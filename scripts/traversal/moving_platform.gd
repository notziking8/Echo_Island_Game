class_name MovingPlatform
extends AnimatableBody3D

@export var travel_offset: Vector3 = Vector3(0.0, 0.5, -13.0)
@export var travel_time: float = 3.5
@export var pause_time: float = 1.0
@export var auto_start: bool = true

var _start_position: Vector3 = Vector3.ZERO
var _target_position: Vector3 = Vector3.ZERO
var _timer: float = 0.0
var _moving_forward: bool = true
var _paused: bool = false
var _pause_timer: float = 0.0

func _ready() -> void:
	sync_to_physics = false
	_start_position = global_position
	_target_position = _start_position + travel_offset

func _physics_process(delta: float) -> void:
	if not auto_start:
		return

	if _paused:
		_pause_timer -= delta
		if _pause_timer <= 0.0:
			_paused = false
		return

	_timer += delta / maxf(travel_time, 0.01)
	var t: float = clampf(_timer, 0.0, 1.0)
	# Smoothstep curve for natural momentum feel
	var smooth_t: float = t * t * (3.0 - 2.0 * t)

	if _moving_forward:
		global_position = _start_position.lerp(_target_position, smooth_t)
	else:
		global_position = _target_position.lerp(_start_position, smooth_t)

	if t >= 1.0:
		_timer = 0.0
		_moving_forward = not _moving_forward
		_paused = true
		_pause_timer = pause_time
