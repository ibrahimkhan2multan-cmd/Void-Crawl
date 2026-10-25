class_name VCInteractable
extends Node3D
## Chest, checkpoint shrine and the Void Gate share one small base so the mission can treat
## them uniformly (prompt text, range, interact()).

signal activated(who)

var world: Node = null
var kind := "chest"          # chest | shrine | gate
var id := ""
var used := false
var prompt := "Open"
var reach := 2.6
var tier := 1
var room := -1
var enabled := true
var _t := 0.0
var _lid: Node3D
var _crystal: MeshInstance3D
var _rings: Array = []
var _light: OmniLight3D

func build_chest(p_tier: int) -> void:
	kind = "chest"
	tier = p_tier
	prompt = "Open"
	var gold := Color(1.0, 0.72, 0.25) if tier < 2 else Color(0.8, 0.45, 1.0)
	VCMats.part(self, Vector3(1.5, 0.8, 1.0), Vector3(0, 0.4, 0), Color(0.34, 0.22, 0.15))
	VCMats.part(self, Vector3(1.56, 0.14, 1.06), Vector3(0, 0.1, 0), Color(0.2, 0.17, 0.24))
	VCMats.part(self, Vector3(0.18, 0.84, 1.06), Vector3(-0.5, 0.42, 0), Color(0.2, 0.17, 0.24))
	VCMats.part(self, Vector3(0.18, 0.84, 1.06), Vector3(0.5, 0.42, 0), Color(0.2, 0.17, 0.24))
	_lid = Node3D.new()
	_lid.position = Vector3(0, 0.8, -0.5)
	add_child(_lid)
	VCMats.part(_lid, Vector3(1.5, 0.42, 1.0), Vector3(0, 0.2, 0.5), Color(0.4, 0.27, 0.18))
	VCMats.part(_lid, Vector3(0.22, 0.46, 1.06), Vector3(0, 0.22, 0.5), gold * 0.8, 0.5)
	VCMats.part(self, Vector3(0.26, 0.26, 0.1), Vector3(0, 0.78, 0.53), gold, 1.4)
	_light = OmniLight3D.new()
	_light.light_color = gold
	_light.light_energy = 0.7
	_light.omni_range = 3.5
	_light.position = Vector3(0, 1.2, 0)
	if VCSettings.safe_mode():
		_light.free()
		_light = null
	else:
		add_child(_light)
	var sb := StaticBody3D.new()
	sb.collision_layer = VCDefs.L_PROP
	sb.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.5, 1.0, 1.0)
	cs.shape = bs
	cs.position = Vector3(0, 0.5, 0)
	sb.add_child(cs)
	add_child(sb)

func build_shrine() -> void:
	kind = "shrine"
	prompt = "Rest"
	reach = 3.0
	VCMats.part(self, Vector3(1.4, 0.35, 1.4), Vector3(0, 0.18, 0), Color(0.3, 0.28, 0.35))
	VCMats.part(self, Vector3(0.9, 0.9, 0.9), Vector3(0, 0.8, 0), Color(0.36, 0.33, 0.42))
	_crystal = MeshInstance3D.new()
	_crystal.mesh = VCMats.box(Vector3(0.5, 0.9, 0.5))
	_crystal.position = Vector3(0, 1.8, 0)
	add_child(_crystal)
	_set_shrine_glow(false)
	_light = OmniLight3D.new()
	_light.light_color = Color(0.5, 0.8, 1.0)
	_light.light_energy = 0.3
	_light.omni_range = 6.0
	_light.position = Vector3(0, 2.0, 0)
	if VCSettings.safe_mode():
		_light.free()
		_light = null
	else:
		add_child(_light)
	var sb := StaticBody3D.new()
	sb.collision_layer = VCDefs.L_PROP
	sb.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.4, 1.6, 1.4)
	cs.shape = bs
	cs.position = Vector3(0, 0.8, 0)
	sb.add_child(cs)
	add_child(sb)

func _set_shrine_glow(on: bool) -> void:
	var c := Color(0.45, 0.85, 1.0) if on else Color(0.25, 0.3, 0.4)
	_crystal.material_override = VCMats.solid(c, 2.0 if on else 0.2)
	if _light != null:
		_light.light_energy = 1.6 if on else 0.3

func build_gate() -> void:
	kind = "gate"
	prompt = "Enter"
	reach = 2.0
	enabled = false
	for i in 3:
		var ring := Node3D.new()
		add_child(ring)
		var r := 1.0 + float(i) * 0.5
		for k in 8:
			var a := TAU * float(k) / 8.0
			var b := VCMats.part(ring, Vector3(0.5, 0.5, 0.5), Vector3(cos(a) * r, 0.0, sin(a) * r), Color(0.55, 0.2, 1.0), 1.6)
			b.rotation.y = -a
		_rings.append(ring)
	VCMats.part(self, Vector3(2.2, 0.08, 2.2), Vector3(0, 0.05, 0), Color(0.12, 0.05, 0.22), 0.3)
	_light = OmniLight3D.new()
	_light.light_color = Color(0.65, 0.3, 1.0)
	_light.light_energy = 0.2
	_light.omni_range = 9.0
	_light.position = Vector3(0, 1.8, 0)
	if VCSettings.safe_mode():
		_light.free()
		_light = null
	else:
		add_child(_light)
	visible = true
	_apply_gate_state()

func set_gate_enabled(on: bool) -> void:
	enabled = on
	_apply_gate_state()

func _apply_gate_state() -> void:
	for ring in _rings:
		(ring as Node3D).visible = enabled
	if _light != null:
		_light.light_energy = 2.4 if enabled else 0.15
		_light.visible = true

## Returns true if the interaction actually did something.
func interact(player: Node) -> bool:
	if not enabled:
		return false
	match kind:
		"chest":
			if used:
				return false
			used = true
			_lid.rotation.x = -1.9
			if _light != null:
				_light.light_energy = 0.25
			activated.emit(self)
			return true
		"shrine":
			activated.emit(self)
			if not used:
				used = true
				_set_shrine_glow(true)
			return true
		"gate":
			activated.emit(self)
			return true
	return false

func can_interact() -> bool:
	if not enabled:
		return false
	if kind == "chest":
		return not used
	return true

func _process(delta: float) -> void:
	_t += delta
	if kind == "gate" and enabled:
		for i in _rings.size():
			var ring: Node3D = _rings[i]
			ring.rotation.y = _t * (0.8 + 0.5 * float(i)) * (1.0 if i % 2 == 0 else -1.0)
			ring.position.y = 0.4 + 0.5 * float(i) + sin(_t * 2.0 + float(i)) * 0.12
	elif kind == "shrine" and _crystal != null:
		_crystal.position.y = 1.8 + sin(_t * 2.0) * 0.1
		_crystal.rotation.y = _t * 0.9
