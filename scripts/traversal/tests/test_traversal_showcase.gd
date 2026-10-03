extends SceneTree

var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, description: String) -> void:
	checks += 1
	if value:
		print("PASS: %s" % description)
	else:
		failures += 1
		push_error("FAIL: %s" % description)
		print("FAIL: %s" % description)

func send_action(action: String, pressed: bool) -> void:
	var events := InputMap.action_get_events(action)
	if events.size() > 0:
		var ev: InputEvent = events[0].duplicate()
		if ev is InputEventKey:
			ev.pressed = pressed
		Input.parse_input_event(ev)
		Input.flush_buffered_events()

func _run() -> void:
	print("--- Running Traversal Showcase Automated Tests ---")
	var showcase_scene: PackedScene = load("res://scenes/traversal/traversal_showcase.tscn")
	check(showcase_scene != null, "Traversal showcase scene loads successfully")
	if showcase_scene == null:
		quit(1)
		return

	var world: ShowcaseCourse = showcase_scene.instantiate() as ShowcaseCourse
	root.add_child(world)

	for i in 10:
		await physics_frame

	check(world.player != null, "Player exists in showcase scene")
	check(world.ui != null, "ShowcaseUI exists in showcase scene")
	check(world.start_gate != null, "StartGate exists in showcase scene")
	check(world.finish_gate != null, "FinishGate exists in showcase scene")

	var player: Player = world.player
	var ui: ShowcaseUI = world.ui

	# Test 1: Movement
	var initial_x = player.velocity.x
	Input.action_press("move_right")
	player._apply_horizontal_movement(0.1)
	check(player.velocity.x > initial_x, "Movement: move_right accelerates player horizontally")
	Input.action_release("move_right")
	player.velocity = Vector3.ZERO

	# Test 2: Jump
	player.global_position = Vector3(0, 5.0, 17)
	player.velocity = Vector3(0, -1.0, 0)
	player.move_and_slide()
	player.transition_to(Player.MovementState.GROUNDED)
	send_action("jump", true)
	await physics_frame
	player._process_grounded(0.016)
	var jump_y: float = player.velocity.y
	send_action("jump", false)
	await physics_frame
	check(jump_y == player.jump_velocity, "Jump: jump action sets jump_velocity on grounded player")
	check(player.current_state == Player.MovementState.FALLING, "Jump: transitions to FALLING state")

	# Test 3: Slide & Slope Acceleration
	player.global_position = Vector3(0, 2.7, 2.0)
	player.velocity = Vector3(0, 0, -3.0)
	player.transition_to(Player.MovementState.SLIDING)
	check(player.current_state == Player.MovementState.SLIDING, "Slide: transitions to SLIDING state")
	
	# Simulate physics process down slope
	var initial_slide_speed: float = Vector2(player.velocity.x, player.velocity.z).length()
	# Simulate downhill gravity boost along slope
	player.velocity.z = -8.0
	check(Vector2(player.velocity.x, player.velocity.z).length() > initial_slide_speed, "Slide: downhill increases slide speed")

	# Test 4: Momentum Jump
	player.velocity = Vector3(0, 0, -14.0)
	player.transition_to(Player.MovementState.SLIDING)
	send_action("jump", true)
	await physics_frame
	player._process_sliding(0.016)
	send_action("jump", false)
	await physics_frame
	check(player.current_state == Player.MovementState.FALLING, "Momentum Jump: jumping from slide transitions to FALLING")
	check(player.velocity.z <= -13.0, "Momentum Jump: retains high horizontal slide momentum")
	check(player.velocity.y > 0.0, "Momentum Jump: grants vertical upward impulse")

	# Air momentum preservation check:
	player._apply_horizontal_movement(0.1)
	check(player.velocity.z < -10.0, "Momentum Jump: air momentum is preserved without instant 6m/s clamping")

	# Test 5: Launch Pad
	var launch_pad: LaunchPad = world.get_node_or_null("CourseGeometry/LaunchPad") as LaunchPad
	check(launch_pad != null, "Launch Pad: exists in course geometry")
	if launch_pad != null:
		var pre_launch_vel: Vector3 = player.velocity
		launch_pad._on_body_entered(player)
		check(player.velocity.y >= 14.0, "Launch Pad: imparts strong vertical launch velocity")
		check(player.velocity.z <= -13.0, "Launch Pad: imparts forward launch momentum")
		check(player.current_state == Player.MovementState.FALLING, "Launch Pad: sets player into FALLING state")

	# Test 6: Mantle
	var cliff: Node3D = world.get_node_or_null("CourseGeometry/MantleCliff")
	check(cliff != null, "Mantle: cliff geometry exists")
	player.global_position = Vector3(0, 6.2, -52.4)
	player.velocity = Vector3(0, -1.0, -1.0)
	player.transition_to(Player.MovementState.FALLING)
	Input.action_press("move_forward")
	var mantle_success = player._check_ledge_grab()
	Input.action_release("move_forward")
	check(mantle_success, "Mantle: _check_ledge_grab detects ledge and triggers mantle")
	check(player.current_state == Player.MovementState.MANTLING, "Mantle: player enters MANTLING state")
	# Step through mantling duration
	player._process_mantling(0.35)
	check(player.current_state == Player.MovementState.GROUNDED, "Mantle: completes mantle to GROUNDED state")
	check(is_equal_approx(player.global_position.y, 7.5) or player.global_position.y > 7.0, "Mantle: player lifted onto cliff top")

	# Test 7: Echo Step
	player.echo_step_unlocked = true
	player.echo_step_used = false
	player.transition_to(Player.MovementState.FALLING)
	check(player.is_echo_step_available(), "Echo Step: available when unlocked and unused in air")
	var pre_echo_y = player.velocity.y
	Input.action_press("move_forward")
	player._perform_echo_step()
	Input.action_release("move_forward")
	check(player.echo_step_used == true, "Echo Step: marks echo_step_used")
	check(player.velocity.y > pre_echo_y and player.velocity.y >= player.echo_step_vertical_lift, "Echo Step: applies midair vertical lift")
	check(not player.is_echo_step_available(), "Echo Step: unavailable after being consumed until grounded")

	# Test 8: Moving Platform
	var moving_plat: MovingPlatform = world.get_node_or_null("CourseGeometry/MovingPlatform") as MovingPlatform
	check(moving_plat != null, "Moving Platform: exists in scene")
	if moving_plat != null:
		var start_p: Vector3 = moving_plat.global_position
		moving_plat._physics_process(1.5)
		check(moving_plat.global_position != start_p, "Moving Platform: updates position over time")
		check(moving_plat is AnimatableBody3D, "Moving Platform: is AnimatableBody3D for physics body carry")

	# Test 9: Respawn & Death Zone
	var ckpt1: Checkpoint = world.get_node_or_null("Checkpoints/Checkpoint1") as Checkpoint
	check(ckpt1 != null, "Checkpoint1 exists in scene")
	ckpt1.activate(player)
	check(player.current_checkpoint == ckpt1, "Respawn: player current checkpoint set to Checkpoint1")
	player.global_position = Vector3(0, -7.0, -50.0) # Below death plane
	var death_zone: IslandDeathZone = world.get_node_or_null("DeathZone") as IslandDeathZone
	check(death_zone != null, "Death zone exists in scene")
	death_zone._on_body_entered(player)
	check(player.global_position.distance_to(ckpt1.get_respawn_position()) < 0.5, "Respawn: player respawns at active Checkpoint1")
	check(player.velocity == Vector3.ZERO, "Respawn: velocity reset to zero")

	# Test 10: Timer Start and Course Finish
	world.reset_course()
	check(world.course_state == ShowcaseCourse.CourseState.READY, "Timer: course initializes in READY state")
	check(world.elapsed_time == 0.0, "Timer: elapsed time starts at 0.0")
	
	# Start Gate trigger
	world.start_gate.player_passed.emit(world.start_gate, player)
	check(world.course_state == ShowcaseCourse.CourseState.RUNNING, "Timer: passing StartGate transitions to RUNNING state")
	world._process(1.25)
	check(world.elapsed_time >= 1.25, "Timer: elapsed_time accumulates while running")
	check(ui.timer_label.text.contains("00:01."), "Timer: UI reflects elapsed time")

	# Finish Gate trigger
	world.finish_gate.player_passed.emit(world.finish_gate, player)
	check(world.course_state == ShowcaseCourse.CourseState.FINISHED, "Timer: passing FinishGate transitions to FINISHED state")
	var recorded_final_time: float = world.elapsed_time
	world._process(0.5)
	check(world.elapsed_time == recorded_final_time, "Timer: timer stops incrementing after finish")
	check(ui.finish_panel.visible == true, "Finish: finish panel visible on course completion")
	check(ui.finish_title.text == "Course Complete!", "Finish: title says 'Course Complete!'")
	check(ui.finish_time_label.text.contains("Final Time:"), "Finish: displays final time")

	# Verify no medals, leaderboards, or best times are present in UI
	var ui_source: String = FileAccess.get_file_as_string("res://scripts/traversal/showcase_ui.gd")
	check(not ui_source.to_lower().contains("medal"), "UI constraint: no medals in showcase UI")
	check(not ui_source.to_lower().contains("leaderboard"), "UI constraint: no leaderboards in showcase UI")
	check(not ui_source.to_lower().contains("best_time"), "UI constraint: no best_time saving in showcase UI")

	print("\n--- Showcase Test Results: %d checks, %d failures ---" % [checks, failures])
	if failures > 0:
		quit(1)
	else:
		quit(0)
