class_name VCUpgradesPanel
extends Control
## UPGRADES (bigger backpack, potion belt, bomb pouch, perk slots, alchemy, kennel) and AUTO-DELETE
## (pick which rarities are removed automatically when you pick them up).

signal closed

var start_tab := "upgrades"
var _tab := "upgrades"
var _list: VBoxContainer
var _status: Label
var _coins: Label
var _tab_up: Button
var _tab_auto: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = VCUI.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	_tab = start_tab
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.03, 0.88)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(cc)
	var panel := VCUI.panel()
	cc.add_child(panel)
	var v := VCUI.vbox(8)
	v.custom_minimum_size = Vector2(760, 0)
	panel.add_child(v)
	var head := VCUI.hbox(10)
	v.add_child(head)
	_tab_up = VCUI.button("UPGRADES", Vector2(190, 52), 22)
	_tab_up.pressed.connect(_set_tab.bind("upgrades"))
	head.add_child(_tab_up)
	_tab_auto = VCUI.button("AUTO-DELETE", Vector2(210, 52), 22)
	_tab_auto.pressed.connect(_set_tab.bind("auto"))
	head.add_child(_tab_auto)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	_coins = VCUI.label("", 24, VCDefs.COL_COIN, HORIZONTAL_ALIGNMENT_RIGHT)
	head.add_child(_coins)
	var scroll := ScrollContainer.new()
	var vh := get_viewport_rect().size.y if is_inside_tree() else 720.0
	scroll.custom_minimum_size = Vector2(0, clampf(vh - 250.0, 160.0, 460.0))
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_list = VCUI.vbox(8)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.add_child(_list)
	_status = VCUI.label("", 18, VCDefs.COL_GOOD, HORIZONTAL_ALIGNMENT_CENTER)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(720, 28)
	v.add_child(_status)
	var back := VCUI.button("BACK", Vector2(760, 54), 24)
	back.pressed.connect(func(): closed.emit())
	v.add_child(back)
	refresh()

func _set_tab(t: String) -> void:
	_tab = t
	_status.text = ""
	refresh()

func refresh() -> void:
	var p: VCProfile = VC.profile
	_coins.text = "%d coins" % p.coins
	VCUI.mark_tab(_tab_up, _tab == "upgrades")
	VCUI.mark_tab(_tab_auto, _tab == "auto")
	for c in _list.get_children():
		c.queue_free()
	if _tab == "upgrades":
		for id in VCUpgrades.ORDER:
			_list.add_child(_upgrade_card(String(id)))
	else:
		_build_auto()

# -------------------------------------------------------------- upgrades
func _upgrade_card(id: String) -> Control:
	var p: VCProfile = VC.profile
	var d: Dictionary = VCUpgrades.DEFS[id]
	var lv := VCUpgrades.level(p, id)
	var mx := VCUpgrades.max_level(id)
	var col: Color = d["color"]
	var pc := VCUI.panel(Color(0.04, 0.02, 0.08, 0.95), col.darkened(0.2))
	pc.mouse_filter = Control.MOUSE_FILTER_PASS
	var h := VCUI.hbox(10)
	pc.add_child(h)
	var tx := VCUI.vbox(2)
	tx.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(tx)
	tx.add_child(VCUI.label("%s   Lv %d / %d" % [String(d["name"]), lv, mx], 22, col))
	var ds := VCUI.label(String(d["desc"]), 15, VCDefs.COL_TEXT_DIM)
	ds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ds.custom_minimum_size = Vector2(470, 0)
	tx.add_child(ds)
	var now_t := VCUpgrades.effect_text(p, id)
	var bar := VCBar.new()
	bar.custom_minimum_size = Vector2(300, 14)
	bar.color = col
	bar.show_ghost = false
	bar.set_values(float(lv), float(mx))
	bar.snap()
	tx.add_child(bar)
	tx.add_child(VCUI.label("Now: " + now_t, 17, VCDefs.COL_GOOD))
	var cost := VCUpgrades.cost(p, id)
	var b: Button
	if cost < 0:
		b = VCUI.button("MAXED", Vector2(190, 56), 20)
		b.disabled = true
	else:
		b = VCUI.button("UPGRADE  %d" % cost, Vector2(190, 56), 19)
		b.disabled = p.coins < cost
		b.pressed.connect(_buy.bind(id))
	h.add_child(b)
	return pc

func _buy(id: String) -> void:
	var err := VCUpgrades.buy(VC.profile, id)
	if err == "":
		_say("%s upgraded!" % String(VCUpgrades.DEFS[id]["name"]), true)
		VC.play_sfx("levelup", -6.0)
		VC.notify_profile_changed()
		VC.save_now()
	else:
		_say(err, false)
	refresh()

# ------------------------------------------------------------ auto-delete
func _build_auto() -> void:
	var p: VCProfile = VC.profile
	var info := VCUI.label("Tap a rarity to switch it ON. Items of an ON rarity are removed the moment you pick them up. Set pieces and unique items are never touched.", 16, VCDefs.COL_TEXT_DIM)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size = Vector2(700, 0)
	_list.add_child(info)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	_list.add_child(grid)
	for r in VCDefs.RARITY_NAMES.size():
		var on := p.auto_rarities.has(r)
		var rc := VCDefs.rarity_color(r)
		var b := VCUI.button("%s   %s" % ["[ON]" if on else "[off]", VCDefs.rarity_name(r)], Vector2(345, 54), 21)
		b.add_theme_color_override("font_color", rc if on else rc.darkened(0.35))
		b.add_theme_stylebox_override("normal", VCUI.box(Color(0.09, 0.05, 0.16, 0.96) if not on else rc.darkened(0.72), rc if on else rc.darkened(0.6), 10, 2, 12))
		b.pressed.connect(_toggle_rarity.bind(r))
		grid.add_child(b)
	var mode_b := VCUI.button("When removed:  " + ("SELL FOR COINS" if p.auto_mode == "sell" else "DELETE (no coins)"), Vector2(700, 52), 20)
	mode_b.pressed.connect(func():
		p.auto_mode = "delete" if p.auto_mode == "sell" else "sell"
		VC.save_now()
		refresh())
	_list.add_child(mode_b)
	var keep_b := VCUI.button("Keep upgrades:  " + ("ON  (never remove gear better than what you wear)" if p.auto_keep_upgrades else "OFF"), Vector2(700, 52), 18)
	keep_b.pressed.connect(func():
		p.auto_keep_upgrades = not p.auto_keep_upgrades
		VC.save_now()
		refresh())
	_list.add_child(keep_b)
	var n := 0
	for it in p.inventory:
		if p.should_auto_remove(it):
			n += 1
	var sweep := VCUI.button("CLEAN BACKPACK NOW  (%d item%s)" % [n, "" if n == 1 else "s"], Vector2(700, 56), 21)
	sweep.disabled = n == 0
	sweep.pressed.connect(func():
		var res := p.sweep_auto()
		_say("Removed %d item%s%s." % [int(res["count"]), "" if int(res["count"]) == 1 else "s", ("  +%d coins" % int(res["coins"])) if int(res["coins"]) > 0 else ""], true)
		VC.play_sfx("coin")
		VC.notify_profile_changed()
		VC.save_now()
		refresh())
	_list.add_child(sweep)

func _toggle_rarity(r: int) -> void:
	VC.profile.toggle_auto_rarity(r)
	VC.play_sfx("click", -6.0)
	VC.save_now()
	refresh()

func _say(t: String, good: bool) -> void:
	_status.text = t
	_status.add_theme_color_override("font_color", VCDefs.COL_GOOD if good else VCDefs.COL_BAD)
