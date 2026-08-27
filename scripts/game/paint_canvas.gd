class_name PaintCanvas
extends Node2D

@export_range(0.1, 1.0, 0.05) var resolution_scale: float = 0.5

var _image: Image = null
var _texture: ImageTexture = null
var _sprite: Sprite2D = null
var _canvas_width: int = 0
var _canvas_height: int = 0
var _dirty: bool = false
var _is_ready: bool = false


func _ready() -> void:
	add_to_group("paint_canvas")


func setup(world_size: Vector2) -> void:
	_canvas_width = maxi(int(world_size.x * resolution_scale), 1)
	_canvas_height = maxi(int(world_size.y * resolution_scale), 1)

	_image = Image.create(_canvas_width, _canvas_height, false, Image.FORMAT_RGBA8)
	_image.fill(Color(0, 0, 0, 0))
	_texture = ImageTexture.create_from_image(_image)

	_sprite = Sprite2D.new()
	_sprite.name = "CanvasSprite"
	_sprite.centered = false
	_sprite.texture = _texture
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale = Vector2.ONE / resolution_scale
	add_child(_sprite)

	_is_ready = true


func get_image_copy() -> Image:
	if _image == null:
		return null
	return _image.duplicate()


func _process(_delta: float) -> void:
	if _dirty and _is_ready:
		_texture.update(_image)
		_dirty = false


func paint_circle(world_position: Vector2, world_radius: float, color: Color) -> void:
	if not _is_ready:
		return

	var local: Vector2 = to_local(world_position) * resolution_scale
	var radius: float = maxf(world_radius * resolution_scale, 1.0)
	var radius_squared: float = radius * radius

	var min_x: int = maxi(int(floorf(local.x - radius)), 0)
	var max_x: int = mini(int(ceilf(local.x + radius)), _canvas_width - 1)
	var min_y: int = maxi(int(floorf(local.y - radius)), 0)
	var max_y: int = mini(int(ceilf(local.y + radius)), _canvas_height - 1)

	for y in range(min_y, max_y + 1):
		var delta_y: float = (y + 0.5) - local.y
		for x in range(min_x, max_x + 1):
			var delta_x: float = (x + 0.5) - local.x
			if delta_x * delta_x + delta_y * delta_y <= radius_squared:
				_image.set_pixel(x, y, color)

	_dirty = true


func paint_line(from_world: Vector2, to_world: Vector2, world_radius: float, color: Color) -> void:
	if not _is_ready:
		return

	var length: float = from_world.distance_to(to_world)
	if length < 0.001:
		paint_circle(from_world, world_radius, color)
		return

	var step: float = maxf(world_radius * 0.5, 2.0)
	var stamp_count: int = maxi(int(ceilf(length / step)), 1)
	for i in range(stamp_count + 1):
		var t: float = float(i) / float(stamp_count)
		paint_circle(from_world.lerp(to_world, t), world_radius, color)
