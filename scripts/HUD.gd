extends CanvasLayer
## Top-left HUD: a top-down minimap that follows the player, plus a health
## bar underneath it. Created by WorldGenerator once the player exists.

const MAP_SIZE := 160.0
const MAP_WORLD_SPAN := 130.0  # world units visible across the minimap
const MAP_HEIGHT_ABOVE := 140.0

var _player: CharacterBody3D
var _map_camera: Camera3D
var _health_fill: ColorRect
const BAR_WIDTH := MAP_SIZE - 8.0


func setup(player: CharacterBody3D) -> void:
	_player = player
	_build_minimap()
	_build_health_bar()
	player.health_changed.connect(_on_health_changed)
	_on_health_changed(player.health, 100.0)


func _build_minimap() -> void:
	var panel := Panel.new()
	panel.position = Vector2(16, 16)
	panel.size = Vector2(MAP_SIZE, MAP_SIZE)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.35)
	style.border_color = Color(1, 1, 1, 0.6)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var margin := 5.0
	var vp_container := SubViewportContainer.new()
	vp_container.position = Vector2(margin, margin)
	vp_container.size = Vector2(MAP_SIZE - margin * 2.0, MAP_SIZE - margin * 2.0)
	vp_container.stretch = true
	vp_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(vp_container)

	var sub := SubViewport.new()
	sub.size = Vector2i(vp_container.size)
	sub.transparent_bg = false
	vp_container.add_child(sub)

	_map_camera = Camera3D.new()
	_map_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_map_camera.size = MAP_WORLD_SPAN
	_map_camera.rotation_degrees = Vector3(-90, 0, 0)  # looking straight down
	_map_camera.far = MAP_HEIGHT_ABOVE + 50.0
	_map_camera.current = true
	sub.add_child(_map_camera)

	# "You are here" marker — the camera always stays centred on the player.
	var marker := ColorRect.new()
	marker.color = Color(1.0, 0.25, 0.2)
	marker.size = Vector2(7, 7)
	marker.position = panel.size / 2.0 - marker.size / 2.0
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(marker)

	var n_label := Label.new()
	n_label.text = "N"
	n_label.position = Vector2(panel.size.x / 2.0 - 6.0, 1.0)
	n_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	n_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(n_label)


func _build_health_bar() -> void:
	var bg := Panel.new()
	bg.position = Vector2(16, 16 + MAP_SIZE + 8.0)
	bg.size = Vector2(MAP_SIZE, 18)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.5)
	style.set_corner_radius_all(4)
	bg.add_theme_stylebox_override("panel", style)
	add_child(bg)

	_health_fill = ColorRect.new()
	_health_fill.color = Color(0.2, 0.8, 0.3)
	_health_fill.position = Vector2(2, 2)
	_health_fill.size = Vector2(BAR_WIDTH, 14)
	bg.add_child(_health_fill)


func _on_health_changed(current: float, max_hp: float) -> void:
	var ratio := clamp(current / max_hp, 0.0, 1.0)
	_health_fill.size.x = BAR_WIDTH * ratio
	_health_fill.color = Color(0.8, 0.15, 0.15).lerp(Color(0.2, 0.8, 0.3), ratio)


func _process(_delta: float) -> void:
	if _player and _map_camera:
		_map_camera.global_position = Vector3(_player.global_position.x, _player.global_position.y + MAP_HEIGHT_ABOVE, _player.global_position.z)
