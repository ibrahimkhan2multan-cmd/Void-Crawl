class_name VCSets
extends RefCounted
## Armour sets: four pieces each (helm, armor, boots, trinket). Wearing 2 or 4 pieces of the same set
## grants real stat bonuses (added in VCItems.totals) and unlocks matching hero visuals/animations.

const SLOT_KEYS := {1: "helm", 2: "armor", 4: "boots", 3: "trinket"}

const DEFS := {
	"gloomguard": {
		"name": "Gloomguard Plate", "mission": "crypt",
		"color": Color(0.5, 0.52, 0.72), "glow": Color(0.7, 0.45, 1.0),
		"pieces": {"helm": "gg_helm", "armor": "gg_plate", "boots": "gg_greaves", "trinket": "gg_sigil"},
		"b2": {"def": 12, "hp": 25}, "b4": {"kill_heal": 5, "regen": 40, "def": 8},
		"t2": "+12 Defense, +25 Health", "t4": "Each kill heals 5% of max health, +40% regen, +8 Defense",
		"flavor": "Forged by the keepers of the Hollow Crypt.",
	},
	"voidwalker": {
		"name": "Voidwalker Regalia", "mission": "delve",
		"color": Color(0.38, 0.15, 0.62), "glow": Color(0.9, 0.4, 1.0),
		"pieces": {"helm": "vw_crown", "armor": "vw_robes", "boots": "vw_treads", "trinket": "vw_core"},
		"b2": {"cdr": 10, "crit": 5}, "b4": {"speed": 10, "crit": 8, "nova_pct": 45},
		"t2": "+10% Cooldown Reduction, +5% Crit", "t4": "+10% Move Speed, +8% Crit, Void Nova deals +45% damage",
		"flavor": "Woven from the dark between worlds.",
	},
	"emberlord": {
		"name": "Emberlord's Panoply", "mission": "forge",
		"color": Color(0.2, 0.12, 0.12), "glow": Color(1.0, 0.5, 0.15),
		"pieces": {"helm": "el_helm", "armor": "el_mail", "boots": "el_stompers", "trinket": "el_brand"},
		"b2": {"atk_pct": 8, "hp": 15}, "b4": {"atk_pct": 16, "leech": 3},
		"t2": "+8% Damage, +15 Health", "t4": "+16% Damage, +3% Life Leech",
		"flavor": "Hammered in the heart of the Emberdeep.",
	},
	"frostwarden": {
		"name": "Frostwarden Aegis", "mission": "frost",
		"color": Color(0.6, 0.78, 0.95), "glow": Color(0.5, 0.9, 1.0),
		"pieces": {"helm": "fw_crown", "armor": "fw_plate", "boots": "fw_striders", "trinket": "fw_heart"},
		"b2": {"def": 8, "speed": 6}, "b4": {"dodge_wave": 160, "def": 8, "hp": 30},
		"t2": "+8 Defense, +6% Move Speed", "t4": "Dodge rolls release a frost shockwave, +8 Defense, +30 Health",
		"flavor": "Cut from the ice that never melts.",
	},
	"friendship": {
		"name": "Bond of Friendship", "mission": "",
		"color": Color(0.95, 0.8, 0.35), "glow": Color(0.5, 0.95, 1.0),
		"pieces": {"helm": "bf_helm", "armor": "bf_plate", "boots": "bf_boots", "trinket": "bf_charm"},
		"b2": {"crit": 6, "coin": 15}, "b4": {"atk_pct": 12, "speed": 8, "kill_heal": 3, "regen": 25},
		"t2": "+6% Crit, +15% Coin Find", "t4": "+12% Damage, +8% Move Speed, kills heal 3%, +25% regen",
		"flavor": "Two heroes, one bond. Power of friendship.",
	},
}

static func set_of(item: Dictionary) -> String:
	if item.is_empty():
		return ""
	return String(item.get("set", ""))

## set id -> number of equipped pieces
static func counts(equipment: Dictionary) -> Dictionary:
	var out := {}
	for slot in equipment:
		var sid := set_of(equipment[slot])
		if sid != "" and DEFS.has(sid):
			out[sid] = int(out.get(sid, 0)) + 1
	return out

## Flat stat bonuses from all active set tiers.
static func bonus_totals(equipment: Dictionary) -> Dictionary:
	var t := {}
	var c := counts(equipment)
	for sid in c:
		var n: int = c[sid]
		var d: Dictionary = DEFS[sid]
		if n >= 2:
			for k in d["b2"]:
				t[k] = float(t.get(k, 0.0)) + float(d["b2"][k])
		if n >= 4:
			for k in d["b4"]:
				t[k] = float(t.get(k, 0.0)) + float(d["b4"][k])
	return t

static func stat_text(k: String, v: float) -> String:
	match k:
		"def": return "+%d Defense" % int(v)
		"hp": return "+%d Health" % int(v)
		"speed": return "+%d%% Move Speed" % int(v)
		"crit": return "+%d%% Crit Chance" % int(v)
		"atk_pct": return "+%d%% Damage" % int(v)
		"cdr": return "+%d%% Cooldown Reduction" % int(v)
		"leech": return "+%d%% Life Leech" % int(v)
		"coin": return "+%d%% Coin Find" % int(v)
		"regen": return "+%d%% Health Regen" % int(v)
		"kill_heal": return "Kills heal %d%% max health" % int(v)
		"dodge_wave": return "Dodge shockwave (%d%% weapon damage)" % int(v)
		"nova_pct": return "Void Nova +%d%% damage" % int(v)
	return k

## A random piece of `set_id` for `slot` (-1 = random slot) at the given rarity/level.
static func make_piece(rng: RandomNumberGenerator, set_id: String, ilvl: int, rarity: int, slot: int, uid: int) -> Dictionary:
	if not DEFS.has(set_id):
		return {}
	var keys := ["helm", "armor", "boots", "trinket"]
	var key: String = keys[rng.randi_range(0, 3)] if slot < 0 else String(SLOT_KEYS.get(slot, "helm"))
	var base_id: String = DEFS[set_id]["pieces"][key]
	return VCItems.generate(rng, ilvl, maxi(rarity, VCDefs.Rarity.RARE), -1, 0.0, uid, base_id)
