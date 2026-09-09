extends Resource
class_name DialogueTree
## An authored conversation/cutscene: a flat, order-doesn't-matter array of
## DialogueLine so it's editable as a plain Inspector list, addressed by
## `id` string rather than array index (so choices can jump forward/back
## without every insert renumbering every jump target).

@export var start_id: String = ""
@export var lines: Array[DialogueLine] = []

var _by_id: Dictionary = {}
var _indexed := false


func get_line(line_id: String) -> DialogueLine:
	if not _indexed:
		_build_index()
	return _by_id.get(line_id)


func _build_index() -> void:
	_by_id.clear()
	for line in lines:
		if line.id != "":
			_by_id[line.id] = line
	_indexed = true
