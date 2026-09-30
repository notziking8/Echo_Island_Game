extends Node
## Frame-authoritative combat component. Traversal retains ownership of move_and_slide.
signal attack_started(attack: Dictionary)
signal phase_changed(phase: String)
signal hit_confirmed(victim: Node3D, result: Dictionary)
signal dodge_started
signal death_started
signal weapon_selected(index: int)
const Data = preload("res://systems/combat/attack_data.gd")
var actor: CharacterBody3D
var vitals: Node
var phase := "idle"
var attack: Dictionary = {}
var elapsed := 0.0
var combo_index := -1
var chain_remaining := 0.0
var buffer := ""
var buffer_remaining := 0.0
var struck: Dictionary = {}
var direction := Vector3.FORWARD
var dodge_remaining := 0.0
var dodge_cooldown := 0.0
var death_remaining := 0.0
var perfect_dodge_used := false
var weapon_index := 0

func _ready() -> void:
	actor = get_parent()
	process_physics_priority = -20
	vitals = preload("res://systems/combat/vitals.gd").new()
	add_child(vitals)
	vitals.defeated.connect(_die)
	vitals.damaged.connect(func(_amount, _source):
		if not vitals.dead:
			cancel_attack()
			_set_phase("hurt")
	)
	actor.respawned.connect(func(_at): reset())
	for binding: Array in [["combat_light", MOUSE_BUTTON_LEFT], ["combat_heavy", MOUSE_BUTTON_RIGHT]]:
		if not InputMap.has_action(binding[0]):
			InputMap.add_action(binding[0])
			var button := InputEventMouseButton.new()
			button.button_index = binding[1]
			InputMap.action_add_event(binding[0], button)
	if not InputMap.has_action("combat_dodge"):
		InputMap.add_action("combat_dodge")
		var key := InputEventKey.new()
		key.physical_keycode = KEY_SHIFT
		InputMap.action_add_event("combat_dodge", key)
	for i in 4:
		var slot := "combat_slot_%d" % (i + 1)
		if not InputMap.has_action(slot):
			InputMap.add_action(slot)
			var key := InputEventKey.new()
			key.physical_keycode = KEY_1 + i
			InputMap.action_add_event(slot, key)

func _unhandled_input(event: InputEvent) -> void:
	if actor.wheel_open or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED or vitals.dead:
		return
	if event.is_action_pressed("combat_dodge"):
		request_dodge()
	elif event.is_action_pressed("combat_light"):
		request_attack("light")
	elif event.is_action_pressed("combat_heavy"):
		request_attack("heavy")
	for i in 4:
		if event.is_action_pressed("combat_slot_%d" % (i + 1)) and phase == "idle":
			weapon_index = i
			weapon_selected.emit(i)

func request_attack(kind: String) -> bool:
	if kind not in ["light", "heavy"] or vitals.dead or actor.wheel_open or phase == "dodge" or phase == "hurt":
		return false
	if not attack.is_empty():
		buffer = kind
		buffer_remaining = Data.BUFFER_SECONDS
		return true
	combo_index = (combo_index + 1) % 3 if kind == "light" and chain_remaining > 0 else 0
	attack = (Data.LIGHT[combo_index] if kind == "light" else Data.HEAVY).duplicate()
	if kind == "heavy":
		combo_index = -1
	struck.clear()
	elapsed = 0
	direction = -actor.camera.global_basis.z
	direction.y = 0
	direction = direction.normalized()
	actor.visuals.rotation.y = atan2(-direction.x, -direction.z)
	_set_phase("startup")
	attack_started.emit(attack)
	return true

func request_dodge() -> bool:
	if vitals.dead or actor.wheel_open or dodge_cooldown > 0 or not actor.is_on_floor():
		return false
	cancel_attack()
	var move := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	direction = actor.camera.global_basis.x * move.x + actor.camera.global_basis.z * move.y
	direction.y = 0
	if direction.length_squared() < 0.01:
		direction = actor.facing
	direction = direction.normalized()
	dodge_remaining = Data.DODGE_SECONDS
	dodge_cooldown = Data.DODGE_COOLDOWN
	perfect_dodge_used = false
	_set_phase("dodge")
	dodge_started.emit()
	return true

func receive_damage(amount: float, source: Object = null) -> Dictionary:
	var result: Dictionary = vitals.receive_damage(amount, source)
	if result.outcome == "evaded" and phase == "dodge" and vitals.invulnerable and not perfect_dodge_used:
		perfect_dodge_used = true
		if is_instance_valid(source) and source.has_method("brief_opening"):
			source.brief_opening()
		vitals.grant_shield(8, 2.0)
	return result

func cancel_attack() -> void:
	attack.clear()
	struck.clear()
	buffer = ""
	buffer_remaining = 0
	chain_remaining = 0
	combo_index = -1
	_set_phase("idle")

func reset() -> void:
	cancel_attack()
	dodge_remaining = 0
	dodge_cooldown = 0
	death_remaining = 0
	vitals.reset()

func _die() -> void:
	cancel_attack()
	dodge_remaining = 0
	death_remaining = 1.2
	_set_phase("dead")
	death_started.emit()

func _set_phase(value: String) -> void:
	if phase != value:
		phase = value
		phase_changed.emit(value)

func _physics_process(delta: float) -> void:
	tick(delta)

func tick(delta: float) -> void:
	vitals.tick(delta)
	dodge_cooldown = maxf(0, dodge_cooldown - delta)
	chain_remaining = maxf(0, chain_remaining - delta)
	if vitals.dead:
		death_remaining -= delta
		if death_remaining <= 0:
			actor.respawn()
		return
	if actor.wheel_open and not attack.is_empty():
		cancel_attack()
	if phase == "hurt":
		if vitals.recovery_remaining < 0.35:
			_set_phase("idle")
		return
	if dodge_remaining > 0:
		dodge_remaining = maxf(0, dodge_remaining - delta)
		var age := Data.DODGE_SECONDS - dodge_remaining
		vitals.invulnerable = age >= Data.DODGE_IFRAME_START and age < Data.DODGE_IFRAME_END
		if dodge_remaining == 0:
			vitals.invulnerable = false
			_set_phase("idle")
		return
	if not attack.is_empty():
		var old_time := elapsed
		elapsed += delta
		# Sweep every portion of the active arc crossed this tick, including hitches.
		if elapsed >= attack.startup and old_time <= attack.startup + attack.active:
			_set_phase("active")
			_sweep_hits(clampf((old_time - attack.startup) / attack.active, 0, 1), clampf((elapsed - attack.startup) / attack.active, 0, 1))
		if elapsed >= attack.startup + attack.active:
			_set_phase("recovery")
		if elapsed >= Data.duration(attack):
			var time_to_end: float = maxf(0, Data.duration(attack) - old_time)
			attack.clear()
			chain_remaining = 0.35
			_set_phase("idle")
			if buffer_remaining > time_to_end:
				var next := buffer
				buffer = ""
				buffer_remaining = 0
				request_attack(next)
	buffer_remaining = maxf(0, buffer_remaining - delta)
	if buffer_remaining == 0:
		buffer = ""

func _sweep_hits(from: float, to: float) -> void:
	var half_arc: float = deg_to_rad(attack.arc) * 0.5
	var a := lerpf(-half_arc, half_arc, from)
	var b := lerpf(-half_arc, half_arc, to)
	for victim: Node3D in get_tree().get_nodes_in_group("combat_targets"):
		if not victim.has_method("receive_hit") or victim.health <= 0 or struck.has(victim.get_instance_id()):
			continue
		var offset := victim.global_position - actor.global_position
		if absf(offset.y) > 2.0 or offset.length() > float(attack.reach) + 0.4:
			continue
		offset.y = 0
		var angle := direction.signed_angle_to(offset.normalized(), Vector3.UP)
		if angle < a - 0.22 or angle > b + 0.22 or not Data.clear_line(actor, victim):
			continue
		struck[victim.get_instance_id()] = true
		var result: Dictionary = victim.receive_hit({"damage": attack.damage, "heavy": attack.name == "heavy", "origin": actor.global_position, "source_id": actor.get_instance_id()})
		hit_confirmed.emit(victim, result)

func apply_motion(delta: float) -> void:
	if vitals.dead or phase == "hurt":
		actor.velocity.x = move_toward(actor.velocity.x, 0, delta * 50)
		actor.velocity.z = move_toward(actor.velocity.z, 0, delta * 50)
	elif phase == "dodge":
		var speed := 11.0 * smoothstep(0, 0.15, dodge_remaining)
		actor.velocity.x = direction.x * speed
		actor.velocity.z = direction.z * speed
	elif not attack.is_empty():
		actor.visuals.rotation.y = atan2(-direction.x, -direction.z)
		var desired := direction * (2.2 if phase == "active" else 0.8)
		actor.velocity.x = move_toward(actor.velocity.x, desired.x, delta * 25)
		actor.velocity.z = move_toward(actor.velocity.z, desired.z, delta * 25)
