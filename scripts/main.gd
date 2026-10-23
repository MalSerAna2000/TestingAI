extends Node3D
class_name Main

# ----------------------------------------------------------------
# Главный игровой мир: связь игрока, замка, генератора чанков,
# смена суток, цикл состояний НЗТБНЗ, сенсорное управление.
# ----------------------------------------------------------------

@onready var terrain: Node3D = get_node("Terrain")
@onready var castle: CastleController = get_node("CastleRoot/Castle")
@onready var player: PlayerController = get_node("Player")
@onready var camera_pivot: Node3D = get_node("Player/CameraPivot")
@onready var cam: Camera3D = get_node("Player/CameraPivot/Camera")
@onready var sun: DirectionalLight3D = get_node("Sun")
@onready var env: WorldEnvironment = get_node("WorldEnv")
@onready var joystick: TouchJoystick = get_node("GUI/Joystick")
@onready var cam_area: TouchCamera = get_node("GUI/CameraArea")
@onready var hud: Hud = get_node("GUI/Hud")

var world_generator: WorldGenerator
var _camera_yaw: float = -90.0
var _camera_pitch: float = -15.0
var _wind_accum: float = 0.0
var _state_accum: float = 0.0

func _ready() -> void:
	GameManager.main = self
	GameManager.player = player
	GameManager.castle = castle
	player.main = self
	player.set_controls(joystick, cam_area)

	world_generator = WorldGenerator.new()
	add_child(world_generator)
	world_generator.init(
		seed=GameManager.seed,
		size_km=GameManager.world_size_km,
		terrain=terrain,
		chunk_scene=load("res://scenes/Chunk.tscn"),
	)

	# меню отладки
	var debug = load("res://scenes/DebugMenu.tscn").instantiate()
	add_child(debug)
	GameManager.debug_toggled.connect(debug.set_open)

	# ворота закрываются при входе внутрь (блокируются, кроме всасывания)
	get_node("CastleRoot/Castle/Entrance").body_entered.connect(_on_enter_castle)

	# аудио
	AudioManager.play_ambient("res://assets/audio/ambient_night.ogg", volume_db=-6)
	AudioManager.play_ambient("res://assets/audio/music_game.ogg", volume_db=-14)

	# камера за спиной игрока
	_camera_yaw = -90.0
	_update_camera()

	# сигналы HUD
	GameManager.state_changed.connect(hud.set_state)
	GameManager.wind_changed.connect(hud.set_wind)
	GameManager.time_changed.connect(hud.set_time)

	hud.set_state(GameManager.state)
	hud.set_time(GameManager.time_of_day)
	hud.set_wind(GameManager.wind_speed_kmh, GameManager.wind_direction)

	world_generator.update(player.global_position)

	# экранные кнопки -> действия игрока
	get_node("GUI/ButtonsRight/BtnLie").pressed.connect(player.lie_down)
	get_node("GUI/ButtonsRight/BtnCrawl").pressed.connect(player.crawl)
	get_node("GUI/ButtonsRight/BtnClimb").pressed.connect(player.climb)
	get_node("GUI/ButtonsRight/BtnJump").pressed.connect(player.jump_action)
	get_node("GUI/ButtonsRight/BtnSqueeze").pressed.connect(player.squeeze)
	get_node("GUI/ButtonsRight/BtnSkirt").pressed.connect(player.lift_skirt)
	get_node("GUI/ButtonsLeft/BtnHold").pressed.connect(player.hold_castle)
	get_node("GUI/ButtonsLeft/BtnDebug").pressed.connect(func(): GameManager.debug_toggled.emit(True))

	# шкаф: одевание горничной
	get_node("CastleRoot/Castle/WardrobeInteract").body_entered.connect(_on_wardrobe)
	# трон: рагдолл на троне
	get_node("CastleRoot/Castle/ThroneSit").body_entered.connect(_on_throne_sit)

func _on_wardrobe(body: Node3D) -> void:
	if body == player:
		player.put_on_maid_outfit()
		AudioManager.play_sfx("res://assets/audio/yumik_euphoria.ogg", global_position, -6)

func _on_throne_sit(body: Node3D) -> void:
	if body == player:
		var throne = get_node("CastleRoot/Castle/Throne")
		player.global_position = throne.global_position + Vector3(0, 1.2, 0)
		player._enter_ragdoll(Vector3.ZERO)
		AudioManager.play_sfx("res://assets/audio/darkgod_purr.ogg", global_position, -6)

func _on_enter_castle(body: Node3D) -> void:
	if body == player:
		castle._gate_close()
		if GameManager.state != GameManager.STATE_SUCTION:
			# выталкиваем игрока обратно, если ворота запечатаны
			player.global_position = player.global_position - Vector3(0, 0, 1.5)

func _process(delta: float) -> void:
	# цикл состояний НЗТБНЗ (каждые 3 реальные минуты)
	_state_accum += delta
	if _state_accum >= GameManager.state_duration:
		GameManager.next_state()
		_state_accum = 0.0

	# смена суток
	var hour: float = GameManager.time_of_day
	hour += delta * GameManager.day_speed
	while hour >= 24.0:
		hour -= 24.0
	while hour < 0.0:
		hour += 24.0
	GameManager.time_of_day = hour
	_update_sky(hour)

	# ветер
	_wind_accum += delta
	if _wind_accum > 5.0:
		_wind_accum = 0.0
		if GameManager.wind_speed_kmh < 25.0:
			GameManager.wind_speed_kmh = clamp(GameManager.wind_speed_kmh + randf_range(-2.5, 2.5), 1.0, 20.0)
			var target: Vector2 = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
			GameManager.wind_direction = GameManager.wind_direction.linear_interpolate(target, 0.35)
		var w3d: Vector3 = Vector3(GameManager.wind_direction.x, 0, GameManager.wind_direction.y) * (GameManager.wind_speed_kmh / 3.6)
		castle.set_wind(w3d)
		castle.get_node("WingInflWest").set_wind(w3d)
		castle.get_node("WingInflEast").set_wind(w3d)
		castle.get_node("WingInflNorth").set_wind(w3d)
		hud.set_wind(GameManager.wind_speed_kmh, GameManager.wind_direction)

	# управление игрой
	player.set_move_input(joystick.direction, joystick.is_running)
	world_generator.update(player.global_position)
	cam_area.rotation_changed.connect(_on_camera_rot)

func _on_camera_rot(dx: float, dy: float) -> void:
	_camera_yaw += dx
	_camera_pitch = clamp(_camera_pitch + dy, -50.0, 70.0)
	_update_camera()

func _update_camera() -> void:
	camera_pivot.rotation_degrees = Vector3(0, _camera_yaw, 0)
	cam.rotation_degrees = Vector3(_camera_pitch, 0, 0)

func _update_sky(hour: float) -> void:
	# солнце/луна по небу
	var angle: float = (hour / 24.0) * TAU - PI * 0.5
	sun.rotation_degrees = Vector3(angle * 180.0 / PI, 40.0, 0)
	if hour >= 6.0 and hour < 18.0:
		sun.energy = 1.1
		env.environment.ambient_light = Color(0.35, 0.35, 0.38, 1)
	else:
		sun.energy = 0.12
		env.environment.ambient_light = Color(0.03, 0.02, 0.05, 1)

# ----------------------------------------------------------------
# Публичный API (вызывается из UI / скриптов)
# ----------------------------------------------------------------

func respawn_player(death_pos: Vector3) -> void:
	# респавн через 3 секунды в радиусе 10 метров
	var rng_angle: float = randf_range(0.0, TAU)
	var rng_dist: float = randf_range(2.0, 10.0)
	var target: Vector3 = death_pos + Vector3(cos(rng_angle), 0, sin(rng_angle)) * rng_dist
	# опускаемся на поверхность (рейкаст вниз)
	var space = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(target + Vector3(0, 60, 0), target + Vector3(0, -80, 0))
	query.collide_with_areas = false
	var res = space.intersect_ray(query)
	if res:
		target.y = res.position.y + 0.95
	player.respawn(target)

func teleport_to_castle() -> void:
	player.global_position = castle.global_position + Vector3(0, 6, -14)
