class_name Interactable
extends Area3D

signal interacted(interactor: Node3D)

@export var prompt_message: String = "Interact"
@export var is_interactable: bool = true
@export var requires_echo: bool = false
@export var echo_type: String = ""

func interact(interactor: Node3D) -> void:
	if not is_interactable:
		return
	interacted.emit(interactor)
	_execute_interaction(interactor)

func _execute_interaction(_interactor: Node3D) -> void:
	# Virtual method to be overridden by derived interactable objects
	pass
