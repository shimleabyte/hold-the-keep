extends Node
## Siklus siang-malam. time_of_day: 0.0 .. 1.0

const DAY_LENGTH := 180.0  # detik per siklus penuh
const NIGHT_START := 0.6
const NIGHT_END := 0.9
const NIGHT_WARNING_LEAD := 0.05 # 9 seconds before the night phase starts

var time_of_day := 0.0
var day := 1
var is_night := false
var _night_warning_sent := false


func reset() -> void:
    time_of_day = 0.0
    day = 1
    is_night = false
    _night_warning_sent = false


func _process(delta: float) -> void:
    time_of_day += delta / DAY_LENGTH
    if time_of_day >= 1.0:
        time_of_day -= 1.0
        day += 1
        _night_warning_sent = false
        Events.day_changed.emit(day)
    if not _night_warning_sent and not is_night and time_of_day >= NIGHT_START - NIGHT_WARNING_LEAD:
        _night_warning_sent = true
        Events.build_feedback.emit("Senja mendekat. Bersiap untuk serangan malam.")
    var night := time_of_day >= NIGHT_START and time_of_day < NIGHT_END
    if night != is_night:
        is_night = night
        Events.phase_changed.emit(is_night)


## Returns the rounded-up number of game seconds until the next night/dawn boundary.
func seconds_until_phase_change() -> int:
    var night_now: bool = time_of_day >= NIGHT_START and time_of_day < NIGHT_END
    var target_phase_time: float = NIGHT_END if night_now else NIGHT_START
    var remaining: float = target_phase_time - time_of_day
    if remaining < 0.0:
        remaining += 1.0
    # Avoid showing an extra second when floating-point math lands just above an integer.
    return maxi(1, ceili(remaining * DAY_LENGTH - 0.000001))


## 0.0 = siang penuh, 1.0 = malam penuh, dengan transisi senja/fajar.
func darkness() -> float:
    var t := time_of_day
    if t < NIGHT_START - 0.1:
        return 0.0
    if t < NIGHT_START:
        return (t - (NIGHT_START - 0.1)) / 0.1
    if t < NIGHT_END:
        return 1.0
    return 1.0 - (t - NIGHT_END) / (1.0 - NIGHT_END)
