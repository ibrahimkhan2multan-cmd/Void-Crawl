class_name VCSave
extends RefCounted
## JSON save file in user://. Written to a temp file first, then swapped in, so a
## crash or power loss mid-write can never corrupt the existing save.

const PATH := "user://voidcrawl_save.json"
const TMP := "user://voidcrawl_save.tmp"

static var path_override := ""   # tests point this at a scratch file

static func _path() -> String:
	return path_override if path_override != "" else PATH

static func exists() -> bool:
	return FileAccess.file_exists(_path())

## run = in-progress dungeon dictionary (may be empty).
static func save(profile: VCProfile, run: Dictionary) -> bool:
	var data := {
		"version": VCDefs.SAVE_VERSION,
		"game": VCDefs.GAME_NAME,
		"profile": profile.to_dict(),
		"run": run,
	}
	var text := JSON.stringify(data, "\t")
	var tmp := _path() + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("VCSave: cannot open temp file (%s)" % error_string(FileAccess.get_open_error()))
		return false
	f.store_string(text)
	f.flush()
	f.close()
	var dir := DirAccess.open(tmp.get_base_dir())
	if dir == null:
		return false
	if FileAccess.file_exists(_path()):
		dir.remove(_path().get_file())
	var err := dir.rename(tmp.get_file(), _path().get_file())
	if err != OK:
		push_warning("VCSave: rename failed (%s)" % error_string(err))
		return false
	return true

## Returns {"profile": VCProfile, "run": Dictionary} or an empty Dictionary if none/corrupt.
static func load_save() -> Dictionary:
	if not exists():
		return {}
	var f := FileAccess.open(_path(), FileAccess.READ)
	if f == null:
		return {}
	var text := f.get_as_text()
	f.close()
	var json := JSON.new()
	var parsed: Variant = json.data if json.parse(text) == OK else null
	if not (parsed is Dictionary):
		push_warning("VCSave: save file is corrupt, ignoring")
		return {}
	var d: Dictionary = parsed
	if not d.has("profile") or not (d["profile"] is Dictionary):
		return {}
	var run: Dictionary = d.get("run", {}) if d.get("run", {}) is Dictionary else {}
	return {"profile": VCProfile.from_dict(d["profile"]), "run": run}

static func delete_save() -> void:
	if exists():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_path()))
