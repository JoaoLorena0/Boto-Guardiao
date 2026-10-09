extends Node2D

@onready var player: PlayerController = $Player
@onready var pollution_core: PollutionCore = $PollutionCore
@onready var game_manager: GameManager = $GameManager
@onready var hud: GameHUD = $Hud
@onready var enemy_spawner: EnemySpawner = $EnemySpawner
@onready var camera: Camera2D = $Camera2D
@onready var background: Sprite2D = $BackGround
@onready var background_loop: Sprite2D = $BackGroundLoop

var game_over: bool = false
var last_health: int = 0
var shake_time: float = 0.0
var shake_strength: float = 0.0
var game_started: bool = false
var background_base_scroll_speed: float = 38.0
var background_scroll_speed: float = 38.0
var background_speed_per_wave: float = 5.0
var background_max_scroll_speed: float = 120.0
var background_center_x: float = 512.0
var background_loop_overlap: float = 8.0
var camera_sway_time: float = 0.0
var camera_sway_speed: float = 0.75
var camera_sway_x: float = 3.0
var camera_sway_y: float = 2.0
var water_streak_timer: float = 0.0
var pause_open: bool = false
var current_biome: int = 1
var biome_tint: Color = Color.WHITE

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	last_health = player.health
	_setup_window()
	get_viewport().size_changed.connect(_layout_for_viewport)
	_layout_for_viewport()

	pollution_core.pollution_changed.connect(hud.update_pollution)
	pollution_core.pollution_changed.connect(_on_pollution_changed)
	pollution_core.ecosystem_destroyed.connect(_on_ecosystem_destroyed)

	game_manager.score_changed.connect(hud.update_score)
	game_manager.wave_changed.connect(hud.update_wave)
	game_manager.wave_changed.connect(_on_wave_changed)
	game_manager.upgrade_choices_requested.connect(_on_upgrade_choices_requested)
	game_manager.combo_changed.connect(hud.update_combo)
	game_manager.mission_changed.connect(hud.update_mission)

	player.health_changed.connect(hud.update_health)
	player.health_changed.connect(_on_player_health_changed)
	player.special_changed.connect(hud.update_special)
	player.power_up_changed.connect(hud.update_power_up)
	player.died.connect(_on_player_died)
	hud.upgrade_selected.connect(_on_upgrade_selected)
	hud.start_requested.connect(_on_start_requested)
	hud.quit_requested.connect(_on_quit_requested)
	hud.restart_requested.connect(_on_restart_requested)
	hud.leaderboard_name_submitted.connect(_on_leaderboard_name_submitted)
	hud.pause_resume_requested.connect(_on_pause_resume_requested)
	hud.sfx_volume_changed.connect(_on_sfx_volume_changed)
	hud.music_volume_changed.connect(_on_music_volume_changed)

	enemy_spawner.enemy_reached_river.connect(_on_enemy_reached_river)
	enemy_spawner.enemy_defeated.connect(_on_enemy_defeated)
	enemy_spawner.wave_cleared.connect(_on_wave_cleared)
	enemy_spawner.wave_event_started.connect(_on_wave_event_started)
	enemy_spawner.enemy_warning.connect(_on_enemy_warning)
	enemy_spawner.boss_health_changed.connect(_on_boss_health_changed)
	enemy_spawner.boss_presence_changed.connect(_on_boss_presence_changed)
	enemy_spawner.boss_defeated.connect(_on_boss_defeated)

	hud.update_score(0)
	hud.update_wave(1)
	hud.update_pollution(0, pollution_core.max_pollution)
	hud.update_health(player.health, player.max_health)
	hud.update_special(true, 0.0)
	hud.update_power_up("")
	hud.hide_game_over()
	hud.show_start_menu()
	get_tree().paused = true

func _process(delta: float) -> void:
	_scroll_background(delta)
	_update_camera_motion(delta)
	_update_water_streaks(delta)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and game_started and not game_over:
		_toggle_pause()
		return

	if game_over and event.is_action_pressed("ui_accept"):
		_on_restart_requested()

func _setup_window() -> void:
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)

func _on_start_requested() -> void:
	game_started = true
	_play_sfx("ui_select", -4.0, 1.0)
	_start_music()
	get_tree().paused = false

func _on_quit_requested() -> void:
	get_tree().quit()

func _on_restart_requested() -> void:
	if not game_over:
		return

	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_enemy_defeated(score_value: int) -> void:
	game_manager.add_score(score_value)
	_shake_camera(0.08, 2.5)

func _on_wave_cleared() -> void:
	game_manager.next_wave()

func _on_wave_changed(wave: int) -> void:
	_play_sfx("wave_clear", -5.0, 1.0)
	_apply_biome_for_wave(wave)
	_update_music_state()
	background_scroll_speed = minf(
		background_base_scroll_speed + float(wave - 1) * background_speed_per_wave,
		background_max_scroll_speed
	)
	_create_wave_pulse()

func _on_wave_event_started(text: String) -> void:
	hud.show_wave_event(text)

func _on_enemy_warning(y_position: float, is_boss: bool) -> void:
	hud.show_danger_indicator(y_position, is_boss)

func _on_boss_health_changed(current: int, max_value: int) -> void:
	hud.update_boss_bar(current, max_value)

func _on_boss_presence_changed(active: bool) -> void:
	if active:
		_play_sfx("boss_warning", -2.0, 1.0)
		hud.show_boss_bar(1, 1)
	else:
		hud.hide_boss_bar()
	_update_music_state()

func _on_boss_defeated() -> void:
	if game_manager.has_method("request_bonus_reward"):
		get_tree().paused = true
		game_manager.call("request_bonus_reward")

func _on_enemy_reached_river(pollution_amount: int) -> void:
	pollution_core.add_pollution(pollution_amount)
	if game_manager.has_method("record_pollution_taken"):
		game_manager.call("record_pollution_taken")
	_play_sfx("pollution_hit", -2.0, 1.0)
	_create_pollution_hit_flash()

func _on_pollution_changed(_current: int, _max_value: int) -> void:
	_update_pollution_visual()
	_update_music_state()

func _on_upgrade_choices_requested(options: Array[String]) -> void:
	get_tree().paused = true
	hud.show_upgrade_choices(options)

func _on_upgrade_selected(kind: String) -> void:
	_play_sfx("powerup_collect", -4.0, 0.86)
	if game_manager.has_method("consume_mission_reward"):
		game_manager.call("consume_mission_reward")
	player.apply_permanent_upgrade(kind)
	get_tree().paused = false

func _on_player_health_changed(current: int, _max_value: int) -> void:
	if current < last_health:
		_shake_camera(0.16, 6.0)

	last_health = current

func _on_ecosystem_destroyed() -> void:
	_end_game("O rio foi tomado pela poluicao.")

func _on_player_died() -> void:
	_end_game("O boto nao conseguiu continuar.")

func _end_game(message: String) -> void:
	if game_over:
		return

	game_over = true
	var leaderboard: Array[Dictionary] = game_manager.load_leaderboard()
	hud.show_game_over(message, game_manager.score, leaderboard)
	_play_sfx("game_over", -2.0, 1.0)
	get_tree().paused = true

func _on_leaderboard_name_submitted(player_name: String) -> void:
	var leaderboard: Array[Dictionary] = game_manager.submit_score(player_name)
	hud.show_submitted_leaderboard(leaderboard)

func _toggle_pause() -> void:
	pause_open = not pause_open
	get_tree().paused = pause_open
	if pause_open:
		hud.show_pause_panel()
	else:
		hud.hide_pause_panel()

func _on_pause_resume_requested() -> void:
	if pause_open:
		_toggle_pause()

func _on_sfx_volume_changed(value: float) -> void:
	for manager in get_tree().get_nodes_in_group("audio_manager"):
		if manager.has_method("set_sfx_volume"):
			manager.call("set_sfx_volume", value)

func _on_music_volume_changed(value: float) -> void:
	for manager in get_tree().get_nodes_in_group("audio_manager"):
		if manager.has_method("set_music_volume"):
			manager.call("set_music_volume", value)

func _shake_camera(duration: float, strength: float) -> void:
	shake_time = maxf(shake_time, duration)
	shake_strength = maxf(shake_strength, strength)

func _update_camera_motion(delta: float) -> void:
	camera_sway_time += delta * camera_sway_speed
	var sway_offset: Vector2 = Vector2(
		sin(camera_sway_time) * camera_sway_x,
		cos(camera_sway_time * 1.35) * camera_sway_y
	)
	var shake_offset: Vector2 = Vector2.ZERO

	if shake_time > 0.0:
		shake_time -= delta
		shake_offset = Vector2(
			randf_range(-shake_strength, shake_strength),
			randf_range(-shake_strength, shake_strength)
		)
		shake_strength = lerp(shake_strength, 0.0, 0.18)

	camera.offset = sway_offset + shake_offset

func _scroll_background(delta: float) -> void:
	if background.texture == null:
		return

	var effective_width: float = _get_background_effective_width()
	var reset_x: float = background_center_x - effective_width

	background.position.x -= background_scroll_speed * delta
	background_loop.position.x -= background_scroll_speed * delta

	if background.position.x <= reset_x:
		background.position.x = background_loop.position.x + effective_width

	if background_loop.position.x <= reset_x:
		background_loop.position.x = background.position.x + effective_width

func _reset_background_loop() -> void:
	if background.texture == null:
		return

	var effective_width: float = _get_background_effective_width()
	background.position.x = background_center_x
	background.position.y = get_viewport_rect().size.y * 0.5
	background_loop.position.y = background.position.y
	background_loop.position.x = background_center_x + effective_width

func _get_background_effective_width() -> float:
	var texture_width: float = float(background.texture.get_width())
	return texture_width * background.scale.x - background_loop_overlap

func _layout_for_viewport() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	background_center_x = viewport_size.x * 0.5
	camera.position = viewport_size * 0.5

	if background.texture != null:
		var texture_size: Vector2 = Vector2(
			float(background.texture.get_width()),
			float(background.texture.get_height())
		)
		var cover_scale: float = maxf(
			viewport_size.x / texture_size.x,
			viewport_size.y / texture_size.y
		) * 1.08
		background.scale = Vector2(cover_scale, cover_scale)
		background_loop.scale = background.scale

	_reset_background_loop()

func _update_pollution_visual() -> void:
	var ratio: float = float(pollution_core.pollution) / float(pollution_core.max_pollution)
	var tint: Color = Color(1.0 - ratio * 0.22, 1.0 - ratio * 0.38, 1.0 - ratio * 0.18, 1.0)
	background.modulate = biome_tint * tint
	background_loop.modulate = biome_tint * tint

func _apply_biome_for_wave(wave: int) -> void:
	var biome: int = 1 + int(float(wave - 1) / 5.0)
	if biome == current_biome:
		return

	current_biome = biome
	var colors: Array[Color] = [
		Color(1.0, 1.0, 1.0, 1.0),
		Color(0.88, 1.0, 0.96, 1.0),
		Color(0.98, 0.9, 1.05, 1.0),
		Color(1.06, 0.9, 0.86, 1.0),
		Color(0.82, 0.92, 1.08, 1.0),
	]
	var index: int = mini(colors.size() - 1, biome - 1)
	biome_tint = colors[index]
	_update_pollution_visual()
	hud.show_wave_event("NOVO TRECHO DO RIO")

func _update_music_state() -> void:
	var pollution_ratio: float = float(pollution_core.pollution) / float(pollution_core.max_pollution)
	for manager in get_tree().get_nodes_in_group("audio_manager"):
		if manager.has_method("set_music_state"):
			manager.call("set_music_state", game_manager.wave, enemy_spawner.boss_active, pollution_ratio)

func _create_pollution_hit_flash() -> void:
	var flash: ColorRect = ColorRect.new()
	flash.color = Color(0.7, 0.08, 0.28, 0.0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.add_child(flash)

	var tween: Tween = get_tree().create_tween()
	tween.tween_property(flash, "color:a", 0.22, 0.04)
	tween.tween_property(flash, "color:a", 0.0, 0.18)
	tween.tween_callback(Callable(flash, "queue_free"))

func _create_wave_pulse() -> void:
	var pulse: ColorRect = ColorRect.new()
	pulse.color = Color(0.55, 0.92, 1.0, 0.12)
	pulse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pulse.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.add_child(pulse)

	var tween: Tween = get_tree().create_tween()
	tween.tween_property(pulse, "modulate:a", 0.0, 0.32)
	tween.tween_callback(Callable(pulse, "queue_free"))

func _update_water_streaks(delta: float) -> void:
	water_streak_timer = maxf(water_streak_timer - delta, 0.0)
	if water_streak_timer > 0.0:
		return

	water_streak_timer = randf_range(0.08, 0.18)
	_create_water_streak()

func _create_water_streak() -> void:
	var streak: Line2D = Line2D.new()
	var viewport_size: Vector2 = get_viewport_rect().size
	var min_y: float = 40.0
	var max_y: float = maxf(viewport_size.y - 45.0, min_y + 1.0)
	var y: float = randf_range(min_y, max_y)
	var length: float = randf_range(30.0, 95.0)
	streak.width = randf_range(1.0, 2.0)
	streak.default_color = Color(0.72, 0.95, 1.0, randf_range(0.12, 0.28))
	streak.add_point(Vector2(0.0, 0.0))
	streak.add_point(Vector2(length, 0.0))
	streak.global_position = Vector2(viewport_size.x + length, y)
	add_child(streak)

	var travel: float = viewport_size.x + length * 2.0
	var duration: float = travel / (background_scroll_speed * randf_range(1.6, 2.4))
	var tween: Tween = get_tree().create_tween()
	tween.tween_property(streak, "global_position", streak.global_position - Vector2(travel, 0.0), duration)
	tween.parallel().tween_property(streak, "modulate:a", 0.0, duration)
	tween.tween_callback(Callable(streak, "queue_free"))

func _play_sfx(sound_name: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	for manager in get_tree().get_nodes_in_group("audio_manager"):
		if manager.has_method("play"):
			manager.call("play", sound_name, volume_db, pitch)
			return

func _start_music() -> void:
	for manager in get_tree().get_nodes_in_group("audio_manager"):
		if manager.has_method("start_music"):
			manager.call("start_music")
			return
