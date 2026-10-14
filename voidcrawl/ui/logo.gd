class_name VCLogo
extends Control
## The VOIDCRAWL wordmark, drawn from vector shapes: a crystalline void-rift "V" over a
## glowing title. Fully original; no font file or image needed.

var pulse := 0.0
var subtitle := "INFINITY STUDIOS"

func _process(delta: float) -> void:
	pulse += delta
	queue_redraw()

func _draw() -> void:
	var s := size
	var cx := s.x * 0.5
	var f := ThemeDB.fallback_font
	var fs := int(minf(s.y * 0.52, s.x * 0.11))
	var title := "VOIDCRAWL"
	var tw := f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pos := Vector2(cx - tw * 0.5, s.y * 0.66)
	var glow := 0.55 + 0.15 * sin(pulse * 2.0)
	for i in range(6, 0, -1):
		draw_string(f, pos, title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs + i * 2, Color(0.55, 0.2, 1.0, 0.05 * glow * float(7 - i)))
	draw_string(f, pos + Vector2(3, 4), title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.05, 0.0, 0.12))
	draw_string(f, pos, title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.93, 0.85, 1.0))
	# rift crystal above the title
	var c := Vector2(cx, s.y * 0.22)
	var h := s.y * 0.2
	var pts := PackedVector2Array([c + Vector2(0, -h), c + Vector2(h * 0.55, 0), c + Vector2(0, h * 1.1), c + Vector2(-h * 0.55, 0)])
	draw_colored_polygon(pts, Color(0.45, 0.15, 0.85, 0.9))
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -h), c + Vector2(h * 0.55, 0), c]), Color(0.8, 0.55, 1.0, 0.9))
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, h * 1.1), c + Vector2(-h * 0.55, 0), c]), Color(0.25, 0.07, 0.5, 0.95))
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), Color(0.95, 0.85, 1.0, 0.9), 2.0, true)
	for side in [-1.0, 1.0]:
		var base := c + Vector2(side * h * 0.9, h * 0.1)
		draw_colored_polygon(PackedVector2Array([base + Vector2(0, -h * 0.55), base + Vector2(h * 0.22, h * 0.05), base + Vector2(0, h * 0.5), base + Vector2(-h * 0.22, h * 0.05)]), Color(0.55, 0.22, 1.0, 0.75))
	var sf := int(maxf(14.0, s.y * 0.1))
	var sw := f.get_string_size(subtitle, HORIZONTAL_ALIGNMENT_LEFT, -1, sf).x
	draw_string(f, Vector2(cx - sw * 0.5, s.y * 0.94), subtitle, HORIZONTAL_ALIGNMENT_LEFT, -1, sf, Color(0.62, 0.5, 0.85))
