# Phase 11.3 — Rival Workforce and Production Economy

**Date:** 2026-11-07  
**Implementation baseline:** `7988eb345651a1debf4fdea492b7702b25630ccb`  
**Gameplay implementation:** `5203b47bcbda99fd53629976b02a54a824999bf9`  
**Save schema:** v17 (unchanged)

## Goal

Remove free, unlimited building production from rival strongholds. Make employment, construction and recruitment compete for a finite population without simulating extra autonomous Node actors.

## Rules

- Eight citizen positions per stronghold.
- A living garrison soldier occupies one citizen position.
- At least two economic workers remain available.
- Production buildings employ at most two workers each.
- Doctrine selects labor priority: Ambush favors Lumber Camp, Fortress favors Quarry, Attrition favors Farm, Siege favors Quarry/Forge.
- Active construction reserves up to two builders. Each builder contributes 0.5 construction work per simulation second.
- Worker food upkeep is 0.04/second; soldier upkeep is 0.06/second, in addition to existing subsistence income.

## Staffed production

| Workplace | Yield per worker per second | Maximum staffed yield |
|---|---:|---:|
| Lumber Camp | 0.525 wood | 1.05 wood |
| Farm | 0.625 food | 1.25 food |
| Quarry | 0.31 stone + 0.04 iron | 0.62 stone + 0.08 iron |
| Forge | 0.11 iron | 0.22 iron |

Baseline subsistence/scavenging income is retained. A production building only contributes its workplace yield when it is completed and has assigned workers. A destroyed production building immediately releases its workers.

## Persistence and performance

Assignments are derived from current living garrison count and active completed structures; no extra save fields are needed. The model advances on the existing bounded one-second civilization tick. No per-frame worker entities, pathfinding or scene allocations are added. Save schema v17 and historical save decoding remain unchanged.

## Regression coverage

The existing `army_command_and_rival_civilization` test checks:

- Workforce conservation across builder, production, and idle jobs.
- Two-worker caps at every production workplace.
- Garrison size-to-workforce conversion and the protected two-worker floor.
- Doctrine-specific labor priorities.
- Actual wood, stone, iron and food accounting against assigned labor and upkeep.
- Release of workplace labor when a production structure is destroyed.
- Existing rival construction, research, recruitment, army command and persistence behavior.

## Deferred

This phase does not claim visible rival laborers, resource-node depletion, travel, local storage, road-connected shipments, outposts, secondary settlements or coordinated offensive planning. Those require a separate world/logistics model and rendered gameplay acceptance.


## Follow-up implementation — visible rival workers (2026-11-08)

The original phase established finite workforce allocation and deliberately avoided per-frame actors. The subsequent physical-workforce slice now realizes assigned production jobs as runtime-only `EnemyEconomicWorker` entities while retaining bounded population and labor rules.

- Completed active Lumber Camp, Farm, Quarry and Forge structures spawn only the number of workers assigned by `labor_allocation()`, up to the existing two-worker cap.
- Lumber Camp workers harvest tree nodes; Quarry workers harvest rock nodes; Forge workers harvest iron after the rival's own research reaches Tier II; Farm workers perform the farm cycle.
- Workers reserve nodes through each resource node's existing `worker` field, path using `NavGrid.path_adjacent()`, stay in the owning local region/claim and reject player/contested territory.
- Cargo is delivered to the owning stronghold's resource ledger subject to current stockpile capacity. Workers are separate from player villagers and military garrison groups.
- Save export folds carried cargo into the existing resource ledger and clears it from live actors. No worker position/cargo fields or schema migration are introduced; v17 remains in force.

Verification completed on merged `main` (`dc060785b54b220a1b63d3149daa24fb59751b96`). `rival_physical_workforce`, `rival_civilization_persistence` and the integrated `army_command_and_rival_civilization` tests passed on the merge commit; the full Godot 4.7 matrix passed 66/66 and Campaign Simulation QA passed. Save schema v17 remains unchanged. A dedicated rendered capture/playtest of rival workers has not yet been performed.

Still deferred: local depots, road shipments, inter-settlement logistics, outposts, secondary settlements, coordinated military planning and target-desktop frame-time acceptance.
