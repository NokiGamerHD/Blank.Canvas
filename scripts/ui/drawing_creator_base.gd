class_name DrawingCreatorBase
extends Control

const PALETTE_COLORS: Array[Color] = [
	Color("000000"), Color("555555"), Color("aaaaaa"), Color("ffffff"),
	Color("d94f4f"), Color("f2913d"), Color("f2d541"), Color("7abf5a"),
	Color("2e8a5c"), Color("4fc3d9"), Color("3f6fd9"), Color("6a4fd9"),
	Color("c95fd9"), Color("f28dbb"), Color("8a5a3c"), Color("e8c9a0"),
]

const WEB_COPY_SCRIPT: String = "(function(text){var area=document.createElement('textarea');area.value=text;area.setAttribute('readonly','');area.style.position='fixed';area.style.top='-1000px';area.style.opacity='0';document.body.appendChild(area);area.focus();area.select();area.setSelectionRange(0,text.length);var copied=false;try{copied=document.execCommand('copy');}catch(error){copied=false;}document.body.removeChild(area);if(!copied&&navigator.clipboard&&navigator.clipboard.writeText){navigator.clipboard.writeText(text);copied=true;}var canvas=document.getElementsByTagName('canvas')[0];if(canvas){canvas.focus();}return copied;})(%s)"

const WEB_PASTE_SCRIPT: String = "(function(){var text=window.prompt(%s,'');var canvas=document.getElementsByTagName('canvas')[0];if(canvas){canvas.focus();}return text===null?'':text;})()"

const SELECTED_BORDER_COLOR: Color = Color(0.12, 0.12, 0.12)
const NORMAL_BORDER_COLOR: Color = Color(0, 0, 0, 0.25)

const SWATCH_TILE_SIZE: int = 16
const SWATCH_BORDER: int = 2
const SWATCH_BUTTON_SIZE: int = 24
const SWATCH_CORNER_CUTS: Array[Vector2i] = [
	Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0),
	Vector2i(0, 1), Vector2i(1, 1),
	Vector2i(0, 2),
]

const TOOL_BUTTON_SIZE: int = 34
const TOOL_ICON_SCALE: int = 2
const TOOL_INK_COLOR: Color = Color(0.12, 0.12, 0.12)
const TOOL_FACE_COLOR: Color = Color(0.87, 0.87, 0.84)
const TOOL_HOVER_COLOR: Color = Color(0.95, 0.95, 0.92)
const TOOL_SELECTED_COLOR: Color = Color(0.72, 0.72, 0.68)

const TOOL_ORDER: Array[int] = [
	PixelEditor.Tool.PENCIL,
	PixelEditor.Tool.ERASER,
	PixelEditor.Tool.BUCKET,
	PixelEditor.Tool.PICKER,
	PixelEditor.Tool.LINE,
	PixelEditor.Tool.RECTANGLE,
	PixelEditor.Tool.ELLIPSE,
	PixelEditor.Tool.SPRAY,
]

const TOOL_NAME_KEYS: Dictionary = {
	PixelEditor.Tool.PENCIL: "creator.tool_pencil",
	PixelEditor.Tool.ERASER: "creator.eraser",
	PixelEditor.Tool.BUCKET: "creator.tool_bucket",
	PixelEditor.Tool.PICKER: "creator.tool_picker",
	PixelEditor.Tool.LINE: "creator.tool_line",
	PixelEditor.Tool.RECTANGLE: "creator.tool_rectangle",
	PixelEditor.Tool.ELLIPSE: "creator.tool_ellipse",
	PixelEditor.Tool.SPRAY: "creator.tool_spray",
}

const TOOL_ICONS: Dictionary = {
	PixelEditor.Tool.PENCIL: [
		"........###.",
		".......####.",
		"......####..",
		".....####...",
		"....####....",
		"...####.....",
		"..####......",
		".####.......",
		"####........",
		"###.........",
		"##..........",
		"#...........",
	],
	PixelEditor.Tool.ERASER: [
		"............",
		"......####..",
		".....#...##.",
		"....#...#.#.",
		"...#...#..#.",
		"..#...#...#.",
		".#...#....#.",
		"#...#....#..",
		"#..#....#...",
		"#.#....#....",
		"##....#.....",
		".######.....",
	],
	PixelEditor.Tool.BUCKET: [
		"...##..##...",
		"..#......#..",
		"..#......#..",
		".##########.",
		".#........#.",
		".#........#.",
		"..#......#..",
		"..#......#..",
		"...#....#...",
		"....####....",
		".........##.",
		"........####",
	],
	PixelEditor.Tool.PICKER: [
		".......#####",
		"......######",
		"......#####.",
		".....###....",
		"....###.....",
		"...###......",
		"..###.......",
		".###........",
		"##..........",
		"#...........",
		"............",
		"............",
	],
	PixelEditor.Tool.LINE: [
		"..........##",
		"..........##",
		"........##..",
		".......##...",
		"......##....",
		".....##.....",
		"....##......",
		"...##.......",
		"..##........",
		"##..........",
		"##..........",
		"............",
	],
	PixelEditor.Tool.RECTANGLE: [
		"............",
		"............",
		"..########..",
		"..#......#..",
		"..#......#..",
		"..#......#..",
		"..#......#..",
		"..#......#..",
		"..########..",
		"............",
		"............",
		"............",
	],
	PixelEditor.Tool.ELLIPSE: [
		"............",
		"...######...",
		"..#......#..",
		".#........#.",
		"#..........#",
		"#..........#",
		"#..........#",
		"#..........#",
		".#........#.",
		"..#......#..",
		"...######...",
		"............",
	],
	PixelEditor.Tool.SPRAY: [
		"....##......",
		"...####.....",
		"...#..#..#..",
		"...#..#.....",
		"...#..#.#...",
		"...#..#...#.",
		"...#..#.#...",
		"...#..#..#..",
		"...####.....",
		"...####.....",
		"............",
		"............",
	],
}

@onready var pixel_editor: PixelEditor = $CenterContainer/MainContainer/EditorRow/PixelEditor
@onready var title_label: Label = $CenterContainer/MainContainer/TitleLabel
@onready var tool_label: Label = $CenterContainer/MainContainer/EditorRow/SidePanel/ToolLabel
@onready var tool_grid: GridContainer = $CenterContainer/MainContainer/EditorRow/SidePanel/ToolGrid
@onready var fill_shapes_button: Button = $CenterContainer/MainContainer/EditorRow/SidePanel/FillShapesButton
@onready var palette_grid: GridContainer = $CenterContainer/MainContainer/EditorRow/SidePanel/PaletteGrid
@onready var palette_label: Label = $CenterContainer/MainContainer/EditorRow/SidePanel/PaletteHeader/PaletteLabel
@onready var current_color_swatch: TextureRect = $CenterContainer/MainContainer/EditorRow/SidePanel/PaletteHeader/CurrentColorSwatch
@onready var brush_label: Label = $CenterContainer/MainContainer/EditorRow/SidePanel/BrushLabel
@onready var brush_slider: HSlider = $CenterContainer/MainContainer/EditorRow/SidePanel/BrushSlider
@onready var clear_button: Button = $CenterContainer/MainContainer/EditorRow/SidePanel/ClearButton
@onready var undo_button: Button = $CenterContainer/MainContainer/EditorRow/SidePanel/HistoryRow/UndoButton
@onready var redo_button: Button = $CenterContainer/MainContainer/EditorRow/SidePanel/HistoryRow/RedoButton
@onready var confirm_button: Button = $CenterContainer/MainContainer/EditorRow/SidePanel/ConfirmButton
@onready var back_button: Button = $CenterContainer/MainContainer/EditorRow/SidePanel/BackButton
@onready var code_label: Label = $CenterContainer/MainContainer/CodeRow/CodeLabel
@onready var code_field: LineEdit = $CenterContainer/MainContainer/CodeRow/CodeField
@onready var copy_code_button: Button = $CenterContainer/MainContainer/CodeRow/CopyCodeButton
@onready var paste_code_button: Button = $CenterContainer/MainContainer/CodeRow/PasteCodeButton
@onready var load_code_button: Button = $CenterContainer/MainContainer/CodeRow/LoadCodeButton
@onready var feedback_label: Label = $CenterContainer/MainContainer/FeedbackLabel

var _palette_group: ButtonGroup = ButtonGroup.new()
var _tool_group: ButtonGroup = ButtonGroup.new()
var _tool_buttons: Dictionary = {}
var _feedback_key: String = ""
var _feedback_values: Array = []


func _ready() -> void:
	_build_tools()
	_build_palette()

	brush_slider.value_changed.connect(_on_brush_slider_value_changed)
	fill_shapes_button.toggled.connect(_on_fill_shapes_button_toggled)
	clear_button.pressed.connect(_on_clear_button_pressed)
	undo_button.pressed.connect(_on_undo_button_pressed)
	redo_button.pressed.connect(_on_redo_button_pressed)
	confirm_button.pressed.connect(_on_confirm_button_pressed)
	back_button.pressed.connect(_on_back_button_pressed)
	copy_code_button.pressed.connect(_on_copy_code_button_pressed)
	paste_code_button.pressed.connect(_on_paste_code_button_pressed)
	load_code_button.pressed.connect(_on_load_code_button_pressed)
	code_field.text_submitted.connect(_on_code_field_text_submitted)
	pixel_editor.drawing_changed.connect(_on_drawing_changed)
	pixel_editor.color_picked.connect(_on_editor_color_picked)
	pixel_editor.tool_changed.connect(_on_editor_tool_changed)
	LocalizationManager.language_changed.connect(_apply_translations)

	feedback_label.text = ""
	_apply_translations()
	_update_history_buttons()
	_on_creator_ready()
	_update_code_field()


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
	fill_shapes_button.text = LocalizationManager.text("creator.fill_shapes")
	clear_button.text = LocalizationManager.text("creator.clear")
	undo_button.text = LocalizationManager.text("creator.undo")
	redo_button.text = LocalizationManager.text("creator.redo")
	confirm_button.text = LocalizationManager.text("creator.confirm")
	back_button.text = LocalizationManager.text(_back_button_key())
	code_label.text = LocalizationManager.text("creator.code")
	code_field.placeholder_text = LocalizationManager.text("creator.code_placeholder")
	copy_code_button.text = LocalizationManager.text("creator.copy")
	paste_code_button.text = LocalizationManager.text("creator.paste")
	load_code_button.text = LocalizationManager.text("creator.load")
	for tool_id in TOOL_ORDER:
		var button: Button = _tool_buttons[tool_id]
		button.tooltip_text = LocalizationManager.text(TOOL_NAME_KEYS[tool_id])
	_update_tool_label()
	_update_brush_label(int(brush_slider.value))
	if not _feedback_key.is_empty():
		feedback_label.text = LocalizationManager.text(_feedback_key, _feedback_values)


func _build_tools() -> void:
	for tool_id in TOOL_ORDER:
		var button: Button = Button.new()
		button.toggle_mode = true
		button.button_group = _tool_group
		button.custom_minimum_size = Vector2(TOOL_BUTTON_SIZE, TOOL_BUTTON_SIZE)
		button.focus_mode = Control.FOCUS_NONE
		button.icon = _make_icon_texture(TOOL_ICONS[tool_id])

		button.add_theme_stylebox_override("normal", _make_tool_style(TOOL_FACE_COLOR, NORMAL_BORDER_COLOR, 1))
		button.add_theme_stylebox_override("hover", _make_tool_style(TOOL_HOVER_COLOR, NORMAL_BORDER_COLOR, 1))
		button.add_theme_stylebox_override("pressed", _make_tool_style(TOOL_SELECTED_COLOR, SELECTED_BORDER_COLOR, 2))
		button.add_theme_stylebox_override("hover_pressed", _make_tool_style(TOOL_SELECTED_COLOR, SELECTED_BORDER_COLOR, 2))
		button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

		button.toggled.connect(_on_tool_button_toggled.bind(tool_id))
		tool_grid.add_child(button)
		_tool_buttons[tool_id] = button

	_tool_buttons[PixelEditor.Tool.PENCIL].button_pressed = true


func _make_icon_texture(pattern: Array) -> ImageTexture:
	var height: int = pattern.size()
	var width: int = String(pattern[0]).length()
	var image: Image = Image.create(width * TOOL_ICON_SCALE, height * TOOL_ICON_SCALE, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for y in height:
		var row: String = pattern[y]
		for x in row.length():
			if row[x] == ".":
				continue
			for offset_y in TOOL_ICON_SCALE:
				for offset_x in TOOL_ICON_SCALE:
					image.set_pixel(x * TOOL_ICON_SCALE + offset_x, y * TOOL_ICON_SCALE + offset_y, TOOL_INK_COLOR)
	return ImageTexture.create_from_image(image)


func _make_tool_style(face_color: Color, border_color: Color, border_width: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = face_color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_content_margin_all(4)
	return style


func _build_palette() -> void:
	for color in PALETTE_COLORS:
		var button: Button = Button.new()
		button.toggle_mode = true
		button.button_group = _palette_group
		button.custom_minimum_size = Vector2(SWATCH_BUTTON_SIZE, SWATCH_BUTTON_SIZE)
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
	_update_current_color_swatch(color)
	if pixel_editor.current_tool == PixelEditor.Tool.ERASER:
		_select_tool(PixelEditor.Tool.PENCIL)


func _on_tool_button_toggled(toggled_on: bool, tool_id: int) -> void:
	if not toggled_on:
		return
	pixel_editor.set_tool(tool_id)
	_update_tool_label()


func _on_editor_tool_changed(new_tool: int) -> void:
	_select_tool(new_tool)
	_update_tool_label()


func _select_tool(tool_id: int) -> void:
	var button: Button = _tool_buttons.get(tool_id)
	if button == null:
		return
	button.button_pressed = true


func _update_tool_label() -> void:
	var name_key: String = TOOL_NAME_KEYS.get(pixel_editor.current_tool, "creator.tool_pencil")
	tool_label.text = LocalizationManager.text("creator.tool", [LocalizationManager.text(name_key)])


func _update_current_color_swatch(color: Color) -> void:
	current_color_swatch.texture = _make_swatch_texture(color, SELECTED_BORDER_COLOR)


func _on_editor_color_picked(picked_color: Color) -> void:
	_update_current_color_swatch(picked_color)
	for index in PALETTE_COLORS.size():
		if PALETTE_COLORS[index].is_equal_approx(picked_color):
			var button: Button = palette_grid.get_child(index)
			button.button_pressed = true
			break
	_show_feedback("creator.color_picked")


func _on_fill_shapes_button_toggled(toggled_on: bool) -> void:
	pixel_editor.set_fill_shapes(toggled_on)


func _on_brush_slider_value_changed(value: float) -> void:
	var brush_value: int = int(value)
	pixel_editor.set_brush_size(brush_value)
	_update_brush_label(brush_value)


func _update_brush_label(brush_value: int) -> void:
	brush_label.text = LocalizationManager.text("creator.brush", [brush_value])


func _on_clear_button_pressed() -> void:
	pixel_editor.clear_canvas()
	_show_feedback("creator.canvas_cleared")


func _on_undo_button_pressed() -> void:
	pixel_editor.undo()


func _on_redo_button_pressed() -> void:
	pixel_editor.redo()


func _on_drawing_changed() -> void:
	_update_history_buttons()
	_update_code_field()


func _update_code_field() -> void:
	if code_field.has_focus():
		return
	code_field.text = DrawingCode.encode(pixel_editor.get_image_copy())


func _on_copy_code_button_pressed() -> void:
	var code: String = code_field.text.strip_edges()
	if code.is_empty():
		_show_feedback("creator.code_empty")
		return
	code_field.release_focus()
	if not _copy_to_clipboard(code):
		_show_feedback("creator.code_copy_failed")
		return
	_show_feedback("creator.code_copied")


func _on_paste_code_button_pressed() -> void:
	code_field.release_focus()
	var pasted: String = _read_clipboard()
	if pasted.strip_edges().is_empty():
		_show_feedback("creator.code_paste_failed")
		return
	code_field.text = pasted
	_load_code(pasted)


func _copy_to_clipboard(text: String) -> bool:
	if not OS.has_feature("web"):
		DisplayServer.clipboard_set(text)
		return true
	var copied: Variant = JavaScriptBridge.eval(WEB_COPY_SCRIPT % JSON.stringify(text), true)
	if copied == null:
		push_warning("[DrawingCreator] A cópia pelo navegador não respondeu.")
		return false
	return bool(copied)


func _read_clipboard() -> String:
	if not OS.has_feature("web"):
		return DisplayServer.clipboard_get()
	var prompt_text: String = LocalizationManager.text("creator.code_paste_prompt")
	var pasted: Variant = JavaScriptBridge.eval(WEB_PASTE_SCRIPT % JSON.stringify(prompt_text), true)
	if pasted == null:
		return ""
	return String(pasted)


func _on_load_code_button_pressed() -> void:
	_load_code(code_field.text)


func _on_code_field_text_submitted(submitted_text: String) -> void:
	_load_code(submitted_text)


func _load_code(code: String) -> void:
	if code.strip_edges().is_empty():
		_show_feedback("creator.code_empty")
		return
	var image: Image = DrawingCode.decode(code)
	if image == null:
		_show_feedback("creator.code_invalid")
		return
	pixel_editor.load_from_image(image)
	code_field.release_focus()
	_update_code_field()
	_show_feedback("creator.code_loaded")


func _update_history_buttons() -> void:
	undo_button.disabled = not pixel_editor.can_undo()
	redo_button.disabled = not pixel_editor.can_redo()


func _show_feedback(key: String, values: Array = []) -> void:
	_feedback_key = key
	_feedback_values = values
	feedback_label.text = LocalizationManager.text(key, values)
