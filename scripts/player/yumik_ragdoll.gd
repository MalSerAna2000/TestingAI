class_name YumikRagdollRig
extends Node3D
## Complete 1.90m, 80.0kg Anatomical Skeleton3D + PhysicalBoneSimulator3D + 11 PhysicalBone3D Ragdoll
## and Dual Outfit Visual Rig (Default White Pajama + Blue Jeans vs Wardrobe Pink Silk Maid Set) for Yumik.

const TOTAL_MASS_KG: float = 80.0

var skeleton: Skeleton3D
var simulator: PhysicalBoneSimulator3D
var physical_bones: Dictionary = {} # bone_name -> PhysicalBone3D
var bone_indices: Dictionary = {}   # bone_name -> int

var hand_pin_left: PinJoint3D = null
var hand_pin_right: PinJoint3D = null

var _pajama_parts: Array[Node3D] = []
var _maid_parts: Array[Node3D] = []
var _maid_skirt_pivot: Node3D
var _is_simulating: bool = false
var _anim_clock: float = 0.0

# Exact 1.90m human proportions for 25yo male (crown at 1.90m, shoulders at 1.54m, hips at 0.96m)
const BONE_DEFS := [
	{"name": "Hips", "parent": "", "rest_pos": Vector3(0.0, 0.96, 0.0), "mass": 16.0, "shape": Vector2(0.16, 0.28), "offset": Vector3(0.0, 0.0, 0.0), "joint": PhysicalBone3D.JOINT_TYPE_NONE},
	{"name": "Torso", "parent": "Hips", "rest_pos": Vector3(0.0, 0.56, 0.0), "mass": 20.0, "shape": Vector2(0.18, 0.54), "offset": Vector3(0.0, -0.24, 0.0), "joint": PhysicalBone3D.JOINT_TYPE_CONE},
	{"name": "Head", "parent": "Torso", "rest_pos": Vector3(0.0, 0.30, 0.0), "mass": 6.0, "shape": Vector2(0.115, 0.25), "offset": Vector3(0.0, -0.05, 0.0), "joint": PhysicalBone3D.JOINT_TYPE_CONE},
	{"name": "UpperArmL", "parent": "Torso", "rest_pos": Vector3(-0.24, -0.04, 0.0), "mass": 3.5, "shape": Vector2(0.062, 0.34), "offset": Vector3(0.0, -0.17, 0.0), "joint": PhysicalBone3D.JOINT_TYPE_CONE},
	{"name": "HandL", "parent": "UpperArmL", "rest_pos": Vector3(0.0, -0.34, 0.0), "mass": 2.5, "shape": Vector2(0.056, 0.34), "offset": Vector3(0.0, -0.17, 0.0), "joint": PhysicalBone3D.JOINT_TYPE_HINGE},
	{"name": "UpperArmR", "parent": "Torso", "rest_pos": Vector3(0.24, -0.04, 0.0), "mass": 3.5, "shape": Vector2(0.062, 0.34), "offset": Vector3(0.0, -0.17, 0.0), "joint": PhysicalBone3D.JOINT_TYPE_CONE},
	{"name": "HandR", "parent": "UpperArmR", "rest_pos": Vector3(0.0, -0.34, 0.0), "mass": 2.5, "shape": Vector2(0.056, 0.34), "offset": Vector3(0.0, -0.17, 0.0), "joint": PhysicalBone3D.JOINT_TYPE_HINGE},
	{"name": "ThighL", "parent": "Hips", "rest_pos": Vector3(-0.11, -0.04, 0.0), "mass": 8.5, "shape": Vector2(0.078, 0.44), "offset": Vector3(0.0, -0.22, 0.0), "joint": PhysicalBone3D.JOINT_TYPE_CONE},
	{"name": "CalfL", "parent": "ThighL", "rest_pos": Vector3(0.0, -0.44, 0.0), "mass": 4.5, "shape": Vector2(0.066, 0.46), "offset": Vector3(0.0, -0.23, 0.0), "joint": PhysicalBone3D.JOINT_TYPE_HINGE},
	{"name": "ThighR", "parent": "Hips", "rest_pos": Vector3(0.11, -0.04, 0.0), "mass": 8.5, "shape": Vector2(0.078, 0.44), "offset": Vector3(0.0, -0.22, 0.0), "joint": PhysicalBone3D.JOINT_TYPE_CONE},
	{"name": "CalfR", "parent": "ThighR", "rest_pos": Vector3(0.0, -0.44, 0.0), "mass": 4.5, "shape": Vector2(0.066, 0.46), "offset": Vector3(0.0, -0.23, 0.0), "joint": PhysicalBone3D.JOINT_TYPE_HINGE},
]


func _ready() -> void:
	_build_skeleton_and_physical_bones()
	_build_attached_character_meshes()
	set_maid_outfit(GameState.maid_outfit_equipped)


func _build_skeleton_and_physical_bones() -> void:
	skeleton = Skeleton3D.new()
	skeleton.name = "YumikSkeleton3D"
	add_child(skeleton)

	for bdef in BONE_DEFS:
		var idx: int = skeleton.add_bone(bdef["name"])
		bone_indices[bdef["name"]] = idx
		if bdef["parent"] != "":
			skeleton.set_bone_parent(idx, bone_indices[bdef["parent"]])
		skeleton.set_bone_rest(idx, Transform3D(Basis.IDENTITY, bdef["rest_pos"]))
		skeleton.reset_bone_pose(idx)

	skeleton.force_update_all_bone_transforms()

	simulator = PhysicalBoneSimulator3D.new()
	simulator.name = "PhysicalBoneSimulator3D"
	simulator.active = false
	skeleton.add_child(simulator)

	for bdef in BONE_DEFS:
		var bname: String = bdef["name"]
		var pb := PhysicalBone3D.new()
		pb.name = "PhysBone_" + bname
		pb.bone_name = bname
		pb.mass = bdef["mass"]
		pb.friction = 0.42
		pb.bounce = 0.35
		pb.linear_damp_mode = PhysicalBone3D.DAMP_MODE_REPLACE
		pb.angular_damp_mode = PhysicalBone3D.DAMP_MODE_REPLACE
		pb.linear_damp = 0.35
		pb.angular_damp = 1.45
		pb.can_sleep = false
		pb.collision_layer = 32 # Layer 6: PlayerRagdoll
		pb.collision_mask = 1 | 4 | 8 | 64 # Terrain, Castle, Ropes, DarkGod
		pb.joint_type = bdef["joint"]
		pb.body_offset = Transform3D(Basis.IDENTITY, bdef["offset"])

		var cap := CapsuleShape3D.new()
		cap.radius = bdef["shape"].x
		cap.height = bdef["shape"].y
		var col := CollisionShape3D.new()
		col.shape = cap
		pb.add_child(col)

		simulator.add_child(pb)
		physical_bones[bname] = pb


func _make_attachment(bone_name: String) -> BoneAttachment3D:
	var ba := BoneAttachment3D.new()
	ba.name = "Attach_" + bone_name
	ba.bone_name = bone_name
	skeleton.add_child(ba)
	return ba


func _build_attached_character_meshes() -> void:
	var pajama_mat: Material = load("res://assets/materials/mat_yumik_pajama.tres")
	var jeans_mat: Material = load("res://assets/materials/mat_yumik_jeans.tres")
	var hair_mat: Material = load("res://assets/materials/mat_yumik_hair.tres")
	var skin_mat: Material = load("res://assets/materials/mat_skin_warm.tres")
	var pink_silk: Material = load("res://assets/materials/mat_maid_pink_silk.tres")
	var blue_silk: Material = load("res://assets/materials/mat_maid_blue_silk.tres")

	var face_mat := StandardMaterial3D.new()
	face_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	face_mat.albedo_texture = load("res://assets/textures/characters/yumik_face_blue_eyes.png")
	face_mat.roughness = 0.42

	var limb_mesh: Mesh = load("res://assets/models/yumik_limb_segment.obj")

	# Head + Blue Eyes + Short Black Shoulder-Length Hair (shared across both outfits!)
	var att_head := _make_attachment("Head")
	var head_mi := MeshInstance3D.new()
	head_mi.mesh = load("res://assets/models/yumik_head.obj")
	head_mi.position = Vector3(0.0, 0.08, 0.0)
	head_mi.material_override = skin_mat
	att_head.add_child(head_mi)

	var eyes_q := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.16, 0.14)
	eyes_q.mesh = qm
	# Yumik faces -Z in local CharacterBody3D forward convention!
	eyes_q.position = Vector3(0.0, -0.03, -0.119)
	eyes_q.rotation.y = PI
	eyes_q.material_override = face_mat
	att_head.add_child(eyes_q)

	var hair_mi := MeshInstance3D.new()
	hair_mi.mesh = load("res://assets/models/yumik_hair_black.obj")
	hair_mi.position = Vector3(0.0, 0.08, 0.0)
	hair_mi.rotation.y = PI
	hair_mi.material_override = hair_mat
	att_head.add_child(hair_mi)

	# Torso: White Pajama Top vs Pink Ruffled Silk Maid Bodice
	var att_torso := _make_attachment("Torso")
	var pj_torso := MeshInstance3D.new()
	pj_torso.mesh = load("res://assets/models/yumik_torso_pajama.obj")
	pj_torso.material_override = pajama_mat
	att_torso.add_child(pj_torso)
	_pajama_parts.append(pj_torso)

	var maid_torso := MeshInstance3D.new()
	maid_torso.mesh = load("res://assets/models/yumik_maid_bodice.obj")
	maid_torso.material_override = pink_silk
	att_torso.add_child(maid_torso)
	_maid_parts.append(maid_torso)

	# Hips: Blue Jeans Pelvis vs Ankle-Length Pink Silk Ruffled Skirt ("подол до пяток")!
	var att_hips := _make_attachment("Hips")
	var jeans_hips := MeshInstance3D.new()
	jeans_hips.mesh = load("res://assets/models/yumik_pelvis_jeans.obj")
	jeans_hips.position = Vector3(0.0, 0.08, 0.0)
	jeans_hips.material_override = jeans_mat
	att_hips.add_child(jeans_hips)
	_pajama_parts.append(jeans_hips)

	_maid_skirt_pivot = Node3D.new()
	_maid_skirt_pivot.name = "MaidSkirtHemPivot"
	_maid_skirt_pivot.position = Vector3(0.0, 0.04, 0.0)
	var skirt_mi := MeshInstance3D.new()
	skirt_mi.mesh = load("res://assets/models/yumik_maid_skirt_hem.obj")
	skirt_mi.material_override = pink_silk
	_maid_skirt_pivot.add_child(skirt_mi)
	att_hips.add_child(_maid_skirt_pivot)
	_maid_parts.append(_maid_skirt_pivot)

	# Arms: Pajama long sleeves vs Maid puff sleeves + bare forearms
	for arm_b in ["UpperArmL", "UpperArmR", "HandL", "HandR"]:
		var att_a := _make_attachment(arm_b)
		var is_upper: bool = arm_b.begins_with("Upper")
		var pj_arm := MeshInstance3D.new()
		pj_arm.mesh = limb_mesh
		pj_arm.scale = Vector3(0.88, 0.80, 0.88)
		pj_arm.material_override = pajama_mat if is_upper else skin_mat
		att_a.add_child(pj_arm)
		_pajama_parts.append(pj_arm)

		var md_arm := MeshInstance3D.new()
		md_arm.mesh = limb_mesh
		md_arm.scale = Vector3(0.86, 0.80, 0.86)
		md_arm.material_override = pink_silk if is_upper else skin_mat
		att_a.add_child(md_arm)
		_maid_parts.append(md_arm)

	# Legs & Footwear: Blue Jeans vs Light-Blue Silk Stockings + White High Heels!
	var heel_mesh: Mesh = load("res://assets/models/yumik_white_heel.obj")
	for leg_b in ["ThighL", "ThighR", "CalfL", "CalfR"]:
		var att_l := _make_attachment(leg_b)
		var pj_leg := MeshInstance3D.new()
		pj_leg.mesh = limb_mesh
		pj_leg.scale = Vector3(1.12, 1.05, 1.12)
		pj_leg.material_override = jeans_mat
		att_l.add_child(pj_leg)
		_pajama_parts.append(pj_leg)

		var md_leg := MeshInstance3D.new()
		md_leg.mesh = limb_mesh
		md_leg.scale = Vector3(1.04, 1.05, 1.04)
		md_leg.material_override = blue_silk
		att_l.add_child(md_leg)
		_maid_parts.append(md_leg)

		if leg_b.begins_with("Calf"):
			var heel_mi := MeshInstance3D.new()
			heel_mi.mesh = heel_mesh
			heel_mi.position = Vector3(0.0, -0.44, -0.03)
			heel_mi.material_override = pajama_mat
			att_l.add_child(heel_mi)
			_maid_parts.append(heel_mi)


func set_maid_outfit(equipped: bool) -> void:
	for p in _pajama_parts:
		if is_instance_valid(p):
			p.visible = not equipped
	for m in _maid_parts:
		if is_instance_valid(m):
			m.visible = equipped


func is_ragdoll_active() -> bool:
	return _is_simulating


func start_ragdoll(initial_lin_vel: Vector3) -> void:
	if _is_simulating:
		return
	_is_simulating = true
	simulator.active = true
	simulator.physical_bones_start_simulation_on([])
	for pb: PhysicalBone3D in physical_bones.values():
		pb.linear_velocity = initial_lin_vel
		pb.angular_velocity = Vector3.ZERO


func stop_ragdoll() -> Vector3:
	detach_hand_pins()
	var hips_world: Vector3 = global_position
	if physical_bones.has("Hips"):
		hips_world = physical_bones["Hips"].global_position
	if _is_simulating:
		simulator.physical_bones_stop_simulation()
		simulator.active = false
		_is_simulating = false
	for idx in range(skeleton.get_bone_count()):
		skeleton.reset_bone_pose(idx)
	return hips_world


func get_ragdoll_hips_global_position() -> Vector3:
	if physical_bones.has("Hips"):
		return physical_bones["Hips"].global_position
	return global_position + Vector3(0.0, 0.96, 0.0)


func apply_ragdoll_central_force(force_vec: Vector3) -> void:
	if not _is_simulating:
		return
	var per_bone: Vector3 = force_vec / float(maxi(physical_bones.size(), 1))
	for pb: PhysicalBone3D in physical_bones.values():
		pb.apply_central_impulse(per_bone * get_physics_process_delta_time())


func attach_hand_pins(world_parent: Node, target_body: PhysicsBody3D, anchor_world: Vector3, init_vel: Vector3) -> void:
	detach_hand_pins()
	start_ragdoll(init_vel)
	if not is_instance_valid(target_body):
		return

	var hand_l: PhysicalBone3D = physical_bones.get("HandL")
	var hand_r: PhysicalBone3D = physical_bones.get("HandR")
	if hand_l == null or hand_r == null:
		return

	var right_dir: Vector3 = global_basis.x * 0.22
	hand_l.global_position = anchor_world - right_dir
	hand_r.global_position = anchor_world + right_dir

	hand_pin_left = PinJoint3D.new()
	hand_pin_left.name = "DontLetGoPinLeft"
	world_parent.add_child(hand_pin_left)
	hand_pin_left.global_position = anchor_world - right_dir
	hand_pin_left.set_param(PinJoint3D.PARAM_BIAS, 0.95)
	hand_pin_left.set_param(PinJoint3D.PARAM_DAMPING, 1.4)
	hand_pin_left.set_param(PinJoint3D.PARAM_IMPULSE_CLAMP, 0.0)
	hand_pin_left.exclude_nodes_from_collision = true
	hand_pin_left.node_a = hand_l.get_path()
	hand_pin_left.node_b = target_body.get_path()

	hand_pin_right = PinJoint3D.new()
	hand_pin_right.name = "DontLetGoPinRight"
	world_parent.add_child(hand_pin_right)
	hand_pin_right.global_position = anchor_world + right_dir
	hand_pin_right.set_param(PinJoint3D.PARAM_BIAS, 0.95)
	hand_pin_right.set_param(PinJoint3D.PARAM_DAMPING, 1.4)
	hand_pin_right.set_param(PinJoint3D.PARAM_IMPULSE_CLAMP, 0.0)
	hand_pin_right.exclude_nodes_from_collision = true
	hand_pin_right.node_a = hand_r.get_path()
	hand_pin_right.node_b = target_body.get_path()


func detach_hand_pins() -> void:
	if is_instance_valid(hand_pin_left):
		hand_pin_left.queue_free()
	if is_instance_valid(hand_pin_right):
		hand_pin_right.queue_free()
	hand_pin_left = null
	hand_pin_right = null


func update_procedural_pose(
	pose_name: String,
	move_speed_norm: float,
	hem_lifted: bool,
	squeeze_active: bool,
	delta: float
) -> void:
	if _is_simulating:
		return
	_anim_clock += delta * (2.5 + 6.5 * move_speed_norm)

	# Skirt flare when "Задрать подол" is active!
	if is_instance_valid(_maid_skirt_pivot):
		var target_scale := Vector3(1.55, -0.72, 1.55) if hem_lifted else Vector3.ONE
		_maid_skirt_pivot.scale = _maid_skirt_pivot.scale.lerp(target_scale, clampf(delta * 8.0, 0.0, 1.0))

	var hips_idx: int = bone_indices["Hips"]
	var torso_idx: int = bone_indices["Torso"]
	var al_idx: int = bone_indices["UpperArmL"]
	var ar_idx: int = bone_indices["UpperArmR"]
	var hl_idx: int = bone_indices["HandL"]
	var hr_idx: int = bone_indices["HandR"]
	var tl_idx: int = bone_indices["ThighL"]
	var tr_idx: int = bone_indices["ThighR"]
	var cl_idx: int = bone_indices["CalfL"]
	var cr_idx: int = bone_indices["CalfR"]

	for idx in range(skeleton.get_bone_count()):
		skeleton.reset_bone_pose(idx)

	if squeeze_active:
		# "Тискать": Rhythmic tight hugging squeeze & release with BOTH arms and legs!
		var sq: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.008)
		skeleton.set_bone_pose_position(hips_idx, Vector3(0.0, 0.90, 0.0))
		skeleton.set_bone_pose_rotation(al_idx, Quaternion.from_euler(Vector3(1.15 + 0.35 * sq, 0.35 * sq, -0.35)))
		skeleton.set_bone_pose_rotation(ar_idx, Quaternion.from_euler(Vector3(1.15 + 0.35 * sq, -0.35 * sq, 0.35)))
		skeleton.set_bone_pose_rotation(hl_idx, Quaternion.from_euler(Vector3(0.65 * sq, 0.0, 0.0)))
		skeleton.set_bone_pose_rotation(hr_idx, Quaternion.from_euler(Vector3(0.65 * sq, 0.0, 0.0)))
		skeleton.set_bone_pose_rotation(tl_idx, Quaternion.from_euler(Vector3(0.75 + 0.30 * sq, 0.0, -0.30 * sq)))
		skeleton.set_bone_pose_rotation(tr_idx, Quaternion.from_euler(Vector3(0.75 + 0.30 * sq, 0.0, 0.30 * sq)))
		return

	match pose_name:
		"lie_back":
			skeleton.set_bone_pose_position(hips_idx, Vector3(0.0, 0.22, 0.0))
			skeleton.set_bone_pose_rotation(hips_idx, Quaternion.from_euler(Vector3(PI * 0.5, 0.0, 0.0)))
		"lie_belly":
			skeleton.set_bone_pose_position(hips_idx, Vector3(0.0, 0.22, 0.0))
			skeleton.set_bone_pose_rotation(hips_idx, Quaternion.from_euler(Vector3(-PI * 0.5, 0.0, 0.0)))
		"skip_dive":
			# Midair "Припрыжку" forward dive landing flat onto stomach!
			skeleton.set_bone_pose_position(hips_idx, Vector3(0.0, 0.72, 0.0))
			skeleton.set_bone_pose_rotation(hips_idx, Quaternion.from_euler(Vector3(-1.18, 0.0, 0.0)))
			skeleton.set_bone_pose_rotation(al_idx, Quaternion.from_euler(Vector3(2.45, 0.0, 0.2)))
			skeleton.set_bone_pose_rotation(ar_idx, Quaternion.from_euler(Vector3(2.45, 0.0, -0.2)))
		"all_fours":
			var crawl: float = sin(_anim_clock) * move_speed_norm
			skeleton.set_bone_pose_position(hips_idx, Vector3(0.0, 0.52, 0.0))
			skeleton.set_bone_pose_rotation(hips_idx, Quaternion.from_euler(Vector3(-1.28, 0.0, 0.0)))
			skeleton.set_bone_pose_rotation(al_idx, Quaternion.from_euler(Vector3(1.28 + 0.42 * crawl, 0.0, 0.0)))
			skeleton.set_bone_pose_rotation(ar_idx, Quaternion.from_euler(Vector3(1.28 - 0.42 * crawl, 0.0, 0.0)))
			skeleton.set_bone_pose_rotation(tl_idx, Quaternion.from_euler(Vector3(1.15 - 0.42 * crawl, 0.0, 0.0)))
			skeleton.set_bone_pose_rotation(tr_idx, Quaternion.from_euler(Vector3(1.15 + 0.42 * crawl, 0.0, 0.0)))
			skeleton.set_bone_pose_rotation(cl_idx, Quaternion.from_euler(Vector3(-1.05, 0.0, 0.0)))
			skeleton.set_bone_pose_rotation(cr_idx, Quaternion.from_euler(Vector3(-1.05, 0.0, 0.0)))
		"climb":
			var reach: float = sin(_anim_clock * 1.15)
			skeleton.set_bone_pose_position(hips_idx, Vector3(0.0, 0.94, 0.0))
			skeleton.set_bone_pose_rotation(al_idx, Quaternion.from_euler(Vector3(2.45 + 0.48 * reach, 0.0, 0.1)))
			skeleton.set_bone_pose_rotation(ar_idx, Quaternion.from_euler(Vector3(2.45 - 0.48 * reach, 0.0, -0.1)))
			skeleton.set_bone_pose_rotation(tl_idx, Quaternion.from_euler(Vector3(0.55 - 0.42 * reach, 0.0, 0.0)))
			skeleton.set_bone_pose_rotation(tr_idx, Quaternion.from_euler(Vector3(0.55 + 0.42 * reach, 0.0, 0.0)))
		_:
			var stride: float = sin(_anim_clock) * move_speed_norm
			skeleton.set_bone_pose_position(hips_idx, Vector3(0.0, 0.96 + absf(stride) * 0.04, 0.0))
			skeleton.set_bone_pose_rotation(torso_idx, Quaternion.from_euler(Vector3(-0.08 * move_speed_norm, 0.0, 0.0)))
			if hem_lifted:
				skeleton.set_bone_pose_rotation(al_idx, Quaternion.from_euler(Vector3(0.62, 0.0, 0.42)))
				skeleton.set_bone_pose_rotation(ar_idx, Quaternion.from_euler(Vector3(0.62, 0.0, -0.42)))
			else:
				skeleton.set_bone_pose_rotation(al_idx, Quaternion.from_euler(Vector3(-0.62 * stride, 0.0, 0.06)))
				skeleton.set_bone_pose_rotation(ar_idx, Quaternion.from_euler(Vector3(0.62 * stride, 0.0, -0.06)))
			skeleton.set_bone_pose_rotation(tl_idx, Quaternion.from_euler(Vector3(0.68 * stride, 0.0, 0.0)))
			skeleton.set_bone_pose_rotation(tr_idx, Quaternion.from_euler(Vector3(-0.68 * stride, 0.0, 0.0)))
			skeleton.set_bone_pose_rotation(cl_idx, Quaternion.from_euler(Vector3(minf(-0.55 * stride, 0.0), 0.0, 0.0)))
			skeleton.set_bone_pose_rotation(cr_idx, Quaternion.from_euler(Vector3(minf(0.55 * stride, 0.0), 0.0, 0.0)))
