class_name VCMission
extends Node3D
## Runs one dungeon: builds it from a seed, spawns everything, drives encounters, loot,
## objectives, checkpoints, saving, death/retry and completion. Actors talk to this node
## through the small "world" API (data, player, enemies, fx, get_projectile, ...).

signal ready_to_play
signal mission_completed
signal player_defeated

const HINTS := {
	"move": "Drag on the LEFT side of the screen to move. Reach the glowing marker.",
	"attack": "Hold ATTACK (bottom right). You auto-aim at nearby enemies.",
	"chest": "Walk up to the chest and tap the USE button when it appears.",
	"equip": "Tap the backpack icon (top right), select the new weapon and tap EQUIP.",
	"dodge": "Tap ROLL to dodge. You cannot be hurt for a moment mid-roll.",
	"clear": "Enemies show a red warning before they strike. Roll through it! Try VOID NOVA too.",
	"exit": "The Void Gate is open. Step into it to finish.",
	"find": "Explore. Cracked, glowing walls hide secret rooms. Strike them to break through.",
	"boss": "Watch the red warnings. The Warden changes tactics as its health falls.",
}

var mission_id := "crypt"
var mission: Dictionary = {}
var seed_ := 0
var data: VCDungeonData
var builder: VCDungeonBuilder
var player: VCPlayer
var cam_rig: VCCameraRig
var fx: VCFx
var hud: VCHud
var touch: VCTouchControls
var enemies: Array = []
var breakables: Array = []
var pickups: Array = []
var interactables: Array = []
var run: Dictionary = {}
var counters: Dictionary = {"kills": 0, "chests": 0, "dodges": 0, "equips": 0, "marker": 0, "boss_room": 0, "boss": 0, "exit": 0}
var obj_index := 0
var rooms_state: Dictionary = {}
var checkpoint_room := 0
var gate: VCInteractable
var boss: VCBoss = null
var boss_state := "idle"
var exit_unlocked := false
var finished := false
var build_done := false
var elapsed := 0.0
var overlay_open := ""
var gained_xp := 0
var gained_coins := 0
var gained_items := 0
var levels_gained := 0
var broken_ids: Array = []
var opened_chests: Array = []
var opened_secrets: Array = []
var resumed := false
var floor_n := 1                        # Endless Delve depth
var fast_build := false                 # tests skip the per-step frame waits

var _loot_rng := RandomNumberGenerator.new()
var _projectiles: Array = []
var _enemy_root: Node3D
var _pickup_root: Node3D
var _prop_root: Node3D
var _proj_root: Node3D
var _overlay: Node
var _ctl_layer: CanvasLayer
var _ui_layer: CanvasLayer
var _loader: VCLoadingOverlay
var _marker: Node3D
var _cutscene := 0.0
var _interact_target: VCInteractable = null
var _light_t := 0.0
var _last_room := -2
var _barriers: Dictionary = {}          # room id -> {"bodies": [], "vis": []}
var _mini_t := 0.0
var _autosave_t := 0.0
var _hint_shown: Dictionary = {}
var _defeat_shown := false
var _time := 0.0
var _resume_pause_pending := false
var _ctx_t := 0.0
var _env: WorldEnvironment
var _sun: DirectionalLight3D

# =========================================================================
# build
# =========================================================================
func _ready() -> void:
	name = "Mission"
	_loader = VCLoadingOverlay.new()
	add_child(_loader)
	await get_tree().process_frame
	await _build()

func _step(f: float, text: String) -> void:
	_loader.set_progress(f, text)
	if not fast_build:
		await get_tree().process_frame

func _build() -> void:
	var pend: Dictionary = VC.pending
	mission_id = String(pend.get("mission", "crypt"))
	mission = VCMissions.get_mission(mission_id)
	var resume: bool = bool(pend.get("resume", false)) and VC.has_run_in_progress() and String(VC.run.get("mission", "")) == mission_id
	resumed = resume
	run = VC.run.duplicate(true) if resume else {}
	floor_n = int(run.get("floor", pend.get("floor", 1))) if resume else int(pend.get("floor", 1))
	var want_seed := int(pend.get("seed", 0))
	if resume:
		want_seed = int(run["seed"])
	elif int(mission.get("fixed_seed", 0)) != 0:
		want_seed = int(mission["fixed_seed"])
	elif want_seed == 0:
		want_seed = int(Time.get_unix_time_from_system()) % 1000000 + 1
	VCSettings.load_settings()
	VCSettings.apply(get_viewport())
	await _step(0.08, "Carving the dungeon...")
	seed_ = want_seed
	var tries := 0
	while true:
		data = VCDungeonGenerator.generate(seed_, mission_id)
		var res := VCDungeonValidator.validate(data, 0)
		if res["ok"]:
			break
		tries += 1
		push_warning("VOIDCRAWL: seed %d invalid (%s), trying the next" % [seed_, str(res["errors"]).left(120)])
		seed_ += 1
		if tries > 25:
			push_error("could not generate a valid dungeon")
			break
	_loot_rng.seed = seed_ * 31 + 7
	var q := VCSettings.quality_profile()
	await _step(0.3, "Raising the walls...")
	_env = WorldEnvironment.new()
	_env.environment = VCEnv.make(q, false, String(mission.get("palette", "crypt")))
	add_child(_env)
	_sun = DirectionalLight3D.new()
	_sun.light_color = Color(0.7, 0.62, 0.95)
	_sun.light_energy = 0.42
	_sun.rotation_degrees = Vector3(-58.0, -25.0, 0.0)
	_sun.shadow_enabled = bool(q["shadows"])
	add_child(_sun)
	builder = VCDungeonBuilder.new()
	add_child(builder)
	await builder.build(data, q, Callable() if fast_build else func(): await get_tree().process_frame)
	await _step(0.55, "Lighting the torches...")
	_enemy_root = Node3D.new(); _enemy_root.name = "Enemies"; add_child(_enemy_root)
	_pickup_root = Node3D.new(); _pickup_root.name = "Pickups"; add_child(_pickup_root)
	_prop_root = Node3D.new(); _prop_root.name = "Props"; add_child(_prop_root)
	_proj_root = Node3D.new(); _proj_root.name = "Projectiles"; add_child(_proj_root)
	fx = VCFx.new()
	fx.world = self
	add_child(fx)
	fx.configure(q)
	for i in 36:
		var pr := VCProjectile.new()
		pr.world = self
		_proj_root.add_child(pr)
		_projectiles.append(pr)
	player = VCPlayer.new()
	player.world = self
	add_child(player)
	player.bind(VC.profile)
	var dust := CPUParticles3D.new()
	dust.amount = maxi(6, int(28.0 * float(q["particles"])))
	dust.lifetime = 5.0
	dust.local_coords = false
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(9, 1.6, 7)
	dust.position = Vector3(0, 1.6, 0)
	dust.direction = Vector3(0.3, 1, 0.2)
	dust.initial_velocity_min = 0.08
	dust.initial_velocity_max = 0.3
	dust.gravity = Vector3.ZERO
	var dq := QuadMesh.new()
	dq.size = Vector2(0.07, 0.07)
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.albedo_color = Color(0.8, 0.65, 1.0, 0.55)
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	dq.material = dm
	dust.mesh = dq
	player.add_child(dust)
	player.died.connect(_on_player_died)
	player.dodged.connect(func(): counters["dodges"] += 1; _update_objectives())
	cam_rig = VCCameraRig.new()
	add_child(cam_rig)
	cam_rig.target = player
	_ui_layer = CanvasLayer.new()
	_ui_layer.layer = 10
	add_child(_ui_layer)
	hud = VCHud.new()
	add_child(hud)
	hud.bind_player(player)
	hud.setup_minimap(data, _decode_explored(String(run.get("explored", ""))))
	_ctl_layer = CanvasLayer.new()
	_ctl_layer.layer = 11
	add_child(_ctl_layer)
	touch = VCTouchControls.new()
	touch.player = player
	_ctl_layer.add_child(touch)
	touch.pause_pressed.connect(func(): open_overlay("pause"))
	touch.inventory_pressed.connect(func(): open_overlay("pack"))
	await _step(0.8, "Waking the dead...")
	_restore_run_state()
	await _step(0.85, "Placing treasure...")
	_spawn_world_objects()
	_place_player()
	cam_rig.snap_to(player.global_position)
	cam_rig.yaw = 0.0
	_update_objectives()
	VC.profile.stats["deaths"] = int(VC.profile.stats["deaths"])
	await _step(1.0, "Enter the void.")
	_loader.queue_free()
	_loader = null
	build_done = true
	VC.play_music("dungeon")
	hud.set_seed_text("%s%s  |  seed %d" % [String(mission["name"]), ("  floor %d" % floor_n) if bool(mission.get("endless", false)) else "", seed_])
	var bn := String(mission["name"]).to_upper()
	if bool(mission.get("endless", false)):
		bn = "DELVE  -  FLOOR %d" % floor_n
	hud.banner(bn, String(mission["biome"]), VCDefs.COL_VIOLET, 3.2)
	_save_run()
	ready_to_play.emit()

func _decode_explored(b64: String) -> PackedByteArray:
	if b64 == "":
		return PackedByteArray()
	var raw := Marshalls.base64_to_raw(b64)
	if raw.size() < 4:
		return PackedByteArray()
	var n := raw.decode_u32(0)
	return raw.slice(4).decompress(n, FileAccess.COMPRESSION_DEFLATE)

func _encode_explored() -> String:
	var m := hud.explored_mask()
	if m.is_empty():
		return ""
	var comp := m.compress(FileAccess.COMPRESSION_DEFLATE)
	var out := PackedByteArray()
	out.resize(4)
	out.encode_u32(0, m.size())
	out.append_array(comp)
	return Marshalls.raw_to_base64(out)

func _restore_run_state() -> void:
	for r in data.rooms:
		rooms_state[int(r["id"])] = {"state": "idle", "wave": 0, "alive": 0, "next_wave_at": -1.0}
	if not resumed:
		checkpoint_room = 0
		return
	checkpoint_room = int(run.get("checkpoint_room", 0))
	for rid in run.get("cleared", []):
		if rooms_state.has(int(rid)):
			rooms_state[int(rid)]["state"] = "cleared"
	opened_chests = (run.get("chests", []) as Array).duplicate()
	broken_ids = (run.get("broken", []) as Array).duplicate()
	opened_secrets = (run.get("secrets", []) as Array).duplicate()
	var c: Dictionary = run.get("counters", {})
	for k in counters:
		if c.has(k):
			counters[k] = int(c[k])
	obj_index = int(run.get("obj_index", 0))
	elapsed = float(run.get("elapsed", 0.0))
	if String(run.get("boss_state", "idle")) == "dead":
		boss_state = "dead"
	for sid in opened_secrets:
		builder.open_secret(String(sid))

func _place_player() -> void:
	var p := _checkpoint_pos()
	player.global_position = p
	player.revive_at(p)
	player.hp = float(player.max_hp) if not resumed else minf(float(player.max_hp), maxf(player.hp, float(player.max_hp) * 0.6))
	hud.reveal(data.world_to_tile(p))
	_last_room = -2

func _checkpoint_pos() -> Vector3:
	var t := data.start_tile
	if checkpoint_room > 0 and checkpoint_room < data.rooms.size():
		var r: Dictionary = data.rooms[checkpoint_room]
		t = data.nearest_floor((r["center"] as Vector2i) + Vector2i(0, 3))
	return data.tile_to_world(t)

# -------------------------------------------------------------- world objects
func _spawn_world_objects() -> void:
	# chests
	for ch in data.chests:
		var it := VCInteractable.new()
		it.world = self
		it.id = String(ch["id"])
		it.room = int(ch["room"])
		_prop_root.add_child(it)
		it.build_chest(int(ch["tier"]))
		it.position = data.tile_to_world(ch["tile"])
		var rc: Vector2i = data.rooms[int(ch["room"])]["center"]
		var toward := data.tile_to_world(rc) - it.position
		it.rotation.y = atan2(-toward.x, -toward.z) if toward.length() > 0.5 else 0.0
		it.activated.connect(_on_chest_opened)
		if opened_chests.has(it.id):
			it.used = true
			it._lid.rotation.x = -1.9
		interactables.append(it)
	# shrines (every checkpoint except the entrance)
	for cp in data.checkpoints:
		if String(cp["id"]) == "cp_start":
			continue
		var sh := VCInteractable.new()
		sh.world = self
		sh.id = String(cp["id"])
		sh.room = int(cp["room"])
		_prop_root.add_child(sh)
		sh.build_shrine()
		sh.position = data.tile_to_world(cp["tile"])
		sh.activated.connect(_on_shrine_used)
		if checkpoint_room == sh.room and resumed:
			sh.used = true
			sh._set_shrine_glow(true)
		interactables.append(sh)
	# exit gate
	gate = VCInteractable.new()
	gate.world = self
	gate.id = "gate"
	_prop_root.add_child(gate)
	gate.build_gate()
	gate.position = data.tile_to_world(data.exit_tile)
	gate.activated.connect(_on_gate_used)
	interactables.append(gate)
	# breakable props
	for pr in data.props:
		if broken_ids.has(String(pr["id"])):
			continue
		var b := VCBreakable.new()
		b.world = self
		b.prop_id = String(pr["id"])
		b.room = int(pr["room"])
		_prop_root.add_child(b)
		b.setup(String(pr["kind"]), 1.0, 0.8)
		b.position = data.tile_to_world(pr["tile"])
		b.rotation.y = float(hash(pr["id"]) % 628) / 100.0
		b.broken.connect(_on_prop_broken)
		breakables.append(b)
	# secret walls
	for sid in builder.secrets:
		var sd: Dictionary = builder.secrets[sid]
		var sb := VCBreakable.new()
		sb.world = self
		sb.secret_id = String(sid)
		_prop_root.add_child(sb)
		sb.setup("secret", 3.0, 2.3)
		sb.position = sd["center"]
		sb.broken.connect(_on_secret_broken)
		breakables.append(sb)
	# tutorial extras
	if mission_id == "tutorial":
		_make_marker()
		if int(counters["kills"]) < 1:
			_spawn_enemy_at_tile(VCDefs.ENEMY_HUSK, data.rooms[0]["center"] + Vector2i(5, -2), 0, 1, 1.4)
	_check_gate_unlock()

func _make_marker() -> void:
	if int(counters["marker"]) >= 1:
		return
	_marker = Node3D.new()
	_marker.position = data.tile_to_world(data.marker_tile)
	add_child(_marker)
	var beam := MeshInstance3D.new()
	beam.mesh = VCMats.box(Vector3(0.5, 6.0, 0.5))
	beam.material_override = VCMats.fx(Color(0.6, 0.35, 1.0, 0.4), true)
	beam.position = Vector3(0, 3.0, 0)
	_marker.add_child(beam)
	var disc := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.6
	cyl.bottom_radius = 1.6
	cyl.height = 0.05
	disc.mesh = cyl
	disc.material_override = VCMats.fx(Color(0.55, 0.3, 1.0, 0.45), true)
	disc.position = Vector3(0, 0.1, 0)
	_marker.add_child(disc)
	var l := OmniLight3D.new()
	l.light_color = Color(0.7, 0.4, 1.0)
	l.light_energy = 1.4
	l.omni_range = 6.0
	l.position = Vector3(0, 1.5, 0)
	_marker.add_child(l)

# =========================================================================
# world API used by actors
# =========================================================================
func is_player_controllable() -> bool:
	return build_done and overlay_open == "" and not finished and _cutscene <= 0.0 and player.is_alive()

func play_sfx(n: String, vol: float = 0.0, pitch: float = 1.0) -> void:
	VC.play_sfx(n, vol, pitch)

func camera_shake(a: float) -> void:
	if cam_rig != null:
		cam_rig.shake(a)

func get_projectile() -> VCProjectile:
	for p in _projectiles:
		if not p.active:
			return p
	return null

func on_player_hit(target: Node, dealt: float, crit: bool) -> void:
	var col := Color(1.0, 0.82, 0.3) if crit else Color(1, 1, 1)
	fx.number(target.global_position, ("%d!" % int(dealt)) if crit else str(int(dealt)), col, crit)
	play_sfx("crit" if crit else "hit", -2.0, randf_range(0.92, 1.1))
	fx.burst(target.global_position + Vector3(0, 1.0, 0), Color(0.85, 0.6, 1.0), 12 if crit else 6, 4.0, 0.9)
	VC.vibrate(18 if crit else 8)

func on_player_hurt(_dmg: float) -> void:
	hud.flash_damage()

func spawn_enemy_at(type: String, pos: Vector3, room: int, level: int) -> VCEnemy:
	var t := data.world_to_tile(pos)
	if not data.is_floor(t.x, t.y):
		t = data.nearest_floor(t)
	return _spawn_enemy_at_tile(type, t, room, level, 0.7)

func _spawn_enemy_at_tile(type: String, tile: Vector2i, room: int, level: int, delay: float) -> VCEnemy:
	var e: VCEnemy
	if type == "warden" or type == "colossus":
		e = VCBoss.new()
	else:
		e = VCEnemy.new()
	e.world = self
	e.setup(type, level, room)
	e._spawn_delay = delay
	_enemy_root.add_child(e)
	e.global_position = data.tile_to_world(tile)
	e.facing = randf() * TAU
	e.killed.connect(_on_enemy_killed)
	enemies.append(e)
	fx.spawn_pillar(e.global_position, delay + 0.2)
	return e

func _enemy_level(room: int) -> int:
	var base := int(mission.get("recommended_level", 1))
	if mission_id == "tutorial":
		return 1
	base += maxi(floor_n - 1, 0)
	var depth := int(data.rooms[room]["depth"]) if room >= 0 and room < data.rooms.size() else 0
	return maxi(1, base + depth / 3)

# =========================================================================
# per-frame
# =========================================================================
func _process(delta: float) -> void:
	if not build_done:
		return
	_time += delta
	_update_fade_uniforms()
	_light_t -= delta
	if _light_t <= 0.0:
		_light_t = 0.25
		builder.update_lights(player.global_position, int(VCSettings.quality_profile()["max_lights"]), _time)
	if builder != null:
		# flicker is cheap but only needs to run on the few visible lights
		builder.update_lights(player.global_position, int(VCSettings.quality_profile()["max_lights"]), _time) if int(_time * 10.0) % 3 == 0 else null

func _update_fade_uniforms() -> void:
	var cam := cam_rig.cam
	if cam == null or not cam.is_inside_tree():
		return
	var vp := get_viewport().get_visible_rect().size
	var p := player.global_position + Vector3(0, 1.0, 0)
	if cam.is_position_behind(p):
		return
	var sp := cam.unproject_position(p)
	var depth := -(cam.global_transform.affine_inverse() * p).z
	var m: ShaderMaterial = builder.wall_mat
	m.set_shader_parameter("player_screen", Vector2(sp.x / vp.x, sp.y / vp.y))
	m.set_shader_parameter("player_depth", depth)
	m.set_shader_parameter("aspect", vp.x / vp.y)
	m.set_shader_parameter("fade_radius", 0.13 * clampf(13.5 / maxf(depth, 4.0), 0.7, 1.4))

func _physics_process(delta: float) -> void:
	if not build_done or finished:
		return
	elapsed += delta
	VC.profile.stats["playtime"] = float(VC.profile.stats["playtime"]) + delta
	player.cam_yaw = cam_rig.yaw
	if _cutscene > 0.0:
		_cutscene -= delta
		if _cutscene <= 0.0:
			cam_rig.release_focus()
	if overlay_open == "":
		if VCInput.take("pause"):
			open_overlay("pause")
		elif VCInput.take("inventory"):
			open_overlay("pack")
	_tick_pickups_cap()
	if player.is_alive():
		_tick_exploration(delta)
		_tick_encounters()
		_tick_interaction()
		_tick_marker()
		_tick_gate()
	_autosave_t += delta
	touch.active = overlay_open == "" and not finished
	if overlay_open != "":
		touch.release_all()

func _tick_exploration(delta: float) -> void:
	_ctx_t -= delta
	if _ctx_t <= 0.0:
		_ctx_t = 1.0
		VCCrashGuard.context = "%s seed=%d room=%d enemies=%d pickups=%d proj=%d hp=%d" % [mission_id, seed_, _last_room, enemies.size(), pickups.size(), _projectiles.size(), int(player.hp)]
	_mini_t -= delta
	if _mini_t <= 0.0:
		_mini_t = 0.2
		hud.reveal(data.world_to_tile(player.global_position))
		for ch in data.chests:
			pass
	var rid := data.room_at(data.world_to_tile(player.global_position))
	if rid != _last_room:
		_last_room = rid
		if rid >= 0:
			_on_enter_room(rid)

func _on_enter_room(rid: int) -> void:
	var r: Dictionary = data.rooms[rid]
	var st: Dictionary = rooms_state[rid]
	if bool(st.get("seen", false)):
		return
	st["seen"] = true
	match String(r["type"]):
		"treasure":
			if bool(r["secret"]):
				hud.banner("SECRET FOUND", "A hidden vault", VCDefs.COL_COIN, 2.6)
				play_sfx("checkpoint")
			else:
				hud.toast("Treasure vault", VCDefs.COL_COIN)
		"checkpoint":
			hud.toast("A quiet shrine glows ahead", Color(0.5, 0.85, 1.0))

# ----------------------------------------------------------------- encounters
func _in_room_inner(rid: int, pt: Vector2i) -> bool:
	var r: Dictionary = data.rooms[rid]
	var c: Vector2i = r["center"]
	var half: int = int(r["size"]) / 2
	return absi(pt.x - c.x) <= half - 2 and absi(pt.y - c.y) <= half - 2

func _tick_encounters() -> void:
	var pt := data.world_to_tile(player.global_position)
	var rid := data.room_at(pt)
	if rid >= 0 and _in_room_inner(rid, pt):
		var st: Dictionary = rooms_state[rid]
		var r: Dictionary = data.rooms[rid]
		if String(r["type"]) == "boss":
			if boss_state == "idle":
				_start_boss(rid)
		elif String(st["state"]) == "idle":
			var enc: Dictionary = r.get("encounter", {})
			if not enc.is_empty() and not bool(enc.get("manual", false)) and not (enc["waves"] as Array).is_empty():
				_start_encounter(rid)
	# staged waves
	for key in rooms_state:
		var st2: Dictionary = rooms_state[key]
		if String(st2["state"]) == "active" and float(st2["next_wave_at"]) > 0.0 and elapsed >= float(st2["next_wave_at"]):
			st2["next_wave_at"] = -1.0
			_spawn_wave(int(key), int(st2["wave"]))

func _start_encounter(rid: int) -> void:
	var st: Dictionary = rooms_state[rid]
	st["state"] = "active"
	st["wave"] = 0
	var enc: Dictionary = data.rooms[rid]["encounter"]
	if bool(enc.get("lock", true)):
		_set_barriers(rid, true)
	_spawn_wave(rid, 0)
	hud.toast("Defeat the enemies to open the doors", Color(1.0, 0.6, 0.7))

func _spawn_wave(rid: int, w: int) -> void:
	var st: Dictionary = rooms_state[rid]
	var wave: Array = data.rooms[rid]["encounter"]["waves"][w]
	st["wave"] = w
	st["alive"] = wave.size()
	var lvl := _enemy_level(rid)
	var i := 0
	for ent in wave:
		var e := _spawn_enemy_at_tile(String(ent["type"]), ent["tile"], rid, lvl, 0.6 + 0.14 * float(i))
		e.set_meta("counted", true)
		i += 1
	if w > 0:
		hud.toast("More enemies!", Color(1.0, 0.6, 0.7))

func _on_enemy_killed(e: VCEnemy) -> void:
	enemies.erase(e)
	counters["kills"] += 1
	VC.profile.stats["kills"] = int(VC.profile.stats["kills"]) + 1
	if not e.no_drops:
		_grant_enemy_rewards(e)
	if e.is_boss:
		_on_boss_killed(e)
	elif bool(e.get_meta("counted", false)):
		var st: Dictionary = rooms_state[e.room]
		st["alive"] = int(st["alive"]) - 1
		if int(st["alive"]) <= 0 and String(st["state"]) == "active":
			var waves: Array = data.rooms[e.room]["encounter"]["waves"]
			if int(st["wave"]) + 1 < waves.size():
				st["wave"] = int(st["wave"]) + 1
				st["next_wave_at"] = elapsed + 1.3
			else:
				_clear_room(e.room)
	_update_objectives()

func _clear_room(rid: int) -> void:
	var st: Dictionary = rooms_state[rid]
	st["state"] = "cleared"
	_set_barriers(rid, false)
	hud.toast("Room cleared", VCDefs.COL_GOOD)
	play_sfx("checkpoint", -4.0)
	VC.profile.coins += 0
	if not (run.get("cleared", []) as Array).has(rid):
		if not run.has("cleared"):
			run["cleared"] = []
		(run["cleared"] as Array).append(rid)
	_check_gate_unlock()
	_save_run()

func _grant_enemy_rewards(e: VCEnemy) -> void:
	var d: Dictionary = e.def
	var pos := e.global_position
	var xp := int(round(float(d["xp"]) * VCEnemyDefs.xp_scale(e.level)))
	_grant_xp(xp, pos)
	var coin_range: Array = d["coins"]
	var n := _loot_rng.randi_range(int(coin_range[0]), int(coin_range[1]))
	n = int(round(float(n) * float(player.stats["coin_mult"])))
	if n > 0:
		_drop_coins(pos, n)
	var lucky := _loot_rng.randf()
	if lucky < float(d["item_chance"]) or e.is_boss:
		var count := 1 if not e.is_boss else 3
		for k in count:
			var rarity := -1
			if e.is_boss:
				rarity = VCDefs.Rarity.EPIC if k == 0 else (VCDefs.Rarity.RARE if k == 1 else -1)
			elif String(d["ai"]) == "slam":
				rarity = maxi(VCDefs.Rarity.UNCOMMON, VCItems.roll_rarity(_loot_rng, 0.3))
			var it := VCItems.generate(_loot_rng, e.level + (1 if e.is_boss else 0), rarity, -1, 0.0, VC.profile.alloc_uid())
			_drop_item(pos, it)
	if _loot_rng.randf() < float(d["potion_chance"]) * 1.6:
		_drop_potion(pos)
	if _loot_rng.randf() < (0.35 if String(d["ai"]) == "slam" else 0.05):
		_drop_bomb(pos)
	var hurt := 1.0 - player.hp / float(player.max_hp)
	if _loot_rng.randf() < 0.14 + 0.45 * hurt:
		_drop_heart(pos)

func _grant_xp(amount: int, pos: Vector3) -> void:
	if amount <= 0:
		return
	gained_xp += amount
	fx.number(pos + Vector3(0, 0.8, 0), "+%d XP" % amount, VCDefs.COL_VIOLET, false)
	var gained := VC.profile.add_xp(amount)
	if gained > 0:
		levels_gained += gained
		player.refresh_stats(false)
		player.heal(float(player.max_hp) * 0.4, true)
		play_sfx("levelup")
		fx.ring(player.global_position, 4.0, Color(1.0, 0.85, 0.4), 0.7)
		fx.burst(player.global_position + Vector3(0, 1, 0), Color(1.0, 0.85, 0.4), 24, 6.0, 1.2)
		hud.banner("LEVEL UP", "Level %d  -  %d points to spend (open HERO)" % [VC.profile.level, VC.profile.attr_points], VCDefs.COL_COIN, 3.0)
		_save_run()

func _drop_coins(pos: Vector3, total: int) -> void:
	var pieces := clampi(int(ceil(float(total) / 4.0)), 1, 5)
	var per := maxi(1, total / pieces)
	var left := total
	for i in pieces:
		var amt := per if i < pieces - 1 else left
		left -= amt
		if amt <= 0:
			continue
		var p := VCPickup.new()
		p.world = self
		_pickup_root.add_child(p)
		p.setup_coin(amt)
		p.toss(pos)
		pickups.append(p)

func _drop_item(pos: Vector3, it: Dictionary) -> void:
	var p := VCPickup.new()
	p.world = self
	_pickup_root.add_child(p)
	p.setup_item(it)
	p.toss(pos)
	pickups.append(p)
	if int(it["rarity"]) >= VCDefs.Rarity.RARE:
		play_sfx("pickup", -2.0, 0.8)

func _drop_bomb(pos: Vector3) -> void:
	var p := VCPickup.new()
	p.world = self
	_pickup_root.add_child(p)
	p.setup_bomb()
	p.toss(pos)
	pickups.append(p)

func _drop_heart(pos: Vector3) -> void:
	var p := VCPickup.new()
	p.world = self
	_pickup_root.add_child(p)
	p.setup_heart()
	p.toss(pos)
	pickups.append(p)

func _drop_potion(pos: Vector3) -> void:
	var p := VCPickup.new()
	p.world = self
	_pickup_root.add_child(p)
	p.setup_potion()
	p.toss(pos)
	pickups.append(p)

func collect_pickup(p: VCPickup) -> void:
	if p.collected:
		return
	var prof: VCProfile = VC.profile
	match p.kind:
		VCPickup.Kind.COIN:
			prof.coins += p.amount
			gained_coins += p.amount
			play_sfx("coin", -6.0, randf_range(0.95, 1.15))
			fx.number(p.global_position, "+%d" % p.amount, VCDefs.COL_COIN, false)
		VCPickup.Kind.POTION:
			if prof.potions >= VCProfile.MAX_POTIONS:
				return                       # leave it on the floor until there is room
			prof.potions += 1
			play_sfx("pickup", -3.0)
			hud.toast("Health potion  (%d/%d)" % [prof.potions, VCProfile.MAX_POTIONS], VCDefs.COL_HP)
		VCPickup.Kind.BOMB:
			if prof.bombs >= VCProfile.MAX_BOMBS:
				return
			prof.bombs += 1
			play_sfx("pickup", -3.0, 0.8)
			hud.toast("Void bomb  (%d/%d)" % [prof.bombs, VCProfile.MAX_BOMBS], Color(1.0, 0.7, 0.35))
		VCPickup.Kind.HEART:
			if player.hp >= float(player.max_hp) - 0.5:
				return                       # keep it for when you need it
			player.heal(float(player.max_hp) * 0.18)
			play_sfx("heal", -4.0, 1.3)
			fx.burst(player.global_position + Vector3(0, 1.0, 0), VCDefs.COL_GOOD, 8, 2.5, 0.8)
		VCPickup.Kind.ITEM:
			var it: Dictionary = p.item
			if prof.add_item(it):
				prof.stats["items_found"] = int(prof.stats["items_found"]) + 1
				gained_items += 1
				play_sfx("pickup")
				var better := _is_upgrade(it)
				hud.toast("%s%s" % [String(it["name"]), "   (upgrade!)" if better else ""], VCDefs.rarity_color(int(it["rarity"])))
			else:
				var v := VCItems.sell_value(it)
				prof.coins += v
				hud.toast("Pack full - sold %s for %d" % [String(it["name"]), v], VCDefs.COL_TEXT_DIM)
	p.collected = true
	pickups.erase(p)
	p.queue_free()
	VC.notify_profile_changed()

func _is_upgrade(it: Dictionary) -> bool:
	var cur: Dictionary = VC.profile.equipment.get(int(it["slot"]), {})
	return VCItems.score(it) > VCItems.score(cur) + 0.5

func _tick_pickups_cap() -> void:
	if pickups.size() > 70:
		for p in pickups.duplicate():
			if p.kind == VCPickup.Kind.COIN and pickups.size() > 60:
				collect_pickup(p)

# ---------------------------------------------------------------- barriers
func _set_barriers(rid: int, on: bool) -> void:
	if not _barriers.has(rid):
		_barriers[rid] = _make_barriers(rid)
	var b: Dictionary = _barriers[rid]
	for body in b["bodies"]:
		(body as StaticBody3D).collision_layer = VCDefs.L_WORLD if on else 0
	for v in b["vis"]:
		(v as Node3D).visible = on
	play_sfx("door", -2.0)
	camera_shake(0.2)

func _make_barriers(rid: int) -> Dictionary:
	var r: Dictionary = data.rooms[rid]
	var bodies: Array = []
	var vis: Array = []
	for side in VCDungeonGenerator.SIDES:
		if not r["doors"][side]:
			continue
		var tiles: Array = VCDungeonGenerator.door_tiles(r, side)
		var c := Vector3.ZERO
		for t in tiles:
			c += data.tile_to_world(t)
		c /= float(tiles.size())
		var horizontal: bool = side == "N" or side == "S"
		var size := Vector3(VCDefs.TILE * 3.0, VCDefs.WALL_H, VCDefs.TILE * 0.6) if horizontal else Vector3(VCDefs.TILE * 0.6, VCDefs.WALL_H, VCDefs.TILE * 3.0)
		var body := StaticBody3D.new()
		body.collision_layer = 0
		body.collision_mask = 0
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		cs.position = Vector3(0, VCDefs.WALL_H * 0.5, 0)
		body.add_child(cs)
		body.position = c
		add_child(body)
		bodies.append(body)
		var mi := MeshInstance3D.new()
		mi.mesh = VCMats.box(size * Vector3(0.9, 0.95, 0.9))
		mi.material_override = VCMats.fx(Color(0.55, 0.22, 1.0, 0.38), true)
		mi.position = c + Vector3(0, VCDefs.WALL_H * 0.5, 0)
		mi.visible = false
		add_child(mi)
		vis.append(mi)
	return {"bodies": bodies, "vis": vis}

# ----------------------------------------------------------------------- boss
func _start_boss(rid: int) -> void:
	boss_state = "active"
	counters["boss_room"] = 1
	_set_barriers(rid, true)
	var c: Vector2i = data.rooms[rid]["center"]
	boss = _spawn_enemy_at_tile(_boss_type(), c + Vector2i(0, -5), rid, _enemy_level(rid) + 1, 1.8) as VCBoss
	boss.phase_changed.connect(_on_boss_phase)
	hud.show_boss(boss)
	var is_col := _boss_type() == "colossus"
	hud.banner("THE ASHEN COLOSSUS" if is_col else String(mission.get("boss_title", "THE HOLLOW WARDEN")), String(mission.get("boss_sub", "Guardian of the Void Gate")), Color(1.0, 0.65, 0.4) if is_col else Color(1.0, 0.7, 1.0), 3.4)
	play_sfx("boss_roar")
	camera_shake(0.7)
	VC.play_music("boss")
	cam_rig.focus_on(data.tile_to_world(c + Vector2i(0, -3)))
	_cutscene = 2.4
	_update_objectives()
	_save_run()

func _boss_type() -> String:
	var b := String(mission.get("boss", "warden"))
	if b == "alternate":
		return "colossus" if floor_n % 2 == 0 else "warden"
	return b

func _on_boss_phase(phase: int) -> void:
	if phase == 2:
		hud.banner("PHASE II", "The Warden calls its servants", Color(1.0, 0.7, 1.0), 2.4)
	else:
		hud.banner("PHASE III", "The Warden's fury awakens", Color(1.0, 0.45, 0.6), 2.4)

func _on_boss_killed(_e: VCEnemy) -> void:
	boss_state = "dead"
	counters["boss"] = 1
	VC.profile.stats["bosses"] = int(VC.profile.stats["bosses"]) + 1
	hud.hide_boss()
	hud.banner("THE WARDEN FALLS", "The Void Gate stirs...", VCDefs.COL_COIN, 3.5)
	_set_barriers(boss.room, false)
	VC.play_music("dungeon")
	play_sfx("victory")
	_check_gate_unlock()
	_save_run()

# ---------------------------------------------------------------- interaction
func _tick_interaction() -> void:
	var best: VCInteractable = null
	var best_d := 1e9
	for it in interactables:
		if not (it as VCInteractable).can_interact() or it.kind == "gate":
			continue
		var d := Vector2(it.global_position.x - player.global_position.x, it.global_position.z - player.global_position.z).length()
		if d <= it.reach and d < best_d:
			best = it
			best_d = d
	_interact_target = best
	touch.interact_prompt = best.prompt if best != null else ""
	if VCInput.take("interact") and best != null and is_player_controllable():
		best.interact(player)

func _tick_marker() -> void:
	if _marker == null or int(counters["marker"]) >= 1:
		return
	var d := Vector2(_marker.global_position.x - player.global_position.x, _marker.global_position.z - player.global_position.z).length()
	if d < 2.2:
		counters["marker"] = 1
		_marker.queue_free()
		_marker = null
		play_sfx("checkpoint")
		_update_objectives()

func _tick_gate() -> void:
	if gate == null or not gate.enabled or finished:
		return
	var d := Vector2(gate.global_position.x - player.global_position.x, gate.global_position.z - player.global_position.z).length()
	if d < 1.7:
		gate.interact(player)

func _check_gate_unlock() -> void:
	var unlocked := false
	if mission_id == "tutorial":
		unlocked = String(rooms_state.get(2, {}).get("state", "")) == "cleared"
	else:
		unlocked = boss_state == "dead"
	exit_unlocked = unlocked
	if gate != null:
		if unlocked and not gate.enabled:
			play_sfx("door")
			hud.toast("The Void Gate opens", Color(0.8, 0.55, 1.0))
		gate.set_gate_enabled(unlocked)

func _on_chest_opened(ch: VCInteractable) -> void:
	counters["chests"] += 1
	VC.profile.stats["chests"] = int(VC.profile.stats["chests"]) + 1
	opened_chests.append(ch.id)
	play_sfx("chest")
	fx.burst(ch.global_position + Vector3(0, 1.0, 0), Color(1.0, 0.8, 0.4), 22, 5.0, 1.1)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_ * 131 + hash(ch.id)
	var lvl := _enemy_level(ch.room) + 1
	var items: Array = []
	if mission_id == "tutorial":
		items.append(VCItems.generate(rng, 2, VCDefs.Rarity.RARE, VCDefs.Slot.WEAPON, 0.0, VC.profile.alloc_uid(), "gloomaxe"))
		items.append(VCItems.generate(rng, 1, VCDefs.Rarity.UNCOMMON, VCDefs.Slot.HELM, 0.0, VC.profile.alloc_uid()))
	else:
		var n := 3 if ch.tier >= 2 else 2
		for k in n:
			var min_r := VCDefs.Rarity.RARE if (ch.tier >= 2 and k == 0) else VCDefs.Rarity.UNCOMMON
			var rr := maxi(min_r, VCItems.roll_rarity(rng, 0.5))
			items.append(VCItems.generate(rng, lvl, rr, -1, 0.0, VC.profile.alloc_uid()))
	for it in items:
		_drop_item(ch.global_position + Vector3(0, 0.5, 0), it)
	_drop_coins(ch.global_position, int(rng.randi_range(18, 34) * ch.tier))
	hud.toast("Chest opened!", VCDefs.COL_COIN)
	_update_objectives()
	_save_run()

func _on_shrine_used(sh: VCInteractable) -> void:
	var first := checkpoint_room != sh.room
	checkpoint_room = sh.room
	player.heal(float(player.max_hp), true)
	VC.profile.potions = VCProfile.MAX_POTIONS
	VC.profile.bombs = maxi(VC.profile.bombs, 3)
	play_sfx("checkpoint")
	fx.ring(sh.global_position, 3.5, Color(0.5, 0.85, 1.0), 0.8)
	fx.burst(sh.global_position + Vector3(0, 1.5, 0), Color(0.5, 0.85, 1.0), 20, 4.0, 1.0)
	hud.toast("Checkpoint reached - health and potions restored" if first else "You rest at the shrine", Color(0.55, 0.88, 1.0))
	_save_run()

func _on_gate_used(_g: VCInteractable) -> void:
	if finished or not exit_unlocked:
		return
	# every objective before the exit must be done (matters for the tutorial)
	var objs: Array = mission["objectives"]
	for i in range(objs.size() - 1):
		if not _obj_met(i):
			if not bool(_hint_shown.get("gate_early", false)) or int(Time.get_ticks_msec() / 1500) % 2 == 0:
				hud.toast("Finish your training first: %s" % _obj_text(i), Color(1.0, 0.75, 0.4))
			_hint_shown["gate_early"] = true
			player.apply_knock(Vector3(0, 0, 4.0).rotated(Vector3.UP, cam_rig.yaw))
			return
	counters["exit"] = 1
	_update_objectives()

func _on_prop_broken(b: VCBreakable) -> void:
	breakables.erase(b)
	if b.prop_id != "":
		broken_ids.append(b.prop_id)
	var roll := _loot_rng.randf()
	if roll < 0.45:
		_drop_coins(b.global_position, _loot_rng.randi_range(2, 7))
	elif roll < 0.58:
		_drop_heart(b.global_position)
	elif roll < 0.64:
		_drop_potion(b.global_position)
	elif roll < 0.69:
		_drop_bomb(b.global_position)
	b.queue_free()

func _on_secret_broken(b: VCBreakable) -> void:
	breakables.erase(b)
	opened_secrets.append(b.secret_id)
	var c := builder.open_secret(b.secret_id)
	fx.burst(c + Vector3(0, 1.2, 0), Color(0.8, 0.5, 1.0), 30, 7.0, 1.3)
	fx.ring(c, 4.0, Color(0.8, 0.5, 1.0), 0.6)
	camera_shake(0.5)
	hud.banner("A HIDDEN PASSAGE OPENS", "", VCDefs.COL_VIOLET, 2.2)
	play_sfx("door")
	b.queue_free()
	_save_run()

# --------------------------------------------------------------- objectives
func _objs() -> Array:
	return mission["objectives"]

func _counter_key(type: String) -> String:
	match type:
		"reach_marker": return "marker"
		"kills": return "kills"
		"chest": return "chests"
		"equip": return "equips"
		"dodge": return "dodges"
		"enter_boss": return "boss_room"
		"boss": return "boss"
		"exit": return "exit"
	return "exit"

func _cum_target(i: int) -> int:
	var objs := _objs()
	var type := String(objs[i]["type"])
	var total := 0
	for j in range(0, i + 1):
		if String(objs[j]["type"]) == type:
			total += int(objs[j].get("count", 1))
	return total

func _prev_target(i: int) -> int:
	return _cum_target(i) - int(_objs()[i].get("count", 1))

func _obj_met(i: int) -> bool:
	var type := String(_objs()[i]["type"])
	return int(counters[_counter_key(type)]) >= _cum_target(i)

func _obj_text(i: int) -> String:
	var o: Dictionary = _objs()[i]
	var cnt := int(o.get("count", 1))
	var t := String(o["text"])
	if cnt > 1:
		var cur := clampi(int(counters[_counter_key(String(o["type"]))]) - _prev_target(i), 0, cnt)
		t += "  (%d/%d)" % [cur, cnt]
	return t

func _update_objectives() -> void:
	if mission.is_empty() or hud == null:
		return
	var objs := _objs()
	while obj_index < objs.size() and _obj_met(obj_index):
		var done_text := String(objs[obj_index]["text"])
		hud.objective_done(done_text)
		play_sfx("checkpoint", -6.0)
		obj_index += 1
		_save_run()
	if obj_index >= objs.size():
		hud.set_objective("MISSION", "All objectives complete")
		if not finished and int(counters["exit"]) >= 1:
			_complete_mission()
		return
	hud.set_objective("OBJECTIVE  %d / %d" % [obj_index + 1, objs.size()], _obj_text(obj_index))
	var oid := String(objs[obj_index]["id"])
	if HINTS.has(oid) and not bool(_hint_shown.get(oid, false)):
		_hint_shown[oid] = true
		if mission_id == "tutorial" or oid in ["find", "boss"]:
			hud.toast(String(HINTS[oid]), Color(0.85, 0.75, 1.0), 6.0)

# --------------------------------------------------------------- completion
func _complete_mission() -> void:
	finished = true
	var prof: VCProfile = VC.profile
	var first_time := not prof.completed.has(mission_id)
	if first_time:
		prof.completed.append(mission_id)
	var xp := int(mission["xp"]) if first_time else int(mission["xp"]) / 3
	var coins := int(mission["coins"]) if first_time else int(mission["coins"]) / 3
	if bool(mission.get("endless", false)):
		xp = int(mission["xp"]) + 250 * (floor_n - 1)
		coins = int(mission["coins"]) + 90 * (floor_n - 1)
		prof.stats["delve_best"] = maxi(int(prof.stats.get("delve_best", 0)), floor_n)
	var before_level := prof.level
	_grant_xp(xp, player.global_position)
	prof.coins += coins
	gained_coins += coins
	player.god_mode = true
	play_sfx("victory")
	VC.run = {"finished": true}
	run = VC.run
	VC.save_now()
	touch.release_all()
	touch.visible = false
	mission_completed.emit()
	await get_tree().create_timer(0.8, false).timeout
	var lines: Array = [
		["Time", "%dm %02ds" % [int(elapsed) / 60, int(elapsed) % 60]],
		["Enemies defeated", str(counters["kills"])],
		["Chests opened", str(counters["chests"])],
		["Loot found", str(gained_items)],
		["Experience", "+%d" % gained_xp, VCDefs.COL_VIOLET],
		["Coins", "+%d" % gained_coins, VCDefs.COL_COIN],
	]
	if prof.level > before_level:
		lines.append(["Level", "%d  (+%d)" % [prof.level, prof.level - before_level], VCDefs.COL_GOOD])
	var next_id := _next_mission()
	var buttons: Array = []
	if bool(mission.get("endless", false)):
		buttons.append(["DESCEND TO FLOOR %d" % (floor_n + 1), func(): VC.start_mission("delve", 0, false, {"floor": floor_n + 1})])
		next_id = ""
	if next_id != "":
		buttons.append(["NEXT: %s" % String(VCMissions.get_mission(next_id)["name"]).to_upper(), func(): VC.start_mission(next_id)])
	buttons.append(["RETURN TO MENU", func(): VC.goto_menu()])
	_show_result("MISSION COMPLETE", VCDefs.COL_COIN, String(mission["name"]), lines, buttons)

func _next_mission() -> String:
	var order: Array = VCMissions.ORDER
	var i := order.find(mission_id)
	if i >= 0 and i + 1 < order.size():
		return String(order[i + 1])
	return ""

func _show_result(title: String, col: Color, sub: String, lines: Array, buttons: Array) -> void:
	_close_overlay_node()
	var rs := VCResultScreen.new()
	rs.setup(title, col, sub, lines, buttons)
	_ctl_layer.layer = 11
	var layer := CanvasLayer.new()
	layer.layer = 30
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	layer.add_child(rs)
	_overlay = layer
	overlay_open = "result"

# ------------------------------------------------------------ death & retry
func _on_player_died() -> void:
	VC.profile.stats["deaths"] = int(VC.profile.stats["deaths"]) + 1
	touch.release_all()
	hud.banner("YOU FELL", "", VCDefs.COL_BAD, 2.0)
	player_defeated.emit()
	await get_tree().create_timer(1.6, false).timeout
	if finished or _defeat_shown:
		return
	_defeat_shown = true
	var lines: Array = [["Enemies defeated", str(counters["kills"])], ["Checkpoint", "Entrance" if checkpoint_room == 0 else "Shrine"]]
	_show_result("DEFEATED", VCDefs.COL_BAD, "The void is patient.", lines, [["RETRY FROM CHECKPOINT", retry], ["SAVE & MAIN MENU", func(): _quit_to_menu()]])

func retry() -> void:
	_defeat_shown = false
	_close_overlay_node()
	# reset any fight in progress
	for key in rooms_state:
		var st: Dictionary = rooms_state[key]
		if String(st["state"]) == "active":
			st["state"] = "idle"
			st["next_wave_at"] = -1.0
			_set_barriers(int(key), false)
	for e in enemies.duplicate():
		if is_instance_valid(e):
			e.queue_free()
	enemies.clear()
	for p in _projectiles:
		p.deactivate()
	if boss_state == "active":
		boss_state = "idle"
		boss = null
		hud.hide_boss()
		cam_rig.release_focus()
		VC.play_music("dungeon")
		_set_barriers(_boss_room_id(), false)
	VC.profile.potions = maxi(VC.profile.potions, 2)
	var p := _checkpoint_pos()
	player.revive_at(p)
	cam_rig.snap_to(p)
	player.god_mode = false
	hud.toast("Back on your feet", VCDefs.COL_GOOD)
	_save_run()
	if mission_id == "tutorial" and int(counters["kills"]) < 1:
		_spawn_enemy_at_tile(VCDefs.ENEMY_HUSK, data.rooms[0]["center"] + Vector2i(5, -2), 0, 1, 1.0)

func _boss_room_id() -> int:
	return data.boss_room

# ------------------------------------------------------------------ overlays
func _close_overlay_node() -> void:
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null
	overlay_open = ""

func open_overlay(kind: String) -> void:
	if overlay_open != "" or finished or not build_done:
		return
	overlay_open = kind
	get_tree().paused = true
	var layer := CanvasLayer.new()
	layer.layer = 30
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	_overlay = layer
	match kind:
		"pause":
			var pm := VCPauseMenu.new()
			layer.add_child(pm)
			pm.resume.connect(close_overlay)
			pm.open_pack.connect(func(): _swap_overlay("pack"))
			pm.open_settings.connect(func(): _swap_overlay("settings"))
			pm.quit_to_menu.connect(_quit_to_menu)
		"pack":
			var inv := VCInventoryScreen.new()
			layer.add_child(inv)
			inv.closed.connect(close_overlay)
			inv.changed.connect(_on_inventory_changed)
		"settings":
			var sp := VCSettingsPanel.new()
			layer.add_child(sp)
			sp.closed.connect(close_overlay)
			sp.applied.connect(func():
				touch.apply_settings()
				fx.configure(VCSettings.quality_profile()))
	play_sfx("click", -4.0)

func _swap_overlay(kind: String) -> void:
	_close_overlay_node()
	get_tree().paused = false
	open_overlay(kind)

func close_overlay() -> void:
	_close_overlay_node()
	get_tree().paused = false
	VCSettings.save_settings()
	touch.apply_settings()
	VCInput.reset()
	_save_run()

func _on_inventory_changed(kind: String) -> void:
	player.refresh_stats(false)
	player.refresh_visuals()
	if kind == "equip":
		counters["equips"] += 1
		_update_objectives()
	_save_run()

func _quit_to_menu() -> void:
	_save_run()
	get_tree().paused = false
	VC.goto_menu()

# ---------------------------------------------------------------------- save
func _save_run() -> void:
	if not build_done or finished or mission.is_empty():
		return
	var run_d := {
		"mission": mission_id, "seed": seed_, "checkpoint_room": checkpoint_room,
		"cleared": (run.get("cleared", []) as Array).duplicate(),
		"chests": opened_chests.duplicate(), "broken": broken_ids.duplicate(), "secrets": opened_secrets.duplicate(),
		"obj_index": obj_index, "counters": counters.duplicate(), "boss_state": "dead" if boss_state == "dead" else "idle",
		"explored": _encode_explored(), "elapsed": elapsed, "finished": false, "floor": floor_n,
	}
	run = run_d
	VC.run = run_d
	if VC.autosave:
		VC.save_now()

func _unhandled_input(event: InputEvent) -> void:
	if not build_done:
		return
	if overlay_open == "" and event.is_action_pressed("vc_inventory"):
		open_overlay("pack")

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and build_done:
		if overlay_open == "pause":
			close_overlay()
		elif overlay_open == "":
			open_overlay("pause")
		elif overlay_open in ["pack", "settings"]:
			close_overlay()
	elif what == NOTIFICATION_APPLICATION_PAUSED and build_done and not finished:
		# Only freeze the game here; building UI while the Android surface is being torn down is risky.
		_resume_pause_pending = overlay_open == ""
		if _resume_pause_pending:
			get_tree().paused = true
		touch.release_all()
		_save_run()
	elif what == NOTIFICATION_APPLICATION_RESUMED and build_done and _resume_pause_pending:
		_resume_pause_pending = false
		get_tree().paused = false
		call_deferred("open_overlay", "pause")
