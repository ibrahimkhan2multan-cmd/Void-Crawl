class_name VCInventoryScreen
extends Control
## PACK (equipment + inventory grid + item detail with live comparison) and HERO
## (attributes + derived stats). Everything reads and writes VC.profile; nothing is cosmetic.

signal closed
signal changed(kind)          # "equip" | "unequip" | "sell" | "attr"

var tab := "pack"
var _sel := {}                # {"src": "inv"|"eq", "i": int}
var _body: Control
var _title: Label
var _coins: Label
var _tab_pack: Button
var _tab_hero: Button
var _ready_done := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = VCUI.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.03, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var m := VCUI.safe_margins(get_viewport(), 20.0)
	var panel := VCUI.panel()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = float(m["left"])
	panel.offset_right = -float(m["right"])
	panel.offset_top = float(m["top"])
	panel.offset_bottom = -float(m["bottom"])
	add_child(panel)
	var root := VCUI.vbox(8)
	panel.add_child(root)
	var head := VCUI.hbox(10)
	root.add_child(head)
	_tab_pack = VCUI.button("PACK", Vector2(150, 54), 24)
	_tab_pack.pressed.connect(func(): set_tab("pack"))
	head.add_child(_tab_pack)
	_tab_hero = VCUI.button("HERO", Vector2(150, 54), 24)
	_tab_hero.pressed.connect(func(): set_tab("hero"))
	head.add_child(_tab_hero)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	_coins = VCUI.label("", 26, VCDefs.COL_COIN)
	head.add_child(_coins)
	var close := VCUI.button("CLOSE", Vector2(150, 54), 24)
	close.pressed.connect(close_screen)
	head.add_child(close)
	_body = Control.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(_body)
	_ready_done = true
	refresh()

func set_tab(t: String) -> void:
	tab = t
	VC.play_sfx("click", -4.0)
	refresh()

func close_screen() -> void:
	VC.play_sfx("back", -4.0)
	closed.emit()

func _clear_body() -> void:
	for c in _body.get_children():
		c.queue_free()

func refresh() -> void:
	if not _ready_done:
		return
	_clear_body()
	var p: VCProfile = VC.profile
	_coins.text = "%d coins" % p.coins
	_tab_pack.disabled = tab == "pack"
	_tab_hero.disabled = tab == "hero"
	if tab == "pack":
		_build_pack()
	else:
		_build_hero()

# --------------------------------------------------------------------- PACK
func _build_pack() -> void:
	var p: VCProfile = VC.profile
	var row := VCUI.hbox(14)
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	_body.add_child(row)

	# equipped column
	var eqv := VCUI.vbox(3)
	eqv.custom_minimum_size = Vector2(250, 0)
	row.add_child(eqv)
	eqv.add_child(VCUI.label("EQUIPPED", 20, VCDefs.COL_VIOLET))
	for slot in VCDefs.SLOT_COUNT:
		var h := VCUI.hbox(8)
		eqv.add_child(h)
		var ic := VCItemIcon.new()
		ic.custom_minimum_size = Vector2(62, 62)
		ic.slot_hint = slot
		var it: Dictionary = p.equipment.get(slot, {})
		ic.set_item(it)
		ic.tag = {"src": "eq", "i": slot}
		ic.selected = _sel.get("src", "") == "eq" and int(_sel.get("i", -1)) == slot
		ic.tapped.connect(_on_icon)
		h.add_child(ic)
		var nm := VCUI.vbox(0)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(nm)
		nm.add_child(VCUI.label(VCDefs.SLOT_NAMES[slot], 16, VCDefs.COL_TEXT_DIM))
		var l := VCUI.label(String(it.get("name", "- empty -")), 18, VCDefs.rarity_color(int(it.get("rarity", 0))) if not it.is_empty() else VCDefs.COL_TEXT_DIM)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(130, 0)
		nm.add_child(l)
	var d := p.derived()
	eqv.add_child(VCUI.spacer(6))
	eqv.add_child(VCUI.label("Power  %d" % int(d["power"]), 22, VCDefs.COL_VIOLET))

	# inventory grid
	var mid := VCUI.vbox(8)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(mid)
	var hh := VCUI.hbox(10)
	mid.add_child(hh)
	hh.add_child(VCUI.label("BACKPACK  %d / %d" % [p.inventory.size(), p.inv_cap()], 20, VCDefs.COL_VIOLET))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hh.add_child(sp)
	var sort_b := VCUI.button("SORT", Vector2(110, 44), 18)
	sort_b.pressed.connect(_sort)
	hh.add_child(sort_b)
	var junk_b := VCUI.button("SELL COMMON", Vector2(170, 44), 18)
	junk_b.pressed.connect(_sell_commons)
	hh.add_child(junk_b)
	var auto_b := VCUI.button("AUTO", Vector2(100, 44), 18)
	auto_b.pressed.connect(_open_auto)
	hh.add_child(auto_b)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	mid.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)
	for i in p.inv_cap():
		var ic2 := VCItemIcon.new()
		ic2.custom_minimum_size = Vector2(78, 78)
		if i < p.inventory.size():
			ic2.set_item(p.inventory[i])
			ic2.tag = {"src": "inv", "i": i}
			ic2.selected = _sel.get("src", "") == "inv" and int(_sel.get("i", -1)) == i
			ic2.tapped.connect(_on_icon)
		grid.add_child(ic2)

	# detail
	var det := VCUI.panel(Color(0.04, 0.02, 0.08, 0.95), Color(0.3, 0.16, 0.5))
	det.custom_minimum_size = Vector2(380, 0)
	row.add_child(det)
	var dv := VCUI.vbox(6)
	det.add_child(dv)
	_build_detail(dv)

func _selected_item() -> Dictionary:
	var p: VCProfile = VC.profile
	if _sel.is_empty():
		return {}
	if _sel["src"] == "inv":
		var i := int(_sel["i"])
		return p.inventory[i] if i < p.inventory.size() else {}
	return p.equipment.get(int(_sel["i"]), {})

func _build_detail(dv: VBoxContainer) -> void:
	var p: VCProfile = VC.profile
	var it := _selected_item()
	if it.is_empty():
		dv.add_child(VCUI.label("Select an item", 24, VCDefs.COL_TEXT_DIM))
		dv.add_child(VCUI.label("Tap gear in your backpack to compare it with what you are wearing. Equipping really changes your combat stats.", 18, VCDefs.COL_TEXT_DIM))
		_autowrap_last(dv)
		return
	# description area scrolls so long text never pushes EQUIP / SELL off the screen
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, 120)
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	dv.add_child(scroll)
	var info := VCUI.vbox(6)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(info)
	var rc := VCDefs.rarity_color(int(it["rarity"]))
	var nm := VCUI.label(String(it["name"]), 26, rc)
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(nm)
	info.add_child(VCUI.label("%s  -  %s  -  item level %d" % [VCDefs.rarity_name(int(it["rarity"])), VCDefs.SLOT_NAMES[int(it["slot"])], int(it["ilvl"])], 16, VCDefs.COL_TEXT_DIM))
	for line in VCItems.describe(it):
		info.add_child(VCUI.label(String(line), 19, VCDefs.COL_TEXT))
	_add_set_info(info, it)
	if _sel["src"] == "inv":
		info.add_child(VCUI.spacer(4))
		info.add_child(VCUI.label("IF YOU EQUIP IT", 16, VCDefs.COL_VIOLET))
		var now := p.derived()
		var nxt := p.preview_derived(it)
		_cmp(info, "Damage / hit", _avg_hit(now), _avg_hit(nxt), "%.0f")
		_cmp(info, "Damage / sec", VCProfile.dps_of(now), VCProfile.dps_of(nxt), "%.1f")
		_cmp(info, "Max health", float(now["max_hp"]), float(nxt["max_hp"]), "%.0f")
		_cmp(info, "Armor", float(now["armor"]), float(nxt["armor"]), "%.1f")
		_cmp(info, "Crit chance", float(now["crit"]) * 100.0, float(nxt["crit"]) * 100.0, "%.0f%%")
		_cmp(info, "Move speed", float(now["move_speed"]), float(nxt["move_speed"]), "%.2f")
		_cmp(info, "Cooldown mult", float(now["cd_mult"]) * 100.0, float(nxt["cd_mult"]) * 100.0, "%.0f%%", true)
	var bh := VCUI.hbox(10)
	dv.add_child(bh)
	if _sel["src"] == "inv":
		var eq := VCUI.button("EQUIP", Vector2(150, 60), 24)
		eq.pressed.connect(_do_equip)
		bh.add_child(eq)
		var sell := VCUI.button("SELL +%d" % VCItems.sell_value(it), Vector2(170, 60), 22)
		sell.pressed.connect(_do_sell)
		bh.add_child(sell)
	else:
		var ue := VCUI.button("UNEQUIP", Vector2(170, 60), 22)
		ue.disabled = p.inventory.size() >= p.inv_cap()
		ue.pressed.connect(_do_unequip)
		bh.add_child(ue)

func _add_set_info(dv: VBoxContainer, it: Dictionary) -> void:
	var sid := VCSets.set_of(it)
	if sid == "" or not VCSets.DEFS.has(sid):
		return
	var d: Dictionary = VCSets.DEFS[sid]
	var have: int = int(VCSets.counts(VC.profile.equipment).get(sid, 0))
	if _sel.get("src", "") == "inv":
		# what the count would be after equipping this piece (it replaces the same slot)
		var cur: Dictionary = VC.profile.equipment.get(int(it["slot"]), {})
		have += 1 - (1 if VCSets.set_of(cur) == sid else 0)
	dv.add_child(VCUI.spacer(2))
	var gcol: Color = d["glow"]
	var total_pcs: int = (d["pieces"] as Dictionary).size()
	dv.add_child(VCUI.label("%s  (%d/%d)" % [String(d["name"]), have, total_pcs], 19, gcol))
	var l2 := VCUI.label("2 pieces: %s" % String(d["t2"]), 16, gcol if have >= 2 else VCDefs.COL_TEXT_DIM)
	l2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l2.custom_minimum_size = Vector2(340, 0)
	dv.add_child(l2)
	var l4 := VCUI.label("4 pieces: %s" % String(d["t4"]), 16, gcol if have >= 4 else VCDefs.COL_TEXT_DIM)
	l4.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l4.custom_minimum_size = Vector2(340, 0)
	dv.add_child(l4)
	if d.has("b5") and not (d["b5"] as Dictionary).is_empty():
		var l5 := VCUI.label("5 pieces: %s" % String(d.get("t5", "")), 16, gcol if have >= 5 else VCDefs.COL_TEXT_DIM)
		l5.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l5.custom_minimum_size = Vector2(340, 0)
		dv.add_child(l5)

func _autowrap_last(dv: VBoxContainer) -> void:
	var l := dv.get_child(dv.get_child_count() - 1) as Label
	if l != null:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(330, 0)

func _avg_hit(d: Dictionary) -> float:
	return (float(d["dmg_min"]) + float(d["dmg_max"])) * 0.5 * float(d["dmg_mult"])

func _cmp(dv: VBoxContainer, label: String, a: float, b: float, fmt: String, lower_better: bool = false) -> void:
	var delta := b - a
	var good := -delta if lower_better else delta
	var h := VCUI.hbox(6)
	var l := VCUI.label(label, 17, VCDefs.COL_TEXT_DIM)
	l.custom_minimum_size = Vector2(130, 0)
	h.add_child(l)
	var v := VCUI.label((fmt % a) + "  ->  " + (fmt % b), 17, VCDefs.COL_TEXT)
	v.custom_minimum_size = Vector2(130, 0)
	h.add_child(v)
	var arrow := "=" if absf(delta) < 0.005 else ("+" if good > 0.0 else "-")
	var dl := VCUI.label(("UP" if good > 0.005 else ("DOWN" if good < -0.005 else "same")), 16, VCUI.delta_color(good))
	dl.text = ("^ " if good > 0.005 else ("v " if good < -0.005 else "= ")) + ("%+.1f" % delta if absf(delta) >= 0.005 else "")
	h.add_child(dl)
	arrow = arrow
	dv.add_child(h)

func _on_icon(ic: VCItemIcon) -> void:
	_sel = ic.tag.duplicate()
	if ic.item.is_empty() and _sel.get("src", "") == "eq":
		_sel = {}
	VC.play_sfx("click", -6.0)
	refresh()

func _do_equip() -> void:
	var p: VCProfile = VC.profile
	if _sel.get("src", "") != "inv":
		return
	var i := int(_sel["i"])
	if i >= p.inventory.size():
		return
	var slot := int(p.inventory[i]["slot"])
	if p.equip_from_inventory(i):
		VC.play_sfx("pickup")
		_sel = {"src": "eq", "i": slot}
		VC.notify_profile_changed()
		changed.emit("equip")
		refresh()

func _do_unequip() -> void:
	var p: VCProfile = VC.profile
	if _sel.get("src", "") != "eq":
		return
	if p.unequip(int(_sel["i"])):
		VC.play_sfx("back", -4.0)
		_sel = {"src": "inv", "i": p.inventory.size() - 1}
		VC.notify_profile_changed()
		changed.emit("unequip")
		refresh()

func _do_sell() -> void:
	var p: VCProfile = VC.profile
	if _sel.get("src", "") != "inv":
		return
	var v := p.sell_item(int(_sel["i"]))
	if v > 0:
		VC.play_sfx("coin")
		_sel = {}
		VC.notify_profile_changed()
		changed.emit("sell")
		refresh()

func _sell_commons() -> void:
	var p: VCProfile = VC.profile
	var total := 0
	var i := p.inventory.size() - 1
	while i >= 0:
		if int(p.inventory[i]["rarity"]) == VCDefs.Rarity.COMMON:
			total += p.sell_item(i)
		i -= 1
	if total > 0:
		VC.play_sfx("coin")
		_sel = {}
		VC.notify_profile_changed()
		changed.emit("sell")
	refresh()

func _open_auto() -> void:
	var up := VCUpgradesPanel.new()
	up.start_tab = "auto"
	up.closed.connect(func():
		up.queue_free()
		_sel = {}
		refresh())
	add_child(up)

func _sort() -> void:
	var p: VCProfile = VC.profile
	p.inventory.sort_custom(func(a, b):
		if int(a["rarity"]) != int(b["rarity"]):
			return int(a["rarity"]) > int(b["rarity"])
		if int(a["slot"]) != int(b["slot"]):
			return int(a["slot"]) < int(b["slot"])
		return VCItems.score(a) > VCItems.score(b))
	_sel = {}
	VC.play_sfx("click")
	refresh()

# --------------------------------------------------------------------- HERO
func _build_hero() -> void:
	var p: VCProfile = VC.profile
	var d := p.derived()
	var row := VCUI.hbox(18)
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	_body.add_child(row)
	var left := VCUI.vbox(8)
	left.custom_minimum_size = Vector2(500, 0)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left)
	left.add_child(VCUI.label("THE VOIDWALKER", 30, Color.WHITE))
	left.add_child(VCUI.label("Level %d%s" % [p.level, "  (MAX)" if p.level >= VCProfile.MAX_LEVEL else ""], 24, VCDefs.COL_VIOLET))
	var xb := VCBar.new()
	xb.custom_minimum_size = Vector2(420, 22)
	xb.color = VCDefs.COL_XP
	xb.show_ghost = false
	if p.level < VCProfile.MAX_LEVEL:
		xb.set_values(float(p.xp), float(p.xp_needed()))
		xb.text = "%d / %d XP" % [p.xp, p.xp_needed()]
	else:
		xb.set_values(1.0, 1.0)
		xb.text = "MAX LEVEL"
	xb.font_size = 16
	xb.snap()
	left.add_child(xb)
	left.add_child(VCUI.spacer(6))
	left.add_child(VCUI.label("ATTRIBUTES  -  %d point%s to spend" % [p.attr_points, "" if p.attr_points == 1 else "s"], 20, VCDefs.COL_COIN if p.attr_points > 0 else VCDefs.COL_TEXT_DIM))
	for a in VCDefs.ATTR_IDS:
		var h := VCUI.hbox(10)
		left.add_child(h)
		var v := VCUI.vbox(0)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(v)
		v.add_child(VCUI.label("%s   %d" % [VCDefs.ATTR_NAMES[a], int(p.attrs[a])], 24, Color.WHITE))
		v.add_child(VCUI.label(String(VCDefs.ATTR_DESC[a]), 16, VCDefs.COL_TEXT_DIM))
		var b := VCUI.button("+", Vector2(64, 56), 30)
		b.disabled = p.attr_points <= 0
		b.pressed.connect(func(): _spend(a))
		h.add_child(b)
	var right := VCUI.panel(Color(0.04, 0.02, 0.08, 0.95), Color(0.3, 0.16, 0.5))
	right.custom_minimum_size = Vector2(420, 0)
	row.add_child(right)
	var rv := VCUI.vbox(4)
	right.add_child(rv)
	rv.add_child(VCUI.label("COMBAT STATS", 20, VCDefs.COL_VIOLET))
	_stat(rv, "Max health", "%d" % int(d["max_hp"]))
	_stat(rv, "Armor", "%.1f   (%.0f%% less damage)" % [float(d["armor"]), float(d["armor"]) / (float(d["armor"]) + 45.0) * 100.0])
	_stat(rv, "Damage / hit", "%d - %d" % [int(round(float(d["dmg_min"]) * float(d["dmg_mult"]))), int(round(float(d["dmg_max"]) * float(d["dmg_mult"])))])
	_stat(rv, "Damage / sec", "%.1f" % VCProfile.dps_of(d))
	_stat(rv, "Attack speed", "%.2f / sec" % (1.0 / float(d["interval"])))
	_stat(rv, "Crit chance", "%.0f%%" % (float(d["crit"]) * 100.0))
	_stat(rv, "Move speed", "%.2f" % float(d["move_speed"]))
	_stat(rv, "Void Nova cooldown", "%.1f s" % (9.0 * float(d["cd_mult"])))
	_stat(rv, "Life leech", "%.0f%%" % (float(d["leech"]) * 100.0))
	rv.add_child(VCUI.spacer(6))
	rv.add_child(VCUI.label("ADVENTURE", 20, VCDefs.COL_VIOLET))
	_stat(rv, "Enemies defeated", str(int(p.stats["kills"])))
	_stat(rv, "Chests opened", str(int(p.stats["chests"])))
	_stat(rv, "Bosses slain", str(int(p.stats["bosses"])))
	_stat(rv, "Times fallen", str(int(p.stats["deaths"])))
	var pt := int(float(p.stats["playtime"]))
	_stat(rv, "Time in the dark", "%dm %02ds" % [pt / 60, pt % 60])

func _stat(parent: Control, label: String, value: String) -> void:
	var h := VCUI.hbox(6)
	var l := VCUI.label(label, 19, VCDefs.COL_TEXT_DIM)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	h.add_child(VCUI.label(value, 19, VCDefs.COL_TEXT, HORIZONTAL_ALIGNMENT_RIGHT))
	parent.add_child(h)

func _spend(attr: String) -> void:
	if VC.profile.spend_point(attr):
		VC.play_sfx("pickup", -3.0, 1.2)
		VC.notify_profile_changed()
		changed.emit("attr")
		refresh()
