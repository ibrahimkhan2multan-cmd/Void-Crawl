class_name VCIntro
extends CanvasLayer
## Startup cinematic, played once per launch: voxel cubes spiral together into the Infinity Studios
## crystal, the studio name types in, a flash, then the VOIDBORN title slams down over rising embers.
## Tap anywhere to skip. Pure 2D drawing, so it costs almost nothing.

signal finished

const LEN := 6.4
static var shown := false

var _c: Control
var _t := 0.0
var _done := false
var _cubes: Array = []
var _embers: Array = []
var _flash_t := -1.0
var _slam_t := -1.0
var _sfx := {"hit": false, "slam": false, "type": 0}

static func should_play() -> bool:
	return not shown and DisplayServer.get_name() != "headless"

func _ready() -> void:
	layer = 80
	process_mode = Node.PROCESS_MODE_ALWAYS
	shown = true
	_c = Control.new()
	_c.set_anchors_preset(Control.PRESET_FULL_RECT)
	_c.mouse_filter = Control.MOUSE_FILTER_STOP
	_c.draw.connect(_draw)
	_c.gui_input.connect(_input_ev)
	add_child(_c)
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for i in 120:
		var a := rng.randf() * TAU
		var r := rng.randf_range(0.55, 1.0)
		_cubes.append({"a": a, "r": r, "s": rng.randf_range(4.0, 11.0), "d": rng.randf_range(0.0, 0.6), "c": rng.randi() % 3, "spin": rng.randf_range(-3.0, 3.0)})
	for i in 70:
		_embers.append({"x": rng.randf(), "y": rng.randf(), "s": rng.randf_range(0.05, 0.22), "z": rng.randf_range(3.0, 8.0), "ph": rng.randf() * TAU, "c": rng.randi() % 3})

func _input_ev(ev: InputEvent) -> void:
	if _t > 0.7 and not _done and ((ev is InputEventMouseButton and ev.pressed) or (ev is InputEventScreenTouch and ev.pressed) or (ev is InputEventKey and ev.pressed)):
		_t = maxf(_t, LEN - 0.5)

func _process(delta: float) -> void:
	if _done:
		return
	_t += delta
	if _t > 1.55 and not _sfx["hit"]:
		_sfx["hit"] = true
		_flash_t = 0.0
		VC.play_sfx("levelup", -3.0, 0.7)
	if _t > 3.75 and not _sfx["slam"]:
		_sfx["slam"] = true
		_slam_t = 0.0
		_flash_t = 0.0
		VC.play_sfx("boss_roar", -4.0, 1.1)
	if _flash_t >= 0.0:
		_flash_t += delta
	if _slam_t >= 0.0:
		_slam_t += delta
	_c.queue_redraw()
	if _t >= LEN:
		_done = true
		finished.emit()
		queue_free()

func _col(i: int, a: float) -> Color:
	match i:
		0: return Color(0.62, 0.3, 1.0, a)
		1: return Color(0.4, 0.92, 1.0, a)
	return Color(1.0, 0.55, 0.85, a)

func _draw() -> void:
	var sz := _c.size
	var ctr := sz * 0.5
	var base := minf(sz.x, sz.y)
	var f := ThemeDB.fallback_font
	_c.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.01, 0.0, 0.03))
	var fade_out := 1.0 - clampf((_t - (LEN - 0.6)) / 0.6, 0.0, 1.0)
	# --- act 1: cubes spiral into the crystal
	var gather := clampf((_t - 0.3) / 1.2, 0.0, 1.0)
	var form := smoothstep(0.0, 1.0, gather)
	var crystal_a := clampf((_t - 1.4) / 0.3, 0.0, 1.0) * clampf(1.0 - (_t - 3.3) / 0.45, 0.0, 1.0)
	for cu in _cubes:
		var local := clampf((gather - float(cu["d"]) * 0.5) / 0.55, 0.0, 1.0)
		var e := local * local * (3.0 - 2.0 * local)
		var ang: float = float(cu["a"]) + (1.0 - e) * 2.4
		var dist: float = float(cu["r"]) * base * 0.75 * (1.0 - e)
		var p := ctr + Vector2(cos(ang), sin(ang)) * dist
		var s: float = float(cu["s"]) * (1.0 - 0.5 * e)
		var a := (0.9 if _t < 3.3 else clampf(1.0 - (_t - 3.3) / 0.4, 0.0, 1.0)) * minf(1.0, gather * 4.0)
		if a > 0.01 and e < 0.995:
			_c.draw_rect(Rect2(p - Vector2(s, s) * 0.5, Vector2(s, s)), _col(int(cu["c"]), a))
	# --- the crystal
	if crystal_a > 0.01:
		var pul := 1.0 + 0.04 * sin(_t * 5.0)
		var h := base * 0.17 * pul * (1.0 + 0.8 * clampf((_t - 3.0) / 0.7, 0.0, 1.0))
		var c := ctr + Vector2(0, -base * 0.15)
		var pts := PackedVector2Array([c + Vector2(0, -h), c + Vector2(h * 0.55, 0), c + Vector2(0, h * 1.1), c + Vector2(-h * 0.55, 0)])
		for g in 5:
			_c.draw_circle(c, h * (1.3 + 0.35 * float(g)), Color(0.5, 0.2, 1.0, 0.05 * crystal_a))
		_c.draw_colored_polygon(pts, Color(0.45, 0.15, 0.85, 0.95 * crystal_a))
		_c.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -h), c + Vector2(h * 0.55, 0), c]), Color(0.85, 0.6, 1.0, 0.95 * crystal_a))
		_c.draw_colored_polygon(PackedVector2Array([c + Vector2(0, h * 1.1), c + Vector2(-h * 0.55, 0), c]), Color(0.25, 0.07, 0.5, 0.95 * crystal_a))
		_c.draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), Color(0.95, 0.88, 1.0, crystal_a), 2.5, true)
		# shock ring on impact
		if _t > 1.55:
			var rr := (_t - 1.55) * base * 0.9
			_c.draw_arc(c, rr, 0.0, TAU, 48, Color(0.8, 0.6, 1.0, clampf(1.0 - (_t - 1.55) / 0.9, 0.0, 1.0)), 4.0)
	# --- act 2: studio name types in
	if _t > 1.9 and _t < 3.7:
		var name_s := "INFINITY STUDIOS"
		var n := clampi(int((_t - 1.9) / 0.07), 0, name_s.length())
		var fs := int(base * 0.075)
		var txt := name_s.substr(0, n)
		var full := f.get_string_size(name_s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var a2 := clampf(1.0 - (_t - 3.3) / 0.4, 0.0, 1.0)
		var pos := Vector2(ctr.x - full * 0.5, ctr.y + base * 0.2)
		var tw0 := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		for i in range(4, 0, -1):
			var gsz := fs + i * 2
			var gww := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, gsz).x
			_c.draw_string(f, pos + Vector2((tw0 - gww) * 0.5, 0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, gsz, Color(0.6, 0.3, 1.0, 0.05 * float(5 - i) * a2))
		_c.draw_string(f, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.92, 0.85, 1.0, a2))
		if _t > 2.9:
			var ps := int(base * 0.03)
			var pw := f.get_string_size("PRESENTS", HORIZONTAL_ALIGNMENT_LEFT, -1, ps).x
			_c.draw_string(f, Vector2(ctr.x - pw * 0.5, ctr.y + base * 0.27), "PRESENTS", HORIZONTAL_ALIGNMENT_LEFT, -1, ps, Color(0.6, 0.5, 0.85, a2 * clampf((_t - 2.9) / 0.3, 0.0, 1.0)))
	# --- act 3: title
	if _t > 3.75:
		var tt := _t - 3.75
		for em in _embers:
			var y := fposmod(float(em["y"]) - tt * float(em["s"]) * 1.4, 1.0)
			var x: float = float(em["x"]) + sin(tt * 1.3 + float(em["ph"])) * 0.02
			var q: float = float(em["z"])
			var ea := clampf(y * 3.0, 0.0, 1.0) * clampf((1.0 - y) * 3.0, 0.0, 1.0) * minf(1.0, tt * 2.0)
			_c.draw_rect(Rect2(Vector2(x * sz.x, y * sz.y), Vector2(q, q)), _col(int(em["c"]), 0.8 * ea))
		# god rays
		for i in 9:
			var ra := -PI * 0.5 + (float(i) - 4.0) * 0.28 + sin(tt * 0.6 + float(i)) * 0.03
			var tip := ctr + Vector2(cos(ra), sin(ra)) * base * 1.2
			_c.draw_colored_polygon(PackedVector2Array([ctr + Vector2(0, -base * 0.02), tip + Vector2(-base * 0.05, 0), tip + Vector2(base * 0.05, 0)]), Color(0.6, 0.3, 1.0, 0.07 * minf(1.0, tt * 2.0)))
		var title := VCDefs.GAME_NAME
		var scale := 1.0 + 0.9 * maxf(0.0, 1.0 - tt * 4.0)
		var fs2 := int(base * 0.17 * scale)
		var shake := Vector2(sin(tt * 90.0), cos(tt * 77.0)) * 6.0 * maxf(0.0, 1.0 - tt * 3.5)
		var tw := f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2).x
		var tpos := Vector2(ctr.x - tw * 0.5, ctr.y + base * 0.05) + shake
		var ta := minf(1.0, tt * 5.0) * fade_out
		for i in range(7, 0, -1):
			var gs := fs2 + i * 3
			var gw := f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, gs).x
			var gp := tpos + Vector2((tw - gw) * 0.5, float(i * 3) * 0.3)
			_c.draw_string(f, gp, title, HORIZONTAL_ALIGNMENT_LEFT, -1, gs, Color(0.55, 0.2, 1.0, 0.045 * float(8 - i) * ta))
		_c.draw_string(f, tpos + Vector2(4, 5), title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, Color(0.05, 0.0, 0.12, ta))
		_c.draw_string(f, tpos, title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, Color(0.95, 0.88, 1.0, ta))
		# glint sweeping across the letters
		var gx := tpos.x + fposmod(tt * 0.9, 2.2) / 2.2 * tw * 1.3 - tw * 0.15
		if gx > tpos.x and gx < tpos.x + tw:
			var gh := fs2 * 0.75
			var gy := tpos.y
			var gwid := base * 0.02
			_c.draw_colored_polygon(PackedVector2Array([Vector2(gx + gh * 0.25, gy - gh), Vector2(gx + gh * 0.25 + gwid, gy - gh), Vector2(gx + gwid, gy), Vector2(gx, gy)]), Color(1, 1, 1, 0.22 * ta))
		var tag := "A BLOCKY DUNGEON ADVENTURE"
		var tgs := int(base * 0.035)
		var tgw := f.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, tgs).x
		_c.draw_string(f, Vector2(ctr.x - tgw * 0.5, ctr.y + base * 0.2), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, tgs, Color(0.7, 0.6, 0.95, clampf((tt - 0.5) / 0.5, 0.0, 1.0) * fade_out))
		var hint := "tap to continue"
		var hs := int(base * 0.026)
		var hw := f.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, hs).x
		_c.draw_string(f, Vector2(ctr.x - hw * 0.5, sz.y - base * 0.06), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, hs, Color(0.6, 0.5, 0.8, (0.4 + 0.3 * sin(tt * 4.0)) * clampf((tt - 1.0) / 0.5, 0.0, 1.0) * fade_out))
	# --- flashes
	if _flash_t >= 0.0 and _flash_t < 0.5:
		_c.draw_rect(Rect2(Vector2.ZERO, sz), Color(1, 0.95, 1, 0.8 * (1.0 - _flash_t / 0.5)))
	# letterbox bars and fade-out to the menu
	var bar := sz.y * 0.09
	_c.draw_rect(Rect2(0, 0, sz.x, bar), Color.BLACK)
	_c.draw_rect(Rect2(0, sz.y - bar, sz.x, bar), Color.BLACK)
	if fade_out < 1.0:
		# reveal the menu behind through the dark layer
		pass
