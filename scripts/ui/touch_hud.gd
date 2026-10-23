class_name TouchHUD
extends CanvasLayer
## Full Android Multi-Touch HUD:
## - Left side: Virtual Joystick (inside circle = Walk "Шаг", outside circle = Run "Бег")
## - Right side background drag: Multi-touch third-person camera orbit
## - Top-left buttons: "Не отпускай меня", "Меню отладки"
## - Right-side buttons: "Лечь", "На четвереньки", "Вскарабкаться",
##   dynamic "Прыжок" / "Припрыжку", "Тискать", and conditional "Задрать подол" (only in Maid Dress!)

var player_ref: YumikController
var castle_ref: InflatableCastle
var biome_gen_ref: BiomeGenerator

var joystick: VirtualJoystick
var debug_panel: DebugMenuPanel

var _btn_dont_let_go: Button
var _btn_debug: Button
var _btn_lie: Button
var _btn_all_fours: Button
var _btn_climb: Button
var _btn_jump: Button
var _btn_hug: Button
var _btn_lift_hem: Button

var _telemetry_label: Label
var _toast_label: Label
var _gait_badge: Label
var _nyash_bar: ProgressBar
var _nyash_box: VBoxContainer
var _sleep_overlay: Control
var _sleep_caption: Label

var _cam_touch_id: int = -1
var _toast_timer: float = 0.0


func setup_hud(p_player: YumikController, p_castle: InflatableCastle, p_biome_gen: BiomeGenerator) -> void:
	player_ref = p_player
	castle_ref = p_castle
	biome_gen_ref = p_biome_gen
	debug_panel.player_ref = p_player
	debug_panel.castle_ref = p_castle

	player_ref.hold_me_state_changed.connect(_on_hold_me_changed)
	player_ref.hug_state_changed.connect(_on_hug_changed)
	player_ref.hem_state_changed.connect(_on_hem_changed)
	player_ref.nyashing_progress_updated.connect(_on_nyash_progress)
	GameState.maid_outfit_changed.connect(_on_maid_outfit_changed)
	GameState.player_status_message.connect(_show_toast)
	GameState.sleep_cutscene_state_changed.connect(_on_sleep_cutscene_changed)

	_btn_lift_hem.visible = GameState.maid_outfit_equipped


func _ready() -> void:
	layer = 10
	_build_hud_controls()


func _make_touch_button(text_str: String, min_size := Vector2(162, 54), base_col := Color(0.14, 0.09, 0.19, 0.86)) -> Button:
	var b := Button.new()
	b.text = text_str
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 16)
	var sb := StyleBoxFlat.new()
	sb.bg_color = base_col
	sb.border_color = Color(0.86, 0.42, 0.58, 0.90)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	b.add_theme_stylebox_override("normal", sb)
	var sbh := sb.duplicate()
	sbh.bg_color = base_col.lightened(0.12)
	b.add_theme_stylebox_override("hover", sbh)
	var sbp := sb.duplicate()
	sbp.bg_color = Color(0.68, 0.18, 0.36, 0.95)
	b.add_theme_stylebox_override("pressed", sbp)
	return b


func _build_hud_controls() -> void:
	var root := Control.new()
	root.name = "HUDRoot"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(root)

	# 1. Right-Half Multi-Touch Camera Orbit Zone (placed underneath buttons so buttons take priority!)
	var cam_drag_zone := Control.new()
	cam_drag_zone.name = "RightScreenCameraSwipeZone"
	cam_drag_zone.anchor_left = 0.40
	cam_drag_zone.anchor_top = 0.0
	cam_drag_zone.anchor_right = 1.0
	cam_drag_zone.anchor_bottom = 1.0
	cam_drag_zone.mouse_filter = Control.MOUSE_FILTER_PASS
	cam_drag_zone.gui_input.connect(_on_camera_zone_gui_input)
	root.add_child(cam_drag_zone)

	# 2. Left-Side Virtual Joystick (inside ring = Walk, outside ring = Run)
	var joy_scene: PackedScene = load("res://addons/virtual_joystick/virtual_joystick_scene.tscn")
	joystick = joy_scene.instantiate() as VirtualJoystick
	joystick.name = "LeftTouchJoystick"
	joystick.anchor_left = 0.0
	joystick.anchor_top = 1.0
	joystick.anchor_right = 0.0
	joystick.anchor_bottom = 1.0
	joystick.offset_left = 24.0
	joystick.offset_top = -396.0
	joystick.offset_right = 404.0
	joystick.offset_bottom = -16.0
	joystick.walkzone_size = 95.0
	joystick.clampzone_size = 175.0
	joystick.joystick_updated.connect(_on_joystick_updated)
	root.add_child(joystick)

	_gait_badge = Label.new()
	_gait_badge.text = "Джойстик: Покой (внутри — Шаг, снаружи — Бег)"
	_gait_badge.position = Vector2(36.0, 24.0)
	_gait_badge.anchor_top = 1.0
	_gait_badge.anchor_bottom = 1.0
	_gait_badge.offset_top = -428.0
	_gait_badge.offset_bottom = -398.0
	_gait_badge.offset_left = 34.0
	_gait_badge.offset_right = 460.0
	_gait_badge.add_theme_font_size_override("font_size", 14)
	_gait_badge.modulate = Color(0.88, 0.85, 0.96)
	root.add_child(_gait_badge)

	# 3. Top-Left Buttons: "Не отпускай меня" & "Меню отладки"
	var top_left := HBoxContainer.new()
	top_left.name = "TopLeftButtons"
	top_left.position = Vector2(20.0, 16.0)
	top_left.add_theme_constant_override("separation", 12)
	root.add_child(top_left)

	_btn_dont_let_go = _make_touch_button("Не отпускай меня", Vector2(205, 52), Color(0.32, 0.08, 0.18, 0.90))
	_btn_dont_let_go.pressed.connect(func():
		AudioManager.play_2d("ui_tap")
		if is_instance_valid(player_ref):
			player_ref.toggle_dont_let_go()
	)
	top_left.add_child(_btn_dont_let_go)

	_btn_debug = _make_touch_button("Меню отладки", Vector2(175, 52), Color(0.16, 0.12, 0.26, 0.90))
	_btn_debug.pressed.connect(func():
		AudioManager.play_2d("ui_tap")
		debug_panel.visible = not debug_panel.visible
	)
	top_left.add_child(_btn_debug)

	# 4. Top-Center Telemetry & Toast Feedback
	var top_center := VBoxContainer.new()
	top_center.anchor_left = 0.28
	top_center.anchor_right = 0.78
	top_center.offset_top = 14.0
	top_center.offset_bottom = 96.0
	top_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top_center)

	_telemetry_label = Label.new()
	_telemetry_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_telemetry_label.add_theme_font_size_override("font_size", 15)
	_telemetry_label.modulate = Color(0.95, 0.90, 1.0)
	top_center.add_child(_telemetry_label)

	_toast_label = Label.new()
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.add_theme_font_size_override("font_size", 17)
	_toast_label.modulate = Color(1.0, 0.78, 0.45, 0.0)
	top_center.add_child(_toast_label)

	# Nyashing Euphoria Exhaustion Progress Bar (shown automatically during "Няшинг")
	_nyash_box = VBoxContainer.new()
	_nyash_box.visible = false
	top_center.add_child(_nyash_box)
	_nyash_bar = ProgressBar.new()
	_nyash_bar.max_value = 20.0
	_nyash_bar.custom_minimum_size = Vector2(320, 22)
	_nyash_box.add_child(_nyash_bar)

	# 5. Right-Side Ergonomic Touch Action Cluster
	var right_col := GridContainer.new()
	right_col.name = "RightActionButtons"
	right_col.columns = 2
	right_col.anchor_left = 1.0
	right_col.anchor_top = 1.0
	right_col.anchor_right = 1.0
	right_col.anchor_bottom = 1.0
	right_col.offset_left = -366.0
	right_col.offset_top = -268.0
	right_col.offset_right = -20.0
	right_col.offset_bottom = -20.0
	right_col.add_theme_constant_override("h_separation", 12)
	right_col.add_theme_constant_override("v_separation", 12)
	root.add_child(right_col)

	_btn_jump = _make_touch_button("Прыжок", Vector2(166, 66), Color(0.46, 0.12, 0.26, 0.92))
	_btn_jump.pressed.connect(func():
		if is_instance_valid(player_ref):
			player_ref.press_jump_or_skip()
	)
	right_col.add_child(_btn_jump)

	_btn_climb = _make_touch_button("Вскарабкаться", Vector2(166, 66), Color(0.18, 0.14, 0.30, 0.90))
	_btn_climb.pressed.connect(func():
		AudioManager.play_2d("ui_tap")
		if is_instance_valid(player_ref):
			player_ref.press_climb()
	)
	right_col.add_child(_btn_climb)

	_btn_hug = _make_touch_button("Тискать", Vector2(166, 60), Color(0.36, 0.10, 0.24, 0.90))
	_btn_hug.pressed.connect(func():
		if is_instance_valid(player_ref):
			player_ref.press_hug_squeeze()
	)
	right_col.add_child(_btn_hug)

	_btn_all_fours = _make_touch_button("На четвереньках", Vector2(166, 60))
	_btn_all_fours.pressed.connect(func():
		AudioManager.play_2d("ui_tap")
		if is_instance_valid(player_ref):
			player_ref.press_all_fours()
	)
	right_col.add_child(_btn_all_fours)

	_btn_lie = _make_touch_button("Лечь", Vector2(166, 56))
	_btn_lie.pressed.connect(func():
		AudioManager.play_2d("ui_tap")
		if is_instance_valid(player_ref):
			player_ref.press_lie_down()
	)
	right_col.add_child(_btn_lie)

	# Conditional 6th right-side button: visible ONLY when Maid Dress is worn!
	_btn_lift_hem = _make_touch_button("Задрать подол", Vector2(166, 56), Color(0.55, 0.18, 0.38, 0.92))
	_btn_lift_hem.visible = false
	_btn_lift_hem.pressed.connect(func():
		if is_instance_valid(player_ref):
			player_ref.press_lift_hem()
	)
	right_col.add_child(_btn_lift_hem)

	# 6. Floating Debug Menu Panel
	debug_panel = DebugMenuPanel.new()
	debug_panel.name = "DebugMenuPanel"
	debug_panel.visible = false
	debug_panel.position = Vector2(20.0, 80.0)
	root.add_child(debug_panel)

	# 7. 8-Game-Hour Sleep Nyashing Cutscene Overlay
	_sleep_overlay = ColorRect.new()
	_sleep_overlay.name = "SleepCutsceneOverlay"
	_sleep_overlay.color = Color(0.10, 0.02, 0.07, 0.56)
	_sleep_overlay.visible = false
	_sleep_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(_sleep_overlay)

	var sleep_vbox := VBoxContainer.new()
	sleep_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	sleep_vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	sleep_vbox.offset_left = -320.0
	sleep_vbox.offset_right = 320.0
	sleep_vbox.offset_top = -110.0
	sleep_vbox.offset_bottom = 110.0
	sleep_vbox.add_theme_constant_override("separation", 18)
	_sleep_overlay.add_child(sleep_vbox)

	_sleep_caption = Label.new()
	_sleep_caption.text = "Юмик уснул от эйфории...\nТемный Бог (> _ <) убаюкивает и няшит его во сне (+8 игровых часов)"
	_sleep_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sleep_caption.add_theme_font_size_override("font_size", 24)
	_sleep_caption.modulate = Color(1.0, 0.86, 0.94)
	sleep_vbox.add_child(_sleep_caption)

	var skip_btn := _make_touch_button("Пропустить сцену сна (Проснуться через 8 часов)", Vector2(420, 56), Color(0.56, 0.14, 0.30, 0.96))
	skip_btn.pressed.connect(func():
		AudioManager.play_2d("ui_tap")
		GameState.skip_sleep_requested.emit()
	)
	sleep_vbox.add_child(skip_btn)


func _on_camera_zone_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _cam_touch_id == -1 and event.index != joystick.get_touch_index():
			_cam_touch_id = event.index
		elif not event.pressed and event.index == _cam_touch_id:
			_cam_touch_id = -1
	elif event is InputEventScreenDrag:
		if event.index == _cam_touch_id and is_instance_valid(player_ref):
			player_ref.rotate_camera_from_touch_drag(event.relative)


func _on_joystick_updated(dir: Vector2, running: bool) -> void:
	if is_instance_valid(player_ref):
		player_ref.move_input = dir
		player_ref.is_running_gait = running

	# Spec: While running, Jump button dynamically changes to "Припрыжку"!
	if running and dir.length() > 0.15:
		_btn_jump.text = "Припрыжку"
		_gait_badge.text = "Джойстик: БЕГ (за пределами кольца)"
		_gait_badge.modulate = Color(1.0, 0.72, 0.32)
	elif dir.length() > 0.05:
		_btn_jump.text = "Прыжок"
		_gait_badge.text = "Джойстик: ШАГ (в пределах кольца)"
		_gait_badge.modulate = Color(0.75, 0.98, 0.85)
	else:
		_btn_jump.text = "Прыжок"
		_gait_badge.text = "Джойстик: Покой (внутри — Шаг, снаружи — Бег)"
		_gait_badge.modulate = Color(0.88, 0.85, 0.96)


func _on_hold_me_changed(active: bool) -> void:
	_btn_dont_let_go.text = "Не отпускай меня [ВКЛ]" if active else "Не отпускай меня"


func _on_hug_changed(active: bool) -> void:
	_btn_hug.text = "Тискать [ВКЛ]" if active else "Тискать"


func _on_hem_changed(active: bool) -> void:
	_btn_lift_hem.text = "Опустить подол" if active else "Задрать подол"


func _on_maid_outfit_changed(equipped: bool) -> void:
	_btn_lift_hem.visible = equipped
	if not equipped:
		_btn_lift_hem.text = "Задрать подол"


func _on_nyash_progress(game_minutes: float, exhausted: bool) -> void:
	_nyash_box.visible = game_minutes > 0.05
	_nyash_bar.value = game_minutes
	_nyash_bar.tooltip_text = "%.1f / 20.0 мин" % game_minutes
	_nyash_bar.modulate = Color(1.0, 0.42, 0.58) if exhausted else Color(0.95, 0.72, 0.86)


func _on_sleep_cutscene_changed(active: bool) -> void:
	_sleep_overlay.visible = active


func _show_toast(msg: String) -> void:
	_toast_label.text = msg
	_toast_label.modulate.a = 1.0
	_toast_timer = 3.6


func _process(delta: float) -> void:
	if _toast_timer > 0.0:
		_toast_timer -= delta
		if _toast_timer < 0.8:
			_toast_label.modulate.a = maxf(_toast_timer / 0.8, 0.0)

	if is_instance_valid(player_ref) and is_instance_valid(castle_ref) and biome_gen_ref != null:
		var px: float = player_ref.global_position.x
		var pz: float = player_ref.global_position.z
		var biome_str: String = biome_gen_ref.get_biome_name_ru(biome_gen_ref.get_biome(px, pz))
		var st_str: String = GameState.get_castle_state_name(castle_ref.current_state)
		var dist_castle: float = player_ref.global_position.distance_to(castle_ref.global_position)
		_telemetry_label.text = "Время: %s  |  Мир: %d×%d км (Seed %s)  |  Зона: %s  |  НЗТБНЗ: %s (%02d:%02d) • %.0f м  |  Ветер: %.0f км/ч" % [
			GameState.get_formatted_time(),
			GameState.world_size_km,
			GameState.world_size_km,
			GameState.world_seed_text,
			biome_str,
			st_str,
			int(castle_ref.state_timer) / 60,
			int(castle_ref.state_timer) % 60,
			dist_castle,
			WindManager.current_speed_kmh,
		]
