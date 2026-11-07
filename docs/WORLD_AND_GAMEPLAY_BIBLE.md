# Hold the Keep — World & Gameplay Design Bible

**Status:** Product and content direction  
**Revision:** 2026-11-01  
**Applies to:** Classic and Frontier campaigns, factions, enemies, settlement systems, objectives, visual identity, audio and future narrative content.

This document defines what belongs in Hold the Keep and how future content should feel. It is a design reference, not a claim that every described mechanic or asset is already implemented. ROADMAP_NEXT_LEVEL.md remains the source of truth for delivery status and technical sequencing.

---

## 1. Product identity

### Working identity: Grim Medieval Folklore Fantasy

The world is materially grounded. Land, food, labor, disease, weather, trade, war and political power determine whether a settlement survives. Folklore shapes how people interpret and respond to those pressures. The supernatural is real, but uncommon, dangerous and poorly understood.

This is a deliberate blend, not an equal mixture:

1. **Grounded medieval hardship is the foundation.** Most pressure comes from understandable human, economic, environmental and military causes.
2. **Folklore is the cultural language.** Local customs, taboos, rumors, rites, omens and inherited knowledge shape regional identity.
3. **The supernatural is the exception that changes the rules.** It should be rare enough to remain unsettling and consequential enough to be remembered.

The game should feel like a frontier settlement trying to establish order in a world that has already begun to fail—not a bright fantasy kingdom clearing endless monster waves.

### Player fantasy

The player is responsible for a vulnerable Keep and the people whose lives depend on it. They directly fight, explore and intervene while also shaping the settlement through labor, construction, supply and military decisions.

The player is not an all-knowing ruler issuing frictionless commands. Information is partial, workers have limits, routes can fail and victories create new responsibilities.

### Positioning statement

> Build a kingdom in a dying world. Hold the line against war and hunger, expand into hostile lands, and uncover what should have remained forgotten.

### What the game is

- A hybrid of direct top-down action, settlement management, survival pressure and regional conquest.
- A strategy game where the player remains physically present in the world.
- A medieval setting whose identity comes from the relationship between ordinary hardship and local folklore.
- A campaign about securing and maintaining territory, not merely defeating a final boss.

### What the game is not

- Not a full RTS that requires direct micromanagement of every civilian. Civilian work remains autonomous; military units may receive direct selection, movement and attack orders.
- Not a pure colony simulator where the player only watches autonomous agents.
- Not a conventional high-fantasy monster-clearing game.
- Not a horror game built around jump scares.
- Not a sprawling 4X game that requires constant expansion to remain interesting.

---

## 2. Design pillars

### A. Survival has a material cost

Food, shelter, labor, storage, health, distance and time must matter. A new system should create a legible decision, not another bar to maintain.

A shortage should have a cause the player can understand and, with preparation, influence. Avoid arbitrary punishment and opaque background calculations.

### B. The player is both fighter and steward

Direct combat and settlement decisions must reinforce one another. A player who explores recklessly may lose access to a resource route; a player who neglects defense may lose workers or infrastructure. A prepared settlement should create options during expeditions and sieges.

Management must not remove the need for player skill, and combat must not make the settlement layer irrelevant.

### C. Territory changes the campaign

A region is more than a differently colored patch of map. It should change access to resources, routes, threats, information, objectives or political conditions. Capturing territory should create a meaningful strategic benefit and a new responsibility.

### D. Every enemy asks a question

Enemy identity is defined by behavior and the response it demands, not by name, tint or health value. A new archetype must make the player or settlement change tactics.

### E. The uncanny is earned

Folklore and supernatural content must grow from place, history and consequence. Do not use supernatural explanations to excuse weak systems or turn every ordinary problem into a monster encounter.

### F. Complexity is layered, not dumped

The game can support interconnected systems, but new players should encounter them in a readable sequence. Classic is the lower-complexity entry point; Frontier can carry the broader campaign. Advanced logistics and specialist roles must be introduced with clear feedback and useful defaults.

---

## 3. World tone and supernatural rules

### Three levels of the uncanny

**Level 1 — Folk practice and rumor**

Examples: bells rung before dusk, paths avoided after dark, offerings left at boundary stones, names not spoken near old ruins. These practices may be cultural, psychological or practical. They give regions texture even when no supernatural event occurs.

**Level 2 — Ambiguous evidence**

Examples: livestock found facing the same direction, a patrol hearing a bell from an abandoned settlement, a blight pattern that does not match the weather, or tracks that stop at a dry stone wall. The player receives clues, not an immediate explanation. Natural causes must remain plausible until evidence accumulates.

**Level 3 — Confirmed supernatural threat**

Examples: a presence tied to a buried site, a ritual that produces a measurable effect, or an entity that violates ordinary physical expectations. These events should be rare, clearly telegraphed and mechanically consequential.

A confirmed supernatural event must not be a random damage tax. It needs:
- A discoverable cause, source or condition.
- Warning signs before irreversible consequences.
- At least one meaningful response: avoid, investigate, contain, disrupt, negotiate or exploit.
- A cost or risk attached to the chosen response.
- A persistent world, campaign or resource consequence when appropriate.

### Tone guardrails

- Human conflict remains a major source of cruelty. Monsters must not displace political, military and economic threats.
- Do not make every forest, ruin or night encounter supernatural.
- Do not explain all folklore. Some beliefs can remain unresolved.
- No gore for decoration. Violence should communicate danger and consequence.
- Hope must remain possible. A world without relief becomes emotionally flat and mechanically exhausting.
- Humor may exist in ordinary human behavior, but it must not undermine major tragic or uncanny moments.

Use grounded hardship as the default presentation, folklore as the regional texture and overt supernatural content as the rare escalation. This is a qualitative art and encounter guideline, not a fixed spawn-rate formula.

---

## 4. World structure

The existing five biomes remain the core geographic vocabulary:

| Region | Material identity | Folklore identity | Gameplay opportunity |
|---|---|---|---|
| Hearthland | Farms, roads, villages, contested farmland | Household rites, boundary stones, harvest omens | Food security, population, trade and defense |
| Greenwood | Timber, dense cover, narrow routes | Forest taboos, lost paths, old markers | Ambushes, hunting, scouting and concealment |
| Highlands | Stone, exposed routes, difficult approaches | Cairns, ancestor markers, storm warnings | Quarrying, fortification and siege routes |
| Fenlands | Wet ground, disease pressure, difficult movement | Drowned settlements, reed charms, burial customs | Risky shortcuts, medicine, poison and hidden sites |
| Ashen March | Scorched land, ruins, depleted resources | Battlefield rites, ash omens, forbidden remains | Late-campaign pressure, salvage and dangerous relics |

Old Frontier remains a ruin-dense subregion rather than a sixth core biome. Its identity should come from landmarks, ruins, history and encounter design—not merely a different ground color.

### Frontier Expedition geography

Frontier Expedition is an optional larger campaign profile, not a replacement for the established 128×128 Frontier campaign. It uses a 192×192 tile world while keeping a 128×128 heartland walkable at the start. The four surrounding marches are generated from the same five-biome vocabulary but remain physically sealed behind survey crossings.

A march opens only when the player explores to its inner-side crossing and completes that region's discovery objective. The crossing is a real navigation/terrain change, not a menu toggle: closed barriers reject ordinary movement and bridge placement. Once opened, the player can move into the outer march and continue revealing it through permanent fog-of-war. Strategic-map survey markers must remain hidden until normal vision discovers the approach; unknown terrain and locations must not be disclosed early.

The four discovery records are the source of truth for open crossings. Loading a save must reconstruct gate state from those records, with no new save-version field. The world remains fully generated and loaded; sector boundaries are gameplay gates, not runtime chunk streaming. Outer territory should become useful through existing exploration, outpost, road, resource and faction systems rather than being an empty visual border.


A biome must be identifiable through more than its floor tile. It should combine terrain, props, resource distribution, silhouettes, landmarks, ambient sound and a gameplay reason to visit.

---

## 5. Faction identity

The four existing Frontier factions are retained. Their visual identity and combat behavior must express a distinct way of surviving and exercising power.

| Faction | Core worldview | Tactical identity target | Player response |
|---|---|---|---|
| Greenwood Raiders | Survival through mobility, local knowledge and control of routes | Scouts, ambushes, traps, harassment and attacks on exposed logistics | Secure routes, improve vision, use escorts and avoid chasing into prepared terrain |
| Iron Legion | Order through hierarchy, discipline and industrialized warfare | Formations, protected advances, shielded units and deliberate siege pressure | Break support, flank, use terrain and prepare layered defenses |
| Fen Cult | Survival through rites, poison, attrition and control of unhealthy ground | Debilitation, support, disease/poison pressure and terrain denial | Interrupt support, manage exposure, use medicine and choose routes carefully |
| Ashen Host | Conquest through fear, destruction and the reuse of a ruined past | Heavy assault, siege equipment, fire/ash-themed pressure and dangerous remnants | Disrupt siege assets, protect critical structures and exploit slow commitment |

These are design targets, not a claim that all behaviors currently exist. A faction is not complete when it has a color, roster and name. It is complete when its composition creates a recognizable tactical problem and its region tells the player why it fights that way.

### Enemy archetype acceptance

The six planned archetypes—Scout, Shieldbearer, Saboteur, War Shaman, Siege Engine and Beast Rider—must each have:

1. A visible signature before its strongest action.
2. A distinct behavior loop.
3. A counter or mitigation the player can learn.
4. A reason to prioritize or ignore it.
5. Readable feedback at normal gameplay zoom.
6. Bounded AI cost and save/reload behavior where its state persists.

A numerical variant of an existing unit does not count as a new archetype.

---

## 6. The three gameplay loops

### Moment-to-moment: act and react

- Move, fight, dodge and use unlocked abilities.
- Read enemy intent and protect vulnerable workers or structures.
- Interact with nearby resources and objectives.
- Decide when to retreat rather than treating every encounter as mandatory.

Combat must remain readable at default zoom. Effects, sprites and HUD cannot hide threats or block the usable playfield.

### Day-to-day: keep the settlement alive

- Assign labor and military roles.
- Produce and preserve food and materials.
- Build, repair and improve defenses.
- Keep workers and depots connected to useful routes.
- Prepare for the next night, raid or campaign event.

The settlement should expose its problems clearly: what is missing, where it is stored, who can access it and what will happen if the player does nothing.

### Campaign: change the frontier

- Discover a region and learn its risks.
- Decide whether to secure, bypass, exploit or investigate it.
- Establish a defensible presence and a supply connection.
- Resolve its hostile power or regional objective.
- Absorb the consequences of expansion and prepare for retaliation.

Conquest must not be a repeated sequence of walking to a marker and reducing a health bar. Regional objectives need different verbs, risks, constraints and consequences.

---

## 7. Event and objective design

### Events should create decisions

An event that only adds or removes a resource is a notification, not a meaningful event.

A stronger event presents:
- A situation the player can understand.
- Two or more viable responses when appropriate.
- A cost, delay or risk for each response.
- A consequence that can be observed later.

Examples:
- Refugees increase labor capacity but strain food and housing.
- A failed harvest can be mitigated by stored food, trade or rationing.
- A suspicious illness may require quarantine, treatment or investigation; the supernatural explanation should not be assumed.
- A trader offers a rare supply at a cost that may weaken another plan.

Not every event needs a dialogue choice. A visible tactical response is also a decision.

### Objectives need different verbs

Avoid padding the campaign with multiple names for the same interaction. “Clear camp” and “clear ruin” are not distinct if both mean attack a site until its health reaches zero.

Preferred objective verbs include:
- Discover: reveal a location and understand why it matters.
- Rescue: reach and free a person under a specific threat.
- Escort: protect a moving target across a risky route.
- Defend: hold a location for a defined interval under changing pressure.
- Sabotage: disable a specific capability rather than destroy a generic HP pool.
- Investigate: collect or verify evidence and choose what to do with it.
- Contain: prevent a threat from spreading beyond a boundary.
- Negotiate: meet a condition, make a concession or accept a future obligation.
- Conquer: defeat an organized hostile force and secure the site afterward.

Use only verbs supported by a real mechanic. Do not write objectives the current game cannot resolve.

---

## 8. Survival systems and player consequences

Hardship should create strategic pressure, not routine frustration.

- Food, disease, injury, weather and local supply are candidates for deeper survival systems, but each requires clear sources, consumers, UI and save rules.
- Do not add a resource unless at least one system produces it and another consumes it.
- Do not add population upkeep or attrition without communicating the cause and giving the player a reasonable preparation window.
- Player death should carry a consequence that fits the tone without forcing save deletion or permadeath. Possible directions include temporary wounds, recovery time, lost expedition momentum or a limited supply penalty.
- Death consequences must be consistent, telegraphed and recoverable through play.
- Logistics should reward planning. Avoid requiring constant manual shipment orders for routine operation; future automation policies should provide clear defaults and optional control.

A new survival mechanic should affect at least two of these areas: settlement economy, direct combat, regional exploration, faction warfare or campaign progression. Otherwise it is probably feature bloat.

---

## 9. Audience and onboarding hypothesis

This is a positioning hypothesis, not verified market research.

**Primary audience:** PC players interested in settlement defense, survival strategy and medieval management who also want direct action rather than a purely observational colony simulator.

**Secondary audience:** players attracted to dark medieval settings, folklore, regional exploration and tactical enemy encounters.

The hybrid is the product's potential hook, but it is also its largest risk: players may find the game too demanding if all management systems become mandatory at once. Therefore:

- Keep the Classic campaign as the approachable entry point.
- Introduce core actions before specialist roles and complex logistics.
- Give new players a guided first-day/first-night sequence and contextual hints.
- Make the HUD communicate the most urgent problem first.
- Prefer sensible automation and defaults over mandatory repetitive micromanagement.
- Let experienced players opt into deeper logistics and campaign pressure.
- Do not market the game as a full colony sim, grand strategy game or horror game unless those experiences become substantial and verifiable.

A broader audience is more likely to come from clear onboarding and a strong core loop than from adding more systems.

---

## 10. Art and audio direction

### Visual language

Use **weathered medieval pixel art with restrained folklore motifs**.

- Base palette: soil, aged timber, iron, faded cloth, overcast sky, peat, ash and restrained plant life.
- Folklore accents: carved boundary marks, worn charms, burial markers, ritual cloth, bells and strange environmental repetition.
- Supernatural accents: rare and unmistakable, but not constant glow or generic magical particle effects.
- Faction distinction must survive grayscale or low-saturation viewing; silhouette, equipment and animation matter more than tint.
- Biomes need distinct prop density, landmarks and ground variation while retaining gameplay readability.
- UI should feel like a field instrument or medieval record, not a generic fantasy mobile-game menu.

Avoid relying on a single dark filter to create atmosphere. Contrast and interaction readability take priority over mood.

### Audio language

- Hearthland: work, wind, animals, distant human activity.
- Greenwood: dense foliage, branches, insects and uncertain distance cues.
- Highlands: exposed wind, stone, sparse wildlife and long reverberation.
- Fenlands: water, reeds, insects and muffled movement.
- Ashen March: dry wind, loose debris and sparse, uneasy ambience.
- Combat audio must distinguish wind-up, impact, block, projectile, siege strike, retreat and objective feedback.
- Supernatural audio should be sparse; do not make every night sound like a horror trailer.
- Use original or properly licensed assets and maintain a credit record.

---

## 11. Scope and feature gate

Before approving a feature, answer these questions:

1. Which design pillar does it strengthen?
2. What player decision or action does it create?
3. Which existing system does it connect to?
4. What does the player see or hear that explains it?
5. What is its counterplay or recovery path?
6. What is the smallest playable slice?
7. What must be saved, migrated and tested?
8. How will it be evaluated in a rendered gameplay session?

Reject or defer a feature when it only adds more content, another resource icon, a larger stat value or an unconnected subsystem.

### Priority order

1. Finish and validate the existing core: jobs, construction, faction behavior and campaign readability.
2. Establish a distinct visual/audio identity through Phase 08.
3. Improve objective variety and consequential events.
4. Add survival/folklore mechanics only after their player-facing loops are defined.
5. Expand content breadth only after a complete campaign is understandable and replayable.

Do not add more biomes, factions, resources or buildings merely to increase a feature count.

---

## 12. QA acceptance checklist

A candidate release or major content update should be reviewed against the following:

- [ ] A new player can explain the basic goal after the first session.
- [ ] The player understands why the settlement is in danger and what can be done about it.
- [ ] Direct combat remains necessary and satisfying.
- [ ] Settlement management creates meaningful trade-offs without constant busywork.
- [ ] Local storage, supply routes and shipment behavior are understandable.
- [ ] Factions require different tactical responses, not just different damage values.
- [ ] Campaign objectives have genuinely different interactions.
- [ ] Folklore is present in regional behavior, environment and events—not only in lore text.
- [ ] Supernatural events are rare, telegraphed, consequential and counterable.
- [ ] Visual identity is recognizable at actual gameplay zoom and all supported resolutions.
- [ ] Audio communicates gameplay information as well as atmosphere.
- [ ] Classic remains approachable and retains its intended rules.
- [ ] Frontier difficulty and length have been tested in a full manual playthrough.
- [ ] Automated tests, rendered screenshots and human playtest notes are all available.

Passing CI is necessary for technical confidence. It is not proof that the game is fun, understandable or distinctive.

---

## 13. Relationship to the implementation roadmap

This bible defines the intended identity. ROADMAP_NEXT_LEVEL.md defines what is implemented, partial, deferred and next.

| Roadmap area | Design requirement |
|---|---|
| Phase 02 — Territory and supply | Logistics should create strategic choices without becoming repetitive manual labor |
| Phase 04 — Jobs | Hunter, Scout, Healer and Blacksmith must have distinct, visible outputs |
| Phase 05 — Buildings | Every facility needs a real dependency, decision or capability |
| Phase 06 — Factions | Every faction and archetype needs a counterable tactical identity |
| Phase 07 — Campaign | Objectives and regional consequences must differ mechanically |
| Phase 08 — Visual/audio identity | Establish the weathered medieval + restrained folklore language |
| Phase 09 — QA/release | Add manual campaign, readability, onboarding and target-hardware gates |
| Phase 10 — Viewport/UI | Protect the readable playfield and clear hierarchy at supported resolutions |

**Current status:** the direction in this document is approved as the target design, but its future mechanics and art requirements remain proposals until implemented and verified through the roadmap's acceptance gates.


## Gameplay direction update — 2026-11-07

The long-term product target is now explicit: Hold the Keep is a kingdom strategy game in which the player remains a directly controlled blue-mantled knight while also stewarding a settlement, assigning autonomous civilian work, developing territory and commanding a separate military force. Rival factions must function as competing kingdoms whose growth and attacks emerge from resource, construction, recruitment, information and territorial decisions.

The core strategic loop is **Establish → Produce → Develop → Explore → Expand → Compete → Defend or Conquer**. Classic's day/night survival pressure remains a useful onboarding and tactical pressure mode; it is not the ceiling for the campaign structure. Frontier's regional progression, strongholds, supply and discovery systems are the foundation for broader kingdom competition.

Design gate for new work: a feature must change a decision or consequence, connect at least two existing systems, be observable in the world and have a recovery/counterplay path. Do not add passive stat upgrades or content volume as substitutes for strategic depth. Current implementation gaps are tracked in [docs/GAMEPLAY_AUDIT.md](docs/GAMEPLAY_AUDIT.md); the current delivery slice is documented in [docs/plans/phase-11.2-faction-strategy.md](docs/plans/phase-11.2-faction-strategy.md).
