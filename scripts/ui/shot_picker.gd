class_name ShotPicker
extends Control

signal chosen(shot_type: int)
signal dismissed

const SHOT_ORDER: Array[int] = [
	AbilityData.ShotType.STANDARD,
	AbilityData.ShotType.CHARGE,
	AbilityData.ShotType.RAPID,
]

const SHOT_NAME_KEYS: Dictionary = {
	AbilityData.ShotType.STANDARD: "shot.standard",
	AbilityData.ShotType.CHARGE: "shot.charge",
	AbilityData.ShotType.RAPID: "shot.rapid",
}

const SHOT_INFO_KEYS: Dictionary = {
	AbilityData.ShotType.STANDARD: "shot.standard_info",
	AbilityData.ShotType.CHARGE: "shot.charge_info",
	AbilityData.ShotType.RAPID: "shot.rapid_info",
}

const SHOT_STATS: Dictionary = {
	AbilityData.ShotType.STANDARD: [3, 3, 3],
	AbilityData.ShotType.CHARGE: [5, 1, 2],
	AbilityData.ShotType.RAPID: [1, 5, 5],
}

const STAT_KEYS: Array[String] = ["shot.damage", "shot.range", "shot.rate"]
const STAT_MAX: int = 5

const SHOT_ICONS: Dictionary = {
	AbilityData.ShotType.STANDARD: [
		"............",
		"........###.",
		"........#.#.",
		"........###.",
		".......#....",
		"......#.....",
		".....#......",
		"....##......",
		"...##.......",
		".###........",
		"###.........",
		"##..........",
	],
	AbilityData.ShotType.CHARGE: [
		"............",
		"............",
		"............",
		"............",
		"........###.",
		"....#..#####",
		"##.###.#####",
		"....#..#####",
		"........###.",
		"............",
		"............",
		"............",
	],
	AbilityData.ShotType.RAPID: [
		"............",
		"............",
		"#####..###..",
		"............",
		"............",
		".#####..###.",
		"............",
		"............",
		"..#####..###",
		"............",
		"............",
		"............",
	],
}

const ICON_SCALE: int = 3
const BAR_CELL: int = 6
const CARD_SIZE: Vector2 = Vector2(176, 156)
const INK_COLOR: Color = Color(0.12, 0.12, 0.12, 1.0)
const SOFT_INK_COLOR: Color = Color(0.35, 0.35, 0.35, 1.0)
const FACE_COLOR: Color = Color(0.96, 0.96, 0.93, 1.0)
const HOVER_COLOR: Color = Color(0.9, 0.9, 0.86, 1.0)
const SELECTED_COLOR: Color = Color(1.0, 0.9, 0.62, 1.0)
const BAR_EMPTY_COLOR: Color = Color(0.8, 0.8, 0.76, 1.0)
const DIM_COLOR: Color = Color(0.1, 0.1, 0.1, 0.55)
const HINT_COLOR: Color = Color(0.72, 0.3, 0.15, 1.0)
const DISABLED_COLOR: Color = Color(0.84, 0.84, 0.8, 1.0)
const DISABLED_MODULATE: Color = Color(1.0, 1.0, 1.0, 0.45)

var confirm_button: Button = null
var back_button: Button = null

var _group: ButtonGroup = ButtonGroup.new()
var _cards: Dictionary = {}
var _name_labels: Dictionary = {}
var _info_labels: Dictionary = {}
var _stat_labels: Array[Label] = []
var _title_label: Label = null
var _hint_label: Label = null
var _selected: int = -1
var _locked: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()
	LocalizationManager.language_changed.connect(_apply_translations)
	_apply_translations()


func open(preselected: int, locked: bool = false) -> void:
	_selected = preselected if SHOT_ORDER.has(preselected) else -1
	_locked = locked and _selected >= 0
	for shot_type in SHOT_ORDER:
		var card: Button = _cards[shot_type]
		card.disabled = _locked and shot_type != _selected
		card.modulate = DISABLED_MODULATE if card.disabled else Color.WHITE
		card.set_pressed_no_signal(shot_type == _selected)
	_update_confirm()
	visible = true


func close() -> void:
	visible = false


func select(shot_type: int) -> void:
	if not SHOT_ORDER.has(shot_type):
		push_warning("[ShotPicker] Tipo de tiro desconhecido: %d." % shot_type)
		return
	if _cards[shot_type].disabled:
		return
	_cards[shot_type].button_pressed = true


func is_locked() -> bool:
	return _locked


func is_card_disabled(shot_type: int) -> bool:
	return _cards.has(shot_type) and _cards[shot_type].disabled


func selected_shot_type() -> int:
	return _selected


func _build() -> void:
	var dim: ColorRect = ColorRect.new()
	dim.color = DIM_COLOR
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center: CenterContainer = CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel: PanelContainer = PanelContainer.new()
	center.add_child(panel)

	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	panel.add_child(content)

	_title_label = _make_label(14, INK_COLOR)
	content.add_child(_title_label)

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	content.add_child(row)
	for shot_type in SHOT_ORDER:
		row.add_child(_build_card(shot_type))

	_hint_label = _make_label(8, HINT_COLOR)
	content.add_child(_hint_label)

	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	content.add_child(buttons)

	back_button = Button.new()
	back_button.custom_minimum_size = Vector2(0, 26)
	back_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back_button.add_theme_font_size_override("font_size", 10)
	back_button.pressed.connect(_on_back_pressed)
	buttons.add_child(back_button)

	confirm_button = Button.new()
	confirm_button.custom_minimum_size = Vector2(0, 26)
	confirm_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm_button.add_theme_font_size_override("font_size", 12)
	confirm_button.pressed.connect(_on_confirm_pressed)
	buttons.add_child(confirm_button)


func _build_card(shot_type: int) -> Button:
	var card: Button = Button.new()
	card.toggle_mode = true
	card.button_group = _group
	card.focus_mode = Control.FOCUS_NONE
	card.custom_minimum_size = CARD_SIZE
	card.add_theme_stylebox_override("normal", _card_style(FACE_COLOR, 2))
	card.add_theme_stylebox_override("hover", _card_style(HOVER_COLOR, 2))
	card.add_theme_stylebox_override("pressed", _card_style(SELECTED_COLOR, 4))
	card.add_theme_stylebox_override("hover_pressed", _card_style(SELECTED_COLOR, 4))
	card.add_theme_stylebox_override("disabled", _card_style(DISABLED_COLOR, 2))
	card.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	card.toggled.connect(_on_card_toggled.bind(shot_type))
	_cards[shot_type] = card

	var box: VBoxContainer = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 4)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
	card.add_child(box)

	var icon: TextureRect = TextureRect.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture = _make_icon(SHOT_ICONS[shot_type])
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	box.add_child(icon)

	var name_label: Label = _make_label(10, INK_COLOR)
	box.add_child(name_label)
	_name_labels[shot_type] = name_label

	var info_label: Label = _make_label(8, SOFT_INK_COLOR)
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_label.custom_minimum_size = Vector2(CARD_SIZE.x - 16, 0)
	box.add_child(info_label)
	_info_labels[shot_type] = info_label

	var stats: Array = SHOT_STATS[shot_type]
	for index in stats.size():
		var stat_row: HBoxContainer = HBoxContainer.new()
		stat_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stat_row.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_child(stat_row)
		var stat_label: Label = _make_label(8, SOFT_INK_COLOR)
		stat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		stat_label.custom_minimum_size = Vector2(64, 0)
		stat_label.set_meta("stat_key", STAT_KEYS[index])
		stat_row.add_child(stat_label)
		_stat_labels.append(stat_label)
		var bar: TextureRect = TextureRect.new()
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.texture = _make_bar(stats[index])
		bar.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		stat_row.add_child(bar)

	return card


func _make_label(font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _card_style(face_color: Color, border_width: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = face_color
	style.border_color = INK_COLOR
	style.set_border_width_all(border_width)
	return style


func _make_icon(pattern: Array) -> ImageTexture:
	var height: int = pattern.size()
	var width: int = String(pattern[0]).length()
	var image: Image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for y in height:
		var row: String = pattern[y]
		for x in mini(width, row.length()):
			if row[x] == "#":
				image.set_pixel(x, y, INK_COLOR)
	image.resize(width * ICON_SCALE, height * ICON_SCALE, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(image)


func _make_bar(value: int) -> ImageTexture:
	var width: int = STAT_MAX * (BAR_CELL + 1) - 1
	var image: Image = Image.create(width, BAR_CELL, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for index in STAT_MAX:
		var color: Color = INK_COLOR if index < value else BAR_EMPTY_COLOR
		image.fill_rect(Rect2i(index * (BAR_CELL + 1), 0, BAR_CELL, BAR_CELL), color)
	return ImageTexture.create_from_image(image)


func _on_card_toggled(pressed: bool, shot_type: int) -> void:
	if not pressed:
		return
	_selected = shot_type
	_update_confirm()


func _update_confirm() -> void:
	confirm_button.disabled = _selected < 0
	if _locked:
		_hint_label.text = LocalizationManager.text("shot.locked")
	elif _selected >= 0:
		_hint_label.text = ""
	else:
		_hint_label.text = LocalizationManager.text("shot.pick_one")


func _on_confirm_pressed() -> void:
	if _selected < 0:
		return
	chosen.emit(_selected)


func _on_back_pressed() -> void:
	close()
	dismissed.emit()


func _apply_translations() -> void:
	_title_label.text = LocalizationManager.text("shot.title")
	for shot_type in SHOT_ORDER:
		_name_labels[shot_type].text = LocalizationManager.text(SHOT_NAME_KEYS[shot_type])
		_info_labels[shot_type].text = LocalizationManager.text(SHOT_INFO_KEYS[shot_type])
	for label in _stat_labels:
		label.text = LocalizationManager.text(label.get_meta("stat_key"))
	back_button.text = LocalizationManager.text("shot.back")
	confirm_button.text = LocalizationManager.text("shot.confirm")
	_update_confirm()
