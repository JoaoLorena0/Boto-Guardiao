extends Area2D

signal reached_river(pollution_amount: int)
signal died(score_value: int)
signal dropped_power_up(global_position: Vector2)
signal summoned_minion(global_position: Vector2)
signal health_changed(current: int, max_value: int)

const RISK_PEARL_SCRIPT: Script = preload("res://scripts/RiskPearl.gd")

@export var speed: float = 140.0
@export var hp: int = 2
@export var pollution_damage: int = 5
@export var score_value: int = 10
@export var contact_damage: int = 1
@export var movement_pattern: int = 0
@export var wave_amplitude: float = 38.0
@export var wave_frequency: float = 3.0
@export var drop_chance: float = 0.16
@export var is_boss: bool = false
@export_enum("basic", "fast", "tank", "shooter", "hunter", "boss") var enemy_role: String = "basic"

var defeated: bool = false
var visual: Sprite2D
var start_y: float = 0.0
var age: float = 0.0
var entered_screen: bool = false
var original_collision_layer: int = 0
var max_hp: int = 1
var burst_timer: float = 0.0
var burst_direction: float = 1.0
var shoot_timer: float = 0.0
var summon_timer: float = 2.4
var glow_ring: Polygon2D

func _ready() -> void:
	add_to_group("enemies")
	if is_boss:
		enemy_role = "boss"
	start_y = global_position.y
	max_hp = hp
	burst_timer = randf_range(0.2, 0.7)
	if randf() < 0.5:
		burst_direction = -1.0
	shoot_timer = randf_range(0.7, 1.8)
	original_collision_layer = collision_layer
	_update_screen_entry()
	body_entered.connect(_on_body_entered)
	visual = get_node_or_null("Visual") as Sprite2D
	if visual == null:
		visual = get_node_or_null("LixoSprite") as Sprite2D
	_create_enemy_glow()
	health_changed.emit(hp, max_hp)

func _process(delta: float) -> void:
	age += delta
	_move_enemy(delta)
	_update_screen_entry()
	_update_enemy_attack(delta)
	_update_enemy_glow()
	if is_instance_valid(visual):
		visual.rotation_degrees = sin(Time.get_ticks_msec() * 0.006 + global_position.y * 0.03) * 2.5

	if position.x < -80:
		reach_river()

func _move_enemy(delta: float) -> void:
	if movement_pattern == 1:
		position.x -= speed * delta
		position.y = start_y + sin(age * wave_frequency) * wave_amplitude
	elif movement_pattern == 2:
		position.x -= speed * delta
		position.y += sin(age * wave_frequency) * 95.0 * delta
	elif movement_pattern == 3:
		var boss_target_x: float = _get_play_area_size().x * 0.8
		if position.x > boss_target_x:
			position.x -= speed * delta
		var boss_phase_speed: float = _get_boss_phase_speed()
		position.y = start_y + sin(age * boss_phase_speed) * wave_amplitude
	elif movement_pattern == 4 or enemy_role == "hunter":
		position.x -= speed * delta
		_follow_player_y(delta)
	elif movement_pattern == 5:
		position.x -= speed * delta
		burst_timer -= delta
		position.y += burst_direction * 160.0 * delta
		if burst_timer <= 0.0:
			burst_timer = randf_range(0.28, 0.55)
			burst_direction *= -1.0
	else:
		position.x -= speed * delta

func take_damage(amount: int) -> void:
	if defeated or not entered_screen:
		return

	hp -= amount
	health_changed.emit(maxi(hp, 0), max_hp)
	_play_sfx("bullet_hit", -7.0, 1.0)
	_create_damage_number(amount)
	_create_hit_flash()

	if hp <= 0:
		die()

func reach_river() -> void:
	if defeated:
		return

	defeated = true
	reached_river.emit(pollution_damage)
	queue_free()

func die() -> void:
	if defeated:
		return

	defeated = true
	died.emit(score_value)
	if not is_boss and randf() <= drop_chance:
		dropped_power_up.emit(global_position)
	if not is_boss and randf() <= 0.55:
		_create_risk_pearl()
	_play_sfx(_get_death_sound_name(), -3.0, 1.0)
	_create_destruction_effect()
	queue_free()

func _update_screen_entry() -> void:
	if entered_screen:
		return

	var screen_width: float = _get_play_area_size().x
	if global_position.x <= screen_width:
		entered_screen = true
		collision_layer = original_collision_layer
	else:
		collision_layer = 0

func _follow_player_y(delta: float) -> void:
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return

	var player: Node2D = players[0] as Node2D
	if player == null:
		return

	var y_direction: float = sign(player.global_position.y - global_position.y)
	position.y += y_direction * speed * 0.55 * delta

func _get_boss_phase_speed() -> float:
	if not is_boss:
		return 1.4

	var hp_ratio: float = float(hp) / float(max_hp)
	if hp_ratio <= 0.33:
		speed = 150.0
		wave_amplitude = 155.0
		return 3.1
	elif hp_ratio <= 0.66:
		speed = 120.0
		wave_amplitude = 135.0
		return 2.2

	return 1.4

func _update_enemy_attack(delta: float) -> void:
	if defeated or not entered_screen:
		return

	shoot_timer -= delta
	if shoot_timer <= 0.0:
		if is_boss:
			_fire_boss_pattern()
		elif enemy_role == "shooter" or movement_pattern == 2:
			shoot_timer = randf_range(1.25, 2.15)
			_fire_enemy_projectile_after_warning(Vector2.LEFT, 1)
		else:
			shoot_timer = randf_range(1.8, 3.1)

	if is_boss:
		summon_timer -= delta
		if summon_timer <= 0.0:
			summon_timer = 2.6
			_create_boss_warning()
			summoned_minion.emit(global_position + Vector2(70.0, randf_range(-60.0, 60.0)))

	if enemy_role == "hunter" and is_instance_valid(visual):
		visual.modulate = Color(1.0, 0.55 + sin(age * 9.0) * 0.2, 1.0, 1.0)

func _fire_boss_pattern() -> void:
	var hp_ratio: float = float(hp) / float(max_hp)
	if hp_ratio <= 0.33:
		shoot_timer = 0.34
		for i in range(5):
			var angle: float = -0.42 + float(i) * 0.21
			_create_enemy_projectile(Vector2.LEFT.rotated(angle), contact_damage, i == 0)
	elif hp_ratio <= 0.66:
		shoot_timer = 0.52
		_create_boss_warning()
		_create_enemy_projectile(Vector2(-1.0, -0.34), contact_damage)
		_create_enemy_projectile(Vector2.LEFT, contact_damage, false)
		_create_enemy_projectile(Vector2(-1.0, 0.34), contact_damage, false)
	else:
		shoot_timer = 0.7
		_fire_enemy_projectile_after_warning(Vector2.LEFT, contact_damage)

func _fire_enemy_projectile_after_warning(direction: Vector2, damage: int) -> void:
	_create_shot_warning(direction)
	await get_tree().create_timer(0.24, false).timeout
	if not defeated and entered_screen:
		_create_enemy_projectile(direction, damage)

func _create_shot_warning(direction: Vector2) -> void:
	var warning: Line2D = Line2D.new()
	warning.width = 2.0
	warning.default_color = Color(1.0, 0.25, 0.55, 0.5)
	warning.add_point(Vector2.ZERO)
	warning.add_point(direction.normalized() * 170.0)
	warning.global_position = global_position + Vector2(-22.0, 0.0)
	get_tree().current_scene.add_child(warning)

	var tween: Tween = get_tree().create_tween()
	tween.tween_property(warning, "modulate:a", 0.0, 0.24)
	tween.tween_callback(Callable(warning, "queue_free"))

func _create_enemy_projectile(direction: Vector2, damage: int, play_sound: bool = true) -> void:
	if play_sound:
		_play_sfx("enemy_shoot", -8.0, 1.0)
	var projectile: Area2D = Area2D.new()
	projectile.collision_layer = 1
	projectile.collision_mask = 2
	projectile.global_position = global_position + Vector2(-28.0, 0.0)
	projectile.body_entered.connect(_on_enemy_projectile_body_entered.bind(projectile, damage))
	get_tree().current_scene.add_child(projectile)

	var shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = 7.0
	shape.shape = circle
	projectile.add_child(shape)

	var visual_bullet: Polygon2D = Polygon2D.new()
	visual_bullet.polygon = PackedVector2Array([
		Vector2(-8, -4),
		Vector2(8, 0),
		Vector2(-8, 4),
	])
	visual_bullet.color = Color(0.78, 0.2, 0.55, 0.9)
	projectile.add_child(visual_bullet)

	var travel: Vector2 = direction.normalized() * 980.0
	var tween: Tween = get_tree().create_tween()
	tween.tween_property(projectile, "global_position", projectile.global_position + travel, 3.0)
	tween.tween_callback(Callable(projectile, "queue_free"))

func _create_damage_number(amount: int) -> void:
	var label: Label = Label.new()
	label.text = str(amount)
	label.global_position = global_position + Vector2(randf_range(-8.0, 8.0), -26.0)
	label.modulate = Color(1.0, 0.9, 0.45, 1.0)
	get_tree().current_scene.add_child(label)

	var tween: Tween = get_tree().create_tween()
	tween.tween_property(label, "global_position", label.global_position + Vector2(0.0, -22.0), 0.28)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.28)
	tween.tween_callback(Callable(label, "queue_free"))

func _create_risk_pearl() -> void:
	var pearl: Area2D = Area2D.new()
	pearl.set_script(RISK_PEARL_SCRIPT)
	pearl.global_position = global_position + Vector2(randf_range(-18.0, 18.0), randf_range(-18.0, 18.0))
	pearl.set("score_value", 8)
	get_tree().current_scene.call_deferred("add_child", pearl)

func _on_enemy_projectile_body_entered(body: Node2D, projectile: Area2D, damage: int) -> void:
	if body.has_method("take_hit"):
		body.call("take_hit", damage)
	if is_instance_valid(projectile):
		projectile.queue_free()

func _create_boss_warning() -> void:
	_play_sfx("boss_warning", -4.0, 1.0)
	var warning: Line2D = Line2D.new()
	warning.width = 2.0
	warning.default_color = Color(1.0, 0.32, 0.55, 0.45)
	warning.add_point(Vector2(-90.0, 0.0))
	warning.add_point(Vector2(90.0, 0.0))
	warning.global_position = global_position + Vector2(-80.0, randf_range(-80.0, 80.0))
	get_tree().current_scene.add_child(warning)

	var tween: Tween = get_tree().create_tween()
	tween.tween_property(warning, "modulate:a", 0.0, 0.45)
	tween.tween_callback(Callable(warning, "queue_free"))

func _create_enemy_glow() -> void:
	glow_ring = Polygon2D.new()
	glow_ring.z_index = -1
	if is_boss:
		glow_ring.polygon = _make_glow_points(58.0, 22)
	else:
		glow_ring.polygon = _make_glow_points(24.0, 18)
	glow_ring.color = _get_enemy_glow_color(0.2)
	add_child(glow_ring)
	move_child(glow_ring, 0)

func _update_enemy_glow() -> void:
	if not is_instance_valid(glow_ring):
		return

	var pulse: float = 1.0 + sin(age * 5.0) * 0.14
	if is_boss:
		pulse = 1.0 + sin(age * 6.5) * 0.2
	glow_ring.scale = Vector2(pulse, pulse)
	glow_ring.rotation = -rotation
	glow_ring.color = _get_enemy_glow_color(0.16 + sin(age * 4.0) * 0.06)

func _make_glow_points(radius: float, count: int) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for i in range(count):
		var angle: float = TAU * float(i) / float(count)
		points.append(Vector2(cos(angle), sin(angle)) * radius)

	return points

func _get_enemy_glow_color(alpha: float) -> Color:
	var blend: float = (sin(age * 3.0) + 1.0) * 0.5
	var red: Color = Color(1.0, 0.12, 0.18, alpha)
	var purple: Color = Color(0.55, 0.18, 1.0, alpha)
	if is_boss:
		return red.lerp(purple, blend) * Color(1.15, 1.0, 1.25, 1.0)

	return red.lerp(purple, blend)

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("take_hit"):
		body.call("take_hit", contact_damage)
		reach_river()

func _get_play_area_size() -> Vector2:
	return get_viewport_rect().size

func _create_hit_flash() -> void:
	if not is_instance_valid(visual):
		return

	visual.modulate = Color(1.0, 1.0, 1.0, 1.0)
	var tween: Tween = get_tree().create_tween()
	tween.tween_property(visual, "modulate", Color(1.0, 0.55, 0.55, 1.0), 0.04)
	tween.tween_property(visual, "modulate", Color.WHITE, 0.08)

func _create_destruction_effect() -> void:
	var burst: Node2D = Node2D.new()
	burst.global_position = global_position
	get_tree().current_scene.add_child(burst)

	var particle_count: int = _get_death_particle_count()
	for i in range(particle_count):
		var shard: Polygon2D = Polygon2D.new()
		var size: float = randf_range(3.0, _get_death_particle_size())
		shard.polygon = _get_death_particle_shape(size, i)
		var shard_colors: Array[Color] = _get_death_particle_colors()
		var color_index: int = randi_range(0, shard_colors.size() - 1)
		shard.rotation = randf() * TAU
		shard.color = shard_colors[color_index]
		burst.add_child(shard)

		var direction: Vector2 = Vector2.RIGHT.rotated(TAU * float(i) / float(particle_count) + randf_range(-0.25, 0.25))
		var tween: Tween = get_tree().create_tween()
		tween.tween_property(shard, "position", direction * randf_range(24.0, _get_death_particle_distance()), 0.24)
		tween.parallel().tween_property(shard, "rotation", shard.rotation + randf_range(-2.5, 2.5), 0.24)
		tween.parallel().tween_property(shard, "modulate:a", 0.0, 0.24)

	var flash: Polygon2D = Polygon2D.new()
	flash.polygon = PackedVector2Array([
		Vector2(0, -24),
		Vector2(10, -8),
		Vector2(28, 0),
		Vector2(10, 8),
		Vector2(0, 24),
		Vector2(-10, 8),
		Vector2(-28, 0),
		Vector2(-10, -8),
	])
	flash.color = Color(1.0, 0.95, 0.5, 0.85)
	burst.add_child(flash)

	var score_label: Label = Label.new()
	score_label.text = "+%d" % score_value
	score_label.position = Vector2(-14, -34)
	score_label.modulate = Color(0.9, 1.0, 0.55, 1.0)
	burst.add_child(score_label)

	var flash_tween: Tween = get_tree().create_tween()
	flash_tween.tween_property(flash, "scale", Vector2(1.5, 1.5), 0.12)
	flash_tween.parallel().tween_property(flash, "modulate:a", 0.0, 0.12)

	var label_tween: Tween = get_tree().create_tween()
	label_tween.tween_property(score_label, "position", score_label.position + Vector2(0, -24), 0.35)
	label_tween.parallel().tween_property(score_label, "modulate:a", 0.0, 0.35)

	var cleanup: Tween = get_tree().create_tween()
	cleanup.tween_interval(0.4)
	cleanup.tween_callback(Callable(burst, "queue_free"))

func _get_death_particle_count() -> int:
	if enemy_role == "fast":
		return 10
	elif enemy_role == "tank":
		return 20
	elif enemy_role == "shooter":
		return 16
	elif enemy_role == "hunter":
		return 14
	elif enemy_role == "boss":
		return 28

	return 12

func _get_death_particle_size() -> float:
	if enemy_role == "tank":
		return 10.0
	elif enemy_role == "boss":
		return 12.0
	elif enemy_role == "fast":
		return 5.0

	return 7.0

func _get_death_particle_distance() -> float:
	if enemy_role == "fast":
		return 78.0
	elif enemy_role == "tank":
		return 48.0
	elif enemy_role == "boss":
		return 95.0

	return 62.0

func _get_death_particle_colors() -> Array[Color]:
	if enemy_role == "fast":
		return [Color(0.72, 0.95, 1.0), Color(0.85, 0.35, 0.8), Color(0.55, 0.28, 0.85)]
	elif enemy_role == "tank":
		return [Color(0.38, 0.28, 0.58), Color(0.62, 0.68, 0.72), Color(0.18, 0.5, 0.62)]
	elif enemy_role == "shooter":
		return [Color(1.0, 0.22, 0.55), Color(0.95, 0.72, 0.25), Color(0.45, 0.9, 0.9)]
	elif enemy_role == "hunter":
		return [Color(0.72, 0.24, 1.0), Color(0.26, 0.85, 0.95), Color(1.0, 0.32, 0.42)]
	elif enemy_role == "boss":
		return [Color(1.0, 0.12, 0.32), Color(0.55, 0.18, 1.0), Color(1.0, 0.86, 0.28)]

	return [Color(0.95, 0.35, 0.18), Color(1.0, 0.78, 0.25), Color(0.45, 0.85, 0.7)]

func _get_death_particle_shape(size: float, index: int) -> PackedVector2Array:
	if enemy_role == "tank":
		return PackedVector2Array([
			Vector2(-size, -size * 0.6),
			Vector2(size, -size * 0.45),
			Vector2(size * 0.7, size * 0.55),
			Vector2(-size * 0.8, size * 0.45),
		])
	elif enemy_role == "shooter" and index % 3 == 0:
		return PackedVector2Array([
			Vector2(0.0, -size),
			Vector2(size * 0.45, 0.0),
			Vector2(0.0, size),
			Vector2(-size * 0.45, 0.0),
		])

	return PackedVector2Array([
		Vector2(-size, -size * 0.5),
		Vector2(size, 0.0),
		Vector2(-size, size * 0.5),
	])

func _get_death_sound_name() -> String:
	if enemy_role == "fast":
		return "enemy_die_fast"
	elif enemy_role == "tank":
		return "enemy_die_tank"
	elif enemy_role == "shooter":
		return "enemy_die_shooter"
	elif enemy_role == "hunter":
		return "enemy_die_hunter"
	elif enemy_role == "boss":
		return "enemy_die_boss"

	return "enemy_die_fast"

func _play_sfx(sound_name: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	for manager in get_tree().get_nodes_in_group("audio_manager"):
		if manager.has_method("play"):
			manager.call("play", sound_name, volume_db, pitch)
			return
