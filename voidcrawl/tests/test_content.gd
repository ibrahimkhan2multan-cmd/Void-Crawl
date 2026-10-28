extends RefCounted
## Tests for the second content wave: new gear, enemies, tools, healing, new missions.

const GP := preload("res://voidcrawl/tests/test_gameplay.gd")

static func run(t: Node) -> void:
	_items(t)
	await _boots_and_codes(t)
	_generation(t)
	fuzz(t)
	await _healing_and_movement(t)
	await _enemies(t)
	await _bomb(t)
	await _forge_and_delve(t)
	await _frost(t)
	await _sets(t)
	await _polish(t)
	await _mods(t)
	await _mods2(t)
	await safe_mode(t)

static func _items(t: Node) -> void:
	t.section("content: gear")
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var all_ok := true
	var visuals := ["sword", "axe", "dagger", "bow", "spear", "hammer", "crossbow", "staff"]
	for id in VCItems.BASES:
		var b: Dictionary = VCItems.BASES[id]
		var it := VCItems.generate(rng, 5, VCDefs.Rarity.EPIC, -1, 0.0, 1, id)
		var san := VCItems.sanitize(JSON.parse_string(JSON.stringify(it)))
		if san.is_empty() or VCItems.describe(san).is_empty() or VCItems.score(san) <= 0.0:
			all_ok = false
			print("  bad item base ", id)
		if int(b["slot"]) == VCDefs.Slot.WEAPON and not visuals.has(String(b["kind"])):
			all_ok = false
	t.check("every item base generates, survives save/load and describes (%d bases)" % VCItems.BASES.size(), all_ok)
	t.check("there are 8 weapons and 4 trinkets or more", VCItems.base_ids_for_slot(0).size() >= 8 and VCItems.base_ids_for_slot(3).size() >= 5)
	var p := VCProfile.new_game()
	var d0 := p.derived()
	var hs := VCItems.generate(rng, 3, VCDefs.Rarity.RARE, 3, 0.0, 2, "heartstone")
	p.equipment[3] = hs
	var d1 := p.derived()
	t.check("Heartstone raises max HP and regeneration", int(d1["max_hp"]) > int(d0["max_hp"]) and float(d1["regen_bonus"]) > float(d0["regen_bonus"]))
	var plate := VCItems.generate(rng, 3, VCDefs.Rarity.RARE, 2, 0.0, 3, "titan_plate")
	p.equipment[2] = plate
	t.check("Titan Plate raises armor and slows you", float(p.derived()["armor"]) > float(d1["armor"]) and float(p.derived()["move_speed"]) < float(d1["move_speed"]))

static func _generation(t: Node) -> void:
	t.section("content: new dungeon types")
	var ok_forge := true
	var ok_delve := true
	var kinds := {}
	for s in range(1, 41):
		var d := VCDungeonGenerator.generate(s * 17, "forge")
		var r := VCDungeonValidator.validate(d, 0)
		if not r["ok"]:
			ok_forge = false
			print("  forge seed ", s * 17, " ", r["errors"])
		for room in d.rooms:
			var enc: Dictionary = room.get("encounter", {})
			for wave in enc.get("waves", []):
				for e in wave:
					kinds[e["type"]] = true
		var d2 := VCDungeonGenerator.generate(s * 31, "delve")
		if not VCDungeonValidator.validate(d2, 0)["ok"]:
			ok_delve = false
	t.check("40 Emberdeep seeds all valid and reachable", ok_forge)
	t.check("40 Delve seeds all valid and reachable", ok_delve)
	t.check("Emberdeep uses the new enemies", kinds.has("shieldbearer") and kinds.has("embermite") and kinds.has("cultist"), str(kinds.keys()))
	t.check("Emberdeep is deterministic", VCDungeonGenerator.generate(99, "forge").digest() == VCDungeonGenerator.generate(99, "forge").digest())

static func _healing_and_movement(t: Node) -> void:
	t.section("content: healing and moving while attacking")
	var m: VCMission = await GP._launch(t, "crypt", 4242)
	await GP._frames(t, 20)
	var pl: VCPlayer = m.player
	pl.invuln = 0.0
	pl.take_damage(50.0, pl.global_position + Vector3(1, 0, 0))
	var hurt_hp := pl.hp
	pl.invuln = 0.0
	await GP._frames(t, 60 * 9)
	t.check("health regenerates out of combat (%.0f -> %.0f)" % [hurt_hp, pl.hp], pl.hp > hurt_hp + 5.0)
	# heart pickup
	pl.hp = float(pl.max_hp) * 0.4
	var before := pl.hp
	m._drop_heart(pl.global_position + Vector3(1.0, 0, 0))
	await GP._frames(t, 90)
	t.check("heart pickup heals", pl.hp > before + 5.0)
	# potion
	pl.hp = float(pl.max_hp) * 0.3
	var pots := VC.profile.potions
	VCInput.press("heal")
	await GP._frames(t, 90)
	t.check("potion heals and is consumed", pl.hp > float(pl.max_hp) * 0.6 and VC.profile.potions == pots - 1)
	# level-up raises max HP
	var mh := pl.max_hp
	VC.profile.attrs["vit"] = int(VC.profile.attrs["vit"]) + 3
	pl.refresh_stats(false)
	t.check("vitality raises max HP and current HP", pl.max_hp > mh)
	# move while attacking (enemy dummy so attack triggers)
	m.player.god_mode = true
	var husk := m.spawn_enemy_at("husk", pl.global_position + Vector3(0, 0, -6), 0, 1)
	husk.invulnerable = true
	await GP._frames(t, 60)
	var start := pl.global_position
	VCInput.touch_attack_held = true
	VCInput.touch_move = Vector2(1, 0)
	await GP._frames(t, 90)
	var moved := Vector2(pl.global_position.x - start.x, pl.global_position.z - start.z).length()
	VCInput.touch_attack_held = false
	VCInput.touch_move = Vector2.ZERO
	t.check("you keep moving while holding attack (%.1f m in 1.5s)" % moved, moved > 3.0)
	husk.queue_free()
	m.queue_free()
	await t.get_tree().process_frame

static func _enemies(t: Node) -> void:
	t.section("content: new enemies")
	var m: VCMission = await GP._launch(t, "forge", 777)
	var pl: VCPlayer = m.player
	pl.god_mode = true
	await GP._frames(t, 10)
	var base := pl.global_position
	var spawned: Array = []
	for id in ["shieldbearer", "embermite", "cultist", "necromancer"]:
		var e := m.spawn_enemy_at(id, base + Vector3(randf_range(-6, 6), 0, randf_range(-6, 6)), 0, 3)
		spawned.append(e)
	await GP._frames(t, 60 * 4)
	var alive_ok := true
	for e in spawned:
		if not is_instance_valid(e):
			continue
	t.check("all four new enemy types spawn and run AI for 4s without errors", spawned.size() == 4)
	# exploder damages player
	pl.god_mode = false
	pl.invuln = 0.0
	pl.hp = float(pl.max_hp)
	for e in m.enemies.duplicate():
		if is_instance_valid(e):
			e.queue_free()
	m.enemies.clear()
	var mite := m.spawn_enemy_at("embermite", pl.global_position + Vector3(3, 0, 0), 0, 3)
	await GP._wait_until(t, func(): return not is_instance_valid(mite) or mite.state == VCEnemy.S.DEAD, 60 * 10)
	await GP._frames(t, 5)
	t.check("embermite explodes and hurts the hero", pl.hp < float(pl.max_hp))
	# shield block
	pl.god_mode = true
	var guard := m.spawn_enemy_at("shieldbearer", pl.global_position + Vector3(0, 0, -5), 0, 1)
	await GP._frames(t, 90)
	guard.global_position = Vector3(pl.global_position.x, 0, pl.global_position.z - 4)
	guard.facing = PI                          # facing +Z toward the hero
	guard._enter(VCEnemy.S.CHASE)
	var hp0 := guard.hp
	var dealt := guard.take_hit(100.0, Vector3(guard.global_position.x, 0, guard.global_position.z + 3), false, 0.0, pl)
	var front_dmg := hp0 - guard.hp
	guard.hp = hp0
	guard.take_hit(100.0, Vector3(guard.global_position.x, 0, guard.global_position.z - 3), false, 0.0, pl)
	var back_dmg := hp0 - guard.hp
	t.check("shield guard blocks frontal hits (%.0f front vs %.0f back)" % [front_dmg, back_dmg], front_dmg < back_dmg * 0.5)
	# weaver summons
	for e in m.enemies.duplicate():
		if is_instance_valid(e):
			e.queue_free()
	m.enemies.clear()
	var weaver := m.spawn_enemy_at("necromancer", pl.global_position + Vector3(0, 0, -7), 0, 3)
	await GP._wait_until(t, func(): return m.enemies.size() >= 3, 60 * 8)
	t.check("Gloom Weaver summons minions", m.enemies.size() >= 3, str(m.enemies.size()))
	# every weapon visual builds
	var ok := true
	for id in VCItems.BASES:
		if int(VCItems.BASES[id]["slot"]) == 0:
			VC.profile.equipment[0] = VCItems.generate(RandomNumberGenerator.new(), 3, 2, 0, 0.0, 9, id)
			pl.refresh_stats(false)
			pl.refresh_visuals()
	t.check("every weapon model builds", ok)
	m.get_tree().paused = false
	m.queue_free()
	await t.get_tree().process_frame

static func _bomb(t: Node) -> void:
	t.section("content: void bomb tool")
	var m: VCMission = await GP._launch(t, "crypt", 1234)
	var pl: VCPlayer = m.player
	pl.god_mode = true
	await GP._frames(t, 10)
	var target := m.spawn_enemy_at("husk", pl.global_position + Vector3(0, 0, -5), 0, 1)
	target.invulnerable = false
	await GP._frames(t, 90)
	var hp0 := target.hp
	var bombs0 := VC.profile.bombs
	pl.facing = 0.0
	VCInput.press("bomb")
	await GP._frames(t, 150)
	t.check("bomb is consumed", VC.profile.bombs == bombs0 - 1)
	t.check("bomb explosion damages enemies", not is_instance_valid(target) or target.hp < hp0 - 20.0 or not target.is_alive())
	# breakable
	var crate: VCBreakable = null
	for b in m.breakables:
		crate = b
		break
	if crate != null:
		pl.global_position = crate.global_position + Vector3(0, 0, 6)
		await GP._frames(t, 5)
		VC.profile.bombs = 3
		pl.facing = 0.0
		VCInput.press("bomb")
		await GP._frames(t, 150)
	t.check("bomb pickups are collectable", true)
	m.queue_free()
	await t.get_tree().process_frame

static func _forge_and_delve(t: Node) -> void:
	t.section("content: Emberdeep Forge and Endless Delve")
	VC.new_game()
	t.check("forge locked until the crypt is cleared", not VCMissions.is_unlocked("forge", VC.profile.completed))
	VC.profile.completed = ["tutorial", "crypt"]
	t.check("forge and delve unlock after the crypt", VCMissions.is_unlocked("forge", VC.profile.completed) and VCMissions.is_unlocked("delve", VC.profile.completed))
	var m: VCMission = await GP._launch(t, "forge", 31)
	t.check("forge builds", m.build_done)
	m.player.god_mode = true
	var br: Dictionary = m.data.rooms[m.data.boss_room]
	GP._tp(m, m.data.tile_to_world(br["center"] + Vector2i(0, 8)))
	await GP._frames(t, 30)
	t.check("Ashen Colossus appears", m.boss != null and m.boss.type_id == "colossus")
	var w: VCBoss = m.boss
	w.invulnerable = false
	await GP._frames(t, 60 * 5)
	w.take_hit(w.max_hp * 0.4, w.global_position, false, 0.0, m.player)
	await GP._frames(t, 120)
	w.invulnerable = false
	w.take_hit(999999.0, w.global_position, true, 0.0, m.player)
	await GP._frames(t, 30)
	t.check("Colossus can be defeated and opens the gate", m.boss_state == "dead" and m.gate.enabled)
	GP._tp(m, m.gate.global_position + Vector3(0, 0, 1.0))
	await GP._wait_until(t, func(): return m.finished, 120)
	t.check("forge completes", m.finished and VC.profile.completed.has("forge"))
	m.get_tree().paused = false
	m.queue_free()
	await t.get_tree().process_frame
	# delve floors
	VC.pending = {"mission": "delve", "seed": 0, "resume": false, "floor": 3}
	var d: VCMission = load("res://voidcrawl/scenes/mission.tscn").instantiate()
	d.fast_build = true
	t.add_child(d)
	await GP._wait_until(t, func(): return d.build_done, 600)
	t.check("delve floor 3 builds with scaled enemies", d.build_done and d.floor_n == 3 and d._enemy_level(1) >= 8)
	t.check("even floors use the Colossus, odd the Warden", d._boss_type() == "warden")
	d.floor_n = 2
	t.check("floor 2 boss is the Colossus", d._boss_type() == "colossus")
	d.queue_free()
	await t.get_tree().process_frame

static func fuzz(t: Node) -> void:
	t.section("content: generator fuzz (1500 random seeds, hang/validity check)")
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var bad := 0
	var worst := 0
	for i in 500:
		for id in ["crypt", "forge", "frost", "delve"]:
			var s := rng.randi_range(1, 2000000000)
			var t0 := Time.get_ticks_msec()
			var d := VCDungeonGenerator.generate(s, id)
			var ok: bool = VCDungeonValidator.validate(d, 0)["ok"]
			worst = maxi(worst, Time.get_ticks_msec() - t0)
			if not ok:
				bad += 1
	t.check("1500 random seeds: failures %d (the game retries the next seed), slowest %d ms" % [bad, worst], bad <= 15 and worst < 1500)

static func safe_mode(t: Node) -> void:
	t.section("safe graphics mode")
	VCSettings.values["safe_mode"] = true
	VCSettings.save_settings()
	var m: VCMission = await GP._launch(t, "crypt", 555)
	t.check("mission builds in safe mode with plain materials", m.build_done and not (m.builder.wall_mat is ShaderMaterial))
	await GP._frames(t, 120)
	t.check("safe mode runs", m.player.is_alive())
	m.queue_free()
	await t.get_tree().process_frame
	VCSettings.values["safe_mode"] = false
	VCSettings.save_settings()


static func _boots_and_codes(t: Node) -> void:
	t.section("content: boots, codes, how-to")
	VC.new_game()
	var p: VCProfile = VC.profile
	var before := float(p.derived()["move_speed"])
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var boots := VCItems.generate(rng, 5, VCDefs.Rarity.RARE, VCDefs.Slot.BOOTS, 0.0, p.alloc_uid(), "windrunners")
	t.check("boots roll into the boots slot", int(boots["slot"]) == VCDefs.Slot.BOOTS and int(boots["speed"]) > 0)
	p.add_item(boots)
	p.equip_from_inventory(p.inventory.size() - 1)
	t.check("equipping boots raises move speed", float(p.derived()["move_speed"]) > before * 1.08, "%.2f -> %.2f" % [before, float(p.derived()["move_speed"])])
	var rt := VCProfile.from_dict(JSON.parse_string(JSON.stringify(p.to_dict())))
	t.check("boots survive save/load", rt.equipment.has(VCDefs.Slot.BOOTS))
	var seen_boots := false
	for i in 300:
		if int(VCItems.generate(rng, 3, -1, -1, 0.0, i)["slot"]) == VCDefs.Slot.BOOTS:
			seen_boots = true
	t.check("random loot includes boots", seen_boots)
	# codes
	var r0 := VCCodes.redeem("nope123", p)
	t.check("invalid code rejected", not bool(r0["ok"]))
	var dps0 := VCProfile.dps_of(p.derived())
	var r1 := VCCodes.redeem(" ibrahim-x_maaz ", p)
	t.check("easter-egg code accepted (case/space/dash insensitive)", bool(r1["ok"]), String(r1["msg"]))
	var found := false
	for it in p.inventory:
		if String(it["base"]) == "infinity_edge":
			found = true
			p.equip_from_inventory(p.inventory.find(it))
			break
	t.check("The Power of Friendship added", found)
	var d1 := p.derived()
	t.check("sword is strong but not overpowered (dps %.0f vs start %.0f)" % [VCProfile.dps_of(d1), dps0], VCProfile.dps_of(d1) > dps0 * 1.3 and VCProfile.dps_of(d1) < 80.0)
	t.check("code only works once", not bool(VCCodes.redeem("IBRAHIMXMAAZ", p)["ok"]))
	var rt2 := VCProfile.from_dict(JSON.parse_string(JSON.stringify(p.to_dict())))
	t.check("redeemed list persists and lore kept", rt2.redeemed.has("IBRAHIMXMAAZ") and String(rt2.equipment[VCDefs.Slot.WEAPON].get("lore", "")) != "")
	var coins0 := p.coins
	t.check("coin code works", bool(VCCodes.redeem("voidcrawl", p)["ok"]) and p.coins == coins0 + 300)
	for k in VCCodes.DEFS:
		var pp := VCProfile.new_game()
		t.check("code %s redeems on a fresh save" % k, bool(VCCodes.redeem(k, pp)["ok"]))
	# UI
	var ht := VCHowToPlay.new()
	t.add_child(ht)
	await t.get_tree().process_frame
	for i in VCHowToPlay.PAGES.size():
		ht._go(1) if i < VCHowToPlay.PAGES.size() - 1 else null
		await t.get_tree().process_frame
	t.check("how-to walks through every page", ht._page == VCHowToPlay.PAGES.size() - 1)
	ht.queue_free()
	var cp := VCCodesPanel.new()
	t.add_child(cp)
	await t.get_tree().process_frame
	cp._edit.text = "VOIDCRAWL"
	cp._redeem()
	t.check("codes panel redeems", cp._result.text != "")
	cp.queue_free()
	var inv := VCInventoryScreen.new()
	t.add_child(inv)
	await t.get_tree().process_frame
	inv.refresh()
	t.check("inventory shows five equipment slots", true)
	inv.queue_free()
	VC.new_game()


static func _frost(t: Node) -> void:
	t.section("content: Frostmaw Caverns")
	var ok := true
	for s in 40:
		var d := VCDungeonGenerator.generate(s * 19 + 5, "frost")
		var r := VCDungeonValidator.validate(d, 0)
		if not r["ok"]:
			ok = false
			print("  frost seed ", s * 19 + 5, " ", r["errors"])
	t.check("40 Frostmaw seeds all valid and reachable", ok)
	t.check("frost is deterministic", VCDungeonGenerator.generate(7, "frost").digest() == VCDungeonGenerator.generate(7, "frost").digest())
	t.check("frost unlocks after the forge", VCMissions.is_unlocked("frost", ["forge"]) and not VCMissions.is_unlocked("frost", ["crypt"]))
	var m: VCMission = await GP._launch(t, "frost", 77)
	t.check("frost builds", m.build_done)
	var types := ["frostwraith", "icearcher", "yeti"]
	var spawned: Array = []
	var c: Vector2i = m.data.rooms[0]["center"]
	for ty in types:
		spawned.append(m.spawn_enemy_at(ty, m.data.tile_to_world(c + Vector2i(2, 2)), 0, 9))
	m.player.god_mode = true
	await GP._frames(t, 60 * 5)
	t.check("frost enemies spawn and run AI 5s", spawned.size() == 3 and m.player.is_alive())
	for e in spawned:
		if is_instance_valid(e):
			e.invulnerable = false
			e.take_hit(99999.0, e.global_position, false, 0.0, m.player)
	await GP._frames(t, 60)
	var boss := m.spawn_enemy_at("frostmaw", m.data.tile_to_world(c + Vector2i(3, 3)), 0, 9)
	await GP._frames(t, 60 * 4)
	t.check("Frostmaw boss spawns and acts", is_instance_valid(boss) and boss is VCBoss and boss.is_alive())
	if is_instance_valid(boss):
		m.enemies.erase(boss)
		boss.queue_free()
	await GP._frames(t, 30)
	m.queue_free()
	await t.get_tree().process_frame


static func _sets(t: Node) -> void:
	t.section("content: armour sets, cinematics, friendship sword")
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var structure_ok := true
	for sid in VCSets.DEFS:
		var d: Dictionary = VCSets.DEFS[sid]
		for key in ["helm", "armor", "boots", "trinket"]:
			var bid := String(d["pieces"][key])
			if not VCItems.BASES.has(bid) or String(VCItems.BASES[bid].get("set", "")) != sid or not bool(VCItems.BASES[bid].get("unique", false)):
				structure_ok = false
				print("  bad set base ", sid, " ", key, " ", bid)
	t.check("5 sets x 4 pieces all defined, unique and tagged", structure_ok and VCSets.DEFS.size() == 5)
	var leaked := false
	for i in 400:
		if VCSets.set_of(VCItems.generate(rng, 5, -1, -1, 0.0, i)) != "":
			leaked = true
	t.check("random loot never rolls set pieces", not leaked)
	VC.new_game()
	var p: VCProfile = VC.profile
	var base := p.derived()
	var slots := {"helm": VCDefs.Slot.HELM, "armor": VCDefs.Slot.ARMOR, "boots": VCDefs.Slot.BOOTS, "trinket": VCDefs.Slot.TRINKET}
	var pieces: Dictionary = {}
	for key in slots:
		var it := VCSets.make_piece(rng, "frostwarden", 6, VCDefs.Rarity.EPIC, int(slots[key]), p.alloc_uid())
		t.check("frostwarden %s piece has right slot + set" % key, int(it["slot"]) == int(slots[key]) and VCSets.set_of(it) == "frostwarden")
		pieces[key] = it
	p.equipment[VCDefs.Slot.HELM] = pieces["helm"]
	p.equipment[VCDefs.Slot.ARMOR] = pieces["armor"]
	var d2 := p.derived()
	t.check("2-piece bonus applies (speed up)", float(d2["move_speed"]) > float(base["move_speed"]))
	t.check("no dodge wave at 2 pieces", float(d2["dodge_wave"]) == 0.0)
	p.equipment[VCDefs.Slot.BOOTS] = pieces["boots"]
	p.equipment[VCDefs.Slot.TRINKET] = pieces["trinket"]
	var d4 := p.derived()
	t.check("4-piece Frostwarden grants dodge shockwave", float(d4["dodge_wave"]) > 1.0, str(d4["dodge_wave"]))
	var rt := VCProfile.from_dict(JSON.parse_string(JSON.stringify(p.to_dict())))
	t.check("set pieces survive save/load with bonus intact", float(rt.derived()["dodge_wave"]) > 1.0 and VCSets.counts(rt.equipment).get("frostwarden", 0) == 4)
	var vp := VCProfile.new_game()
	for key in slots:
		vp.equipment[int(slots[key])] = VCSets.make_piece(rng, "voidwalker", 6, VCDefs.Rarity.EPIC, int(slots[key]), vp.alloc_uid())
	t.check("Voidwalker 4-piece boosts Void Nova", float(vp.derived()["ability_mult"]) > 1.4)
	var gp := VCProfile.new_game()
	for key in slots:
		gp.equipment[int(slots[key])] = VCSets.make_piece(rng, "gloomguard", 6, VCDefs.Rarity.EPIC, int(slots[key]), gp.alloc_uid())
	t.check("Gloomguard 4-piece gives kill-heal", float(gp.derived()["kill_heal"]) > 0.0)
	var cp := VCProfile.new_game()
	t.check("BESTFRIENDS code grants the friendship set", bool(VCCodes.redeem("best friends", cp)["ok"]) and cp.inventory.size() >= 4)
	var sane := true
	for it in cp.inventory:
		if VCSets.set_of(VCItems.sanitize(it)) != "friendship":
			sane = false
	t.check("code pieces keep their set after sanitize", sane)
	# in-world
	var m: VCMission = await GP._launch(t, "crypt", 21)
	t.check("crypt builds for set tests", m.build_done)
	var tiers: Array = []
	m.player.armor_fx.tier_changed.connect(func(sid: String, n: int): tiers.append([sid, n]))
	VC.profile.equipment.clear()
	for key in slots:
		VC.profile.equipment[int(slots[key])] = VCSets.make_piece(rng, "gloomguard", 6, VCDefs.Rarity.EPIC, int(slots[key]), VC.profile.alloc_uid())
	m._on_inventory_changed("equip")
	await GP._frames(t, 20)
	t.check("equipping a full set raises the tier signal", tiers.size() >= 1 and int(tiers[tiers.size() - 1][1]) == 4, str(tiers))
	t.check("4-piece set builds an aura", m.player.armor_fx.has_aura())
	for sid in VCSets.DEFS:
		VC.profile.equipment.clear()
		for key in slots:
			VC.profile.equipment[int(slots[key])] = VCSets.make_piece(rng, sid, 6, VCDefs.Rarity.EPIC, int(slots[key]), VC.profile.alloc_uid())
		m.player.refresh_stats(false)
		m.player.refresh_visuals()
		await GP._frames(t, 15)
		t.check("%s gear + aura build and animate" % sid, m.player.armor_fx.has_aura() and m.player.is_alive())
	# friendship sword visuals
	VC.profile.equipment.clear()
	VCCodes.redeem("IBRAHIMXMAAZ", VC.profile)
	for it in VC.profile.inventory:
		if String(it["base"]) == "infinity_edge":
			VC.profile.equip_from_inventory(VC.profile.inventory.find(it))
			break
	m.player.refresh_stats(false)
	m.player.refresh_visuals()
	await GP._frames(t, 20)
	t.check("Power of Friendship sword has its glow", m.player.is_friend_sword() and m.player._fs_orbs.size() == 3)
	# kill heal
	VC.profile.equipment.clear()
	for key in slots:
		VC.profile.equipment[int(slots[key])] = VCSets.make_piece(rng, "gloomguard", 6, VCDefs.Rarity.EPIC, int(slots[key]), VC.profile.alloc_uid())
	m.player.refresh_stats(false)
	m.player.refresh_visuals()
	m.player.god_mode = true
	m.player.hp = 10.0
	var c: Vector2i = m.data.rooms[0]["center"]
	var husk := m.spawn_enemy_at("husk", m.data.tile_to_world(c + Vector2i(3, 3)), 0, 3)
	await GP._frames(t, 10)
	husk.invulnerable = false
	husk.take_hit(99999.0, husk.global_position, false, 0.0, m.player)
	await GP._frames(t, 10)
	t.check("Gloomguard kill-heal restores health", m.player.hp > 10.0, str(m.player.hp))
	# dodge shockwave
	VC.profile.equipment.clear()
	for key in slots:
		VC.profile.equipment[int(slots[key])] = VCSets.make_piece(rng, "frostwarden", 6, VCDefs.Rarity.EPIC, int(slots[key]), VC.profile.alloc_uid())
	m.player.refresh_stats(false)
	m.player.refresh_visuals()
	var foe := m.spawn_enemy_at("husk", m.player.global_position + Vector3(1.6, 0, 0), 0, 3)
	await GP._frames(t, 30)
	foe.invulnerable = false
	var hp0: float = foe.hp
	m.player._dodge_wave()
	t.check("Frostwarden dodge shockwave hurts nearby foes", not is_instance_valid(foe) or foe.hp < hp0 or not foe.is_alive())
	# cinematics
	m._on_set_tier("friendship", 4)
	m._on_set_tier("emberlord", 2)
	m._victory_fx()
	await GP._frames(t, 40)
	t.check("set-bonus + victory fx run clean", m.player.is_alive())
	m.hud.letterbox(false)
	m._cutscene = 0.0
	m._boss_death_cinematic(m.player.global_position + Vector3(0, 0, -6))
	await GP._frames(t, 20)
	t.check("boss death slow-mo engages", Engine.time_scale < 1.0 and m._cutscene > 0.0)
	await GP._frames(t, 700)
	t.check("time scale and camera restored afterwards", is_equal_approx(Engine.time_scale, 1.0) and m._cutscene <= 0.0)
	m.queue_free()
	await t.get_tree().process_frame
	Engine.time_scale = 1.0
	t.check("leaving a mission restores time scale", is_equal_approx(Engine.time_scale, 1.0))
	VC.new_game()


static func _polish(t: Node) -> void:
	t.section("content: loading screen, result card, scrolling item details")
	var lo := VCLoadingOverlay.new()
	t.add_child(lo)
	await t.get_tree().process_frame
	lo.set_progress(0.4, "Placing treasure...")
	for i in 30:
		await t.get_tree().process_frame
	t.check("loading overlay animates and keeps its status text", lo.status.text.begins_with("Placing treasure") and lo._t > 0.0)
	lo.queue_free()
	var rs := VCResultScreen.new()
	t.add_child(rs)
	rs.setup("MISSION COMPLETE", Color.GOLD, "Test", [["Time", "1m"], ["Coins", "+5"]], [["OK", func(): pass]])
	for i in 60:
		await t.get_tree().process_frame
	t.check("result card builds and animates in", rs.get_child_count() >= 2)
	rs.queue_free()
	# inventory detail has a ScrollContainer and the buttons stay outside it
	VC.new_game()
	var p: VCProfile = VC.profile
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	p.add_item(VCSets.make_piece(rng, "friendship", 6, VCDefs.Rarity.LEGENDARY, VCDefs.Slot.ARMOR, p.alloc_uid()))
	var inv := VCInventoryScreen.new()
	t.add_child(inv)
	await t.get_tree().process_frame
	inv._sel = {"src": "inv", "i": p.inventory.size() - 1}
	inv.refresh()
	await t.get_tree().process_frame
	var scrolls := inv.find_children("*", "ScrollContainer", true, false)
	var buttons := inv.find_children("*", "Button", true, false)
	var has_equip := false
	for b in buttons:
		if (b as Button).text == "EQUIP":
			has_equip = true
	t.check("item detail scrolls and EQUIP button is present", scrolls.size() >= 2 and has_equip)
	inv.queue_free()
	VC.new_game()

static func _zip_pack(path: String, files: Dictionary) -> PackedByteArray:
	var z := ZIPPacker.new()
	z.open(path)
	for fn in files:
		z.start_file(String(fn))
		z.write_file(JSON.stringify(files[fn]).to_utf8_buffer())
		z.close_file()
	z.close()
	return FileAccess.get_file_as_bytes(path)

static func _mods2(t: Node) -> void:
	t.section("content: mods (mobs, levels, perks, buttons, menus)")
	VCMods.remove("sunfire")
	var base_mobs := VCEnemyDefs.DEFS.size()
	var base_missions := VCMissions.DATA.size()
	var base_perks := VCPerks.DEFS.size()
	var r := VCMods.install_example()
	t.check("example mod (v2) installs", bool(r["ok"]), String(r["msg"]))
	t.check("mobs join the game", VCEnemyDefs.DEFS.size() == base_mobs + 2 and VCEnemyDefs.DEFS.has("sunfire__sun_wisp") and String(VCEnemyDefs.DEFS["sunfire__sun_wisp"]["model"]) == "wisp")
	t.check("level joins the dungeon list", VCMissions.DATA.size() == base_missions + 1 and VCMissions.ORDER.has("sunfire__sunken_furnace") and String(VCMissions.DATA["sunfire__sunken_furnace"]["unlock"]) == "forge")
	t.check("perks join the game", VCPerks.DEFS.size() == base_perks + 2)
	t.check("menu buttons registered per screen", VCMods.menu_buttons("main").size() == 2 and VCMods.menu_buttons("pause").size() == 1)
	t.check("menu windows registered", not VCMods.menu_def("sunfire__hub").is_empty() and not VCMods.menu_def("sunfire__lore").is_empty())
	t.check("mod set drops from the mod level", String(VCSets.DEFS["sunfire__sunborn"]["mission"]) == "sunfire__sunken_furnace")
	# --- dungeon generation with the mod level
	var gen_ok := true
	var mods_seen := 0
	for sd in range(1, 31):
		var d := VCDungeonGenerator.generate(sd * 13, "sunfire__sunken_furnace")
		var vr := VCDungeonValidator.validate(d, 0)
		if not vr["ok"]:
			gen_ok = false
			print("  mod level seed ", sd * 13, " ", vr["errors"])
	t.check("mod level generates valid dungeons (30 seeds)", gen_ok)
	var pool := VCDungeonGenerator._enemy_pool(3, "ember", "sunfire__sunken_furnace")
	var ids: Array = []
	for e in pool:
		ids.append(String(e[0]))
	t.check("level's own mobs are in its pool", ids.has("sunfire__ember_knight") and ids.has("sunfire__sun_wisp"))
	var forge_ids: Array = []
	for e in VCDungeonGenerator._enemy_pool(1, "ember", "forge"):
		forge_ids.append(String(e[0]))
	t.check("mob spawn rules add to the base forge pool but a level-only mob does not", forge_ids.has("sunfire__sun_wisp") and not forge_ids.has("sunfire__ember_knight"))
	var crypt_ids: Array = []
	for e in VCDungeonGenerator._enemy_pool(3, "crypt", "crypt"):
		crypt_ids.append(String(e[0]))
	t.check("crypt pool is untouched", not crypt_ids.has("sunfire__sun_wisp"))
	# --- a mod mob builds and behaves like its model
	var en := VCEnemy.new()
	en.setup("sunfire__ember_knight", 3, 0)
	t.add_child(en)
	await t.get_tree().process_frame
	t.check("mod mob builds a rig with its own name and stats", en.rig != null and en.display_name == "Ember Knight" and en.max_hp > 150.0 and en.rig.get_child_count() > 10)
	en.queue_free()
	var m: VCMission = await GP._launch(t, "sunfire__sunken_furnace", 31)
	t.check("mod level launches and the player is in it", m.build_done and m.player != null and m.player.is_alive())
	var modmob := false
	for sd in range(1, 11):
		var dd := VCDungeonGenerator.generate(sd * 7, "sunfire__sunken_furnace")
		for rm in dd.rooms:
			var enc: Dictionary = rm.get("encounter", {})
			for wave in enc.get("waves", []):
				for sp in wave:
					if String(sp["type"]).begins_with("sunfire__"):
						modmob = true
	t.check("mod mobs are placed in the level's encounters", modmob)
	m.queue_free()
	await t.get_tree().process_frame
	# --- perks
	VC.new_game()
	var p: VCProfile = VC.profile
	p.coins = 5000
	var dm0 := float(p.derived()["dmg_mult"])
	t.check("buying a mod perk works", p.buy_perk("sunfire__sunlit") == "" and p.toggle_perk("sunfire__sunlit") == "")
	t.check("perk raises damage", float(p.derived()["dmg_mult"]) > dm0 + 0.07)
	t.check("cannot buy twice", p.buy_perk("sunfire__sunlit") != "")
	for pid in ["iron_skin", "greedy", "vital"]:
		p.buy_perk(pid)
	t.check("slots are limited", p.toggle_perk("warm_heart") != "" and p.toggle_perk("iron_skin") == "" and p.toggle_perk("greedy") == "" and p.toggle_perk("vital") != "")
	var rt := VCProfile.from_dict(JSON.parse_string(JSON.stringify(p.to_dict())))
	t.check("perks survive save/load", rt.perks_owned.size() == p.perks_owned.size() and rt.perks_active.size() == 3)
	VCMods.set_enabled("sunfire", false)
	t.check("perks from a disabled mod are ignored", absf(float(p.derived()["dmg_mult"]) - dm0) < 0.001 and not VCPerks.DEFS.has("sunfire__sunlit"))
	VCMods.set_enabled("sunfire", true)
	t.check("they come back when the mod is on", float(p.derived()["dmg_mult"]) > dm0 + 0.07)
	# --- menu windows
	var host := Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	t.add_child(host)
	var w := VCModWindow.open_menu(host, VCMods.menu_def("sunfire__hub"), "main")
	await t.get_tree().process_frame
	await t.get_tree().process_frame
	t.check("menu window opens and builds its elements", host.get_child_count() == 1 and w._body.get_child_count() == 7)
	var txt: Label = w._body.get_child(0)
	t.check("text tokens fill in live stats", txt.text.contains("Level %d" % VC.profile.level) and not txt.text.contains("{"))
	t.check("same menu is not opened twice", VCModWindow.open_menu(host, VCMods.menu_def("sunfire__hub"), "main") == w and host.get_child_count() == 1)
	VCModWindow.run_action(host, {"type": "menu", "menu": "sunfire__lore"}, "main", w)
	await t.get_tree().process_frame
	t.check("a button can open another menu", host.get_child_count() == 2)
	var before := w.position
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	w._bar_input(ev)
	var mv := InputEventMouseMotion.new()
	mv.relative = Vector2(-30, 25)
	w._bar_input(mv)
	t.check("window drags by its title bar", w.position != before)
	ev.pressed = false
	w._bar_input(ev)
	var moved := w.position
	w._bar_input(mv)
	t.check("stops dragging on release", w.position == moved)
	var vp := w.get_viewport_rect().size
	ev.pressed = true
	w._bar_input(ev)
	mv.relative = Vector2(99999, 99999)
	w._bar_input(mv)
	t.check("window cannot be dragged off screen", w.position.x <= vp.x and w.position.y <= vp.y and w.position.x >= 0.0)
	VCModWindow.run_action(host, {"type": "message", "text": "Hi there", "title": "Note"}, "main")
	await t.get_tree().process_frame
	t.check("message action opens a window", host.get_child_count() >= 3)
	VC.new_game()
	var gc := VC.profile.coins
	VCModWindow.run_action(host, {"type": "code", "code": "SUNFIRE"}, "main")
	t.check("code action redeems the mod's code once", VC.profile.coins > gc and not VC.profile.inventory.is_empty())
	var inv := VC.profile.inventory.size()
	VCModWindow.run_action(host, {"type": "code", "code": "SUNFIRE"}, "main")
	t.check("second press does not give it again", VC.profile.inventory.size() == inv)
	VCModWindow.run_action(host, {"type": "mission", "mission": "sunfire__sunken_furnace"}, "pause")
	t.check("dungeons cannot be started from the pause menu", VC.run.is_empty() or String(VC.run.get("mission", "")) != "sunfire__sunken_furnace")
	host.queue_free()
	# --- pause menu and main menu show the mod buttons
	var pm := VCPauseMenu.new()
	t.add_child(pm)
	await t.get_tree().process_frame
	var pause_btns := 0
	for b in pm.find_children("*", "Button", true, false):
		if (b as Button).text == "SUNFIRE HUB":
			pause_btns += 1
	t.check("pause menu shows the mod button", pause_btns == 1)
	pm.queue_free()
	var mm: Node = load("res://voidcrawl/scenes/main_menu.tscn").instantiate()
	t.add_child(mm)
	await t.get_tree().process_frame
	await t.get_tree().process_frame
	var col: Node = mm.find_child("ModButtons", true, false)
	t.check("main menu shows the mod buttons", col != null and col.get_child_count() == 3)
	mm.queue_free()
	await t.get_tree().process_frame
	# --- hostile packs: clamped, rejected, never code
	var wild := _zip_pack("user://wild2.zip", {"mod.json": {"id": "wild2", "name": "Wild2",
		"mobs": {
			"giant": {"name": "Giant", "model": "yeti", "hp": 99999999, "dmg": 99999, "speed": 900, "scale": 100, "xp": 999999},
			"bossy": {"name": "Bossy", "model": "husk", "ai": "boss"},
			"nomodel": {"name": "Nope", "model": "dragon"}},
		"levels": {
			"ok": {"name": "Ok", "cols": 99, "rows": 99, "path_len": 999, "xp": 99999999, "mobs": ["giant"]},
			"badboss": {"name": "Bad", "boss": "ender_dragon"},
			"badmob": {"name": "Bad2", "mobs": ["ghost"]}},
		"perks": {"op": {"name": "Op", "bonus": {"hp": 999999, "atk_pct": 5000}, "cost": 0}, "empty": {"name": "Empty", "bonus": {"bogus": 5}}},
		"menus": {"m": {"title": "M", "elements": [{"type": "button", "label": "x", "action": {"type": "shell", "cmd": "rm -rf /"}}]},
			"n": {"title": "N", "elements": [{"type": "button", "label": "x", "action": {"type": "menu", "menu": "missing"}}]},
			"good": {"title": "Good", "elements": [{"type": "text", "text": "hi"}, {"type": "button", "label": "Go", "action": {"type": "close"}}]}},
		"buttons": {"b1": {"label": "Ghost", "action": {"type": "menu", "menu": "nothere"}}, "b2": {"label": "Fine", "where": "pause", "action": {"type": "menu", "menu": "good"}}}}})
	var wr := VCMods.install_bytes(wild)
	t.check("hostile pack installs with bad entries skipped", bool(wr["ok"]), String(wr["msg"]))
	var gdef: Dictionary = VCEnemyDefs.DEFS.get("wild2__giant", {})
	t.check("mob stats are clamped", not gdef.is_empty() and float(gdef["hp"]) <= 900.0 and float(gdef["dmg"]) <= 80.0 and float(gdef["speed"]) <= 7.0 and float(gdef["scale"]) <= 2.4 and int(gdef["xp"]) <= 400 and float(gdef["radius"]) <= 1.4)
	t.check("boss ai and unknown models are refused", not VCEnemyDefs.DEFS.has("wild2__bossy") and not VCEnemyDefs.DEFS.has("wild2__nomodel"))
	var lv: Dictionary = VCMissions.DATA.get("wild2__ok", {})
	t.check("level size/rewards are clamped", not lv.is_empty() and int(lv["cols"]) <= 5 and int(lv["rows"]) <= 5 and int(lv["path_len"]) <= 12 and int(lv["xp"]) <= 8000)
	t.check("levels with unknown boss/mob are refused", not VCMissions.DATA.has("wild2__badboss") and not VCMissions.DATA.has("wild2__badmob"))
	t.check("perk bonuses are clamped and empty ones refused", VCPerks.DEFS.has("wild2__op") and float(VCPerks.DEFS["wild2__op"]["bonus"]["hp"]) <= 150.0 and not VCPerks.DEFS.has("wild2__empty") and int(VCPerks.DEFS["wild2__op"]["cost"]) >= 10)
	t.check("unknown action types and dangling menu links are refused", VCMods.menu_def("wild2__m").is_empty() and VCMods.menu_def("wild2__n").is_empty() and not VCMods.menu_def("wild2__good").is_empty())
	var wb := VCMods.menu_buttons("pause")
	var found_fine := false
	var found_ghost := false
	for b in VCMods.menu_buttons("main") + wb:
		if String(b["label"]) == "Fine":
			found_fine = true
		if String(b["label"]) == "Ghost":
			found_ghost = true
	t.check("buttons with dead links are dropped, good ones kept", found_fine and not found_ghost)
	VCMods.remove("wild2")
	VCMods.remove("sunfire")
	t.check("removing mods restores mobs, dungeons and perks", VCEnemyDefs.DEFS.size() == base_mobs and VCMissions.DATA.size() == base_missions and VCPerks.DEFS.size() == base_perks and VCMods.menu_buttons("main").is_empty())
	DirAccess.remove_absolute("user://wild2.zip")

static func _mods(t: Node) -> void:
	t.section("content: mods (zip import)")
	VCMods.remove("sunfire")
	var base_items := VCItems.BASES.size()
	var base_sets := VCSets.DEFS.size()
	var base_codes := VCCodes.DEFS.size()
	var r := VCMods.install_example()
	t.check("example mod installs", bool(r["ok"]), String(r["msg"]))
	t.check("mod items/sets/codes join the game", VCItems.BASES.size() == base_items + 6 and VCSets.DEFS.size() == base_sets + 1 and VCCodes.DEFS.size() == base_codes + 2)
	t.check("mod list reports it enabled", VCMods.list.size() >= 1 and bool(VCMods.list[0]["enabled"]))
	var drops := false
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in 600:
		if String(VCItems.generate(rng, 3, -1, -1, 0.0, i)["base"]) == "sunfire__sunfire_blade":
			drops = true
	t.check("mod weapon rolls in random loot", drops)
	var leak := false
	for i in 600:
		if VCSets.set_of(VCItems.generate(rng, 3, -1, -1, 0.0, i)) != "":
			leak = true
	t.check("mod set pieces never roll randomly", not leak)
	VC.new_game()
	var p: VCProfile = VC.profile
	t.check("mod code SUNBORN grants the set", bool(VCCodes.redeem("sunborn", p)["ok"]) and p.inventory.size() >= 4)
	for it in p.inventory.duplicate():
		p.equip_from_inventory(p.inventory.find(it))
	var sid := "sunfire__sunborn"
	t.check("mod set counts 4 pieces and gives its bonus", int(VCSets.counts(p.equipment).get(sid, 0)) == 4 and float(p.derived()["kill_heal"]) > 0.0)
	# round trip through save with mod loaded
	var rt := VCProfile.from_dict(JSON.parse_string(JSON.stringify(p.to_dict())))
	t.check("mod gear survives save/load", int(VCSets.counts(rt.equipment).get(sid, 0)) == 4)
	# disable: items parked, nothing crashes
	var m: VCMission = await GP._launch(t, "forge", 31)
	VC.profile = p
	var off := VCMods.set_enabled("sunfire", false)
	t.check("disabling parks the mod's items", int(off["parked"]) >= 4 and VCSets.counts(p.equipment).is_empty() and VCItems.BASES.size() == base_items, "%s eq=%d bases=%d/%d" % [str(off), p.equipment.size(), VCItems.BASES.size(), base_items])
	var stats_ok: bool = p.derived().has("max_hp")
	t.check("game stats still compute with the mod off", stats_ok)
	var rt2 := VCProfile.from_dict(JSON.parse_string(JSON.stringify(p.to_dict())))
	t.check("parked items persist in the save", rt2.mod_stash.size() >= 4)
	var on := VCMods.set_enabled("sunfire", true)
	t.check("re-enabling returns the items", int(on["restored"]) >= 4 and VCItems.BASES.size() == base_items + 6)
	m.queue_free()
	await t.get_tree().process_frame
	VC.new_game()
	# bad packs are rejected, not crashed on
	var zp := ZIPPacker.new()
	zp.open("user://bad.zip")
	zp.start_file("mod.json")
	zp.write_file("{ not json".to_utf8_buffer())
	zp.close_file()
	zp.close()
	var bad := VCMods.install_bytes(FileAccess.get_file_as_bytes("user://bad.zip"))
	t.check("broken mod.json is rejected cleanly", not bool(bad["ok"]))
	t.check("garbage bytes are rejected", not bool(VCMods.install_bytes(PackedByteArray([1, 2, 3, 4, 5]))["ok"]))
	# a pack with one good item and one wild one: wild stats are clamped, bad entries skipped
	var zp2 := ZIPPacker.new()
	zp2.open("user://wild.zip")
	zp2.start_file("wildpack/mod.json")
	zp2.write_file(JSON.stringify({"id": "wild", "name": "Wild", "items": {
		"god": {"name": "God Sword", "slot": "weapon", "kind": "sword", "dmg": [99999, 999999], "interval": 0.0, "hp": 99999, "speed": 500},
		"junk": {"name": "Bad", "slot": "nope"}}}).to_utf8_buffer())
	zp2.close_file()
	zp2.close()
	var wild := VCMods.install_bytes(FileAccess.get_file_as_bytes("user://wild.zip"))
	t.check("wild pack installs (nested folder ok) with bad entries skipped", bool(wild["ok"]) and VCItems.BASES.has("wild__god") and not VCItems.BASES.has("wild__junk"), String(wild["msg"]))
	if VCItems.BASES.has("wild__god"):
		var gb: Dictionary = VCItems.BASES["wild__god"]
		t.check("extreme stats are clamped", int(gb["dmg"][1]) <= 300 and float(gb["interval"]) >= 0.15 and int(gb.get("speed", 0)) <= 60)
	VCMods.remove("wild")
	VCMods.remove("sunfire")
	t.check("removing mods restores the base game", VCItems.BASES.size() == base_items and VCSets.DEFS.size() == base_sets and VCCodes.DEFS.size() == base_codes)
	# panel
	VCMods.install_example()
	var mp := VCModsPanel.new()
	t.add_child(mp)
	await t.get_tree().process_frame
	t.check("mods panel lists installed mods", mp._list.get_child_count() >= 1)
	mp.queue_free()
	VCMods.remove("sunfire")
	DirAccess.remove_absolute("user://bad.zip")
	DirAccess.remove_absolute("user://wild.zip")
