# Echo module integration

## Ownership and files

Echo owns active ancestor, unlocked Echoes/abilities, collected stones, ability
cooldowns, and remembered knowledge. It emits requests rather than directly
changing team-owned movement, health, enemy state, or world geometry.

| File | Responsibility |
| --- | --- |
| echo_system.gd | Inheritance state, selection, validation, requests/responses, cooldowns, hints, snapshots |
| power_catalog.gd | Shared proposed effect durations and strengths |
| echo_input.gd | Camera aiming, tap/hold controls, reach, cancellation and wheel integration |
| echo_wheel.gd | Hold/release selection with mouse or arrows, locked slots and personal-power focus |
| echo_ghost.gd | Replaceable procedural ancestor visual |
| earth_target.gd | Reference Earth object behavior, collision checks and persistent state |
| ability_target.gd | Minimal descriptor for a team-owned target |
| demo/echo_player.gd | Reference arrow movement, dash, glide, swimming and diving receiver |
| demo/echo_enemy.gd | Reference patrolling guardian with stun, push, freeze and slow reactions |
| demo/environment_target.gd | Reference updraft, water/ice, stream and moving Time object |
| demo/echo_sandbox.gd | Playground composition, event wiring, range validation, UI and save coordinator |

No inventory, branching dialogue, boss system, or generation-transition story is
implemented. The playground is an isolated integration fixture.

## Unlocks and selection

Default `enforce_story_order=false`: `collect_stone(element)` works in any order.
Earth, Wind and Water unlock their ancestors. Time unlocks the living descendant's
personal power. `unlock_all()` enables independent testing; the demo does this by
default. `unlocked_echoes()` and `unlocked_abilities()` derive their state from
unlocks. No story coordinator is needed.

For the later game, opt into `enforce_story_order=true`. In this mode generations
1–4 discover Earth/Wind/Water/Time respectively, previous ancestors become
available, and `begin_generation(next)` is explicitly called by the story owner.
Stone discovery never advances a generation automatically. The demo export
`start_unlocked=false` exercises this optional mode.

`summon(element)` selects one ancestor until switched/dismissed. `select_power`
also accepts the personal power: that changes Q's focus and keeps the ancestor.
`selected_power(true)` always returns the descendant's power for E. Time never
becomes an ancestral ghost. Observe `state_changed` to update the final HUD and
connect the active ancestor to the final character art.

## Input and wheel

Instantiate `echo_input.gd`, then call `configure(echo, camera, actor)`. Assign
its `wheel` to an `echo_wheel.gd` Control and assign the wheel's `system` to Echo.
Place the wheel last in the CanvasLayer for correct GUI hit testing. Respond to
`opened_changed` or `is_open` in Traversal to block movement input while choosing.
The wheel does not pause the scene tree or assume ownership of global time.

The adapter installs absent namespaced InputMap actions only: `echo_primary` (Q),
`echo_personal` (E), `echo_wheel` (Tab), `echo_dismiss` (X), `echo_cancel` (Esc).
Override these mappings in the team's project later. The old `echo_cycle` binding
is unused. Arrow movement and Space belong only to the demonstration player.

Targets implement `target_id`, `channel`, `echo_action(element, held)`,
`set_highlight(bool)`, and `prompt()`. `ability_target.gd` is a minimal example.
The actor can implement the same interface for untargeted movement powers, plus
a `facing: Vector3` for dash direction. CharacterBody3D and StaticBody3D targets
are both supported. Targeting uses collision layers 1 and 3 (bit values 1 and 4);
the reference actor collides with bit values 1 and 2. Unfrozen water is pickable
on bit 4 without preventing swimming. Adapt these layers to the real island.

## Four event seams

**AbilityEvent** is the exact Echo -> Combat signal. **TraversalAbilityEvent** is
the exact Echo -> Traversal signal. Both send a Dictionary:

```gdscript
{
    "request_id": "echo_1",          # Opaque per-instance request ID.
    "echo_id": "wind",              # Power source, ancestral or personal.
    "ability_id": "wind.push",
    "target_id": "enemy_42",         # Stable ID provided by the receiving system.
    "intended_effect": "push",
    "position": Vector3.ZERO,       # World-space target / placement destination.
    "origin": Vector3.ZERO,         # World-space caster position.
    "direction": Vector3.FORWARD,   # Normalized intended direction.
    "duration_seconds": 0.5,
    "strength": 9.0
}
```

For **AbilityResponse**, Combat calls `receive_ability_response(response)`:

```gdscript
{
    "request_id": event["request_id"],
    "target_id": event["target_id"],
    "success": true,
    "resulting_status": "pushed"
}
```

Traversal acknowledges via `receive_traversal_response` with the same response
shape. This explicit Traversal acknowledgment extends the original design so
blocked placements and unsupported actions can be rejected without consuming a
cooldown. Only successful responses start cooldowns. Wrong-channel, wrong-target,
duplicate and late responses are ignored. Missing receivers time out after 3s.

Receivers must resolve stable target IDs, validate eligibility, range and collision,
apply the effect, then acknowledge. Never report success before applying an effect.
The demo receivers actually change motion, geometry and statuses. Production
Combat still owns health, damage, immunity and enemy behavior; Traversal owns
movement, checkpoints and world interactions. Replace reference receivers while
retaining event names, payloads and acknowledgment behavior.

For **EchoInteractionEvent**, Traversal calls `receive_echo_interaction`:

```gdscript
echo.receive_echo_interaction({
    "echo_id": "water",
    "object_or_area_id": "water_basin",
    "hint": "We can make a path across this water, or seek what lies below."
})
```

Only the active ancestor speaks. A location/ancestor pair is remembered once.
Listen to `hint_ready(echo_id, text)` for UI; Traversal supplies location proximity
and authored hint content. Earth, Wind and Water have examples in the playground.

## Implemented power behavior

| Element | Actions and default behavior |
| --- | --- |
| Earth | `crack`: two taps destroy a rock; `move`: hold/preview/release into clear supported ground; `raise_platform` / `raise_barrier`: tap/hold on eligible patches; `lower`: undo raised structure; `reveal`: uncover guided discovery; `stun`: stop enemy for 2.5s |
| Wind | `air_dash`: 16 units/s for 0.25s, collision-aware; `glide`: up to 8s, fall speed capped at 1.5 units/s, recast toggles off; `wind_current`: persistent updraft toggled on/off, lifts at 8 units/s; `push`: impulse of 9 units/s |
| Water | `freeze_water`: persistent solid path, recast thaws; `redirect_current`: persistent stream reversal with 3 units/s force; `underwater_access`: 15s diving access, Space swims up; `freeze`: stop enemy for 4s with an ice shell |
| Time | `freeze_object`: stop designated moving object for 6s; `reset_object`: reset designated object to authored initial state when clear; `slow`: enemy moves at 25% speed for 6s |

`power_catalog.gd` supplies proposed durations and strengths; reference movement
constants are in the demo player/world adapters. Receivers remain responsible for
their authoritative tuning. The small per-element successful-cast cooldown is
exported as `cooldown_seconds` (0.6s). Input exports `hold_seconds` (0.3s) and `reach`
(9 units). Repeated holds never also trigger a tap. Esc, switching, dismissal,
focus loss and wheel opening cancel charged placement.

The reference island has authored Earth patches and a flat-ground placement
plane. `require_ground_support` is enabled on its Earth objects to prevent
placement over water/voids; collision queries reject overlaps. It is off by default
for callers that supply their own support validation. Arbitrary terrain sculpting
and a general navigation mesh rebake are not part of this module. The buried
discovery demonstrates persistent reveal state; the actual entrance/level content
belongs to the island scene.

## Persistence and limits

Echo snapshot version 2 stores order mode, generation, stones, active ancestor,
personal focus, cooldowns and remembered hints. Legacy version 1 Echo snapshots
load as story-ordered mode. Validate first with `valid_snapshot`, then apply with
`restore`; malformed input leaves state untouched.

The demo stores each world's target snapshot separately by stable ID, validates
the complete bundle, then restores it. The v2 playground uses
`user://echo_sandbox_v2.json`, leaving the earlier prototype slot alone. World
changes persist across Echo changes and reloads. Time-object freeze saves its
remaining duration. Player position, active swimming/gliding/dash effects and
enemy state belong to their respective systems and are not saved by Echo; the
demo respawns the player and clears movement effects on load.

Pending effects are not serialized. Save when receivers have finished their work;
the playground uses synchronous receivers. A timeout does not undo an effect:
asynchronous production receivers must cancel late work themselves. Compatibility
with the team's game still requires testing with their receivers. Coordinate
shared event schema changes with the other owners.

## Tests

```text
godot --headless --path . --script res://systems/echo/tests/run_tests.gd
godot --headless --path . --script res://systems/echo/tests/run_powers_tests.gd
godot --headless --path . res://systems/echo/demo/echo_sandbox.tscn --quit-after 120
```

The suites exercise inheritance, optional story progression, arbitrary unlock
order, wheel selection/cancellation/locking and keyboard hold/release, personal
Time alongside an ancestor, tap/hold/cancel, all power receivers, actual movement,
blocked placement, status expiry, range rejection, hints and real disk save/load.

Optional rendered previews (run without `--headless`):

```text
godot --path . --rendering-method gl_compatibility --script res://systems/echo/tests/capture_preview.gd
godot --path . --rendering-method gl_compatibility --script res://systems/echo/tests/capture_preview.gd -- --wheel
```

These save PNGs to the project's user-data folder and exit.
