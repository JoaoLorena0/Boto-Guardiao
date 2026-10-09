extends Node2D
class_name EnemySpawner

signal enemy_reached_river(pollution_amount: int)
signal enemy_defeated(score_value: int)
signal wave_cleared
signal wave_event_started(text: String)
signal enemy_warning(y_position: float, is_boss: bool)
signal boss_health_changed(current: int, max_value: int)
signal boss_presence_changed(active: bool)
signal boss_defeated

@export var enemy_scenes: Array[PackedScene]
@export var boss_scene: PackedScene
@export var power_up_scene: PackedScene
@export var spawn_interval: float = 1.8
@export var min_spawn_interval: float = 0.32
@export var spawn_margin: float = 48.0
@export var power_up_interval: float = 26.0
@export var base_wave_enemies: int = 7
@export var enemies_per_wave: int = 4
@export var wave_enemy_growth: int = 1
@export var weak_only_waves: int = 2

var active: bool = true
var current_wave: int = 1
var current_chapter: int = 1
var boss_active: bool = false
var enemies_to_spawn: int = 0
var total_wave_enemies: int = 0
var active_enemies: int = 0
var spawning_wave: bool = false
var wave_clear_emitted: bool = false
var current_wave_event: String = ""
var strategic_power_up_spawned: bool = false

func _ready() -> void:
	randomize()
	await get_tree().process_frame
	start_wave(current_wave)
	power_up_loop()

func start_wave(wave: int) -> void:
	current_wave = wave
	current_chapter = 1 + int(float(wave - 1) / 5.0)
	current_wave_event = _get_wave_event(wave)
	var wave_index: int = wave - 1
	var chapter_wave: int = ((wave - 1) % 5) + 1
	enemies_to_spawn = base_wave_enemies + (chapter_wave - 1) * enemies_per_wave + (current_chapter - 1) * 5 + wave_index * wave_enemy_growth
	total_wave_enemies = enemies_to_spawn
	active_enemies = 0
	spawning_wave = true
	wave_clear_emitted = false
	strategic_power_up_spawned = false
	spawn_interval = maxf(min_spawn_interval, 1.25 - float(current_chapter - 1) * 0.14 - float(chapter_wave - 1) * 0.07)
	if current_wave_event == "swarm":
		spawn_interval = maxf(min_spawn_interval, spawn_interval * 0.65)
	elif current_wave_event == "current":
		spawn_interval = maxf(min_spawn_interval, spawn_interval * 0.85)

	if wave % 5 == 0:
		current_wave_event = "boss"
		enemies_to_spawn = 0
		spawn_boss()
		spawning_wave = false
		_check_wave_clear()
		return

	_emit_wave_event()
	spawn_wave_loop()

func spawn_wave_loop() -> void:
	while active and spawning_wave and enemies_to_spawn > 0:
		while get_tree().paused:
			await get_tree().process_frame
		var spawn_count: int = mini(_get_spawn_batch_size(), enemies_to_spawn)
		for i in range(spawn_count):
			spawn_enemy()
			enemies_to_spawn -= 1
		_try_spawn_strategic_power_up()
		await get_tree().create_timer(spawn_interval, false).timeout

	spawning_wave = false
	_check_wave_clear()

func power_up_loop() -> void:
	while active:
		await get_tree().create_timer(power_up_interval, false).timeout
		if not spawning_wave and not boss_active:
			spawn_power_up()

func spawn_enemy() -> void:
	if enemy_scenes.is_empty():
		return

	var enemy_index: int = _pick_enemy_index()
	var enemy_scene: PackedScene = enemy_scenes[enemy_index]
	var enemy: Area2D = enemy_scene.instantiate() as Area2D
	if enemy == null:
		return

	var screen_size: Vector2 = _get_play_area_size()
	var screen_width: float = screen_size.x
	var screen_height: float = screen_size.y

	enemy.global_position = Vector2(screen_width + 40, randf_range(spawn_margin, screen_height - spawn_margin))
	_apply_wave_event(enemy)
	_apply_chapter_scaling(enemy)
	enemy_warning.emit(enemy.global_position.y, false)

	if enemy.has_signal("reached_river"):
		enemy.reached_river.connect(_on_enemy_reached_river)

	if enemy.has_signal("died"):
		enemy.died.connect(_on_enemy_died)

	if enemy.has_signal("dropped_power_up"):
		enemy.dropped_power_up.connect(_on_enemy_dropped_power_up)

	active_enemies += 1
	get_tree().current_scene.call_deferred("add_child", enemy)

func _get_available_enemy_count() -> int:
	if current_wave <= weak_only_waves:
		return 1
	if current_chapter == 1:
		return mini(enemy_scenes.size(), 2)
	elif current_chapter == 2:
		return mini(enemy_scenes.size(), 3)

	return enemy_scenes.size()

func _pick_enemy_index() -> int:
	var available_enemy_count: int = _get_available_enemy_count()
	if available_enemy_count <= 1:
		return 0

	var roll: float = randf()
	if current_chapter == 1:
		if roll < 0.72:
			return 0
		return 1
	elif current_chapter == 2:
		if roll < 0.45:
			return 0
		elif roll < 0.78:
			return 1
		return 2

	if current_wave_event == "hunt" and available_enemy_count >= 4:
		if roll < 0.42:
			return 3
		elif roll < 0.62:
			return 0
		elif roll < 0.82:
			return 1
		return 2

	if current_wave_event == "swarm":
		if roll < 0.52:
			return 0
		elif roll < 0.76:
			return 3
		elif roll < 0.9:
			return 1
		return 2

	if roll < 0.32:
		return 0
	elif roll < 0.56:
		return 1
	elif roll < 0.78:
		return 2

	return 3

func _get_wave_event(wave: int) -> String:
	if wave <= 2:
		return ""
	if wave % 5 == 0:
		return "boss"
	if wave % 4 == 0:
		return "swarm"
	if wave % 3 == 0:
		return "current"
	if wave >= 6 and wave % 2 == 0:
		return "hunt"

	return ""

func _emit_wave_event() -> void:
	if current_wave_event == "swarm":
		wave_event_started.emit("ENXAME DE LIXO")
	elif current_wave_event == "current":
		wave_event_started.emit("CORRENTEZA FORTE")
	elif current_wave_event == "hunt":
		wave_event_started.emit("INIMIGOS CACADORES")

func _get_spawn_batch_size() -> int:
	if current_wave_event == "swarm":
		return 3
	if current_chapter >= 3:
		return 3
	if current_chapter >= 2 or current_wave >= 3:
		return 2

	return 1

func _apply_wave_event(enemy: Area2D) -> void:
	if current_wave_event == "current":
		var current_speed: float = float(enemy.get("speed"))
		enemy.set("speed", current_speed * 1.35)
		enemy.set("movement_pattern", randi_range(1, 2))
	elif current_wave_event == "hunt":
		var hunt_speed: float = float(enemy.get("speed"))
		enemy.set("speed", hunt_speed * 1.24)
		enemy.set("movement_pattern", 4)
	elif current_wave_event == "swarm":
		var swarm_speed: float = float(enemy.get("speed"))
		enemy.set("speed", swarm_speed * 1.28)
		if randf() < 0.65:
			enemy.set("movement_pattern", 5)

func _apply_chapter_scaling(enemy: Area2D) -> void:
	if current_wave <= 5:
		return

	var role: String = str(enemy.get("enemy_role"))
	var hp_bonus: int = _get_enemy_hp_bonus(role)
	if hp_bonus <= 0:
		return

	var base_hp: int = int(enemy.get("hp"))
	var base_score: int = int(enemy.get("score_value"))
	enemy.set("hp", base_hp + hp_bonus)
	enemy.set("score_value", base_score + hp_bonus * 4)

func _get_enemy_hp_bonus(role: String) -> int:
	var chapter_bonus: int = current_chapter - 1
	var chapter_wave: int = ((current_wave - 1) % 5) + 1
	var within_chapter_bonus: int = int(float(chapter_wave - 1) / 2.0)
	var pressure: int = chapter_bonus + within_chapter_bonus

	if role == "fast":
		return mini(pressure, 5)
	elif role == "shooter":
		return pressure + maxi(current_chapter - 2, 0)
	elif role == "hunter":
		return pressure + maxi(current_chapter - 2, 0)
	elif role == "tank":
		return pressure * 2 + maxi(current_chapter - 2, 0)
	elif role == "boss":
		return (current_chapter - 1) * 18

	return pressure

func spawn_power_up(at_position: Vector2 = Vector2.INF) -> void:
	if power_up_scene == null:
		return

	var power_up: Area2D = power_up_scene.instantiate() as Area2D
	if power_up == null:
		return
	power_up.set("kind", _choose_power_up_kind())

	var screen_size: Vector2 = _get_play_area_size()
	var screen_width: float = screen_size.x
	var screen_height: float = screen_size.y
	if at_position == Vector2.INF:
		power_up.global_position = Vector2(screen_width + 40.0, randf_range(spawn_margin, screen_height - spawn_margin))
	else:
		power_up.global_position = at_position

	get_tree().current_scene.call_deferred("add_child", power_up)

func _try_spawn_strategic_power_up() -> void:
	if strategic_power_up_spawned or total_wave_enemies <= 0:
		return

	var remaining_ratio: float = float(enemies_to_spawn) / float(total_wave_enemies)
	if remaining_ratio <= 0.5:
		strategic_power_up_spawned = true
		spawn_power_up(Vector2(_get_play_area_size().x + 45.0, randf_range(spawn_margin, _get_play_area_size().y - spawn_margin)))

func _choose_power_up_kind() -> String:
	var scene: Node = get_tree().current_scene
	if scene != null:
		var pollution_core: Node = scene.get_node_or_null("PollutionCore")
		if pollution_core != null:
			var pollution: int = int(pollution_core.get("pollution"))
			var max_pollution: int = int(pollution_core.get("max_pollution"))
			if pollution >= int(float(max_pollution) * 0.42):
				return "clean"

	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		var player: Node = players[0]
		if int(player.get("health")) < int(player.get("max_health")):
			return "health"

	if current_wave % 5 == 4:
		return "shield"
	elif current_wave_event == "swarm":
		return "spread"
	elif current_wave_event == "hunt":
		return "rapid"

	var kinds: Array[String] = ["rapid", "spread", "shield", "health"]
	var kind_index: int = randi_range(0, kinds.size() - 1)
	return kinds[kind_index]

func spawn_boss() -> void:
	if boss_scene == null or boss_active:
		return

	var boss: Area2D = boss_scene.instantiate() as Area2D
	if boss == null:
		return

	var screen_size: Vector2 = _get_play_area_size()
	var screen_width: float = screen_size.x
	var screen_height: float = screen_size.y
	boss.global_position = Vector2(screen_width + 120.0, screen_height * 0.5)
	boss.set("enemy_role", "boss")
	_apply_chapter_scaling(boss)
	boss_active = true
	active_enemies = 1
	enemy_warning.emit(boss.global_position.y, true)
	boss_presence_changed.emit(true)

	if boss.has_signal("reached_river"):
		boss.reached_river.connect(_on_enemy_reached_river)

	if boss.has_signal("died"):
		boss.died.connect(_on_boss_died)

	if boss.has_signal("summoned_minion"):
		boss.summoned_minion.connect(_on_boss_summoned_minion)

	if boss.has_signal("health_changed"):
		boss.health_changed.connect(_on_boss_health_changed)

	get_tree().current_scene.call_deferred("add_child", boss)

func _on_enemy_reached_river(pollution_amount: int) -> void:
	active_enemies = maxi(active_enemies - 1, 0)
	enemy_reached_river.emit(pollution_amount)
	_check_wave_clear()

func _on_enemy_died(score_value: int) -> void:
	active_enemies = maxi(active_enemies - 1, 0)
	enemy_defeated.emit(score_value)
	_check_wave_clear()

func set_difficulty(wave: int) -> void:
	start_wave(wave)

func _on_enemy_dropped_power_up(drop_position: Vector2) -> void:
	spawn_power_up(drop_position)

func _on_boss_died(score_value: int) -> void:
	boss_active = false
	active_enemies = maxi(active_enemies - 1, 0)
	enemy_defeated.emit(score_value)
	boss_presence_changed.emit(false)
	boss_defeated.emit()
	var screen_size: Vector2 = _get_play_area_size()
	spawn_power_up(Vector2(screen_size.x * 0.65, screen_size.y * 0.5))
	_check_wave_clear()

func _on_boss_health_changed(current: int, max_value: int) -> void:
	boss_health_changed.emit(current, max_value)

func _on_boss_summoned_minion(spawn_position: Vector2) -> void:
	if enemy_scenes.is_empty():
		return

	var enemy_scene: PackedScene = enemy_scenes[0]
	var enemy: Area2D = enemy_scene.instantiate() as Area2D
	if enemy == null:
		return

	enemy.global_position = spawn_position
	enemy.set("speed", float(enemy.get("speed")) * 1.2)
	enemy.set("movement_pattern", 4)
	enemy.set("enemy_role", "hunter")
	_apply_chapter_scaling(enemy)
	enemy_warning.emit(enemy.global_position.y, false)

	if enemy.has_signal("reached_river"):
		enemy.reached_river.connect(_on_enemy_reached_river)

	if enemy.has_signal("died"):
		enemy.died.connect(_on_enemy_died)

	if enemy.has_signal("dropped_power_up"):
		enemy.dropped_power_up.connect(_on_enemy_dropped_power_up)

	active_enemies += 1
	get_tree().current_scene.call_deferred("add_child", enemy)

func _check_wave_clear() -> void:
	if spawning_wave:
		return

	if enemies_to_spawn <= 0 and active_enemies <= 0 and not boss_active and not wave_clear_emitted:
		wave_clear_emitted = true
		wave_cleared.emit()

func _get_play_area_size() -> Vector2:
	return get_viewport_rect().size
