extends Node3D
## Procedurally builds the open-world map: three zones (Industrial, Rural,
## Middle-Class Hometown) laid out side by side, populated with buildings,
## huts, and shops, each with a walk-in interior. Also places a school,
## spawns working NPCs on daily routines, and spawns the player (Joseph).

# --- Map layout ---------------------------------------------------------
const ZONE_WIDTH := 200.0
const ZONE_DEPTH := 200.0
const ROAD_WIDTH := 10.0

enum ZoneType { RURAL, HOMETOWN, INDUSTRIAL }

var zone_origins := {}
var _interior_counter := 0
var _hometown_house_positions: Array = []   # candidate "homes" for NPCs and Joseph
var _workplaces: Array = []                 # [{pos=Vector3, kind=String}] for NPC jobs
var _school_pos: Vector3
var _joseph_home_pos: Vector3

const PlayerScript := preload("res://scripts/Player.gd")
const NPCScript := preload("res://scripts/NPC.gd")

func _ready() -> void:
	randomize()
	_build_environment()
	_layout_zones()
	for zone_type in [ZoneType.RURAL, ZoneType.HOMETOWN, ZoneType.INDUSTRIAL]:
		_build_ground(zone_type)
		_populate_zone(zone_type)
	_build_connecting_roads()
	_build_school()
	_spawn_npcs()
	_spawn_player()


# --- Environment ----------------------------------------------------------
func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.55, 0.65, 0.75)
	env.fog_enabled = true
	env.fog_light_color = Color(0.6, 0.65, 0.7)
	env.fog_density = 0.015
	var cam_env := WorldEnvironment.new()
	cam_env.environment = env
	add_child(cam_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.light_energy = 1.1
	add_child(sun)


# --- Zone placement ---------------------------------------------------------
func _layout_zones() -> void:
	zone_origins[ZoneType.RURAL] = Vector3(-ZONE_WIDTH - ROAD_WIDTH, 0, 0)
	zone_origins[ZoneType.HOMETOWN] = Vector3(0, 0, 0)
	zone_origins[ZoneType.INDUSTRIAL] = Vector3(ZONE_WIDTH + ROAD_WIDTH, 0, 0)


func _build_ground(zone_type: int) -> void:
	var origin: Vector3 = zone_origins[zone_type]
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(ZONE_WIDTH, ZONE_DEPTH)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = _ground_color(zone_type)
	mat.roughness = 1.0
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = origin
	add_child(mi)

	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(ZONE_WIDTH, 0.1, ZONE_DEPTH)
	col.shape = shape
	body.position = origin
	body.add_child(col)
	add_child(body)


func _ground_color(zone_type: int) -> Color:
	match zone_type:
		ZoneType.RURAL:
			return Color(0.42, 0.55, 0.28)
		ZoneType.HOMETOWN:
			return Color(0.55, 0.52, 0.45)
		ZoneType.INDUSTRIAL:
			return Color(0.35, 0.35, 0.37)
	return Color.WHITE


# --- Population: buildings, huts, shops -------------------------------------
func _populate_zone(zone_type: int) -> void:
	var origin: Vector3 = zone_origins[zone_type]
	var structure_count := 0
	var spacing := 0.0
	match zone_type:
		ZoneType.RURAL:
			structure_count = 14
			spacing = 22.0
		ZoneType.HOMETOWN:
			structure_count = 30
			spacing = 16.0
		ZoneType.INDUSTRIAL:
			structure_count = 10
			spacing = 28.0

	var per_row := int(ceil(sqrt(structure_count)))
	var placed := 0
	var start_x := origin.x - (per_row * spacing) / 2.0
	var start_z := origin.z - (per_row * spacing) / 2.0

	for row in range(per_row):
		for col in range(per_row):
			if placed >= structure_count:
				return
			var jitter := Vector3(randf_range(-2.0, 2.0), 0, randf_range(-2.0, 2.0))
			var pos := Vector3(start_x + col * spacing, 0, start_z + row * spacing) + jitter
			_place_structure(zone_type, pos)
			placed += 1


func _place_structure(zone_type: int, pos: Vector3) -> void:
	var kind := _pick_structure_kind(zone_type)
	var structure := _make_structure(kind)
	structure.position = pos
	structure.rotation_degrees.y = [0, 90, 180, 270].pick_random()
	add_child(structure)

	_add_door_and_interior(structure, kind, pos)

	if zone_type == ZoneType.HOMETOWN and kind != "shop":
		_hometown_house_positions.append(pos)
	if kind == "shop" or kind == "building":
		_workplaces.append({"pos": pos, "kind": kind})


func _pick_structure_kind(zone_type: int) -> String:
	var roll := randf()
	match zone_type:
		ZoneType.RURAL:
			return "hut" if roll < 0.8 else "shop"
		ZoneType.HOMETOWN:
			if roll < 0.55:
				return "building"
			elif roll < 0.8:
				return "shop"
			else:
				return "hut"
		ZoneType.INDUSTRIAL:
			return "building"
	return "building"


func _make_structure(kind: String) -> StaticBody3D:
	var body := StaticBody3D.new()
	var size := Vector3.ZERO
	var color := Color.WHITE

	match kind:
		"hut":
			size = Vector3(randf_range(4, 6), randf_range(3, 4), randf_range(4, 6))
			color = Color(0.62, 0.5, 0.35)
		"shop":
			size = Vector3(randf_range(6, 9), randf_range(4, 5), randf_range(6, 9))
			color = Color(0.75, 0.35, 0.3)
		"building":
			size = Vector3(randf_range(8, 14), randf_range(10, 30), randf_range(8, 14))
			color = Color(0.5, 0.55, 0.6)
		_:
			size = Vector3(6, 4, 6)
			color = Color.GRAY

	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	mesh.material = mat

	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position.y = size.y / 2.0
	body.add_child(mi)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	col.position.y = size.y / 2.0
	body.add_child(col)

	body.set_meta("kind", kind)
	body.set_meta("size", size)
	return body


# --- Doors + interiors -------------------------------------------------------
## Adds a walk-in door trigger on the structure's front face and builds a
## matching interior room far from the main map. Stepping on either door
## teleports the player between exterior and interior.
func _add_door_and_interior(structure: StaticBody3D, kind: String, exterior_pos: Vector3) -> Node3D:
	var size: Vector3 = structure.get_meta("size")

	var entry_door := Area3D.new()
	entry_door.name = "EntryDoor"
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.5, 2, 1.5)
	col.shape = shape
	entry_door.add_child(col)
	entry_door.position = Vector3(0, 1, size.z / 2.0 + 0.75)
	structure.add_child(entry_door)

	_interior_counter += 1
	var interior := InteriorBuilder.build_interior(kind)
	var interior_offset := Vector3(0, 0, 5000 + _interior_counter * 60.0)
	interior.position = interior_offset
	add_child(interior)

	var interior_spawn := interior_offset + Vector3(0, 1, 0)
	var exterior_spawn := exterior_pos + Vector3(0, 1, size.z / 2.0 + 2.0)

	entry_door.body_entered.connect(func(body):
		if body.is_in_group("player"):
			body.teleport_to(interior_spawn)
	)

	var exit_door: Area3D = interior.get_node("ExitDoor")
	exit_door.body_entered.connect(func(body):
		if body.is_in_group("player"):
			body.teleport_to(exterior_spawn)
	)

	return interior


# --- School -------------------------------------------------------------------
func _build_school() -> void:
	var hometown_origin: Vector3 = zone_origins[ZoneType.HOMETOWN]
	_school_pos = hometown_origin + Vector3(-60, 0, -70)  # fixed spot, away from house grid

	var body := StaticBody3D.new()
	var size := Vector3(30, 10, 18)
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.8, 0.65, 0.4)  # brick school color
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position.y = size.y / 2.0
	body.add_child(mi)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	col.position.y = size.y / 2.0
	body.add_child(col)

	body.set_meta("kind", "school")
	body.set_meta("size", size)
	body.position = _school_pos
	add_child(body)

	# School interior: a hallway, with a door to each subject classroom.
	var hall_interior := _add_door_and_interior(body, "school_hall", _school_pos)
	_add_classrooms(hall_interior)


## Adds one door + classroom interior per subject off the school hall,
## each with a stationary teacher standing at the front desk.
func _add_classrooms(hall_interior: Node3D) -> void:
	var subjects := [
		{"name": "Maths", "teacher": "Mr. Aldridge", "color": Color(0.2, 0.4, 0.8)},
		{"name": "English", "teacher": "Ms. Bellamy", "color": Color(0.6, 0.2, 0.5)},
		{"name": "Physics", "teacher": "Dr. Corvin", "color": Color(0.3, 0.6, 0.3)},
		{"name": "Chemistry", "teacher": "Dr. Osei", "color": Color(0.8, 0.5, 0.1)},
		{"name": "Biology", "teacher": "Ms. Whitfield", "color": Color(0.5, 0.7, 0.2)},
	]
	var hall_size := Vector2(20, 8)  # must match InteriorBuilder's "school_hall" size
	var count := subjects.size()
	var spacing := hall_size.x / float(count + 1)
	var start_x := -hall_size.x / 2.0 + spacing

	for i in range(count):
		var subj: Dictionary = subjects[i]
		var door_x: float = start_x + i * spacing

		var hall_door := Area3D.new()
		hall_door.name = "ClassroomDoor_%s" % subj["name"]
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(1.5, 2, 1.0)
		col.shape = shape
		hall_door.add_child(col)
		hall_door.position = Vector3(door_x, 1, -hall_size.y / 2.0 + 0.5)
		hall_interior.add_child(hall_door)

		_interior_counter += 1
		var classroom := InteriorBuilder.build_interior("school_classroom")
		var offset := Vector3(0, 0, 5000 + _interior_counter * 60.0)
		classroom.position = offset
		add_child(classroom)

		var classroom_spawn := offset + Vector3(0, 1, 3)
		var hall_spawn := hall_interior.position + Vector3(door_x, 1, -hall_size.y / 2.0 + 1.5)

		hall_door.body_entered.connect(func(body):
			if body.is_in_group("player"):
				body.teleport_to(classroom_spawn)
		)
		var exit_door: Area3D = classroom.get_node("ExitDoor")
		exit_door.body_entered.connect(func(body):
			if body.is_in_group("player"):
				body.teleport_to(hall_spawn)
		)

		_spawn_teacher(classroom, Vector3(0, 0, -4.8), subj["color"], "%s\n%s" % [subj["teacher"], subj["name"]])


## Places a stationary teacher (capsule + name/subject label) at the front
## of a classroom.
func _spawn_teacher(parent: Node3D, local_pos: Vector3, color: Color, label_text: String) -> void:
	var holder := Node3D.new()
	holder.position = local_pos
	parent.add_child(holder)

	var mesh_inst := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.35
	mesh.height = 1.6
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh.material = mat
	mesh_inst.mesh = mesh
	mesh_inst.position.y = 0.9
	holder.add_child(mesh_inst)

	var label := Label3D.new()
	label.text = label_text
	label.position = Vector3(0, 2.0, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 32
	holder.add_child(label)


# --- NPCs -----------------------------------------------------------------
func _spawn_npcs() -> void:
	var role_colors := [Color(0.7, 0.6, 0.2), Color(0.2, 0.6, 0.7), Color(0.6, 0.3, 0.6)]
	for job in _workplaces:
		var home: Vector3 = job["pos"]
		if not _hometown_house_positions.is_empty():
			home = _hometown_house_positions.pick_random()

		var npc := CharacterBody3D.new()
		npc.set_script(NPCScript)
		npc.home_pos = home + Vector3(2, 0, 2)
		npc.work_pos = job["pos"] + Vector3(0, 0, 3)
		npc.role_color = role_colors.pick_random()
		add_child(npc)


# --- Player (Joseph) ---------------------------------------------------------
func _spawn_player() -> void:
	if not _hometown_house_positions.is_empty():
		_joseph_home_pos = _hometown_house_positions.pick_random()
	else:
		_joseph_home_pos = zone_origins[ZoneType.HOMETOWN]

	var player := CharacterBody3D.new()
	player.set_script(PlayerScript)
	add_child(player)
	player.global_position = _joseph_home_pos + Vector3(3, 1, 3)


# --- Roads connecting the three zones -----------------------------------------
func _build_connecting_roads() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.2, 0.2)

	for pair in [[ZoneType.RURAL, ZoneType.HOMETOWN], [ZoneType.HOMETOWN, ZoneType.INDUSTRIAL]]:
		var a: Vector3 = zone_origins[pair[0]]
		var b: Vector3 = zone_origins[pair[1]]
		var mid := (a + b) / 2.0
		var length := a.distance_to(b) - ZONE_WIDTH

		var mesh := PlaneMesh.new()
		mesh.size = Vector2(length, ROAD_WIDTH)
		mesh.material = mat

		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.position = mid
		add_child(mi)
