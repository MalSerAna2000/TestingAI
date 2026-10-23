class_name BiomeGenerator
extends RefCounted
## Deterministic procedural valley & strictly non-overlapping 3-biome generator using FastNoiseLite.
## Biomes:
##   0 = Водоемы (Rivers & Lakes, M < -0.24, height strictly < WATER_LEVEL)
##   1 = Равнины (Plains & Meadows, -0.24 <= M <= 0.26, height strictly > WATER_LEVEL)
##   2 = Горы    (Hills & Climbable Cliffs, M > 0.26)

enum Biome {
	WATER = 0,
	PLAINS = 1,
	MOUNTAINS = 2,
}

const WATER_LEVEL: float = 0.0
const WATER_THRESHOLD: float = -0.24
const MOUNTAIN_THRESHOLD: float = 0.26

var seed_value: int = 20261023
var half_world_size: float = 500.0

var _biome_noise: FastNoiseLite
var _river_warp_noise: FastNoiseLite
var _plains_noise: FastNoiseLite
var _mountain_ridge_noise: FastNoiseLite
var _detail_noise: FastNoiseLite


func _init(p_seed: int = 20261023, p_world_size_meters: float = 1000.0) -> void:
	seed_value = p_seed
	half_world_size = maxf(p_world_size_meters * 0.5, 500.0)

	_biome_noise = FastNoiseLite.new()
	_biome_noise.seed = p_seed
	_biome_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_biome_noise.frequency = 0.00155
	_biome_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_biome_noise.fractal_octaves = 3

	_river_warp_noise = FastNoiseLite.new()
	_river_warp_noise.seed = p_seed + 1337
	_river_warp_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_river_warp_noise.frequency = 0.0009
	_river_warp_noise.fractal_octaves = 2

	_plains_noise = FastNoiseLite.new()
	_plains_noise.seed = p_seed + 4242
	_plains_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	_plains_noise.frequency = 0.0065
	_plains_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_plains_noise.fractal_octaves = 4

	_mountain_ridge_noise = FastNoiseLite.new()
	_mountain_ridge_noise.seed = p_seed + 9001
	_mountain_ridge_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_mountain_ridge_noise.frequency = 0.0038
	_mountain_ridge_noise.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_mountain_ridge_noise.fractal_octaves = 5

	_detail_noise = FastNoiseLite.new()
	_detail_noise.seed = p_seed + 777
	_detail_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	_detail_noise.frequency = 0.042
	_detail_noise.fractal_octaves = 2


func get_biome_scalar(x: float, z: float) -> float:
	var warp_x: float = _river_warp_noise.get_noise_2d(x, z) * 95.0
	var warp_z: float = _river_warp_noise.get_noise_2d(x + 512.0, z - 512.0) * 95.0
	var raw_m: float = _biome_noise.get_noise_2d(x + warp_x, z + warp_z) * 1.18

	# Raise perimeter mountains near world border so all 3 world sizes (1x1, 10x10, 50x50 km) have natural mountain rims
	var edge_dist: float = maxf(absf(x), absf(z))
	var border_start: float = half_world_size - minf(180.0, half_world_size * 0.24)
	if edge_dist > border_start:
		var bt: float = clampf((edge_dist - border_start) / maxf(half_world_size - border_start, 1.0), 0.0, 1.0)
		raw_m = lerpf(raw_m, 0.85, bt * bt)

	# Safe starting valley plains around (0, 0..55m) so Castle & Yumik always spawn cleanly on Plains
	var origin_dist: float = Vector2(x, z - 18.0).length()
	if origin_dist < 145.0:
		var st: float = smoothstep(88.0, 145.0, origin_dist)
		raw_m = lerpf(0.02, raw_m, st)

	return clampf(raw_m, -1.0, 1.0)


func get_biome(x: float, z: float) -> int:
	var m: float = get_biome_scalar(x, z)
	if m < WATER_THRESHOLD:
		return Biome.WATER
	elif m > MOUNTAIN_THRESHOLD:
		return Biome.MOUNTAINS
	return Biome.PLAINS


func get_biome_name_ru(biome_id: int) -> String:
	match biome_id:
		Biome.WATER:
			return "Водоемы"
		Biome.MOUNTAINS:
			return "Горы"
	return "Равнины"


func get_height(x: float, z: float) -> float:
	var m: float = get_biome_scalar(x, z)
	var detail: float = _detail_noise.get_noise_2d(x, z) * 0.42
	var spawn_flat: float = smoothstep(62.0, 125.0, Vector2(x, z - 18.0).length())

	if m < WATER_THRESHOLD:
		# Strictly below WATER_LEVEL (0.0): carved lake / river bed
		var depth_t: float = clampf((WATER_THRESHOLD - m) / 0.55, 0.0, 1.0)
		var bed_ripple: float = _plains_noise.get_noise_2d(x * 1.4, z * 1.4) * 0.65
		return -(0.45 + 7.2 * pow(depth_t, 0.85)) + bed_ripple * depth_t

	# Strictly above WATER_LEVEL for Plains & Mountains so water and land zones NEVER intersect
	var shore_rise: float = smoothstep(WATER_THRESHOLD, WATER_THRESHOLD + 0.14, m)
	var meadow_h: float = 0.65 + (2.15 + (_plains_noise.get_noise_2d(x, z) * 0.5 + 0.5) * 7.8) * shore_rise
	meadow_h = lerpf(2.4, meadow_h + detail * spawn_flat, spawn_flat)

	if m <= MOUNTAIN_THRESHOLD:
		return meadow_h

	var mtn_t: float = clampf((m - MOUNTAIN_THRESHOLD) / 0.58, 0.0, 1.0)
	var mtn_smooth: float = mtn_t * mtn_t * (3.0 - 2.0 * mtn_t)
	var ridge: float = _mountain_ridge_noise.get_noise_2d(x, z) * 0.5 + 0.5
	var cliff_terrace: float = ridge * 78.0 + pow(ridge, 2.2) * 44.0
	return meadow_h + mtn_smooth * (8.0 + cliff_terrace) + detail * 2.2


func get_surface_normal(x: float, z: float, eps: float = 1.0) -> Vector3:
	var hL: float = get_height(x - eps, z)
	var hR: float = get_height(x + eps, z)
	var hD: float = get_height(x, z - eps)
	var hU: float = get_height(x, z + eps)
	return Vector3(hL - hR, 2.0 * eps, hD - hU).normalized()
