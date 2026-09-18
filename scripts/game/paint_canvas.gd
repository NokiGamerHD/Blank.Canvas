class_name PaintCanvas
extends Node2D

enum Footing { CLEAN, FRESH, FRESH_MIX }

const WET_TIME_MS: int = 3500
const CLOCK_START_MS: int = 1000
const WET_VALUE_SCALE: float = 1.18
const WET_VALUE_LIFT: float = 0.06
const WET_WHITE_MIX: float = 0.03
const DRY_MARK: int = -1
const MIX_LEVELS: float = 31.0
const OPPOSITE_DESATURATION: float = 0.7
const OPPOSITE_DARKENING: float = 0.3
const MIX_SATURATION_LIFT: float = 0.1
const OPPOSITE_SHARPNESS: float = 6.0
const CANVAS_BASE_COLOR: Color = Color(0.97, 0.97, 0.95, 1.0)
const NO_BRUSH: int = 0
const MAX_BRUSHES: int = 255
const QUEUE_COMPACT_THRESHOLD: int = 200000
const RGB_HUE_ANCHORS: Array[float] = [0.0, 30.0, 60.0, 120.0, 180.0, 240.0, 275.0, 360.0]
const RYB_HUE_ANCHORS: Array[float] = [0.0, 60.0, 120.0, 180.0, 210.0, 240.0, 300.0, 360.0]

@export_range(0.1, 1.0, 0.05) var resolution_scale: float = 0.5

var _image: Image = null
var _base_image: Image = null
var _texture: ImageTexture = null
var _sprite: Sprite2D = null
var _canvas_width: int = 0
var _canvas_height: int = 0
var _dirty: bool = false
var _is_ready: bool = false
var _painted_at: PackedInt32Array = PackedInt32Array()
var _brush_ids: PackedByteArray = PackedByteArray()
var _mixed_flags: PackedByteArray = PackedByteArray()
var _brushes: Dictionary = {}
var _wet_pixels: PackedInt32Array = PackedInt32Array()
var _wet_times: PackedInt32Array = PackedInt32Array()
var _wet_head: int = 0
var _clock_seconds: float = CLOCK_START_MS / 1000.0
var _clock_ms: int = CLOCK_START_MS
var _covered_pixels: int = 0
var _mix_count: int = 0

static var _flat_cache: Dictionary = {}
static var _wet_color_cache: Dictionary = {}
static var _mix_cache: Dictionary = {}


func _ready() -> void:
	add_to_group("paint_canvas")


func setup(world_size: Vector2) -> void:
	_canvas_width = maxi(int(world_size.x * resolution_scale), 1)
	_canvas_height = maxi(int(world_size.y * resolution_scale), 1)

	_image = Image.create(_canvas_width, _canvas_height, false, Image.FORMAT_RGBA8)
	_image.fill(Color(0, 0, 0, 0))
	_base_image = _image.duplicate()
	_texture = ImageTexture.create_from_image(_image)
	_painted_at.resize(_canvas_width * _canvas_height)
	_painted_at.fill(0)
	_brush_ids.resize(_canvas_width * _canvas_height)
	_brush_ids.fill(NO_BRUSH)
	_mixed_flags.resize(_canvas_width * _canvas_height)
	_mixed_flags.fill(0)

	_sprite = Sprite2D.new()
	_sprite.name = "CanvasSprite"
	_sprite.centered = false
	_sprite.texture = _texture
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale = Vector2.ONE / resolution_scale
	add_child(_sprite)

	_is_ready = true


func get_texture() -> ImageTexture:
	return _texture


func get_image_copy() -> Image:
	if _base_image == null:
		return null
	return _base_image.duplicate()


func get_display_image_copy() -> Image:
	if _image == null:
		return null
	return _image.duplicate()


func coverage() -> float:
	if _painted_at.is_empty():
		return 0.0
	return float(_covered_pixels) / float(_painted_at.size())


func mix_count() -> int:
	return _mix_count


func is_wet_at(world_position: Vector2) -> bool:
	var index: int = _index_at(world_position)
	return index >= 0 and _is_wet(_painted_at[index])


func footing_at(world_position: Vector2) -> Footing:
	var index: int = _index_at(world_position)
	if index < 0 or not _is_wet(_painted_at[index]):
		return Footing.CLEAN
	return Footing.FRESH_MIX if _mixed_flags[index] == 1 else Footing.FRESH


func color_at(world_position: Vector2) -> Color:
	var index: int = _index_at(world_position)
	if index < 0:
		return Color(0, 0, 0, 0)
	return _base_image.get_pixel(index % _canvas_width, index / _canvas_width)


func _process(delta: float) -> void:
	if not _is_ready:
		return
	_clock_seconds += delta
	_clock_ms = int(_clock_seconds * 1000.0)
	_dry_until(_clock_ms - WET_TIME_MS)
	if _dirty:
		_texture.update(_image)
		_dirty = false


func dry_all() -> void:
	_dry_until(_clock_ms + WET_TIME_MS)


func paint_circle(world_position: Vector2, world_radius: float, color: Color, mixes: bool = true) -> void:
	if not _is_ready:
		return

	var local: Vector2 = to_local(world_position) * resolution_scale
	var radius: float = maxf(world_radius * resolution_scale, 1.0)
	var radius_squared: float = radius * radius

	var min_x: int = maxi(int(floorf(local.x - radius)), 0)
	var max_x: int = mini(int(ceilf(local.x + radius)), _canvas_width - 1)
	var min_y: int = maxi(int(floorf(local.y - radius)), 0)
	var max_y: int = mini(int(ceilf(local.y + radius)), _canvas_height - 1)

	var brush: int = _brush_id(color)
	var flat_color: Color = flatten(color)
	var wet_color: Color = wet_color_for(flat_color)

	for y in range(min_y, max_y + 1):
		var delta_y: float = (y + 0.5) - local.y
		var row: int = y * _canvas_width
		for x in range(min_x, max_x + 1):
			var delta_x: float = (x + 0.5) - local.x
			if delta_x * delta_x + delta_y * delta_y > radius_squared:
				continue
			var index: int = row + x
			var painted: int = _painted_at[index]
			var previous_brush: int = _brush_ids[index]
			if painted == _clock_ms and previous_brush == brush:
				continue

			if _is_wet(painted) and previous_brush == brush:
				pass
			elif mixes and _is_wet(painted) and previous_brush != NO_BRUSH:
				var mixed: Color = mix_colors(_base_image.get_pixel(x, y), flat_color)
				_base_image.set_pixel(x, y, mixed)
				_image.set_pixel(x, y, wet_color_for(mixed))
				_mixed_flags[index] = 1
				_mix_count += 1
			else:
				if painted == 0:
					_covered_pixels += 1
				_base_image.set_pixel(x, y, flat_color)
				_image.set_pixel(x, y, wet_color)
				_mixed_flags[index] = 0

			_brush_ids[index] = brush
			if painted != _clock_ms:
				_painted_at[index] = _clock_ms
				_wet_pixels.append(index)
				_wet_times.append(_clock_ms)

	_dirty = true


func paint_line(from_world: Vector2, to_world: Vector2, world_radius: float, color: Color, mixes: bool = true) -> void:
	if not _is_ready:
		return

	var length: float = from_world.distance_to(to_world)
	if length < 0.001:
		paint_circle(from_world, world_radius, color, mixes)
		return

	var step: float = maxf(world_radius * 0.5, 2.0)
	var stamp_count: int = maxi(int(ceilf(length / step)), 1)
	for i in range(stamp_count + 1):
		var t: float = float(i) / float(stamp_count)
		paint_circle(from_world.lerp(to_world, t), world_radius, color, mixes)


func _is_wet(painted: int) -> bool:
	return painted > 0 and _clock_ms - painted < WET_TIME_MS


func _index_at(world_position: Vector2) -> int:
	if not _is_ready:
		return -1
	var local: Vector2 = to_local(world_position) * resolution_scale
	var x: int = int(floorf(local.x))
	var y: int = int(floorf(local.y))
	if x < 0 or y < 0 or x >= _canvas_width or y >= _canvas_height:
		return -1
	return y * _canvas_width + x


func _dry_until(limit_ms: int) -> void:
	var total: int = _wet_pixels.size()
	while _wet_head < total and _wet_times[_wet_head] <= limit_ms:
		var index: int = _wet_pixels[_wet_head]
		if _painted_at[index] == _wet_times[_wet_head]:
			var x: int = index % _canvas_width
			var y: int = index / _canvas_width
			_image.set_pixel(x, y, _base_image.get_pixel(x, y))
			_painted_at[index] = DRY_MARK
			_dirty = true
		_wet_head += 1

	if _wet_head >= total:
		_wet_pixels.clear()
		_wet_times.clear()
		_wet_head = 0
	elif _wet_head >= QUEUE_COMPACT_THRESHOLD:
		_wet_pixels = _wet_pixels.slice(_wet_head)
		_wet_times = _wet_times.slice(_wet_head)
		_wet_head = 0


func _brush_id(color: Color) -> int:
	var key: int = color.to_rgba32()
	if _brushes.has(key):
		return _brushes[key]
	var id: int = _brushes.size() % MAX_BRUSHES + 1
	_brushes[key] = id
	return id


static func flatten(color: Color) -> Color:
	if color.a >= 1.0:
		return color
	var key: int = color.to_rgba32()
	if _flat_cache.has(key):
		return _flat_cache[key]
	var flat: Color = CANVAS_BASE_COLOR.lerp(Color(color.r, color.g, color.b, 1.0), color.a)
	_flat_cache[key] = flat
	return flat


static func wet_color_for(color: Color) -> Color:
	var key: int = color.to_rgba32()
	if _wet_color_cache.has(key):
		return _wet_color_cache[key]
	var value: float = minf(color.v * WET_VALUE_SCALE + WET_VALUE_LIFT, 1.0)
	var wet: Color = Color.from_hsv(color.h, color.s, value, color.a).lerp(Color(1, 1, 1, color.a), WET_WHITE_MIX)
	_wet_color_cache[key] = wet
	return wet


static func mix_colors(base: Color, incoming: Color) -> Color:
	var first: Color = flatten(base)
	var second: Color = flatten(incoming)
	var key: Vector2i = Vector2i(first.to_rgba32(), second.to_rgba32())
	if _mix_cache.has(key):
		return _mix_cache[key]

	var weight_total: float = first.s + second.s
	var second_weight: float = 0.5 if weight_total <= 0.001 else second.s / weight_total
	var first_hue: float = _rgb_to_ryb_hue(first.h * 360.0)
	var second_hue: float = _rgb_to_ryb_hue(second.h * 360.0)
	var difference: float = wrapf(second_hue - first_hue, -180.0, 180.0)
	var hue: float = wrapf(first_hue + difference * second_weight, 0.0, 360.0)
	var opposition: float = pow(absf(difference) / 180.0, OPPOSITE_SHARPNESS) * minf(first.s, second.s)
	var saturation: float = minf(maxf(first.s, second.s) + MIX_SATURATION_LIFT, 1.0) \
		* (1.0 - OPPOSITE_DESATURATION * opposition)
	var value: float = minf(first.v, second.v) * (1.0 - OPPOSITE_DARKENING * opposition)

	var mixed: Color = Color.from_hsv(_ryb_to_rgb_hue(hue) / 360.0, saturation, value, 1.0)
	mixed.a = 1.0
	mixed = Color(
		roundf(mixed.r * MIX_LEVELS) / MIX_LEVELS,
		roundf(mixed.g * MIX_LEVELS) / MIX_LEVELS,
		roundf(mixed.b * MIX_LEVELS) / MIX_LEVELS,
		mixed.a
	)
	_mix_cache[key] = mixed
	return mixed


static func _rgb_to_ryb_hue(hue: float) -> float:
	return _map_hue(hue, RGB_HUE_ANCHORS, RYB_HUE_ANCHORS)


static func _ryb_to_rgb_hue(hue: float) -> float:
	return _map_hue(hue, RYB_HUE_ANCHORS, RGB_HUE_ANCHORS)


static func _map_hue(hue: float, from: Array[float], to: Array[float]) -> float:
	var wrapped: float = wrapf(hue, 0.0, 360.0)
	for i in range(1, from.size()):
		if wrapped <= from[i]:
			var t: float = (wrapped - from[i - 1]) / (from[i] - from[i - 1])
			return lerpf(to[i - 1], to[i], t)
	return wrapped
