class_name PaintDrop
extends Node2D

const GROUP: String = "paint_drops"
const CONTAINER_GROUP: String = "drops_container"
const DROP_PATTERN: Array[String] = [
	"...#...",
	"...#...",
	"..###..",
	".#o###.",
	".#o###.",
	"#######",
	"#######",
	".#####.",
	"..###..",
]
const OUTLINE_COLOR: Color = Color(0.12, 0.12, 0.12, 1.0)
const ICON_INK_COLOR: Color = Color(0.2, 0.2, 0.22, 1.0)
const HIGHLIGHT_MIX: float = 0.65
const PIXEL_SCALE: int = 2
const VALUE: int = 1
const MAGNET_RADIUS: float = 90.0
const COLLECT_DISTANCE: float = 12.0
const FLY_START_SPEED: float = 140.0
const FLY_ACCELERATION: float = 2400.0
const SCATTER_MIN: float = 8.0
const SCATTER_MAX: float = 26.0
const POP_TIME: float = 0.24
const POP_HEIGHT: float = 14.0
const BOB_SPEED: float = 3.5

static var _texture_cache: Dictionary = {}

var ink_color: Color = Color.WHITE
var value: int = VALUE

var _sprite: Sprite2D = null
var _pop_tween: Tween = null
var _hop_tween: Tween = null
var _landed: bool = false
var _flying: bool = false
var _collected: bool = false
var _speed: float = 0.0
var _bob_time: float = 0.0
var _player: Player = null


func setup(color: Color) -> void:
	ink_color = Color(color.r, color.g, color.b, 1.0)


func _ready() -> void:
	add_to_group(GROUP)
	_sprite = Sprite2D.new()
	_sprite.texture = texture_for(ink_color, PIXEL_SCALE, true)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)
	_bob_time = randf() * TAU

	var landing: Vector2 = position + Vector2.from_angle(randf() * TAU) * randf_range(SCATTER_MIN, SCATTER_MAX)
	_pop_tween = create_tween()
	_pop_tween.tween_property(self, "position", landing, POP_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_hop_tween = create_tween()
	_hop_tween.tween_property(_sprite, "position:y", -POP_HEIGHT, POP_TIME * 0.5) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_hop_tween.tween_property(_sprite, "position:y", 0.0, POP_TIME * 0.5) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_hop_tween.finished.connect(_on_landed)


func _process(delta: float) -> void:
	if _collected:
		return
	var player: Player = _get_player()
	if not _flying:
		_bob(delta)
		if player != null and not player.is_dead() \
				and global_position.distance_to(player.global_position) <= MAGNET_RADIUS:
			attract()
		return
	if player == null or player.is_dead():
		return
	_speed += FLY_ACCELERATION * delta
	var to_player: Vector2 = player.global_position - global_position
	var step: float = _speed * delta
	if to_player.length() <= maxf(COLLECT_DISTANCE, step):
		collect()
		return
	global_position += to_player.normalized() * step


func attract() -> void:
	if _flying or _collected:
		return
	_flying = true
	_speed = FLY_START_SPEED
	_stop_pop()


func collect() -> void:
	if _collected:
		return
	_collected = true
	_stop_pop()
	var player: Player = _get_player()
	if player != null:
		player.add_ink(value)
	AudioManager.play_ink_pickup()
	queue_free()


func is_flying() -> bool:
	return _flying


func _bob(delta: float) -> void:
	if not _landed:
		return
	_bob_time += delta * BOB_SPEED
	_sprite.position.y = -float(PIXEL_SCALE) if sin(_bob_time) > 0.0 else 0.0


func _on_landed() -> void:
	_landed = true


func _stop_pop() -> void:
	for tween in [_pop_tween, _hop_tween]:
		if tween != null and tween.is_valid():
			tween.kill()
	_landed = true
	if _sprite != null:
		_sprite.position.y = 0.0


func _get_player() -> Player:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Player
	return _player


static func icon_texture(pixel_scale: int) -> ImageTexture:
	return texture_for(ICON_INK_COLOR, pixel_scale, false)


static func texture_for(color: Color, pixel_scale: int, outlined: bool) -> ImageTexture:
	var key: String = "%s|%d|%s" % [color.to_html(), pixel_scale, outlined]
	if _texture_cache.has(key):
		return _texture_cache[key]

	var border: int = 1 if outlined else 0
	var height: int = DROP_PATTERN.size()
	var width: int = DROP_PATTERN[0].length()
	var image: Image = Image.create(width + border * 2, height + border * 2, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var highlight: Color = color.lerp(Color.WHITE, HIGHLIGHT_MIX)
	for y in height:
		var row: String = DROP_PATTERN[y]
		for x in mini(width, row.length()):
			match row[x]:
				"#":
					image.set_pixel(x + border, y + border, color)
				"o":
					image.set_pixel(x + border, y + border, highlight)
	if outlined:
		for y in image.get_height():
			for x in image.get_width():
				if image.get_pixel(x, y).a == 0.0 and _touches_fill(x - border, y - border):
					image.set_pixel(x, y, OUTLINE_COLOR)

	image.resize(image.get_width() * pixel_scale, image.get_height() * pixel_scale, Image.INTERPOLATE_NEAREST)
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	_texture_cache[key] = texture
	return texture


static func _touches_fill(x: int, y: int) -> bool:
	for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var neighbour: Vector2i = Vector2i(x, y) + offset
		if neighbour.y < 0 or neighbour.y >= DROP_PATTERN.size():
			continue
		var row: String = DROP_PATTERN[neighbour.y]
		if neighbour.x >= 0 and neighbour.x < row.length() and row[neighbour.x] != ".":
			return true
	return false
