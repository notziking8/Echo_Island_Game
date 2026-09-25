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
	if not hit.is_empty() and (hit["collider"] is EarthTarget or hit["collider"].has_method("echo_action")):
		var candidate: Node3D = hit["collider"]
		if actor.global_position.distance_to(candidate.global_position) <= reach:
			target = candidate
			target.set_highlight(true)


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
