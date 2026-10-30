class_name VCPauseMenu
extends Control
## Pause overlay. Emits intent signals; the mission decides what each one does.

signal resume
signal open_pack
signal open_howto
signal open_settings
signal quit_to_menu
signal open_tester

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = VCUI.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.03, 0.75)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(c)
	var panel := VCUI.panel()
	c.add_child(panel)
	var v := VCUI.vbox(12)
	v.custom_minimum_size = Vector2(380, 0)
	panel.add_child(v)
	v.add_child(VCUI.label("PAUSED", 38, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
	var items := [["RESUME", "resume"], ["PACK & HERO", "pack"], ["HOW TO PLAY", "howto"], ["SETTINGS", "settings"], ["SAVE & QUIT", "quit"]]
	for it in items:
		var b := VCUI.button(String(it[0]), Vector2(380, 58), 26)
		b.pressed.connect(_pressed.bind(String(it[1])))
		v.add_child(b)
	if VCTester.unlocked():
		var tb := VCUI.button("TESTER", Vector2(380, 50), 22)
		tb.add_theme_color_override("font_color", Color(0.4, 1.0, 0.8))
		tb.pressed.connect(func(): open_tester.emit())
		v.add_child(tb)
	# buttons added by mods (each opens a message or a draggable menu window)
	var mb := VCMods.menu_buttons("pause")
	if not mb.is_empty():
		v.add_child(VCUI.label("FROM MODS", 14, Color(0.6, 0.5, 0.85), HORIZONTAL_ALIGNMENT_CENTER))
		for bd in mb:
			var bc: Color = bd["color"]
			var mbn := VCUI.button(String(bd["label"]), Vector2(380, 50), 22)
			mbn.add_theme_color_override("font_color", bc.lerp(Color.WHITE, 0.55))
			mbn.add_theme_stylebox_override("normal", VCUI.box(Color(0.06, 0.035, 0.11, 0.92), bc, 10, 2, 8))
			mbn.pressed.connect(func(): VCModWindow.run_action(self, bd["action"], "pause", null, String(bd["label"])))
			v.add_child(mbn)

func _pressed(id: String) -> void:
	match id:
		"resume": resume.emit()
		"pack": open_pack.emit()
		"howto": open_howto.emit()
		"settings": open_settings.emit()
		"quit": quit_to_menu.emit()

func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("vc_pause") or event.is_action_pressed("ui_cancel")):
		get_viewport().set_input_as_handled()
		resume.emit()
