class_name PaintFlask
extends Node2D

const GROUP: String = "paint_flasks"
const FLASK_PATTERN: Array[String] = [
	"+++++++",
	"+++++++",
	"#~~~~~#",
	"#o~~~~#",
	"#o~~~~#",
	"#######",
	"#######",
	"#######",
	"#######",
	".#####.",
]
const OUTLINE_COLOR: Color = Color(0.12, 0.12, 0.12, 1.0)
const LID_COLOR: Color = Color(0.49, 0.34, 0.17, 1.0)
const HIGHLIGHT_MIX: float = 0.72
const PIXEL_SCALE: int = 2
const MAGNET_RADIUS: float = 80.0
const COLLECT_DISTANCE: float = 14.0
const WARNING_DISTANCE: float = 34.0
const WARNING_INTERVAL: float = 2.4
const WARNING_RISE: float = 16.0
const WARNING_TIME: float = 1.1
const WARNING_FONT_SIZE: int = 8
const WARNING_COLOR: Color = Color(0.2, 0.2, 0.2, 1.0)
const FLY_START_SPEED: float = 150.0
const FLY_ACCELERATION: float = 2200.0
const SCATTER_MIN: float = 10.0
const SCATTER_MAX: float = 28.0
const POP_TIME: float = 0.26
const POP_HEIGHT: float = 16.0
const BOB_SPEED: float = 3.0

static var _texture_cache: Dictionary = {}

var flask_color: Color = Color.WHITE
var effects: Array[String] = []

var _sprite: Sprite2D = null
var _pop_tween: Tween = null
var _hop_tween: Tween = null
var _landed: bool = false
var _flying: bool = false
var _collected: bool = false
var _speed: float = 0.0
var _bob_time: float = 0.0
var _warning_timer: float = 0.0
var _player: Player = null


func setup(color: Color, flask_effects: Array[String]) -> void:
	flask_color = Color(color.r, color.g, color.b, 1.0)
	effects = flask_effects.duplicate()


func _ready() -> void:
	add_to_group(GROUP)
	_sprite = Sprite2D.new()
	_sprite.texture = texture_for(flask_color, PIXEL_SCALE, true)
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
	_warning_timer = maxf(_warning_timer - delta, 0.0)
	var player: Player = _get_player()
	if player == null or player.is_dead():
		_bob(delta)
		return

	var distance: float = global_position.distance_to(player.global_position)
	if not _flying:
		_bob(delta)
		if _has_room():
			if distance <= MAGNET_RADIUS:
				attract()
		elif distance <= WARNING_DISTANCE:
			_warn_full()
		return

	if not _has_room():
		_flying = false
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


func collect() -> bool:
	if _collected:
		return false
	var belt: FlaskBelt = _get_belt()
	if belt == null or not belt.store(flask_color, effects):
		_warn_full()
		return false
	_collected = true
	_stop_pop()
	AudioManager.play_flask_pickup()
	queue_free()
	return true


func is_flying() -> bool:
	return _flying


func _has_room() -> bool:
	var belt: FlaskBelt = _get_belt()
	return belt != null and belt.has_room()


func _get_belt() -> FlaskBelt:
	var player: Player = _get_player()
	if player == null:
		return null
	return player.flask_belt


func _warn_full() -> void:
	if _warning_timer > 0.0:
		return
	_warning_timer = WARNING_INTERVAL
	var label: Label = Label.new()
	label.text = LocalizationManager.text("flask.slots_full")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", WARNING_FONT_SIZE)
	label.add_theme_color_override("font_color", WARNING_COLOR)
	label.position = Vector2(-70.0, -34.0)
	label.size = Vector2(140.0, 12.0)
	add_child(label)

	var tween: Tween = label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - WARNING_RISE, WARNING_TIME)
	tween.tween_property(label, "modulate:a", 0.0, WARNING_TIME)
	tween.finished.connect(label.queue_free)


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


static func texture_for(color: Color, pixel_scale: int, outlined: bool) -> ImageTexture:
	var key: String = "%s|%d|%s" % [color.to_html(), pixel_scale, outlined]
	if _texture_cache.has(key):
		return _texture_cache[key]

	var border: int = 1 if outlined else 0
	var height: int = FLASK_PATTERN.size()
	var width: int = FLASK_PATTERN[0].length()
	var image: Image = Image.create(width + border * 2, height + border * 2, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var highlight: Color = color.lerp(Color.WHITE, HIGHLIGHT_MIX)
	for y in height:
		var row: String = FLASK_PATTERN[y]
		for x in mini(width, row.length()):
			match row[x]:
				"#":
					image.set_pixel(x + border, y + border, color)
				"o":
					image.set_pixel(x + border, y + border, highlight)
				"+":
					image.set_pixel(x + border, y + border, LID_COLOR)
	if outlined:
		for y in image.get_height():
			for x in image.get_width():
				if image.get_pixel(x, y).a > 0.0 or _mark_at(x - border, y - border) == "~":
					continue
				if _touches_fill(x - border, y - border):
					image.set_pixel(x, y, OUTLINE_COLOR)

	image.resize(image.get_width() * pixel_scale, image.get_height() * pixel_scale, Image.INTERPOLATE_NEAREST)
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	_texture_cache[key] = texture
	return texture


static func _mark_at(x: int, y: int) -> String:
	if y < 0 or y >= FLASK_PATTERN.size():
		return "."
	var row: String = FLASK_PATTERN[y]
	return row[x] if x >= 0 and x < row.length() else "."


static func _touches_fill(x: int, y: int) -> bool:
	for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var neighbour: Vector2i = Vector2i(x, y) + offset
		if _mark_at(neighbour.x, neighbour.y) != ".":
			return true
	return false
