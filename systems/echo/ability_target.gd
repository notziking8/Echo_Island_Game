extends StaticBody3D
## Minimal target descriptor for a team-owned combat or traversal receiver.
## Effects are applied by the receiver connected to Echo's signals, never here.

@export var target_id: String = ""
@export_enum("combat", "traversal") var channel: String = "combat"
@export var actions: Dictionary = {"earth": "stun", "wind": "push", "water": "freeze", "time": "slow"}


func echo_action(element: String, _held: bool) -> String:
	return str(actions.get(element, ""))


func set_highlight(_enabled: bool) -> void:
	pass


func prompt() -> String:
	return "Q: active power | E: personal power"
