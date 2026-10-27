class_name VCMainMenu
extends Node3D
## Boot + main menu. Animated 3D void-rift backdrop with the UI laid over it.

var _ui: CanvasLayer
var _root: Control
var _panel_holder: Control
var _crystal: Node3D
var _shards: Array = []
var _hero: Node3D
var _t := 0.0
var _cam: Camera3D
var _modal: Control
var _play_btn: Button
var _mat_cache := {}

func _ready() -> void:
	VCSettings.load_settings()
	VCSettings.apply(get_viewport())
	_build_backdrop()
	_build_ui()
	VC.play_music("menu")
	_splash()
	if not bool(VCSettings.get_value("seen_howto")):
		get_tree().create_timer(1.8).timeout.connect(func():
			if _modal == null and is_inside_tree():
				_open_howto())
	if VCCrashGuard.crashed_last_time:
		VCCrashGuard.crashed_last_time = false
		_notice("The game closed unexpectedly last time. Tap OPEN CRASH REPORT, screenshot it and send it to the developer.")

func _m(c: Color, em: float = 0.0) -> StandardMaterial3D:
	var key := "%s_%s" % [c.to_html(), em]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.85
	if em > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = em
	_mat_cache[key] = m
	return m

func _box(parent: Node3D, size: Vector3, pos: Vector3, c: Color, em: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = _m(c, em)
	mi.position = pos
	parent.add_child(mi)
	return mi

func _build_backdrop() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.008, 0.045)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.4, 0.75)
	env.ambient_light_energy = 0.7
	env.fog_enabled = true
	env.fog_light_color = Color(0.12, 0.05, 0.22)
	env.fog_density = 0.035
	env.glow_enabled = true
	we.environment = env
	add_child(we)
	_cam = Camera3D.new()
	_cam.position = Vector3(4.2, 3.2, 9.0)
	_cam.fov = 48.0
	_cam.h_offset = -3.2
	add_child(_cam)
	_cam.look_at(Vector3(2.4, 1.8, 0.0))
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	sun.light_color = Color(0.75, 0.65, 1.0)
	sun.light_energy = 0.6
	add_child(sun)
	# floor of dark blocks
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for x in range(-8, 9):
		for z in range(-8, 6):
			var h := 0.0 if rng.randf() < 0.85 else 0.25
			var shade := 0.10 + rng.randf() * 0.05
			_box(self, Vector3(1.96, 0.5 + h, 1.96), Vector3(x * 2.0, -0.25 + h * 0.5 - 0.0, z * 2.0), Color(shade * 1.1, shade * 0.95, shade * 1.5))
	# ruined pillars
	for p in [Vector3(-4, 0, -4), Vector3(9, 0, -3), Vector3(-7, 0, 1), Vector3(11, 0, 2)]:
		var hgt := 3.0 + rng.randf() * 3.0
		_box(self, Vector3(1.6, hgt, 1.6), p + Vector3(0, hgt * 0.5, 0), Color(0.16, 0.13, 0.22))
		_box(self, Vector3(1.9, 0.3, 1.9), p + Vector3(0, hgt + 0.15, 0), Color(0.2, 0.16, 0.28))
	# the rift crystal
	_crystal = Node3D.new()
	_crystal.position = Vector3(8.0, 3.2, -5.0)
	add_child(_crystal)
	var core := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(2.2, 3.6, 2.2)
	core.mesh = pm
	core.material_override = _m(Color(0.55, 0.22, 1.0), 2.2)
	_crystal.add_child(core)
	var core2 := MeshInstance3D.new()
	core2.mesh = pm
	core2.rotation_degrees = Vector3(180, 45, 0)
	core2.position = Vector3(0, -3.0, 0)
	core2.material_override = _m(Color(0.4, 0.15, 0.8), 1.6)
	_crystal.add_child(core2)
	var cl := OmniLight3D.new()
	cl.light_color = Color(0.7, 0.4, 1.0)
	cl.light_energy = 3.0
	cl.omni_range = 14.0
	cl.position = Vector3(0, -1.0, 0)
	_crystal.add_child(cl)
	for i in 14:
		var s := _box(self, Vector3.ONE * (0.2 + rng.randf() * 0.25), Vector3.ZERO, Color(0.6, 0.35, 1.0), 1.5)
		s.set_meta("a", rng.randf() * TAU)
		s.set_meta("r", 2.6 + rng.randf() * 2.2)
		s.set_meta("y", rng.randf_range(-1.0, 3.5))
		s.set_meta("sp", rng.randf_range(0.3, 0.9))
		_shards.append(s)
	# torches
	for tp in [Vector3(-1.0, 0, -3.0), Vector3(5.5, 0, 3.0)]:
		_box(self, Vector3(0.3, 1.6, 0.3), tp + Vector3(0, 0.8, 0), Color(0.25, 0.17, 0.12))
		_box(self, Vector3(0.45, 0.45, 0.45), tp + Vector3(0, 1.8, 0), Color(1.0, 0.55, 0.2), 2.5)
		var tl := OmniLight3D.new()
		tl.light_color = Color(1.0, 0.6, 0.3)
		tl.light_energy = 1.6
		tl.omni_range = 7.0
		tl.position = tp + Vector3(0, 2.0, 0)
		add_child(tl)
	# a blocky hero silhouette
	_hero = Node3D.new()
	_hero.position = Vector3(3.4, 0.0, 2.0)
	_hero.rotation.y = -0.5
	add_child(_hero)
	_box(_hero, Vector3(0.5, 0.7, 0.3), Vector3(0, 0.35 + 0.05, 0), Color(0.2, 0.15, 0.3))        # legs
	_box(_hero, Vector3(0.6, 0.8, 0.36), Vector3(0, 1.1, 0), Color(0.3, 0.18, 0.5))               # torso
	_box(_hero, Vector3(0.5, 0.5, 0.5), Vector3(0, 1.78, 0), Color(0.85, 0.7, 0.6))               # head
	_box(_hero, Vector3(0.58, 0.3, 0.58), Vector3(0, 2.0, 0), Color(0.15, 0.08, 0.25))            # hood
	_box(_hero, Vector3(0.18, 0.8, 0.2), Vector3(0.45, 1.0, 0.0), Color(0.3, 0.18, 0.5))          # arm
	_box(_hero, Vector3(0.12, 1.4, 0.12), Vector3(0.55, 1.5, 0.35), Color(0.8, 0.8, 0.95), 0.6)   # blade
	# drifting embers
	var ps := CPUParticles3D.new()
	ps.amount = 60
	ps.lifetime = 6.0
	ps.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	ps.emission_box_extents = Vector3(10, 0.2, 8)
	ps.direction = Vector3.UP
	ps.initial_velocity_min = 0.4
	ps.initial_velocity_max = 1.2
	ps.gravity = Vector3.ZERO
	var qm := QuadMesh.new()
	qm.size = Vector2(0.09, 0.09)
	var qmat := StandardMaterial3D.new()
	qmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qmat.albedo_color = Color(0.75, 0.5, 1.0)
	qmat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	qm.material = qmat
	ps.mesh = qm
	ps.position = Vector3(2, 0.2, 0)
	add_child(ps)

func _process(delta: float) -> void:
	_t += delta
	_crystal.rotation.y += delta * 0.6
	_crystal.position.y = 3.2 + sin(_t * 1.2) * 0.3
	for s in _shards:
		var a: float = float(s.get_meta("a")) + _t * float(s.get_meta("sp"))
		var r: float = s.get_meta("r")
		s.position = _crystal.position + Vector3(cos(a) * r, float(s.get_meta("y")) - 2.0 + sin(_t + a) * 0.3, sin(a) * r)
		s.rotation += Vector3(delta, delta * 0.7, 0)
	_hero.position.y = sin(_t * 1.6) * 0.03
	_cam.position.x = 4.2 + sin(_t * 0.15) * 0.5

# ------------------------------------------------------------------- UI
func _build_ui() -> void:
	_ui = CanvasLayer.new()
	add_child(_ui)
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = VCUI.theme()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_root)
	var m := VCUI.safe_margins(get_viewport(), 24.0)
	var mc := MarginContainer.new()
	mc.set_anchors_preset(Control.PRESET_FULL_RECT)
	mc.add_theme_constant_override("margin_left", int(m["left"]))
	mc.add_theme_constant_override("margin_right", int(m["right"]))
	mc.add_theme_constant_override("margin_top", int(m["top"]))
	mc.add_theme_constant_override("margin_bottom", int(m["bottom"]))
	_root.add_child(mc)
	var col := VCUI.vbox(7)
	col.custom_minimum_size = Vector2(420, 0)
	col.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	mc.add_child(col)
	var logo := VCLogo.new()
	logo.custom_minimum_size = Vector2(520, 130)
	col.add_child(logo)
	var info := VCUI.label("", 20, VCDefs.COL_TEXT_DIM)
	info.name = "Info"
	col.add_child(info)
	var items := [["PLAY", "play"], ["DUNGEONS", "dungeons"], ["INVENTORY", "inventory"], ["CHARACTER", "character"], ["SETTINGS", "settings"]]
	if not OS.has_feature("web"):
		items.append(["EXIT", "exit"])
	for it in items:
		var b := VCUI.button(String(it[0]), Vector2(380, 56), 26)
		b.pressed.connect(_on_button.bind(String(it[1])))
		col.add_child(b)
		if String(it[1]) == "play":
			_play_btn = b
	var row2 := VCUI.hbox(10)
	col.add_child(row2)
	var hb := VCUI.button("HOW TO PLAY", Vector2(130, 52), 17)
	hb.pressed.connect(_on_button.bind("howto"))
	row2.add_child(hb)
	var cb2 := VCUI.button("CODES", Vector2(110, 52), 17)
	cb2.pressed.connect(_on_button.bind("codes"))
	row2.add_child(cb2)
	var mb := VCUI.button("MODS", Vector2(120, 52), 17)
	mb.pressed.connect(_on_button.bind("mods"))
	row2.add_child(mb)
	var ver := VCUI.label("%s v%s  -  Infinity Studios" % [VCDefs.GAME_NAME, String(ProjectSettings.get_setting("application/config/version", "0.1.0"))], 16, Color(0.5, 0.45, 0.65))
	ver.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_root.add_child(ver)
	ver.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	ver.grow_vertical = Control.GROW_DIRECTION_BEGIN
	ver.offset_left = -300
	ver.offset_top = -34
	ver.offset_right = -14
	ver.offset_bottom = -8
	_refresh_info()

func _refresh_info() -> void:
	var p: VCProfile = VC.profile
	var info: Label = _root.find_child("Info", true, false)
	if info != null and p != null:
		info.text = "Level %d   |   %d coins" % [p.level, p.coins]
	if _play_btn != null:
		if VC.has_run_in_progress():
			_play_btn.text = "CONTINUE"
		elif not VC.profile.completed.has("tutorial"):
			_play_btn.text = "PLAY"
		else:
			_play_btn.text = "PLAY"

func _notice(text: String) -> void:
	var l := VCUI.label(text, 18, Color(1.0, 0.75, 0.5), HORIZONTAL_ALIGNMENT_CENTER)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(620, 0)
	var p := VCUI.panel(Color(0.12, 0.05, 0.04, 0.95), Color(0.8, 0.4, 0.2))
	var vb := VCUI.vbox(8)
	p.add_child(vb)
	vb.add_child(l)
	var cb := VCUI.button("OPEN CRASH REPORT", Vector2(300, 52), 20)
	cb.pressed.connect(func():
		var lay := CanvasLayer.new()
		lay.layer = 60
		add_child(lay)
		lay.add_child(VCLogViewer.make()))
	vb.add_child(cb)
	p.set_anchors_preset(Control.PRESET_CENTER_TOP)
	p.position = Vector2(300, 18)
	_root.add_child(p)
	var tw := create_tween()
	tw.tween_interval(40.0)
	tw.tween_callback(p.queue_free)

func _splash() -> void:
	var sp := ColorRect.new()
	sp.color = Color(0.01, 0.0, 0.03)
	sp.set_anchors_preset(Control.PRESET_FULL_RECT)
	sp.mouse_filter = Control.MOUSE_FILTER_STOP
	var l := VCUI.label("INFINITY STUDIOS", 44, Color(0.85, 0.75, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sp.add_child(l)
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	layer.add_child(sp)
	var tw := create_tween()
	tw.tween_interval(0.9)
	tw.tween_property(sp, "modulate:a", 0.0, 0.6)
	tw.tween_callback(layer.queue_free)

func _on_button(id: String) -> void:
	if _modal != null:
		return
	VC.play_sfx("click", -4.0)
	VCCrashGuard.stage("menu:" + id)
	match id:
		"play":
			if VC.has_run_in_progress():
				VC.start_mission(String(VC.run["mission"]), int(VC.run["seed"]), true)
			else:
				VC.start_mission(_next_mission_id())
		"dungeons":
			_open_dungeons()
		"inventory":
			_open_inventory("pack")
		"character":
			_open_inventory("hero")
		"settings":
			var sp := VCSettingsPanel.new()
			sp.closed.connect(_close_modal)
			_show_modal(sp)
		"howto":
			_open_howto()
		"codes":
			var cp := VCCodesPanel.new()
			cp.closed.connect(_close_modal)
			_show_modal(cp)
		"mods":
			var mp := VCModsPanel.new()
			mp.closed.connect(_close_modal)
			_show_modal(mp)
		"exit":
			VC.save_now()
			get_tree().quit()

func _next_mission_id() -> String:
	for id in VCMissions.ORDER:
		if not VC.profile.completed.has(id):
			return id
	return VCMissions.ORDER[VCMissions.ORDER.size() - 1]

func _show_modal(c: Control) -> void:
	_modal = c
	var layer := CanvasLayer.new()
	layer.layer = 20
	layer.name = "ModalLayer"
	add_child(layer)
	layer.add_child(c)
	VCUI.fit_to_viewport(c)

func _close_modal() -> void:
	if _modal != null:
		var layer := _modal.get_parent()
		layer.queue_free()
		_modal = null
	VCSettings.save_settings()
	VC.save_now()
	_refresh_info()

func _open_howto() -> void:
	var h := VCHowToPlay.new()
	h.closed.connect(_close_modal)
	_show_modal(h)

func _open_inventory(tab: String) -> void:
	var inv := VCInventoryScreen.new()
	inv.tab = tab
	inv.closed.connect(_close_modal)
	_show_modal(inv)

func _open_dungeons() -> void:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.theme = VCUI.theme()
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.03, 0.8)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.add_child(cc)
	var panel := VCUI.panel()
	cc.add_child(panel)
	var v := VCUI.vbox(10)
	v.custom_minimum_size = Vector2(700, 0)
	panel.add_child(v)
	v.add_child(VCUI.label("DUNGEONS", 36, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(700, 460)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	var list := VCUI.vbox(10)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(list)
	for id in VCMissions.ORDER:
		var mi := VCMissions.get_mission(id)
		var unlocked := VCMissions.is_unlocked(id, VC.profile.completed)
		var done: bool = VC.profile.completed.has(id)
		var card := VCUI.panel(Color(0.08, 0.05, 0.14, 0.95), Color(0.3, 0.18, 0.5) if unlocked else Color(0.2, 0.2, 0.25))
		list.add_child(card)
		var h := VCUI.hbox(12)
		card.add_child(h)
		var txt := VCUI.vbox(2)
		txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(txt)
		var title := String(mi["name"]) + ("   [COMPLETE]" if done else "")
		txt.add_child(VCUI.label(title, 26, VCDefs.COL_COIN if done else Color.WHITE))
		var blurb := VCUI.label(String(mi["blurb"]) + ("\nRecommended level %d" % int(mi["recommended_level"]) if unlocked else "\nLocked - complete the previous mission"), 17, VCDefs.COL_TEXT_DIM)
		blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		blurb.custom_minimum_size = Vector2(430, 0)
		txt.add_child(blurb)
		var bv := VCUI.vbox(6)
		h.add_child(bv)
		var go := VCUI.button("START" if not VC.has_run_in_progress() or String(VC.run.get("mission", "")) != id else "NEW RUN", Vector2(180, 56), 22)
		go.disabled = not unlocked
		go.pressed.connect(func(): VC.run = {}; VC.start_mission(id, 0, false))
		bv.add_child(go)
		if VC.has_run_in_progress() and String(VC.run.get("mission", "")) == id:
			var cont := VCUI.button("CONTINUE", Vector2(180, 56), 22)
			cont.pressed.connect(func(): VC.start_mission(id, int(VC.run["seed"]), true))
			bv.add_child(cont)
	var back := VCUI.button("BACK", Vector2(700, 60), 24)
	back.pressed.connect(_close_modal)
	v.add_child(back)
	_show_modal(c)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _modal != null:
		_close_modal()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if _modal != null:
			_close_modal()
