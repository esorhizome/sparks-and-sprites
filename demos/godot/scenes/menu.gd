extends Node2D
## The demo menu. Click a demo to open it, or press its key; Esc returns here.
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
	["0", "Trails — a trail is short-term memory, drawn", "res://scenes/trails.tscn"],
	["Q", "Fragmented trails — a comet of pieces", "res://scenes/trails_fragments.tscn"],
	["W", "Waterdrops — fall, splash, ripple", "res://scenes/waterdrops.tscn"],
	["E", "Halo — an additive ring with a ±3% breath", "res://scenes/halo.tscn"],
	["R", "Chrome & liquid metal — a mirror with opinions", "res://scenes/metal_chrome.tscn"],
	["T", "Living buttons — plasma underlay + tap impulse", "res://scenes/glow_buttons.tscn"],
	["Y", "Responsive cursor — chase, shed, pop", "res://scenes/cursor_sparkle.tscn"],
	["U", "Starfield & ambience — sparks at 1/10 speed", "res://scenes/starfield.tscn"],
	["I", "Screen shake — trauma², smooth noise, fast calm", "res://scenes/shake.tscn"],
	["O", "Planet (3D) — a noise-displaced world", "res://scenes/planet_3d.tscn"],
	["P", "Orbit & glow (3D) — drag-to-orbit + bloom", "res://scenes/orbit_glow_3d.tscn"],
	["A", "Elemental buttons — all 104, paged by family", "res://scenes/elemental_buttons.tscn"],
	["S", "Cube codex — one hero, 104 character effects", "res://scenes/cube_vfx.tscn"],
]

func _ready() -> void:
	var title := Label.new()
	title.text = "SPARKS & SPRITES — Godot demos\nClick a demo (or press its key).  Esc returns here.  Each scene builds itself in _ready() — open the script and read it."
	title.position = Vector2(40, 24)
	add_child(title)
	# two columns of real, clickable buttons
	var half := int(ceil(DEMOS.size() / 2.0))
	for i in DEMOS.size():
		var d: Array = DEMOS[i]
		var btn := Button.new()
		btn.text = "[%s]  %s" % [d[0], d[1]]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.position = Vector2(40 + floorf(i / float(half)) * 450.0, 90 + (i % half) * 38.0)
		btn.size = Vector2(430, 32)
		btn.pressed.connect(func(): get_tree().change_scene_to_file(d[2]))
		add_child(btn)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		for d in DEMOS:
			if event.keycode == OS.find_keycode_from_string(d[0]):
				get_tree().change_scene_to_file(d[2])
