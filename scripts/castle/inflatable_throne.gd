extends Node3D
class_name InflatableThrone

## 2.5 x 2.5 x 5.0m inflatable throne in the North wall behind the Dark God.
## Possesses passive effect "Очень прыгучий" AND 3 pairs (6 wings) of 7m span
## dark inflatable angel wings that fold & squeeze Yumik in Ragdoll when he sits!

var wing_pivots_left: Array[Node3D] = []
var wing_pivots_right: Array[Node3D] = []
var seat_area: Area3D
var seated_player: Node3D = null
var squeeze_phase: float = 0.0
var squeak_cooldown: float = 0.0


func _ready() -> void:
	var velvet_mat: Material = load("res://assets/materials/mat_throne_velvet_pvc.tres")
	var wing_mat: Material = load("res://assets/materials/mat_pvc_angel_wing.tres")

	var throne_body := AnimatableBody3D.new()
	throne_body.name = "ThroneBouncyBody"
	throne_body.sync_to_physics = false
	throne_body.collision_layer = 8 # Layer 4: DarkGodAndProps
	throne_body.collision_mask = 0
	throne_body.add_to_group("pvc_surface")
	throne_body.add_to_group("very_bouncy") # Passive effect "Очень прыгучий"!

	var seat_cs := CollisionShape3D.new()
	var seat_bx := BoxShape3D.new()
	seat_bx.size = Vector3(2.5, 1.3, 2.5)
	seat_cs.shape = seat_bx
	seat_cs.position = Vector3(0.0, 0.65, 0.0)
	throne_body.add_child(seat_cs)

	var back_cs := CollisionShape3D.new()
	var back_bx := BoxShape3D.new()
	back_bx.size = Vector3(2.5, 5.0, 0.85)
	back_cs.shape = back_bx
	back_cs.position = Vector3(0.0, 2.5, -0.85)
	throne_body.add_child(back_cs)
	add_child(throne_body)

	if ResourceLoader.exists("res://assets/models/inflatable_throne_5m.glb"):
		var packed: PackedScene = load("res://assets/models/inflatable_throne_5m.glb")
		if packed:
			var inst: Node = packed.instantiate()
			var idx: int = 0
			for ch in inst.get_children():
				if ch is MeshInstance3D:
					(ch as MeshInstance3D).material_override = velvet_mat if idx == 0 else wing_mat
					idx += 1
			add_child(inst)

	# Build 3 articulated pairs (6 wings, 7m total span -> 3.5m each side) for active squeezing!
	for pair_idx in range(3):
		var y_h: float = 1.65 + float(pair_idx) * 1.15
		for side in [-1, 1]:
			var pivot := Node3D.new()
			pivot.name = "SqueezeWing_%d_%s" % [pair_idx, "L" if side < 0 else "R"]
			pivot.position = Vector3(float(side) * 0.85, y_h, -0.45)
			var w_mi := MeshInstance3D.new()
			var w_prism := BoxMesh.new()
			w_prism.size = Vector3(3.5, 0.68, 0.24)
			w_mi.mesh = w_prism
			w_mi.position = Vector3(float(side) * 1.75, 0.15, 0.25)
			w_mi.material_override = wing_mat
			pivot.add_child(w_mi)
			add_child(pivot)
			if side < 0:
				wing_pivots_left.append(pivot)
			else:
				wing_pivots_right.append(pivot)

	seat_area = Area3D.new()
	seat_area.name = "ThroneSeatSensor"
	seat_area.collision_layer = 64
	seat_area.collision_mask = 2
	var s_col := CollisionShape3D.new()
	var s_box := BoxShape3D.new()
	s_box.size = Vector3(2.0, 1.6, 1.9)
	s_col.shape = s_box
	s_col.position = Vector3(0.0, 1.85, 0.15)
	seat_area.add_child(s_col)
	seat_area.body_entered.connect(_on_seat_entered)
	seat_area.body_exited.connect(_on_seat_exited)
	add_child(seat_area)


func _on_seat_entered(body: Node3D) -> void:
	if body.is_in_group("player") and body.has_method("enter_throne_squeeze"):
		# Only seat player if moving slowly enough (not mid super-bounce)
		var vel_len: float = (body as CharacterBody3D).velocity.length() if body is CharacterBody3D else 0.0
		if vel_len < 6.5:
			seated_player = body
			body.call("enter_throne_squeeze", self, global_transform * Vector3(0.0, 1.55, 0.20))
			AudioManager.play_pvc_squeak(global_position)


func _on_seat_exited(body: Node3D) -> void:
	if body == seated_player:
		seated_player = null


func release_seated_player() -> void:
	seated_player = null


func _physics_process(delta: float) -> void:
	squeeze_phase += delta * (4.2 if is_instance_valid(seated_player) else 1.2)
	squeak_cooldown = maxf(0.0, squeak_cooldown - delta)

	for i in range(wing_pivots_left.size()):
		var phase_off: float = float(i) * 0.55
		if is_instance_valid(seated_player):
			# Wrap wings inward (+65..+105 deg) to squeeze & cuddle Yumik!
			var wrap_ang: float = deg_to_rad(78.0 + 24.0 * sin(squeeze_phase + phase_off))
			wing_pivots_left[i].rotation.y = lerpf(wing_pivots_left[i].rotation.y, wrap_ang, delta * 8.0)
			wing_pivots_right[i].rotation.y = lerpf(wing_pivots_right[i].rotation.y, -wrap_ang, delta * 8.0)
		else:
			var idle_ang: float = deg_to_rad(12.0 + 8.0 * sin(squeeze_phase + phase_off))
			wing_pivots_left[i].rotation.y = lerpf(wing_pivots_left[i].rotation.y, idle_ang, delta * 4.0)
			wing_pivots_right[i].rotation.y = lerpf(wing_pivots_right[i].rotation.y, -idle_ang, delta * 4.0)

	if is_instance_valid(seated_player):
		var target_seat_pos: Vector3 = global_transform * Vector3(0.0, 1.55 + 0.12 * sin(squeeze_phase * 2.0), 0.22)
		if seated_player.has_method("maintain_throne_ragdoll_cradle"):
			seated_player.call("maintain_throne_ragdoll_cradle", target_seat_pos)
		if squeak_cooldown <= 0.0:
			squeak_cooldown = 1.15
			AudioManager.play_pvc_squeak(target_seat_pos)
			AudioManager.play_3d("wing_inner", global_position, -3.0, 0.1)
