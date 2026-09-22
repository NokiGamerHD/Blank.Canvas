class_name SettingsScreen
extends CanvasLayer

signal closed

const LAYER: int = 30
const PANEL_WIDTH: int = 420
const TITLE_FONT_SIZE: int = 14
const ROW_FONT_SIZE: int = 10
const LABEL_FONT_SIZE: int = 9
const ROW_HEIGHT: int = 22
const LABEL_WIDTH: int = 180
const VALUE_WIDTH: int = 150
const DIM_COLOR: Color = Color(0.1, 0.1, 0.1, 0.55)
const TEXT_COLOR: Color = Color(0.15, 0.15, 0.15, 1.0)

const ACTION_KEYS: Dictionary = {
	"move_up": "settings.action_move_up",
	"move_down": "settings.action_move_down",
	"move_left": "settings.action_move_left",
	"move_right": "settings.action_move_right",
	"fire": "settings.action_fire",
	"dash": "settings.action_dash",
}

var _general_page: VBoxContainer = null
var _controls_page: VBoxContainer = null
var _general_tab: Button = null
var _controls_tab: Button = null
var _title: Label = null
var _volume_label: Label = null
var _volume_slider: HSlider = null
var _mute_button: Button = null
var _fullscreen_button: Button = null
var _shake_button: Button = null
var _numbers_button: Button = null
var _english_button: Button = null
var _portuguese_button: Button = null
var _reset_button: Button = null
var _back_button: Button = null
var _action_buttons: Dictionary = {}
var _awaiting_action: String = ""


func _ready() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build()
	LocalizationManager.language_changed.connect(_apply_translations)
	AudioManager.audio_settings_changed.connect(_apply_values)
	GameManager.settings_changed.connect(_apply_values)
	_apply_translations()


func open() -> void:
	visible = true
	_awaiting_action = ""
	_show_page(true)
	_apply_translations()


func close() -> void:
	visible = false
	_awaiting_action = ""
	closed.emit()


func is_open() -> bool:
	return visible


func is_waiting_for_key() -> bool:
	return not _awaiting_action.is_empty()


func action_button(action: String) -> Button:
	return _action_buttons.get(action, null)


func back_button() -> Button:
	return _back_button


func _build() -> void:
	var dim: ColorRect = ColorRect.new()
	dim.color = DIM_COLOR
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	center.add_child(panel)

	var margin: MarginContainer = MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 12)
	panel.add_child(margin)

	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	margin.add_child(content)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	_title.add_theme_color_override("font_color", TEXT_COLOR)
	content.add_child(_title)

	var tabs: HBoxContainer = HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	content.add_child(tabs)
	_general_tab = _make_button(ROW_FONT_SIZE)
	_general_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_general_tab.pressed.connect(_show_page.bind(true))
	tabs.add_child(_general_tab)
	_controls_tab = _make_button(ROW_FONT_SIZE)
	_controls_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_controls_tab.pressed.connect(_show_page.bind(false))
	tabs.add_child(_controls_tab)

	_general_page = VBoxContainer.new()
	_general_page.add_theme_constant_override("separation", 5)
	content.add_child(_general_page)
	_build_general_page()

	_controls_page = VBoxContainer.new()
	_controls_page.add_theme_constant_override("separation", 5)
	content.add_child(_controls_page)
	_build_controls_page()

	_back_button = _make_button(ROW_FONT_SIZE)
	_back_button.pressed.connect(close)
	content.add_child(_back_button)


func _build_general_page() -> void:
	var volume_row: HBoxContainer = _make_row(_general_page)
	_volume_label = _make_label()
	volume_row.add_child(_volume_label)
	_volume_slider = HSlider.new()
	_volume_slider.min_value = 0.0
	_volume_slider.max_value = 1.0
	_volume_slider.step = 0.05
	_volume_slider.custom_minimum_size = Vector2(VALUE_WIDTH, ROW_HEIGHT)
	_volume_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_volume_slider.value_changed.connect(_on_volume_changed)
	_volume_slider.drag_ended.connect(_on_volume_drag_ended)
	volume_row.add_child(_volume_slider)

	_mute_button = _make_button(ROW_FONT_SIZE)
	_mute_button.pressed.connect(_on_mute_pressed)
	_general_page.add_child(_mute_button)

	_fullscreen_button = _make_button(ROW_FONT_SIZE)
	_fullscreen_button.pressed.connect(_on_fullscreen_pressed)
	_general_page.add_child(_fullscreen_button)

	_shake_button = _make_button(ROW_FONT_SIZE)
	_shake_button.pressed.connect(_on_shake_pressed)
	_general_page.add_child(_shake_button)

	_numbers_button = _make_button(ROW_FONT_SIZE)
	_numbers_button.pressed.connect(_on_numbers_pressed)
	_general_page.add_child(_numbers_button)

	var language_row: HBoxContainer = _make_row(_general_page)
	_english_button = _make_button(ROW_FONT_SIZE)
	_english_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_english_button.pressed.connect(_on_language_pressed.bind("en"))
	language_row.add_child(_english_button)
	_portuguese_button = _make_button(ROW_FONT_SIZE)
	_portuguese_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_portuguese_button.pressed.connect(_on_language_pressed.bind("pt_BR"))
	language_row.add_child(_portuguese_button)


func _build_controls_page() -> void:
	for action in ACTION_KEYS:
		var row: HBoxContainer = _make_row(_controls_page)
		var label: Label = _make_label()
		label.set_meta("action", action)
		row.add_child(label)
		var button: Button = _make_button(ROW_FONT_SIZE)
		button.custom_minimum_size = Vector2(VALUE_WIDTH, ROW_HEIGHT)
		button.pressed.connect(_on_rebind_pressed.bind(action))
		row.add_child(button)
		_action_buttons[action] = button

	_reset_button = _make_button(ROW_FONT_SIZE)
	_reset_button.pressed.connect(_on_reset_pressed)
	_controls_page.add_child(_reset_button)


func _make_row(parent: VBoxContainer) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	return row


func _make_label() -> Label:
	var label: Label = Label.new()
	label.custom_minimum_size = Vector2(LABEL_WIDTH, ROW_HEIGHT)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", LABEL_FONT_SIZE)
	label.add_theme_color_override("font_color", TEXT_COLOR)
	return label


func _make_button(font_size: int) -> Button:
	var button: Button = Button.new()
	button.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	button.add_theme_font_size_override("font_size", font_size)
	button.focus_mode = Control.FOCUS_NONE
	return button


func _show_page(general: bool) -> void:
	_general_page.visible = general
	_controls_page.visible = not general
	_general_tab.disabled = general
	_controls_tab.disabled = not general
	_awaiting_action = ""
	_apply_values()


func _apply_translations() -> void:
	_title.text = LocalizationManager.text("settings.title")
	_general_tab.text = LocalizationManager.text("settings.tab_general")
	_controls_tab.text = LocalizationManager.text("settings.tab_controls")
	_english_button.text = LocalizationManager.text("language.english")
	_portuguese_button.text = LocalizationManager.text("language.portuguese")
	_reset_button.text = LocalizationManager.text("settings.controls_reset")
	_back_button.text = LocalizationManager.text("settings.back")
	for row in _controls_page.get_children():
		for child in row.get_children():
			var label: Label = child as Label
			if label != null and label.has_meta("action"):
				label.text = LocalizationManager.text(ACTION_KEYS[label.get_meta("action")])
	_apply_values()


func _apply_values() -> void:
	_volume_label.text = LocalizationManager.text("audio.volume", [int(round(AudioManager.volume * 100.0))])
	_volume_slider.set_value_no_signal(AudioManager.volume)
	_mute_button.text = LocalizationManager.text("audio.unmute" if AudioManager.muted else "audio.mute")
	_fullscreen_button.text = _toggle_text("settings.fullscreen", GameManager.is_fullscreen())
	_shake_button.text = _toggle_text("settings.screen_shake", GameManager.screen_shake)
	_numbers_button.text = _toggle_text("settings.damage_numbers", GameManager.damage_numbers)
	_english_button.disabled = LocalizationManager.is_language_selected("en")
	_portuguese_button.disabled = LocalizationManager.is_language_selected("pt_BR")
	for action in _action_buttons:
		var button: Button = _action_buttons[action]
		if action == _awaiting_action:
			button.text = LocalizationManager.text("settings.press_key")
			continue
		button.text = GameManager.action_label(action)


func _toggle_text(key: String, value: bool) -> String:
	return "%s: %s" % [
		LocalizationManager.text(key),
		LocalizationManager.text("settings.on" if value else "settings.off"),
	]


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if _awaiting_action.is_empty():
		if event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			close()
		return
	var pressed_key: bool = event is InputEventKey and event.pressed and not event.echo
	var pressed_button: bool = event is InputEventMouseButton and event.pressed
	if not pressed_key and not pressed_button:
		return
	get_viewport().set_input_as_handled()
	if pressed_key and event.keycode == KEY_ESCAPE:
		_awaiting_action = ""
		_apply_values()
		return
	if GameManager.rebind_action(_awaiting_action, event):
		AudioManager.play_click()
	_awaiting_action = ""
	_apply_values()


func _on_volume_changed(value: float) -> void:
	AudioManager.set_volume(value)


func _on_volume_drag_ended(value_changed: bool) -> void:
	if not value_changed:
		return
	AudioManager.save_settings()
	AudioManager.play_click()


func _on_mute_pressed() -> void:
	AudioManager.set_muted(not AudioManager.muted)


func _on_fullscreen_pressed() -> void:
	GameManager.set_fullscreen(not GameManager.is_fullscreen())


func _on_shake_pressed() -> void:
	GameManager.set_screen_shake(not GameManager.screen_shake)


func _on_numbers_pressed() -> void:
	GameManager.set_damage_numbers(not GameManager.damage_numbers)


func _on_language_pressed(code: String) -> void:
	LocalizationManager.set_language(code)


func _on_rebind_pressed(action: String) -> void:
	_awaiting_action = action
	_apply_values()


func _on_reset_pressed() -> void:
	GameManager.reset_controls()
	_apply_values()
