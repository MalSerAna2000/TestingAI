extends Control
class_name TouchCamera

# ----------------------------------------------------------------
# Свайп правой половины экрана — вращение камеры от третьего лица.
# ----------------------------------------------------------------

signal rotation_changed(dx: float, dy: float)

var _active_touch: int = -1
var _last: Vector2 = Vector2.ZERO

@export var sensitivity: float = 0.6

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _active_touch == -1:
			var local = get_local_mouse_position()
			if local.x > rect_size.x * 0.3:
				_active_touch = event.index
				_last = local
		elif not event.pressed and event.index == _active_touch:
			_active_touch = -1
	elif event is InputEventScreenDrag and event.index == _active_touch:
		var local = get_local_mouse_position()
		var delta = local - _last
		_last = local
		rotation_changed.emit(delta.x * sensitivity, delta.y * sensitivity)
