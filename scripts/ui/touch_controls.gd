class_name TouchControls
extends Control

signal pause_requested

const RING_ART_RADIUS: int = 26
const RING_INNER_RADIUS: float = 22.2
const KNOB_ART_RADIUS: int = 10
const STICK_SCALE: int = 3
const DEAD_ZONE: float = 0.18
const MAX_PULL: float = 72.0
const STICK_MARGIN: int = 34
const AIM_DISTANCE: float = 220.0
const ZONE_TOP_FRACTION: float = 0.28
const BUTTON_ART_RADIUS: int = 9
const BUTTON_SCALE: int = 3
const BUTTON_GAP: int = 8
const TOUCH_PADDING: int = 12
const PAUSE_SIZE: int = 44
const PAUSE_MARGIN: int = 10
const PAUSE_SCALE: int = 6
const IDLE_DIM: float = 0.6
const RING_FILL_COLOR: Color = Color(0.96, 0.96, 0.93, 0.34)
const RING_EDGE_COLOR: Color = Color(0.15, 0.15, 0.15, 0.62)
const KNOB_FILL_COLOR: Color = Color(0.96, 0.96, 0.93, 0.85)
const KNOB_EDGE_COLOR: Color = Color(0.15, 0.15, 0.15, 0.85)
const FACE_COLOR: Color = Color(0.96, 0.96, 0.93, 0.62)
const FACE_READY_COLOR: Color = Color(0.96, 0.96, 0.93, 0.88)
const EDGE_COLOR: Color = Color(0.15, 0.15, 0.15, 0.75)
const EDGE_THICKNESS: int = 2
const PRESSED_TINT: Color = Color(0.82, 0.82, 0.78, 0.9)

const PAUSE_PATTERN: Array[String] = [
	"##.##",
	"##.##",
	"##.##",
	"##.##",
	"##.##",
]

var _player: Player = null
var _controller: AbilityController = null
var _dash_icon: Texture2D = null
var _ring_texture: ImageTexture = null
var _disc_texture: ImageTexture = null
var _knob_texture: ImageTexture = null
var _knob_edge_texture: ImageTexture = null
var _pause_texture: ImageTexture = null
var _button_face_texture: ImageTexture = null
var _button_edge_texture: ImageTexture = null
var _move_touch: int = -1
var _aim_touch: int = -1
var _move_point: Vector2 = Vector2.ZERO
var _aim_point: Vector2 = Vector2.ZERO
var _blockers: Array[Control] = []
var _dash_touch: int = -1
var _pause_touch: int = -1
var _active: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	_ring_texture = _build_disc(RING_ART_RADIUS, RING_INNER_RADIUS)
	_disc_texture = _build_disc(RING_ART_RADIUS, -1.0)
	_knob_texture = _build_disc(KNOB_ART_RADIUS, -1.0)
	_knob_edge_texture = _build_disc(KNOB_ART_RADIUS, float(KNOB_ART_RADIUS) - 1.6)
	_pause_texture = _build_pattern(PAUSE_PATTERN, PAUSE_SCALE)
	_button_face_texture = _build_disc(BUTTON_ART_RADIUS, -1.0)
	_button_edge_texture = _build_disc(BUTTON_ART_RADIUS, float(BUTTON_ART_RADIUS) - 1.4)
	GameManager.input_mode_changed.connect(_on_input_mode_changed)
	_on_input_mode_changed(GameManager.uses_touch())


func setup(player: Player, controller: AbilityController, dash_icon: Texture2D) -> void:
	_player = player
	_controller = controller
	_dash_icon = dash_icon
	if _controller != null:
		_controller.touch_input = _active


func add_blocker(control: Control) -> void:
	if control != null and not _blockers.has(control):
		_blockers.append(control)


func is_active() -> bool:
	return _active


func screen_size() -> Vector2:
	return get_viewport_rect().size


func stick_radius() -> float:
	return float(RING_ART_RADIUS * STICK_SCALE)


func move_stick_center() -> Vector2:
	var radius: float = stick_radius()
	return Vector2(float(STICK_MARGIN) + radius, screen_size().y - float(STICK_MARGIN) - radius)


func aim_stick_center() -> Vector2:
	var radius: float = stick_radius()
	var screen: Vector2 = screen_size()
	return Vector2(screen.x - float(STICK_MARGIN) - radius, screen.y - float(STICK_MARGIN) - radius)


func dash_button_radius() -> float:
	return float(BUTTON_ART_RADIUS * BUTTON_SCALE)


func dash_button_center() -> Vector2:
	var reach: float = stick_radius() + float(BUTTON_GAP) + dash_button_radius()
	return aim_stick_center() + Vector2(-0.7071, -0.7071) * reach


func dash_button_rect() -> Rect2:
	var radius: float = dash_button_radius()
	return Rect2((dash_button_center() - Vector2(radius, radius)).floor(),
		Vector2(radius, radius) * 2.0)


func pause_button_rect() -> Rect2:
	var side: float = float(PAUSE_SIZE)
	return Rect2(Vector2((screen_size().x - side) * 0.5, float(PAUSE_MARGIN)), Vector2(side, side))


func _input(event: InputEvent) -> void:
	var touch: InputEventScreenTouch = event as InputEventScreenTouch
	if touch != null:
		GameManager.set_touch_input(true)
		if touch.pressed:
			_begin_touch(touch.index, touch.position)
		else:
			_end_touch(touch.index)
		return
	var drag: InputEventScreenDrag = event as InputEventScreenDrag
	if drag == null:
		return
	if drag.index == _move_touch:
		_move_point = drag.position
	elif drag.index == _aim_touch:
		_aim_point = drag.position


func _process(_delta: float) -> void:
	if not _active:
		return
	_apply_move()
	_apply_aim()
	_update_dash_hold()
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		release_all()


func release_all() -> void:
	_move_touch = -1
	_aim_touch = -1
	_dash_touch = -1
	_pause_touch = -1
	for action in ["move_left", "move_right", "move_up", "move_down"]:
		if Input.is_action_pressed(action):
			Input.action_release(action)
	if _controller != null:
		_controller.touch_firing = false
	queue_redraw()


func _on_input_mode_changed(touch: bool) -> void:
	if _active == touch:
		return
	_active = touch
	visible = touch
	if _controller != null:
		_controller.touch_input = touch
	if not touch:
		release_all()
	queue_redraw()


func _touched(rect: Rect2, point: Vector2) -> bool:
	return rect.grow(float(TOUCH_PADDING)).has_point(point)


func _begin_touch(index: int, point: Vector2) -> void:
	if _touched(pause_button_rect(), point):
		_pause_touch = index
		pause_requested.emit()
		queue_redraw()
		return
	if point.distance_to(dash_button_center()) <= dash_button_radius() + float(TOUCH_PADDING):
		_dash_touch = index
		_try_dash()
		queue_redraw()
		return
	var screen: Vector2 = screen_size()
	if point.y < screen.y * ZONE_TOP_FRACTION or _blocked(point):
		return
	if point.x < screen.x * 0.5:
		if _move_touch >= 0:
			return
		_move_touch = index
		_move_point = point
		return
	if _aim_touch >= 0:
		return
	_aim_touch = index
	_aim_point = point


func _blocked(point: Vector2) -> bool:
	for control in _blockers:
		if is_instance_valid(control) and control.get_global_rect().has_point(point):
			return true
	return false


func _end_touch(index: int) -> void:
	if index == _pause_touch:
		_pause_touch = -1
		queue_redraw()
		return
	if index == _dash_touch:
		_dash_touch = -1
		queue_redraw()
		return
	if index == _move_touch:
		_move_touch = -1
		_apply_move()
		return
	if index == _aim_touch:
		_aim_touch = -1
		_apply_aim()


func _pull(origin: Vector2, point: Vector2) -> Vector2:
	var offset: Vector2 = point - origin
	var strength: float = clampf(offset.length() / MAX_PULL, 0.0, 1.0)
	if strength < DEAD_ZONE:
		return Vector2.ZERO
	return offset.normalized() * strength


func _apply_move() -> void:
	var pull: Vector2 = Vector2.ZERO
	if _move_touch >= 0:
		pull = _pull(move_stick_center(), _move_point)
	_set_axis("move_left", maxf(-pull.x, 0.0))
	_set_axis("move_right", maxf(pull.x, 0.0))
	_set_axis("move_up", maxf(-pull.y, 0.0))
	_set_axis("move_down", maxf(pull.y, 0.0))


func _set_axis(action: String, strength: float) -> void:
	if strength <= 0.0:
		if Input.is_action_pressed(action):
			Input.action_release(action)
		return
	Input.action_press(action, strength)


func _apply_aim() -> void:
	if _controller == null or _player == null or not is_instance_valid(_player):
		return
	var pull: Vector2 = Vector2.ZERO
	if _aim_touch >= 0:
		pull = _pull(aim_stick_center(), _aim_point)
	if pull == Vector2.ZERO:
		_controller.touch_firing = false
		return
	_player.set_aim_override(_player.global_position + pull.normalized() * AIM_DISTANCE)
	_controller.touch_firing = true


func _update_dash_hold() -> void:
	if _dash_touch < 0:
		return
	_try_dash()


func _try_dash() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var direction: Vector2 = Vector2.ZERO
	if _move_touch >= 0:
		direction = _pull(move_stick_center(), _move_point)
	_player.try_dash(direction)


func _draw() -> void:
	if not _active:
		return
	_draw_stick(move_stick_center(), _move_point, _move_touch >= 0)
	_draw_stick(aim_stick_center(), _aim_point, _aim_touch >= 0)
	_draw_dash_button()
	_draw_pause_button()


func _draw_stick(center: Vector2, point: Vector2, held: bool) -> void:
	var dim: float = 1.0 if held else IDLE_DIM
	_draw_centered(_disc_texture, center, STICK_SCALE, _faded(RING_FILL_COLOR, dim))
	_draw_centered(_ring_texture, center, STICK_SCALE, _faded(RING_EDGE_COLOR, dim))
	var knob: Vector2 = center
	if held:
		var travel: float = float((RING_ART_RADIUS - KNOB_ART_RADIUS) * STICK_SCALE)
		var offset: Vector2 = point - center
		var strength: float = clampf(offset.length() / MAX_PULL, 0.0, 1.0)
		if not offset.is_zero_approx():
			knob = center + offset.normalized() * travel * strength
	_draw_centered(_knob_texture, knob, STICK_SCALE, _faded(KNOB_FILL_COLOR, dim))
	_draw_centered(_knob_edge_texture, knob, STICK_SCALE, _faded(KNOB_EDGE_COLOR, dim))


func _faded(color: Color, factor: float) -> Color:
	return Color(color.r, color.g, color.b, color.a * factor)


func _draw_centered(texture: ImageTexture, center: Vector2, scale: int, color: Color) -> void:
	var span: Vector2 = Vector2(texture.get_size()) * float(scale)
	var corner: Vector2 = (center - span * 0.5).floor()
	draw_texture_rect(texture, Rect2(corner, span), false, color)


func _draw_dash_button() -> void:
	var center: Vector2 = dash_button_center()
	var ready: bool = _player != null and is_instance_valid(_player) and _player.dash_ready()
	var face: Color = FACE_READY_COLOR if ready else FACE_COLOR
	if _dash_touch >= 0:
		face = PRESSED_TINT
	_draw_centered(_button_face_texture, center, BUTTON_SCALE, face)
	_draw_centered(_button_edge_texture, center, BUTTON_SCALE, EDGE_COLOR)
	if _dash_icon == null:
		return
	var icon: Vector2 = Vector2(_dash_icon.get_size())
	var spot: Vector2 = (center - icon * 0.5).floor()
	draw_texture(_dash_icon, spot, Color(1.0, 1.0, 1.0, 1.0 if ready else 0.45))


func _draw_pause_button() -> void:
	var rect: Rect2 = pause_button_rect()
	draw_rect(rect, EDGE_COLOR, true)
	draw_rect(rect.grow(-float(EDGE_THICKNESS)), PRESSED_TINT if _pause_touch >= 0 else FACE_COLOR, true)
	_draw_centered(_pause_texture, rect.get_center(), 1, EDGE_COLOR)


func _build_disc(art_radius: int, inner: float) -> ImageTexture:
	var span: int = art_radius * 2 + 1
	var image: Image = Image.create(span, span, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var center: Vector2 = Vector2(art_radius, art_radius)
	for y in span:
		for x in span:
			var distance: float = Vector2(x, y).distance_to(center)
			if distance <= float(art_radius) and distance > inner:
				image.set_pixel(x, y, Color.WHITE)
	return ImageTexture.create_from_image(image)


func _build_pattern(pattern: Array[String], scale: int) -> ImageTexture:
	var height: int = pattern.size()
	var width: int = pattern[0].length()
	var image: Image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for y in height:
		var row: String = pattern[y]
		for x in mini(width, row.length()):
			if row[x] == "#":
				image.set_pixel(x, y, Color.WHITE)
	image.resize(width * scale, height * scale, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(image)
