class_name VCEnemyDefs
extends RefCounted
## Data for every creature. Adding an enemy = add an entry here (and a rig in VCEnemy._build_rig).
##   ai:        melee | ranged | dasher | slam | swarm | boss
##   hp/dmg:    at level 1; scaled by VCEnemyDefs.scale_for_level()
##   windup:    seconds of telegraph before the hit lands (the dodge window)

static var DEFS := {
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
	"frostwraith": {
		"name": "Rime Wraith", "ai": "dasher", "hp": 40.0, "dmg": 14.0, "speed": 3.7, "radius": 0.42,
		"xp": 22, "coins": [3, 7], "item_chance": 0.18, "potion_chance": 0.1,
		"windup": 0.6, "reach": 11.0, "cooldown": 2.2, "dash_speed": 14.0, "dash_time": 0.5, "scale": 1.05, "floating": true,
		"glow": Color(0.55, 0.9, 1.0),
	},
	"icearcher": {
		"name": "Frostbone Archer", "ai": "ranged", "hp": 52.0, "dmg": 10.0, "speed": 3.0, "radius": 0.42,
		"xp": 24, "coins": [3, 8], "item_chance": 0.2, "potion_chance": 0.1,
		"windup": 0.7, "reach": 14.0, "pref_dist": 9.0, "cooldown": 2.4, "proj_speed": 11.0, "fan": 3, "scale": 1.05,
		"glow": Color(0.6, 0.9, 1.0), "robe": Color(0.18, 0.3, 0.45),
	},
	"yeti": {
		"name": "Glacier Yeti", "ai": "slam", "hp": 230.0, "dmg": 28.0, "speed": 2.6, "radius": 0.9,
		"xp": 55, "coins": [8, 18], "item_chance": 0.6, "potion_chance": 0.3,
		"windup": 0.9, "reach": 3.5, "cooldown": 2.2, "slam_radius": 3.8, "scale": 1.65,
		"glow": Color(0.55, 0.85, 1.0), "body": Color(0.78, 0.84, 0.92),
	},
	# ---- biome mobs (v0.8): each dungeon theme has its own creatures ----
	"skeleton": {
		"name": "Crypt Skeleton", "ai": "melee", "model": "husk", "tint": Color(0.78, 0.8, 0.84), "hp": 40.0, "dmg": 8.0, "speed": 3.5, "radius": 0.45,
		"xp": 11, "coins": [1, 3], "item_chance": 0.10, "potion_chance": 0.06,
		"windup": 0.42, "reach": 2.0, "cooldown": 0.95, "arc": 100.0, "scale": 1.0, "glow": Color(0.7, 0.85, 1.0),
	},
	"gloomhound": {
		"name": "Gloom Hound", "ai": "swarm", "model": "hound", "hp": 38.0, "dmg": 8.0, "speed": 5.0, "radius": 0.5,
		"xp": 11, "coins": [1, 3], "item_chance": 0.08, "potion_chance": 0.05,
		"windup": 0.35, "reach": 1.9, "cooldown": 1.0, "arc": 90.0, "scale": 1.0, "glow": Color(1.0, 0.3, 0.35), "body": Color(0.3, 0.24, 0.34),
	},
	"cavebat": {
		"name": "Cave Bat", "ai": "swarm", "model": "bat", "hp": 22.0, "dmg": 6.0, "speed": 5.4, "radius": 0.38,
		"xp": 7, "coins": [0, 2], "item_chance": 0.05, "potion_chance": 0.04,
		"windup": 0.3, "reach": 1.6, "cooldown": 0.85, "arc": 90.0, "scale": 0.9, "floating": true, "glow": Color(1.0, 0.35, 0.5), "body": Color(0.26, 0.2, 0.32),
	},
	"slime": {
		"name": "Gloom Slime", "ai": "melee", "model": "slime", "hp": 96.0, "dmg": 10.0, "speed": 2.3, "radius": 0.6,
		"xp": 16, "coins": [2, 5], "item_chance": 0.14, "potion_chance": 0.09,
		"windup": 0.7, "reach": 1.9, "cooldown": 1.5, "arc": 120.0, "scale": 1.1, "glow": Color(0.5, 1.0, 0.6), "body": Color(0.26, 0.7, 0.4),
	},
	"specter": {
		"name": "Wailing Specter", "ai": "dasher", "model": "wisp", "hp": 32.0, "dmg": 11.0, "speed": 3.5, "radius": 0.4,
		"xp": 16, "coins": [2, 5], "item_chance": 0.14, "potion_chance": 0.08,
		"windup": 0.65, "reach": 10.0, "cooldown": 2.4, "dash_speed": 13.0, "dash_time": 0.5, "scale": 1.0, "floating": true, "glow": Color(0.8, 0.92, 1.0),
	},
	"sentinel": {
		"name": "Stone Sentinel", "ai": "slam", "model": "brute", "hp": 175.0, "dmg": 21.0, "speed": 2.1, "radius": 0.85,
		"xp": 42, "coins": [7, 15], "item_chance": 0.55, "potion_chance": 0.25,
		"windup": 0.95, "reach": 3.4, "cooldown": 2.4, "slam_radius": 3.2, "scale": 1.5, "glow": Color(0.4, 0.9, 1.0), "body": Color(0.5, 0.52, 0.58),
	},
	"thornling": {
		"name": "Thorn Crawler", "ai": "swarm", "model": "spiderling", "tint": Color(0.45, 0.85, 0.3), "hp": 24.0, "dmg": 6.0, "speed": 4.7, "radius": 0.35,
		"xp": 7, "coins": [0, 2], "item_chance": 0.05, "potion_chance": 0.04,
		"windup": 0.28, "reach": 1.5, "cooldown": 0.9, "arc": 90.0, "scale": 0.85, "glow": Color(0.6, 1.0, 0.3),
	},
	"sporecaster": {
		"name": "Spore Shaman", "ai": "ranged", "model": "cultist", "hp": 44.0, "dmg": 9.0, "speed": 2.8, "radius": 0.42,
		"xp": 19, "coins": [2, 6], "item_chance": 0.18, "potion_chance": 0.1,
		"windup": 0.75, "reach": 13.0, "pref_dist": 8.5, "cooldown": 2.6, "proj_speed": 8.5, "fan": 2, "scale": 1.05,
		"glow": Color(0.6, 1.0, 0.3), "robe": Color(0.16, 0.34, 0.14),
	},
	"treant": {
		"name": "Gnarlroot Treant", "ai": "slam", "model": "brute", "style": "leather", "hp": 195.0, "dmg": 22.0, "speed": 2.2, "radius": 0.9,
		"xp": 46, "coins": [7, 16], "item_chance": 0.55, "potion_chance": 0.28,
		"windup": 1.0, "reach": 3.5, "cooldown": 2.4, "slam_radius": 3.5, "scale": 1.6, "glow": Color(0.55, 1.0, 0.35), "body": Color(0.34, 0.24, 0.14),
	},
	"voidacolyte": {
		"name": "Void Acolyte", "ai": "ranged", "model": "cultist", "hp": 44.0, "dmg": 10.0, "speed": 2.9, "radius": 0.42,
		"xp": 22, "coins": [3, 7], "item_chance": 0.2, "potion_chance": 0.1,
		"windup": 0.7, "reach": 13.0, "pref_dist": 8.5, "cooldown": 2.4, "proj_speed": 9.5, "fan": 3, "scale": 1.05,
		"glow": Color(0.85, 0.4, 1.0), "robe": Color(0.22, 0.09, 0.38),
	},
	"frozenhusk": {
		"name": "Frozen Husk", "ai": "melee", "model": "husk", "tint": Color(0.55, 0.82, 1.0), "hp": 54.0, "dmg": 10.0, "speed": 3.0, "radius": 0.45,
		"xp": 14, "coins": [2, 4], "item_chance": 0.12, "potion_chance": 0.07,
		"windup": 0.55, "reach": 1.9, "cooldown": 1.2, "arc": 100.0, "scale": 1.0, "glow": Color(0.5, 0.95, 1.0),
	},
	"frosthound": {
		"name": "Frost Hound", "ai": "swarm", "model": "hound", "hp": 46.0, "dmg": 9.0, "speed": 5.1, "radius": 0.5,
		"xp": 15, "coins": [2, 4], "item_chance": 0.1, "potion_chance": 0.06,
		"windup": 0.35, "reach": 1.9, "cooldown": 1.0, "arc": 90.0, "scale": 1.05, "glow": Color(0.5, 0.95, 1.0), "body": Color(0.72, 0.86, 0.96),
	},
	"rimebat": {
		"name": "Rime Bat", "ai": "swarm", "model": "bat", "hp": 28.0, "dmg": 7.0, "speed": 5.6, "radius": 0.38,
		"xp": 10, "coins": [1, 3], "item_chance": 0.07, "potion_chance": 0.05,
		"windup": 0.3, "reach": 1.6, "cooldown": 0.85, "arc": 90.0, "scale": 0.95, "floating": true, "glow": Color(0.6, 0.95, 1.0), "body": Color(0.7, 0.85, 0.98),
	},
	"charredhusk": {
		"name": "Charred Husk", "ai": "melee", "model": "husk", "tint": Color(1.0, 0.42, 0.18), "hp": 50.0, "dmg": 10.0, "speed": 3.2, "radius": 0.45,
		"xp": 14, "coins": [2, 4], "item_chance": 0.12, "potion_chance": 0.07,
		"windup": 0.5, "reach": 1.9, "cooldown": 1.1, "arc": 100.0, "scale": 1.0, "glow": Color(1.0, 0.55, 0.15),
	},
	"emberhound": {
		"name": "Ember Hound", "ai": "swarm", "model": "hound", "hp": 44.0, "dmg": 10.0, "speed": 5.2, "radius": 0.5,
		"xp": 15, "coins": [2, 4], "item_chance": 0.1, "potion_chance": 0.06,
		"windup": 0.35, "reach": 1.9, "cooldown": 1.0, "arc": 90.0, "scale": 1.05, "glow": Color(1.0, 0.55, 0.15), "body": Color(0.32, 0.13, 0.09),
	},
	"magmaslug": {
		"name": "Magma Slug", "ai": "melee", "model": "slime", "hp": 115.0, "dmg": 14.0, "speed": 2.2, "radius": 0.62,
		"xp": 24, "coins": [3, 8], "item_chance": 0.2, "potion_chance": 0.1,
		"windup": 0.75, "reach": 1.9, "cooldown": 1.6, "arc": 120.0, "scale": 1.15, "glow": Color(1.0, 0.5, 0.1), "body": Color(0.5, 0.12, 0.06),
	},
	"frostmaw": {
		"name": "The Frostmaw", "ai": "boss", "hp": 1700.0, "dmg": 31.0, "speed": 2.8, "radius": 1.3,
		"xp": 1300, "coins": [300, 400], "item_chance": 1.0, "potion_chance": 1.0,
		"windup": 0.78, "reach": 5.2, "cooldown": 1.3, "scale": 2.6,
		"glow": Color(0.5, 0.9, 1.0), "body": Color(0.35, 0.5, 0.68),
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
