extends Node

## Manages natural valley wind, Debug Menu artificial wind presets (3 real minutes each),
## AeroAtmosphere3D synchronization, and the 250m Hurricane Vortex wind field.

signal wind_preset_changed(preset_name: String, speed_kmh: float, remaining_sec: float)
signal hurricane_spawn_requested(distance_m: float)
signal hurricane_cleared()

const ARTIFICIAL_WIND_DURATION_SEC: float = 180.0 # 3 real minutes

var natural_noise := FastNoiseLite.new()
var time_accum: float = 0.0

var artificial_active: bool = false
var artificial_timer_sec: float = 0.0
var artificial_preset_name: String = "Естественный"
var artificial_speed_ms: float = 2.5
var artificial_direction: Vector3 = Vector3(1.0, 0.0, 0.0)
var hurricane_active: bool = false

var current_wind_velocity: Vector3 = Vector3(2.2, 0.0, -1.2)
var world_aero_atmosphere: Area3D = null
var active_hurricane_node: Node3D = null


func _ready() -> void:
	natural_noise.seed = 90210
	natural_noise.frequency = 0.015


func register_world_atmosphere(atmo: Area3D) -> void:
	world_aero_atmosphere = atmo
	if is_instance_valid(world_aero_atmosphere):
		world_aero_atmosphere.set("wind", current_wind_velocity)


func set_artificial_wind_kmh(speed_kmh: float, preset_label: String, spawn_hurricane: bool = false) -> void:
	artificial_active = true
	artificial_timer_sec = ARTIFICIAL_WIND_DURATION_SEC
	artificial_preset_name = preset_label
	artificial_speed_ms = speed_kmh / 3.6
	var rand_angle: float = randf() * TAU
	artificial_direction = Vector3(cos(rand_angle), 0.0, sin(rand_angle)).normalized()

	if spawn_hurricane:
		hurricane_active = true
		hurricane_spawn_requested.emit(250.0)
	else:
		if hurricane_active:
			hurricane_active = false
			hurricane_cleared.emit()

	_update_wind_vector(0.0)
	wind_preset_changed.emit(artificial_preset_name, speed_kmh, artificial_timer_sec)


func _physics_process(delta: float) -> void:
	time_accum += delta
	if artificial_active:
		artificial_timer_sec -= delta
		if artificial_timer_sec <= 0.0:
			artificial_active = false
			artificial_timer_sec = 0.0
			artificial_preset_name = "Естественный"
			if hurricane_active:
				hurricane_active = false
				hurricane_cleared.emit()
	_update_wind_vector(delta)


func _update_wind_vector(_delta: float) -> void:
	if artificial_active:
		# Subtle natural gusting around the target wind speed
		var gust: float = 1.0 + 0.14 * sin(time_accum * 1.35) + 0.08 * cos(time_accum * 3.1)
		var vert_gust: float = 0.08 * artificial_speed_ms * sin(time_accum * 0.9) if artificial_speed_ms > 15.0 else 0.0
		current_wind_velocity = artificial_direction * (artificial_speed_ms * gust) + Vector3(0.0, vert_gust, 0.0)
	else:
		var nx: float = natural_noise.get_noise_2d(time_accum * 1.4, 0.0)
		var nz: float = natural_noise.get_noise_2d(0.0, time_accum * 1.4 + 100.0)
		var dir := Vector3(nx, 0.0, nz)
		if dir.length_squared() < 0.001:
			dir = Vector3(1.0, 0.0, 0.0)
		else:
			dir = dir.normalized()
		var spd: float = remap(natural_noise.get_noise_1d(time_accum * 0.8), -1.0, 1.0, 1.5, 7.5)
		current_wind_velocity = dir * spd

	if is_instance_valid(world_aero_atmosphere):
		var effective_atmo_wind: Vector3 = current_wind_velocity
		if hurricane_active and is_instance_valid(active_hurricane_node) and is_instance_valid(GameState.castle_ref):
			effective_atmo_wind = get_wind_at_position(GameState.castle_ref.global_position)
		world_aero_atmosphere.set("wind", effective_atmo_wind)


func get_wind_at_position(world_pos: Vector3) -> Vector3:
	var w: Vector3 = current_wind_velocity
	if hurricane_active and is_instance_valid(active_hurricane_node):
		var offset: Vector3 = world_pos - active_hurricane_node.global_position
		var horiz := Vector3(offset.x, 0.0, offset.z)
		var dist: float = maxf(horiz.length(), 1.0)
		if dist < 420.0:
			var falloff: float = clampf(1.0 - (dist / 420.0), 0.0, 1.0)
			var tangent := Vector3(-horiz.z, 0.0, horiz.x).normalized()
			var radial_in := -horiz.normalized()
			# Rankine-like hurricane swirl + inward pull + strong central updraft
			w += (tangent * 36.0 + radial_in * 14.0 + Vector3.UP * (18.0 * falloff)) * falloff
	return w


func get_current_speed_kmh() -> float:
	return current_wind_velocity.length() * 3.6
