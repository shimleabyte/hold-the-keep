extends SceneTree
## Regression checks for centralized world profile settings and tile indexing.


func _initialize() -> void:
    var world_config = root.get_node("WorldConfig")
    var game_clock = root.get_node("GameClock")
    var save_system = root.get_node("SaveSystem")
    assert(world_config.profile_id == "classic", "The shipped project must keep Classic as its default profile")
    assert(world_config.map_size == 128, "Classic must now provide a 128x128 playable homeland")
    assert(world_config.tile_size == 16, "The world tile size must remain 16 pixels")
    assert(world_config.map_cells == 128 * 128, "Map cell count must match the configured dimensions")
    assert(world_config.starting_claim_radius == 14.0, "Classic must provide a proportionally larger starting claim")
    assert(world_config.safe_radius == 10.0, "Classic must provide a larger spawn clearing")
    assert(world_config.world_seed == 1337, "The default world seed must remain deterministic")
    assert(world_config.world_pixel_size() == Vector2i(2048, 2048),
        "World pixel dimensions must derive from tile count and tile size")

    var sample := Vector2i(17, 29)
    var index: int = world_config.cell_index(sample)
    assert(index == sample.y * world_config.map_size + sample.x,
        "Tile coordinates must map to a stable row-major index")
    assert(world_config.cell_from_index(index) == sample,
        "Tile index conversion must round-trip")
    assert(world_config.cell_index(Vector2i(-1, 0)) == -1,
        "Out-of-bounds cells must not receive valid indices")
    assert(world_config.cell_from_index(world_config.map_cells) == Vector2i(-1, -1),
        "Out-of-bounds indices must not map to valid cells")

    var frontier: Dictionary = world_config.profile_definition("frontier")
    assert(int(frontier.get("map_size", 0)) == 192,
        "The Frontier profile must define a 192x192 world")
    assert(is_equal_approx(float(frontier.get("starting_claim_radius", 0.0)), 18.0),
        "The larger Frontier must use an 18-tile Keep claim")
    assert(is_equal_approx(float(frontier.get("safe_radius", 0.0)), 14.0),
        "Frontier must provide an appropriately larger starting clearing")
    assert(int(frontier.get("iron_veins", 0)) == 72,
        "Frontier iron supply must scale with its expanded map area")

    var expedition: Dictionary = world_config.profile_definition("frontier_expedition")
    assert(int(expedition.get("map_size", 0)) == 256,
        "Frontier Expedition must define a 256x256 world")
    assert(int(frontier.get("map_size", 0)) == 192,
        "The current Frontier profile must remain 192x192")
    assert(int(expedition.get("expedition_core_size", 0)) == 160,
        "The Expedition profile must provide a larger 160x160 starting heartland")
    assert(int(expedition.get("iron_veins", 0)) == 128,
        "Expedition iron supply must scale to the largest map area")
    assert(world_config.is_frontier_profile("frontier_expedition")
        and not world_config.is_frontier_profile("classic"),
        "Both Frontier profiles must use shared campaign systems without changing Classic")

    OS.set_environment("HTK_AUTO_START_GAME", "0")
    var main = load("res://scenes/main.tscn").instantiate()
    root.add_child(main)
    current_scene = main
    await process_frame
    await process_frame
    assert(main.world == null,
        "Launching the project must show the title screen without constructing a gameplay world")
    assert(main.get_node_or_null("TitleScreen") != null,
        "The main scene must present the title screen before gameplay")
    var title_screen = main.get_node("TitleScreen")
    assert(title_screen.find_child("ContinueButton", true, false) != null,
        "The title screen must expose a Continue action")
    assert(title_screen.find_child("SettingsButton", true, false) != null,
        "The title screen must expose Settings")
    var title_scroll = title_screen.find_child("TitleContentScroll", true, false)
    assert(title_scroll is ScrollContainer,
        "The title screen's central content must remain scrollable at compact viewport sizes")
    var campaign_options = title_screen.find_child("CampaignOptions", true, false)
    assert(campaign_options is HFlowContainer,
        "Campaign choices must wrap instead of overflowing horizontally")
    assert(campaign_options.get_child_count() == 3,
        "The title screen must expose Classic, Frontier and Frontier: Expedition")
    var expedition_card: PanelContainer = campaign_options.get_node_or_null("CampaignCard_frontier_expedition") as PanelContainer
    assert(expedition_card is PanelContainer,
        "Frontier: Expedition must have its own campaign card")
    var expedition_button: Button = expedition_card.find_child("Select_frontier_expedition", true, false) as Button
    assert(expedition_button is Button
        and expedition_button.text == "FRONTIER: EXPEDITION"
        and String(expedition_button.get_meta("campaign_profile_id", "")) == "frontier_expedition",
        "The Frontier: Expedition button must select the 256x256 Expedition profile")
    var campaign_scroll_rect: Rect2 = title_scroll.get_global_rect()
    assert(campaign_scroll_rect.encloses(expedition_button.get_global_rect()),
        "Frontier: Expedition must be visible without scrolling on the default title viewport")
    assert(title_screen.get_node_or_null("SettingsPanel") != null,
        "The title screen must provide an in-menu settings panel")
    main._start_campaign("classic")
    await process_frame
    await process_frame
    await process_frame
    game_clock.set_process(false)
    assert(main.world != null,
        "Selecting Classic from the title screen must initialize the gameplay world")
    assert(main.fog != null and main.fog._fog_chunks.size() == 64,
        "A 128x128 Classic world must use sixty-four 16x16 fog chunks")

    var hud = main.get_tree().get_first_node_in_group("hud")
    assert(hud != null, "Gameplay must create its HUD")
    assert(hud._map_button.icon != null and hud._map_button.label.is_empty(),
        "The world-map control must use an icon without a permanent text label")
    assert(hud._jobs_button.icon != null and hud._jobs_button.label.is_empty(),
        "The jobs control must use an icon without a permanent text label")
    assert(hud._tech_btn.icon != null,
        "Research must remain discoverable through its icon")
    assert(hud._map_button.focus_mode == Control.FOCUS_ALL
        and hud._jobs_button.focus_mode == Control.FOCUS_ALL
        and hud._tech_btn.focus_mode == Control.FOCUS_ALL,
        "Icon-only navigation controls must remain keyboard/controller focusable")
    assert(not hud._hp_text.visible and not hud._keep_text.visible,
        "Persistent vitals must use bars and icons rather than numeric text")
    assert(not hud._build_left_hint.visible and not hud._build_right_hint.visible,
        "Keyboard instruction text must not occupy permanent gameplay HUD space")
    assert(hud._combat_bar.ability_icons.size() == 3,
        "Combat abilities must be represented by distinct icons")
    assert(not hud._stage_label.visible and not hud._research_name.visible,
        "Stage and research names must move to contextual tooltips")
    assert(not hud._slots.is_empty(),
        "The icon-first build bar must still expose available building choices")
    for building_id in hud._slots:
        var build_slot = hud._slots[building_id]
        assert(build_slot.icon != null and not build_slot.tooltip_text.is_empty(),
            "Every icon-only building slot must retain its name, shortcut and cost in a tooltip")

    var current_save: Dictionary = save_system.collect(main)
    assert(current_save["world"]["profile"] == "classic",
        "New saves must record the active world profile")
    assert(current_save["world"]["map_size"] == 128,
        "New Classic saves must record the enlarged map dimensions")
    assert(save_system._valid_save(current_save),
        "A current save must validate against its matching enlarged world configuration")

    var legacy_save := current_save.duplicate(true)
    legacy_save.erase("world")
    legacy_save["quota"].erase("builder")
    legacy_save["quota"].erase("hunter")
    legacy_save["quota"].erase("scout")
    legacy_save["quota"].erase("healer")
    legacy_save["quota"].erase("blacksmith")
    legacy_save.erase("job_priority")
    for villager in legacy_save["villagers"]:
        villager.erase("weapon_equipped")
        villager.erase("armor_equipped")
        if String(villager.get("job", "")) in ["hunter", "scout", "healer", "blacksmith"]:
            villager["job"] = ""
        villager.erase("occupation")
        villager.erase("military_specialization")
    var legacy_resources: Array = []
    for resource in legacy_save["resources"]:
        if String(resource.get("kind", "")) != "food":
            legacy_resources.append(resource)
    legacy_save["resources"] = legacy_resources
    for building_index in range(legacy_save["buildings"].size() - 1, -1, -1):
        if String(legacy_save["buildings"][building_index].get("id", "")) in ["hunting_lodge", "scout_post", "infirmary", "forge"]:
            legacy_save["buildings"].remove_at(building_index)
    assert(world_config.is_supported_map_size("classic", 64)
        and world_config.is_supported_map_size("frontier", 128)
        and world_config.is_supported_map_size("frontier_expedition", 192),
        "Every previously shipped map size must remain an explicitly supported save format")

    var incompatible_save := current_save.duplicate(true)
    incompatible_save["world"]["profile"] = "frontier"
    incompatible_save["world"]["map_size"] = 192
    assert(not save_system._valid_save(incompatible_save),
        "A save from another profile or map size must be rejected")

    assert(world_config.apply_saved_profile("classic", 64)
        and world_config.map_size == 64
        and world_config.safe_radius == 8.0,
        "Continuing an original Classic save must restore its original 64x64 generation settings")
    assert(world_config.apply_saved_profile("frontier", 128)
        and world_config.map_size == 128
        and world_config.starting_claim_radius == 15.0,
        "Continuing an original Frontier save must restore its original 128x128 generation settings")
    assert(world_config.apply_saved_profile("frontier_expedition", 192)
        and world_config.map_size == 192
        and int(world_config.profile_definition("frontier_expedition")["expedition_core_size"]) == 128,
        "Continuing an original Expedition save must restore its 192x192 map and 128x128 heartland")
    assert(world_config.apply_saved_profile("classic", 64),
        "The legacy Classic profile must remain restorable after the other historical profiles are checked")
    assert(not save_system._valid_save(current_save),
        "A new 128x128 Classic save must not load into the historical 64x64 runtime")
    assert(save_system._valid_save(current_save, false),
        "A structurally valid new Classic save must remain retainable as a profile-switch backup")

    assert(world_config.apply_profile("frontier"),
        "The enlarged Frontier profile must remain selectable")
    assert(not save_system._valid_save(current_save),
        "A Classic save must not load into Frontier")
    assert(save_system._valid_save(current_save, false),
        "A valid Classic save must remain eligible for a cross-profile backup")
    assert(world_config.apply_profile("classic"),
        "Tests must restore the default enlarged Classic profile")

    print("PASS: world profiles, tile indexing, and save profile compatibility")
    quit()
