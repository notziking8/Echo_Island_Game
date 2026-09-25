class_name CombatSystem
extends Node
## Owns Combat's side of Echo's AbilityEvent/AbilityResponse contract.

@export var echo_system: Node
var _targets: Dictionary = {}


func _ready() -> void:
	for node: Node in get_tree().get_nodes_in_group("combat_targets"):
		_register_target(node)
	get_tree().node_added.connect(_on_node_added)
	if echo_system and echo_system.has_signal("AbilityEvent"):
		echo_system.connect("AbilityEvent", receive_ability_event)


func receive_ability_event(event: Dictionary) -> void:
	var target: Variant = _targets.get(str(event.get("target_id", "")))
	var success: bool = target != null and is_instance_valid(target) and bool(target.apply_echo_event(event))
	var response := {
		"request_id": event.get("request_id", ""),
		"target_id": event.get("target_id", ""),
		"success": success,
		"resulting_status": str(event.get("intended_effect", "")) if success else "rejected",
	}
	if echo_system and echo_system.has_method("receive_ability_response"):
		echo_system.receive_ability_response(response)


func _on_node_added(node: Node) -> void:
	if node.is_in_group("combat_targets"):
		_register_target(node)


func _register_target(node: Node) -> void:
	var id := str(node.get("target_id"))
	if not id.is_empty():
		_targets[id] = node
