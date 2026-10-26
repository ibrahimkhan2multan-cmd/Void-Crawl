class_name VCItemIcon
extends Control
## Square slot that draws an item as a simple vector pictogram, framed in its rarity colour.

signal tapped(icon)

var item: Dictionary = {}
var slot_hint := -1                 # for empty equipment slots: which silhouette to show
var selected := false
var tag := {}                       # arbitrary data the owner attaches (index, slot...)
var badge := ""                     # e.g. "E" for equipped

func _init() -> void:
	custom_minimum_size = Vector2(76, 76)
	mouse_filter = Control.MOUSE_FILTER_STOP

func set_item(it: Dictionary) -> void:
	item = it
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		tapped.emit(self)
		accept_event()

func _draw() -> void:
	var s := size
	var has := not item.is_empty()
	var rar := int(item.get("rarity", 0)) if has else 0
	var rc := VCDefs.rarity_color(rar) if has else Color(0.3, 0.22, 0.5)
	draw_rect(Rect2(Vector2.ZERO, s), Color(0.04, 0.02, 0.08, 0.95))
	if has and rar >= 2:
		draw_rect(Rect2(Vector2(3, 3), s - Vector2(6, 6)), Color(rc.r, rc.g, rc.b, 0.12 + 0.05 * float(rar)))
	draw_rect(Rect2(Vector2.ZERO, s), rc if not selected else Color.WHITE, false, 3.0 if selected else 2.0)
	var kind := ""
	var col := Color(0.4, 0.33, 0.55, 0.5)
	if has:
		kind = String(VCItems.BASES[item["base"]]["kind"])
		col = VCItems.base_color(item)
	else:
		match slot_hint:
			0: kind = "sword"
			1: kind = "helm"
			2: kind = "armor"
			3: kind = "trinket"
			4: kind = "boots"
	_draw_glyph(kind, col, rc, has)
	if badge != "":
		var f := ThemeDB.fallback_font
		draw_string(f, Vector2(6, s.y - 6), badge, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.9))

func _draw_glyph(kind: String, col: Color, accent: Color, solid: bool) -> void:
	var c := size * 0.5
	var k := minf(size.x, size.y) * 0.34
	var dim := 1.0 if solid else 0.55
	col.a = dim
	match kind:
		"sword":
			draw_line(c + Vector2(-k * 0.9, k * 0.9), c + Vector2(k * 0.9, -k * 0.9), col, 7.0, true)
			draw_line(c + Vector2(-k * 0.55, k * 0.1), c + Vector2(-k * 0.05, k * 0.6), accent, 5.0, true)
			draw_line(c + Vector2(-k * 0.9, k * 0.9), c + Vector2(-k * 1.1, k * 1.1), Color(0.5, 0.35, 0.25, dim), 6.0, true)
		"axe":
			draw_line(c + Vector2(-k * 0.8, k * 1.0), c + Vector2(k * 0.5, -k * 0.9), Color(0.5, 0.35, 0.25, dim), 5.0, true)
			draw_colored_polygon(PackedVector2Array([c + Vector2(k * 0.1, -k * 1.0), c + Vector2(k * 1.0, -k * 0.5), c + Vector2(k * 0.9, k * 0.2), c + Vector2(k * 0.3, -k * 0.2)]), col)
		"dagger":
			draw_line(c + Vector2(-k * 0.6, k * 0.8), c + Vector2(k * 0.5, -k * 0.7), col, 6.0, true)
			draw_line(c + Vector2(-k * 0.55, k * 0.15), c + Vector2(-k * 0.05, k * 0.65), accent, 4.0, true)
		"bow":
			draw_arc(c + Vector2(-k * 0.3, 0), k * 1.1, -1.1, 1.1, 18, col, 5.0, true)
			draw_line(c + Vector2(-k * 0.3 + cos(-1.1) * k * 1.1, sin(-1.1) * k * 1.1), c + Vector2(-k * 0.3 + cos(1.1) * k * 1.1, sin(1.1) * k * 1.1), Color(0.9, 0.9, 1.0, dim), 2.0, true)
			draw_line(c + Vector2(-k * 0.2, 0), c + Vector2(k * 1.1, 0), accent, 3.0, true)
		"spear":
			draw_line(c + Vector2(-k * 1.0, k * 1.0), c + Vector2(k * 0.7, -k * 0.7), Color(0.5, 0.35, 0.25, dim), 5.0, true)
			draw_colored_polygon(PackedVector2Array([c + Vector2(k * 0.55, -k * 0.5), c + Vector2(k * 1.1, -k * 1.1), c + Vector2(k * 0.5, -k * 0.95), c + Vector2(k * 0.3, -k * 0.65)]), col)
		"hammer":
			draw_line(c + Vector2(-k * 0.8, k * 1.0), c + Vector2(k * 0.4, -k * 0.6), Color(0.5, 0.35, 0.25, dim), 5.0, true)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-k * 0.1, -k * 0.5), c + Vector2(k * 0.7, -k * 1.1), c + Vector2(k * 1.1, -k * 0.5), c + Vector2(k * 0.4, k * 0.1)]), col)
		"crossbow":
			draw_line(c + Vector2(-k * 0.2, -k * 1.0), c + Vector2(-k * 0.2, k * 1.0), col, 5.0, true)
			draw_line(c + Vector2(-k * 0.2, -k * 1.0), c + Vector2(k * 0.7, -k * 0.2), Color(0.9, 0.9, 1.0, dim), 2.0, true)
			draw_line(c + Vector2(-k * 0.2, k * 1.0), c + Vector2(k * 0.7, k * 0.2), Color(0.9, 0.9, 1.0, dim), 2.0, true)
			draw_line(c + Vector2(-k * 0.9, 0), c + Vector2(k * 1.0, 0), accent, 4.0, true)
		"staff":
			draw_line(c + Vector2(-k * 0.9, k * 1.0), c + Vector2(k * 0.5, -k * 0.7), Color(0.5, 0.35, 0.25, dim), 5.0, true)
			draw_circle(c + Vector2(k * 0.7, -k * 0.9), k * 0.35, col)
			draw_arc(c + Vector2(k * 0.7, -k * 0.9), k * 0.55, 0, TAU, 16, accent, 2.0, true)
		"helm":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-k, k * 0.7), c + Vector2(-k, -k * 0.2), c + Vector2(-k * 0.6, -k * 0.9), c + Vector2(k * 0.6, -k * 0.9), c + Vector2(k, -k * 0.2), c + Vector2(k, k * 0.7)]), col)
			draw_rect(Rect2(c + Vector2(-k * 0.65, -k * 0.1), Vector2(k * 1.3, k * 0.3)), Color(0.02, 0.0, 0.05, dim))
			draw_line(c + Vector2(0, -k * 0.9), c + Vector2(0, -k * 0.2), accent, 3.0, true)
		"armor":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-k * 1.0, -k * 0.8), c + Vector2(-k * 0.4, -k * 1.0), c + Vector2(k * 0.4, -k * 1.0), c + Vector2(k * 1.0, -k * 0.8), c + Vector2(k * 0.8, k * 1.0), c + Vector2(-k * 0.8, k * 1.0)]), col)
			draw_line(c + Vector2(0, -k * 0.9), c + Vector2(0, k * 0.9), accent, 3.0, true)
			draw_rect(Rect2(c + Vector2(-k * 0.8, k * 0.2), Vector2(k * 1.6, k * 0.18)), Color(accent.r, accent.g, accent.b, dim * 0.8))
		"boots":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-k * 0.5, -k * 0.9), c + Vector2(k * 0.3, -k * 0.9), c + Vector2(k * 0.3, k * 0.1), c + Vector2(k * 1.0, k * 0.35), c + Vector2(k * 1.0, k * 0.9), c + Vector2(-k * 0.5, k * 0.9)]), col)
			draw_rect(Rect2(c + Vector2(-k * 0.5, k * 0.65), Vector2(k * 1.5, k * 0.25)), Color(accent.r, accent.g, accent.b, dim))
			draw_line(c + Vector2(-k * 0.5, -k * 0.55), c + Vector2(k * 0.3, -k * 0.55), accent, 3.0, true)
		"trinket":
			draw_arc(c, k * 0.9, 0, TAU, 24, Color(0.8, 0.7, 0.4, dim), 4.0, true)
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -k * 0.6), c + Vector2(k * 0.5, 0), c + Vector2(0, k * 0.6), c + Vector2(-k * 0.5, 0)]), Color(col.r, col.g, col.b, dim) if solid else col)
