extends RefCounted

const TextKit := preload("res://scenes/textfx/kit.gd")
const Base := preload("res://scenes/textfx/fade.gd")
## FADES & PULSES — the rhymes. Dials named per branch; the rest delegates.

const RHYMES := {
	"firefly_pulse": { "name": "Slow breath", "hint": "the same pulse at rest — twice the period, and it never goes fully dark" },
	"fade_in_order": { "name": "Fade out of order", "hint": "inverted — the phrase stands whole, and random letters briefly step out" },
	"fade_lottery": { "name": "Roll call", "hint": "the same random order, but strictly one at a time — each to full before the next" },
	"fluorescent": { "name": "Dying tube", "hint": "the timeline reversed — steady light degrades into stutter, fails, tries again" },
	"tide": { "name": "Rip tide", "hint": "two waves in opposite directions, interfering — some letters get caught between" },
	"afterimage": { "name": "Double exposure", "hint": "the blink leaves an offset ghost that outlives the phrase itself" },
	"half_light": { "name": "Checkerboard", "hint": "the crossfade replaced with a snap — the trade happens all at once, twice as often" },
}

static func init(b: Dictionary) -> void:
	Base.init(b)
	match b.id:
		"fade_in_order":
			# state moved: the marching clock → one absent letter and a phase timer
			b.away = -1
			b.phase = 0.0
		"fluorescent":
			# dial: the tube begins in its good years
			b.level = 1.0
		"half_light":
			# state moved: the crossfade → a hard flip and its timer
			b.flip = 0
			b.timer = 0.0

static func press(b: Dictionary, pos: Vector2) -> void:
	match b.id:
		"fade_in_order":
			b.phase = 0.0
			b.away = -1
		"fluorescent":
			# dial: the reset relights it (level 0 → 1)
			b.phase = 0.0
			b.level = 1.0
		"half_light":
			# dial: the press trades sides instead of hurrying the fade
			b.flip = 1 - b.flip
			b.timer = 0.0
		_:
			Base.press(b, pos)

static func tick(b: Dictionary, dt: float, t: float) -> void:
	match b.id:
		"fade_in_order":
			# dial: order randomized · one absence at a time
			b.phase -= dt
			if b.phase <= 0.0:
				b.away = randi_range(0, TextKit.PHRASE.length() - 1)
				b.phase = randf_range(0.8, 1.8)
		"fade_lottery":
			# dial: one letter's whole turn 0.16 → 0.24, still a fresh draw each round
			b.clock += dt
			var cycle: float = b.order.size() * 0.24 + 3.0
			if b.clock > cycle:
				b.clock = 0.0
				Base._shuffle(b)
		"fluorescent":
			# dial: the timeline reversed — the original's struggle, played backwards
			b.phase += dt
			if b.phase < 3.0:              # the good years
				b.level = minf(1.0, b.level + dt)
			elif b.phase < 6.0:            # the decline
				b.next -= dt
				if b.next <= 0.0:
					b.level = randf_range(0.4, 0.9) if randf() < 0.6 else randf_range(0.0, 0.2)
					b.next = randf_range(0.04, 0.3)
			else:                          # the end
				b.level = maxf(0.0, b.level - dt * 3.0)
			if b.phase > 7.5:              # …and someone replaces the starter
				b.phase = 0.0
		"half_light":
			# dial: period 4s → 0.9s, and it snaps instead of gliding
			b.timer += dt
			if b.timer > 0.9:
				b.timer = 0.0
				b.flip = 1 - b.flip
		_:
			Base.tick(b, dt, t)

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	var ink := TextKit.INK
	match b.id:
		"firefly_pulse":
			TextKit.stage(n, b)
			# dials: period 3.6s → 8s · floor 0.08 → 0.35 · press holds the DIM instead of the bright
			var L := TextKit.layout(b)
			var a: float = 0.35 if b.hold > 0.0 else 0.35 + 0.65 * pow(0.5 + 0.5 * sin(t * TAU / 8.0), 2.0)
			for l in L:
				TextKit.letter(n, l.ch, Vector2(l.x, l.y), b.base_size, Color(ink.r, ink.g, ink.b, a))
		"fade_in_order":
			TextKit.stage(n, b)
			# dial: polarity flipped — visible is the resting state, the absence is the event
			var L := TextKit.layout(b)
			for l in L:
				var gone: float = 0.0
				if l.i == b.away:
					gone = minf(1.0, sin(minf(1.0, 1.0 - b.phase / 1.8) * PI) * 1.4)
				TextKit.letter(n, l.ch, Vector2(l.x, l.y), b.base_size,
					Color(ink.r, ink.g, ink.b, 1.0 - gone * 0.95))
		"fade_lottery":
			TextKit.stage(n, b)
			# dial: overlap removed (fades queue instead of cascading) · each fade ×2 faster
			var per := 0.24                # one letter's whole turn
			var L := TextKit.layout(b)
			for l in L:
				var rank: int = b.order.find(l.i)
				var a: float = minf(1.0, maxf(0.0, (b.clock - rank * per) / per))   # no overlap: turns, not waves
				TextKit.letter(n, l.ch, Vector2(l.x, l.y), b.base_size, Color(ink.r, ink.g, ink.b, a))
		"tide":
			TextKit.stage(n, b)
			# dials: a second, counter-travelling wave added · palette cooled further
			var L := TextKit.layout(b)
			for l in L:
				var w1: float = 0.5 + 0.5 * sin(t * 2.0 * b.speed - l.i * 0.7)
				var w2: float = 0.5 + 0.5 * sin(t * 1.3 * b.speed + l.i * 0.9)   # the undertow, running back
				var a: float = 0.1 + 0.9 * pow(w1 * w2, 1.2)     # only where both agree is it bright
				TextKit.letter(n, l.ch, Vector2(l.x, l.y), b.base_size, Color(0.667, 0.843, 1.0, a))
		"afterimage":
			TextKit.stage(n, b)
			# dials: a displaced second exposure added · the ghost decays SLOWER than the main image
			var flash: bool = b.age < 0.12
			var a_main: float = 1.0 if flash else maxf(0.02, exp(-(b.age - 0.12) * 1.4))
			var a_ghost: float = 0.4 if flash else (maxf(0.02, exp(-(b.age - 0.12) * 0.5)) * 0.5)
			var s: float = b.base_size
			var L := TextKit.layout(b)
			for l in L:
				TextKit.letter(n, l.ch, Vector2(l.x + s * 0.14, l.y - s * 0.1), s,
					Color(0.706, 0.745, 1.0, a_ghost))
			for l in L:
				TextKit.letter(n, l.ch, Vector2(l.x, l.y), s, Color(0.941, 0.933, 1.0, a_main))
		"half_light":
			TextKit.stage(n, b)
			# dial: the trade happens all at once — on is on, off is 0.12
			var L := TextKit.layout(b)
			for l in L:
				var on: bool = (l.i % 2) == b.flip
				TextKit.letter(n, l.ch, Vector2(l.x, l.y), b.base_size,
					Color(ink.r, ink.g, ink.b, 1.0 if on else 0.12))
		_:
			Base.draw(n, b, t)
