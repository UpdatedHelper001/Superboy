class_name CharacterRig
extends RefCounted
## Builds a low-poly articulated body (legs/arms on swinging pivots + torso +
## head, optional hair) on a parent Node3D, and drives a sine-wave walk cycle
## from a 0..1 speed ratio. Shared by Player.gd and NPC.gd so both characters
## animate identically without duplicating the limb-building code.

var left_leg: Node3D
var right_leg: Node3D
var left_arm: Node3D
var right_arm: Node3D
var torso: MeshInstance3D
var torso_base_y := 0.0
var walk_phase := 0.0

var anim_speed := 6.0
var leg_swing_max := 0.6
var arm_swing_max := 0.45


## `cfg` keys: hip_x, hip_y, leg_len, leg_r, leg_color,
## shoulder_x, shoulder_y, arm_len, arm_r, arm_color,
## torso_r, torso_h, torso_y, torso_color,
## head_r, head_y, head_color, hair_color (optional).
func build(parent: Node3D, cfg: Dictionary) -> void:
	left_leg = _make_limb(parent, Vector3(-cfg.hip_x, cfg.hip_y, 0), cfg.leg_len, cfg.leg_r, cfg.leg_color)
	right_leg = _make_limb(parent, Vector3(cfg.hip_x, cfg.hip_y, 0), cfg.leg_len, cfg.leg_r, cfg.leg_color)
	left_arm = _make_limb(parent, Vector3(-cfg.shoulder_x, cfg.shoulder_y, 0), cfg.arm_len, cfg.arm_r, cfg.arm_color)
	right_arm = _make_limb(parent, Vector3(cfg.shoulder_x, cfg.shoulder_y, 0), cfg.arm_len, cfg.arm_r, cfg.arm_color)

	torso = MeshInstance3D.new()
	var tmesh := CapsuleMesh.new()
	tmesh.radius = cfg.torso_r
	tmesh.height = cfg.torso_h
	tmesh.material = _mat(cfg.torso_color)
	torso.mesh = tmesh
	torso_base_y = cfg.torso_y
	torso.position.y = torso_base_y
	parent.add_child(torso)

	var head := MeshInstance3D.new()
	var hmesh := SphereMesh.new()
	hmesh.radius = cfg.head_r
	hmesh.height = cfg.head_r * 2.0
	hmesh.material = _mat(cfg.head_color)
	head.mesh = hmesh
	head.position.y = cfg.head_y
	parent.add_child(head)

	if cfg.has("hair_color"):
		var hair := MeshInstance3D.new()
		var hmesh2 := SphereMesh.new()
		hmesh2.radius = cfg.head_r * 1.08
		hmesh2.height = cfg.head_r * 1.3
		hmesh2.material = _mat(cfg.hair_color)
		hair.mesh = hmesh2
		hair.position.y = cfg.head_y + cfg.head_r * 0.4
		parent.add_child(hair)


## Advances the walk cycle and swings legs/arms; call every physics frame
## with the character's current horizontal speed / max speed (0..1+).
func update_walk(delta: float, speed_ratio: float) -> void:
	if speed_ratio > 0.02:
		walk_phase += delta * anim_speed * clamp(speed_ratio, 0.35, 1.0)
	else:
		walk_phase = lerp(walk_phase, 0.0, delta * 8.0)

	var swing: float = sin(walk_phase) * leg_swing_max * clamp(speed_ratio, 0.0, 1.0)
	var arm_swing: float = swing * (arm_swing_max / leg_swing_max)
	if left_leg: left_leg.rotation.x = swing
	if right_leg: right_leg.rotation.x = -swing
	if left_arm: left_arm.rotation.x = -arm_swing
	if right_arm: right_arm.rotation.x = arm_swing
	if torso: torso.position.y = torso_base_y + absf(sin(walk_phase)) * 0.035 * clamp(speed_ratio, 0.0, 1.0)


## Hip/shoulder pivot at `pivot_pos` holding a hanging capsule limb.
## Rotate the returned pivot's .x to swing the limb.
func _make_limb(parent: Node3D, pivot_pos: Vector3, length: float, radius: float, color: Color) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pivot_pos
	parent.add_child(pivot)

	var mi := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = length
	mesh.material = _mat(color)
	mi.mesh = mesh
	mi.position.y = -length / 2.0
	pivot.add_child(mi)
	return pivot


func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	return m
