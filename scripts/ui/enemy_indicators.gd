class_name EnemyIndicators
extends Control

const TILE_SIZE: int = 19
const ICON_SIZE: int = 7
const INDICATOR_SCALE: int = 2
const EDGE_MARGIN: float = 24.0
const PAPER_COLOR: Color = Color(0.98, 0.98, 0.96)
const INK_COLOR: Color = Color(0.1, 0.1, 0.1)
const ALPHA_CUTOFF: float = 0.5
const MIN_ALPHA: float = 0.35

const DIRECTION_RIGHT: int = 0
const DIRECTION_DOWN: int = 1
const DIRECTION_LEFT: int = 2
const DIRECTION_UP: int = 3
const DIRECTION_COUNT: int = 4

const BUBBLE_PATTERN: Array[String] = [
	"..#######..",
	".#ooooooo#.",
	"#ooooooooo#",
	"#ooooooooo#",
	"#ooooooooo#",
	"#ooooooooo#",
	"#ooooooooo#",
	"#ooooooooo#",
	"#ooooooooo#",
	".#ooooooo#.",
	"..#######..",
]

const TAIL_PATTERN: Array[String] = [
	"##...",
	"#a#..",
	"#aa#.",
	"#aaa#",
	"#aa#.",
	"#a#..",
	"##...",
]

@export var max_indicators: int = 6

@export var max_distance: float = 1200.0

@export var solid_distance: float = 700.0

@export var refresh_interval: float = 0.1

var _camera: Camera2D = null
var _tracked: Array[EnemyBase] = []
var _textures: Dictionary = {}
var _icons: Dictionary = {}
var _refresh_countdown: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_process(false)


func setup(arena: Arena) -> void:
	if arena.player == null or arena.player.camera == null:
		push_warning("[EnemyIndicators] Sem câmera do jogador; indicadores desativados.")
		return
	_camera = arena.player.camera
	set_process(true)


func _process(delta: float) -> void:
	_refresh_countdown -= delta
	if _refresh_countdown <= 0.0:
		_refresh_countdown = refresh_interval
		_collect_enemies()
	queue_redraw()


func _collect_enemies() -> void:
	_tracked.clear()
	if _camera == null or not is_instance_valid(_camera):
		return

	var center: Vector2 = _camera.get_screen_center_position()
	var half: Vector2 = size * 0.5 / _camera.zoom

	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy: EnemyBase = node as EnemyBase
		if enemy == null:
			continue
		var offset: Vector2 = enemy.global_position - center
		if absf(offset.x) <= half.x and absf(offset.y) <= half.y:
			continue
		if offset.length() > max_distance:
			continue
		_tracked.append(enemy)

	_tracked.sort_custom(func(a: EnemyBase, b: EnemyBase) -> bool:
		return a.global_position.distance_squared_to(center) \
			< b.global_position.distance_squared_to(center)
	)
	if _tracked.size() > max_indicators:
		_tracked.resize(max_indicators)


func _draw() -> void:
	if _camera == null or not is_instance_valid(_camera):
		return

	var center: Vector2 = _camera.get_screen_center_position()
	var screen_center: Vector2 = size * 0.5
	var extents: Vector2 = screen_center - Vector2(EDGE_MARGIN, EDGE_MARGIN)
	if extents.x <= 0.0 or extents.y <= 0.0:
		return

	var span: float = float(TILE_SIZE * INDICATOR_SCALE)

	for enemy in _tracked:
		if not is_instance_valid(enemy):
			continue
		var world_offset: Vector2 = enemy.global_position - center
		var direction: Vector2 = (world_offset * _camera.zoom).normalized()
		if direction.is_zero_approx():
			continue

		var reach_x: float = extents.x / maxf(absf(direction.x), 0.0001)
		var reach_y: float = extents.y / maxf(absf(direction.y), 0.0001)
		var anchor: Vector2 = screen_center + direction * minf(reach_x, reach_y)

		var texture: ImageTexture = _texture_for(enemy, _edge_direction(direction, reach_x, reach_y))
		if texture == null:
			continue

		var origin: Vector2 = _snap(anchor - Vector2(span, span) * 0.5)
		draw_texture_rect(
			texture,
			Rect2(origin, Vector2(span, span)),
			false,
			Color(1.0, 1.0, 1.0, _alpha_for(world_offset.length()))
		)


func _edge_direction(direction: Vector2, reach_x: float, reach_y: float) -> int:
	if reach_x <= reach_y:
		return DIRECTION_RIGHT if direction.x >= 0.0 else DIRECTION_LEFT
	return DIRECTION_DOWN if direction.y >= 0.0 else DIRECTION_UP


func _snap(point: Vector2) -> Vector2:
	return (point / float(INDICATOR_SCALE)).floor() * float(INDICATOR_SCALE)


func _alpha_for(distance: float) -> float:
	if distance <= solid_distance:
		return 1.0
	var span: float = maxf(max_distance - solid_distance, 1.0)
	return lerpf(1.0, MIN_ALPHA, clampf((distance - solid_distance) / span, 0.0, 1.0))


func _texture_for(enemy: EnemyBase, direction: int) -> ImageTexture:
	var key: int = int(enemy.enemy_type) * DIRECTION_COUNT + direction
	if _textures.has(key):
		return _textures[key]

	var texture: ImageTexture = _build_indicator(enemy, direction)
	_textures[key] = texture
	return texture


func _build_indicator(enemy: EnemyBase, direction: int) -> ImageTexture:
	var accent: Color = EnemyBase.PRESETS[enemy.enemy_type]["trail_color"]
	accent.a = 1.0

	var image: Image = Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))

	var bubble_span: int = BUBBLE_PATTERN.size()
	var offset: int = (TILE_SIZE - bubble_span) / 2

	_stamp_tail(image, direction, offset, bubble_span, accent)
	_stamp_bubble(image, offset)
	_stamp_icon(image, enemy, offset + bubble_span / 2)
	return ImageTexture.create_from_image(image)


func _stamp_tail(image: Image, direction: int, offset: int, bubble_span: int, accent: Color) -> void:
	var tail_rows: int = TAIL_PATTERN.size()
	var tail_columns: int = String(TAIL_PATTERN[0]).length()
	var along: int = offset + (bubble_span - tail_rows) / 2

	for row in tail_rows:
		var line: String = TAIL_PATTERN[row]
		for column in tail_columns:
			if line[column] == ".":
				continue
			var color: Color = INK_COLOR if line[column] == "#" else accent
			var point: Vector2i = _tail_pixel(direction, offset, bubble_span, along + row, column)
			if point.x >= 0 and point.x < TILE_SIZE and point.y >= 0 and point.y < TILE_SIZE:
				image.set_pixelv(point, color)


func _tail_pixel(direction: int, offset: int, bubble_span: int, along: int, depth: int) -> Vector2i:
	var near_edge: int = offset
	var far_edge: int = offset + bubble_span - 1
	match direction:
		DIRECTION_RIGHT:
			return Vector2i(far_edge + depth, along)
		DIRECTION_LEFT:
			return Vector2i(near_edge - depth, along)
		DIRECTION_DOWN:
			return Vector2i(along, far_edge + depth)
	return Vector2i(along, near_edge - depth)


func _stamp_bubble(image: Image, offset: int) -> void:
	for row in BUBBLE_PATTERN.size():
		var line: String = BUBBLE_PATTERN[row]
		for column in line.length():
			var symbol: String = line[column]
			if symbol == ".":
				continue
			var color: Color = INK_COLOR if symbol == "#" else PAPER_COLOR
			image.set_pixel(offset + column, offset + row, color)


func _stamp_icon(image: Image, enemy: EnemyBase, center: int) -> void:
	var icon: Image = _icon_for(enemy)
	if icon == null:
		return
	var origin: Vector2i = Vector2i(center - icon.get_width() / 2, center - icon.get_height() / 2)
	image.blend_rect(icon, Rect2i(Vector2i.ZERO, icon.get_size()), origin)


func _icon_for(enemy: EnemyBase) -> Image:
	var type: int = enemy.enemy_type
	if _icons.has(type):
		return _icons[type]

	var icon: Image = _build_icon(enemy)
	_icons[type] = icon
	return icon


func _build_icon(enemy: EnemyBase) -> Image:
	if enemy.sprite == null:
		return null
	var frames: SpriteFrames = enemy.sprite.sprite_frames
	if frames == null:
		return null

	var animation: StringName = &"walk" if frames.has_animation(&"walk") else &"default"
	if not frames.has_animation(animation) or frames.get_frame_count(animation) <= 0:
		return null

	var frame: Texture2D = frames.get_frame_texture(animation, 0)
	if frame == null:
		return null
	var image: Image = frame.get_image()
	if image == null:
		push_warning("[EnemyIndicators] Quadro do inimigo %d sem imagem legível." % enemy.enemy_type)
		return null

	image = image.duplicate()
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)

	var used: Rect2i = image.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		return null
	image = image.get_region(used)

	var scale: float = float(ICON_SIZE) / float(maxi(used.size.x, used.size.y))
	var target: Vector2i = Vector2i(
		maxi(int(round(used.size.x * scale)), 1),
		maxi(int(round(used.size.y * scale)), 1)
	)
	image.premultiply_alpha()
	image.resize(target.x, target.y, Image.INTERPOLATE_BILINEAR)
	_harden_pixels(image)
	return image


func _harden_pixels(image: Image) -> void:
	for y in image.get_height():
		for x in image.get_width():
			var pixel: Color = image.get_pixel(x, y)
			if pixel.a < ALPHA_CUTOFF:
				image.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			image.set_pixel(x, y, Color(
				minf(pixel.r / pixel.a, 1.0),
				minf(pixel.g / pixel.a, 1.0),
				minf(pixel.b / pixel.a, 1.0),
				1.0
			))
