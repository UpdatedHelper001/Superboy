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

func _ready() -> void:
	add_to_group("player")
	_build_visual()
	_build_camera_rig()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _build_visual() -> void:
	# Collision capsule
	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.4
	shape.height = 1.7
	col.shape = shape
	col.position.y = 0.85
	add_child(col)

	# Simple low-poly "Joseph" body: torso + head, school-uniform colors
	var torso := MeshInstance3D.new()
	var torso_mesh := CapsuleMesh.new()
	torso_mesh.radius = 0.35
	torso_mesh.height = 1.3
	var torso_mat := StandardMaterial3D.new()
	torso_mat.albedo_color = Color(0.15, 0.25, 0.55)  # school uniform blue
	torso_mesh.material = torso_mat
	torso.mesh = torso_mesh
	torso.position.y = 0.85
	add_child(torso)

	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.25
	head_mesh.height = 0.5
	var head_mat := StandardMaterial3D.new()
	head_mat.albedo_color = Color(0.85, 0.7, 0.55)  # skin tone
	head_mesh.material = head_mat
	head.mesh = head_mesh
	head.position.y = 1.65
	add_child(head)


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
	input_dir = input_dir.normalized()

	var speed := SPRINT_SPEED if Input.is_key_pressed(KEY_SHIFT) else SPEED
	var dir := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if dir.length() > 0:
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	move_and_slide()


## Called by WorldGenerator to teleport Joseph (e.g. entering/exiting a door).
func teleport_to(pos: Vector3) -> void:
	global_position = pos
	velocity = Vector3.ZERO
