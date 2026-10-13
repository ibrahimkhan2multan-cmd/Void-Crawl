class_name VCDungeonValidator
extends RefCounted
## Proves a generated dungeon is playable: reachable entrance, route to the exit without
## breaking any secret wall, every chest/checkpoint/spawn reachable, no isolated floor.

## 4-connected flood fill. Returns a byte per tile (1 = reached).
static func flood(d: VCDungeonData, from: Vector2i, allow_secret: bool) -> PackedByteArray:
	var seen := PackedByteArray()
	seen.resize(d.w * d.h)
	seen.fill(0)
	if not d.in_bounds(from.x, from.y):
		return seen
	var stack: Array[Vector2i] = [from]
	seen[d.idx(from.x, from.y)] = 1
	while not stack.is_empty():
		var t: Vector2i = stack.pop_back()
		for dv in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = t + dv
			if not d.in_bounds(n.x, n.y) or seen[d.idx(n.x, n.y)] == 1:
				continue
			var tt := d.get_tile(n.x, n.y)
			if tt == VCDungeonData.T_FLOOR or (allow_secret and tt == VCDungeonData.T_SECRET):
				seen[d.idx(n.x, n.y)] = 1
				stack.append(n)
	return seen

static func validate(d: VCDungeonData, min_templates: int = 0) -> Dictionary:
	var errors: Array[String] = []
	if d.rooms.is_empty():
		errors.append("no rooms")
		return {"ok": false, "errors": errors}
	if not d.is_floor(d.start_tile.x, d.start_tile.y):
		errors.append("start tile is not floor")
	if not d.is_floor(d.exit_tile.x, d.exit_tile.y):
		errors.append("exit tile is not floor")

	var all_reach := flood(d, d.start_tile, true)
	var main_reach := flood(d, d.start_tile, false)

	# the exit must be reachable WITHOUT breaking anything
	if main_reach[d.idx(d.exit_tile.x, d.exit_tile.y)] != 1:
		errors.append("exit not reachable from start without breaking walls")
	if d.boss_room >= 0:
		var bc: Vector2i = d.rooms[d.boss_room]["center"]
		if main_reach[d.idx(bc.x, bc.y)] != 1:
			errors.append("boss room not reachable")

	# no isolated floor pockets anywhere (everything reachable once secrets are open)
	var floors := 0
	var reached := 0
	for y in d.h:
		for x in d.w:
			if d.get_tile(x, y) == VCDungeonData.T_FLOOR:
				floors += 1
				if all_reach[d.idx(x, y)] == 1:
					reached += 1
	if floors != reached:
		errors.append("%d floor tiles are unreachable" % (floors - reached))

	for ch in d.chests:
		var t: Vector2i = ch["tile"]
		if not d.is_floor(t.x, t.y):
			errors.append("chest %s not on floor" % ch["id"])
		elif all_reach[d.idx(t.x, t.y)] != 1:
			errors.append("chest %s unreachable" % ch["id"])
	for cp in d.checkpoints:
		var t2: Vector2i = cp["tile"]
		if main_reach[d.idx(t2.x, t2.y)] != 1:
			errors.append("checkpoint %s unreachable" % cp["id"])
	for r in d.rooms:
		var enc: Dictionary = r.get("encounter", {})
		for wave in enc.get("waves", []):
			var seen_spawns := {}      # waves spawn one after another, so only same-wave overlaps matter
			for e in wave:
				var t3: Vector2i = e["tile"]
				if not d.is_floor(t3.x, t3.y):
					errors.append("enemy spawn in room %d is not on floor" % r["id"])
				elif all_reach[d.idx(t3.x, t3.y)] != 1:
					errors.append("enemy spawn in room %d unreachable" % r["id"])
				if seen_spawns.has(t3):
					errors.append("two enemies share a tile in room %d" % r["id"])
				seen_spawns[t3] = true
		if int(r["floor_count"] if r.has("floor_count") else 1) <= 0:
			errors.append("room %d has no floor" % r["id"])
	for s in d.secrets:
		var any_adjacent_floor := false
		for t4 in s["tiles"]:
			for dv in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if d.is_floor(t4.x + dv.x, t4.y + dv.y):
					any_adjacent_floor = true
		if not any_adjacent_floor:
			errors.append("secret wall %s is not adjacent to floor" % s["id"])
	var templates := {}
	for r in d.rooms:
		templates[r["template"]] = true
	if templates.size() < min_templates:
		errors.append("only %d distinct room templates (need %d)" % [templates.size(), min_templates])
	return {"ok": errors.is_empty(), "errors": errors, "templates": templates.size(), "rooms": d.rooms.size(), "floors": floors}
