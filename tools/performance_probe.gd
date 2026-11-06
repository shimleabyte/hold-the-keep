extends SceneTree
## Manual performance probe for Classic, Frontier and Frontier Expedition.
## Run locally with:
##   godot --path . --script res://tools/performance_probe.gd
## Windowed runs at a fixed resolution include render counters. Headless runs still measure CPU/frame
## timing, but draw-call and render-object values are marked unavailable.
## This is diagnostic tooling, not a pass/fail test. Compare profiles on the same machine.

const PROFILES: Array[String] = ["classic", "frontier", "frontier_expedition"]
const WARMUP_FRAMES := 30
const IDLE_SAMPLE_FRAMES := 120
const WAVE_SAMPLE_FRAMES := 180
const SYSTEM_REPEATS := 3
# Keep this value aligned with GameClock.NIGHT_START. Avoid a static autoload
# reference here: --script runs this SceneTree script outside the normal main
# scene parse context, where static autoload symbol resolution can fail.
const NIGHT_START := 0.6

var _cases: Array[Dictionary] = []
var _world_config


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    await process_frame
    OS.set_environment("HTK_AUTO_START_GAME", "1")
    var config = root.get_node("WorldConfig")
    _world_config = config
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
        await _wait_for_flow_snapshot(main.flow)

        var system_timings := {
            "navigation_rebuild": _measure_system(main.nav, "rebuild"),
            "flow_field_rebuild": await _measure_flow_rebuild(main.flow),
            "territory_rebuild": _measure_system(main.territory, "rebuild"),
            "village_job_assignment": _measure_system(main.village, "assign_jobs"),
            "fog_source_scan": _measure_system(main.fog, "_scan_sources")
        }
        var building_completion_timing: Dictionary = await _measure_building_completion(main)

        var idle_samples := await _capture_frames(IDLE_SAMPLE_FRAMES)
        clock.day = 6
        clock.time_of_day = NIGHT_START
        clock.is_night = true
        main.spawner.start_wave(6)
        var wave_samples := await _capture_frames(WAVE_SAMPLE_FRAMES)

        _cases.append({
            "profile": profile_id,
            "map_size": config.map_size,
            "map_cells": config.map_cells,
            "world_creation_ms": generation_ms,
            "system_timings_ms": system_timings,
            "flow_field_rebuild_budget_usec": main.flow.rebuild_budget_usec,
            "building_completion_transition": building_completion_timing,
            "scene_counts": _scene_counts(main),
            "idle_frame_samples": _summarize_frames(idle_samples),
            "active_wave_frame_samples": _summarize_frames(wave_samples)
        })

        main.queue_free()
        await process_frame
        await process_frame

    OS.set_environment("HTK_AUTO_START_GAME", "0")
    var headless := DisplayServer.get_name().to_lower() == "headless"
    var report := {
        "engine": Engine.get_version_info(),
        "render_mode": "headless" if headless else "windowed",
        "warmup_frames": WARMUP_FRAMES,
        "idle_sample_frames": IDLE_SAMPLE_FRAMES,
        "active_wave_sample_frames": WAVE_SAMPLE_FRAMES,
        "system_timing_repeats": SYSTEM_REPEATS,
        "cases": _cases
    }
    var output := JSON.stringify(report, "\\t")
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



func _wait_for_flow_snapshot(flow_field: Node, maximum_frames := 600) -> int:
    var waited := 0
    while not flow_field.is_current():
        await process_frame
        waited += 1
        if waited >= maximum_frames:
            push_error("Performance probe: FlowField did not publish a current snapshot")
            return waited
    return waited


func _measure_flow_rebuild(flow_field: Node) -> Dictionary:
    var schedule_call_ms: Array[float] = []
    var completion_ms: Array[float] = []
    var completion_frames: Array[int] = []
    var worst_frame_ms: Array[float] = []

    for _repeat in SYSTEM_REPEATS:
        var previous_version: int = int(flow_field.version)
        var started := Time.get_ticks_usec()
        flow_field.rebuild()
        schedule_call_ms.append(float(Time.get_ticks_usec() - started) / 1000.0)
        var waited_frames := 0
        var peak_frame_ms := 0.0

        while not flow_field.is_current() or int(flow_field.version) <= previous_version:
            var frame_started := Time.get_ticks_usec()
            await process_frame
            var frame_ms := float(Time.get_ticks_usec() - frame_started) / 1000.0
            peak_frame_ms = maxf(peak_frame_ms, frame_ms)
            waited_frames += 1
            if waited_frames >= 600:
                push_error("Performance probe: FlowField rebuild timed out")
                break

        completion_ms.append(float(Time.get_ticks_usec() - started) / 1000.0)
        completion_frames.append(waited_frames)
        worst_frame_ms.append(peak_frame_ms)

    return {
        "schedule_call_ms_avg": _average(schedule_call_ms),
        "schedule_call_ms_max": _max_float(schedule_call_ms),
        "completion_ms_avg": _average(completion_ms),
        "completion_ms_max": _max_float(completion_ms),
        "completion_frames_avg": _average_int(completion_frames),
        "completion_frames_max": _max_int(completion_frames),
        "peak_frame_wall_ms_max": _max_float(worst_frame_ms)
    }


func _measure_building_completion(main: Node) -> Dictionary:
    var keep = null
    for depot in get_nodes_in_group("depots"):
        if is_instance_valid(depot) and String(depot.id) == "keep":
            keep = depot
            break
    if keep == null:
        return {"error": "Keep not found"}

    var probe_cell := _find_build_probe_cell(main, keep.cell)
    if probe_cell.x < 0:
        return {"error": "No free construction probe cell"}
    var site = main.build.create_construction_site("wall", probe_cell, keep.cell)
    await _wait_for_flow_snapshot(main.flow)
    var previous_version: int = int(main.flow.version)
    var started := Time.get_ticks_usec()
    site._finish()
    var completion_call_ms := float(Time.get_ticks_usec() - started) / 1000.0

    var settle_started := Time.get_ticks_usec()
    var settle_frames := 0
    var peak_frame_ms := 0.0
    while not main.flow.is_current() or int(main.flow.version) <= previous_version:
        var frame_started := Time.get_ticks_usec()
        await process_frame
        var frame_ms := float(Time.get_ticks_usec() - frame_started) / 1000.0
        peak_frame_ms = maxf(peak_frame_ms, frame_ms)
        settle_frames += 1
        if settle_frames >= 600:
            push_error("Performance probe: building-completion FlowField did not settle")
            break

    return {
        "synchronous_transition_call_ms": completion_call_ms,
        "flow_settle_ms": float(Time.get_ticks_usec() - settle_started) / 1000.0,
        "flow_settle_frames": settle_frames,
        "flow_peak_frame_wall_ms": peak_frame_ms
    }


func _find_build_probe_cell(main: Node, origin: Vector2i) -> Vector2i:
    for radius in range(3, 20):
        for y in range(-radius, radius + 1):
            for x in range(-radius, radius + 1):
                if maxi(absi(x), absi(y)) != radius:
                    continue
                var cell := origin + Vector2i(x, y)
                if not _world_config.is_valid_cell(cell):
                    continue
                if not main.world.is_buildable(cell) or main.world.occupied.has(cell):
                    continue
                return cell
    return Vector2i(-1, -1)


func _max_float(values: Array[float]) -> float:
    var maximum := 0.0
    for value in values:
        maximum = maxf(maximum, value)
    return maximum


func _average_int(values: Array[int]) -> float:
    if values.is_empty():
        return 0.0
    var total := 0
    for value in values:
        total += value
    return float(total) / float(values.size())


func _max_int(values: Array[int]) -> int:
    var maximum := 0
    for value in values:
        maximum = maxi(maximum, value)
    return maximum

func _capture_frames(count: int) -> Array[Dictionary]:
    var samples: Array[Dictionary] = []
    var has_render_counters := DisplayServer.get_name().to_lower() != "headless"
    for _frame in count:
        await process_frame
        samples.append({
            "process_ms": float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0,
            "physics_ms": float(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0,
            "draw_calls": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)) if has_render_counters else -1,
            "render_objects": int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)) if has_render_counters else -1,
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
