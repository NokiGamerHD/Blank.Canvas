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
const FLASK_MIN_STRENGTH: float = 0.2
const FLASK_MAX_STRENGTH: float = 0.38
const FLASK_PULSE_SPEED: float = 2.4
const BOLT_PATTERN: Array[String] = [
	"..##.",
	".##..",
	"###..",
	".###.",
	"..##.",
	".##..",
	".#...",
]
const BOLT_SCALE: int = 2
const BOLT_ALPHA: float = 0.55
const BOLT_TIME: float = 0.26
const BOLT_MIN_GAP: float = 0.5
const BOLT_MAX_GAP: float = 1.1
const BOLT_MARGIN: float = 26.0

static var _mask_texture: ImageTexture = null
static var _bolt_textures: Dictionary = {}

var _tween: Tween = null
var _footing: PaintCanvas.Footing = PaintCanvas.Footing.CLEAN
var _tint: Color = IDLE_COLOR
var _strength: float = IDLE_STRENGTH
var _flashing: bool = false
var _flask_color: Color = Color(0, 0, 0, 0)
var _pulse: float = 0.0
var _rise: float = 0.0
var _bolt_timer: float = 0.0
var _fade_left: float = 0.0
var _fade_total: float = 0.0


func _init() -> void:
	texture = _get_mask_texture()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	stretch_mode = TextureRect.STRETCH_SCALE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modulate = Color(IDLE_COLOR.r, IDLE_COLOR.g, IDLE_COLOR.b, IDLE_STRENGTH)


func _process(delta: float) -> void:
	if _flask_color.a <= 0.0 or _flashing:
		return
	if _fade_total > 0.0:
		_fade_left = maxf(_fade_left - delta, 0.0)
		if _fade_left <= 0.0:
			set_flask_glow(Color(0, 0, 0, 0))
			return
	_pulse += delta * FLASK_PULSE_SPEED
	_rise = minf(_rise + delta / FADE_TIME, 1.0)
	var blend: float = (sin(_pulse) + 1.0) * 0.5
	var strength: float = lerpf(FLASK_MIN_STRENGTH, FLASK_MAX_STRENGTH, blend) * _fade_scale() * _rise
	modulate = Color(_flask_color.r, _flask_color.g, _flask_color.b, strength)

	_bolt_timer -= delta
	if _bolt_timer <= 0.0:
		_bolt_timer = randf_range(BOLT_MIN_GAP, BOLT_MAX_GAP)
		_spawn_bolt()


func set_flask_glow(color: Color) -> void:
	_flask_color = color
	_fade_total = 0.0
	_fade_left = 0.0
	if color.a <= 0.0:
		if not _flashing:
			_start_tween(Color(_tint.r, _tint.g, _tint.b, _strength), FADE_TIME)
		return
	_pulse = 0.0
	_rise = 0.0
	_bolt_timer = BOLT_MIN_GAP
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_flashing = false


func fade_flask_glow(seconds: float) -> void:
	if _flask_color.a <= 0.0 or seconds <= 0.0:
		return
	_fade_total = seconds
	_fade_left = seconds


func _fade_scale() -> float:
	if _fade_total <= 0.0:
		return 1.0
	return clampf(_fade_left / _fade_total, 0.0, 1.0)


func _spawn_bolt() -> void:
	var bolt: TextureRect = TextureRect.new()
	bolt.texture = _get_bolt_texture(_flask_color)
	bolt.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bolt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bolt.modulate = Color(1.0, 1.0, 1.0, BOLT_ALPHA * _fade_scale())
	var screen: Vector2 = size
	var spot: Vector2 = Vector2.ZERO
	match randi() % 4:
		0:
			spot = Vector2(randf() * screen.x, randf_range(0.0, BOLT_MARGIN))
		1:
			spot = Vector2(randf() * screen.x, screen.y - randf_range(BOLT_MARGIN, BOLT_MARGIN * 2.0))
		2:
			spot = Vector2(randf_range(0.0, BOLT_MARGIN), randf() * screen.y)
		_:
			spot = Vector2(screen.x - randf_range(BOLT_MARGIN, BOLT_MARGIN * 2.0), randf() * screen.y)
	bolt.position = spot.floor()
	add_child(bolt)

	var tween: Tween = bolt.create_tween()
	tween.tween_property(bolt, "modulate:a", 0.0, BOLT_TIME)
	tween.tween_callback(bolt.queue_free)


func flask_color() -> Color:
	return _flask_color


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
	if _flashing or _flask_color.a > 0.0:
		return
	_start_tween(Color(tint.r, tint.g, tint.b, strength), FADE_TIME)


func flash_hurt() -> void:
	_flashing = true
	if _tween != null and _tween.is_valid():
		_tween.kill()
	modulate = Color(HURT_COLOR.r, HURT_COLOR.g, HURT_COLOR.b, HURT_STRENGTH)
	var back: Color = Color(_tint.r, _tint.g, _tint.b, _strength)
	if _flask_color.a > 0.0:
		back = Color(_flask_color.r, _flask_color.g, _flask_color.b, FLASK_MAX_STRENGTH)
	_tween = create_tween()
	_tween.tween_property(self, "modulate", back, HURT_FADE_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
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


static func _get_bolt_texture(color: Color) -> ImageTexture:
	var key: int = Color(color.r, color.g, color.b, 1.0).to_rgba32()
	if _bolt_textures.has(key):
		return _bolt_textures[key]
	var height: int = BOLT_PATTERN.size()
	var width: int = BOLT_PATTERN[0].length()
	var image: Image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for y in height:
		var row: String = BOLT_PATTERN[y]
		for x in mini(width, row.length()):
			if row[x] == "#":
				image.set_pixel(x, y, Color(color.r, color.g, color.b, 1.0))
	image.resize(width * BOLT_SCALE, height * BOLT_SCALE, Image.INTERPOLATE_NEAREST)
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	_bolt_textures[key] = texture
	return texture


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
