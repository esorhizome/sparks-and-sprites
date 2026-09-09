extends RefCounted

const ElemKit := preload("res://scenes/elements/kit.gd")
const Base := preload("res://scenes/elements/earth.gd")
## EARTH & STONE — the rhymes. Dials named per branch; the rest delegates.

const RHYMES := {
	"fault_line": { "name": "Ley line", "hint": "violet hum, the quake becomes a chime-ripple" },
	"crumble": { "name": "Gentle collapse", "hint": "gravity ÷3, spin ×2, a softer slower spring home — same grid" },
	"sandstorm": { "name": "Pollen wind", "hint": "slow and green-gold — spring, not desert" },
	"landslide": { "name": "Bubble rise", "hint": "gravity flipped: pebbles become climbing bubbles" },
	"geode": { "name": "Furnace door", "hint": "the interior is molten instead of crystal — a heavier door: spring 60 → 30" },
	"tectonic": { "name": "Ice floes", "hint": "pale blue open water — creep and range ×2, the grip a quarter of stone's" },
	"quicksand": { "name": "Snow sink", "hint": "softened to powder — pull ÷3, drag lighter, so the yank carries further" },
	"boulder": { "name": "Beach ball", "hint": "bounce dial cranked, gravity eased" },
}

## Turn dials the original already has — a rhyme never invents a key.
static func _turn(b: Dictionary, dials: Dictionary) -> void:
	for k in dials:
		assert(b.D.has(k), "rhyme dial %s.%s is not a dial of the original" % [b.id, k])
		b.D[k] = dials[k]

static func init(b: Dictionary) -> void:
	Base.init(b)
	if b.id == "sandstorm":
		for g in b.grains:              # the ÷2 wind dial
			g.v *= 0.45
	if b.id == "geode":
		_turn(b, { "k": 30.0 })         # dial: a furnace door is heavier — half the spring, a slower swing
	if b.id == "tectonic":              # dials: floes drift twice as far, and ice barely grips
		_turn(b, { "creep": 4.0, "range": 10.0, "stick": 50.0, "slide": 15.0 })
	if b.id == "crumble":
		b.grav = 80.0                   # a third of gravity
		b.fall = 1.8                    # a longer fall
		b.k_home = 18.0                 # a softer spring home…
		b.damp_home = 0.45              # …floatier past it
		b.settle = 4.0
	if b.id == "quicksand":
		b.pull = 3.2                    # powder's pull: terminal sink 0.8 px/s
		b.drag = 4.0                    # lighter drag: the yank carries ~21 px

static func press(b: Dictionary, pos: Vector2) -> void:
	match b.id:
		"fault_line":
			# dial: rubble burst → chime rings born on the crack
			b.press_v = 1.0
			var r: Rect2 = b.rect
			for i in 3:
				b.parts.append({ "kind": "ring", "pos": Vector2(r.size.x / 2.0, r.size.y / 2.0),
					"r": 4.0 + i * 5.0, "life": 1.0 })
		"landslide":
			# dial: the slope releases UPWARD
			b.press_v = 1.0
			var r: Rect2 = b.rect
			for i in 18:
				b.parts.append({ "pos": Vector2(randf_range(4, r.size.x - 4), r.size.y - 2.0),
					"vel": Vector2(0, randf_range(-30, -10)), "r": randf_range(1.2, 2.6) })
		_:
			Base.press(b, pos)

static func tick(b: Dictionary, dt: float, t: float) -> void:
	var r: Rect2 = b.rect
	match b.id:
		"fault_line":
			b.press_v = maxf(0.0, b.press_v - dt * 1.4)
			for p in b.parts:
				p.r += 34.0 * dt
				p.life -= dt * 1.1
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		"landslide":
			# dial: gravity +60 → buoyancy −45, wobble kept
			b.press_v = maxf(0.0, b.press_v - dt * 0.5)
			if randf() < 0.06 + b.press_v * 0.5:
				b.parts.append({ "pos": Vector2(randf_range(4, r.size.x - 4), r.size.y - 2.0),
					"vel": Vector2(0, randf_range(-30, -10)), "r": randf_range(1.2, 2.6) })
			for p in b.parts:
				p.pos += p.vel * dt
				p.vel.y -= 45.0 * dt
				p.pos.x += sin(p.pos.y * 0.3) * 6.0 * dt
			b.parts = b.parts.filter(func(p): return p.pos.y > -40.0)
		"boulder":
			# dials: gravity 500 → 180 · restitution 0.4 → 0.78
			b.press_v = maxf(0.0, b.press_v - dt * 1.4)
			if not b.falling:
				b.bx += 40.0 * dt
				b.rot += 3.0 * dt
				if b.bx > r.size.x + 12.0:
					b.bx = -12.0
			else:
				b.vy += 180.0 * dt
				b.by += b.vy * dt
				b.rot += 6.0 * dt
				if b.by > -8.0:
					if b.vy > 40.0:
						b.squash = 1.0
						b.vy = -b.vy * 0.78
					else:
						b.falling = false
						b.by = -22.0
						b.vy = 0.0
					b.by = minf(b.by, -8.0)
			b.squash = maxf(0.0, b.squash - dt * 4.0)
			for p in b.parts:
				p.pos += p.vel * dt
				p.vel.y += 80.0 * dt
				p.life -= dt * 1.8
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		_:
			Base.tick(b, dt, t)         # crumble and quicksand: the dials moved in init, the same springs run

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	var r: Rect2 = b.rect
	var o := r.position
	var pv: float = b.press_v
	match b.id:
		"fault_line":
			# dials: magma orange → arcane violet · no shake, a hum instead
			ElemKit.face(n, r, Color(0.086, 0.063, 0.13), Color(0.71, 0.55, 0.94, 0.5))
			var glow: float = 0.45 + 0.3 * sin(t * 1.8) + pv * 0.5
			var crack: Array = b.crack
			for i in range(crack.size() - 1):
				n.draw_line(o + crack[i], o + crack[i + 1],
					Color(0.78, 0.55, 1.0, minf(1.0, glow)), 1.6 + pv * 1.5)
			ElemKit.label(n, r, "LEYLINE", Color(0.9, 0.84, 0.98))
			for p in b.parts:
				ElemKit.ellipse(n, r.get_center(), p.r * 1.5, p.r * 0.8,
					Color(0.8, 0.63, 1.0, p.life * 0.6), 1.2)
		"sandstorm":
			# dials: desert tan → spring green-gold
			ElemKit.face(n, r, Color(0.08, 0.11, 0.055), Color(0.75, 0.86, 0.47, 0.5))
			ElemKit.label(n, r, "POLLINATE", Color(0.93, 0.95, 0.78))
			for g in b.grains:
				n.draw_circle(o + g.pos, 1.2, Color(0.92, 0.88, 0.5, 0.35 + pv * 0.4))
		"landslide":
			var lean: float = pv * sin(t * 30.0) * 0.01
			n.draw_set_transform(r.get_center(), lean, Vector2.ONE)
			ElemKit.face(n, Rect2(-r.size / 2.0, r.size), Color(0.055, 0.086, 0.11), Color(0.51, 0.75, 0.86, 0.5))
			ElemKit.label(n, Rect2(-r.size / 2.0, r.size), "BUOYANT", Color(0.83, 0.93, 0.96))
			n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			for p in b.parts:
				ElemKit.ellipse(n, o + p.pos, p.r, p.r, Color(0.67, 0.88, 0.94, 0.85), 1.0)
		"geode":
			# dials: amethyst interior → molten furnace (the spring dial is in init)
			var gap: float = b.gap
			if b.open > 0.05:
				ElemKit.face(n, r, Color(0.23, 0.086, 0.02))
				ElemKit.glow(n, r.get_center(), 16.0 + b.open * 10.0, Color(1, 0.7, 0.27, 0.5 * b.open), 4)
				for gl in b.glitter:
					var a: float = maxf(0.0, sin(t * 4.0 + gl.ph)) * b.open
					n.draw_circle(o + gl.pos, 1.8, Color(1, 0.82, 0.43, a))
			for side in [-1.0, 1.0]:
				var half := Rect2(o + Vector2(side * gap / 2.0, 0), Vector2(r.size.x / 2.0, r.size.y))
				if side > 0:
					half.position.x += r.size.x / 2.0
				n.draw_rect(half, Color(0.14, 0.11, 0.1, 1.0 - b.open * 0.15))
			ElemKit.ring_face(n, r.grow(gap / 2.0), Color(0.86, 0.6, 0.35, 0.5))
			if b.open < 0.4:
				ElemKit.label(n, r, "FURNACE", Color(0.95, 0.85, 0.75))
		"tectonic":
			# dials: stone plates → ice floes, open water between (drift and grip dials in init)
			ElemKit.face(n, r, Color(0.055, 0.11, 0.165), Color(0.55, 0.78, 0.92, 0.5))
			var pw := r.size.x / 3.0
			var px: PackedFloat32Array = b.px
			for p in 3:
				var plate := Rect2(o + Vector2(p * pw + px[p] + 2.0, 2.0),
					Vector2(pw - 4.0, r.size.y - 4.0))
				n.draw_rect(plate, Color(0.85, 0.92, 0.97))
				n.draw_rect(plate, Color(0.63, 0.82, 0.94, 0.6), false, 1.0)
			ElemKit.label(n, r, "DRIFT", Color(0.1, 0.2, 0.3, 0.85))
			for p in b.parts:
				n.draw_circle(o + p.pos, 1.8, Color(0.85, 0.94, 1.0, p.life))
		"quicksand":
			# dials: sand → powder snow
			ElemKit.face(n, r, Color(0.1, 0.11, 0.14), Color(0.82, 0.88, 0.96, 0.5))
			var lr := Rect2(r.position + Vector2(0, b.sink), r.size)
			var submerged: float = clampf(1.0 - b.sink / (r.size.y * 0.4), 0.15, 1.0)
			ElemKit.label(n, lr, "SOFT LANDING", Color(0.92, 0.95, 1.0, submerged))
			var poly := PackedVector2Array()
			poly.append(o + Vector2(0, r.size.y))
			poly.append(o + Vector2(0, r.size.y * 0.55))
			var x := 0.0
			while x <= r.size.x:
				poly.append(o + Vector2(x, r.size.y * 0.55 + sin(x * 0.15 + t * 0.6) * 1.5))
				x += 6.0
			poly.append(o + Vector2(r.size.x, r.size.y))
			n.draw_colored_polygon(poly, Color(0.88, 0.92, 0.97, 0.9))
			if randf() < 0.04:
				ElemKit.ellipse(n, o + Vector2(r.size.x / 2.0 + randf_range(-20, 20), r.size.y * 0.55),
					randf_range(4, 9), 2.0, Color(1, 1, 1, 0.4), 1.0)
		"boulder":
			# dials: stone → striped beach ball
			ElemKit.face(n, r, Color(0.07, 0.1, 0.13), Color(0.55, 0.8, 0.9, 0.55))
			ElemKit.label(n, r, "HEADS UP", Color(0.85, 0.93, 0.97))
			n.draw_set_transform(o + Vector2(b.bx, b.by), b.rot,
				Vector2(1.0 + b.squash * 0.3, 1.0 - b.squash * 0.3))
			n.draw_circle(Vector2.ZERO, 8.0, Color(0.95, 0.94, 0.9))
			for k in 3:
				var a0 := k / 3.0 * TAU
				var poly := PackedVector2Array([Vector2.ZERO])
				for s in 7:
					var a := a0 + s / 6.0 * TAU / 6.0
					poly.append(Vector2(cos(a), sin(a)) * 8.0)
				n.draw_colored_polygon(poly, [Color(0.9, 0.3, 0.3), Color(0.3, 0.55, 0.9), Color(0.95, 0.8, 0.3)][k])
			n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			for p in b.parts:
				n.draw_rect(Rect2(o + p.pos, Vector2(2, 2)), Color(0.8, 0.88, 0.94, p.life * 0.7))
		_:
			Base.draw(n, b, t)
