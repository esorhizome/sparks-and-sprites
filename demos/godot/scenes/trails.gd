extends Node2D
## TRAILS — the "don't clear the canvas" trick, Godot-style.
## On the web the trick is literally not clearing the canvas; Godot always
## clears, so the honest port is: REMEMBER the last N positions and redraw
## them each frame with fading alpha. Same idea, made explicit — a trail is
## just short-term memory, drawn. Move the mouse. Esc = menu. Chapter 06.

const MAX_POINTS := 40          # trail length (memory span)
const DOT_RADIUS := 7.0

var history: Array[Vector2] = []

func _ready() -> void:
	var l := Label.new()
	l.text = "Trails: move the mouse.  Esc = menu.\nA trail is remembered positions redrawn with fading alpha — read trails.gd."
	l.position = Vector2(24, 16)
	add_child(l)

func _process(_delta: float) -> void:
	history.push_front(get_global_mouse_position())
	if history.size() > MAX_POINTS:
		history.pop_back()
	queue_redraw()                # ask for _draw() this frame

func _draw() -> void:
	# oldest first, so the bright head draws on top of the faint tail
	for i in range(history.size() - 1, -1, -1):
		var k := 1.0 - float(i) / MAX_POINTS      # 1 at the head, 0 at the tail
		var col := Color(0.61, 0.64, 0.94, k * 0.9)
		draw_circle(history[i], DOT_RADIUS * (0.3 + 0.7 * k), col)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().change_scene_to_file("res://scenes/menu.tscn")
