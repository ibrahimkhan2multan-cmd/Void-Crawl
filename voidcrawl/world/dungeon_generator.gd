class_name VCDungeonGenerator
extends RefCounted
## Deterministic dungeon generator. Same seed + mission id => identical dungeon.
##
## 1. Build a room graph on a coarse grid (a self-avoiding main path start->boss,
##    plus side branches: treasure, a secret room behind a cracked wall, extra combat).
## 2. Stamp a hand-designed template into each room.
## 3. Carve straight 3-wide corridors between connected rooms and guaranteed door lanes.
## 4. Populate chests, props, encounters, checkpoints and lights.
## The result is always run through VCDungeonValidator by the caller.

const PITCH := 26
const MARGIN := 3
const SIDES := ["N", "E", "S", "W"]
const DIRS := {"N": Vector2i(0, -1), "E": Vector2i(1, 0), "S": Vector2i(0, 1), "W": Vector2i(-1, 0)}

static func generate(seed_: int, mission_id: String) -> VCDungeonData:
	var m := VCMissions.get_mission(mission_id)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var graph: Dictionary
	if String(m.get("layout", "procedural")) == "tutorial":
		graph = _tutorial_graph()
	else:
		graph = _procedural_graph(rng, int(m.get("cols", 4)), int(m.get("rows", 4)), int(m.get("path_len", 8)), String(m.get("palette", "crypt")))
	var cols: int = graph["cols"]
	var rows: int = graph["rows"]
	var d := VCDungeonData.new()
	d.seed = seed_
	d.mission_id = mission_id
	d.setup(cols * PITCH + MARGIN * 2, rows * PITCH + MARGIN * 2)
	d.rooms = graph["rooms"]
	# templates + stamping
	var used := {}
	for r in d.rooms:
		r["template"] = _pick_template(rng, r, used)
		used[r["template"]] = true
		r["size"] = _template_size(r["template"])
		var cell: Vector2i = r["cell"]
		r["center"] = Vector2i(MARGIN + cell.x * PITCH + PITCH / 2, MARGIN + cell.y * PITCH + PITCH / 2)
		r["doors"] = {"N": false, "E": false, "S": false, "W": false}
		r["spawns"] = []
		r["chest_spots"] = []
		_stamp_room(d, r)
	for e in graph["edges"]:
		_connect(d, int(e[0]), int(e[1]), bool(e[2]))
	_populate(d, rng, m, graph)
	d.build_nav()
	return d

# ------------------------------------------------------------------ graph --

static func _theme_for_path(i: int, n: int, palette: String = "crypt") -> String:
	if palette == "frost":
		if i == n - 1:
			return "rime"
		return "ice" if i < 3 else ("glacier" if i < 6 else "rime")
	if palette == "ember":
		if i == n - 1:
			return "magma"
		return "ash" if i < 3 else ("forge" if i < 6 else "magma")
	if i == n - 1:
		return "void"
	if i < 2:
		return "crypt"
	if i < 4:
		return "cavern"
	if i < 6:
		return "ruins"
	return "overgrown"

static func _new_room(id: int, type: String, theme: String, cell: Vector2i, depth: int, parent: int) -> Dictionary:
	return {"id": id, "type": type, "theme": theme, "cell": cell, "depth": depth, "parent": parent,
		"secret": false, "encounter": {}}

static func _tutorial_graph() -> Dictionary:
	var rooms: Array = []
	rooms.append(_new_room(0, "start", "crypt", Vector2i(0, 0), 0, -1))
	rooms.append(_new_room(1, "treasure", "crypt", Vector2i(1, 0), 1, 0))
	rooms.append(_new_room(2, "combat", "crypt", Vector2i(2, 0), 2, 1))
	rooms[2]["template"] = "ruined_arena"
	return {"cols": 3, "rows": 1, "rooms": rooms, "edges": [[0, 1, false], [1, 2, false]], "path": [0, 1, 2]}

static func _procedural_graph(rng: RandomNumberGenerator, cols: int, rows: int, path_len: int, palette: String = "crypt") -> Dictionary:
	var path: Array[Vector2i] = []
	var dirs := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(-1, 0)]
	for attempt in 400:
		var start := Vector2i(0, rng.randi_range(0, rows - 1))
		var p: Array[Vector2i] = [start]
		var used := {start: true}
		var ok := true
		while p.size() < path_len:
			var cur: Vector2i = p[p.size() - 1]
			var opts: Array[Vector2i] = []
			for dv in dirs:
				var n: Vector2i = cur + dv
				if n.x < 0 or n.y < 0 or n.x >= cols or n.y >= rows or used.has(n):
					continue
				opts.append(n)
				if dv == Vector2i(1, 0):
					opts.append(n)      # bias the walk towards the right so it progresses
			if opts.is_empty():
				ok = false
				break
			var pick: Vector2i = opts[rng.randi_range(0, opts.size() - 1)]
			p.append(pick)
			used[pick] = true
		if ok:
			path = p
			break
	if path.is_empty():
		# deterministic serpentine fallback; always valid on a grid with >= path_len cells
		for y in rows:
			for xi in cols:
				var x := xi if y % 2 == 0 else cols - 1 - xi
				if path.size() < path_len:
					path.append(Vector2i(x, y))
	var n := path.size()
	var rooms: Array = []
	var cell_to_room := {}
	var edges: Array = []
	var path_ids: Array = []
	var cp_index := n / 2
	for i in n:
		var t := "combat"
		if i == 0:
			t = "start"
		elif i == n - 1:
			t = "boss"
		elif i == cp_index:
			t = "checkpoint"
		var r := _new_room(i, t, _theme_for_path(i, n, palette), path[i], i, i - 1)
		rooms.append(r)
		cell_to_room[path[i]] = i
		path_ids.append(i)
		if i > 0:
			edges.append([i - 1, i, false])
	# side branches
	var cands: Array = []   # [cell, parent_index]
	for i in range(1, n - 1):
		for dv in dirs:
			var c: Vector2i = path[i] + dv
			if c.x < 0 or c.y < 0 or c.x >= cols or c.y >= rows or cell_to_room.has(c):
				continue
			cands.append([c, i])
	# deterministic shuffle
	for i in range(cands.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = cands[i]
		cands[i] = cands[j]
		cands[j] = tmp
	var branch_types := ["treasure", "secret", "combat"]
	var bi := 0
	for cand in cands:
		if bi >= branch_types.size():
			break
		var c: Vector2i = cand[0]
		if cell_to_room.has(c):
			continue
		var parent: int = cand[1]
		var id := rooms.size()
		var bt: String = branch_types[bi]
		var theme: String = rooms[parent]["theme"]
		var r := _new_room(id, "treasure" if bt == "secret" else bt, theme, c, int(rooms[parent]["depth"]) + 1, parent)
		r["secret"] = (bt == "secret")
		rooms.append(r)
		cell_to_room[c] = id
		edges.append([parent, id, bt == "secret"])
		bi += 1
	return {"cols": cols, "rows": rows, "rooms": rooms, "edges": edges, "path": path_ids}

# -------------------------------------------------------------- templates --

static func _pick_template(rng: RandomNumberGenerator, r: Dictionary, used: Dictionary) -> String:
	if r.has("template"):
		return r["template"]
	match String(r["type"]):
		"start": return "start_crypt"
		"checkpoint": return "checkpoint_shrine"
		"treasure": return "treasure_vault"
		"boss": return "boss_arena"
	var themed := VCRoomTemplates.combat_ids_for_theme(String(r["theme"]))
	var fresh_themed: Array = themed.filter(func(id): return not used.has(id))
	if not fresh_themed.is_empty():
		return fresh_themed[rng.randi_range(0, fresh_themed.size() - 1)]
	var all_ids := VCRoomTemplates.all_combat_ids()
	var fresh: Array = all_ids.filter(func(id): return not used.has(id))
	if not fresh.is_empty():
		return fresh[rng.randi_range(0, fresh.size() - 1)]
	return themed[rng.randi_range(0, themed.size() - 1)] if not themed.is_empty() else all_ids[0]

static func _template_size(id: String) -> int:
	var rows := VCRoomTemplates.get_rows(id)
	return rows.size()

static func _decor_kind(ch: String) -> String:
	match ch:
		"P": return "pillar"
		"S": return "sarcophagus"
		"T": return "tree"
		"k": return "crystal"
	return ""

static func _stamp_room(d: VCDungeonData, r: Dictionary) -> void:
	var rows := VCRoomTemplates.get_rows(String(r["template"]))
	var size: int = rows.size()
	var half := size / 2
	var c: Vector2i = r["center"]
	r["props"] = []
	r["braziers"] = []
	for ty in size:
		var line: String = rows[ty]
		for tx in size:
			var ch := line.substr(tx, 1)
			var x := c.x - half + tx
			var y := c.y - half + ty
			d.room_map[d.idx(x, y)] = int(r["id"])
			if ch == "#":
				d.set_tile(x, y, VCDungeonData.T_ROCK)
				continue
			var dk := _decor_kind(ch)
			if dk != "":
				d.set_tile(x, y, VCDungeonData.T_DECOR)
				d.decor[Vector2i(x, y)] = dk
				continue
			d.set_tile(x, y, VCDungeonData.T_FLOOR)
			match ch:
				"e": r["spawns"].append(Vector2i(x, y))
				"x": r["chest_spots"].append(Vector2i(x, y))
				"c": r["props"].append(Vector2i(x, y))
				"t": r["braziers"].append(Vector2i(x, y))

static func door_tiles(r: Dictionary, side: String) -> Array:
	var c: Vector2i = r["center"]
	var half: int = int(r["size"]) / 2
	var out: Array = []
	for o in [-1, 0, 1]:
		match side:
			"N": out.append(Vector2i(c.x + o, c.y - half))
			"S": out.append(Vector2i(c.x + o, c.y + half))
			"E": out.append(Vector2i(c.x + half, c.y + o))
			"W": out.append(Vector2i(c.x - half, c.y + o))
	return out

static func _force_floor(d: VCDungeonData, x: int, y: int, room_id: int) -> void:
	d.set_tile(x, y, VCDungeonData.T_FLOOR)
	d.decor.erase(Vector2i(x, y))
	if room_id >= 0:
		d.room_map[d.idx(x, y)] = room_id

static func _carve_door_lane(d: VCDungeonData, r: Dictionary, side: String) -> void:
	# door opening + 3 tiles of guaranteed lane inside the room, 3 wide
	var c: Vector2i = r["center"]
	var half: int = int(r["size"]) / 2
	var id: int = int(r["id"])
	for depth in range(0, 4):
		for o in [-1, 0, 1]:
			match side:
				"N": _force_floor(d, c.x + o, c.y - half + depth, id)
				"S": _force_floor(d, c.x + o, c.y + half - depth, id)
				"E": _force_floor(d, c.x + half - depth, c.y + o, id)
				"W": _force_floor(d, c.x - half + depth, c.y + o, id)
	r["doors"][side] = true

static func _connect(d: VCDungeonData, a_id: int, b_id: int, secret: bool) -> void:
	var ra: Dictionary = d.rooms[a_id]
	var rb: Dictionary = d.rooms[b_id]
	var ca: Vector2i = ra["center"]
	var cb: Vector2i = rb["center"]
	if cb.x != ca.x:
		var left: Dictionary = ra if ca.x < cb.x else rb
		var right: Dictionary = rb if ca.x < cb.x else ra
		_carve_door_lane(d, left, "E")
		_carve_door_lane(d, right, "W")
		var cy: int = ca.y
		var x0: int = int(left["center"].x) + int(left["size"]) / 2
		var x1: int = int(right["center"].x) - int(right["size"]) / 2
		for x in range(x0, x1 + 1):
			for dy in [-1, 0, 1]:
				if d.room_map[d.idx(x, cy + dy)] == -1:
					d.set_tile(x, cy + dy, VCDungeonData.T_FLOOR)
		var mid := (x0 + x1) / 2
		if secret:
			var ts: Array = []
			for dy in [-1, 0, 1]:
				d.set_tile(mid, cy + dy, VCDungeonData.T_SECRET)
				ts.append(Vector2i(mid, cy + dy))
			d.secrets.append({"id": "s%d" % d.secrets.size(), "tiles": ts, "from_room": a_id, "to_room": b_id})
		var x := x0 + 3
		var flip := 1
		while x < x1 - 2:
			if absi(x - mid) > 1 or not secret:
				d.torches.append({"tile": Vector2i(x, cy - 2 if flip > 0 else cy + 2), "facing": Vector2i(0, 1 * flip)})
			flip = -flip
			x += 5
	else:
		var top: Dictionary = ra if ca.y < cb.y else rb
		var bot: Dictionary = rb if ca.y < cb.y else ra
		_carve_door_lane(d, top, "S")
		_carve_door_lane(d, bot, "N")
		var cx: int = ca.x
		var y0: int = int(top["center"].y) + int(top["size"]) / 2
		var y1: int = int(bot["center"].y) - int(bot["size"]) / 2
		for y in range(y0, y1 + 1):
			for dx in [-1, 0, 1]:
				if d.room_map[d.idx(cx + dx, y)] == -1:
					d.set_tile(cx + dx, y, VCDungeonData.T_FLOOR)
		var midy := (y0 + y1) / 2
		if secret:
			var ts2: Array = []
			for dx in [-1, 0, 1]:
				d.set_tile(cx + dx, midy, VCDungeonData.T_SECRET)
				ts2.append(Vector2i(cx + dx, midy))
			d.secrets.append({"id": "s%d" % d.secrets.size(), "tiles": ts2, "from_room": a_id, "to_room": b_id})
		var y := y0 + 3
		var flip2 := 1
		while y < y1 - 2:
			if absi(y - midy) > 1 or not secret:
				d.torches.append({"tile": Vector2i(cx - 2 if flip2 > 0 else cx + 2, y), "facing": Vector2i(1 * flip2, 0)})
			flip2 = -flip2
			y += 5

# -------------------------------------------------------------- populate --

static func _flood(d: VCDungeonData, from: Vector2i, allow_secret: bool) -> PackedByteArray:
	return VCDungeonValidator.flood(d, from, allow_secret)

static func _populate(d: VCDungeonData, rng: RandomNumberGenerator, m: Dictionary, graph: Dictionary) -> void:
	var reach := _flood(d, d.rooms[0]["center"], true)
	d.start_tile = d.rooms[0]["center"]
	d.checkpoints.append({"id": "cp_start", "room": 0, "tile": d.start_tile})
	var tutorial := String(m.get("layout", "")) == "tutorial"
	for r in d.rooms:
		var id: int = int(r["id"])
		var c: Vector2i = r["center"]
		for b in r["braziers"]:
			d.braziers.append({"tile": b})
		var pi := 0
		for p in r["props"]:
			d.props.append({"id": "p%d_%d" % [id, pi], "kind": "crate" if (pi + id) % 2 == 0 else "barrel", "tile": p, "room": id})
			pi += 1
		match String(r["type"]):
			"checkpoint":
				d.checkpoints.append({"id": "cp%d" % id, "room": id, "tile": c})
			"treasure":
				var spots: Array = r["chest_spots"] if not r["chest_spots"].is_empty() else [c]
				var ci := 0
				for s in spots:
					d.chests.append({"id": "ch%d_%d" % [id, ci], "tile": s, "tier": 2 if bool(r["secret"]) else 1, "room": id})
					ci += 1
			"boss":
				d.boss_room = id
				d.exit_tile = c
		# decorative wall torches around the room edge
		_place_wall_lights(d, rng, r)
	if tutorial:
		d.exit_tile = d.rooms[2]["center"]
		d.marker_tile = d.rooms[0]["center"] + Vector2i(4, 0)
		_tutorial_encounters(d, rng, reach)
	else:
		for r in d.rooms:
			if String(r["type"]) == "combat":
				_combat_encounter(d, rng, r, reach)
	# every room needs a stable list of its floor tiles for gating/minimap
	for r in d.rooms:
		r["floor_count"] = d.room_floor_tiles(int(r["id"])).size()

static func _place_wall_lights(d: VCDungeonData, rng: RandomNumberGenerator, r: Dictionary) -> void:
	var c: Vector2i = r["center"]
	var size: int = int(r["size"])
	var half := size / 2
	var cands: Array = []
	for i in range(2, size - 2):
		for side in SIDES:
			var t := Vector2i.ZERO
			match side:
				"N": t = Vector2i(c.x - half + i, c.y - half)
				"S": t = Vector2i(c.x - half + i, c.y + half)
				"E": t = Vector2i(c.x + half, c.y - half + i)
				"W": t = Vector2i(c.x - half, c.y - half + i)
			var facing: Vector2i = -DIRS[side]
			if d.get_tile(t.x, t.y) == VCDungeonData.T_ROCK and d.is_floor(t.x + facing.x, t.y + facing.y):
				# keep clear of door openings
				if absi(i - half) > 2:
					cands.append([t, facing])
	var want := 7 if String(r["type"]) == "boss" else 4
	for k in want:
		if cands.is_empty():
			break
		var j := rng.randi_range(0, cands.size() - 1)
		var cand: Array = cands[j]
		cands.remove_at(j)
		if k % 3 == 2 or String(r["theme"]) == "cavern" and k % 2 == 1:
			d.wall_crystals.append({"tile": cand[0], "facing": cand[1]})
		else:
			d.torches.append({"tile": cand[0], "facing": cand[1]})

static func _enemy_pool(depth: int, kind: String = "crypt", mission_id: String = "") -> Array:
	var pool := _base_pool(depth, kind)
	for extra in VCMods.pool_additions(kind, depth, mission_id):
		pool.append(extra)
	if pool.is_empty():
		pool.append([VCDefs.ENEMY_HUSK, 1.0])
	return pool

static func _base_pool(depth: int, kind: String) -> Array:
	if kind == "none":
		return []
	if kind == "frost":
		var fp: Array = [[VCDefs.ENEMY_HUSK, 2.0], [VCDefs.ENEMY_ICEARCHER, 3.0], [VCDefs.ENEMY_SPIDER, 1.5]]
		if depth >= 1:
			fp.append([VCDefs.ENEMY_SHIELD, 2.5])
			fp.append([VCDefs.ENEMY_FROSTWRAITH, 2.5])
		if depth >= 2:
			fp.append([VCDefs.ENEMY_CULTIST, 1.0])
		if depth >= 3:
			fp.append([VCDefs.ENEMY_YETI, 2.0])
			fp.append([VCDefs.ENEMY_WEAVER, 1.5])
		return fp
	if kind == "ember":
		var ep: Array = [[VCDefs.ENEMY_HUSK, 3.0], [VCDefs.ENEMY_MITE, 3.0]]
		if depth >= 1:
			ep.append([VCDefs.ENEMY_SHIELD, 3.0])
			ep.append([VCDefs.ENEMY_CULTIST, 2.5])
		if depth >= 2:
			ep.append([VCDefs.ENEMY_WISP, 1.5])
		if depth >= 3:
			ep.append([VCDefs.ENEMY_WEAVER, 1.5])
			ep.append([VCDefs.ENEMY_BRUTE, 1.5])
		return ep
	if kind == "mixed":
		var mp: Array = [[VCDefs.ENEMY_HUSK, 3.0], [VCDefs.ENEMY_SLINGER, 2.0], [VCDefs.ENEMY_SPIDER, 1.5], [VCDefs.ENEMY_MITE, 2.0],
			[VCDefs.ENEMY_SHIELD, 2.0], [VCDefs.ENEMY_CULTIST, 2.0]]
		if depth >= 2:
			mp.append([VCDefs.ENEMY_WISP, 1.5])
			mp.append([VCDefs.ENEMY_ICEARCHER, 1.5])
			mp.append([VCDefs.ENEMY_FROSTWRAITH, 1.2])
		if depth >= 3:
			mp.append([VCDefs.ENEMY_BRUTE, 1.5])
			mp.append([VCDefs.ENEMY_YETI, 1.0])
			mp.append([VCDefs.ENEMY_WEAVER, 1.5])
		return mp
	var pool: Array = [[VCDefs.ENEMY_HUSK, 6.0]]
	if depth >= 1:
		pool.append([VCDefs.ENEMY_SLINGER, 3.0])
		pool.append([VCDefs.ENEMY_SPIDER, 2.0])
	if depth >= 2:
		pool.append([VCDefs.ENEMY_WISP, 2.0])
	if depth >= 3:
		pool.append([VCDefs.ENEMY_BRUTE, 1.5])
	return pool

static func _pick_weighted(rng: RandomNumberGenerator, pool: Array) -> String:
	var total := 0.0
	for e in pool:
		total += float(e[1])
	var roll := rng.randf() * total
	for e in pool:
		roll -= float(e[1])
		if roll <= 0.0:
			return String(e[0])
	return String(pool[0][0])

static func _spawn_tiles(d: VCDungeonData, rng: RandomNumberGenerator, r: Dictionary, reach: PackedByteArray, count: int) -> Array:
	var out: Array = []
	var markers: Array = []
	for t in r["spawns"]:
		if reach[d.idx(t.x, t.y)] == 1:
			markers.append(t)
	for i in range(markers.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = markers[i]
		markers[i] = markers[j]
		markers[j] = tmp
	var taken := {}
	for t in markers:
		if out.size() >= count:
			break
		out.append(t)
		taken[t] = true
	# top up with random interior floor tiles, away from the door lanes
	var floors := d.room_floor_tiles(int(r["id"]))
	var c: Vector2i = r["center"]
	var guard := 0
	while out.size() < count and not floors.is_empty() and guard < 400:
		guard += 1
		var t: Vector2i = floors[rng.randi_range(0, floors.size() - 1)]
		if taken.has(t) or reach[d.idx(t.x, t.y)] != 1:
			continue
		var off := t - c
		var half: int = int(r["size"]) / 2
		if absi(off.x) > half - 3 or absi(off.y) > half - 3:
			continue
		if (absi(off.x) <= 1 and absi(off.y) > half - 5) or (absi(off.y) <= 1 and absi(off.x) > half - 5):
			continue
		out.append(t)
		taken[t] = true
	return out

static func _combat_encounter(d: VCDungeonData, rng: RandomNumberGenerator, r: Dictionary, reach: PackedByteArray) -> void:
	var depth: int = int(r["depth"])
	var n := clampi(2 + depth / 2 + rng.randi_range(0, 2), 3, 7)
	var waves: Array = []
	var wave_count := 2 if depth >= 3 else 1
	for w in wave_count:
		var count := n if w == 0 else maxi(2, n - 2)
		var tiles := _spawn_tiles(d, rng, r, reach, count)
		var wave: Array = []
		var brutes := 0
		for t in tiles:
			var kind := _pick_weighted(rng, _enemy_pool(depth, String(VCMissions.get_mission(d.mission_id).get("pool", "crypt")), d.mission_id))
			if kind == VCDefs.ENEMY_BRUTE:
				if brutes >= (2 if depth >= 5 else 1):
					kind = VCDefs.ENEMY_HUSK
				brutes += 1
			wave.append({"type": kind, "tile": t})
		waves.append(wave)
	r["encounter"] = {"waves": waves, "lock": true, "manual": false}

static func _tutorial_encounters(d: VCDungeonData, rng: RandomNumberGenerator, reach: PackedByteArray) -> void:
	var r0: Dictionary = d.rooms[0]
	var c0: Vector2i = r0["center"]
	r0["encounter"] = {"waves": [[{"type": VCDefs.ENEMY_HUSK, "tile": c0 + Vector2i(4, -2)}]], "lock": false, "manual": true, "training": true}
	var r2: Dictionary = d.rooms[2]
	var tiles := _spawn_tiles(d, rng, r2, reach, 3)
	var wave: Array = []
	var kinds := [VCDefs.ENEMY_HUSK, VCDefs.ENEMY_SLINGER, VCDefs.ENEMY_SLINGER]
	for i in tiles.size():
		wave.append({"type": kinds[i], "tile": tiles[i]})
	r2["encounter"] = {"waves": [wave], "lock": true, "manual": false}
