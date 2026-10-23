class_name DayNightCycle
extends Node3D
## Dynamic Sun/Moon orbital cycle using DirectionalLight3D and PhysicalSkyMaterial.
## Starts cleanly at 22:00 night with crisp moonlit PS3 atmosphere and full solar progression.

@export var sun_light: DirectionalLight3D
@export var moon_light: DirectionalLight3D
@export var world_environment: WorldEnvironment

var _sky_mat: PhysicalSkyMaterial


func _ready() -> void:
	if world_environment != null and world_environment.environment != null and world_environment.environment.sky != null:
		_sky_mat = world_environment.environment.sky.sky_material as PhysicalSkyMaterial
	_apply_time(GameState.time_of_day_hours)


func _process(_delta: float) -> void:
	_apply_time(GameState.time_of_day_hours)


func _apply_time(hours: float) -> void:
	# 06:00 sunrise (0 deg), 12:00 zenith (+90 deg), 18:00 sunset (+180 deg), 24:00 nadir (+270 deg)
	var sun_angle_rad: float = ((hours - 6.0) / 24.0) * TAU
	var sun_elev: float = sin(sun_angle_rad)
	var day_factor: float = clampf((sun_elev + 0.14) / 0.42, 0.0, 1.0)
	var twilight_factor: float = clampf(1.0 - absf(sun_elev) / 0.24, 0.0, 1.0)

	if sun_light != null:
		sun_light.rotation = Vector3(-sun_angle_rad, deg_to_rad(32.0), 0.0)
		sun_light.light_energy = lerpf(0.0, 1.35, day_factor)
		sun_light.shadow_enabled = day_factor > 0.05
		var warm_sun := Color(1.0, 0.62, 0.36)
		var noon_sun := Color(1.0, 0.97, 0.91)
		sun_light.light_color = warm_sun.lerp(noon_sun, clampf(sun_elev * 1.6, 0.0, 1.0))

	if moon_light != null:
		var moon_angle_rad: float = sun_angle_rad + PI
		moon_light.rotation = Vector3(-moon_angle_rad, deg_to_rad(-28.0), 0.0)
		var night_factor: float = 1.0 - day_factor
		moon_light.light_energy = lerpf(0.0, 0.52, night_factor)
		moon_light.shadow_enabled = night_factor > 0.35
		moon_light.light_color = Color(0.66, 0.75, 1.0)

	if _sky_mat != null:
		_sky_mat.rayleigh_coefficient = lerpf(3.2, 2.0, day_factor)
		_sky_mat.turbidity = lerpf(4.5, 10.0, day_factor)
		_sky_mat.energy_multiplier = lerpf(0.45, 1.15, day_factor)
		var star_alpha: float = clampf(1.0 - day_factor * 1.35, 0.0, 1.0)
		_sky_mat.sky_cover_modulate = Color(star_alpha, star_alpha, star_alpha * 1.1, star_alpha)

	if world_environment != null and world_environment.environment != null:
		var env: Environment = world_environment.environment
		var night_amb := Color(0.16, 0.19, 0.30)
		var dusk_amb := Color(0.42, 0.26, 0.32)
		var day_amb := Color(0.55, 0.62, 0.72)
		env.ambient_light_color = night_amb.lerp(day_amb, day_factor).lerp(dusk_amb, twilight_factor * 0.45)
		env.ambient_light_energy = lerpf(0.68, 0.48, day_factor)
		env.fog_light_color = Color(0.10, 0.11, 0.20).lerp(Color(0.68, 0.76, 0.88), day_factor)
