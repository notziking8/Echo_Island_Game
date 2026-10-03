extends RefCounted
## Deterministic visual meshes only: never creates physics or gameplay nodes.
static var meshes: Dictionary = {}
static var paints: Dictionary = {}

static func paint(color: Color) -> ShaderMaterial:
	if not paints.has(color):
		var result := ShaderMaterial.new()
		result.shader = preload("res://presentation/painted.gdshader")
		result.set_shader_parameter("pigment", color)
		paints[color] = result
	return paints[color]

static func instance(parent: Node3D, mesh: Mesh, at: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = at
	node.scale = size
	node.material_override = paint(color)
	node.set_meta("camera_decoration", true)
	parent.add_child(node)
	return node

static func triangle(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, tint: Color = Color.WHITE) -> void:
	tool.set_color(tint)
	tool.add_vertex(a)
	tool.add_vertex(c)
	tool.add_vertex(b)

static func finish(tool: SurfaceTool) -> ArrayMesh:
	tool.index()
	tool.generate_normals()
	return tool.commit()

static func form(seed_value: int, block: bool = true) -> ArrayMesh:
	var key := "form_%d_%s" % [posmod(seed_value, 12), block]
	if meshes.has(key):
		return meshes[key]
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var profiles := [Vector2(-0.5, 0.72), Vector2(-0.41, 0.96), Vector2(-0.18, 1.0), Vector2(0.2, 0.97), Vector2(0.42, 0.87), Vector2(0.5, 0.63)]
	if not block:
		profiles = [Vector2(-0.5, 0.12), Vector2(-0.36, 0.72), Vector2(-0.12, 1.0), Vector2(0.16, 0.94), Vector2(0.37, 0.68), Vector2(0.5, 0.12)]
	var rings: Array[PackedVector3Array] = []
	for row in profiles.size():
		var points := PackedVector3Array()
		for j in 16:
			var a := j * TAU / 16.0
			var wobble := 1.0 + 0.065 * sin(a * 3 + seed_value) + 0.04 * cos(a * 5 - row * 0.8 + seed_value)
			var exponent := 0.72 if block else 1.0
			var x := signf(cos(a)) * pow(absf(cos(a)), exponent)
			var z := signf(sin(a)) * pow(absf(sin(a)), exponent)
			points.append(Vector3(x * profiles[row].y * wobble * 0.5, profiles[row].x + 0.025 * sin(a * 3 + seed_value), z * profiles[row].y * wobble * 0.5))
		rings.append(points)
	for row in rings.size() - 1:
		for j in 16:
			var k := (j + 1) % 16
			triangle(tool, rings[row][j], rings[row + 1][j], rings[row][k])
			triangle(tool, rings[row][k], rings[row + 1][j], rings[row + 1][k])
	for j in 16:
		var k := (j + 1) % 16
		triangle(tool, Vector3(0, -0.5, 0), rings[0][j], rings[0][k])
		triangle(tool, Vector3(0, 0.5, 0), rings[-1][k], rings[-1][j])
	meshes[key] = finish(tool)
	return meshes[key]

static func stone(parent: Node3D, at: Vector3, size: Vector3, color: Color, seed_value: int = 0) -> MeshInstance3D:
	return instance(parent, form(seed_value), at, size, color)

static func leaf_mesh(flower: bool = false) -> ArrayMesh:
	var key := "flower" if flower else "fern"
	if meshes.has(key):
		return meshes[key]
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in (5 if flower else 9):
		var a := i * TAU / (5.0 if flower else 9.0)
		var forward := Vector3(cos(a), 0, sin(a))
		var side := Vector3(-sin(a), 0, cos(a))
		var base := Vector3(0, 0.24 if flower else 0, 0)
		var reach := 0.32 if flower else (0.6 + 0.14 * sin(i * 2.4))
		var middle := base + forward * reach * 0.55 + Vector3.UP * (0.07 if flower else 0.38)
		var tip := base + forward * reach + Vector3.UP * (0.02 if flower else 0.27)
		var width := 0.14 if flower else 0.13
		var left := middle - side * width
		var right := middle + side * width
		triangle(tool, base, middle, left, Color("e5f4ce"))
		triangle(tool, base, right, middle)
		triangle(tool, left, middle, tip, Color("e5f4ce"))
		triangle(tool, middle, right, tip)
	meshes[key] = finish(tool)
	return meshes[key]

static func tube(tool: SurfaceTool, points: PackedVector3Array, radii: PackedFloat32Array, seed_value: int) -> void:
	var rings: Array[PackedVector3Array] = []
	for row in points.size():
		var tangent := (points[mini(row + 1, points.size() - 1)] - points[maxi(row - 1, 0)]).normalized()
		var turn := Quaternion(Vector3.UP, tangent)
		var ring := PackedVector3Array()
		for j in 12:
			var a := j * TAU / 12.0
			var r := radii[row] * (1.0 + sin(a * 3 + seed_value + row * 0.2) * 0.1)
			ring.append(points[row] + turn * Vector3(cos(a) * r, 0, sin(a) * r))
		rings.append(ring)
	for row in rings.size() - 1:
		for j in 12:
			var k := (j + 1) % 12
			triangle(tool, rings[row][j], rings[row + 1][j], rings[row][k])
			triangle(tool, rings[row][k], rings[row + 1][j], rings[row + 1][k])
	for j in 12:
		triangle(tool, points[-1], rings[-1][(j + 1) % 12], rings[-1][j])

static func tree_mesh(seed_value: int) -> ArrayMesh:
	var key := "tree_%d" % posmod(seed_value, 8)
	if meshes.has(key):
		return meshes[key]
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var points := PackedVector3Array()
	var radii := PackedFloat32Array()
	for i in 12:
		var t := i / 11.0
		points.append(Vector3(sin(t * 2.4 + seed_value) * t * 0.42, t * 4.3, sin(t * 3.0) * t * 0.3))
		radii.append(lerpf(0.36 + 0.06 * sin(seed_value), 0.07, t) + 0.23 * pow(1.0 - t, 8))
	tube(tool, points, radii, seed_value)
	for i in 3:
		var a := i * TAU / 3 + seed_value
		var outward := Vector3(cos(a), 0, sin(a))
		tube(tool, PackedVector3Array([points[7], points[8] + outward * 0.4, points[9] + outward * 0.95, points[10] + outward * 1.4]), PackedFloat32Array([0.19, 0.16, 0.11, 0.025]), i)
		# Organic buttress roots are continuous curved tapered tubes in this mesh.
		tube(tool, PackedVector3Array([points[1], outward * 0.55 + Vector3.UP * 0.17, outward * 1.1 + Vector3.UP * 0.045]), PackedFloat32Array([0.24, 0.17, 0.025]), i)
	meshes[key] = finish(tool)
	return meshes[key]

static func canopy(seed_value: int) -> ArrayMesh:
	var key := "canopy_%d" % posmod(seed_value, 6)
	if meshes.has(key):
		return meshes[key]
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array[PackedVector3Array] = []
	for row in 13:
		var latitude := -PI * 0.5 + row * PI / 12.0
		var ring := PackedVector3Array()
		for j in 24:
			var a := j * TAU / 24.0
			var scallop := 1.0 + 0.14 * sin(a * 5 + seed_value) + 0.06 * cos(a * 7 + row * 0.4)
			ring.append(Vector3(cos(a) * cos(latitude) * scallop * 0.5, sin(latitude) * 0.5 + sin(a * 3 + seed_value) * cos(latitude) * 0.065, sin(a) * cos(latitude) * scallop * 0.5))
		rings.append(ring)
	for row in 12:
		for j in 24:
			var k := (j + 1) % 24
			triangle(tool, rings[row][j], rings[row + 1][j], rings[row][k])
			triangle(tool, rings[row][k], rings[row + 1][j], rings[row + 1][k])
	meshes[key] = finish(tool)
	return meshes[key]

static func ground(size: Vector3) -> ArrayMesh:
	# Top-only disk avoids coplanar cylinder sides against the cliff skirt.
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 64:
		var a := i * TAU / 64.0
		var b := (i + 1) * TAU / 64.0
		triangle(tool, Vector3.ZERO, Vector3(cos(b) * size.x * 0.5, 0, sin(b) * size.z * 0.5), Vector3(cos(a) * size.x * 0.5, 0, sin(a) * size.z * 0.5))
	return finish(tool)

static func cliff(size: Vector3) -> ArrayMesh:
	# The top rim matches the original 64-sided collider exactly. Irregularity
	# lives below it, so neither jump gaps nor supported walking edges move.
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array[PackedVector3Array] = []
	for row in 7:
		var points := PackedVector3Array()
		for i in 64:
			var a := i * TAU / 64.0
			var ridge := sin(a * 7 + size.x) * 0.045 + cos(a * 11 + size.z) * 0.025
			var radius: float = [1.0, 1.0, 1.01 + ridge, 0.92 + ridge, 0.96 + ridge, 0.81 + ridge, 0.63 + ridge][row]
			var y: float = [0.0, -0.3, -0.65, -1.3, -1.65, -2.65, -3.2][row]
			if row > 1:
				y += sin(a * 5 + row * 0.7) * 0.12
			points.append(Vector3(cos(a) * size.x * 0.5 * radius, y, sin(a) * size.z * 0.5 * radius))
		rings.append(points)
	for row in 6:
		var tint: Color = [Color("f0dfb5"), Color("e9c990"), Color("dcb780"), Color("caa473"), Color("dfbd86"), Color("b99872")][row]
		for i in 64:
			var j := (i + 1) % 64
			triangle(tool, rings[row][i], rings[row][j], rings[row + 1][i], tint)
			triangle(tool, rings[row][j], rings[row + 1][j], rings[row + 1][i], tint)
	return finish(tool)

static func vine(parent: Node3D, at: Vector3, length: float, seed_value: int) -> void:
	# A single inexpensive ribbon with pointed leaves, instead of stretched orbs.
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 9:
		var p := Vector3(sin(i * 0.6 + seed_value) * 0.12, -length * i / 9.0, 0)
		var q := Vector3(sin((i + 1) * 0.6 + seed_value) * 0.12, -length * (i + 1) / 9.0, 0)
		triangle(tool, p, q, p + Vector3(0.045, 0, 0))
		triangle(tool, q, q + Vector3(0.045, 0, 0), p + Vector3(0.045, 0, 0))
		var side := -1.0 if i % 2 else 1.0
		triangle(tool, p, p + Vector3(side * 0.2, -0.21, 0.08), p + Vector3(side * 0.27, -0.04, 0.02))
	var node := instance(parent, finish(tool), at, Vector3.ONE, Color("4b963e"))
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("4b963e")
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 1.0
	node.material_override = mat
