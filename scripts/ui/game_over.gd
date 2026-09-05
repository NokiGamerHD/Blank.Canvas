extends Control

const RECORD_COLOR: Color = Color(0.75, 0.5, 0.1, 1.0)
const BEST_COLOR: Color = Color(0.4, 0.4, 0.4, 1.0)

@onready var wave_label: Label = $CenterContainer/MenuContainer/WaveLabel
@onready var best_wave_label: Label = $CenterContainer/MenuContainer/BestWaveLabel
@onready var retry_button: Button = $CenterContainer/MenuContainer/RetryButton
@onready var new_drawing_button: Button = $CenterContainer/MenuContainer/NewDrawingButton
@onready var save_scenario_button: Button = $CenterContainer/MenuContainer/SaveScenarioButton
@onready var menu_button: Button = $CenterContainer/MenuContainer/MenuButton


func _ready() -> void:
	retry_button.pressed.connect(_on_retry_button_pressed)
	new_drawing_button.pressed.connect(_on_new_drawing_button_pressed)
	save_scenario_button.pressed.connect(_on_save_scenario_button_pressed)
	menu_button.pressed.connect(_on_menu_button_pressed)
	LocalizationManager.language_changed.connect(_apply_translations)

	retry_button.visible = GameManager.has_ability_drawing(0)
	_apply_translations()


func _unhandled_input(event: InputEvent) -> void:
	if not retry_button.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		get_viewport().set_input_as_handled()
		_on_retry_button_pressed()


func _apply_translations() -> void:
	wave_label.text = LocalizationManager.text("game_over.wave_reached", [GameManager.last_wave_reached])
	retry_button.text = LocalizationManager.text("game_over.retry")
	new_drawing_button.text = LocalizationManager.text("game_over.new_drawing")
	save_scenario_button.text = LocalizationManager.text("game_over.save_scenario")
	menu_button.text = LocalizationManager.text("game_over.menu")
	_apply_best_wave()


func _apply_best_wave() -> void:
	if GameManager.last_run_was_record:
		best_wave_label.text = LocalizationManager.text("game_over.new_record")
		best_wave_label.add_theme_color_override("font_color", RECORD_COLOR)
		return
	best_wave_label.text = LocalizationManager.text("game_over.best_wave", [GameManager.best_wave])
	best_wave_label.add_theme_color_override("font_color", BEST_COLOR)


func _on_retry_button_pressed() -> void:
	if GameManager.restart_run():
		return
	_on_new_drawing_button_pressed()


func _on_new_drawing_button_pressed() -> void:
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
