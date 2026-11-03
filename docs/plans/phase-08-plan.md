# Phase 08 — Visual and Audio Identity

**Status:** Implementation slices 08.2–08.7 are merged. PR #50/#52/#53/#54/#55 delivered biome dressing, faction identity, building identity, combat visual feedback and regional audio; workflows #471/#473/#475/#476/#477 passed 30/30, 72/72, 74/74, 76/76 and 78/78 jobs respectively. Phase 08 remains open for rendered screenshot review and manual audio listening/level-balance QA.
**Art direction:** [World & Gameplay Design Bible](../WORLD_AND_GAMEPLAY_BIBLE.md) — Grim Medieval Folklore Fantasy, weathered medieval pixel art and restrained folklore motifs.
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