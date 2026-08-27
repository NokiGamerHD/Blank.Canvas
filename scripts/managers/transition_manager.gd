extends CanvasLayer

const DISSOLVE_SHADER: Shader = preload("res://assets/shaders/pixel_dissolve.gdshader")

@export var transition_duration: float = 0.28

@export var flash_in_duration: float = 0.06

@export var flash_out_duration: float = 0.45

var _overlay: ColorRect
var _material: ShaderMaterial

var _flash_overlay: ColorRect


func _ready() -> void:
	layer = 1000
	process_mode = Node.PROCESS_MODE_ALWAYS

	_material = ShaderMaterial.new()
	_material.shader = DISSOLVE_SHADER
	_material.set_shader_parameter("progress", 0.0)

	_overlay = ColorRect.new()
	_overlay.name = "DissolveOverlay"
	_overlay.anchor_right = 1.0
	_overlay.anchor_bottom = 1.0
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.color = Color.WHITE
	_overlay.material = _material
	_overlay.visible = false
	add_child(_overlay)

	_flash_overlay = ColorRect.new()
	_flash_overlay.name = "FlashOverlay"
	_flash_overlay.anchor_right = 1.0
	_flash_overlay.anchor_bottom = 1.0
	_flash_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_overlay.color = Color.WHITE
	_flash_overlay.modulate.a = 0.0
	_flash_overlay.visible = false
	add_child(_flash_overlay)


func play_transition(change_action: Callable) -> void:
	_overlay.visible = true
	_material.set_shader_parameter("progress", 0.0)

	var cover_tween: Tween = create_tween()
	cover_tween.tween_method(_set_progress, 0.0, 1.0, transition_duration)
	await cover_tween.finished

	change_action.call()
	await get_tree().process_frame

	var reveal_tween: Tween = create_tween()
	reveal_tween.tween_method(_set_progress, 1.0, 0.0, transition_duration)
	await reveal_tween.finished

	_overlay.visible = false


func _set_progress(value: float) -> void:
	_material.set_shader_parameter("progress", value)


func play_flash_transition(change_action: Callable) -> void:
	_flash_overlay.visible = true
	_flash_overlay.modulate.a = 0.0

	var flash_in: Tween = create_tween()
	flash_in.tween_property(_flash_overlay, "modulate:a", 1.0, flash_in_duration)
	await flash_in.finished

	change_action.call()
	await get_tree().process_frame

	var flash_out: Tween = create_tween()
	flash_out.tween_property(_flash_overlay, "modulate:a", 0.0, flash_out_duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await flash_out.finished

	_flash_overlay.visible = false
