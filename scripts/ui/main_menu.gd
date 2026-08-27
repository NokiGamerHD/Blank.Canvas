extends Control

@onready var title_label: Label = $CenterContainer/MenuContainer/TitleLabel
@onready var play_button: Button = $CenterContainer/MenuContainer/PlayButton
@onready var quit_button: Button = $CenterContainer/MenuContainer/QuitButton
@onready var feedback_label: Label = $FeedbackLabel
@onready var language_button: Button = $LanguageButton
@onready var language_panel: PanelContainer = $LanguagePanel
@onready var language_title: Label = $LanguagePanel/Content/TitleLabel
@onready var english_button: Button = $LanguagePanel/Content/EnglishButton
@onready var portuguese_button: Button = $LanguagePanel/Content/PortugueseButton
@onready var version_label: Label = $VersionLabel


func _ready() -> void:
	play_button.pressed.connect(_on_play_button_pressed)
	quit_button.pressed.connect(_on_quit_button_pressed)
	language_button.pressed.connect(_on_language_button_pressed)
	english_button.pressed.connect(_on_english_button_pressed)
	portuguese_button.pressed.connect(_on_portuguese_button_pressed)
	LocalizationManager.language_changed.connect(_apply_translations)

	feedback_label.visible = false
	language_panel.visible = false
	_apply_translations()


func _apply_translations() -> void:
	title_label.text = GameManager.DISPLAY_NAME.to_upper()
	play_button.text = LocalizationManager.text("menu.play")
	quit_button.text = LocalizationManager.text("menu.quit")
	language_button.tooltip_text = LocalizationManager.text("language.tooltip")
	language_title.text = LocalizationManager.text("language.title")
	english_button.text = LocalizationManager.text("language.english")
	portuguese_button.text = LocalizationManager.text("language.portuguese")
	english_button.disabled = LocalizationManager.is_language_selected("en")
	portuguese_button.disabled = LocalizationManager.is_language_selected("pt_BR")
	version_label.text = "v%s" % GameManager.VERSION


func _on_play_button_pressed() -> void:
	GameManager.reset_run_data()

	var changed: bool = GameManager.go_to_character_creator()
	if not changed:
		feedback_label.text = LocalizationManager.text("menu.character_creator_error")
		feedback_label.visible = true


func _on_quit_button_pressed() -> void:
	GameManager.quit_game()


func _on_language_button_pressed() -> void:
	language_panel.visible = not language_panel.visible


func _on_english_button_pressed() -> void:
	LocalizationManager.set_language("en")
	language_panel.visible = false


func _on_portuguese_button_pressed() -> void:
	LocalizationManager.set_language("pt_BR")
	language_panel.visible = false
