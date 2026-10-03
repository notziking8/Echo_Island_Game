extends SceneTree

var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if value:
		print("PASS: ", label)
	else:
		failures += 1
		push_error("FAIL: " + label)
		print("FAIL: ", label)

func _run() -> void:
	print("--- Running In-Campaign Traversal Integration Verification ---")
	var game: Node = preload("res://campaign/main.tscn").instantiate()
	root.add_child(game)
	for f in 5:
		await physics_frame

	game.echo.enforce_story_order = false
	game.echo.generation = 4

	# -------------------------------------------------------------
	# 1. VERIFY WIND CLIFFS (Stage index 3)
	# -------------------------------------------------------------
	print("\n>>> Testing Wind Cliffs (Stage 4) Traversal Integration...")
	await game.load_stage(3)
	var stage: Node3D = game.stage
	for f in 5:
		await physics_frame

	check(stage.initialized, "Wind Cliffs initializes successfully")
	var launch_pad: LaunchPad = stage.get_node_or_null("LaunchPad") as LaunchPad
	var mantle_cliff: StaticBody3D = stage.get_node_or_null("TraversalMantleCliff")
	if not mantle_cliff:
		mantle_cliff = stage.get_node_or_null("MantleCliff") as StaticBody3D
	check(launch_pad != null, "LaunchPad node exists in Wind Cliffs")
	check(mantle_cliff != null, "MantleCliff node exists in Wind Cliffs")

	# Test Launch Pad trajectory & Mantle
	var player = stage.player
	player.global_position = launch_pad.global_position
	launch_pad._on_body_entered(player)
	check(player.velocity.y >= 10.0, "Launch Pad imparts upward velocity (>= 10 m/s)")
	check(player.velocity.z <= -6.0, "Launch Pad imparts forward velocity (<= -6 m/s)")

	# Advance trajectory into mantle detection zone
	# Player arcs up and forward toward mantle cliff face (z = -8.0, ledge y = 4.5)
	player.global_position = Vector3(5.5, 3.4, -7.4)
	player.velocity = Vector3(0.0, -0.5, -2.0)
	player.transition_to(player.MovementState.FALLING)
	Input.action_press("move_forward")
	var mantle_triggered = player._check_ledge_grab()
	Input.action_release("move_forward")
	check(mantle_triggered, "Mantle: player detects ledge and triggers MANTLING consistently")
	check(player.current_state == player.MovementState.MANTLING, "Player enters MANTLING state")
	player._process_mantling(0.35)
	check(player.current_state == player.MovementState.GROUNDED, "Mantle completes to GROUNDED state")
	check(player.global_position.y >= 4.0, "Player successfully mantled onto top of cliff outlook")

	# Verify Wind Cliffs objectives are still 100% completable
	check(stage.targets.platform != null, "Platform target not blocked")
	check(stage.stone != null, "Wind stone not blocked")
	check(stage.exit_at != Vector3.ZERO, "Exit arch not blocked")

	# -------------------------------------------------------------
	# 2. VERIFY FORBIDDEN INTERIOR (Stage index 6)
	# -------------------------------------------------------------
	print("\n>>> Testing Forbidden Interior (Stage 7) Traversal Integration...")
	await game.load_stage(6)
	stage = game.stage
	for f in 5:
		await physics_frame

	check(stage.initialized, "Forbidden Interior initializes successfully")
	var moving_plat: MovingPlatform = stage.get_node_or_null("MovingPlatform") as MovingPlatform
	check(moving_plat != null, "MovingPlatform node exists in Forbidden Interior")
	check(moving_plat is AnimatableBody3D, "MovingPlatform is AnimatableBody3D")

	# Verify Moving Platform travel
	var start_pos: Vector3 = moving_plat.global_position
	moving_plat._physics_process(1.5)
	check(moving_plat.global_position != start_pos, "Moving Platform moves over time")
	check(moving_plat.global_position.z < start_pos.z, "Moving Platform travels toward destination island")

	# Verify objectives in Forbidden Interior are unaffected
	check(stage.targets.rock != null, "Rock target exists and is accessible")
	check(stage.targets.vent != null, "Vent target exists and is accessible")
	check(stage.targets.pool != null, "Pool target exists and is accessible")
	check(stage.enemies.size() > 0, "Enemy guard exists and is accessible")

	# Finish verification
	game.free()
	print("\n--- In-Campaign Traversal Integration Verification Complete ---")
	print("Results: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
