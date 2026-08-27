class_name BoardCanvas
extends Sprite2D

@export var tile_world_size: float = 96.0


func setup(world_size: Vector2) -> void:
	centered = false
	region_enabled = false
	scale = world_size / Vector2(texture.get_width(), texture.get_height())

	var material_override: ShaderMaterial = material as ShaderMaterial
	if material_override != null:
		var tiles_across: float = world_size.x / tile_world_size
		material_override.set_shader_parameter("tile_count", tiles_across)
