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
	if node.has_signal("combat_event") and not node.combat_event.is_connected(_forward_combat_event):
		node.combat_event.connect(_forward_combat_event)


func receive_ability_event(event: Dictionary) -> void:
	var target: Variant = _targets.get(str(event.get("target_id", "")))
	if not is_instance_valid(player) or not is_instance_valid(target) or player.global_position.distance_to(target.global_position) > reach or not preload("res://systems/combat/attack_data.gd").clear_line(player, target):
		echo_system.receive_ability_response({"request_id": event.get("request_id", ""), "target_id": event.get("target_id", ""), "success": false, "resulting_status": "out_of_range_or_missing"})
		return
	var routed := event.duplicate(true)
	routed.origin = player.global_position
	var is_new: bool = not _resolved_requests.has(str(event.get("request_id", "")))
	super.receive_ability_event(routed)
	if is_new and event.get("echo_id") == "time" and target._status_remaining.has("slow"):
		var field := preload("res://systems/combat/time_field.gd").new()
		field.position = target.global_position
		field.source = player
		get_parent().add_child(field)

func affected_targets(primary: Node, event: Dictionary) -> Array[Node]:
	var result: Array[Node] = [primary]
	var radius: float = {"earth": 1.8, "wind": 2.0, "water": 1.4, "time": 3.0}.get(event.get("echo_id"), 0.0)
	for candidate: Node in _targets.values():
		if not is_instance_valid(candidate) or candidate == primary or not candidate is Node3D:
			continue
		if candidate.global_position.distance_to(primary.global_position) <= radius and candidate.global_position.distance_to(player.global_position) <= reach and preload("res://systems/combat/attack_data.gd").clear_line(player, candidate):
			result.append(candidate)
	return result
