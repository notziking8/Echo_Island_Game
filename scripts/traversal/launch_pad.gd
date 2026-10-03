class_name LaunchPad
extends Area3D

signal launched(body: Node3D, launch_velocity: Vector3)

@export var launch_velocity: Vector3 = Vector3(0.0, 14.5, -14.0)
@export var pad_color: Color = Color("ffd166") # island_art.GOLD
@export var glow_color: Color = Color("ff7a59") # island_art.CORAL
@export var cooldown: float = 0.35
@export var use_local_orientation: bool = false

var _ready_to_launch: bool = true
var _anim_tween: Tween = null

@onready var visuals: Node3D = get_node_or_null("Visuals")
@onready var pad_mesh: MeshInstance3D = get_node_or_null("Visuals/PadMesh")

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_setup_visuals()

func _setup_visuals() -> void:
	if not pad_mesh:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = pad_color
	mat.emission_enabled = true
	mat.emission = glow_color
	mat.emission_energy_multiplier = 0.9
	pad_mesh.material_override = mat

func _on_body_entered(body: Node3D) -> void:
	if not _ready_to_launch:
		return
	if not (body is CharacterBody3D or body.has_method("launch")):
		return

	_ready_to_launch = false
	var effective_vel: Vector3 = launch_velocity
	if use_local_orientation:
		effective_vel = global_transform.basis * launch_velocity

	if body.has_method("launch"):
		body.launch(effective_vel)
	elif "velocity" in body:
		body.velocity = effective_vel
		if body.has_method("transition_to") and "MovementState" in body:
			body.transition_to(body.MovementState.FALLING)

	launched.emit(body, effective_vel)
	_play_launch_fx()

	var tree := get_tree()
	if tree:
		await tree.create_timer(cooldown, false).timeout
		_ready_to_launch = true

func _play_launch_fx() -> void:
	if not visuals:
		return
	if _anim_tween and _anim_tween.is_valid():
		_anim_tween.kill()
	_anim_tween = create_tween()
	# Squash down on launch trigger, then spring up and settle
	_anim_tween.tween_property(visuals, "scale", Vector3(1.25, 0.4, 1.25), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_anim_tween.tween_property(visuals, "scale", Vector3(0.9, 1.35, 0.9), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_anim_tween.tween_property(visuals, "scale", Vector3.ONE, 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
