extends Node
class_name DialogueRunner
## Plays a DialogueTree against a DialogueBox: advances line-by-line,
## applies each line's/choice's flag + corruption effects through
## StoryManager (the only writer of story state -- this node never touches
## StoryManager's Dictionary directly, always through set_flag/add_corruption
## so `flag_changed`/`corruption_changed` listeners elsewhere fire correctly),
## and emits `finished` when the tree runs out.

signal finished

var _tree: DialogueTree
var _box: DialogueBox
var _current_id: String


func play(tree: DialogueTree, box: DialogueBox) -> void:
	_tree = tree
	_box = box
	_current_id = tree.start_id
	if not _box.continue_pressed.is_connected(_on_continue):
		_box.continue_pressed.connect(_on_continue)
	if not _box.choice_pressed.is_connected(_on_choice):
		_box.choice_pressed.connect(_on_choice)
	_advance()


func _advance() -> void:
	if _current_id == "" or _current_id == "END":
		_box.hide_box()
		finished.emit()
		return

	var line := _tree.get_line(_current_id)
	if line == null:
		push_warning("DialogueRunner: no line with id '%s' in tree" % _current_id)
		_box.hide_box()
		finished.emit()
		return

	_apply_effects(line.set_flag, line.flag_value, line.corruption_delta)
	_box.show_line(line.speaker, line.text, line.choices)
	if line.choices.is_empty():
		_current_id = line.next_id


func _apply_effects(flag_name: String, flag_value: bool, corruption_delta: int) -> void:
	if corruption_delta != 0:
		StoryManager.add_corruption(corruption_delta)
	if flag_name != "":
		StoryManager.set_flag(flag_name, flag_value)


func _on_continue() -> void:
	_advance()


func _on_choice(choice: Dictionary) -> void:
	_apply_effects(choice.get("set_flag", ""), choice.get("flag_value", true), choice.get("corruption_delta", 0))
	_current_id = choice.get("next", "")
	_advance()
