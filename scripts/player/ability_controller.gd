class_name AbilityController
extends Node

signal overcharge_ticked(step: int)

const PROJECTILE_SCENE: PackedScene = preload("res://scenes/abilities/projectile.tscn")

const FAN_SPREAD_DEGREES: float = 12.0
const PROJECTILE_BASE_SCALE: float = 1.5
const CHARGE_PREVIEW_ALPHA: float = 0.6
const CHARGE_BLINK_SPEED: float = 16.0
const CHARGE_BLINK_ALPHA: float = 0.35

@export var cooldown: float = 1.0

@export var damage: float = 20.0

@export var projectile_speed: float = 720.0

@export var ability_index: int = 0

@export var spawn_offset: float = 30.0

@export var additional_ability_cooldown_multiplier: float = 1.3

var abilities: Array[AbilityData] = []

var _player: Player = null
var _charge_preview: Sprite2D = null
var _preview_index: int = -1
var _blink_clock: float = 0.0
var _next_charge_slot: int = 0

var perks: Array[String] = []


func _ready() -> void:
	_player = get_parent() as Player
	if _player == null:
		push_warning("[AbilityController] O parent não é um Player; controlador desativado.")
		set_physics_process(false)
		return
	_player.died.connect(_on_player_died)

	abilities = [_build_ability(ability_index, 0)]
	_charge_preview = Sprite2D.new()
	_charge_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_charge_preview.visible = false
	_player.add_child.call_deferred(_charge_preview)


func _build_ability(index: int, extra_index: int) -> AbilityData:
	var data: AbilityData = AbilityData.new()
	data.ability_index = index
	var shot_type: int = GameManager.get_ability_shot_type(index)
	if shot_type < 0:
		shot_type = AbilityData.ShotType.STANDARD
	var ability_cooldown: float = cooldown * pow(additional_ability_cooldown_multiplier, extra_index)
	data.apply_shot_type(shot_type, damage, ability_cooldown, projectile_speed)
	return data


func _physics_process(delta: float) -> void:
	var holding: bool = Input.is_action_pressed("fire")
	var aim_direction: Vector2 = _aim_direction()
	var chargers: Array[AbilityData] = []

	var rate_multiplier: float = _fire_rate_multiplier()

	for data in abilities:
		data.cooldown_remaining = maxf(data.cooldown_remaining - delta * rate_multiplier, 0.0)
		if data.shot_type == AbilityData.ShotType.CHARGE:
			chargers.append(data)
			continue
		if data.cooldown_remaining > 0.0 or not holding:
			continue
		_fire_ability(data, aim_direction)
		data.cooldown_remaining = data.cooldown

	_process_chargers(chargers, holding, aim_direction, delta)
	_update_charge_preview(aim_direction, delta)


func _process_chargers(chargers: Array[AbilityData], holding: bool, aim_direction: Vector2, delta: float) -> void:
	if chargers.is_empty():
		return
	var active: AbilityData = null
	for data in chargers:
		if data.charging:
			active = data
			break
	if active == null:
		if not holding:
			return
		active = _next_ready_charger(chargers)
		if active == null:
			return

	if holding:
		var was_full: bool = active.charging and active.is_fully_charged()
		active.charging = true
		active.charge_elapsed = minf(active.charge_elapsed + delta, active.charge_time)
		if not was_full and active.is_fully_charged():
			AudioManager.play_charge_ready()
		elif was_full and has_perk("overcharge"):
			var previous_step: int = _overcharge_step(active.overcharge_elapsed)
			active.overcharge_elapsed = minf(active.overcharge_elapsed + delta, ShotPerks.OVERCHARGE_TIME)
			var step: int = _overcharge_step(active.overcharge_elapsed)
			if step > previous_step:
				AudioManager.play_overcharge_tick()
				overcharge_ticked.emit(step)
		return

	_fire_ability(active, aim_direction)
	active.charging = false
	active.charge_elapsed = 0.0
	active.overcharge_elapsed = 0.0
	active.cooldown_remaining = active.cooldown
	_next_charge_slot = (chargers.find(active) + 1) % chargers.size()


func _overcharge_step(elapsed: float) -> int:
	return floori(elapsed / ShotPerks.OVERCHARGE_TICK_INTERVAL + 0.0001)


func _next_ready_charger(chargers: Array[AbilityData]) -> AbilityData:
	for offset in chargers.size():
		var data: AbilityData = chargers[(_next_charge_slot + offset) % chargers.size()]
		if data.cooldown_remaining <= 0.0:
			return data
	return null


func has_perk(perk_id: String) -> bool:
	return perks.has(perk_id)


func add_perk(perk_id: String) -> bool:
	if not ShotPerks.PERKS.has(perk_id):
		push_warning("[AbilityController] Buff especial desconhecido: %s." % perk_id)
		return false
	if perks.has(perk_id):
		return false
	perks.append(perk_id)
	return true


func _fire_rate_multiplier() -> float:
	if has_perk("momentum") and _player.is_moving():
		return 1.0 + ShotPerks.MOMENTUM_RATE_BONUS
	return 1.0


func _on_player_died() -> void:
	set_physics_process(false)
	if _charge_preview != null:
		_charge_preview.visible = false


func add_ability(index: int) -> void:
	for data in abilities:
		if data.ability_index == index:
			return
	abilities.append(_build_ability(index, abilities.size()))


func get_abilities() -> Array[AbilityData]:
	return abilities


func _aim_direction() -> Vector2:
	var direction: Vector2 = (_player.aim_position() - _player.global_position).normalized()
	if direction.is_zero_approx():
		return Vector2.LEFT if _player.sprite.flip_h else Vector2.RIGHT
	return direction


func _charging_ability() -> AbilityData:
	for data in abilities:
		if data.charging:
			return data
	return null


func _update_charge_preview(aim_direction: Vector2, delta: float) -> void:
	if _charge_preview == null:
		return
	var data: AbilityData = _charging_ability()
	if data == null:
		_charge_preview.visible = false
		_blink_clock = 0.0
		return

	if _preview_index != data.ability_index:
		_preview_index = data.ability_index
		_charge_preview.texture = GameManager.get_ability_texture(data.ability_index)
	_charge_preview.visible = true
	_charge_preview.position = aim_direction * spawn_offset
	_charge_preview.rotation = aim_direction.angle()
	_charge_preview.scale = Vector2.ONE * PROJECTILE_BASE_SCALE * data.shot_size()

	if not data.is_fully_charged():
		_charge_preview.modulate = Color(1.0, 1.0, 1.0, CHARGE_PREVIEW_ALPHA)
		return
	_blink_clock += delta
	var bright: bool = fmod(_blink_clock * CHARGE_BLINK_SPEED, 2.0) < 1.0
	_charge_preview.modulate = Color(1.0, 1.0, 1.0, 1.0 if bright else CHARGE_BLINK_ALPHA)


func _fire_ability(data: AbilityData, base_direction: Vector2) -> void:
	var texture: ImageTexture = GameManager.get_ability_texture(data.ability_index)
	var count: int = maxi(data.projectile_count, 1)
	var spread: float = deg_to_rad(FAN_SPREAD_DEGREES)

	AudioManager.play_shoot()

	for i in count:
		var angle_offset: float = (float(i) - float(count - 1) / 2.0) * spread
		var fire_direction: Vector2 = base_direction.rotated(angle_offset)

		var projectile: Projectile = PROJECTILE_SCENE.instantiate()
		projectile.configure(texture, fire_direction)
		projectile.damage = data.shot_damage()
		projectile.speed = data.projectile_speed
		projectile.pierce_remaining = data.shot_piercing()
		projectile.size_scale = data.shot_size()
		projectile.max_distance = data.shot_range
		projectile.homing_turn_rate = data.homing_turn_rate
		projectile.perks = perks
		projectile.fully_charged = data.shot_type == AbilityData.ShotType.CHARGE and data.is_fully_charged()
		if has_perk("ricochet"):
			projectile.ricochets_remaining = ShotPerks.ricochet_bounces(data.piercing)
		if has_perk("shards"):
			projectile.shard_count = ShotPerks.shard_count(count)
		if has_perk("critical") and randf() < ShotPerks.critical_chance(data.projectile_speed / projectile_speed):
			projectile.damage *= ShotPerks.CRIT_MULTIPLIER
			projectile.is_critical = true
		projectile.position = _player.global_position + fire_direction * spawn_offset

		var container: Node = get_tree().get_first_node_in_group("projectiles_container")
		if container == null:
			container = _player.get_parent()
		container.add_child(projectile)
