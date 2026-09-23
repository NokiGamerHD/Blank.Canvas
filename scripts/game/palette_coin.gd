class_name PaletteCoin
extends Node2D

const GROUP: String = "palette_coins"
const COIN_PATTERN: Array[String] = [
	"...#####...",
	"..#or#b##..",
	".#o###o###.",
	"#####g#####",
	"##..#######",
	".#..######.",
	"..#######..",
	"...#####...",
]
const GOLD_COLOR: Color = Color(0.91, 0.74, 0.17, 1.0)
const GOLD_HIGHLIGHT: Color = Color(1.0, 0.91, 0.54, 1.0)
const OUTLINE_COLOR: Color = Color(0.12, 0.12, 0.12, 1.0)
const DAB_COLORS: Dictionary = {
	"r": Color("b43434"),
	"b": Color("0b35dc"),
	"g": Color("15b10f"),
}
const PIXEL_SCALE: int = 3
const COLLECT_DISTANCE: float = 22.0
const POP_TIME: float = 0.3
const POP_HEIGHT: float = 22.0
const FLOAT_SPEED: float = 2.2
const FLOAT_HEIGHT: float = 2.0
const SHINE_SPEED: float = 3.0
const SHINE_MIN: float = 0.82

static var _texture: ImageTexture = null

var _sprite: Sprite2D = null
var _hop_tween: Tween = null
var _landed: bool = false
var _collected: bool = false
var _float_time: float = 0.0
var _shine_time: float = 0.0
var _player: Player = null


func _ready() -> void:
	add_to_group(GROUP)
	_sprite = Sprite2D.new()
	_sprite.texture = coin_texture()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)
	_float_time = randf() * TAU
	_shine_time = randf() * TAU

	_hop_tween = create_tween()
	_hop_tween.tween_property(_sprite, "position:y", -POP_HEIGHT, POP_TIME * 0.5) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_hop_tween.tween_property(_sprite, "position:y", 0.0, POP_TIME * 0.5) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_hop_tween.finished.connect(_on_landed)


func _process(delta: float) -> void:
	if _collected:
		return
	_shine_time += delta * SHINE_SPEED
	_float_time += delta * FLOAT_SPEED
	_sprite.modulate = Color(1.0, 1.0, 1.0, 1.0).lerp(
		Color(SHINE_MIN, SHINE_MIN, SHINE_MIN, 1.0), (sin(_shine_time) + 1.0) * 0.5)
	if _landed:
		_sprite.position.y = roundf(sin(_float_time) * FLOAT_HEIGHT) * float(PIXEL_SCALE)

	var player: Player = _get_player()
	if player == null or player.is_dead():
		return
	if global_position.distance_to(player.global_position) <= COLLECT_DISTANCE:
		collect()


func collect() -> void:
	if _collected:
		return
	_collected = true
	_stop_hop()
	GameManager.add_palettes(1)
	AudioManager.play_palette_pickup()
	queue_free()


func _on_landed() -> void:
	_landed = true


func _stop_hop() -> void:
	if _hop_tween != null and _hop_tween.is_valid():
		_hop_tween.kill()
	_landed = true


func _get_player() -> Player:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Player
	return _player


static func coin_texture() -> ImageTexture:
	if _texture != null:
		return _texture
	_texture = build_texture(PIXEL_SCALE)
	return _texture


static func build_texture(pixel_scale: int) -> ImageTexture:
	var height: int = COIN_PATTERN.size()
	var width: int = COIN_PATTERN[0].length()
	var image: Image = Image.create(width + 2, height + 2, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for y in height:
		var row: String = COIN_PATTERN[y]
		for x in mini(width, row.length()):
			var mark: String = row[x]
			if mark == ".":
				continue
			var color: Color = GOLD_COLOR
			if mark == "o":
				color = GOLD_HIGHLIGHT
			elif DAB_COLORS.has(mark):
				color = DAB_COLORS[mark]
			image.set_pixel(x + 1, y + 1, color)
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a == 0.0 and _touches_fill(x - 1, y - 1):
				image.set_pixel(x, y, OUTLINE_COLOR)
	image.resize(image.get_width() * pixel_scale, image.get_height() * pixel_scale, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(image)


static func _touches_fill(x: int, y: int) -> bool:
	for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var neighbour: Vector2i = Vector2i(x, y) + offset
		if neighbour.y < 0 or neighbour.y >= COIN_PATTERN.size():
			continue
		var row: String = COIN_PATTERN[neighbour.y]
		if neighbour.x >= 0 and neighbour.x < row.length() and row[neighbour.x] != ".":
			return true
	return false
