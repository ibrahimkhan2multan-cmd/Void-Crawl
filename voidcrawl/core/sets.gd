class_name VCSets
extends RefCounted
## Armour sets: five pieces each (helm, armor, leggings, boots, trinket). Wearing 2, 4 or all 5 pieces of the
## same set grants real stat bonuses (added in VCItems.totals) and unlocks matching hero visuals/animations.
## Older / modded sets with only four pieces still work (they simply have no leggings and no 5-piece bonus).

const SLOT_KEYS := {1: "helm", 2: "armor", 4: "boots", 3: "trinket", 5: "legs"}
const PIECE_KEYS := ["helm", "armor", "legs", "boots", "trinket"]

static var DEFS := {
	"gloomguard": {
		"name": "Gloomguard Plate", "mission": "crypt",
		"color": Color(0.5, 0.52, 0.72), "glow": Color(0.7, 0.45, 1.0),
		"pieces": {"helm": "gg_helm", "armor": "gg_plate", "legs": "gg_tassets", "boots": "gg_greaves", "trinket": "gg_sigil"},
		"b5": {"hp": 40, "def": 10, "kill_heal": 3}, "t5": "+40 Health, +10 Defense, kills heal 3% more",
		"b2": {"def": 12, "hp": 25}, "b4": {"kill_heal": 5, "regen": 40, "def": 8},
		"t2": "+12 Defense, +25 Health", "t4": "Each kill heals 5% of max health, +40% regen, +8 Defense",
		"flavor": "Forged by the keepers of the Hollow Crypt.",
	},
	"voidwalker": {
		"name": "Voidwalker Regalia", "mission": "delve",
		"color": Color(0.38, 0.15, 0.62), "glow": Color(0.9, 0.4, 1.0),
		"pieces": {"helm": "vw_crown", "armor": "vw_robes", "legs": "vw_leggings", "boots": "vw_treads", "trinket": "vw_core"},
		"b5": {"cdr": 8, "crit": 4, "nova_pct": 40}, "t5": "+8% Cooldown Reduction, +4% Crit, Void Nova +40% damage more",
		"b2": {"cdr": 10, "crit": 5}, "b4": {"speed": 10, "crit": 8, "nova_pct": 45},
		"t2": "+10% Cooldown Reduction, +5% Crit", "t4": "+10% Move Speed, +8% Crit, Void Nova deals +45% damage",
		"flavor": "Woven from the dark between worlds.",
	},
	"emberlord": {
		"name": "Emberlord's Panoply", "mission": "forge",
		"color": Color(0.2, 0.12, 0.12), "glow": Color(1.0, 0.5, 0.15),
		"pieces": {"helm": "el_helm", "armor": "el_mail", "legs": "el_cuisses", "boots": "el_stompers", "trinket": "el_brand"},
		"b5": {"atk_pct": 14, "leech": 2, "hp": 25}, "t5": "+14% Damage, +2% Life Leech, +25 Health",
		"b2": {"atk_pct": 8, "hp": 15}, "b4": {"atk_pct": 16, "leech": 3},
		"t2": "+8% Damage, +15 Health", "t4": "+16% Damage, +3% Life Leech",
		"flavor": "Hammered in the heart of the Emberdeep.",
	},
	"frostwarden": {
		"name": "Frostwarden Aegis", "mission": "frost",
		"color": Color(0.6, 0.78, 0.95), "glow": Color(0.5, 0.9, 1.0),
		"pieces": {"helm": "fw_crown", "armor": "fw_plate", "legs": "fw_legguards", "boots": "fw_striders", "trinket": "fw_heart"},
		"b5": {"def": 10, "speed": 6, "cdr": 5, "dodge_wave": 80}, "t5": "+10 Defense, +6% Move Speed, +5% Cooldown Reduction, stronger frost shockwave",
		"b2": {"def": 8, "speed": 6}, "b4": {"dodge_wave": 160, "def": 8, "hp": 30},
		"t2": "+8 Defense, +6% Move Speed", "t4": "Dodge rolls release a frost shockwave, +8 Defense, +30 Health",
		"flavor": "Cut from the ice that never melts.",
	},
	"friendship": {
		"name": "Bond of Friendship", "mission": "",
		"color": Color(0.95, 0.8, 0.35), "glow": Color(0.5, 0.95, 1.0),
		"pieces": {"helm": "bf_helm", "armor": "bf_plate", "legs": "bf_leggings", "boots": "bf_boots", "trinket": "bf_charm"},
		"b5": {"atk_pct": 10, "crit": 6, "coin": 20, "regen": 25}, "t5": "+10% Damage, +6% Crit, +20% Coin Find, +25% regen",
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
		if n >= 5 and d.has("b5"):
			for k in d["b5"]:
				t[k] = float(t.get(k, 0.0)) + float(d["b5"][k])
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
	var pieces: Dictionary = DEFS[set_id]["pieces"]
	var keys: Array = []
	for pk in PIECE_KEYS:
		if pieces.has(pk):
			keys.append(pk)
	var key: String = String(keys[rng.randi_range(0, keys.size() - 1)]) if slot < 0 else String(SLOT_KEYS.get(slot, "helm"))
	if not pieces.has(key):
		key = String(keys[0])
	var base_id: String = pieces[key]
	return VCItems.generate(rng, ilvl, maxi(rarity, VCDefs.Rarity.RARE), -1, 0.0, uid, base_id)
