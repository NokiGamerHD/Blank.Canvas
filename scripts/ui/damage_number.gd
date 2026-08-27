class_name DamageNumber
extends Node2D

@export var rise_distance: float = 28.0
@export var rise_duration: float = 1.0

@export var opaque_fraction: float = 0.6

@onready var label: Label = $Label


func setup(amount: float) -> void:
	label.text = str(int(round(amount)))
	_start_animation()


func _start_animation() -> void:
	var fade_delay: float = rise_duration * opaque_fraction
	var fade_duration: float = rise_duration - fade_delay
	var target_y: float = position.y - rise_distance

	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", target_y, rise_duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, fade_duration) \
		.set_delay(fade_delay)

	await get_tree().create_timer(rise_duration).timeout
	queue_free()
