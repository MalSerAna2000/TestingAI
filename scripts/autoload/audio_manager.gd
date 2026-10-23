extends Node

## Central Ogg Vorbis (.ogg) audio manager: crossfades ambient night/day, wind, water,
## dream lullaby, and pools spatial 3D SFX & character vocalizations.

var streams: Dictionary = {}

var menu_music_player: AudioStreamPlayer
var night_ambient_player: AudioStreamPlayer
var day_ambient_player: AudioStreamPlayer
var wind_calm_player: AudioStreamPlayer
var wind_strong_player: AudioStreamPlayer
var wind_hurricane_player: AudioStreamPlayer
var water_ambient_player: AudioStreamPlayer
var dream_music_player: AudioStreamPlayer

var sfx_pool_3d: Array[AudioStreamPlayer3D] = []
var sfx_pool_idx: int = 0
var water_proximity_factor: float = 0.0


func _ready() -> void:
	_preload_all_ogg()
	menu_music_player = _make_2d_player("menu_theme", &"Ambient", -6.0)
	night_ambient_player = _make_2d_player("night_ambient", &"Ambient", -8.0)
	day_ambient_player = _make_2d_player("day_ambient", &"Ambient", -40.0)
	wind_calm_player = _make_2d_player("wind_calm", &"Ambient", -12.0)
	wind_strong_player = _make_2d_player("wind_strong", &"Ambient", -40.0)
	wind_hurricane_player = _make_2d_player("wind_hurricane", &"Ambient", -40.0)
	water_ambient_player = _make_2d_player("water_shore", &"Ambient", -40.0)
	dream_music_player = _make_2d_player("dream_music", &"Ambient", -40.0)

	for i in range(18):
		var p3d := AudioStreamPlayer3D.new()
		p3d.bus = &"SFX"
		p3d.max_distance = 160.0
		p3d.unit_size = 8.0
		add_child(p3d)
		sfx_pool_3d.append(p3d)


func _preload_all_ogg() -> void:
	var table := {
		"menu_theme": "res://assets/audio/ambient/menu_dark_castle_theme.ogg",
		"night_ambient": "res://assets/audio/ambient/night_valley_ambient.ogg",
		"day_ambient": "res://assets/audio/ambient/day_valley_ambient.ogg",
		"wind_calm": "res://assets/audio/ambient/wind_calm_loop.ogg",
		"wind_strong": "res://assets/audio/ambient/wind_strong_loop.ogg",
		"wind_hurricane": "res://assets/audio/ambient/wind_hurricane_loop.ogg",
		"water_shore": "res://assets/audio/ambient/water_shore_loop.ogg",
		"dream_music": "res://assets/audio/ambient/nyashing_dream_music.ogg",
		"step_grass_1": "res://assets/audio/sfx/step_grass_01.ogg",
		"step_grass_2": "res://assets/audio/sfx/step_grass_02.ogg",
		"step_rock_1": "res://assets/audio/sfx/step_rock_01.ogg",
		"step_rock_2": "res://assets/audio/sfx/step_rock_02.ogg",
		"step_pvc_1": "res://assets/audio/sfx/step_pvc_01.ogg",
		"step_pvc_2": "res://assets/audio/sfx/step_pvc_02.ogg",
		"jump": "res://assets/audio/sfx/jump_whoosh.ogg",
		"land_ground": "res://assets/audio/sfx/land_ground.ogg",
		"land_pvc_1": "res://assets/audio/sfx/land_pvc_boom_01.ogg",
		"land_pvc_2": "res://assets/audio/sfx/land_pvc_boom_02.ogg",
		"pvc_boing": "res://assets/audio/sfx/pvc_bounce_boing.ogg",
		"pvc_squeak_1": "res://assets/audio/sfx/pvc_squeak_cuddle_01.ogg",
		"pvc_squeak_2": "res://assets/audio/sfx/pvc_squeak_cuddle_02.ogg",
		"pvc_squeak_3": "res://assets/audio/sfx/pvc_squeak_cuddle_03.ogg",
		"silk_rustle": "res://assets/audio/sfx/silk_dress_rustle.ogg",
		"suction_loop": "res://assets/audio/sfx/venturi_suction_loop.ogg",
		"wing_huge": "res://assets/audio/sfx/angel_wing_flap_huge.ogg",
		"wing_inner": "res://assets/audio/sfx/angel_wing_flap_inner.ogg",
		"gate_lock": "res://assets/audio/sfx/gate_seal_lock.ogg",
		"rope_creak": "res://assets/audio/sfx/rope_grab_creak.ogg",
		"yumik_hop": "res://assets/audio/voices/yumik_hop.ogg",
		"yumik_climb": "res://assets/audio/voices/yumik_climb.ogg",
		"yumik_whoa": "res://assets/audio/voices/yumik_whoa.ogg",
		"yumik_hold_me": "res://assets/audio/voices/yumik_hold_me.ogg",
		"yumik_respawn": "res://assets/audio/voices/yumik_respawn.ogg",
		"yumik_sleep": "res://assets/audio/voices/yumik_sleep_sigh.ogg",
		"god_giggle_1": "res://assets/audio/voices/dark_god_giggle_01.ogg",
		"god_giggle_2": "res://assets/audio/voices/dark_god_giggle_02.ogg",
		"god_nya": "res://assets/audio/voices/dark_god_nya_happy.ogg",
		"god_purr": "res://assets/audio/voices/dark_god_purr_loop.ogg",
	}
	for key: String in table.keys():
		var path: String = table[key]
		if ResourceLoader.exists(path):
			var s: AudioStream = load(path)
			if s is AudioStreamOggVorbis and key in ["menu_theme", "night_ambient", "day_ambient", "wind_calm", "wind_strong", "wind_hurricane", "water_shore", "dream_music", "suction_loop", "god_purr"]:
				(s as AudioStreamOggVorbis).loop = true
			streams[key] = s


func _make_2d_player(stream_key: String, bus_name: StringName, vol_db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus_name
	p.volume_db = vol_db
	if streams.has(stream_key):
		p.stream = streams[stream_key]
	add_child(p)
	return p


func start_menu_audio() -> void:
	for p in [night_ambient_player, day_ambient_player, wind_calm_player, wind_strong_player, wind_hurricane_player, water_ambient_player, dream_music_player]:
		p.stop()
	if menu_music_player.stream and not menu_music_player.playing:
		menu_music_player.play()


func start_world_audio() -> void:
	menu_music_player.stop()
	for p in [night_ambient_player, day_ambient_player, wind_calm_player, wind_strong_player, wind_hurricane_player, water_ambient_player]:
		if p.stream and not p.playing:
			p.play()


func _process(delta: float) -> void:
	if not GameState.in_gameplay:
		return

	var hr: float = GameState.game_hours
	var is_day: bool = hr >= 6.0 and hr <= 19.0
	var target_night_db: float = -34.0 if is_day else -7.5
	var target_day_db: float = -8.0 if is_day else -36.0
	night_ambient_player.volume_db = lerpf(night_ambient_player.volume_db, target_night_db, delta * 1.5)
	day_ambient_player.volume_db = lerpf(day_ambient_player.volume_db, target_day_db, delta * 1.5)

	var spd_kmh: float = WindManager.get_current_speed_kmh()
	var calm_db: float = remap(clampf(spd_kmh, 0.0, 40.0), 0.0, 40.0, -14.0, -5.0)
	var strong_db: float = remap(clampf(spd_kmh, 15.0, 80.0), 15.0, 80.0, -36.0, -2.5)
	var hurr_db: float = remap(clampf(spd_kmh, 65.0, 120.0), 65.0, 120.0, -40.0, 0.0)
	wind_calm_player.volume_db = lerpf(wind_calm_player.volume_db, calm_db, delta * 2.5)
	wind_strong_player.volume_db = lerpf(wind_strong_player.volume_db, strong_db, delta * 2.5)
	wind_hurricane_player.volume_db = lerpf(wind_hurricane_player.volume_db, hurr_db, delta * 2.5)

	var water_db: float = lerpf(-42.0, -4.5, clampf(water_proximity_factor, 0.0, 1.0))
	water_ambient_player.volume_db = lerpf(water_ambient_player.volume_db, water_db, delta * 2.0)

	if GameState.is_sleeping_cutscene:
		if dream_music_player.stream and not dream_music_player.playing:
			dream_music_player.play()
		dream_music_player.volume_db = lerpf(dream_music_player.volume_db, -3.5, delta * 2.5)
	else:
		dream_music_player.volume_db = lerpf(dream_music_player.volume_db, -45.0, delta * 3.0)
		if dream_music_player.volume_db < -42.0 and dream_music_player.playing:
			dream_music_player.stop()


func play_3d(key: String, world_pos: Vector3, vol_db: float = 0.0, pitch_jitter: float = 0.08, bus_name: StringName = &"SFX") -> void:
	if not streams.has(key):
		return
	var p: AudioStreamPlayer3D = sfx_pool_3d[sfx_pool_idx]
	sfx_pool_idx = (sfx_pool_idx + 1) % sfx_pool_3d.size()
	p.stop()
	p.bus = bus_name
	p.stream = streams[key]
	p.global_position = world_pos
	p.volume_db = vol_db
	p.pitch_scale = randf_range(1.0 - pitch_jitter, 1.0 + pitch_jitter)
	p.play()


func play_footstep(surface: String, pos: Vector3) -> void:
	var variant: int = 1 + (randi() % 2)
	match surface:
		"pvc":
			play_3d("step_pvc_%d" % variant, pos, -2.0, 0.10)
		"rock":
			play_3d("step_rock_%d" % variant, pos, -3.0, 0.09)
		_:
			play_3d("step_grass_%d" % variant, pos, -4.0, 0.09)


func play_landing(on_pvc: bool, is_elastic_bounce: bool, pos: Vector3) -> void:
	if on_pvc:
		if is_elastic_bounce:
			play_3d("pvc_boing", pos, 1.5, 0.08)
		var idx: int = 1 + (randi() % 2)
		play_3d("land_pvc_%d" % idx, pos, 2.5, 0.07)
	else:
		play_3d("land_ground", pos, -1.5, 0.08)


func play_pvc_squeak(pos: Vector3) -> void:
	var idx: int = 1 + (randi() % 3)
	play_3d("pvc_squeak_%d" % idx, pos, 0.5, 0.12)


func play_yumik_voice(kind: String, pos: Vector3) -> void:
	play_3d("yumik_" + kind, pos, 1.5, 0.05, &"Voice")


func play_dark_god_voice(kind: String, pos: Vector3) -> void:
	if kind == "giggle":
		var idx: int = 1 + (randi() % 2)
		play_3d("god_giggle_%d" % idx, pos, 2.5, 0.06, &"Voice")
	else:
		play_3d("god_nya", pos, 2.5, 0.06, &"Voice")
