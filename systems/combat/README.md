# Combat system

`CombatEnemy` is a scene-ready `CharacterBody3D` component with the shared states
`IDLE`, `CHASE`, `ATTACK`, `STUNNED`, `FROZEN`, `SLOWED`, and `DEAD`. Select one
of its five archetypes in the Inspector: Scout, Slinger, Shellguard, Skitter, or
Ruin Guardian.

Add one `CombatSystem` node to the gameplay scene and assign Echo's `EchoSystem`
node to `echo_system`. Each enemy needs a unique `target_id`; CombatSystem routes
Echo's `AbilityEvent` to it and sends the response back to Echo only after the
effect has been applied.

| Archetype | Required Echo reaction |
| --- | --- |
| Shellguard / Ruin Guardian | Earth -> 2.5s stun and broken guard |
| Skitter | Wind -> directional knockback |
| Scout | Water -> 3.5s frozen |
| Slinger | Time -> 4s slow at 35% movement speed |

This foundation intentionally does not own Echo unlocks, player movement, cameras,
or scene art. Attach a target `Node3D` to `CombatEnemy.target` for pursuit, and
have the player call `take_damage`/`CombatEnemy.take_damage` from their hitboxes.
