extends CharacterBody3D
## Joseph — the playable character in "Joseph: The Man He Hated". An adult
## (laid-off OOO Corporation employee turned politician turned president),
## not the earlier high-school-boy concept -- see StoryManager for the
## narrative arc this drives. Body proportions/rig are unchanged from that
## earlier concept (same low-poly CharacterRig build), only the palette
## below and the framing have moved off "schoolboy"; a proper adult
## wardrobe (suit era vs. campaign-trail era vs. presidential era) is art
## work for later, not a geometry change.

signal health_changed(current: float, max_hp: float)

const SPEED := 6.0
const SPRINT_SPEED := 10.0
const JUMP_VELOCITY := 6.0
const GRAVITY := 18.0
const MOUSE_SENSITIVITY := 0.12

const MAX_HEALTH := 100.0
const FALL_DAMAGE_MIN_SPEED := 10.0  # vertical speed (m/s) before landings start to hurt
const FALL_DAMAGE_SCALE := 4.0       # damage per m/s of speed above the threshold
const RESPAWN_INVULN_TIME := 1.5     # seconds of immunity right after a respawn
const INTERACT_RANGE := 3.0

var _spring_arm: SpringArm3D
var _camera: Camera3D
var _yaw := 0.0
var _pitch := -10.0
var _touch: TouchControls
var _is_mobile := false
var _rig := CharacterRig.new()

var health := MAX_HEALTH
var home_position: Vector3
var _invuln_timer := 0.0
var _is_dying := false
var _talk_box: DialogueBox = null


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

	# Low-poly "Joseph" body: articulated legs/arms + torso + head. Palette
	# is a plain dark office/campaign look (charcoal jacket, dark trousers)
	# rather than the earlier schoolboy blue -- a placeholder pass, not
	# final art; per-act wardrobe changes come later.
	_rig.leg_swing_max = 0.7
	_rig.arm_swing_max = 0.55
	_rig.anim_speed = 6.5
	_rig.build(self, {
		"model_path": "res://art/models/MainCharacter_Default.glb",
		"leg_color": Color(0.13, 0.13, 0.15),
		"arm_color": Color(0.18, 0.18, 0.22),
		"torso_color": Color(0.18, 0.18, 0.22),
		"head_color": Color(0.85, 0.7, 0.55),
		# Fallback values if the model fails to load:
		"hip_x": 0.16, "hip_y": 0.9, "leg_len": 0.9, "leg_r": 0.12,
		"shoulder_x": 0.42, "shoulder_y": 1.5, "arm_len": 0.7, "arm_r": 0.09,
		"torso_r": 0.35, "torso_h": 0.8, "torso_y": 1.3,
		"head_r": 0.25, "head_y": 1.95,
		"hair_color": Color(0.25, 0.16, 0.1),
	})


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
	if Input.is_action_just_pressed("interact"):
		_try_interact()

	if _invuln_timer > 0.0:
		_invuln_timer = max(_invuln_timer - delta, 0.0)

	if _touch:
		var look := _touch.consume_look_delta()
		if look != Vector2.ZERO:
			_yaw -= look.x * MOUSE_SENSITIVITY
			_pitch = clamp(_pitch - look.y * MOUSE_SENSITIVITY, -60, 20)
			rotation_degrees.y = _yaw
			_spring_arm.rotation_degrees.x = _pitch

	var was_on_floor := is_on_floor()

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		if Input.is_action_just_pressed("ui_accept"):
			velocity.y = JUMP_VELOCITY

	var fall_speed := -velocity.y  # positive while falling, used for landing-impact damage below

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

	if not was_on_floor and is_on_floor() and fall_speed > FALL_DAMAGE_MIN_SPEED:
		take_damage((fall_speed - FALL_DAMAGE_MIN_SPEED) * FALL_DAMAGE_SCALE)

	var h_speed := Vector2(velocity.x, velocity.z).length()
	_rig.update_walk(delta, h_speed / SPRINT_SPEED)


## Reduces health (e.g. a hard landing). Ignored while invulnerable (right
## after a respawn), for non-positive amounts, or while a previous hit is
## already mid-death (see _die() below).
func take_damage(amount: float) -> void:
	if _invuln_timer > 0.0 or amount <= 0.0 or _is_dying:
		return
	health = max(health - amount, 0.0)
	health_changed.emit(health, MAX_HEALTH)
	if health <= 0.0:
		_die()


## A lethal hit used to respawn Joseph with full health again inside the
## very same physics frame the damage happened -- the HUD never actually got
## a frame to render the health bar at 0, so a fatal fall looked visually
## identical to no damage at all ("invincible"). Now health is held at 0 for
## a brief beat (long enough to render/feel) before the teleport-home and
## heal, so the hit is actually seen.
func _die() -> void:
	_is_dying = true
	await get_tree().create_timer(0.6).timeout
	var respawn := home_position if home_position != Vector3.ZERO else global_position
	teleport_to(respawn)
	health = MAX_HEALTH
	_invuln_timer = RESPAWN_INVULN_TIME
	_is_dying = false
	health_changed.emit(health, MAX_HEALTH)


## Called by WorldGenerator to teleport Joseph (e.g. entering/exiting a door).
func teleport_to(pos: Vector3) -> void:
	global_position = pos
	velocity = Vector3.ZERO


## Nearest-NPC-in-range "talk" interaction. Ambient NPCs only have one flat
## line each (NPC.get_ambient_line -- see its const dictionaries), so this
## shows it directly through a one-off DialogueBox rather than spinning up
## a full DialogueRunner/DialogueTree for a single line with no choices.
func _try_interact() -> void:
	if _talk_box != null:
		return
	var nearest: Node3D = null
	var nearest_dist := INTERACT_RANGE
	for npc in get_tree().get_nodes_in_group("npc"):
		var d: float = global_position.distance_to(npc.global_position)
		if d <= nearest_dist:
			nearest_dist = d
			nearest = npc
	if nearest == null:
		return

	_talk_box = DialogueBox.new()
	add_child(_talk_box)
	_talk_box.show_line("Citizen", nearest.get_ambient_line(), [])
	_talk_box.continue_pressed.connect(func():
		_talk_box.queue_free()
		_talk_box = null
	)
