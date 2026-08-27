extends SceneTree
## Temporary headless smoke test (not part of the book's demos).
## Cycles every scene, injecting clicks / right-clicks / key presses /
## mouse motion so the press-reaction code paths actually run.
## Run: godot --headless --path demos/godot -s res://smoke_test.gd

const SCENES := [
	"menu", "sprite_basics", "personalities", "sparks", "flame", "parallax",
	"scroll_uv", "glow", "dissolve", "sound_blips", "trails", "trails_fragments",
	"waterdrops", "halo", "metal_chrome", "glow_buttons", "cursor_sparkle",
	"starfield", "shake", "planet_3d", "orbit_glow_3d", "elemental_buttons",
	"cube_vfx", "text_fx",
]
const PAGED := ["elemental_buttons", "cube_vfx", "text_fx"]   # these page through 14 families

var i := 0
var frame := 0

func _initialize() -> void:
	change_scene_to_file("res://scenes/%s.tscn" % SCENES[0])
	process_frame.connect(_tick)

func _click(pos: Vector2, button: MouseButton) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	ev.pressed = true
	ev.position = pos
	Input.parse_input_event(ev)
	var up := ev.duplicate() as InputEventMouseButton
	up.pressed = false
	Input.parse_input_event(up)

func _tick() -> void:
	frame += 1
	if frame == 10:
		_click(Vector2(480, 300), MOUSE_BUTTON_LEFT)     # centre-ish press
	if frame == 15:
		_click(Vector2(200, 150), MOUSE_BUTTON_LEFT)     # a second spot
	if frame == 20:
		_click(Vector2(480, 300), MOUSE_BUTTON_RIGHT)    # shake's big hit
	if frame == 25:
		var k := InputEventKey.new()
		k.keycode = KEY_2                                # style/preset switches
		k.pressed = true
		Input.parse_input_event(k)
	if frame == 30:
		var mm := InputEventMouseMotion.new()            # orbit drag / trails
		mm.position = Vector2(420, 260)
		mm.relative = Vector2(30, 12)
		Input.parse_input_event(mm)
	# the paged galleries have 14 family pages: turn through every one, clicking twice
	if SCENES[i] in PAGED and frame > 40 and frame % 20 == 0 and frame < 340:
		var k := InputEventKey.new()
		k.keycode = KEY_RIGHT
		k.pressed = true
		Input.parse_input_event(k)
		_click(Vector2(110, 140), MOUSE_BUTTON_LEFT)     # first card of the page
		_click(Vector2(480, 300), MOUSE_BUTTON_LEFT)     # a second spot
	if frame >= (360 if SCENES[i] in PAGED else 45):
		i += 1
		if i >= SCENES.size():
			print("SMOKE TEST COMPLETE — all %d scenes survived input" % SCENES.size())
			quit()
			return
		frame = 0
		change_scene_to_file("res://scenes/%s.tscn" % SCENES[i])
