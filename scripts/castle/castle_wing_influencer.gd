@tool
class_name CastleWingInfluencer3D
extends AeroInfluencer3D
## Custom AeroInfluencer3D driving active wing-beat lift, turbulence, banking, flips,
## and Venturi reaction forces for НЗТБНЗ inside AeroBody3D's substep solver.

@export var flap_active: bool = false
@export var suction_recoil_active: bool = false
@export var flap_phase_offset: float = 0.0
@export var flap_lift_power: float = 44000.0
@export var recoil_force_power: float = 115000.0

var _sim_time: float = 0.0


func _enter_tree() -> void:
	super._enter_tree()


func _ready() -> void:
	super._ready()


func _physics_process(delta: float) -> void:
	super._physics_process(delta)


func is_overriding_body_sleep() -> bool:
	if Engine.is_editor_hint():
		return false
	return flap_active or suction_recoil_active or WindManager.current_speed_kmh > 4.0


func _calculate_forces(substep_delta: float = 0.0) -> PackedVector3Array:
	var force_and_torque: PackedVector3Array = super._calculate_forces(substep_delta)
	if Engine.is_editor_hint():
		return force_and_torque

	_sim_time += substep_delta
	var added_force := Vector3.ZERO
	var added_torque := Vector3.ZERO

	if flap_active and is_instance_valid(aero_body):
		# Powerful rhythmic wing downstrokes + wild playful rolling/banking/inversion torques!
		var downstroke: float = maxf(sin(_sim_time * 3.1 + flap_phase_offset), -0.22)
		var alt_target_boost: float = clampf((95.0 - aero_body.global_position.y) / 65.0, -0.35, 1.45)
		var up_vec: Vector3 = (aero_body.global_basis.y * 0.65 + Vector3.UP * 0.75).normalized()
		var fwd_vec: Vector3 = -aero_body.global_basis.z

		var lift_mag: float = flap_lift_power * (0.62 + 0.85 * downstroke) * maxf(alt_target_boost, 0.15)
		var circle_vec: Vector3 = (fwd_vec * 0.8 + aero_body.global_basis.x * 0.45 * sin(_sim_time * 0.45)).normalized()
		added_force += up_vec * lift_mag + circle_vec * (flap_lift_power * 0.34)

		# Sway, shake, spin, and periodic barrel-roll flips in midair!
		var roll_wave: float = sin(_sim_time * 0.85 + flap_phase_offset) + 0.65 * sin(_sim_time * 2.15)
		var pitch_wave: float = cos(_sim_time * 0.72) * 0.8
		var yaw_wave: float = sin(_sim_time * 0.53) * 0.9
		added_torque += aero_body.global_basis * Vector3(pitch_wave, yaw_wave, roll_wave) * 420000.0

	if suction_recoil_active and is_instance_valid(aero_body):
		# Gates face +Z locally -> suction pulls air INTO -Z, blasting reaction force toward -Z (away from gate opening)!
		var recoil_dir: Vector3 = (-aero_body.global_basis.z * 0.92 + Vector3.UP * 0.24).normalized()
		var pulse: float = 0.85 + 0.28 * sin(_sim_time * 4.2)
		added_force += recoil_dir * recoil_force_power * pulse
		added_torque += aero_body.global_basis.x * (sin(_sim_time * 1.9) * 260000.0)

	_current_force = added_force
	_current_torque = relative_position.cross(added_force) + added_torque

	force_and_torque[0] += _current_force
	force_and_torque[1] += _current_torque
	return force_and_torque
