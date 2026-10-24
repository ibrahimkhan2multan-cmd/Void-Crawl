class_name VCBomb
extends Node3D
## Thrown void-bomb: arcs to a spot, flashes, then explodes for heavy area damage.
## It also smashes crates and cracked secret walls, so it doubles as a tool for exploring.

const FLIGHT := 0.7
const FUSE := 0.55
const RADIUS := 3.6

var world: Node = null
var start := Vector3.ZERO
var land := Vector3.ZERO
var damage := 40.0
var _t := 0.0
var _mesh: MeshInstance3D
var _done := false

func setup(p_start: Vector3, p_land: Vector3, p_damage: float) -> void:
	start = p_start
	land = p_land
	damage = p_damage
	position = start
	_mesh = VCMats.part(self, Vector3(0.42, 0.42, 0.42), Vector3.ZERO, Color(0.2, 0.12, 0.3), 0.0)
	VCMats.part(self, Vector3(0.1, 0.18, 0.1), Vector3(0, 0.28, 0), Color(1.0, 0.7, 0.3), 2.0)
	VCMats.part(self, Vector3(0.46, 0.08, 0.46), Vector3(0, 0, 0), Color(0.75, 0.4, 1.0), 1.4)

func _physics_process(delta: float) -> void:
	if _done:
		return
	_t += delta
	if _t < FLIGHT:
		var k := _t / FLIGHT
		var p := start.lerp(land, k)
		p.y = lerpf(start.y, 0.3, k) + sin(k * PI) * 2.4
		position = p
		_mesh.rotation += Vector3(delta * 9.0, delta * 6.0, 0)
	else:
		position = Vector3(land.x, 0.3, land.z)
		var f := fmod(_t * 14.0, 2.0) < 1.0
		_mesh.scale = Vector3.ONE * (1.25 if f else 1.0)
		if _t >= FLIGHT + FUSE:
			_explode()

func _explode() -> void:
	_done = true
	var pos := Vector3(land.x, 0.0, land.z)
	world.fx.ring(pos, RADIUS, Color(1.0, 0.65, 0.3), 0.5)
	world.fx.ring(pos, RADIUS * 0.6, Color(0.85, 0.5, 1.0), 0.4)
	world.fx.burst(pos + Vector3(0, 0.8, 0), Color(1.0, 0.7, 0.3), 30, 8.0, 1.2)
	world.fx.burst(pos + Vector3(0, 0.8, 0), Color(0.8, 0.45, 1.0), 20, 6.0, 1.0)
	world.play_sfx("boss_roar", -8.0, 1.9)
	world.play_sfx("hit", -2.0, 0.6)
	world.camera_shake(0.6)
	var victims: Array = []
	for list in [world.enemies, world.breakables]:
		for t in list:
			if is_instance_valid(t) and t.is_alive():
				var d := Vector2(t.global_position.x - pos.x, t.global_position.z - pos.z).length()
				if d <= RADIUS + t.hit_radius:
					victims.append(t)
	for t in victims:
		var falloff := 1.0 - clampf(Vector2(t.global_position.x - pos.x, t.global_position.z - pos.z).length() / (RADIUS + 1.0), 0.0, 0.5)
		var dealt: float = t.take_hit(round(damage * falloff), pos, false, 5.0, world.player)
		if dealt > 0.0:
			world.on_player_hit(t, dealt, false)
	queue_free()
