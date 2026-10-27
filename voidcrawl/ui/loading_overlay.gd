class_name VCLoadingOverlay
extends CanvasLayer
## Full-screen loading card with a real progress bar (fed by the caller) and rotating tips.

const TIPS := [
	"Telegraphs fill red before every enemy attack. Dodge-roll through them.",
	"Cracked, glowing walls hide secret rooms. Strike them to break through.",
	"Higher rarity gear carries more affixes. Compare before you equip.",
	"Shrines restore health and potions, and save your place in the dungeon.",
	"The Void Nova stuns and breaks crates. Time it for crowds.",
	"Sprint by pushing the joystick all the way to its rim.",
]

var bar: VCBar
var status: Label
var tip: Label
var _logo: Control
var _t := 0.0
var _tip_t := 0.0
var _dots := ""
var _base_status := ""

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = VCUI.theme()
	add_child(root)
	var bg := ColorRect.new()
	bg.color = VCDefs.COL_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var fxl := VCLoadFx.new()
	fxl.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(fxl)
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(c)
	var v := VCUI.vbox(14)
	c.add_child(v)
	var logo := VCLogo.new()
	logo.custom_minimum_size = Vector2(620, 150)
	v.add_child(logo)
	_logo = logo
	status = VCUI.label("Preparing the descent...", 24, VCDefs.COL_VIOLET, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(status)
	bar = VCBar.new()
	bar.custom_minimum_size = Vector2(560, 18)
	bar.color = VCDefs.COL_PURPLE
	bar.show_ghost = false
	bar.set_values(0.0, 1.0)
	v.add_child(bar)
	tip = VCUI.label(String(TIPS[randi() % TIPS.size()]), 19, VCDefs.COL_TEXT_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.custom_minimum_size = Vector2(560, 0)
	v.add_child(tip)

func _process(delta: float) -> void:
	_t += delta
	if _logo != null:
		_logo.modulate = Color(1, 1, 1, 0.88 + 0.12 * sin(_t * 2.2))
		_logo.pivot_offset = _logo.size * 0.5
		_logo.scale = Vector2.ONE * (1.0 + 0.012 * sin(_t * 1.7))
	if status != null and _base_status != "":
		var n := int(_t * 2.5) % 4
		status.text = _base_status.trim_suffix("...").trim_suffix(".") + ".".repeat(n)
	if tip != null:
		_tip_t += delta
		if _tip_t > 3.2:
			_tip_t = 0.0
			tip.text = String(TIPS[randi() % TIPS.size()])
		tip.modulate.a = clampf(minf(_tip_t * 3.0, (3.2 - _tip_t) * 3.0), 0.0, 1.0)

func set_progress(f: float, text: String) -> void:
	if bar != null:
		bar.set_values(f, 1.0)
		_base_status = text
		status.text = text
