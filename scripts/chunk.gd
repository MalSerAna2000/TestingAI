extends StaticBody3D
class_name Chunk

# ----------------------------------------------------------------
# Один чанк ландшафта: ArrayMesh по карте высот FastNoiseLite,
# биомы по цвету вершин (трава / вода / горы), три角ная коллизия.
# ----------------------------------------------------------------

func build(noise: FastNoiseLite, biome_noise: FastNoiseLite, gx: int, gz: int) -> void:
	var size: float = 64.0
	var res: int = 32
	var half: float = size / 2.0
	var offset: Vector3 = Vector3(gx * size, 0, gz * size)
	var verts: PackedVector3Array = PackedVector3Array()
	var cols: PackedColorArray = PackedColorArray()
	var idx: PackedInt32Array = PackedInt32Array()
	var faces: PackedVector3Array = PackedVector3Array()

	var water_level: float = 1.6
	var mountain_level: float = 5.0

	for z in range(res + 1):
		for x in range(res + 1):
			var wx: float = offset.x + (x / res) * size - half
			var wz: float = offset.z + (z / res) * size - half
			var n: float = noise.noise2d(wx, wz)
			var b: float = biome_noise.noise2d(wx + 1000.0, wz + 1000.0)
			var h: float = n * 12.0
			var col: Color = Color(0.42, 0.72, 0.36)  # равнины
			if h < water_level:
				h = water_level - 0.15
				col = Color(0.18, 0.42, 0.62)  # вода
			elif b > 0.22 and h > mountain_level:
				h = clamp(h, 0.0, 16.0)
				col = Color(0.55, 0.55, 0.55)  # горы
			verts.push_back(Vector3(wx, h, wz))
			cols.push_back(col)

	for z in range(res):
		for x in range(res):
			var i0: int = z * (res + 1) + x
			var i1: int = i0 + 1
			var i2: int = i0 + (res + 1)
			var i3: int = i2 + 1
			idx.push_back(i0)
			idx.push_back(i2)
			idx.push_back(i1)
			idx.push_back(i1)
			idx.push_back(i2)
			idx.push_back(i3)
			faces.push_back(verts[i0])
			faces.push_back(verts[i2])
			faces.push_back(verts[i1])
			faces.push_back(verts[i1])
			faces.push_back(verts[i2])
			faces.push_back(verts[i3])

	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_INDEX] = idx
	arr[Mesh.ARRAY_COLOR] = cols
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	get_node("Mesh").mesh = mesh
	var shape: ConcavePolygonShape3D = ConcavePolygonShape3D.new()
	shape.faces = faces
	get_node("Shape").shape = shape
