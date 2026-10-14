class_name VCInput
extends RefCounted
## Single source of truth for player intent. The touch overlay writes into it; keyboard and
## gamepad are polled into it. Gameplay code only ever reads from here, so tests can drive
## the game by setting these fields directly.

static var touch_move := Vector2.ZERO        # joystick deflection, length 0..1
static var touch_sprint := false
static var touch_attack_held := false
static var cam_yaw_delta := 0.0              # radians accumulated by camera drags since last read

static var _presses: Dictionary = {}         # action -> true (consumed on read)

static func reset() -> void:
	touch_move = Vector2.ZERO
	touch_sprint = false
	touch_attack_held = false
	cam_yaw_delta = 0.0
	_presses.clear()

static func press(action: String) -> void:
	_presses[action] = true

## True once per press. Used for dodge/ability/heal/interact/inventory/pause.
static func take(action: String) -> bool:
	if _presses.has(action):
		_presses.erase(action)
		return true
	if Input.is_action_just_pressed("vc_" + action):
		return true
	return false

static func attack_held() -> bool:
	return touch_attack_held or Input.is_action_pressed("vc_attack")

## Movement on screen axes: x right, y down (so y>0 = towards the camera).
static func move_vector() -> Vector2:
	var v := touch_move
	if v.length() < 0.01:
		v = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	return v.limit_length(1.0)

static func sprinting() -> bool:
	return touch_sprint or Input.is_action_pressed("vc_sprint")

static func take_cam_delta() -> float:
	var d := cam_yaw_delta
	cam_yaw_delta = 0.0
	return d
