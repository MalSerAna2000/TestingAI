extends Node3D
class_name TerrainChunkManager

## Streams procedural valley chunks around both Yumik and NZTBNZ so 1x1 km,
## 10x10 km, and 50x50 km worlds run smoothly on Android without memory spikes.

const CHUNK_SIZE: float = 100.0
const CHUNK_SUBDIVS: int = 20
const PLAYER_RADIUS_CHUNKS: int = 4
const CASTLE_RADIUS_CHUNKS: int = 2
const MAX_CHUNKS_BUILT_PER_FRAME: int = 2

var generator: ValleyGenerator
var half_extent_m: float = 500.0
var min_chunk_idx: int = -5
var max_chunk_idx: int = 4

var active_chunks: Dictionary = {} # Vector2i -> TerrainChunk
var pending_queue: Array[Vector2i] = []

var terrain_material: Material
var water_material: Material
var rock_material: Material
var boulder_resource: Resource

var update_timer: float = 0.0


func initialize_world(seed_val: int, size_km: int) -> void:
	for child in get_children():
		child.queue_free()
	active_chunks.clear()
	pending_queue.clear()

	generator = ValleyGenerator.new(seed_val)
	half_extent_m = float(size_km) * 500.0
	var total_chunks_axis: int = maxi(2, int(round((half_extent_m * 2.0) / CHUNK_SIZE)))
	min_chunk_idx = -total_chunks_axis / 2
	max_chunk_idx = min_chunk_idx + total_chunks_axis - 1

	terrain_material = load("res://assets/materials/mat_terrain_biomes.tres")
	water_material = load("res://assets/materials/mat_valley_water.tres")
	rock_material = load("res://assets/materials/mat_biome_mountain_rock.tres")
	if ResourceLoader.exists("res://assets/models/valley_boulder_cliff.glb"):
		boulder_resource = load("res://assets/models/valley_boulder_cliff.glb")

	_create_world_boundary_walls()

	# Immediately build initial spawn chunks around (0, 0) & (0, -50) synchronously
	for cz in range(-2, 2):
		for cx in range(-2, 2):
			var cc := Vector2i(cx, cz)
			if _is_chunk_in_world(cc):
				_instantiate_chunk_now(cc)


func _create_world_boundary_walls() -> void:
	var border_body := StaticBody3D.new()
	border_body.name = "WorldBorders"
	border_body.collision_layer = 1
	var wall_h: float = 600.0
	var span: float = half_extent_m * 2.0 + 40.0
	var configs := [
		[Vector3(0.0, wall_h * 0.4, -half_extent_m), Vector3(span, wall_h, 4.0)],
		[Vector3(0.0, wall_h * 0.4, half_extent_m), Vector3(span, wall_h, 4.0)],
		[Vector3(-half_extent_m, wall_h * 0.4, 0.0), Vector3(4.0, wall_h, span)],
		[Vector3(half_extent_m, wall_h * 0.4, 0.0), Vector3(4.0, wall_h, span)],
	]
	for cfg in configs:
		var cs := CollisionShape3D.new()
		var bx := BoxShape3D.new()
		bx.size = cfg[1]
		cs.shape = bx
		cs.position = cfg[0]
		border_body.add_child(cs)
	add_child(border_body)


func _is_chunk_in_world(cc: Vector2i) -> bool:
	return cc.x >= min_chunk_idx and cc.x <= max_chunk_idx and cc.y >= min_chunk_idx and cc.y <= max_chunk_idx


func world_to_chunk(pos: Vector3) -> Vector2i:
	return Vector2i(int(floor(pos.x / CHUNK_SIZE)), int(floor(pos.z / CHUNK_SIZE)))


func _process(delta: float) -> void:
	if generator == null:
		return

	var built: int = 0
	while not pending_queue.is_empty() and built < MAX_CHUNKS_BUILT_PER_FRAME:
		var next_cc: Vector2i = pending_queue.pop_front()
		if not active_chunks.has(next_cc) and _is_chunk_in_world(next_cc):
			_instantiate_chunk_now(next_cc)
			built += 1

	update_timer += delta
	if update_timer >= 0.35:
		update_timer = 0.0
		_refresh_streaming_targets()


func _refresh_streaming_targets() -> void:
	var needed: Dictionary = {}
	if is_instance_valid(GameState.player_ref):
		var pc: Vector2i = world_to_chunk(GameState.player_ref.global_position)
		for dz in range(-PLAYER_RADIUS_CHUNKS, PLAYER_RADIUS_CHUNKS + 1):
			for dx in range(-PLAYER_RADIUS_CHUNKS, PLAYER_RADIUS_CHUNKS + 1):
				var cc := Vector2i(pc.x + dx, pc.y + dz)
				if _is_chunk_in_world(cc):
					needed[cc] = true

		# Update water ambient proximity for AudioManager
		var ppos: Vector3 = GameState.player_ref.global_position
		var nearest_water_dist: float = 999.0
		for ang_i in range(8):
			var a: float = float(ang_i) * (TAU / 8.0)
			for r in [0.0, 18.0, 45.0, 85.0]:
				if generator.get_biome_at(ppos.x + cos(a) * r, ppos.z + sin(a) * r) == ValleyGenerator.Biome.WATER:
					nearest_water_dist = minf(nearest_water_dist, r)
		AudioManager.water_proximity_factor = clampf(1.0 - (nearest_water_dist / 85.0), 0.0, 1.0)

	if is_instance_valid(GameState.castle_ref):
		var kc: Vector2i = world_to_chunk(GameState.castle_ref.global_position)
		for dz in range(-CASTLE_RADIUS_CHUNKS, CASTLE_RADIUS_CHUNKS + 1):
			for dx in range(-CASTLE_RADIUS_CHUNKS, CASTLE_RADIUS_CHUNKS + 1):
				var cc := Vector2i(kc.x + dx, kc.y + dz)
				if _is_chunk_in_world(cc):
					needed[cc] = true

	# Unload far chunks
	var to_remove: Array[Vector2i] = []
	for existing_cc: Vector2i in active_chunks.keys():
		if not needed.has(existing_cc):
			to_remove.append(existing_cc)
	for rem_cc in to_remove:
		var ch_node: Node = active_chunks[rem_cc]
		active_chunks.erase(rem_cc)
		if is_instance_valid(ch_node):
			ch_node.queue_free()

	# Enqueue newly required chunks sorted by distance to player
	var player_cc := world_to_chunk(GameState.player_ref.global_position) if is_instance_valid(GameState.player_ref) else Vector2i.ZERO
	var newly_needed: Array[Vector2i] = []
	for req_cc: Vector2i in needed.keys():
		if not active_chunks.has(req_cc) and not pending_queue.has(req_cc):
			newly_needed.append(req_cc)
	newly_needed.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return (a - player_cc).length_squared() < (b - player_cc).length_squared()
	)
	for cc in newly_needed:
		pending_queue.append(cc)


func _instantiate_chunk_now(cc: Vector2i) -> void:
	var chunk := TerrainChunk.new()
	add_child(chunk)
	chunk.build_chunk(
		cc,
		CHUNK_SIZE,
		CHUNK_SUBDIVS,
		generator,
		terrain_material,
		water_material,
		rock_material,
		boulder_resource
	)
	active_chunks[cc] = chunk
