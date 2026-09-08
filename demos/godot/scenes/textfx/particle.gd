extends RefCounted

const TextKit := preload("res://scenes/textfx/kit.gd")
## DUST & PARTICLES — eight text effects, ported from the web grimoire.

const TITLE := "Dust & particles"
const BLURB := "letters assembled from, and lost to, sparks"
const DEFS := [
	{ "id": "star_assembly", "name": "Star assembly", "hint": "motes stream toward the letter slots, overshoot, swing back and settle; where they gather, letters appear" },
	{ "id": "dust_burst", "name": "Dust burst", "hint": "press and the letters explode into dust — which is hauled back, overshoots, and shudders into the letters again" },
	{ "id": "sparkle_crown", "name": "Sparkle crown", "hint": "little four-point twinkles pop over the letters, one place at a time" },
	{ "id": "electron_letters", "name": "Electron letters", "hint": "two motes orbit every letter like electrons — press and they are flung outward, swing wide and slow, and get pulled back into orbit" },
	{ "id": "snow_fill", "name": "Snow fill", "hint": "snow settles on the letters, whitening them from the top down — gusts sweep across, and the flakes lean into them one after another" },
	{ "id": "ember_decay", "name": "Ember decay", "hint": "the letters smoulder away into rising embers, then heal, on a loop" },
	{ "id": "rain_reveal", "name": "Rain reveal", "hint": "rain streaks fall; letters show where the rain is touching them — press for a downpour" },
	{ "id": "confetti_pop", "name": "Confetti pop", "hint": "press: confetti and a little hop of celebration — idle, the occasional stray fleck" },
]

const COLS := [Color("#FF8FA3"), Color("#FFD166"), Color("#8FE3B0"), Color("#8FB7FF"), Color("#E3A8FF")]

static func init(b: Dictionary) -> void:
	b.parts = []
	match b.id:
		"star_assembly":
			b.arrived = []
			b.age = 0.0
		"dust_burst":
			b.gone = 0.0
		"sparkle_crown":
			b.shower = 0.0
		"electron_letters":
			b.flung = 0.0
			electrons(b)
		"snow_fill":
			b.depth = 0.0
			b.gust = {}                       # the gust, while one is blowing: front x, direction, strength
			b.calm = randf_range(2.0, 5.0)
		"rain_reveal":
			b.pour = 0.0
			b.wet = []
		"confetti_pop":
			b.hop = 0.0

static func press(b: Dictionary, _pos: Vector2) -> void:
	match b.id:
		"star_assembly":
			b.arrived = []
			b.age = 0.0
			b.parts = []
		"dust_burst":
			var L := TextKit.layout(b)
			b.parts = []
			for l in L:
				if l.ch == " ":
					continue
				for i in 6:                   # six grains per letter remember where home is
					b.parts.append({ "x": l.cx + randf_range(-l.w, l.w) * 0.4,
						"y": l.y - randf_range(0.0, b.base_size * 0.6),
						"vx": randf_range(-70.0, 70.0), "vy": randf_range(-90.0, 20.0),
						"hx": l.cx + randf_range(-l.w, l.w) * 0.3,
						"hy": l.y - randf_range(0.0, b.base_size * 0.6) })
			b.gone = 1.0
		"sparkle_crown":
			b.shower = 1.0
		"electron_letters":
			b.flung = 1.0
			var px: PackedFloat32Array = b.ex
			var py: PackedFloat32Array = b.ey
			var vx: PackedFloat32Array = b.evx
			var vy: PackedFloat32Array = b.evy
			var r0: float = b.base_size * 0.55
			for j in px.size():               # the shove: straight outward, velocity only
				var r := maxf(1.0, sqrt(px[j] * px[j] + py[j] * py[j]))
				vx[j] += px[j] / r * r0 * 12.0
				vy[j] += py[j] / r * r0 * 12.0
		"snow_fill":
			b.depth = 0.0                     # brush the snow off — and the sweep of the brush is a gust
			blow(b)
		"rain_reveal":
			b.pour = 1.6
		"confetti_pop":
			b.hop = 1.0
			var r: Rect2 = b.rect
			for i in 26:
				b.parts.append({ "x": r.get_center().x + randf_range(-b.base_size, b.base_size),
					"y": b.mid + randf_range(-4.0, 4.0),
					"vx": randf_range(-90.0, 90.0), "vy": randf_range(-160.0, -60.0),
					"a": randf_range(0.0, TAU), "va": randf_range(-8.0, 8.0),
					"col": COLS[randi() % COLS.size()], "life": 1.0 })
		_:
			pass                              # ember decay keeps its own schedule

static func tick(b: Dictionary, dt: float, t: float) -> void:
	var r: Rect2 = b.rect
	match b.id:
		"star_assembly":
			b.age += dt
			var L := TextKit.layout(b)
			if b.arrived.size() != L.size():
				b.arrived = []
				for l in L:
					b.arrived.append(0.0)
			if b.age > 8.0:
				for i in L.size():
					b.arrived[i] = 0.0
				b.age = 0.0
				b.parts = []
			if b.parts.size() < 40 and b.age < 3.0:        # recruit from the edges, at rest
				var l: Dictionary = L[randi() % L.size()]
				if l.ch != " ":
					b.parts.append({ "x": (r.position.x + randf_range(-10.0, 0.0)) if randf() < 0.5 else (r.end.x + randf_range(0.0, 10.0)),
						"y": randf_range(r.position.y, r.end.y), "vx": 0.0, "vy": 0.0,
						"tx": l.cx, "ty": l.y - b.base_size * 0.3, "ti": l.i, "life": 1.0 })
			# a mote is pulled to its slot by a spring, v' = k·(target − p) − c·v,
			# with the damping under critical: it arrives fast, overshoots the
			# slot, swings back through it and settles — follow-through instead of
			# a lerp's slow creep. it counts as arrived only when close AND slow,
			# so the letter condenses at the settle, not at the first pass.
			var k := 20.0                                  # the homing spring (1/s²) and damping as a fraction of critical
			var c := 2.0 * 0.4 * sqrt(k)
			var sub := maxi(1, ceili(dt * 50.0))           # ≤ 0.02 s steps: a coarse frame is cut up, not trusted
			var h := dt / float(sub)
			for m in b.parts:
				for _s in sub:
					m.vx += (k * (m.tx - m.x) - c * m.vx) * h
					m.vy += (k * (m.ty - m.y) - c * m.vy) * h
					m.x += m.vx * h
					m.y += m.vy * h
				if absf(m.x - m.tx) < 4.0 and absf(m.y - m.ty) < 4.0 and Vector2(m.vx, m.vy).length() < 40.0:   # close AND slow: settled
					b.arrived[m.ti] += dt * 2.0
					m.life = 0.0
			b.parts = b.parts.filter(func(m): return m.life > 0.0)
		"dust_burst":
			# the burst is ballistics: velocity, gravity, air drag. the return is a
			# spring, not a lerp — each grain keeps whatever momentum it still has
			# and is pulled at its home by v' = k·(home − p) − c·v, under-damped,
			# so it overshoots, swings back and shudders into place over a second
			# or so. the phrase only fades up once that shudder has died.
			if b.gone > 0.0:
				b.gone = minf(3.2, b.gone + dt)
				var homing: bool = b.gone > 1.2            # first they scatter; then they remember
				var k := 60.0                              # the homing spring (1/s²) and damping as a fraction of critical
				var c := 2.0 * 0.25 * sqrt(k)
				var sub := maxi(1, ceili(dt * 50.0))
				var h := dt / float(sub)
				for d in b.parts:
					if homing:                             # the spring: momentum kept, hauled home, overshoot and all
						for _s in sub:
							d.vx += (k * (d.hx - d.x) - c * d.vx) * h
							d.vy += (k * (d.hy - d.y) - c * d.vy) * h
							d.x += d.vx * h
							d.y += d.vy * h
					else:
						d.x += d.vx * dt
						d.y += d.vy * dt
						d.vy += 60.0 * dt
						d.vx *= pow(0.4, dt)
						d.vy *= pow(0.4, dt)
				if b.gone >= 3.2:
					b.gone = 0.0
					b.parts = []
		"sparkle_crown":
			b.shower = maxf(0.0, b.shower - dt)
			var L := TextKit.layout(b)
			if randf() < 0.15 + b.shower * 0.8:
				var l: Dictionary = L[randi() % L.size()]
				b.parts.append({ "x": l.cx + randf_range(-l.w * 0.5, l.w * 0.5),
					"y": l.y - randf_range(b.base_size * 0.2, b.base_size * 0.95),
					"life": 1.0, "s": randf_range(2.0, 4.5) })
			for s in b.parts:
				s.life -= dt * 1.6
			b.parts = b.parts.filter(func(s): return s.life > 0.0)
		"electron_letters":
			# an orbit is nothing but velocity plus a central pull. each mote has a
			# position and a velocity, and every step the letter tugs it toward the
			# ring radius r0 with a spring in r, F = −k·(r − r0), that damps only
			# the RADIAL motion — the sideways speed is left alone, so the mote
			# keeps circling for ever. a press is a radial shove: the mote flies
			# out, slows (angular momentum is conserved, so wider means slower),
			# and the spring hauls it back in, the excess ringing down.
			b.flung = maxf(0.0, b.flung - dt * 0.7)
			var px: PackedFloat32Array = b.ex
			var py: PackedFloat32Array = b.ey
			var vx: PackedFloat32Array = b.evx
			var vy: PackedFloat32Array = b.evy
			var r0: float = b.base_size * 0.55
			var k := 80.0                                  # the ring spring (1/s²) and radial damping as a fraction of critical
			var c := 2.0 * 0.15 * sqrt(k)
			var sub := maxi(1, ceili(dt * 50.0))
			var h := dt / float(sub)
			for j in px.size():
				var ring := r0 + float(j % 2) * 3.0
				for _s in sub:
					var rr := maxf(1.0, sqrt(px[j] * px[j] + py[j] * py[j]))
					var ux := px[j] / rr
					var uy := py[j] / rr
					var vr := vx[j] * ux + vy[j] * uy       # the radial part of the velocity: the only part damped
					var f := -k * (rr - ring) - c * vr
					vx[j] += f * ux * h
					vy[j] += f * uy * h
					px[j] += vx[j] * h
					py[j] += vy[j] * h
				var rl := sqrt(px[j] * px[j] + py[j] * py[j])
				if rl > ring * 8.0:                        # a leash, in case of a run of presses
					px[j] *= ring * 8.0 / rl
					py[j] *= ring * 8.0 / rl
		"snow_fill":
			# a flake is a tiny mass with a lot of drag: gravity pulls it down and
			# the air drags it toward the air's own speed — vy' = g − drag·vy and
			# vx' = drag·(wind − vx) — so it never exceeds its terminal speed
			# g/drag, and it takes about 1/drag seconds to believe a change in the
			# wind. the wind is a gust: a bump of sideways air that sweeps across
			# the card, so a flake near the front leans first and one further
			# along leans later — the gust is SEEN travelling.
			b.depth = minf(1.0, b.depth + dt * 0.06)       # the slow accumulation
			b.calm -= dt
			if b.gust.is_empty() and b.calm < 0.0:
				blow(b)
			if not b.gust.is_empty():
				b.gust.x += b.gust.dir * r.size.x * 0.35 * dt
				if b.gust.x < r.position.x - r.size.x * 0.4 or b.gust.x > r.end.x + r.size.x * 0.4:
					b.gust = {}
					b.calm = randf_range(2.0, 5.0)
			var g := 60.0                                  # gravity, px/s² — each flake's drag sets its terminal speed
			if b.parts.size() < 30 and randf() < 0.5:
				b.parts.append({ "x": randf_range(r.position.x, r.end.x), "y": r.position.y - 4.0,
					"vx": 0.0, "vy": 0.0, "drag": randf_range(2.0, 4.5) })   # drag 2–4.5 → terminal speeds 30–13 px/s
			for f in b.parts:
				f.vy += (g - f.drag * f.vy) * dt           # toward terminal speed
				f.vx += f.drag * (wind(b, f.x) - f.vx) * dt   # toward the local air, 1/drag seconds behind it
				f.x += f.vx * dt
				f.y += f.vy * dt
			b.parts = b.parts.filter(func(f): return f.y < r.end.y + 4.0 and f.x > r.position.x - 8.0 and f.x < r.end.x + 8.0)
		"ember_decay":
			var cycle := fmod(t, 7.0) / 7.0                # 0..1: whole → gone → whole
			var burn := cycle * 2.0 if cycle < 0.5 else (1.0 - cycle) * 2.0
			var L := TextKit.layout(b)
			for l in L:
				if l.ch == " ":
					continue
				var lit_from: float = l.y - b.base_size * 0.75 + b.base_size * 0.85 * (1.0 - burn)   # the burn line climbs
				if burn > 0.02 and burn < 0.98 and randf() < 0.3:                                    # sparks at the burn line
					b.parts.append({ "x": l.cx + randf_range(-l.w * 0.4, l.w * 0.4), "y": lit_from,
						"vy": randf_range(-30.0, -14.0), "life": 1.0 })
			for e in b.parts:
				e.y += e.vy * dt
				e.x += sin(e.y * 0.2) * 8.0 * dt
				e.life -= dt * 1.3
			b.parts = b.parts.filter(func(e): return e.life > 0.0)
		"rain_reveal":
			b.pour = maxf(0.0, b.pour - dt)
			var L := TextKit.layout(b)
			if b.wet.size() != L.size():
				b.wet = []
				for l in L:
					b.wet.append(0.0)
			if randf() < 0.35 + b.pour * 1.5:
				b.parts.append({ "x": randf_range(r.position.x, r.end.x), "y": r.position.y - 10.0,
					"v": randf_range(160.0, 260.0) })
			for d in b.parts:
				d.y += d.v * dt
				for l in L:                                # a streak passing through a letter wets it
					if absf(d.x - l.cx) < l.w * 0.7 and d.y > l.y - b.base_size and d.y < l.y + 4.0:
						b.wet[l.i] = minf(1.0, b.wet[l.i] + dt * 8.0)
			b.parts = b.parts.filter(func(d): return d.y < r.end.y + 12.0)
			for l in L:
				b.wet[l.i] = maxf(0.0, b.wet[l.i] - dt * 0.25)     # it dries
		"confetti_pop":
			b.hop = maxf(0.0, b.hop - dt * 2.2)
			if randf() < 0.02:                             # a stray fleck, even between parties
				b.parts.append({ "x": randf_range(r.position.x, r.end.x), "y": r.position.y - 4.0,
					"vx": randf_range(-6.0, 6.0), "vy": randf_range(20.0, 40.0),
					"a": randf_range(0.0, TAU), "va": randf_range(-3.0, 3.0),
					"col": COLS[randi() % COLS.size()], "life": 1.0 })
			for c in b.parts:
				c.x += c.vx * dt
				c.y += c.vy * dt
				c.vy += 150.0 * dt
				c.a += c.va * dt
				c.life -= dt * 0.5
				c.vx *= pow(0.5, dt)
			b.parts = b.parts.filter(func(c): return c.life > 0.0 and c.y < r.end.y + 8.0)

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	TextKit.stage(n, b)
	var bs: float = b.base_size
	match b.id:
		"star_assembly":
			for m in b.parts:                              # "lighter" motes → layered glows
				TextKit.glow(n, Vector2(m.x, m.y), 2.5, Color(0.86, 0.86, 1.0, 0.8))
			var L := TextKit.layout(b)
			for l in L:                                    # letters condense out of gathered light
				if l.i >= b.arrived.size():
					break
				var k: float = minf(1.0, b.arrived[l.i])
				if k <= 0.0:
					continue
				TextKit.letter(n, l.ch, Vector2(l.x, l.y), bs, Color(TextKit.INK.r, TextKit.INK.g, TextKit.INK.b, k))
		"dust_burst":
			var L := TextKit.layout(b)
			if b.gone > 0.0:
				for d in b.parts:
					n.draw_rect(Rect2(Vector2(d.x, d.y), Vector2(1.8, 1.8)), Color(0.86, 0.84, 0.94, 0.8))
				var k: float = maxf(0.0, (b.gone - 2.6) * 2.0)     # the reformed phrase fades up once the shudder has died
				if k > 0.0:
					for l in L:
						TextKit.letter(n, l.ch, Vector2(l.x, l.y), bs, Color(TextKit.INK.r, TextKit.INK.g, TextKit.INK.b, minf(1.0, k)))
			else:
				for l in L:
					TextKit.letter(n, l.ch, Vector2(l.x, l.y), bs, TextKit.INK)
		"sparkle_crown":
			var L := TextKit.layout(b)
			for l in L:
				TextKit.letter(n, l.ch, Vector2(l.x, l.y), bs, TextKit.INK)
			for s in b.parts:
				TextKit.twinkle(n, Vector2(s.x, s.y), s.s * sin(s.life * PI), Color(1.0, 0.98, 0.86, s.life))
		"electron_letters":
			var L := TextKit.layout(b)
			for l in L:
				TextKit.letter(n, l.ch, Vector2(l.x, l.y), bs, TextKit.INK)
			var px: PackedFloat32Array = b.ex
			var py: PackedFloat32Array = b.ey
			for l in L:
				if l.ch == " ":
					continue
				for e in 2:
					var j: int = l.i * 2 + e               # the orbit, squashed in y for the tilted look
					TextKit.glow(n, Vector2(l.cx + px[j], l.y - bs * 0.3 + py[j] * 0.55),
						2.5, Color(0.63, 0.86, 1.0, 0.8 - b.flung * 0.3))
		"snow_fill":
			for f in b.parts:
				n.draw_rect(Rect2(Vector2(f.x, f.y), Vector2(1.8, 1.8)), Color(0.94, 0.96, 1.0, 0.8))
			var L := TextKit.layout(b)                     # JS layout(BASE, 0, 600): the weight rides letter_weight
			for l in L:                                    # dim letters, snowier from the top
				TextKit.letter_weight(n, l.ch, Vector2(l.x, l.y), bs, TextKit.DIM, 600.0)
				# canvas clip: the snowy cap grows down from the letter top —
				# here the whitening rides depth as alpha instead of a hard cap line
				if b.depth > 0.0:
					TextKit.letter_weight(n, l.ch, Vector2(l.x, l.y), bs, Color(0.96, 0.98, 1.0, 0.95 * b.depth), 600.0)
		"ember_decay":
			var cycle := fmod(t, 7.0) / 7.0
			var burn := cycle * 2.0 if cycle < 0.5 else (1.0 - cycle) * 2.0    # how much is burned away
			var L := TextKit.layout(b)
			for l in L:
				if l.ch == " ":
					continue
				var lit_from: float = l.y - bs * 0.75 + bs * 0.85 * (1.0 - burn)
				# canvas clip below the burn line → the letter's alpha follows the
				# clipped share (burn); the line itself carries the glow
				TextKit.letter(n, l.ch, Vector2(l.x, l.y), bs, Color(TextKit.INK.r, TextKit.INK.g, TextKit.INK.b, burn))
				if burn > 0.02 and burn < 0.98:            # JS flickers this with its spark rolls; it holds here
					TextKit.glow(n, Vector2(l.cx, lit_from), 4.0, Color(1.0, 0.55, 0.24, 0.5))
			for e in b.parts:
				TextKit.glow(n, Vector2(e.x, e.y), 2.0 + e.life * 2.0, Color(1.0, 0.59, 0.24, e.life * 0.8))
		"rain_reveal":
			for d in b.parts:
				n.draw_line(Vector2(d.x, d.y - 10.0), Vector2(d.x, d.y), Color(0.59, 0.75, 1.0, 0.5), 1.2)
			var L := TextKit.layout(b)
			for l in L:
				var w: float = 0.0 if b.wet.is_empty() else b.wet[l.i]
				var col: Color = Color(0.78, 0.86, 1.0, 0.15 + w * 0.85) if w > 0.02 else TextKit.DIM
				TextKit.letter(n, l.ch, Vector2(l.x, l.y), bs, col)
		"confetti_pop":
			for c in b.parts:
				var col: Color = c.col
				n.draw_set_transform(Vector2(c.x, c.y), c.a, Vector2.ONE)
				n.draw_rect(Rect2(Vector2(-2.5, -1.5), Vector2(5.0, 3.0)),
					Color(col.r, col.g, col.b, minf(1.0, c.life * 2.0)))
				n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			var jump: float = sin(minf(1.0, 1.0 - b.hop) * PI) * b.hop * bs * 0.4
			var L := TextKit.layout(b)                     # JS layout(BASE, 0, hop ? 700 : 400)
			for l in L:
				TextKit.letter_weight(n, l.ch, Vector2(l.x, l.y - jump * sin(float(l.i) / float(l.n - 1) * PI)),
					bs, TextKit.INK, 700.0 if b.hop > 0.0 else 400.0)

## Electron letters' motes: two per letter, a position and a velocity relative
## to the letter, started on a circle at the radius where the ring spring's
## pull equals v²/r (so they begin in orbit, not in a wobble). Packed arrays,
## letter-major: [i * 2 + e].
static func electrons(b: Dictionary) -> void:
	var nn := TextKit.PHRASE.length() * 2
	var px := PackedFloat32Array()
	var py := PackedFloat32Array()
	var vx := PackedFloat32Array()
	var vy := PackedFloat32Array()
	px.resize(nn)
	py.resize(nn)
	vx.resize(nn)
	vy.resize(nn)
	var r0: float = b.base_size * 0.55
	for i in TextKit.PHRASE.length():
		for e in 2:
			var j := i * 2 + e
			var a := float(i) * 1.3 + float(e) * PI
			var w := 2.2 + float(e) * 0.9
			var r := (r0 + float(e) * 3.0) * (1.0 + w * w / 80.0)
			px[j] = cos(a) * r
			py[j] = sin(a) * r
			vx[j] = -sin(a) * r * w                        # sideways speed for a circle at this rate
			vy[j] = cos(a) * r * w
	b.ex = px
	b.ey = py
	b.evx = vx
	b.evy = vy

## Snow fill's gust: starts upwind of the card and travels downwind.
static func blow(b: Dictionary) -> void:
	var r: Rect2 = b.rect
	var dir := -1.0 if randf() < 0.5 else 1.0
	var x: float = (r.position.x - r.size.x * 0.3) if dir > 0.0 else (r.end.x + r.size.x * 0.3)
	b.gust = { "x": x, "dir": dir, "k": randf_range(25.0, 55.0) * dir }

## The air's sideways speed at x: a bump riding the gust front, or still air.
static func wind(b: Dictionary, x: float) -> float:
	if b.gust.is_empty():
		return 0.0
	var r: Rect2 = b.rect
	var d: float = (x - b.gust.x) / (r.size.x * 0.25)
	return b.gust.k * exp(-d * d)
