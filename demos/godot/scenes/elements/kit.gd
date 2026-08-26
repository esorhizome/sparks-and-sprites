extends RefCounted
## Shared drawing helpers for the elemental button bestiary
## (scenes/elements/*.gd) — each family file preloads this as ElemKit.
## Canvas 2D's gradients and additive blending are emulated with layered
## translucent shapes — same look, honest arithmetic.

static func face(n: CanvasItem, r: Rect2, bg: Color, border: Color = Color.TRANSPARENT) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(10)
	if border.a > 0.0:
		sb.border_color = border
		sb.set_border_width_all(2)
	n.draw_style_box(sb, r)

## A border-only rounded rect (neon tubes, outlines).
static func ring_face(n: CanvasItem, r: Rect2, border: Color, width: int = 2) -> void:
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.set_corner_radius_all(10)
	sb.border_color = border
	sb.set_border_width_all(width)
	n.draw_style_box(sb, r)

static func label(n: CanvasItem, r: Rect2, text: String, col: Color) -> void:
	n.draw_string(ThemeDB.fallback_font, Vector2(r.position.x, r.get_center().y + 5),
		text, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 13, col)

## Layered fading circles ≈ a soft radial-gradient glow.
static func glow(n: CanvasItem, pos: Vector2, radius: float, col: Color, layers: int = 4) -> void:
	for i in range(layers, 0, -1):
		var k := float(i) / layers
		n.draw_circle(pos, radius * k, Color(col.r, col.g, col.b, col.a * (1.1 - k) * 0.5))

## A quadratic curve stroked as a short polyline (prominences, wisps, vines).
static func qcurve(n: CanvasItem, p0: Vector2, c: Vector2, p1: Vector2, col: Color, width: float = 1.5) -> void:
	var pts := PackedVector2Array()
	for i in 11:
		var u := i / 10.0
		pts.append(p0.lerp(c, u).lerp(c.lerp(p1, u), u))
	n.draw_polyline(pts, col, width)

## An ellipse outline (rings, ripples, orbits) — optionally a partial arc.
static func ellipse(n: CanvasItem, centre: Vector2, rx: float, ry: float, col: Color,
		width: float = 1.5, a0: float = 0.0, a1: float = TAU, steps: int = 32) -> void:
	var pts := PackedVector2Array()
	for i in steps + 1:
		var a := a0 + (a1 - a0) * i / steps
		pts.append(centre + Vector2(cos(a) * rx, sin(a) * ry))
	n.draw_polyline(pts, col, width)

## A tiny 4-point twinkle (glitter, sparkles).
static func twinkle(n: CanvasItem, pos: Vector2, size: float, col: Color) -> void:
	n.draw_line(pos - Vector2(size, 0), pos + Vector2(size, 0), col, 1.0)
	n.draw_line(pos - Vector2(0, size), pos + Vector2(0, size), col, 1.0)
