extends Node3D
## Composition seam: owns scene objectives; delegates every ability to its existing owner.
signal exit_requested
const Art = preload("res://presentation/island_art.gd")
const Catalog = preload("res://campaign/catalog.gd")
const Earth = preload("res://presentation/earth.gd")
const EnvironmentTarget = preload("res://presentation/environment_target.gd")
const Enemy = preload("res://presentation/crab.gd")
const Lilo = preload("res://presentation/lilo.gd")
const Spirit = preload("res://presentation/echo_spirit.gd")
@export_range(0, 8) var stage_index := 0
var manager: Node
var echo: Node
var player: CharacterBody3D
var controls: Node
var combat: Node
var wheel: Control
var lilo: Node3D
var kip: Node3D
var ancestor: Node3D
var effects: Node3D
var enemies: Array[Node] = []
var targets: Dictionary = {}
var completed: Array[String] = []
var pending_events: Dictionary = {}
var stone: Node3D
var exit_at := Vector3(0, 0, -24)
var message := ""
var hit_cooldown := 0.0
var initialized := false
var data: Dictionary
var clouds: Array[Node3D] = []
var elapsed := 0.0
var guide: Node3D
var message_age := 0.0
var last_message := ""
var wind_crossing_armed := false

func _ready() -> void:
	data = Catalog.STAGES[stage_index]
	echo = manager.echo
	InputMap.action_erase_events("interact")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_F
	InputMap.action_add_event("interact", key)
	_build_landscape()
	player = preload("res://scenes/player/player.tscn").instantiate()
	player.set_script(preload("res://integration/player_adapter.gd"))
	player.position = Vector3(0, 0.15, 14 if stage_index == 5 else 16)
	add_child(player)
	player.spring_arm.spring_length = 6.3
	player.spring_arm.rotation.x = deg_to_rad(-22)
	player.camera.fov = 65
	for child in player.visuals.get_children():
		if child is MeshInstance3D:
			child.hide()
	lilo = Lilo.new()
	lilo.actor = player
	player.visuals.add_child(lilo)
	controls = preload("res://integration/input_adapter.gd").new()
	add_child(controls)
	controls.configure(echo, player.camera, player)
	controls.feedback.connect(func(value: String): message = value)
	var canvas := CanvasLayer.new()
	canvas.layer = 8
	add_child(canvas)
	wheel = preload("res://systems/echo/echo_wheel.gd").new()
	wheel.system = echo
	canvas.add_child(wheel)
	wheel.opened_changed.connect(func(open: bool): player.wheel_open = open)
	controls.wheel = wheel
	kip = Spirit.new()
	add_child(kip)
	ancestor = Spirit.new()
	add_child(ancestor)
	effects = preload("res://presentation/effects.gd").new()
	add_child(effects)
	echo.state_changed.connect(_refresh_echo)
	echo.hint_ready.connect(func(element: String, value: String): message = element.capitalize() + ": " + value)
	echo.TraversalAbilityEvent.connect(_receive_traversal)
	echo.ability_started.connect(_ability_started)
	echo.ability_finished.connect(_ability_finished)
	player.respawned.connect(func(_at: Vector3): controls.cancel(); wheel.close(false); message = "Returned to this scene's arrival point. Your discoveries remain.")
	player.respawned.connect(func(_at: Vector3): wind_crossing_armed = false)
	_build_encounter()
	combat = preload("res://integration/combat_bridge.gd").new()
	combat.echo_system = echo
	combat.player = player
	combat.reach = controls.reach
	add_child(combat)
	_refresh_echo()
	var composition := preload("res://presentation/camera_composition.gd").new()
	add_child(composition)
	composition.configure(self, player, player.camera)
	guide = Node3D.new()
	add_child(guide)
	Art.ring(guide, Vector3.ZERO, 0.55, Art.GOLD, 0.035)
	message = arrival_hint()
	initialized = true

func _build_landscape() -> void:
	Art.lighting(self, stage_index == 8)
	var ocean := Art.water(self, Vector3(0, -4, -4), Vector2(240, 240))
	ocean.name = "Ocean"
	var split := stage_index >= 3
	var water_ruins := stage_index == 5
	Art.land(self, Vector3(0, 0, 5 if water_ruins else (4 if split else -2)), Vector3(26, 1, 22 if water_ruins else (32 if split else 54)))
	if water_ruins:
		# Wind crossing before discovery, then a separate Water crossing afterward.
		Art.land(self, Vector3(0, 0, -10), Vector3(12, 1, 4), Art.GOLD.darkened(0.1))
	if split:
		Art.land(self, Vector3(0, 0, -23), Vector3(18, 1, 16))
	if stage_index >= 5:
		Art.land(self, Vector3(0, -2.5, -13.5), Vector3(9, 1, 8), Color("c1b794"))
		_add_environment("pool", "pool", Vector3(0, 0, -14.5 if water_ruins else -13.5))
	# Continuous warm path on each shore; gaps remain readable rather than disguised.
	for i in 22:
		var z := 17.0 - i * 1.85
		if i % 3 == 1:
			continue
		if split and z < -10.5 and z > -16:
			continue
		if water_ruins and z < -5.5:
			continue
		if water_ruins and z > 15:
			continue
		Art.stone(self, Vector3(sin(i * 0.5) * 0.7, 0.015, z), Vector3(1.9 + sin(i) * 0.2, 0.06, 1.25), Color("d9c795").darkened((i % 3) * 0.025), i)
	for i in 14:
		var side := -1 if i % 2 else 1
		var z := 15.0 - (i / 2) * 4.3
		if water_ruins:
			z = minf(z, 12.0)
		var x := side * (7.5 + sin(i) * 1.5)
		if water_ruins and z < -3:
			continue
		if stage_index == 3:
			Art.stone(self, Vector3(x, 1.8, z), Vector3(3, 4, 3), Color("dbc397"), i)
		else:
			Art.tree(self, Vector3(x, 0, z), 0.85 + (i % 3) * 0.15, i + stage_index)
		Art.stone(self, Vector3(x * 0.7, 0.3, z - 1), Vector3(1.3, 0.7, 1.1), Color("cbbd92"), i)
	if not water_ruins:
		Art.scatter(self, 82 + stage_index, 140, split)
	Art.arch(self, exit_at, 2.5)
	for i in 4:
		# Layered distant island silhouettes, not reachable gameplay geometry.
		Art.land(self, Vector3(-30 + i * 22, -1 - i, -45 - (i % 2) * 15), Vector3(18 + i * 3, 1, 18))
		Art.tree(self, Vector3(-30 + i * 22, -1 - i, -45 - (i % 2) * 15), 1.6, i)
	for i in 7:
		var cloud := Node3D.new()
		cloud.position = Vector3(-35 + i * 12, 13 + i % 3, -35 - i % 2 * 12)
		add_child(cloud)
		for j in 4:
			Art.orb(cloud, Vector3(j * 1.7, sin(j) * 0.5, 0), Vector3(4, 2.0 + sin(j) * 0.65, 2.8), Color("eff8ea"))
		clouds.append(cloud)
	if stage_index == 0:
		# Arrival's shoreline and a small rounded boat landmark.
		Art.orb(self, Vector3(-4, 0.15, 15), Vector3(2, 0.65, 3.2), Color("aa7b4f"))
		Art.rod(self, Vector3(-4, 0.5, 15), Vector3(-4, 3, 15), 0.06, Color("71583e"))
	if stage_index in [1, 5, 7, 8]:
		Art.arch(self, Vector3(0, 0, -6), 3.8)
		for side in [-1, 1]:
			Art.column(self, Vector3(side * 4, 0, -7), 3.5, side + stage_index)
	if stage_index == 8:
		for i in 4:
			Art.ring(self, Vector3(0, 0.06 + i * 0.025, -21), 3 + i * 0.35, Art.MAGIC, 0.025)
	_build_biome_details()
	preload("res://presentation/regions.gd").dress(self, stage_index)

func _build_biome_details() -> void:
	# Region-specific silhouettes sit off the collision-safe main route.
	match stage_index:
		2, 6:
			for i in 4:
				var vine_arch := Art.arch(self, Vector3(0, 0, 11 - i * 6), 4.8)
				vine_arch.rotation.y = 0.12 * sin(i)
				for j in 7:
					Art.Sculpt.vine(vine_arch, Vector3(-2.2 + j * 0.7, 1.5 + sqrt(4.8 * 4.8 - pow(-2.2 + j * 0.7, 2)), 0.55), 1.4 + sin(j) * 0.35, j)
		3:
			for i in 4:
				Art.land(self, Vector3(-16 + i * 11, -0.5 + i * 0.6, -35 - i % 2 * 7), Vector3(6, 1, 7), Art.GOLD.darkened(0.13))
		4, 5:
			for side in [-1, 1]:
				Art.water(self, Vector3(side * 12, -0.8, -9), Vector2(2.8, 21))
				var waterfall := Art.water(self, Vector3(side * 12, -2.0, 1), Vector2(2.8, 3.5))
				waterfall.rotation.x = PI * 0.5
		7:
			for i in 6:
				var a := i * TAU / 6
				Art.column(self, Vector3(cos(a) * 5, 0, -21 + sin(a) * 4), 4.5, i)
			for i in 3:
				var halo := Art.ring(self, Vector3(0, 4 + i * 0.3, -22), 2 + i * 0.4, Art.GOLD)
				halo.rotation.x = 0.2 * i

func _build_encounter() -> void:
	var enemy := Enemy.new()
	enemy.target_id = "stage_%d_guard" % stage_index
	enemy.archetype = data.enemy
	enemy.position = Vector3(0, 0.1, -20 if stage_index == 8 else 9)
	enemy.target = player
	enemy.detection_range = 6
	add_child(enemy)
	enemies.append(enemy)
	if "crack" in data.tasks:
		_add_earth("rock", "rock", Vector3(0, 0.02, 3))
	if "raise_platform" in data.tasks:
		_add_earth("platform", "ground", Vector3(3, 0.02, 0))
		Art.land(self, Vector3(3, 0.6, 2.1), Vector3(2.0, 1, 1.5), Art.GOLD)
	if "wind_current" in data.tasks:
		_add_environment("vent", "vent", Vector3(-2.5, 0.04, -3))
	if "freeze_object" in data.tasks:
		_add_environment("clockwork", "clockwork", Vector3(-3, 0.04, -18))
	if not data.stone.is_empty():
		stone = Spirit.new()
		stone.element = data.stone
		stone.position = Vector3(3, 1.2, 5)
		if stage_index == 3:
			Art.land(self, Vector3(3, 2.2, -2.5), Vector3(4, 1, 3.5), Art.GOLD)
			stone.position = Vector3(3, 3.2, -2.5)
		elif stage_index == 5:
			stone.position = Vector3(0, 1.2, -10)
		elif stage_index == 7:
			stone.position = Vector3(3, 1.2, -7)
		add_child(stone)
		Art.ring(self, stone.position - Vector3.UP * 0.8, 0.75, Art.GOLD)
	if stage_index in [0, 2, 4, 6, 8] and not manager.relic_stages.has(stage_index):
		var relic := preload("res://scripts/test/collectible_relic.gd").new()
		relic.position = Vector3(-4, 0.75, 1)
		relic.collision_mask = 1
		var shape_node := CollisionShape3D.new()
		var shape := SphereShape3D.new()
		shape.radius = 0.65
		shape_node.shape = shape
		relic.add_child(shape_node)
		var visual := Art.orb(relic, Vector3.ZERO, Vector3(0.35, 0.65, 0.35), Art.GOLD)
		visual.name = "MeshInstance3D"
		relic.relic_collected.connect(func(_relic): manager.collect_relic(stage_index))
		add_child(relic)

func _add_earth(id: String, kind: String, at: Vector3) -> void:
	var object := Earth.new()
	object.target_id = id
	object.kind = kind
	object.position = at
	add_child(object)
	targets[id] = object

func _add_environment(id: String, kind: String, at: Vector3) -> void:
	var object := EnvironmentTarget.new()
	object.target_id = id
	object.kind = kind
	object.position = at
	add_child(object)
	targets[id] = object

func _refresh_echo() -> void:
	ancestor.visible = not echo.active_echo.is_empty()
	if ancestor.visible:
		ancestor.set_element(echo.active_echo)
	if not echo.selected_power().is_empty():
		lilo.set_weapon(echo.selected_power())

func _ability_started(event: Dictionary) -> void:
	pending_events[event.request_id] = event.duplicate()
	effects.burst(player.global_position, event.echo_id, false)
	lilo.interact_pose()

func _ability_finished(response: Dictionary) -> void:
	var event: Dictionary = pending_events.get(response.request_id, {})
	pending_events.erase(response.request_id)
	if response.success and not event.is_empty():
		manager.soundscape.play(event.echo_id)
		var objective_applied: bool = event.intended_effect != "crack" or (targets.has(event.target_id) and targets[event.target_id].damage >= 2)
		if event.intended_effect in ["air_dash", "glide"] and "air_dash" in data.tasks:
			# Learning Wind means crossing the channel, not casting anywhere on land.
			objective_applied = false
			if player.position.z <= -4 and player.position.z >= -16 and absf(player.position.x) < 8:
				wind_crossing_armed = true
		if objective_applied and event.intended_effect not in completed:
			completed.append(event.intended_effect)
		effects.burst(event.position, event.echo_id)
		message = {"crack": "The stone gives way." if objective_applied else "A fracture opens. Tap again to clear the boulder.", "raise_platform": "An old path rises from the earth.", "air_dash": "Let the wind carry you across.", "wind_current": "The updraft is awake. Step into it to rise.", "freeze_water": "The water holds. Cross while the ice lasts.", "freeze_object": "The relic falls still. Time has made a path.", "stun": "The shell is open. Move in and strike."}.get(event.intended_effect, "Your Echo answers.")
	else:
		message = "No effect here. Check your power, aim, distance, and whether the destination is clear."

func _receive_traversal(event: Dictionary) -> void:
	var success := false
	var object: Node = targets.get(event.target_id)
	if event.target_id == player.target_id:
		success = player.apply_event(event)
	elif is_instance_valid(object) and player.global_position.distance_to(object.global_position) <= controls.reach:
		if object is Earth and event.echo_id == "earth" and player.global_position.distance_to(event.position) <= controls.reach:
			success = object.apply_earth(event.intended_effect, event.position)
		elif object is EnvironmentTarget:
			success = object.apply_event(event, player)
	echo.receive_traversal_response({"request_id": event.request_id, "target_id": event.target_id, "success": success, "resulting_status": event.intended_effect if success else "blocked_or_unsupported"})

func enemies_defeated() -> bool:
	for enemy in enemies:
		if enemy.health > 0:
			return false
	return true

func missing_tasks() -> Array[String]:
	var missing: Array[String] = []
	for task: String in data.tasks:
		# A player can defeat a guarded enemy from behind using the unchanged owner.
		# Never demand a status effect on an already-dead, ineligible receiver.
		if task == "stun" and enemies_defeated():
			continue
		if task not in completed:
			missing.append(task)
	return missing

func can_exit() -> bool:
	return enemies_defeated() and missing_tasks().is_empty() and (data.stone.is_empty() or data.stone in echo.collected_stones)

func arrival_hint() -> String:
	if stage_index in [2, 4, 6]:
		return "A new keeper arrives. Hold Tab to call an ancestor; use Q for their gift. E awaits your own stone."
	return ["Kip: The island remembers footsteps. Let's leave some of our own.", "Kip: Something beneath these roots remembers you.", "", "Kip: Look up. Some paths are waiting to be raised.", "", "Kip: The next memory rests beyond the water.", "", "Kip: Every gift you inherited brought you here.", "Kip: Four gifts. One island. Bring its memories home."][stage_index]

func next_objective() -> Dictionary:
	if can_exit():
		return {"title": "Follow the ancestral arch", "hint": "Approach the golden arch and press F.", "at": exit_at, "element": ""}
	if can_collect_stone():
		return {"title": "Remember " + str(data.stone).capitalize(), "hint": "Approach the stone and press F. Its gift becomes your personal power on E.", "at": stone.global_position, "element": data.stone}
	if stage_index in [0, 1] and not enemies_defeated():
		return {"title": "Clear the way", "hint": "Aim at the moss crab. Move close and left click to strike.", "at": enemies[0].global_position, "element": ""}
	var tasks := missing_tasks()
	if not tasks.is_empty():
		var task: String = tasks[0]
		var spec: Array = {"crack": ["earth", "rock", "Open the old path", "Tap to fracture the boulder twice."], "raise_platform": ["earth", "platform", "Raise a way forward", "Aim at the earth seal and tap. Climb the raised ledge."], "air_dash": ["wind", "", "Cross with the wind", "At the channel, jump and tap to dash; hold to glide."], "wind_current": ["wind", "vent", "Wake the sleeping wind", "Aim at the vent and tap. Step into the updraft."], "freeze_water": ["water", "pool", "Make a path across water", "Aim at the pool from the bank and tap to freeze it."], "freeze_object": ["time", "clockwork", "Still the restless relic", "Aim at the moving relic and tap to stop it."], "stun": ["earth", "", "Break the guardian's defense", "Aim at its shell and tap, then move close to strike."]}[task]
		var key := "E" if spec[0] == echo.personal_power() else "Q"
		var at := Vector3(0, 0, -9)
		if targets.has(spec[1]):
			at = targets[spec[1]].global_position
		elif task == "stun":
			at = enemies[0].global_position
		return {"title": spec[2], "hint": "%s / %s. %s" % [str(spec[0]).capitalize(), key, spec[3]], "at": at, "element": spec[0]}
	return {"title": "Face the island's guardian", "hint": "Aim and strike within reach. Use its Echo weakness to open a safe approach.", "at": enemies[0].global_position, "element": ""}

func can_collect_stone() -> bool:
	if not is_instance_valid(stone) or data.stone in echo.collected_stones:
		return false
	if stage_index == 1:
		return enemies_defeated()
	if stage_index == 3:
		return "raise_platform" in completed
	if stage_index == 5:
		return "crack" in completed and "air_dash" in completed
	if stage_index == 7:
		return "crack" in completed and "wind_current" in completed and "freeze_water" in completed
	return true

func proximity_prompt() -> String:
	if is_instance_valid(stone) and stone.visible and player.global_position.distance_to(stone.global_position) < 2.3:
		return "F  ·  Remember " + str(data.stone).capitalize() if can_collect_stone() else "Complete the earlier objectives to awaken this stone."
	if player.global_position.distance_to(exit_at) < 3.5:
		return "F  ·  Continue the story" if can_exit() else "The arch awaits: defeat the guard and complete this scene's objectives."
	if stage_index == 0:
		return "Left click to strike within reach." if is_instance_valid(controls.target) else "Follow the worn path. Aim with the center reticle."
	return controls.prompt()

func _unhandled_input(event: InputEvent) -> void:
	if not initialized or wheel.is_open or manager.transitioning:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode in [KEY_1, KEY_2, KEY_3, KEY_4]:
		controls.cancel()
		var element: String = echo.ELEMENTS[event.physical_keycode - KEY_1]
		if not echo.select_power(element):
			message = element.capitalize() + " has not been discovered by this keeper yet."
		get_viewport().set_input_as_handled()
	if event.is_action_pressed("interact"):
		if is_instance_valid(stone) and stone.visible and player.global_position.distance_to(stone.global_position) < 2.3 and can_collect_stone():
			if echo.collect_stone(data.stone):
				echo.select_power(data.stone)
				manager.soundscape.play(data.stone, true)
				stone.hide()
				lilo.interact_pose()
				effects.burst(stone.global_position, data.stone)
				message = str(data.stone).capitalize() + " is now your personal power. Aim and use E."
		elif player.global_position.distance_to(exit_at) < 3.5 and can_exit():
			exit_requested.emit()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and hit_cooldown <= 0:
		# Same strike contract/range/damage/cooldown as the original integration scene.
		var victim: Node3D = controls.target
		if is_instance_valid(victim) and victim.has_method("take_damage") and player.global_position.distance_to(victim.global_position) <= 3:
			var applied: bool = victim.take_damage(10.0, player.global_position)
			hit_cooldown = 0.4
			lilo.strike()
			if applied:
				manager.soundscape.play("strike")
			effects.burst(victim.global_position, "strike", false)
			message = "Strike landed." if applied else "Armored shell: stagger with Earth or approach from behind."

func _physics_process(_delta: float) -> void:
	if not initialized:
		return
	if wind_crossing_armed and player.position.z < (-8.3 if stage_index == 5 else -16.5) and player.position.y > -0.4 and absf(player.position.x) < 6:
		wind_crossing_armed = false
		if "air_dash" not in completed:
			completed.append("air_dash")
			message = "Across together. The wind remembers your passage."
	player.external_velocity = Vector3.ZERO
	player.in_water = false
	for object in targets.values():
		if object is EnvironmentTarget:
			if object.kind == "pool":
				player.water_surface = object.global_position.y
				player.in_water = object.contains(player.global_position) and not object.active and player.global_position.y < player.water_surface + 0.7 and player.global_position.y > player.water_surface - 3
			elif object.kind == "vent" and object.active and object.contains(player.global_position) and player.global_position.y < object.global_position.y + 6:
				player.external_velocity.y = 8
	if player.position.y < -7:
		player.respawn()
	for enemy in enemies:
		if enemy.position.y < -7 and enemy.health > 0:
			enemy.take_damage(enemy.max_health, Vector3.INF)

func _process(delta: float) -> void:
	if not initialized:
		return
	elapsed += delta
	if message != last_message:
		last_message = message
		message_age = 0.0
	message_age += delta
	if message_age > 8.0:
		message = ""
	var objective := next_objective()
	if message.is_empty() and not echo.active_echo.is_empty() and objective.element == echo.active_echo and player.global_position.distance_to(objective.at) < 12:
		echo.receive_echo_interaction({"echo_id": echo.active_echo, "object_or_area_id": "chapter_%d_%s" % [stage_index, objective.title], "hint": objective.hint})
	guide.global_position = objective.at + Vector3.UP * (0.12 + sin(elapsed * 2) * 0.04)
	guide.rotation.y += delta * 0.3
	hit_cooldown = maxf(0, hit_cooldown - delta)
	kip.global_position = kip.global_position.lerp(player.global_position + Vector3(0.9, 1.5, 0.4), minf(delta * 8, 1))
	ancestor.global_position = ancestor.global_position.lerp(player.global_position + Vector3(-0.9, 1.65, 0.4), minf(delta * 7, 1))
	for i in clouds.size():
		clouds[i].position.x += delta * 0.12
	# A rounded preview uses the input owner's exact position/validity/material.
	if controls.preview.visible and controls.preview.mesh is BoxMesh:
		var size: Vector3 = controls.preview.mesh.size
		var rounded := SphereMesh.new()
		rounded.radius = 0.5
		rounded.height = 1
		controls.preview.mesh = rounded
		controls.preview.scale = size
