class_name VCUI
extends RefCounted
## Shared look for every VOIDCRAWL screen: black stone panels, violet edges, big touch targets.

static var _theme: Theme = null

static func box(bg: Color, border: Color, radius: int = 10, border_w: int = 2, pad: int = 10) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = pad * 0.6
	sb.content_margin_bottom = pad * 0.6
	return sb

static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font_size = 22
	t.set_color("font_color", "Label", VCDefs.COL_TEXT)
	t.set_color("font_color", "Button", VCDefs.COL_TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(0.5, 0.45, 0.6))
	t.set_color("font_focus_color", "Button", Color.WHITE)
	t.set_font_size("font_size", "Button", 26)
	t.set_stylebox("normal", "Button", box(Color(0.1, 0.06, 0.18, 0.95), Color(0.42, 0.22, 0.75), 10, 2, 16))
	t.set_stylebox("hover", "Button", box(Color(0.17, 0.09, 0.3, 0.98), Color(0.7, 0.4, 1.0), 10, 2, 16))
	t.set_stylebox("pressed", "Button", box(Color(0.32, 0.14, 0.55, 1.0), Color(0.9, 0.7, 1.0), 10, 2, 16))
	t.set_stylebox("disabled", "Button", box(Color(0.08, 0.06, 0.12, 0.8), Color(0.2, 0.16, 0.28), 10, 2, 16))
	t.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), Color(0.9, 0.7, 1.0), 10, 2, 16))
	t.set_stylebox("panel", "PanelContainer", box(Color(0.06, 0.035, 0.11, 0.96), Color(0.35, 0.18, 0.62), 14, 2, 14))
	t.set_stylebox("panel", "Panel", box(Color(0.06, 0.035, 0.11, 0.96), Color(0.35, 0.18, 0.62), 14, 2, 14))
	t.set_stylebox("normal", "LineEdit", box(Color(0.05, 0.03, 0.09), Color(0.35, 0.18, 0.62), 8, 2, 10))
	t.set_stylebox("normal", "OptionButton", box(Color(0.1, 0.06, 0.18), Color(0.42, 0.22, 0.75), 8, 2, 12))
	t.set_stylebox("hover", "OptionButton", box(Color(0.17, 0.09, 0.3), Color(0.7, 0.4, 1.0), 8, 2, 12))
	t.set_stylebox("pressed", "OptionButton", box(Color(0.17, 0.09, 0.3), Color(0.7, 0.4, 1.0), 8, 2, 12))
	var grab := box(Color(0.1, 0.06, 0.18), Color(0.3, 0.16, 0.55), 6, 1, 4)
	t.set_stylebox("slider", "HSlider", box(Color(0.1, 0.06, 0.18), Color(0.25, 0.14, 0.45), 6, 1, 4))
	t.set_stylebox("grabber_area", "HSlider", box(Color(0.5, 0.25, 0.9), Color(0.5, 0.25, 0.9), 6, 0, 4))
	t.set_stylebox("grabber_area_highlight", "HSlider", box(Color(0.65, 0.4, 1.0), Color(0.65, 0.4, 1.0), 6, 0, 4))
	t.set_constant("separation", "HBoxContainer", 12)
	t.set_constant("separation", "VBoxContainer", 10)
	t.set_stylebox("normal", "CheckButton", StyleBoxEmpty.new())
	t.set_stylebox("pressed", "CheckButton", StyleBoxEmpty.new())
	t.set_stylebox("hover", "CheckButton", StyleBoxEmpty.new())
	t.set_stylebox("focus", "CheckButton", StyleBoxEmpty.new())
	t.set_stylebox("scroll", "VScrollBar", box(Color(0.08, 0.05, 0.14), Color(0.08, 0.05, 0.14), 6, 0, 0))
	t.set_stylebox("grabber", "VScrollBar", box(Color(0.4, 0.2, 0.7), Color(0.4, 0.2, 0.7), 6, 0, 0))
	_theme = t
	return t

static func label(text: String, size: int = 22, color: Color = VCDefs.COL_TEXT, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align as HorizontalAlignment
	return l

static func button(text: String, min_size: Vector2 = Vector2(220, 64), font: int = 26) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", font)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func(): VC.play_sfx("click", -4.0))
	return b

static func panel(bg: Color = Color(0.06, 0.035, 0.11, 0.96), border: Color = Color(0.35, 0.18, 0.62)) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(bg, border, 14, 2, 14))
	return p

static func hbox(sep: int = 12) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h

static func vbox(sep: int = 10) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v

static func spacer(h: int = 8) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c

## Safe-area margins in virtual pixels (notches / rounded corners). Never less than `minimum`.
static func safe_margins(viewport: Viewport, minimum: float = 14.0) -> Dictionary:
	var m := {"left": minimum, "right": minimum, "top": minimum, "bottom": minimum}
	if not OS.has_feature("mobile"):
		return m
	var win := DisplayServer.window_get_size()
	var safe := DisplayServer.get_display_safe_area()
	if win.x <= 0 or win.y <= 0 or safe.size.x <= 0:
		return m
	var vs := viewport.get_visible_rect().size
	var sx := vs.x / float(win.x)
	var sy := vs.y / float(win.y)
	m["left"] = maxf(minimum, float(safe.position.x) * sx)
	m["top"] = maxf(minimum, float(safe.position.y) * sy)
	m["right"] = maxf(minimum, float(win.x - safe.end.x) * sx)
	m["bottom"] = maxf(minimum, float(win.y - safe.end.y) * sy)
	return m

## Pretty "stat line" colour: green for better, red for worse, dim for equal.
static func delta_color(d: float) -> Color:
	if d > 0.001:
		return VCDefs.COL_GOOD
	if d < -0.001:
		return VCDefs.COL_BAD
	return VCDefs.COL_TEXT_DIM
