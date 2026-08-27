class_name InteriorBuilder
extends RefCounted
## Builds simple low-poly interior rooms for structures. Each interior is a
## sealed box (floor + 4 walls) with basic furniture placeholders and an
## "ExitDoor" Area3D the player steps on to leave. The exit door's target
## position is set by the caller (WorldGenerator) after building.

static func build_interior(kind: String) -> Node3D:
	var room := Node3D.new()
	room.name = "Interior_%s" % kind

	var room_size := Vector2(8, 8)
	match kind:
		"shop":
			room_size = Vector2(9, 9)
		"building":
			room_size = Vector2(10, 10)
		"school_classroom":
			room_size = Vector2(12, 10)
		"school_hall":
			room_size = Vector2(20, 8)

	_add_floor(room, room_size)
	_add_walls(room, room_size, 4.0)
	_add_light(room)
	_add_furniture(room, kind, room_size)
	_add_exit_door(room)

	return room


static func _add_floor(room: Node3D, size: Vector2) -> void:
	var mesh := PlaneMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.6, 0.55, 0.5)
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	room.add_child(mi)


static func _add_walls(room: Node3D, size: Vector2, height: float) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.83, 0.78)

	var configs := [
		{"pos": Vector3(0, height / 2.0, -size.y / 2.0), "size": Vector3(size.x, height, 0.3)},
		{"pos": Vector3(0, height / 2.0, size.y / 2.0), "size": Vector3(size.x, height, 0.3)},
		{"pos": Vector3(-size.x / 2.0, height / 2.0, 0), "size": Vector3(0.3, height, size.y)},
		{"pos": Vector3(size.x / 2.0, height / 2.0, 0), "size": Vector3(0.3, height, size.y)},
	]
	for c in configs:
		var mesh := BoxMesh.new()
		mesh.size = c["size"]
		mesh.material = mat
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.position = c["pos"]
		room.add_child(mi)

		var body := StaticBody3D.new()
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = c["size"]
		col.shape = shape
		body.position = c["pos"]
		body.add_child(col)
		room.add_child(body)


static func _add_light(room: Node3D) -> void:
	var light := OmniLight3D.new()
	light.position = Vector3(0, 3.5, 0)
	light.light_energy = 1.3
	light.omni_range = 12
	room.add_child(light)


static func _add_furniture(room: Node3D, kind: String, size: Vector2) -> void:
	match kind:
		"hut":
			_box(room, Vector3(-2, 0.4, -2), Vector3(1.8, 0.8, 2.2), Color(0.4, 0.3, 0.2))  # bed
			_box(room, Vector3(2, 0.4, 1.5), Vector3(1.2, 0.8, 1.2), Color(0.5, 0.35, 0.2))  # table
		"shop":
			_box(room, Vector3(0, 0.5, -3.5), Vector3(6, 1.0, 0.8), Color(0.45, 0.3, 0.2))  # counter
			_box(room, Vector3(-3.5, 0.75, 0), Vector3(0.6, 1.5, 4), Color(0.4, 0.25, 0.15))  # shelf
			_box(room, Vector3(3.5, 0.75, 0), Vector3(0.6, 1.5, 4), Color(0.4, 0.25, 0.15))  # shelf
		"building":
			for i in range(4):
				var x := -3.0 + (i % 2) * 6.0
				var z := -3.0 + int(i / 2) * 6.0
				_box(room, Vector3(x, 0.4, z), Vector3(1.4, 0.8, 0.8), Color(0.5, 0.4, 0.3))  # desk
		"school_classroom":
			_box(room, Vector3(0, 0.5, -4), Vector3(2.2, 1.0, 0.8), Color(0.4, 0.3, 0.2))  # teacher desk
			for row in range(2):
				for col in range(3):
					var x := -4.0 + col * 4.0
					var z := -1.0 + row * 2.5
					_box(room, Vector3(x, 0.35, z), Vector3(1.0, 0.7, 0.6), Color(0.55, 0.45, 0.3))  # student desk
		"school_hall":
			_box(room, Vector3(0, 0.75, -3.5), Vector3(18, 1.5, 0.6), Color(0.6, 0.6, 0.65))  # lockers


static func _box(room: Node3D, pos: Vector3, size: Vector3, color: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	room.add_child(mi)


static func _add_exit_door(room: Node3D) -> void:
	var door := Area3D.new()
	door.name = "ExitDoor"
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.5, 2, 1.5)
	col.shape = shape
	door.add_child(col)
	door.position = Vector3(0, 1, 3.3)
	room.add_child(door)
