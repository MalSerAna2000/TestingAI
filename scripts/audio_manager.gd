extends Node
class_name AudioManager

# ----------------------------------------------------------------
# Аудио-менеджер (автозагрузка). Все ассеты — Ogg Vorbis (.ogg).
# ----------------------------------------------------------------

var streams: Dictionary = {}

func _ready() -> void:
	var paths = [
		"res://assets/audio/ambient_wind.ogg",
		"res://assets/audio/ambient_night.ogg",
		"res://assets/audio/ambient_water.ogg",
		"res://assets/audio/music_menu.ogg",
		"res://assets/audio/music_game.ogg",
		"res://assets/audio/step_grass.ogg",
		"res://assets/audio/step_stone.ogg",
		"res://assets/audio/step_pvc.ogg",
		"res://assets/audio/jump.ogg",
		"res://assets/audio/land.ogg",
		"res://assets/audio/pvc_squeak.ogg",
		"res://assets/audio/wind_suck.ogg",
		"res://assets/audio/wing_flap.ogg",
		"res://assets/audio/yumik_hurt.ogg",
		"res://assets/audio/yumik_euphoria.ogg",
		"res://assets/audio/darkgod_laugh.ogg",
		"res://assets/audio/darkgod_purr.ogg",
		"res://assets/audio/gate_close.ogg",
	]
	for p in paths:
		var res = load(p)
		if res:
			streams[p] = res

func _get(path: String) -> AudioStream:
	var res = streams.get(path)
	if not res:
		res = load(path)
		streams[path] = res
	return res

# Фоновая музыка / амбиент (циклично)
func play_ambient(path: String, volume_db: float = 0.0, bus: String = "Master") -> AudioStreamPlayer3D:
	var player = AudioStreamPlayer3D.new()
	player.stream = _get(path)
	player.loop = true
	player.autoplay = true
	player.volume_db = volume_db
	player.bus = bus
	player.play()
	add_child(player)
	return player

# Одноразовый звуковой эффект (3D, позиция опционально)
func play_sfx(path: String, position: Vector3 = Vector3(0, 0, 0), volume_db: float = 0.0, bus: String = "Master") -> AudioStreamPlayer3D:
	var player = AudioStreamPlayer3D.new()
	player.stream = _get(path)
	player.loop = false
	player.global_position = position
	player.volume_db = volume_db
	player.bus = bus
	player.play()
	player.finished.connect(player.queue_free)
	add_child(player)
	return player

func play_voice(path: String, volume_db: float = 0.0) -> AudioStreamPlayer3D:
	return play_sfx(path, Vector3(0, 0, 0), volume_db, bus="Master")
