extends RefCounted

const TextKit := preload("res://scenes/textfx/kit.gd")
## INK & COLOUR — eight text effects, ported from the web grimoire.

const TITLE := "Ink & colour"
const BLURB := "rainbows, metals, fires, and misprints"
const DEFS := [
	{ "id": "rainbow_ride", "name": "Rainbow ride", "hint": "a rainbow slides along the letters, wrapping around forever" },
	{ "id": "gold_sheen", "name": "Gold sheen", "hint": "a specular gleam sweeps across gold letters, like light down a ring" },
	{ "id": "fire_ink", "name": "Fire ink", "hint": "each letter burns — white-hot at the base, orange at the tips, always moving" },
	{ "id": "ocean_ink", "name": "Ocean ink", "hint": "blues and greens flow through the phrase like water over stones" },
	{ "id": "misprint", "name": "Misprint", "hint": "cyan, magenta, and yellow plates breathe in and out of register" },
	{ "id": "highlighter", "name": "Highlighter", "hint": "a marker swipes through behind the words — press for a fresh colour" },
	{ "id": "ink_bleed", "name": "Ink bleed", "hint": "the letters arrive as watery stains and slowly saturate into solid ink" },
	{ "id": "mood_ring", "name": "Mood ring", "hint": "the phrase drifts through moods — colour, pace, and posture together" },
]

## Highlighter's marker inks — press cycles through them.
const HI_COLOURS := [
	Color(1.0, 235.0 / 255.0, 90.0 / 255.0, 0.4),
	Color(120.0 / 255.0, 1.0, 160.0 / 255.0, 0.35),
	Color(1.0, 140.0 / 255.0, 200.0 / 255.0, 0.35),
	Color(120.0 / 255.0, 210.0 / 255.0, 1.0, 0.35),
]

## Mood ring's wardrobe — colour, pace, and posture per mood.
const MOODS := [
	{ "name": "calm", "col": Color(150.0 / 255.0, 200.0 / 255.0, 1.0), "pace": 0.6, "lift": 0.0 },
	{ "name": "joy", "col": Color(1.0, 220.0 / 255.0, 120.0 / 255.0), "pace": 1.6, "lift": 0.08 },
	{ "name": "wist", "col": Color(190.0 / 255.0, 160.0 / 255.0, 230.0 / 255.0), "pace": 0.4, "lift": -0.04 },
	{ "name": "alert", "col": Color(1.0, 140.0 / 255.0, 120.0 / 255.0), "pace": 2.4, "lift": 0.02 },
]

## The web's rgb(r,g,b) strings, channels on 0–255.
static func rgb(r: float, g: float, b: float, a: float = 1.0) -> Color:
	return Color(r / 255.0, g / 255.0, b / 255.0, a)

## The web's hsl() → Color.from_hsv. HSL is NOT HSV — same hue wheel, different
## cone: v = l + s·min(l, 1−l), s_hsv = 2·(1 − l/v). Converting exactly means
## the JS saturation/lightness numbers carry over untouched.
static func hsl(h: float, s: float, l: float) -> Color:
	var v := l + s * minf(l, 1.0 - l)
	var sv := 0.0 if v == 0.0 else 2.0 * (1.0 - l / v)
	return Color.from_hsv(fposmod(h, 360.0) / 360.0, sv, v)

static func init(b: Dictionary) -> void:
	match b.id:
		"rainbow_ride":
			b.speed = 1.0
		"gold_sheen":
			b.sweep = 0.0
		"ocean_ink":
			b.stir = 0.0
		"misprint":
			b.align = 0.0
		"highlighter":
			b.ci = 0
			b.sweep = 0.0
		"ink_bleed":
			b.age = 0.0
			b.seeds = []
		"mood_ring":
			b.mi = 0
			b.blend = 1.0
			b.timer = 0.0

static func press(b: Dictionary, _pos: Vector2) -> void:
	match b.id:
		"rainbow_ride":
			b.speed = 3.0
		"gold_sheen":
			b.sweep = -0.3                 # restart the gleam
		"fire_ink":
			pass                           # fire needs no instruction
		"ocean_ink":
			b.stir = 1.5
		"misprint":
			b.align = 2.5                  # the pressman leans on the machine — perfect register, briefly
		"highlighter":
			b.ci = (b.ci + 1) % HI_COLOURS.size()
			b.sweep = 0.0
		"ink_bleed":
			b.age = 0.0
			b.seeds = []
		"mood_ring":
			b.mi = (b.mi + 1) % MOODS.size()
			b.blend = 0.0
			b.timer = 0.0

static func tick(b: Dictionary, dt: float, t: float) -> void:
	match b.id:
		"rainbow_ride":
			b.speed = maxf(1.0, b.speed - dt)
		"gold_sheen":
			b.sweep += dt * 0.55
			if b.sweep > 1.6:              # a pause between passes
				b.sweep = -0.3
		"ocean_ink":
			b.stir = maxf(0.0, b.stir - dt)
		"misprint":
			b.align = maxf(0.0, b.align - dt)
		"highlighter":
			b.sweep = minf(1.15, b.sweep + dt * 1.1)
			if b.sweep >= 1.15 and fmod(t, 6.0) < dt:   # re-swipe on its own, occasionally
				b.sweep = 0.0
		"ink_bleed":
			b.age += dt
			if b.seeds.is_empty():
				for _i in TextKit.PHRASE.length():
					b.seeds.append(randf_range(0.0, 1.2))
			if b.age > 8.0:
				b.age = 0.0
				b.seeds = []
		"mood_ring":
			b.timer += dt
			if b.timer > 5.0:
				b.timer = 0.0
				b.mi = (b.mi + 1) % MOODS.size()
				b.blend = 0.0
			b.blend = minf(1.0, b.blend + dt * 0.8)

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	var r: Rect2 = b.rect
	var base: float = b.base_size
	TextKit.stage(n, b)
	match b.id:
		"rainbow_ride":
			for l in TextKit.layout(b):
				var hue: float = fmod(t * 60.0 * b.speed + l.i * 36.0, 360.0)
				TextKit.letter_weight(n, l.ch, Vector2(l.x, l.y), base, hsl(hue, 0.85, 0.70), 600.0)
		"gold_sheen":
			var gx: float = r.position.x + r.size.x * b.sweep      # the web's W * sweep, in card coords
			for l in TextKit.layout(b):
				var k: float = exp(-pow((l.cx - gx) / (base * 0.9), 2.0))
				TextKit.letter_weight(n, l.ch, Vector2(l.x, l.y), base,
					rgb(200.0 + k * 55.0, 165.0 + k * 85.0, 70.0 + k * 150.0), 700.0)
		"fire_ink":
			for l in TextKit.layout(b):
				if l.ch == " ":
					continue
				var flick: float = 0.5 + 0.5 * sin(t * 9.0 + l.i * 2.7) * sin(t * 5.3 + l.i)
				var jig: float = sin(t * 7.0 + l.i * 1.3) * 1.2
				# the web's per-letter vertical gradient (white-hot base →
				# red tips) → two stops: the animated mid colour as the body,
				# the hot base colour laid over it at reduced alpha
				TextKit.letter_weight(n, l.ch, Vector2(l.x, l.y + jig), base,
					rgb(255.0, 140.0 + flick * 60.0, 40.0, 0.55 + flick * 0.4), 600.0)
				TextKit.letter(n, l.ch, Vector2(l.x, l.y + jig), base,
					rgb(255.0, 240.0, 200.0, 0.35))
			# "lighter" glow over the whole phrase → plain layering on the dark bg
			TextKit.glow(n, Vector2(r.get_center().x, b.mid - base * 0.3), base * 3.0,
				rgb(255.0, 120.0, 40.0, 0.10))
		"ocean_ink":
			for l in TextKit.layout(b):
				var k: float = 0.5 + 0.5 * sin(t * (1.2 + b.stir) + l.i * 0.8)
				var k2: float = 0.5 + 0.5 * sin(t * 0.7 + l.i * 1.9 + 2.0)
				TextKit.letter_weight(n, l.ch,
					Vector2(l.x, l.y + sin(t * 1.6 + l.i * 0.8) * base * 0.04), base,
					rgb(50.0 + k2 * 60.0, 140.0 + k * 80.0, 190.0 + k * 60.0), 500.0)
		"misprint":
			var off: float = 0.0 if b.align > 0.0 else base * 0.06 * (1.0 + sin(t * TAU / 5.0))   # drift 0..12% of size
			var lm := TextKit.layout(b)
			# "lighter" plates → the three coloured copies at 0.85 alpha; on
			# the dark bg the layering reads close to additive (agreement ≈ white)
			var plates := [
				[rgb(80.0, 220.0, 255.0, 0.85), -off, off * 0.4],
				[rgb(255.0, 80.0, 200.0, 0.85), off, -off * 0.3],
				[rgb(255.0, 235.0, 90.0, 0.85), off * 0.3, off * 0.8],
			]
			for p in plates:
				for l in lm:
					TextKit.letter_weight(n, l.ch, Vector2(l.x + p[1], l.y + p[2]), base, p[0], 700.0)
		"highlighter":
			var lh := TextKit.layout(b)
			var x0: float = lh[0].x - 4.0
			var x1: float = lh[lh.size() - 1].x + lh[lh.size() - 1].w + 4.0
			var wave: float = minf(1.0, b.sweep)
			var lead: float = x0 + (x1 - x0) * wave
			# the marker band, with a slightly ragged leading edge
			n.draw_colored_polygon(PackedVector2Array([
				Vector2(x0, lh[0].y - base * 0.62),
				Vector2(lead + sin(t * 20.0) * 2.0, lh[0].y - base * 0.62 + randf_range(-1.0, 1.0)),
				Vector2(lead + sin(t * 17.0) * 2.0, lh[0].y + base * 0.18),
				Vector2(x0, lh[0].y + base * 0.18)]), HI_COLOURS[b.ci])
			for l in lh:
				TextKit.letter(n, l.ch, Vector2(l.x, l.y), base, TextKit.INK)
		"ink_bleed":
			if not b.seeds.is_empty():
				for l in TextKit.layout(b):
					var p2: float = clampf((b.age - b.seeds[l.i]) / 3.0, 0.0, 1.0)
					if p2 <= 0.0:
						continue
					# young ink: wide, soft, pale — old ink: tight, dark.
					# ctx.shadowBlur → a glow disc behind the letter (radius
					# the blur plus the letter's half-width) + the low-alpha letter
					var blur: float = (1.0 - p2) * base * 0.35
					if blur > 0.5:
						TextKit.glow(n, Vector2(l.cx, l.y - base * 0.3), blur + l.w * 0.6,
							rgb(90.0, 110.0, 200.0, 0.5 + p2 * 0.5))
					TextKit.letter_weight(n, l.ch, Vector2(l.x, l.y), base,
						rgb(120.0, 140.0, 230.0, 0.25 + p2 * 0.75), 600.0)
					if p2 > 0.6:               # the core sets
						TextKit.letter_weight(n, l.ch, Vector2(l.x, l.y), base,
							rgb(200.0, 210.0, 255.0, (p2 - 0.6) * 2.2), 600.0)
		"mood_ring":
			var m0: Dictionary = MOODS[(b.mi + MOODS.size() - 1) % MOODS.size()]   # from
			var m1: Dictionary = MOODS[b.mi]                                        # to
			var col: Color = m0.col.lerp(m1.col, b.blend)
			var pace: float = lerpf(m0.pace, m1.pace, b.blend)
			var lift: float = lerpf(m0.lift, m1.lift, b.blend)
			for l in TextKit.layout(b):
				var yb: float = sin(t * TAU * pace / 4.0 + l.i * 0.5) * base * 0.05 * pace - lift * base
				TextKit.letter(n, l.ch, Vector2(l.x, l.y + yb), base, col)
			TextKit.letter(n, "mood: " + str(m1.name), r.position + Vector2(8.0, 14.0), 10.0,
				rgb(232.0, 229.0, 244.0, 0.35))
