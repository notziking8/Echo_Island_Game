extends Node3D
## Composition root: Traversal's island/player + Echo + Combat, connected once.

const Echo = preload("res://systems/echo/echo_system.gd")
const Wheel = preload("res://systems/echo/echo_wheel.gd")
const Ghost = preload("res://systems/echo/echo_ghost.gd")
const IntegratedPlayer = preload("res://integration/player_adapter.gd")
const IntegratedInput = preload("res://integration/input_adapter.gd")
const IntegratedCombat = preload("res://integration/combat_bridge.gd")
const IntegratedEnemy = preload("res://integration/enemy_adapter.gd")
const IntegratedEarth = preload("res://integration/earth_adapter.gd")
const EnvironmentTarget = preload("res://systems/echo/demo/environment_target.gd")
var world: Node3D
var player: CharacterBody3D
var echo: Node
var combat: Node
var controls: Node
var wheel: Control
var ghost: Node3D
var hud: Label
var message: Label
var targets: Dictionary = {}
var enemies: Array[Node] = []
var initialized: bool = false
var _hit_cooldown: float = 0.0
var _interaction_events: int = 0


func _ready() -> void:
	# Resolve E conflict only in the integrated scene, without changing either owner's files.
	InputMap.action_erase_events("interact")
	var interact_key := InputEventKey.new()
	interact_key.physical_keycode = KEY_F
	InputMap.action_add_event("interact", interact_key)
	world = load("res://scenes/test/art_test.tscn").instantiate()
	player = world.get_node("Player")
	player.set_script(IntegratedPlayer)
	var tutorial: Node = world.get_node_or_null("TutorialTriggers/Trigger_Interact")
	if tutorial:
		tutorial.tutorial_message = "F - Interact"
	add_child(world)
	player.spring_arm.spring_length = 5.5
	player.spring_arm.rotation.x = deg_to_rad(-18)
	echo = Echo.new()
	echo.name = "EchoSystem"
	add_child(echo)
	echo.unlock_all()
	echo.summon("earth")
	controls = IntegratedInput.new()
	controls.name = "EchoInput"
	add_child(controls)
	controls.configure(echo, player.camera, player)
	ghost = Ghost.new()
	add_child(ghost)
	_build_ui()
	echo.state_changed.connect(_refresh_ghost)
	echo.hint_ready.connect(func(ancestor: String, text: String): message.text = ancestor.capitalize() + ": " + text)
	echo.ability_finished.connect(func(response: Dictionary): message.text = ("Applied: " if response["success"] else "Not applied: ") + response["resulting_status"])
	echo.TraversalAbilityEvent.connect(_receive_traversal)
	player.EchoInteractionEvent.connect(_receive_interaction)
	player.respawned.connect(func(_at: Vector3): controls.cancel(); wheel.close(false))
	world.get_node("ArtTestUI").show_tutorial_message("Arrow keys / WASD - Move   |   Hold Tab - Echo wheel", "move", 5.0)
	_refresh_ghost()
	await get_tree().physics_frame
	await get_tree().physics_frame
	player.global_position = _ground(0, 20) + Vector3.UP * 0.2
	player.spawn_position = player.global_position
	_add_earth("earth_rock", "rock", _ground(-2, 16))
	_add_earth("earth_platform", "ground", _ground(2, 16))
	_add_earth("earth_memory", "discovery", _ground(-5, 12))
	_add_environment("wind_vent", "vent", _ground(-5, 17))
	_add_environment("water_stream", "stream", _ground(5, 19))
	_add_environment("time_relic", "clockwork", _ground(0, 12))
	# Raised practice basin provides real depth without cutting Megan's authored island.
	var basin_floor := _ground(11, 17).y
	_box(Vector3(6, 0.3, 6), Vector3(11, basin_floor, 17), Color("c5a666"))
	for side in [-1, 1]:
		_box(Vector3(0.3, 2.6, 6), Vector3(11 + side * 3.15, basin_floor + 1.3, 17), Color("c6b797"))
		_box(Vector3(6, 2.6, 0.3), Vector3(11, basin_floor + 1.3, 17 + side * 3.15), Color("c6b797"))
	for i in 4:
		_box(Vector3(1, 0.65 * (i + 1), 2), Vector3(4.5 + i, basin_floor + 0.325 * (i + 1), 17), Color("c6b797"))
	_add_environment("water_basin", "pool", Vector3(11, basin_floor + 2.6, 17))
	for data: Array in [["shellguard", 2, -4, 8], ["skitter", 3, 4, 8], ["scout", 0, -4, 3], ["slinger", 1, 4, 3]]:
		spawn_enemy(data[0], data[1], _ground(data[2], data[3]) + Vector3.UP * 0.05)
	combat = IntegratedCombat.new()
	combat.name = "CombatSystem"
	combat.echo_system = echo
	combat.player = player
	combat.reach = controls.reach
	add_child(combat)
	# This is Megan's actual interaction seam, with authored Echo hint data attached.
	for node: Node in world.find_children("*", "Area3D", true, false):
		if node.get_script() == load("res://scripts/interaction/test_interactable.gd"):
			node.requires_echo = true
			node.echo_type = "earth"
			node.set_meta("echo_hint", "The stone remembers a path beneath these ruins.")
	initialized = true
	message.text = "Three systems connected. All Echo powers unlocked for integration testing."


func _ground(x: float, z: float) -> Vector3:
	var query := PhysicsRayQueryParameters3D.create(Vector3(x, 30, z), Vector3(x, -5, z), 1)
	query.exclude = [player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit["position"] if not hit.is_empty() else Vector3(x, 1, z)


func _add_earth(id: String, kind: String, at: Vector3) -> void:
	var node := IntegratedEarth.new()
	node.target_id = id
	node.kind = kind
	node.position = at
	add_child(node)
	targets[id] = node


func _add_environment(id: String, kind: String, at: Vector3) -> void:
	var node := EnvironmentTarget.new()
	node.target_id = id
	node.kind = kind
	node.position = at
	add_child(node)
	targets[id] = node


func spawn_enemy(id: String, archetype: int, at: Vector3) -> Node:
	var node := IntegratedEnemy.new()
	node.name = id
	node.target_id = id
	node.archetype = archetype
	node.position = at
	node.target = player
	node.detection_range = 6.0
	add_child(node)
	enemies.append(node)
	return node


func _physics_process(_delta: float) -> void:
	if not initialized:
		return
	var basin: Node = targets["water_basin"]
	player.water_surface = basin.global_position.y
	player.in_water = basin.contains(player.global_position) and not basin.active and player.global_position.y < player.water_surface + 0.7 and player.global_position.y > player.water_surface - 3.0
	player.external_velocity = Vector3.ZERO
	var vent: Node = targets["wind_vent"]
	if vent.active and vent.contains(player.global_position) and player.global_position.y < vent.global_position.y + 6:
		player.external_velocity.y = 8
	var stream: Node = targets["water_stream"]
	if stream.contains(player.global_position) and absf(player.global_position.y - stream.global_position.y) < 1:
		player.external_velocity.z = -3 if stream.reversed else 3


func _process(delta: float) -> void:
	if not is_instance_valid(ghost):
		return
	_hit_cooldown = maxf(0, _hit_cooldown - delta)
	ghost.global_position = player.global_position + Vector3(0.9, 0.25, 0.35)
	hud.text = "ECHO ISLAND · TEAM INTEGRATION\nArrows / WASD: move  •  Mouse: look  •  Space: jump\nHold Tab: Echo wheel  •  Q: selected power  •  E: personal power\nF: interact  •  X: dismiss  •  R: checkpoint respawn\nLeft click: close-range strike  •  Esc: free/capture mouse\n\nQ: %s    Ancestor: %s    Movement: %s\n%s" % [echo.selected_power().capitalize(), echo.active_echo.capitalize(), player.get_state_name(), controls.prompt()]


func _receive_traversal(event: Dictionary) -> void:
	var success := false
	var object: Node = targets.get(event["target_id"])
	if event["target_id"] == player.target_id:
		success = player.apply_event(event)
	elif is_instance_valid(object) and player.global_position.distance_to(object.global_position) <= controls.reach:
		if object is IntegratedEarth and event["echo_id"] == "earth" and player.global_position.distance_to(event["position"]) <= controls.reach:
			success = object.apply_earth(event["intended_effect"], event["position"])
		elif object is EnvironmentTarget:
			success = object.apply_event(event, player)
	echo.receive_traversal_response({"request_id": event["request_id"], "target_id": event["target_id"], "success": success, "resulting_status": event["intended_effect"] if success else "blocked_or_unsupported"})


func _receive_interaction(object: Object, data: Dictionary) -> void:
	_interaction_events += 1
	if not is_instance_valid(object):
		return
	var id: String = str(object.get_path()) if object is Node else str(object.get_instance_id())
	echo.receive_echo_interaction({"echo_id": str(data.get("echo_type", data.get("echo_id", ""))).to_lower(), "object_or_area_id": id,
		"hint": str(data.get("hint", object.get_meta("echo_hint", "This place holds a memory of our family.")))})


func _refresh_ghost() -> void:
	ghost.visible = not echo.active_echo.is_empty()
	if ghost.visible:
		ghost.set_element(echo.active_echo)


func _unhandled_input(event: InputEvent) -> void:
	if not initialized or wheel.is_open or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and _hit_cooldown <= 0:
		var victim: Node3D = controls.target
		if is_instance_valid(victim) and victim.has_method("take_damage") and player.global_position.distance_to(victim.global_position) <= 3:
			var applied: bool = victim.take_damage(10.0, player.global_position)
			_hit_cooldown = 0.4
			message.text = "Strike hit" if applied else "Guard blocked it: use Earth first"


func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 5
	add_child(canvas)
	var panel := PanelContainer.new()
	panel.position = Vector2(14, 14)
	panel.custom_minimum_size = Vector2(480, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.12, 0.15, 0.9)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	canvas.add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	hud = Label.new()
	hud.add_theme_font_size_override("font_size", 14)
	column.add_child(hud)
	message = Label.new()
	message.custom_minimum_size.x = 460
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.add_theme_font_size_override("font_size", 14)
	message.modulate = Color("ffd166")
	column.add_child(message)
	var crosshair := Label.new()
	crosshair.text = "+"
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(crosshair)
	wheel = Wheel.new()
	wheel.system = echo
	canvas.add_child(wheel)
	wheel.opened_changed.connect(func(open: bool): player.wheel_open = open)
	controls.wheel = wheel


func _box(size: Vector3, at: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.position = at
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	mesh.material_override = material
	body.add_child(mesh)
	add_child(body)
