class_name FlaskEffects
extends RefCounted

const ZIGZAG: String = "zigzag"
const RUSH: String = "rush"
const BURST: String = "burst"
const ORBIT: String = "orbit"

const MAX_SLOTS: int = 8
const START_SLOTS: int = 1
const SLOT_PRICE: int = 1
const DURATION: float = 15.0
const USE_HEAL: float = 18.0

const ZIGZAG_SWING: float = 190.0
const ZIGZAG_INTERVAL: float = 0.11
const ZIGZAG_DAMAGE: float = 1.4

const RUSH_SHOT_SPEED: float = 1.6
const RUSH_PLAYER_SPEED: float = 1.3
const RUSH_FIRE_RATE: float = 1.5

const BURST_SIZE: float = 1.6
const BURST_RADIUS: float = 64.0
const BURST_DAMAGE: float = 0.55
const BURST_PAINT: float = 0.5
const BURST_BONUS_HP: float = 40.0
const BURST_GROW: float = 1.35

const ORBIT_TURN_RATE: float = 7.0
const ORBIT_DASH_COOLDOWN: float = 0.35
const ORBIT_DASH_SPEED: float = 1.25

const EFFECT_KEYS: Dictionary = {
	ZIGZAG: "flask.zigzag",
	RUSH: "flask.rush",
	BURST: "flask.burst",
	ORBIT: "flask.orbit",
}


static func for_type(type: int) -> String:
	match type:
		EnemyBase.EnemyType.COMMON:
			return ZIGZAG
		EnemyBase.EnemyType.FAST:
			return RUSH
		EnemyBase.EnemyType.TANK:
			return BURST
		EnemyBase.EnemyType.STALKER:
			return ORBIT
	return ""


static func name_key(effect: String) -> String:
	return EFFECT_KEYS.get(effect, "")


static func player_speed(effects: Array[String]) -> float:
	return RUSH_PLAYER_SPEED if effects.has(RUSH) else 1.0


static func dash_cooldown(effects: Array[String]) -> float:
	return ORBIT_DASH_COOLDOWN if effects.has(ORBIT) else 1.0


static func dash_speed(effects: Array[String]) -> float:
	return ORBIT_DASH_SPEED if effects.has(ORBIT) else 1.0


static func fire_rate(effects: Array[String]) -> float:
	return RUSH_FIRE_RATE if effects.has(RUSH) else 1.0


static func damage(effects: Array[String]) -> float:
	return ZIGZAG_DAMAGE if effects.has(ZIGZAG) else 1.0
