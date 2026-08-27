extends RefCounted

const TextKit := preload("res://scenes/textfx/kit.gd")
## GLOW & NEON — seven text effects, ported from the web grimoire.

const TITLE := "Glow & neon"
const BLURB := "soft light, hard light, storefront light"
const DEFS := [
	{ "id": "candleglow", "name": "Candleglow", "hint": "a soft warm halo that flickers like a small flame — press to flare" },
	{ "id": "halo_lift", "name": "Halo lift", "hint": "a moderate cool glow on a slow three-second breath — press to double it" },
	{ "id": "supernova", "name": "Supernova", "hint": "a big glow that nearly swallows the letters — press to send out a ring" },
	{ "id": "neon_sign", "name": "Neon sign", "hint": "a magenta storefront tube — now and then one letter buzzes out" },
	{ "id": "ember_text", "name": "Ember text", "hint": "lit from within — heat shimmer rises off the letters" },
	{ "id": "beacon_sweep", "name": "Beacon sweep", "hint": "a lighthouse beam crosses the phrase, lighting letters as it passes" },
	{ "id": "chromatic_halo", "name": "Chromatic halo", "hint": "the glow splits into red, green, and blue rings that drift and re-merge" },
]

static func init(b: Dictionary) -> void:
	match b.id:
		"candleglow":
			b.flare = 0.0
			b.wick = 0.0
		"halo_lift":
			b.lift = 0.0
		"supernova":
			b.rings = []
		"neon_sign":
			b.dead = -1
			b.dead_t = 0.0
			b.all_flick = 0.0
		"ember_text":
			b.motes = []
		"beacon_sweep":
			b.hurry = 0.0
		"chromatic_halo":
			b.snap = 0.0

static func press(b: Dictionary, _pos: Vector2) -> void:
	match b.id:
		"candleglow":
			b.flare = 1.0
		"halo_lift":
			b.lift = 1.0
		"supernova":
			b.rings.append({ "r": b.base_size, "a": 0.8 })
		"neon_sign":
			b.all_flick = 0.7              # the whole sign stutters, then steadies
		"ember_text":
			# stoke it: a burst of sparks
			var L: Array = TextKit.layout(b)
			for i in 14:
				var l: Dictionary = L[int(randf_range(0.0, L.size()))]
				b.motes.append({ "x": l.cx + randf_range(-4.0, 4.0),
					"y": l.y - randf_range(0.0, b.base_size * 0.6),
					"vy": randf_range(-42.0, -20.0), "life": 1.0 })
		"beacon_sweep":
			b.hurry = 1.0
		"chromatic_halo":
			b.snap = 1.0

static func tick(b: Dictionary, dt: float, _t: float) -> void:
	match b.id:
		"candleglow":
			b.flare = maxf(0.0, b.flare - dt * 1.2)
			b.wick += (randf_range(-1.0, 1.0) - b.wick) * minf(1.0, dt * 6.0)   # the flicker, smoothed
		"halo_lift":
			b.lift = maxf(0.0, b.lift - dt * 0.7)
		"supernova":
			for rg in b.rings:
				rg.r += dt * b.base_size * 4.0
				rg.a -= dt * 0.7
			b.rings = b.rings.filter(func(rg): return rg.a > 0.0)
		"neon_sign":
			b.all_flick = maxf(0.0, b.all_flick - dt)
			b.dead_t -= dt
			if b.dead_t <= 0.0:
				b.dead = int(randf_range(0.0, 9.0)) if randf() < 0.55 else -1   # 9 = PHRASE length
				b.dead_t = randf_range(0.06, 0.3 if b.dead >= 0 else 2.4)
		"ember_text":
			var s: float = b.base_size
			var L: Array = TextKit.layout(b)
			if randf() < 0.35:
				var l: Dictionary = L[int(randf_range(0.0, L.size()))]
				if l.ch != " ":
					b.motes.append({ "x": l.cx + randf_range(-3.0, 3.0),
						"y": l.y - randf_range(0.0, s * 0.5),
						"vy": randf_range(-26.0, -12.0), "life": 0.8 })
			for m in b.motes:
				m.y += m.vy * dt
				m.x += sin(m.y * 0.15) * 12.0 * dt
				m.life -= dt * 1.1
			b.motes = b.motes.filter(func(m): return m.life > 0.0)
		"beacon_sweep":
			b.hurry = maxf(0.0, b.hurry - dt * 0.5)
		"chromatic_halo":
			b.snap = maxf(0.0, b.snap - dt * 0.8)

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	var s: float = b.base_size
	var r: Rect2 = b.rect
	var cx: float = r.get_center().x
	TextKit.stage(n, b)
	match b.id:
		"candleglow":
			var a: float = 0.10 + 0.03 * b.wick + b.flare * 0.22
			# radial gradient + composite "lighter" → TextKit.glow's translucent stack
			TextKit.glow(n, Vector2(cx, b.mid - s * 0.3),
				s * (2.6 + b.wick * 0.2 + b.flare * 1.4), Color(1, 0.75, 0.43, a))
			for l in TextKit.layout(b):
				TextKit.letter(n, l.ch, Vector2(l.x, l.y), s, Color(0.96, 0.92, 0.85))
		"halo_lift":
			var breath := 1.0 + 0.03 * sin(t * TAU / 3.0)   # the ±3% breath, borrowed from the halo demo
			var c := Vector2(cx, b.mid - s * 0.3)
			TextKit.glow(n, c, s * 3.4 * breath * (1.0 + b.lift), Color(0.55, 0.67, 1, 0.16 + b.lift * 0.14))
			TextKit.glow(n, c, s * 1.7 * breath, Color(0.75, 0.82, 1, 0.13))
			for l in TextKit.layout(b):
				TextKit.letter(n, l.ch, Vector2(l.x, l.y), s, Color(0.89, 0.92, 1))
		"supernova":
			var c := Vector2(cx, b.mid - s * 0.3)
			TextKit.glow(n, c, s * 5.2, Color(1, 0.92, 0.78, 0.20))
			TextKit.glow(n, c, s * 2.6, Color(1, 0.98, 0.92, 0.28 + 0.05 * sin(t * 2.0)))
			for rg in b.rings:
				n.draw_arc(c, rg.r, 0.0, TAU, 48, Color(1, 0.94, 0.82, rg.a), 2.0)
			for l in TextKit.layout(b):
				# canvas weight 700 → the fake-bold outline dial
				TextKit.letter_weight(n, l.ch, Vector2(l.x, l.y), s, Color(1, 0.98, 0.93), 700.0)
		"neon_sign":
			for l in TextKit.layout(b):
				if l.ch == " ":
					continue
				var on: bool = l.i != b.dead
				if b.all_flick > 0.0 and randf() < 0.4:
					on = not on
				if on:
					TextKit.glow(n, Vector2(l.cx, l.y - s * 0.32), s * 0.9, Color(1, 0.31, 0.78, 0.30))
				# canvas fill + strokeText tube → letter plus a 1px brighter outline
				TextKit.letter(n, l.ch, Vector2(l.x, l.y), s,
					Color(1, 0.71, 0.91) if on else Color(0.47, 0.24, 0.39, 0.5))
				TextKit.letter_outline(n, l.ch, Vector2(l.x, l.y), s, 1,
					Color(1, 0.59, 0.88, 0.9) if on else Color(0.47, 0.24, 0.39, 0.4))
		"ember_text":
			var L: Array = TextKit.layout(b)
			for l in L:
				if l.ch == " ":
					continue                 # each letter holds a coal at a slightly different heat
				var heat: float = 0.5 + 0.5 * sin(t * 1.7 + l.i * 1.31)
				TextKit.glow(n, Vector2(l.cx, l.y - s * 0.28), s * 0.65,
					Color(1, 0.35 + heat * 0.35, 0.16, 0.18 + heat * 0.14))
			for m in b.motes:
				TextKit.glow(n, Vector2(m.x, m.y), 2.5 + m.life * 2.0, Color(1, 0.63, 0.27, m.life * 0.7))
			for l in L:
				# the JS per-letter gradient → its midpoint colour, on the same heat clock
				var heat: float = 0.5 + 0.5 * sin(t * 1.7 + l.i * 1.31)
				TextKit.letter(n, l.ch, Vector2(l.x, l.y), s,
					Color(1, 0.67 + heat * 0.24, 0.43 + heat * 0.24))
		"beacon_sweep":
			var bx: float = r.position.x + r.size.x * (0.5 + 0.55 * sin(t * (0.8 + b.hurry * 2.2)))   # the beam's centre
			TextKit.glow(n, Vector2(bx, b.mid - s * 0.3), s * 2.2, Color(1, 0.96, 0.78, 0.22))
			for l in TextKit.layout(b):
				var k: float = maxf(0.0, 1.0 - absf(l.cx - bx) / (s * 2.2))
				TextKit.letter(n, l.ch, Vector2(l.x, l.y), s,
					Color(1, 0.97, 0.86, minf(1.0, 0.25 + k)) if k > 0.02 else TextKit.DIM)
		"chromatic_halo":
			var drift: float = s * 0.5 * (0.5 + 0.5 * sin(t * 0.7)) * (1.0 - b.snap)
			var c := Vector2(cx, b.mid - s * 0.3)
			TextKit.glow(n, c + Vector2(-drift, 0.0), s * 2.2, Color(1, 0.24, 0.35, 0.16))
			TextKit.glow(n, c + Vector2(drift * 0.5, -drift * 0.6), s * 2.2, Color(0.27, 1, 0.55, 0.14))
			TextKit.glow(n, c + Vector2(drift * 0.5, drift * 0.6), s * 2.2, Color(0.31, 0.47, 1, 0.18))
			for l in TextKit.layout(b):
				TextKit.letter(n, l.ch, Vector2(l.x, l.y), s, Color(0.95, 0.94, 0.98))
