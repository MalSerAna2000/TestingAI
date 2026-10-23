class_name DebugMenuPanel
extends PanelContainer
## Touch-friendly Floating Debug Panel ("Меню отладки"):
## - Switch НЗТБНЗ states: "Обычное", "Всасывание", "Летающее"
## - Teleport to Castle (exterior & interior hall)
## - Skip Sleep Scene ("Пропустить сцену сна")
## - Artificial Wind Controls (random direction, 3 real minutes each):
##   * Штиль (1 км/ч)
##   * Слабый ветер (15 км/ч)
##   * Свежий ветер (35 км/ч)
##   * Очень крепкий ветер (70 км/ч)
##   * Ураган (120 км/ч) — spawns Hurricane Vortex 250m from Yumik!

var castle_ref: InflatableCastle
var player_ref: YumikController
var _wind_status_label: Label
var _aero_btn: Button


func _ready() -> void:
	_build_debug_panel()
	WindManager.wind_changed.connect(_on_wind_changed)


func _make_btn(label_text: String, cb: Callable, bg := Color(0.18, 0.11, 0.22, 0.95)) -> Button:
	var b := Button.new()
	b.text = label_text
	b.custom_minimum_size = Vector2(215, 44)
	b.add_theme_font_size_override("font_size", 15)
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = Color(0.75, 0.35, 0.52, 0.9)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	b.add_theme_stylebox_override("normal", sb)
	var sbh := sb.duplicate()
	sbh.bg_color = bg.lightened(0.14)
	b.add_theme_stylebox_override("hover", sbh)
	var sbp := sb.duplicate()
	sbp.bg_color = bg.lightened(0.28)
	b.add_theme_stylebox_override("pressed", sbp)
	b.pressed.connect(func():
		AudioManager.play_2d("ui_tap")
		cb.call()
	)
	return b


func _build_debug_panel() -> void:
	var panel_sb := StyleBoxFlat.new()
	panel_sb.bg_color = Color(0.08, 0.05, 0.11, 0.94)
	panel_sb.border_color = Color(0.90, 0.30, 0.48, 0.95)
	panel_sb.set_border_width_all(2)
	panel_sb.set_corner_radius_all(14)
	panel_sb.set_content_margin_all(14)
	add_theme_stylebox_override("panel", panel_sb)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(470, 470)
	add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(vbox)

	var hdr := HBoxContainer.new()
	vbox.add_child(hdr)
	var title := Label.new()
	title.text = "МЕНЮ ОТЛАДКИ НЗТБНЗ"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 19)
	title.modulate = Color(1.0, 0.78, 0.88)
	hdr.add_child(title)
	hdr.add_child(_make_btn("Закрыть ✕", func(): visible = false, Color(0.45, 0.12, 0.20)))

	# 1. Castle State Controls
	var s_lbl := Label.new()
	s_lbl.text = "1. Состояние Надувного Замка (НЗТБНЗ):"
	s_lbl.modulate = Color(0.92, 0.82, 1.0)
	vbox.add_child(s_lbl)

	var state_grid := GridContainer.new()
	state_grid.columns = 3
	state_grid.add_theme_constant_override("h_separation", 8)
	vbox.add_child(state_grid)
	state_grid.add_child(_make_btn("Обычное", func(): GameState.castle_state_requested.emit(GameState.CastleState.NORMAL)))
	state_grid.add_child(_make_btn("Всасывание", func(): GameState.castle_state_requested.emit(GameState.CastleState.SUCTION), Color(0.42, 0.12, 0.28)))
	state_grid.add_child(_make_btn("Летающее", func(): GameState.castle_state_requested.emit(GameState.CastleState.FLYING), Color(0.22, 0.16, 0.44)))

	# 2. Teleport, Sleep Skip & Developer Helpers
	var t_lbl := Label.new()
	t_lbl.text = "2. Навигация, Сон и Инструменты:"
	t_lbl.modulate = Color(0.92, 0.82, 1.0)
	vbox.add_child(t_lbl)

	var util_grid := GridContainer.new()
	util_grid.columns = 2
	util_grid.add_theme_constant_override("h_separation", 8)
	util_grid.add_theme_constant_override("v_separation", 8)
	vbox.add_child(util_grid)

	util_grid.add_child(_make_btn("Телепорт к замку", func(): GameState.teleport_to_castle_requested.emit(false)))
	util_grid.add_child(_make_btn("Телепорт внутрь зала", func(): GameState.teleport_to_castle_requested.emit(true)))
	util_grid.add_child(_make_btn("Пропустить сцену сна", func(): GameState.skip_sleep_requested.emit(), Color(0.38, 0.20, 0.12)))
	util_grid.add_child(_make_btn("Комплект горничной", func():
		if is_instance_valid(player_ref):
			player_ref.toggle_maid_outfit_from_wardrobe()
	))

	_aero_btn = _make_btn("Аэро-векторы AeroBody3D: ВЫКЛ", _toggle_aero_vectors)
	util_grid.add_child(_aero_btn)
	util_grid.add_child(_make_btn("+3 часа суток", func(): GameState.advance_game_hours(3.0)))

	# 3. Wind Controls (3 minutes each, random direction, Hurricane at 250m!)
	var w_lbl := Label.new()
	w_lbl.text = "3. Управление ветром (случайное направление • 3 минуты):"
	w_lbl.modulate = Color(0.92, 0.82, 1.0)
	vbox.add_child(w_lbl)

	_wind_status_label = Label.new()
	_wind_status_label.text = "Активный ветер: Естественный"
	_wind_status_label.add_theme_font_size_override("font_size", 14)
	_wind_status_label.modulate = Color(0.72, 0.94, 1.0)
	vbox.add_child(_wind_status_label)

	var wind_grid := GridContainer.new()
	wind_grid.columns = 2
	wind_grid.add_theme_constant_override("h_separation", 8)
	wind_grid.add_theme_constant_override("v_separation", 8)
	vbox.add_child(wind_grid)

	wind_grid.add_child(_make_btn("Штиль (1 км/ч)", func(): WindManager.set_artificial_wind(WindManager.WindPreset.CALM)))
	wind_grid.add_child(_make_btn("Слабый ветер (15 км/ч)", func(): WindManager.set_artificial_wind(WindManager.WindPreset.LIGHT)))
	wind_grid.add_child(_make_btn("Свежий ветер (35 км/ч)", func(): WindManager.set_artificial_wind(WindManager.WindPreset.FRESH)))
	wind_grid.add_child(_make_btn("Очень крепкий ветер (70 км/ч)", func(): WindManager.set_artificial_wind(WindManager.WindPreset.VERY_STRONG), Color(0.32, 0.20, 0.14)))
	wind_grid.add_child(_make_btn("Ураган (120 км/ч • 250 м)", func(): WindManager.set_artificial_wind(WindManager.WindPreset.HURRICANE), Color(0.55, 0.10, 0.16)))
	wind_grid.add_child(_make_btn("Главное меню", func(): get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")))


func _toggle_aero_vectors() -> void:
	GameState.aero_debug_vectors_enabled = not GameState.aero_debug_vectors_enabled
	if is_instance_valid(castle_ref):
		castle_ref.show_debug = GameState.aero_debug_vectors_enabled
	_aero_btn.text = "Аэро-векторы AeroBody3D: %s" % ("ВКЛ" if GameState.aero_debug_vectors_enabled else "ВЫКЛ")


func _on_wind_changed(label: String, speed_kmh: float, _dir: Vector3, rem_sec: float) -> void:
	if not is_instance_valid(_wind_status_label):
		return
	if rem_sec > 0.0:
		_wind_status_label.text = "Активный: %s [%.0f км/ч] — осталось %02d:%02d" % [label, speed_kmh, int(rem_sec) / 60, int(rem_sec) % 60]
	else:
		_wind_status_label.text = "Активный: %s [%.1f км/ч]" % [label, speed_kmh]
