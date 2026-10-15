class_name VCTouchControls
extends Control
## On-screen controls. Handles every touch itself (index-tracked), so the thumbs never fight:
##   - floating or fixed joystick on the left (left/right swap for left-handed mode)
##   - ATTACK, DODGE, VOID NOVA, POTION, USE buttons on the right
##   - dragging an empty patch of screen on the strong-hand side rotates the camera
## Writes into VCInput; draws itself with vector shapes (no image assets needed).

signal pause_pressed
signal inventory_pressed

var player: VCPlayer = null
var interact_prompt := ""            # non-empty while something can be used
var active := true                   # false while a menu is open
var preview := false                 # settings preview: draw only

var _joy_touch := -1
var _joy_origin := Vector2.ZERO
var _joy_pos := Vector2.ZERO
var _cam_touch := -1
var _cam_last := Vector2.ZERO
var _btn_touch: Dictionary = {}      # touch index -> button id
var _held: Dictionary = {}           # button id -> true
var _layout: Dictionary = {}         # id -> {"c": Vector2, "r": float}
var _hud_buttons: Dictionary = {}    # small top buttons
var _pulse := 0.0
var _joy_rest := Vector2.ZERO

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_relayout)
	name = "TouchControls"
	if get_parent() is CanvasLayer:
		# anchors do not resolve under a CanvasLayer, so track the viewport size by hand
		get_viewport().size_changed.connect(_fit_to_viewport)
		_fit_to_viewport()
	_relayout()

func _fit_to_viewport() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size

func apply_settings() -> void:
	_relayout()
	queue_redraw()

func _relayout() -> void:
	var size_v := size
	if size_v.x < 10.0:
		size_v = get_viewport_rect().size
	var m := VCUI.safe_margins(get_viewport(), 18.0)
	var s: float = float(VCSettings.get_value("btn_scale"))
	var left_handed: bool = bool(VCSettings.get_value("left_handed"))
	var base := minf(size_v.x, size_v.y)
	var unit := clampf(base / 720.0, 0.75, 1.5) * s
	var rb := size_v.x - float(m["right"]) - 20.0     # right edge for action cluster
	var bb := size_v.y - float(m["bottom"]) - 18.0
	var cx := rb - 82.0 * unit
	var cy := bb - 82.0 * unit
	var sign_ := 1.0
	if left_handed:
		cx = float(m["left"]) + 20.0 + 82.0 * unit
		sign_ = -1.0
	_layout = {
		"attack": {"c": Vector2(cx, cy), "r": 70.0 * unit},
		"dodge": {"c": Vector2(cx - sign_ * 138.0 * unit, cy + 26.0 * unit), "r": 48.0 * unit},
		"ability": {"c": Vector2(cx - sign_ * 98.0 * unit, cy - 98.0 * unit), "r": 48.0 * unit},
		"heal": {"c": Vector2(cx + sign_ * 6.0 * unit, cy - 150.0 * unit), "r": 40.0 * unit},
		"interact": {"c": Vector2(cx - sign_ * 20.0 * unit, cy - 250.0 * unit), "r": 54.0 * unit},
	}
	var tr := size_v.x - float(m["right"]) - 8.0
	_hud_buttons = {
		"pause": {"c": Vector2(tr - 30.0 * unit, float(m["top"]) + 34.0 * unit), "r": 30.0 * unit},
		"pack": {"c": Vector2(tr - 100.0 * unit, float(m["top"]) + 34.0 * unit), "r": 30.0 * unit},
	}
	if left_handed:
		var tl := float(m["left"]) + 8.0
		_hud_buttons["pause"]["c"] = Vector2(tl + 30.0 * unit, float(m["top"]) + 34.0 * unit)
		_hud_buttons["pack"]["c"] = Vector2(tl + 100.0 * unit, float(m["top"]) + 34.0 * unit)
	var jr := 96.0 * float(VCSettings.get_value("joy_size")) * unit
	if left_handed:
		_joy_rest = Vector2(size_v.x - float(m["right"]) - 40.0 - jr - 40.0 * unit, bb - jr - 24.0 * unit)
	else:
		_joy_rest = Vector2(float(m["left"]) + 40.0 + jr + 40.0 * unit, bb - jr - 24.0 * unit)
	queue_redraw()

func _joy_radius() -> float:
	var base := minf(size.x, size.y)
	return 96.0 * float(VCSettings.get_value("joy_size")) * clampf(base / 720.0, 0.75, 1.5) * float(VCSettings.get_value("btn_scale"))

func _hit_button(p: Vector2) -> String:
	var best := ""
	var best_d := 1e9
	for id in _layout:
		if id == "interact" and interact_prompt == "":
			continue
		var d: float = p.distance_to(_layout[id]["c"])
		var r: float = _layout[id]["r"] * 1.18       # forgiving hit area
		if d <= r and d < best_d:
			best = id
			best_d = d
	return best

func _hit_hud(p: Vector2) -> String:
	for id in _hud_buttons:
		if p.distance_to(_hud_buttons[id]["c"]) <= float(_hud_buttons[id]["r"]) * 1.25:
			return id
	return ""

func _on_left_side(p: Vector2) -> bool:
	var left_handed: bool = bool(VCSettings.get_value("left_handed"))
	var on_left := p.x < size.x * 0.46
	return on_left != left_handed

func _input(event: InputEvent) -> void:
	if preview:
		return
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)

func _handle_touch(e: InputEventScreenTouch) -> void:
	var p := e.position
	if e.pressed:
		if not active:
			return
		var hud := _hit_hud(p)
		if hud != "":
			get_viewport().set_input_as_handled()
			if hud == "pause":
				pause_pressed.emit()
			else:
				inventory_pressed.emit()
			VC.play_sfx("click", -4.0)
			return
		var b := _hit_button(p)
		if b != "":
			_btn_touch[e.index] = b
			_held[b] = true
			_button_down(b)
			get_viewport().set_input_as_handled()
			return
		if _on_left_side(p) and _joy_touch < 0:
			_joy_touch = e.index
			if bool(VCSettings.get_value("joy_floating")):
				_joy_origin = p
			else:
				_joy_origin = _joy_rest
			_joy_pos = p
			_update_joy()
			get_viewport().set_input_as_handled()
		elif not _on_left_side(p) and _cam_touch < 0:
			_cam_touch = e.index
			_cam_last = p
	else:
		if e.index == _joy_touch:
			_joy_touch = -1
			VCInput.touch_move = Vector2.ZERO
			VCInput.touch_sprint = false
			queue_redraw()
		elif e.index == _cam_touch:
			_cam_touch = -1
		if _btn_touch.has(e.index):
			var id: String = _btn_touch[e.index]
			_btn_touch.erase(e.index)
			_held.erase(id)
			_button_up(id)
	queue_redraw()

func _handle_drag(e: InputEventScreenDrag) -> void:
	if e.index == _joy_touch:
		_joy_pos = e.position
		_update_joy()
		get_viewport().set_input_as_handled()
	elif e.index == _cam_touch:
		var dx := e.position.x - _cam_last.x
		_cam_last = e.position
		VCInput.cam_yaw_delta -= dx * 0.006
	queue_redraw()

func _update_joy() -> void:
	var r := _joy_radius()
	var off := _joy_pos - _joy_origin
	if bool(VCSettings.get_value("joy_floating")) and off.length() > r:
		# the stick base follows the thumb so you never run out of travel
		_joy_origin += off.normalized() * (off.length() - r)
		off = _joy_pos - _joy_origin
	var v := off / r
	var dz: float = float(VCSettings.get_value("joy_deadzone"))
	var mag := v.length()
	if mag < dz:
		VCInput.touch_move = Vector2.ZERO
		VCInput.touch_sprint = false
	else:
		var scaled := (mag - dz) / (1.0 - dz)
		VCInput.touch_move = v.normalized() * clampf(scaled, 0.0, 1.0)
		VCInput.touch_sprint = mag > 0.93

func _button_down(id: String) -> void:
	match id:
		"attack": VCInput.touch_attack_held = true
		"dodge": VCInput.press("dodge")
		"ability": VCInput.press("ability")
		"heal": VCInput.press("heal")
		"interact": VCInput.press("interact")
	VC.vibrate(8)

func _button_up(id: String) -> void:
	if id == "attack":
		VCInput.touch_attack_held = false

func release_all() -> void:
	_joy_touch = -1
	_cam_touch = -1
	_btn_touch.clear()
	_held.clear()
	VCInput.touch_move = Vector2.ZERO
	VCInput.touch_attack_held = false
	VCInput.touch_sprint = false
	queue_redraw()

# -------------------------------------------------------------------- draw
func _process(delta: float) -> void:
	_pulse += delta
	if visible:
		queue_redraw()

func _alpha() -> float:
	return float(VCSettings.get_value("btn_opacity"))

func _draw() -> void:
	if size.x < 10.0:
		return
	var a := _alpha()
	# joystick
	var r := _joy_radius()
	var base_c := _joy_origin if (_joy_touch >= 0) else _joy_rest
	var knob := base_c
	if _joy_touch >= 0:
		knob = base_c + (_joy_pos - base_c).limit_length(r)
	var show_idle: bool = _joy_touch >= 0 or not bool(VCSettings.get_value("joy_floating"))
	var ja := a if _joy_touch >= 0 else a * 0.55
	if show_idle or preview:
		draw_circle(base_c, r, Color(0.08, 0.04, 0.16, 0.45 * ja))
		draw_arc(base_c, r, 0, TAU, 48, Color(0.65, 0.4, 1.0, 0.8 * ja), 3.0, true)
		draw_arc(base_c, r * 0.55, 0, TAU, 32, Color(0.5, 0.3, 0.9, 0.3 * ja), 2.0, true)
		draw_circle(knob, r * 0.42, Color(0.45, 0.22, 0.85, 0.7 * ja))
		draw_arc(knob, r * 0.42, 0, TAU, 32, Color(0.85, 0.65, 1.0, 0.95 * ja), 3.0, true)
	for id in _layout:
		if id == "interact" and interact_prompt == "":
			continue
		_draw_button(id, a)
	for id in _hud_buttons:
		_draw_hud_button(id, a)

func _cooldown(id: String) -> float:
	if player == null:
		return 0.0
	return player.cooldown_fraction(id)

func _draw_button(id: String, a: float) -> void:
	var c: Vector2 = _layout[id]["c"]
	var r: float = _layout[id]["r"]
	var down: bool = _held.has(id)
	var cd := _cooldown(id) if id in ["dodge", "ability", "heal"] else 0.0
	var potions := 0
	if player != null and player.profile != null:
		potions = player.profile.potions
	var disabled := (id == "heal" and potions <= 0)
	var fill := Color(0.1, 0.05, 0.2, 0.55 * a)
	var edge := Color(0.7, 0.45, 1.0, 0.9 * a)
	match id:
		"attack":
			fill = Color(0.35, 0.1, 0.55, 0.62 * a)
			edge = Color(0.95, 0.7, 1.0, 0.95 * a)
		"heal":
			edge = Color(1.0, 0.4, 0.55, 0.95 * a)
		"interact":
			var pul := 0.75 + 0.25 * sin(_pulse * 6.0)
			fill = Color(0.3, 0.2, 0.05, 0.7 * a)
			edge = Color(1.0, 0.85, 0.35, pul * a)
	if down:
		fill = fill.lightened(0.35)
		r *= 0.94
	draw_circle(c, r, fill)
	draw_arc(c, r, 0, TAU, 48, edge if not disabled else Color(0.4, 0.35, 0.45, 0.6 * a), 3.5, true)
	var ic := Color(1, 1, 1, 0.95 * a) if not disabled else Color(0.6, 0.55, 0.65, 0.6 * a)
	var k := r * 0.46
	match id:
		"attack":
			# crossed blades
			draw_line(c + Vector2(-k, k), c + Vector2(k, -k), ic, 6.0, true)
			draw_line(c + Vector2(k, k), c + Vector2(-k, -k), ic, 6.0, true)
			draw_line(c + Vector2(-k * 0.45, k * 0.15), c + Vector2(-k * 0.05, k * 0.55), ic, 5.0, true)
			draw_line(c + Vector2(k * 0.45, k * 0.15), c + Vector2(k * 0.05, k * 0.55), ic, 5.0, true)
		"dodge":
			draw_arc(c, k, deg_to_rad(210), deg_to_rad(500), 24, ic, 5.0, true)
			var tip := c + Vector2(cos(deg_to_rad(500)), sin(deg_to_rad(500))) * k
			draw_colored_polygon(PackedVector2Array([tip + Vector2(-10, -12), tip + Vector2(12, 4), tip + Vector2(-12, 10)]), ic)
		"ability":
			draw_arc(c, k * 0.5, 0, TAU, 20, ic, 4.0, true)
			draw_arc(c, k * 1.0, 0, TAU, 28, Color(ic.r, ic.g, ic.b, ic.a * 0.8), 3.0, true)
			for i in 8:
				var an := TAU * float(i) / 8.0
				draw_line(c + Vector2(cos(an), sin(an)) * k * 1.1, c + Vector2(cos(an), sin(an)) * k * 1.5, ic, 3.5, true)
		"heal":
			draw_rect(Rect2(c + Vector2(-k * 0.28, -k * 1.0), Vector2(k * 0.56, k * 0.5)), ic)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-k * 0.28, -k * 0.5), c + Vector2(k * 0.28, -k * 0.5), c + Vector2(k * 0.8, k * 0.9), c + Vector2(-k * 0.8, k * 0.9)]), Color(1.0, 0.3, 0.45, ic.a) if not disabled else ic)
			var font := ThemeDB.fallback_font
			draw_string(font, c + Vector2(r * 0.3, r * 0.95), str(potions), HORIZONTAL_ALIGNMENT_LEFT, -1, int(r * 0.7), Color(1, 1, 1, a))
		"interact":
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -k * 1.1), c + Vector2(k * 0.8, 0), c + Vector2(0, k * 1.1), c + Vector2(-k * 0.8, 0)]), ic)
			var f2 := ThemeDB.fallback_font
			draw_string(f2, c + Vector2(-r, r + 22.0), interact_prompt.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, 20, Color(1.0, 0.92, 0.6, a))
	if cd > 0.0:
		draw_circle(c, r, Color(0, 0, 0, 0.55))
		draw_arc(c, r - 3.0, -PI * 0.5, -PI * 0.5 + TAU * cd, 40, Color(0.9, 0.8, 1.0, 0.95), 6.0, true)
		var secs := 0.0
		if id == "ability" and player != null:
			secs = player.nova_cd
		elif id == "dodge" and player != null:
			secs = player.dodge_cd
		elif id == "heal" and player != null:
			secs = player.potion_cd
		var f := ThemeDB.fallback_font
		draw_string(f, c + Vector2(-r, r * 0.22), "%.1f" % secs, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, int(r * 0.62), Color(1, 1, 1, 0.95))

func _draw_hud_button(id: String, a: float) -> void:
	var c: Vector2 = _hud_buttons[id]["c"]
	var r: float = _hud_buttons[id]["r"]
	draw_circle(c, r, Color(0.08, 0.04, 0.16, 0.6 * a))
	draw_arc(c, r, 0, TAU, 32, Color(0.7, 0.45, 1.0, 0.8 * a), 2.5, true)
	var ic := Color(1, 1, 1, 0.9 * a)
	if id == "pause":
		draw_rect(Rect2(c + Vector2(-r * 0.35, -r * 0.4), Vector2(r * 0.22, r * 0.8)), ic)
		draw_rect(Rect2(c + Vector2(r * 0.13, -r * 0.4), Vector2(r * 0.22, r * 0.8)), ic)
	else:
		# backpack
		draw_rect(Rect2(c + Vector2(-r * 0.4, -r * 0.3), Vector2(r * 0.8, r * 0.7)), ic)
		draw_arc(c + Vector2(0, -r * 0.3), r * 0.25, PI, TAU, 12, ic, 3.0, true)
		draw_rect(Rect2(c + Vector2(-r * 0.22, r * 0.05), Vector2(r * 0.44, r * 0.18)), Color(0.3, 0.1, 0.5, a))
