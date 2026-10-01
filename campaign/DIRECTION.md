# Echo Island: a journey carried across generations

The team's GDD is the visual and mechanical source of truth: whimsical, sunlit,
exploratory ruins; rounded exaggerated silhouettes; sky blue, grass green, warm
yellow and coral, with purple reserved for rare magic. Existing local sculpt,
shader and camera work is incorporated into this pass.

## The nine-chapter teaching arc

| Chapter | Purpose | Visual identity |
| --- | --- | --- |
| Arrival | Meet Kip, learn movement and close strikes | Warm shore, boat, coral wayfinding banners |
| Earth Ruins | Discover a personal gift; fracture a path | Weathered columns, root-green memory seal |
| Overgrown Path | First inheritance; summon Earth with Tab or 1 | Tall overgrowth, vine-covered arches |
| Wind Cliffs | Combine inherited Earth and personal Wind | Elevated ledges, pale sky, wind banners |
| Flooded Trail | Recombine the first two inherited gifts | Reed beds and branching waterways |
| Water Ruins | Reach and learn personal Water | Submerged foundations, turquoise memory seal |
| Forbidden Interior | Three ancestors working together | Dense canopy, cool fill, warm guiding lights |
| Time Temple | The final keeper discovers Time | Sundial seals, golden banners and broken columns |
| Island Core | Resolve the journey with all four gifts | Four elemental pillars around the Sentinel |

Generation handoffs remain after Earth, Wind and Water discovery chapters. Time
stays personal to the fourth keeper. The wheel and HUD explain the current
generation rather than assuming Time is always available.

## Implemented behavior

- Reset stale personal focus at generation handoff. Campaign discovery focuses
  the newly learned gift without changing the shared stone-collection contract.
- Tab wheel and 1–4 quick selection; Q uses the selected power, E the personal
  gift. Locked, recovering and mismatched casts give readable feedback.
- Next-action guidance, a world marker, nine-stop progress line, distinct element
  glyphs, real cooldown rings and ancestor hints through `EchoInteractionEvent`.
- Wind objectives require an acknowledged dash or glide near the channel and
  reaching the far bank above water. Casting elsewhere cannot satisfy the gate.
- Chapter-entry saves retain inheritance and earlier optional relics. Continue
  restarts the current chapter; it does not restore mid-chapter enemy or terrain
  state. Invalid saves are rejected. The previous checkpoint survives failed
  validation; writes use a temporary file before replacement.
- Organic branching trees, sculpted canopies and softer stones, painted ground,
  quieter water, softer shadow contrast, regional landmarks and camera occlusion
  handling. The existing collision and gameplay owners are retained.
- Exploration HUD shows player-relevant actions; unsupported health/ammo data is
  documented here rather than presented as debug placeholders during play.
- Original synthesized shore ambience, element-specific success chimes, discovery
  arpeggios and strike cues use four bounded voices. M toggles sound.

## Play and validate

Open `project.godot` in Godot 4.7.2 and press F5, or use `Play Echo Island.cmd` on
this Windows workspace. Saves live in Godot's user data directory under
`echo_island_journey_v1.json`. Enter/click continues; N starts a new journey when
a valid checkpoint exists. Reaching the ending clears the checkpoint.

Run the campaign, Echo, all-power, integration and Combat suites listed in
`IMPLEMENTATION.md`. Campaign tests disable player persistence and use an isolated
checkpoint file. Renderer reviews also disable persistence.

`campaign/tests/capture_journey.gd` captures all nine scenes using a real renderer
with `-- --output=ABSOLUTE_FOLDER`. These images and automated contract tests do
not constitute a full human playthrough or a measured frame-rate guarantee.

## Remaining production work

Validation on September 30: campaign **186 checks, zero failures**, both from
source and the exported pack; Echo **51**, all-power **56**, integration **41**,
all passing. Combat reports success with its pre-existing shutdown resource leak.
All nine chapters were captured with the Compatibility renderer on Intel Graphics.
The campaign and renderer review scripts exit without script errors or leaks.

The local `Echo_Island_Visual_Overhaul` folder contains the exported
`EchoIsland.pck`, its Windows `Play Pack.cmd` launcher (uses the installed Godot),
test logs, and `review.html` with the nine-chapter gallery and comparison slider.
The pack is a Godot resource package, not a standalone executable or web deployment.

The game still uses procedural character/creature art and compact challenge
layouts. This pass does not supply rigged production characters, recorded audio,
new combat health/death logic, a multi-phase boss, or nine hand-sculpted open
levels. Those are distinct follow-up production tasks. Combat and traversal
retain their team-owned contracts. This local revision has not been published.

`IMPLEMENTATION.md` records the earlier September 28 build; this document
supersedes its old HUD, persistence and camera limitations for the current pass.
