extends AeroBody3D
class_name CastleController

# ----------------------------------------------------------------
# НЗТБНЗ: надувной замок Темного Бога. rigid body с аэродинамикой
# (AeroBody3D + AeroInfluencer3D на крыльях), три состояния,
# ворота, всасывание, полёт.
# ----------------------------------------------------------------

enum State { NORMAL = 0, SUCTION = 1, FLYING = 2 }

var state: State = NORMAL
var _gate_open: bool = false
var _flap_angle: float = 0.0

@onready var _gate: MeshInstance3D = get_node("Gate")
@onready var _suction: Area3D = get_node("SuctionZone")
@onready var _wing_w: MeshInstance3D = get_node("WingWest")
@onready var _wing_e: MeshInstance3D = get_node("WingEast")
@onready var _wing_n: MeshInstance3D = get_node("WingNorth")

func _ready() -> void:
	add_to_group("castle")
	for i in range(1, 5):
		var r = get_node("Rope%d" % i)
		if r:
			r.add_to_group("rope")

func set_state(s: int) -> void:
	state = s
	match s:
		State.NORMAL:
			_suction.monitoring = false
			_gate_close()
		State.SUCTION:
			_gate_open()
			_suction.monitoring = true
			AudioManager.play_ambient("res://assets/audio/wind_suck.ogg", volume_db=-8)
		State.FLYING:
			_suction.monitoring = false
			_gate_close()
			gravity_scale = 0.2
			AudioManager.play_sfx("res://assets/audio/wing_flap.ogg", global_position, -6)

func _physics_process(delta: float) -> void:
	if state == State.SUCTION:
		# всасывание: мощный поток тянет всё внутрь замка (эффект Вентури)
		for body in _suction.get_overlapping_bodies():
			var dir: Vector3 = (global_position - body.global_position).normalized()
			var force: float = 35000.0
			if body is RigidBody3D:
				body.apply_central_force(dir * force * delta)
			elif body is CharacterBody3D:
				body.velocity += dir * 14.0 * delta
		# сам замок уносится в противоположную сторону
		if wind.length() > 0.1:
			apply_central_force(-wind.normalized() * 12000.0 * delta)
	if state == State.FLYING:
		_flap_angle += delta * 7.0
		var flap: float = sin(_flap_angle)
		_wing_w.rotation_degrees = Vector3(flap * 30, 0, 0)
		_wing_e.rotation_degrees = Vector3(flap * 30, 0, 0)
		_wing_n.rotation_degrees = Vector3(flap * 22, 0, 0)
		if randf() < 0.025:
			apply_central_impulse(Vector3(randf_range(-1, 1) * 4000, randf_range(0, 1) * 6000, randf_range(-1, 1) * 4000))

func _gate_open() -> void:
	if _gate_open:
		return
	_gate_open = true
	create_tween().tween_property(_gate, "position", Vector3(0, -0.2, 16.5), 1.4).set_trans(Tween.TRANS_QUAD)
	AudioManager.play_sfx("res://assets/audio/gate_close.ogg", Vector3(0, 3.5, 16.5), -4)

func _gate_close() -> void:
	if not _gate_open:
		return
	_gate_open = false
	create_tween().tween_property(_gate, "position", Vector3(0, 3.5, 16.5), 1.4).set_trans(Tween.TRANS_QUAD)
	AudioManager.play_sfx("res://assets/audio/gate_close.ogg", Vector3(0, 3.5, 16.5), -4)
