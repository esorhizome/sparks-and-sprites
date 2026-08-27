extends RefCounted

const TextKit := preload("res://scenes/textfx/kit.gd")
const Base := preload("res://scenes/textfx/particle.gd")
## DUST & PARTICLES — the rhymes. Dials named per branch; the rest delegates.

const RHYMES := {
	"star_assembly": { "name": "Star scatter", "hint": "the cycle reversed — the phrase stands, sheds its letters as motes, and regathers" },
	"dust_burst": { "name": "Bubble burst", "hint": "gravity flipped — the letters burst into bubbles that rise and pop" },
	"sparkle_crown": { "name": "Frost sparkle", "hint": "cold twinkles at half the rate — and the letters blush blue where they land" },
	"electron_letters": { "name": "Moth lamp", "hint": "the orbits abandoned — the motes crowd toward one drifting lamp instead" },
	"snow_fill": { "name": "Sandstorm", "hint": "the snow turned sideways and hostile — grit streams past and scours the letters pale" },
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
		"snow_fill":
			b.worn = []

static func press(b: Dictionary, pos: Vector2) -> void:
	match b.id:
		"star_assembly":
			b.phase = 3.0                     # shed early
		"dust_burst":
			# dials moved: six grains → four bubbles · velocities gentled · life is a fuse
			var L := TextKit.layout(b)
			b.parts = []
			for l in L:
				if l.ch == " ":
					continue
				for i in 4:
					b.parts.append({ "x": l.cx + randf_range(-l.w, l.w) * 0.4,
						"y": l.y - randf_range(0.0, b.base_size * 0.6),
						"vx": randf_range(-15.0, 15.0), "vy": randf_range(-40.0, -15.0),
						"r": randf_range(2.0, 5.0), "life": randf_range(0.8, 1.6) })
			b.gone = 2.2
		"electron_letters":
			b.parts = []                      # startle them into new positions
		"snow_fill":
			b.worn = []                       # the wind drops for a moment; the letters recover
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
			# dials moved: converge → shed (targets swapped with sources) · the phrase dims as it sheds
			b.phase += dt
			if b.phase > 9.0:
				b.phase = 0.0
			var shedding: bool = b.phase > 3.0 and b.phase < 6.0
			var L := TextKit.layout(b)
			if shedding:
				b.solidity = maxf(0.0, b.solidity - dt * 0.5)
				if randf() < 0.7:
					var l: Dictionary = L[randi() % L.size()]
					if l.ch != " ":
						b.parts.append({ "x": l.cx, "y": l.y - b.base_size * 0.3,
							"tx": (r.position.x + randf_range(-20.0, 0.0)) if randf() < 0.5 else (r.end.x + randf_range(0.0, 20.0)),
							"ty": randf_range(r.position.y, r.end.y), "life": 1.0 })
			else:
				b.solidity = minf(1.0, b.solidity + dt * 0.6)
			for m in b.parts:
				m.x += (m.tx - m.x) * minf(1.0, dt * 1.2)
				m.y += (m.ty - m.y) * minf(1.0, dt * 1.2)
				m.life -= dt * 0.5
			b.parts = b.parts.filter(func(m): return m.life > 0.0)
		"dust_burst":
			# dials moved: gravity flipped — bubbles rise and wobble, then pop past life zero
			if b.gone > 0.0:
				b.gone -= dt
				for bub in b.parts:
					bub.x += bub.vx * dt + sin(bub.y * 0.1) * 6.0 * dt
					bub.y += bub.vy * dt
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
			# dials moved: per-letter orbits → shared attraction point (clumsy, moth-style)
			var L := TextKit.layout(b)
			if b.parts.is_empty():
				for l in L:
					b.parts.append({ "x": randf_range(r.position.x, r.end.x),
						"y": randf_range(r.position.y, r.end.y), "vx": 0.0, "vy": 0.0 })
			var lamp_x: float = r.get_center().x + sin(t * 0.5) * r.size.x * 0.3      # the lamp strolls
			var lamp_y: float = b.mid - b.base_size * 1.1 + sin(t * 0.9) * b.base_size * 0.4
			for m in b.parts:
				m.vx += (lamp_x - m.x) * 2.2 * dt + randf_range(-1.0, 1.0) * 30.0 * dt
				m.vy += (lamp_y - m.y) * 2.2 * dt + randf_range(-1.0, 1.0) * 30.0 * dt
				m.vx *= pow(0.5, dt)
				m.vy *= pow(0.5, dt)
				m.x += m.vx * dt
				m.y += m.vy * dt
		"snow_fill":
			# dials moved: fall vertical → horizontal stream · fill-up → scour (worn per letter)
			var L := TextKit.layout(b)
			if b.worn.size() != L.size():
				b.worn = []
				for l in L:
					b.worn.append(0.0)
			if b.parts.size() < 40:
				b.parts.append({ "x": r.position.x - 4.0, "y": randf_range(r.position.y, r.end.y),
					"v": randf_range(120.0, 240.0), "life": 1.0 })
			for g in b.parts:
				g.x += g.v * dt
				g.y += sin(g.x * 0.05) * 10.0 * dt
				for l in L:                   # grit wears the letters as it passes
					if absf(g.y - (l.y - b.base_size * 0.3)) < b.base_size * 0.5 and absf(g.x - l.cx) < l.w:
						b.worn[l.i] = minf(1.0, b.worn[l.i] + dt * 2.0)
			b.parts = b.parts.filter(func(g): return g.x < r.end.x + 6.0)
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
			# dials moved: orbit glows → one lamp glow · letters brighten near the lamp
			var r: Rect2 = b.rect
			var lamp_x: float = r.get_center().x + sin(t * 0.5) * r.size.x * 0.3
			var lamp_y: float = b.mid - bs * 1.1 + sin(t * 0.9) * bs * 0.4
			var L := TextKit.layout(b)
			for l in L:
				var k: float = maxf(0.0, 1.0 - absf(l.cx - lamp_x) / (bs * 2.5))
				TextKit.letter(n, l.ch, Vector2(l.x, l.y), bs, Color(TextKit.INK.r, TextKit.INK.g, TextKit.INK.b, 0.35 + k * 0.65))
			TextKit.glow(n, Vector2(lamp_x, lamp_y), bs * 0.9, Color(1.0, 0.9, 0.63, 0.35))
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
