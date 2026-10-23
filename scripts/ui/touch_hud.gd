extends CanvasLayer
class_name TouchHUD

## Complete Android multi-touch HUD:
## - Left side: Virtual Joystick (inside ring = Walk, outside ring = Run)
## - Right side: Swipe Camera + Action Buttons:
##   «Лечь», «На четвереньки», «Вскарабкаться», «Прыжок»/«Припрыжку», «Тискать», «Задрать подол»
## - Top-left corner: «Не отпускай меня», «Меню отладки»
## - Debug Menu panel: Castle states, Teleport to castle, Skip sleep cutscene, 5 Wind presets!

var player: YumikController = null

var virtual_joystick: VirtualJoystick
var swipe_zone: CameraSwipeZone

var btn_hold_me: Button
var btn_debug_menu: Button
var debug_panel: PanelContainer

var btn_lie: Button
var btn_all_fours: Button
var btn_climb: Button
var btn_jump: Button
var btn_cuddle: Button
var btn_lift_hem: Button

var status_label: Label
var banner_label: Label
var sleep_overlay: ColorRect
var sleep_info_label: Label
var sleep_real_timer: float = 0.0
const SLEEP_CUTSCENE_REAL_DURATION: float = 24.0 # Skip button available anytime!


func _ready() -> void:
	layer = 10
	_build_touch_interface()

	GameState.maid_outfit_changed.connect(_on_maid_outfit_changed)
	GameState.maid_hem_changed.connect(_on_maid_hem_changed)
	GameState.hold_me_changed.connect(_on_hold_me_changed)
	GameState.sleep_cutscene_started.connect(_on_sleep_started)
	GameState.sleep_cutscene_finished.connect(_on_sleep_finished)


func bind_player(p: YumikController) -> void:
	player = p
	virtual_joystick.joystick_updated.connect(player.set_joystick_input)
	swipe_zone.camera_swiped.connect(player.rotate_camera_by_swipe)
	player.running_changed.connect(_on_player_running_changed)
	player.climbing_changed.connect(_on_player_climbing_changed)
	player.cuddling_changed.connect(_on_player_cuddling_changed)
	player.death_state_changed.connect(_on_player_death_changed)


func _build_touch_interface() -> void:
	var root := Control.new()
	root.name = "TouchRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# 1. Right-half Swipe Camera Zone
	swipe_zone = CameraSwipeZone.new()
	swipe_zone.name = "CameraSwipeZone"
	swipe_zone.anchor_left = 0.44
	swipe_zone.anchor_top = 0.0
	swipe_zone.anchor_right = 1.0
	swipe_zone.anchor_bottom = 1.0
	root.add_child(swipe_zone)

	# 2. Left-side Virtual Joystick
	virtual_joystick = VirtualJoystick.new()
	virtual_joystick.name = "VirtualJoystick"
	virtual_joystick.anchor_left = 0.0
	virtual_joystick.anchor_top = 0.40
	virtual_joystick.anchor_right = 0.36
	virtual_joystick.anchor_bottom = 1.0
	root.add_child(virtual_joystick)

	# 3. Top-Left Corner Buttons: «Не отпускай меня» & «Меню отладки»
	var top_left_bar := HBoxContainer.new()
	top_left_bar.position = Vector2(24.0, 20.0)
	top_left_bar.add_theme_constant_override("separation", 14)
	root.add_child(top_left_bar)

	btn_hold_me = _make_touch_button("Не отпускай меня", Vector2(240, 66), Color(0.55, 0.10, 0.24, 0.88))
	btn_hold_me.pressed.connect(func() -> void:
		GameState.set_hold_me(not GameState.hold_me_active)
	)
	top_left_bar.add_child(btn_hold_me)

	btn_debug_menu = _make_touch_button("Меню отладки", Vector2(210, 66), Color(0.18, 0.22, 0.36, 0.88))
	btn_debug_menu.pressed.connect(func() -> void:
		debug_panel.visible = not debug_panel.visible
	)
	top_left_bar.add_child(btn_debug_menu)

	# 4. Top-Center Status Telemetry HUD
	var status_panel := PanelContainer.new()
	status_panel.anchor_left = 0.30
	status_panel.anchor_right = 0.72
	status_panel.offset_top = 18.0
	status_panel.offset_bottom = 86.0
	status_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sp_style := StyleBoxFlat.new()
	sp_style.bg_color = Color(0.06, 0.05, 0.11, 0.74)
	sp_style.corner_radius_top_left = 12
	sp_style.corner_radius_top_right = 12
	sp_style.corner_radius_bottom_left = 12
	sp_style.corner_radius_bottom_right = 12
	sp_style.content_margin_left = 16
	sp_style.content_margin_right = 16
	sp_style.content_margin_top = 8
	sp_style.content_margin_bottom = 8
	status_panel.add_theme_stylebox_override("panel", sp_style)
	root.add_child(status_panel)

	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 19)
	status_panel.add_child(status_label)

	# 5. Center Notification / Resurrection Banner
	banner_label = Label.new()
	banner_label.anchor_left = 0.25
	banner_label.anchor_right = 0.75
	banner_label.offset_top = 104.0
	banner_label.offset_bottom = 164.0
	banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_label.add_theme_font_size_override("font_size", 26)
	banner_label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.88))
	banner_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(banner_label)

	# 6. Right-Side Touch Action Buttons Cluster
	var right_col := GridContainer.new()
	right_col.columns = 2
	right_col.anchor_left = 1.0
	right_col.anchor_top = 1.0
	right_col.anchor_right = 1.0
	right_col.anchor_bottom = 1.0
	right_col.offset_left = -450.0
	right_col.offset_top = -340.0
	right_col.offset_right = -26.0
	right_col.offset_bottom = -26.0
	right_col.add_theme_constant_override("h_separation", 14)
	right_col.add_theme_constant_override("v_separation", 14)
	root.add_child(right_col)

	btn_lie = _make_touch_button("Лечь", Vector2(202, 88), Color(0.18, 0.20, 0.32, 0.86))
	btn_lie.pressed.connect(func() -> void:
		if player:
			player.toggle_lie_down()
	)
	right_col.add_child(btn_lie)

	btn_all_fours = _make_touch_button("На четвереньки", Vector2(202, 88), Color(0.18, 0.20, 0.32, 0.86))
	btn_all_fours.pressed.connect(func() -> void:
		if player:
			player.toggle_all_fours()
	)
	right_col.add_child(btn_all_fours)

	btn_climb = _make_touch_button("Вскарабкаться", Vector2(202, 88), Color(0.24, 0.30, 0.22, 0.88))
	btn_climb.pressed.connect(func() -> void:
		if player:
			player.toggle_climb()
	)
	right_col.add_child(btn_climb)

	btn_jump = _make_touch_button("Прыжок", Vector2(202, 88), Color(0.68, 0.14, 0.32, 0.92))
	btn_jump.pressed.connect(func() -> void:
		if player:
			player.trigger_jump()
	)
	right_col.add_child(btn_jump)

	btn_cuddle = _make_touch_button("Тискать", Vector2(202, 88), Color(0.62, 0.16, 0.44, 0.90))
	btn_cuddle.pressed.connect(func() -> void:
		if player:
			player.toggle_cuddle()
	)
	right_col.add_child(btn_cuddle)

	btn_lift_hem = _make_touch_button("Задрать подол", Vector2(202, 88), Color(0.82, 0.36, 0.58, 0.92))
	btn_lift_hem.visible = false # Shown ONLY when wearing Maid Outfit!
	btn_lift_hem.pressed.connect(func() -> void:
		GameState.toggle_maid_hem()
	)
	right_col.add_child(btn_lift_hem)

	# 7. Debug Panel («Меню отладки»)
	_build_debug_panel(root)

	# 8. 8-Hour Euphoria Sleep Nyashing Cutscene Overlay
	_build_sleep_cutscene_overlay(root)


func _build_debug_panel(root: Control) -> void:
	debug_panel = PanelContainer.new()
	debug_panel.name = "DebugMenuPanel"
	debug_panel.position = Vector2(24.0, 98.0)
	debug_panel.custom_minimum_size = Vector2(470.0, 0.0)
	debug_panel.visible = false

	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.08, 0.07, 0.15, 0.94)
	st.border_color = Color(0.85, 0.25, 0.45, 0.85)
	st.set_border_width_all(2)
	st.set_corner_radius_all(14)
	st.content_margin_left = 16
	st.content_margin_right = 16
	st.content_margin_top = 14
	st.content_margin_bottom = 14
	debug_panel.add_theme_stylebox_override("panel", st)
	root.add_child(debug_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	debug_panel.add_child(vbox)

	var hdr := Label.new()
	hdr.text = "МЕНЮ ОТЛАДКИ (НЗТБНЗ и Ветер)"
	hdr.add_theme_font_size_override("font_size", 20)
	hdr.add_theme_color_override("font_color", Color(1.0, 0.65, 0.78))
	vbox.add_child(hdr)

	var state_row := HBoxContainer.new()
	state_row.add_theme_constant_override("separation", 8)
	vbox.add_child(state_row)
	for pair in [
		["Обычное", GameState.CastleState.NORMAL],
		["Всасывание", GameState.CastleState.SUCTION],
		["Летающее", GameState.CastleState.FLYING],
	]:
		var b := _make_touch_button(pair[0], Vector2(138, 48), Color(0.45, 0.10, 0.22, 0.92))
		var target_st: int = pair[1]
		b.pressed.connect(func() -> void:
			GameState.request_debug_castle_state(target_st)
		)
		state_row.add_child(b)

	var util_row := HBoxContainer.new()
	util_row.add_theme_constant_override("separation", 8)
	vbox.add_child(util_row)

	var tp_btn := _make_touch_button("Телепорт к замку", Vector2(215, 48), Color(0.18, 0.34, 0.48, 0.92))
	tp_btn.pressed.connect(func() -> void:
		GameState.teleport_to_castle_requested.emit()
	)
	util_row.add_child(tp_btn)

	var skip_btn := _make_touch_button("Пропустить сон", Vector2(215, 48), Color(0.38, 0.24, 0.52, 0.92))
	skip_btn.pressed.connect(func() -> void:
		GameState.finish_euphoria_sleep_cutscene()
	)
	util_row.add_child(skip_btn)

	var wind_lbl := Label.new()
	wind_lbl.text = "Искусственный ветер (случ. направление, 3 мин):"
	wind_lbl.add_theme_font_size_override("font_size", 17)
	vbox.add_child(wind_lbl)

	var wind_grid := GridContainer.new()
	wind_grid.columns = 2
	wind_grid.add_theme_constant_override("h_separation", 8)
	wind_grid.add_theme_constant_override("v_separation", 8)
	vbox.add_child(wind_grid)

	var wind_presets := [
		["Штиль (1 км/ч)", 1.0, false],
		["Слабый ветер (15 км/ч)", 15.0, false],
		["Свежий ветер (35 км/ч)", 35.0, false],
		["Очень крепкий (70 км/ч)", 70.0, false],
		["Ураган (120 км/ч)", 120.0, true],
	]
	for wp in wind_presets:
		var wb := _make_touch_button(wp[0], Vector2(215, 48), Color(0.16, 0.28, 0.38, 0.92) if not wp[2] else Color(0.68, 0.18, 0.16, 0.95))
		var spd: float = wp[1]
		var lbl_txt: String = wp[0]
		var is_hurr: bool = wp[2]
		wb.pressed.connect(func() -> void:
			WindManager.set_artificial_wind_kmh(spd, lbl_txt, is_hurr)
		)
		wind_grid.add_child(wb)

	var menu_btn := _make_touch_button("В главное меню", Vector2(215, 48), Color(0.26, 0.22, 0.28, 0.92))
	menu_btn.pressed.connect(func() -> void:
		GameState.in_gameplay = false
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	)
	wind_grid.add_child(menu_btn)


func _build_sleep_cutscene_overlay(root: Control) -> void:
	sleep_overlay = ColorRect.new()
	sleep_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	sleep_overlay.color = Color(0.14, 0.04, 0.16, 0.52)
	sleep_overlay.visible = false
	root.add_child(sleep_overlay)

	var center_box := VBoxContainer.new()
	center_box.anchor_left = 0.22
	center_box.anchor_right = 0.78
	center_box.anchor_top = 0.68
	center_box.anchor_bottom = 0.92
	center_box.add_theme_constant_override("separation", 14)
	sleep_overlay.add_child(center_box)

	sleep_info_label = Label.new()
	sleep_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sleep_info_label.add_theme_font_size_override("font_size", 25)
	sleep_info_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.94))
	sleep_info_label.text = "Катсцена сна от эйфории (> _ <)\nТемный Бог нежно няшит спящего Юмика на мягком полу замка..."
	center_box.add_child(sleep_info_label)

	var skip_sleep_btn := _make_touch_button("Пропустить сцену сна (+8 игровых часов)", Vector2(460, 64), Color(0.65, 0.16, 0.38, 0.95))
	skip_sleep_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	skip_sleep_btn.pressed.connect(func() -> void:
		GameState.finish_euphoria_sleep_cutscene()
	)
	center_box.add_child(skip_sleep_btn)


func _make_touch_button(txt: String, min_sz: Vector2, bg: Color) -> Button:
	var b := Button.new()
	b.text = txt
	b.custom_minimum_size = min_sz
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 18)

	var normal_sb := StyleBoxFlat.new()
	normal_sb.bg_color = bg
	normal_sb.border_color = Color(1.0, 0.82, 0.90, 0.45)
	normal_sb.set_border_width_all(2)
	normal_sb.set_corner_radius_all(12)
	b.add_theme_stylebox_override("normal", normal_sb)

	var hover_sb := normal_sb.duplicate() as StyleBoxFlat
	hover_sb.bg_color = bg.lightened(0.14)
	b.add_theme_stylebox_override("hover", hover_sb)

	var pressed_sb := normal_sb.duplicate() as StyleBoxFlat
	pressed_sb.bg_color = bg.lightened(0.28)
	pressed_sb.border_color = Color(1.0, 0.95, 1.0, 0.95)
	b.add_theme_stylebox_override("pressed", pressed_sb)
	return b


func _on_player_running_changed(running: bool) -> void:
	btn_jump.text = "Припрыжку" if running else "Прыжок"


func _on_player_climbing_changed(climbing: bool) -> void:
	btn_climb.text = "Отпустить" if climbing else "Вскарабкаться"


func _on_player_cuddling_changed(cuddling: bool) -> void:
	btn_cuddle.text = "Тискать [ВКЛ]" if cuddling else "Тискать"


func _on_maid_outfit_changed(equipped: bool) -> void:
	btn_lift_hem.visible = equipped


func _on_maid_hem_changed(lifted: bool) -> void:
	btn_lift_hem.text = "Опустить подол" if lifted else "Задрать подол"


func _on_hold_me_changed(active: bool) -> void:
	btn_hold_me.text = "Не отпускай [ВКЛ]" if active else "Не отпускай меня"


func _on_player_death_changed(dead: bool, timer_s: float) -> void:
	if dead:
		banner_label.text = "Юмик погиб! Воскрешение через %.1f сек (в радиусе 10 м)..." % timer_s
	else:
		banner_label.text = ""


func _on_sleep_started() -> void:
	sleep_real_timer = SLEEP_CUTSCENE_REAL_DURATION
	sleep_overlay.visible = true


func _on_sleep_finished() -> void:
	sleep_overlay.visible = false
	banner_label.text = ""


func _process(delta: float) -> void:
	if GameState.is_sleeping_cutscene:
		sleep_real_timer -= delta
		sleep_info_label.text = "Катсцена сна от эйфории (> _ <) — Няшинг во сне!\nПробуждение через %.0f сек (или нажмите «Пропустить»)" % maxf(0.0, sleep_real_timer)
		if sleep_real_timer <= 0.0:
			GameState.finish_euphoria_sleep_cutscene()

	var castle_timer_m: int = int(GameState.castle_state_timer_sec) / 60
	var castle_timer_s: int = int(GameState.castle_state_timer_sec) % 60
	var wind_kmh: float = WindManager.get_current_speed_kmh()
	var extra_tags: String = ""
	if GameState.is_exhausted:
		extra_tags += " | ИСТОЩЕН"
	if GameState.nyashing_active:
		extra_tags += " | НЯШИНГ (%.1f/20 мин)" % GameState.nyashing_unresisted_game_minutes
	if player and player.is_ragdoll:
		extra_tags += " | RAGDOLL (%s)" % player.ragdoll_reason

	status_label.text = "Время: %s | Мир: %d×%d км (Seed %d) | НЗТБНЗ: %s (%02d:%02d)\nВетер: %.0f км/ч (%s)%s" % [
		GameState.get_formatted_clock(),
		GameState.world_size_km,
		GameState.world_size_km,
		GameState.world_seed,
		GameState.get_castle_state_name_ru(),
		castle_timer_m,
		castle_timer_s,
		wind_kmh,
		WindManager.artificial_preset_name,
		extra_tags
	]
