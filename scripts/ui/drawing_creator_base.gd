class_name DrawingCreatorBase
extends Control

const COLOR_DIALOG_SCENE: String = "res://scenes/ui/color_dialog.tscn"

const CUSTOM_COLOR_SLOTS: int = 10

const PALETTE_COLORS: Array[Color] = [
	Color("000000"), Color("333333"), Color("555555"), Color("777777"), Color("aaaaaa"),
	Color("cccccc"), Color("ffffff"), Color("5c3a2a"), Color("8a5a3c"), Color("c98a5a"),
	Color("e8c9a0"), Color("7a2020"), Color("d94f4f"), Color("f2757a"), Color("f28dbb"),
	Color("c95fd9"), Color("f2913d"), Color("f2d541"), Color("fff7a8"), Color("b8e07a"),
	Color("3f6b2e"), Color("7abf5a"), Color("1f5f4a"), Color("2e8a5c"), Color("4fc3d9"),
	Color("2e7fb8"), Color("3f6fd9"), Color("6a4fd9"), Color("9b7ff0"), Color("2b2b45"),
]

const WEB_CLIPBOARD_SCRIPT: String = "(function(){if(window.blankCanvasClipboard){return true;}var state={text:'',armed:false,copied:false};window.blankCanvasClipboard=state;var copy=function(){if(!state.armed){return;}state.armed=false;var area=document.createElement('textarea');area.value=state.text;area.style.position='fixed';area.style.left='-9999px';document.body.appendChild(area);var previous=document.activeElement;area.focus();area.select();area.setSelectionRange(0,state.text.length);try{state.copied=document.execCommand('copy');}catch(error){state.copied=false;}document.body.removeChild(area);if(previous&&previous.focus){previous.focus();}};document.addEventListener('mouseup',copy,true);document.addEventListener('touchend',copy,true);return true;})()"

const WEB_ARM_COPY_SCRIPT: String = "(function(text){var state=window.blankCanvasClipboard;if(!state){return false;}state.text=text;state.armed=true;state.copied=false;return true;})(%s)"

const WEB_COPIED_SCRIPT: String = "(function(){var state=window.blankCanvasClipboard;if(!state){return false;}var copied=state.copied;state.copied=false;return copied;})()"

const WEB_SHOW_CODE_SCRIPT: String = "(function(label,text){window.prompt(label,text);var canvas=document.getElementsByTagName('canvas')[0];if(canvas){canvas.focus();}return true;})(%s,%s)"

const WEB_PASTE_SCRIPT: String = "(function(){var text=window.prompt(%s,'');var canvas=document.getElementsByTagName('canvas')[0];if(canvas){canvas.focus();}return text===null?'':text;})()"

const SELECTED_BORDER_COLOR: Color = Color(0.12, 0.12, 0.12)
const NORMAL_BORDER_COLOR: Color = Color(0, 0, 0, 0.25)
const EMPTY_SLOT_COLOR: Color = Color(0.90, 0.90, 0.87)
const EMPTY_SLOT_BORDER_COLOR: Color = Color(0, 0, 0, 0.12)

const SWATCH_TILE_SIZE: int = 16
const SWATCH_BORDER: int = 2
const SWATCH_BUTTON_SIZE: int = 20
const SWATCH_CORNER_CUTS: Array[Vector2i] = [
	Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0),
	Vector2i(0, 1), Vector2i(1, 1),
	Vector2i(0, 2),
]

const TOOL_BUTTON_SIZE: int = 34
const TOOL_ICON_SCALE: int = 2
const TOOL_INK_COLOR: Color = Color(0.12, 0.12, 0.12)
const TOOL_PAPER_COLOR: Color = Color(0.99, 0.99, 0.97)
const TOOL_FACE_COLOR: Color = Color(0.96, 0.96, 0.93)
const TOOL_HOVER_COLOR: Color = Color(1, 1, 1)
const TOOL_SELECTED_COLOR: Color = Color(0.12, 0.12, 0.12)

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

const TOOL_HINT_KEYS: Dictionary = {
	PixelEditor.Tool.PICKER: "creator.tool_picker_hint",
}

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
		"........####",
		".......#####",
		"......#####.",
		".....#####..",
		"....#####...",
		"...#####....",
		"..#####.....",
		".#####......",
		"#####.......",
		".###........",
		"..#.........",
		"............",
	],
	PixelEditor.Tool.ERASER: [
		"............",
		"....######..",
		"...########.",
		"..##########",
		"..##########",
		"..#........#",
		"..##########",
		"..#########.",
		"...#######..",
		"............",
		".##.###.###.",
		"............",
	],
	PixelEditor.Tool.BUCKET: [
		"...##..##...",
		"..##....##..",
		"############",
		"############",
		"##........##",
		"##........##",
		".##......##.",
		".##......##.",
		"..########..",
		"..######....",
		"..........#.",
		".........###",
	],
	PixelEditor.Tool.PICKER: [
		".......####.",
		"......######",
		"......######",
		"......######",
		".....####...",
		".....##.....",
		"....##......",
		"...##.......",
		"..##........",
		".##.........",
		"##..........",
		"#...........",
	],
	PixelEditor.Tool.LINE: [
		".........###",
		".........###",
		"........##..",
		".......##...",
		"......##....",
		".....##.....",
		"....##......",
		"...##.......",
		"..##........",
		"###.........",
		"###.........",
		"............",
	],
	PixelEditor.Tool.RECTANGLE: [
		"............",
		".##########.",
		".##########.",
		".##......##.",
		".##......##.",
		".##......##.",
		".##......##.",
		".##......##.",
		".##########.",
		".##########.",
		"............",
		"............",
	],
	PixelEditor.Tool.ELLIPSE: [
		"............",
		"...######...",
		"..########..",
		".###....###.",
		".##......##.",
		"##........##",
		"##........##",
		".##......##.",
		".###....###.",
		"..########..",
		"...######...",
		"............",
	],
	PixelEditor.Tool.SPRAY: [
		"..##........",
		"..##..#.....",
		".####.......",
		".#####...#..",
		".#####.#....",
		".#####......",
		".#####..#..#",
		".#####.#....",
		".#####...#..",
		".#####......",
		".#####.#....",
		"..###.......",
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
@onready var custom_color_button: Button = $CenterContainer/MainContainer/EditorRow/SidePanel/PaletteHeader/CustomColorButton
@onready var brush_label: Label = $CenterContainer/MainContainer/EditorRow/SidePanel/BrushRow/BrushLabel
@onready var brush_slider: HSlider = $CenterContainer/MainContainer/EditorRow/SidePanel/BrushRow/BrushSlider
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
var _color_dialog: ColorDialog = null
var _feedback_key: String = ""
var _feedback_values: Array = []


func _ready() -> void:
	_build_tools()
	_build_palette()
	_build_color_dialog()

	brush_slider.value_changed.connect(_on_brush_slider_value_changed)
	custom_color_button.pressed.connect(_on_custom_color_button_pressed)
	fill_shapes_button.toggled.connect(_on_fill_shapes_button_toggled)
	clear_button.pressed.connect(_on_clear_button_pressed)
	undo_button.pressed.connect(_on_undo_button_pressed)
	redo_button.pressed.connect(_on_redo_button_pressed)
	confirm_button.pressed.connect(_on_confirm_button_pressed)
	back_button.pressed.connect(_on_back_button_pressed)
	copy_code_button.button_down.connect(_on_copy_code_button_down)
	copy_code_button.pressed.connect(_on_copy_code_button_pressed)
	paste_code_button.pressed.connect(_on_paste_code_button_pressed)
	load_code_button.pressed.connect(_on_load_code_button_pressed)
	code_field.text_submitted.connect(_on_code_field_text_submitted)
	pixel_editor.drawing_changed.connect(_on_drawing_changed)
	pixel_editor.color_picked.connect(_on_editor_color_picked)
	pixel_editor.tool_changed.connect(_on_editor_tool_changed)
	LocalizationManager.language_changed.connect(_apply_translations)

	if OS.has_feature("web"):
		_setup_web_clipboard()

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
	custom_color_button.tooltip_text = LocalizationManager.text("creator.custom_color")
	_refresh_custom_slots()
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
		var hint_key: String = TOOL_HINT_KEYS.get(tool_id, TOOL_NAME_KEYS[tool_id])
		button.tooltip_text = LocalizationManager.text(hint_key)
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

		button.add_theme_stylebox_override("normal", _make_tool_style(TOOL_FACE_COLOR, SELECTED_BORDER_COLOR, 2))
		button.add_theme_stylebox_override("hover", _make_tool_style(TOOL_HOVER_COLOR, SELECTED_BORDER_COLOR, 2))
		button.add_theme_stylebox_override("pressed", _make_tool_style(TOOL_SELECTED_COLOR, SELECTED_BORDER_COLOR, 2))
		button.add_theme_stylebox_override("hover_pressed", _make_tool_style(TOOL_SELECTED_COLOR, SELECTED_BORDER_COLOR, 2))
		button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

		button.add_theme_color_override("icon_normal_color", TOOL_INK_COLOR)
		button.add_theme_color_override("icon_hover_color", TOOL_INK_COLOR)
		button.add_theme_color_override("icon_focus_color", TOOL_INK_COLOR)
		button.add_theme_color_override("icon_pressed_color", TOOL_PAPER_COLOR)
		button.add_theme_color_override("icon_hover_pressed_color", TOOL_PAPER_COLOR)

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
					image.set_pixel(x * TOOL_ICON_SCALE + offset_x, y * TOOL_ICON_SCALE + offset_y, Color.WHITE)
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
		var button: Button = _make_swatch_button()
		_apply_swatch_look(button, color, NORMAL_BORDER_COLOR)
		button.toggled.connect(_on_palette_button_toggled.bind(color))
		palette_grid.add_child(button)

	for slot in CUSTOM_COLOR_SLOTS:
		var slot_button: Button = _make_swatch_button()
		slot_button.toggled.connect(_on_custom_slot_toggled.bind(slot))
		palette_grid.add_child(slot_button)

	_refresh_custom_slots()
	_build_custom_color_button()

	var first_button: Button = palette_grid.get_child(0)
	first_button.button_pressed = true


func _make_swatch_button() -> Button:
	var button: Button = Button.new()
	button.toggle_mode = true
	button.button_group = _palette_group
	button.custom_minimum_size = Vector2(SWATCH_BUTTON_SIZE, SWATCH_BUTTON_SIZE)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return button


func _apply_swatch_look(button: Button, color: Color, border_color: Color) -> void:
	var normal_style: StyleBoxTexture = _make_swatch_style(color, border_color)
	var selected_style: StyleBoxTexture = _make_swatch_style(color, SELECTED_BORDER_COLOR)
	button.add_theme_stylebox_override("normal", normal_style)
	button.add_theme_stylebox_override("hover", normal_style)
	button.add_theme_stylebox_override("disabled", normal_style)
	button.add_theme_stylebox_override("pressed", selected_style)
	button.add_theme_stylebox_override("hover_pressed", selected_style)


func _custom_slot_button(slot: int) -> Button:
	return palette_grid.get_child(PALETTE_COLORS.size() + slot) as Button


func _refresh_custom_slots() -> void:
	if palette_grid.get_child_count() < PALETTE_COLORS.size() + CUSTOM_COLOR_SLOTS:
		return
	var colors: PackedColorArray = GameManager.custom_colors
	for slot in CUSTOM_COLOR_SLOTS:
		var button: Button = _custom_slot_button(slot)
		if slot < colors.size():
			button.disabled = false
			button.tooltip_text = "#%s" % colors[slot].to_html(false).to_upper()
			_apply_swatch_look(button, colors[slot], NORMAL_BORDER_COLOR)
		else:
			button.disabled = true
			button.tooltip_text = LocalizationManager.text("creator.custom_empty")
			_apply_swatch_look(button, EMPTY_SLOT_COLOR, EMPTY_SLOT_BORDER_COLOR)


func _build_custom_color_button() -> void:
	custom_color_button.custom_minimum_size = Vector2(SWATCH_BUTTON_SIZE, SWATCH_BUTTON_SIZE)
	custom_color_button.focus_mode = Control.FOCUS_NONE
	var normal_style: StyleBoxTexture = _make_spectrum_style(NORMAL_BORDER_COLOR)
	var hover_style: StyleBoxTexture = _make_spectrum_style(SELECTED_BORDER_COLOR)
	custom_color_button.add_theme_stylebox_override("normal", normal_style)
	custom_color_button.add_theme_stylebox_override("hover", hover_style)
	custom_color_button.add_theme_stylebox_override("pressed", hover_style)
	custom_color_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _build_color_dialog() -> void:
	var scene: PackedScene = load(COLOR_DIALOG_SCENE)
	if scene == null:
		push_warning("[DrawingCreator] Não foi possível carregar %s." % COLOR_DIALOG_SCENE)
		custom_color_button.disabled = true
		return
	_color_dialog = scene.instantiate()
	add_child(_color_dialog)
	_color_dialog.color_confirmed.connect(_on_color_dialog_confirmed)


func _make_swatch_texture(fill_color: Color, border_color: Color) -> ImageTexture:
	var image: Image = Image.create(SWATCH_TILE_SIZE, SWATCH_TILE_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(border_color)
	for y in range(SWATCH_BORDER, SWATCH_TILE_SIZE - SWATCH_BORDER):
		for x in range(SWATCH_BORDER, SWATCH_TILE_SIZE - SWATCH_BORDER):
			image.set_pixel(x, y, fill_color)
	_cut_swatch_corners(image)
	return ImageTexture.create_from_image(image)


func _make_spectrum_texture(border_color: Color) -> ImageTexture:
	var image: Image = Image.create(SWATCH_TILE_SIZE, SWATCH_TILE_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(border_color)
	var span: int = SWATCH_TILE_SIZE - SWATCH_BORDER * 2
	for y in range(SWATCH_BORDER, SWATCH_TILE_SIZE - SWATCH_BORDER):
		var value: float = 1.0 - float(y - SWATCH_BORDER) / float(span) * 0.55
		for x in range(SWATCH_BORDER, SWATCH_TILE_SIZE - SWATCH_BORDER):
			var hue: float = float(x - SWATCH_BORDER) / float(span)
			image.set_pixel(x, y, Color.from_hsv(hue, 0.85, value))
	_cut_swatch_corners(image)
	return ImageTexture.create_from_image(image)


func _cut_swatch_corners(image: Image) -> void:
	var tile_size: int = SWATCH_TILE_SIZE
	for cut in SWATCH_CORNER_CUTS:
		var dx: int = cut.x
		var dy: int = cut.y
		image.set_pixel(dx, dy, Color(0, 0, 0, 0))
		image.set_pixel(tile_size - 1 - dx, dy, Color(0, 0, 0, 0))
		image.set_pixel(dx, tile_size - 1 - dy, Color(0, 0, 0, 0))
		image.set_pixel(tile_size - 1 - dx, tile_size - 1 - dy, Color(0, 0, 0, 0))


func _make_swatch_style(fill_color: Color, border_color: Color) -> StyleBoxTexture:
	return _make_tile_style(_make_swatch_texture(fill_color, border_color))


func _make_spectrum_style(border_color: Color) -> StyleBoxTexture:
	return _make_tile_style(_make_spectrum_texture(border_color))


func _make_tile_style(texture: ImageTexture) -> StyleBoxTexture:
	var style: StyleBoxTexture = StyleBoxTexture.new()
	style.texture = texture
	style.texture_margin_left = 4
	style.texture_margin_top = 4
	style.texture_margin_right = 4
	style.texture_margin_bottom = 4
	return style


func _on_palette_button_toggled(toggled_on: bool, color: Color) -> void:
	if not toggled_on:
		return
	_use_color(color)


func _on_custom_slot_toggled(toggled_on: bool, slot: int) -> void:
	if not toggled_on:
		return
	var colors: PackedColorArray = GameManager.custom_colors
	if slot >= colors.size():
		return
	_use_color(colors[slot])


func _use_color(color: Color) -> void:
	pixel_editor.set_current_color(color)
	_update_current_color_swatch(color)
	if pixel_editor.current_tool == PixelEditor.Tool.ERASER:
		_select_tool(PixelEditor.Tool.PENCIL)


func open_color_dialog() -> bool:
	if _color_dialog == null:
		push_warning("[DrawingCreator] O seletor de cor não está disponível.")
		return false
	_color_dialog.open(pixel_editor.current_color)
	return true


func _on_custom_color_button_pressed() -> void:
	open_color_dialog()


func _on_color_dialog_confirmed(color: Color) -> void:
	var slot: int = GameManager.add_custom_color(color)
	_refresh_custom_slots()
	_custom_slot_button(slot).button_pressed = true
	_use_color(color)
	_show_feedback("creator.custom_color_added")


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
	_select_swatch(picked_color)
	_show_feedback("creator.color_picked")


func _select_swatch(color: Color) -> void:
	for index in PALETTE_COLORS.size():
		if PALETTE_COLORS[index].is_equal_approx(color):
			var button: Button = palette_grid.get_child(index)
			button.button_pressed = true
			return
	var colors: PackedColorArray = GameManager.custom_colors
	for slot in colors.size():
		if colors[slot].is_equal_approx(color):
			_custom_slot_button(slot).button_pressed = true
			return


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


func _setup_web_clipboard() -> void:
	if JavaScriptBridge.eval(WEB_CLIPBOARD_SCRIPT, true) == null:
		push_warning("[DrawingCreator] O navegador não aceitou o apoio de cópia; o código vai abrir numa caixa.")


func _on_copy_code_button_down() -> void:
	if not OS.has_feature("web"):
		return
	var code: String = code_field.text.strip_edges()
	if code.is_empty():
		return
	JavaScriptBridge.eval(WEB_ARM_COPY_SCRIPT % JSON.stringify(code), true)


func _on_copy_code_button_pressed() -> void:
	var code: String = code_field.text.strip_edges()
	if code.is_empty():
		_show_feedback("creator.code_empty")
		return
	code_field.release_focus()
	if _copy_to_clipboard(code):
		_show_feedback("creator.code_copied")
		return
	if _show_code_for_manual_copy(code):
		_show_feedback("creator.code_copy_manual")
		return
	_show_feedback("creator.code_copy_failed")


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
	var copied: Variant = JavaScriptBridge.eval(WEB_COPIED_SCRIPT, true)
	return copied != null and bool(copied)


func _show_code_for_manual_copy(text: String) -> bool:
	if not OS.has_feature("web"):
		return false
	var label: String = LocalizationManager.text("creator.code_copy_prompt")
	var shown: Variant = JavaScriptBridge.eval(WEB_SHOW_CODE_SCRIPT % [JSON.stringify(label), JSON.stringify(text)], true)
	return shown != null


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
