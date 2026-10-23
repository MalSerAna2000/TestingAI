@tool
extends AeroBody3D
class_name NZTBNZCastle

## Надувной Замок Темного Бога Надувных Замков (НЗТБНЗ)
## 33x33x33m 0.35mm PVC inflatable castle extending AeroBody3D (VehicleBody3D -> RigidBody3D).
## Equipped with:
## - 2m thick air-chamber floor, walls & ceiling
## - 3x7m auto-closing/locking South Gate (forced open during Venturi Suction)
## - Three 33m semi-span inflatable angel wings (West, North, East) with AeroInfluencer3D / ManualAeroSurface3D
##   and passive effect "Очень прыгучий"
## - Four 5x50m corner inflatable towers + four 75m physical hemp climbing ropes
## - Interior 3x3x3m Wardrobe, 2.5x2.5x5m Throne (with 6x7m wings), and 3m Dark God Avatar!

const AeroSurfaceConfigScript = preload("res://addons/godot_aerodynamic_physics/core/aero_influencer_3d/aero_surface_3d/aero_surface_config.gd")
const ManualAeroSurfaceScript = preload("res://addons/godot_aerodynamic_physics/core/aero_influencer_3d/aero_surface_3d/manual_aero_surface_3d/manual_aero_surface_3d.gd")
const ManualAeroConfigScript = preload("res://addons/godot_aerodynamic_physics/core/aero_influencer_3d/aero_surface_3d/manual_aero_surface_3d/manual_aero_surface_config.gd")
const AeroDragScript = preload("res://addons/godot_aerodynamic_physics/core/aero_influencer_3d/drag_influencer/aero_drag_influencer.gd")

var gate_door_body: AnimatableBody3D
var gate_door_visual: Node3D
var gate_locked_closed: bool = false
var gate_open_ratio: float = 1.0 # 1.0 = open, 0.0 = sealed

var interior_area: Area3D
var venturi_suction_area: Area3D
var suction_audio: AudioStreamPlayer3D

var wing_visual_west: Node3D
var wing_visual_north: Node3D
var wing_visual_east: Node3D
var aero_wing_west: Node3D
var aero_wing_north: Node3D
var aero_wing_east: Node3D

var dark_god: DarkGodAvatar
var throne: InflatableThrone
var wardrobe: InflatableWardrobe
var ropes_container: Node3D

var flap_time: float = 0.0
var flap_sfx_cd: float = 0.0
var prev_linear_vel := Vector3.ZERO
var current_hull_accel := Vector3.ZERO


func _enter_tree() -> void:
	super()


func _ready() -> void:
	super()
	if Engine.is_editor_hint():
		return

	add_to_group("inflatable_castle")
	add_to_group("pvc_surface")
	add_to_group("pvc_slippery")

	collision_layer = 4 | 16384 # Layer 3 (InflatableCastle) + Layer 15 (Atmosphere Areas)
	collision_mask = 1 | 2 | 4 | 8 | 32
	mass = 4200.0
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0.0, 9.5, 0.0)
	can_sleep = false

	var pvc_phys := PhysicsMaterial.new()
	pvc_phys.bounce = 0.88
	pvc_phys.friction = 0.20 # Slippery 0.35mm PVC!
	physics_material_override = pvc_phys

	_build_castle_geometry_and_colliders()
	_build_aerodynamic_influencers()
	_build_interior_entities()
	_build_suction_and_interior_triggers()
	_spawn_75m_tower_ropes.call_deferred()

	GameState.castle_ref = self
	GameState.castle_state_changed.connect(_on_castle_state_changed)
	_on_castle_state_changed(GameState.current_castle_state)


func _build_castle_geometry_and_colliders() -> void:
	var mat_castle: Material = load("res://assets/materials/mat_pvc_crimson_castle.tres")
	var mat_lace: Material = load("res://assets/materials/mat_pvc_white_lace.tres")
	var mat_wing: Material = load("res://assets/materials/mat_pvc_angel_wing.tres")

	# Compound RigidBody3D primitives matching exact 33x33x33m (2m chambers) & 3x7m Gate:
	var boxes := [
		["ColFloor", Vector3(0.0, 1.0, 0.0), Vector3(33.0, 2.0, 33.0)],
		["ColCeiling", Vector3(0.0, 32.0, 0.0), Vector3(33.0, 2.0, 33.0)],
		["ColWallWest", Vector3(-15.5, 16.5, 0.0), Vector3(2.0, 29.0, 33.0)],
		["ColWallEast", Vector3(15.5, 16.5, 0.0), Vector3(2.0, 29.0, 33.0)],
		["ColWallNorth", Vector3(0.0, 16.5, -15.5), Vector3(29.0, 29.0, 2.0)],
		# South wall leaving exact 3m wide (X:-1.5..+1.5) x 7m tall (Y:2.0..9.0) Gate!
		["ColWallSouthL", Vector3(-9.0, 16.5, 15.5), Vector3(15.0, 29.0, 2.0)],
		["ColWallSouthR", Vector3(9.0, 16.5, 15.5), Vector3(15.0, 29.0, 2.0)],
		["ColWallSouthTop", Vector3(0.0, 20.0, 15.5), Vector3(3.0, 22.0, 2.0)],
		# Soft inflatable entry ramp outside South gate (Y: 0..2m) so Yumik can walk/jump in
		["ColEntryRamp", Vector3(0.0, 0.85, 17.8), Vector3(5.0, 1.7, 3.2)],
		# 4 Corner inflatable towers (width 5m, height 50m!)
		["ColTowerNW", Vector3(-15.5, 25.0, -15.5), Vector3(5.0, 50.0, 5.0)],
		["ColTowerNE", Vector3(15.5, 25.0, -15.5), Vector3(5.0, 50.0, 5.0)],
		["ColTowerSW", Vector3(-15.5, 25.0, 15.5), Vector3(5.0, 50.0, 5.0)],
		["ColTowerSE", Vector3(15.5, 25.0, 15.5), Vector3(5.0, 50.0, 5.0)],
	]
	for b in boxes:
		var cs := CollisionShape3D.new()
		cs.name = b[0]
		var shape := BoxShape3D.new()
		shape.size = b[2]
		cs.shape = shape
		cs.position = b[1]
		add_child(cs)
	# Sloped entry ramp rotation
	var ramp_cs: CollisionShape3D = get_node("ColEntryRamp") as CollisionShape3D
	if ramp_cs:
		ramp_cs.rotation.x = deg_to_rad(24.0)

	# Hull visual mesh (33x33x33m)
	if ResourceLoader.exists("res://assets/models/castle_hull_33m.glb"):
		var hull_scene: PackedScene = load("res://assets/models/castle_hull_33m.glb")
		if hull_scene:
			var hull_inst: Node = hull_scene.instantiate()
			var idx: int = 0
			for ch in hull_inst.get_children():
				if ch is MeshInstance3D:
					(ch as MeshInstance3D).material_override = mat_castle if idx == 0 else mat_lace
					idx += 1
			add_child(hull_inst)

	# 4 Corner 50m Tower visual meshes
	var tower_corners := [
		Vector3(-15.5, 0.0, -15.5),
		Vector3(15.5, 0.0, -15.5),
		Vector3(-15.5, 0.0, 15.5),
		Vector3(15.5, 0.0, 15.5),
	]
	var tower_scene: PackedScene = load("res://assets/models/castle_tower_50m.glb") if ResourceLoader.exists("res://assets/models/castle_tower_50m.glb") else null
	for i in range(4):
		var t_root := Node3D.new()
		t_root.name = "TowerVisual_%d" % i
		t_root.position = tower_corners[i]
		if tower_scene:
			var ti: Node = tower_scene.instantiate()
			var k: int = 0
			for ch in ti.get_children():
				if ch is MeshInstance3D:
					(ch as MeshInstance3D).material_override = mat_castle if k == 0 else mat_wing
					k += 1
			t_root.add_child(ti)
		add_child(t_root)

	# Warm interior OmniLight3Ds so the 33m throne hall glows invitingly at night!
	for lp in [Vector3(0.0, 14.0, 0.0), Vector3(0.0, 7.5, -8.5), Vector3(-7.5, 6.5, 9.0)]:
		var omni := OmniLight3D.new()
		omni.position = lp
		omni.light_color = Color(1.0, 0.58, 0.72)
		omni.light_energy = 2.6
		omni.omni_range = 28.0
		add_child(omni)

	# 3x7m Auto-Locking Gate Door at South wall (X=0, Y=2..9m, Z=15.5)
	gate_door_body = AnimatableBody3D.new()
	gate_door_body.name = "GateDoor3x7m"
	gate_door_body.sync_to_physics = false
	gate_door_body.collision_layer = 4
	gate_door_body.collision_mask = 0
	gate_door_body.add_to_group("pvc_surface")
	var g_cs := CollisionShape3D.new()
	var g_bx := BoxShape3D.new()
	g_bx.size = Vector3(3.0, 7.0, 1.5)
	g_cs.shape = g_bx
	g_cs.position = Vector3(0.0, 3.5, 0.0)
	gate_door_body.add_child(g_cs)

	gate_door_visual = Node3D.new()
	if ResourceLoader.exists("res://assets/models/castle_gate_door_3x7m.glb"):
		var gd_scene: PackedScene = load("res://assets/models/castle_gate_door_3x7m.glb")
		if gd_scene:
			var gdi: Node = gd_scene.instantiate()
			for ch in gdi.get_children():
				if ch is MeshInstance3D:
					(ch as MeshInstance3D).material_override = mat_wing
			gate_door_visual.add_child(gdi)
	gate_door_body.add_child(gate_door_visual)
	gate_door_body.position = Vector3(0.0, 9.2, 15.5) # Raised open initially!
	add_child(gate_door_body)

	# Three 33m semi-span inflatable angel wings (West, North, East) — "Очень прыгучий"!
	wing_visual_west = _create_wall_wing_assembly("WestWing33m", Vector3(-16.5, 17.5, 0.0), deg_to_rad(180.0), mat_wing)
	wing_visual_east = _create_wall_wing_assembly("EastWing33m", Vector3(16.5, 17.5, 0.0), 0.0, mat_wing)
	wing_visual_north = _create_wall_wing_assembly("NorthWing33m", Vector3(0.0, 18.5, -16.5), deg_to_rad(90.0), mat_wing)


func _create_wall_wing_assembly(w_name: String, mount_pos: Vector3, yaw_rad: float, mat_wing: Material) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = w_name
	pivot.position = mount_pos
	pivot.rotation.y = yaw_rad

	if ResourceLoader.exists("res://assets/models/castle_angel_wing_33m.glb"):
		var w_scene: PackedScene = load("res://assets/models/castle_angel_wing_33m.glb")
		if w_scene:
			var wi: Node = w_scene.instantiate()
			for ch in wi.get_children():
				if ch is MeshInstance3D:
					(ch as MeshInstance3D).material_override = mat_wing
			pivot.add_child(wi)

	# Dedicated "very_bouncy" + "pvc_slippery" wing collider extending 33m along +X of pivot!
	var w_body := AnimatableBody3D.new()
	w_body.name = w_name + "_BouncyCollider"
	w_body.sync_to_physics = false
	w_body.collision_layer = 8 # Layer 4 so Yumik bounces infinitely & climbs on wings!
	w_body.collision_mask = 0
	w_body.add_to_group("pvc_surface")
	w_body.add_to_group("pvc_slippery")
	w_body.add_to_group("very_bouncy") # Passive effect "Очень прыгучий"!
	var w_cs := CollisionShape3D.new()
	var w_bx := BoxShape3D.new()
	w_bx.size = Vector3(33.0, 2.2, 12.0)
	w_cs.shape = w_bx
	w_cs.position = Vector3(16.5, -1.5, -1.2)
	w_body.add_child(w_cs)
	pivot.add_child(w_body)

	add_child(pivot)
	return pivot


func _build_aerodynamic_influencers() -> void:
	# Real Godot Aerodynamic Physics (AeroInfluencer3D -> ManualAeroSurface3D + AeroDragInfluencer3D)!
	aero_wing_west = _make_aero_wing_surface("AeroWingWest", Vector3(-32.0, 18.0, 0.0), 33.0, 14.0)
	aero_wing_east = _make_aero_wing_surface("AeroWingEast", Vector3(32.0, 18.0, 0.0), 33.0, 14.0)
	aero_wing_north = _make_aero_wing_surface("AeroWingNorth", Vector3(0.0, 19.0, -32.0), 33.0, 14.0)
	# Broad flat 33x33m inflatable hull roof/bottom lifting surface
	_make_aero_wing_surface("AeroHullPlanform", Vector3(0.0, 16.5, 0.0), 33.0, 33.0)

	# Volumetric form-drag influencers on the huge 33m walls & 50m towers so crosswinds push & tumble it!
	var drag_points := [
		["AeroDragCenter", Vector3(0.0, 18.0, 0.0), 15.5],
		["AeroDragTopTowers", Vector3(0.0, 42.0, 0.0), 11.0],
		["AeroDragNorth", Vector3(0.0, 18.0, -15.0), 10.5],
		["AeroDragSouth", Vector3(0.0, 18.0, 15.0), 10.5],
	]
	for dp in drag_points:
		var d_node: Node3D = AeroDragScript.new()
		d_node.name = dp[0]
		d_node.position = dp[1]
		d_node.set("radius", dp[2])
		d_node.set("drag_coefficient", 0.85)
		add_child(d_node)


func _make_aero_wing_surface(s_name: String, pos: Vector3, span_m: float, chord_m: float) -> Node3D:
	var surf: Node3D = ManualAeroSurfaceScript.new()
	surf.name = s_name
	surf.position = pos

	var w_cfg: Resource = AeroSurfaceConfigScript.new(chord_m, span_m)
	surf.set("wing_config", w_cfg)

	var m_cfg: Resource = ManualAeroConfigScript.new()
	m_cfg.set("min_lift_coefficient", -1.8)
	m_cfg.set("max_lift_coefficient", 2.1)
	m_cfg.set("min_drag_coefficient", 0.06)
	m_cfg.set("max_drag_coefficient", 1.15)
	surf.set("manual_config", m_cfg)

	add_child(surf)
	return surf


func _build_interior_entities() -> void:
	# 1. Inflatable Wardrobe (3x3x3m) to the left of the gate!
	wardrobe = InflatableWardrobe.new()
	wardrobe.name = "InflatableWardrobe"
	wardrobe.position = Vector3(-9.5, 2.0, 11.5)
	wardrobe.rotation.y = deg_to_rad(90.0)
	add_child(wardrobe)

	# 2. Inflatable Throne (2.5x2.5x5m) in the North wall behind the Dark God!
	throne = InflatableThrone.new()
	throne.name = "InflatableThrone"
	throne.position = Vector3(0.0, 2.0, -13.1)
	add_child(throne)

	# 3. Dark God of Inflatable Castles (3m tall legless anime femboy merged into floor!)
	dark_god = DarkGodAvatar.new()
	dark_god.name = "DarkGodAvatar"
	dark_god.position = Vector3(0.0, 2.0, -7.2)
	add_child(dark_god)


func _build_suction_and_interior_triggers() -> void:
	# Interior detector: closes & locks gates when Yumik steps inside!
	interior_area = Area3D.new()
	interior_area.name = "InteriorLockSensor"
	interior_area.collision_layer = 64
	interior_area.collision_mask = 2
	var in_cs := CollisionShape3D.new()
	var in_bx := BoxShape3D.new()
	in_bx.size = Vector3(27.5, 27.0, 26.5)
	in_cs.shape = in_bx
	in_cs.position = Vector3(0.0, 15.5, -1.0)
	interior_area.add_child(in_cs)
	interior_area.body_entered.connect(_on_interior_body_entered)
	add_child(interior_area)

	# Venturi Suction Cone outside South gate (65m range)
	venturi_suction_area = Area3D.new()
	venturi_suction_area.name = "VenturiSuctionZone"
	venturi_suction_area.collision_layer = 64
	venturi_suction_area.collision_mask = 2 | 16 | 32
	var vs_cs := CollisionShape3D.new()
	var vs_bx := BoxShape3D.new()
	vs_bx.size = Vector3(34.0, 24.0, 72.0)
	vs_cs.shape = vs_bx
	vs_cs.position = Vector3(0.0, 10.0, 42.0)
	venturi_suction_area.add_child(vs_cs)
	add_child(venturi_suction_area)

	suction_audio = AudioStreamPlayer3D.new()
	suction_audio.bus = &"SFX"
	suction_audio.max_distance = 180.0
	suction_audio.unit_size = 18.0
	suction_audio.position = Vector3(0.0, 5.5, 16.0)
	if AudioManager.streams.has("suction_loop"):
		suction_audio.stream = AudioManager.streams["suction_loop"]
	add_child(suction_audio)


func _spawn_75m_tower_ropes() -> void:
	if not is_inside_tree():
		return
	ropes_container = Node3D.new()
	ropes_container.name = "CastleHempRopes75m"
	get_parent().add_child(ropes_container)

	var peaks := [
		[Vector3(-15.5, 50.0, -15.5), Vector3(-0.707, 0.0, -0.707)],
		[Vector3(15.5, 50.0, -15.5), Vector3(0.707, 0.0, -0.707)],
		[Vector3(-15.5, 50.0, 15.5), Vector3(-0.707, 0.0, 0.707)],
		[Vector3(15.5, 50.0, 15.5), Vector3(0.707, 0.0, 0.707)],
	]
	for i in range(4):
		var rope := HempRope75m.new()
		ropes_container.add_child(rope)
		rope.build_rope(self, peaks[i][0], peaks[i][1], i)


func _on_interior_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		if GameState.current_castle_state != GameState.CastleState.SUCTION and not gate_locked_closed:
			gate_locked_closed = true
			AudioManager.play_3d("gate_lock", to_global(Vector3(0.0, 4.0, 15.5)), 2.5, 0.04)


func _on_castle_state_changed(new_state: int) -> void:
	if new_state == GameState.CastleState.SUCTION:
		# Gates automatically unlock & open wide during Venturi Suction!
		gate_locked_closed = false
		if suction_audio and suction_audio.stream and not suction_audio.playing:
			suction_audio.play()
	else:
		if suction_audio and suction_audio.playing:
			suction_audio.stop()
		# Re-lock gate if Yumik is already inside
		if interior_area:
			for b in interior_area.get_overlapping_bodies():
				if b.is_in_group("player"):
					gate_locked_closed = true


func _physics_process(delta: float) -> void:
	super(delta)
	if Engine.is_editor_hint():
		return

	current_hull_accel = (linear_velocity - prev_linear_vel) / maxf(delta, 0.001)
	prev_linear_vel = linear_velocity

	# Animate 3x7m Gate opening / sealing
	var target_open: float = 0.0 if gate_locked_closed else 1.0
	if GameState.current_castle_state == GameState.CastleState.SUCTION:
		target_open = 1.0
	gate_open_ratio = move_toward(gate_open_ratio, target_open, delta * 2.2)
	if gate_door_body:
		gate_door_body.position = Vector3(0.0, lerpf(2.0, 9.2, gate_open_ratio), 15.5)

	var st: int = GameState.current_castle_state
	if st == GameState.CastleState.SUCTION:
		_process_suction_venturi(delta)
	elif st == GameState.CastleState.FLYING:
		_process_flying_wings(delta)
	else:
		# Reset outer wing dihedral gently
		if wing_visual_west:
			wing_visual_west.rotation.z = lerpf(wing_visual_west.rotation.z, 0.0, delta * 3.0)
			wing_visual_east.rotation.z = lerpf(wing_visual_east.rotation.z, 0.0, delta * 3.0)
			wing_visual_north.rotation.x = lerpf(wing_visual_north.rotation.x, 0.0, delta * 3.0)


func _process_suction_venturi(delta: float) -> void:
	# Pull Yumik & nearby physics props inward toward the gate & throne room!
	var gate_intake_target: Vector3 = to_global(Vector3(0.0, 3.8, -5.0))
	if venturi_suction_area:
		for body in venturi_suction_area.get_overlapping_bodies():
			var to_intake: Vector3 = gate_intake_target - body.global_position
			var dist: float = maxf(to_intake.length(), 1.5)
			var dir: Vector3 = to_intake.normalized()
			var pull_accel: float = clampf(48.0 * (1.0 - dist / 80.0) + 14.0, 12.0, 54.0)
			if body.is_in_group("player") and body.has_method("apply_external_wind_impulse"):
				body.call("apply_external_wind_impulse", dir * pull_accel * delta)
			elif body is RigidBody3D and body != self:
				(body as RigidBody3D).apply_central_force(dir * pull_accel * (body as RigidBody3D).mass * 0.6)


func _process_flying_wings(delta: float) -> void:
	flap_time += delta * 4.2
	flap_sfx_cd = maxf(0.0, flap_sfx_cd - delta)
	var stroke: float = sin(flap_time)
	if wing_visual_west:
		wing_visual_west.rotation.z = deg_to_rad(-28.0 * stroke)
		wing_visual_east.rotation.z = deg_to_rad(28.0 * stroke)
		wing_visual_north.rotation.x = deg_to_rad(26.0 * stroke)
	if aero_wing_west:
		aero_wing_west.rotation.z = deg_to_rad(-16.0 * stroke)
		aero_wing_east.rotation.z = deg_to_rad(16.0 * stroke)
		aero_wing_north.rotation.x = deg_to_rad(15.0 * stroke)

	if flap_sfx_cd <= 0.0 and stroke > 0.85:
		flap_sfx_cd = 1.15
		AudioManager.play_3d("wing_huge", global_position + Vector3(0, 18.0, 0), 4.0, 0.07)


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	super(state)
	if Engine.is_editor_hint():
		return

	var st: int = GameState.current_castle_state
	if st == GameState.CastleState.SUCTION:
		# Venturi reaction jet: gate faces +Z, air sucked inward (-Z), castle rockets in opposite direction!
		# Actually intake pulls from +Z toward -Z, or pushes castle forcefully across terrain so it can ram, flip & launch!
		var jet_dir: Vector3 = -global_transform.basis.z
		var suction_thrust: Vector3 = (jet_dir * 82000.0) + Vector3.UP * (16000.0 * sin(Time.get_ticks_msec() * 0.004))
		state.apply_central_force(suction_thrust)
		state.apply_torque(global_transform.basis.x * 48000.0 * sin(Time.get_ticks_msec() * 0.0025))
	elif st == GameState.CastleState.FLYING:
		# Wing flapping lift + wild turbulent pitch/roll/yaw tossing & occasional inversions!
		var t_sec: float = float(Time.get_ticks_msec()) * 0.001
		var target_alt_boost: float = clampf((85.0 - global_position.y) * 950.0, -18000.0, 68000.0)
		var downstroke: float = maxf(0.0, sin(flap_time)) * 46000.0
		var forward_flight: Vector3 = -global_transform.basis.z * 34000.0
		var lift_vec: Vector3 = Vector3.UP * (mass * 9.8 + target_alt_boost * 0.45 + downstroke * 0.5)
		state.apply_central_force(lift_vec + forward_flight)

		# Wild swaying, shaking, circling, and rolling/flipping in mid-air!
		var roll_t: float = sin(t_sec * 1.15) * 145000.0 + cos(t_sec * 2.7) * 65000.0
		var pitch_t: float = cos(t_sec * 0.92) * 125000.0
		var yaw_t: float = sin(t_sec * 0.65) * 110000.0
		state.apply_torque(Vector3(pitch_t, yaw_t, roll_t))

	# Gentle angular damping cap so extreme hurricane/flight spins stay physically stable in Jolt
	if state.angular_velocity.length() > 2.6:
		state.angular_velocity = state.angular_velocity.normalized() * 2.6
