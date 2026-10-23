class_name AeroBody3D extends RigidBody3D

# Заглушка узла AeroBody3D (настоящий — из плагина Godot Aerodynamic Physics).
# Надувное тело замка: ветер создаёт силу сопротивления и подъём, объект лёгкий,
# но инертный. Настоящий плагин заменит эту логику на реалистичную аэродинамику.

@export var wind_surface_area: float = 1200.0      # м² Effective лобовое сопротивление
@export var drag_coefficient: float = 0.9
@export var lift_coefficient: float = 0.35
@export var air_density: float = 1.225
@export var angular_damping_air: float = 0.95

var wind: Vector3 = Vector3(0, 0, 0)

func set_wind(wind_vector: Vector3) -> void:
	wind = wind_vector

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	var velocity: Vector3 = state.linear_velocity
	var rel_wind: Vector3 = wind - velocity
	var speed: float = rel_wind.length()
	if speed < 0.01:
		return
	var dyn_pressure: float = 0.5 * air_density * speed * speed
	var direction: Vector3 = rel_wind.normalized()
	# Сила лобового сопротивления
	var drag: Vector3 = -direction * dyn_pressure * wind_surface_area * drag_coefficient
	state.apply_central_force(drag)
	# Затухание вращения — надувной объект Stabilзируется в потоке
	state.angular_velocity = state.angular_velocity * angular_damping_air
