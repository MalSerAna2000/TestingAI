extends Node

## Global game state, clock (1 real sec = 20 game sec -> 3 real min = 60 game min),
## world generation parameters, and character/castle state signals.

enum CastleState {
	NORMAL = 0,
	SUCTION = 1,
	FLYING = 2,
}

const TIME_SCALE: float = 20.0 # 180 real seconds = 3600 game seconds (60 game minutes)
const CASTLE_STATE_INTERVAL_REAL_SEC: float = 180.0

signal castle_state_changed(new_state: int)
signal maid_outfit_changed(equipped: bool)
signal maid_hem_changed(lifted: bool)
signal hold_me_changed(active: bool)
signal sleep_cutscene_started()
signal sleep_cutscene_finished()
signal teleport_to_castle_requested()
signal debug_castle_state_requested(target_state: int)
signal exhaustion_changed(exhausted: bool)

var world_size_km: int = 1
var world_seed: int = 472026

# Starts at 22:00 night as required by specification
var game_hours: float = 22.0
var total_game_minutes_elapsed: float = 0.0

var current_castle_state: int = CastleState.NORMAL
var castle_state_timer_sec: float = CASTLE_STATE_INTERVAL_REAL_SEC

var maid_outfit_equipped: bool = false
var maid_hem_lifted: bool = false
var hold_me_active: bool = false

var nyashing_active: bool = false
var nyashing_unresisted_game_minutes: float = 0.0
var is_exhausted: bool = false
var is_sleeping_cutscene: bool = false
var in_gameplay: bool = false

var player_ref: Node3D = null
var castle_ref: Node3D = null


func reset_for_new_game(size_km: int, seed_val: int) -> void:
	world_size_km = size_km
	world_seed = seed_val
	game_hours = 22.0
	total_game_minutes_elapsed = 0.0
	current_castle_state = CastleState.NORMAL
	castle_state_timer_sec = CASTLE_STATE_INTERVAL_REAL_SEC
	maid_outfit_equipped = false
	maid_hem_lifted = false
	hold_me_active = false
	nyashing_active = false
	nyashing_unresisted_game_minutes = 0.0
	is_exhausted = false
	is_sleeping_cutscene = false
	in_gameplay = true


func get_world_half_extent_m() -> float:
	return float(world_size_km) * 500.0


func _process(delta: float) -> void:
	if not in_gameplay:
		return
	if not is_sleeping_cutscene:
		var game_sec: float = delta * TIME_SCALE
		var game_min: float = game_sec / 60.0
		total_game_minutes_elapsed += game_min
		game_hours = fposmod(game_hours + game_sec / 3600.0, 24.0)

		castle_state_timer_sec -= delta
		if castle_state_timer_sec <= 0.0:
			castle_state_timer_sec = CASTLE_STATE_INTERVAL_REAL_SEC
			var next_state: int = (current_castle_state + 1) % 3
			set_castle_state(next_state)


func set_castle_state(new_state: int) -> void:
	current_castle_state = clampi(new_state, 0, 2)
	castle_state_timer_sec = CASTLE_STATE_INTERVAL_REAL_SEC
	if current_castle_state != CastleState.SUCTION:
		nyashing_active = false
	castle_state_changed.emit(current_castle_state)


func request_debug_castle_state(target_state: int) -> void:
	set_castle_state(target_state)
	debug_castle_state_requested.emit(current_castle_state)


func set_maid_outfit(equipped: bool) -> void:
	maid_outfit_equipped = equipped
	if not equipped and maid_hem_lifted:
		maid_hem_lifted = false
		maid_hem_changed.emit(false)
	maid_outfit_changed.emit(maid_outfit_equipped)


func toggle_maid_hem() -> void:
	if not maid_outfit_equipped:
		return
	maid_hem_lifted = not maid_hem_lifted
	maid_hem_changed.emit(maid_hem_lifted)


func set_hold_me(active: bool) -> void:
	if hold_me_active == active:
		return
	hold_me_active = active
	hold_me_changed.emit(hold_me_active)


func set_exhausted(exhausted: bool) -> void:
	if is_exhausted == exhausted:
		return
	is_exhausted = exhausted
	exhaustion_changed.emit(is_exhausted)


func start_euphoria_sleep_cutscene() -> void:
	if is_sleeping_cutscene:
		return
	is_sleeping_cutscene = true
	sleep_cutscene_started.emit()


func finish_euphoria_sleep_cutscene() -> void:
	if not is_sleeping_cutscene:
		return
	is_sleeping_cutscene = false
	# Advance world time by 8 in-game hours and clear exhaustion
	game_hours = fposmod(game_hours + 8.0, 24.0)
	total_game_minutes_elapsed += 480.0
	nyashing_unresisted_game_minutes = 0.0
	nyashing_active = false
	set_exhausted(false)
	sleep_cutscene_finished.emit()


func get_formatted_clock() -> String:
	var h: int = int(floor(game_hours)) % 24
	var m: int = int(floor((game_hours - floor(game_hours)) * 60.0)) % 60
	return "%02d:%02d" % [h, m]


func get_castle_state_name_ru(state_val: int = -1) -> String:
	var s: int = current_castle_state if state_val < 0 else state_val
	match s:
		CastleState.NORMAL:
			return "Обычное"
		CastleState.SUCTION:
			return "Всасывание"
		CastleState.FLYING:
			return "Летающее"
	return "Обычное"
