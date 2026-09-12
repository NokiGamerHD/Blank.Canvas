extends CanvasLayer

const AbilitySlotScene: PackedScene = preload("res://scenes/ui/ability_slot.tscn")

const DASH_ICON_PATTERN: Array[String] = [
	"..............",
	"..........##..",
	".........###..",
	".........##...",
	"......#####...",
	"##...##.####..",
	"....##..##.##.",
	"###.....##....",
	"........###...",
	"##.....##.##..",
	"......##...##.",
	".....##.....#.",
	"....##........",
	"..............",
]
const DASH_ICON_SCALE: int = 2
const DASH_ICON_COLOR: Color = Color(0.12, 0.12, 0.12, 1.0)
const DASH_ICON_OUTLINE: Color = Color(0.96, 0.96, 0.93, 1.0)
const DASH_COOLDOWN_OVERLAY: Color = Color(0.12, 0.12, 0.12, 0.45)
const CONTROLS_HINT_SECONDS: float = 6.0
const CONTROLS_HINT_FADE: float = 1.0
const CONTROLS_HINT_BOTTOM_OFFSET: float = 66.0

@onready var hp_label: Label = $InfoPanel/InfoContainer/HPLabel
@onready var wave_label: Label = $InfoPanel/InfoContainer/WaveLabel
@onready var enemies_label: Label = $InfoPanel/InfoContainer/EnemiesLabel
@onready var abilities_row: HBoxContainer = $AbilitiesPanel/AbilitiesRow
@onready var minimap: Minimap = $MinimapPanel/Minimap
@onready var enemy_indicators: EnemyIndicators = $EnemyIndicators

var _count_timer: Timer = null
var _ability_controller: AbilityController = null
var _player: Player = null
var _dash_slot: AbilitySlot = null
var _controls_hint: Label = null
var _slots: Array[AbilitySlot] = []
var _tracked_ability_count: int = -1
var _current_wave: int = 1
var _current_hp: float = 100.0
var _max_hp: float = 100.0
var _alive_enemies: int = 0


func _ready() -> void:
	LocalizationManager.language_changed.connect(_apply_translations)
	_count_timer = Timer.new()
	_count_timer.wait_time = 0.2
	_count_timer.timeout.connect(_refresh_enemy_count)
	add_child(_count_timer)
	_count_timer.start()
	_refresh_enemy_count()
	_build_controls_hint()
	_apply_translations()


func _process(_delta: float) -> void:
	if _dash_slot != null and _player != null:
		_dash_slot.set_cooldown_fraction(_player.dash_cooldown_fraction())

	if _ability_controller == null:
		return

	var abilities: Array[AbilityData] = _ability_controller.get_abilities()
	if abilities.size() != _tracked_ability_count:
		_rebuild_ability_slots(abilities)

	for i in abilities.size():
		var data: AbilityData = abilities[i]
		var fraction: float = 0.0
		if data.cooldown > 0.0:
			fraction = data.cooldown_remaining / data.cooldown
		_slots[i].set_cooldown_fraction(fraction)


func update_wave(wave: int) -> void:
	_current_wave = wave
	wave_label.text = LocalizationManager.text("hud.wave", [_current_wave])


func update_hp(current_hp: float, max_hp: float) -> void:
	_current_hp = current_hp
	_max_hp = max_hp
	hp_label.text = LocalizationManager.text("hud.hp", [ceili(_current_hp), int(_max_hp)])


func setup_abilities(controller: AbilityController) -> void:
	_ability_controller = controller


func setup_player(player: Player) -> void:
	_player = player
	if _dash_slot != null:
		return
	_dash_slot = AbilitySlotScene.instantiate()
	abilities_row.add_child(_dash_slot)
	abilities_row.move_child(_dash_slot, 0)
	_dash_slot.set_pixel_icon(_build_dash_icon(), DASH_COOLDOWN_OVERLAY)


func _build_dash_icon() -> ImageTexture:
	var height: int = DASH_ICON_PATTERN.size()
	var width: int = DASH_ICON_PATTERN[0].length()
	var image: Image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for y in height:
		var row: String = DASH_ICON_PATTERN[y]
		for x in mini(width, row.length()):
			if row[x] == "#":
				image.set_pixel(x, y, DASH_ICON_COLOR)
			elif _touches_ink(x, y):
				image.set_pixel(x, y, DASH_ICON_OUTLINE)
	image.resize(width * DASH_ICON_SCALE, height * DASH_ICON_SCALE, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(image)


func _touches_ink(x: int, y: int) -> bool:
	for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var neighbour: Vector2i = Vector2i(x, y) + offset
		if neighbour.y < 0 or neighbour.y >= DASH_ICON_PATTERN.size():
			continue
		var row: String = DASH_ICON_PATTERN[neighbour.y]
		if neighbour.x >= 0 and neighbour.x < row.length() and row[neighbour.x] == "#":
			return true
	return false


func _build_controls_hint() -> void:
	_controls_hint = Label.new()
	_controls_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_controls_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_controls_hint.add_theme_font_size_override("font_size", 8)
	_controls_hint.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2, 1.0))
	_controls_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_controls_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_controls_hint.offset_top = -CONTROLS_HINT_BOTTOM_OFFSET
	_controls_hint.offset_bottom = -CONTROLS_HINT_BOTTOM_OFFSET + 12.0
	add_child(_controls_hint)
	move_child(_controls_hint, 0)

	var tween: Tween = create_tween()
	tween.tween_interval(CONTROLS_HINT_SECONDS)
	tween.tween_property(_controls_hint, "modulate:a", 0.0, CONTROLS_HINT_FADE)
	tween.tween_callback(_controls_hint.hide)


func setup_minimap(arena: Arena) -> void:
	minimap.setup(arena)


func setup_enemy_indicators(arena: Arena) -> void:
	enemy_indicators.setup(arena)


func _rebuild_ability_slots(abilities: Array[AbilityData]) -> void:
	for slot in _slots:
		slot.queue_free()
	_slots.clear()

	for data in abilities:
		var slot: AbilitySlot = AbilitySlotScene.instantiate()
		abilities_row.add_child(slot)
		slot.set_texture(GameManager.get_ability_texture(data.ability_index))
		_slots.append(slot)

	_tracked_ability_count = abilities.size()


func _refresh_enemy_count() -> void:
	_alive_enemies = get_tree().get_nodes_in_group("enemies").size()
	enemies_label.text = LocalizationManager.text("hud.enemies", [_alive_enemies])


func _apply_translations() -> void:
	update_hp(_current_hp, _max_hp)
	update_wave(_current_wave)
	enemies_label.text = LocalizationManager.text("hud.enemies", [_alive_enemies])
	if _controls_hint != null:
		_controls_hint.text = LocalizationManager.text("hud.controls_hint")
