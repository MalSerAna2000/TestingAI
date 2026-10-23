class_name ChunkManager
extends Node3D
## Dynamic streaming terrain manager supporting 1x1 km, 10x10 km, and 50x50 km worlds.
## Keeps collision chunks active around BOTH Yumik AND the flying/wind-blown InflatableCastle!

const CHUNK_SIZE: float = 128.0
const VIEW_RADIUS_CHUNKS: int = 3
const CASTLE_SAFETY_RADIUS_CHUNKS: int = 1
const MAX_CHUNKS_BUILT_PER_FRAME: int = 2

var biome_generator: BiomeGenerator
var player_target: Node3D
var castle_target: Node3D

var _loaded_chunks: Dictionary = {} # Vector2i -> TerrainChunk
var _pending_queue: Array[Vector2i] = []

var _min_chunk: int = -4
var _max_chunk: int = 3

var _terrain_mat: Material
var _water_mat: Material
var _rock_mat: Material
var _tree_mat: Material
var _rock_mesh_a: Mesh
var _rock_mesh_b: Mesh
var _tree_mesh: Mesh
var _boundary_root: StaticBody3D

var _refresh_timer: float = 0.0


func initialize_world(seed_val: int, world_size_meters: float, p_player: Node3D, p_castle: Node3D) -> void:
	clear_all_chunks()

	player_target = p_player
	castle_target = p_castle
	biome_generator = BiomeGenerator.new(seed_val, world_size_meters)

	var half_m: float = world_size_meters * 0.5
	_min_chunk = int(floor(-half_m / CHUNK_SIZE))
	_max_chunk = int(ceil(half_m / CHUNK_SIZE)) - 1

	_terrain_mat = load("res://assets/materials/mat_terrain_shader.tres")
	_water_mat = load("res://assets/materials/mat_water_shader.tres")
	_rock_mat = load("res://assets/materials/mat_mountain_rock.tres")
	_tree_mat = load("res://assets/materials/mat_pine_foliage.tres")
	_rock_mesh_a = load("res://assets/models/mountain_cliff_rock_a.obj")
	_rock_mesh_b = load("res://assets/models/mountain_cliff_rock_b.obj")
	_tree_mesh = load("res://assets/models/valley_pine_tree.obj")

	_build_world_boundary_colliders(half_m)

	# Build immediate spawn neighborhood synchronously so physics floor exists on frame 1!
	var center_coord := world_to_chunk(Vector3.ZERO)
	for dz in range(-2, 3):
		for dx in range(-2, 3):
			var c := Vector2i(center_coord.x + dx, center_coord.y + dz)
			if _is_chunk_in_world(c):
				_spawn_chunk_immediate(c)

	_refresh_streaming_targets()


func _build_world_boundary_colliders(half_m: float) -> void:
	if is_instance_valid(_boundary_root):
		_boundary_root.queue_free()
	_boundary_root = StaticBody3D.new()
	_boundary_root.name = "WorldBorders"
	_boundary_root.collision_layer = 1
	_boundary_root.collision_mask = 0
	add_child(_boundary_root)

	var wall_defs := [
		[Vector3(0.0, 250.0, -half_m), Vector3(half_m * 2.1, 600.0, 8.0)],
		[Vector3(0.0, 250.0, half_m), Vector3(half_m * 2.1, 600.0, 8.0)],
		[Vector3(-half_m, 250.0, 0.0), Vector3(8.0, 600.0, half_m * 2.1)],
		[Vector3(half_m, 250.0, 0.0), Vector3(8.0, 600.0, half_m * 2.1)],
	]
	for wd in wall_defs:
		var cs := CollisionShape3D.new()
		var bx := BoxShape3D.new()
		bx.size = wd[1]
		cs.shape = bx
		cs.position = wd[0]
		_boundary_root.add_child(cs)


func world_to_chunk(world_pos: Vector3) -> Vector2i:
	return Vector2i(int(floor(world_pos.x / CHUNK_SIZE)), int(floor(world_pos.z / CHUNK_SIZE)))


func _is_chunk_in_world(c: Vector2i) -> bool:
	return c.x >= _min_chunk and c.x <= _max_chunk and c.y >= _min_chunk and c.y <= _max_chunk


func _process(delta: float) -> void:
	_refresh_timer += delta
	if _refresh_timer >= 0.35:
		_refresh_timer = 0.0
		_refresh_streaming_targets()

	var built: int = 0
	while not _pending_queue.is_empty() and built < MAX_CHUNKS_BUILT_PER_FRAME:
		var next_coord: Vector2i = _pending_queue.pop_front()
		if not _loaded_chunks.has(next_coord) and _is_chunk_in_world(next_coord):
			_spawn_chunk_immediate(next_coord)
			built += 1

	# Update water ambient audio proximity around player
	if is_instance_valid(player_target) and biome_generator != null:
		var px: float = player_target.global_position.x
		var pz: float = player_target.global_position.z
		var m_val: float = biome_generator.get_biome_scalar(px, pz)
		AudioManager.water_proximity_weight = clampf(1.0 - maxf(m_val - BiomeGenerator.WATER_THRESHOLD, 0.0) / 0.16, 0.0, 1.0)


func _refresh_streaming_targets() -> void:
	var wanted: Dictionary = {}

	if is_instance_valid(player_target):
		var pc := world_to_chunk(player_target.global_position)
		for dz in range(-VIEW_RADIUS_CHUNKS, VIEW_RADIUS_CHUNKS + 1):
			for dx in range(-VIEW_RADIUS_CHUNKS, VIEW_RADIUS_CHUNKS + 1):
				var cc := Vector2i(pc.x + dx, pc.y + dz)
				if _is_chunk_in_world(cc):
					wanted[cc] = true

	if is_instance_valid(castle_target):
		var kc := world_to_chunk(castle_target.global_position)
		for dz in range(-CASTLE_SAFETY_RADIUS_CHUNKS, CASTLE_SAFETY_RADIUS_CHUNKS + 1):
			for dx in range(-CASTLE_SAFETY_RADIUS_CHUNKS, CASTLE_SAFETY_RADIUS_CHUNKS + 1):
				var cc2 := Vector2i(kc.x + dx, kc.y + dz)
				if _is_chunk_in_world(cc2):
					wanted[cc2] = true

	# Unload distant chunks smoothly
	var to_unload: Array[Vector2i] = []
	for existing_coord in _loaded_chunks.keys():
		if not wanted.has(existing_coord):
			to_unload.append(existing_coord)
	for uc in to_unload:
		var node: TerrainChunk = _loaded_chunks[uc]
		_loaded_chunks.erase(uc)
		if is_instance_valid(node):
			node.queue_free()

	for wc in wanted.keys():
		if not _loaded_chunks.has(wc) and not _pending_queue.has(wc):
			_pending_queue.append(wc)


func _spawn_chunk_immediate(coord: Vector2i) -> void:
	var chunk := TerrainChunk.new()
	chunk.name = "Chunk_%d_%d" % [coord.x, coord.y]
	var dist_from_player: int = 0
	if is_instance_valid(player_target):
		var pc := world_to_chunk(player_target.global_position)
		dist_from_player = maxi(absi(coord.x - pc.x), absi(coord.y - pc.y))
	var steps: int = 32 if dist_from_player <= 1 else 20
	add_child(chunk)
	chunk.build_chunk(
		coord,
		CHUNK_SIZE,
		steps,
		biome_generator,
		_terrain_mat,
		_water_mat,
		_rock_mesh_a,
		_rock_mesh_b,
		_rock_mat,
		_tree_mesh,
		_tree_mat,
		dist_from_player <= 2
	)
	_loaded_chunks[coord] = chunk


func get_loaded_chunk_count() -> int:
	return _loaded_chunks.size()


func clear_all_chunks() -> void:
	_pending_queue.clear()
	for c in _loaded_chunks.values():
		if is_instance_valid(c):
			c.queue_free()
	_loaded_chunks.clear()
