# Hold the Keep — Art Direction

**Authority:** This document governs new and replacement visual assets for the game.
**Status:** Stage A direction lock. The full visual overhaul is not complete.
**Engine:** Godot 4.7
**Platform target:** Windows and Linux desktop
**Rendering:** Top-down 2D, native-grid SVG pixel art

## 1. Identity

### Grim medieval folklore fantasy

Hold the Keep depicts a frontier kingdom whose practical systems are failing under military pressure. Its visual identity is weathered medieval material culture, defensive architecture, rural labor, regional customs and rare folklore intrusions.

The setting must look inhabited rather than decorated. Objects should show why they exist, who maintains them, what they are made from and how long they have endured. Settlements should communicate labor and defense. Military equipment should communicate resources, rank and tactical purpose. Ruins should communicate a former use before they communicate mystery.

The visual tone is severe but not uniformly miserable. Hearthland can contain harvest color, warm bread, patched clothing and maintained timber. Greenwood can contain dense life beneath a cold canopy. Fenlands should feel damp and difficult rather than poisonous neon. Ashen March should feel burned and depleted, not like a generic lava biome. Supernatural details are rare, specific and unsettling because they interrupt a grounded world.

This is not bright high fantasy, a cheerful village builder, anime medieval fantasy, generic mobile strategy art or a black-and-brown monochrome game.

### Design principles

1. **Silhouette before ornament.** A unit or building must be identifiable before its crest, trim or palette is considered.
2. **Construction before texture.** Show how a thing is assembled: seams, joints, straps, rivets, beams, stone courses, roof supports and tool wear.
3. **Material before color.** Timber, stone, wool, linen, leather, iron, steel, bone and vegetation need different cluster structures and highlight behavior.
4. **Function before decoration.** A farm must read as cultivated land; a forge as a working heat source; a barracks as a defended military workplace.
5. **Readable darkness.** Dark atmosphere comes from composition, palette relationships, occlusion and lighting. It does not come from lowering every value.
6. **Regional identity before faction recoloring.** Factions should differ through equipment construction, insignia shape, posture and material treatment, not only hue.
7. **Pixel decisions are authored at final resolution.** Do not paint large illustrations and shrink them into noisy pseudo-pixel art.
8. **Restraint is deliberate.** One well-placed landmark is stronger than random clutter across every tile.

## 2. Historical and visual grounding

The game uses a broad northern and western European late-medieval material vocabulary, mainly 13th–15th century, with regional variation. It is not a literal historical simulation and should not mix every century's equipment indiscriminately.

For common soldiers, layered textile protection and practical equipment are the baseline. Mail is expensive, labor-intensive and often used with padded textile; later plate elements augment rather than magically replace every earlier layer. A noble or veteran may have better protection, but a whole village must not look like a parade of fully plated knights.

Civilian clothing should use layered wool and linen garments, weather protection, belts, aprons, hoods, simple caps and repaired fabric. Garments need to suit the activity and climate. Avoid modern profession uniforms, identical tunics with recolored trims and ornamental armor on laborers.

Architecture should follow believable load and weather logic. Roofs need support and eaves. Timber structures need visible frame logic. Stone walls need courses, corners and openings. Defensive structures should have a clear approach, gate, wall walk or firing position. Improvised buildings may be crooked or patched, but should not look structurally random.

Reference links and their intended use are recorded in docs/ART_REFERENCE_BOARD.md.

## 3. Rendering contract

### Current integration dimensions

These are existing contracts to preserve unless a deliberate migration updates the generator, assets, texture slicing, render offsets and tests atomically.

| Asset family | Current sheet | Frame | Layout |
|---|---:|---:|---|
| Player | 528×84 | 24×28 | 22 columns × 3 directional rows |
| Villagers | 440×60 | 20×20 | 22 columns × 3 directional rows |
| Humanoid enemies | 440×60 | 20×20 | 22 columns × 3 directional rows |
| Direction rows | — | — | front, back, side; side is horizontally flipped |
| Animation clips | 22 frames | — | idle 2, walk 4, run 4, attack 4, work 4, hurt 1, death 3 |

The player uses a 24×28 frame and has a deliberately distinct blue-mantled design. It is hand-authored and is not owned by the legacy 20×20 humanoid generator.

Villager and enemy origins are the center of the bottom edge: the feet anchor the world position and Y-sort. Preserve this foot pivot. Do not vertically center characters or let their feet drift between frames.

### Pixel grid

- One SVG coordinate unit equals one authored logical pixel unless a documented asset-specific scale is required.
- Use integer coordinates and integer dimensions for pixel clusters.
- Use an explicit viewBox matching the intended sheet size.
- Use shape-rendering="crispEdges".
- Keep transparent backgrounds for sprites and props that require compositing.
- Avoid SVG filters, blur, soft shadows, fractional transforms and decorative gradients.
- Avoid raster embeds and external image dependencies in production sprite SVGs.
- Do not add indiscriminate one-pixel noise. A cluster must describe a plane, edge, seam, material grain, wear mark or readable feature.
- Do not force a black outline around every object. Use selective dark contours and internal value boundaries.
- Use a small number of coherent value steps per material. Highlights belong on the light-facing plane, not on every exposed edge.

### Detail density

At native gameplay scale, the main mass and interaction point must remain obvious. Secondary seams and equipment can disappear at 1× if the silhouette remains readable. No important gameplay distinction may rely on a single isolated pixel or a hue difference alone.

The default world light comes from the upper-left. Top-facing planes receive the clearest highlights; lower-right planes carry the deepest material shadows. Firelight is a localized warm light source, not a whole-screen orange filter.

## 4. Color language

Color is assigned by material and environment. The values below are starting anchors, not a rule that every asset must use every swatch.

### Core material palette

| Purpose | Shadow | Base | Light | Use |
|---|---|---|---|---|
| Soot / ink | #171B1D | #242A2B | #414849 | Deep recesses, outlines, smoke-darkened surfaces |
| Oak / timber | #453427 | #73543A | #A08056 | Beams, doors, handles, roof structure |
| Weathered plank | #4E483B | #756A53 | #9A8C6B | Exterior boards, fences, crates |
| Rough stone | #454C4D | #707A79 | #A0A69B | Walls, foundations, paving |
| Mortar | #4B4A43 | #777367 | #9A927F | Stone joints and repair seams |
| Iron | #30363D | #58616A | #89939B | Tools, hinges, rings and dark armor |
| Steel | #56616C | #9AA5AE | #D0D4D2 | Edges, helmets and fitted plate |
| Aged bronze | #59432C | #8D6C3F | #B99A61 | Buckles, rivets, fittings and heirlooms |
| Leather | #352B25 | #654831 | #92704D | Belts, boots, straps, scabbards |
| Wool | #373A35 | #66685D | #999887 | Cloaks, tunics and padded garments |
| Faded linen | #77715F | #B1A78F | #D6CBB0 | Shirts, bandages, sacks and pale cloth |
| Bone | #77705D | #B0A487 | #D8CCAC | Small ritual objects, animal remains |
| Peat / mud | #383A30 | #5F5944 | #817657 | Fen ground, trampled paths and wet soil |
| Dried blood | #492A2A | #793B36 | #A65345 | Wounds, restrained warning marks, old staining |
| Ash | #383938 | #686A65 | #A3A49A | Burned structures, cinder and ash deposits |

### Biome palettes

| Biome | Dominant family | Supporting accents | Avoid |
|---|---|---|---|
| Hearthland | muted pasture, rye, worn earth | faded linen, fence oak, cultivated green | bright lawn-green saturation |
| Greenwood | deep pine, moss, leaf litter | lichen, old timber, restrained berry tones | uniform green carpet |
| Highlands | shale, cold stone, sparse grass | iron ore, pale scree, lichen | flat grey monochrome |
| Fenlands | peat, wet olive, black water | reed straw, deadwood, pale mineral deposits | radioactive green or vivid teal |
| Ashen March | charcoal earth, ash and burned timber | oxide, old bone, faint ember red | lava fields and constant glowing cracks |
| Old Frontier | weathered versions of the surrounding region | collapsed stone, old roads, buried masonry | treating it as a sixth core biome |

Water is opaque and cold, with short broken reflection clusters. It must not read as a bright blue pool. Mud is a value-and-shape material, not a brown overlay on grass.

### Faction identifiers

Faction identity must survive grayscale conversion. Use silhouette, equipment profile, crest geometry and material condition as primary cues; palette is secondary.

| Faction | Primary | Secondary | Crest / signal | Construction language |
|---|---|---|---|---|
| Greenwood Raiders | #52674C | #89916C | #C0AE7B | asymmetrical leather, rough green wool, thorn and branch shapes |
| Iron Legion | #56616A | #A5ADB1 | #B69A66 | fitted iron, square plates, disciplined straps and chevrons |
| Fen Cult | #5D6348 | #8D9169 | #C0B48A | damp layers, reed bindings, irregular woven forms |
| Ashen Host | #514746 | #80685B | #A95743 | scorched metal, broken edges, ash-stained cloth and ember geometry |

Faction crests are small and restrained. Do not turn every unit into a walking flag. Keep a readable chest, shoulder or shield device.

### Threat and interaction cues

Threat uses a limited dried-crimson family, reinforced with shape and motion. Warnings, projectiles and attack arcs must be legible against every biome. Friendly selection, construction placement, ownership and supply state must each retain a distinct shape language. Color alone is never sufficient.

## 5. Material grammar

| Material | Shape and cluster behavior | Highlight / wear |
|---|---|---|
| Oak and timber | long directional grain groups; visible joints, pegs and plank breaks | pale upper edges, dark joints, worn corners |
| Rough stone | irregular block courses; varied block widths; interrupted mortar | small cool planes and chipped corners |
| Mortar | narrow recessed seams; never uniform bright grid lines | lower-value separation from adjacent stone |
| Leather | broad dark flexible shapes; straps and seams follow tension | rubbed edges, creases at bends, dull warm highlights |
| Linen | soft irregular folds; pale but dirty; layered hems | narrow fold highlights, stains and repaired patches |
| Wool | thick broad folds and heavier hems than linen | low-contrast highlights; frayed edges |
| Iron | dark compact shapes; rivets, rings, hinges and forged irregularities | hard short glints, rust at seams, no chrome shine |
| Steel | clearer planar facets and fitted edges | controlled cold highlight on a few facing planes |
| Bronze | warm metal, smaller hardware and cast fittings | muted yellow-brown edge highlights; tarnish in recesses |
| Bone | tapered, uneven organic forms | pale central planes, aged dark ends and cracks |
| Vegetation | directional leaf and branch clusters; species-specific masses | varied leaf planes, broken canopy edge |
| Mud | clumped, compressed and trampled shapes | dull wet glints only in small patches |
| Water | broad dark mass with broken horizontal reflections | high-value reflections are sparse and localized |
| Ash / burn | irregular soot fields, charred edges and exposed underlying material | pale ash on upper surfaces; ember is rare |

No material should be defined by a single flat color rectangle with random noise placed on top.

## 6. Character family

### Player

Preserve the recognizable blue-mantled knight already integrated into main. Its blue mantle is the primary recognition cue; fitted steel, dark underlayers, leather attachment points and restrained brass hardware establish rank without turning the character into polished parade armor.

Keep the 24×28 frame, 22-frame clip allocation and bottom-center foot anchor unless a full migration is validated. Front, back and side reads must all preserve mantle construction, helmet/head profile and equipment placement. The attack must visibly prepare, strike and recover. The feet remain planted through the combat contact frames.

### Villagers and professions

Every occupation needs a different body mass, garment construction, equipment placement and work posture. A held tool is supporting evidence, not the whole identity.

| Role | Silhouette and clothing construction | Signature equipment / posture |
|---|---|---|
| Woodcutter | broad shoulder line, weathered short outer layer, heavy boots and forearm protection | two-handed axe; weight shifts through the hips and shoulders |
| Miner | compact, forward-weighted frame, reinforced hood or cap, layered work tunic | pick, belt pouch and ore sack; overhead and low striking poses |
| Farmer | loose sleeves, practical apron, broad hat or hood and simple footwear | sickle, fork or seed basket; reach and stoop rather than combat stance |
| Builder | square tool-bearing silhouette, rolled sleeves, thick belt and patched workwear | hammer, mallet, wedge and tool roll; short measured impacts |
| Hunter | tapered travel layers, weather hood, light pack and close-fitting boots | bow, knife and game satchel; alert stance with clear ranged aim |
| Scout | narrow profile, short layered cloak, wrapped lower legs and minimal baggage | map case, light blade and field marker; low, mobile posture |
| Healer | long practical over-layer, sleeves protected from work, marked satchel and bandage rolls | field kit, pouch and staff or walking aid; deliberate non-combat posture |
| Blacksmith | broad forearms, heavy leather apron, thick boots and heat-worn sleeves | hammer, tongs and smithing gloves; shoulder-led hammer strike |
| Soldier | padded gambeson or mail-backed textile, shield or spear, practical helmet | defensive stance, weapon carried with real weight |
| Archer | lighter protective layers, shoulder clearance for the bow, visible quiver | bow draw, release and recovery; ranged silhouette reads at 1× |

Controlled variation may use hair, beard, garment condition, body width and small accessories. Variation must not hide profession identity or alter the role's combat/work read.

### Enemy silhouettes

- Bandit: uneven layered cloth, concealed face or hood, light weapon and asymmetric equipment.
- Wolf: low elongated quadruped with a clear head, spine and leg rhythm; not a humanoid with a wolf mask.
- Enemy soldier: squared shoulders, fitted protection, controlled shield/weapon silhouette.
- Archer: long-range weapon profile, visible bow and quiver, narrow equipment mass.
- Brute: wider torso, larger shoulder and head mass, slower weapon silhouette; never a scaled-up ordinary soldier alone.
- King: tallest humanoid profile, deliberate heraldic mantle and rare high-quality armor construction. Crown and palette are not enough.
- Scout: narrow outline, reduced mass and travel equipment.
- Shieldbearer: shield dominates one side and creates a recognizable defensive profile.
- Saboteur: compact load-bearing equipment, tools and concealed approach.
- War Shaman: regional ritual clothing, field materials and a support tool; no generic glowing wizard robe.
- Siege Engine: timber frame, bracing, wheels or hauling structure appropriate to its existing implementation; it must read as a machine, not a large humanoid.
- Beast Rider: mounted silhouette must clearly separate animal mass, rider and tack.

Preserve the current gameplay archetype IDs and behavior. Artwork must not silently change unit scale, collision size, reach, hit timing, ownership or AI.

### Faction equipment

Faction equipment is modular only where the component can be attached without hiding the base archetype. Greenwood uses rough leather, weatherproof cloth, branch/thorn shapes and practical light armor. Iron Legion uses fitted metal, repeated plate construction and consistent military straps. Fen Cult uses damp, repaired, reed-bound materials and irregular organic shapes. Ashen Host uses charred cloth, damaged metal and heavy, severe profiles.

The same archetype must remain recognizable when faction equipment is applied. Faction and archetype overlays must be checked together in all three directions.

## 7. Buildings and settlement architecture

The Keep is the settlement's visual anchor. It needs a dominant mass, defensible approach, layered wall height, clear gate, tower hierarchy and a recognizable banner. It must not become a generic castle icon enlarged.

A structure is designed from its footprint outward. Every building needs a recognizable roof or upper structure, wall material, support logic, entrance, functional equipment, ground contact and a consistent shadow. Do not use one generic house silhouette with recolored roofs.

| Structure | Required functional read |
|---|---|
| Keep | stone stronghold, gate, towers, defended upper edge |
| House | domestic roof, entrance, small windows and inhabited yard |
| Wooden Wall | timber construction, bracing, stakes and defended edge |
| Stone Wall | stone courses, capstones and defensible height |
| Tower | vertical lookout, openings, parapet and access |
| Outpost | small defended position with sightline and supply purpose |
| Storage | weather-protected store with loading access, crates or sacks |
| Farm | rows, plots, crop variation, boundary and working access |
| Granary | raised/protected food storage and ventilation |
| Lumber Camp | felled logs, sawing/work area and timber stacks |
| Quarry | exposed rock face, spoil piles and extraction access |
| Barracks | military accommodation, weapon storage and defensive access |
| Archery Range | targets, practice lane, bow storage and open firing space |
| Hunting Lodge | field gear, hides or game provisions and a woodland edge |
| Scout Post | elevated sightline, map/marker equipment and a light footprint |
| Infirmary | sheltered care space, clean cloth, beds or treatment supplies |
| Forge | chimney, hearth, anvil, fuel and metal work zone |
| Road / Bridge | clear connection, surface treatment and terrain-aware edge |

Damage should remove or crack material in a way that respects construction: missing planks, broken parapets, fallen roof sections, fractured stone corners, smoke and exposed structural beams. A universal crack overlay is not enough.

Construction visuals must derive from actual build state. A site should show a logical sequence of foundation, posts, frame, roofing and completion only where the construction system exposes those real stages. Never invent progress with an unrelated timer.

## 8. Environment and biomes

Terrain is the readable base layer. Decoration must never obscure the ground type, resource node, unit feet, collision boundary or interaction target.

- **Hearthland:** cultivated fields, worn lanes, pasture edges, fences, ditches, stacked firewood and maintained boundary stones.
- **Greenwood:** dense canopy, roots, ferns, fallen trunks, wet needles, old markers and selective light gaps.
- **Highlands:** fractured shale, exposed mineral seams, sparse grass, scree, stone cairns and defensive ridges.
- **Fenlands:** peat, shallow pools, reeds, deadwood, submerged tracks, damp posts and abandoned low structures.
- **Ashen March:** cinder, charred roots, burned fencing, ruin foundations, battlefield remains and isolated ember traces.
- **Old Frontier:** ruin-dense subregion treatment derived from its surrounding biome; not a sixth core biome.

Resource nodes need a harvestable silhouette and distinct depleted state. Tree variants must change branch structure and canopy shape, not only hue. Ore nodes must expose veins or broken rock. Wildlife uses a species-specific body silhouette and readable movement footprint.

Prop density is controlled by use and place. A cart belongs on a road, a woodpile near a worksite, a shrine at a boundary or path, and abandoned arms on a battlefield or ruin. Empty space is part of composition.

## 9. Combat effects and moment-to-moment feedback

Effects are short, directional and tied to real gameplay events. They should explain preparation, release, contact, block, stagger, movement and consequence.

- Melee: locked attack direction, restrained arc, contact cluster and short recovery cue.
- Heavy impact: larger contact mass, grounded dust and clear enemy recoil.
- Projectile: visible release, consistent travel direction and impact point.
- Shield block: compact metal/wood contact mark and directional response.
- Dash: short displacement evidence, not a trail that hides the actor.
- Cleave and Rally: distinct shape grammar, distinct timing and restrained palette.
- Construction/work: contact only at the real tool-impact frame.
- Building damage/destruction: material-specific breakage and debris limits.
- Supernatural: rare and visually unlike ordinary fire, metal or magic particles.

The actual combat resolver remains authoritative. Artwork must never imply damage before a hit is resolved or show an impact after an attack is cancelled.

## 10. UI and iconography

Icons use one-pixel cluster logic, consistent perspective, silhouette-first construction and the same material vocabulary as the world. Resources, professions, structures, factions, abilities, objectives and state indicators each need their own compact symbolic grammar.

No emoji replacement art, unrelated icon library, excessive ornament, gradients, soft shadows or tiny illegible linework. Icons must be evaluated at their actual UI size and in grayscale.

## 11. SVG source and generator ownership

SVG is the editable source for production pixel art. Generated assets must be reproducible; hand-authored assets must not be overwritten by a general-purpose generator.

The existing tools/gen_assets.py is a legacy procedural renderer, not an unrestricted authority over every sprite. It uses a common 16×16 humanoid construction and overlays profession/faction variations. That is not sufficient as the final character art system. Do not add new character classes by changing only Look colors, hats or held tools.

Before a generator writes an asset, its ownership must be explicit. A hand-authored asset needs to be excluded or protected. A generator-owned asset needs its source definition and rendered SVG updated together. Never update only the rendered output and leave generation stale.

A generator migration must preserve:
- stable asset paths where possible;
- exact frame slicing and directional row order;
- character foot pivots and render offsets;
- sprite resource references;
- deterministic output;
- collision and gameplay footprints;
- all existing SVG import and regression coverage.

The generator may reuse material palettes, pixel-cluster helpers, animation timing and shared low-level drawing operations. It must not force every character into one anatomy or silhouette template.

## 12. Lighting and atmosphere

Use upper-left daylight as the shared world light direction. At dusk, reduce saturation and cool the ground while retaining a clear value hierarchy. At night, preserve unit and building silhouettes; use local window, torch and firelight as small warm pools. Underground/ruin scenes use confined pools and deep occlusion. Supernatural light is rare, localized and tied to a specific threat.

Do not place a global dark overlay on top of weak art. Do not tint every object the same brown or blue. Material and value structure must do the work.

## 13. Acceptance gates

An asset is not complete because an SVG file exists.

### Artistic
- Silhouette reads at native gameplay scale.
- Role, building function or biome is identifiable without relying only on color.
- Materials use distinct cluster and value behavior.
- Detail density is controlled; no random pixel noise.
- The asset belongs to the same world and has a deliberate construction logic.

### Character and animation
- All 3 directional rows read correctly.
- Anatomy and equipment remain consistent across frames.
- Walk/run have alternating leg and arm motion with ground contact.
- Attack contains anticipation, strike, contact and recovery.
- Work motion matches the occupation and its actual event timing.
- Hurt and death preserve the foot origin and final orientation.
- Character identity survives grayscale and faction equipment overlays.

### Integration
- SVG parses and imports under Godot 4.7.
- Texture dimensions match the frame contract.
- No sprite slicing, pivot, Y-sort or offset regression.
- No missing resources or accidental collision changes.
- No draw-call or particle-cap regression.
- Generator output is deterministic and respects ownership.

### Evidence
- Review sheets for every role, enemy, faction/archetype combination, building, biome, resource, VFX family and icon family.
- Actual Godot screenshots at 1280×720, 1600×900 and 1920×1080.
- Review native logical scale and 2× pixel output.
- Cover day, dusk, night, fog, dense settlement, construction, combat and strategic-map contexts.
- Keep the full Godot 4.7 regression matrix green.
- Record target-PC performance separately from CI timing.
- Keep human desktop playtest review open until it actually occurs.

## 14. Production order

1. Stage A: inventory, references, art direction, ownership and scale contracts.
2. Stage B: player, civilian and enemy character family; full animation review.
3. Stage C: faction equipment and combined faction/archetype review.
4. Stage D: architecture and every shipped building, including damage and construction states.
5. Stage E: terrain, biome props, resources, wildlife and regional landmarks.
6. Stage F: combat effects and iconography.
7. Stage G: integration and multi-resolution rendered review.
8. Stage H: defect pass, performance check and final human acceptance.

No stage may mark the complete overhaul finished while a major asset group remains generic, inconsistent or unreviewed.
