extends Node2D
## The demo menu. Press a number key to open a demo; Esc returns here.
## Like every scene in this project, the UI is built from code in _ready()
## so there is nothing hidden in the editor — the script is the whole story.

const DEMOS := [
	["1", "Sprite basics — load, attach, place", "res://scenes/sprite_basics.tscn"],
	["2", "Movement personalities — one dot, eight souls", "res://scenes/personalities.tscn"],
	["3", "Sparks — click to burst", "res://scenes/sparks.tscn"],
	["4", "Flame — a particle system configured in code", "res://scenes/flame.tscn"],
	["5", "Parallax — move the mouse, you are the camera", "res://scenes/parallax.tscn"],
	["6", "Infinite scroll — the one-line UV shader", "res://scenes/scroll_uv.tscn"],
	["7", "Additive glow — light that adds up", "res://scenes/glow.tscn"],
	["8", "Dissolve — the noise-threshold shader", "res://scenes/dissolve.tscn"],
	["9", "Sound blips — synthesized from nothing", "res://scenes/sound_blips.tscn"],
]

func _ready() -> void:
	var label := Label.new()
	label.text = "SPARKS & SPRITES — Godot demos\n\n"
	for d in DEMOS:
		label.text += "  [%s]  %s\n" % [d[0], d[1]]
	label.text += "\n  Esc returns to this menu from any demo."
	label.text += "\n  Each demo builds its whole scene in _ready() — open the script and read it."
	label.position = Vector2(60, 60)
	add_child(label)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		for d in DEMOS:
			if event.keycode == KEY_0 + int(d[0]):
				get_tree().change_scene_to_file(d[2])
