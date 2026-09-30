class_name CombatEnemy
extends CharacterBody3D
## Awareness, attack phase and statuses are independent; state is a UI projection.
signal state_changed(previous: State, current: State)
signal defeated(enemy: CombatEnemy)
signal combat_event(event: Dictionary)
signal attack_telegraphed(kind: String, at: Vector3, seconds: float)
enum State { IDLE, CHASE, ATTACK, STUNNED, FROZEN, SLOWED, DEAD, SUSPICIOUS, HIT_REACTION, AIRBORNE, RETURNING, SPAWNING }
enum Archetype { SCOUT, SLINGER, SHELLGUARD, SKITTER, RUIN_GUARDIAN }
enum Awareness { UNAWARE, SUSPICIOUS, ENGAGED, RETURNING }
const Data = preload("res://systems/combat/attack_data.gd")
const EFFECTS = {"earth": "stun", "wind": "push", "water": "freeze", "time": "slow"}
@export var target_id := ""
@export var archetype: Archetype = Archetype.SCOUT
@export var max_health := 40.0
@export var contact_damage := 10.0
@export var move_speed := 3.5
@export var attack_interval := 1.2
@export var detection_range := 12.0
@export var return_radius := 18.0
@export var guard_blocks_front := false
@export var guard_broken := false
@export var immune_elements: Array[String] = []
@export var combo_guardian := false
@export var spawn_seconds := 0.6
var state: State = State.IDLE
var awareness: Awareness = Awareness.UNAWARE
var health := 0.0
var shield := 0.0
var max_shield := 0.0
var armor_type := "none"
var home_position := Vector3.ZERO
var target: Node3D
var _status_remaining: Dictionary = {}
var _knockback := Vector3.ZERO
var _attack_cooldown := 0.0
var suspicion := 0.0
var lost_sight := 0.0
var attack_phase := "idle"
var attack_age := 0.0
var attack_kind := "melee"
var attack_point := Vector3.ZERO
var attack_direction := Vector3.FORWARD
var attack_hit := false
var hit_recovery := 0.0
var life_age := 0.0
var defeat_age := 0.0
var boss_phase := 1
var combo_step := 0
var exposed_remaining := 0.0
var _event_serial := 0

func _ready() -> void:
	if target_id.is_empty():
		target_id = name.to_snake_case()
	_apply_archetype_defaults()
	health = max_health
	home_position = global_position
	armor_type = "stone" if guard_blocks_front else "none"
	max_shield = 40.0 if guard_blocks_front else 0.0
	shield = max_shield
	add_to_group("combat_targets")

func echo_action(element: String, _held: bool = false) -> String:
	return EFFECTS.get(element, "") if state != State.DEAD else ""

func status_result(event: Dictionary) -> Dictionary:
	var element := str(event.get("echo_id", ""))
	var effect := str(event.get("intended_effect", ""))
	var result := {"target_id": target_id, "success": false, "outcome": "failed", "resulting_status": "invalid_target_or_effect", "armor_type": armor_type}
	if state == State.DEAD or event.get("target_id") != target_id or not EFFECTS.has(element) or EFFECTS[element] != effect:
		return result
	if element in immune_elements or (guard_blocks_front and not guard_broken and element != "earth"):
		result.outcome = "resisted"
		result.resulting_status = "armored" if element not in immune_elements else "immune"
		return result
	var here := global_position if is_inside_tree() else position
	var origin: Variant = event.get("origin", here - Vector3.FORWARD)
	if not origin is Vector3 or not origin.is_finite():
		return result
	match effect:
		"stun":
			guard_broken = true
			shield = 0
			_apply_status("stun", 2.5)
			_cancel_attack()
		"freeze":
			_apply_status("freeze", 3.0)
			_knockback = Vector3.ZERO
			velocity = Vector3.ZERO
			_cancel_attack()
		"slow": _apply_status("slow", 4.0)
		"push":
			var launch_combo := _status_remaining.has("stun")
			var direction: Vector3 = here - origin
			direction.y = 0
			if direction.length_squared() < 0.01:
				direction = Vector3.FORWARD
			_knockback = direction.normalized() * 10.0
			if not _status_remaining.has("freeze"):
				_status_remaining.erase("stun")
				velocity.y = 5.0 if archetype != Archetype.RUIN_GUARDIAN else 2.0
				_apply_status("airborne", 0.55)
			_apply_status("push", 0.35)
			_cancel_attack()
			if launch_combo:
				_emit_combat("launch_combo", {"reward": 8.0})
	if combo_guardian:
		var sequence := ["earth", "wind", "water", "time"]
		if element == sequence[mini(combo_step, 3)] and combo_step < 4:
			combo_step += 1
			if combo_step == 4:
				exposed_remaining = 6
				_emit_combat("core_exposed", {"reward": 8.0})
	awareness = Awareness.ENGAGED
	lost_sight = 0
	result.success = true
	result.outcome = "applied"
	result.resulting_status = effect
	return result

func apply_echo_event(event: Dictionary) -> bool:
	return status_result(event).success

func take_damage(amount: float, attacker_position := Vector3.INF, heavy := false) -> bool:
	return receive_hit({"damage": amount, "origin": attacker_position, "heavy": heavy}).success

func receive_hit(hit: Dictionary) -> Dictionary:
	var raw: Variant = hit.get("damage", 0.0)
	var result := {"success": false, "outcome": "invalid", "damage": 0.0, "critical": false, "shatter": false}
	if (not raw is float and not raw is int) or not is_finite(float(raw)) or raw <= 0 or state == State.DEAD:
		return result
	var origin: Variant = hit.get("origin", Vector3.INF)
	if not origin is Vector3:
		return result
	var environmental: bool = origin == Vector3.INF
	if not environmental and not origin.is_finite():
		return result
	var heavy: bool = hit.get("heavy", false) == true
	var offset: Vector3 = origin - global_position if not environmental else Vector3.ZERO
	offset.y = 0
	var frontal: bool = not environmental and offset.length_squared() > 0.01 and (-global_basis.z).dot(offset.normalized()) > 0.25
	if guard_blocks_front and not guard_broken and frontal and not heavy:
		result.outcome = "guarded"
		return result
	if heavy and guard_blocks_front and not guard_broken:
		shield = maxf(0, shield - float(raw))
		if shield <= 0:
			guard_broken = true
			_apply_status("stun", 1.0)
		else:
			result.success = true
			result.outcome = "shield_damaged"
			return result
	var shatter := _status_remaining.has("freeze") and not environmental
	# Deterministic critical: punish the back during recovery, not hidden random rolls.
	var critical: bool = not environmental and attack_phase == "recovery" and not frontal
	var damage: float = float(raw) * (1.5 if shatter else 1.0) * (1.5 if critical else 1.0)
	if combo_guardian and exposed_remaining <= 0 and not environmental:
		result.outcome = "core_shielded"
		return result
	if shatter:
		_status_remaining.erase("freeze")
		_emit_combat("shatter_combo", {"reward": 8.0})
	damage = minf(damage, health)
	health -= damage
	result.merge({"success": true, "outcome": "damaged", "damage": damage, "critical": critical, "shatter": shatter}, true)
	awareness = Awareness.ENGAGED
	lost_sight = 0
	if health <= 0:
		_set_state(State.DEAD)
		_cancel_attack()
		collision_layer = 0
		collision_mask = 0
		_emit_combat("enemy_defeated", {"reward": 10.0})
		defeated.emit(self)
	else:
		hit_recovery = 0.2 if not heavy else 0.35
		if archetype != Archetype.RUIN_GUARDIAN or shatter:
			_cancel_attack()
		_update_boss_phase()
	return result

func _update_boss_phase() -> void:
	if not combo_guardian:
		return
	var next := 3 if health <= max_health / 3 else (2 if health <= max_health * 2 / 3 else 1)
	if next > boss_phase:
		boss_phase = next
		combo_step = 0
		exposed_remaining = 0
		guard_broken = false
		shield = max_shield
		_status_remaining.clear()
		_cancel_attack()
		_emit_combat("boss_phase", {"phase": boss_phase, "reward": 0.0})

func _physics_process(delta: float) -> void:
	life_age += delta
	if state == State.DEAD:
		defeat_age += delta
		velocity = Vector3.ZERO
		return
	_tick_statuses(delta)
	exposed_remaining = maxf(0, exposed_remaining - delta)
	if combo_guardian and exposed_remaining == 0 and combo_step == 4:
		combo_step = 0
		guard_broken = false
		shield = max_shield
	if life_age < spawn_seconds:
		_set_state(State.SPAWNING)
		return
	if _status_remaining.has("freeze"):
		_set_state(State.FROZEN)
		velocity = Vector3.ZERO
		return
	var speed_factor := 0.3 if _status_remaining.has("slow") else 1.0
	_attack_cooldown = maxf(0, _attack_cooldown - delta * speed_factor)
	hit_recovery = maxf(0, hit_recovery - delta * speed_factor)
	if _status_remaining.has("stun"):
		_set_state(State.STUNNED)
		velocity.x = 0
		velocity.z = 0
	elif _status_remaining.has("airborne"):
		_set_state(State.AIRBORNE)
	elif hit_recovery > 0:
		_set_state(State.HIT_REACTION)
		velocity.x = move_toward(velocity.x, 0, 25 * delta)
		velocity.z = move_toward(velocity.z, 0, 25 * delta)
	else:
		_update_awareness(delta)
		_update_behavior(speed_factor, delta)
		_tick_attack(delta * speed_factor)
	velocity.x += _knockback.x
	velocity.z += _knockback.z
	var applied_knockback := _knockback
	_knockback = _knockback.move_toward(Vector3.ZERO, 24 * delta)
	if not is_on_floor():
		velocity.y -= 20 * delta
	move_and_slide()
	velocity.x -= applied_knockback.x
	velocity.z -= applied_knockback.z

func _update_awareness(delta: float) -> void:
	var sees := false
	if is_instance_valid(target) and global_position.distance_to(home_position) < return_radius:
		var offset := target.global_position - global_position
		var facing := (-global_basis.z).dot(offset.normalized()) > -0.25
		sees = offset.length() <= detection_range and (facing or awareness == Awareness.ENGAGED or offset.length() < 3) and Data.clear_line(self, target)
		if target.has_method("combat_alive") and not target.combat_alive():
			sees = false
	if sees:
		lost_sight = 0
		suspicion = minf(1, suspicion + delta * 1.7)
		awareness = Awareness.ENGAGED if suspicion >= 1 or awareness == Awareness.ENGAGED else Awareness.SUSPICIOUS
	else:
		lost_sight += delta
		suspicion = maxf(0, suspicion - delta)
		if lost_sight > 2:
			awareness = Awareness.RETURNING
			_cancel_attack()

func _update_behavior(speed_factor: float, delta: float = 0.016) -> void:
	if awareness == Awareness.ENGAGED and is_instance_valid(target):
		var offset := target.global_position - global_position
		offset.y = 0
		if attack_phase == "idle" and offset.length_squared() > 0.01:
			rotation.y = lerp_angle(rotation.y, atan2(-offset.x, -offset.z), minf(1, delta * 8))
		var reach := 8.0 if archetype == Archetype.SLINGER else (3.0 if archetype == Archetype.RUIN_GUARDIAN else 1.9)
		if attack_phase != "idle" or (offset.length() <= reach and _attack_cooldown <= 0 and Data.clear_line(self, target)):
			velocity.x = 0
			velocity.z = 0
			_set_state(State.ATTACK)
			if attack_phase == "idle":
				_start_attack()
		else:
			var desired := offset.normalized() * move_speed * speed_factor
			if archetype == Archetype.SLINGER and offset.length() < 4:
				desired *= -0.65
			elif offset.length() <= reach:
				desired = Vector3.ZERO
			velocity.x = move_toward(velocity.x, desired.x, delta * 18)
			velocity.z = move_toward(velocity.z, desired.z, delta * 18)
			_set_state(State.SLOWED if speed_factor < 1 else State.CHASE)
	elif awareness == Awareness.SUSPICIOUS:
		velocity.x = 0
		velocity.z = 0
		_set_state(State.SUSPICIOUS)
	else:
		var offset := home_position - global_position
		offset.y = 0
		var desired := offset.normalized() * move_speed * 0.6 if offset.length() > 0.2 else Vector3.ZERO
		velocity.x = desired.x
		velocity.z = desired.z
		_set_state(State.RETURNING if offset.length() > 0.2 else State.IDLE)
		if offset.length() <= 0.2:
			awareness = Awareness.UNAWARE

func _start_attack() -> void:
	attack_phase = "startup"
	attack_age = 0
	attack_hit = false
	attack_point = target.global_position
	attack_direction = (attack_point - global_position).normalized()
	attack_kind = "projectile" if archetype == Archetype.SLINGER else "melee"
	if combo_guardian and boss_phase >= 2:
		attack_kind = "hazard" if _event_serial % 2 == 0 else "melee"
	_event_serial += 1
	attack_telegraphed.emit(attack_kind, attack_point, _startup())

func _startup() -> float:
	return 0.85 if attack_kind == "hazard" else (0.7 if archetype == Archetype.RUIN_GUARDIAN else 0.4)

func _tick_attack(delta: float) -> void:
	if attack_phase == "idle":
		return
	attack_age += delta
	if attack_age >= _startup() and attack_age < _startup() + 0.1:
		attack_phase = "active"
	if attack_age >= _startup() and not attack_hit:
		attack_hit = true
		if attack_kind in ["projectile", "hazard"]:
			var effect := preload("res://systems/combat/threat.gd").new()
			effect.source = self
			effect.actor = target
			effect.kind = attack_kind
			effect.damage = contact_damage
			effect.position = global_position + Vector3.UP if attack_kind == "projectile" else attack_point
			effect.direction = attack_direction
			get_parent().add_child(effect)
		elif is_instance_valid(target) and target.has_method("receive_combat_damage"):
			var offset := target.global_position - global_position
			var reach := 3.2 if archetype == Archetype.RUIN_GUARDIAN else 2.2
			if offset.length() <= reach and attack_direction.dot(offset.normalized()) > 0.35 and Data.clear_line(self, target):
				target.receive_combat_damage(contact_damage, self)
	if attack_age >= _startup() + 0.1:
		attack_phase = "recovery"
	if attack_age >= _startup() + 0.6:
		_cancel_attack()
		_attack_cooldown = attack_interval

func _cancel_attack() -> void:
	attack_phase = "idle"
	attack_age = 0
	attack_hit = false

func brief_opening() -> void:
	_apply_status("slow", 0.65)
	_attack_cooldown = maxf(_attack_cooldown, 0.5)

func _emit_combat(kind: String, extra: Dictionary) -> void:
	_event_serial += 1
	var event := {"event_id": "%d:%d" % [get_instance_id(), _event_serial], "target_id": target_id, "kind": kind, "armor_type": armor_type}
	event.merge(extra)
	combat_event.emit(event)

func _apply_status(status: String, duration: float) -> void:
	_status_remaining[status] = maxf(float(_status_remaining.get(status, 0)), duration)

func _tick_statuses(delta: float) -> void:
	for effect: String in _status_remaining.keys():
		_status_remaining[effect] -= delta
		if _status_remaining[effect] <= 0:
			_status_remaining.erase(effect)

func _set_state(next: State) -> void:
	if state != next:
		var previous := state
		state = next
		state_changed.emit(previous, next)

func _apply_archetype_defaults() -> void:
	match archetype:
		Archetype.SCOUT:
			move_speed = 4.2
			max_health = maxf(max_health, 30)
		Archetype.SLINGER:
			move_speed = 2.4
			attack_interval = 2
		Archetype.SHELLGUARD:
			guard_blocks_front = true
			max_health = maxf(max_health, 80)
		Archetype.SKITTER:
			move_speed = 6.5
			max_health = minf(max_health, 28)
		Archetype.RUIN_GUARDIAN:
			guard_blocks_front = true
			max_health = maxf(max_health, 220)
			contact_damage = 25
