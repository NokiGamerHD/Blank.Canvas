extends Control

@onready var wave_label: Label = $CenterContainer/MenuContainer/WaveLabel
@onready var play_again_button: Button = $CenterContainer/MenuContainer/PlayAgainButton
@onready var save_scenario_button: Button = $CenterContainer/MenuContainer/SaveScenarioButton
@onready var menu_button: Button = $CenterContainer/MenuContainer/MenuButton


func _ready() -> void:
	play_again_button.pressed.connect(_on_play_again_button_pressed)
	save_scenario_button.pressed.connect(_on_save_scenario_button_pressed)
	menu_button.pressed.connect(_on_menu_button_pressed)
	LocalizationManager.language_changed.connect(_apply_translations)
	_apply_translations()


func _apply_translations() -> void:
	wave_label.text = LocalizationManager.text("game_over.wave_reached", [GameManager.last_wave_reached])
	play_again_button.text = LocalizationManager.text("game_over.play_again")
	save_scenario_button.text = LocalizationManager.text("game_over.save_scenario")
	menu_button.text = LocalizationManager.text("game_over.menu")


func _on_play_again_button_pressed() -> void:
	GameManager.reset_run_data()
	GameManager.go_to_character_creator()


func _on_save_scenario_button_pressed() -> void:
	if not GameManager.has_last_canvas_snapshot():
		return
	GameManager.save_last_canvas_to_disk()
	if not ResourceLoader.exists(GameManager.SCENE_SCENARIO_VIEWER):
		push_warning("[GameOver] Cena do visualizador de cenário não encontrada.")
		return
	TransitionManager.play_flash_transition(func() -> void:
		get_tree().change_scene_to_file(GameManager.SCENE_SCENARIO_VIEWER)
	)


func _on_menu_button_pressed() -> void:
	GameManager.go_to_main_menu()
