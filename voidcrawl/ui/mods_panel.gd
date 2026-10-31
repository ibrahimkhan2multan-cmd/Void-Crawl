class_name VCModsPanel
extends Control
## Install, enable, disable and remove data mods (.zip). The import button opens the phone's own
## file picker; the chosen zip is copied into the game's private mods folder.

signal closed

var _list: VBoxContainer
var _status: Label
var _dialog: FileDialog

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = VCUI.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.03, 0.85)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(cc)
	var panel := VCUI.panel()
	cc.add_child(panel)
	var v := VCUI.vbox(10)
	v.custom_minimum_size = Vector2(720, 0)
	panel.add_child(v)
	v.add_child(VCUI.label("MODS", 38, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
	var hint := VCUI.label("Mods add weapons, armour, mobs, dungeons, perks, pets, menu buttons and draggable menus. Import a .zip made for VOIDBORN. Mods cannot run code.", 17, VCDefs.COL_TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(680, 0)
	v.add_child(hint)
	var scroll := ScrollContainer.new()
	var vh := get_viewport_rect().size.y if is_inside_tree() else 720.0
	scroll.custom_minimum_size = Vector2(0, clampf(vh - 400.0, 150.0, 380.0))
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_list = VCUI.vbox(8)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.add_child(_list)
	var row := VCUI.hbox(10)
	v.add_child(row)
	var imp := VCUI.button("IMPORT MOD (.zip)", Vector2(350, 60), 22)
	imp.pressed.connect(_import)
	row.add_child(imp)
	var ex := VCUI.button("INSTALL EXAMPLE", Vector2(350, 60), 22)
	ex.pressed.connect(_example)
	row.add_child(ex)
	_status = VCUI.label("", 18, VCDefs.COL_GOOD, HORIZONTAL_ALIGNMENT_CENTER)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(680, 48)
	v.add_child(_status)
	var back := VCUI.button("BACK", Vector2(720, 56), 24)
	back.pressed.connect(func(): closed.emit())
	v.add_child(back)
	refresh()

func refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	if VCMods.list.is_empty():
		var e := VCUI.label("No mods installed yet.", 20, VCDefs.COL_TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
		_list.add_child(e)
		return
	for m in VCMods.list:
		_list.add_child(_card(m))

func _card(m: Dictionary) -> Control:
	var ok := bool(m["ok"])
	var on := bool(m["enabled"])
	var pc := VCUI.panel(Color(0.04, 0.02, 0.08, 0.95), Color(0.3, 0.16, 0.5) if ok else Color(0.7, 0.2, 0.25))
	pc.mouse_filter = Control.MOUSE_FILTER_PASS    # so a finger drag on a card still scrolls the list
	var v := VCUI.vbox(4)
	pc.add_child(v)
	var title := "%s  v%s" % [String(m["name"]), String(m["version"])]
	if String(m["author"]) != "":
		title += "  by %s" % String(m["author"])
	v.add_child(VCUI.label(title, 22, VCDefs.COL_TEXT if on else VCDefs.COL_TEXT_DIM))
	if String(m["description"]) != "":
		var d := VCUI.label(String(m["description"]), 16, VCDefs.COL_TEXT_DIM)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size = Vector2(640, 0)
		v.add_child(d)
	if ok:
		var bits: Array = []
		for k in ["items", "sets", "codes", "mobs", "levels", "perks", "pets", "buttons", "menus"]:
			if int(m.get(k, 0)) > 0:
				bits.append("%d %s" % [int(m[k]), k])
		var cl := VCUI.label("  -  ".join(bits), 16, VCDefs.COL_VIOLET)
		cl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cl.custom_minimum_size = Vector2(640, 0)
		v.add_child(cl)
	var errs: Array = m["errors"]
	if not errs.is_empty():
		var el := VCUI.label(("Problem: " if not ok else "Skipped: ") + String(errs[0]) + (" (+%d more)" % (errs.size() - 1) if errs.size() > 1 else ""), 15, VCDefs.COL_BAD)
		el.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		el.custom_minimum_size = Vector2(640, 0)
		v.add_child(el)
	var row := VCUI.hbox(8)
	v.add_child(row)
	if ok:
		var tg := VCUI.button("ON" if on else "OFF", Vector2(110, 46), 20)
		tg.pressed.connect(_toggle.bind(String(m["id"]), not on))
		row.add_child(tg)
	var rm := VCUI.button("REMOVE", Vector2(150, 46), 20)
	rm.pressed.connect(_remove.bind(String(m["id"])))
	row.add_child(rm)
	return pc

func _say(text: String, good: bool) -> void:
	_status.text = text
	_status.add_theme_color_override("font_color", VCDefs.COL_GOOD if good else VCDefs.COL_BAD)

func _toggle(id: String, on: bool) -> void:
	var r := VCMods.set_enabled(id, on)
	_say(("Mod enabled." if on else "Mod disabled.") + VCMods.reconcile_text(r), true)
	VC.play_sfx("click", -6.0)
	refresh()

func _remove(id: String) -> void:
	var r := VCMods.remove(id)
	_say("Mod removed." + VCMods.reconcile_text(r), true)
	VC.play_sfx("click", -6.0)
	refresh()

func _example() -> void:
	var r := VCMods.install_example()
	_say(String(r["msg"]) + ("  Look for the SUNFIRE HUB button on the main menu!" if bool(r["ok"]) else ""), bool(r["ok"]))
	refresh()

func _import() -> void:
	if _dialog != null:
		_dialog.queue_free()
	_dialog = FileDialog.new()
	_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_dialog.use_native_dialog = true
	_dialog.filters = PackedStringArray(["*.zip ; Mod packs"])
	_dialog.title = "Choose a mod .zip"
	_dialog.file_selected.connect(_on_file)
	add_child(_dialog)
	_dialog.popup_centered_ratio(0.85)

func _on_file(path: String) -> void:
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		_say("Could not read that file (%s). Try copying the zip to your Downloads folder." % FileAccess.get_open_error(), false)
		return
	var r := VCMods.install_bytes(bytes)
	_say(String(r["msg"]), bool(r["ok"]))
	if bool(r["ok"]):
		VC.play_sfx("levelup", -4.0)
	refresh()
