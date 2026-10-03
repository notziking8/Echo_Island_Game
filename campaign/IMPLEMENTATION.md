# Echo Island: PDF implementation report

Source: the user's 26-page **Untitled document (3).pdf**, supplied September 28,
2026. Its visual/story instructions are task requirements, not authority to change
the protected gameplay owners. This build implements a procedural first pass;
it does **not** claim to reproduce the illustrated reference assets exactly.

## Ownership audit and boundaries

| Existing owner | Preserved responsibility | New seam |
| --- | --- | --- |
| `scripts/player/player.gd`, `integration/player_adapter.gd` | Movement, jump, swimming, glide, dash, camera input, checkpoint respawn | Instantiate existing player; replace visible meshes; configure spring arm |
| `systems/echo/echo_system.gd` | Stones, generation/inheritance, selection, cooldown, request/response | Persistent instance with `enforce_story_order`; public `collect_stone`, `begin_generation` |
| `systems/echo/echo_input.gd`, `integration/input_adapter.gd`, `echo_wheel.gd` | Aim, contextual Q/E actions, wheel, cancellation | Q selects a summoned ancestor; E always calls the personal power; aimed puzzle/environment targets outrank nearby enemies |
| `systems/combat/combat_enemy.gd`, `combat_system.gd`, `integration/combat_bridge.gd` | Health, guard, enemy AI, effect validation/status | Normal left-click attack remains; Echo casts add element-specific damage/status; armored guard requires Earth stun |
| `earth_target.gd`, `integration/earth_adapter.gd`, `demo/environment_target.gd` | Rock/platform placement, wind/water/time world behavior | Campaign walls and raised platforms use the same Earth receiver; ice, updrafts, and gates change collision through existing acknowledged events |
| `scripts/test/collectible_relic.gd` | Pickup and animation | Connect collection signal to five-scene counter |

The implementation keeps existing Echo request/response and Combat/Traversal
ownership seams. It updates their input dispatch, Echo combat result, target
geometry, and campaign composition to enforce the intended power gates.

## Added files and phases

- `presentation/island_art.gd`, `foliage.gdshader`: palette, smooth rounded meshes,
  grass/flower MultiMeshes, foliage sway, soft daylight, clouds and landmarks.
- `campaign/main.gd`, `main.tscn`, `catalog.gd`, `scenes/*.tscn`: live 3D title,
  key/click start, fades, separate scene loading, entry respawn positions, gated
  exits, generation memory cards, ending and restart.
- `presentation/lilo.gd`: articulated procedural Lilo with hair, goggles, blue
  shirt, vest, backpack/bedroll, green pocketed pants and boots. Velocity-driven
  limb cycles, idle breath, airborne pose, landing compression, attack/interact
  gestures, hand socket and four cosmetic weapon silhouettes.
- `presentation/echo_spirit.gd`: discovered stone and the selected ancestor;
  Earth/Wind/Water/Time variants, bobbing and summon scaling. The duplicate
  lavender follower was removed from the campaign.
- `presentation/effects.gd`: bounded 12-slot cast/impact pool. Effects only mark
  successful impacts after owner acknowledgement. No visual effect awards damage.
- `presentation/crab.gd`: moss crabs and Sentinel, status tint, scuttle,
  cosmetic attack anticipation, hit reaction and defeat. Guardian collider fits
  its larger silhouette; archetype defaults and damage rules are inherited.
- `presentation/earth.gd`, `environment_target.gd`: rounded visible targets,
  hidden debug captions, original receiver/collision contracts.
- `campaign/stage.gd`: landscape/encounter assembly and thin interaction/event
  glue. Falls call the existing respawn/damage APIs. Successful task acknowledgements
  gate the next scene; a rock is not counted cleared until its second crack.
- `campaign/hud.gd`: parchment HUD, segmented cooldown/unlock ring, target health
  and state, four locked/selected power slots, relic count, controls, objectives,
  nearby interaction prompt, truthful unsupported-data placeholders.
- `campaign/tests/*`: progression/receiver tests and reproducible renderer captures.
- `project.godot`: campaign main scene, 1280×720 scalable viewport, Compatibility
  renderer. `export_presets.cfg`: explicit nonthreaded Web build for Pages.
- GitHub Pages workflow: import + all five regression suites before exporting.

## Playthrough / completion gates

| Scene | Required sequence |
| --- | --- |
| Arrival | Defeat shore crab with close strikes; follow gold path to arch; F |
| Earth Ruins | Defeat guard; F at Earth stone; E twice on rock; exit |
| Overgrown Path | Tab summon Earth; Q twice on rock; Earth-stun Shellguard; defeat it |
| Wind Cliffs | Q raises the Earth bridge to reach Wind; E dashes across the second unjumpable gap; defeat guard |
| Flooded Trail | Q breaks the Earth wall; Wind dash crosses the physical channel; defeat guard |
| Water Ruins | Break the Earth wall; Wind dash reaches the Water stone; E freezes the full-width pool bridge; defeat guard |
| Forbidden Interior | Break the Earth wall; activate the updraft to reach the high ledge; freeze the Water crossing; defeat guard |
| Time Temple | Earth, Wind and Water open the route; collect Time, then E opens the collision-blocking Time gate; defeat guard |
| Island Core | Raise Earth bridge; activate Wind updraft; freeze Water crossing; open Time gate; Earth-stun the Sentinel before normal attacks; F at final arch |

Generation changes occur only after Earth Ruins, Wind Cliffs, and Water Ruins.
The Time power remains personal to generation four, as required by the existing
Echo owner's inheritance rules; the three earlier powers are ancestral Echoes.
Five optional relics persist between scenes during this run. Defeated enemies
stay defeated during the scene, including after R; refresh/restart starts a new run.

## Verification

- Godot 4.7.2 desktop: campaign suite **183 checks, zero failures**; Echo **51**,
  all-power **57**, integration **43**, and Combat suite passed.
- Tests load all nine scenes, enforce stone prerequisites, use F collection,
  send actual requests through the existing receivers, verify success before
  progression, confirm generations/ancestral powers and final ending. These are
  automated contract tests, **not** a claimed uninterrupted human playthrough.
  Geometry and collision checks verify each power gate changes state through its
  existing receiver. Armored guards reject normal damage until their Echo stun;
  regular attacks remain available and finish them after the guard breaks.
- Real OpenGL captures of title, Arrival, Earth Ruins, and Core inspected.
  Fixed terrain skirt overlap, washed-out lighting, low-contrast notifications,
  objective panel overflow, and ungrounded decorative placement found in review.
- Original integration tests still exercise swim/glide/dash, wheel movement lock,
  range rejection, late combat registration, checkpoints and existing interactions.
- Linux CI reports a retained resource on shutdown in the unchanged Combat test
  suite, after its success marker. CI allows that exact one-resource shutdown
  message only for that suite and still rejects all other errors and failed tests.
- Reproduce: `godot --headless --path . --script res://campaign/tests/run_tests.gd`.
  Capture: `godot --path . --script res://campaign/tests/capture.gd -- --output=ABSOLUTE_FOLDER`.

## Explicit TODOs / limits (do not hide behind cosmetic replacements)

1. **Authored asset fidelity:** no imported rigged GLBs or animation clips existed.
   These original procedural assets are a fallback, not the requested production
   character/terrain quality. Replace them with authored skinned Lilo/Kip/creature
   meshes, blend-tree clips, textured rocks/foliage and more organic terrain.
   Current levels reuse a landscape vocabulary and are compact challenge scenes,
   not nine fully hand-sculpted biomes. Primitive collision approximates rounded art.
2. **Combat-owner hooks:** player health/damage/hurt/death, dodge/roll, combo,
   ranged projectiles/ammo, actual boss hazards and multi-Echo vulnerability phases
   are absent from the owner. HUD health/ammo/level show unavailable; no fake
   hearts, damage, invulnerability, or ranged attacks have been invented. Current
   Sentinel uses the existing Earth guard/stun profile, not a new boss controller.
3. **Animation/VFX polish:** no skeletal AnimationTree, authored anticipation clips,
   cinematic death/respawn, sound assets, true ribbon trails, dense ice shards,
   transparency fades, or camera shake. Cast/impact pool is intentionally modest.
   Kip follows/bobs; dismiss hides the ancestor immediately through the existing seam.
4. **Level-design fidelity:** gates enforce the requested ability sequence; some
   challenge stations remain tutorial-style. Updraft activation is a completion
   requirement but not every route is physically impassable without it. Further
   authored traversal puzzles should keep the owner contracts unchanged.
5. **Camera:** retains collision-safe SpringArm and existing mouse camera; no new
   camera damping controller or optional target lock has been added.
6. **HUD:** labeled power slots are functional but not final illustrated icons.
   Existing Echo wheel rendering is retained. Keyboard/mouse desktop play is the
   supported input; touch/gamepad/accessibility layout still needs a separate pass.
7. **Performance:** instanced flowers/grass and bounded effect pool avoid runaway
   effects, but per-device 60 FPS is a target, not a measured guarantee. More shared
   mesh/material caching, LODs and profiling remain before a production art pass.
8. **Persistence:** no disk save system was introduced. Scene progression is held
   in memory; browser refresh begins at title. No external art/audio was downloaded
   or licensed. All newly generated meshes/shader code are original project assets.

These remaining items either require authored production assets or new owner
interfaces beyond the document's strict prohibition on gameplay-internal changes.
