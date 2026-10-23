extends Node3D
class_name DarkGodAvatar

## The Dark God of Inflatable Castles (НЗТБНЗ) — 3m tall cute anime femboy with
## legless inflatable floor-skirt body, dark-red lace maid bodice, waist-length white
## inflatable hair, 30cm kitsune ears, 12m dark-red angel wings, >_< expression,
## SoftBody3D pneumatic cuddle cushion, and Nyashing / Flying behavior!

var visual_root: Node3D
var face_plate: MeshInstance3D
var squint_badge: Label3D
var right_arm_pivot: Node3D
var left_arm_pivot: Node3D
var wing_left_pivot: Node3D
var wing_right_pivot: Node3D
var soft_cushion: SoftBody3D
var elastic_body: AnimatableBody3D
var nyashing_zone: Area3D
var purr_player: AudioStreamPlayer3D

var mat_face_open: Material
var mat_face_squint: Material

var is_squinting: bool = false
var squint_hold_timer: float = 0.0
var anim_phase: float = 0.0
var sfx_timer: float = 0.0
var escape_progress: float = 0.0


func _ready() -> void:
	add_to_group("dark_god")
	add_to_group("pvc_surface")

	var mat_dress: Material = load("res://assets/materials/mat_pvc_crimson_castle.tres")
	var mat_lace: Material = load("res://assets/materials/mat_pvc_white_lace.tres")
	var mat_hair: Material = load("res://assets/materials/mat_pvc_kitsune_hair.tres")
	var mat_wing: Material = load("res://assets/materials/mat_pvc_angel_wing.tres")
	mat_face_open = load("res://assets/materials/mat_dark_god_face_open.tres")
	mat_face_squint = load("res://assets/materials/mat_dark_god_face_squint.tres")

	# Elastic collider representing his 3m inflatable torso & floor base
	elastic_body = AnimatableBody3D.new()
	elastic_body.name = "DarkGodElasticBody"
	elastic_body.sync_to_physics = false
	elastic_body.collision_layer = 8 # Layer 4: DarkGodAndProps
	elastic_body.collision_mask = 0
	elastic_body.add_to_group("dark_god")
	elastic_body.add_to_group("pvc_surface")
	var phys_m := PhysicsMaterial.new()
	phys_m.bounce = 0.92
	phys_m.friction = 0.25
	elastic_body.physics_material_override = phys_m

	var base_cs := CollisionShape3D.new()
	var base_cyl := CylinderShape3D.new()
	base_cyl.radius = 1.65
	base_cyl.height = 1.1
	base_cs.shape = base_cyl
	base_cs.position = Vector3(0.0, 0.55, 0.0)
	elastic_body.add_child(base_cs)

	var torso_cs := CollisionShape3D.new()
	var torso_cap := CapsuleShape3D.new()
	torso_cap.radius = 0.55
	torso_cap.height = 2.6
	torso_cs.shape = torso_cap
	torso_cs.position = Vector3(0.0, 1.75, 0.0)
	elastic_body.add_child(torso_cs)
	add_child(elastic_body)

	# Pressurized SoftBody3D pneumatic cushion around front floor for soft elastic Nyashing!
	soft_cushion = SoftBody3D.new()
	soft_cushion.name = "PneumaticNyashingCushion"
	var cushion_mesh := SphereMesh.new()
	cushion_mesh.radius = 1.6
	cushion_mesh.height = 1.1
	cushion_mesh.radial_segments = 16
	cushion_mesh.rings = 8
	soft_cushion.mesh = cushion_mesh
	soft_cushion.material_override = mat_dress
	soft_cushion.position = Vector3(0.0, 0.55, 1.85)
	soft_cushion.collision_layer = 8
	soft_cushion.collision_mask = 2 | 32
	soft_cushion.total_mass = 18.0
	soft_cushion.linear_stiffness = 0.48
	soft_cushion.pressure_coefficient = 35.0
	soft_cushion.damping_coefficient = 0.10
	add_child(soft_cushion)
	# Pin vertex 0 relative to parent DarkGodAvatar so cushion moves with castle throne hall!
	soft_cushion.set_point_pinned.call_deferred(0, true, NodePath(".."))

	visual_root = Node3D.new()
	visual_root.name = "DarkGodVisualRoot"
	add_child(visual_root)

	if ResourceLoader.exists("res://assets/models/dark_god_avatar.glb"):
		var packed: PackedScene = load("res://assets/models/dark_god_avatar.glb")
		if packed:
			var inst: Node = packed.instantiate()
			var mats := [mat_dress, mat_face_open, mat_lace, mat_hair, mat_wing]
			var idx: int = 0
			for ch in inst.get_children():
				if ch is MeshInstance3D:
					(ch as MeshInstance3D).material_override = mats[mini(idx, mats.size() - 1)]
					idx += 1
			visual_root.add_child(inst)

	# Expressive anime face quad & >_< 3D indicator
	face_plate = MeshInstance3D.new()
	var f_quad := QuadMesh.new()
	f_quad.size = Vector2(0.56, 0.52)
	face_plate.mesh = f_quad
	face_plate.position = Vector3(0.0, 2.56, 0.41)
	face_plate.material_override = mat_face_open
	visual_root.add_child(face_plate)

	squint_badge = Label3D.new()
	squint_badge.position = Vector3(0.0, 3.45, 0.25)
	squint_badge.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	squint_badge.font_size = 64
	squint_badge.outline_size = 14
	squint_badge.modulate = Color(1.0, 0.28, 0.48)
	squint_badge.text = ">_<"
	squint_badge.visible = false
	visual_root.add_child(squint_badge)

	# Articulated inflatable arms (for hugging Yumik OR mischievously covering mouth while Flying!)
	left_arm_pivot = _build_arm(-1.0, mat_dress, mat_lace)
	right_arm_pivot = _build_arm(1.0, mat_dress, mat_lace)
	visual_root.add_child(left_arm_pivot)
	visual_root.add_child(right_arm_pivot)

	# Articulated flapping 12m angel wing roots (6m each side) for interior throne gusts
	wing_left_pivot = _build_inner_wing(-1.0, mat_wing)
	wing_right_pivot = _build_inner_wing(1.0, mat_wing)
	visual_root.add_child(wing_left_pivot)
	visual_root.add_child(wing_right_pivot)

	# Nyashing capture zone inside throne hall
	nyashing_zone = Area3D.new()
	nyashing_zone.name = "NyashingCaptureArea"
	nyashing_zone.collision_layer = 64
	nyashing_zone.collision_mask = 2
	var nz_cs := CollisionShape3D.new()
	var nz_sph := SphereShape3D.new()
	nz_sph.radius = 6.5
	nz_cs.shape = nz_sph
	nz_cs.position = Vector3(0.0, 2.0, 2.5)
	nyashing_zone.add_child(nz_cs)
	add_child(nyashing_zone)

	purr_player = AudioStreamPlayer3D.new()
	purr_player.bus = &"Voice"
	purr_player.max_distance = 45.0
	if AudioManager.streams.has("god_purr"):
		purr_player.stream = AudioManager.streams["god_purr"]
	add_child(purr_player)


func _build_arm(side: float, mat_sleeve: Material, mat_hand: Material) -> Node3D:
	var piv := Node3D.new()
	piv.position = Vector3(side * 0.44, 1.82, 0.05)
	var sleeve := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.13
	cap.height = 0.85
	sleeve.mesh = cap
	sleeve.position = Vector3(side * 0.22, -0.32, 0.18)
	sleeve.rotation.z = side * deg_to_rad(25.0)
	sleeve.material_override = mat_sleeve
	piv.add_child(sleeve)

	var cuff := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.15
	cuff.mesh = sph
	cuff.position = Vector3(side * 0.34, -0.68, 0.32)
	cuff.material_override = mat_hand
	piv.add_child(cuff)
	return piv


func _build_inner_wing(side: float, mat_wing: Material) -> Node3D:
	var piv := Node3D.new()
	piv.position = Vector3(side * 0.35, 1.85, -0.35)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(5.8, 1.15, 0.18)
	mi.mesh = bm
	mi.position = Vector3(side * 2.9, 0.35, -0.25)
	mi.material_override = mat_wing
	piv.add_child(mi)
	return piv


func trigger_cuddle_reaction(duration: float = 0.8) -> void:
	squint_hold_timer = maxf(squint_hold_timer, duration)
	_set_squint_eyes(true)


func _set_squint_eyes(active: bool) -> void:
	if is_squinting == active:
		return
	is_squinting = active
	if face_plate:
		face_plate.material_override = mat_face_squint if active else mat_face_open
	if squint_badge:
		squint_badge.visible = active
	if active:
		if purr_player and purr_player.stream and not purr_player.playing:
			purr_player.play()
		AudioManager.play_dark_god_voice("nya", global_position + Vector3(0, 2.5, 0))
	else:
		if purr_player and purr_player.playing:
			purr_player.stop()


func _physics_process(delta: float) -> void:
	anim_phase += delta
	sfx_timer = maxf(0.0, sfx_timer - delta)

	if squint_hold_timer > 0.0:
		squint_hold_timer -= delta

	var cstate: int = GameState.current_castle_state
	var player: Node3D = GameState.player_ref

	if cstate == GameState.CastleState.SUCTION:
		_process_nyashing_state(delta, player)
	elif cstate == GameState.CastleState.FLYING:
		GameState.nyashing_active = false
		_process_flying_mischief(delta, player)
	else:
		GameState.nyashing_active = false
		_set_squint_eyes(squint_hold_timer > 0.0)
		# Gentle playful idle sway
		visual_root.position = visual_root.position.lerp(Vector3(0.0, 0.06 * sin(anim_phase * 2.2), 0.0), delta * 6.0)
		right_arm_pivot.rotation = right_arm_pivot.rotation.lerp(Vector3(0.0, 0.0, deg_to_rad(-10.0 * sin(anim_phase * 2.0))), delta * 5.0)
		left_arm_pivot.rotation = left_arm_pivot.rotation.lerp(Vector3(0.0, 0.0, deg_to_rad(10.0 * sin(anim_phase * 2.0))), delta * 5.0)
		wing_left_pivot.rotation.y = lerpf(wing_left_pivot.rotation.y, deg_to_rad(12.0 * sin(anim_phase * 1.8)), delta * 4.0)
		wing_right_pivot.rotation.y = lerpf(wing_right_pivot.rotation.y, deg_to_rad(-12.0 * sin(anim_phase * 1.8)), delta * 4.0)


func _process_nyashing_state(delta: float, player: Node3D) -> void:
	if not is_instance_valid(player) or GameState.is_sleeping_cutscene:
		if GameState.is_sleeping_cutscene:
			_animate_nyashing_motion(delta, player)
		return

	var local_p: Vector3 = to_local(player.global_position)
	var inside_reach: bool = local_p.length() < 9.5 and local_p.z > -3.0

	if inside_reach:
		if not GameState.nyashing_active:
			GameState.nyashing_active = true
			escape_progress = 0.0
			AudioManager.play_dark_god_voice("giggle", global_position)

		_set_squint_eyes(true)
		_animate_nyashing_motion(delta, player)

		# Check if Yumik is resisting or cuddling back
		var player_cuddling: bool = bool(player.get("is_cuddling"))
		var player_struggle: float = float(player.call("get_nyashing_struggle_strength")) if player.has_method("get_nyashing_struggle_strength") else 0.0

		if player_struggle > 0.55:
			escape_progress += delta * player_struggle
			if escape_progress >= 1.65:
				# Yumik breaks free! Push him slightly toward gate
				escape_progress = 0.0
				GameState.nyashing_active = false
				GameState.nyashing_unresisted_game_minutes = maxf(0.0, GameState.nyashing_unresisted_game_minutes - 4.0)
				if player.has_method("on_escaped_nyashing"):
					player.call("on_escaped_nyashing", global_transform.basis.z * 9.0 + Vector3.UP * 5.0)
				return
		else:
			escape_progress = maxf(0.0, escape_progress - delta * 0.4)

		if player_cuddling:
			# Mutual cuddling prevents euphoria exhaustion!
			GameState.nyashing_unresisted_game_minutes = maxf(0.0, GameState.nyashing_unresisted_game_minutes - (delta * GameState.TIME_SCALE / 60.0) * 0.5)
		else:
			# Accumulate unresisted game minutes: 10 game min -> exhausted; 20 game min -> sleep!
			var added_game_min: float = (delta * GameState.TIME_SCALE) / 60.0
			GameState.nyashing_unresisted_game_minutes += added_game_min
			if GameState.nyashing_unresisted_game_minutes >= 10.0:
				GameState.set_exhausted(true)
			if GameState.nyashing_unresisted_game_minutes >= 20.0:
				AudioManager.play_yumik_voice("sleep", player.global_position)
				GameState.start_euphoria_sleep_cutscene()
	else:
		GameState.nyashing_active = false
		_set_squint_eyes(squint_hold_timer > 0.0)


func _animate_nyashing_motion(delta: float, player: Node3D) -> void:
	# Bouncy straddling, hugging, rubbing & patting on the soft pneumatic cushion!
	var bounce_y: float = absf(sin(anim_phase * 5.8)) * 0.42
	var rub_x: float = sin(anim_phase * 3.4) * 0.28
	visual_root.position = visual_root.position.lerp(Vector3(rub_x, bounce_y, 1.35), delta * 10.0)
	left_arm_pivot.rotation = Vector3(deg_to_rad(-55.0 + 18.0 * sin(anim_phase * 6.0)), deg_to_rad(32.0), 0.0)
	right_arm_pivot.rotation = Vector3(deg_to_rad(-55.0 - 18.0 * sin(anim_phase * 6.0)), deg_to_rad(-32.0), 0.0)

	if soft_cushion:
		soft_cushion.apply_central_impulse(Vector3(rub_x * 4.0, -bounce_y * 12.0, 0.0) * delta * 15.0)

	if is_instance_valid(player) and player.has_method("apply_nyashing_cradle"):
		var target_pad: Vector3 = global_transform * Vector3(rub_x * 0.45, 0.95 + bounce_y * 0.35, 1.85)
		player.call("apply_nyashing_cradle", target_pad)

	if sfx_timer <= 0.0:
		sfx_timer = 0.85
		AudioManager.play_pvc_squeak(global_position + Vector3(0, 1.0, 1.8))


func _process_flying_mischief(delta: float, player: Node3D) -> void:
	_set_squint_eyes(squint_hold_timer > 0.0)
	# Mischievously cover mouth with right hand & flap 12m angel wings to blow throne gusts!
	right_arm_pivot.rotation = right_arm_pivot.rotation.lerp(Vector3(deg_to_rad(-118.0), deg_to_rad(-36.0), deg_to_rad(28.0)), delta * 7.0)
	left_arm_pivot.rotation = left_arm_pivot.rotation.lerp(Vector3(deg_to_rad(-25.0), 0.0, deg_to_rad(-20.0)), delta * 5.0)

	var flap: float = sin(anim_phase * 7.5)
	wing_left_pivot.rotation.y = deg_to_rad(42.0 * flap)
	wing_right_pivot.rotation.y = deg_to_rad(-42.0 * flap)

	if sfx_timer <= 0.0:
		sfx_timer = 1.4
		AudioManager.play_3d("wing_inner", global_position, 1.0, 0.08)
		if randf() < 0.35:
			AudioManager.play_dark_god_voice("giggle", global_position + Vector3(0, 2.5, 0))

	# Apply powerful interior wind gusts from the 12m wings inside the throne room!
	if is_instance_valid(player):
		var local_p: Vector3 = to_local(player.global_position)
		if absf(local_p.x) < 15.0 and absf(local_p.z) < 22.0 and local_p.y > -1.0 and local_p.y < 30.0:
			var swirl_gust: Vector3 = global_transform.basis * Vector3(sin(anim_phase * 2.7) * 14.0, 5.5 + 4.5 * absf(flap), 16.5)
			if player.has_method("apply_external_wind_impulse"):
				player.call("apply_external_wind_impulse", swirl_gust * delta)
