extends CharacterBody2D
class_name PlayerController

signal health_changed(current: int, max_value: int)
signal died
signal special_changed(ready: bool, cooldown_left: float)
signal power_up_changed(text: String)

@export var speed: float = 420.0
@export var bullet_scene: PackedScene
@export var fire_rate: float = 0.5
@export var max_health: int = 2
@export var invulnerability_time: float = 0.55
@export var dash_speed: float = 900.0
@export var dash_duration: float = 0.16
@export var dash_cooldown: float = 1.15
@export var special_cooldown: float = 8.0

@onready var fire_point: Marker2D = $FirePoint
@onready var sprite: Sprite2D = $Boto

var can_shoot: bool = true
var vulnerable: bool = true
var health: int = 0
var screen_size: Vector2
var move_direction: Vector2 = Vector2.RIGHT
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var special_cooldown_timer: float = 0.0
var spread_timer: float = 0.0
var rapid_timer: float = 0.0
var shield_timer: float = 0.0
var spread_level: int = 1
var power_up_text: String = ""
var permanent_spread_level: int = 1
var bullet_damage: int = 1
var special_damage: int = 3
var bubble_emit_timer: float = 0.0
var bubble_emit_interval: float = 0.08
var explosive_bubbles: bool = false
var damaging_dash_trail: bool = false
var shield_heals: bool = false
var river_burst: bool = false

func _ready() -> void:
	add_to_group("player")
	screen_size = _get_play_area_size()
	health = max_health
	health_changed.emit(health, max_health)
	special_changed.emit(true, 0.0)
	power_up_changed.emit("")

func _physics_process(delta: float) -> void:
	_update_timers(delta)
	move_player(delta)
	_update_bubble_trail(delta)
	handle_shoot()
	handle_dash()
	handle_special()

func move_player(delta: float) -> void:
	screen_size = _get_play_area_size()
	var direction: Vector2 = Vector2.ZERO

	direction.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	direction.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")

	if direction.length() > 0:
		direction = direction.normalized()
		move_direction = direction

	if dash_timer > 0.0:
		velocity = move_direction * dash_speed
		dash_timer -= delta
	else:
		velocity = direction * speed

	move_and_slide()

	global_position.x = clampf(global_position.x, 24.0, screen_size.x - 24.0)
	global_position.y = clampf(global_position.y, 24.0, screen_size.y - 24.0)

	var target_tilt: float = clampf(velocity.y * 0.045, -10.0, 10.0)
	sprite.rotation_degrees = lerp(sprite.rotation_degrees, target_tilt, 0.22)
	sprite.position.y = sin(Time.get_ticks_msec() * 0.008) * 1.5

func handle_shoot() -> void:
	if Input.is_action_pressed("shoot") and can_shoot:
		shoot()

func handle_dash() -> void:
	if Input.is_action_just_pressed("dash") and dash_cooldown_timer <= 0.0:
		dash_timer = dash_duration
		dash_cooldown_timer = dash_cooldown
		vulnerable = false
		_play_sfx("ui_select", -7.0, 0.78)
		_create_dash_afterimage()
		if damaging_dash_trail:
			_create_dash_damage_trail()
		await get_tree().create_timer(dash_duration + 0.05, false).timeout
		if shield_timer <= 0.0:
			vulnerable = true

func handle_special() -> void:
	if Input.is_action_just_pressed("special") and special_cooldown_timer <= 0.0:
		special_cooldown_timer = special_cooldown
		special_changed.emit(false, special_cooldown_timer)
		_play_sfx("special_cast", -1.0, 1.0)
		_cast_special_wave()

func shoot() -> void:
	if bullet_scene == null:
		return

	can_shoot = false
	_play_sfx("player_shoot", -4.0, 1.0)
	_spawn_bullet(Vector2.RIGHT)
	var active_spread_level: int = maxi(spread_level, permanent_spread_level)
	if active_spread_level >= 2:
		_spawn_bullet(Vector2(1.0, -0.18))
		_spawn_bullet(Vector2(1.0, 0.18))
	if active_spread_level >= 3:
		_spawn_bullet(Vector2(1.0, -0.34))
		_spawn_bullet(Vector2(1.0, 0.34))
	if active_spread_level >= 4:
		_spawn_bullet(Vector2(1.0, -0.5))
		_spawn_bullet(Vector2(1.0, 0.5))
	if active_spread_level >= 5:
		_spawn_bullet(Vector2.RIGHT, true)
	_create_muzzle_flash()

	var current_fire_rate: float = fire_rate
	if rapid_timer > 0.0:
		current_fire_rate = fire_rate * 0.45

	await get_tree().create_timer(current_fire_rate, false).timeout
	can_shoot = true

func _spawn_bullet(direction: Vector2, piercing: bool = false) -> void:
	var bullet: Node2D = bullet_scene.instantiate() as Node2D
	if bullet == null:
		return

	bullet.global_position = fire_point.global_position
	if bullet.has_method("setup"):
		bullet.call("setup", direction, bullet_damage, 560.0, piercing, explosive_bubbles)
	get_tree().current_scene.add_child(bullet)

func take_hit(amount: int = 1) -> void:
	if not vulnerable or shield_timer > 0.0:
		_create_shield_flash()
		_play_sfx("bullet_hit", -5.0, 0.74)
		if shield_heals and health < max_health:
			health = mini(health + 1, max_health)
			health_changed.emit(health, max_health)
		return

	health = maxi(health - amount, 0)
	health_changed.emit(health, max_health)
	_play_sfx("player_hit", -1.0, 1.0)
	_create_damage_flash()
	global_position.x = maxf(global_position.x - 18.0, 24.0)

	if health <= 0:
		died.emit()
		return

	_start_invulnerability()

func _start_invulnerability() -> void:
	vulnerable = false
	sprite.modulate = Color(1.0, 1.0, 1.0, 0.45)
	await get_tree().create_timer(invulnerability_time, false).timeout
	sprite.modulate = Color.WHITE
	vulnerable = true

func apply_power_up(kind: String) -> void:
	if kind == "health":
		health = mini(health + 1, max_health)
		health_changed.emit(health, max_health)
		_set_power_up_text("Vida +1")
	elif kind == "rapid":
		rapid_timer = 5.2
		_set_power_up_text("Tiro rapido")
	elif kind == "spread":
		spread_level = mini(spread_level + 1, 3)
		spread_timer = 6.4
		_set_power_up_text("Tiro aberto")
	elif kind == "shield":
		shield_timer = 4.2
		vulnerable = false
		_set_power_up_text("Escudo")
	elif kind == "clean":
		_set_power_up_text("Rio limpo")

func apply_permanent_upgrade(kind: String) -> void:
	var rarity: String = _get_upgrade_rarity(kind)
	var base_kind: String = _get_upgrade_kind(kind)
	var tier: int = _get_upgrade_tier(rarity)

	if base_kind == "max_health":
		max_health += tier
		health = max_health
		health_changed.emit(health, max_health)
		_set_power_up_text("Vida maxima +" + str(tier))
	elif base_kind == "fire_rate":
		fire_rate = maxf(fire_rate * (0.9 - float(tier) * 0.06), 0.12)
		_set_power_up_text("Cadencia +" + str(tier))
	elif base_kind == "spread":
		permanent_spread_level = mini(permanent_spread_level + tier, 5)
		spread_level = maxi(spread_level, permanent_spread_level)
		_set_power_up_text("Tiro aberto +" + str(tier))
	elif base_kind == "damage":
		bullet_damage += tier
		_set_power_up_text("Dano +" + str(tier))
	elif base_kind == "special":
		special_damage += tier
		special_cooldown = maxf(special_cooldown * (0.94 - float(tier) * 0.08), 2.0)
		_set_power_up_text("Especial +" + str(tier))
	elif base_kind == "dash":
		dash_cooldown = maxf(dash_cooldown * (0.88 - float(tier) * 0.08), 0.18)
		dash_duration = minf(dash_duration + 0.02 * float(tier), 0.34)
		_set_power_up_text("Dash +" + str(tier))
	elif base_kind == "bubble_explosion":
		explosive_bubbles = true
		bullet_damage += tier
		_set_power_up_text("Bolhas explosivas")
	elif base_kind == "dash_trail":
		damaging_dash_trail = true
		dash_cooldown = maxf(dash_cooldown * 0.86, 0.18)
		_set_power_up_text("Rastro de dash")
	elif base_kind == "shield_heal":
		shield_heals = true
		max_health += 1
		health = max_health
		health_changed.emit(health, max_health)
		_set_power_up_text("Escudo cura")
	elif base_kind == "river_burst":
		river_burst = true
		special_damage += tier
		_set_power_up_text("Especial purifica")

func _get_upgrade_rarity(kind: String) -> String:
	var parts: PackedStringArray = kind.split(":")
	if parts.size() >= 2:
		return parts[0]

	return "comum"

func _get_upgrade_kind(kind: String) -> String:
	var parts: PackedStringArray = kind.split(":")
	if parts.size() >= 2:
		return parts[1]

	return kind

func _get_upgrade_tier(rarity: String) -> int:
	if rarity == "lendario":
		return 3
	elif rarity == "raro":
		return 2

	return 1

func _update_timers(delta: float) -> void:
	dash_cooldown_timer = maxf(dash_cooldown_timer - delta, 0.0)

	if special_cooldown_timer > 0.0:
		var was_cooling_down: bool = special_cooldown_timer > 0.0
		special_cooldown_timer = maxf(special_cooldown_timer - delta, 0.0)
		special_changed.emit(special_cooldown_timer <= 0.0, special_cooldown_timer)
		if was_cooling_down and special_cooldown_timer <= 0.0:
			_play_sfx("special_ready", -3.0, 1.0)

	if rapid_timer > 0.0:
		rapid_timer = maxf(rapid_timer - delta, 0.0)

	if spread_timer > 0.0:
		spread_timer = maxf(spread_timer - delta, 0.0)
		if spread_timer <= 0.0:
			spread_level = permanent_spread_level

	if shield_timer > 0.0:
		shield_timer = maxf(shield_timer - delta, 0.0)
		sprite.modulate = Color(0.65, 1.0, 1.0, 0.95)
		if shield_timer <= 0.0:
			sprite.modulate = Color.WHITE
			vulnerable = true

	if rapid_timer <= 0.0 and spread_timer <= 0.0 and shield_timer <= 0.0 and power_up_text != "":
		_set_power_up_text("")

func _set_power_up_text(text: String) -> void:
	power_up_text = text
	power_up_changed.emit(power_up_text)

func _cast_special_wave() -> void:
	var wave: Polygon2D = Polygon2D.new()
	wave.global_position = global_position + Vector2(34, 0)
	wave.polygon = PackedVector2Array([
		Vector2(0, -70),
		Vector2(250, -24),
		Vector2(250, 24),
		Vector2(0, 70),
	])
	wave.color = Color(0.55, 0.95, 1.0, 0.38)
	get_tree().current_scene.add_child(wave)

	for enemy in get_tree().get_nodes_in_group("enemies"):
		var area: Area2D = enemy as Area2D
		if area != null and area.global_position.x > global_position.x - 20:
			area.call("take_damage", special_damage)
	if river_burst:
		var pollution_core: Node = get_tree().current_scene.get_node_or_null("PollutionCore")
		if pollution_core != null and pollution_core.has_method("reduce_pollution"):
			pollution_core.call("reduce_pollution", 8)

	var tween: Tween = get_tree().create_tween()
	tween.tween_property(wave, "scale", Vector2(1.45, 1.45), 0.22)
	tween.parallel().tween_property(wave, "modulate:a", 0.0, 0.22)
	tween.tween_callback(Callable(wave, "queue_free"))

func _create_muzzle_flash() -> void:
	var flash: Polygon2D = Polygon2D.new()
	flash.global_position = fire_point.global_position
	flash.polygon = PackedVector2Array([
		Vector2(0, -7),
		Vector2(19, 0),
		Vector2(0, 7),
		Vector2(5, 0),
	])
	flash.color = Color(0.63, 0.98, 1.0, 0.9)
	get_tree().current_scene.add_child(flash)

	var tween: Tween = get_tree().create_tween()
	tween.tween_property(flash, "scale", Vector2(1.8, 1.8), 0.08)
	tween.parallel().tween_property(flash, "modulate:a", 0.0, 0.08)
	tween.tween_callback(Callable(flash, "queue_free"))

func _create_damage_flash() -> void:
	var burst: Node2D = Node2D.new()
	burst.global_position = global_position
	get_tree().current_scene.add_child(burst)

	for i in range(8):
		var shard: Polygon2D = Polygon2D.new()
		shard.polygon = PackedVector2Array([
			Vector2(-2, -1),
			Vector2(6, -1),
			Vector2(6, 1),
			Vector2(-2, 1),
		])
		shard.rotation = TAU * float(i) / 8.0
		shard.color = Color(1.0, 0.35, 0.55, 0.95)
		burst.add_child(shard)

		var direction: Vector2 = Vector2.RIGHT.rotated(shard.rotation)
		var tween: Tween = get_tree().create_tween()
		tween.tween_property(shard, "position", direction * 30.0, 0.16)
		tween.parallel().tween_property(shard, "modulate:a", 0.0, 0.16)

	var cleanup: Tween = get_tree().create_tween()
	cleanup.tween_interval(0.18)
	cleanup.tween_callback(Callable(burst, "queue_free"))

func _create_dash_afterimage() -> void:
	for i in range(3):
		var ghost: Sprite2D = Sprite2D.new()
		ghost.texture = sprite.texture
		ghost.global_position = sprite.global_position - move_direction * float(i + 1) * 12.0
		ghost.global_rotation = sprite.global_rotation
		ghost.global_scale = sprite.global_scale
		ghost.modulate = Color(0.45, 0.9, 1.0, 0.35)
		get_tree().current_scene.add_child(ghost)

		var tween: Tween = get_tree().create_tween()
		tween.tween_property(ghost, "modulate:a", 0.0, 0.18 + float(i) * 0.04)
		tween.tween_callback(Callable(ghost, "queue_free"))

func _create_dash_damage_trail() -> void:
	var trail_area: Area2D = Area2D.new()
	trail_area.global_position = global_position
	trail_area.collision_layer = 0
	trail_area.collision_mask = 1
	get_tree().current_scene.add_child(trail_area)

	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(94.0, 42.0)
	shape.shape = rect
	trail_area.add_child(shape)

	var visual_rect: Polygon2D = Polygon2D.new()
	visual_rect.polygon = PackedVector2Array([
		Vector2(-47.0, -21.0),
		Vector2(47.0, -21.0),
		Vector2(47.0, 21.0),
		Vector2(-47.0, 21.0),
	])
	visual_rect.color = Color(0.45, 0.92, 1.0, 0.22)
	trail_area.add_child(visual_rect)

	for enemy in get_tree().get_nodes_in_group("enemies"):
		var area: Area2D = enemy as Area2D
		if area != null and area.global_position.distance_to(global_position) < 96.0:
			area.call("take_damage", maxi(1, bullet_damage))

	var tween: Tween = get_tree().create_tween()
	tween.tween_property(trail_area, "modulate:a", 0.0, 0.18)
	tween.tween_callback(Callable(trail_area, "queue_free"))

func _update_bubble_trail(delta: float) -> void:
	bubble_emit_timer = maxf(bubble_emit_timer - delta, 0.0)
	if velocity.length() < 20.0 or bubble_emit_timer > 0.0:
		return

	if dash_timer > 0.0:
		bubble_emit_timer = bubble_emit_interval * 0.45
		_create_swim_bubble()
		_create_swim_bubble()
	else:
		bubble_emit_timer = bubble_emit_interval
		_create_swim_bubble()

func _create_swim_bubble() -> void:
	var bubble: Node2D = Node2D.new()
	var back_offset: Vector2 = Vector2(-30.0, randf_range(-8.0, 10.0))
	bubble.global_position = global_position + back_offset
	get_tree().current_scene.add_child(bubble)

	var body: Polygon2D = Polygon2D.new()
	var points: PackedVector2Array = PackedVector2Array()
	var radius: float = randf_range(2.0, 5.0)
	for i in range(10):
		var angle: float = TAU * float(i) / 10.0
		points.append(Vector2(cos(angle), sin(angle)) * radius)

	body.polygon = points
	body.color = Color(0.72, 0.96, 1.0, 0.34)
	bubble.add_child(body)

	var shine: Polygon2D = Polygon2D.new()
	shine.polygon = PackedVector2Array([
		Vector2(-radius * 0.25, -radius * 0.65),
		Vector2(radius * 0.35, -radius * 0.55),
		Vector2(radius * 0.15, -radius * 0.25),
		Vector2(-radius * 0.45, -radius * 0.35),
	])
	shine.color = Color(0.9, 1.0, 1.0, 0.75)
	bubble.add_child(shine)

	var drift: Vector2 = Vector2(randf_range(-24.0, -44.0), randf_range(-18.0, -34.0))
	var duration: float = randf_range(0.55, 0.85)
	var tween: Tween = get_tree().create_tween()
	tween.tween_property(bubble, "global_position", bubble.global_position + drift, duration)
	tween.parallel().tween_property(bubble, "scale", Vector2(1.8, 1.8), duration)
	tween.parallel().tween_property(bubble, "modulate:a", 0.0, duration)
	tween.tween_callback(Callable(bubble, "queue_free"))

func _create_shield_flash() -> void:
	var ring: Polygon2D = Polygon2D.new()
	ring.global_position = global_position
	ring.polygon = PackedVector2Array([
		Vector2(0, -30),
		Vector2(22, -20),
		Vector2(34, 0),
		Vector2(22, 20),
		Vector2(0, 30),
		Vector2(-22, 20),
		Vector2(-34, 0),
		Vector2(-22, -20),
	])
	ring.color = Color(0.5, 1.0, 1.0, 0.45)
	get_tree().current_scene.add_child(ring)

	var tween: Tween = get_tree().create_tween()
	tween.tween_property(ring, "scale", Vector2(1.35, 1.35), 0.15)
	tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.15)
	tween.tween_callback(Callable(ring, "queue_free"))

func _get_play_area_size() -> Vector2:
	return get_viewport_rect().size

func _play_sfx(sound_name: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	for manager in get_tree().get_nodes_in_group("audio_manager"):
		if manager.has_method("play"):
			manager.call("play", sound_name, volume_db, pitch)
			return
