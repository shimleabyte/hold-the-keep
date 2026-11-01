extends SceneTree
## Loads every GDScript resource inside the actual project context.
## This is intentionally not --check-only per-file: standalone parsing cannot resolve autoloads.


func _initialize() -> void:
    call_deferred("_check_all_scripts")


func _check_all_scripts() -> void:
    var paths: Array[String] = []
    _collect_scripts("res://scripts", paths)
    _collect_scripts("res://tests", paths)
    paths.sort()

    var failures: Array[String] = []
    for path in paths:
        var script_resource: Resource = load(path)
        if script_resource == null:
            failures.append(path)
            push_error("GDScript failed to load: " + path)

    if not failures.is_empty():
        push_error("GDScript parse/load failures: " + ", ".join(failures))
        quit(1)
        return

    print("PASS: parsed %d GDScript resources in project context." % paths.size())
    quit()


func _collect_scripts(directory_path: String, output: Array[String]) -> void:
    var directory := DirAccess.open(directory_path)
    if directory == null:
        push_error("Unable to open script directory: " + directory_path)
        return

    directory.list_dir_begin()
    var entry := directory.get_next()
    while entry != "":
        if entry != "." and entry != "..":
            var full_path := directory_path.path_join(entry)
            if directory.current_is_dir():
                _collect_scripts(full_path, output)
            elif entry.ends_with(".gd"):
                output.append(full_path)
        entry = directory.get_next()
    directory.list_dir_end()
