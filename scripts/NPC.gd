extends CharacterBody3D
## Working NPC: walks from home to their workplace, stays for their "shift",
## then walks home. Runs on a compressed day cycle so behavior is visible
## quickly instead of over a real 24h clock.

const SPEED := 3.0
const WANDER_SPEED := 1.8
const GRAVITY := 18.0

@export var home_pos: Vector3
@export var work_pos: Vector3
@export var day_length := 120.0  # seconds per full day cycle
@export var role_color := Color(0.7, 0.7, 0.3)
@export var wander_radius := 4.0  # how far this NPC drifts while idle/home/at-work
@export var is_ambient := false  # pure street wanderer, ignores the home/work schedule

enum State { AT_HOME, GOING_TO_WORK, AT_WORK, GOING_HOME }
var _state := State.AT_HOME
var _elapsed: float = 0.0  # stagger NPCs so they're not all synced
var _rig := CharacterRig.new()
var _wander_target := Vector3.ZERO
var _wander_timer := 0.0

# Straight-line movement has no obstacle avoidance, so a target that's
# blocked (another NPC in the way, or an edge case that still lands an NPC
# too close to a wall) can otherwise leave it pushed uselessly against
# whatever it hit. These track "am I actually making progress?" and steer
# around the obstruction for a couple of seconds when the answer is no.
const STUCK_CHECK_INTERVAL := 1.2
const STUCK_MIN_PROGRESS := 0.6
const DETOUR_DURATION := 2.0
const DETOUR_DISTANCE := 3.0
var _stuck_check_timer := STUCK_CHECK_INTERVAL
var _stuck_check_pos := Vector3.ZERO
var _detour_target := Vector3.ZERO
var _detour_timer := 0.0

const SKIN_TONES := [Color(0.85, 0.7, 0.55), Color(0.65, 0.48, 0.35), Color(0.4, 0.28, 0.2), Color(0.93, 0.8, 0.68)]
const HAIR_COLORS := [Color(0.1, 0.08, 0.06), Color(0.35, 0.22, 0.12), Color(0.6, 0.55, 0.5), Color(0.15, 0.1, 0.08)]

# Weighted by simple repetition (no separate weight table needed) toward a
# believable city crowd: mostly civilians/workers, occasional
# police/doctor/elder/child, gang rarest.
const NPC_MODELS := [
	"res://art/models/NPC_Civilian.glb", "res://art/models/NPC_Civilian.glb", "res://art/models/NPC_Civilian.glb",
	"res://art/models/NPC_Worker.glb", "res://art/models/NPC_Worker.glb", "res://art/models/NPC_Worker.glb",
	"res://art/models/NPC_Elder.glb", "res://art/models/NPC_Elder.glb",
	"res://art/models/NPC_Child.glb", "res://art/models/NPC_Child.glb",
	"res://art/models/NPC_Police.glb",
	"res://art/models/NPC_Doctor.glb",
	"res://art/models/NPC_Gang.glb",
]


func _ready() -> void:
	_elapsed = randf() * day_length
	add_to_group("npc")
	_build_visual()
	# A tiny lift off the ground plane avoids spawning slightly embedded in
	# it (the ground collision's top surface sits a hair above y=0).
	global_position = home_pos + Vector3(0, 0.05, 0)
	_stuck_check_pos = global_position


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
		"model_path": NPC_MODELS.pick_random(),
		"leg_color": limb_color,
		"arm_color": role_color,
		"torso_color": role_color,
		"head_color": SKIN_TONES.pick_random(),
		# Fallback values if the model fails to load:
		"hip_x": 0.14, "hip_y": 0.78, "leg_len": 0.78, "leg_r": 0.1,
		"shoulder_x": 0.36, "shoulder_y": 1.3, "arm_len": 0.6, "arm_r": 0.08,
		"torso_r": 0.3, "torso_h": 0.7, "torso_y": 1.13,
		"head_r": 0.22, "head_y": 1.7,
		"hair_color": HAIR_COLORS.pick_random(),
	})


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0

	var target: Vector3
	var move_speed := SPEED

	if is_ambient:
		# Pure street life: no schedule, just keep drifting around a home point.
		target = _update_wander(delta, home_pos, wander_radius)
		move_speed = WANDER_SPEED
	else:
		_elapsed = fmod(_elapsed + delta, day_length)
		var phase := _elapsed / day_length

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

		match _state:
			State.GOING_TO_WORK:
				target = work_pos
			State.GOING_HOME:
				target = home_pos
			State.AT_HOME:
				target = _update_wander(delta, home_pos, wander_radius)
				move_speed = WANDER_SPEED
			State.AT_WORK:
				target = _update_wander(delta, work_pos, wander_radius)
				move_speed = WANDER_SPEED

	target = _apply_unstuck(delta, target)

	var to_target := target - global_position
	to_target.y = 0
	if to_target.length() > 0.4:
		var dir := to_target.normalized()
		velocity.x = dir.x * move_speed
		velocity.z = dir.z * move_speed
		look_at(global_position + dir, Vector3.UP)
	else:
		velocity.x = 0
		velocity.z = 0

	move_and_slide()

	var h_speed := Vector2(velocity.x, velocity.z).length()
	_rig.update_walk(delta, h_speed / SPEED)


## Detects "trying to get somewhere but barely moving" (typically an NPC
## pushed up against a wall or another NPC) and substitutes a sideways
## detour point for a couple of seconds so it can walk around whatever it's
## stuck on, instead of indefinitely pushing into it. Returns whatever the
## NPC should actually walk toward this frame -- either the real target
## passed in, or a temporary detour.
func _apply_unstuck(delta: float, real_target: Vector3) -> Vector3:
	if _detour_timer > 0.0:
		_detour_timer -= delta
		if _detour_timer > 0.0 and global_position.distance_to(_detour_target) > 0.6:
			return _detour_target

	_stuck_check_timer -= delta
	if _stuck_check_timer <= 0.0:
		_stuck_check_timer = STUCK_CHECK_INTERVAL
		var progressed := global_position.distance_to(_stuck_check_pos)
		_stuck_check_pos = global_position
		var wants_to_move := real_target.distance_to(global_position) > 0.4
		if wants_to_move and progressed < STUCK_MIN_PROGRESS:
			var to_target := real_target - global_position
			to_target.y = 0
			var perp := Vector3(-to_target.z, 0, to_target.x)
			perp = perp.normalized() if perp.length() > 0.01 else Vector3(1, 0, 0)
			if randf() < 0.5:
				perp = -perp
			_detour_target = global_position + perp * DETOUR_DISTANCE
			_detour_timer = DETOUR_DURATION
			return _detour_target

	return real_target


## Picks a lazy wander target within `radius` of `center` and keeps returning
## it until reached (or a few seconds pass), so NPCs meander instead of
## teleporting between random points every frame.
func _update_wander(delta: float, center: Vector3, radius: float) -> Vector3:
	_wander_timer -= delta
	if _wander_timer <= 0.0 or global_position.distance_to(_wander_target) < 1.0:
		var angle := randf() * TAU
		var r := randf() * radius
		_wander_target = center + Vector3(cos(angle) * r, 0, sin(angle) * r)
		_wander_timer = randf_range(3.0, 7.0)
	return _wander_target
