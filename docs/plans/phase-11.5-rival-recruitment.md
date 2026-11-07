# Phase 11.5 — Doctrine-Driven Paid Army Composition

**Date:** 2026-11-07  
**Gameplay baseline:** `b6d3bedd434886ee709fb974c0522a9995e53725`  
**Implementation:** `4b78adfc9992ff59927f9481fa96d19f7c2cd9bb`  
**Save schema:** v17 (unchanged)

## Goal

Replace round-robin rival recruitment with a composition-aware decision that respects faction doctrine and actual resource affordability.

## Target army tendencies

| Doctrine | Target composition | Recruit decision |
|---|---|---|
| Ambush | Bandits 35%, Scouts 25%, Saboteurs 20%, Beast Riders 20% | Cheap pressure and disruption, with reconnaissance |
| Fortress | Shieldbearers 40%, Archers 35%, Siege Engines 25% | Defensive frontline and ranged support before siege |
| Attrition | Wolves 35%, War Shamans 25%, Scouts 20%, Beast Riders 20% | Harassment, support and pursuit |
| Siege | Siege Engines 40%, Shieldbearers 25%, War Shamans 20%, Saboteurs 15% | Structural pressure protected by support |

The stronghold counts its living garrison and scores each faction roster candidate by its target-share deficit after one prospective recruit. Only defined, affordable units are considered. The highest deficit is selected; roster order breaks ties deterministically. If no candidate is affordable, the reinforcement timer elapses without spawning a unit.

## Unit-specific costs

| Unit | Food | Wood | Stone | Iron |
|---|---:|---:|---:|---:|
| Bandit | 10 | 4 | — | — |
| Scout | 10 | 4 | — | — |
| Saboteur | 14 | 6 | — | 1 |
| Beast Rider | 18 | 8 | — | 2 |
| Shieldbearer | 14 | 5 | 4 | 1 |
| Archer | 11 | 6 | — | — |
| Siege Engine | 20 | 10 | 12 | 3 |
| Wolf | 8 | — | — | — |
| War Shaman | 16 | 6 | — | 1 |

The initial three-unit garrison remains as campaign setup. Periodic reinforcements are paid. The spawn function accepts a selected roster ID and validates it against the faction roster/DataDB before creating the actor. Resource payment occurs after a valid spawn is made; the operation contains no asynchronous yield.

## Save and simulation constraints

Composition is derived from currently living guard IDs; no composition snapshot or new save field is added. The implementation uses the existing bounded reinforcement timer and the existing finite resource ledger. No new per-frame loops, pathfinding, or scene nodes are created by the planner. Save schema v17 remains unchanged.

## Regression

The existing `army_command_and_rival_civilization` suite checks doctrine favorite recruit, deficit filling against a sample garrison, valid roster membership, individual cost debits, and no recruitment when the ledger cannot pay any candidate. Existing soldier-only army command, autonomous civilian, rival persistence, and campaign tests remain in the matrix.

## Deferred

This does not add attack planning, target selection, coordinated raids, siege staging, retreats, secondary settlements, or physical supply chains. It only decides what a stronghold recruits when its existing periodic reinforcement opportunity occurs.
