class_name VCCrashGuard
extends RefCounted
## Detects an unclean exit and preserves the engine log so it can be inspected/copied.
## A flag file exists while the game is in the foreground. If it is still there at the next
## launch, the previous session ended without the app being paused or closed (crash/kill).

const FLAG := "user://running.flag"
const REPORT := "user://last_crash_report.txt"

const CRUMBS := "user://breadcrumbs.txt"
const CRUMBS_PREV := "user://breadcrumbs_prev.txt"

static var crashed_last_time := false
static var context := ""            # set by the mission: room, enemy count, etc.
const MARK := "user://lastmark.txt"
const MARK_PREV := "user://lastmark_prev.txt"
static var _mark_file: FileAccess = null
static var mark_n := 0
static var level := 0               ## graphics/feature fallback level (0 normal ... 4 minimal); raised by each crash
static var _crumb_lines: PackedStringArray = PackedStringArray()

## Called every ~2 s from the autoload. Writes a one-line state snapshot and flushes it to
## disk immediately, so after a crash we can see what the game was doing and how much memory it used.
static func crumb(extra: String = "") -> void:
	var line := "%s fps=%d mem=%dMB vram=%dMB nodes=%d objs=%d scene=%s %s %s" % [
		Time.get_time_string_from_system(), int(Engine.get_frames_per_second()),
		int(OS.get_static_memory_usage() / 1048576), int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0),
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		(Engine.get_main_loop() as SceneTree).current_scene.name if Engine.get_main_loop() is SceneTree and (Engine.get_main_loop() as SceneTree).current_scene != null else "?",
		context, extra]
	_crumb_lines.append(line)
	if _crumb_lines.size() > 40:
		_crumb_lines = _crumb_lines.slice(_crumb_lines.size() - 40)
	var f := FileAccess.open(CRUMBS, FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(_crumb_lines))
		f.close()

## Overwrites ONE line on disk (flushed immediately). After a native crash it shows the very last
## thing the game did, down to the frame. Cheap: fixed-size write at offset 0.
static func mark(label: String) -> void:
	if _mark_file == null:
		_mark_file = FileAccess.open(MARK, FileAccess.WRITE)
		if _mark_file == null:
			return
	mark_n += 1
	_mark_file.seek(0)
	var line := "%d|%s|%s" % [mark_n, label, context]
	_mark_file.store_string(line.substr(0, 220).rpad(220) + "\n")
	_mark_file.flush()

static func on_start() -> void:
	crashed_last_time = FileAccess.file_exists(FLAG)
	level = 0                                           # never auto-degrade quality; diagnostics only
	if not bool(VCSettings.values.get("migrated_027", false)):
		VCSettings.values["safe_mode"] = false          # undo the old automatic safe mode
		VCSettings.values["crash_level"] = 0
		VCSettings.values["migrated_027"] = true
		VCSettings.save_settings()
	if FileAccess.file_exists(MARK):
		var mo := FileAccess.get_file_as_string(MARK)
		var mp := FileAccess.open(MARK_PREV, FileAccess.WRITE)
		if mp != null:
			mp.store_string(mo)
			mp.close()
	if FileAccess.file_exists(CRUMBS):
		var old := FileAccess.get_file_as_string(CRUMBS)
		var pf := FileAccess.open(CRUMBS_PREV, FileAccess.WRITE)
		if pf != null:
			pf.store_string(old)
			pf.close()
	if crashed_last_time:
		VCSettings.save_settings()
		var txt := _previous_log_text()
		var f := FileAccess.open(REPORT, FileAccess.WRITE)
		if f != null:
			f.store_string("VOIDCRAWL possible crash report\nversion %s\ndevice %s | %s | gpu %s\ntime %s\n\n--- last state snapshots before the crash ---\n%s\n\n%s" % [
				String(ProjectSettings.get_setting("application/config/version", "?")) + " fallback_level_now=%d" % level + "\nLAST MARK BEFORE CRASH (frame|phase|state): " + FileAccess.get_file_as_string(MARK_PREV).strip_edges(), OS.get_model_name(), OS.get_version(),
				RenderingServer.get_video_adapter_name(), Time.get_datetime_string_from_system(), _tail(CRUMBS_PREV, 24), txt])
			f.close()
	elif FileAccess.file_exists(REPORT):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(REPORT))   # never show a stale report
	mark_running(true)

## Marks a stage right before something risky, so the report shows the last thing attempted.
static func stage(name: String) -> void:
	crumb("STAGE " + name)

static func mark_running(on: bool) -> void:
	if on:
		var f := FileAccess.open(FLAG, FileAccess.WRITE)
		if f != null:
			f.store_string("1")
			f.close()
	elif FileAccess.file_exists(FLAG):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(FLAG))

static func _logs() -> Array:
	var out: Array = []
	var d := DirAccess.open("user://logs")
	if d == null:
		return out
	for fn in d.get_files():
		if fn.ends_with(".log"):
			out.append("user://logs/" + fn)
	out.sort_custom(func(a, b): return FileAccess.get_modified_time(a) > FileAccess.get_modified_time(b))
	return out

static func _tail(path: String, lines: int) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var all := f.get_as_text().split("\n")
	var start := maxi(0, all.size() - lines)
	return "\n".join(all.slice(start))

## Text of the log from the session before this one (the active log is the newest file).
static func _previous_log_text() -> String:
	var logs := _logs()
	if logs.size() >= 2:
		return "--- %s ---\n%s" % [logs[1], _tail(logs[1], 160)]
	return "(no earlier log files)"

static func report_text() -> String:
	var t := ""
	if FileAccess.file_exists(REPORT):
		t = FileAccess.get_file_as_string(REPORT)
	t = "safe_mode=%s version=%s\n" % [str(VCSettings.safe_mode()), str(ProjectSettings.get_setting("application/config/version", "?"))] + t
	var logs := _logs()
	if logs.size() > 0:
		t += "\n\n--- current session log tail (%s) ---\n%s" % [logs[0], _tail(logs[0], 80)]
	if t.strip_edges() == "":
		t = "No crash report or log yet. Logs are written while the game runs."
	return t
