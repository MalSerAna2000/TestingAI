extends Control
class_name VirtualJoystick

## Multi-touch Android Virtual Joystick:
## - Deflection inside base ring (radius <= walk_radius) -> Walk (Шаг)
## - Dragging outside base ring (radius > walk_radius) -> Run (Бег)

signal joystick_updated(vec: Vector2, is_outside_ring: bool)

@export var walk_radius: float = 105.0
@export var max_knob_radius: float = 195.0
@export var deadzone: float = 0.08

var active_touch_id: int = -1
var ring_center := Vector2.ZERO
var knob_offset := Vector2.ZERO
var is_running_zone: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_recenter()
	resized.connect(_recenter)


func _recenter() -> void:
	ring_center = Vector2(size.x * 0.42, size.y * 0.58)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed and active_touch_id == -1:
			active_touch_id = st.index
			_update_from_local_pos(st.position)
			accept_event()
		elif not st.pressed and st.index == active_touch_id:
			_release_joystick()
			accept_event()
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if sd.index == active_touch_id:
			_update_from_local_pos(sd.position)
			accept_event()


func _update_from_local_pos(local_pos: Vector2) -> void:
	var delta_v: Vector2 = local_pos - ring_center
	var dist: float = delta_v.length()
	if dist < walk_radius * deadzone:
		knob_offset = Vector2.ZERO
		is_running_zone = false
		joystick_updated.emit(Vector2.ZERO, false)
	else:
		var clamped_dist: float = minf(dist, max_knob_radius)
		var dir: Vector2 = delta_v / dist
		knob_offset = dir * clamped_dist
		is_running_zone = dist > walk_radius
		var norm_len: float = dist / walk_radius
		joystick_updated.emit(dir * minf(norm_len, 1.45), is_running_zone)
	queue_redraw()


func _release_joystick() -> void:
	active_touch_id = -1
	knob_offset = Vector2.ZERO
	is_running_zone = false
	joystick_updated.emit(Vector2.ZERO, false)
	queue_redraw()


func _draw() -> void:
	# Outer run-threshold halo
	draw_arc(ring_center, max_knob_radius, 0.0, TAU, 64, Color(1.0, 0.35, 0.55, 0.20), 2.5, true)
	# Walk ring
	var ring_col := Color(1.0, 0.36, 0.54, 0.72) if is_running_zone else Color(0.85, 0.88, 0.98, 0.48)
	draw_circle(ring_center, walk_radius, Color(0.08, 0.06, 0.14, 0.45))
	draw_arc(ring_center, walk_radius, 0.0, TAU, 64, ring_col, 4.0, true)

	# Thumb knob
	var knob_pos: Vector2 = ring_center + knob_offset
	var knob_col := Color(0.95, 0.24, 0.45, 0.92) if is_running_zone else Color(0.92, 0.94, 1.0, 0.86)
	draw_circle(knob_pos, 38.0, knob_col)
	draw_arc(knob_pos, 38.0, 0.0, TAU, 36, Color(1.0, 1.0, 1.0, 0.95), 2.5, true)
