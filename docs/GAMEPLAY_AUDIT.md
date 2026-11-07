# Hold the Keep — Gameplay Audit

**Audit date:** 2026-11-07  
**Repository:** `shimleabyte/hold-the-keep`  
**Baseline inspected:** remote `main` at `931cca8e065976da89a33d40ef42c5f70bd6b308`  
**Engine target:** Godot 4.7  
**Save schema:** v17

## Executive assessment

The current game is a substantial hybrid of settlement survival, direct-action combat, regional campaign progression and a first-pass RTS layer. It is not yet a complete kingdom strategy game. Most player-side building blocks exist, but rival civilizations are still single-stronghold economic simulations with an abstract workforce, fixed construction order and local defensive garrisons. Their economy does not yet expand into a competing territorial system.

The principal gap is not a lack of content. It is the missing strategic connection between rival economic policy, territorial expansion, military planning and campaign objectives.

The first implementation slice in this change makes the four existing faction doctrines affect actual rival investment order. It does not claim to complete rival expansion, offensive AI or the full campaign overhaul.

## 1. Existing playable loop

### Classic

The configured Classic campaign lasts 15 days. The player manages a settlement during the day, allocates autonomous villagers, gathers and spends resources, constructs and researches, then defends the Keep during night waves. Enemy pressure scales by day and the enemy King appears on the final night. The direct-control knight remains active throughout.

### Frontier and Frontier Expedition

Frontier uses a 20-day, four-act campaign. Regional discovery, faction camps, campaign objectives and multiple strongholds create a larger conquest route. Frontier Expedition adds a 256×256 world with a 160×160 starting heartland and discovery-gated outer marches. The progression is more strategic than Classic, but its objective sequence is still largely authored rather than selected by the player.

### Moment-to-moment player control

The player directly moves and fights as the blue-mantled knight. The player has a basic melee loop, Dash, Cleave and Rally abilities, experience progression and direct harvesting/interactions. Military control is separate: living soldiers, including Archer-specialized soldiers, can be selected individually or by drag/Shift selection and receive move or attack orders. Civilians are not selectable by the army commander.

## 2. Verified systems and dependencies

| System | Verified implementation | Important dependency or boundary |
|---|---|---|
| World | Classic 128×128, Frontier 192×192 and Frontier Expedition 256×256 new-campaign profiles; deterministic regional generation, five biomes and legacy saved dimensions | World configuration, terrain generation, occupancy and navigation must remain synchronized |
| Player | Direct movement/combat, harvesting, Dash, Cleave, Rally, XP and saveable combat state | Must remain the player-facing tactical layer; do not replace with cursor-only RTS control |
| Civilian economy | Job quotas and priority assignment for woodcutters, miners, farmers, builders, hunters, scouts, healers, blacksmiths and soldiers | Village assignment depends on workplaces, reachable targets, storage/depot availability and population upkeep |
| Construction | Building placement, builder-driven construction sites, a construction queue, repairs, prerequisites and footprint occupancy | Construction state, worker pathing, resource payment and save state must agree |
| Resources and logistics | Wood, stone, food and iron; local depot stockpiles, bounded transfers, explicit cost sources, physical shipments, roads and supply-pressure behavior | Supply connectivity is computed from the road/depot graph; isolated depots can be exposed to raids |
| Technology | Data-driven technology definitions across three eras; research spends resources and gates buildings/equipment | Current research remains primarily a predefined unlock/progression path |
| Territory and information | Keep/Outpost claims, frontier placement rules, regional state, permanent fog exploration, Scout Post and Watchtower vision | Player claims and conquest objectives are not yet a full two-sided territorial economy |
| Enemy factions | Four faction definitions, distinct rosters and specialist archetypes; camps can patrol and raid | Camp behavior is not yet coordinated with a rival stronghold's economic and territorial plan |
| Army command | Soldier-only selection, drag selection, Shift add/remove, move and attack | No attack-move, order queue, control groups or formation editor |
| Rival strongholds | Separate stronghold entities; each owns a finite resource ledger, visible structures, bounded construction/research and paid periodic recruitment | Abstract workforce; fixed local build area; no rival outposts, secondary settlements, roads or full offensive planner |
| Persistence | Additive rival civilization state in v17; legacy world dimensions and save migration paths remain | Save/load must preserve economy, construction, structures, stronghold and campaign state |

## 3. Strategic decisions that already exist

The player can choose how to allocate a limited civilian workforce between production, construction, scouting, healing, specialist equipment and military duty. Food upkeep makes population growth and army conversion consume economic capacity. Buildings, technology and unit equipment share resource constraints. Local depot stock and road connectivity make the location of a resource and its storage relevant. Outposts and regional objectives create a risk/reward choice between compact defense and forward development.

Army composition already has distinct enemy archetypes and soldier specializations. The knight can intervene directly, while the army command system controls soldiers independently.

These mechanics provide a useful base. Their strategic value is reduced when rivals do not make comparable territorial and military decisions.

## 4. Highest-severity gaps

### P0 — Playability is not fully established

The exact baseline SHA passed automated Godot 4.7 validation and campaign simulation. That does not establish control clarity, pacing, tactical readability or enjoyment in a live session. A rendered ten-minute opening and a longer middle-game playthrough remain mandatory acceptance work. No P0 defect is claimed absent, because this environment did not run the game interactively.

### P1 — Rival strategy is not yet strategic

1. Before this change, `EnemyCivilization` used one global seven-building order for every faction. The `doctrine` field in `data/factions.json` did not affect settlement investment.
2. Rival resource generation is abstracted. Base income and building production do not require visible rival workers, travel, resource-node access, roads or deliveries.
3. Rival construction searches a bounded ring around one owning stronghold and stays within that stronghold's region. There is no rival secondary settlement, outpost network or territorial expansion.
4. The rival stronghold periodically recruits a paid local garrison, but it does not plan coordinated raids, reinforcement routes, sieges or retreats as an economic-military campaign.
5. Faction camps already patrol and raid, but that system is not yet a shared strategic planner for the rival civilization's economy, settlements and armies.

### P2 — Strategic variety and campaign agency

1. The campaign offers authored objectives and a final victory condition, not player-selected economic, territorial or diplomatic victory paths.
2. No diplomacy or trade system currently connects rival relations to access, resource exchange, ceasefires or war escalation.
3. Army commands are intentionally basic. Reliable move/attack behavior should be retained before adding attack-move, order queues or formations.
4. Technology is broad enough to support progression, but the audit did not find distinct strategic branches that make different kingdom plans viable end-to-end.

### P3 — Acceptance and release evidence

Human playthroughs, target-desktop frame-time percentiles, native-resolution review, old-save desktop continuation and audio listening remain open. The visual asset/animation PRs are separate work and must not be confused with gameplay completion.

## 5. Implementation delivered with this audit

### Phase 11.2 — Doctrine-driven rival investment

Rival construction now derives its priority order from the owning faction's existing doctrine:

| Faction | Doctrine | Investment priority |
|---|---|---|
| Greenwood Raiders | Ambush | Lumber Camp → Quarry → Barracks → Farm → Tower → Forge → Storage |
| Iron Legion | Fortress | Lumber Camp → Quarry → Tower → Farm → Barracks → Storage → Forge |
| Fen Cult | Attrition | Farm → Lumber Camp → Quarry → Storage → Barracks → Tower → Forge |
| Ashen Host | Siege | Quarry → Lumber Camp → Farm → Barracks → Forge → Tower → Storage |

All doctrines retain the same seven structures, build costs, construction durations, resource production, recruitment costs and finite resource ledger. The change is the order in which the AI commits its resources; it does not grant resources, bypass prerequisites or use difficulty multipliers.

The build cursor is reconciled from completed/pending structures and any active construction record. A destroyed priority structure becomes eligible for reconstruction. This avoids treating a legacy v17 integer cursor as a permanent index into a newly reordered plan. No save-schema change is required.

The existing `army_command_and_rival_civilization` regression now checks all four exact plans, confirms that each plan starts its preferred affordable structure and verifies that the structure cost is debited from that civilization's own ledger.

## 6. Deferred implementation order

1. **P0 gameplay acceptance:** execute a rendered Classic opening for at least ten minutes and a longer session into the middle game. Record decisions per minute, idle periods, control friction, worker stalls, combat outcomes and recovery windows.
2. **P1 rival economy:** make rival production depend on a bounded workforce/logistics model; add local storage and road/supply constraints rather than invisible production bonuses.
3. **P1 territory:** add rival outposts or secondary settlements only when ownership, construction, supply and save/load semantics are coherent.
4. **P1 military planner:** connect recruitment and faction doctrine to reconnaissance, patrol, raid, attack preparation, local defense and retreat; all recruitment must remain paid.
5. **P2 progression:** add a small number of genuinely different strategic unlock paths and objectives, rather than a large percentage-upgrade tree.
6. **P3 balance/release:** run campaign simulations, rendered sessions, target-machine profiling and save compatibility acceptance.

## 7. Verification boundary

At the audited baseline `931cca8e`, GitHub Actions reported:

- Godot 4.7 CI: 63/63 jobs successful, including import/parse, the regression matrix and performance/construction diagnostics.
- Classic + Frontier Campaign Simulation QA: 1/1 job successful.
- The latest Rendered World QA observed during the audit was on the parent SHA `27740a72`, not the audited `931cca8e`.

This workspace has no local repository checkout and no Godot 4.7 executable. A local Git clone also failed because the runtime could not resolve `github.com`. Therefore no local Godot execution, rendered playthrough or human ten-minute playtest is claimed. Post-change CI results must be checked on the new commit before treating this slice as integrated and verified.

Remote main and open PRs were inspected. The four open PRs at audit time were #182 (civilian role art), #181 (player atlas/animation), #152 (Android touch controls) and #150 (Android device checklist). The gameplay changes in this slice touch separate economy/test/documentation files; no unrelated PR is merged or overwritten.

## 5b. Phase 11.3 — Bounded rival workforce and production

Rival production now uses an explicit derived workforce instead of granting each completed production building full output regardless of labor availability.

- Each stronghold has an eight-citizen labor pool. Each living garrison soldier occupies one position; a minimum of two civilian workers is protected.
- Production buildings employ at most two workers each.
- Per-worker yields: Lumber Camp 0.525 wood/second; Farm 0.625 food/second; Quarry 0.31 stone plus 0.04 iron/second; Forge 0.11 iron/second.
- Doctrine changes labor priority as well as construction priority: Ambush favors wood, Fortress favors stone, Attrition favors food, Siege favors stone/iron.
- Active construction reserves up to two builders. Each builder contributes 0.5 work/second, so construction labor cannot simultaneously produce resources.
- Worker upkeep is 0.04 food/second and soldier upkeep 0.06 food/second, in addition to existing background subsistence income.
- Assignments are derived from the live garrison and completed structures every bounded economy tick. They are not serialized; save schema v17 remains unchanged.

The rival workforce is still abstract. Visible laborers, resource-node depletion, travel, roads, storage capacity and physical deliveries are not part of this slice.

The existing army/rival regression now checks workforce conservation, workplace caps, recruitment-to-labor conversion, staffed output formulas, doctrine labor priority and worker release when a production structure is destroyed.

## 5c. Phase 11.4 — Rival stockpile capacity (implementation)

The rival Storage building now has an economic purpose. Each resource starts with a 240-unit local stockpile limit; completing Storage raises the limit to 600. Production is credited only up to the active capacity. A full resource type stops staffing its corresponding production workplace, and labor is reassigned by the faction's remaining priority order.

Existing v17 saves with balances above the new capacity are preserved rather than clamped downward. Those balances simply receive no new production until spending reduces them below the current capacity. The save schema is unchanged.

Regression coverage verifies base/expanded capacity, saturation at the cap, labor release when a stockpile is full, and preservation of over-cap legacy balances.

## 5d. Phase 11.5 — Doctrine-driven paid army composition (implementation)

Periodic rival reinforcements now use the existing faction roster and doctrine composition targets rather than round-robin roster indexing. The recruiter counts the living stronghold garrison, measures each roster unit against the doctrine's target share, and chooses the most underrepresented affordable role. If no roster unit can be paid, the stronghold does not receive a reinforcement.

Each recruit has an explicit resource cost. Scouts and basic infantry remain cheaper; saboteurs, beast riders, shield specialists, shamans and siege engines consume additional food, wood, stone and/or iron. Initial opening garrisons remain unchanged; only periodic paid reinforcement uses the planner. Costs are debited only after a valid spawn cell is found and the unit is created. Save schema v17 is unchanged because composition is derived from the live garrison.

The existing army/rival regression now checks doctrine favorites, filling missing composition roles, per-unit costs and ledger debits, and refusal to recruit when no roster unit is affordable.


## 5e. Phase 11.5 — Composition-aware paid recruitment (implementation)

The rival stronghold no longer cycles mechanically through its faction roster when recruiting periodic reinforcements. Every doctrine has target unit shares. On each reinforcement opportunity the planner counts living garrison IDs, computes each candidate's composition deficit against the prospective army size, filters out unavailable/unaffordable roster entries, and selects the candidate with the largest remaining deficit. Roster order provides deterministic tie-breaking.

Each supported faction unit has an explicit recruitment cost. Basic roles have modest food/wood costs; disruption, cavalry, shield, shaman and siege roles consume additional resources. The stronghold does not spawn a periodic reinforcement when no candidate can be paid. Costs are debited only after a valid spawn succeeds. The three opening garrison units are preserved unchanged as initial campaign setup.

No unit-composition state is stored; it is derived from living garrison entities. Save schema v17 remains unchanged. The army/rival regression now verifies the expected first recruit for all four doctrines, composition deficit correction, unit-specific resource debits and no recruitment when all candidates are unaffordable.
