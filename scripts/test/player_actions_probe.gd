extends Node

const ENEMY_SCENE: String = "res://scenes/enemies/enemy_base.tscn"
const PLAYER_SPOT: Vector2 = Vector2(600.0, 600.0)
const SAMPLE_INTERVAL: float = 0.02

var _arena: Arena = null
var _player: Player = null
var _controller: AbilityController = null
var _failures: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_arena = load(GameManager.SCENE_ARENA).instantiate() as Arena
	_arena.arena_size = Vector2(1200.0, 1200.0)
	var manager: WaveManager = _arena.get_node("WaveManager") as WaveManager
	manager.first_wave_delay = 9000.0
	add_child(_arena)

	_arena.paint_canvas.remove_from_group("paint_canvas")
	_player = _arena.player
	_controller = _arena.ability_controller
	_controller.set_physics_process(false)
	_player.max_hp = 1000000.0
	_player.current_hp = 1000000.0

	await get_tree().process_frame
	await get_tree().process_frame

	await _check_dash_moves()
	await _check_dash_key()
	await _check_dash_cooldown()
	await _check_invulnerability()
	await _check_dash_through_enemies()
	_check_dash_upgrade()
	await _check_aim_follows_cursor()
	await _check_no_fire_without_click()
	await _check_click_fires()
	_check_stronger_upgrades()
	_check_dash_upgrade_needs_player()

	print("falhas: %d" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _report(label: String, passed: bool, detail: String) -> void:
	if not passed:
		_failures += 1
	print("%s %s %s" % ["ok  " if passed else "FALHA", label, detail])


func _reset_player() -> void:
	for child in _arena.enemies_container.get_children():
		child.free()
	for child in _arena.projectiles_container.get_children():
		child.free()
	_player.global_position = PLAYER_SPOT
	_player.velocity = Vector2.ZERO


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _wait_for_dash_ready() -> void:
	await _wait(_player.dash_cooldown + 0.1)


func _check_dash_moves() -> void:
	_reset_player()
	var start: Vector2 = _player.global_position
	var started: bool = _player.try_dash(Vector2.RIGHT)
	var fastest: float = 0.0
	var previous: Vector2 = start
	var elapsed: float = 0.0
	while elapsed < _player.dash_duration + 0.1:
		await get_tree().physics_frame
		var step: float = get_physics_process_delta_time()
		elapsed += step
		fastest = maxf(fastest, _player.global_position.distance_to(previous) / step)
		previous = _player.global_position
	var travelled: float = _player.global_position.x - start.x
	_report("dash avanca rapido", started and travelled > 120.0 and fastest > _player.max_speed * 2.0,
		"comecou=%s distancia=%.0f (>120) pico=%.0f andar=%.0f" % [
			started, travelled, fastest, _player.max_speed
		])


func _check_dash_key() -> void:
	await _wait_for_dash_ready()
	_reset_player()
	Input.action_press("dash")
	var dashed: bool = false
	for i in 4:
		await get_tree().physics_frame
		dashed = dashed or _player.is_dashing()
	Input.action_release("dash")
	await _wait(_player.dash_duration + 0.05)
	_report("tecla de dash dispara o dash", dashed, "dashou=%s" % dashed)


func _check_dash_cooldown() -> void:
	await _wait_for_dash_ready()
	_reset_player()
	var first: bool = _player.try_dash(Vector2.UP)
	await _wait(_player.dash_duration + 0.05)
	var blocked: bool = not _player.try_dash(Vector2.UP)
	await _wait_for_dash_ready()
	var again: bool = _player.try_dash(Vector2.UP)
	await _wait(_player.dash_duration + 0.05)
	_report("dash respeita a recarga", first and blocked and again,
		"primeiro=%s bloqueado_logo_depois=%s liberado_apos_recarga=%s" % [first, blocked, again])


func _check_invulnerability() -> void:
	await _wait_for_dash_ready()
	_reset_player()
	var before: float = _player.current_hp
	_player.try_dash(Vector2.LEFT)
	await get_tree().physics_frame
	_player.take_damage(10.0)
	var during: float = _player.current_hp
	await _wait(_player.dash_duration + _player.dash_invulnerability_grace + 0.05)
	_player.take_damage(10.0)
	var after: float = _player.current_hp
	_report("dash da invencibilidade e ela acaba",
		is_equal_approx(during, before) and is_equal_approx(after, before - 10.0),
		"durante=%.0f (esperado %.0f) depois=%.0f (esperado %.0f)" % [
			before - during, 0.0, before - after, 10.0
		])


func _check_dash_through_enemies() -> void:
	await _wait_for_dash_ready()
	_reset_player()
	var wall_x: float = PLAYER_SPOT.x + 70.0
	for i in 7:
		var enemy: EnemyBase = load(ENEMY_SCENE).instantiate()
		enemy.enemy_type = EnemyBase.EnemyType.TANK
		enemy.position = Vector2(wall_x, PLAYER_SPOT.y + (float(i) - 3.0) * 40.0)
		_arena.enemies_container.add_child(enemy)
		enemy.set_physics_process(false)
	await get_tree().physics_frame

	_player.try_dash(Vector2.RIGHT)
	await _wait(_player.dash_duration + 0.02)
	var crossed: bool = _player.global_position.x > wall_x
	var mask_back: bool = _player.get_collision_mask_value(Player.ENEMY_LAYER_NUMBER)
	_report("dash atravessa uma parede de inimigos", crossed and mask_back,
		"x_final=%.0f parede=%.0f colisao_restaurada=%s" % [
			_player.global_position.x, wall_x, mask_back
		])


func _check_dash_upgrade() -> void:
	var screen: Node = _arena.progression_screen
	var original: float = _player.dash_cooldown
	screen._player = _player
	screen._apply_upgrade("dash", _controller.get_abilities()[0])
	var once: float = _player.dash_cooldown
	for i in 20:
		screen._apply_upgrade("dash", _controller.get_abilities()[0])
	var floor_value: float = _player.dash_cooldown
	_player.dash_cooldown = original
	_report("upgrade de dash reduz a recarga com piso",
		is_equal_approx(once, original * 0.7) and is_equal_approx(floor_value, Player.MIN_DASH_COOLDOWN),
		"%.2f -> %.2f, apos 21 upgrades %.2f (piso %.2f)" % [
			original, once, floor_value, Player.MIN_DASH_COOLDOWN
		])


func _living_projectiles() -> Array[Projectile]:
	var found: Array[Projectile] = []
	for child in _arena.projectiles_container.get_children():
		var projectile: Projectile = child as Projectile
		if projectile != null and not projectile.is_queued_for_deletion():
			found.append(projectile)
	return found


func _check_aim_follows_cursor() -> void:
	_reset_player()
	var bait: EnemyBase = load(ENEMY_SCENE).instantiate()
	bait.enemy_type = EnemyBase.EnemyType.TANK
	bait.position = PLAYER_SPOT + Vector2(250.0, 0.0)
	_arena.enemies_container.add_child(bait)
	bait.set_physics_process(false)

	_player.set_aim_override(PLAYER_SPOT + Vector2(0.0, -200.0))
	_controller.get_abilities()[0].cooldown_remaining = 0.0
	Input.action_press("fire")
	_controller.set_physics_process(true)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_controller.set_physics_process(false)
	Input.action_release("fire")

	var shots: Array[Projectile] = _living_projectiles()
	var direction: Vector2 = shots[0].direction if not shots.is_empty() else Vector2.ZERO
	_report("tiro vai para a mira, nao para o inimigo",
		not shots.is_empty() and direction.dot(Vector2.UP) > 0.99,
		"projeteis=%d direcao=%s inimigo_a_direita" % [shots.size(), direction])


func _check_no_fire_without_click() -> void:
	_reset_player()
	var bait: EnemyBase = load(ENEMY_SCENE).instantiate()
	bait.enemy_type = EnemyBase.EnemyType.TANK
	bait.position = PLAYER_SPOT + Vector2(150.0, 0.0)
	_arena.enemies_container.add_child(bait)
	bait.set_physics_process(false)
	_player.set_aim_override(bait.position)
	_controller.get_abilities()[0].cooldown_remaining = 0.0
	_controller.set_physics_process(true)
	await _wait(1.5)
	_controller.set_physics_process(false)
	var count: int = _living_projectiles().size()
	_report("nao atira sem clique, mesmo com inimigo perto", count == 0, "projeteis=%d" % count)


func _check_click_fires() -> void:
	_reset_player()
	_controller.get_abilities()[0].cooldown_remaining = 0.0
	Input.action_press("fire")
	_controller.set_physics_process(true)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_controller.set_physics_process(false)
	Input.action_release("fire")
	var count: int = _living_projectiles().size()
	_report("clique atira mesmo sem inimigo", count > 0, "projeteis=%d" % count)


func _check_stronger_upgrades() -> void:
	var screen: Node = _arena.progression_screen
	var data: AbilityData = AbilityData.new()
	var before: Array = [data.damage, data.cooldown, data.projectile_count, data.size_scale, data.piercing, data.projectile_speed]
	for upgrade in ["damage", "cooldown", "count", "size", "pierce", "speed"]:
		screen._apply_upgrade(upgrade, data)
	var after: Array = [data.damage, data.cooldown, data.projectile_count, data.size_scale, data.piercing, data.projectile_speed]
	var passed: bool = is_equal_approx(data.damage, 30.0) \
		and is_equal_approx(data.cooldown, 0.75) \
		and data.projectile_count == 3 \
		and is_equal_approx(data.size_scale, 1.5) \
		and data.piercing == 2 \
		and is_equal_approx(data.projectile_speed, 936.0)
	_report("upgrades mais fortes", passed, "antes=%s depois=%s" % [before, after])


func _check_dash_upgrade_needs_player() -> void:
	var screen: Node = _arena.progression_screen
	var dash_text: String = LocalizationManager.text("upgrade.dash")
	var seen_with_player: bool = false
	var seen_without_player: bool = false

	screen._abilities = _controller.get_abilities()
	for pass_index in 2:
		screen._player = _player if pass_index == 0 else null
		for i in 40:
			screen._build_upgrade_options()
			for child in screen.upgrade_options.get_children():
				var button: Button = child as Button
				if button == null or button.is_queued_for_deletion():
					continue
				if button.text.contains(dash_text):
					if pass_index == 0:
						seen_with_player = true
					else:
						seen_without_player = true
	_report("dash so aparece no sorteio com jogador", seen_with_player and not seen_without_player,
		"com_jogador=%s sem_jogador=%s" % [seen_with_player, seen_without_player])
