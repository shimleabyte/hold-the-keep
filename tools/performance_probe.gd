extends SceneTree
## Manual performance probe for Classic, Frontier and Frontier Expedition.
## Run locally with:
##   godot --path . --script res://tools/performance_probe.gd
## Run windowed at a fixed resolution; headless runs cannot provide meaningful draw-call counts.
## This is diagnostic tooling, not a pass/fail test. Compare profiles on the same machine.

const PROFILES: Array[String] = ["classic", "frontier", "frontier_expedition"]
const WARMUP_FRAMES := 30
const IDLE_SAMPLE_FRAMES := 120
const WAVE_SAMPLE_FRAMES := 180
const SYSTEM_REPEATS := 3

var _cases: Array[Dictionary] = []


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    await process_frame
    OS.set_environment("HTK_AUTO_START_GAME", "1")
    var config = root.get_node("WorldConfig")
    var inventory = root.get_node("Inventory")
    var clock = root.get_node("GameClock")
    var tech = root.get_node("Tech")
    var save_system = root.get_node("SaveSystem")

    for profile_id in PROFILES:
        config.apply_profile(profile_id)
        inventory.reset()
        clock.reset()
        tech.reset()
        save_system.pending.clear()
        paused = false

        var generation_started := Time.get_ticks_usec()
        var main = load("res://scenes/main.tscn").instantiate()
        root.add_child(main)
        current_scene = main
        var generation_ms := float(Time.get_ticks_usec() - generation_started) / 1000.0

        for _frame in WARMUP_FRAMES:
            await process_frame

        var system_timings := {
            "navigation_rebuild": _measure_system(main.nav, "rebuild"),
            "flow_field_rebuild": _measure_system(main.flow, "rebuild"),
            "territory_rebuild": _measure_system(main.territory, "rebuild"),
            "fog_source_scan": _measure_system(main.fog, "_scan_sources")
        }

        var idle_samples := await _capture_frames(IDLE_SAMPLE_FRAMES)
        clock.day = 6
        clock.time_of_day = GameClock.NIGHT_START
        clock.is_night = true
        main.spawner.start_wave(6)
        var wave_samples := await _capture_frames(WAVE_SAMPLE_FRAMES)

        _cases.append({
            "profile": profile_id,
            "map_size": config.map_size,
            "map_cells": config.map_cells,
            "world_creation_ms": generation_ms,
            "system_timings_ms": system_timings,
            "scene_counts": _scene_counts(main),
            "idle_frame_samples": _summarize_frames(idle_samples),
            "active_wave_frame_samples": _summarize_frames(wave_samples)
        })

        main.queue_free()
        await process_frame
        await process_frame

    OS.set_environment("HTK_AUTO_START_GAME", "0")
    var report := {
        "engine": Engine.get_version_info(),
        "warmup_frames": WARMUP_FRAMES,
        "idle_sample_frames": IDLE_SAMPLE_FRAMES,
        "active_wave_sample_frames": WAVE_SAMPLE_FRAMES,
        "system_timing_repeats": SYSTEM_REPEATS,
        "cases": _cases
    }
    var output := JSON.stringify(report, "\t")
    var file := FileAccess.open("user://performance_probe.json", FileAccess.WRITE)
    if file == null:
        push_error("Performance probe: could not write user://performance_probe.json")
    else:
        file.store_string(output)
        file.close()
    print(output)
    quit(0)


func _measure_system(target: Object, method_name: String) -> Dictionary:
    var samples: Array[float] = []
    for _repeat in SYSTEM_REPEATS:
        var started := Time.get_ticks_usec()
        target.call(method_name)
        samples.append(float(Time.get_ticks_usec() - started) / 1000.0)
    samples.sort()
    var total := 0.0
    for sample in samples:
        total += sample
    return {
        "average": total / float(samples.size()),
        "max": samples[samples.size() - 1],
        "min": samples[0]
    }


func _capture_frames(count: int) -> Array[Dictionary]:
    var samples: Array[Dictionary] = []
    for _frame in count:
        await process_frame
        samples.append({
            "process_ms": float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0,
            "physics_ms": float(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0,
            "draw_calls": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
            "render_objects": int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
            "physics_2d_objects": int(Performance.get_monitor(Performance.PHYSICS_2D_ACTIVE_OBJECTS)),
            "fps": Engine.get_frames_per_second()
        })
    return samples


func _summarize_frames(samples: Array[Dictionary]) -> Dictionary:
    var process_times: Array[float] = []
    var physics_times: Array[float] = []
    var draw_calls: Array[int] = []
    var fps_values: Array[int] = []
    for sample in samples:
        process_times.append(float(sample["process_ms"]))
        physics_times.append(float(sample["physics_ms"]))
        draw_calls.append(int(sample["draw_calls"]))
        fps_values.append(int(sample["fps"]))
    process_times.sort()
    physics_times.sort()
    draw_calls.sort()
    fps_values.sort()
    return {
        "process_ms_avg": _average(process_times),
        "process_ms_p95": _percentile(process_times, 0.95),
        "physics_ms_avg": _average(physics_times),
        "physics_ms_p95": _percentile(physics_times, 0.95),
        "draw_calls_p95": _percentile_int(draw_calls, 0.95),
        "fps_median": _percentile_int(fps_values, 0.50)
    }


func _scene_counts(main: Node) -> Dictionary:
    var resource_nodes := get_nodes_in_group("resource_nodes")
    var processing_resources := 0
    for resource in resource_nodes:
        if is_instance_valid(resource) and resource.is_processing():
            processing_resources += 1
    return {
        "scene_nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
        "active_2d_physics_objects": int(Performance.get_monitor(Performance.PHYSICS_2D_ACTIVE_OBJECTS)),
        "resource_nodes": resource_nodes.size(),
        "resource_nodes_processing": processing_resources,
        "frontier_decoration_records": main.world.generated_decoration_layout.size(),
        "frontier_decoration_batch_nodes": get_nodes_in_group("frontier_decoration_batches").size(),
        "world_entity_children": main.world.entities.get_child_count(),
        "fog_chunks": main.fog._fog_chunks.size(),
        "villagers": get_nodes_in_group("villagers").size(),
        "enemies": get_nodes_in_group("enemies").size(),
        "buildings": get_nodes_in_group("buildings").size(),
        "tilemap_cells": main.world._layer.get_used_cells().size()
    }


func _average(values: Array[float]) -> float:
    if values.is_empty():
        return 0.0
    var total := 0.0
    for value in values:
        total += value
    return total / float(values.size())


func _percentile(values: Array[float], ratio: float) -> float:
    if values.is_empty():
        return 0.0
    var index := clampi(roundi(float(values.size() - 1) * ratio), 0, values.size() - 1)
    return values[index]


func _percentile_int(values: Array[int], ratio: float) -> int:
    if values.is_empty():
        return 0
    var index := clampi(roundi(float(values.size() - 1) * ratio), 0, values.size() - 1)
    return values[index]
