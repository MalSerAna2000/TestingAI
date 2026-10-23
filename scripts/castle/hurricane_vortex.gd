class_name HurricaneVortex
extends Node3D
## Towering 3D Hurricane Funnel / Trigger spawned 250 meters away from Yumik
## whenever "Ураган (120 км/ч)" is activated in the Debug Menu.

var target_focus: Node3D
var _rings: Array[MeshInstance3D] = []
var _spin_t: float = 0.0


func _ready() -> void:
	_build_vortex_funnel()


func _build_vortex_funnel() -> void:
	var funnel_mat := StandardMaterial3D.new()
	funnel_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	funnel_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	funnel_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	funnel_mat.albedo_color = Color(0.56, 0.60, 0.72, 0.34)

	# 10 stacked expanding tornado rings from ground (radius 8m) up to 240m cloud deck (radius 88m)!
	for i in range(10):
		var t: float = float(i) / 9.0
		var cyl := CylinderMesh.new()
		cyl.top_radius = lerpf(10.0, 88.0, pow(t, 1.25))
		cyl.bottom_radius = lerpf(7.0, 74.0, pow(maxf(t - 0.1, 0.0), 1.25))
		cyl.height = 28.0
		cyl.radial_segments = 24
		cyl.cap_top = false
		cyl.cap_bottom = false

		var mi := MeshInstance3D.new()
		mi.name = "VortexRing_%d" % i
		mi.mesh = cyl
		mi.position = Vector3(0.0, 14.0 + float(i) * 24.0, 0.0)
		mi.material_override = funnel_mat
		add_child(mi)
		_rings.append(mi)

	var trigger := Area3D.new()
	trigger.name = "HurricaneTriggerArea"
	trigger.collision_layer = 128
	trigger.collision_mask = 4 | 16 | 32
	var cyl_shape := CylinderShape3D.new()
	cyl_shape.radius = 165.0
	cyl_shape.height = 280.0
	var csh := CollisionShape3D.new()
	csh.shape = cyl_shape
	csh.position = Vector3(0.0, 140.0, 0.0)
	trigger.add_child(csh)
	add_child(trigger)


func _physics_process(delta: float) -> void:
	_spin_t += delta
	for i in range(_rings.size()):
		var r: MeshInstance3D = _rings[i]
		r.rotation.y += delta * (4.8 - float(i) * 0.25)
		r.position.x = sin(_spin_t * 2.2 + float(i) * 0.55) * (3.5 + float(i) * 0.9)
		r.position.z = cos(_spin_t * 1.9 + float(i) * 0.55) * (3.5 + float(i) * 0.9)

	# Drift menacingly across the valley toward the action so the 250m funnel overtakes castle & player!
	if is_instance_valid(target_focus):
		var to_target: Vector3 = target_focus.global_position - global_position
		to_target.y = 0.0
		if to_target.length() > 14.0:
			global_position += to_target.normalized() * (5.2 * delta)

	WindManager.hurricane_center = global_position
