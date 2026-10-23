extends Node
class_name DebugMenu

# ----------------------------------------------------------------
# Меню отладки: переключение состояний НЗТБНЗ, телепортация, ветер.
# ----------------------------------------------------------------

@onready var _menu: CanvasLayer = get_node("CanvasLayer")

func _ready() -> void:
	_menu.visible = false
	GameManager.debug_toggled.connect(set_open)
	get_node("CanvasLayer/BtnStateN").pressed.connect(func(): _set_state(GameManager.STATE_NORMAL))
	get_node("CanvasLayer/BtnStateS").pressed.connect(func(): _set_state(GameManager.STATE_SUCTION))
	get_node("CanvasLayer/BtnStateF").pressed.connect(func(): _set_state(GameManager.STATE_FLYING))
	get_node("CanvasLayer/BtnTeleport").pressed.connect(GameManager.teleport_to_castle)
	get_node("CanvasLayer/BtnSkipSleep").pressed.connect(_skip_sleep)
	get_node("CanvasLayer/BtnClose").pressed.connect(func(): GameManager.debug_toggled.emit(false))
	get_node("CanvasLayer/BtnWind0").pressed.connect(func(): GameManager.set_wind_preset(1.0))
	get_node("CanvasLayer/BtnWind1").pressed.connect(func(): GameManager.set_wind_preset(15.0))
	get_node("CanvasLayer/BtnWind2").pressed.connect(func(): GameManager.set_wind_preset(35.0))
	get_node("CanvasLayer/BtnWind3").pressed.connect(func(): GameManager.set_wind_preset(70.0))
	get_node("CanvasLayer/BtnWind4").pressed.connect(func(): GameManager.set_wind_preset(120.0))

func set_open(open: bool) -> void:
	_menu.visible = open

func _set_state(state: int) -> void:
	GameManager.state = state
	GameManager.state_timer = 0.0
	if GameManager.castle and GameManager.castle.has_method("set_state"):
		GameManager.castle.set_state(state)
	GameManager.state_changed.emit(state)

func _skip_sleep() -> void:
	GameManager.time_of_day = 6.0
	AudioManager.play_sfx("res://assets/audio/darkgod_laugh.ogg", volume_db=-4)
