extends RefCounted
## Shared kit for the depth atlas (scenes/depth/*.gd) — each family file
## preloads this as K. It is the web page's kit `u` spelled in CanvasItem
## calls, and it exists to answer one question honestly: Godot's _draw()
## has NO gradient-fill call — so how do you draw a gradient?
##
##   • A LINEAR gradient is a polygon with one colour PER VERTEX. The GPU
##     interpolates between them for free — draw_polygon(points, colors)
##     with two colours on the top edge and two on the bottom edge IS a
##     vertical gradient. Multi-stop gradients are stacked polygons.
##   • A RADIAL gradient is a fan of triangles: a centre vertex in the
##     centre colour, a ring of vertices in the rim colour. Several rings
##     give several stops. Push the centre vertex toward the light and the
##     disc becomes a lit ball — the same offset trick as the web page.
##     One RenderingServer.canvas_item_add_triangle_array call draws the
##     whole fan, so a sphere costs one draw command, not thirty.
##
## For nodes rather than _draw(), GradientTexture2D (fill = linear or
## radial, fill_from / fill_to) on a Sprite2D or TextureRect is the
## zero-code spelling of the same two ideas.
##
## Every painter draws into a card-local space: (0,0) is the card's top
## left, b.W × b.H is its size. Card state lives in the dictionary b:
##   b.W, b.H  — the stage size          b.D — the active dials (original
##   b.t       — seconds since wake        or rhyme — the rhyme IS a dials
##   b.rng     — a seeded RandomNumberGenerator   swap, nothing else)
##   anything else a painter stores in init()

const INK := Color("E8E5F4")
const NIGHT := Color("131020")
const SUN := Color("F5C169")
const FIRE := Color("F5A15A")
const SPARK := Color("8AD9F5")
const MAGIC := Color("C9A0F5")
const GOOD := Color("9BE28A")
const HOT := Color("F58A8A")
const AIR := Color("9FB3D9")

const SEGS := 28                 # ring resolution for radial fans

## ---------------------------------------------------------------- colour
static func alpha(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, a)

static func mix(a: Color, b: Color, k: float) -> Color:
	return a.lerp(b, clampf(k, 0.0, 1.0))

## k > 0 lightens toward white, k < 0 darkens toward black (alpha kept).
static func shade(c: Color, k: float) -> Color:
	if k >= 0.0:
		return Color(c.r + (1.0 - c.r) * k, c.g + (1.0 - c.g) * k, c.b + (1.0 - c.b) * k, c.a)
	return Color(c.r * (1.0 + k), c.g * (1.0 + k), c.b * (1.0 + k), c.a)

## Atmospheric perspective: the colour you'd see THROUGH `depth` of air.
static func fog(c: Color, depth: float, air: Color = AIR) -> Color:
	return mix(c, air, depth)

## The web's hsl(h, s, l): Godot speaks HSV, so convert.
static func hsl(h: float, s: float, l: float, a := 1.0) -> Color:
	var v := l + s * minf(l, 1.0 - l)
	var sv := 0.0 if v == 0.0 else 2.0 * (1.0 - l / v)
	return Color.from_hsv(fposmod(h, 360.0) / 360.0, sv, v, a)

## ---------------------------------------------------------------- gradients
## Vertical gradient over a rect. stops: Array of [k, Color] pairs (k 0..1)
## or a plain Array of Colors (evenly spaced).
static func lin_rect(n: CanvasItem, r: Rect2, stops: Array) -> void:
	var st := _stops(stops)
	for i in st.size() - 1:
		var y0: float = r.position.y + r.size.y * st[i][0]
		var y1: float = r.position.y + r.size.y * st[i + 1][0]
		if y1 - y0 < 0.01: continue
		var c0: Color = st[i][1]
		var c1: Color = st[i + 1][1]
		n.draw_polygon(PackedVector2Array([Vector2(r.position.x, y0), Vector2(r.end.x, y0),
			Vector2(r.end.x, y1), Vector2(r.position.x, y1)]), PackedColorArray([c0, c0, c1, c1]))

## Horizontal gradient over a rect (left → right).
static func hlin_rect(n: CanvasItem, r: Rect2, stops: Array) -> void:
	var st := _stops(stops)
	for i in st.size() - 1:
		var x0: float = r.position.x + r.size.x * st[i][0]
		var x1: float = r.position.x + r.size.x * st[i + 1][0]
		if x1 - x0 < 0.01: continue
		var c0: Color = st[i][1]
		var c1: Color = st[i + 1][1]
		n.draw_polygon(PackedVector2Array([Vector2(x0, r.position.y), Vector2(x1, r.position.y),
			Vector2(x1, r.end.y), Vector2(x0, r.end.y)]), PackedColorArray([c0, c1, c1, c0]))

## A polygon with a per-vertex colour — the general spelling of "gradient".
static func lin_poly(n: CanvasItem, pts: PackedVector2Array, cols: PackedColorArray) -> void:
	if pts.size() >= 3:
		n.draw_polygon(pts, cols)

## Fill the whole card top → bottom.
static func sky(n: CanvasItem, b: Dictionary, stops: Array) -> void:
	lin_rect(n, Rect2(0, 0, b.W, b.H), stops)

## Radial gradient as ONE triangle array. stops as in lin_rect. `off` moves
## the inner point (the highlight) — that offset is what makes a ball round.
static func radial(n: CanvasItem, c: Vector2, r: float, stops: Array, off := Vector2.ZERO) -> void:
	r = maxf(r, 0.5)
	var st := _stops(stops)
	var rings := st.size()
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	# vertex 0: the centre, at the inner point
	pts.append(c + off)
	cols.append(st[0][1])
	for ri in range(1, rings):
		var k: float = st[ri][0]
		var centre := c + off * (1.0 - k)               # inner circles slide toward the offset
		var rad := r * maxf(k, 0.002)
		for s in SEGS:
			var ang := TAU * float(s) / SEGS
			pts.append(centre + Vector2(cos(ang), sin(ang)) * rad)
			cols.append(st[ri][1])
	# the innermost ring fans from the centre vertex
	for s in SEGS:
		idx.append(0); idx.append(1 + s); idx.append(1 + (s + 1) % SEGS)
	# each further ring is a strip of quads to the previous ring
	for ri in range(1, rings - 1):
		var a := 1 + (ri - 1) * SEGS
		var bb := 1 + ri * SEGS
		for s in SEGS:
			var s1 := (s + 1) % SEGS
			idx.append(a + s); idx.append(bb + s); idx.append(bb + s1)
			idx.append(a + s); idx.append(bb + s1); idx.append(a + s1)
	RenderingServer.canvas_item_add_triangle_array(n.get_canvas_item(), idx, pts, cols)

## A glow: c at alpha a in the centre, nothing at the rim.
static func soft(n: CanvasItem, c: Vector2, r: float, col: Color, a := 0.9) -> void:
	radial(n, c, r, [[0.0, alpha(col, a)], [1.0, alpha(col, 0.0)]])

## ---------------------------------------------------------------- forms
## A shaded ball. lx, ly in −1..1 say where the light is.
static func sphere(n: CanvasItem, c: Vector2, r: float, col: Color, lx := -0.5, ly := -0.5,
		spec := 0.35, dark: Variant = null, rim: Variant = null) -> void:
	var dk: Color = dark if dark != null else shade(col, -0.75)
	radial(n, c, r * 1.02, [[0.0, shade(col, spec)], [0.35, col], [0.8, shade(col, -0.35)], [1.0, dk]],
		Vector2(lx, ly) * r * 0.55)
	if rim != null:                                     # light leaking round the back edge
		radial(n, c, r, [[0.0, alpha(rim, 0.0)], [0.72, alpha(rim, 0.0)], [1.0, alpha(rim, 0.85)]],
			Vector2(-lx, -ly) * r * 0.35)

## A vertical cylinder standing on (x, y): dark → light → dark across.
static func cyl(n: CanvasItem, x: float, y: float, w: float, h: float, col: Color, lx := -0.3) -> void:
	var hi := clampf(0.5 + lx * 0.4, 0.05, 0.95)
	hlin_rect(n, Rect2(x - w / 2.0, y - h, w, h), [[0.0, shade(col, -0.55)], [hi, shade(col, 0.3)], [1.0, shade(col, -0.7)]])

## 2:1 isometric projection of grid coordinates (ix right-down, iy left-down, iz up).
static func iso(ix: float, iy: float, iz: float, s := 1.0) -> Vector2:
	return Vector2((ix - iy) * 0.866 * s, (ix + iy) * 0.5 * s - iz * s)

## An isometric cube standing on its base point. Three flat shades.
static func cube(n: CanvasItem, base: Vector2, s: float, col: Color, h := -1.0,
		top: Variant = null, left: Variant = null, right: Variant = null) -> void:
	if h < 0.0: h = s
	var ct: Color = top if top != null else shade(col, 0.32)
	var cl: Color = left if left != null else col
	var cr: Color = right if right != null else shade(col, -0.42)
	var dx := 0.866 * s
	var dy := 0.5 * s
	var x := base.x
	var y := base.y
	n.draw_colored_polygon(PackedVector2Array([Vector2(x, y), Vector2(x - dx, y - dy), Vector2(x - dx, y - dy - h), Vector2(x, y - h)]), cl)
	n.draw_colored_polygon(PackedVector2Array([Vector2(x, y), Vector2(x + dx, y - dy), Vector2(x + dx, y - dy - h), Vector2(x, y - h)]), cr)
	n.draw_colored_polygon(PackedVector2Array([Vector2(x, y - h), Vector2(x - dx, y - dy - h), Vector2(x, y - 2 * dy - h), Vector2(x + dx, y - dy - h)]), ct)

## A soft ground ellipse.
static func shadow(n: CanvasItem, c: Vector2, rx: float, ry: float, a := 0.45) -> void:
	rx = maxf(rx, 0.5)
	n.draw_set_transform(c, 0.0, Vector2(1.0, maxf(0.01, ry / rx)))
	radial(n, Vector2.ZERO, rx, [[0.0, Color(0, 0, 0, a)], [0.6, Color(0, 0, 0, a * 0.6)], [1.0, Color(0, 0, 0, 0)]])
	n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

static func poly(n: CanvasItem, pts: PackedVector2Array, col: Color) -> void:
	if pts.size() >= 3:
		n.draw_colored_polygon(pts, col)

static func dot(n: CanvasItem, p: Vector2, r: float, col: Color) -> void:
	n.draw_circle(p, maxf(r, 0.1), col)

static func line(n: CanvasItem, a: Vector2, b: Vector2, col: Color, w := 1.0) -> void:
	n.draw_line(a, b, col, w, true)

static func ellipse(n: CanvasItem, c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for s in 32:
		var ang := TAU * float(s) / 32.0
		pts.append(c + Vector2(cos(ang) * rx, sin(ang) * ry))
	n.draw_colored_polygon(pts, col)

## A flat floor from y down.
static func ground(n: CanvasItem, b: Dictionary, y: float, col := Color("0E0B1A")) -> void:
	n.draw_rect(Rect2(0, y, b.W, b.H - y), col)

## The one-breath lesson, bottom-centre, wrapped to two lines if it must be.
static func label(n: CanvasItem, b: Dictionary, txt: String, col := Color(0.91, 0.9, 0.96, 0.8)) -> void:
	var f := ThemeDB.fallback_font
	var w: float = b.W - 8.0
	var lines := 2 if f.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, 9).x > w else 1
	var y: float = b.H - 6.0 - (lines - 1) * 10.0
	n.draw_multiline_string(f, Vector2(4.7, y + 0.7), txt, HORIZONTAL_ALIGNMENT_CENTER, w, 9, 2, Color(0.04, 0.03, 0.08, 0.6))
	n.draw_multiline_string(f, Vector2(4.0, y), txt, HORIZONTAL_ALIGNMENT_CENTER, w, 9, 2, col)

## ---------------------------------------------------------------- misc
static func rng(seed_v: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_v
	return r

static func ease(k: float) -> float:
	k = clampf(k, 0.0, 1.0)
	return k * k * (3.0 - 2.0 * k)

## Normalise stops to [[k, Color], …].
static func _stops(stops: Array) -> Array:
	var out := []
	var n := stops.size()
	for i in n:
		var s = stops[i]
		if s is Array:
			out.append([clampf(float(s[0]), 0.0, 1.0), s[1] as Color])
		else:
			out.append([0.0 if n == 1 else float(i) / (n - 1), s as Color])
	if out.size() == 1:
		out.append([1.0, out[0][1]])
	return out
