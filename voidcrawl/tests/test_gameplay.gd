extends RefCounted
## Gameplay integration tests: launches the real mission scene headlessly and drives it.

static func _launch(t: Node, id: String, seed_: int = 0) -> VCMission:
	VC.new_game()
	VC.pending = {"mission": id, "seed": seed_, "resume": false}
	var m: VCMission = load("res://voidcrawl/scenes/mission.tscn").instantiate()
	m.fast_build = true
	t.add_child(m)
	var guard := 0
	while not m.build_done and guard < 600:
		await t.get_tree().process_frame
		guard += 1
	return m

static func _frames(t: Node, n: int) -> void:
	for i in n:
		await t.get_tree().physics_frame

static func run(t: Node) -> void:
	t.section("gameplay: tutorial launch")
	var m := await _launch(t, "tutorial")
	t.check("tutorial scene builds", m.build_done)
	if not m.build_done:
		return
	await _frames(t, 30)
	t.check("player alive and on floor tile", m.player.is_alive() and m.data.is_floor(m.data.world_to_tile(m.player.global_position).x, m.data.world_to_tile(m.player.global_position).y))
	t.check("training husk spawned", m.enemies.size() >= 1)
	t.check("first objective active", m.obj_index == 0)
	await _tutorial_playthrough(t, m)
	m.queue_free()
	VCInput.reset()
	await t.get_tree().process_frame
	await _menu_test(t)
	await _crypt_playthrough(t)
	await _death_and_resume(t)
	await load("res://voidcrawl/tests/test_content.gd").run(t)

static func _tp(m: VCMission, pos: Vector3) -> void:
	m.player.global_position = pos
	m.player.velocity = Vector3.ZERO

static func _wait_until(t: Node, cond: Callable, max_frames: int) -> bool:
	for i in max_frames:
		if cond.call():
			return true
		await t.get_tree().physics_frame
	return cond.call()

static func _kill_all(m: VCMission) -> void:
	for e in m.enemies.duplicate():
		if is_instance_valid(e) and e.is_alive():
			e.invulnerable = false
			e.take_hit(99999.0, e.global_position, false, 0.0, m.player)

static func _tutorial_playthrough(t: Node, m: VCMission) -> void:
	t.section("gameplay: movement")
	var start := m.player.global_position
	VCInput.touch_move = Vector2(0, -1)
	await _frames(t, 90)
	VCInput.touch_move = Vector2.ZERO
	var moved := start.distance_to(m.player.global_position)
	var tile := m.data.world_to_tile(m.player.global_position)
	t.check("joystick input moves the hero", moved > 2.0, "moved %.2f" % moved)
	t.check("hero is stopped by walls (still on floor)", m.data.is_floor(tile.x, tile.y))
	VCInput.touch_move = Vector2(1, 0)
	await _frames(t, 400)
	VCInput.touch_move = Vector2.ZERO
	tile = m.data.world_to_tile(m.player.global_position)
	t.check("pushing into walls for 6s never leaves the dungeon", m.data.is_floor(tile.x, tile.y))

	t.section("gameplay: tutorial objectives")
	_tp(m, m.data.tile_to_world(m.data.marker_tile))
	await _frames(t, 10)
	t.check("reaching the marker completes objective 1", m.counters["marker"] == 1 and m.obj_index >= 1)
	# real melee combat against the training husk
	var husk: VCEnemy = m.enemies[0]
	await _wait_until(t, func(): return husk._spawn_delay <= 0.0 and husk.state != VCEnemy.S.SPAWN, 120)
	m.player.god_mode = true
	_tp(m, husk.global_position + Vector3(1.4, 0, 0))
	VCInput.touch_attack_held = true
	var dead := await _wait_until(t, func(): return not is_instance_valid(husk) or not husk.is_alive(), 60 * 12)
	VCInput.touch_attack_held = false
	t.check("holding attack defeats the husk", dead)
	t.check("kill counted and XP granted", m.counters["kills"] >= 1 and VC.profile.xp > 0 or VC.profile.level > 1)
	m.player.god_mode = false
	# chest
	var ch: VCInteractable = null
	for it in m.interactables:
		if it.kind == "chest":
			ch = it
	t.check("tutorial has a chest", ch != null)
	_tp(m, ch.global_position + Vector3(0, 0, 1.2))
	await _frames(t, 5)
	var inv_before := VC.profile.inventory.size()
	VCInput.press("interact")
	await _frames(t, 5)
	t.check("interact opens chest and counts objective", ch.used and m.counters["chests"] == 1)
	await _frames(t, 120)
	_tp(m, ch.global_position)
	await _frames(t, 90)
	t.check("loot is picked up into the pack", VC.profile.inventory.size() > inv_before, "%d -> %d" % [inv_before, VC.profile.inventory.size()])
	# equip changes stats
	var dps_before := VCProfile.dps_of(VC.profile.derived())
	var best := -1
	for i in VC.profile.inventory.size():
		if int(VC.profile.inventory[i]["slot"]) == VCDefs.Slot.WEAPON:
			best = i
	if best >= 0:
		VC.profile.equip_from_inventory(best)
		m._on_inventory_changed("equip")
	await _frames(t, 3)
	t.check("equipping the chest weapon raises DPS", VCProfile.dps_of(VC.profile.derived()) > dps_before)
	t.check("equip objective completed", m.counters["equips"] >= 1)
	# dodge
	m.player.dodge_cd = 0.0
	VCInput.press("dodge")
	await _frames(t, 30)
	t.check("dodge roll registers", m.counters["dodges"] >= 1)
	# remaining rooms
	var locked_seen := false
	for rid in [1, 2]:
		var c: Vector2i = m.data.rooms[rid]["center"]
		_tp(m, m.data.tile_to_world(c))
		await _frames(t, 10)
		if m.rooms_state[rid]["state"] == "active":
			locked_seen = true
			await _frames(t, 60)
			_kill_all(m)
			await _frames(t, 20)
			for k in 3:
				_kill_all(m)
				await _frames(t, 100)
	t.check("an encounter triggered and locked the room", locked_seen)
	t.check("encounter rooms cleared", m.rooms_state[1]["state"] == "cleared" or m.rooms_state[2]["state"] == "cleared")
	await _frames(t, 10)
	t.check("kill objectives satisfied", m.counters["kills"] >= 4, str(m.counters["kills"]))
	t.check("exit gate unlocked", m.exit_unlocked and m.gate.enabled)
	_tp(m, m.gate.global_position + Vector3(0, 0, 1.0))
	await _wait_until(t, func(): return m.finished, 120)
	t.check("walking into the gate completes the mission", m.finished)
	t.check("completion recorded in profile", VC.profile.completed.has("tutorial"))
	t.check("crypt is unlocked afterwards", VCMissions.is_unlocked("crypt", VC.profile.completed))
	m.get_tree().paused = false
	m.queue_free()

static func _crypt_playthrough(t: Node) -> void:
	t.section("gameplay: crypt and boss")
	var keep_profile: Dictionary = VC.profile.to_dict()
	VC.pending = {"mission": "crypt", "seed": 777, "resume": false}
	var m: VCMission = load("res://voidcrawl/scenes/mission.tscn").instantiate()
	m.fast_build = true
	t.add_child(m)
	await _wait_until(t, func(): return m.build_done, 600)
	t.check("crypt builds", m.build_done)
	m.player.god_mode = true
	var br: Dictionary = m.data.rooms[m.data.boss_room]
	_tp(m, m.data.tile_to_world(br["center"] + Vector2i(0, 8)))
	await _frames(t, 20)
	t.check("entering boss room spawns the Warden", m.boss != null and m.boss_state == "active")
	await _frames(t, 200)
	t.check("boss room is sealed during the fight", m._barriers.has(m.data.boss_room))
	var w: VCBoss = m.boss
	var phases: Array = []
	w.phase_changed.connect(func(p): phases.append(p))
	var max_hp := w.max_hp
	# fight for real for a few seconds: boss must act
	var hp0 := m.player.hp
	m.player.god_mode = false
	m.player.hp = float(m.player.max_hp)
	await _frames(t, 60 * 6)
	m.player.god_mode = true
	t.check("boss attacks the hero", m.player.hp < float(m.player.max_hp) or w.state != VCEnemy.S.CHASE)
	for step in 2:
		w.invulnerable = false
		w.take_hit(max_hp * 0.4, w.global_position, false, 0.0, m.player)
		await _frames(t, 90)
	t.check("boss goes through phases", phases.has(2) and phases.has(3), str(phases))
	w.invulnerable = false
	w.take_hit(999999.0, w.global_position, true, 0.0, m.player)
	await _frames(t, 30)
	t.check("boss can be defeated", m.boss_state == "dead" and m.counters["boss"] == 1)
	t.check("boss dropped loot", m.pickups.size() > 0)
	t.check("boss room reopened and gate unlocked", m.exit_unlocked and m.gate.enabled)
	_tp(m, m.gate.global_position + Vector3(0, 0, 1.0))
	await _wait_until(t, func(): return m.finished, 120)
	t.check("crypt completes and shows result", m.finished and VC.profile.completed.has("crypt"))
	m.get_tree().paused = false
	m.queue_free()
	await t.get_tree().process_frame

static func _death_and_resume(t: Node) -> void:
	t.section("gameplay: death, retry, save and resume")
	VC.new_game()
	VC.pending = {"mission": "crypt", "seed": 31337, "resume": false}
	var m: VCMission = load("res://voidcrawl/scenes/mission.tscn").instantiate()
	m.fast_build = true
	t.add_child(m)
	await _wait_until(t, func(): return m.build_done, 600)
	var seed_a := m.seed_
	m.player.invuln = 0.0
	m.player.take_damage(99999.0, m.player.global_position + Vector3(1, 0, 0))
	await _frames(t, 5)
	t.check("hero dies at 0 HP", not m.player.is_alive())
	await _wait_until(t, func(): return m._defeat_shown, 200)
	t.check("defeat screen appears", m._defeat_shown)
	m.retry()
	await _frames(t, 5)
	t.check("retry revives hero at checkpoint", m.player.is_alive() and m.player.hp > 0.0)
	# progress then save/resume
	m.counters["kills"] = 5
	m.opened_chests.append("chest_test")
	m._save_run()
	var snap: Dictionary = VC.run.duplicate(true)
	t.check("run state recorded", int(snap["seed"]) == seed_a and int(snap["counters"]["kills"]) == 5)
	var ok := VCSave.save(VC.profile, VC.run)
	t.check("save file written", ok and VCSave.load_save().has("profile"))
	m.queue_free()
	await t.get_tree().process_frame
	VC.pending = {"mission": "crypt", "seed": 0, "resume": true}
	var m2: VCMission = load("res://voidcrawl/scenes/mission.tscn").instantiate()
	m2.fast_build = true
	t.add_child(m2)
	await _wait_until(t, func(): return m2.build_done, 600)
	t.check("resume rebuilds the same dungeon", m2.seed_ == seed_a)
	t.check("resume restores counters and chests", m2.counters["kills"] == 5 and m2.opened_chests.has("chest_test"))
	m2.queue_free()
	await t.get_tree().process_frame

static func _menu_test(t: Node) -> void:
	t.section("main menu")
	VC.new_game()
	var menu: Node = load("res://voidcrawl/scenes/main_menu.tscn").instantiate()
	t.add_child(menu)
	await t.get_tree().process_frame
	await t.get_tree().process_frame
	var labels: Array = []
	for b in menu.find_children("*", "Button", true, false):
		labels.append((b as Button).text)
	for want in ["PLAY", "DUNGEONS", "INVENTORY", "CHARACTER", "SETTINGS", "EXIT"]:
		t.check("menu has %s button" % want, labels.has(want), str(labels))
	menu._on_button("inventory")
	await t.get_tree().process_frame
	t.check("INVENTORY opens the pack screen", menu._modal is VCInventoryScreen)
	menu._close_modal()
	menu._on_button("dungeons")
	await t.get_tree().process_frame
	t.check("DUNGEONS opens the mission list", menu._modal != null)
	menu._close_modal()
	menu.queue_free()
	await t.get_tree().process_frame
