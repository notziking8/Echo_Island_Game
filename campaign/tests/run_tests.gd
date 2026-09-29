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
				stage.player.global_position = target.global_position + Vector3(0, 0.1, 4)
			await physics_frame
			var id: String = game.echo.request_ability(element, task, target.target_id, target.global_position, channel, {"origin": stage.player.global_position, "direction": Vector3.FORWARD})
			check(not id.is_empty(), "request accepted: %d %s" % [i + 1, task])
			if task == "crack":
				check(task not in stage.completed, "one crack does not count as clearing rock")
				game.echo.cooldowns.clear()
				game.echo.request_ability(element, task, target.target_id, target.global_position, channel, {"origin": stage.player.global_position})
			check(task in stage.completed, "receiver acknowledged: %d %s" % [i + 1, task])
		if not str(Catalog.STAGES[i].stone).is_empty() and Catalog.STAGES[i].stone not in game.echo.collected_stones:
			_interact_stone(stage)
		for enemy in stage.enemies:
			enemy.take_damage(enemy.health, Vector3.INF)
		if "stun" in stage.completed:
			stage.completed.erase("stun")
			check("stun" not in stage.missing_tasks(), "defeating guard without stun cannot softlock exit")
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
