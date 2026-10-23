extends CharacterBody3D
class_name PlayerController

# ----------------------------------------------------------------
# Юмик: движение, прыжки, рагдолл, стойки, карабканье, тисканье.
# Управление с виртуального джойстика + кнопок.
# ----------------------------------------------------------------

@export var walk_speed: float = 4.5
@export var run_speed: float = 9.0
@export var gravity: float = 19.6
@export var jump_velocity: float = 2.62          # ~35 см
@export var castle_jump_velocity: float = 8.3    # ~350 см на НЗТБНЗ
@export var run_jump_velocity: float = 3.3       # ~45 см с бега

enum State { IDLE, LYING_BACK, LYING_FRONT, CRAWLING, CLIMBING, RAGDOLL, GRABBED }

var state: State = IDLE
var move_input: Vector2 = Vector2.ZERO
var is_running: bool = false
var maid_outfit: bool = false
var skirt_raised: bool = false

var main: Node                        # ссылка на Main (ставится извне)
var _shape: CapsuleShape3D
var _joystick: TouchJoystick
var _camera: TouchCamera
var _airborne_timer: float = 0.0
var _bounce_velocities: Array = []
var _bounce_accum: float = 0.0
var _bounce_index: int = 0
var _hold_joint: PinJoint3D
var _on_castle: bool = false
var _ground_name: String = ""

func set_controls(joystick: TouchJoystick, camera: TouchCamera) -> void:
	_joystick = joystick
	_camera = camera

func _ready() -> void:
	_shape = get_node("BodyCol").shape

func set_move_input(dir: Vector2, run: bool) -> void:
	move_input = dir
	is_running = run

func _physics_process(delta: float) -> void:
	if state == RAGDOLL:
		return

	# в воздухе дольше 1 секунды — рагдолл
	if not is_on_floor():
		_airborne_timer += delta
		if _airborne_timer > 1.0:
			_enter_ragdoll(Vector3(0, -6, 0))
			return
	else:
		_airborne_timer = 0.0

	var vel: Vector3 = velocity
	vel.y -= gravity * delta

	var target_h: Vector3 = Vector3.ZERO
	if move_input.length() > 0.01:
		var speed: float = is_running ? run_speed : walk_speed
		if state == CRAWLING:
			speed *= 0.45
		elif state == LYING_BACK or state == LYING_FRONT:
			speed *= 0.2
		target_h = Vector3(move_input.x, 0, -move_input.y).normalized() * speed
		if target_h.length() > 0.01:
			look_at(global_position + target_h, Vector3.UP)

	if state == CLIMBING:
		_physics_climb(delta, vel)
		velocity = vel
		move_and_slide()
		_process_bounces(delta)
		return

	velocity = Vector3(target_h.x, vel.y, target_h.z)
	move_and_slide()

	# поверхность под ногами
	if is_on_floor():
		var col: Node3D = get_floor_collider()
		_on_castle = col != null and col.get_parent() != null and col.get_parent().has_method("set_state")
		_ground_name = col.name if col else ""
		_land_on_floor()
	else:
		_on_castle = false

	_process_bounces(delta)

func _physics_climb(delta: float, vel: Vector3) -> void:
	# движение по поверхности, за которой удержались
	if _ground_name.empty():
		state = IDLE
		return
	var speed: float = walk_speed * 0.5
	var dir: Vector3 = Vector3(move_input.x, 0, -move_input.y)
	if dir.length() > 0.01:
		vel = dir * speed
	else:
		vel.x = 0
		vel.z = 0
	vel.y = -gravity * 0.3 * delta
	# ветер может сбить со скалы/ПВХ
	if GameManager.wind_speed_kmh > 40 and randf() < 0.015:
		state = IDLE
		_enter_ragdoll(Vector3(0, -10, 0))

func _land_on_floor() -> void:
	pass

func _process_bounces(delta: float) -> void:
	# отскоки при приземлении на НЗТБНЗ (50%, 25%, 10% высоты, не падают на прыгучих частях)
	if _bounce_index < _bounce_velocities.size() and is_on_floor() and _on_castle:
		_bounce_accum += delta
		if _bounce_accum >= 0.35:
			_bounce_accum = 0.0
			velocity.y = _bounce_velocities[_bounce_index]
			_bounce_index += 1
			AudioManager.play_sfx("res://assets/audio/land.ogg", global_position, -10)

func _queue_bounces(base_velocity: float) -> void:
	_bounce_velocities = [base_velocity * 0.5, base_velocity * 0.25, base_velocity * 0.1]
	_bounce_accum = 0.0
	_bounce_index = 0

# ----------------------------------------------------------------
# Действия с кнопок
# ----------------------------------------------------------------
func jump_action() -> void:
	if state == RAGDOLL or state == CLIMBING:
		return
	if is_on_floor():
		var v: float
		if _on_castle:
			v = castle_jump_velocity * (1.15 if is_running else 1.0)
		else:
			v = run_jump_velocity if is_running else jump_velocity
		velocity.y = v
		_airborne_timer = 0.0
		AudioManager.play_sfx("res://assets/audio/jump.ogg", global_position, -6)

func lie_down() -> void:
	if state == RAGDOLL: return
	if state == LYING_BACK:
		state = IDLE
		_shape.height = 1.7
		global_position = Vector3(global_position.x, global_position.y + 0.575, global_position.z)
	else:
		state = LYING_BACK
		_shape.height = 0.55
		global_position = Vector3(global_position.x, global_position.y - 0.575, global_position.z)
	AudioManager.play_sfx("res://assets/audio/pvc_squeak.ogg", global_position, -12)

func crawl() -> void:
	if state == RAGDOLL: return
	if state == CRAWLING:
		state = IDLE
		_shape.height = 1.7
		global_position = Vector3(global_position.x, global_position.y + 0.6, global_position.z)
	else:
		state = CRAWLING
		_shape.height = 0.5
		global_position = Vector3(global_position.x, global_position.y - 0.6, global_position.z)
	AudioManager.play_sfx("res://assets/audio/pvc_squeak.ogg", global_position, -12)

func climb() -> void:
	if state == RAGDOLL: return
	var from_pos: Vector3 = global_position + Vector3(0, 1.0, 0)
	var dir: Vector3 = -get_global_transform().basis.z
	var space = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from_pos, from_pos + dir * 2.2)
	query.collide_with_areas = false
	var res = space.intersect_ray(query)
	if res:
		var col: Node3D = res.collider
		if col.is_in_group("terrain") or col.is_in_group("castle") or col.is_in_group("rope"):
			state = CLIMBING if state != CLIMBING else IDLE
			_ground_name = col.name
			AudioManager.play_sfx("res://assets/audio/pvc_squeak.ogg", global_position, -10)
			return
	if state == CLIMBING:
		state = IDLE

func squeeze() -> void:
	if state == RAGDOLL: return
	if state == GRABBED:
		state = IDLE
	else:
		state = GRABBED
		AudioManager.play_sfx("res://assets/audio/pvc_squeak.ogg", global_position, -8)

func hold_castle() -> void:
	# «Не отпускай меня»: привязка к замку + рагдолл
	if _hold_joint:
		_hold_joint.queue_free()
		_hold_joint = null
		if state == GRABBED:
			state = IDLE
		AudioManager.play_sfx("res://assets/audio/pvc_squeak.ogg", global_position, -10)
		return
	var castle: Node3D = main.castle
	if not castle:
		return
	var j = PinJoint3D.new()
	j.node_a = get_path()
	j.node_b = castle.get_path()
	j.position_a = get_node("GrabPoint").global_position
	j.position_b = castle.global_position
	j.setup()
	get_tree().root.add_child(j)
	_hold_joint = j
	state = GRABBED
	AudioManager.play_sfx("res://assets/audio/pvc_squeak.ogg", global_position, -8)

func lift_skirt() -> void:
	if not maid_outfit:
		AudioManager.play_sfx("res://assets/audio/yumik_hurt.ogg", global_position, -10)
		return
	skirt_raised = not skirt_raised
	AudioManager.play_sfx("res://assets/audio/pvc_squeak.ogg", global_position, -6)

func put_on_maid_outfit() -> void:
	maid_outfit = true
	var mesh = get_node("BodyMesh")
	if mesh:
		var mat = SpatialMaterial.new()
		mat.albedo_texture = load("res://assets/textures/fabric_albedo.png")
		mat.roughness = 0.9
		mesh.material_override = mat

func die(impulse: Vector3 = Vector3.ZERO) -> void:
	_enter_ragdoll(impulse)
	var t = Timer.new()
	t.wait_time = 3.0
	t.one_shot = true
	t.timeout.connect(func(): _respawn_request())
	add_child(t)
	t.start()

func _enter_ragdoll(impulse: Vector3) -> void:
	state = RAGDOLL
	RagdollManager.activate(self, impulse)

func _respawn_request() -> void:
	if main and main.has_method("respawn_player"):
		main.respawn_player(global_position)

func respawn(pos: Vector3) -> void:
	RagdollManager.deactivate(self)
	state = IDLE
	_shape.height = 1.7
	global_position = pos
	velocity = Vector3.ZERO
	_airborne_timer = 0.0
	_bounce_velocities = []
	var mesh = get_node("BodyMesh")
	if mesh: mesh.visible = true
	collision_layer = 1
	collision_mask = 14
	set_physics_process(true)
	AudioManager.play_sfx("res://assets/audio/yumik_euphoria.ogg", global_position, -8)
