extends Node


func _ready() -> void:
	for path in [GameManager.SCENE_CHARACTER_CREATOR, GameManager.SCENE_ABILITY_CREATOR]:
		var creator: Control = load(path).instantiate() as Control
		add_child(creator)
		await get_tree().process_frame
		await get_tree().process_frame
		var main: Control = creator.get_node("CenterContainer/MainContainer") as Control
		var side: Control = creator.get_node("CenterContainer/MainContainer/EditorRow/SidePanel") as Control
		var editor: Control = creator.get_node("CenterContainer/MainContainer/EditorRow/PixelEditor") as Control
		print("%s main=%.0f side=%.0f editor=%.0f" % [
			path.get_file(), main.size.y, side.size.y, editor.size.y])
		for child in main.get_children():
			var control: Control = child as Control
			if control != null:
				print("   %s y=%.0f altura=%.0f" % [control.name, control.position.y, control.size.y])
		for child in side.get_children():
			var control: Control = child as Control
			if control != null:
				print("   side/%s altura=%.0f" % [control.name, control.size.y])
		creator.queue_free()
		await get_tree().process_frame
	get_tree().quit()
