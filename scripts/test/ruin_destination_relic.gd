class_name RuinDestinationRelic
extends "res://scripts/interaction/interactable.gd"

signal destination_reached(activator: Node3D)

var is_activated: bool = false
var time_passed: float = 0.0

@onready var relic_mesh: MeshInstance3D = get_node_or_null("MeshInstance3D")
@onready var purple_light: OmniLight3D = get_node_or_null("OmniLight3D")

func _ready() -> void:
	prompt_message = "Claim Island Relic"
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	time_passed += delta
	if relic_mesh:
		relic_mesh.rotate_y(delta * 1.5)
		relic_mesh.rotate_x(delta * 0.8)

func _on_body_entered(body: Node3D) -> void:
	# Also trigger if player walks directly onto the altar
	if not is_activated and (body is CharacterBody3D or body.name == "Player"):
		_execute_interaction(body)

func _execute_interaction(interactor: Node3D) -> void:
	if is_activated:
		return
	is_activated = true
	destination_reached.emit(interactor)
	print("[RuinDestinationRelic] Final Relic Claimed by %s! Destination Reached!" % interactor.name)
	
	# Notify UI manager
	var ui = get_tree().get_first_node_in_group("art_test_ui")
	if ui and ui.has_method("on_destination_reached"):
		ui.on_destination_reached(self)
	
	if purple_light:
		purple_light.light_energy = 4.0
		purple_light.omni_range = 7.0
