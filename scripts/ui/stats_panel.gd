class_name StatsPanel
extends PanelContainer

const FONT_SIZE: int = 8
const ROW_SPACING: int = 3
const LABEL_COLOR: Color = Color(0.4, 0.4, 0.4, 1.0)
const VALUE_COLOR: Color = Color(0.12, 0.12, 0.12, 1.0)
const RATE_DECIMAL_LIMIT: float = 10.0

const STATS: Array[String] = ["life", "damage", "rate", "pierce", "size", "speed", "dash"]

var _player: Player = null
var _controller: AbilityController = null
var _rows: VBoxContainer = null
var _names: Dictionary = {}
var _values: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_rows = VBoxContainer.new()
	_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rows.add_theme_constant_override("separation", ROW_SPACING)
	add_child(_rows)
	for stat in STATS:
		_add_row(stat)
	LocalizationManager.language_changed.connect(_on_language_changed)
	_apply_translations()


func setup(player: Player, controller: AbilityController) -> void:
	_player = player
	_controller = controller
	refresh()


func refresh() -> void:
	if _player == null or _controller == null:
		return
	var abilities: Array[AbilityData] = _controller.get_abilities()
	_set_value("life", "%d/%d" % [ceili(maxf(_player.current_hp, 0.0)), roundi(_player.max_hp)])
	_set_value("damage", format_damage(abilities))
	_set_value("rate", format_rate(abilities))
	_set_value("pierce", format_pierce(abilities))
	_set_value("size", format_size(abilities))
	_set_value("speed", format_speed(abilities))
	_set_value("dash", LocalizationManager.text("stats.seconds", [_decimal(_player.dash_cooldown)]))


func value_text(stat: String) -> String:
	if not _values.has(stat):
		return ""
	return (_values[stat] as Label).text


func format_damage(abilities: Array[AbilityData]) -> String:
	if abilities.is_empty():
		return "-"
	var low: float = 0.0
	var high: float = 0.0
	for data in abilities:
		if data.shot_type == AbilityData.ShotType.CHARGE:
			low += data.damage * AbilityData.CHARGE_MIN_DAMAGE
			high += data.damage * AbilityData.CHARGE_MAX_DAMAGE
		else:
			low += data.damage
			high += data.damage
	return _range_text(low, high, "")


func shots_per_second(abilities: Array[AbilityData]) -> float:
	var total: float = 0.0
	for data in abilities:
		var cycle: float = data.cooldown
		if data.shot_type == AbilityData.ShotType.CHARGE:
			cycle += data.charge_time
		if cycle > 0.0:
			total += float(maxi(data.projectile_count, 1)) / cycle
	return total


func format_rate(abilities: Array[AbilityData]) -> String:
	var rate: float = shots_per_second(abilities)
	var number: String = _decimal(rate) if rate < RATE_DECIMAL_LIMIT else str(roundi(rate))
	return LocalizationManager.text("stats.per_second", [number])


func format_pierce(abilities: Array[AbilityData]) -> String:
	if abilities.is_empty():
		return "-"
	var low: float = 0.0
	var high: float = 0.0
	for data in abilities:
		low += data.piercing
		high += data.shot_piercing() if data.shot_type != AbilityData.ShotType.CHARGE \
			else data.piercing + AbilityData.CHARGE_FULL_PIERCE
	return _range_text(low / abilities.size(), high / abilities.size(), "")


func format_size(abilities: Array[AbilityData]) -> String:
	if abilities.is_empty():
		return "-"
	var total: float = 0.0
	for data in abilities:
		var size: float = data.size_scale
		if data.shot_type == AbilityData.ShotType.CHARGE:
			size *= AbilityData.CHARGE_MAX_SIZE
		total += size
	return "%d%%" % roundi(total / abilities.size() * 100.0)


func format_speed(abilities: Array[AbilityData]) -> String:
	if abilities.is_empty() or _controller.projectile_speed <= 0.0:
		return "-"
	var total: float = 0.0
	for data in abilities:
		total += data.projectile_speed
	return "%d%%" % roundi(total / abilities.size() / _controller.projectile_speed * 100.0)


func _range_text(low: float, high: float, suffix: String) -> String:
	var rounded_low: int = roundi(low)
	var rounded_high: int = roundi(high)
	if rounded_low == rounded_high:
		return "%d%s" % [rounded_low, suffix]
	return "%d-%d%s" % [rounded_low, rounded_high, suffix]


func _add_row(stat: String) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rows.add_child(row)
	var name_label: Label = _make_label(LABEL_COLOR)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	row.add_child(name_label)
	var value_label: Label = _make_label(VALUE_COLOR)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)
	_names[stat] = name_label
	_values[stat] = value_label


func _make_label(color: Color) -> Label:
	var label: Label = Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_color_override("font_color", color)
	return label


func _set_value(stat: String, text: String) -> void:
	if _values.has(stat):
		(_values[stat] as Label).text = text


func _decimal(value: float) -> String:
	var text: String = "%.1f" % value
	if LocalizationManager.is_language_selected("pt_BR"):
		return text.replace(".", ",")
	return text


func _apply_translations() -> void:
	for stat in STATS:
		(_names[stat] as Label).text = LocalizationManager.text("stats.%s" % stat)


func _on_language_changed() -> void:
	_apply_translations()
	refresh()
