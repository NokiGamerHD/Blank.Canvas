extends Node

const ENEMY_SCENE: String = "res://scenes/enemies/enemy_base.tscn"
const PLAYER_SPOT: Vector2 = Vector2(1500.0, 1500.0)
const CHANCE_SAMPLE: int = 120
const BUTTON_TEXT_WIDTH: float = 280.0
const PANEL_TEXT_WIDTH: float = 300.0
const WIDEST_PRICE: String = "95"

var _arena: Arena = null
var _player: Player = null
var _controller: AbilityController = null
var _screen: Node = null
var _failures: int = 0


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
	await get_tree().process_frame
	await get_tree().process_frame

	_check_presets()
	await _check_drop_chance()
	await _check_pickup()
	_check_spend_rules()
	await _check_wave_end_attracts()
	await _check_progression_collects()
	await _check_reroll()
	await _check_new_ability_purchase()
	_check_texts_fit()

	get_tree().paused = false
	print("falhas: %d" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _report(label: String, passed: bool, detail: String) -> void:
	if not passed:
		_failures += 1
	print("%s %s %s" % ["ok  " if passed else "FALHA", label, detail])


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _clear() -> void:
	get_tree().paused = false
	for child in _arena.enemies_container.get_children():
		child.free()
	for child in _arena.drops_container.get_children():
		child.free()
	_player.global_position = PLAYER_SPOT
	_player.velocity = Vector2.ZERO
	_player.spend_ink(_player.ink)


func _drop_at(offset: Vector2) -> PaintDrop:
	var drop: PaintDrop = PaintDrop.new()
	drop.setup(Color("b43434"))
	drop.position = PLAYER_SPOT + offset
	_arena.drops_container.add_child(drop)
	return drop


func _live_options() -> Array[Button]:
	var found: Array[Button] = []
	for child in _screen.upgrade_options.get_children():
		var button: Button = child as Button
		if button != null and not button.is_queued_for_deletion():
			found.append(button)
	return found


func _check_presets() -> void:
	var all_have: bool = true
	var details: PackedStringArray = PackedStringArray()
	for type in EnemyBase.PRESETS:
		var chance: float = EnemyBase.PRESETS[type].get("ink_drop_chance", 0.0)
		details.append("%s=%.2f" % [EnemyBase.EnemyType.keys()[type], chance])
		all_have = all_have and chance > 0.0 and chance < 1.0
	_report("todo inimigo tem chance de soltar gota", all_have, " ".join(details))


func _check_drop_chance() -> void:
	_clear()
	var scene: PackedScene = load(ENEMY_SCENE)
	for i in CHANCE_SAMPLE:
		var enemy: EnemyBase = scene.instantiate()
		enemy.enemy_type = EnemyBase.EnemyType.COMMON
		enemy.position = PLAYER_SPOT + Vector2(900.0, 0.0)
		_arena.enemies_container.add_child(enemy)
		enemy.set_physics_process(false)
		enemy.take_damage(100000.0, false)

	var drops: Array[Node] = get_tree().get_nodes_in_group(PaintDrop.GROUP)
	var trail: Color = EnemyBase.PRESETS[EnemyBase.EnemyType.COMMON]["trail_color"]
	var colors_match: bool = true
	for node in drops:
		colors_match = colors_match and (node as PaintDrop).ink_color.is_equal_approx(Color(trail.r, trail.g, trail.b))
	await _wait(0.5)

	var chance: float = EnemyBase.PRESETS[EnemyBase.EnemyType.COMMON]["ink_drop_chance"]
	var mean: float = CHANCE_SAMPLE * chance
	var spread: float = 3.5 * sqrt(CHANCE_SAMPLE * chance * (1.0 - chance))
	var in_range: bool = absf(drops.size() - mean) <= spread
	_report("inimigo morto solta gota na chance e na cor do rastro",
		in_range and colors_match and not drops.is_empty() and _player.ink == 0,
		"gotas=%d de %d (esperado %.0f +- %.0f) cor_do_rastro=%s longe_nao_coleta=%s" % [
			drops.size(), CHANCE_SAMPLE, mean, spread, colors_match, _player.ink == 0
		])


func _check_pickup() -> void:
	_clear()
	AudioManager._last_played.erase(AudioManager.INK_PICKUP_SOUND)
	var drop: PaintDrop = _drop_at(Vector2(220.0, 0.0))
	await _wait(0.6)
	var stayed: bool = is_instance_valid(drop) and not drop.is_flying() and _player.ink == 0
	_player.global_position = drop.global_position - Vector2(60.0, 0.0)
	await get_tree().process_frame
	await get_tree().process_frame
	var flew: bool = is_instance_valid(drop) and drop.is_flying()
	await _wait(0.5)
	var collected: bool = not is_instance_valid(drop) and _player.ink == 1
	var sounded: bool = AudioManager._last_played.has(AudioManager.INK_PICKUP_SOUND)
	var hud_shows: bool = _arena.hud.ink_text() == "1"
	_report("gota perto voa ate o jogador, soma, toca som e aparece no HUD",
		stayed and flew and collected and sounded and hud_shows,
		"parada_longe=%s voou=%s coletou=%s som=%s hud=%s" % [stayed, flew, collected, sounded, _arena.hud.ink_text()])


func _check_spend_rules() -> void:
	_clear()
	_player.add_ink(5)
	var refused_over: bool = not _player.spend_ink(6) and _player.ink == 5
	var refused_negative: bool = not _player.spend_ink(-2) and _player.ink == 5
	_player.add_ink(-3)
	var ignored_negative_add: bool = _player.ink == 5
	var spent: bool = _player.spend_ink(5) and _player.ink == 0
	_report("gastar gotas nunca deixa saldo negativo",
		refused_over and refused_negative and ignored_negative_add and spent,
		"recusa_acima=%s recusa_negativo=%s ignora_soma_negativa=%s gasta_tudo=%s" % [
			refused_over, refused_negative, ignored_negative_add, spent
		])


func _check_wave_end_attracts() -> void:
	_clear()
	var drops: Array[PaintDrop] = []
	for i in 3:
		drops.append(_drop_at(Vector2.from_angle(TAU * float(i) / 3.0) * 600.0))
	await _wait(0.4)
	var waited: bool = _player.ink == 0
	_arena.wave_manager.wave_completed.emit(3)
	await _wait(1.5)
	var all_gone: bool = true
	for drop in drops:
		all_gone = all_gone and not is_instance_valid(drop)
	_report("fim da wave puxa as gotas que sobraram",
		waited and all_gone and _player.ink == 3,
		"esperou_longe=%s todas_coletadas=%s gotas=%d" % [waited, all_gone, _player.ink])


func _check_progression_collects() -> void:
	_clear()
	_drop_at(Vector2(600.0, 0.0))
	_drop_at(Vector2(-600.0, 0.0))
	await get_tree().process_frame
	_arena._on_progression_due(5)
	await get_tree().process_frame
	var waits_for_drops: bool = not _screen.visible and _player.ink == 0
	var flying: bool = true
	for drop in get_tree().get_nodes_in_group(PaintDrop.GROUP):
		flying = flying and (drop as PaintDrop).is_flying()
	var elapsed: float = await _wait_for_shop(3.0)
	var shown: bool = _screen.visible and _screen._ink_label.text == "2" and _player.ink == 2
	var none_left: bool = get_tree().get_nodes_in_group(PaintDrop.GROUP).is_empty()
	_screen.close()
	_report("tela de upgrade espera as gotas chegarem voando e abre com o saldo todo",
		waits_for_drops and flying and shown and none_left and elapsed < _arena.DROP_GATHER_TIMEOUT + 0.2,
		"esperou=%s voando=%s saldo_na_tela=%s nenhuma_sobrou=%s abriu_em=%.2fs" % [
			waits_for_drops, flying, _screen._ink_label.text, none_left, elapsed])

	_clear()
	_drop_at(Vector2(600.0, 0.0))
	await get_tree().process_frame
	_arena._on_progression_due(5)
	get_tree().paused = true
	await get_tree().create_timer(_arena.DROP_GATHER_TIMEOUT + 1.0).timeout
	var stayed_closed: bool = not _screen.visible
	get_tree().paused = false
	var after_pause: float = await _wait_for_shop(3.0)
	var opened_after: bool = _screen.visible and _player.ink == 1
	_screen.close()
	_report("com o jogo pausado a loja espera, e abre quando volta",
		stayed_closed and opened_after,
		"fechada_na_pausa=%s abriu_depois=%s em=%.2fs" % [stayed_closed, opened_after, after_pause])


func _wait_for_shop(limit: float) -> float:
	var elapsed: float = 0.0
	while not _screen.visible and elapsed < limit:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	return elapsed


func _check_reroll() -> void:
	_clear()
	_player.add_ink(10)
	_screen.open(5, _controller.get_abilities(), _player)
	var first_price: int = _screen.reroll_price()
	_screen._on_upgrade_button_pressed()
	var before: Array[Button] = _live_options()
	_screen._show_choice_page()
	_screen._on_upgrade_button_pressed()
	var no_free_reroll: bool = _live_options() == before

	_screen._reroll_button.pressed.emit()
	var after: Array[Button] = _live_options()
	var has_perk: bool = false
	for button in after:
		has_perk = has_perk or String(button.get_meta("upgrade_id", "")).begins_with("perk:")
	var rerolled: bool = _player.ink == 7 and _screen.reroll_price() == 5 \
		and after.size() == 3 and not before.has(after[0])

	_screen._reroll_button.pressed.emit()
	var second: bool = _player.ink == 2 and _screen.reroll_price() == 7
	var disabled: bool = _screen._reroll_button.disabled
	var refused: bool = not _screen.reroll() and _player.ink == 2
	_screen.close()
	_screen.open(10, _controller.get_abilities(), _player)
	var price_reset: bool = first_price == 3 and _screen.reroll_price() == 3
	_screen.close()

	_report("sortear de novo custa gotas, sobe o preco e zera na tela seguinte",
		no_free_reroll and rerolled and has_perk and second and disabled and refused and price_reset,
		"voltar_nao_sorteia=%s primeiro=%s especial_garantido=%s segundo=%s travou_sem_gotas=%s recusou=%s preco_volta_a_3=%s" % [
			no_free_reroll, rerolled, has_perk, second, disabled, refused, price_reset
		])


func _check_new_ability_purchase() -> void:
	_clear()
	var image: Image = Image.create(36, 36, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	image.fill_rect(Rect2i(14, 14, 8, 8), Color("f2913d"))
	if not GameManager.has_ability_drawing(0):
		GameManager.set_ability_drawing(0, image)
	var emitted: Array[int] = []
	var counter: Callable = func() -> void: emitted.append(1)
	_screen.new_ability_chosen.connect(counter)

	_player.add_ink(5)
	_arena._on_progression_due(5)
	var price: int = _screen.new_ability_price()
	var locked: bool = _screen.new_ability_button.disabled and price == 20 \
		and _screen.new_ability_info_label.text == LocalizationManager.text("progression.need_ink", [15])
	_screen.new_ability_button.pressed.emit()
	var ignored: bool = emitted.is_empty() and not _arena.in_run_creator_layer.visible

	_player.add_ink(20)
	_screen.return_to_shop()
	var unlocked: bool = not _screen.new_ability_button.disabled
	_screen.new_ability_button.pressed.emit()
	var opened: bool = emitted.size() == 1 and _arena.in_run_creator_layer.visible
	_arena._on_in_run_ability_cancelled()
	var cancel_free: bool = _player.ink == 25 and _screen.visible and not _arena.in_run_creator_layer.visible

	var index: int = _arena._next_free_ability_index()
	GameManager.set_ability_drawing(index, image)
	GameManager.set_ability_shot_type(index, AbilityData.ShotType.STANDARD)
	_screen.new_ability_button.pressed.emit()
	_arena._on_in_run_ability_created(index)
	var paid: bool = _player.ink == 5
	var added: bool = _controller.get_abilities().size() == 2
	var back_in_shop: bool = _screen.visible and _screen.choice_page.visible and get_tree().paused \
		and not _screen.upgrade_button.disabled
	var next_price: bool = _screen.new_ability_price() == 35 and _screen.new_ability_button.disabled
	_screen.new_ability_chosen.disconnect(counter)
	_screen.close()

	_report("nova habilidade custa gotas, so cobra ao criar e volta para escolher o upgrade",
		locked and ignored and unlocked and opened and cancel_free and paid and added and back_in_shop and next_price,
		"travada_com_5=%s ignorou_clique=%s liberou_com_25=%s abriu_editor=%s cancelar_nao_cobra=%s pagou=%s adicionou=%s voltou_a_loja=%s proximo_preco_35=%s" % [
			locked, ignored, unlocked, opened, cancel_free, paid, added, back_in_shop, next_price
		])


func _row_width(row: HBoxContainer, name: String, price: String) -> float:
	var name_label: Label = row.get_child(0) as Label
	var font: Font = name_label.get_theme_font("font")
	var font_size: int = name_label.get_theme_font_size("font_size")
	var gap: float = (row.get_child(1) as Control).custom_minimum_size.x
	var icon: float = PaintDrop.icon_texture(1).get_width()
	var separation: float = row.get_theme_constant("separation") * (row.get_child_count() - 1)
	return font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x \
		+ gap + font.get_string_size(price, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + icon + separation


func _label_width(label: Label, text: String) -> float:
	var font: Font = label.get_theme_font("font")
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x


func _check_texts_fit() -> void:
	var worst: float = 0.0
	var worst_text: String = ""
	var fits: bool = true
	for language in ["en", "pt_BR"]:
		var table: Dictionary = LocalizationManager.TRANSLATIONS[language]
		var measures: Array = [
			[_row_width(_screen._new_ability_content, table["progression.new_ability"], WIDEST_PRICE),
				BUTTON_TEXT_WIDTH, table["progression.new_ability"]],
			[_row_width(_screen._reroll_content, table["progression.reroll"], WIDEST_PRICE),
				BUTTON_TEXT_WIDTH, table["progression.reroll"]],
			[_label_width(_screen.new_ability_info_label, table["progression.need_ink"] % 95),
				PANEL_TEXT_WIDTH, table["progression.need_ink"] % 95],
			[_label_width(_screen.choice_subtitle, table["progression.choose_path"]),
				PANEL_TEXT_WIDTH, table["progression.choose_path"]],
		]
		for measure in measures:
			if measure[0] > measure[1]:
				fits = false
				print("  largo demais %s %.0f px (limite %.0f): %s" % [language, measure[0], measure[1], measure[2]])
			if measure[0] > worst:
				worst = measure[0]
				worst_text = measure[2]
	_report("textos da loja cabem na tela de upgrade", fits,
		"mais_largo=%.0f px (%s)" % [worst, worst_text])
