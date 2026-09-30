extends Node3D
## Cosmetic ribbon + authored-animation interface. Never determines hit timing.
@export var animation_player_path: NodePath
var controller: Node
var visual_root: Node3D
var animator: AnimationPlayer
var ribbon: MeshInstance3D
var ribbon_mesh := ImmediateMesh.new()

func _ready() -> void:
	if not animation_player_path.is_empty():
		animator = get_node_or_null(animation_player_path)
	if not animator and is_instance_valid(visual_root):
		animator = visual_root.find_child("AnimationPlayer", true, false)
	ribbon = MeshInstance3D.new()
	ribbon.mesh = ribbon_mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(1, 0.85, 0.4, 0.7)
	material.emission_enabled = true
	material.emission = Color("ffd166")
	ribbon.material_override = material
	add_child(ribbon)
	controller.attack_started.connect(func(attack): _play(attack.name, preload("res://systems/combat/attack_data.gd").duration(attack)))
	controller.dodge_started.connect(func(): _play("dodge", 0.42))
	controller.phase_changed.connect(func(phase):
		if phase in ["hurt", "dead"]:
			_play(phase, 0.2 if phase == "hurt" else 1.2)
		elif phase == "idle" and is_instance_valid(animator):
			animator.stop()
	)

func _play(clip: String, duration: float) -> void:
	if is_instance_valid(animator) and animator.has_animation(clip):
		var speed := animator.get_animation(clip).length / maxf(duration, 0.01)
		animator.play(clip, 0.08, speed)

func _process(_delta: float) -> void:
	ribbon_mesh.clear_surfaces()
	if controller.phase != "active" or controller.attack.is_empty():
		return
	var attack: Dictionary = controller.attack
	var t: float = clampf((controller.elapsed - attack.startup) / attack.active, 0, 1)
	var angle: float = atan2(-controller.direction.x, -controller.direction.z)
	ribbon_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 12:
		var a: float = angle + deg_to_rad(attack.arc) * (lerpf(maxf(0, t - 0.35), t, i / 12.0) - 0.5)
		var b: float = angle + deg_to_rad(attack.arc) * (lerpf(maxf(0, t - 0.35), t, (i + 1) / 12.0) - 0.5)
		var p := Vector3(-sin(a), 0, -cos(a))
		var q := Vector3(-sin(b), 0, -cos(b))
		for vertex: Vector3 in [p * 1.25, p * float(attack.reach), q * float(attack.reach), p * 1.25, q * float(attack.reach), q * 1.25]:
			ribbon_mesh.surface_add_vertex(vertex + Vector3.UP)
	ribbon_mesh.surface_end()
