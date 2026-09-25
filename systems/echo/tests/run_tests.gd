extends SceneTree

const EchoSystem = preload("res://systems/echo/echo_system.gd")
const EarthTarget = preload("res://systems/echo/earth_target.gd")
var failures: int = 0
var checks: int = 0
var events: Array[Dictionary] = []

class ControlledInput:
	extends "res://systems/echo/echo_input.gd"
	func _update_target() -> void:
		pass # Supply a deterministic aim target while exercising real input handling.
	func _update_preview() -> void:
		_destination = Vector3(0, 0, 4)


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)


func _run() -> void:
	var echo := EchoSystem.new()
	echo.enforce_story_order = true
	root.add_child(echo)
	echo.set_process(false)
	check(echo.personal_power().is_empty() and echo.unlocked_echoes().is_empty(), "Generation 1 begins without powers")
	check(not echo.summon("earth") and not echo.collect_stone("time"), "Future powers are locked")
	check(not echo.begin_generation(2), "Cannot skip stone discovery")
	check(echo.collect_stone("earth") and not echo.collect_stone("earth"), "Stone unlocks once")
	check(echo.generation == 1 and echo.personal_power() == "earth", "Collection does not advance story")
	echo.TraversalAbilityEvent.connect(func(event: Dictionary): events.append(event))
	echo.AbilityEvent.connect(func(event: Dictionary): events.append(event))
	var id := echo.request_ability("earth", "crack", "rock")
	check(not id.is_empty() and events.back()["ability_id"] == "earth.crack", "Earth emits named event payload")
	check(echo.request_ability("earth", "crack", "rock").is_empty(), "Pending requests block repeated same-power casts")
	check(not echo.receive_traversal_response({"request_id": id, "target_id": "wrong", "success": true, "resulting_status": "crack"}), "Wrong target cannot resolve a cast")
	check(not echo.receive_ability_response({"request_id": id, "target_id": "rock", "success": true, "resulting_status": "crack"}), "Wrong receiver channel cannot resolve a cast")
	check(echo.receive_traversal_response({"request_id": id, "target_id": "rock", "success": false, "resulting_status": "blocked"}), "Receiver can reject cast")
	check(echo.can_use("earth"), "Rejected cast has no cooldown")
	id = echo.request_ability("earth", "crack", "rock")
	var success := {"request_id": id, "target_id": "rock", "success": true, "resulting_status": "cracked"}
	check(echo.receive_traversal_response(success) and not echo.can_use("earth"), "Successful response starts cooldown")
	check(not echo.receive_traversal_response(success), "Duplicate responses are ignored")
	echo._process(1.0)
	check(echo.can_use("earth"), "Cooldown expires")
	id = echo.request_ability("earth", "move", "rock")
	echo._process(4.0)
	check(echo.can_use("earth"), "Missing receiver times out without consuming power")
	check(not echo.receive_traversal_response({"request_id": id, "target_id": "rock", "success": true, "resulting_status": "late"}), "Late response is ignored")
	check(echo.request_ability("earth", "freeze", "rock").is_empty(), "Invalid effect is rejected")
	check(echo.begin_generation(2) and echo.summon("earth"), "Next generation inherits Earth")
	check(echo.collect_stone("wind") and echo.selected_power() == "earth" and echo.selected_power(true) == "wind", "Personal and ancestral powers coexist")
	var hint := {"echo_id": "earth", "object_or_area_id": "ruins", "hint": "Look below."}
	check(echo.receive_echo_interaction(hint) and not echo.receive_echo_interaction(hint), "Contextual hint appears once")
	check(echo.begin_generation(3) and echo.collect_stone("water"), "Generation 3 discovers Water")
	check(echo.begin_generation(4) and echo.collect_stone("time"), "Generation 4 discovers Time")
	check(echo.all_stones_collected() and not echo.summon("time"), "Time is personal, never an ancestor")
	check(echo.summon("water") and echo.selected_power(true) == "time", "Time coexists with Water Echo")
	id = echo.request_ability("time", "slow", "enemy", Vector3.ZERO, "combat")
	check(not id.is_empty() and not echo.request_ability("water", "freeze", "enemy", Vector3.ZERO, "combat").is_empty(), "Personal and ancestor can have independent pending casts")
	echo._process(4.0)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(echo.snapshot()))
	echo.dismiss()
	check(echo.restore(saved) and echo.active_echo == "water", "JSON round trip restores ancestor")
	check(echo.heard_hints.has("earth:ruins"), "Hint knowledge persists across generations and save")
	var corrupt := saved.duplicate(true)
	corrupt["generation"] = 9
	check(not echo.restore(corrupt) and echo.generation == 4, "Invalid save leaves state untouched")
	corrupt = saved.duplicate(true)
	corrupt["collected_stones"] = ["time"]
	check(not echo.restore(corrupt), "Save cannot skip inheritance order")
	corrupt = saved.duplicate(true)
	corrupt["cooldowns"] = {"water": -1}
	check(not echo.restore(corrupt), "Invalid cooldown rejected")
	var world := Node3D.new()
	root.add_child(world)
	var rock := EarthTarget.new()
	rock.target_id = "rock"
	world.add_child(rock)
	var patch := EarthTarget.new()
	patch.kind = "ground"
	patch.position = Vector3(5, 0, 0)
	world.add_child(patch)
	var buried := EarthTarget.new()
	buried.kind = "discovery"
	buried.position = Vector3(-5, 0, 0)
	world.add_child(buried)
	await physics_frame
	await physics_frame
	check(rock.apply_earth("move", Vector3(0, 0, 4)), "Rock can be moved into clear terrain")
	check(rock.damage == 0, "Moving never also cracks rock")
	await physics_frame
	check(not rock.apply_earth("move", patch.position), "Rock placement rejects occupied terrain")
	check(not rock.apply_earth("move", Vector3(100, 0, 0)), "Rock cannot be placed outside island")
	check(patch.apply_earth("raise_platform", patch.position), "Tap raises platform")
	check(patch.form == "platform", "Platform state recorded")
	var world_saved: Dictionary = JSON.parse_string(JSON.stringify(patch.snapshot()))
	check(patch.apply_earth("lower", patch.position), "Player can deliberately lower platform")
	check(patch.valid_snapshot(world_saved), "World state JSON validates")
	patch.restore(world_saved)
	check(patch.form == "platform", "Raised platform restores after load")
	check(patch.apply_earth("lower", patch.position) and patch.apply_earth("raise_barrier", patch.position), "Hold raises barrier after lowering")
	check(buried.apply_earth("reveal", buried.position) and not buried.apply_earth("reveal", buried.position), "Discovery persists and cannot be triggered twice")
	check(rock.apply_earth("crack", rock.position) and rock.damage == 1, "First tap visibly cracks rock")
	check(rock.apply_earth("crack", rock.position) and rock.damage == 2 and rock.collision_layer == 0, "Second tap removes rock collision")
	check(not rock.apply_earth("move", Vector3.ZERO), "Broken rock cannot be moved")
	var input_echo := EchoSystem.new()
	input_echo.enforce_story_order = true
	root.add_child(input_echo)
	input_echo.set_process(false)
	input_echo.cooldown_seconds = 0.0
	input_echo.collect_stone("earth")
	var input_events: Array[Dictionary] = []
	input_echo.TraversalAbilityEvent.connect(func(event: Dictionary):
		input_events.append(event)
		input_echo.receive_traversal_response({"request_id": event["request_id"], "target_id": event["target_id"], "success": true, "resulting_status": "test"}))
	var fresh_rock := EarthTarget.new()
	fresh_rock.target_id = "input_rock"
	world.add_child(fresh_rock)
	var actor := Node3D.new()
	world.add_child(actor)
	var camera := Camera3D.new()
	world.add_child(camera)
	var controls := ControlledInput.new()
	world.add_child(controls)
	controls.configure(input_echo, camera, actor)
	controls.set_physics_process(false)
	controls.target = fresh_rock
	await process_frame
	Input.action_press("echo_primary")
	controls._physics_process(0.01)
	await process_frame
	Input.action_release("echo_primary")
	controls._physics_process(0.05)
	check(input_events.size() == 1 and input_events.back()["intended_effect"] == "crack", "Short Q press emits exactly one crack")
	await process_frame
	Input.action_press("echo_primary")
	controls._physics_process(0.01)
	await process_frame
	controls._physics_process(0.4)
	Input.action_release("echo_primary")
	controls._physics_process(0.01)
	check(input_events.size() == 2 and input_events.back()["intended_effect"] == "move", "Held Q emits move without also cracking")
	await process_frame
	Input.action_press("echo_primary")
	controls._physics_process(0.01)
	controls.cancel()
	await process_frame
	Input.action_release("echo_primary")
	controls._physics_process(0.01)
	check(input_events.size() == 2, "Cancelled hold applies no effect")
	input_echo.free()
	world.free()
	echo.free()
	var sandbox: Node3D = load("res://systems/echo/demo/echo_sandbox.tscn").instantiate()
	sandbox.start_unlocked = false
	sandbox.save_path = "user://echo_automated_test_%d.json" % Time.get_ticks_usec()
	root.add_child(sandbox)
	sandbox.set_process(false)
	sandbox.set_physics_process(false)
	sandbox.controls.set_physics_process(false)
	await physics_frame
	await physics_frame
	sandbox.echo.collect_stone("earth")
	var sandbox_patch: StaticBody3D = sandbox.targets["platform_clearing"]
	check(sandbox_patch.apply_earth("raise_platform", sandbox_patch.position), "Sandbox platform raises")
	sandbox.save_demo()
	sandbox.echo.begin_generation(2)
	check(sandbox_patch.form == "platform", "Generation transition preserves world changes")
	sandbox_patch.apply_earth("lower", sandbox_patch.position)
	sandbox.load_demo()
	check(sandbox.echo.generation == 1 and sandbox.echo.personal_power() == "earth" and sandbox_patch.form == "platform", "Actual save/load restores inheritance and world together")
	var bad_file := FileAccess.open(sandbox.save_path, FileAccess.WRITE)
	bad_file.store_string("{broken JSON")
	bad_file.close()
	sandbox.load_demo()
	check(sandbox.echo.personal_power() == "earth" and sandbox_patch.form == "platform", "Corrupt file does not partially mutate sandbox")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(sandbox.save_path))
	sandbox.free()
	print("Echo tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
