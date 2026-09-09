extends CanvasLayer
## HUD: a top-down minimap + health bar in the top-left, and a day/time
## clock in the top-right. Created by WorldGenerator once the player exists.

const MAP_SIZE := 160.0
const MAP_WORLD_SPAN := 130.0  # world units visible across the minimap
const MAP_HEIGHT_ABOVE := 140.0

const CLOCK_WIDTH := 130.0
const CLOCK_HEIGHT := 46.0
const DAY_LENGTH := 120.0     # seconds per full day/night cycle -- matches NPC.gd's day_length default
const DAY_START_HOUR := 22.0  # phase 0.0 = 10 PM, lining up with NPCs starting their day AT_HOME

var _player: CharacterBody3D
var _map_camera: Camera3D
var _health_fill: ColorRect
var _corruption_fill: ColorRect
var _corruption_label: Label
var _act_label: Label
var _clock_label: Label
var _world_elapsed := 0.0
var _day_count := 1
const BAR_WIDTH := MAP_SIZE - 8.0


func setup(player: CharacterBody3D) -> void:
	_player = player
	_build_minimap()
	_build_health_bar()
	_build_corruption_bar()
	_build_clock()
	_build_act_label()
	player.health_changed.connect(_on_health_changed)
	_on_health_changed(player.health, 100.0)
	StoryManager.corruption_changed.connect(_on_corruption_changed)
	StoryManager.act_changed.connect(_on_act_changed)
	_on_corruption_changed(StoryManager.corruption, 0)
	_on_act_changed(StoryManager.current_act, StoryManager.current_act)


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
	var ratio: float = clamp(current / max_hp, 0.0, 1.0)
	_health_fill.size.x = BAR_WIDTH * ratio
	_health_fill.color = Color(0.8, 0.15, 0.15).lerp(Color(0.2, 0.8, 0.3), ratio)


## "Integrity" reads the same 0-100 value as StoryManager.corruption, just
## inverted in framing (full bar = clean) so a *higher* fill still means
## "better", matching the health bar just above it rather than needing the
## player to learn "low bar is good" for this one meter only.
func _build_corruption_bar() -> void:
	var bg := Panel.new()
	bg.position = Vector2(16, 16 + MAP_SIZE + 8.0 + 18.0 + 6.0)
	bg.size = Vector2(MAP_SIZE, 18)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.5)
	style.set_corner_radius_all(4)
	bg.add_theme_stylebox_override("panel", style)
	add_child(bg)

	_corruption_fill = ColorRect.new()
	_corruption_fill.color = Color(0.7, 0.6, 0.2)
	_corruption_fill.position = Vector2(2, 2)
	_corruption_fill.size = Vector2(BAR_WIDTH, 14)
	bg.add_child(_corruption_fill)

	_corruption_label = Label.new()
	_corruption_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_corruption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_corruption_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_corruption_label.add_theme_font_size_override("font_size", 11)
	_corruption_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	bg.add_child(_corruption_label)


func _on_corruption_changed(new_value: int, _delta: int) -> void:
	var ratio: float = 1.0 - clamp(new_value / 100.0, 0.0, 1.0)
	_corruption_fill.size.x = BAR_WIDTH * ratio
	_corruption_fill.color = Color(0.8, 0.15, 0.15).lerp(Color(0.2, 0.7, 0.5), ratio)
	_corruption_label.text = "Integrity: %d%%" % int(ratio * 100.0)


## Top-right panel showing an in-world clock, mirroring the minimap panel's
## style. Runs on its own independent timer (not synced to any one NPC's
## staggered schedule) over the same DAY_LENGTH every NPC's day/night cycle
## uses, so it reads as "the time of day" rather than any specific person's.
func _build_clock() -> void:
	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.position = Vector2(-16.0 - CLOCK_WIDTH, 16.0)
	panel.size = Vector2(CLOCK_WIDTH, CLOCK_HEIGHT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.35)
	style.border_color = Color(1, 1, 1, 0.6)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	_clock_label = Label.new()
	_clock_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_clock_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_clock_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	_clock_label.add_theme_font_size_override("font_size", 16)
	panel.add_child(_clock_label)

	_update_clock_label()


func _update_clock_label() -> void:
	if not _clock_label:
		return
	var phase := _world_elapsed / DAY_LENGTH
	var total_hours := fmod(DAY_START_HOUR + phase * 24.0, 24.0)
	var hour := int(total_hours)
	var minute := int((total_hours - hour) * 60.0)
	var am_pm := "AM" if hour < 12 else "PM"
	var hour12 := hour % 12
	if hour12 == 0:
		hour12 = 12
	_clock_label.text = "Day %d\n%02d:%02d %s" % [_day_count, hour12, minute, am_pm]


## Small unobtrusive label under the clock naming the current story act
## (StoryManager.ACT_NAMES), so a player who hasn't been tracking dialogue
## closely can still tell the story has moved on.
func _build_act_label() -> void:
	_act_label = Label.new()
	_act_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_act_label.position = Vector2(-16.0 - CLOCK_WIDTH, 16.0 + CLOCK_HEIGHT + 4.0)
	_act_label.size = Vector2(CLOCK_WIDTH, 20)
	_act_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_act_label.add_theme_font_size_override("font_size", 12)
	_act_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	add_child(_act_label)


func _on_act_changed(new_act: int, _old_act: int) -> void:
	if _act_label:
		_act_label.text = StoryManager.ACT_NAMES.get(new_act, "")


func _process(delta: float) -> void:
	if _player and _map_camera:
		_map_camera.global_position = Vector3(_player.global_position.x, _player.global_position.y + MAP_HEIGHT_ABOVE, _player.global_position.z)

	_world_elapsed += delta
	if _world_elapsed >= DAY_LENGTH:
		_world_elapsed = fmod(_world_elapsed, DAY_LENGTH)
		_day_count += 1
	_update_clock_label()
