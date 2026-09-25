extends CharacterBody3D
## Demonstration Traversal receiver. Replace with Megan's movement adapter in the game.

var target_id: String = "player"
var channel: String = "traversal"
var facing := Vector3.FORWARD
var glide_remaining: float = 0.0
var dash_remaining: float = 0.0
var underwater_remaining: float = 0.0
var dash_direction := Vector3.FORWARD
var external_velocity := Vector3.ZERO
var in_water: bool = false
var movement_state: String = "grounded"
var _jump_was_down: bool = false


func echo_action(element: String, held: bool) -> String:
	if element == "wind":
		return "glide" if held else "air_dash"
	if element == "water" and in_water:
		return "underwater_access"
	return ""


func apply_event(event: Dictionary) -> bool:
	var action: String = event["intended_effect"]
	match action:
		"air_dash":
			if dash_remaining > 0:
				return false
			dash_direction = event.get("direction", facing)
			dash_direction.y = 0
			if dash_direction.length() < 0.1:
				dash_direction = facing
			dash_direction = dash_direction.normalized()
			dash_remaining = clampf(float(event.get("duration_seconds", 0.25)), 0.1, 0.5)
			velocity.y = maxf(velocity.y, 2.0)
		"glide":
			glide_remaining = 0.0 if glide_remaining > 0 else clampf(float(event.get("duration_seconds", 8.0)), 0.1, 20)
			if is_on_floor() and glide_remaining > 0:
				velocity.y = 7.5
		"underwater_access":
			if not in_water:
				return false
			underwater_remaining = clampf(float(event.get("duration_seconds", 15.0)), 1, 30)
		_:
			return false
	return true


func step(delta: float, input_blocked: bool) -> void:
	glide_remaining = maxf(0, glide_remaining - delta)
	dash_remaining = maxf(0, dash_remaining - delta)
	underwater_remaining = maxf(0, underwater_remaining - delta)
	var direction := Vector3.ZERO
	var jump := false
	if not input_blocked:
		direction = Vector3(float(Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_LEFT)), 0,
			float(Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_UP))).normalized()
		jump = Input.is_physical_key_pressed(KEY_SPACE)
	if direction.length() > 0.1:
		facing = direction
	velocity.x = direction.x * 5.0 + external_velocity.x
	velocity.z = direction.z * 5.0 + external_velocity.z
	if dash_remaining > 0:
		velocity.x = dash_direction.x * 16.0
		velocity.z = dash_direction.z * 16.0
	if in_water:
		movement_state = "diving" if underwater_remaining > 0 and not jump else "swimming"
		var desired_y := -1.9 if underwater_remaining > 0 and not jump else -0.15
		velocity.y = clampf((desired_y - position.y) * 3.0, -3.0, 3.0)
		if jump and position.y > -0.3:
			velocity.y = 6.0
	elif not is_on_floor():
		movement_state = "gliding" if glide_remaining > 0 else "falling"
		velocity.y -= (3.0 if glide_remaining > 0 else 18.0) * delta
		if glide_remaining > 0:
			velocity.y = maxf(velocity.y, -1.5)
	else:
		movement_state = "grounded"
		if jump and not _jump_was_down:
			velocity.y = 7.0
	if external_velocity.y > 0:
		velocity.y = maxf(velocity.y, external_velocity.y)
		movement_state = "updraft"
	_jump_was_down = jump
	move_and_slide()
	position.x = clampf(position.x, -13, 13)
	position.z = clampf(position.z, -10, 10)
	if position.y < -5:
		position = Vector3(0, 1, 4)
		velocity = Vector3.ZERO


func clear_effects() -> void:
	glide_remaining = 0
	dash_remaining = 0
	underwater_remaining = 0
	velocity = Vector3.ZERO
	external_velocity = Vector3.ZERO
