class_name VCPetIcon
extends Control
## Little vector portrait of a pet (or an egg) used by the PETS screen and the HUD.

var species := ""
var egg_tier := ""
var dim := false
var _t := 0.0

func _init() -> void:
	custom_minimum_size = Vector2(84, 84)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_species(id: String) -> void:
	species = id
	egg_tier = ""
	queue_redraw()

func set_egg(tier: String) -> void:
	egg_tier = tier
	species = ""
	queue_redraw()

func _process(delta: float) -> void:
	_t += delta
	if visible and is_inside_tree():
		queue_redraw()

func _draw() -> void:
	var s := size
	draw_rect(Rect2(Vector2.ZERO, s), Color(0.04, 0.02, 0.08, 0.95))
	if egg_tier != "":
		_draw_egg()
		return
	if not VCPets.SPECIES.has(species):
		return
	var d: Dictionary = VCPets.SPECIES[species]
	var rc := VCDefs.rarity_color(int(d["rarity"]))
	draw_rect(Rect2(Vector2.ZERO, s), rc, false, 2.0)
	var col: Color = d["col"]
	var col2: Color = d["col2"]
	var glow: Color = d["glow"]
	var a := 0.45 if dim else 1.0
	col.a = a
	col2.a = a
	glow.a = a
	var bob := sin(_t * 3.0) * 2.0
	var c := s * 0.5 + Vector2(0, bob)
	var k := minf(s.x, s.y) * 0.3
	match String(d["style"]):
		"quad":
			draw_rect(Rect2(c + Vector2(-k * 0.9, -k * 0.3), Vector2(k * 1.5, k * 0.8)), col)
			draw_rect(Rect2(c + Vector2(k * 0.4, -k * 0.7), Vector2(k * 0.8, k * 0.75)), col)
			draw_colored_polygon(PackedVector2Array([c + Vector2(k * 0.5, -k * 0.7), c + Vector2(k * 0.62, -k * 1.1), c + Vector2(k * 0.78, -k * 0.7)]), col2)
			draw_colored_polygon(PackedVector2Array([c + Vector2(k * 0.95, -k * 0.7), c + Vector2(k * 1.08, -k * 1.1), c + Vector2(k * 1.2, -k * 0.7)]), col2)
			draw_rect(Rect2(c + Vector2(-k * 0.8, k * 0.5), Vector2(k * 0.3, k * 0.6)), col2)
			draw_rect(Rect2(c + Vector2(k * 0.3, k * 0.5), Vector2(k * 0.3, k * 0.6)), col2)
			draw_line(c + Vector2(-k * 0.9, -k * 0.1), c + Vector2(-k * 1.4, -k * 0.6), col2, 5.0, true)
			draw_rect(Rect2(c + Vector2(k * 0.95, -k * 0.5), Vector2(k * 0.15, k * 0.15)), glow)
		"bird":
			draw_circle(c, k * 0.7, col)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-k * 0.2, -k * 0.2), c + Vector2(-k * 1.5, -k * 0.9 + sin(_t * 8.0) * k * 0.2), c + Vector2(-k * 0.9, k * 0.2)]), col2)
			draw_colored_polygon(PackedVector2Array([c + Vector2(k * 0.2, -k * 0.2), c + Vector2(k * 1.5, -k * 0.9 + sin(_t * 8.0) * k * 0.2), c + Vector2(k * 0.9, k * 0.2)]), col2)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-k * 0.15, -k * 0.1), c + Vector2(k * 0.15, -k * 0.1), c + Vector2(0, k * 0.35)]), glow)
			draw_circle(c + Vector2(-k * 0.25, -k * 0.25), k * 0.1, glow)
			draw_circle(c + Vector2(k * 0.25, -k * 0.25), k * 0.1, glow)
		"blob":
			draw_rect(Rect2(c + Vector2(-k, -k * 0.3), Vector2(k * 2.0, k * 1.1)), col)
			draw_rect(Rect2(c + Vector2(-k * 0.6, -k * 0.8), Vector2(k * 1.2, k * 0.6)), col2)
			draw_rect(Rect2(c + Vector2(-k * 0.5, -k * 0.1), Vector2(k * 0.25, k * 0.35)), Color(1, 1, 1, a))
			draw_rect(Rect2(c + Vector2(k * 0.25, -k * 0.1), Vector2(k * 0.25, k * 0.35)), Color(1, 1, 1, a))
			draw_rect(Rect2(c + Vector2(-k * 0.42, k * 0.0), Vector2(k * 0.1, k * 0.2)), glow)
			draw_rect(Rect2(c + Vector2(k * 0.33, k * 0.0), Vector2(k * 0.1, k * 0.2)), glow)
		"imp":
			draw_rect(Rect2(c + Vector2(-k * 0.5, -k * 0.2), Vector2(k, k * 1.1)), col)
			draw_rect(Rect2(c + Vector2(-k * 0.55, -k * 1.0), Vector2(k * 1.1, k * 0.8)), col)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-k * 0.55, -k * 1.0), c + Vector2(-k * 0.8, -k * 1.5), c + Vector2(-k * 0.2, -k * 1.0)]), col2)
			draw_colored_polygon(PackedVector2Array([c + Vector2(k * 0.55, -k * 1.0), c + Vector2(k * 0.8, -k * 1.5), c + Vector2(k * 0.2, -k * 1.0)]), col2)
			draw_rect(Rect2(c + Vector2(-k * 0.35, -k * 0.7), Vector2(k * 0.2, k * 0.2)), glow)
			draw_rect(Rect2(c + Vector2(k * 0.15, -k * 0.7), Vector2(k * 0.2, k * 0.2)), glow)
			draw_line(c + Vector2(k * 0.5, k * 0.6), c + Vector2(k * 1.2, k * 0.2), col2, 4.0, true)
		"golem":
			draw_rect(Rect2(c + Vector2(-k * 0.9, -k * 0.5), Vector2(k * 1.8, k * 1.5)), col)
			draw_rect(Rect2(c + Vector2(-k * 0.5, -k * 1.2), Vector2(k, k * 0.7)), col * 1.1)
			draw_rect(Rect2(c + Vector2(-k * 1.3, -k * 0.4), Vector2(k * 0.4, k * 1.1)), col * 0.8)
			draw_rect(Rect2(c + Vector2(k * 0.9, -k * 0.4), Vector2(k * 0.4, k * 1.1)), col * 0.8)
			draw_rect(Rect2(c + Vector2(-k * 0.3, -k * 0.95), Vector2(k * 0.2, k * 0.15)), glow)
			draw_rect(Rect2(c + Vector2(k * 0.1, -k * 0.95), Vector2(k * 0.2, k * 0.15)), glow)
			draw_rect(Rect2(c + Vector2(-k * 0.6, -k * 0.5), Vector2(k * 1.2, k * 0.2)), col2)
		"orb":
			draw_circle(c, k * 0.95, Color(glow.r, glow.g, glow.b, 0.25 * a))
			draw_circle(c, k * 0.65, col)
			draw_circle(c, k * 0.35, col2)
			draw_circle(c + Vector2(-k * 0.2, -k * 0.05), k * 0.1, Color(1, 1, 1, a))
			draw_circle(c + Vector2(k * 0.2, -k * 0.05), k * 0.1, Color(1, 1, 1, a))
			for i in 3:
				var ang := _t * 2.0 + TAU * float(i) / 3.0
				draw_rect(Rect2(c + Vector2(cos(ang), sin(ang)) * k * 1.1 - Vector2(3, 3), Vector2(6, 6)), glow)
		"drake":
			draw_rect(Rect2(c + Vector2(-k * 0.9, -k * 0.2), Vector2(k * 1.5, k * 0.8)), col)
			draw_rect(Rect2(c + Vector2(k * 0.5, -k * 0.8), Vector2(k * 0.9, k * 0.65)), col)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-k * 0.3, -k * 0.2), c + Vector2(-k * 0.9, -k * 1.2 + sin(_t * 5.0) * k * 0.15), c + Vector2(k * 0.2, -k * 0.2)]), col2)
			draw_rect(Rect2(c + Vector2(k * 1.3, -k * 0.55), Vector2(k * 0.35, k * 0.25)), col2)
			draw_line(c + Vector2(-k * 0.9, k * 0.3), c + Vector2(-k * 1.5, k * 0.7), col, 6.0, true)
			draw_rect(Rect2(c + Vector2(k * 0.95, -k * 0.65), Vector2(k * 0.15, k * 0.15)), glow)
			draw_rect(Rect2(c + Vector2(-k * 0.5, k * 0.5), Vector2(k * 0.25, k * 0.5)), col2)
			draw_rect(Rect2(c + Vector2(k * 0.2, k * 0.5), Vector2(k * 0.25, k * 0.5)), col2)
		"hydra":
			draw_rect(Rect2(c + Vector2(-k * 0.9, k * 0.1), Vector2(k * 1.8, k * 0.8)), col)
			for i in 3:
				var hx := (float(i) - 1.0) * k * 0.8
				draw_line(c + Vector2(hx * 0.5, k * 0.1), c + Vector2(hx, -k * 0.7 + sin(_t * 3.0 + float(i)) * 3.0), col2, 6.0, true)
				draw_rect(Rect2(c + Vector2(hx - k * 0.22, -k * 1.1 + sin(_t * 3.0 + float(i)) * 3.0), Vector2(k * 0.44, k * 0.4)), col)
				draw_rect(Rect2(c + Vector2(hx - k * 0.1, -k * 0.98 + sin(_t * 3.0 + float(i)) * 3.0), Vector2(k * 0.2, k * 0.1)), glow)
	var f := ThemeDB.fallback_font
	draw_string(f, Vector2(5, s.y - 5), VCDefs.rarity_name(int(d["rarity"])).substr(0, 4).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(rc.r, rc.g, rc.b, 0.9))

func _draw_egg() -> void:
	var s := size
	var ec: Color = VCPets.EGGS[egg_tier]["color"]
	var c := s * 0.5 + Vector2(sin(_t * 2.2) * 1.5, 0)
	var pts := PackedVector2Array()
	for i in 24:
		var ang := TAU * float(i) / 24.0
		pts.append(c + Vector2(cos(ang) * s.x * 0.24, sin(ang) * s.y * 0.32 * (1.0 + 0.1 * (-sin(ang)))))
	draw_colored_polygon(pts, ec.darkened(0.25))
	draw_colored_polygon(pts, Color(ec.r, ec.g, ec.b, 0.35))
	draw_circle(c + Vector2(-s.x * 0.06, -s.y * 0.1), s.x * 0.05, ec.lightened(0.5))
	draw_circle(c + Vector2(s.x * 0.08, s.y * 0.07), s.x * 0.04, ec.lightened(0.4))
	draw_circle(c + Vector2(-s.x * 0.02, s.y * 0.15), s.x * 0.03, ec.lightened(0.6))
	draw_rect(Rect2(Vector2.ZERO, s), ec, false, 2.0)
