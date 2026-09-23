extends Node

const ENEMY_SCENE: String = "res://scenes/enemies/enemy_base.tscn"
const PLAYER_SPOT: Vector2 = Vector2(1500.0, 1500.0)
const CHANCE_SAMPLE: int = 300
const PANEL_TEXT_WIDTH: float = 150.0
const WARNING_TEXT_WIDTH: float = 130.0
const EXPECTED_CHECKS: int = 18

var _arena: Arena = null
var _player: Player = null
var _belt: FlaskBelt = null
var _controller: AbilityController = null
var _failures: int = 0
var _checks: int = 0
var _saved_palettes: int = 0
var _saved_slots: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_saved_palettes = GameManager.palettes
	_saved_slots = GameManager.flask_slots

	_arena = load(GameManager.SCENE_ARENA).instantiate() as Arena
	_arena.arena_size = Vector2(3000.0, 3000.0)
	(_arena.get_node("WaveManager") as WaveManager).first_wave_delay = 9000.0
	add_child(_arena)
	_arena.paint_canvas.remove_from_group("paint_canvas")
	_player = _arena.player
	_belt = _player.flask_belt
	_controller = _arena.ability_controller
	_controller.set_physics_process(false)
	_player.max_hp = 1000000.0
	_player.current_hp = 1000000.0
	_player.global_position = PLAYER_SPOT
	await get_tree().process_frame
	await get_tree().process_frame

	_check_effect_per_type()
	await _check_drop_chance()
	await _check_fused_flask()
	await _check_slots_and_warning()
	await _check_key_use()
	await _check_zigzag()
	await _check_rush()
	await _check_burst()
	await _check_orbit()
	await _check_duration()
	await _check_body_effects()
	await _check_use_heal()
	await _check_palette_coin()
	_check_shop()
	await _check_hud()
	await _check_paint_stains()
	await _check_charge_preview_tint()
	_check_texts_fit()

	_restore()
	if _checks != EXPECTED_CHECKS:
		_failures += 1
		print("FALHA a sonda rodou %d checagens, esperava %d (alguma morreu no meio)" % [
			_checks, EXPECTED_CHECKS])
	print("checagens: %d  falhas: %d" % [_checks, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _restore() -> void:
	GameManager.palettes = _saved_palettes
	GameManager.flask_slots = _saved_slots
	GameManager._save_progress()


func _report(label: String, passed: bool, detail: String) -> void:
	_checks += 1
	if not passed:
		_failures += 1
	print("%s %s %s" % ["ok  " if passed else "FALHA", label, detail])


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _clear() -> void:
	for child in _arena.enemies_container.get_children():
		child.queue_free()
	for child in _arena.drops_container.get_children():
		child.queue_free()
	for child in _arena.projectiles_container.get_children():
		child.queue_free()
	_belt.slots.clear()
	_belt._clear_effect()
	await get_tree().process_frame


func _spawn(type: EnemyBase.EnemyType, offset: Vector2) -> EnemyBase:
	var enemy: EnemyBase = load(ENEMY_SCENE).instantiate() as EnemyBase
	enemy.enemy_type = type
	enemy.position = PLAYER_SPOT + offset
	_arena.enemies_container.add_child(enemy)
	enemy.set_physics_process(false)
	return enemy


func _flasks() -> Array:
	return get_tree().get_nodes_in_group(PaintFlask.GROUP)


func _check_effect_per_type() -> void:
	var pairs: Array = [
		[EnemyBase.EnemyType.COMMON, FlaskEffects.ZIGZAG],
		[EnemyBase.EnemyType.FAST, FlaskEffects.RUSH],
		[EnemyBase.EnemyType.TANK, FlaskEffects.BURST],
		[EnemyBase.EnemyType.STALKER, FlaskEffects.ORBIT],
	]
	var right: bool = true
	var detail: String = ""
	for pair in pairs:
		var effect: String = FlaskEffects.for_type(pair[0])
		right = right and effect == pair[1]
		detail += "%s " % effect
	var boss: bool = FlaskEffects.for_type(EnemyBase.EnemyType.BOSS) == ""
	_report("cada cor de inimigo tem o efeito dela e o chefe nao tem frasco",
		right and boss, "%s chefe_sem_efeito=%s" % [detail, boss])


func _check_drop_chance() -> void:
	await _clear()
	GameManager.flask_slots = FlaskEffects.MAX_SLOTS
	var dropped: int = 0
	var colors_right: bool = true
	for index in CHANCE_SAMPLE:
		var enemy: EnemyBase = _spawn(EnemyBase.EnemyType.COMMON, Vector2(900.0, 0.0))
		await get_tree().process_frame
		enemy._drop_flask()
		for node in _flasks():
			var flask: PaintFlask = node as PaintFlask
			colors_right = colors_right and flask.flask_color.to_rgba32() == enemy.trail_color.to_rgba32()
			colors_right = colors_right and flask.effects == [FlaskEffects.ZIGZAG]
			flask.queue_free()
			dropped += 1
		enemy.queue_free()
	var rate: float = float(dropped) / float(CHANCE_SAMPLE)
	_report("inimigo solta frasco na cor e no efeito dele, perto da chance do preset",
		absf(rate - EnemyBase.FLASK_DROP_CHANCE) < 0.07 and colors_right,
		"soltou=%d de %d (%.0f%%, esperado %.0f%%) cores=%s" % [
			dropped, CHANCE_SAMPLE, rate * 100.0, EnemyBase.FLASK_DROP_CHANCE * 100.0, colors_right])


func _check_fused_flask() -> void:
	await _clear()
	var red: EnemyBase = _spawn(EnemyBase.EnemyType.COMMON, Vector2(200.0, 0.0))
	var blue: EnemyBase = _spawn(EnemyBase.EnemyType.FAST, Vector2(210.0, 0.0))
	await get_tree().process_frame
	red.fuse_with(blue)
	await get_tree().process_frame
	var mixed: Color = red.trail_color
	red.flask_effects = red.flask_effects
	var both: bool = red.flask_effects.has(FlaskEffects.ZIGZAG) and red.flask_effects.has(FlaskEffects.RUSH)

	var flask: PaintFlask = PaintFlask.new()
	flask.setup(mixed, red.flask_effects)
	flask.position = PLAYER_SPOT + Vector2(200.0, 0.0)
	_arena.drops_container.add_child(flask)
	await get_tree().process_frame
	var stored: bool = flask.collect()
	var slot_effects: Array = _belt.slots[0]["effects"] if not _belt.slots.is_empty() else []
	_report("frasco de inimigo fundido leva a cor misturada e os dois efeitos",
		both and stored and slot_effects.size() == 2,
		"cor=%s efeitos=%s guardado=%s" % [mixed.to_html(false), slot_effects, stored])


func _check_slots_and_warning() -> void:
	await _clear()
	GameManager.flask_slots = 1
	var first: bool = _belt.store(Color("b43434"), [FlaskEffects.ZIGZAG])
	var second: bool = _belt.store(Color("0b35dc"), [FlaskEffects.RUSH])

	var flask: PaintFlask = PaintFlask.new()
	flask.setup(Color("15b10f"), [FlaskEffects.BURST])
	flask.position = PLAYER_SPOT + Vector2(20.0, 0.0)
	_arena.drops_container.add_child(flask)
	await _wait(0.5)
	var flying: bool = flask.is_flying()
	var warned: bool = false
	for child in flask.get_children():
		if child is Label:
			warned = (child as Label).text == LocalizationManager.text("flask.slots_full")
	_report("com um slot so, o segundo frasco nao entra e o do chao avisa que esta cheio",
		first and not second and not flying and warned and _belt.slots.size() == 1,
		"guardou=%s recusou=%s voou=%s avisou=%s" % [first, not second, flying, warned])


func _check_key_use() -> void:
	await _clear()
	GameManager.flask_slots = 3
	_belt.store(Color("b43434"), [FlaskEffects.ZIGZAG])
	_belt.store(Color("0b35dc"), [FlaskEffects.RUSH])
	var key: InputEventKey = InputEventKey.new()
	key.keycode = KEY_1
	key.pressed = true
	Input.parse_input_event(key)
	await get_tree().process_frame
	await get_tree().process_frame
	var edges: ScreenEdges = _arena.hud.screen_edges()
	var glow: Color = edges.flask_color()
	await _wait(0.3)
	var first_alpha: float = edges.modulate.a
	var pulsed: bool = false
	var bolts: int = 0
	for step in 90:
		await get_tree().process_frame
		if absf(edges.modulate.a - first_alpha) > 0.02:
			pulsed = true
		for child in edges.get_children():
			if child is TextureRect:
				bolts += 1
				child.queue_free()
	var refused: bool = not _belt.use(0)
	_report("a tecla 1 usa o frasco, faz a borda piscar com raiozinhos na cor dele e recusa empilhar outro",
		_belt.is_active() and _belt.slots.size() == 1 and refused and pulsed and bolts > 0
			and glow.to_rgba32() == Color("b43434").to_rgba32(),
		"ativo=%s sobraram=%d borda=%s piscou=%s raios=%d recusou_segundo=%s" % [
			_belt.is_active(), _belt.slots.size(), glow.to_html(false), pulsed, bolts, refused])


func _fire_one(effect: String, color: Color) -> Projectile:
	_belt._clear_effect()
	_belt.slots.clear()
	_belt.store(color, [effect])
	_belt.use(0)
	_player.set_aim_override(_player.global_position + Vector2.RIGHT * 400.0)
	_controller._fire_ability(_controller.abilities[0], Vector2.RIGHT)
	await get_tree().process_frame
	for child in _arena.projectiles_container.get_children():
		if child is Projectile:
			return child
	return null


func _check_zigzag() -> void:
	await _clear()
	var shot: Projectile = await _fire_one(FlaskEffects.ZIGZAG, Color("b43434"))
	if shot == null:
		_report("o frasco vermelho engorda o tiro e faz ele andar em zigue-zague", false, "sem projetil")
		return
	var size: float = shot.size_scale
	var hit_damage: float = shot.damage
	var tinted: bool = shot.tint_color.to_rgba32() == Color("b43434").to_rgba32() and shot.sprite.material != null
	var start: Vector2 = shot.global_position
	var sides: int = 0
	var previous: float = 0.0
	for step in 24:
		await get_tree().physics_frame
		if not is_instance_valid(shot):
			break
		var side: float = signf((shot.global_position - start).dot(Vector2.DOWN))
		if side == 0.0:
			continue
		if previous != 0.0 and side != previous:
			sides += 1
		previous = side
	_report("o frasco vermelho aumenta o dano e faz o tiro andar em zigue-zague, sem engordar",
		is_equal_approx(size, 1.0) and sides >= 2 and tinted and hit_damage > _controller.damage * 1.3,
		"tamanho=%.2f dano=%.0f (base %.0f) trocas_de_lado=%d tingido=%s" % [
			size, hit_damage, _controller.damage, sides, tinted])


func _check_rush() -> void:
	await _clear()
	var shot: Projectile = await _fire_one(FlaskEffects.RUSH, Color("0b35dc"))
	var shot_speed: float = shot.speed if shot != null else 0.0
	var base_speed: float = _controller.abilities[0].projectile_speed
	var walk: float = _player.flask_speed_multiplier()
	var rate: float = _controller._fire_rate_multiplier()
	_report("o frasco azul acelera o tiro, o jogador e a recarga",
		shot_speed > base_speed * 1.4 and walk > 1.2 and rate > 1.4,
		"tiro=%.0f (base %.0f) jogador=x%.2f recarga=x%.2f" % [shot_speed, base_speed, walk, rate])


func _check_burst() -> void:
	await _clear()
	var hit: EnemyBase = _spawn(EnemyBase.EnemyType.COMMON, Vector2(420.0, 0.0))
	var near: EnemyBase = _spawn(EnemyBase.EnemyType.COMMON, Vector2(420.0, 45.0))
	var far: EnemyBase = _spawn(EnemyBase.EnemyType.COMMON, Vector2(420.0, 260.0))
	await get_tree().process_frame
	var near_hp: float = near.current_hp
	var far_hp: float = far.current_hp
	var shot: Projectile = await _fire_one(FlaskEffects.BURST, Color("15b10f"))
	if shot == null:
		_report("o frasco verde faz o tiro estourar em area", false, "sem projetil")
		return
	var size: float = shot.size_scale
	shot.global_position = hit.global_position
	shot._on_body_entered(hit)
	await get_tree().process_frame
	_report("o frasco verde engorda o tiro e faz ele estourar em area, pegando perto e nao longe",
		near.current_hp < near_hp and is_equal_approx(far.current_hp, far_hp) and size > 1.4,
		"tamanho=%.2f perto=%.0f->%.0f longe=%.0f->%.0f" % [
			size, near_hp, near.current_hp, far_hp, far.current_hp])


func _check_orbit() -> void:
	await _clear()
	var base_cooldown: float = _player.dash_cooldown
	var shot: Projectile = await _fire_one(FlaskEffects.ORBIT, Color("e0b400"))
	var turn: float = shot.homing_turn_rate if shot != null else 0.0
	_player._dash_cooldown_timer = 0.0
	_player.try_dash(Vector2.RIGHT)
	var cooldown: float = _player._dash_cooldown_timer
	_report("o frasco amarelo persegue com o tiro e deixa o dash muito mais rapido",
		turn >= FlaskEffects.ORBIT_TURN_RATE and cooldown < base_cooldown * 0.5
			and _player.flask_dash_speed_multiplier() > 1.1,
		"giro=%.1f recarga=%.2fs (base %.2fs) velocidade=x%.2f" % [
			turn, cooldown, base_cooldown, _player.flask_dash_speed_multiplier()])


func _check_duration() -> void:
	_belt._clear_effect()
	_belt.slots.clear()
	GameManager.flask_slots = 2
	_belt.store(Color("b43434"), [FlaskEffects.ZIGZAG])
	_belt.use(0)
	var full: float = _belt.time_left()
	await _wait(0.4)
	var running: bool = _belt.time_left() < full
	var edges: ScreenEdges = _arena.hud.screen_edges()
	_belt._time_left = FlaskBelt.FADE_OUT_TIME
	await _wait(0.1)
	var strong: float = edges.modulate.a
	await _wait(FlaskBelt.FADE_OUT_TIME * 0.7)
	var faded: float = edges.modulate.a
	await _wait(FlaskBelt.FADE_OUT_TIME * 0.5)
	_report("o efeito dura 15 segundos, apaga a borda aos poucos no fim e libera o proximo frasco",
		is_equal_approx(full, FlaskEffects.DURATION) and running and faded < strong * 0.7
			and not _belt.is_active() and edges.flask_color().a <= 0.0,
		"duracao=%.0fs correndo=%s borda=%.2f->%.2f ativo_no_fim=%s" % [
			full, running, strong, faded, _belt.is_active()])


func _check_body_effects() -> void:
	_belt._clear_effect()
	_belt.slots.clear()
	GameManager.flask_slots = 2
	_player.max_hp = 100.0
	_player.current_hp = 60.0
	var scale_before: float = _player.body_scale()
	_belt.store(Color("15b10f"), [FlaskEffects.BURST])
	_belt.use(0)
	await _wait(FlaskBelt.GROW_TIME + 0.15)
	var grew: bool = _player.body_scale() > scale_before * 1.2
	var tougher: bool = is_equal_approx(_player.max_hp, 100.0 + FlaskEffects.BURST_BONUS_HP)
	var healed: bool = _player.current_hp > 60.0
	_belt._time_left = 0.05
	await _wait(FlaskBelt.GROW_TIME + 0.4)
	_report("o frasco verde deixa o personagem maior e mais resistente, e devolve tudo no fim",
		grew and tougher and healed and is_equal_approx(_player.max_hp, 100.0)
			and is_equal_approx(_player.body_scale(), scale_before) and _player.current_hp <= _player.max_hp,
		"cresceu=%s vida_max=%s curou=%s voltou=%.0f/%.0f escala=%.2f" % [
			grew, tougher, healed, _player.current_hp, _player.max_hp, _player.body_scale()])


func _check_use_heal() -> void:
	await _clear()
	GameManager.flask_slots = 2
	_player.max_hp = 100.0
	_player.current_hp = 50.0
	var flask: PaintFlask = PaintFlask.new()
	flask.setup(Color("b43434"), [FlaskEffects.ZIGZAG])
	flask.position = PLAYER_SPOT + Vector2(40.0, 0.0)
	_arena.drops_container.add_child(flask)
	await get_tree().process_frame
	flask.collect()
	var after_pickup: float = _player.current_hp
	_belt.use(0)
	var after_use: float = _player.current_hp
	_report("pegar frasco nao cura, usar cura",
		is_equal_approx(after_pickup, 50.0)
			and is_equal_approx(after_use, 50.0 + FlaskEffects.USE_HEAL),
		"ao_pegar=%.0f ao_usar=%.0f (cura %.0f)" % [after_pickup, after_use, FlaskEffects.USE_HEAL])
	_belt._clear_effect()
	_player.max_hp = 1000000.0
	_player.current_hp = 1000000.0


func _check_palette_coin() -> void:
	await _clear()
	GameManager.palettes = 0
	var waves: WaveManager = _arena.wave_manager
	waves.current_wave = 9
	waves._drop_palette_coin()
	var on_common_wave: int = get_tree().get_nodes_in_group(PaletteCoin.GROUP).size()
	waves.current_wave = 10
	waves._last_boss_spot = PLAYER_SPOT + Vector2(260.0, 0.0)
	waves._drop_palette_coin()
	await get_tree().process_frame
	var coins: Array = get_tree().get_nodes_in_group(PaletteCoin.GROUP)
	var big: bool = false
	if not coins.is_empty():
		var coin: PaletteCoin = coins[0] as PaletteCoin
		big = coin._sprite.texture.get_width() >= 30 and coin._sprite.texture.get_width() <= 48
		coin.collect()
	waves.current_wave = 1
	_report("a wave de chefe solta uma paleta, e wave comum nao solta",
		on_common_wave == 0 and coins.size() == 1 and big and GameManager.palettes == 1,
		"wave_comum=%d wave_de_chefe=%d tamanho_ok=%s paletas=%d" % [
			on_common_wave, coins.size(), big, GameManager.palettes])


func _check_shop() -> void:
	GameManager.palettes = 1
	GameManager.flask_slots = 1
	var bought: bool = GameManager.buy_flask_slot()
	var broke: bool = not GameManager.buy_flask_slot()
	GameManager.palettes = 99
	GameManager.flask_slots = FlaskEffects.MAX_SLOTS
	var maxed: bool = not GameManager.buy_flask_slot()
	_report("a paleta compra um slot, e a compra trava sem paleta e no teto de 8",
		bought and broke and maxed and GameManager.flask_slots == FlaskEffects.MAX_SLOTS,
		"comprou=%s sem_paleta=%s teto=%d" % [bought, broke, FlaskEffects.MAX_SLOTS])


func _check_hud() -> void:
	GameManager.flask_slots = 3
	GameManager.palettes = 2
	await _clear()
	var hud: CanvasLayer = _arena.hud
	var bar: FlaskBar = hud.flask_bar()
	bar.refresh()
	hud.update_palettes()
	_belt.store(Color("e0b400"), [FlaskEffects.ORBIT])
	await get_tree().process_frame
	var info_panel: Control = hud.get_node("InfoPanel")
	var below: bool = bar.offset_top >= info_panel.offset_top + info_panel.size.y
	_report("a barra de frascos fica embaixo do painel de wave e hp, com um espaco por slot",
		bar != null and bar.capacity() == 3 and bar.slot_count() == 1 and below and hud.palette_row_visible(),
		"slots=%d cheios=%d topo=%.0f painel_fim=%.0f paletas_visiveis=%s" % [
			bar.capacity(), bar.slot_count(), bar.offset_top,
			info_panel.offset_top + info_panel.size.y, hud.palette_row_visible()])


func _check_paint_stains() -> void:
	await _clear()
	_arena.paint_canvas.add_to_group("paint_canvas")
	_arena.paint_canvas.paint_circle(_player.global_position, 90.0, Color("b43434"))
	await _wait(Player.STAIN_INTERVAL * 4.0)
	var stained: int = _player.stain_count()
	var tint: Color = _player.paint_tint()
	var tinted: bool = tint.r > tint.b + 0.05 and tint.b > 0.6
	_arena.paint_canvas.dry_all()
	await _wait(Player.STAIN_FADE + 0.5)
	var cleaned: int = _player.stain_count()
	var back: bool = _player.paint_tint().is_equal_approx(Color.WHITE) \
		or _player.paint_tint().b > 0.97
	_arena.paint_canvas.remove_from_group("paint_canvas")
	_report("andar em tinta fresca suja o personagem e o tinge de leve, e tudo sai ao deixar a tinta",
		stained >= 3 and tinted and cleaned == 0 and back,
		"manchas=%d cor=%s depois=%d voltou=%s" % [
			stained, tint.to_html(false), cleaned, _player.paint_tint().to_html(false)])


func _check_charge_preview_tint() -> void:
	await _clear()
	GameManager.flask_slots = 2
	var data: AbilityData = _controller.abilities[0]
	var saved_type: int = data.shot_type
	data.apply_shot_type(AbilityData.ShotType.CHARGE, _controller.damage, _controller.cooldown,
		_controller.projectile_speed)
	data.charging = true
	data.charge_elapsed = data.charge_time * 0.5
	_belt.store(Color("e0b400"), [FlaskEffects.ORBIT])
	_belt.use(0)
	_controller._update_charge_preview(Vector2.RIGHT, 0.016)
	var material: ShaderMaterial = _controller._charge_preview.material as ShaderMaterial
	var hue: float = material.get_shader_parameter("target_hue") if material != null else -1.0
	_belt._clear_effect()
	_controller._update_charge_preview(Vector2.RIGHT, 0.016)
	var cleared: bool = _controller._charge_preview.material == null
	data.charging = false
	data.charge_elapsed = 0.0
	data.apply_shot_type(saved_type, _controller.damage, _controller.cooldown,
		_controller.projectile_speed)
	_report("a previa do tiro carregado sai na cor do frasco e volta ao normal sem efeito",
		material != null and is_equal_approx(hue, Color("e0b400").h) and cleared,
		"matiz=%.3f (esperado %.3f) limpou=%s" % [hue, Color("e0b400").h, cleared])


func _check_texts_fit() -> void:
	var probe_label: Label = _arena.hud.get_node("InfoPanel/InfoContainer/EnemiesLabel") as Label
	var font: Font = probe_label.get_theme_font("font")
	var fits: bool = true
	var worst: float = 0.0
	var worst_text: String = ""
	for language in ["en", "pt_BR"]:
		var table: Dictionary = LocalizationManager.TRANSLATIONS[language]
		var measures: Array = [
			[table["flask.slots_full"], WARNING_TEXT_WIDTH, PaintFlask.WARNING_FONT_SIZE],
			[table["creator.palettes"] % 9, PANEL_TEXT_WIDTH, 8],
			[table["creator.flask_slots"] % [8, 8], PANEL_TEXT_WIDTH, 8],
			[table["creator.buy_slot"], PANEL_TEXT_WIDTH, 8],
		]
		for measure in measures:
			var width: float = font.get_string_size(
				measure[0], HORIZONTAL_ALIGNMENT_LEFT, -1, measure[2]).x
			if width > measure[1]:
				fits = false
				print("  largo demais %s %.0f px (limite %.0f): %s" % [language, width, measure[1], measure[0]])
			if width > worst:
				worst = width
				worst_text = measure[0]
	_report("os textos novos cabem nos dois idiomas", fits,
		"mais_largo=%.0f px (%s)" % [worst, worst_text])
