class_name TouchControls
extends CanvasLayer
## On-screen touch controls for Android/mobile builds: a virtual joystick
## (bottom-left) drives movement, dragging anywhere on the right ~65% of the
## screen looks around, and a round button (bottom-right) jumps.
##
## Player.gd only creates this when OS.has_feature("mobile") is true, so
## desktop keyboard/mouse play is completely untouched by this script.
## Raw InputEventScreenTouch/Drag events are used directly (each tracked by
## its own finger `index`) instead of relying on "emulate mouse from touch",
## which is disabled in project.godot to prevent the same drag being counted
## twice (once here, once as emulated mouse-look in Player.gd).

var move_vector := Vector2.ZERO   # -1..1 per axis, polled by Player each physics frame
var look_delta := Vector2.ZERO    # accumulated screen-drag delta; drained via consume_look_delta()

const JOY_RADIUS := 65.0
const JOY_KNOB_RADIUS := 30.0
const JOY_GRAB_SLOP := 1.6          # a touch starting a little outside the base still grabs the stick
const JOY_MARGIN := Vector2(120, 120)

const JUMP_RADIUS := 42.0
const JUMP_GRAB_SLOP := 1.4
const JUMP_MARGIN := Vector2(90, 130)

const TALK_RADIUS := 34.0
const TALK_GRAB_SLOP := 1.4
const TALK_MARGIN := Vector2(90, 210)  # stacked above the jump button

const LOOK_REGION_FRACTION := 0.35  # touches right of this fraction of the screen width can look around

var _joy_touch := -1
var _joy_center := Vector2.ZERO
var _joy_knob: _Circle

var _look_touch := -1
var _look_region_x := 0.0

var _jump_touch := -1
var _jump_center := Vector2.ZERO

var _talk_touch := -1
var _talk_center := Vector2.ZERO


## Minimal translucent circle, drawn directly (no texture assets needed).
class _Circle extends Control:
	var radius := 40.0
	var color := Color(1, 1, 1, 0.2)
	func _draw() -> void:
		draw_circle(Vector2.ZERO, radius, color)


var _joy_base: _Circle
var _jump_circle: _Circle
var _talk_circle: _Circle
var _talk_label: Label


func _ready() -> void:
	layer = 20
	_joy_base = _add_circle(JOY_RADIUS, Color(1, 1, 1, 0.15))
	_joy_knob = _add_circle(JOY_KNOB_RADIUS, Color(1, 1, 1, 0.35))
	_jump_circle = _add_circle(JUMP_RADIUS, Color(1, 1, 1, 0.3))
	_talk_circle = _add_circle(TALK_RADIUS, Color(1, 1, 1, 0.3))
	_talk_label = Label.new()
	_talk_label.text = "Talk"
	_talk_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_talk_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	_talk_label.add_theme_font_size_override("font_size", 13)
	add_child(_talk_label)
	# The viewport isn't guaranteed to already report its final on-screen
	# size on the very first frame (e.g. while the window is still being set
	# up), so lay out now AND whenever the size changes, instead of trusting
	# a single _ready()-time read.
	get_viewport().size_changed.connect(_relayout)
	_relayout()


func _relayout() -> void:
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	_look_region_x = vp_size.x * LOOK_REGION_FRACTION
	_joy_center = Vector2(JOY_MARGIN.x, vp_size.y - JOY_MARGIN.y)
	_jump_center = Vector2(vp_size.x - JUMP_MARGIN.x, vp_size.y - JUMP_MARGIN.y)
	_talk_center = Vector2(vp_size.x - TALK_MARGIN.x, vp_size.y - TALK_MARGIN.y)
	_joy_base.position = _joy_center
	_joy_knob.position = _joy_center
	_jump_circle.position = _jump_center
	_talk_circle.position = _talk_center
	_talk_label.position = _talk_center - Vector2(16, 8)


func _add_circle(radius: float, color: Color) -> _Circle:
	var c := _Circle.new()
	c.radius = radius
	c.color = color
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	return c


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		# Android occasionally sends a single pressed=false, index=-1 event to
		# mean "all fingers were cancelled" (e.g. an incoming call/notification)
		# instead of individual release events per finger. Reset everything.
		if not event.pressed and event.index == -1:
			_reset_all()
			return
		if event.pressed:
			_touch_start(event.index, event.position)
		else:
			_touch_end(event.index)
	elif event is InputEventScreenDrag:
		_touch_drag(event.index, event.position, event.relative)


func _touch_start(index: int, pos: Vector2) -> void:
	if _joy_touch == -1 and pos.distance_to(_joy_center) <= JOY_RADIUS * JOY_GRAB_SLOP:
		_joy_touch = index
		_update_joy(pos)
	elif _jump_touch == -1 and pos.distance_to(_jump_center) <= JUMP_RADIUS * JUMP_GRAB_SLOP:
		_jump_touch = index
		Input.action_press("ui_accept")
	elif _talk_touch == -1 and pos.distance_to(_talk_center) <= TALK_RADIUS * TALK_GRAB_SLOP:
		_talk_touch = index
		Input.action_press("interact")
	elif _look_touch == -1 and pos.x >= _look_region_x:
		_look_touch = index


func _touch_end(index: int) -> void:
	if index == _joy_touch:
		_joy_touch = -1
		move_vector = Vector2.ZERO
		_joy_knob.position = _joy_center
	if index == _jump_touch:
		_jump_touch = -1
		Input.action_release("ui_accept")
	if index == _talk_touch:
		_talk_touch = -1
		Input.action_release("interact")
	if index == _look_touch:
		_look_touch = -1


func _touch_drag(index: int, pos: Vector2, relative: Vector2) -> void:
	if index == _joy_touch:
		_update_joy(pos)
	elif index == _look_touch:
		look_delta += relative


func _update_joy(pos: Vector2) -> void:
	var offset := pos - _joy_center
	if offset.length() > JOY_RADIUS:
		offset = offset.normalized() * JOY_RADIUS
	_joy_knob.position = _joy_center + offset
	move_vector = offset / JOY_RADIUS


func _reset_all() -> void:
	_joy_touch = -1
	_look_touch = -1
	_jump_touch = -1
	_talk_touch = -1
	move_vector = Vector2.ZERO
	Input.action_release("ui_accept")
	Input.action_release("interact")
	if _joy_knob:
		_joy_knob.position = _joy_center


## Called once per physics frame by Player.gd; returns and clears the
## accumulated look-drag delta so a drag isn't applied to rotation twice.
func consume_look_delta() -> Vector2:
	var d := look_delta
	look_delta = Vector2.ZERO
	return d
