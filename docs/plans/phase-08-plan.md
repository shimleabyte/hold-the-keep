# Phase 08 — Visual and Audio Identity

**Status:** Phase 08.2–08.7 production slices remain integrated. Stage A art-direction foundation merged through PR #179 at `27740a72`. Stage B civilian character atlases are implemented on `art/phase-08.9-villager-character-family` and under review in PR #182. The remaining enemy/faction, building, environment, VFX and icon packages are still open. Preserve the existing biome/faction/building gameplay integration rather than discarding it.
**Art direction:** [ART_DIRECTION.md](../ART_DIRECTION.md) is the authoritative production specification. [World & Gameplay Design Bible](../WORLD_AND_GAMEPLAY_BIBLE.md) remains the world/lore source of truth; [ART_REFERENCE_BOARD.md](../ART_REFERENCE_BOARD.md) records historical and game-art references.
**Dependency:** Stable gameplay contracts from Phases 02, 04, 05, 06 and current UI layouts from Phase 10.
**Engine target:** Godot 4.7 only.

## Goal

Give the Frontier campaign a coherent Grim Medieval Folklore Fantasy visual language: weathered medieval material surfaces, grounded biome identity and restrained regional folklore. Preserve readable silhouettes, pixel-art scaling, runtime performance and Classic readability.

## 08.1 — Art direction and asset pipeline
- [x] Define and apply an earthy, weathered terrain palette for Hearthland, Greenwood, Highlands, Fenlands and Ashen March through a dedicated Frontier atlas; Classic retains its original atlas and no global dark filter is used.
- [x] Extend the Frontier material/crest contract to four faction visual kits and the shipped building set; Phase 08.5 adds structure-specific detail and damage marks.
- Add restrained regional folklore motifs through landmarks, boundary marks, burial customs and environmental storytelling. Keep overt supernatural visual effects rare and reserved for confirmed threats.
- Define sprite scale, pivot, outline, contrast and animation-frame conventions before producing bulk assets.
- Keep generated/procedural SVG assets reproducible; hand-authored replacements must preserve import paths or update references atomically.
- Establish preview sheets and in-engine screenshot baselines so visual changes are reviewed rather than inferred from source files.

## 08.8 — Art-direction foundation (merged)

**Merged:** PR #179 at [`27740a72e187`](https://github.com/shimleabyte/hold-the-keep/commit/27740a72e187487ea8fc58a1a08680836cc8e22e).

- [x] Establish `docs/ART_DIRECTION.md` as the authoritative grim medieval folklore art bible, including material palettes, biome/faction language, silhouettes, animation, architecture, lighting, pixel grid and visual gates.
- [x] Establish `docs/ART_REFERENCE_BOARD.md` with historical medieval construction, clothing/armor, tools and relevant pixel-art production references.
- [x] Protect the hand-authored 24×28 blue-mantled player atlas from the legacy 20×20 humanoid generator.
- [x] Add a player frame-size and generator-ownership regression.
- [x] Exact PR #179 head passed Godot 4.7 64/64 checks and deterministic Frontier Rendered World QA.

## 08.9 — Civilian character family (PR #182 active)

**Branch:** `art/phase-08.9-villager-character-family`  
**PR:** [#182](https://github.com/shimleabyte/hold-the-keep/pull/182)  
**Current validated code head:** `8dc9b8e2a25f`

- [x] Replace all ten civilian atlases: labourer, woodcutter, miner, farmer, builder, hunter, scout, healer, blacksmith and soldier.
- [x] Preserve 440×60 atlas dimensions, 20×20 frames, 22 animation frames, three directional rows and existing texture paths/foot pivots.
- [x] Give each profession distinct body silhouette, clothing mass, headwear, equipment placement and signature tool/gear; include idle, walk, run, attack, work, hurt and death frames.
- [x] Remove civilian atlas output from the legacy generic humanoid renderer and protect all ten hand-authored SVG sources.
- [x] Add XML/integer-grid/SVG ownership validation and byte-reproducibility checks for the remaining generator-owned enemy Archer/Brute sheets.
- [x] Add a Godot-native 10-role atlas contact sheet and real gameplay capture at 1280×720, 1600×900 and 1920×1080.
- [x] Exact-head Godot 4.7 CI passed 63/63 jobs (run #42323335962); Role Sprite Visual QA passed (run #42323335969); deterministic Frontier Rendered World QA passed (run #42323335991).
- [ ] Merge PR #182 after final exact-head checks remain green.
- [ ] Manually review all civilian animation clips at native desktop scale and confirm profession recognition during actual work/combat.
- [ ] Continue with faction-specific military units and enemy archetypes; then buildings/construction/damage, biomes/resources/wildlife/props, combat effects, HUD/map icons and final visual-performance review.

**Remaining Phase 08 scope:** enemy/faction identity, all building silhouettes and states, terrain/biome assets, resource nodes and wildlife, environmental props, VFX, UI icon families, whole-world rendered review and target-desktop performance. The overhaul is not complete while those groups remain generic or unreviewed.

## 08.10 — Player combat and tool animation (PR #181 active)

**Branch:** `animation/player-motion-timing`  
**PR:** [#181](https://github.com/shimleabyte/hold-the-keep/pull/181)

- [x] Separate the protagonist's 30-frame 24×28 atlas from shared 22-frame civilian/enemy sheets.
- [x] Add a dedicated four-pose pick/axe work cycle and six-pose heavy Cleave sequence.
- [x] Key light attack and Cleave contact poses to existing gameplay hit delays.
- [x] Preserve civilian atlases from PR #182; their 440×60 / 20×20 / 22×3 contract remains unchanged.
- [ ] Pass exact-head Godot 4.7 tests with both protagonist and civilian visual regressions.
- [ ] Capture and inspect the player animation contact sheet/GIF at native gameplay zoom.
- [x] Add dedicated six-pose Dash/Rally clips and four-pose Hurt/Death-preview ranges while preserving existing gameplay timers and immediate-respawn behavior.
- [ ] Inspect the new action poses in the exact-head contact sheet and refine locomotion/cape/weapon overlap.

**Boundary:** three player facing rows remain three facings. This is not an eight-direction or complete character animation pass.

## 08.2 — Terrain and regional identity
- [x] Give Frontier biomes distinct ground textures in a dedicated seven-cell atlas (five land biomes, alternate Hearthland ground and water), preserving tile IDs, 16px tile size and water collision.
- Create a distinct Old Frontier/ruin subregion treatment without introducing an unsupported sixth core biome.
- Add visual cues for ownership, contested territory, supply routes, fog and regional objectives.

## 08.3 — Biome props, landmarks and resource silhouettes
- [x] Scatter deterministic, region-specific fern clusters, reeds, dead pines, standing stones and ash pillars; add one landmark in each core biome. Decorations are non-colliding and excluded from resource occupancy.
- [x] Add Greenwood pine, Fenlands willow, Ashen deadwood, Highlands stone and Ashen rock resource silhouettes; preserve Classic sprite paths and resource behavior.
- [ ] Add further resource-cluster dressing and restrained ambient animation while preserving tile readability.

## 08.4 — Unit and faction identity
- [x] Give each faction a distinct three-color visual kit and unique thorn, chevron, reed or ember crest motif; retain the existing faction tint as a secondary recognition cue.
- [x] Add specialist equipment silhouettes for Scout, Shieldbearer, Saboteur, War Shaman, Siege Engine and Beast Rider through a modular draw layer that does not modify AI, collision, attack timing or save data.
- [ ] Validate readability with rendered screenshots at actual gameplay zoom and during night/combat effects.

## 08.5 — Building identity
- [x] Add distinct material palettes and unique structural details for all 13 shipped building types in Frontier, layered over their existing dedicated sprite assets.
- [x] Add four deterministic health-scaled damage states using material-aware cracks and missing-edge marks; retain the existing HP bar and sabotage indicator.
- [ ] Add visual construction stages when Phase 05's actual staged-construction state exists; do not fake progress with timers or HP.
- [ ] Review map and HUD icons at native UI scale and ensure every shipped structure remains distinct.

## 08.6 — Combat visual feedback
- [x] Add short directional melee/ranged anticipation marks that clear when attacks resolve or are cancelled; existing archetype-specific telegraphs remain authoritative.
- [x] Add a transient directional impact burst, stagger marker and distinct Dash/Cleave/Rally shapes through one shared draw-only helper. Existing corpse/death animation and particle caps remain in place.
- [ ] Capture screenshots at native gameplay scale to verify cues remain readable without hiding sprite silhouettes or telegraphs.
- Keep player, villager and enemy sprite footprints consistent with Y-sort and collision origins.

## 08.7 — Audio
- [x] Generate ten deterministic, loop-forward ambience streams for five Frontier biomes across day/night. Crossfade regions and day/night contexts without adding external audio assets.
- [x] Add original low-level campaign and menu music loops with soft loop-edge envelopes and crossfade on pause/resume.
- [x] Connect combat cues for melee/ranged wind-up, projectile release, block, stagger, Dash, Cleave, Rally, Beast Rider charge and Siege Engine wind-up/impact; connect wave/camp alarm, regional objective, act unlock and victory events.
- [x] Route all new AudioStreamPlayers through the existing Master bus so the existing persisted volume setting and mute path remain authoritative.
- [ ] Listen-test every biome/day-night pair, menu/campaign transitions, pause/resume and combat cues on actual speakers/headphones; review level balance and loop seams.
- [x] All new loops and cues are synthesized from original in-repository signal generators at runtime; no external recordings or third-party music samples are used.

## Verification
- Capture screenshots at 1280×720, 1600×900 and 1920×1080 for day/night, fog, combat, objective panel and strategic map.
- Review silhouettes at native logical scale and 2× pixel output; no critical gameplay cue may depend on color alone.
- Profile particle/audio load on target hardware; retain particle/entity bounds.
- Run Godot 4.3/4.7 import/parse/regression and inspect actual rendered screenshots before acceptance.

## Acceptance gate
- Five biomes, four factions, six archetypes and all shipped buildings have distinct readable identity.
- Day/night, fog, objective and ownership cues remain legible under combat load.
- Audio cues map to real gameplay events and settings work.
- Screenshots and human review are recorded; generated asset existence alone is not acceptance.