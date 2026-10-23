class_name DarkGodController
extends Node3D
## Living Avatar of the Dark God of Inflatable Castles (НЗТБНЗ):
## - Height: 3.0 meters (plus 0.30m kitsune ears)
## - Legless: seamlessly fused into the inflatable castle floor
## - Dark-red inflatable maid dress with white lace (no bottom hem), waist-length white hair,
##   30cm inflatable kitsune ears, 12m span dark-red inflatable angel wings
## - Dynamic crimson anime eyes switching to ">_<" when hugged ("Тискать") or during "Няшинг"
## - SoftBody3D elastic cushion shell + high-elasticity physics interaction during "Няшинг"
## - In "Летающее": mischievously covers mouth with hand, giggles, and beats 12m wings to blast wind across hall!

var castle_owner: Node3D
var player_ref: Node3D

var _visual_root: Node3D
var _head_pivot: Node3D
var _face_quad: MeshInstance3D
var _ear_l: Node3D
var _ear_r: Node3D
var _wing_l: Node3D
var _wing_r: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _hair_node: Node3D
var _soft_cushion: SoftBody3D
var _hit_body: AnimatableBody3D

var _mat_eyes_normal: StandardMaterial3D
var _mat_eyes_gtlt: StandardMaterial3D

var is_gtlt_expression: bool = false
var is_nyashing_player: bool = false
var _home_local_pos: Vector3 = Vector3(0.0, 2.0, -7.2)
var _anim_t: float = 0.0
var _expression_hold_timer: float = 0.0
var _giggle_cooldown: float = 1.5
var _wing_gust_timer: float = 0.0


func _ready() -> void:
	_home_local_pos = position
	_build_dark_god_model_and_physics()


func _build_dark_god_model_and_physics() -> void:
	var dress_mat: Material = load("res://assets/materials/mat_dark_god_dress.tres")
	var white_pvc: Material = load("res://assets/materials/mat_dark_god_white_pvc.tres")
	var wing_mat: Material = load("res://assets/materials/mat_castle_wing.tres")
	var skin_mat: Material = load("res://assets/materials/mat_skin_warm.tres")

	_mat_eyes_normal = StandardMaterial3D.new()
	_mat_eyes_normal.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_eyes_normal.albedo_texture = load("res://assets/textures/characters/dark_god_face_normal.png")
	_mat_eyes_normal.roughness = 0.25
	_mat_eyes_normal.emission_enabled = true
	_mat_eyes_normal.emission = Color(0.32, 0.04, 0.10)

	_mat_eyes_gtlt = StandardMaterial3D.new()
	_mat_eyes_gtlt.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_eyes_gtlt.albedo_texture = load("res://assets/textures/characters/dark_god_face_gtlt.png")
	_mat_eyes_gtlt.roughness = 0.22
	_mat_eyes_gtlt.emission_enabled = true
	_mat_eyes_gtlt.emission = Color(0.55, 0.08, 0.18)

	_visual_root = Node3D.new()
	_visual_root.name = "DarkGodVisualRoot"
	add_child(_visual_root)

	# 0.0..2.32m legless maid dress fused seamlessly into floor
	var body_mi := MeshInstance3D.new()
	body_mi.name = "MaidDressBody"
	body_mi.mesh = load("res://assets/models/dark_god_maid_body.obj")
	body_mi.material_override = dress_mat
	_visual_root.add_child(body_mi)

	# Head at 2.66m (crown reaches exact 3.00m height!)
	_head_pivot = Node3D.new()
	_head_pivot.name = "HeadPivot"
	_head_pivot.position = Vector3(0.0, 2.66, 0.0)
	_visual_root.add_child(_head_pivot)

	var head_mi := MeshInstance3D.new()
	head_mi.mesh = load("res://assets/models/dark_god_head_anime.obj")
	head_mi.material_override = skin_mat
	_head_pivot.add_child(head_mi)

	# Front anime face plane displaying normal crimson eyes OR ">_<" expression!
	var fquad := QuadMesh.new()
	fquad.size = Vector2(0.46, 0.44)
	_face_quad = MeshInstance3D.new()
	_face_quad.name = "AnimeFaceExpression"
	_face_quad.mesh = fquad
	_face_quad.position = Vector3(0.0, -0.02, 0.312)
	_face_quad.material_override = _mat_eyes_normal
	_head_pivot.add_child(_face_quad)

	# Waist-length white inflatable hair
	_hair_node = Node3D.new()
	_hair_node.name = "WhiteInflatableHair"
	var hair_mi := MeshInstance3D.new()
	hair_mi.mesh = load("res://assets/models/dark_god_hair_white.obj")
	hair_mi.material_override = white_pvc
	_hair_node.add_child(hair_mi)
	_head_pivot.add_child(_hair_node)

	# 30cm (0.30m) inflatable kitsune ears!
	_ear_l = Node3D.new()
	_ear_l.position = Vector3(-0.17, 0.28, 0.02)
	_ear_l.rotation.z = 0.26
	var ear_mi_l := MeshInstance3D.new()
	ear_mi_l.mesh = load("res://assets/models/dark_god_kitsune_ear_30cm.obj")
	ear_mi_l.material_override = white_pvc
	_ear_l.add_child(ear_mi_l)
	_head_pivot.add_child(_ear_l)

	_ear_r = Node3D.new()
	_ear_r.position = Vector3(0.17, 0.28, 0.02)
	_ear_r.rotation.z = -0.26
	var ear_mi_r := MeshInstance3D.new()
	ear_mi_r.mesh = load("res://assets/models/dark_god_kitsune_ear_30cm.obj")
	ear_mi_r.material_override = white_pvc
	_ear_r.add_child(ear_mi_r)
	_head_pivot.add_child(_ear_r)

	# Articulated inflatable arms (for hugging, patting, and mischievously covering mouth in flight!)
	_arm_l = Node3D.new()
	_arm_l.position = Vector3(-0.44, 2.18, 0.06)
	var arm_mi_l := MeshInstance3D.new()
	arm_mi_l.mesh = load("res://assets/models/dark_god_arm_segment.obj")
	arm_mi_l.material_override = dress_mat
	_arm_l.add_child(arm_mi_l)
	_visual_root.add_child(_arm_l)

	_arm_r = Node3D.new()
	_arm_r.position = Vector3(0.44, 2.18, 0.06)
	var arm_mi_r := MeshInstance3D.new()
	arm_mi_r.mesh = load("res://assets/models/dark_god_arm_segment.obj")
	arm_mi_r.material_override = dress_mat
	_arm_r.add_child(arm_mi_r)
	_visual_root.add_child(_arm_r)

	# 12m span (6m left + 6m right) dark-red inflatable angel wings on back!
	var dg_wing_mesh: Mesh = load("res://assets/models/dark_god_wing_6m.obj")
	_wing_r = Node3D.new()
	_wing_r.name = "BackWingRight6m"
	_wing_r.position = Vector3(0.28, 2.02, -0.32)
	var wmi_r := MeshInstance3D.new()
	wmi_r.mesh = dg_wing_mesh
	wmi_r.material_override = wing_mat
	_wing_r.add_child(wmi_r)
	_visual_root.add_child(_wing_r)

	_wing_l = Node3D.new()
	_wing_l.name = "BackWingLeft6m"
	_wing_l.position = Vector3(-0.28, 2.02, -0.32)
	var wmi_l := MeshInstance3D.new()
	wmi_l.mesh = dg_wing_mesh
	wmi_l.scale = Vector3(-1.0, 1.0, 1.0)
	wmi_l.material_override = wing_mat
	_wing_l.add_child(wmi_l)
	_visual_root.add_child(_wing_l)

	# High-elasticity bouncy physics body for climbing, hugging ("Тискать"), & 10x bounce!
	_hit_body = AnimatableBody3D.new()
	_hit_body.name = "DarkGodPhysicsBody"
	_hit_body.sync_to_physics = false
	_hit_body.collision_layer = 64 # Layer 7: DarkGod
	_hit_body.collision_mask = 0
	_hit_body.set_meta("surface_kind", "dark_god")
	_hit_body.set_meta("climbable", true)
	_hit_body.set_meta("grip_factor", 0.52)
	_hit_body.set_meta("dark_god_owner", self)
	var dg_pmat := PhysicsMaterial.new()
	dg_pmat.friction = 0.26
	dg_pmat.bounce = 0.94
	_hit_body.physics_material_override = dg_pmat

	var body_cap := CapsuleShape3D.new()
	body_cap.radius = 0.68
	body_cap.height = 3.0
	var bcol := CollisionShape3D.new()
	bcol.shape = body_cap
	bcol.position = Vector3(0.0, 1.5, 0.0)
	_hit_body.add_child(bcol)
	add_child(_hit_body)

	# Genuine Jolt SoftBody3D deformable plush cushion shell around waist/lap for soft elastic Nyashing physics!
	_soft_cushion = SoftBody3D.new()
	_soft_cushion.name = "DarkGodSoftPlushCushion"
	_soft_cushion.mesh = load("res://assets/models/nyashing_cushion_shell.obj")
	_soft_cushion.material_override = dress_mat
	_soft_cushion.position = Vector3(0.0, 0.92, 0.36)
	_soft_cushion.collision_layer = 64
	_soft_cushion.collision_mask = 16 | 32
	_soft_cushion.total_mass = 18.0
	_soft_cushion.linear_stiffness = 0.42
	_soft_cushion.pressure_coefficient = 28.0
	_soft_cushion.damping_coefficient = 0.08
	_soft_cushion.simulation_precision = 6
	add_child(_soft_cushion)
	# Pin ring anchor vertices of SoftBody3D to DarkGodPhysicsBody so it moves with him while squishing elastically!
	_pin_soft_cushion_anchors.call_deferred()


func _pin_soft_cushion_anchors() -> void:
	if not is_instance_valid(_soft_cushion) or not is_instance_valid(_hit_body):
		return
	if _soft_cushion.mesh == null or _soft_cushion.mesh.get_surface_count() == 0:
		return
	var arrays: Array = _soft_cushion.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for idx in range(verts.size()):
		if verts[idx].z < -0.22:
			_soft_cushion.set_point_pinned(idx, true, _hit_body.get_path())


func trigger_gtlt_expression(duration: float = 1.6, play_sound: bool = false) -> void:
	_expression_hold_timer = maxf(_expression_hold_timer, duration)
	if not is_gtlt_expression:
		_set_gtlt_visual(true)
	if play_sound:
		AudioManager.play_3d("dg_nya", global_position + Vector3(0.0, 2.5, 0.0), 1.5, randf_range(0.95, 1.08), true)


func _set_gtlt_visual(active: bool) -> void:
	is_gtlt_expression = active
	if is_instance_valid(_face_quad):
		_face_quad.material_override = _mat_eyes_gtlt if active else _mat_eyes_normal


func _physics_process(delta: float) -> void:
	_anim_t += delta
	if _expression_hold_timer > 0.0:
		_expression_hold_timer -= delta

	var state_id: int = GameState.CastleState.NORMAL
	var player_inside_hall: bool = false
	if is_instance_valid(castle_owner) and castle_owner.has_method("get_current_state"):
		state_id = castle_owner.get_current_state()
		player_inside_hall = castle_owner.is_player_inside_hall()

	# Cute kitsune ear twitches & inflatable hair sway
	var ear_twitch: float = sin(_anim_t * 4.5) * 0.14 if is_gtlt_expression else sin(_anim_t * 1.8) * 0.06
	_ear_l.rotation.z = 0.26 + ear_twitch
	_ear_r.rotation.z = -0.26 - ear_twitch
	_hair_node.rotation.x = sin(_anim_t * 1.5) * 0.06

	if state_id == GameState.CastleState.SUCTION and player_inside_hall and is_instance_valid(player_ref):
		# STATE 2 INSIDE HALL: Grab Yumik, lay him on the soft PVC floor, straddle him & perform "Няшинг"!
		var p_local: Vector3 = get_parent().to_local(player_ref.global_position)
		p_local.x = clampf(p_local.x, -11.5, 11.5)
		p_local.z = clampf(p_local.z, -11.5, 11.5)
		var target_local := Vector3(p_local.x, _home_local_pos.y, p_local.z)
		position = position.lerp(target_local, clampf(delta * 2.8, 0.0, 1.0))

		var dist_to_player: float = Vector2(position.x - p_local.x, position.z - p_local.z).length()
		is_nyashing_player = dist_to_player < 2.9
		if is_nyashing_player:
			trigger_gtlt_expression(0.5, false)
			# Playful bounce + rub + hug motion on top of Yumik!
			var bounce_y: float = absf(sin(_anim_t * 4.4)) * 0.34
			_visual_root.position.y = bounce_y
			_visual_root.rotation.z = sin(_anim_t * 3.1) * 0.11
			_arm_l.rotation = Vector3(-0.95 + 0.32 * sin(_anim_t * 5.2), 0.0, -0.42)
			_arm_r.rotation = Vector3(-0.95 - 0.32 * sin(_anim_t * 5.2), 0.0, 0.42)
			_wing_l.rotation.y = -0.78 - 0.25 * sin(_anim_t * 3.6)
			_wing_r.rotation.y = 0.78 + 0.25 * sin(_anim_t * 3.6)

			AudioManager.update_purr_audio(true, global_position + Vector3(0.0, 1.8, 0.0))
			if player_ref.has_method("apply_dark_god_nyashing"):
				player_ref.apply_dark_god_nyashing(global_position, bounce_y, delta)
		else:
			_visual_root.position.y = 0.0
			AudioManager.update_purr_audio(false, global_position)

		WindManager.interior_gust_active = false
	elif state_id == GameState.CastleState.FLYING:
		# STATE 3 INSIDE HALL: Mischievously covers mouth with hand, giggles, and beats 12m wings to whip gusts across hall!
		is_nyashing_player = false
		position = position.lerp(_home_local_pos, clampf(delta * 2.2, 0.0, 1.0))
		_visual_root.position.y = 0.12 * sin(_anim_t * 3.0)

		# Right hand raised mischievously covering mouth while left arm waves playfully!
		_arm_r.rotation = Vector3(-2.45, -0.35, -0.52)
		_arm_l.rotation = Vector3(-0.45 + 0.35 * sin(_anim_t * 3.4), 0.0, 0.35)

		# Rapid 12m wing beats generating swirling gusts inside throne room!
		var flap: float = sin(_anim_t * 6.5)
		_wing_r.rotation.y = 0.68 * flap
		_wing_l.rotation.y = -0.68 * flap
		_wing_r.rotation.z = 0.32 * flap
		_wing_l.rotation.z = -0.32 * flap

		_giggle_cooldown -= delta
		if _giggle_cooldown <= 0.0:
			_giggle_cooldown = randf_range(4.5, 7.8)
			var g_key := "dg_giggle_1" if randf() < 0.5 else "dg_giggle_2"
			AudioManager.play_3d(g_key, global_position + Vector3(0.0, 2.5, 0.0), 2.5, randf_range(0.96, 1.06), true)

		_wing_gust_timer += delta
		var hall_forward: Vector3 = global_basis.z
		var hall_side: Vector3 = global_basis.x * sin(_wing_gust_timer * 1.9)
		WindManager.interior_gust_active = true
		WindManager.interior_center = to_global(Vector3(0.0, 6.0, 6.0))
		WindManager.interior_gust_vector = (hall_forward * (14.5 + 8.5 * absf(flap)) + hall_side * 9.5 + Vector3.UP * (5.5 * flap))
		AudioManager.update_purr_audio(false, global_position)
	else:
		# STATE 1 ("Обычное"): Playful idle sway inside throne room, tracking Yumik with eyes
		is_nyashing_player = false
		position = position.lerp(_home_local_pos, clampf(delta * 2.0, 0.0, 1.0))
		_visual_root.position.y = 0.05 * sin(_anim_t * 2.1)
		_visual_root.rotation.z = 0.04 * sin(_anim_t * 1.4)
		_arm_l.rotation = Vector3(-0.22, 0.0, 0.24 + 0.08 * sin(_anim_t * 2.0))
		_arm_r.rotation = Vector3(-0.22, 0.0, -0.24 - 0.08 * sin(_anim_t * 2.0))
		_wing_r.rotation.y = 0.16 * sin(_anim_t * 1.6)
		_wing_l.rotation.y = -0.16 * sin(_anim_t * 1.6)
		WindManager.interior_gust_active = false
		AudioManager.update_purr_audio(false, global_position)

	if _expression_hold_timer <= 0.0 and is_gtlt_expression:
		_set_gtlt_visual(false)

	# Turn head smoothly toward Yumik when nearby
	if is_instance_valid(player_ref) and player_ref.global_position.distance_to(global_position) < 28.0:
		var rel_p: Vector3 = to_local(player_ref.global_position + Vector3(0.0, 1.5, 0.0)) - _head_pivot.position
		var yaw: float = clampf(atan2(rel_p.x, rel_p.z), -0.85, 0.85)
		_head_pivot.rotation.y = lerpf(_head_pivot.rotation.y, yaw, clampf(delta * 4.5, 0.0, 1.0))
