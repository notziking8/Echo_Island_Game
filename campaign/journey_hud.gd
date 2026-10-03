extends Control
## Quiet exploration HUD: the next action, inherited gifts, and a nine-stop journey.
const Art = preload("res://presentation/island_art.gd")
const Regions = preload("res://presentation/regions.gd")
const COLORS = [Color("9acb7b"), Color("8acfe8"), Color("7bd2c9"), Color("ffd166")]
const PAPER = Color("fff1d2")
var manager: Node
var font := ThemeDB.fallback_font

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _process(_delta: float) -> void:
	queue_redraw()

func panel(rect: Rect2) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.12, 0.135, 0.87)
	style.border_color = Color(0.86, 0.79, 0.59, 0.28)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	draw_style_box(style, rect)

func text(at: Vector2, value: String, point_size: int = 16, color: Color = PAPER) -> void:
	draw_string(font, at + Vector2(0, 1), value, HORIZONTAL_ALIGNMENT_LEFT, -1, point_size, Color(0.03, 0.06, 0.07, 0.8))
	draw_string(font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, point_size, color)

func wrapped(at: Vector2, value: String, width: float, point_size: int = 15, color: Color = PAPER) -> int:
	var lines := 0
	var line := ""
	for word in value.split(" "):
		var candidate := word if line.is_empty() else line + " " + word
		if font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, point_size).x > width and not line.is_empty():
			text(at + Vector2(0, lines * 21), line, point_size, color)
			lines += 1
			line = word
		else:
			line = candidate
	if not line.is_empty():
		text(at + Vector2(0, lines * 21), line, point_size, color)
		lines += 1
	return lines

func glyph(at: Vector2, index: int, color: Color) -> void:
	match index:
		0:
			draw_polyline(PackedVector2Array([at + Vector2(-10, 6), at + Vector2(0, -10), at + Vector2(10, 6), at + Vector2(-10, 6)]), color, 2, true)
			draw_line(at + Vector2(-5, 0), at + Vector2(5, 0), color, 2, true)
		1:
			for i in 3:
				draw_arc(at + Vector2(-3 + i * 3, -7 + i * 7), 6, -0.3, PI, 14, color, 2, true)
		2:
			draw_polyline(PackedVector2Array([at + Vector2(0, -12), at + Vector2(-8, 1), at + Vector2(-6, 8), at + Vector2(0, 11), at + Vector2(6, 8), at + Vector2(8, 1), at + Vector2(0, -12)]), color, 2, true)
		3:
			draw_arc(at, 10, 0, TAU, 32, color, 2, true)
			draw_line(at, at + Vector2(0, -7), color, 2, true)
			draw_line(at, at + Vector2(5, 3), color, 2, true)

func _draw() -> void:
	var stage: Node = manager.stage
	if not is_instance_valid(stage) or not stage.initialized or stage.wheel.is_open:
		return
	# Work in a fixed design canvas; Godot stretches it with the viewport.
	var w := size.x
	var h := size.y
	text(Vector2(30, 38), "E C H O   I S L A N D", 15, Art.GOLD)
	text(Vector2(30, 71), str(stage.data.name), 27)
	text(Vector2(31, 94), Regions.NAMES[stage.stage_index], 11, Color("d2ddc5"))
	for i in 9:
		var at := Vector2(35 + i * 21, 116)
		if i < 8:
			draw_line(at, at + Vector2(21, 0), Color(1, 0.9, 0.65, 0.25), 1, true)
		draw_circle(at, 4 if i == stage.stage_index else 2.5, Art.GOLD if i <= stage.stage_index else Color("75908c"))
	var objective: Dictionary = stage.next_objective()
	panel(Rect2(24, 142, 318, 133))
	text(Vector2(40, 166), "THE NEXT FOOTSTEP", 11, Art.GOLD)
	text(Vector2(40, 192), objective.title, 18)
	wrapped(Vector2(40, 215), objective.hint, 278, 14)
	text(Vector2(w - 242, 37), "KEEPER %d   /   RELICS %d OF 5" % [manager.echo.generation, manager.relic_stages.size()], 12)
	var target: Node = stage.controls.target
	if is_instance_valid(target) and target is CombatEnemy and target.health > 0:
		panel(Rect2(w - 270, 54, 246, 81))
		text(Vector2(w - 254, 79), "The Sentinel" if target.archetype == 4 else "Moss " + CombatEnemy.Archetype.keys()[target.archetype].capitalize(), 17)
		draw_rect(Rect2(w - 254, 92, 212, 4), Color("536c68"))
		draw_rect(Rect2(w - 254, 92, 212 * clampf(target.health / target.max_health, 0, 1), 4), Art.CORAL)
		text(Vector2(w - 254, 119), "Echo weakness: " + target.weakness().capitalize(), 12)
	var selected: String = manager.echo.selected_power()
	for i in 4:
		var element: String = manager.echo.ELEMENTS[i]
		var unlocked: bool = element in manager.echo.collected_stones
		var x := w * 0.5 - 174 + i * 90
		panel(Rect2(x, h - 95, 78, 71))
		var color: Color = COLORS[i] if unlocked else Color("6d8480")
		glyph(Vector2(x + 39, h - 68), i, color)
		if selected == element:
			draw_arc(Vector2(x + 39, h - 68), 20, 0, TAU, 40, color, 1.5, true)
		var cooldown: float = manager.echo.cooldowns.get(element, 0.0)
		if cooldown > 0:
			draw_arc(Vector2(x + 39, h - 68), 23, -PI / 2, -PI / 2 + TAU * clampf(cooldown / maxf(manager.echo.cooldown_seconds, 0.01), 0, 1), 40, PAPER, 2, true)
		text(Vector2(x + 13, h - 34), element.capitalize(), 13, color)
		text(Vector2(x + 6, h - 78), str(i + 1), 10, color)
	var personal: String = manager.echo.personal_power()
	text(Vector2(30, h - 60), "Q  " + (selected.capitalize() if not selected.is_empty() else "Call an ancestor with Tab"), 15)
	text(Vector2(30, h - 35), "E  " + (personal.capitalize() + " / personal gift" if not personal.is_empty() else "Your stone awaits"), 13, Color("c4d6c8"))
	text(Vector2(w - 264, h - 60), "WASD  Move   Space  Jump   R  Return", 12)
	text(Vector2(w - 264, h - 83), "M  Sound   Esc  Cursor   X  Dismiss", 11, Color("c4d6c8"))
	text(Vector2(w - 264, h - 35), "Tab / 1-4  Echoes   F  Interact   LMB  Strike", 11)
	var prompt: String = stage.proximity_prompt()
	if not prompt.is_empty():
		panel(Rect2(w * 0.5 - 290, h - 158, 580, 49))
		wrapped(Vector2(w * 0.5 - 274, h - 137), prompt, 548, 13)
	if not stage.message.is_empty():
		panel(Rect2(w * 0.5 - 290, h - 229, 580, 61))
		wrapped(Vector2(w * 0.5 - 274, h - 205), stage.message, 548, 14)
	draw_arc(size * 0.5, 3, 0, TAU, 16, PAPER, 1.3, true)
