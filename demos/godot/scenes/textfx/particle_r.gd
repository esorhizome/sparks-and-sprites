extends RefCounted

const TextKit := preload("res://scenes/textfx/kit.gd")
const Base := preload("res://scenes/textfx/particle.gd")
## DUST & PARTICLES — the rhymes. Dials named per branch; the rest delegates.

const RHYMES := {
	"star_assembly": { "name": "Star scatter", "hint": "the cycle reversed — the phrase stands, flings its letters off as motes that coast to a stop, then hauls them home on the spring, overshoot and all, and regathers as they land" },
	"dust_burst": { "name": "Bubble burst", "hint": "gravity flipped — the letters burst into bubbles that rise under buoyancy, the big ones faster, wobbling as they go, and pop at their fuse or at the top" },
	"sparkle_crown": { "name": "Frost sparkle", "hint": "cold twinkles at half the rate — and the letters blush blue where they land" },
	"electron_letters": { "name": "Moth lamp", "hint": "the orbits abandoned for one drifting lamp — the same ring spring, but every mote shares the one centre, and it strolls, so they lag it, crowd it, and circle; press to startle them outward" },
	"snow_fill": { "name": "Sandstorm", "hint": "the snow turned sideways and hostile — grit dragged along by a wind that comes in gust fronts, streaming past and scouring the letters pale; press and the wind drops for a moment, the grit sags, and the letters recover" },
	"ember_decay": { "name": "Ash rain", "hint": "the burn eats downward instead, and ash falls where embers rose" },
	"rain_reveal": { "name": "Sun shower", "hint": "gold light instead of rain — and what it reveals takes much longer to fade" },
	"confetti_pop": { "name": "Streamers", "hint": "ribbons instead of flecks — fewer, longer, floatier, twice the hang-time" },
}

static func init(b: Dictionary) -> void:
	Base.init(b)
	match b.id:
		"star_assembly":
			b.solidity = 1.0
			b.phase = 0.0
		"sparkle_crown":
			b.chill = []
		"electron_letters":
			var r: Rect2 = b.rect
			b.lamp = Vector2(r.get_center().x, b.mid - b.base_size * 1.1)   # where the lamp is now, for the press
			b.parts = moths(b)
		"snow_fill":
			b.worn = []
			b.lull = 0.0                      # seconds of still air left after a press
			b.sgust = {}                      # the storm's gust, while one is blowing: front x and extra speed
			b.scalm = randf_range(1.0, 3.0)

static func press(b: Dictionary, pos: Vector2) -> void:
	match b.id:
		"star_assembly":
			b.phase = 3.0                     # shed early
		"dust_burst":
			# dials moved: six grains → four bubbles, from rest · life is a fuse · a wobble phase and rate of its own
			var L := TextKit.layout(b)
			b.parts = []
			for l in L:
				if l.ch == " ":
					continue
				for i in 4:
					b.parts.append({ "x": l.cx + randf_range(-l.w, l.w) * 0.4,
						"y": l.y - randf_range(0.0, b.base_size * 0.6),
						"vx": randf_range(-15.0, 15.0), "vy": 0.0,   # from rest: buoyancy does the lifting
						"r": randf_range(2.0, 5.0), "life": randf_range(0.8, 1.6),
						"ph": randf_range(0.0, TAU), "wf": randf_range(4.0, 8.0) })
			b.gone = 2.2
		"electron_letters":
			# dial: the startle is a radial shove away from the lamp — velocity only, as Electron letters' press
			var lamp: Vector2 = b.lamp
			var r0: float = b.base_size * 0.7
			for m in b.parts:
				var d := Vector2(m.x, m.y) - lamp
				var rr := maxf(1.0, d.length())
				m.vx += d.x / rr * r0 * 8.0
				m.vy += d.y / rr * r0 * 8.0
		"snow_fill":
			b.worn = []                       # the wind drops for a moment; the letters recover
			b.lull = 1.5
		"confetti_pop":
			# dials moved: count ÷2ish (26 → 10) · launch softened · double life
			b.hop = 1.0
			var r: Rect2 = b.rect
			for i in 10:
				b.parts.append({ "x": r.get_center().x + randf_range(-b.base_size, b.base_size), "y": b.mid,
					"vx": randf_range(-50.0, 50.0), "vy": randf_range(-110.0, -50.0),
					"ph": randf_range(0.0, TAU), "col": Base.COLS[randi() % Base.COLS.size()], "life": 2.0 })
		_:
			Base.press(b, pos)

static func tick(b: Dictionary, dt: float, t: float) -> void:
	var r: Rect2 = b.rect
	match b.id:
		"star_assembly":
			# dials moved: converge → shed, then regather (the same spring runs
			# the second half) · the shedding is a kick and air drag, not a lerp
			# to an edge · the phrase dims as it sheds and firms as motes land.
			# three seconds standing, three shedding, three regathering. a shed
			# mote is KICKED off its letter and then only air drag acts on it,
			# v' = −drag·v, so it coasts to a stop a letter-height or two away.
			# the regather is Star assembly's spring, v' = k·(home − p) − c·v,
			# under-damped: every mote is hauled back from where it stopped,
			# overshoots, swings back, and counts as home only when close AND slow.
			b.phase += dt
			if b.phase > 9.0:
				b.phase = 0.0
				b.parts = []
			var shedding: bool = b.phase > 3.0 and b.phase < 6.0
			var homing: bool = b.phase >= 6.0
			var s: float = b.base_size
			var L := TextKit.layout(b)
			if shedding:
				b.solidity = maxf(0.0, b.solidity - dt * 0.5)
				if randf() < 0.7:             # a letter lets go of a mote: a kick, one way or the other
					var l: Dictionary = L[randi() % L.size()]
					if l.ch != " ":
						b.parts.append({ "x": l.cx, "y": l.y - s * 0.3, "hx": l.cx, "hy": l.y - s * 0.3,
							"vx": (-1.0 if randf() < 0.5 else 1.0) * randf_range(2.0, 4.5) * s,
							"vy": randf_range(-1.2, 1.2) * s, "life": 1.0 })
			elif homing:
				b.solidity = minf(1.0, b.solidity + dt * 0.6)
			var k := 20.0                     # the homing spring (1/s²) and damping as a fraction of critical
			var c := 2.0 * 0.4 * sqrt(k)
			var drag := 2.0                   # a coasting mote loses most of its speed in a second
			var sub := maxi(1, ceili(dt * 50.0))   # ≤ 0.02 s steps: a coarse frame is cut up, not trusted
			var h := dt / float(sub)
			for m in b.parts:
				for _s in sub:
					if homing:                # the spring: hauled home from wherever it stopped
						m.vx += (k * (m.hx - m.x) - c * m.vx) * h
						m.vy += (k * (m.hy - m.y) - c * m.vy) * h
					else:                     # the coast: drag only
						m.vx -= drag * m.vx * h
						m.vy -= drag * m.vy * h
					m.x += m.vx * h
					m.y += m.vy * h
				if homing and absf(m.x - m.hx) < 4.0 and absf(m.y - m.hy) < 4.0 and Vector2(m.vx, m.vy).length() < 40.0:   # close AND slow: landed
					m.life = 0.0
			b.parts = b.parts.filter(func(m): return m.life > 0.0)
		"dust_burst":
			# dials moved: gravity down → buoyancy up, ∝ size, with drag to a
			# terminal speed · the wobble is a drag toward a little side-wind of
			# the bubble's own · pop at the fuse, or at the top of the card.
			# a bubble is a snowflake upside down: vy' = −lift·r − drag·vy, so a
			# big bubble outruns a small one and none goes at a fixed rate — they
			# start from rest and get up to speed. sideways, vx' = drag·(sway − vx):
			# the zigzag a real bubble makes as it sheds eddies.
			if b.gone > 0.0:
				b.gone -= dt
				var lift := 18.0              # lift per px of radius, and drag (1/s): terminal rise 22–56 px/s for r 2–5
				var drag := 1.6
				for bub in b.parts:
					if bub.life > 0.0:        # still whole: rise, wobble
						bub.ph += bub.wf * dt
						bub.vy += (-lift * bub.r - drag * bub.vy) * dt   # buoyancy up, drag toward the terminal speed
						bub.vx += drag * (sin(bub.ph) * 12.0 - bub.vx) * dt   # dragged toward its own little side-wind
						bub.x += bub.vx * dt
						bub.y += bub.vy * dt
						if bub.y < r.position.y + bub.r:   # the top of the card: pop
							bub.life = 0.0
					bub.life -= dt
				b.parts = b.parts.filter(func(bub): return bub.life > -0.15)
		"sparkle_crown":
			# dials moved: rate ×0.5 · life drains 1.6 → 1.1 · a per-letter chill tint that fades
			b.shower = maxf(0.0, b.shower - dt)
			var L := TextKit.layout(b)
			if b.chill.size() != L.size():
				b.chill = []
				for l in L:
					b.chill.append(0.0)
			if randf() < 0.08 + b.shower * 0.5:
				var i := randi() % L.size()
				var l: Dictionary = L[i]
				b.parts.append({ "x": l.cx + randf_range(-l.w * 0.5, l.w * 0.5),
					"y": l.y - randf_range(b.base_size * 0.2, b.base_size * 0.95),
					"life": 1.0, "s": randf_range(2.0, 4.5) })
				b.chill[i] = 1.0
			for l in L:
				b.chill[l.i] = maxf(0.0, b.chill[l.i] - dt * 0.5)
			for s in b.parts:
				s.life -= dt * 1.1
			b.parts = b.parts.filter(func(s): return s.life > 0.0)
		"electron_letters":
			# dials moved: per-letter centres → one shared lamp that strolls ·
			# ring radius 0.55 → 0.7 letter-heights, the spring looser · a flutter
			# of random kicks, moth-style · a whisper of tangential drag.
			# the same physics as Electron letters: position + velocity, a spring
			# in r toward a ring radius that damps only the RADIAL motion, so the
			# sideways speed — the angular momentum — is kept and the mote keeps
			# circling. the one dial that changes everything is the CENTRE: all
			# the motes share it, and it moves, so a mote is forever being hauled
			# after a lamp that has already strolled on.
			var s: float = b.base_size
			var lamp := Vector2(r.get_center().x + sin(t * 0.5) * r.size.x * 0.3,   # the lamp strolls
				b.mid - s * 1.1 + sin(t * 0.9) * s * 0.4)
			b.lamp = lamp
			var r0: float = s * 0.7
			var k := 30.0                     # the ring spring (1/s²), radial damping, and a whisper of tangential drag, as fractions of critical
			var c := 2.0 * 0.3 * sqrt(k)
			var ct := 2.0 * 0.02 * sqrt(k)
			var sub := maxi(1, ceili(dt * 50.0))
			var h := dt / float(sub)
			for m in b.parts:
				m.flit -= dt
				if m.flit < 0.0:              # the flutter: a kick now and then
					m.vx += randf_range(-1.0, 1.0) * s * 1.5
					m.vy += randf_range(-1.0, 1.0) * s * 1.5
					m.flit = randf_range(0.1, 0.5)
				for _s in sub:
					var rel := Vector2(m.x, m.y) - lamp
					var rr := maxf(1.0, rel.length())
					var ux := rel.x / rr
					var uy := rel.y / rr
					var vr: float = m.vx * ux + m.vy * uy        # radial and sideways parts of the velocity
					var vtan: float = -m.vx * uy + m.vy * ux
					var f := -k * (rr - r0) - c * vr             # the ring spring, damping the radial part only
					m.vx += (f * ux + ct * vtan * uy) * h        # the sideways drag acts along (−uy, ux)
					m.vy += (f * uy - ct * vtan * ux) * h
					m.x += m.vx * h
					m.y += m.vy * h
				var off := Vector2(m.x, m.y) - lamp
				var rl := off.length()
				if rl > r0 * 8.0:             # a leash, in case of a run of presses
					m.x = lamp.x + off.x * r0 * 8.0 / rl
					m.y = lamp.y + off.y * r0 * 8.0 / rl
		"snow_fill":
			# dials moved: gravity → a sideways wind (the grain is dragged toward
			# the air, exactly as the flake is) · the gust is a front of extra
			# speed that sweeps downwind · a small sag under gravity · fill-up →
			# scour (worn per letter) · press: a lull instead of a brush.
			# a grain is dragged toward the air's speed, vx' = drag·(wind − vx),
			# and the air is a steady stream with GUSTS riding on it — bumps of
			# extra speed that sweep downwind, so a grain near the front surges
			# first and one further along later, each 1/drag seconds behind the
			# air. sand is heavy, so it also sags, vy' = g − drag·vy. a press is
			# a lull: the air stops, the grit slows and sinks, then the wind returns.
			b.lull = maxf(0.0, b.lull - dt)
			b.scalm -= dt
			if b.sgust.is_empty() and b.scalm < 0.0:   # a gust starts upwind and travels downwind, always left to right here
				b.sgust = { "x": r.position.x - r.size.x * 0.3, "k": randf_range(80.0, 160.0) }
			if not b.sgust.is_empty():
				b.sgust.x += r.size.x * 0.6 * dt
				if b.sgust.x > r.end.x + r.size.x * 0.4:
					b.sgust = {}
					b.scalm = randf_range(1.0, 3.0)
			var g := 25.0                     # the sag (px/s²); each grain's drag sets how closely it follows the air
			var L := TextKit.layout(b)
			if b.worn.size() != L.size():
				b.worn = []
				for l in L:
					b.worn.append(0.0)
			if b.parts.size() < 40 and b.lull <= 0.0:   # recruited upwind, already moving with the stream
				b.parts.append({ "x": r.position.x - 4.0, "y": randf_range(r.position.y, r.end.y),
					"vx": randf_range(90.0, 150.0), "vy": 0.0, "drag": randf_range(3.0, 6.0) })
			for gr in b.parts:
				gr.vx += gr.drag * (storm_wind(b, gr.x) - gr.vx) * dt   # toward the local air, 1/drag seconds behind it
				gr.vy += (g - gr.drag * gr.vy) * dt                     # the sag, toward its slow terminal drop
				gr.x += gr.vx * dt
				gr.y += gr.vy * dt
				for l in L:                   # grit wears the letters as it passes
					if absf(gr.y - (l.y - b.base_size * 0.3)) < b.base_size * 0.5 and absf(gr.x - l.cx) < l.w:
						b.worn[l.i] = minf(1.0, b.worn[l.i] + dt * 2.0)
			b.parts = b.parts.filter(func(gr): return gr.x < r.end.x + 6.0 and gr.y < r.end.y + 6.0)
			for l in L:
				b.worn[l.i] = maxf(0.0, b.worn[l.i] - dt * 0.1)
		"ember_decay":
			# dials moved: burn direction bottom-up → top-down · particles rise → fall
			var cycle := fmod(t, 7.0) / 7.0
			var burn := cycle * 2.0 if cycle < 0.5 else (1.0 - cycle) * 2.0
			var L := TextKit.layout(b)
			for l in L:
				if l.ch == " ":
					continue
				var burn_line: float = l.y - b.base_size * 0.75 + b.base_size * 0.85 * burn    # the line DESCENDS
				if burn > 0.02 and burn < 0.98 and randf() < 0.25:
					b.parts.append({ "x": l.cx + randf_range(-l.w * 0.4, l.w * 0.4), "y": burn_line,
						"vy": randf_range(10.0, 26.0), "life": 1.0 })
			for a in b.parts:
				a.y += a.vy * dt
				a.x += sin(a.y * 0.15 + a.x) * 6.0 * dt
				a.life -= dt * 0.8
			b.parts = b.parts.filter(func(a): return a.life > 0.0 and a.y < r.end.y)
		"rain_reveal":
			# dials moved: fall speed ×0.5 · spawn a touch rarer · dry-out ×5 slower
			b.pour = maxf(0.0, b.pour - dt)
			var L := TextKit.layout(b)
			if b.wet.size() != L.size():
				b.wet = []
				for l in L:
					b.wet.append(0.0)
			if randf() < 0.25 + b.pour * 1.2:
				b.parts.append({ "x": randf_range(r.position.x, r.end.x), "y": r.position.y - 10.0,
					"v": randf_range(80.0, 130.0) })
			for d in b.parts:
				d.y += d.v * dt
				for l in L:
					if absf(d.x - l.cx) < l.w * 0.7 and d.y > l.y - b.base_size and d.y < l.y + 4.0:
						b.wet[l.i] = minf(1.0, b.wet[l.i] + dt * 8.0)
			b.parts = b.parts.filter(func(d): return d.y < r.end.y + 12.0)
			for l in L:
				b.wet[l.i] = maxf(0.0, b.wet[l.i] - dt * 0.05)     # sunlight lingers
		"confetti_pop":
			# dials moved: gravity ÷3 · drag softened · hop drains slower · a phase for the tail
			b.hop = maxf(0.0, b.hop - dt * 1.4)
			for rb in b.parts:
				rb.x += rb.vx * dt
				rb.y += rb.vy * dt
				rb.vy += 50.0 * dt
				rb.ph += dt * 9.0
				rb.life -= dt * 0.5
				rb.vx *= pow(0.6, dt)
			b.parts = b.parts.filter(func(rb): return rb.life > 0.0 and rb.y < r.end.y + 20.0)
		_:
			Base.tick(b, dt, t)

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	var bs: float = b.base_size
	match b.id:
		"star_assembly":
			TextKit.stage(n, b)
			for m in b.parts:
				TextKit.glow(n, Vector2(m.x, m.y), 2.5, Color(0.86, 0.86, 1.0, m.life * 0.8))
			var L := TextKit.layout(b)
			for l in L:
				TextKit.letter(n, l.ch, Vector2(l.x, l.y), bs, Color(TextKit.INK.r, TextKit.INK.g, TextKit.INK.b, b.solidity))
		"dust_burst":
			TextKit.stage(n, b)
			# dials moved: filled grains → outlined circles · the pop is a brief star
			var L := TextKit.layout(b)
			if b.gone > 0.0:
				for bub in b.parts:
					if bub.life > 0.0:
						n.draw_arc(Vector2(bub.x, bub.y), bub.r, 0.0, TAU, 24, Color(0.71, 0.86, 1.0, 0.8), 1.0)
					else:                     # the pop: a brief star
						TextKit.twinkle(n, Vector2(bub.x, bub.y), bub.r, Color(0.71, 0.86, 1.0, 0.8))
				var k: float = maxf(0.0, 1.0 - b.gone * 1.4)       # the phrase seeps back
				for l in L:
					TextKit.letter(n, l.ch, Vector2(l.x, l.y), bs, Color(TextKit.INK.r, TextKit.INK.g, TextKit.INK.b, minf(1.0, k)))
			else:
				for l in L:
					TextKit.letter(n, l.ch, Vector2(l.x, l.y), bs, TextKit.INK)
		"sparkle_crown":
			TextKit.stage(n, b)
			# dials moved: palette warm → ice · the frost twinkles grow diagonals
			var L := TextKit.layout(b)
			for l in L:
				var c: float = 0.0 if b.chill.is_empty() else b.chill[l.i]
				TextKit.letter(n, l.ch, Vector2(l.x, l.y), bs,
					Color((232.0 - c * 60.0) / 255.0, (229.0 - c * 20.0) / 255.0, 1.0))
			for s in b.parts:
				var size: float = s.s * sin(s.life * PI)
				var col := Color(0.78, 0.9, 1.0, 0.9)
				TextKit.twinkle(n, Vector2(s.x, s.y), size, col)
				n.draw_line(Vector2(s.x - size * 0.6, s.y - size * 0.6), Vector2(s.x + size * 0.6, s.y + size * 0.6), col, 1.0)
				n.draw_line(Vector2(s.x - size * 0.6, s.y + size * 0.6), Vector2(s.x + size * 0.6, s.y - size * 0.6), col, 1.0)
		"electron_letters":
			TextKit.stage(n, b)
			# dials moved: orbit glows → one lamp glow · letters brighten near the lamp · the moths' positions come from the ring spring in tick
			var lamp: Vector2 = b.lamp
			var L := TextKit.layout(b)
			for l in L:
				var k: float = maxf(0.0, 1.0 - absf(l.cx - lamp.x) / (bs * 2.5))
				TextKit.letter(n, l.ch, Vector2(l.x, l.y), bs, Color(TextKit.INK.r, TextKit.INK.g, TextKit.INK.b, 0.35 + k * 0.65))
			TextKit.glow(n, lamp, bs * 0.9, Color(1.0, 0.9, 0.63, 0.35))
			for m in b.parts:
				TextKit.glow(n, Vector2(m.x, m.y), 2.0, Color(1.0, 0.92, 0.71, 0.7))
		"snow_fill":
			TextKit.stage(n, b)
			# dials moved: white flakes → sand grains · whitening → a scoured, faded tint
			for g in b.parts:
				n.draw_rect(Rect2(Vector2(g.x, g.y), Vector2(2.2, 1.2)), Color(0.88, 0.78, 0.59, 0.7))
			var L := TextKit.layout(b)
			for l in L:
				var wgt: float = 0.0 if b.worn.is_empty() else b.worn[l.i]
				TextKit.letter_weight(n, l.ch, Vector2(l.x, l.y), bs,
					Color((232.0 - wgt * 30.0) / 255.0, (229.0 - wgt * 45.0) / 255.0, (244.0 - wgt * 90.0) / 255.0, 1.0 - wgt * 0.55), 600.0)
		"ember_decay":
			TextKit.stage(n, b)
			# dials moved: surviving share flips to 1 - burn · burn-line glow dropped · embers → grey ash
			var cycle := fmod(t, 7.0) / 7.0
			var burn := cycle * 2.0 if cycle < 0.5 else (1.0 - cycle) * 2.0
			var L := TextKit.layout(b)
			for l in L:
				if l.ch == " ":
					continue
				TextKit.letter(n, l.ch, Vector2(l.x, l.y), bs, Color(TextKit.INK.r, TextKit.INK.g, TextKit.INK.b, 1.0 - burn))
			for a in b.parts:
				n.draw_rect(Rect2(Vector2(a.x, a.y), Vector2(1.8, 1.8)), Color(0.67, 0.65, 0.63, 0.6))
		"rain_reveal":
			TextKit.stage(n, b)
			# dials moved: palette rain → sunlight · streaks longer and a shade wider
			for d in b.parts:
				n.draw_line(Vector2(d.x, d.y - 14.0), Vector2(d.x, d.y), Color(1.0, 0.86, 0.51, 0.45), 1.4)
			var L := TextKit.layout(b)
			for l in L:
				var w: float = 0.0 if b.wet.is_empty() else b.wet[l.i]
				var col: Color = Color(1.0, 0.94, 0.78, 0.15 + w * 0.85) if w > 0.02 else TextKit.DIM
				TextKit.letter(n, l.ch, Vector2(l.x, l.y), bs, col)
		"confetti_pop":
			TextKit.stage(n, b)
			# dials moved: spinning flecks → ribbons with a waving tail · hop ×0.75 height
			for rb in b.parts:
				var pts := PackedVector2Array()
				pts.append(Vector2(rb.x, rb.y))
				for s in range(1, 5):         # the tail waves behind the head
					pts.append(Vector2(rb.x - rb.vx * 0.02 * s + sin(rb.ph + s) * 3.0, rb.y - rb.vy * 0.02 * s - s * 3.0))
				var col: Color = rb.col
				n.draw_polyline(pts, Color(col.r, col.g, col.b, minf(1.0, rb.life)), 2.5)
			var jump: float = sin(minf(1.0, 1.0 - b.hop) * PI) * b.hop * bs * 0.3
			var L := TextKit.layout(b)
			for l in L:
				TextKit.letter_weight(n, l.ch, Vector2(l.x, l.y - jump * sin(float(l.i) / float(l.n - 1) * PI)),
					bs, TextKit.INK, 700.0 if b.hop > 0.0 else 400.0)
		_:
			Base.draw(n, b, t)

## Moth lamp's moths: one per letter, scattered over the card, each already on
## the wing — its velocity sideways to the lamp at the ring spring's own rate,
## so it circles rather than dives. `flit` is the timer to its next flutter.
static func moths(b: Dictionary) -> Array:
	var r: Rect2 = b.rect
	var lamp: Vector2 = b.lamp
	var r0: float = b.base_size * 0.7
	var out: Array = []
	for _i in TextKit.PHRASE.length():
		var p := Vector2(randf_range(r.position.x, r.end.x), randf_range(r.position.y, r.end.y))
		var rel := p - lamp
		var rr := maxf(1.0, rel.length())
		var sp: float = sqrt(30.0) * r0 * randf_range(0.6, 1.0) * (-1.0 if randf() < 0.5 else 1.0)
		out.append({ "x": p.x, "y": p.y, "vx": -rel.y / rr * sp, "vy": rel.x / rr * sp, "flit": randf_range(0.0, 0.4) })
	return out

## Sandstorm's air speed at x: still in a lull, else the steady stream plus
## any gust bump riding the front.
static func storm_wind(b: Dictionary, x: float) -> float:
	if b.lull > 0.0:
		return 0.0
	var mean := 150.0
	if b.sgust.is_empty():
		return mean
	var r: Rect2 = b.rect
	var d: float = (x - b.sgust.x) / (r.size.x * 0.2)
	return mean + b.sgust.k * exp(-d * d)
