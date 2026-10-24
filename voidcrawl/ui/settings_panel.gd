class_name VCSettingsPanel
extends Control
## Audio, graphics presets and touch-layout settings. Every control writes to VCSettings,
## saves, and applies immediately, so the effect is visible/audible behind the panel.

signal closed
signal applied

var _scroll_box: VBoxContainer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = VCUI.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.03, 0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var m := VCUI.safe_margins(get_viewport(), 20.0)
	var panel := VCUI.panel()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = float(m["left"]) + 60.0
	panel.offset_right = -float(m["right"]) - 60.0
	panel.offset_top = float(m["top"])
	panel.offset_bottom = -float(m["bottom"])
	add_child(panel)
	var root := VCUI.vbox(8)
	panel.add_child(root)
	var head := VCUI.hbox(10)
	root.add_child(head)
	var t := VCUI.label("SETTINGS", 32, Color.WHITE)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var done := VCUI.button("DONE", Vector2(170, 56), 24)
	done.pressed.connect(_close)
	head.add_child(done)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	_scroll_box = VCUI.vbox(6)
	_scroll_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_scroll_box)
	_build()

func _close() -> void:
	VCSettings.save_settings()
	VC.play_sfx("back", -4.0)
	closed.emit()

func _section(title: String) -> void:
	_scroll_box.add_child(VCUI.spacer(6))
	_scroll_box.add_child(VCUI.label(title, 22, VCDefs.COL_VIOLET))

func _slider(label: String, key: String, lo: float, hi: float, step: float, fmt: String = "%.0f%%", scale: float = 100.0) -> void:
	var h := VCUI.hbox(14)
	h.custom_minimum_size = Vector2(0, 48)
	var l := VCUI.label(label, 21, VCDefs.COL_TEXT)
	l.custom_minimum_size = Vector2(300, 0)
	h.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = float(VCSettings.get_value(key))
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.custom_minimum_size = Vector2(300, 36)
	h.add_child(s)
	var v := VCUI.label(fmt % (s.value * scale), 20, VCDefs.COL_TEXT_DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	v.custom_minimum_size = Vector2(80, 0)
	h.add_child(v)
	s.value_changed.connect(func(val: float):
		VCSettings.set_value(key, val)
		v.text = fmt % (val * scale)
		_apply())
	_scroll_box.add_child(h)

func _toggle(label: String, key: String) -> void:
	var h := VCUI.hbox(14)
	h.custom_minimum_size = Vector2(0, 48)
	var l := VCUI.label(label, 21, VCDefs.COL_TEXT)
	l.custom_minimum_size = Vector2(300, 0)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	var b := VCUI.button("", Vector2(150, 44), 20)
	b.text = "ON" if bool(VCSettings.get_value(key)) else "OFF"
	b.pressed.connect(func():
		var nv := not bool(VCSettings.get_value(key))
		VCSettings.set_value(key, nv)
		b.text = "ON" if nv else "OFF"
		_apply())
	h.add_child(b)
	_scroll_box.add_child(h)

func _choice(label: String, key: String, options: Array, values: Array) -> void:
	var h := VCUI.hbox(14)
	h.custom_minimum_size = Vector2(0, 52)
	var l := VCUI.label(label, 21, VCDefs.COL_TEXT)
	l.custom_minimum_size = Vector2(300, 0)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	var btns: Array = []
	for i in options.size():
		var b := VCUI.button(String(options[i]), Vector2(120, 46), 20)
		b.set_meta("val", values[i])
		h.add_child(b)
		btns.append(b)
	var refresh := func():
		for bb in btns:
			(bb as Button).disabled = (bb as Button).get_meta("val") == VCSettings.get_value(key)
	for bb in btns:
		(bb as Button).pressed.connect(func():
			VCSettings.set_value(key, (bb as Button).get_meta("val"))
			refresh.call()
			_apply())
	refresh.call()
	_scroll_box.add_child(h)

func _build() -> void:
	_section("AUDIO")
	_slider("Master volume", "master", 0.0, 1.0, 0.05)
	_slider("Music volume", "music", 0.0, 1.0, 0.05)
	_slider("Effects volume", "sfx", 0.0, 1.0, 0.05)
	_section("GRAPHICS")
	_choice("Quality preset", "quality", ["Low", "Medium", "High"], [0, 1, 2])
	_choice("Frame rate cap", "fps", ["30 FPS", "60 FPS"], [30, 60])
	_toggle("Show FPS counter", "show_fps")
	_toggle("Damage numbers", "damage_numbers")
	_slider("Screen shake", "screen_shake", 0.0, 1.5, 0.1)
	_scroll_box.add_child(VCUI.label("Low uses 3 lights, no fog and fewer particles. Use it if the game stutters.", 16, VCDefs.COL_TEXT_DIM))
	_section("CONTROLS")
	_toggle("Left-handed layout", "left_handed")
	_toggle("Floating joystick", "joy_floating")
	_slider("Joystick size", "joy_size", 0.7, 1.5, 0.05)
	_slider("Joystick dead zone", "joy_deadzone", 0.0, 0.4, 0.02)
	_slider("Button size", "btn_scale", 0.7, 1.4, 0.05)
	_slider("Button opacity", "btn_opacity", 0.3, 1.0, 0.05)
	_toggle("Vibration", "haptics")
	_section("CAMERA")
	_slider("Camera drag sensitivity", "cam_sens", 0.3, 2.5, 0.1, "%.1fx", 1.0)
	_slider("Camera distance", "cam_zoom", 0.7, 1.4, 0.05, "%.2fx", 1.0)
	_section("DIAGNOSTICS")
	var logb := VCUI.button("VIEW / COPY CRASH LOG", Vector2(360, 56), 22)
	logb.pressed.connect(_show_log)
	_scroll_box.add_child(logb)
	_scroll_box.add_child(VCUI.label("If the game closed by itself, open this, press COPY and send the text to the developer.", 16, VCDefs.COL_TEXT_DIM))
	var reset := VCUI.button("RESET TO DEFAULTS", Vector2(300, 56), 22)
	reset.pressed.connect(func():
		VCSettings.values = VCSettings.DEFAULTS.duplicate()
		_apply()
		for c in _scroll_box.get_children():
			c.queue_free()
		await get_tree().process_frame
		_build())
	_scroll_box.add_child(VCUI.spacer(10))
	_scroll_box.add_child(reset)

func _apply() -> void:
	VCSettings.apply(get_viewport())
	VCSettings.save_settings()
	applied.emit()

func _show_log() -> void:
	var layer := Control.new()
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.theme = VCUI.theme()
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0.03, 0.92)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	var mc := MarginContainer.new()
	mc.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		mc.add_theme_constant_override("margin_" + side, 24)
	layer.add_child(mc)
	var v := VCUI.vbox(8)
	mc.add_child(v)
	var txt := VCCrashGuard.report_text()
	var te := TextEdit.new()
	te.text = txt
	te.editable = false
	te.size_flags_vertical = Control.SIZE_EXPAND_FILL
	te.add_theme_font_size_override("font_size", 15)
	v.add_child(te)
	var row := VCUI.hbox(10)
	v.add_child(row)
	var copy := VCUI.button("COPY", Vector2(220, 56), 22)
	copy.pressed.connect(func(): DisplayServer.clipboard_set(txt); copy.text = "COPIED")
	row.add_child(copy)
	var back := VCUI.button("CLOSE", Vector2(220, 56), 22)
	back.pressed.connect(layer.queue_free)
	row.add_child(back)
	add_child(layer)
