# Phase 08 — Visual and Audio Identity

**Status:** Phase 08.2–08.7 production slices remain integrated. The original biome, faction, building, combat-feedback and audio work is not being discarded. Phase 08 remains open for rendered screenshot review and manual audio listening/level-balance QA. A new additive overhaul is in progress on `art/phase-08.8-art-direction-lock`; it has established the authoritative art bible/reference board and added a regression guard for the hand-authored player atlas. No complete character/building/biome replacement is claimed yet.
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

## 08.8 — Complete visual asset overhaul (active)

Branch: `art/phase-08.8-art-direction-lock`

The overhaul is additive to the shipped Phase 08 work. It replaces generic construction at its source while preserving resource IDs, gameplay behavior, collision footprints, animation IDs, Y-sort origins and save data.

- [x] Establish `docs/ART_DIRECTION.md` with material palettes, biome/faction grammar, role silhouettes, architecture, lighting, pixel-grid rules, rendering dimensions and visual acceptance gates.
- [x] Establish `docs/ART_REFERENCE_BOARD.md` with historical construction, clothing/armor, pixel-art production and top-down atmosphere references.
- [x] Identify the legacy generator's unsafe player overwrite: it previously emitted a 20×20 generic player sheet despite the integrated protagonist using 24×28 frames.
- [x] Exclude the hand-authored player from the legacy renderer and add an explicit generator write guard.
- [x] Extend `role_sprite_identity` to check player frame size, distinction from the generic soldier sheet and generator ownership. Exact-head Godot 4.7 CI passed 64/64 checks on PR #179 (run #42320928929); the deterministic Frontier Rendered World QA also passed (run #42320928830).
- [ ] Inventory every current SVG, generator owner, resource reference, atlas size, collision/footprint dependency and actual screen usage.
- [ ] Redesign the complete player/villager/enemy family with separate authored silhouettes and full directional animation. Do not treat color, hat or held tool overlays as complete role identity.
- [ ] Redesign faction/archetype combinations, all shipped building silhouettes and construction/damage states.
- [ ] Redesign biome terrain, vegetation, resources, wildlife, props, combat effects and HUD/map icon families.
- [ ] Add reproducible source/generator ownership for new assets without allowing a legacy bulk generator to overwrite hand-authored work.
- [ ] Produce Godot 4.7 rendered sheets and in-game captures at 1280×720, 1600×900 and 1920×1080. Review native logical scale and 2× output.
- [ ] Run the complete blocking regression matrix and record target-desktop performance separately from CI. Human desktop visual acceptance remains a separate gate.

**Current limitation:** only the art bible, reference board, generator safety guard and test assertions are committed on this branch. Existing shipped art remains in use until replacement packages are implemented and validated.

## 08.9 — Player motion and event-timed animation foundation (active)

Branch: `animation/player-motion-timing` — [PR #181](https://github.com/shimleabyte/hold-the-keep/pull/181)

- [x] Split the protagonist's 24×28 atlas/clip contract from shared role sheets.
- [x] Synchronize the light-attack impact frame to existing combo hit delays and the Cleave hit event.
- [x] Add player animation interruption priority and timing/pose/foot-contact regression coverage.
- [x] Keep gameplay damage, hit sectors, cooldowns and harvest yield unchanged.
- [ ] Complete the Godot-rendered Player playblast and inspect attack/locomotion at native gameplay zoom.
- [ ] Replace placeholder harvest poses with dedicated tool artwork.
- [ ] Author genuinely distinct Cleave, Dash and Rally sequences plus multi-frame hurt/death.
- [ ] Complete player locomotion and secondary cloth/weapon overlap before extending the character production method to villagers and enemies.

**Boundary:** three authored facing rows remain three facings, not eight-direction art. This foundation is not a complete Player animation set and does not complete Phase 08.8.

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