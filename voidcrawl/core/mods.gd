class_name VCMods
extends RefCounted
## Data-only mod packs. A mod is a .zip containing mod.json (+ optional items/sets/codes/mobs/levels/perks/buttons/menus .json).
## Mods can add weapons, armour, armour sets, promo codes, mobs, dungeon levels, perks, main-menu/pause buttons and
## whole draggable menu windows. They never run code:
## everything is validated, clamped and rebuilt into the game's own data tables, so a broken pack is
## skipped with a readable error instead of crashing the game.

const DIR := "user://mods/"
const STATE := "user://mods/state.json"
const MAX_ZIP := 4 * 1024 * 1024
const MAX_FILE := 512 * 1024
const MAX_ITEMS := 120
const MAX_SETS := 12
const MAX_CODES := 40

const SLOT_IDS := {"weapon": 0, "helm": 1, "armor": 2, "trinket": 3, "boots": 4}
const WEAPON_KINDS := ["sword", "axe", "dagger", "bow", "spear", "hammer", "crossbow", "staff"]
const RANGED_KINDS := ["bow", "crossbow", "staff"]
const STAT_KEYS := ["def", "hp", "speed", "crit", "atk_pct", "cdr", "leech", "coin", "regen"]
const BONUS_LIMITS := {"def": 40, "hp": 150, "speed": 30, "crit": 25, "atk_pct": 40, "cdr": 30, "leech": 10, "coin": 60, "regen": 150, "kill_heal": 10, "nova_pct": 100, "dodge_wave": 300}
const MISSIONS := ["crypt", "forge", "frost", "delve"]
const MAX_MOBS := 24
const MAX_LEVELS := 8
const MAX_PERKS := 24
const MAX_BUTTONS := 6
const MAX_MENUS := 12
const MAX_ELEMENTS := 30
const MOB_MODELS := ["husk", "slinger", "spiderling", "wisp", "brute", "shieldbearer", "embermite", "cultist", "necromancer", "frostwraith", "icearcher", "yeti"]
const MOB_AIS := ["melee", "ranged", "dasher", "slam", "swarm", "exploder"]
const BASE_POOLS := ["crypt", "ember", "frost", "mixed"]
const BOSSES := ["warden", "colossus", "frostmaw"]
const BOSS_TITLES := {"warden": "THE HOLLOW WARDEN", "colossus": "THE ASHEN COLOSSUS", "frostmaw": "THE FROSTMAW"}
const UNLOCKABLE := ["tutorial", "crypt", "forge", "frost", "delve"]
const ACTION_TYPES := ["message", "code", "mission", "perks", "menu", "close"]

static var list: Array = []            # one Dictionary per installed pack (see _info)
static var _base_items: Dictionary = {}
static var _base_sets: Dictionary = {}
static var _base_codes: Dictionary = {}
static var _base_mobs: Dictionary = {}
static var _base_missions: Dictionary = {}
static var _base_order: Array = []
static var _base_perks: Dictionary = {}
static var _disabled: Array = []
static var _menus: Dictionary = {}       # full menu id -> menu definition (see VCModWindow)
static var _buttons: Array = []          # button definitions from enabled mods
static var _mob_spawns: Array = []       # {mob, pool, weight, depth}

# ------------------------------------------------------------------ registry
static func _snapshot() -> void:
	if _base_items.is_empty():
		_base_items = VCItems.BASES.duplicate(true)
		_base_sets = VCSets.DEFS.duplicate(true)
		_base_codes = VCCodes.DEFS.duplicate(true)
		_base_mobs = VCEnemyDefs.DEFS.duplicate(true)
		_base_missions = VCMissions.DATA.duplicate(true)
		_base_order = VCMissions.ORDER.duplicate()
		_base_perks = VCPerks.DEFS.duplicate(true)

static func _load_state() -> void:
	_disabled = []
	if FileAccess.file_exists(STATE):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(STATE))
		if parsed is Dictionary:
			for d in parsed.get("disabled", []):
				_disabled.append(String(d))

static func _save_state() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	var f := FileAccess.open(STATE, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"disabled": _disabled}))

## (Re)build the live item/set/code tables: base game first, then every enabled pack.
static func load_all() -> void:
	_snapshot()
	_load_state()
	VCItems.BASES = _base_items.duplicate(true)
	VCSets.DEFS = _base_sets.duplicate(true)
	VCCodes.DEFS = _base_codes.duplicate(true)
	VCEnemyDefs.DEFS = _base_mobs.duplicate(true)
	VCMissions.DATA = _base_missions.duplicate(true)
	VCMissions.ORDER = _base_order.duplicate()
	VCPerks.DEFS = _base_perks.duplicate(true)
	_menus = {}
	_buttons = []
	_mob_spawns = []
	list = []
	DirAccess.make_dir_recursive_absolute(DIR)
	var files: Array = []
	var da := DirAccess.open(DIR)
	if da != null:
		for fn in da.get_files():
			if fn.to_lower().ends_with(".zip"):
				files.append(fn)
	files.sort()
	for fn in files:
		var parsed := _parse_zip(DIR + String(fn))
		var info := _info(parsed, DIR + String(fn))
		var id := String(info["id"])
		info["enabled"] = bool(parsed["ok"]) and not _disabled.has(id)
		if bool(info["enabled"]):
			_apply(parsed)
		list.append(info)

static func _info(parsed: Dictionary, path: String) -> Dictionary:
	var mf: Dictionary = parsed.get("manifest", {})
	return {
		"id": String(mf.get("id", path.get_file().get_basename())),
		"name": String(mf.get("name", path.get_file().get_basename())),
		"version": String(mf.get("version", "?")),
		"author": String(mf.get("author", "")),
		"description": String(mf.get("description", "")),
		"items": (parsed.get("items", {}) as Dictionary).size(),
		"sets": (parsed.get("sets", {}) as Dictionary).size(),
		"codes": (parsed.get("codes", {}) as Dictionary).size(),
		"mobs": (parsed.get("mobs", {}) as Dictionary).size(),
		"levels": (parsed.get("levels", {}) as Dictionary).size(),
		"perks": (parsed.get("perks", {}) as Dictionary).size(),
		"buttons": (parsed.get("buttons", {}) as Dictionary).size(),
		"menus": (parsed.get("menus", {}) as Dictionary).size(),
		"errors": parsed.get("errors", []),
		"ok": bool(parsed["ok"]),
		"enabled": false,
		"path": path,
	}

static func _apply(parsed: Dictionary) -> void:
	for id in parsed["items"]:
		VCItems.BASES[id] = parsed["items"][id]
	for id in parsed["sets"]:
		VCSets.DEFS[id] = parsed["sets"][id]
	for code in parsed["codes"]:
		if not _base_codes.has(code):
			VCCodes.DEFS[code] = parsed["codes"][code]
	for id in parsed["mobs"]:
		VCEnemyDefs.DEFS[id] = parsed["mobs"][id]
	for sp in parsed["spawns"]:
		_mob_spawns.append(sp)
	for id in parsed["levels"]:
		VCMissions.DATA[id] = parsed["levels"][id]
		if not VCMissions.ORDER.has(id):
			VCMissions.ORDER.append(id)
	for id in parsed["perks"]:
		VCPerks.DEFS[id] = parsed["perks"][id]
	for id in parsed["menus"]:
		_menus[id] = parsed["menus"][id]
	for id in parsed["buttons"]:
		if _buttons.size() < 2 * MAX_BUTTONS:
			_buttons.append(parsed["buttons"][id])

# ------------------------------------------------------------------- lookups used by the game
static func menu_def(key: String) -> Dictionary:
	return _menus.get(key, {})

## Buttons that show on a screen: "main" (main menu) or "pause" (pause menu). Capped so the screen stays tidy.
static func menu_buttons(where: String = "main") -> Array:
	var out: Array = []
	for b in _buttons:
		if String(b["where"]) == where or String(b["where"]) == "both":
			out.append(b)
	return out.slice(0, MAX_BUTTONS)

## Extra [mob_id, weight] entries for a dungeon's enemy pool (from mob "spawn" rules and a level's own "mobs").
static func pool_additions(kind: String, depth: int, mission_id: String = "") -> Array:
	var out: Array = []
	for sp in _mob_spawns:
		if String(sp["pool"]) == kind and depth >= int(sp["depth"]) and VCEnemyDefs.DEFS.has(String(sp["mob"])):
			out.append([String(sp["mob"]), float(sp["weight"])])
	var m: Dictionary = VCMissions.DATA.get(mission_id, {})
	for mid in m.get("mod_mobs", []):
		if VCEnemyDefs.DEFS.has(String(mid)):
			out.append([String(mid), 2.5])
	return out

# ------------------------------------------------------------------- install
static func install_bytes(bytes: PackedByteArray) -> Dictionary:
	if bytes.is_empty():
		return {"ok": false, "msg": "That file is empty or could not be read."}
	if bytes.size() > MAX_ZIP:
		return {"ok": false, "msg": "Mod is too large (max 4 MB)."}
	DirAccess.make_dir_recursive_absolute(DIR)
	var tmp := DIR + "_incoming.tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return {"ok": false, "msg": "Could not write to the mods folder."}
	f.store_buffer(bytes)
	f.close()
	var parsed := _parse_zip(tmp)
	if not bool(parsed["ok"]):
		DirAccess.remove_absolute(tmp)
		var errs: Array = parsed["errors"]
		return {"ok": false, "msg": "Not a valid mod: %s" % (String(errs[0]) if not errs.is_empty() else "unknown problem")}
	var id := String(parsed["manifest"]["id"])
	var dest := DIR + id + ".zip"
	if FileAccess.file_exists(dest):
		DirAccess.remove_absolute(dest)
	DirAccess.rename_absolute(tmp, dest)
	_load_state()
	_disabled.erase(id)
	_save_state()
	load_all()
	var r := _reconcile()
	var name := String(parsed["manifest"]["name"])
	var warn := ""
	if not (parsed["errors"] as Array).is_empty():
		warn = "  (%d entries skipped)" % (parsed["errors"] as Array).size()
	var bits: Array = []
	for k in ["items", "sets", "codes", "mobs", "levels", "perks", "buttons", "menus"]:
		var c := (parsed[k] as Dictionary).size()
		if c > 0:
			bits.append("%d %s" % [c, k])
	return {"ok": true, "id": id, "msg": "Installed %s: %s%s%s" % [name, ", ".join(bits), warn, _reconcile_text(r)]}

static func set_enabled(id: String, on: bool) -> Dictionary:
	_load_state()
	_disabled.erase(id)
	if not on:
		_disabled.append(id)
	_save_state()
	load_all()
	return _reconcile()

static func remove(id: String) -> Dictionary:
	for m in list:
		if String(m["id"]) == id:
			DirAccess.remove_absolute(String(m["path"]))
	_load_state()
	_disabled.erase(id)
	_save_state()
	load_all()
	return _reconcile()

static func _reconcile() -> Dictionary:
	if VC != null and VC.profile != null:
		var r: Dictionary = VC.profile.reconcile_mod_items()
		VC.notify_profile_changed()
		VC.save_now()
		return r
	return {"parked": 0, "restored": 0}

static func _reconcile_text(r: Dictionary) -> String:
	var t := ""
	if int(r.get("restored", 0)) > 0:
		t += "  %d item(s) returned to your backpack." % int(r["restored"])
	if int(r.get("parked", 0)) > 0:
		t += "  %d item(s) put away until the mod is back." % int(r["parked"])
	return t

static func reconcile_text(r: Dictionary) -> String:
	return _reconcile_text(r)

# ------------------------------------------------------------------- parsing
static func _read_json(zr: ZIPReader, files: PackedStringArray, prefix: String, name: String) -> Variant:
	var path := prefix + name
	if not files.has(path):
		return null
	var b := zr.read_file(path)
	if b.size() > MAX_FILE:
		return "too_big"
	var parsed = JSON.parse_string(b.get_string_from_utf8())
	if parsed == null:
		return "bad_json"
	return parsed

static func _parse_zip(path: String) -> Dictionary:
	var out := {"ok": false, "manifest": {}, "items": {}, "sets": {}, "codes": {}, "mobs": {}, "spawns": [], "levels": {}, "perks": {}, "buttons": {}, "menus": {}, "errors": []}
	var errs: Array = out["errors"]
	var zr := ZIPReader.new()
	if zr.open(path) != OK:
		errs.append("not a readable .zip file")
		return out
	var files := zr.get_files()
	var prefix := ""
	var found := false
	for f in files:
		var fs := String(f)
		if fs == "mod.json" or (fs.ends_with("/mod.json") and fs.count("/") == 1 and not fs.begins_with("__MACOSX")):
			prefix = fs.trim_suffix("mod.json")
			found = true
			break
	if not found:
		zr.close()
		errs.append("mod.json is missing")
		return out
	var mj = _read_json(zr, files, prefix, "mod.json")
	if not (mj is Dictionary):
		zr.close()
		errs.append("mod.json is unreadable")
		return out
	var mf: Dictionary = {}
	var mid := _clean_id(String(mj.get("id", "")))
	if mid == "":
		zr.close()
		errs.append("mod.json needs an \"id\" (a-z, 0-9, _ ; 2-20 chars)")
		return out
	mf["id"] = mid
	mf["name"] = _clean_text(String(mj.get("name", mid)), 32)
	mf["version"] = _clean_text(String(mj.get("version", "1.0")), 12)
	mf["author"] = _clean_text(String(mj.get("author", "")), 32)
	mf["description"] = _clean_text(String(mj.get("description", "")), 160)
	out["manifest"] = mf
	var raw := {}
	var kinds := ["items", "sets", "codes", "mobs", "levels", "perks", "buttons", "menus"]
	for key in kinds:
		var dst := {}
		if mj.get(key) is Dictionary:
			dst.merge(mj[key])
		var extra = _read_json(zr, files, prefix, key + ".json")
		if extra is String:
			errs.append("%s.json: %s" % [key, "file too large" if extra == "too_big" else "invalid JSON"])
		elif extra is Dictionary:
			dst.merge(extra.get(key, extra) if extra.get(key) is Dictionary else extra)
		raw[key] = dst
	zr.close()
	# items
	var items: Dictionary = out["items"]
	var raw_items: Dictionary = raw["items"]
	if raw_items.size() > MAX_ITEMS:
		errs.append("too many items (max %d)" % MAX_ITEMS)
	var n := 0
	for k in raw_items:
		n += 1
		if n > MAX_ITEMS:
			break
		var r := _build_item(String(k), raw_items[k])
		if r.has("error"):
			errs.append("item %s: %s" % [String(k), String(r["error"])])
		else:
			items["%s__%s" % [mid, _clean_id(String(k))]] = r["item"]
	# mobs
	var mobs: Dictionary = out["mobs"]
	n = 0
	for k in raw["mobs"]:
		n += 1
		if n > MAX_MOBS:
			errs.append("too many mobs (max %d)" % MAX_MOBS)
			break
		var rm := _build_mob(mid, String(k), raw["mobs"][k])
		if rm.has("error"):
			errs.append("mob %s: %s" % [String(k), String(rm["error"])])
		else:
			var fid := "%s__%s" % [mid, _clean_id(String(k))]
			mobs[fid] = rm["mob"]
			for sp in rm["spawns"]:
				out["spawns"].append(sp)
	# levels (dungeons)
	var levels: Dictionary = out["levels"]
	n = 0
	for k in raw["levels"]:
		n += 1
		if n > MAX_LEVELS:
			errs.append("too many levels (max %d)" % MAX_LEVELS)
			break
		var rl := _build_level(mid, String(k), raw["levels"][k], mobs, raw["levels"])
		if rl.has("error"):
			errs.append("level %s: %s" % [String(k), String(rl["error"])])
		else:
			levels["%s__%s" % [mid, _clean_id(String(k))]] = rl["level"]
	# perks
	var perks: Dictionary = out["perks"]
	n = 0
	for k in raw["perks"]:
		n += 1
		if n > MAX_PERKS:
			errs.append("too many perks (max %d)" % MAX_PERKS)
			break
		var rp := _build_perk(String(k), raw["perks"][k])
		if rp.has("error"):
			errs.append("perk %s: %s" % [String(k), String(rp["error"])])
		else:
			perks["%s__%s" % [mid, _clean_id(String(k))]] = rp["perk"]
	# sets (need the items for slot checks and levels for the drop dungeon)
	var sets: Dictionary = out["sets"]
	n = 0
	for k in raw["sets"]:
		n += 1
		if n > MAX_SETS:
			errs.append("too many sets (max %d)" % MAX_SETS)
			break
		var rs := _build_set(mid, String(k), raw["sets"][k], items, levels)
		if rs.has("error"):
			errs.append("set %s: %s" % [String(k), String(rs["error"])])
		else:
			sets["%s__%s" % [mid, _clean_id(String(k))]] = rs["set"]
	# codes
	var codes: Dictionary = out["codes"]
	n = 0
	for k in raw["codes"]:
		n += 1
		if n > MAX_CODES:
			errs.append("too many codes (max %d)" % MAX_CODES)
			break
		var code := VCCodes.normalise(String(k))
		if code == "" or code.length() > 24:
			errs.append("code %s: invalid name" % String(k))
			continue
		var rc := _build_code(mid, raw["codes"][k], items)
		if rc.has("error"):
			errs.append("code %s: %s" % [String(k), String(rc["error"])])
		else:
			codes[code] = rc["code"]
	# menus, then buttons (they point at menus / levels of this same pack)
	var menus: Dictionary = out["menus"]
	n = 0
	for k in raw["menus"]:
		n += 1
		if n > MAX_MENUS:
			errs.append("too many menus (max %d)" % MAX_MENUS)
			break
		var rmn := _build_menu(mid, String(k), raw["menus"][k], raw["menus"], raw["levels"])
		if rmn.has("error"):
			errs.append("menu %s: %s" % [String(k), String(rmn["error"])])
		else:
			menus["%s__%s" % [mid, _clean_id(String(k))]] = rmn["menu"]
	var buttons: Dictionary = out["buttons"]
	n = 0
	for k in raw["buttons"]:
		n += 1
		if n > MAX_BUTTONS:
			errs.append("too many buttons (max %d)" % MAX_BUTTONS)
			break
		var rb := _build_button(mid, String(k), raw["buttons"][k], raw["menus"], raw["levels"])
		if rb.has("error"):
			errs.append("button %s: %s" % [String(k), String(rb["error"])])
		else:
			buttons["%s__%s" % [mid, _clean_id(String(k))]] = rb["button"]
	var total := items.size() + sets.size() + codes.size() + mobs.size() + levels.size() + perks.size() + menus.size() + buttons.size()
	if total == 0:
		errs.append("the pack adds nothing (no valid items, sets, codes, mobs, levels, perks, buttons or menus)")
		return out
	out["ok"] = true
	return out

static func _clean_id(s: String) -> String:
	var o := ""
	for ch in s.to_lower():
		if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") or ch == "_":
			o += ch
	return o.substr(0, 20)

static func _clean_text(s: String, max_len: int) -> String:
	var o := ""
	for ch in s:
		if ch.unicode_at(0) >= 32 and ch != "[" and ch != "]":
			o += ch
	return o.strip_edges().substr(0, max_len)

static func _num(v: Variant, lo: float, hi: float, dflt: float) -> float:
	if v is float or v is int:
		return clampf(float(v), lo, hi)
	return dflt

static func _color(v: Variant, dflt: Color) -> Color:
	if v is String and Color.html_is_valid(String(v)):
		return Color.html(String(v))
	if v is Array and (v as Array).size() >= 3:
		var a: Array = v
		var mx := 1.0
		for c in a:
			if c is float or c is int:
				mx = maxf(mx, float(c))
		var div := 255.0 if mx > 1.0 else 1.0
		return Color(clampf(float(a[0]) / div, 0, 1), clampf(float(a[1]) / div, 0, 1), clampf(float(a[2]) / div, 0, 1))
	return dflt

static func _build_item(id: String, spec: Variant) -> Dictionary:
	if not (spec is Dictionary):
		return {"error": "must be an object"}
	if _clean_id(id) == "":
		return {"error": "bad id"}
	var s: Dictionary = spec
	var nm := _clean_text(String(s.get("name", "")), 32)
	if nm == "":
		return {"error": "needs a name"}
	var slot_name := String(s.get("slot", "")).to_lower()
	if not SLOT_IDS.has(slot_name):
		return {"error": "slot must be weapon, helm, armor, trinket or boots"}
	var slot: int = SLOT_IDS[slot_name]
	var b := {"name": nm, "slot": slot, "color": _color(s.get("color"), Color(0.8, 0.8, 0.9))}
	if slot == 0:
		var kind := String(s.get("kind", "sword")).to_lower()
		if not WEAPON_KINDS.has(kind):
			return {"error": "weapon kind must be one of " + ", ".join(WEAPON_KINDS)}
		var d = s.get("dmg", [8, 12])
		if not (d is Array) or (d as Array).size() < 2:
			return {"error": "weapon needs dmg: [min, max]"}
		var lo := int(_num(d[0], 1, 200, 8))
		var hi := maxi(lo, int(_num(d[1], 1, 300, 12)))
		var ranged := RANGED_KINDS.has(kind)
		b["kind"] = kind
		b["dmg"] = [lo, hi]
		b["interval"] = _num(s.get("interval"), 0.15, 2.5, 0.5)
		b["range"] = _num(s.get("range"), 1.5, 20.0, 16.0 if ranged else 2.8)
		b["arc"] = 0.0 if ranged else _num(s.get("arc"), 20.0, 200.0, 110.0)
		b["ranged"] = ranged
	else:
		b["kind"] = String(["", "helm", "armor", "trinket", "boots"][slot])
	for k in STAT_KEYS:
		if s.has(k):
			b[k] = int(_num(s[k], -20 if k == "speed" else 0, 60 if k != "hp" else 200, 0))
	if not bool(s.get("drops", true)):
		b["unique"] = true
	return {"item": b}

static func _build_set(mid: String, id: String, spec: Variant, items: Dictionary, levels: Dictionary = {}) -> Dictionary:
	if not (spec is Dictionary):
		return {"error": "must be an object"}
	var s: Dictionary = spec
	var nm := _clean_text(String(s.get("name", "")), 32)
	if nm == "":
		return {"error": "needs a name"}
	var pcs = s.get("pieces")
	if not (pcs is Dictionary):
		return {"error": "needs pieces {helm, armor, boots, trinket}"}
	var full := "%s__%s" % [mid, _clean_id(id)]
	var pieces := {}
	for key in ["helm", "armor", "boots", "trinket"]:
		var lid := _clean_id(String(pcs.get(key, "")))
		var fid := "%s__%s" % [mid, lid]
		if lid == "" or not items.has(fid):
			return {"error": "piece \"%s\" is missing or invalid" % key}
		if int(items[fid]["slot"]) != int(SLOT_IDS[key]):
			return {"error": "piece \"%s\" has the wrong slot" % key}
		pieces[key] = fid
	var mission := String(s.get("mission", ""))
	var own_level := "%s__%s" % [mid, _clean_id(mission)]
	if mission != "" and levels.has(own_level):
		mission = own_level
	elif mission != "" and not MISSIONS.has(mission):
		return {"error": "mission must be empty, one of %s, or a level from this pack" % ", ".join(MISSIONS)}
	var b2 := _bonus(s.get("b2"))
	var b4 := _bonus(s.get("b4"))
	if b2.is_empty() or b4.is_empty():
		return {"error": "needs b2 and b4 bonuses (e.g. {\"def\": 10})"}
	for key in pieces:
		items[pieces[key]]["set"] = full
		items[pieces[key]]["unique"] = true
	var glow := _color(s.get("glow"), Color(1, 0.8, 0.4))
	return {"set": {
		"name": nm, "mission": mission,
		"color": _color(s.get("color"), glow.darkened(0.4)), "glow": glow,
		"pieces": pieces, "b2": b2, "b4": b4,
		"t2": _bonus_text(b2), "t4": _bonus_text(b4),
		"flavor": _clean_text(String(s.get("flavor", "")), 80), "mod": mid,
	}}

static func _bonus(v: Variant) -> Dictionary:
	var out := {}
	if v is Dictionary:
		for k in v:
			var key := String(k)
			if BONUS_LIMITS.has(key) and (v[k] is float or v[k] is int):
				var val := clampf(float(v[k]), 0.0, float(BONUS_LIMITS[key]))
				if val > 0.0:
					out[key] = val
	return out

static func _bonus_text(b: Dictionary) -> String:
	var parts: Array = []
	for k in b:
		parts.append(VCSets.stat_text(String(k), float(b[k])))
	return ", ".join(parts)

static func _build_code(mid: String, spec: Variant, items: Dictionary) -> Dictionary:
	if not (spec is Dictionary):
		return {"error": "must be an object"}
	var s: Dictionary = spec
	var c := {"msg": _clean_text(String(s.get("msg", "Code redeemed!")), 80)}
	c["coins"] = int(_num(s.get("coins"), 0, 5000, 0))
	c["xp"] = int(_num(s.get("xp"), 0, 5000, 0))
	c["points"] = int(_num(s.get("points"), 0, 5, 0))
	c["potions"] = int(_num(s.get("potions"), 0, 10, 0))
	c["bombs"] = int(_num(s.get("bombs"), 0, 10, 0))
	var specs: Array = []
	for it in s.get("items", []):
		if it is Dictionary:
			var fid := "%s__%s" % [mid, _clean_id(String(it.get("base", "")))]
			if items.has(fid) and specs.size() < 8:
				specs.append({"base": fid, "rarity": int(_num(it.get("rarity"), 0, 4, 2)), "ilvl": int(_num(it.get("ilvl"), 1, 30, 4))})
			else:
				return {"error": "item \"%s\" is not defined in this pack" % String(it.get("base", ""))}
	if not specs.is_empty():
		c["items"] = specs
	return {"code": c}

# ------------------------------------------------------------------- mobs, levels, perks, buttons, menus
static func _has_local(raw: Dictionary, local: String) -> bool:
	var want := _clean_id(local)
	if want == "":
		return false
	for k in raw:
		if _clean_id(String(k)) == want:
			return true
	return false

static func _text_ml(s: String, max_len: int) -> String:
	var o := ""
	for ch in s:
		if ch == "\n" or (ch.unicode_at(0) >= 32 and ch != "[" and ch != "]"):
			o += ch
	return o.strip_edges().substr(0, max_len)

static func _build_mob(mid: String, id: String, spec: Variant) -> Dictionary:
	if not (spec is Dictionary):
		return {"error": "must be an object"}
	if _clean_id(id) == "":
		return {"error": "bad id"}
	var s: Dictionary = spec
	var nm := _clean_text(String(s.get("name", "")), 28)
	if nm == "":
		return {"error": "needs a name"}
	var model := String(s.get("model", "husk")).to_lower()
	if not MOB_MODELS.has(model):
		return {"error": "model must be one of " + ", ".join(MOB_MODELS)}
	var base: Dictionary = _base_mobs.get(model, {})
	if base.is_empty():
		return {"error": "model %s is unavailable" % model}
	var d: Dictionary = base.duplicate(true)
	d["name"] = nm
	d["model"] = model
	var ai := String(s.get("ai", base["ai"])).to_lower()
	if not MOB_AIS.has(ai):
		return {"error": "ai must be one of " + ", ".join(MOB_AIS)}
	d["ai"] = ai
	var defaults := {"reach": 2.0, "cooldown": 1.8, "windup": 0.6, "arc": 100.0, "pref_dist": 7.5, "proj_speed": 9.5, "dash_speed": 12.0, "dash_time": 0.55, "slam_radius": 3.0, "blast": 3.0}
	for k in defaults:
		if not d.has(k):
			d[k] = defaults[k]
	if ai == "ranged" and float(d["reach"]) < 6.0:
		d["reach"] = 12.0
	if ai == "dasher" and float(d["reach"]) < 6.0:
		d["reach"] = 10.0
	var base_scale := float(base.get("scale", 1.0))
	var sc := _num(s.get("scale"), 0.6, 2.4, base_scale)
	d["scale"] = sc
	d["radius"] = clampf(float(base["radius"]) * sc / maxf(base_scale, 0.1), 0.3, 1.4)
	d["hp"] = _num(s.get("hp"), 10.0, 900.0, float(base["hp"]))
	d["dmg"] = _num(s.get("dmg"), 0.0 if model == "necromancer" else 1.0, 80.0, float(base["dmg"]))
	d["speed"] = _num(s.get("speed"), 1.2, 7.0, float(base["speed"]))
	d["xp"] = int(_num(s.get("xp"), 1.0, 400.0, float(base["xp"])))
	if s.get("coins") is Array and (s["coins"] as Array).size() >= 2:
		var c0 := int(_num(s["coins"][0], 0, 100, 1))
		d["coins"] = [c0, maxi(c0, int(_num(s["coins"][1], 0, 120, 3)))]
	d["item_chance"] = _num(s.get("item_chance"), 0.0, 0.8, float(base["item_chance"]))
	d["potion_chance"] = _num(s.get("potion_chance"), 0.0, 0.5, float(base["potion_chance"]))
	d["windup"] = _num(s.get("windup"), 0.25, 1.5, float(d["windup"]))
	d["reach"] = _num(s.get("reach"), 1.0, 16.0, float(d["reach"]))
	d["cooldown"] = _num(s.get("cooldown"), 0.5, 6.0, float(d["cooldown"]))
	if s.has("tint"):
		d["tint"] = _color(s["tint"], Color(0.6, 0.6, 0.6))
	for ck in ["glow", "robe", "body"]:
		if s.has(ck):
			d[ck] = _color(s[ck], d.get(ck, Color(0.75, 0.35, 1.0)))
	d["mod"] = mid
	var spawns: Array = []
	var sp = s.get("spawn", [])
	if sp is String:
		sp = [{"pool": sp}]
	if sp is Array:
		var fid := "%s__%s" % [mid, _clean_id(id)]
		for e in sp:
			if e is Dictionary and BASE_POOLS.has(String(e.get("pool", ""))) and spawns.size() < 8:
				spawns.append({"mob": fid, "pool": String(e["pool"]), "weight": _num(e.get("weight"), 0.2, 8.0, 2.0), "depth": int(_num(e.get("depth"), 0, 3, 0))})
	return {"mob": d, "spawns": spawns}

static func _build_level(mid: String, id: String, spec: Variant, mobs: Dictionary, raw_levels: Dictionary) -> Dictionary:
	if not (spec is Dictionary):
		return {"error": "must be an object"}
	if _clean_id(id) == "":
		return {"error": "bad id"}
	var s: Dictionary = spec
	var nm := _clean_text(String(s.get("name", "")), 36)
	if nm == "":
		return {"error": "needs a name"}
	var pal := String(s.get("palette", "")).to_lower()
	if not ["", "crypt", "ember", "frost"].has(pal):
		return {"error": "palette must be crypt, ember or frost"}
	var pool := String(s.get("pool", "ember" if pal == "ember" else ("frost" if pal == "frost" else "crypt"))).to_lower()
	if not BASE_POOLS.has(pool) and pool != "none":
		return {"error": "pool must be one of %s, or none (only your own mobs)" % ", ".join(BASE_POOLS)}
	var boss := String(s.get("boss", "warden")).to_lower()
	if not BOSSES.has(boss):
		return {"error": "boss must be one of " + ", ".join(BOSSES)}
	var cols := int(_num(s.get("cols"), 3, 5, 4))
	var rows := int(_num(s.get("rows"), 3, 5, 4))
	var path_len := int(_num(s.get("path_len"), 4, 12, 8))
	path_len = clampi(path_len, 4, maxi(4, int(float(cols * rows) * 0.6)))
	var unlock := String(s.get("unlock", "tutorial"))
	var own := "%s__%s" % [mid, _clean_id(unlock)]
	if _has_local(raw_levels, unlock) and _clean_id(unlock) != _clean_id(id):
		unlock = own
	elif not UNLOCKABLE.has(unlock):
		return {"error": "unlock must be one of %s or another level of this pack" % ", ".join(UNLOCKABLE)}
	var title := _clean_text(String(s.get("boss_title", BOSS_TITLES[boss])), 36).to_upper()
	var mod_mobs: Array = []
	for m in s.get("mobs", []):
		var fid := "%s__%s" % [mid, _clean_id(String(m))]
		if mobs.has(fid) and mod_mobs.size() < 12:
			mod_mobs.append(fid)
		else:
			return {"error": "mob \"%s\" is not defined in this pack" % String(m)}
	if pool == "none" and mod_mobs.is_empty():
		return {"error": "pool \"none\" needs at least one mob in \"mobs\""}
	var lvl := {
		"name": nm, "biome": _clean_text(String(s.get("biome", "Unknown Depths")), 28),
		"blurb": _clean_text(String(s.get("blurb", "A new dungeon from a mod.")), 160),
		"layout": "procedural", "pool": pool, "cols": cols, "rows": rows, "path_len": path_len, "fixed_seed": 0,
		"recommended_level": int(_num(s.get("recommended_level"), 1, 30, 3)),
		"xp": int(_num(s.get("xp"), 50, 8000, 800)), "coins": int(_num(s.get("coins"), 20, 3000, 250)),
		"unlock": unlock, "boss": boss, "boss_title": title,
		"boss_sub": _clean_text(String(s.get("boss_sub", "Guardian of the Void Gate")), 40),
		"mod": mid, "mod_mobs": mod_mobs,
		"objectives": [
			{"id": "find", "text": "Find the guardian's lair", "type": "enter_boss"},
			{"id": "boss", "text": "Defeat %s" % title.capitalize(), "type": "boss"},
			{"id": "exit", "text": "Step through the Void Gate", "type": "exit"},
		],
	}
	if pal == "ember" or pal == "frost":
		lvl["palette"] = pal
	return {"level": lvl}

static func _build_perk(id: String, spec: Variant) -> Dictionary:
	if not (spec is Dictionary):
		return {"error": "must be an object"}
	if _clean_id(id) == "":
		return {"error": "bad id"}
	var s: Dictionary = spec
	var nm := _clean_text(String(s.get("name", "")), 28)
	if nm == "":
		return {"error": "needs a name"}
	var b := _bonus(s.get("bonus"))
	if b.is_empty():
		return {"error": "needs a bonus (e.g. {\"def\": 6})"}
	return {"perk": {"name": nm, "desc": _clean_text(String(s.get("desc", "")), 70), "cost": int(_num(s.get("cost"), 10, 5000, 200)),
		"bonus": b, "color": _color(s.get("color"), Color(0.7, 0.5, 1.0))}}

static func _build_action(a: Variant, raw_menus: Dictionary, raw_levels: Dictionary, mid: String) -> Dictionary:
	if not (a is Dictionary):
		return {"error": "action must be an object like {\"type\": \"message\", \"text\": \"...\"}"}
	var t := String(a.get("type", "")).to_lower()
	if not ACTION_TYPES.has(t):
		return {"error": "action type must be one of " + ", ".join(ACTION_TYPES)}
	var out := {"type": t}
	match t:
		"message":
			out["text"] = _text_ml(String(a.get("text", "")), 400)
			out["title"] = _clean_text(String(a.get("title", "")), 28)
			if out["text"] == "":
				return {"error": "message action needs text"}
		"code":
			var code := VCCodes.normalise(String(a.get("code", "")))
			if code == "":
				return {"error": "code action needs a code"}
			out["code"] = code
		"mission":
			var m := String(a.get("mission", ""))
			if _has_local(raw_levels, m):
				out["mission"] = "%s__%s" % [mid, _clean_id(m)]
			elif UNLOCKABLE.has(m) and m != "tutorial":
				out["mission"] = m
			else:
				return {"error": "mission \"%s\" is not a level of this pack or a base dungeon" % m}
		"menu":
			var mn := String(a.get("menu", ""))
			if not _has_local(raw_menus, mn):
				return {"error": "menu \"%s\" is not defined in this pack" % mn}
			out["menu"] = "%s__%s" % [mid, _clean_id(mn)]
	return {"action": out}

static func _build_button(mid: String, id: String, spec: Variant, raw_menus: Dictionary, raw_levels: Dictionary) -> Dictionary:
	if not (spec is Dictionary):
		return {"error": "must be an object"}
	var s: Dictionary = spec
	var label := _clean_text(String(s.get("label", "")), 18)
	if label == "":
		return {"error": "needs a label"}
	var where := String(s.get("where", "main")).to_lower()
	if not ["main", "pause", "both"].has(where):
		return {"error": "where must be main, pause or both"}
	var ra := _build_action(s.get("action"), raw_menus, raw_levels, mid)
	if ra.has("error"):
		return ra
	return {"button": {"label": label, "where": where, "color": _color(s.get("color"), Color(0.7, 0.5, 1.0)), "action": ra["action"], "mod": mid}}

static func _build_menu(mid: String, id: String, spec: Variant, raw_menus: Dictionary, raw_levels: Dictionary) -> Dictionary:
	if not (spec is Dictionary):
		return {"error": "must be an object"}
	var s: Dictionary = spec
	var title := _clean_text(String(s.get("title", "")), 28)
	if title == "":
		return {"error": "needs a title"}
	var els: Array = []
	var raw_els = s.get("elements", [])
	if not (raw_els is Array) or (raw_els as Array).is_empty():
		return {"error": "needs elements: [ {\"type\": \"text\", ...}, {\"type\": \"button\", ...} ]"}
	for e in raw_els:
		if els.size() >= MAX_ELEMENTS:
			break
		if not (e is Dictionary):
			continue
		var t := String(e.get("type", "")).to_lower()
		match t:
			"text":
				var txt := _text_ml(String(e.get("text", "")), 300)
				if txt != "":
					els.append({"type": "text", "text": txt, "size": int(_num(e.get("size"), 14, 30, 19)), "color": _color(e.get("color"), VCDefs.COL_TEXT), "center": bool(e.get("center", false))})
			"divider":
				els.append({"type": "divider"})
			"button":
				var lab := _clean_text(String(e.get("label", "")), 28)
				var ra := _build_action(e.get("action"), raw_menus, raw_levels, mid)
				if lab == "":
					return {"error": "a button needs a label"}
				if ra.has("error"):
					return {"error": "button \"%s\": %s" % [lab, String(ra["error"])]}
				els.append({"type": "button", "label": lab, "color": _color(e.get("color"), _color(s.get("color"), Color(0.7, 0.5, 1.0))), "action": ra["action"]})
	if els.is_empty():
		return {"error": "no valid elements"}
	return {"menu": {
		"key": "%s__%s" % [mid, _clean_id(id)], "title": title, "color": _color(s.get("color"), Color(0.7, 0.5, 1.0)),
		"width": int(_num(s.get("width"), 240, 600, 340)), "draggable": bool(s.get("draggable", true)),
		"x": _num(s.get("x"), 0.0, 1.0, 0.5), "y": _num(s.get("y"), 0.0, 1.0, 0.5), "elements": els, "mod": mid}}

# ------------------------------------------------------------------- example
const EXAMPLE_MOD := {
	"id": "sunfire", "name": "Sunfire Pack", "version": "1.0", "author": "Infinity Studios",
	"description": "Example mod: a blazing sword, the Sunborn armour set, new mobs, the Sunken Furnace dungeon, two perks, codes and a draggable Sunfire Hub menu.",
}
const EXAMPLE_ITEMS := {
	"sunfire_blade": {"name": "Sunfire Blade", "slot": "weapon", "kind": "sword", "dmg": [12, 16], "interval": 0.4, "range": 2.8, "arc": 120, "color": "#ffaa33", "drops": true},
	"solar_boots": {"name": "Solar Boots", "slot": "boots", "speed": 11, "def": 2, "color": "#ffd24a", "drops": true},
	"sun_helm": {"name": "Sunborn Helm", "slot": "helm", "def": 8, "hp": 14, "color": "#e8a838"},
	"sun_plate": {"name": "Sunborn Plate", "slot": "armor", "def": 14, "hp": 30, "color": "#d98f2b"},
	"sun_greaves": {"name": "Sunborn Greaves", "slot": "boots", "def": 5, "speed": 6, "color": "#f0b84a"},
	"sun_charm": {"name": "Sunborn Charm", "slot": "trinket", "hp": 20, "atk_pct": 4, "color": "#ffe08a"},
}
const EXAMPLE_SETS := {
	"sunborn": {"name": "Sunborn Regalia", "mission": "sunken_furnace", "color": "#c98a2a", "glow": "#ffcc55",
		"pieces": {"helm": "sun_helm", "armor": "sun_plate", "boots": "sun_greaves", "trinket": "sun_charm"},
		"b2": {"def": 10, "hp": 20}, "b4": {"atk_pct": 14, "kill_heal": 2, "speed": 6},
		"flavor": "Warm as a summer noon."},
}
const EXAMPLE_CODES := {
	"SUNFIRE": {"msg": "The sun answers.", "coins": 200, "items": [{"base": "sunfire_blade", "rarity": 3, "ilvl": 5}]},
	"SUNBORN": {"msg": "Sunborn armour granted.", "items": [
		{"base": "sun_helm", "rarity": 3, "ilvl": 6}, {"base": "sun_plate", "rarity": 3, "ilvl": 6},
		{"base": "sun_greaves", "rarity": 3, "ilvl": 6}, {"base": "sun_charm", "rarity": 3, "ilvl": 6}]},
}

const EXAMPLE_MOBS := {
	"sun_wisp": {"name": "Sun Wisp", "model": "wisp", "tint": "#ff9a2a", "glow": "#ffd24a", "hp": 36, "dmg": 12, "speed": 3.8, "xp": 20, "coins": [3, 7],
		"spawn": [{"pool": "ember", "weight": 2.0, "depth": 1}, {"pool": "mixed", "weight": 1.0, "depth": 2}]},
	"ember_knight": {"name": "Ember Knight", "model": "shieldbearer", "tint": "#c85a1a", "glow": "#ffb347", "hp": 170, "dmg": 20, "speed": 2.6, "scale": 1.3, "xp": 40, "coins": [6, 14], "item_chance": 0.4},
}
const EXAMPLE_LEVELS := {
	"sunken_furnace": {"name": "The Sunken Furnace", "biome": "Sunfire Depths", "blurb": "A drowned forge where sun-touched knights guard a molten heart. Sunborn armour drops here.",
		"palette": "ember", "pool": "ember", "cols": 4, "rows": 4, "path_len": 8, "recommended_level": 6, "xp": 1800, "coins": 600,
		"unlock": "forge", "boss": "colossus", "boss_title": "THE SUN-FORGED", "boss_sub": "Heart of the Sunken Furnace", "mobs": ["sun_wisp", "ember_knight"]},
}
const EXAMPLE_PERKS := {
	"sunlit": {"name": "Sunlit Edge", "desc": "Blades gleam with borrowed daylight.", "cost": 260, "bonus": {"atk_pct": 8}, "color": "#ffcc55"},
	"warm_heart": {"name": "Warm Heart", "desc": "A little sunshine for the road.", "cost": 180, "bonus": {"hp": 50, "regen": 20}, "color": "#ff8a5a"},
}
const EXAMPLE_MENUS := {
	"hub": {"title": "Sunfire Hub", "color": "#ffaa33", "width": 360, "x": 0.5, "y": 0.4, "elements": [
		{"type": "text", "text": "Welcome, wanderer! Level {level}  -  {coins} coins  -  perks {perks}", "size": 19},
		{"type": "divider"},
		{"type": "button", "label": "Enter the Sunken Furnace", "action": {"type": "mission", "mission": "sunken_furnace"}},
		{"type": "button", "label": "Claim SUNFIRE gift", "action": {"type": "code", "code": "SUNFIRE"}},
		{"type": "button", "label": "Open Perks", "action": {"type": "perks"}},
		{"type": "button", "label": "Read the lore", "action": {"type": "menu", "menu": "lore"}},
		{"type": "button", "label": "Close", "color": "#8888aa", "action": {"type": "close"}}]},
	"lore": {"title": "Sunfire Lore", "color": "#ffd24a", "width": 400, "x": 0.8, "y": 0.5, "elements": [
		{"type": "text", "text": "Long ago a star fell into the Emberdeep and never went out. The Sunborn knights were forged from its light. Drag this window by its title bar!", "size": 18},
		{"type": "button", "label": "Close", "action": {"type": "close"}}]},
}
const EXAMPLE_BUTTONS := {
	"hub_btn": {"label": "SUNFIRE HUB", "where": "both", "color": "#ffaa33", "action": {"type": "menu", "menu": "hub"}},
	"furnace_btn": {"label": "SUNKEN FURNACE", "where": "main", "color": "#ff7a33", "action": {"type": "mission", "mission": "sunken_furnace"}},
}

## Writes the example pack as a .zip (used by the in-game "install example" button and for the repo copy).
static func write_example_zip(path: String) -> bool:
	var zp := ZIPPacker.new()
	if zp.open(path) != OK:
		return false
	for pair in [["mod.json", EXAMPLE_MOD], ["items.json", EXAMPLE_ITEMS], ["sets.json", EXAMPLE_SETS], ["codes.json", EXAMPLE_CODES],
			["mobs.json", EXAMPLE_MOBS], ["levels.json", EXAMPLE_LEVELS], ["perks.json", EXAMPLE_PERKS], ["menus.json", EXAMPLE_MENUS], ["buttons.json", EXAMPLE_BUTTONS]]:
		zp.start_file(String(pair[0]))
		zp.write_file(JSON.stringify(pair[1], "  ").to_utf8_buffer())
		zp.close_file()
	zp.close()
	return true

static func install_example() -> Dictionary:
	var tmp := "user://example_mod.tmp.zip"
	if not write_example_zip(tmp):
		return {"ok": false, "msg": "Could not create the example mod."}
	var r := install_bytes(FileAccess.get_file_as_bytes(tmp))
	DirAccess.remove_absolute(tmp)
	return r
