class_name FloatingElement
extends Control

@export var amplitude_pixels: float = 4.0
@export var period_seconds: float = 2.8
@export var phase_offset: float = 0.0

var _time: float = 0.0
var _base_position: Vector2
var _base_captured: bool = false


func _process(delta: float) -> void:
	if not _base_captured:
		_base_position = position
		_base_captured = true

	_time += delta
	var wave: float = sin((_time * TAU / period_seconds) + phase_offset)
	position = _base_position + Vector2(0, wave * amplitude_pixels)
