extends Control
## Hold to open, hover or use arrows, release to choose. No scene-tree pause ownership.

signal opened_changed(open: bool)
const ELEMENTS := ["earth", "wind", "water", "time"]
const COLORS := [Color("ffd166"), Color("74c7ec"), Color("59bca2"), Color("ac88cb")]
const DETAILS := ["Shape • move • break", "Dash • glide • lift", "Freeze • flow • dive", "Slow • freeze • reset"]
var system: Node
var selection: int = -1
var is_open: bool = false
var _mouse_at_open := Vector2.ZERO
var _mouse_mode: int


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	z_index = 20


func open() -> void:
	if is_open:
		return
	is_open = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	selection = ELEMENTS.find(system.selected_power())
	_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_mouse_at_open = get_global_mouse_position()
	visible = true
	opened_changed.emit(true)
	queue_redraw()


func close(commit: bool = true) -> void:
	if not is_open:
		return
	if commit and selection >= 0 and available(selection):
		system.select_power(ELEMENTS[selection])
	is_open = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	Input.mouse_mode = _mouse_mode
	opened_changed.emit(false)


func available(index: int) -> bool:
	return ELEMENTS[index] in system.unlocked_echoes() or ELEMENTS[index] == system.personal_power()


func select_direction(direction: Vector2) -> void:
	if direction.length() < 0.1:
		selection = -1
	else:
		selection = posmod(int(round((direction.angle() + PI / 2.0) / (PI / 2.0))), 4)
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not is_open:
		return
	if event is InputEventMouseMotion and get_global_mouse_position().distance_to(_mouse_at_open) > 3:
		var offset := get_global_mouse_position() - size * 0.5
		select_direction(offset if offset.length() > 60 else Vector2.ZERO)
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_UP: select_direction(Vector2.UP)
			KEY_RIGHT: select_direction(Vector2.RIGHT)
			KEY_DOWN: select_direction(Vector2.DOWN)
			KEY_LEFT: select_direction(Vector2.LEFT)
			KEY_ESCAPE: close(false)
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		close(false)


func _draw() -> void:
	if not is_open:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.025, 0.065, 0.08, 0.84))
	var center := size * 0.5
	var radius := minf(220.0, size.y * 0.32)
	for i in 4:
		var angle := -PI / 2.0 + i * PI / 2.0
		var points := PackedVector2Array()
		for step in 25:
			points.append(center + Vector2.from_angle(angle - PI / 4 + 0.04 + (PI / 2 - 0.08) * step / 24.0) * radius)
		for step in range(24, -1, -1):
			points.append(center + Vector2.from_angle(angle - PI / 4 + 0.04 + (PI / 2 - 0.08) * step / 24.0) * 67.0)
		var color: Color = COLORS[i] if available(i) else Color("526166")
		draw_colored_polygon(points, Color(color, 0.65 if selection == i else 0.16))
		draw_polyline(points, Color(color, 0.95 if selection == i else 0.4), 2, true)
		var label_at := center + Vector2.from_angle(angle) * radius * 0.65
		_text(ELEMENTS[i].capitalize(), label_at, 23, color)
		_text("LOCKED" if not available(i) else ("Personal" if ELEMENTS[i] == system.personal_power() else "Ancestor"), label_at + Vector2(0, 24), 14, Color.WHITE)
	_text("ECHOES", center + Vector2(0, 5), 18, Color("ffd166"))
	_text("Hold Tab • aim or use arrows • release to select", center + Vector2(0, -radius - 35), 20, Color.WHITE)
	_text(DETAILS[selection] if selection >= 0 else "Move outward to choose", center + Vector2(0, radius + 40), 20, Color.WHITE)
	_text("Time stays yours. Your ancestor can remain beside you.  •  Esc cancels", center + Vector2(0, radius + 70), 14, Color("b7d4cf"))


func _text(text: String, at: Vector2, font_size: int, color: Color) -> void:
	var font := ThemeDB.fallback_font
	draw_string(font, at - Vector2(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
