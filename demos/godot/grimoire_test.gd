extends SceneTree
## Headless test for the full glyph grimoire (not a demo).
## Every one of the 104 text effects, in BOTH voices — original and rhyme:
## setup → 60 ticks → two presses → 60 ticks, then one draw pass per family
## page inside the real scene, with a right-click (rhyme toggle) per page.
## Run: godot --headless --path . -s res://grimoire_test.gd

const FAMILIES := [
	preload("res://scenes/textfx/weight.gd"),
	preload("res://scenes/textfx/glow.gd"),
	preload("res://scenes/textfx/type.gd"),
	preload("res://scenes/textfx/fade.gd"),
	preload("res://scenes/textfx/scale.gd"),
	preload("res://scenes/textfx/scramble.gd"),
	preload("res://scenes/textfx/wave.gd"),
	preload("res://scenes/textfx/slide.gd"),
	preload("res://scenes/textfx/spin.gd"),
	preload("res://scenes/textfx/color.gd"),
	preload("res://scenes/textfx/shake.gd"),
	preload("res://scenes/textfx/stroke.gd"),
	preload("res://scenes/textfx/particle.gd"),
	preload("res://scenes/textfx/shadow.gd"),
]
const RHYME_FAMILIES := [
	preload("res://scenes/textfx/weight_r.gd"),
	preload("res://scenes/textfx/glow_r.gd"),
	preload("res://scenes/textfx/type_r.gd"),
	preload("res://scenes/textfx/fade_r.gd"),
	preload("res://scenes/textfx/scale_r.gd"),
	preload("res://scenes/textfx/scramble_r.gd"),
	preload("res://scenes/textfx/wave_r.gd"),
	preload("res://scenes/textfx/slide_r.gd"),
	preload("res://scenes/textfx/spin_r.gd"),
	preload("res://scenes/textfx/color_r.gd"),
	preload("res://scenes/textfx/shake_r.gd"),
	preload("res://scenes/textfx/stroke_r.gd"),
	preload("res://scenes/textfx/particle_r.gd"),
	preload("res://scenes/textfx/shadow_r.gd"),
]
const TextKit := preload("res://scenes/textfx/kit.gd")

var page := 0
var frame := 0
var total := 0
var rhymed := 0

func _run_one(script: GDScript, def: Dictionary) -> void:
	var b := { "id": def.id, "name": def.name, "hint": def.hint,
		"rect": Rect2(Vector2(20, 64), Vector2(220, 132)) }
	TextKit.setup(b)
	script.init(b)
	var t := 0.0
	for i in 60:
		t += 1.0 / 60.0
		script.tick(b, 1.0 / 60.0, t)
	script.press(b, Vector2(130, 130))          # centre-ish of the stage
	script.press(b, Vector2(34, 72))            # an aimed corner press
	for i in 60:
		t += 1.0 / 60.0
		script.tick(b, 1.0 / 60.0, t)

func _initialize() -> void:
	for fi in FAMILIES.size():
		var fam: GDScript = FAMILIES[fi]
		var rfam: GDScript = RHYME_FAMILIES[fi]
		for def in fam.DEFS:
			_run_one(fam, def)
			total += 1
			assert(rfam.RHYMES.has(def.id), "missing rhyme for %s" % def.id)
			_run_one(rfam, def)
			rhymed += 1
	print("grimoire logic pass: %d effects + %d rhymes ticked and pressed" % [total, rhymed])
	change_scene_to_file("res://scenes/text_fx.tscn")
	process_frame.connect(_tick)

func _tick() -> void:
	frame += 1
	if frame % 8 == 3:
		# right-click the first card: toggles it to its rhyme for the draw pass
		var m := InputEventMouseButton.new()
		m.button_index = MOUSE_BUTTON_RIGHT
		m.pressed = true
		m.position = Vector2(120, 120)
		Input.parse_input_event(m)
	if frame % 8 == 0:
		var k := InputEventKey.new()
		k.keycode = KEY_RIGHT
		k.pressed = true
		Input.parse_input_event(k)
		page += 1
		if page > FAMILIES.size() + 1:
			print("GRIMOIRE TEST COMPLETE — %d effects + %d rhymes, all %d pages drawn" % [total, rhymed, FAMILIES.size()])
			quit()
