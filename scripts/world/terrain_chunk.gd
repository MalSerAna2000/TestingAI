extends StaticBody3D
class_name TerrainChunk

## Single streamed terrain chunk (100x100m) with non-overlapping biome vertex weights,
## exact Jolt ConcavePolygonShape3D collision, optional non-overlapping Water surface mesh
## + AeroWaterAtmosphere3D buoyancy, and Mountain climbable cliff outcrops.

const AeroWaterAtmosphereScript = preload("res://addons/godot_aerodynamic_physics/core/aero_atmosphere_3d/aero_water_atmosphere_3d/aero_water_atmosphere_3d.gd")

var chunk_coord := Vector2i.ZERO
var has_water: bool = false
var has_mountains: bool = false


func build_chunk(
	p_coord: Vector2i,
	chunk_size: float,
	subdivs: int,
	gen: ValleyGenerator,
	terrain_mat: Material,
	water_mat: Material,
	rock_mat: Material,
	boulder_scene_or_mesh: Resource
) -> void:
	chunk_coord = p_coord
	name = "Chunk_%d_%d" % [p_coord.x, p_coord.y]
	collision_layer = 1 # Layer 1: WorldTerrain
	collision_mask = 0

	var origin_x: float = float(p_coord.x) * chunk_size
	var origin_z: float = float(p_coord.y) * chunk_size
	position = Vector3(origin_x, 0.0, origin_z)

	var step: float = chunk_size / float(subdivs)
	var stride: int = subdivs + 1
	var heights := PackedFloat32Array()
	heights.resize(stride * stride)
	var biomes := PackedInt32Array()
	biomes.resize(stride * stride)

	for iz in range(stride):
		var wz: float = origin_z + float(iz) * step
		for ix in range(stride):
			var wx: float = origin_x + float(ix) * step
			var hb: Vector2 = gen.get_height_and_biome(wx, wz)
			var idx: int = iz * stride + ix
			heights[idx] = hb.x
			var b_id: int = int(hb.y)
			biomes[idx] = b_id
			if b_id == ValleyGenerator.Biome.WATER:
				has_water = true
			elif b_id == ValleyGenerator.Biome.MOUNTAINS:
				has_mountains = true

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var faces := PackedVector3Array()
	faces.resize(subdivs * subdivs * 6)
	var face_write: int = 0

	var water_st := SurfaceTool.new()
	var water_quad_count: int = 0
	if has_water:
		water_st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for iz in range(subdivs):
		for ix in range(subdivs):
			var i00: int = iz * stride + ix
			var i10: int = i00 + 1
			var i01: int = i00 + stride
			var i11: int = i01 + 1

			var p00 := Vector3(float(ix) * step, heights[i00], float(iz) * step)
			var p10 := Vector3(float(ix + 1) * step, heights[i10], float(iz) * step)
			var p01 := Vector3(float(ix) * step, heights[i01], float(iz + 1) * step)
			var p11 := Vector3(float(ix + 1) * step, heights[i11], float(iz + 1) * step)

			var c00 := _biome_to_color(biomes[i00])
			var c10 := _biome_to_color(biomes[i10])
			var c01 := _biome_to_color(biomes[i01])
			var c11 := _biome_to_color(biomes[i11])

			# Triangle 1: p00, p10, p01
			_emit_tri(st, p00, p10, p01, c00, c10, c01, chunk_size)
			# Triangle 2: p10, p11, p01
			_emit_tri(st, p10, p11, p01, c10, c11, c01, chunk_size)

			faces[face_write] = p00
			faces[face_write + 1] = p10
			faces[face_write + 2] = p01
			faces[face_write + 3] = p10
			faces[face_write + 4] = p11
			faces[face_write + 5] = p01
			face_write += 6

			# Water mesh ONLY over depressed Water biome cells so zones never overlap/glitch
			if has_water and (
				biomes[i00] == ValleyGenerator.Biome.WATER
				or biomes[i10] == ValleyGenerator.Biome.WATER
				or biomes[i01] == ValleyGenerator.Biome.WATER
				or biomes[i11] == ValleyGenerator.Biome.WATER
			):
				if minf(minf(p00.y, p10.y), minf(p01.y, p11.y)) < ValleyGenerator.WATER_LEVEL_Y - 0.05:
					var w00 := Vector3(p00.x, ValleyGenerator.WATER_LEVEL_Y, p00.z)
					var w10 := Vector3(p10.x, ValleyGenerator.WATER_LEVEL_Y, p10.z)
					var w01 := Vector3(p01.x, ValleyGenerator.WATER_LEVEL_Y, p01.z)
					var w11 := Vector3(p11.x, ValleyGenerator.WATER_LEVEL_Y, p11.z)
					_emit_water_quad(water_st, w00, w10, w01, w11, chunk_size)
					water_quad_count += 1

	st.generate_normals()
	st.generate_tangents()
	var terrain_mesh: ArrayMesh = st.commit()
	var mi := MeshInstance3D.new()
	mi.name = "TerrainMesh"
	mi.mesh = terrain_mesh
	mi.material_override = terrain_mat
	add_child(mi)

	var col_shape := CollisionShape3D.new()
	col_shape.name = "TerrainCollision"
	var concave := ConcavePolygonShape3D.new()
	concave.set_faces(faces)
	col_shape.shape = concave
	add_child(col_shape)

	# Track mountain tag on chunk if steep cliffs present
	if has_mountains:
		add_to_group("climbable_rock")
		_spawn_mountain_outcrops(chunk_size, gen, rock_mat, boulder_scene_or_mesh)

	if water_quad_count > 0:
		var w_mesh: ArrayMesh = water_st.commit()
		var w_mi := MeshInstance3D.new()
		w_mi.name = "WaterSurface"
		w_mi.mesh = w_mesh
		w_mi.material_override = water_mat
		w_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(w_mi)

		# Aerodynamic water buoyancy volume for NZTBNZ if blown into lakes/rivers
		var water_atmo: Area3D = AeroWaterAtmosphereScript.new()
		water_atmo.name = "ChunkWaterAtmosphere"
		var w_col := CollisionShape3D.new()
		var w_box := BoxShape3D.new()
		w_box.size = Vector3(chunk_size, 24.0, chunk_size)
		w_col.shape = w_box
		w_col.position = Vector3(chunk_size * 0.5, -12.0, chunk_size * 0.5)
		water_atmo.add_child(w_col)
		add_child(water_atmo)


func _biome_to_color(b: int) -> Color:
	match b:
		ValleyGenerator.Biome.WATER:
			return Color(0.0, 1.0, 0.0, 1.0)
		ValleyGenerator.Biome.MOUNTAINS:
			return Color(0.0, 0.0, 1.0, 1.0)
		_:
			return Color(1.0, 0.0, 0.0, 1.0)


func _emit_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color, csize: float) -> void:
	st.set_color(ca)
	st.set_uv(Vector2(a.x / csize, a.z / csize))
	st.add_vertex(a)
	st.set_color(cb)
	st.set_uv(Vector2(b.x / csize, b.z / csize))
	st.add_vertex(b)
	st.set_color(cc)
	st.set_uv(Vector2(c.x / csize, c.z / csize))
	st.add_vertex(c)


func _emit_water_quad(wst: SurfaceTool, w00: Vector3, w10: Vector3, w01: Vector3, w11: Vector3, csize: float) -> void:
	for p in [w00, w10, w01, w10, w11, w01]:
		wst.set_normal(Vector3.UP)
		wst.set_uv(Vector2(p.x / csize, p.z / csize))
		wst.add_vertex(p)


func _spawn_mountain_outcrops(chunk_size: float, gen: ValleyGenerator, rock_mat: Material, boulder_res: Resource) -> void:
	var h_seed: int = abs((chunk_coord.x * 73856093) ^ (chunk_coord.y * 19349663) ^ gen.seed_value)
	var rng := RandomNumberGenerator.new()
	rng.seed = h_seed
	for i in range(2):
		var lx: float = rng.randf_range(16.0, chunk_size - 16.0)
		var lz: float = rng.randf_range(16.0, chunk_size - 16.0)
		var wx: float = position.x + lx
		var wz: float = position.z + lz
		var hb: Vector2 = gen.get_height_and_biome(wx, wz)
		if int(hb.y) != ValleyGenerator.Biome.MOUNTAINS:
			continue
		var cliff := StaticBody3D.new()
		cliff.name = "CliffBoulder_%d" % i
		cliff.collision_layer = 1
		cliff.add_to_group("climbable_rock")
		cliff.position = Vector3(lx, hb.x - 1.5, lz)
		cliff.rotation.y = rng.randf() * TAU
		var s_xz: float = rng.randf_range(7.0, 14.0)
		var s_y: float = rng.randf_range(9.0, 18.0)

		var col := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(s_xz, s_y, s_xz * 0.85)
		col.shape = box
		col.position = Vector3(0.0, s_y * 0.5, 0.0)
		cliff.add_child(col)

		if boulder_res is PackedScene:
			var inst: Node = (boulder_res as PackedScene).instantiate()
			if inst is Node3D:
				(inst as Node3D).scale = Vector3(s_xz / 14.0, s_y / 12.0, (s_xz * 0.85) / 11.0)
				_apply_mat_recursive(inst, rock_mat)
			cliff.add_child(inst)
		else:
			var mi := MeshInstance3D.new()
			var bmesh := BoxMesh.new()
			bmesh.size = box.size
			mi.mesh = bmesh
			mi.position = col.position
			mi.material_override = rock_mat
			cliff.add_child(mi)
		add_child(cliff)


func _apply_mat_recursive(n: Node, mat: Material) -> void:
	if n is MeshInstance3D:
		(n as MeshInstance3D).material_override = mat
	for ch in n.get_children():
		_apply_mat_recursive(ch, mat)
