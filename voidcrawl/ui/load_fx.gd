class_name VCLoadFx
extends Control
## Animated background for the loading card: a blocky void rift that spins and pulses, rising
## embers, drifting rune cubes and a slow scan line. Pure drawing, no textures, very cheap.

const EMBERS := 46
var _t := 0.0
var _em: Array = []
var _cubes: Array = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in EMBERS:
		_em.append({"x": rng.randf(), "y": rng.randf(), "s": rng.randf_range(0.04, 0.16), "z": rng.randf_range(3.0, 8.0), "ph": rng.randf() * TAU, "c": rng.randi() % 3})
	for i in 7:
		_cubes.append({"a": TAU * float(i) / 7.0, "r": rng.randf_range(0.22, 0.42), "sp": rng.randf_range(0.2, 0.5) * (1.0 if i % 2 == 0 else -1.0), "z": rng.randf_range(10.0, 22.0)})

func _process(delta: float) -> void:
	_t += delta / maxf(Engine.time_scale, 0.05)
	queue_redraw()

func _draw() -> void:
	var sz := size
	if sz.x < 10.0:
		return
	var ctr := sz * 0.5
	var base := minf(sz.x, sz.y)
	# rift: nested rotating squares
	for i in 9:
		var k := float(i) / 8.0
		var half := base * (0.12 + 0.5 * k) * (1.0 + 0.03 * sin(_t * 1.6 + float(i)))
		var ang := _t * (0.25 + 0.08 * float(i)) * (1.0 if i % 2 == 0 else -1.0) + float(i) * 0.4
		var col := Color(0.5, 0.2, 0.9).lerp(Color(0.95, 0.3, 0.8), 0.5 + 0.5 * sin(_t * 0.8 + float(i) * 0.7))
		col.a = 0.16 * (1.0 - k) + 0.03
		var pts := PackedVector2Array()
		for j in 5:
			var a := ang + float(j) * PI * 0.5 + PI * 0.25
			pts.append(ctr + Vector2(cos(a), sin(a)) * half * 1.414)
		draw_polyline(pts, col, 3.0 + 3.0 * (1.0 - k))
	# glowing core
	var pulse := 0.5 + 0.5 * sin(_t * 2.4)
	for g in 5:
		var r := base * (0.05 + 0.03 * float(g)) * (1.0 + 0.1 * pulse)
		draw_rect(Rect2(ctr - Vector2(r, r), Vector2(r, r) * 2.0), Color(0.7, 0.4, 1.0, 0.07), true)
	# orbiting rune cubes
	for c in _cubes:
		var a: float = float(c["a"]) + _t * float(c["sp"])
		var rr: float = base * float(c["r"])
		var p := ctr + Vector2(cos(a) * rr * 1.5, sin(a) * rr)
		var s: float = float(c["z"]) * (0.8 + 0.4 * sin(_t * 2.0 + float(c["a"])))
		draw_rect(Rect2(p - Vector2(s, s) * 0.5, Vector2(s, s)), Color(0.55, 0.95, 1.0, 0.5), true)
		draw_rect(Rect2(p - Vector2(s, s) * 0.5, Vector2(s, s)), Color(1, 1, 1, 0.5), false, 1.5)
	# embers rising
	for e in _em:
		var y := fposmod(float(e["y"]) - _t * float(e["s"]), 1.0)
		var x: float = float(e["x"]) + sin(_t * 0.9 + float(e["ph"])) * 0.02
		var q: float = float(e["z"])
		var col2 := Color(1.0, 0.65, 0.3, 0.7) if int(e["c"]) == 0 else (Color(0.8, 0.5, 1.0, 0.7) if int(e["c"]) == 1 else Color(0.5, 0.95, 1.0, 0.7))
		col2.a *= clampf(y * 3.0, 0.0, 1.0) * clampf((1.0 - y) * 3.0, 0.0, 1.0)
		draw_rect(Rect2(Vector2(x * sz.x, y * sz.y), Vector2(q, q)), col2, true)
	# slow scan line
	var sy := fposmod(_t * 0.12, 1.0) * sz.y
	draw_rect(Rect2(0, sy, sz.x, 3), Color(0.7, 0.5, 1.0, 0.07), true)
