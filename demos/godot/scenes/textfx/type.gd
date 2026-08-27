extends RefCounted

const TextKit := preload("res://scenes/textfx/kit.gd")
## TYPEWRITERS — eight text effects, ported from the web grimoire.

const TITLE := "Typewriters"
const BLURB := "letter by letter, in all the typist's moods"
const DEFS := [
	{ "id": "typewriter", "name": "Typewriter", "hint": "letter by letter, block caret and all — press to retype" },
	{ "id": "hesitant_typist", "name": "Hesitant typist", "hint": "types unevenly — thinks before words, hovers mid-phrase" },
	{ "id": "backspace_correct", "name": "Backspace & correct", "hint": "types a wrong letter now and then, notices, backspaces, fixes it" },
	{ "id": "word_by_word", "name": "Word by word", "hint": "whole words appear at a time, each with a small settle" },
	{ "id": "teletype", "name": "Teletype", "hint": "each letter slams in and jolts the whole line — newsroom urgency" },
	{ "id": "dialogue_box", "name": "Dialogue box", "hint": "an RPG text box fills slowly — press to fast-forward, like every player ever" },
	{ "id": "two_hands", "name": "Two hands", "hint": "typed from both ends at once, meeting in the middle" },
	{ "id": "dictation", "name": "Dictation", "hint": "an underline sweeps ahead and the letters catch up in little bursts" },
]

static func init(b: Dictionary) -> void:
	match b.id:
		"typewriter":
			# the classic: an integer count of visible letters, advanced on a timer
			b.shown = 0
			b.timer = 0.0
			b.rest = 0.0
		"hesitant_typist":
			b.shown = 0
			b.wait = 0.3
		"backspace_correct":
			b.typed = ""
			b.wrong = false
			b.wait = 0.3
			b.rest = 0.0
		"word_by_word":
			# word starts, computed as the JS does: index 0 plus one past each space
			var starts: Array = [0]
			for i in TextKit.PHRASE.length():
				if TextKit.PHRASE[i] == " ":
					starts.append(i + 1)
			b.starts = starts
			b.shown = 0
			b.timer = 0.0
			b.pop = 0.0
		"teletype":
			b.shown = 0
			b.timer = 0.0
			b.jolt = 0.0
			b.rest = 0.0
		"dialogue_box":
			b.progress = 0.0
			b.fast = false
			b.rest = 0.0
		"two_hands":
			b.steps = 0
			b.timer = 0.0
			b.rest = 0.0
		"dictation":
			b.sweep = 0.0
			b.shown = 0
			b.burst = 0.0
			b.rest = 0.0

static func press(b: Dictionary, _pos: Vector2) -> void:
	match b.id:
		"typewriter":
			b.shown = 0
			b.timer = 0.0
			b.rest = 0.0
		"hesitant_typist":
			b.shown = 0
			b.wait = 0.2
		"backspace_correct":
			b.typed = ""
			b.wrong = false
			b.rest = 0.0
			b.wait = 0.2
		"word_by_word":
			b.shown = 0
			b.timer = 0.0
		"teletype":
			b.shown = 0
			b.rest = 0.0
		"dialogue_box":
			if b.progress < TextKit.PHRASE.length():
				b.fast = true              # first press: hurry
			else:
				b.progress = 0.0           # at the ▼: next page (same page, this being a demo)
				b.fast = false
				b.rest = 0.0
		"two_hands":
			b.steps = 0
			b.rest = 0.0
		"dictation":
			b.sweep = 0.0
			b.shown = 0
			b.rest = 0.0

## The hesitation is all in this one function.
static func _delay_for(i: int) -> float:
	if i >= TextKit.PHRASE.length():
		return 0.0
	if TextKit.PHRASE[i] == " ":
		return randf_range(0.5, 1.1)       # breathe before the next word
	if randf() < 0.15:
		return randf_range(0.4, 0.9)       # …or just lose the thread briefly
	return randf_range(0.05, 0.22)

static func _word_of(starts: Array, i: int) -> int:
	var w := 0
	for s in range(1, starts.size()):
		if i >= int(starts[s]):
			w = s
	return w

static func tick(b: Dictionary, dt: float, _t: float) -> void:
	var n := TextKit.PHRASE.length()
	match b.id:
		"typewriter":
			if b.shown < n:
				b.timer += dt
				if b.timer > 0.12:
					b.timer = 0.0
					b.shown += 1
			else:
				b.rest += dt               # done: sit with it a moment, then retype
				if b.rest > 3.5:
					b.rest = 0.0
					b.shown = 0
		"hesitant_typist":
			b.wait -= dt
			if b.wait <= 0.0:
				if b.shown < n:            # one more letter, then decide how long to dither
					b.shown += 1
					b.wait = 4.0 if b.shown == n else _delay_for(b.shown)
				else:                      # rested long enough — begin again
					b.shown = 0
					b.wait = 0.3
		"backspace_correct":
			b.wait -= dt
			if b.wait <= 0.0:
				if b.wrong:                # the backspace
					b.typed = (b.typed as String).substr(0, b.typed.length() - 1)
					b.wrong = false
					b.wait = 0.22
				elif b.typed.length() < n:
					if randf() < 0.18:     # the slip (and the noticing)
						b.typed += TextKit.scramble()
						b.wrong = true
						b.wait = randf_range(0.3, 0.55)
					else:
						b.typed += TextKit.PHRASE[b.typed.length()]
						b.wait = randf_range(0.07, 0.16)
				else:
					b.rest += dt
					if b.rest > 3.0:
						b.typed = ""
						b.rest = 0.0
					b.wait = 0.1
		"word_by_word":
			b.timer += dt
			b.pop = maxf(0.0, b.pop - dt * 3.0)
			if b.timer > (0.9 if b.shown < b.starts.size() else 3.2):
				b.timer = 0.0
				b.shown = b.shown + 1 if b.shown < b.starts.size() else 0
				b.pop = 1.0
		"teletype":
			b.jolt = maxf(0.0, b.jolt - dt * 6.0)
			if b.shown < n:
				b.timer += dt
				if b.timer > 0.09:
					b.timer = 0.0
					b.shown += 1
					b.jolt = 1.0
			else:
				b.rest += dt
				if b.rest > 3.0:
					b.rest = 0.0
					b.shown = 0
		"dialogue_box":
			if b.progress < n:
				b.progress += dt * (60.0 if b.fast else 9.0)
			else:
				b.rest += dt
				if b.rest > 4.0:
					b.rest = 0.0
					b.progress = 0.0
					b.fast = false
		"two_hands":
			var need := int(ceil(n / 2.0))
			if b.steps < need:
				b.timer += dt
				if b.timer > 0.16:
					b.timer = 0.0
					b.steps += 1
			else:
				b.rest += dt
				if b.rest > 3.2:
					b.rest = 0.0
					b.steps = 0
		"dictation":
			if b.shown >= n:
				b.rest += dt
				if b.rest > 3.0:
					b.rest = 0.0
					b.sweep = 0.0
					b.shown = 0
			else:
				b.sweep = minf(float(n), b.sweep + dt * 6.0)   # the pen runs ahead…
				b.burst -= dt
				if b.burst <= 0.0 and b.shown < int(floor(b.sweep)):
					# …the voice catches up in bursts
					b.shown = mini(int(floor(b.sweep)), b.shown + int(floor(randf_range(1.0, 3.5))))
					b.burst = randf_range(0.2, 0.5)

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	TextKit.stage(n, b)
	var bs: float = b.base_size
	match b.id:
		"typewriter":
			var L := TextKit.layout(b)
			for l in L:
				if l.i < b.shown:
					TextKit.letter(n, l.ch, Vector2(l.x, l.y), bs, TextKit.INK)
			if sin(t * 7.0) > -0.2:        # the caret blinks — a block after the last letter
				var last: Dictionary = L[L.size() - 1]
				var cx: float = L[b.shown].x if b.shown < L.size() else last.x + last.w + 2.0
				n.draw_rect(Rect2(cx, L[0].y - bs * 0.72, bs * 0.5, bs * 0.82), TextKit.INK)
		"hesitant_typist":
			var L := TextKit.layout(b)
			for l in L:
				if l.i < b.shown:
					TextKit.letter(n, l.ch, Vector2(l.x, l.y), bs, TextKit.INK)
			if sin(t * 6.0) > 0.0:
				var last: Dictionary = L[L.size() - 1]
				var cx: float = L[b.shown].x if b.shown < L.size() else last.x + last.w + 2.0
				# a thin underline caret — less sure of itself
				n.draw_rect(Rect2(cx, L[0].y + 3.0, bs * 0.5, 2.0), TextKit.INK)
		"backspace_correct":
			var L := TextKit.layout(b)
			var typed: String = b.typed
			for i in typed.length():
				var bad: bool = b.wrong and i == typed.length() - 1
				var col := Color(0.91, 0.604, 0.604) if bad else TextKit.INK   # #E89A9A for the slip
				TextKit.letter(n, typed[i], Vector2(L[i].x, L[i].y), bs, col)
			if sin(t * 7.0) > -0.2 and typed.length() <= L.size():
				var last: Dictionary = L[L.size() - 1]
				var cx: float = L[typed.length()].x if typed.length() < L.size() else last.x + last.w + 2.0
				n.draw_rect(Rect2(cx, L[0].y - bs * 0.72, bs * 0.5, bs * 0.82), TextKit.INK)
		"word_by_word":
			var L := TextKit.layout(b)
			for l in L:
				var w := _word_of(b.starts, l.i)
				if w >= b.shown:
					continue
				var fresh: float = b.pop if w == b.shown - 1 else 0.0   # the newest word lands a touch large
				var s := 1.0 + fresh * 0.12
				n.draw_set_transform(Vector2(l.cx, l.y), 0.0, Vector2(s, s))
				TextKit.letter(n, l.ch, Vector2(-l.w / 2.0, 0.0), bs, TextKit.INK)
				n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"teletype":
			# the JS lays out at weight 600 → fake bold via letter_weight (kit note)
			var L := TextKit.layout(b)
			# the machine kicks — canvas translate → a whole-line draw transform
			var off := Vector2(randf_range(-1.0, 1.0) * b.jolt * 2.5, randf_range(-1.0, 1.0) * b.jolt * 1.5)
			n.draw_set_transform(off, 0.0, Vector2.ONE)
			for l in L:
				if l.i < b.shown:
					TextKit.letter_weight(n, l.ch, Vector2(l.x, l.y), bs, TextKit.INK, 600.0)
			n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"dialogue_box":
			var L := TextKit.layout(b, bs * 0.85)
			var r: Rect2 = b.rect
			# the box — canvas fillRect + strokeRect → filled then unfilled draw_rect
			var bx: float = r.position.x + r.size.x * 0.06
			var by: float = b.mid - bs * 1.1
			var bw: float = r.size.x * 0.88
			var bh: float = bs * 1.9
			n.draw_rect(Rect2(bx, by, bw, bh), Color(0.078, 0.063, 0.149, 0.85))
			n.draw_rect(Rect2(bx, by, bw, bh), Color(0.745, 0.725, 0.882, 0.7), false, 1.5)
			for l in L:
				if l.i < b.progress:
					TextKit.letter(n, l.ch, Vector2(l.x, l.y), bs * 0.85, TextKit.INK)
			if b.progress >= L.size() and sin(t * 4.0) > 0.0:
				# the patient ▼ — a small colored polygon
				n.draw_colored_polygon(PackedVector2Array([
					Vector2(bx + bw - 16.0, by + bh - 12.0),
					Vector2(bx + bw - 8.0, by + bh - 12.0),
					Vector2(bx + bw - 12.0, by + bh - 6.0)]), TextKit.INK)
		"two_hands":
			var L := TextKit.layout(b)
			var total := L.size()
			var need := int(ceil(total / 2.0))
			for l in L:
				if l.i < b.steps or l.i >= total - b.steps:
					TextKit.letter(n, l.ch, Vector2(l.x, l.y), bs, TextKit.INK)
			if b.steps < need and sin(t * 7.0) > -0.2:   # two carets, closing in
				n.draw_rect(Rect2(L[b.steps].x, L[0].y - bs * 0.72, bs * 0.45, bs * 0.82), TextKit.INK)
				var rr: Dictionary = L[total - 1 - b.steps]
				n.draw_rect(Rect2(rr.x + rr.w - bs * 0.45, rr.y - bs * 0.72, bs * 0.45, bs * 0.82), TextKit.INK)
		"dictation":
			var L := TextKit.layout(b)
			for l in L:
				if l.ch == " ":
					continue
				if l.i < b.shown:
					TextKit.letter(n, l.ch, Vector2(l.x, l.y), bs, TextKit.INK)
				elif l.i < b.sweep:        # swept but unspoken: the waiting underline
					n.draw_rect(Rect2(l.x, l.y + 4.0, l.w * 0.8, 2.0), TextKit.DIM)
