# Echo_Island_Game

## Combat upgrade branch

The working branch includes timed LMB combos, RMB heavy attacks, Shift dodge,
real player damage/vitals, elemental combinations, an Echo combat meter, enemy
attack phases and a three-phase Sentinel. See
[the combat upgrade guide](systems/combat/UPGRADE.md) for controls, tuning,
architecture, validation and remaining production-animation requirements.
This supersedes the older combat limitations in the first-pass campaign report.

## Story campaign (main)

[Play Echo Island in your browser](https://notziking8.github.io/Echo_Island_Game/).
On `main`, open `project.godot` in Godot 4.7.2 and press **F5** for the new title
screen and nine-scene campaign. Press any key/click to start. Powers are discovered
in story order; they are not all unlocked at the beginning.

WASD/arrows move, mouse looks, Space jumps, left click strikes a targeted enemy
within 3m. Hold Tab for the Echo wheel; Q uses the selected power; E uses your
generation's personal power. F collects nearby awakened stones and continues
through completed exit arches. X dismisses, R respawns, Esc releases the mouse.
Five optional relics are spread across Arrival, Overgrown Path, Flooded Trail,
Forbidden Interior, and Island Core.

This is a **procedural-art playable first pass**, not the finished reference art.
The inherited Combat/Echo/Traversal logic is preserved. Player health/damage,
dodge, ranged firing, and multi-element boss phases still need their owners'
implementations. Cosmetic bows/tridents do not change the existing melee attack.
See [campaign/IMPLEMENTATION.md](campaign/IMPLEMENTATION.md) for the scope audit,
scene walkthrough, test evidence, asset approach, and remaining work.

The original all-powers integration playground is still available by opening
`integration/team_game.tscn` and pressing **F6**.

## Combined playtest build

Use the **integration/echo-team** branch for the combined Echo, Traversal and
Combat project. This is a development playtest, not a finished release.

1. Select `integration/echo-team` in GitHub's branch selector, then choose
   **Code > Download ZIP** and extract it. Or clone that branch:

   ```text
   git clone --branch integration/echo-team https://github.com/notziking8/Echo_Island_Game.git Echo_Island_Playtest
   ```

2. Open/import the extracted `project.godot` in **Godot 4.7.2**.
3. Press **F5**. The main scene is `integration/team_game.tscn`.

All powers start unlocked. Arrow keys or WASD move, mouse looks, and Space jumps.
Hold **Tab**, choose with the mouse or arrows, and release to select a power.
**Q** uses the selected power; **E** uses personal Time. **F** interacts,
**X** dismisses an ancestor, and **R** respawns at the checkpoint. **Esc** frees
or captures the mouse. Left-click within three units strikes an enemy.

Try Earth on Shellguards, Wind on Skitters, Water on Scouts and Time on Slingers.
The starting area also has rocks, platforms, a wind vent, a reversible stream,
a raised swimming basin, and a moving Time relic for testing environmental powers.

Known limits: some visuals and stations are temporary; enemy attacks do not yet
damage the player; shared game saving and story progression are not connected.
Downloading this branch gives you the Godot project, not an exported executable.

When reporting problems, include the power/target, steps to reproduce, expected
versus actual behavior, and a screenshot or Godot error message if available.

See [integration/README.md](integration/README.md) for architecture, source branch
versions, test commands, and remaining team integration work.
