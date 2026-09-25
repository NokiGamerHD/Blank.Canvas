extends Node

const PLAYER_SPOT: Vector2 = Vector2(1100.0, 1100.0)
const PANEL_TEXT_WIDTH: int = 396
const LABEL_TEXT_WIDTH: int = 180
const EXPECTED_CHECKS: int = 13

var _arena: Arena = null
var _screen: SettingsScreen = null
var _failures: int = 0
var _checks: int = 0
var _saved_shake: bool = true
var _saved_numbers: bool = true
var _saved_controls: Dictionary = {}
var _saved_muted: bool = false
var _saved_volume: float = 1.0
var _saved_language: String = ""
var _saved_fullscreen: bool = false
var _saved_music: float = 0.6


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_saved_muted = AudioManager.muted
	_saved_volume = AudioManager.volume
	_saved_language = LocalizationManager.language_code
	_saved_fullscreen = GameManager.fullscreen
	_saved_music = MusicManager.volume
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
	await _check_music()
	await _check_credits()
	await _check_erase_save()
	_check_texts_fit()
	await _check_menu_buttons()

	_restore()
	if _checks != EXPECTED_CHECKS:
		_failures += 1
		print("FALHA checagens incompletas: %d de %d" % [_checks, EXPECTED_CHECKS])
	print("checagens: %d  falhas: %d" % [_checks, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _report(label: String, passed: bool, detail: String) -> void:
	_checks += 1
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
	MusicManager.set_volume(_saved_music)
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
		menu.play_button, menu.quick_play_button, menu.settings_button, menu.credits_button,
		menu.quit_button,
	]
	var keys: Array[String] = [
		"menu.play", "menu.quick_play", "menu.settings", "menu.credits", "menu.quit",
	]
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
	_report("os cinco botoes do menu usam a mesma fonte e cabem nos dois idiomas",
		same_size and widest <= usable,
		"tamanho=%d mesmo_tamanho=%s mais_largo=%.0f px (%s) de %.0f px uteis" % [
			font_size, same_size, widest, widest_text, usable])
	await get_tree().process_frame


func _text_width(message: String, font_size: int) -> int:
	var font: Font = _screen._back_button.get_theme_font("font")
	return int(ceil(font.get_string_size(message, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x))


func _check_music() -> void:
	AudioManager.set_muted(false)
	var installed: bool = MusicManager.has_track(MusicManager.MENU_TRACK) \
		and MusicManager.has_track(MusicManager.ARENA_TRACK) \
		and MusicManager.has_track(MusicManager.BOSS_TRACK)
	var looping: bool = true
	for track in MusicManager.track_names():
		var stream: AudioStream = MusicManager._tracks[track]
		looping = looping and stream is AudioStreamOggVorbis and (stream as AudioStreamOggVorbis).loop
	var refused: bool = not MusicManager.play("faixa_que_nao_existe")
	await get_tree().create_timer(MusicManager.FADE_TIME + 0.2).timeout
	var missing: bool = refused and not MusicManager.is_playing()

	MusicManager.set_volume(0.8)
	var started: bool = MusicManager.play_arena()
	await get_tree().create_timer(MusicManager.FADE_TIME + 0.2).timeout
	var playing: bool = MusicManager.is_playing() and MusicManager.current_track() == MusicManager.ARENA_TRACK
	var first_player: int = MusicManager._active
	MusicManager.play_boss()
	var swapped: bool = MusicManager._active != first_player
	await get_tree().create_timer(MusicManager.FADE_TIME + 0.2).timeout
	var on_boss: bool = MusicManager.current_track() == MusicManager.BOSS_TRACK

	AudioManager.set_muted(true)
	var muted_db: float = MusicManager._players[MusicManager._active].volume_db
	AudioManager.set_muted(false)
	await get_tree().create_timer(MusicManager.FADE_TIME + 0.2).timeout
	var resumed: bool = MusicManager.is_playing() \
		and MusicManager.current_track() == MusicManager.BOSS_TRACK
	MusicManager.stop()

	MusicManager.set_volume(0.35)
	var settings: ConfigFile = ConfigFile.new()
	settings.load(GameManager.SETTINGS_PATH)
	var saved: bool = is_equal_approx(
		float(settings.get_value(MusicManager.AUDIO_SECTION, MusicManager.MUSIC_VOLUME_KEY, -1.0)), 0.35)
	_screen._apply_values()
	var slider_ok: bool = _screen._music_slider != null \
		and is_equal_approx(_screen._music_slider.value, 0.35) \
		and _screen._music_label.text.contains("35")

	_report("as tres faixas estao instaladas, tocam em loop, trocam com fade e respeitam mudo e volume",
		installed and looping and missing and started and playing and swapped and on_boss
			and is_equal_approx(muted_db, MusicManager.SILENT_DB) and resumed and saved and slider_ok,
		"instaladas=%s loop=%s faixa_inexistente=%s tocou=%s tocando=%s trocou=%s no_chefe=%s mudo=%.0fdB voltou_ao_desmutar=%s salvo=%s slider=%s" % [
			installed, looping, missing, started, playing, swapped, on_boss, muted_db, resumed,
			saved, slider_ok])


func _check_credits() -> void:
	var credits: CreditsScreen = CreditsScreen.new()
	add_child(credits)
	await get_tree().process_frame
	var closed_at_start: bool = not credits.is_open()
	credits.open()
	await get_tree().process_frame
	var opened: bool = credits.is_open()
	var lines: PackedStringArray = credits.line_texts()
	var has_music_line: bool = false
	var all_translated: bool = true
	for line in lines:
		if line.contains("music") or line.contains("Música") or line.contains("Music"):
			has_music_line = true
		if line.begins_with("credits."):
			all_translated = false
	credits.close()
	var closed: bool = not credits.is_open()

	var music_label: Label = null
	for label in credits._labels:
		if label.has_meta("needs_music"):
			music_label = label
	var music_shown: bool = music_label != null and music_label.visible
	var installed: Dictionary = MusicManager._tracks.duplicate()
	MusicManager._tracks.clear()
	credits._apply_translations()
	var music_hidden: bool = music_label != null and not music_label.visible
	MusicManager._tracks = installed
	credits._apply_translations()

	var font: Font = credits._back_button.get_theme_font("font")
	var widest: float = 0.0
	var fits: bool = true
	for language in ["en", "pt_BR"]:
		var table: Dictionary = LocalizationManager.TRANSLATIONS[language]
		for label in credits._labels:
			var key: String = str(label.get_meta("key"))
			var size: float = font.get_string_size(str(table.get(key, "")), HORIZONTAL_ALIGNMENT_LEFT, -1,
				label.get_theme_font_size("font_size")).x
			widest = maxf(widest, size)
			if size > float(CreditsScreen.PANEL_WIDTH) - 40.0:
				fits = false
				print("  largo demais %s: %s" % [language, table.get(key, "")])
	credits.queue_free()

	_report("tela de creditos abre, lista as secoes traduzidas e cabe no painel",
		closed_at_start and opened and closed and lines.size() >= 6 and has_music_line
			and all_translated and fits and music_hidden and music_shown,
		"abriu=%s linhas=%d musica=%s oculta_sem_faixa=%s visivel_com_faixa=%s traduzido=%s mais_largo=%.0f px de %.0f" % [
			opened, lines.size(), has_music_line, music_hidden, music_shown, all_translated, widest,
			float(CreditsScreen.PANEL_WIDTH) - 40.0])


func _check_erase_save() -> void:
	var backup: Dictionary = {}
	var dir: DirAccess = DirAccess.open(GameManager.DRAWINGS_DIR)
	if dir != null:
		for file_name in dir.get_files():
			backup[file_name] = FileAccess.get_file_as_bytes("%s/%s" % [GameManager.DRAWINGS_DIR, file_name])
	var saved_best: int = GameManager.best_wave
	var saved_palettes: int = GameManager.palettes
	var saved_slots: int = GameManager.flask_slots
	var saved_colors: PackedColorArray = GameManager.custom_colors.duplicate()

	var drawing: Image = Image.create(36, 36, false, Image.FORMAT_RGBA8)
	drawing.fill(Color("f2913d"))
	GameManager.set_character_drawing(drawing)
	GameManager.set_ability_drawing(0, drawing)
	GameManager.save_character_drawing_to_disk()
	GameManager.save_ability_drawing_to_disk(0)
	GameManager.best_wave = 12
	GameManager.palettes = 4
	GameManager.flask_slots = 3
	GameManager.custom_colors = PackedColorArray([Color.RED])
	GameManager._save_progress()
	GameManager._save_custom_colors()
	var had_drawings: bool = GameManager.has_saved_drawings()

	var locked: SettingsScreen = SettingsScreen.new()
	locked.allow_erase = false
	add_child(locked)
	await get_tree().process_frame
	var hidden_in_run: bool = not locked._erase_button.visible
	locked.queue_free()

	_screen.open()
	_screen._erase_button.pressed.emit()
	var armed: bool = _screen._erase_button.text == LocalizationManager.text("settings.erase_confirm")
	var kept: bool = GameManager.best_wave == 12 and GameManager.has_saved_drawings()
	_screen._erase_button.pressed.emit()
	await get_tree().process_frame

	var cleared: bool = not GameManager.has_saved_drawings()
	var zeroed: bool = GameManager.best_wave == 0 and GameManager.palettes == 0 \
		and GameManager.flask_slots == FlaskEffects.START_SLOTS and GameManager.custom_colors.is_empty()
	var on_disk: bool = int(_stored(GameManager.PROGRESS_SECTION, GameManager.BEST_WAVE_KEY, -1)) == 0 \
		and int(_stored(GameManager.PROGRESS_SECTION, GameManager.FLASK_SLOTS_KEY, -1)) == FlaskEffects.START_SLOTS
	var kept_language: bool = str(_stored(LocalizationManager.SETTINGS_SECTION, "code", "")) != ""
	var announced: bool = _screen._erase_button.text == LocalizationManager.text("settings.erase_done")
	_screen.close()

	for file_name in backup:
		var file: FileAccess = FileAccess.open("%s/%s" % [GameManager.DRAWINGS_DIR, file_name], FileAccess.WRITE)
		if file != null:
			file.store_buffer(backup[file_name])
			file.close()
	GameManager.best_wave = saved_best
	GameManager.palettes = saved_palettes
	GameManager.flask_slots = saved_slots
	GameManager.custom_colors = saved_colors
	GameManager._save_progress()
	GameManager._save_custom_colors()
	var restored: bool = GameManager.best_wave == saved_best \
		and int(_stored(GameManager.PROGRESS_SECTION, GameManager.BEST_WAVE_KEY, -1)) == saved_best

	_report("apagar dados pede confirmacao, zera desenhos e progresso e nao aparece em partida",
		had_drawings and hidden_in_run and armed and kept and cleared and zeroed and on_disk
			and kept_language and announced and restored,
		"tinha=%s oculto_em_partida=%s armou=%s manteve=%s apagou=%s zerou=%s disco=%s idioma=%s aviso=%s devolveu=%s" % [
			had_drawings, hidden_in_run, armed, kept, cleared, zeroed, on_disk, kept_language,
			announced, restored])


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
