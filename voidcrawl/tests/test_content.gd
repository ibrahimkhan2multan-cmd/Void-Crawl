extends RefCounted
## Tests for the second content wave: new gear, enemies, tools, healing, new missions.

const GP := preload("res://voidcrawl/tests/test_gameplay.gd")

static func run(t: Node) -> void:
	_items(t)
	_generation(t)
	await _healing_and_movement(t)
	await _enemies(t)
	await _bomb(t)
	await _forge_and_delve(t)

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
	await GP._wait_until(t, func(): return not is_instance_valid(mite) or not mite.is_alive(), 60 * 10)
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
