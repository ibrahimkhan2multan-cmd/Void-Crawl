class_name VCPickup
extends Node3D
## Loot lying on the floor: coins, equipment, health potions. Tossed out, settles, then
## magnetises to the hero. Collection is resolved by the mission via collect().

enum Kind { COIN, ITEM, POTION }

var world: Node = null
var kind: int = Kind.COIN
var amount := 1
var item: Dictionary = {}
var age := 0.0
var collected := false
var _vel := Vector3.ZERO
var _vy := 0.0
var _y := 0.4
var _grounded := false
var _body: Node3D
var _beam: MeshInstance3D
var _spin := 0.0

func setup_coin(n: int) -> void:
	kind = Kind.COIN
	amount = n
	_body = Node3D.new()
	add_child(_body)
	VCMats.part(_body, Vector3(0.34, 0.34, 0.1), Vector3.ZERO, VCDefs.COL_COIN, 0.9)

func setup_item(it: Dictionary) -> void:
	kind = Kind.ITEM
	item = it
	_body = Node3D.new()
	add_child(_body)
	var col: Color = VCDefs.rarity_color(int(it["rarity"]))
	var base: Color = VCItems.base_color(it)
	VCMats.part(_body, Vector3(0.55, 0.55, 0.55), Vector3.ZERO, base * 0.9, 0.0)
	VCMats.part(_body, Vector3(0.62, 0.1, 0.62), Vector3(0, 0.3, 0), col, 1.2)
	VCMats.part(_body, Vector3(0.62, 0.1, 0.62), Vector3(0, -0.3, 0), col, 1.2)
	if int(it["rarity"]) >= VCDefs.Rarity.RARE:
		_beam = MeshInstance3D.new()
		_beam.mesh = VCMats.box(Vector3(0.18, 4.0, 0.18))
		_beam.material_override = VCMats.fx(Color(col.r, col.g, col.b, 0.35), true)
		_beam.position = Vector3(0, 1.9, 0)
		add_child(_beam)
		var light := OmniLight3D.new()
		light.light_color = col
		light.light_energy = 0.9
		light.omni_range = 4.0
		light.position = Vector3(0, 0.8, 0)
		add_child(light)

func setup_potion() -> void:
	kind = Kind.POTION
	_body = Node3D.new()
	add_child(_body)
	VCMats.part(_body, Vector3(0.36, 0.42, 0.36), Vector3.ZERO, VCDefs.COL_HP, 1.0)
	VCMats.part(_body, Vector3(0.16, 0.18, 0.16), Vector3(0, 0.28, 0), Color(0.85, 0.85, 0.9))

## Toss the pickup from `origin` in a random direction.
func toss(origin: Vector3) -> void:
	position = Vector3(origin.x, 0.0, origin.z)
	_y = 0.8
	_vy = randf_range(3.0, 5.0)
	var a := randf() * TAU
	var s := randf_range(1.0, 2.4)
	_vel = Vector3(cos(a) * s, 0, sin(a) * s)

func _physics_process(delta: float) -> void:
	if collected:
		return
	age += delta
	_spin += delta * 2.5
	if _body != null:
		_body.rotation.y = _spin
		_body.position.y = _y + (sin(age * 3.0) * 0.08 if _grounded else 0.0)
	if not _grounded:
		_vy -= 14.0 * delta
		_y += _vy * delta
		var np := position + _vel * delta
		var tile: Vector2i = world.data.world_to_tile(np)
		if world.data.is_floor(tile.x, tile.y):
			position = np
		else:
			_vel = Vector3.ZERO
		_vel *= (1.0 - 1.5 * delta)
		if _y <= 0.4:
			_y = 0.4
			_grounded = true
	elif age > 0.55 and world.player != null and world.player.is_alive():
		var to_p: Vector3 = world.player.global_position - global_position
		to_p.y = 0.0
		var d := to_p.length()
		var magnet: float = 3.2 if kind != Kind.ITEM else 2.4
		if d < magnet:
			position += to_p.normalized() * minf(d, (5.0 + (magnet - d) * 5.0) * delta)
		if d < 0.9:
			world.collect_pickup(self)
