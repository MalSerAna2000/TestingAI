extends Control
class_name Hud

# HUD: состояние НЗТБНЗ, время суток, ветер.

@onready var _label: Label = get_node("Info")

var _state_names = ["Обычное", "Всасывание", "Летающее"]

func set_state(state: int) -> void:
	_update()

func set_time(hour: float) -> void:
	_update()

func set_wind(speed_kmh: float, direction: Vector2) -> void:
	_update()

func _update() -> void:
	var h = GameManager.time_of_day
	var h_i = int(h)
	var m_i = int((h - h_i) * 60)
	var wind_dir = "?"
	if GameManager.wind_direction.x > 0.3: wind_dir = "восток"
	elif GameManager.wind_direction.x < -0.3: wind_dir = "запад"
	elif GameManager.wind_direction.y > 0.3: wind_dir = "юг"
	elif GameManager.wind_direction.y < -0.3: wind_dir = "север"
	_label.text = "[НЗТБНЗ: %s] [%02d:%02d] [ветер %d км/ч %s]" % [
		_state_names[GameManager.state], h_i, m_i, int(GameManager.wind_speed_kmh), wind_dir]
