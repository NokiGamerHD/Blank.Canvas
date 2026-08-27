class_name AbilitySlot
extends Control

@onready var icon: TextureRect = $Icon
@onready var cooldown_overlay: ColorRect = $CooldownOverlay


func set_texture(texture: Texture2D) -> void:
	icon.texture = texture


func set_cooldown_fraction(fraction: float) -> void:
	cooldown_overlay.anchor_bottom = clampf(fraction, 0.0, 1.0)
