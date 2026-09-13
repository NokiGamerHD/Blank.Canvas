class_name AbilityData
extends Resource

enum ShotType { STANDARD, CHARGE, RAPID }

const SHOT_PRESETS: Dictionary = {
	ShotType.STANDARD: {
		"damage": 1.0, "cooldown": 0.8, "speed": 1.0, "range": 700.0, "size": 1.0,
		"homing_turn_rate": 4.5,
	},
	ShotType.CHARGE: {
		"damage": 1.0, "cooldown": 1.6, "speed": 0.85, "range": 380.0, "size": 1.0,
		"homing_turn_rate": 0.0,
	},
	ShotType.RAPID: {
		"damage": 0.35, "cooldown": 0.28, "speed": 1.45, "range": 1100.0, "size": 0.6,
		"homing_turn_rate": 0.0,
	},
}

const CHARGE_TIME: float = 1.1
const MIN_CHARGE_TIME: float = 0.35
const CHARGE_MIN_DAMAGE: float = 0.5
const CHARGE_MAX_DAMAGE: float = 2.6
const CHARGE_MAX_SIZE: float = 2.2
const CHARGE_FULL_PIERCE: int = 2

@export var ability_index: int = 0

@export var damage: float = 20.0

@export var cooldown: float = 1.0

@export var projectile_speed: float = 720.0

@export var projectile_count: int = 1

@export var size_scale: float = 1.0

@export var piercing: int = 0

@export var shot_type: int = ShotType.STANDARD

@export var shot_range: float = 700.0

@export var homing_turn_rate: float = 0.0

@export var charge_time: float = CHARGE_TIME

var cooldown_remaining: float = 0.0
var charge_elapsed: float = 0.0
var charging: bool = false


func apply_shot_type(type: int, base_damage: float, base_cooldown: float, base_speed: float) -> void:
	if not SHOT_PRESETS.has(type):
		push_warning("[AbilityData] Tipo de tiro desconhecido: %d; usando o padrão." % type)
		type = ShotType.STANDARD
	var preset: Dictionary = SHOT_PRESETS[type]
	shot_type = type
	damage = base_damage * preset["damage"]
	cooldown = base_cooldown * preset["cooldown"]
	projectile_speed = base_speed * preset["speed"]
	shot_range = preset["range"]
	size_scale = preset["size"]
	homing_turn_rate = preset["homing_turn_rate"]
	charge_time = CHARGE_TIME


func charge_fraction() -> float:
	if charge_time <= 0.0:
		return 1.0
	return clampf(charge_elapsed / charge_time, 0.0, 1.0)


func is_fully_charged() -> bool:
	return charge_fraction() >= 1.0


func shot_damage() -> float:
	if shot_type != ShotType.CHARGE:
		return damage
	return damage * lerpf(CHARGE_MIN_DAMAGE, CHARGE_MAX_DAMAGE, charge_fraction())


func shot_size() -> float:
	if shot_type != ShotType.CHARGE:
		return size_scale
	return size_scale * lerpf(1.0, CHARGE_MAX_SIZE, charge_fraction())


func shot_piercing() -> int:
	if shot_type == ShotType.CHARGE and is_fully_charged():
		return piercing + CHARGE_FULL_PIERCE
	return piercing


func display_name() -> String:
	return LocalizationManager.text("ability.name", [ability_index + 1])
