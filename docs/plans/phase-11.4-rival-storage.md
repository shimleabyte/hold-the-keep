# Phase 11.4 — Rival Storage and Production Overflow

**Date:** 2026-11-07  
**Gameplay baseline:** a1f59f535cf732d73ecd38cb7010641d70bd1947  
**Implementation:** 8fa13a80e3d431d815b23a4fef6e885202579a09  
**Regression follow-up:** 3e6cfe375f20d5d7ae5677fb268608e968a175a3  
**Save schema:** v17 (unchanged)

## Goal

Give the rival Storage building a functional economic purpose and stop assigning scarce workers to production whose output cannot be retained.

## Rules

- Base capacity: 240 units per resource.
- A completed Storage building raises capacity to 600 units per resource.
- Production is credited only up to available capacity.
- A full Lumber Camp, Farm or Forge stockpile makes that workplace temporarily ineligible for labor.
- A Quarry remains eligible while either stone or iron has room; overflow for the already-full resource is discarded.
- Labor priority then moves workers to the next eligible workplace under the faction doctrine.

## Save compatibility

Existing v17 balances above the new limit are preserved. Loading does not reduce or delete saved resources. An over-cap resource simply receives no additional production until spending brings it under the active capacity. Labor assignments remain derived/transient; no save-schema change is needed.

## Regression coverage

The existing army/rival regression checks base and expanded capacity, saturation, worker reassignment when a stockpile fills, and preservation of an over-cap v17 balance. Existing rival economy and persistence tests remain in the full Godot CI matrix.

## Deferred

This phase does not add visible rival workers, local resource-node extraction, travel, transport, multiple depots, roads, shipments or secondary settlements. Storage is currently the cap for the stronghold's single rival ledger.
