extends Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().create_timer(1.5).timeout
	print("  depois da troca         -> paused = %s" % get_tree().paused)
	var scene: Node = get_tree().current_scene
	var path: String = scene.scene_file_path if scene != null else "(nenhuma)"
	print("  cena atual              -> %s" % path)
	get_tree().quit()
