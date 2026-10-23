extends Control
class_name TouchJoystick

# ----------------------------------------------------------------
# Виртуальный джойстик (левая половина экрана, мультитач).
# Внутри мёртвой зоны — шаг, за пределами — бег.
# ----------------------------------------------------------------

signal direction_changed(direction: Vector2, running: bool)

@export var deadzone: float = 0.15
@export var run_threshold: float = 0.7

var _active_touch: int = -1
var _anchor: Vector2 = Vector2.ZERO
var _radius: float = 80.0

var direction: Vector2 = Vector2.ZERO
var is_running: bool = false

func _gui_input(event: InputEvent) -> void:
	if not is_inside_tree():
		return
	if event is InputEventScreenTouch:
		if event.pressed and _active_touch == -1:
			# начинаем касание только внутри области джойстика
			var local = get_local_mouse_position()
			if local.length() < _radius + 20:
				_active_touch = event.index
				_anchor = local
		elif not event.pressed and event.index == _active_touch:
			_active_touch = -1
			_anchor = Vector2.ZERO
			direction = Vector2.ZERO
			is_running = false
			direction_changed.emit(Vector2.ZERO, false)
	elif event is InputEventScreenDrag and event.index == _active_touch:
		var local = get_local_mouse_position()
		var offset = local - _anchor
		var dist = offset.length()
		var clamped = offset.clamped(_radius) if dist > _radius else offset
		direction = clamped / _radius
		is_running = dist > _radius * run_threshold
		if direction.length() < deadzone:
			direction = Vector2.ZERO
			is_running = false
		direction_changed.emit(direction, is_running)

func _draw() -> void:
	var center = rect_size / 2
	draw_circle(center, _radius, Color(1, 1, 1, 0.15))
	draw_circle(center, _radius * deadzone, Color(1, 1, 1, 0.05))
	if _active_touch != -1:
		var pos = _anchor + direction * _radius
		draw_circle(pos, 26, Color(1, 1, 1, 0.6))
