extends Control

@onready var canvas_display: TextureRect = $CenterContainer/VBoxContainer/FramePanel/CanvasDisplay
@onready var title_label: Label = $CenterContainer/VBoxContainer/TitleLabel
@onready var path_label: Label = $CenterContainer/VBoxContainer/PathLabel
@onready var instruction_label: Label = $CenterContainer/VBoxContainer/InstructionLabel


func _ready() -> void:
	LocalizationManager.language_changed.connect(_apply_translations)
	var texture: ImageTexture = GameManager.get_last_canvas_texture()
	if texture != null:
		canvas_display.texture = texture
		path_label.text = GameManager.get_last_saved_scenario_message()
	else:
		path_label.text = ""
	_apply_translations()


func _apply_translations() -> void:
	instruction_label.text = LocalizationManager.text("scenario.press_escape")
	if GameManager.has_last_canvas_snapshot():
		title_label.text = LocalizationManager.text("scenario.final_canvas")
		path_label.text = GameManager.get_last_saved_scenario_message()
	else:
		title_label.text = LocalizationManager.text("scenario.no_canvas")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		GameManager.go_to_game_over()
