extends Node3D
class_name DayNightCycle

## Dynamic 24-hour cycle starting at 22:00 night.
## Drives Sun DirectionalLight3D, Moon DirectionalLight3D, and WorldEnvironment
## with PhysicalSkyMaterial + starry Milky Way HDR night sky.

@export var sun_light_path: NodePath
@export var moon_light_path: NodePath
@export var world_env_path: NodePath

var sun_light: DirectionalLight3D
var moon_light: DirectionalLight3D
var world_env: WorldEnvironment
var physical_sky: PhysicalSkyMaterial


func _ready() -> void:
	sun_light = get_node_or_null(sun_light_path) as DirectionalLight3D
	moon_light = get_node_or_null(moon_light_path) as DirectionalLight3D
	world_env = get_node_or_null(world_env_path) as WorldEnvironment
	if world_env and world_env.environment and world_env.environment.sky:
		physical_sky = world_env.environment.sky.sky_material as PhysicalSkyMaterial
	_update_celestial_lighting(GameState.game_hours)


func _process(_delta: float) -> void:
	_update_celestial_lighting(GameState.game_hours)


func _update_celestial_lighting(hours: float) -> void:
	# 06:00 = sunrise (pitch 0), 12:00 = zenith (-90 deg), 18:00 = sunset (-180 deg), 24:00 = nadir
	var day_fraction: float = (hours - 6.0) / 24.0
	var sun_angle_rad: float = day_fraction * TAU
	var sun_elev: float = sin(sun_angle_rad)

	if sun_light:
		# Rotate sun so positive sin(sun_angle_rad) points light downward onto valley
		sun_light.rotation = Vector3(-sun_angle_rad, deg_to_rad(28.0), 0.0)
		var sun_factor: float = clampf((sun_elev + 0.08) / 0.35, 0.0, 1.0)
		sun_light.light_energy = sun_factor * 1.45
		sun_light.visible = sun_factor > 0.01
		# Warm golden sunrise/sunset -> crisp PS3 daylight at noon
		var horizon_warmth: float = clampf(1.0 - absf(sun_elev) * 2.2, 0.0, 1.0)
		sun_light.light_color = Color(1.0, 0.96, 0.90).lerp(Color(1.0, 0.58, 0.32), horizon_warmth)

	if moon_light:
		var moon_angle_rad: float = sun_angle_rad + PI
		var moon_elev: float = sin(moon_angle_rad)
		moon_light.rotation = Vector3(-moon_angle_rad, deg_to_rad(28.0), 0.0)
		var moon_factor: float = clampf((moon_elev + 0.12) / 0.35, 0.0, 1.0) * (1.0 - clampf(sun_elev * 3.0, 0.0, 1.0))
		moon_light.light_energy = 0.42 * moon_factor
		moon_light.visible = moon_factor > 0.01
		moon_light.light_color = Color(0.66, 0.78, 1.0)

	if physical_sky:
		var day_energy: float = clampf((sun_elev + 0.14) / 0.42, 0.0, 1.0)
		physical_sky.energy_multiplier = lerpf(0.28, 1.15, day_energy)
		physical_sky.turbidity = lerpf(4.5, 10.0, day_energy)
		physical_sky.rayleigh_coefficient = lerpf(1.2, 2.2, day_energy)

	if world_env and world_env.environment:
		var night_factor: float = clampf((-sun_elev + 0.1) / 0.35, 0.0, 1.0)
		world_env.environment.ambient_light_energy = lerpf(0.55, 0.34, night_factor)
		world_env.environment.ambient_light_color = Color(0.72, 0.78, 0.88).lerp(Color(0.20, 0.25, 0.44), night_factor)
