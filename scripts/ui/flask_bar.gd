class_name FlaskBar
extends Control

const SLOT_WIDTH: int = 13
const SLOT_HEIGHT: int = 16
const SLOT_SCALE: int = 2
const SLOT_SEPARATION: int = 4
const KEY_FONT_SIZE: int = 8
const KEY_GAP: int = 4
const KEY_COLOR: Color = Color(0.2, 0.2, 0.2, 1.0)
const FRAME_COLOR: Color = Color(0.18, 0.18, 0.18, 1.0)
const EMPTY_COLOR: Color = Color(0.78, 0.78, 0.75, 0.6)
const ACTIVE_BAR_HEIGHT: float = 3.0

static var _slot_cache: Dictionary = {}

var _rows: HBoxContainer = null
var _active_bar: ColorRect = null
var _belt: FlaskBelt = null
var _cells: Array[TextureRect] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 2)
	add_child(column)

	_rows = HBoxContainer.new()
	_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rows.add_theme_constant_override("separation", SLOT_SEPARATION)
	column.add_child(_rows)

	_active_bar = ColorRect.new()
	_active_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_active_bar.custom_minimum_size = Vector2(0.0, ACTIVE_BAR_HEIGHT)
	_active_bar.visible = false
	column.add_child(_active_bar)


func setup(belt: FlaskBelt) -> void:
	_belt = belt
	if _belt == null:
		return
	if not _belt.slots_changed.is_connected(refresh):
		_belt.slots_changed.connect(refresh)
	if not _belt.effect_changed.is_connected(_on_effect_changed):
		_belt.effect_changed.connect(_on_effect_changed)
	refresh()


func refresh() -> void:
	if _belt == null:
		return
	var capacity: int = _belt.capacity()
	while _cells.size() > capacity:
		_cells.pop_back().queue_free()
	while _cells.size() < capacity:
		_cells.append(_build_cell(_cells.size() + 1))

	for index in _cells.size():
		var color: Color = EMPTY_COLOR
		if index < _belt.slots.size():
			color = _belt.slots[index]["color"]
		_cells[index].texture = _slot_texture(color, index < _belt.slots.size())


func slot_count() -> int:
	return _belt.slots.size() if _belt != null else 0


func capacity() -> int:
	return _cells.size()


func active_color() -> Color:
	return _active_bar.color if _active_bar.visible else Color(0, 0, 0, 0)


func _build_cell(key_number: int) -> TextureRect:
	var cell: VBoxContainer = VBoxContainer.new()
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_theme_constant_override("separation", KEY_GAP)
	_rows.add_child(cell)

	var icon: TextureRect = TextureRect.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	icon.custom_minimum_size = Vector2(SLOT_WIDTH * SLOT_SCALE, SLOT_HEIGHT * SLOT_SCALE)
	cell.add_child(icon)

	var key: Label = Label.new()
	key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	key.text = str(key_number)
	key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key.add_theme_font_size_override("font_size", KEY_FONT_SIZE)
	key.add_theme_color_override("font_color", KEY_COLOR)
	cell.add_child(key)
	return icon


func _on_effect_changed(color: Color, effects: Array[String]) -> void:
	_active_bar.visible = not effects.is_empty()
	_active_bar.color = color


static func _slot_texture(color: Color, filled: bool) -> ImageTexture:
	var key: String = "%s|%s" % [color.to_html(), filled]
	if _slot_cache.has(key):
		return _slot_cache[key]

	var image: Image = Image.create(SLOT_WIDTH, SLOT_HEIGHT, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for x in SLOT_WIDTH:
		image.set_pixel(x, 0, FRAME_COLOR)
		image.set_pixel(x, SLOT_HEIGHT - 1, FRAME_COLOR)
	for y in SLOT_HEIGHT:
		image.set_pixel(0, y, FRAME_COLOR)
		image.set_pixel(SLOT_WIDTH - 1, y, FRAME_COLOR)

	if filled:
		var flask: Image = PaintFlask.texture_for(color, 1, true).get_image()
		var offset_x: int = (SLOT_WIDTH - flask.get_width()) / 2
		var offset_y: int = (SLOT_HEIGHT - flask.get_height()) / 2
		for y in flask.get_height():
			for x in flask.get_width():
				var pixel: Color = flask.get_pixel(x, y)
				if pixel.a > 0.0:
					image.set_pixel(x + offset_x, y + offset_y, pixel)
	else:
		for y in range(2, SLOT_HEIGHT - 2):
			for x in range(2, SLOT_WIDTH - 2):
				if (x + y) % 2 == 0:
					image.set_pixel(x, y, EMPTY_COLOR)

	image.resize(SLOT_WIDTH * SLOT_SCALE, SLOT_HEIGHT * SLOT_SCALE, Image.INTERPOLATE_NEAREST)
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	_slot_cache[key] = texture
	return texture
