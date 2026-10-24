class_name VCBoss
extends VCEnemy
## The Hollow Warden. Three phases (100-66-33-0 % health). Every attack has a visible
## ground telegraph; later phases add new attacks and shorten cooldowns.
##   phase 1: cleave, shockwave, charge
##   phase 2: + summon, orb volley
##   phase 3: + void rifts, spin; faster

signal phase_changed(phase)

func _gc() -> Color:
	return def.get("glow", Color(0.85, 0.4, 1.0))

var phase := 1
var _atk := ""
var _last_atk := ""
var _rifts: Array = []            # {pos, t, life, tele}
var _spin_tick := 0.0
var _second_ring := false
var _shift_t := 0.0
var _summon_cd := 6.0
var _orbit: Node3D
var _atk_dir := Vector3.FORWARD
var _hit_once := false
var _adds: Array = []

func setup(p_type: String, p_level: int, p_room: int) -> void:
	super.setup(p_type, p_level, p_room)
	is_boss = true
	super_armor = true
	_spawn_delay = 1.5

func _build_rig() -> void:
	rig = Node3D.new()
	rig.name = "Rig"
	add_child(rig)
	var bone := Color(0.74, 0.7, 0.66)
	var iron: Color = def.get("body", Color(0.2, 0.19, 0.26))
	var glow: Color = def.get("glow", Color(0.78, 0.3, 1.0))
	_leg_l = _limb(rig, Vector3(-0.22, 0.7, 0)); _leg_r = _limb(rig, Vector3(0.22, 0.7, 0))
	_mk(_leg_l, Vector3(0.26, 0.72, 0.28), Vector3(0, -0.36, 0), iron)
	_mk(_leg_r, Vector3(0.26, 0.72, 0.28), Vector3(0, -0.36, 0), iron)
	_mk(_leg_l, Vector3(0.3, 0.16, 0.4), Vector3(0, -0.7, -0.05), iron * 0.7)
	_mk(_leg_r, Vector3(0.3, 0.16, 0.4), Vector3(0, -0.7, -0.05), iron * 0.7)
	_mk(rig, Vector3(0.9, 0.9, 0.5), Vector3(0, 1.2, 0), iron)
	_mk(rig, Vector3(0.62, 0.55, 0.12), Vector3(0, 1.28, -0.3), glow, 1.5)               # glowing ribcage
	_mk(rig, Vector3(0.96, 0.2, 0.56), Vector3(0, 0.78, 0), iron * 0.7)
	_mk(rig, Vector3(0.5, 0.5, 0.5), Vector3(0, 1.98, 0), bone)
	_mk(rig, Vector3(0.12, 0.1, 0.05), Vector3(-0.12, 2.0, -0.26), glow, 3.5)
	_mk(rig, Vector3(0.12, 0.1, 0.05), Vector3(0.12, 2.0, -0.26), glow, 3.5)
	# crown
	_mk(rig, Vector3(0.58, 0.14, 0.58), Vector3(0, 2.3, 0), Color(0.3, 0.25, 0.4))
	for i in 5:
		var a := TAU * float(i) / 5.0
		_mk(rig, Vector3(0.1, 0.3, 0.1), Vector3(cos(a) * 0.24, 2.5, sin(a) * 0.24), glow, 2.5)
	# shoulders
	_mk(rig, Vector3(0.5, 0.42, 0.5), Vector3(-0.72, 1.62, 0), iron * 1.2)
	_mk(rig, Vector3(0.5, 0.42, 0.5), Vector3(0.72, 1.62, 0), iron * 1.2)
	_mk(rig, Vector3(0.18, 0.6, 0.18), Vector3(-0.82, 1.98, 0), glow, 2.0).rotation.z = 0.25
	_mk(rig, Vector3(0.18, 0.6, 0.18), Vector3(0.82, 1.98, 0), glow, 2.0).rotation.z = -0.25
	_arm_l = _limb(rig, Vector3(-0.72, 1.5, 0)); _arm_r = _limb(rig, Vector3(0.72, 1.5, 0))
	_mk(_arm_l, Vector3(0.24, 0.9, 0.24), Vector3(0, -0.4, 0), bone * 0.85)
	_mk(_arm_r, Vector3(0.24, 0.9, 0.24), Vector3(0, -0.4, 0), bone * 0.85)
	# great cleaver
	_mk(_arm_r, Vector3(0.12, 0.12, 0.9), Vector3(0, -0.9, -0.1), Color(0.3, 0.2, 0.16))
	_mk(_arm_r, Vector3(0.18, 0.5, 1.4), Vector3(0, -0.85, -1.2), Color(0.5, 0.48, 0.6))
	_mk(_arm_r, Vector3(0.2, 0.08, 1.4), Vector3(0, -1.12, -1.2), glow, 2.2)
	# cape
	_mk(rig, Vector3(0.9, 1.3, 0.08), Vector3(0, 1.3, 0.32), iron * 0.8)
	# orbiting shards
	_orbit = Node3D.new()
	_orbit.position = Vector3(0, 1.4, 0)
	rig.add_child(_orbit)
	for i in 4:
		var a2 := TAU * float(i) / 4.0
		var sh := _mk(_orbit, Vector3(0.2, 0.5, 0.2), Vector3(cos(a2) * 1.5, 0.3 * sin(float(i) * 2.0), sin(a2) * 1.5), glow, 2.4)
		sh.rotation = Vector3(0.3, a2, 0.2)
	rig.visible = false

func _animate(delta: float) -> void:
	super._animate(delta)
	if _orbit != null and state != S.DEAD:
		_orbit.rotation.y += delta * (1.2 + float(phase) * 0.5)

# -------------------------------------------------------------------- phases
func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _shift_t > 0.0:
		_shift_t -= delta
		if _shift_t <= 0.0:
			invulnerable = false
			_phase_started()
	_tick_rifts(delta)

func take_hit(amount: float, from_pos: Vector3, crit: bool = false, knock: float = 0.0, source: Node = null) -> float:
	var dealt := super.take_hit(amount, from_pos, crit, 0.0, source)
	if dealt > 0.0 and state != S.DEAD:
		var frac := hp / max_hp
		var np := 1 if frac > 0.66 else (2 if frac > 0.33 else 3)
		if np > phase:
			phase = np
			_begin_shift()
	return dealt

func _begin_shift() -> void:
	invulnerable = true
	_shift_t = 1.8
	_stun_t = 1.8
	_enter(S.STUN)
	_cancel_tele()
	_cd = 1.0
	world.play_sfx("boss_roar")
	world.camera_shake(0.8)
	world.fx.ring(global_position, 9.0, _gc(), 0.8)
	world.fx.burst(global_position + Vector3(0, 2.0, 0), _gc(), 30, 9.0, 1.6)
	# shove the hero out of melee range (no damage)
	var away: Vector3 = world.player.global_position - global_position
	away.y = 0.0
	if away.length() < 7.0:
		world.player.apply_knock(away.normalized() * 11.0)
	phase_changed.emit(phase)

func _phase_started() -> void:
	if phase == 2:
		_do_summon()
	elif phase == 3:
		speed_mult = 1.25
		_summon_cd = 8.0

func _cooldown_for_phase() -> float:
	return float(def["cooldown"]) * (1.0 if phase == 1 else (0.85 if phase == 2 else 0.62))

func _wind(base: float) -> float:
	return base * (1.0 if phase < 3 else 0.78)

# ----------------------------------------------------------------------- AI
func _update_ai(delta: float) -> void:
	_summon_cd -= delta
	if not world.player.is_alive():
		return
	var pv := _player_vec()
	var d := pv.length()
	match state:
		S.CHASE:
			_face(pv, 4.5, delta)
			if d > 3.4:
				_move_toward(world.player.global_position, _speed(), delta)
			if _cd <= 0.0:
				_begin_attack(_pick_attack(d))
		S.WINDUP:
			_tick_windup(delta, pv)
		S.ATTACK:
			_tick_active(delta, pv)
		S.RECOVER:
			if _t >= (0.5 if _atk != "charge" and _atk != "spin" else 1.1):
				_enter(S.CHASE)

func _pick_attack(dist: float) -> String:
	var pool: Array = [["cleave", 3.0 if dist < 6.0 else 1.0], ["shockwave", 2.0], ["charge", 2.0 if dist > 5.0 else 0.8]]
	if phase >= 2:
		pool.append(["orbs", 2.0])
		var adds_alive := 0
		for a in _adds:
			if is_instance_valid(a) and a.is_alive():
				adds_alive += 1
		if adds_alive < 2 and _summon_cd <= 0.0:
			pool.append(["summon", 4.0])
	if phase >= 3:
		pool.append(["rifts", 3.0])
		pool.append(["spin", 1.6])
	var total := 0.0
	for e in pool:
		if String(e[0]) != _last_atk:
			total += float(e[1])
	var roll := randf() * total
	for e in pool:
		if String(e[0]) == _last_atk:
			continue
		roll -= float(e[1])
		if roll <= 0.0:
			return String(e[0])
	return "cleave"

func _begin_attack(name_: String) -> void:
	_atk = name_
	_last_atk = name_
	_hit_once = false
	_second_ring = false
	_enter(S.WINDUP)
	world.play_sfx("telegraph", -4.0, 0.6)

func _windup_time() -> float:
	match _atk:
		"cleave": return _wind(0.95)
		"shockwave": return _wind(1.15)
		"charge": return _wind(1.0)
		"orbs": return _wind(0.75)
		"summon": return 1.1
		"rifts": return 0.5
		"spin": return 0.7
	return 0.8

func _tick_windup(delta: float, pv: Vector3) -> void:
	var w := _windup_time()
	match _atk:
		"cleave":
			if _t < w * 0.3:
				_face(pv, 10.0, delta)
			elif _tele < 0:
				_tele = world.fx.telegraph(global_position, facing, "cone", 5.4, 150.0, w - _t)
		"shockwave":
			if _tele < 0:
				_tele = world.fx.telegraph(global_position, 0.0, "circle", 6.6, 360.0, w)
		"charge":
			if _t < w * 0.45:
				_face(pv, 12.0, delta)
			elif _tele < 0:
				_atk_dir = _forward()
				_tele = world.fx.telegraph(global_position, facing, "cone", 15.0, 14.0, w - _t)
		"orbs", "summon", "rifts":
			_face(pv, 6.0, delta)
		"spin":
			if _tele < 0:
				_tele = world.fx.telegraph(global_position, 0.0, "circle", 4.4, 360.0, w)
	if _t >= w:
		_cancel_tele()
		_fire_attack()

func _fire_attack() -> void:
	_hit_once = false
	match _atk:
		"cleave":
			_strike_cone(5.4, 150.0, dmg)
			world.camera_shake(0.5)
			_enter(S.ATTACK)
		"shockwave":
			_slam_hit(global_position, 6.6, dmg * 1.1, 10.0)
			_enter(S.ATTACK)
		"charge":
			_atk_dir = _forward()
			_enter(S.ATTACK)
		"orbs":
			_fire_ring(8 if phase < 3 else 12, 0.0)
			_enter(S.ATTACK)
		"summon":
			_do_summon()
			_enter(S.ATTACK)
		"rifts":
			_spawn_rifts()
			_enter(S.ATTACK)
		"spin":
			_spin_tick = 0.0
			_enter(S.ATTACK)

func _active_time() -> float:
	match _atk:
		"cleave": return 0.35
		"shockwave": return 0.4
		"charge": return 0.85
		"orbs": return 0.9
		"summon": return 0.5
		"rifts": return 0.6
		"spin": return 2.0
	return 0.4

func _tick_active(delta: float, pv: Vector3) -> void:
	match _atk:
		"charge":
			velocity = _atk_dir * 15.0
			var d := pv.length()
			if not _hit_once and d < hit_radius * 0.9 + world.player.hit_radius + 0.3:
				_hit_once = true
				world.player.take_damage(dmg * 1.2, global_position)
				world.player.apply_knock(_atk_dir * 9.0)
			var tile: Vector2i = world.data.world_to_tile(global_position + _atk_dir * 1.6)
			if not world.data.is_floor(tile.x, tile.y):
				world.camera_shake(0.6)
				world.fx.burst(global_position + _atk_dir * 1.2 + Vector3(0, 1, 0), Color(0.8, 0.7, 0.6), 16, 6.0, 1.2)
				world.play_sfx("hit", 0.0, 0.5)
				_cd = _cooldown_for_phase()
				_enter(S.RECOVER)
				_stun_t = 0.0
				return
		"orbs":
			if not _second_ring and _t >= 0.55:
				_second_ring = true
				_fire_ring(8 if phase < 3 else 12, PI / 8.0)
		"spin":
			_face(pv, 3.0, delta)
			_move_toward(world.player.global_position, _speed() * 0.6, delta)
			_spin_tick -= delta
			rig.rotation.y += delta * 14.0
			if _spin_tick <= 0.0:
				_spin_tick = 0.4
				world.fx.ring(global_position, 4.4, Color(1.0, 0.35, 0.5), 0.3)
				if pv.length() <= 4.4 + world.player.hit_radius:
					world.player.take_damage(dmg * 0.6, global_position)
	if _t >= _active_time():
		_cd = _cooldown_for_phase()
		_enter(S.RECOVER)

func _fire_ring(n: int, offset: float) -> void:
	world.play_sfx("enemy_shoot", -2.0, 0.6)
	for i in n:
		var a := offset + TAU * float(i) / float(n)
		var dv := Vector3(sin(a), 0, cos(a))
		var proj = world.get_projectile()
		if proj != null:
			proj.fire(global_position + dv * 1.4, dv, 6.5, dmg * 0.55, true, _gc(), 0.4, 4.5)

func _do_summon() -> void:
	_summon_cd = 18.0
	world.play_sfx("boss_roar", -4.0, 1.3)
	var kinds: Array = ["husk", "husk", "slinger"] if phase < 3 else ["spiderling", "spiderling", "spiderling"]
	var n := 0
	for k in kinds:
		var a := randf() * TAU
		var p := global_position + Vector3(cos(a), 0, sin(a)) * randf_range(5.0, 7.0)
		var e = world.spawn_enemy_at(String(k), p, room, level)
		if e != null:
			_adds.append(e)
			n += 1
	world.fx.ring(global_position, 7.0, _gc(), 0.6)

func _spawn_rifts() -> void:
	var pp: Vector3 = world.player.global_position
	for i in 6:
		var off := Vector3.ZERO if i == 0 else Vector3(randf_range(-6, 6), 0, randf_range(-6, 6))
		var pos := pp + off
		var tile: Vector2i = world.data.world_to_tile(pos)
		if not world.data.is_floor(tile.x, tile.y):
			pos = pp
		var delay := 0.15 * float(i)
		_rifts.append({"pos": pos, "t": -delay, "life": 1.15, "tele": -1})

func _tick_rifts(delta: float) -> void:
	if _rifts.is_empty() or world == null:
		return
	var keep: Array = []
	for r in _rifts:
		r["t"] += delta
		if r["t"] < 0.0:
			keep.append(r)
			continue
		if int(r["tele"]) < 0:
			r["tele"] = world.fx.telegraph(r["pos"], 0.0, "circle", 2.2, 360.0, float(r["life"]), _gc())
		if r["t"] >= float(r["life"]):
			world.fx.ring(r["pos"], 2.4, _gc(), 0.35)
			world.fx.burst(r["pos"] + Vector3(0, 0.4, 0), _gc(), 14, 6.0, 1.0)
			world.camera_shake(0.25)
			world.play_sfx("hit", -2.0, 0.6)
			var pl = world.player
			var dd := Vector2(pl.global_position.x - r["pos"].x, pl.global_position.z - r["pos"].z).length()
			if dd <= 2.2 + pl.hit_radius:
				pl.take_damage(dmg * 0.9, r["pos"])
		else:
			keep.append(r)
	_rifts = keep

func _die() -> void:
	_rifts.clear()
	for a in _adds:
		if is_instance_valid(a) and a.is_alive():
			a.no_drops = true
			a.take_hit(99999.0, global_position, false, 0.0, null)
	super._die()
	world.camera_shake(1.0)
	world.fx.ring(global_position, 10.0, Color(1.0, 0.8, 1.0), 1.0)
