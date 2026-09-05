extends Node

const OUTPUT_DIR: String = "user://screenshots"
const SETTLE_FRAMES: int = 12

@export var arena_seconds: float = 8.0

@export var showcase_best_wave: int = 17


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
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

	var image: Image = get_viewport().get_texture().get_image()
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

	menu.get_node("AudioPanel").visible = true
	await _capture("02_menu_som")
	menu.get_node("AudioPanel").visible = false

	AudioManager.set_muted(true)
	await _capture("03_menu_mudo")
	AudioManager.set_muted(false)

	await _clear_scene(menu)


func _capture_creators() -> void:
	var character: Node = _show_scene(GameManager.SCENE_CHARACTER_CREATOR)
	if character != null:
		await _capture("08_criador_personagem")
		await _clear_scene(character)

	var ability: Node = _show_scene(GameManager.SCENE_ABILITY_CREATOR)
	if ability != null:
		await _capture("09_criador_habilidade")
		await _clear_scene(ability)


func _capture_arena() -> void:
	var arena: Node = _show_scene(GameManager.SCENE_ARENA)
	if arena == null:
		return
	await get_tree().create_timer(arena_seconds).timeout
	await _capture("04_arena_minimapa")

	arena.get_node("PauseScreen").open()
	await _capture("05_arena_pausa")
	arena.get_node("PauseScreen").close()

	var controller: AbilityController = arena.get_node("Player/AbilityController")
	arena.get_node("ProgressionScreen").open(5, controller.get_abilities())
	await _capture("10_arena_progressao")
	arena.get_node("ProgressionScreen").close()

	await _clear_scene(arena)


func _capture_game_over() -> void:
	GameManager.last_wave_reached = 12
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
