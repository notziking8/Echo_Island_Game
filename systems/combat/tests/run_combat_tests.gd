extends SceneTree
const Enemy = preload("res://systems/combat/combat_enemy.gd")
const Controller = preload("res://systems/combat/player_combat.gd")
const Echo = preload("res://systems/combat/echo_combat_adapter.gd")
var checks := 0
var failures := 0
var world: Node3D
var player: CharacterBody3D
var controller: Node
var echo: Node
var bridge: Node
var responses: Array[Dictionary] = []

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + label)
	else:
		print("PASS: ", label)

func spawn(id: String, at: Vector3, archetype: int = 0) -> Node:
	var enemy := preload("res://integration/enemy_adapter.gd").new()
	enemy.target_id = id
	enemy.position = at
	enemy.archetype = archetype
	enemy.max_health = 200
	enemy.spawn_seconds = 0
	enemy.target = player
	world.add_child(enemy)
	enemy.set_physics_process(false)
	return enemy

func run() -> void:
	world = Node3D.new()
	root.add_child(world)
	var floor_body := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(60, 1, 60)
	collider.shape = shape
	floor_body.position.y = -0.5
	floor_body.add_child(collider)
	world.add_child(floor_body)
	player = preload("res://scenes/player/player.tscn").instantiate()
	player.set_script(preload("res://integration/player_adapter.gd"))
	player.position.y = 0.05
	world.add_child(player)
	controller = Controller.new()
	player.combat_controller = controller
	player.add_child(controller)
	controller.set_physics_process(false)
	for i in 15:
		await physics_frame
	player.set_physics_process(false)
	echo = Echo.new()
	world.add_child(echo)
	echo.unlock_all()
	echo.summon("earth")
	echo.set_process(false)
	echo.ability_finished.connect(func(response): responses.append(response))
	bridge = preload("res://integration/combat_bridge.gd").new()
	bridge.echo_system = echo
	bridge.player = player
	world.add_child(bridge)
	var enemy := spawn("test_scout", Vector3(0, 0, -2))
	await physics_frame
	await process_frame

	check(controller.request_attack("light"), "light starts")
	var hp: float = enemy.health
	controller.tick(0.10)
	check(enemy.health == hp and controller.phase == "startup", "startup cannot damage")
	controller.tick(0.09)
	check(enemy.health == hp - 10, "swept active arc hits once")
	controller.tick(0.05)
	check(enemy.health == hp - 10, "same swing cannot hit target twice")
	controller.tick(0.07)
	controller.request_attack("light")
	controller.tick(0.10)
	check(controller.attack.get("name") == "light_2", "buffer chains second light")
	controller.tick(0.39)
	controller.request_attack("light")
	controller.tick(0.09)
	check(controller.attack.get("name") == "light_3", "buffer chains third light")
	controller.cancel_attack()
	check(controller.request_attack("heavy"), "heavy starts")
	controller.tick(0.35)
	check(controller.phase == "startup", "heavy has longer windup")
	controller.cancel_attack()
	controller.request_attack("light")
	check(controller.request_dodge(), "dodge cancels startup on floor")
	check(controller.attack.is_empty(), "dodge disables outgoing attack")
	controller.tick(0.06)
	var health_before: float = controller.vitals.health
	var dodge_result: Dictionary = controller.receive_damage(15, enemy)
	check(dodge_result.outcome == "evaded" and controller.vitals.health == health_before, "dodge invulnerability rejects hit")
	check(controller.vitals.shield == 8 and enemy._status_remaining.has("slow"), "perfect dodge grants shield and opening")
	check(not controller.request_dodge(), "dodge cooldown prevents spam")
	controller.tick(0.40)
	check(not controller.vitals.invulnerable, "invulnerability ends")
	controller.vitals.reset()
	controller.vitals.grant_shield(20, 0.5)
	controller.receive_damage(25, enemy)
	check(controller.vitals.health == 95 and controller.vitals.shield == 0, "shield absorbs before health")
	controller.receive_damage(25, enemy)
	check(controller.vitals.health == 95, "recovery frames reject stacked hits")
	controller.tick(0.6)
	check(not controller.receive_damage(NAN).success, "NaN player damage rejected")
	controller.receive_damage(200, enemy)
	check(controller.vitals.dead and controller.phase == "dead", "death disables combat")
	controller.tick(1.3)
	check(controller.vitals.health == 100 and controller.phase == "idle", "death returns through traversal respawn")
	player.position = Vector3.ZERO

	enemy.health = 200
	enemy._status_remaining.clear()
	check(enemy.apply_echo_event({"target_id": enemy.target_id, "echo_id": "water", "intended_effect": "freeze"}), "unarmored enemy accepts Water")
	check(enemy._status_remaining.freeze == 3.0, "freeze lasts exactly 3 seconds")
	enemy.velocity = Vector3(2, 3, 4)
	enemy._physics_process(0.1)
	check(enemy.velocity == Vector3.ZERO, "freeze completely locks motion")
	var shatter: Dictionary = enemy.receive_hit({"damage": 20.0, "origin": player.position})
	check(shatter.shatter and shatter.damage == 30, "frozen hit has 50 percent shatter bonus")
	check(not enemy._status_remaining.has("freeze"), "shatter consumes freeze")
	check(not enemy.receive_hit({"damage": INF}).success, "infinite enemy damage rejected")
	enemy.attack_phase = "recovery"
	var critical: Dictionary = enemy.receive_hit({"damage": 10.0, "origin": player.position})
	check(critical.critical and critical.damage == 15, "rear recovery punish is deterministic critical")

	var shell := spawn("test_shell", Vector3(5, 0, -2), 2)
	await process_frame
	var resisted: Dictionary = shell.status_result({"target_id": shell.target_id, "echo_id": "water", "intended_effect": "freeze"})
	check(resisted.outcome == "resisted", "stone armor resists Water")
	shell.apply_echo_event({"target_id": shell.target_id, "echo_id": "earth", "intended_effect": "stun"})
	check(shell.guard_broken and shell.shield == 0 and shell._status_remaining.stun == 2.5, "Earth shatters armor and stuns for 2.5s")
	shell.apply_echo_event({"target_id": shell.target_id, "echo_id": "wind", "intended_effect": "push", "origin": Vector3.ZERO})
	check(shell._status_remaining.has("airborne") and shell.velocity.y > 0, "Wind launches stunned target")
	shell.apply_echo_event({"target_id": shell.target_id, "echo_id": "time", "intended_effect": "slow"})
	check(shell._status_remaining.slow == 4.0, "Time duration is 4s")
	shell._status_remaining.erase("airborne")
	shell.attack_phase = "startup"
	shell.attack_age = 0
	shell.awareness = Enemy.Awareness.ENGAGED
	shell._physics_process(0.1)
	check(is_equal_approx(shell.attack_age, 0.03), "Time slows attack clock by 70 percent")

	# Real Echo bridge, meter, AoE and duplicate request handling.
	player.position = Vector3(0, 0, 0)
	enemy.position = Vector3(0, 0, -2)
	enemy._status_remaining.clear()
	var neighbor := spawn("neighbor", Vector3(0.8, 0, -2))
	await physics_frame
	await process_frame
	echo.energy = 60
	echo.cooldowns.clear()
	responses.clear()
	var request: String = echo.request_ability("earth", "stun", enemy.target_id, enemy.position, "combat")
	check(not request.is_empty() and responses.size() == 1 and responses[0].success, "one cast produces one acknowledgement")
	check(responses[0].affected_targets.size() == 2, "AoE reports both nearby targets")
	check(enemy._status_remaining.has("stun") and neighbor._status_remaining.has("stun"), "AoE actually affects both targets")
	check(echo.energy == 45, "multi-target cast charges energy once")
	bridge.receive_ability_event({"request_id": request, "target_id": enemy.target_id, "echo_id": "earth", "intended_effect": "stun"})
	check(responses.size() == 1 and echo.energy == 45, "duplicate cast cannot charge or respond twice")
	echo.cooldowns.clear()
	echo.energy = 10
	check(echo.request_ability("earth", "stun", enemy.target_id, enemy.position, "combat").is_empty(), "insufficient energy blocks combat cast")
	check(not echo.request_ability("earth", "crack", "world_rock", Vector3.ZERO, "traversal").is_empty(), "combat meter does not block traversal")
	echo._process(4)
	check(echo.reservations.is_empty(), "timeouts release reservations")
	echo.energy = 40
	check(echo.receive_combat_event({"event_id": "test:1", "kind": "shatter_combo", "reward": 999}), "combo feedback accepted")
	check(echo.energy == 48, "Echo owns reward amount")
	check(not echo.receive_combat_event({"event_id": "test:1", "kind": "shatter_combo"}) and echo.energy == 48, "combo reward deduplicated")
	var saved: Dictionary = echo.snapshot()
	echo.energy = 0
	check(echo.restore(saved) and echo.energy == 48, "Echo energy survives snapshot round trip")
	var invalid := saved.duplicate()
	invalid.combat_energy = NAN
	check(not echo.restore(invalid) and echo.energy == 48, "invalid energy snapshot leaves state unchanged")
	echo.summon("earth")
	echo.energy = 100
	echo.cooldowns.clear()
	player.position = Vector3(25, 0, 25)
	responses.clear()
	echo.request_ability("earth", "stun", enemy.target_id, enemy.position, "combat")
	check(responses.size() == 1 and not responses[0].success and echo.energy == 100, "out-of-range cast has no energy cost")

	var guardian := spawn("guardian", Vector3(-5, 0, -2), 4)
	guardian.combo_guardian = true
	check(not guardian.receive_hit({"damage": 28.0, "origin": Vector3(-5, 0, 0)}).success, "Guardian core cannot be bypassed with rear brute force")
	for element: String in ["earth", "wind", "water", "time"]:
		guardian.apply_echo_event({"target_id": guardian.target_id, "echo_id": element, "intended_effect": Enemy.EFFECTS[element]})
	check(guardian.combo_step == 4 and guardian.exposed_remaining == 6, "four-element sequence exposes Guardian")
	guardian.take_damage(90, Vector3.INF)
	check(guardian.boss_phase == 2 and guardian.combo_step == 0 and not guardian.guard_broken, "Guardian phase transition restores counter sequence")
	guardian.take_damage(80, Vector3.INF)
	check(guardian.boss_phase == 3, "Guardian has third phase")
	var deaths: Array = []
	guardian.defeated.connect(func(dead): deaths.append(dead))
	guardian.take_damage(999, Vector3.INF)
	guardian.take_damage(999, Vector3.INF)
	check(deaths.size() == 1 and guardian.collision_layer == 0, "defeat happens once and disables collision")

	# Enemy damage uses real phases and player vitals, not contact polling.
	player.position = Vector3.ZERO
	controller.reset()
	enemy.position = Vector3(0, 0, -1.5)
	enemy._status_remaining.clear()
	enemy.target = player
	enemy._start_attack()
	enemy._tick_attack(0.39)
	check(controller.vitals.health == 100, "enemy startup is readable and harmless")
	enemy._tick_attack(0.02)
	check(controller.vitals.health == 90, "enemy active phase damages player")
	enemy._tick_attack(0.04)
	check(controller.vitals.health == 90, "enemy active phase hits only once")
	enemy._start_attack()
	enemy.apply_echo_event({"target_id": enemy.target_id, "echo_id": "earth", "intended_effect": "stun"})
	check(enemy.attack_phase == "idle", "stun cancels enemy attack")
	controller.reset()
	enemy._status_remaining.clear()
	enemy.health = 200
	enemy.guard_blocks_front = false
	enemy.position = Vector3(0, 0, -2)
	neighbor.position = Vector3(10, 0, -2)
	player.position = Vector3.ZERO
	echo.energy = 100
	echo.cooldowns.clear()
	echo.summon("earth")
	echo.request_ability("earth", "stun", enemy.target_id, enemy.position, "combat")
	echo.cooldowns.clear()
	echo.energy = 100
	echo.summon("wind")
	echo.request_ability("wind", "push", enemy.target_id, enemy.position, "combat")
	check(echo.energy == 93, "launch reward settles after cast cost even at full meter")
	enemy._status_remaining.clear()
	enemy.velocity = Vector3.ZERO
	enemy._knockback = Vector3.ZERO
	echo.cooldowns.clear()
	echo.select_power("time")
	echo.request_ability("time", "slow", enemy.target_id, enemy.position, "combat")
	var fields: Array = world.get_children().filter(func(child): return child.get_script() == preload("res://systems/combat/time_field.gd"))
	check(not fields.is_empty(), "Time cast creates a world-space aura")
	if not fields.is_empty():
		var field: Node = fields.back()
		field.set_physics_process(false)
		neighbor.position = Vector3(1, 0, -2)
		field._physics_process(1.0)
		check(is_equal_approx(neighbor._status_remaining.get("slow", 0), 3.0), "late aura entrant gets remaining three seconds")
		field._physics_process(3.0)
		check(field.is_queued_for_deletion(), "aura expires without extending lifetime")

	# Wall occlusion must block melee, Echo and enemy detection.
	var wall := StaticBody3D.new()
	var wall_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(8, 3, 0.3)
	wall_shape.shape = box
	wall.position = Vector3(0, 1.5, -1)
	wall.add_child(wall_shape)
	world.add_child(wall)
	await physics_frame
	controller.reset()
	enemy._status_remaining.clear()
	enemy.health = 200
	controller.request_attack("heavy")
	controller.tick(0.52)
	check(enemy.health == 200, "melee arc cannot hit through wall")
	echo.cooldowns.clear()
	echo.summon("earth")
	responses.clear()
	var energy_before: float = echo.energy
	echo.request_ability("earth", "stun", enemy.target_id, enemy.position, "combat")
	check(responses.size() == 1 and not responses[0].success and echo.energy == energy_before, "wall blocks Echo without spending energy")
	enemy.awareness = Enemy.Awareness.UNAWARE
	enemy.suspicion = 0
	enemy._update_awareness(1.0)
	check(enemy.awareness != Enemy.Awareness.ENGAGED, "wall blocks visual detection")
	wall.free()
	await physics_frame
	enemy._update_awareness(0.3)
	check(enemy.awareness == Enemy.Awareness.SUSPICIOUS, "visual detection first becomes suspicious")
	enemy._update_awareness(0.4)
	check(enemy.awareness == Enemy.Awareness.ENGAGED, "suspicion escalates into engagement")
	player.position = Vector3(25, 0, 25)
	enemy._update_awareness(3.0)
	check(enemy.awareness == Enemy.Awareness.RETURNING, "lost target returns to patrol area")
	world.free()
	print("COMBAT UPGRADE TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
