class_name VCHowToPlay
extends Control
## Step-by-step controls tutorial. Draws the REAL on-screen controls (same layout/settings the
## player uses) and highlights one control per page with an explanation.

signal closed

const PAGES := [
	{"t": "MOVE", "target": "joy", "body": "Touch and drag on the left side of the screen to move. Push the stick all the way out to sprint."},
	{"t": "ATTACK", "target": "attack", "body": "HOLD to swing your weapon again and again. You can keep moving while you attack - strafe around enemies!"},
	{"t": "DODGE ROLL", "target": "dodge", "body": "Tap to roll away. You cannot be hit mid-roll. Use it to escape red danger zones."},
	{"t": "VOID NOVA", "target": "ability", "body": "A blast of void energy that hurts and pushes back everything near you. It needs time to recharge."},
	{"t": "HEALTH POTION", "target": "heal", "body": "Tap to heal. The number shows how many you carry. Shrines and drops refill them. Health also slowly regenerates when you stay out of combat."},
	{"t": "VOID BOMB", "target": "bomb", "body": "Throw a bomb: it lands, then explodes and damages enemies and breaks props. Great against crowds."},
	{"t": "USE", "target": "interact", "body": "This button appears next to chests, shrines and the Void Gate. Tap it to open chests, rest at shrines and leave the dungeon."},
	{"t": "PACK & PAUSE", "target": "hud", "body": "Top right: the backpack opens your gear, the pause button opens the menu. Equip armor, helms, weapons, trinkets and BOOTS (faster movement)."},
	{"t": "LOOK AROUND", "target": "cam", "body": "Drag on an empty part of the right side of the screen to rotate the camera."},
	{"t": "TIPS", "target": "", "body": "Break crates and barrels for coins and hearts. Locked rooms open when every enemy is dead. Rare loot shines with a coloured beam. Got a friend's secret code? Redeem it from CODES in the main menu."},
]

var _page := 0
var _touch: VCTouchControls
var _card: PanelContainer
var _title: Label
var _body: Label
var _count: Label
var _next: Button
var _prev: Button
var _t := 0.0
var _hl: Control

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_fit()
	get_viewport().size_changed.connect(_fit)
	theme = VCUI.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.03, 0.88)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	_touch = VCTouchControls.new()
	_touch.preview = true
	_touch.interact_prompt = "OPEN"
	_touch.set_anchors_preset(Control.PRESET_FULL_RECT)
	_touch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_touch)
	_touch.size = size
	_hl = Control.new()
	_hl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hl.draw.connect(_draw_highlight)
	add_child(_hl)
	_card = VCUI.panel(Color(0.07, 0.04, 0.13, 0.97), Color(0.7, 0.4, 1.0))
	add_child(_card)
	var v := VCUI.vbox(8)
	v.custom_minimum_size = Vector2(430, 0)
	_card.add_child(v)
	_count = VCUI.label("", 16, VCDefs.COL_TEXT_DIM)
	v.add_child(_count)
	_title = VCUI.label("", 34, VCDefs.COL_VIOLET)
	v.add_child(_title)
	_body = VCUI.label("", 21, VCDefs.COL_TEXT)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(430, 120)
	v.add_child(_body)
	var row := VCUI.hbox(10)
	v.add_child(row)
	_prev = VCUI.button("BACK", Vector2(120, 56), 22)
	_prev.pressed.connect(func(): _go(-1))
	row.add_child(_prev)
	_next = VCUI.button("NEXT", Vector2(150, 56), 22)
	_next.pressed.connect(func(): _go(1))
	row.add_child(_next)
	var skip := VCUI.button("SKIP", Vector2(120, 56), 20)
	skip.pressed.connect(_finish)
	row.add_child(skip)
	_show()

## Under a CanvasLayer anchors do not resolve, so size to the viewport by hand.
func _fit() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size
	if _touch != null:
		_touch.position = Vector2.ZERO
		_touch.size = size
		_touch._relayout()
	if _card != null:
		_place_card()

func _go(d: int) -> void:
	if _page + d >= PAGES.size():
		_finish()
		return
	_page = clampi(_page + d, 0, PAGES.size() - 1)
	_show()

func _finish() -> void:
	VCSettings.values["seen_howto"] = true
	VCSettings.save_settings()
	closed.emit()

func _target_pos(id: String) -> Vector2:
	match id:
		"joy": return _touch._joy_rest
		"hud":
			var a: Vector2 = _touch._hud_buttons["pause"]["c"]
			var b: Vector2 = _touch._hud_buttons["pack"]["c"]
			return (a + b) * 0.5
		"cam":
			var lh: bool = bool(VCSettings.get_value("left_handed"))
			return Vector2(size.x * (0.3 if lh else 0.62), size.y * 0.3)
	if _touch._layout.has(id):
		return _touch._layout[id]["c"]
	return Vector2.ZERO

func _show() -> void:
	var pg: Dictionary = PAGES[_page]
	_count.text = "%d / %d" % [_page + 1, PAGES.size()]
	_title.text = String(pg["t"])
	_body.text = String(pg["body"])
	_prev.disabled = _page == 0
	_next.text = "DONE" if _page == PAGES.size() - 1 else "NEXT"
	await get_tree().process_frame
	_place_card()

func _place_card() -> void:
	if not is_inside_tree():
		return
	var tgt := _target_pos(String(PAGES[_page]["target"]))
	var cs := _card.get_combined_minimum_size()
	var vs := get_viewport_rect().size
	# put the card on the opposite half from the highlighted control so it never covers it
	var x := vs.x * 0.5 - cs.x * 0.5
	if tgt != Vector2.ZERO:
		x = vs.x * 0.27 - cs.x * 0.5 if tgt.x > vs.x * 0.5 else vs.x * 0.73 - cs.x * 0.5
	_card.position = Vector2(clampf(x, 12.0, vs.x - cs.x - 12.0), clampf(vs.y * 0.5 - cs.y * 0.5 - 30.0, 12.0, vs.y - cs.y - 12.0))
	queue_redraw()

func _process(delta: float) -> void:
	_t += delta
	if _hl != null:
		_hl.size = size
		_hl.queue_redraw()

func _draw_highlight() -> void:
	var tgt := _target_pos(String(PAGES[_page]["target"]))
	if tgt == Vector2.ZERO:
		return
	var id := String(PAGES[_page]["target"])
	var r := 70.0
	if _touch._layout.has(id):
		r = float(_touch._layout[id]["r"]) + 10.0
	elif id == "joy":
		r = 110.0
	elif id == "cam":
		r = 90.0
	elif id == "hud":
		r = 80.0
	var pul := 0.5 + 0.5 * sin(_t * 5.0)
	var col := Color(1.0, 0.9, 0.4, 0.55 + 0.4 * pul)
	_hl.draw_arc(tgt, r + 6.0 * pul, 0, TAU, 48, col, 5.0, true)
	_hl.draw_arc(tgt, r + 16.0 + 8.0 * pul, 0, TAU, 48, Color(col.r, col.g, col.b, 0.25), 3.0, true)
	if id == "cam":
		_hl.draw_line(tgt + Vector2(-60, 0), tgt + Vector2(60, 0), col, 4.0, true)
		_hl.draw_colored_polygon(PackedVector2Array([tgt + Vector2(60, -12), tgt + Vector2(80, 0), tgt + Vector2(60, 12)]), col)
		_hl.draw_colored_polygon(PackedVector2Array([tgt + Vector2(-60, -12), tgt + Vector2(-80, 0), tgt + Vector2(-60, 12)]), col)
	# arrow from the card to the control
	var from := _card.position + _card.size * 0.5
	var dir := (tgt - from).normalized()
	_hl.draw_line(from + dir * 150.0, tgt - dir * (r + 10.0), Color(col.r, col.g, col.b, 0.5), 3.0, true)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_finish()
