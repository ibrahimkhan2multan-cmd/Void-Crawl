class_name VCDungeonData
extends RefCounted
## Pure-data description of a generated dungeon (no nodes). Everything gameplay needs
## to know about the map lives here so it can be generated, validated and unit-tested
## without a renderer.

const T_ROCK := 0
const T_FLOOR := 1
const T_SECRET := 2   # cracked wall: solid until broken, counts as walkable for reachability
const T_DECOR := 3    # solid decorative obstacle (pillar, sarcophagus, tree, crystal)

var seed: int = 0
var mission_id: String = ""
var w: int = 0
var h: int = 0
var tiles: PackedByteArray = PackedByteArray()
var room_map: PackedInt32Array = PackedInt32Array()

var decor: Dictionary = {}          # Vector2i -> String kind
var rooms: Array = []               # Array[Dictionary]
var chests: Array = []              # {id, tile, tier, room}
var props: Array = []               # breakables {id, kind, tile, room}
var braziers: Array = []            # {tile} standing light sources on floor
var torches: Array = []             # {tile (wall tile), facing (Vector2i toward floor)}
var wall_crystals: Array = []       # same shape as torches
var secrets: Array = []             # {id, tiles:[Vector2i], from_room, to_room}
var checkpoints: Array = []         # {id, room, tile}
var start_tile: Vector2i = Vector2i.ZERO
var exit_tile: Vector2i = Vector2i.ZERO
var boss_room: int = -1
var marker_tile: Vector2i = Vector2i(-1, -1)

var astar: AStarGrid2D

func setup(width: int, height: int) -> void:
	w = width
	h = height
	tiles = PackedByteArray()
	tiles.resize(w * h)
	tiles.fill(T_ROCK)
	room_map = PackedInt32Array()
	room_map.resize(w * h)
	room_map.fill(-1)

func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < w and y < h

func idx(x: int, y: int) -> int:
	return y * w + x

func get_tile(x: int, y: int) -> int:
	if not in_bounds(x, y):
		return T_ROCK
	return tiles[y * w + x]

func set_tile(x: int, y: int, t: int) -> void:
	if in_bounds(x, y):
		tiles[y * w + x] = t

func is_floor(x: int, y: int) -> bool:
	return get_tile(x, y) == T_FLOOR

func is_solid(x: int, y: int) -> bool:
	return get_tile(x, y) != T_FLOOR

func tile_to_world(t: Vector2i) -> Vector3:
	return Vector3((float(t.x) + 0.5) * VCDefs.TILE, 0.0, (float(t.y) + 0.5) * VCDefs.TILE)

func world_to_tile(p: Vector3) -> Vector2i:
	return Vector2i(int(floor(p.x / VCDefs.TILE)), int(floor(p.z / VCDefs.TILE)))

func room_at(t: Vector2i) -> int:
	if not in_bounds(t.x, t.y):
		return -1
	return room_map[idx(t.x, t.y)]

## Build / rebuild the pathfinding grid from the tile map.
func build_nav() -> void:
	astar = AStarGrid2D.new()
	astar.region = Rect2i(0, 0, w, h)
	astar.cell_size = Vector2.ONE
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_EUCLIDEAN
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_EUCLIDEAN
	astar.update()
	for y in h:
		for x in w:
			if tiles[y * w + x] != T_FLOOR:
				astar.set_point_solid(Vector2i(x, y), true)

func set_walkable(t: Vector2i, walkable: bool) -> void:
	if astar != null and in_bounds(t.x, t.y):
		astar.set_point_solid(t, not walkable)

## Break a cracked wall tile.
func open_secret_tile(t: Vector2i) -> void:
	if get_tile(t.x, t.y) == T_SECRET:
		set_tile(t.x, t.y, T_FLOOR)
		set_walkable(t, true)

## Path in world coordinates (tile centres). Empty if unreachable.
func find_path(from_w: Vector3, to_w: Vector3) -> PackedVector3Array:
	var out := PackedVector3Array()
	if astar == null:
		return out
	var a := world_to_tile(from_w)
	var b := world_to_tile(to_w)
	if not in_bounds(a.x, a.y) or not in_bounds(b.x, b.y):
		return out
	if astar.is_point_solid(a):
		a = nearest_floor(a)
	if astar.is_point_solid(b):
		b = nearest_floor(b)
	var ids: Array[Vector2i] = astar.get_id_path(a, b)
	for t in ids:
		out.append(tile_to_world(t))
	return out

func nearest_floor(t: Vector2i, max_r: int = 6) -> Vector2i:
	if is_floor(t.x, t.y):
		return t
	for r in range(1, max_r + 1):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				if is_floor(t.x + dx, t.y + dy):
					return Vector2i(t.x + dx, t.y + dy)
	return t

## Supercover-ish line check used for enemy line-of-sight and direct chasing.
func line_clear(a: Vector2i, b: Vector2i) -> bool:
	var x0 := a.x
	var y0 := a.y
	var x1 := b.x
	var y1 := b.y
	var dx := absi(x1 - x0)
	var dy := absi(y1 - y0)
	var sx := 1 if x0 < x1 else -1
	var sy := 1 if y0 < y1 else -1
	var err := dx - dy
	var guard := 0
	while guard < 400:
		guard += 1
		if not is_floor(x0, y0):
			return false
		if x0 == x1 and y0 == y1:
			return true
		var e2 := 2 * err
		if e2 > -dy:
			err -= dy
			x0 += sx
		if e2 < dx:
			err += dx
			y0 += sy
	return false

func room_floor_tiles(room_id: int) -> Array:
	var out: Array = []
	if room_id < 0 or room_id >= rooms.size():
		return out
	var r: Dictionary = rooms[room_id]
	var c: Vector2i = r["center"]
	var half: int = int(r["size"]) / 2
	for y in range(c.y - half, c.y + half + 1):
		for x in range(c.x - half, c.x + half + 1):
			if is_floor(x, y) and room_map[idx(x, y)] == room_id:
				out.append(Vector2i(x, y))
	return out

## Stable hash of the whole layout: same seed must always give the same digest.
func digest() -> int:
	var hsh := hash(tiles)
	hsh = hsh * 31 + rooms.size()
	for r in rooms:
		hsh = hsh * 31 + hash(str(r["center"]) + str(r["type"]) + str(r["template"]))
	hsh = hsh * 31 + chests.size() * 7 + props.size()
	for t in decor:
		hsh = (hsh * 31 + hash(str(t) + str(decor[t]))) & 0x7fffffffffffffff
	return hsh
