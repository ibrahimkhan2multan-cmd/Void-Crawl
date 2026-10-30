class_name VCPetsPanel
extends Control
## PETS: your companions (equip, upgrade) and the egg shop (buy and hatch eggs, see the odds).

signal closed

var _tab := "pets"
var _list: VBoxContainer
var _status: Label
var _coins: Label
var _tab_pets: Button
var _tab_eggs: Button
var _hatch_box: Control = null
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = VCUI.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
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
	v.custom_minimum_size = Vector2(800, 0)
	panel.add_child(v)
	var head := VCUI.hbox(10)
	v.add_child(head)
	_tab_pets = VCUI.button("MY PETS", Vector2(190, 52), 22)
	_tab_pets.pressed.connect(_set_tab.bind("pets"))
	head.add_child(_tab_pets)
	_tab_eggs = VCUI.button("EGGS", Vector2(150, 52), 22)
	_tab_eggs.pressed.connect(_set_tab.bind("eggs"))
	head.add_child(_tab_eggs)
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
	_status.custom_minimum_size = Vector2(760, 28)
	v.add_child(_status)
	var back := VCUI.button("BACK", Vector2(800, 54), 24)
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
	VCUI.mark_tab(_tab_pets, _tab == "pets")
	VCUI.mark_tab(_tab_eggs, _tab == "eggs")
	for c in _list.get_children():
		c.queue_free()
	_hatch_box = null
	if _tab == "pets":
		_build_pets()
	else:
		_build_eggs()

# ------------------------------------------------------------------ pets
func _build_pets() -> void:
	var p: VCProfile = VC.profile
	var party := VCUI.label("Party: %d / %d active   (upgrade the Kennel for more slots)" % [p.pets_active.size(), p.pet_slots()], 17, VCDefs.COL_TEXT_DIM)
	_list.add_child(party)
	var feed := VCUI.button("Pets eat your potions to heal:  " + ("ON" if p.pet_feed else "OFF"), Vector2(740, 48), 18)
	feed.pressed.connect(func():
		p.pet_feed = not p.pet_feed
		VC.save_now()
		refresh())
	_list.add_child(feed)
	if p.pets.is_empty():
		var none := VCUI.label("You have no pets yet. Buy an egg in the EGGS tab, or defeat a dungeon boss - bosses drop eggs!", 19, VCDefs.COL_TEXT_DIM)
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		none.custom_minimum_size = Vector2(740, 0)
		_list.add_child(none)
		return
	var ids: Array = p.pets.keys()
	ids.sort_custom(func(a, b):
		var ra := VCPets.rarity_of(String(a))
		var rb := VCPets.rarity_of(String(b))
		return ra > rb if ra != rb else String(a) < String(b))
	for id in ids:
		_list.add_child(_pet_card(String(id)))

func _pet_card(id: String) -> Control:
	var p: VCProfile = VC.profile
	var d: Dictionary = VCPets.SPECIES[id]
	var lvl := int(p.pets[id])
	var active := p.pets_active.has(id)
	var rc := VCDefs.rarity_color(int(d["rarity"]))
	var pc := VCUI.panel(Color(0.04, 0.02, 0.08, 0.95), rc if active else rc.darkened(0.55))
	pc.mouse_filter = Control.MOUSE_FILTER_PASS
	var h := VCUI.hbox(10)
	pc.add_child(h)
	var ic := VCPetIcon.new()
	ic.custom_minimum_size = Vector2(96, 96)
	ic.set_species(id)
	h.add_child(ic)
	var tx := VCUI.vbox(1)
	tx.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(tx)
	tx.add_child(VCUI.label("%s   Lv %d / %d%s" % [String(d["name"]), lvl, VCProfile.MAX_PET_LEVEL, "   [ACTIVE]" if active else ""], 22, rc))
	tx.add_child(VCUI.label("%s  -  %s" % [VCDefs.rarity_name(int(d["rarity"])), "ranged" if String(d["ai"]) == "ranged" else "melee"], 14, VCDefs.COL_TEXT_DIM))
	tx.add_child(VCUI.label("Health %d   Damage %d   DPS %.0f" % [int(VCPets.max_hp(id, lvl, p.level)), int(VCPets.damage(id, lvl, p.level)), VCPets.dps(id, lvl, p.level)], 16, VCDefs.COL_TEXT))
	var pas := VCUI.label("While active: " + VCPets.passive_text(id), 15, VCDefs.COL_GOOD)
	pas.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pas.custom_minimum_size = Vector2(380, 0)
	tx.add_child(pas)
	var bv := VCUI.vbox(6)
	h.add_child(bv)
	var eq := VCUI.button("UNEQUIP" if active else "EQUIP", Vector2(190, 46), 19)
	eq.pressed.connect(_toggle.bind(id))
	bv.add_child(eq)
	var cost := VCPets.upgrade_cost(id, lvl)
	var up: Button
	if cost < 0:
		up = VCUI.button("MAX LEVEL", Vector2(190, 46), 18)
		up.disabled = true
	else:
		up = VCUI.button("UPGRADE  %d" % cost, Vector2(190, 46), 17)
		up.disabled = p.coins < cost
		up.pressed.connect(_upgrade.bind(id))
	bv.add_child(up)
	return pc

func _toggle(id: String) -> void:
	var err := VCPets.toggle_active(VC.profile, id)
	if err == "":
		VC.play_sfx("click", -6.0)
		VC.notify_profile_changed()
		VC.save_now()
		_say("Party updated.", true)
	else:
		_say(err, false)
	refresh()

func _upgrade(id: String) -> void:
	var err := VCPets.upgrade(VC.profile, id)
	if err == "":
		VC.play_sfx("levelup", -6.0)
		VC.notify_profile_changed()
		VC.save_now()
		_say("%s grew stronger!" % String(VCPets.SPECIES[id]["name"]), true)
	else:
		_say(err, false)
	refresh()

# ------------------------------------------------------------------ eggs
func _build_eggs() -> void:
	var p: VCProfile = VC.profile
	var info := VCUI.label("Buy eggs with coins, then hatch them. A duplicate pet levels up your existing one instead. Bosses also drop eggs.", 16, VCDefs.COL_TEXT_DIM)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size = Vector2(740, 0)
	_list.add_child(info)
	for tier in VCPets.EGG_ORDER:
		_list.add_child(_egg_card(String(tier)))
	_hatch_box = VCUI.vbox(4)
	_list.add_child(_hatch_box)

func _egg_card(tier: String) -> Control:
	var p: VCProfile = VC.profile
	var d: Dictionary = VCPets.EGGS[tier]
	var col: Color = d["color"]
	var owned := VCPets.egg_count(p, tier)
	var pc := VCUI.panel(Color(0.04, 0.02, 0.08, 0.95), col.darkened(0.2))
	pc.mouse_filter = Control.MOUSE_FILTER_PASS
	var h := VCUI.hbox(10)
	pc.add_child(h)
	var ic := VCPetIcon.new()
	ic.custom_minimum_size = Vector2(84, 96)
	ic.set_egg(tier)
	h.add_child(ic)
	var tx := VCUI.vbox(2)
	tx.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(tx)
	tx.add_child(VCUI.label("%s    owned: %d" % [String(d["name"]), owned], 22, col))
	var odds: Array = d["odds"]
	var parts: Array = []
	for r in odds.size():
		if float(odds[r]) > 0.0:
			parts.append("%s %s%%" % [VCDefs.rarity_name(r), ("%.0f" % float(odds[r])) if float(odds[r]) >= 1.0 else str(odds[r])])
	var ot := VCUI.label("Chances:  " + "  |  ".join(parts), 15, VCDefs.COL_TEXT_DIM)
	ot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ot.custom_minimum_size = Vector2(430, 0)
	tx.add_child(ot)
	var bv := VCUI.vbox(6)
	h.add_child(bv)
	var buy := VCUI.button("BUY  %d" % int(d["cost"]), Vector2(190, 46), 19)
	buy.disabled = p.coins < int(d["cost"])
	buy.pressed.connect(_buy_egg.bind(tier))
	bv.add_child(buy)
	var hatch := VCUI.button("HATCH", Vector2(190, 46), 19)
	hatch.disabled = owned <= 0
	hatch.pressed.connect(_hatch.bind(tier))
	bv.add_child(hatch)
	return pc

func _buy_egg(tier: String) -> void:
	var err := VCPets.buy_egg(VC.profile, tier)
	if err == "":
		VC.play_sfx("pickup", -3.0)
		VC.notify_profile_changed()
		VC.save_now()
		_say("%s bought." % String(VCPets.EGGS[tier]["name"]), true)
	else:
		_say(err, false)
	refresh()

func _hatch(tier: String) -> void:
	var res := VCPets.hatch(VC.profile, tier, _rng)
	if not bool(res["ok"]):
		_say(String(res["msg"]), false)
		return
	VC.play_sfx("levelup", -4.0)
	VC.notify_profile_changed()
	VC.save_now()
	var rid := String(res["id"])
	refresh()
	if _hatch_box != null and VCPets.SPECIES.has(rid):
		var rc := VCDefs.rarity_color(VCPets.rarity_of(rid))
		var pc := VCUI.panel(Color(0.08, 0.05, 0.14, 0.98), rc)
		var h := VCUI.hbox(12)
		pc.add_child(h)
		var ic := VCPetIcon.new()
		ic.custom_minimum_size = Vector2(110, 110)
		ic.set_species(rid)
		h.add_child(ic)
		var tv := VCUI.vbox(2)
		h.add_child(tv)
		tv.add_child(VCUI.label("HATCHED!  " + String(VCPets.SPECIES[rid]["name"]), 26, rc))
		tv.add_child(VCUI.label(String(res["msg"]), 18, VCDefs.COL_TEXT))
		var bl := VCUI.label(String(VCPets.SPECIES[rid]["blurb"]), 15, VCDefs.COL_TEXT_DIM)
		bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		bl.custom_minimum_size = Vector2(500, 0)
		tv.add_child(bl)
		_hatch_box.add_child(pc)
		pc.modulate.a = 0.0
		pc.scale = Vector2(0.8, 0.8)
		var tw := create_tween().set_parallel(true)
		tw.tween_property(pc, "modulate:a", 1.0, 0.35)
		tw.tween_property(pc, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_say(String(res["msg"]), true)

func _say(t: String, good: bool) -> void:
	_status.text = t
	_status.add_theme_color_override("font_color", VCDefs.COL_GOOD if good else VCDefs.COL_BAD)
