extends RefCounted
## Shared kit for the world workshop (scenes/world/*.gd) — the locomotion
## lexicon's kit (the night stage with graph paper, the ground, the mote,
## honest arrows, rng and 1-D noise) plus the WORLD tools: 2-D value noise,
## a small grid type with safe out-of-range reads, a grid painter, and a
## seeded shuffle. Every generator draws from rng(D.seed), so the same seed
## makes the same world on every machine — that is the last card's lesson.
##
## Coordinates are CARD-LOCAL: worlds.gd draws every card through its own
## clipping Painter node, so (0,0)..(w,h) is the whole stage, exactly like
## the web version (docs/worlds.js).
##
## Card state lives in the card dictionary b:
##   b.rect — the card's stage (Rect2 at ZERO)
##   b.w, b.h — the stage size · b.gy — the standard ground line (h · 0.78)
##   b.D  — the active dials (the def's "dials", with the rhyme's merged
##          over them when the card shows its rhyme — a rhyme IS a dials swap)
##   b.t  — seconds since this card (or its rhyme) woke

const INK := Color(0.91, 0.898, 0.957)
const DIM := Color(0.91, 0.898, 0.957, 0.25)
const MOVER := Color(0.541, 0.851, 0.961)   ## the mote — the protagonist blue
const TARGET := Color(0.961, 0.757, 0.412)  ## where it wants to be — amber
const BONE := Color(0.788, 0.769, 0.894)    ## structure
const GOOD := Color(0.608, 0.886, 0.541)    ## allowed, open, alive
const HOT := Color(0.961, 0.541, 0.541)     ## danger, rock, walls
const MAGIC := Color(0.788, 0.627, 0.961)   ## rare, strange
const WATER := Color(0.31, 0.64, 0.85)      ## water, cold
const NIGHT := Color(0.075, 0.063, 0.125)

static func setup(b: Dictionary) -> void:
	var r: Rect2 = b.rect
	b.w = r.size.x
	b.h = r.size.y
	b.gy = r.size.y * 0.78

static func stage(n: CanvasItem, b: Dictionary) -> void:
	n.draw_rect(Rect2(Vector2.ZERO, Vector2(b.w, b.h)), NIGHT)
	var grid := Color(0.59, 0.57, 0.75, 0.07)   # faint graph paper — this is a maths page
	var x := 26.0
	while x < b.w:
		n.draw_line(Vector2(x, 0), Vector2(x, b.h), grid, 1.0)
		x += 26.0
	var y := 26.0
	while y < b.h:
		n.draw_line(Vector2(0, y), Vector2(b.w, y), grid, 1.0)
		y += 26.0

static func ground(n: CanvasItem, b: Dictionary, gy: float = -1.0) -> void:
	var g: float = b.gy if gy < 0.0 else gy
	n.draw_line(Vector2(0, g), Vector2(b.w, g), Color(0.788, 0.769, 0.894, 0.5), 1.5)
	var x := 4.0
	while x < b.w:                              # the hatching that says "solid"
		n.draw_line(Vector2(x, g + 2), Vector2(x - 5, g + 8), Color(0.788, 0.769, 0.894, 0.16), 1.0)
		x += 12.0

static func dot(n: CanvasItem, p: Vector2, radius: float, col: Color = INK) -> void:
	n.draw_circle(p, radius, col)

static func ring(n: CanvasItem, p: Vector2, radius: float, col: Color = DIM, w: float = 1.0) -> void:
	n.draw_arc(p, maxf(0.5, radius), 0.0, TAU, 48, col, w)

static func line(n: CanvasItem, a: Vector2, c: Vector2, col: Color = INK, w: float = 1.0) -> void:
	n.draw_line(a, c, col, w)

static func rect(n: CanvasItem, r: Rect2, col: Color = INK) -> void:
	n.draw_rect(r, col)

## A polygon from a list of Vector2 (filled, or outlined when stroke > 0).
static func poly(n: CanvasItem, pts: Array, col: Color = INK, stroke: float = 0.0) -> void:
	if pts.size() < 2:
		return
	var packed := PackedVector2Array(pts)
	if stroke > 0.0:
		packed.append(pts[0])
		n.draw_polyline(packed, col, stroke)
	elif pts.size() >= 3:
		n.draw_colored_polygon(packed, col)

static func arrow(n: CanvasItem, a: Vector2, c: Vector2, col: Color = INK) -> void:
	var d := a.distance_to(c)
	n.draw_line(a, c, col, 1.5)
	if d < 3.0:
		return
	var h := (c - a) / d
	var s := minf(6.0, d * 0.4)
	var perp := Vector2(-h.y, h.x)
	n.draw_colored_polygon(PackedVector2Array([
		c, c - h * s + perp * s * 0.55, c - h * s - perp * s * 0.55]), col)

## The lexicon's protagonist: a round body, a nose, one eye — here for scale
## and for walking the generated worlds.
static func mote(n: CanvasItem, b: Dictionary, p: Vector2, ang: float, col: Color = MOVER, s: float = 8.0) -> void:
	var origin: Vector2 = (b.rect as Rect2).position
	n.draw_set_transform(origin + p, ang, Vector2.ONE)
	n.draw_circle(Vector2.ZERO, s, col)
	n.draw_colored_polygon(PackedVector2Array([
		Vector2(s * 0.45, -s * 0.6), Vector2(s * 1.5, 0), Vector2(s * 0.45, s * 0.6)]), col)
	n.draw_circle(Vector2(s * 0.38, -s * 0.3), s * 0.22, NIGHT)
	n.draw_set_transform(origin, 0.0, Vector2.ONE)

static func label(n: CanvasItem, b: Dictionary, txt: String, p: Vector2,
		col: Color = Color(0.91, 0.898, 0.957, 0.55), center: bool = false) -> void:
	var f := ThemeDB.fallback_font
	var x := p.x
	if center:
		x -= f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x / 2.0
	n.draw_string(f, Vector2(x, p.y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, col)

static func smooth(rate: float, dt: float) -> float:
	return 1.0 - exp(-rate * dt)

## Seeded random: the same seed gives the same world on every machine.
static func rng(seed_v: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_v
	return r

static func _hash(i: float) -> float:
	var s := sin(i * 127.1 + 311.7) * 43758.5453
	return s - floor(s)

static func _hash2(i: float, j: float) -> float:
	var s := sin(i * 127.1 + j * 269.5 + 311.7) * 43758.5453
	return s - floor(s)

## Smooth 1-D value noise in -1..1 (the web kit's noise(x)).
static func noise(x: float) -> float:
	var i := floorf(x)
	var f := x - i
	var k := f * f * (3.0 - 2.0 * f)
	return (_hash(i) + (_hash(i + 1.0) - _hash(i)) * k) * 2.0 - 1.0

## Smooth 2-D value noise in -1..1: random heights at the grid corners,
## smoothstepped across the cell (the web kit's noise2(x, y)).
static func noise2(x: float, y: float) -> float:
	var i := floorf(x)
	var j := floorf(y)
	var fx := x - i
	var fy := y - j
	var kx := fx * fx * (3.0 - 2.0 * fx)
	var ky := fy * fy * (3.0 - 2.0 * fy)
	var a := _hash2(i, j)
	var bb := _hash2(i + 1.0, j)
	var c := _hash2(i, j + 1.0)
	var d := _hash2(i + 1.0, j + 1.0)
	var top := a + (bb - a) * kx
	var bot := c + (d - c) * kx
	return (top + (bot - top) * ky) * 2.0 - 1.0

## A grid: { cols, rows, fill, a: PackedFloat32Array }. Read with cell_get
## (out-of-range reads return fill), write with cell_set (out-of-range writes
## are ignored) — the same safety the web kit's cells() gives.
static func cells(cols: int, rows: int, fill: float = 0.0) -> Dictionary:
	var a := PackedFloat32Array()
	a.resize(cols * rows)
	if fill != 0.0:
		a.fill(fill)
	return { "cols": cols, "rows": rows, "fill": fill, "a": a }

static func cell_get(g: Dictionary, x: int, y: int) -> float:
	if x < 0 or y < 0 or x >= int(g.cols) or y >= int(g.rows):
		return float(g.fill)
	return (g.a as PackedFloat32Array)[y * int(g.cols) + x]

static func cell_set(g: Dictionary, x: int, y: int, v: float) -> void:
	if x < 0 or y < 0 or x >= int(g.cols) or y >= int(g.rows):
		return
	# Write through a typed local: it shares the underlying array, whereas
	# `(g.a as PackedFloat32Array)[i] = v` writes into a temporary copy.
	var a: PackedFloat32Array = g.a
	a[y * int(g.cols) + x] = v

## Paint a grid: colour_of.call(v, x, y) returns a Color, or null to skip.
static func draw_cells(n: CanvasItem, g: Dictionary, origin: Vector2, cw: float, ch: float, colour_of: Callable) -> void:
	var cols := int(g.cols)
	var a: PackedFloat32Array = g.a
	for y in int(g.rows):
		for x in cols:
			var c: Variant = colour_of.call(a[y * cols + x], x, y)
			if c != null:
				n.draw_rect(Rect2(origin + Vector2(x * cw, y * ch), Vector2(cw + 0.5, ch + 0.5)), c)

## Fisher–Yates in place with a seeded generator.
static func shuffle(arr: Array, r: RandomNumberGenerator) -> Array:
	for i in range(arr.size() - 1, 0, -1):
		var j := r.randi_range(0, i)
		var tmp: Variant = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
	return arr

## k > 0 lightens toward white, k < 0 darkens toward black (the web's shade()).
static func shade(c: Color, k: float) -> Color:
	return c.lerp(Color.WHITE, k) if k >= 0.0 else c.lerp(Color.BLACK, -k)
