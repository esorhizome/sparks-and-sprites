extends RefCounted

const TextKit := preload("res://scenes/textfx/kit.gd")
const Base := preload("res://scenes/textfx/type.gd")
## TYPEWRITERS — the rhymes. Dials named per branch; the rest delegates.

const RHYMES := {
	"typewriter": { "name": "Heavy typewriter", "hint": "the same machine with weight behind it — slower, bold, each letter lands with a stamp" },
	"hesitant_typist": { "name": "Confident typist", "hint": "no hesitation at all — a steady clip and a proud underline flourish at the end" },
	"backspace_correct": { "name": "Overtype", "hint": "no backspace on this machine — mistakes stay, struck through, corrected above" },
	"word_by_word": { "name": "Line by line", "hint": "coarser grain — the phrase arrives as two half-lines, each sliding up as a block" },
	"teletype": { "name": "Telegraph", "hint": "dots and dashes tick in above each letter before it resolves — the jolt halved" },
	"dialogue_box": { "name": "Villain dialogue", "hint": "the same box gone wrong — red trim, trembling letters, and no hurrying it" },
	"two_hands": { "name": "The race", "hint": "the two ends type at different speeds — the meeting point lands somewhere new each run" },
	"dictation": { "name": "Redaction", "hint": "inverted — the phrase starts as black bars, and the sweep un-redacts it" },
}

static func init(b: Dictionary) -> void:
	Base.init(b)
	match b.id:
		"typewriter":
			b.punch = 0.0
		"hesitant_typist":
			b.flourish = 0.0
		"backspace_correct":
			b.typed = []                   # {ch, bad} pairs — this machine keeps its mistakes
		"word_by_word":
			b.clock = 0.0
			b.split = TextKit.PHRASE.find(" ") + 1   # everything before/after the first space
		"two_hands":
			b.left = 0
			b.right = 0
			b.l_wait = 0.0
			b.r_wait = 0.0
			b.speeds = {}                  # rolled lazily; empty = re-roll next tick

static func press(b: Dictionary, pos: Vector2) -> void:
	match b.id:
		"hesitant_typist":
			# dial: reset also clears the flourish
			b.shown = 0
			b.wait = 0.15
			b.flourish = 0.0
		"backspace_correct":
			# dial: typed is a list of kept letters, not an erasable string
			b.typed = []
			b.rest = 0.0
			b.wait = 0.2
		"word_by_word":
			# dial: one clock drives both half-lines
			b.clock = 0.0
		"dialogue_box":
			# dial: fast-forward disabled (the villain talks at their own pace)
			if b.progress >= TextKit.PHRASE.length():
				b.progress = 0.0
				b.rest = 0.0
		"two_hands":
			# dial: the speeds re-roll each run
			b.left = 0
			b.right = 0
			b.speeds = {}
			b.rest = 0.0
		_:
			Base.press(b, pos)

static func tick(b: Dictionary, dt: float, t: float) -> void:
	var n := TextKit.PHRASE.length()
	match b.id:
		"typewriter":
			# dials: cadence 0.12s → 0.22s · each arrival punches the frame
			b.punch = maxf(0.0, b.punch - dt * 8.0)
			if b.shown < n:
				b.timer += dt
				if b.timer > 0.22:
					b.timer = 0.0
					b.shown += 1
					b.punch = 1.0
			else:
				b.rest += dt
				if b.rest > 3.5:
					b.rest = 0.0
					b.shown = 0
		"hesitant_typist":
			# dials: delays flattened to one fast beat · the dithering removed · a flourish at the end
			b.wait -= dt
			if b.wait <= 0.0:
				if b.shown < n:
					b.shown += 1
					b.wait = 0.06
					if b.shown == n:
						b.flourish = 0.001
						b.wait = 3.5
				else:
					b.shown = 0
					b.flourish = 0.0
					b.wait = 0.15
			if b.flourish > 0.0:
				b.flourish = minf(1.0, b.flourish + dt * 2.5)
		"backspace_correct":
			# dial: correction policy — the error is kept (struck + small fix above) instead of erased
			b.wait -= dt
			if b.wait <= 0.0:
				if b.typed.size() < n:
					var bad: bool = randf() < 0.18 and TextKit.PHRASE[b.typed.size()] != " "
					b.typed.append({ "ch": TextKit.scramble() if bad else TextKit.PHRASE[b.typed.size()], "bad": bad })
					b.wait = randf_range(0.07, 0.18)
				else:
					b.rest += dt
					if b.rest > 3.2:
						b.typed = []
						b.rest = 0.0
					b.wait = 0.1
		"word_by_word":
			# dial: granularity word → half-phrase (one clock, no pop timer)
			b.clock += dt
			if b.clock > 6.0:
				b.clock = 0.0
		"teletype":
			# dials: jolt ×0.5 · cadence slightly uneven (threshold re-rolled against each frame)
			b.jolt = maxf(0.0, b.jolt - dt * 6.0)
			if b.shown < n:
				b.timer += dt
				if b.timer > randf_range(0.14, 0.2):
					b.timer = 0.0
					b.shown += 1
					b.jolt = 0.5
			else:
				b.rest += dt
				if b.rest > 3.0:
					b.rest = 0.0
					b.shown = 0
		"dialogue_box":
			# dial: fill speed 9 → 6, and no fast lane — slower, and it will not be rushed
			if b.progress < n:
				b.progress += dt * 6.0
			else:
				b.rest += dt
				if b.rest > 4.0:
					b.rest = 0.0
					b.progress = 0.0
		"two_hands":
			# dial: symmetric cadence → independent speeds per side, re-rolled each run
			if b.speeds.is_empty():
				b.speeds = { "l": randf_range(0.08, 0.2), "r": randf_range(0.08, 0.2) }
			if b.left + b.right < n:
				b.l_wait -= dt
				b.r_wait -= dt
				if b.l_wait <= 0.0 and b.left + b.right < n:
					b.left += 1
					b.l_wait = b.speeds.l
				if b.r_wait <= 0.0 and b.left + b.right < n:
					b.right += 1
					b.r_wait = b.speeds.r
			else:
				b.rest += dt
				if b.rest > 3.2:
					b.left = 0
					b.right = 0
					b.speeds = {}
					b.rest = 0.0
		"dictation":
			# dials: sweep steady, not bursty · reveal replaces conceal
			if b.sweep < n:
				b.sweep += dt * 3.2
			else:
				b.rest += dt
				if b.rest > 3.4:
					b.sweep = 0.0
					b.rest = 0.0
		_:
			Base.tick(b, dt, t)

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	var bs: float = b.base_size
	match b.id:
		"typewriter":
			TextKit.stage(n, b)
			# dials: weight 400 → 700 (fake bold via letter_weight) · the whole page takes the hit
			var L := TextKit.layout(b)
			var pv: float = b.punch
			var off := Vector2(randf_range(-1.0, 1.0) * pv * 1.5, pv * 2.0)
			for l in L:
				if l.i >= b.shown:
					continue
				var fresh: float = pv if l.i == b.shown - 1 else 0.0
				var s := 1.0 + fresh * 0.25            # the stamp, mid-landing
				# canvas nested save/translate/scale → one composed transform per letter
				n.draw_set_transform(Vector2(l.cx, l.y) + off, 0.0, Vector2(s, s))
				TextKit.letter_weight(n, l.ch, Vector2(-l.w / 2.0, 0.0), bs, TextKit.INK, 700.0)
				n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			if sin(t * 7.0) > -0.2:
				var last: Dictionary = L[L.size() - 1]
				var cx: float = L[b.shown].x if b.shown < L.size() else last.x + last.w + 2.0
				n.draw_rect(Rect2(cx + off.x, L[0].y - bs * 0.72 + off.y, bs * 0.5, bs * 0.82), TextKit.INK)
		"hesitant_typist":
			TextKit.stage(n, b)
			# dials: no dithering caret · the underline, drawn like a signature
			var L := TextKit.layout(b)
			for l in L:
				if l.i < b.shown:
					TextKit.letter(n, l.ch, Vector2(l.x, l.y), bs, TextKit.INK)
			if b.flourish > 0.0:
				var last: Dictionary = L[L.size() - 1]
				var x0: float = L[0].x
				var x1: float = last.x + last.w
				var f: float = b.flourish
				n.draw_line(Vector2(x0, L[0].y + 7.0),
					Vector2(x0 + (x1 - x0) * f, L[0].y + 7.0 + sin(f * 7.0) * 2.0),
					Color(0.706, 0.824, 1.0, 0.9), 2.0)
		"backspace_correct":
			TextKit.stage(n, b)
			# dial: the strike, and the correction squeezed in above
			var L := TextKit.layout(b)
			for i in b.typed.size():
				var l: Dictionary = L[i]
				var e: Dictionary = b.typed[i]
				var col: Color = Color(0.91, 0.898, 0.957, 0.5) if e.bad else TextKit.INK
				TextKit.letter(n, e.ch, Vector2(l.x, l.y), bs, col)
				if e.bad:
					n.draw_line(Vector2(l.x - 1.0, l.y - bs * 0.26),
						Vector2(l.x + l.w + 1.0, l.y - bs * 0.3),
						Color(0.902, 0.588, 0.588, 0.9), 1.5)
					TextKit.letter(n, TextKit.PHRASE[i], Vector2(l.cx - l.w * 0.25, l.y - bs * 0.75),
						bs * 0.55, TextKit.INK)
			if sin(t * 7.0) > -0.2 and b.typed.size() < L.size():
				n.draw_rect(Rect2(L[b.typed.size()].x, L[0].y - bs * 0.72, bs * 0.5, bs * 0.82), TextKit.INK)
		"word_by_word":
			TextKit.stage(n, b)
			# dials: arrivals slide up instead of popping · alpha rides the ease
			var L := TextKit.layout(b)
			for l in L:
				var half := 0 if l.i < b.split else 1
				var p: float = clampf((b.clock - 0.3 - half * 1.1) / 0.7, 0.0, 1.0)
				if p <= 0.0:
					continue
				var e := 1.0 - pow(1.0 - p, 3.0)
				TextKit.letter(n, l.ch, Vector2(l.x, l.y + (1.0 - e) * bs * 0.9), bs,
					Color(TextKit.INK.r, TextKit.INK.g, TextKit.INK.b, e))
		"teletype":
			TextKit.stage(n, b)
			# dials: a morse tick precedes each arrival · the kick roughly halved
			var L := TextKit.layout(b)
			var off := Vector2(randf_range(-1.0, 1.0) * b.jolt * 1.2, randf_range(-1.0, 1.0) * b.jolt * 0.7)
			n.draw_set_transform(off, 0.0, Vector2.ONE)
			for l in L:
				if l.i < b.shown:
					TextKit.letter_weight(n, l.ch, Vector2(l.x, l.y), bs, TextKit.INK, 600.0)
			if b.shown < L.size():             # the incoming code: dot or dash, by parity
				var l2: Dictionary = L[b.shown]
				var code := Color(0.706, 0.863, 1.0, 0.9)
				if l2.i % 2 == 1:
					n.draw_rect(Rect2(l2.cx - 4.0, l2.y - bs * 1.05, 8.0, 2.0), code)   # dash
				else:
					n.draw_rect(Rect2(l2.cx - 1.5, l2.y - bs * 1.05, 3.0, 3.0), code)   # dot
			n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"dialogue_box":
			TextKit.stage(n, b)
			# dials: palette → red · letters tremble as they sit · blink ×2
			var L := TextKit.layout(b, bs * 0.85)
			var r: Rect2 = b.rect
			var bx: float = r.position.x + r.size.x * 0.06
			var by: float = b.mid - bs * 1.1
			var bw: float = r.size.x * 0.88
			var bh: float = bs * 1.9
			n.draw_rect(Rect2(bx, by, bw, bh), Color(0.118, 0.039, 0.063, 0.9))
			n.draw_rect(Rect2(bx, by, bw, bh), Color(0.922, 0.353, 0.353, 0.8), false, 1.5)
			for l in L:
				if l.i < b.progress:
					TextKit.letter(n, l.ch,
						Vector2(l.x + randf_range(-0.7, 0.7), l.y + randf_range(-0.7, 0.7)),
						bs * 0.85, Color(0.949, 0.784, 0.784))
			if b.progress >= L.size() and sin(t * 8.0) > 0.0:
				n.draw_colored_polygon(PackedVector2Array([
					Vector2(bx + bw - 16.0, by + bh - 12.0),
					Vector2(bx + bw - 8.0, by + bh - 12.0),
					Vector2(bx + bw - 12.0, by + bh - 6.0)]), Color(0.922, 0.353, 0.353, 0.9))
		"two_hands":
			TextKit.stage(n, b)
			# dial: the faster hand's caret glows brighter
			var L := TextKit.layout(b)
			var total := L.size()
			for l in L:
				if l.i < b.left or l.i >= total - b.right:
					TextKit.letter(n, l.ch, Vector2(l.x, l.y), bs, TextKit.INK)
			if b.left + b.right < total and sin(t * 7.0) > -0.2 and not b.speeds.is_empty():
				var dim := Color(0.91, 0.898, 0.957, 0.5)
				n.draw_rect(Rect2(L[b.left].x, L[0].y - bs * 0.72, bs * 0.45, bs * 0.82),
					TextKit.INK if b.speeds.l <= b.speeds.r else dim)
				var rr: Dictionary = L[total - 1 - b.right]
				n.draw_rect(Rect2(rr.x + rr.w - bs * 0.45, rr.y - bs * 0.72, bs * 0.45, bs * 0.82),
					TextKit.INK if b.speeds.r < b.speeds.l else dim)
		"dictation":
			TextKit.stage(n, b)
			# dials: underline → covering bar · the sweep un-redacts
			var L := TextKit.layout(b)
			for l in L:
				if l.ch == " ":
					continue
				if l.i < b.sweep:
					TextKit.letter(n, l.ch, Vector2(l.x, l.y), bs, TextKit.INK)
				else:                          # still classified
					n.draw_rect(Rect2(l.x - 1.0, l.y - bs * 0.68, l.w + 2.0, bs * 0.78),
						Color(0.157, 0.141, 0.259, 0.95))
		_:
			Base.draw(n, b, t)
