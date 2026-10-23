extends Node
## Global 3D Wind, Venturi Suction, Interior Gust, and Hurricane Vortex Simulator.
## Artificial wind presets last strictly 3 real minutes (180 seconds) with random direction,
## and "Ураган" (120 km/h) spawns a physical Hurricane Funnel strictly 250m from Yumik.

signal wind_changed(label: String, speed_kmh: float, direction_vec: Vector3, remaining_sec: float)
signal hurricane_spawn_requested(spawn_distance_meters: float)
signal hurricane_cleared()

enum WindPreset {
	NATURAL = -1,
	CALM = 0,        ## Штиль: 1 км/ч
	LIGHT = 1,       ## Слабый ветер: 15 км/ч
	FRESH = 2,       ## Свежий ветер: 35 км/ч
	VERY_STRONG = 3, ## Очень крепкий ветер: 70 км/ч
	HURRICANE = 4    ## Ураган: 120 км/ч (воронка в 250 м от Юмика)
}

const ARTIFICIAL_DURATION_SEC: float = 180.0
const HURRICANE_SPAWN_DISTANCE: float = 250.0

const PRESET_KMH := {
	WindPreset.CALM: 1.0,
	WindPreset.LIGHT: 15.0,
	WindPreset.FRESH: 35.0,
	WindPreset.VERY_STRONG: 70.0,
	WindPreset.HURRICANE: 120.0,
}

const PRESET_NAMES := {
	WindPreset.NATURAL: "Естественный ветер",
	WindPreset.CALM: "Штиль (1 км/ч)",
	WindPreset.LIGHT: "Слабый ветер (15 км/ч)",
	WindPreset.FRESH: "Свежий ветер (35 км/ч)",
	WindPreset.VERY_STRONG: "Очень крепкий ветер (70 км/ч)",
	WindPreset.HURRICANE: "Ураган (120 км/ч)",
}

var active_preset: int = WindPreset.NATURAL
var current_speed_kmh: float = 14.0
var wind_direction: Vector3 = Vector3(0.707, 0.0, -0.707)
var artificial_timer: float = 0.0

var hurricane_active: bool = false
var hurricane_center: Vector3 = Vector3.ZERO
var hurricane_radius: float = 165.0

var venturi_active: bool = false
var venturi_mouth_pos: Vector3 = Vector3.ZERO
var venturi_inward_dir: Vector3 = Vector3.FORWARD
var venturi_strength_mps: float = 34.0

var interior_gust_active: bool = false
var interior_center: Vector3 = Vector3.ZERO
var interior_gust_vector: Vector3 = Vector3.ZERO

var _turbulence_time: float = 0.0
var _natural_phase: float = 0.0
var _ui_accum: float = 0.0


func _ready() -> void:
	randomize()
	reset_to_natural()


func reset_to_natural() -> void:
	active_preset = WindPreset.NATURAL
	artificial_timer = 0.0
	if hurricane_active:
		hurricane_active = false
		hurricane_cleared.emit()
	var ang: float = randf() * TAU
	wind_direction = Vector3(cos(ang), 0.0, sin(ang)).normalized()
	current_speed_kmh = 14.0
	wind_changed.emit(PRESET_NAMES[WindPreset.NATURAL], current_speed_kmh, wind_direction, 0.0)


func set_artificial_wind(preset: int) -> void:
	if not PRESET_KMH.has(preset):
		reset_to_natural()
		return

	if hurricane_active and preset != WindPreset.HURRICANE:
		hurricane_active = false
		hurricane_cleared.emit()

	active_preset = preset
	artificial_timer = ARTIFICIAL_DURATION_SEC
	current_speed_kmh = PRESET_KMH[preset]

	# Random horizontal direction for every artificial wind activation
	var angle: float = randf() * TAU
	wind_direction = Vector3(cos(angle), 0.0, sin(angle)).normalized()

	if preset == WindPreset.HURRICANE:
		hurricane_active = true
		hurricane_spawn_requested.emit(HURRICANE_SPAWN_DISTANCE)

	wind_changed.emit(get_current_wind_label(), current_speed_kmh, wind_direction, artificial_timer)
	GameState.player_status_message.emit("Ветер: %s (3:00)" % get_current_wind_label())


func get_current_wind_label() -> String:
	return PRESET_NAMES.get(active_preset, "Ветер")


func get_base_wind_mps() -> float:
	return current_speed_kmh / 3.6


func _physics_process(delta: float) -> void:
	_turbulence_time += delta

	if active_preset != WindPreset.NATURAL:
		artificial_timer -= delta
		if artificial_timer <= 0.0:
			reset_to_natural()
	else:
		_natural_phase += delta * 0.045
		current_speed_kmh = 12.0 + 14.0 * (0.5 + 0.5 * sin(_natural_phase)) + 5.0 * sin(_natural_phase * 2.7)
		var drift_angle: float = delta * 0.03 * sin(_natural_phase * 0.6)
		wind_direction = wind_direction.rotated(Vector3.UP, drift_angle).normalized()

	_ui_accum += delta
	if _ui_accum >= 0.4:
		_ui_accum = 0.0
		wind_changed.emit(get_current_wind_label(), current_speed_kmh, wind_direction, maxf(artificial_timer, 0.0))


func get_wind_at_position(world_pos: Vector3) -> Vector3:
	var base_mps: float = get_base_wind_mps()
	var gust_factor: float = 1.0 + 0.16 * sin(_turbulence_time * 1.35 + world_pos.x * 0.025 + world_pos.z * 0.021)
	var alt_factor: float = 1.0 + clampf(world_pos.y / 140.0, 0.0, 0.55)
	var up_gust: float = base_mps * 0.11 * sin(_turbulence_time * 0.92 + world_pos.z * 0.03)
	var w: Vector3 = wind_direction * (base_mps * gust_factor * alt_factor) + Vector3(0.0, up_gust, 0.0)

	# Cyclonic 3D Hurricane Funnel Field (spawned strictly 250m from Yumik in "Ураган")
	if hurricane_active:
		var rel: Vector3 = world_pos - hurricane_center
		var horiz := Vector2(rel.x, rel.z)
		var dist: float = maxf(horiz.length(), 1.5)
		if dist < hurricane_radius * 2.4:
			var falloff: float = clampf(1.0 - dist / (hurricane_radius * 2.4), 0.0, 1.0)
			var tangent := Vector3(-rel.z, 0.0, rel.x).normalized()
			var inward := -Vector3(rel.x, 0.0, rel.z).normalized()
			var swirl_speed: float = 38.0 * falloff
			var inflow_speed: float = 22.0 * falloff
			var updraft: float = 24.0 * pow(falloff, 1.35)
			w += tangent * swirl_speed + inward * inflow_speed + Vector3.UP * updraft

	# Venturi Suction Cone outside & inside open gates during "Всасывание"
	if venturi_active:
		var to_mouth: Vector3 = venturi_mouth_pos - world_pos
		var d: float = to_mouth.length()
		if d < 95.0 and d > 0.25:
			var pull_falloff: float = pow(1.0 - d / 95.0, 1.25)
			w += (to_mouth.normalized() * 0.72 + venturi_inward_dir * 0.45).normalized() * (venturi_strength_mps * pull_falloff)

	# Interior Throne Hall gusts created by Dark God flapping wings in "Летающее"
	if interior_gust_active:
		if world_pos.distance_to(interior_center) < 17.5:
			w += interior_gust_vector

	return w
