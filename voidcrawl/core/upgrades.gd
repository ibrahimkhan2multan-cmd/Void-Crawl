class_name VCUpgrades
extends RefCounted
## Permanent upgrades bought with coins from the UPGRADES screen: bigger backpack, potion belt, bomb pouch,
## more perk slots, stronger potions and a kennel for extra pets. Levels live in VCProfile.upgrades.

static var DEFS := {
	"backpack": {"name": "Backpack", "per": 6, "max": 8, "base_cost": 140, "growth": 1.55, "color": Color(0.85, 0.65, 0.35),
		"desc": "Carry more gear. +6 backpack slots per level."},
	"potion_belt": {"name": "Potion Belt", "per": 1, "max": 7, "base_cost": 180, "growth": 1.6, "color": Color(1.0, 0.4, 0.5),
		"desc": "Carry more health potions. +1 potion per level."},
	"bomb_pouch": {"name": "Bomb Pouch", "per": 1, "max": 7, "base_cost": 150, "growth": 1.55, "color": Color(1.0, 0.7, 0.35),
		"desc": "Carry more void bombs. +1 bomb per level."},
	"perk_slots": {"name": "Perk Slots", "per": 1, "max": 6, "base_cost": 400, "growth": 1.9, "color": Color(0.7, 0.5, 1.0),
		"desc": "Equip more perks at once. +1 perk slot per level."},
	"potion_potency": {"name": "Alchemy", "per": 8, "max": 5, "base_cost": 260, "growth": 1.8, "color": Color(0.45, 1.0, 0.65),
		"desc": "Potions heal more. +8% of max health per level (base 50%)."},
	"kennel": {"name": "Kennel", "per": 1, "max": 2, "base_cost": 1500, "growth": 4.0, "color": Color(0.95, 0.8, 0.4),
		"desc": "Bring more pets along. +1 active pet per level."},
}
const ORDER := ["backpack", "potion_belt", "bomb_pouch", "perk_slots", "potion_potency", "kennel"]

static func level(p: VCProfile, id: String) -> int:
	return clampi(int(p.upgrades.get(id, 0)), 0, int(DEFS[id]["max"])) if DEFS.has(id) else 0

static func max_level(id: String) -> int:
	return int(DEFS[id]["max"]) if DEFS.has(id) else 0

## Coin cost of the NEXT level (-1 when already maxed).
static func cost(p: VCProfile, id: String) -> int:
	if not DEFS.has(id):
		return -1
	var lv := level(p, id)
	if lv >= int(DEFS[id]["max"]):
		return -1
	return int(round(float(DEFS[id]["base_cost"]) * pow(float(DEFS[id]["growth"]), float(lv))))

## Returns "" on success, otherwise the reason.
static func buy(p: VCProfile, id: String) -> String:
	if not DEFS.has(id):
		return "Unknown upgrade."
	var c := cost(p, id)
	if c < 0:
		return "Already at the maximum level."
	if p.coins < c:
		return "Not enough coins (%d needed)." % c
	p.coins -= c
	p.upgrades[id] = level(p, id) + 1
	return ""

## Human text for the current effect, e.g. "36 slots".
static func effect_text(p: VCProfile, id: String) -> String:
	match id:
		"backpack": return "%d slots" % p.inv_cap()
		"potion_belt": return "%d potions" % p.max_potions()
		"bomb_pouch": return "%d bombs" % p.max_bombs()
		"perk_slots": return "%d slots" % p.perk_slots()
		"potion_potency": return "heals %d%%" % int(round(p.potion_heal_frac() * 100.0))
		"kennel": return "%d active pet%s" % [p.pet_slots(), "" if p.pet_slots() == 1 else "s"]
	return ""
