# Phase 11.2 — Faction-Driven Rival Settlement Strategy

**Date:** 2026-11-07  
**Baseline:** `main` at `931cca8e065976da89a33d40ef42c5f70bd6b308`  
**Status:** Implementation committed with the gameplay audit; live CI and rendered acceptance tracked separately.

## Goal

Make existing rival faction identity change real economic decisions. Do not add another resource, free income source, AI difficulty multiplier or separate economy implementation.

## Implemented slice

`EnemyCivilization.development_order()` reads the owning faction's existing `doctrine` from `FactionRegistry` and returns a deterministic priority over the existing seven-building plan.

| Doctrine | Priority | Intended pressure |
|---|---|---|
| Ambush | Lumber Camp, Quarry, Barracks, Farm, Tower, Forge, Storage | Commit toward a recruit-capable settlement early |
| Fortress | Lumber Camp, Quarry, Tower, Farm, Barracks, Storage, Forge | Invest in fixed defense before military expansion |
| Attrition | Farm, Lumber Camp, Quarry, Storage, Barracks, Tower, Forge | Secure food and storage before army buildup |
| Siege | Quarry, Lumber Camp, Farm, Barracks, Forge, Tower, Storage | Build the stone/iron chain before heavy military infrastructure |

Every priority contains all current buildings exactly once. Unknown or missing doctrines fall back to the original Classic order. Building costs, construction work, production, research costs, recruitment costs and caps are unchanged.

The cursor is reconstructed from actual completed/pending structure records or the active construction record. Destroyed structures can be reconsidered after the current construction completes. Save schema remains v17; no migration is introduced.

## Regression requirements

- Verify every doctrine resolves to the exact expected order.
- Verify all plans contain all seven structures.
- Advance each rival by one bounded simulation tick and assert its preferred affordable building becomes the active construction.
- Verify wood and stone debits match the building cost after the normal baseline income tick.
- Retain existing army-command, rival economy, persistence and Classic/Frontier campaign tests.

## Still open

- Render each faction's first three development decisions in an actual Frontier session.
- Confirm the Fortress and Siege openings do not create economically inert waiting periods.
- Confirm doctrine differences remain visible after structure destruction and save/reload.
- Add faction-aware recruitment and coordinated military planning only after this investment layer is observed in a full session.
- No manual ten-minute or middle-game playtest is claimed by this phase.
