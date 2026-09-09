extends Node
## Autoload (registered after StoryManager in project.godot [autoload], so
## StoryManager already exists by the time anything here runs). Persists
## StoryManager's act/flags/corruption to disk so a session can resume where
## it left off.
##
## Checkpoints are act boundaries only, not mid-dialogue lines: save_state()
## is called by WorldGenerator right after StoryManager.advance_act(), never
## mid-DialogueTree. This is a deliberate scope cut, not an oversight --
## saving/restoring an in-progress DialogueRunner's exact line and re-deriving
## which choices were already answered (without re-applying their corruption
## deltas a second time) is real complexity for a case ("quit mid-conversation")
## that a simple "resume at the start of the current act" already handles
## safely. The cost: quitting mid-Act-III (say, right after the journalist
## choice) and reloading replays that act's dialogue from its start, including
## the choice already made. Player-facing effect: none of the story's acts
## take long to replay, and no corruption/flag ever gets double-applied,
## since resuming re-enters the act at its first line rather than resuming
## the runner's saved position.

const SAVE_PATH := "user://savegame.json"


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_state() -> void:
	var data := {
		"act": StoryManager.current_act,
		"corruption": StoryManager.corruption,
		"flags": StoryManager.flags,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("SaveManager: could not open %s for writing (err %d)" % [SAVE_PATH, FileAccess.get_open_error()])
		return
	file.store_string(JSON.stringify(data))
	file.close()


## Returns true if a valid save was found and applied to StoryManager.
func load_state() -> bool:
	if not has_save():
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("SaveManager: could not open %s for reading (err %d)" % [SAVE_PATH, FileAccess.get_open_error()])
		return false
	var text := file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("SaveManager: %s did not contain a valid save (corrupt or empty)" % SAVE_PATH)
		return false

	StoryManager.current_act = parsed.get("act", StoryManager.Act.PROLOGUE)
	StoryManager.corruption = parsed.get("corruption", 0)
	StoryManager.flags = parsed.get("flags", {})
	return true


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
