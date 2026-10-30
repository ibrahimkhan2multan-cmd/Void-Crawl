class_name VCModWindow
extends PanelContainer
## A floating menu window created from a mod's "menus" data. Drag it by the title bar; tap X to close.
## Windows hold text lines (with {coins} {level} ... tokens), dividers and buttons. Buttons run data-only actions:
##   message / code / mission / perks / menu / close      (see modding/MODDING.md)

const MAX_OPEN := 6

var menu: Dictionary = {}
var ctx := "main"                       # "main" (main menu) or "pause" (in a dungeon)
var _host: Control
var _body: VBoxContainer
var _bar: Control
var _dragging := false
var _col := Color(0.6, 0.4, 1.0)

# ------------------------------------------------------------------ static helpers
static func open_menu(host: Control, menu_def: Dictionary, context: String) -> VCModWindow:
	for w in host.get_children():
		if w is VCModWindow and String(w.menu.get("key", "")) == String(menu_def.get("key", "?")) and String(menu_def.get("key", "")) != "":
			w.move_to_front()
			return w
	var open_ones: Array = []
	for w in host.get_children():
		if w is VCModWindow:
			open_ones.append(w)
	if open_ones.size() >= MAX_OPEN:
		open_ones[0].queue_free()
	var win := VCModWindow.new()
	win.menu = menu_def
	win.ctx = context
	win._host = host
	host.add_child(win)
	return win

static func message(host: Control, title: String, text: String, context: String) -> void:
	var m := {"key": "", "title": title, "color": Color(0.7, 0.5, 1.0), "width": 380, "draggable": true, "x": 0.5, "y": 0.35,
		"elements": [{"type": "text", "text": text, "size": 20, "color": Color(0.92, 0.9, 1.0), "center": true}, {"type": "button", "label": "OK", "color": Color(0.7, 0.5, 1.0), "action": {"type": "close"}}]}
	open_menu(host, m, context)

static func run_action(host: Control, action: Dictionary, context: String, from: VCModWindow = null, title: String = "") -> void:
	match String(action.get("type", "")):
		"message":
			message(host, String(action.get("title", title if title != "" else "Message")), String(action.get("text", "")), context)
		"code":
			var r := VCCodes.redeem(String(action.get("code", "")), VC.profile)
			if bool(r["ok"]):
				VC.notify_profile_changed()
				VC.save_now()
				VC.play_sfx("levelup", -4.0)
			message(host, title if title != "" else "Code", String(r["msg"]), context)
		"mission":
			var mid := String(action.get("mission", ""))
			if context != "main":
				message(host, title if title != "" else "Dungeon", "Start dungeons from the main menu.", context)
			elif not VCMissions.DATA.has(mid):
				message(host, title if title != "" else "Dungeon", "That dungeon is not available (is its mod turned on?).", context)
			elif not VCMissions.is_unlocked(mid, VC.profile.completed):
				message(host, title if title != "" else "Dungeon", "That dungeon is still locked. Finish the dungeon before it first.", context)
			else:
				VC.run = {}
				VC.start_mission(mid, 0, false)
		"perks":
			var pp := VCPerksPanel.new()
			pp.closed.connect(func():
				pp.queue_free()
				refresh_all(host))
			host.add_child(pp)
			VCUI.fit_to_viewport(pp)
		"menu":
			var key := String(action.get("menu", ""))
			var md: Dictionary = VCMods.menu_def(key)
			if md.is_empty():
				message(host, title if title != "" else "Menu", "That menu is not available (is its mod turned on?).", context)
			else:
				open_menu(host, md, context)
		"close":
			if from != null:
				from.queue_free()
	refresh_all(host)

static func refresh_all(host: Control) -> void:
	for w in host.get_children():
		if w is VCModWindow:
			w.rebuild()

# ------------------------------------------------------------------ the window
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = VCUI.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	_col = menu.get("color", Color(0.6, 0.4, 1.0))
	modulate.a = 0.0      # hidden for one frame while it is positioned
	add_theme_stylebox_override("panel", VCUI.box(Color(0.05, 0.03, 0.1, 0.97), _col, 12, 3, 10))
	var width := float(clampi(int(menu.get("width", 340)), 240, 600))
	var vp := get_viewport_rect().size
	width = minf(width, vp.x - 20.0)
	custom_minimum_size = Vector2(width, 0)
	var v := VCUI.vbox(8)
	add_child(v)
	_bar = PanelContainer.new()
	_bar.add_theme_stylebox_override("panel", VCUI.box(_col.darkened(0.55), _col.darkened(0.2), 8, 1, 6))
	_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	_bar.gui_input.connect(_bar_input)
	v.add_child(_bar)
	var th := VCUI.hbox(6)
	_bar.add_child(th)
	var grip := VCUI.label("::" if bool(menu.get("draggable", true)) else "", 20, _col.lightened(0.4))
	grip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	th.add_child(grip)
	var tl := VCUI.label(String(menu.get("title", "Menu")), 22, Color.WHITE)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	th.add_child(tl)
	var x := VCUI.button("X", Vector2(48, 40), 20)
	x.pressed.connect(queue_free)
	th.add_child(x)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	var est := 0.0
	for e in menu.get("elements", []):
		est += 56.0 if String(e.get("type", "")) == "button" else (14.0 if String(e.get("type", "")) == "divider" else 12.0 + 26.0 * float(maxi(1, int(String(e.get("text", "")).length() / 28.0) + 1)))
	sc.custom_minimum_size = Vector2(width - 24.0, minf(est + 4.0, vp.y - 170.0))
	v.add_child(sc)
	_body = VCUI.vbox(8)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.mouse_filter = Control.MOUSE_FILTER_PASS
	sc.add_child(_body)
	rebuild()
	# start position (fractions of the screen), cascaded a little so stacked windows stay visible
	var fx := clampf(float(menu.get("x", 0.5)), 0.0, 1.0)
	var fy := clampf(float(menu.get("y", 0.5)), 0.0, 1.0)
	await get_tree().process_frame
	if not is_inside_tree():
		return
	var n := 0
	for w in get_parent().get_children():
		if w is VCModWindow and w != self:
			n += 1
	position = Vector2((vp.x - size.x) * fx + 22.0 * float(n), (vp.y - size.y) * fy + 22.0 * float(n))
	_clamp()
	modulate.a = 1.0

func rebuild() -> void:
	if _body == null:
		return
	for c in _body.get_children():
		c.queue_free()
	for e in menu.get("elements", []):
		match String(e.get("type", "")):
			"text":
				var l := VCUI.label(_tokens(String(e.get("text", ""))), int(e.get("size", 19)), e.get("color", VCDefs.COL_TEXT), HORIZONTAL_ALIGNMENT_CENTER if bool(e.get("center", false)) else HORIZONTAL_ALIGNMENT_LEFT)
				l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				l.custom_minimum_size = Vector2(custom_minimum_size.x - 40.0, 0)
				l.mouse_filter = Control.MOUSE_FILTER_PASS
				_body.add_child(l)
			"divider":
				var d := ColorRect.new()
				d.color = _col.darkened(0.4)
				d.custom_minimum_size = Vector2(0, 2)
				_body.add_child(d)
			"button":
				var b := VCUI.button(String(e.get("label", "OK")), Vector2(custom_minimum_size.x - 40.0, 52), 20)
				var c: Color = e.get("color", _col)
				b.add_theme_color_override("font_color", c.lerp(Color.WHITE, 0.6))
				b.add_theme_stylebox_override("normal", VCUI.box(Color(0.07, 0.04, 0.13, 0.95), c, 10, 2, 8))
				b.pressed.connect(_pressed.bind(e))
				_body.add_child(b)

func _tokens(t: String) -> String:
	var p: VCProfile = VC.profile
	if p == null:
		return t
	var live := 0
	for a in p.perks_active:
		if VCPerks.DEFS.has(String(a)):
			live += 1
	return t.replace("{coins}", str(p.coins)).replace("{level}", str(p.level)).replace("{kills}", str(int(p.stats.get("kills", 0)))) \
		.replace("{bosses}", str(int(p.stats.get("bosses", 0)))).replace("{deaths}", str(int(p.stats.get("deaths", 0)))) \
		.replace("{potions}", str(p.potions)).replace("{bombs}", str(p.bombs)).replace("{perks}", "%d/%d" % [live, p.perk_slots()])

func _pressed(e: Dictionary) -> void:
	VC.play_sfx("click", -6.0)
	run_action(_host if _host != null else get_parent() as Control, e.get("action", {}), ctx, self, String(menu.get("title", "")))

func _bar_input(ev: InputEvent) -> void:
	if not bool(menu.get("draggable", true)):
		return
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		_dragging = ev.pressed
		if ev.pressed:
			move_to_front()
	elif ev is InputEventMouseMotion and _dragging:
		position += ev.relative
		_clamp()

func _clamp() -> void:
	var vp := get_viewport_rect().size
	position = Vector2(clampf(position.x, 0.0, maxf(vp.x - size.x, 0.0)), clampf(position.y, 0.0, maxf(vp.y - size.y, 0.0)))
