extends RefCounted
## Chaos soak: random inputs, teleports and overlay toggles on several seeds. Run with:
##   godot --headless res://voidcrawl/tests/test_runner.tscn -- suite=soak
## Script errors show up in the output as SCRIPT ERROR lines; the suite also tracks node/object growth.

static func run(t: Node) -> void:
	t.section("soak: chaos on several seeds")
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	for seed_ in [11, 222, 3333, 44444]:
		VC.new_game()
		VC.pending = {"mission": "crypt", "seed": seed_, "resume": false}
		var m: VCMission = load("res://voidcrawl/scenes/mission.tscn").instantiate()
		m.fast_build = true
		t.add_child(m)
		var g := 0
		while not m.build_done and g < 600:
			await t.get_tree().process_frame
			g += 1
		var nodes0 := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
		var rooms: Array = m.data.rooms
		for step in 60 * 40:
			if step % 20 == 0:
				VCInput.touch_move = Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1))
				VCInput.touch_attack_held = rng.randf() < 0.7
			if step % 45 == 0 and rng.randf() < 0.5:
				VCInput.press("dodge")
			if step % 90 == 0 and rng.randf() < 0.5:
				VCInput.press("ability")
			if step % 120 == 0 and rng.randf() < 0.5:
				VCInput.press("heal")
			if step % 150 == 0:
				VCInput.press("interact")
			if step % 400 == 0 and m.player.is_alive():
				var r: Dictionary = rooms[rng.randi() % rooms.size()]
				m.player.global_position = m.data.tile_to_world(r["center"])
			if step % 600 == 300:
				m.open_overlay("pack")
				await t.get_tree().physics_frame
				m.close_overlay()
			if not m.player.is_alive() and not m._defeat_shown:
				pass
			if m._defeat_shown:
				m.retry()
			await t.get_tree().physics_frame
		VCInput.reset()
		var nodes1 := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
		t.check("seed %d survived 40s of chaos" % seed_, is_instance_valid(m) and not m.finished or m.finished)
		t.check("seed %d node count stays bounded (%d -> %d)" % [seed_, nodes0, nodes1], nodes1 < nodes0 + 600)
		m.get_tree().paused = false
		m.queue_free()
		await t.get_tree().process_frame
