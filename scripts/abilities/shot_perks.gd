class_name ShotPerks
extends RefCounted

const PERKS: Dictionary = {
	"vampirism": AbilityData.ShotType.STANDARD,
	"ricochet": AbilityData.ShotType.STANDARD,
	"critical": AbilityData.ShotType.STANDARD,
	"explosion": AbilityData.ShotType.CHARGE,
	"shards": AbilityData.ShotType.CHARGE,
	"overcharge": AbilityData.ShotType.CHARGE,
	"poison": AbilityData.ShotType.RAPID,
	"focus": AbilityData.ShotType.RAPID,
	"momentum": AbilityData.ShotType.RAPID,
}

const VAMPIRISM_FRACTION: float = 0.03

const RICOCHET_BASE_BOUNCES: int = 1
const RICOCHET_RANGE: float = 320.0

const CRIT_BASE_CHANCE: float = 0.25
const CRIT_CHANCE_PER_SPEED: float = 0.35
const CRIT_MAX_CHANCE: float = 0.7
const CRIT_MULTIPLIER: float = 2.0

const BLAST_RADIUS_PER_SIZE: float = 48.0
const BLAST_DAMAGE_FRACTION: float = 0.5

const SHARD_BASE_COUNT: int = 4
const SHARDS_PER_EXTRA_PROJECTILE: int = 2
const SHARD_DAMAGE_FRACTION: float = 0.25
const SHARD_RANGE: float = 220.0
const SHARD_SIZE: float = 0.6

const OVERCHARGE_TIME: float = 1.0
const OVERCHARGE_BONUS: float = 0.6
const OVERCHARGE_TICK_INTERVAL: float = 0.2

const POISON_DPS_FRACTION: float = 0.35
const POISON_DURATION: float = 3.0
const POISON_TICK: float = 0.5
const POISON_MAX_STACKS: int = 5

const FOCUS_BONUS_PER_STACK: float = 0.08
const FOCUS_MAX_STACKS: int = 10
const FOCUS_DECAY: float = 1.5

const MOMENTUM_RATE_BONUS: float = 0.4


static func perks_for(shot_type: int) -> Array[String]:
	var found: Array[String] = []
	for perk_id in PERKS:
		if PERKS[perk_id] == shot_type:
			found.append(perk_id)
	return found


static func name_key(perk_id: String) -> String:
	return "perk.%s" % perk_id


static func info_key(perk_id: String) -> String:
	return "perk.%s_info" % perk_id


static func critical_chance(speed_ratio: float) -> float:
	return clampf(CRIT_BASE_CHANCE + maxf(speed_ratio - 1.0, 0.0) * CRIT_CHANCE_PER_SPEED, 0.0, CRIT_MAX_CHANCE)


static func ricochet_bounces(piercing: int) -> int:
	return RICOCHET_BASE_BOUNCES + maxi(piercing, 0)


static func shard_count(projectile_count: int) -> int:
	return SHARD_BASE_COUNT + SHARDS_PER_EXTRA_PROJECTILE * maxi(projectile_count - 1, 0)


static func blast_radius(shot_size: float) -> float:
	return BLAST_RADIUS_PER_SIZE * shot_size
