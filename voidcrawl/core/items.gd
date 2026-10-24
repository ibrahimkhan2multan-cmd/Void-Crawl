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
		if int(BASES[id]["slot"]) == slot:
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
		slot = 0 if sr < 0.32 else (1 if sr < 0.55 else (2 if sr < 0.8 else 3))
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
