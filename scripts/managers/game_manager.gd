extends Node


const DISPLAY_NAME: String = "Blank Canvas"

const VERSION: String = "1.0.2"


const SCENE_MAIN_MENU: String = "res://scenes/menu/main_menu.tscn"
const SCENE_CHARACTER_CREATOR: String = "res://scenes/character_creator/character_creator.tscn"
const SCENE_ABILITY_CREATOR: String = "res://scenes/ability_creator/ability_creator.tscn"
const SCENE_ARENA: String = "res://scenes/game/arena.tscn"
const SCENE_GAME_OVER: String = "res://scenes/ui/game_over.tscn"
const SCENE_SCENARIO_VIEWER: String = "res://scenes/ui/scenario_viewer.tscn"


const DRAWINGS_DIR: String = "user://drawings"
const CHARACTER_DRAWING_PATH: String = "user://drawings/character.png"
const SAVED_SCENARIOS_DIR: String = "user://saved_scenarios"


var character_image: Image = null

var ability_images: Array[Image] = []

var last_wave_reached: int = 0

var last_canvas_snapshot: Image = null

var last_saved_scenario_path: String = ""


func change_scene(scene_path: String) -> bool:
	if not ResourceLoader.exists(scene_path):
		push_warning("[GameManager] Cena ainda não implementada: %s" % scene_path)
		return false
	TransitionManager.play_transition(func() -> void:
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
	last_wave_reached = 0
	last_canvas_snapshot = null


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
	return true


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
