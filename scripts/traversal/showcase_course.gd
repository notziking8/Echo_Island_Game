class_name ShowcaseCourse
extends Node3D

enum CourseState { READY, RUNNING, FINISHED }

@export var player_path: NodePath = NodePath("Player")
@export var ui_path: NodePath = NodePath("ShowcaseUI")
@export var start_gate_path: NodePath = NodePath("Gates/StartGate")
@export var finish_gate_path: NodePath = NodePath("Gates/FinishGate")

var course_state: CourseState = CourseState.READY
var elapsed_time: float = 0.0

@onready var player: Player = get_node_or_null(player_path) as Player
@onready var ui: ShowcaseUI = get_node_or_null(ui_path) as ShowcaseUI
@onready var start_gate: CourseGate = get_node_or_null(start_gate_path) as CourseGate
@onready var finish_gate: CourseGate = get_node_or_null(finish_gate_path) as CourseGate

func _ready() -> void:
	if start_gate:
		start_gate.player_passed.connect(_on_start_gate_passed)
	if finish_gate:
		finish_gate.player_passed.connect(_on_finish_gate_passed)
	
	if player:
		# Unlock Echo Step for this showcase run
		player.echo_step_unlocked = true
		player.respawned.connect(_on_player_respawned)

	_connect_checkpoints()
	reset_course()

func _connect_checkpoints() -> void:
	var checkpoints_node := get_node_or_null("Checkpoints")
	if not checkpoints_node:
		return
	for child in checkpoints_node.get_children():
		if child is Checkpoint:
			child.checkpoint_activated.connect(_on_checkpoint_activated)

func _process(delta: float) -> void:
	if course_state == CourseState.RUNNING:
		elapsed_time += delta
		if ui:
			ui.update_timer(elapsed_time)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_respawn"):
		if course_state == CourseState.FINISHED:
			reset_course()
			if player:
				player.current_checkpoint = null
				player.respawn()

func _on_start_gate_passed(_gate: CourseGate, _body: Node3D) -> void:
	if course_state == CourseState.READY:
		course_state = CourseState.RUNNING
		elapsed_time = 0.0
		if ui:
			ui.set_status("Section: Slide Ramp")
			ui.update_timer(0.0)

func _on_finish_gate_passed(_gate: CourseGate, _body: Node3D) -> void:
	if course_state == CourseState.RUNNING:
		course_state = CourseState.FINISHED
		if ui:
			ui.set_status("Finished!")
			ui.show_course_complete(elapsed_time)

func _on_checkpoint_activated(ckpt: Checkpoint, _activator: Node3D) -> void:
	if course_state == CourseState.READY:
		course_state = CourseState.RUNNING
	if ui:
		match ckpt.name:
			"Checkpoint1":
				ui.set_status("Section: Launch Pad")
			"Checkpoint2":
				ui.set_status("Section: Echo Step Gap")
			"Checkpoint3":
				ui.set_status("Section: Moving Platform")

func _on_player_respawned(_pos: Vector3) -> void:
	if course_state == CourseState.FINISHED:
		reset_course()

func reset_course() -> void:
	course_state = CourseState.READY
	elapsed_time = 0.0
	if ui:
		ui.update_timer(0.0)
		ui.set_status("Ready at Start")
		ui.hide_course_complete()
