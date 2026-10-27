class_name VCArmorFx
extends Node3D
## Visible armour-set gear on the hero + its animations. Each equipped set piece adds geometry to
## the rig (horns, crowns, pauldrons, capes, charms); wearing 4 pieces adds an animated aura.
## Purely cosmetic: the stat bonuses live in VCSets / VCItems.totals.

signal tier_changed(set_id: String, count: int)

var player: Node3D = null            # VCPlayer
var rig: Node3D = null
var counts: Dictionary = {}

var _gear: Node3D = null             # child of the rig (turns with the hero)
var _aura: Node3D = null             # child of the player (world-aligned orbit effects)
var _flames: Array = []              # bobbing emissive cubes
var _orbiters: Array = []            # {node, r, h, speed, phase}
var _spinners: Array = []
var _ring: MeshInstance3D = null
var _cape_len := 1.0
var _cape_col := Color(0.12, 0.62, 0.7)
var _t := 0.0
var _pulse_parts: Array = []
var _leg_parts: Array = []           # nodes attached to the legs (freed on refresh)

func setup(p_player: Node3D, p_rig: Node3D) -> void:
	player = p_player
	rig = p_rig
	name = "ArmorFx"

func _b(parent: Node3D, size: Vector3, pos: Vector3, col: Color, em: float = 0.0, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := VCMats.part(parent, size, pos, col, em)
	mi.rotation = rot
	return mi

func _clear() -> void:
	for lp in _leg_parts:
		if is_instance_valid(lp):
			lp.queue_free()
	_leg_parts.clear()
	if _gear != null:
		_gear.queue_free()
	if _aura != null:
		_aura.queue_free()
	_gear = Node3D.new()
	_gear.name = "SetGear"
	rig.add_child(_gear)
	_aura = Node3D.new()
	_aura.name = "SetAura"
	player.add_child(_aura)
	_flames.clear()
	_orbiters.clear()
	_spinners.clear()
	_pulse_parts.clear()
	_ring = null
	_cape_len = 1.0
	_cape_col = Color(0.12, 0.62, 0.7)

## Rebuild from the current equipment. Emits tier_changed when a 2-/4-piece tier is reached or lost.
func refresh(equipment: Dictionary) -> void:
	var new_counts := VCSets.counts(equipment)
	_clear()
	for slot in equipment:
		var it: Dictionary = equipment[slot]
		var sid := VCSets.set_of(it)
		if sid == "" or not VCSets.DEFS.has(sid):
			_build_worn(int(slot), it)
			continue
		match int(slot):
			VCDefs.Slot.HELM: _build_helm(sid)
			VCDefs.Slot.ARMOR: _build_armor(sid)
			VCDefs.Slot.BOOTS: _build_boots(sid)
			VCDefs.Slot.TRINKET: _build_trinket(sid)
	for sid in new_counts:
		if int(new_counts[sid]) >= 4:
			_build_aura(sid)
	# cape style
	var cape: MeshInstance3D = player.get("_cape")
	if cape != null:
		cape.material_override = VCMats.solid(_cape_col, 0.0)
		cape.scale = Vector3(1.0, _cape_len, 1.0)
		cape.position.y = 0.95 - (_cape_len - 1.0) * 0.45
	for sid in new_counts:
		var n: int = new_counts[sid]
		var before: int = int(counts.get(sid, 0))
		if (n >= 2 and before < 2) or (n >= 4 and before < 4):
			tier_changed.emit(sid, n)
	counts = new_counts

func _col(sid: String) -> Color:
	return VCSets.DEFS[sid]["color"]

func _glow(sid: String) -> Color:
	return VCSets.DEFS[sid]["glow"]

# -------------------------------------------------------------- pieces
func _build_helm(sid: String) -> void:
	var c := _col(sid)
	var g := _glow(sid)
	var y := 1.84
	match sid:
		"gloomguard":
			_b(_gear, Vector3(0.56, 0.3, 0.56), Vector3(0, 1.8, 0.02), c)
			_b(_gear, Vector3(0.1, 0.34, 0.5), Vector3(0, 2.08, 0.02), g, 1.2)               # crest/plume
			_b(_gear, Vector3(0.3, 0.08, 0.04), Vector3(0, 1.64, -0.27), g, 2.4)             # visor slit
			_b(_gear, Vector3(0.08, 0.3, 0.3), Vector3(-0.3, 1.62, -0.05), c * 0.85)         # cheek guards
			_b(_gear, Vector3(0.08, 0.3, 0.3), Vector3(0.3, 1.62, -0.05), c * 0.85)
		"voidwalker":
			_b(_gear, Vector3(0.54, 0.16, 0.54), Vector3(0, 1.86, 0.02), c)
			for i in 5:
				var a := TAU * float(i) / 5.0
				var s := _b(_gear, Vector3(0.1, 0.34, 0.1), Vector3(cos(a) * 0.24, 2.1, sin(a) * 0.24), g, 2.0, Vector3(0, a, 0.15))
				_pulse_parts.append(s)
			_b(_gear, Vector3(0.3, 0.08, 0.04), Vector3(0, 1.62, -0.25), g, 3.0)
		"emberlord":
			_b(_gear, Vector3(0.56, 0.26, 0.56), Vector3(0, 1.8, 0.02), c)
			for sx in [-1.0, 1.0]:
				_b(_gear, Vector3(0.12, 0.34, 0.12), Vector3(sx * 0.3, 1.98, 0), Color(0.88, 0.8, 0.66), 0.0, Vector3(0, 0, -sx * 0.45))
				_b(_gear, Vector3(0.1, 0.3, 0.1), Vector3(sx * 0.43, 2.2, 0), Color(0.95, 0.9, 0.78), 0.2, Vector3(0, 0, -sx * 0.85))
			_b(_gear, Vector3(0.4, 0.07, 0.05), Vector3(0, 1.67, -0.27), g, 3.0)
		"frostwarden":
			_b(_gear, Vector3(0.54, 0.16, 0.54), Vector3(0, 1.84, 0.02), c)
			for i in 7:
				var a := TAU * float(i) / 7.0
				var h := 0.26 + 0.12 * float(i % 3)
				_b(_gear, Vector3(0.09, h, 0.09), Vector3(cos(a) * 0.23, 1.95 + h * 0.5, sin(a) * 0.23), Color(0.85, 0.96, 1.0), 0.8, Vector3(sin(a) * 0.2, 0, -cos(a) * 0.2))
			_b(_gear, Vector3(0.3, 0.08, 0.04), Vector3(0, 1.62, -0.25), g, 2.6)
		"friendship":
			_b(_gear, Vector3(0.54, 0.22, 0.54), Vector3(0, 1.82, 0.02), c)
			for sx in [-1.0, 1.0]:
				var w := _b(_gear, Vector3(0.5, 0.1, 0.22), Vector3(sx * 0.42, 1.98, 0.02), Color(0.95, 0.8, 0.4) if sx < 0 else Color(0.45, 0.85, 0.95), 0.5, Vector3(0, 0, sx * 0.5))
				_pulse_parts.append(w)
			_b(_gear, Vector3(0.12, 0.12, 0.08), Vector3(0, 1.95, -0.28), Color(1.0, 0.45, 0.75), 2.6, Vector3(0, 0, PI * 0.25))
		_:
			# mod-made sets get a generic crested helm in their colours
			_b(_gear, Vector3(0.56, 0.26, 0.56), Vector3(0, 1.8, 0.02), c)
			_b(_gear, Vector3(0.12, 0.3, 0.46), Vector3(0, 2.04, 0.02), g, 1.4)
			_b(_gear, Vector3(0.3, 0.08, 0.04), Vector3(0, 1.64, -0.27), g, 2.4)

func _build_armor(sid: String) -> void:
	var c := _col(sid)
	var g := _glow(sid)
	# big pauldrons
	for sx in [-1.0, 1.0]:
		_b(_gear, Vector3(0.42, 0.2, 0.5), Vector3(sx * 0.46, 1.4, 0), c * 1.15)
		_b(_gear, Vector3(0.44, 0.05, 0.52), Vector3(sx * 0.46, 1.5, 0), g, 1.0)
	# chest emblem
	_b(_gear, Vector3(0.22, 0.22, 0.05), Vector3(0, 1.08, -0.2), g, 2.4, Vector3(0, 0, PI * 0.25))
	match sid:
		"gloomguard":
			for sx in [-1.0, 1.0]:
				_b(_gear, Vector3(0.1, 0.3, 0.1), Vector3(sx * 0.5, 1.68, 0), c * 1.3, 0.0, Vector3(0, 0, -sx * 0.25))
			_cape_col = Color(0.22, 0.12, 0.38)
		"voidwalker":
			_cape_col = Color(0.4, 0.1, 0.62)
			_cape_len = 1.45
			for sx in [-1.0, 1.0]:
				var f := _b(_gear, Vector3(0.14, 0.14, 0.14), Vector3(sx * 0.5, 1.7, 0), g, 2.4)
				_flames.append({"node": f, "base": f.position.y, "ph": randf() * TAU})
		"emberlord":
			_cape_col = Color(0.35, 0.08, 0.05)
			for sx in [-1.0, 1.0]:
				for k in 2:
					var f2 := _b(_gear, Vector3(0.12, 0.2, 0.12), Vector3(sx * (0.42 + 0.1 * float(k)), 1.62 + 0.08 * float(k), 0), g, 3.0)
					_flames.append({"node": f2, "base": f2.position.y, "ph": randf() * TAU})
		"frostwarden":
			_cape_col = Color(0.55, 0.78, 0.95)
			for sx in [-1.0, 1.0]:
				_b(_gear, Vector3(0.1, 0.4, 0.1), Vector3(sx * 0.52, 1.74, 0), Color(0.9, 0.98, 1.0), 0.8, Vector3(0, 0, -sx * 0.3))
		"friendship":
			_cape_col = Color(0.95, 0.8, 0.35)
			_cape_len = 1.3
			_b(_gear, Vector3(0.5, 0.06, 0.04), Vector3(0, 1.3, 0.28), Color(0.5, 0.95, 1.0), 1.6)   # cyan trim on the cape

func _build_boots(sid: String) -> void:
	var c := _col(sid)
	var g := _glow(sid)
	for sx in [-1.0, 1.0]:
		var leg: Node3D = player.get("_leg_l") if sx < 0 else player.get("_leg_r")
		if leg == null:
			continue
		var greave := VCMats.part(leg, Vector3(0.3, 0.3, 0.32), Vector3(0, -0.42, 0), c * 1.1)
		var strip := VCMats.part(leg, Vector3(0.32, 0.05, 0.34), Vector3(0, -0.28, 0), g, 1.6)
		greave.name = "SetGreave"
		strip.name = "SetGreave"
		_leg_parts.append(greave)
		_leg_parts.append(strip)
		_gear.set_meta("greaves", true)
		_pulse_parts.append(strip)

func _build_trinket(sid: String) -> void:
	var g := _glow(sid)
	var orb := _b(_aura, Vector3(0.2, 0.2, 0.2), Vector3(0.7, 1.2, 0), g, 2.6, Vector3(0.5, 0.5, 0))
	_orbiters.append({"node": orb, "r": 0.85, "h": 1.15, "speed": 1.8, "phase": 0.0, "bob": 0.12})
	_spinners.append(orb)

func _build_aura(sid: String) -> void:
	var g := _glow(sid)
	# glowing ring on the ground
	_ring = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.05
	cyl.bottom_radius = 1.05
	cyl.height = 0.03
	cyl.radial_segments = 20
	_ring.mesh = cyl
	_ring.material_override = VCMats.fx(Color(g.r, g.g, g.b, 0.28), true)
	_ring.position = Vector3(0, 0.06, 0)
	_aura.add_child(_ring)
	for i in 4:
		var m := _b(_aura, Vector3(0.1, 0.1, 0.1), Vector3.ZERO, g, 3.0)
		_orbiters.append({"node": m, "r": 0.9, "h": 0.3 + 0.55 * float(i), "speed": 2.4 + 0.3 * float(i), "phase": TAU * float(i) / 4.0, "bob": 0.05})
	if sid == "friendship":
		var a := _b(_aura, Vector3(0.22, 0.22, 0.22), Vector3.ZERO, Color(0.4, 0.95, 1.0), 3.2, Vector3(0.6, 0.6, 0))
		var b := _b(_aura, Vector3(0.22, 0.22, 0.22), Vector3.ZERO, Color(1.0, 0.45, 0.8), 3.2, Vector3(0.6, 0.6, 0))
		_orbiters.append({"node": a, "r": 1.15, "h": 1.0, "speed": 1.5, "phase": 0.0, "bob": 0.25})
		_orbiters.append({"node": b, "r": 1.15, "h": 1.0, "speed": 1.5, "phase": PI, "bob": 0.25})
		_spinners.append(a)
		_spinners.append(b)
	elif sid == "voidwalker":
		for i in 3:
			var s := _b(_aura, Vector3(0.14, 0.34, 0.14), Vector3.ZERO, g, 2.6, Vector3(0.3, 0, 0.3))
			_orbiters.append({"node": s, "r": 1.25, "h": 1.5, "speed": -1.1, "phase": TAU * float(i) / 3.0, "bob": 0.2})
			_spinners.append(s)

func has_aura() -> bool:
	for sid in counts:
		if int(counts[sid]) >= 4:
			return true
	return false

## Called every physics frame by the player.
func tick(delta: float, run: float) -> void:
	_t += delta
	for f in _flames:
		var n: MeshInstance3D = f["node"]
		if is_instance_valid(n):
			n.position.y = float(f["base"]) + sin(_t * 7.0 + float(f["ph"])) * 0.07
			n.scale = Vector3.ONE * (0.85 + 0.3 * sin(_t * 11.0 + float(f["ph"])))
	for o in _orbiters:
		var n2: MeshInstance3D = o["node"]
		if is_instance_valid(n2):
			var a: float = _t * float(o["speed"]) + float(o["phase"])
			n2.position = Vector3(cos(a) * float(o["r"]), float(o["h"]) + sin(_t * 3.0 + float(o["phase"])) * float(o["bob"]), sin(a) * float(o["r"]))
	for s in _spinners:
		if is_instance_valid(s):
			(s as Node3D).rotation.y += delta * 3.0
			(s as Node3D).rotation.x += delta * 1.6
	if _ring != null and is_instance_valid(_ring):
		_ring.rotation.y += delta * 0.9
		var k := 1.0 + 0.06 * sin(_t * 3.0)
		_ring.scale = Vector3(k, 1, k)
	var pulse := 1.0 + 0.12 * sin(_t * 5.0)
	for p in _pulse_parts:
		if is_instance_valid(p):
			(p as Node3D).scale = Vector3.ONE * pulse if not (p as Node3D).name.begins_with("Set") else Vector3(1.0, pulse, 1.0)
	# cape sways harder while running
	var cape: MeshInstance3D = player.get("_cape")
	if cape != null and _cape_len > 1.0:
		cape.rotation.x = -0.1 - run * 0.55 + sin(_t * 4.0) * 0.06


# ------------------------------------------------------------- worn (non-set) gear
## Every equipped helm/armour/boots/trinket changes the hero's look. The base item picks a style,
## its colour tints the metal, and rarity adds glow trim and extra ornaments.
func _build_worn(slot: int, it: Dictionary) -> void:
	var base_id := String(it.get("base", ""))
	var c := VCItems.base_color(it)
	var rar := int(it.get("rarity", 0))
	var rc := VCDefs.rarity_color(rar)
	var v := absi(hash(base_id)) % 4
	match slot:
		VCDefs.Slot.HELM: _worn_helm(c, rc, rar, v)
		VCDefs.Slot.ARMOR: _worn_armor(c, rc, rar, v)
		VCDefs.Slot.BOOTS: _worn_boots(c, rc, rar, v)
		VCDefs.Slot.TRINKET: _worn_trinket(c, rc, rar, v)

func _worn_helm(c: Color, rc: Color, rar: int, v: int) -> void:
	_b(_gear, Vector3(0.56, 0.28, 0.56), Vector3(0, 1.84, 0.02), c).material_override = VCMats.solid(c, 0.0, false, "plate")
	_b(_gear, Vector3(0.34, 0.07, 0.04), Vector3(0, 1.68, -0.28), Color(0.05, 0.04, 0.08))            # eye slit
	match v:
		0:   # crested
			_b(_gear, Vector3(0.1, 0.22, 0.5), Vector3(0, 2.07, 0.02), c * 1.1)
		1:   # horned
			for sx in [-1.0, 1.0]:
				_b(_gear, Vector3(0.1, 0.26, 0.1), Vector3(sx * 0.3, 2.0, 0), Color(0.9, 0.86, 0.74), 0.0, Vector3(0, 0, -sx * 0.5))
		2:   # spiked crown
			for i in 5:
				var a := TAU * float(i) / 5.0
				_b(_gear, Vector3(0.07, 0.16, 0.07), Vector3(cos(a) * 0.22, 2.05, sin(a) * 0.22), c * 1.2)
		3:   # visored
			_b(_gear, Vector3(0.5, 0.2, 0.06), Vector3(0, 1.7, -0.29), c * 0.8)
			_b(_gear, Vector3(0.14, 0.14, 0.06), Vector3(0, 1.88, -0.29), rc, 0.8 if rar >= 2 else 0.0)
	if rar >= 2:
		_b(_gear, Vector3(0.58, 0.04, 0.58), Vector3(0, 1.72, 0.02), rc, 1.0 + 0.4 * float(rar - 2))
	if rar >= 4:
		for sx in [-1.0, 1.0]:
			var w := _b(_gear, Vector3(0.36, 0.08, 0.2), Vector3(sx * 0.42, 1.96, 0.02), rc, 1.6, Vector3(0, 0, sx * 0.5))
			_pulse_parts.append(w)

func _worn_armor(c: Color, rc: Color, rar: int, v: int) -> void:
	_b(_gear, Vector3(0.68, 0.5, 0.4), Vector3(0, 1.08, 0), c).material_override = VCMats.solid(c, 0.0, false, "plate")
	_b(_gear, Vector3(0.22, 0.22, 0.05), Vector3(0, 1.12, -0.22), rc, 0.6 + 0.4 * float(rar), Vector3(0, 0, PI * 0.25))   # chest emblem
	if rar >= 1:
		for sx in [-1.0, 1.0]:
			_b(_gear, Vector3(0.4, 0.18, 0.44), Vector3(sx * 0.46, 1.42, 0), c * 1.1)          # pauldrons
	match v:
		0:   # tassets
			for sx in [-1.0, 1.0]:
				_b(_gear, Vector3(0.24, 0.3, 0.06), Vector3(sx * 0.17, 0.52, -0.2), c * 0.9)
		1:   # shoulder spikes
			for sx in [-1.0, 1.0]:
				_b(_gear, Vector3(0.08, 0.26, 0.08), Vector3(sx * 0.5, 1.64, 0), Color(0.85, 0.85, 0.9), 0.0, Vector3(0, 0, -sx * 0.3))
		2:   # fur collar
			_b(_gear, Vector3(0.78, 0.14, 0.5), Vector3(0, 1.4, 0), Color(0.82, 0.78, 0.7), 0.0, Vector3.ZERO).material_override = VCMats.solid(Color(0.82, 0.78, 0.7), 0.0, false, "fur")
		3:   # tabard + sash
			_b(_gear, Vector3(0.7, 0.08, 0.44), Vector3(0, 1.3, 0), rc, 0.5, Vector3(0, 0, 0.3))
	if rar >= 3:
		_b(_gear, Vector3(0.72, 0.04, 0.44), Vector3(0, 0.84, 0), rc, 1.4)                      # glowing waist trim
		for sx in [-1.0, 1.0]:
			_pulse_parts.append(_b(_gear, Vector3(0.44, 0.04, 0.48), Vector3(sx * 0.46, 1.52, 0), rc, 1.4))

func _worn_boots(c: Color, rc: Color, rar: int, v: int) -> void:
	for sx in [-1.0, 1.0]:
		var leg: Node3D = player.get("_leg_l") if sx < 0 else player.get("_leg_r")
		if leg == null:
			continue
		var sh := VCMats.part(leg, Vector3(0.3, 0.3, 0.3), Vector3(0, -0.38, 0), c * 1.05, 0.0, "", "plate")
		_leg_parts.append(sh)
		var toe := VCMats.part(leg, Vector3(0.3, 0.1, 0.14), Vector3(0, -0.6, -0.26), c * 0.85, 0.0, "", "plate")
		_leg_parts.append(toe)
		if v == 0 or v == 3:   # winged / spiked
			var w := VCMats.part(leg, Vector3(0.04, 0.2, 0.3), Vector3(sx * 0.17, -0.45, 0.1), Color(0.95, 0.95, 1.0), 0.6 if v == 3 else 0.0)
			w.rotation.z = sx * 0.4
			_leg_parts.append(w)
		else:
			_leg_parts.append(VCMats.part(leg, Vector3(0.32, 0.06, 0.32), Vector3(0, -0.24, 0), rc, 0.8 if rar >= 2 else 0.0))
		if rar >= 3:
			_leg_parts.append(VCMats.part(leg, Vector3(0.32, 0.04, 0.32), Vector3(0, -0.52, 0), rc, 1.6))

func _worn_trinket(c: Color, rc: Color, rar: int, v: int) -> void:
	# a pendant on the chest and, for better rarities, a charm that floats beside the hero
	_b(_gear, Vector3(0.08, 0.3, 0.04), Vector3(0, 1.28, -0.2), Color(0.8, 0.75, 0.4))
	var gem := _b(_gear, Vector3(0.16, 0.16, 0.06), Vector3(0, 1.1, -0.22), c.lerp(rc, 0.4), 1.2 + 0.4 * float(rar), Vector3(0, 0, PI * 0.25))
	_pulse_parts.append(gem)
	if rar >= 2:
		var orb := _b(_aura, Vector3(0.14, 0.14, 0.14), Vector3(0.6, 1.2, 0), rc, 2.0, Vector3(0.5, 0.5, 0))
		_orbiters.append({"node": orb, "r": 0.75, "h": 1.0 + 0.1 * float(v), "speed": 1.4 + 0.2 * float(v), "phase": float(v), "bob": 0.1})
		_spinners.append(orb)
