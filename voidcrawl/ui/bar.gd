class_name VCBar
extends Control
## Stylised progress bar (health, xp, boss). Smoothly chases its target value and shows a
## trailing "damage" ghost segment so big hits are readable at a glance.

var value := 1.0
var max_value := 1.0
var color := Color(0.88, 0.19, 0.35)
var back_color := Color(0.06, 0.03, 0.1, 0.9)
var edge_color := Color(0.6, 0.35, 1.0, 0.9)
var text := "":
	set(v):
		if v != text:
			text = v
			queue_redraw()
var font_size := 20
var markers: Array = []          # fractions where thin phase ticks are drawn
var show_ghost := true

var _shown := 1.0
var _ghost := 1.0

func set_values(v: float, m: float) -> void:
	var nm := maxf(m, 0.001)
	if v != value or nm != max_value:
		value = v
		max_value = nm
		queue_redraw()

func snap() -> void:
	_shown = clampf(value / max_value, 0.0, 1.0)
	_ghost = _shown
	queue_redraw()

func _process(delta: float) -> void:
	var target := clampf(value / max_value, 0.0, 1.0)
	var prev := _shown
	_shown = lerpf(_shown, target, clampf(delta * 14.0, 0.0, 1.0))
	if absf(_shown - target) < 0.002:
		_shown = target
	if target >= _ghost:
		_ghost = target
	else:
		_ghost = move_toward(_ghost, target, delta * 0.35) if _ghost > target else target
	if prev != _shown or _ghost != _shown:
		queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED or what == NOTIFICATION_VISIBILITY_CHANGED:
		queue_redraw()

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, back_color)
	if show_ghost and _ghost > _shown:
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * _ghost, size.y)), Color(1.0, 0.85, 0.9, 0.55))
	draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * _shown, size.y)), color)
	draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * _shown, size.y * 0.42)), Color(1, 1, 1, 0.14))
	for m in markers:
		var x: float = size.x * float(m)
		draw_line(Vector2(x, 0), Vector2(x, size.y), Color(1, 1, 1, 0.55), 2.0)
	draw_rect(r, edge_color, false, 2.0)
	if text != "":
		var f := ThemeDB.fallback_font
		var sz := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var pos := Vector2((size.x - sz.x) * 0.5, (size.y + sz.y * 0.62) * 0.5)
		draw_string(f, pos + Vector2(1.5, 1.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0, 0, 0, 0.8))
		draw_string(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1, 1, 1, 0.97))
