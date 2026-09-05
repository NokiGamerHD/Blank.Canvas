class_name PixelEditor
extends Control

signal drawing_changed

@export var grid_size: int = 36

@export var cell_pixels: int = 10

@export var grid_line_color: Color = Color(0, 0, 0, 0.10)
@export var border_color: Color = Color(0.2, 0.2, 0.2, 0.9)
@export var checker_color_a: Color = Color(1, 1, 1, 1)
@export var checker_color_b: Color = Color(0.93, 0.93, 0.93, 1)

const MAX_UNDO_STEPS: int = 64

const NEIGHBOR_OFFSETS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
]

var current_color: Color = Color.BLACK
var brush_size: int = 1
var eraser_enabled: bool = false

var _image: Image
var _texture: ImageTexture
var _undo_stack: Array[Image] = []
var _redo_stack: Array[Image] = []

var _is_drawing: bool = false
var _stroke_erase: bool = false
var _last_cell: Vector2i = Vector2i(-1, -1)

@onready var _canvas_background: TextureRect = $CanvasBackground
@onready var _drawing_area: TextureRect = $DrawingArea
@onready var _grid_overlay: Control = $GridOverlay


func _ready() -> void:
	custom_minimum_size = Vector2(grid_size * cell_pixels, grid_size * cell_pixels)

	_image = Image.create(grid_size, grid_size, false, Image.FORMAT_RGBA8)
	_image.fill(Color(0, 0, 0, 0))
	_texture = ImageTexture.create_from_image(_image)
	_drawing_area.texture = _texture

	_canvas_background.texture = _build_checkerboard_texture()

	_grid_overlay.draw.connect(_on_grid_overlay_draw)
	resized.connect(_grid_overlay.queue_redraw)
	_grid_overlay.queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				_begin_stroke(event.position, event.button_index == MOUSE_BUTTON_RIGHT)
			else:
				_end_stroke()
			accept_event()
	elif event is InputEventMouseMotion and _is_drawing:
		if (event.button_mask & (MOUSE_BUTTON_MASK_LEFT | MOUSE_BUTTON_MASK_RIGHT)) == 0:
			_end_stroke()
			return
		_continue_stroke(event.position)
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.ctrl_pressed:
		if event.keycode == KEY_Z and event.shift_pressed:
			redo()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_Z:
			undo()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_Y:
			redo()
			get_viewport().set_input_as_handled()


func _begin_stroke(pos: Vector2, force_erase: bool) -> void:
	_push_undo_snapshot()
	_is_drawing = true
	_stroke_erase = eraser_enabled or force_erase
	var cell: Vector2i = _position_to_cell(pos)
	_last_cell = cell
	_apply_brush(cell)
	_commit_changes()


func _continue_stroke(pos: Vector2) -> void:
	var cell: Vector2i = _position_to_cell(pos)
	if cell == _last_cell:
		return
	_paint_line(_last_cell, cell)
	_last_cell = cell
	_commit_changes()


func _end_stroke() -> void:
	_is_drawing = false
	_last_cell = Vector2i(-1, -1)


func _position_to_cell(pos: Vector2) -> Vector2i:
	var cell_width: float = size.x / float(grid_size)
	var cell_height: float = size.y / float(grid_size)
	var cell_x: int = int(floor(pos.x / cell_width))
	var cell_y: int = int(floor(pos.y / cell_height))
	return Vector2i(clampi(cell_x, 0, grid_size - 1), clampi(cell_y, 0, grid_size - 1))


func _apply_brush(center: Vector2i) -> void:
	var paint_color: Color = Color(0, 0, 0, 0) if _stroke_erase else current_color
	var half: int = int((brush_size - 1) / 2.0)
	for offset_y in range(-half, brush_size - half):
		for offset_x in range(-half, brush_size - half):
			var pixel: Vector2i = center + Vector2i(offset_x, offset_y)
			if pixel.x >= 0 and pixel.x < grid_size and pixel.y >= 0 and pixel.y < grid_size:
				_image.set_pixelv(pixel, paint_color)


func _paint_line(from_cell: Vector2i, to_cell: Vector2i) -> void:
	var delta: Vector2i = (to_cell - from_cell).abs()
	var step_x: int = 1 if from_cell.x < to_cell.x else -1
	var step_y: int = 1 if from_cell.y < to_cell.y else -1
	var error: int = delta.x - delta.y
	var current: Vector2i = from_cell
	while true:
		_apply_brush(current)
		if current == to_cell:
			break
		var error_double: int = error * 2
		if error_double > -delta.y:
			error -= delta.y
			current.x += step_x
		if error_double < delta.x:
			error += delta.x
			current.y += step_y


func _commit_changes() -> void:
	_texture.update(_image)
	drawing_changed.emit()


func set_current_color(color: Color) -> void:
	current_color = color
	eraser_enabled = false


func set_brush_size(value: int) -> void:
	brush_size = clampi(value, 1, 8)


func set_eraser(enabled: bool) -> void:
	eraser_enabled = enabled


func clear_canvas() -> void:
	_push_undo_snapshot()
	_image.fill(Color(0, 0, 0, 0))
	_commit_changes()


func _push_undo_snapshot() -> void:
	_undo_stack.append(_image.duplicate())
	if _undo_stack.size() > MAX_UNDO_STEPS:
		_undo_stack.pop_front()
	_redo_stack.clear()


func can_undo() -> bool:
	return not _undo_stack.is_empty()


func can_redo() -> bool:
	return not _redo_stack.is_empty()


func undo() -> void:
	if _undo_stack.is_empty():
		return
	_redo_stack.append(_image.duplicate())
	_image = _undo_stack.pop_back()
	_commit_changes()


func redo() -> void:
	if _redo_stack.is_empty():
		return
	_undo_stack.append(_image.duplicate())
	_image = _redo_stack.pop_back()
	_commit_changes()


func get_image_copy() -> Image:
	return _image.duplicate()


func load_from_image(source: Image) -> void:
	if source == null:
		return
	var copy: Image = source.duplicate()
	if copy.get_format() != Image.FORMAT_RGBA8:
		copy.convert(Image.FORMAT_RGBA8)
	if copy.get_width() != grid_size or copy.get_height() != grid_size:
		copy.resize(grid_size, grid_size, Image.INTERPOLATE_NEAREST)
	_push_undo_snapshot()
	_image = copy
	_commit_changes()


func painted_pixel_count() -> int:
	var count: int = 0
	for y in grid_size:
		for x in grid_size:
			if _image.get_pixel(x, y).a > 0.0:
				count += 1
	return count


func outline_pixel_count() -> int:
	var outside: Array[bool] = _build_outside_mask()
	var count: int = 0
	for y in grid_size:
		for x in grid_size:
			if _image.get_pixel(x, y).a <= 0.0:
				continue
			if _touches_outside(Vector2i(x, y), outside):
				count += 1
	return count


func _build_outside_mask() -> Array[bool]:
	var outside: Array[bool] = []
	outside.resize(grid_size * grid_size)
	outside.fill(false)

	var pending: Array[Vector2i] = []
	for i in grid_size:
		_mark_outside(Vector2i(i, 0), outside, pending)
		_mark_outside(Vector2i(i, grid_size - 1), outside, pending)
		_mark_outside(Vector2i(0, i), outside, pending)
		_mark_outside(Vector2i(grid_size - 1, i), outside, pending)

	while not pending.is_empty():
		var cell: Vector2i = pending.pop_back()
		for offset in NEIGHBOR_OFFSETS:
			_mark_outside(cell + offset, outside, pending)
	return outside


func _mark_outside(cell: Vector2i, outside: Array[bool], pending: Array[Vector2i]) -> void:
	if not _is_inside_grid(cell):
		return
	var index: int = cell.y * grid_size + cell.x
	if outside[index]:
		return
	if _image.get_pixelv(cell).a > 0.0:
		return
	outside[index] = true
	pending.append(cell)


func _touches_outside(cell: Vector2i, outside: Array[bool]) -> bool:
	for offset in NEIGHBOR_OFFSETS:
		var neighbor: Vector2i = cell + offset
		if not _is_inside_grid(neighbor):
			return true
		if outside[neighbor.y * grid_size + neighbor.x]:
			return true
	return false


func _is_inside_grid(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < grid_size and cell.y >= 0 and cell.y < grid_size


func has_any_pixels() -> bool:
	for y in grid_size:
		for x in grid_size:
			if _image.get_pixel(x, y).a > 0.0:
				return true
	return false


func _build_checkerboard_texture() -> ImageTexture:
	var checker: Image = Image.create(grid_size, grid_size, false, Image.FORMAT_RGBA8)
	for y in grid_size:
		for x in grid_size:
			var checker_color: Color = checker_color_a if (x + y) % 2 == 0 else checker_color_b
			checker.set_pixel(x, y, checker_color)
	return ImageTexture.create_from_image(checker)


func _on_grid_overlay_draw() -> void:
	var cell_width: float = size.x / float(grid_size)
	var cell_height: float = size.y / float(grid_size)
	for i in range(grid_size + 1):
		var x: float = i * cell_width
		var y: float = i * cell_height
		_grid_overlay.draw_line(Vector2(x, 0), Vector2(x, size.y), grid_line_color, 1.0)
		_grid_overlay.draw_line(Vector2(0, y), Vector2(size.x, y), grid_line_color, 1.0)
	_grid_overlay.draw_rect(Rect2(Vector2.ZERO, size), border_color, false, 2.0)
