class_name VCTester
extends RefCounted
## Developer "tester" tools, unlocked by typing the secret code TESTER on the CODES screen.
## Holds live overrides that are applied on top of the hero's derived stats, plus switches the game
## code checks (god mode, one-hit kills, frozen enemies...). Nothing here is saved except the unlock flag.

const NUMERIC := {
	"hp_add": {"label": "Max health", "step": 50.0, "min": 0.0, "max": 5000.0, "base": 0.0, "fmt": "+%d"},
	"dmg_x": {"label": "Damage multiplier", "step": 0.5, "min": 0.5, "max": 50.0, "base": 1.0, "fmt": "x%.1f"},
	"aspd_x": {"label": "Attack speed", "step": 0.25, "min": 0.5, "max": 6.0, "base": 1.0, "fmt": "x%.2f"},
	"speed_x": {"label": "Move speed", "step": 0.25, "min": 0.5, "max": 3.0, "base": 1.0, "fmt": "x%.2f"},
	"crit_add": {"label": "Crit chance", "step": 10.0, "min": 0.0, "max": 95.0, "base": 0.0, "fmt": "+%d%%"},
	"armor_add": {"label": "Armor", "step": 10.0, "min": 0.0, "max": 500.0, "base": 0.0, "fmt": "+%d"},
	"leech_add": {"label": "Life leech", "step": 5.0, "min": 0.0, "max": 100.0, "base": 0.0, "fmt": "+%d%%"},
	"cdr_add": {"label": "Cooldown reduction", "step": 10.0, "min": 0.0, "max": 90.0, "base": 0.0, "fmt": "+%d%%"},
	"kill_heal_add": {"label": "Heal per kill", "step": 5.0, "min": 0.0, "max": 100.0, "base": 0.0, "fmt": "+%d%%"},
	"coin_x": {"label": "Coin find", "step": 1.0, "min": 1.0, "max": 20.0, "base": 1.0, "fmt": "x%.0f"},
	"range_x": {"label": "Weapon reach", "step": 0.25, "min": 0.5, "max": 4.0, "base": 1.0, "fmt": "x%.2f"},
}
const NUMERIC_ORDER := ["hp_add", "dmg_x", "aspd_x", "speed_x", "crit_add", "armor_add", "leech_add", "cdr_add", "kill_heal_add", "coin_x", "range_x"]

const TOGGLES := {
	"god": "God mode (no damage taken)",
	"one_hit": "One-hit kills",
	"freeze_ai": "Freeze all enemies",
	"inf_items": "Infinite potions and bombs",
	"no_cd": "No cooldowns (roll, nova, bomb)",
}
const TOGGLE_ORDER := ["god", "one_hit", "freeze_ai", "inf_items", "no_cd"]

static var values: Dictionary = {}
static var switches: Dictionary = {}

static func unlocked() -> bool:
	return bool(VCSettings.get_value("tester_unlocked"))

static func unlock() -> void:
	VCSettings.set_value("tester_unlocked", true)
	VCSettings.save_settings()

static func num(key: String) -> float:
	return float(values.get(key, float(NUMERIC[key]["base"])))

static func set_num(key: String, v: float) -> void:
	var spec: Dictionary = NUMERIC[key]
	values[key] = clampf(v, float(spec["min"]), float(spec["max"]))

static func step(key: String, dir: int) -> void:
	set_num(key, snappedf(num(key) + float(NUMERIC[key]["step"]) * float(dir), 0.001))

static func on(key: String) -> bool:
	return unlocked() and bool(switches.get(key, false))

static func set_switch(key: String, v: bool) -> void:
	switches[key] = v

static func reset_all() -> void:
	values.clear()
	switches.clear()

static func active_count() -> int:
	var n := 0
	for k in NUMERIC:
		if absf(num(k) - float(NUMERIC[k]["base"])) > 0.0001:
			n += 1
	for k in TOGGLES:
		if bool(switches.get(k, false)):
			n += 1
	return n

## Applied at the end of VCProfile.derived(). Does nothing unless the tester is unlocked.
static func apply(d: Dictionary) -> void:
	if not unlocked() or values.is_empty():
		return
	d["max_hp"] = int(d["max_hp"]) + int(num("hp_add"))
	d["dmg_mult"] = float(d["dmg_mult"]) * num("dmg_x")
	d["interval"] = maxf(0.05, float(d["interval"]) / num("aspd_x"))
	d["move_speed"] = float(d["move_speed"]) * num("speed_x")
	d["crit"] = clampf(float(d["crit"]) + num("crit_add") / 100.0, 0.0, 1.0)
	d["armor"] = float(d["armor"]) + num("armor_add")
	d["leech"] = float(d["leech"]) + num("leech_add") / 100.0
	d["cd_mult"] = clampf(float(d["cd_mult"]) - num("cdr_add") / 100.0, 0.05, 1.0)
	d["kill_heal"] = float(d["kill_heal"]) + num("kill_heal_add") / 100.0
	d["coin_mult"] = float(d["coin_mult"]) * num("coin_x")
	d["range"] = float(d["range"]) * num("range_x")

## Damage multiplier applied to every hero hit (one-hit mode).
static func hit_mult() -> float:
	return 99999.0 if on("one_hit") else 1.0
