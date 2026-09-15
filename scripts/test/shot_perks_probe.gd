extends Node

const ENEMY_SCENE: String = "res://scenes/enemies/enemy_base.tscn"
const PLAYER_SPOT: Vector2 = Vector2(300.0, 1500.0)
const BUTTON_TEXT_WIDTH: float = 280.0

var _arena: Arena = null
var _player: Player = null
var _controller: AbilityController = null
var _screen: Node = null
var _failures: int = 0
var _spawned: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_arena = load(GameManager.SCENE_ARENA).instantiate() as Arena
	_arena.arena_size = Vector2(3000.0, 3000.0)
	(_arena.get_node("WaveManager") as WaveManager).first_wave_delay = 9000.0
	add_child(_arena)
	_arena.paint_canvas.remove_from_group("paint_canvas")
	_player = _arena.player
	_controller = _arena.ability_controller
	_controller.set_physics_process(false)
	_player.max_hp = 1000000.0
	_player.current_hp = 1000000.0
	_screen = _arena.progression_screen
	_arena.projectiles_container.child_entered_tree.connect(func(_node: Node) -> void: _spawned += 1)
	await get_tree().process_frame
	await get_tree().process_frame

	_check_options_guarantee()
	_check_perk_taken_once()
	await _check_vampirism()
	await _check_ricochet()
	_check_critical()
	await _check_blast()
	await _check_shards()
	await _check_overcharge()
	await _check_overcharge_ticks()
	await _check_critical_sound()
	_check_repeated_sounds_throttled()
	await _check_poison()
	await _check_poison_visuals()
	await _check_focus()
	await _check_momentum()
	_check_texts_fit()

	print("falhas: %d" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _report(label: String, passed: bool, detail: String) -> void:
	if not passed:
		_failures += 1
	print("%s %s %s" % ["ok  " if passed else "FALHA", label, detail])


func _reset(shot_type: int) -> AbilityData:
	Input.action_release("fire")
	Input.action_release("move_right")
	_controller.set_physics_process(false)
	_controller.perks.clear()
	for child in _arena.enemies_container.get_children():
		child.free()
	for child in _arena.projectiles_container.get_children():
		child.free()
	_player.global_position = PLAYER_SPOT
	_player.velocity = Vector2.ZERO
	_player.set_aim_override(PLAYER_SPOT + Vector2(400.0, 0.0))
	var data: AbilityData = _controller.get_abilities()[0]
	data.apply_shot_type(shot_type, _controller.damage, _controller.cooldown, _controller.projectile_speed)
	data.cooldown_remaining = 0.0
	data.charge_elapsed = 0.0
	data.overcharge_elapsed = 0.0
	data.charging = false
	return data


func _enemy(type: int, offset: Vector2, frozen: bool = true) -> EnemyBase:
	var enemy: EnemyBase = load(ENEMY_SCENE).instantiate()
	enemy.enemy_type = type
	enemy.position = PLAYER_SPOT + offset
	_arena.enemies_container.add_child(enemy)
	if frozen:
		enemy.set_physics_process(false)
	return enemy


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _open_for(shot_type: int) -> void:
	_reset(shot_type)
	_screen._abilities = _controller.get_abilities()
	_screen._player = _player
	_screen._controller = _controller


func _option_ids() -> Array[String]:
	var ids: Array[String] = []
	for child in _screen.upgrade_options.get_children():
		var button: Button = child as Button
		if button != null and not button.is_queued_for_deletion():
			ids.append(button.get_meta("upgrade_id", ""))
	return ids


func _check_options_guarantee() -> void:
	var guaranteed: bool = true
	var foreign: bool = false
	var seen: Dictionary = {}
	for shot_type in [AbilityData.ShotType.STANDARD, AbilityData.ShotType.CHARGE, AbilityData.ShotType.RAPID]:
		_open_for(shot_type)
		var own: Array[String] = ShotPerks.perks_for(shot_type)
		for i in 30:
			_screen._build_upgrade_options()
			var ids: Array[String] = _option_ids()
			var perk_count: int = 0
			for id in ids:
				if not id.begins_with("perk:"):
					continue
				var perk: String = id.trim_prefix("perk:")
				seen[perk] = true
				perk_count += 1
				if not own.has(perk):
					foreign = true
			guaranteed = guaranteed and perk_count >= 1 and ids.size() == 3
	_report("toda tela de upgrade traz ao menos um especial do tipo certo",
		guaranteed and not foreign and seen.size() == ShotPerks.PERKS.size(),
		"garantido=%s de_outro_tipo=%s especiais_vistos=%d/%d" % [guaranteed, foreign, seen.size(), ShotPerks.PERKS.size()])


func _check_perk_taken_once() -> void:
	_open_for(AbilityData.ShotType.STANDARD)
	_screen._apply_upgrade("perk:vampirism", _controller.get_abilities()[0])
	var owned: bool = _controller.has_perk("vampirism")
	var reappeared: bool = false
	for i in 40:
		_screen._build_upgrade_options()
		reappeared = reappeared or _option_ids().has("perk:vampirism")
	_screen._apply_upgrade("perk:ricochet", _controller.get_abilities()[0])
	_screen._apply_upgrade("perk:critical", _controller.get_abilities()[0])
	var duplicate_refused: bool = not _controller.add_perk("critical") and _controller.perks.size() == 3
	var perks_after_all: int = 0
	for i in 20:
		_screen._build_upgrade_options()
		for id in _option_ids():
			if id.begins_with("perk:"):
				perks_after_all += 1
	_controller.perks.clear()
	_report("especial so pode ser pego uma vez",
		owned and not reappeared and duplicate_refused and perks_after_all == 0,
		"pegou=%s voltou_a_aparecer=%s recusou_repetido=%s especiais_depois_de_todos=%d" % [
			owned, reappeared, duplicate_refused, perks_after_all
		])


func _check_vampirism() -> void:
	var data: AbilityData = _reset(AbilityData.ShotType.STANDARD)
	_controller.add_perk("vampirism")
	_player.max_hp = 100.0
	_player.current_hp = 50.0
	var enemy: EnemyBase = _enemy(EnemyBase.EnemyType.TANK, Vector2(200.0, 0.0))
	var expected: float = minf(data.damage, enemy.max_hp * ShotPerks.VAMPIRISM_FRACTION)
	_controller._fire_ability(data, Vector2.RIGHT)
	await _wait(0.6)
	var healed: float = _player.current_hp - 50.0
	_player.max_hp = 1000000.0
	_player.current_hp = 1000000.0
	_report("vampirismo cura pela vida do inimigo", is_equal_approx(healed, expected),
		"curou=%.2f esperado=%.2f (%.0f%% de %.0f)" % [healed, expected, ShotPerks.VAMPIRISM_FRACTION * 100.0, 100.0])


func _check_ricochet() -> void:
	var data: AbilityData = _reset(AbilityData.ShotType.STANDARD)
	_controller.add_perk("ricochet")
	var first: EnemyBase = _enemy(EnemyBase.EnemyType.COMMON, Vector2(200.0, 0.0))
	var second: EnemyBase = _enemy(EnemyBase.EnemyType.COMMON, Vector2(260.0, 170.0))
	first.current_hp = 1000.0
	second.current_hp = 1000.0
	_controller._fire_ability(data, Vector2.RIGHT)
	await _wait(1.0)
	var first_hit: bool = first.current_hp < 1000.0
	var second_hit: bool = second.current_hp < 1000.0
	_report("ricochete quica para o proximo inimigo", first_hit and second_hit,
		"primeiro=%s segundo=%s quiques_base=%d" % [first_hit, second_hit, ShotPerks.ricochet_bounces(0)])


func _check_critical() -> void:
	var data: AbilityData = _reset(AbilityData.ShotType.STANDARD)
	_controller.add_perk("critical")
	var base_chance: float = ShotPerks.critical_chance(1.0)
	var faster_chance: float = ShotPerks.critical_chance(2.0)
	var capped: float = ShotPerks.critical_chance(10.0)
	for i in 200:
		_controller._fire_ability(data, Vector2.from_angle(randf() * TAU))
	var crits: int = 0
	var doubled: bool = true
	for child in _arena.projectiles_container.get_children():
		var projectile: Projectile = child as Projectile
		if projectile == null:
			continue
		if projectile.is_critical:
			crits += 1
			doubled = doubled and is_equal_approx(projectile.damage, data.damage * ShotPerks.CRIT_MULTIPLIER)
	_reset(AbilityData.ShotType.STANDARD)
	_report("critico escala com a velocidade do tiro",
		is_equal_approx(base_chance, ShotPerks.CRIT_BASE_CHANCE) and faster_chance > base_chance and is_equal_approx(capped, ShotPerks.CRIT_MAX_CHANCE) \
			and crits >= 25 and crits <= 80 and doubled,
		"chance base=%.2f com_2x_veloc=%.2f teto=%.2f criticos=%d/200 dano_dobrado=%s" % [
			base_chance, faster_chance, capped, crits, doubled
		])


func _check_blast() -> void:
	var data: AbilityData = _reset(AbilityData.ShotType.CHARGE)
	_controller.add_perk("explosion")
	var target: EnemyBase = _enemy(EnemyBase.EnemyType.COMMON, Vector2(150.0, 0.0))
	var near: EnemyBase = _enemy(EnemyBase.EnemyType.COMMON, Vector2(150.0, 90.0))
	var far: EnemyBase = _enemy(EnemyBase.EnemyType.COMMON, Vector2(150.0, 320.0))
	for enemy in [target, near, far]:
		enemy.current_hp = 1000.0
	data.charge_elapsed = data.charge_time
	_controller._fire_ability(data, Vector2.RIGHT)
	await _wait(0.5)
	var radius: float = ShotPerks.blast_radius(data.shot_size())
	_report("explosao da carga cheia acerta quem esta perto",
		target.current_hp < 1000.0 and near.current_hp < 1000.0 and is_equal_approx(far.current_hp, 1000.0),
		"alvo=%.0f perto=%.0f longe=%.0f raio=%.0f" % [target.current_hp, near.current_hp, far.current_hp, radius])


func _check_shards() -> void:
	var data: AbilityData = _reset(AbilityData.ShotType.CHARGE)
	_controller.add_perk("shards")
	var target: EnemyBase = _enemy(EnemyBase.EnemyType.COMMON, Vector2(150.0, 0.0))
	target.current_hp = 1000.0
	var before: int = _spawned
	_controller._fire_ability(data, Vector2.RIGHT)
	await _wait(0.5)
	var spawned: int = _spawned - before
	data.projectile_count = 3
	var with_more_shots: int = ShotPerks.shard_count(data.projectile_count)
	_report("estilhacos saem no acerto e escalam com os tiros",
		spawned == 1 + ShotPerks.shard_count(1) and with_more_shots > ShotPerks.shard_count(1),
		"projeteis=%d (1 tiro + %d estilhacos) com_3_tiros=%d" % [spawned, ShotPerks.shard_count(1), with_more_shots])


func _charged_damage(hold: float) -> float:
	Input.action_press("fire")
	_controller.set_physics_process(true)
	await _wait(hold)
	Input.action_release("fire")
	await get_tree().physics_frame
	await get_tree().physics_frame
	_controller.set_physics_process(false)
	var children: Array[Node] = _arena.projectiles_container.get_children()
	for index in range(children.size() - 1, -1, -1):
		var projectile: Projectile = children[index] as Projectile
		if projectile != null and not projectile.is_queued_for_deletion():
			return projectile.damage
	return 0.0


func _check_overcharge() -> void:
	_reset(AbilityData.ShotType.CHARGE)
	var plain: float = await _charged_damage(2.8)
	_reset(AbilityData.ShotType.CHARGE)
	_controller.add_perk("overcharge")
	var boosted: float = await _charged_damage(2.8)
	var expected: float = _controller.damage * AbilityData.CHARGE_MAX_DAMAGE * (1.0 + ShotPerks.OVERCHARGE_BONUS)
	_report("sobrecarga continua crescendo depois de cheio",
		absf(boosted - expected) < 0.5 and absf(plain - _controller.damage * AbilityData.CHARGE_MAX_DAMAGE) < 0.5,
		"sem=%.1f com=%.1f esperado=%.1f" % [plain, boosted, expected])


func _check_overcharge_ticks() -> void:
	var counts: Array[int] = []
	for with_perk in [true, false]:
		_reset(AbilityData.ShotType.CHARGE)
		if with_perk:
			_controller.add_perk("overcharge")
		var ticks: Array[int] = []
		var on_tick: Callable = func(step: int) -> void: ticks.append(step)
		_controller.overcharge_ticked.connect(on_tick)
		Input.action_press("fire")
		_controller.set_physics_process(true)
		await _wait(2.8)
		Input.action_release("fire")
		await get_tree().physics_frame
		await get_tree().physics_frame
		_controller.set_physics_process(false)
		_controller.overcharge_ticked.disconnect(on_tick)
		counts.append(ticks.size())
	var label_on_player: bool = false
	for child in _player.get_children():
		label_on_player = label_on_player or child is Label
	_report("sobrecarga toca tique de cronometro ate o maximo, sem numero na tela",
		counts[0] == 5 and counts[1] == 0 and not label_on_player,
		"tiques_com_buff=%d sem_buff=%d numero_na_tela=%s" % [counts[0], counts[1], label_on_player])


func _check_critical_sound() -> void:
	_reset(AbilityData.ShotType.STANDARD)
	var enemy: EnemyBase = _enemy(EnemyBase.EnemyType.COMMON, Vector2(160.0, 0.0))
	enemy.current_hp = 1000.0
	AudioManager._last_played.erase(AudioManager.CRITICAL_HIT_SOUND)
	var normal: Projectile = load("res://scenes/abilities/projectile.tscn").instantiate()
	normal.configure(null, Vector2.RIGHT)
	normal.position = PLAYER_SPOT + Vector2(40.0, 0.0)
	_arena.projectiles_container.add_child(normal)
	await _wait(0.4)
	var silent_on_normal: bool = not AudioManager._last_played.has(AudioManager.CRITICAL_HIT_SOUND)
	var yellow_on_normal: bool = _has_critical_number()
	var critical: Projectile = load("res://scenes/abilities/projectile.tscn").instantiate()
	critical.configure(null, Vector2.RIGHT)
	critical.is_critical = true
	critical.position = PLAYER_SPOT + Vector2(40.0, 0.0)
	_arena.projectiles_container.add_child(critical)
	await _wait(0.4)
	var played_on_critical: bool = AudioManager._last_played.has(AudioManager.CRITICAL_HIT_SOUND)
	var yellow_on_critical: bool = _has_critical_number()
	_report("critico toca som e mostra numero amarelo so no critico",
		silent_on_normal and played_on_critical and not yellow_on_normal and yellow_on_critical,
		"normal_em_silencio=%s critico_tocou=%s amarelo_no_normal=%s amarelo_no_critico=%s" % [
			silent_on_normal, played_on_critical, yellow_on_normal, yellow_on_critical
		])


func _has_critical_number() -> bool:
	var effects: Node = get_tree().get_first_node_in_group("effects_container")
	for child in effects.get_children():
		var number: DamageNumber = child as DamageNumber
		if number != null and number.label.get_theme_color("font_color").is_equal_approx(DamageNumber.CRITICAL_COLOR):
			return true
	return false


func _check_repeated_sounds_throttled() -> void:
	var results: Array[String] = []
	var passed: bool = true
	for entry in [["acerto", AudioManager.HIT_SOUND, AudioManager.play_hit], ["morte", AudioManager.ENEMY_DEATH_SOUND, AudioManager.play_enemy_death], ["explosao", AudioManager.ENEMY_EXPLODE_SOUND, AudioManager.play_enemy_explode]]:
		for player in AudioManager._players:
			player.stop()
		AudioManager._last_played.erase(entry[1])
		for i in 5:
			entry[2].call()
		var started: int = 0
		for player in AudioManager._players:
			if player.stream == entry[1] and player.playing:
				started += 1
		passed = passed and started <= 1
		results.append("%s=%d" % [entry[0], started])
	_report("som repetido no mesmo instante toca uma vez so", passed, " ".join(results) + " (5 chamadas cada)")


func _check_poison_visuals() -> void:
	_reset(AbilityData.ShotType.RAPID)
	_arena.paint_canvas.add_to_group("paint_canvas")
	var effects: Node = get_tree().get_first_node_in_group("effects_container")
	var enemy: EnemyBase = _enemy(EnemyBase.EnemyType.FAST, Vector2(600.0, 0.0), false)
	enemy.current_hp = 100000.0
	var start: Vector2 = enemy.global_position
	enemy.add_poison(0.01)
	var puffs_seen: int = 0
	for i in 10:
		await _wait(0.1)
		for child in effects.get_children():
			if child.has_meta("poison_puff") and not child.is_queued_for_deletion():
				puffs_seen = maxi(puffs_seen, puffs_seen + 1)
	var image: Image = _arena.paint_canvas.get_image_copy()
	var scale: float = _arena.paint_canvas.resolution_scale
	var from: Vector2 = _arena.paint_canvas.to_local(start) * scale
	var to: Vector2 = _arena.paint_canvas.to_local(enemy.global_position) * scale
	var purple: int = 0
	var box: Rect2i = Rect2i(Vector2i(mini(int(from.x), int(to.x)) - 8, mini(int(from.y), int(to.y)) - 8),
		Vector2i(absi(int(to.x) - int(from.x)) + 16, absi(int(to.y) - int(from.y)) + 16))
	for y in range(maxi(box.position.y, 0), mini(box.end.y, image.get_height())):
		for x in range(maxi(box.position.x, 0), mini(box.end.x, image.get_width())):
			var pixel: Color = image.get_pixel(x, y)
			if pixel.a > 0.5 and pixel.b > 0.6 and pixel.r > 0.4 and pixel.g < 0.45:
				purple += 1
	_arena.paint_canvas.remove_from_group("paint_canvas")
	enemy.set_physics_process(false)
	_report("veneno solta fumaca e pinta rastro roxo", puffs_seen > 0 and purple > 0,
		"fumacas_vistas=%d pixels_roxos_no_rastro=%d" % [puffs_seen, purple])


func _check_poison() -> void:
	var data: AbilityData = _reset(AbilityData.ShotType.RAPID)
	_controller.add_perk("poison")
	var enemy: EnemyBase = _enemy(EnemyBase.EnemyType.FAST, Vector2(200.0, 0.0))
	enemy.current_hp = 200.0
	_controller._fire_ability(data, Vector2.RIGHT)
	await _wait(0.4)
	var after_hit: float = enemy.current_hp
	var stacks: int = enemy.poison_stacks()
	await _wait(2.0)
	var after_poison: float = enemy.current_hp
	_report("veneno causa dano com o tempo",
		stacks == 1 and after_poison < after_hit - 2.0,
		"acumulos=%d vida_apos_acerto=%.1f dois_segundos_depois=%.1f" % [stacks, after_hit, after_poison])


func _check_focus() -> void:
	var data: AbilityData = _reset(AbilityData.ShotType.RAPID)
	_controller.add_perk("focus")
	var enemy: EnemyBase = _enemy(EnemyBase.EnemyType.COMMON, Vector2(200.0, 0.0))
	enemy.current_hp = 10000.0
	var losses: Array[float] = []
	for i in 5:
		var before: float = enemy.current_hp
		_controller._fire_ability(data, Vector2.RIGHT)
		await _wait(0.3)
		losses.append(before - enemy.current_hp)
	var expected_last: float = data.damage * (1.0 + ShotPerks.FOCUS_BONUS_PER_STACK * 4.0)
	_report("foco aumenta o dano a cada acerto no mesmo alvo",
		enemy.focus_stacks() == 5 and absf(losses[4] - expected_last) < 0.01 and losses[4] > losses[0],
		"acumulos=%d primeiro=%.2f quinto=%.2f esperado=%.2f" % [enemy.focus_stacks(), losses[0], losses[4], expected_last])


func _count_rapid_shots(moving: bool, with_perk: bool) -> int:
	_reset(AbilityData.ShotType.RAPID)
	if with_perk:
		_controller.add_perk("momentum")
	if moving:
		Input.action_press("move_right")
	var before: int = _spawned
	Input.action_press("fire")
	_controller.set_physics_process(true)
	await _wait(2.0)
	_controller.set_physics_process(false)
	Input.action_release("fire")
	Input.action_release("move_right")
	return _spawned - before


func _check_momentum() -> void:
	var standing: int = await _count_rapid_shots(false, true)
	var moving: int = await _count_rapid_shots(true, true)
	var moving_without: int = await _count_rapid_shots(true, false)
	_report("embalo atira mais rapido andando",
		moving > standing and moving > moving_without,
		"em_2s: parado=%d andando=%d andando_sem_buff=%d" % [standing, moving, moving_without])


func _check_texts_fit() -> void:
	var button: Button = Button.new()
	button.add_theme_font_size_override("font_size", 9)
	add_child(button)
	var font: Font = button.get_theme_font("font")
	var font_size: int = button.get_theme_font_size("font_size")
	var widest: float = 0.0
	var widest_text: String = ""
	for language in ["en", "pt_BR"]:
		var table: Dictionary = LocalizationManager.TRANSLATIONS[language]
		for perk_id in ShotPerks.PERKS:
			for key in [ShotPerks.name_key(perk_id), ShotPerks.info_key(perk_id)]:
				if not table.has(key):
					widest = INF
					widest_text = "%s sem %s" % [language, key]
					continue
				var width: float = font.get_string_size(table[key], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
				if width > BUTTON_TEXT_WIDTH:
					print("  largo demais %s %.0f px: %s" % [language, width, table[key]])
				if width > widest:
					widest = width
					widest_text = table[key]
	button.queue_free()
	_report("textos dos especiais cabem no botao", widest <= BUTTON_TEXT_WIDTH,
		"mais_largo=%.0f px (%s) limite=%.0f" % [widest, widest_text, BUTTON_TEXT_WIDTH])
