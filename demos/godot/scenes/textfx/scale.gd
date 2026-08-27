extends RefCounted

const TextKit := preload("res://scenes/textfx/kit.gd")
## GROW & SHRINK — seven text effects, ported from the web grimoire.

const TITLE := "Grow & shrink"
const BLURB := "text that swells, pops, and exhales"
const DEFS := [
	{ "id": "heartbeat", "name": "Heartbeat", "hint": "the phrase expands and shrinks on a lub-dub — press to race it" },
	{ "id": "pop_in", "name": "Pop-in", "hint": "letters pop in one by one with a springy overshoot" },
	{ "id": "rubber_band", "name": "Rubber band", "hint": "press to stretch it tall — it springs back with a jelly wobble" },
	{ "id": "zoom_arrival", "name": "Zoom arrival", "hint": "arrives from enormous — rushes past, then settles into place" },
	{ "id": "accordion", "name": "Accordion", "hint": "the letter-spacing squeezes shut and wheezes open, letters leaning as it goes" },
	{ "id": "pinpoint", "name": "Pinpoint", "hint": "the whole phrase grows out of a single point of light" },
	{ "id": "giants_whisper", "name": "Giant's whisper", "hint": "swells until it barely fits, then snaps small and starts over" },
]

static func init(b: Dictionary) -> void:
	match b.id:
		"heartbeat":
			b.race = 0.0
		"pop_in":
			b.clock = 0.0
		"rubber_band":
			b.vy = 0.0                     # a spring in one dimension
			b.sy = 1.0
		"zoom_arrival", "pinpoint":
			b.age = 0.0
		"accordion":
			b.push = 0.0
		"giants_whisper":
			b.swell = 0.6
			b.snap = 0.0

static func press(b: Dictionary, _pos: Vector2) -> void:
	match b.id:
		"heartbeat":
			b.race = 2.5
		"pop_in":
			b.clock = 0.0
		"rubber_band":
			b.vy = 9.0                     # yank
		"zoom_arrival", "pinpoint":
			b.age = 0.0
		"accordion":
			b.push = 1.0
		"giants_whisper":
			b.snap = 1.0                   # pop it early

static func tick(b: Dictionary, dt: float, t: float) -> void:
	match b.id:
		"heartbeat":
			b.race = maxf(0.0, b.race - dt)
		"pop_in":
			b.clock += dt
			var cycle := TextKit.PHRASE.length() * 0.11 + 3.4
			if b.clock > cycle:
				b.clock = 0.0
		"rubber_band":
			var k := 90.0                  # stiffness and calm-down, the two spring dials
			var damp := 6.0
			b.vy += (1.0 - b.sy) * k * dt - b.vy * damp * dt
			b.sy += b.vy * dt
		"zoom_arrival":
			b.age += dt
			if b.age > 6.0:
				b.age = 0.0
		"accordion":
			b.push = maxf(0.0, b.push - dt * 0.9)
		"pinpoint":
			b.age += dt
			if b.age > 6.5:
				b.age = 0.0
		"giants_whisper":
			if b.snap > 0.0:
				b.swell = 0.6
				b.snap = 0.0
			b.swell += dt * 0.16           # the slow, oblivious swell
			if b.swell > 1.45:
				b.swell = 0.6

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	var bs: float = b.base_size
	var r: Rect2 = b.rect
	TextKit.stage(n, b)
	match b.id:
		"heartbeat":
			var bpm := 150.0 if b.race > 0.0 else 62.0
			var beat := fmod(t * bpm / 60.0, 1.0)               # lub at 0, dub at 0.28, long rest after
			var k := maxf(exp(-beat * 14.0),
				0.72 * exp(-maxf(0.0, beat - 0.28) * 14.0) * (1.0 if beat > 0.28 else 0.0))
			var s := 1.0 + k * 0.16
			var mid := r.get_center().x
			for l in TextKit.layout(b, bs, 0.0):
				n.draw_set_transform(Vector2(mid + (l.cx - mid) * s, l.y), 0.0, Vector2(s, s))   # scale about the phrase's centre
				TextKit.letter_weight(n, l.ch, Vector2(-l.w / 2.0, 0.0), bs, TextKit.INK, 500.0)
				n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"pop_in":
			var clock: float = b.clock
			for l in TextKit.layout(b):
				var a: float = (clock - l.i * 0.11) / 0.4       # each letter's own little life
				if a <= 0.0:
					continue
				var s := 1.0 if a >= 1.0 else 1.75 * a * exp(1.0 - 1.75 * a) * 1.55   # overshoot then settle
				n.draw_set_transform(Vector2(l.cx, l.y), 0.0, Vector2(maxf(0.01, s), maxf(0.01, s)))
				TextKit.letter(n, l.ch, Vector2(-l.w / 2.0, 0.0), bs, TextKit.INK)
				n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"rubber_band":
			var sy: float = b.sy
			var sx := 1.0 / maxf(0.4, sqrt(sy))                 # conserve area: taller means narrower
			var L := TextKit.layout(b, bs, 0.0)
			var mid: float = (L[0].x + L[L.size() - 1].x + L[L.size() - 1].w) / 2.0
			for l in L:
				n.draw_set_transform(Vector2(mid + (l.cx - mid) * sx, l.y), 0.0, Vector2(sx, sy))
				TextKit.letter_weight(n, l.ch, Vector2(-l.w / 2.0, 0.0), bs, TextKit.INK, 600.0)
				n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"zoom_arrival":
			var p := minf(1.0, b.age / 0.9)
			var e := 1.0 - pow(1.0 - p, 3.0)                    # ease-out cubic: fast arrival, gentle landing
			var s := 6.0 - 5.0 * e - maxf(0.0, (1.0 - e) - 0.85) * 8.0
			var a := minf(1.0, p * 2.0)
			var mid := r.get_center().x
			for l in TextKit.layout(b, bs, 0.0):
				n.draw_set_transform(Vector2(mid + (l.cx - mid) * s, l.y - (s - 1.0) * bs * 0.3),
					0.0, Vector2(s, s))
				TextKit.letter_weight(n, l.ch, Vector2(-l.w / 2.0, 0.0), bs, Color(TextKit.INK, a), 600.0)
				n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"accordion":
			var k := 0.5 + 0.5 * sin(t * TAU / 4.6 + b.push * 3.0)
			var spacing := -bs * 0.18 + k * bs * 0.5            # from overlapped to airy
			for l in TextKit.layout(b, bs, spacing):
				n.draw_set_transform(Vector2(l.cx, l.y),
					(k - 0.5) * 0.14 * (1.0 if l.i % 2 == 1 else -1.0), Vector2.ONE)   # the bellows lean
				TextKit.letter_weight(n, l.ch, Vector2(-l.w / 2.0, 0.0), bs, TextKit.INK, 500.0)
				n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"pinpoint":
			var p := minf(1.0, b.age / 1.4)
			var e := p * p * (3.0 - 2.0 * p)                    # smoothstep: born slow, grows sure
			var mid := r.get_center().x
			# canvas "lighter" pinprick → layered glow (see kit notes)
			TextKit.glow(n, Vector2(mid, b.mid - bs * 0.3), 4.0 + (1.0 - e) * bs,
				Color(0.863, 0.824, 1.0, 0.7 - e * 0.55))
			if e <= 0.02:
				return
			for l in TextKit.layout(b, bs, 0.0):
				n.draw_set_transform(Vector2(mid + (l.cx - mid) * e, l.y), 0.0,
					Vector2(maxf(0.01, e), maxf(0.01, e)))
				TextKit.letter_weight(n, l.ch, Vector2(-l.w / 2.0, 0.0), bs, Color(TextKit.INK, e), 500.0)
				n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"giants_whisper":
			var s: float = b.swell
			var w := 700.0 if s > 1.2 else 400.0                # it even leans bold near the brim
			for l in TextKit.layout(b, bs * s, 0.0):
				TextKit.letter_weight(n, l.ch, Vector2(l.x, l.y), bs * s, TextKit.INK, w)
			if s > 1.2:                                         # the walls it's about to meet
				n.draw_rect(Rect2(r.position + Vector2(2.0, 2.0), r.size - Vector2(4.0, 4.0)),
					Color(TextKit.INK, (s - 1.2) * 1.2), false, 1.0)
