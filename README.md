# Echo_Island_Game

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
