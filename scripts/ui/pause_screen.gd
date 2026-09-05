extends CanvasLayer

signal resumed
signal restart_requested
signal menu_requested

@onready var resume_button: Button = $Dim/CenterContainer/Panel/Content/ResumeButton
@onready var restart_button: Button = $Dim/CenterContainer/Panel/Content/RestartButton
@onready var menu_button: Button = $Dim/CenterContainer/Panel/Content/MenuButton
@onready var title_label: Label = $Dim/CenterContainer/Panel/Content/TitleLabel


func _ready() -> void:
	visible = false
	resume_button.pressed.connect(_on_resume_button_pressed)
	restart_button.pressed.connect(_on_restart_button_pressed)
	menu_button.pressed.connect(_on_menu_button_pressed)
	LocalizationManager.language_changed.connect(_apply_translations)
	_apply_translations()


func _apply_translations() -> void:
	title_label.text = LocalizationManager.text("pause.title")
	resume_button.text = LocalizationManager.text("pause.resume")
	restart_button.text = LocalizationManager.text("pause.restart")
	menu_button.text = LocalizationManager.text("pause.menu")


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		_on_resume_button_pressed()


func open() -> void:
	visible = true
	get_tree().paused = true


func close() -> void:
	visible = false
	get_tree().paused = false


func _on_resume_button_pressed() -> void:
	close()
	resumed.emit()


func _on_restart_button_pressed() -> void:
	close()
	restart_requested.emit()


func _on_menu_button_pressed() -> void:
	close()
	menu_requested.emit()
