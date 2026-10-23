class_name AeroInfluencer3D extends Node3D

# Заглушка узла AeroInfluencer3D (крило / поверхность, создающая подъём и résistance).
# Размещается на крыльях и корпусе замка. Каждый кадр приложит силу к телу владельца
# (AeroBody3D) в зависимости от угла атаки и скорости ветра.

@export var surface_area: float = 400.0        # м² площадь поверхности
@export var lift_coefficient: float = 0.9
@export var drag_coefficient: float = 0.5
@export var air_density: float = 1.225

var body: AeroBody3D
var wind: Vector3 = Vector3(0, 0, 0)

func set_wind(wind_vector: Vector3) -> void:
	wind = wind_vector

func _physics_process(delta: float) -> void:
	if not body:
		body = get_parent()
		if not body or not body.has_method("apply_force"):
			body = null
			return
	var velocity: Vector3 = body.linear_velocity
	var rel_wind: Vector3 = wind - velocity
	var speed: float = rel_wind.length()
	if speed < 0.01:
		return
	var dyn_pressure: float = 0.5 * air_density * speed * speed
	var direction: Vector3 = rel_wind.normalized()
	# Подъёмная сила по локальной вертикали поверхности (упрощённо)
	var up: Vector3 = global_transform.basis.y.normalized()
	var attack: float = clamp(direction.dot(up), -1.0, 1.0)
	var lift: Vector3 = up * attack * dyn_pressure * surface_area * lift_coefficient
	var drag: Vector3 = -direction * dyn_pressure * surface_area * drag_coefficient
	body.apply_force(lift + drag, global_position)
