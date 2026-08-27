class_name Projectile
extends Area2D

static var _paint_color_cache: Dictionary = {}

@export var speed: float = 600.0

@export var damage: float = 20.0

@export var max_lifetime: float = 3.0

@export var paint_radius: float = 9.0

var direction: Vector2 = Vector2.RIGHT

var pierce_remaining: int = 0

var size_scale: float = 1.0

var _has_impacted: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func configure(texture: Texture2D, fly_direction: Vector2) -> void:
	direction = fly_direction.normalized()
	if texture != null:
		set_meta("configured_texture", texture)


func _ready() -> void:
	body_entered.connect(_on_body_entered)

	var texture: Texture2D = get_meta("configured_texture", null)
	if texture == null:
		texture = _resolve_ability_texture()
	sprite.texture = texture

	rotation = direction.angle()
	scale = Vector2.ONE * size_scale

	get_tree().create_timer(max_lifetime).timeout.connect(_on_lifetime_expired)


func _physics_process(delta: float) -> void:
	if _has_impacted:
		return
	global_position += direction * speed * delta


func _on_body_entered(body: Node2D) -> void:
	if _has_impacted:
		return
	if body is EnemyBase:
		body.take_damage(damage)
		_paint_impact(global_position)
		if pierce_remaining > 0:
			pierce_remaining -= 1
			return
		_finish_impact()
		return
	_paint_impact(global_position)
	_finish_impact()


func _finish_impact() -> void:
	_has_impacted = true
	queue_free()


func _on_lifetime_expired() -> void:
	if not _has_impacted and is_instance_valid(self):
		queue_free()


func _paint_impact(impact_position: Vector2) -> void:
	var canvas: PaintCanvas = get_tree().get_first_node_in_group("paint_canvas") as PaintCanvas
	if canvas == null:
		return

	var color: Color = _get_paint_color()
	var radius: float = paint_radius * size_scale
	canvas.paint_circle(impact_position, radius, color)
	for i in 3:
		var offset: Vector2 = Vector2.from_angle(randf() * TAU) \
			* randf_range(radius * 1.2, radius * 2.5)
		canvas.paint_circle(
			impact_position + offset,
			randf_range(radius * 0.3, radius * 0.6),
			color
		)


func _get_paint_color() -> Color:
	var texture: Texture2D = sprite.texture
	if texture == null:
		return Color(0.2, 0.2, 0.2, 0.9)
	if _paint_color_cache.has(texture):
		return _paint_color_cache[texture]

	var color: Color = _compute_average_color(texture.get_image())
	_paint_color_cache[texture] = color
	return color


static func _compute_average_color(image: Image) -> Color:
	var fallback: Color = Color(0.2, 0.2, 0.2, 0.9)
	if image == null:
		return fallback

	var bright_sum: Vector3 = Vector3.ZERO
	var bright_count: int = 0
	var all_sum: Vector3 = Vector3.ZERO
	var all_count: int = 0

	for y in image.get_height():
		for x in image.get_width():
			var pixel: Color = image.get_pixel(x, y)
			if pixel.a <= 0.1:
				continue
			all_sum += Vector3(pixel.r, pixel.g, pixel.b)
			all_count += 1
			if pixel.r + pixel.g + pixel.b > 0.35:
				bright_sum += Vector3(pixel.r, pixel.g, pixel.b)
				bright_count += 1

	if bright_count > 0:
		var bright: Vector3 = bright_sum / float(bright_count)
		return Color(bright.x, bright.y, bright.z, 0.9)
	if all_count > 0:
		var average: Vector3 = all_sum / float(all_count)
		return Color(average.x, average.y, average.z, 0.9)
	return fallback


func _resolve_ability_texture() -> Texture2D:
	var texture: ImageTexture = GameManager.get_ability_texture(0)
	if texture == null:
		if GameManager.load_ability_drawing_from_disk(0):
			texture = GameManager.get_ability_texture(0)
	if texture == null:
		push_warning("[Projectile] Sem desenho de habilidade; usando placeholder.")
		texture = _create_placeholder_texture()
	return texture


func _create_placeholder_texture() -> ImageTexture:
	var image: Image = Image.create(12, 12, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var center: Vector2 = Vector2(5.5, 5.5)
	for y in 12:
		for x in 12:
			if Vector2(x, y).distance_to(center) <= 5.5:
				image.set_pixel(x, y, Color(0.95, 0.55, 0.1))
	return ImageTexture.create_from_image(image)
