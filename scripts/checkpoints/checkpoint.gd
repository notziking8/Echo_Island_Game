class_name Checkpoint
extends Area3D

signal checkpoint_activated(checkpoint: Checkpoint, activator: Node3D)

@export var spawn_offset: Vector3 = Vector3(0.0, 0.5, 0.0)
@export var inactive_color: Color = Color(0.2, 0.4, 0.6)
@export var active_color: Color = Color(0.0, 0.9, 1.0)

var is_active: bool = false

@onready var marker_mesh: MeshInstance3D = $MarkerMesh

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_update_visuals()

func _on_body_entered(body: Node3D) -> void:
	if body.has_method("set_checkpoint"):
		activate(body)

func activate(activator: Node3D) -> void:
	if is_active:
		return
	is_active = true
	_update_visuals()
	if activator.has_method("set_checkpoint"):
		activator.set_checkpoint(self)
	checkpoint_activated.emit(self, activator)
	print("[Checkpoint] Activated: %s by %s" % [name, activator.name])

func deactivate() -> void:
	is_active = false
	_update_visuals()

func get_respawn_position() -> Vector3:
	return global_position + spawn_offset

func _update_visuals() -> void:
	if marker_mesh:
		var mat = StandardMaterial3D.new()
		mat.albedo_color = active_color if is_active else inactive_color
		if is_active:
			mat.emission_enabled = true
			mat.emission = active_color
			mat.emission_energy_multiplier = 1.0
		marker_mesh.material_override = mat
