extends Node

const OUTPUT_DIR: String = "user://screenshots"
const SETTLE_FRAMES: int = 12
const INDICATOR_DEMO_SCENE: String = "res://scenes/enemies/enemy_base.tscn"
const INDICATOR_DEMO_DISTANCE: float = 520.0
const DASH_DEMO_DISTANCE: float = 250.0
const DASH_DEMO_DELAY: float = 0.34
const SPLIT_DEMO_DISTANCE: float = 190.0
const SPLIT_DEMO_DAMAGE: float = 20.0
const SPLIT_DEMO_DELAY: float = 0.12
const ZIGZAG_DEMO_DISTANCE: float = 560.0
const ZIGZAG_DEMO_SECONDS: float = 3.2
const PLAYER_DASH_DEMO_DELAY: float = 0.1
const CROSSHAIR_PREVIEW_SCALE: int = 4
const CHARGE_DEMO_HOLD: float = 1.6
const CHARGE_DEMO_FLIGHT: float = 0.12
const CRITICAL_DEMO_DELAY: float = 0.2
const POISON_DEMO_DISTANCE: float = 230.0
const POISON_DEMO_SECONDS: float = 1.4
const POISON_DEMO_DPS: float = 2.45
const HARNESS_INVULNERABILITY: float = 1.0e9
const INK_DEMO_COUNT: int = 8
const INK_DEMO_DISTANCE: float = 150.0
const INK_DEMO_SETTLE: float = 0.5
const SHOP_DEMO_INK: int = 26
const SHOP_DEMO_SHORT_INK: int = 7
const BOSS_DEMO_DISTANCE: float = 230.0
const BOSS_DEMO_SETTLE: float = 0.6
const BOSS_SHARD_FLIGHT: float = 0.45
const ORB_DEMO_DISTANCE: float = 240.0
const ORB_DEMO_GENERATION: int = 2
const ORB_DEMO_VOLLEYS: int = 3
const ORB_DEMO_GAP: float = 0.55
const WAVE_BANNER_DEMO: int = 7
const BOSS_BANNER_DEMO: int = 10
const BANNER_DEMO_DELAY: float = 0.3
const BANNER_DEMO_CLEAR: float = 1.8
const FUSION_DEMO_DISTANCE: float = 190.0
const FUSION_DEMO_WALK: float = 0.7
const FUSION_DEMO_PAIRS: Array[Array] = [
	[EnemyBase.EnemyType.STALKER, EnemyBase.EnemyType.STALKER],
	[EnemyBase.EnemyType.COMMON, EnemyBase.EnemyType.FAST],
	[EnemyBase.EnemyType.FAST, EnemyBase.EnemyType.STALKER],
	[EnemyBase.EnemyType.TANK, EnemyBase.EnemyType.COMMON],
]
const MIX_DEMO_OFFSET: Vector2 = Vector2(0.0, -150.0)
const MIX_DEMO_HALF: float = 120.0
const MIX_DEMO_RADIUS: float = 10.0
const FOOTING_DEMO_RADIUS: float = 34.0
const FOOTING_DEMO_WALK: float = 0.5

@export var arena_seconds: float = 8.0

@export var showcase_best_wave: int = 17


const FLASK_DEMO_DISTANCE: float = 120.0
const FLASK_DEMO_COIN_DISTANCE: float = 200.0
const FLASK_DEMO_SETTLE: float = 0.45
const FLASK_DEMO_SHOT_GAP: float = 0.12
const FLASK_DEMO_GLOW: float = 0.3
const FLASK_DEMO_SLOTS: int = 6


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var language: String = OS.get_environment("SHOT_LANG")
	if not language.is_empty():
		LocalizationManager.set_language(language)
	var dir_error: int = DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
	if dir_error != OK and not DirAccess.dir_exists_absolute(OUTPUT_DIR):
		push_warning("[ScreenshotHarness] Não foi possível criar %s (erro %d)." % [OUTPUT_DIR, dir_error])
		get_tree().quit()
		return

	_prepare_drawings()
	await _capture_main_menu()
	await _capture_creators()
	await _capture_arena()
	await _capture_game_over()
	get_tree().quit()


func _prepare_drawings() -> void:
	if not GameManager.load_character_drawing_from_disk():
		GameManager.set_character_drawing(_placeholder_image(Color("3f6fd9")))
	if not GameManager.load_ability_drawing_from_disk(0):
		GameManager.set_ability_drawing(0, _placeholder_image(Color("f2913d")))


func _placeholder_image(color: Color) -> Image:
	var image: Image = Image.create(36, 36, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var center: Vector2 = Vector2(17.5, 17.5)
	for y in 36:
		for x in 36:
			if Vector2(x, y).distance_to(center) <= 15.0:
				image.set_pixel(x, y, color)
	return image


func _show_scene(scene_path: String) -> Node:
	var scene: PackedScene = load(scene_path)
	if scene == null:
		push_warning("[ScreenshotHarness] Não foi possível carregar %s." % scene_path)
		return null
	var instance: Node = scene.instantiate()
	add_child(instance)
	return instance


func _clear_scene(instance: Node) -> void:
	if instance == null:
		return
	instance.queue_free()
	await get_tree().process_frame


func _capture(file_name: String) -> void:
	for i in SETTLE_FRAMES:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw

	_save_image(get_viewport().get_texture().get_image(), file_name)


func _capture_immediately(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	_save_image(get_viewport().get_texture().get_image(), file_name)


func _save_image(image: Image, file_name: String) -> void:
	var path: String = "%s/%s.png" % [OUTPUT_DIR, file_name]
	var save_error: int = image.save_png(path)
	if save_error != OK:
		push_warning("[ScreenshotHarness] Falha ao salvar %s (erro %d)." % [path, save_error])
		return
	print("captura: %s" % ProjectSettings.globalize_path(path))


func _capture_main_menu() -> void:
	GameManager.best_wave = showcase_best_wave
	var menu: Node = _show_scene(GameManager.SCENE_MAIN_MENU)
	if menu == null:
		return
	await _capture("01_menu")

	var settings: SettingsScreen = menu._settings_screen
	settings.open()
	await _capture("02_opcoes_geral")
	settings._show_page(false)
	await _capture("03_opcoes_controles")
	settings._show_page(true)
	settings.close()

	await _clear_scene(menu)


func _capture_creators() -> void:
	var character: Node = _show_scene(GameManager.SCENE_CHARACTER_CREATOR)
	if character != null:
		var saved_palettes: int = GameManager.palettes
		GameManager.palettes = 3
		character.call("_refresh_flask_shop")
		await _capture("08_criador_personagem")
		GameManager.palettes = saved_palettes
		character.call("_refresh_flask_shop")
		if character.open_color_dialog():
			await _capture("11_seletor_de_cor")
		await _clear_scene(character)

	var ability: Node = _show_scene(GameManager.SCENE_ABILITY_CREATOR)
	if ability != null:
		await _capture("09_criador_habilidade")
		if ability.open_shot_picker():
			await _capture("21_escolha_de_tiro")
			ability.get_shot_picker().select(AbilityData.ShotType.CHARGE)
			await _capture("22_escolha_de_tiro_marcado")
		await _clear_scene(ability)


func _capture_arena() -> void:
	var arena: Node = _show_scene(GameManager.SCENE_ARENA)
	if arena == null:
		return
	_keep_player_alive(arena)
	await _capture("18_dica_de_controles")
	_save_crosshair_preview()
	await get_tree().create_timer(arena_seconds).timeout
	await _capture("04_arena_minimapa")

	arena.get_node("PauseScreen").open()
	await _capture("05_arena_pausa")
	arena.get_node("PauseScreen").close()

	arena.wave_manager.wave_changed.emit(WAVE_BANNER_DEMO)
	await get_tree().create_timer(BANNER_DEMO_DELAY).timeout
	await _capture_immediately("37_aviso_de_wave")
	await get_tree().create_timer(BANNER_DEMO_CLEAR).timeout
	arena.wave_manager.wave_changed.emit(BOSS_BANNER_DEMO)
	await get_tree().create_timer(BANNER_DEMO_DELAY).timeout
	await _capture_immediately("38_aviso_de_chefe")
	await get_tree().create_timer(BANNER_DEMO_CLEAR).timeout
	arena.hud.update_wave(1)

	var controller: AbilityController = arena.get_node("Player/AbilityController")
	arena.player.add_ink(SHOP_DEMO_INK)
	arena.get_node("ProgressionScreen").open(5, controller.get_abilities(), arena.player)
	await _capture("10_arena_progressao")
	if _show_dash_upgrade_option(arena.get_node("ProgressionScreen")):
		await _capture("20_arena_upgrades")
	arena.get_node("ProgressionScreen").close()
	arena.player.spend_ink(arena.player.ink - SHOP_DEMO_SHORT_INK)
	arena.get_node("ProgressionScreen").open(5, controller.get_abilities(), arena.player)
	await _capture("29_loja_sem_gotas")
	arena.get_node("ProgressionScreen").close()
	arena.player.add_ink(SHOP_DEMO_INK)
	arena.get_node("ProgressionScreen").open(4, controller.get_abilities(), arena.player, true)
	await _capture("41_upgrade_de_status")
	arena.get_node("ProgressionScreen").close()

	await _capture_ink_drops_demo(arena)
	await _capture_paint_mix_demo(arena)
	await _capture_footing_demo(arena)
	await _capture_hurt_edges_demo(arena)
	await _capture_boss_demo(arena)
	await _capture_fusion_demo(arena)
	await _capture_flask_demo(arena)

	if _spawn_indicator_demo(arena):
		await _capture("13_indicadores_de_inimigo")

	if _spawn_zigzag_demo(arena):
		await get_tree().create_timer(ZIGZAG_DEMO_SECONDS).timeout
		await _capture("15_zigue_zague_do_vermelho")

	if _spawn_split_demo(arena):
		await get_tree().create_timer(SPLIT_DEMO_DELAY).timeout
		await _capture("16_divisao_do_verde")

	if _start_player_dash_demo(arena):
		await get_tree().create_timer(PLAYER_DASH_DEMO_DELAY).timeout
		await _capture_immediately("17_dash_do_jogador")
		_keep_player_alive(arena)

	await _capture_charge_demo(arena)

	if _spawn_dash_demo(arena):
		await get_tree().create_timer(DASH_DEMO_DELAY).timeout
		await _capture("14_dash_do_amarelo")

	var in_run_layer: CanvasLayer = arena.get_node("InRunAbilityCreator")
	var in_run_creator: DrawingCreatorBase = in_run_layer.get_node("AbilityCreator")
	in_run_layer.visible = true
	get_tree().paused = true
	var locked_image: Image = Image.create(36, 36, false, Image.FORMAT_RGBA8)
	locked_image.fill(Color(0, 0, 0, 0))
	locked_image.fill_rect(Rect2i(13, 13, 10, 10), Color("f2913d"))
	in_run_creator.pixel_editor.load_from_image(locked_image)
	var in_run_ability: Node = in_run_creator
	if in_run_ability.open_shot_picker():
		await _capture("25_escolha_travada_em_partida")
		in_run_ability.get_shot_picker().close()
	if in_run_creator.open_color_dialog():
		await _capture("12_seletor_de_cor_em_partida")
	get_tree().paused = false
	in_run_layer.visible = false

	await _clear_scene(arena)


func _spawn_indicator_demo(arena: Arena) -> bool:
	var scene: PackedScene = load(INDICATOR_DEMO_SCENE)
	if scene == null:
		push_warning("[ScreenshotHarness] Não foi possível carregar %s." % INDICATOR_DEMO_SCENE)
		return false

	var types: Array[EnemyBase.EnemyType] = [
		EnemyBase.EnemyType.COMMON,
		EnemyBase.EnemyType.FAST,
		EnemyBase.EnemyType.TANK,
		EnemyBase.EnemyType.STALKER,
	]
	for index in types.size():
		var enemy: EnemyBase = scene.instantiate()
		enemy.enemy_type = types[index]
		enemy.set_arena_bounds(Rect2(Vector2.ZERO, arena.arena_size))
		var angle: float = TAU * float(index) / float(types.size()) - PI / 3.0
		enemy.position = arena.player.global_position \
			+ Vector2.from_angle(angle) * INDICATOR_DEMO_DISTANCE
		arena.enemies_container.add_child(enemy)
		enemy.set_physics_process(false)
	return true


func _spawn_zigzag_demo(arena: Arena) -> bool:
	var scene: PackedScene = load(INDICATOR_DEMO_SCENE)
	if scene == null:
		return false
	for child in arena.enemies_container.get_children():
		child.queue_free()

	for index in 3:
		var enemy: EnemyBase = scene.instantiate()
		enemy.enemy_type = EnemyBase.EnemyType.COMMON
		enemy.set_arena_bounds(Rect2(Vector2.ZERO, arena.arena_size))
		var angle: float = TAU * float(index) / 3.0
		enemy.position = arena.player.global_position \
			+ Vector2.from_angle(angle) * ZIGZAG_DEMO_DISTANCE
		arena.enemies_container.add_child(enemy)
		enemy.dash_range = 0.0
	return true


func _spawn_split_demo(arena: Arena) -> bool:
	var scene: PackedScene = load(INDICATOR_DEMO_SCENE)
	if scene == null:
		return false
	for child in arena.enemies_container.get_children():
		child.queue_free()

	var greens: Array[EnemyBase] = []
	for index in 3:
		var enemy: EnemyBase = scene.instantiate()
		enemy.enemy_type = EnemyBase.EnemyType.TANK
		enemy.set_arena_bounds(Rect2(Vector2.ZERO, arena.arena_size))
		var angle: float = TAU * float(index) / 3.0 - PI / 5.0
		enemy.position = arena.player.global_position \
			+ Vector2.from_angle(angle) * SPLIT_DEMO_DISTANCE
		arena.enemies_container.add_child(enemy)
		enemy.set_physics_process(false)
		greens.append(enemy)

	for enemy in greens:
		enemy.take_damage(SPLIT_DEMO_DAMAGE)
	return true


func _spawn_dash_demo(arena: Arena) -> bool:
	var scene: PackedScene = load(INDICATOR_DEMO_SCENE)
	if scene == null:
		return false
	for child in arena.enemies_container.get_children():
		child.queue_free()

	for index in 3:
		var enemy: EnemyBase = scene.instantiate()
		enemy.enemy_type = EnemyBase.EnemyType.STALKER
		enemy.set_arena_bounds(Rect2(Vector2.ZERO, arena.arena_size))
		var angle: float = TAU * float(index) / 3.0 + PI / 6.0
		enemy.position = arena.player.global_position \
			+ Vector2.from_angle(angle) * DASH_DEMO_DISTANCE
		arena.enemies_container.add_child(enemy)
		enemy.dash_patience = 0.0
	return true


func _capture_game_over() -> void:
	GameManager.last_wave_reached = 12
	GameManager.last_canvas_coverage = 0.23
	GameManager.last_run_was_record = false
	var normal: Node = _show_scene(GameManager.SCENE_GAME_OVER)
	if normal != null:
		await _capture("06_game_over")
		await _clear_scene(normal)

	GameManager.last_wave_reached = 21
	GameManager.best_wave = 21
	GameManager.last_run_was_record = true
	var record: Node = _show_scene(GameManager.SCENE_GAME_OVER)
	if record != null:
		await _capture("07_game_over_recorde")
		await _clear_scene(record)


func _start_player_dash_demo(arena: Arena) -> bool:
	for child in arena.enemies_container.get_children():
		child.queue_free()
	return arena.player.try_dash(Vector2.RIGHT)


func _save_crosshair_preview() -> void:
	var crosshair: Image = Arena.build_crosshair_image()
	var width: int = crosshair.get_width()
	var height: int = crosshair.get_height()
	var preview: Image = Image.create(width * 2, height, false, Image.FORMAT_RGBA8)
	preview.fill(Color.WHITE)
	preview.fill_rect(Rect2i(width, 0, width, height), Color("15b10f"))
	preview.blend_rect(crosshair, Rect2i(Vector2i.ZERO, crosshair.get_size()), Vector2i.ZERO)
	preview.blend_rect(crosshair, Rect2i(Vector2i.ZERO, crosshair.get_size()), Vector2i(width, 0))
	preview.resize(width * 2 * CROSSHAIR_PREVIEW_SCALE, height * CROSSHAIR_PREVIEW_SCALE, Image.INTERPOLATE_NEAREST)
	_save_image(preview, "19_mira")



func _show_dash_upgrade_option(screen: Node) -> bool:
	var dash_text: String = LocalizationManager.text("upgrade.dash")
	screen._on_upgrade_button_pressed()
	for attempt in 40:
		for child in screen.upgrade_options.get_children():
			var button: Button = child as Button
			if button != null and not button.is_queued_for_deletion() and button.text.contains(dash_text):
				return true
		screen._build_upgrade_options()
	push_warning("[ScreenshotHarness] O upgrade de dash não apareceu em 40 sorteios.")
	return false


func _capture_charge_demo(arena: Arena) -> void:
	for child in arena.enemies_container.get_children():
		child.queue_free()
	var controller: AbilityController = arena.ability_controller
	var data: AbilityData = controller.get_abilities()[0]
	data.apply_shot_type(AbilityData.ShotType.CHARGE, controller.damage, controller.cooldown, controller.projectile_speed)
	data.cooldown_remaining = 0.0
	arena.player.set_aim_override(arena.player.global_position + Vector2(220.0, -70.0))
	Input.action_press("fire")
	await get_tree().create_timer(CHARGE_DEMO_HOLD).timeout
	await _capture("23_tiro_carregando")
	Input.action_release("fire")
	await get_tree().create_timer(CHARGE_DEMO_FLIGHT).timeout
	await _capture_immediately("24_disparo_carregado")
	data.apply_shot_type(AbilityData.ShotType.STANDARD, controller.damage, controller.cooldown, controller.projectile_speed)
	controller.perks.clear()
	await _capture_poison_demo(arena)
	await _capture_critical_number_demo(arena)


func _capture_critical_number_demo(arena: Arena) -> void:
	for child in arena.enemies_container.get_children():
		child.queue_free()
	var enemy_scene: PackedScene = load(INDICATOR_DEMO_SCENE)
	var projectile_scene: PackedScene = load("res://scenes/abilities/projectile.tscn")
	for index in 2:
		var enemy: EnemyBase = enemy_scene.instantiate()
		enemy.enemy_type = EnemyBase.EnemyType.COMMON
		enemy.set_arena_bounds(Rect2(Vector2.ZERO, arena.arena_size))
		enemy.position = arena.player.global_position + Vector2(-80.0 + 160.0 * index, -110.0)
		arena.enemies_container.add_child(enemy)
		enemy.set_physics_process(false)
		enemy.current_hp = 100000.0
		var projectile: Projectile = projectile_scene.instantiate()
		projectile.configure(GameManager.get_ability_texture(0), Vector2.UP)
		projectile.damage = arena.ability_controller.damage * (ShotPerks.CRIT_MULTIPLIER if index == 1 else 1.0)
		projectile.is_critical = index == 1
		projectile.position = enemy.position + Vector2(0.0, 70.0)
		arena.projectiles_container.add_child(projectile)
	await get_tree().create_timer(CRITICAL_DEMO_DELAY).timeout
	await _capture_immediately("27_numero_critico")


func _capture_poison_demo(arena: Arena) -> void:
	for child in arena.enemies_container.get_children():
		child.queue_free()
	var scene: PackedScene = load(INDICATOR_DEMO_SCENE)
	for index in 3:
		var enemy: EnemyBase = scene.instantiate()
		enemy.enemy_type = EnemyBase.EnemyType.COMMON
		enemy.set_arena_bounds(Rect2(Vector2.ZERO, arena.arena_size))
		enemy.position = arena.player.global_position + Vector2.from_angle(TAU * float(index) / 3.0 + 0.4) * POISON_DEMO_DISTANCE
		arena.enemies_container.add_child(enemy)
		enemy.dash_range = 0.0
		enemy.current_hp = 100000.0
		enemy.add_poison(POISON_DEMO_DPS)
	await get_tree().create_timer(POISON_DEMO_SECONDS).timeout
	await _capture("26_veneno_fumaca_e_rastro")


func _capture_ink_drops_demo(arena: Arena) -> void:
	for child in arena.enemies_container.get_children():
		child.queue_free()
	var types: Array = EnemyBase.PRESETS.keys()
	var drops: Array[PaintDrop] = []
	for index in INK_DEMO_COUNT:
		var drop: PaintDrop = PaintDrop.new()
		drop.setup(EnemyBase.PRESETS[types[index % types.size()]]["trail_color"])
		var angle: float = TAU * float(index) / float(INK_DEMO_COUNT) + 0.3
		drop.position = arena.drops_container.to_local(
			arena.player.global_position + Vector2.from_angle(angle) * INK_DEMO_DISTANCE)
		arena.drops_container.add_child(drop)
		drops.append(drop)
	await get_tree().create_timer(INK_DEMO_SETTLE).timeout
	await _capture("28_gotas_de_tinta")
	for drop in drops:
		if is_instance_valid(drop):
			drop.queue_free()


func _capture_paint_mix_demo(arena: Arena) -> void:
	for child in arena.enemies_container.get_children():
		child.queue_free()
	var canvas: PaintCanvas = arena.paint_canvas
	var center: Vector2 = arena.player.global_position + MIX_DEMO_OFFSET
	var red: Color = EnemyBase.PRESETS[EnemyBase.EnemyType.COMMON]["trail_color"]
	var blue: Color = EnemyBase.PRESETS[EnemyBase.EnemyType.FAST]["trail_color"]
	var yellow: Color = EnemyBase.PRESETS[EnemyBase.EnemyType.STALKER]["trail_color"]
	var green: Color = EnemyBase.PRESETS[EnemyBase.EnemyType.TANK]["trail_color"]
	var left: Vector2 = center + Vector2(-MIX_DEMO_HALF * 2.0, 0.0)
	var right: Vector2 = center + Vector2(MIX_DEMO_HALF * 2.0, 0.0)
	canvas.paint_line(left + Vector2(0.0, -60.0), right + Vector2(0.0, -60.0), MIX_DEMO_RADIUS, green)
	canvas.dry_all()
	canvas.paint_line(left + Vector2(0.0, 40.0), right + Vector2(0.0, 40.0), MIX_DEMO_RADIUS, red)
	for index in 3:
		var x: float = -MIX_DEMO_HALF + MIX_DEMO_HALF * float(index)
		var color: Color = [blue, yellow, blue][index]
		canvas.paint_line(center + Vector2(x, -120.0), center + Vector2(x, 100.0), MIX_DEMO_RADIUS, color)
	await _capture("30_mistura_de_tinta")


func _capture_footing_demo(arena: Arena) -> void:
	for child in arena.enemies_container.get_children():
		child.queue_free()
	var canvas: PaintCanvas = arena.paint_canvas
	var start: Vector2 = arena.player.global_position
	var finish: Vector2 = start + Vector2(260.0, 0.0)
	canvas.paint_line(start - Vector2(60.0, 0.0), finish, FOOTING_DEMO_RADIUS,
		EnemyBase.PRESETS[EnemyBase.EnemyType.COMMON]["trail_color"])
	canvas.paint_line(start - Vector2(60.0, 0.0), finish, FOOTING_DEMO_RADIUS,
		EnemyBase.PRESETS[EnemyBase.EnemyType.FAST]["trail_color"])
	Input.action_press("move_right")
	await get_tree().create_timer(FOOTING_DEMO_WALK).timeout
	await _capture_immediately("31_pisando_na_tinta")
	Input.action_release("move_right")
	_keep_player_alive(arena)


func _capture_hurt_edges_demo(arena: Arena) -> void:
	arena.player._invulnerable_timer = 0.0
	arena.player.take_damage(12.0)
	await _capture_immediately("32_borda_de_dano")
	_keep_player_alive(arena)


func _capture_flask_demo(arena: Arena) -> void:
	for child in arena.enemies_container.get_children():
		child.queue_free()
	var saved_slots: int = GameManager.flask_slots
	var saved_palettes: int = GameManager.palettes
	GameManager.flask_slots = FLASK_DEMO_SLOTS
	GameManager.palettes = 2
	arena.hud.flask_bar().refresh()
	arena.hud.update_palettes()

	var colors: Array[Color] = [Color("b43434"), Color("0b35dc"), Color("15b10f"), Color("e0b400")]
	var effects: Array[String] = [
		FlaskEffects.ZIGZAG, FlaskEffects.RUSH, FlaskEffects.BURST, FlaskEffects.ORBIT]
	for index in colors.size():
		var flask: PaintFlask = PaintFlask.new()
		flask.setup(colors[index], [effects[index]])
		flask.position = arena.drops_container.to_local(arena.player.global_position
			+ Vector2.from_angle(PI * 0.75 + TAU * float(index) / 6.0) * FLASK_DEMO_DISTANCE)
		arena.drops_container.add_child(flask)
	var coin: PaletteCoin = PaletteCoin.new()
	coin.position = arena.drops_container.to_local(arena.player.global_position
		+ Vector2(0.0, -FLASK_DEMO_COIN_DISTANCE))
	arena.drops_container.add_child(coin)

	arena.player.flask_belt.store(Color("0b35dc"), [FlaskEffects.RUSH])
	arena.player.flask_belt.store(Color("e0b400"), [FlaskEffects.ORBIT])
	arena.player.flask_belt.store(Color("15b10f"), [FlaskEffects.BURST])
	arena.player.flask_belt.store(Color("b43434"), [FlaskEffects.ZIGZAG])
	arena.player.flask_belt.store(Color("5a08ac"), [FlaskEffects.ZIGZAG, FlaskEffects.RUSH])
	await get_tree().create_timer(FLASK_DEMO_SETTLE).timeout
	await _capture("39_frascos_e_paleta")

	for child in arena.drops_container.get_children():
		child.queue_free()
	arena.player.flask_belt.slots.clear()
	arena.player.flask_belt.store(Color("b43434"), [FlaskEffects.ZIGZAG])
	arena.player.flask_belt.use(0)
	arena.player.set_aim_override(arena.player.global_position + Vector2(260.0, -40.0))
	await get_tree().create_timer(FLASK_DEMO_GLOW).timeout
	for shot in 3:
		arena.ability_controller._fire_ability(arena.ability_controller.abilities[0], Vector2(0.9, -0.15).normalized())
		await get_tree().create_timer(FLASK_DEMO_SHOT_GAP).timeout
	var edges: ScreenEdges = arena.hud.screen_edges()
	for bolt in 3:
		edges._spawn_bolt()
	await _capture_immediately("40_efeito_do_frasco")

	arena.player.flask_belt._clear_effect()
	arena.player.flask_belt.slots.clear()
	arena.hud.flask_bar().refresh()
	GameManager.flask_slots = saved_slots
	GameManager.palettes = saved_palettes
	arena.hud.update_palettes()
	_keep_player_alive(arena)


func _capture_fusion_demo(arena: Arena) -> void:
	for child in arena.enemies_container.get_children():
		child.queue_free()
	var scene: PackedScene = load(INDICATOR_DEMO_SCENE)
	for index in FUSION_DEMO_PAIRS.size():
		var pair: Array = FUSION_DEMO_PAIRS[index]
		var spot: Vector2 = arena.player.global_position \
			+ Vector2.from_angle(PI * 0.25 + TAU * float(index) / FUSION_DEMO_PAIRS.size()) * FUSION_DEMO_DISTANCE
		var members: Array[EnemyBase] = []
		for offset in [-14.0, 14.0]:
			var enemy: EnemyBase = scene.instantiate()
			enemy.enemy_type = pair[members.size()]
			enemy.set_arena_bounds(Rect2(Vector2.ZERO, arena.arena_size))
			enemy.position = spot + Vector2(offset, 0.0)
			arena.enemies_container.add_child(enemy)
			enemy.fusion_chance = 0.0
			members.append(enemy)
		var fused: EnemyBase = members[0].fuse_with(members[1])
		if index == FUSION_DEMO_PAIRS.size() - 1:
			var third: EnemyBase = scene.instantiate()
			third.enemy_type = pair[1]
			third.set_arena_bounds(Rect2(Vector2.ZERO, arena.arena_size))
			third.position = spot + Vector2(28.0, 0.0)
			arena.enemies_container.add_child(third)
			third.fusion_chance = 0.0
			fused.fuse_with(third)
	await get_tree().create_timer(FUSION_DEMO_WALK).timeout
	await _capture_immediately("36_fusoes")
	for child in arena.enemies_container.get_children():
		child.queue_free()
	_keep_player_alive(arena)


func _capture_boss_demo(arena: Arena) -> void:
	for child in arena.enemies_container.get_children():
		child.queue_free()
	var scene: PackedScene = load(INDICATOR_DEMO_SCENE)
	var boss: EnemyBase = scene.instantiate()
	boss.enemy_type = EnemyBase.EnemyType.BOSS
	boss.set_arena_bounds(Rect2(Vector2.ZERO, arena.arena_size))
	boss.position = arena.player.global_position + Vector2(BOSS_DEMO_DISTANCE, -40.0)
	arena.enemies_container.add_child(boss)
	boss.set_physics_process(false)
	arena.hud.track_boss(boss)
	await get_tree().create_timer(BOSS_DEMO_SETTLE).timeout
	await _capture("33_chefe")

	boss.take_damage(1.0e9, false)
	await get_tree().create_timer(BOSS_SHARD_FLIGHT).timeout
	await _capture_immediately("34_estilhacos_do_chefe")
	for child in arena.enemies_container.get_children():
		child.queue_free()
	for child in arena.projectiles_container.get_children():
		child.queue_free()
	_keep_player_alive(arena)

	var divisions: Array[EnemyBase] = []
	for index in 3:
		var division: EnemyBase = scene.instantiate()
		division.enemy_type = EnemyBase.EnemyType.BOSS
		division.generation = ORB_DEMO_GENERATION
		division.set_arena_bounds(Rect2(Vector2.ZERO, arena.arena_size))
		division.position = arena.player.global_position \
			+ Vector2.from_angle(-PI * 0.5 + TAU * float(index) / 3.0) * ORB_DEMO_DISTANCE
		arena.enemies_container.add_child(division)
		division.set_physics_process(false)
		divisions.append(division)
	for volley in ORB_DEMO_VOLLEYS:
		for division in divisions:
			division._shoot_orb(arena.player)
		await get_tree().create_timer(ORB_DEMO_GAP).timeout
	await _capture_immediately("35_bolas_das_divisoes")
	for child in arena.enemies_container.get_children():
		child.queue_free()
	for child in arena.projectiles_container.get_children():
		child.queue_free()
	_keep_player_alive(arena)


func _keep_player_alive(arena: Arena) -> void:
	arena.player._invulnerable_timer = HARNESS_INVULNERABILITY
