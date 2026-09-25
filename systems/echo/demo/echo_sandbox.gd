extends Node3D
## Standalone test fixtures, not the team's traversal/combat implementation.

const EchoSystem = preload("res://systems/echo/echo_system.gd")
const EarthTarget = preload("res://systems/echo/earth_target.gd")
const EchoInput = preload("res://systems/echo/echo_input.gd")
const AbilityTarget = preload("res://systems/echo/ability_target.gd")
const EchoWheel = preload("res://systems/echo/echo_wheel.gd")
const EchoGhost = preload("res://systems/echo/echo_ghost.gd")
const DemoPlayer = preload("res://systems/echo/demo/echo_player.gd")
const EnvironmentTarget = preload("res://systems/echo/demo/environment_target.gd")
const DemoEnemy = preload("res://systems/echo/demo/echo_enemy.gd")
const COLORS := {"earth": Color("ffd166"), "wind": Color("74c7ec"), "water": Color("59bca2"), "time": Color("7b2cbf")}
@export var save_path: String = "user://echo_sandbox_v2.json"
@export var start_unlocked: bool = true
var echo: Node
var controls: Node
var player: CharacterBody3D
var camera: Camera3D
var ghost: Node3D
var stone: MeshInstance3D
var status: Label
var target_prompt: Label
var message: Label
var generation_button: Button
var wheel: Control
var enemy: CharacterBody3D
var cooldown_label: Label
var targets: Dictionary = {}
var _time: float = 0.0
var _message_time: float = 0.0


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("74c7ec"))
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("74c7ec")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("ffffff")
	environment.environment.ambient_light_energy = 0.35
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.light_color = Color("fff1d0")
	sun.light_energy = 0.75
	sun.shadow_enabled = true
	add_child(sun)
	var ground := StaticBody3D.new()
	ground.collision_layer = 2
	add_child(ground)
	# Leave a real six-by-six basin for swimming, diving and an ice path.
	_box(ground, Vector3(19, 3, 24), Vector3(-5.5, -1.5, 0), Color("7ed957"), true)
	_box(ground, Vector3(5, 3, 24), Vector3(12.5, -1.5, 0), Color("7ed957"), true)
	_box(ground, Vector3(6, 3, 6), Vector3(7, -1.5, -9), Color("7ed957"), true)
	_box(ground, Vector3(6, 3, 12), Vector3(7, -1.5, 6), Color("7ed957"), true)
	_box(ground, Vector3(6, 0.5, 6), Vector3(7, -3.25, -3), Color("c5a666"), true)
	for x in [-12.0, 12.0]:
		for z in [-8.0, 8.0]:
			_box(self, Vector3(0.9, 3.0, 0.9), Vector3(x, 1.5, z), Color("e3d1a6"))
	_make_target("rock_west", "rock", Vector3(-3, 0, 0))
	_make_target("rock_east", "rock", Vector3(3, 0, -1))
	_make_target("platform_clearing", "ground", Vector3(0, 0, -3))
	_make_target("barrier_clearing", "ground", Vector3(-3, 0, -6))
	_make_target("buried_entrance", "discovery", Vector3(-6, 0, -4))
	_make_environment("wind_vent", "vent", Vector3(-8, 0, 2))
	_make_environment("water_basin", "pool", Vector3(7, 0, -3))
	_make_environment("water_stream", "stream", Vector3(-10, 0, -4))
	_make_environment("time_relic", "clockwork", Vector3(0, 0, -8))
	_box(self, Vector3(0.9, 0.7, 0.9), Vector3(7, -2.5, -3), Color("ffd166"))
	enemy = DemoEnemy.new()
	enemy.position = Vector3(6, 0, 4)
	add_child(enemy)
	player = DemoPlayer.new()
	player.collision_layer = 1
	player.collision_mask = 3
	add_child(player)
	player.position = Vector3(0, 0.1, 4)
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.6
	var collision := CollisionShape3D.new()
	collision.shape = capsule
	collision.position.y = 0.8
	player.add_child(collision)
	_capsule(player, Color("ff7a59"), false)
	camera = Camera3D.new()
	add_child(camera)
	camera.current = true
	camera.fov = 60
	_update_camera()
	ghost = EchoGhost.new()
	add_child(ghost)
	stone = MeshInstance3D.new()
	var stone_mesh := PrismMesh.new()
	stone_mesh.size = Vector3(0.65, 1.0, 0.65)
	stone.mesh = stone_mesh
	add_child(stone)
	stone.position = Vector3(-2, 0.9, 2)
	echo = EchoSystem.new()
	echo.enforce_story_order = not start_unlocked
	add_child(echo)
	if start_unlocked:
		echo.unlock_all()
		echo.summon("earth")
	controls = EchoInput.new()
	add_child(controls)
	controls.configure(echo, camera, player)
	echo.TraversalAbilityEvent.connect(_apply_world_event)
	echo.AbilityEvent.connect(_combat_receiver)
	echo.state_changed.connect(_refresh_ui)
	echo.hint_ready.connect(func(ancestor: String, text: String): _say(ancestor.capitalize() + ": " + text))
	echo.ability_finished.connect(func(response: Dictionary):
		_say(("Applied: " if response["success"] else "Could not apply: ") + response["resulting_status"]))
	_build_ui()
	_refresh_ui()
	_say("All powers unlocked. Hold Tab to choose any Echo. E always uses your own Time power." if start_unlocked else "Walk to the golden stone to discover Earth.")


func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	var basin: Node = targets["water_basin"]
	player.in_water = basin.contains(player.position) and not basin.active and player.position.y < 0.7
	player.external_velocity = Vector3.ZERO
	var vent: Node = targets["wind_vent"]
	if vent.active and vent.contains(player.position) and player.position.y < 6:
		player.external_velocity.y = 8.0
	var stream: Node = targets["water_stream"]
	if stream.contains(player.position) and player.position.y < 0.8:
		player.external_velocity.z = -3.0 if stream.reversed else 3.0
	player.step(delta, is_instance_valid(wheel) and wheel.is_open)
	_update_camera()
	if not start_unlocked and stone.visible and player.position.distance_to(Vector3(stone.position.x, 0, stone.position.z)) < 1.4:
		var element: String = EchoSystem.ELEMENTS[echo.generation - 1]
		if echo.collect_stone(element):
			_say(element.capitalize() + " discovered. Your personal power is available.")
	if echo.active_echo == "earth" and player.position.distance_to(targets["buried_entrance"].position) < 5.0:
		echo.receive_echo_interaction({"echo_id": "earth", "object_or_area_id": "buried_entrance",
			"hint": "There is another entrance beneath that disturbed earth."})
	for hint_data: Array in [["wind", "wind_vent", "Let the wind lift you, then spread it beneath your feet to glide."], ["water", "water_basin", "We can make a path across this water, or seek what lies below."]]:
		if echo.active_echo == hint_data[0] and player.position.distance_to(targets[hint_data[1]].position) < 6:
			echo.receive_echo_interaction({"echo_id": hint_data[0], "object_or_area_id": hint_data[1], "hint": hint_data[2]})


func _process(delta: float) -> void:
	_time += delta
	_message_time = maxf(0, _message_time - delta)
	if is_instance_valid(ghost):
		ghost.position = player.position + Vector3(1.0, 0.25 + sin(_time * 2.0) * 0.12, 0.4)
		stone.rotation.y += delta
		target_prompt.text = controls.prompt()
		cooldown_label.text = "Movement: " + player.movement_state
		for element: String in echo.cooldowns:
			cooldown_label.text += "  |  %s %.1fs" % [element.capitalize(), echo.cooldowns[element]]
		if player.glide_remaining > 0:
			cooldown_label.text += "  |  Glide %.1fs" % player.glide_remaining
		if player.underwater_remaining > 0:
			cooldown_label.text += "  |  Dive %.1fs" % player.underwater_remaining
		if _message_time <= 0:
			message.text = "The island remembers. Move or lower structures to change them again."


func _update_camera() -> void:
	camera.position = player.position + Vector3(0, 10, 13)
	camera.look_at(player.position + Vector3(0, 0, -2))


func _make_target(id: String, kind: String, at: Vector3) -> void:
	var target := EarthTarget.new()
	target.target_id = id
	target.kind = kind
	target.require_ground_support = true
	target.position = at
	add_child(target)
	targets[id] = target


func _make_environment(id: String, kind: String, at: Vector3) -> void:
	var target := EnvironmentTarget.new()
	target.target_id = id
	target.kind = kind
	target.position = at
	add_child(target)
	targets[id] = target


func _apply_world_event(event: Dictionary) -> void:
	var target: Node = targets.get(event["target_id"])
	var success := false
	if event["target_id"] == "player":
		success = player.apply_event(event)
	elif is_instance_valid(target) and player.global_position.distance_to(target.global_position) <= controls.reach:
		if target is EarthTarget and event["echo_id"] == "earth" and player.global_position.distance_to(event["position"]) <= controls.reach:
			success = target.apply_earth(event["intended_effect"], event["position"])
		elif target is EnvironmentTarget:
			success = target.apply_event(event, player)
	if success:
		_pulse(event["position"], COLORS[event["echo_id"]])
	echo.receive_traversal_response({"request_id": event["request_id"], "target_id": event["target_id"],
		"success": success, "resulting_status": event["intended_effect"] if success else "blocked_or_unsupported"})


func _combat_receiver(event: Dictionary) -> void:
	var success: bool = event["target_id"] == enemy.target_id and player.global_position.distance_to(enemy.global_position) <= controls.reach
	if success:
		success = enemy.apply_event(event)
		_pulse(enemy.position, COLORS[event["echo_id"]])
	echo.receive_ability_response({"request_id": event["request_id"], "target_id": event["target_id"],
		"success": success, "resulting_status": event["intended_effect"] if success else "out_of_range_or_invalid"})


func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	wheel = EchoWheel.new()
	wheel.system = echo
	canvas.add_child(wheel)
	controls.wheel = wheel
	var panel := PanelContainer.new()
	panel.position = Vector2(18, 18)
	panel.custom_minimum_size = Vector2(350, 0)
	panel.theme = Theme.new()
	panel.theme.default_font_size = 14
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.16, 0.18, 0.94)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	panel.add_theme_stylebox_override("panel", style)
	canvas.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	var title := Label.new()
	title.text = "ECHO ISLAND / Power playground"
	title.add_theme_font_size_override("font_size", 18)
	title.modulate = Color("ffd166")
	column.add_child(title)
	status = Label.new()
	column.add_child(status)
	var keys := Label.new()
	keys.text = "Arrow keys move • Space jump / swim up\nHold Tab: Echo wheel • Mouse: aim\nQ: selected power • E: your own power\nX: dismiss ancestor • Esc: cancel"
	column.add_child(keys)
	target_prompt = Label.new()
	target_prompt.custom_minimum_size.x = 320
	target_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	target_prompt.modulate = Color("ffd166")
	column.add_child(target_prompt)
	cooldown_label = Label.new()
	cooldown_label.custom_minimum_size.x = 320
	cooldown_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(cooldown_label)
	message = Label.new()
	message.custom_minimum_size = Vector2(320, 48)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(message)
	var row := HBoxContainer.new()
	column.add_child(row)
	generation_button = _button(row, "Next generation (test)", _advance)
	generation_button.visible = not start_unlocked
	_button(row, "Save", save_demo)
	_button(row, "Load", load_demo)
	_button(column, "Unlock every power", _unlock_everything)
	var note := Label.new()
	note.text = "Earth: rocks & terrain • Wind: vent & open air\nWater: basin & stream • Time: moving relic\nEvery element also affects the training guardian."
	note.add_theme_font_size_override("font_size", 12)
	note.modulate = Color("b7d4cf")
	column.add_child(note)
	# GUI hit testing follows sibling order, independently of z_index.
	canvas.move_child(wheel, canvas.get_child_count() - 1)


func _button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _refresh_ui() -> void:
	if not is_instance_valid(status):
		return
	status.text = "Q: %s    Stones %d / 4\nPersonal: %s    Ancestor: %s" % [echo.selected_power().capitalize(),
		echo.collected_stones.size(), echo.personal_power().capitalize() if not echo.personal_power().is_empty() else "Locked",
		echo.active_echo.capitalize() if not echo.active_echo.is_empty() else "None"]
	ghost.visible = not echo.active_echo.is_empty()
	if ghost.visible:
		ghost.set_element(echo.active_echo)
	stone.visible = not start_unlocked and echo.personal_power().is_empty()
	var material := StandardMaterial3D.new()
	material.albedo_color = COLORS[EchoSystem.ELEMENTS[echo.generation - 1]]
	material.emission_enabled = true
	material.emission = material.albedo_color
	material.emission_energy_multiplier = 0.4
	stone.material_override = material
	generation_button.disabled = echo.personal_power().is_empty() or echo.generation == 4
	generation_button.visible = echo.enforce_story_order


func _advance() -> void:
	controls.cancel()
	if echo.begin_generation(echo.generation + 1):
		player.position = Vector3(0, 0.1, 4)
		player.velocity = Vector3.ZERO
		_say("Next descendant. Tab summons an ancestor. Discover the next stone.")


func _test_combat() -> void:
	var element: String = echo.selected_power()
	if element.is_empty() or echo.request_ability(element, EchoSystem.COMBAT_EFFECTS[element], enemy.target_id, enemy.position, "combat", {"origin": player.position}).is_empty():
		_say("Unlock a power and wait for its cooldown first.")


func _unlock_everything() -> void:
	controls.cancel()
	echo.unlock_all()
	echo.summon("earth")
	_say("All powers available. Hold Tab and choose in any order.")


func save_demo() -> void:
	controls.cancel()
	var world: Dictionary = {}
	for id: String in targets:
		world[id] = targets[id].snapshot()
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		_say("Save failed: " + error_string(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify({"version": 1, "echo": echo.snapshot(), "world": world}))
	var error := file.get_error()
	file.close()
	_say("Island and inheritance saved." if error == OK else "Save failed: " + error_string(error))


func load_demo() -> void:
	if not FileAccess.file_exists(save_path):
		_say("No sandbox save yet. Use Save first.")
		return
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		_say("Could not read sandbox save.")
		return
	var parser := JSON.new()
	var parse_error := parser.parse(file.get_as_text())
	file.close()
	if parse_error != OK:
		_say("Invalid save; current island kept.")
		return
	var data: Variant = parser.data
	if not data is Dictionary or data.get("version") != 1 or not data.get("echo") is Dictionary or not data.get("world") is Dictionary:
		_say("Invalid save; current island kept.")
		return
	if not echo.valid_snapshot(data["echo"]) or data["world"].size() != targets.size():
		_say("Invalid save; current island kept.")
		return
	for id: String in targets:
		if not data["world"].get(id) is Dictionary or not targets[id].valid_snapshot(data["world"][id]):
			_say("Invalid world save; current island kept.")
			return
	controls.cancel()
	wheel.close(false)
	for id: String in targets:
		targets[id].restore(data["world"][id])
	echo.restore(data["echo"])
	# Player position belongs to Traversal; this fixture restarts above the island.
	player.position = Vector3(0, 4, 4)
	player.velocity = Vector3.ZERO
	player.clear_effects()
	_say("Saved island restored, including ancestors and Earth changes.")


func _pulse(at: Vector3, color: Color) -> void:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.75
	torus.outer_radius = 0.85
	ring.mesh = torus
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(color, 0.85)
	material.emission_enabled = true
	material.emission = color
	ring.material_override = material
	add_child(ring)
	ring.position = at + Vector3.UP * 0.15
	var tween := create_tween().set_parallel(true)
	tween.tween_property(ring, "scale", Vector3.ONE * 2.5, 0.6)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.6)
	tween.chain().tween_callback(ring.queue_free)


func _say(text: String) -> void:
	message.text = text
	_message_time = 6.0


func _box(parent: Node, size: Vector3, at: Vector3, color: Color, solid: bool = false) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = at
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	mesh.material_override = material
	parent.add_child(mesh)
	if solid:
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		collision.position = at
		parent.add_child(collision)


func _capsule(parent: Node, color: Color, translucent: bool) -> void:
	var mesh := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.35
	capsule.height = 1.6
	mesh.mesh = capsule
	mesh.position.y = 0.8
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color, 0.45 if translucent else 1.0)
	if translucent:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 0.3
	mesh.material_override = material
	parent.add_child(mesh)
