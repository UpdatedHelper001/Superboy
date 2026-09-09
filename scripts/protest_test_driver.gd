extends Node

func _ready() -> void:
	await get_tree().create_timer(1.0).timeout
	var main := get_node("../Main")
	StoryManager.advance_act(StoryManager.Act.COLLAPSE)
	await get_tree().process_frame
	print("protesters_spawned=%s palace_pos=%s" % [main._protesters_spawned, main._palace_pos])
	get_tree().quit()
