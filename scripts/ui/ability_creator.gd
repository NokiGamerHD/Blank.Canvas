extends DrawingCreatorBase

signal in_run_ability_created(index: int)

signal in_run_cancelled

const MAIN_ABILITY_INDEX: int = 0

const COUNT_OK_COLOR: Color = Color(0.3, 0.3, 0.3)
const COUNT_OVER_COLOR: Color = Color(0.85, 0.2, 0.15)

@export var max_ability_pixels: int = 100

@export var in_run_mode: bool = false

var in_run_target_index: int = MAIN_ABILITY_INDEX

@onready var pixel_count_label: Label = $CenterContainer/MainContainer/EditorRow/SidePanel/PixelCountLabel


func _creator_title_key() -> String:
	return "creator.ability_title"


func _back_button_key() -> String:
	return "creator.cancel" if in_run_mode else "creator.back_character"


func _apply_translations() -> void:
	super()
	_update_pixel_count()


func _on_creator_ready() -> void:
	if in_run_mode:
		back_button.text = LocalizationManager.text(_back_button_key())
	else:
		_load_previous_drawing()
	_update_pixel_count()


func open_for_new_ability(index: int) -> void:
	in_run_target_index = index
	pixel_editor.clear_canvas()
	_update_pixel_count()
	_show_feedback("creator.draw_new_ability")


func _on_drawing_changed() -> void:
	super()
	_update_pixel_count()


func _update_pixel_count() -> void:
	var count: int = pixel_editor.outline_pixel_count()
	pixel_count_label.text = LocalizationManager.text("creator.pixels", [count, max_ability_pixels])
	var count_color: Color = COUNT_OVER_COLOR if count > max_ability_pixels else COUNT_OK_COLOR
	pixel_count_label.add_theme_color_override("font_color", count_color)


func _on_confirm_button_pressed() -> void:
	if not pixel_editor.has_any_pixels():
		_show_feedback("creator.draw_ability_first")
		return

	var count: int = pixel_editor.outline_pixel_count()
	if count > max_ability_pixels:
		_show_feedback("creator.ability_too_large", [count, max_ability_pixels])
		return

	var target_index: int = in_run_target_index if in_run_mode else MAIN_ABILITY_INDEX

	GameManager.set_ability_drawing(target_index, pixel_editor.get_image_copy())
	var saved: bool = GameManager.save_ability_drawing_to_disk(target_index)
	if not saved:
		push_warning("[AbilityCreator] A habilidade ficou apenas em memória (falha ao salvar em disco).")

	if in_run_mode:
		in_run_ability_created.emit(target_index)
		return

	var changed: bool = GameManager.go_to_arena()
	if not changed:
		_show_feedback("creator.arena_error")


func _on_back_button_pressed() -> void:
	if in_run_mode:
		in_run_cancelled.emit()
		return
	GameManager.go_to_character_creator()


func _load_previous_drawing() -> void:
	if not GameManager.has_ability_drawing(MAIN_ABILITY_INDEX):
		GameManager.load_ability_drawing_from_disk(MAIN_ABILITY_INDEX)
	if GameManager.has_ability_drawing(MAIN_ABILITY_INDEX):
		pixel_editor.load_from_image(GameManager.get_ability_drawing(MAIN_ABILITY_INDEX))
		_show_feedback("creator.ability_loaded")
