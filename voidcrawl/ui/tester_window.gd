class_name VCTesterWindow
extends Control
## The TESTER menu: a draggable floating window that changes the live game (stats, toggles, spawning, items,
## teleports...). In a dungeon `world` is the VCMission; on the main menu it is null and dungeon-only
## actions are disabled. Opened with the secret code TESTER (see VCCodes / VCTester).

signal closed

var world: VCMission = null
var _win: PanelContainer
var _body: VBoxContainer
var _tab := "player"
var _tabs: Dictionary = {}
var _status: Label
var _info_label: Label
var _info_t := 0.0
var _drag := false
var _drag_off := Vector2.ZERO
var _spawn_level := 5
var _gen_rarity := 3
var _gen_ilvl := 8
var _gen_slot := -1
var _spawn_last := ""
var _scroll: ScrollContainer
var _min := false
var _freeze_btn: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = VCUI.theme()
	_win = VCUI.panel(Color(0.03, 0.02, 0.07, 0.93), Color(0.25, 1.0, 0.7))
	_win.position = Vector2(14, 70)
	_win.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_win)
	var v := VCUI.vbox(6)
	v.custom_minimum_size = Vector2(500, 0)
	_win.add_child(v)
	# title bar (drag handle)
	var bar := VCUI.hbox(8)
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	bar.gui_input.connect(_bar_input)
	v.add_child(bar)
	var title := VCUI.label("TESTER  (drag me)", 22, Color(0.4, 1.0, 0.8))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.mouse_filter = Control.MOUSE_FILTER_PASS
	bar.add_child(title)
	if world != null:
		_freeze_btn = VCUI.button("", Vector2(112, 40), 15)
		_freeze_btn.pressed.connect(func():
			VCSettings.set_value("tester_freeze", not bool(VCSettings.get_value("tester_freeze")))
			VCSettings.save_settings()
			world.apply_tester_freeze()
			_update_freeze_btn())
		bar.add_child(_freeze_btn)
		_update_freeze_btn()
	var mn := VCUI.button("_", Vector2(48, 40), 20)
	mn.pressed.connect(func():
		_min = not _min
		_apply_min())
	bar.add_child(mn)
	var x := VCUI.button("X", Vector2(48, 40), 20)
	x.pressed.connect(func(): closed.emit())
	bar.add_child(x)
	var tb := VCUI.hbox(4)
	tb.name = "TabBar"
	v.add_child(tb)
	for t in [["player", "PLAYER"], ["world", "WORLD"], ["spawn", "SPAWN"], ["items", "ITEMS"], ["info", "INFO"]]:
		var b := VCUI.button(String(t[1]), Vector2(92, 40), 15)
		b.pressed.connect(_set_tab.bind(String(t[0])))
		tb.add_child(b)
		_tabs[String(t[0])] = b
	_scroll = ScrollContainer.new()
	_scroll.name = "Scroll"
	var vh := get_viewport_rect().size.y if is_inside_tree() else 720.0
	_scroll.custom_minimum_size = Vector2(0, clampf(vh - 250.0, 150.0, 400.0))
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	v.add_child(_scroll)
	_body = VCUI.vbox(6)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.mouse_filter = Control.MOUSE_FILTER_PASS
	_scroll.add_child(_body)
	_status = VCUI.label("", 16, VCDefs.COL_GOOD)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(480, 22)
	_status.name = "Status"
	v.add_child(_status)
	_set_tab("player")

func _update_freeze_btn() -> void:
	if _freeze_btn != null:
		_freeze_btn.text = "FREEZE: ON" if bool(VCSettings.get_value("tester_freeze")) else "FREEZE: OFF"

func _apply_min() -> void:
	_scroll.visible = not _min
	_status.visible = not _min
	(_win.find_child("TabBar", true, false) as Control).visible = not _min
	_win.reset_size()

func _bar_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_drag = ev.pressed
		_drag_off = _win.position - get_global_mouse_position()
	elif ev is InputEventMouseMotion and _drag:
		var vs := get_viewport_rect().size
		_win.position = (get_global_mouse_position() + _drag_off).clamp(Vector2(-300, 0), vs - Vector2(120, 60))

func _set_tab(t: String) -> void:
	_tab = t
	for k in _tabs:
		VCUI.mark_tab(_tabs[k] as Button, k == t)
	_rebuild()

func _rebuild() -> void:
	for c in _body.get_children():
		c.queue_free()
	_info_label = null
	match _tab:
		"player": _build_player()
		"world": _build_world()
		"spawn": _build_spawn()
		"items": _build_items()
		"info": _build_info()

func _say(t: String, good: bool = true) -> void:
	_status.text = t
	_status.add_theme_color_override("font_color", VCDefs.COL_GOOD if good else VCDefs.COL_BAD)

func _live() -> bool:
	return world != null and is_instance_valid(world) and world.build_done and world.player != null

func _need_world() -> bool:
	if _live():
		return true
	_say("Needs a dungeon - start a run first.", false)
	return false

func _refresh_player() -> void:
	if _live():
		world.player.refresh_stats(false)
		VC.notify_profile_changed()

# ---------------------------------------------------------------- widgets
func _head(text: String) -> void:
	_body.add_child(VCUI.label(text, 17, Color(0.5, 0.9, 1.0)))

func _stepper(label: String, get_text: Callable, on_step: Callable) -> void:
	var h := VCUI.hbox(6)
	var l := VCUI.label(label, 18, VCDefs.COL_TEXT)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	var val := VCUI.label(String(get_text.call()), 18, VCDefs.COL_COIN, HORIZONTAL_ALIGNMENT_CENTER)
	val.custom_minimum_size = Vector2(88, 0)
	var minus := VCUI.button("-", Vector2(54, 44), 24)
	var plus := VCUI.button("+", Vector2(54, 44), 24)
	minus.pressed.connect(func():
		on_step.call(-1)
		val.text = String(get_text.call()))
	plus.pressed.connect(func():
		on_step.call(1)
		val.text = String(get_text.call()))
	h.add_child(minus)
	h.add_child(val)
	h.add_child(plus)
	_body.add_child(h)

func _toggle(key: String) -> void:
	var b := VCUI.button("", Vector2(0, 44), 17)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var upd := func():
		var on := bool(VCTester.switches.get(key, false))
		b.text = "%s   %s" % ["[ON] " if on else "[off]", String(VCTester.TOGGLES[key])]
		b.add_theme_color_override("font_color", Color(0.5, 1.0, 0.7) if on else VCDefs.COL_TEXT_DIM)
	upd.call()
	b.pressed.connect(func():
		VCTester.set_switch(key, not bool(VCTester.switches.get(key, false)))
		upd.call()
		_say("%s: %s" % [String(VCTester.TOGGLES[key]), "ON" if VCTester.switches[key] else "off"]))
	_body.add_child(b)

func _action(label: String, fn: Callable, cols_with: Button = null) -> Button:
	var b := VCUI.button(label, Vector2(0, 46), 17)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(fn)
	_body.add_child(b)
	return b

func _row(btns: Array) -> void:
	var h := VCUI.hbox(6)
	for bd in btns:
		var b := VCUI.button(String(bd[0]), Vector2(0, 46), 16)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(bd[1])
		h.add_child(b)
	_body.add_child(h)

# ------------------------------------------------------------------ PLAYER
func _build_player() -> void:
	_head("LIVE STATS  (applied on top of your gear)")
	for key in VCTester.NUMERIC_ORDER:
		var k: String = key
		_stepper(String(VCTester.NUMERIC[k]["label"]), func(): return String(VCTester.NUMERIC[k]["fmt"]) % VCTester.num(k), func(d):
			VCTester.step(k, d)
			_refresh_player())
	_head("SWITCHES")
	for key in VCTester.TOGGLE_ORDER:
		_toggle(String(key))
	_head("QUICK")
	_row([["FULL HEAL", func():
		if _need_world():
			world.player.heal(float(world.player.max_hp), true)
			VC.profile.potions = VC.profile.max_potions()
			VC.profile.bombs = VC.profile.max_bombs()
			_say("Healed and restocked.")],
		["RESET ALL", func():
			VCTester.reset_all()
			_refresh_player()
			_rebuild()
			_say("All tester overrides reset.")]])

# ------------------------------------------------------------------- WORLD
func _build_world() -> void:
	_head("TIME")
	_stepper("Game speed", func(): return "x%.2f" % Engine.time_scale, func(d):
		Engine.time_scale = clampf(snappedf(Engine.time_scale + 0.25 * float(d), 0.01), 0.25, 3.0))
	_head("DUNGEON")
	_row([["KILL ALL ENEMIES", func():
		if _need_world():
			var n := 0
			for e in world.enemies.duplicate():
				if is_instance_valid(e) and e.is_alive():
					e.invulnerable = false
					e.take_hit(999999.0, e.global_position, false, 0.0, world.player)
					n += 1
			_say("Defeated %d enemies." % n)],
		["SET CHECKPOINT HERE", func():
			if _need_world():
				var rid := int(world._last_room)
				if rid >= 0:
					world._set_checkpoint(rid, "Checkpoint saved  -  tester")
					_say("Checkpoint set to room %d." % rid)
				else:
					_say("Stand inside a room first.", false)]])
	_row([["TO START", func():
		if _need_world():
			_teleport(world.data.tile_to_world(world.data.start_tile))],
		["TO BOSS ROOM", func():
			if _need_world():
				if world.data.boss_room >= 0:
					_teleport(world.data.tile_to_world(world.data.nearest_floor((world.data.rooms[world.data.boss_room]["center"] as Vector2i) + Vector2i(0, 8))))
				else:
					_say("This dungeon has no boss room.", false)],
		["TO VOID GATE", func():
			if _need_world():
				_teleport(world.data.tile_to_world(world.data.nearest_floor(world.data.exit_tile)))]])
	_action("OPEN THE VOID GATE (skip the boss)", func():
		if _need_world():
			world.boss_state = "dead"
			world.counters["boss"] = 1
			world.counters["boss_room"] = 1
			world._check_gate_unlock()
			world._update_objectives()
			_say("Void Gate unlocked."))
	_action("OVERLAP / Z-FIGHT AUDIT OF EVERYTHING NEAR YOU", func():
		if _need_world():
			var n := 0
			var names: Array = []
			var nodes: Array = [world.player.rig]
			for e in world.enemies:
				if is_instance_valid(e) and e.rig != null:
					nodes.append(e.rig)
			for b in world.breakables:
				if is_instance_valid(b):
					nodes.append(b)
			for nd in nodes:
				var hits := VCZAudit.find(nd)
				if not hits.is_empty():
					n += hits.size()
					names.append(String(nd.get_parent().name) if nd.get_parent() != null else String(nd.name))
			_say("Audit: %d overlapping face pair%s%s" % [n, "" if n == 1 else "s", ("  in " + ", ".join(names.slice(0, 4))) if n > 0 else "  - all clean"], n == 0))
	_head("PETS IN THE DUNGEON")
	_row([["REVIVE PETS", func():
		if _need_world():
			for p in world.pets:
				if is_instance_valid(p):
					p.respawn_now()
					p.hp = p.max_hp
			_say("Pets revived and healed.")],
		["HURT PETS 50%", func():
			if _need_world():
				for p in world.pets:
					if is_instance_valid(p) and not p.dead:
						p._invuln = 0.0
						p.take_damage(p.max_hp * 0.5, p.global_position + Vector3(1, 0, 0))
				_say("Pets hurt (watch them eat potions).")],
		["FALL", func():
			if _need_world():
				for p in world.pets:
					if is_instance_valid(p) and not p.dead:
						p._invuln = 0.0
						p.take_damage(999999.0, p.global_position + Vector3(1, 0, 0))
				_say("Pets fell - they return in 10 s.")]])

func _teleport(pos: Vector3) -> void:
	world.player.global_position = pos
	world.player.velocity = Vector3.ZERO
	world.cam_rig.snap_to(pos)
	for p in world.pets:
		if is_instance_valid(p) and not p.dead:
			p._teleport_to_player()
	_say("Teleported.")

# ------------------------------------------------------------------- SPAWN
func _build_spawn() -> void:
	_head("SPAWN ENEMIES  (in front of you)")
	_stepper("Enemy level", func(): return str(_spawn_level), func(d): _spawn_level = clampi(_spawn_level + d, 1, 40))
	_row([["x5 LAST", func(): _spawn_many(_spawn_last, 5)], ["x10 LAST", func(): _spawn_many(_spawn_last, 10)]])
	var ids: Array = VCEnemyDefs.DEFS.keys()
	ids.sort_custom(func(a, b):
		var aa := 1 if String(VCEnemyDefs.DEFS[a]["ai"]) == "boss" else 0
		var bb := 1 if String(VCEnemyDefs.DEFS[b]["ai"]) == "boss" else 0
		return aa < bb if aa != bb else String(VCEnemyDefs.DEFS[a]["name"]) < String(VCEnemyDefs.DEFS[b]["name"]))
	for id in ids:
		var d: Dictionary = VCEnemyDefs.DEFS[id]
		var lab := "%s%s   (hp %d)" % ["BOSS  " if String(d["ai"]) == "boss" else "", String(d["name"]), int(float(d["hp"]) * VCEnemyDefs.hp_scale(_spawn_level))]
		var sid: String = id
		_action(lab, func(): _spawn_many(sid, 1))

func _spawn_many(id: String, n: int) -> void:
	if not _need_world():
		return
	if id == "" or not VCEnemyDefs.DEFS.has(id):
		_say("Spawn something first.", false)
		return
	_spawn_last = id
	var fwd := Vector3(-sin(world.player.facing), 0, -cos(world.player.facing))
	for i in n:
		var ang := float(i) * 0.9
		var pos := world.player.global_position + fwd.rotated(Vector3.UP, ang) * (4.5 + 0.6 * float(i / 6))
		world.spawn_enemy_at(id, pos, int(world._last_room), _spawn_level)
	_say("Spawned %d x %s (level %d)." % [n, String(VCEnemyDefs.DEFS[id]["name"]), _spawn_level])

# ------------------------------------------------------------------- ITEMS
func _build_items() -> void:
	var P: VCProfile = VC.profile
	_head("GIVE GEAR  (goes into your pack)")
	_stepper("Rarity", func(): return VCDefs.rarity_name(_gen_rarity), func(d): _gen_rarity = clampi(_gen_rarity + d, 0, VCDefs.RARITY_MAX))
	_stepper("Item level", func(): return str(_gen_ilvl), func(d): _gen_ilvl = clampi(_gen_ilvl + d, 1, 40))
	_stepper("Slot", func(): return "Random" if _gen_slot < 0 else String(VCDefs.SLOT_NAMES[_gen_slot]), func(d): _gen_slot = clampi(_gen_slot + d, -1, VCDefs.SLOT_COUNT - 1))
	_row([["GIVE 1", func(): _give_gear(1)], ["GIVE 5", func(): _give_gear(5)], ["GIVE 20", func(): _give_gear(20)]])
	_head("ARMOUR SETS  (all 5 pieces at the rarity above)")
	var sids: Array = VCSets.DEFS.keys()
	sids.sort()
	for sid in sids:
		var s: String = sid
		_action("%s" % String(VCSets.DEFS[s]["name"]), func(): _give_set(s))
	_head("PETS")
	_row([["EGG: COMMON", func(): _give_egg("common")], ["EGG: RARE", func(): _give_egg("rare")]])
	_row([["EGG: EPIC", func(): _give_egg("epic")], ["EGG: MYTHIC", func(): _give_egg("mythic")]])
	_action("UNLOCK EVERY PET (level 5)", func():
		for id in VCPets.SPECIES:
			P.pets[String(id)] = maxi(int(P.pets.get(String(id), 0)), 5)
		_pets_changed()
		_say("All %d pets unlocked." % VCPets.SPECIES.size()))
	_action("MAX LEVEL ALL PETS", func():
		for id in P.pets.keys():
			P.pets[id] = VCProfile.MAX_PET_LEVEL
		_pets_changed()
		_say("Every pet is max level."))
	_head("PROGRESS")
	_row([["+1000 COINS", func(): _coins(1000)], ["+100,000", func(): _coins(100000)]])
	_row([["+1 LEVEL", func(): _levels(1)], ["+5 LEVELS", func(): _levels(5)], ["+5 POINTS", func():
		P.attr_points += 5
		_refresh_player()
		_say("+5 attribute points (open HERO).")]])
	_action("MAX ALL UPGRADES (backpack, belt, perks...)", func():
		for id in VCUpgrades.DEFS:
			P.upgrades[String(id)] = VCUpgrades.max_level(String(id))
		P.potions = P.max_potions()
		P.bombs = P.max_bombs()
		_refresh_player()
		_say("All shop upgrades maxed."))
	_action("UNLOCK EVERY DUNGEON", func():
		for id in VCMissions.ORDER:
			if not P.completed.has(String(id)):
				P.completed.append(String(id))
		_say("All dungeons unlocked."))
	_action("OWN EVERY PERK", func():
		for id in VCPerks.DEFS:
			if not P.perks_owned.has(String(id)):
				P.perks_owned.append(String(id))
		_say("All perks owned (equip them in PERKS)."))
	_action("CLEAR MY BACKPACK", func():
		P.inventory.clear()
		VC.notify_profile_changed()
		_say("Backpack emptied."))
	_action("REFILL POTIONS AND BOMBS", func():
		P.potions = P.max_potions()
		P.bombs = P.max_bombs()
		_say("Restocked."))
	_head("These grants are saved to your profile.")

func _give_gear(n: int) -> void:
	var P: VCProfile = VC.profile
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var given := 0
	for i in n:
		var it := VCItems.generate(rng, _gen_ilvl, _gen_rarity, _gen_slot, 0.0, P.alloc_uid())
		if P.add_item(it):
			given += 1
	VC.notify_profile_changed()
	_say("Gave %d item%s%s." % [given, "" if given == 1 else "s", "  (pack full)" if given < n else ""], given > 0)

func _give_set(sid: String) -> void:
	var P: VCProfile = VC.profile
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var n := 0
	var pieces: Dictionary = VCSets.DEFS[sid]["pieces"]
	for key in VCSets.PIECE_KEYS:
		if not pieces.has(key):
			continue
		var slot := -1
		for sl in VCSets.SLOT_KEYS:
			if String(VCSets.SLOT_KEYS[sl]) == String(key):
				slot = int(sl)
		var it := VCItems.generate(rng, _gen_ilvl, _gen_rarity, slot, 0.0, P.alloc_uid(), String(pieces[key]))
		if P.add_item(it):
			n += 1
	VC.notify_profile_changed()
	_say("Gave %d piece%s of %s." % [n, "" if n == 1 else "s", String(VCSets.DEFS[sid]["name"])], n > 0)

func _give_egg(tier: String) -> void:
	VC.profile.eggs[tier] = VCPets.egg_count(VC.profile, tier) + 1
	_say("+1 %s  (hatch in PETS)." % String(VCPets.EGGS[tier]["name"]))

func _pets_changed() -> void:
	var P: VCProfile = VC.profile
	if P.pets_active.is_empty():
		for id in P.pets:
			if P.pets_active.size() < P.pet_slots():
				P.pets_active.append(String(id))
	if _live():
		world._spawn_pets()
	_refresh_player()

func _coins(n: int) -> void:
	VC.profile.coins += n
	VC.notify_profile_changed()
	_say("+%d coins (now %d)." % [n, VC.profile.coins])

func _levels(n: int) -> void:
	var P: VCProfile = VC.profile
	for i in n:
		P.add_xp(P.xp_needed())
	_refresh_player()
	if _live():
		world.player.heal(float(world.player.max_hp), true)
	_say("Level %d." % P.level)

# -------------------------------------------------------------------- INFO
func _build_info() -> void:
	_info_label = VCUI.label("", 17, VCDefs.COL_TEXT)
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_label.custom_minimum_size = Vector2(470, 0)
	_body.add_child(_info_label)
	_update_info()

func _update_info() -> void:
	if _info_label == null:
		return
	var P: VCProfile = VC.profile
	var d := P.derived()
	var lines: Array = []
	lines.append("FPS %d    overrides active: %d" % [Engine.get_frames_per_second(), VCTester.active_count()])
	lines.append("Level %d   coins %d   pack %d/%d" % [P.level, P.coins, P.inventory.size(), P.inv_cap()])
	lines.append("Max HP %d   armor %.1f   crit %.0f%%   leech %.0f%%" % [int(d["max_hp"]), float(d["armor"]), float(d["crit"]) * 100.0, float(d["leech"]) * 100.0])
	lines.append("Damage/hit %d-%d   DPS %.1f   speed %.2f" % [int(float(d["dmg_min"]) * float(d["dmg_mult"])), int(float(d["dmg_max"]) * float(d["dmg_mult"])), VCProfile.dps_of(d), float(d["move_speed"])])
	lines.append("Potions %d/%d   bombs %d/%d   perk slots %d   pets %d/%d" % [P.potions, P.max_potions(), P.bombs, P.max_bombs(), P.perk_slots(), P.pets_active.size(), P.pet_slots()])
	if _live():
		lines.append("Dungeon: %s   seed %d   room %d   checkpoint room %d" % [world.mission_id, world.seed_, int(world._last_room), world.checkpoint_room])
		var alive := 0
		for e in world.enemies:
			if is_instance_valid(e) and e.is_alive():
				alive += 1
		lines.append("Enemies alive %d   pickups %d   pets %d" % [alive, world.pickups.size(), world.pets.size()])
		lines.append("Hero HP %d / %d   at (%.1f, %.1f)" % [int(world.player.hp), world.player.max_hp, world.player.global_position.x, world.player.global_position.z])
		var rarest := ""
		for pt in world.pets:
			if is_instance_valid(pt):
				rarest += "%s %d/%d%s   " % [pt.display_name, int(pt.hp), int(pt.max_hp), " (down %.0fs)" % pt.respawn_t if pt.dead else ""]
		if rarest != "":
			lines.append("Pets: " + rarest)
	else:
		lines.append("(not in a dungeon)")
	_info_label.text = "\n".join(lines)

func _process(delta: float) -> void:
	if _tab == "info":
		_info_t -= delta
		if _info_t <= 0.0:
			_info_t = 0.4
			_update_info()
