class_name LanguageButton
extends Button


const ICON_COLOR: Color = Color(0.15, 0.15, 0.15, 1.0)


func _ready() -> void:
	text = ""
	focus_mode = Control.FOCUS_NONE
	queue_redraw()


func _draw() -> void:
	var center: Vector2 = size / 2.0
	var radius: float = minf(size.x, size.y) * 0.25
	var line_width: float = 1.5

	draw_arc(center, radius, 0.0, TAU, 20, ICON_COLOR, line_width, true)
	draw_line(center + Vector2(-radius, 0.0), center + Vector2(radius, 0.0), ICON_COLOR, line_width, true)
	draw_line(center + Vector2(0.0, -radius), center + Vector2(0.0, radius), ICON_COLOR, line_width, true)
	draw_arc(center, radius * 0.58, -PI / 2.0, PI / 2.0, 10, ICON_COLOR, line_width, true)
	draw_arc(center, radius * 0.58, PI / 2.0, PI * 1.5, 10, ICON_COLOR, line_width, true)
