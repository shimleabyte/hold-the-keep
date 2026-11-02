# Phase 08 — Visual and Audio Identity

**Status:** In progress. The Frontier terrain atlas is merged; the next slice adds biome-specific resource prop silhouettes and regression coverage. Classic resource visuals remain unchanged. This is a foundation, not completion of biome identity.
**Art direction:** [World & Gameplay Design Bible](../WORLD_AND_GAMEPLAY_BIBLE.md) — Grim Medieval Folklore Fantasy, weathered medieval pixel art and restrained folklore motifs.
**Dependency:** Stable gameplay contracts from Phases 02, 04, 05, 06 and current UI layouts from Phase 10.
**Engine targets:** Godot 4.3 and 4.7.

## Goal

Give the Frontier campaign a coherent Grim Medieval Folklore Fantasy visual language: weathered medieval material surfaces, grounded biome identity and restrained regional folklore. Preserve readable silhouettes, pixel-art scaling, runtime performance and Classic readability.

## 08.1 — Art direction and asset pipeline
- [x] Define and apply an earthy, weathered terrain palette for Hearthland, Greenwood, Highlands, Fenlands and Ashen March through a dedicated Frontier atlas; Classic retains its original atlas and no global dark filter is used.
- [ ] Extend the palette/material contract to props, buildings, units and regional landmarks.
- Add restrained regional folklore motifs through landmarks, boundary marks, burial customs and environmental storytelling. Keep overt supernatural visual effects rare and reserved for confirmed threats.
- Define sprite scale, pivot, outline, contrast and animation-frame conventions before producing bulk assets.
- Keep generated/procedural SVG assets reproducible; hand-authored replacements must preserve import paths or update references atomically.
- Establish preview sheets and in-engine screenshot baselines so visual changes are reviewed rather than inferred from source files.

## 08.2 — Environment and regional identity
- [x] Give Frontier biomes distinct ground textures in a dedicated seven-cell atlas (five land biomes, alternate Hearthland ground and water), preserving tile IDs, 16px tile size and water collision.
- [x] Add first biome-specific resource prop variants: Greenwood pine, Fenlands willow, Ashen deadwood, Highlands stone and Ashen rock; preserve Classic sprites and resource behavior.
- [ ] Expand into non-harvestable landmarks, resource clusters and ambient animation while preserving tile readability.
- Create a distinct Old Frontier/ruin subregion treatment without introducing an unsupported sixth core biome.
- Add visual cues for ownership, contested territory, supply routes, fog and regional objectives.

## 08.3 — Unit and faction identity
- Give each faction recognizable unit silhouettes, equipment, palette accents and banner/marker language.
- Ensure all six enemy archetypes remain identifiable at actual gameplay zoom and during night/combat effects.
- Add anticipation, attack, hit, stagger, death and ability feedback that communicates counterplay rather than decoration only.
- Keep player, villager and enemy sprite footprints consistent with Y-sort and collision origins.

## 08.4 — Building identity
- Replace generic/placeholder appearance with unique silhouettes for each shipped structure.
- Match visual construction stages, damage states and completed-building states to Phase 05 construction contracts.
- Add map and HUD icons that remain distinct at small pixel sizes.

## 08.5 — Audio
- Add layered ambient loops per biome/day-night state.
- Add readable combat cues for wind-up, projectile, block, charge, siege impact, camp alert and objective completion.
- Add a restrained campaign/menu music set; keep volume controls and mute behavior integrated with existing settings.
- Use original or properly licensed audio and document credits.

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