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


# ---------------------------------------------------------------- polished nine-patch skins
static var _skins: Dictionary = {}

## A rounded, softly shaded nine-patch drawn in code (gradient fill, light rim, dark base edge, optional glow).
## Cached per colour set so each look is only built once.
static func skin(top: Color, bottom: Color, border: Color, radius: int = 14, glow: Color = Color(0, 0, 0, 0), pad_h: float = 16.0, pad_v: float = 9.0, rim: float = 0.22) -> StyleBoxTexture:
	var key := "%s|%s|%s|%d|%s|%.0f|%.0f|%.2f" % [top.to_html(true), bottom.to_html(true), border.to_html(true), radius, glow.to_html(true), pad_h, pad_v, rim]
	var tex: ImageTexture
	if _skins.has(key):
		tex = _skins[key]
	else:
		tex = ImageTexture.create_from_image(_skin_image(top, bottom, border, radius, glow, rim))
		_skins[key] = tex
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	var m := float(radius) + 6.0
	sb.texture_margin_left = m
	sb.texture_margin_right = m
	sb.texture_margin_top = m
	sb.texture_margin_bottom = m
	sb.content_margin_left = pad_h
	sb.content_margin_right = pad_h
	sb.content_margin_top = pad_v
	sb.content_margin_bottom = pad_v
	# the glow lives outside the box, so draw the texture a little larger than the control
	var e := 0.0 if glow.a <= 0.01 else 6.0
	sb.expand_margin_left = e
	sb.expand_margin_right = e
	sb.expand_margin_top = e
	sb.expand_margin_bottom = e
	return sb

static func _skin_image(top: Color, bottom: Color, border: Color, radius: int, glow: Color, rim: float) -> Image:
	var n := (radius + 6) * 2 + 8
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var pad := 6.0 if glow.a > 0.01 else 0.0
	var x0 := pad
	var y0 := pad
	var x1 := float(n) - pad
	var y1 := float(n) - pad
	var r := float(radius)
	var cxm := (x0 + x1) * 0.5
	var cym := (y0 + y1) * 0.5
	var hw := (x1 - x0) * 0.5
	var hh := (y1 - y0) * 0.5
	for y in n:
		for x in n:
			var px := float(x) + 0.5 - cxm
			var py := float(y) + 0.5 - cym
			var qx := absf(px) - (hw - r)
			var qy := absf(py) - (hh - r)
			var d := Vector2(maxf(qx, 0.0), maxf(qy, 0.0)).length() + minf(maxf(qx, qy), 0.0) - r
			var col := Color(0, 0, 0, 0)
			if d > 0.0:
				if glow.a > 0.01 and d < pad:
					var g := 1.0 - d / pad
					col = Color(glow.r, glow.g, glow.b, glow.a * g * g)
			else:
				var t := clampf((float(y) - y0) / maxf(y1 - y0, 1.0), 0.0, 1.0)
				var fill := top.lerp(bottom, t)
				# border band (2px) fading with the top highlight
				var edge := clampf(1.0 + d / 2.0, 0.0, 1.0)      # 1 at the very edge .. 0 two px inside
				var bc := border
				if t < 0.5:
					bc = border.lerp(Color(1, 1, 1, border.a), rim * (1.0 - t * 2.0))
				else:
					bc = border.darkened(0.25 * (t - 0.5) * 2.0)
				col = fill.lerp(bc, edge)
				# one-pixel inner highlight under the top edge
				if t < 0.18 and d < -2.0 and d > -3.5:
					col = col.lerp(Color(1, 1, 1, col.a), 0.10)
				col.a = maxf(col.a, 0.0)
				# soften the edge (anti-alias)
				col.a *= clampf(0.5 - d, 0.0, 1.0)
			img.set_pixel(x, y, col)
	return img

static func panel_skin(bg: Color, border: Color) -> StyleBoxTexture:
	return skin(bg.lightened(0.07), bg.darkened(0.12), border, 16, Color(border.r, border.g, border.b, 0.28), 14.0, 9.0, 0.16)

## Gold-edged call-to-action look (used for PLAY and other primary buttons).
static func make_primary(b: Button) -> void:
	var top := Color(0.55, 0.28, 0.98)
	var bot := Color(0.30, 0.10, 0.62)
	var edge := Color(1.0, 0.82, 0.45)
	b.add_theme_stylebox_override("normal", skin(top, bot, edge, 14, Color(0.7, 0.4, 1.0, 0.35), 16.0, 9.0, 0.3))
	b.add_theme_stylebox_override("hover", skin(top.lightened(0.15), bot.lightened(0.1), Color(1, 0.92, 0.65), 14, Color(0.85, 0.55, 1.0, 0.55), 16.0, 9.0, 0.3))
	b.add_theme_stylebox_override("pressed", skin(bot, top.darkened(0.2), edge, 14, Color(0.7, 0.4, 1.0, 0.2), 16.0, 9.0, 0.1))
	b.add_theme_color_override("font_color", Color(1, 0.97, 0.9))
	b.add_theme_color_override("font_hover_color", Color.WHITE)

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
	t.set_stylebox("normal", "Button", skin(Color(0.16, 0.09, 0.28, 0.97), Color(0.08, 0.045, 0.15, 0.97), Color(0.45, 0.25, 0.8), 12, Color(0, 0, 0, 0), 16.0, 9.0, 0.22))
	t.set_stylebox("hover", "Button", skin(Color(0.26, 0.14, 0.44, 0.98), Color(0.13, 0.07, 0.24, 0.98), Color(0.75, 0.48, 1.0), 12, Color(0.7, 0.4, 1.0, 0.4), 16.0, 9.0, 0.3))
	t.set_stylebox("pressed", "Button", skin(Color(0.2, 0.09, 0.36, 1.0), Color(0.36, 0.17, 0.62, 1.0), Color(0.95, 0.75, 1.0), 12, Color(0, 0, 0, 0), 16.0, 9.0, 0.1))
	t.set_stylebox("disabled", "Button", skin(Color(0.1, 0.08, 0.14, 0.85), Color(0.07, 0.055, 0.1, 0.85), Color(0.22, 0.18, 0.3), 12, Color(0, 0, 0, 0), 16.0, 9.0, 0.0))
	t.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), Color(0.9, 0.7, 1.0), 10, 2, 16))
	t.set_stylebox("panel", "PanelContainer", panel_skin(Color(0.06, 0.035, 0.11, 0.96), Color(0.38, 0.2, 0.66)))
	t.set_stylebox("panel", "Panel", panel_skin(Color(0.06, 0.035, 0.11, 0.96), Color(0.38, 0.2, 0.66)))
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

## Highlights a tab button as the current one (bright fill + white text) without disabling it.
static func mark_tab(b: Button, active: bool) -> void:
	for sb in ["normal", "hover", "pressed", "focus"]:
		b.remove_theme_stylebox_override(sb)
	b.remove_theme_color_override("font_color")
	b.remove_theme_color_override("font_hover_color")
	if active:
		var on := skin(Color(0.58, 0.3, 0.98), Color(0.32, 0.13, 0.64), Color(1.0, 0.88, 1.0), 12, Color(0.75, 0.45, 1.0, 0.5), 16.0, 9.0, 0.35)
		for sb in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(sb, on)
		b.add_theme_color_override("font_color", Color.WHITE)
		b.add_theme_color_override("font_hover_color", Color.WHITE)

static func panel(bg: Color = Color(0.06, 0.035, 0.11, 0.96), border: Color = Color(0.35, 0.18, 0.62)) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", panel_skin(bg, border))
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

## Controls parented directly to a CanvasLayer do not resolve anchors (their size stays 0), so
## full-screen overlays are sized to the viewport by hand and kept in sync.
static func fit_to_viewport(c: Control) -> void:
	var fit := func():
		if is_instance_valid(c) and c.is_inside_tree():
			c.position = Vector2.ZERO
			c.size = c.get_viewport_rect().size
	fit.call()
	c.get_viewport().size_changed.connect(fit)
	c.tree_exiting.connect(func():
		if c.get_viewport() != null and c.get_viewport().size_changed.is_connected(fit):
			c.get_viewport().size_changed.disconnect(fit))

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
