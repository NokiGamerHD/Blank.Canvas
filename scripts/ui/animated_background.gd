class_name AnimatedBackground
extends TextureRect

@export var overscan_scale: float = 1.2
@export var sway_angle_degrees: float = 1.8
@export var sway_period_seconds: float = 10.0
@export var drift_amount: Vector2 = Vector2(16.0, 10.0)
@export var drift_period_x: float = 14.0
@export var drift_period_y: float = 9.0

var _time: float = 0.0
var _center_position: Vector2


func _ready() -> void:
	var base_size: Vector2 = get_parent_area_size()
	size = base_size * overscan_scale
	pivot_offset = size / 2.0
	_center_position = (base_size - size) / 2.0
	position = _center_position


func _process(delta: float) -> void:
	_time += delta
	rotation = deg_to_rad(sway_angle_degrees) * sin(_time * TAU / sway_period_seconds)
	var drift: Vector2 = Vector2(
		sin(_time * TAU / drift_period_x),
		sin(_time * TAU / drift_period_y + 1.3)
	) * drift_amount
	position = _center_position + drift
