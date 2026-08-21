extends Node2D
## PARALLAX — depth from three multiplications.
## Far things move slower than near things: layer.x = -camera.x * factor.
## Move the mouse left/right — you are the camera. Esc returns to the menu.
## (In a scrolling game you'd use Godot's Parallax2D node with scroll_scale
## set to these same factors; this demo shows the arithmetic underneath it.)
## Chapter 04 in the book.

var layers: Array[Node2D] = []
const FACTORS := [0.2, 0.5, 0.9]   # far, mid, near — the entire depth illusion
var camera_x := 0.0

func _ready() -> void:
	var size := get_viewport_rect().size
	var colours := [Color("8A8FD0"), Color("5A63C8"), Color("3A3F8F")]
	var bases := [0.45, 0.60, 0.78]
	var jags := [1.0, 1.6, 2.4]
	for i in 3:
		layers.append(_make_ridge(colours[i], bases[i] * size.y, jags[i], size))
	var l := Label.new()
	l.text = "Parallax: move the mouse — you are the camera.  Esc = menu.\nTry: set all FACTORS to 0.5 and watch depth vanish."
	l.position = Vector2(24, 16)
	add_child(l)

## Build one silhouette ridge as a Polygon2D, wider than the screen
## so it can slide without showing its edges.
func _make_ridge(colour: Color, base_y: float, jag: float, size: Vector2) -> Node2D:
	var holder := Node2D.new()
	var poly := Polygon2D.new()
	var pts := PackedVector2Array()
	var extra := 400.0
	pts.append(Vector2(-extra, size.y + 50))
	var x := -extra
	var i := 0
	while x <= size.x + extra:
		var y := base_y + sin(i * 0.7 + jag) * jag * 14.0 \
					   + sin(i * 1.9 + jag * 3.0) * jag * 7.0
		pts.append(Vector2(x, y))
		x += 48.0
		i += 1
	pts.append(Vector2(size.x + extra, size.y + 50))
	poly.polygon = pts
	poly.color = colour
	holder.add_child(poly)
	add_child(holder)
	return holder

func _process(_delta: float) -> void:
	for i in layers.size():
		# ---- THE parallax line ----
		layers[i].position.x = -camera_x * FACTORS[i]

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var size := get_viewport_rect().size
		camera_x = (event.position.x - size.x / 2.0) * 2.0
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().change_scene_to_file("res://scenes/menu.tscn")
