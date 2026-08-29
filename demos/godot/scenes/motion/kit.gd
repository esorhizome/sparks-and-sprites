extends RefCounted
## Shared kit for the locomotion lexicon (scenes/motion/*.gd) — each family
## file preloads this as Kit. Every card is a little maths stage: a night
## backdrop with graph paper, a ground line, a small blue MOTE protagonist,
## and honest vector arrows.
##
## Coordinates are CARD-LOCAL: locomotion.gd sets a draw transform to the
## card's corner before calling a family's draw(), so demo code works in
## (0,0)..(w,h) exactly like the web version (docs/locomotion.js). The two
## kit helpers that need their own transforms (mote) restore the card
## offset before returning.
##
## Card state lives in the card dictionary b:
##   b.rect — the card's stage area (absolute scene coords)
##   b.w, b.h — the stage size (local maths space)
##   b.gy — the standard ground line's y (h · 0.78)

const INK := Color(0.91, 0.898, 0.957)
const DIM := Color(0.91, 0.898, 0.957, 0.25)
const MOVER := Color(0.541, 0.851, 0.961)   ## the mote — every demo's protagonist blue
const TARGET := Color(0.961, 0.757, 0.412)  ## where it wants to be — always amber
const BONE := Color(0.788, 0.769, 0.894)    ## limbs and joints
const GOOD := Color(0.608, 0.886, 0.541)    ## helpers, friends
const HOT := Color(0.961, 0.541, 0.541)     ## impulses, lasers
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

static func arrow(n: CanvasItem, a: Vector2, c: Vector2, col: Color = INK) -> void:
	var d := a.distance_to(c)
	n.draw_line(a, c, col, 1.5)
	if d < 3.0:
		return                                  # too short to deserve a head
	var h := (c - a) / d
	var s := minf(6.0, d * 0.4)
	var perp := Vector2(-h.y, h.x)
	n.draw_colored_polygon(PackedVector2Array([
		c, c - h * s + perp * s * 0.55, c - h * s - perp * s * 0.55]), col)

## The protagonist: a round body, a nose showing its heading, one attentive
## eye. Uses its own transform, then restores the CARD offset (b.rect).
static func mote(n: CanvasItem, b: Dictionary, p: Vector2, ang: float, col: Color = MOVER, s: float = 8.0) -> void:
	var origin: Vector2 = (b.rect as Rect2).position
	n.draw_set_transform(origin + p, ang, Vector2.ONE)
	n.draw_circle(Vector2.ZERO, s, col)
	n.draw_colored_polygon(PackedVector2Array([   # the nose — heading made visible
		Vector2(s * 0.45, -s * 0.6), Vector2(s * 1.5, 0), Vector2(s * 0.45, s * 0.6)]), col)
	n.draw_circle(Vector2(s * 0.38, -s * 0.3), s * 0.22, NIGHT)   # one attentive eye
	n.draw_set_transform(origin, 0.0, Vector2.ONE)

static func label(n: CanvasItem, b: Dictionary, txt: String, p: Vector2,
		col: Color = Color(0.91, 0.898, 0.957, 0.55), center: bool = false) -> void:
	var f := ThemeDB.fallback_font
	var x := p.x
	if center:
		x -= f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x / 2.0
	n.draw_string(f, Vector2(x, p.y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, col)

## The framerate-proof lerp factor: cover this fraction of any remaining gap.
static func smooth(rate: float, dt: float) -> float:
	return 1.0 - exp(-rate * dt)
