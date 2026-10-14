class_name VCPauseMenu
extends Control
## Pause overlay. Emits intent signals; the mission decides what each one does.

signal resume
signal open_pack
signal open_settings
signal quit_to_menu

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
	var items := [["RESUME", "resume"], ["PACK & HERO", "pack"], ["SETTINGS", "settings"], ["SAVE & QUIT", "quit"]]
	for it in items:
		var b := VCUI.button(String(it[0]), Vector2(380, 66), 26)
		b.pressed.connect(_pressed.bind(String(it[1])))
		v.add_child(b)

func _pressed(id: String) -> void:
	match id:
		"resume": resume.emit()
		"pack": open_pack.emit()
		"settings": open_settings.emit()
		"quit": quit_to_menu.emit()

func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("vc_pause") or event.is_action_pressed("ui_cancel")):
		get_viewport().set_input_as_handled()
		resume.emit()
