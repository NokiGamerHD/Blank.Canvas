extends Node

const ENEMY_SCENE: String = "res://scenes/enemies/enemy_base.tscn"
const PLAYER_SPOT: Vector2 = Vector2(1100.0, 1100.0)
const FAR: Vector2 = Vector2(500.0, 0.0)

var _arena: Arena = null
var _manager: WaveManager = null
var _failures: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_arena = load(GameManager.SCENE_ARENA).instantiate() as Arena
	_arena.arena_size = Vector2(2200.0, 2200.0)
	(_arena.get_node("WaveManager") as WaveManager).first_wave_delay = 9000.0
	add_child(_arena)
	_arena.paint_canvas.remove_from_group("paint_canvas")
	_arena.ability_controller.set_physics_process(false)
	_arena.player.max_hp = 100000.0
	_arena.player.current_hp = 100000.0
	_arena.player.global_position = PLAYER_SPOT
	_manager = _arena.wave_manager
	_manager.current_wave = 1
	_manager._spawn_timer.stop()
	await get_tree().process_frame
	await get_tree().process_frame

	await _check_same_color()
	await _check_mixed_colors()
	await _check_bump_rolls()
	await _check_boss_never_fuses()
	await _check_alive_cap()
	await _check_tier_cap()
	await _check_plain_trail()
	await _check_splash_and_sound()
	await _check_rewards()
	await _check_fused_tank_split()
	_check_ghost_keeps_color()

	print("falhas: %d" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _report(label: String, passed: bool, detail: String) -> void:
	if not passed:
		_failures += 1
	print("%s %s %s" % ["ok  " if passed else "FALHA", label, detail])


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _clear() -> void:
	for child in _arena.enemies_container.get_children():
		child.free()
	for child in _arena.drops_container.get_children():
		child.free()
	for child in _arena.get_node("Effects").get_children():
		child.free()
	_manager._alive = 0
	_arena.player.global_position = PLAYER_SPOT
	_arena.player.velocity = Vector2.ZERO


func _spawn(type: EnemyBase.EnemyType, offset: Vector2, frozen: bool = true) -> EnemyBase:
	var enemy: EnemyBase = _manager._spawn_enemy(type, PLAYER_SPOT + offset)
	enemy.set_physics_process(not frozen)
	return enemy


func _alive_enemies() -> int:
	var count: int = 0
	for child in _arena.enemies_container.get_children():
		var enemy: EnemyBase = child as EnemyBase
		if enemy != null and not enemy._is_dying:
			count += 1
	return count


func _same_bytes(a: Color, b: Color) -> bool:
	return absi(a.r8 - b.r8) <= 1 and absi(a.g8 - b.g8) <= 1 and absi(a.b8 - b.b8) <= 1


func _check_same_color() -> void:
	_clear()
	var first: EnemyBase = _spawn(EnemyBase.EnemyType.STALKER, FAR)
	var second: EnemyBase = _spawn(EnemyBase.EnemyType.STALKER, FAR + Vector2(20.0, 0.0))
	var hp_sum: float = first.max_hp + second.max_hp
	var radius: float = first.collision_radius
	var color: Color = first.trail_color
	var speed: float = first.speed
	var survivor: EnemyBase = first.fuse_with(second)
	await _wait(0.3)
	var aura: FusionAura = survivor.fusion_aura()
	var foam: bool = aura != null and is_instance_valid(aura) and aura.aura_color.is_equal_approx(color) \
		and aura.bubble_count() > 0 and aura.bolt_count() == 0
	var passed: bool = survivor.fusion_tier == 1 and survivor.is_in_group(EnemyBase.FUSION_GROUP) and foam \
		and is_equal_approx(survivor.max_hp, hp_sum * EnemyBase.FUSION_HP_BONUS) \
		and is_equal_approx(survivor.collision_radius, radius * EnemyBase.FUSION_SIZE_STEP) \
		and survivor.trail_color == color and not survivor.fusion_tinted and survivor.sprite.material == null \
		and is_equal_approx(survivor.speed, speed) \
		and _alive_enemies() == 1 and _manager._alive == 1
	_report("dois amarelos se fundem num maior e mais forte, com espuma amarela em volta",
		passed,
		"nivel=%d espuma_na_cor=%s bolhas=%d raios=%d vida=%.1f (esperado %.1f) raio=%.1f vivos=%d contagem_da_wave=%d" % [
			survivor.fusion_tier, foam, aura.bubble_count() if aura != null else -1,
			aura.bolt_count() if aura != null else -1, survivor.max_hp, hp_sum * EnemyBase.FUSION_HP_BONUS,
			survivor.collision_radius, _alive_enemies(), _manager._alive
		])
	_clear()


func _check_mixed_colors() -> void:
	_clear()
	var red: EnemyBase = _spawn(EnemyBase.EnemyType.COMMON, FAR)
	var blue: EnemyBase = _spawn(EnemyBase.EnemyType.FAST, FAR + Vector2(20.0, 0.0))
	var fastest: float = maxf(red.speed, blue.speed)
	var expected: Color = PaintCanvas.mix_colors(PaintCanvas.flatten(red.trail_color), PaintCanvas.flatten(blue.trail_color))
	var survivor: EnemyBase = blue.fuse_with(red)
	await _wait(0.3)
	var material: ShaderMaterial = survivor.sprite.material as ShaderMaterial
	var hue: float = material.get_shader_parameter("target_hue") if material != null else -1.0
	var aura: FusionAura = survivor.fusion_aura()
	var boost: float = material.get_shader_parameter("saturation_boost") if material != null else 0.0
	var passed: bool = survivor == red and survivor.enemy_type == EnemyBase.EnemyType.COMMON \
		and _same_bytes(survivor.trail_color, expected) and survivor.fusion_tinted \
		and material != null and is_equal_approx(hue, expected.h) and boost > 0.0 \
		and survivor.speed >= fastest * EnemyBase.FUSION_SPEED_BONUS - 0.01 \
		and aura != null and _same_bytes(aura.aura_color, expected) and _alive_enemies() == 1
	_report("vermelho e azul viram um vermelho roxo, maior, mais forte e mais rapido",
		passed,
		"sobrou=%s cor=%s (esperado %s) velocidade=%.0f (mais rapido era %.0f) tinta_no_sprite=%s" % [
			"vermelho" if survivor == red else "azul", survivor.trail_color.to_html(false),
			expected.to_html(false), survivor.speed, fastest, material != null
		])
	_clear()


func _check_bump_rolls() -> void:
	_clear()
	var first: EnemyBase = _spawn(EnemyBase.EnemyType.COMMON, FAR, false)
	var second: EnemyBase = _spawn(EnemyBase.EnemyType.COMMON, FAR + Vector2(10.0, 0.0), false)
	for enemy in [first, second]:
		enemy.fusion_chance = 1.0
		enemy._fusion_cooldown = 0.0
	await _wait(1.0)
	var fused: int = get_tree().get_nodes_in_group(EnemyBase.FUSION_GROUP).size()
	var bumped_into_one: bool = fused == 1 and _alive_enemies() == 1
	_clear()

	var third: EnemyBase = _spawn(EnemyBase.EnemyType.COMMON, FAR, false)
	var fourth: EnemyBase = _spawn(EnemyBase.EnemyType.COMMON, FAR + Vector2(10.0, 0.0), false)
	for enemy in [third, fourth]:
		enemy.fusion_chance = 0.0
		enemy._fusion_cooldown = 0.0
	await _wait(0.5)
	var no_luck: bool = get_tree().get_nodes_in_group(EnemyBase.FUSION_GROUP).is_empty() and _alive_enemies() == 2
	var cooled: bool = third._fusion_cooldown > EnemyBase.FUSION_COOLDOWN - 0.6 \
		and fourth._fusion_cooldown > EnemyBase.FUSION_COOLDOWN - 0.6
	_report("a fusao sai de uma batida de verdade, e cada batida so rola a chance uma vez",
		bumped_into_one and no_luck and cooled and EnemyBase.FUSION_CHANCE < 0.5,
		"com_chance_1=%s sem_sorte_nao_funde=%s espera_depois_de_rolar=%s chance_normal=%.0f%%" % [
			bumped_into_one, no_luck, cooled, EnemyBase.FUSION_CHANCE * 100.0
		])
	_clear()


func _check_boss_never_fuses() -> void:
	_clear()
	var boss: EnemyBase = _spawn(EnemyBase.EnemyType.BOSS, FAR, false)
	var small: EnemyBase = _spawn(EnemyBase.EnemyType.COMMON, FAR + Vector2(-60.0, 0.0), false)
	for enemy in [boss, small]:
		enemy.fusion_chance = 1.0
		enemy._fusion_cooldown = 0.0
	await _wait(1.0)
	var passed: bool = get_tree().get_nodes_in_group(EnemyBase.FUSION_GROUP).is_empty() \
		and not boss.can_fuse() and is_instance_valid(small) and not small._is_dying
	_report("o chefe nunca se funde", passed,
		"fundidos=%d chefe_pode=%s" % [get_tree().get_nodes_in_group(EnemyBase.FUSION_GROUP).size(), boss.can_fuse()])
	_clear()


func _check_alive_cap() -> void:
	_clear()
	for index in EnemyBase.FUSION_MAX_ALIVE:
		var spot: Vector2 = Vector2(-500.0, -300.0 + 150.0 * index)
		var a: EnemyBase = _spawn(EnemyBase.EnemyType.FAST, spot)
		var b: EnemyBase = _spawn(EnemyBase.EnemyType.FAST, spot + Vector2(20.0, 0.0))
		a.fuse_with(b)
	await _wait(0.3)
	var first: EnemyBase = _spawn(EnemyBase.EnemyType.COMMON, FAR, false)
	var second: EnemyBase = _spawn(EnemyBase.EnemyType.COMMON, FAR + Vector2(10.0, 0.0), false)
	for enemy in [first, second]:
		enemy.fusion_chance = 1.0
		enemy._fusion_cooldown = 0.0
	await _wait(1.0)
	var fused: int = get_tree().get_nodes_in_group(EnemyBase.FUSION_GROUP).size()
	_report("nunca passa de %d fundidos vivos ao mesmo tempo" % EnemyBase.FUSION_MAX_ALIVE,
		fused == EnemyBase.FUSION_MAX_ALIVE and not first._is_dying and not second._is_dying,
		"fundidos=%d" % fused)
	_clear()


func _check_tier_cap() -> void:
	_clear()
	var a: EnemyBase = _spawn(EnemyBase.EnemyType.COMMON, FAR)
	var b: EnemyBase = _spawn(EnemyBase.EnemyType.COMMON, FAR + Vector2(20.0, 0.0))
	var c: EnemyBase = _spawn(EnemyBase.EnemyType.COMMON, FAR + Vector2(40.0, 0.0))
	var tier_one: EnemyBase = a.fuse_with(b)
	await _wait(0.3)
	var calm: bool = tier_one.fusion_aura().bolt_count() == 0
	var tier_two: EnemyBase = tier_one.fuse_with(c)
	await _wait(0.3)
	var bigger_aura: bool = calm and tier_two.fusion_aura().tier == 2 and tier_two.fusion_aura().bolt_count() > 0
	var d: EnemyBase = _spawn(EnemyBase.EnemyType.COMMON, FAR + Vector2(0.0, 80.0), false)
	tier_two.set_physics_process(true)
	for enemy in [tier_two, d]:
		enemy.fusion_chance = 1.0
		enemy._fusion_cooldown = 0.0
	d.global_position = tier_two.global_position + Vector2(10.0, 0.0)
	await _wait(1.0)
	var passed: bool = tier_two.fusion_tier == EnemyBase.FUSION_MAX_TIER and bigger_aura \
		and is_instance_valid(d) and not d._is_dying and tier_two.fusion_tier == 2
	_report("fundido funde de novo ate o nivel %d, ganha raios, e para ai" % EnemyBase.FUSION_MAX_TIER,
		passed, "nivel=%d raios_so_no_nivel_2=%s terceiro_ficou_de_fora=%s" % [
			tier_two.fusion_tier, bigger_aura, is_instance_valid(d) and not d._is_dying])
	_clear()


func _check_plain_trail() -> void:
	_clear()
	var canvas: PaintCanvas = _arena.paint_canvas
	canvas.add_to_group("paint_canvas")
	var red: EnemyBase = _spawn(EnemyBase.EnemyType.COMMON, FAR)
	var blue: EnemyBase = _spawn(EnemyBase.EnemyType.FAST, FAR + Vector2(20.0, 0.0))
	var mixed: EnemyBase = red.fuse_with(blue)
	await _wait(0.3)
	var start: Vector2 = PLAYER_SPOT + Vector2(0.0, -500.0)
	mixed._last_paint_position = start
	mixed.global_position = start + Vector2(120.0, 0.0)
	mixed._paint_trail()
	var middle: Vector2 = start + Vector2(60.0, 0.0)
	var footing: int = canvas.footing_at(middle)
	var painted: Color = canvas.color_at(middle)
	canvas.remove_from_group("paint_canvas")
	_report("fundido pinta rastro normal na cor misturada, sem acelerar o jogador",
		footing == PaintCanvas.Footing.FRESH and _same_bytes(painted, PaintCanvas.flatten(mixed.trail_color)),
		"chao=%d (fresco=%d) cor_no_chao=%s cor_do_fundido=%s" % [
			footing, PaintCanvas.Footing.FRESH, painted.to_html(false), mixed.trail_color.to_html(false)])
	_clear()


func _check_splash_and_sound() -> void:
	_clear()
	var canvas: PaintCanvas = _arena.paint_canvas
	canvas.add_to_group("paint_canvas")
	var mixes_before: int = canvas.mix_count()
	AudioManager._last_played.erase(AudioManager.ENEMY_MERGE_SOUND)
	var red: EnemyBase = _spawn(EnemyBase.EnemyType.COMMON, Vector2(0.0, 400.0))
	var yellow: EnemyBase = _spawn(EnemyBase.EnemyType.STALKER, Vector2(24.0, 400.0))
	red.fuse_with(yellow)
	var mixed_pixels: int = canvas.mix_count() - mixes_before
	var sounded: bool = AudioManager._last_played.has(AudioManager.ENEMY_MERGE_SOUND)
	canvas.remove_from_group("paint_canvas")
	_report("a fusao espirra as duas cores no chao, misturando no meio, e toca o som dela",
		mixed_pixels > 1000 and sounded, "pixels_misturados=%d som=%s" % [mixed_pixels, sounded])
	await _wait(0.3)
	_clear()


func _check_rewards() -> void:
	_clear()
	var counts: Array[int] = []
	for tier in [1, 2]:
		var a: EnemyBase = _spawn(EnemyBase.EnemyType.COMMON, FAR)
		var b: EnemyBase = _spawn(EnemyBase.EnemyType.COMMON, FAR + Vector2(20.0, 0.0))
		var fused: EnemyBase = a.fuse_with(b)
		if tier == 2:
			var c: EnemyBase = _spawn(EnemyBase.EnemyType.COMMON, FAR + Vector2(40.0, 0.0))
			fused = fused.fuse_with(c)
		await _wait(0.3)
		var before: int = _arena.drops_container.get_child_count()
		fused._die()
		counts.append(_arena.drops_container.get_child_count() - before)
		await _wait(0.3)
		_clear()
	_report("fundido sempre solta gota: nivel 1 solta 2, nivel 2 solta 3",
		counts[0] == 2 and counts[1] == 3, "nivel_1=%d nivel_2=%d" % [counts[0], counts[1]])


func _check_fused_tank_split() -> void:
	_clear()
	var green: EnemyBase = _spawn(EnemyBase.EnemyType.TANK, FAR)
	var red: EnemyBase = _spawn(EnemyBase.EnemyType.COMMON, FAR + Vector2(40.0, 0.0))
	var fused: EnemyBase = green.fuse_with(red)
	var color: Color = fused.trail_color
	var children: Array[EnemyBase] = []
	fused.split_into.connect(func(child: EnemyBase) -> void: children.append(child))
	await _wait(0.3)
	fused.take_damage(20.0, false)
	await get_tree().process_frame
	await get_tree().process_frame
	var kept: bool = children.size() == 2
	for child in children:
		kept = kept and _same_bytes(child.trail_color, color) and child.fusion_tinted \
			and child.sprite.material != null and child.fusion_tier == 0
	_report("verde fundido com vermelho divide em filhotes da mesma cor misturada",
		fused == green and kept, "sobrou_o_verde=%s filhotes=%d mantiveram_a_cor=%s" % [fused == green, children.size(), kept])
	_clear()


func _check_ghost_keeps_color() -> void:
	_clear()
	var red: EnemyBase = _spawn(EnemyBase.EnemyType.COMMON, FAR)
	var blue: EnemyBase = _spawn(EnemyBase.EnemyType.FAST, FAR + Vector2(20.0, 0.0))
	var fused: EnemyBase = red.fuse_with(blue)
	fused._ghost_countdown = 0.0
	fused._spawn_dash_ghost(0.1)
	var ghost_tinted: bool = false
	for child in _arena.get_node("Effects").get_children():
		var ghost: Sprite2D = child as Sprite2D
		if ghost != null and ghost.material == fused.sprite.material:
			ghost_tinted = true
	_report("o fantasma do dash do fundido sai na cor misturada", ghost_tinted, "fantasma_tingido=%s" % ghost_tinted)
	_clear()
