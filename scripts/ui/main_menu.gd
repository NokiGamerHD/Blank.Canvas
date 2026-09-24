extends Control

@onready var title_label: Label = $CenterContainer/MenuContainer/TitleLabel
@onready var play_button: Button = $CenterContainer/MenuContainer/PlayButton
@onready var quick_play_button: Button = $CenterContainer/MenuContainer/QuickPlayButton
@onready var settings_button: Button = $CenterContainer/MenuContainer/SettingsButton
@onready var credits_button: Button = $CenterContainer/MenuContainer/CreditsButton
@onready var quit_button: Button = $CenterContainer/MenuContainer/QuitButton
@onready var feedback_label: Label = $FeedbackLabel
@onready var version_label: Label = $VersionLabel
@onready var best_wave_label: Label = $BestWaveLabel

var _settings_screen: SettingsScreen = null
var _credits_screen: CreditsScreen = null


func _ready() -> void:
	play_button.pressed.connect(_on_play_button_pressed)
	quick_play_button.pressed.connect(_on_quick_play_button_pressed)
	settings_button.pressed.connect(_on_settings_button_pressed)
	credits_button.pressed.connect(_on_credits_button_pressed)
	quit_button.pressed.connect(_on_quit_button_pressed)
	LocalizationManager.language_changed.connect(_apply_translations)
	GameManager.settings_changed.connect(_refresh_progress)
	MusicManager.play_menu()

	_settings_screen = SettingsScreen.new()
	add_child(_settings_screen)
	_credits_screen = CreditsScreen.new()
	add_child(_credits_screen)

	feedback_label.visible = false
	_apply_translations()


func _refresh_progress() -> void:
	quick_play_button.visible = GameManager.has_saved_drawings()
	best_wave_label.visible = GameManager.best_wave > 0
	best_wave_label.text = LocalizationManager.text("menu.best_wave", [GameManager.best_wave])


func _apply_translations() -> void:
	title_label.text = GameManager.DISPLAY_NAME.to_upper()
	play_button.text = LocalizationManager.text("menu.play")
	quick_play_button.text = LocalizationManager.text("menu.quick_play")
	quick_play_button.tooltip_text = LocalizationManager.text("menu.quick_play_tooltip")
	settings_button.text = LocalizationManager.text("menu.settings")
	credits_button.text = LocalizationManager.text("menu.credits")
	quit_button.text = LocalizationManager.text("menu.quit")
	version_label.text = "v%s" % GameManager.VERSION
	_refresh_progress()


func _on_play_button_pressed() -> void:
	GameManager.reset_run_data()

	var changed: bool = GameManager.go_to_character_creator()
	if not changed:
		feedback_label.text = LocalizationManager.text("menu.character_creator_error")
		feedback_label.visible = true


func _on_quick_play_button_pressed() -> void:
	if not GameManager.load_saved_drawings():
		feedback_label.text = LocalizationManager.text("menu.quick_play_error")
		feedback_label.visible = true
		return
	GameManager.go_to_arena()


func _on_quit_button_pressed() -> void:
	GameManager.quit_game()


func _on_credits_button_pressed() -> void:
	_credits_screen.open()


func _on_settings_button_pressed() -> void:
	_settings_screen.open()
