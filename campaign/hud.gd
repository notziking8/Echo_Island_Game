extends Control
## Read-only HUD. Unsupported owner data is explicitly unavailable, not fabricated.
const Art = preload("res://presentation/island_art.gd")
var manager: Node
var font := ThemeDB.fallback_font
var stage: Node

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _process(_delta: float) -> void:
	stage = manager.stage
	queue_redraw()

func panel(rect: Rect2) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.98, 0.95, 0.83, 0.93)
	style.border_color = Color("c5b28a")
	style.set_border_width_all(1)
	style.set_corner_radius_all(16)
	draw_style_box(style, rect)

func text(at: Vector2, value: String, size_value: int = 17, color: Color = Art.INK) -> void:
	draw_string(font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size_value, color)

func _draw() -> void:
	if not is_instance_valid(stage) or not stage.initialized:
		return
	var w := size.x
	var h := size.y
	panel(Rect2(20, 20, 290, 102))
	text(Vector2(38, 48), "LILO  /  GENERATION %d" % manager.echo.generation, 18)
	var vitals: Node = stage.player_combat.vitals
	for i in 10:
		var filled: float = clampf((vitals.health - i * 10) / 10.0, 0, 1)
		draw_rect(Rect2(38 + i * 19, 60, 16, 10), Color("c5bba9"))
		draw_rect(Rect2(38 + i * 19, 60, 16 * filled, 10), Art.CORAL)
	if vitals.shield > 0:
		draw_rect(Rect2(38, 74, 180 * vitals.shield / vitals.max_health, 4), Art.SKY)
	text(Vector2(38, 101), "Relics  %d / 5" % manager.relic_stages.size(), 18)
	var selected: String = manager.echo.selected_power()
	text(Vector2(241, 108), "%d" % roundi(manager.echo.energy), 12)
	for i in 4:
		var angle := -PI / 2 + i * TAU / 4
		var element: String = manager.echo.ELEMENTS[i]
		var available: bool = element in manager.echo.collected_stones
		var cooldown: float = manager.echo.cooldowns.get(element, 0.0)
		draw_arc(Vector2(270, 72), 24, angle + 0.08, angle + PI / 2 - 0.08, 12, (Art.MAGIC if cooldown > 0 else Art.GRASS) if available else Color("b7b9a4"), 5, true)
	panel(Rect2(w * 0.5 - 220, 20, 440, 68))
	text(Vector2(w * 0.5 - 200, 47), "%02d  /  %s" % [stage.stage_index + 1, str(stage.data.name).to_upper()], 20)
	text(Vector2(w * 0.5 - 200, 71), "Follow the gold path to the ancestral arch", 14)
	var target: Node = stage.controls.target
	if is_instance_valid(target) and target is CombatEnemy:
		panel(Rect2(w - 310, 20, 290, 106))
		text(Vector2(w - 290, 47), "Overgrown Sentinel" if target.archetype == 4 else "Moss " + CombatEnemy.Archetype.keys()[target.archetype].capitalize(), 18)
		var ratio: float = target.health / target.max_health
		draw_rect(Rect2(w - 290, 59, 244, 8), Color("ccc5ae"))
		draw_rect(Rect2(w - 290, 59, 244 * ratio, 8), Art.CORAL)
		text(Vector2(w - 290, 89), "%d%%  ·  %s" % [roundi(ratio * 100), CombatEnemy.State.keys()[target.state].capitalize()], 14)
		text(Vector2(w - 290, 112), "Weakness: " + target.weakness().capitalize(), 14)
	panel(Rect2(20, h - 112, 320, 92))
	text(Vector2(36, h - 84), "LMB  Combo    RMB  Heavy    Shift  Dodge", 13)
	text(Vector2(36, h - 60), "Space  Jump    F  Interact    R  Respawn", 14)
	text(Vector2(36, h - 36), "Tab  Wheel    Q / E  Power    X  Dismiss", 14)
	for i in 4:
		var element: String = manager.echo.ELEMENTS[i]
		var unlocked: bool = element in manager.echo.collected_stones
		var x := w * 0.5 - 170 + i * 87
		panel(Rect2(x, h - 99, 78, 79))
		var color: Color = [Art.GRASS, Art.SKY, Color("56bec8"), Art.GOLD][i] if unlocked else Color("b7b9ad")
		draw_circle(Vector2(x + 39, h - 68), 18, color)
		if selected == element:
			draw_arc(Vector2(x + 39, h - 68), 23, 0, TAU, 40, Art.MAGIC, 2, true)
		text(Vector2(x + 31, h - 62), ["E", "W", "W", "T"][i] if unlocked else "-", 18)
		text(Vector2(x + 12, h - 32), element.capitalize(), 13)
	panel(Rect2(w - 280, h - 112, 260, 92))
	var weapon_name: String = ["Terran Gauntlets", "Tempest Bow", "Tidal Trident", "Hourglass Scythe"][stage.player_combat.weapon_index]
	text(Vector2(w - 262, h - 84), weapon_name, 18)
	text(Vector2(w - 262, h - 60), "Melee  ·  " + stage.player_combat.phase.capitalize(), 14)
	text(Vector2(w - 262, h - 36), "1–4  Cosmetic slots · Same melee stats", 12, Color("697b79"))
	for enemy in stage.enemies:
		if not is_instance_valid(enemy) or enemy.health <= 0 or enemy.global_position.distance_to(stage.player.global_position) > 12:
			continue
		var camera: Camera3D = stage.player.camera
		var at: Vector3 = enemy.global_position + Vector3.UP * (4.6 if enemy.archetype == 4 else 1.7)
		if camera.is_position_behind(at) or not preload("res://systems/combat/attack_data.gd").clear_line(stage.player, enemy):
			continue
		var screen := camera.unproject_position(at)
		screen.y = clampf(screen.y, 140, h - 240)
		var awareness_color: Color = Color.WHITE if enemy.awareness == 0 else (Art.GOLD if enemy.awareness == 1 else Art.CORAL)
		draw_circle(screen + Vector2(-48, -2), 4, awareness_color)
		draw_rect(Rect2(screen + Vector2(-40, -6), Vector2(80, 7)), Color("304746"))
		draw_rect(Rect2(screen + Vector2(-40, -6), Vector2(80 * enemy.health / enemy.max_health, 7)), Art.CORAL)
		if enemy.max_shield > 0 and enemy.shield > 0:
			draw_rect(Rect2(screen + Vector2(-40, -12), Vector2(80 * enemy.shield / enemy.max_shield, 3)), Art.GRASS)
		if enemy.archetype == 4:
			text(screen + Vector2(-48, -23), "Phase %d · %s" % [enemy.boss_phase, enemy.weakness().capitalize()], 13)
	# Compact wrapped objective block; no floating world-space debug captions.
	var lines := _wrap(stage.data.text, 57)
	var missing: Array[String] = stage.missing_tasks()
	var progress := "Ready: find the exit arch" if stage.can_exit() else "Remaining: " + (", ".join(missing).replace("_", " ") if not missing.is_empty() else "guard / stone")
	panel(Rect2(20, 140, 420, 36 + lines.size() * 21 + 17 * _wrap(progress, 57).size() + 20))
	text(Vector2(36, 165), "THE PATH AHEAD", 14)
	for i in lines.size():
		text(Vector2(36, 190 + i * 21), lines[i], 13)
	for i in _wrap(progress, 57).size():
		text(Vector2(36, 190 + lines.size() * 21 + i * 17), _wrap(progress, 57)[i], 12, Color("6b597b"))
	var notification := _wrap(stage.message, 92)
	if not notification.is_empty():
		panel(Rect2(w * 0.5 - 330, h - 219 - (notification.size() - 1) * 19, 660, 32 + (notification.size() - 1) * 19))
	for i in notification.size():
		text(Vector2(w * 0.5 - 314, h - 197 - (notification.size() - i - 1) * 19), notification[i], 14, Art.INK)
	draw_arc(size * 0.5, 4, 0, TAU, 16, Color("fff5d9"), 1.5, true)
	var prompt: String = stage.proximity_prompt()
	if not prompt.is_empty():
		panel(Rect2(w * 0.5 - 330, h - 165, 660, 42))
		text(Vector2(w * 0.5 - 314, h - 138), prompt.left(91), 14)

func _wrap(value: String, columns: int) -> Array[String]:
	var result: Array[String] = []
	var line := ""
	for word in value.split(" "):
		if line.length() + word.length() > columns:
			result.append(line)
			line = ""
		line += ("" if line.is_empty() else " ") + word
	if not line.is_empty():
		result.append(line)
	return result
