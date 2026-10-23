extends Node
class_name MainMenu

# ----------------------------------------------------------------
# Стартовое меню: выбор размера мира (1×1, 10×10, 50×50 км) и сида.
# ----------------------------------------------------------------

@onready var _edit_seed: LineEdit = get_node("CanvasLayer/EditSeed")
@onready var _btn_size_1: Button = get_node("CanvasLayer/BtnSize1")
@onready var _btn_size_10: Button = get_node("CanvasLayer/BtnSize10")
@onready var _btn_size_50: Button = get_node("CanvasLayer/BtnSize50")

var world_size: float = 1.0

func _ready() -> void:
	get_node("CanvasLayer/BtnNew").pressed.connect(_on_new)
	get_node("CanvasLayer/BtnExit").pressed.connect(_on_exit)
	_btn_size_1.pressed.connect(func(): _set_size(1.0))
	_btn_size_10.pressed.connect(func(): _set_size(10.0))
	_btn_size_50.pressed.connect(func(): _set_size(50.0))
	_set_size(1.0)
	AudioManager.play_ambient("res://assets/audio/music_menu.ogg", volume_db=-10)

func _set_size(size: float) -> void:
	world_size = size
	_btn_size_1.button_pressed = (size == 1.0)
	_btn_size_10.button_pressed = (size == 10.0)
	_btn_size_50.button_pressed = (size == 50.0)

func _on_new() -> void:
	GameManager.world_size_km = world_size
	if _edit_seed.text.is_valid_integer():
		GameManager.seed = int(_edit_seed.text)
	else:
		GameManager.seed = 12345
		_edit_seed.text = str(GameManager.seed)
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _on_exit() -> void:
	get_tree().quit()
