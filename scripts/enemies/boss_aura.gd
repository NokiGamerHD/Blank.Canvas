class_name BossAura
extends Sprite2D

const PIXEL_SCALE: int = 3
const RING_THICKNESS: int = 2
const RADIUS_FACTOR: float = 1.35
const MIN_ALPHA: float = 0.3
const MAX_ALPHA: float = 0.72
const PULSE_TIME: float = 0.75

static var _textures: Dictionary = {}


func setup(world_radius: float, color: Color) -> void:
	var art_radius: int = maxi(int(roundf(world_radius * RADIUS_FACTOR / float(PIXEL_SCALE))), 4)
	texture = _get_texture(art_radius, Color(color.r, color.g, color.b, 1.0))
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	scale = Vector2.ONE * PIXEL_SCALE
	modulate.a = MIN_ALPHA

	var tween: Tween = create_tween()
	tween.set_loops()
	tween.tween_property(self, "modulate:a", MAX_ALPHA, PULSE_TIME).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "modulate:a", MIN_ALPHA, PULSE_TIME).set_trans(Tween.TRANS_SINE)


static func _get_texture(art_radius: int, color: Color) -> ImageTexture:
	var key: String = "%d|%s" % [art_radius, color.to_html(false)]
	if _textures.has(key):
		return _textures[key]

	var span: int = art_radius * 2 + 1
	var image: Image = Image.create(span, span, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var center: Vector2 = Vector2(art_radius, art_radius)
	var inner: float = float(art_radius - RING_THICKNESS)
	for y in span:
		for x in span:
			var distance: float = Vector2(x, y).distance_to(center)
			if distance <= float(art_radius) and distance > inner:
				image.set_pixel(x, y, color)

	var texture: ImageTexture = ImageTexture.create_from_image(image)
	_textures[key] = texture
	return texture
