class_name VCHud
extends CanvasLayer
## In-game overlay: health/xp, coins, objective tracker, boss bar, toasts, banners, minimap.

var player: VCPlayer
var hp_bar: VCBar
var xp_bar: VCBar
var boss_bar: VCBar
var level_label: Label
var coin_label: Label
var obj_title: Label
var obj_text: Label
var obj_panel: PanelContainer
var boss_box: VBoxContainer
var boss_name: Label
var fps_label: Label
var banner_title: Label
var banner_sub: Label
var banner_box: VBoxContainer
var vignette: ColorRect
var toast_box: VBoxContainer
var mini_clip: Control
var mini_tex: TextureRect
var mini_dot: Control
var seed_label: Label

var _mini_img: Image
var _mini_tex_obj: ImageTexture
var _mini_dirty := false
var _mini_data: VCDungeonData
var _explored: PackedByteArray
var _last_reveal := Vector2i(-99, -99)
var _vignette_a := 0.0
var _banner_t := 0.0
var _banner_total := 3.0
var _toast_items: Array = []
var _obj_flash := 0.0
const MINI_PX := 3

func _ready() -> void:
	layer = 10
	name = "Hud"
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = VCUI.theme()
	add_child(root)
	var m := VCUI.safe_margins(get_viewport(), 18.0)
	var ml := float(m["left"])
	var mt := float(m["top"])

	vignette = ColorRect.new()
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette.color = Color(0.8, 0.0, 0.1, 0.0)
	root.add_child(vignette)

	# --- player block (top left)
	var pb := VBoxContainer.new()
	pb.position = Vector2(ml, mt)
	pb.add_theme_constant_override("separation", 4)
	pb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(pb)
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 8)
	top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pb.add_child(top_row)
	var lvl_panel := PanelContainer.new()
	lvl_panel.add_theme_stylebox_override("panel", VCUI.box(Color(0.2, 0.08, 0.38, 0.95), Color(0.85, 0.65, 1.0), 8, 2, 8))
	top_row.add_child(lvl_panel)
	level_label = VCUI.label("1", 28, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	level_label.custom_minimum_size = Vector2(42, 0)
	lvl_panel.add_child(level_label)
	var bars := VBoxContainer.new()
	bars.add_theme_constant_override("separation", 3)
	top_row.add_child(bars)
	hp_bar = VCBar.new()
	hp_bar.custom_minimum_size = Vector2(300, 28)
	hp_bar.font_size = 19
	bars.add_child(hp_bar)
	xp_bar = VCBar.new()
	xp_bar.custom_minimum_size = Vector2(300, 10)
	xp_bar.color = VCDefs.COL_XP
	xp_bar.show_ghost = false
	bars.add_child(xp_bar)
	coin_label = VCUI.label("0", 22, VCDefs.COL_COIN)
	pb.add_child(coin_label)

	# --- objective (top centre)
	obj_panel = PanelContainer.new()
	obj_panel.add_theme_stylebox_override("panel", VCUI.box(Color(0.05, 0.03, 0.09, 0.78), Color(0.45, 0.25, 0.8, 0.9), 10, 2, 12))
	obj_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	obj_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	obj_panel.position.y = mt
	obj_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(obj_panel)
	var ov := VBoxContainer.new()
	ov.add_theme_constant_override("separation", 0)
	obj_panel.add_child(ov)
	obj_title = VCUI.label("OBJECTIVE", 15, VCDefs.COL_VIOLET, HORIZONTAL_ALIGNMENT_CENTER)
	ov.add_child(obj_title)
	obj_text = VCUI.label("", 22, VCDefs.COL_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	obj_text.custom_minimum_size = Vector2(340, 0)
	ov.add_child(obj_text)

	# --- boss bar (below objective)
	boss_box = VBoxContainer.new()
	boss_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	boss_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	boss_box.position.y = mt + 78.0
	boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_box.visible = false
	root.add_child(boss_box)
	boss_name = VCUI.label("", 24, Color(1.0, 0.8, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	boss_box.add_child(boss_name)
	boss_bar = VCBar.new()
	boss_bar.custom_minimum_size = Vector2(560, 22)
	boss_bar.color = Color(0.7, 0.15, 0.85)
	boss_bar.markers = [0.66, 0.33]
	boss_bar.font_size = 16
	boss_box.add_child(boss_bar)

	# --- banner (centre)
	banner_box = VBoxContainer.new()
	banner_box.set_anchors_preset(Control.PRESET_CENTER)
	banner_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	banner_box.grow_vertical = Control.GROW_DIRECTION_BOTH
	banner_box.position.y = -110
	banner_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner_box.modulate.a = 0.0
	root.add_child(banner_box)
	banner_title = VCUI.label("", 54, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	banner_title.add_theme_color_override("font_outline_color", Color(0.15, 0.0, 0.3, 1.0))
	banner_title.add_theme_constant_override("outline_size", 10)
	banner_box.add_child(banner_title)
	banner_sub = VCUI.label("", 26, VCDefs.COL_VIOLET, HORIZONTAL_ALIGNMENT_CENTER)
	banner_box.add_child(banner_sub)

	# --- toasts (bottom centre-left)
	toast_box = VBoxContainer.new()
	toast_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	toast_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	toast_box.position.y = -float(m["bottom"]) - 24.0
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_box.add_theme_constant_override("separation", 4)
	root.add_child(toast_box)

	# --- minimap (top right, under the small buttons)
	var mr := float(m["right"])
	mini_clip = Control.new()
	mini_clip.custom_minimum_size = Vector2(150, 150)
	mini_clip.size = Vector2(150, 150)
	mini_clip.clip_contents = true
	mini_clip.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	mini_clip.position = Vector2(-150.0 - mr, mt + 78.0)
	mini_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(mini_clip)
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.015, 0.06, 0.6)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mini_clip.add_child(bg)
	mini_tex = TextureRect.new()
	mini_tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mini_tex.stretch_mode = TextureRect.STRETCH_SCALE
	mini_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mini_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mini_clip.add_child(mini_tex)
	mini_dot = Control.new()
	mini_dot.set_anchors_preset(Control.PRESET_FULL_RECT)
	mini_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mini_dot.draw.connect(_draw_mini_dot)
	mini_clip.add_child(mini_dot)
	var frame := Panel.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_theme_stylebox_override("panel", VCUI.box(Color(0, 0, 0, 0), Color(0.5, 0.3, 0.85, 0.9), 8, 2, 0))
	mini_clip.add_child(frame)

	fps_label = VCUI.label("", 18, Color(0.6, 1.0, 0.7))
	fps_label.position = Vector2(ml, 118.0 + mt)
	fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fps_label)
	seed_label = VCUI.label("", 16, Color(0.6, 0.55, 0.75))
	seed_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	seed_label.position = Vector2(ml, -34.0 - float(m["bottom"]))
	seed_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(seed_label)

func bind_player(p: VCPlayer) -> void:
	player = p
	hp_bar.set_values(p.hp, p.max_hp)
	hp_bar.snap()
	_refresh_xp()
	xp_bar.snap()

# -------------------------------------------------------------- minimap
func setup_minimap(d: VCDungeonData, explored_mask: PackedByteArray = PackedByteArray()) -> void:
	_mini_data = d
	_mini_img = Image.create(d.w, d.h, false, Image.FORMAT_RGBA8)
	_mini_img.fill(Color(0, 0, 0, 0))
	_mini_tex_obj = ImageTexture.create_from_image(_mini_img)
	mini_tex.texture = _mini_tex_obj
	mini_tex.size = Vector2(d.w * MINI_PX, d.h * MINI_PX)
	_explored = explored_mask if explored_mask.size() == d.w * d.h else PackedByteArray()
	if _explored.is_empty():
		_explored.resize(d.w * d.h)
		_explored.fill(0)
	else:
		for y in d.h:
			for x in d.w:
				if _explored[d.idx(x, y)] == 1:
					_paint(x, y)
		_mini_dirty = true

func explored_mask() -> PackedByteArray:
	return _explored

func _paint(x: int, y: int) -> void:
	var d := _mini_data
	var t := d.get_tile(x, y)
	var col := Color(0.42, 0.28, 0.72, 0.95)
	if t == VCDungeonData.T_DECOR:
		col = Color(0.25, 0.17, 0.42, 0.95)
	elif t == VCDungeonData.T_SECRET:
		col = Color(0.8, 0.5, 1.0, 0.95)
	elif t != VCDungeonData.T_FLOOR:
		col = Color(0.12, 0.08, 0.2, 0.85)
	_mini_img.set_pixel(x, y, col)

func reveal(tile: Vector2i, radius: int = 6) -> void:
	if _mini_data == null or tile == _last_reveal:
		return
	_last_reveal = tile
	var d := _mini_data
	for y in range(tile.y - radius, tile.y + radius + 1):
		for x in range(tile.x - radius, tile.x + radius + 1):
			if not d.in_bounds(x, y) or _explored[d.idx(x, y)] == 1:
				continue
			if Vector2(x - tile.x, y - tile.y).length() > float(radius):
				continue
			# only reveal what the hero could plausibly see (line of sight over floor)
			var visible_ := d.line_clear(tile, Vector2i(x, y))
			if not visible_ and d.get_tile(x, y) != VCDungeonData.T_FLOOR:
				# walls bordering a seen floor tile
				for dv in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var n: Vector2i = Vector2i(x, y) + dv
					if d.is_floor(n.x, n.y) and _explored[d.idx(n.x, n.y)] == 1:
						visible_ = true
						break
			if visible_:
				_explored[d.idx(x, y)] = 1
				_paint(x, y)
				_mini_dirty = true

func mark(tile: Vector2i, color: Color, size_px: int = 2) -> void:
	if _mini_data == null:
		return
	for dy in range(-size_px / 2, size_px / 2 + 1):
		for dx in range(-size_px / 2, size_px / 2 + 1):
			var x := tile.x + dx
			var y := tile.y + dy
			if _mini_data.in_bounds(x, y) and _explored[_mini_data.idx(x, y)] == 1:
				_mini_img.set_pixel(x, y, color)
	_mini_dirty = true

func _draw_mini_dot() -> void:
	var c := mini_dot.size * 0.5
	mini_dot.draw_circle(c, 5.0, Color(1, 1, 1, 0.95))
	mini_dot.draw_circle(c, 3.0, Color(0.6, 0.3, 1.0, 1.0))
	if player != null:
		var f := Vector2(-sin(player.facing), -cos(player.facing))
		# facing is in world axes; minimap is north-up, so it only matches at camera yaw 0
		mini_dot.draw_line(c, c + f.rotated(0.0) * 11.0, Color(1, 1, 1, 0.9), 2.0)

# --------------------------------------------------------------- updating
func _refresh_xp() -> void:
	if player == null or player.profile == null:
		return
	var p := player.profile
	level_label.text = str(p.level)
	if p.level >= VCProfile.MAX_LEVEL:
		xp_bar.set_values(1.0, 1.0)
	else:
		xp_bar.set_values(float(p.xp), float(p.xp_needed()))
	coin_label.text = "%d" % p.coins

func _process(delta: float) -> void:
	if player == null:
		return
	hp_bar.set_values(player.hp, float(player.max_hp))
	hp_bar.text = "%d / %d" % [int(ceil(player.hp)), player.max_hp]
	_refresh_xp()
	if _mini_dirty and _mini_data != null:
		_mini_tex_obj.update(_mini_img)
		_mini_dirty = false
	if _mini_data != null:
		var t := _mini_data.world_to_tile(player.global_position)
		var off := mini_clip.size * 0.5 - (Vector2(t) + Vector2(0.5, 0.5)) * float(MINI_PX)
		mini_tex.position = off
	# low-health pulse + hit flash
	_vignette_a = maxf(0.0, _vignette_a - delta * 2.2)
	var low := 0.0
	if player.is_alive() and player.hp < player.max_hp * 0.3:
		low = 0.14 + 0.08 * sin(Time.get_ticks_msec() * 0.008)
	vignette.color.a = maxf(_vignette_a, low)
	if bool(VCSettings.get_value("show_fps")):
		fps_label.text = "%d FPS" % Engine.get_frames_per_second()
	else:
		fps_label.text = ""
	if _banner_t > 0.0:
		_banner_t -= delta
		var elapsed := _banner_total - _banner_t
		banner_box.modulate.a = clampf(minf(elapsed / 0.25, _banner_t / 0.6), 0.0, 1.0)
	if _obj_flash > 0.0:
		_obj_flash -= delta
		var k := clampf(_obj_flash / 1.2, 0.0, 1.0)
		obj_panel.modulate = Color(1, 1, 1).lerp(Color(0.7, 1.0, 0.8), k)
	var i := _toast_items.size() - 1
	while i >= 0:
		var it: Dictionary = _toast_items[i]
		it["t"] -= delta
		var lab: Control = it["node"]
		if it["t"] < 0.5:
			lab.modulate.a = clampf(it["t"] / 0.5, 0.0, 1.0)
		if it["t"] <= 0.0:
			lab.queue_free()
			_toast_items.remove_at(i)
		i -= 1
	if boss_box.visible and boss_target != null and is_instance_valid(boss_target):
		boss_bar.set_values(boss_target.hp, boss_target.max_hp)
		boss_bar.text = "%d" % int(ceil(boss_target.hp))

var boss_target: VCEnemy = null

func flash_damage() -> void:
	_vignette_a = 0.35

func set_objective(title: String, text: String) -> void:
	obj_title.text = title
	obj_text.text = text
	obj_panel.visible = text != ""

func objective_done(text: String) -> void:
	_obj_flash = 1.2
	toast("Objective complete: " + text, VCDefs.COL_GOOD)

func show_boss(e: VCEnemy) -> void:
	boss_target = e
	boss_name.text = e.display_name.to_upper()
	boss_bar.set_values(e.hp, e.max_hp)
	boss_bar.snap()
	boss_box.visible = true

func hide_boss() -> void:
	boss_target = null
	boss_box.visible = false

func banner(title: String, sub: String = "", color: Color = Color.WHITE, seconds: float = 3.0) -> void:
	banner_title.text = title
	banner_title.add_theme_color_override("font_color", color)
	banner_sub.text = sub
	_banner_t = seconds
	_banner_total = seconds
	banner_box.modulate.a = 0.0

func toast(text: String, color: Color = VCDefs.COL_TEXT, seconds: float = 3.0) -> void:
	var l := VCUI.label(text, 22, color, HORIZONTAL_ALIGNMENT_CENTER)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0, 0.1))
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_box.add_child(l)
	_toast_items.append({"node": l, "t": seconds})
	while _toast_items.size() > 5:
		var old: Dictionary = _toast_items.pop_front()
		(old["node"] as Node).queue_free()

func set_seed_text(t: String) -> void:
	seed_label.text = t

func set_visible_hud(v: bool) -> void:
	for c in get_children():
		c.visible = v
