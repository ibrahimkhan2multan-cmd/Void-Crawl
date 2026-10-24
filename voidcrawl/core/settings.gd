class_name VCSettings
extends RefCounted
## User settings (audio, graphics quality, controls). Stored in user://voidcrawl_settings.cfg.

const PATH := "user://voidcrawl_settings.cfg"
static var path_override := ""

const DEFAULTS := {
	"master": 0.8, "music": 0.6, "sfx": 0.9,
	"quality": 1,            # 0 low, 1 medium, 2 high
	"fps": 30,               # 30 or 60
	"show_fps": false,
	"safe_mode": false,      # plain materials, no custom shaders / glow / fog / gradients (auto-enabled after a crash)
	"joy_size": 1.0, "joy_floating": true, "joy_deadzone": 0.12,
	"btn_scale": 1.0, "btn_opacity": 0.8, "left_handed": false,
	"cam_sens": 1.0, "cam_zoom": 1.0,
	"haptics": true, "damage_numbers": true, "screen_shake": 1.0,
}

static var values: Dictionary = DEFAULTS.duplicate()

static func _path() -> String:
	return path_override if path_override != "" else PATH

static func load_settings() -> void:
	values = DEFAULTS.duplicate()
	var cf := ConfigFile.new()
	if cf.load(_path()) != OK:
		return
	for k in DEFAULTS:
		if cf.has_section_key("settings", k):
			var v: Variant = cf.get_value("settings", k)
			# keep the type of the default so a hand-edited file can't break things
			if typeof(v) == typeof(DEFAULTS[k]) or (typeof(DEFAULTS[k]) == TYPE_FLOAT and typeof(v) == TYPE_INT):
				values[k] = v

static func save_settings() -> void:
	var cf := ConfigFile.new()
	for k in values:
		cf.set_value("settings", k, values[k])
	cf.save(_path())

static func get_value(key: String) -> Variant:
	return values.get(key, DEFAULTS.get(key))

static func set_value(key: String, v: Variant) -> void:
	values[key] = v

static func _set_bus(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	AudioServer.set_bus_mute(idx, linear <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(linear, 0.0001, 1.0)))

## Quality presets. Returns a dictionary of tunables read by the world/builder.
static func safe_mode() -> bool:
	return bool(values.get("safe_mode", false))

static func quality_profile() -> Dictionary:
	if safe_mode():
		return {"scale_3d": 1.0, "max_lights": 2, "particles": 0.0, "shadows": false, "msaa": 0, "fog": false, "glow": false, "max_enemies_fx": 4}
	match int(values["quality"]):
		0:
			return {"scale_3d": 0.62, "max_lights": 3, "particles": 0.35, "shadows": false, "msaa": 0, "fog": false, "glow": false, "max_enemies_fx": 6}
		2:
			return {"scale_3d": 1.0, "max_lights": 8, "particles": 1.0, "shadows": true, "msaa": 2, "fog": true, "glow": true, "max_enemies_fx": 16}
		_:
			return {"scale_3d": 0.82, "max_lights": 5, "particles": 0.65, "shadows": false, "msaa": 0, "fog": true, "glow": false, "max_enemies_fx": 10}

## Apply everything that is global (audio buses, frame cap, viewport).
static func apply(viewport: Viewport = null) -> void:
	_set_bus("Master", float(values["master"]))
	_set_bus("Music", float(values["music"]))
	_set_bus("SFX", float(values["sfx"]))
	Engine.max_fps = int(values["fps"])
	if viewport != null:
		var q := quality_profile()
		# 3D resolution scaling is deliberately NOT used: it is unreliable in the Compatibility
		# renderer on some Mali/PowerVR drivers. Quality presets reduce lights, fog, glow and particles instead.
		viewport.scaling_3d_scale = 1.0
		viewport.msaa_3d = Viewport.MSAA_2X if int(q["msaa"]) == 2 else Viewport.MSAA_DISABLED
