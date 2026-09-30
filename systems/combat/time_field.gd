extends Node3D
## Four-second world-space aura; late entrants receive only the remaining lifetime.
var remaining := 4.0
var source: Node3D
var rings: Array[MeshInstance3D] = []

func _ready() -> void:
	for i in 2:
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 2.88 + i * 0.08
		torus.outer_radius = 2.91 + i * 0.08
		torus.rings = 48
		torus.ring_segments = 6
		ring.mesh = torus
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color("ffd166") if i == 0 else Color("7b2cbf")
		ring.material_override = material
		ring.position.y = 0.08 + i * 0.12
		add_child(ring)
		rings.append(ring)

func _physics_process(delta: float) -> void:
	remaining = maxf(0, remaining - delta)
	if remaining == 0 or not is_instance_valid(source):
		queue_free()
		return
	for i in rings.size():
		rings[i].rotation.y += delta * (1 if i == 0 else -1)
		rings[i].scale = Vector3.ONE * (0.97 + sin(remaining * 5) * 0.03)
	for enemy: Node3D in get_tree().get_nodes_in_group("combat_targets"):
		if enemy is CombatEnemy and enemy.state != CombatEnemy.State.DEAD and "time" not in enemy.immune_elements and (not enemy.guard_blocks_front or enemy.guard_broken) and enemy.global_position.distance_to(global_position) <= 3.0 and preload("res://systems/combat/attack_data.gd").clear_line(self, enemy):
			enemy._apply_status("slow", remaining)
