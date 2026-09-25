extends "res://systems/combat/combat_system.gd"
## Keeps Combat's effect logic, adding range validation and ready-safe dynamic registration.

var player: Node3D
var reach: float = 9.0


func _on_node_added(node: Node) -> void:
	# node_added runs before CombatEnemy._ready() joins combat_targets.
	_register_after_ready.call_deferred(weakref(node))


func _register_after_ready(reference: WeakRef) -> void:
	var node: Node = reference.get_ref()
	if is_instance_valid(node) and node.is_in_group("combat_targets"):
		_register_target(node)


func _register_target(node: Node) -> void:
	var id := str(node.get("target_id"))
	if id.is_empty() or not node.has_method("apply_echo_event"):
		return
	if _targets.has(id) and is_instance_valid(_targets[id]) and _targets[id] != node:
		push_warning("Duplicate Combat target ID: " + id)
		return
	_targets[id] = node


func receive_ability_event(event: Dictionary) -> void:
	var target: Variant = _targets.get(str(event.get("target_id", "")))
	if not is_instance_valid(player) or not is_instance_valid(target) or player.global_position.distance_to(target.global_position) > reach:
		echo_system.receive_ability_response({"request_id": event.get("request_id", ""), "target_id": event.get("target_id", ""), "success": false, "resulting_status": "out_of_range_or_missing"})
		return
	super.receive_ability_event(event)
