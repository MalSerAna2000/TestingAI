extends Control
## Android Touch-Friendly Start Menu:
## Configures World Size (1x1 km, 10x10 km, 50x50 km) and Procedural Generation Seed.

var _selected_km: int = 1
var _btn_1km: Button
var _btn_10km: Button
var _btn_50km: Button
var _seed_edit: LineEdit
var _status_lbl: Label


func _ready() -> void:
	GameState.is_in_game = false
	_build_menu_ui()
	_refresh_size_buttons()


func _make_styled_panel(bg_col: Color, border_col: Color, radius: int = 14) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_col
	sb.border_color = border_col
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	return sb


func _style_button(btn: Button, active: bool = false, accent: bool = false) -> void:
	var base := Color(0.56, 0.11, 0.24, 0.96) if (active or accent) else Color(0.14, 0.09, 0.17, 0.92)
	var border := Color(1.0, 0.52, 0.68, 1.0) if (active or accent) else Color(0.45, 0.25, 0.36, 0.85)
	btn.add_theme_stylebox_override("normal", _make_styled_panel(base, border, 12))
	btn.add_theme_stylebox_override("hover", _make_styled_panel(base.lightened(0.12), border, 12))
	btn.add_theme_stylebox_override("pressed", _make_styled_panel(base.lightened(0.24), Color(1.0, 0.82, 0.88), 12))
	btn.add_theme_font_size_override("font_size", 22 if accent else 19)
	btn.custom_minimum_size = Vector2(180, 58 if accent else 52)


func _build_menu_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.03, 0.08, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var stars_tex := TextureRect.new()
	stars_tex.texture = load("res://assets/textures/sky/night_stars_panorama.png")
	stars_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stars_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	stars_tex.modulate = Color(1.0, 0.72, 0.85, 0.42)
	stars_tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(stars_tex)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(820, 560)
	card.add_theme_stylebox_override("panel", _make_styled_panel(Color(0.09, 0.05, 0.12, 0.94), Color(0.78, 0.22, 0.40, 0.95), 20))
	center.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	card.add_child(vbox)

	var title := Label.new()
	title.text = "ТЕМНЫЙ БОГ НАДУВНЫХ ЗАМков"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.modulate = Color(1.0, 0.86, 0.92)
	vbox.add_child(title)

	var sub := Label.new()
	sub.text = "Godot Engine 4.7.2 • Jolt Physics • Aerodynamic Physics v0.9.1 • Mobile Touch"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 16)
	sub.modulate = Color(0.84, 0.62, 0.74)
	vbox.add_child(sub)

	var sep1 := HSeparator.new()
	vbox.add_child(sep1)

	# World Size Selection: 1x1 km, 10x10 km, 50x50 km
	var size_lbl := Label.new()
	size_lbl.text = "Размер процедурной долины (Равнины • Водоемы • Горы):"
	size_lbl.add_theme_font_size_override("font_size", 19)
	vbox.add_child(size_lbl)

	var size_row := HBoxContainer.new()
	size_row.alignment = BoxContainer.ALIGNMENT_CENTER
	size_row.add_theme_constant_override("separation", 18)
	vbox.add_child(size_row)

	_btn_1km = Button.new()
	_btn_1km.text = "1 × 1 км\n(Компактная долина)"
	_btn_1km.pressed.connect(func():
		AudioManager.play_2d("ui_tap")
		_selected_km = 1
		_refresh_size_buttons()
	)
	size_row.add_child(_btn_1km)

	_btn_10km = Button.new()
	_btn_10km.text = "10 × 10 км\n(Большая долина)"
	_btn_10km.pressed.connect(func():
		AudioManager.play_2d("ui_tap")
		_selected_km = 10
		_refresh_size_buttons()
	)
	size_row.add_child(_btn_10km)

	_btn_50km = Button.new()
	_btn_50km.text = "50 × 50 км\n(Гигантский мир)"
	_btn_50km.pressed.connect(func():
		AudioManager.play_2d("ui_tap")
		_selected_km = 50
		_refresh_size_buttons()
	)
	size_row.add_child(_btn_50km)

	# Seed input
	var seed_lbl := Label.new()
	seed_lbl.text = "Зерно генерации мира (Seed):"
	seed_lbl.add_theme_font_size_override("font_size", 19)
	vbox.add_child(seed_lbl)

	var seed_row := HBoxContainer.new()
	seed_row.add_theme_constant_override("separation", 14)
	vbox.add_child(seed_row)

	_seed_edit = LineEdit.new()
	_seed_edit.text = str(GameState.world_seed)
	_seed_edit.placeholder_text = "Введите число или строку Seed..."
	_seed_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_seed_edit.custom_minimum_size = Vector2(320, 50)
	_seed_edit.add_theme_font_size_override("font_size", 20)
	seed_row.add_child(_seed_edit)

	var rnd_btn := Button.new()
	rnd_btn.text = "Случайный Seed"
	_style_button(rnd_btn, false, false)
	rnd_btn.pressed.connect(func():
		AudioManager.play_2d("ui_tap")
		_seed_edit.text = str(randi_range(100000, 99999999))
	)
	seed_row.add_child(rnd_btn)

	var hint := Label.new()
	hint.text = "Старт в 22:00 ночи в 50 м от НЗТБНЗ • Слева: джойстик (внутри — шаг, за пределами — бег) • Справа: камера и действия"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 15)
	hint.modulate = Color(0.82, 0.80, 0.90)
	vbox.add_child(hint)

	_status_lbl = Label.new()
	_status_lbl.text = ""
	_status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_lbl.modulate = Color(1.0, 0.78, 0.45)
	vbox.add_child(_status_lbl)

	var start_btn := Button.new()
	start_btn.text = "ВОЙТИ В ДОЛИНУ (НАЧАТЬ ИГРУ)"
	_style_button(start_btn, true, true)
	start_btn.pressed.connect(_on_start_pressed)
	vbox.add_child(start_btn)


func _refresh_size_buttons() -> void:
	_style_button(_btn_1km, _selected_km == 1, false)
	_style_button(_btn_10km, _selected_km == 10, false)
	_style_button(_btn_50km, _selected_km == 50, false)


func _on_start_pressed() -> void:
	AudioManager.play_2d("ui_tap")
	_status_lbl.text = "Генерация долины %d×%d км (Seed: %s)..." % [_selected_km, _selected_km, _seed_edit.text]
	GameState.configure_new_game(_selected_km, _seed_edit.text)
	await get_tree().process_frame
	get_tree().change_scene_to_file("res://scenes/main/GameWorld.tscn")
