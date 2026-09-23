extends Node

const PLAYER_SPOT: Vector2 = Vector2(1100.0, 1100.0)
const PANEL_TEXT_WIDTH: int = 396
const LABEL_TEXT_WIDTH: int = 180

var _arena: Arena = null
var _screen: SettingsScreen = null
var _failures: int = 0
var _saved_shake: bool = true
var _saved_numbers: bool = true
var _saved_controls: Dictionary = {}
var _saved_muted: bool = false
var _saved_volume: float = 1.0
var _saved_language: String = ""
var _saved_fullscreen: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_saved_muted = AudioManager.muted
	_saved_volume = AudioManager.volume
	_saved_language = LocalizationManager.language_code
	_saved_fullscreen = GameManager.fullscreen
	_saved_shake = GameManager.screen_shake
	_saved_numbers = GameManager.damage_numbers
	for action in GameManager.REBINDABLE_ACTIONS:
		_saved_controls[action] = InputMap.action_get_events(action).duplicate()

	_arena = load(GameManager.SCENE_ARENA).instantiate() as Arena
	_arena.arena_size = Vector2(2200.0, 2200.0)
	(_arena.get_node("WaveManager") as WaveManager).first_wave_delay = 9000.0
	add_child(_arena)
	_arena.paint_canvas.remove_from_group("paint_canvas")
	_arena.ability_controller.set_physics_process(false)
	_arena.player.global_position = PLAYER_SPOT
	_screen = SettingsScreen.new()
	add_child(_screen)
	await get_tree().process_frame
	await get_tree().process_frame

	_check_defaults_and_persistence()
	await _check_screen_shake_toggle()
	_check_damage_numbers_toggle()
	await _check_rebinding()
	_check_labels()
	await _check_screen_toggles()
	await _check_wave_banner()
	await _check_boss_banner()
	_check_texts_fit()
	await _check_menu_buttons()

	_restore()
	print("falhas: %d" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _report(label: String, passed: bool, detail: String) -> void:
	if not passed:
		_failures += 1
	print("%s %s %s" % ["ok  " if passed else "FALHA", label, detail])


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _restore() -> void:
	AudioManager.muted = _saved_muted
	AudioManager.volume = _saved_volume
	AudioManager.save_settings()
	LocalizationManager.set_language(_saved_language)
	GameManager.set_fullscreen(_saved_fullscreen)
	GameManager.set_screen_shake(_saved_shake)
	GameManager.set_damage_numbers(_saved_numbers)
	for action in _saved_controls:
		InputMap.action_erase_events(action)
		for event in _saved_controls[action]:
			InputMap.action_add_event(action, event)
	GameManager._save_controls()


func _stored(section: String, key: String, fallback: Variant) -> Variant:
	var settings: ConfigFile = ConfigFile.new()
	if settings.load(GameManager.SETTINGS_PATH) != OK:
		return fallback
	return settings.get_value(section, key, fallback)


func _check_defaults_and_persistence() -> void:
	GameManager.set_screen_shake(false)
	GameManager.set_damage_numbers(false)
	var saved_off: bool = _stored(GameManager.GAMEPLAY_SECTION, GameManager.SCREEN_SHAKE_KEY, true) == false \
		and _stored(GameManager.GAMEPLAY_SECTION, GameManager.DAMAGE_NUMBERS_KEY, true) == false
	GameManager.set_screen_shake(true)
	GameManager.set_damage_numbers(true)
	var saved_on: bool = _stored(GameManager.GAMEPLAY_SECTION, GameManager.SCREEN_SHAKE_KEY, false) == true
	var kept_others: bool = _stored(GameManager.PROGRESS_SECTION, GameManager.BEST_WAVE_KEY, -1) != -1 \
		or GameManager.best_wave == 0
	_report("opcoes de jogo ficam salvas no settings.cfg sem apagar as outras secoes",
		saved_off and saved_on and kept_others,
		"gravou_desligado=%s gravou_ligado=%s manteve_progresso=%s" % [saved_off, saved_on, kept_others])


func _check_screen_shake_toggle() -> void:
	var player: Player = _arena.player
	GameManager.set_screen_shake(false)
	player.camera.offset = Vector2.ZERO
	player.shake(9.0)
	await get_tree().process_frame
	await get_tree().process_frame
	var still: bool = player.camera.offset.is_zero_approx()
	GameManager.set_screen_shake(true)
	player.shake(9.0)
	await get_tree().process_frame
	await get_tree().process_frame
	var shook: bool = not player.camera.offset.is_zero_approx()
	await _wait(0.8)
	_report("desligar o tremor de tela para a camera, e ligar volta a sacudir",
		still and shook, "desligado_parado=%s ligado_sacode=%s" % [still, shook])


func _damage_numbers_in_scene() -> int:
	var count: int = 0
	for child in _arena.get_node("Effects").get_children():
		if child is DamageNumber:
			count += 1
	return count


func _check_damage_numbers_toggle() -> void:
	for child in _arena.get_node("Effects").get_children():
		child.free()
	var enemy: EnemyBase = _arena.wave_manager._spawn_enemy(
		EnemyBase.EnemyType.COMMON, PLAYER_SPOT + Vector2(300.0, 0.0))
	enemy.set_physics_process(false)
	GameManager.set_damage_numbers(false)
	enemy.take_damage(1.0, false)
	var hidden: bool = _damage_numbers_in_scene() == 0
	GameManager.set_damage_numbers(true)
	enemy.take_damage(1.0, false)
	var shown: bool = _damage_numbers_in_scene() == 1
	enemy.free()
	for child in _arena.get_node("Effects").get_children():
		child.free()
	_report("desligar os numeros de dano tira eles da tela, e ligar traz de volta",
		hidden and shown, "desligado=%d numero(s) ligado=%d numero(s)" % [0 if hidden else 1, 1 if shown else 0])


func _check_rebinding() -> void:
	var key: InputEventKey = InputEventKey.new()
	key.physical_keycode = KEY_Q
	var applied: bool = GameManager.rebind_action("dash", key)
	var in_map: bool = InputMap.event_is_action(key, "dash")
	var label: String = GameManager.action_label("dash")
	var stored: String = str(_stored(GameManager.CONTROLS_SECTION, "dash", ""))
	var refused: bool = not GameManager.rebind_action("ui_cancel", key)

	GameManager.reset_controls()
	var back_to_space: bool = GameManager.action_label("dash") == "SPACE" and not InputMap.event_is_action(key, "dash")
	var mouse_label: String = GameManager.action_label("fire")
	_report("trocar a tecla vale na hora, fica salva e o padrao volta",
		applied and in_map and label == "Q" and stored == "key:%d" % KEY_Q and refused and back_to_space,
		"aplicou=%s no_mapa=%s rotulo=%s salvo=%s recusou_acao_fixa=%s voltou=%s tiro=%s" % [
			applied, in_map, label, stored, refused, back_to_space, mouse_label])
	await get_tree().process_frame


func _check_labels() -> void:
	var fire_label: String = GameManager.action_label("fire")
	var dash_label: String = GameManager.action_label("dash")
	var up_label: String = GameManager.action_label("move_up")
	_report("cada acao mostra a tecla dela, e o tiro mostra o botao do mouse",
		fire_label == LocalizationManager.text("settings.mouse_button", [MOUSE_BUTTON_LEFT]) \
			and dash_label == "SPACE" and up_label == "W",
		"tiro=%s dash=%s andar_para_cima=%s" % [fire_label, dash_label, up_label])


func _check_screen_toggles() -> void:
	_screen.open()
	await get_tree().process_frame
	var opened: bool = _screen.is_open()
	var shake_before: bool = GameManager.screen_shake
	_screen._shake_button.pressed.emit()
	var shake_changed: bool = GameManager.screen_shake != shake_before
	var numbers_before: bool = GameManager.damage_numbers
	_screen._numbers_button.pressed.emit()
	var numbers_changed: bool = GameManager.damage_numbers != numbers_before

	_screen.action_button("move_up").pressed.emit()
	var waiting: bool = _screen.is_waiting_for_key() \
		and _screen.action_button("move_up").text == LocalizationManager.text("settings.press_key")
	var key: InputEventKey = InputEventKey.new()
	key.physical_keycode = KEY_T
	key.pressed = true
	Input.parse_input_event(key)
	await get_tree().process_frame
	await get_tree().process_frame
	var rebound: bool = not _screen.is_waiting_for_key() and GameManager.action_label("move_up") == "T"
	_screen._reset_button.pressed.emit()
	var reset: bool = GameManager.action_label("move_up") == "W"
	_screen.close()
	GameManager.set_screen_shake(true)
	GameManager.set_damage_numbers(true)
	_report("a tela de opcoes liga e desliga as opcoes e troca a tecla pelo botao",
		opened and shake_changed and numbers_changed and waiting and rebound and reset and not _screen.is_open(),
		"abriu=%s tremor=%s numeros=%s esperou_tecla=%s trocou=%s restaurou=%s" % [
			opened, shake_changed, numbers_changed, waiting, rebound, reset])


func _check_wave_banner() -> void:
	var banner: WaveBanner = _arena.hud.wave_banner()
	AudioManager._last_played.erase(AudioManager.WAVE_START_SOUND)
	_arena.wave_manager.wave_changed.emit(4)
	await get_tree().process_frame
	var showing: bool = banner.is_showing()
	var text: String = banner.text()
	var sounded: bool = AudioManager._last_played.has(AudioManager.WAVE_START_SOUND)
	await _wait(WaveBanner.FADE_IN + WaveBanner.HOLD + WaveBanner.FADE_OUT + 0.3)
	var gone: bool = not banner.is_showing()
	_report("passar de wave mostra o aviso com o numero, toca o som e some sozinho",
		showing and text == LocalizationManager.text("hud.wave_banner", [4]) and sounded and gone,
		"apareceu=%s texto=%s som=%s sumiu=%s" % [showing, text, sounded, gone])


func _check_boss_banner() -> void:
	var banner: WaveBanner = _arena.hud.wave_banner()
	var player: Player = _arena.player
	AudioManager._last_played.erase(AudioManager.BOSS_WAVE_SOUND)
	AudioManager._last_played.erase(AudioManager.WAVE_START_SOUND)
	player.camera.offset = Vector2.ZERO
	_arena.wave_manager.wave_changed.emit(10)
	await get_tree().process_frame
	await get_tree().process_frame
	var text: String = banner.text()
	var boss_sound: bool = AudioManager._last_played.has(AudioManager.BOSS_WAVE_SOUND)
	var wave_sound: bool = AudioManager._last_played.has(AudioManager.WAVE_START_SOUND)
	var shook: bool = false
	for i in 10:
		if not player.camera.offset.is_zero_approx():
			shook = true
			break
		await get_tree().process_frame
	await _wait(0.9)
	_report("wave de chefe tem aviso e som proprios, diferentes da wave comum",
		text == LocalizationManager.text("hud.boss_banner") and boss_sound and not wave_sound and shook,
		"texto=%s som_do_chefe=%s som_comum=%s sacudiu=%s" % [text, boss_sound, wave_sound, shook])


func _check_menu_buttons() -> void:
	var menu: Node = load(GameManager.SCENE_MAIN_MENU).instantiate()
	add_child(menu)
	await get_tree().process_frame
	var buttons: Array[Button] = [
		menu.play_button, menu.quick_play_button, menu.settings_button, menu.quit_button,
	]
	var keys: Array[String] = ["menu.play", "menu.quick_play", "menu.settings", "menu.quit"]
	var font_size: int = buttons[0].get_theme_font_size("font_size")
	var same_size: bool = true
	for button in buttons:
		same_size = same_size and button.get_theme_font_size("font_size") == font_size

	var style: StyleBox = buttons[0].get_theme_stylebox("normal")
	var usable: float = buttons[0].size.x - style.content_margin_left - style.content_margin_right
	var font: Font = buttons[0].get_theme_font("font")
	var widest: float = 0.0
	var widest_text: String = ""
	for code in LocalizationManager.TRANSLATIONS:
		var table: Dictionary = LocalizationManager.TRANSLATIONS[code]
		for key in keys:
			var width: float = font.get_string_size(
				str(table[key]), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			if width > widest:
				widest = width
				widest_text = str(table[key])
	menu.queue_free()
	_report("os quatro botoes do menu usam a mesma fonte e cabem nos dois idiomas",
		same_size and widest <= usable,
		"tamanho=%d mesmo_tamanho=%s mais_largo=%.0f px (%s) de %.0f px uteis" % [
			font_size, same_size, widest, widest_text, usable])
	await get_tree().process_frame


func _text_width(message: String, font_size: int) -> int:
	var font: Font = _screen._back_button.get_theme_font("font")
	return int(ceil(font.get_string_size(message, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x))


func _check_texts_fit() -> void:
	var widest: int = 0
	var widest_text: String = ""
	var fits: bool = true
	for code in LocalizationManager.TRANSLATIONS:
		var table: Dictionary = LocalizationManager.TRANSLATIONS[code]
		for key in table:
			if not String(key).begins_with("settings.") and key != "hud.boss_banner":
				continue
			var message: String = str(table[key])
			if message.contains("%"):
				continue
			var font_size: int = SettingsScreen.LABEL_FONT_SIZE if key.begins_with("settings.action_") \
				else SettingsScreen.ROW_FONT_SIZE
			var limit: int = LABEL_TEXT_WIDTH if key.begins_with("settings.action_") else PANEL_TEXT_WIDTH
			var width: int = _text_width(message, font_size)
			if key == "settings.fullscreen" or key == "settings.screen_shake" or key == "settings.damage_numbers":
				width = _text_width("%s: %s" % [message, table["settings.off"]], font_size)
			if width > widest:
				widest = width
				widest_text = message
			fits = fits and width <= limit
	_report("todo texto das opcoes cabe na janela nos dois idiomas", fits,
		"mais_largo=%d px (%s)" % [widest, widest_text])
