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
	"shieldbearer": {
		"name": "Gravewall Guard", "ai": "melee", "hp": 120.0, "dmg": 14.0, "speed": 2.4, "radius": 0.55,
		"xp": 22, "coins": [3, 8], "item_chance": 0.3, "potion_chance": 0.12,
		"windup": 0.75, "reach": 2.1, "cooldown": 1.6, "arc": 90.0, "scale": 1.15, "block_arc": 130.0,
		"glow": Color(0.5, 0.8, 1.0),
	},
	"embermite": {
		"name": "Ember Mite", "ai": "exploder", "hp": 26.0, "dmg": 18.0, "speed": 5.2, "radius": 0.4,
		"xp": 9, "coins": [1, 3], "item_chance": 0.05, "potion_chance": 0.05,
		"windup": 0.65, "reach": 1.9, "blast": 3.1, "scale": 0.85, "glow": Color(1.0, 0.5, 0.2),
	},
	"cultist": {
		"name": "Ashen Cultist", "ai": "ranged", "hp": 42.0, "dmg": 9.0, "speed": 2.8, "radius": 0.42,
		"xp": 18, "coins": [2, 6], "item_chance": 0.18, "potion_chance": 0.1,
		"windup": 0.75, "reach": 13.0, "pref_dist": 8.5, "cooldown": 2.8, "proj_speed": 8.5, "fan": 3, "scale": 1.05,
		"glow": Color(1.0, 0.45, 0.2), "robe": Color(0.35, 0.12, 0.1),
	},
	"necromancer": {
		"name": "Gloom Weaver", "ai": "ranged", "hp": 60.0, "dmg": 0.0, "speed": 2.6, "radius": 0.42,
		"xp": 30, "coins": [4, 10], "item_chance": 0.3, "potion_chance": 0.2,
		"windup": 0.9, "reach": 13.0, "pref_dist": 9.5, "cooldown": 5.5, "proj_speed": 0.0,
		"summon": "spiderling", "summon_count": 2, "summon_cap": 5, "scale": 1.12,
		"glow": Color(0.4, 1.0, 0.6), "robe": Color(0.1, 0.22, 0.16),
	},
	"colossus": {
		"name": "The Ashen Colossus", "ai": "boss", "hp": 1250.0, "dmg": 27.0, "speed": 2.7, "radius": 1.25,
		"xp": 900, "coins": [220, 300], "item_chance": 1.0, "potion_chance": 1.0,
		"windup": 0.8, "reach": 5.0, "cooldown": 1.4, "scale": 2.5,
		"glow": Color(1.0, 0.5, 0.15), "body": Color(0.28, 0.14, 0.12),
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
