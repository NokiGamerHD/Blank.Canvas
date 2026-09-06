extends Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await _probe_paused_game_over()
	await _probe_pause_survives_scene_teardown()
	await _probe_escape_while_dead()
	await _probe_change_scene_clears_pause()


func _probe_paused_game_over() -> void:
	print("--- A: game over herda a arvore pausada ---")
	var screen: Control = load(GameManager.SCENE_GAME_OVER).instantiate() as Control
	get_tree().root.add_child.call_deferred(screen)
	await get_tree().process_frame
	await get_tree().process_frame

	var retry: Button = screen.get_node("CenterContainer/MenuContainer/RetryButton") as Button
	print("  process_mode da tela: %d (0 = INHERIT = pausavel)" % screen.process_mode)
	print("  paused=false -> botao processa: %s" % retry.can_process())
	get_tree().paused = true
	await get_tree().process_frame
	print("  paused=true  -> botao processa: %s" % retry.can_process())

	get_tree().paused = false
	screen.queue_free()
	await get_tree().process_frame


func _probe_pause_survives_scene_teardown() -> void:
	print("--- B: pausa sobrevive a destruicao da cena ---")
	var arena: Arena = _build_arena()
	await get_tree().process_frame

	arena.pause_screen.open()
	print("  pausa aberta            -> paused = %s" % get_tree().paused)

	arena.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	print("  arena destruida         -> paused = %s" % get_tree().paused)
	print("  ninguem restou para despausar")
	get_tree().paused = false


func _probe_escape_while_dead() -> void:
	print("--- C: ESC continua abrindo a pausa com o jogador morto ---")
	var arena: Arena = _build_arena()
	await get_tree().process_frame

	arena.player.take_damage(arena.player.max_hp)
	print("  jogador morto           -> is_dead reportado pelo player")

	var escape: InputEventKey = InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	arena._unhandled_input(escape)
	await get_tree().process_frame

	print("  ESC apos a morte        -> pausa visivel = %s" % arena.pause_screen.visible)
	print("  ESC apos a morte        -> paused = %s" % get_tree().paused)

	arena.queue_free()
	await get_tree().process_frame
	get_tree().paused = false


func _probe_change_scene_clears_pause() -> void:
	print("--- D: troca de cena limpa a pausa ---")
	var watcher: Node = Node.new()
	watcher.set_script(load("res://scripts/test/pause_watcher.gd"))
	get_tree().root.add_child.call_deferred(watcher)
	await get_tree().process_frame
	await get_tree().process_frame

	get_tree().paused = true
	print("  antes da troca          -> paused = %s" % get_tree().paused)
	print("  change_scene aceitou    -> %s" % GameManager.go_to_main_menu())


func _build_arena() -> Arena:
	GameManager.set_character_drawing(_placeholder(Color("3f6fd9")))
	GameManager.set_ability_drawing(0, _placeholder(Color("f2913d")))
	var arena: Arena = load(GameManager.SCENE_ARENA).instantiate() as Arena
	arena.arena_size = Vector2(512, 512)
	add_child(arena)
	arena.paint_canvas.remove_from_group("paint_canvas")
	return arena


func _placeholder(color: Color) -> Image:
	var image: Image = Image.create(36, 36, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for y in 36:
		for x in 36:
			if Vector2(x, y).distance_to(Vector2(17.5, 17.5)) <= 15.0:
				image.set_pixel(x, y, color)
	return image
