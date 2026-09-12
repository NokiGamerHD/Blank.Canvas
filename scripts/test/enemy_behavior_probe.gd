extends Node

const ENEMY_SCENE: String = "res://scenes/enemies/enemy_base.tscn"
const PLAYER_SPOT: Vector2 = Vector2(600.0, 600.0)
const SAMPLE_INTERVAL: float = 0.05
const BASE_SHOT_DAMAGE: float = 20.0

var _arena: Arena = null
var _player: Player = null
var _failures: int = 0
var _alive: int = 0
var _born: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_arena = load(GameManager.SCENE_ARENA).instantiate() as Arena
	_arena.arena_size = Vector2(1200.0, 1200.0)
	var manager: WaveManager = _arena.get_node("WaveManager") as WaveManager
	manager.first_wave_delay = 9000.0
	add_child(_arena)

	_arena.paint_canvas.remove_from_group("paint_canvas")
	_arena.ability_controller.set_physics_process(false)
	_player = _arena.player
	_player.max_hp = 1000000.0
	_player.current_hp = 1000000.0

	await get_tree().process_frame
	await get_tree().process_frame

	await _check_orbit()
	await _check_crowd_dash()
	await _check_lonely_dash()
	await _check_shove()
	await _check_zigzag()
	await _check_red_dash()
	await _check_split_tree()
	await _check_split_children_shrink()
	await _check_explosion_damage()
	await _check_explosion_paint()

	print("falhas: %d" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _report(label: String, passed: bool, detail: String) -> void:
	if not passed:
		_failures += 1
	print("%s %s %s" % ["ok  " if passed else "FALHA", label, detail])


func _clear_enemies() -> void:
	for child in _arena.enemies_container.get_children():
		child.free()


func _spawn(type: int, spot: Vector2) -> EnemyBase:
	var enemy: EnemyBase = load(ENEMY_SCENE).instantiate()
	enemy.enemy_type = type
	_arena.enemies_container.add_child(enemy)
	enemy.set_arena_bounds(Rect2(Vector2.ZERO, _arena.arena_size))
	enemy.global_position = spot
	return enemy


func _pin_player() -> void:
	_player.global_position = PLAYER_SPOT
	_player.velocity = Vector2.ZERO


func _sample(enemy: EnemyBase, seconds: float) -> Array[Vector2]:
	var samples: Array[Vector2] = []
	var elapsed: float = 0.0
	var next_sample: float = 0.0
	while elapsed < seconds:
		_pin_player()
		await get_tree().physics_frame
		elapsed += get_physics_process_delta_time()
		if elapsed >= next_sample and is_instance_valid(enemy):
			next_sample += SAMPLE_INTERVAL
			samples.append(enemy.global_position)
	return samples


func _check_orbit() -> void:
	_clear_enemies()
	_pin_player()
	var yellow: EnemyBase = _spawn(EnemyBase.EnemyType.STALKER, PLAYER_SPOT + Vector2(360.0, 0.0))
	var samples: Array[Vector2] = await _sample(yellow, 4.0)

	var closest: float = INF
	var swept: float = 0.0
	var previous: float = (samples[0] - PLAYER_SPOT).angle()
	for point in samples:
		closest = minf(closest, point.distance_to(PLAYER_SPOT))
		var angle: float = (point - PLAYER_SPOT).angle()
		swept += absf(angle_difference(previous, angle))
		previous = angle

	var kept_distance: bool = closest > 90.0
	var circled: bool = swept > PI * 0.5
	_report("amarelo orbita", kept_distance and circled,
		"aproximacao_minima=%.0f (>90) volta=%.2f rad (>1.57)" % [closest, swept])


func _check_crowd_dash() -> void:
	_clear_enemies()
	_pin_player()
	var yellow: EnemyBase = _spawn(EnemyBase.EnemyType.STALKER, PLAYER_SPOT + Vector2(300.0, 0.0))
	yellow.dash_patience = 9000.0
	for i in 4:
		var angle: float = PI * 0.5 + PI * float(i) / 4.0
		_spawn(EnemyBase.EnemyType.FAST, PLAYER_SPOT + Vector2.from_angle(angle) * 130.0) \
			.set_physics_process(false)

	var samples: Array[Vector2] = await _sample(yellow, 3.0)
	_report("amarelo avanca com plateia", _peak_speed(samples) > yellow.speed * 1.8,
		"pico=%.0f andar=%.0f (paciencia desligada)" % [_peak_speed(samples), yellow.speed])


func _check_lonely_dash() -> void:
	_clear_enemies()
	_pin_player()
	var yellow: EnemyBase = _spawn(EnemyBase.EnemyType.STALKER, PLAYER_SPOT + Vector2(300.0, 0.0))
	yellow.dash_patience = 1.0
	var samples: Array[Vector2] = await _sample(yellow, 3.5)
	var closest: float = INF
	for point in samples:
		closest = minf(closest, point.distance_to(PLAYER_SPOT))
	_report("amarelo avanca sozinho apos a paciencia", closest < 60.0,
		"aproximacao_minima=%.0f (<60)" % closest)


func _check_shove() -> void:
	_clear_enemies()
	_pin_player()
	var yellow: EnemyBase = _spawn(EnemyBase.EnemyType.STALKER, PLAYER_SPOT + Vector2(300.0, 0.0))
	yellow.dash_patience = 9000.0
	yellow.set_physics_process(false)
	await get_tree().physics_frame

	var before: float = yellow.global_position.distance_to(PLAYER_SPOT)
	var pusher: EnemyBase = _spawn(EnemyBase.EnemyType.TANK, PLAYER_SPOT + Vector2(316.0, 0.0))
	pusher.set_physics_process(false)
	yellow.set_physics_process(true)

	var samples: Array[Vector2] = await _sample(yellow, 1.0)
	var after: float = samples[samples.size() - 1].distance_to(PLAYER_SPOT)
	_report("amarelo e empurrado pro jogador", after < before - 20.0,
		"antes=%.0f depois=%.0f" % [before, after])


func _check_zigzag() -> void:
	_clear_enemies()
	_pin_player()
	var start: Vector2 = PLAYER_SPOT + Vector2(620.0, 0.0)
	var red: EnemyBase = _spawn(EnemyBase.EnemyType.COMMON, start)
	red.dash_range = 0.0
	var samples: Array[Vector2] = await _sample(red, 4.0)

	var axis: Vector2 = (PLAYER_SPOT - start).normalized().orthogonal()
	var crossings: int = 0
	var peak: float = 0.0
	var previous_side: int = 0
	for point in samples:
		var lateral: float = (point - start).dot(axis)
		peak = maxf(peak, absf(lateral))
		if absf(lateral) < 4.0:
			continue
		var side: int = 1 if lateral > 0.0 else -1
		if previous_side != 0 and side != previous_side:
			crossings += 1
		previous_side = side
	_report("vermelho anda em zigue-zague", crossings >= 2 and peak > 15.0,
		"trocas_de_lado=%d (>=2) desvio_maximo=%.0f (>15)" % [crossings, peak])


func _check_red_dash() -> void:
	_clear_enemies()
	_pin_player()
	var red: EnemyBase = _spawn(EnemyBase.EnemyType.COMMON, PLAYER_SPOT + Vector2(300.0, 0.0))
	var samples: Array[Vector2] = await _sample(red, 2.5)

	_report("vermelho avanca com dash", _peak_speed(samples) > red.speed * 1.8,
		"pico=%.0f andar=%.0f" % [_peak_speed(samples), red.speed])


func _on_probe_died(_enemy: EnemyBase) -> void:
	_alive -= 1


func _on_probe_split(child: EnemyBase) -> void:
	_alive += 1
	_born += 1
	child.set_physics_process(false)
	child.died.connect(_on_probe_died)
	child.split_into.connect(_on_probe_split)


func _living_enemies() -> Array[EnemyBase]:
	var living: Array[EnemyBase] = []
	for child in _arena.enemies_container.get_children():
		var enemy: EnemyBase = child as EnemyBase
		if enemy != null and not enemy.is_queued_for_deletion():
			living.append(enemy)
	return living


func _check_split_tree() -> void:
	_clear_enemies()
	_pin_player()
	_alive = 1
	_born = 1

	var green: EnemyBase = _spawn(EnemyBase.EnemyType.TANK, PLAYER_SPOT + Vector2(500.0, 0.0))
	green.set_physics_process(false)
	green.died.connect(_on_probe_died)
	green.split_into.connect(_on_probe_split)

	for round in 8:
		var living: Array[EnemyBase] = _living_enemies()
		if living.is_empty():
			break
		for enemy in living:
			enemy.take_damage(BASE_SHOT_DAMAGE)
		await get_tree().physics_frame
		await get_tree().process_frame

	await get_tree().create_timer(0.4).timeout
	var settled: bool = _living_enemies().is_empty()
	_report("verde se divide e a contagem fecha", _born == 7 and _alive == 0 and settled,
		"nascidos=%d (esperado 7) vivos=%d (esperado 0) sobraram=%d" % [
			_born, _alive, _living_enemies().size()
		])


func _check_split_children_shrink() -> void:
	_clear_enemies()
	_pin_player()
	var green: EnemyBase = _spawn(EnemyBase.EnemyType.TANK, PLAYER_SPOT + Vector2(500.0, 0.0))
	green.set_physics_process(false)
	var parent_radius: float = green.collision_radius
	var parent_hp: float = green.current_hp

	green.take_damage(BASE_SHOT_DAMAGE)
	await get_tree().physics_frame
	await get_tree().process_frame

	var living: Array[EnemyBase] = _living_enemies()
	var two: bool = living.size() == 2
	var smaller: bool = two and living[0].collision_radius < parent_radius
	var halved: bool = two and living[0].current_hp < (parent_hp - BASE_SHOT_DAMAGE) * 0.6
	_report("filhotes nascem menores e com metade da vida", two and smaller and halved,
		"filhos=%d raio %.0f->%.0f vida %.0f->%.0f" % [
			living.size(), parent_radius,
			living[0].collision_radius if two else 0.0,
			parent_hp - BASE_SHOT_DAMAGE, living[0].current_hp if two else 0.0
		])


func _check_explosion_damage() -> void:
	_clear_enemies()
	_pin_player()
	_player.max_hp = 1000.0
	_player.current_hp = 1000.0

	var far: EnemyBase = _spawn(EnemyBase.EnemyType.TANK, PLAYER_SPOT + Vector2(500.0, 0.0))
	far.set_physics_process(false)
	far.take_damage(BASE_SHOT_DAMAGE)
	await get_tree().physics_frame
	var after_far: float = _player.current_hp

	_clear_enemies()
	_pin_player()
	var near: EnemyBase = _spawn(EnemyBase.EnemyType.TANK, PLAYER_SPOT + Vector2(40.0, 0.0))
	near.set_physics_process(false)
	near.take_damage(BASE_SHOT_DAMAGE)
	await get_tree().physics_frame
	var after_near: float = _player.current_hp

	_report("explosao machuca de perto e nao de longe",
		is_equal_approx(after_far, 1000.0) and after_near < after_far,
		"longe=%.0f (esperado 1000) perto=%.0f" % [after_far, after_near])


func _check_explosion_paint() -> void:
	_clear_enemies()
	_pin_player()
	_arena.paint_canvas.add_to_group("paint_canvas")
	await get_tree().physics_frame

	var spot: Vector2 = PLAYER_SPOT + Vector2(500.0, 0.0)
	var pixel: Vector2i = Vector2i(_arena.paint_canvas.to_local(spot) * _arena.paint_canvas.resolution_scale)
	var before: Color = _arena.paint_canvas.get_image_copy().get_pixelv(pixel)
	var green: EnemyBase = _spawn(EnemyBase.EnemyType.TANK, spot)
	green.set_physics_process(false)
	green.take_damage(BASE_SHOT_DAMAGE)
	await get_tree().physics_frame
	await get_tree().process_frame
	var after: Color = _arena.paint_canvas.get_image_copy().get_pixelv(pixel)

	_arena.paint_canvas.remove_from_group("paint_canvas")
	_report("explosao pinta o chao", not before.is_equal_approx(after),
		"antes=%s depois=%s" % [before.to_html(false), after.to_html(false)])


func _peak_speed(samples: Array[Vector2]) -> float:
	var fastest: float = 0.0
	for i in range(1, samples.size()):
		fastest = maxf(fastest, samples[i].distance_to(samples[i - 1]) / SAMPLE_INTERVAL)
	return fastest
