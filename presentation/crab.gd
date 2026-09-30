extends "res://integration/enemy_adapter.gd"
## Combat remains in the parent. This only replaces shapes and reads its state.
const Art = preload("res://presentation/island_art.gd")
var shell: Node3D
var feet: Array[Node3D] = []
var timer := 0.0
var previous_health := 0.0
var flash := 0.0
var dissolves: Array[ShaderMaterial] = []
var base_colors: Array[Color] = []

func _ready() -> void:
	super._ready()
	mesh.hide()
	label.hide()
	previous_health = health
	shell = Node3D.new()
	add_child(shell)
	if archetype == Archetype.RUIN_GUARDIAN:
		_build_guardian()
	else:
		var colors := [Color("91ab67"), Color("a0bcca"), Color("b3a47f"), Color("efaa7b")]
		Art.orb(shell, Vector3(0, 0.67, 0), Vector3(1.2, 0.83, 1.1), colors[archetype])
		Art.orb(shell, Vector3(0, 0.94, 0.08), Vector3(1.05, 0.35, 0.96), Art.GRASS.darkened(0.12))
		for side in [-1, 1]:
			Art.orb(shell, Vector3(side * 0.26, 0.6, -0.5), Vector3(0.17, 0.19, 0.14), Art.CORAL)
			Art.orb(shell, Vector3(side * 0.26, 0.63, -0.58), Vector3.ONE * 0.065, Art.INK)
			for i in 3:
				var foot := Node3D.new()
				foot.position = Vector3(side * 0.42, 0.44, (i - 1) * 0.32)
				shell.add_child(foot)
				feet.append(foot)
				Art.rod(foot, Vector3.ZERO, Vector3(side * 0.36, -0.08, 0.07), 0.11, Art.CORAL.darkened(0.15))
				Art.rod(foot, Vector3(side * 0.36, -0.08, 0.07), Vector3(side * 0.48, -0.4, 0.13), 0.09, Art.CORAL)
			Art.orb(shell, Vector3(side * 0.72, 0.48, -0.65), Vector3(0.4, 0.32, 0.46), Art.CORAL)
		for i in 3:
			Art.orb(shell, Vector3((i - 1) * 0.25, 1.12, 0.05), Vector3(0.16, 0.08, 0.16), Art.GOLD)
	for visual: Node in shell.find_children("*", "MeshInstance3D", true, false):
		var dissolve := ShaderMaterial.new()
		dissolve.shader = preload("res://systems/combat/dissolve.gdshader")
		dissolve.set_shader_parameter("base_color", visual.material_override.albedo_color)
		base_colors.append(visual.material_override.albedo_color)
		dissolve.set_shader_parameter("reveal", 0.0)
		visual.material_override = dissolve
		dissolves.append(dissolve)

func _build_guardian() -> void:
	Art.orb(shell, Vector3(0, 1.9, 0), Vector3(2.15, 2.5, 1.35), Color("85927e"))
	Art.orb(shell, Vector3(0, 3.35, -0.1), Vector3(1.65, 1.1, 1.15), Color("b6ad8a"))
	Art.orb(shell, Vector3(0, 3.3, -0.66), Vector3(0.7, 0.25, 0.16), Art.GOLD, 1)
	for side in [-1, 1]:
		Art.orb(shell, Vector3(side * 1.1, 2.45, 0), Vector3(1.1, 1.1, 1.2), Art.CORAL.darkened(0.12))
		Art.orb(shell, Vector3(side * 1.15, 1.6, 0), Vector3(0.85, 1.3, 0.85), Color("9b987e"))
		Art.orb(shell, Vector3(side * 0.6, 0.55, 0), Vector3(0.95, 1.3, 1.0), Color("8c967e"))
		Art.orb(shell, Vector3(side * 1, 2.96, 0), Vector3(1.15, 0.27, 1.18), Art.GRASS)
		Art.rod(shell, Vector3(side * 0.7, 3.6, 0), Vector3(side * 1.2, 4.5, 0.05), 0.11, Color("6c7656"))
	Art.orb(shell, Vector3(0, 1.95, -0.74), Vector3(0.55, 0.7, 0.12), Art.MAGIC, 0.5)
	# Keep target/collision aligned with the larger presentation (no AI/stat changes).
	var collision: CollisionShape3D = get_child(0)
	var shape := CapsuleShape3D.new()
	shape.radius = 0.9
	shape.height = 3.8
	collision.shape = shape
	collision.position.y = 1.9

func _process(delta: float) -> void:
	super._process(delta)
	label.hide()
	timer += delta
	if health < previous_health:
		flash = 0.18
	previous_health = health
	flash = maxf(0, flash - delta)
	var frozen := state == State.FROZEN or state == State.STUNNED
	var pace := 0.3 if _status_remaining.has("slow") else 1.0
	for i in feet.size():
		feet[i].rotation.z = 0 if frozen else sin(timer * 14 * pace + i * PI) * minf(velocity.length() * 0.06, 0.25)
	shell.position.y = 0 if frozen else sin(timer * 5 * pace) * 0.025
	shell.rotation.x = -0.25 * smoothstep(0, _startup(), attack_age) if attack_phase == "startup" else 0.0
	shell.scale = Vector3.ONE * (1.04 if flash > 0 else 1.0)
	if state == State.DEAD:
		shell.visible = defeat_age < 1.2
		shell.rotation.z = 0
	shell.rotation.y = 0
	var reveal := clampf(1.0 - defeat_age / 1.2, 0, 1) if state == State.DEAD else clampf(life_age / maxf(spawn_seconds, 0.01), 0, 1)
	for dissolve in dissolves:
		dissolve.set_shader_parameter("reveal", reveal)
	# Status shell uses the parent's truthful status tint.
	for i in dissolves.size():
		dissolves[i].set_shader_parameter("base_color", mesh.material_override.albedo_color if frozen or _status_remaining.has("slow") or flash > 0 else base_colors[i])
