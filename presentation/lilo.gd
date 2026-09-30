extends Node3D
## Articulated procedural fallback. Reads movement, never changes the controller.
const Art = preload("res://presentation/island_art.gd")
var actor: CharacterBody3D
var torso: Node3D
var arms: Array[Node3D] = []
var legs: Array[Node3D] = []
var weapon_socket: Node3D
var weapon: Node3D
var elapsed := 0.0
var swing := 0.0
var interaction := 0.0
var last_element := ""
var landing := 0.0
var was_grounded := true

func _ready() -> void:
	torso = Node3D.new()
	add_child(torso)
	Art.orb(torso, Vector3(0, 1.05, 0), Vector3(0.64, 0.65, 0.4), Art.SKY)
	for side in [-1, 1]:
		Art.orb(torso, Vector3(side * 0.22, 1.08, -0.1), Vector3(0.22, 0.55, 0.36), Color("886047"))
	Art.orb(torso, Vector3(0, 0.8, 0), Vector3(0.65, 0.12, 0.44), Color("b69962"))
	Art.orb(torso, Vector3(0, 0.8, -0.23), Vector3(0.16, 0.13, 0.05), Art.GOLD)
	Art.orb(torso, Vector3(0, 1.49, -0.025), Vector3(0.6, 0.6, 0.53), Color("efbe90"))
	Art.orb(torso, Vector3(0, 1.65, 0.035), Vector3(0.65, 0.4, 0.55), Color("684534"))
	for i in 7:
		var a := i * 1.6
		Art.orb(torso, Vector3(cos(a) * 0.24, 1.72 + sin(a) * 0.05, sin(a) * 0.17), Vector3(0.25, 0.23, 0.23), Color("79503a"))
	for side in [-1, 1]:
		Art.orb(torso, Vector3(side * 0.13, 1.5, -0.272), Vector3(0.075, 0.09, 0.03), Art.INK)
		Art.orb(torso, Vector3(side * 0.14, 1.68, -0.23), Vector3(0.23, 0.18, 0.09), Art.GOLD)
		Art.orb(torso, Vector3(side * 0.14, 1.68, -0.28), Vector3(0.16, 0.12, 0.035), Art.SKY)
		Art.orb(torso, Vector3(side * 0.31, 1.49, 0), Vector3(0.13, 0.18, 0.12), Color("efbe90"))
	Art.orb(torso, Vector3(0, 1.45, -0.3), Vector3(0.1, 0.12, 0.08), Color("efbe90"))
	Art.rod(torso, Vector3(-0.07, 1.36, -0.263), Vector3(0.07, 1.36, -0.263), 0.012, Color("986650"))
	Art.orb(torso, Vector3(0, 1.05, 0.28), Vector3(0.5, 0.58, 0.34), Color("795640"))
	Art.rod(torso, Vector3(-0.31, 1.34, 0.28), Vector3(0.31, 1.34, 0.28), 0.115, Color("a7af7a"))
	for side in [-1, 1]:
		var arm := Node3D.new()
		arm.position = Vector3(side * 0.38, 1.22, 0)
		torso.add_child(arm)
		arms.append(arm)
		Art.orb(arm, Vector3(0, -0.13, 0), Vector3(0.24, 0.36, 0.25), Art.SKY)
		Art.orb(arm, Vector3(0, -0.36, 0), Vector3(0.18, 0.3, 0.18), Color("efbe90"))
		Art.orb(arm, Vector3(0, -0.5, 0), Vector3(0.21, 0.21, 0.2), Color("efbe90"))
		var leg := Node3D.new()
		leg.position = Vector3(side * 0.17, 0.78, 0)
		add_child(leg)
		legs.append(leg)
		Art.orb(leg, Vector3(0, -0.29, 0), Vector3(0.29, 0.62, 0.31), Color("66814c"))
		Art.orb(leg, Vector3(side * 0.12, -0.18, 0), Vector3(0.1, 0.19, 0.21), Color("9caf70"))
		Art.orb(leg, Vector3(0, -0.6, -0.055), Vector3(0.3, 0.3, 0.43), Color("73503b"))
	weapon_socket = Node3D.new()
	weapon_socket.position = Vector3(0, -0.5, -0.1)
	arms[1].add_child(weapon_socket)
	set_weapon("earth")

func set_weapon(element: String) -> void:
	if element == last_element:
		return
	last_element = element
	if is_instance_valid(weapon):
		weapon.queue_free()
	weapon = Node3D.new()
	weapon_socket.add_child(weapon)
	match element:
		"earth":
			Art.orb(weapon, Vector3.ZERO, Vector3(0.34, 0.32, 0.4), Color("b4a17c"))
			for i in 3:
				Art.orb(weapon, Vector3((i - 1) * 0.1, 0.13, -0.13), Vector3(0.09, 0.23, 0.12), Art.GRASS, 0.3)
		"wind":
			var bow := Art.ring(weapon, Vector3(0, 0.15, 0), 0.42, Color("d7e7e5"))
			bow.rotation.x = PI / 2
			bow.scale.x = 0.45
			Art.rod(weapon, Vector3(0, -0.27, 0), Vector3(0, 0.57, 0), 0.01, Art.SKY)
		"water":
			Art.rod(weapon, Vector3(0, -0.45, 0), Vector3(0, 0.72, 0), 0.035, Art.SKY)
			for i in 3:
				Art.rod(weapon, Vector3(0, 0.55, 0), Vector3((i - 1) * 0.17, 0.98 - abs(i - 1) * 0.12, 0), 0.04, Color("b3eaf0"))
		"time":
			Art.rod(weapon, Vector3(0, -0.4, 0), Vector3(0, 0.85, 0), 0.04, Art.GOLD)
			Art.orb(weapon, Vector3(-0.25, 0.82, 0), Vector3(0.7, 0.13, 0.1), Color("bca2dc"))
			Art.orb(weapon, Vector3(0, 0.55, 0), Vector3(0.16, 0.26, 0.16), Art.MAGIC, 0.25)

func strike() -> void:
	swing = 0.4

func interact_pose() -> void:
	interaction = 0.65

func _process(delta: float) -> void:
	if not is_instance_valid(actor):
		return
	elapsed += delta
	swing = maxf(0, swing - delta)
	interaction = maxf(0, interaction - delta)
	var grounded := actor.is_on_floor()
	if grounded and not was_grounded:
		landing = 0.2
	was_grounded = grounded
	landing = maxf(0, landing - delta)
	var speed := Vector2(actor.velocity.x, actor.velocity.z).length()
	var cycle := sin(elapsed * 11) * minf(speed / 6, 1)
	torso.position.y = absf(cycle) * 0.045 + sin(elapsed * 2) * 0.015 - landing * 0.4
	torso.rotation.x = lerpf(torso.rotation.x, -speed * 0.016, delta * 8)
	torso.rotation.y = sin((0.4 - swing) * PI * 5) * swing * 1.8
	for i in 2:
		var sign_value := -1 if i == 0 else 1
		legs[i].rotation.x = lerpf(legs[i].rotation.x, cycle * sign_value * 0.65 if grounded else -0.35 * sign_value, delta * 12)
		arms[i].rotation.x = -cycle * sign_value * 0.65 if grounded else -0.6
	arms[1].rotation.x -= sin((0.4 - swing) / 0.4 * PI) * minf(swing * 10, 1) * 2.1
	arms[0].rotation.x -= interaction * 1.7
	_apply_combat_pose(delta)

func _apply_combat_pose(delta: float) -> void:
	# Retargetable joint poses on the existing rig; no alternate character geometry.
	var controller: Node = actor.get("combat_controller")
	if not is_instance_valid(controller):
		return
	var lean := 0.0
	if controller.phase == "dodge":
		lean = -0.7
		torso.position.y -= 0.22
		arms[0].rotation.z = -0.45
		arms[1].rotation.z = 0.45
		legs[0].rotation.x = 0.8
		legs[1].rotation.x = -0.6
	elif not controller.attack.is_empty():
		var data: Dictionary = controller.attack
		var twist: float
		if controller.phase == "startup":
			twist = lerpf(0, -0.75, smoothstep(0, data.startup, controller.elapsed))
		elif controller.phase == "active":
			twist = lerpf(-0.75, 1.0, smoothstep(data.startup, data.startup + data.active, controller.elapsed))
		else:
			twist = lerpf(1.0, 0.0, smoothstep(data.startup + data.active, preload("res://systems/combat/attack_data.gd").duration(data), controller.elapsed))
		if controller.combo_index == 1:
			twist *= -1
		torso.rotation.y = twist
		arms[1].rotation.x = -1.1 - twist * 0.6
		arms[1].rotation.z = -twist * 0.7
		arms[0].rotation.x = -0.5 + twist * 0.2
		lean = -0.15
	elif controller.phase == "hurt":
		lean = 0.3
	elif controller.phase == "dead":
		lean = 0.65
		torso.position.y -= 0.35
	else:
		arms[0].rotation.z = lerpf(arms[0].rotation.z, 0, delta * 12)
		arms[1].rotation.z = lerpf(arms[1].rotation.z, 0, delta * 12)
	torso.rotation.x = lerpf(torso.rotation.x, lean, minf(delta * 15, 1))
