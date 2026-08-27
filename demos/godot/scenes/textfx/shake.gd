extends RefCounted

const TextKit := preload("res://scenes/textfx/kit.gd")
## SHAKES & GLITCHES — seven text effects, ported from the web grimoire.

const TITLE := "Shakes & glitches"
const BLURB := "jitter, corruption, and the settle after"
const DEFS := [
	{ "id": "cold_shiver", "name": "Cold shiver", "hint": "a fine tremble, with a proper shiver running through now and then" },
	{ "id": "earthquake", "name": "Earthquake", "hint": "press for the quake — trauma squared, then the slow settle" },
	{ "id": "rgb_split", "name": "RGB split", "hint": "the channels tear apart in glitch bursts and heal — press for a big one" },
	{ "id": "scanline_slice", "name": "Scanline slice", "hint": "horizontal slices of the phrase shear sideways for a frame or two" },
	{ "id": "corruption", "name": "Corruption", "hint": "letters flicker into blocks and wrong glyphs, one frame at a time" },
	{ "id": "nervous", "name": "Nervous", "hint": "the letters fidget — leaning, drifting, never quite holding still" },
	{ "id": "sync_loss", "name": "Sync loss", "hint": "the picture rolls like a TV losing vertical hold, then locks back on" },
]

static func init(b: Dictionary) -> void:
	match b.id:
		"cold_shiver":
			b.shiver = 0.0
			b.next = 2.0
		"earthquake":
			b.trauma = 0.0
		"rgb_split":
			b.burst = 0.0
			b.next = 1.5
		"scanline_slice":
			b.jolt = 0.0
		"corruption":
			b.sick = 0.08              # baseline corruption probability
		"nervous":
			b.calm = 0.0
		"sync_loss":
			b.roll = 0.0
			b.v = 0.0

static func press(b: Dictionary, _pos: Vector2) -> void:
	match b.id:
		"cold_shiver":
			b.shiver = 1.0
		"earthquake":
			b.trauma = 1.0
		"rgb_split":
			b.burst = 1.0
		"scanline_slice":
			b.jolt = 1.0
		"corruption":
			b.sick = 0.6               # a bad sector
		"nervous":
			b.calm = 3.0               # a deep breath: stillness, briefly
		"sync_loss":
			b.v = b.rect.size.y * 3.0  # spin the v-hold knob

static func tick(b: Dictionary, dt: float, t: float) -> void:
	match b.id:
		"cold_shiver":
			b.next -= dt
			if b.next <= 0.0:
				b.shiver = 1.0
				b.next = randf_range(2.5, 5.0)
			b.shiver = maxf(0.0, b.shiver - dt * 1.5)
		"earthquake":
			b.trauma = maxf(0.0, b.trauma - dt * 0.7)
		"rgb_split":
			b.next -= dt
			if b.next <= 0.0:
				b.burst = maxf(b.burst, randf_range(0.2, 0.5))
				b.next = randf_range(0.8, 2.4)
			b.burst = maxf(0.0, b.burst - dt * 2.0)
		"scanline_slice":
			b.jolt = maxf(0.0, b.jolt - dt * 3.0)
		"corruption":
			b.sick = maxf(0.08, b.sick - dt * 0.4)
		"nervous":
			b.calm = maxf(0.0, b.calm - dt)
		"sync_loss":
			var h: float = b.rect.size.y
			b.v = maxf(0.0, b.v - dt * h * 2.2)
			b.roll = fmod(b.roll + b.v * dt, h)
			if b.v <= 0.0 and b.roll > 0.0:  # snap the lock
				b.roll = 0.0 if absf(b.roll) < 2.0 else b.roll * pow(0.02, dt)

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	var r: Rect2 = b.rect
	var base: float = b.base_size
	TextKit.stage(n, b)
	match b.id:
		"cold_shiver":
			var col := Color(0.847, 0.894, 0.949)
			for l in TextKit.layout(b):
				var tremble := 0.5     # the ever-present tremble, in px
				var wave: float = maxf(0.0, sin(b.shiver * PI)) * \
					exp(-pow(l.i / float(l.n) - (1.0 - b.shiver), 2.0) * 8.0) * 3.0  # the travelling shiver
				TextKit.letter(n, l.ch, Vector2(
					l.x + randf_range(-1.0, 1.0) * (tremble + wave),
					l.y + randf_range(-1.0, 1.0) * (tremble + wave)), base, col)
		"earthquake":
			var sh: float = b.trauma * b.trauma  # the chapter-06 lesson: shake by trauma², not trauma
			var dx := randf_range(-1.0, 1.0) * sh * base * 0.5
			var dy := randf_range(-1.0, 1.0) * sh * base * 0.3
			var rot := randf_range(-1.0, 1.0) * sh * 0.06
			var cx := r.get_center().x
			# ctx.save/translate/rotate → draw_set_transform pivoted on the card centre, reset after
			n.draw_set_transform(Vector2(cx + dx, b.mid + dy), rot, Vector2.ONE)
			var w := 700.0 if sh > 0.3 else 400.0  # it clenches while shaking
			for l in TextKit.layout(b):
				TextKit.letter_weight(n, l.ch, Vector2(l.x - cx, l.y - b.mid), base, TextKit.INK, w)
			n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			if sh > 0.05:              # dust from the ceiling
				var dust := Color(0.784, 0.745, 0.667, sh * 0.5)
				for i in 3:
					n.draw_rect(Rect2(r.position + Vector2(
						randf_range(0.0, r.size.x), randf_range(0.0, r.size.y)), Vector2(1.5, 1.5)), dust)
		"rgb_split":
			var off: float = b.burst * base * 0.25 * (2.0 if randf() < 0.2 else 1.0)  # occasional double-tear
			var l_arr := TextKit.layout(b)
			# gCO "lighter" → three ~0.9-alpha coats on the night backdrop read as additive
			for l in l_arr:
				TextKit.letter_weight(n, l.ch, Vector2(l.x - off, l.y + off * 0.2), base,
					Color(1.0, 0.235, 0.314, 0.9), 600.0)
			for l in l_arr:
				TextKit.letter_weight(n, l.ch, Vector2(l.x, l.y), base,
					Color(0.235, 1.0, 0.471, 0.9), 600.0)
			for l in l_arr:
				TextKit.letter_weight(n, l.ch, Vector2(l.x + off, l.y - off * 0.2), base,
					Color(0.314, 0.471, 1.0, 0.9), 600.0)
		"scanline_slice":
			# getImageData/putImageData has no _draw equivalent — re-spelled as per-letter
			# horizontal jolts: each frame rolls the same 4 bands, and a letter whose
			# glyph spans an active band takes that band's dx (ascenders catch the top
			# bands, descenders the bottom one)
			var slices := 4
			var top: float = b.mid - base * 0.85
			var hgt := base * 1.2
			var band_dx: Array = []
			for i in slices:
				var on: bool = randf() < 0.8 if b.jolt > 0.0 else randf() < 0.04
				band_dx.append(randf_range(-1.0, 1.0) * (4.0 + b.jolt * base * 0.5) if on else 0.0)
			for l in TextKit.layout(b):
				var g_top: float = l.y - base * (0.72 if l.ch in "bdfhkltij" else 0.48)
				var g_bot: float = l.y + (base * 0.2 if l.ch in "gjpqy" else 1.0)
				var dx := 0.0
				for i in slices:
					var sy: float = top + (i / float(slices)) * hgt
					if band_dx[i] != 0.0 and g_top < sy + hgt / slices and g_bot > sy:
						dx += band_dx[i]
				TextKit.letter_weight(n, l.ch, Vector2(l.x + dx, l.y), base, TextKit.INK, 600.0)
		"corruption":
			for l in TextKit.layout(b):
				if l.ch == " ":
					continue
				var roll := randf()
				if roll < b.sick * 0.4:      # a block
					n.draw_rect(Rect2(Vector2(l.x, l.y - base * 0.68),
						Vector2(l.w * 0.9, base * 0.74)), Color(0.706, 0.863, 0.627, 0.8))
				elif roll < b.sick:          # a wrong glyph
					TextKit.letter(n, TextKit.scramble(), Vector2(l.x, l.y), base,
						Color(0.706, 0.863, 0.627, 0.9))
				else:
					TextKit.letter(n, l.ch, Vector2(l.x, l.y), base, TextKit.INK)
		"nervous":
			var k := 0.15 if b.calm > 0.0 else 1.0
			for l in TextKit.layout(b):
				# smooth pseudo-noise from stacked sines — jitter without randomness
				var nx: float = (sin(t * 3.1 + l.i * 7.3) + sin(t * 5.7 + l.i * 3.1)) * 0.8 * k
				var ny: float = (sin(t * 2.7 + l.i * 5.9) + sin(t * 6.3 + l.i * 2.3)) * 0.6 * k
				var na: float = sin(t * 2.2 + l.i * 4.7) * 0.06 * k
				n.draw_set_transform(Vector2(l.cx + nx, l.y + ny), na, Vector2.ONE)
				TextKit.letter(n, l.ch, Vector2(-l.w / 2.0, 0.0), base, TextKit.INK)
			n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"sync_loss":
			var h: float = r.size.y
			var l_arr := TextKit.layout(b)
			# no ctx.clip in _draw — the rolling twin may poke past the card edge for a beat
			for pass_i in 2:           # the frame and its wraparound twin
				var dy: float = -b.roll + pass_i * h
				for l in l_arr:
					TextKit.letter_weight(n, l.ch, Vector2(l.x, l.y + dy), base, TextKit.INK, 500.0)
				if b.v > 0.0:          # the torn sync bar between frames
					n.draw_rect(Rect2(Vector2(r.position.x, r.position.y + dy - base * 1.6),
						Vector2(r.size.x, 6.0)), Color(0.588, 0.569, 0.745, 0.25))
			if b.v > 0.0 and randf() < 0.3:  # static in the tear
				var st := Color(0.784, 0.784, 0.863, 0.3)
				for i in 12:
					n.draw_rect(Rect2(r.position + Vector2(
						randf_range(0.0, r.size.x), randf_range(0.0, h)), Vector2(2.0, 1.0)), st)
