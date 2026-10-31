class_name VCProfile
extends RefCounted
## Persistent character: level, XP, attributes, inventory, equipment, coins.

const MAX_LEVEL := 20
const INV_CAP := 36                  # base backpack size (see inv_cap() for the upgraded value)
const MAX_BOMBS := 5                 # base bomb capacity (see max_bombs())
const MAX_POTIONS := 3               # base potion capacity (see max_potions())
const BASE_PERK_SLOTS := 3
const HARD_INV_CAP := 120
const MAX_PET_LEVEL := 10

var level: int = 1
var xp: int = 0
var attr_points: int = 0
var attrs: Dictionary = {"str": 0, "vit": 0, "agi": 0, "arc": 0}
var coins: int = 0
var potions: int = MAX_POTIONS
var bombs: int = 3
var inventory: Array = []            # Array[Dictionary] items
var equipment: Dictionary = {}       # slot(int) -> item Dictionary
var completed: Array = []            # mission ids
var stats: Dictionary = {"kills": 0, "deaths": 0, "chests": 0, "bosses": 0, "playtime": 0.0, "items_found": 0}
var next_uid: int = 1
var mod_stash: Array = []            # items whose mod is off/missing; restored when it returns
var perks_owned: Array = []          # perk ids bought
var perks_active: Array = []         # perk ids slotted (max VCPerks.SLOTS)
var redeemed: Array = []             # promo codes already used (normalised)
var upgrades: Dictionary = {}        # VCUpgrades id -> level
var auto_rarities: Array = []        # rarity numbers that are auto-removed on pickup
var auto_mode := "sell"              # "sell" (pays coins) or "delete"
var auto_keep_upgrades := true       # never auto-remove an item that beats what you wear
var pets: Dictionary = {}            # pet species id -> level (1..MAX_PET_LEVEL)
var pets_parked: Dictionary = {}     # pets of a mod that is switched off; they come back with it
var pets_active: Array = []          # species ids that follow you
var eggs: Dictionary = {}            # egg tier id -> count owned
var pet_feed := true                 # pets may eat your potions to heal

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

# ---- capacities (base + upgrades) ----
func inv_cap() -> int:
	return mini(INV_CAP + VCUpgrades.level(self, "backpack") * int(VCUpgrades.DEFS["backpack"]["per"]), HARD_INV_CAP)

func max_potions() -> int:
	return MAX_POTIONS + VCUpgrades.level(self, "potion_belt")

func max_bombs() -> int:
	return MAX_BOMBS + VCUpgrades.level(self, "bomb_pouch")

func perk_slots() -> int:
	return BASE_PERK_SLOTS + VCUpgrades.level(self, "perk_slots")

func pet_slots() -> int:
	return 1 + VCUpgrades.level(self, "kennel")

## Fraction of max health one potion restores.
func potion_heal_frac() -> float:
	return 0.5 + 0.01 * float(VCUpgrades.level(self, "potion_potency") * int(VCUpgrades.DEFS["potion_potency"]["per"]))

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
	if item.is_empty() or inventory.size() >= inv_cap():
		return false
	inventory.append(item)
	return true

## True when this item is covered by the auto-delete filter. Set pieces, unique/lore items are never touched.
func should_auto_remove(item: Dictionary) -> bool:
	if item.is_empty() or auto_rarities.is_empty():
		return false
	if not auto_rarities.has(int(item.get("rarity", 0))):
		return false
	if item.has("set") or item.has("lore"):
		return false
	var b: Dictionary = VCItems.BASES.get(String(item.get("base", "")), {})
	if bool(b.get("unique", false)):
		return false
	if auto_keep_upgrades:
		var cur: Dictionary = equipment.get(int(item.get("slot", 0)), {})
		if VCItems.score(item) > VCItems.score(cur) + 0.5:
			return false
	return true

func toggle_auto_rarity(r: int) -> void:
	if auto_rarities.has(r):
		auto_rarities.erase(r)
	else:
		auto_rarities.append(r)
		auto_rarities.sort()

## Remove every backpack item the filter covers. Returns {"count": n, "coins": n}.
func sweep_auto() -> Dictionary:
	var n := 0
	var gained := 0
	var i := inventory.size() - 1
	while i >= 0:
		if should_auto_remove(inventory[i]):
			if auto_mode == "sell":
				gained += VCItems.sell_value(inventory[i])
			inventory.remove_at(i)
			n += 1
		i -= 1
	coins += gained
	return {"count": n, "coins": gained}

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
	if old.is_empty() or inventory.size() >= inv_cap():
		return false
	equipment.erase(slot)
	inventory.append(old)
	return true

## Buy a perk with coins. Returns "" on success or the reason it failed.
func buy_perk(id: String) -> String:
	if not VCPerks.DEFS.has(id):
		return "That perk is not available."
	if perks_owned.has(id):
		return "You already own this perk."
	var cost := int(VCPerks.DEFS[id]["cost"])
	if coins < cost:
		return "Not enough coins (%d needed)." % cost
	coins -= cost
	perks_owned.append(id)
	return ""

## Slot or unslot an owned perk. Returns "" on success or the reason it failed.
func toggle_perk(id: String) -> String:
	if not perks_owned.has(id):
		return "Buy this perk first."
	if perks_active.has(id):
		perks_active.erase(id)
		return ""
	var live := 0
	for a in perks_active:
		if VCPerks.DEFS.has(String(a)):
			live += 1
	if live >= perk_slots():
		return "All %d perk slots are full - unequip one first." % perk_slots()
	perks_active.append(id)
	return ""

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
	var pt := VCPerks.totals(perks_active, perk_slots())
	for pk in pt:
		t[pk] = float(t.get(pk, 0.0)) + float(pt[pk])
	var pet_t := VCPets.totals(self)
	for pk2 in pet_t:
		t[pk2] = float(t.get(pk2, 0.0)) + float(pet_t[pk2])
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
	d["move_speed"] = 6.2 * (1.0 + agi * 0.008 + clampf(float(t["speed"]), -20.0, 55.0) / 100.0)
	d["crit"] = clampf(0.05 + agi * 0.004 + float(t["crit"]) / 100.0, 0.0, 0.75)
	d["ability_mult"] = 1.0 + arc * 0.06 + float(t["nova_pct"]) / 100.0
	d["kill_heal"] = float(t["kill_heal"]) / 100.0
	d["dodge_wave"] = float(t["dodge_wave"]) / 100.0
	d["cd_mult"] = clampf(1.0 - arc * 0.01 - float(t["cdr"]) / 100.0, 0.4, 1.0)
	d["leech"] = float(t["leech"]) / 100.0
	d["coin_mult"] = 1.0 + float(t["coin"]) / 100.0
	d["regen_bonus"] = float(t["regen"]) / 100.0 + vit * 0.03
	var avg := (float(t["dmg_min"]) + float(t["dmg_max"])) * 0.5
	VCTester.apply(d)
	d["power"] = int(round(avg * float(d["dmg_mult"]) * (1.0 + float(d["crit"])) / maxf(float(t["interval"]), 0.1) + float(d["max_hp"]) / 10.0 + float(d["armor"])))
	return d

## Derived stats as they would be if `item` were equipped (does not change anything).
func preview_derived(item: Dictionary) -> Dictionary:
	var slot: int = int(item["slot"])
	var had := equipment.has(slot)
	var old: Dictionary = equipment.get(slot, {})
	equipment[slot] = item
	var d := derived()
	if had:
		equipment[slot] = old
	else:
		equipment.erase(slot)
	return d

## Average damage per second (crits included) for a derived-stats dictionary.
static func dps_of(d: Dictionary) -> float:
	var avg := (float(d["dmg_min"]) + float(d["dmg_max"])) * 0.5
	return avg * float(d["dmg_mult"]) * (1.0 + float(d["crit"]) * 0.75) / maxf(float(d["interval"]), 0.1)

## After the mod list changed: park items whose base vanished, bring back stashed ones that exist again.
## Returns {"parked": n, "restored": n}.
func reconcile_mod_items() -> Dictionary:
	var parked := 0
	var restored := 0
	var keep: Array = []
	for it in inventory:
		if VCItems.BASES.has(String(it.get("base", ""))):
			keep.append(it)
		elif mod_stash.size() < 300:
			mod_stash.append(it)
			parked += 1
	inventory = keep
	for slot in equipment.keys():
		if not VCItems.BASES.has(String(equipment[slot].get("base", ""))):
			if mod_stash.size() < 300:
				mod_stash.append(equipment[slot])
			equipment.erase(slot)
			parked += 1
	var left: Array = []
	for raw in mod_stash:
		var clean := VCItems.sanitize(raw)
		if clean.is_empty() or inventory.size() >= inv_cap():
			left.append(raw)
		else:
			inventory.append(clean)
			restored += 1
	mod_stash = left
	reconcile_mod_pets()
	return {"parked": parked, "restored": restored}

## Pets from a mod that is off are put away (never lost); pets whose mod is back return.
func reconcile_mod_pets() -> void:
	for id in pets.keys():
		if not VCPets.SPECIES.has(String(id)):
			pets_parked[id] = pets[id]
			pets.erase(id)
	for id in pets_parked.keys():
		if VCPets.SPECIES.has(String(id)):
			pets[id] = maxi(int(pets.get(id, 0)), int(pets_parked[id]))
			pets_parked.erase(id)
	var keep: Array = []
	for id in pets_active:
		if pets.has(String(id)) and keep.size() < pet_slots():
			keep.append(id)
	pets_active = keep

func to_dict() -> Dictionary:
	var eq := {}
	for slot in equipment:
		eq[str(slot)] = equipment[slot]
	return {
		"level": level, "xp": xp, "attr_points": attr_points, "attrs": attrs.duplicate(),
		"coins": coins, "potions": potions, "bombs": bombs, "inventory": inventory.duplicate(true),
		"equipment": eq, "completed": completed.duplicate(), "stats": stats.duplicate(),
		"next_uid": next_uid, "redeemed": redeemed.duplicate(), "perks_owned": perks_owned.duplicate(), "perks_active": perks_active.duplicate(), "mod_stash": mod_stash.duplicate(true),
		"upgrades": upgrades.duplicate(), "auto_rarities": auto_rarities.duplicate(), "auto_mode": auto_mode, "auto_keep_upgrades": auto_keep_upgrades,
		"pets": pets.duplicate(), "pets_parked": pets_parked.duplicate(), "pets_active": pets_active.duplicate(), "eggs": eggs.duplicate(), "pet_feed": pet_feed,
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
	var up: Dictionary = d.get("upgrades", {})
	for uid in VCUpgrades.DEFS:
		if up.has(uid):
			p.upgrades[uid] = clampi(int(up[uid]), 0, VCUpgrades.max_level(uid))
	p.potions = clampi(int(d.get("potions", MAX_POTIONS)), 0, p.max_potions())
	p.bombs = clampi(int(d.get("bombs", 3)), 0, p.max_bombs())
	for ar in d.get("auto_rarities", []):
		var ari := clampi(int(ar), 0, VCDefs.RARITY_MAX)
		if not p.auto_rarities.has(ari):
			p.auto_rarities.append(ari)
	p.auto_rarities.sort()
	p.auto_mode = "delete" if String(d.get("auto_mode", "sell")) == "delete" else "sell"
	p.auto_keep_upgrades = bool(d.get("auto_keep_upgrades", true))
	var pd: Dictionary = d.get("pets", {})
	for pid in pd:
		if VCPets.SPECIES.has(String(pid)):
			p.pets[String(pid)] = clampi(int(pd[pid]), 1, MAX_PET_LEVEL)
		else:
			p.pets_parked[String(pid)] = clampi(int(pd[pid]), 1, MAX_PET_LEVEL)
	var ppk: Dictionary = d.get("pets_parked", {})
	for pid in ppk:
		if VCPets.SPECIES.has(String(pid)):
			p.pets[String(pid)] = maxi(int(p.pets.get(String(pid), 0)), clampi(int(ppk[pid]), 1, MAX_PET_LEVEL))
		else:
			p.pets_parked[String(pid)] = clampi(int(ppk[pid]), 1, MAX_PET_LEVEL)
	for pa2 in d.get("pets_active", []):
		if p.pets.has(String(pa2)) and not p.pets_active.has(String(pa2)) and p.pets_active.size() < p.pet_slots():
			p.pets_active.append(String(pa2))
	var ed: Dictionary = d.get("eggs", {})
	for eid in ed:
		if VCPets.EGGS.has(String(eid)):
			p.eggs[String(eid)] = clampi(int(ed[eid]), 0, 999)
	p.pet_feed = bool(d.get("pet_feed", true))
	for raw in d.get("inventory", []):
		if raw is Dictionary:
			var it := VCItems.sanitize(raw)
			if not it.is_empty():
				p.inventory.append(it)
			elif raw.has("base") and p.mod_stash.size() < 300:
				p.mod_stash.append(raw)
	var eq: Dictionary = d.get("equipment", {})
	for k in eq:
		if eq[k] is Dictionary:
			var it2 := VCItems.sanitize(eq[k])
			if not it2.is_empty():
				p.equipment[int(it2["slot"])] = it2
			elif eq[k].has("base") and p.mod_stash.size() < 300:
				p.mod_stash.append(eq[k])
	for m in d.get("completed", []):
		p.completed.append(String(m))
	var st: Dictionary = d.get("stats", {})
	for k in p.stats:
		if st.has(k):
			p.stats[k] = st[k] if k == "playtime" else int(st[k])
	for st_raw in d.get("mod_stash", []):
		if st_raw is Dictionary and st_raw.has("base") and p.mod_stash.size() < 300:
			p.mod_stash.append(st_raw)
	for po in d.get("perks_owned", []):
		if not p.perks_owned.has(String(po)) and p.perks_owned.size() < 80:
			p.perks_owned.append(String(po))
	for pa in d.get("perks_active", []):
		if p.perks_owned.has(String(pa)) and not p.perks_active.has(String(pa)) and p.perks_active.size() < p.perk_slots():
			p.perks_active.append(String(pa))
	for rc in d.get("redeemed", []):
		p.redeemed.append(String(rc))
	p.next_uid = maxi(int(d.get("next_uid", 1)), 1)
	# make sure uids never collide with saved items
	for it in p.inventory:
		p.next_uid = maxi(p.next_uid, int(it["uid"]) + 1)
	for s in p.equipment:
		p.next_uid = maxi(p.next_uid, int(p.equipment[s]["uid"]) + 1)
	return p
