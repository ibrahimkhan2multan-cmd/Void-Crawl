class_name VCFx
extends Node3D
## Pooled visual effects: damage numbers, hit bursts, slash arcs, rings and enemy telegraphs.
## Nothing here is freed during play; nodes are recycled so there is no GC/alloc spike mid-fight.

const NUM_POOL := 28
const BURST_POOL := 14
const DECAL_POOL := 40

var world: Node = null
var particle_scale := 1.0
var show_numbers := true

var _numbers: Array = []        # {node, t, life, vel}
var _bursts: Array = []         # CPUParticles3D
var _burst_i := 0
var _decals: Array = []         # {node, t, life, kind, a, b, color, active}
var _sector_cache: Dictionary = {}

func _ready() -> void:
	for i in NUM_POOL:
		var l := Label3D.new()
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.fixed_size = false
		l.pixel_size = 0.012
		l.font_size = 64
		l.outline_size = 14
		l.outline_modulate = Color(0.05, 0.0, 0.1, 0.95)
		l.modulate = Color.WHITE
		l.visible = false
		l.render_priority = 5
		add_child(l)
		_numbers.append({"node": l, "t": 0.0, "life": 0.0, "vel": Vector3.ZERO, "on": false})
	for i in BURST_POOL:
		var p := CPUParticles3D.new()
		p.emitting = false
		p.one_shot = true
		p.explosiveness = 1.0
		p.amount = 14
		p.lifetime = 0.5
		p.direction = Vector3.UP
		p.spread = 180.0
		p.gravity = Vector3(0, -9.0, 0)
		p.initial_velocity_min = 2.0
		p.initial_velocity_max = 5.0
		p.scale_amount_min = 0.5
		p.scale_amount_max = 1.0
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.14, 0.14, 0.14)
		p.mesh = mesh
		p.material_override = VCMats.fx(Color(1, 1, 1, 1), false)
		p.visible = true
		add_child(p)
		_bursts.append(p)
	for i in DECAL_POOL:
		var mi := MeshInstance3D.new()
		mi.visible = false
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_decals.append({"node": mi, "t": 0.0, "life": 0.0, "kind": "", "a": 0.0, "b": 0.0, "color": Color.WHITE, "active": false})

func configure(quality: Dictionary) -> void:
	particle_scale = float(quality.get("particles", 0.65))
	show_numbers = bool(VCSettings.get_value("damage_numbers"))

# ------------------------------------------------------------------ numbers
func number(pos: Vector3, text: String, color: Color = Color.WHITE, big: bool = false) -> void:
	if not show_numbers:
		return
	var slot: Dictionary = {}
	for n in _numbers:
		if not n["on"]:
			slot = n
			break
	if slot.is_empty():
		slot = _numbers[0]
	var l: Label3D = slot["node"]
	l.text = text
	l.modulate = color
	l.font_size = 96 if big else 64
	l.position = pos + Vector3(randf_range(-0.25, 0.25), 1.8, randf_range(-0.2, 0.2))
	l.visible = true
	slot["t"] = 0.0
	slot["life"] = 0.85 if not big else 1.1
	slot["vel"] = Vector3(randf_range(-0.6, 0.6), 2.6, 0)
	slot["on"] = true

# ------------------------------------------------------------------- bursts
func burst(pos: Vector3, color: Color, amount: int = 12, speed: float = 4.0, size: float = 1.0) -> void:
	var p: CPUParticles3D = _bursts[_burst_i]
	_burst_i = (_burst_i + 1) % BURST_POOL
	var n := maxi(2, int(float(amount) * particle_scale))
	p.amount = n
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.scale_amount_min = 0.5 * size
	p.scale_amount_max = 1.0 * size
	p.material_override = VCMats.fx(Color(color.r, color.g, color.b, 0.95), true)
	p.position = pos
	p.restart()
	p.emitting = true

# ------------------------------------------------------------------- decals
func _sector_mesh(arc_deg: float, radius: float) -> ArrayMesh:
	var key := "%d_%d" % [int(arc_deg), int(radius * 10.0)]
	if _sector_cache.has(key):
		return _sector_cache[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 20
	var half := deg_to_rad(arc_deg) * 0.5
	for i in segs:
		var a0 := -half + (2.0 * half) * float(i) / float(segs)
		var a1 := -half + (2.0 * half) * float(i + 1) / float(segs)
		# forward = -Z. y offset keeps it above the floor slabs
		st.add_vertex(Vector3(0, 0, 0))
		st.add_vertex(Vector3(sin(a0) * radius, 0, -cos(a0) * radius))
		st.add_vertex(Vector3(sin(a1) * radius, 0, -cos(a1) * radius))
	var m := st.commit()
	_sector_cache[key] = m
	return m

func _decal_slot() -> Dictionary:
	for d in _decals:
		if not d["active"]:
			return d
	return _decals[0]

## Expanding ring / disc that fades. kind "ring" (flat disc scaling out).
func ring(pos: Vector3, radius: float, color: Color, life: float = 0.35) -> void:
	var d := _decal_slot()
	var mi: MeshInstance3D = d["node"]
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.0
	cyl.bottom_radius = 1.0
	cyl.height = 0.05
	cyl.radial_segments = 24
	cyl.rings = 1
	mi.mesh = cyl
	mi.material_override = VCMats.fx(Color(color.r, color.g, color.b, 0.5), true)
	mi.position = Vector3(pos.x, 0.08, pos.z)
	mi.rotation = Vector3.ZERO
	mi.scale = Vector3(0.1, 1, 0.1)
	mi.visible = true
	d.merge({"t": 0.0, "life": life, "kind": "ring", "a": radius, "b": 0.0, "color": color, "active": true}, true)

## Player/enemy slash wedge. facing is a yaw angle (radians, 0 = -Z).
func slash(pos: Vector3, yaw: float, radius: float, arc_deg: float, color: Color, life: float = 0.16) -> void:
	var d := _decal_slot()
	var mi: MeshInstance3D = d["node"]
	mi.mesh = _sector_mesh(arc_deg, radius)
	mi.material_override = VCMats.fx(Color(color.r, color.g, color.b, 0.55), true)
	mi.position = Vector3(pos.x, 0.9, pos.z)
	mi.rotation = Vector3(0, yaw, 0)
	mi.scale = Vector3.ONE
	mi.visible = true
	d.merge({"t": 0.0, "life": life, "kind": "slash", "a": 0.0, "b": 0.0, "color": color, "active": true}, true)

## Ground warning that fills up over `life`. shape: "circle" or "cone".
## Returns the decal slot id so callers can cancel it (e.g. enemy killed mid wind-up).
func telegraph(pos: Vector3, yaw: float, shape: String, radius: float, arc_deg: float, life: float, color: Color = Color(1.0, 0.2, 0.35)) -> int:
	var d := _decal_slot()
	var mi: MeshInstance3D = d["node"]
	if shape == "circle":
		var cyl := CylinderMesh.new()
		cyl.top_radius = radius
		cyl.bottom_radius = radius
		cyl.height = 0.04
		cyl.radial_segments = 28
		cyl.rings = 1
		mi.mesh = cyl
	else:
		mi.mesh = _sector_mesh(arc_deg, radius)
	mi.material_override = VCMats.fx(Color(color.r, color.g, color.b, 0.22), false)
	mi.position = Vector3(pos.x, 0.07, pos.z)
	mi.rotation = Vector3(0, yaw, 0)
	mi.scale = Vector3.ONE
	mi.visible = true
	d.merge({"t": 0.0, "life": life, "kind": "tele", "a": radius, "b": arc_deg, "color": color, "active": true, "shape": shape}, true)
	return _decals.find(d)

func cancel(slot_id: int) -> void:
	if slot_id >= 0 and slot_id < _decals.size():
		_decals[slot_id]["active"] = false
		(_decals[slot_id]["node"] as Node3D).visible = false

## Pulsing violet pillar used when enemies materialise.
func spawn_pillar(pos: Vector3, life: float = 0.7) -> void:
	var d := _decal_slot()
	var mi: MeshInstance3D = d["node"]
	mi.mesh = VCMats.box(Vector3(1.0, 1.0, 1.0))
	mi.material_override = VCMats.fx(Color(0.6, 0.25, 1.0, 0.55), true)
	mi.position = Vector3(pos.x, 1.2, pos.z)
	mi.rotation = Vector3.ZERO
	mi.scale = Vector3(0.9, 2.4, 0.9)
	mi.visible = true
	d.merge({"t": 0.0, "life": life, "kind": "pillar", "a": 0.0, "b": 0.0, "color": Color(0.6, 0.25, 1.0), "active": true}, true)

func _process(delta: float) -> void:
	for n in _numbers:
		if not n["on"]:
			continue
		n["t"] += delta
		var l: Label3D = n["node"]
		var k: float = n["t"] / n["life"]
		if k >= 1.0:
			n["on"] = false
			l.visible = false
			continue
		l.position += (n["vel"] as Vector3) * delta
		n["vel"] = (n["vel"] as Vector3) * (1.0 - 3.0 * delta)
		var c := l.modulate
		c.a = 1.0 - maxf(0.0, (k - 0.55) / 0.45)
		l.modulate = c
	for d in _decals:
		if not d["active"]:
			continue
		d["t"] += delta
		var mi: MeshInstance3D = d["node"]
		var k: float = d["t"] / d["life"]
		if k >= 1.0:
			d["active"] = false
			mi.visible = false
			continue
		match String(d["kind"]):
			"ring":
				var s: float = lerpf(0.1, float(d["a"]), 1.0 - pow(1.0 - k, 2.0))
				mi.scale = Vector3(s, 1, s)
				var col: Color = d["color"]
				(mi.material_override as StandardMaterial3D).albedo_color = Color(col.r, col.g, col.b, 0.5 * (1.0 - k))
			"slash":
				var col2: Color = d["color"]
				(mi.material_override as StandardMaterial3D).albedo_color = Color(col2.r, col2.g, col2.b, 0.6 * (1.0 - k))
				mi.scale = Vector3.ONE * (0.9 + 0.2 * k)
			"tele":
				var col3: Color = d["color"]
				var pulse := 0.18 + 0.22 * k + 0.08 * sin(k * 30.0)
				(mi.material_override as StandardMaterial3D).albedo_color = Color(col3.r, col3.g, col3.b, pulse)
			"pillar":
				var s2 := 0.9 * (1.0 - k)
				mi.scale = Vector3(maxf(s2, 0.05), 2.4 + 1.5 * k, maxf(s2, 0.05))
				(mi.material_override as StandardMaterial3D).albedo_color = Color(0.6, 0.25, 1.0, 0.55 * (1.0 - k))
