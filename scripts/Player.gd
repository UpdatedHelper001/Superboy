extends CharacterBody3D
## Joseph — the playable character. A high-school boy exploring the open
## world, going to school, and (later) picking up missions/mini-games.

const SPEED := 6.0
const SPRINT_SPEED := 10.0
const JUMP_VELOCITY := 6.0
const GRAVITY := 18.0
const MOUSE_SENSITIVITY := 0.12

var _spring_arm: SpringArm3D
var _camera: Camera3D
var _yaw := 0.0
var _pitch := -10.0
var _touch: TouchControls
var _is_mobile := false
var _rig := CharacterRig.new()


func _ready() -> void:
	add_to_group("player")
	_build_visual()
	_build_camera_rig()
	_is_mobile = OS.has_feature("mobile")
	if _is_mobile:
		# No physical keyboard/mouse on a phone: add the on-screen joystick,
		# look-drag region, and jump button instead of capturing a cursor.
		_touch = TouchControls.new()
		add_child(_touch)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _build_visual() -> void:
	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.4
	shape.height = 1.7
	col.shape = shape
	col.position.y = 0.85
	add_child(col)

	# Low-poly "Joseph" body: articulated legs/arms + torso + head, school-uniform colors.
	_rig.leg_swing_max = 0.7
	_rig.arm_swing_max = 0.55
	_rig.anim_speed = 6.5
	_rig.build(self, {
		"hip_x": 0.16, "hip_y": 0.9, "leg_len": 0.9, "leg_r": 0.12, "leg_color": Color(0.2, 0.2, 0.25),
		"shoulder_x": 0.42, "shoulder_y": 1.5, "arm_len": 0.7, "arm_r": 0.09, "arm_color": Color(0.15, 0.25, 0.55),
		"torso_r": 0.35, "torso_h": 0.8, "torso_y": 1.3, "torso_color": Color(0.15, 0.25, 0.55),
		"head_r": 0.25, "head_y": 1.95, "head_color": Color(0.85, 0.7, 0.55),
		"hair_color": Color(0.25, 0.16, 0.1),
	})
	_add_backpack()


## A small backpack on Joseph's back so he reads as the protagonist among a
## crowd of NPCs sharing the same low-poly rig.
func _add_backpack() -> void:
	var pack := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.32, 0.4, 0.18)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.8, 0.2, 0.15)
	mesh.material = mat
	pack.mesh = mesh
	pack.position = Vector3(0, 1.35, -0.28)
	add_child(pack)


func _build_camera_rig() -> void:
	_spring_arm = SpringArm3D.new()
	_spring_arm.position = Vector3(0, 1.5, 0)
	_spring_arm.spring_length = 6.0
	add_child(_spring_arm)

	_camera = Camera3D.new()
	_camera.current = true
	_spring_arm.add_child(_camera)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if event is InputEventMouseButton and event.pressed:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * MOUSE_SENSITIVITY
		_pitch = clamp(_pitch - event.relative.y * MOUSE_SENSITIVITY, -60, 20)
		rotation_degrees.y = _yaw
		_spring_arm.rotation_degrees.x = _pitch


func _physics_process(delta: float) -> void:
	if _touch:
		var look := _touch.consume_look_delta()
		if look != Vector2.ZERO:
			_yaw -= look.x * MOUSE_SENSITIVITY
			_pitch = clamp(_pitch - look.y * MOUSE_SENSITIVITY, -60, 20)
			rotation_degrees.y = _yaw
			_spring_arm.rotation_degrees.x = _pitch

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		if Input.is_action_just_pressed("ui_accept"):
			velocity.y = JUMP_VELOCITY

	var input_dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_W):
		input_dir.y -= 1
	if Input.is_key_pressed(KEY_S):
		input_dir.y += 1
	if Input.is_key_pressed(KEY_A):
		input_dir.x -= 1
	if Input.is_key_pressed(KEY_D):
		input_dir.x += 1
	if _touch:
		input_dir += _touch.move_vector
	input_dir = input_dir.limit_length(1.0)

	var speed := SPRINT_SPEED if Input.is_key_pressed(KEY_SHIFT) else SPEED
	var move_dir3 := transform.basis * Vector3(input_dir.x, 0, input_dir.y)

	if move_dir3.length() > 0.001:
		var dir := move_dir3.normalized()
		var throttle := input_dir.length()  # keyboard is always 1.0; a gentle joystick tilt walks instead of runs
		velocity.x = dir.x * speed * throttle
		velocity.z = dir.z * speed * throttle
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	move_and_slide()

	var h_speed := Vector2(velocity.x, velocity.z).length()
	_rig.update_walk(delta, h_speed / SPRINT_SPEED)


## Called by WorldGenerator to teleport Joseph (e.g. entering/exiting a door).
func teleport_to(pos: Vector3) -> void:
	global_position = pos
	velocity = Vector3.ZERO
