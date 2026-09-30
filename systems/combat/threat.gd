extends Node3D
## Swept projectile / telegraphed area damage; ribbon visuals, no proxy characters.
const Data = preload("res://systems/combat/attack_data.gd")
var source: Node3D
var actor: Node3D
var kind := "projectile"
var damage := 10.0
var direction := Vector3.FORWARD
var age := 0.0
var ring: MeshInstance3D

func _ready() -> void:
	ring = MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = 1.9 if kind == "hazard" else 0.1
	mesh.outer_radius = 2.0 if kind == "hazard" else 0.16
	mesh.rings = 32
	mesh.ring_segments = 6
	ring.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("ff7a59")
	material.emission_enabled = true
	material.emission = Color("ffd166")
	ring.material_override = material
	ring.position.y = 0.06 if kind == "hazard" else 0
	add_child(ring)

func _physics_process(delta: float) -> void:
	age += delta
	if not is_instance_valid(actor) or not is_instance_valid(source) or source.state == 6 or age > 5:
		queue_free()
		return
	if kind == "hazard":
		ring.scale = Vector3.ONE * (0.85 + sin(age * 12) * 0.1)
		if age >= 0.7:
			if actor.global_position.distance_to(global_position) <= 2.0 and Data.clear_line(self, actor) and actor.has_method("receive_combat_damage"):
				actor.receive_combat_damage(damage, source)
			queue_free()
	else:
		var destination := global_position + direction.normalized() * 6.0 * delta
		var ray := PhysicsRayQueryParameters3D.create(global_position, destination, 1)
		ray.exclude = [source.get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty():
			if hit.collider == actor and actor.has_method("receive_combat_damage"):
				actor.receive_combat_damage(damage, source)
			queue_free()
		else:
			global_position = destination
