extends SceneTree
## Headless test for the full elemental bestiary (not a demo).
## Every one of the 104 buttons, in BOTH voices — original and rhyme:
## init → 60 ticks → two presses → 60 ticks, then one draw pass per family
## page inside a real scene, with a right-click (rhyme toggle) per page.
## Run: godot --headless --path . -s res://bestiary_test.gd

const FAMILIES := [
	preload("res://scenes/elements/fire.gd"),
	preload("res://scenes/elements/lightning.gd"),
	preload("res://scenes/elements/water.gd"),
	preload("res://scenes/elements/metal.gd"),
	preload("res://scenes/elements/ice.gd"),
	preload("res://scenes/elements/earth.gd"),
	preload("res://scenes/elements/air.gd"),
	preload("res://scenes/elements/light.gd"),
	preload("res://scenes/elements/sparkfx.gd"),
	preload("res://scenes/elements/cosmic.gd"),
	preload("res://scenes/elements/nature.gd"),
	preload("res://scenes/elements/acid.gd"),
	preload("res://scenes/elements/crystal.gd"),
	preload("res://scenes/elements/weather.gd"),
]
const RHYME_FAMILIES := [
	preload("res://scenes/elements/fire_r.gd"),
	preload("res://scenes/elements/lightning_r.gd"),
	preload("res://scenes/elements/water_r.gd"),
	preload("res://scenes/elements/metal_r.gd"),
	preload("res://scenes/elements/ice_r.gd"),
	preload("res://scenes/elements/earth_r.gd"),
	preload("res://scenes/elements/air_r.gd"),
	preload("res://scenes/elements/light_r.gd"),
	preload("res://scenes/elements/sparkfx_r.gd"),
	preload("res://scenes/elements/cosmic_r.gd"),
	preload("res://scenes/elements/nature_r.gd"),
	preload("res://scenes/elements/acid_r.gd"),
	preload("res://scenes/elements/crystal_r.gd"),
	preload("res://scenes/elements/weather_r.gd"),
]

var page := 0
var frame := 0
var scene: Node2D
var total := 0
var rhymed := 0

func _run_one(script: GDScript, def: Dictionary) -> void:
	var b := { "id": def.id, "name": def.name, "hint": def.hint,
		"rect": Rect2(Vector2(33, 106), Vector2(150, 62)) }
	script.init(b)
	var t := 0.0
	for i in 60:
		t += 1.0 / 60.0
		script.tick(b, 1.0 / 60.0, t)
	script.press(b, Vector2(75, 31))
	script.press(b, Vector2(5, 5))
	for i in 60:
		t += 1.0 / 60.0
		script.tick(b, 1.0 / 60.0, t)

func _initialize() -> void:
	# state/tick/press coverage, off-screen: every button, both voices
	for fi in FAMILIES.size():
		var fam: GDScript = FAMILIES[fi]
		var rfam: GDScript = RHYME_FAMILIES[fi]
		for def in fam.DEFS:
			_run_one(fam, def)
			total += 1
			assert(rfam.RHYMES.has(def.id), "missing rhyme for %s" % def.id)
			_run_one(rfam, def)
			rhymed += 1
	print("bestiary logic pass: %d buttons + %d rhymes ticked and pressed" % [total, rhymed])
	# draw coverage: run the real scene, right-click a card, turn every page
	change_scene_to_file("res://scenes/elemental_buttons.tscn")
	process_frame.connect(_tick)

func _tick() -> void:
	frame += 1
	if frame % 8 == 3:
		# right-click the first card: toggles it to its rhyme for the draw pass
		var m := InputEventMouseButton.new()
		m.button_index = MOUSE_BUTTON_RIGHT
		m.pressed = true
		m.position = Vector2(108, 137)
		Input.parse_input_event(m)
	if frame % 8 == 0:
		var k := InputEventKey.new()
		k.keycode = KEY_RIGHT
		k.pressed = true
		Input.parse_input_event(k)
		page += 1
		if page > FAMILIES.size() + 1:
			print("BESTIARY TEST COMPLETE — %d buttons + %d rhymes, all %d pages drawn" % [total, rhymed, FAMILIES.size()])
			quit()
