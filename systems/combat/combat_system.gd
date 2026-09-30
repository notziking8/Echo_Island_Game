class_name CombatSystem
extends Node
## Owns Combat's side of Echo's AbilityEvent/AbilityResponse contract.

@export var echo_system: Node
var _targets: Dictionary = {}
var _resolved_requests: Dictionary = {}


func _ready() -> void:
	for node: Node in get_tree().get_nodes_in_group("combat_targets"):
		_register_target(node)
	get_tree().node_added.connect(_on_node_added)
	if echo_system and echo_system.has_signal("AbilityEvent"):
		echo_system.connect("AbilityEvent", receive_ability_event)


func receive_ability_event(event: Dictionary) -> void:
	var id := str(event.get("request_id", ""))
	if id.is_empty() or _resolved_requests.has(id):
		return
	_resolved_requests[id] = true
	if _resolved_requests.size() > 512:
		_resolved_requests.erase(_resolved_requests.keys()[0])
	var target: Variant = _targets.get(str(event.get("target_id", "")))
	var results: Array[Dictionary] = []
	if is_instance_valid(target):
		for candidate: Node in affected_targets(target, event):
			var routed := event.duplicate(true)
			routed.target_id = candidate.target_id
			var result: Dictionary
			if candidate.has_method("status_result"):
				result = candidate.status_result(routed)
			else:
				var applied: bool = candidate.apply_echo_event(routed)
				result = {"target_id": candidate.target_id, "success": applied, "outcome": "applied" if applied else "failed", "resulting_status": event.get("intended_effect", "") if applied else "rejected", "armor_type": "unknown"}
			results.append(result)
	var success := false
	for result in results:
		success = success or result.success
	var response := {
		"request_id": event.get("request_id", ""),
		"target_id": event.get("target_id", ""),
		"success": success,
		"resulting_status": str(event.get("intended_effect", "")) if success else "rejected",
		"outcome": "applied" if success else ("resisted" if not results.is_empty() and results[0].outcome == "resisted" else "failed"),
		"armor_type": results[0].armor_type if not results.is_empty() else "unknown",
		"affected_targets": results,
	}
	if echo_system and echo_system.has_method("receive_ability_response"):
		echo_system.receive_ability_response(response)

func affected_targets(primary: Node, _event: Dictionary) -> Array[Node]:
	return [primary]

func _forward_combat_event(event: Dictionary) -> void:
	if is_instance_valid(echo_system) and echo_system.has_method("receive_combat_event"):
		echo_system.receive_combat_event(event)


func _on_node_added(node: Node) -> void:
	if node.is_in_group("combat_targets"):
		_register_target(node)


func _register_target(node: Node) -> void:
	var id := str(node.get("target_id"))
	if not id.is_empty():
		_targets[id] = node
		if node.has_signal("combat_event") and not node.combat_event.is_connected(_forward_combat_event):
			node.combat_event.connect(_forward_combat_event)
