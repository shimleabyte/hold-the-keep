extends SceneTree
## Live hardware acceptance probe for low-end desktop targets.
## Run with:
##   godot --path . --script res://tools/hardware_acceptance_probe.gd
## The game opens in a window. Play normally for 20 minutes.
## Unlike performance_probe.gd, this leaves all autonomous gameplay systems enabled.

const DURATION_SECONDS := 1200.0
const STATUS_INTERVAL_SECONDS := 60.0

var _frame_wall_ms: Array[float] = []
var _process_ms: Array[float] = []
var _physics_ms: Array[float] = []
var _memory_bytes: Array[float] = []
var _node_counts: Array[float] = []
var _physics_objects: Array[float] = []
var _started_usec := 0
var _last_status_second := -1


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    await process_frame

    var config = root.get_node_or_null("WorldConfig")
    var inventory = root.get_node_or_null("Inventory")
    var clock = root.get_node_or_null("GameClock")
    var tech = root.get_node_or_null("Tech")
    var save_system = root.get_node_or_null("SaveSystem")
    if config == null or inventory == null or clock == null or tech == null or save_system == null:
        push_error("Hardware probe: required autoload is missing")
        quit(1)
        return

    OS.set_environment("HTK_AUTO_START_GAME", "1")
    config.apply_profile("classic")
    inventory.reset()
    clock.reset()
    tech.reset()
    save_system.pending.clear()
    paused = false

    var main = load("res://scenes/main.tscn").instantiate()
    root.add_child(main)
    current_scene = main
    await process_frame

    if not is_instance_valid(main) or main.get_node_or_null("World") == null:
        push_error("Hardware probe: campaign failed to initialize")
        quit(1)
        return

    print("HARDWARE_PROBE_STARTED duration_seconds=", DURATION_SECONDS,
        " profile=classic autonomous_systems=enabled")
    _started_usec = Time.get_ticks_usec()
    var previous_usec := _started_usec

    while true:
        await process_frame
        var now_usec := Time.get_ticks_usec()
        var elapsed_seconds := float(now_usec - _started_usec) / 1000000.0
        var frame_ms := float(now_usec - previous_usec) / 1000.0
        previous_usec = now_usec

        _frame_wall_ms.append(frame_ms)
        _process_ms.append(float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0)
        _physics_ms.append(float(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0)
        _memory_bytes.append(float(Performance.get_monitor(Performance.MEMORY_STATIC)))
        _node_counts.append(float(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
        _physics_objects.append(float(Performance.get_monitor(Performance.PHYSICS_2D_ACTIVE_OBJECTS)))

        var elapsed_whole_seconds := int(elapsed_seconds)
        if elapsed_whole_seconds > 0 and elapsed_whole_seconds % int(STATUS_INTERVAL_SECONDS) == 0 and elapsed_whole_seconds != _last_status_second:
            _last_status_second = elapsed_whole_seconds
            print("HARDWARE_PROBE_PROGRESS elapsed_seconds=", elapsed_whole_seconds,
                " samples=", _frame_wall_ms.size(),
                " memory_mb=", _to_mb(_memory_bytes[_memory_bytes.size() - 1]),
                " nodes=", int(_node_counts[_node_counts.size() - 1]),
                " physics_objects=", int(_physics_objects[_physics_objects.size() - 1]))

        if elapsed_seconds >= DURATION_SECONDS:
            break

    var report := {
        "profile": "classic",
        "duration_seconds": float(Time.get_ticks_usec() - _started_usec) / 1000000.0,
        "samples": _frame_wall_ms.size(),
        "autonomous_systems_enabled": true,
        "windowed_rendering": DisplayServer.get_name().to_lower() != "headless",
        "frame_wall_ms": _summarize(_frame_wall_ms),
        "engine_process_ms": _summarize(_process_ms),
        "engine_physics_ms": _summarize(_physics_ms),
        "memory_static_mb": {
            "start": _to_mb(_memory_bytes[0]),
            "peak": _to_mb(_max_value(_memory_bytes)),
            "end": _to_mb(_memory_bytes[_memory_bytes.size() - 1])
        },
        "node_count": {
            "start": int(_node_counts[0]),
            "peak": int(_max_value(_node_counts)),
            "end": int(_node_counts[_node_counts.size() - 1])
        },
        "active_physics_objects": {
            "start": int(_physics_objects[0]),
            "peak": int(_max_value(_physics_objects)),
            "end": int(_physics_objects[_physics_objects.size() - 1])
        }
    }

    var output := JSON.stringify(report, "\\t")
    var file := FileAccess.open("user://hardware_acceptance_probe.json", FileAccess.WRITE)
    if file == null:
        push_error("Hardware probe: could not write user://hardware_acceptance_probe.json")
        print(output)
        quit(1)
        return
    file.store_string(output)
    file.close()
    print("HARDWARE_PROBE_COMPLETE")
    print(output)
    OS.set_environment("HTK_AUTO_START_GAME", "0")
    quit(0)


func _summarize(values: Array[float]) -> Dictionary:
    var sorted := values.duplicate()
    sorted.sort()
    return {
        "average": _average(sorted),
        "p50": _percentile(sorted, 0.50),
        "p95": _percentile(sorted, 0.95),
        "p99": _percentile(sorted, 0.99),
        "max": sorted[sorted.size() - 1]
    }


func _average(values: Array[float]) -> float:
    var total := 0.0
    for value in values:
        total += value
    return total / float(values.size())


func _percentile(sorted_values: Array[float], ratio: float) -> float:
    var index := clampi(int(ceil(float(sorted_values.size()) * ratio)) - 1, 0, sorted_values.size() - 1)
    return sorted_values[index]


func _max_value(values: Array[float]) -> float:
    var maximum := 0.0
    for value in values:
        maximum = maxf(maximum, value)
    return maximum


func _to_mb(bytes: float) -> float:
    return snappedf(bytes / 1048576.0, 0.1)
