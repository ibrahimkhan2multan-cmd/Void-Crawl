class_name VCItems
extends RefCounted
## Item database, random item generation, and stat aggregation.
## Items are plain JSON-friendly Dictionaries so they save/load trivially.

# kind: sword/axe/dagger/bow for weapons. range = reach (melee) or max distance (ranged).
const BASES := {
	"ashen_blade": {"name": "Ashen Blade", "slot": 0, "kind": "sword", "dmg": [9, 12], "interval": 0.42,
		"range": 2.7, "arc": 115.0, "ranged": false, "color": Color(0.78, 0.78, 0.9)},
	"gloomaxe": {"name": "Gloomaxe", "slot": 0, "kind": "axe", "dmg": [17, 23], "interval": 0.74,
		"range": 3.0, "arc": 150.0, "ranged": false, "color": Color(0.55, 0.5, 0.65)},
	"voidfang": {"name": "Voidfang Dagger", "slot": 0, "kind": "dagger", "dmg": [5, 7], "interval": 0.25,
		"range": 2.2, "arc": 95.0, "ranged": false, "color": Color(0.7, 0.4, 1.0)},
	"wraithbow": {"name": "Wraithbow", "slot": 0, "kind": "bow", "dmg": [9, 13], "interval": 0.58,
		"range": 15.0, "arc": 0.0, "ranged": true, "color": Color(0.5, 0.9, 0.85)},
	"oathspear": {"name": "Oathspear", "slot": 0, "kind": "spear", "dmg": [12, 16], "interval": 0.58,
		"range": 3.9, "arc": 46.0, "ranged": false, "color": Color(0.7, 0.85, 0.95)},
	"grave_hammer": {"name": "Grave Hammer", "slot": 0, "kind": "hammer", "dmg": [27, 36], "interval": 1.05,
		"range": 2.9, "arc": 165.0, "ranged": false, "color": Color(0.5, 0.48, 0.58)},
	"duskbolt": {"name": "Duskbolt Crossbow", "slot": 0, "kind": "crossbow", "dmg": [18, 24], "interval": 0.95,
		"range": 17.0, "arc": 0.0, "ranged": true, "color": Color(0.6, 0.45, 0.35)},
	"starless_staff": {"name": "Starless Staff", "slot": 0, "kind": "staff", "dmg": [8, 11], "interval": 0.4,
		"range": 13.0, "arc": 0.0, "ranged": true, "color": Color(0.45, 0.6, 1.0)},
	"moonlit_saber": {"name": "Moonlit Saber", "slot": 0, "kind": "sword", "dmg": [10, 14], "interval": 0.40,
		"range": 2.8, "arc": 120.0, "ranged": false, "color": Color(0.7, 0.85, 1.0)},
	"bone_cleaver": {"name": "Bone Cleaver", "slot": 0, "kind": "axe", "dmg": [14, 19], "interval": 0.62,
		"range": 2.9, "arc": 140.0, "ranged": false, "color": Color(0.88, 0.85, 0.75)},
	"cinder_longbow": {"name": "Cinder Longbow", "slot": 0, "kind": "bow", "dmg": [11, 15], "interval": 0.52,
		"range": 16.0, "arc": 0.0, "ranged": true, "color": Color(1.0, 0.55, 0.25)},
	"frostbrand": {"name": "Frostbrand", "slot": 0, "kind": "sword", "dmg": [13, 17], "interval": 0.46,
		"range": 2.8, "arc": 120.0, "ranged": false, "color": Color(0.6, 0.9, 1.0)},
	"infinity_edge": {"name": "The Power of Friendship", "slot": 0, "kind": "sword", "dmg": [15, 20], "interval": 0.38,
		"range": 2.9, "arc": 125.0, "ranged": false, "color": Color(0.45, 0.95, 1.0), "unique": true},
	"gg_helm": {"name": "Gloomguard Helm", "slot": 1, "kind": "helm", "def": 9, "hp": 16, "color": Color(0.5, 0.52, 0.72), "set": "gloomguard", "unique": true},
	"gg_plate": {"name": "Gloomguard Plate", "slot": 2, "kind": "armor", "def": 16, "hp": 34, "speed": -2, "color": Color(0.46, 0.48, 0.68), "set": "gloomguard", "unique": true},
	"gg_greaves": {"name": "Gloomguard Greaves", "slot": 4, "kind": "boots", "def": 6, "hp": 12, "speed": 3, "color": Color(0.44, 0.46, 0.64), "set": "gloomguard", "unique": true},
	"gg_sigil": {"name": "Gloomguard Sigil", "slot": 3, "kind": "trinket", "hp": 24, "def": 4, "color": Color(0.75, 0.5, 1.0), "set": "gloomguard", "unique": true},
	"vw_crown": {"name": "Voidwalker Crown", "slot": 1, "kind": "helm", "def": 4, "hp": 10, "crit": 5, "color": Color(0.45, 0.2, 0.7), "set": "voidwalker", "unique": true},
	"vw_robes": {"name": "Voidwalker Robes", "slot": 2, "kind": "armor", "def": 7, "hp": 18, "crit": 3, "cdr": 3, "color": Color(0.38, 0.15, 0.62), "set": "voidwalker", "unique": true},
	"vw_treads": {"name": "Voidwalker Treads", "slot": 4, "kind": "boots", "speed": 9, "cdr": 3, "color": Color(0.55, 0.2, 0.85), "set": "voidwalker", "unique": true},
	"vw_core": {"name": "Voidwalker Core", "slot": 3, "kind": "trinket", "cdr": 7, "crit": 3, "color": Color(0.9, 0.4, 1.0), "set": "voidwalker", "unique": true},
	"el_helm": {"name": "Emberlord Horned Helm", "slot": 1, "kind": "helm", "def": 7, "hp": 14, "atk_pct": 3, "color": Color(0.28, 0.14, 0.12), "set": "emberlord", "unique": true},
	"el_mail": {"name": "Emberlord Mail", "slot": 2, "kind": "armor", "def": 13, "hp": 28, "atk_pct": 4, "color": Color(0.3, 0.15, 0.13), "set": "emberlord", "unique": true},
	"el_stompers": {"name": "Emberlord Stompers", "slot": 4, "kind": "boots", "def": 4, "hp": 8, "speed": 6, "atk_pct": 2, "color": Color(0.26, 0.13, 0.11), "set": "emberlord", "unique": true},
	"el_brand": {"name": "Emberlord Brand", "slot": 3, "kind": "trinket", "atk_pct": 7, "leech": 1, "color": Color(1.0, 0.5, 0.15), "set": "emberlord", "unique": true},
	"fw_crown": {"name": "Frostwarden Crown", "slot": 1, "kind": "helm", "def": 8, "hp": 15, "cdr": 3, "color": Color(0.65, 0.85, 1.0), "set": "frostwarden", "unique": true},
	"fw_plate": {"name": "Frostwarden Plate", "slot": 2, "kind": "armor", "def": 15, "hp": 32, "color": Color(0.6, 0.78, 0.95), "set": "frostwarden", "unique": true},
	"fw_striders": {"name": "Frostwarden Striders", "slot": 4, "kind": "boots", "def": 4, "hp": 8, "speed": 8, "color": Color(0.7, 0.92, 1.0), "set": "frostwarden", "unique": true},
	"fw_heart": {"name": "Frostwarden Heart", "slot": 3, "kind": "trinket", "hp": 30, "def": 3, "regen": 30, "color": Color(0.5, 0.9, 1.0), "set": "frostwarden", "unique": true},
	"bf_helm": {"name": "Helm of the Bond", "slot": 1, "kind": "helm", "def": 7, "hp": 14, "crit": 3, "color": Color(0.95, 0.8, 0.35), "set": "friendship", "unique": true},
	"bf_plate": {"name": "Plate of the Bond", "slot": 2, "kind": "armor", "def": 12, "hp": 26, "atk_pct": 3, "color": Color(0.9, 0.75, 0.3), "set": "friendship", "unique": true},
	"bf_boots": {"name": "Boots of the Bond", "slot": 4, "kind": "boots", "def": 4, "hp": 8, "speed": 8, "color": Color(0.5, 0.9, 1.0), "set": "friendship", "unique": true},
	"bf_charm": {"name": "Charm of the Bond", "slot": 3, "kind": "trinket", "hp": 18, "coin": 10, "regen": 20, "color": Color(1.0, 0.45, 0.75), "set": "friendship", "unique": true},
	"hollow_cap": {"name": "Hollow Cap", "slot": 1, "kind": "helm", "def": 4, "hp": 10, "color": Color(0.6, 0.58, 0.68)},
	"crypt_hood": {"name": "Crypt Hood", "slot": 1, "kind": "helm", "def": 2, "hp": 6, "speed": 3, "color": Color(0.35, 0.25, 0.5)},
	"bone_helm": {"name": "Bone Helm", "slot": 1, "kind": "helm", "def": 6, "hp": 14, "color": Color(0.85, 0.82, 0.74)},
	"iron_greathelm": {"name": "Iron Greathelm", "slot": 1, "kind": "helm", "def": 9, "hp": 18, "speed": -2, "color": Color(0.55, 0.57, 0.62)},
	"wraith_mask": {"name": "Wraith Mask", "slot": 1, "kind": "helm", "def": 3, "hp": 8, "crit": 4, "color": Color(0.7, 0.9, 0.95)},
	"ironbark_vest": {"name": "Ironbark Vest", "slot": 2, "kind": "armor", "def": 8, "hp": 22, "color": Color(0.4, 0.34, 0.28)},
	"shade_robe": {"name": "Shade Robe", "slot": 2, "kind": "armor", "def": 4, "hp": 14, "crit": 3, "color": Color(0.28, 0.18, 0.42)},
	"gravemail": {"name": "Gravemail", "slot": 2, "kind": "armor", "def": 13, "hp": 30, "speed": -3, "color": Color(0.45, 0.45, 0.55)},
	"titan_plate": {"name": "Titan Plate", "slot": 2, "kind": "armor", "def": 18, "hp": 40, "speed": -5, "color": Color(0.62, 0.6, 0.7)},
	"ember_mail": {"name": "Ember Mail", "slot": 2, "kind": "armor", "def": 10, "hp": 26, "atk_pct": 4, "color": Color(0.85, 0.4, 0.22)},
	"rime_crown": {"name": "Rime Crown", "slot": 1, "kind": "helm", "def": 8, "hp": 16, "cdr": 4, "color": Color(0.7, 0.9, 1.0)},
	"glacier_plate": {"name": "Glacier Plate", "slot": 2, "kind": "armor", "def": 15, "hp": 34, "speed": -2, "color": Color(0.6, 0.78, 0.95)},
	"icewalkers": {"name": "Icewalkers", "slot": 4, "kind": "boots", "speed": 9, "def": 3, "hp": 6, "color": Color(0.7, 0.92, 1.0)},
	"frozen_heart": {"name": "Frozen Heart", "slot": 3, "kind": "trinket", "hp": 30, "def": 4, "color": Color(0.6, 0.85, 1.0)},
	"spiked_helm": {"name": "Spiked Helm", "slot": 1, "kind": "helm", "def": 7, "hp": 12, "atk_pct": 3, "color": Color(0.5, 0.5, 0.58)},
	"cultist_cowl": {"name": "Cultist Cowl", "slot": 1, "kind": "helm", "def": 2, "hp": 8, "cdr": 5, "color": Color(0.5, 0.15, 0.2)},
	"duskplate": {"name": "Duskplate", "slot": 2, "kind": "armor", "def": 11, "hp": 24, "regen": 25, "color": Color(0.3, 0.3, 0.45)},
	"nightweave": {"name": "Nightweave Cloak", "slot": 2, "kind": "armor", "def": 5, "hp": 16, "speed": 4, "crit": 2, "color": Color(0.15, 0.12, 0.3)},
	"scuffed_boots": {"name": "Scuffed Boots", "slot": 4, "kind": "boots", "speed": 4, "def": 1, "color": Color(0.42, 0.3, 0.2)},
	"crypt_treads": {"name": "Crypt Treads", "slot": 4, "kind": "boots", "speed": 6, "def": 2, "hp": 4, "color": Color(0.35, 0.3, 0.45)},
	"ironshod_greaves": {"name": "Ironshod Greaves", "slot": 4, "kind": "boots", "def": 6, "hp": 12, "speed": -1, "color": Color(0.55, 0.57, 0.62)},
	"shadowstep": {"name": "Shadowstep Boots", "slot": 4, "kind": "boots", "speed": 9, "cdr": 3, "color": Color(0.22, 0.14, 0.38)},
	"windrunners": {"name": "Windrunner Boots", "slot": 4, "kind": "boots", "speed": 12, "color": Color(0.6, 0.9, 0.95)},
	"ember_striders": {"name": "Ember Striders", "slot": 4, "kind": "boots", "speed": 8, "atk_pct": 3, "color": Color(1.0, 0.5, 0.2)},
	"voidwalkers": {"name": "Voidwalkers", "slot": 4, "kind": "boots", "speed": 10, "cdr": 5, "color": Color(0.7, 0.35, 1.0)},
	"gravewalkers": {"name": "Gravewalkers", "slot": 4, "kind": "boots", "speed": 5, "def": 4, "hp": 10, "regen": 25, "color": Color(0.6, 0.62, 0.5)},
	"heartstone": {"name": "Heartstone", "slot": 3, "kind": "trinket", "regen": 60, "hp": 20, "color": Color(1.0, 0.3, 0.45)},
	"lucky_coin": {"name": "Lucky Coin", "slot": 3, "kind": "trinket", "coin": 25, "color": Color(1.0, 0.85, 0.3)},
	"ember_charm": {"name": "Ember Charm", "slot": 3, "kind": "trinket", "atk_pct": 6, "color": Color(1.0, 0.5, 0.25)},
	"void_shard": {"name": "Void Shard", "slot": 3, "kind": "trinket", "cdr": 8, "color": Color(0.75, 0.35, 1.0)},
	"leech_ring": {"name": "Leech Ring", "slot": 3, "kind": "trinket", "leech": 2, "color": Color(0.9, 0.2, 0.4)},
}

# id -> [label, min, max] at item level 1.
const AFFIXES := {
	"atk_pct": ["+%d%% Damage", 4.0, 8.0],
	"hp": ["+%d Health", 8.0, 16.0],
	"def": ["+%d Defense", 2.0, 4.0],
	"crit": ["+%d%% Crit Chance", 2.0, 4.0],
	"speed": ["+%d%% Move Speed", 2.0, 4.0],
	"leech": ["+%d%% Life Leech", 1.0, 2.0],
	"cdr": ["+%d%% Cooldown Reduction", 3.0, 6.0],
	"coin": ["+%d%% Coin Find", 6.0, 12.0],
	"regen": ["+%d%% Health Regen", 15.0, 35.0],
}

const NAME_PREFIX := ["Gloom", "Void", "Ashen", "Hollow", "Umbral", "Wraith", "Dusk", "Grave", "Nether", "Starless"]
const NAME_SUFFIX := {
	"atk_pct": "of Ruin", "hp": "of Vigor", "def": "of Warding", "crit": "of Precision",
	"speed": "of Haste", "leech": "of the Leech", "cdr": "of Echoes", "coin": "of Greed", "regen": "of Renewal",
}
const UNCOMMON_PREFIX := ["Sturdy", "Keen", "Tempered", "Polished"]

static func base_ids_for_slot(slot: int) -> Array:
	var out: Array = []
	for id in BASES:
		if int(BASES[id]["slot"]) == slot and not bool(BASES[id].get("unique", false)):
			out.append(id)
	out.sort()
	return out

static func base_color(item: Dictionary) -> Color:
	var b: Dictionary = BASES.get(item.get("base", ""), {})
	return b.get("color", Color.WHITE)

static func _level_mult(ilvl: int) -> float:
	return 1.0 + 0.11 * float(maxi(ilvl, 1) - 1)

static func roll_rarity(rng: RandomNumberGenerator, luck: float = 0.0) -> int:
	var total := 0.0
	var w: Array[float] = []
	for i in VCDefs.RARITY_WEIGHTS.size():
		var v: float = VCDefs.RARITY_WEIGHTS[i] * (1.0 + luck * float(i))
		w.append(v)
		total += v
	var r := rng.randf() * total
	for i in w.size():
		r -= w[i]
		if r <= 0.0:
			return i
	return 0

## Generate an item. rarity/slot = -1 means random.
static func generate(rng: RandomNumberGenerator, ilvl: int, rarity: int = -1, slot: int = -1, luck: float = 0.0, uid: int = 0, force_base: String = "") -> Dictionary:
	if rarity < 0:
		rarity = roll_rarity(rng, luck)
	rarity = clampi(rarity, 0, 4)
	if slot < 0:
		# weapons slightly more common so upgrades are visible
		var sr := rng.randf()
		slot = 0 if sr < 0.27 else (1 if sr < 0.45 else (2 if sr < 0.66 else (3 if sr < 0.83 else 4)))
	var ids := base_ids_for_slot(slot)
	var base_id: String = ids[rng.randi_range(0, ids.size() - 1)]
	if force_base != "" and BASES.has(force_base):
		base_id = force_base
		slot = int(BASES[force_base]["slot"])
	var b: Dictionary = BASES[base_id]
	var rm: float = VCDefs.RARITY_STAT_MULT[rarity]
	var lm := _level_mult(ilvl)
	var item := {
		"uid": uid, "base": base_id, "slot": slot, "rarity": rarity, "ilvl": maxi(ilvl, 1),
		"affixes": [],
	}
	if b.has("set"):
		item["set"] = String(b["set"])
	if slot == VCDefs.Slot.WEAPON:
		var d: Array = b["dmg"]
		item["dmg_min"] = maxi(1, int(round(float(d[0]) * lm * rm)))
		item["dmg_max"] = maxi(item["dmg_min"], int(round(float(d[1]) * lm * rm)))
	else:
		for k in ["def", "hp", "speed", "crit", "atk_pct", "cdr", "leech", "coin", "regen"]:
			if b.has(k):
				var v: float = float(b[k])
				if k == "def" or k == "hp":
					v *= lm * rm
				elif v > 0.0:
					v *= (0.8 + 0.2 * rm)
				item[k] = int(round(v))
	# affixes
	var pool: Array = AFFIXES.keys()
	pool.sort()
	var n_aff: int = VCDefs.RARITY_AFFIX_COUNT[rarity]
	for i in n_aff:
		if pool.is_empty():
			break
		var idx := rng.randi_range(0, pool.size() - 1)
		var aid: String = pool[idx]
		pool.remove_at(idx)
		var spec: Array = AFFIXES[aid]
		var val := lerpf(float(spec[1]), float(spec[2]), rng.randf()) * (1.0 + 0.06 * float(ilvl - 1)) * (0.85 + 0.15 * rm)
		item["affixes"].append({"id": aid, "val": maxi(1, int(round(val)))})
	item["name"] = _make_name(rng, item, b)
	return item

static func _make_name(rng: RandomNumberGenerator, item: Dictionary, b: Dictionary) -> String:
	var r: int = item["rarity"]
	var base_name: String = b["name"]
	if b.has("set"):
		return base_name
	if r == VCDefs.Rarity.COMMON:
		return base_name
	if r == VCDefs.Rarity.UNCOMMON:
		return "%s %s" % [UNCOMMON_PREFIX[rng.randi_range(0, UNCOMMON_PREFIX.size() - 1)], base_name]
	var nm := "%s %s" % [NAME_PREFIX[rng.randi_range(0, NAME_PREFIX.size() - 1)], base_name]
	if r >= VCDefs.Rarity.EPIC and not item["affixes"].is_empty():
		var top: Dictionary = item["affixes"][0]
		nm += " " + String(NAME_SUFFIX.get(top["id"], "of the Void"))
	return nm

## Make a defensive, JSON-normalised copy (JSON turns ints into floats).
static func sanitize(raw: Dictionary) -> Dictionary:
	if not raw.has("base") or not BASES.has(raw["base"]):
		return {}
	var item := {}
	item["uid"] = int(raw.get("uid", 0))
	item["base"] = String(raw["base"])
	item["slot"] = int(BASES[item["base"]]["slot"])
	item["rarity"] = clampi(int(raw.get("rarity", 0)), 0, 4)
	item["ilvl"] = maxi(int(raw.get("ilvl", 1)), 1)
	item["name"] = String(raw.get("name", BASES[item["base"]]["name"]))
	if raw.has("lore"):
		item["lore"] = String(raw["lore"])
	if BASES[item["base"]].has("set"):
		item["set"] = String(BASES[item["base"]]["set"])
	for k in ["dmg_min", "dmg_max", "def", "hp", "speed", "crit", "atk_pct", "cdr", "leech", "coin", "regen"]:
		if raw.has(k):
			item[k] = int(raw[k])
	var affs: Array = []
	for a in raw.get("affixes", []):
		if a is Dictionary and AFFIXES.has(String(a.get("id", ""))):
			affs.append({"id": String(a["id"]), "val": int(a.get("val", 0))})
	item["affixes"] = affs
	return item

## Sum up equipment: Dictionary slot(int) -> item. Returns flat stat dictionary.
static func totals(equipment: Dictionary) -> Dictionary:
	var t := {
		"dmg_min": 3.0, "dmg_max": 4.0, "interval": 0.5, "range": 2.2, "arc": 100.0, "ranged": false,
		"kind": "fist", "def": 0.0, "hp": 0.0, "speed": 0.0, "crit": 0.0, "atk_pct": 0.0,
		"cdr": 0.0, "leech": 0.0, "coin": 0.0, "regen": 0.0,
		"kill_heal": 0.0, "dodge_wave": 0.0, "nova_pct": 0.0,
	}
	for slot in equipment:
		var it: Dictionary = equipment[slot]
		if it.is_empty():
			continue
		var b: Dictionary = BASES.get(it.get("base", ""), {})
		if b.is_empty():
			continue
		if int(it.get("slot", -1)) == VCDefs.Slot.WEAPON:
			t["dmg_min"] = float(it.get("dmg_min", 1))
			t["dmg_max"] = float(it.get("dmg_max", 2))
			t["interval"] = float(b["interval"])
			t["range"] = float(b["range"])
			t["arc"] = float(b["arc"])
			t["ranged"] = bool(b["ranged"])
			t["kind"] = String(b["kind"])
		for k in ["def", "hp", "speed", "crit", "atk_pct", "cdr", "leech", "coin", "regen"]:
			if it.has(k):
				t[k] += float(it[k])
		for a in it.get("affixes", []):
			var aid: String = a["id"]
			var key := "atk_pct" if aid == "atk_pct" else aid
			t[key] = float(t.get(key, 0.0)) + float(a["val"])
	var sb := VCSets.bonus_totals(equipment)
	for k in sb:
		t[k] = float(t.get(k, 0.0)) + float(sb[k])
	return t

static func affix_text(a: Dictionary) -> String:
	var spec: Array = AFFIXES.get(a["id"], ["%d", 0, 0])
	return String(spec[0]) % int(a["val"])

## Human-readable stat lines for an item (used by inventory UI).
static func describe(item: Dictionary) -> Array:
	var lines: Array = []
	if item.is_empty():
		return lines
	var b: Dictionary = BASES.get(item["base"], {})
	if int(item["slot"]) == VCDefs.Slot.WEAPON:
		var avg := (float(item.get("dmg_min", 0)) + float(item.get("dmg_max", 0))) * 0.5
		lines.append("Damage %d-%d" % [item.get("dmg_min", 0), item.get("dmg_max", 0)])
		lines.append("%s  |  %.1f hits/sec  |  DPS %.1f" % ["Ranged" if b.get("ranged", false) else "Melee", 1.0 / float(b["interval"]), avg / float(b["interval"])])
	if item.has("def"):
		lines.append("+%d Defense" % item["def"])
	if item.has("hp"):
		lines.append("+%d Health" % item["hp"])
	if item.has("speed") and int(item["speed"]) != 0:
		lines.append("%s%d%% Move Speed" % ["+" if int(item["speed"]) > 0 else "", item["speed"]])
	if item.has("crit"):
		lines.append("+%d%% Crit Chance" % item["crit"])
	if item.has("atk_pct"):
		lines.append("+%d%% Damage" % item["atk_pct"])
	if item.has("cdr"):
		lines.append("+%d%% Cooldown Reduction" % item["cdr"])
	if item.has("leech"):
		lines.append("+%d%% Life Leech" % item["leech"])
	if item.has("coin"):
		lines.append("+%d%% Coin Find" % item["coin"])
	if item.has("regen"):
		lines.append("+%d%% Health Regen" % item["regen"])
	for a in item.get("affixes", []):
		lines.append(affix_text(a))
	if item.has("lore"):
		lines.append(String(item["lore"]))
	return lines

## Single comparable number per slot, used for "upgrade / downgrade" hints.
static func score(item: Dictionary) -> float:
	if item.is_empty():
		return 0.0
	var s := 0.0
	var b: Dictionary = BASES.get(item["base"], {})
	if int(item["slot"]) == VCDefs.Slot.WEAPON:
		var avg := (float(item.get("dmg_min", 0)) + float(item.get("dmg_max", 0))) * 0.5
		s += avg / float(b["interval"]) * 2.0
	s += float(item.get("def", 0)) * 2.0 + float(item.get("hp", 0)) * 0.6
	s += float(item.get("speed", 0)) * 2.0 + float(item.get("crit", 0)) * 3.0
	s += float(item.get("atk_pct", 0)) * 3.0 + float(item.get("cdr", 0)) * 2.0 + float(item.get("leech", 0)) * 6.0 + float(item.get("regen", 0)) * 0.5 + float(item.get("coin", 0)) * 0.4
	if item.has("set"):
		s += 12.0
	for a in item.get("affixes", []):
		match String(a["id"]):
			"atk_pct": s += float(a["val"]) * 3.0
			"hp": s += float(a["val"]) * 0.6
			"def": s += float(a["val"]) * 2.0
			"crit": s += float(a["val"]) * 3.0
			"speed": s += float(a["val"]) * 2.0
			"leech": s += float(a["val"]) * 6.0
			"cdr": s += float(a["val"]) * 2.0
			"coin": s += float(a["val"]) * 0.4
			"regen": s += float(a["val"]) * 0.5
	return s

static func sell_value(item: Dictionary) -> int:
	return int(VCDefs.RARITY_SELL[clampi(int(item.get("rarity", 0)), 0, 4)]) + int(item.get("ilvl", 1)) * 2
