extends SceneTree
const Catalog = preload("res://campaign/catalog.gd")
var failures := 0
var checks := 0

func _initialize() -> void:
	create_timer(30).timeout.connect(func(): push_error("FAIL: campaign test timeout"); quit(1))
	run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: " + label)
	else:
		print("PASS: ", label)

func run() -> void:
	await checkpoint_checks()
	var game := preload("res://campaign/main.tscn").instantiate()
	game.persistence_enabled = false
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
		check(not stage.next_objective().title.is_empty(), "scene has actionable guidance")
		check(stage.next_objective().at.is_finite(), "objective beacon has finite position")
		if i in [2, 4, 6]:
			check(not game.echo.focus_personal and game.echo.personal_power().is_empty(), "new keeper has no stale personal selection")
			check(game.echo.valid_snapshot(game.echo.snapshot()), "generation handoff creates restorable state")
			var quick := InputEventKey.new()
			quick.physical_keycode = KEY_1
			quick.pressed = true
			stage._unhandled_input(quick)
			check(game.echo.active_echo == "earth", "quick select calls inherited Earth")
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
			if task == "air_dash":
				stage.player.position = Vector3(0, 0.15, 6)
				game.echo.request_ability(element, task, target.target_id, target.global_position, channel)
				check(not stage.wind_crossing_armed and task not in stage.completed, "casting Wind away from channel cannot complete crossing")
				game.echo.cooldowns.clear()
				stage.player.position = Vector3(0, 0.15, -6)
			await physics_frame
			var id: String = game.echo.request_ability(element, task, target.target_id, target.global_position, channel, {"origin": stage.player.global_position, "direction": Vector3.FORWARD})
			check(not id.is_empty(), "request accepted: %d %s" % [i + 1, task])
			if task == "air_dash":
				check(task not in stage.completed, "Wind requires reaching the other shore")
				stage.player.position = Vector3(0, 0.15, -9 if i == 5 else -17)
				stage._physics_process(0)
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
		check(stage.next_objective().at == stage.exit_at, "completed chapter points toward exit")
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
	await create_timer(0.15).timeout
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
	check(stage.echo.selected_power() == stage.data.stone, "discovery focuses the new personal gift")

func checkpoint_checks() -> void:
	var storage = preload("res://campaign/checkpoint.gd")
	var echo := preload("res://systems/echo/echo_system.gd").new()
	echo.enforce_story_order = true
	root.add_child(echo)
	var entry := {"version": 1, "stage": 0, "echo": echo.snapshot(), "relics": []}
	check(storage.valid(entry, echo), "fresh chapter checkpoint valid")
	var path := "user://echo_island_checkpoint_regression.json"
	check(storage.write_checkpoint(entry, echo, path), "checkpoint writes successfully")
	check(not storage.read_checkpoint(echo, path).is_empty(), "checkpoint survives JSON round trip")
	check(echo.restore(storage.read_checkpoint(echo, path).echo), "saved Echo state restores")
	var bad := entry.duplicate(true)
	bad.stage = 8
	check(not storage.valid(bad, echo), "reject chapter beyond inherited powers")
	bad = entry.duplicate(true)
	bad.stage = 0.5
	check(not storage.valid(bad, echo), "reject fractional chapter")
	bad = entry.duplicate(true)
	bad.relics = [0]
	check(not storage.valid(bad, echo), "reject current chapter relic in entry checkpoint")
	bad = entry.duplicate(true)
	bad.echo.story_order = false
	check(not storage.valid(bad, echo), "reject sandbox unlock state in campaign save")
	echo.collect_stone("earth")
	echo.select_power("earth")
	check(echo.focus_personal, "Earth discovery selects personal focus")
	check(echo.begin_generation(2), "generation advances through public API")
	check(not echo.focus_personal and echo.valid_snapshot(echo.snapshot()), "handoff resets focus and remains serializable")
	entry = {"version": 1, "stage": 2, "echo": echo.snapshot(), "relics": [0]}
	check(storage.write_checkpoint(entry, echo, path), "atomic checkpoint replacement succeeds")
	check(storage.read_checkpoint(echo, path).get("stage", -1) == 2, "replacement contains newer chapter")
	bad = entry.duplicate(true)
	bad.relics = [0, 0]
	check(not storage.valid(bad, echo), "reject duplicate relics")
	bad = entry.duplicate(true)
	bad.echo.focus_personal = true
	check(not storage.valid(bad, echo), "reject personal selection before discovery")
	check(not storage.write_checkpoint(bad, echo, path), "invalid save cannot overwrite valid checkpoint")
	check(storage.read_checkpoint(echo, path).get("stage", -1) == 2, "last valid checkpoint preserved")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("{broken-json")
	file.close()
	check(storage.read_checkpoint(echo, path).is_empty(), "corrupt checkpoint safely returns to title")
	DirAccess.remove_absolute(path)
	echo.free()
