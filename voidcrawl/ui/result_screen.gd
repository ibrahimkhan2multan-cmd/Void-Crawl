class_name VCResultScreen
extends Control
## Victory / defeat card. Buttons are supplied by the caller as [label, Callable] pairs.

func setup(title: String, title_color: Color, subtitle: String, lines: Array, buttons: Array) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = VCUI.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.03, 0.8)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(c)
	var panel := VCUI.panel(Color(0.05, 0.03, 0.1, 0.97), title_color.darkened(0.2))
	c.add_child(panel)
	var v := VCUI.vbox(8)
	v.custom_minimum_size = Vector2(560, 0)
	panel.add_child(v)
	var t := VCUI.label(title, 52, title_color, HORIZONTAL_ALIGNMENT_CENTER)
	t.add_theme_color_override("font_outline_color", Color(0.1, 0, 0.2))
	t.add_theme_constant_override("outline_size", 8)
	v.add_child(t)
	if subtitle != "":
		v.add_child(VCUI.label(subtitle, 22, VCDefs.COL_VIOLET, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(VCUI.spacer(6))
	for ln in lines:
		var h := VCUI.hbox(6)
		var l := VCUI.label(String(ln[0]), 22, VCDefs.COL_TEXT_DIM)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(l)
		var col: Color = ln[2] if ln.size() > 2 else VCDefs.COL_TEXT
		h.add_child(VCUI.label(String(ln[1]), 22, col, HORIZONTAL_ALIGNMENT_RIGHT))
		v.add_child(h)
	v.add_child(VCUI.spacer(10))
	for b in buttons:
		var btn := VCUI.button(String(b[0]), Vector2(560, 66), 26)
		btn.pressed.connect(b[1])
		v.add_child(btn)
