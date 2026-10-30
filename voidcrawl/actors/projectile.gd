class_name VCProjectile
extends Node3D
## Pooled bolt. Moves manually (no physics body) and checks dungeon tiles + targets itself.
## hostile=true hurts the player, otherwise it hurts enemies/breakables via the player's damage pipeline.

var world: Node = null
var active := false
var hostile := true
var velocity := Vector3.ZERO
var damage := 8.0
var radius := 0.35
var life := 0.0
var pierce := 0
var flat_damage := 0.0            # pet bolts: fixed damage dealt to enemies (no player stats)
var from_pet := false
var mult := 1.0                # player projectiles: damage multiplier passed to player.hit_target
var color := Color(0.8, 0.3, 1.0)
var _hit_ids: Dictionary = {}
var _mesh: MeshInstance3D
var _core: MeshInstance3D
var _t := 0.0

func _ready() -> void:
	_core = MeshInstance3D.new()
	_core.mesh = VCMats.box(Vector3(0.22, 0.22, 0.5))
	add_child(_core)
	_mesh = MeshInstance3D.new()
	_mesh.mesh = VCMats.box(Vector3(0.42, 0.42, 0.42))
	add_child(_mesh)
	visible = false
	set_physics_process(false)

func fire(from: Vector3, dir: Vector3, speed: float, dmg: float, is_hostile: bool, col: Color, rad: float = 0.35, lifetime: float = 2.4, pierce_count: int = 0, dmg_mult: float = 1.0) -> void:
	hostile = is_hostile
	damage = dmg
	color = col
	radius = rad
	life = lifetime
	pierce = pierce_count
	mult = dmg_mult
	flat_damage = 0.0
	from_pet = false
	_hit_ids.clear()
	dir.y = 0.0
	dir = dir.normalized()
	velocity = dir * speed
	global_position = Vector3(from.x, 1.0, from.z)
	rotation.y = atan2(-dir.x, -dir.z)
	var mat := VCMats.fx(Color(col.r, col.g, col.b, 0.9), true)
	_mesh.material_override = mat
	_core.material_override = VCMats.solid(Color(1, 1, 1), 1.0)
	_t = 0.0
	active = true
	visible = true
	set_physics_process(true)

func deactivate() -> void:
	active = false
	visible = false
	set_physics_process(false)

func _physics_process(delta: float) -> void:
	if not active or world == null:
		return
	_t += delta
	life -= delta
	if life <= 0.0:
		_fizzle()
		return
	# sub-step so fast bolts never tunnel through thin walls
	var steps := maxi(1, int(ceil(velocity.length() * delta / 0.4)))
	var step := velocity * delta / float(steps)
	for i in steps:
		global_position += step
		var tile: Vector2i = world.data.world_to_tile(global_position)
		if not world.data.is_floor(tile.x, tile.y):
			world.fx.burst(global_position, color, 6, 3.0, 0.7)
			deactivate()
			return
		if _check_hits():
			return
	_mesh.rotation.z = _t * 9.0

func _fizzle() -> void:
	world.fx.burst(global_position, color, 5, 2.0, 0.6)
	deactivate()

func _check_hits() -> bool:
	var p: Vector3 = global_position
	if hostile:
		if world.get("pets") != null:
			for pt in world.pets:
				if is_instance_valid(pt) and not pt.dead and Vector2(p.x - pt.global_position.x, p.z - pt.global_position.z).length() < radius + pt.hit_radius:
					pt.take_damage(damage, p)
					world.fx.burst(p, color, 6, 3.0, 0.7)
					deactivate()
					return true
		var pl = world.player
		if pl != null and pl.is_alive():
			var d2 := Vector2(p.x - pl.global_position.x, p.z - pl.global_position.z).length()
			if d2 < radius + pl.hit_radius:
				pl.take_damage(damage, p)
				world.fx.burst(p, color, 8, 3.5, 0.8)
				deactivate()
				return true
		return false
	# player projectile: enemies first, then breakables / secret walls
	for e in world.enemies:
		if not e.is_alive() or _hit_ids.has(e.get_instance_id()):
			continue
		var d := Vector2(p.x - e.global_position.x, p.z - e.global_position.z).length()
		if d < radius + e.hit_radius:
			_hit_ids[e.get_instance_id()] = true
			if from_pet:
				var dealt: float = e.take_hit(flat_damage, global_position, false, 1.0, self)
				if dealt > 0.0:
					world.fx.number(e.global_position + Vector3(0, 0.4, 0), str(int(dealt)), Color(0.85, 0.95, 1.0), false)
			else:
				world.player.hit_target(e, mult, 1.5)
			if pierce <= 0:
				world.fx.burst(p, color, 8, 3.5, 0.8)
				deactivate()
				return true
			pierce -= 1
	for b in world.breakables:
		if not b.alive or _hit_ids.has(b.get_instance_id()):
			continue
		var d3 := Vector2(p.x - b.global_position.x, p.z - b.global_position.z).length()
		if d3 < radius + b.hit_radius:
			_hit_ids[b.get_instance_id()] = true
			if from_pet:
				b.take_hit(flat_damage, global_position)
			else:
				world.player.hit_target(b, mult, 0.0)
			world.fx.burst(p, color, 6, 3.0, 0.7)
			deactivate()
			return true
	return false
