class_name VCBreakable
extends Node3D
## Crates, barrels and cracked secret walls. Same take_hit() shape as enemies so attacks,
## projectiles and the Void Nova can all damage them through one code path.

signal broken(b)

var world: Node = null
var kind := "crate"            # crate | barrel | secret
var hp := 1.0
var alive := true
var hit_radius := 0.8
var secret_id := ""
var room := -1
var prop_id := ""
var _body: Node3D
var _shake := 0.0

func setup(p_kind: String, p_hp: float, radius: float) -> void:
	kind = p_kind
	hp = p_hp
	hit_radius = radius
	if kind == "secret":
		return   # visuals are owned by the dungeon builder
	_body = Node3D.new()
	add_child(_body)
	if kind == "barrel":
		VCMats.part(_body, Vector3(0.9, 1.0, 0.9), Vector3(0, 0.5, 0), Color(0.36, 0.24, 0.16))
		VCMats.part(_body, Vector3(0.96, 0.12, 0.96), Vector3(0, 0.25, 0), Color(0.2, 0.17, 0.22))
		VCMats.part(_body, Vector3(0.96, 0.12, 0.96), Vector3(0, 0.75, 0), Color(0.2, 0.17, 0.22))
	else:
		VCMats.part(_body, Vector3(1.1, 0.9, 1.1), Vector3(0, 0.45, 0), Color(0.42, 0.3, 0.2))
		VCMats.part(_body, Vector3(1.16, 0.12, 1.16), Vector3(0, 0.9, 0), Color(0.3, 0.22, 0.16))
		VCMats.part(_body, Vector3(0.12, 0.92, 1.18), Vector3(0, 0.46, 0), Color(0.25, 0.2, 0.25))
	# body collision so the hero cannot walk through crates
	var sb := StaticBody3D.new()
	sb.collision_layer = VCDefs.L_PROP
	sb.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.0, 1.0, 1.0)
	cs.shape = bs
	cs.position = Vector3(0, 0.5, 0)
	sb.add_child(cs)
	add_child(sb)
	sb.name = "Body"

func is_alive() -> bool:
	return alive

## Same signature as VCEnemy.take_hit. Returns damage actually applied.
func take_hit(amount: float, from_pos: Vector3, _crit: bool = false, _knock: float = 0.0, _source: Node = null) -> float:
	if not alive:
		return 0.0
	hp -= 1.0   # every strike counts as one hit, regardless of damage
	_shake = 0.2
	if world != null:
		world.fx.burst(global_position + Vector3(0, 0.8, 0), Color(0.7, 0.6, 0.5) if kind != "secret" else Color(0.7, 0.4, 1.0), 6, 3.0, 0.8)
		world.play_sfx("hit", -6.0, 0.8)
	if hp <= 0.0:
		_break()
	return 1.0

func _break() -> void:
	alive = false
	if world != null:
		world.fx.burst(global_position + Vector3(0, 0.6, 0), Color(0.55, 0.4, 0.28) if kind != "secret" else Color(0.8, 0.5, 1.0), 16, 5.0, 1.2)
		world.play_sfx("enemy_die" if kind == "secret" else "hit", -3.0, 1.4)
	broken.emit(self)
	visible = false
	var sb := get_node_or_null("Body")
	if sb != null:
		sb.queue_free()

func _process(delta: float) -> void:
	if _body != null and _shake > 0.0:
		_shake -= delta
		_body.position.x = sin(_shake * 90.0) * 0.06
		if _shake <= 0.0:
			_body.position.x = 0.0
