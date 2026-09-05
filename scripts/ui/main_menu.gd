extends Control

@onready var title_label: Label = $CenterContainer/MenuContainer/TitleLabel
@onready var play_button: Button = $CenterContainer/MenuContainer/PlayButton
@onready var quick_play_button: Button = $CenterContainer/MenuContainer/QuickPlayButton
@onready var quit_button: Button = $CenterContainer/MenuContainer/QuitButton
@onready var feedback_label: Label = $FeedbackLabel
@onready var language_button: Button = $LanguageButton
@onready var language_panel: PanelContainer = $LanguagePanel
@onready var language_title: Label = $LanguagePanel/Content/TitleLabel
@onready var english_button: Button = $LanguagePanel/Content/EnglishButton
@onready var portuguese_button: Button = $LanguagePanel/Content/PortugueseButton
@onready var audio_button: Button = $AudioButton
@onready var audio_panel: PanelContainer = $AudioPanel
@onready var audio_title: Label = $AudioPanel/Content/TitleLabel
@onready var volume_label: Label = $AudioPanel/Content/VolumeLabel
@onready var volume_slider: HSlider = $AudioPanel/Content/VolumeSlider
@onready var mute_button: Button = $AudioPanel/Content/MuteButton
@onready var version_label: Label = $VersionLabel
@onready var best_wave_label: Label = $BestWaveLabel


func _ready() -> void:
	play_button.pressed.connect(_on_play_button_pressed)
	quick_play_button.pressed.connect(_on_quick_play_button_pressed)
	quit_button.pressed.connect(_on_quit_button_pressed)
	language_button.pressed.connect(_on_language_button_pressed)
	english_button.pressed.connect(_on_english_button_pressed)
	portuguese_button.pressed.connect(_on_portuguese_button_pressed)
	audio_button.pressed.connect(_on_audio_button_pressed)
	mute_button.pressed.connect(_on_mute_button_pressed)
	volume_slider.value_changed.connect(_on_volume_slider_value_changed)
	volume_slider.drag_ended.connect(_on_volume_slider_drag_ended)
	LocalizationManager.language_changed.connect(_apply_translations)
	AudioManager.audio_settings_changed.connect(_apply_audio_settings)

	feedback_label.visible = false
	language_panel.visible = false
	audio_panel.visible = false
	quick_play_button.visible = GameManager.has_saved_drawings()
	best_wave_label.visible = GameManager.best_wave > 0
	volume_slider.set_value_no_signal(AudioManager.volume)
	_apply_translations()


func _apply_translations() -> void:
	title_label.text = GameManager.DISPLAY_NAME.to_upper()
	play_button.text = LocalizationManager.text("menu.play")
	quick_play_button.text = LocalizationManager.text("menu.quick_play")
	quick_play_button.tooltip_text = LocalizationManager.text("menu.quick_play_tooltip")
	quit_button.text = LocalizationManager.text("menu.quit")
	language_button.tooltip_text = LocalizationManager.text("language.tooltip")
	language_title.text = LocalizationManager.text("language.title")
	english_button.text = LocalizationManager.text("language.english")
	portuguese_button.text = LocalizationManager.text("language.portuguese")
	english_button.disabled = LocalizationManager.is_language_selected("en")
	portuguese_button.disabled = LocalizationManager.is_language_selected("pt_BR")
	audio_button.tooltip_text = LocalizationManager.text("audio.tooltip")
	audio_title.text = LocalizationManager.text("audio.title")
	best_wave_label.text = LocalizationManager.text("menu.best_wave", [GameManager.best_wave])
	version_label.text = "v%s" % GameManager.VERSION
	_apply_audio_settings()


func _apply_audio_settings() -> void:
	volume_slider.set_value_no_signal(AudioManager.volume)
	volume_label.text = LocalizationManager.text("audio.volume", [int(round(AudioManager.volume * 100.0))])
	mute_button.text = LocalizationManager.text("audio.unmute" if AudioManager.muted else "audio.mute")


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


func _on_language_button_pressed() -> void:
	audio_panel.visible = false
	language_panel.visible = not language_panel.visible


func _on_audio_button_pressed() -> void:
	language_panel.visible = false
	audio_panel.visible = not audio_panel.visible


func _on_volume_slider_value_changed(value: float) -> void:
	AudioManager.set_volume(value)


func _on_volume_slider_drag_ended(value_changed: bool) -> void:
	if not value_changed:
		return
	AudioManager.save_settings()
	AudioManager.play_click()


func _on_mute_button_pressed() -> void:
	AudioManager.set_muted(not AudioManager.muted)


func _on_english_button_pressed() -> void:
	LocalizationManager.set_language("en")
	language_panel.visible = false


func _on_portuguese_button_pressed() -> void:
	LocalizationManager.set_language("pt_BR")
	language_panel.visible = false
