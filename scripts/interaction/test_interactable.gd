class_name TestInteractable
extends "res://scripts/interaction/interactable.gd"

@export var inactive_color: Color = Color(0.85, 0.65, 0.15)
@export var active_color: Color = Color(0.15, 0.85, 0.35)

var is_activated: bool = false
var interaction_count: int = 0

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

func _ready() -> void:
	_update_visuals()

func _execute_interaction(interactor: Node3D) -> void:
	is_activated = !is_activated
	interaction_count += 1
	_update_visuals()
	print("[TestInteractable] Interacted by %s! Count: %d, Activated: %s" % [interactor.name, interaction_count, str(is_activated)])

func _update_visuals() -> void:
	if mesh_instance:
		var mat = StandardMaterial3D.new()
		mat.albedo_color = active_color if is_activated else inactive_color
		if is_activated:
			mat.emission_enabled = true
			mat.emission = active_color
			mat.emission_energy_multiplier = 0.5
		mesh_instance.material_override = mat
