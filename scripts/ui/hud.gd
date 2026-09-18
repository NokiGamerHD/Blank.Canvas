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
const STATS_PANEL_GAP: float = 8.0
const ABILITY_SLOT_SIZE: float = 28.0
const MIN_ABILITY_SLOT_SIZE: float = 8.0
const ABILITY_BAR_SCREEN_MARGIN: float = 8.0
const ABILITY_ROW_SEPARATION: int = 6
const MIN_ABILITY_ROW_SEPARATION: int = 2
const INK_ROW_SEPARATION: int = 4
const INK_FONT_SIZE: int = 10
const INK_TEXT_COLOR: Color = Color(0.2, 0.2, 0.2, 1.0)

@onready var hp_label: Label = $InfoPanel/InfoContainer/HPLabel
@onready var wave_label: Label = $InfoPanel/InfoContainer/WaveLabel
@onready var enemies_label: Label = $InfoPanel/InfoContainer/EnemiesLabel
@onready var info_container: VBoxContainer = $InfoPanel/InfoContainer
@onready var abilities_row: HBoxContainer = $AbilitiesPanel/AbilitiesRow
@onready var minimap: Minimap = $MinimapPanel/Minimap
@onready var enemy_indicators: EnemyIndicators = $EnemyIndicators

var _count_timer: Timer = null
var _ability_controller: AbilityController = null
var _player: Player = null
var _dash_slot: AbilitySlot = null
var _controls_hint: Label = null
var _stats_panel: StatsPanel = null
var _screen_edges: ScreenEdges = null
var _ink_label: Label = null
var _dash_icon_large: ImageTexture = null
var _dash_icon_small: ImageTexture = null
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
	_count_timer.timeout.connect(_refresh_stats)
	add_child(_count_timer)
	_count_timer.start()
	_refresh_enemy_count()
	_build_controls_hint()
	_apply_translations()


func _process(_delta: float) -> void:
	if _dash_slot != null and _player != null:
		_dash_slot.set_cooldown_fraction(_player.dash_cooldown_fraction())
	if _screen_edges != null and _player != null:
		_screen_edges.apply_footing(_player.footing(), _player.footing_color())

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
	if _screen_edges != null and current_hp < _current_hp:
		_screen_edges.flash_hurt()
	_current_hp = current_hp
	_max_hp = max_hp
	hp_label.text = LocalizationManager.text("hud.hp", [ceili(_current_hp), int(_max_hp)])


func setup_abilities(controller: AbilityController) -> void:
	_ability_controller = controller


func setup_player(player: Player) -> void:
	_player = player
	_build_screen_edges()
	_build_stats_panel()
	_build_ink_row()
	if _dash_slot != null:
		return
	_dash_icon_large = _build_dash_icon(DASH_ICON_SCALE)
	_dash_icon_small = _build_dash_icon(1)
	_dash_slot = AbilitySlotScene.instantiate()
	abilities_row.add_child(_dash_slot)
	abilities_row.move_child(_dash_slot, 0)
	_dash_slot.set_pixel_icon(_dash_icon_large, DASH_COOLDOWN_OVERLAY)
	_fit_ability_bar()


func screen_edges() -> ScreenEdges:
	return _screen_edges


func _build_screen_edges() -> void:
	if _screen_edges != null:
		return
	_screen_edges = ScreenEdges.new()
	add_child(_screen_edges)
	move_child(_screen_edges, 0)


func update_ink(total: int) -> void:
	if _ink_label != null:
		_ink_label.text = str(total)


func ink_text() -> String:
	return _ink_label.text if _ink_label != null else ""


func _build_ink_row() -> void:
	if _ink_label == null:
		var row: HBoxContainer = HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", INK_ROW_SEPARATION)
		_ink_label = Label.new()
		_ink_label.add_theme_font_size_override("font_size", INK_FONT_SIZE)
		_ink_label.add_theme_color_override("font_color", INK_TEXT_COLOR)
		row.add_child(_ink_label)
		var icon: TextureRect = TextureRect.new()
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.texture = PaintDrop.icon_texture(1)
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		row.add_child(icon)
		info_container.add_child(row)
	if not _player.ink_changed.is_connected(update_ink):
		_player.ink_changed.connect(update_ink)
	update_ink(_player.ink)


func _build_dash_icon(icon_scale: int) -> ImageTexture:
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
	image.resize(width * icon_scale, height * icon_scale, Image.INTERPOLATE_NEAREST)
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
	_fit_ability_bar()


func _fit_ability_bar() -> void:
	var slots: Array[AbilitySlot] = []
	if _dash_slot != null:
		slots.append(_dash_slot)
	slots.append_array(_slots)
	if slots.is_empty():
		return

	var count: int = slots.size()
	var bar_panel: Control = abilities_row.get_parent() as Control
	var chrome: float = 0.0
	var style: StyleBox = bar_panel.get_theme_stylebox("panel")
	if style != null:
		chrome = style.get_minimum_size().x
	var available: float = get_viewport().get_visible_rect().size.x - ABILITY_BAR_SCREEN_MARGIN * 2.0 - chrome

	var separation: int = ABILITY_ROW_SEPARATION
	var side: float = ABILITY_SLOT_SIZE
	if count * side + (count - 1) * separation > available:
		separation = MIN_ABILITY_ROW_SEPARATION
		side = clampf(floorf((available - (count - 1) * separation) / count), MIN_ABILITY_SLOT_SIZE, ABILITY_SLOT_SIZE)
	abilities_row.add_theme_constant_override("separation", separation)
	for slot in slots:
		slot.set_slot_size(side)

	if _dash_slot == null or _dash_icon_large == null:
		return
	var dash_icon: ImageTexture = _dash_icon_large if side >= _dash_icon_large.get_width() else _dash_icon_small
	_dash_slot.set_pixel_icon(dash_icon, DASH_COOLDOWN_OVERLAY)
	if side < dash_icon.get_width():
		_dash_slot.icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED


func ability_slot_size() -> float:
	if _dash_slot == null:
		return 0.0
	return _dash_slot.custom_minimum_size.x


func _refresh_enemy_count() -> void:
	_alive_enemies = get_tree().get_nodes_in_group("enemies").size()
	enemies_label.text = LocalizationManager.text("hud.enemies", [_alive_enemies])


func _apply_translations() -> void:
	update_hp(_current_hp, _max_hp)
	update_wave(_current_wave)
	enemies_label.text = LocalizationManager.text("hud.enemies", [_alive_enemies])
	if _controls_hint != null:
		_controls_hint.text = LocalizationManager.text("hud.controls_hint")


func get_stats_panel() -> StatsPanel:
	return _stats_panel


func _build_stats_panel() -> void:
	if _stats_panel != null:
		_stats_panel.setup(_player, _ability_controller)
		return
	var minimap_panel: Control = get_node("MinimapPanel")
	_stats_panel = StatsPanel.new()
	_stats_panel.anchor_left = minimap_panel.anchor_left
	_stats_panel.anchor_right = minimap_panel.anchor_right
	_stats_panel.offset_left = minimap_panel.offset_left
	_stats_panel.offset_right = minimap_panel.offset_right
	_stats_panel.offset_top = minimap_panel.offset_bottom + STATS_PANEL_GAP
	_stats_panel.offset_bottom = _stats_panel.offset_top
	_stats_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	add_child(_stats_panel)
	move_child(_stats_panel, enemy_indicators.get_index())
	_stats_panel.setup(_player, _ability_controller)


func _refresh_stats() -> void:
	if _stats_panel != null:
		_stats_panel.refresh()
