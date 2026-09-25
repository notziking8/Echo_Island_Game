extends "res://systems/echo/earth_target.gd"
## Adapts the flat sandbox object's placement to the Traversal island's world-space terrain.


func can_place(at: Vector3, size: Vector3) -> bool:
	if not at.is_finite() or absf(at.x) > 60 or absf(at.z) > 80 or absf(at.y) > 30:
		return false
	for x in [-0.45, 0.45]:
		for z in [-0.45, 0.45]:
			var corner := at + Vector3(size.x * x, 0.2, size.z * z)
			var ray := PhysicsRayQueryParameters3D.create(corner, corner - Vector3.UP * 0.5, 1)
			ray.exclude = [get_rid()]
			var hit := get_world_3d().direct_space_state.intersect_ray(ray)
			if hit.is_empty() or hit["normal"].y < 0.8 or hit["collider"].name == "Ocean":
				return false
	var box := BoxShape3D.new()
	box.size = size * 0.96
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = box
	query.transform = Transform3D(Basis.IDENTITY, at + Vector3.UP * size.y * 0.5)
	query.exclude = [get_rid()]
	query.collision_mask = 1
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()
