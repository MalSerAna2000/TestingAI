@tool
class_name InflatableCastle
extends AeroBody3D
## Central Physical & Aerodynamic Entity: НЗТБНЗ ("Надувной Замок Темного Бога").
## Exact Specification Geometry & Physics:
## - 33m x 33m x 33m hollow PVC 0.35mm body with 2.0m thick inflatable floor, ceiling, and walls
## - 3.0m wide x 7.0m tall double front gates (+Z wall): auto-close & lock when Yumik enters (except in "Всасывание")
## - 3 giant dark inflatable angel wings on West (-X), North (-Z), East (+X) walls: 33.0m half-span each,
##   powered by ManualAeroSurface3D + CastleWingInfluencer3D, tagged "Очень прыгучий" (infinite bounce, ultra-slick)
## - 4 corner inflatable towers (5.0m width x 50.0m height) with 4 physical 75.0m hemp climbing ropes
## - Interior: 3x3x3m Wardrobe (left of gates), 3.0m Dark God Avatar, 2.5x2.5x5.0m Throne ("Очень прыгучий", 6 wings)
## - Automatic state transitions every 60 game minutes / 3 real minutes (180.0s):
##   0 = "Обычное", 1 = "Всасывание" (Venturi suction + jet recoil + Nyashing), 2 = "Летающее" (flapping flight & rolls)

signal castle_state_changed(new_state: int, state_name: String)
signal gates_lock_changed(is_locked: bool)

const STATE_DURATION_REAL_SEC: float = 180.0 # 60 game minutes = 3 real minutes

var current_state: int = GameState.CastleState.NORMAL
var state_timer: float = STATE_DURATION_REAL_SEC
var gates_closed_and_locked: bool = false

var atmosphere_node: WorldAeroAtmosphere3D
var dark_god: DarkGodController
var throne: ThroneController
var wardrobe: WardrobeController
var ropes: Array[HempRope75m] = []
var player_ref: Node3D

var _gate_left_mesh: MeshInstance3D
var _gate_right_mesh: MeshInstance3D
var _gate_blocker_shape: CollisionShape3D
var _outer_wing_pivots: Array[Node3D] = []
var _wing_aero_surfaces: Array[ManualAeroSurface3D] = []
var _wing_flap_influencer: CastleWingInfluencer3D
var _venturi_thruster: AeroThruster3D
var _interior_area: Area3D
var _player_inside: bool = false
var _built_runtime: bool = false
var _flap_anim_t: float = 0.0
var _flap_sfx_cooldown: float = 0.6


func _enter_tree() -> void:
	super._enter_tree()


func _ready() -> void:
	super._ready()
	if Engine.is_editor_hint():
		return
	if has_node("EditorPreviewRoot"):
		$EditorPreviewRoot.queue_free()
	if not _built_runtime:
		_built_runtime = true
		_configure_rigid_body_properties()
		_build_castle_structure()
		_build_aerodynamic_influencers()
		_build_interior_entities()
		GameState.castle_state_requested.connect(set_castle_state)


func _configure_rigid_body_properties() -> void:
	# 0.35mm double-walled PVC 33m structure + trapped air effective inertia under Jolt Physics
	mass = 4800.0
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0.0, 11.5, 0.0)
	inertia = Vector3(680000.0, 740000.0, 680000.0)
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = 0.0
	angular_damp = 0.0
	can_sleep = false
	continuous_cd = true

	collision_layer = 4 # Layer 3: Castle (+ Layer 15 set by AeroBody3D._enter_tree!)
	set_collision_layer_value(15, true)
	collision_mask = 1 # Collides cleanly with Terrain & WorldBorders

	var pvc_phys := PhysicsMaterial.new()
	pvc_phys.friction = 0.28
	pvc_phys.bounce = 0.86
	physics_material_override = pvc_phys

	set_meta("surface_kind", "pvc")
	set_meta("climbable", true)
	set_meta("grip_factor", 0.38)
	set_meta("very_bouncy", false)
	add_to_group("inflatable_castle")


func _add_chamber_part(
	part_name: String,
	center_pos: Vector3,
	box_size: Vector3,
	mesh_res: Mesh,
	mat_res: Material,
	shape_meta_kind: String = "pvc",
	is_very_bouncy: bool = false
) -> CollisionShape3D:
	var mi := MeshInstance3D.new()
	mi.name = part_name + "Mesh"
	mi.mesh = mesh_res
	mi.position = center_pos
	mi.scale = box_size
	mi.material_override = mat_res
	add_child(mi)

	var bshape := BoxShape3D.new()
	bshape.size = box_size
	var cshape := CollisionShape3D.new()
	cshape.name = part_name + "Col"
	cshape.shape = bshape
	cshape.position = center_pos
	cshape.set_meta("surface_kind", shape_meta_kind)
	cshape.set_meta("very_bouncy", is_very_bouncy)
	add_child(cshape)
	return cshape


func _build_castle_structure() -> void:
	var pvc_mat: Material = load("res://assets/materials/mat_castle_pvc.tres")
	var wing_mat: Material = load("res://assets/materials/mat_castle_wing.tres")
	var wall_mesh: Mesh = load("res://assets/models/castle_quilted_wall.obj")
	var floor_mesh: Mesh = load("res://assets/models/castle_quilted_floor.obj")
	var tower_mesh: Mesh = load("res://assets/models/castle_corner_tower_50m.obj")
	var wing_mesh: Mesh = load("res://assets/models/castle_angel_wing_33m.obj")
	var gate_mesh: Mesh = load("res://assets/models/castle_gate_leaf.obj")

	# 1. Floor (33 x 2 x 33m, y = 0..2m) & Ceiling (33 x 2 x 33m, y = 31..33m)
	_add_chamber_part("FloorChamber", Vector3(0.0, 1.0, 0.0), Vector3(33.0, 2.0, 33.0), floor_mesh, pvc_mat)
	_add_chamber_part("RoofChamber", Vector3(0.0, 32.0, 0.0), Vector3(33.0, 2.0, 33.0), floor_mesh, pvc_mat)

	# 2. North (-Z), West (-X), East (+X) Solid 2m-Thick Walls (height 33m -> y = 2..31m inner span)
	_add_chamber_part("WallNorth", Vector3(0.0, 16.5, -15.5), Vector3(33.0, 29.0, 2.0), wall_mesh, pvc_mat)
	_add_chamber_part("WallWest", Vector3(-15.5, 16.5, 0.0), Vector3(2.0, 29.0, 29.0), wall_mesh, pvc_mat)
	_add_chamber_part("WallEast", Vector3(15.5, 16.5, 0.0), Vector3(2.0, 29.0, 29.0), wall_mesh, pvc_mat)

	# 3. South Front Wall (+Z = +15.5) with centered 3.0m wide x 7.0m tall Gate Portal (x in [-1.5..+1.5], y in [2.0..9.0])!
	_add_chamber_part("WallSouthLeft", Vector3(-9.0, 16.5, 15.5), Vector3(15.0, 29.0, 2.0), wall_mesh, pvc_mat)
	_add_chamber_part("WallSouthRight", Vector3(9.0, 16.5, 15.5), Vector3(15.0, 29.0, 2.0), wall_mesh, pvc_mat)
	_add_chamber_part("WallSouthHeader", Vector3(0.0, 20.0, 15.5), Vector3(3.0, 22.0, 2.0), wall_mesh, pvc_mat)

	# Double Gate Leaves (width 1.5m each = 3.0m total, height 7.0m, y = 2.0..9.0m) + Lockable Blocker Shape!
	_gate_left_mesh = MeshInstance3D.new()
	_gate_left_mesh.name = "GateDoorLeftMesh"
	_gate_left_mesh.mesh = gate_mesh
	_gate_left_mesh.scale = Vector3(1.5, 7.0, 1.5)
	_gate_left_mesh.position = Vector3(-2.35, 5.5, 15.5)
	_gate_left_mesh.material_override = wing_mat
	add_child(_gate_left_mesh)

	_gate_right_mesh = MeshInstance3D.new()
	_gate_right_mesh.name = "GateDoorRightMesh"
	_gate_right_mesh.mesh = gate_mesh
	_gate_right_mesh.scale = Vector3(1.5, 7.0, 1.5)
	_gate_right_mesh.position = Vector3(2.35, 5.5, 15.5)
	_gate_right_mesh.material_override = wing_mat
	add_child(_gate_right_mesh)

	var gate_box := BoxShape3D.new()
	gate_box.size = Vector3(3.2, 7.2, 1.8)
	_gate_blocker_shape = CollisionShape3D.new()
	_gate_blocker_shape.name = "GateLockCollider"
	_gate_blocker_shape.shape = gate_box
	_gate_blocker_shape.position = Vector3(0.0, 5.5, 15.5)
	_gate_blocker_shape.disabled = true
	_gate_blocker_shape.set_meta("surface_kind", "pvc")
	add_child(_gate_blocker_shape)

	# 4. Four Corner Inflatable Towers (width = 5.0m, height = 50.0m)!
	var corners := [
		Vector3(-15.5, 0.0, -15.5),
		Vector3(15.5, 0.0, -15.5),
		Vector3(-15.5, 0.0, 15.5),
		Vector3(15.5, 0.0, 15.5),
	]
	for idx in range(corners.size()):
		var cpos: Vector3 = corners[idx]
		var tmi := MeshInstance3D.new()
		tmi.name = "CornerTowerMesh_%d" % idx
		tmi.mesh = tower_mesh
		tmi.position = cpos
		tmi.material_override = pvc_mat
		add_child(tmi)

		var tshape := CylinderShape3D.new()
		tshape.radius = 2.5
		tshape.height = 50.0
		var tcol := CollisionShape3D.new()
		tcol.name = "CornerTowerCol_%d" % idx
		tcol.shape = tshape
		tcol.position = cpos + Vector3(0.0, 25.0, 0.0)
		tcol.set_meta("surface_kind", "pvc")
		tcol.set_meta("very_bouncy", false)
		add_child(tcol)

	# 5. Three Outer Giant Dark Inflatable Angel Wings (West -X, North -Z, East +X — half-span 33.0m each!)
	# Passive effect: "Очень прыгучий" + softest, slickest surface of the entire castle!
	var wing_mounts := [
		{"name": "OuterWingEast", "pos": Vector3(16.2, 19.5, 0.0), "rot_y": 0.0, "col_offset": Vector3(32.5, 19.5, 0.0), "col_size": Vector3(33.0, 2.2, 13.5)},
		{"name": "OuterWingWest", "pos": Vector3(-16.2, 19.5, 0.0), "rot_y": PI, "col_offset": Vector3(-32.5, 19.5, 0.0), "col_size": Vector3(33.0, 2.2, 13.5)},
		{"name": "OuterWingNorth", "pos": Vector3(0.0, 20.5, -16.2), "rot_y": PI * 0.5, "col_offset": Vector3(0.0, 20.5, -32.5), "col_size": Vector3(13.5, 2.2, 33.0)},
	]
	for wm in wing_mounts:
		var pivot := Node3D.new()
		pivot.name = wm["name"]
		pivot.position = wm["pos"]
		pivot.rotation.y = wm["rot_y"]
		var wmi := MeshInstance3D.new()
		wmi.mesh = wing_mesh
		wmi.material_override = wing_mat
		pivot.add_child(wmi)
		add_child(pivot)
		_outer_wing_pivots.append(pivot)

		var wbox := BoxShape3D.new()
		wbox.size = wm["col_size"]
		var wcol := CollisionShape3D.new()
		wcol.name = wm["name"] + "BouncyCol"
		wcol.shape = wbox
		wcol.position = wm["col_offset"]
		wcol.set_meta("surface_kind", "pvc_wing")
		wcol.set_meta("very_bouncy", true)
		wcol.set_meta("grip_factor", 0.16)
		add_child(wcol)


func _build_aerodynamic_influencers() -> void:
	# Genuine Godot Aerodynamic Physics v0.9.1 influencers directly under AeroBody3D!
	# 1. Three ManualAeroSurface3D 33m Wings (West, North, East) creating real AoA Lift, Induced Drag & Roll/Pitch Torque
	var wing_aero_defs := [
		{"name": "AeroWingEast33m", "pos": Vector3(28.0, 19.5, 0.0), "chord": 14.0, "span": 33.0, "rot": Vector3(0.08, 0.0, 0.06)},
		{"name": "AeroWingWest33m", "pos": Vector3(-28.0, 19.5, 0.0), "chord": 14.0, "span": 33.0, "rot": Vector3(0.08, 0.0, -0.06)},
		{"name": "AeroWingNorth33m", "pos": Vector3(0.0, 20.5, -28.0), "chord": 33.0, "span": 14.0, "rot": Vector3(0.11, 0.0, 0.0)},
	]
	for wd in wing_aero_defs:
		var existing_surf: Node = get_node_or_null(NodePath(wd["name"]))
		var surf: ManualAeroSurface3D = existing_surf as ManualAeroSurface3D if existing_surf is ManualAeroSurface3D else ManualAeroSurface3D.new()
		surf.name = wd["name"]
		surf.position = wd["pos"]
		surf.rotation = wd["rot"]
		var cfg := AeroSurfaceConfig.new(wd["chord"], wd["span"])
		surf.wing_config = cfg
		surf.manual_config.max_lift_coefficient = 1.85
		surf.manual_config.min_lift_coefficient = -1.45
		surf.manual_config.min_drag_coefficient = 0.06
		surf.manual_config.max_drag_coefficient = 1.15
		if surf.get_parent() == null:
			add_child(surf)
		_wing_aero_surfaces.append(surf)

	# 2. Bluff-body AeroDragInfluencer3D nodes on the 33m inflatable walls & 50m tower tops so strong winds push, tip & flip the castle!
	var drag_points := [
		{"name": "BodyCoreDrag", "pos": Vector3(0.0, 16.5, 0.0), "radius": 15.5},
		{"name": "UpperWallDrag", "pos": Vector3(0.0, 30.0, 0.0), "radius": 11.5},
		{"name": "TowerSpireDragNW", "pos": Vector3(-15.5, 44.0, -15.5), "radius": 3.4},
		{"name": "TowerSpireDragNE", "pos": Vector3(15.5, 44.0, -15.5), "radius": 3.4},
		{"name": "TowerSpireDragSW", "pos": Vector3(-15.5, 44.0, 15.5), "radius": 3.4},
		{"name": "TowerSpireDragSE", "pos": Vector3(15.5, 44.0, 15.5), "radius": 3.4},
	]
	for dp in drag_points:
		var existing_drag: Node = get_node_or_null(NodePath(dp["name"]))
		var di: AeroDragInfluencer3D = existing_drag as AeroDragInfluencer3D if existing_drag is AeroDragInfluencer3D else AeroDragInfluencer3D.new()
		di.name = dp["name"]
		di.position = dp["pos"]
		di.radius = dp["radius"]
		di.drag_coefficient = 0.92
		if di.get_parent() == null:
			add_child(di)

	# 3. AeroThruster3D + CastleWingInfluencer3D for Venturi jet recoil & active wing-beat flight
	_venturi_thruster = AeroThruster3D.new()
	_venturi_thruster.name = "VenturiJetRecoilThruster"
	_venturi_thruster.position = Vector3(0.0, 5.5, 14.5)
	_venturi_thruster.max_thrust_force = 65000.0
	_venturi_thruster.throttle_control_config = null
	_venturi_thruster.throttle = Vector3.ZERO
	add_child(_venturi_thruster)

	_wing_flap_influencer = CastleWingInfluencer3D.new()
	_wing_flap_influencer.name = "ActiveWingFlapInfluencer"
	_wing_flap_influencer.position = Vector3(0.0, 20.0, -1.5)
	add_child(_wing_flap_influencer)


func _build_interior_entities() -> void:
	# Warm crimson PS3 interior hall illumination so inside is atmospheric and readable even when gates lock!
	for lp in [Vector3(0.0, 22.0, 0.0), Vector3(0.0, 8.5, -8.5)]:
		var omni := OmniLight3D.new()
		omni.position = lp
		omni.light_color = Color(1.0, 0.45, 0.62)
		omni.light_energy = 2.6
		omni.omni_range = 30.0
		omni.shadow_enabled = false
		add_child(omni)

	# Wardrobe (3x3x3m) left of the gates inside hall!
	wardrobe = WardrobeController.new()
	wardrobe.name = "InflatableWardrobe"
	wardrobe.position = Vector3(-9.5, 2.0, 11.2)
	wardrobe.rotation.y = deg_to_rad(135.0)
	add_child(wardrobe)
	# Solid bouncy collider on castle for Wardrobe
	var wbox := BoxShape3D.new()
	wbox.size = Vector3(3.0, 3.0, 3.0)
	var wcol := CollisionShape3D.new()
	wcol.name = "WardrobeCastleCol"
	wcol.shape = wbox
	wcol.position = Vector3(-9.5, 3.5, 11.2)
	wcol.set_meta("surface_kind", "pvc")
	add_child(wcol)

	# Throne (2.5x2.5x5.0m) in rear north wall behind Dark God + "Очень прыгучий" collider!
	throne = ThroneController.new()
	throne.name = "InflatableThrone"
	throne.position = Vector3(0.0, 2.0, -12.8)
	add_child(throne)

	var th_box := BoxShape3D.new()
	th_box.size = Vector3(2.5, 2.2, 2.5)
	var th_col := CollisionShape3D.new()
	th_col.name = "ThroneSeatBouncyCol"
	th_col.shape = th_box
	th_col.position = Vector3(0.0, 3.1, -12.8)
	th_col.set_meta("surface_kind", "pvc_throne")
	th_col.set_meta("very_bouncy", true)
	th_col.set_meta("grip_factor", 0.32)
	add_child(th_col)

	# Dark God Avatar (3.0m tall, legless, rising right out of the castle floor!)
	dark_god = DarkGodController.new()
	dark_god.name = "DarkGodAvatar"
	dark_god.castle_owner = self
	dark_god.position = Vector3(0.0, 2.0, -7.2)
	add_child(dark_god)
	throne.player_seated_changed.connect(func(seated: bool):
		if seated and is_instance_valid(dark_god):
			dark_god.trigger_gtlt_expression(999.0, true)
		elif is_instance_valid(dark_god):
			dark_god.trigger_gtlt_expression(0.4, false)
	)

	# Interior Hall Zone detector (29 x 29 x 29m hollow interior -> auto-locks gates upon entry!)
	_interior_area = Area3D.new()
	_interior_area.name = "InteriorHallZone"
	_interior_area.collision_layer = 128
	_interior_area.collision_mask = 16 | 32
	var ibox := BoxShape3D.new()
	ibox.size = Vector3(28.5, 28.5, 27.0)
	var icol := CollisionShape3D.new()
	icol.shape = ibox
	icol.position = Vector3(0.0, 16.5, -0.5)
	_interior_area.add_child(icol)
	_interior_area.body_entered.connect(_on_interior_entered)
	_interior_area.body_exited.connect(_on_interior_exited)
	add_child(_interior_area)


func spawn_corner_ropes(world_parent: Node3D, ground_y: float) -> void:
	var tower_tops := [
		Vector3(-15.5, 50.0, -15.5),
		Vector3(15.5, 50.0, -15.5),
		Vector3(-15.5, 50.0, 15.5),
		Vector3(15.5, 50.0, 15.5),
	]
	for idx in range(tower_tops.size()):
		var rope := HempRope75m.new()
		rope.name = "HempRope75m_%d" % idx
		world_parent.add_child(rope)
		rope.setup_rope(self, tower_tops[idx], ground_y)
		ropes.append(rope)


func attach_atmosphere(atmo: WorldAeroAtmosphere3D) -> void:
	atmosphere_node = atmo
	if not atmosphere_areas.has(atmo):
		atmosphere_areas.append(atmo)


func set_player_reference(p: Node3D) -> void:
	player_ref = p
	if is_instance_valid(dark_god):
		dark_god.player_ref = p


func get_current_state() -> int:
	return current_state


func is_player_inside_hall() -> bool:
	return _player_inside


func _on_interior_entered(body: Node3D) -> void:
	if body != null and body.is_in_group("player_yumik"):
		_player_inside = true
		# Spec: As soon as Yumik enters inside, gates close & lock automatically EXCEPT in "Всасывание"!
		if current_state != GameState.CastleState.SUCTION:
			_set_gates_locked(true, true)


func _on_interior_exited(body: Node3D) -> void:
	if body != null and body.is_in_group("player_yumik"):
		# Confirm Yumik actually exited the 29m hall volume rather than toggling ragdoll bodies
		var local_p: Vector3 = to_local(body.global_position)
		if absf(local_p.x) > 15.2 or local_p.y < 1.2 or local_p.y > 31.8 or absf(local_p.z) > 15.2:
			_player_inside = false


func _set_gates_locked(locked: bool, play_slam_sfx: bool = false) -> void:
	if gates_closed_and_locked == locked:
		return
	gates_closed_and_locked = locked
	if is_instance_valid(_gate_blocker_shape):
		_gate_blocker_shape.set_deferred("disabled", not locked)
	if play_slam_sfx:
		AudioManager.play_3d("gate_slam", to_global(Vector3(0.0, 5.5, 15.5)), 3.0, 1.0)
	gates_lock_changed.emit(locked)


func set_castle_state(new_state: int) -> void:
	current_state = clampi(new_state, 0, 2)
	state_timer = STATE_DURATION_REAL_SEC
	interrupt_sleep()

	match current_state:
		GameState.CastleState.NORMAL:
			_wing_flap_influencer.flap_active = false
			_wing_flap_influencer.suction_recoil_active = false
			_venturi_thruster.throttle = Vector3.ZERO
			WindManager.venturi_active = false
			AudioManager.update_suction_audio(false, global_position)
			AudioManager.sky_music_weight = 0.0
			# If player is not inside, unlock gates so player can walk inside again!
			if not _player_inside:
				_set_gates_locked(false, false)
			else:
				_set_gates_locked(true, true)

		GameState.CastleState.SUCTION:
			# "Всасывание": Gates open wide, Venturi wind sucks everything inside while castle rockets in opposite direction!
			_set_gates_locked(false, true)
			_wing_flap_influencer.flap_active = false
			_wing_flap_influencer.suction_recoil_active = true
			_venturi_thruster.throttle = Vector3(0.0, 0.0, -1.0)
			AudioManager.sky_music_weight = 0.85

		GameState.CastleState.FLYING:
			# "Летающее": Flaps wings, launches skyward, rocks & rolls wildly!
			_wing_flap_influencer.flap_active = true
			_wing_flap_influencer.suction_recoil_active = false
			_venturi_thruster.throttle = Vector3.ZERO
			WindManager.venturi_active = false
			AudioManager.update_suction_audio(false, global_position)
			AudioManager.sky_music_weight = 1.0
			if _player_inside:
				_set_gates_locked(true, true)

	var st_name: String = GameState.get_castle_state_name(current_state)
	castle_state_changed.emit(current_state, st_name)
	GameState.player_status_message.emit("Состояние НЗТБНЗ: %s" % st_name)


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	super._integrate_forces(state)
	if Engine.is_editor_hint():
		return

	# Keep castle safely within world bounds on 1x1 / 10x10 / 50x50 km maps
	var limit: float = GameState.get_half_world_meters() - 55.0
	var p: Vector3 = state.transform.origin
	if absf(p.x) > limit:
		p.x = clampf(p.x, -limit, limit)
		state.linear_velocity.x *= -0.35
	if absf(p.z) > limit:
		p.z = clampf(p.z, -limit, limit)
		state.linear_velocity.z *= -0.35
	if p.y > 420.0:
		p.y = 420.0
		state.linear_velocity.y = minf(state.linear_velocity.y, 0.0)
	state.transform.origin = p


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if Engine.is_editor_hint():
		return

	# Automatic 60-game-minute (3-real-minute = 180s) state cycle
	state_timer -= delta
	if state_timer <= 0.0:
		set_castle_state((current_state + 1) % 3)

	# Animate double gate leaves smoothly between Open (apart) and Locked (sealed center)
	var target_x_left: float = -0.75 if gates_closed_and_locked else -2.35
	var target_x_right: float = 0.75 if gates_closed_and_locked else 2.35
	if is_instance_valid(_gate_left_mesh):
		_gate_left_mesh.position.x = lerpf(_gate_left_mesh.position.x, target_x_left, clampf(delta * 7.5, 0.0, 1.0))
	if is_instance_valid(_gate_right_mesh):
		_gate_right_mesh.position.x = lerpf(_gate_right_mesh.position.x, target_x_right, clampf(delta * 7.5, 0.0, 1.0))

	# Update Venturi mouth world transform & sound in "Всасывание"
	if current_state == GameState.CastleState.SUCTION:
		var gate_mouth_world: Vector3 = to_global(Vector3(0.0, 5.5, 11.5))
		WindManager.venturi_active = true
		WindManager.venturi_mouth_pos = gate_mouth_world
		WindManager.venturi_inward_dir = (-global_basis.z).normalized()
		AudioManager.update_suction_audio(true, gate_mouth_world)

	# Animate giant 33m outer angel wings visually & trigger booming wing-flap OGG audio!
	_flap_anim_t += delta
	for i in range(_outer_wing_pivots.size()):
		var piv: Node3D = _outer_wing_pivots[i]
		if current_state == GameState.CastleState.FLYING:
			var beat: float = sin(_flap_anim_t * 3.1 + float(i) * 0.25)
			piv.rotation.z = beat * 0.42
		else:
			var breeze_sway: float = sin(_flap_anim_t * 1.1 + float(i)) * clampf(WindManager.current_speed_kmh / 180.0, 0.02, 0.22)
			piv.rotation.z = lerpf(piv.rotation.z, breeze_sway, clampf(delta * 3.0, 0.0, 1.0))

	if current_state == GameState.CastleState.FLYING:
		_flap_sfx_cooldown -= delta
		if _flap_sfx_cooldown <= 0.0:
			_flap_sfx_cooldown = (TAU / 3.1)
			var wkey := "wing_flap_1" if randf() < 0.5 else "wing_flap_2"
			AudioManager.play_3d(wkey, to_global(Vector3(0.0, 20.0, 0.0)), 4.0, randf_range(0.88, 1.05))
