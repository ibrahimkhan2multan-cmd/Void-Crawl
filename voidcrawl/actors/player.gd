class_name VCPlayer
extends CharacterBody3D
## The Voidwalker. Reads VCInput, owns combat state, and pulls every number from
## VCProfile.derived() so equipment, attributes and level change real gameplay.

signal died
signal damaged(amount, hp, max_hp)
signal healed(amount)
signal attacked
signal dodged
signal ability_used
signal potion_used
signal bomb_thrown

enum S { IDLE, ATTACK, DODGE, DEAD }

const HIT_RADIUS := 0.5
const CRIT_MULT := 1.75
const DODGE_TIME := 0.38
const DODGE_IFRAMES := 0.32
const DODGE_CD := 0.75
const NOVA_BASE_CD := 9.0
const NOVA_RADIUS := 5.4
const POTION_CD := 1.2

var world: Node = null
var profile: VCProfile
var stats: Dictionary = {}
var hp := 100.0
var max_hp := 100
var state: int = S.IDLE
var hit_radius := HIT_RADIUS
var facing := 0.0                    # yaw radians (0 = -Z)
var cam_yaw := 0.0                   # camera yaw, used to turn joystick into world movement
var invuln := 0.0
var combo := 0
var combo_timer := 0.0
var dodge_cd := 0.0
var nova_cd := 0.0
var potion_cd := 0.0
var bomb_cd := 0.0
var attack_cd := 0.0
var god_mode := false
var _since_hurt := 99.0
const REGEN_DELAY := 3.5            # seconds without being hit before slow regeneration starts
const REGEN_PCT := 0.012            # of max HP per second                # tests / debug only

var _attack_t := 0.0
var _attack_total := 0.4
var _attack_hit_at := 0.16
var _attack_hit_done := false
var _attack_mult := 1.0
var _attack_dir := Vector3.FORWARD
var _dodge_t := 0.0
var _dodge_dir := Vector3.FORWARD
var _knock := Vector3.ZERO
var _buffered_attack := 0.0
var _heal_pool := 0.0
var _anim_t := 0.0
var _flash := 0.0
var _coll: CollisionShape3D

# rig
var rig: Node3D
var _torso: MeshInstance3D
var _head: MeshInstance3D
var _hood_grp: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _weapon_root: Node3D
var _cape: MeshInstance3D
var _helm_part: MeshInstance3D
var _boot_l: MeshInstance3D
var _boot_r: MeshInstance3D
var _parts: Array = []
var _light: OmniLight3D
var armor_fx: VCArmorFx = null
var _fs_t := 0.0        # friendship-sword sparkle timer
var _fs_orbs: Array = []
var _dust_t := 0.0
var _pose_t := 0.0      # victory / level-up pose timer
var _pose_kind := ""

func _ready() -> void:
	collision_layer = VCDefs.L_PLAYER
	collision_mask = VCDefs.L_WORLD | VCDefs.L_PROP
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	_coll = CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.42
	cap.height = 1.5
	_coll.shape = cap
	_coll.position = Vector3(0, 0.8, 0)
	add_child(_coll)
	_build_rig()
	armor_fx = VCArmorFx.new()
	armor_fx.setup(self, rig)
	add_child(armor_fx)
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.78, 0.55)     # warm lantern so the hero pops against cool stone
	_light.light_energy = 1.1
	_light.omni_range = 8.0
	_light.position = Vector3(0, 2.4, 0.6)
	if VCCrashGuard.level >= 2:
		_light.free()
		_light = null
	else:
		add_child(_light)
	name = "Player"

func bind(p: VCProfile) -> void:
	profile = p
	refresh_stats(true)
	refresh_visuals()

func is_alive() -> bool:
	return state != S.DEAD

# ------------------------------------------------------------------- stats
func refresh_stats(full_heal: bool = false) -> void:
	var old_max := max_hp
	stats = profile.derived()
	max_hp = int(stats["max_hp"])
	if full_heal:
		hp = float(max_hp)
	else:
		# keep the same missing-health, so equipping a helm gives real extra health
		hp = clampf(hp + float(max_hp - old_max), 1.0, float(max_hp))

func cooldown_fraction(which: String) -> float:
	match which:
		"dodge": return clampf(dodge_cd / DODGE_CD, 0.0, 1.0)
		"ability": return clampf(nova_cd / (NOVA_BASE_CD * float(stats["cd_mult"])), 0.0, 1.0)
		"heal": return clampf(potion_cd / POTION_CD, 0.0, 1.0)
		"bomb": return clampf(bomb_cd / 1.2, 0.0, 1.0)
	return 0.0

# ------------------------------------------------------------------ rig
func _mk(parent: Node3D, size: Vector3, pos: Vector3, col: Color, em: float = 0.0, style: String = "") -> MeshInstance3D:
	var mi := VCMats.part(parent, size, pos, col, em, "", style)
	_parts.append(mi)
	return mi

func _build_rig() -> void:
	rig = Node3D.new()
	rig.name = "Rig"
	add_child(rig)
	var cloth := Color(0.42, 0.27, 0.72)
	var cloth_dk := Color(0.27, 0.2, 0.42)
	var skin := Color(0.78, 0.65, 0.58)
	var gold := Color(0.95, 0.8, 0.35)
	var steel := Color(0.62, 0.62, 0.74)
	_leg_l = Node3D.new(); _leg_l.position = Vector3(-0.16, 0.62, 0); rig.add_child(_leg_l)
	_leg_r = Node3D.new(); _leg_r.position = Vector3(0.16, 0.62, 0); rig.add_child(_leg_r)
	for leg in [_leg_l, _leg_r]:
		_mk(leg, Vector3(0.24, 0.62, 0.26), Vector3(0, -0.31, 0), cloth_dk)
		_mk(leg, Vector3(0.27, 0.12, 0.29), Vector3(0, -0.2, 0), steel)                     # knee pad
		_mk(leg, Vector3(0.3, 0.1, 0.32), Vector3(0, -0.47, -0.01), Color(0.3, 0.22, 0.2), 0.0, "leather")  # boot cuff
	_boot_l = _mk(_leg_l, Vector3(0.28, 0.2, 0.36), Vector3(0, -0.56, -0.04), Color(0.2, 0.16, 0.24))
	_boot_r = _mk(_leg_r, Vector3(0.28, 0.2, 0.36), Vector3(0, -0.56, -0.04), Color(0.2, 0.16, 0.24))
	_mk(_leg_l, Vector3(0.3, 0.05, 0.38), Vector3(0, -0.66, -0.04), Color(0.1, 0.08, 0.12))   # sole
	_mk(_leg_r, Vector3(0.3, 0.05, 0.38), Vector3(0, -0.66, -0.04), Color(0.1, 0.08, 0.12))
	_torso = _mk(rig, Vector3(0.62, 0.7, 0.36), Vector3(0, 0.98, 0), cloth)
	_mk(rig, Vector3(0.22, 0.52, 0.04), Vector3(0, 0.9, -0.19), Color(0.5, 0.32, 0.85))        # tabard panel
	_mk(rig, Vector3(0.24, 0.05, 0.05), Vector3(0, 0.66, -0.2), gold, 0.4, "plate")             # tabard hem
	_mk(rig, Vector3(0.66, 0.1, 0.4), Vector3(0, 0.66, 0), Color(0.55, 0.3, 0.9), 0.6)       # belt
	_mk(rig, Vector3(0.12, 0.12, 0.05), Vector3(0, 0.66, -0.21), gold, 0.8, "plate")            # belt buckle
	_mk(rig, Vector3(0.14, 0.18, 0.12), Vector3(0.36, 0.6, -0.04), Color(0.4, 0.28, 0.2), 0.0, "leather")  # hip pouch
	_cape = _mk(rig, Vector3(0.58, 0.9, 0.08), Vector3(0, 0.95, 0.24), Color(0.12, 0.62, 0.7))
	_head = _mk(rig, Vector3(0.42, 0.42, 0.42), Vector3(0, 1.58, 0), skin, 0.0, "skin")
	# hood: separate pieces around the head (never a box that encloses the face, which z-fought with the skin)
	_hood_grp = Node3D.new()
	_hood_grp.name = "Hood"
	rig.add_child(_hood_grp)
	var hc := Color(0.3, 0.2, 0.5)
	_mk(_hood_grp, Vector3(0.6, 0.52, 0.1), Vector3(0, 1.62, 0.27), hc)                    # back
	_mk(_hood_grp, Vector3(0.1, 0.5, 0.5), Vector3(-0.27, 1.6, 0.04), hc * 0.92)           # left side
	_mk(_hood_grp, Vector3(0.1, 0.5, 0.5), Vector3(0.27, 1.6, 0.04), hc * 0.92)            # right side
	_mk(_hood_grp, Vector3(0.66, 0.1, 0.66), Vector3(0, 1.86, 0.04), hc * 1.08)            # top
	_mk(_hood_grp, Vector3(0.46, 0.09, 0.06), Vector3(0, 1.77, -0.24), Color(0.2, 0.13, 0.35))   # brow band (hairline)
	_mk(_hood_grp, Vector3(0.14, 0.2, 0.14), Vector3(0, 2.02, 0.2), hc)                    # hood tip
	_mk(rig, Vector3(0.09, 0.09, 0.04), Vector3(-0.1, 1.58, -0.24), Color(1.0, 1.0, 1.0), 1.5)    # eyes: white
	_mk(rig, Vector3(0.09, 0.09, 0.04), Vector3(0.1, 1.58, -0.24), Color(1.0, 1.0, 1.0), 1.5)
	_mk(rig, Vector3(0.05, 0.06, 0.045), Vector3(-0.1, 1.58, -0.255), Color(0.55, 0.3, 1.0), 2.4)  # pupils
	_mk(rig, Vector3(0.05, 0.06, 0.045), Vector3(0.1, 1.58, -0.255), Color(0.55, 0.3, 1.0), 2.4)
	_mk(rig, Vector3(0.12, 0.03, 0.04), Vector3(0, 1.47, -0.24), Color(0.5, 0.3, 0.3))        # mouth
	_helm_part = _mk(rig, Vector3(0.5, 0.2, 0.5), Vector3(0, 1.84, 0.02), Color(0.6, 0.58, 0.68))
	_mk(rig, Vector3(0.3, 0.14, 0.44), Vector3(-0.4, 1.35, 0), Color(0.7, 0.68, 0.82), 0.0, "plate")  # pauldrons
	_mk(rig, Vector3(0.3, 0.14, 0.44), Vector3(0.4, 1.35, 0), Color(0.7, 0.68, 0.82), 0.0, "plate")
	_mk(rig, Vector3(0.14, 0.08, 0.3), Vector3(-0.44, 1.44, 0), gold, 0.5)
	_mk(rig, Vector3(0.14, 0.08, 0.3), Vector3(0.44, 1.44, 0), gold, 0.5)
	_mk(rig, Vector3(0.2, 0.2, 0.06), Vector3(0, 1.05, -0.2), Color(0.3, 0.95, 1.0), 2.0)      # chest gem
	_mk(rig, Vector3(0.28, 0.28, 0.03), Vector3(0, 1.05, -0.19), gold, 0.5, "plate")           # gem setting
	_mk(rig, Vector3(0.66, 0.1, 0.4), Vector3(0, 1.36, 0), Color(0.12, 0.62, 0.7))            # scarf
	_mk(rig, Vector3(0.12, 0.34, 0.06), Vector3(-0.2, 1.17, 0.2), Color(0.12, 0.62, 0.7))    # scarf tails
	_mk(rig, Vector3(0.12, 0.26, 0.06), Vector3(0.0, 1.2, 0.21), Color(0.1, 0.52, 0.6))
	VCMats.add_blob(self, 1.5)
	_arm_l = Node3D.new(); _arm_l.position = Vector3(-0.42, 1.28, 0); rig.add_child(_arm_l)
	_arm_r = Node3D.new(); _arm_r.position = Vector3(0.42, 1.28, 0); rig.add_child(_arm_r)
	for arm in [_arm_l, _arm_r]:
		_mk(arm, Vector3(0.2, 0.62, 0.22), Vector3(0, -0.28, 0), cloth * 1.1)
		_mk(arm, Vector3(0.23, 0.2, 0.25), Vector3(0, -0.44, 0), Color(0.3, 0.22, 0.2), 0.0, "leather")   # bracer
		_mk(arm, Vector3(0.22, 0.16, 0.24), Vector3(0, -0.62, 0), skin, 0.0, "skin")
		_mk(arm, Vector3(0.24, 0.08, 0.26), Vector3(0, -0.55, 0), Color(0.22, 0.17, 0.2), 0.0, "leather")  # glove cuff
	_weapon_root = Node3D.new()
	_weapon_root.position = Vector3(0, -0.62, -0.1)
	_arm_r.add_child(_weapon_root)

func is_friend_sword() -> bool:
	if profile == null:
		return false
	var wp: Dictionary = profile.equipment.get(VCDefs.Slot.WEAPON, {})
	return not wp.is_empty() and String(wp.get("base", "")) == "infinity_edge"

## The Power of Friendship: two-tone blade (cyan | magenta), gold guard, orbiting sparkles.
func _build_friend_sword(wp: Dictionary) -> void:
	_fs_orbs.clear()
	if wp.is_empty() or String(wp.get("base", "")) != "infinity_edge":
		return
	for c in _weapon_root.get_children():
		c.queue_free()
	VCMats.part(_weapon_root, Vector3(0.09, 0.12, 0.46), Vector3(0, 0, 0.1), Color(0.95, 0.8, 0.3), 0.6)
	VCMats.part(_weapon_root, Vector3(0.42, 0.08, 0.08), Vector3(0, 0, -0.14), Color(1.0, 0.85, 0.35), 1.2)
	VCMats.part(_weapon_root, Vector3(0.06, 0.06, 0.06), Vector3(0, 0.0, 0.34), Color(1.0, 0.4, 0.75), 2.2)
	VCMats.part(_weapon_root, Vector3(0.05, 0.05, 1.02), Vector3(-0.045, 0, -0.68), Color(0.35, 0.95, 1.0), 2.2)
	VCMats.part(_weapon_root, Vector3(0.05, 0.05, 1.02), Vector3(0.045, 0, -0.68), Color(1.0, 0.4, 0.8), 2.2)
	VCMats.part(_weapon_root, Vector3(0.12, 0.05, 0.12), Vector3(0, 0, -1.22), Color(1.0, 0.95, 0.8), 3.0)
	for i in 3:
		var o := VCMats.part(_weapon_root, Vector3(0.07, 0.07, 0.07), Vector3(0, 0, -0.7), Color(0.4, 1.0, 1.0) if i % 2 == 0 else Color(1.0, 0.5, 0.85), 3.0)
		_fs_orbs.append({"n": o, "ph": TAU * float(i) / 3.0})

func refresh_visuals() -> void:
	if profile == null:
		return
	for c in _weapon_root.get_children():
		c.queue_free()
	var wp: Dictionary = profile.equipment.get(VCDefs.Slot.WEAPON, {})
	var kind := "fist"
	var wcol := Color(0.8, 0.8, 0.9)
	var rar := 0
	if not wp.is_empty():
		kind = String(VCItems.BASES[wp["base"]]["kind"])
		wcol = VCItems.base_color(wp)
		rar = int(wp["rarity"])
	var glow := VCDefs.rarity_color(rar)
	var em := 0.0 if rar < 2 else 1.2
	var W := _weapon_root
	var wood := Color(0.34, 0.24, 0.17)
	var gold := Color(0.95, 0.8, 0.35)
	var dark := Color(0.2, 0.2, 0.26)
	match kind:
		"sword":
			VCMats.part(W, Vector3(0.09, 0.12, 0.4), Vector3(0, 0, 0.12), Color(0.3, 0.2, 0.15), 0.0, "", "leather")      # grip
			VCMats.part(W, Vector3(0.14, 0.14, 0.12), Vector3(0, 0, 0.36), gold, 0.3, "", "plate")                          # pommel
			VCMats.part(W, Vector3(0.4, 0.08, 0.09), Vector3(0, 0, -0.1), gold * 0.9, 0.2, "", "plate")                     # crossguard
			VCMats.part(W, Vector3(0.09, 0.14, 0.12), Vector3(-0.2, 0, -0.1), gold, 0.3)
			VCMats.part(W, Vector3(0.09, 0.14, 0.12), Vector3(0.2, 0, -0.1), gold, 0.3)
			VCMats.part(W, Vector3(0.12, 0.05, 0.78), Vector3(0, 0, -0.53), wcol, em, "", "metal")                          # blade
			VCMats.part(W, Vector3(0.07, 0.05, 0.3), Vector3(0, 0, -1.07), wcol, em, "", "metal")                           # taper
			VCMats.part(W, Vector3(0.03, 0.05, 0.12), Vector3(0, 0, -1.28), wcol, em, "", "metal")                          # tip
			VCMats.part(W, Vector3(0.04, 0.062, 0.82), Vector3(0, 0, -0.55), wcol.darkened(0.35), 0.0, "", "metal")       # fuller groove
			if rar >= 2:
				VCMats.part(W, Vector3(0.016, 0.06, 1.0), Vector3(-0.065, 0, -0.62), glow, 2.0)                              # glowing edges
				VCMats.part(W, Vector3(0.016, 0.06, 1.0), Vector3(0.065, 0, -0.62), glow, 2.0)
		"axe":
			VCMats.part(W, Vector3(0.09, 0.09, 1.1), Vector3(0, 0, -0.2), wood, 0.0, "", "leather")
			VCMats.part(W, Vector3(0.1, 0.1, 0.14), Vector3(0, 0, 0.36), dark, 0.0, "", "plate")
			VCMats.part(W, Vector3(0.1, 0.5, 0.4), Vector3(0, 0.12, -0.72), wcol, em, "", "metal")                           # head
			VCMats.part(W, Vector3(0.08, 0.34, 0.2), Vector3(0, 0.2, -0.98), wcol * 1.1, em, "", "metal")                   # bit
			VCMats.part(W, Vector3(0.1, 0.5, 0.06), Vector3(0, 0.12, -1.0), glow if rar >= 2 else wcol * 1.3, 1.2 if rar >= 2 else 0.2)  # sharp edge
			VCMats.part(W, Vector3(0.07, 0.2, 0.14), Vector3(0, -0.22, -0.7), dark)                                          # back spike
		"dagger":
			VCMats.part(W, Vector3(0.08, 0.1, 0.24), Vector3(0, 0, 0.1), Color(0.3, 0.2, 0.15), 0.0, "", "leather")
			VCMats.part(W, Vector3(0.12, 0.12, 0.07), Vector3(0, 0, 0.24), gold, 0.3)
			VCMats.part(W, Vector3(0.26, 0.07, 0.07), Vector3(0, 0, -0.04), gold * 0.9, 0.2)
			VCMats.part(W, Vector3(0.08, 0.04, 0.46), Vector3(0, 0, -0.3), wcol, em, "", "metal")
			VCMats.part(W, Vector3(0.04, 0.04, 0.18), Vector3(0, 0, -0.62), wcol, em, "", "metal")
			if rar >= 2:
				VCMats.part(W, Vector3(0.02, 0.05, 0.6), Vector3(0, 0, -0.36), glow, 2.0)
		"spear":
			VCMats.part(W, Vector3(0.07, 0.07, 1.7), Vector3(0, 0, -0.5), wood, 0.0, "", "leather")
			VCMats.part(W, Vector3(0.12, 0.05, 0.5), Vector3(0, 0, -1.5), wcol, em, "", "metal")
			VCMats.part(W, Vector3(0.06, 0.05, 0.22), Vector3(0, 0, -1.84), wcol, em, "", "metal")
			VCMats.part(W, Vector3(0.22, 0.05, 0.1), Vector3(0, 0, -1.22), glow, 0.8)
			VCMats.part(W, Vector3(0.08, 0.2, 0.1), Vector3(0, 0, -1.2), dark)                                               # collar
			VCMats.part(W, Vector3(0.1, 0.1, 0.12), Vector3(0, 0, 0.36), dark)
		"hammer":
			VCMats.part(W, Vector3(0.1, 0.1, 1.3), Vector3(0, 0, -0.3), wood, 0.0, "", "leather")
			VCMats.part(W, Vector3(0.52, 0.44, 0.64), Vector3(0, 0.05, -1.0), wcol, em, "", "stone")
			VCMats.part(W, Vector3(0.56, 0.1, 0.1), Vector3(0, 0.05, -1.0), glow, 1.0)
			VCMats.part(W, Vector3(0.56, 0.5, 0.1), Vector3(0, 0.05, -0.7), dark, 0.0, "", "plate")                         # bands
			VCMats.part(W, Vector3(0.56, 0.5, 0.1), Vector3(0, 0.05, -1.3), dark, 0.0, "", "plate")
			VCMats.part(W, Vector3(0.16, 0.16, 0.16), Vector3(0, 0, 0.4), dark, 0.0, "", "plate")
		"crossbow":
			VCMats.part(W, Vector3(0.1, 0.12, 0.76), Vector3(0, 0, -0.3), Color(0.32, 0.22, 0.15), 0.0, "", "leather")
			VCMats.part(W, Vector3(0.96, 0.06, 0.08), Vector3(0, 0, -0.62), wcol, em, "", "metal")
			VCMats.part(W, Vector3(0.1, 0.1, 0.1), Vector3(-0.5, 0, -0.55), dark)
			VCMats.part(W, Vector3(0.1, 0.1, 0.1), Vector3(0.5, 0, -0.55), dark)
			VCMats.part(W, Vector3(0.04, 0.04, 0.6), Vector3(0, 0.08, -0.5), glow, 1.0)
			VCMats.part(W, Vector3(0.02, 0.02, 0.5), Vector3(0, 0, -0.35), Color(0.9, 0.9, 0.8))                              # string
			VCMats.part(W, Vector3(0.08, 0.18, 0.12), Vector3(0, -0.14, -0.1), Color(0.28, 0.2, 0.14))                         # trigger grip
		"staff":
			VCMats.part(W, Vector3(0.08, 0.08, 1.6), Vector3(0, 0, -0.4), Color(0.3, 0.2, 0.14), 0.0, "", "leather")
			VCMats.part(W, Vector3(0.3, 0.3, 0.3), Vector3(0, 0, -1.3), wcol, 1.8).material_override = VCMats.solid(wcol, 1.8)
			VCMats.part(W, Vector3(0.44, 0.06, 0.44), Vector3(0, 0, -1.3), glow, 1.2)
			VCMats.part(W, Vector3(0.06, 0.44, 0.44), Vector3(0, 0, -1.3), glow, 1.2)
			for sx in [-1.0, 1.0]:
				VCMats.part(W, Vector3(0.06, 0.34, 0.06), Vector3(sx * 0.2, 0, -1.2), Color(0.35, 0.25, 0.18), 0.0, "", "leather").rotation.y = sx * 0.4   # prongs
			VCMats.part(W, Vector3(0.12, 0.12, 0.12), Vector3(0, 0, 0.4), gold, 0.3)
		"bow":
			VCMats.part(W, Vector3(0.06, 1.1, 0.08), Vector3(0, 0, -0.2), wcol, em, "", "leather")
			VCMats.part(W, Vector3(0.05, 0.5, 0.05), Vector3(0, 0.55, -0.1), wcol * 0.9, 0.0, "", "leather").rotation.x = 0.7
			VCMats.part(W, Vector3(0.05, 0.5, 0.05), Vector3(0, -0.55, -0.1), wcol * 0.9, 0.0, "", "leather").rotation.x = -0.7
			VCMats.part(W, Vector3(0.02, 1.3, 0.02), Vector3(0, 0, 0.1), Color(0.92, 0.9, 0.82))                               # string
			VCMats.part(W, Vector3(0.1, 0.16, 0.1), Vector3(0, 0, -0.2), gold, 0.3)                                           # grip wrap
			if rar >= 2:
				VCMats.part(W, Vector3(0.02, 1.1, 0.02), Vector3(0, 0, -0.26), glow, 1.6)
		_:
			pass
	# armour tint
	var arm: Dictionary = profile.equipment.get(VCDefs.Slot.ARMOR, {})
	if arm.is_empty():
		_torso.material_override = VCMats.solid(Color(0.2, 0.12, 0.34))
	else:
		var ac := VCItems.base_color(arm).lerp(VCDefs.rarity_color(int(arm["rarity"])), 0.25)
		_torso.material_override = VCMats.solid(ac, 0.2 if int(arm["rarity"]) >= 3 else 0.0)
	var helm: Dictionary = profile.equipment.get(VCDefs.Slot.HELM, {})
	_helm_part.visible = false      # worn helms are drawn by VCArmorFx; this plain cap overlapped them (z-fight)
	if not helm.is_empty():
		_helm_part.material_override = VCMats.solid(VCItems.base_color(helm), 0.3 if int(helm["rarity"]) >= 3 else 0.0)
	var boots: Dictionary = profile.equipment.get(VCDefs.Slot.BOOTS, {})
	var bc := Color(0.2, 0.16, 0.24)
	var be := 0.0
	if not boots.is_empty():
		bc = VCItems.base_color(boots)
		be = 0.5 if int(boots["rarity"]) >= 3 else 0.0
	_boot_l.material_override = VCMats.solid(bc, be)
	_boot_r.material_override = VCMats.solid(bc, be)
	if _light != null:
		_light.light_color = Color(0.75, 0.55, 1.0).lerp(glow, 0.25)
	_build_friend_sword(wp)
	if armor_fx != null:
		armor_fx.refresh(profile.equipment)

# ----------------------------------------------------------------- tick
func _physics_process(delta: float) -> void:
	if profile == null or world == null:
		return
	_anim_t += delta
	dodge_cd = maxf(0.0, dodge_cd - delta)
	nova_cd = maxf(0.0, nova_cd - delta)
	potion_cd = maxf(0.0, potion_cd - delta)
	bomb_cd = maxf(0.0, bomb_cd - delta)
	attack_cd = maxf(0.0, attack_cd - delta)
	if VCTester.on("no_cd"):
		dodge_cd = 0.0
		nova_cd = 0.0
		bomb_cd = 0.0
		potion_cd = 0.0
	if VCTester.on("inf_items"):
		profile.potions = profile.max_potions()
		profile.bombs = profile.max_bombs()
	invuln = maxf(0.0, invuln - delta)
	_buffered_attack = maxf(0.0, _buffered_attack - delta)
	if combo_timer > 0.0:
		combo_timer -= delta
		if combo_timer <= 0.0:
			combo = 0
	_since_hurt += delta
	if state != S.DEAD and _since_hurt > REGEN_DELAY and hp < float(max_hp):
		hp = minf(hp + float(max_hp) * REGEN_PCT * delta * (1.0 + float(stats.get("regen_bonus", 0.0))), float(max_hp))
	if _heal_pool > 0.0:
		var h := minf(_heal_pool, float(max_hp) * 0.9 * delta)
		_heal_pool -= h
		hp = minf(hp + h, float(max_hp))
	if _flash > 0.0:
		_flash -= delta
		if _flash <= 0.0:
			_set_flash(false)
	if state == S.DEAD:
		_animate(delta, Vector2.ZERO)
		return

	var mv := VCInput.move_vector()
	var dir := _screen_to_world(mv)
	var accept_actions: bool = world.is_player_controllable()

	if accept_actions:
		if VCInput.take("dodge"):
			_try_dodge(dir)
		if VCInput.take("ability"):
			_try_nova()
		if VCInput.take("heal"):
			_try_potion()
		if VCInput.take("bomb"):
			_try_bomb()
		if VCInput.attack_held() or Input.is_action_just_pressed("vc_attack"):
			_buffered_attack = 0.25
	else:
		_buffered_attack = 0.0

	match state:
		S.IDLE:
			var spd: float = float(stats["move_speed"]) * (1.28 if VCInput.sprinting() and mv.length() > 0.5 else 1.0)
			var target_v := dir * spd * minf(mv.length() * 1.15, 1.0)
			velocity = velocity.lerp(target_v, clampf(delta * 16.0, 0.0, 1.0)) + _knock
			if dir.length() > 0.1:
				facing = lerp_angle(facing, atan2(-dir.x, -dir.z), clampf(delta * 18.0, 0.0, 1.0))
			if _buffered_attack > 0.0 and attack_cd <= 0.0 and accept_actions:
				_start_attack()
		S.ATTACK:
			_tick_attack(delta, dir)
		S.DODGE:
			_dodge_t -= delta
			velocity = _dodge_dir * 11.5 * clampf(_dodge_t / DODGE_TIME + 0.35, 0.35, 1.0)
			if _dodge_t <= 0.0:
				state = S.IDLE
	_knock = _knock.move_toward(Vector3.ZERO, 30.0 * delta)
	velocity.y = 0.0
	move_and_slide()
	global_position.y = 0.0
	_push_out_of_enemies()
	_animate(delta, mv)

func _screen_to_world(mv: Vector2) -> Vector3:
	if mv.length() < 0.001:
		return Vector3.ZERO
	var v := Vector3(mv.x, 0.0, mv.y)
	return v.rotated(Vector3.UP, cam_yaw).normalized() * minf(mv.length(), 1.0)

func _push_out_of_enemies() -> void:
	for e in world.enemies:
		if not e.is_alive() or e.non_solid:
			continue
		var d: Vector3 = global_position - e.global_position
		d.y = 0.0
		var min_d: float = hit_radius * 0.7 + e.hit_radius * 0.7
		var dl: float = d.length()
		if dl < min_d and dl > 0.001:
			global_position += d.normalized() * (min_d - dl) * 0.5

# ---------------------------------------------------------------- attack
func _weapon_interval() -> float:
	return float(stats["interval"])

func _pick_target() -> Dictionary:
	# auto-aim: nearest enemy/breakable in a generous cone ahead, otherwise attack where you face
	var reach: float = float(stats["range"]) + (4.0 if bool(stats["ranged"]) else 1.4)
	var best = null
	var best_score := 1e9
	var fwd := Vector3(-sin(facing), 0, -cos(facing))
	var move_dir := _screen_to_world(VCInput.move_vector())
	if move_dir.length() > 0.3:
		fwd = move_dir.normalized()
	for list in [world.enemies, world.breakables]:
		for t in list:
			if not t.is_alive():
				continue
			var to_t: Vector3 = t.global_position - global_position
			to_t.y = 0.0
			var d := to_t.length()
			if d > reach + t.hit_radius:
				continue
			var ang := rad_to_deg(fwd.angle_to(to_t.normalized())) if d > 0.05 else 0.0
			if ang > 85.0 and d > 1.6:
				continue
			var score := d + ang * 0.02
			if t is VCBreakable:
				score += 2.0                # prefer enemies over crates
			if score < best_score:
				best_score = score
				best = t
	if best == null:
		return {"dir": fwd, "target": null}
	var dv: Vector3 = best.global_position - global_position
	dv.y = 0.0
	return {"dir": dv.normalized(), "target": best}

func _start_attack() -> void:
	var pick := _pick_target()
	_attack_dir = pick["dir"]
	facing = atan2(-_attack_dir.x, -_attack_dir.z)
	var interval := _weapon_interval()
	_attack_total = interval
	_attack_hit_at = interval * 0.38
	_attack_hit_done = false
	var ranged: bool = bool(stats["ranged"])
	if ranged:
		_attack_mult = 1.0
		combo = 0
	else:
		_attack_mult = [1.0, 1.0, 1.45][combo % 3]
	_attack_t = 0.0
	state = S.ATTACK
	_buffered_attack = 0.0
	world.play_sfx("shoot" if ranged else "swing", -4.0, 1.0 + 0.08 * float(combo % 3))
	attacked.emit()

func _tick_attack(delta: float, dir: Vector3) -> void:
	_attack_t += delta
	# You can keep moving while you swing. Standing still gives the little lunge forward;
	# steering keeps most of your speed (more with ranged weapons).
	var mv_len := VCInput.move_vector().length()
	var ranged_w: bool = bool(stats["ranged"])
	var steer := (0.9 if ranged_w else 0.7) * float(stats["move_speed"])
	var target_v := dir * steer * minf(mv_len * 1.15, 1.0)
	if mv_len < 0.2 and not ranged_w and _attack_t < _attack_hit_at:
		target_v = _attack_dir * (3.2 * (1.0 - _attack_t / _attack_hit_at) + 1.0)
	velocity = velocity.lerp(target_v, clampf(delta * 18.0, 0.0, 1.0)) + _knock
	if _attack_hit_done and mv_len > 0.2:
		facing = lerp_angle(facing, atan2(-dir.x, -dir.z), clampf(delta * 10.0, 0.0, 1.0))
	if not _attack_hit_done and _attack_t >= _attack_hit_at:
		_attack_hit_done = true
		_do_attack_hit()
	if _attack_t >= _attack_total:
		state = S.IDLE
		if not bool(stats["ranged"]):
			combo += 1
			combo_timer = 0.9
			if combo >= 3:
				combo = 0
				attack_cd = 0.12

func _do_attack_hit() -> void:
	var ranged: bool = bool(stats["ranged"])
	if ranged:
		var proj = world.get_projectile()
		if proj != null:
			var kind := String(stats.get("weapon_kind", "bow"))
			var col := Color(0.4, 1.0, 0.9)
			var spd := 21.0
			var sz := 0.3
			match kind:
				"crossbow":
					col = Color(1.0, 0.7, 0.35); spd = 30.0; sz = 0.34
				"staff":
					col = Color(0.55, 0.65, 1.0); spd = 16.0; sz = 0.4
			proj.fire(global_position + _attack_dir * 0.6, _attack_dir, spd, 0.0, false, col, sz, float(stats["range"]) / spd + 0.1, 2 if kind == "crossbow" else 0, 1.0)
		return
	var arc_deg: float = float(stats["arc"]) * (1.25 if combo % 3 == 2 else 1.0)
	var reach: float = float(stats["range"]) * (1.15 if combo % 3 == 2 else 1.0)
	var slash_col := Color(0.85, 0.65, 1.0) if combo % 3 != 2 else Color(1.0, 0.8, 1.0)
	if is_friend_sword():
		slash_col = Color(0.35, 0.95, 1.0) if combo % 2 == 0 else Color(1.0, 0.45, 0.85)
		if combo % 3 == 2:
			slash_col = Color(1.0, 0.9, 0.5)
	world.fx.slash(global_position, facing, reach, arc_deg, slash_col)
	var hits := 0
	for t in _targets_in_cone(reach, arc_deg):
		hit_target(t, _attack_mult, (3.5 if combo % 3 == 2 else 2.2) * (1.8 if String(stats.get("weapon_kind", "")) == "hammer" else 1.0))
		hits += 1
	if hits > 0:
		world.camera_shake(0.12 + 0.05 * float(combo % 3))
		if combo % 3 == 2:
			world.fx.ring(global_position, reach * 0.9, slash_col, 0.25)

func _targets_in_cone(reach: float, arc_deg: float) -> Array:
	var out: Array = []
	var fwd := Vector3(-sin(facing), 0, -cos(facing))
	for list in [world.enemies, world.breakables]:
		for t in list:
			if not t.is_alive():
				continue
			var to_t: Vector3 = t.global_position - global_position
			to_t.y = 0.0
			var d := to_t.length()
			if d > reach + t.hit_radius:
				continue
			if d < 0.9:
				out.append(t)
				continue
			if rad_to_deg(fwd.angle_to(to_t / d)) <= arc_deg * 0.5 + rad_to_deg(atan2(t.hit_radius, d)):
				out.append(t)
	return out

## Roll damage for one hit on `target` and apply it. Returns the damage dealt.
func hit_target(target: Node, mult: float, knock: float) -> float:
	var lo: float = float(stats["dmg_min"])
	var hi: float = float(stats["dmg_max"])
	var dmg := randf_range(lo, hi) * float(stats["dmg_mult"]) * mult * VCTester.hit_mult()
	var crit := randf() < float(stats["crit"])
	if crit:
		dmg *= CRIT_MULT
	dmg = maxf(1.0, round(dmg))
	var dealt: float = target.take_hit(dmg, global_position, crit, knock, self)
	if dealt > 0.0:
		var leech: float = float(stats["leech"])
		if leech > 0.0 and target is VCEnemy:
			hp = minf(hp + dealt * leech, float(max_hp))
		world.on_player_hit(target, dealt, crit)
	return dealt

func _tick_friend_sword(delta: float) -> void:
	if _fs_orbs.is_empty():
		return
	_fs_t += delta
	for o in _fs_orbs:
		var n: MeshInstance3D = o["n"]
		if is_instance_valid(n):
			var a: float = _fs_t * 5.0 + float(o["ph"])
			n.position = Vector3(cos(a) * 0.16, sin(a) * 0.16, -0.25 - fposmod(_fs_t * 0.9 + float(o["ph"]), 1.0) * 0.95)
			n.scale = Vector3.ONE * (0.6 + 0.6 * sin(_fs_t * 8.0 + float(o["ph"])))

## Short celebratory poses: "victory" (sword raised), "levelup" (hop + arms up), "equip" (little flex).
func play_pose(kind: String, dur: float = 1.4) -> void:
	_pose_kind = kind
	_pose_t = dur

func _tick_pose(delta: float) -> void:
	if _pose_t <= 0.0 or state == S.DEAD or state == S.ATTACK or state == S.DODGE:
		return
	_pose_t -= delta
	var k := clampf(_pose_t, 0.0, 1.0)
	match _pose_kind:
		"victory":
			_arm_r.rotation.x = lerpf(_arm_r.rotation.x, -3.0, 0.25)
			_arm_r.rotation.z = lerpf(_arm_r.rotation.z, -0.2, 0.25)
			_arm_l.rotation.x = lerpf(_arm_l.rotation.x, -0.6, 0.2)
			rig.position.y = absf(sin(_anim_t * 6.0)) * 0.12
		"levelup":
			var up := sin(clampf(1.0 - _pose_t / 1.2, 0.0, 1.0) * PI)
			rig.position.y = up * 0.6
			_arm_l.rotation.x = lerpf(_arm_l.rotation.x, -2.8, 0.3)
			_arm_r.rotation.x = lerpf(_arm_r.rotation.x, -2.8, 0.3)
		"equip":
			_arm_l.rotation.x = lerpf(_arm_l.rotation.x, -1.3, 0.3)
			_arm_r.rotation.x = lerpf(_arm_r.rotation.x, -1.3, 0.3)
			rig.rotation.y += delta * 6.0 * k
	if _pose_t <= 0.0:
		_pose_kind = ""

## Frostwarden 4-piece: a dodge leaves a freezing shockwave.
func _dodge_wave() -> void:
	var pct: float = float(stats.get("dodge_wave", 0.0))
	if pct <= 0.0:
		return
	var avg: float = (float(stats["dmg_min"]) + float(stats["dmg_max"])) * 0.5
	var col := Color(0.6, 0.9, 1.0)
	world.fx.ring(global_position, 3.2, col, 0.45)
	world.fx.burst(global_position + Vector3(0, 0.3, 0), col, 14, 5.0, 1.0)
	for list in [world.enemies, world.breakables]:
		for t in list.duplicate():
			if not t.is_alive():
				continue
			var d: float = Vector2(t.global_position.x - global_position.x, t.global_position.z - global_position.z).length()
			if d <= 3.2 + t.hit_radius:
				var dmg := maxf(1.0, round(avg * float(stats["dmg_mult"]) * pct))
				var dealt: float = t.take_hit(dmg, global_position, false, 4.0, self)
				if dealt > 0.0:
					world.on_player_hit(t, dealt, false)
					if t is VCEnemy:
						t.stun(0.6)

# ----------------------------------------------------------------- dodge
func _try_dodge(dir: Vector3) -> void:
	if state == S.DODGE or dodge_cd > 0.0 or state == S.DEAD:
		return
	_dodge_dir = dir if dir.length() > 0.1 else Vector3(-sin(facing), 0, -cos(facing))
	_dodge_dir = _dodge_dir.normalized()
	facing = atan2(-_dodge_dir.x, -_dodge_dir.z)
	_dodge_t = DODGE_TIME
	dodge_cd = DODGE_CD
	invuln = maxf(invuln, DODGE_IFRAMES)
	state = S.DODGE
	world.play_sfx("dodge", -3.0)
	world.fx.burst(global_position + Vector3(0, 0.2, 0), Color(0.6, 0.45, 0.9), 8, 2.5, 0.8)
	VC.vibrate(15)
	_dodge_wave()
	dodged.emit()

# --------------------------------------------------------------- ability
func _try_nova() -> void:
	if nova_cd > 0.0 or state == S.DEAD or state == S.DODGE:
		return
	nova_cd = NOVA_BASE_CD * float(stats["cd_mult"])
	var avg: float = (float(stats["dmg_min"]) + float(stats["dmg_max"])) * 0.5
	var mult: float = 2.3 * float(stats["ability_mult"])
	world.fx.ring(global_position, NOVA_RADIUS, Color(0.75, 0.4, 1.0), 0.5)
	world.fx.ring(global_position, NOVA_RADIUS * 0.6, Color(1.0, 0.8, 1.0), 0.35)
	world.fx.burst(global_position + Vector3(0, 0.5, 0), Color(0.8, 0.5, 1.0), 26, 8.0, 1.3)
	world.play_sfx("ability")
	world.camera_shake(0.45)
	VC.vibrate(40)
	var n := 0
	for list in [world.enemies, world.breakables]:
		for t in list.duplicate():
			if not t.is_alive():
				continue
			var d: float = Vector2(t.global_position.x - global_position.x, t.global_position.z - global_position.z).length()
			if d <= NOVA_RADIUS + t.hit_radius:
				var lo: float = float(stats["dmg_min"])
				var hi: float = float(stats["dmg_max"])
				var dmg := maxf(1.0, round(randf_range(lo, hi) * float(stats["dmg_mult"]) * mult))
				var dealt: float = t.take_hit(dmg, global_position, false, 7.0, self)
				if dealt > 0.0:
					world.on_player_hit(t, dealt, false)
					if t is VCEnemy:
						t.stun(0.9)
					n += 1
	invuln = maxf(invuln, 0.25)
	ability_used.emit()

# ------------------------------------------------------------------ bomb
func _try_bomb() -> void:
	if bomb_cd > 0.0 or state == S.DEAD or profile.bombs <= 0:
		return
	profile.bombs -= 1
	bomb_cd = 1.2
	var pick := _pick_target()
	var fwd: Vector3 = pick["dir"]
	var dist := 6.5
	if pick["target"] != null:
		dist = clampf((pick["target"].global_position - global_position).length(), 2.5, 9.0)
	var land := global_position + fwd * dist
	var tile: Vector2i = world.data.world_to_tile(land)
	if not world.data.is_floor(tile.x, tile.y):
		tile = world.data.nearest_floor(tile)
		land = world.data.tile_to_world(tile)
	var avg := (float(stats["dmg_min"]) + float(stats["dmg_max"])) * 0.5
	var dmg := (avg * 2.6 + 30.0) * float(stats["dmg_mult"]) * float(stats["ability_mult"])
	var b := VCBomb.new()
	b.world = world
	world.add_child(b)
	b.setup(global_position + Vector3(0, 1.4, 0), land, dmg)
	world.play_sfx("swing", -2.0, 0.7)
	bomb_thrown.emit()

# ---------------------------------------------------------------- potion
func _try_potion() -> void:
	if potion_cd > 0.0 or state == S.DEAD:
		return
	if profile.potions <= 0 or hp >= float(max_hp) - 0.5:
		return
	profile.potions -= 1
	potion_cd = POTION_CD
	var amt := float(max_hp) * profile.potion_heal_frac()
	_heal_pool += amt
	world.fx.number(global_position, "+%d" % int(amt), VCDefs.COL_GOOD, false)
	world.fx.burst(global_position + Vector3(0, 1.0, 0), VCDefs.COL_GOOD, 14, 3.0, 0.9)
	world.play_sfx("heal")
	healed.emit(amt)
	potion_used.emit()

func heal(amount: float, silent: bool = false) -> void:
	var before := hp
	hp = minf(hp + amount, float(max_hp))
	if not silent and hp > before:
		world.fx.number(global_position, "+%d" % int(hp - before), VCDefs.COL_GOOD)
	healed.emit(hp - before)

# --------------------------------------------------------------- damage
func take_damage(amount: float, from_pos: Vector3, ignore_armor: bool = false) -> bool:
	if state == S.DEAD or invuln > 0.0 or god_mode or VCTester.on("god"):
		return false
	var armor: float = float(stats["armor"])
	var red := 0.0 if ignore_armor else armor / (armor + 45.0)
	var dmg := maxf(1.0, round(amount * (1.0 - red)))
	hp -= dmg
	_since_hurt = 0.0
	invuln = 0.4
	_flash = 0.1
	_set_flash(true)
	var away := global_position - from_pos
	away.y = 0.0
	if away.length() > 0.01:
		_knock = away.normalized() * 5.5
	world.fx.number(global_position, str(int(dmg)), VCDefs.COL_BAD, false)
	world.fx.burst(global_position + Vector3(0, 1.0, 0), Color(1.0, 0.3, 0.4), 10, 4.0, 0.9)
	world.play_sfx("hurt", -2.0)
	world.camera_shake(0.35)
	world.on_player_hurt(dmg)
	VC.vibrate(35)
	damaged.emit(dmg, hp, max_hp)
	if hp <= 0.0:
		hp = 0.0
		_die()
	return true

func _die() -> void:
	state = S.DEAD
	velocity = Vector3.ZERO
	world.play_sfx("defeat")
	died.emit()

func apply_knock(v: Vector3) -> void:
	_knock += v

func revive_at(pos: Vector3) -> void:
	global_position = Vector3(pos.x, 0, pos.z)
	state = S.IDLE
	refresh_stats(true)
	invuln = 1.5
	rig.rotation = Vector3.ZERO
	rig.position = Vector3.ZERO
	combo = 0
	velocity = Vector3.ZERO
	_knock = Vector3.ZERO

# ---------------------------------------------------------------- visuals
func _set_flash(on: bool) -> void:
	for p in _parts:
		var mi: MeshInstance3D = p
		if on:
			if not mi.has_meta("orig"):
				mi.set_meta("orig", mi.material_override)
			mi.material_override = VCMats.flash_overlay()
		elif mi.has_meta("orig"):
			mi.material_override = mi.get_meta("orig")
			mi.remove_meta("orig")

func _animate(delta: float, mv: Vector2) -> void:
	rig.rotation.y = lerp_angle(rig.rotation.y, facing, clampf(delta * 22.0, 0.0, 1.0))
	var speed := Vector2(velocity.x, velocity.z).length()
	var run := clampf(speed / 6.0, 0.0, 1.5)
	var swing := sin(_anim_t * 12.0) * 0.9 * run
	match state:
		S.DEAD:
			rig.rotation.x = lerpf(rig.rotation.x, -PI * 0.5, clampf(delta * 6.0, 0.0, 1.0))
			rig.position.y = lerpf(rig.position.y, 0.35, clampf(delta * 6.0, 0.0, 1.0))
		S.DODGE:
			var k := 1.0 - _dodge_t / DODGE_TIME
			rig.rotation.x = -k * TAU
			rig.position.y = sin(k * PI) * 0.25 - 0.15
			_leg_l.rotation.x = 0.0
			_leg_r.rotation.x = 0.0
		S.ATTACK:
			rig.rotation.x = 0.0
			rig.position.y = 0.0
			var k2 := clampf(_attack_t / _attack_total, 0.0, 1.0)
			if bool(stats["ranged"]):
				_arm_r.rotation.x = -1.4
				_arm_l.rotation.x = -1.2 + sin(k2 * PI) * 0.3
			else:
				var wind := 1.0 - clampf(_attack_t / maxf(_attack_hit_at, 0.01), 0.0, 1.0)
				var side := -1.0 if combo % 2 == 0 else 1.0
				_arm_r.rotation.x = lerpf(-2.4, 0.5, smoothstep(0.0, 1.0, k2 * 1.6)) if k2 < 0.6 else lerpf(0.5, 0.0, (k2 - 0.6) / 0.4)
				_arm_r.rotation.z = side * 0.5 * (1.0 - k2) + wind * 0.2
				_arm_l.rotation.x = -0.5
			_leg_l.rotation.x = 0.3
			_leg_r.rotation.x = -0.3
		_:
			rig.rotation.x = 0.0
			rig.position.y = absf(sin(_anim_t * 12.0)) * 0.06 * run + sin(_anim_t * 2.0) * 0.01
			_leg_l.rotation.x = swing
			_leg_r.rotation.x = -swing
			_arm_l.rotation.x = -swing * 0.8
			_arm_r.rotation.x = swing * 0.8 - 0.2
			_arm_r.rotation.z = lerpf(_arm_r.rotation.z, 0.0, 0.2)
	_cape.rotation.x = -0.1 - run * 0.35 + sin(_anim_t * 4.0) * 0.03
	if run > 0.7 and state == S.IDLE:
		_dust_t -= delta
		if _dust_t <= 0.0:
			_dust_t = 0.22
			world.fx.burst(global_position + Vector3(0, 0.08, 0), Color(0.6, 0.55, 0.7), 2, 1.2, 0.5)
	if armor_fx != null:
		armor_fx.tick(delta, run)
	_tick_friend_sword(delta)
	_tick_pose(delta)
	if mv.length() < 0.05 and state == S.IDLE:
		_leg_l.rotation.x = lerpf(_leg_l.rotation.x, 0.0, 0.2)
		_leg_r.rotation.x = lerpf(_leg_r.rotation.x, 0.0, 0.2)
