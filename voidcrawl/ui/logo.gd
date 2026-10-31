class_name VCLogo
extends Control
## The VOIDBORN wordmark, drawn from vector shapes: a faceted void crystal (same emblem as the app icon) over a
## glowing, outlined title. Fully original; no font file or image needed.

var pulse := 0.0
var subtitle := "INFINITY STUDIOS"

func _process(delta: float) -> void:
	pulse += delta
	queue_redraw()

func _poly(pts: Array, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array(pts), col)

## One facet-shaded crystal. (cx, cy) = centre, h = half height.
func _crystal(c: Vector2, h: float, tint: float) -> void:
	var w := h * 0.46
	var top := c + Vector2(0, -h)
	var bot := c + Vector2(0, h * 0.82)
	var ul := c + Vector2(-w, -h * 0.2)
	var ur := c + Vector2(w, -h * 0.2)
	var ml := c + Vector2(-w * 0.28, -h * 0.2)
	var mr := c + Vector2(w * 0.28, -h * 0.2)
	var ll := c + Vector2(-w, h * 0.28)
	var lr := c + Vector2(w, h * 0.28)
	var lml := c + Vector2(-w * 0.28, h * 0.28)
	var lmr := c + Vector2(w * 0.28, h * 0.28)
	var a := tint
	# upper facets (cyan -> white)
	_poly([top, ml, ul], Color(0.62, 0.95, 1.0, a))
	_poly([top, mr, ml], Color(0.85, 1.0, 1.0, a))
	_poly([top, ur, mr], Color(0.45, 0.82, 1.0, a))
	# belt
	_poly([ul, ml, lml, ll], Color(0.42, 0.55, 0.98, a))
	_poly([ml, mr, lmr, lml], Color(0.72, 0.88, 1.0, a))
	_poly([mr, ur, lr, lmr], Color(0.33, 0.42, 0.88, a))
	# lower facets (violet)
	_poly([ll, lml, bot], Color(0.38, 0.2, 0.86, a))
	_poly([lml, lmr, bot], Color(0.52, 0.3, 0.98, a))
	_poly([lmr, lr, bot], Color(0.26, 0.12, 0.66, a))
	var edge := Color(0.95, 0.9, 1.0, 0.85 * a)
	draw_polyline(PackedVector2Array([top, ur, lr, bot, ll, ul, top]), edge, 1.6, true)
	draw_line(ml, lml, edge * Color(1, 1, 1, 0.6), 1.0)
	draw_line(mr, lmr, edge * Color(1, 1, 1, 0.6), 1.0)
	draw_polyline(PackedVector2Array([c + Vector2(w * 0.05, -h * 0.55), c + Vector2(w * 0.22, -h * 0.25), c + Vector2(-w * 0.05, h * 0.0), c + Vector2(w * 0.18, h * 0.3), c + Vector2(0, h * 0.58)]), Color(1, 1, 1, 0.9 * a), 1.8, true)

func _draw() -> void:
	var s := size
	var cx := s.x * 0.5
	var f := ThemeDB.fallback_font
	var fs := int(minf(s.y * 0.5, s.x * 0.1))
	var title := VCDefs.GAME_NAME
	var tw := f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pos := Vector2(cx - tw * 0.5, s.y * 0.7)
	var glow := 0.6 + 0.2 * sin(pulse * 2.0)
	# glow halo behind the crystal
	var c := Vector2(cx, s.y * 0.25)
	var h := s.y * 0.2
	for i in range(7, 0, -1):
		draw_circle(c, h * (0.9 + 0.16 * float(i)), Color(0.6, 0.25, 1.0, 0.045 * glow))
	# floating shards
	for side in [-1.0, 1.0]:
		var bob := sin(pulse * 1.6 + side) * 2.5
		var sc := c + Vector2(side * h * 1.15, h * 0.1 + bob)
		_crystal(sc, h * 0.5, 0.9)
		var sc2 := c + Vector2(side * h * 1.85, h * 0.45 - bob)
		_crystal(sc2, h * 0.3, 0.75)
	_crystal(c + Vector2(0, sin(pulse * 1.3) * 1.5), h, 1.0)
	# title: neon halo, hard outline, extruded shadow, light fill, shine
	for i in range(6, 0, -1):
		draw_string(f, pos, title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs + i * 2, Color(0.55, 0.2, 1.0, 0.045 * glow * float(7 - i)))
	for o in [Vector2(-3, 0), Vector2(3, 0), Vector2(0, -3), Vector2(0, 3), Vector2(-2, -2), Vector2(2, 2), Vector2(-2, 2), Vector2(2, -2)]:
		draw_string(f, pos + o + Vector2(0, 2), title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.06, 0.0, 0.14))
	for k in range(5, 0, -1):
		draw_string(f, pos + Vector2(0, float(k)), title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.32, 0.12, 0.62))
	draw_string(f, pos, title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.97, 0.92, 1.0))
	# a thin rift line with a gem under the title
	var ly := s.y * 0.8
	var half := tw * 0.5
	draw_line(Vector2(cx - half, ly), Vector2(cx - 14, ly), Color(0.7, 0.45, 1.0, 0.7), 2.0)
	draw_line(Vector2(cx + 14, ly), Vector2(cx + half, ly), Color(0.7, 0.45, 1.0, 0.7), 2.0)
	_poly([Vector2(cx, ly - 6), Vector2(cx + 7, ly), Vector2(cx, ly + 6), Vector2(cx - 7, ly)], Color(0.8, 1.0, 1.0, 0.95))
	var sf := int(maxf(14.0, s.y * 0.1))
	var sw := f.get_string_size(subtitle, HORIZONTAL_ALIGNMENT_LEFT, -1, sf).x
	draw_string(f, Vector2(cx - sw * 0.5, s.y * 0.96), subtitle, HORIZONTAL_ALIGNMENT_LEFT, -1, sf, Color(0.7, 0.58, 0.95))
