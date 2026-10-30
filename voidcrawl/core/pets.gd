class_name VCPets
extends RefCounted
## Pets: companions that follow you, fight on their own and can be upgraded. They are found by hatching eggs
## (bought in the PETS screen or dropped by bosses). Each species has a rarity, a fighting style and a small
## passive bonus for you while it is active. All numbers here are data; the actor is actors/pet.gd.

# style = how the model is built; ai = "melee" | "ranged"
static var SPECIES := {
	"pup": {"name": "Gloom Pup", "rarity": 0, "style": "quad", "ai": "melee", "hp": 70.0, "dmg": 5.0, "interval": 0.8, "reach": 1.9, "speed": 6.4,
		"col": Color(0.34, 0.26, 0.5), "col2": Color(0.7, 0.55, 0.95), "glow": Color(0.75, 0.45, 1.0), "scale": 0.8,
		"passive": {"coin": 4}, "blurb": "A loyal pup from the Hollow Crypt. Sniffs out coins."},
	"bat": {"name": "Cave Bat", "rarity": 0, "style": "bird", "ai": "melee", "hp": 46.0, "dmg": 4.0, "interval": 0.55, "reach": 1.8, "speed": 7.6, "float": 1.1,
		"col": Color(0.25, 0.2, 0.32), "col2": Color(0.5, 0.35, 0.6), "glow": Color(1.0, 0.4, 0.5), "scale": 0.7,
		"passive": {"speed": 3}, "blurb": "Fast and fragile. Flits around your enemies."},
	"slime": {"name": "Jelly Slime", "rarity": 0, "style": "blob", "ai": "melee", "hp": 115.0, "dmg": 4.0, "interval": 1.0, "reach": 1.7, "speed": 4.6,
		"col": Color(0.3, 0.85, 0.5), "col2": Color(0.6, 1.0, 0.7), "glow": Color(0.5, 1.0, 0.6), "scale": 0.85,
		"passive": {"hp": 10}, "blurb": "Wobbly and tough. Soaks up hits."},
	"raven": {"name": "Bone Raven", "rarity": 1, "style": "bird", "ai": "ranged", "hp": 56.0, "dmg": 6.0, "interval": 1.1, "reach": 9.5, "speed": 6.6, "float": 1.3,
		"col": Color(0.82, 0.8, 0.74), "col2": Color(0.3, 0.28, 0.34), "glow": Color(0.7, 0.9, 1.0), "scale": 0.75,
		"passive": {"crit": 2}, "blurb": "Throws bone shards from a safe distance."},
	"imp": {"name": "Ember Imp", "rarity": 1, "style": "imp", "ai": "ranged", "hp": 62.0, "dmg": 8.0, "interval": 1.2, "reach": 9.5, "speed": 5.8,
		"col": Color(0.75, 0.22, 0.14), "col2": Color(1.0, 0.6, 0.2), "glow": Color(1.0, 0.5, 0.15), "scale": 0.8,
		"passive": {"atk_pct": 2}, "blurb": "Hurls fireballs and cackles."},
	"fox": {"name": "Frost Fox", "rarity": 2, "style": "quad", "ai": "melee", "hp": 92.0, "dmg": 7.0, "interval": 0.6, "reach": 1.9, "speed": 7.4,
		"col": Color(0.85, 0.94, 1.0), "col2": Color(0.45, 0.75, 1.0), "glow": Color(0.55, 0.9, 1.0), "scale": 0.85,
		"passive": {"speed": 3, "cdr": 2}, "blurb": "Quick bites, quicker feet."},
	"golem": {"name": "Moss Golem", "rarity": 2, "style": "golem", "ai": "melee", "hp": 210.0, "dmg": 10.0, "interval": 1.3, "reach": 2.2, "speed": 4.4,
		"col": Color(0.4, 0.45, 0.38), "col2": Color(0.3, 0.7, 0.35), "glow": Color(0.5, 1.0, 0.5), "scale": 1.0,
		"passive": {"def": 4, "hp": 12}, "blurb": "A slow wall of mossy stone."},
	"wisp": {"name": "Void Wisp", "rarity": 3, "style": "orb", "ai": "ranged", "hp": 84.0, "dmg": 10.0, "interval": 0.9, "reach": 10.5, "speed": 6.2, "float": 1.2,
		"col": Color(0.55, 0.2, 0.95), "col2": Color(0.85, 0.6, 1.0), "glow": Color(0.8, 0.45, 1.0), "scale": 0.8, "pierce": 1,
		"passive": {"cdr": 4, "crit": 2}, "blurb": "Its bolts pierce through two foes."},
	"drake": {"name": "Ash Drake", "rarity": 3, "style": "drake", "ai": "ranged", "hp": 135.0, "dmg": 13.0, "interval": 1.3, "reach": 10.0, "speed": 5.6,
		"col": Color(0.3, 0.2, 0.2), "col2": Color(1.0, 0.45, 0.15), "glow": Color(1.0, 0.5, 0.15), "scale": 0.95,
		"passive": {"atk_pct": 4}, "blurb": "A small dragon that spits embers."},
	"griffin": {"name": "Star Griffin", "rarity": 4, "style": "bird", "ai": "melee", "hp": 175.0, "dmg": 15.0, "interval": 0.65, "reach": 2.3, "speed": 7.8, "float": 0.9,
		"col": Color(0.95, 0.85, 0.5), "col2": Color(1.0, 1.0, 0.85), "glow": Color(1.0, 0.9, 0.5), "scale": 1.05,
		"passive": {"atk_pct": 4, "speed": 4, "hp": 15}, "blurb": "Swoops on its prey with starlight claws."},
	"phoenix": {"name": "Sun Phoenix", "rarity": 4, "style": "bird", "ai": "ranged", "hp": 155.0, "dmg": 17.0, "interval": 1.0, "reach": 11.0, "speed": 6.6, "float": 1.3,
		"col": Color(1.0, 0.45, 0.15), "col2": Color(1.0, 0.85, 0.3), "glow": Color(1.0, 0.7, 0.2), "scale": 1.0,
		"passive": {"regen": 40, "leech": 1}, "blurb": "Burning wings that mend your wounds."},
	"hydra": {"name": "Void Hydra", "rarity": 5, "style": "hydra", "ai": "ranged", "hp": 270.0, "dmg": 16.0, "interval": 1.2, "reach": 11.0, "speed": 5.4, "fan": 3,
		"col": Color(0.2, 0.12, 0.34), "col2": Color(1.0, 0.3, 0.45), "glow": Color(1.0, 0.3, 0.5), "scale": 1.1,
		"passive": {"atk_pct": 6, "hp": 30, "leech": 1}, "blurb": "Three heads, three bolts."},
	"dragon": {"name": "Voidborn Dragon", "rarity": 6, "style": "drake", "ai": "ranged", "hp": 400.0, "dmg": 32.0, "interval": 1.1, "reach": 12.0, "speed": 6.4, "float": 0.5, "pierce": 2,
		"col": Color(0.1, 0.2, 0.26), "col2": Color(0.35, 1.0, 0.9), "glow": Color(0.35, 1.0, 0.9), "scale": 1.25,
		"passive": {"atk_pct": 10, "crit": 4, "def": 6}, "blurb": "A legend of the deep. Its breath pierces everything."},
}

# egg tier -> price and the chance (weights) of each PET rarity [common .. voidborn]
static var EGGS := {
	"common": {"name": "Common Egg", "cost": 300, "color": Color(0.8, 0.8, 0.86), "odds": [70.0, 25.0, 5.0, 0.0, 0.0, 0.0, 0.0]},
	"rare": {"name": "Rare Egg", "cost": 900, "color": Color(0.38, 0.58, 1.0), "odds": [20.0, 38.0, 30.0, 10.0, 2.0, 0.0, 0.0]},
	"epic": {"name": "Epic Egg", "cost": 2600, "color": Color(0.74, 0.34, 1.0), "odds": [0.0, 15.0, 40.0, 35.0, 9.0, 1.0, 0.0]},
	"mythic": {"name": "Mythic Egg", "cost": 9000, "color": Color(1.0, 0.26, 0.4), "odds": [0.0, 0.0, 10.0, 40.0, 38.0, 10.0, 2.0]},
}
const EGG_ORDER := ["common", "rare", "epic", "mythic"]

static func species_ids() -> Array:
	var ids: Array = SPECIES.keys()
	ids.sort_custom(func(a, b):
		var ra := int(SPECIES[a]["rarity"])
		var rb := int(SPECIES[b]["rarity"])
		return ra < rb if ra != rb else String(a) < String(b))
	return ids

static func rarity_of(id: String) -> int:
	return int(SPECIES[id]["rarity"]) if SPECIES.has(id) else 0

# ---- stats ------------------------------------------------------------------
## Max health of a pet at `lvl`, scaled a little with the owner's hero level.
static func max_hp(id: String, lvl: int, owner_level: int = 1) -> float:
	var d: Dictionary = SPECIES[id]
	return float(d["hp"]) * (1.0 + 0.30 * float(lvl - 1)) * (1.0 + 0.04 * float(owner_level - 1))

static func damage(id: String, lvl: int, owner_level: int = 1) -> float:
	var d: Dictionary = SPECIES[id]
	return float(d["dmg"]) * (1.0 + 0.15 * float(lvl - 1)) * (1.0 + 0.03 * float(owner_level - 1))

static func dps(id: String, lvl: int, owner_level: int = 1) -> float:
	var d: Dictionary = SPECIES[id]
	return damage(id, lvl, owner_level) * float(d.get("fan", 1)) / float(d["interval"])

## Coins to raise a pet from `lvl` to `lvl + 1` (-1 at max level).
static func upgrade_cost(id: String, lvl: int) -> int:
	if not SPECIES.has(id) or lvl >= VCProfile.MAX_PET_LEVEL:
		return -1
	return int(round(80.0 * float(rarity_of(id) + 1) * pow(float(lvl), 1.5)))

## Passive bonuses of the active pets, in the same stat keys as set bonuses / perks. Scales a little with pet level.
static func totals(p: VCProfile) -> Dictionary:
	var out := {}
	var n := 0
	for id in p.pets_active:
		if not SPECIES.has(String(id)) or not p.pets.has(String(id)) or n >= p.pet_slots():
			continue
		n += 1
		var lvl := int(p.pets[String(id)])
		var mult := 1.0 + 0.08 * float(lvl - 1)
		var b: Dictionary = SPECIES[String(id)]["passive"]
		for k in b:
			out[k] = float(out.get(k, 0.0)) + float(b[k]) * mult
	return out

static func passive_text(id: String) -> String:
	var parts: Array = []
	var b: Dictionary = SPECIES[id]["passive"]
	for k in b:
		parts.append(VCSets.stat_text(String(k), float(b[k])))
	return ", ".join(parts)

# ---- profile operations -------------------------------------------------------------
static func level_of(p: VCProfile, id: String) -> int:
	return int(p.pets.get(id, 0))

## Roll the species an egg of `tier` produces.
static func roll_species(rng: RandomNumberGenerator, tier: String) -> String:
	var odds: Array = EGGS[tier]["odds"]
	var by_rarity := {}
	for sid in SPECIES:
		var r := int(SPECIES[sid]["rarity"])
		if not by_rarity.has(r):
			by_rarity[r] = []
		(by_rarity[r] as Array).append(String(sid))
	var total := 0.0
	for r in odds.size():
		if by_rarity.has(r):
			total += float(odds[r])
	var roll := rng.randf() * total
	var pick := 0
	for r in odds.size():
		if not by_rarity.has(r):
			continue
		roll -= float(odds[r])
		if roll <= 0.0:
			pick = r
			break
	var list: Array = by_rarity.get(pick, by_rarity[0])
	list.sort()
	return String(list[rng.randi_range(0, list.size() - 1)])

## Buy an egg with coins. Returns "" on success.
static func buy_egg(p: VCProfile, tier: String) -> String:
	if not EGGS.has(tier):
		return "Unknown egg."
	var c := int(EGGS[tier]["cost"])
	if p.coins < c:
		return "Not enough coins (%d needed)." % c
	p.coins -= c
	p.eggs[tier] = int(p.eggs.get(tier, 0)) + 1
	return ""

static func egg_count(p: VCProfile, tier: String) -> int:
	return int(p.eggs.get(tier, 0))

## Hatch one owned egg. Returns {"ok": bool, "msg": String, "id": species, "new": bool, "level": n}.
static func hatch(p: VCProfile, tier: String, rng: RandomNumberGenerator) -> Dictionary:
	if not EGGS.has(tier) or egg_count(p, tier) <= 0:
		return {"ok": false, "msg": "You have no %s." % String(EGGS.get(tier, {}).get("name", "egg"))}
	p.eggs[tier] = egg_count(p, tier) - 1
	var sid := roll_species(rng, tier)
	var nm := String(SPECIES[sid]["name"])
	if not p.pets.has(sid):
		p.pets[sid] = 1
		if p.pets_active.size() < p.pet_slots():
			p.pets_active.append(sid)
		return {"ok": true, "id": sid, "new": true, "level": 1, "msg": "A new friend: %s!" % nm}
	if int(p.pets[sid]) < VCProfile.MAX_PET_LEVEL:
		p.pets[sid] = int(p.pets[sid]) + 1
		return {"ok": true, "id": sid, "new": false, "level": int(p.pets[sid]), "msg": "Duplicate %s - it grew to level %d!" % [nm, int(p.pets[sid])]}
	var refund := int(EGGS[tier]["cost"]) / 2
	p.coins += refund
	return {"ok": true, "id": sid, "new": false, "level": VCProfile.MAX_PET_LEVEL, "msg": "Duplicate %s (already max) - refunded %d coins." % [nm, refund]}

## Pay coins to raise a pet one level. Returns "" on success.
static func upgrade(p: VCProfile, id: String) -> String:
	if not p.pets.has(id):
		return "You do not own this pet."
	var lvl := int(p.pets[id])
	var c := upgrade_cost(id, lvl)
	if c < 0:
		return "This pet is at the maximum level."
	if p.coins < c:
		return "Not enough coins (%d needed)." % c
	p.coins -= c
	p.pets[id] = lvl + 1
	return ""

## Put a pet in / take it out of the active party. Returns "" on success.
static func toggle_active(p: VCProfile, id: String) -> String:
	if not p.pets.has(id):
		return "You do not own this pet."
	if p.pets_active.has(id):
		p.pets_active.erase(id)
		return ""
	if p.pets_active.size() >= p.pet_slots():
		return "Your party is full (%d). Unequip a pet or upgrade the Kennel." % p.pet_slots()
	p.pets_active.append(id)
	return ""

## The egg a boss kill drops in this dungeon (tier id), or "" for none.
static func boss_egg(mission_id: String, floor_n: int, rng: RandomNumberGenerator) -> String:
	var r := rng.randf()
	match mission_id:
		"tutorial": return ""
		"crypt": return "common"
		"forge": return "rare" if r < 0.3 else "common"
		"frost": return "epic" if r < 0.12 else ("rare" if r < 0.7 else "common")
		"delve":
			var f := maxi(floor_n, 1)
			if f >= 6 and r < 0.1:
				return "mythic"
			if f >= 3 and r < 0.3:
				return "epic"
			return "rare" if r < 0.6 else "common"
	return "common" if r < 0.7 else "rare"

## Short single-line description for lists.
static func line(id: String, lvl: int) -> String:
	return "%s  Lv %d" % [String(SPECIES[id]["name"]), lvl]
