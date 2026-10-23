class_name HempRope75m
extends Node3D
## Physical 75.0-meter non-inflatable braided hemp rope hanging from a 50m castle corner tower.
## Built with 15 Jolt RigidBody3D capsule segments (15 x 5.0m = 75.0m) chained via PinJoint3D:
## - Top 50m hangs down the tower wall
## - Remaining 25m rests & trails across the ground ready for Yumik to grab and climb!

const TOTAL_LENGTH: float = 75.0
const SEGMENT_COUNT: int = 15
const SEGMENT_LENGTH: float = TOTAL_LENGTH / float(SEGMENT_COUNT) # 5.0 m exact
const ROPE_RADIUS: float = 0.20

var castle_body: RigidBody3D
var tower_anchor_local: Vector3 = Vector3.ZERO
var segments: Array[RigidBody3D] = []
var joints: Array[PinJoint3D] = []

var _mesh_instance: MeshInstance3D
var _imm_mesh: ImmediateMesh
var _rope_mat: Material


func setup_rope(p_castle: RigidBody3D, p_anchor_local: Vector3, ground_y: float) -> void:
	castle_body = p_castle
	tower_anchor_local = p_anchor_local
	_rope_mat = load("res://assets/materials/mat_hemp_rope.tres")

	_imm_mesh = ImmediateMesh.new()
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = "BraidedRopeMesh"
	_mesh_instance.mesh = _imm_mesh
	_mesh_instance.material_override = _rope_mat
	_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(_mesh_instance)

	var anchor_world: Vector3 = castle_body.to_global(tower_anchor_local)
	var outward_dir := Vector3(signf(tower_anchor_local.x), 0.0, signf(tower_anchor_local.z)).normalized()

	var pmat := PhysicsMaterial.new()
	pmat.friction = 0.92
	pmat.bounce = 0.04

	var prev_pos: Vector3 = anchor_world
	for i in range(SEGMENT_COUNT):
		var seg := RigidBody3D.new()
		seg.name = "RopeSeg_%02d" % i
		seg.collision_layer = 8 # Layer 4: CastleRopes
		seg.collision_mask = 1 | 4 # Collides with Terrain & Castle
		seg.mass = 5.5
		seg.physics_material_override = pmat
		seg.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
		seg.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
		seg.linear_damp = 0.85
		seg.angular_damp = 1.65
		seg.can_sleep = false

		seg.set_meta("surface_kind", "rope")
		seg.set_meta("climbable", true)
		seg.set_meta("grip_factor", 0.95)
		seg.set_meta("rope_owner", self)
		seg.set_meta("rope_index", i)

		var next_pos: Vector3 = prev_pos + Vector3(0.0, -SEGMENT_LENGTH, 0.0)
		# Lay excess rope (> 50m drop) cleanly outward across the ground surface so zero initial penetration occurs!
		if next_pos.y < ground_y + ROPE_RADIUS + 0.15:
			next_pos = Vector3(prev_pos.x, maxf(prev_pos.y, ground_y + ROPE_RADIUS + 0.18), prev_pos.z) + outward_dir * SEGMENT_LENGTH
		var mid_pos: Vector3 = (prev_pos + next_pos) * 0.5

		var cap := CapsuleShape3D.new()
		cap.radius = ROPE_RADIUS
		cap.height = SEGMENT_LENGTH * 0.94
		var cshape := CollisionShape3D.new()
		cshape.shape = cap
		seg.add_child(cshape)

		add_child(seg)
		seg.global_position = mid_pos
		var seg_dir: Vector3 = (next_pos - prev_pos).normalized()
		if absf(seg_dir.dot(Vector3.UP)) < 0.99:
			seg.global_basis = Basis.looking_at(seg_dir, Vector3.UP).rotated(Vector3.RIGHT, PI * 0.5)

		var pj := PinJoint3D.new()
		pj.name = "RopePin_%02d" % i
		add_child(pj)
		pj.global_position = prev_pos
		pj.set_param(PinJoint3D.PARAM_BIAS, 0.88)
		pj.set_param(PinJoint3D.PARAM_DAMPING, 1.25)
		pj.set_param(PinJoint3D.PARAM_IMPULSE_CLAMP, 0.0)
		if i == 0:
			pj.node_a = castle_body.get_path()
		else:
			pj.node_a = segments[i - 1].get_path()
		pj.node_b = seg.get_path()
		pj.exclude_nodes_from_collision = true

		segments.append(seg)
		joints.append(pj)
		prev_pos = next_pos


func teleport_with_castle(ground_y: float) -> void:
	if not is_instance_valid(castle_body) or segments.is_empty():
		return
	var anchor_world: Vector3 = castle_body.to_global(tower_anchor_local)
	var outward_dir := Vector3(signf(tower_anchor_local.x), 0.0, signf(tower_anchor_local.z)).normalized()
	var prev_pos: Vector3 = anchor_world
	for i in range(segments.size()):
		var seg: RigidBody3D = segments[i]
		var next_pos: Vector3 = prev_pos + Vector3(0.0, -SEGMENT_LENGTH, 0.0)
		if next_pos.y < ground_y + ROPE_RADIUS + 0.2:
			next_pos = Vector3(prev_pos.x, maxf(prev_pos.y, ground_y + ROPE_RADIUS + 0.22), prev_pos.z) + outward_dir * SEGMENT_LENGTH
		seg.linear_velocity = Vector3.ZERO
		seg.angular_velocity = Vector3.ZERO
		seg.global_position = (prev_pos + next_pos) * 0.5
		prev_pos = next_pos


func get_climb_position_along_rope(current_world_pos: Vector3, climb_delta_meters: float) -> Dictionary:
	if segments.is_empty() or not is_instance_valid(castle_body):
		return {"pos": current_world_pos, "body": castle_body}

	var pts: Array[Vector3] = [castle_body.to_global(tower_anchor_local)]
	for s in segments:
		if is_instance_valid(s):
			pts.append(s.global_position)

	# Project current position to polyline (index 0 = top at 50m tower, last = ground tip at 75m!)
	var best_dist_sq: float = INF
	var best_arc: float = 0.0
	var cumulative: Array[float] = [0.0]
	for k in range(1, pts.size()):
		cumulative.append(cumulative[k - 1] + pts[k - 1].distance_to(pts[k]))

	for k in range(pts.size() - 1):
		var a: Vector3 = pts[k]
		var b: Vector3 = pts[k + 1]
		var ab: Vector3 = b - a
		var len_sq: float = maxf(ab.length_squared(), 0.0001)
		var t: float = clampf((current_world_pos - a).dot(ab) / len_sq, 0.0, 1.0)
		var proj: Vector3 = a + ab * t
		var d2: float = current_world_pos.distance_squared_to(proj)
		if d2 < best_dist_sq:
			best_dist_sq = d2
			best_arc = cumulative[k] + t * sqrt(len_sq)

	# Climbing UP (+climb_delta_meters) moves toward arc = 0.0 (50m tower summit!)
	var target_arc: float = clampf(best_arc - climb_delta_meters, 0.0, cumulative.back())
	for k in range(pts.size() - 1):
		if target_arc <= cumulative[k + 1] or k == pts.size() - 2:
			var seg_len: float = maxf(cumulative[k + 1] - cumulative[k], 0.001)
			var lt: float = clampf((target_arc - cumulative[k]) / seg_len, 0.0, 1.0)
			var seg_body: RigidBody3D = segments[mini(k, segments.size() - 1)]
			return {
				"pos": pts[k].lerp(pts[k + 1], lt),
				"body": seg_body,
				"at_top": target_arc <= 0.65,
			}

	return {"pos": pts[0], "body": segments[0], "at_top": true}


func _physics_process(_delta: float) -> void:
	for s in segments:
		if is_instance_valid(s):
			var w: Vector3 = WindManager.get_wind_at_position(s.global_position)
			var rel: Vector3 = w - s.linear_velocity
			s.apply_central_force(rel * rel.length() * 0.42)


func _process(_delta: float) -> void:
	_rebuild_tube_mesh()


func _rebuild_tube_mesh() -> void:
	if _imm_mesh == null or not is_instance_valid(castle_body) or segments.is_empty():
		return
	_imm_mesh.clear_surfaces()

	var pts: Array[Vector3] = [to_local(castle_body.to_global(tower_anchor_local))]
	for s in segments:
		if is_instance_valid(s):
			pts.append(to_local(s.global_position))
	if pts.size() < 2:
		return

	var sides: int = 6
	_imm_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(pts.size() - 1):
		var p0: Vector3 = pts[i]
		var p1: Vector3 = pts[i + 1]
		var dir: Vector3 = (p1 - p0).normalized()
		if dir.length_squared() < 0.01:
			dir = Vector3.DOWN
		var ref := Vector3.FORWARD if absf(dir.dot(Vector3.UP)) > 0.92 else Vector3.UP
		var n1: Vector3 = dir.cross(ref).normalized()
		var n2: Vector3 = dir.cross(n1).normalized()

		var v0: float = float(i) / float(pts.size() - 1)
		var v1: float = float(i + 1) / float(pts.size() - 1)

		for s_idx in range(sides):
			var a0: float = (float(s_idx) / float(sides)) * TAU
			var a1: float = (float(s_idx + 1) / float(sides)) * TAU
			var r00: Vector3 = (n1 * cos(a0) + n2 * sin(a0)) * ROPE_RADIUS
			var r01: Vector3 = (n1 * cos(a1) + n2 * sin(a1)) * ROPE_RADIUS

			_imm_mesh.surface_set_normal(r00.normalized())
			_imm_mesh.surface_set_uv(Vector2(float(s_idx) / float(sides), v0))
			_imm_mesh.surface_add_vertex(p0 + r00)

			_imm_mesh.surface_set_normal(r01.normalized())
			_imm_mesh.surface_set_uv(Vector2(float(s_idx + 1) / float(sides), v0))
			_imm_mesh.surface_add_vertex(p0 + r01)

			_imm_mesh.surface_set_normal(r01.normalized())
			_imm_mesh.surface_set_uv(Vector2(float(s_idx + 1) / float(sides), v1))
			_imm_mesh.surface_add_vertex(p1 + r01)

			_imm_mesh.surface_set_normal(r00.normalized())
			_imm_mesh.surface_set_uv(Vector2(float(s_idx) / float(sides), v0))
			_imm_mesh.surface_add_vertex(p0 + r00)

			_imm_mesh.surface_set_normal(r01.normalized())
			_imm_mesh.surface_set_uv(Vector2(float(s_idx + 1) / float(sides), v1))
			_imm_mesh.surface_add_vertex(p1 + r01)

			_imm_mesh.surface_set_normal(r00.normalized())
			_imm_mesh.surface_set_uv(Vector2(float(s_idx) / float(sides), v1))
			_imm_mesh.surface_add_vertex(p1 + r00)

	_imm_mesh.surface_end()
