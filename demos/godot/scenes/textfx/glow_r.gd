extends RefCounted

const TextKit := preload("res://scenes/textfx/kit.gd")
const Base := preload("res://scenes/textfx/glow.gd")
## GLOW & NEON — the rhymes. Dials named per branch; the rest delegates.

const BROKEN := 2                          # this letter has seen things

const RHYMES := {
	"candleglow": { "name": "Ghostglow", "hint": "the same flame gone cold — dim, slow, and blue at the edges" },
	"halo_lift": { "name": "Heartbeat halo", "hint": "the same halo on a lub-dub — two quick pulses, then the long rest" },
	"supernova": { "name": "Black sun", "hint": "inverted — a dark core wearing a bright rim, and the rings run inward" },
	"neon_sign": { "name": "Broken neon", "hint": "cyan, and one letter is properly broken — it buzzes until you press to heal it" },
	"ember_text": { "name": "Frost light", "hint": "the same inner light gone cold — the shimmer sinks instead of rising" },
	"beacon_sweep": { "name": "Lighthouse", "hint": "the same beam at sea pace — half the speed, nearly twice the width" },
	"chromatic_halo": { "name": "Duotone drift", "hint": "two inks instead of three — teal and orange, drifting apart on one axis" },
}

static func init(b: Dictionary) -> void:
	Base.init(b)
	match b.id:
		"neon_sign":
			# dial: the failure is pinned to BROKEN — press heals it
			b.heal = 0.0

static func press(b: Dictionary, pos: Vector2) -> void:
	match b.id:
		"supernova":
			# dial: press rings are born wide (4.5×) and travel IN, not out
			b.rings.append({ "r": b.base_size * 4.5, "a": 0.8 })
		"neon_sign":
			# dial: press heals instead of stuttering
			b.heal = 3.0
		"ember_text":
			# dial: vy flipped — the burst of sparks falls
			var L: Array = TextKit.layout(b)
			for i in 14:
				var l: Dictionary = L[int(randf_range(0.0, L.size()))]
				b.motes.append({ "x": l.cx + randf_range(-4.0, 4.0),
					"y": l.y - randf_range(0.0, b.base_size * 0.6),
					"vy": randf_range(14.0, 30.0), "life": 1.0 })
		_:
			Base.press(b, pos)

static func tick(b: Dictionary, dt: float, t: float) -> void:
	match b.id:
		"candleglow":
			# dials: flare decays at half pace · flicker smoothing ×3 slower
			b.flare = maxf(0.0, b.flare - dt * 0.6)
			b.wick += (randf_range(-1.0, 1.0) - b.wick) * minf(1.0, dt * 2.0)
		"supernova":
			# dial: the rings run inward — falling home, fading slower
			for rg in b.rings:
				rg.r -= dt * b.base_size * 3.0
				rg.a -= dt * 0.5
			b.rings = b.rings.filter(func(rg): return rg.a > 0.0 and rg.r > 2.0)
		"neon_sign":
			b.heal = maxf(0.0, b.heal - dt)
		"ember_text":
			# dials: motes fall (vy flipped) · sway 12 → 8
			var s: float = b.base_size
			var L: Array = TextKit.layout(b)
			if randf() < 0.35:
				var l: Dictionary = L[int(randf_range(0.0, L.size()))]
				if l.ch != " ":
					b.motes.append({ "x": l.cx + randf_range(-3.0, 3.0),
						"y": l.y - randf_range(s * 0.3, s * 0.8),
						"vy": randf_range(8.0, 18.0), "life": 0.8 })
			for m in b.motes:
				m.y += m.vy * dt
				m.x += sin(m.y * 0.15) * 8.0 * dt
				m.life -= dt * 1.1
			b.motes = b.motes.filter(func(m): return m.life > 0.0)
		_:
			Base.tick(b, dt, t)

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	var s: float = b.base_size
	var r: Rect2 = b.rect
	var cx: float = r.get_center().x
	match b.id:
		"candleglow":
			TextKit.stage(n, b)
			# dials: palette warm → cold · flare = a shiver (wider, fainter)
			var a: float = 0.06 + 0.02 * b.wick + b.flare * 0.10
			TextKit.glow(n, Vector2(cx, b.mid - s * 0.3),
				s * (2.6 + b.wick * 0.2 + b.flare * 2.4), Color(0.55, 0.75, 1, a))
			for l in TextKit.layout(b):
				TextKit.letter(n, l.ch, Vector2(l.x, l.y), s, Color(0.82, 0.9, 1, 0.85))
		"halo_lift":
			TextKit.stage(n, b)
			# dials: waveform sine → double-pulse · palette cool → warm
			var beat := fmod(t * 62.0 / 60.0, 1.0)   # the same clock a heart keeps
			var k := maxf(exp(-beat * 14.0), 0.7 * (exp(-(beat - 0.28) * 14.0) if beat > 0.28 else 0.0))
			TextKit.glow(n, Vector2(cx, b.mid - s * 0.3), s * (2.6 + k * 1.2) * (1.0 + b.lift),
				Color(1, 0.59, 0.55, 0.13 + k * 0.10 + b.lift * 0.1))
			for l in TextKit.layout(b):
				TextKit.letter(n, l.ch, Vector2(l.x, l.y), s, Color(1, 0.91, 0.89))
		"supernova":
			TextKit.stage(n, b)
			# dial: glow polarity inverted — dark centre, lit rim
			var c := Vector2(cx, b.mid - s * 0.3)
			TextKit.glow(n, c, s * 4.6, Color(0.78, 0.67, 1, 0.16))                          # the corona
			TextKit.glow(n, c, s * 2.4, Color(0.03, 0.02, 0.06, 0.75 + 0.05 * sin(t * 2.0))) # the dark heart
			for rg in b.rings:
				n.draw_arc(c, rg.r, 0.0, TAU, 48, Color(0.82, 0.71, 1, rg.a), 2.0)
			for l in TextKit.layout(b):
				# rim-lit letters over the void: strokeText alone → letter_outline alone
				TextKit.letter_outline(n, l.ch, Vector2(l.x, l.y), s, 1, Color(0.86, 0.75, 1, 0.9))
		"neon_sign":
			TextKit.stage(n, b)
			# dials: palette magenta → cyan · only BROKEN buzzes, until healed
			for l in TextKit.layout(b):
				if l.ch == " ":
					continue
				var on := true
				if l.i == BROKEN and b.heal <= 0.0:
					on = randf() < 0.45      # the buzz
				if on:
					TextKit.glow(n, Vector2(l.cx, l.y - s * 0.32), s * 0.9, Color(0.31, 0.9, 1, 0.28))
				TextKit.letter(n, l.ch, Vector2(l.x, l.y), s,
					Color(0.75, 0.96, 1) if on else Color(0.2, 0.35, 0.43, 0.5))
				TextKit.letter_outline(n, l.ch, Vector2(l.x, l.y), s, 1,
					Color(0.59, 0.94, 1, 0.9) if on else Color(0.2, 0.35, 0.43, 0.4))
		"ember_text":
			TextKit.stage(n, b)
			# dials: palette ember → frost · pulse 1.7 → 1.0
			var L: Array = TextKit.layout(b)
			for l in L:
				if l.ch == " ":
					continue
				var chill: float = 0.5 + 0.5 * sin(t * 1.0 + l.i * 1.31)
				TextKit.glow(n, Vector2(l.cx, l.y - s * 0.28), s * 0.65,
					Color(0.59, 0.78, 1, 0.12 + chill * 0.10))
			for m in b.motes:
				TextKit.glow(n, Vector2(m.x, m.y), 2.0 + m.life * 2.0, Color(0.71, 0.86, 1, m.life * 0.6))
			for l in L:
				var chill: float = 0.5 + 0.5 * sin(t * 1.0 + l.i * 1.31)
				TextKit.letter(n, l.ch, Vector2(l.x, l.y), s,
					Color(0.71 + chill * 0.16, 0.82 + chill * 0.12, 1))
		"beacon_sweep":
			TextKit.stage(n, b)
			# dials: sweep ×0.5 · beam ×1.8 wide · a faint fog ring around the lamp
			var bx: float = r.position.x + r.size.x * (0.5 + 0.55 * sin(t * (0.4 + b.hurry * 1.1)))
			TextKit.glow(n, Vector2(bx, b.mid - s * 0.3), s * 4.0, Color(1, 0.96, 0.78, 0.13))
			TextKit.glow(n, Vector2(bx, b.mid - s * 0.3), s * 1.4, Color(1, 0.98, 0.88, 0.15))
			for l in TextKit.layout(b):
				var k: float = maxf(0.0, 1.0 - absf(l.cx - bx) / (s * 4.0))
				TextKit.letter(n, l.ch, Vector2(l.x, l.y), s,
					Color(1, 0.97, 0.86, minf(1.0, 0.25 + k)) if k > 0.02 else TextKit.DIM)
		"chromatic_halo":
			TextKit.stage(n, b)
			# dials: plates 3 → 2 · drift horizontal-only · speed ×0.6
			var drift: float = s * 0.6 * (0.5 + 0.5 * sin(t * 0.42)) * (1.0 - b.snap)
			var c := Vector2(cx, b.mid - s * 0.3)
			TextKit.glow(n, c + Vector2(-drift, 0.0), s * 2.2, Color(0.24, 0.82, 0.78, 0.18))
			TextKit.glow(n, c + Vector2(drift, 0.0), s * 2.2, Color(1, 0.59, 0.27, 0.18))
			for l in TextKit.layout(b):
				TextKit.letter(n, l.ch, Vector2(l.x, l.y), s, Color(0.95, 0.94, 0.98))
		_:
			Base.draw(n, b, t)
