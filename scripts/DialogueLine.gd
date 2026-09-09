extends Resource
class_name DialogueLine
## One beat in a DialogueTree. Most of the script's prose is narration --
## a single line with no choices, auto-advancing to `next_id` on tap. Real
## decision points (the businessman's offer, the journalist, etc.) set
## `choices` instead; each choice is a Dictionary so tree authors don't need
## a second Resource class just to describe a branch:
##   {"text": "Accept his support", "next": "act2_compromise_yes",
##    "set_flag": "took_businessman_support", "corruption_delta": 15}
## Only "text" and "next" are required; the rest default to no-op.

@export var id: String = ""
@export var speaker: String = ""
@export_multiline var text: String = ""

## Empty = this is narration; the box shows a "continue" tap instead of buttons.
@export var choices: Array[Dictionary] = []

## Where to go next when there are no choices. "" or "END" closes the box.
@export var next_id: String = ""

## Effects applied the moment this line is shown (for narration beats that
## set a flag/corruption without needing a fake single-option choice).
@export var set_flag: String = ""
@export var flag_value: bool = true
@export var corruption_delta: int = 0
