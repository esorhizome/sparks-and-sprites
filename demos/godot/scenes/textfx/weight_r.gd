extends RefCounted

const TextKit := preload("res://scenes/textfx/kit.gd")
const Base := preload("res://scenes/textfx/weight.gd")
## WEIGHT & WIDTH — the rhymes. Dials named per branch; the rest delegates.

const RHYMES := {
	"crescendo": { "name": "Diminuendo", "hint": "the same staircase walked down — bold and large first, thinning to a whisper" },
	"breathing_weight": { "name": "Panting", "hint": "the same breath at a sprint — four times faster, half as deep" },
	"fat_press": { "name": "Crash diet", "hint": "inverted — it drifts toward heavy on its own, and every press slims it" },
	"stretch": { "name": "Squeeze", "hint": "the same slider pushed the other way — it lives condensed, and the press crushes tighter" },
	"heavy_word": { "name": "Whispered word", "hint": "the walking emphasis turned inside out — one word goes quiet and italic" },
	"weight_wave": { "name": "Undertow", "hint": "the travelling spotlight pulls weight OUT — a wave of lightness through a bold line" },
	"iron_feather": { "name": "Every third", "hint": "the same trade with a longer stride — heaviness walks in threes, twice as fast" },
}

static func init(b: Dictionary) -> void:
	Base.init(b)
	match b.id:
		"fat_press":
			# dial: the diet starts from the top — fat 0 → 4
			b.fat = 4.0

static func press(b: Dictionary, pos: Vector2) -> void:
	match b.id:
		"breathing_weight":
			# dial: press catches the breath — three seconds of calm (b.boost holds them)
			b.boost = 3.0
		"fat_press":
			# dial: press −1 step instead of +1
			b.fat = maxf(0.0, b.fat - 1.0)
		"iron_feather":
			# dial: stride 2 → 3 (b.flip walks 0,1,2)
			b.flip = (b.flip + 1) % 3
			b.timer = 0.0
		_:
			Base.press(b, pos)

static func tick(b: Dictionary, dt: float, t: float) -> void:
	match b.id:
		"breathing_weight":
			# dial: the calm drains in real seconds, not at the boost rate
			b.boost = maxf(0.0, b.boost - dt)
		"fat_press":
			# dial: drift +0.35/s toward fat instead of thin
			b.fat = minf(4.0, b.fat + dt * 0.35)
		"iron_feather":
			# dial: beat 1.2s → 0.5s
			b.timer += dt
			if b.timer > 0.5:
				b.timer = 0.0
				b.flip = (b.flip + 1) % 3
		_:
			Base.tick(b, dt, t)

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	match b.id:
		"crescendo":
			TextKit.stage(n, b)
			# dials: direction reversed (k → 1−k) · press drops to the whisper instead of the peak
			var k: float = 1.0 - minf(1.0, b.p)    # the only real change: start loud, end soft
			var weight := 300.0 + roundf(k * 4.0) * 100.0
			var size: float = b.base_size * (1.0 + maxf(0.0, k - 0.75) * 0.6)
			var L: Array = TextKit.layout(b, size)
			for l in L:
				TextKit.letter_weight(n, l.ch, Vector2(l.x, l.y), size, TextKit.INK, weight)
				if k > 0.85:
					TextKit.letter_outline(n, l.ch, Vector2(l.x, l.y), size,
						int(ceil((k - 0.85) * b.base_size * 0.12)), TextKit.INK)
		"breathing_weight":
			TextKit.stage(n, b)
			# dials: period 4.2s → 1.1s · range 300–700 → 400–600 · no press swell
			var period: float = 4.2 if b.boost > 0.0 else 1.1
			var k := 0.5 + 0.5 * sin(t * TAU / period)
			var weight := 400.0 + roundf(k * 2.0) * 100.0
			var L: Array = TextKit.layout(b)
			for l in L:
				TextKit.letter_weight(n, l.ch, Vector2(l.x, l.y), b.base_size, TextKit.INK, weight)
		"stretch":
			TextKit.stage(n, b)
			# dials: range 0.72–1.0 → 0.55–0.85 · slam +0.34 → −0.22 (a crush, not a splay)
			var sx: float = 0.55 + 0.30 * (0.5 + 0.5 * sin(t * TAU / 5.0)) - b.slam * 0.22
			var L: Array = TextKit.layout(b)
			var mid: float = (L[0].x + L[L.size() - 1].x + L[L.size() - 1].w) / 2.0
			for l in L:
				n.draw_set_transform(Vector2(mid + (l.cx - mid) * sx, l.y), 0.0, Vector2(sx, 1.0))
				TextKit.letter_weight(n, l.ch, Vector2(-l.w / 2.0, 0.0), b.base_size, TextKit.INK, 500.0)
			n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"heavy_word":
			TextKit.stage(n, b)
			# dials: emphasis bold → italic-thin-dim · the rest stays at full voice
			var L: Array = TextKit.layout(b)
			for l in L:
				if Base._word_of(b.starts, l.i) == b.which:
					# canvas "i300" italic → the fallback font has no italic face, so the
					# lean is spelled as a small shear about the baseline (matrix, not rotation)
					n.draw_set_transform_matrix(Transform2D(
						Vector2(1.0, 0.0), Vector2(-0.18, 1.0), Vector2(l.x, l.y)))
					TextKit.letter(n, l.ch, Vector2.ZERO, b.base_size, Color(0.91, 0.898, 0.957, 0.4))
					n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				else:
					TextKit.letter_weight(n, l.ch, Vector2(l.x, l.y), b.base_size, TextKit.INK, 500.0)
		"weight_wave":
			TextKit.stage(n, b)
			# dials: resting weight 300 → 700 · the wave subtracts weight and size instead of adding
			var L: Array = TextKit.layout(b)
			var centre := fmod(t * b.speed * 0.9, 2.0) - 0.5
			for l in L:
				var d: float = absf(float(l.i) / float(l.n - 1) - centre)
				var k := maxf(0.0, 1.0 - d * 3.0)
				var size: float = b.base_size * (1.0 - k * 0.1)
				var w: float = ThemeDB.fallback_font.get_string_size(l.ch,
					HORIZONTAL_ALIGNMENT_LEFT, -1, int(round(size))).x
				TextKit.letter_weight(n, l.ch, Vector2(l.cx - w / 2.0, l.y), size,
					TextKit.INK, 700.0 - roundf(k * 4.0) * 100.0)
		"iron_feather":
			TextKit.stage(n, b)
			# dial: heavy = every third letter (stride and beat moved in press/tick)
			var L: Array = TextKit.layout(b)
			for l in L:
				if (l.i % 3) == b.flip:
					TextKit.letter_weight(n, l.ch, Vector2(l.x, l.y), b.base_size, TextKit.INK, 700.0)
				else:
					TextKit.letter(n, l.ch, Vector2(l.x, l.y - b.base_size * 0.05), b.base_size,
						Color(0.91, 0.898, 0.957, 0.72))
		_:
			Base.draw(n, b, t)
