extends RefCounted

const TextKit := preload("res://scenes/textfx/kit.gd")
const Base := preload("res://scenes/textfx/color.gd")
## INK & COLOUR — the rhymes. Dials named per branch; the rest delegates.

const RHYMES := {
	"rainbow_ride": { "name": "Grayscale ride", "hint": "the same ride with the saturation at zero — proof that hue was only one dial" },
	"gold_sheen": { "name": "Tarnish", "hint": "the sweep inverted — a shadow crosses silver letters instead of a gleam crossing gold" },
	"fire_ink": { "name": "Ember ink", "hint": "the fire banked for the night — a dim smoulder that only pops now and then" },
	"ocean_ink": { "name": "Lagoon", "hint": "the same water at half speed in pastel — nothing here is in a hurry" },
	"misprint": { "name": "Bad pressman", "hint": "the offsets doubled and stepped — the plates jump between misalignments" },
	"highlighter": { "name": "Redactor", "hint": "the marker turned censor — a black bar sweeps in and stays until pressed away" },
	"ink_bleed": { "name": "Ink dry", "hint": "run in reverse — solid letters dry out into pale, blurred stains" },
	"mood_ring": { "name": "Alarm", "hint": "two moods only — long calm, sudden ALERT, no blending between them" },
}

## Bad pressman's deterministic jitter — the web's sin-hash, fmod for the % 1.
static func rng(x: float) -> float:
	return fmod(sin(x * 127.1 + 311.7) * 43758.5453, 1.0)

static func init(b: Dictionary) -> void:
	Base.init(b)
	match b.id:
		"gold_sheen":
			b.sweep = -0.3                 # dial: the shadow starts mid-pause
		"fire_ink":
			b.flare = -1
			b.flare_t = 0.0
		"misprint":
			b.seed = 0
		"highlighter":
			b.lifting = 0.0
		"mood_ring":
			b.alert = false
			b.timer = 0.0

static func press(b: Dictionary, pos: Vector2) -> void:
	match b.id:
		"fire_ink":
			# dial: the press now aims the pop at a random letter
			b.flare_t = 0.0
			b.flare = int(floor(randf_range(0.0, 9.0)))
		"misprint":
			# dial: the press-to-align removed (he cannot fix it) —
			# he tries something; it becomes a different misalignment
			b.seed += 1
		"highlighter":
			b.lifting = 0.001              # dial: the press lifts the bar instead of recolouring
		"mood_ring":
			b.alert = not b.alert          # dial: a toggle, not a carousel
			b.timer = 0.0
		_:
			Base.press(b, pos)

static func tick(b: Dictionary, dt: float, t: float) -> void:
	match b.id:
		"gold_sheen":
			# dial: sweep speed 0.55 → 0.38 (×0.7 — tarnish is slower than light)
			b.sweep += dt * 0.38
			if b.sweep > 1.6:
				b.sweep = -0.3
		"fire_ink":
			# dial: constant burning → a flare on a loose 2–4 s clock
			b.flare_t += dt
			if b.flare_t > randf_range(2.0, 4.0):
				b.flare_t = 0.0
				b.flare = int(floor(randf_range(0.0, float(TextKit.PHRASE.length()))))
		"highlighter":
			# dial: no auto re-swipe — the bar stays; the lift is another sweep
			if b.lifting > 0.0:
				b.lifting = minf(1.0, b.lifting + dt * 1.2)
				if b.lifting >= 1.0:
					b.lifting = 0.0
					b.sweep = 0.0
			else:
				b.sweep = minf(1.0, b.sweep + dt * 0.9)
		"mood_ring":
			# dial: crossfade → hard snap on a two-state clock (alarms are brief; calm is long)
			b.timer += dt
			if b.timer > (2.0 if b.alert else 6.0):
				b.timer = 0.0
				b.alert = not b.alert
		_:
			Base.tick(b, dt, t)

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	var r: Rect2 = b.rect
	var base: float = b.base_size
	match b.id:
		"rainbow_ride":
			TextKit.stage(n, b)
			# dial: saturation 85% → 0% (a travelling lightness wave carries the motion instead)
			for l in TextKit.layout(b):
				var lum: float = 35.0 + 55.0 * (0.5 + 0.5 * sin((t * 60.0 * b.speed + l.i * 36.0) / 180.0 * PI))
				# hsl(0, 0%, lum%) — grey, where HSL lightness IS HSV value
				TextKit.letter_weight(n, l.ch, Vector2(l.x, l.y), base,
					Color(lum / 100.0, lum / 100.0, lum / 100.0), 600.0)
		"gold_sheen":
			TextKit.stage(n, b)
			# dials: metal gold → silver · the sweep darkens instead of brightening
			var gx: float = r.position.x + r.size.x * b.sweep
			for l in TextKit.layout(b):
				var k: float = exp(-pow((l.cx - gx) / (base * 0.9), 2.0))   # k now dims
				var v: float = 205.0 - k * 130.0
				TextKit.letter_weight(n, l.ch, Vector2(l.x, l.y), base,
					Base.rgb(v, v, v * 1.06), 700.0)
		"fire_ink":
			TextKit.stage(n, b)
			# dials: brightness ×0.4 · flicker slowed ×3 · single-letter flare added
			for l in TextKit.layout(b):
				if l.ch == " ":
					continue
				var slow: float = 0.5 + 0.5 * sin(t * 3.0 + l.i * 2.7)
				var hot: float = (1.0 - b.flare_t) if (l.i == b.flare and b.flare_t < 0.8) else 0.0   # the pop
				# the two-stop gradient → warm base body + dark tip overlay at half alpha
				TextKit.letter_weight(n, l.ch, Vector2(l.x, l.y), base,
					Base.rgb(180.0, 120.0, 80.0, 0.7 + hot * 0.3), 600.0)
				TextKit.letter(n, l.ch, Vector2(l.x, l.y), base,
					Base.rgb(120.0, 40.0, 20.0, (0.5 + slow * 0.2 + hot * 0.5) * 0.5))
				if hot > 0.0:
					# "lighter" glow → plain layering on the dark bg
					TextKit.glow(n, Vector2(l.cx, l.y - base * 0.3), base * hot,
						Base.rgb(255.0, 150.0, 60.0, hot * 0.4))
		"ocean_ink":
			TextKit.stage(n, b)
			# dials: palette deepwater → pastel · speed ×0.5 · bob halved
			for l in TextKit.layout(b):
				var k: float = 0.5 + 0.5 * sin(t * (0.6 + b.stir * 0.5) + l.i * 0.8)
				var k2: float = 0.5 + 0.5 * sin(t * 0.35 + l.i * 1.9 + 2.0)
				TextKit.letter_weight(n, l.ch,
					Vector2(l.x, l.y + sin(t * 0.8 + l.i * 0.8) * base * 0.02), base,
					Base.rgb(150.0 + k2 * 40.0, 210.0 + k * 30.0, 220.0 + k * 25.0), 500.0)
		"misprint":
			TextKit.stage(n, b)
			# dials: smooth drift → quantized jumps · offset ×2
			var step: float = floor(t * 1.5) + b.seed          # a new offset every 2/3 second
			var off: float = base * 0.13
			var lm := TextKit.layout(b)
			# "lighter" plates → three coloured copies at 0.85 alpha on the dark bg
			var plates := [
				[Base.rgb(80.0, 220.0, 255.0, 0.85), rng(step) * off, rng(step + 9.0) * off],
				[Base.rgb(255.0, 80.0, 200.0, 0.85), rng(step + 3.0) * off, rng(step + 5.0) * off],
				[Base.rgb(255.0, 235.0, 90.0, 0.85), rng(step + 7.0) * off, rng(step + 2.0) * off],
			]
			for p in plates:
				for l in lm:
					TextKit.letter_weight(n, l.ch, Vector2(l.x + p[1], l.y + p[2]), base, p[0], 700.0)
		"highlighter":
			TextKit.stage(n, b)
			# dials: colour → black, opaque · the band covers instead of underlays
			var lh := TextKit.layout(b)
			for l in lh:
				TextKit.letter(n, l.ch, Vector2(l.x, l.y), base, TextKit.INK)
			var x0: float = lh[0].x - 4.0
			var x1: float = lh[lh.size() - 1].x + lh[lh.size() - 1].w + 4.0
			var from_x: float = (x0 + (x1 - x0) * b.lifting) if b.lifting > 0.0 else x0   # the lift is another sweep
			var w: float = (x0 + (x1 - x0) * b.sweep) - from_x
			if w > 0.0:                    # canvas fillRect normalizes a negative width; draw_rect does not
				n.draw_rect(Rect2(from_x, lh[0].y - base * 0.66, w, base * 0.85),
					Base.rgb(12.0, 10.0, 22.0, 0.96))
		"ink_bleed":
			TextKit.stage(n, b)
			# dial: direction reversed — p is now how much ink REMAINS
			if not b.seeds.is_empty():
				for l in TextKit.layout(b):
					var p2: float = 1.0 - clampf((b.age - b.seeds[l.i]) / 3.5, 0.0, 1.0)
					# ctx.shadowBlur → a glow disc behind the letter + the low-alpha letter
					var blur: float = (1.0 - p2) * base * 0.35
					if blur > 0.5:
						TextKit.glow(n, Vector2(l.cx, l.y - base * 0.3), blur + l.w * 0.6,
							Base.rgb(90.0, 110.0, 200.0, 0.5 + p2 * 0.5))
					TextKit.letter_weight(n, l.ch, Vector2(l.x, l.y), base,
						Base.rgb(120.0, 140.0, 230.0, 0.18 + p2 * 0.82), 600.0)
					if p2 > 0.6:
						TextKit.letter_weight(n, l.ch, Vector2(l.x, l.y), base,
							Base.rgb(200.0, 210.0, 255.0, (p2 - 0.6) * 2.2), 600.0)
		"mood_ring":
			TextKit.stage(n, b)
			# dials: moods 4 → 2 · crossfade → hard snap · alert adds a flash border
			if b.alert:
				var col: Color = Base.rgb(255.0, 120.0, 100.0) if sin(t * 12.0) > 0.0 else Base.rgb(255.0, 170.0, 150.0)
				for l in TextKit.layout(b):
					TextKit.letter_weight(n, l.ch, Vector2(l.x, l.y + sin(t * 24.0 + l.i) * 1.2), base, col, 700.0)
				n.draw_rect(Rect2(r.position.x + 3.0, r.position.y + 3.0, r.size.x - 6.0, r.size.y - 6.0),
					Base.rgb(255.0, 120.0, 100.0, 0.4 + 0.3 * sin(t * 12.0)), false, 2.0)
			else:
				for l in TextKit.layout(b):
					TextKit.letter(n, l.ch, Vector2(l.x, l.y + sin(t * 0.8 + l.i * 0.5) * base * 0.02), base,
						Base.rgb(150.0, 200.0, 255.0))
		_:
			Base.draw(n, b, t)
