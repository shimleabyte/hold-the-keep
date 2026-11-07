# Phase 11.6 — Rival Military Research Unlocks

**Date:** 2026-11-07  
**Implementation:** `dd5b7f4170c3cb8ba4077824037036ee61a638b7`  
**Save schema:** v17 (unchanged)

## Goal

Make rival military research change battlefield capability. Research should unlock recruitable roles rather than merely increase a tier label.

## Recruitment gates

| Minimum technology tier | Available advanced roles |
|---|---|
| Tier I | Bandit, Scout, Wolf, Archer, Shieldbearer |
| Tier II | Saboteur, War Shaman |
| Tier III | Beast Rider, Siege Engine |

Basic faction roster roles remain available at Tier I. The doctrine composition planner filters locked candidates; `can_recruit` and `pay_recruitment` independently enforce the same gate, preventing direct callers from bypassing research.

Unit-specific resource costs remain in force after unlock. Research is not a free recruitment action. The initial three-unit garrison remains campaign setup; periodic reinforcements are paid.

## Persistence

No unlock state is separately serialized. The existing rival `technology_tier` is the source of truth, and current living guard IDs determine army composition. Save schema remains v17.

## Regression

The `army_command_and_rival_civilization` test verifies that the Ashen Host begins with shield infantry, unlocks War Shamans and Saboteurs at Tier II, and only gains Siege Engine recruitment at Tier III. The test also checks Tier III composition prioritizes its siege engine. Exact-head Godot CI passed 64/64 and Campaign Simulation QA passed 1/1.

## Deferred

This phase does not add military attack orders, target selection, coordinated raids, siege staging, or retreats. It only gates periodic stronghold recruitment by the civilization's existing research tier.
