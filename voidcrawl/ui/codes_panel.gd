class_name VCCodesPanel
extends Control
## Enter a promo / easter-egg code. Works offline; each code is single-use per save.

signal closed

var _edit: LineEdit
var _result: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = VCUI.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.03, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(cc)
	var panel := VCUI.panel()
	cc.add_child(panel)
	var v := VCUI.vbox(12)
	v.custom_minimum_size = Vector2(640, 0)
	panel.add_child(v)
	v.add_child(VCUI.label("REDEEM CODE", 36, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
	var hint := VCUI.label("Enter a code to unlock rewards. Each code works once. Friends of Infinity Studios may know a secret one...", 18, VCDefs.COL_TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(hint)
	_edit = LineEdit.new()
	_edit.placeholder_text = "ENTER CODE"
	_edit.custom_minimum_size = Vector2(0, 64)
	_edit.add_theme_font_size_override("font_size", 28)
	_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_edit.max_length = 32
	_edit.text_submitted.connect(func(_t): _redeem())
	v.add_child(_edit)
	var go := VCUI.button("REDEEM", Vector2(640, 64), 26)
	go.pressed.connect(_redeem)
	v.add_child(go)
	_result = VCUI.label("", 20, VCDefs.COL_GOOD, HORIZONTAL_ALIGNMENT_CENTER)
	_result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result.custom_minimum_size = Vector2(620, 60)
	v.add_child(_result)
	var back := VCUI.button("BACK", Vector2(640, 60), 24)
	back.pressed.connect(func(): closed.emit())
	v.add_child(back)

func _redeem() -> void:
	var r := VCCodes.redeem(_edit.text, VC.profile)
	_result.text = String(r["msg"])
	_result.add_theme_color_override("font_color", VCDefs.COL_GOOD if bool(r["ok"]) else VCDefs.COL_BAD)
	if bool(r["ok"]):
		VC.play_sfx("levelup", -4.0)
		_edit.text = ""
		VC.notify_profile_changed()
		VC.save_now()
	else:
		VC.play_sfx("hurt", -10.0)
