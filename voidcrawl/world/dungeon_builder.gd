class_name VCDungeonBuilder
extends Node3D
## Turns VCDungeonData into 3D nodes: chunked MultiMesh blocks (few draw calls),
## merged collision, torches/crystals/braziers with distance-culled lights.

const CHUNK := 12

const THEME_COL := {
	"crypt": [Color(0.27, 0.26, 0.31), Color(0.42, 0.40, 0.48)],
	"cavern": [Color(0.20, 0.21, 0.30), Color(0.33, 0.31, 0.46)],
	"ruins": [Color(0.31, 0.30, 0.31), Color(0.47, 0.45, 0.47)],
	"overgrown": [Color(0.16, 0.29, 0.20), Color(0.33, 0.42, 0.35)],
	"void": [Color(0.15, 0.09, 0.24), Color(0.31, 0.18, 0.48)],
	"corridor": [Color(0.24, 0.23, 0.29), Color(0.37, 0.35, 0.44)],
	"ash": [Color(0.30, 0.22, 0.22), Color(0.46, 0.34, 0.32)],
	"forge": [Color(0.27, 0.19, 0.17), Color(0.5, 0.3, 0.22)],
	"magma": [Color(0.24, 0.1, 0.09), Color(0.5, 0.2, 0.14)],
	"ice": [Color(0.24, 0.32, 0.42), Color(0.44, 0.6, 0.74)],
	"glacier": [Color(0.18, 0.29, 0.43), Color(0.33, 0.52, 0.76)],
	"rime": [Color(0.13, 0.18, 0.32), Color(0.3, 0.42, 0.72)],
}

const MOSS := {
	"crypt": 0.5, "cavern": 0.38, "ruins": 0.62, "overgrown": 1.0, "void": 0.0, "corridor": 0.42,
	"ash": 0.0, "forge": 0.0, "magma": 0.0, "ice": 0.55, "glacier": 0.75, "rime": 0.5,
}
const FROST_THEMES := ["ice", "glacier", "rime"]

var data: VCDungeonData
var wall_prop_mat: Material            # wall-mounted dressing (fades like walls)
var floor_prop_mat: Material
var _wprop_chunks: Dictionary = {}
var _fprop_chunks: Dictionary = {}
var wall_mat: Material
var floor_mat: Material
var glow_mat: Material
var world_body: StaticBody3D
var lights: Array = []                 # Array[Dictionary] {node, base, flicker, pos}
var secrets: Dictionary = {}           # id -> {"body": StaticBody3D, "vis": Node3D, "tiles": [...]}
var _floor_chunks: Dictionary = {}
var _wall_chunks: Dictionary = {}
var _glow_chunks: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _quality: Dictionary = {}
var _step: Callable = Callable()

func _yield() -> void:
	if _step.is_valid():
		await _step.call()

func _init() -> void:
	name = "DungeonGeometry"

static func _make_world_material(fade: bool) -> Material:
	if VCSettings.safe_mode():
		var sm := StandardMaterial3D.new()
		sm.vertex_color_use_as_albedo = true
		sm.roughness = 1.0
		sm.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		return sm
	var m := ShaderMaterial.new()
	m.shader = load("res://voidcrawl/assets/shaders/world.gdshader")
	m.set_shader_parameter("tex", VCMats.stone_texture())
	m.set_shader_parameter("fade_enabled", 1.0 if fade else 0.0)
	return m

static func _make_prop_material(fade: bool) -> Material:
	if VCSettings.safe_mode():
		var sm := StandardMaterial3D.new()
		sm.vertex_color_use_as_albedo = true
		sm.roughness = 1.0
		sm.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		return sm
	var m := ShaderMaterial.new()
	m.shader = load("res://voidcrawl/assets/shaders/prop.gdshader")
	m.set_shader_parameter("tex", VCTex.texture("cloth"))
	m.set_shader_parameter("fade_enabled", 1.0 if fade else 0.0)
	return m

## Pass a `step` Callable (it should await a frame) to spread the work over many frames so a
## slow phone never freezes for seconds (Android reports a frozen UI as a crash / ANR).
func build(d: VCDungeonData, quality: Dictionary, step: Callable = Callable()) -> void:
	_step = step
	data = d
	_quality = quality
	_rng.seed = d.seed * 7919 + 13
	wall_mat = _make_world_material(true)
	floor_mat = _make_world_material(false)
	wall_prop_mat = _make_prop_material(true)
	floor_prop_mat = _make_prop_material(false)
	if wall_mat is ShaderMaterial:
		var pal := String(VCMissions.get_mission(d.mission_id).get("palette", ""))
		(wall_mat as ShaderMaterial).set_shader_parameter("frost_mode", 1.0 if pal == "frost" else 0.0)
		(floor_mat as ShaderMaterial).set_shader_parameter("frost_mode", 1.0 if pal == "frost" else 0.0)
	if VCSettings.safe_mode():
		var gm := StandardMaterial3D.new()
		gm.vertex_color_use_as_albedo = true
		gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glow_mat = gm
	else:
		var gs := ShaderMaterial.new()
		gs.shader = load("res://voidcrawl/assets/shaders/glow.gdshader")
		glow_mat = gs
	world_body = StaticBody3D.new()
	world_body.name = "WorldCollision"
	world_body.collision_layer = VCDefs.L_WORLD
	world_body.collision_mask = 0
	add_child(world_body)
	await _build_tiles()
	await _build_collision()
	await _build_decor()
	await _build_flora()
	await _build_lights()
	await _build_runes()
	await _build_secrets()
	await _flush_chunks(_floor_chunks, floor_mat, "Floor")
	await _flush_chunks(_wall_chunks, wall_mat, "Walls")
	await _flush_chunks(_wprop_chunks, wall_prop_mat, "WallProps")
	await _flush_chunks(_fprop_chunks, floor_prop_mat, "FloorProps")
	await _flush_chunks(_glow_chunks, glow_mat, "Glow")

# ------------------------------------------------------------------ batching
func _add(chunks: Dictionary, center: Vector3, size: Vector3, color: Color, rot: Vector3 = Vector3.ZERO) -> void:
	var key := Vector2i(int(floor(center.x / (VCDefs.TILE * CHUNK))), int(floor(center.z / (VCDefs.TILE * CHUNK))))
	if not chunks.has(key):
		chunks[key] = {"xf": [], "col": []}
	var b := Basis.from_euler(rot).scaled(size)
	chunks[key]["xf"].append(Transform3D(b, center))
	chunks[key]["col"].append(color)

func _flush_chunks(chunks: Dictionary, mat: Material, label: String) -> void:
	var unit := BoxMesh.new()
	unit.size = Vector3.ONE
	for key in chunks:
		await _yield()
		var c: Dictionary = chunks[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = unit
		mm.instance_count = c["xf"].size()
		for i in c["xf"].size():
			mm.set_instance_transform(i, c["xf"][i])
			mm.set_instance_color(i, c["col"][i])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "%s_%d_%d" % [label, key.x, key.y]
		mmi.multimesh = mm
		mmi.material_override = mat
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
	chunks.clear()

func _theme_of(x: int, y: int) -> String:
	var rid := data.room_at(Vector2i(x, y))
	if rid < 0:
		return "corridor"
	return String(data.rooms[rid]["theme"])

func _jit(x: int, y: int, amt: float) -> float:
	var h := hash(Vector2i(x * 73856093, y * 19349663) + Vector2i(data.seed, 7))
	return 1.0 + (float(h % 1000) / 1000.0 - 0.5) * 2.0 * amt

func _near_floor(x: int, y: int) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var t := data.get_tile(x + dx, y + dy)
			if t == VCDungeonData.T_FLOOR or t == VCDungeonData.T_DECOR:
				return true
	return false

func _build_tiles() -> void:
	var T := VCDefs.TILE
	for y in data.h:
		if y % 4 == 0:
			await _yield()
		for x in data.w:
			var t := data.get_tile(x, y)
			var wpos := data.tile_to_world(Vector2i(x, y))
			var theme := _theme_of(x, y)
			var cols: Array = THEME_COL[theme]
			if t == VCDungeonData.T_FLOOR or t == VCDungeonData.T_DECOR:
				var f: Color = cols[0] * _jit(x, y, 0.16)
				if (x + y) % 2 == 0:
					f = f * 0.93
				# fake ambient occlusion: tiles hugging a wall are darker
				var rock_n := 0
				for dd in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					if data.get_tile(x + dd.x, y + dd.y) == VCDungeonData.T_ROCK:
						rock_n += 1
				f = f * (1.0 - 0.11 * float(rock_n))
				f.a = 1.0 - float(MOSS.get(theme, 0.0)) * (0.5 if not FROST_THEMES.has(theme) else 0.3)
				_add(_floor_chunks, wpos + Vector3(0, -0.25, 0), Vector3(T, 0.5, T), f)
			elif t == VCDungeonData.T_ROCK:
				if not _near_floor(x, y):
					continue
				var h: float = VCDefs.WALL_H * clampf(_jit(x, y, 0.12), 0.85, 1.15)
				var w: Color = cols[1] * _jit(x + 5, y + 3, 0.14)
				w.a = 1.0 - float(MOSS.get(theme, 0.0))
				_add(_wall_chunks, wpos + Vector3(0, h * 0.5, 0), Vector3(T, h, T), w)
			# T_SECRET is built in _build_secrets()

func _build_collision() -> void:
	var T := VCDefs.TILE
	for y in data.h:
		if y % 6 == 0:
			await _yield()
		var x := 0
		while x < data.w:
			if data.get_tile(x, y) == VCDungeonData.T_ROCK and _near_floor(x, y):
				var x0 := x
				while x < data.w and data.get_tile(x, y) == VCDungeonData.T_ROCK and _near_floor(x, y):
					x += 1
				var run := x - x0
				var cs := CollisionShape3D.new()
				var bs := BoxShape3D.new()
				bs.size = Vector3(run * T, VCDefs.WALL_H, T)
				cs.shape = bs
				cs.position = Vector3((float(x0) + float(run) * 0.5) * T, VCDefs.WALL_H * 0.5, (float(y) + 0.5) * T)
				world_body.add_child(cs)
			else:
				x += 1
	# floor plane so nothing can fall (huge thin box under the dungeon)
	var fc := CollisionShape3D.new()
	var fs := BoxShape3D.new()
	fs.size = Vector3(data.w * T, 1.0, data.h * T)
	fc.shape = fs
	fc.position = Vector3(data.w * T * 0.5, -0.5, data.h * T * 0.5)
	world_body.add_child(fc)

# --------------------------------------------------------------------- decor
func _decor_shape(t: Vector2i, size: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	var p := data.tile_to_world(t)
	cs.position = p + Vector3(0, size.y * 0.5, 0)
	world_body.add_child(cs)

func _build_decor() -> void:
	for t in data.decor:
		var kind: String = data.decor[t]
		var p := data.tile_to_world(t)
		var theme := _theme_of(t.x, t.y)
		var base: Color = THEME_COL[theme][1]
		match kind:
			"pillar":
				var c := base * 1.12
				_add(_wall_chunks, p + Vector3(0, 0.2, 0), Vector3(1.3, 0.4, 1.3), c * 0.9)
				_add(_wall_chunks, p + Vector3(0, 1.45, 0), Vector3(0.95, 2.1, 0.95), c)
				_add(_wall_chunks, p + Vector3(0, 2.6, 0), Vector3(1.3, 0.3, 1.3), c * 0.9)
				_decor_shape(t, Vector3(1.2, 2.8, 1.2))
			"sarcophagus":
				var along_x: bool = (t.x + t.y) % 2 == 0
				var sz := Vector3(1.8, 0.8, 1.2) if along_x else Vector3(1.2, 0.8, 1.8)
				_add(_wall_chunks, p + Vector3(0, 0.4, 0), sz, base * 0.95)
				_add(_wall_chunks, p + Vector3(0, 0.9, 0), sz + Vector3(0.1, 0.2, 0.1), base * 1.15)
				_add(_glow_chunks, p + Vector3(0, 1.03, 0), Vector3(sz.x * 0.4, 0.04, sz.z * 0.4), Color(0.55, 0.25, 1.0))
				_decor_shape(t, sz + Vector3(0, 0.4, 0))
			"tree":
				var trunk := Color(0.24, 0.16, 0.11)
				var leaf := Color(0.09, 0.22, 0.12) * _jit(t.x, t.y, 0.25)
				_add(_wall_chunks, p + Vector3(0, 0.9, 0), Vector3(0.5, 1.8, 0.5), trunk)
				_add(_wall_chunks, p + Vector3(0, 2.1, 0), Vector3(1.8, 0.8, 1.8), leaf)
				_add(_wall_chunks, p + Vector3(0.1, 2.75, 0.05), Vector3(1.2, 0.7, 1.2), leaf * 1.15)
				_decor_shape(t, Vector3(0.9, 2.4, 0.9))
			"crystal":
				var cc := Color(0.55, 0.22, 1.0)
				_add(_glow_chunks, p + Vector3(0, 0.7, 0), Vector3(0.5, 1.4, 0.5), cc, Vector3(0.0, 0.5, 0.12))
				_add(_glow_chunks, p + Vector3(0.45, 0.45, 0.2), Vector3(0.32, 0.9, 0.32), cc * 0.85, Vector3(0.0, 0.2, -0.3))
				_add(_glow_chunks, p + Vector3(-0.4, 0.35, -0.2), Vector3(0.28, 0.7, 0.28), cc * 1.1, Vector3(0.3, 0.9, 0.25))
				_add(_wall_chunks, p + Vector3(0, 0.12, 0), Vector3(1.3, 0.24, 1.3), base * 0.8)
				_decor_shape(t, Vector3(1.1, 1.4, 1.1))


# --------------------------------------------------------------------- flora
func _hf(x: int, y: int, salt: int) -> float:
	var h := hash(Vector2i(x * 73856093 + salt * 4099, y * 19349663 - salt * 7919) + Vector2i(data.seed, salt))
	return float(absi(h) % 10000) / 10000.0

func _pr(c: Color) -> Color:
	c.a = 1.0
	return c

func _reserved_tiles() -> Dictionary:
	var r := {}
	var pts: Array = [data.start_tile, data.exit_tile, data.marker_tile]
	for c in data.chests:
		pts.append(c["tile"])
	for c in data.checkpoints:
		pts.append(c["tile"])
	for c in data.props:
		pts.append(c["tile"])
	for b in data.braziers:
		pts.append(b["tile"])
	for t in data.decor:
		pts.append(t)
	for pt in pts:
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				r[Vector2i(pt.x + dx, pt.y + dy)] = true
	return r

## Box mounted flat on a wall face. `dir` points from the floor tile toward the wall.
func _wbox(fp: Vector3, dir: Vector2i, thick: float, wide: float, tall: float, y: float, lateral: float, col: Color, rot_in_plane: float = 0.0) -> void:
	var dv := Vector3(float(dir.x), 0, float(dir.y))
	var perp := Vector3(float(dir.y), 0, float(dir.x))
	var size := Vector3(thick, tall, wide) if dir.x != 0 else Vector3(wide, tall, thick)
	var pos := fp - dv * (thick * 0.5 + 0.01) + perp * lateral + Vector3(0, y, 0)
	var rot := Vector3(rot_in_plane, 0, 0) if dir.x != 0 else Vector3(0, 0, rot_in_plane)
	_add(_wprop_chunks, pos, size, _pr(col), rot)

func _build_flora() -> void:
	var T := VCDefs.TILE
	var reserved := _reserved_tiles()
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var count := 0
	for y in data.h:
		if y % 5 == 0:
			await _yield()
		for x in data.w:
			if data.get_tile(x, y) != VCDungeonData.T_FLOOR:
				continue
			var t := Vector2i(x, y)
			if reserved.has(t):
				continue
			var theme := _theme_of(x, y)
			var wp := data.tile_to_world(t)
			var base: Color = THEME_COL[theme][1]
			var frosty := FROST_THEMES.has(theme)
			var hot := theme == "forge" or theme == "magma" or theme == "ash"
			var mossy := theme in ["crypt", "cavern", "ruins", "overgrown", "corridor"]
			var walls: Array = []
			for d in dirs:
				if data.get_tile(x + d.x, y + d.y) == VCDungeonData.T_ROCK:
					walls.append(d)
			var narrow := (walls.has(Vector2i(1, 0)) and walls.has(Vector2i(-1, 0))) or (walls.has(Vector2i(0, 1)) and walls.has(Vector2i(0, -1)))
			var wi := 0
			for d in walls:
				wi += 1
				var fp := wp + Vector3(float(d.x), 0, float(d.y)) * (T * 0.5)
				var r1 := _hf(x, y, 10 + wi)
				var r2 := _hf(x, y, 20 + wi)
				var r3 := _hf(x, y, 30 + wi)
				# vines
				var vine_p: float = {"overgrown": 0.5, "crypt": 0.2, "ruins": 0.3, "cavern": 0.14, "corridor": 0.1}.get(theme, 0.0)
				if r1 < vine_p:
					var n := 2 + int(r2 * 3.0)
					for k in n:
						var ln := 0.8 + 1.6 * _hf(x, y, 40 + k + wi)
						var lat := (float(k) - float(n - 1) * 0.5) * 0.38 + (_hf(x, y, 50 + k) - 0.5) * 0.2
						var g := Color(0.1, 0.26, 0.1) * (0.8 + 0.5 * _hf(x, y, 60 + k))
						_wbox(fp, d, 0.07, 0.09, ln, VCDefs.WALL_H - ln * 0.5 - 0.02, lat, g)
						for lf in 2:
							var ly := VCDefs.WALL_H - ln * (0.25 + 0.5 * _hf(x, y, 70 + k * 2 + lf))
							_wbox(fp, d, 0.1, 0.2, 0.14, ly, lat + (_hf(x, y, 80 + k + lf) - 0.5) * 0.16, Color(0.2, 0.45, 0.14) * (0.8 + 0.4 * _hf(x, y, 90 + lf + k)))
						count += 1
				# banners
				var ban_p: float = {"crypt": 0.05, "ruins": 0.07, "forge": 0.06, "corridor": 0.03}.get(theme, 0.0)
				if r2 > 0.5 and r3 < ban_p * 2.0 and r1 >= vine_p:
					var bc := Color(0.38, 0.12, 0.52) if theme == "crypt" or theme == "corridor" else (Color(0.16, 0.26, 0.55) if theme == "ruins" else Color(0.6, 0.13, 0.1))
					_wbox(fp, d, 0.05, 0.72, 1.35, 1.65, 0.0, bc)
					_wbox(fp, d, 0.08, 0.86, 0.09, 2.35, 0.0, Color(0.82, 0.66, 0.25))
					_wbox(fp, d, 0.06, 0.3, 0.3, 1.6, 0.0, Color(0.82, 0.66, 0.25), PI * 0.25)
					_wbox(fp, d, 0.06, 0.18, 0.18, 1.6, 0.0, bc * 1.4, PI * 0.25)
					_wbox(fp, d, 0.05, 0.3, 0.2, 0.9, 0.0, bc, PI * 0.25)
					count += 1
				# icicles
				if frosty and r1 < 0.38:
					var ni := 3 + int(r2 * 3.0)
					for k in ni:
						var lat2 := (float(k) - float(ni - 1) * 0.5) * 0.3
						var il := 0.35 + 0.5 * _hf(x, y, 100 + k + wi)
						var ic := Color(0.8, 0.94, 1.0)
						_wbox(fp, d, 0.14, 0.16, il * 0.5, VCDefs.WALL_H - il * 0.25, lat2, ic)
						_wbox(fp, d, 0.1, 0.1, il * 0.5, VCDefs.WALL_H - il * 0.65, lat2, ic * 0.95)
						_wbox(fp, d, 0.06, 0.06, il * 0.3, VCDefs.WALL_H - il * 0.95, lat2, Color(0.9, 1.0, 1.0))
					count += 1
				# roots
				if theme == "overgrown" and r3 < 0.28:
					_wbox(fp, d, 0.12, 0.12, 2.0, 1.3, 0.3, Color(0.25, 0.17, 0.11), 0.35)
					_wbox(fp, d, 0.1, 0.1, 1.5, 1.5, -0.3, Color(0.22, 0.15, 0.1), -0.45)
				# chains
				if (theme == "crypt" or theme == "forge" or theme == "ruins") and r3 > 0.93:
					_wbox(fp, d, 0.05, 0.05, 1.5, VCDefs.WALL_H - 0.75, 0.0, Color(0.2, 0.2, 0.24))
					for k in 5:
						_wbox(fp, d, 0.09, 0.09, 0.1, VCDefs.WALL_H - 0.2 - 0.28 * float(k), 0.0, Color(0.38, 0.38, 0.44))
				# pipes and vents
				if hot and r2 < 0.12:
					_wbox(fp, d, 0.16, 1.7, 0.16, 2.0, 0.0, Color(0.2, 0.18, 0.2))
					_wbox(fp, d, 0.2, 0.2, 0.2, 2.0, -0.6, Color(0.32, 0.28, 0.3))
					_wbox(fp, d, 0.2, 0.2, 0.2, 2.0, 0.6, Color(0.32, 0.28, 0.3))
					_add(_glow_chunks, fp - Vector3(float(d.x), 0, float(d.y)) * 0.1 + Vector3(0, 1.75, 0), Vector3(0.12, 0.12, 0.12), Color(1.0, 0.45, 0.1))
				# glowing wall cracks (lava)
				if (theme == "magma" or theme == "forge") and r3 < 0.1:
					var gp := fp - Vector3(float(d.x), 0, float(d.y)) * 0.03
					_add(_glow_chunks, gp + Vector3(0, 1.0, 0), Vector3(0.05, 1.2, 0.05) if d.x != 0 else Vector3(0.05, 1.2, 0.05), Color(1.0, 0.4, 0.08), Vector3(0, 0, 0.2))
				# cobwebs in corners
				for d2 in walls:
					if d2 != d and d2.x * d.x + d2.y * d.y == 0 and (mossy or theme == "void") and _hf(x, y, 110 + wi) < 0.45:
						var cp := wp + Vector3(float(d.x + d2.x), 0, float(d.y + d2.y)) * (T * 0.5 - 0.06) + Vector3(0, VCDefs.WALL_H - 0.5, 0)
						var web := Color(0.84, 0.86, 0.9)
						_add(_wprop_chunks, cp, Vector3(0.9, 0.02, 0.02), _pr(web), Vector3(0, PI * 0.25 * (1.0 if d.x * d2.y - d.y * d2.x > 0 else -1.0), 0))
						_add(_wprop_chunks, cp - Vector3(float(d.x), 0.2, float(d.y)) * 0.25, Vector3(0.6, 0.02, 0.02), _pr(web), Vector3(0, 0, 0.5))
						count += 1
						break
				# floor dressing hugging the wall
				var fl := wp + Vector3(float(d.x), 0, float(d.y)) * (T * 0.5 - 0.35)
				if mossy and _hf(x, y, 120 + wi) < 0.28:
					for k in 2 + int(_hf(x, y, 125) * 2.0):
						var off := Vector3(_hf(x, y, 130 + k) - 0.5, 0, _hf(x, y, 140 + k) - 0.5) * 1.2
						_add(_fprop_chunks, fl + off + Vector3(0, 0.05, 0), Vector3(0.5, 0.1, 0.4) * (0.7 + 0.6 * _hf(x, y, 150 + k)), _pr(Color(0.12, 0.3, 0.1) * (0.8 + 0.5 * _hf(x, y, 160 + k))), Vector3(0, _hf(x, y, 170 + k) * TAU, 0))
				if frosty and _hf(x, y, 180 + wi) < 0.3:
					var sn := Color(0.9, 0.96, 1.0)
					_add(_fprop_chunks, fl + Vector3(0, 0.1, 0), Vector3(1.4, 0.2, 0.55), _pr(sn * 0.92))
					_add(_fprop_chunks, fl + Vector3(0.1, 0.22, 0), Vector3(0.9, 0.1, 0.35), _pr(sn))
				if _hf(x, y, 190 + wi) < 0.09 and not narrow and theme in ["crypt", "ruins", "forge", "corridor", "ash", "magma"]:
					# barrel or crate against the wall (solid so the hero cannot walk through it)
					var crate := _hf(x, y, 195 + wi) > 0.5
					var bp := wp + Vector3(float(d.x), 0, float(d.y)) * (T * 0.5 - 0.42)
					if crate:
						_add(_fprop_chunks, bp + Vector3(0, 0.4, 0), Vector3(0.8, 0.8, 0.8), _pr(Color(0.45, 0.3, 0.17)), Vector3(0, 0.15, 0))
						_add(_fprop_chunks, bp + Vector3(0, 0.4, 0), Vector3(0.84, 0.1, 0.84), _pr(Color(0.3, 0.2, 0.12)), Vector3(0, 0.15, 0))
						_add(_fprop_chunks, bp + Vector3(0, 0.82, 0), Vector3(0.72, 0.06, 0.72), _pr(Color(0.52, 0.36, 0.2)), Vector3(0, 0.15, 0))
					else:
						_add(_fprop_chunks, bp + Vector3(0, 0.42, 0), Vector3(0.62, 0.84, 0.62), _pr(Color(0.4, 0.27, 0.15)))
						_add(_fprop_chunks, bp + Vector3(0, 0.22, 0), Vector3(0.68, 0.08, 0.68), _pr(Color(0.2, 0.2, 0.24)))
						_add(_fprop_chunks, bp + Vector3(0, 0.62, 0), Vector3(0.68, 0.08, 0.68), _pr(Color(0.2, 0.2, 0.24)))
					var cs := CollisionShape3D.new()
					var bs := BoxShape3D.new()
					bs.size = Vector3(0.75, 0.9, 0.75)
					cs.shape = bs
					cs.position = bp + Vector3(0, 0.45, 0)
					world_body.add_child(cs)
					count += 1
					break
			# open-floor dressing
			var r := _hf(x, y, 1)
			var q := _hf(x, y, 2)
			var o := wp + Vector3((_hf(x, y, 3) - 0.5) * 1.1, 0, (_hf(x, y, 4) - 0.5) * 1.1)
			if r < 0.07:
				# rubble
				for k in 2 + int(q * 2.0):
					var sz := 0.14 + 0.2 * _hf(x, y, 200 + k)
					_add(_fprop_chunks, o + Vector3((_hf(x, y, 210 + k) - 0.5) * 0.7, sz * 0.4, (_hf(x, y, 220 + k) - 0.5) * 0.7), Vector3(sz, sz * 0.7, sz * 1.2), _pr(base * 0.78), Vector3(_hf(x, y, 230 + k), _hf(x, y, 240 + k) * TAU, 0.2))
			elif r < 0.11 and (theme == "crypt" or theme == "ash" or theme == "cavern" or theme == "forge"):
				# bone pile with a skull
				var bone := Color(0.86, 0.82, 0.72)
				for k in 4:
					_add(_fprop_chunks, o + Vector3((_hf(x, y, 250 + k) - 0.5) * 0.5, 0.05 + 0.04 * float(k % 2), (_hf(x, y, 260 + k) - 0.5) * 0.5), Vector3(0.5, 0.07, 0.07), _pr(bone * (0.85 + 0.2 * _hf(x, y, 270 + k))), Vector3(0, _hf(x, y, 280 + k) * TAU, 0.1))
				if q < 0.5:
					_add(_fprop_chunks, o + Vector3(0, 0.2, 0), Vector3(0.24, 0.22, 0.24), _pr(bone), Vector3(0, q * TAU, 0))
					_add(_fprop_chunks, o + Vector3(0, 0.08, 0), Vector3(0.18, 0.1, 0.2), _pr(bone * 0.85), Vector3(0, q * TAU, 0))
					for sx in [-1.0, 1.0]:
						_add(_fprop_chunks, o + Vector3(sx * 0.06, 0.22, -0.1).rotated(Vector3.UP, q * TAU), Vector3(0.06, 0.07, 0.04), _pr(Color(0.05, 0.04, 0.06)), Vector3(0, q * TAU, 0))
				count += 1
			elif r < 0.14 and (mossy or theme == "void"):
				# damp stain / shallow puddle
				_add(_fprop_chunks, wp + Vector3(0, 0.012, 0), Vector3(0.7 + 0.5 * q, 0.02, 0.6 + 0.5 * _hf(x, y, 5)), _pr(Color(0.1, 0.14, 0.24)), Vector3(0, q * TAU, 0))
			elif r < 0.18 and (theme == "crypt" or theme == "cavern" or theme == "overgrown"):
				# glowing mushrooms
				var mc := Color(0.35, 0.9, 1.0) if q < 0.5 else Color(0.8, 0.4, 1.0)
				for k in 2 + int(q * 3.0):
					var mo := o + Vector3((_hf(x, y, 290 + k) - 0.5) * 0.7, 0, (_hf(x, y, 300 + k) - 0.5) * 0.7)
					var mh := 0.2 + 0.25 * _hf(x, y, 310 + k)
					_add(_fprop_chunks, mo + Vector3(0, mh * 0.5, 0), Vector3(0.07, mh, 0.07), _pr(Color(0.75, 0.72, 0.65)))
					_add(_glow_chunks, mo + Vector3(0, mh + 0.04, 0), Vector3(0.22, 0.1, 0.22), mc * (0.8 + 0.3 * _hf(x, y, 320 + k)))
				count += 1
			elif r < 0.2 and (theme == "overgrown" or theme == "ruins"):
				# grass tufts
				for k in 4:
					_add(_fprop_chunks, o + Vector3((_hf(x, y, 330 + k) - 0.5) * 0.5, 0.17, (_hf(x, y, 340 + k) - 0.5) * 0.5), Vector3(0.05, 0.34, 0.05), _pr(Color(0.16, 0.38, 0.12) * (0.8 + 0.5 * _hf(x, y, 350 + k))), Vector3(_hf(x, y, 360 + k) * 0.5 - 0.25, 0, _hf(x, y, 370 + k) * 0.5 - 0.25))
			elif r < 0.215 and (theme == "crypt" or theme == "ruins" or theme == "corridor"):
				# candle cluster
				for k in 3:
					var co := o + Vector3((_hf(x, y, 380 + k) - 0.5) * 0.4, 0, (_hf(x, y, 390 + k) - 0.5) * 0.4)
					var chh := 0.12 + 0.16 * _hf(x, y, 400 + k)
					_add(_fprop_chunks, co + Vector3(0, chh * 0.5, 0), Vector3(0.06, chh, 0.06), _pr(Color(0.9, 0.86, 0.72)))
					_add(_glow_chunks, co + Vector3(0, chh + 0.05, 0), Vector3(0.05, 0.09, 0.05), Color(1.0, 0.75, 0.3))
				_add(_fprop_chunks, o + Vector3(0, 0.01, 0), Vector3(0.5, 0.02, 0.5), _pr(Color(0.8, 0.76, 0.62)), Vector3(0, q, 0))
			elif r < 0.2 and hot:
				# floor lava cracks and ash
				if q < 0.5:
					_add(_glow_chunks, wp + Vector3(0, 0.03, 0), Vector3(1.3, 0.03, 0.07), Color(1.0, 0.4, 0.08), Vector3(0, _hf(x, y, 6) * TAU, 0))
					_add(_glow_chunks, wp + Vector3(0.3, 0.03, 0.2), Vector3(0.6, 0.03, 0.06), Color(1.0, 0.55, 0.12), Vector3(0, _hf(x, y, 7) * TAU, 0))
				else:
					_add(_fprop_chunks, o + Vector3(0, 0.05, 0), Vector3(0.9, 0.1, 0.8), _pr(Color(0.12, 0.1, 0.1)), Vector3(0, q * TAU, 0))
			elif r < 0.17 and frosty:
				# frost crystals
				var fc := Color(0.5, 0.9, 1.0)
				for k in 2:
					_add(_glow_chunks, o + Vector3((_hf(x, y, 410 + k) - 0.5) * 0.5, 0.25, (_hf(x, y, 420 + k) - 0.5) * 0.5), Vector3(0.12, 0.5 + 0.2 * float(k), 0.12), fc * 0.9, Vector3(0.2, _hf(x, y, 430 + k), 0.15))
			elif r < 0.12 and theme == "void":
				# drifting violet shards
				_add(_glow_chunks, o + Vector3(0, 0.5 + q * 0.6, 0), Vector3(0.14, 0.34, 0.14), Color(0.65, 0.3, 1.0), Vector3(0.4, q * TAU, 0.3))

# -------------------------------------------------------------------- lights
func _add_light(pos: Vector3, color: Color, energy: float, rng_m: float, flicker: float) -> void:
	if VCCrashGuard.level >= 2:
		return          # fallback level 2+: no managed point lights at all
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = rng_m
	l.omni_attenuation = 1.4
	l.shadow_enabled = false
	l.position = pos
	l.visible = false
	add_child(l)
	lights.append({"node": l, "base": energy, "flicker": flicker, "pos": pos})

func _build_lights() -> void:
	var T := VCDefs.TILE
	for tr in data.torches:
		var wt: Vector2i = tr["tile"]
		var f: Vector2i = tr["facing"]
		var p := data.tile_to_world(wt) + Vector3(float(f.x), 0, float(f.y)) * (T * 0.5 - 0.15)
		_add(_wall_chunks, p + Vector3(0, 1.4, 0), Vector3(0.2, 0.8, 0.2), Color(0.25, 0.16, 0.1))
		_add(_glow_chunks, p + Vector3(0, 1.95, 0), Vector3(0.28, 0.36, 0.28), Color(1.0, 0.55, 0.15))
		_add_light(p + Vector3(float(f.x), 2.0, float(f.y)) * 0.6 + Vector3(0, 0, 0), Color(1.0, 0.58, 0.28), 1.5, 8.0, 0.25)
	for wc in data.wall_crystals:
		var wt2: Vector2i = wc["tile"]
		var f2: Vector2i = wc["facing"]
		var p2 := data.tile_to_world(wt2) + Vector3(float(f2.x), 0, float(f2.y)) * (T * 0.5 - 0.1)
		var pal := String(VCMissions.get_mission(data.mission_id).get("palette", ""))
		var ember: bool = pal == "ember"
		var c := Color(1.0, 0.42, 0.1) if ember else (Color(0.4, 0.8, 1.0) if pal == "frost" else Color(0.55, 0.25, 1.0))
		_add(_glow_chunks, p2 + Vector3(0, 1.2, 0), Vector3(0.4, 1.0, 0.4), c, Vector3(0.0, 0.4, 0.3))
		_add(_glow_chunks, p2 + Vector3(0.3, 0.8, 0.0), Vector3(0.28, 0.6, 0.28), c * 0.9, Vector3(0.0, 0.1, -0.35))
		_add_light(p2 + Vector3(float(f2.x), 1.4, float(f2.y)) * 0.6, Color(1.0, 0.45, 0.15) if ember else (Color(0.45, 0.8, 1.0) if pal == "frost" else Color(0.6, 0.32, 1.0)), 1.4, 7.0, 0.1)
	for br in data.braziers:
		var bp := data.tile_to_world(br["tile"])
		_add(_wall_chunks, bp + Vector3(0, 0.35, 0), Vector3(0.5, 0.7, 0.5), Color(0.22, 0.2, 0.25))
		_add(_wall_chunks, bp + Vector3(0, 0.8, 0), Vector3(0.9, 0.22, 0.9), Color(0.3, 0.27, 0.33))
		_add(_glow_chunks, bp + Vector3(0, 1.1, 0), Vector3(0.5, 0.5, 0.5), Color(1.0, 0.5, 0.1))
		_add_light(bp + Vector3(0, 1.8, 0), Color(1.0, 0.55, 0.25), 1.7, 9.0, 0.3)
		_decor_shape(br["tile"], Vector3(0.8, 1.0, 0.8))
	# glowing dungeon-entrance sign pillars near start
	var sp := data.tile_to_world(data.start_tile)
	_add_light(sp + Vector3(0, 2.4, 0), Color(0.7, 0.45, 1.0), 1.1, 9.0, 0.0)

func _build_runes() -> void:
	# violet rune ring on the boss arena floor and on checkpoint shrine floors
	if data.boss_room >= 0:
		var r: Dictionary = data.rooms[data.boss_room]
		var c: Vector2i = r["center"]
		for y in range(c.y - 12, c.y + 13):
			for x in range(c.x - 12, c.x + 13):
				if not data.is_floor(x, y):
					continue
				var dd := Vector2(x - c.x, y - c.y).length()
				if (dd > 8.6 and dd < 9.5) or dd < 1.0 or (absf(dd - 4.5) < 0.5 and (x + y) % 2 == 0):
					_add(_glow_chunks, data.tile_to_world(Vector2i(x, y)) + Vector3(0, 0.02, 0), Vector3(1.5, 0.03, 1.5), Color(0.42, 0.15, 0.8))
	for cp in data.checkpoints:
		var ct: Vector2i = cp["tile"]
		if cp["id"] == "cp_start":
			continue
		for dv in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			_add(_glow_chunks, data.tile_to_world(ct + dv) + Vector3(0, 0.02, 0), Vector3(1.4, 0.03, 1.4), Color(0.35, 0.8, 1.0) * 0.8)

# ------------------------------------------------------------------- secrets
func _build_secrets() -> void:
	var T := VCDefs.TILE
	for s in data.secrets:
		var tiles: Array = s["tiles"]
		var body := StaticBody3D.new()
		body.name = "Secret_" + String(s["id"])
		body.collision_layer = VCDefs.L_WORLD
		body.collision_mask = 0
		var center := Vector3.ZERO
		for t in tiles:
			center += data.tile_to_world(t)
		center /= float(tiles.size())
		var horizontal: bool = (tiles[0] as Vector2i).x == (tiles[1] as Vector2i).x     # tiles stacked along y
		var size := Vector3(T, VCDefs.WALL_H, T * float(tiles.size())) if horizontal else Vector3(T * float(tiles.size()), VCDefs.WALL_H, T)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		cs.position = Vector3(0, VCDefs.WALL_H * 0.5, 0)
		body.add_child(cs)
		body.position = center
		add_child(body)
		var vis := Node3D.new()
		vis.position = center
		add_child(vis)
		var block := MeshInstance3D.new()
		block.mesh = VCMats.box(size * Vector3(0.98, 0.96, 0.98))
		block.material_override = VCMats.solid(Color(0.2, 0.15, 0.27), 0.0, true)
		block.position = Vector3(0, VCDefs.WALL_H * 0.48, 0)
		vis.add_child(block)
		# glowing cracks: thin emissive slabs on both faces of the wall
		var span: float = size.z if horizontal else size.x       # length of the wall along its long axis
		for side in [-1.0, 1.0]:
			for k in 4:
				var crack := MeshInstance3D.new()
				var length := 0.7 + 0.25 * float(k % 2)
				var lateral := (float(k) - 1.5) * (span / 4.5)
				var y := 0.6 + 0.5 * float(k % 3)
				var face := (T * 0.5 + 0.02) * float(side)
				if horizontal:
					crack.mesh = VCMats.box(Vector3(0.04, 0.1, length))
					crack.position = Vector3(face, y, lateral)
				else:
					crack.mesh = VCMats.box(Vector3(length, 0.1, 0.04))
					crack.position = Vector3(lateral, y, face)
				crack.material_override = VCMats.solid(Color(0.7, 0.35, 1.0), 2.0)
				vis.add_child(crack)
		secrets[s["id"]] = {"body": body, "vis": vis, "tiles": tiles, "hp": 3, "center": center}
	# secret tiles also need floor-coloured ground underneath (visible once opened)
	for s in data.secrets:
		for t in s["tiles"]:
			_add(_floor_chunks, data.tile_to_world(t) + Vector3(0, -0.25, 0), Vector3(T, 0.5, T), Color(0.14, 0.12, 0.18))

## Remove a secret wall visually + physically. Returns its world centre.
func open_secret(id: String) -> Vector3:
	if not secrets.has(id):
		return Vector3.ZERO
	var s: Dictionary = secrets[id]
	(s["body"] as Node).queue_free()
	(s["vis"] as Node).queue_free()
	for t in s["tiles"]:
		data.open_secret_tile(t)
	var c: Vector3 = s["center"]
	secrets.erase(id)
	return c

# -------------------------------------------------------------------- update
## Enable only the lights nearest to the hero (keeps GPU cost flat on weak phones).
func update_lights(focus: Vector3, max_lights: int, time: float) -> void:
	var cand: Array = []
	for i in lights.size():
		var d: float = (lights[i]["pos"] as Vector3).distance_squared_to(focus)
		if d < 900.0:
			cand.append([d, i])
	cand.sort_custom(func(a, b): return a[0] < b[0])
	var on := {}
	for k in mini(max_lights, cand.size()):
		on[int(cand[k][1])] = true
	for i in lights.size():
		var l: Dictionary = lights[i]
		var node: OmniLight3D = l["node"]
		var want := on.has(i)
		if node.visible != want:
			node.visible = want
		if want and float(l["flicker"]) > 0.0:
			var n := sin(time * 11.0 + float(i) * 1.7) * 0.5 + sin(time * 5.3 + float(i)) * 0.5
			node.light_energy = float(l["base"]) * (1.0 + n * float(l["flicker"]) * 0.5)
