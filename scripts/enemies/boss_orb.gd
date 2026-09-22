class_name BossOrb
extends Node2D

const GROUP: String = "boss_orbs"
const PATTERN: Array[String] = [
	"..###..",
	".#ooo#.",
	"#oo**o#",
	"#o***o#",
	"#oo*oo#",
	".#ooo#.",
	"..###..",
]
const PIXEL_SCALE: int = 3
const SPEED: float = 300.0
const MAX_LIFETIME: float = 7.0
const DAMAGE: float = 8.0
const HIT_RADIUS: float = 20.0
const TRAIL_RADIUS: float = 4.0
const PAINT_SPACING: float = 8.0
const FADE_TIME: float = 0.25
const BOUNDS_MARGIN: float = 10.0
const OUTLINE_DARKEN: float = 0.55
const CORE_LIGHTEN: float = 0.6

static var _textures: Dictionary = {}

var direction: Vector2 = Vector2.RIGHT
var ink_color: Color = Color.WHITE
var arena_bounds: Rect2 = Rect2()

var _sprite: Sprite2D = null
var _life: float = MAX_LIFETIME
var _last_paint_position: Vector2 = Vector2.ZERO
var _player: Player = null
var _paint_canvas: PaintCanvas = null
var _spent: bool = false


func setup(orb_direction: Vector2, color: Color, bounds: Rect2 = Rect2()) -> void:
	direction = orb_direction.normalized()
	ink_color = Color(color.r, color.g, color.b, 1.0)
	arena_bounds = bounds


func _ready() -> void:
	add_to_group(GROUP)
	_sprite = Sprite2D.new()
	_sprite.texture = _get_texture(ink_color)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)
	_last_paint_position = global_position


func _process(delta: float) -> void:
	if _spent:
		return

	global_position += direction * SPEED * delta
	_paint_trail()

	var player: Player = _get_player()
	if player != null and not player.is_dead() \
			and global_position.distance_to(player.global_position) <= HIT_RADIUS:
		player.take_damage(DAMAGE)
		player.apply_knockback(global_position)
		dissolve()
		return

	if arena_bounds.has_area() \
			and not arena_bounds.grow(BOUNDS_MARGIN).has_point(global_position):
		dissolve()
		return

	_life -= delta
	if _life <= 0.0:
		dissolve()


func dissolve() -> void:
	if _spent:
		return
	_spent = true
	var tween: Tween = create_tween()
	tween.tween_property(_sprite, "modulate:a", 0.0, FADE_TIME)
	tween.finished.connect(queue_free)


func is_spent() -> bool:
	return _spent


func _paint_trail() -> void:
	if _paint_canvas == null or not is_instance_valid(_paint_canvas):
		_paint_canvas = get_tree().get_first_node_in_group("paint_canvas") as PaintCanvas
		_last_paint_position = global_position
	if _paint_canvas == null:
		return
	if global_position.distance_to(_last_paint_position) < PAINT_SPACING:
		return
	_paint_canvas.paint_line(_last_paint_position, global_position, TRAIL_RADIUS, ink_color)
	_last_paint_position = global_position


func _get_player() -> Player:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Player
	return _player


static func _get_texture(color: Color) -> ImageTexture:
	var key: int = color.to_rgba32()
	if _textures.has(key):
		return _textures[key]

	var tones: Dictionary = {
		"#": color.darkened(OUTLINE_DARKEN),
		"o": color,
		"*": color.lightened(CORE_LIGHTEN),
	}
	var height: int = PATTERN.size()
	var width: int = PATTERN[0].length()
	var image: Image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for y in height:
		var row: String = PATTERN[y]
		for x in mini(width, row.length()):
			if tones.has(row[x]):
				image.set_pixel(x, y, tones[row[x]])
	image.resize(width * PIXEL_SCALE, height * PIXEL_SCALE, Image.INTERPOLATE_NEAREST)
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	_textures[key] = texture
	return texture
