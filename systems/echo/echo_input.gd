extends Node
## Optional keyboard/mouse adapter. Namespaced actions preserve team input mappings.

const EarthTarget = preload("res://systems/echo/earth_target.gd")
@export var hold_seconds: float = 0.3
@export var reach: float = 9.0
var system: Node
var camera: Camera3D
var actor: Node3D
var target: Node3D
var wheel: Control
var preview: MeshInstance3D
var _pressed_action: String = ""
var _element: String = ""
var _locked_target: Node3D
var _elapsed: float = 0.0
var _destination := Vector3.ZERO


func configure(echo_system: Node, view: Camera3D, player: Node3D) -> void:
	system = echo_system
	camera = view
	actor = player
	for binding: Array in [["echo_primary", KEY_Q], ["echo_personal", KEY_E], ["echo_wheel", KEY_TAB], ["echo_dismiss", KEY_X], ["echo_cancel", KEY_ESCAPE]]:
		if not InputMap.has_action(binding[0]):
			InputMap.add_action(binding[0])
			var key := InputEventKey.new()
			key.physical_keycode = binding[1]
			InputMap.action_add_event(binding[0], key)
	preview = MeshInstance3D.new()
	add_child(preview)
	preview.visible = false


func _physics_process(delta: float) -> void:
	if not is_instance_valid(system) or not is_instance_valid(camera):
		return
	if Input.is_action_just_pressed("echo_cancel"):
		cancel()
	if Input.is_action_just_pressed("echo_wheel") and is_instance_valid(wheel):
		cancel()
		wheel.open()
	if Input.is_action_just_released("echo_wheel") and is_instance_valid(wheel):
		wheel.close()
		return
	if is_instance_valid(wheel) and wheel.is_open:
		cancel()
		return
	if Input.is_action_just_pressed("echo_dismiss"):
		cancel()
		system.dismiss()
	_update_target()
	if _pressed_action.is_empty():
		for input_action: String in ["echo_primary", "echo_personal"]:
			if Input.is_action_just_pressed(input_action):
				var element: String = system.selected_power(input_action == "echo_personal")
				var candidate: Node3D = target
				if _action_for(candidate, element, false).is_empty() and _action_for(candidate, element, true).is_empty():
					candidate = actor
				if system.can_use(element) and (not _action_for(candidate, element, false).is_empty() or not _action_for(candidate, element, true).is_empty()):
					_pressed_action = input_action
					_element = element
					_locked_target = candidate
					_elapsed = 0.0
				break
	else:
		_elapsed += delta
		if not is_instance_valid(_locked_target) or not system.can_use(_element) or system.selected_power(_pressed_action == "echo_personal") != _element:
			cancel()
			return
		if actor.global_position.distance_to(_locked_target.global_position) > reach:
			cancel()
			return
		if _elapsed >= hold_seconds and _locked_target is EarthTarget and _locked_target.kind == "rock":
			_update_preview()
			if _pressed_action.is_empty():
				return
		if Input.is_action_just_released(_pressed_action):
			var held := _elapsed >= hold_seconds
			var is_earth_target: bool = _locked_target is EarthTarget
			var action: String = _action_for(_locked_target, _element, held)
			var at: Vector3 = _destination if held and is_earth_target and _locked_target.kind == "rock" else _locked_target.global_position
			var channel: String = "traversal" if is_earth_target else _locked_target.channel
			if actor.global_position.distance_to(at) <= reach:
				var direction := (at - actor.global_position).normalized()
				if _locked_target == actor:
					direction = actor.get("facing") if actor.get("facing") is Vector3 else Vector3.FORWARD
				system.request_ability(_element, action, _locked_target.target_id, at, channel, {"origin": actor.global_position, "direction": direction})
			cancel()


func cancel() -> void:
	_pressed_action = ""
	_locked_target = null
	_elapsed = 0.0
	if is_instance_valid(preview):
		preview.visible = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		cancel()
		if is_instance_valid(wheel):
			wheel.close(false)


func _action_for(candidate: Node3D, element: String, held: bool) -> String:
	if not is_instance_valid(candidate):
		return ""
	if candidate is EarthTarget:
		return candidate.action_for(held) if element == "earth" else ""
	if candidate.has_method("echo_action"):
		return candidate.echo_action(element, held)
	return ""


func _update_target() -> void:
	if is_instance_valid(target):
		target.set_highlight(false)
	target = null
	var mouse := camera.get_viewport().get_mouse_position()
	var start := camera.project_ray_origin(mouse)
	var query := PhysicsRayQueryParameters3D.create(start, start + camera.project_ray_normal(mouse) * 100.0, 5)
	if actor is CollisionObject3D:
		query.exclude = [actor.get_rid()]
	var hit := camera.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and (hit["collider"] is EarthTarget or hit["collider"].has_method("echo_action")):
		var candidate: Node3D = hit["collider"]
		if actor.global_position.distance_to(candidate.global_position) <= reach:
			target = candidate
			target.set_highlight(true)


func _update_preview() -> void:
	var mouse := camera.get_viewport().get_mouse_position()
	var intersection: Variant = Plane(Vector3.UP, 0.0).intersects_ray(camera.project_ray_origin(mouse), camera.project_ray_normal(mouse))
	if intersection == null:
		cancel()
		return
	_destination = intersection
	var box := BoxMesh.new()
	box.size = _locked_target.dimensions()
	preview.mesh = box
	preview.global_position = _destination + Vector3.UP * box.size.y * 0.5
	var valid: bool = actor.global_position.distance_to(_destination) <= reach and _locked_target.can_place(_destination, box.size)
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.4, 1.0, 0.5, 0.45) if valid else Color(1.0, 0.25, 0.2, 0.45)
	preview.material_override = material
	preview.visible = true


func prompt() -> String:
	if is_instance_valid(wheel) and wheel.is_open:
		return "Release Tab to select. Esc cancels."
	if not _pressed_action.is_empty() and _elapsed >= hold_seconds and is_instance_valid(_locked_target) and _locked_target is EarthTarget and _locked_target.kind == "rock":
		return "Aim to move | Release to place | Esc to cancel"
	if is_instance_valid(target) and not _action_for(target, system.selected_power(), false).is_empty():
		return "Q: " + target.prompt()
	if system.selected_power() == "wind":
		return "Q tap: dash • Hold: glide • Aim at a vent: create an updraft"
	if system.selected_power() == "water":
		return "Aim at water: tap to freeze/thaw, hold to dive • Stream: reverse flow"
	if system.selected_power() == "time":
		return "Clockwork: tap to freeze, hold to reset • Enemy: slow"
	if system.personal_power().is_empty() and system.unlocked_echoes().is_empty():
		return "Walk to your stone to unlock Earth."
	if system.selected_power() != "earth" and system.personal_power() != "earth":
		return "Hold Tab to select an unlocked power. Earth shapes rocks and terrain."
	if is_instance_valid(target):
		var key := "Q" if system.selected_power() == "earth" else "E"
		return key + " - " + target.prompt()
	return "Aim at a highlighted rock or earth patch within reach."
