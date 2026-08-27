extends CharacterBody3D
## Working NPC: walks from home to their workplace, stays for their "shift",
## then walks home. Runs on a compressed day cycle so behavior is visible
## quickly instead of over a real 24h clock.

const SPEED := 3.0
const GRAVITY := 18.0

@export var home_pos: Vector3
@export var work_pos: Vector3
@export var day_length := 120.0  # seconds per full day cycle
@export var role_color := Color(0.7, 0.7, 0.3)

enum State { AT_HOME, GOING_TO_WORK, AT_WORK, GOING_HOME }
var _state := State.AT_HOME
var _elapsed := randf() * 120.0  # stagger NPCs so they're not all synced


func _ready() -> void:
	add_to_group("npc")
	_build_visual()
	global_position = home_pos


func _build_visual() -> void:
	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.35
	shape.height = 1.5
	col.shape = shape
	col.position.y = 0.75
	add_child(col)

	var mesh_inst := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.3
	mesh.height = 1.2
	var mat := StandardMaterial3D.new()
	mat.albedo_color = role_color
	mesh.material = mat
	mesh_inst.mesh = mesh
	mesh_inst.position.y = 0.75
	add_child(mesh_inst)


func _physics_process(delta: float) -> void:
	_elapsed = fmod(_elapsed + delta, day_length)
	var phase := _elapsed / day_length

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0

	# Schedule: 0-40% home, 40-45% commute to work, 45-85% work,
	# 85-90% commute home, 90-100% home.
	if phase < 0.40:
		_state = State.AT_HOME
	elif phase < 0.45:
		_state = State.GOING_TO_WORK
	elif phase < 0.85:
		_state = State.AT_WORK
	elif phase < 0.90:
		_state = State.GOING_HOME
	else:
		_state = State.AT_HOME

	var target := global_position
	match _state:
		State.GOING_TO_WORK:
			target = work_pos
		State.GOING_HOME:
			target = home_pos
		_:
			target = global_position  # idle, hold position

	var to_target := target - global_position
	to_target.y = 0
	if to_target.length() > 0.5:
		var dir := to_target.normalized()
		velocity.x = dir.x * SPEED
		velocity.z = dir.z * SPEED
		look_at(global_position + dir, Vector3.UP)
	else:
		velocity.x = 0
		velocity.z = 0

	move_and_slide()
