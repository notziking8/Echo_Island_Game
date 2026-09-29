extends RefCounted
## Shared, original procedural assets. No gameplay decisions live in this file.
const SKY = Color("74c7ec")
const GRASS = Color("7ed957")
const GOLD = Color("ffd166")
const CORAL = Color("ff7a59")
const MAGIC = Color("7b2cbf")
const INK = Color("283e46")

static func material(color: Color, glow: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.82
	m.metallic_specular = 0.25
	if glow > 0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = glow
	return m

static func orb(parent: Node3D, at: Vector3, size: Vector3, color: Color, glow: float = 0.0) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 20
	mesh.rings = 12
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = at
	node.scale = size
	node.material_override = material(color, glow)
	parent.add_child(node)
	return node

static func rod(parent: Node3D, from: Vector3, to: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.85
	mesh.bottom_radius = radius
	mesh.height = from.distance_to(to)
	mesh.radial_segments = 12
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = (from + to) * 0.5
	var axis := (to - from).normalized()
	node.quaternion = Quaternion(Vector3.UP, axis)
	node.material_override = material(color)
	parent.add_child(node)
	return node

static func ring(parent: Node3D, at: Vector3, radius: float, color: Color, thickness: float = 0.045) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - thickness
	mesh.outer_radius = radius + thickness
	mesh.rings = 32
	mesh.ring_segments = 8
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = at
	node.material_override = material(color, 0.15)
	parent.add_child(node)
	return node

static func land(parent: Node3D, at: Vector3, size: Vector3, color: Color = GRASS) -> StaticBody3D:
	# Sculpted ellipsoid skirts surround a flat playable top, with matching collision.
	var body := StaticBody3D.new()
	body.position = at
	parent.add_child(body)
	orb(body, Vector3(0, -1.8, 0), Vector3(size.x * 1.04, 3.2, size.z * 1.04), Color("c5a776"))
	var surface := CylinderMesh.new()
	surface.top_radius = 0.5
	surface.bottom_radius = 0.5
	surface.height = 0.3
	surface.radial_segments = 64
	var visual := MeshInstance3D.new()
	visual.mesh = surface
	visual.scale = Vector3(size.x, 1, size.z)
	visual.position.y = -0.15
	visual.material_override = material(color)
	body.add_child(visual)
	var collision := CollisionShape3D.new()
	var shape := ConvexPolygonShape3D.new()
	var points := PackedVector3Array()
	for i in 64:
		var angle := i * TAU / 64
		for y in [-0.3, 0.0]:
			points.append(Vector3(cos(angle) * size.x * 0.5, y, sin(angle) * size.z * 0.5))
	shape.points = points
	collision.shape = shape
	body.add_child(collision)
	return body

static func tree(parent: Node3D, at: Vector3, size: float, seed_value: int) -> void:
	var tree_root := Node3D.new()
	tree_root.position = at
	tree_root.scale = Vector3.ONE * size
	parent.add_child(tree_root)
	rod(tree_root, Vector3.ZERO, Vector3(0.12, 3, 0), 0.25, Color("93734c"))
	for i in 5:
		var a := i * 2.4 + seed_value
		var p := Vector3(cos(a) * 0.8, 2.7 + sin(a * 3) * 0.4, sin(a) * 0.8)
		rod(tree_root, Vector3(0, 1.5, 0), p, 0.12, Color("93734c"))
		var crown := orb(tree_root, p, Vector3(2.5, 1.9, 2.2), GRASS.darkened(0.06 + i * 0.035))
		var m := ShaderMaterial.new()
		m.shader = preload("res://presentation/foliage.gdshader")
		m.set_shader_parameter("leaf_color", GRASS.darkened(i * 0.035))
		crown.material_override = m

static func arch(parent: Node3D, at: Vector3, radius: float = 2.3) -> Node3D:
	var arch_root := Node3D.new()
	arch_root.position = at
	parent.add_child(arch_root)
	for i in 11:
		var a := i * PI / 10
		var p := Vector3(cos(a) * radius, 1.2 + sin(a) * radius, 0)
		var rock := orb(arch_root, p, Vector3(0.95, 1.05, 0.9), GOLD.darkened(0.12 + (i % 3) * 0.05))
		rock.rotation.z = a
		if i % 2 == 0:
			orb(arch_root, p + Vector3(0, 0.43, 0), Vector3(0.9, 0.24, 0.95), GRASS)
	for x in [-radius, radius]:
		orb(arch_root, Vector3(x, 0.5, 0), Vector3(1.0, 1.4, 1.0), GOLD.darkened(0.16))
	return arch_root

static func scatter(parent: Node3D, seed_value: int, density: int = 180, split: bool = false) -> void:
	# One draw call for all flower petals and one for all grass tufts.
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for flowers in [false, true]:
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_colors = true
		var sphere := SphereMesh.new()
		sphere.radius = 0.5
		sphere.height = 1
		sphere.radial_segments = 8
		sphere.rings = 4
		multi.mesh = sphere
		multi.instance_count = density
		for i in density:
			var x := rng.randf_range(3.6, 9.4) * (-1 if i % 2 else 1)
			var z := rng.randf_range(-7, 15) if split else rng.randf_range(-19, 16)
			while pow(x / 13, 2) + pow((z - (4 if split else -2)) / (16 if split else 27), 2) > 0.86:
				z = rng.randf_range(-5, 12)
				x *= 0.94
			var scale_value := Vector3(0.16, 0.45, 0.12) if not flowers else Vector3(0.23, 0.13, 0.23)
			multi.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(scale_value), Vector3(x, 0.12 if flowers else 0.19, z)))
			multi.set_instance_color(i, [CORAL, GOLD, Color("fff2d6")][i % 3] if flowers else GRASS.darkened(rng.randf_range(0.05, 0.25)))
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = multi
		var m := material(Color.WHITE)
		m.vertex_color_use_as_albedo = true
		instance.material_override = m
		instance.visibility_range_end = 50
		parent.add_child(instance)

static func lighting(parent: Node3D, core: bool = false) -> void:
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = SKY.darkened(0.12)
	sky_material.sky_horizon_color = Color("d5f0dd")
	sky_material.ground_horizon_color = Color("d5f0dd")
	sky_material.ground_bottom_color = Color("6ab6c1")
	sky.sky_material = sky_material
	settings.sky = sky
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("c4e1eb")
	settings.ambient_light_energy = 0.35
	settings.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.environment = settings
	parent.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.light_color = Color("fff0cf")
	sun.light_energy = 0.8 if not core else 0.65
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 65
	parent.add_child(sun)
