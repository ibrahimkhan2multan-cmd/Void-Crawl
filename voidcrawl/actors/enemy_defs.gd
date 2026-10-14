class_name VCEnemyDefs
extends RefCounted
## Data for every creature. Adding an enemy = add an entry here (and a rig in VCEnemy._build_rig).
##   ai:        melee | ranged | dasher | slam | swarm | boss
##   hp/dmg:    at level 1; scaled by VCEnemyDefs.scale_for_level()
##   windup:    seconds of telegraph before the hit lands (the dodge window)

const DEFS := {
	"husk": {
		"name": "Hollow Husk", "ai": "melee", "hp": 44.0, "dmg": 9.0, "speed": 3.1, "radius": 0.45,
		"xp": 10, "coins": [1, 3], "item_chance": 0.10, "potion_chance": 0.06,
		"windup": 0.55, "reach": 1.9, "cooldown": 1.15, "arc": 100.0, "scale": 1.0,
	},
	"slinger": {
		"name": "Bone Slinger", "ai": "ranged", "hp": 30.0, "dmg": 8.0, "speed": 2.9, "radius": 0.4,
		"xp": 12, "coins": [1, 4], "item_chance": 0.12, "potion_chance": 0.07,
		"windup": 0.6, "reach": 12.0, "pref_dist": 7.5, "cooldown": 2.1, "proj_speed": 9.5, "scale": 1.0,
	},
	"spiderling": {
		"name": "Gloom Skitter", "ai": "swarm", "hp": 20.0, "dmg": 5.0, "speed": 4.9, "radius": 0.35,
		"xp": 6, "coins": [0, 2], "item_chance": 0.04, "potion_chance": 0.03,
		"windup": 0.28, "reach": 1.5, "cooldown": 0.9, "arc": 90.0, "scale": 0.8,
	},
	"wisp": {
		"name": "Void Wisp", "ai": "dasher", "hp": 24.0, "dmg": 11.0, "speed": 3.4, "radius": 0.4,
		"xp": 14, "coins": [2, 5], "item_chance": 0.14, "potion_chance": 0.08,
		"windup": 0.7, "reach": 10.0, "cooldown": 2.6, "dash_speed": 12.5, "dash_time": 0.55, "scale": 1.0, "floating": true,
	},
	"brute": {
		"name": "Crypt Brute", "ai": "slam", "hp": 150.0, "dmg": 22.0, "speed": 2.2, "radius": 0.85,
		"xp": 38, "coins": [6, 14], "item_chance": 0.55, "potion_chance": 0.25,
		"windup": 0.95, "reach": 3.4, "cooldown": 2.4, "slam_radius": 3.3, "scale": 1.55,
	},
	"warden": {
		"name": "The Hollow Warden", "ai": "boss", "hp": 780.0, "dmg": 20.0, "speed": 2.8, "radius": 1.1,
		"xp": 400, "coins": [120, 160], "item_chance": 1.0, "potion_chance": 1.0,
		"windup": 0.85, "reach": 4.6, "cooldown": 1.5, "scale": 2.3,
	},
}

static func get_def(id: String) -> Dictionary:
	return DEFS.get(id, DEFS["husk"])

## Level scaling used for enemy health/damage/xp.
static func hp_scale(level: int) -> float:
	return 1.0 + 0.2 * float(maxi(level, 1) - 1)

static func dmg_scale(level: int) -> float:
	return 1.0 + 0.12 * float(maxi(level, 1) - 1)

static func xp_scale(level: int) -> float:
	return 1.0 + 0.15 * float(maxi(level, 1) - 1)
