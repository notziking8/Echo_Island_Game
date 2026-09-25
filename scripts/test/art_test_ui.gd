class_name ArtTestUI
extends CanvasLayer

@export var total_relics: int = 5
var collected_relics: int = 0

var current_action_filter: String = ""
var dismiss_timer: float = 0.0
var banner_dismiss_timer: float = 0.0
var banner_shown_time: float = 0.0
var banner_tween: Tween = null
var popup_tween: Tween = null

@onready var popup_panel: PanelContainer = $UIRoot/PopupContainer/TutorialPanel
@onready var tutorial_label: Label = $UIRoot/PopupContainer/TutorialPanel/TutorialMargin/TutorialLabel
@onready var relic_counter_label: Label = $UIRoot/HUDContainer/RelicBadge/RelicMargin/RelicLabel
@onready var banner_panel: PanelContainer = $UIRoot/BannerContainer/BannerPanel
@onready var banner_title: Label = $UIRoot/BannerContainer/BannerPanel/BannerMargin/VBox/BannerTitle
@onready var banner_subtitle: Label = $UIRoot/BannerContainer/BannerPanel/BannerMargin/VBox/BannerSubtitle

func _ready() -> void:
	add_to_group("art_test_ui")
	banner_panel.visible = false
	popup_panel.visible = false
	_audit_relic_count()
	_update_relic_display()
	
	# Spawn sequence:
	# 1. At spawn: WASD — Move
	show_tutorial_message("WASD — Move", "move", 4.0)

func _audit_relic_count() -> void:
	var container = get_parent().get_node_or_null("CollectibleRelics")
	if not container:
		container = get_tree().root.find_child("CollectibleRelics", true, false)
	if container:
		total_relics = container.get_child_count()
	else:
		var relic_nodes = get_tree().get_nodes_in_group("collectible_relics")
		if relic_nodes.size() > 0:
			total_relics = relic_nodes.size()

func _process(delta: float) -> void:
	if dismiss_timer > 0.0:
		dismiss_timer -= delta
		if dismiss_timer <= 0.0:
			_dismiss_popup()
	
	if banner_dismiss_timer > 0.0:
		banner_dismiss_timer -= delta
		banner_shown_time += delta
		if banner_dismiss_timer <= 0.0:
			_dismiss_banner()

func _unhandled_input(event: InputEvent) -> void:
	# Dismiss celebration banner if user presses any key or mouse button after brief display
	if banner_panel.visible and banner_shown_time > 0.3:
		if (event is InputEventKey and event.pressed) or (event is InputEventMouseButton and event.pressed):
			_dismiss_banner()
			return

	# Dismiss current message if associated action is performed
	if popup_panel.visible and current_action_filter != "":
		var should_dismiss = false
		match current_action_filter:
			"move":
				if event.is_action_pressed("move_forward") or event.is_action_pressed("move_backward") or event.is_action_pressed("move_left") or event.is_action_pressed("move_right"):
					should_dismiss = true
					# Transition to Mouse Look message shortly after
					call_deferred("_trigger_look_tutorial")
			"look":
				if event is InputEventMouseMotion and event.relative.length_squared() > 10.0:
					should_dismiss = true
			"jump":
				if event.is_action_pressed("jump"):
					should_dismiss = true
			"interact":
				if event.is_action_pressed("interact"):
					should_dismiss = true
			"respawn":
				if event.is_action_pressed("debug_respawn"):
					should_dismiss = true
		
		if should_dismiss:
			_dismiss_popup()

func _trigger_look_tutorial() -> void:
	# Show "Mouse — Look Around" shortly after movement
	await get_tree().create_timer(0.8, true, true).timeout
	if is_inside_tree():
		show_tutorial_message("Mouse — Look Around", "look", 3.5)

func show_tutorial_message(message: String, action_filter: String = "", duration: float = 4.5) -> void:
	tutorial_label.text = message
	current_action_filter = action_filter
	dismiss_timer = duration
	popup_panel.visible = true
	
	# Gentle scale pop animation
	popup_panel.scale = Vector2(0.85, 0.85)
	popup_panel.pivot_offset = popup_panel.size * 0.5
	if popup_tween and popup_tween.is_valid():
		popup_tween.kill()
	popup_tween = create_tween()
	if popup_tween:
		popup_tween.tween_property(popup_panel, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _dismiss_popup() -> void:
	if not popup_panel.visible:
		return
	dismiss_timer = 0.0
	current_action_filter = ""
	if popup_tween and popup_tween.is_valid():
		popup_tween.kill()
	popup_tween = create_tween()
	if popup_tween:
		popup_tween.tween_property(popup_panel, "scale", Vector2(0.85, 0.85), 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		popup_tween.tween_callback(func(): popup_panel.visible = false)
	else:
		popup_panel.visible = false

func on_relic_collected(_relic: Node) -> void:
	collected_relics += 1
	_update_relic_display()
	
	# Pulse relic badge
	var badge = $UIRoot/HUDContainer/RelicBadge
	badge.pivot_offset = badge.size * 0.5
	var tween = create_tween()
	if tween:
		tween.tween_property(badge, "scale", Vector2(1.2, 1.2), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(badge, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_CUBIC)

func _update_relic_display() -> void:
	relic_counter_label.text = "✦ Relics: %d / %d" % [collected_relics, total_relics]

func on_destination_reached(_dest: Node) -> void:
	# Show celebration banner
	banner_title.text = "★ Island Relic Claimed! ★"
	banner_subtitle.text = "Exploration Complete! Found %d / %d Relics.\n[Press any key to dismiss]" % [collected_relics, total_relics]
	banner_panel.visible = true
	banner_panel.modulate.a = 1.0
	banner_panel.scale = Vector2(0.8, 0.8)
	banner_panel.pivot_offset = banner_panel.size * 0.5
	banner_dismiss_timer = 5.0
	banner_shown_time = 0.0
	if banner_tween and banner_tween.is_valid():
		banner_tween.kill()
	banner_tween = create_tween()
	if banner_tween:
		banner_tween.tween_property(banner_panel, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _dismiss_banner() -> void:
	if not banner_panel.visible:
		return
	banner_dismiss_timer = 0.0
	if banner_tween and banner_tween.is_valid():
		banner_tween.kill()
	banner_tween = create_tween()
	if banner_tween:
		banner_tween.tween_property(banner_panel, "scale", Vector2(0.8, 0.8), 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		banner_tween.parallel().tween_property(banner_panel, "modulate:a", 0.0, 0.18)
		banner_tween.tween_callback(func():
			banner_panel.visible = false
			banner_panel.modulate.a = 1.0
		)
	else:
		banner_panel.visible = false
