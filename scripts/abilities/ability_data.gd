class_name AbilityData
extends Resource

@export var ability_index: int = 0

@export var damage: float = 20.0

@export var cooldown: float = 1.2

@export var projectile_speed: float = 600.0

@export var attack_range: float = 380.0

@export var projectile_count: int = 1

@export var size_scale: float = 1.0

@export var piercing: int = 0

@export var target_mode: int = 0

var cooldown_remaining: float = 0.0


func display_name() -> String:
	return LocalizationManager.text("ability.name", [ability_index + 1])
