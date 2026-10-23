extends Node
## Centralized Ogg Vorbis (.ogg) Audio Engine.
## All music, ambient loops, surface footsteps, hollow PVC booms, squeaks, silk rustle,
## Venturi suction roar, wing beats, and Yumik / Dark God vocalizations use exclusively .ogg files.

var _streams: Dictionary = {}
var _music_night: AudioStreamPlayer
var _music_sky: AudioStreamPlayer
var _amb_wind_calm: AudioStreamPlayer
var _amb_wind_strong: AudioStreamPlayer
var _amb_night: AudioStreamPlayer
var _amb_day: AudioStreamPlayer
var _amb_water: AudioStreamPlayer
var _suction_player: AudioStreamPlayer3D
var _purr_player: AudioStreamPlayer3D

var _sfx_2d_pool: Array[AudioStreamPlayer] = []
var _sfx_3d_pool: Array[AudioStreamPlayer3D] = []
var _sfx_2d_idx: int = 0
var _sfx_3d_idx: int = 0

var water_proximity_weight: float = 0.0
var sky_music_weight: float = 0.0

const AUDIO_PATHS := {
	"music_night": "res://assets/audio/music/dark_castle_theme_night.ogg",
	"music_sky": "res://assets/audio/music/dark_castle_theme_sky.ogg",
	"wind_calm": "res://assets/audio/ambient/wind_calm_loop.ogg",
	"wind_strong": "res://assets/audio/ambient/wind_strong_loop.ogg",
	"amb_night": "res://assets/audio/ambient/night_valley_ambient.ogg",
	"amb_day": "res://assets/audio/ambient/day_valley_ambient.ogg",
	"water_loop": "res://assets/audio/ambient/water_shore_loop.ogg",
	"step_grass_1": "res://assets/audio/sfx/step_grass_01.ogg",
	"step_grass_2": "res://assets/audio/sfx/step_grass_02.ogg",
	"step_grass_3": "res://assets/audio/sfx/step_grass_03.ogg",
	"step_rock_1": "res://assets/audio/sfx/step_rock_01.ogg",
	"step_rock_2": "res://assets/audio/sfx/step_rock_02.ogg",
	"step_rock_3": "res://assets/audio/sfx/step_rock_03.ogg",
	"step_pvc_1": "res://assets/audio/sfx/step_pvc_01.ogg",
	"step_pvc_2": "res://assets/audio/sfx/step_pvc_02.ogg",
	"step_pvc_3": "res://assets/audio/sfx/step_pvc_03.ogg",
	"jump": "res://assets/audio/sfx/jump_effort.ogg",
	"skip_jump": "res://assets/audio/sfx/hop_skip_effort.ogg",
	"land_ground": "res://assets/audio/sfx/land_ground_heavy.ogg",
	"pvc_boom_big": "res://assets/audio/sfx/land_pvc_boom_big.ogg",
	"pvc_boom_med": "res://assets/audio/sfx/land_pvc_boom_med.ogg",
	"pvc_boom_soft": "res://assets/audio/sfx/land_pvc_boom_soft.ogg",
	"pvc_squeak_1": "res://assets/audio/sfx/pvc_squeak_hug_01.ogg",
	"pvc_squeak_2": "res://assets/audio/sfx/pvc_squeak_hug_02.ogg",
	"pvc_slip": "res://assets/audio/sfx/pvc_slide_slip.ogg",
	"silk_rustle": "res://assets/audio/sfx/silk_rustle_dress.ogg",
	"wardrobe": "res://assets/audio/sfx/wardrobe_open.ogg",
	"gate_slam": "res://assets/audio/sfx/gate_slam_lock.ogg",
	"suction_roar": "res://assets/audio/sfx/venturi_suction_roar.ogg",
	"wing_flap_1": "res://assets/audio/sfx/wings_giant_flap_01.ogg",
	"wing_flap_2": "res://assets/audio/sfx/wings_giant_flap_02.ogg",
	"ui_tap": "res://assets/audio/sfx/ui_tap.ogg",
	"yumik_jump": "res://assets/audio/voice/yumik_jump_01.ogg",
	"yumik_fall": "res://assets/audio/voice/yumik_whoa_fall.ogg",
	"yumik_oof": "res://assets/audio/voice/yumik_oof_impact.ogg",
	"yumik_hold": "res://assets/audio/voice/yumik_hold_me.ogg",
	"yumik_sleep": "res://assets/audio/voice/yumik_sigh_sleep.ogg",
	"yumik_respawn": "res://assets/audio/voice/yumik_respawn.ogg",
	"dg_giggle_1": "res://assets/audio/voice/dark_god_giggle_01.ogg",
	"dg_giggle_2": "res://assets/audio/voice/dark_god_giggle_02.ogg",
	"dg_purr": "res://assets/audio/voice/dark_god_purr_loop.ogg",
	"dg_nya": "res://assets/audio/voice/dark_god_nya_happy.ogg",
}


func _ready() -> void:
	for key in AUDIO_PATHS.keys():
		var path: String = AUDIO_PATHS[key]
		if ResourceLoader.exists(path):
			_streams[key] = load(path)

	_music_night = _make_2d_player("Music", "music_night", true, -8.0)
	_music_sky = _make_2d_player("Music", "music_sky", true, -60.0)
	_amb_wind_calm = _make_2d_player("Ambient", "wind_calm", true, -9.0)
	_amb_wind_strong = _make_2d_player("Ambient", "wind_strong", true, -40.0)
	_amb_night = _make_2d_player("Ambient", "amb_night", true, -6.0)
	_amb_day = _make_2d_player("Ambient", "amb_day", true, -45.0)
	_amb_water = _make_2d_player("Ambient", "water_loop", true, -50.0)

	_suction_player = _make_3d_loop_player("SFX", "suction_roar", 110.0)
	_purr_player = _make_3d_loop_player("Voice", "dg_purr", 28.0)

	for _i in range(10):
		var p2 := AudioStreamPlayer.new()
		p2.bus = &"SFX"
		add_child(p2)
		_sfx_2d_pool.append(p2)

	for _j in range(14):
		var p3 := AudioStreamPlayer3D.new()
		p3.bus = &"SFX"
		p3.max_distance = 120.0
		p3.unit_size = 12.0
		add_child(p3)
		_sfx_3d_pool.append(p3)


func _make_2d_player(bus_name: String, key: String, autoplay_loop: bool, vol_db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = StringName(bus_name)
	p.volume_db = vol_db
	var st: AudioStream = _streams.get(key)
	if st is AudioStreamOggVorbis:
		st.loop = autoplay_loop
	p.stream = st
	add_child(p)
	if autoplay_loop and st != null:
		p.play()
	return p


func _make_3d_loop_player(bus_name: String, key: String, max_dist: float) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.bus = StringName(bus_name)
	p.max_distance = max_dist
	p.unit_size = 14.0
	var st: AudioStream = _streams.get(key)
	if st is AudioStreamOggVorbis:
		st.loop = true
	p.stream = st
	add_child(p)
	return p


func _process(delta: float) -> void:
	# Ensure looped streams stay alive even if reimported without loop metadata
	for lp in [_music_night, _music_sky, _amb_wind_calm, _amb_wind_strong, _amb_night, _amb_day, _amb_water]:
		if is_instance_valid(lp) and lp.stream != null and not lp.playing:
			lp.play()

	var t_blend: float = clampf(delta * 1.8, 0.0, 1.0)
	var kmh: float = WindManager.current_speed_kmh
	var strong_w: float = clampf((kmh - 18.0) / 72.0, 0.0, 1.0)
	_amb_wind_calm.volume_db = lerpf(_amb_wind_calm.volume_db, lerpf(-7.0, -20.0, strong_w), t_blend)
	_amb_wind_strong.volume_db = lerpf(_amb_wind_strong.volume_db, lerpf(-38.0, -1.5, strong_w), t_blend)
	_amb_wind_strong.pitch_scale = lerpf(0.85, 1.28, strong_w)

	var night_w: float = 1.0 if GameState.is_night_time() else 0.0
	_amb_night.volume_db = lerpf(_amb_night.volume_db, lerpf(-42.0, -6.5, night_w), t_blend)
	_amb_day.volume_db = lerpf(_amb_day.volume_db, lerpf(-42.0, -7.5, 1.0 - night_w), t_blend)

	_amb_water.volume_db = lerpf(_amb_water.volume_db, lerpf(-48.0, -5.0, clampf(water_proximity_weight, 0.0, 1.0)), t_blend)

	_music_night.volume_db = lerpf(_music_night.volume_db, lerpf(-7.0, -34.0, sky_music_weight), t_blend)
	_music_sky.volume_db = lerpf(_music_sky.volume_db, lerpf(-38.0, -5.5, sky_music_weight), t_blend)


func play_2d(key: String, vol_db: float = 0.0, pitch: float = 1.0, is_voice: bool = false) -> void:
	var st: AudioStream = _streams.get(key)
	if st == null:
		return
	var p: AudioStreamPlayer = _sfx_2d_pool[_sfx_2d_idx]
	_sfx_2d_idx = (_sfx_2d_idx + 1) % _sfx_2d_pool.size()
	p.bus = &"Voice" if is_voice else &"SFX"
	p.stream = st
	p.volume_db = vol_db
	p.pitch_scale = pitch
	p.play()


func play_3d(key: String, world_pos: Vector3, vol_db: float = 0.0, pitch: float = 1.0, is_voice: bool = false) -> void:
	var st: AudioStream = _streams.get(key)
	if st == null:
		return
	var p: AudioStreamPlayer3D = _sfx_3d_pool[_sfx_3d_idx]
	_sfx_3d_idx = (_sfx_3d_idx + 1) % _sfx_3d_pool.size()
	p.bus = &"Voice" if is_voice else &"SFX"
	p.global_position = world_pos
	p.stream = st
	p.volume_db = vol_db
	p.pitch_scale = pitch
	p.play()


func play_step(surface_kind: String, world_pos: Vector3, running: bool) -> void:
	var variant: int = (randi() % 3) + 1
	var key := "step_grass_%d" % variant
	if surface_kind == "rock":
		key = "step_rock_%d" % variant
	elif surface_kind.begins_with("pvc") or surface_kind == "dark_god":
		key = "step_pvc_%d" % variant
	play_3d(key, world_pos, 1.5 if running else -2.5, randf_range(0.92, 1.10))


func play_pvc_bounce(bounce_height: float, world_pos: Vector3) -> void:
	if bounce_height >= 2.2:
		play_3d("pvc_boom_big", world_pos, 2.5, randf_range(0.90, 1.05))
	elif bounce_height >= 0.8:
		play_3d("pvc_boom_med", world_pos, 0.5, randf_range(0.95, 1.08))
	else:
		play_3d("pvc_boom_soft", world_pos, -1.5, randf_range(0.98, 1.12))


func update_suction_audio(enabled: bool, pos: Vector3) -> void:
	if not is_instance_valid(_suction_player):
		return
	_suction_player.global_position = pos
	if enabled:
		if not _suction_player.playing:
			_suction_player.play()
	else:
		if _suction_player.playing:
			_suction_player.stop()


func update_purr_audio(enabled: bool, pos: Vector3) -> void:
	if not is_instance_valid(_purr_player):
		return
	_purr_player.global_position = pos
	if enabled:
		if not _purr_player.playing:
			_purr_player.play()
	else:
		if _purr_player.playing:
			_purr_player.stop()
