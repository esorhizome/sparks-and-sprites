extends RefCounted

const TextKit := preload("res://scenes/textfx/kit.gd")
## SPINS & FLIPS — seven text effects, ported from the web glyph grimoire.

const TITLE := "Spins & flips"
const BLURB := "split-flaps, coins, revolving doors"
const DEFS := [
	{ "id": "split_flap", "name": "Split-flap", "hint": "the airport board: every slot flips through glyphs until the right one clacks in" },
	{ "id": "coin_spin", "name": "Coin spin", "hint": "each letter spins like a flipped coin and lands face-up, left to right" },
	{ "id": "cartwheel", "name": "Cartwheel", "hint": "letters roll in from the left like wheels, spinning as they travel" },
	{ "id": "revolving_door", "name": "Revolving door", "hint": "letters orbit in along an arc, swinging around into their slots" },
	{ "id": "clock_hands", "name": "Clock hands", "hint": "every letter starts at its own wrong hour and rotates upright" },
	{ "id": "tumble_dry", "name": "Tumble dry", "hint": "letters tumble weightless in the drum — press to give them gravity and a baseline" },
	{ "id": "orbit_assembly", "name": "Orbit assembly", "hint": "the letters circle the centre in a ring, then spiral into their slots" },
]

static func init(b: Dictionary) -> void:
	b.clock = 0.0
	match b.id:
		"split_flap":
			b.slots = deal_slots()
			b.rest = 0.0
		"clock_hands":
			b.angles = scatter()
		"tumble_dry":
			b.bods = drum(b)
			b.settle = 0.0

static func press(b: Dictionary, _pos: Vector2) -> void:
	match b.id:
		"split_flap":
			b.slots = deal_slots()          # a fresh departure board
			b.rest = 0.0
		"clock_hands":
			b.clock = 0.0
			b.angles = scatter()            # new wrong hours
		"tumble_dry":
			b.settle = 4.0                  # gravity, briefly
		_:
			b.clock = 0.0

static func tick(b: Dictionary, dt: float, t: float) -> void:
	match b.id:
		"split_flap":
			var all_done := true
			for i in TextKit.PHRASE.length():
				if TextKit.PHRASE[i] == " ":
					continue
				var s: Dictionary = b.slots[i]
				if s.flips > 0:
					all_done = false
					s.phase += dt * 9.0     # one flip ≈ a ninth of a second
					if s.phase >= 1.0:
						s.phase = 0.0
						s.flips -= 1
						s.cur = (s.cur + 1) % TextKit.GLYPHS.length()
			if all_done:
				b.rest += dt
				if b.rest > 3.2:
					b.slots = deal_slots()
					b.rest = 0.0
		"coin_spin":
			b.clock += dt
			if b.clock > TextKit.PHRASE.length() * 0.12 + 4.0:
				b.clock = 0.0
		"cartwheel":
			b.clock += dt
			if b.clock > TextKit.PHRASE.length() * 0.08 + 4.0:
				b.clock = 0.0
		"revolving_door":
			b.clock += dt
			if b.clock > TextKit.PHRASE.length() * 0.07 + 4.2:
				b.clock = 0.0
		"clock_hands":
			b.clock += dt
			if b.clock > 6.0:
				b.clock = 0.0
				b.angles = scatter()        # the JS nulled and re-made these next frame
		"tumble_dry":
			var r: Rect2 = b.rect
			b.settle = maxf(0.0, b.settle - dt)
			var L := TextKit.layout(b)
			for l in L:
				var bd: Dictionary = b.bods[l.i]
				if b.settle > 0.0:          # ease home, straighten up
					bd.x += (l.cx - bd.x) * minf(1.0, dt * 5.0)
					bd.y += (l.y - bd.y) * minf(1.0, dt * 5.0)
					bd.a += (0.0 - bd.a) * minf(1.0, dt * 5.0)
				else:                       # drift and bounce off the drum walls
					bd.x += bd.vx * dt
					bd.y += bd.vy * dt
					bd.a += bd.va * dt
					if bd.x < r.position.x + b.base_size or bd.x > r.position.x + r.size.x - b.base_size:
						bd.vx *= -1.0
					if bd.y < r.position.y + b.base_size or bd.y > r.position.y + r.size.y - b.base_size * 0.5:
						bd.vy *= -1.0
		"orbit_assembly":
			b.clock += dt
			if b.clock > 8.0:
				b.clock = 0.0

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	TextKit.stage(n, b)
	match b.id:
		"split_flap":
			var L := TextKit.layout(b)
			for l in L:
				if l.ch == " ":
					continue
				var s: Dictionary = b.slots[l.i]
				var showing: String = TextKit.GLYPHS[s.cur] if s.flips > 0 else l.ch
				var sy: float = absf(cos(s.phase * PI)) if s.flips > 0 else 1.0   # the flap turning edge-on
				# the plate behind the letter
				var plate := Rect2(l.x - 2.0, l.y - b.base_size * 0.8, l.w + 4.0, b.base_size * 1.05)
				n.draw_rect(plate, Color(0.137, 0.118, 0.227, 0.9))
				n.draw_rect(plate, Color(0.59, 0.57, 0.75, 0.3), false, 1.0)
				n.draw_line(Vector2(l.x - 2.0, l.y - b.base_size * 0.28),          # the split line
					Vector2(l.x + l.w + 2.0, l.y - b.base_size * 0.28), Color(0.59, 0.57, 0.75, 0.3), 1.0)
				n.draw_set_transform(Vector2(l.cx, l.y - b.base_size * 0.28), 0.0, Vector2(1.0, maxf(0.06, sy)))
				TextKit.letter(n, showing, Vector2(-l.w / 2.0, b.base_size * 0.28), b.base_size,
					Color(0.91, 0.898, 0.957, 0.85) if s.flips > 0 else TextKit.INK)
				n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"coin_spin":
			var L := TextKit.layout(b)
			for l in L:
				var p: float = clampf((b.clock - l.i * 0.12) / 0.7, 0.0, 1.0)
				if p <= 0.0:
					continue
				var spins := 2.5            # total half-turns before landing
				var sx := cos(((1.0 - pow(1.0 - p, 2.0)) * spins * PI) if p < 1.0 else 0.0)
				# |cos| — the coin never truly vanishes
				n.draw_set_transform(Vector2(l.cx, l.y), 0.0, Vector2(maxf(0.05, absf(sx)), 1.0))
				TextKit.letter(n, l.ch, Vector2(-l.w / 2.0, 0.0), b.base_size,
					Color(TextKit.INK.r, TextKit.INK.g, TextKit.INK.b, 0.4 + 0.6 * absf(sx)))
				n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"cartwheel":
			var r: Rect2 = b.rect
			var L := TextKit.layout(b)
			for l in L:
				var p: float = clampf((b.clock - l.i * 0.08) / 0.8, 0.0, 1.0)
				if p <= 0.0:
					continue
				var e := 1.0 - pow(1.0 - p, 3.0)
				var x: float = r.position.x - b.base_size + (l.cx - r.position.x + b.base_size) * e
				var rot := (1.0 - e) * -PI * 3.0                   # unrolls as it arrives
				n.draw_set_transform(Vector2(x, l.y - b.base_size * 0.3), rot, Vector2.ONE)
				TextKit.letter(n, l.ch, Vector2(-l.w / 2.0, b.base_size * 0.3), b.base_size, TextKit.INK)
				n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"revolving_door":
			var L := TextKit.layout(b)
			for l in L:
				var p: float = clampf((b.clock - l.i * 0.07) / 1.0, 0.0, 1.0)
				if p <= 0.0:
					continue
				var e := 1.0 - pow(1.0 - p, 3.0)
				var a := (1.0 - e) * PI                            # half a revolution to arrive
				var rr: float = (1.0 - e) * b.base_size * 2.2
				var x: float = l.cx + sin(a * 2.0) * rr
				var y: float = l.y - sin(a) * rr
				n.draw_set_transform(Vector2(x, y), (1.0 - e) * PI * 2.0, Vector2.ONE)
				TextKit.letter(n, l.ch, Vector2(-l.w / 2.0, 0.0), b.base_size,
					Color(TextKit.INK.r, TextKit.INK.g, TextKit.INK.b, minf(1.0, p * 2.0)))
				n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"clock_hands":
			var L := TextKit.layout(b)
			var p := minf(1.0, b.clock / 2.0)
			var e := p * p * (3.0 - 2.0 * p)
			for l in L:
				var rot: float = b.angles[l.i] * (1.0 - e)
				# rotate about the letter's middle
				n.draw_set_transform(Vector2(l.cx, l.y - b.base_size * 0.3), rot, Vector2.ONE)
				TextKit.letter(n, l.ch, Vector2(-l.w / 2.0, b.base_size * 0.3), b.base_size, TextKit.INK)
				n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"tumble_dry":
			var L := TextKit.layout(b)
			for l in L:
				var bd: Dictionary = b.bods[l.i]
				n.draw_set_transform(Vector2(bd.x, bd.y), bd.a, Vector2.ONE)
				TextKit.letter(n, l.ch, Vector2(-l.w / 2.0, 0.0), b.base_size, TextKit.INK)
				n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"orbit_assembly":
			var r: Rect2 = b.rect
			var L := TextKit.layout(b)
			var p := clampf((b.clock - 1.2) / 1.8, 0.0, 1.0)       # orbit first, then land
			var e := p * p * (3.0 - 2.0 * p)
			for l in L:
				var base_a: float = float(l.i) / float(l.n) * TAU + b.clock * 1.4   # the carousel
				var rr: float = b.base_size * 2.0 * (1.0 - e)
				var x: float = r.get_center().x * (1.0 - e) + l.cx * e + cos(base_a) * rr
				var y: float = (b.mid - b.base_size * 0.3) * (1.0 - e) + l.y * e + sin(base_a) * rr * 0.5
				n.draw_set_transform(Vector2(x, y), (1.0 - e) * sin(base_a) * 0.4, Vector2.ONE)
				TextKit.letter(n, l.ch, Vector2(-l.w / 2.0, 0.0), b.base_size, TextKit.INK)
				n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## Fresh state dealers — the JS nulled these and re-made them lazily next
## frame; here they are dealt on the spot so draw never meets an empty array.

static func deal_slots() -> Array:
	var out: Array = []
	for i in TextKit.PHRASE.length():
		out.append({ "flips": int(randf_range(3.0, 10.0)) + i, "phase": 0.0,
			"cur": randi() % TextKit.GLYPHS.length() })
	return out

static func scatter() -> Array:
	var out: Array = []
	for _i in TextKit.PHRASE.length():
		out.append(randf_range(-PI, PI))
	return out

static func drum(b: Dictionary) -> Array:
	var r: Rect2 = b.rect
	var out: Array = []
	for _i in TextKit.PHRASE.length():
		out.append({ "x": r.position.x + randf_range(r.size.x * 0.2, r.size.x * 0.8),
			"y": r.position.y + randf_range(r.size.y * 0.2, r.size.y * 0.7),
			"vx": randf_range(-30.0, 30.0), "vy": randf_range(-30.0, 30.0),
			"a": randf_range(0.0, TAU), "va": randf_range(-3.0, 3.0) })
	return out
