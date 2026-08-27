extends RefCounted

const TextKit := preload("res://scenes/textfx/kit.gd")
## SCRAMBLES & DECODES — eight text effects, ported from the web grimoire.

const TITLE := "Scrambles & decodes"
const BLURB := "wrong letters on their way to right ones"
const AL := "abcdefghijklmnopqrstuvwxyz"
const DEFS := [
	{ "id": "decoder", "name": "Decoder", "hint": "a1h7 8u3d — random letters churn, resolving one by one into the phrase" },
	{ "id": "slot_machine", "name": "Slot machine", "hint": "each column scrolls a strip of glyphs, stopping left to right on the right one" },
	{ "id": "jumble_home", "name": "Jumble home", "hint": "the right letters in the wrong places drift home to correct placement" },
	{ "id": "matrix_rain", "name": "Matrix rain", "hint": "glyph rain falls; the phrase crystallizes out of the downpour" },
	{ "id": "anagram_walk", "name": "Anagram walk", "hint": "the letters keep trading places — press to send them all home" },
	{ "id": "static_tune", "name": "Static tune", "hint": "tuning a radio: a dial sweeps, and where it points, noise becomes words" },
	{ "id": "cipher_wheel", "name": "Cipher wheel", "hint": "every letter steps through the alphabet until it lands on the right one" },
	{ "id": "number_station", "name": "Number station", "hint": "cold digits cycle in every slot; press, and the words come through" },
]

static func _spin_up(b: Dictionary) -> void:
	b.reels = []
	for i in TextKit.PHRASE.length():
		b.reels.append({ "v": randf_range(14.0, 20.0), "off": randf_range(0.0, float(TextKit.GLYPHS.length())),
			"stop_at": 0.8 + i * 0.28, "done": false })
	b.spin_t = 0.0
	b.rest = 0.0

static func _scatter(b: Dictionary) -> void:
	var r: Rect2 = b.rect
	b.pts = []
	for i in TextKit.PHRASE.length():
		b.pts.append({ "x": r.position.x + randf_range(r.size.x * 0.08, r.size.x * 0.85),
			"y": r.position.y + randf_range(r.size.y * 0.15, r.size.y * 0.85),
			"r": randf_range(-1.5, 1.5) })
	b.going = 0.0
	b.rest = 0.0

static func _wheel(b: Dictionary) -> void:
	b.offs = []
	for i in TextKit.PHRASE.length():
		b.offs.append(floorf(randf_range(6.0, 22.0)))    # steps still to walk
	b.rest = 0.0

static func init(b: Dictionary) -> void:
	match b.id:
		"decoder":
			# the churn is honest randomness; the resolve is just an index that grows
			b.fixed = 0
			b.timer = 0.0
			b.churn_t = 0.0
			b.rest = 0.0
			b.churn = []
			for i in TextKit.PHRASE.length():
				b.churn.append(TextKit.scramble())
		"slot_machine":
			_spin_up(b)
		"jumble_home":
			_scatter(b)
		"matrix_rain":
			b.resolve = 0.0
			b.drops = []
			var r: Rect2 = b.rect
			for i in int(r.size.x / 12.0):
				b.drops.append({ "x": r.position.x + 6.0 + i * 12.0,
					"y": r.position.y + randf_range(-r.size.y, r.size.y), "v": randf_range(40.0, 110.0) })
		"anagram_walk":
			b.perm = range(TextKit.PHRASE.length())
			b.from = range(TextKit.PHRASE.length())
			b.lerp = 1.0
			b.wait = 0.5
			b.home = 0.0
		"static_tune":
			b.dial = 0.0
			b.dir = 1.0
		"cipher_wheel":
			_wheel(b)
		"number_station":
			b.clear = 0.0
			b.d_t = 0.0
			b.digits = []
			for i in TextKit.PHRASE.length():
				b.digits.append(randi() % 10)

static func press(b: Dictionary, _pos: Vector2) -> void:
	match b.id:
		"decoder":
			b.fixed = 0
			b.rest = 0.0
		"slot_machine":
			_spin_up(b)
		"jumble_home":
			_scatter(b)
		"matrix_rain":
			b.resolve = 0.0            # dissolve back into the rain, then re-crystallize
		"anagram_walk":
			b.home = 3.0               # three seconds of correct spelling, as a treat
		"static_tune":
			b.dir = -b.dir             # sweep back the other way
		"cipher_wheel":
			_wheel(b)
		"number_station":
			b.clear = 4.0              # the signal, briefly, means something

static func tick(b: Dictionary, dt: float, t: float) -> void:
	match b.id:
		"decoder":
			b.churn_t += dt
			if b.churn_t > 0.05:       # refresh the wrong letters at 20fps — readable churn
				b.churn_t = 0.0
				b.churn = []
				for i in TextKit.PHRASE.length():
					b.churn.append(TextKit.scramble())
			if b.fixed < TextKit.PHRASE.length():
				b.timer += dt
				if b.timer > 0.22:
					b.timer = 0.0
					b.fixed += 1
			else:
				b.rest += dt
				if b.rest > 3.2:
					b.rest = 0.0
					b.fixed = 0
		"slot_machine":
			b.spin_t += dt
			var all_done := true
			for i in TextKit.PHRASE.length():
				if TextKit.PHRASE[i] == " ":
					continue
				var rl: Dictionary = b.reels[i]
				if not rl.done:
					if b.spin_t > rl.stop_at:            # the brake
						rl.v = maxf(0.0, rl.v - dt * 30.0)
					rl.off += rl.v * dt
					if b.spin_t > rl.stop_at and rl.v < 0.8:
						rl.done = true
						rl.off = 0.0
				if not rl.done:
					all_done = false
			if all_done:
				b.rest += dt
				if b.rest > 3.0:
					_spin_up(b)
		"jumble_home":
			b.going += dt
			var p: float = clampf((b.going - 0.7) / 1.6, 0.0, 1.0)
			if p >= 1.0:
				b.rest += dt
				if b.rest > 3.0:
					_scatter(b)
		"matrix_rain":
			b.resolve += dt
			var r: Rect2 = b.rect
			for d in b.drops:          # the rain never stops; the phrase just outshines it
				d.y += d.v * dt
				if d.y > r.end.y + 20.0:
					d.y = r.position.y + randf_range(-40.0, -10.0)
					d.v = randf_range(40.0, 110.0)
			if b.resolve > 9.0:
				b.resolve = 0.0
		"anagram_walk":
			b.home = maxf(0.0, b.home - dt)
			b.lerp = minf(1.0, b.lerp + dt * 1.6)
			b.wait -= dt
			if b.wait <= 0.0 and b.lerp >= 1.0 and b.home <= 0.0:
				b.from = b.perm.duplicate()
				var ai := randi() % TextKit.PHRASE.length()      # pick two letters and swap their slots
				var bi := randi() % TextKit.PHRASE.length()
				var k: int = b.perm[ai]
				b.perm[ai] = b.perm[bi]
				b.perm[bi] = k
				b.lerp = 0.0
				b.wait = randf_range(0.3, 0.9)
		"static_tune":
			b.dial += b.dir * dt * 0.35
			if b.dial > 1.3:
				b.dial = 1.3
				b.dir = -1.0
			if b.dial < -0.3:
				b.dial = -0.3
				b.dir = 1.0
		"cipher_wheel":
			var all_done := true
			for i in TextKit.PHRASE.length():
				if TextKit.PHRASE[i] == " ":
					continue
				if b.offs[i] > 0.0:
					all_done = false
					b.offs[i] = maxf(0.0, b.offs[i] - dt * 9.0)  # the wheel turns…
			if all_done:
				b.rest += dt
				if b.rest > 3.2:
					_wheel(b)
		"number_station":
			b.clear = maxf(0.0, b.clear - dt)
			b.d_t += dt
			if b.d_t > 0.14:
				b.d_t = 0.0
				b.digits = []
				for i in TextKit.PHRASE.length():
					b.digits.append(randi() % 10)

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	TextKit.stage(n, b)
	match b.id:
		"decoder":
			var lay: Array = TextKit.layout(b)
			for l in lay:
				if l.ch == " ":
					continue
				var done: bool = l.i < b.fixed
				if done:
					TextKit.letter(n, l.ch, Vector2(l.x, l.y), b.base_size, TextKit.INK)
				else:
					TextKit.letter(n, b.churn[l.i], Vector2(l.x, l.y), b.base_size, Color(0.59, 0.86, 0.71, 0.75))
		"slot_machine":
			# the web version clipped each column to its own little window; a
			# CanvasItem has no draw-clip, so the three passing glyphs fade
			# toward the cell edges instead of being cut off by one
			var lay: Array = TextKit.layout(b)
			var lh: float = b.base_size * 1.08               # the strip's line height
			for l in lay:
				if l.ch == " ":
					continue
				var rl: Dictionary = b.reels[l.i]
				if rl.done:
					TextKit.letter(n, l.ch, Vector2(l.x, l.y), b.base_size, TextKit.INK)
				else:
					var off: float = rl.off
					var frac := fmod(off, 1.0)
					for k in range(-1, 2):                   # three glyphs of the passing strip
						var gi: int = (int(off) + k + TextKit.GLYPHS.length() * 4) % TextKit.GLYPHS.length()
						var dy: float = (k - frac) * lh
						var a: float = (0.75 - absf(k - frac) * 0.3) * (1.0 - clampf(absf(dy) / (lh * 1.2), 0.0, 1.0))
						if a > 0.0:
							TextKit.letter(n, TextKit.GLYPHS[gi], Vector2(l.x, l.y + dy), b.base_size,
								Color(0.71, 0.86, 1.0, a))
		"jumble_home":
			var lay: Array = TextKit.layout(b)
			var p: float = clampf((b.going - 0.7) / 1.6, 0.0, 1.0)   # a beat of pure jumble first
			var e := p * p * (3.0 - 2.0 * p)
			for l in lay:
				var s: Dictionary = b.pts[l.i]
				var x: float = s.x + (l.cx - s.x) * e
				var y: float = s.y + (l.y - s.y) * e
				n.draw_set_transform(Vector2(x, y), s.r * (1.0 - e), Vector2.ONE)   # they also un-tilt as they arrive
				TextKit.letter(n, l.ch, Vector2(-l.w / 2.0, 0.0), b.base_size, TextKit.INK)
				n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"matrix_rain":
			var r: Rect2 = b.rect
			for d in b.drops:
				# the web canvas clipped at its own edges; the card shares the
				# scene, so rain outside b.rect is simply not drawn
				if d.y > r.position.y + 10.0 and d.y < r.end.y:
					TextKit.letter(n, TextKit.scramble(), Vector2(d.x, d.y), 12.0, Color(0.35, 0.78, 0.47, 0.35))
				if d.y - 14.0 > r.position.y + 10.0 and d.y - 14.0 < r.end.y:
					TextKit.letter(n, TextKit.scramble(), Vector2(d.x, d.y - 14.0), 12.0, Color(0.63, 1.0, 0.75, 0.5))
			var lay: Array = TextKit.layout(b)
			for l in lay:
				if l.ch == " ":
					continue
				var k: float = clampf((b.resolve - 1.0 - l.i * 0.18) / 0.8, 0.0, 1.0)
				if k <= 0.0:
					continue
				var ch: String = TextKit.scramble() if k < 1.0 and randf() < 0.3 else l.ch
				TextKit.letter_weight(n, ch, Vector2(l.x, l.y), b.base_size, Color(0.78, 1.0, 0.84, k), 500.0)
		"anagram_walk":
			var lay: Array = TextKit.layout(b)
			var e: float = b.lerp * b.lerp * (3.0 - 2.0 * b.lerp)
			var col: Color = Color(0.71, 0.94, 0.78) if b.home > 0.0 else TextKit.INK
			for l in lay:
				var slot_now: int = l.i if b.home > 0.0 else b.perm[l.i]
				var slot_was: int = b.from[l.i]
				var x: float = lay[slot_was].cx + (lay[slot_now].cx - lay[slot_was].cx) * e
				var arc: float = sin(e * PI) * (0.0 if slot_now == slot_was else b.base_size * 0.5)
				n.draw_set_transform(Vector2(x, l.y - arc), 0.0, Vector2.ONE)   # swaps travel over the line, politely
				TextKit.letter(n, l.ch, Vector2(-l.w / 2.0, 0.0), b.base_size, col)
				n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"static_tune":
			var r: Rect2 = b.rect
			var fx: float = r.position.x + r.size.x * b.dial     # the tuned spot
			var lay: Array = TextKit.layout(b)
			for l in lay:
				if l.ch == " ":
					continue
				var k: float = maxf(0.0, 1.0 - absf(l.cx - fx) / (r.size.x * 0.22))   # clarity near the dial
				var clear := k > randf() * 0.9
				var col := Color(0.91, 0.9, 0.96, 0.3 + k * 0.7) if clear else Color(0.59, 0.57, 0.75, 0.4)
				var jitter := (1.0 - k) * randf_range(-1.5, 1.5)
				TextKit.letter(n, l.ch if clear else TextKit.scramble(), Vector2(l.x, l.y + jitter), b.base_size, col)
			n.draw_rect(Rect2(Vector2(fx - 1.0, b.mid + b.base_size * 0.5), Vector2(2.0, b.base_size * 0.3)),
				Color(0.71, 0.86, 1.0, 0.5))                     # the dial's needle, below the line
		"cipher_wheel":
			var lay: Array = TextKit.layout(b)
			for l in lay:
				if l.ch == " ":
					continue
				var idx: int = AL.find(l.ch)
				var steps_left: int = int(ceil(b.offs[l.i]))
				var show_idx: int = 0 if idx < 0 else (idx - steps_left + AL.length() * 4) % AL.length()
				var settled := steps_left == 0
				var col: Color = TextKit.INK if settled else Color(0.9, 0.78, 0.59, 0.75)
				TextKit.letter(n, l.ch if idx < 0 else AL[show_idx], Vector2(l.x, l.y), b.base_size, col)
		"number_station":
			var r: Rect2 = b.rect
			var lay: Array = TextKit.layout(b)
			for l in lay:
				if l.ch == " ":
					continue
				if b.clear > 0.4 or (b.clear > 0.0 and randf() < 0.7):
					TextKit.letter(n, l.ch, Vector2(l.x, l.y), b.base_size, Color(0.78, 0.92, 1.0, 0.95))
				else:
					TextKit.letter(n, str(b.digits[l.i]), Vector2(l.x, l.y), b.base_size, Color(0.55, 0.67, 0.78, 0.6))
			TextKit.letter(n, "— signal —" if b.clear > 0.0 else "— numbers —",
				r.position + Vector2(8.0, 14.0), 10.0, Color(0.55, 0.67, 0.78, 0.35))
