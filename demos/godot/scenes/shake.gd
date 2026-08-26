extends Node2D
## SCREEN SHAKE — the kind version: trauma², smooth noise, fast calm.
## Three rules: (1) accumulate "trauma", shake by trauma SQUARED so small
## hits whisper and big hits roar; (2) sample smooth noise, never random
## jumps; (3) decay fast — calm is what makes the shake readable.
## Click = small hit, right-click = big hit. Esc = menu. Chapter 06.

const MAX_OFFSET := 18.0
const MAX_ROLL := 0.05

var trauma := 0.0
var t := 0.0
var noise_x := FastNoiseLite.new()
var noise_y := FastNoiseLite.new()
var world: Node2D
var camera: Camera2D

func _ready() -> void:
	noise_x.seed = 1
	noise_y.seed = 2
	noise_x.frequency = 2.0
	noise_y.frequency = 2.0
	var size := get_viewport_rect().size

	world = Node2D.new()                  # something worth shaking
	add_child(world)
	for i in 40:
		var block := ColorRect.new()
		block.color = Color(0.35, 0.32, 0.5).lerp(Color(0.61, 0.64, 0.94), randf())
		block.size = Vector2(randf_range(14, 60), randf_range(14, 60))
		block.position = Vector2(randf_range(0, size.x), randf_range(0, size.y))
		world.add_child(block)

	camera = Camera2D.new()               # the shake lives on the CAMERA, not the world
	camera.position = size / 2.0
	camera.ignore_rotation = false        # let the roll through (off by default)
	add_child(camera)
	camera.make_current()

	var l := Label.new()
	l.text = "Screen shake: click = small hit, right-click = big hit.  Esc = menu.\ntrauma² + smooth noise + fast decay — read shake.gd."
	l.position = Vector2(24, 16)
	add_child(l)

func _process(delta: float) -> void:
	t += delta
	trauma = maxf(0.0, trauma - delta * 1.1)          # rule 3: calm returns fast
	var shake := trauma * trauma                       # rule 1: square it
	camera.offset = Vector2(                           # rule 2: smooth noise, not randf
		noise_x.get_noise_1d(t * 300.0) * MAX_OFFSET * shake,
		noise_y.get_noise_1d(t * 300.0) * MAX_OFFSET * shake
	)
	camera.rotation = noise_x.get_noise_1d(t * 200.0 + 99.0) * MAX_ROLL * shake

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			trauma = minf(1.0, trauma + 0.7)
		else:
			trauma = minf(1.0, trauma + 0.3)
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().change_scene_to_file("res://scenes/menu.tscn")
