extends "res://scripts/player/player.gd"
## Extends Megan's player; the base still owns movement, camera, checkpoints and interaction.

var target_id: String = "player"
var channel: String = "traversal"
var wheel_open: bool = false
var glide_remaining: float = 0.0
var dash_remaining: float = 0.0
var underwater_remaining: float = 0.0
var dash_direction := Vector3.FORWARD
var in_water: bool = false
var water_surface: float = 0.0
var external_velocity := Vector3.ZERO
var facing: Vector3:
	get: return -visuals.global_basis.z if is_instance_valid(visuals) else Vector3.FORWARD


func _unhandled_input(event: InputEvent) -> void:
	if wheel_open:
		return
	# Echo owns these bindings; disable debug abilities in the shared gameplay scene.
	if event.is_action("echo_primary") or event.is_action("echo_personal") or event.is_action("echo_wheel") or event.is_action("debug_glide") or event.is_action("debug_swim"):
		return
	super._unhandled_input(event)


func _physics_process(delta: float) -> void:
	glide_remaining = maxf(0, glide_remaining - delta)
	dash_remaining = maxf(0, dash_remaining - delta)
	underwater_remaining = maxf(0, underwater_remaining - delta)
	if in_water:
		transition_to(MovementState.SWIMMING)
	elif current_state == MovementState.SWIMMING or (current_state == MovementState.GLIDING and glide_remaining <= 0):
		transition_to(MovementState.GROUNDED if is_on_floor() else MovementState.FALLING)
	super._physics_process(delta)


func _apply_horizontal_movement(delta: float) -> void:
	if wheel_open:
		velocity.x = 0
		velocity.z = 0
	else:
		super._apply_horizontal_movement(delta)
		if dash_remaining > 0:
			velocity.x = dash_direction.x * 16.0
			velocity.z = dash_direction.z * 16.0
		velocity.x += external_velocity.x * delta
		velocity.z += external_velocity.z * delta
	velocity.y = maxf(velocity.y, external_velocity.y) if external_velocity.y > 0 else velocity.y


func _process_grounded(delta: float) -> void:
	if not wheel_open:
		super._process_grounded(delta)


func _process_swimming(_delta: float) -> void:
	var ascending := not wheel_open and Input.is_action_pressed("jump")
	var desired_y := water_surface - (1.9 if underwater_remaining > 0 and not ascending else 0.15)
	velocity.y = clampf((desired_y - global_position.y) * 3.0, -3, 3)
	if ascending and global_position.y > water_surface - 0.3:
		velocity.y = 6.0


func echo_action(element: String, held: bool) -> String:
	if element == "wind":
		return "glide" if held else "air_dash"
	return "underwater_access" if element == "water" and in_water else ""


func apply_event(event: Dictionary) -> bool:
	match str(event.get("intended_effect", "")):
		"glide":
			glide_remaining = 0 if glide_remaining > 0 else float(event.get("duration_seconds", 8))
			if glide_remaining > 0:
				if is_on_floor():
					velocity.y = jump_velocity
				TraversalAbilityEvent("glide", event)
			else:
				transition_to(MovementState.FALLING)
		"air_dash":
			dash_direction = event.get("direction", facing)
			dash_direction.y = 0
			dash_direction = dash_direction.normalized() if dash_direction.length() > 0.01 else facing
			dash_remaining = float(event.get("duration_seconds", 0.25))
			velocity.y = maxf(velocity.y, 1.5)
		"underwater_access":
			if not in_water:
				return false
			underwater_remaining = float(event.get("duration_seconds", 15))
			TraversalAbilityEvent("swim", event)
		_: return false
	return true


func respawn() -> void:
	glide_remaining = 0
	dash_remaining = 0
	underwater_remaining = 0
	in_water = false
	external_velocity = Vector3.ZERO
	super.respawn()
