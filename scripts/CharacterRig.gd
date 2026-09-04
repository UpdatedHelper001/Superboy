class_name CharacterRig
extends RefCounted
## Builds an articulated body (thigh+shin legs, upper-arm+forearm arms,
## torso, head) on a parent Node3D, and drives a walk cycle from a 0..1
## speed ratio. Shared by Player.gd and NPC.gd.
##
## Two ways to build a body:
## - cfg with a "model_path" (res://art/models/*.glb): loads one of the
##   reconstructed Nova Terra character rigs -- 10 nodes (root ->
##   {Left,Right}{Thigh,UpperArm}, each with a {Shin,Forearm} child nested
##   at the knee/elbow, plus Torso and Head), each pre-centered on its own
##   pivot so it drops straight into this pivot-rotation animation system.
##   The source meshes have no material, so color still comes from cfg.
## - cfg without "model_path": the original procedural capsule/sphere
##   primitives (single rigid limb, no knee/elbow), used as a fallback if
##   a model fails to load.

var left_thigh: Node3D
var left_shin: Node3D
var right_thigh: Node3D
var right_shin: Node3D
var left_upper_arm: Node3D
var left_forearm: Node3D
var right_upper_arm: Node3D
var right_forearm: Node3D
var torso: MeshInstance3D
var torso_base_y := 0.0
var walk_phase := 0.0

# Fully-rigged/animated source (e.g. Quaternius packs): a real Skeleton3D +
# baked Idle/Walk/Run clips, found and played instead of driving pivots by
# hand. No manual limb rotation, no cfg tinting (these ship their own
# per-part materials -- that's the point of using a named archetype).
var _anim_player: AnimationPlayer
var _idle_anim := ""
var _walk_anim := ""
var _run_anim := ""

# Primitive-fallback-only limbs (single rigid pivot per leg/arm).
var left_leg: Node3D
var right_leg: Node3D
var left_arm: Node3D
var right_arm: Node3D

var anim_speed := 6.0
var leg_swing_max := 0.6
var arm_swing_max := 0.45
# Extra knee/elbow flex layered on top of the hip/shoulder swing above --
# this is what turns a stiff scissoring pendulum into a walk that reads as
# a real gait: the knee/elbow bends while that limb is swinging through
# the air and straightens while it's planted/extended, timed off the same
# walk_phase so it's always in sync with the swing driving it.
var knee_bend_max := 0.9
var elbow_bend_max := 0.35


func build(parent: Node3D, cfg: Dictionary) -> void:
	if cfg.has("model_path") and _build_from_model(parent, cfg):
		return
	_build_primitive(parent, cfg)


func _build_from_model(parent: Node3D, cfg: Dictionary) -> bool:
	var scene: PackedScene = load(cfg.model_path)
	if not scene:
		return false
	var inst := scene.instantiate()
	if not inst:
		return false
	if cfg.has("facing_offset_y"):
		inst.rotation_degrees.y = cfg.facing_offset_y
	parent.add_child(inst)

	if cfg.has("target_height"):
		_scale_to_height(inst, cfg.target_height)

	var ap := _find_animation_player(inst)
	if ap:
		var idle := _find_anim(ap, ["idle"])
		var walk := _find_anim(ap, ["walk"])
		if idle != "" and walk != "":
			_anim_player = ap
			_idle_anim = idle
			_walk_anim = walk
			_run_anim = _find_anim(ap, ["run"])
			_anim_player.play(_idle_anim)
			return true
		inst.queue_free()
		return false

	return _build_from_rig_model(inst, cfg)


## Measures how tall the just-instanced model actually renders at (world
## space, whatever native scale the source pack used) and rescales `inst`
## so it comes out to `target_height` -- one general fix that works for any
## pack's native units instead of a hand-picked scale constant per archetype
## (which is what silently let some NovaTerra archetypes end up as tall as
## the main character, and left the unrelated-native-scale Quaternius pack
## rendering at several times human height).
func _scale_to_height(inst: Node, target_height: float) -> void:
	var h := _measure_height(inst)
	if h > 0.001:
		inst.scale = Vector3.ONE * (target_height / h)


func _measure_height(inst: Node) -> float:
	# Prefer the skeleton (if any): a skinned MeshInstance3D's own get_aabb()
	# reflects only its unposed bind pose, not the actual rendered size, so
	# bone world positions are the only reliable measurement for a rigged
	# character like the Quaternius packs.
	for skel in _find_all_of_type(inst, "Skeleton3D"):
		var s: Skeleton3D = skel
		var min_y := INF
		var max_y := -INF
		for i in range(s.get_bone_count()):
			var bname := s.get_bone_name(i)
			if bname.contains("Pole") or bname.contains("IK") or bname.contains("Target"):
				continue
			var world_y: float = (s.global_transform * s.get_bone_global_pose(i).origin).y
			min_y = minf(min_y, world_y)
			max_y = maxf(max_y, world_y)
		if max_y > min_y:
			return max_y - min_y

	# No skeleton (the NovaTerra reconstructed rigs and the primitive
	# fallback aren't skinned): aggregate ordinary MeshInstance3D bounds.
	var min_y2 := INF
	var max_y2 := -INF
	for mi in _find_all_of_type(inst, "MeshInstance3D"):
		var m: MeshInstance3D = mi
		var aabb: AABB = m.get_aabb()
		if aabb.size == Vector3.ZERO:
			continue
		var gt: Transform3D = m.global_transform
		for c in range(8):
			var corner := aabb.position + Vector3(
				aabb.size.x * float(c & 1),
				aabb.size.y * float((c >> 1) & 1),
				aabb.size.z * float((c >> 2) & 1))
			var wy: float = (gt * corner).y
			min_y2 = minf(min_y2, wy)
			max_y2 = maxf(max_y2, wy)
	return max_y2 - min_y2 if max_y2 > min_y2 else 0.0


func _find_all_of_type(n: Node, cls: String) -> Array:
	var out := []
	if n.get_class() == cls:
		out.append(n)
	for c in n.get_children():
		out.append_array(_find_all_of_type(c, cls))
	return out


## The reconstructed-from-boxes Nova Terra rigs: no skeleton, just 10 named
## pivot nodes this class rotates by hand every frame (see update_walk).
func _build_from_rig_model(inst: Node, cfg: Dictionary) -> bool:
	left_thigh = inst.get_node_or_null("root/LeftThigh")
	left_shin = inst.get_node_or_null("root/LeftThigh/LeftShin")
	right_thigh = inst.get_node_or_null("root/RightThigh")
	right_shin = inst.get_node_or_null("root/RightThigh/RightShin")
	left_upper_arm = inst.get_node_or_null("root/LeftUpperArm")
	left_forearm = inst.get_node_or_null("root/LeftUpperArm/LeftForearm")
	right_upper_arm = inst.get_node_or_null("root/RightUpperArm")
	right_forearm = inst.get_node_or_null("root/RightUpperArm/RightForearm")
	torso = inst.get_node_or_null("root/Torso") as MeshInstance3D
	var head := inst.get_node_or_null("root/Head")

	var all_present := left_thigh and left_shin and right_thigh and right_shin \
		and left_upper_arm and left_forearm and right_upper_arm and right_forearm \
		and torso and head
	if not all_present:
		inst.queue_free()
		return false

	_tint(left_thigh, cfg.get("leg_color"))
	_tint(left_shin, cfg.get("leg_color"))
	_tint(right_thigh, cfg.get("leg_color"))
	_tint(right_shin, cfg.get("leg_color"))
	_tint(left_upper_arm, cfg.get("arm_color"))
	_tint(left_forearm, cfg.get("arm_color"))
	_tint(right_upper_arm, cfg.get("arm_color"))
	_tint(right_forearm, cfg.get("arm_color"))
	_tint(torso, cfg.get("torso_color"))
	_tint(head, cfg.get("head_color"))

	torso_base_y = torso.position.y
	return true


func _find_animation_player(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var found := _find_animation_player(c)
		if found:
			return found
	return null


## Case-insensitive substring match against the clip's name (after the
## "SomeArmature|" prefix these packs all use) -- e.g. "HumanArmature|Man_Walk"
## and "CharacterArmature|Walk" both match "walk".
func _find_anim(ap: AnimationPlayer, keywords: Array) -> String:
	for full_name in ap.get_animation_list():
		var short := full_name.to_lower()
		for kw in keywords:
			if short.contains(kw) and not short.contains("running"):
				return full_name
	return ""


func _tint(mi: Node3D, color) -> void:
	if not (mi is MeshInstance3D) or color == null:
		return
	(mi as MeshInstance3D).set_surface_override_material(0, _mat(color))


func _build_primitive(parent: Node3D, cfg: Dictionary) -> void:
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


## Advances the walk cycle and swings/bends legs and arms; call every
## physics frame with the character's current horizontal speed / max speed.
func update_walk(delta: float, speed_ratio: float) -> void:
	if _anim_player:
		_update_walk_anim(speed_ratio)
		return

	if speed_ratio > 0.02:
		walk_phase += delta * anim_speed * clamp(speed_ratio, 0.35, 1.0)
	else:
		walk_phase = lerp(walk_phase, 0.0, delta * 8.0)

	var ratio: float = clamp(speed_ratio, 0.0, 1.0)
	var s: float = sin(walk_phase)
	var c: float = cos(walk_phase)
	var hip_l: float = s * leg_swing_max * ratio
	var hip_r: float = -hip_l
	# Knee bends while that leg is airborne (swinging through), straightens
	# through its planted/stance half -- cos(phase) is exactly in that
	# timing relative to the sin(phase) hip swing above.
	var knee_l: float = maxf(0.0, c) * knee_bend_max * ratio
	var knee_r: float = maxf(0.0, -c) * knee_bend_max * ratio
	var arm_ratio: float = arm_swing_max / leg_swing_max
	var sh_l: float = -hip_l * arm_ratio
	var sh_r: float = hip_l * arm_ratio
	var elbow_l: float = maxf(0.0, -c) * elbow_bend_max * ratio
	var elbow_r: float = maxf(0.0, c) * elbow_bend_max * ratio

	if left_thigh:
		left_thigh.rotation.x = hip_l
		if right_thigh: right_thigh.rotation.x = hip_r
		if left_shin: left_shin.rotation.x = -knee_l
		if right_shin: right_shin.rotation.x = -knee_r
		if left_upper_arm: left_upper_arm.rotation.x = sh_l
		if right_upper_arm: right_upper_arm.rotation.x = sh_r
		if left_forearm: left_forearm.rotation.x = -elbow_l
		if right_forearm: right_forearm.rotation.x = -elbow_r
	else:
		if left_leg: left_leg.rotation.x = hip_l
		if right_leg: right_leg.rotation.x = hip_r
		if left_arm: left_arm.rotation.x = sh_l
		if right_arm: right_arm.rotation.x = sh_r

	if torso: torso.position.y = torso_base_y + absf(s) * 0.035 * ratio


## Skeletal-animation path: crossfade Idle<->Walk (or Run, past a speed
## threshold, if the pack shipped one) and nudge playback speed with actual
## movement speed so foot-plant timing doesn't visibly slip.
func _update_walk_anim(speed_ratio: float) -> void:
	var ratio: float = clamp(speed_ratio, 0.0, 1.0)
	if ratio < 0.05:
		if _anim_player.current_animation != _idle_anim:
			_anim_player.play(_idle_anim, 0.25)
		_anim_player.speed_scale = 1.0
		return

	var use_run := _run_anim != "" and ratio > 0.75
	var target := _run_anim if use_run else _walk_anim
	if _anim_player.current_animation != target:
		_anim_player.play(target, 0.2)
	_anim_player.speed_scale = clampf(0.7 + ratio * 0.6, 0.7, 1.6)


## Hip/shoulder pivot at `pivot_pos` holding a hanging capsule limb.
## Rotate the returned pivot's .x to swing the limb. Primitive fallback only.
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
