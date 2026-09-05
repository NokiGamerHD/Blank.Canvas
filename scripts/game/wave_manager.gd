class_name WaveManager
extends Node

signal wave_changed(wave: int)
signal wave_completed(wave: int)
signal progression_due(wave: int)

const ENEMY_SCENE: PackedScene = preload("res://scenes/enemies/enemy_base.tscn")

@export var base_enemies_per_wave: int = 4

@export var enemies_increment_per_wave: int = 3

@export var waves_per_progression: int = 5

@export var hp_scale_per_wave: float = 0.10

@export var first_wave_delay: float = 2.0

@export var time_between_waves: float = 3.0

@export var base_spawn_interval: float = 0.6

@export var spawn_interval_decrease_per_wave: float = 0.02

@export var min_spawn_interval: float = 0.15

@export var min_spawn_distance: float = 450.0
@export var max_spawn_distance: float = 600.0

@export var arena_margin: float = 64.0

@export var common_weight_base: float = 0.50
@export var common_weight_per_wave: float = -0.015
@export var fast_weight_base: float = 0.30
@export var fast_weight_per_wave: float = 0.006
@export var tank_weight_base: float = 0.20
@export var tank_weight_per_wave: float = 0.009
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
	_spawn_enemy(_pick_enemy_type(), _pick_spawn_position(player.global_position))
	_to_spawn -= 1
	if _to_spawn <= 0:
		_spawn_timer.stop()


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
	var elapsed: int = current_wave - 1
	var common_weight: float = maxf(common_weight_base + common_weight_per_wave * elapsed, min_type_weight)
	var fast_weight: float = maxf(fast_weight_base + fast_weight_per_wave * elapsed, min_type_weight)

	if current_wave < tank_unlock_wave:
		var early_total: float = common_weight + fast_weight
		var early_roll: float = randf() * early_total
		if early_roll < common_weight:
			return EnemyBase.EnemyType.COMMON
		return EnemyBase.EnemyType.FAST

	var tank_weight: float = maxf(tank_weight_base + tank_weight_per_wave * elapsed, min_type_weight)
	var total_weight: float = common_weight + fast_weight + tank_weight
	var roll: float = randf() * total_weight

	if roll < common_weight:
		return EnemyBase.EnemyType.COMMON
	elif roll < common_weight + fast_weight:
		return EnemyBase.EnemyType.FAST
	return EnemyBase.EnemyType.TANK


func _pick_spawn_position(player_position: Vector2) -> Vector2:
	var angle: float = randf() * TAU
	var distance: float = randf_range(min_spawn_distance, max_spawn_distance)
	var candidate: Vector2 = player_position + Vector2.from_angle(angle) * distance

	var minimum: Vector2 = Vector2(arena_margin, arena_margin)
	var maximum: Vector2 = _arena.arena_size - Vector2(arena_margin, arena_margin)
	return candidate.clamp(minimum, maximum)


func _spawn_enemy(type: EnemyBase.EnemyType, spawn_position: Vector2) -> void:
	var enemy: EnemyBase = ENEMY_SCENE.instantiate()
	enemy.enemy_type = type
	enemy.position = spawn_position
	enemy.died.connect(_on_enemy_died)
	_enemies_container.add_child(enemy)
	enemy.apply_wave_scaling(1.0 + hp_scale_per_wave * (current_wave - 1))
	_alive += 1
