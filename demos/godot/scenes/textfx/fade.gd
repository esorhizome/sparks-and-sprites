extends RefCounted

const TextKit := preload("res://scenes/textfx/kit.gd")
## FADES & PULSES — seven text effects, ported from the web grimoire.

const TITLE := "Fades & pulses"
const BLURB := "dim to visible and back — breath as opacity"
const DEFS := [
	{ "id": "firefly_pulse", "name": "Firefly pulse", "hint": "dim to visible and back, the whole phrase on one slow pulse — press to hold it bright" },
	{ "id": "fade_in_order", "name": "Fade in order", "hint": "letters fade up left to right, hold, then fade away the same way" },
	{ "id": "fade_lottery", "name": "Fade lottery", "hint": "letters fade in, but the order is drawn from a hat — press to reshuffle" },
	{ "id": "fluorescent", "name": "Fluorescent", "hint": "an old tube starting up: erratic stutters, then steady light" },
	{ "id": "tide", "name": "Tide", "hint": "an opacity wave flows through the letters, endlessly" },
	{ "id": "afterimage", "name": "Afterimage", "hint": "a bright blink, then the long retinal fade — press to blink again" },
	{ "id": "half_light", "name": "Half-light", "hint": "odd and even letters trade visibility in a slow crossfade" },
]

## Fisher–Yates, exactly the web shuffle: j = floor(rand(0, i + 1)).
static func _shuffle(b: Dictionary) -> void:
	var order: Array = []
	for i in TextKit.PHRASE.length():
		order.append(i)
	for i in range(order.size() - 1, 0, -1):
		var j := randi_range(0, i)
		var k = order[i]
		order[i] = order[j]
		order[j] = k
	b.order = order

static func init(b: Dictionary) -> void:
	match b.id:
		"firefly_pulse":
			b.hold = 0.0
		"fade_in_order":
			b.clock = 0.0
		"fade_lottery":
			b.clock = 0.0
			_shuffle(b)
		"fluorescent":
			b.phase = 0.0
			b.level = 0.0
			b.next = 0.0
		"tide":
			b.speed = 1.0
		"afterimage":
			b.age = 0.0
		"half_light":
			b.hurry = 0.0

static func press(b: Dictionary, _pos: Vector2) -> void:
	match b.id:
		"firefly_pulse":
			b.hold = 2.5
		"fade_in_order":
			b.clock = 0.0
		"fade_lottery":
			_shuffle(b)
			b.clock = 0.0
		"fluorescent":                     # flip the switch again
			b.phase = 0.0
			b.level = 0.0
		"tide":
			b.speed = 3.0
		"afterimage":
			b.age = 0.0
		"half_light":
			b.hurry = 2.0

static func tick(b: Dictionary, dt: float, t: float) -> void:
	match b.id:
		"firefly_pulse":
			b.hold = maxf(0.0, b.hold - dt)
		"fade_in_order":
			b.clock += dt
		"fade_lottery":
			b.clock += dt
			var cycle: float = b.order.size() * 0.16 + 3.0
			if b.clock > cycle:            # every round is a new drawing
				b.clock = 0.0
				_shuffle(b)
		"fluorescent":
			b.phase += dt
			if b.phase < 2.2:              # the struggle
				b.next -= dt
				if b.next <= 0.0:
					b.level = randf_range(0.5, 1.0) if randf() < 0.55 else randf_range(0.0, 0.15)
					b.next = randf_range(0.03, 0.22)
			else:
				b.level = minf(1.0, b.level + dt * 2.0)   # the hum settles
			if b.phase > 8.0:              # and every so often, the tube gives out and tries again
				b.phase = 0.0
		"tide":
			b.speed = maxf(1.0, b.speed - dt)
		"afterimage":
			b.age += dt
			if b.age > 7.0:                # it re-blinks on its own, eventually
				b.age = 0.0
		"half_light":
			b.hurry = maxf(0.0, b.hurry - dt)

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	var ink := TextKit.INK
	TextKit.stage(n, b)
	var L := TextKit.layout(b)
	match b.id:
		"firefly_pulse":
			var a: float = 1.0 if b.hold > 0.0 else 0.08 + 0.92 * pow(0.5 + 0.5 * sin(t * TAU / 3.6), 2.0)
			for l in L:
				TextKit.letter(n, l.ch, Vector2(l.x, l.y), b.base_size, Color(ink.r, ink.g, ink.b, a))
		"fade_in_order":
			var in_end: float = L.size() * 0.14 + 0.5      # when the last letter is fully up
			var cycle: float = in_end + 2.0 + in_end + 1.0 # in, hold, out, dark
			var c: float = fmod(b.clock, cycle)
			for l in L:
				var a: float
				if c < in_end + 2.0:
					a = minf(1.0, maxf(0.0, (c - l.i * 0.14) / 0.5))
				else:
					a = 1.0 - minf(1.0, maxf(0.0, (c - (in_end + 2.0) - l.i * 0.14) / 0.5))
				TextKit.letter(n, l.ch, Vector2(l.x, l.y), b.base_size, Color(ink.r, ink.g, ink.b, a))
		"fade_lottery":
			for l in L:
				var rank: int = b.order.find(l.i)
				var a: float = minf(1.0, maxf(0.0, (b.clock - rank * 0.16) / 0.45))
				TextKit.letter(n, l.ch, Vector2(l.x, l.y), b.base_size, Color(ink.r, ink.g, ink.b, a))
		"fluorescent":
			# canvas "lighter" + radial glow → TextKit.glow's layered circles (see kit notes)
			var r: Rect2 = b.rect
			TextKit.glow(n, Vector2(r.get_center().x, b.mid - b.base_size * 0.3), b.base_size * 3.0,
				Color(0.784, 1.0, 0.922, b.level * 0.14))
			for l in L:
				TextKit.letter(n, l.ch, Vector2(l.x, l.y), b.base_size,
					Color(0.882, 1.0, 0.949, 0.06 + b.level * 0.94))
		"tide":
			for l in L:
				var a: float = 0.15 + 0.85 * pow(0.5 + 0.5 * sin(t * 2.0 * b.speed - l.i * 0.7), 1.5)
				TextKit.letter(n, l.ch, Vector2(l.x, l.y), b.base_size, Color(0.784, 0.882, 1.0, a))
		"afterimage":
			var flash: bool = b.age < 0.12
			var a: float = 1.0 if flash else maxf(0.03, exp(-(b.age - 0.12) * 0.9))
			# the flash is bold; the ghost is thin — weight via the kit's fake-bold dial
			for l in L:
				TextKit.letter_weight(n, l.ch, Vector2(l.x, l.y), b.base_size,
					Color(0.941, 0.933, 1.0, a), 700.0 if flash else 400.0)
		"half_light":
			var k: float = 0.5 + 0.5 * sin(t * TAU / (1.0 if b.hurry > 0.0 else 4.0))   # the trade
			for l in L:
				var a: float = 0.1 + 0.9 * (k if l.i % 2 == 0 else 1.0 - k)
				TextKit.letter(n, l.ch, Vector2(l.x, l.y), b.base_size, Color(ink.r, ink.g, ink.b, a))
