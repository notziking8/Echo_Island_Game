extends RefCounted
## Nine authored compositions using the team's shared palette and rounded forms.
const Art = preload("res://presentation/island_art.gd")
const NAMES = ["THE FIRST FOOTSTEPS", "ROOTS OF MEMORY", "WHAT WE INHERIT", "A BREATH OF FREEDOM", "WHERE RIVERS MEET", "THE SHAPE OF KINDNESS", "BENEATH THE CANOPY", "THE HOURS BETWEEN", "ALL THAT REMAINS"]
const TINTS = [Color("ffe8b2"), Color("efd6a5"), Color("cde6ab"), Color("e9f5ff"), Color("d3f0df"), Color("bce8ed"), Color("a4bec9"), Color("f7dbaa"), Color("c5bbdd")]

static func dress(stage: Node3D, index: int) -> void:
	for child in stage.get_children():
		if child is WorldEnvironment:
			var env: Environment = child.environment
			env.fog_light_color = TINTS[index].lerp(Art.SKY, 0.45)
			env.fog_density = 0.0025 if index >= 6 else 0.0012
			env.ambient_light_color = TINTS[index].lerp(Color.WHITE, 0.55)
			env.ambient_light_energy = 0.62 if index >= 6 else 0.78
		if child is DirectionalLight3D:
			child.light_color = TINTS[index]
			child.rotation_degrees.y = -32 + index * 9
	# Landmarks frame the route; they do not obscure the ability receivers.
	match index:
		0:
			for side in [-1, 1]:
				for i in 3:
					Art.stone(stage, Vector3(side * (8.0 + i), 0.25, 9 - i * 6), Vector3(2.8, 0.65, 2.1), Color("ecd9ad"), i)
			_banner(stage, Vector3(-3, 0, 12), Art.CORAL)
			_banner(stage, Vector3(4, 0, -18), Art.CORAL)
		1:
			for side in [-1, 1]:
				for i in 3:
					Art.column(stage, Vector3(side * 5.5, 0, 6 - i * 8), 2.5 + i, i)
			_mural(stage, Vector3(0, 0.04, -17), Art.GRASS, 0)
		2:
			for side in [-1, 1]:
				for i in 4:
					Art.tree(stage, Vector3(side * 6.5, 0, 10 - i * 7), 1.4 + i * 0.08, i + 9)
			_mural(stage, Vector3(-3, 0.05, -18), Art.GRASS, 0)
		3:
			for side in [-1, 1]:
				for i in 4:
					_banner(stage, Vector3(side * 6, 0, 12 - i * 7), Art.SKY)
			_mural(stage, Vector3(3, 2.23, -2.5), Art.SKY, 1)
		4:
			for side in [-1, 1]:
				for i in 5:
					_reeds(stage, Vector3(side * 6, 0, 10 - i * 4), i)
		5:
			for side in [-1, 1]:
				for i in 4:
					Art.column(stage, Vector3(side * 7, 0, 12 - i * 5), 1.5 + i * 0.45, i)
			_mural(stage, Vector3(0, 0.05, -10), Color("76ccd1"), 2)
		6:
			for side in [-1, 1]:
				for i in 4:
					Art.tree(stage, Vector3(side * 6.8, 0, 12 - i * 5.5), 1.6, i + 2)
					Art.orb(stage, Vector3(side * 4.5, 0.55, 10 - i * 5), Vector3(0.15, 0.3, 0.15), Art.GOLD, 0.6)
		7:
			for i in 5:
				_mural(stage, Vector3(0, 0.04, 12 - i * 5), Art.GOLD, 3)
			for side in [-1, 1]:
				_banner(stage, Vector3(side * 5, 0, -20), Art.GOLD)
		8:
			for i in 4:
				var angle := i * TAU / 4
				var at := Vector3(cos(angle) * 5, 0, -21 + sin(angle) * 4)
				Art.column(stage, at, 2.5, i)
				Art.orb(stage, at + Vector3.UP * 3.3, Vector3.ONE * 0.65, [Art.GRASS, Art.SKY, Color("76ccd1"), Art.GOLD][i], 0.4)
			_mural(stage, Vector3(0, 0.08, -21), Art.MAGIC, 3)

static func _banner(parent: Node3D, at: Vector3, color: Color) -> void:
	Art.rod(parent, at, at + Vector3.UP * 3.8, 0.06, Color("95724f"))
	Art.rod(parent, at + Vector3(0, 3.6, 0), at + Vector3(1.2, 3.6, 0), 0.04, Color("95724f"))
	var cloth := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(1.1, 1.6)
	mesh.subdivide_width = 8
	mesh.subdivide_depth = 8
	cloth.mesh = mesh
	cloth.position = at + Vector3(0.6, 2.8, 0)
	cloth.rotation.x = PI / 2
	cloth.material_override = Art.foliage_material(color, false)
	parent.add_child(cloth)

static func _mural(parent: Node3D, at: Vector3, color: Color, element: int) -> void:
	Art.ring(parent, at, 1.25, color, 0.025)
	Art.ring(parent, at + Vector3.UP * 0.01, 1.05, color, 0.018)
	for i in 4 + element:
		var a := i * TAU / (4 + element)
		Art.stone(parent, at + Vector3(cos(a) * 0.75, 0.01, sin(a) * 0.75), Vector3(0.16, 0.04, 0.32), color, i)

static func _reeds(parent: Node3D, at: Vector3, seed_value: int) -> void:
	for i in 5:
		var p := at + Vector3(sin(i * 2.4) * 0.4, 0, cos(i * 2.4) * 0.4)
		var tip := p + Vector3(0.15, 1.1 + 0.3 * sin(i + seed_value), 0.1)
		Art.rod(parent, p, tip, 0.025, Color("73874c"))
		Art.orb(parent, tip, Vector3(0.12, 0.35, 0.12), Color("bb9460"))
