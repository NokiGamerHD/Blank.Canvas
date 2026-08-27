class_name DrawingCreatorBase
extends Control

const PALETTE_COLORS: Array[Color] = [
	Color("000000"), Color("555555"), Color("aaaaaa"), Color("ffffff"),
	Color("d94f4f"), Color("f2913d"), Color("f2d541"), Color("7abf5a"),
	Color("2e8a5c"), Color("4fc3d9"), Color("3f6fd9"), Color("6a4fd9"),
	Color("c95fd9"), Color("f28dbb"), Color("8a5a3c"), Color("e8c9a0"),
]

const SELECTED_BORDER_COLOR: Color = Color(0.12, 0.12, 0.12)
const NORMAL_BORDER_COLOR: Color = Color(0, 0, 0, 0.25)

const SWATCH_TILE_SIZE: int = 16
const SWATCH_BORDER: int = 2
const SWATCH_CORNER_CUTS: Array[Vector2i] = [
	Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0),
	Vector2i(0, 1), Vector2i(1, 1),
	Vector2i(0, 2),
]

@onready var pixel_editor: PixelEditor = $CenterContainer/MainContainer/EditorRow/PixelEditor
@onready var title_label: Label = $CenterContainer/MainContainer/TitleLabel
@onready var palette_grid: GridContainer = $CenterContainer/MainContainer/EditorRow/SidePanel/PaletteGrid
@onready var palette_label: Label = $CenterContainer/MainContainer/EditorRow/SidePanel/PaletteLabel
@onready var brush_label: Label = $CenterContainer/MainContainer/EditorRow/SidePanel/BrushLabel
@onready var brush_slider: HSlider = $CenterContainer/MainContainer/EditorRow/SidePanel/BrushSlider
@onready var eraser_button: Button = $CenterContainer/MainContainer/EditorRow/SidePanel/EraserButton
@onready var clear_button: Button = $CenterContainer/MainContainer/EditorRow/SidePanel/ClearButton
@onready var undo_button: Button = $CenterContainer/MainContainer/EditorRow/SidePanel/HistoryRow/UndoButton
@onready var redo_button: Button = $CenterContainer/MainContainer/EditorRow/SidePanel/HistoryRow/RedoButton
@onready var confirm_button: Button = $CenterContainer/MainContainer/EditorRow/SidePanel/ConfirmButton
@onready var back_button: Button = $CenterContainer/MainContainer/EditorRow/SidePanel/BackButton
@onready var feedback_label: Label = $FeedbackLabel

var _palette_group: ButtonGroup = ButtonGroup.new()
var _feedback_key: String = ""
var _feedback_values: Array = []


func _ready() -> void:
	_build_palette()

	brush_slider.value_changed.connect(_on_brush_slider_value_changed)
	eraser_button.toggled.connect(_on_eraser_button_toggled)
	clear_button.pressed.connect(_on_clear_button_pressed)
	undo_button.pressed.connect(_on_undo_button_pressed)
	redo_button.pressed.connect(_on_redo_button_pressed)
	confirm_button.pressed.connect(_on_confirm_button_pressed)
	back_button.pressed.connect(_on_back_button_pressed)
	pixel_editor.drawing_changed.connect(_on_drawing_changed)
	LocalizationManager.language_changed.connect(_apply_translations)

	feedback_label.text = ""
	_apply_translations()
	_update_history_buttons()
	_on_creator_ready()


func _on_creator_ready() -> void:
	pass


func _on_confirm_button_pressed() -> void:
	pass


func _on_back_button_pressed() -> void:
	pass


func _creator_title_key() -> String:
	return ""


func _back_button_key() -> String:
	return "creator.back_menu"


func _apply_translations() -> void:
	title_label.text = LocalizationManager.text(_creator_title_key())
	palette_label.text = LocalizationManager.text("creator.colors")
	eraser_button.text = LocalizationManager.text("creator.eraser")
	clear_button.text = LocalizationManager.text("creator.clear")
	undo_button.text = LocalizationManager.text("creator.undo")
	redo_button.text = LocalizationManager.text("creator.redo")
	confirm_button.text = LocalizationManager.text("creator.confirm")
	back_button.text = LocalizationManager.text(_back_button_key())
	_update_brush_label(int(brush_slider.value))
	if not _feedback_key.is_empty():
		feedback_label.text = LocalizationManager.text(_feedback_key, _feedback_values)


func _build_palette() -> void:
	for color in PALETTE_COLORS:
		var button: Button = Button.new()
		button.toggle_mode = true
		button.button_group = _palette_group
		button.custom_minimum_size = Vector2(32, 32)
		button.focus_mode = Control.FOCUS_NONE

		var normal_style: StyleBoxTexture = _make_swatch_style(color, NORMAL_BORDER_COLOR)
		var selected_style: StyleBoxTexture = _make_swatch_style(color, SELECTED_BORDER_COLOR)
		button.add_theme_stylebox_override("normal", normal_style)
		button.add_theme_stylebox_override("hover", normal_style)
		button.add_theme_stylebox_override("pressed", selected_style)
		button.add_theme_stylebox_override("hover_pressed", selected_style)
		button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

		button.toggled.connect(_on_palette_button_toggled.bind(color))
		palette_grid.add_child(button)

	var first_button: Button = palette_grid.get_child(0)
	first_button.button_pressed = true


func _make_swatch_texture(fill_color: Color, border_color: Color) -> ImageTexture:
	var tile_size: int = SWATCH_TILE_SIZE
	var image: Image = Image.create(tile_size, tile_size, false, Image.FORMAT_RGBA8)
	image.fill(border_color)
	for y in range(SWATCH_BORDER, tile_size - SWATCH_BORDER):
		for x in range(SWATCH_BORDER, tile_size - SWATCH_BORDER):
			image.set_pixel(x, y, fill_color)
	for cut in SWATCH_CORNER_CUTS:
		var dx: int = cut.x
		var dy: int = cut.y
		image.set_pixel(dx, dy, Color(0, 0, 0, 0))
		image.set_pixel(tile_size - 1 - dx, dy, Color(0, 0, 0, 0))
		image.set_pixel(dx, tile_size - 1 - dy, Color(0, 0, 0, 0))
		image.set_pixel(tile_size - 1 - dx, tile_size - 1 - dy, Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(image)


func _make_swatch_style(fill_color: Color, border_color: Color) -> StyleBoxTexture:
	var style: StyleBoxTexture = StyleBoxTexture.new()
	style.texture = _make_swatch_texture(fill_color, border_color)
	style.texture_margin_left = 4
	style.texture_margin_top = 4
	style.texture_margin_right = 4
	style.texture_margin_bottom = 4
	return style


func _on_palette_button_toggled(toggled_on: bool, color: Color) -> void:
	if not toggled_on:
		return
	pixel_editor.set_current_color(color)
	eraser_button.button_pressed = false


func _on_brush_slider_value_changed(value: float) -> void:
	var brush_value: int = int(value)
	pixel_editor.set_brush_size(brush_value)
	_update_brush_label(brush_value)


func _update_brush_label(brush_value: int) -> void:
	brush_label.text = LocalizationManager.text("creator.brush", [brush_value])


func _on_eraser_button_toggled(toggled_on: bool) -> void:
	pixel_editor.set_eraser(toggled_on)


func _on_clear_button_pressed() -> void:
	pixel_editor.clear_canvas()
	_show_feedback("creator.canvas_cleared")


func _on_undo_button_pressed() -> void:
	pixel_editor.undo()


func _on_redo_button_pressed() -> void:
	pixel_editor.redo()


func _on_drawing_changed() -> void:
	_update_history_buttons()


func _update_history_buttons() -> void:
	undo_button.disabled = not pixel_editor.can_undo()
	redo_button.disabled = not pixel_editor.can_redo()


func _show_feedback(key: String, values: Array = []) -> void:
	_feedback_key = key
	_feedback_values = values
	feedback_label.text = LocalizationManager.text(key, values)
