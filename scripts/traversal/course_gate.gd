class_name CourseGate
extends Area3D

enum GateType { START, FINISH }

signal player_passed(gate: CourseGate, player: Node3D)

@export var gate_type: GateType = GateType.START

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D or body.name == "Player":
		player_passed.emit(self, body)
