class_name VirtualJoystick
extends Control
## Multi-touch Virtual Joystick with Dual Gait Zones:
## - Inside the joystick circle (deadzone < r <= walkzone_size): WALK ("Шаг")
## - Outside the joystick circle (r > walkzone_size): RUN ("Бег")

signal joystick_updated(direction: Vector2, running: bool)

@export var pressed_color := Color(0.95, 0.35, 0.48, 1.0)
@export var run_color := Color(1.0, 0.68, 0.22, 1.0)
@export_range(0, 200, 1) var deadzone_size: float = 12.0
@export_range(20, 300, 1) var walkzone_size: float = 95.0
@export_range(40, 500, 1) var clampzone_size: float = 175.0

enum Joystick_mode {
	FIXED,
	DYNAMIC,
	FOLLOWING
}

@export var joystick_mode := Joystick_mode.FIXED

enum Visibility_mode {
	ALWAYS,
	TOUCHSCREEN_ONLY,
	WHEN_TOUCHED
}

@export var visibility_mode := Visibility_mode.ALWAYS
@export var use_input_actions := false
@export var action_left := "ui_left"
@export var action_right := "ui_right"
@export var action_up := "ui_up"
@export var action_down := "ui_down"

var is_pressed: bool = false
var is_running: bool = false
var output: Vector2 = Vector2.ZERO
var move_direction: Vector2 = Vector2.ZERO
var distance_ratio: float = 0.0

var _touch_index: int = -1
var _current_offset: Vector2 = Vector2.ZERO

@onready var _base: Control = $Base
@onready var _tip: Control = $Base/Tip
@onready var _base_default_position: Vector2 = _base.position
@onready var _tip_default_position: Vector2 = _tip.position
@onready var _default_color: Color = _tip.modulate


func _ready() -> void:
	if not DisplayServer.is_touchscreen_available() and visibility_mode == Visibility_mode.TOUCHSCREEN_ONLY:
		hide()
	if visibility_mode == Visibility_mode.WHEN_TOUCHED:
		hide()
	_reset()


func get_touch_index() -> int:
	return _touch_index


func _draw() -> void:
	if not is_instance_valid(_base):
		return
	var center: Vector2 = _base.position + _base.size * 0.5
	var outer_col := Color(1.0, 0.55, 0.25, 0.52) if is_running else Color(0.85, 0.25, 0.42, 0.24)
	draw_arc(center, walkzone_size, 0.0, TAU, 48, Color(0.85, 0.85, 0.98, 0.42), 2.5, true)
	draw_arc(center, clampzone_size, 0.0, TAU, 64, outer_col, 2.0, true)
	if is_pressed:
		var line_col := run_color if is_running else pressed_color
		draw_line(center, center + _current_offset, Color(line_col.r, line_col.g, line_col.b, 0.65), 3.0, true)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			if _touch_index == -1 and _is_point_inside_joystick_area(event.position):
				if joystick_mode == Joystick_mode.DYNAMIC or joystick_mode == Joystick_mode.FOLLOWING:
					_move_base(event.position)
				if visibility_mode == Visibility_mode.WHEN_TOUCHED:
					show()
				_touch_index = event.index
				_update_joystick(event.position)
				get_viewport().set_input_as_handled()
		elif event.index == _touch_index:
			_reset()
			if visibility_mode == Visibility_mode.WHEN_TOUCHED:
				hide()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		if event.index == _touch_index:
			_update_joystick(event.position)
			get_viewport().set_input_as_handled()


func _move_base(new_position: Vector2) -> void:
	_base.global_position = new_position - _base.pivot_offset * get_global_transform_with_canvas().get_scale()


func _move_tip(new_position: Vector2) -> void:
	_tip.global_position = new_position - _tip.pivot_offset * _base.get_global_transform_with_canvas().get_scale()


func _is_point_inside_joystick_area(point: Vector2) -> bool:
	var scale_vec: Vector2 = get_global_transform_with_canvas().get_scale()
	var x_ok: bool = point.x >= global_position.x and point.x <= global_position.x + (size.x * scale_vec.x)
	var y_ok: bool = point.y >= global_position.y and point.y <= global_position.y + (size.y * scale_vec.y)
	return x_ok and y_ok


func _get_base_radius() -> Vector2:
	return _base.size * _base.get_global_transform_with_canvas().get_scale() * 0.5


func _update_joystick(touch_position: Vector2) -> void:
	var base_radius: Vector2 = _get_base_radius()
	var center: Vector2 = _base.global_position + base_radius
	var raw_vector: Vector2 = touch_position - center
	var raw_dist: float = raw_vector.length()
	var clamped_vector: Vector2 = raw_vector.limit_length(clampzone_size)
	_current_offset = clamped_vector

	if joystick_mode == Joystick_mode.FOLLOWING and raw_dist > clampzone_size:
		_move_base(touch_position - clamped_vector)

	_move_tip(center + clamped_vector)

	var effective_walk_radius: float = maxf(walkzone_size, deadzone_size + 1.0)
	if raw_dist > deadzone_size:
		is_pressed = true
		move_direction = raw_vector.normalized()
		# Strictly inside joystick boundary -> Walk; beyond joystick boundary -> Run!
		is_running = raw_dist > effective_walk_radius
		if is_running:
			output = move_direction
			distance_ratio = clampf(raw_dist / maxf(clampzone_size, 1.0), 0.0, 1.0)
			_tip.modulate = run_color
		else:
			var walk_strength: float = clampf((raw_dist - deadzone_size) / (effective_walk_radius - deadzone_size), 0.15, 1.0)
			output = move_direction * walk_strength
			distance_ratio = walk_strength * 0.65
			_tip.modulate = pressed_color
	else:
		is_pressed = false
		is_running = false
		move_direction = Vector2.ZERO
		output = Vector2.ZERO
		distance_ratio = 0.0
		_tip.modulate = _default_color

	if use_input_actions:
		_sync_input_actions()

	joystick_updated.emit(output, is_running)
	queue_redraw()


func _sync_input_actions() -> void:
	if output.x >= 0.0 and Input.is_action_pressed(action_left):
		Input.action_release(action_left)
	if output.x <= 0.0 and Input.is_action_pressed(action_right):
		Input.action_release(action_right)
	if output.y >= 0.0 and Input.is_action_pressed(action_up):
		Input.action_release(action_up)
	if output.y <= 0.0 and Input.is_action_pressed(action_down):
		Input.action_release(action_down)
	if output.x < 0.0:
		Input.action_press(action_left, -output.x)
	if output.x > 0.0:
		Input.action_press(action_right, output.x)
	if output.y < 0.0:
		Input.action_press(action_up, -output.y)
	if output.y > 0.0:
		Input.action_press(action_down, output.y)


func _reset() -> void:
	is_pressed = false
	is_running = false
	output = Vector2.ZERO
	move_direction = Vector2.ZERO
	distance_ratio = 0.0
	_touch_index = -1
	_current_offset = Vector2.ZERO
	if is_instance_valid(_tip):
		_tip.modulate = _default_color
		_tip.position = _tip_default_position
	if is_instance_valid(_base):
		_base.position = _base_default_position
	if use_input_actions:
		for action in [action_left, action_right, action_down, action_up]:
			if Input.is_action_pressed(action):
				Input.action_release(action)
	joystick_updated.emit(Vector2.ZERO, false)
	queue_redraw()
