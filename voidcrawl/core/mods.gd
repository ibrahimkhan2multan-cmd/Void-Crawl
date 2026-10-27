class_name VCMods
extends RefCounted
## Data-only mod packs. A mod is a .zip containing mod.json (+ optional items.json, sets.json, codes.json).
## Mods can add weapons, armour, boots, trinkets, armour sets and promo codes. They never run code:
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

static var list: Array = []            # one Dictionary per installed pack (see _info)
static var _base_items: Dictionary = {}
static var _base_sets: Dictionary = {}
static var _base_codes: Dictionary = {}
static var _disabled: Array = []

# ------------------------------------------------------------------ registry
static func _snapshot() -> void:
	if _base_items.is_empty():
		_base_items = VCItems.BASES.duplicate(true)
		_base_sets = VCSets.DEFS.duplicate(true)
		_base_codes = VCCodes.DEFS.duplicate(true)

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
	return {"ok": true, "id": id, "msg": "Installed %s: %d items, %d sets, %d codes%s%s" % [name, (parsed["items"] as Dictionary).size(), (parsed["sets"] as Dictionary).size(), (parsed["codes"] as Dictionary).size(), warn, _reconcile_text(r)]}

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
	var out := {"ok": false, "manifest": {}, "items": {}, "sets": {}, "codes": {}, "errors": []}
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
	var raw_items: Dictionary = {}
	var raw_sets: Dictionary = {}
	var raw_codes: Dictionary = {}
	for pair in [["items", raw_items], ["sets", raw_sets], ["codes", raw_codes]]:
		var key: String = pair[0]
		var dst: Dictionary = pair[1]
		if mj.get(key) is Dictionary:
			dst.merge(mj[key])
		var extra = _read_json(zr, files, prefix, key + ".json")
		if extra is String:
			errs.append("%s.json: %s" % [key, "file too large" if extra == "too_big" else "invalid JSON"])
		elif extra is Dictionary:
			dst.merge(extra.get(key, extra) if extra.get(key) is Dictionary else extra)
	zr.close()
	# items
	var items: Dictionary = out["items"]
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
	# sets (need the items for slot checks)
	var sets: Dictionary = out["sets"]
	n = 0
	for k in raw_sets:
		n += 1
		if n > MAX_SETS:
			errs.append("too many sets (max %d)" % MAX_SETS)
			break
		var rs := _build_set(mid, String(k), raw_sets[k], items)
		if rs.has("error"):
			errs.append("set %s: %s" % [String(k), String(rs["error"])])
		else:
			sets["%s__%s" % [mid, _clean_id(String(k))]] = rs["set"]
	# codes
	var codes: Dictionary = out["codes"]
	n = 0
	for k in raw_codes:
		n += 1
		if n > MAX_CODES:
			errs.append("too many codes (max %d)" % MAX_CODES)
			break
		var code := VCCodes.normalise(String(k))
		if code == "" or code.length() > 24:
			errs.append("code %s: invalid name" % String(k))
			continue
		var rc := _build_code(mid, raw_codes[k], items)
		if rc.has("error"):
			errs.append("code %s: %s" % [String(k), String(rc["error"])])
		else:
			codes[code] = rc["code"]
	if items.is_empty() and sets.is_empty() and codes.is_empty():
		errs.append("the pack adds nothing (no valid items, sets or codes)")
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

static func _build_set(mid: String, id: String, spec: Variant, items: Dictionary) -> Dictionary:
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
	if mission != "" and not MISSIONS.has(mission):
		return {"error": "mission must be empty or one of " + ", ".join(MISSIONS)}
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

# ------------------------------------------------------------------- example
const EXAMPLE_MOD := {
	"id": "sunfire", "name": "Sunfire Pack", "version": "1.0", "author": "Infinity Studios",
	"description": "Example mod: a blazing sword, solar boots, the Sunborn armour set and two codes.",
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
	"sunborn": {"name": "Sunborn Regalia", "mission": "forge", "color": "#c98a2a", "glow": "#ffcc55",
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

## Writes the example pack as a .zip (used by the in-game "install example" button and for the repo copy).
static func write_example_zip(path: String) -> bool:
	var zp := ZIPPacker.new()
	if zp.open(path) != OK:
		return false
	for pair in [["mod.json", EXAMPLE_MOD], ["items.json", EXAMPLE_ITEMS], ["sets.json", EXAMPLE_SETS], ["codes.json", EXAMPLE_CODES]]:
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
