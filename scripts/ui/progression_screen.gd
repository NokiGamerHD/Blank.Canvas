extends CanvasLayer

signal upgrade_chosen
signal new_ability_chosen

const UPGRADE_POOL: Array[Dictionary] = [
	{"id": "damage", "text_key": "upgrade.damage", "global": false},
	{"id": "cooldown", "text_key": "upgrade.cooldown", "global": false},
	{"id": "count", "text_key": "upgrade.count", "global": false},
	{"id": "size", "text_key": "upgrade.size", "global": false},
	{"id": "pierce", "text_key": "upgrade.pierce", "global": false},
	{"id": "speed", "text_key": "upgrade.speed", "global": false},
	{"id": "dash", "text_key": "upgrade.dash", "global": true},
]

const DAMAGE_MULTIPLIER: float = 1.5
const COOLDOWN_MULTIPLIER: float = 0.75
const COUNT_STEP: int = 2
const SIZE_MULTIPLIER: float = 1.5
const PIERCE_STEP: int = 2
const SPEED_MULTIPLIER: float = 1.3
const DASH_COOLDOWN_MULTIPLIER: float = 0.7

const MAX_PROJECTILE_COUNT: int = 9
const MAX_SIZE_SCALE: float = 3.0
const MAX_PIERCING: int = 8
const MIN_COOLDOWN: float = 0.15
const PERK_PREFIX: String = "perk:"
const OPTION_COUNT: int = 3
const PERK_FACE_COLOR: Color = Color(1.0, 0.9, 0.62, 1.0)
const PERK_HOVER_COLOR: Color = Color(0.96, 0.82, 0.48, 1.0)
const PERK_BORDER_COLOR: Color = Color(0.12, 0.12, 0.12, 1.0)
const PERK_BUTTON_HEIGHT: float = 46.0
const PERK_LINE_SPACING: int = 5
const PERK_NAME_COLOR: Color = Color(0.12, 0.12, 0.12, 1.0)
const PERK_INFO_COLOR: Color = Color(0.3, 0.3, 0.3, 1.0)
const PERK_NAME_FONT_SIZE: int = 9
const PERK_INFO_FONT_SIZE: int = 8

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
var _player: Player = null
var _controller: AbilityController = null
var _current_wave: int = 5


func _ready() -> void:
	visible = false
	upgrade_button.pressed.connect(_on_upgrade_button_pressed)
	new_ability_button.pressed.connect(_on_new_ability_button_pressed)
	back_to_choice_button.pressed.connect(_show_choice_page)
	LocalizationManager.language_changed.connect(_apply_translations)
	_apply_translations()


func open(wave: int, abilities: Array[AbilityData], player: Player = null) -> void:
	_abilities = abilities
	_player = player
	_controller = player.get_node_or_null("AbilityController") as AbilityController if player != null else null
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

	var rest: Array[Dictionary] = []
	for entry in UPGRADE_POOL:
		if entry["global"] and _player == null:
			continue
		rest.append(entry)

	var perk_pool: Array[Dictionary] = _available_perk_entries()
	perk_pool.shuffle()
	var chosen: Array[Dictionary] = []
	if not perk_pool.is_empty():
		chosen.append(perk_pool.pop_back())
	rest.append_array(perk_pool)
	rest.shuffle()
	while chosen.size() < OPTION_COUNT and not rest.is_empty():
		chosen.append(rest.pop_back())
	chosen.shuffle()

	for entry in chosen:
		var target: AbilityData = _abilities.pick_random()
		var button: Button = Button.new()
		button.custom_minimum_size = Vector2(300, 30)
		button.add_theme_font_size_override("font_size", 9)
		button.set_meta("upgrade_id", entry["id"])
		if entry.has("perk"):
			button.custom_minimum_size = Vector2(300, PERK_BUTTON_HEIGHT)
			var lines: VBoxContainer = VBoxContainer.new()
			lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
			lines.alignment = BoxContainer.ALIGNMENT_CENTER
			lines.add_theme_constant_override("separation", PERK_LINE_SPACING)
			lines.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			button.add_child(lines)
			lines.add_child(_perk_label(
				LocalizationManager.text(ShotPerks.name_key(entry["perk"])), PERK_NAME_FONT_SIZE, PERK_NAME_COLOR))
			lines.add_child(_perk_label(
				LocalizationManager.text(ShotPerks.info_key(entry["perk"])), PERK_INFO_FONT_SIZE, PERK_INFO_COLOR))
			button.add_theme_stylebox_override("normal", _perk_style(PERK_FACE_COLOR))
			button.add_theme_stylebox_override("hover", _perk_style(PERK_HOVER_COLOR))
			button.add_theme_stylebox_override("pressed", _perk_style(PERK_HOVER_COLOR))
		else:
			var label: String = LocalizationManager.text(entry["text_key"])
			if _abilities.size() > 1 and not entry["global"]:
				label = "%s: %s" % [target.display_name(), label]
			button.text = label
		button.pressed.connect(_on_upgrade_option_pressed.bind(entry["id"], target))
		upgrade_options.add_child(button)


func _available_perk_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if _controller == null or _abilities.is_empty():
		return entries
	for perk_id in ShotPerks.perks_for(_abilities[0].shot_type):
		if _controller.has_perk(perk_id):
			continue
		entries.append({"id": PERK_PREFIX + perk_id, "perk": perk_id, "global": true})
	return entries


func _perk_label(text: String, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _perk_style(face_color: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = face_color
	style.border_color = PERK_BORDER_COLOR
	style.set_border_width_all(3)
	return style


func _on_upgrade_option_pressed(upgrade_id: String, target: AbilityData) -> void:
	_apply_upgrade(upgrade_id, target)
	upgrade_chosen.emit()


func _apply_upgrade(upgrade_id: String, data: AbilityData) -> void:
	if upgrade_id.begins_with(PERK_PREFIX):
		if _controller == null:
			push_warning("[ProgressionScreen] Buff especial sem controlador; ignorado.")
			return
		_controller.add_perk(upgrade_id.trim_prefix(PERK_PREFIX))
		return
	match upgrade_id:
		"damage":
			data.damage *= DAMAGE_MULTIPLIER
		"cooldown":
			data.cooldown = maxf(data.cooldown * COOLDOWN_MULTIPLIER, MIN_COOLDOWN)
			data.charge_time = maxf(data.charge_time * COOLDOWN_MULTIPLIER, AbilityData.MIN_CHARGE_TIME)
		"count":
			data.projectile_count = mini(data.projectile_count + COUNT_STEP, MAX_PROJECTILE_COUNT)
		"size":
			data.size_scale = minf(data.size_scale * SIZE_MULTIPLIER, MAX_SIZE_SCALE)
		"pierce":
			data.piercing = mini(data.piercing + PIERCE_STEP, MAX_PIERCING)
		"speed":
			data.projectile_speed *= SPEED_MULTIPLIER
		"dash":
			if _player == null:
				push_warning("[ProgressionScreen] Upgrade de dash sem jogador; ignorado.")
				return
			_player.reduce_dash_cooldown(DASH_COOLDOWN_MULTIPLIER)
		_:
			push_warning("[ProgressionScreen] Upgrade desconhecido: %s" % upgrade_id)
