extends Area2D

@export var speed: float = 450.0
@export var damage: int = 1

var spent: bool = false
var trail: Line2D
var direction: Vector2 = Vector2.RIGHT
var pierce: bool = false
var explosive: bool = false
var explosion_damage: int = 1

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	_create_trail()

func _process(delta: float) -> void:
	position += direction * speed * delta
	_update_trail()

	if position.x > get_viewport_rect().size.x + 80 or position.x < -80 or position.y < -80 or position.y > get_viewport_rect().size.y + 80:
		queue_free()

func setup(new_direction: Vector2, new_damage: int = 1, new_speed: float = 450.0, new_pierce: bool = false, new_explosive: bool = false) -> void:
	direction = new_direction.normalized()
	damage = new_damage
	speed = new_speed
	pierce = new_pierce
	explosive = new_explosive
	explosion_damage = maxi(1, int(float(damage) * 0.65))
	rotation = direction.angle()

func _on_area_entered(area: Area2D) -> void:
	if spent:
		return

	if area.has_method("take_damage"):
		spent = true
		_create_hit_spark()
		area.call("take_damage", damage)
		if explosive:
			_create_explosion_damage()
		if not pierce:
			queue_free()
		else:
			spent = false

func _exit_tree() -> void:
	if is_instance_valid(trail):
		trail.queue_free()

func _create_trail() -> void:
	trail = Line2D.new()
	trail.width = 3.0
	trail.default_color = Color(0.52, 0.96, 1.0, 0.65)
	trail.texture_mode = Line2D.LINE_TEXTURE_NONE
	get_tree().current_scene.call_deferred("add_child", trail)

func _update_trail() -> void:
	if not is_instance_valid(trail):
		return

	trail.add_point(global_position)
	while trail.get_point_count() > 8:
		trail.remove_point(0)

func _create_hit_spark() -> void:
	var spark: Node2D = Node2D.new()
	spark.global_position = global_position
	get_tree().current_scene.add_child(spark)

	for i in range(7):
		var ray: Polygon2D = Polygon2D.new()
		ray.polygon = PackedVector2Array([
			Vector2(0, -1),
			Vector2(14, 0),
			Vector2(0, 1),
		])
		ray.rotation = TAU * float(i) / 7.0
		ray.color = Color(0.75, 1.0, 1.0, 0.95)
		spark.add_child(ray)

		var tween: Tween = get_tree().create_tween()
		tween.tween_property(ray, "scale", Vector2(1.8, 1.8), 0.09)
		tween.parallel().tween_property(ray, "modulate:a", 0.0, 0.09)

	var cleanup: Tween = get_tree().create_tween()
	cleanup.tween_interval(0.1)
	cleanup.tween_callback(Callable(spark, "queue_free"))

func _create_explosion_damage() -> void:
	var radius: float = 72.0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var area: Area2D = enemy as Area2D
		if area != null and area != get_parent() and area.global_position.distance_to(global_position) <= radius:
			area.call("take_damage", explosion_damage)

	var ring: Polygon2D = Polygon2D.new()
	ring.global_position = global_position
	var points: PackedVector2Array = PackedVector2Array()
	for i in range(18):
		var angle: float = TAU * float(i) / 18.0
		points.append(Vector2(cos(angle), sin(angle)) * radius * 0.35)
	ring.polygon = points
	ring.color = Color(0.58, 0.95, 1.0, 0.35)
	get_tree().current_scene.add_child(ring)
	var tween: Tween = get_tree().create_tween()
	tween.tween_property(ring, "scale", Vector2(2.2, 2.2), 0.14)
	tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.14)
	tween.tween_callback(Callable(ring, "queue_free"))
