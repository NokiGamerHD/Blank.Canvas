class_name FlaskBar
extends Control

const SLOT_WIDTH: int = 13
const SLOT_HEIGHT: int = 16
const SLOT_SCALE: int = 2
const SLOT_SEPARATION: int = 4
const SLOTS_PER_ROW: int = 4
const ROW_SEPARATION: int = 3
const KEY_FONT_SIZE: int = 8
const KEY_GAP: int = 4
const KEY_COLOR: Color = Color(0.2, 0.2, 0.2, 1.0)
const FRAME_COLOR: Color = Color(0.18, 0.18, 0.18, 1.0)
const EMPTY_COLOR: Color = Color(0.78, 0.78, 0.75, 0.6)

static var _slot_cache: Dictionary = {}

var _column: VBoxContainer = null
var _rows: Array[HBoxContainer] = []
var _belt: FlaskBelt = null
var _cells: Array[TextureRect] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column = VBoxContainer.new()
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_theme_constant_override("separation", ROW_SEPARATION)
	add_child(_column)


func setup(belt: FlaskBelt) -> void:
	_belt = belt
	if _belt == null:
		return
	if not _belt.slots_changed.is_connected(refresh):
		_belt.slots_changed.connect(refresh)
	refresh()


func refresh() -> void:
	if _belt == null:
		return
	var capacity: int = _belt.capacity()
	while _cells.size() > capacity:
		_cells.pop_back().get_parent().queue_free()
	while _cells.size() < capacity:
		_cells.append(_build_cell(_cells.size()))
	_drop_empty_rows()

	for index in _cells.size():
		var color: Color = EMPTY_COLOR
		if index < _belt.slots.size():
			color = _belt.slots[index]["color"]
		_cells[index].texture = _slot_texture(color, index < _belt.slots.size())


func slot_count() -> int:
	return _belt.slots.size() if _belt != null else 0


func capacity() -> int:
	return _cells.size()


func row_count() -> int:
	return _rows.size()


func slots_in_row(row: int) -> int:
	if row < 0 or row >= _rows.size():
		return 0
	return _live_children(_rows[row])


func _row_for(index: int) -> HBoxContainer:
	var wanted: int = index / SLOTS_PER_ROW
	while _rows.size() <= wanted:
		var row: HBoxContainer = HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", SLOT_SEPARATION)
		_column.add_child(row)
		_rows.append(row)
	return _rows[wanted]


func _drop_empty_rows() -> void:
	while _rows.size() > 1 and _live_children(_rows.back()) == 0:
		var row: HBoxContainer = _rows.pop_back()
		row.queue_free()


func _live_children(row: HBoxContainer) -> int:
	var count: int = 0
	for child in row.get_children():
		if not child.is_queued_for_deletion():
			count += 1
	return count


func _build_cell(index: int) -> TextureRect:
	var cell: VBoxContainer = VBoxContainer.new()
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_theme_constant_override("separation", KEY_GAP)
	_row_for(index).add_child(cell)

	var icon: TextureRect = TextureRect.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	icon.custom_minimum_size = Vector2(SLOT_WIDTH * SLOT_SCALE, SLOT_HEIGHT * SLOT_SCALE)
	cell.add_child(icon)

	var key: Label = Label.new()
	key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	key.text = str(index + 1)
	key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key.add_theme_font_size_override("font_size", KEY_FONT_SIZE)
	key.add_theme_color_override("font_color", KEY_COLOR)
	cell.add_child(key)
	return icon


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
