extends RefCounted
class_name StoryContent
## Authored DialogueTree content for "Joseph -- The Man He Hated", kept
## separate from DialogueTree/DialogueRunner (the reusable machinery) so
## later acts can each get their own static builder function here without
## touching the runtime classes. The Prologue is pure narration -- the
## actual story has no player-facing choice until Act II's businessman
## offer -- so every line here auto-advances via next_id.

static func prologue() -> DialogueTree:
	var tree := DialogueTree.new()
	tree.start_id = "p1"
	tree.lines = [
		_line("p1", "", "Joseph is an ordinary employee at OOO Corporation -- one of the country's largest infrastructure companies. He isn't rich. He isn't powerful. He isn't particularly ambitious.", "p2"),
		_line("p2", "", "But Joseph has one thing that separates him from the people around him: he hates corruption.", "p3"),
		_line("p3", "", "He watches executives manipulate contracts, politicians protect corporations, and ordinary workers get blamed for decisions made by people above them. Joseph believes the system is broken -- but he still believes it can be fixed.", "p4"),
		_line("p4", "", "One morning, Joseph is called into his manager's office.", "p5"),
		_line("p5", "Manager", "We're restructuring. Your position's been eliminated.", "p6"),
		_line("p6", "", "Joseph knows the real reason. He had refused to approve a suspicious project document.", "p7"),
		_line("p7", "", "He walks out of OOO carrying a small box containing everything he owned at his desk.", "p8"),
		_line("p8", "", "That evening, Joseph watches a political speech on television. The politician talks about corruption. Joseph laughs bitterly.", "p9"),
		_line("p9", "Joseph", "They all become the same eventually.", "p10"),
		_line("p10", "Friend", "Then why don't you change it?", "p11"),
		_line("p11", "", "Joseph doesn't answer. That question stays with him.", "END", "heard_friend_challenge"),
	]
	return tree


static func act1_candidate() -> DialogueTree:
	var tree := DialogueTree.new()
	tree.start_id = "a1_1"
	tree.lines = [
		_line("a1_1", "", "Joseph enters local politics. At first, he is exactly what people hoped for.", "a1_2"),
		_line("a1_2", "", "He visits poor neighborhoods. He listens to workers. He exposes small corruption scandals. He refuses expensive gifts. He travels without an enormous security team.", "a1_3"),
		_line("a1_3", "", "People begin calling him \"The People's Candidate.\" Joseph's popularity grows.", "a1_4"),
		_line("a1_4", "", "But politics teaches him something uncomfortable: doing the right thing isn't enough. His opponents have money. They control newspapers. They influence businesses. They manipulate public opinion.", "a1_5"),
		_line("a1_5", "", "Joseph loses his first major election.", "a1_6"),
		_line("a1_6", "", "But instead of leaving politics, he studies the system. He learns how elections actually work. Who funds campaigns. Who controls contracts. Who influences ministers. Who controls the media.", "a1_7"),
		_line("a1_7", "", "And slowly... Joseph begins changing.", "END", "act1_complete"),
	]
	return tree


## Act II's businessman-support offer is the story's first real corruption
## fork (see StoryManager.corruption_tier) -- everything before this is
## fixed narration because the source script never frames it as a choice.
## Both branches converge back into the same Act III onward; only the
## corruption delta and the flag persist as a difference for now.
static func act2_rise() -> DialogueTree:
	var tree := DialogueTree.new()
	tree.start_id = "a2_1"
	tree.lines = [
		_line("a2_1", "", "Joseph forms his own political movement. His message is simple: \"No more corruption.\"", "a2_2"),
		_line("a2_2", "", "This time he wins. He becomes a powerful national politician.", "a2_3"),
		_line("a2_3", "", "His reforms initially work. OOO Corporation loses several government contracts. Corrupt officials are investigated. Joseph becomes extremely popular.", "a2_4"),
		_line("a2_4", "", "Then comes the first compromise. A wealthy businessman offers Joseph political support.", "a2_5"),
		_line("a2_5", "Adviser", "You don't have to become corrupt. You just have to understand how the game works.", "a2_choice"),
	]

	var choice := DialogueLine.new()
	choice.id = "a2_choice"
	choice.text = "Without funding, Joseph's next election campaign could collapse. Does he accept the businessman's support?"
	choice.choices = [
		{"text": "Accept the support", "next": "a2_accept", "set_flag": "took_businessman_support", "corruption_delta": 15},
		{"text": "Refuse it", "next": "a2_refuse", "set_flag": "refused_businessman_support", "corruption_delta": -5},
	]
	tree.lines.append(choice)
	tree.lines.append(_line("a2_accept", "", "Joseph accepts the support. Nothing immediately goes wrong. That's what makes it dangerous.", "END"))
	tree.lines.append(_line("a2_refuse", "", "Joseph refuses. The campaign becomes a fight for survival on a fraction of his opponents' funding -- but he digs in anyway.", "END"))
	return tree


## Act III has three independent creeping-compromise choices (journalist,
## ally, businessmen) rather than one big fork like Act II -- each is
## individually smaller (+10/-5) since the source text frames these as
## incremental, self-justified steps ("It's temporary", "It's necessary"),
## not a single dramatic turn.
static func act3_president() -> DialogueTree:
	var tree := DialogueTree.new()
	tree.start_id = "a3_1"
	tree.lines = [
		_line("a3_1", "", "Joseph wins the presidential election. The country celebrates. The same man who once walked out of OOO with a cardboard box now enters the presidential palace.", "a3_2"),
		_line("a3_2", "", "For the first few years, Joseph genuinely changes the country. Infrastructure improves. Government services become faster. Several corrupt officials are removed.", "a3_3"),
		_line("a3_3", "", "But Joseph becomes obsessed with maintaining control. \"If I lose power, everything I built will disappear.\" So he starts making compromises.", "a3_journalist"),
	]

	var journalist := DialogueLine.new()
	journalist.id = "a3_journalist"
	journalist.text = "A journalist is investigating his government."
	journalist.choices = [
		{"text": "Pressure the journalist", "next": "a3_ally", "set_flag": "pressured_journalist", "corruption_delta": 10},
		{"text": "Let the investigation continue", "next": "a3_ally", "set_flag": "protected_press_freedom", "corruption_delta": -5},
	]
	tree.lines.append(journalist)

	var ally := DialogueLine.new()
	ally.id = "a3_ally"
	ally.text = "A political ally faces prosecution over a corruption case."
	ally.choices = [
		{"text": "Protect the ally from prosecution", "next": "a3_businessmen", "set_flag": "protected_ally", "corruption_delta": 10},
		{"text": "Let the ally face justice", "next": "a3_businessmen", "set_flag": "exposed_ally", "corruption_delta": -5},
	]
	tree.lines.append(ally)

	var businessmen := DialogueLine.new()
	businessmen.id = "a3_businessmen"
	businessmen.text = "The businessmen who funded his rise want rewards."
	businessmen.choices = [
		{"text": "Reward the businessmen who support him", "next": "a3_close", "set_flag": "rewarded_businessmen", "corruption_delta": 10},
		{"text": "Refuse them special favors", "next": "a3_close", "set_flag": "refused_businessmen_favors", "corruption_delta": -5},
	]
	tree.lines.append(businessmen)

	tree.lines.append(_line("a3_close", "", "Each decision seems small. Each one has a justification. \"It's temporary.\" \"It's necessary.\" \"I'm doing this for the country.\"", "END", "act3_complete"))
	return tree


## Act IV's "does he destroy the network or use it" is written in the source
## as inevitable ("Instead... He starts using them"), not a real choice --
## same situation as Act II's businessman offer. Giving the player a
## "dismantle" option that still converges back into the same network
## keeps the choice meaningful (corruption delta, flag) without forking
## Acts V-VII, which assume Joseph is using the network either way.
static func act4_shadow_government() -> DialogueTree:
	var tree := DialogueTree.new()
	tree.start_id = "a4_1"
	tree.lines = [
		_line("a4_1", "", "Joseph discovers that politics isn't controlled only by politicians. Behind the government exists a network of businessmen, criminals, political fixers and influential officials.", "a4_2"),
		_line("a4_2", "", "They don't care about ideology. They care about power.", "a4_choice"),
	]

	var choice := DialogueLine.new()
	choice.id = "a4_choice"
	choice.text = "Joseph initially wants to destroy them."
	choice.choices = [
		{"text": "Try to dismantle the network", "next": "a4_resist", "set_flag": "tried_to_dismantle_network", "corruption_delta": -10},
		{"text": "Start using them instead", "next": "a4_use", "set_flag": "used_shadow_network", "corruption_delta": 20},
	]
	tree.lines.append(choice)

	tree.lines.append(_line("a4_resist", "", "He tries. But the network is entrenched everywhere -- ministries, courts, media. Cutting them out now would collapse his own government along with them. He backs off, telling himself he'll deal with it later.", "a4_close"))
	tree.lines.append(_line("a4_use", "", "Instead, he starts using them. They help him control political opposition. They provide information. They influence elections. They make problems disappear. He tells himself: \"I'm using them. They aren't using me.\"", "a4_close"))
	tree.lines.append(_line("a4_close", "", "But eventually the relationship changes. Joseph is no longer controlling the network. The network is controlling him.", "END", "act4_complete"))
	return tree


## Act V is pure consequence of Act IV -- the source offers no choice here,
## just the payoff of the corrupted path, so this stays linear narration.
static func act5_mafia() -> DialogueTree:
	var tree := DialogueTree.new()
	tree.start_id = "a5_1"
	tree.lines = [
		_line("a5_1", "", "Years earlier, Joseph hated the mafia because they represented everything wrong with society. Now he secretly meets the same kind of people.", "a5_2"),
		_line("a5_2", "", "They call him \"The Boss.\" Joseph never thought he'd hear that name.", "a5_3"),
		_line("a5_3", "", "His government becomes increasingly authoritarian. Political opponents mysteriously lose influence. Business contracts go to Joseph's allies.", "a5_4"),
		_line("a5_4", "", "OOO Corporation, the company that fired him years earlier, becomes one of his government's biggest contractors again.", "a5_5"),
		_line("a5_5", "", "Joseph sees the company's CEO at a private meeting. The CEO recognizes him.", "a5_6"),
		_line("a5_6", "CEO", "Funny how things change.", "a5_7"),
		_line("a5_7", "", "Joseph doesn't respond. He simply signs the contract.", "END", "act5_complete"),
	]
	return tree


## Act VI is the story's emotional pivot -- fixed dialogue, no choice, same
## as the design plan called for from the start.
static func act6_mirror() -> DialogueTree:
	var tree := DialogueTree.new()
	tree.start_id = "a6_1"
	tree.lines = [
		_line("a6_1", "", "Joseph's closest friend confronts him. He reminds Joseph of the man who walked out of OOO -- the man who hated corrupt politicians, who promised never to become like them.", "a6_2"),
		_line("a6_2", "Joseph", "You think I wanted this?", "a6_3"),
		_line("a6_3", "Friend", "No. You just kept choosing it.", "a6_4"),
		_line("a6_4", "", "That sentence destroys Joseph. For the first time, he realizes something: nobody forced him to become this person. There wasn't one moment when he suddenly became evil. It happened through hundreds of small decisions.", "END", "act6_complete"),
	]
	return tree


## Act VII is systemic collapse, not a player decision -- the source is
## explicit that Joseph's old methods "no longer work" regardless of what
## he tries, so no choice is offered here either.
static func act7_collapse() -> DialogueTree:
	var tree := DialogueTree.new()
	tree.start_id = "a7_1"
	tree.lines = [
		_line("a7_1", "", "The political system Joseph created begins collapsing. Evidence of corruption reaches the public. Former allies turn against him. The mafia network wants more control. Opposition parties demand his resignation.", "a7_2"),
		_line("a7_2", "", "Joseph tries to use the same methods that helped him rise. But they no longer work. The people who once protected him begin protecting themselves.", "a7_3"),
		_line("a7_3", "", "His political allies disappear. His businessmen abandon him. His old enemies return.", "a7_4"),
		_line("a7_4", "", "And OOO Corporation becomes involved in the final political scandal. The company that started Joseph's journey becomes part of the event that ends it.", "END", "act7_complete"),
	]
	return tree


## The one place StoryManager.corruption_tier() actually changes the text
## shown, rather than just being tracked for later -- see the tier's doc
## comment on StoryManager for why the bands are drawn where they are. The
## closing quote is fixed across all three: it's the story's thesis, not
## a per-path detail.
static func final_act() -> DialogueTree:
	var tree := DialogueTree.new()
	tree.start_id = "f1"

	var reflection: String
	match StoryManager.corruption_tier():
		StoryManager.CorruptionTier.REFORMER:
			reflection = "Joseph resisted more than he gave in -- he can point to real fights he won without giving ground. But some compromises still shaped him, smaller ones than most, but not none."
		StoryManager.CorruptionTier.TYRANT:
			reflection = "Joseph gave in every time it was offered. There is no version of this story where he gets to call himself the exception."
		_:
			reflection = "Joseph can't point to one single moment where he became this. It happened through a hundred small decisions, each one justified at the time."

	tree.lines = [
		_line("f1", "", "Joseph sits alone inside the presidential office. The building outside is surrounded by protesters.", "f2"),
		_line("f2", "", "On his desk is an old photograph. It shows Joseph on his first day as a politician. Young. Hopeful. Angry at corruption.", "f3"),
		_line("f3", "", reflection, "f4"),
		_line("f4", "", "Joseph looks at the photograph. Then he looks at himself in the window. He finally understands: he didn't defeat the system. He became the system.", "f5"),
		_line("f5", "", "\"The man Joseph hated was never his enemy. He was his destination.\"", "END", "story_complete"),
	]
	return tree


## `flag` (optional) is set true the moment this line displays -- used once,
## on the closing beat, so StoryManager records that the Prologue's real
## turning point (the friend's question) actually happened.
static func _line(id: String, speaker: String, text: String, next_id: String, flag: String = "") -> DialogueLine:
	var line := DialogueLine.new()
	line.id = id
	line.speaker = speaker
	line.text = text
	line.next_id = next_id
	line.set_flag = flag
	return line
