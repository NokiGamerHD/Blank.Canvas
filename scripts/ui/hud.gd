extends CanvasLayer

const AbilitySlotScene: PackedScene = preload("res://scenes/ui/ability_slot.tscn")

@onready var hp_label: Label = $InfoPanel/InfoContainer/HPLabel
@onready var wave_label: Label = $InfoPanel/InfoContainer/WaveLabel
@onready var enemies_label: Label = $InfoPanel/InfoContainer/EnemiesLabel
@onready var abilities_row: HBoxContainer = $AbilitiesPanel/AbilitiesRow
@onready var minimap: Minimap = $MinimapPanel/Minimap

var _count_timer: Timer = null
var _ability_controller: AbilityController = null
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
	_apply_translations()


func _process(_delta: float) -> void:
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


func setup_minimap(arena: Arena) -> void:
	minimap.setup(arena)


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
