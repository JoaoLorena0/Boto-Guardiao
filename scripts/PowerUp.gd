extends Area2D

@export_enum("random", "health", "rapid", "spread", "shield", "clean") var kind: String = "random"
@export var speed: float = 145.0

@onready var visual: Sprite2D = $Visual

var textures: Dictionary = {
	"health": preload("res://Sprites/PowerUps/power_health.png"),
	"rapid": preload("res://Sprites/PowerUps/power_rapid.png"),
	"spread": preload("res://Sprites/PowerUps/power_spread.png"),
	"shield": preload("res://Sprites/PowerUps/power_shield.png"),
	"clean": preload("res://Sprites/PowerUps/power_clean.png"),
}

var bob_time: float = 0.0
var glow_ring: Polygon2D
var sparkle_timer: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	if kind == "random":
		kind = _random_kind()
	_update_color()
	_create_glow()

func _process(delta: float) -> void:
	bob_time += delta
	position.x -= speed * delta
	position.y += sin(bob_time * 5.5) * 12.0 * delta
	rotation_degrees = sin(bob_time * 4.0) * 8.0
	_update_glow(delta)

	if position.x < -80:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("apply_power_up"):
		body.call("apply_power_up", kind)
		_play_sfx("powerup_collect", -2.0, 1.0)
		for manager in get_tree().get_nodes_in_group("game_manager"):
			if manager.has_method("record_power_up_collected"):
				manager.call("record_power_up_collected")
		if kind == "clean":
			var pollution_core: Node = get_tree().current_scene.get_node_or_null("PollutionCore")
			if pollution_core != null and pollution_core.has_method("reduce_pollution"):
				pollution_core.call("reduce_pollution", 18)
		_create_collect_flash()
		queue_free()

func _random_kind() -> String:
	var kinds: Array[String] = ["health", "rapid", "spread", "shield", "clean"]
	var kind_index: int = randi_range(0, kinds.size() - 1)
	return kinds[kind_index]

func _update_color() -> void:
	visual.texture = textures[kind] as Texture2D
	if kind == "health":
		visual.modulate = Color.WHITE
	elif kind == "spread":
		visual.modulate = Color.WHITE
	elif kind == "shield":
		visual.modulate = Color.WHITE
	elif kind == "clean":
		visual.modulate = Color.WHITE
	else:
		visual.modulate = Color.WHITE

func _create_glow() -> void:
	glow_ring = Polygon2D.new()
	glow_ring.z_index = -1
	glow_ring.polygon = _make_ring_points(22.0, 18)
	glow_ring.color = _get_glow_color(0.22)
	add_child(glow_ring)
	move_child(glow_ring, 0)

func _update_glow(delta: float) -> void:
	if is_instance_valid(glow_ring):
		var pulse: float = 1.0 + sin(bob_time * 5.0) * 0.12
		glow_ring.scale = Vector2(pulse, pulse)
		glow_ring.rotation = -rotation
		glow_ring.color = _get_glow_color(0.18 + sin(bob_time * 4.0) * 0.06)

	sparkle_timer = maxf(sparkle_timer - delta, 0.0)
	if sparkle_timer <= 0.0:
		sparkle_timer = 0.18
		_create_sparkle()

func _make_ring_points(radius: float, count: int) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for i in range(count):
		var angle: float = TAU * float(i) / float(count)
		points.append(Vector2(cos(angle), sin(angle)) * radius)

	return points

func _get_glow_color(alpha: float) -> Color:
	if kind == "health":
		return Color(1.0, 0.35, 0.65, alpha)
	elif kind == "rapid":
		return Color(1.0, 0.86, 0.28, alpha)
	elif kind == "spread":
		return Color(0.56, 0.94, 1.0, alpha)
	elif kind == "shield":
		return Color(0.48, 1.0, 1.0, alpha)
	elif kind == "clean":
		return Color(0.58, 1.0, 0.48, alpha)

	return Color(0.84, 1.0, 1.0, alpha)

func _create_sparkle() -> void:
	var sparkle: Polygon2D = Polygon2D.new()
	var angle: float = randf() * TAU
	var distance: float = randf_range(17.0, 25.0)
	sparkle.position = Vector2(cos(angle), sin(angle)) * distance
	sparkle.polygon = PackedVector2Array([
		Vector2(0, -3),
		Vector2(3, 0),
		Vector2(0, 3),
		Vector2(-3, 0),
	])
	sparkle.color = _get_glow_color(0.85)
	add_child(sparkle)

	var tween: Tween = get_tree().create_tween()
	tween.tween_property(sparkle, "scale", Vector2(1.6, 1.6), 0.18)
	tween.parallel().tween_property(sparkle, "modulate:a", 0.0, 0.18)
	tween.tween_callback(Callable(sparkle, "queue_free"))

func _create_collect_flash() -> void:
	var flash: Polygon2D = Polygon2D.new()
	flash.global_position = global_position
	flash.polygon = PackedVector2Array([
		Vector2(0, -22),
		Vector2(17, 0),
		Vector2(0, 22),
		Vector2(-17, 0),
	])
	flash.color = Color(1.0, 1.0, 1.0, 0.75)
	get_tree().current_scene.add_child(flash)

	var tween: Tween = get_tree().create_tween()
	tween.tween_property(flash, "scale", Vector2(2.0, 2.0), 0.14)
	tween.parallel().tween_property(flash, "modulate:a", 0.0, 0.14)
	tween.tween_callback(Callable(flash, "queue_free"))

func _play_sfx(sound_name: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	for manager in get_tree().get_nodes_in_group("audio_manager"):
		if manager.has_method("play"):
			manager.call("play", sound_name, volume_db, pitch)
			return
