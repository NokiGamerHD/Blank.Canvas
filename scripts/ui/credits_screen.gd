class_name CreditsScreen
extends CanvasLayer

signal closed

const LAYER: int = 31
const PANEL_WIDTH: int = 460
const DIM_COLOR: Color = Color(0.05, 0.05, 0.07, 0.55)
const TITLE_FONT_SIZE: int = 14
const SECTION_FONT_SIZE: int = 9
const LINE_FONT_SIZE: int = 8
const SECTION_COLOR: Color = Color(0.12, 0.12, 0.12, 1.0)
const LINE_COLOR: Color = Color(0.32, 0.32, 0.32, 1.0)
const ROW_SPACING: int = 3
const SECTION_SPACING: int = 9
const BUTTON_SIZE: Vector2 = Vector2(200, 26)
const MUSIC_KEY: String = "credits.music_line"

const ENTRIES: Array[Dictionary] = [
	{"section": "credits.game", "lines": ["credits.game_line"]},
	{"section": "credits.font", "lines": ["credits.font_line"]},
	{"section": "credits.sprites", "lines": ["credits.sprites_line"]},
	{"section": "credits.audio", "lines": ["credits.audio_line", "credits.music_line"]},
	{"section": "credits.thanks", "lines": ["credits.thanks_line"]},
]

var _panel: PanelContainer = null
var _rows: VBoxContainer = null
var _title: Label = null
var _back_button: Button = null
var _labels: Array[Label] = []


func _ready() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	var dim: ColorRect = ColorRect.new()
	dim.color = DIM_COLOR
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	center.add_child(_panel)

	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", SECTION_SPACING)
	_panel.add_child(content)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	_title.add_theme_color_override("font_color", SECTION_COLOR)
	content.add_child(_title)

	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", SECTION_SPACING)
	content.add_child(_rows)
	_build_rows()

	_back_button = Button.new()
	_back_button.custom_minimum_size = BUTTON_SIZE
	_back_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_back_button.add_theme_font_size_override("font_size", SECTION_FONT_SIZE)
	_back_button.pressed.connect(close)
	content.add_child(_back_button)

	LocalizationManager.language_changed.connect(_apply_translations)
	_apply_translations()


func open() -> void:
	visible = true
	_back_button.grab_focus()


func close() -> void:
	visible = false
	closed.emit()


func is_open() -> bool:
	return visible


func line_texts() -> PackedStringArray:
	var texts: PackedStringArray = PackedStringArray()
	for label in _labels:
		texts.append(label.text)
	return texts


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	close()


func _build_rows() -> void:
	for entry in ENTRIES:
		var block: VBoxContainer = VBoxContainer.new()
		block.add_theme_constant_override("separation", ROW_SPACING)
		_rows.add_child(block)
		block.add_child(_make_label(entry["section"], SECTION_FONT_SIZE, SECTION_COLOR))
		for key in entry["lines"]:
			block.add_child(_make_label(key, LINE_FONT_SIZE, LINE_COLOR))


func _make_label(key: String, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.set_meta("key", key)
	if key == MUSIC_KEY:
		label.set_meta("needs_music", true)
	_labels.append(label)
	return label


func _apply_translations() -> void:
	_title.text = LocalizationManager.text("credits.title")
	_back_button.text = LocalizationManager.text("progression.back")
	var has_music: bool = not MusicManager.track_names().is_empty()
	for label in _labels:
		label.text = LocalizationManager.text(str(label.get_meta("key")))
		if label.has_meta("needs_music"):
			label.visible = has_music
