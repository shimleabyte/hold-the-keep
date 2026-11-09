# Hold the Keep — Player Animation Direction and Runtime Contract

**Status:** Player-first engineering foundation in PR #181. This document is authoritative for the current protagonist animation package. It does not declare the full character or asset overhaul complete.

## Production target

The player is a directly controlled blue-mantled medieval knight. Motion must read as deliberate, weighted 2D character animation at native gameplay zoom—not a sprite bouncing as a rigid rectangle. Primary motion comes from authored changes in silhouette, torso/arm/weapon pose, leg contact and follow-through. Secondary motion comes from cape overlap, weapon lag, recoil and controlled recovery.

Keep the existing crisp pixel-art rendering discipline. Every pose remains aligned to the 24×28 source grid. Do not blur, interpolate pixel art, or use broad whole-body offsets as a substitute for pose changes.

## Current atlas contract

| Property | Contract |
|---|---|
| Player frame size | 24×28 logical pixels |
| Player atlas | 46 frames × 3 facing rows |
| Source SVG size | 1104×84 |
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
| 16–19 | Work/harvest | Four-pose hand-authored pick/axe tool cycle; contact frame 18 follows the existing 0.14s event |
| 20–23 | Death | Four-pose collapse, drop, fall and settled-prone preview; gameplay still respawns immediately |
| 24–29 | Heavy Cleave | Dedicated six-pose brace, wind-up, downswing, impact, follow-through and recovery; impact frame 26 follows the existing 0.22s hit event |
| 30–35 | Dash | Dedicated six-pose acceleration, drive, extension, braking and recovery cycle within the existing 0.22s dash window |
| 36–41 | Rally | Dedicated six-pose raised-arm command sequence; 0.50s visual cycle, separate from the 8s gameplay buff |
| 42–45 | Hurt | Four-pose recoil, guard, stagger and recovery within the existing 0.20s hurt window |

## Gameplay event ownership

Gameplay remains authoritative for damage, hit sectors, cooldowns, combo state, harvest yield and ability resolution. Animation is presentation-only.

- Light attack frame 12 is timed from the existing combo hit delay: 0.11s / 0.13s / 0.19s.
- Cleave resolves at its existing 0.22s event within its 0.46s ability window. It uses frames 24–29, with heavy impact frame 26; damage, range, stagger and cooldown remain gameplay-owned.
- Player harvest retains its existing 0.14s contact event. Its artwork must become a distinct tool-contact cycle; do not alter yield or resource timing to fit art.
- Hurt must pre-empt attack/work presentation. Its four-frame reaction is presentation-only and must not cancel or duplicate pending gameplay events.
- Dash and Rally now use dedicated authored player clip ranges; their movement/invulnerability and buff mechanics remain unchanged.

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

## Protagonist locomotion pass

- Walk and run use four distinct authored leg poses in each of the front, back and side rows. The cycle alternates planted contact and passing/extension poses instead of repeating a two-pose shuffle.
- Player locomotion keeps the pelvis planted on walk and limits run lift to one pixel. Shared villager/enemy locomotion retains its existing secondary-motion profile.
- The player playblast captures every locomotion pose at native gameplay framing for all three authored facing rows before reviewing the action clips.

## Review/QA gates

- GDScript import/parse and the full Godot 4.7 regression matrix pass on the exact PR head.
- Player sprite identity and pose tests validate atlas dimensions, distinct key poses, pixel bounds and planted contact.
- A rendered Godot playblast includes idle, walk, run, light attack anticipation/impact/follow-through/recovery, harvest, Cleave, Dash, Rally, hurt and death.
- Review contact sheet and looping clips at native gameplay zoom. Verify weapon visibility, boot contact, cape overlap, silhouette clarity and no frame clipping.
- Inspect front, back and side rows independently; no diagonal coverage claim without actual diagonal artwork.
- Only after player acceptance should the same production method expand to villager, enemy and specialist character families.

## Current known blockers

- The player playblast previously failed because the harness eagerly preloaded `player.gd` before the `Events` autoload was available. The harness now loads Player after autoload initialization and captures exact action-time markers.
- The tool, heavy Cleave, Dash, Rally, Hurt and Death now have separate art/clip ranges. Exact-head visual acceptance of the expanded action set remains pending.
- Death remains preview-only because gameplay immediately respawns; do not change that gameplay rule as part of this presentation task.
- Player locomotion still needs more complete leg cycles and torso/cape overlap.
- Villager, enemy, faction-specific and specialist animation production remains open.

