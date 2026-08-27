extends RefCounted

const TextKit := preload("res://scenes/textfx/kit.gd")
const Base := preload("res://scenes/textfx/shake.gd")
## SHAKES & GLITCHES — the rhymes. Dials named per branch; the rest delegates.

const RHYMES := {
	"cold_shiver": { "name": "Swelter", "hint": "randomness swapped for heat haze — a smooth, sinuous wobble rising off the words" },
	"earthquake": { "name": "Aftershocks", "hint": "one press buys three quakes — each smaller, each a little later" },
	"rgb_split": { "name": "CMY split", "hint": "printers' inks instead of screen light — and the tear runs vertically" },
	"scanline_slice": { "name": "Venetian", "hint": "continuous and orderly — thin bands shear alternately left and right, like blinds" },
	"corruption": { "name": "Censorship", "hint": "the noise organized — blocks sweep across word by word, then release" },
	"nervous": { "name": "Drunk", "hint": "the fidget slowed and widened — big slow sways, letters leaning on their neighbours" },
	"sync_loss": { "name": "Interlace", "hint": "the roll traded for a comb — odd and even letters split apart and zip together" },
}

## Censorship reads the phrase by word: the start index of each word, and
## which word a letter index belongs to.
static func _word_starts() -> Array:
	var starts: Array = [0]
	for i in TextKit.PHRASE.length():
		if TextKit.PHRASE[i] == " ":
			starts.append(i + 1)
	return starts

static func _word_of(i: int, starts: Array) -> int:
	var w := 0
	for s in range(1, starts.size()):
		if i >= starts[s]:
			w = s
	return w

static func init(b: Dictionary) -> void:
	match b.id:
		"cold_shiver":
			b.heat = 1.0
		"earthquake":
			b.shocks = []
			b.trauma = 0.0
		"scanline_slice":
			b.tilt = 0.0
		"corruption":
			b.clock = 0.0
		"nervous":
			b.sober = 0.0
		"sync_loss":
			b.split = 1.0
			b.k = 1.0
		_:
			Base.init(b)

static func press(b: Dictionary, pos: Vector2) -> void:
	match b.id:
		"cold_shiver":
			b.heat = 2.2
		"earthquake":
			# dial moved: one shock → a scheduled series of three, magnitude decaying
			b.shocks = [
				{ "at": 0.0, "mag": 1.0, "age": 0.0 },
				{ "at": 1.4, "mag": 0.55, "age": 0.0 },
				{ "at": 2.6, "mag": 0.3, "age": 0.0 },
			]
		"scanline_slice":
			b.tilt = 1.0
		"corruption":
			b.clock = 0.0
		"nervous":
			b.sober = 3.0              # a coffee
		"sync_loss":
			b.split = 0.0 if b.split > 0.5 else 1.0  # zip / unzip
		_:
			Base.press(b, pos)

static func tick(b: Dictionary, dt: float, t: float) -> void:
	match b.id:
		"cold_shiver":
			# dial moved: decay 1.5 → 0.5, floored at 1 (the heat never quite leaves)
			b.heat = maxf(1.0, b.heat - dt * 0.5)
		"earthquake":
			var trauma := 0.0
			for s in b.shocks:
				s.age += dt
				var local: float = s.age - s.at
				if local > 0.0:
					trauma = maxf(trauma, maxf(0.0, s.mag - local * 0.7))
			b.shocks = b.shocks.filter(func(s): return s.age < s.at + 2.0)
			b.trauma = trauma
		"scanline_slice":
			# dial moved: release 3.0 → 0.8 (the blinds settle slowly)
			b.tilt = maxf(0.0, b.tilt - dt * 0.8)
		"corruption":
			b.clock += dt
			var period: float = (_word_starts().size() + 2) * 1.1
			if b.clock > period:
				b.clock = 0.0
		"nervous":
			b.sober = maxf(0.0, b.sober - dt)
		"sync_loss":
			# ease toward the current state — the zip is the animation
			b.k += (b.split - b.k) * minf(1.0, dt * 4.0)
		_:
			Base.tick(b, dt, t)

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	var r: Rect2 = b.rect
	var base: float = b.base_size
	match b.id:
		"cold_shiver":
			TextKit.stage(n, b)
			# dials moved: random jitter → smooth stacked sines · axis mostly vertical · warm tint
			var warm := Color(0.949, 0.886, 0.808)
			for l in TextKit.layout(b):
				var y: float = (sin(t * 4.0 + l.i * 1.8) + sin(t * 6.7 + l.i * 0.7) * 0.5) * b.heat
				var sx: float = 1.0 + sin(t * 5.0 + l.i * 2.3) * 0.03 * b.heat  # the shimmer stretch
				n.draw_set_transform(Vector2(l.cx, l.y + y), 0.0, Vector2(sx, 1.0))
				TextKit.letter(n, l.ch, Vector2(-l.w / 2.0, 0.0), base, warm)
			n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"earthquake":
			TextKit.stage(n, b)
			# dial moved: the shake reads b.trauma from the shock schedule · no ceiling dust
			var sh: float = b.trauma * b.trauma
			var dx := randf_range(-1.0, 1.0) * sh * base * 0.5
			var dy := randf_range(-1.0, 1.0) * sh * base * 0.3
			var rot := randf_range(-1.0, 1.0) * sh * 0.06
			var cx := r.get_center().x
			n.draw_set_transform(Vector2(cx + dx, b.mid + dy), rot, Vector2.ONE)
			var w := 700.0 if sh > 0.3 else 400.0
			for l in TextKit.layout(b):
				TextKit.letter_weight(n, l.ch, Vector2(l.x - cx, l.y - b.mid), base, TextKit.INK, w)
			n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"rgb_split":
			TextKit.stage(n, b)
			# dials moved: palette RGB → CMY at 0.8 alpha · tear axis horizontal → vertical · no double-tear
			var off: float = b.burst * base * 0.25
			var l_arr := TextKit.layout(b)
			for l in l_arr:            # cyan
				TextKit.letter_weight(n, l.ch, Vector2(l.x + off * 0.2, l.y - off), base,
					Color(0.353, 0.902, 0.902, 0.8), 600.0)
			for l in l_arr:            # magenta
				TextKit.letter_weight(n, l.ch, Vector2(l.x, l.y), base,
					Color(0.902, 0.353, 0.902, 0.8), 600.0)
			for l in l_arr:            # yellow
				TextKit.letter_weight(n, l.ch, Vector2(l.x - off * 0.2, l.y + off), base,
					Color(0.922, 0.922, 0.392, 0.8), 600.0)
		"scanline_slice":
			TextKit.stage(n, b)
			# dials moved: random trigger → continuous · amplitude gentled — and the
			# per-band clip has no _draw equivalent, so the alternating shear is
			# re-spelled per LETTER: index parity plays the band, dx flips with it
			var dx0: float = sin(t * 1.8) * (3.0 + b.tilt * 8.0)
			for l in TextKit.layout(b):
				var dx: float = dx0 * (1.0 if l.i % 2 == 1 else -1.0)
				TextKit.letter_weight(n, l.ch, Vector2(l.x + dx, l.y), base, TextKit.INK, 600.0)
		"corruption":
			TextKit.stage(n, b)
			# dials moved: random per-letter → an orderly sweep by word · blocks solid, not flickering
			var starts := _word_starts()
			var censored := floori(b.clock / 1.1) - 1  # which word is currently blocked (−1 = none yet)
			for l in TextKit.layout(b):
				if l.ch == " ":
					continue
				if _word_of(l.i, starts) == censored:
					n.draw_rect(Rect2(Vector2(l.x - 1.0, l.y - base * 0.68),
						Vector2(l.w + 2.0, base * 0.78)), Color(0.157, 0.141, 0.259, 0.95))
				else:
					TextKit.letter(n, l.ch, Vector2(l.x, l.y), base, TextKit.INK)
		"nervous":
			TextKit.stage(n, b)
			# dials moved: speed ×0.3 · amplitude ×4 · neighbour coupling added
			var k := 0.15 if b.sober > 0.0 else 1.0
			var lean := 0.0
			for l in TextKit.layout(b):
				lean = lean * 0.6 + sin(t * 0.9 + l.i * 1.9) * 0.4  # it leans where its neighbour leant
				var nx: float = sin(t * 1.1 + l.i * 2.1) * 3.0 * k
				var ny: float = sin(t * 0.8 + l.i * 1.3) * 2.4 * k
				n.draw_set_transform(Vector2(l.cx + nx, l.y + ny), lean * 0.18 * k, Vector2.ONE)
				TextKit.letter(n, l.ch, Vector2(-l.w / 2.0, 0.0), base, TextKit.INK)
			n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"sync_loss":
			TextKit.stage(n, b)
			# dials moved: vertical roll → static comb offset · the press zips instead of rolling
			var k: float = b.k
			for l in TextKit.layout(b):
				var dy: float = (1.0 if l.i % 2 == 1 else -1.0) * k * base * 0.22
				TextKit.letter_weight(n, l.ch, Vector2(l.x, l.y + dy), base, TextKit.INK, 500.0)
			if k > 0.1:                # the faint scanline hint while split
				var y := r.position.y
				while y < r.position.y + r.size.y:
					n.draw_rect(Rect2(Vector2(r.position.x, y), Vector2(r.size.x, 1.0)),
						Color(0.588, 0.569, 0.745, k * 0.12))
					y += 4.0
		_:
			Base.draw(n, b, t)
