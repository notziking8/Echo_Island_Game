class_name CombatEnemy
extends CharacterBody3D
## Shared enemy state machine and Echo receiver. Individual scenes only choose a profile.

signal state_changed(previous: State, current: State)
signal defeated(enemy: CombatEnemy)

enum State { IDLE, CHASE, ATTACK, STUNNED, FROZEN, SLOWED, DEAD }
enum Archetype { SCOUT, SLINGER, SHELLGUARD, SKITTER, RUIN_GUARDIAN }

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

var state: State = State.IDLE
var health := 0.0
var home_position := Vector3.ZERO
var target: Node3D
var _status_remaining: Dictionary = {}
var _knockback := Vector3.ZERO
var _attack_cooldown := 0.0


func _ready() -> void:
	if target_id.is_empty():
		target_id = name.to_snake_case()
	_apply_archetype_defaults()
	health = max_health
	home_position = global_position
	add_to_group("combat_targets")


func echo_action(element: String, _held: bool = false) -> String:
	match archetype:
		Archetype.SHELLGUARD, Archetype.RUIN_GUARDIAN:
			return "stun" if element == "earth" else ""
		Archetype.SKITTER:
			return "push" if element == "wind" else ""
		Archetype.SLINGER:
			return "slow" if element == "time" else ""
		_:
			return "freeze" if element == "water" else ""


func apply_echo_event(event: Dictionary) -> bool:
	if state == State.DEAD or event.get("target_id", "") != target_id:
		return false
	var effect := str(event.get("intended_effect", ""))
	if effect != echo_action(str(event.get("echo_id", ""))):
		return false
	match effect:
		"stun":
			guard_broken = true
			_apply_status("stun", 2.5)
		"freeze": _apply_status("freeze", 3.5)
		"slow": _apply_status("slow", 4.0)
		"push":
			var direction: Vector3 = global_position - event.get("origin", global_position - Vector3.FORWARD)
			direction.y = 0.0
			_knockback = direction.normalized() * maxf(9.0, float(event.get("strength", 0.0)))
			_apply_status("push", 0.35)
		_:
			return false
	return true


func take_damage(amount: float, attacker_position := Vector3.INF, heavy := false) -> bool:
	if state == State.DEAD or amount <= 0.0:
		return false
	if guard_blocks_front and not guard_broken and not heavy and attacker_position.is_finite():
		var to_attacker := attacker_position - global_position
		to_attacker.y = 0.0
		if to_attacker.length_squared() > 0.01 and -global_transform.basis.z.dot(to_attacker.normalized()) > 0.25:
			return false
	if heavy and guard_blocks_front:
		guard_broken = true
		_apply_status("stun", 1.0)
	health = maxf(0.0, health - amount)
	if is_zero_approx(health):
		_set_state(State.DEAD)
		defeated.emit(self)
	return true


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		velocity = Vector3.ZERO
		return
	_tick_statuses(delta)
	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)
	var immobilized := _status_remaining.has("stun") or _status_remaining.has("freeze")
	if immobilized:
		_set_state(State.STUNNED if _status_remaining.has("stun") else State.FROZEN)
		velocity = _knockback
	else:
		var speed_factor := 0.35 if _status_remaining.has("slow") else 1.0
		_update_behavior(speed_factor)
		velocity += _knockback
	_knockback = _knockback.move_toward(Vector3.ZERO, 24.0 * delta)
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	move_and_slide()


func _update_behavior(speed_factor: float) -> void:
	if target and is_instance_valid(target):
		var offset := target.global_position - global_position
		offset.y = 0.0
		if offset.length() <= detection_range:
			if offset.length() <= 1.8:
				_set_state(State.ATTACK)
				velocity.x = 0.0
				velocity.z = 0.0
				return
			_set_state(State.CHASE if not _status_remaining.has("slow") else State.SLOWED)
			velocity = offset.normalized() * move_speed * speed_factor
			return
	var home_offset := home_position - global_position
	home_offset.y = 0.0
	if home_offset.length() > 0.15:
		_set_state(State.IDLE)
		velocity = home_offset.normalized() * move_speed * 0.6
	else:
		velocity = Vector3.ZERO


func _apply_status(status: String, duration: float) -> void:
	_status_remaining[status] = maxf(float(_status_remaining.get(status, 0.0)), duration)


func _tick_statuses(delta: float) -> void:
	for effect: String in _status_remaining.keys():
		_status_remaining[effect] = float(_status_remaining[effect]) - delta
		if _status_remaining[effect] <= 0.0:
			_status_remaining.erase(effect)


func _set_state(next: State) -> void:
	if state == next:
		return
	var previous := state
	state = next
	state_changed.emit(previous, state)


func _apply_archetype_defaults() -> void:
	match archetype:
		Archetype.SCOUT:
			move_speed = 4.2
			max_health = maxf(max_health, 30.0)
		Archetype.SLINGER:
			move_speed = 2.4
			attack_interval = 2.0
		Archetype.SHELLGUARD:
			guard_blocks_front = true
			max_health = maxf(max_health, 80.0)
		Archetype.SKITTER:
			move_speed = 6.5
			max_health = minf(max_health, 28.0)
		Archetype.RUIN_GUARDIAN:
			guard_blocks_front = true
			max_health = maxf(max_health, 220.0)
			contact_damage = 25.0
