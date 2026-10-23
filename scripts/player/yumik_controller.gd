class_name YumikController
extends CharacterBody3D
## Complete Physics & Gameplay Controller for Yumik (25yo, 1.90m, 80.0kg).
## Implements:
## - Pure touch locomotion: inside joystick = Walk, outside joystick = Run
## - Postures: Stand/Walk/Run, Lie on Back, Lie on Belly, All-Fours Crawl, Climb (with PVC angle/wind/inertia slip!)
## - Exact Jumps & "Припрыжку" belly-dives:
##   * Ground: 0.35m (35cm) / 0.45m (45cm)
##   * НЗТБНЗ & Dark God: 3.50m (350cm) / 4.50m (450cm) — 10x higher!
## - Exact Post-Bounces:
##   * 50% (175 / 225cm) -> 25% (87.5 / 112.5cm) -> 10% (35 / 45cm)
##   * Passive "Очень прыгучий" surfaces (Castle 33m Wings, Throne): NON-DECAYING infinite bounces!
## - Full PhysicalBoneSimulator3D + PhysicalBone3D Ragdoll triggers:
##   1) Active "Не отпускай меня" (PinJoint3D locking both hands!)
##   2) Sitting on the Inflatable Throne (with 6 wings squeezing!)
##   3) "В воздухе" > 1.0 second without touching anything except air
##   4) Falling from height / hard impact
## - "Тискать" hugging squeeze, "Задрать подол" maid dress wind-catching,
## - Nyashing exhaustion (10 game min) & sleep euphoria (20 game min -> 8h cutscene),
## - Death & 3.0-second Resurrection within 10.0m radius!

signal posture_changed(posture_label: String)
signal hold_me_state_changed(active: bool)
signal hug_state_changed(active: bool)
signal hem_state_changed(active: bool)
signal nyashing_progress_updated(game_minutes: float, exhausted: bool)
signal euphoria_sleep_triggered()
signal died_and_respawning(seconds_left: float)

enum Posture {
	STANDING = 0,
	LIE_BACK = 1,
	LIE_BELLY = 2,
	ALL_FOURS = 3,
	CLIMBING = 4,
}

enum RagdollReason {
	NONE = 0,
	HOLD_ME_PINNED = 1,
	THRONE_SEATED = 2,
	AIRBORNE_1S = 3,
	HARD_FALL_IMPACT = 4,
	DEAD_WAITING_RESPAWN = 5,
}

const GRAVITY_ACCEL: float = 9.8
const WALK_SPEED: float = 4.2
const RUN_SPEED: float = 8.4
const CRAWL_SPEED: float = 2.6
const CLIMB_SPEED: float = 3.6

const JUMP_GROUND_M: float = 0.35
const JUMP_CASTLE_M: float = 3.50
const SKIP_GROUND_M: float = 0.45
const SKIP_CASTLE_M: float = 4.50

const POST_BOUNCE_RATIOS := [0.50, 0.25, 0.10]

# Input fed by TouchHUD
var move_input: Vector2 = Vector2.ZERO
var is_running_gait: bool = false
var camera_yaw: float = 0.0
var camera_pitch: float = -0.22

# Core nodes
var camera_pivot: Node3D
var spring_arm: SpringArm3D
var camera_3d: Camera3D
var ragdoll_rig: YumikRagdollRig
var body_col_shape: CollisionShape3D
var capsule_shape: CapsuleShape3D

# External world references
var castle_ref: InflatableCastle
var biome_gen_ref: BiomeGenerator

# State variables
var current_posture: int = Posture.STANDING
var ragdoll_reason: int = RagdollReason.NONE
var dont_let_go_active: bool = false
var is_hugging_squeeze: bool = false
var is_hem_lifted: bool = false
var is_dead: bool = false

var passive_nyashing_game_minutes: float = 0.0
var is_exhausted: bool = false

var _airborne_only_air_timer: float = 0.0
var _ragdoll_recover_timer: float = 0.0
var _respawn_timer: float = 0.0
var _death_origin: Vector3 = Vector3.ZERO

var _pending_skip_belly_land: bool = false
var _bounce_chain_active: bool = false
var _bounce_is_skip: bool = false
var _bounce_step_index: int = 0
var _prev_vertical_vel: float = 0.0
var _prev_on_floor: bool = false

var _climb_target_body: Node3D = null
var _climb_surface_normal: Vector3 = Vector3.BACK
var _active_throne: ThroneController = null

var _step_accum: float = 0.0
var _hug_sfx_timer: float = 0.0
var _slip_sfx_cooldown: float = 0.0
var _fall_voice_played: bool = false


func _ready() -> void:
	add_to_group("player_yumik")
	collision_layer = 16 # Layer 5: Player
	collision_mask = 1 | 4 | 8 | 64 # Terrain, Castle, Ropes, DarkGod
	floor_max_angle = deg_to_rad(56.0)
	floor_snap_length = 0.35
	up_direction = Vector3.UP

	_build_player_hierarchy()


func _build_player_hierarchy() -> void:
	capsule_shape = CapsuleShape3D.new()
	capsule_shape.radius = 0.34
	capsule_shape.height = 1.90
	body_col_shape = CollisionShape3D.new()
	body_col_shape.name = "StandingCapsule190cm"
	body_col_shape.shape = capsule_shape
	body_col_shape.position = Vector3(0.0, 0.95, 0.0)
	add_child(body_col_shape)

	ragdoll_rig = YumikRagdollRig.new()
	ragdoll_rig.name = "YumikVisualAndRagdollRig"
	add_child(ragdoll_rig)

	camera_pivot = Node3D.new()
	camera_pivot.name = "CameraOrbitPivot"
	camera_pivot.position = Vector3(0.0, 1.55, 0.0)
	add_child(camera_pivot)

	spring_arm = SpringArm3D.new()
	spring_arm.name = "ThirdPersonSpringArm"
	spring_arm.spring_length = 5.4
	spring_arm.collision_mask = 1 | 4
	var cam_sphere := SphereShape3D.new()
	cam_sphere.radius = 0.28
	spring_arm.shape = cam_sphere
	camera_pivot.add_child(spring_arm)

	camera_3d = Camera3D.new()
	camera_3d.name = "PlayerCamera3D"
	camera_3d.fov = 68.0
	camera_3d.far = 3600.0
	camera_3d.current = true
	spring_arm.add_child(camera_3d)


func rotate_camera_from_touch_drag(relative_px: Vector2) -> void:
	camera_yaw -= relative_px.x * 0.0042
	camera_pitch = clampf(camera_pitch - relative_px.y * 0.0036, -1.28, 1.05)


# ============================================================================
# TOUCH BUTTON ACTIONS
# ============================================================================

func toggle_dont_let_go() -> void:
	if is_dead:
		return
	if dont_let_go_active:
		dont_let_go_active = false
		_exit_ragdoll_cleanly()
		hold_me_state_changed.emit(false)
		GameState.player_status_message.emit("Юмик разжал ладони")
		return

	var target_info: Dictionary = _find_nearest_grabbable_body(3.8)
	if target_info.is_empty():
		GameState.player_status_message.emit("Рядом нет участка НЗТБНЗ или веревки, за который можно ухватиться!")
		return

	dont_let_go_active = true
	current_posture = Posture.STANDING
	_bounce_chain_active = false
	ragdoll_reason = RagdollReason.HOLD_ME_PINNED
	body_col_shape.disabled = true

	var target_body: PhysicsBody3D = target_info["body"]
	var anchor_pos: Vector3 = target_info["point"]
	ragdoll_rig.attach_hand_pins(get_parent(), target_body, anchor_pos, velocity)

	AudioManager.play_3d("yumik_hold", global_position + Vector3(0.0, 1.6, 0.0), 2.0, 1.0, true)
	AudioManager.play_3d("pvc_squeak_1", anchor_pos, 1.5, 1.0)
	if is_instance_valid(castle_ref) and is_instance_valid(castle_ref.dark_god):
		castle_ref.dark_god.trigger_gtlt_expression(3.0, true)
	hold_me_state_changed.emit(true)
	posture_changed.emit("Не отпускай меня (Ragdoll)")
	GameState.player_status_message.emit("«Не отпускай меня!» — ладони прикреплены намертво!")


func press_lie_down() -> void:
	if is_dead:
		return
	if ragdoll_reason != RagdollReason.NONE and not dont_let_go_active:
		_exit_ragdoll_cleanly()
		return
	if dont_let_go_active:
		return

	if current_posture == Posture.LIE_BACK or current_posture == Posture.LIE_BELLY:
		_set_posture(Posture.STANDING)
	else:
		# Spec: If joystick points forward -> lie on stomach; otherwise -> lie on back!
		if move_input.y < -0.25:
			_set_posture(Posture.LIE_BELLY)
		else:
			_set_posture(Posture.LIE_BACK)


func press_all_fours() -> void:
	if is_dead or dont_let_go_active:
		return
	if ragdoll_reason != RagdollReason.NONE:
		_exit_ragdoll_cleanly()
	if current_posture == Posture.ALL_FOURS:
		_set_posture(Posture.STANDING)
	else:
		_set_posture(Posture.ALL_FOURS)


func press_climb() -> void:
	if is_dead or dont_let_go_active:
		return
	if ragdoll_reason == RagdollReason.THRONE_SEATED:
		_exit_ragdoll_cleanly()
	if current_posture == Posture.CLIMBING:
		_climb_target_body = null
		_set_posture(Posture.STANDING)
		return

	var hit: Dictionary = _find_nearest_climbable(2.85)
	if hit.is_empty():
		GameState.player_status_message.emit("Нет поверхности рядом для карабканья")
		return

	_climb_target_body = hit["body"]
	_climb_surface_normal = hit["normal"]
	_bounce_chain_active = false
	_pending_skip_belly_land = false
	if ragdoll_reason != RagdollReason.NONE:
		_exit_ragdoll_cleanly()
	_set_posture(Posture.CLIMBING)
	AudioManager.play_3d("pvc_squeak_2", global_position + Vector3(0.0, 1.1, 0.0), 0.5, 1.05)


func press_jump_or_skip() -> void:
	if is_dead or dont_let_go_active:
		return
	if ragdoll_reason == RagdollReason.THRONE_SEATED or ragdoll_reason == RagdollReason.HARD_FALL_IMPACT:
		_exit_ragdoll_cleanly()

	var can_launch: bool = is_on_floor() or current_posture == Posture.CLIMBING or _bounce_chain_active
	if not can_launch:
		return

	var surf: Dictionary = _inspect_underfoot_surface()
	var on_inflatable: bool = surf["is_inflatable"]
	var do_skip: bool = is_running_gait and move_input.length() > 0.15

	var target_height_m: float = JUMP_GROUND_M
	if do_skip:
		target_height_m = SKIP_CASTLE_M if on_inflatable else SKIP_GROUND_M
	else:
		target_height_m = JUMP_CASTLE_M if on_inflatable else JUMP_GROUND_M

	var v_launch: float = sqrt(2.0 * GRAVITY_ACCEL * target_height_m)

	_climb_target_body = null
	is_hugging_squeeze = false
	hug_state_changed.emit(false)
	_set_posture(Posture.STANDING)

	var launch_dir: Vector3 = surf["normal"] if current_posture == Posture.CLIMBING else Vector3.UP
	launch_dir = (launch_dir * 0.85 + Vector3.UP * 0.45).normalized()
	velocity.y = v_launch * launch_dir.y
	if do_skip:
		var fwd: Vector3 = _get_world_wish_dir()
		velocity.x += fwd.x * 2.4
		velocity.z += fwd.z * 2.4
		_pending_skip_belly_land = true
	else:
		_pending_skip_belly_land = false

	# Arm fresh post-bounce chain for subsequent landing on НЗТБНЗ / Dark God!
	_bounce_chain_active = true
	_bounce_is_skip = do_skip
	_bounce_step_index = 0
	_airborne_only_air_timer = 0.0
	_fall_voice_played = false

	AudioManager.play_3d("skip_jump" if do_skip else "jump", global_position, 1.0, 1.0)
	AudioManager.play_3d("yumik_jump", global_position + Vector3(0.0, 1.6, 0.0), 0.5, randf_range(0.96, 1.05), true)
	if on_inflatable:
		AudioManager.play_pvc_bounce(target_height_m, global_position)


func press_hug_squeeze() -> void:
	if is_dead:
		return
	is_hugging_squeeze = not is_hugging_squeeze
	hug_state_changed.emit(is_hugging_squeeze)
	if is_hugging_squeeze:
		_bounce_chain_active = false # Hugging latches tightly onto PVC & stops infinite bouncing!
		AudioManager.play_3d("pvc_squeak_1", global_position + Vector3(0.0, 1.0, 0.0), 2.0, 1.0)
		var near_castle_or_god: bool = _is_touching_or_near_castle(3.2)
		if near_castle_or_god and is_instance_valid(castle_ref) and is_instance_valid(castle_ref.dark_god):
			castle_ref.dark_god.trigger_gtlt_expression(2.5, true)
		GameState.player_status_message.emit("Юмик крепко тискает надувную поверхность (> _ <)")
	else:
		GameState.player_status_message.emit("Юмик ослабил объятия")


func press_lift_hem() -> void:
	if not GameState.maid_outfit_equipped:
		return
	is_hem_lifted = not is_hem_lifted
	hem_state_changed.emit(is_hem_lifted)
	AudioManager.play_3d("silk_rustle", global_position + Vector3(0.0, 0.9, 0.0), 2.5, 1.0)
	GameState.player_status_message.emit("Подол платья поднят навстречу ветру!" if is_hem_lifted else "Подол платья опущен")


func toggle_maid_outfit_from_wardrobe() -> void:
	var new_val: bool = not GameState.maid_outfit_equipped
	GameState.maid_outfit_equipped = new_val
	if not new_val and is_hem_lifted:
		is_hem_lifted = false
		hem_state_changed.emit(false)
	ragdoll_rig.set_maid_outfit(new_val)
	AudioManager.play_3d("wardrobe", global_position, 1.5, 1.0)
	AudioManager.play_3d("silk_rustle", global_position + Vector3(0.0, 1.0, 0.0), 2.5, 1.05)
	GameState.maid_outfit_changed.emit(new_val)
	GameState.player_status_message.emit(
		"Надет комплект горничной (розовое шелковое платье, голубые чулки, каблуки)!" if new_val
		else "Возвращена обычная одежда Юмика (белая пижама и джинсы)"
	)


# ============================================================================
# THRONE, NYASHING, DEATH & 3-SECOND RESURRECTION
# ============================================================================

func enter_throne_hug_ragdoll(throne_node: ThroneController) -> void:
	if is_dead or dont_let_go_active:
		return
	_active_throne = throne_node
	_bounce_chain_active = false
	ragdoll_reason = RagdollReason.THRONE_SEATED
	body_col_shape.disabled = true
	global_position = throne_node.get_seat_anchor_global() - Vector3(0.0, 0.65, 0.0)
	ragdoll_rig.start_ragdoll(Vector3.ZERO)
	posture_changed.emit("На троне (Ragdoll + крылья)")
	GameState.player_status_message.emit("Крылья надувного трона сжимают и тискают Юмика!")


func apply_throne_squeeze_force(seat_world_pos: Vector3, pulse: float) -> void:
	if ragdoll_reason != RagdollReason.THRONE_SEATED:
		return
	var hips_pos: Vector3 = ragdoll_rig.get_ragdoll_hips_global_position()
	var pull: Vector3 = (seat_world_pos - hips_pos) * (185.0 + 65.0 * pulse)
	ragdoll_rig.apply_ragdoll_central_force(pull)


func apply_dark_god_nyashing(god_world_pos: Vector3, bounce_offset_y: float, delta: float) -> void:
	if is_dead or GameState.is_sleep_cutscene_active:
		return

	# Soft elastic physical coupling toward the bouncy PVC floor under the Dark God!
	var pull_target := god_world_pos + Vector3(0.0, 0.15 + bounce_offset_y * 0.55, 0.25)
	var diff: Vector3 = pull_target - global_position
	var struggling: bool = move_input.length() > 0.65 and is_running_gait

	if struggling:
		# Yumik actively fighting to wriggle out!
		velocity += diff.limit_length(1.5) * (3.5 * delta)
		passive_nyashing_game_minutes = maxf(passive_nyashing_game_minutes - delta * GameState.GAME_MINUTES_PER_REAL_SECOND * 1.4, 0.0)
	elif is_hugging_squeeze:
		# Yumik is actively nyashing/hugging the Dark God BACK -> holds off exhaustion!
		velocity = velocity.lerp(diff * 4.5, clampf(delta * 5.0, 0.0, 1.0))
		passive_nyashing_game_minutes = maxf(passive_nyashing_game_minutes - delta * GameState.GAME_MINUTES_PER_REAL_SECOND * 0.8, 0.0)
	else:
		# Yumik neither escapes nor nyashes back -> soft elastic cuddle bounce + euphoria timer!
		if current_posture != Posture.LIE_BACK:
			_set_posture(Posture.LIE_BACK)
		velocity = velocity.lerp(diff * 5.5, clampf(delta * 6.0, 0.0, 1.0))
		passive_nyashing_game_minutes += delta * GameState.GAME_MINUTES_PER_REAL_SECOND

	var prev_exhausted: bool = is_exhausted
	is_exhausted = passive_nyashing_game_minutes >= 10.0
	if is_exhausted and not prev_exhausted:
		GameState.player_status_message.emit("10 игровых минут няшинга: Юмик истощен — движения замедлены!")

	nyashing_progress_updated.emit(passive_nyashing_game_minutes, is_exhausted)

	if passive_nyashing_game_minutes >= 20.0:
		passive_nyashing_game_minutes = 0.0
		is_exhausted = false
		nyashing_progress_updated.emit(0.0, false)
		AudioManager.play_2d("yumik_sleep", 1.5, 1.0, true)
		euphoria_sleep_triggered.emit()


func reset_after_sleep() -> void:
	passive_nyashing_game_minutes = 0.0
	is_exhausted = false
	nyashing_progress_updated.emit(0.0, false)
	if ragdoll_reason != RagdollReason.NONE:
		_exit_ragdoll_cleanly()
	_set_posture(Posture.STANDING)


func trigger_death(cause_msg: String) -> void:
	if is_dead:
		return
	is_dead = true
	dont_let_go_active = false
	hold_me_state_changed.emit(false)
	is_hugging_squeeze = false
	hug_state_changed.emit(false)
	_death_origin = global_position
	_respawn_timer = 3.0
	ragdoll_reason = RagdollReason.DEAD_WAITING_RESPAWN
	body_col_shape.disabled = true
	ragdoll_rig.start_ragdoll(velocity * 0.4)
	AudioManager.play_3d("yumik_oof", global_position + Vector3(0.0, 1.0, 0.0), 3.0, 0.92, true)
	GameState.player_status_message.emit("%s Воскрешение через 3 секунды..." % cause_msg)


func _complete_resurrection() -> void:
	is_dead = false
	_exit_ragdoll_cleanly()
	# Respawn within 10.0m radius around death position cleanly above ground/water!
	var best_pos: Vector3 = _death_origin + Vector3(0.0, 2.5, 0.0)
	for _attempt in range(16):
		var ang: float = randf() * TAU
		var rad: float = randf_range(2.5, 9.8)
		var cand := _death_origin + Vector3(cos(ang) * rad, 0.0, sin(ang) * rad)
		if biome_gen_ref != null:
			var gh: float = biome_gen_ref.get_height(cand.x, cand.z)
			if gh > BiomeGenerator.WATER_LEVEL + 0.35:
				best_pos = Vector3(cand.x, gh + 1.25, cand.z)
				break
			best_pos = Vector3(cand.x, maxf(gh, BiomeGenerator.WATER_LEVEL) + 2.0, cand.z)
	global_position = best_pos
	velocity = Vector3.ZERO
	_airborne_only_air_timer = 0.0
	_set_posture(Posture.STANDING)
	AudioManager.play_3d("yumik_respawn", global_position + Vector3(0.0, 1.5, 0.0), 2.5, 1.0, true)
	GameState.player_status_message.emit("Юмик воскрес в радиусе 10 метров!")


# ============================================================================
# PHYSICS TICK & POST-BOUNCE / SLIP / RAGDOLL / WIND SOLVERS
# ============================================================================

func _physics_process(delta: float) -> void:
	if _slip_sfx_cooldown > 0.0:
		_slip_sfx_cooldown -= delta

	# Keep camera orbiting smoothly in both character mode and ragdoll mode
	var focus_world: Vector3 = ragdoll_rig.get_ragdoll_hips_global_position() + Vector3(0.0, 0.45, 0.0) if ragdoll_rig.is_ragdoll_active() else global_position + Vector3(0.0, 1.48, 0.0)
	camera_pivot.global_position = camera_pivot.global_position.lerp(focus_world, clampf(delta * 16.0, 0.0, 1.0))
	camera_pivot.global_rotation = Vector3(camera_pitch, camera_yaw, 0.0)

	# 1. Death 3.0s resurrection timer
	if is_dead:
		_respawn_timer -= delta
		died_and_respawning.emit(maxf(_respawn_timer, 0.0))
		if _respawn_timer <= 0.0:
			_complete_resurrection()
		return

	# Check drowning deep in lake/river water (> 2.3m below surface without swimming out)
	if biome_gen_ref != null and global_position.y < BiomeGenerator.WATER_LEVEL - 2.35 and not _is_touching_or_near_castle(6.0):
		trigger_death("Юмик ушел под воду!")
		return

	# Decay nyashing counter slowly when safely outside Nyashing
	if passive_nyashing_game_minutes > 0.0 and (not is_instance_valid(castle_ref) or castle_ref.current_state != GameState.CastleState.SUCTION):
		passive_nyashing_game_minutes = maxf(passive_nyashing_game_minutes - delta * 0.5, 0.0)
		is_exhausted = passive_nyashing_game_minutes >= 10.0
		nyashing_progress_updated.emit(passive_nyashing_game_minutes, is_exhausted)

	# 2. Active Ragdoll Simulation States
	if ragdoll_rig.is_ragdoll_active():
		_process_active_ragdoll(delta)
		return

	# 3. Climbing State (Cliffs, 75m Hemp Ropes, Castle PVC Walls/Towers/Wings, Dark God)
	if current_posture == Posture.CLIMBING:
		_process_climbing(delta)
		return

	# 4. Standard / Prone / All-Fours / Airborne Movement & Physics
	_prev_vertical_vel = velocity.y
	_prev_on_floor = is_on_floor()

	if not is_on_floor():
		velocity.y -= GRAVITY_ACCEL * delta
		_airborne_only_air_timer += delta
		if _airborne_only_air_timer > 0.75 and velocity.y < -8.0 and not _fall_voice_played:
			_fall_voice_played = true
			AudioManager.play_3d("yumik_fall", global_position + Vector3(0.0, 1.4, 0.0), 1.5, 1.0, true)

		# Spec Rule: In "В воздухе" (touching nothing except air for > 1.0 second) -> enter Ragdoll!
		if _airborne_only_air_timer > 1.0:
			_enter_ragdoll(RagdollReason.AIRBORNE_1S, "В воздухе > 1 сек (Ragdoll)")
			return
	else:
		_airborne_only_air_timer = 0.0
		_fall_voice_played = false

	# Wind aerodynamic force on Yumik + Maid Dress "Задрать подол" sail/parachute force!
	var local_wind: Vector3 = WindManager.get_wind_at_position(global_position + Vector3(0.0, 1.0, 0.0))
	var rel_air: Vector3 = local_wind - velocity
	var drag_area: float = 0.62
	if GameState.maid_outfit_equipped and is_hem_lifted:
		# Raised ankle-length ruffled silk skirt catches massive wind & updraft!
		drag_area = 4.65
		velocity.y += maxf(rel_air.length() * 0.24, 0.0) * delta * 8.5
	if is_hugging_squeeze:
		drag_area *= 0.22
	var wind_push: Vector3 = rel_air * rel_air.length() * (0.5 * 1.225 * drag_area / YumikRagdollRig.TOTAL_MASS_KG)
	velocity += wind_push * delta

	# Horizontal wish movement
	var speed_mult: float = 0.42 if is_exhausted else 1.0
	var base_spd: float = WALK_SPEED
	match current_posture:
		Posture.LIE_BACK, Posture.LIE_BELLY:
			base_spd = 0.85
		Posture.ALL_FOURS:
			base_spd = CRAWL_SPEED
		_:
			base_spd = RUN_SPEED if is_running_gait else WALK_SPEED

	if is_hugging_squeeze:
		base_spd *= 0.25
		_hug_sfx_timer += delta
		if _hug_sfx_timer >= 0.85:
			_hug_sfx_timer = 0.0
			AudioManager.play_3d("pvc_squeak_2", global_position + Vector3(0.0, 1.0, 0.0), -1.0, randf_range(0.92, 1.15))
			if _is_touching_or_near_castle(3.2) and is_instance_valid(castle_ref) and is_instance_valid(castle_ref.dark_god):
				castle_ref.dark_god.trigger_gtlt_expression(1.4, false)

	var wish_dir: Vector3 = _get_world_wish_dir()
	var target_hvel: Vector3 = wish_dir * (base_spd * move_input.length() * speed_mult)
	var accel: float = 14.0 if is_on_floor() else 3.8
	velocity.x = move_toward(velocity.x, target_hvel.x + local_wind.x * (0.12 if not is_on_floor() else 0.0), accel * delta)
	velocity.z = move_toward(velocity.z, target_hvel.z + local_wind.z * (0.12 if not is_on_floor() else 0.0), accel * delta)

	if wish_dir.length_squared() > 0.01:
		var target_rot_y: float = atan2(-wish_dir.x, -wish_dir.z)
		ragdoll_rig.rotation.y = lerp_angle(ragdoll_rig.rotation.y, target_rot_y, clampf(delta * 10.0, 0.0, 1.0))

	move_and_slide()

	# Shallow water buoyancy if wading in lake/river
	if biome_gen_ref != null and global_position.y < BiomeGenerator.WATER_LEVEL - 0.55:
		velocity.y = lerpf(velocity.y, 2.2, clampf(delta * 4.0, 0.0, 1.0))

	# Footstep OGG audio
	var hspeed: float = Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and hspeed > 0.55:
		_step_accum += hspeed * delta
		if _step_accum >= 1.85:
			_step_accum = 0.0
			var usurf: Dictionary = _inspect_underfoot_surface()
			AudioManager.play_step(usurf["kind"], global_position, is_running_gait)

	# 5. Handle Touchdown: Hard Fall Ragdoll / Death OR "Припрыжку" Belly Flop OR Post-Bounce Chain!
	if is_on_floor() and not _prev_on_floor:
		_handle_landing(_prev_vertical_vel)

	# Animate procedural pose on 1.90m skeleton
	var pose_key := "stand"
	if not is_on_floor() and _pending_skip_belly_land:
		pose_key = "skip_dive"
	elif current_posture == Posture.LIE_BACK:
		pose_key = "lie_back"
	elif current_posture == Posture.LIE_BELLY:
		pose_key = "lie_belly"
	elif current_posture == Posture.ALL_FOURS:
		pose_key = "all_fours"
	ragdoll_rig.update_procedural_pose(pose_key, clampf(hspeed / RUN_SPEED, 0.0, 1.0), is_hem_lifted, is_hugging_squeeze, delta)


func _handle_landing(impact_vy: float) -> void:
	var surf: Dictionary = _inspect_underfoot_surface()
	var on_inflatable: bool = surf["is_inflatable"]
	var very_bouncy: bool = surf["very_bouncy"]

	# Hard impact on solid non-inflatable ground!
	if not on_inflatable:
		_bounce_chain_active = false
		if _pending_skip_belly_land:
			_pending_skip_belly_land = false
			_set_posture(Posture.LIE_BELLY)
			AudioManager.play_3d("land_ground", global_position, 2.0, 1.0)
			return
		if impact_vy < -25.0:
			trigger_death("Смертельный удар при падении с большой высоты!")
			return
		if impact_vy < -13.0:
			AudioManager.play_3d("land_ground", global_position, 3.0, 0.9)
			_enter_ragdoll(RagdollReason.HARD_FALL_IMPACT, "Сильный удар (Ragdoll)")
			return
		if impact_vy < -3.0:
			AudioManager.play_3d("land_ground", global_position, -1.0, 1.05)
		return

	# LANDED ON НЗТБНЗ OR DARK GOD!
	if _pending_skip_belly_land:
		_pending_skip_belly_land = false
		_set_posture(Posture.LIE_BELLY)

	# If player actively hugs ("Тискать"), absorb bounce into hug!
	if is_hugging_squeeze:
		_bounce_chain_active = false
		AudioManager.play_pvc_bounce(0.5, global_position)
		return

	var base_jump_h: float = SKIP_CASTLE_M if _bounce_is_skip else JUMP_CASTLE_M

	# Passive effect "Очень прыгучий" (33m Wings, 12m Wings, Throne): height NEVER decays -> infinite bounce!
	if very_bouncy:
		var v_inf: float = sqrt(2.0 * GRAVITY_ACCEL * base_jump_h)
		velocity = velocity + surf["normal"] * v_inf
		velocity.y = maxf(velocity.y, v_inf * 0.92)
		AudioManager.play_pvc_bounce(base_jump_h, global_position)
		GameState.player_status_message.emit("«Очень прыгучий» участок: отскок %.2f м без потери высоты!" % base_jump_h)
		return

	# Standard PVC / Dark God Post-Bounces: 50% (175/225cm) -> 25% (87.5/112.5cm) -> 10% (35/45cm)!
	if not _bounce_chain_active and impact_vy < -3.5:
		_bounce_chain_active = true
		_bounce_is_skip = false
		_bounce_step_index = 0

	if _bounce_chain_active and _bounce_step_index < POST_BOUNCE_RATIOS.size():
		var ratio: float = POST_BOUNCE_RATIOS[_bounce_step_index]
		var next_h: float = base_jump_h * ratio
		_bounce_step_index += 1
		var v_reb: float = sqrt(2.0 * GRAVITY_ACCEL * next_h)
		velocity.y = v_reb
		AudioManager.play_pvc_bounce(next_h, global_position)
		GameState.player_status_message.emit("Пост-прыжок #%d на ПВХ: %.1f см (%.0f%%)" % [_bounce_step_index, next_h * 100.0, ratio * 100.0])
	else:
		_bounce_chain_active = false
		AudioManager.play_pvc_bounce(0.35, global_position)


func _process_climbing(delta: float) -> void:
	if not is_instance_valid(_climb_target_body):
		_set_posture(Posture.STANDING)
		return

	# 1. Special Physical Rope Climbing along 75m Hemp Ropes!
	if _climb_target_body.has_meta("rope_owner"):
		var rope: HempRope75m = _climb_target_body.get_meta("rope_owner")
		if is_instance_valid(rope):
			var climb_delta: float = -move_input.y * CLIMB_SPEED * delta
			var res: Dictionary = rope.get_climb_position_along_rope(global_position + Vector3(0.0, 1.0, 0.0), climb_delta)
			var target_p: Vector3 = res["pos"] - Vector3(0.0, 1.0, 0.0)
			velocity = (target_p - global_position) / maxf(delta, 0.001)
			global_position = target_p
			_climb_target_body = res["body"]
			ragdoll_rig.update_procedural_pose("climb", absf(move_input.y), is_hem_lifted, is_hugging_squeeze, delta)
			return

	# 2. Surface Climbing (Rock Cliffs, НЗТБНЗ 33m PVC Walls/Towers/Wings, Dark God)
	var probe: Dictionary = _find_nearest_climbable(2.5)
	if probe.is_empty():
		_climb_target_body = null
		_set_posture(Posture.STANDING)
		return

	_climb_target_body = probe["body"]
	_climb_surface_normal = probe["normal"]
	var grip: float = probe["grip"]
	if is_hugging_squeeze:
		grip *= 3.0 # Hugging ("Тискать") dramatically increases grip on slick PVC!

	# Carry Yumik with moving/rotating RigidBody3D / AeroBody3D castle!
	var carrier_vel := Vector3.ZERO
	var inertia_load: float = 0.0
	if _climb_target_body is RigidBody3D:
		var rb := _climb_target_body as RigidBody3D
		var r_rel: Vector3 = global_position - rb.global_position
		carrier_vel = rb.linear_velocity + rb.angular_velocity.cross(r_rel)
		inertia_load = rb.angular_velocity.length() * 6.5 + rb.linear_velocity.length() * 0.06
		if rb is AeroBody3D:
			inertia_load += (rb as AeroBody3D).linear_acceleration.length() * 0.08

	# Realistic PVC Slip Physics: accounts for surface overhang angle, castle inertia, and local wind!
	var overhang_severity: float = clampf(1.0 - (_climb_surface_normal.y + 0.35), 0.0, 1.65)
	var wind_speed_mps: float = WindManager.get_wind_at_position(global_position).length()
	var slip_demand: float = overhang_severity * 0.62 + (wind_speed_mps / 42.0) * 0.55 + inertia_load * 0.22
	var net_slip: float = maxf(slip_demand - grip, 0.0)

	if net_slip > 0.72:
		# Extreme overhang + hurricane wind / flip throws Yumik completely off the slick PVC!
		_climb_target_body = null
		_set_posture(Posture.STANDING)
		velocity = carrier_vel + _climb_surface_normal * 3.5 + Vector3.DOWN * 2.0
		AudioManager.play_3d("pvc_slip", global_position, 3.0, 0.95)
		GameState.player_status_message.emit("Юмик сорвался со скользкого ПВХ!")
		return

	# Tangent basis across wall surface
	var wall_up: Vector3 = (Vector3.UP - _climb_surface_normal * Vector3.UP.dot(_climb_surface_normal))
	if wall_up.length_squared() < 0.01:
		wall_up = Vector3.FORWARD
	wall_up = wall_up.normalized()
	var wall_right: Vector3 = wall_up.cross(_climb_surface_normal).normalized()

	var climb_vel: Vector3 = (wall_up * (-move_input.y) + wall_right * move_input.x) * CLIMB_SPEED
	if net_slip > 0.02:
		climb_vel -= wall_up * (net_slip * 7.5)
		if _slip_sfx_cooldown <= 0.0:
			_slip_sfx_cooldown = 0.75
			AudioManager.play_3d("pvc_slip", global_position, 0.5, randf_range(0.95, 1.12))

	# Gently press into surface so Jolt contact remains continuous
	velocity = carrier_vel + climb_vel - _climb_surface_normal * 1.65
	move_and_slide()

	var face_wall_yaw: float = atan2(_climb_surface_normal.x, _climb_surface_normal.z)
	ragdoll_rig.rotation.y = lerp_angle(ragdoll_rig.rotation.y, face_wall_yaw, clampf(delta * 10.0, 0.0, 1.0))
	ragdoll_rig.update_procedural_pose("climb", clampf((absf(move_input.x) + absf(move_input.y)), 0.0, 1.0), is_hem_lifted, is_hugging_squeeze, delta)


func _enter_ragdoll(reason: int, label_text: String) -> void:
	if ragdoll_rig.is_ragdoll_active():
		return
	ragdoll_reason = reason
	_ragdoll_recover_timer = 0.0
	body_col_shape.disabled = true
	ragdoll_rig.start_ragdoll(velocity)
	posture_changed.emit(label_text)


func _process_active_ragdoll(delta: float) -> void:
	var hips_pos: Vector3 = ragdoll_rig.get_ragdoll_hips_global_position()

	# Apply wind directly to simulated PhysicalBone3D ragdoll limbs too!
	var w: Vector3 = WindManager.get_wind_at_position(hips_pos)
	var rag_area: float = 2.8 if (GameState.maid_outfit_equipped and is_hem_lifted) else 0.65
	ragdoll_rig.apply_ragdoll_central_force(w * w.length() * (0.5 * 1.225 * rag_area))

	# Follow ragdoll hips if not locked on Throne
	if ragdoll_reason == RagdollReason.AIRBORNE_1S or ragdoll_reason == RagdollReason.HARD_FALL_IMPACT:
		_ragdoll_recover_timer += delta
		# Check if ragdoll has landed near ground/castle surface so player can stand back up cleanly!
		var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
		var rq := PhysicsRayQueryParameters3D.create(hips_pos + Vector3(0.0, 0.35, 0.0), hips_pos + Vector3(0.0, -1.15, 0.0), 1 | 4 | 64)
		var rhit: Dictionary = space.intersect_ray(rq)
		if not rhit.is_empty() and _ragdoll_recover_timer > 0.85:
			# Landed on castle wing / bouncy surface during airborne ragdoll!
			var hit_col: Object = rhit["collider"]
			var hit_shape_idx: int = rhit.get("shape", -1)
			var info: Dictionary = _extract_collider_surface_info(hit_col, hit_shape_idx, rhit["normal"])
			var impact_speed: float = 0.0
			if ragdoll_rig.physical_bones.has("Hips"):
				impact_speed = -ragdoll_rig.physical_bones["Hips"].linear_velocity.y
			if not info["is_inflatable"] and impact_speed > 25.0:
				global_position = hips_pos
				trigger_death("Смертельное падение в режиме Ragdoll!")
				return
			_exit_ragdoll_cleanly()
			if info["is_inflatable"]:
				_bounce_chain_active = true
				_bounce_step_index = 0
				_handle_landing(-maxf(impact_speed, 8.0))
			return

		# Safety check if falling underwater in ragdoll
		if biome_gen_ref != null and hips_pos.y < BiomeGenerator.WATER_LEVEL - 2.35:
			global_position = hips_pos
			trigger_death("Юмик упал глубоко в озеро!")


func _exit_ragdoll_cleanly() -> void:
	if is_instance_valid(_active_throne):
		_active_throne.release_seated_player()
		_active_throne = null
	var rec_pos: Vector3 = ragdoll_rig.stop_ragdoll()
	ragdoll_reason = RagdollReason.NONE
	body_col_shape.disabled = false
	global_position = rec_pos + Vector3(0.0, 0.35, 0.0)
	velocity = Vector3.ZERO
	_airborne_only_air_timer = 0.0
	_set_posture(Posture.STANDING)


func _set_posture(p: int) -> void:
	current_posture = p
	match p:
		Posture.LIE_BACK:
			capsule_shape.height = 0.72
			body_col_shape.position = Vector3(0.0, 0.36, 0.0)
			posture_changed.emit("Лежит на спине")
		Posture.LIE_BELLY:
			capsule_shape.height = 0.72
			body_col_shape.position = Vector3(0.0, 0.36, 0.0)
			posture_changed.emit("Лежит на животе")
		Posture.ALL_FOURS:
			capsule_shape.height = 1.05
			body_col_shape.position = Vector3(0.0, 0.525, 0.0)
			posture_changed.emit("На четвереньках")
		Posture.CLIMBING:
			capsule_shape.height = 1.75
			body_col_shape.position = Vector3(0.0, 0.88, 0.0)
			posture_changed.emit("Карабкается")
		_:
			capsule_shape.height = 1.90
			body_col_shape.position = Vector3(0.0, 0.95, 0.0)
			posture_changed.emit("На ногах")


# ============================================================================
# SURFACE & GRAB QUERIES
# ============================================================================

func _get_world_wish_dir() -> Vector3:
	if move_input.length_squared() < 0.0001:
		return Vector3.ZERO
	var cam_basis := Basis(Vector3.UP, camera_yaw)
	var fwd: Vector3 = -cam_basis.z
	var right: Vector3 = cam_basis.x
	var d: Vector3 = (right * move_input.x + fwd * (-move_input.y))
	d.y = 0.0
	return d.normalized() if d.length_squared() > 0.0001 else Vector3.ZERO


func _extract_collider_surface_info(collider: Object, shape_index: int, hit_normal: Vector3) -> Dictionary:
	var result := {
		"kind": "grass",
		"is_inflatable": false,
		"very_bouncy": false,
		"grip": 0.85,
		"normal": hit_normal,
	}
	if collider == null or not is_instance_valid(collider):
		return result

	if collider is CollisionObject3D:
		var co := collider as CollisionObject3D
		if co.has_meta("surface_kind"):
			result["kind"] = String(co.get_meta("surface_kind"))
		if co.has_meta("grip_factor"):
			result["grip"] = float(co.get_meta("grip_factor"))
		if co.has_meta("very_bouncy"):
			result["very_bouncy"] = bool(co.get_meta("very_bouncy"))

		# Inspect exact child CollisionShape3D hit on compound AeroBody3D castle (e.g. 33m Wing vs Throne vs Wall)!
		if shape_index >= 0:
			var owner_id: int = co.shape_find_owner(shape_index)
			if owner_id != -1:
				var shape_node: Object = co.shape_owner_get_owner(owner_id)
				if shape_node != null and shape_node.has_meta("surface_kind"):
					result["kind"] = String(shape_node.get_meta("surface_kind"))
				if shape_node != null and shape_node.has_meta("very_bouncy"):
					result["very_bouncy"] = bool(shape_node.get_meta("very_bouncy"))
				if shape_node != null and shape_node.has_meta("grip_factor"):
					result["grip"] = float(shape_node.get_meta("grip_factor"))

	var k: String = result["kind"]
	if k.begins_with("pvc") or k == "dark_god":
		result["is_inflatable"] = true
	if k == "pvc_wing" or k == "pvc_throne":
		result["very_bouncy"] = true
	return result


func _inspect_underfoot_surface() -> Dictionary:
	if get_slide_collision_count() > 0:
		for i in range(get_slide_collision_count()):
			var kc: KinematicCollision3D = get_slide_collision(i)
			if kc.get_normal().y > 0.25:
				return _extract_collider_surface_info(kc.get_collider(), kc.get_collider_shape_index(), kc.get_normal())

	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var rq := PhysicsRayQueryParameters3D.create(global_position + Vector3(0.0, 0.55, 0.0), global_position + Vector3(0.0, -1.25, 0.0), 1 | 4 | 64)
	rq.exclude = [get_rid()]
	var hit: Dictionary = space.intersect_ray(rq)
	if not hit.is_empty():
		return _extract_collider_surface_info(hit["collider"], hit.get("shape", -1), hit["normal"])
	return {"kind": "grass", "is_inflatable": false, "very_bouncy": false, "grip": 0.85, "normal": Vector3.UP}


func _find_nearest_climbable(radius: float) -> Dictionary:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var origin: Vector3 = global_position + Vector3(0.0, 1.0, 0.0)

	# First check 75m hemp ropes & Dark God / Castle / Rock sphere query
	var sp := PhysicsShapeQueryParameters3D.new()
	var sph := SphereShape3D.new()
	sph.radius = radius
	sp.shape = sph
	sp.transform = Transform3D(Basis.IDENTITY, origin)
	sp.collision_mask = 8 | 64 # Ropes & DarkGod prioritized for easy grabbing!
	var overlaps: Array[Dictionary] = space.intersect_shape(sp, 8)
	for ov in overlaps:
		var col: Object = ov["collider"]
		if col is Node3D:
			var cnode := col as Node3D
			var nrm: Vector3 = (origin - cnode.global_position).normalized()
			if nrm.length_squared() < 0.01:
				nrm = Vector3.BACK
			var info: Dictionary = _extract_collider_surface_info(col, ov.get("shape", -1), nrm)
			return {"body": cnode, "normal": nrm, "grip": info["grip"]}

	# Radial 8-direction ray fan for Castle walls/towers/wings & Mountain rock cliffs!
	var best_d: float = INF
	var best_res: Dictionary = {}
	for i in range(8):
		var ang: float = (float(i) / 8.0) * TAU + camera_yaw
		var dir := Vector3(sin(ang), 0.0, cos(ang))
		var rq := PhysicsRayQueryParameters3D.create(origin, origin + dir * radius, 1 | 4 | 64)
		rq.exclude = [get_rid()]
		var hit: Dictionary = space.intersect_ray(rq)
		if not hit.is_empty():
			var d: float = origin.distance_to(hit["position"])
			var nrm: Vector3 = hit["normal"]
			# Allow climbing any castle surface OR steep rocky terrain (> 34 deg)
			var info: Dictionary = _extract_collider_surface_info(hit["collider"], hit.get("shape", -1), nrm)
			if info["is_inflatable"] or nrm.y < 0.83:
				if d < best_d:
					best_d = d
					best_res = {"body": hit["collider"], "normal": nrm, "grip": info["grip"]}
	return best_res


func _find_nearest_grabbable_body(radius: float) -> Dictionary:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var origin: Vector3 = global_position + Vector3(0.0, 1.25, 0.0)

	var sp := PhysicsShapeQueryParameters3D.new()
	var sph := SphereShape3D.new()
	sph.radius = radius
	sp.shape = sph
	sp.transform = Transform3D(Basis.IDENTITY, origin)
	sp.collision_mask = 4 | 8 | 64 # Castle, Ropes, DarkGod
	var hits: Array[Dictionary] = space.intersect_shape(sp, 8)
	for h in hits:
		var col: Object = h["collider"]
		if col is PhysicsBody3D:
			var pb := col as PhysicsBody3D
			var anchor: Vector3 = origin
			var rq := PhysicsRayQueryParameters3D.create(origin, pb.global_position, 4 | 8 | 64)
			rq.exclude = [get_rid()]
			var rhit: Dictionary = space.intersect_ray(rq)
			if not rhit.is_empty():
				anchor = rhit["position"] + rhit["normal"] * 0.08
			elif is_on_floor():
				anchor = global_position + Vector3(0.0, 0.20, 0.0)
			else:
				anchor = origin
			return {"body": pb, "point": anchor}
	return {}


func _is_touching_or_near_castle(radius: float) -> bool:
	return not _find_nearest_grabbable_body(radius).is_empty()
