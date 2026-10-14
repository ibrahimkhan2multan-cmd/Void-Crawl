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
	m.queue_free()
	await t.get_tree().process_frame
