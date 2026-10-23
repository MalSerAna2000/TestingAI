extends RefCounted
class_name ValleyGenerator

## Procedural valley generator using FastNoiseLite with three strictly non-overlapping
## biome zones: PLAINS (Равнины), WATER (Водоемы), and MOUNTAINS (Горы).

enum Biome {
	PLAINS = 0,
	WATER = 1,
	MOUNTAINS = 2,
}

const WATER_LEVEL_Y: float = 0.0

var seed_value: int = 472026
var biome_noise := FastNoiseLite.new()
var river_noise := FastNoiseLite.new()
var height_noise := FastNoiseLite.new()
var ridge_noise := FastNoiseLite.new()


func _init(p_seed: int = 472026) -> void:
	seed_value = p_seed

	biome_noise.seed = seed_value
	biome_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	biome_noise.frequency = 0.0014
	biome_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	biome_noise.fractal_octaves = 3

	river_noise.seed = seed_value + 1337
	river_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	river_noise.frequency = 0.0009
	river_noise.fractal_octaves = 2

	height_noise.seed = seed_value + 7777
	height_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	height_noise.frequency = 0.0065
	height_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	height_noise.fractal_octaves = 4

	ridge_noise.seed = seed_value + 31337
	ridge_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	ridge_noise.frequency = 0.0042
	ridge_noise.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	ridge_noise.fractal_octaves = 4


func _get_biome_selector(wx: float, wz: float) -> float:
	var dist_origin: float = Vector2(wx, wz).length()
	var raw_b: float = biome_noise.get_noise_2d(wx, wz)
	# Carve meandering river/lake channels outside safe spawn zone
	var river_band: float = absf(river_noise.get_noise_2d(wx, wz))
	if river_band < 0.055 and raw_b < 0.18:
		var t_riv: float = 1.0 - (river_band / 0.055)
		raw_b = lerpf(raw_b, -0.55, t_riv)

	# Guarantee central 125m radius around (0, 0) & (0, -50) is open Plains for clean start
	if dist_origin < 165.0:
		var safe_blend: float = smoothstep(95.0, 165.0, dist_origin)
		raw_b = lerpf(0.02, raw_b, safe_blend)
	return raw_b


func get_biome_at(wx: float, wz: float) -> int:
	var sel: float = _get_biome_selector(wx, wz)
	if sel < -0.20:
		return Biome.WATER
	elif sel > 0.24:
		return Biome.MOUNTAINS
	return Biome.PLAINS


func get_height_and_biome(wx: float, wz: float) -> Vector2:
	var sel: float = _get_biome_selector(wx, wz)
	var gentle: float = height_noise.get_noise_2d(wx, wz) * 0.5 + 0.5
	var dist_origin: float = Vector2(wx, wz).length()
	var spawn_flat: float = smoothstep(55.0, 130.0, dist_origin)

	if sel < -0.20:
		# Strictly WATER zone: depressed basin below WATER_LEVEL_Y (0.0)
		var depth_factor: float = clampf((-0.20 - sel) / 0.45, 0.0, 1.0)
		var h_water: float = -0.45 - pow(depth_factor, 0.85) * (9.5 + 3.0 * gentle)
		return Vector2(h_water, float(Biome.WATER))
	elif sel > 0.24:
		# Strictly MOUNTAINS zone: hills & steep rocky cliffs rising cleanly from plains edge
		var m_factor: float = clampf((sel - 0.24) / 0.55, 0.0, 1.0)
		var ridge: float = ridge_noise.get_noise_2d(wx, wz) * 0.5 + 0.5
		var base_plains_edge: float = 1.6 + 5.8 * gentle
		var mountain_elev: float = pow(m_factor, 1.25) * (34.0 + 96.0 * ridge + 18.0 * gentle)
		return Vector2(base_plains_edge + mountain_elev, float(Biome.MOUNTAINS))
	else:
		# Strictly PLAINS zone: smooth shoreline margin near -0.20 and foothill margin near +0.24
		var shore_t: float = smoothstep(-0.20, -0.11, sel)
		var meadow_h: float = lerpf(0.65, 1.6 + 5.8 * gentle * spawn_flat, shore_t)
		return Vector2(meadow_h, float(Biome.PLAINS))


func get_height_at(wx: float, wz: float) -> float:
	return get_height_and_biome(wx, wz).x


func get_normal_at(wx: float, wz: float, eps: float = 1.0) -> Vector3:
	var hL: float = get_height_at(wx - eps, wz)
	var hR: float = get_height_at(wx + eps, wz)
	var hD: float = get_height_at(wx, wz - eps)
	var hU: float = get_height_at(wx, wz + eps)
	return Vector3(hL - hR, 2.0 * eps, hD - hU).normalized()
