extends CanvasLayer
class_name EndingScreen
## Full-screen end-of-story overlay shown once the Final Act's dialogue
## finishes (see WorldGenerator._show_ending_screen). Plain fade + labels +
## a restart button -- same code-built-UI convention as DialogueBox/HUD, no
## art needed. Elements fade in via `modulate` (not theme color overrides)
## since modulate is a plain CanvasItem property Tween can animate directly,
## without depending on how Label exposes its font-color override.

const TIER_TITLES := {
	StoryManager.CorruptionTier.REFORMER: "The Reformer",
	StoryManager.CorruptionTier.COMPROMISED: "The Compromised",
	StoryManager.CorruptionTier.TYRANT: "The Tyrant",
}


func setup(tier: int) -> void:
	layer = 100

	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)
	create_tween().tween_property(bg, "color:a", 0.92, 1.5)

	var title := Label.new()
	title.text = "THE END"
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.position = Vector2(-100, 140)
	title.size = Vector2(200, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(1, 1, 1))
	title.modulate.a = 0.0
	add_child(title)

	var subtitle := Label.new()
	subtitle.text = TIER_TITLES.get(tier, "")
	subtitle.set_anchors_preset(Control.PRESET_CENTER_TOP)
	subtitle.position = Vector2(-100, 190)
	subtitle.size = Vector2(200, 30)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color(0.85, 0.75, 0.4))
	subtitle.modulate.a = 0.0
	add_child(subtitle)

	var btn := Button.new()
	btn.text = "Play Again"
	btn.set_anchors_preset(Control.PRESET_CENTER)
	btn.position = Vector2(-60, 40)
	btn.size = Vector2(120, 36)
	btn.modulate.a = 0.0
	btn.pressed.connect(_on_play_again)
	add_child(btn)

	var reveal := create_tween()
	reveal.set_parallel(true)
	reveal.tween_property(title, "modulate:a", 1.0, 1.2).set_delay(1.0)
	reveal.tween_property(subtitle, "modulate:a", 1.0, 1.2).set_delay(1.4)
	reveal.tween_property(btn, "modulate:a", 1.0, 1.0).set_delay(2.2)


func _on_play_again() -> void:
	SaveManager.delete_save()
	StoryManager.reset()
	get_tree().reload_current_scene()
