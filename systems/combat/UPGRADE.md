# Combat upgrade

This branch adds combat behavior to the existing integrated campaign. It does not
replace the project's character models or claim production-quality authored art.
The previous procedural art remains; no new proxy character/enemy geometry was
introduced. Imported animation assets are still required for the requested
high-end animated look and a fully authored dodge-roll clip.

## Controls

- LMB: three-hit light chain. Queue the next press within the last 120 ms.
- RMB: heavy attack; repeated heavy hits break armor.
- Shift: grounded dodge, canceling startup/active/recovery immediately.
- 1–4: cosmetic weapon quick slots while idle (same melee stats, no player bow firing).
- Existing movement, jump, Q/E/Tab/X Echo controls, F interaction, and R respawn stay intact.

## Ownership

player_combat.gd owns combat phases, buffer, damage sweep and dodge timing.
vitals.gd owns health, temporary shields, recovery immunity, and death.
integration/player_adapter.gd delegates combat movement contributions to the
component; the existing traversal controller still owns collision movement.

combat_enemy.gd owns enemy health/armor, independent awareness/action/status
layers, suspicion, pursuit, return, attack timing and phase transitions.
combat_system.gd batches status outcomes into one response per cast.
integration/combat_bridge.gd validates range/occlusion and chooses AoE targets.
echo_combat_adapter.gd extends (does not edit) the Echo system. It owns the combat
energy economy, reservations, failed-cast refunds, snapshot extension, and rewards.
Traversal abilities are not charged combat energy and cannot be stranded by it.

Enemy states retain the old enum indices for compatibility. New states append
Suspicious, Hit Reaction, Airborne, Returning and Spawning. Awareness is tracked
separately, so Slow does not erase Freeze or attack phase.

## Tuning and rules

| Action | Startup | Active | Recovery | Base damage |
| --- | --- | --- | --- | --- |
| Light 1 | 7/60 s | 4/60 s | 13/60 s | 10 |
| Light 2 | 8/60 s | 5/60 s | 15/60 s | 13 |
| Light 3 | 12/60 s | 6/60 s | 20/60 s | 18 |
| Heavy | 24/60 s | 7/60 s | 27/60 s | 28 |

Physics time, not rendering FPS, determines hits. The sector sweep tests the whole
active-arc interval crossed each tick, enforces height/reach/line of sight, and
deduplicates victims per swing. Critical hits are deterministic rear attacks
during enemy recovery: 1.5x damage. The first physical hit against Freeze gains
1.5x shatter damage and consumes Freeze; critical and shatter multipliers stack.

Dodge lasts 0.42 s, gives immunity from 0.04–0.25 s, and has a 0.65 s cooldown.
An actually evaded hit grants one 8-point/2-second shield and a brief attacker
opening. Damage recovery immunity lasts 0.55 s; an attack cannot repeatedly hit
every frame. Death disables input/Echo and returns through traversal respawn
after 1.2 s. R also resets vitals. Defeated enemies stay defeated in the scene.

Earth stuns 2.5 s and removes armor; Wind pushes and launches non-frozen targets;
Water freezes 3 s; Time slows movement and attack progression to 30% for 4 s.
Stone armor resists non-Earth statuses until broken. Unarmored enemies can receive
all four effects; optional explicit immunities return a resisted outcome.
Freeze locks the complete body, including gravity and knockback. Timers expire in
real time; Slow never stretches itself indefinitely.

AoE radii: Earth 1.8 m, Wind 2 m, Water 1.4 m, Time 3 m. Every additional target
must also be within the player's 9 m reach and visible through the environment.
Time leaves a four-second aura; later entrants receive only its remaining time.

The combat Echo meter starts at 100. Successful casts cost 15 once, regardless
of target count. Failed/resisted casts cost nothing; pending casts reserve cost.
After 1.5 s it regenerates at 8/s. Launch/shatter/core-exposure rewards grant 8;
defeat grants 10. Rewards settle after cast cost, are deduplicated, and reward
amounts are defined by the Echo extension, not trusted from incoming payloads.
Deduplication caches retain the latest 512 requests/events per live instance;
these are local trusted-engine signals, not a multiplayer/network authority.

## Enemy progression

Generations 1–2 teach single-enemy timing, armor and knockback. Generation 3 adds
flanking groups; scene 8 introduces a ranged flanker. Slingers fire slow swept
projectiles blocked by world collision (including a frozen enemy). The Sentinel
in scene 9 has three health phases. Each phase requires Earth → Wind → Water →
Time to expose its core for six seconds; closed-core melee does not damage it.
Later phases alternate melee with marked ground hazards. No encounter requires
Water or Time before the campaign unlocks those abilities.

## Presentation integration

- Existing Lilo joints now read authoritative attack phases for torso twist,
  arm follow-through, braced legs and dodge/hurt/death poses.
- combat_visuals.gd renders a swept golden arc and can bind an authored
  AnimationPlayer. Supply clips named light_1, light_2, light_3, heavy, dodge,
  hurt, dead. Clips blend and scale to the combat clock; they never award damage.
- Existing enemy meshes use a noise-cutout spawn/defeat shader, not ragdolls or
  instant deletion. Existing scuttle and telegraph poses follow combat state.
- HUD displays real segmented health/shield, energy, phase, contextual overhead
  health/armor and white/yellow/red awareness. Four cosmetic slots remain melee.
- Existing pooled Echo effects are retained, with persistent Time aura rings,
  colored status surfaces, readable projectile and ground-hazard indicators.

Remaining art work: production rigged models/clips, layered authored AnimationTree,
foot IK, a full dodge roll, bespoke Earth shard/Wind ribbon/Water crystal effects,
and dissolve particles. Current shader dissolve is functional, not particle art.
No generated spheres/boxes are being represented as finished character assets.

## Validation

Run in Godot 4.7.2:

    godot --headless --path . --script res://systems/combat/tests/run_combat_tests.gd
    godot --headless --path . --script res://campaign/tests/run_tests.gd
    godot --headless --path . --script res://integration/tests/run_tests.gd

The combat upgrade suite covers 64 checks: active windows, combo buffering,
dodge cancellation/immunity, shields, damage validation, death/respawn, shatter,
criticals, armor resistance, launches, slow attack clock, AoE, response/cost
deduplication, meter persistence, aura entry/expiry, boss phases, real enemy
attacks, walls, suspicion and return. The old wrong-element integration assertion
now checks explicit immunity because unarmored cross-element combos are intended.
The legacy Combat test's leaked temporary system instance was also fixed.

Also run original Echo (51 checks), all-power (56 checks), integration (41 checks),
campaign (122 checks), and legacy Combat tests. GitHub CI includes the new suite
and rejects script errors, including tests that print a success exit code after
a GDScript runtime failure. Production-art fidelity and per-device 60 FPS are not
certified by these automated tests.
