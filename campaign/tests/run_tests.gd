extends SceneTree
const Catalog = preload("res://campaign/catalog.gd")
var failures := 0
var checks := 0

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: " + label)
	else:
		print("PASS: ", label)

func run() -> void:
	var game := preload("res://campaign/main.tscn").instantiate()
	root.add_child(game)
	check(game.mode == "title", "starts at title")
	check(game.echo.collected_stones.is_empty(), "no powers unlocked at start")
	for i in 9:
		await game.load_stage(i)
		var stage: Node = game.stage
		await physics_frame
		await physics_frame
		check(stage.initialized, "scene %d initializes" % (i + 1))
		check(stage.echo.generation == Catalog.STAGES[i].generation, "correct generation %d" % (i + 1))
		check(not stage.can_exit(), "scene %d cannot skip objectives" % (i + 1))
		check(stage.player.get_script() == preload("res://integration/player_adapter.gd"), "uses original player adapter")
		# Freeze AI during contract checks, not the player or receivers.
		for enemy in stage.enemies:
			enemy.set_physics_process(false)
		var guard: Node = stage.enemies[0]
		var health_before_basic: float = guard.health
		var ordinary_hit: bool = guard.take_damage(10.0, stage.player.global_position)
		if guard.guard_blocks_front and not guard.guard_broken:
			check(not ordinary_hit and is_equal_approx(guard.health, health_before_basic), "armored guard requires its Echo power before ordinary hits can finish it")
		else:
			check(ordinary_hit and guard.health < health_before_basic, "ordinary attacks still damage unarmored enemies")
		if stage.targets.has("rock"):
			var wall_size: Vector3 = stage.targets["rock"].get("blocking_size")
			check(wall_size.x >= 36.0 and wall_size.y >= 6.0, "Earth wall spans the route and cannot be jumped over")
			check(_wall_blocks_route(stage, 3.0), "Earth wall physically blocks the route")
		if stage.targets.has("platform") and i in [3, 8]:
			check(stage.targets["platform"].global_position.y < 0.0 and stage.targets["platform"].get("raised_size").z >= 7.0, "Earth platform sits in a deep, non-jumpable gap")
			check(not _ground_below(stage, 0.0, -8.5), "the gap has no ordinary ground before Earth raises the platform")
		if i in [3, 4, 5]:
			var dash_gap_z := -31.5 if i == 3 else -8.5
			check(not _ground_below(stage, 0.0, dash_gap_z), "Wind route has no walkable or jumpable floor")
		if stage.targets.has("pool") and i >= 5:
			var pool_size: Vector3 = stage.targets["pool"].get("custom_size")
			check(pool_size.z >= 9.0 and stage.targets["pool"].collision_layer == 4, "unfrozen Water crossing is a real gap")
			check(not _ground_below(stage, 0.0, stage.targets["pool"].global_position.z), "unfrozen water has no walkable collision")
		if stage.targets.has("vent"):
			check(stage.targets["vent"].global_position.y < 0.1 and stage.targets.has("pool"), "Wind updraft is required to reach the raised route")
		if stage.targets.has("clockwork"):
			check(stage.targets["clockwork"].collision_layer == 1, "Time gate physically blocks the exit before freeze")
		# Discover early stones through the same F interaction as the player.
		if i == 1:
			check(not stage.can_collect_stone(), "Earth stone guarded")
			for enemy in stage.enemies:
				enemy.take_damage(enemy.health, Vector3.INF)
			_interact_stone(stage)
		for task: String in Catalog.STAGES[i].tasks:
			var element: String = {"crack": "earth", "raise_platform": "earth", "stun": "earth", "air_dash": "wind", "wind_current": "wind", "freeze_water": "water", "freeze_object": "time"}[task]
			if element == Catalog.STAGES[i].stone and element not in game.echo.collected_stones:
				_interact_stone(stage)
			game.echo.select_power(element)
			game.echo.cooldowns.clear()
			var target: Node3D
			var channel := "traversal"
			match task:
				"crack": target = stage.targets.rock
				"raise_platform": target = stage.targets.platform
				"air_dash": target = stage.player
				"wind_current": target = stage.targets.vent
				"freeze_water": target = stage.targets.pool
				"freeze_object": target = stage.targets.clockwork
				"stun":
					target = stage.enemies[0]
					channel = "combat"
			if target != stage.player:
				stage.player.global_position = target.global_position + Vector3(0, 0.1, 5 if task == "freeze_water" else 4)
			await physics_frame
			var id: String = game.echo.request_ability(element, task, target.target_id, target.global_position, channel, {"origin": stage.player.global_position, "direction": Vector3.FORWARD})
			check(not id.is_empty(), "request accepted: %d %s" % [i + 1, task])
			if task == "crack":
				check(task not in stage.completed, "one crack does not count as clearing rock")
				game.echo.cooldowns.clear()
				game.echo.request_ability(element, task, target.target_id, target.global_position, channel, {"origin": stage.player.global_position})
			check(task in stage.completed, "receiver acknowledged: %d %s" % [i + 1, task])
			match task:
				"crack": check(target.damage == 2 and target.collision_layer == 0, "Earth removes the route-blocking wall")
				"raise_platform": check(target.form == "platform" and target.collision_layer == 1, "Earth raises a solid bridge across the gap")
				"air_dash": check(stage.player.dash_remaining >= 0.5 and stage.player.dash_speed >= 22.0, "Wind dash has enough force and duration for the gap")
				"wind_current":
					stage.player.global_position = target.global_position
					stage._physics_process(0.016)
					stage.player._apply_horizontal_movement(0.016)
					check(target.active and stage.player.velocity.y >= 8.0, "Wind opens and powers the updraft route")
				"freeze_water": check(target.active and target.collision_layer == 1, "Water makes the crossing physically solid")
				"freeze_object": check(target.active and target.collision_layer == 0 and not target.mesh.visible, "Time opens the blocking gate")
		if not str(Catalog.STAGES[i].stone).is_empty() and Catalog.STAGES[i].stone not in game.echo.collected_stones:
			_interact_stone(stage)
		for enemy in stage.enemies:
			enemy.take_damage(enemy.health, Vector3.INF)
		if "stun" in stage.completed:
			stage.completed.erase("stun")
			check("stun" in stage.missing_tasks(), "stun remains required until the Echo power is used")
			stage.completed.append("stun")
		check(stage.can_exit(), "scene %d exits after actual receiver success" % (i + 1))
		check(stage.effects.rings.size() == 12, "VFX pool bounded")
		game.echo.cooldowns.clear()
	check(game.echo.collected_stones.size() == 4, "all four stones collected in order")
	check(game.echo.unlocked_echoes() == ["earth", "wind", "water"], "three ancestral Echoes")
	check(game.echo.personal_power() == "time", "Time remains generation-four personal power")
	game.collect_relic(0)
	game.collect_relic(0)
	check(game.relic_stages.size() == 1, "relic counter is idempotent")
	game._finish_stage()
	check(game.mode == "ending", "final scene reaches ending")
	game.free()
	print("CAMPAIGN TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _interact_stone(stage: Node) -> void:
	check(stage.can_collect_stone(), "stone prerequisites satisfied: " + str(stage.data.stone))
	stage.player.global_position = stage.stone.global_position + Vector3(0, -0.3, 0.5)
	var event := InputEventKey.new()
	event.physical_keycode = KEY_F
	event.pressed = true
	stage._unhandled_input(event)
	check(stage.data.stone in stage.echo.collected_stones, "F collected " + str(stage.data.stone))


func _ground_below(stage: Node, x: float, z: float) -> bool:
	var query := PhysicsRayQueryParameters3D.create(Vector3(x, 2.0, z), Vector3(x, -0.6, z), 1)
	query.exclude = [stage.player.get_rid()]
	return not stage.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _wall_blocks_route(stage: Node, z: float) -> bool:
	var query := PhysicsRayQueryParameters3D.create(Vector3(0, 1.0, z + 1.0), Vector3(0, 1.0, z - 1.0), 1)
	query.exclude = [stage.player.get_rid()]
	return not stage.get_world_3d().direct_space_state.intersect_ray(query).is_empty()
