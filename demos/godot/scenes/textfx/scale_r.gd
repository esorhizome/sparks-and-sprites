extends RefCounted

const TextKit := preload("res://scenes/textfx/kit.gd")
const Base := preload("res://scenes/textfx/scale.gd")
## GROW & SHRINK — the rhymes. Dials named per branch; the rest delegates.

const RHYMES := {
	"heartbeat": { "name": "Sigh", "hint": "one slow swell every few seconds, with a small droop after — the tired rhyme" },
	"pop_in": { "name": "Deflate-in", "hint": "arrivals reversed — letters appear huge and translucent, shrinking into place" },
	"rubber_band": { "name": "Pancake", "hint": "the same spring turned sideways — the press squashes it flat and wide" },
	"zoom_arrival": { "name": "Zoom departure", "hint": "the timeline reversed — it stands a while, then rushes past the camera and is gone" },
	"accordion": { "name": "Bellows", "hint": "the squeeze turned vertical — the phrase flattens and huffs back to height" },
	"pinpoint": { "name": "Horizon", "hint": "born from a line instead of a point — the phrase unfolds vertically like a sunrise" },
	"giants_whisper": { "name": "Whisper's giant", "hint": "the loop reversed — it snaps huge, then spends its time shrinking back down" },
}

static func init(b: Dictionary) -> void:
	match b.id:
		"giants_whisper":
			# dial: the loop starts huge (0.6 → 1.45)
			b.swell = 1.45
			b.snap = 0.0
		_:
			Base.init(b)

static func press(b: Dictionary, pos: Vector2) -> void:
	match b.id:
		"rubber_band":
			# dial: yank 9 → −7 — a squash, not a stretch
			b.vy = -7.0                    # flatten
		"zoom_arrival":
			b.age = 10.0                   # leave NOW
		_:
			Base.press(b, pos)

static func tick(b: Dictionary, dt: float, t: float) -> void:
	match b.id:
		"giants_whisper":
			# dial: grow-then-snap → snap-then-shrink (the sign on dt·0.16 flips)
			if b.snap > 0.0:
				b.swell = 1.45
				b.snap = 0.0
			b.swell -= dt * 0.16
			if b.swell < 0.6:
				b.swell = 1.45
		_:
			Base.tick(b, dt, t)

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	var bs: float = b.base_size
	var r: Rect2 = b.rect
	match b.id:
		"heartbeat":
			TextKit.stage(n, b)
			# dials moved: waveform lub-dub → single slow swell · a droop added on the exhale
			var period := 2.0 if b.race > 0.0 else 5.5
			var ph := fmod(t, period) / period
			var swell := sin(minf(1.0, ph * 2.2) * PI)          # in… and out
			var droop := maxf(0.0, ph - 0.6) * bs * 0.16        # the shoulders drop
			var s := 1.0 + swell * 0.1
			var mid := r.get_center().x
			for l in TextKit.layout(b, bs, 0.0):
				n.draw_set_transform(Vector2(mid + (l.cx - mid) * s, l.y + droop), 0.0, Vector2(s, s))
				TextKit.letter(n, l.ch, Vector2(-l.w / 2.0, 0.0), bs, TextKit.INK)
				n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"pop_in":
			TextKit.stage(n, b)
			# dials moved: scale direction 0→1 becomes 2.4→1 · arrival fades in from thin air
			var clock: float = b.clock
			for l in TextKit.layout(b):
				var a: float = (clock - l.i * 0.11) / 0.5
				if a <= 0.0:
					continue
				var p := minf(1.0, a)
				var e := 1.0 - pow(1.0 - p, 3.0)
				var s := 2.4 - 1.4 * e
				n.draw_set_transform(Vector2(l.cx, l.y), 0.0, Vector2(s, s))
				TextKit.letter(n, l.ch, Vector2(-l.w / 2.0, 0.0), bs, Color(TextKit.INK, e))
				n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"rubber_band":
			TextKit.stage(n, b)
			# dials moved: yank axis vertical → horizontal (sy ↔ sx) · the spring value worn sideways
			var sx: float = b.sy
			var ax := absf(sx)
			var sy := 1.0 / maxf(0.4, sqrt(ax if ax != 0.0 else 0.4))
			var L := TextKit.layout(b, bs, 0.0)
			var mid: float = (L[0].x + L[L.size() - 1].x + L[L.size() - 1].w) / 2.0
			for l in L:
				n.draw_set_transform(Vector2(mid + (l.cx - mid) * maxf(0.3, sx), l.y), 0.0,
					Vector2(maxf(0.3, sx), sy))
				TextKit.letter_weight(n, l.ch, Vector2(-l.w / 2.0, 0.0), bs, TextKit.INK, 600.0)
				n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"zoom_arrival":
			TextKit.stage(n, b)
			# dials moved: settle-then-leave instead of arrive-then-settle · it fades as it grows PAST you
			var p := minf(1.0, maxf(0.0, (b.age - 2.2) / 0.9))
			var e := p * p * p                                  # slow start, violent exit
			var s := 1.0 + e * 7.0
			var a := 1.0 - p
			var mid := r.get_center().x
			for l in TextKit.layout(b, bs, 0.0):
				n.draw_set_transform(Vector2(mid + (l.cx - mid) * s, l.y + (s - 1.0) * bs * 0.2),
					0.0, Vector2(s, s))
				TextKit.letter_weight(n, l.ch, Vector2(-l.w / 2.0, 0.0), bs, Color(TextKit.INK, a), 600.0)
				n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"accordion":
			TextKit.stage(n, b)
			# dials moved: axis horizontal spacing → vertical scale · the lean becomes a bob
			var k := 0.5 + 0.5 * sin(t * TAU / 4.6 + b.push * 3.0)
			var sy := 0.45 + k * 0.65
			for l in TextKit.layout(b, bs, 0.0):
				n.draw_set_transform(Vector2(l.cx, l.y), 0.0, Vector2(1.0, sy))
				TextKit.letter_weight(n, l.ch, Vector2(-l.w / 2.0, sin(t * 3.0 + l.i) * 1.5),
					bs, TextKit.INK, 500.0)                     # the huff
				n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"pinpoint":
			TextKit.stage(n, b)
			# dials moved: source geometry point → horizontal line · the glow becomes a band
			var p := minf(1.0, b.age / 1.4)
			var e := p * p * (3.0 - 2.0 * p)
			var y0: float = b.mid - bs * 0.3
			# the line of first light — the canvas gradient band as three stacked veils
			for i in 3:
				var h := 12.0 - i * 4.0
				n.draw_rect(Rect2(r.position.x + r.size.x * 0.1, y0 - h / 2.0, r.size.x * 0.8, h),
					Color(1.0, 0.863, 0.588, (0.5 - e * 0.4) * (0.2 + i * 0.15)))
			if e <= 0.02:
				return
			for l in TextKit.layout(b):
				n.draw_set_transform(Vector2(l.cx, y0), 0.0, Vector2(1.0, maxf(0.01, e)))   # unfolds up and down from the line
				TextKit.letter(n, l.ch, Vector2(-l.w / 2.0, bs * 0.3), bs,
					Color(0.98, 0.941, 0.863, e))
				n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"giants_whisper":
			TextKit.stage(n, b)
			# dials moved: the bold moment moves to the start · the walls are gone — it only shrinks
			var s: float = b.swell
			var w := 700.0 if s > 1.2 else 400.0
			for l in TextKit.layout(b, bs * s, 0.0):
				TextKit.letter_weight(n, l.ch, Vector2(l.x, l.y), bs * s, TextKit.INK, w)
		_:
			Base.draw(n, b, t)
