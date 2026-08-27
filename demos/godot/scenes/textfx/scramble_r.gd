extends RefCounted

const TextKit := preload("res://scenes/textfx/kit.gd")
const Base := preload("res://scenes/textfx/scramble.gd")
## SCRAMBLES & DECODES — the rhymes. Dials named per branch; the rest delegates.

const RHYMES := {
	"decoder": { "name": "Encoder", "hint": "run backwards — a clean phrase corrupts letter by letter into cipher, then returns" },
	"slot_machine": { "name": "Jackpot", "hint": "the reels spin faster and all brake at the same instant — then the win flash" },
	"jumble_home": { "name": "Scatter", "hint": "the loop inverted — it rests assembled, and the press is what throws it" },
	"matrix_rain": { "name": "Blossom rain", "hint": "the rain warms and reverses — petals drift UP, and the phrase blooms out of them" },
	"anagram_walk": { "name": "Neighbour swap", "hint": "only adjacent letters trade, twice as often — the phrase stays almost readable" },
	"static_tune": { "name": "Ghost signal", "hint": "tuned letters LINGER after the dial moves on — the broadcast refuses to die" },
	"cipher_wheel": { "name": "Countdown", "hint": "letters land when their digit hits zero — every slot counts down from nine" },
	"number_station": { "name": "Morse station", "hint": "dots and dashes instead of digits — and the press decodes one word at a time" },
}

static func _jackpot_spin(b: Dictionary) -> void:
	# dial: spin speed 14..20 → 24..30 · no per-reel stop_at — everyone shares one
	b.reels = []
	for i in TextKit.PHRASE.length():
		b.reels.append({ "v": randf_range(24.0, 30.0), "off": randf_range(0.0, float(TextKit.GLYPHS.length())),
			"done": false })
	b.spin_t = 0.0
	b.rest = 0.0
	b.flash = 0.0

static func _countdown(b: Dictionary) -> void:
	# dial: refill 6..22 random → 9 + 2i staggered (later letters start higher)
	b.offs = []
	for i in TextKit.PHRASE.length():
		b.offs.append(9.0 + i * 2.0)
	b.rest = 0.0

static func init(b: Dictionary) -> void:
	Base.init(b)
	match b.id:
		"decoder":
			b.dir = 1                  # dial added: which way the machine runs
		"slot_machine":
			_jackpot_spin(b)
		"jumble_home":
			# dial: it rests ASSEMBLED — no opening scatter, the press throws
			b.pts = []
			b.thrown = 0.0
		"matrix_rain":
			# dials: fall speed 40..110 → 24..70 · petals start inside the card
			var r: Rect2 = b.rect
			b.drops = []
			for i in int(r.size.x / 12.0):
				b.drops.append({ "x": r.position.x + 6.0 + i * 12.0,
					"y": r.position.y + randf_range(0.0, r.size.y), "v": randf_range(24.0, 70.0) })
		"anagram_walk":
			b.wait = 0.3               # dial: first wait 0.5 → 0.3
		"static_tune":
			b.mem = []                 # dial added: remembered clarity per letter
		"cipher_wheel":
			_countdown(b)
		"number_station":
			# dials added: word starts, word-by-word clarity, morse marks
			b.clear_words = 0
			b.fade = 0.0
			b.starts = [0]
			for i in TextKit.PHRASE.length():
				if TextKit.PHRASE[i] == " ":
					b.starts.append(i + 1)
			b.marks = []
			for i in TextKit.PHRASE.length():
				b.marks.append(randf() < 0.5)

static func press(b: Dictionary, pos: Vector2) -> void:
	match b.id:
		"decoder":
			b.dir = -b.dir             # dial: press reverses the machine instead of restarting it
		"slot_machine":
			_jackpot_spin(b)
		"jumble_home":
			# dial: driven by press instead of a cycle — scatter is an explosion, not a shuffle
			# (thrown targets clamped into the card; the web canvas clipped for free)
			var r: Rect2 = b.rect
			var pts: Array = []
			for l in TextKit.layout(b):
				pts.append({ "x": clampf(l.cx + randf_range(-1.0, 1.0) * r.size.x * 0.3, r.position.x + 8.0, r.end.x - 8.0),
					"y": l.y + randf_range(-1.0, 1.0) * r.size.y * 0.45, "r": randf_range(-2.0, 2.0) })
			b.pts = pts
			b.thrown = 1.0
		"number_station":
			# dial: resolve granularity all-at-once → word by word
			b.clear_words = mini(b.starts.size(), b.clear_words + 1)
			b.fade = 6.0
		_:
			Base.press(b, pos)

static func tick(b: Dictionary, dt: float, t: float) -> void:
	match b.id:
		"decoder":
			# dial: resolve direction flipped (readable → cipher) · the cycle breathes both ways
			b.churn_t += dt
			if b.churn_t > 0.05:
				b.churn_t = 0.0
				b.churn = []
				for i in TextKit.PHRASE.length():
					b.churn.append(TextKit.scramble())
			b.timer += dt
			if b.timer > 0.22:
				b.timer = 0.0
				b.fixed += b.dir
				if b.fixed >= TextKit.PHRASE.length():
					b.fixed = TextKit.PHRASE.length()
					b.dir = -1
				if b.fixed <= 0:
					b.fixed = 0
					b.dir = 1
		"slot_machine":
			# dials: staggered stops → one shared STOP at 1.6 · brake 30 → 40
			b.flash = maxf(0.0, b.flash - dt * 1.2)
			b.spin_t += dt
			var all_done := true
			for i in TextKit.PHRASE.length():
				if TextKit.PHRASE[i] == " ":
					continue
				var rl: Dictionary = b.reels[i]
				if not rl.done:
					if b.spin_t > 1.6:                       # everyone, together
						rl.v = maxf(0.0, rl.v - dt * 40.0)
					rl.off += rl.v * dt
					if b.spin_t > 1.6 and rl.v < 0.8:
						rl.done = true
						rl.off = 0.0
						var every := true
						for j in TextKit.PHRASE.length():
							if TextKit.PHRASE[j] != " " and not b.reels[j].done:
								every = false
						if every:
							b.flash = 1.0                    # the house pays out in light
				if not rl.done:
					all_done = false
			if all_done:
				b.rest += dt
				if b.rest > 3.0:
					_jackpot_spin(b)
		"jumble_home":
			# dial: no cycle — thrown decays and the letters ease home
			b.thrown = maxf(0.0, b.thrown - dt * 0.55)
		"matrix_rain":
			# dial: fall direction flipped — upward, unhurried; wrap runs top → bottom
			b.resolve += dt
			var r: Rect2 = b.rect
			for d in b.drops:
				d.y -= d.v * dt
				if d.y < r.position.y - 20.0:
					d.y = r.end.y + randf_range(10.0, 40.0)
					d.v = randf_range(24.0, 70.0)
			if b.resolve > 9.0:
				b.resolve = 0.0
		"anagram_walk":
			# dials: swap distance any → adjacent only · lerp 1.6 → 3 · wait 0.3..0.9 → 0.15..0.45
			b.home = maxf(0.0, b.home - dt)
			b.lerp = minf(1.0, b.lerp + dt * 3.0)
			b.wait -= dt
			if b.wait <= 0.0 and b.lerp >= 1.0 and b.home <= 0.0:
				b.from = b.perm.duplicate()
				var ai := randi() % (TextKit.PHRASE.length() - 1)
				var bi := ai + 1                             # the whole dial: b = a+1
				var k: int = b.perm[ai]
				b.perm[ai] = b.perm[bi]
				b.perm[bi] = k
				b.lerp = 0.0
				b.wait = randf_range(0.15, 0.45)
		"static_tune":
			# dials: sweep 0.35 → 0.21 · persistence added — clarity is remembered, decays at 0.12
			b.dial += b.dir * dt * 0.21
			if b.dial > 1.3:
				b.dial = 1.3
				b.dir = -1.0
			if b.dial < -0.3:
				b.dial = -0.3
				b.dir = 1.0
			var r: Rect2 = b.rect
			var fx: float = r.position.x + r.size.x * b.dial
			var lay: Array = TextKit.layout(b)
			if b.mem.is_empty():
				for l in lay:
					b.mem.append(0.0)
			for l in lay:
				if l.ch == " ":
					continue
				var k: float = maxf(0.0, 1.0 - absf(l.cx - fx) / (r.size.x * 0.22))
				b.mem[l.i] = maxf(b.mem[l.i] - dt * 0.12, k)  # the ghost: clarity is remembered
		"cipher_wheel":
			# dial: the wheel turns at 7, not 9 — digits, so slower reads better
			var all_done := true
			for i in TextKit.PHRASE.length():
				if TextKit.PHRASE[i] == " ":
					continue
				if b.offs[i] > 0.0:
					all_done = false
					b.offs[i] = maxf(0.0, b.offs[i] - dt * 7.0)
			if all_done:
				b.rest += dt
				if b.rest > 3.2:
					_countdown(b)
		"number_station":
			# dials: digits → morse marks, refreshed at 0.2 · fade runs the word-clock down
			b.fade -= dt
			if b.fade <= 0.0 and b.clear_words > 0:
				b.clear_words = 0                            # the station goes dark again
			b.d_t += dt
			if b.d_t > 0.2:
				b.d_t = 0.0
				b.marks = []
				for i in TextKit.PHRASE.length():
					b.marks.append(randf() < 0.5)
		_:
			Base.tick(b, dt, t)

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	match b.id:
		"decoder":
			TextKit.stage(n, b)
			# dial: the boundary now marks LOST letters — churn amber, not mint
			var lay: Array = TextKit.layout(b)
			for l in lay:
				if l.ch == " ":
					continue
				var gone: bool = l.i < b.fixed
				if gone:
					TextKit.letter(n, b.churn[l.i], Vector2(l.x, l.y), b.base_size, Color(0.9, 0.67, 0.59, 0.75))
				else:
					TextKit.letter(n, l.ch, Vector2(l.x, l.y), b.base_size, TextKit.INK)
		"slot_machine":
			TextKit.stage(n, b)
			# dials: reel tint blue → gold · a payout flash added ("lighter" → TextKit.glow, layered)
			var lay: Array = TextKit.layout(b)
			var lh: float = b.base_size * 1.08
			for l in lay:
				if l.ch == " ":
					continue
				var rl: Dictionary = b.reels[l.i]
				if rl.done:
					TextKit.letter(n, l.ch, Vector2(l.x, l.y), b.base_size, TextKit.INK)
				else:
					var off: float = rl.off
					var frac := fmod(off, 1.0)
					for k in range(-1, 2):
						var gi: int = (int(off) + k + TextKit.GLYPHS.length() * 4) % TextKit.GLYPHS.length()
						var dy: float = (k - frac) * lh
						# no draw-clip in Godot: the strip fades toward the cell edges (see Base)
						var a: float = (0.75 - absf(k - frac) * 0.3) * (1.0 - clampf(absf(dy) / (lh * 1.2), 0.0, 1.0))
						if a > 0.0:
							TextKit.letter(n, TextKit.GLYPHS[gi], Vector2(l.x, l.y + dy), b.base_size,
								Color(1.0, 0.84, 0.55, a))
			if b.flash > 0.0:
				var r: Rect2 = b.rect
				TextKit.glow(n, Vector2(r.get_center().x, b.mid - b.base_size * 0.3),
					b.base_size * 4.0 * (1.4 - b.flash), Color(1.0, 0.84, 0.47, b.flash * 0.4), 4)
		"jumble_home":
			TextKit.stage(n, b)
			# dial: e eases home as thrown decays; before any press, the letters just sit
			var lay: Array = TextKit.layout(b)
			var thrown: float = b.thrown
			var e := 1.0 - thrown * thrown
			for l in lay:
				if b.pts.is_empty():
					TextKit.letter(n, l.ch, Vector2(l.x, l.y), b.base_size, TextKit.INK)
				else:
					var s: Dictionary = b.pts[l.i]
					var x: float = s.x + (l.cx - s.x) * e
					var y: float = s.y + (l.y - s.y) * e
					n.draw_set_transform(Vector2(x, y), s.r * (1.0 - e), Vector2.ONE)
					TextKit.letter(n, l.ch, Vector2(-l.w / 2.0, 0.0), b.base_size, TextKit.INK)
					n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"matrix_rain":
			TextKit.stage(n, b)
			# dials: palette green → pink · trail glyph below, not above · resolve softer, no flicker
			var r: Rect2 = b.rect
			for d in b.drops:
				if d.y > r.position.y + 10.0 and d.y < r.end.y:
					TextKit.letter(n, TextKit.scramble(), Vector2(d.x, d.y), 12.0, Color(1.0, 0.59, 0.75, 0.3))
				if d.y + 14.0 > r.position.y + 10.0 and d.y + 14.0 < r.end.y:
					TextKit.letter(n, TextKit.scramble(), Vector2(d.x, d.y + 14.0), 12.0, Color(1.0, 0.78, 0.86, 0.45))
			var lay: Array = TextKit.layout(b)
			for l in lay:
				if l.ch == " ":
					continue
				var k: float = clampf((b.resolve - 1.0 - l.i * 0.18) / 1.2, 0.0, 1.0)
				if k <= 0.0:
					continue
				# no flicker: blossoms open once
				TextKit.letter_weight(n, l.ch, Vector2(l.x, l.y), b.base_size, Color(1.0, 0.88, 0.92, k), 500.0)
		"anagram_walk":
			TextKit.stage(n, b)
			# dial: the travel arc lowered 0.5 → 0.22 — neighbours barely hop
			var lay: Array = TextKit.layout(b)
			var e: float = b.lerp * b.lerp * (3.0 - 2.0 * b.lerp)
			var col: Color = Color(0.71, 0.94, 0.78) if b.home > 0.0 else TextKit.INK
			for l in lay:
				var slot_now: int = l.i if b.home > 0.0 else b.perm[l.i]
				var slot_was: int = b.from[l.i]
				var x: float = lay[slot_was].cx + (lay[slot_now].cx - lay[slot_was].cx) * e
				var arc: float = sin(e * PI) * (0.0 if slot_now == slot_was else b.base_size * 0.22)
				n.draw_set_transform(Vector2(x, l.y - arc), 0.0, Vector2.ONE)
				TextKit.letter(n, l.ch, Vector2(-l.w / 2.0, 0.0), b.base_size, col)
				n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"static_tune":
			TextKit.stage(n, b)
			# dials: clarity read from mem, not the dial · clear threshold 0.9 → 0.7
			var r: Rect2 = b.rect
			var fx: float = r.position.x + r.size.x * b.dial
			var lay: Array = TextKit.layout(b)
			for l in lay:
				if l.ch == " ":
					continue
				var c: float = 0.0 if b.mem.is_empty() else b.mem[l.i]
				var clear := c > randf() * 0.7
				var col := Color(0.91, 0.9, 0.96, 0.3 + c * 0.7) if clear else Color(0.59, 0.57, 0.75, 0.4)
				TextKit.letter(n, l.ch if clear else TextKit.scramble(),
					Vector2(l.x, l.y + (1.0 - c) * randf_range(-1.5, 1.5)), b.base_size, col)
			n.draw_rect(Rect2(Vector2(fx - 1.0, b.mid + b.base_size * 0.5), Vector2(2.0, b.base_size * 0.3)),
				Color(0.71, 0.86, 1.0, 0.5))
		"cipher_wheel":
			TextKit.stage(n, b)
			# dial: alphabet wheel → digits — the slot shows c % 10 until it lands
			var lay: Array = TextKit.layout(b)
			for l in lay:
				if l.ch == " ":
					continue
				var c: int = int(ceil(b.offs[l.i]))
				if c > 0:
					TextKit.letter(n, str(c % 10), Vector2(l.x, l.y), b.base_size, Color(0.9, 0.78, 0.59, 0.75))
				else:
					TextKit.letter(n, l.ch, Vector2(l.x, l.y), b.base_size, TextKit.INK)
		"number_station":
			TextKit.stage(n, b)
			# dials: digits → morse marks · the label reads decoding/traffic, not signal/numbers
			var r: Rect2 = b.rect
			var lay: Array = TextKit.layout(b)
			for l in lay:
				if l.ch == " ":
					continue
				var wi := 0
				for s in range(1, b.starts.size()):
					if l.i >= b.starts[s]:
						wi = s
				if wi < b.clear_words:
					TextKit.letter(n, l.ch, Vector2(l.x, l.y), b.base_size, Color(0.78, 0.92, 1.0, 0.95))
				elif b.marks[l.i]:
					n.draw_rect(Rect2(Vector2(l.cx - 4.0, l.y - b.base_size * 0.3), Vector2(8.0, 2.0)),
						Color(0.55, 0.67, 0.78, 0.7))        # dash
				else:
					n.draw_rect(Rect2(Vector2(l.cx - 1.5, l.y - b.base_size * 0.3), Vector2(3.0, 3.0)),
						Color(0.55, 0.67, 0.78, 0.7))        # dot
			TextKit.letter(n, "— decoding —" if b.clear_words > 0 else "— traffic —",
				r.position + Vector2(8.0, 14.0), 10.0, Color(0.55, 0.67, 0.78, 0.35))
		_:
			Base.draw(n, b, t)
