class_name VCPet
extends CharacterBody3D
## A companion. Follows the hero, picks fights with nearby enemies, takes damage from them, comes back
## RESPAWN_TIME seconds after falling and eats potions from the hero's belt to heal (if allowed).
## Stats and look come from VCPets.SPECIES; the level comes from the profile.

signal fell(pet)

const RESPAWN_TIME := 10.0
const AGGRO := 9.5
const LEASH := 12.0
const FEED_BELOW := 0.45

var world: Node = null
var species_id := ""
var level := 1
var def: Dictionary = {}
var hp := 1.0
var max_hp := 1.0
var dmg := 1.0
var slot_index := 0
var dead := false
var respawn_t := 0.0
var hit_radius := 0.45
var display_name := ""

var _t := 0.0
var _cd := 0.6
var _target: VCEnemy = null
var _retarget := 0.0
var _feed_cd := 0.0
var _invuln := 0.0
var _flash := 0.0
var _bite := 0.0
var _stuck := 0.0
var _last_pos := Vector3.ZERO
var _facing := 0.0
var _path := PackedVector3Array()
var _path_i := 0
var _repath := 0.0
var _hp_show := 0.0
var rig: Node3D
var _parts: Array = []
var _leg_a: Node3D
var _leg_b: Node3D
var _wings: Array = []
var _squash: Node3D
var _spin: Array = []
var _hover := 0.0
var _bar_bg: MeshInstance3D
var _bar_fg: MeshInstance3D

func setup(id: String, lvl: int, owner_level: int, slot: int) -> void:
	species_id = id
	def = VCPets.SPECIES[id]
	level = lvl
	slot_index = slot
	display_name = String(def["name"])
	max_hp = VCPets.max_hp(id, lvl, owner_level)
	hp = max_hp
	dmg = VCPets.damage(id, lvl, owner_level)
	hit_radius = 0.45 * float(def.get("scale", 1.0))
	_hover = float(def.get("float", 0.0))

func _ready() -> void:
	collision_layer = 0
	collision_mask = VCDefs.L_WORLD | VCDefs.L_PROP
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = hit_radius * 0.8
	sh.height = 1.0
	cs.shape = sh
	cs.position = Vector3(0, 0.5, 0)
	add_child(cs)
	rig = Node3D.new()
	rig.name = "Rig"
	add_child(rig)
	_build_rig()
	rig.scale = Vector3.ONE * float(def.get("scale", 1.0))
	if _hover <= 0.0:
		VCMats.add_blob(self, 1.1 * float(def.get("scale", 1.0)))
	_build_bar()
	name = "Pet_%s" % species_id
	_last_pos = global_position

func _p(parent: Node3D, size: Vector3, pos: Vector3, col: Color, em: float = 0.0, style: String = "") -> MeshInstance3D:
	var mi := VCMats.part(parent, size, pos, col, em, "", style)
	_parts.append(mi)
	return mi

func _limb(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n

func _build_bar() -> void:
	var qm := QuadMesh.new()
	qm.size = Vector2(1.0, 0.12)
	var top := (1.7 if String(def["style"]) in ["golem", "drake", "hydra", "imp"] else 1.35) * float(def.get("scale", 1.0)) + _hover
	_bar_bg = MeshInstance3D.new()
	_bar_bg.mesh = qm
	_bar_bg.material_override = _bar_mat(Color(0.05, 0.02, 0.08, 0.85))
	_bar_bg.position = Vector3(0, top, 0)
	add_child(_bar_bg)
	var qf := QuadMesh.new()
	qf.size = Vector2(1.0, 0.12)
	_bar_fg = MeshInstance3D.new()
	_bar_fg.mesh = qf
	_bar_fg.material_override = _bar_mat(Color(0.35, 1.0, 0.55, 1.0))
	_bar_fg.position = Vector3(0, top, 0)
	add_child(_bar_fg)
	_bar_bg.visible = false
	_bar_fg.visible = false

func _bar_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_color = c
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.no_depth_test = true
	m.render_priority = 5 if c.a > 0.95 else 4
	return m

# ------------------------------------------------------------------ rig
func _build_rig() -> void:
	var col: Color = def["col"]
	var c2: Color = def["col2"]
	var glow: Color = def["glow"]
	match String(def["style"]):
		"quad":
			_p(rig, Vector3(0.5, 0.4, 0.9), Vector3(0, 0.5, 0), col)
			_p(rig, Vector3(0.4, 0.36, 0.4), Vector3(0, 0.7, -0.55), col * 1.08)
			_p(rig, Vector3(0.2, 0.16, 0.22), Vector3(0, 0.62, -0.8), c2)
			_p(rig, Vector3(0.1, 0.18, 0.08), Vector3(-0.13, 0.98, -0.5), c2)
			_p(rig, Vector3(0.1, 0.18, 0.08), Vector3(0.13, 0.98, -0.5), c2)
			_p(rig, Vector3(0.07, 0.07, 0.04), Vector3(-0.1, 0.74, -0.76), glow, 3.0)
			_p(rig, Vector3(0.07, 0.07, 0.04), Vector3(0.1, 0.74, -0.76), glow, 3.0)
			_p(rig, Vector3(0.07, 0.06, 0.04), Vector3(0, 0.66, -0.92), Color(0.05, 0.04, 0.07))
			_p(rig, Vector3(0.1, 0.1, 0.45), Vector3(0, 0.66, 0.6), c2).rotation.x = -0.5
			_p(rig, Vector3(0.12, 0.05, 0.5), Vector3(0, 0.72, 0.05), glow, 1.2)
			_leg_a = _limb(rig, Vector3(0, 0.36, 0))
			_leg_b = _limb(rig, Vector3(0, 0.36, 0))
			_p(_leg_a, Vector3(0.14, 0.36, 0.15), Vector3(-0.17, -0.18, -0.28), col * 0.8)
			_p(_leg_a, Vector3(0.14, 0.36, 0.15), Vector3(0.17, -0.18, 0.3), col * 0.8)
			_p(_leg_b, Vector3(0.14, 0.36, 0.15), Vector3(0.17, -0.18, -0.28), col * 0.8)
			_p(_leg_b, Vector3(0.14, 0.36, 0.15), Vector3(-0.17, -0.18, 0.3), col * 0.8)
		"bird":
			_p(rig, Vector3(0.4, 0.36, 0.5), Vector3(0, 0, 0), col)
			_p(rig, Vector3(0.28, 0.26, 0.28), Vector3(0, 0.2, -0.34), col * 1.1)
			_p(rig, Vector3(0.1, 0.08, 0.16), Vector3(0, 0.14, -0.54), c2)
			_p(rig, Vector3(0.06, 0.06, 0.04), Vector3(-0.08, 0.25, -0.49), glow, 3.0)
			_p(rig, Vector3(0.06, 0.06, 0.04), Vector3(0.08, 0.25, -0.49), glow, 3.0)
			_p(rig, Vector3(0.1, 0.1, 0.08), Vector3(0, 0.4, -0.3), c2)
			_p(rig, Vector3(0.22, 0.05, 0.4), Vector3(0, -0.04, 0.42), c2)
			_p(rig, Vector3(0.14, 0.04, 0.3), Vector3(0, -0.04, 0.72), glow, 1.0)
			for sx in [-1.0, 1.0]:
				var wing := _limb(rig, Vector3(sx * 0.2, 0.08, 0.0))
				_p(wing, Vector3(0.55, 0.04, 0.42), Vector3(sx * 0.28, 0, 0), c2)
				_p(wing, Vector3(0.42, 0.04, 0.3), Vector3(sx * 0.72, 0, 0.06), col * 0.9)
				_p(wing, Vector3(0.5, 0.045, 0.05), Vector3(sx * 0.3, 0.01, -0.2), glow, 1.0)
				_wings.append({"n": wing, "s": sx})
		"blob":
			_squash = _limb(rig, Vector3.ZERO)
			_p(_squash, Vector3(0.9, 0.58, 0.9), Vector3(0, 0.31, 0), col)
			_p(_squash, Vector3(0.58, 0.28, 0.58), Vector3(0, 0.72, 0), c2)
			_p(_squash, Vector3(0.15, 0.18, 0.05), Vector3(-0.17, 0.52, -0.47), Color(1, 1, 1), 2.0)
			_p(_squash, Vector3(0.15, 0.18, 0.05), Vector3(0.17, 0.52, -0.47), Color(1, 1, 1), 2.0)
			_p(_squash, Vector3(0.07, 0.09, 0.05), Vector3(-0.17, 0.51, -0.5), Color(0.05, 0.1, 0.06), 0.0)
			_p(_squash, Vector3(0.07, 0.09, 0.05), Vector3(0.17, 0.51, -0.5), Color(0.05, 0.1, 0.06), 0.0)
			_p(_squash, Vector3(0.12, 0.12, 0.12), Vector3(0.18, 0.22, 0.2), glow, 1.4)
			_p(_squash, Vector3(1.05, 0.06, 1.05), Vector3(0, 0.03, 0), col * 0.7)
		"imp":
			_leg_a = _limb(rig, Vector3(-0.12, 0.45, 0))
			_leg_b = _limb(rig, Vector3(0.12, 0.45, 0))
			_p(_leg_a, Vector3(0.14, 0.45, 0.16), Vector3(0, -0.22, 0), col * 0.8)
			_p(_leg_b, Vector3(0.14, 0.45, 0.16), Vector3(0, -0.22, 0), col * 0.8)
			_p(rig, Vector3(0.42, 0.5, 0.28), Vector3(0, 0.7, 0), col)
			_p(rig, Vector3(0.38, 0.34, 0.34), Vector3(0, 1.14, 0), col * 1.1)
			_p(rig, Vector3(0.08, 0.22, 0.08), Vector3(-0.14, 1.4, 0), c2).rotation.z = 0.3
			_p(rig, Vector3(0.08, 0.22, 0.08), Vector3(0.14, 1.4, 0), c2).rotation.z = -0.3
			_p(rig, Vector3(0.08, 0.07, 0.04), Vector3(-0.09, 1.16, -0.18), glow, 3.0)
			_p(rig, Vector3(0.08, 0.07, 0.04), Vector3(0.09, 1.16, -0.18), glow, 3.0)
			_p(rig, Vector3(0.22, 0.06, 0.04), Vector3(0, 1.04, -0.18), Color(0.1, 0.03, 0.03))
			_p(rig, Vector3(0.07, 0.07, 0.5), Vector3(0, 0.5, 0.4), c2).rotation.x = -0.4
			_p(rig, Vector3(0.14, 0.14, 0.14), Vector3(0, 0.62, 0.66), glow, 2.0)
			for sx in [-1.0, 1.0]:
				var wing := _limb(rig, Vector3(sx * 0.2, 0.85, 0.15))
				_p(wing, Vector3(0.4, 0.04, 0.3), Vector3(sx * 0.22, 0, 0.1), c2)
				_wings.append({"n": wing, "s": sx})
		"golem":
			_leg_a = _limb(rig, Vector3(-0.2, 0.5, 0))
			_leg_b = _limb(rig, Vector3(0.2, 0.5, 0))
			_p(_leg_a, Vector3(0.24, 0.5, 0.26), Vector3(0, -0.25, 0), col * 0.75, 0.0, "stone")
			_p(_leg_b, Vector3(0.24, 0.5, 0.26), Vector3(0, -0.25, 0), col * 0.75, 0.0, "stone")
			_p(rig, Vector3(0.74, 0.62, 0.48), Vector3(0, 0.82, 0), col, 0.0, "stone")
			_p(rig, Vector3(0.36, 0.32, 0.34), Vector3(0, 1.3, 0), col * 1.1, 0.0, "stone")
			_p(rig, Vector3(0.1, 0.08, 0.04), Vector3(-0.09, 1.32, -0.18), glow, 3.0)
			_p(rig, Vector3(0.1, 0.08, 0.04), Vector3(0.09, 1.32, -0.18), glow, 3.0)
			_p(rig, Vector3(0.3, 0.22, 0.04), Vector3(0, 0.88, -0.26), glow, 1.6)
			_p(rig, Vector3(0.5, 0.12, 0.4), Vector3(-0.2, 1.2, 0.02), c2, 0.0, "fur")
			_p(rig, Vector3(0.3, 0.12, 0.3), Vector3(0.3, 1.18, 0.1), c2, 0.0, "fur")
			_leg_a.set_meta("arm", false)
			for sx in [-1.0, 1.0]:
				_p(rig, Vector3(0.22, 0.56, 0.24), Vector3(sx * 0.5, 0.74, 0), col * 0.9, 0.0, "stone")
		"orb":
			var core := _p(rig, Vector3(0.5, 0.5, 0.5), Vector3.ZERO, col, 1.8)
			core.rotation = Vector3(0.7, 0.7, 0)
			_spin.append(core)
			for i in 3:
				_spin.append(_p(rig, Vector3(0.14, 0.34, 0.14), Vector3.ZERO, c2, 2.0))
			_p(rig, Vector3(0.1, 0.08, 0.04), Vector3(-0.1, 0.04, -0.3), Color(1, 1, 1), 3.0)
			_p(rig, Vector3(0.1, 0.08, 0.04), Vector3(0.1, 0.04, -0.3), Color(1, 1, 1), 3.0)
		"drake":
			_p(rig, Vector3(0.5, 0.4, 0.9), Vector3(0, 0.55, 0), col)
			_p(rig, Vector3(0.4, 0.12, 0.8), Vector3(0, 0.36, 0), c2)
			_p(rig, Vector3(0.2, 0.36, 0.2), Vector3(0, 0.88, -0.45), col * 1.05).rotation.x = 0.25
			_p(rig, Vector3(0.3, 0.26, 0.4), Vector3(0, 1.06, -0.66), col * 1.1)
			_p(rig, Vector3(0.08, 0.2, 0.08), Vector3(-0.1, 1.28, -0.54), c2).rotation.x = -0.4
			_p(rig, Vector3(0.08, 0.2, 0.08), Vector3(0.1, 1.28, -0.54), c2).rotation.x = -0.4
			_p(rig, Vector3(0.07, 0.07, 0.04), Vector3(-0.1, 1.1, -0.87), glow, 3.0)
			_p(rig, Vector3(0.07, 0.07, 0.04), Vector3(0.1, 1.1, -0.87), glow, 3.0)
			_p(rig, Vector3(0.16, 0.14, 0.7), Vector3(0, 0.5, 0.8), col).rotation.x = -0.15
			_p(rig, Vector3(0.12, 0.12, 0.2), Vector3(0, 0.46, 1.2), glow, 1.6)
			for i in 4:
				_p(rig, Vector3(0.08, 0.1, 0.1), Vector3(0, 0.82, -0.3 + 0.22 * float(i)), glow, 1.2)
			for sx in [-1.0, 1.0]:
				var wing := _limb(rig, Vector3(sx * 0.24, 0.75, 0.0))
				_p(wing, Vector3(0.7, 0.05, 0.5), Vector3(sx * 0.36, 0, 0.1), c2)
				_p(wing, Vector3(0.5, 0.05, 0.3), Vector3(sx * 0.9, 0, 0.18), col * 0.9)
				_wings.append({"n": wing, "s": sx})
			_leg_a = _limb(rig, Vector3(0, 0.36, 0))
			_leg_b = _limb(rig, Vector3(0, 0.36, 0))
			_p(_leg_a, Vector3(0.14, 0.36, 0.16), Vector3(-0.17, -0.18, -0.28), col * 0.8)
			_p(_leg_a, Vector3(0.14, 0.36, 0.16), Vector3(0.17, -0.18, 0.3), col * 0.8)
			_p(_leg_b, Vector3(0.14, 0.36, 0.16), Vector3(0.17, -0.18, -0.28), col * 0.8)
			_p(_leg_b, Vector3(0.14, 0.36, 0.16), Vector3(-0.17, -0.18, 0.3), col * 0.8)
		"hydra":
			_p(rig, Vector3(0.7, 0.5, 1.0), Vector3(0, 0.6, 0), col)
			_p(rig, Vector3(0.6, 0.1, 0.9), Vector3(0, 0.34, 0), c2)
			for i in 3:
				var hx := (float(i) - 1.0) * 0.26
				_p(rig, Vector3(0.14, 0.6, 0.14), Vector3(hx, 1.05, -0.4), col * 1.1).rotation.z = -hx * 0.9
				_p(rig, Vector3(0.28, 0.24, 0.34), Vector3(hx * 1.7, 1.4, -0.52), col * 1.15)
				_p(rig, Vector3(0.07, 0.07, 0.04), Vector3(hx * 1.7 - 0.07, 1.43, -0.71), glow, 3.0)
				_p(rig, Vector3(0.07, 0.07, 0.04), Vector3(hx * 1.7 + 0.07, 1.43, -0.71), glow, 3.0)
			_p(rig, Vector3(0.2, 0.18, 0.7), Vector3(0, 0.56, 0.85), col).rotation.x = -0.2
			_p(rig, Vector3(0.14, 0.16, 0.2), Vector3(0, 0.6, 1.25), glow, 1.6)
			_leg_a = _limb(rig, Vector3(0, 0.4, 0))
			_leg_b = _limb(rig, Vector3(0, 0.4, 0))
			_p(_leg_a, Vector3(0.18, 0.4, 0.2), Vector3(-0.28, -0.2, -0.3), col * 0.8)
			_p(_leg_a, Vector3(0.18, 0.4, 0.2), Vector3(0.28, -0.2, 0.34), col * 0.8)
			_p(_leg_b, Vector3(0.18, 0.4, 0.2), Vector3(0.28, -0.2, -0.3), col * 0.8)
			_p(_leg_b, Vector3(0.18, 0.4, 0.2), Vector3(-0.28, -0.2, 0.34), col * 0.8)
	rig.visible = true

# ----------------------------------------------------------------- tick
func is_alive() -> bool:
	return not dead

func _physics_process(delta: float) -> void:
	if world == null or world.player == null:
		return
	_t += delta
	_invuln = maxf(0.0, _invuln - delta)
	_feed_cd = maxf(0.0, _feed_cd - delta)
	_hp_show = maxf(0.0, _hp_show - delta)
	if dead:
		respawn_t -= delta
		if respawn_t <= 0.0:
			_respawn()
		return
	_cd = maxf(0.0, _cd - delta)
	_bite = maxf(0.0, _bite - delta)
	if _flash > 0.0:
		_flash -= delta
		if _flash <= 0.0:
			_set_flash(false)
	_retarget -= delta
	if _retarget <= 0.0 or _target == null or not is_instance_valid(_target) or not _target.is_alive():
		_retarget = 0.3
		_target = _pick_target()
	var moved := false
	var want := Vector3.ZERO
	if _target != null:
		moved = _fight(delta)
	else:
		moved = _follow(delta)
	_tick_feed()
	if global_position.distance_to(world.player.global_position) > 18.0:
		_teleport_to_player()
	if moved:
		if global_position.distance_to(_last_pos) < 0.04 * delta * 60.0 * 0.25:
			_stuck += delta
			if _stuck > 2.2:
				_stuck = 0.0
				_teleport_to_player()
		else:
			_stuck = 0.0
	else:
		_stuck = 0.0
	_last_pos = global_position
	move_and_slide()
	global_position.y = 0.0
	_animate(delta)
	_update_bar()

func _pick_target() -> VCEnemy:
	var best: VCEnemy = null
	var best_s := 1e9
	var ppos: Vector3 = world.player.global_position
	for e in world.enemies:
		if not is_instance_valid(e) or not e.is_alive():
			continue
		var dp := Vector2(e.global_position.x - global_position.x, e.global_position.z - global_position.z).length()
		var dpl := Vector2(e.global_position.x - ppos.x, e.global_position.z - ppos.z).length()
		if dp > AGGRO or dpl > LEASH:
			continue
		var sc := dp + dpl * 0.6
		if sc < best_s:
			best_s = sc
			best = e
	return best

func _follow(delta: float) -> bool:
	var ppos: Vector3 = world.player.global_position
	var ang := PI * 0.8 + float(slot_index) * 1.9 + sin(_t * 0.6 + float(slot_index)) * 0.2
	var desired := ppos + Vector3(cos(ang), 0, sin(ang)) * (2.4 + 0.5 * float(slot_index))
	var to := desired - global_position
	to.y = 0.0
	var d := to.length()
	if d < 0.7:
		velocity = velocity.move_toward(Vector3.ZERO, 18.0 * delta)
		return false
	var sp := float(def["speed"]) * (1.0 + clampf((d - 3.5) / 6.0, 0.0, 1.0) * 0.9)
	_steer(desired, sp, delta)
	return true

func _fight(delta: float) -> bool:
	var tpos: Vector3 = _target.global_position
	var to := tpos - global_position
	to.y = 0.0
	var d := to.length()
	var reach := float(def["reach"]) + _target.hit_radius
	var ranged := String(def["ai"]) == "ranged"
	if to.length() > 0.05:
		_facing = lerp_angle(_facing, atan2(-to.x, -to.z), clampf(12.0 * delta, 0.0, 1.0))
	if ranged:
		var los: bool = world.data.line_clear(world.data.world_to_tile(global_position), world.data.world_to_tile(tpos))
		if d > reach or not los:
			_steer(tpos, float(def["speed"]), delta)
			return true
		if d < reach * 0.38:
			velocity = velocity.move_toward(-to.normalized() * float(def["speed"]), 30.0 * delta)
		else:
			velocity = velocity.move_toward(Vector3.ZERO, 18.0 * delta)
		if _cd <= 0.0:
			_shoot(to.normalized())
		return false
	if d > reach * 0.9:
		_steer(tpos, float(def["speed"]) * 1.15, delta)
		return true
	velocity = velocity.move_toward(Vector3.ZERO, 22.0 * delta)
	if _cd <= 0.0:
		_strike()
	return false

func _strike() -> void:
	_cd = float(def["interval"]) * randf_range(0.95, 1.1)
	_bite = 0.22
	var crit := randf() < 0.08
	var amount := dmg * randf_range(0.9, 1.1) * (1.6 if crit else 1.0)
	var dealt: float = _target.take_hit(amount, global_position, crit, 1.4, self)
	if dealt > 0.0:
		world.fx.number(_target.global_position + Vector3(0, 0.4, 0), ("%d!" % int(dealt)) if crit else str(int(dealt)), Color(1.0, 0.85, 0.5) if crit else Color(0.85, 0.95, 1.0), crit)
		world.fx.burst(_target.global_position + Vector3(0, 0.9, 0), Color(def["glow"]), 5, 3.0, 0.7)
		world.play_sfx("hit", -9.0, randf_range(1.1, 1.4))

func _shoot(dir: Vector3) -> void:
	_cd = float(def["interval"]) * randf_range(0.95, 1.1)
	_bite = 0.18
	var fan: int = int(def.get("fan", 1))
	for fi in fan:
		var proj = world.get_projectile()
		if proj == null:
			break
		var ang := (float(fi) - float(fan - 1) * 0.5) * 0.26
		proj.fire(global_position + Vector3(0, 0, 0) + dir * 0.7, dir.rotated(Vector3.UP, ang), 13.0, 0.0, false, Color(def["glow"]), 0.3, 1.6, int(def.get("pierce", 0)), 1.0)
		proj.flat_damage = dmg * randf_range(0.9, 1.1)
		proj.from_pet = true
	world.play_sfx("enemy_shoot", -12.0, 1.5)

func _steer(target: Vector3, speed: float, delta: float) -> void:
	var data: VCDungeonData = world.data
	var to := target - global_position
	to.y = 0.0
	var dist := to.length()
	var my_t := data.world_to_tile(global_position)
	var tg_t := data.world_to_tile(target)
	var dir := Vector3.ZERO
	var direct: bool = dist < 6.0 and data.line_clear(my_t, tg_t)
	if direct:
		dir = to.normalized()
		_path = PackedVector3Array()
	else:
		_repath -= delta
		if _repath <= 0.0 or _path.is_empty():
			_path = data.find_path(global_position, target)
			_path_i = 1 if _path.size() > 1 else 0
			_repath = randf_range(0.4, 0.8)
		while _path_i < _path.size():
			var wp := _path[_path_i]
			var dv := wp - global_position
			dv.y = 0.0
			if dv.length() < 0.55 and _path_i < _path.size() - 1:
				_path_i += 1
			else:
				dir = dv.normalized()
				break
		if dir == Vector3.ZERO:
			dir = to.normalized()
	velocity = velocity.move_toward(dir * speed, 40.0 * delta)
	if dir.length() > 0.01 and (_target == null or not is_instance_valid(_target)):
		_facing = lerp_angle(_facing, atan2(-dir.x, -dir.z), clampf(10.0 * delta, 0.0, 1.0))

func _teleport_to_player() -> void:
	var ppos: Vector3 = world.player.global_position
	var ang := randf() * TAU
	var spot := ppos + Vector3(cos(ang), 0, sin(ang)) * 2.0
	var t: Vector2i = world.data.world_to_tile(spot)
	if not world.data.is_floor(t.x, t.y):
		t = world.data.nearest_floor(world.data.world_to_tile(ppos))
	global_position = world.data.tile_to_world(t)
	velocity = Vector3.ZERO
	_path = PackedVector3Array()
	world.fx.burst(global_position + Vector3(0, 0.6, 0), Color(def["glow"]), 8, 3.0, 0.7)

# --------------------------------------------------------------- damage
func take_damage(amount: float, from_pos: Vector3) -> bool:
	if dead or _invuln > 0.0:
		return false
	hp -= amount
	_invuln = 0.3
	_flash = 0.09
	_hp_show = 3.0
	_set_flash(true)
	world.fx.number(global_position + Vector3(0, 1.2, 0), str(int(amount)), Color(1.0, 0.55, 0.6), false)
	var away := global_position - from_pos
	away.y = 0.0
	if away.length() > 0.01:
		velocity += away.normalized() * 4.0
	if hp <= 0.0:
		hp = 0.0
		_die()
	return true

func heal(amount: float) -> void:
	if dead:
		return
	hp = minf(max_hp, hp + amount)
	_hp_show = 2.5
	world.fx.number(global_position + Vector3(0, 1.2, 0), "+%d" % int(amount), VCDefs.COL_GOOD, false)

func _die() -> void:
	dead = true
	respawn_t = RESPAWN_TIME
	_target = null
	rig.visible = false
	_bar_bg.visible = false
	_bar_fg.visible = false
	collision_mask = 0
	world.fx.burst(global_position + Vector3(0, 0.8, 0), Color(def["glow"]), 18, 5.0, 1.0)
	world.play_sfx("enemy_die", -8.0, 1.4)
	if world.hud != null:
		world.hud.toast("%s fell!  Back in %d seconds" % [display_name, int(RESPAWN_TIME)], Color(1.0, 0.7, 0.5), 2.5)
	fell.emit(self)

func respawn_now() -> void:
	respawn_t = 0.0
	if dead:
		_respawn()

func _respawn() -> void:
	dead = false
	hp = max_hp * 0.5
	rig.visible = true
	collision_mask = VCDefs.L_WORLD | VCDefs.L_PROP
	_teleport_to_player()
	_invuln = 1.0
	world.fx.ring(global_position, 2.0, Color(def["glow"]), 0.6)
	world.fx.spawn_pillar(global_position, 0.9, Color(def["glow"]), 1.4, 0.6)
	world.play_sfx("heal", -8.0, 1.5)
	if world.hud != null:
		world.hud.toast("%s is back!" % display_name, VCDefs.COL_GOOD, 2.0)

## Eats a potion from the hero's belt when badly hurt (only if the player allowed it).
func _tick_feed() -> void:
	var prof: VCProfile = VC.profile
	if prof == null or not prof.pet_feed or _feed_cd > 0.0 or hp > max_hp * FEED_BELOW:
		return
	var pl = world.player
	var reserve := 1 if float(pl.hp) < float(pl.max_hp) * 0.5 else 0      # keep one for yourself when you are hurt
	if prof.potions <= reserve:
		return
	prof.potions -= 1
	_feed_cd = 4.0
	heal(max_hp * 0.6)
	world.fx.burst(global_position + Vector3(0, 0.9, 0), VCDefs.COL_GOOD, 12, 3.0, 0.9)
	world.play_sfx("heal", -8.0, 1.3)
	if world.hud != null:
		world.hud.toast("%s ate a potion  (%d left)" % [display_name, prof.potions], VCDefs.COL_GOOD, 2.0)
	VC.notify_profile_changed()

func _set_flash(on: bool) -> void:
	for p in _parts:
		var mi: MeshInstance3D = p
		if not is_instance_valid(mi):
			continue
		if on:
			if not mi.has_meta("orig"):
				mi.set_meta("orig", mi.material_override)
			mi.material_override = VCMats.flash_overlay()
		elif mi.has_meta("orig"):
			mi.material_override = mi.get_meta("orig")
			mi.remove_meta("orig")

# ------------------------------------------------------------- animation
func _update_bar() -> void:
	var show := hp < max_hp * 0.999 or _hp_show > 0.0
	_bar_bg.visible = show
	_bar_fg.visible = show
	if show:
		var f := clampf(hp / max_hp, 0.0, 1.0)
		var w := 0.9 * float(def.get("scale", 1.0)) + 0.3
		_bar_bg.scale = Vector3(w, 1.0, 1.0)
		_bar_fg.scale = Vector3(maxf(w * f, 0.001), 0.7, 1.0)
		(_bar_fg.material_override as StandardMaterial3D).albedo_color = Color(0.35, 1.0, 0.55) if f > 0.45 else (Color(1.0, 0.8, 0.3) if f > 0.2 else Color(1.0, 0.3, 0.35))

func _animate(delta: float) -> void:
	rig.rotation.y = lerp_angle(rig.rotation.y, _facing, clampf(delta * 14.0, 0.0, 1.0))
	var spd := Vector2(velocity.x, velocity.z).length()
	var swing := sin(_t * (8.0 + spd * 1.4)) * clampf(spd / 3.0, 0.0, 1.0) * 0.8
	var bob := sin(_t * 2.6) * 0.12 if _hover > 0.0 else absf(swing) * 0.05
	var lunge := sin(clampf(_bite / 0.22, 0.0, 1.0) * PI) * 0.35
	rig.position = Vector3(0, _hover + bob, 0) + Vector3(-sin(_facing), 0, -cos(_facing)) * lunge * 0.0
	rig.position.z = 0.0
	if _leg_a != null:
		_leg_a.rotation.x = swing
		_leg_b.rotation.x = -swing
	for wg in _wings:
		(wg["n"] as Node3D).rotation.z = float(wg["s"]) * sin(_t * 15.0) * 0.6
	if _squash != null:
		var sq := sin(_t * 3.4)
		_squash.scale = Vector3(1.0 + 0.07 * sq + lunge * 0.4, 1.0 - 0.09 * sq - lunge * 0.4, 1.0 + 0.07 * sq + lunge * 0.4)
	for i in _spin.size():
		var sp: Node3D = _spin[i]
		if i == 0:
			sp.rotation.y = _t * 2.0
		else:
			var a := _t * 2.4 + TAU * float(i) / 3.0
			sp.position = Vector3(cos(a) * 0.55, sin(_t * 3.0 + float(i)) * 0.15, sin(a) * 0.55)
			sp.rotation.y = a
	rig.rotation.x = -lunge * 0.8
