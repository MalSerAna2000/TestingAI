class_name ThroneController
extends Node3D
## 2.5 x 2.5 x 5.0m Inflatable Throne behind the Dark God against the north hall wall.
## Features:
## - Passive effect "Очень прыгучий" (infinite non-decaying bounce!)
## - Three pairs (6 wings) of dark inflatable angel wings (7.0m span = 3.5m half-span each)
## - When Yumik sits on the Throne, transitions Yumik into Ragdoll while all 6 wings wrap and squeeze him!

signal player_seated_changed(is_seated: bool)

var _left_wings: Array[Node3D] = []
var _right_wings: Array[Node3D] = []
var _seat_area: Area3D
var _seated_player: Node3D = null
var _squeeze_phase: float = 0.0
var _reentry_cooldown: float = 0.0


func _ready() -> void:
	_build_throne_and_wings()


func _build_throne_and_wings() -> void:
	var pvc_mat: Material = load("res://assets/materials/mat_castle_pvc.tres")
	var wing_mat: Material = load("res://assets/materials/mat_castle_wing.tres")
	var throne_mesh: Mesh = load("res://assets/models/castle_throne_5m.obj")
	var wing_mesh: Mesh = load("res://assets/models/throne_wing_3_5m.obj")

	var tmi := MeshInstance3D.new()
	tmi.name = "ThroneMesh"
	tmi.mesh = throne_mesh
	tmi.material_override = pvc_mat
	add_child(tmi)

	# 3 pairs of dark inflatable angel wings on backrest (span 7m = 3.5m each side)
	var pair_heights := [1.55, 2.75, 3.95]
	var pair_tilts := [-0.16, 0.04, 0.24]
	for idx in range(3):
		var wy: float = pair_heights[idx]
		var wt: float = pair_tilts[idx]

		var pivot_r := Node3D.new()
		pivot_r.name = "ThroneWingR_%d" % idx
		pivot_r.position = Vector3(0.55, wy, -0.78)
		pivot_r.rotation = Vector3(0.0, 0.14, wt)
		var mi_r := MeshInstance3D.new()
		mi_r.mesh = wing_mesh
		mi_r.material_override = wing_mat
		pivot_r.add_child(mi_r)
		add_child(pivot_r)
		_right_wings.append(pivot_r)

		var pivot_l := Node3D.new()
		pivot_l.name = "ThroneWingL_%d" % idx
		pivot_l.position = Vector3(-0.55, wy, -0.78)
		pivot_l.rotation = Vector3(0.0, -0.14, -wt)
		var mi_l := MeshInstance3D.new()
		mi_l.mesh = wing_mesh
		mi_l.scale = Vector3(-1.0, 1.0, 1.0)
		mi_l.material_override = wing_mat
		pivot_l.add_child(mi_l)
		add_child(pivot_l)
		_left_wings.append(pivot_l)

	var label := Label3D.new()
	label.text = "Надувной Трон\n[Очень прыгучий • 6 крыльев]"
	label.font_size = 38
	label.modulate = Color(1.0, 0.72, 0.86)
	label.outline_size = 10
	label.position = Vector3(0.0, 5.45, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)

	_seat_area = Area3D.new()
	_seat_area.name = "ThroneSeatTrigger"
	_seat_area.collision_layer = 128
	_seat_area.collision_mask = 16
	var sbox := BoxShape3D.new()
	sbox.size = Vector3(2.1, 1.6, 2.0)
	var scol := CollisionShape3D.new()
	scol.shape = sbox
	scol.position = Vector3(0.0, 1.85, 0.25)
	_seat_area.add_child(scol)
	_seat_area.body_entered.connect(_on_seat_body_entered)
	add_child(_seat_area)


func _on_seat_body_entered(body: Node3D) -> void:
	if _reentry_cooldown > 0.0 or _seated_player != null:
		return
	if body != null and body.is_in_group("player_yumik") and body.has_method("enter_throne_hug_ragdoll"):
		# Only seat when gently stepping onto cushion (so jumping onto throne still demonstrates infinite bounce too!)
		if body.velocity.y > -5.5:
			_seated_player = body
			body.enter_throne_hug_ragdoll(self)
			AudioManager.play_3d("pvc_squeak_1", global_position + Vector3(0.0, 1.6, 0.2), 1.5, 0.96)
			player_seated_changed.emit(true)


func release_seated_player() -> void:
	if _seated_player != null:
		_seated_player = null
		_reentry_cooldown = 2.8
		player_seated_changed.emit(false)


func get_seat_anchor_global() -> Vector3:
	return to_global(Vector3(0.0, 1.62, 0.18))


func _physics_process(delta: float) -> void:
	if _reentry_cooldown > 0.0:
		_reentry_cooldown -= delta

	_squeeze_phase += delta
	var squeezing: bool = is_instance_valid(_seated_player)
	for i in range(3):
		var target_wrap: float = (1.18 + 0.34 * sin(_squeeze_phase * 3.4 + float(i) * 0.65)) if squeezing else (0.14 + 0.06 * sin(_squeeze_phase * 1.1 + float(i)))
		_right_wings[i].rotation.y = lerpf(_right_wings[i].rotation.y, target_wrap, clampf(delta * 5.0, 0.0, 1.0))
		_left_wings[i].rotation.y = lerpf(_left_wings[i].rotation.y, -target_wrap, clampf(delta * 5.0, 0.0, 1.0))

	if squeezing:
		if fmod(_squeeze_phase, 1.45) < delta:
			AudioManager.play_3d("pvc_squeak_2", get_seat_anchor_global(), -2.0, randf_range(0.92, 1.14))
		if _seated_player.has_method("apply_throne_squeeze_force"):
			_seated_player.apply_throne_squeeze_force(get_seat_anchor_global(), sin(_squeeze_phase * 3.4))
