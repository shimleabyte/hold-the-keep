extends RefCounted
## Owns save-file parsing and crash-safe primary/temporary/backup replacement.
## Validation remains injected so the store does not depend on gameplay autoloads.

var _validator


func configure(validator) -> void:
    _validator = validator


func read_snapshot(path: String, enforce_world_compatibility := true) -> Variant:
    if not FileAccess.file_exists(path) or _validator == null:
        return null
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return null
    var json := JSON.new()
    var parse_error := json.parse(file.get_as_text())
    file.close()
    if parse_error != OK or not _validator.is_valid_save(json.data, enforce_world_compatibility):
        return null
    return json.data


## Install only a fully written and schema-valid temp snapshot.
## A verified primary becomes the rollback backup before the temp is installed.
func write_snapshot(data: Dictionary, primary_path: String, temp_path: String, backup_path: String) -> bool:
    if _validator == null:
        return false

    DirAccess.remove_absolute(temp_path)
    var file := FileAccess.open(temp_path, FileAccess.WRITE)
    if file == null:
        return false
    file.store_string(JSON.stringify(data))
    file.flush()
    var write_error := file.get_error()
    file.close()
    if write_error != OK:
        DirAccess.remove_absolute(temp_path)
        return false

    # Re-open the exact bytes to catch incomplete writes and serialization errors.
    if read_snapshot(temp_path, false) == null:
        DirAccess.remove_absolute(temp_path)
        return false

    if FileAccess.file_exists(primary_path):
        if read_snapshot(primary_path, false) != null:
            DirAccess.remove_absolute(backup_path)
            var backup_error := DirAccess.rename_absolute(primary_path, backup_path)
            if backup_error != OK:
                DirAccess.remove_absolute(temp_path)
                return false
        else:
            # Never discard the backup just because the primary is already corrupt.
            DirAccess.remove_absolute(primary_path)

    var install_error := DirAccess.rename_absolute(temp_path, primary_path)
    if install_error != OK:
        if FileAccess.file_exists(backup_path):
            var restore_error := DirAccess.rename_absolute(backup_path, primary_path)
            if restore_error != OK:
                push_error("Save rollback failed; backup remains at " + backup_path)
        DirAccess.remove_absolute(temp_path)
        return false
    return true
