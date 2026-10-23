extends Node3D
class_name HempRope75m

## Physical 75-meter hemp rope (15 segments x 5.0m = 75.0m) hanging from the 50m
## corner tower peak. The extra 25m drapes onto the ground so Yumik can grab & climb.

const TOTAL_LENGTH_M: float = 75.0
const SEGMENT_COUNT: int = 15
const SEG_LEN: float = TOTAL_LENGTH_M / float(SEGMENT_COUNT) # 5.0m
const ROPE_RADIUS: float = 0.14

var segments: Array[RigidBody3D] = []
var joints: Array[PinJoint3D] = []


func build_rope(castle_body: RigidBody3D, tower_top_local: Vector3, outward_dir: Vector3, rope_id: int) -> void:
	name = "HempRope75m_%d" % rope_id
	var rope_mat: Material = load("res://assets/materials/mat_hemp_rope.tres")
	var phys_mat := PhysicsMaterial.new()
	phys_mat.friction = 0.96
	phys_mat.bounce = 0.01 # Non-inflatable ordinary hemp rope

	var prev_body: PhysicsBody3D = castle_body
	var world_anchor_top: Vector3 = castle_body.to_global(tower_top_local)

	for i in range(SEGMENT_COUNT):
		var seg := RigidBody3D.new()
		seg.name = "RopeSeg_%d_%d" % [rope_id, i]
		seg.collision_layer = 16 # Layer 5: ClimbableRopes
		seg.collision_mask = 1 # Collides with WorldTerrain so lower 25m rests on ground!
		seg.mass = 3.2
		seg.linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
		seg.angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
		seg.linear_damp = 1.4
		seg.angular_damp = 2.8
		seg.physics_material_override = phys_mat
		seg.add_to_group("climbable_rope")
		seg.set_meta("rope_id", rope_id)
		seg.set_meta("seg_index", i)

		# First 9 segments hang vertically down 45m; remaining 6 segments (30m) coil outward on ground
		var seg_center: Vector3
		var seg_rot := Vector3.ZERO
		if i < 9:
			seg_center = world_anchor_top + Vector3(0.0, -(float(i) + 0.5) * SEG_LEN, 0.0) + outward_dir * (0.35 * float(i + 1))
		else:
			var ground_idx: int = i - 9
			var base_ground := world_anchor_top + Vector3(0.0, -45.5, 0.0) + outward_dir * 3.5
			seg_center = base_ground + outward_dir * ((float(ground_idx) + 0.5) * SEG_LEN * 0.92) + Vector3(0.0, 0.35, 0.0)
			seg_rot = Vector3(0.0, 0.0, deg_to_rad(82.0)) if absf(outward_dir.x) > 0.5 else Vector3(deg_to_rad(82.0), 0.0, 0.0)

		add_child(seg)
		seg.global_position = seg_center
		seg.global_rotation = seg_rot

		var col := CollisionShape3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = ROPE_RADIUS * 1.4 # Slightly generous touch/climb grab radius
		cap.height = SEG_LEN
		col.shape = cap
		seg.add_child(col)

		var mi := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = ROPE_RADIUS
		cyl.bottom_radius = ROPE_RADIUS
		cyl.height = SEG_LEN
		cyl.radial_segments = 12
		mi.mesh = cyl
		mi.material_override = rope_mat
		seg.add_child(mi)

		var joint := PinJoint3D.new()
		joint.name = "RopeJoint_%d_%d" % [rope_id, i]
		joint.exclude_nodes_from_collision = true
		add_child(joint)
		if i == 0:
			joint.global_position = world_anchor_top
		else:
			joint.global_position = (segments[i - 1].global_position + seg.global_position) * 0.5
		joint.node_a = prev_body.get_path()
		joint.node_b = seg.get_path()

		segments.append(seg)
		joints.append(joint)
		prev_body = seg
