class_name WaveManager
extends Node

signal wave_changed(wave: int)
signal wave_completed(wave: int)
signal progression_due(wave: int)

const ENEMY_SCENE: PackedScene = preload("res://scenes/enemies/enemy_base.tscn")

@export var base_enemies_per_wave: int = 4

@export var enemies_increment_per_wave: int = 2

@export var waves_per_progression: int = 5

@export var hp_scale_per_wave: float = 0.08

@export var first_wave_delay: float = 2.0

@export var time_between_waves: float = 2.0

@export var base_spawn_interval: float = 0.45

@export var spawn_interval_decrease_per_wave: float = 0.02

@export var min_spawn_interval: float = 0.12

@export var min_spawn_distance: float = 450.0
@export var max_spawn_distance: float = 600.0

@export var arena_margin: float = 64.0

@export var spawn_attempts: int = 16

@export var common_weight_base: float = 0.50
@export var common_weight_per_wave: float = -0.008
@export var fast_weight_base: float = 0.30
@export var fast_weight_per_wave: float = 0.006
@export var stalker_weight_base: float = 0.14
@export var stalker_weight_per_wave: float = 0.003
@export var stalker_weight_max: float = 0.24
@export var tank_weight_base: float = 0.05
@export var tank_weight_per_wave: float = 0.002
@export var tank_weight_max: float = 0.12
@export var tank_unlock_wave: int = 6

@export var min_type_weight: float = 0.05

@export var enemies_container_path: NodePath

var current_wave: int = 0

var _to_spawn: int = 0
var _alive: int = 0
var _waiting_progression: bool = false
var _arena: Arena = null
var _enemies_container: Node = null
var _spawn_timer: Timer = null


func _ready() -> void:
	_arena = get_parent() as Arena
	_enemies_container = get_node(enemies_container_path)

	_spawn_timer = Timer.new()
	_spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	add_child(_spawn_timer)

	await get_tree().create_timer(first_wave_delay).timeout
	_start_wave(1)


func enemies_in_wave(wave: int) -> int:
	return base_enemies_per_wave + (wave - 1) * enemies_increment_per_wave


func _spawn_interval_for_wave(wave: int) -> float:
	var interval: float = base_spawn_interval - spawn_interval_decrease_per_wave * (wave - 1)
	return maxf(interval, min_spawn_interval)


func _start_wave(wave: int) -> void:
	current_wave = wave
	GameManager.set_wave_reached(wave)
	_to_spawn = enemies_in_wave(wave)
	_alive = 0
	wave_changed.emit(wave)
	_spawn_timer.wait_time = _spawn_interval_for_wave(wave)
	_spawn_timer.start()


func _on_spawn_timer_timeout() -> void:
	if _to_spawn <= 0:
		_spawn_timer.stop()
		return
	var player: Player = get_tree().get_first_node_in_group("player") as Player
	if player == null:
		return
	var type: EnemyBase.EnemyType = _pick_enemy_type()
	_spawn_enemy(type, _pick_spawn_position(player.global_position, _spawn_clearance(type)))
	_to_spawn -= 1
	if _to_spawn <= 0:
		_spawn_timer.stop()


func _on_enemy_split(child: EnemyBase) -> void:
	child.died.connect(_on_enemy_died)
	child.split_into.connect(_on_enemy_split)
	_alive += 1


func _on_enemy_died(_enemy: EnemyBase) -> void:
	_alive -= 1
	if _to_spawn <= 0 and _alive <= 0:
		_complete_wave()


func _complete_wave() -> void:
	wave_completed.emit(current_wave)
	if current_wave % waves_per_progression == 0:
		_waiting_progression = true
		progression_due.emit(current_wave)
		return
	await get_tree().create_timer(time_between_waves).timeout
	_start_wave(current_wave + 1)


func resume_after_progression() -> void:
	if not _waiting_progression:
		return
	_waiting_progression = false
	_start_next_wave_delayed()


func _start_next_wave_delayed() -> void:
	await get_tree().create_timer(time_between_waves).timeout
	_start_wave(current_wave + 1)


func _pick_enemy_type() -> EnemyBase.EnemyType:
	var weights: Dictionary = _type_weights()
	var total: float = 0.0
	for weight in weights.values():
		total += weight

	var roll: float = randf() * total
	for type in weights:
		roll -= weights[type]
		if roll <= 0.0:
			return type
	return EnemyBase.EnemyType.COMMON


func _type_weights() -> Dictionary:
	var elapsed: int = current_wave - 1
	var weights: Dictionary = {
		EnemyBase.EnemyType.COMMON:
			maxf(common_weight_base + common_weight_per_wave * elapsed, min_type_weight),
		EnemyBase.EnemyType.FAST:
			maxf(fast_weight_base + fast_weight_per_wave * elapsed, min_type_weight),
		EnemyBase.EnemyType.STALKER:
			clampf(stalker_weight_base + stalker_weight_per_wave * elapsed,
				min_type_weight, stalker_weight_max),
	}
	if current_wave >= tank_unlock_wave:
		weights[EnemyBase.EnemyType.TANK] = clampf(
			tank_weight_base + tank_weight_per_wave * elapsed, min_type_weight, tank_weight_max
		)
	return weights


func _spawn_clearance(type: EnemyBase.EnemyType) -> float:
	return maxf(arena_margin, EnemyBase.PRESETS[type]["collision_radius"])


func _pick_spawn_position(player_position: Vector2, clearance: float) -> Vector2:
	var minimum: Vector2 = Vector2(clearance, clearance)
	var maximum: Vector2 = _arena.arena_size - minimum
	if minimum.x >= maximum.x or minimum.y >= maximum.y:
		push_warning("[WaveManager] Arena menor que a margem de spawn; usando o centro.")
		return _arena.arena_size / 2.0

	var start_angle: float = randf() * TAU
	for attempt in spawn_attempts:
		var angle: float = start_angle + TAU * float(attempt) / float(spawn_attempts)
		var distance: float = randf_range(min_spawn_distance, max_spawn_distance)
		var candidate: Vector2 = player_position + Vector2.from_angle(angle) * distance
		if _is_inside(candidate, minimum, maximum):
			return candidate

	return _farthest_position_inside(player_position, minimum, maximum)


func _is_inside(point: Vector2, minimum: Vector2, maximum: Vector2) -> bool:
	return point.x >= minimum.x and point.x <= maximum.x \
		and point.y >= minimum.y and point.y <= maximum.y


func _farthest_position_inside(player_position: Vector2, minimum: Vector2, maximum: Vector2) -> Vector2:
	var best: Vector2 = player_position.clamp(minimum, maximum)
	var best_distance: float = -1.0
	for attempt in spawn_attempts:
		var candidate: Vector2 = Vector2(
			randf_range(minimum.x, maximum.x),
			randf_range(minimum.y, maximum.y)
		)
		var distance: float = candidate.distance_squared_to(player_position)
		if distance > best_distance:
			best_distance = distance
			best = candidate
	return best


func _spawn_enemy(type: EnemyBase.EnemyType, spawn_position: Vector2) -> void:
	var enemy: EnemyBase = ENEMY_SCENE.instantiate()
	enemy.enemy_type = type
	enemy.position = spawn_position
	enemy.set_arena_bounds(Rect2(Vector2.ZERO, _arena.arena_size))
	enemy.died.connect(_on_enemy_died)
	enemy.split_into.connect(_on_enemy_split)
	_enemies_container.add_child(enemy)
	enemy.apply_wave_scaling(1.0 + hp_scale_per_wave * (current_wave - 1))
	_alive += 1
