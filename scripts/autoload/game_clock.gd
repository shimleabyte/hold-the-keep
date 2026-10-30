extends Node
## Siklus siang-malam. time_of_day: 0.0 .. 1.0

const DAY_LENGTH := 180.0  # detik per hari
const NIGHT_START := 0.6
const NIGHT_END := 0.9

var time_of_day := 0.0
var day := 1
var is_night := false


func reset() -> void:
    time_of_day = 0.0
    day = 1
    is_night = false


func _process(delta: float) -> void:
    time_of_day += delta / DAY_LENGTH
    if time_of_day >= 1.0:
        time_of_day -= 1.0
        day += 1
        Events.day_changed.emit(day)
    var night := time_of_day >= NIGHT_START and time_of_day < NIGHT_END
    if night != is_night:
        is_night = night
        Events.phase_changed.emit(is_night)


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
