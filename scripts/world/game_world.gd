extends Node3D
class_name GameWorld

## Main open-world gameplay coordinator:
## - Initializes chunked procedural valley (1x1, 10x10, 50x50 km) with 3 non-overlapping biomes
## - Sets up PhysicalSkyMaterial + Sun/Moon DirectionalLight3D starting at 22:00 night
## - Registers global AeroAtmosphere3D for Godot Aerodynamic Physics
## - Spawns Yumik at (0, ground_y, 0) and NZTBNZ 50m away at (0, castle_y, -50)
## - Spawns the 250m Hurricane Vortex when Debug Wind "Ураган (120 км/ч)" is triggered!

const AeroAtmosphereScript = preload("res://addons/godot_aerodynamic_physics/core/aero_atmosphere_3d/aero_atmosphere_3d.gd")

@onready var chunk_manager: TerrainChunkManager = $TerrainChunkManager
@onready var world_atmosphere: Area3D = $WorldWindAtmosphere

var player: YumikController
var castle: NZTBNZCastle
var touch_hud: TouchHUD
var active_hurricane: HurricaneVortex = null


func _ready() -> void:
	if not GameState.in_gameplay:
		GameState.reset_for_new_game(GameState.world_size_km, GameState.world_seed)

	AudioManager.start_world_audio()

	# 1. Initialize chunked procedural valley
	chunk_manager.initialize_world(GameState.world_seed, GameState.world_size_km)

	# 2. Register AeroAtmosphere3D with WindManager
	WindManager.register_world_atmosphere(world_atmosphere)
	WindManager.hurricane_spawn_requested.connect(_on_hurricane_spawn_requested)
	WindManager.hurricane_cleared.connect(_on_hurricane_cleared)

	# 3. Spawn NZTBNZ Castle 50 meters north of Yumik (Z = -50.0)!
	var castle_ground_y: float = sample_terrain_height(0.0, -50.0)
	var castle_scene: PackedScene = load("res://scenes/castle/nztbnz_castle.tscn")
	castle = castle_scene.instantiate() as NZTBNZCastle
	castle.position = Vector3(0.0, castle_ground_y + 0.25, -50.0)
	add_child(castle)

	# 4. Spawn Yumik at (0, ground_y, 0) facing NZTBNZ 50m away!
	var player_ground_y: float = sample_terrain_height(0.0, 0.0)
	var player_scene: PackedScene = load("res://scenes/player/yumik.tscn")
	player = player_scene.instantiate() as YumikController
	player.position = Vector3(0.0, player_ground_y + 0.2, 0.0)
	add_child(player)

	# 5. Instantiate Android Touch HUD & bind player
	var hud_scene: PackedScene = load("res://scenes/ui/touch_hud.tscn")
	touch_hud = hud_scene.instantiate() as TouchHUD
	add_child(touch_hud)
	touch_hud.bind_player(player)


func sample_terrain_height(wx: float, wz: float) -> float:
	if chunk_manager and chunk_manager.generator:
		return chunk_manager.generator.get_height_at(wx, wz)
	return 1.5


func _physics_process(_delta: float) -> void:
	# Keep WorldWindAtmosphere centered around NZTBNZ so even in 50x50 km worlds it stays in atmosphere!
	if is_instance_valid(world_atmosphere) and is_instance_valid(castle):
		world_atmosphere.global_position = Vector3(castle.global_position.x, 0.0, castle.global_position.z)


func _on_hurricane_spawn_requested(distance_m: float) -> void:
	_on_hurricane_cleared()
	if not is_instance_valid(player):
		return
	var ang: float = randf() * TAU
	var spawn_x: float = player.global_position.x + cos(ang) * distance_m
	var spawn_z: float = player.global_position.z + sin(ang) * distance_m
	var spawn_y: float = sample_terrain_height(spawn_x, spawn_z)

	var h_scene: PackedScene = load("res://scenes/world/hurricane_vortex.tscn")
	active_hurricane = h_scene.instantiate() as HurricaneVortex
	active_hurricane.position = Vector3(spawn_x, spawn_y, spawn_z)
	add_child(active_hurricane)
	WindManager.active_hurricane_node = active_hurricane


func _on_hurricane_cleared() -> void:
	if is_instance_valid(active_hurricane):
		active_hurricane.queue_free()
	active_hurricane = null
	WindManager.active_hurricane_node = null
