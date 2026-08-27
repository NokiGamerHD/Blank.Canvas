class_name AbilityController
extends Node

enum TargetMode { NEAREST, LOWEST_HP, FARTHEST, RANDOM, FIRST }

const PROJECTILE_SCENE: PackedScene = preload("res://scenes/abilities/projectile.tscn")

const FAN_SPREAD_DEGREES: float = 12.0

@export var target_mode: TargetMode = TargetMode.NEAREST

@export var cooldown: float = 1.2

@export var attack_range: float = 380.0

@export var damage: float = 20.0

@export var projectile_speed: float = 600.0

@export var ability_index: int = 0

@export var spawn_offset: float = 30.0

@export var additional_ability_cooldown_multiplier: float = 1.3

var abilities: Array[AbilityData] = []

var _player: Player = null


func _ready() -> void:
	_player = get_parent() as Player
	if _player == null:
		push_warning("[AbilityController] O parent não é um Player; controlador desativado.")
		set_physics_process(false)
		return
	_player.died.connect(_on_player_died)

	abilities = [_build_initial_ability()]


func _build_initial_ability() -> AbilityData:
	var data: AbilityData = AbilityData.new()
	data.ability_index = ability_index
	data.damage = damage
	data.cooldown = cooldown
	data.projectile_speed = projectile_speed
	data.attack_range = attack_range
	data.target_mode = target_mode
	return data


func _physics_process(delta: float) -> void:
	for data in abilities:
		data.cooldown_remaining = maxf(data.cooldown_remaining - delta, 0.0)
		if data.cooldown_remaining > 0.0:
			continue

		var target: EnemyBase = _select_target(data)
		if target == null:
			continue

		_fire_ability(data, target)
		data.cooldown_remaining = data.cooldown


func _on_player_died() -> void:
	set_physics_process(false)


func add_ability(index: int) -> void:
	for data in abilities:
		if data.ability_index == index:
			return
	var new_ability: AbilityData = AbilityData.new()
	new_ability.ability_index = index
	new_ability.damage = damage
	new_ability.projectile_speed = projectile_speed
	new_ability.attack_range = attack_range
	new_ability.target_mode = target_mode

	var extra_index: int = abilities.size()
	new_ability.cooldown = cooldown * pow(additional_ability_cooldown_multiplier, extra_index)

	abilities.append(new_ability)


func get_abilities() -> Array[AbilityData]:
	return abilities


func _select_target(data: AbilityData) -> EnemyBase:
	var origin: Vector2 = _player.global_position
	var candidates: Array[EnemyBase] = []
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy: EnemyBase = node as EnemyBase
		if enemy == null:
			continue
		if origin.distance_to(enemy.global_position) <= data.attack_range:
			candidates.append(enemy)

	if candidates.is_empty():
		return null

	match data.target_mode:
		TargetMode.NEAREST:
			return _pick_by_distance(candidates, origin, true)
		TargetMode.FARTHEST:
			return _pick_by_distance(candidates, origin, false)
		TargetMode.LOWEST_HP:
			return _pick_lowest_hp(candidates)
		TargetMode.RANDOM:
			return candidates.pick_random()
		TargetMode.FIRST:
			return candidates[0]
	return candidates[0]


func _pick_by_distance(candidates: Array[EnemyBase], origin: Vector2, nearest: bool) -> EnemyBase:
	var best: EnemyBase = candidates[0]
	var best_distance: float = origin.distance_squared_to(best.global_position)
	for enemy in candidates:
		var distance: float = origin.distance_squared_to(enemy.global_position)
		var is_better: bool = distance < best_distance if nearest else distance > best_distance
		if is_better:
			best = enemy
			best_distance = distance
	return best


func _pick_lowest_hp(candidates: Array[EnemyBase]) -> EnemyBase:
	var best: EnemyBase = candidates[0]
	for enemy in candidates:
		if enemy.current_hp < best.current_hp:
			best = enemy
	return best


func _fire_ability(data: AbilityData, target: EnemyBase) -> void:
	var base_direction: Vector2 = (target.global_position - _player.global_position).normalized()
	var texture: ImageTexture = GameManager.get_ability_texture(data.ability_index)
	var count: int = maxi(data.projectile_count, 1)
	var spread: float = deg_to_rad(FAN_SPREAD_DEGREES)

	for i in count:
		var angle_offset: float = (float(i) - float(count - 1) / 2.0) * spread
		var fire_direction: Vector2 = base_direction.rotated(angle_offset)

		var projectile: Projectile = PROJECTILE_SCENE.instantiate()
		projectile.configure(texture, fire_direction)
		projectile.damage = data.damage
		projectile.speed = data.projectile_speed
		projectile.pierce_remaining = data.piercing
		projectile.size_scale = data.size_scale
		projectile.position = _player.global_position + fire_direction * spawn_offset

		var container: Node = get_tree().get_first_node_in_group("projectiles_container")
		if container == null:
			container = _player.get_parent()
		container.add_child(projectile)
