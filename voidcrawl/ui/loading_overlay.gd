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
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(c)
	var v := VCUI.vbox(14)
	c.add_child(v)
	var logo := VCLogo.new()
	logo.custom_minimum_size = Vector2(620, 150)
	v.add_child(logo)
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

func set_progress(f: float, text: String) -> void:
	if bar != null:
		bar.set_values(f, 1.0)
		status.text = text
