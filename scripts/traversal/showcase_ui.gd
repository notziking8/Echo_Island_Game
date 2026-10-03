class_name ShowcaseUI
extends CanvasLayer

signal restart_requested

@onready var timer_label: Label = $UIRoot/HUDContainer/TimerCard/TimerMargin/TimerLabel
@onready var status_label: Label = $UIRoot/HUDContainer/StatusCard/StatusMargin/StatusLabel
@onready var finish_panel: PanelContainer = $UIRoot/FinishContainer/FinishPanel
@onready var finish_title: Label = $UIRoot/FinishContainer/FinishPanel/FinishMargin/VBox/FinishTitle
@onready var finish_time_label: Label = $UIRoot/FinishContainer/FinishPanel/FinishMargin/VBox/FinishTimeLabel
@onready var finish_hint_label: Label = $UIRoot/FinishContainer/FinishPanel/FinishMargin/VBox/FinishHintLabel

var _finish_tween: Tween = null

func _ready() -> void:
	if finish_panel:
		finish_panel.visible = false
	update_timer(0.0)
	set_status("Ready at Start")

func format_time(seconds: float) -> String:
	var total_cents: int = int(seconds * 100.0)
	var mins: int = total_cents / 6000
	var secs: int = (total_cents % 6000) / 100
	var cents: int = total_cents % 100
	return "%02d:%02d.%02d" % [mins, secs, cents]

func update_timer(seconds: float) -> void:
	if timer_label:
		timer_label.text = "⏱ %s" % format_time(seconds)

func set_status(text: String) -> void:
	if status_label:
		status_label.text = text

func show_course_complete(final_time: float) -> void:
	if not finish_panel:
		return
	finish_title.text = "Course Complete!"
	finish_time_label.text = "Final Time: %s" % format_time(final_time)
	finish_hint_label.text = "[Press R to Retry]"
	finish_panel.visible = true
	finish_panel.scale = Vector2(0.85, 0.85)
	finish_panel.pivot_offset = finish_panel.size * 0.5
	if _finish_tween and _finish_tween.is_valid():
		_finish_tween.kill()
	_finish_tween = create_tween()
	_finish_tween.tween_property(finish_panel, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func hide_course_complete() -> void:
	if finish_panel:
		finish_panel.visible = false
