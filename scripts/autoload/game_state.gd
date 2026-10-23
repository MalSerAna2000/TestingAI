extends Node
## Global game configuration, world seed/size state, and synchronized game clock.
## Time ratio per specification: 60 game minutes = 3 real minutes (180.0 real seconds).

signal time_updated(hours: float, formatted: String)
signal castle_state_requested(state_id: int)
signal teleport_to_castle_requested(inside_hall: bool)
signal skip_sleep_requested()
signal maid_outfit_changed(equipped: bool)
signal sleep_cutscene_state_changed(active: bool)
signal player_status_message(text: String)

const START_HOUR: float = 22.0
const REAL_SECONDS_PER_GAME_HOUR: float = 180.0
const GAME_MINUTES_PER_REAL_SECOND: float = 60.0 / REAL_SECONDS_PER_GAME_HOUR # 0.333333 game min / real sec

enum CastleState {
	NORMAL = 0,   ## "Обычное"
	SUCTION = 1,  ## "Всасывание"
	FLYING = 2    ## "Летающее"
}

var world_size_km: int = 1
var world_seed: int = 20261023
var world_seed_text: String = "20261023"

var time_of_day_hours: float = START_HOUR
var total_game_minutes: float = 0.0
var is_in_game: bool = false
var is_sleep_cutscene_active: bool = false
var maid_outfit_equipped: bool = false
var aero_debug_vectors_enabled: bool = false

var _ui_emit_accum: float = 0.0


func configure_new_game(size_km: int, seed_input: String) -> void:
	if size_km in [1, 10, 50]:
		world_size_km = size_km
	else:
		world_size_km = 1

	var cleaned := seed_input.strip_edges()
	if cleaned.is_empty():
		cleaned = str(randi() % 99999999 + 1)
	world_seed_text = cleaned
	if cleaned.is_valid_int():
		world_seed = int(cleaned)
	else:
		world_seed = abs(cleaned.hash())

	time_of_day_hours = START_HOUR
	total_game_minutes = 0.0
	is_sleep_cutscene_active = false
	maid_outfit_equipped = false


func get_world_size_meters() -> float:
	return float(world_size_km) * 1000.0


func get_half_world_meters() -> float:
	return get_world_size_meters() * 0.5


func reset_session_clock() -> void:
	time_of_day_hours = START_HOUR
	total_game_minutes = 0.0
	is_sleep_cutscene_active = false
	time_updated.emit(time_of_day_hours, get_formatted_time())


func _process(delta: float) -> void:
	if not is_in_game:
		return
	if is_sleep_cutscene_active:
		return

	var added_minutes: float = delta * GAME_MINUTES_PER_REAL_SECOND
	total_game_minutes += added_minutes
	time_of_day_hours = fposmod(time_of_day_hours + added_minutes / 60.0, 24.0)

	_ui_emit_accum += delta
	if _ui_emit_accum >= 0.25:
		_ui_emit_accum = 0.0
		time_updated.emit(time_of_day_hours, get_formatted_time())


func advance_game_hours(hours: float) -> void:
	total_game_minutes += hours * 60.0
	time_of_day_hours = fposmod(time_of_day_hours + hours, 24.0)
	time_updated.emit(time_of_day_hours, get_formatted_time())


func get_formatted_time() -> String:
	var h: int = int(floor(time_of_day_hours)) % 24
	var m: int = int(floor((time_of_day_hours - floor(time_of_day_hours)) * 60.0)) % 60
	return "%02d:%02d" % [h, m]


func is_night_time() -> bool:
	return time_of_day_hours >= 19.5 or time_of_day_hours < 6.0


func get_castle_state_name(state_id: int) -> String:
	match state_id:
		CastleState.NORMAL:
			return "Обычное"
		CastleState.SUCTION:
			return "Всасывание"
		CastleState.FLYING:
			return "Летающее"
	return "Обычное"
