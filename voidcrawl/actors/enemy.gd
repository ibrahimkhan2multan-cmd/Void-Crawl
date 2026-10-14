class_name VCEnemy
extends CharacterBody3D
## One class for every non-boss creature. Behaviour comes from VCEnemyDefs[type].ai:
##   melee  - chase, telegraphed cone swing
##   swarm  - like melee but fast, short wind-up, comes in packs
##   ranged - keeps distance, strafes, fires telegraphed bolts
##   dasher - circles then telegraphs a straight-line dash
##   slam   - slow brute, telegraphed ground slam (super armour)
## Boss subclass overrides _update_ai().

signal killed(enemy)

enum S { SPAWN, CHASE, WINDUP, ATTACK, RECOVER, STUN, DEAD }

const HURT_COLOR := Color(1.0, 0.25, 0.4)

var world: Node = null
var type_id := "husk"
var def: Dictionary = {}
var level := 1
var hp := 10.0
var max_hp := 10.0
var dmg := 5.0
var speed_mult := 1.0
var state: int = S.SPAWN
var hit_radius := 0.45
var non_solid := true
var super_armor := false
var invulnerable := false
var no_drops := false
var room := -1
var facing := 0.0
var is_boss := false
var display_name := ""

var _t := 0.0                 # time in current state
var _cd := 0.0                # attack cooldown
var _spawn_delay := 0.6
var _anim_t := 0.0
var _flash := 0.0
var _knock := Vector3.ZERO
var _stun_t := 0.0
var _path := PackedVector3Array()
var _path_i := 0
var _repath_in := 0.0
var _stuck_t := 0.0
var _last_pos := Vector3.ZERO
var _tele := -1
var _dash_dir := Vector3.ZERO
var _dash_hit := false
var _strafe_sign := 1.0
var _attack_done := false
var _hover := 0.0
var _hp_bar_t := 0.0
var rig: Node3D
var _parts: Array = []
var _arm_r: Node3D
var _arm_l: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _spin_parts: Array = []
var _legs8: Array = []
var _eye_mat: Material

func setup(p_type: String, p_level: int, p_room: int) -> void:
	type_id = p_type
	def = VCEnemyDefs.get_def(p_type)
	level = p_level
	room = p_room
	display_name = String(def["name"])
	max_hp = float(def["hp"]) * VCEnemyDefs.hp_scale(level)
	hp = max_hp
	dmg = float(def["dmg"]) * VCEnemyDefs.dmg_scale(level)
	hit_radius = float(def["radius"])
	super_armor = String(def["ai"]) in ["slam", "boss"]
	_strafe_sign = 1.0 if randf() < 0.5 else -1.0

func _ready() -> void:
	collision_layer = VCDefs.L_ENEMY
	collision_mask = VCDefs.L_WORLD | VCDefs.L_PROP
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = hit_radius * 0.9
	sh.height = 1.6 * float(def.get("scale", 1.0))
	cs.shape = sh
	cs.position = Vector3(0, sh.height * 0.5, 0)
	add_child(cs)
	_build_rig()
	rig.scale = Vector3.ONE * float(def.get("scale", 1.0))
	_hover = 1.1 if bool(def.get("floating", false)) else 0.0
	_cd = randf_range(0.2, 0.9)
	_last_pos = global_position
	name = "%s_%d" % [type_id, get_instance_id()]
	rig.visible = false

func is_alive() -> bool:
	return state != S.DEAD and state != S.SPAWN

func is_dying_or_dead() -> bool:
	return state == S.DEAD

# ------------------------------------------------------------------- rig
func _mk(parent: Node3D, size: Vector3, pos: Vector3, col: Color, em: float = 0.0) -> MeshInstance3D:
	var mi := VCMats.part(parent, size, pos, col, em)
	_parts.append(mi)
	return mi

func _limb(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n

func _build_rig() -> void:
	rig = Node3D.new()
	rig.name = "Rig"
	add_child(rig)
	var glow := Color(0.75, 0.35, 1.0)
	match type_id:
		"husk":
			var bone := Color(0.72, 0.68, 0.62)
			var rag := Color(0.28, 0.2, 0.34)
			_leg_l = _limb(rig, Vector3(-0.15, 0.6, 0)); _leg_r = _limb(rig, Vector3(0.15, 0.6, 0))
			_mk(_leg_l, Vector3(0.2, 0.6, 0.22), Vector3(0, -0.3, 0), bone * 0.8)
			_mk(_leg_r, Vector3(0.2, 0.6, 0.22), Vector3(0, -0.3, 0), bone * 0.8)
			_mk(rig, Vector3(0.58, 0.7, 0.34), Vector3(0, 0.95, 0), rag)
			_mk(rig, Vector3(0.64, 0.3, 0.4), Vector3(0, 0.78, 0), rag * 0.8)
			_mk(rig, Vector3(0.44, 0.44, 0.44), Vector3(0, 1.52, 0), bone)
			_mk(rig, Vector3(0.1, 0.09, 0.05), Vector3(-0.1, 1.55, -0.23), glow, 3.0)
			_mk(rig, Vector3(0.1, 0.09, 0.05), Vector3(0.1, 1.55, -0.23), glow, 3.0)
			_arm_l = _limb(rig, Vector3(-0.4, 1.22, 0)); _arm_r = _limb(rig, Vector3(0.4, 1.22, 0))
			_mk(_arm_l, Vector3(0.16, 0.66, 0.16), Vector3(0, -0.3, 0), bone * 0.85)
			_mk(_arm_r, Vector3(0.16, 0.66, 0.16), Vector3(0, -0.3, 0), bone * 0.85)
			_mk(_arm_r, Vector3(0.08, 0.1, 0.8), Vector3(0, -0.62, -0.4), Color(0.45, 0.4, 0.5))
		"slinger":
			var bone2 := Color(0.82, 0.8, 0.74)
			_leg_l = _limb(rig, Vector3(-0.12, 0.62, 0)); _leg_r = _limb(rig, Vector3(0.12, 0.62, 0))
			_mk(_leg_l, Vector3(0.14, 0.62, 0.16), Vector3(0, -0.31, 0), bone2 * 0.8)
			_mk(_leg_r, Vector3(0.14, 0.62, 0.16), Vector3(0, -0.31, 0), bone2 * 0.8)
			_mk(rig, Vector3(0.46, 0.62, 0.28), Vector3(0, 0.94, 0), Color(0.2, 0.14, 0.3))
			_mk(rig, Vector3(0.4, 0.4, 0.4), Vector3(0, 1.46, 0), bone2)
			_mk(rig, Vector3(0.5, 0.48, 0.48), Vector3(0, 1.5, 0.05), Color(0.14, 0.09, 0.22))
			_mk(rig, Vector3(0.09, 0.08, 0.05), Vector3(-0.09, 1.46, -0.21), glow, 3.0)
			_mk(rig, Vector3(0.09, 0.08, 0.05), Vector3(0.09, 1.46, -0.21), glow, 3.0)
			_arm_l = _limb(rig, Vector3(-0.32, 1.18, 0)); _arm_r = _limb(rig, Vector3(0.32, 1.18, 0))
			_mk(_arm_l, Vector3(0.12, 0.6, 0.12), Vector3(0, -0.28, 0), bone2 * 0.85)
			_mk(_arm_r, Vector3(0.12, 0.6, 0.12), Vector3(0, -0.28, 0), bone2 * 0.85)
			_mk(_arm_r, Vector3(0.3, 0.3, 0.3), Vector3(0, -0.62, -0.28), glow, 2.0)
		"spiderling":
			_mk(rig, Vector3(0.7, 0.4, 0.9), Vector3(0, 0.5, 0.15), Color(0.16, 0.1, 0.22))
			_mk(rig, Vector3(0.46, 0.34, 0.4), Vector3(0, 0.48, -0.5), Color(0.22, 0.14, 0.3))
			_mk(rig, Vector3(0.08, 0.08, 0.05), Vector3(-0.1, 0.55, -0.71), glow, 3.0)
			_mk(rig, Vector3(0.08, 0.08, 0.05), Vector3(0.1, 0.55, -0.71), glow, 3.0)
			_mk(rig, Vector3(0.22, 0.05, 0.3), Vector3(0, 0.72, 0.25), glow, 1.6)
			for i in 6:
				var side := -1.0 if i % 2 == 0 else 1.0
				var zi := -0.35 + 0.35 * float(i / 2)
				var leg := _limb(rig, Vector3(0.3 * side, 0.45, zi))
				_mk(leg, Vector3(0.55, 0.08, 0.08), Vector3(0.28 * side, -0.1, 0), Color(0.18, 0.12, 0.26))
				_legs8.append(leg)
		"wisp":
			var core := _mk(rig, Vector3(0.6, 0.6, 0.6), Vector3(0, 0.0, 0), glow, 2.4)
			core.rotation = Vector3(0.7, 0.7, 0.0)
			_spin_parts.append(core)
			for i in 3:
				var shard := _mk(rig, Vector3(0.18, 0.4, 0.18), Vector3.ZERO, glow * 1.2, 2.0)
				_spin_parts.append(shard)
			_mk(rig, Vector3(0.9, 0.05, 0.9), Vector3(0, -1.05, 0), Color(0.3, 0.1, 0.5, 1.0), 0.0).visible = false
		"brute":
			var stone := Color(0.4, 0.36, 0.46)
			_leg_l = _limb(rig, Vector3(-0.22, 0.6, 0)); _leg_r = _limb(rig, Vector3(0.22, 0.6, 0))
			_mk(_leg_l, Vector3(0.3, 0.62, 0.32), Vector3(0, -0.31, 0), stone * 0.7)
			_mk(_leg_r, Vector3(0.3, 0.62, 0.32), Vector3(0, -0.31, 0), stone * 0.7)
			_mk(rig, Vector3(0.9, 0.9, 0.5), Vector3(0, 1.05, 0), stone)
			_mk(rig, Vector3(0.7, 0.34, 0.12), Vector3(0, 1.15, -0.3), glow, 1.4)
			_mk(rig, Vector3(0.46, 0.46, 0.46), Vector3(0, 1.72, 0), Color(0.55, 0.5, 0.5))
			_mk(rig, Vector3(0.12, 0.1, 0.05), Vector3(-0.11, 1.74, -0.24), Color(1.0, 0.3, 0.5), 3.0)
			_mk(rig, Vector3(0.12, 0.1, 0.05), Vector3(0.11, 1.74, -0.24), Color(1.0, 0.3, 0.5), 3.0)
			_mk(rig, Vector3(0.42, 0.4, 0.42), Vector3(-0.62, 1.52, 0), glow, 1.4)
			_mk(rig, Vector3(0.42, 0.4, 0.42), Vector3(0.62, 1.52, 0), glow, 1.4)
			_arm_l = _limb(rig, Vector3(-0.62, 1.35, 0)); _arm_r = _limb(rig, Vector3(0.62, 1.35, 0))
			_mk(_arm_l, Vector3(0.28, 0.8, 0.28), Vector3(0, -0.35, 0), stone * 0.9)
			_mk(_arm_r, Vector3(0.28, 0.8, 0.28), Vector3(0, -0.35, 0), stone * 0.9)
			_mk(_arm_r, Vector3(0.14, 0.14, 1.0), Vector3(0, -0.8, -0.4), Color(0.28, 0.2, 0.15))
			_mk(_arm_r, Vector3(0.5, 0.5, 0.7), Vector3(0, -0.8, -1.0), stone * 1.1)
	_set_visible_rig(false)

func _set_visible_rig(v: bool) -> void:
	if rig != null:
		rig.visible = v

# -------------------------------------------------------------------- tick
func _physics_process(delta: float) -> void:
	if world == null:
		return
	_t += delta
	_anim_t += delta
	_cd = maxf(0.0, _cd - delta)
	if _flash > 0.0:
		_flash -= delta
		if _flash <= 0.0:
			_set_flash(false)
	if state == S.SPAWN:
		_spawn_delay -= delta
		if _spawn_delay <= 0.0:
			_set_visible_rig(true)
			state = S.CHASE
			non_solid = false
			_t = 0.0
			world.fx.burst(global_position + Vector3(0, 0.6, 0), Color(0.7, 0.35, 1.0), 14, 4.0, 1.0)
		return
	if state == S.DEAD:
		_animate(delta)
		return
	if _stun_t > 0.0:
		_stun_t -= delta
		if _stun_t <= 0.0 and state == S.STUN:
			_enter(S.CHASE)
	velocity = _knock
	_knock = _knock.move_toward(Vector3.ZERO, 22.0 * delta)
	if state != S.STUN:
		_update_ai(delta)
	_separate(delta)
	velocity.y = 0.0
	move_and_slide()
	global_position.y = 0.0
	_check_stuck(delta)
	_animate(delta)

func _enter(s: int) -> void:
	state = s
	_t = 0.0
	if s != S.WINDUP and _tele >= 0:
		world.fx.cancel(_tele)
		_tele = -1

func _player_vec() -> Vector3:
	var v: Vector3 = world.player.global_position - global_position
	v.y = 0.0
	return v

func _face(dir: Vector3, rate: float, delta: float) -> void:
	if dir.length() < 0.01:
		return
	facing = lerp_angle(facing, atan2(-dir.x, -dir.z), clampf(rate * delta, 0.0, 1.0))

func _forward() -> Vector3:
	return Vector3(-sin(facing), 0, -cos(facing))

# ----------------------------------------------------------------- AI core
func _update_ai(delta: float) -> void:
	if not world.player.is_alive():
		velocity += Vector3.ZERO
		return
	match String(def["ai"]):
		"melee", "swarm": _ai_melee(delta)
		"ranged": _ai_ranged(delta)
		"dasher": _ai_dasher(delta)
		"slam": _ai_slam(delta)

func _speed() -> float:
	return float(def["speed"]) * speed_mult

func _ai_melee(delta: float) -> void:
	var pv := _player_vec()
	var d := pv.length()
	var reach: float = float(def["reach"])
	match state:
		S.CHASE:
			_face(pv, 9.0, delta)
			if d > reach * 0.8:
				_move_toward(world.player.global_position, _speed(), delta)
			if d <= reach * 0.95 and _cd <= 0.0:
				_begin_windup()
		S.WINDUP:
			var lock_at: float = float(def["windup"]) * 0.3
			if _t < lock_at:
				_face(pv, 12.0, delta)
			elif _tele < 0:
				_tele = world.fx.telegraph(global_position, facing, "cone", reach + 0.3, float(def["arc"]), maxf(float(def["windup"]) - _t, 0.05))
			if _t >= float(def["windup"]):
				_strike_cone(reach + 0.3, float(def["arc"]), dmg)
				_enter(S.ATTACK)
		S.ATTACK:
			if _t >= 0.28:
				_cd = float(def["cooldown"]) * randf_range(0.9, 1.2)
				_enter(S.RECOVER)
		S.RECOVER:
			if _t >= 0.45:
				_enter(S.CHASE)

func _begin_windup() -> void:
	_enter(S.WINDUP)
	world.play_sfx("telegraph", -10.0, 1.0 + randf() * 0.2)

func _strike_cone(reach: float, arc_deg: float, amount: float) -> void:
	var pl = world.player
	var pv := _player_vec()
	var d := pv.length()
	world.fx.slash(global_position, facing, reach, arc_deg, Color(1.0, 0.35, 0.5), 0.2)
	if d <= reach + pl.hit_radius:
		var ang := rad_to_deg(_forward().angle_to(pv.normalized())) if d > 0.05 else 0.0
		if ang <= arc_deg * 0.5 + 10.0:
			pl.take_damage(amount, global_position)

func _ai_ranged(delta: float) -> void:
	var pv := _player_vec()
	var d := pv.length()
	var pref: float = float(def["pref_dist"])
	match state:
		S.CHASE:
			_face(pv, 8.0, delta)
			var los: bool = world.data.line_clear(world.data.world_to_tile(global_position), world.data.world_to_tile(world.player.global_position))
			if d > pref * 1.25 or not los:
				_move_toward(world.player.global_position, _speed(), delta)
			elif d < pref * 0.6:
				velocity += -pv.normalized() * _speed()
			else:
				var side := pv.normalized().cross(Vector3.UP) * _strafe_sign
				velocity += side * _speed() * 0.7
				if randf() < delta * 0.25:
					_strafe_sign = -_strafe_sign
			if _cd <= 0.0 and los and d < float(def["reach"]):
				_enter(S.WINDUP)
				_attack_done = false
				world.play_sfx("telegraph", -10.0, 1.3)
		S.WINDUP:
			_face(pv, 12.0, delta)
			if _t >= float(def["windup"]) and not _attack_done:
				_attack_done = true
				var proj = world.get_projectile()
				if proj != null:
					proj.fire(global_position + _forward() * 0.6, _forward(), float(def["proj_speed"]), dmg, true, Color(0.9, 0.3, 1.0), 0.32, 2.6)
				world.play_sfx("enemy_shoot", -6.0)
				_cd = float(def["cooldown"]) * randf_range(0.9, 1.3)
				_enter(S.RECOVER)
		S.RECOVER:
			if _t >= 0.4:
				_enter(S.CHASE)

func _ai_dasher(delta: float) -> void:
	var pv := _player_vec()
	var d := pv.length()
	match state:
		S.CHASE:
			_face(pv, 8.0, delta)
			if d > 7.0:
				_move_toward(world.player.global_position, _speed(), delta)
			else:
				var side := pv.normalized().cross(Vector3.UP) * _strafe_sign
				velocity += side * _speed() * 0.9
				if d < 4.0:
					velocity += -pv.normalized() * _speed() * 0.6
			if _cd <= 0.0 and d < float(def["reach"]) and d > 2.0:
				_enter(S.WINDUP)
				world.play_sfx("telegraph", -8.0, 0.8)
		S.WINDUP:
			_face(pv, 14.0, delta)
			var length: float = float(def["dash_speed"]) * float(def["dash_time"])
			if _tele < 0 and _t > 0.05:
				_tele = world.fx.telegraph(global_position, facing, "cone", length, 14.0, float(def["windup"]) - 0.05)
			if _t >= float(def["windup"]):
				_dash_dir = _forward()
				_dash_hit = false
				_enter(S.ATTACK)
		S.ATTACK:
			velocity = _dash_dir * float(def["dash_speed"])
			world.fx.burst(global_position + Vector3(0, _hover, 0), Color(0.7, 0.3, 1.0), 2, 1.0, 0.6)
			if not _dash_hit and d < hit_radius + world.player.hit_radius + 0.35:
				_dash_hit = true
				world.player.take_damage(dmg, global_position)
			if _t >= float(def["dash_time"]):
				_cd = float(def["cooldown"]) * randf_range(0.9, 1.3)
				_enter(S.RECOVER)
		S.RECOVER:
			if _t >= 0.8:
				_enter(S.CHASE)

func _ai_slam(delta: float) -> void:
	var pv := _player_vec()
	var d := pv.length()
	var reach: float = float(def["reach"])
	match state:
		S.CHASE:
			_face(pv, 5.0, delta)
			if d > reach * 0.7:
				_move_toward(world.player.global_position, _speed(), delta)
			if d <= reach and _cd <= 0.0:
				_enter(S.WINDUP)
				var c := global_position + _forward() * 1.8
				_tele = world.fx.telegraph(c, 0.0, "circle", float(def["slam_radius"]), 360.0, float(def["windup"]))
				world.play_sfx("telegraph", -6.0, 0.7)
		S.WINDUP:
			if _t < float(def["windup"]) * 0.5:
				_face(pv, 4.0, delta)
			if _t >= float(def["windup"]):
				_slam_hit(global_position + _forward() * 1.8, float(def["slam_radius"]), dmg, 8.0)
				_enter(S.ATTACK)
		S.ATTACK:
			if _t >= 0.35:
				_cd = float(def["cooldown"])
				_enter(S.RECOVER)
		S.RECOVER:
			if _t >= 0.9:
				_enter(S.CHASE)

func _slam_hit(center: Vector3, radius: float, amount: float, knock: float) -> void:
	world.fx.ring(center, radius, Color(1.0, 0.35, 0.5), 0.4)
	world.fx.burst(center + Vector3(0, 0.3, 0), Color(0.8, 0.6, 0.5), 18, 6.0, 1.2)
	world.camera_shake(0.45)
	world.play_sfx("hit", 0.0, 0.5)
	var pl = world.player
	var d := Vector2(pl.global_position.x - center.x, pl.global_position.z - center.z).length()
	if d <= radius + pl.hit_radius:
		pl.take_damage(amount, center)

# ---------------------------------------------------------------- movement
func _move_toward(target: Vector3, speed: float, delta: float) -> void:
	var data: VCDungeonData = world.data
	var to := target - global_position
	to.y = 0.0
	var dist := to.length()
	var my_t := data.world_to_tile(global_position)
	var tg_t := data.world_to_tile(target)
	var dir := Vector3.ZERO
	var direct: bool = dist < 6.0 and data.line_clear(my_t, tg_t) and _corridor_clear(my_t, tg_t)
	if direct:
		dir = to.normalized()
		_path = PackedVector3Array()
	else:
		_repath_in -= delta
		if _repath_in <= 0.0 or _path.is_empty():
			_path = data.find_path(global_position, target)
			_path_i = 1 if _path.size() > 1 else 0
			_repath_in = randf_range(0.35, 0.7)
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
	velocity += dir * speed

## True when the straight line also has clearance for the body (no diagonal squeezes).
func _corridor_clear(a: Vector2i, b: Vector2i) -> bool:
	var data: VCDungeonData = world.data
	var dv := Vector2(b - a)
	if dv.length() < 1.0:
		return true
	var n := Vector2(-dv.y, dv.x).normalized()
	var sx := int(round(n.x))
	var sy := int(round(n.y))
	var steps := int(dv.length())
	for i in range(0, steps + 1):
		var p := Vector2(a) + dv * (float(i) / float(maxi(steps, 1)))
		var px := int(round(p.x))
		var py := int(round(p.y))
		if data.is_solid(px + sx, py + sy) and data.is_solid(px - sx, py - sy):
			return false
	return true

func _check_stuck(delta: float) -> void:
	if state != S.CHASE:
		_stuck_t = 0.0
		_last_pos = global_position
		return
	if global_position.distance_to(_last_pos) < _speed() * delta * 0.25:
		_stuck_t += delta
		if _stuck_t > 0.6:
			_stuck_t = 0.0
			_repath_in = 0.0
			_path = PackedVector3Array()
			_knock += Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * 2.5
	else:
		_stuck_t = 0.0
	_last_pos = global_position

func _separate(delta: float) -> void:
	for e in world.enemies:
		if e == self or not e.is_alive():
			continue
		var dv: Vector3 = global_position - e.global_position
		dv.y = 0.0
		var min_d: float = (hit_radius + e.hit_radius) * 0.85
		var dl := dv.length()
		if dl < min_d:
			if dl < 0.01:
				dv = Vector3(randf() - 0.5, 0, randf() - 0.5)
				dl = 0.1
			velocity += dv / dl * (min_d - dl) * 6.0

# ------------------------------------------------------------------ damage
func stun(t: float) -> void:
	if state == S.DEAD or state == S.SPAWN:
		return
	if super_armor:
		t *= 0.25
		if is_boss:
			return
	_stun_t = maxf(_stun_t, t)
	if not super_armor:
		_enter(S.STUN)
	_cancel_tele()

func _cancel_tele() -> void:
	if _tele >= 0:
		world.fx.cancel(_tele)
		_tele = -1

## Returns damage dealt (0 if untargetable).
func take_hit(amount: float, from_pos: Vector3, crit: bool = false, knock: float = 0.0, _source: Node = null) -> float:
	if state == S.DEAD or state == S.SPAWN or invulnerable:
		return 0.0
	hp -= amount
	_flash = 0.09
	_set_flash(true)
	var away := global_position - from_pos
	away.y = 0.0
	if away.length() > 0.01:
		var k := knock * (0.25 if super_armor else 1.0)
		_knock += away.normalized() * k * 2.0
	if not super_armor and state in [S.WINDUP, S.CHASE, S.RECOVER] and knock > 0.0:
		_stun_t = 0.18
		_enter(S.STUN)
	_hp_bar_t = 3.0
	if hp <= 0.0:
		hp = 0.0
		_die()
	return amount

func _die() -> void:
	_enter(S.DEAD)
	_cancel_tele()
	collision_layer = 0
	collision_mask = 0
	world.play_sfx("enemy_die", -2.0, randf_range(0.9, 1.1))
	world.fx.burst(global_position + Vector3(0, 0.9 * float(def.get("scale", 1.0)), 0), Color(0.75, 0.4, 1.0), 20, 6.0, 1.1)
	killed.emit(self)

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

# ---------------------------------------------------------------- animation
func _animate(delta: float) -> void:
	if rig == null:
		return
	if state != S.WINDUP and state != S.ATTACK:
		rig.rotation.y = lerp_angle(rig.rotation.y, facing, clampf(delta * 14.0, 0.0, 1.0))
	else:
		rig.rotation.y = lerp_angle(rig.rotation.y, facing, clampf(delta * 22.0, 0.0, 1.0))
	if state == S.DEAD:
		var k := clampf(_t / 0.55, 0.0, 1.0)
		rig.rotation.x = -k * PI * 0.5
		rig.position.y = lerpf(_hover, 0.0, k)
		rig.scale = Vector3.ONE * float(def.get("scale", 1.0)) * (1.0 - maxf(0.0, k - 0.6) * 2.0)
		if _t > 0.9:
			queue_free()
		return
	var spd := Vector2(velocity.x, velocity.z).length()
	var swing := sin(_anim_t * (7.0 + spd * 1.6)) * clampf(spd / 3.0, 0.0, 1.0) * 0.8
	rig.position.y = _hover + (sin(_anim_t * 2.4) * 0.12 if _hover > 0.0 else absf(swing) * 0.05)
	if _leg_l != null:
		_leg_l.rotation.x = swing
		_leg_r.rotation.x = -swing
	for i in _legs8.size():
		(_legs8[i] as Node3D).rotation.y = sin(_anim_t * 18.0 + float(i) * 1.3) * 0.35
	for i in _spin_parts.size():
		var sp: Node3D = _spin_parts[i]
		if i == 0:
			sp.rotation.y = _anim_t * 2.0
			sp.rotation.x = 0.7 + sin(_anim_t * 1.5) * 0.2
		else:
			var a := _anim_t * 2.4 + TAU * float(i) / 3.0
			sp.position = Vector3(cos(a) * 0.75, sin(_anim_t * 3.0 + float(i)) * 0.2, sin(a) * 0.75)
			sp.rotation.y = a
	if _arm_r != null:
		match state:
			S.WINDUP:
				var kk := clampf(_t / maxf(float(def["windup"]), 0.1), 0.0, 1.0)
				_arm_r.rotation.x = lerpf(0.0, -2.5, kk)
				if _arm_l != null:
					_arm_l.rotation.x = lerpf(0.0, -1.2, kk)
			S.ATTACK:
				_arm_r.rotation.x = lerpf(_arm_r.rotation.x, 0.9, clampf(delta * 25.0, 0.0, 1.0))
			S.STUN:
				_arm_r.rotation.z = sin(_anim_t * 40.0) * 0.2
			_:
				_arm_r.rotation.x = lerpf(_arm_r.rotation.x, -swing * 0.7, clampf(delta * 10.0, 0.0, 1.0))
				_arm_r.rotation.z = lerpf(_arm_r.rotation.z, 0.0, 0.2)
				if _arm_l != null:
					_arm_l.rotation.x = lerpf(_arm_l.rotation.x, swing * 0.7, clampf(delta * 10.0, 0.0, 1.0))
