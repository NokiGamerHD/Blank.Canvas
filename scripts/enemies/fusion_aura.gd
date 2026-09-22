class_name FusionAura
extends Node2D

const BUBBLE_PATTERNS: Array = [
	[
		".##.",
		"#o.#",
		"#..#",
		".##.",
	],
	[
		".#.",
		"#.#",
		".#.",
	],
]
const BOLT_PATTERN: Array[String] = [
	"...##",
	"..#o#",
	".##..",
	"#o###",
	"..##.",
	".#o#.",
	"##...",
]
const PIXEL_SCALE: int = 4
const HIGHLIGHT_MIX: float = 0.75
const BUBBLE_LIGHTEN: float = 0.25
const BOLT_LIGHTEN: float = 0.35
const BUBBLE_INTERVAL: float = 0.06
const BUBBLE_SPREAD_MIN: float = 0.75
const BUBBLE_SPREAD_MAX: float = 1.2
const BUBBLE_RISE: float = 22.0
const BUBBLE_TIME: float = 0.5
const BOLT_INTERVAL: float = 0.09
const BOLT_SPREAD_MIN: float = 0.9
const BOLT_SPREAD_MAX: float = 1.25
const BOLT_TIME: float = 0.12
const BOLT_TIER: int = 2

static var _textures: Dictionary = {}

var aura_color: Color = Color.WHITE
var body_radius: float = 10.0
var tier: int = 1

var _bubble_timer: float = 0.0
var _bolt_timer: float = 0.0


func setup(radius: float, color: Color, fusion_tier: int) -> void:
	body_radius = radius
	aura_color = Color(color.r, color.g, color.b, 1.0)
	tier = fusion_tier


func _process(delta: float) -> void:
	_bubble_timer -= delta
	if _bubble_timer <= 0.0:
		_bubble_timer = BUBBLE_INTERVAL
		_spawn_bubble()
	if tier < BOLT_TIER:
		return
	_bolt_timer -= delta
	if _bolt_timer <= 0.0:
		_bolt_timer = BOLT_INTERVAL
		_spawn_bolt()


func _spawn_bubble() -> void:
	var index: int = randi() % BUBBLE_PATTERNS.size()
	var bubble: Sprite2D = _make_sprite(
		_get_texture("bubble%d" % index, BUBBLE_PATTERNS[index], aura_color.lightened(BUBBLE_LIGHTEN)), "bubble")
	bubble.position = Vector2.from_angle(randf() * TAU) \
		* body_radius * randf_range(BUBBLE_SPREAD_MIN, BUBBLE_SPREAD_MAX)
	add_child(bubble)
	var tween: Tween = bubble.create_tween()
	tween.set_parallel(true)
	tween.tween_property(bubble, "position:y", bubble.position.y - BUBBLE_RISE, BUBBLE_TIME)
	tween.tween_property(bubble, "modulate:a", 0.0, BUBBLE_TIME).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(bubble.queue_free)


func _spawn_bolt() -> void:
	var bolt_color: Color = aura_color.lightened(BOLT_LIGHTEN)
	var bolt: Sprite2D = _make_sprite(_get_texture("bolt", BOLT_PATTERN, bolt_color), "bolt")
	bolt.position = Vector2.from_angle(randf() * TAU) \
		* body_radius * randf_range(BOLT_SPREAD_MIN, BOLT_SPREAD_MAX)
	bolt.flip_h = randf() < 0.5
	bolt.flip_v = randf() < 0.5
	add_child(bolt)
	var tween: Tween = bolt.create_tween()
	tween.tween_interval(BOLT_TIME)
	tween.tween_callback(bolt.queue_free)


func bubble_count() -> int:
	return _count_children_with_meta("bubble")


func bolt_count() -> int:
	return _count_children_with_meta("bolt")


func _count_children_with_meta(kind: String) -> int:
	var count: int = 0
	for child in get_children():
		if child.get_meta("kind", "") == kind:
			count += 1
	return count


func _make_sprite(texture: ImageTexture, kind: String) -> Sprite2D:
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.set_meta("kind", kind)
	return sprite


static func _get_texture(name: String, pattern: Array, color: Color) -> ImageTexture:
	var key: String = "%s|%s" % [name, color.to_html(false)]
	if _textures.has(key):
		return _textures[key]
	var tones: Dictionary = {
		"#": color,
		"o": color.lerp(Color.WHITE, HIGHLIGHT_MIX),
	}
	var height: int = pattern.size()
	var width: int = String(pattern[0]).length()
	var image: Image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for y in height:
		var row: String = pattern[y]
		for x in mini(width, row.length()):
			if tones.has(row[x]):
				image.set_pixel(x, y, tones[row[x]])
	image.resize(width * PIXEL_SCALE, height * PIXEL_SCALE, Image.INTERPOLATE_NEAREST)
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	_textures[key] = texture
	return texture
