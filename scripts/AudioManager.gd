extends Node
class_name AudioManager

var streams: Dictionary = {
	"player_shoot": preload("res://Audio/SFX/player_shoot.wav"),
	"bullet_hit": preload("res://Audio/SFX/bullet_hit.wav"),
	"player_hit": preload("res://Audio/SFX/player_hit.wav"),
	"powerup_collect": preload("res://Audio/SFX/powerup_collect.wav"),
	"special_cast": preload("res://Audio/SFX/special_cast.wav"),
	"special_ready": preload("res://Audio/SFX/special_ready.wav"),
	"enemy_die_fast": preload("res://Audio/SFX/enemy_die_fast.wav"),
	"enemy_die_tank": preload("res://Audio/SFX/enemy_die_tank.wav"),
	"enemy_die_shooter": preload("res://Audio/SFX/enemy_die_shooter.wav"),
	"enemy_die_hunter": preload("res://Audio/SFX/enemy_die_hunter.wav"),
	"enemy_die_boss": preload("res://Audio/SFX/enemy_die_boss.wav"),
	"enemy_shoot": preload("res://Audio/SFX/enemy_shoot.wav"),
	"boss_warning": preload("res://Audio/SFX/boss_warning.wav"),
	"pollution_hit": preload("res://Audio/SFX/pollution_hit.wav"),
	"wave_clear": preload("res://Audio/SFX/wave_clear.wav"),
	"game_over": preload("res://Audio/SFX/game_over.wav"),
	"ui_select": preload("res://Audio/SFX/ui_select.wav"),
}
var music_streams: Dictionary = {
	"ambient": preload("res://Audio/Music/ambient_loop.wav"),
	"action": preload("res://Audio/Music/action_layer.wav"),
	"boss": preload("res://Audio/Music/boss_layer.wav"),
}
var music_players: Dictionary = {}
var sfx_volume_db: float = 0.0
var music_volume_db: float = -3.0
var last_wave: int = 1
var last_boss_active: bool = false
var last_pollution_ratio: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("audio_manager")
	_create_music_layers()

func play(sound_name: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if not streams.has(sound_name):
		return

	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	player.stream = streams[sound_name] as AudioStream
	player.volume_db = volume_db + sfx_volume_db
	player.pitch_scale = pitch * randf_range(0.94, 1.06)
	add_child(player)
	player.finished.connect(Callable(player, "queue_free"))
	player.play()

func set_sfx_volume(value: float) -> void:
	sfx_volume_db = linear_to_db(maxf(value, 0.001))

func set_music_volume(value: float) -> void:
	music_volume_db = linear_to_db(maxf(value, 0.001)) - 3.0
	_update_music_layers(last_wave, last_boss_active, last_pollution_ratio)

func set_music_state(wave: int, boss_active: bool, pollution_ratio: float) -> void:
	last_wave = wave
	last_boss_active = boss_active
	last_pollution_ratio = pollution_ratio
	_update_music_layers(wave, boss_active, pollution_ratio)

func start_music() -> void:
	for key in music_players.keys():
		var player: AudioStreamPlayer = music_players[key] as AudioStreamPlayer
		if player != null and not player.playing:
			player.play()
	_update_music_layers(last_wave, last_boss_active, last_pollution_ratio)

func _create_music_layers() -> void:
	for key in music_streams.keys():
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		var stream: AudioStreamWAV = music_streams[key] as AudioStreamWAV
		if stream != null:
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		player.stream = stream
		player.volume_db = -80.0
		add_child(player)
		player.play()
		music_players[key] = player
	_update_music_layers(1, false, 0.0)

func _update_music_layers(wave: int, boss_active: bool, pollution_ratio: float) -> void:
	if music_players.is_empty():
		return

	var action_gain: float = minf(1.0, maxf(float(wave - 2) / 6.0, pollution_ratio))
	var ambient_db: float = music_volume_db
	var action_db: float = music_volume_db + linear_to_db(maxf(action_gain, 0.001)) - 4.0
	var boss_db: float = -80.0
	if boss_active:
		action_db = music_volume_db - 4.0
		boss_db = music_volume_db - 1.0

	_fade_music("ambient", ambient_db)
	_fade_music("action", action_db)
	_fade_music("boss", boss_db)

func _fade_music(key: String, target_db: float) -> void:
	var player: AudioStreamPlayer = music_players[key] as AudioStreamPlayer
	if player == null:
		return

	var tween: Tween = create_tween()
	tween.tween_property(player, "volume_db", target_db, 0.35)
