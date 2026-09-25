class_name TutorialTrigger
extends Area3D

@export var tutorial_message: String = ""
@export var action_to_dismiss: String = ""
@export var duration: float = 4.5

var has_triggered: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if has_triggered:
		return
	if body is CharacterBody3D or body.name == "Player":
		has_triggered = true
		print("[TutorialTrigger] Triggered: %s" % tutorial_message)
		var ui = get_tree().get_first_node_in_group("art_test_ui")
		if ui and ui.has_method("show_tutorial_message"):
			ui.show_tutorial_message(tutorial_message, action_to_dismiss, duration)
