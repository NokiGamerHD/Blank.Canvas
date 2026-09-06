extends Node

const LIVE_SECONDS: float = 25.0

var _arena: Arena = null
var _player: Player = null
var _pinned_position: Vector2 = Vector2.ZERO
var _margin: float = 0.0
var _min_spawn_distance: float = 0.0
var _outside_frames: int = 0
var _worst_depth: float = 0.0
var _spawn_min_distance: float = INF
var _spawns_seen: int = 0
var _spawns_on_margin: int = 0
var _spawns_too_close: int = 0
var _escaped: Dictionary = {}
var _peak_alive: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_arena = load(GameManager.SCENE_ARENA).instantiate() as Arena
	var manager: WaveManager = _arena.get_node("WaveManager") as WaveManager
	manager.first_wave_delay = 0.2
	manager.base_enemies_per_wave = 160
	manager.base_spawn_interval = 0.03
	_margin = manager.arena_margin
	_min_spawn_distance = manager.min_spawn_distance
	add_child(_arena)

	_arena.paint_canvas.remove_from_group("paint_canvas")
	_arena.ability_controller.set_physics_process(false)

	_player = _arena.player
	_player.max_hp = 1000000.0
	_player.current_hp = 1000000.0
	_pinned_position = Vector2(26.0, 26.0)
	_player.global_position = _pinned_position

	_arena.enemies_container.child_entered_tree.connect(_on_enemy_spawned)

	await get_tree().create_timer(LIVE_SECONDS).timeout
	_report()
	get_tree().quit()


func _physics_process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	_player.global_position = _pinned_position
	_player.velocity = Vector2.ZERO

	_peak_alive = maxi(_peak_alive, _arena.enemies_container.get_child_count())
	for child in _arena.enemies_container.get_children():
		var enemy: EnemyBase = child as EnemyBase
		if enemy == null:
			continue
		var depth: float = _outside_depth(enemy.global_position)
		if depth > 0.0:
			_outside_frames += 1
			_worst_depth = maxf(_worst_depth, depth)
			_escaped[enemy.get_instance_id()] = true


func _outside_depth(point: Vector2) -> float:
	var over_left: float = -point.x
	var over_top: float = -point.y
	var over_right: float = point.x - _arena.arena_size.x
	var over_bottom: float = point.y - _arena.arena_size.y
	return maxf(maxf(over_left, over_top), maxf(over_right, over_bottom))


func _on_enemy_spawned(node: Node) -> void:
	var enemy: EnemyBase = node as EnemyBase
	if enemy == null:
		return
	_spawns_seen += 1
	var distance: float = enemy.position.distance_to(_pinned_position)
	_spawn_min_distance = minf(_spawn_min_distance, distance)
	if is_equal_approx(enemy.position.x, _margin):
		_spawns_on_margin += 1
	if distance < _min_spawn_distance:
		_spawns_too_close += 1


func _report() -> void:
	var percent_margin: float = 0.0
	var percent_close: float = 0.0
	if _spawns_seen > 0:
		percent_margin = 100.0 * _spawns_on_margin / float(_spawns_seen)
		percent_close = 100.0 * _spawns_too_close / float(_spawns_seen)

	print("RESULTADO jogador no canto (26,26), sem atacar, %.0f s" % LIVE_SECONDS)
	print("  spawns observados          : %d" % _spawns_seen)
	print("  grudados na linha x=%.0f    : %d (%.1f%%)" % [_margin, _spawns_on_margin, percent_margin])
	print("  mais perto que %.0f px      : %d (%.1f%%)" % [_min_spawn_distance, _spawns_too_close, percent_close])
	print("  spawn mais proximo         : %.1f px" % _spawn_min_distance)
	print("  frames com inimigo fora    : %d" % _outside_frames)
	print("  profundidade max na parede : %.1f px" % _worst_depth)
	print("  inimigos distintos fora    : %d" % _escaped.size())
	print("  pico de inimigos vivos     : %d" % _peak_alive)
