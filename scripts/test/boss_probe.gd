extends Node

const PLAYER_SPOT: Vector2 = Vector2(1100.0, 1100.0)
const BASE_SHOT_DAMAGE: float = 20.0
const HIT_INTERVAL: float = 0.05
const TREE_SECONDS: float = 6.0

var _arena: Arena = null
var _failures: int = 0
var _spawned: int = 0
var _died: int = 0


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
	await get_tree().process_frame
	await get_tree().process_frame

	_check_preset()
	_check_recolor()
	await _check_aura()
	await _check_split_tree()
	await _check_shards()
	_check_shards_are_wide()
	await _check_shard_reaches_the_wall()
	await _check_shard_hits_player()
	_check_shards_stop_by_generation()
	await _check_boss_wave()
	_check_big_explosions()
	await _check_explosion_shake()
	await _check_boss_bar()

	print("falhas: %d" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _report(label: String, passed: bool, detail: String) -> void:
	if not passed:
		_failures += 1
	print("%s %s %s" % ["ok  " if passed else "FALHA", label, detail])


func _clear() -> void:
	for child in _arena.enemies_container.get_children():
		child.free()
	for child in _arena.projectiles_container.get_children():
		child.free()
	_arena.player.global_position = PLAYER_SPOT
	_arena.player.velocity = Vector2.ZERO


func _spawn_boss(offset: Vector2, boss_generation: int = 0, hp: float = -1.0) -> EnemyBase:
	var boss: EnemyBase = load("res://scenes/enemies/enemy_base.tscn").instantiate() as EnemyBase
	boss.enemy_type = EnemyBase.EnemyType.BOSS
	boss.generation = boss_generation
	boss.spawn_hp = hp
	boss.position = PLAYER_SPOT + offset
	boss.set_arena_bounds(Rect2(Vector2.ZERO, _arena.arena_size))
	_arena.enemies_container.add_child(boss)
	return boss


func _living_shards() -> Array[BossShard]:
	var found: Array[BossShard] = []
	for child in _arena.projectiles_container.get_children():
		var shard: BossShard = child as BossShard
		if shard != null and not shard.is_queued_for_deletion():
			found.append(shard)
	return found


func _check_preset() -> void:
	var boss: Dictionary = EnemyBase.PRESETS[EnemyBase.EnemyType.BOSS]
	var tank: Dictionary = EnemyBase.PRESETS[EnemyBase.EnemyType.TANK]
	_report("chefe e o quadrado maior, de outra cor e que divide muito mais",
		boss["sheet"] == tank["sheet"]
			and boss["sprite_scale"] > tank["sprite_scale"] * 1.5
			and boss["collision_radius"] > tank["collision_radius"] * 1.5
			and boss["max_hp"] > tank["max_hp"] * 10.0
			and not boss["trail_color"].is_equal_approx(tank["trail_color"])
			and boss["split_generations"] > tank["split_generations"]
			and boss.get("boss", false) and boss.get("shard_count", 0) >= 8,
		"escala=%.2f (tanque %.2f) raio=%.0f vida=%.0f cor=%s geracoes=%d estilhacos=%d" % [
			boss["sprite_scale"], tank["sprite_scale"], boss["collision_radius"], boss["max_hp"],
			boss["trail_color"].to_html(false), boss["split_generations"], boss["shard_count"]
		])


func _check_recolor() -> void:
	var boss: EnemyBase = _spawn_boss(Vector2(400.0, 0.0))
	boss.set_physics_process(false)
	var frames: SpriteFrames = boss.sprite.sprite_frames
	var tank_frames: SpriteFrames = EnemyBase._get_sprite_frames(
		EnemyBase.EnemyType.TANK, EnemyBase.PRESETS[EnemyBase.EnemyType.TANK])
	var image: Image = frames.get_frame_texture("walk", 0).get_image()
	var target_hue: float = EnemyBase.PRESETS[EnemyBase.EnemyType.BOSS]["trail_color"].h

	var counts: Dictionary = {}
	var dark_kept: bool = true
	for y in image.get_height():
		for x in image.get_width():
			var pixel: Color = image.get_pixel(x, y)
			if pixel.a <= 0.0:
				continue
			if pixel.s < EnemyBase.RECOLOR_MIN_SATURATION:
				dark_kept = dark_kept and pixel.v < 0.2
				continue
			var key: int = Color(pixel.r, pixel.g, pixel.b).to_rgba32()
			counts[key] = counts.get(key, 0) + 1

	var shades: int = counts.size()
	var hue_ok: bool = shades > 0
	for key in counts:
		hue_ok = hue_ok and absf(Color.hex(key).h - target_hue) < 0.02
	_clear()
	_report("sprite do chefe e a do tanque recolorida, mantendo o contorno",
		hue_ok and dark_kept and shades >= 2 and frames != tank_frames,
		"tons_recoloridos=%d contorno_preservado=%s matiz_alvo=%.2f" % [shades, dark_kept, target_hue])


func _check_aura() -> void:
	var boss: EnemyBase = _spawn_boss(Vector2(400.0, 0.0))
	boss.set_physics_process(false)
	await get_tree().process_frame
	var aura: BossAura = boss.get_child(0) as BossAura
	var behind: bool = aura != null and aura.get_index() < boss.sprite.get_index()
	var pixelated: bool = aura != null and aura.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST \
		and is_equal_approx(aura.scale.x, float(BossAura.PIXEL_SCALE))
	var ring: bool = false
	var wide_enough: bool = false
	if aura != null:
		var image: Image = aura.texture.get_image()
		var middle: int = image.get_width() / 2
		ring = is_equal_approx(image.get_pixel(middle, middle).a, 0.0) \
			and image.get_pixel(middle, 0).a > 0.9
		wide_enough = image.get_width() * BossAura.PIXEL_SCALE > boss.collision_radius * 3.0
	_clear()
	_report("chefe tem aura de anel em pixel art atras do corpo",
		behind and pixelated and ring and wide_enough,
		"atras=%s pixelado=%s anel=%s cobre_o_corpo=%s" % [behind, pixelated, ring, wide_enough])


func _check_split_tree() -> void:
	_clear()
	_spawned = 0
	_died = 0
	var boss: EnemyBase = _spawn_boss(Vector2(520.0, 0.0))
	boss.set_physics_process(false)
	_track(boss)
	_spawned = 1

	var elapsed: float = 0.0
	while elapsed < TREE_SECONDS:
		for child in _arena.enemies_container.get_children():
			var enemy: EnemyBase = child as EnemyBase
			if enemy != null and not enemy.is_queued_for_deletion():
				enemy.set_physics_process(false)
				enemy.take_damage(BASE_SHOT_DAMAGE, false)
		await _wait(HIT_INTERVAL)
		elapsed += HIT_INTERVAL
		if _arena.enemies_container.get_child_count() == 0 and _died > 0:
			break

	var expected: int = 1
	var generations: int = EnemyBase.PRESETS[EnemyBase.EnemyType.BOSS]["split_generations"]
	for level in generations:
		expected += int(pow(2, level + 1))
	_clear()
	_report("a arvore do chefe fecha em %d inimigos e esvazia" % expected,
		_spawned == expected and _died == expected,
		"nasceram=%d morreram=%d sobraram=%d" % [_spawned, _died, _arena.enemies_container.get_child_count()])


func _track(enemy: EnemyBase) -> void:
	enemy.died.connect(func(_who: EnemyBase) -> void: _died += 1)
	enemy.split_into.connect(func(child: EnemyBase) -> void:
		_spawned += 1
		_track(child)
	)


func _check_shards() -> void:
	_clear()
	var boss: EnemyBase = _spawn_boss(Vector2(700.0, 0.0))
	boss.set_physics_process(false)
	boss.current_hp = 1.0
	boss.take_damage(BASE_SHOT_DAMAGE * 100.0, false)
	await get_tree().process_frame

	var shards: Array[BossShard] = _living_shards()
	var sum: Vector2 = Vector2.ZERO
	var same_color: bool = true
	var boss_color: Color = EnemyBase.PRESETS[EnemyBase.EnemyType.BOSS]["trail_color"]
	for shard in shards:
		sum += shard.direction
		same_color = same_color and shard.ink_color.is_equal_approx(Color(boss_color, 1.0))
	var expected: int = EnemyBase.PRESETS[EnemyBase.EnemyType.BOSS]["shard_count"]
	_report("explosao do chefe lanca estilhacos para todos os lados",
		shards.size() == expected and sum.length() < 0.2 and same_color,
		"estilhacos=%d (esperado %d) soma_das_direcoes=%.2f cor_do_chefe=%s" % [
			shards.size(), expected, sum.length(), same_color
		])

	_arena.paint_canvas.add_to_group("paint_canvas")
	var before: float = _arena.paint_canvas.coverage()
	await _wait(0.6)
	var after: float = _arena.paint_canvas.coverage()
	_arena.paint_canvas.remove_from_group("paint_canvas")
	_report("estilhaco do chefe deixa rastro de tinta", after > before,
		"pintado antes=%.5f depois=%.5f" % [before, after])
	_clear()


func _check_shards_are_wide() -> void:
	var width: int = BossShard.PATTERN[0].length() * BossShard.PIXEL_SCALE
	_report("estilhaco e largo e pinta rastro grosso",
		width >= 16 and BossShard.HIT_RADIUS >= 24.0 and BossShard.TRAIL_RADIUS >= 10.0,
		"lado=%d px raio_de_acerto=%.0f raio_do_rastro=%.0f" % [
			width, BossShard.HIT_RADIUS, BossShard.TRAIL_RADIUS
		])


func _check_shard_reaches_the_wall() -> void:
	_clear()
	var start: Vector2 = Vector2(_arena.arena_size.x - 500.0, PLAYER_SPOT.y - 400.0)
	var shard: BossShard = BossShard.new()
	shard.setup(Vector2.RIGHT, EnemyBase.PRESETS[EnemyBase.EnemyType.BOSS]["trail_color"],
		Rect2(Vector2.ZERO, _arena.arena_size))
	shard.position = start
	_arena.projectiles_container.add_child(shard)

	await _wait(0.9)
	var travelled: float = shard.global_position.x - start.x if is_instance_valid(shard) else -1.0
	var alive_past_old_life: bool = is_instance_valid(shard) and not shard.is_queued_for_deletion()
	await _wait(1.4)
	var gone_at_the_wall: bool = not is_instance_valid(shard) or shard.is_queued_for_deletion()
	_clear()
	_report("estilhaco viaja ate a parede em vez de sumir no tempo",
		alive_past_old_life and travelled > 250.0 and gone_at_the_wall,
		"andou=%.0f px vivo_depois_de_0,9s=%s sumiu_na_parede=%s" % [
			travelled, alive_past_old_life, gone_at_the_wall
		])


func _check_shard_hits_player() -> void:
	_clear()
	var player: Player = _arena.player
	var before: float = player.current_hp
	var shard: BossShard = BossShard.new()
	shard.setup(Vector2.RIGHT, EnemyBase.PRESETS[EnemyBase.EnemyType.BOSS]["trail_color"])
	shard.position = PLAYER_SPOT - Vector2(60.0, 0.0)
	_arena.projectiles_container.add_child(shard)
	await _wait(0.5)
	var hurt: bool = player.current_hp < before
	var gone: bool = not is_instance_valid(shard) or shard.is_queued_for_deletion()
	_clear()
	_report("estilhaco machuca o jogador e se gasta",
		hurt and gone and is_equal_approx(before - player.current_hp, BossShard.DAMAGE),
		"dano=%.0f (esperado %.0f) sumiu=%s" % [before - player.current_hp, BossShard.DAMAGE, gone])


func _check_shards_stop_by_generation() -> void:
	_clear()
	var deep: EnemyBase = _spawn_boss(Vector2(700.0, 0.0), 3, 40.0)
	deep.set_physics_process(false)
	deep._explode()
	var deep_shards: int = _living_shards().size()
	_clear()
	var first: EnemyBase = _spawn_boss(Vector2(700.0, 0.0), 1, 40.0)
	first.set_physics_process(false)
	first._explode()
	var first_shards: int = _living_shards().size()
	_clear()
	_report("so o chefe e o primeiro filhote lancam estilhacos",
		deep_shards == 0 and first_shards > 0,
		"geracao_3=%d geracao_1=%d" % [deep_shards, first_shards])


func _puff_count() -> int:
	var count: int = 0
	for child in _arena.get_node("Effects").get_children():
		if child.has_meta("explosion_puff"):
			count += 1
	return count


func _clear_puffs() -> void:
	for child in _arena.get_node("Effects").get_children():
		if child.has_meta("explosion_puff"):
			child.free()


func _check_big_explosions() -> void:
	_clear()
	_clear_puffs()
	var boss_preset: Dictionary = EnemyBase.PRESETS[EnemyBase.EnemyType.BOSS]
	var tank_preset: Dictionary = EnemyBase.PRESETS[EnemyBase.EnemyType.TANK]
	var boss: EnemyBase = _spawn_boss(Vector2(700.0, 0.0))
	boss.set_physics_process(false)
	boss._explode()
	var puffs: int = _puff_count()
	_clear_puffs()
	_clear()
	_report("explosao do chefe e bem maior que a do verde",
		boss_preset["explosion_paint_radius"] > tank_preset["explosion_paint_radius"] * 2.0
			and boss_preset["explosion_spatters"] > EnemyBase.EXPLOSION_SPATTERS * 2
			and puffs == boss_preset["explosion_puffs"],
		"tinta=%.0f (verde %.0f) respingos=%d (padrao %d) nuvens=%d" % [
			boss_preset["explosion_paint_radius"], tank_preset["explosion_paint_radius"],
			boss_preset["explosion_spatters"], EnemyBase.EXPLOSION_SPATTERS, puffs
		])


func _check_explosion_shake() -> void:
	_clear()
	var player: Player = _arena.player
	player.camera.offset = Vector2.ZERO
	var boss: EnemyBase = _spawn_boss(Vector2(700.0, 0.0))
	boss.set_physics_process(false)
	boss._explode()
	await get_tree().process_frame
	await get_tree().process_frame
	var shaken: Vector2 = player.camera.offset
	var whole_pixels: bool = is_equal_approx(shaken.x, roundf(shaken.x)) \
		and is_equal_approx(shaken.y, roundf(shaken.y))
	await _wait(0.8)
	var settled: bool = player.camera.offset.is_zero_approx()
	_clear()
	_clear_puffs()
	_report("explosao do chefe sacode a camera em pixels inteiros e volta ao lugar",
		not shaken.is_zero_approx() and whole_pixels and settled,
		"tremor=%s inteiro=%s voltou=%s" % [shaken, whole_pixels, settled])


func _check_boss_bar() -> void:
	_clear()
	var manager: WaveManager = _arena.get_node("WaveManager") as WaveManager
	var bar: BossHealthBar = _arena.hud.boss_bar()
	manager._start_wave(10)
	manager._spawn_timer.stop()
	await _wait(0.4)
	var showing: bool = bar != null and bar.is_showing()
	var full: float = bar.fill_width() if bar != null else 0.0

	for child in _arena.enemies_container.get_children():
		var enemy: EnemyBase = child as EnemyBase
		if enemy != null:
			enemy.set_physics_process(false)
			enemy.current_hp *= 0.4
	await _wait(0.4)
	var shrank: float = bar.fill_width() if bar != null else 0.0

	_clear()
	await _wait(0.7)
	var hidden: bool = bar != null and not bar.is_showing()
	_report("barra de vida do chefe aparece, encolhe e some no fim",
		showing and shrank < full and shrank > 0.0 and hidden,
		"cheia=%.0f px depois_do_dano=%.0f px sumiu=%s" % [full, shrank, hidden])


func _check_boss_wave() -> void:
	_clear()
	var manager: WaveManager = _arena.get_node("WaveManager") as WaveManager
	var marks: bool = manager.is_boss_wave(10) and manager.is_boss_wave(20) \
		and not manager.is_boss_wave(9) and not manager.is_boss_wave(11)
	var normal: int = manager.enemies_in_wave(9)
	var boss_wave: int = manager.enemies_in_wave(10)

	manager._start_wave(10)
	await get_tree().process_frame
	var bosses: int = 0
	for child in _arena.enemies_container.get_children():
		var enemy: EnemyBase = child as EnemyBase
		if enemy != null and enemy.enemy_type == EnemyBase.EnemyType.BOSS:
			bosses += 1
	manager._spawn_timer.stop()
	_clear()
	_report("wave 10 nasce so com o chefe, sem inimigos comuns",
		marks and bosses == 1 and boss_wave == 0 and normal > 0,
		"marca_10_e_20=%s chefes=%d inimigos wave9=%d wave10=%d" % [marks, bosses, normal, boss_wave])
