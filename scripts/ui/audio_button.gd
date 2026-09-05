class_name AudioButton
extends Button


const ICON_COLOR: Color = Color(0.15, 0.15, 0.15, 1.0)


func _ready() -> void:
	text = ""
	focus_mode = Control.FOCUS_NONE
	AudioManager.audio_settings_changed.connect(queue_redraw)
	queue_redraw()


func _draw() -> void:
	var center: Vector2 = size / 2.0
	var unit: float = minf(size.x, size.y) * 0.22
	var line_width: float = 1.5

	var cone: PackedVector2Array = PackedVector2Array([
		center + Vector2(-unit, -unit * 0.5),
		center + Vector2(-unit * 0.3, -unit * 0.5),
		center + Vector2(unit * 0.3, -unit),
		center + Vector2(unit * 0.3, unit),
		center + Vector2(-unit * 0.3, unit * 0.5),
		center + Vector2(-unit, unit * 0.5),
	])
	draw_colored_polygon(cone, ICON_COLOR)

	if AudioManager.is_audible():
		draw_arc(center + Vector2(unit * 0.3, 0.0), unit * 0.7, -PI / 3.0, PI / 3.0, 8, ICON_COLOR, line_width, true)
		draw_arc(center + Vector2(unit * 0.3, 0.0), unit * 1.2, -PI / 3.0, PI / 3.0, 10, ICON_COLOR, line_width, true)
		return

	var cross_center: Vector2 = center + Vector2(unit * 1.1, 0.0)
	var arm: float = unit * 0.5
	draw_line(cross_center + Vector2(-arm, -arm), cross_center + Vector2(arm, arm), ICON_COLOR, line_width, true)
	draw_line(cross_center + Vector2(-arm, arm), cross_center + Vector2(arm, -arm), ICON_COLOR, line_width, true)
