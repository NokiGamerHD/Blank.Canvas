extends DrawingCreatorBase


func _creator_title_key() -> String:
	return "creator.character_title"


func _on_creator_ready() -> void:
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
