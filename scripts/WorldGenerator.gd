extends Node3D
## Procedurally builds the Nova Terra open-world map: districts matching the
## city map (Suburban West, Residential North, Downtown/Financial, Old Town,
## Greenwood Park, Industrial East, Port Authority, South Beach), each with
## buildings and walk-in interiors. Spawns school, NPCs, and the player.

const ROAD_WIDTH := 10.0
const DOOR_WIDTH := 2.0
const DOOR_HEIGHT := 2.3
const WALL_THICKNESS := 0.4

# --- Building facade art (art/textures) -------------------------------------
# Each 1280x720 source PNG is really a 720x720 square facade card,
# horizontally centered with transparent padding on both sides -- crop that
# out rather than stretching the padding into the building.
const FACADE_CROP := Rect2(280, 0, 720, 720)
const FACADE_VARIANTS := 8
const DISTRICT_TEXTURE_FOLDER := {
	"residential": "residential",
	"downtown": "downtown",
	"old_town": "old_town",
	"industrial": "industrial",
	"port": "port",
	"beach": "beach",
}

# --- District signage (art/decals) -------------------------------------------
# Decals are a wide horizontal pill, vertically centered in the same
# 1280x720 canvas -- a different crop than the building facades above.
const SIGN_CROP := Rect2(0, 200, 1280, 320)
const DISTRICT_SIGNS := [
	{"zone": "downtown", "decal": "downtown_finance_sign"},
	{"zone": "greenwood_park", "decal": "greenwood_park_sign"},
	{"zone": "industrial_east", "decal": "industrial_logistics_sign"},
	{"zone": "old_town", "decal": "old_town_market_sign"},
	{"zone": "port_authority", "decal": "port_authority_sign"},
	{"zone": "suburban_west", "decal": "residential_sign"},
	{"zone": "residential_north", "decal": "residential_sign"},
	{"zone": "south_beach", "decal": "south_beach_sign"},
]

# Zone adjacency, also used by _build_connecting_roads below -- hoisted to a
# shared const so district sign placement can point each sign toward
# whichever neighboring zone people are most likely arriving from.
const ZONE_LINKS := [
	["suburban_west", "residential_north"],
	["suburban_west", "old_town"],
	["residential_north", "downtown"],
	["downtown", "old_town"],
	["downtown", "industrial_east"],
	["old_town", "greenwood_park"],
	["industrial_east", "port_authority"],
	["greenwood_park", "port_authority"],
	["greenwood_park", "south_beach"],
	["old_town", "south_beach"],
]

var _interior_counter := 0
var _house_positions: Array = []  # Array of {"pos": Vector3, "front": Vector3} — "front" is the world-space point just outside that house's actual door
var _workplaces: Array = []       # Array of {"pos": Vector3, "kind": String, "front": Vector3}
var _school_pos: Vector3
var ZONES: Array = []

const PlayerScript := preload("res://scripts/Player.gd")
const NPCScript := preload("res://scripts/NPC.gd")
const HUDScript := preload("res://scripts/HUD.gd")

## Buildings (each with its own interior room) spawned per frame during
## chunked generation, and NPCs (each with an articulated body) spawned per
## frame right after. Kept low enough that no single frame does much more
## work than a normal gameplay frame -- see _populate_zones_chunked below.
const STRUCTURES_PER_CHUNK := 5
const NPCS_PER_CHUNK := 6


func _ready() -> void:
	randomize()
	_define_zones()
	_build_environment()
	for z in ZONES:
		_build_ground(z)
	_build_connecting_roads()
	_build_school()
	_place_district_signs()

	# Building ~180 structures (each with a separate interior room) and then
	# ~150+ NPCs (each with a multi-part articulated body) all in a single
	# frame used to stall the game for a very noticeable moment on startup --
	# worst of all on the low-end/Android hardware this project targets. Both
	# passes are chunked across multiple frames instead, with a loading
	# screen tracking progress.
	var loading := _show_loading_screen()
	await _populate_zones_chunked(loading)
	await _spawn_npcs_chunked(loading)
	await _spawn_ambient_npcs_chunked(loading)
	_hide_loading_screen(loading)

	_spawn_player()


# --- Chunked generation / loading screen -------------------------------------
func _show_loading_screen() -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)

	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.08, 0.94)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)

	var label := Label.new()
	label.name = "LoadingLabel"
	label.text = "Generating Nova Terra... 0%"
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	layer.add_child(label)

	return layer


func _update_loading(loading: CanvasLayer, done: int, total: int, prefix: String = "Generating Nova Terra") -> void:
	if not loading:
		return
	var label := loading.get_node("LoadingLabel") as Label
	if not label:
		return
	var pct := 100 if total <= 0 else int(round(100.0 * done / total))
	label.text = "%s... %d%%" % [prefix, pct]


func _hide_loading_screen(loading: CanvasLayer) -> void:
	if loading:
		loading.queue_free()


# --- District layout (mirrors the Nova Terra city map) ---------------------
func _define_zones() -> void:
	ZONES = [
		{"id":"suburban_west","kind":"residential","pos":Vector3(-320,0,-40),"size":Vector2(220,220),"count":34,"spacing":18},
		{"id":"residential_north","kind":"residential","pos":Vector3(0,0,-380),"size":Vector2(260,180),"count":40,"spacing":16},
		{"id":"downtown","kind":"downtown","pos":Vector3(0,0,-140),"size":Vector2(200,180),"count":26,"spacing":18},
		{"id":"old_town","kind":"old_town","pos":Vector3(-40,0,60),"size":Vector2(180,160),"count":24,"spacing":15},
		{"id":"greenwood_park","kind":"park","pos":Vector3(140,0,120),"size":Vector2(160,160),"count":4,"spacing":30},
		{"id":"industrial_east","kind":"industrial","pos":Vector3(280,0,-100),"size":Vector2(220,200),"count":14,"spacing":26},
		{"id":"port_authority","kind":"port","pos":Vector3(360,0,120),"size":Vector2(160,160),"count":8,"spacing":28},
		{"id":"south_beach","kind":"beach","pos":Vector3(60,0,280),"size":Vector2(260,120),"count":10,"spacing":22},
	]


func _zone_pos(id: String) -> Vector3:
	for z in ZONES:
		if z["id"] == id:
			return z["pos"]
	return Vector3.ZERO


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


func _build_ground(zone: Dictionary) -> void:
	var origin: Vector3 = zone["pos"]
	var size: Vector2 = zone["size"]
	var mesh := PlaneMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = _ground_color(zone["kind"])
	mat.roughness = 1.0
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = origin
	add_child(mi)

	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(size.x, 0.1, size.y)
	col.shape = shape
	body.position = origin
	body.add_child(col)
	add_child(body)


func _ground_color(kind: String) -> Color:
	match kind:
		"residential":
			return Color(0.62, 0.5, 0.42)
		"downtown":
			return Color(0.5, 0.5, 0.56)
		"old_town":
			return Color(0.58, 0.48, 0.36)
		"industrial":
			return Color(0.38, 0.38, 0.4)
		"port":
			return Color(0.45, 0.45, 0.5)
		"park":
			return Color(0.3, 0.55, 0.3)
		"beach":
			return Color(0.85, 0.78, 0.55)
	return Color.WHITE


# --- Population: buildings, huts, shops, trees -------------------------------

## Precomputes every structure's zone-kind and grid position (cheap, pure
## math) so the actual node-creation work below can be spread across frames
## without redoing this layout math each time.
func _collect_structure_slots() -> Array:
	var slots: Array = []
	for z in ZONES:
		var origin: Vector3 = z["pos"]
		var structure_count: int = z["count"]
		var spacing: float = z["spacing"]
		var kind: String = z["kind"]

		var per_row := int(ceil(sqrt(structure_count)))
		var placed := 0
		var start_x := origin.x - (per_row * spacing) / 2.0
		var start_z := origin.z - (per_row * spacing) / 2.0

		for row in range(per_row):
			for col in range(per_row):
				if placed >= structure_count:
					break
				var jitter := Vector3(randf_range(-2.0, 2.0), 0, randf_range(-2.0, 2.0))
				var pos := Vector3(start_x + col * spacing, 0, start_z + row * spacing) + jitter
				slots.append({"kind": kind, "pos": pos})
				placed += 1
			if placed >= structure_count:
				break
	return slots


## Spawns every building/hut/tree a handful at a time across multiple frames
## (STRUCTURES_PER_CHUNK per frame) instead of all ~180 structures -- each
## with its own interior room -- in one blocking burst.
func _populate_zones_chunked(loading: CanvasLayer) -> void:
	var slots := _collect_structure_slots()
	for i in range(slots.size()):
		var slot: Dictionary = slots[i]
		_place_structure(slot["kind"], slot["pos"])
		if i % STRUCTURES_PER_CHUNK == STRUCTURES_PER_CHUNK - 1:
			_update_loading(loading, i + 1, slots.size(), "Raising buildings")
			await get_tree().process_frame
	_update_loading(loading, slots.size(), slots.size(), "Raising buildings")


func _place_structure(zone_kind: String, pos: Vector3) -> void:
	var struct_kind := _pick_structure_kind(zone_kind)

	if struct_kind == "tree":
		_place_tree(pos)
		return

	var structure := _make_structure(struct_kind, zone_kind)
	structure.position = pos
	structure.rotation_degrees.y = [0, 90, 180, 270].pick_random()
	add_child(structure)

	_add_door_and_interior(structure, struct_kind, pos)
	var door_front: Vector3 = structure.get_meta("door_front")

	if zone_kind in ["residential", "old_town", "beach"] and struct_kind != "shop":
		_house_positions.append({"pos": pos, "front": door_front})
	if struct_kind == "shop" or struct_kind == "building":
		_workplaces.append({"pos": pos, "kind": struct_kind, "front": door_front})


func _pick_structure_kind(zone_kind: String) -> String:
	var roll := randf()
	match zone_kind:
		"residential":
			if roll < 0.7: return "hut"
			elif roll < 0.9: return "shop"
			else: return "building"
		"downtown":
			return "building"
		"old_town":
			return "hut" if roll < 0.4 else "shop"
		"industrial":
			return "building"
		"port":
			return "building"
		"park":
			return "tree"
		"beach":
			return "shop" if roll < 0.5 else "hut"
	return "building"


func _place_tree(pos: Vector3) -> void:
	var holder := Node3D.new()
	holder.position = pos
	var trunk := MeshInstance3D.new()
	var tmesh := CylinderMesh.new()
	tmesh.top_radius = 0.3
	tmesh.bottom_radius = 0.4
	tmesh.height = 2.0
	var tmat := StandardMaterial3D.new()
	tmat.albedo_color = Color(0.4, 0.28, 0.15)
	tmesh.material = tmat
	trunk.mesh = tmesh
	trunk.position.y = 1.0
	holder.add_child(trunk)

	var leaves := MeshInstance3D.new()
	var lmesh := SphereMesh.new()
	lmesh.radius = 1.6
	lmesh.height = 3.2
	var lmat := StandardMaterial3D.new()
	lmat.albedo_color = Color(0.2, 0.5, 0.22)
	lmesh.material = lmat
	leaves.mesh = lmesh
	leaves.position.y = 3.0
	holder.add_child(leaves)
	add_child(holder)


func _make_structure(kind: String, zone_kind: String) -> StaticBody3D:
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
	color = color.darkened(randf_range(0.0, 0.15))  # subtle variation where the base color still shows: roof cap, and the recessed doorway reveal
	var door_h := _build_door_shell(body, size, color)
	_add_roof_cap(body, size, color)

	# Shops always get the "commercial" set (baked-in awning + shop name);
	# everything else uses its own district's facade art if we have one.
	# Falls back to the old procedural window grid + awning for anything
	# without matching art (e.g. a zone kind added later with no art yet).
	var folder: String = "commercial" if kind == "shop" else DISTRICT_TEXTURE_FOLDER.get(zone_kind, "")
	if folder != "":
		_apply_facade(body, size, folder)
	else:
		_add_facade_windows(body, kind, size, size.x / 2.0 - DOOR_WIDTH / 2.0, size.z / 2.0)
		if kind == "shop":
			_add_shop_awning(body, door_h, size.z / 2.0)

	body.set_meta("kind", kind)
	body.set_meta("size", size)
	body.set_meta("door_h", door_h)
	return body


## Builds the recessed shell (main mass + doorway pillars/lintel/panel) shared
## by every walk-in structure, including the school. Returns the door height.
func _build_door_shell(body: StaticBody3D, size: Vector3, color: Color) -> float:
	var door_h: float = min(DOOR_HEIGHT, size.y - 0.4)
	var half_x := size.x / 2.0
	var half_z := size.z / 2.0
	var side_w := half_x - DOOR_WIDTH / 2.0

	# Recessed main mass (back + sides + roof), set behind the front face.
	_add_box_part(body, Vector3(0, size.y / 2.0, -WALL_THICKNESS / 2.0), Vector3(size.x, size.y, size.z - WALL_THICKNESS), color)
	# Front-left and front-right pillars flanking the doorway.
	_add_box_part(body, Vector3(-DOOR_WIDTH / 2.0 - side_w / 2.0, size.y / 2.0, half_z - WALL_THICKNESS / 2.0), Vector3(side_w, size.y, WALL_THICKNESS), color)
	_add_box_part(body, Vector3(DOOR_WIDTH / 2.0 + side_w / 2.0, size.y / 2.0, half_z - WALL_THICKNESS / 2.0), Vector3(side_w, size.y, WALL_THICKNESS), color)
	# Lintel closing the gap above the door.
	_add_box_part(body, Vector3(0, door_h + (size.y - door_h) / 2.0, half_z - WALL_THICKNESS / 2.0), Vector3(DOOR_WIDTH, size.y - door_h, WALL_THICKNESS), color)
	# Cosmetic door panel, no collision, sitting flush in the opening.
	_add_box_part(body, Vector3(0, door_h / 2.0, half_z - 0.05), Vector3(DOOR_WIDTH - 0.3, door_h - 0.15, 0.1), Color(0.32, 0.2, 0.12), false)
	return door_h


## Flat overhanging cap so structures don't read as bare extruded boxes.
func _add_roof_cap(body: StaticBody3D, size: Vector3, wall_color: Color) -> void:
	_add_box_part(body, Vector3(0, size.y + 0.12, 0), Vector3(size.x + 0.4, 0.24, size.z + 0.4), wall_color.darkened(0.35), false)


## Cosmetic window grid on the front pillars. Deliberately front-face-only
## (even for tall "building" kind) — with ~150 NPCs now roaming the map on
## top of every structure's geometry, lighting every face would add
## thousands of extra mesh nodes for windows most players never see anyway.
func _add_facade_windows(body: StaticBody3D, kind: String, size: Vector3, side_w: float, half_z: float) -> void:
	if side_w < 0.6:
		return
	var rows := clampi(int(size.y / 3.0), 1, 6)
	var cols := 1 if kind == "hut" else 2

	_add_window_grid(body, Vector3(-DOOR_WIDTH / 2.0 - side_w / 2.0, size.y / 2.0, half_z + 0.02), side_w, size.y, "z", cols, rows)
	_add_window_grid(body, Vector3(DOOR_WIDTH / 2.0 + side_w / 2.0, size.y / 2.0, half_z + 0.02), side_w, size.y, "z", cols, rows)


## Cosmetic (non-colliding) glass panes laid out in a grid across a face.
## `thin_axis` picks which local axis the pane is flattened along ("x" or "z").
func _add_window_grid(body: StaticBody3D, center: Vector3, width: float, height: float, thin_axis: String, cols: int, rows: int) -> void:
	var margin_w := width * 0.15
	var margin_h := height * 0.18
	var usable_w := width - margin_w * 2.0
	var usable_h := height - margin_h * 2.0
	if usable_w <= 0.1 or usable_h <= 0.1:
		return
	var cell_w := usable_w / cols
	var cell_h := usable_h / rows
	var win_w := cell_w * 0.6
	var win_h := cell_h * 0.55

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.75, 0.85)
	mat.emission_enabled = true
	mat.emission = Color(0.6, 0.8, 0.9)
	mat.emission_energy_multiplier = 0.4

	for r in range(rows):
		for c in range(cols):
			var off_w: float = -usable_w / 2.0 + cell_w * (c + 0.5)
			var off_h: float = -usable_h / 2.0 + cell_h * (r + 0.5)
			var mesh := BoxMesh.new()
			var mi := MeshInstance3D.new()
			if thin_axis == "z":
				mesh.size = Vector3(win_w, win_h, 0.04)
				mi.position = center + Vector3(off_w, off_h, 0)
			else:
				mesh.size = Vector3(0.04, win_h, win_w)
				mi.position = center + Vector3(0, off_h, off_w)
			mesh.material = mat
			mi.mesh = mesh
			body.add_child(mi)


## Small striped overhang above a shop's door.
func _add_shop_awning(body: StaticBody3D, door_h: float, half_z: float) -> void:
	_add_box_part(body, Vector3(0, door_h + 0.18, half_z + 0.45), Vector3(DOOR_WIDTH + 0.6, 0.1, 0.7), Color(0.8, 0.15, 0.15), false)


func _random_facade_texture(folder: String) -> Texture2D:
	var idx := randi_range(1, FACADE_VARIANTS)
	var path := "res://art/textures/%s/%s_%02d.png" % [folder, folder, idx]
	var base := load(path) as Texture2D
	if not base:
		return null
	var atlas := AtlasTexture.new()
	atlas.atlas = base
	atlas.region = FACADE_CROP
	return atlas


## A single textured quad standing in for the old procedural window grid +
## (for shops) the flat awning box -- the art pack's facade art already
## bakes in windows, a roofline, a door, and (for the "commercial" set) an
## awning with a shop name. Non-colliding and sits just proud of the real
## recessed door shell/collision built by _build_door_shell, so players and
## NPCs still walk straight through it to the actual door trigger behind.
func _apply_facade(structure: StaticBody3D, size: Vector3, folder: String) -> void:
	var tex := _random_facade_texture(folder)
	if not tex:
		return

	var mesh := PlaneMesh.new()
	mesh.size = Vector2(size.x, size.y)
	mesh.orientation = PlaneMesh.FACE_Z
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.roughness = 0.85
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED  # reads correctly regardless of which way the generated winding faces
	mesh.material = mat

	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = Vector3(0, size.y / 2.0, size.z / 2.0 + 0.03)
	structure.add_child(mi)


func _add_box_part(body: StaticBody3D, pos: Vector3, size: Vector3, color: Color, collide: bool = true) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	mesh.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	body.add_child(mi)

	if collide:
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		col.shape = shape
		col.position = pos
		body.add_child(col)


# --- Doors + interiors -------------------------------------------------------
func _add_door_and_interior(structure: StaticBody3D, kind: String, exterior_pos: Vector3) -> Node3D:
	var size: Vector3 = structure.get_meta("size")
	var door_h: float = structure.get_meta("door_h")
	# The door itself is built in local space facing local +Z, so it already
	# rotates correctly with the structure. But callers that need a *target*
	# point outside the door (NPC work/home spots, the player's spawn, the
	# exit-door teleport) previously assumed that local +Z always equals
	# world +Z -- wrong for 3 out of 4 of the random Y rotations applied in
	# _place_structure, and even at rotation 0 the old fixed offsets landed
	# inside the structure's own solid collision instead of outside it. Read
	# the structure's actual world-space forward axis here instead, once,
	# and hand every caller a point that's genuinely outside the building.
	var door_dir: Vector3 = structure.transform.basis.z

	var entry_door := Area3D.new()
	entry_door.name = "EntryDoor"
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(DOOR_WIDTH - 0.1, door_h, 1.2)
	col.shape = shape
	entry_door.add_child(col)
	entry_door.monitoring = true
	entry_door.position = Vector3(0, door_h / 2.0, size.z / 2.0 + 0.3)
	structure.add_child(entry_door)

	_interior_counter += 1
	var interior := InteriorBuilder.build_interior(kind)
	var interior_offset := Vector3(0, 0, 5000 + _interior_counter * 60.0)
	interior.position = interior_offset
	add_child(interior)

	var interior_spawn := interior_offset + Vector3(0, 1, 0)
	var exterior_spawn := exterior_pos + door_dir * (size.z / 2.0 + 2.0) + Vector3(0, 1, 0)
	# A safe, reusable "stand outside this door" point for NPC targeting and
	# player home-spawn -- same idea as exterior_spawn above, just without
	# the height lift (NPCs/ground logic add their own).
	structure.set_meta("door_front", exterior_pos + door_dir * (size.z / 2.0 + 2.5))

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
	var res_origin: Vector3 = _zone_pos("residential_north")
	_school_pos = res_origin + Vector3(-60, 0, -70)

	var body := StaticBody3D.new()
	var size := Vector3(30, 10, 18)
	var color := Color(0.8, 0.65, 0.4)
	var door_h := _build_door_shell(body, size, color)
	_add_roof_cap(body, size, color)
	_apply_facade(body, size, "civic")

	body.set_meta("kind", "school")
	body.set_meta("size", size)
	body.set_meta("door_h", door_h)
	body.position = _school_pos
	add_child(body)

	var hall_interior := _add_door_and_interior(body, "school_hall", _school_pos)
	_add_classrooms(hall_interior)


func _add_classrooms(hall_interior: Node3D) -> void:
	var subjects := [
		{"name": "Maths", "teacher": "Mr. Aldridge", "color": Color(0.2, 0.4, 0.8)},
		{"name": "English", "teacher": "Ms. Bellamy", "color": Color(0.6, 0.2, 0.5)},
		{"name": "Physics", "teacher": "Dr. Corvin", "color": Color(0.3, 0.6, 0.3)},
		{"name": "Chemistry", "teacher": "Dr. Osei", "color": Color(0.8, 0.5, 0.1)},
		{"name": "Biology", "teacher": "Ms. Whitfield", "color": Color(0.5, 0.7, 0.2)},
	]
	var hall_size := Vector2(20, 8)
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
		hall_door.monitoring = true
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

## One commuter NPC per workplace, a handful at a time across frames (each
## NPC also builds a multi-part articulated body the same frame it spawns).
## home_pos/work_pos both come from the "front" points computed in
## _add_door_and_interior, so every commute target is a real point just
## outside a door rather than inside the building's own solid collision.
func _spawn_npcs_chunked(loading: CanvasLayer) -> void:
	var role_colors := [Color(0.7, 0.6, 0.2), Color(0.2, 0.6, 0.7), Color(0.6, 0.3, 0.6)]
	for i in range(_workplaces.size()):
		var job: Dictionary = _workplaces[i]
		var home_front: Vector3 = job["front"]  # fallback if no houses exist: lives at their own workplace
		if not _house_positions.is_empty():
			home_front = _house_positions.pick_random()["front"]

		var npc := CharacterBody3D.new()
		npc.set_script(NPCScript)
		npc.home_pos = home_front
		npc.work_pos = job["front"]
		npc.role_color = role_colors.pick_random()
		add_child(npc)

		if i % NPCS_PER_CHUNK == NPCS_PER_CHUNK - 1:
			_update_loading(loading, i + 1, _workplaces.size(), "Sending residents to work")
			await get_tree().process_frame


## Extra pedestrians with no job — they just drift around their district —
## so streets, the market, and the park feel lived-in instead of empty
## between the commuter NPCs' scheduled trips. Also chunked across frames.
func _spawn_ambient_npcs_chunked(loading: CanvasLayer) -> void:
	var role_colors := [Color(0.7, 0.6, 0.2), Color(0.2, 0.6, 0.7), Color(0.6, 0.3, 0.6), Color(0.3, 0.7, 0.4), Color(0.8, 0.5, 0.3), Color(0.75, 0.4, 0.25)]
	# Foot-traffic density per district kind (fraction of that zone's structure count).
	var density := {"downtown": 0.5, "old_town": 0.5, "beach": 0.4, "residential": 0.2, "industrial": 0.15, "port": 0.15}

	var spawns: Array = []
	for z in ZONES:
		var kind: String = z["kind"]
		var count: int
		if kind == "park":
			count = 8  # joggers/walkers even though the park has no workplaces
		else:
			count = int(z["count"] * density.get(kind, 0.0))
		var radius: float = min(z["size"].x, z["size"].y) / 2.0 * 0.75
		for i in range(count):
			var spawn_pos: Vector3 = z["pos"] + Vector3(randf_range(-radius, radius), 0, randf_range(-radius, radius))
			spawns.append({"pos": spawn_pos, "radius": radius})

	for i in range(spawns.size()):
		var s: Dictionary = spawns[i]
		var npc := CharacterBody3D.new()
		npc.set_script(NPCScript)
		npc.is_ambient = true
		npc.home_pos = s["pos"]
		npc.work_pos = s["pos"]
		npc.wander_radius = s["radius"]
		npc.role_color = role_colors.pick_random()
		add_child(npc)

		if i % NPCS_PER_CHUNK == NPCS_PER_CHUNK - 1:
			_update_loading(loading, i + 1, spawns.size(), "Filling the streets")
			await get_tree().process_frame


# --- Player (Joseph) ---------------------------------------------------------
func _spawn_player() -> void:
	var home_front: Vector3
	if not _house_positions.is_empty():
		home_front = _house_positions.pick_random()["front"]
	else:
		home_front = _zone_pos("residential_north")

	var player := CharacterBody3D.new()
	player.set_script(PlayerScript)
	add_child(player)
	var spawn_pos := home_front + Vector3(0, 1, 0)
	player.global_position = spawn_pos
	player.home_position = spawn_pos

	var hud := CanvasLayer.new()
	hud.set_script(HUDScript)
	add_child(hud)
	hud.setup(player)


# --- District entrance signage (art/decals) -----------------------------------

## Points from a zone's center toward whichever neighboring zone ZONE_LINKS
## says it connects to first, so a district's sign faces roughly toward the
## road most people actually arrive from.
func _primary_neighbor_dir(zone_id: String, zone_pos: Vector3) -> Vector3:
	for pair in ZONE_LINKS:
		if pair[0] == zone_id or pair[1] == zone_id:
			var other_id: String = pair[1] if pair[0] == zone_id else pair[0]
			var dir: Vector3 = _zone_pos(other_id) - zone_pos
			dir.y = 0
			if dir.length() > 0.01:
				return dir.normalized()
	return Vector3(0, 0, 1)


func _find_zone(id: String) -> Dictionary:
	for z in ZONES:
		if z["id"] == id:
			return z
	return {}


func _place_district_signs() -> void:
	for entry in DISTRICT_SIGNS:
		var zone := _find_zone(entry["zone"])
		if zone.is_empty():
			continue
		var zone_pos: Vector3 = zone["pos"]
		var size: Vector2 = zone["size"]
		var dir := _primary_neighbor_dir(entry["zone"], zone_pos)
		var reach: float = min(size.x, size.y) / 2.0 * 0.85
		_place_sign(zone_pos + dir * reach, -dir, entry["decal"])

	# A neutral "Welcome to Nova Terra" landmark near the school -- itself a
	# civic building not tied to any one commercial district -- rather than
	# favoring one district's sign over the others.
	_place_sign(_school_pos + Vector3(-22, 0, 4), Vector3(1, 0, 0), "nova_terra_neutral_sign")


## A simple post + double-sided textured board. `facing_dir` is the guessed
## direction approaching traffic comes from; the material is double-sided so
## the sign still reads fine even if that guess is off by 180 degrees.
func _place_sign(pos: Vector3, facing_dir: Vector3, decal_name: String) -> void:
	var base := load("res://art/decals/%s.png" % decal_name) as Texture2D
	if not base:
		return
	var tex := AtlasTexture.new()
	tex.atlas = base
	tex.region = SIGN_CROP

	var post := MeshInstance3D.new()
	var post_mesh := BoxMesh.new()
	post_mesh.size = Vector3(0.22, 2.0, 0.22)
	var post_mat := StandardMaterial3D.new()
	post_mat.albedo_color = Color(0.32, 0.3, 0.27)
	post_mesh.material = post_mat
	post.mesh = post_mesh
	post.position = pos + Vector3(0, 1.0, 0)
	add_child(post)

	var aspect: float = float(tex.get_width()) / float(tex.get_height())
	var board_h := 1.0
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(board_h * aspect, board_h)
	mesh.orientation = PlaneMesh.FACE_Z
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material = mat

	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos + Vector3(0, 2.15, 0)
	add_child(mi)
	if facing_dir.length() > 0.01:
		mi.look_at(mi.position + facing_dir, Vector3.UP)


# --- Roads connecting districts (mirrors map adjacency) ----------------------
func _build_connecting_roads() -> void:
	var road_mat := StandardMaterial3D.new()
	road_mat.albedo_color = Color(0.2, 0.2, 0.2)
	var curb_mat := StandardMaterial3D.new()
	curb_mat.albedo_color = Color(0.75, 0.75, 0.7)
	var line_mat := StandardMaterial3D.new()
	line_mat.albedo_color = Color(0.95, 0.85, 0.3)
	line_mat.emission_enabled = true
	line_mat.emission = Color(0.9, 0.8, 0.2)
	line_mat.emission_energy_multiplier = 0.3

	var links := ZONE_LINKS

	for pair in links:
		var a := _zone_pos(pair[0])
		var b := _zone_pos(pair[1])
		var mid := (a + b) / 2.0
		var length := a.distance_to(b)
		var yaw := rad_to_deg(atan2(b.z - a.z, b.x - a.x)) * -1.0 + 90.0

		var road := Node3D.new()
		road.position = mid
		road.rotation_degrees.y = yaw
		add_child(road)

		var mesh := PlaneMesh.new()
		mesh.size = Vector2(length, ROAD_WIDTH)
		mesh.material = road_mat
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		road.add_child(mi)

		# Raised curb strips along both edges.
		for side in [-1.0, 1.0]:
			var curb := MeshInstance3D.new()
			var curb_mesh := BoxMesh.new()
			curb_mesh.size = Vector3(length, 0.15, 0.4)
			curb_mesh.material = curb_mat
			curb.mesh = curb_mesh
			curb.position = Vector3(0, 0.05, side * (ROAD_WIDTH / 2.0 - 0.2))
			road.add_child(curb)

		# Dashed centre line along the direction of travel.
		var dash_len := 3.0
		var gap_len := 5.0
		var stride := dash_len + gap_len
		var dash_count := mini(int(length / stride), 80)  # cap for very long roads
		var start_x := -length / 2.0 + stride / 2.0
		for i in range(dash_count):
			var dash := MeshInstance3D.new()
			var dash_mesh := BoxMesh.new()
			dash_mesh.size = Vector3(dash_len, 0.02, 0.25)
			dash_mesh.material = line_mat
			dash.mesh = dash_mesh
			dash.position = Vector3(start_x + i * stride, 0.03, 0)
			road.add_child(dash)
