extends "res://systems/echo/echo_input.gd"
## Megan's captured camera aims at the center; free cursor mode still supports mouse targeting.


func aim_position() -> Vector2:
	return camera.get_viewport().get_visible_rect().size * 0.5 if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else camera.get_viewport().get_mouse_position()


func _update_target() -> void:
	if is_instance_valid(target):
		target.set_highlight(false)
	target = null
	var start := camera.project_ray_origin(aim_position())
	var ray := PhysicsRayQueryParameters3D.create(start, start + camera.project_ray_normal(aim_position()) * 100, 5)
	ray.exclude = [actor.get_rid()]
	var hit := camera.get_world_3d().direct_space_state.intersect_ray(ray)
	var aimed: Node3D
	if not hit.is_empty() and (hit["collider"] is EarthTarget or hit["collider"].has_method("echo_action")):
		aimed = hit["collider"]
		if actor.global_position.distance_to(aimed.global_position) > reach:
			aimed = null
	# Aimed puzzle and environment targets outrank combat. Enemies are otherwise
	# selected automatically once the player is close enough to fight.
	if is_instance_valid(aimed) and not aimed.is_in_group("combat_targets") and _has_power_action(aimed):
		target = aimed
	else:
		var nearest_distance := 4.5
		for node: Node in get_tree().get_nodes_in_group("combat_targets"):
			if not node is Node3D or float(node.get("health")) <= 0.0:
				continue
			var enemy := node as Node3D
			var distance := actor.global_position.distance_to(enemy.global_position)
			if distance < nearest_distance:
				nearest_distance = distance
				target = enemy
		if not is_instance_valid(target) and is_instance_valid(aimed):
			target = aimed
	if is_instance_valid(target):
		target.set_highlight(true)


func _has_power_action(candidate: Node3D) -> bool:
	for element in [system.selected_power(), system.personal_power()]:
		if not str(element).is_empty() and (not _action_for(candidate, element, false).is_empty() or not _action_for(candidate, element, true).is_empty()):
			return true
	return false


func prompt() -> String:
	if is_instance_valid(wheel) and wheel.is_open:
		return "Release Tab to select. Esc cancels."
	return context_hint("echo_primary") + "    " + context_hint("echo_personal")


func _update_preview() -> void:
	var start := camera.project_ray_origin(aim_position())
	var ray := PhysicsRayQueryParameters3D.create(start, start + camera.project_ray_normal(aim_position()) * 100, 1)
	ray.exclude = [actor.get_rid(), _locked_target.get_rid()]
	var hit := camera.get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty():
		cancel()
		return
	_destination = hit["position"]
	var box := BoxMesh.new()
	box.size = _locked_target.dimensions()
	preview.mesh = box
	preview.global_position = _destination + Vector3.UP * box.size.y * 0.5
	var valid: bool = actor.global_position.distance_to(_destination) <= reach and _locked_target.can_place(_destination, box.size)
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.4, 1, 0.5, 0.45) if valid else Color(1, 0.25, 0.2, 0.45)
	preview.material_override = material
	preview.visible = true
