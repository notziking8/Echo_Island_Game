extends Node3D
## Persistent scene-flow coordinator. Echo owns inheritance; this calls its public API.
const Art = preload("res://presentation/island_art.gd")
const Catalog = preload("res://campaign/catalog.gd")
const Checkpoint = preload("res://campaign/checkpoint.gd")
@export var persistence_enabled := true
var saved_checkpoint: Dictionary = {}
var soundscape: Node
var echo: Node
var stage: Node3D
var stage_index := -1
var relic_stages: Array[int] = []
var transitioning := false
var mode := "title"
var canvas: CanvasLayer
var title_world: Node3D
var title_camera: Camera3D
var overlay: Control
var heading: Label
var subtitle: Label
var prompt: Label
var fade: ColorRect
var hud: Control
var timer := 0.0

func _ready() -> void:
	soundscape = preload("res://presentation/soundscape.gd").new()
	add_child(soundscape)
	echo = preload("res://systems/echo/echo_system.gd").new()
	echo.enforce_story_order = true
	add_child(echo)
	canvas = CanvasLayer.new()
	canvas.layer = 12
	add_child(canvas)
	_build_title_world()
	_build_overlay()
	if persistence_enabled:
		saved_checkpoint = Checkpoint.read_checkpoint(echo)
		if not saved_checkpoint.is_empty():
			prompt.text = "CONTINUE / " + str(Catalog.STAGES[int(saved_checkpoint.stage)].name) + "\nEnter or click to resume  /  N for a new journey"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _build_title_world() -> void:
	title_world = Node3D.new()
	add_child(title_world)
	Art.lighting(title_world)
	Art.water(title_world, Vector3(0, -3, 0), Vector2(200, 200))
	for i in 5:
		var at := Vector3((i - 2) * 13, -i * 0.7, -i * 9)
		Art.land(title_world, at, Vector3(23, 1, 24))
		Art.tree(title_world, at + Vector3(-7, 0, -3), 1.4, i)
		Art.tree(title_world, at + Vector3(7, 0, 2), 1.1, i + 2)
		Art.arch(title_world, at + Vector3(0, 0, -5), 2.3)
		for j in 7:
			Art.stone(title_world, at + Vector3(sin(j) * 0.4, 0.02, 7 - j * 2), Vector3(2.8, 0.12, 1.6), Color("e9d6a6"), j)
	for i in 5:
		Art.orb(title_world, Vector3(-30 + i * 15, 12 + i % 2 * 2, -40), Vector3(12, 2, 4), Color("f5f5e9"))
	title_camera = Camera3D.new()
	title_camera.position = Vector3(19, 13, 23)
	title_world.add_child(title_camera)
	title_camera.look_at(Vector3(0, 0, -8))
	title_camera.current = true

func _build_overlay() -> void:
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(overlay)
	var shade := ColorRect.new()
	shade.color = Color(0.08, 0.18, 0.2, 0.18)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(shade)
	var rings := Control.new()
	rings.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rings.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(rings)
	rings.draw.connect(func():
		for i in 3:
			rings.draw_arc(Vector2(rings.size.x * 0.5, rings.size.y * 0.32), 102 + i * 24, -2.95, -0.2, 80, Color(1, 0.88, 0.55, 0.7 - i * 0.15), 2.0, true)
	)
	heading = _label(64, Color("fff2ce"), 0.27, 0.46)
	heading.text = "ECHO ISLAND"
	subtitle = _label(21, Color("fff5df"), 0.45, 0.64)
	subtitle.text = "A journey carried across generations"
	prompt = _label(23, Color("ffd166"), 0.75, 0.91)
	prompt.text = "PRESS START\nAny key or click"
	fade = ColorRect.new()
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.color = Color("203d43")
	fade.modulate.a = 0
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(fade)

func _label(font_size: int, color: Color, top: float, bottom: float) -> Label:
	var label := Label.new()
	label.anchor_left = 0.12
	label.anchor_right = 0.88
	label.anchor_top = top
	label.anchor_bottom = bottom
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color("25424c"))
	label.add_theme_constant_override("shadow_offset_y", 3)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(label)
	return label

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_M:
		soundscape.toggle_mute()
		if is_instance_valid(stage):
			stage.message = "Sound muted. M to listen again." if soundscape.muted else "The island's voice returns. M to mute."
		get_viewport().set_input_as_handled()
		return
	if transitioning or mode == "play":
		return
	var pressed: bool = (event is InputEventKey and event.pressed and not event.echo) or (event is InputEventMouseButton and event.pressed)
	if pressed:
		get_viewport().set_input_as_handled()
		if mode == "ending":
			get_tree().reload_current_scene()
		elif mode == "title" and not saved_checkpoint.is_empty():
			if event is InputEventKey and event.physical_keycode == KEY_N:
				saved_checkpoint.clear()
				load_stage.call_deferred(0)
			elif (event is InputEventKey and event.physical_keycode == KEY_ENTER) or event is InputEventMouseButton:
				if echo.restore(saved_checkpoint.echo):
					for index in saved_checkpoint.relics:
						relic_stages.append(int(index))
					load_stage.call_deferred(int(saved_checkpoint.stage))
		else:
			load_stage.call_deferred(stage_index + 1)

func load_stage(index: int) -> void:
	if transitioning or index < 0 or index >= Catalog.STAGES.size():
		return
	transitioning = true
	if is_instance_valid(stage):
		stage.process_mode = Node.PROCESS_MODE_DISABLED
	var tween := create_tween()
	tween.tween_property(fade, "modulate:a", 1.0, 0.35)
	await tween.finished
	var next_generation: int = Catalog.STAGES[index].generation
	if next_generation > echo.generation and not echo.begin_generation(next_generation):
		push_error("Campaign transition rejected by Echo owner")
		if is_instance_valid(stage):
			stage.process_mode = Node.PROCESS_MODE_INHERIT
		transitioning = false
		fade.modulate.a = 0
		return
	if is_instance_valid(stage):
		stage.free()
	if is_instance_valid(title_world):
		title_world.free()
	stage_index = index
	stage = load(Catalog.scene_path(index)).instantiate()
	stage.manager = self
	add_child(stage)
	stage.exit_requested.connect(_finish_stage)
	if persistence_enabled:
		var entry := {"version": 1, "stage": index, "echo": echo.snapshot(), "relics": relic_stages.duplicate()}
		if not Checkpoint.write_checkpoint(entry, echo):
			stage.message = "This chapter could not be saved. You can keep playing this session."
	overlay.hide()
	if not is_instance_valid(hud):
		hud = preload("res://campaign/journey_hud.gd").new()
		hud.manager = self
		canvas.add_child(hud)
		canvas.move_child(fade, -1)
	hud.show()
	mode = "play"
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var reveal := create_tween()
	reveal.tween_property(fade, "modulate:a", 0.0, 0.4)
	await reveal.finished
	transitioning = false

func _finish_stage() -> void:
	if transitioning or not stage.can_exit():
		return
	stage.controls.cancel()
	stage.wheel.close(false)
	stage.process_mode = Node.PROCESS_MODE_DISABLED
	hud.hide()
	overlay.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	mode = "ending" if stage_index == 8 else "memory"
	if mode == "ending" and persistence_enabled:
		DirAccess.remove_absolute(Checkpoint.PATH)
	heading.text = "THE ISLAND REMEMBERS" if mode == "ending" else str(Catalog.STAGES[stage_index].name).to_upper()
	heading.add_theme_font_size_override("font_size", 44)
	subtitle.text = Catalog.STAGES[stage_index].memory
	if stage_index in [1, 3, 5]:
		subtitle.text += "\n\nTheir gift is now inherited. Hold Tab to call them; Q carries their power into the next keeper's journey."
	prompt.text = "Relics %d / 5\nAny key to begin again" % relic_stages.size() if mode == "ending" else "CONTINUE\nAny key or click"

func collect_relic(index: int) -> void:
	if index not in relic_stages:
		relic_stages.append(index)

func _process(delta: float) -> void:
	timer += delta
	if is_instance_valid(prompt):
		prompt.modulate.a = 0.75 + sin(timer * 2) * 0.25
	if is_instance_valid(title_camera):
		title_camera.position.x = 19 + sin(timer * 0.12) * 1.2
		title_camera.look_at(Vector3(0, 0, -8))
