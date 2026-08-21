extends Node2D
## DISSOLVE — the noise-threshold shader, driven from code.
## The sprite endlessly burns away and re-forms as the threshold slides 0→1→0.
## The shader (shaders/dissolve.gdshader) is three lines of real logic.
## Esc = menu. Chapter 03 in the book.

var mat: ShaderMaterial
var t := 0.0

func _ready() -> void:
	var size := get_viewport_rect().size

	# the "sprite": a filled circle texture, generated in code
	var s := 256
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	for y in s:
		for x in s:
			if Vector2(x - s / 2.0, y - s / 2.0).length() < s * 0.38:
				img.set_pixel(x, y, Color("5A63C8"))
	var sprite := Sprite2D.new()
	sprite.texture = ImageTexture.create_from_image(img)
	sprite.position = size / 2.0
	sprite.scale = Vector2.ONE * 1.4

	# the noise the shader compares against (Godot ships noise built in)
	var noise_tex := NoiseTexture2D.new()
	noise_tex.noise = FastNoiseLite.new()
	(noise_tex.noise as FastNoiseLite).frequency = 0.04   # lower = chunkier islands

	mat = ShaderMaterial.new()
	mat.shader = load("res://shaders/dissolve.gdshader")
	mat.set_shader_parameter("noise_tex", noise_tex)
	sprite.material = mat
	add_child(sprite)

	var l := Label.new()
	l.text = "Dissolve: noise vs a sliding threshold.  Esc = menu.\nTry: frequency 0.04 → 0.2 in dissolve.gd for a fizzy TV-static dissolve."
	l.position = Vector2(24, 16)
	add_child(l)

func _process(delta: float) -> void:
	t += delta
	# slide the threshold 0→1→0 forever; the shader does the rest per pixel
	mat.set_shader_parameter("threshold", (sin(t * 0.6) + 1.0) / 2.0)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().change_scene_to_file("res://scenes/menu.tscn")
