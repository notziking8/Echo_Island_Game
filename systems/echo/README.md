# Echo System — Hali

A standalone Godot Echo module with a hold-to-select wheel, four playable power
families, persistent environment changes, contextual ancestor hints, and reference
receivers for integration with Combat and Traversal.

Open `demo/echo_sandbox.tscn` in Godot 4.7.2 and press **F6**. Every power starts
unlocked; no generation sequence or stone collection is required to test it.

| Control | Action |
| --- | --- |
| Arrow keys | Move; choose a wheel direction while Tab is held |
| Space | Jump / swim upward |
| Hold Tab | Open wheel; hover or use arrows, then release to select |
| Q | Selected contextual power: tap or hold as shown in the prompt |
| E | Your personal power, alongside the summoned ancestor |
| X | Dismiss ancestor |
| Esc | Cancel wheel or charged action |

Earth, Wind, and Water are ancestors. Time remains the descendant's own power.
Choosing Time in the wheel focuses Q on Time while leaving the ancestor beside
the player; E also uses Time. Choose an ancestor again to focus Q on their power.

| Power | Playable actions |
| --- | --- |
| Earth | Move, crack, and break rocks; raise/lower platforms and barriers; uncover a buried discovery; stun the guardian |
| Wind | Dash; glide; create/remove an updraft; push the guardian |
| Water | Freeze/thaw a traversable ice path; reverse a stream; dive and swim below the surface; freeze the guardian |
| Time | Stop the moving relic temporarily; reset it to its starting state; slow the guardian |

World changes stay until deliberately changed again. Enemy statuses, Time freezes,
gliding, and underwater access have finite durations. Save/Load preserves inheritance,
wheel focus, remembered hints, terrain, water, currents, and the moving relic's state.

The player, guardian, and environment adapters in `demo/` make Echo testable on its
own. They are reference receivers for the team's systems, not replacements for
Megan's Traversal or Zion/Kai's Combat. Geometry and ancestor appearances are
procedural placeholders. See [INTEGRATION.md](INTEGRATION.md) for APIs and tuning.

## Git workflow

Repository: https://github.com/notziking8/Echo_Island_Game

Local branch `Echo_System` tracks `origin/Echo_System`. Keep Echo changes under
`systems/echo/`. Review before committing:

```text
git status --short --branch
git add -- systems/echo .githooks/pre-push
git diff --cached
git commit -m "Build standalone Echo powers and selection wheel"
git push
```

The local `.githooks/pre-push` guard checks the remote, destination branch,
fast-forward history, and outgoing file paths. It permits `systems/echo/` and the
guard itself. It is enabled in this checkout with `core.hooksPath=.githooks`.
Other Hali checkouts must enable it explicitly; other owners should use their own
workflow. This is a bypassable local check, not GitHub branch protection.

Godot can modify shared `project.godot`, including the selected main scene.
Review and coordinate such changes separately; do not stage them with Echo-only
commits. The guard intentionally rejects shared project changes. Test compatibility
with the other systems before merging into main.
