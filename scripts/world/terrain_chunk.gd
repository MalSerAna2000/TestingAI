class_name TerrainChunk
extends Node3D
## Single streamed valley chunk with Jolt static terrain collision,
## non-overlapping water plane + buoyancy zone, and biome-matched rock/tree props.

var chunk_coord: Vector2i = Vector2i.ZERO
var chunk_size: float = 128.0
var has_water: bool = false

var _static_body: StaticBody3D
var _water_area: Area3D


func build_chunk(
	coord: Vector2i,
	p_chunk_size: float,
	grid_steps: int,
	gen: BiomeGenerator,
	terrain_mat: Material,
	water_mat: Material,
	rock_mesh_a: Mesh,
	rock_mesh_b: Mesh,
	rock_mat: Material,
	tree_mesh: Mesh,
	tree_mat: Material,
	spawn_props: bool = true
) -> void:
	chunk_coord = coord
	chunk_size = p_chunk_size
	var origin_x: float = float(coord.x) * p_chunk_size
	var origin_z: float = float(coord.y) * p_chunk_size
	position = Vector3(origin_x, 0.0, origin_z)

	var verts_per_side: int = grid_steps + 1
	var step: float = p_chunk_size / float(grid_steps)

	var positions := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	positions.resize(verts_per_side * verts_per_side)
	normals.resize(verts_per_side * verts_per_side)
	uvs.resize(verts_per_side * verts_per_side)
	colors.resize(verts_per_side * verts_per_side)

	var dominant_rock_cells: int = 0
	var water_cells: int = 0

	for iz in range(verts_per_side):
		var wz: float = origin_z + float(iz) * step
		for ix in range(verts_per_side):
			var wx: float = origin_x + float(ix) * step
			var idx: int = iz * verts_per_side + ix
			var h: float = gen.get_height(wx, wz)
			var b: int = gen.get_biome(wx, wz)

			positions[idx] = Vector3(float(ix) * step, h, float(iz) * step)
			normals[idx] = gen.get_surface_normal(wx, wz, maxf(step * 0.5, 0.75))
			uvs[idx] = Vector2(wx * 0.05, wz * 0.05)

			var mtn_w: float = 1.0 if b == BiomeGenerator.Biome.MOUNTAINS else 0.0
			var shore_w: float = 1.0 - clampf(absf(h - BiomeGenerator.WATER_LEVEL) / 2.2, 0.0, 1.0)
			var ao_w: float = clampf(0.55 + normals[idx].y * 0.45, 0.35, 1.0)
			colors[idx] = Color(mtn_w, shore_w, ao_w, 1.0)

			if b == BiomeGenerator.Biome.MOUNTAINS:
				dominant_rock_cells += 1
			elif b == BiomeGenerator.Biome.WATER:
				water_cells += 1

	has_water = water_cells > 0

	var indices := PackedInt32Array()
	indices.resize(grid_steps * grid_steps * 6)
	var tri_faces := PackedVector3Array()
	tri_faces.resize(grid_steps * grid_steps * 6)

	var ptr: int = 0
	for iz in range(grid_steps):
		for ix in range(grid_steps):
			var i00: int = iz * verts_per_side + ix
			var i10: int = i00 + 1
			var i01: int = i00 + verts_per_side
			var i11: int = i01 + 1

			indices[ptr] = i00
			indices[ptr + 1] = i10
			indices[ptr + 2] = i11
			indices[ptr + 3] = i00
			indices[ptr + 4] = i11
			indices[ptr + 5] = i01

			tri_faces[ptr] = positions[i00]
			tri_faces[ptr + 1] = positions[i10]
			tri_faces[ptr + 2] = positions[i11]
			tri_faces[ptr + 3] = positions[i00]
			tri_faces[ptr + 4] = positions[i11]
			tri_faces[ptr + 5] = positions[i01]
			ptr += 6

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = positions
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices

	var terrain_mesh := ArrayMesh.new()
	terrain_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var mi := MeshInstance3D.new()
	mi.name = "TerrainMesh"
	mi.mesh = terrain_mesh
	mi.material_override = terrain_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mi)

	_static_body = StaticBody3D.new()
	_static_body.name = "TerrainBody"
	_static_body.collision_layer = 1
	_static_body.collision_mask = 0
	var surf_kind := "rock" if dominant_rock_cells > (verts_per_side * verts_per_side) / 2 else "grass"
	_static_body.set_meta("surface_kind", surf_kind)
	_static_body.set_meta("climbable", true)
	_static_body.set_meta("grip_factor", 0.94 if surf_kind == "rock" else 0.78)

	var pmat := PhysicsMaterial.new()
	pmat.friction = 0.86
	pmat.bounce = 0.05
	_static_body.physics_material_override = pmat

	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(tri_faces)
	var col := CollisionShape3D.new()
	col.shape = shape
	_static_body.add_child(col)
	add_child(_static_body)

	# Strictly non-overlapping water surface ONLY when BIOME_WATER exists in this chunk
	if has_water:
		var wmesh := PlaneMesh.new()
		wmesh.size = Vector2(p_chunk_size, p_chunk_size)
		wmesh.subdivide_width = 12
		wmesh.subdivide_depth = 12

		var wmi := MeshInstance3D.new()
		wmi.name = "WaterSurface"
		wmi.mesh = wmesh
		wmi.material_override = water_mat
		wmi.position = Vector3(p_chunk_size * 0.5, BiomeGenerator.WATER_LEVEL, p_chunk_size * 0.5)
		wmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(wmi)

		_water_area = Area3D.new()
		_water_area.name = "WaterVolume"
		_water_area.collision_layer = 2
		_water_area.collision_mask = 16 | 32 | 4
		_water_area.set_meta("surface_kind", "water")
		var wbox := BoxShape3D.new()
		wbox.size = Vector3(p_chunk_size, 8.0, p_chunk_size)
		var wcol := CollisionShape3D.new()
		wcol.shape = wbox
		wcol.position = Vector3(p_chunk_size * 0.5, BiomeGenerator.WATER_LEVEL - 4.0, p_chunk_size * 0.5)
		_water_area.add_child(wcol)
		add_child(_water_area)

	if spawn_props:
		_scatter_biome_props(coord, origin_x, origin_z, p_chunk_size, gen, rock_mesh_a, rock_mesh_b, rock_mat, tree_mesh, tree_mat)


func _scatter_biome_props(
	coord: Vector2i,
	origin_x: float,
	origin_z: float,
	p_chunk_size: float,
	gen: BiomeGenerator,
	rock_mesh_a: Mesh,
	rock_mesh_b: Mesh,
	rock_mat: Material,
	tree_mesh: Mesh,
	tree_mat: Material
) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(gen.seed_value) ^ (coord.x * 73856093) ^ (coord.y * 19349663)

	var tree_transforms: Array[Transform3D] = []

	for _i in range(10):
		var lx: float = rng.randf_range(6.0, p_chunk_size - 6.0)
		var lz: float = rng.randf_range(6.0, p_chunk_size - 6.0)
		var wx: float = origin_x + lx
		var wz: float = origin_z + lz

		# Keep immediate castle landing apron clear
		if Vector2(wx, wz - 12.0).length() < 46.0:
			continue

		var biome: int = gen.get_biome(wx, wz)
		var h: float = gen.get_height(wx, wz)

		if biome == BiomeGenerator.Biome.MOUNTAINS and rock_mesh_a != null and rock_mesh_b != null:
			var rbody := StaticBody3D.new()
			rbody.collision_layer = 1
			rbody.collision_mask = 0
			rbody.position = Vector3(lx, h - 0.55, lz)
			rbody.rotation.y = rng.randf() * TAU
			var sc: float = rng.randf_range(0.75, 1.85)
			rbody.set_meta("surface_kind", "rock")
			rbody.set_meta("climbable", true)
			rbody.set_meta("grip_factor", 0.96)

			var rmi := MeshInstance3D.new()
			var use_tall: bool = rng.randf() > 0.45
			rmi.mesh = rock_mesh_b if use_tall else rock_mesh_a
			rmi.material_override = rock_mat
			rmi.scale = Vector3.ONE * sc
			rbody.add_child(rmi)

			var rshape := SphereShape3D.new()
			rshape.radius = (3.4 if use_tall else 2.2) * sc
			var rcol := CollisionShape3D.new()
			rcol.shape = rshape
			rbody.add_child(rcol)
			add_child(rbody)

		elif biome == BiomeGenerator.Biome.PLAINS and tree_mesh != null and rng.randf() < 0.55:
			var tsc: float = rng.randf_range(0.85, 1.55)
			var basis := Basis.IDENTITY.rotated(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * tsc)
			tree_transforms.append(Transform3D(basis, Vector3(lx, h - 0.15, lz)))

	if not tree_transforms.is_empty() and tree_mesh != null:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = tree_mesh
		mm.instance_count = tree_transforms.size()
		for ti in range(tree_transforms.size()):
			mm.set_instance_transform(ti, tree_transforms[ti])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "PlainsTrees"
		mmi.multimesh = mm
		mmi.material_override = tree_mat
		add_child(mmi)
