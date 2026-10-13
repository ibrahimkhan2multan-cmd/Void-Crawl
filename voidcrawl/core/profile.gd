class_name VCProfile
extends RefCounted
## Persistent character: level, XP, attributes, inventory, equipment, coins.

const MAX_LEVEL := 20
const INV_CAP := 36
const MAX_POTIONS := 3

var level: int = 1
var xp: int = 0
var attr_points: int = 0
var attrs: Dictionary = {"str": 0, "vit": 0, "agi": 0, "arc": 0}
var coins: int = 0
var potions: int = MAX_POTIONS
var inventory: Array = []            # Array[Dictionary] items
var equipment: Dictionary = {}       # slot(int) -> item Dictionary
var completed: Array = []            # mission ids
var stats: Dictionary = {"kills": 0, "deaths": 0, "chests": 0, "bosses": 0, "playtime": 0.0, "items_found": 0}
var next_uid: int = 1

static func new_game() -> VCProfile:
	var p := VCProfile.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var blade := VCItems.generate(rng, 1, VCDefs.Rarity.COMMON, VCDefs.Slot.WEAPON, 0.0, p.alloc_uid())
	blade["base"] = "ashen_blade"
	blade["dmg_min"] = 9
	blade["dmg_max"] = 12
	blade["name"] = "Ashen Blade"
	p.equipment[VCDefs.Slot.WEAPON] = blade
	return p

func alloc_uid() -> int:
	var u := next_uid
	next_uid += 1
	return u

func xp_needed(lvl: int = -1) -> int:
	if lvl < 0:
		lvl = level
	return int(55.0 * pow(float(lvl), 1.5)) + 20

## Returns number of levels gained.
func add_xp(amount: int) -> int:
	if amount <= 0 or level >= MAX_LEVEL:
		return 0
	xp += amount
	var gained := 0
	while level < MAX_LEVEL and xp >= xp_needed():
		xp -= xp_needed()
		level += 1
		attr_points += 3
		gained += 1
	if level >= MAX_LEVEL:
		xp = 0
	return gained

func spend_point(attr: String) -> bool:
	if attr_points <= 0 or not attrs.has(attr):
		return false
	attrs[attr] = int(attrs[attr]) + 1
	attr_points -= 1
	return true

func add_item(item: Dictionary) -> bool:
	if item.is_empty() or inventory.size() >= INV_CAP:
		return false
	inventory.append(item)
	return true

## Equip an item from inventory (by index). The previously equipped item returns to inventory.
func equip_from_inventory(index: int) -> bool:
	if index < 0 or index >= inventory.size():
		return false
	var item: Dictionary = inventory[index]
	var slot: int = int(item["slot"])
	var old: Dictionary = equipment.get(slot, {})
	equipment[slot] = item
	inventory.remove_at(index)
	if not old.is_empty():
		inventory.append(old)
	return true

func unequip(slot: int) -> bool:
	var old: Dictionary = equipment.get(slot, {})
	if old.is_empty() or inventory.size() >= INV_CAP:
		return false
	equipment.erase(slot)
	inventory.append(old)
	return true

func sell_item(index: int) -> int:
	if index < 0 or index >= inventory.size():
		return 0
	var v := VCItems.sell_value(inventory[index])
	inventory.remove_at(index)
	coins += v
	return v

## All derived combat stats. This is what the Player actually reads.
func derived() -> Dictionary:
	var t := VCItems.totals(equipment)
	var lvl_b := float(level - 1)
	var str_ := float(attrs["str"])
	var vit := float(attrs["vit"])
	var agi := float(attrs["agi"])
	var arc := float(attrs["arc"])
	var d := {}
	d["max_hp"] = int(round(90.0 + vit * 8.0 + lvl_b * 6.0 + float(t["hp"])))
	d["armor"] = float(t["def"]) + lvl_b * 0.6
	d["dmg_mult"] = 1.0 + str_ * 0.04 + float(t["atk_pct"]) / 100.0
	d["dmg_min"] = float(t["dmg_min"])
	d["dmg_max"] = float(t["dmg_max"])
	d["interval"] = float(t["interval"])
	d["range"] = float(t["range"])
	d["arc"] = float(t["arc"])
	d["ranged"] = bool(t["ranged"])
	d["weapon_kind"] = String(t["kind"])
	d["move_speed"] = 6.2 * (1.0 + agi * 0.008 + float(t["speed"]) / 100.0)
	d["crit"] = clampf(0.05 + agi * 0.004 + float(t["crit"]) / 100.0, 0.0, 0.75)
	d["ability_mult"] = 1.0 + arc * 0.06
	d["cd_mult"] = clampf(1.0 - arc * 0.01 - float(t["cdr"]) / 100.0, 0.4, 1.0)
	d["leech"] = float(t["leech"]) / 100.0
	d["coin_mult"] = 1.0 + float(t["coin"]) / 100.0
	var avg := (float(t["dmg_min"]) + float(t["dmg_max"])) * 0.5
	d["power"] = int(round(avg * float(d["dmg_mult"]) * (1.0 + float(d["crit"])) / maxf(float(t["interval"]), 0.1) + float(d["max_hp"]) / 10.0 + float(d["armor"])))
	return d

func to_dict() -> Dictionary:
	var eq := {}
	for slot in equipment:
		eq[str(slot)] = equipment[slot]
	return {
		"level": level, "xp": xp, "attr_points": attr_points, "attrs": attrs.duplicate(),
		"coins": coins, "potions": potions, "inventory": inventory.duplicate(true),
		"equipment": eq, "completed": completed.duplicate(), "stats": stats.duplicate(),
		"next_uid": next_uid,
	}

static func from_dict(d: Dictionary) -> VCProfile:
	var p := VCProfile.new()
	p.level = clampi(int(d.get("level", 1)), 1, MAX_LEVEL)
	p.xp = maxi(int(d.get("xp", 0)), 0)
	p.attr_points = maxi(int(d.get("attr_points", 0)), 0)
	var a: Dictionary = d.get("attrs", {})
	for k in VCDefs.ATTR_IDS:
		p.attrs[k] = maxi(int(a.get(k, 0)), 0)
	p.coins = maxi(int(d.get("coins", 0)), 0)
	p.potions = clampi(int(d.get("potions", MAX_POTIONS)), 0, MAX_POTIONS)
	for raw in d.get("inventory", []):
		if raw is Dictionary:
			var it := VCItems.sanitize(raw)
			if not it.is_empty():
				p.inventory.append(it)
	var eq: Dictionary = d.get("equipment", {})
	for k in eq:
		if eq[k] is Dictionary:
			var it2 := VCItems.sanitize(eq[k])
			if not it2.is_empty():
				p.equipment[int(it2["slot"])] = it2
	for m in d.get("completed", []):
		p.completed.append(String(m))
	var st: Dictionary = d.get("stats", {})
	for k in p.stats:
		if st.has(k):
			p.stats[k] = st[k] if k == "playtime" else int(st[k])
	p.next_uid = maxi(int(d.get("next_uid", 1)), 1)
	# make sure uids never collide with saved items
	for it in p.inventory:
		p.next_uid = maxi(p.next_uid, int(it["uid"]) + 1)
	for s in p.equipment:
		p.next_uid = maxi(p.next_uid, int(p.equipment[s]["uid"]) + 1)
	return p
