extends RefCounted
## v0.9 features: mod pets, the tester freezing the game, the health-bar text fix, the cleaner wall window.

const GP := preload("res://voidcrawl/tests/test_gameplay.gd")
const CT := preload("res://voidcrawl/tests/test_content.gd")

static func run(t: Node) -> void:
	await _bar_text(t)
	await _mod_pets(t)
	await _tester_freeze(t)

static func _bar_text(t: Node) -> void:
	t.section("v0.9: health bar text")
	var bar := VCBar.new()
	bar.size = Vector2(300, 28)
	t.add_child(bar)
	bar.set_values(90.0, 90.0)
	bar.snap()
	await t.get_tree().process_frame
	# the bar is already settled; changing only the text must still repaint it
	var drew := [false]
	bar.draw.connect(func(): drew[0] = true)
	bar.text = "90 / 90"
	await t.get_tree().process_frame
	await t.get_tree().process_frame
	t.check("changing only the text repaints a settled bar", drew[0])
	drew[0] = false
	bar.set_values(40.0, 120.0)
	await t.get_tree().process_frame
	await t.get_tree().process_frame
	t.check("changing the maximum repaints the bar", drew[0])
	bar.queue_free()
	# real HUD in a dungeon shows numbers right away and after level / max-health changes
	var m: VCMission = await GP._launch(t, "tutorial")
	await GP._frames(t, 6)
	t.check("HUD health text is filled in", m.hud.hp_bar.text == "%d / %d" % [int(ceil(m.player.hp)), m.player.max_hp], m.hud.hp_bar.text)
	m.player.max_hp += 500
	m.player.hp = float(m.player.max_hp)
	await GP._frames(t, 3)
	t.check("HUD health text follows max health", m.hud.hp_bar.text == "%d / %d" % [m.player.max_hp, m.player.max_hp], m.hud.hp_bar.text)
	m.queue_free()
	await t.get_tree().process_frame

static func _mod_pets(t: Node) -> void:
	t.section("v0.9: mods add pets")
	VCMods.remove("sunfire")
	VCMods.remove("petmod")
	var base_n := VCPets.SPECIES.size()
	var r := VCMods.install_example()
	t.check("example mod installs with a pet", bool(r["ok"]), String(r["msg"]))
	t.check("example pet joins the game", VCPets.SPECIES.has("sunfire__ember_cub") and VCPets.SPECIES.size() == base_n + 1)
	var pk := VCMods.list.filter(func(i): return String(i["id"]) == "sunfire")
	t.check("mod info counts pets", pk.size() == 1 and int(pk[0]["pets"]) == 1)
	# a hostile pack: wild numbers are clamped, bad entries skipped
	var files := {"mod.json": {"id": "petmod", "name": "Pet Mod"},
		"pets.json": {"pets": {
			"god": {"name": "God Dog", "rarity": 99, "style": "quad", "ai": "ranged", "hp": 9999999, "dmg": 99999, "interval": 0.0, "passive": {"atk_pct": 9999, "hp": 99999}},
			"nostyle": {"name": "Odd", "style": "banana"},
			"noname": {"style": "quad"},
			"ok": {"name": "Tiny Newt", "rarity": 1, "style": "blob", "color": "#33aa55", "passive": {"def": 2}}}}}
	var wr := VCMods.install_bytes(CT._zip_pack("user://petmod.zip", files))
	t.check("pet pack installs", bool(wr["ok"]), String(wr["msg"]))
	t.check("bad pets are skipped", VCPets.SPECIES.has("petmod__god") and VCPets.SPECIES.has("petmod__ok") and not VCPets.SPECIES.has("petmod__nostyle") and not VCPets.SPECIES.has("petmod__noname"))
	if VCPets.SPECIES.has("petmod__god"):
		var g: Dictionary = VCPets.SPECIES["petmod__god"]
		t.check("wild pet numbers are clamped", int(g["rarity"]) <= VCDefs.RARITY_MAX and float(g["hp"]) <= 1000.0 and float(g["dmg"]) <= 60.0 and float(g["interval"]) >= 0.35)
		t.check("wild passives are clamped", float(g["passive"].get("atk_pct", 0.0)) <= 40.0 and float(g["passive"].get("hp", 0.0)) <= 150.0)
		t.check("pet stat functions work for a mod pet", VCPets.max_hp("petmod__god", 3) > 0.0 and VCPets.dps("petmod__god", 3) > 0.0)
	# eggs can hatch a mod pet
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var seen := false
	for i in 1500:
		if String(VCPets.roll_species(rng, "rare")).begins_with("petmod__") or String(VCPets.roll_species(rng, "common")).begins_with("sunfire__"):
			seen = true
			break
	t.check("eggs can hatch mod pets", seen)
	# own it, equip it, see it in a dungeon
	VC.new_game()
	var P: VCProfile = VC.profile
	P.pets["petmod__ok"] = 3
	P.pets_active = ["petmod__ok"]
	var m: VCMission = await GP._launch(t, "tutorial")
	P = VC.profile
	P.pets["petmod__ok"] = 3
	P.pets_active = ["petmod__ok"]
	m._spawn_pets()
	await GP._frames(t, 20)
	t.check("a mod pet spawns and follows in a dungeon", m.pets.size() == 1 and is_instance_valid(m.pets[0]))
	var pp := VCPetsPanel.new()
	t.add_child(pp)
	await t.get_tree().process_frame
	t.check("pets panel lists a mod pet", pp._list.get_child_count() >= 2)
	pp.queue_free()
	m.queue_free()
	await t.get_tree().process_frame
	# turn the mod off: the pet is put away, not lost; turn it on: it returns
	VC.new_game()
	P = VC.profile
	P.pets["petmod__ok"] = 4
	P.pets_active = ["petmod__ok"]
	VCMods.set_enabled("petmod", false)
	t.check("pets of a disabled mod are put away", not P.pets.has("petmod__ok") and P.pets_parked.has("petmod__ok") and P.pets_active.is_empty())
	var d := P.to_dict()
	var P2 := VCProfile.from_dict(d)
	t.check("parked pets survive save and load", P2.pets_parked.has("petmod__ok") and int(P2.pets_parked["petmod__ok"]) == 4)
	VCMods.set_enabled("petmod", true)
	t.check("pets return when the mod is back", P.pets.has("petmod__ok") and int(P.pets["petmod__ok"]) == 4 and not P.pets_parked.has("petmod__ok"))
	VCMods.remove("petmod")
	VCMods.remove("sunfire")
	t.check("removing the mods removes their pets", VCPets.SPECIES.size() == base_n)
	DirAccess.remove_absolute("user://petmod.zip")
	VC.new_game()

static func _tester_freeze(t: Node) -> void:
	t.section("v0.9: tester freezes the game")
	var m: VCMission = await GP._launch(t, "tutorial")
	VCSettings.set_value("tester_unlocked", true)
	VCSettings.set_value("tester_freeze", true)
	m.toggle_tester(true)
	await GP._frames(t, 3)
	t.check("opening the tester pauses the game", t.get_tree().paused)
	var x0 := m.player.global_position
	Input.action_press("move_right")
	await GP._frames(t, 20)
	Input.action_release("move_right")
	t.check("the hero does not move while the tester is open", m.player.global_position.distance_to(x0) < 0.05)
	var tw: VCTesterWindow = m.tester_win
	tw._freeze_btn.pressed.emit()
	await GP._frames(t, 2)
	t.check("FREEZE OFF lets the game run again", not t.get_tree().paused and not bool(VCSettings.get_value("tester_freeze")))
	tw._freeze_btn.pressed.emit()
	await GP._frames(t, 2)
	t.check("FREEZE ON pauses it again", t.get_tree().paused)
	m.toggle_tester()
	await GP._frames(t, 3)
	t.check("closing the tester resumes the game", not t.get_tree().paused and m.tester_win == null)
	# the pause menu owns its own pause
	m.open_overlay("pause")
	await GP._frames(t, 2)
	m.toggle_tester(true)
	await GP._frames(t, 2)
	m.close_overlay()
	await GP._frames(t, 2)
	t.check("pause menu resume + tester open keeps the freeze consistent", t.get_tree().paused == (m.tester_win != null))
	m.toggle_tester()
	await GP._frames(t, 2)
	t.check("game runs after everything is closed", not t.get_tree().paused)
	VCSettings.set_value("tester_unlocked", false)
	t.get_tree().paused = false
	m.queue_free()
	await t.get_tree().process_frame
