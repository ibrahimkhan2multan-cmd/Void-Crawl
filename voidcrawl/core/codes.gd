class_name VCCodes
extends RefCounted
## Promo / easter-egg codes. Each code works once per save. Codes are matched ignoring case,
## spaces, dashes and underscores. A code never needs the network.

const MAAZ_LORE := "Forged for InfinityxMaaz - a gift from Infinity Studios."

## id -> {"msg": toast, "coins": n, "xp": n, "points": n, "potions": n, "bombs": n, "items": [spec...]}
## item spec: {"base": id, "rarity": r, "ilvl": n}  or  {"custom": "maaz"}
const DEFS := {
	"INFINITYXMAAZ": {"msg": "Easter egg unlocked: the Infinity Edge!", "coins": 250, "items": [{"custom": "maaz"}]},
	"VOIDCRAWL": {"msg": "Welcome to the Void, crawler.", "coins": 300},
	"INFINITYSTUDIOS": {"msg": "Supplies from Infinity Studios.", "coins": 400, "potions": 3, "bombs": 5},
	"SWIFTFEET": {"msg": "Fleet-footed!", "items": [{"base": "windrunners", "rarity": 2, "ilvl": 4}]},
	"EMBERDEEP": {"msg": "The forge remembers you.", "items": [{"base": "ember_mail", "rarity": 2, "ilvl": 6}, {"base": "ember_striders", "rarity": 2, "ilvl": 6}]},
	"FIRSTBLOOD": {"msg": "A taste of power.", "xp": 400},
	"LUCKYDAY": {"msg": "Fortune smiles.", "coins": 200, "items": [{"base": "lucky_coin", "rarity": 3, "ilvl": 5}]},
	"DELVER": {"msg": "Your potential grows.", "points": 3},
	"HEARTSTONE": {"msg": "A beating heart of stone.", "items": [{"base": "heartstone", "rarity": 3, "ilvl": 6}]},
	"VOIDWALKER": {"msg": "You walk between worlds.", "items": [{"base": "voidwalkers", "rarity": 3, "ilvl": 7}]},
}

static func normalise(code: String) -> String:
	var out := ""
	for ch in code.to_upper():
		if (ch >= "A" and ch <= "Z") or (ch >= "0" and ch <= "9"):
			out += ch
	return out

static func _make_item(spec: Dictionary, p: VCProfile) -> Dictionary:
	if String(spec.get("custom", "")) == "maaz":
		return {
			"uid": p.alloc_uid(), "base": "infinity_edge", "slot": VCDefs.Slot.WEAPON,
			"rarity": VCDefs.Rarity.EPIC, "ilvl": 6, "name": "Infinity Edge of Maaz",
			"dmg_min": 15, "dmg_max": 20, "crit": 6, "speed": 5,
			"affixes": [{"id": "leech", "val": 2}], "lore": MAAZ_LORE,
		}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(spec.get("base", ""))) + p.next_uid
	return VCItems.generate(rng, int(spec.get("ilvl", 1)), int(spec.get("rarity", 2)), -1, 0.0, p.alloc_uid(), String(spec["base"]))

## Returns {"ok": bool, "msg": String}. Applies the reward to the profile on success.
static func redeem(raw: String, p: VCProfile) -> Dictionary:
	var code := normalise(raw)
	if code == "":
		return {"ok": false, "msg": "Type a code first."}
	if not DEFS.has(code):
		return {"ok": false, "msg": "That code is not valid."}
	if p.redeemed.has(code):
		return {"ok": false, "msg": "You already used this code."}
	var d: Dictionary = DEFS[code]
	var specs: Array = d.get("items", [])
	if p.inventory.size() + specs.size() > VCProfile.INV_CAP:
		return {"ok": false, "msg": "Backpack too full - free up %d slot(s) first." % specs.size()}
	var got: Array = []
	for spec in specs:
		var it := _make_item(spec, p)
		if not it.is_empty() and p.add_item(it):
			got.append(String(it["name"]))
	p.coins += int(d.get("coins", 0))
	if int(d.get("xp", 0)) > 0:
		p.add_xp(int(d["xp"]))
	p.attr_points += int(d.get("points", 0))
	p.potions = clampi(p.potions + int(d.get("potions", 0)), 0, VCProfile.MAX_POTIONS)
	p.bombs = clampi(p.bombs + int(d.get("bombs", 0)), 0, VCProfile.MAX_BOMBS)
	p.redeemed.append(code)
	var lines: Array = [String(d.get("msg", "Code redeemed!"))]
	if int(d.get("coins", 0)) > 0:
		lines.append("+%d coins" % int(d["coins"]))
	if int(d.get("xp", 0)) > 0:
		lines.append("+%d XP" % int(d["xp"]))
	if int(d.get("points", 0)) > 0:
		lines.append("+%d attribute points" % int(d["points"]))
	if int(d.get("potions", 0)) > 0 or int(d.get("bombs", 0)) > 0:
		lines.append("Potions and bombs restocked")
	for g in got:
		lines.append("Received: %s" % g)
	return {"ok": true, "msg": "\n".join(lines)}
