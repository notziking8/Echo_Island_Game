extends RefCounted
## Shared, original procedural assets. No gameplay decisions live in this file.
const SKY = Color("74c7ec")
const GRASS = Color("7ed957")
const GOLD = Color("ffd166")
const CORAL = Color("ff7a59")
const MAGIC = Color("7b2cbf")
const INK = Color("283e46")
const Sculpt = preload("res://presentation/sculpt.gd")
static var _water_material: ShaderMaterial

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
	# Preserve the original playable top and collision; sculpt only its skirt.
	var body := StaticBody3D.new()
	body.position = at
	parent.add_child(body)
	Sculpt.instance(body, Sculpt.cliff(size), Vector3.ZERO, Vector3.ONE, Color.WHITE)
	var visual := MeshInstance3D.new()
	visual.mesh = Sculpt.ground(size)
	if color == GRASS:
		var ground_material := ShaderMaterial.new()
		ground_material.shader = preload("res://presentation/ground.gdshader")
		ground_material.set_shader_parameter("worn_route", size.z > 20)
		visual.material_override = ground_material
	else:
		visual.material_override = Sculpt.paint(color)
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
	# Moss is below the supported rim. Short fragments leave the strata readable.
	var moss_batch := MultiMesh.new()
	moss_batch.transform_format = MultiMesh.TRANSFORM_3D
	moss_batch.mesh = Sculpt.form(4, false)
	moss_batch.instance_count = 18
	for i in 18:
		var a := i * TAU / 18.0
		var moss_size := Vector3(minf(size.x, size.z) * 0.095, 0.35 + 0.22 * sin(i * 2.3), 0.65)
		moss_batch.set_instance_transform(i, Transform3D(Basis(Vector3.UP, -a + PI * 0.5).scaled(moss_size), Vector3(cos(a) * size.x * 0.493, -0.24, sin(a) * size.z * 0.493)))
	var moss := MultiMeshInstance3D.new()
	moss.multimesh = moss_batch
	moss.material_override = Sculpt.paint(color.darkened(0.12))
	body.add_child(moss)
	return body

static func tree(parent: Node3D, at: Vector3, size: float, seed_value: int) -> void:
	var tree_root := Node3D.new()
	tree_root.position = at
	tree_root.scale = Vector3.ONE * size
	parent.add_child(tree_root)
	var trunk := Sculpt.instance(tree_root, Sculpt.tree_mesh(seed_value), Vector3.ZERO, Vector3.ONE, Color("a18157"))
	var bark := Sculpt.paint(Color("a18157")).duplicate()
	bark.set_shader_parameter("wood", true)
	trunk.material_override = bark
	for i in 3:
		var a := i * 2.4 + seed_value
		var p := Vector3(cos(a) * 0.85, 3.8 + sin(a * 3) * 0.35, sin(a) * 0.85)
		var crown := Sculpt.instance(tree_root, Sculpt.canopy(seed_value + i), p, Vector3(3.4, 1.8 + 0.3 * sin(i), 3.2), GRASS)
		var m := ShaderMaterial.new()
		m.shader = preload("res://presentation/foliage.gdshader")
		m.set_shader_parameter("leaf_color", Color("86b95e").darkened(i * 0.045))
		crown.material_override = m
		crown.rotation.y = a
	# Understory frames the trunk with large leaves rather than isolated balls.
	for i in 3:
		var fern := Sculpt.instance(tree_root, Sculpt.leaf_mesh(), Vector3(cos(i * 2.3), 0.02, sin(i * 2.3)), Vector3.ONE * 1.4, GRASS)
		fern.material_override = foliage_material(GRASS.darkened(0.18), false)

static func arch(parent: Node3D, at: Vector3, radius: float = 2.3) -> Node3D:
	var arch_root := Node3D.new()
	arch_root.position = at
	parent.add_child(arch_root)
	for i in 13:
		var a := i * PI / 12
		var p := Vector3(cos(a) * radius, 1.2 + sin(a) * radius, 0)
		var rock := Sculpt.stone(arch_root, p, Vector3(radius * 0.28, 0.92, 1.15), Color("ebd4a1").darkened((i % 3) * 0.035), i)
		rock.rotation.z = a - PI * 0.5 + sin(i * 3.1) * 0.035
		if i in [2, 3, 7, 8, 9]:
			Sculpt.instance(arch_root, Sculpt.form(i, false), p + Vector3(0, 0.43, 0), Vector3(0.95, 0.21, 1.2), GRASS.darkened(0.08))
		if i in [3, 8, 10]:
			Sculpt.vine(arch_root, p + Vector3(0, 0.3, 0.62), 0.85 + i * 0.11, i)
	for x in [-radius, radius]:
		Sculpt.stone(arch_root, Vector3(x, 0.15, 0), Vector3(1.4, 0.35, 1.5), Color("cfb587"), 2)
		Sculpt.stone(arch_root, Vector3(x, 0.72, 0), Vector3(1.05, 1.0, 1.15), Color("e5cca0"), 5)
		var fragment := Sculpt.stone(arch_root, Vector3(x * 1.35, 0.28, -0.7), Vector3(1.1, 0.65, 0.8), Color("d6bd8d"), 7)
		fragment.rotation = Vector3(0.17, x * 0.4, 0.22)
	return arch_root

static func foliage_material(color: Color, use_instance_color: bool) -> ShaderMaterial:
	var result := ShaderMaterial.new()
	result.shader = preload("res://presentation/foliage.gdshader")
	result.set_shader_parameter("leaf_color", color)
	result.set_shader_parameter("instance_color", use_instance_color)
	return result

static func stone(parent: Node3D, at: Vector3, size: Vector3, color: Color, seed_value: int = 0) -> MeshInstance3D:
	var result := Sculpt.stone(parent, at, size, color, seed_value)
	result.rotation.y = sin(seed_value * 2.4) * 0.24
	return result

static func column(parent: Node3D, at: Vector3, height: float, seed_value: int = 0) -> void:
	var root := Node3D.new()
	parent.add_child(root)
	root.position = at
	root.rotation.z = sin(seed_value * 2.1) * 0.065
	stone(root, Vector3(0, 0.18, 0), Vector3(1.6, 0.36, 1.5), Color("cdb180"), seed_value)
	for i in 4:
		stone(root, Vector3(0.04 * sin(i), 0.36 + height * (i + 0.5) / 4.0, 0), Vector3(1.0 - i * 0.08, height / 4.0 - 0.035, 0.95), Color("e5cfa2"), seed_value + i)
	stone(root, Vector3(0, height + 0.4, 0), Vector3(1.4, 0.35, 1.3), Color("d6bd8d"), seed_value)
	Sculpt.instance(root, Sculpt.form(seed_value, false), Vector3(0, height + 0.59, 0), Vector3(1.4, 0.25, 1.3), GRASS)
	Sculpt.vine(root, Vector3(0.4, height + 0.6, 0.55), height * 0.65, seed_value)

static func water(parent: Node3D, at: Vector3, size: Vector2) -> MeshInstance3D:
	if _water_material == null:
		_water_material = ShaderMaterial.new()
		_water_material.shader = preload("res://presentation/water.gdshader")
	var plane := PlaneMesh.new()
	plane.size = size
	plane.subdivide_width = 40
	plane.subdivide_depth = 40
	var node := MeshInstance3D.new()
	node.mesh = plane
	node.position = at
	node.material_override = _water_material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node

static func scatter(parent: Node3D, seed_value: int, density: int = 180, split: bool = false) -> void:
	# Two batched meshes. Seeded patches leave the central route and gaps clear.
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for flowers in [false, true]:
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_colors = true
		multi.mesh = Sculpt.leaf_mesh(flowers)
		multi.instance_count = density
		for i in density:
			var patch := i % 12
			var x := (5.3 + sin(patch * 2.4) * 1.3 + rng.randf_range(-1.2, 1.2)) * (-1 if patch % 2 else 1)
			var z := (13.0 - (patch / 2) * (3.5 if split else 5.4)) + rng.randf_range(-1.6, 1.6)
			while pow(x / 13, 2) + pow((z - (4 if split else -2)) / (16 if split else 27), 2) > 0.86:
				z = rng.randf_range(-5, 12)
				x *= 0.94
			var scale_value := Vector3.ONE * rng.randf_range(0.65, 1.45) if not flowers else Vector3.ONE * rng.randf_range(0.45, 0.8)
			multi.set_instance_transform(i, Transform3D(Basis(Vector3.UP, rng.randf_range(0, TAU)).scaled(scale_value), Vector3(x, 0.02, z)))
			multi.set_instance_color(i, [CORAL, GOLD, Color("fff2d6")][i % 3] if flowers else GRASS.darkened(rng.randf_range(0.05, 0.25)))
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = multi
		instance.material_override = foliage_material(Color.WHITE, true)
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		instance.visibility_range_end = 50
		parent.add_child(instance)

static func lighting(parent: Node3D, core: bool = false) -> void:
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = SKY
	sky_material.sky_horizon_color = Color("c9eee9")
	sky_material.ground_horizon_color = Color("c9eee9")
	sky_material.ground_bottom_color = Color("6ab6c1")
	sky.sky_material = sky_material
	settings.sky = sky
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("c4e1eb")
	settings.ambient_light_energy = 0.72
	settings.fog_enabled = true
	settings.fog_light_color = Color("a9dcd9")
	settings.fog_density = 0.0007
	settings.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.environment = settings
	parent.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.light_color = Color("fff0cf")
	sun.light_energy = 0.42 if not core else 0.36
	sun.shadow_opacity = 0.65
	sun.light_angular_distance = 1.5
	sun.shadow_blur = 1.8
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 65
	parent.add_child(sun)
