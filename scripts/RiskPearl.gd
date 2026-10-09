extends Area2D
class_name RiskPearl

@export var score_value: int = 8
@export var lifetime: float = 5.0

var age: float = 0.0
var visual: Polygon2D

func _ready() -> void:
	collision_layer = 8
	collision_mask = 2
	body_entered.connect(_on_body_entered)
	_create_visual()

func _process(delta: float) -> void:
	age += delta
	position.x -= 24.0 * delta
	position.y += sin(age * 5.0) * 10.0 * delta
	if visual != null:
		var pulse: float = 1.0 + sin(age * 7.0) * 0.18
		visual.scale = Vector2(pulse, pulse)

	if age >= lifetime:
		_fade_out()

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return

	for manager in get_tree().get_nodes_in_group("game_manager"):
		if manager.has_method("add_risk_score"):
			manager.call("add_risk_score", score_value)
			break
	_play_sfx("powerup_collect", -8.0, 1.25)
	_create_collect_flash()
	queue_free()

func _create_visual() -> void:
	var shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = 12.0
	shape.shape = circle
	add_child(shape)

	visual = Polygon2D.new()
	visual.polygon = _make_points(10.0, 12)
	visual.color = Color(1.0, 0.86, 0.35, 0.95)
	add_child(visual)

	var core: Polygon2D = Polygon2D.new()
	core.polygon = _make_points(4.5, 10)
	core.color = Color(1.0, 1.0, 0.82, 1.0)
	add_child(core)

func _make_points(radius: float, count: int) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for i in range(count):
		var angle: float = TAU * float(i) / float(count)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points

func _fade_out() -> void:
	set_process(false)
	var tween: Tween = get_tree().create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.25)
	tween.tween_callback(Callable(self, "queue_free"))

func _create_collect_flash() -> void:
	var flash: Polygon2D = Polygon2D.new()
	flash.global_position = global_position
	flash.polygon = _make_points(18.0, 10)
	flash.color = Color(1.0, 0.92, 0.35, 0.8)
	get_tree().current_scene.add_child(flash)

	var tween: Tween = get_tree().create_tween()
	tween.tween_property(flash, "scale", Vector2(1.9, 1.9), 0.14)
	tween.parallel().tween_property(flash, "modulate:a", 0.0, 0.14)
	tween.tween_callback(Callable(flash, "queue_free"))

func _play_sfx(sound_name: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	for manager in get_tree().get_nodes_in_group("audio_manager"):
		if manager.has_method("play"):
			manager.call("play", sound_name, volume_db, pitch)
			return
