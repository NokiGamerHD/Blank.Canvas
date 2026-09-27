class_name ShopScreen
extends CanvasLayer

signal closed

const LAYER: int = 32
const PANEL_WIDTH: int = 470
const DIM_COLOR: Color = Color(0.05, 0.05, 0.07, 0.55)
const TITLE_FONT_SIZE: int = 14
const ITEM_FONT_SIZE: int = 8
const INFO_FONT_SIZE: int = 8
const BUTTON_FONT_SIZE: int = 9
const COLUMNS: int = 2
const ITEM_SIZE: Vector2 = Vector2(214, 30)
const GRID_SEPARATION: int = 4
const ITEM_PADDING: int = 8
const CONTENT_SEPARATION: int = 6
const BACK_BUTTON_SIZE: Vector2 = Vector2(200, 26)
const SIGNATURE_FIELD_SIZE: Vector2 = Vector2(180, 22)
const TITLE_COLOR: Color = Color(0.12, 0.12, 0.12, 1.0)
const INFO_COLOR: Color = Color(0.32, 0.32, 0.32, 1.0)
const PRICE_COLOR: Color = Color(0.45, 0.35, 0.05, 1.0)
const SOLD_COLOR: Color = Color(0.30, 0.45, 0.30, 1.0)
const FEEDBACK_COLOR: Color = Color(0.55, 0.20, 0.20, 1.0)

var _title: Label = null
var _balance: Label = null
var _description: Label = null
var _feedback: Label = null
var _back_button: Button = null
var _signature_row: HBoxContainer = null
var _signature_label: Label = null
var _signature_field: LineEdit = null
var _buttons: Dictionary = {}
var _names: Dictionary = {}
var _prices: Dictionary = {}
var _focused: String = ""


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

	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	center.add_child(panel)

	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", CONTENT_SEPARATION)
	panel.add_child(content)

	_title = _make_label(TITLE_FONT_SIZE, TITLE_COLOR)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_title)

	var balance_row: HBoxContainer = HBoxContainer.new()
	balance_row.alignment = BoxContainer.ALIGNMENT_CENTER
	balance_row.add_theme_constant_override("separation", GRID_SEPARATION)
	content.add_child(balance_row)
	var coin: TextureRect = TextureRect.new()
	coin.texture = PaletteCoin.build_texture(1)
	coin.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	coin.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	balance_row.add_child(coin)
	_balance = _make_label(INFO_FONT_SIZE, PRICE_COLOR)
	balance_row.add_child(_balance)

	var grid: GridContainer = GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", GRID_SEPARATION)
	grid.add_theme_constant_override("v_separation", GRID_SEPARATION)
	content.add_child(grid)
	for id in ShopItems.ORDER:
		grid.add_child(_build_item(id))

	_description = _make_label(INFO_FONT_SIZE, INFO_COLOR)
	_description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_description.custom_minimum_size = Vector2(0, 12)
	content.add_child(_description)

	_signature_row = HBoxContainer.new()
	_signature_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_signature_row.add_theme_constant_override("separation", GRID_SEPARATION * 2)
	content.add_child(_signature_row)
	_signature_label = _make_label(INFO_FONT_SIZE, INFO_COLOR)
	_signature_row.add_child(_signature_label)
	_signature_field = LineEdit.new()
	_signature_field.custom_minimum_size = SIGNATURE_FIELD_SIZE
	_signature_field.max_length = ShopItems.MAX_SIGNATURE_LENGTH
	_signature_field.add_theme_font_size_override("font_size", ITEM_FONT_SIZE)
	_signature_field.text_submitted.connect(_on_signature_submitted)
	_signature_field.focus_exited.connect(_commit_signature)
	_signature_row.add_child(_signature_field)

	_feedback = _make_label(INFO_FONT_SIZE, FEEDBACK_COLOR)
	_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback.custom_minimum_size = Vector2(0, 12)
	content.add_child(_feedback)

	_back_button = Button.new()
	_back_button.custom_minimum_size = BACK_BUTTON_SIZE
	_back_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_back_button.add_theme_font_size_override("font_size", BUTTON_FONT_SIZE)
	_back_button.pressed.connect(close)
	content.add_child(_back_button)

	LocalizationManager.language_changed.connect(_apply_translations)
	GameManager.settings_changed.connect(refresh)
	_apply_translations()


func open() -> void:
	_feedback.text = ""
	_focused = ""
	visible = true
	refresh()
	_back_button.grab_focus()


func close() -> void:
	_commit_signature()
	visible = false
	closed.emit()


func is_open() -> bool:
	return visible


func item_button(id: String) -> Button:
	return _buttons.get(id, null)


func description_text() -> String:
	return _description.text


func feedback_text() -> String:
	return _feedback.text


func balance_text() -> String:
	return _balance.text


func signature_field() -> LineEdit:
	return _signature_field


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	close()


func _make_label(font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _build_item(id: String) -> Button:
	var button: Button = Button.new()
	button.custom_minimum_size = ITEM_SIZE
	button.pressed.connect(_on_item_pressed.bind(id))
	button.focus_entered.connect(_on_item_focused.bind(id))
	button.mouse_entered.connect(_on_item_focused.bind(id))
	_buttons[id] = button

	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = ITEM_PADDING
	row.offset_right = -ITEM_PADDING
	row.add_theme_constant_override("separation", GRID_SEPARATION)
	button.add_child(row)

	var icon: Texture2D = ShopItems.icon(id)
	if icon != null:
		var art: TextureRect = TextureRect.new()
		art.texture = icon
		art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		art.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		row.add_child(art)

	var name_label: Label = _make_label(ITEM_FONT_SIZE, TITLE_COLOR)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	row.add_child(name_label)
	_names[id] = name_label

	var price_label: Label = _make_label(ITEM_FONT_SIZE, PRICE_COLOR)
	price_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(price_label)
	_prices[id] = price_label
	return button


func _on_item_focused(id: String) -> void:
	_focused = id
	_description.text = LocalizationManager.text(ShopItems.description_key(id))


func _on_item_pressed(id: String) -> void:
	if GameManager.buy_shop_item(id):
		_feedback.add_theme_color_override("font_color", SOLD_COLOR)
		_feedback.text = LocalizationManager.text("shop.bought")
	else:
		_feedback.add_theme_color_override("font_color", FEEDBACK_COLOR)
		if GameManager.shop_item_sold_out(id):
			_feedback.text = LocalizationManager.text("shop.already_owned")
		else:
			_feedback.text = LocalizationManager.text("shop.no_palettes", [ShopItems.price(id)])
	_on_item_focused(id)
	refresh()


func _on_signature_submitted(_value: String) -> void:
	_commit_signature()


func _commit_signature() -> void:
	if _signature_field.text.strip_edges().to_upper() == GameManager.signature_name:
		return
	GameManager.set_signature_name(_signature_field.text)
	_signature_field.text = GameManager.signature_name


func refresh() -> void:
	if _balance == null:
		return
	_balance.text = LocalizationManager.text("shop.balance", [GameManager.palettes])
	for id in ShopItems.ORDER:
		var button: Button = _buttons[id]
		var name_label: Label = _names[id]
		var price_label: Label = _prices[id]
		name_label.text = LocalizationManager.text(ShopItems.name_key(id))
		var sold_out: bool = GameManager.shop_item_sold_out(id)
		if id == ShopItems.BELT and not sold_out:
			price_label.text = "%d/%d  %d" % [
				GameManager.flask_slots, FlaskEffects.MAX_SLOTS, ShopItems.price(id)]
		elif sold_out:
			price_label.text = LocalizationManager.text("shop.owned")
		else:
			price_label.text = str(ShopItems.price(id))
		price_label.add_theme_color_override("font_color", SOLD_COLOR if sold_out else PRICE_COLOR)
		button.disabled = sold_out or not GameManager.can_buy_shop_item(id)

	var signed: bool = GameManager.has_shop_item(ShopItems.SIGNATURE)
	_signature_row.visible = signed
	if signed and _signature_field.text != GameManager.signature_name:
		_signature_field.text = GameManager.signature_name


func _apply_translations() -> void:
	_title.text = LocalizationManager.text("shop.title")
	_back_button.text = LocalizationManager.text("progression.back")
	_signature_label.text = LocalizationManager.text("shop.signature_label")
	_signature_field.placeholder_text = LocalizationManager.text("shop.signature_hint")
	if _focused.is_empty():
		_description.text = LocalizationManager.text("shop.hint")
	else:
		_description.text = LocalizationManager.text(ShopItems.description_key(_focused))
	refresh()
