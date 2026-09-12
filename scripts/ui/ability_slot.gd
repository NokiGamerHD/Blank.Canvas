class_name AbilitySlot
extends Control

@onready var icon: TextureRect = $Icon
@onready var cooldown_overlay: ColorRect = $CooldownOverlay


func set_texture(texture: Texture2D) -> void:
	icon.texture = texture


func set_pixel_icon(texture: Texture2D, overlay_color: Color) -> void:
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	icon.texture = texture
	cooldown_overlay.color = overlay_color


func set_cooldown_fraction(fraction: float) -> void:
	cooldown_overlay.anchor_bottom = clampf(fraction, 0.0, 1.0)
