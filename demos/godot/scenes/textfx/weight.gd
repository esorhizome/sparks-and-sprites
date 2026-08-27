extends RefCounted

const TextKit := preload("res://scenes/textfx/kit.gd")
## WEIGHT & WIDTH — seven text effects, ported from the web grimoire.

const TITLE := "Weight & width"
const BLURB := "thin to bold to bolder — the voice clearing its throat"
const DEFS := [
	{ "id": "crescendo", "name": "Crescendo", "hint": "thin, then bold, then bolder, then bolder-and-larger — press to peak at once" },
	{ "id": "breathing_weight", "name": "Breathing weight", "hint": "the whole phrase inhales toward bold and exhales toward thin" },
	{ "id": "fat_press", "name": "Fat press", "hint": "every press feeds it a weight step; left alone, it slims back down" },
	{ "id": "stretch", "name": "Stretch", "hint": "condensed to expanded and back — press slams it wide" },
	{ "id": "heavy_word", "name": "Heavy word", "hint": "the emphasis strolls from word to word, one bold at a time" },
	{ "id": "weight_wave", "name": "Weight wave", "hint": "a bold spotlight travels through the letters like a wave down a rope" },
	{ "id": "iron_feather", "name": "Iron & feather", "hint": "alternate letters heavy and light, trading places on a beat" },
]

static func init(b: Dictionary) -> void:
	b.timer = 0.0
	match b.id:
		"crescendo":
			b.p = 0.0
			b.hold = 0.0
		"breathing_weight":
			b.boost = 0.0
		"fat_press":
			b.fat = 0.0                    # 0..4 → weights 300..700
		"stretch":
			b.slam = 0.0
		"heavy_word":
			b.which = 0
			b.starts = [0]                 # word boundaries, found once
			for i in TextKit.PHRASE.length():
				if TextKit.PHRASE[i] == " ":
					b.starts.append(i + 1)
		"weight_wave":
			b.speed = 1.0
		"iron_feather":
			b.flip = 0

static func press(b: Dictionary, _pos: Vector2) -> void:
	match b.id:
		"crescendo":
			b.p = 1.0
			b.hold = 0.8
		"breathing_weight":
			b.boost = 1.0                  # a startled deep breath
		"fat_press":
			b.fat = minf(4.0, b.fat + 1.0)
		"stretch":
			b.slam = 1.0
		"heavy_word":
			b.which = (b.which + 1) % b.starts.size()
			b.timer = 0.0
		"weight_wave":
			b.speed = 3.5                  # hurry the wave for a while
		"iron_feather":
			b.flip = 1 - b.flip
			b.timer = 0.0

static func tick(b: Dictionary, dt: float, _t: float) -> void:
	match b.id:
		"crescendo":
			if b.hold > 0.0:
				b.hold -= dt
			else:
				b.p = fmod(b.p + dt * 0.22, 1.3)   # the slow climb, with a beat of rest at the top
		"breathing_weight":
			b.boost = maxf(0.0, b.boost - dt * 0.8)
		"fat_press":
			b.fat = maxf(0.0, b.fat - dt * 0.35)   # the slow diet
		"stretch":
			b.slam = maxf(0.0, b.slam - dt * 1.4)
		"heavy_word":
			b.timer += dt
			if b.timer > 1.8:
				b.timer = 0.0
				b.which = (b.which + 1) % b.starts.size()
		"weight_wave":
			b.speed = maxf(1.0, b.speed - dt * 1.2)
		"iron_feather":
			b.timer += dt
			if b.timer > 1.2:
				b.timer = 0.0
				b.flip = 1 - b.flip

## Which word does letter i belong to? (walks the boundary list, like the JS)
static func _word_of(starts: Array, i: int) -> int:
	var w := 0
	for s in range(1, starts.size()):
		if i >= (starts[s] as int):
			w = s
	return w

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	TextKit.stage(n, b)
	match b.id:
		"crescendo":
			# canvas weights 300–700 → letter_weight; past 700 the strokeText fattening
			# becomes an extra letter_outline pass, same 0.12·BASE dial
			var k: float = minf(1.0, b.p)
			var weight := 300.0 + roundf(k * 4.0) * 100.0
			var size: float = b.base_size * (1.0 + maxf(0.0, k - 0.75) * 0.6)   # the last quarter also grows
			var L: Array = TextKit.layout(b, size)
			for l in L:
				TextKit.letter_weight(n, l.ch, Vector2(l.x, l.y), size, TextKit.INK, weight)
				if k > 0.85:
					TextKit.letter_outline(n, l.ch, Vector2(l.x, l.y), size,
						int(ceil((k - 0.85) * b.base_size * 0.12)), TextKit.INK)
		"breathing_weight":
			var k := 0.5 + 0.5 * sin(t * TAU / 4.2)          # one breath every ~4 seconds
			var weight: float = minf(700.0, 300.0 + roundf((k + b.boost * 0.5) * 4.0) * 100.0)
			var size: float = b.base_size * (1.0 + b.boost * 0.06)
			var L: Array = TextKit.layout(b, size)
			for l in L:
				TextKit.letter_weight(n, l.ch, Vector2(l.x, l.y), size, TextKit.INK, weight)
		"fat_press":
			var w := 300.0 + roundf(b.fat) * 100.0
			var L: Array = TextKit.layout(b)
			for l in L:
				TextKit.letter_weight(n, l.ch, Vector2(l.x, l.y), b.base_size, TextKit.INK, w)
			var r: Rect2 = b.rect            # the little corner readout, 10px system-ui in the JS
			n.draw_string(ThemeDB.fallback_font, r.position + Vector2(8.0, 14.0),
				"weight " + str(int(w)), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.91, 0.898, 0.957, 0.35))
		"stretch":
			var sx: float = 0.72 + 0.28 * (0.5 + 0.5 * sin(t * TAU / 5.0)) + b.slam * 0.34
			var L: Array = TextKit.layout(b)
			# respread: letter centres scaled about the phrase centre, then each
			# letter widens about its own centre (canvas translate+scale → draw_set_transform)
			var mid: float = (L[0].x + L[L.size() - 1].x + L[L.size() - 1].w) / 2.0
			for l in L:
				n.draw_set_transform(Vector2(mid + (l.cx - mid) * sx, l.y), 0.0, Vector2(sx, 1.0))
				TextKit.letter_weight(n, l.ch, Vector2(-l.w / 2.0, 0.0), b.base_size, TextKit.INK, 500.0)
			n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"heavy_word":
			# fake bold never changes metrics, so nothing shifts when emphasis lands
			# (the JS had to measure at 700 for the same guarantee)
			var L: Array = TextKit.layout(b)
			for l in L:
				if _word_of(b.starts, l.i) == b.which:
					TextKit.letter_weight(n, l.ch, Vector2(l.x, l.y), b.base_size, TextKit.INK, 700.0)
				else:
					# weight 300 + 0.6 ink → the kit spells thin as a fade, so one dim does both jobs
					TextKit.letter(n, l.ch, Vector2(l.x, l.y), b.base_size, Color(0.91, 0.898, 0.957, 0.6))
		"weight_wave":
			var L: Array = TextKit.layout(b)
			var centre := fmod(t * b.speed * 0.9, 2.0) - 0.5   # sweeps past both ends
			for l in L:
				var d: float = absf(float(l.i) / float(l.n - 1) - centre)
				var k := maxf(0.0, 1.0 - d * 3.0)              # near the wave = heavy
				var size: float = b.base_size * (1.0 + k * 0.12)
				# grown letters re-centre on their own cx, like the JS measureText dance
				var w: float = ThemeDB.fallback_font.get_string_size(l.ch,
					HORIZONTAL_ALIGNMENT_LEFT, -1, int(round(size))).x
				TextKit.letter_weight(n, l.ch, Vector2(l.cx - w / 2.0, l.y), size,
					TextKit.INK, 300.0 + roundf(k * 4.0) * 100.0)
		"iron_feather":
			var L: Array = TextKit.layout(b)
			for l in L:
				if (l.i % 2) == b.flip:
					# iron sits on the line…
					TextKit.letter_weight(n, l.ch, Vector2(l.x, l.y), b.base_size, TextKit.INK, 700.0)
				else:
					# …the feather floats a hair above it; weight 300 + 0.72 ink → one dim does both jobs
					TextKit.letter(n, l.ch, Vector2(l.x, l.y - b.base_size * 0.05), b.base_size,
						Color(0.91, 0.898, 0.957, 0.72))
