extends Area3D
class_name HurricaneVortex

## Spawned 250 meters from Yumik when Debug Wind "Ураган (120 км/ч)" is activated.
## Rotates its 180m storm funnel cloud, emits roaring .ogg wind audio, and applies
## vortex suction + updraft impulses to RigidBody3D / CharacterBody3D entities.

var spin_speed: float = 3.4
var drift_dir := Vector3(0.4, 0.0, -0.9).normalized()
var lifetime_sec: float = 180.0
var funnel_visual: Node3D
var roar_player: AudioStreamPlayer3D


func _ready() -> void:
	collision_layer = 64 # Layer 7: TriggersAndWind
	collision_mask = 2 | 4 | 8 | 16 | 32
	monitoring = true
	monitorable = false

	var col := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 220.0
	cyl.height = 260.0
	col.shape = cyl
	col.position = Vector3(0.0, 120.0, 0.0)
	add_child(col)

	funnel_visual = Node3D.new()
	funnel_visual.name = "FunnelVisual"
	add_child(funnel_visual)

	var vmat: Material = load("res://assets/materials/mat_hurricane_vortex.tres")
	if ResourceLoader.exists("res://assets/models/hurricane_funnel.glb"):
		var packed: PackedScene = load("res://assets/models/hurricane_funnel.glb")
		if packed:
			var inst: Node = packed.instantiate()
			_apply_mat(inst, vmat)
			funnel_visual.add_child(inst)
	else:
		# Fallback multi-cone funnel
		for i in range(6):
			var mi := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.bottom_radius = 6.0 + float(i) * 6.5
			cm.top_radius = 12.0 + float(i + 1) * 7.5
			cm.height = 30.0
			mi.mesh = cm
			mi.position = Vector3(0.0, 15.0 + float(i) * 30.0, 0.0)
			mi.material_override = vmat
			funnel_visual.add_child(mi)

	roar_player = AudioStreamPlayer3D.new()
	roar_player.bus = &"Ambient"
	roar_player.max_distance = 750.0
	roar_player.unit_size = 45.0
	if AudioManager.streams.has("wind_hurricane"):
		roar_player.stream = AudioManager.streams["wind_hurricane"]
		roar_player.play()
	add_child(roar_player)

	drift_dir = WindManager.artificial_direction


func _apply_mat(n: Node, mat: Material) -> void:
	if n is MeshInstance3D:
		(n as MeshInstance3D).material_override = mat
	for c in n.get_children():
		_apply_mat(c, mat)


func _physics_process(delta: float) -> void:
	lifetime_sec -= delta
	if lifetime_sec <= 0.0 or not WindManager.hurricane_active:
		queue_free()
		return

	if funnel_visual:
		funnel_visual.rotate_y(spin_speed * delta)

	# Slowly drift across the terrain surface
	global_position += drift_dir * (3.2 * delta)
	var parent_world: Node = get_parent()
	if parent_world and parent_world.has_method("sample_terrain_height"):
		global_position.y = parent_world.call("sample_terrain_height", global_position.x, global_position.z)

	for body in get_overlapping_bodies():
		if body is RigidBody3D:
			var rb := body as RigidBody3D
			var rel: Vector3 = rb.global_position - global_position
			var horiz := Vector3(rel.x, 0.0, rel.z)
			var d: float = maxf(horiz.length(), 2.0)
			var strength: float = clampf(1.0 - (d / 220.0), 0.0, 1.0)
			var tang := Vector3(-horiz.z, 0.0, horiz.x).normalized()
			var pull := -horiz.normalized()
			var force_vec: Vector3 = (tang * 28.0 + pull * 16.0 + Vector3.UP * 22.0) * rb.mass * strength * 0.45
			rb.apply_central_force(force_vec)
