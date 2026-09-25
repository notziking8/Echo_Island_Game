class_name Player
extends CharacterBody3D

signal state_changed(old_state: MovementState, new_state: MovementState)
signal respawned(respawn_position: Vector3)
signal EchoInteractionEvent(target: Object, interaction_data: Dictionary)

enum MovementState {
	GROUNDED,
	FALLING,
	SWIMMING,
	GLIDING,
}

@export_group("Movement")
@export var move_speed: float = 6.0
@export var jump_velocity: float = 4.5
@export var acceleration: float = 24.0
@export var deceleration: float = 28.0
@export var rotation_speed: float = 12.0
@export var floor_snap_distance: float = 0.3

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

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	spawn_position = global_position
	floor_snap_length = floor_snap_distance
	floor_constant_speed = true
	floor_stop_on_slope = true
	if spring_arm:
		spring_arm.add_excluded_object(get_rid())

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

	_apply_horizontal_movement(delta)
	move_and_slide()
	_update_state_transitions()

func _process_grounded(_delta: float) -> void:
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity
		transition_to(MovementState.FALLING)

func _process_falling(delta: float) -> void:
	velocity.y -= gravity * delta

func _process_swimming(delta: float) -> void:
	# Placeholder swimming neutral buoyancy
	velocity.y = move_toward(velocity.y, 0.0, 6.0 * delta)

func _process_gliding(delta: float) -> void:
	# Placeholder gentle gliding descent
	velocity.y = max(velocity.y - (gravity * 0.15 * delta), -1.8)

func _update_state_transitions() -> void:
	match current_state:
		MovementState.GROUNDED:
			if not is_on_floor():
				transition_to(MovementState.FALLING)
		MovementState.FALLING:
			if is_on_floor() and velocity.y <= 0.0:
				transition_to(MovementState.GROUNDED)
		MovementState.SWIMMING:
			if is_on_floor() and velocity.y <= 0.0:
				transition_to(MovementState.GROUNDED)
		MovementState.GLIDING:
			if is_on_floor():
				transition_to(MovementState.GROUNDED)

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
		MovementState.FALLING:
			floor_snap_length = 0.0
		MovementState.SWIMMING:
			floor_snap_length = 0.0
		MovementState.GLIDING:
			floor_snap_length = 0.0

func _on_state_exited(_state: MovementState) -> void:
	pass

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
		_: return "UNKNOWN"

func _try_interact() -> void:
	var interactable = get_focused_interactable()
	if not interactable:
		return
	
	# If the object requires or relates to an Echo ability, notify the Echo system
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

