extends SceneTree

const CombatEnemyScript = preload("res://systems/combat/combat_enemy.gd")
const CombatSystemScript = preload("res://systems/combat/combat_system.gd")

func _init() -> void:
	assert(CombatSystemScript.new() != null)
	var shellguard = CombatEnemyScript.new()
	shellguard.target_id = "shellguard"
	shellguard.archetype = CombatEnemyScript.Archetype.SHELLGUARD
	root.add_child(shellguard)
	assert(shellguard.echo_action("earth") == "stun")
	assert(shellguard.apply_echo_event({"target_id": "shellguard", "echo_id": "earth", "intended_effect": "stun"}))
	assert(shellguard.guard_broken)
	assert(shellguard.state != CombatEnemyScript.State.DEAD)

	var skitter = CombatEnemyScript.new()
	skitter.target_id = "skitter"
	skitter.archetype = CombatEnemyScript.Archetype.SKITTER
	root.add_child(skitter)
	assert(skitter.echo_action("wind") == "push")

	print("Combat tests passed")
	quit()
