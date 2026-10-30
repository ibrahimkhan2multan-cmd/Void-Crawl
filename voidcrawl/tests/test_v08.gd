extends RefCounted
## v0.8 features: Mythic/Voidborn rarities, leggings + 5-piece sets, upgrades, auto-delete, pets, biome mobs,
## automatic checkpoints, tougher deep mobs.

const GP := preload("res://voidcrawl/tests/test_gameplay.gd")

static func run(t: Node) -> void:
	_rarity_and_legs(t)
	_upgrades_and_auto(t)
	_pets_data(t)
	_biomes_and_balance(t)
	await _pets_in_world(t)
	await _checkpoints(t)
	await run_tester(t)

static func _rarity_and_legs(t: Node) -> void:
	t.section("v0.8: rarities and leggings")
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	t.check("7 rarities defined", VCDefs.RARITY_NAMES.size() == 7 and VCDefs.RARITY_COLORS.size() == 7 and VCDefs.RARITY_STAT_MULT.size() == 7)
	var early := 0
	for i in 4000:
		if VCItems.roll_rarity(rng, 0.5, 5) >= VCDefs.Rarity.MYTHIC:
			early += 1
	t.check("Mythic / Voidborn never roll in shallow dungeons", early == 0)
	var myth := 0
	var void_ := 0
	for i in 6000:
		var r := VCItems.roll_rarity(rng, 0.5, 16)
		if r == VCDefs.Rarity.MYTHIC: myth += 1
		if r == VCDefs.Rarity.VOIDBORN: void_ += 1
	t.check("Mythic and Voidborn do roll deep down", myth > 0 and void_ > 0, "%d / %d" % [myth, void_])
	var comm := VCItems.generate(rng, 10, VCDefs.Rarity.COMMON, VCDefs.Slot.ARMOR, 0.0, 1, "titan_plate")
	var vb := VCItems.generate(rng, 10, VCDefs.Rarity.VOIDBORN, VCDefs.Slot.ARMOR, 0.0, 2, "titan_plate")
	t.check("Voidborn is much stronger than Common", int(vb["def"]) > int(comm["def"]) * 3 - 3 and (vb["affixes"] as Array).size() == 6)
	t.check("Voidborn is worth more and scores higher", VCItems.sell_value(vb) > VCItems.sell_value(comm) * 10 and VCItems.score(vb) > VCItems.score(comm))
	var legs := VCItems.generate(rng, 5, VCDefs.Rarity.RARE, VCDefs.Slot.LEGS, 0.0, 3)
	t.check("leggings roll into slot 5", int(legs["slot"]) == 5 and int(legs.get("def", 0)) > 0)
	var seen_legs := 0
	for i in 400:
		if int(VCItems.generate(rng, 3, -1, -1, 0.0, i)["slot"]) == VCDefs.Slot.LEGS:
			seen_legs += 1
	t.check("random drops include leggings", seen_legs > 10, "%d" % seen_legs)
	var p := VCProfile.new_game()
	var d0 := p.derived()
	p.equipment[VCDefs.Slot.LEGS] = legs
	var d1 := p.derived()
	t.check("wearing leggings raises armor", float(d1["armor"]) > float(d0["armor"]) and int(d1["max_hp"]) > int(d0["max_hp"]))
	var back := VCProfile.from_dict(JSON.parse_string(JSON.stringify(p.to_dict())))
	t.check("leggings survive save/load", back.equipment.has(VCDefs.Slot.LEGS) and back.equipment[VCDefs.Slot.LEGS]["base"] == legs["base"])
	for sid in VCSets.DEFS:
		var sd: Dictionary = VCSets.DEFS[sid]
		if String(sd.get("mod", "")) != "":
			continue
		t.check("set %s has 5 pieces incl. leggings and a 5-piece bonus" % sid, (sd["pieces"] as Dictionary).has("legs") and (sd["pieces"] as Dictionary).size() == 5 and not (sd["b5"] as Dictionary).is_empty())
	var q := VCProfile.new()
	var pieces := {}
	for key in VCSets.PIECE_KEYS:
		var sl: int = [VCDefs.Slot.HELM, VCDefs.Slot.ARMOR, VCDefs.Slot.LEGS, VCDefs.Slot.BOOTS, VCDefs.Slot.TRINKET][VCSets.PIECE_KEYS.find(key)]
		pieces[sl] = VCSets.make_piece(rng, "frostwarden", 6, 3, sl, 10 + sl)
		t.check("make_piece builds the %s" % key, not pieces[sl].is_empty() and int(pieces[sl]["slot"]) == sl)
	for sl in pieces:
		q.equipment[sl] = pieces[sl]
	var c := VCSets.counts(q.equipment)
	t.check("five frostwarden pieces counted", int(c["frostwarden"]) == 5)
	var b := VCSets.bonus_totals(q.equipment)
	t.check("5-piece bonus is added on top of the 2 and 4 bonuses", float(b["def"]) >= 8.0 + 8.0 + 10.0, "def %s" % str(b.get("def")))
	q.equipment.erase(VCDefs.Slot.LEGS)
	t.check("losing the leggings drops the 5-piece bonus", float(VCSets.bonus_totals(q.equipment)["def"]) == 16.0)

static func _upgrades_and_auto(t: Node) -> void:
	t.section("v0.8: upgrades and auto-delete")
	var p := VCProfile.new_game()
	t.check("base capacities", p.inv_cap() == 36 and p.max_potions() == 3 and p.max_bombs() == 5 and p.perk_slots() == 3 and p.pet_slots() == 1)
	t.check("cannot buy without coins", VCUpgrades.buy(p, "backpack") != "")
	p.coins = 100000
	var costs: Array = []
	for i in 3:
		costs.append(VCUpgrades.cost(p, "backpack"))
		t.check("backpack upgrade %d bought" % (i + 1), VCUpgrades.buy(p, "backpack") == "")
	t.check("costs rise each level", int(costs[1]) > int(costs[0]) and int(costs[2]) > int(costs[1]))
	t.check("backpack grows by 6 per level", p.inv_cap() == 36 + 18)
	for i in 4:
		VCUpgrades.buy(p, "potion_belt")
		VCUpgrades.buy(p, "bomb_pouch")
		VCUpgrades.buy(p, "perk_slots")
	t.check("potion belt, bomb pouch, perk slots grow", p.max_potions() == 7 and p.max_bombs() == 9 and p.perk_slots() == 7)
	for i in 5:
		VCUpgrades.buy(p, "potion_potency")
	t.check("alchemy makes potions heal more (50% -> 90%)", absf(p.potion_heal_frac() - 0.9) < 0.001, str(p.potion_heal_frac()))
	t.check("max level is enforced", VCUpgrades.buy(p, "potion_potency") != "" and VCUpgrades.cost(p, "potion_potency") == -1)
	for i in 50:
		p.add_item(VCItems.generate(RandomNumberGenerator.new(), 3, VCDefs.Rarity.COMMON, -1, 0.0, p.alloc_uid()))
	t.check("a bigger backpack really holds more items", p.inventory.size() == 50 and p.inv_cap() == 54)
	# perk slots: equip more than 3
	for id in ["iron_skin", "swift_feet", "sharpened", "eagle_eye", "vampiric"]:
		p.buy_perk(id)
		t.check("perk %s equips with extra slots" % id, p.toggle_perk(id) == "")
	t.check("5 perks active gives all their bonuses", float(p.derived()["crit"]) > 0.05 + 0.05)
	# persistence
	var back := VCProfile.from_dict(JSON.parse_string(JSON.stringify(p.to_dict())))
	t.check("upgrades and many perks survive save/load", back.inv_cap() == p.inv_cap() and back.max_potions() == 7 and back.perks_active.size() == 5)
	# auto-delete
	var a := VCProfile.new_game()
	a.coins = 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var junk := VCItems.generate(rng, 3, VCDefs.Rarity.UNCOMMON, VCDefs.Slot.BOOTS, 0.0, 1)
	var epic := VCItems.generate(rng, 3, VCDefs.Rarity.EPIC, VCDefs.Slot.BOOTS, 0.0, 2)
	var setp := VCSets.make_piece(rng, "gloomguard", 3, 2, VCDefs.Slot.HELM, 3)
	t.check("nothing is removed while the filter is empty", not a.should_auto_remove(junk))
	a.equipment[VCDefs.Slot.BOOTS] = VCItems.generate(rng, 8, VCDefs.Rarity.EPIC, VCDefs.Slot.BOOTS, 0.0, 9, "windrunners")
	a.toggle_auto_rarity(VCDefs.Rarity.UNCOMMON)
	a.toggle_auto_rarity(VCDefs.Rarity.RARE)
	t.check("Uncommon is removed, Epic is kept", a.should_auto_remove(junk) and not a.should_auto_remove(epic))
	t.check("set pieces are never auto-removed", not a.should_auto_remove(setp))
	a.equipment[VCDefs.Slot.BOOTS] = VCItems.generate(rng, 1, VCDefs.Rarity.COMMON, VCDefs.Slot.BOOTS, 0.0, 4, "scuffed_boots")
	var better := VCItems.generate(rng, 8, VCDefs.Rarity.UNCOMMON, VCDefs.Slot.BOOTS, 0.0, 5, "windrunners")
	t.check("an upgrade is protected by 'keep upgrades'", not a.should_auto_remove(better))
	a.auto_keep_upgrades = false
	t.check("...unless that option is switched off", a.should_auto_remove(better))
	a.auto_keep_upgrades = true
	a.inventory = [junk.duplicate(), epic.duplicate(), setp.duplicate()]
	a.inventory[0]["slot"] = VCDefs.Slot.HELM   # not an upgrade over an empty slot? (empty slot => any item beats it)
	var res := a.sweep_auto()
	t.check("sweep result is consistent", int(res["count"]) >= 0 and a.inventory.has(epic) and a.inventory.has(setp))
	a.auto_keep_upgrades = false
	a.inventory = [junk.duplicate(), junk.duplicate(), epic.duplicate()]
	a.auto_mode = "sell"
	var before := a.coins
	var res2 := a.sweep_auto()
	t.check("sweep in sell mode pays coins", int(res2["count"]) == 2 and a.coins == before + 2 * VCItems.sell_value(junk) and a.inventory.size() == 1)
	a.inventory = [junk.duplicate()]
	a.auto_mode = "delete"
	before = a.coins
	a.sweep_auto()
	t.check("delete mode pays nothing", a.coins == before and a.inventory.is_empty())
	var back2 := VCProfile.from_dict(JSON.parse_string(JSON.stringify(a.to_dict())))
	t.check("auto-delete settings survive save/load", back2.auto_rarities == a.auto_rarities and back2.auto_mode == "delete" and not back2.auto_keep_upgrades)

static func _pets_data(t: Node) -> void:
	t.section("v0.8: pets (data)")
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	t.check("12+ pet species across 7 rarities", VCPets.SPECIES.size() >= 12)
	var rars := {}
	for id in VCPets.SPECIES:
		rars[VCPets.rarity_of(id)] = true
	t.check("pets cover every rarity", rars.size() == 7)
	var p := VCProfile.new_game()
	t.check("cannot buy an egg without coins", VCPets.buy_egg(p, "common") != "")
	p.coins = 50000
	t.check("buying eggs works", VCPets.buy_egg(p, "common") == "" and VCPets.buy_egg(p, "rare") == "" and VCPets.egg_count(p, "common") == 1)
	var res := VCPets.hatch(p, "common", rng)
	t.check("hatching gives a new pet and equips it", bool(res["ok"]) and p.pets.has(String(res["id"])) and p.pets_active.has(String(res["id"])))
	t.check("hatching with no egg fails", not bool(VCPets.hatch(p, "mythic", rng)["ok"]))
	# odds
	var counts := {}
	for i in 3000:
		var sid := VCPets.roll_species(rng, "common")
		counts[VCPets.rarity_of(sid)] = int(counts.get(VCPets.rarity_of(sid), 0)) + 1
	t.check("common eggs never give epic+ pets", int(counts.get(3, 0)) + int(counts.get(4, 0)) + int(counts.get(5, 0)) + int(counts.get(6, 0)) == 0)
	t.check("common eggs mostly give common pets", int(counts.get(0, 0)) > 1800, str(counts))
	var top := 0
	for i in 3000:
		if VCPets.rarity_of(VCPets.roll_species(rng, "mythic")) >= 5:
			top += 1
	t.check("mythic eggs can give Mythic/Voidborn pets", top > 100, str(top))
	# duplicates level up
	p.eggs["common"] = 60
	for i in 60:
		VCPets.hatch(p, "common", rng)
	var leveled := 0
	for k in p.pets:
		if int(p.pets[k]) > 1:
			leveled += 1
	t.check("duplicate pets level up instead of being wasted", leveled >= 2, "%d pets leveled" % leveled)
	# upgrades
	var id := String(p.pets.keys()[0])
	var lvl := int(p.pets[id])
	if lvl >= VCProfile.MAX_PET_LEVEL:
		p.pets[id] = 3
		lvl = 3
	var hp1 := VCPets.max_hp(id, lvl, 1)
	var cost := VCPets.upgrade_cost(id, lvl)
	var coins := p.coins
	t.check("pet upgrade costs coins and raises its level", VCPets.upgrade(p, id) == "" and p.coins == coins - cost and int(p.pets[id]) == lvl + 1)
	t.check("upgraded pet is tougher and hits harder", VCPets.max_hp(id, lvl + 1, 1) > hp1 and VCPets.damage(id, lvl + 1, 1) > VCPets.damage(id, lvl, 1))
	p.pets[id] = VCProfile.MAX_PET_LEVEL
	t.check("max level pets cannot be upgraded", VCPets.upgrade(p, id) != "")
	# party limit
	var ids: Array = VCPets.SPECIES.keys()
	for k in ids:
		p.pets[String(k)] = 1
	p.pets_active.clear()
	t.check("first pet equips", VCPets.toggle_active(p, String(ids[0])) == "")
	t.check("party is limited by the kennel", VCPets.toggle_active(p, String(ids[1])) != "")
	p.coins = 99999
	VCUpgrades.buy(p, "kennel")
	t.check("a kennel upgrade adds a party slot", VCPets.toggle_active(p, String(ids[1])) == "" and p.pet_slots() == 2)
	# passives feed into derived()
	var base := VCProfile.new_game().derived()
	var withp := VCProfile.new_game()
	withp.pets["dragon"] = 5
	withp.pets_active = ["dragon"]
	var dd := withp.derived()
	t.check("active pet passives raise hero stats", float(dd["dmg_mult"]) > float(base["dmg_mult"]) and float(dd["armor"]) > float(base["armor"]))
	var back := VCProfile.from_dict(JSON.parse_string(JSON.stringify(p.to_dict())))
	t.check("pets, party and eggs survive save/load", back.pets.size() == p.pets.size() and back.pets_active == p.pets_active and back.eggs == p.eggs)
	# boss eggs
	t.check("tutorial boss drops no egg, crypt drops one", VCPets.boss_egg("tutorial", 1, rng) == "" and VCPets.boss_egg("crypt", 1, rng) != "")

static func _biomes_and_balance(t: Node) -> void:
	t.section("v0.8: biome mobs and heavy deep mobs")
	var seen := {}
	for theme in ["crypt", "cavern", "ruins", "overgrown", "void", "ice", "glacier", "rime", "ash", "forge", "magma"]:
		var pool: Array = VCDungeonGenerator._theme_pool(theme, 4)
		var ids: Array = []
		for e in pool:
			ids.append(String(e[0]))
			t.check("%s: mob '%s' exists" % [theme, e[0]], VCEnemyDefs.DEFS.has(String(e[0])))
		seen[theme] = ids
	t.check("different surroundings have different mobs", seen["cavern"] != seen["crypt"] and seen["ice"] != seen["magma"] and seen["overgrown"] != seen["void"])
	t.check("cave rooms spawn bats and slimes, forests spawn thorn crawlers", seen["cavern"].has("cavebat") and seen["cavern"].has("slime") and seen["overgrown"].has("thornling"))
	# generated dungeons actually use them
	var kinds := {}
	for sd in [11, 12, 13]:
		var d := VCDungeonGenerator.generate(sd, "crypt")
		for r in d.rooms:
			var enc = r.get("encounter", null)
			if not (enc is Dictionary) or not (enc as Dictionary).has("waves"):
				continue
			for w in enc["waves"]:
				for en in w:
					kinds[String(en["type"])] = true
	t.check("a generated crypt uses more than the old 5 creature types", kinds.size() >= 6, str(kinds.keys()))
	# hits to kill: a common sword hit vs a small mob at various depths
	var p := VCProfile.new_game()
	var hit := (float(p.derived()["dmg_min"]) + float(p.derived()["dmg_max"])) * 0.5
	var husk: Dictionary = VCEnemyDefs.get_def("husk")
	var lvl_hp := {}
	for lvl in [1, 4, 8, 12]:
		lvl_hp[lvl] = float(husk["hp"]) * VCEnemyDefs.hp_scale(lvl)
	t.check("deeper mobs have clearly more health", lvl_hp[12] > lvl_hp[1] * 2.5, str(lvl_hp))
	t.check("a level-12 husk takes the starter sword 12+ hits", lvl_hp[12] / hit >= 12.0, "%.1f hits" % (lvl_hp[12] / hit))

static func _pets_in_world(t: Node) -> void:
	t.section("v0.8: pets in a dungeon")
	var m: VCMission = await GP._launch(t, "crypt", 1234)
	t.check("crypt builds", m.build_done)
	if not m.build_done:
		return
	VC.profile.pets = {"pup": 3, "golem": 2}
	VC.profile.pets_active = ["pup"]
	m._spawn_pets()
	await GP._frames(t, 20)
	t.check("the active pet follows you into the dungeon", m.pets.size() == 1 and is_instance_valid(m.pets[0]))
	var pet: VCPet = m.pets[0]
	t.check("pet is alive near the hero", not pet.dead and pet.global_position.distance_to(m.player.global_position) < 8.0)
	# follows
	GP._tp(m, m.data.tile_to_world(m.data.nearest_floor(m.data.world_to_tile(m.player.global_position) + Vector2i(6, 0))))
	await GP._frames(t, 240)
	t.check("pet follows when the hero moves", pet.global_position.distance_to(m.player.global_position) < 6.0, "%.1f" % pet.global_position.distance_to(m.player.global_position))
	# fights: spawn a husk next to the pet while the hero stays away from the fight
	m.player.god_mode = true
	var e := m.spawn_enemy_at("husk", pet.global_position + Vector3(3, 0, 0), 0, 1)
	await GP._wait_until(t, func(): return e.state != VCEnemy.S.SPAWN, 120)
	var hp0 := e.hp
	await GP._frames(t, 200)
	t.check("pet attacks nearby enemies on its own", not is_instance_valid(e) or not e.is_alive() or e.hp < hp0, "hp %.0f -> %.0f" % [hp0, e.hp if is_instance_valid(e) else 0.0])
	GP._kill_all(m)
	await GP._frames(t, 60)
	# damage, feeding, death, respawn
	pet.hp = pet.max_hp
	pet.take_damage(10.0, pet.global_position + Vector3(1, 0, 0))
	t.check("pet takes damage", pet.hp < pet.max_hp)
	t.check("pet health is shown to the player", pet._hp_show > 0.0)
	pet._invuln = 0.0
	VC.profile.potions = 3
	VC.profile.pet_feed = true
	pet.hp = pet.max_hp * 0.2
	m.player.hp = float(m.player.max_hp)
	await GP._frames(t, 20)
	t.check("a hurt pet eats a potion to heal", VC.profile.potions == 2 and pet.hp > pet.max_hp * 0.5, "potions %d hp %.0f/%.0f" % [VC.profile.potions, pet.hp, pet.max_hp])
	VC.profile.pet_feed = false
	VC.profile.potions = 3
	pet._feed_cd = 0.0
	pet.hp = pet.max_hp * 0.2
	await GP._frames(t, 20)
	t.check("pets keep your potions when feeding is off", VC.profile.potions == 3)
	pet._invuln = 0.0
	pet.take_damage(99999.0, pet.global_position + Vector3(1, 0, 0))
	t.check("pet can fall", pet.dead and not pet.rig.visible)
	t.check("a fallen pet takes no further damage", not pet.take_damage(5.0, pet.global_position))
	await GP._frames(t, 60 * 9)
	t.check("pet is still down before 10 seconds", pet.dead)
	await GP._frames(t, 60 * 2)
	t.check("pet respawns by itself after ~10 seconds", not pet.dead and pet.rig.visible and pet.hp > 0.0)
	# enemies hurt pets
	GP._kill_all(m)
	pet._invuln = 0.0
	pet.hp = pet.max_hp
	var brute := m.spawn_enemy_at("brute", pet.global_position + Vector3(1.8, 0, 0), 0, 4)
	await GP._wait_until(t, func(): return brute.state != VCEnemy.S.SPAWN, 120)
	GP._tp(m, pet.global_position + Vector3(14, 0, 0))
	m.player.god_mode = true
	pet.hp = pet.max_hp
	await GP._frames(t, 60 * 8)
	t.check("enemies attack pets too", pet.hp < pet.max_hp or pet.dead)
	GP._kill_all(m)
	m.queue_free()
	VCInput.reset()
	await t.get_tree().process_frame

static func _checkpoints(t: Node) -> void:
	t.section("v0.8: automatic checkpoints")
	var m: VCMission = await GP._launch(t, "crypt", 777)
	t.check("crypt builds", m.build_done)
	if not m.build_done:
		return
	var shrines := 0
	for it in m.interactables:
		if it.kind == "shrine":
			shrines += 1
	t.check("no checkpoint shrine structures are spawned", shrines == 0)
	t.check("run starts with the entrance checkpoint", m.checkpoint_room == 0)
	# find a combat room and clear it
	var rid := -1
	for r in m.data.rooms:
		var enc = r.get("encounter", null)
		if (enc is Dictionary) and (enc as Dictionary).has("waves") and int(r["id"]) > 0 and not bool(r.get("secret", false)) and String(r["type"]) == "combat":
			rid = int(r["id"])
			break
	t.check("dungeon has a combat room", rid > 0)
	if rid > 0:
		m.player.god_mode = true
		var c: Vector2i = m.data.rooms[rid]["center"]
		GP._tp(m, m.data.tile_to_world(c))
		await GP._frames(t, 30)
		var guard := 0
		while String(m.rooms_state[rid]["state"]) != "cleared" and guard < 40:
			GP._kill_all(m)
			await GP._frames(t, 30)
			guard += 1
		t.check("clearing the room works", String(m.rooms_state[rid]["state"]) == "cleared")
		t.check("clearing a room saves it as the checkpoint", m.checkpoint_room == rid, "checkpoint %d" % m.checkpoint_room)
		t.check("the checkpoint is stored in the run save", int(VC.run.get("checkpoint_room", -1)) == rid)
		var shown := false
		for ch in m.hud.toast_box.get_children():
			if ch is Label and (ch as Label).text.find("Checkpoint saved") >= 0:
				shown = true
		t.check("the player is told 'Checkpoint saved'", shown)
		# die and retry => back in that room
		m.player.god_mode = false
		m.player.take_damage(99999.0, m.player.global_position + Vector3(1, 0, 0), true)
		await GP._frames(t, 120)
		m.retry()
		await GP._frames(t, 30)
		var tile := m.data.world_to_tile(m.player.global_position)
		t.check("retry puts the hero in the last cleared room", m.player.is_alive() and (tile - c).length() < 10.0, "%s vs %s" % [str(tile), str(c)])
	m.queue_free()
	VCInput.reset()
	await t.get_tree().process_frame

static func run_tester(t: Node) -> void:
	t.section("v0.8: tester menu")
	VCTester.reset_all()
	VCSettings.set_value("tester_unlocked", false)
	var p := VCProfile.new_game()
	t.check("tester overrides do nothing while locked", true)
	VCTester.values["dmg_x"] = 5.0
	t.check("locked: overrides are ignored", absf(float(p.derived()["dmg_mult"]) - 1.0) < 0.001)
	var r := VCCodes.redeem("tester", p)
	t.check("typing 'tester' unlocks the menu", bool(r["ok"]) and VCTester.unlocked())
	t.check("the tester code is never used up", bool(VCCodes.redeem(" T-E-S-T-E-R ", p)["ok"]) and not p.redeemed.has("TESTER"))
	VCTester.reset_all()
	var base := VCProfile.new_game().derived()
	VCTester.step("hp_add", 1)
	VCTester.step("dmg_x", 1)
	VCTester.step("speed_x", 1)
	VCTester.step("crit_add", 1)
	var d := VCProfile.new_game().derived()
	t.check("health override applies", int(d["max_hp"]) == int(base["max_hp"]) + 50)
	t.check("damage override applies", absf(float(d["dmg_mult"]) - float(base["dmg_mult"]) * 1.5) < 0.001, "%s vs %s" % [str(d["dmg_mult"]), str(base["dmg_mult"])])
	t.check("speed and crit overrides apply", float(d["move_speed"]) > float(base["move_speed"]) * 1.2 and float(d["crit"]) > float(base["crit"]) + 0.09)
	VCTester.step("dmg_x", -1)
	VCTester.step("dmg_x", -1)
	VCTester.step("dmg_x", -1)
	t.check("overrides are clamped to their range", VCTester.num("dmg_x") == 0.5)
	VCTester.reset_all()
	t.check("reset restores normal stats", int(VCProfile.new_game().derived()["max_hp"]) == int(base["max_hp"]))
	var m: VCMission = await GP._launch(t, "crypt", 4321)
	t.check("dungeon builds", m.build_done)
	if not m.build_done:
		return
	VCSettings.set_value("tester_unlocked", true)
	m.toggle_tester(true)
	await GP._frames(t, 5)
	t.check("the tester window opens in a dungeon", m.tester_win != null and is_instance_valid(m.tester_win))
	var tw: VCTesterWindow = m.tester_win
	for tab in ["world", "spawn", "items", "info", "player"]:
		tw._set_tab(tab)
		await GP._frames(t, 2)
		t.check("tab %s builds" % tab, tw._body.get_child_count() > 0 or tab == "none")
	# god mode
	VCTester.set_switch("god", true)
	var hp0 := m.player.hp
	m.player.invuln = 0.0
	m.player.take_damage(50.0, m.player.global_position + Vector3(1, 0, 0))
	t.check("god mode blocks damage", m.player.hp == hp0)
	VCTester.set_switch("god", false)
	# stat change applies live
	var hp_max := m.player.max_hp
	VCTester.step("hp_add", 1)
	tw._refresh_player()
	t.check("max health changes live", m.player.max_hp == hp_max + 50)
	# spawn
	tw._spawn_level = 6
	var before := m.enemies.size()
	tw._spawn_many("slime", 3)
	t.check("spawner creates enemies at the chosen level", m.enemies.size() == before + 3 and (m.enemies[m.enemies.size() - 1] as VCEnemy).level == 6)
	await GP._frames(t, 90)
	# freeze
	VCTester.set_switch("freeze_ai", true)
	var e: VCEnemy = m.enemies[m.enemies.size() - 1]
	var pos0 := e.global_position
	m.player.global_position = e.global_position + Vector3(8, 0, 0)
	await GP._frames(t, 90)
	t.check("frozen enemies do not move", e.global_position.distance_to(pos0) < 0.6, "%.2f" % e.global_position.distance_to(pos0))
	VCTester.set_switch("freeze_ai", false)
	# one hit
	VCTester.set_switch("one_hit", true)
	var dealt := m.player.hit_target(e, 1.0, 0.0)
	t.check("one-hit kills one-shot even a boss-level hp enemy", not e.is_alive() or dealt > 1000.0)
	VCTester.set_switch("one_hit", false)
	# kill all
	tw._spawn_many("husk", 4)
	tw._build_world()
	var n_before := m.enemies.size()
	for e2 in m.enemies.duplicate():
		if is_instance_valid(e2):
			e2.take_hit(999999.0, e2.global_position, false, 0.0, m.player)
	t.check("enemies can be wiped", n_before > 0)
	# items and progress
	var inv0 := VC.profile.inventory.size()
	tw._gen_rarity = VCDefs.Rarity.VOIDBORN
	tw._gen_slot = VCDefs.Slot.LEGS
	tw._give_gear(2)
	t.check("giving gear adds Voidborn leggings", VC.profile.inventory.size() == inv0 + 2 and int(VC.profile.inventory[inv0]["rarity"]) == 6 and int(VC.profile.inventory[inv0]["slot"]) == 5)
	tw._give_set("gloomguard")
	t.check("giving a set adds its pieces", VC.profile.inventory.size() >= inv0 + 2 + 4)
	var lv0 := VC.profile.level
	tw._levels(2)
	t.check("level ups work", VC.profile.level == lv0 + 2)
	tw._coins(1000)
	tw._give_egg("epic")
	t.check("coins and eggs are granted", VC.profile.coins >= 1000 and VCPets.egg_count(VC.profile, "epic") == 1)
	# pets via tester
	for id in VCPets.SPECIES:
		VC.profile.pets[String(id)] = 5
	VC.profile.pets_active = ["pup"]
	tw._pets_changed()
	t.check("pets can be summoned via the tester", m.pets.size() == 1)
	# teleports
	tw._teleport(m.data.tile_to_world(m.data.start_tile))
	t.check("teleport to start works", m.player.global_position.distance_to(m.data.tile_to_world(m.data.start_tile)) < 0.5)
	if m.data.boss_room >= 0:
		tw._teleport(m.data.tile_to_world(m.data.nearest_floor((m.data.rooms[m.data.boss_room]["center"] as Vector2i) + Vector2i(0, 8))))
		t.check("teleport to the boss room works", m._last_room != -2)
	# gate
	m.boss_state = "dead"
	m._check_gate_unlock()
	t.check("gate can be force-opened", m.exit_unlocked)
	# pause menu shows the TESTER button
	var pm := VCPauseMenu.new()
	m.add_child(pm)
	await t.get_tree().process_frame
	var has_btn := false
	for b in pm.find_children("*", "Button", true, false):
		if (b as Button).text == "TESTER":
			has_btn = true
	t.check("pause menu has a TESTER button once unlocked", has_btn)
	pm.queue_free()
	VCTester.reset_all()
	tw.closed.emit()
	await t.get_tree().process_frame
	t.check("closing removes the window", m.tester_win == null)
	VCSettings.set_value("tester_unlocked", false)
	m.queue_free()
	VCInput.reset()
	await t.get_tree().process_frame
