extends DrawingCreatorBase

const SHOP_FONT_SIZE: int = 8
const SHOP_TEXT_COLOR: Color = Color(0.2, 0.2, 0.2, 1.0)
const SHOP_SEPARATION: int = 2

var _palettes_label: Label = null
var _slots_label: Label = null
var _buy_slot_button: Button = null


func _creator_title_key() -> String:
	return "creator.character_title"


func _on_creator_ready() -> void:
	_build_flask_shop()
	_load_previous_drawing()


func _on_confirm_button_pressed() -> void:
	if not pixel_editor.has_any_pixels():
		_show_feedback("creator.draw_character_first")
		return

	GameManager.set_character_drawing(pixel_editor.get_image_copy())
	var saved: bool = GameManager.save_character_drawing_to_disk()
	if not saved:
		push_warning("[CharacterCreator] O desenho ficou apenas em memória (falha ao salvar em disco).")

	GameManager.go_to_ability_creator()


func _on_back_button_pressed() -> void:
	GameManager.go_to_main_menu()


func _load_previous_drawing() -> void:
	if not GameManager.has_character_drawing():
		GameManager.load_character_drawing_from_disk()
	if GameManager.has_character_drawing():
		pixel_editor.load_from_image(GameManager.character_image)
		_show_feedback("creator.character_loaded")


func buy_slot_button() -> Button:
	return _buy_slot_button


func _build_flask_shop() -> void:
	var side_panel: VBoxContainer = confirm_button.get_parent() as VBoxContainer
	if side_panel == null:
		push_warning("[CharacterCreator] Painel lateral não encontrado; loja de frascos ignorada.")
		return

	var shop: VBoxContainer = VBoxContainer.new()
	shop.add_theme_constant_override("separation", SHOP_SEPARATION)

	var coin_row: HBoxContainer = HBoxContainer.new()
	coin_row.add_theme_constant_override("separation", SHOP_SEPARATION * 2)
	var icon: TextureRect = TextureRect.new()
	icon.texture = PaletteCoin.build_texture(1)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	coin_row.add_child(icon)
	_palettes_label = _make_shop_label()
	coin_row.add_child(_palettes_label)
	shop.add_child(coin_row)

	_slots_label = _make_shop_label()
	shop.add_child(_slots_label)

	_buy_slot_button = Button.new()
	_buy_slot_button.add_theme_font_size_override("font_size", SHOP_FONT_SIZE)
	_buy_slot_button.pressed.connect(_on_buy_slot_pressed)
	shop.add_child(_buy_slot_button)

	side_panel.add_child(shop)
	side_panel.move_child(shop, confirm_button.get_index())
	LocalizationManager.language_changed.connect(_refresh_flask_shop)
	_refresh_flask_shop()


func _make_shop_label() -> Label:
	var label: Label = Label.new()
	label.add_theme_font_size_override("font_size", SHOP_FONT_SIZE)
	label.add_theme_color_override("font_color", SHOP_TEXT_COLOR)
	return label


func _on_buy_slot_pressed() -> void:
	if GameManager.buy_flask_slot():
		_show_feedback("creator.slot_bought")
	elif GameManager.flask_slots >= FlaskEffects.MAX_SLOTS:
		_show_feedback("creator.slots_maxed")
	else:
		_show_feedback("creator.no_palettes")
	_refresh_flask_shop()


func _refresh_flask_shop() -> void:
	if _buy_slot_button == null:
		return
	_palettes_label.text = LocalizationManager.text("creator.palettes", [GameManager.palettes])
	_slots_label.text = LocalizationManager.text(
		"creator.flask_slots", [GameManager.flask_slots, FlaskEffects.MAX_SLOTS])
	_buy_slot_button.text = LocalizationManager.text("creator.buy_slot")
	_buy_slot_button.disabled = not GameManager.can_buy_flask_slot()
