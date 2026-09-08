class_name ColorDialog
extends Control

signal color_confirmed(color: Color)

const FIELD_STEPS: int = 32
const HUE_STEPS: int = 32
const SWATCH_TILE_SIZE: int = 16
const SWATCH_BORDER: int = 2
const MARKER_OUTLINE_COLOR: Color = Color(0.12, 0.12, 0.12)
const MARKER_FILL_COLOR: Color = Color(1, 1, 1)
const SWATCH_BORDER_COLOR: Color = Color(0.12, 0.12, 0.12)

@onready var title_label: Label = $Center/Window/Layout/TitleLabel
@onready var field: TextureRect = $Center/Window/Layout/FieldRow/Field
@onready var field_marker: Control = $Center/Window/Layout/FieldRow/Field/FieldMarker
@onready var hue_bar: TextureRect = $Center/Window/Layout/FieldRow/HueBar
@onready var hue_marker: Control = $Center/Window/Layout/FieldRow/HueBar/HueMarker
@onready var preview_swatch: TextureRect = $Center/Window/Layout/PreviewRow/PreviewSwatch
@onready var hex_field: LineEdit = $Center/Window/Layout/PreviewRow/HexField
@onready var use_button: Button = $Center/Window/Layout/ButtonRow/UseButton
@onready var cancel_button: Button = $Center/Window/Layout/ButtonRow/CancelButton

var _color: Color = Color.BLACK
var _hue: float = 0.0
var _saturation: float = 1.0
var _value: float = 1.0
var _field_image: Image
var _field_texture: ImageTexture


func _ready() -> void:
	hide()

	_field_image = Image.create(FIELD_STEPS, FIELD_STEPS, false, Image.FORMAT_RGBA8)
	_field_texture = ImageTexture.create_from_image(_field_image)
	field.texture = _field_texture
	hue_bar.texture = _build_hue_texture()

	field.gui_input.connect(_on_field_gui_input)
	hue_bar.gui_input.connect(_on_hue_bar_gui_input)
	field_marker.draw.connect(_on_field_marker_draw)
	hue_marker.draw.connect(_on_hue_marker_draw)
	hex_field.text_submitted.connect(_on_hex_field_text_submitted)
	hex_field.focus_exited.connect(_on_hex_field_focus_exited)
	use_button.pressed.connect(_on_use_button_pressed)
	cancel_button.pressed.connect(close)
	LocalizationManager.language_changed.connect(_apply_translations)

	_apply_translations()
	_refresh_field()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var key_event: InputEventKey = event as InputEventKey
	if key_event == null or not key_event.pressed:
		return
	if key_event.keycode == KEY_ESCAPE:
		close()
	get_viewport().set_input_as_handled()


func open(starting_color: Color) -> void:
	_adopt_color(starting_color)
	_refresh_field()
	show()
	use_button.grab_focus()


func close() -> void:
	hex_field.release_focus()
	hide()


func selected_color() -> Color:
	return _color


func _adopt_color(color: Color) -> void:
	_color = Color(color.r, color.g, color.b)
	if _color.s > 0.0:
		_hue = _color.h
	_saturation = _color.s
	_value = _color.v


func _apply_translations() -> void:
	title_label.text = LocalizationManager.text("creator.color_title")
	use_button.text = LocalizationManager.text("creator.color_use")
	cancel_button.text = LocalizationManager.text("creator.cancel")


func _build_hue_texture() -> ImageTexture:
	var image: Image = Image.create(1, HUE_STEPS, false, Image.FORMAT_RGBA8)
	for y in HUE_STEPS:
		image.set_pixel(0, y, Color.from_hsv(float(y) / float(HUE_STEPS - 1), 1.0, 1.0))
	return ImageTexture.create_from_image(image)


func _refresh_field() -> void:
	for y in FIELD_STEPS:
		var value: float = 1.0 - float(y) / float(FIELD_STEPS - 1)
		for x in FIELD_STEPS:
			var saturation: float = float(x) / float(FIELD_STEPS - 1)
			_field_image.set_pixel(x, y, Color.from_hsv(_hue, saturation, value))
	_field_texture.update(_field_image)
	preview_swatch.texture = _build_preview_texture(selected_color())
	if not hex_field.has_focus():
		hex_field.text = "#%s" % selected_color().to_html(false).to_upper()
	field_marker.queue_redraw()
	hue_marker.queue_redraw()


func _build_preview_texture(color: Color) -> ImageTexture:
	var image: Image = Image.create(SWATCH_TILE_SIZE, SWATCH_TILE_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(SWATCH_BORDER_COLOR)
	for y in range(SWATCH_BORDER, SWATCH_TILE_SIZE - SWATCH_BORDER):
		for x in range(SWATCH_BORDER, SWATCH_TILE_SIZE - SWATCH_BORDER):
			image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)


func _on_field_gui_input(event: InputEvent) -> void:
	if not _is_drag_event(event):
		return
	var cell: Vector2 = _event_cell(event, field.size, FIELD_STEPS)
	_saturation = cell.x / float(FIELD_STEPS - 1)
	_value = 1.0 - cell.y / float(FIELD_STEPS - 1)
	_color = Color.from_hsv(_hue, _saturation, _value)
	hex_field.release_focus()
	_refresh_field()
	accept_event()


func _on_hue_bar_gui_input(event: InputEvent) -> void:
	if not _is_drag_event(event):
		return
	var cell: Vector2 = _event_cell(event, hue_bar.size, HUE_STEPS)
	_hue = cell.y / float(HUE_STEPS - 1)
	_color = Color.from_hsv(_hue, _saturation, _value)
	hex_field.release_focus()
	_refresh_field()
	accept_event()


func _is_drag_event(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		return event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	if event is InputEventMouseMotion:
		return (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0
	return false


func _event_cell(event: InputEvent, area_size: Vector2, steps: int) -> Vector2:
	var normalized: Vector2 = event.position / area_size.max(Vector2.ONE)
	var cell_x: int = clampi(int(normalized.x * steps), 0, steps - 1)
	var cell_y: int = clampi(int(normalized.y * steps), 0, steps - 1)
	return Vector2(cell_x, cell_y)


func _on_field_marker_draw() -> void:
	var cell_size: Vector2 = field_marker.size / float(FIELD_STEPS)
	var origin: Vector2 = Vector2(
		_saturation * (FIELD_STEPS - 1) * cell_size.x,
		(1.0 - _value) * (FIELD_STEPS - 1) * cell_size.y
	)
	var rect: Rect2 = Rect2(origin, cell_size)
	field_marker.draw_rect(rect.grow(1.0), MARKER_OUTLINE_COLOR, false, 2.0)
	field_marker.draw_rect(rect.grow(-1.0), MARKER_FILL_COLOR, false, 2.0)


func _on_hue_marker_draw() -> void:
	var band_height: float = hue_marker.size.y / float(HUE_STEPS)
	var origin: Vector2 = Vector2(0.0, _hue * (HUE_STEPS - 1) * band_height)
	var rect: Rect2 = Rect2(origin, Vector2(hue_marker.size.x, band_height))
	hue_marker.draw_rect(rect.grow(1.0), MARKER_OUTLINE_COLOR, false, 2.0)
	hue_marker.draw_rect(rect.grow(-1.0), MARKER_FILL_COLOR, false, 2.0)


func _on_hex_field_text_submitted(submitted_text: String) -> void:
	_apply_hex(submitted_text)


func _on_hex_field_focus_exited() -> void:
	_apply_hex(hex_field.text)


func _apply_hex(hex_text: String) -> void:
	var cleaned: String = hex_text.strip_edges().trim_prefix("#")
	if not cleaned.is_valid_html_color():
		hex_field.text = "#%s" % selected_color().to_html(false).to_upper()
		return
	_adopt_color(Color.html(cleaned))
	_refresh_field()


func _on_use_button_pressed() -> void:
	_apply_hex(hex_field.text)
	color_confirmed.emit(selected_color())
	close()
