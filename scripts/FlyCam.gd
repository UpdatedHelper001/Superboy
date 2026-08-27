extends Camera3D
## Basic no-clip fly camera for inspecting the generated map.
## WASD to move, mouse to look (click to capture mouse, Esc to release),
## Shift to move faster, Space/Ctrl for up/down.

var move_speed := 20.0
var fast_multiplier := 3.0
var mouse_sensitivity := 0.12
var _yaw := 0.0
var _pitch := 0.0

func _ready() -> void:
	position = Vector3(0, 15, 40)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if event is InputEventMouseButton and event.pressed:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * mouse_sensitivity
		_pitch = clamp(_pitch - event.relative.y * mouse_sensitivity, -89, 89)
		rotation_degrees = Vector3(_pitch, _yaw, 0)

func _process(delta: float) -> void:
	var dir := Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		dir -= transform.basis.z
	if Input.is_key_pressed(KEY_S):
		dir += transform.basis.z
	if Input.is_key_pressed(KEY_A):
		dir -= transform.basis.x
	if Input.is_key_pressed(KEY_D):
		dir += transform.basis.x
	if Input.is_key_pressed(KEY_SPACE):
		dir += Vector3.UP
	if Input.is_key_pressed(KEY_CTRL):
		dir -= Vector3.UP

	var speed := move_speed
	if Input.is_key_pressed(KEY_SHIFT):
		speed *= fast_multiplier

	position += dir.normalized() * speed * delta if dir.length() > 0 else Vector3.ZERO
