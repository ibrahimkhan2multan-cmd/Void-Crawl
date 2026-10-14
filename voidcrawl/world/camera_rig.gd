class_name VCCameraRig
extends Node3D
## Angled follow camera with smoothing, drag-to-rotate yaw, zoom setting and screen shake.

var target: Node3D
var yaw := 0.0
var pitch_deg := 54.0
var distance := 13.5
var cam: Camera3D
var _shake := 0.0
var _focus_override := Vector3.ZERO
var _use_focus := false
var _zoom_mult := 1.0
var _look_ahead := Vector3.ZERO

func _ready() -> void:
	cam = Camera3D.new()
	cam.fov = 52.0
	cam.near = 0.3
	cam.far = 90.0
	cam.current = true
	add_child(cam)
	name = "CameraRig"

func snap_to(p: Vector3) -> void:
	global_position = p
	_apply()

func shake(amount: float) -> void:
	_shake = maxf(_shake, amount * float(VCSettings.get_value("screen_shake")))

func focus_on(p: Vector3) -> void:
	_focus_override = p
	_use_focus = true

func release_focus() -> void:
	_use_focus = false

func _process(delta: float) -> void:
	if target == null:
		return
	var sens: float = float(VCSettings.get_value("cam_sens"))
	yaw += VCInput.take_cam_delta() * sens
	var want: Vector3 = _focus_override if _use_focus else target.global_position
	if not _use_focus and target is CharacterBody3D:
		var v: Vector3 = (target as CharacterBody3D).velocity
		_look_ahead = _look_ahead.lerp(Vector3(v.x, 0, v.z) * 0.18, clampf(delta * 3.0, 0.0, 1.0))
		want += _look_ahead
	global_position = global_position.lerp(want, clampf(delta * 7.0, 0.0, 1.0))
	_zoom_mult = lerpf(_zoom_mult, float(VCSettings.get_value("cam_zoom")), clampf(delta * 4.0, 0.0, 1.0))
	_shake = maxf(0.0, _shake - delta * 1.6)
	_apply()

func _apply() -> void:
	if cam == null:
		return
	var d := distance * _zoom_mult
	var pr := deg_to_rad(pitch_deg)
	rotation = Vector3(0, yaw, 0)
	cam.position = Vector3(0, sin(pr) * d, cos(pr) * d)
	cam.rotation = Vector3(-pr, 0, 0)
	if _shake > 0.0:
		cam.position += Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake * 0.35
