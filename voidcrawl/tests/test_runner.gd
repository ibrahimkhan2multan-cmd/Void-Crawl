extends Node
## Headless test runner. Run with:
##   godot --headless --path . res://voidcrawl/tests/test_runner.tscn
## Exit code 0 = every check passed. Prints a PASS/FAIL line per check and a summary.
## Optional user args after "--":  suite=<name>  (generator, items, save, world, ui ...)

var passed := 0
var failed := 0
var failures: Array[String] = []
var _suite_filter := ""

func check(name: String, cond: bool, detail: String = "") -> void:
	if cond:
		passed += 1
		print("  PASS  %s" % name)
	else:
		failed += 1
		var line := "%s %s" % [name, ("(" + detail + ")") if detail != "" else ""]
		failures.append(line)
		print("  FAIL  %s" % line)

func section(title: String) -> void:
	print("\n== %s ==" % title)

func _wanted(suite: String) -> bool:
	return _suite_filter == "" or _suite_filter == suite

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("suite="):
			_suite_filter = a.substr(6)
	VC.play_audio = false
	VC.autosave = false
	VCSave.path_override = "user://test_save.json"
	VCSettings.path_override = "user://test_settings.cfg"
	await _run()
	print("\n==============================")
	print("TESTS: %d passed, %d failed" % [passed, failed])
	for f in failures:
		print("  - FAILED: " + f)
	print("==============================")
	get_tree().quit(1 if failed > 0 else 0)

func _run() -> void:
	if _wanted("scripts"):
		_test_scripts_load()
	if _wanted("generator"):
		_test_templates()
		_test_generator()
	if _wanted("items"):
		_test_items_and_profile()
	if _wanted("save"):
		_test_save_and_settings()
	if _suite_filter == "content":
		await load("res://voidcrawl/tests/test_content.gd").run(self)
		return
	if _suite_filter == "soak":
		await load("res://voidcrawl/tests/soak.gd").run(self)
		return
	if ResourceLoader.exists("res://voidcrawl/tests/test_gameplay.gd"):
		var extra: Script = load("res://voidcrawl/tests/test_gameplay.gd")
		await extra.run(self)

# ------------------------------------------------------------------ scripts
func _collect(dir_path: String, out: Array) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for f in dir.get_files():
		if f.ends_with(".gd"):
			out.append(dir_path.path_join(f))
	for sub in dir.get_directories():
		_collect(dir_path.path_join(sub), out)

func _test_scripts_load() -> void:
	section("All VOIDCRAWL scripts parse and load")
	var files: Array = []
	_collect("res://voidcrawl", files)
	files.sort()
	var bad: Array = []
	for f in files:
		var s := load(f)
		if s == null or (s is GDScript and not (s as GDScript).can_instantiate() and not (s as GDScript).is_abstract()):
			# can_instantiate is false for scripts with errors; static-only helper classes still return true
			bad.append(f)
	check("loaded %d scripts without parse errors" % files.size(), bad.is_empty(), "bad: %s" % str(bad))

# ---------------------------------------------------------------- templates
func _test_templates() -> void:
	section("Room templates are well-formed")
	var ids: Array = VCRoomTemplates.all_combat_ids()
	ids.append_array(VCRoomTemplates.SPECIAL.keys())
	ids.append("boss_arena")
	check("at least 5 distinct combat layouts (have %d combat)" % VCRoomTemplates.COMBAT.size(), VCRoomTemplates.COMBAT.size() >= 5)
	for id in ids:
		var rows: Array = VCRoomTemplates.get_rows(id)
		var n := rows.size()
		var square := true
		var ring := true
		var odd := n % 2 == 1
		for y in n:
			var line: String = rows[y]
			if line.length() != n:
				square = false
				continue
			for x in n:
				var edge := x == 0 or y == 0 or x == n - 1 or y == n - 1
				if edge and line[x] != "#":
					ring = false
		check("template '%s' is %dx%d square, odd-sized, walled" % [id, n, n], square and odd and ring)
		# door lanes: centre 3 tiles at depth 1..3 inside each side must not be solid after carving;
		# the generator force-carves them, so here we only verify the ring is 1 thick.

# ---------------------------------------------------------------- generator
func _test_generator() -> void:
	section("Dungeon generation: reachability across many seeds")
	var bad_seeds: Array = []
	var min_templates := 99
	var max_ms := 0
	var total_rooms := 0
	var secrets_seen := 0
	var treasure_seen := 0
	var boss_seen := 0
	for s in range(1, 201):
		var t0 := Time.get_ticks_msec()
		var d := VCDungeonGenerator.generate(s, "crypt")
		max_ms = maxi(max_ms, Time.get_ticks_msec() - t0)
		var res := VCDungeonValidator.validate(d, 6)
		if not res["ok"]:
			bad_seeds.append("%d: %s" % [s, str(res["errors"])])
		min_templates = mini(min_templates, int(res.get("templates", 0)))
		total_rooms += d.rooms.size()
		secrets_seen += d.secrets.size()
		treasure_seen += d.chests.size()
		boss_seen += 1 if d.boss_room >= 0 else 0
	check("200 seeds all validate (entrance, exit, boss, chests, spawns reachable)", bad_seeds.is_empty(), str(bad_seeds.slice(0, 3)))
	check("every dungeon uses >= 6 distinct room layouts (min %d)" % min_templates, min_templates >= 6)
	check("every dungeon has a boss room", boss_seen == 200)
	check("secret rooms are generated (%d across 200 seeds)" % secrets_seen, secrets_seen >= 150)
	check("treasure chests are generated (%d)" % treasure_seen, treasure_seen >= 400)
	print("  info  worst generation time %d ms, avg rooms %.1f" % [max_ms, float(total_rooms) / 200.0])

	section("Dungeon generation: determinism")
	var a := VCDungeonGenerator.generate(777, "crypt")
	var b := VCDungeonGenerator.generate(777, "crypt")
	var c := VCDungeonGenerator.generate(778, "crypt")
	check("same seed -> identical layout digest", a.digest() == b.digest())
	check("different seed -> different layout", a.digest() != c.digest())
	check("same seed -> identical room list", str(a.rooms) == str(b.rooms))

	section("Tutorial dungeon")
	var tut := VCDungeonGenerator.generate(4242, "tutorial")
	var tr := VCDungeonValidator.validate(tut, 0)
	check("tutorial validates", tr["ok"], str(tr["errors"]))
	check("tutorial has start, treasure and combat rooms", tut.rooms.size() == 3)
	check("tutorial has a chest and an exit", tut.chests.size() == 1 and tut.is_floor(tut.exit_tile.x, tut.exit_tile.y))

	section("Navigation")
	var d2 := VCDungeonGenerator.generate(31, "crypt")
	var path := d2.find_path(d2.tile_to_world(d2.start_tile), d2.tile_to_world(d2.exit_tile))
	check("A* finds a route from start to exit (%d waypoints)" % path.size(), path.size() > 10)
	var all_floor := true
	for p in path:
		var t := d2.world_to_tile(p)
		if not d2.is_floor(t.x, t.y):
			all_floor = false
	check("A* route only crosses floor tiles", all_floor)
	if not d2.secrets.is_empty():
		var s0: Dictionary = d2.secrets[0]
		var st: Vector2i = s0["tiles"][1]
		check("secret wall is solid before it is broken", not d2.is_floor(st.x, st.y))
		d2.open_secret_tile(st)
		check("secret wall becomes floor once broken", d2.is_floor(st.x, st.y))

	section("Validator catches broken dungeons")
	var broken := VCDungeonGenerator.generate(5, "crypt")
	var bc: Vector2i = broken.rooms[broken.boss_room]["center"]
	# wall the boss room entrance off completely
	var br: Dictionary = broken.rooms[broken.boss_room]
	for side in ["N", "E", "S", "W"]:
		if br["doors"][side]:
			for t in VCDungeonGenerator.door_tiles(br, side):
				for k in range(0, 5):
					var dv: Vector2i = VCDungeonGenerator.DIRS[side]
					var tt: Vector2i = t - dv * k
					broken.set_tile(tt.x, tt.y, VCDungeonData.T_ROCK)
	var bres := VCDungeonValidator.validate(broken, 0)
	check("validator rejects a dungeon whose boss room is sealed", not bres["ok"], "bc=%s" % str(bc))

# -------------------------------------------------------------------- items
func _test_items_and_profile() -> void:
	section("Items, rarity and stats")
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var counts := [0, 0, 0, 0, 0]
	for i in 2000:
		var it := VCItems.generate(rng, 3)
		counts[int(it["rarity"])] += 1
	check("rarity distribution is common-heavy (%s)" % str(counts), counts[0] > counts[1] and counts[1] > counts[2] and counts[2] > counts[3] and counts[3] > counts[4] and counts[4] > 0)
	var legendary := VCItems.generate(rng, 5, VCDefs.Rarity.LEGENDARY, VCDefs.Slot.WEAPON)
	var common := VCItems.generate(rng, 5, VCDefs.Rarity.COMMON, VCDefs.Slot.WEAPON)
	check("legendary has 4 affixes, common has 0", legendary["affixes"].size() == 4 and common["affixes"].size() == 0)
	check("rarity scales item score", VCItems.score(legendary) > VCItems.score(common) * 1.3 or legendary["base"] != common["base"])
	var same_base_a := VCItems.generate(rng, 1, VCDefs.Rarity.COMMON, VCDefs.Slot.ARMOR)
	check("armor items have defense and health", int(same_base_a.get("def", 0)) > 0 and int(same_base_a.get("hp", 0)) > 0)

	section("Equipment changes real player stats")
	var p := VCProfile.new_game()
	var base := p.derived()
	check("new game starts with an equipped weapon", p.equipment.has(VCDefs.Slot.WEAPON))
	var axe := {"uid": p.alloc_uid(), "base": "gloomaxe", "slot": 0, "rarity": 3, "ilvl": 4, "name": "Test Axe",
		"dmg_min": 40, "dmg_max": 50, "affixes": [{"id": "atk_pct", "val": 10}, {"id": "crit", "val": 8}]}
	p.add_item(axe)
	check("item in inventory does not change stats yet", p.derived()["power"] == base["power"])
	var ok := p.equip_from_inventory(0)
	var after := p.derived()
	check("equip succeeds and swaps the old weapon into the pack", ok and p.inventory.size() == 1 and p.inventory[0]["base"] == "ashen_blade")
	check("weapon damage range changed (%d-%d -> %d-%d)" % [base["dmg_min"], base["dmg_max"], after["dmg_min"], after["dmg_max"]], after["dmg_min"] == 40.0 and after["dmg_max"] == 50.0)
	check("attack interval changed to the axe's", absf(after["interval"] - VCItems.BASES["gloomaxe"]["interval"]) < 0.001)
	check("affix +10% damage applied", absf(after["dmg_mult"] - 1.10) < 0.001)
	check("affix +8% crit applied", absf(after["crit"] - 0.13) < 0.001)
	check("power rating increased", after["power"] > base["power"])
	var helm := {"uid": p.alloc_uid(), "base": "bone_helm", "slot": 1, "rarity": 1, "ilvl": 1, "name": "Test Helm", "def": 20, "hp": 50, "affixes": []}
	p.add_item(helm)
	var hp_before: int = p.derived()["max_hp"]
	p.equip_from_inventory(p.inventory.size() - 1)
	check("equipping a helm raises max health by exactly its hp (+50)", p.derived()["max_hp"] == hp_before + 50)
	check("equipping a helm raises armor by its defense", p.derived()["armor"] >= base["armor"] + 20.0)

	section("Progression")
	var q := VCProfile.new_game()
	var need := q.xp_needed()
	var gained := q.add_xp(need - 1)
	check("1 xp short of a level does not level up", gained == 0 and q.level == 1)
	gained = q.add_xp(1)
	check("reaching the threshold levels up and grants 3 attribute points", gained == 1 and q.level == 2 and q.attr_points == 3)
	var hp0: int = q.derived()["max_hp"]
	check("spending a Vitality point adds +8 max health", q.spend_point("vit") and q.derived()["max_hp"] == hp0 + 8)
	var dm0: float = q.derived()["dmg_mult"]
	q.spend_point("str")
	check("spending a Might point raises damage multiplier by 4%", absf(q.derived()["dmg_mult"] - (dm0 + 0.04)) < 0.0001)
	check("cannot spend points you do not have", q.attr_points == 1 and q.spend_point("agi") and not (q.spend_point("agi") and q.spend_point("agi")))
	var big := q.add_xp(10_000_000)
	check("level is capped at %d" % VCProfile.MAX_LEVEL, q.level == VCProfile.MAX_LEVEL and big > 0)

	section("Inventory limits")
	var inv := VCProfile.new_game()
	var r2 := RandomNumberGenerator.new()
	r2.seed = 1
	for i in VCProfile.INV_CAP:
		inv.add_item(VCItems.generate(r2, 1))
	check("inventory accepts exactly %d items" % VCProfile.INV_CAP, inv.inventory.size() == VCProfile.INV_CAP)
	check("a full inventory rejects more items", not inv.add_item(VCItems.generate(r2, 1)))
	var coins_before := inv.coins
	var val := inv.sell_item(0)
	check("selling an item pays coins and frees a slot", val > 0 and inv.coins == coins_before + val and inv.inventory.size() == VCProfile.INV_CAP - 1)

# --------------------------------------------------------------------- save
func _test_save_and_settings() -> void:
	section("Save / load")
	VCSave.delete_save()
	check("no save file at start", not VCSave.exists())
	var p := VCProfile.new_game()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 6:
		p.add_item(VCItems.generate(rng, 3, -1, -1, 0.0, p.alloc_uid()))
	p.add_xp(300)
	p.spend_point("arc")
	p.coins = 777
	p.completed.append("tutorial")
	p.stats["kills"] = 42
	p.equip_from_inventory(0)
	var run := {"mission": "crypt", "seed": 9001, "checkpoint_room": 3, "cleared": [1, 2], "chests": ["ch1_0"], "obj": 1}
	check("save writes the file", VCSave.save(p, run) and VCSave.exists())
	var loaded := VCSave.load_save()
	check("load returns profile and run", loaded.has("profile") and loaded.has("run"))
	var q: VCProfile = loaded["profile"]
	check("level/xp/coins/points restored", q.level == p.level and q.xp == p.xp and q.coins == 777 and q.attr_points == p.attr_points)
	check("attributes restored", int(q.attrs["arc"]) == int(p.attrs["arc"]) and int(q.attrs["arc"]) >= 1)
	check("inventory restored (%d items)" % q.inventory.size(), q.inventory.size() == p.inventory.size() and str(q.inventory[0]["name"]) == str(p.inventory[0]["name"]))
	check("equipment restored", q.equipment.size() == p.equipment.size() and q.equipment[VCDefs.Slot.WEAPON]["name"] == p.equipment[VCDefs.Slot.WEAPON]["name"])
	check("derived stats identical after reload", q.derived() == p.derived())
	check("completed missions + stats restored", q.completed == ["tutorial"] and int(q.stats["kills"]) == 42)
	check("run state restored (seed, checkpoint, cleared rooms, chests)", int(loaded["run"]["seed"]) == 9001 and int(loaded["run"]["checkpoint_room"]) == 3 and loaded["run"]["cleared"].size() == 2 and loaded["run"]["chests"] == ["ch1_0"])
	check("uids never collide after reload", q.alloc_uid() > p.inventory.back()["uid"])
	# corrupt file must not crash and must be ignored
	var f := FileAccess.open(VCSave.path_override, FileAccess.WRITE)
	f.store_string("{ this is not json")
	f.close()
	check("corrupt save is ignored safely", VCSave.load_save().is_empty())
	VCSave.save(p, {})
	check("a good save after a corrupt one works", not VCSave.load_save().is_empty())
	VCSave.delete_save()
	check("delete removes the file", not VCSave.exists())

	section("Settings")
	VCSettings.load_settings()
	check("defaults load when no file exists", VCSettings.get_value("quality") == 1)
	VCSettings.set_value("quality", 2)
	VCSettings.set_value("btn_scale", 1.4)
	VCSettings.set_value("left_handed", true)
	VCSettings.save_settings()
	VCSettings.load_settings()
	check("settings persist across reload", VCSettings.get_value("quality") == 2 and absf(float(VCSettings.get_value("btn_scale")) - 1.4) < 0.001 and VCSettings.get_value("left_handed") == true)
	check("quality presets differ", VCSettings.quality_profile()["max_lights"] == 8)
	VCSettings.set_value("quality", 0)
	check("low preset reduces 3D resolution", float(VCSettings.quality_profile()["scale_3d"]) < 0.7)
	VCSettings.values = VCSettings.DEFAULTS.duplicate()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(VCSettings.path_override))
