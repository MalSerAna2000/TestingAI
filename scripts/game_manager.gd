extends Node
class_name GameManager

# ----------------------------------------------------------------
# Синглтон управления игрой (автозагрузка).
# Состояния НЗТБНЗ, смена суток, ветер, настройки мира, ссылки.
# ----------------------------------------------------------------

signal state_changed(new_state: int)
signal wind_changed(speed_kmh: float, direction: Vector2)
signal time_changed(hour: float)
signal debug_toggled(open: bool)

enum CastleState { STATE_NORMAL = 0, STATE_SUCTION = 1, STATE_FLYING = 2 }

# --- настройки мира (выбираются в стартовом меню) -----------------
var world_size_km: float = 1.0   # 1.0 / 10.0 / 50.0
var seed: int = 12345

# --- состояние НЗТБНЗ (меняется каждые 60 игровых мин / 3 реал. мин) ---
var state: int = STATE_NORMAL
var state_timer: float = 0.0
var state_duration: float = 180.0

# --- смена суток ---------------------------------------------------
var time_of_day: float = 22.0      # старт в 22:00 ночи
var day_speed: float = 8.0         # игровых часов за реальную секунду

# --- ветер ---------------------------------------------------------
var wind_speed_kmh: float = 6.0
var wind_direction: Vector2 = Vector2(1.0, 0.0)

# --- ссылки (заполняются Main при старте) -------------------------
var main: Node
var player: Node3D
var castle: Node3D

var debug_menu_open: bool = false
var _hurricane_source: Node3D

func next_state() -> void:
	state = (state + 1) % 3
	state_timer = 0.0
	if castle and castle.has_method("set_state"):
		castle.set_state(state)
	state_changed.emit(state)
	AudioManager.play_sfx("res://assets/audio/wing_flap.ogg", volume_db=-6)

func set_wind_preset(kmh: float, duration_s: float = 180.0) -> void:
	wind_speed_kmh = kmh
	wind_direction = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
	wind_changed.emit(wind_speed_kmh, wind_direction)
	if kmh >= 120.0 and player:
		_spawn_hurricane_source(duration_s)
	var t = Timer.new()
	t.wait_time = duration_s
	t.one_shot = true
	t.timeout.connect(func(): _restore_natural_wind())
	add_child(t)
	t.start()

func _restore_natural_wind() -> void:
	wind_speed_kmh = clamp(wind_speed_kmh * 0.5, 1.0, 12.0)
	wind_direction = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
	wind_changed.emit(wind_speed_kmh, wind_direction)

func _spawn_hurricane_source(lifetime_s: float) -> void:
	# источник урагана в 250 метрах от игрока
	if _hurricane_source:
		_hurricane_source.queue_free()
	if not player:
		return
	var h = Node3D.new()
	h.name = "HurricaneSource"
	h.global_position = player.global_position + Vector3(wind_direction.x, 0, wind_direction.y) * 250.0
	var mesh = MeshInstance3D.new()
	mesh.mesh = SphereMesh.new()
	mesh.mesh.radius = 12.0
	var mat = SpatialMaterial.new()
	mat.albedo_color = Color(0.25, 0.25, 0.7, 0.5)
	mat.transparency = 1
	mesh.material_override = mat
	h.add_child(mesh)
	add_child(h)
	_hurricane_source = h
	var t = Timer.new()
	t.wait_time = lifetime_s
	t.one_shot = true
	t.timeout.connect(func(): _despawn_hurricane())
	add_child(t)
	t.start()

func _despawn_hurricane() -> void:
	if _hurricane_source:
		_hurricane_source.queue_free()
		_hurricane_source = null

func teleport_to_castle() -> void:
	if player and castle:
		player.global_position = castle.global_position + Vector3(0, 6, -14)

func state_name() -> String:
	var names = ["Обычное", "Всасывание", "Летающее"]
	return names[state]
