extends CanvasLayer

signal upgrade_chosen
signal new_ability_chosen

const UPGRADE_POOL: Array[Dictionary] = [
	{"id": "damage", "text_key": "upgrade.damage"},
	{"id": "cooldown", "text_key": "upgrade.cooldown"},
	{"id": "count", "text_key": "upgrade.count"},
	{"id": "size", "text_key": "upgrade.size"},
	{"id": "pierce", "text_key": "upgrade.pierce"},
	{"id": "speed", "text_key": "upgrade.speed"},
	{"id": "range", "text_key": "upgrade.range"},
]

const MAX_PROJECTILE_COUNT: int = 8
const MAX_SIZE_SCALE: float = 2.5
const MAX_PIERCING: int = 6
const MIN_COOLDOWN: float = 0.15

@onready var title_label: Label = $Dim/CenterContainer/Panel/Content/TitleLabel
@onready var choice_page: VBoxContainer = $Dim/CenterContainer/Panel/Content/ChoicePage
@onready var upgrade_button: Button = $Dim/CenterContainer/Panel/Content/ChoicePage/UpgradeButton
@onready var new_ability_button: Button = $Dim/CenterContainer/Panel/Content/ChoicePage/NewAbilityButton
@onready var choice_subtitle: Label = $Dim/CenterContainer/Panel/Content/ChoicePage/SubtitleLabel
@onready var upgrade_info_label: Label = $Dim/CenterContainer/Panel/Content/ChoicePage/UpgradeInfoLabel
@onready var new_ability_info_label: Label = $Dim/CenterContainer/Panel/Content/ChoicePage/NewAbilityInfoLabel
@onready var upgrade_page: VBoxContainer = $Dim/CenterContainer/Panel/Content/UpgradePage
@onready var upgrade_options: VBoxContainer = $Dim/CenterContainer/Panel/Content/UpgradePage/UpgradeOptions
@onready var back_to_choice_button: Button = $Dim/CenterContainer/Panel/Content/UpgradePage/BackToChoiceButton
@onready var upgrade_subtitle: Label = $Dim/CenterContainer/Panel/Content/UpgradePage/UpgradeSubtitle

var _abilities: Array[AbilityData] = []
var _current_wave: int = 5


func _ready() -> void:
	visible = false
	upgrade_button.pressed.connect(_on_upgrade_button_pressed)
	new_ability_button.pressed.connect(_on_new_ability_button_pressed)
	back_to_choice_button.pressed.connect(_show_choice_page)
	LocalizationManager.language_changed.connect(_apply_translations)
	_apply_translations()


func open(wave: int, abilities: Array[AbilityData]) -> void:
	_abilities = abilities
	_current_wave = wave
	title_label.text = LocalizationManager.text("progression.wave_complete", [_current_wave])
	_show_choice_page()
	visible = true
	get_tree().paused = true


func close() -> void:
	visible = false
	get_tree().paused = false


func _show_choice_page() -> void:
	choice_page.visible = true
	upgrade_page.visible = false


func _apply_translations() -> void:
	title_label.text = LocalizationManager.text("progression.wave_complete", [_current_wave])
	choice_subtitle.text = LocalizationManager.text("progression.choose_path")
	upgrade_button.text = LocalizationManager.text("progression.upgrade_ability")
	upgrade_info_label.text = LocalizationManager.text("progression.upgrade_info")
	new_ability_button.text = LocalizationManager.text("progression.new_ability")
	new_ability_info_label.text = LocalizationManager.text("progression.new_ability_info")
	upgrade_subtitle.text = LocalizationManager.text("progression.choose_upgrade")
	back_to_choice_button.text = LocalizationManager.text("progression.back")


func _on_new_ability_button_pressed() -> void:
	new_ability_chosen.emit()


func _on_upgrade_button_pressed() -> void:
	_build_upgrade_options()
	choice_page.visible = false
	upgrade_page.visible = true


func _build_upgrade_options() -> void:
	for child in upgrade_options.get_children():
		child.queue_free()

	var pool: Array[Dictionary] = UPGRADE_POOL.duplicate()
	pool.shuffle()

	for i in mini(3, pool.size()):
		var entry: Dictionary = pool[i]
		var target: AbilityData = _abilities.pick_random()

		var label: String = LocalizationManager.text(entry["text_key"])
		if _abilities.size() > 1:
			label = "%s: %s" % [target.display_name(), label]

		var button: Button = Button.new()
		button.text = label
		button.custom_minimum_size = Vector2(300, 30)
		button.add_theme_font_size_override("font_size", 9)
		button.pressed.connect(_on_upgrade_option_pressed.bind(entry["id"], target))
		upgrade_options.add_child(button)


func _on_upgrade_option_pressed(upgrade_id: String, target: AbilityData) -> void:
	_apply_upgrade(upgrade_id, target)
	upgrade_chosen.emit()


func _apply_upgrade(upgrade_id: String, data: AbilityData) -> void:
	match upgrade_id:
		"damage":
			data.damage *= 1.25
		"cooldown":
			data.cooldown = maxf(data.cooldown * 0.85, MIN_COOLDOWN)
		"count":
			data.projectile_count = mini(data.projectile_count + 1, MAX_PROJECTILE_COUNT)
		"size":
			data.size_scale = minf(data.size_scale * 1.2, MAX_SIZE_SCALE)
		"pierce":
			data.piercing = mini(data.piercing + 1, MAX_PIERCING)
		"speed":
			data.projectile_speed *= 1.15
		"range":
			data.attack_range *= 1.10
		_:
			push_warning("[ProgressionScreen] Upgrade desconhecido: %s" % upgrade_id)
