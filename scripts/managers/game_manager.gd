extends Node

signal settings_changed


const DISPLAY_NAME: String = "Blank Canvas"

const VERSION: String = "3.2.4"


const SCENE_MAIN_MENU: String = "res://scenes/menu/main_menu.tscn"
const SCENE_CHARACTER_CREATOR: String = "res://scenes/character_creator/character_creator.tscn"
const SCENE_ABILITY_CREATOR: String = "res://scenes/ability_creator/ability_creator.tscn"
const SCENE_ARENA: String = "res://scenes/game/arena.tscn"
const SCENE_GAME_OVER: String = "res://scenes/ui/game_over.tscn"
const SCENE_SCENARIO_VIEWER: String = "res://scenes/ui/scenario_viewer.tscn"


const DRAWINGS_DIR: String = "user://drawings"
const CHARACTER_DRAWING_PATH: String = "user://drawings/character.png"
const SAVED_SCENARIOS_DIR: String = "user://saved_scenarios"


const SETTINGS_PATH: String = "user://settings.cfg"
const SHOT_TYPES_SECTION: String = "shot_types"
const PROGRESS_SECTION: String = "progress"
const BEST_WAVE_KEY: String = "best_wave"
const PALETTES_KEY: String = "palettes"
const FLASK_SLOTS_KEY: String = "flask_slots"
const PALETTE_SECTION: String = "palette"
const CUSTOM_COLORS_KEY: String = "custom_colors"
const MAX_CUSTOM_COLORS: int = 10
const DISPLAY_SECTION: String = "display"
const FULLSCREEN_KEY: String = "fullscreen"
const GAMEPLAY_SECTION: String = "gameplay"
const SCREEN_SHAKE_KEY: String = "screen_shake"
const DAMAGE_NUMBERS_KEY: String = "damage_numbers"
const CONTROLS_SECTION: String = "controls"
const REBINDABLE_ACTIONS: Array[String] = [
	"move_up", "move_down", "move_left", "move_right", "fire", "dash",
]


var character_image: Image = null

var ability_images: Array[Image] = []
var ability_shot_types: Array[int] = []

var last_wave_reached: int = 0

var last_canvas_snapshot: Image = null

var last_canvas_coverage: float = 0.0

var last_saved_scenario_path: String = ""

var best_wave: int = 0

var palettes: int = 0

var flask_slots: int = FlaskEffects.START_SLOTS

var last_run_was_record: bool = false

var custom_colors: PackedColorArray = PackedColorArray()

var fullscreen: bool = false

var screen_shake: bool = true

var damage_numbers: bool = true

var _default_events: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_progress()
	_load_custom_colors()
	_store_default_events()
	_load_preferences()
	_load_controls()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		toggle_fullscreen()


func toggle_fullscreen() -> void:
	set_fullscreen(not is_fullscreen())


func is_fullscreen() -> bool:
	var mode: int = DisplayServer.window_get_mode()
	return mode == DisplayServer.WINDOW_MODE_FULLSCREEN \
		or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN


func set_fullscreen(value: bool) -> void:
	fullscreen = value
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if value else DisplayServer.WINDOW_MODE_WINDOWED)
	_save_preferences()
	settings_changed.emit()


func set_screen_shake(value: bool) -> void:
	screen_shake = value
	_save_preferences()
	settings_changed.emit()


func set_damage_numbers(value: bool) -> void:
	damage_numbers = value
	_save_preferences()
	settings_changed.emit()


func _load_preferences() -> void:
	var settings: ConfigFile = ConfigFile.new()
	if settings.load(SETTINGS_PATH) != OK:
		return
	screen_shake = bool(settings.get_value(GAMEPLAY_SECTION, SCREEN_SHAKE_KEY, true))
	damage_numbers = bool(settings.get_value(GAMEPLAY_SECTION, DAMAGE_NUMBERS_KEY, true))
	fullscreen = bool(settings.get_value(DISPLAY_SECTION, FULLSCREEN_KEY, false))
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func _save_preferences() -> void:
	var settings: ConfigFile = ConfigFile.new()
	settings.load(SETTINGS_PATH)
	settings.set_value(GAMEPLAY_SECTION, SCREEN_SHAKE_KEY, screen_shake)
	settings.set_value(GAMEPLAY_SECTION, DAMAGE_NUMBERS_KEY, damage_numbers)
	settings.set_value(DISPLAY_SECTION, FULLSCREEN_KEY, fullscreen)
	var save_error: int = settings.save(SETTINGS_PATH)
	if save_error != OK:
		push_warning("[GameManager] Não foi possível salvar as preferências (erro %d)." % save_error)


func _store_default_events() -> void:
	for action in REBINDABLE_ACTIONS:
		if InputMap.has_action(action):
			_default_events[action] = InputMap.action_get_events(action).duplicate()


func rebind_action(action: String, event: InputEvent) -> bool:
	if not REBINDABLE_ACTIONS.has(action) or not InputMap.has_action(action):
		push_warning("[GameManager] Ação desconhecida para remapear: %s." % action)
		return false
	if not (event is InputEventKey or event is InputEventMouseButton):
		return false
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, event)
	_save_controls()
	settings_changed.emit()
	return true


func reset_controls() -> void:
	for action in REBINDABLE_ACTIONS:
		if not _default_events.has(action):
			continue
		InputMap.action_erase_events(action)
		for event in _default_events[action]:
			InputMap.action_add_event(action, event)
	_save_controls()
	settings_changed.emit()


func action_label(action: String) -> String:
	if not InputMap.has_action(action):
		return "-"
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
			return OS.get_keycode_string(code).to_upper()
		if event is InputEventMouseButton:
			return LocalizationManager.text("settings.mouse_button", [event.button_index])
	return "-"


func _event_to_text(event: InputEvent) -> String:
	if event is InputEventKey:
		var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		return "key:%d" % code
	if event is InputEventMouseButton:
		return "mouse:%d" % event.button_index
	return ""


func _event_from_text(description: String) -> InputEvent:
	var parts: PackedStringArray = description.split(":")
	if parts.size() != 2 or not parts[1].is_valid_int():
		return null
	if parts[0] == "key":
		var key: InputEventKey = InputEventKey.new()
		key.physical_keycode = int(parts[1])
		return key
	if parts[0] == "mouse":
		var button: InputEventMouseButton = InputEventMouseButton.new()
		button.button_index = int(parts[1])
		return button
	return null


func _load_controls() -> void:
	var settings: ConfigFile = ConfigFile.new()
	if settings.load(SETTINGS_PATH) != OK:
		return
	for action in REBINDABLE_ACTIONS:
		var description: String = str(settings.get_value(CONTROLS_SECTION, action, ""))
		if description.is_empty() or not InputMap.has_action(action):
			continue
		var event: InputEvent = _event_from_text(description)
		if event == null:
			push_warning("[GameManager] Controle salvo em formato inesperado (%s), usando o padrão." % description)
			continue
		InputMap.action_erase_events(action)
		InputMap.action_add_event(action, event)


func _save_controls() -> void:
	var settings: ConfigFile = ConfigFile.new()
	settings.load(SETTINGS_PATH)
	for action in REBINDABLE_ACTIONS:
		var events: Array[InputEvent] = InputMap.action_get_events(action)
		settings.set_value(CONTROLS_SECTION, action, _event_to_text(events[0]) if not events.is_empty() else "")
	var save_error: int = settings.save(SETTINGS_PATH)
	if save_error != OK:
		push_warning("[GameManager] Não foi possível salvar os controles (erro %d)." % save_error)


func change_scene(scene_path: String) -> bool:
	if not ResourceLoader.exists(scene_path):
		push_warning("[GameManager] Cena ainda não implementada: %s" % scene_path)
		return false
	TransitionManager.play_transition(func() -> void:
		get_tree().paused = false
		get_tree().change_scene_to_file(scene_path)
	)
	return true


func go_to_main_menu() -> bool:
	return change_scene(SCENE_MAIN_MENU)


func go_to_character_creator() -> bool:
	return change_scene(SCENE_CHARACTER_CREATOR)


func go_to_ability_creator() -> bool:
	return change_scene(SCENE_ABILITY_CREATOR)


func go_to_arena() -> bool:
	return change_scene(SCENE_ARENA)


func go_to_game_over() -> bool:
	return change_scene(SCENE_GAME_OVER)


func quit_game() -> void:
	get_tree().quit()


func reset_run_data() -> void:
	character_image = null
	ability_images.clear()
	ability_shot_types.clear()
	last_wave_reached = 0
	last_canvas_snapshot = null
	last_canvas_coverage = 0.0
	last_run_was_record = false


func set_wave_reached(wave: int) -> void:
	last_wave_reached = wave
	if wave <= best_wave:
		return
	best_wave = wave
	last_run_was_record = true
	_save_progress()


func add_palettes(amount: int) -> void:
	if amount <= 0:
		return
	palettes += amount
	_save_progress()
	settings_changed.emit()


func can_buy_flask_slot() -> bool:
	return flask_slots < FlaskEffects.MAX_SLOTS and palettes >= FlaskEffects.SLOT_PRICE


func buy_flask_slot() -> bool:
	if not can_buy_flask_slot():
		return false
	palettes -= FlaskEffects.SLOT_PRICE
	flask_slots += 1
	_save_progress()
	settings_changed.emit()
	return true


func _load_progress() -> void:
	var settings: ConfigFile = ConfigFile.new()
	if settings.load(SETTINGS_PATH) != OK:
		return
	best_wave = settings.get_value(PROGRESS_SECTION, BEST_WAVE_KEY, 0)
	palettes = maxi(int(settings.get_value(PROGRESS_SECTION, PALETTES_KEY, 0)), 0)
	flask_slots = clampi(int(settings.get_value(PROGRESS_SECTION, FLASK_SLOTS_KEY, FlaskEffects.START_SLOTS)),
		FlaskEffects.START_SLOTS, FlaskEffects.MAX_SLOTS)


func _save_progress() -> void:
	var settings: ConfigFile = ConfigFile.new()
	settings.load(SETTINGS_PATH)
	settings.set_value(PROGRESS_SECTION, BEST_WAVE_KEY, best_wave)
	settings.set_value(PROGRESS_SECTION, PALETTES_KEY, palettes)
	settings.set_value(PROGRESS_SECTION, FLASK_SLOTS_KEY, flask_slots)
	var save_error: int = settings.save(SETTINGS_PATH)
	if save_error != OK:
		push_warning("[GameManager] Não foi possível salvar o recorde (erro %d)." % save_error)


func add_custom_color(color: Color) -> int:
	for index in custom_colors.size():
		if custom_colors[index].is_equal_approx(color):
			return index
	if custom_colors.size() >= MAX_CUSTOM_COLORS:
		custom_colors.remove_at(0)
	custom_colors.append(color)
	_save_custom_colors()
	return custom_colors.size() - 1


func _load_custom_colors() -> void:
	var settings: ConfigFile = ConfigFile.new()
	if settings.load(SETTINGS_PATH) != OK:
		return
	var stored: Variant = settings.get_value(PALETTE_SECTION, CUSTOM_COLORS_KEY, PackedColorArray())
	if not stored is PackedColorArray:
		push_warning("[GameManager] Cores personalizadas salvas em formato inesperado, ignorando.")
		return
	custom_colors = stored
	if custom_colors.size() > MAX_CUSTOM_COLORS:
		custom_colors = custom_colors.slice(custom_colors.size() - MAX_CUSTOM_COLORS)


func _save_custom_colors() -> void:
	var settings: ConfigFile = ConfigFile.new()
	settings.load(SETTINGS_PATH)
	settings.set_value(PALETTE_SECTION, CUSTOM_COLORS_KEY, custom_colors)
	var save_error: int = settings.save(SETTINGS_PATH)
	if save_error != OK:
		push_warning("[GameManager] Não foi possível salvar as cores personalizadas (erro %d)." % save_error)


func has_saved_drawings() -> bool:
	return FileAccess.file_exists(CHARACTER_DRAWING_PATH) \
		and FileAccess.file_exists(_ability_drawing_path(0))


func load_saved_drawings() -> bool:
	reset_run_data()
	if not load_character_drawing_from_disk():
		return false
	return load_ability_drawing_from_disk(0)


func restart_run() -> bool:
	if character_image == null or not has_ability_drawing(0):
		push_warning("[GameManager] Sem desenhos em memória para reiniciar a run.")
		return false
	last_wave_reached = 0
	last_canvas_snapshot = null
	last_canvas_coverage = 0.0
	last_run_was_record = false
	if ability_images.size() > 1:
		ability_images.resize(1)
	if ability_shot_types.size() > 1:
		ability_shot_types.resize(1)
	return go_to_arena()


func set_character_drawing(image: Image) -> void:
	character_image = image


func has_character_drawing() -> bool:
	return character_image != null


func get_character_texture() -> ImageTexture:
	if character_image == null:
		return null
	return ImageTexture.create_from_image(character_image)


func save_character_drawing_to_disk() -> bool:
	if character_image == null:
		return false
	if not DirAccess.dir_exists_absolute(DRAWINGS_DIR):
		var dir_error: int = DirAccess.make_dir_recursive_absolute(DRAWINGS_DIR)
		if dir_error != OK:
			push_warning("[GameManager] Não foi possível criar %s (erro %d)." % [DRAWINGS_DIR, dir_error])
			return false
	var save_error: int = character_image.save_png(CHARACTER_DRAWING_PATH)
	if save_error != OK:
		push_warning("[GameManager] Falha ao salvar o desenho (erro %d)." % save_error)
		return false
	return true


func load_character_drawing_from_disk() -> bool:
	if not FileAccess.file_exists(CHARACTER_DRAWING_PATH):
		return false
	var image: Image = Image.new()
	var load_error: int = image.load(CHARACTER_DRAWING_PATH)
	if load_error != OK:
		push_warning("[GameManager] Falha ao carregar o desenho (erro %d)." % load_error)
		return false
	character_image = image
	return true


func set_ability_drawing(index: int, image: Image) -> void:
	while ability_images.size() <= index:
		ability_images.append(null)
	ability_images[index] = image


func get_ability_drawing(index: int) -> Image:
	if index < 0 or index >= ability_images.size():
		return null
	return ability_images[index]


func has_ability_drawing(index: int) -> bool:
	return get_ability_drawing(index) != null


func set_ability_shot_type(index: int, shot_type: int) -> void:
	while ability_shot_types.size() <= index:
		ability_shot_types.append(-1)
	ability_shot_types[index] = shot_type


func get_ability_shot_type(index: int) -> int:
	if index < 0 or index >= ability_shot_types.size():
		return -1
	return ability_shot_types[index]


func _shot_types_path() -> String:
	return "%s/shot_types.cfg" % DRAWINGS_DIR


func _save_ability_shot_type(index: int) -> bool:
	var shot_type: int = get_ability_shot_type(index)
	if shot_type < 0:
		return true
	var shot_types: ConfigFile = ConfigFile.new()
	shot_types.load(_shot_types_path())
	shot_types.set_value(SHOT_TYPES_SECTION, str(index), shot_type)
	var save_error: int = shot_types.save(_shot_types_path())
	if save_error != OK:
		push_warning("[GameManager] Falha ao salvar o tipo de tiro da habilidade %d (erro %d)." % [index, save_error])
		return false
	return true


func _load_ability_shot_type(index: int) -> void:
	var shot_types: ConfigFile = ConfigFile.new()
	if shot_types.load(_shot_types_path()) != OK:
		set_ability_shot_type(index, -1)
		return
	set_ability_shot_type(index, shot_types.get_value(SHOT_TYPES_SECTION, str(index), -1))


func get_ability_texture(index: int) -> ImageTexture:
	var image: Image = get_ability_drawing(index)
	if image == null:
		return null
	return ImageTexture.create_from_image(image)


func _ability_drawing_path(index: int) -> String:
	return "%s/ability_%02d.png" % [DRAWINGS_DIR, index + 1]


func save_ability_drawing_to_disk(index: int) -> bool:
	var image: Image = get_ability_drawing(index)
	if image == null:
		return false
	if not DirAccess.dir_exists_absolute(DRAWINGS_DIR):
		var dir_error: int = DirAccess.make_dir_recursive_absolute(DRAWINGS_DIR)
		if dir_error != OK:
			push_warning("[GameManager] Não foi possível criar %s (erro %d)." % [DRAWINGS_DIR, dir_error])
			return false
	var save_error: int = image.save_png(_ability_drawing_path(index))
	if save_error != OK:
		push_warning("[GameManager] Falha ao salvar a habilidade %d (erro %d)." % [index, save_error])
		return false
	return _save_ability_shot_type(index)


func load_ability_drawing_from_disk(index: int) -> bool:
	var path: String = _ability_drawing_path(index)
	if not FileAccess.file_exists(path):
		return false
	var image: Image = Image.new()
	var load_error: int = image.load(path)
	if load_error != OK:
		push_warning("[GameManager] Falha ao carregar a habilidade %d (erro %d)." % [index, load_error])
		return false
	set_ability_drawing(index, image)
	_load_ability_shot_type(index)
	return true


func set_last_canvas_snapshot(image: Image) -> void:
	last_canvas_snapshot = image


func has_last_canvas_snapshot() -> bool:
	return last_canvas_snapshot != null


func get_last_canvas_texture() -> ImageTexture:
	if last_canvas_snapshot == null:
		return null
	return ImageTexture.create_from_image(last_canvas_snapshot)


func save_last_canvas_to_disk() -> String:
	if last_canvas_snapshot == null:
		return ""

	if OS.has_feature("web"):
		return _save_last_canvas_web()
	return _save_last_canvas_disk()


func _save_last_canvas_web() -> String:
	var buffer: PackedByteArray = last_canvas_snapshot.save_png_to_buffer()
	if buffer.is_empty():
		push_warning("[GameManager] Falha ao gerar o PNG do cenário para download.")
		return ""
	var filename: String = "blank_canvas_canvas_%d.png" % int(Time.get_unix_time_from_system())
	JavaScriptBridge.download_buffer(buffer, filename, "image/png")
	last_saved_scenario_path = filename
	return get_last_saved_scenario_message()


func _save_last_canvas_disk() -> String:
	if not DirAccess.dir_exists_absolute(SAVED_SCENARIOS_DIR):
		var dir_error: int = DirAccess.make_dir_recursive_absolute(SAVED_SCENARIOS_DIR)
		if dir_error != OK:
			push_warning("[GameManager] Não foi possível criar %s (erro %d)." % [SAVED_SCENARIOS_DIR, dir_error])
			return ""
	var path: String = "%s/scenario_%d.png" % [SAVED_SCENARIOS_DIR, int(Time.get_unix_time_from_system())]
	var save_error: int = last_canvas_snapshot.save_png(path)
	if save_error != OK:
		push_warning("[GameManager] Falha ao salvar o cenário (erro %d)." % save_error)
		return ""
	last_saved_scenario_path = ProjectSettings.globalize_path(path)
	return path


func get_last_saved_scenario_message() -> String:
	if last_saved_scenario_path.is_empty():
		return ""
	var key: String = "scenario.downloaded" if OS.has_feature("web") else "scenario.saved_to"
	return LocalizationManager.text(key, [last_saved_scenario_path])
