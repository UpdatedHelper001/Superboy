extends Node
## Headless smoke test: walks every authored DialogueTree along every
## branch, confirming every next_id/choice "next" resolves to a real line
## (or END), and reports the corruption/flag outcome of each path. Not a
## gameplay test (no UI involved) -- just verifies the authored content
## itself is well-formed before trusting it in-engine. Runs as a real Node
## in a real scene (see scenes/story_test.tscn) rather than a custom
## SceneTree --script, because autoloads like StoryManager aren't
## initialized in that mode.

func _ready() -> void:
	_check("prologue", StoryContent.prologue())
	_check("act1_candidate", StoryContent.act1_candidate())
	_walk_all_paths("act2_rise", StoryContent.act2_rise())
	_walk_all_paths("act3_president", StoryContent.act3_president())
	_walk_all_paths("act4_shadow_government", StoryContent.act4_shadow_government())
	_check("act5_mafia", StoryContent.act5_mafia())
	_check("act6_mirror", StoryContent.act6_mirror())
	_check("act7_collapse", StoryContent.act7_collapse())
	for tier in [StoryManager.CorruptionTier.REFORMER, StoryManager.CorruptionTier.COMPROMISED, StoryManager.CorruptionTier.TYRANT]:
		StoryManager.corruption = 0
		StoryManager.add_corruption(tier * 40)  # cheap way to land in each band for the test
		_check("final_act(tier=%d)" % StoryManager.corruption_tier(), StoryContent.final_act())

	_check_save_roundtrip()

	print("All dialogue trees OK.")
	get_tree().quit()


func _check_save_roundtrip() -> void:
	StoryManager.reset()
	StoryManager.set_flag("took_businessman_support", true)
	StoryManager.add_corruption(42)
	StoryManager.advance_act(StoryManager.Act.PRESIDENT)
	SaveManager.save_state()

	StoryManager.reset()
	assert(StoryManager.corruption == 0 and not StoryManager.has_flag("took_businessman_support"))

	var ok := SaveManager.load_state()
	if not ok or StoryManager.corruption != 42 or not StoryManager.has_flag("took_businessman_support") or StoryManager.current_act != StoryManager.Act.PRESIDENT:
		push_error("SaveManager round-trip failed: ok=%s corruption=%d act=%d" % [ok, StoryManager.corruption, StoryManager.current_act])
		get_tree().quit(1)
		return
	print("save/load round-trip OK (corruption=%d, act=%d)" % [StoryManager.corruption, StoryManager.current_act])
	SaveManager.delete_save()
	StoryManager.reset()


func _check(name: String, tree: DialogueTree) -> void:
	var cur := tree.start_id
	var steps := 0
	while cur != "" and cur != "END":
		var line := tree.get_line(cur)
		if line == null:
			push_error("%s: dangling id '%s'" % [name, cur])
			get_tree().quit(1)
			return
		steps += 1
		if steps > 200:
			push_error("%s: possible infinite loop" % name)
			get_tree().quit(1)
			return
		cur = line.next_id
	print("%s: %d lines, linear OK" % [name, steps])


## For trees with a choice node, recursively follows every branch.
func _walk_all_paths(name: String, tree: DialogueTree, start: String = "", corruption := 0, depth := 0) -> void:
	var cur: String = start if start != "" else tree.start_id
	while true:
		if cur == "" or cur == "END":
			print("%s: path ended, corruption=%d" % [name, corruption])
			return
		var line := tree.get_line(cur)
		if line == null:
			push_error("%s: dangling id '%s'" % [name, cur])
			get_tree().quit(1)
			return
		if not line.choices.is_empty():
			for choice in line.choices:
				var delta: int = choice.get("corruption_delta", 0)
				_walk_all_paths(name, tree, choice.get("next", ""), corruption + delta, depth + 1)
			return
		cur = line.next_id
