extends CanvasLayer
class_name DialogueBox
## Bottom-of-screen dialogue/choice UI, built the same way HUD.gd builds its
## minimap/health/clock panels (plain Panel + StyleBoxFlat, no .tscn) so the
## project has one UI-construction convention instead of two. One instance
## is created per scene that needs it (see DialogueRunner.play) and freed
## when the conversation ends -- unlike HUD, which persists for the whole
## session, dialogue is scene-local.

signal continue_pressed
signal choice_pressed(choice: Dictionary)

const BOX_HEIGHT := 170.0
const MARGIN := 24.0

var _panel: Panel
var _speaker_label: Label
var _text_label: Label
var _choice_box: VBoxContainer
var _continue_hint: Label
var _awaiting_continue := false


func _ready() -> void:
	layer = 60
	_build_ui()
	hide_box()


func _build_ui() -> void:
	_panel = Panel.new()
	_panel.anchor_left = 0.0
	_panel.anchor_right = 1.0
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = MARGIN
	_panel.offset_right = -MARGIN
	_panel.offset_top = -BOX_HEIGHT - MARGIN
	_panel.offset_bottom = -MARGIN
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.03, 0.05, 0.85)
	style.border_color = Color(1, 1, 1, 0.5)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	_speaker_label = Label.new()
	_speaker_label.position = Vector2(0, 0)
	_speaker_label.add_theme_font_size_override("font_size", 17)
	_speaker_label.add_theme_color_override("font_color", Color(0.95, 0.8, 0.3))
	_panel.add_child(_speaker_label)

	_text_label = Label.new()
	_text_label.position = Vector2(0, 26)
	_text_label.size = Vector2(0, 0)  # sized in show_line once panel width is known
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_text_label.add_theme_font_size_override("font_size", 16)
	_text_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	_panel.add_child(_text_label)

	_choice_box = VBoxContainer.new()
	_choice_box.add_theme_constant_override("separation", 4)
	_panel.add_child(_choice_box)

	_continue_hint = Label.new()
	_continue_hint.text = "\u25be tap to continue"
	_continue_hint.add_theme_font_size_override("font_size", 13)
	_continue_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	_panel.add_child(_continue_hint)


## `choices` is the same Array[Dictionary] format as DialogueLine.choices --
## each needs at least a "text" key. Pass an empty array for narration.
func show_line(speaker: String, text: String, choices: Array[Dictionary]) -> void:
	_panel.visible = true
	_speaker_label.text = speaker
	_text_label.text = text
	_text_label.size = Vector2(_panel.size.x - 32.0, BOX_HEIGHT - 60.0)

	for child in _choice_box.get_children():
		child.queue_free()

	if choices.is_empty():
		_awaiting_continue = true
		_continue_hint.visible = true
		_continue_hint.position = Vector2(_panel.size.x - 150.0, BOX_HEIGHT - 34.0)
		_choice_box.visible = false
	else:
		_awaiting_continue = false
		_continue_hint.visible = false
		_choice_box.visible = true
		_choice_box.position = Vector2(0, 50)
		_choice_box.size = Vector2(_panel.size.x - 32.0, 0)
		for choice in choices:
			var btn := Button.new()
			btn.text = str(choice.get("text", "..."))
			btn.custom_minimum_size = Vector2(0, 32)
			btn.pressed.connect(_on_choice_button_pressed.bind(choice))
			_choice_box.add_child(btn)


func hide_box() -> void:
	_panel.visible = false
	_awaiting_continue = false


func _on_choice_button_pressed(choice: Dictionary) -> void:
	choice_pressed.emit(choice)


func _unhandled_input(event: InputEvent) -> void:
	if not _awaiting_continue or not _panel.visible:
		return
	var tapped: bool = false
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		tapped = true
	elif event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		tapped = true
	elif event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).keycode == KEY_SPACE:
		tapped = true
	if tapped:
		get_viewport().set_input_as_handled()
		_awaiting_continue = false
		continue_pressed.emit()
