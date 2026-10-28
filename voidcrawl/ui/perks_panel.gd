class_name VCPerksPanel
extends Control
## Buy perks with coins and slot up to VCPerks.SLOTS of them. Mods can add more perks.

signal closed

var _list: VBoxContainer
var _status: Label
var _coins: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = VCUI.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.03, 0.85)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(cc)
	var panel := VCUI.panel()
	cc.add_child(panel)
	var v := VCUI.vbox(10)
	v.custom_minimum_size = Vector2(720, 0)
	panel.add_child(v)
	v.add_child(VCUI.label("PERKS", 38, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
	_coins = VCUI.label("", 20, VCDefs.COL_COIN, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(_coins)
	var scroll := ScrollContainer.new()
	var vh := get_viewport_rect().size.y if is_inside_tree() else 720.0
	scroll.custom_minimum_size = Vector2(0, clampf(vh - 340.0, 160.0, 420.0))
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_list = VCUI.vbox(8)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.add_child(_list)
	_status = VCUI.label("", 18, VCDefs.COL_GOOD, HORIZONTAL_ALIGNMENT_CENTER)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(680, 30)
	v.add_child(_status)
	var back := VCUI.button("BACK", Vector2(720, 56), 24)
	back.pressed.connect(func(): closed.emit())
	v.add_child(back)
	refresh()

func _live_active() -> int:
	var n := 0
	for a in VC.profile.perks_active:
		if VCPerks.DEFS.has(String(a)):
			n += 1
	return n

func refresh() -> void:
	var p: VCProfile = VC.profile
	_coins.text = "%d coins   -   %d / %d perk slots used" % [p.coins, _live_active(), VCPerks.SLOTS]
	for c in _list.get_children():
		c.queue_free()
	var ids: Array = VCPerks.DEFS.keys()
	# owned & slotted first, then owned, then the rest
	ids.sort_custom(func(a, b):
		var ra := (2 if p.perks_active.has(a) else (1 if p.perks_owned.has(a) else 0))
		var rb := (2 if p.perks_active.has(b) else (1 if p.perks_owned.has(b) else 0))
		if ra != rb:
			return ra > rb
		return int(VCPerks.DEFS[a]["cost"]) < int(VCPerks.DEFS[b]["cost"]))
	for id in ids:
		_list.add_child(_card(String(id)))

func _card(id: String) -> Control:
	var p: VCProfile = VC.profile
	var d: Dictionary = VCPerks.DEFS[id]
	var owned := p.perks_owned.has(id)
	var active := p.perks_active.has(id)
	var col: Color = d.get("color", Color(0.7, 0.5, 1.0))
	var pc := VCUI.panel(Color(0.04, 0.02, 0.08, 0.95), col.darkened(0.1) if active else (Color(0.3, 0.16, 0.5) if owned else Color(0.2, 0.18, 0.28)))
	pc.mouse_filter = Control.MOUSE_FILTER_PASS
	var h := VCUI.hbox(10)
	pc.add_child(h)
	var tx := VCUI.vbox(2)
	tx.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(tx)
	tx.add_child(VCUI.label(String(d["name"]) + ("   [EQUIPPED]" if active else ""), 22, col if owned else VCDefs.COL_TEXT_DIM))
	tx.add_child(VCUI.label(VCPerks.bonus_text(id), 17, VCDefs.COL_GOOD))
	var ds := VCUI.label(String(d.get("desc", "")), 15, VCDefs.COL_TEXT_DIM)
	ds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ds.custom_minimum_size = Vector2(430, 0)
	tx.add_child(ds)
	var b: Button
	if not owned:
		b = VCUI.button("BUY  %d" % int(d["cost"]), Vector2(190, 56), 20)
		b.disabled = p.coins < int(d["cost"])
		b.pressed.connect(_buy.bind(id))
	else:
		b = VCUI.button("UNEQUIP" if active else "EQUIP", Vector2(190, 56), 20)
		b.pressed.connect(_toggle.bind(id))
	h.add_child(b)
	return pc

func _buy(id: String) -> void:
	var err := VC.profile.buy_perk(id)
	if err == "":
		VC.profile.toggle_perk(id)   # equip straight away if a slot is free
		_say("Perk bought!", true)
		VC.play_sfx("levelup", -6.0)
		VC.notify_profile_changed()
		VC.save_now()
	else:
		_say(err, false)
	refresh()

func _toggle(id: String) -> void:
	var err := VC.profile.toggle_perk(id)
	if err == "":
		_say("Perk slots updated.", true)
		VC.play_sfx("click", -6.0)
		VC.notify_profile_changed()
		VC.save_now()
	else:
		_say(err, false)
	refresh()

func _say(t: String, good: bool) -> void:
	_status.text = t
	_status.add_theme_color_override("font_color", VCDefs.COL_GOOD if good else VCDefs.COL_BAD)
