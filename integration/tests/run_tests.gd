extends SceneTree

var checks: int = 0
var failures: int = 0
var responses: Array[Dictionary] = []


func _initialize() -> void:
	_run.call_deferred()


func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(description)


func _run() -> void:
	var game: Node = load("res://integration/team_game.tscn").instantiate()
	root.add_child(game)
	for frame in 30:
		await physics_frame
		if game.initialized:
			break
	check(game.initialized, "Combined scene initializes")
	if not game.initialized:
		quit(1)
		return
	game.player.set_physics_process(false)
	game.controls.set_physics_process(false)
	game.echo.set_process(false)
	game.echo.ability_finished.connect(func(response: Dictionary): responses.append(response))
	for enemy: Node in game.enemies:
		enemy.set_physics_process(false)
	check(game.player is Player and game.world.get_node("Player") == game.player, "Uses Traversal's real player, not Echo's demo player")
	check(game.combat is CombatSystem, "Uses team's CombatSystem")
	check(game.combat._targets.size() == 4, "All four enemy archetypes registered")
	var interaction_keys := InputMap.action_get_events("interact")
	check(interaction_keys.size() == 1 and interaction_keys[0].physical_keycode == KEY_F, "Interaction remapped to F")
	check(InputMap.action_get_events("echo_personal")[0].physical_keycode == KEY_E, "E remains personal power")
	Input.action_press("move_right")
	game.wheel.open()
	game.player._apply_horizontal_movement(0.1)
	check(game.player.wheel_open and is_zero_approx(game.player.velocity.x), "Wheel blocks Traversal movement input")
	game.wheel.select_direction(Vector2.RIGHT)
	game.wheel.close()
	Input.action_release("move_right")
	check(not game.player.wheel_open and game.echo.active_echo == "wind", "Wheel release selects Wind and restores player control")
	game.echo.cooldown_seconds = 0.6
	for data: Array in [["earth", "stun", "shellguard"], ["wind", "push", "skitter"], ["water", "freeze", "scout"], ["time", "slow", "slinger"]]:
		var enemy: Node3D = game.combat._targets[data[2]]
		game.player.global_position = enemy.global_position + Vector3(0, 0, 2.5)
		game.echo._process(1)
		if data[0] != "time":
			game.echo.summon(data[0])
		responses.clear()
		var request: String = game.echo.request_ability(data[0], data[1], data[2], enemy.global_position, "combat", {"origin": game.player.global_position})
		check(not request.is_empty() and responses.size() == 1 and responses[0]["success"], "%s -> actual Combat -> successful response" % data[0])
		check(enemy._status_remaining.has(data[1]), "%s applies Combat-owned status" % data[1])
		check(not game.echo.can_use(data[0]), "Combat acknowledgment starts Echo cooldown")
		if data[0] == "earth":
			check(enemy.guard_broken, "Earth breaks Combat shellguard defense")
	game.echo._process(1)
	game.echo.summon("earth")
	var scout: Node3D = game.combat._targets["scout"]
	game.player.global_position = scout.global_position + Vector3(0, 0, 2)
	responses.clear()
	game.echo.request_ability("earth", "stun", "scout", scout.global_position, "combat")
	check(responses.size() == 1 and not responses[0]["success"] and game.echo.can_use("earth"), "Wrong element is rejected without consuming cooldown")
	game.player.global_position = Vector3(40, 10, 40)
	responses.clear()
	game.echo.request_ability("earth", "stun", "shellguard", Vector3.ZERO, "combat")
	check(responses.size() == 1 and not responses[0]["success"], "Combat bridge rejects out-of-range cast")
	var late: Node3D = game.spawn_enemy("late_scout", 0, game.player.spawn_position + Vector3(2, 0, 0))
	late.set_physics_process(false)
	await process_frame
	await process_frame
	check(game.combat._targets.get("late_scout") == late, "Enemy spawned after CombatSystem registers after ready")
	game.echo.summon("water")
	game.player.global_position = late.global_position + Vector3(0, 0, 2)
	responses.clear()
	game.echo.request_ability("water", "freeze", "late_scout", late.global_position, "combat")
	check(responses.size() == 1 and responses[0]["success"], "Dynamically registered enemy receives Echo power")
	late.free()
	game.echo._process(1)
	responses.clear()
	game.echo.request_ability("water", "freeze", "late_scout", Vector3.ZERO, "combat")
	check(responses.size() == 1 and not responses[0]["success"], "Freed target rejects safely")
	game.player.global_position = game.player.spawn_position
	game.echo.summon("wind")
	responses.clear()
	game.echo.request_ability("wind", "glide", "player")
	check(game.player.current_state == Player.MovementState.GLIDING and responses[0]["success"], "Wind event reaches real Traversal state machine")
	game.echo._process(1)
	game.player.glide_remaining = 0
	game.player._physics_process(0.016)
	check(game.player.current_state != Player.MovementState.GLIDING, "Timed glide exits Traversal state")
	game.echo.request_ability("wind", "air_dash", "player", game.player.global_position, "traversal", {"direction": Vector3.RIGHT})
	game.player._apply_horizontal_movement(0.016)
	check(game.player.velocity.x > 10, "Wind dash feeds actual player movement")
	game.echo._process(1)
	game.echo.summon("water")
	var basin: Node3D = game.targets["water_basin"]
	game.player.global_position = basin.global_position + Vector3(-4, 0, 0)
	responses.clear()
	game.echo.request_ability("water", "freeze_water", basin.target_id, basin.global_position)
	check(responses.size() == 1 and responses[0]["success"] and basin.active, "Water freezes an actual integrated path")
	game.echo._process(1)
	game.echo.request_ability("water", "freeze_water", basin.target_id, basin.global_position)
	check(not basin.active, "Integrated ice path can be thawed")
	game.player.global_position = basin.global_position - Vector3.UP * 0.15
	game._physics_process(0.016)
	game.echo._process(1)
	responses.clear()
	game.echo.request_ability("water", "underwater_access", basin.target_id, basin.global_position)
	game.player._process_swimming(0.1)
	check(responses.size() == 1 and responses[0]["success"] and game.player.current_state == Player.MovementState.SWIMMING and game.player.velocity.y < 0, "Water dives using Traversal at the basin's world height")
	var relic: Node3D = game.targets["time_relic"]
	game.player.global_position = relic.global_position + Vector3(0, 0, 3)
	game.echo._process(1)
	responses.clear()
	game.echo.request_ability("time", "freeze_object", relic.target_id, relic.global_position)
	var relic_position: Vector3 = relic.global_position
	relic._physics_process(0.1)
	check(responses.size() == 1 and responses[0]["success"] and relic.global_position.is_equal_approx(relic_position), "Personal Time stops integrated relic while Water ancestor stays active")
	game.echo._process(1)
	responses.clear()
	game.echo.request_ability("time", "reset_object", relic.target_id, relic.global_position)
	check(responses.size() == 1 and responses[0]["success"] and relic.position.is_equal_approx(relic.home), "Time reset works on integrated world object")
	game.echo._process(1)
	game.echo.summon("earth")
	var hint_target: Node = game.targets["earth_memory"]
	game.player.trigger_echo_interaction(hint_target, {"echo_type": "earth", "hint": "Integration hint"})
	check(game._interaction_events == 1 and game.echo.heard_hints.size() == 1, "Traversal two-argument interaction signal converts into Echo knowledge")
	game.player.trigger_echo_interaction(hint_target, {"echo_type": "earth", "hint": "Integration hint"})
	check(game.echo.heard_hints.size() == 1, "Hints do not repeat through bridge")
	var patch: Node3D = game.targets["earth_platform"]
	game.player.global_position = patch.global_position + Vector3(0, 0, 3)
	responses.clear()
	game.echo.request_ability("earth", "raise_platform", patch.target_id, patch.global_position)
	check(responses.size() == 1 and responses[0]["success"] and patch.form == "platform", "Earth raises a platform on Traversal terrain")
	var checkpoint: Node
	for area: Node in game.world.find_children("*", "Area3D", true, false):
		if area.has_method("get_respawn_position"):
			checkpoint = area
			break
	check(checkpoint != null, "Team island includes a real checkpoint")
	if checkpoint:
		checkpoint.activate(game.player)
		game.player.respawn()
		check(game.player.global_position.is_equal_approx(checkpoint.get_respawn_position()), "Respawn uses Traversal's checkpoint")
		check(game.player.dash_remaining == 0 and game.player.glide_remaining == 0 and patch.form == "platform", "Respawn clears temporary movement but preserves Echo world changes")
	# Combat remains authoritative for enemy health and defeated state.
	var shell: Node = game.combat._targets["shellguard"]
	check(shell.take_damage(500, game.player.global_position, true) and shell.state == CombatEnemy.State.DEAD, "Damage/death stays in Combat implementation")
	game.free()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	print("Team integration tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
