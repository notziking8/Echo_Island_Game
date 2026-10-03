class_name Player
extends CharacterBody3D

signal state_changed(old_state: MovementState, new_state: MovementState)
signal respawned(respawn_position: Vector3)
signal EchoInteractionEvent(target: Object, interaction_data: Dictionary)
signal echo_step_performed(position: Vector3)
signal mantled(ledge_position: Vector3)
signal slide_started

enum MovementState {
	GROUNDED,
	FALLING,
	SWIMMING,
	GLIDING,
	MANTLING,
	SLIDING,
}

@export_group("Movement")
@export var move_speed: float = 6.0
@export var jump_velocity: float = 4.5
@export var acceleration: float = 24.0
@export var deceleration: float = 28.0
@export var rotation_speed: float = 12.0
@export var floor_snap_distance: float = 0.3

@export_group("Ledge & Mantle")
@export var mantle_reach: float = 0.65
@export var mantle_min_height: float = 0.5
@export var mantle_max_height: float = 2.05
@export var mantle_duration: float = 0.32

@export_group("Slide")
@export var min_slide_speed: float = 1.8
@export var max_slide_speed: float = 18.0
@export var slide_friction: float = 12.0
@export var slide_slope_accel_multiplier: float = 1.7
@export var min_slide_angle_deg: float = 10.0

@export_group("Echo Step")
@export var echo_step_strength: float = 6.0
@export var echo_step_vertical_lift: float = 3.4
@export var echo_step_unlocked: bool = false

@export_group("Camera")
@export var mouse_sensitivity: float = 0.003
@export var min_pitch: float = -75.0
@export var max_pitch: float = 60.0

@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D
@onready var visuals: Node3D = $Visuals
@onready var interaction_ray: RayCast3D = $Visuals/InteractionRay

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var current_state: MovementState = MovementState.GROUNDED
var spawn_position: Vector3 = Vector3.ZERO
var current_checkpoint: Node3D = null

# Traversal state trackers
var echo_system: Node = null
var echo_step_used: bool = false
var mantle_start_pos: Vector3 = Vector3.ZERO
var mantle_target_pos: Vector3 = Vector3.ZERO
var mantle_timer: float = 0.0

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	spawn_position = global_position
	floor_snap_length = floor_snap_distance
	floor_constant_speed = true
	floor_stop_on_slope = true
	if spring_arm:
		spring_arm.add_excluded_object(get_rid())
	
	# Fallback registration for slide action if not loaded from project settings
	if not InputMap.has_action("slide"):
		InputMap.add_action("slide")
		var key_c := InputEventKey.new()
		key_c.physical_keycode = KEY_C
		InputMap.action_add_event("slide", key_c)
		var key_shift := InputEventKey.new()
		key_shift.physical_keycode = KEY_SHIFT
		InputMap.action_add_event("slide", key_shift)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if camera_pivot:
			camera_pivot.rotate_y(-event.relative.x * mouse_sensitivity)
		if spring_arm:
			spring_arm.rotate_x(-event.relative.y * mouse_sensitivity)
			spring_arm.rotation.x = clamp(
				spring_arm.rotation.x,
				deg_to_rad(min_pitch),
				deg_to_rad(max_pitch)
			)
	
	if event.is_action_pressed("interact"):
		_try_interact()
	
	if event.is_action_pressed("debug_respawn"):
		respawn()
	
	if event.is_action_pressed("debug_glide"):
		TraversalAbilityEvent("glide")
	
	if event.is_action_pressed("debug_swim"):
		TraversalAbilityEvent("swim")
	
	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	match current_state:
		MovementState.GROUNDED:
			_process_grounded(delta)
		MovementState.FALLING:
			_process_falling(delta)
		MovementState.SWIMMING:
			_process_swimming(delta)
		MovementState.GLIDING:
			_process_gliding(delta)
		MovementState.MANTLING:
			_process_mantling(delta)
		MovementState.SLIDING:
			_process_sliding(delta)

	if current_state != MovementState.MANTLING and current_state != MovementState.SLIDING:
		_apply_horizontal_movement(delta)

	if current_state != MovementState.MANTLING:
		move_and_slide()
		_update_state_transitions()

func _process_grounded(_delta: float) -> void:
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity
		transition_to(MovementState.FALLING)
	elif Input.is_action_just_pressed("slide") and is_on_floor():
		var h_speed: float = Vector2(velocity.x, velocity.z).length()
		var floor_angle: float = get_floor_angle()
		if h_speed >= min_slide_speed or floor_angle >= deg_to_rad(min_slide_angle_deg):
			transition_to(MovementState.SLIDING)

func _process_falling(delta: float) -> void:
	velocity.y -= gravity * delta

	# Check for Ledge Grab / Mantle opportunity
	if _check_ledge_grab():
		return

	# Check for Echo Step midair correction
	if Input.is_action_just_pressed("jump") and is_echo_step_available():
		_perform_echo_step()

func _process_swimming(delta: float) -> void:
	# Placeholder swimming neutral buoyancy
	velocity.y = move_toward(velocity.y, 0.0, 6.0 * delta)

func _process_gliding(delta: float) -> void:
	# Placeholder gentle gliding descent
	velocity.y = max(velocity.y - (gravity * 0.15 * delta), -1.8)

	# Gliding can catch a ledge on contact
	if _check_ledge_grab():
		return

func _process_mantling(delta: float) -> void:
	mantle_timer += delta
	var progress: float = clampf(mantle_timer / maxf(mantle_duration, 0.05), 0.0, 1.0)

	# S-curve easing: rise vertically to clear ledge, then slide forward onto surface
	var t_vert: float = sin(progress * PI * 0.5)
	var t_horiz: float = progress * progress

	global_position.y = lerpf(mantle_start_pos.y, mantle_target_pos.y, t_vert)
	global_position.x = lerpf(mantle_start_pos.x, mantle_target_pos.x, t_horiz)
	global_position.z = lerpf(mantle_start_pos.z, mantle_target_pos.z, t_horiz)

	if progress >= 1.0:
		global_position = mantle_target_pos
		velocity = Vector3.ZERO
		transition_to(MovementState.GROUNDED)
		mantled.emit(mantle_target_pos)

func _process_sliding(delta: float) -> void:
	if not is_on_floor():
		transition_to(MovementState.FALLING)
		return

	# Slide jump carries forward momentum
	if Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity * 1.05
		transition_to(MovementState.FALLING)
		return

	var floor_normal: Vector3 = get_floor_normal()
	var slope_angle: float = get_floor_angle()
	var min_angle_rad: float = deg_to_rad(min_slide_angle_deg)

	# Downhill vector along the floor plane
	var downhill: Vector3 = (Vector3.DOWN - floor_normal * Vector3.DOWN.dot(floor_normal))
	if downhill.length_squared() > 0.001:
		downhill = downhill.normalized()
	else:
		downhill = Vector3.ZERO

	var current_horizontal_vel := Vector3(velocity.x, 0.0, velocity.z)
	var h_speed: float = current_horizontal_vel.length()

	# Downhill slope acceleration
	if slope_angle >= min_angle_rad and downhill != Vector3.ZERO:
		var downhill_dot: float = current_horizontal_vel.dot(downhill) if h_speed > 0.1 else 1.0
		if downhill_dot >= -0.3:
			# Heading downhill: gravity boosts downhill velocity
			var slope_accel: float = gravity * sin(slope_angle) * slide_slope_accel_multiplier
			velocity.x += downhill.x * slope_accel * delta
			velocity.z += downhill.z * slope_accel * delta
		else:
			# Moving uphill: strong deceleration
			velocity.x = move_toward(velocity.x, 0.0, deceleration * 1.5 * delta)
			velocity.z = move_toward(velocity.z, 0.0, deceleration * 1.5 * delta)
	else:
		# Flat or mild terrain: gradual friction slows the slide
		velocity.x = move_toward(velocity.x, 0.0, slide_friction * delta)
		velocity.z = move_toward(velocity.z, 0.0, slide_friction * delta)

	# Allow subtle steering while sliding
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	if input_dir.x != 0.0 and camera:
		var cam_basis: Basis = camera.global_transform.basis
		var right: Vector3 = Vector3(cam_basis.x.x, 0.0, cam_basis.x.z).normalized()
		velocity += right * (input_dir.x * 8.0 * delta)

	# Cap maximum slide speed to prevent physics instability
	var new_h_speed: float = Vector2(velocity.x, velocity.z).length()
	if new_h_speed > max_slide_speed:
		var clamped_dir := Vector3(velocity.x, 0.0, velocity.z).normalized()
		velocity.x = clamped_dir.x * max_slide_speed
		velocity.z = clamped_dir.z * max_slide_speed

	# Visual orientation follows slide motion
	if visuals and new_h_speed > 0.5:
		var target_rot_y: float = atan2(-velocity.x, -velocity.z)
		visuals.rotation.y = lerp_angle(visuals.rotation.y, target_rot_y, rotation_speed * delta)

	# Natural slide completion on flat ground when speed drops
	if new_h_speed < 1.6 and slope_angle < min_angle_rad:
		transition_to(MovementState.GROUNDED)

func _update_state_transitions() -> void:
	match current_state:
		MovementState.GROUNDED:
			if not is_on_floor():
				transition_to(MovementState.FALLING)
		MovementState.FALLING:
			if is_on_floor() and velocity.y <= 0.0:
				echo_step_used = false
				if Input.is_action_pressed("slide"):
					var h_speed: float = Vector2(velocity.x, velocity.z).length()
					if h_speed >= min_slide_speed or get_floor_angle() >= deg_to_rad(min_slide_angle_deg):
						transition_to(MovementState.SLIDING)
						return
				transition_to(MovementState.GROUNDED)
		MovementState.SWIMMING:
			if is_on_floor() and velocity.y <= 0.0:
				echo_step_used = false
				transition_to(MovementState.GROUNDED)
		MovementState.GLIDING:
			if is_on_floor():
				echo_step_used = false
				if Input.is_action_pressed("slide"):
					var h_speed: float = Vector2(velocity.x, velocity.z).length()
					if h_speed >= min_slide_speed or get_floor_angle() >= deg_to_rad(min_slide_angle_deg):
						transition_to(MovementState.SLIDING)
						return
				transition_to(MovementState.GROUNDED)
		MovementState.SLIDING:
			if not is_on_floor():
				transition_to(MovementState.FALLING)
		MovementState.MANTLING:
			pass

func transition_to(new_state: MovementState) -> void:
	if current_state == new_state:
		return
	var old_state: MovementState = current_state
	current_state = new_state
	_on_state_exited(old_state)
	_on_state_entered(new_state)
	state_changed.emit(old_state, new_state)

func _on_state_entered(state: MovementState) -> void:
	match state:
		MovementState.GROUNDED:
			floor_snap_length = floor_snap_distance
			echo_step_used = false
		MovementState.FALLING:
			floor_snap_length = 0.0
		MovementState.SWIMMING:
			floor_snap_length = 0.0
			echo_step_used = false
		MovementState.GLIDING:
			floor_snap_length = 0.0
		MovementState.MANTLING:
			floor_snap_length = 0.0
			velocity = Vector3.ZERO
		MovementState.SLIDING:
			floor_snap_length = 0.5
			slide_started.emit()
			if visuals:
				visuals.scale = Vector3(1.0, 0.65, 1.0)

func _on_state_exited(state: MovementState) -> void:
	if state == MovementState.SLIDING:
		if visuals:
			visuals.scale = Vector3.ONE

func _apply_horizontal_movement(delta: float) -> void:
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var move_direction: Vector3 = Vector3.ZERO

	if input_dir != Vector2.ZERO:
		if camera:
			var cam_basis: Basis = camera.global_transform.basis
			var forward: Vector3 = Vector3(cam_basis.z.x, 0.0, cam_basis.z.z).normalized()
			var right: Vector3 = Vector3(cam_basis.x.x, 0.0, cam_basis.x.z).normalized()
			move_direction = (right * input_dir.x + forward * input_dir.y).normalized()
		else:
			move_direction = Vector3(input_dir.x, 0.0, input_dir.y).normalized()

	if move_direction != Vector3.ZERO:
		velocity.x = move_toward(velocity.x, move_direction.x * move_speed, acceleration * delta)
		velocity.z = move_toward(velocity.z, move_direction.z * move_speed, acceleration * delta)
		
		if visuals:
			var target_rot_y: float = atan2(-move_direction.x, -move_direction.z)
			visuals.rotation.y = lerp_angle(visuals.rotation.y, target_rot_y, rotation_speed * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, deceleration * delta)

func get_state_name() -> String:
	match current_state:
		MovementState.GROUNDED: return "GROUNDED"
		MovementState.FALLING: return "FALLING"
		MovementState.SWIMMING: return "SWIMMING"
		MovementState.GLIDING: return "GLIDING"
		MovementState.MANTLING: return "MANTLING"
		MovementState.SLIDING: return "SLIDING"
		_: return "UNKNOWN"

# --- Ledge Detection and Mantle ---
func _check_ledge_grab() -> bool:
	var space_state := get_world_3d().direct_space_state
	if not space_state:
		return false

	var check_dir: Vector3 = Vector3.ZERO
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	if input_dir.length_squared() > 0.01 and camera:
		var cam_basis: Basis = camera.global_transform.basis
		var fwd: Vector3 = Vector3(cam_basis.z.x, 0.0, cam_basis.z.z).normalized()
		var rgt: Vector3 = Vector3(cam_basis.x.x, 0.0, cam_basis.x.z).normalized()
		check_dir = (rgt * input_dir.x + fwd * input_dir.y).normalized()
	elif visuals:
		check_dir = -visuals.global_transform.basis.z.normalized()
		check_dir.y = 0.0
		check_dir = check_dir.normalized()
	else:
		check_dir = -global_transform.basis.z.normalized()
		check_dir.y = 0.0
		check_dir = check_dir.normalized()

	if check_dir.length_squared() < 0.01:
		check_dir = -global_transform.basis.z

	# 1. Forward checks: check shin/knee (0.3m), waist (0.7m), and chest (1.2m) for vertical wall face
	var wall_hit: Dictionary = {}
	for check_y_offset: float in [0.3, 0.7, 1.2]:
		var ray_start := Vector3(global_position.x, global_position.y + check_y_offset, global_position.z)
		var ray_end := ray_start + check_dir * (0.4 + mantle_reach)
		var wall_query := PhysicsRayQueryParameters3D.create(ray_start, ray_end, 1)
		wall_query.exclude = [get_rid()]
		var hit := space_state.intersect_ray(wall_query)
		if not hit.is_empty() and absf(hit["normal"].y) <= 0.35:
			wall_hit = hit
			break

	if wall_hit.is_empty():
		return false

	var wall_normal: Vector3 = wall_hit["normal"]

	# 2. High overhead ray: check if the wall extends too high (prevents climbing infinite walls)
	var high_y: float = global_position.y + mantle_max_height
	var high_start := Vector3(global_position.x, high_y, global_position.z)
	var high_end := high_start + check_dir * (0.4 + mantle_reach + 0.35)

	var high_query := PhysicsRayQueryParameters3D.create(high_start, high_end, 1)
	high_query.exclude = [get_rid()]
	var high_hit := space_state.intersect_ray(high_query)
	if not high_hit.is_empty():
		return false

	# 3. Downward ray: locate the flat top surface of the ledge
	var wall_point: Vector3 = wall_hit["position"]
	var inward_dir: Vector3 = -Vector3(wall_normal.x, 0.0, wall_normal.z).normalized()
	var down_start: Vector3 = wall_point + inward_dir * 0.3 + Vector3(0, (mantle_max_height - 0.6) + 0.1, 0)
	var down_end: Vector3 = down_start - Vector3(0, (mantle_max_height - mantle_min_height) + 0.5, 0)

	var down_query := PhysicsRayQueryParameters3D.create(down_start, down_end, 1)
	down_query.exclude = [get_rid()]
	var down_hit := space_state.intersect_ray(down_query)
	if down_hit.is_empty():
		return false

	var ledge_point: Vector3 = down_hit["position"]
	var ledge_normal: Vector3 = down_hit["normal"]
	if ledge_normal.y < 0.8:
		return false

	var ledge_height: float = ledge_point.y - global_position.y
	if ledge_height < mantle_min_height or ledge_height > mantle_max_height:
		return false

	# 4. Stand clearance check: verify capsule fits on top of the surface
	var target_stand_pos := Vector3(ledge_point.x + inward_dir.x * 0.15, ledge_point.y, ledge_point.z + inward_dir.z * 0.15)
	var cap_shape := CapsuleShape3D.new()
	cap_shape.radius = 0.38
	cap_shape.height = 1.7

	var clearance_query := PhysicsShapeQueryParameters3D.new()
	clearance_query.shape = cap_shape
	clearance_query.transform = Transform3D(Basis.IDENTITY, target_stand_pos + Vector3(0, 0.88, 0))
	clearance_query.collision_mask = 1
	clearance_query.exclude = [get_rid()]
	var obstructions := space_state.intersect_shape(clearance_query, 1)
	if not obstructions.is_empty():
		return false

	mantle_start_pos = global_position
	mantle_target_pos = target_stand_pos
	mantle_timer = 0.0
	velocity = Vector3.ZERO
	if visuals:
		visuals.rotation.y = atan2(-check_dir.x, -check_dir.z)
	transition_to(MovementState.MANTLING)
	return true

# --- Echo Step Mechanic ---
func is_echo_step_available() -> bool:
	if echo_step_used:
		return false
	if is_instance_valid(echo_system):
		if "collected_stones" in echo_system and echo_system.collected_stones.size() > 0:
			return true
		if "generation" in echo_system and echo_system.generation >= 2:
			return true
		if "active_echo" in echo_system and not echo_system.active_echo.is_empty():
			return true
		return false
	return echo_step_unlocked

func _perform_echo_step() -> void:
	echo_step_used = true

	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var step_dir: Vector3 = Vector3.ZERO

	if input_dir != Vector2.ZERO and camera:
		var cam_basis: Basis = camera.global_transform.basis
		var forward: Vector3 = Vector3(cam_basis.z.x, 0.0, cam_basis.z.z).normalized()
		var right: Vector3 = Vector3(cam_basis.x.x, 0.0, cam_basis.x.z).normalized()
		step_dir = (right * input_dir.x + forward * input_dir.y).normalized()
	elif visuals:
		step_dir = -visuals.global_transform.basis.z.normalized()
		step_dir.y = 0.0
		step_dir = step_dir.normalized()
	else:
		step_dir = -global_transform.basis.z.normalized()
		step_dir.y = 0.0
		step_dir = step_dir.normalized()

	if step_dir.length_squared() < 0.01:
		step_dir = Vector3.FORWARD

	velocity.x = step_dir.x * echo_step_strength
	velocity.z = step_dir.z * echo_step_strength
	velocity.y = echo_step_vertical_lift

	if visuals:
		visuals.rotation.y = atan2(-step_dir.x, -step_dir.z)

	echo_step_performed.emit(global_position)
	_spawn_echo_step_vfx()

func _spawn_echo_step_vfx() -> void:
	if not is_inside_tree():
		return
	var pulse := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.6
	cylinder.bottom_radius = 0.4
	cylinder.height = 0.06
	pulse.mesh = cylinder
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.4, 0.9, 0.95, 0.7)
	mat.emission_enabled = true
	mat.emission = Color(0.4, 0.85, 0.95)
	mat.emission_energy_multiplier = 1.2
	pulse.material_override = mat
	pulse.top_level = true
	get_tree().root.add_child(pulse)
	pulse.global_position = global_position + Vector3(0, 0.1, 0)
	var tween := pulse.create_tween()
	if tween:
		tween.tween_property(pulse, "scale", Vector3(1.8, 1.0, 1.8), 0.22)
		tween.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.22)
		tween.tween_callback(pulse.queue_free)
	else:
		pulse.queue_free()

func _try_interact() -> void:
	var interactable = get_focused_interactable()
	if not interactable:
		return
	
	var echo_data: Dictionary = {}
	if "requires_echo" in interactable and interactable.requires_echo:
		echo_data["requires_echo"] = true
		if "echo_type" in interactable:
			echo_data["echo_type"] = interactable.echo_type
		EchoInteractionEvent.emit(interactable, echo_data)
	
	if interactable.has_method("interact"):
		interactable.interact(self)

func trigger_echo_interaction(target: Object, data: Dictionary = {}) -> void:
	EchoInteractionEvent.emit(target, data)

func TraversalAbilityEvent(ability_name: String, ability_data: Dictionary = {}) -> void:
	print("[Player] TraversalAbilityEvent received: %s, data: %s" % [ability_name, str(ability_data)])
	match ability_name.to_lower():
		"glide":
			transition_to(MovementState.GLIDING)
		"swim":
			transition_to(MovementState.SWIMMING)
		_:
			print("[Player] Unhandled traversal ability request: %s" % ability_name)

func get_focused_interactable() -> Object:
	if not interaction_ray or not interaction_ray.is_colliding():
		return null
	var collider: Object = interaction_ray.get_collider()
	if not collider:
		return null
	if collider.has_method("interact"):
		return collider
	elif collider.get_parent() and collider.get_parent().has_method("interact"):
		return collider.get_parent()
	elif collider.has_node("Interactable"):
		return collider.get_node("Interactable")
	return null

func set_checkpoint(checkpoint: Node3D) -> void:
	if current_checkpoint and current_checkpoint != checkpoint and current_checkpoint.has_method("deactivate"):
		current_checkpoint.deactivate()
	current_checkpoint = checkpoint
	print("[Player] Active checkpoint set to: %s" % checkpoint.name)

func respawn() -> void:
	velocity = Vector3.ZERO
	echo_step_used = false
	var target_pos: Vector3 = spawn_position
	if current_checkpoint and is_instance_valid(current_checkpoint):
		if current_checkpoint.has_method("get_respawn_position"):
			target_pos = current_checkpoint.get_respawn_position()
		else:
			target_pos = current_checkpoint.global_position
	
	global_position = target_pos
	transition_to(MovementState.GROUNDED)
	floor_snap_length = floor_snap_distance
	respawned.emit(target_pos)
	print("[Player] Respawned at %s" % str(target_pos))


