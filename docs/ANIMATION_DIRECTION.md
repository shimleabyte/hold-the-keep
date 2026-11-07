# Hold the Keep — Player Animation Direction and Runtime Contract

**Status:** Player-first engineering foundation in PR #181. This document is authoritative for the current protagonist animation package. It does not declare the full character or asset overhaul complete.

## Production target

The player is a directly controlled blue-mantled medieval knight. Motion must read as deliberate, weighted 2D character animation at native gameplay zoom—not a sprite bouncing as a rigid rectangle. Primary motion comes from authored changes in silhouette, torso/arm/weapon pose, leg contact and follow-through. Secondary motion comes from cape overlap, weapon lag, recoil and controlled recovery.

Keep the existing crisp pixel-art rendering discipline. Every pose remains aligned to the 24×28 source grid. Do not blur, interpolate pixel art, or use broad whole-body offsets as a substitute for pose changes.

## Current atlas contract

| Property | Contract |
|---|---|
| Player frame size | 24×28 logical pixels |
| Player atlas | 24 frames × 3 facing rows |
| Source SVG size | 576×84 |
| Facing rows | Front/down, back/up, side/right; side is mirrored for left |
| Ground pivot | Bottom-center of the 24×28 cell |
| Shared role sheets | Preserve their independent 22-frame contract |
| Texture owner | Hand-authored `assets/sprites/player.svg`; do not route through the generic role-sheet generator |

Three rows do not mean eight-direction animation. Diagonal input currently selects/quantizes into front, back or side facing. Do not claim diagonal poses exist until they are authored and tested.

## Current clip map and honest status

| Frames | Current use | Status / outstanding defect |
|---|---|---|
| 0–1 | Idle | Existing two-pose idle; breathing and cape overlap need authored refinement |
| 2–5 | Walk | Existing two-step-pose alternation repeated; upper body/cape mostly static |
| 6–9 | Run | Existing two-pose alternation repeated; not yet a complete stride cycle |
| 10–15 | Light sword attack | Six-pose timed sequence; impact frame 12 follows live gameplay hit delay |
| 16–19 | Work/harvest | Separate clip range, but currently uses sword-layer poses; dedicated tool silhouette is not yet authored |
| 20 | Hurt | One frame only; insufficient for a complete recoil/recovery animation |
| 21–23 | Death | Three frames exist, but gameplay immediately respawns and does not play this sequence to completion |

## Gameplay event ownership

Gameplay remains authoritative for damage, hit sectors, cooldowns, combo state, harvest yield and ability resolution. Animation is presentation-only.

- Light attack frame 12 is timed from the existing combo hit delay: 0.11s / 0.13s / 0.19s.
- Cleave resolves at its existing 0.22s event within its 0.46s ability window. It currently shares the light-attack pose sequence; a separate heavy action is required.
- Player harvest retains its existing 0.14s contact event. Its artwork must become a distinct tool-contact cycle; do not alter yield or resource timing to fit art.
- Hurt must pre-empt attack/work presentation. It must not cancel or duplicate pending gameplay events unless the gameplay contract explicitly calls for cancellation.
- Dash currently reuses Run. Rally currently reuses Idle. These are known presentation gaps, not accepted final states.

## Animation production rules

1. **Pose readability first.** Test the silhouette at native gameplay zoom before adding detail.
2. **Anticipation.** Show where force is coming from before acceleration.
3. **Weight transfer.** Distinguish planted and stepping feet. A heavy attack needs a readable base, not a whole-body bounce.
4. **Contact timing.** Keep the designated impact pose visible at the existing gameplay event marker.
5. **Follow-through.** Weapon, arm, torso and cape do not stop simultaneously.
6. **Recovery.** Return to guard through a deliberate recovery pose, not an instant idle snap.
7. **Action-specific motion.** A quick cut, heavy Cleave, Dash, Rally, harvest strike and hurt reaction need different silhouettes and timing.
8. **Layered overlap.** Cape and weapon should lag the torso slightly while preserving crisp pixel alignment.
9. **Interruption.** Hurt/death and ability transitions must explicitly take animation priority according to gameplay state.
10. **No false completion.** Distinct frame indices or tiny pixel translations alone do not prove a convincing animation.

## Review/QA gates

- GDScript import/parse and the full Godot 4.7 regression matrix pass on the exact PR head.
- Player sprite identity and pose tests validate atlas dimensions, distinct key poses, pixel bounds and planted contact.
- A rendered Godot playblast includes idle, walk, run, light attack anticipation/impact/follow-through/recovery, harvest, Cleave, Dash, Rally, hurt and death.
- Review contact sheet and looping clips at native gameplay zoom. Verify weapon visibility, boot contact, cape overlap, silhouette clarity and no frame clipping.
- Inspect front, back and side rows independently; no diagonal coverage claim without actual diagonal artwork.
- Only after player acceptance should the same production method expand to villager, enemy and specialist character families.

## Current known blockers

- The player playblast previously failed because the harness eagerly preloaded `player.gd` before the `Events` autoload was available. The branch now loads the GDScript after the first process frame; exact-head rendered validation remains pending.
- Harvest artwork is not yet a genuine tool animation.
- Cleave/Dash/Rally do not yet have unique pose sequences.
- Hurt/death are under-animated and death is not currently played through the gameplay respawn path.
- Player locomotion still needs more complete leg cycles and torso/cape overlap.
- Villager, enemy, faction-specific and specialist animation production remains open.

