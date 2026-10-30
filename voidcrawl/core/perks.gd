class_name VCPerks
extends RefCounted
## Perks: passive bonuses bought with coins and slotted (up to SLOTS at once). Mods can add more.
## A perk's "bonus" uses the same stat keys as armour set bonuses (def, hp, speed, crit, atk_pct, ...).

const SLOTS := 3                    # base number of slots (upgrades add more: VCProfile.perk_slots())

static var DEFS := {
	"iron_skin": {"name": "Iron Skin", "desc": "Toughened hide.", "cost": 150, "bonus": {"def": 6}, "color": Color(0.7, 0.75, 0.9)},
	"swift_feet": {"name": "Swift Feet", "desc": "Light on your toes.", "cost": 150, "bonus": {"speed": 7}, "color": Color(0.5, 1.0, 0.7)},
	"sharpened": {"name": "Sharpened Edge", "desc": "Every blow bites deeper.", "cost": 220, "bonus": {"atk_pct": 7}, "color": Color(1.0, 0.6, 0.4)},
	"eagle_eye": {"name": "Eagle Eye", "desc": "See the weak spot.", "cost": 220, "bonus": {"crit": 6}, "color": Color(1.0, 0.9, 0.4)},
	"vampiric": {"name": "Vampiric Touch", "desc": "Your wounds close as theirs open.", "cost": 320, "bonus": {"leech": 3}, "color": Color(1.0, 0.35, 0.5)},
	"greedy": {"name": "Gold Nose", "desc": "You always find the coin.", "cost": 120, "bonus": {"coin": 25}, "color": Color(1.0, 0.85, 0.3)},
	"vital": {"name": "Vital Spark", "desc": "More life to spend.", "cost": 200, "bonus": {"hp": 40}, "color": Color(1.0, 0.45, 0.45)},
	"quickhands": {"name": "Quick Hands", "desc": "Abilities recharge faster.", "cost": 300, "bonus": {"cdr": 10}, "color": Color(0.6, 0.8, 1.0)},
	"bloodthirst": {"name": "Bloodthirst", "desc": "Each kill mends you.", "cost": 450, "bonus": {"kill_heal": 2}, "color": Color(0.9, 0.2, 0.3)},
}

static func exists(id: String) -> bool:
	return DEFS.has(id)

static func bonus_text(id: String) -> String:
	if not DEFS.has(id):
		return ""
	var parts: Array = []
	var b: Dictionary = DEFS[id]["bonus"]
	for k in b:
		parts.append(VCSets.stat_text(String(k), float(b[k])))
	return ", ".join(parts)

## Sum of the bonuses of the given perk ids (unknown ids are ignored, e.g. from a disabled mod).
static func totals(active: Array, slots: int = SLOTS) -> Dictionary:
	var out := {}
	var n := 0
	for id in active:
		if not DEFS.has(String(id)) or n >= slots:
			continue
		n += 1
		var b: Dictionary = DEFS[String(id)]["bonus"]
		for k in b:
			out[k] = float(out.get(k, 0.0)) + float(b[k])
	return out
