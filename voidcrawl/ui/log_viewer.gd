class_name VCLogViewer
extends RefCounted
## Full-screen, selectable crash/log report with COPY and SHARE (e-mail) buttons.
## The text is also readable on screen so it can simply be photographed or screenshotted.

static func make() -> Control:
	var layer := Control.new()
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.theme = VCUI.theme()
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0.03, 0.97)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	var mc := MarginContainer.new()
	mc.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		mc.add_theme_constant_override("margin_" + side, 20)
	layer.add_child(mc)
	var v := VCUI.vbox(8)
	mc.add_child(v)
	var txt := VCCrashGuard.report_text()
	var head := VCUI.label("CRASH REPORT  -  screenshot this screen or use COPY / SHARE", 20, Color(1.0, 0.8, 0.5))
	v.add_child(head)
	var te := TextEdit.new()
	te.text = txt
	te.editable = false
	te.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	te.size_flags_vertical = Control.SIZE_EXPAND_FILL
	te.add_theme_font_size_override("font_size", 14)
	v.add_child(te)
	var row := VCUI.hbox(10)
	v.add_child(row)
	var copy := VCUI.button("COPY", Vector2(200, 54), 22)
	copy.pressed.connect(func():
		DisplayServer.clipboard_set(txt)
		te.select_all()
		te.grab_focus()
		copy.text = "COPIED?")
	row.add_child(copy)
	var share := VCUI.button("SHARE (EMAIL)", Vector2(260, 54), 22)
	share.pressed.connect(func():
		var body := txt.left(1800)
		OS.shell_open("mailto:?subject=" + "VOIDBORN crash report".uri_encode() + "&body=" + body.uri_encode()))
	row.add_child(share)
	var back := VCUI.button("CLOSE", Vector2(200, 54), 22)
	back.pressed.connect(layer.queue_free)
	row.add_child(back)
	return layer
