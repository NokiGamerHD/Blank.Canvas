class_name BossHealthBar
extends Control

const PIXEL_SCALE: int = 2
const ART_WIDTH: int = 96
const ART_HEIGHT: int = 7
const BORDER_COLOR: Color = Color(0.12, 0.12, 0.12, 1.0)
const BACK_COLOR: Color = Color(0.86, 0.86, 0.84, 1.0)
const TOP_OFFSET: float = 12.0
const FADE_TIME: float = 0.3

static var _frame_texture: ImageTexture = null

var _frame: TextureRect = null
var _back: ColorRect = null
var _fill: ColorRect = null
var _total: float = 0.0
var _showing: bool = false
var _tween: Tween = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(ART_WIDTH * PIXEL_SCALE, ART_HEIGHT * PIXEL_SCALE)
	size = custom_minimum_size
	anchor_left = 0.5
	anchor_right = 0.5
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	offset_left = -custom_minimum_size.x * 0.5
	offset_right = custom_minimum_size.x * 0.5
	offset_top = TOP_OFFSET
	offset_bottom = TOP_OFFSET + custom_minimum_size.y
	modulate.a = 0.0

	_back = ColorRect.new()
	_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_back.color = BACK_COLOR
	_back.position = Vector2(PIXEL_SCALE, PIXEL_SCALE)
	_back.size = custom_minimum_size - Vector2(PIXEL_SCALE, PIXEL_SCALE) * 2.0
	add_child(_back)

	_fill = ColorRect.new()
	_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill.position = _back.position
	_fill.size = _back.size
	add_child(_fill)

	_frame = TextureRect.new()
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.texture = _get_frame_texture()
	_frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_frame.stretch_mode = TextureRect.STRETCH_SCALE
	_frame.size = custom_minimum_size
	add_child(_frame)


func show_boss(color: Color, total_hp: float) -> void:
	_total = maxf(total_hp, 1.0)
	_fill.color = Color(color.r, color.g, color.b, 1.0)
	_fill.size.x = _back.size.x
	_showing = true
	_fade_to(1.0)


func update_value(current_hp: float) -> void:
	if not _showing:
		return
	var ratio: float = clampf(current_hp / _total, 0.0, 1.0)
	var steps: float = floorf(_back.size.x / float(PIXEL_SCALE))
	_fill.size.x = roundf(ratio * steps) * float(PIXEL_SCALE)


func hide_boss() -> void:
	if not _showing:
		return
	_showing = false
	_fade_to(0.0)


func is_showing() -> bool:
	return _showing


func fill_width() -> float:
	return _fill.size.x


func _fade_to(alpha: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", alpha, FADE_TIME)


static func _get_frame_texture() -> ImageTexture:
	if _frame_texture != null:
		return _frame_texture

	var image: Image = Image.create(ART_WIDTH, ART_HEIGHT, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for x in ART_WIDTH:
		image.set_pixel(x, 0, BORDER_COLOR)
		image.set_pixel(x, ART_HEIGHT - 1, BORDER_COLOR)
	for y in ART_HEIGHT:
		image.set_pixel(0, y, BORDER_COLOR)
		image.set_pixel(ART_WIDTH - 1, y, BORDER_COLOR)
	for corner in [Vector2i(0, 0), Vector2i(ART_WIDTH - 1, 0),
			Vector2i(0, ART_HEIGHT - 1), Vector2i(ART_WIDTH - 1, ART_HEIGHT - 1)]:
		image.set_pixelv(corner, Color(0, 0, 0, 0))

	_frame_texture = ImageTexture.create_from_image(image)
	return _frame_texture
