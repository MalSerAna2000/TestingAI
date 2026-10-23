extends Control
class_name MainMenu

## Start menu with touch controls:
## - World size selection: 1x1 km, 10x10 km, 50x50 km
## - Seed input + random/preset touch buttons (no hardware keyboard required)
## - Start button launching Valley at 22:00 night, 50m from NZTBNZ!

var selected_size_km: int = 1
var size_buttons: Dictionary = {}
var seed_edit: LineEdit


func _ready() -> void:
	GameState.in_gameplay = false
	AudioManager.start_menu_audio()
	_build_menu_ui()


func _build_menu_ui() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.05, 0.04, 0.10, 1.0)
	add_child(bg)

	var card := PanelContainer.new()
	card.anchor_left = 0.18
	card.anchor_right = 0.82
	card.anchor_top = 0.10
	card.anchor_bottom = 0.90
	var card_sb := StyleBoxFlat.new()
	card_sb.bg_color = Color(0.10, 0.07, 0.17, 0.96)
	card_sb.border_color = Color(0.86, 0.22, 0.44, 0.90)
	card_sb.set_border_width_all(3)
	card_sb.set_corner_radius_all(22)
	card_sb.content_margin_left = 42
	card_sb.content_margin_right = 42
	card_sb.content_margin_top = 34
	card_sb.content_margin_bottom = 34
	card.add_theme_stylebox_override("panel", card_sb)
	add_child(card)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 22)
	card.add_child(vbox)

	var title := Label.new()
	title.text = "ТЕМНЫЙ БОГ НАДУВНЫХ ЗАМКОВ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(1.0, 0.72, 0.84))
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Godot Engine 4.7.2 · Jolt Physics · Godot Aerodynamic Physics 0.9.1 · Android Touch"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 19)
	subtitle.add_theme_color_override("font_color", Color(0.75, 0.78, 0.92))
	vbox.add_child(subtitle)

	# World Size Selector (1x1 km, 10x10 km, 50x50 km)
	var size_lbl := Label.new()
	size_lbl.text = "Выберите размер процедурной долины:"
	size_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	size_lbl.add_theme_font_size_override("font_size", 24)
	vbox.add_child(size_lbl)

	var size_row := HBoxContainer.new()
	size_row.alignment = BoxContainer.ALIGNMENT_CENTER
	size_row.add_theme_constant_override("separation", 20)
	vbox.add_child(size_row)

	for km in [1, 10, 50]:
		var btn := _create_styled_button("%d × %d км" % [km, km], Vector2(240, 74), Color(0.22, 0.16, 0.34))
		var target_km: int = km
		btn.pressed.connect(func() -> void:
			_select_world_size(target_km)
		)
		size_row.add_child(btn)
		size_buttons[km] = btn

	# Seed Selector
	var seed_lbl := Label.new()
	seed_lbl.text = "Зерно генерации мира (Seed — Равнины, Водоемы, Горы):"
	seed_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	seed_lbl.add_theme_font_size_override("font_size", 24)
	vbox.add_child(seed_lbl)

	var seed_row := HBoxContainer.new()
	seed_row.alignment = BoxContainer.ALIGNMENT_CENTER
	seed_row.add_theme_constant_override("separation", 16)
	vbox.add_child(seed_row)

	seed_edit = LineEdit.new()
	seed_edit.text = str(GameState.world_seed)
	seed_edit.custom_minimum_size = Vector2(300, 66)
	seed_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	seed_edit.add_theme_font_size_override("font_size", 26)
	seed_row.add_child(seed_edit)

	var rnd_btn := _create_styled_button("Случайный Seed", Vector2(240, 66), Color(0.20, 0.34, 0.46))
	rnd_btn.pressed.connect(func() -> void:
		seed_edit.text = str(randi_range(100000, 999999))
	)
	seed_row.add_child(rnd_btn)

	var plus_btn := _create_styled_button("+1", Vector2(90, 66), Color(0.24, 0.24, 0.38))
	plus_btn.pressed.connect(func() -> void:
		seed_edit.text = str(int(seed_edit.text) + 1)
	)
	seed_row.add_child(plus_btn)

	# Start Button
	var start_btn := _create_styled_button("НАЧАТЬ ИГРУ (22:00 НОЧИ · 50 М ОТ НЗТБНЗ)", Vector2(680, 88), Color(0.74, 0.14, 0.34))
	start_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	start_btn.add_theme_font_size_override("font_size", 25)
	start_btn.pressed.connect(_on_start_pressed)
	vbox.add_child(start_btn)

	_select_world_size(1)


func _select_world_size(km: int) -> void:
	selected_size_km = km
	for k: int in size_buttons.keys():
		var b: Button = size_buttons[k]
		b.modulate = Color(1.25, 1.0, 1.15) if k == km else Color(0.75, 0.75, 0.82)


func _create_styled_button(txt: String, min_sz: Vector2, col: Color) -> Button:
	var b := Button.new()
	b.text = txt
	b.custom_minimum_size = min_sz
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 22)
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.border_color = Color(1.0, 0.78, 0.88, 0.65)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	b.add_theme_stylebox_override("normal", sb)
	var sb_p := sb.duplicate() as StyleBoxFlat
	sb_p.bg_color = col.lightened(0.22)
	b.add_theme_stylebox_override("pressed", sb_p)
	b.add_theme_stylebox_override("hover", sb_p)
	return b


func _on_start_pressed() -> void:
	var parsed_seed: int = seed_edit.text.to_int()
	if parsed_seed == 0 and seed_edit.text != "0":
		parsed_seed = abs(seed_edit.text.hash())
	GameState.reset_for_new_game(selected_size_km, parsed_seed)
	get_tree().change_scene_to_file("res://scenes/game_world.tscn")
