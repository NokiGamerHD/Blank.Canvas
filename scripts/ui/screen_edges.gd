class_name ScreenEdges
extends TextureRect

const MASK_WIDTH: int = 120
const MASK_HEIGHT: int = 90
const EDGE_REACH: float = 0.3
const EDGE_STEPS: float = 6.0
const CORNER_WEIGHT: float = 0.45
const IDLE_COLOR: Color = Color(0.12, 0.12, 0.16, 1.0)
const IDLE_STRENGTH: float = 0.0
const FRESH_STRENGTH: float = 0.34
const MIXED_STRENGTH: float = 0.46
const FADE_TIME: float = 0.2
const HURT_COLOR: Color = Color(0.7, 0.08, 0.08, 1.0)
const HURT_STRENGTH: float = 0.62
const HURT_FADE_TIME: float = 0.45

static var _mask_texture: ImageTexture = null

var _tween: Tween = null
var _footing: PaintCanvas.Footing = PaintCanvas.Footing.CLEAN
var _tint: Color = IDLE_COLOR
var _strength: float = IDLE_STRENGTH
var _flashing: bool = false


func _init() -> void:
	texture = _get_mask_texture()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	stretch_mode = TextureRect.STRETCH_SCALE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modulate = Color(IDLE_COLOR.r, IDLE_COLOR.g, IDLE_COLOR.b, IDLE_STRENGTH)


func apply_footing(footing: PaintCanvas.Footing, paint_color: Color) -> void:
	var tint: Color = IDLE_COLOR
	var strength: float = IDLE_STRENGTH
	match footing:
		PaintCanvas.Footing.FRESH:
			tint = paint_color
			strength = FRESH_STRENGTH
		PaintCanvas.Footing.FRESH_MIX:
			tint = paint_color
			strength = MIXED_STRENGTH
	if footing == _footing and tint.is_equal_approx(_tint) and is_equal_approx(strength, _strength):
		return

	_footing = footing
	_tint = tint
	_strength = strength
	if _flashing:
		return
	_start_tween(Color(tint.r, tint.g, tint.b, strength), FADE_TIME)


func flash_hurt() -> void:
	_flashing = true
	if _tween != null and _tween.is_valid():
		_tween.kill()
	modulate = Color(HURT_COLOR.r, HURT_COLOR.g, HURT_COLOR.b, HURT_STRENGTH)
	_tween = create_tween()
	_tween.tween_property(
		self, "modulate", Color(_tint.r, _tint.g, _tint.b, _strength), HURT_FADE_TIME
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.finished.connect(_on_flash_finished)


func is_flashing() -> bool:
	return _flashing


func _on_flash_finished() -> void:
	_flashing = false


func _start_tween(target: Color, time: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate", target, time)


func current_footing() -> PaintCanvas.Footing:
	return _footing


static func _get_mask_texture() -> ImageTexture:
	if _mask_texture != null:
		return _mask_texture

	var image: Image = Image.create(MASK_WIDTH, MASK_HEIGHT, false, Image.FORMAT_RGBA8)
	var half: Vector2 = Vector2(MASK_WIDTH, MASK_HEIGHT) * 0.5
	for y in MASK_HEIGHT:
		for x in MASK_WIDTH:
			var offset: Vector2 = Vector2(
				absf(x + 0.5 - half.x) / half.x,
				absf(y + 0.5 - half.y) / half.y
			)
			var edge: float = maxf(offset.x, offset.y) * (1.0 - CORNER_WEIGHT) \
				+ minf(offset.length(), 1.0) * CORNER_WEIGHT
			var reach: float = clampf((edge - (1.0 - EDGE_REACH)) / EDGE_REACH, 0.0, 1.0)
			var alpha: float = roundf(reach * reach * EDGE_STEPS) / EDGE_STEPS
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))

	_mask_texture = ImageTexture.create_from_image(image)
	return _mask_texture
