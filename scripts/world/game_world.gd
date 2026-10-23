extends Node3D
## Master GameWorld Orchestrator:
## - Initializes Dynamic Sky + Sun/Moon at 22:00 night
## - Streams 1x1 / 10x10 / 50x50 km procedural valley chunks with 3 non-overlapping biomes
## - Spawns НЗТБНЗ (33m AeroBody3D castle + 4 x 75m hemp ropes) at valley origin (0, ground_y, 0)
## - Spawns Юмик (1.90m, 80kg) strictly 50.0 meters in front of НЗТБНЗ facing the gates
## - Spawns 250m Hurricane Funnel on "Ураган (120 км/ч)"
## - Runs 8-game-hour Sleep Nyashing Cutscene & instant Skip handler

@onready var world_env: WorldEnvironment = $WorldEnvironment
@onready var sun_light: DirectionalLight3D = $SunLight3D
@onready var moon_light: DirectionalLight3D = $MoonLight3D
@onready var day_night: DayNightCycle = $DayNightCycle
@onready var chunk_manager: ChunkManager = $ChunkManager
@onready var atmosphere: WorldAeroAtmosphere3D = $WorldAeroAtmosphere3D
@onready var castle: InflatableCastle = $InflatableCastle
@onready var player: YumikController = $Yumik
@onready var hud: TouchHUD = $TouchHUD

var active_hurricane: HurricaneVortex = null
var _cutscene_cam: Camera3D = null
var _cutscene_timer: float = 0.0
var _cutscene_hours_applied: float = 0.0


func _ready() -> void:
	GameState.is_in_game = true
	GameState.reset_session_clock()
	WindManager.reset_to_natural()

	day_night.sun_light = sun_light
	day_night.moon_light = moon_light
	day_night.world_environment = world_env

	# Initialize procedural valley (1x1, 10x10, or 50x50 km) around (0, 0)
	chunk_manager.initialize_world(
		GameState.world_seed,
		GameState.get_world_size_meters(),
		player,
		castle
	)

	var gen: BiomeGenerator = chunk_manager.biome_generator
	var castle_ground_y: float = gen.get_height(0.0, 0.0)
	castle.global_position = Vector3(0.0, castle_ground_y + 0.05, 0.0)
	castle.linear_velocity = Vector3.ZERO
	castle.angular_velocity = Vector3.ZERO
	castle.attach_atmosphere(atmosphere)
	castle.set_player_reference(player)
	castle.spawn_corner_ropes(self, castle_ground_y)
	castle.set_castle_state(GameState.CastleState.NORMAL)

	# Spec: Yumik starts at 22:00 night strictly 50.0 meters away from НЗТБНЗ facing the gates!
	var player_z: float = 50.0
	var player_ground_y: float = gen.get_height(0.0, player_z)
	player.castle_ref = castle
	player.biome_gen_ref = gen
	player.global_position = Vector3(0.0, player_ground_y + 0.15, player_z)
	player.camera_yaw = 0.0 # Faces -Z straight toward НЗТБНЗ's 3x7m front gates!

	hud.setup_hud(player, castle, gen)

	# Connect global orchestration events
	GameState.teleport_to_castle_requested.connect(_on_teleport_to_castle)
	GameState.skip_sleep_requested.connect(_finish_or_skip_sleep_cutscene)
	WindManager.hurricane_spawn_requested.connect(_on_spawn_hurricane_250m)
	WindManager.hurricane_cleared.connect(_on_clear_hurricane)
	player.euphoria_sleep_triggered.connect(_start_sleep_cutscene)


func _on_teleport_to_castle(inside_hall: bool) -> void:
	if not is_instance_valid(castle) or not is_instance_valid(player):
		return
	player.reset_after_sleep()
	if inside_hall:
		player.global_position = castle.to_global(Vector3(0.0, 2.5, 5.5))
		GameState.player_status_message.emit("Телепортация внутрь зала НЗТБНЗ!")
	else:
		var outside_world: Vector3 = castle.to_global(Vector3(0.0, 2.5, 25.0))
		if chunk_manager.biome_generator != null:
			outside_world.y = maxf(outside_world.y, chunk_manager.biome_generator.get_height(outside_world.x, outside_world.z) + 1.0)
		player.global_position = outside_world
		GameState.player_status_message.emit("Телепортация к вратам НЗТБНЗ!")


func _on_spawn_hurricane_250m(dist_m: float) -> void:
	_on_clear_hurricane()
	var ang: float = randf() * TAU
	var origin: Vector3 = player.global_position if is_instance_valid(player) else Vector3.ZERO
	var spawn_xz := Vector3(origin.x + cos(ang) * dist_m, 0.0, origin.z + sin(ang) * dist_m)
	if chunk_manager.biome_generator != null:
		spawn_xz.y = chunk_manager.biome_generator.get_height(spawn_xz.x, spawn_xz.z)

	active_hurricane = HurricaneVortex.new()
	active_hurricane.name = "HurricaneVortex250m"
	active_hurricane.target_focus = castle
	add_child(active_hurricane)
	active_hurricane.global_position = spawn_xz
	WindManager.hurricane_center = spawn_xz
	GameState.player_status_message.emit("В 250 метрах от Юмика зародилась воронка УРАГАНА (120 км/ч)!")


func _on_clear_hurricane() -> void:
	if is_instance_valid(active_hurricane):
		active_hurricane.queue_free()
	active_hurricane = null


func _start_sleep_cutscene() -> void:
	if GameState.is_sleep_cutscene_active:
		return
	GameState.is_sleep_cutscene_active = true
	GameState.sleep_cutscene_state_changed.emit(true)
	_cutscene_timer = 12.0
	_cutscene_hours_applied = 0.0

	if not is_instance_valid(_cutscene_cam):
		_cutscene_cam = Camera3D.new()
		_cutscene_cam.name = "SleepCutsceneCamera3D"
		_cutscene_cam.fov = 60.0
		add_child(_cutscene_cam)
	_cutscene_cam.current = true
	if is_instance_valid(castle.dark_god):
		castle.dark_god.trigger_gtlt_expression(20.0, true)


func _finish_or_skip_sleep_cutscene() -> void:
	if GameState.is_sleep_cutscene_active:
		var rem_hours: float = maxf(8.0 - _cutscene_hours_applied, 0.0)
		GameState.advance_game_hours(rem_hours)
		GameState.is_sleep_cutscene_active = false
		GameState.sleep_cutscene_state_changed.emit(false)
		if is_instance_valid(player) and is_instance_valid(player.camera_3d):
			player.camera_3d.current = true
			player.reset_after_sleep()
		GameState.player_status_message.emit("Прошло 8 игровых часов! Юмик проснулся бодрым в %s" % GameState.get_formatted_time())
	else:
		GameState.advance_game_hours(8.0)
		if is_instance_valid(player):
			player.reset_after_sleep()
		GameState.player_status_message.emit("Пропуск сна (+8 игровых часов) -> %s" % GameState.get_formatted_time())


func _process(delta: float) -> void:
	if not GameState.is_sleep_cutscene_active:
		return

	# Smoothly advance the 8.0 game hours during the dream Nyashing cutscene!
	var step_hours: float = (delta / 12.0) * 8.0
	var add_h: float = minf(step_hours, maxf(8.0 - _cutscene_hours_applied, 0.0))
	_cutscene_hours_applied += add_h
	GameState.advance_game_hours(add_h)

	if is_instance_valid(_cutscene_cam) and is_instance_valid(castle) and is_instance_valid(castle.dark_god):
		var center: Vector3 = castle.dark_god.global_position + Vector3(0.0, 1.35, 0.0)
		var orbit_a: float = (12.0 - _cutscene_timer) * 0.65
		_cutscene_cam.global_position = center + Vector3(sin(orbit_a) * 5.2, 2.2, cos(orbit_a) * 5.2)
		_cutscene_cam.look_at(center, Vector3.UP)

	_cutscene_timer -= delta
	if _cutscene_timer <= 0.0:
		_finish_or_skip_sleep_cutscene()
