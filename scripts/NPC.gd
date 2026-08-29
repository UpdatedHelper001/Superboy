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
var _elapsed: float = 0.0  # stagger NPCs so they're not all synced
var _rig := CharacterRig.new()

const SKIN_TONES := [Color(0.85, 0.7, 0.55), Color(0.65, 0.48, 0.35), Color(0.4, 0.28, 0.2), Color(0.93, 0.8, 0.68)]
const HAIR_COLORS := [Color(0.1, 0.08, 0.06), Color(0.35, 0.22, 0.12), Color(0.6, 0.55, 0.5), Color(0.15, 0.1, 0.08)]


func _ready() -> void:
	_elapsed = randf() * day_length
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

	var limb_color := role_color.darkened(0.3)
	_rig.leg_swing_max = 0.6
	_rig.arm_swing_max = 0.45
	_rig.anim_speed = 6.0
	_rig.build(self, {
		"hip_x": 0.14, "hip_y": 0.78, "leg_len": 0.78, "leg_r": 0.1, "leg_color": limb_color,
		"shoulder_x": 0.36, "shoulder_y": 1.3, "arm_len": 0.6, "arm_r": 0.08, "arm_color": role_color,
		"torso_r": 0.3, "torso_h": 0.7, "torso_y": 1.13, "torso_color": role_color,
		"head_r": 0.22, "head_y": 1.7, "head_color": SKIN_TONES.pick_random(),
		"hair_color": HAIR_COLORS.pick_random(),
	})


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

	var h_speed := Vector2(velocity.x, velocity.z).length()
	_rig.update_walk(delta, h_speed / SPEED)
