extends Node
## Autoload singleton (see project.godot [autoload]) holding all narrative
## state for "Joseph -- The Man He Hated": which act is active, every flag
## set by a dialogue choice, and the corruption meter that drives late-game
## world reactions and which Final Act ending plays. Everything else --
## dialogue, missions, NPC reactions -- reads/writes through this single
## source of truth rather than keeping its own copy of story state.

signal act_changed(new_act: int, old_act: int)
signal flag_changed(flag_name: String, value)
signal corruption_changed(new_value: int, delta: int)

enum Act {
	PROLOGUE,           # The Last Day
	CANDIDATE,          # Act I
	RISE,               # Act II
	PRESIDENT,          # Act III
	SHADOW_GOVERNMENT,  # Act IV
	MAFIA,              # Act V
	MIRROR,             # Act VI
	COLLAPSE,           # Act VII
	FINAL,              # Final Act
}

## Matches CorruptionTier below -- kept here as documentation of which
## story beat corresponds to which act, since Act enum values alone don't
## say that. Update this alongside any Act reordering.
const ACT_NAMES := {
	Act.PROLOGUE: "The Last Day",
	Act.CANDIDATE: "The Candidate",
	Act.RISE: "The Rise",
	Act.PRESIDENT: "The President",
	Act.SHADOW_GOVERNMENT: "The Shadow Government",
	Act.MAFIA: "The Mafia",
	Act.MIRROR: "The Man in the Mirror",
	Act.COLLAPSE: "Collapse",
	Act.FINAL: "The President",
}

enum CorruptionTier { REFORMER, COMPROMISED, TYRANT }

const CORRUPTION_MIN := 0
const CORRUPTION_MAX := 100
## Bands chosen so making only the story's "required" compromises (each
## act has at least one beat that adds corruption regardless of dialogue
## choice) lands solidly in COMPROMISED, not at either extreme -- the
## extremes should require either refusing every optional compromise
## (REFORMER) or actively pursuing every available one (TYRANT).
const TIER_THRESHOLDS := {CorruptionTier.REFORMER: 30, CorruptionTier.COMPROMISED: 70}

var current_act: int = Act.PROLOGUE
var flags: Dictionary = {}
var corruption: int = 0


func set_flag(flag_name: String, value = true) -> void:
	if flags.get(flag_name) == value:
		return
	flags[flag_name] = value
	flag_changed.emit(flag_name, value)


func has_flag(flag_name: String) -> bool:
	return flags.get(flag_name, false) != false


func get_flag(flag_name: String, default = null):
	return flags.get(flag_name, default)


func advance_act(new_act: int) -> void:
	if new_act == current_act:
		return
	var old := current_act
	current_act = new_act
	act_changed.emit(current_act, old)


func add_corruption(delta: int) -> void:
	if delta == 0:
		return
	var old := corruption
	corruption = clampi(corruption + delta, CORRUPTION_MIN, CORRUPTION_MAX)
	if corruption != old:
		corruption_changed.emit(corruption, corruption - old)


func corruption_tier() -> int:
	if corruption < TIER_THRESHOLDS[CorruptionTier.REFORMER]:
		return CorruptionTier.REFORMER
	elif corruption < TIER_THRESHOLDS[CorruptionTier.COMPROMISED]:
		return CorruptionTier.COMPROMISED
	else:
		return CorruptionTier.TYRANT


## Full reset -- used by a future main-menu "New Game", not called anywhere
## yet. Kept here rather than left implicit so a save/load system (whenever
## one gets built) has one obvious place that defines "blank slate".
func reset() -> void:
	flags.clear()
	corruption = 0
	current_act = Act.PROLOGUE
