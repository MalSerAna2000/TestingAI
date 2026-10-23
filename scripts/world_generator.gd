extends Node
class_name WorldGenerator

# ----------------------------------------------------------------
# Процедурная генерация долины: FastNoiseLite, 3 биома, чанки.
# Миры 1×1 / 10×10 / 50×50 км с динамической загрузкой чанков.
# ----------------------------------------------------------------

var noise: FastNoiseLite
var biome_noise: FastNoiseLite
var seed: int = 12345
var size_km: float = 1.0
var chunk_size: float = 64.0
var terrain: Node3D
var chunk_scene: PackedScene
var chunks: Dictionary = {}

func init(seed: int, size_km: float, terrain: Node3D, chunk_scene: PackedScene) -> void:
	self.seed = seed
	self.size_km = size_km
	self.terrain = terrain
	self.chunk_scene = chunk_scene
	noise = FastNoiseLite.new()
	noise.seed = seed
	noise.fractal_type = FastNoiseLite.FRACTAL_TYPE_FBM
	noise.octaves = 4
	noise.frequency = 0.004
	biome_noise = FastNoiseLite.new()
	biome_noise.seed = seed + 1
	biome_noise.fractal_type = FastNoiseLite.FRACTAL_TYPE_FBM
	biome_noise.octaves = 3
	biome_noise.frequency = 0.002

func update(player_pos: Vector3) -> void:
	var radius = 4 if size_km <= 1.5 else 6
	var cx = int(player_pos.x / chunk_size)
	var cz = int(player_pos.z / chunk_size)
	var reach = radius * chunk_size + chunk_size
	for x in range(cx - radius, cx + radius + 1):
		for z in range(cz - radius, cz + radius + 1):
			var key = "%d,%d" % [x, z]
			if not chunks.has(key):
				var c = chunk_scene.instantiate()
				c.global_position = Vector3(x * chunk_size, 0, z * chunk_size)
				c.build(noise, biome_noise, x, z)
				terrain.add_child(c)
				c.add_to_group("terrain")
				chunks[key] = c
	for key in chunks.keys().duplicate():
		var c = chunks[key]
		var d = c.global_position.distance_to(player_pos)
		if d > reach:
			terrain.remove_child(c)
			c.queue_free()
			chunks.erase(key)

func height_at(wx: float, wz: float) -> float:
	if not noise:
		return 0.0
	return noise.noise2d(wx, wz) * 12.0
