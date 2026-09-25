extends SceneTree

const EchoSystem = preload("res://systems/echo/echo_system.gd")
const Wheel = preload("res://systems/echo/echo_wheel.gd")
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


func cast(lab: Node, element: String, action: String, id: String, at: Vector3 = Vector3.ZERO, channel: String = "traversal") -> bool:
	responses.clear()
	var request: String = lab.echo.request_ability(element, action, id, at, channel, {"origin": lab.player.position, "direction": lab.player.facing})
	return not request.is_empty() and not responses.is_empty() and responses.back()["success"]


func _run() -> void:
	var core := EchoSystem.new()
	root.add_child(core)
	check(core.collect_stone("water") and core.summon("water"), "Standalone Water unlock works before Earth")
	check(core.collect_stone("time") and core.personal_power() == "time", "Personal Time unlock is independent of order")
	check(core.select_power("time") and core.active_echo == "water" and core.selected_power() == "time", "Time wheel selection keeps ancestor alongside player")
	var save: Dictionary = JSON.parse_string(JSON.stringify(core.snapshot()))
	check(core.valid_snapshot(save), "Out-of-order save validates")
	core.dismiss()
	check(core.restore(save) and core.active_echo == "water" and core.focus_personal, "Wheel focus and ancestor survive save/load")
	var wheel := Wheel.new()
	wheel.system = core
	root.add_child(wheel)
	wheel.open()
	wheel.select_direction(Vector2.UP)
	check(wheel.selection == 0 and not wheel.available(0), "Wheel identifies locked Earth slot")
	wheel.close()
	check(core.active_echo == "water", "Locked wheel selection cannot replace ancestor")
	core.unlock_all()
	wheel.open()
	wheel.select_direction(Vector2.RIGHT)
	wheel.close()
	check(core.active_echo == "wind" and core.selected_power() == "wind", "Wheel selects Wind directly")
	wheel.open()
	wheel.select_direction(Vector2.DOWN)
	wheel.close(false)
	check(core.active_echo == "wind", "Wheel cancel keeps existing ancestor")
	wheel.open()
	wheel.select_direction(Vector2.LEFT)
	wheel.close()
	check(core.selected_power() == "time" and core.active_echo == "wind", "Time can be selected without dismissing Wind")
	wheel.free()
	core.free()
	var lab: Node = load("res://systems/echo/demo/echo_sandbox.tscn").instantiate()
	lab.save_path = "user://echo_powers_test_%d.json" % Time.get_ticks_usec()
	root.add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab.controls.set_physics_process(false)
	lab.echo.set_process(false)
	lab.echo.cooldown_seconds = 0
	lab.enemy.set_physics_process(false)
	for target: Node in lab.targets.values():
		target.set_physics_process(false)
	lab.echo.ability_finished.connect(func(response: Dictionary): responses.append(response))
	await physics_frame
	await physics_frame
	check(lab.echo.all_stones_collected() and lab.echo.unlocked_echoes().size() == 3, "Playground starts with every power available")
	await process_frame
	Input.action_press("echo_wheel")
	lab.controls._physics_process(0.01)
	check(lab.wheel.is_open, "Holding Tab opens the wheel through the input adapter")
	Input.action_press("echo_primary")
	lab.controls._physics_process(0.01)
	check(lab.controls._pressed_action.is_empty(), "Wheel blocks power charging")
	lab.wheel.select_direction(Vector2.RIGHT)
	await process_frame
	Input.action_release("echo_primary")
	Input.action_release("echo_wheel")
	lab.controls._physics_process(0.01)
	check(not lab.wheel.is_open and lab.echo.active_echo == "wind", "Releasing Tab summons highlighted ancestor")
	await physics_frame
	check(not lab.targets["rock_west"].can_place(Vector3(7, 0, -3), Vector3(1.5, 1.6, 1.4)), "Earth rock placement rejects unsupported water")
	lab.echo.summon("wind")
	lab.player.facing = Vector3.LEFT
	lab.player.position = Vector3(0, 1, 4)
	check(cast(lab, "wind", "air_dash", "player"), "Wind dash accepted by Traversal receiver")
	var before: Vector3 = lab.player.position
	lab.player.step(0.05, false)
	check(lab.player.position.x < before.x, "Wind dash physically moves character")
	lab.player.dash_remaining = 0
	lab.player.position = Vector3(0, 5, 4)
	lab.player.velocity.y = -10
	check(cast(lab, "wind", "glide", "player"), "Wind glide activates")
	lab.player.step(0.1, false)
	check(lab.player.velocity.y >= -1.5 and lab.player.glide_remaining > 0, "Glide limits falling speed")
	check(cast(lab, "wind", "glide", "player") and lab.player.glide_remaining == 0, "Player can dismiss glide deliberately")
	lab.player.position = Vector3(-8, 0, 4)
	var vent: Node = lab.targets["wind_vent"]
	check(cast(lab, "wind", "wind_current", vent.target_id, vent.position) and vent.active, "Wind creates persistent updraft")
	lab.player.position = Vector3(-8, 0, 2)
	lab._physics_process(0.016)
	check(lab.player.velocity.y >= 8 and lab.player.movement_state == "updraft", "Vent lifts character physically")
	lab.echo.summon("earth")
	check(vent.active, "Updraft persists when switching ancestors")
	lab.echo.summon("wind")
	check(cast(lab, "wind", "wind_current", vent.target_id, vent.position) and not vent.active, "Player can turn off updraft")
	lab.echo.summon("water")
	var pool: Node = lab.targets["water_basin"]
	lab.player.position = Vector3(3, 0, -3)
	check(cast(lab, "water", "freeze_water", pool.target_id, pool.position) and pool.active and pool.collision_layer == 1, "Water makes solid traversable ice")
	check(cast(lab, "water", "freeze_water", pool.target_id, pool.position) and not pool.active and pool.collision_layer == 4, "Water thaws the ice deliberately")
	lab.player.position = Vector3(7, -0.2, -3)
	check(not cast(lab, "water", "freeze_water", pool.target_id, pool.position), "Cannot trap a swimmer beneath new ice")
	check(cast(lab, "water", "underwater_access", pool.target_id, pool.position), "Water grants underwater access")
	lab._physics_process(0.1)
	check(lab.player.movement_state == "diving" and lab.player.velocity.y < 0, "Underwater power dives below surface")
	lab.player.underwater_remaining = 0
	lab.player.position.y = -1.5
	lab._physics_process(0.1)
	check(lab.player.velocity.y > 0, "Expired underwater access brings player toward surface")
	var stream: Node = lab.targets["water_stream"]
	lab.player.position = Vector3(-10, 0, -1)
	check(cast(lab, "water", "redirect_current", stream.target_id, stream.position) and stream.reversed, "Water redirects current")
	lab.player.position = Vector3(-10, 0, -4)
	lab._physics_process(0.016)
	check(lab.player.external_velocity.z < 0, "Reversed current physically affects movement")
	lab.player.position = Vector3(0, 0, -5)
	var relic: Node = lab.targets["time_relic"]
	relic._physics_process(0.5)
	var moving_position: Vector3 = relic.position
	check(not moving_position.is_equal_approx(relic.home), "Time relic moves before cast")
	check(cast(lab, "time", "freeze_object", relic.target_id, relic.position), "Personal Time freezes moving object with Water ancestor present")
	relic._physics_process(0.5)
	check(relic.position.is_equal_approx(moving_position), "Time freeze actually stops motion")
	relic._physics_process(7.0)
	relic._physics_process(0.1)
	check(not relic.position.is_equal_approx(moving_position), "Motion resumes after Time freeze expires")
	check(cast(lab, "time", "reset_object", relic.target_id, relic.position) and relic.position.is_equal_approx(relic.home), "Time reset returns designated object to original state")
	lab.player.position = Vector3(4, 0, 4)
	for pair: Array in [["earth", "stun"], ["wind", "push"], ["water", "freeze"], ["time", "slow"]]:
		lab.enemy.effects.clear()
		lab.enemy.impulse = Vector3.ZERO
		if pair[0] != "time":
			lab.echo.summon(pair[0])
		check(cast(lab, pair[0], pair[1], lab.enemy.target_id, lab.enemy.position, "combat"), "%s ability reaches Combat receiver" % pair[0])
		check(lab.enemy.effects.has(pair[1]), "%s changes enemy status" % pair[1])
		if pair[1] in ["stun", "freeze"]:
			check(lab.enemy.movement_multiplier() == 0, "%s stops enemy movement" % pair[1])
		elif pair[1] == "slow":
			check(lab.enemy.movement_multiplier() == 0.25, "Time reduces enemy movement to one quarter")
		else:
			before = lab.enemy.position
			lab.enemy._physics_process(0.1)
			check(lab.enemy.position.x > before.x, "Wind physically pushes enemy away")
		lab.enemy._physics_process(31.0)
		check(lab.enemy.effects.is_empty(), "%s expires cleanly" % pair[1])
	lab.player.position = Vector3(-12, 0, -8)
	check(not cast(lab, "time", "slow", lab.enemy.target_id, lab.enemy.position, "combat"), "Combat rejects out-of-range target")
	# Persistent reference world changes and focus survive an actual disk save.
	lab.player.position = Vector3(3, 0, -3)
	lab.echo.summon("water")
	cast(lab, "water", "freeze_water", pool.target_id, pool.position)
	lab.echo.select_power("time")
	lab.save_demo()
	pool.active = false
	stream.reversed = false
	lab.echo.dismiss()
	lab.load_demo()
	check(pool.active and stream.reversed, "Ice and redirected currents survive disk save/load")
	check(lab.echo.focus_personal and lab.echo.active_echo == "water", "Personal focus and ancestor both restore")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(lab.save_path))
	lab.free()
	print("All-power tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
