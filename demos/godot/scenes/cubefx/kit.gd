extends RefCounted
## Shared kit for the cube codex (scenes/cubefx/*.gd) — each family file
## preloads this as CubeKit. It owns the protagonist: a cube with eyes that
## patrols its card's little stage. Effects draw behind it, call draw_cube,
## then draw in front — the sandwich is the whole layering system.
##
## Card state lives in the button dictionary b:
##   b.rect — the card's stage area (absolute scene coords)
##   b.G    — the ground's y
##   b.cub  — the cube: { x, y, s, face, vx, t, pace, hop, lean, alpha, tint, spin }

static func setup(b: Dictionary) -> void:
	var r: Rect2 = b.rect
	b.G = r.position.y + r.size.y * 0.8
	b.cub = { "x": r.get_center().x, "y": b.G, "s": maxf(14.0, r.size.y * 0.17),
		"face": 1.0, "vx": 0.0, "t": randf_range(0, 9), "pace": true,
		"hop": 0.0, "lean": 0.0, "alpha": 1.0, "tint": null, "spin": 0.0 }

static func tick_cube(b: Dictionary, dt: float) -> void:
	var c: Dictionary = b.cub
	var r: Rect2 = b.rect
	c.t += dt
	if c.pace:
		var nx: float = r.get_center().x + sin(c.t * 0.55) * r.size.x * 0.2
		c.vx = (nx - c.x) / maxf(dt, 0.0001)
		if absf(c.vx) > 2.0:
			c.face = 1.0 if c.vx > 0.0 else -1.0
		c.x = nx
	else:
		c.x += c.vx * dt
	var stride: float = minf(1.0, absf(c.vx) / 30.0)
	c.hop = absf(sin(c.t * 4.2)) * c.s * 0.07 * stride
	c.lean = clampf(c.vx * 0.002, -0.14, 0.14)

static func stage(n: CanvasItem, b: Dictionary) -> void:
	var r: Rect2 = b.rect
	n.draw_rect(r, Color(0.075, 0.063, 0.125))              # the backdrop
	n.draw_rect(Rect2(r.position.x, b.G, r.size.x, r.position.y + r.size.y - b.G),
		Color(0.11, 0.094, 0.19))                            # the floor
	n.draw_line(Vector2(r.position.x, b.G), Vector2(r.position.x + r.size.x, b.G),
		Color(0.59, 0.57, 0.75, 0.35), 1.0)

static func draw_cube(n: CanvasItem, b: Dictionary) -> void:
	var c: Dictionary = b.cub
	if c.alpha <= 0.01:
		return
	var s: float = c.s
	n.draw_set_transform(Vector2(c.x, b.G + 2.0), 0.0, Vector2(1.0, 0.28))
	n.draw_circle(Vector2.ZERO, s * 0.5, Color(0, 0, 0, 0.35 * c.alpha))   # the shadow
	n.draw_set_transform(Vector2(c.x, c.y - c.hop), c.lean + c.spin, Vector2.ONE)
	var body: Color = c.tint if c.tint != null else Color(0.29, 0.263, 0.44)
	body.a *= c.alpha
	n.draw_rect(Rect2(-s / 2.0, -s, s, s), body)
	n.draw_rect(Rect2(-s / 2.0, -s, s, s), Color(0.75, 0.73, 0.88, 0.7 * c.alpha), false, 1.5)
	var ex: float = c.face * s * 0.13                        # the earnest eyes
	n.draw_rect(Rect2(ex - s * 0.17 - 1.2, -s * 0.68, 2.4, 4.0), Color(0.94, 0.93, 1.0, c.alpha))
	n.draw_rect(Rect2(ex + s * 0.17 - 1.2, -s * 0.68, 2.4, 4.0), Color(0.94, 0.93, 1.0, c.alpha))
	n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## Layered fading circles ≈ a soft additive glow.
static func glow(n: CanvasItem, pos: Vector2, radius: float, col: Color, layers: int = 3) -> void:
	for i in range(layers, 0, -1):
		var k := float(i) / layers
		n.draw_circle(pos, maxf(1.0, radius * k), Color(col.r, col.g, col.b, col.a * (1.1 - k) * 0.5))

static func twinkle(n: CanvasItem, pos: Vector2, size: float, col: Color) -> void:
	n.draw_line(pos - Vector2(size, 0), pos + Vector2(size, 0), col, 1.0)
	n.draw_line(pos - Vector2(0, size), pos + Vector2(0, size), col, 1.0)

## A quadratic curve as a polyline (wings, vines, wisps).
static func qcurve(n: CanvasItem, p0: Vector2, cp: Vector2, p1: Vector2, col: Color, width: float = 1.5) -> void:
	var pts := PackedVector2Array()
	for i in 11:
		var t := i / 10.0
		pts.append(p0.lerp(cp, t).lerp(cp.lerp(p1, t), t))
	n.draw_polyline(pts, col, width)

static func ellipse(n: CanvasItem, centre: Vector2, rx: float, ry: float, col: Color,
		width: float = 1.5, a0: float = 0.0, a1: float = TAU, steps: int = 24) -> void:
	var pts := PackedVector2Array()
	for i in steps + 1:
		var a := a0 + (a1 - a0) * i / steps
		pts.append(centre + Vector2(cos(a) * maxf(0.3, rx), sin(a) * maxf(0.3, ry)))
	n.draw_polyline(pts, col, width)
