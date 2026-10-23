extends CharacterBody3D
class_name YumikController

## Юмик — Главный герой (25 лет, рост 190 см, вес 80 кг).
## Короткие черные волосы до плеч, голубые глаза, белая пижама и голубые джинсы
## (+ сменный комплект горничной из шкафа НЗТБНЗ).
## Полная физика прыжков, пост-прыжков (50%->25%->10% и бесконечных на «Очень прыгучий»),
## лазания по ПВХ и 75-метровым веревкам, тисканья, Ragdoll (PhysicalBoneSimulator3D + PhysicalBone3D),
## PinJoint3D «Не отпускай меня» и воскрешения через 3 секунды в радиусе 10 м!

signal posture_changed(posture_name: String)
signal running_changed(is_running: bool)
signal climbing_changed(is_climbing: bool)
signal cuddling_changed(is_cuddling: bool)
signal ragdoll_changed(is_ragdoll: bool, reason: String)
signal death_state_changed(is_dead: bool, respawn_timer: float)

enum Posture {
	STANDING = 0,
	LIE_BACK = 1,
	LIE_STOMACH = 2,
	ALL_FOURS = 3,
}

const HEIGHT_M: float = 1.90
const TOTAL_MASS_KG: float = 80.0
const GRAVITY: float = 9.8

const WALK_SPEED: float = 3.6
const RUN_SPEED: float = 7.4
const CRAWL_SPEED: float = 2.1
const PRONE_SPEED: float = 1.1
const CLIMB_SPEED: float = 3.8

# Exact Jump Heights from specification:
const JUMP_GROUND_M: float = 0.35      # 35 cm
const JUMP_PVC_M: float = 3.50         # 350 cm (10x higher)
const SKIP_GROUND_M: float = 0.45      # 45 cm ("Припрыжку" -> lands on stomach)
const SKIP_PVC_M: float = 4.50         # 450 cm ("Припрыжку" on NZTBNZ -> lands on stomach)

var current_posture: int = Posture.STANDING
var joystick_input := Vector2.ZERO # length <= 1.0 walk, length > 1.0 run
var is_running_input: bool = false
var is_climbing: bool = false
var is_cuddling: bool = false

# Ragdoll state
var is_ragdoll: bool = false
var ragdoll_reason: String = ""
var ragdoll_min_hold: float = 0.0
var airborne_free_timer: float = 0.0
var last_vertical_speed: float = 0.0

# Jump & Post-jump bounce chain
var base_pvc_jump_h: float = JUMP_PVC_M
var post_bounce_step: int = -1 # -1 = none, 0 = 50%, 1 = 25%, 2 = 10%
var land_on_stomach_pending: bool = false

# Death & 3s Resurrection within 10m
var is_dead: bool = false
var respawn_countdown: float = 0.0
var death_origin := Vector3.ZERO
var underwater_timer: float = 0.0

# Hold-Me PinJoint3D nodes
var pin_joint_left: PinJoint3D = null
var pin_joint_right: PinJoint3D = null
var active_throne_ref: Node3D = null

# Climbing state
var climb_target_node: Node3D = null
var climb_surface_normal := Vector3.FORWARD

# Scene nodes constructed / bound
var main_collision: CollisionShape3D
var camera_pivot: Node3D
var spring_arm: SpringArm3D
var player_camera: Camera3D
var climb_ray: RayCast3D

var visual_pivot: Node3D
var skeleton: Skeleton3D
var bone_simulator: PhysicalBoneSimulator3D
var physical_bones: Dictionary = {} # bone_name -> PhysicalBone3D
var maid_outfit_nodes: Array[Node3D] = []
var maid_skirt_pivot: Node3D

var camera_yaw: float = 0.0
var camera_pitch: float = -16.0
var walk_anim_phase: float = 0.0
var cuddle_anim_phase: float = 0.0
var footstep_accum: float = 0.0
var external_wind_accum := Vector3.ZERO


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2 # Layer 2: Player
	collision_mask = 1 | 4 | 8 | 16 # Terrain, Castle, DarkGodAndProps, Ropes
	floor_max_angle = deg_to_rad(52.0)
	floor_snap_length = 0.35

	_build_character_collision_and_camera()
	_build_skeleton_visuals_and_ragdoll()

	GameState.player_ref = self
	GameState.maid_outfit_changed.connect(_on_maid_outfit_changed)
	GameState.maid_hem_changed.connect(_on_maid_hem_changed)
	GameState.hold_me_changed.connect(_on_hold_me_changed)
	GameState.teleport_to_castle_requested.connect(_on_teleport_to_castle)
	GameState.sleep_cutscene_started.connect(_on_sleep_cutscene_started)
	GameState.sleep_cutscene_finished.connect(_on_sleep_cutscene_finished)


func _build_character_collision_and_camera() -> void:
	main_collision = CollisionShape3D.new()
	main_collision.name = "MainCapsule190cm"
	var cap := CapsuleShape3D.new()
	cap.radius = 0.34
	cap.height = HEIGHT_M
	main_collision.shape = cap
	main_collision.position = Vector3(0.0, HEIGHT_M * 0.5, 0.0)
	add_child(main_collision)

	climb_ray = RayCast3D.new()
	climb_ray.name = "ClimbDetectorRay"
	climb_ray.position = Vector3(0.0, 1.05, 0.0)
	climb_ray.target_position = Vector3(0.0, 0.0, -1.65)
	climb_ray.collision_mask = 1 | 4 | 8 | 16
	climb_ray.enabled = true
	add_child(climb_ray)

	camera_pivot = Node3D.new()
	camera_pivot.name = "CameraOrbitPivot"
	camera_pivot.position = Vector3(0.0, 1.55, 0.0)
	add_child(camera_pivot)

	spring_arm = SpringArm3D.new()
	spring_arm.name = "ThirdPersonSpringArm"
	spring_arm.collision_mask = 1 | 4
	spring_arm.spring_length = 4.6
	spring_arm.margin = 0.3
	camera_pivot.add_child(spring_arm)

	player_camera = Camera3D.new()
	player_camera.name = "ThirdPersonCamera"
	player_camera.fov = 68.0
	player_camera.far = 6500.0
	player_camera.current = true
	spring_arm.add_child(player_camera)
	_apply_camera_angles()


func _build_skeleton_visuals_and_ragdoll() -> void:
	visual_pivot = Node3D.new()
	visual_pivot.name = "VisualPivot"
	add_child(visual_pivot)

	skeleton = Skeleton3D.new()
	skeleton.name = "YumikSkeleton3D"
	visual_pivot.add_child(skeleton)

	# 1.90m articulated humanoid hierarchy
	var bone_defs := [
		["Hips", -1, Vector3(0.0, 0.96, 0.0)],
		["Spine", 0, Vector3(0.0, 0.28, 0.0)],
		["Head", 1, Vector3(0.0, 0.42, 0.0)],
		["LeftUpperArm", 1, Vector3(-0.22, 0.22, 0.0)],
		["LeftHand", 3, Vector3(-0.26, -0.32, 0.0)],
		["RightUpperArm", 1, Vector3(0.22, 0.22, 0.0)],
		["RightHand", 5, Vector3(0.26, -0.32, 0.0)],
		["LeftUpperLeg", 0, Vector3(-0.11, -0.06, 0.0)],
		["LeftFoot", 7, Vector3(0.0, -0.82, 0.0)],
		["RightUpperLeg", 0, Vector3(0.11, -0.06, 0.0)],
		["RightFoot", 9, Vector3(0.0, -0.82, 0.0)],
	]
	for b in bone_defs:
		var idx: int = skeleton.add_bone(b[0])
		if b[1] >= 0:
			skeleton.set_bone_parent(idx, b[1])
		skeleton.set_bone_rest(idx, Transform3D(Basis.IDENTITY, b[2]))
	skeleton.reset_bone_poses()

	var mat_cloth: Material = load("res://assets/materials/mat_yumik_pajama_denim.tres")
	var mat_face: Material = load("res://assets/materials/mat_yumik_face_hair.tres")
	var mat_silk: Material = load("res://assets/materials/mat_maid_pink_silk.tres")
	var mat_stock: Material = load("res://assets/materials/mat_maid_blue_stockings.tres")
	var mat_lace: Material = load("res://assets/materials/mat_pvc_white_lace.tres")

	# Attach visual limb & clothing meshes to bones via BoneAttachment3D
	_attach_bone_mesh("Spine", Vector3(0.0, 0.06, 0.0), Vector3(0.36, 0.56, 0.22), mat_cloth, "TorsoPajama")
	_attach_bone_head(mat_face)
	_attach_bone_limb("LeftUpperArm", Vector3(-0.13, -0.16, 0.0), 0.058, 0.42, mat_cloth)
	_attach_bone_limb("RightUpperArm", Vector3(0.13, -0.16, 0.0), 0.058, 0.42, mat_cloth)
	_attach_bone_limb("LeftHand", Vector3(0.0, -0.04, 0.0), 0.052, 0.14, mat_face)
	_attach_bone_limb("RightHand", Vector3(0.0, -0.04, 0.0), 0.052, 0.14, mat_face)
	_attach_bone_limb("LeftUpperLeg", Vector3(0.0, -0.42, 0.0), 0.082, 0.86, mat_cloth)
	_attach_bone_limb("RightUpperLeg", Vector3(0.0, -0.42, 0.0), 0.082, 0.86, mat_cloth)

	# Equippable Maid Outfit attached to Hips / Legs (hidden until equipped from Wardrobe!)
	var hips_att := BoneAttachment3D.new()
	hips_att.bone_name = "Hips"
	skeleton.add_child(hips_att)

	maid_skirt_pivot = Node3D.new()
	maid_skirt_pivot.name = "MaidSkirtPivot"
	maid_skirt_pivot.visible = false
	hips_att.add_child(maid_skirt_pivot)
	maid_outfit_nodes.append(maid_skirt_pivot)

	if ResourceLoader.exists("res://assets/models/yumik_maid_dress.glb"):
		var md_scene: PackedScene = load("res://assets/models/yumik_maid_dress.glb")
		if md_scene:
			var mdi: Node = md_scene.instantiate()
			if mdi is Node3D:
				(mdi as Node3D).position = Vector3(0.0, -0.94, 0.0)
			var k: int = 0
			for ch in mdi.get_children():
				if ch is MeshInstance3D:
					(ch as MeshInstance3D).material_override = mat_silk if k == 0 else mat_stock
					k += 1
			maid_skirt_pivot.add_child(mdi)
	else:
		var sk_mi := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.20
		cyl.bottom_radius = 0.52
		cyl.height = 0.92
		sk_mi.mesh = cyl
		sk_mi.position = Vector3(0.0, -0.40, 0.0)
		sk_mi.material_override = mat_silk
		maid_skirt_pivot.add_child(sk_mi)

	# White heels on feet
	for foot_bone in ["LeftFoot", "RightFoot"]:
		var f_att := BoneAttachment3D.new()
		f_att.bone_name = foot_bone
		skeleton.add_child(f_att)
		var heel := MeshInstance3D.new()
		var h_box := BoxMesh.new()
		h_box.size = Vector3(0.11, 0.11, 0.24)
		heel.mesh = h_box
		heel.position = Vector3(0.0, -0.02, -0.04)
		heel.material_override = mat_lace
		heel.visible = false
		f_att.add_child(heel)
		maid_outfit_nodes.append(heel)

	# PhysicalBoneSimulator3D + PhysicalBone3D Ragdoll summing to 80.0 kg!
	bone_simulator = PhysicalBoneSimulator3D.new()
	bone_simulator.name = "PhysicalBoneSimulator3D"
	bone_simulator.active = false
	skeleton.add_child(bone_simulator)

	var ragdoll_specs := [
		["Hips", PhysicalBone3D.JOINT_TYPE_NONE, 18.0, Vector3(0.32, 0.26, 0.22)],
		["Spine", PhysicalBone3D.JOINT_TYPE_CONE, 22.0, Vector3(0.34, 0.44, 0.22)],
		["Head", PhysicalBone3D.JOINT_TYPE_CONE, 6.0, Vector3(0.22, 0.24, 0.22)],
		["LeftUpperArm", PhysicalBone3D.JOINT_TYPE_CONE, 4.5, Vector3(0.24, 0.14, 0.14)],
		["LeftHand", PhysicalBone3D.JOINT_TYPE_PIN, 2.5, Vector3(0.16, 0.14, 0.14)],
		["RightUpperArm", PhysicalBone3D.JOINT_TYPE_CONE, 4.5, Vector3(0.24, 0.14, 0.14)],
		["RightHand", PhysicalBone3D.JOINT_TYPE_PIN, 2.5, Vector3(0.16, 0.14, 0.14)],
		["LeftUpperLeg", PhysicalBone3D.JOINT_TYPE_CONE, 10.0, Vector3(0.16, 0.72, 0.16)],
		["RightUpperLeg", PhysicalBone3D.JOINT_TYPE_CONE, 10.0, Vector3(0.16, 0.72, 0.16)],
	]
	for spec in ragdoll_specs:
		var pb := PhysicalBone3D.new()
		pb.name = "PhysicalBone_" + spec[0]
		pb.bone_name = spec[0]
		pb.joint_type = spec[1]
		pb.mass = spec[2]
		pb.friction = 0.55
		pb.bounce = 0.25
		pb.linear_damp_mode = PhysicalBone3D.DAMP_MODE_REPLACE
		pb.angular_damp_mode = PhysicalBone3D.DAMP_MODE_REPLACE
		pb.linear_damp = 0.35
		pb.angular_damp = 1.6
		pb.collision_layer = 32 # Layer 6: PlayerRagdoll
		pb.collision_mask = 1 | 4 | 8

		var pb_cs := CollisionShape3D.new()
		var pb_box := BoxShape3D.new()
		pb_box.size = spec[3]
		pb_cs.shape = pb_box
		pb.add_child(pb_cs)

		bone_simulator.add_child(pb)
		physical_bones[spec[0]] = pb

	bone_simulator.physical_bones_add_collision_exception(get_rid())


func _attach_bone_mesh(bname: String, offset: Vector3, bsize: Vector3, mat: Material, mname: String) -> void:
	var att := BoneAttachment3D.new()
	att.bone_name = bname
	skeleton.add_child(att)
	var mi := MeshInstance3D.new()
	mi.name = mname
	var bm := BoxMesh.new()
	bm.size = bsize
	mi.mesh = bm
	mi.position = offset
	mi.material_override = mat
	att.add_child(mi)


func _attach_bone_limb(bname: String, offset: Vector3, rad: float, h: float, mat: Material) -> void:
	var att := BoneAttachment3D.new()
	att.bone_name = bname
	skeleton.add_child(att)
	var mi := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = rad
	cap.height = h
	mi.mesh = cap
	mi.position = offset
	mi.material_override = mat
	att.add_child(mi)


func _attach_bone_head(mat_face: Material) -> void:
	var att := BoneAttachment3D.new()
	att.bone_name = "Head"
	skeleton.add_child(att)
	var head_mi := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.125
	sph.height = 0.26
	head_mi.mesh = sph
	head_mi.position = Vector3(0.0, 0.08, 0.0)
	head_mi.material_override = mat_face
	att.add_child(head_mi)

	# Shoulder-length black hair back lock
	var hair_mi := MeshInstance3D.new()
	var hair_box := BoxMesh.new()
	hair_box.size = Vector3(0.26, 0.34, 0.16)
	hair_mi.mesh = hair_box
	hair_mi.position = Vector3(0.0, 0.0, 0.07)
	var black_mat := StandardMaterial3D.new()
	black_mat.albedo_color = Color(0.06, 0.06, 0.09)
	black_mat.roughness = 0.38
	hair_mi.material_override = black_mat
	att.add_child(hair_mi)


func set_joystick_input(joy: Vector2, outside_ring_run: bool) -> void:
	joystick_input = joy
	if is_running_input != outside_ring_run:
		is_running_input = outside_ring_run
		running_changed.emit(is_running_input)


func rotate_camera_by_swipe(screen_delta: Vector2) -> void:
	camera_yaw -= screen_delta.x * 0.0048
	camera_pitch = clampf(camera_pitch - screen_delta.y * 0.22, -75.0, 58.0)
	_apply_camera_angles()


func _apply_camera_angles() -> void:
	if camera_pivot:
		camera_pivot.rotation = Vector3(deg_to_rad(camera_pitch), camera_yaw, 0.0)


func toggle_lie_down() -> void:
	if is_dead or is_ragdoll or GameState.is_sleeping_cutscene:
		return
	if is_climbing:
		_stop_climbing()
	if current_posture == Posture.LIE_BACK or current_posture == Posture.LIE_STOMACH:
		_set_posture(Posture.STANDING)
	else:
		# Forward joystick -> lie on stomach; otherwise -> lie on back!
		if joystick_input.y < -0.22:
			_set_posture(Posture.LIE_STOMACH)
		else:
			_set_posture(Posture.LIE_BACK)


func toggle_all_fours() -> void:
	if is_dead or is_ragdoll or GameState.is_sleeping_cutscene:
		return
	if is_climbing:
		_stop_climbing()
	if current_posture == Posture.ALL_FOURS:
		_set_posture(Posture.STANDING)
	else:
		_set_posture(Posture.ALL_FOURS)


func _set_posture(new_posture: int) -> void:
	current_posture = new_posture
	var cap := main_collision.shape as CapsuleShape3D
	match current_posture:
		Posture.STANDING:
			cap.height = HEIGHT_M
			main_collision.position = Vector3(0.0, HEIGHT_M * 0.5, 0.0)
			visual_pivot.rotation = Vector3.ZERO
			visual_pivot.position = Vector3.ZERO
			posture_changed.emit("Стоя")
		Posture.LIE_BACK:
			cap.height = 0.72
			main_collision.position = Vector3(0.0, 0.36, 0.0)
			visual_pivot.rotation.x = deg_to_rad(88.0)
			visual_pivot.position = Vector3(0.0, 0.22, -0.85)
			posture_changed.emit("Лежа на спине")
		Posture.LIE_STOMACH:
			cap.height = 0.72
			main_collision.position = Vector3(0.0, 0.36, 0.0)
			visual_pivot.rotation.x = deg_to_rad(-88.0)
			visual_pivot.position = Vector3(0.0, 0.22, 0.85)
			posture_changed.emit("Лежа на животе")
		Posture.ALL_FOURS:
			cap.height = 1.05
			main_collision.position = Vector3(0.0, 0.525, 0.0)
			visual_pivot.rotation.x = deg_to_rad(-55.0)
			visual_pivot.position = Vector3(0.0, -0.18, 0.42)
			posture_changed.emit("На четвереньках")


func toggle_climb() -> void:
	if is_dead or GameState.is_sleeping_cutscene:
		return
	if active_throne_ref:
		_exit_throne_squeeze()
	if is_ragdoll and not GameState.hold_me_active:
		exit_ragdoll()
	if is_climbing:
		_stop_climbing()
		return
	var found: Node3D = _find_climbable_nearby()
	if found:
		is_climbing = true
		climb_target_node = found
		post_bounce_step = -1 # Grabbing stops infinite/post bounce!
		_set_posture(Posture.STANDING)
		climbing_changed.emit(true)
		if found.is_in_group("climbable_rope"):
			AudioManager.play_3d("rope_grab_creak", global_position, 1.0, 0.08)
		else:
			AudioManager.play_pvc_squeak(global_position)
		AudioManager.play_yumik_voice("climb", global_position)


func _stop_climbing() -> void:
	if not is_climbing:
		return
	is_climbing = false
	climb_target_node = null
	climbing_changed.emit(false)


func _find_climbable_nearby() -> Node3D:
	if climb_ray and climb_ray.is_colliding():
		var col: Object = climb_ray.get_collider()
		if col is Node3D:
			var n := col as Node3D
			if n.is_in_group("climbable_rope") or n.is_in_group("pvc_surface") or n.is_in_group("climbable_rock") or n.is_in_group("dark_god"):
				climb_surface_normal = climb_ray.get_collision_normal()
				return n

	# Spherical proximity search for ropes / castle walls / cliffs within 2.3m
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 2.35
	q.shape = sph
	q.transform = Transform3D(Basis.IDENTITY, global_position + Vector3(0.0, 1.0, 0.0))
	q.collision_mask = 1 | 4 | 8 | 16
	q.exclude = [get_rid()]
	var hits: Array[Dictionary] = space.intersect_shape(q, 8)
	for h in hits:
		var c: Object = h.get("collider")
		if c is Node3D:
			var cn := c as Node3D
			if cn.is_in_group("climbable_rope") or cn.is_in_group("pvc_surface") or cn.is_in_group("climbable_rock") or cn.is_in_group("dark_god"):
				climb_surface_normal = (global_position - cn.global_position).normalized()
				return cn
	return null


func toggle_cuddle() -> void:
	if is_dead or GameState.is_sleeping_cutscene:
		return
	is_cuddling = not is_cuddling
	cuddling_changed.emit(is_cuddling)
	if is_cuddling:
		post_bounce_step = -1 # Hugging catches surface!
		AudioManager.play_pvc_squeak(global_position)
		_notify_dark_god_cuddle_if_touching()


func _notify_dark_god_cuddle_if_touching() -> void:
	if is_instance_valid(GameState.castle_ref):
		var dg: Node = GameState.castle_ref.get_node_or_null("DarkGodAvatar")
		if dg and dg.has_method("trigger_cuddle_reaction"):
			var dist_castle: float = global_position.distance_to(GameState.castle_ref.global_position)
			if dist_castle < 45.0:
				dg.call("trigger_cuddle_reaction", 1.8)


func trigger_jump() -> void:
	if is_dead or GameState.is_sleeping_cutscene:
		return
	if active_throne_ref:
		_exit_throne_squeeze()
		velocity.y = sqrt(2.0 * GRAVITY * JUMP_PVC_M)
		return
	if GameState.nyashing_active:
		# Struggling jump impulse!
		AudioManager.play_yumik_voice("hop", global_position)
		return
	if is_ragdoll and not GameState.hold_me_active:
		exit_ragdoll()

	if is_climbing:
		_stop_climbing()
		velocity = climb_surface_normal * 4.2 + Vector3.UP * sqrt(2.0 * GRAVITY * 1.6)
		AudioManager.play_yumik_voice("hop", global_position)
		return

	if not is_on_floor():
		return

	var standing_on_pvc: bool = _is_standing_on_pvc()
	var jump_h: float = 0.0
	if is_running_input:
		# "Припрыжку": 45 cm on ground, 450 cm on NZTBNZ, lands on stomach!
		jump_h = SKIP_PVC_M if standing_on_pvc else SKIP_GROUND_M
		land_on_stomach_pending = true
	else:
		# "Прыжок": 35 cm on ground, 350 cm on NZTBNZ!
		jump_h = JUMP_PVC_M if standing_on_pvc else JUMP_GROUND_M
		land_on_stomach_pending = false

	if current_posture != Posture.STANDING:
		_set_posture(Posture.STANDING)

	if standing_on_pvc:
		base_pvc_jump_h = jump_h
		post_bounce_step = 0
	else:
		post_bounce_step = -1

	velocity.y = sqrt(2.0 * GRAVITY * jump_h)
	AudioManager.play_3d("jump", global_position, 0.0, 0.08)
	AudioManager.play_yumik_voice("hop", global_position)


func _is_standing_on_pvc() -> bool:
	for i in range(get_slide_collision_count()):
		var col: KinematicCollision3D = get_slide_collision(i)
		var obj: Object = col.get_collider()
		if obj is Node3D and ((obj as Node3D).is_in_group("pvc_surface") or (obj as Node3D).is_in_group("dark_god")):
			return true
	return false


func _get_floor_surface_info() -> Dictionary:
	var on_pvc := false
	var very_bouncy := false
	var on_rock := false
	for i in range(get_slide_collision_count()):
		var col: KinematicCollision3D = get_slide_collision(i)
		var obj: Object = col.get_collider()
		if obj is Node3D:
			var n := obj as Node3D
			if n.is_in_group("very_bouncy"):
				very_bouncy = true
				on_pvc = true
			elif n.is_in_group("pvc_surface") or n.is_in_group("dark_god"):
				on_pvc = true
			elif n.is_in_group("climbable_rock"):
				on_rock = true
	return {"pvc": on_pvc, "very_bouncy": very_bouncy, "rock": on_rock}


func enter_ragdoll(reason: String, min_duration: float = 1.2) -> void:
	if is_dead:
		return
	ragdoll_reason = reason
	ragdoll_min_hold = maxf(ragdoll_min_hold, min_duration)
	if is_ragdoll:
		return
	is_ragdoll = true
	if is_climbing:
		_stop_climbing()

	main_collision.disabled = true
	bone_simulator.active = true
	bone_simulator.physical_bones_start_simulation()
	for pb: PhysicalBone3D in physical_bones.values():
		pb.linear_velocity = velocity
	ragdoll_changed.emit(true, reason)


func exit_ragdoll() -> void:
	if not is_ragdoll:
		return
	_clear_hold_me_joints()
	var hips_pb: PhysicalBone3D = physical_bones.get("Hips")
	if hips_pb:
		global_position = hips_pb.global_position + Vector3(0.0, 0.15, 0.0)
	bone_simulator.physical_bones_stop_simulation()
	bone_simulator.active = false
	skeleton.reset_bone_poses()
	main_collision.disabled = false
	is_ragdoll = false
	ragdoll_reason = ""
	airborne_free_timer = 0.0
	velocity = Vector3.ZERO
	ragdoll_changed.emit(false, "")


func _on_hold_me_changed(active: bool) -> void:
	if active:
		var target_body: PhysicsBody3D = _find_nearest_attachable_physics_body()
		if target_body == null:
			GameState.set_hold_me(false)
			return
		AudioManager.play_yumik_voice("hold_me", global_position)
		enter_ragdoll("Не отпускай меня", 999999.0)
		_create_hold_me_pin_joints(target_body)
	else:
		_clear_hold_me_joints()
		if is_ragdoll and ragdoll_reason == "Не отпускай меня":
			exit_ragdoll()


func _find_nearest_attachable_physics_body() -> PhysicsBody3D:
	if is_instance_valid(climb_target_node) and climb_target_node is PhysicsBody3D:
		return climb_target_node as PhysicsBody3D
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 4.2
	q.shape = sph
	q.transform = Transform3D(Basis.IDENTITY, global_position + Vector3(0.0, 1.0, 0.0))
	q.collision_mask = 4 | 8 | 16
	q.exclude = [get_rid()]
	var hits: Array[Dictionary] = space.intersect_shape(q, 8)
	for h in hits:
		var col: Object = h.get("collider")
		if col is PhysicsBody3D:
			return col as PhysicsBody3D
	if is_instance_valid(GameState.castle_ref) and GameState.castle_ref is PhysicsBody3D:
		if global_position.distance_to(GameState.castle_ref.global_position) < 42.0:
			return GameState.castle_ref as PhysicsBody3D
	return null


func _create_hold_me_pin_joints(target_body: PhysicsBody3D) -> void:
	_clear_hold_me_joints()
	var pb_l: PhysicalBone3D = physical_bones.get("LeftHand")
	var pb_r: PhysicalBone3D = physical_bones.get("RightHand")
	if pb_l:
		pin_joint_left = PinJoint3D.new()
		pin_joint_left.name = "HoldMePinLeft"
		pin_joint_left.exclude_nodes_from_collision = true
		get_parent().add_child(pin_joint_left)
		pin_joint_left.global_position = pb_l.global_position
		pin_joint_left.node_a = pb_l.get_path()
		pin_joint_left.node_b = target_body.get_path()
	if pb_r:
		pin_joint_right = PinJoint3D.new()
		pin_joint_right.name = "HoldMePinRight"
		pin_joint_right.exclude_nodes_from_collision = true
		get_parent().add_child(pin_joint_right)
		pin_joint_right.global_position = pb_r.global_position
		pin_joint_right.node_a = pb_r.get_path()
		pin_joint_right.node_b = target_body.get_path()


func _clear_hold_me_joints() -> void:
	if is_instance_valid(pin_joint_left):
		pin_joint_left.queue_free()
	if is_instance_valid(pin_joint_right):
		pin_joint_right.queue_free()
	pin_joint_left = null
	pin_joint_right = null


func enter_throne_squeeze(throne_node: Node3D, seat_world_pos: Vector3) -> void:
	active_throne_ref = throne_node
	global_position = seat_world_pos
	enter_ragdoll("На надувном троне", 999999.0)


func maintain_throne_ragdoll_cradle(target_pos: Vector3) -> void:
	if not is_ragdoll:
		return
	var hips_pb: PhysicalBone3D = physical_bones.get("Hips")
	if hips_pb:
		var pull: Vector3 = (target_pos - hips_pb.global_position) * 14.0 - hips_pb.linear_velocity * 3.0
		hips_pb.apply_central_impulse(pull * get_physics_process_delta_time() * hips_pb.mass)


func _exit_throne_squeeze() -> void:
	if is_instance_valid(active_throne_ref) and active_throne_ref.has_method("release_seated_player"):
		active_throne_ref.call("release_seated_player")
	active_throne_ref = null
	if is_ragdoll and ragdoll_reason == "На надувном троне":
		exit_ragdoll()


func apply_nyashing_cradle(target_world_pos: Vector3) -> void:
	if is_ragdoll:
		exit_ragdoll()
	if current_posture != Posture.LIE_BACK:
		_set_posture(Posture.LIE_BACK)
	global_position = global_position.lerp(target_world_pos, 0.22)
	velocity = Vector3.ZERO


func get_nyashing_struggle_strength() -> float:
	return clampf(joystick_input.length(), 0.0, 1.4)


func on_escaped_nyashing(push_vel: Vector3) -> void:
	_set_posture(Posture.STANDING)
	velocity = push_vel
	AudioManager.play_yumik_voice("hop", global_position)


func apply_external_wind_impulse(dv: Vector3) -> void:
	external_wind_accum += dv


func _on_maid_outfit_changed(equipped: bool) -> void:
	for n in maid_outfit_nodes:
		if is_instance_valid(n):
			n.visible = equipped


func _on_maid_hem_changed(lifted: bool) -> void:
	if maid_skirt_pivot:
		maid_skirt_pivot.rotation.x = deg_to_rad(-48.0 if lifted else 0.0)
		maid_skirt_pivot.scale.y = 0.62 if lifted else 1.0
	AudioManager.play_3d("silk_rustle", global_position, 1.0, 0.06)


func _on_teleport_to_castle() -> void:
	if not is_instance_valid(GameState.castle_ref):
		return
	if is_ragdoll:
		GameState.set_hold_me(false)
		_exit_throne_squeeze()
		exit_ragdoll()
	var gate_front: Vector3 = GameState.castle_ref.to_global(Vector3(0.0, 3.0, 22.0))
	global_position = gate_front
	velocity = Vector3.ZERO


func _on_sleep_cutscene_started() -> void:
	if is_ragdoll:
		exit_ragdoll()
	_set_posture(Posture.LIE_BACK)


func _on_sleep_cutscene_finished() -> void:
	_set_posture(Posture.STANDING)


func _trigger_death() -> void:
	if is_dead:
		return
	is_dead = true
	respawn_countdown = 3.0 # Resurrects 3 seconds after death!
	death_origin = global_position
	AudioManager.play_yumik_voice("whoa", global_position)
	if not is_ragdoll:
		enter_ragdoll("Гибель", 3.2)
	death_state_changed.emit(true, respawn_countdown)


func _complete_resurrection() -> void:
	is_dead = false
	underwater_timer = 0.0
	if GameState.hold_me_active:
		GameState.set_hold_me(false)
	exit_ragdoll()
	_set_posture(Posture.STANDING)

	# Respawn within 10-meter radius at safe terrain elevation!
	var rand_ang: float = randf() * TAU
	var rand_r: float = randf_range(2.5, 9.5) # Strictly <= 10m radius!
	var target_xz := Vector2(death_origin.x + cos(rand_ang) * rand_r, death_origin.z + sin(rand_ang) * rand_r)
	var ground_y: float = death_origin.y + 2.0
	var p_world: Node = get_parent()
	if p_world and p_world.has_method("sample_terrain_height"):
		ground_y = maxf(0.8, float(p_world.call("sample_terrain_height", target_xz.x, target_xz.y)) + 0.5)
	global_position = Vector3(target_xz.x, ground_y, target_xz.y)
	velocity = Vector3.ZERO
	AudioManager.play_yumik_voice("respawn", global_position)
	death_state_changed.emit(false, 0.0)


func _physics_process(delta: float) -> void:
	if is_dead:
		respawn_countdown -= delta
		death_state_changed.emit(true, maxf(0.0, respawn_countdown))
		_follow_ragdoll_camera(delta)
		if respawn_countdown <= 0.0:
			_complete_resurrection()
		return

	if GameState.is_sleeping_cutscene:
		# Orbit camera cinematically around sleeping Yumik & Dark God during 8-hour dream!
		camera_yaw += delta * 0.45
		camera_pitch = -22.0
		_apply_camera_angles()
		return

	# Check deep-water drowning
	if global_position.y < -1.85:
		underwater_timer += delta
		if underwater_timer > 4.5:
			_trigger_death()
			return
	else:
		underwater_timer = maxf(0.0, underwater_timer - delta * 2.0)

	if is_cuddling:
		cuddle_anim_phase += delta * 7.5
		if fmod(cuddle_anim_phase, TAU) < delta * 7.5:
			AudioManager.play_pvc_squeak(global_position)
			_notify_dark_god_cuddle_if_touching()
		_animate_cuddle_limbs()

	if is_ragdoll:
		_process_ragdoll_state(delta)
		return

	if is_climbing:
		_process_climbing_movement(delta)
		return

	_process_standard_locomotion(delta)


func _process_ragdoll_state(delta: float) -> void:
	_follow_ragdoll_camera(delta)
	if ragdoll_min_hold > 0.0:
		ragdoll_min_hold -= delta

	# Apply lifted maid-skirt wind sail even in Ragdoll!
	if GameState.maid_outfit_equipped and GameState.maid_hem_lifted:
		var hips_pb: PhysicalBone3D = physical_bones.get("Hips")
		if hips_pb:
			var w: Vector3 = WindManager.get_wind_at_position(hips_pb.global_position)
			hips_pb.apply_central_impulse(w * 2.6 * delta * 15.0)

	# Recover automatically from airborne/impact ragdoll once settled near surface
	if not GameState.hold_me_active and active_throne_ref == null and ragdoll_min_hold <= 0.0:
		var hips_pb: PhysicalBone3D = physical_bones.get("Hips")
		if hips_pb and hips_pb.linear_velocity.length() < 1.8:
			exit_ragdoll()


func _follow_ragdoll_camera(delta: float) -> void:
	var hips_pb: PhysicalBone3D = physical_bones.get("Hips")
	if hips_pb and camera_pivot:
		camera_pivot.global_position = camera_pivot.global_position.lerp(hips_pb.global_position + Vector3(0.0, 0.5, 0.0), delta * 12.0)


func _process_climbing_movement(delta: float) -> void:
	if not is_instance_valid(climb_target_node):
		_stop_climbing()
		return

	var exhaust_mult: float = 0.42 if GameState.is_exhausted else 1.0
	var climb_up: float = -joystick_input.y * CLIMB_SPEED * exhaust_mult
	var climb_side: float = joystick_input.x * (CLIMB_SPEED * 0.75) * exhaust_mult

	if climb_target_node.is_in_group("climbable_rope"):
		# Climb smoothly along physical 75m hemp rope segment chain!
		var rope_parent: Node = climb_target_node.get_parent()
		global_position = global_position.lerp(climb_target_node.global_position + climb_surface_normal * 0.45, delta * 9.0)
		global_position.y += climb_up * delta
		if rope_parent and "segments" in rope_parent:
			var segs: Array = rope_parent.get("segments")
			var best_seg: Node3D = climb_target_node
			var best_d: float = 999.0
			for s: Node3D in segs:
				if is_instance_valid(s):
					var d: float = absf(s.global_position.y - global_position.y)
					if d < best_d:
						best_d = d
						best_seg = s
			climb_target_node = best_seg
		velocity = Vector3.ZERO
		return

	# Climbing on 0.35mm PVC or Mountain Rock: calculate slope, castle inertia & wind slip!
	var right_tangent: Vector3 = Vector3.UP.cross(climb_surface_normal).normalized()
	if right_tangent.length_squared() < 0.01:
		right_tangent = Vector3.RIGHT
	var up_tangent: Vector3 = climb_surface_normal.cross(right_tangent).normalized()

	var slip_vel := Vector3.ZERO
	if climb_target_node.is_in_group("pvc_surface") or climb_target_node.is_in_group("pvc_slippery"):
		# Overhang/steepness + wind + castle acceleration cause sliding unless cuddling ("Тискать")!
		var overhang: float = clampf(1.0 - climb_surface_normal.y, 0.0, 2.0)
		var local_wind: Vector3 = WindManager.get_wind_at_position(global_position)
		var castle_shake: float = 0.0
		if is_instance_valid(GameState.castle_ref) and "current_hull_accel" in GameState.castle_ref:
			castle_shake = (GameState.castle_ref.get("current_hull_accel") as Vector3).length() * 0.08
		var grip_factor: float = 3.2 if is_cuddling else 1.0
		var raw_slip: float = maxf(0.0, (overhang * 1.45 + local_wind.length() * 0.10 + castle_shake) / grip_factor - 0.85)
		slip_vel = Vector3.DOWN * raw_slip * 2.4 + local_wind * (0.08 / grip_factor)
		if raw_slip > 3.6 and not is_cuddling:
			# Slips and falls off slippery PVC!
			_stop_climbing()
			AudioManager.play_yumik_voice("whoa", global_position)
			velocity = climb_surface_normal * 2.0 + slip_vel
			return

	velocity = (up_tangent * climb_up + right_tangent * climb_side) + slip_vel
	move_and_slide()

	# Verify still near climbable surface
	if _find_climbable_nearby() == null:
		_stop_climbing()


func _process_standard_locomotion(delta: float) -> void:
	camera_pivot.position = Vector3(0.0, 1.55 if current_posture == Posture.STANDING else 0.85, 0.0)

	var was_on_floor: bool = is_on_floor()
	if not was_on_floor:
		velocity.y -= GRAVITY * delta
		airborne_free_timer += delta
		# Ragdoll Trigger #3: Airborne touching nothing except air for > 1.0 second!
		# (Allow clean vertical bounces on NZTBNZ if horizontal chaos isn't extreme, OR trigger at > 1.0s freefall!)
		if airborne_free_timer > 1.0 and post_bounce_step < 0:
			AudioManager.play_yumik_voice("whoa", global_position)
			enter_ragdoll("В воздухе > 1 сек", 0.9)
			return
	else:
		airborne_free_timer = 0.0

	# Maid Outfit lifted hem ("Задрать подол") catches wind!
	if GameState.maid_outfit_equipped and GameState.maid_hem_lifted:
		var wind_v: Vector3 = WindManager.get_wind_at_position(global_position)
		velocity += wind_v * (0.55 * delta)
		if velocity.y < -2.5 and wind_v.length() > 3.0:
			# Silk skirt parachute effect reduces fall rate!
			velocity.y = move_toward(velocity.y, -2.5 + wind_v.length() * 0.15, 16.0 * delta)

	velocity += external_wind_accum
	external_wind_accum = Vector3.ZERO

	# Horizontal movement from virtual joystick relative to camera yaw
	var exhaust_mult: float = 0.40 if GameState.is_exhausted else 1.0
	var target_spd: float = WALK_SPEED
	match current_posture:
		Posture.STANDING:
			target_spd = RUN_SPEED if is_running_input else WALK_SPEED
		Posture.ALL_FOURS:
			target_spd = CRAWL_SPEED
		Posture.LIE_BACK, Posture.LIE_STOMACH:
			target_spd = PRONE_SPEED
	target_spd *= exhaust_mult

	var cam_basis := Basis(Vector3.UP, camera_yaw)
	var move_dir: Vector3 = (cam_basis * Vector3(joystick_input.x, 0.0, joystick_input.y))
	if move_dir.length() > 1.0:
		move_dir = move_dir.normalized()

	var accel: float = 14.0 if is_on_floor() else 4.5
	velocity.x = move_toward(velocity.x, move_dir.x * target_spd, accel * delta)
	velocity.z = move_toward(velocity.z, move_dir.z * target_spd, accel * delta)

	if move_dir.length_squared() > 0.02 and visual_pivot:
		var target_yaw: float = atan2(-move_dir.x, -move_dir.z)
		visual_pivot.rotation.y = lerp_angle(visual_pivot.rotation.y, target_yaw, delta * 10.0)

	last_vertical_speed = velocity.y
	move_and_slide()

	# Landing, Post-Jumps, Impact Ragdoll & Lethal Fall Detection
	if is_on_floor() and not was_on_floor:
		_handle_landing_physics(-last_vertical_speed)
	elif is_on_floor():
		_animate_walk_and_footsteps(delta, Vector2(velocity.x, velocity.z).length())


func _handle_landing_physics(downward_impact_speed: float) -> void:
	airborne_free_timer = 0.0
	var surf: Dictionary = _get_floor_surface_info()
	var on_pvc: bool = surf["pvc"]
	var very_bouncy: bool = surf["very_bouncy"]

	if land_on_stomach_pending:
		land_on_stomach_pending = false
		_set_posture(Posture.LIE_STOMACH)

	# Lethal fall on hard ground/rock (> 23 m/s ~ 27m cliff drop) -> 3s Resurrection!
	if not on_pvc and downward_impact_speed > 23.0:
		AudioManager.play_landing(false, false, global_position)
		_trigger_death()
		return

	# Heavy impact on non-PVC (> 11.5 m/s) -> Ragdoll Trigger #4!
	if not on_pvc and downward_impact_speed > 11.5:
		AudioManager.play_landing(false, false, global_position)
		enter_ragdoll("Сильный удар / падение", 1.5)
		return

	if on_pvc:
		if is_cuddling:
			post_bounce_step = -1
			AudioManager.play_landing(true, false, global_position)
			return

		if very_bouncy:
			# "Очень прыгучий" (33m wings & Throne): bounce height NEVER decays!
			var inf_h: float = maxf(base_pvc_jump_h, maxf(JUMP_PVC_M, (downward_impact_speed * downward_impact_speed) / (2.0 * GRAVITY)))
			velocity.y = sqrt(2.0 * GRAVITY * minf(inf_h, 18.0))
			post_bounce_step = 0
			AudioManager.play_landing(true, true, global_position)
			return

		# Standard NZTBNZ / Dark God Post-Jump Decay: 50% -> 25% -> 10% -> stop!
		if post_bounce_step < 0 and downward_impact_speed > 3.8:
			base_pvc_jump_h = clampf((downward_impact_speed * downward_impact_speed) / (2.0 * GRAVITY), 1.5, SKIP_PVC_M)
			post_bounce_step = 0

		if post_bounce_step >= 0 and post_bounce_step <= 2:
			var ratios := [0.50, 0.25, 0.10]
			var next_h: float = base_pvc_jump_h * ratios[post_bounce_step]
			post_bounce_step += 1
			velocity.y = sqrt(2.0 * GRAVITY * next_h)
			AudioManager.play_landing(true, true, global_position)
			return
		else:
			post_bounce_step = -1
			AudioManager.play_landing(true, false, global_position)
	else:
		post_bounce_step = -1
		if downward_impact_speed > 1.8:
			AudioManager.play_landing(false, false, global_position)


func _animate_walk_and_footsteps(delta: float, horiz_speed: float) -> void:
	if horiz_speed < 0.25:
		if not is_cuddling:
			skeleton.reset_bone_poses()
		return

	walk_anim_phase += delta * horiz_speed * 2.6
	footstep_accum += delta * horiz_speed
	if footstep_accum >= 1.85:
		footstep_accum = 0.0
		var surf: Dictionary = _get_floor_surface_info()
		var stype := "pvc" if surf["pvc"] else ("rock" if surf["rock"] else "grass")
		AudioManager.play_footstep(stype, global_position)

	if not is_cuddling:
		var swing: float = sin(walk_anim_phase) * 0.48
		var l_leg: int = skeleton.find_bone("LeftUpperLeg")
		var r_leg: int = skeleton.find_bone("RightUpperLeg")
		var l_arm: int = skeleton.find_bone("LeftUpperArm")
		var r_arm: int = skeleton.find_bone("RightUpperArm")
		if l_leg >= 0:
			skeleton.set_bone_pose_rotation(l_leg, Quaternion.from_euler(Vector3(swing, 0.0, 0.0)))
		if r_leg >= 0:
			skeleton.set_bone_pose_rotation(r_leg, Quaternion.from_euler(Vector3(-swing, 0.0, 0.0)))
		if l_arm >= 0:
			skeleton.set_bone_pose_rotation(l_arm, Quaternion.from_euler(Vector3(-swing * 0.7, 0.0, 0.0)))
		if r_arm >= 0:
			skeleton.set_bone_pose_rotation(r_arm, Quaternion.from_euler(Vector3(swing * 0.7, 0.0, 0.0)))


func _animate_cuddle_limbs() -> void:
	var squeeze: float = 0.55 + 0.35 * sin(cuddle_anim_phase)
	var l_arm: int = skeleton.find_bone("LeftUpperArm")
	var r_arm: int = skeleton.find_bone("RightUpperArm")
	var l_leg: int = skeleton.find_bone("LeftUpperLeg")
	var r_leg: int = skeleton.find_bone("RightUpperLeg")
	if l_arm >= 0:
		skeleton.set_bone_pose_rotation(l_arm, Quaternion.from_euler(Vector3(0.7, squeeze, 0.35)))
	if r_arm >= 0:
		skeleton.set_bone_pose_rotation(r_arm, Quaternion.from_euler(Vector3(0.7, -squeeze, -0.35)))
	if l_leg >= 0:
		skeleton.set_bone_pose_rotation(l_leg, Quaternion.from_euler(Vector3(0.25, 0.0, -squeeze * 0.4)))
	if r_leg >= 0:
		skeleton.set_bone_pose_rotation(r_leg, Quaternion.from_euler(Vector3(0.25, 0.0, squeeze * 0.4)))
