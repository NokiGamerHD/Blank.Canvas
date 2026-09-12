class_name AbilityController
extends Node

const PROJECTILE_SCENE: PackedScene = preload("res://scenes/abilities/projectile.tscn")

const FAN_SPREAD_DEGREES: float = 12.0

@export var cooldown: float = 1.0

@export var damage: float = 20.0

@export var projectile_speed: float = 720.0

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
	return data


func _physics_process(delta: float) -> void:
	var wants_to_fire: bool = Input.is_action_pressed("fire")
	var aim_direction: Vector2 = _aim_direction()

	for data in abilities:
		data.cooldown_remaining = maxf(data.cooldown_remaining - delta, 0.0)
		if data.cooldown_remaining > 0.0 or not wants_to_fire:
			continue
		_fire_ability(data, aim_direction)
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

	var extra_index: int = abilities.size()
	new_ability.cooldown = cooldown * pow(additional_ability_cooldown_multiplier, extra_index)

	abilities.append(new_ability)


func get_abilities() -> Array[AbilityData]:
	return abilities


func _aim_direction() -> Vector2:
	var direction: Vector2 = (_player.aim_position() - _player.global_position).normalized()
	if direction.is_zero_approx():
		return Vector2.LEFT if _player.sprite.flip_h else Vector2.RIGHT
	return direction


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
		projectile.damage = data.damage
		projectile.speed = data.projectile_speed
		projectile.pierce_remaining = data.piercing
		projectile.size_scale = data.size_scale
		projectile.position = _player.global_position + fire_direction * spawn_offset

		var container: Node = get_tree().get_first_node_in_group("projectiles_container")
		if container == null:
			container = _player.get_parent()
		container.add_child(projectile)
