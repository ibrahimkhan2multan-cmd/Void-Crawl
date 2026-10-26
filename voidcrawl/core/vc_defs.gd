class_name VCDefs
extends RefCounted
## Shared constants for VOIDCRAWL (Infinity Studios). Pure data, no logic.

const GAME_NAME := "VOIDBORN"
const STUDIO := "Infinity Studios"
const VERSION := "0.1.0"
const SAVE_VERSION := 1

# --- Physics layers (bit values) -------------------------------------------
const L_WORLD := 1
const L_PLAYER := 2
const L_ENEMY := 4
const L_INTERACT := 8
const L_PROP := 16

# --- Grid ------------------------------------------------------------------
const TILE := 2.0          # metres per dungeon tile
const WALL_H := 2.6        # metres

# --- Items -----------------------------------------------------------------
enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }
const RARITY_NAMES := ["Common", "Uncommon", "Rare", "Epic", "Legendary"]
const RARITY_COLORS := [
	Color(0.78, 0.78, 0.84),
	Color(0.36, 0.88, 0.50),
	Color(0.38, 0.58, 1.00),
	Color(0.74, 0.34, 1.00),
	Color(1.00, 0.66, 0.18),
]
const RARITY_WEIGHTS := [58.0, 26.0, 11.0, 4.0, 1.0]
const RARITY_STAT_MULT := [1.0, 1.15, 1.35, 1.65, 2.05]
const RARITY_AFFIX_COUNT := [0, 1, 2, 3, 4]
const RARITY_SELL := [4, 10, 28, 80, 240]

enum Slot { WEAPON, HELM, ARMOR, TRINKET, BOOTS }
const SLOT_NAMES := ["Weapon", "Helm", "Armor", "Trinket", "Boots"]
const SLOT_COUNT := 5

# --- UI palette (black + purple) --------------------------------------------
const COL_BG := Color("07040d")
const COL_PANEL := Color("120b1f")
const COL_PANEL_LIGHT := Color("1d1230")
const COL_STONE := Color("2a2533")
const COL_PURPLE := Color("8a3cff")
const COL_VIOLET := Color("c18bff")
const COL_MAGENTA := Color("e04bff")
const COL_TEXT := Color("ece4ff")
const COL_TEXT_DIM := Color("9a8bb8")
const COL_HP := Color("e0305a")
const COL_XP := Color("9a5cff")
const COL_COIN := Color("ffcf4a")
const COL_GOOD := Color("5be08a")
const COL_BAD := Color("ff5a6e")

# --- Enemy / boss ids -------------------------------------------------------
const ENEMY_HUSK := "husk"
const ENEMY_SLINGER := "slinger"
const ENEMY_WISP := "wisp"
const ENEMY_BRUTE := "brute"
const ENEMY_SPIDER := "spiderling"
const ENEMY_WARDEN := "warden"
const ENEMY_SHIELD := "shieldbearer"
const ENEMY_MITE := "embermite"
const ENEMY_CULTIST := "cultist"
const ENEMY_WEAVER := "necromancer"
const ENEMY_COLOSSUS := "colossus"
const ENEMY_FROSTWRAITH := "frostwraith"
const ENEMY_ICEARCHER := "icearcher"
const ENEMY_YETI := "yeti"
const ENEMY_FROSTMAW := "frostmaw"

# --- Attributes -------------------------------------------------------------
const ATTR_IDS := ["str", "vit", "agi", "arc"]
const ATTR_NAMES := {
	"str": "Might",
	"vit": "Vitality",
	"agi": "Agility",
	"arc": "Arcana",
}
const ATTR_DESC := {
	"str": "+4% weapon damage per point",
	"vit": "+8 max health per point",
	"agi": "+0.8% move speed, +0.4% crit chance per point",
	"arc": "+6% ability damage, -1% cooldowns per point",
}

static func rarity_color(r: int) -> Color:
	return RARITY_COLORS[clampi(r, 0, RARITY_COLORS.size() - 1)]

static func rarity_name(r: int) -> String:
	return RARITY_NAMES[clampi(r, 0, RARITY_NAMES.size() - 1)]
