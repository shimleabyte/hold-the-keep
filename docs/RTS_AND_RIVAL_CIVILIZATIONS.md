# Hold the Keep — Rival Civilizations & Army Command

**Direction:** A hybrid kingdom strategy game. The player remains a directly controlled combatant and settlement steward. Civilian workers retain autonomous job behavior. Military units can be selected and commanded with the mouse. Rival factions must develop as competing settlements rather than passive strongholds.

## Non-negotiable boundaries

- Army selection and orders apply only to military units with job equal to soldier, including the existing archer specialization.
- Civilian workers are not directly selectable. Their existing job, construction, gathering, carrying and delivery loops remain autonomous.
- The player avatar, direct movement, combat abilities, camera and existing build-placement rules remain in place.
- Basic commands are select, box-select, move and attack. Advanced formation controls, control groups, attack-move and command queues are separate later work.
- Rival economy and construction are distinct from player buildings. Rival structures must not be assigned to player workers, depots or supply routes.
- Rival resource production is bounded and paid for. Recruitment, construction and research spend stored resources.
- New campaign dimensions are Classic 128×128, Frontier 192×192 and Frontier Expedition 256×256. The larger footprint is a gameplay requirement for rival settlement growth and territorial expansion, not a cosmetic option.
- Historical save dimensions remain supported: Classic 64×64, Frontier 128×128 and Expedition 192×192. Continue loads the exact dimensions stored by the campaign so old terrain, coordinates, fog and resource placement stay valid.
- New save state is additive. Existing v17 saves without civilization data must load with a valid initial rival economy.

## Current implementation slice

### Army command foundation
- Left click selects one military unit.
- Drag selects multiple military units.
- Shift adds/removes units from the current selection.
- Right click ground issues a move order.
- Right click a visible hostile unit, enemy stronghold or hostile settlement structure issues an attack order.
- Soldiers keep their combat execution, pathfinding and attack animation logic. The command layer does not take over every attack frame.

### Rival civilization foundation
- Each enemy stronghold owns an independent resource ledger and scheduled development simulation.
- Rival construction produces visible, destructible structures using existing art.
- Initial development order: lumber camp, farm, quarry, barracks, tower, forge and storage.
- Buildings generate resources; upkeep and construction/recruitment costs consume resources.
- Barracks increase garrison capacity. Recruitment consumes food and wood, with an iron cost at higher technology.
- Technology progresses through three military tiers using prerequisites, time and stored resources.
- Rival structures and economy state are persisted as additive stronghold state.

**Current limitation:** the initial economy foundation used abstract labor. The follow-up branch now instantiates visible rival workplace workers: lumber camps harvest trees, quarries harvest stone, forges harvest iron after rival Tier II research, and farms produce food on-site. Workers reserve world nodes, path locally and haul cargo to their own stronghold. Local depots, road-connected shipments, multi-settlement logistics, territorial expansion and coordinated offensive campaigns remain unfinished.

## Map-scale decision

The previous defer-expansion decision is superseded by real player playtesting: the old world sizes do not leave enough strategic distance or space for a competing civilization to develop. New campaigns therefore use the enlarged profile ladder. Resource density is retained as the map grows, and the Expedition heartland grows to 160×160 while its four outer marches remain discovery-gated.

## Delivery sequence

| Stage | Scope | Acceptance |
|---|---|---|
| 1 — Army orders | Military-only select, box select, move and attack | Workers remain autonomous; soldiers obey commands; player avatar and build mode remain unchanged |
| 2 — Rival settlement | Resources, visible construction, recruitment, research, save/load | Classic rival builds and develops without free resources or units; structure destruction and reload are safe |
| 3 — Faction strategy | Faction-specific economic priorities, defensive plans, patrols and raids | Four Frontier factions produce distinct strategic problems and respect their available resources |
| 4 — Expansion and warfare | Secondary settlements, outposts, logistics, siege plans and larger maps | Territory and supply matter; both sides can attack/defend; map dimensions are justified by actual strategic distance |
| 5 — Campaign rebalance | Classic/Frontier pacing, objectives and victory conditions | Human playthroughs establish challenge, recovery windows and campaign length |

## Performance and persistence constraints

- Strategic decisions run on bounded simulation ticks, not every rendered frame.
- Construction placement checks only a bounded local search around the owning stronghold.
- World occupancy and navigation updates use the existing dirty-cell/event mechanisms.
- Do not rebuild the full NavGrid or FlowField synchronously during each placement.
- Save resource balances, technology, completed structures, their HP and any active construction timer.
- Reconstruct paths and transient caches after load rather than serializing navigation internals.



## Phase 11.2 — Doctrine-driven investment (2026-11-07)

The first faction-strategy slice is implemented in `EnemyCivilization`. The existing faction doctrine now selects an economic investment order:

- Greenwood Raiders / ambush: Lumber Camp → Quarry → Barracks → Farm → Tower → Forge → Storage.
- Iron Legion / fortress: Lumber Camp → Quarry → Tower → Farm → Barracks → Storage → Forge.
- Fen Cult / attrition: Farm → Lumber Camp → Quarry → Storage → Barracks → Tower → Forge.
- Ashen Host / siege: Quarry → Lumber Camp → Farm → Barracks → Forge → Tower → Storage.

This changes which finite investment is chosen next, not how many resources a faction receives. All building costs, production values, work durations, research requirements and recruitment prices remain shared. Unknown doctrine IDs fall back to the original Classic plan. The build cursor is reconstructed from completed/pending structures and active construction state; structure loss can re-enter the priority plan. Save schema stays v17.

This is not the full faction-strategy stage. Visible rival workers and stronghold hauling are now implemented on `feat/rival-physical-workforce-hauling`; local depots, road shipments, secondary settlements, territory/supply expansion and coordinated offensive plans remain open. Regression coverage includes `tests/rival_physical_workforce.gd` and `tests/army_command_and_rival_civilization.gd`; exact-head verification is pending. Rendered faction pacing still requires a live Frontier playthrough.


## Phase 11.3 — Rival workforce and economic constraints (2026-11-07)

Rival production no longer grants the full building yield independently of labor. Each stronghold has an eight-citizen pool; living garrison soldiers occupy one citizen position each, with a two-worker minimum retained. Production sites employ up to two workers, and doctrine controls labor priority:

- Ambush: Lumber Camp → Quarry → Farm → Forge.
- Fortress: Quarry → Lumber Camp → Farm → Forge.
- Attrition: Farm → Lumber Camp → Quarry → Forge.
- Siege: Quarry → Forge → Lumber Camp → Farm.

Per-worker production is 0.525 wood/second (Lumber Camp), 0.625 food/second (Farm), 0.31 stone plus 0.04 iron/second (Quarry), and 0.11 iron/second (Forge). Active construction reserves up to two builders at 0.5 work/second each. Worker food upkeep is 0.04/second and soldier upkeep 0.06/second alongside existing background subsistence income. Recruitment therefore consumes resources, removes productive capacity and increases food demand.

Labor assignments are rebuilt from the live garrison and completed structures each bounded economy tick. They remain transient; live worker positions and cargo are not serialized. Resource-node yield is real and renewable, workers reserve and travel to nodes, and cargo is delivered to the owning stronghold. Save export atomically folds carried cargo into the existing resource ledger and clears it from live workers, so schema v17 remains unchanged. Local depots, road-connected shipments and multi-settlement logistics remain open.


## Phase 11.4 — Rival stockpile capacity (2026-11-07)

Each rival stronghold now has 240 units of capacity per resource by default. Completing its Storage building raises each resource capacity to 600. Production cannot exceed the active stockpile limit. A full Lumber Camp, Farm or Forge stockpile makes that workplace temporarily ineligible for labor. A Quarry remains eligible while either stone or iron has room; overflow for the already-full resource is discarded. Labor priority then moves workers to the next eligible workplace under the faction doctrine.

Existing v17 balances above the new capacity remain intact and production is suspended for that resource until spending lowers it. No save-schema migration is introduced. Regression checks cover storage capacity, saturation, labor reassignment and legacy over-cap balances.


## Phase 11.5 — Doctrine-driven recruitment and army composition (2026-11-07)

Periodic rival reinforcement now uses a target composition rather than incrementing through the roster. The faction doctrine specifies unit shares; the stronghold counts its living garrison and chooses the affordable roster type with the largest deficit against those shares. Ambush favors bandits/scouts/disruption/riders; Fortress favors shieldbearers and archers; Attrition favors wolves, shamans and scouts; Siege prioritizes siege engines with shield/shaman/saboteur support.

Recruitment costs are unit-specific and paid from the rival's own ledger. Higher-impact specialist and siege roles consume additional resources. If no roster type is affordable, no reinforcement spawns. The three-unit opening garrison is preserved as campaign setup; every subsequent periodic reinforcement must be paid. The live garrison is the source of composition truth, so no save fields or schema migration are needed.


## Phase 11.6 — Military research unlocks (2026-11-07)

Rival military research now gates advanced recruitment options. Basic infantry, scouts, wolves, archers and shield infantry are available at Tier I. Saboteurs and War Shamans require Tier II; Beast Riders and Siege Engines require Tier III. The recruitment composition planner excludes locked units, and the payment function independently checks the minimum tier. The same unit-specific costs still apply after unlock; research does not provide free troops. Initial three-unit garrisons are unchanged.

The unlock rules read the existing `technology_tier`, and army composition is still derived from living garrison entities. No save fields or schema bump are required.


## Phase 11.3.1 — Visible rival gathering and hauling (2026-11-08)

The physical workforce follow-up keeps the existing eight-citizen model and its two-worker per workplace cap. Runtime worker entities are spawned only for active completed workplaces and are resized from the derived labor assignment. Excess workers retire safely, returning any cargo before leaving; destroyed workplaces or strongholds release node reservations and workers.

| Workplace | Visible role | World interaction |
|---|---|---|
| Lumber Camp | Woodcutter | Reserves and harvests renewable tree nodes |
| Farm | Farmer | Performs a farm work cycle and carries food back |
| Quarry | Miner | Reserves and harvests renewable rock nodes |
| Forge | Miner | Harvests iron nodes after the rival's own Tier II research |

Workers use the existing NavGrid and stay within their owning stronghold's local claim/region. They reject player-owned or contested cells and never join player villager or enemy military command groups. The player does not directly select or control them.

Cargo is capped per worker. Stronghold delivery obeys the existing resource and stockpile capacity rules. Save export transfers in-flight cargo into the existing resource ledger and clears the worker's cargo, preserving it without introducing per-worker save records or changing schema v17. Cargo already extracted from the world remains conserved across save/load. A full stockpile may preserve delivered cargo above its soft active capacity as over-cap stored stock, after which production remains suspended until resources are spent.

**Scope boundary:** this first slice uses the stronghold as the central receiving store. It does not yet implement local depot buildings, road-connected supply shipments, inter-settlement transfers, outposts, second settlements or coordinated raids. Automated tests are being added; rendered and desktop acceptance must still be performed.
