extends RefCounted

const CubeKit := preload("res://scenes/cubefx/kit.gd")
## EARTH & NATURE — eight cube effects, ported from the web codex.

const TITLE := "Earth & nature"
const BLURB := "rocks thrown, vines called, flowers left behind"
const DEFS := [
	{ "id": "rock_throw", "name": "Rock throw", "hint": "a pebble orbits, waiting; press to lob the real boulder" },
	{ "id": "vine_snare", "name": "Vine snare", "hint": "press: three flat vines where you click get kicked upright — chains that whip past vertical, settle, lie back down" },
	{ "id": "leaf_whirl", "name": "Leaf whirl", "hint": "leaves orbit like a green satellite belt; press for the storm" },
	{ "id": "boulder_shield", "name": "Boulder shield", "hint": "press: four rocks rise and orbit as armour for a while" },
	{ "id": "bloom_trail", "name": "Bloom trail", "hint": "flowers open in its footsteps; press for a whole garden" },
	{ "id": "sand_kick", "name": "Sand kick", "hint": "press: a spray of sand, straight at the opponent's eyes" },
	{ "id": "quake_slam", "name": "Quake slam", "hint": "press: fists down — a hump of ground ROLLS away from it" },
	{ "id": "thorn_wall", "name": "Thorn wall", "hint": "press: a fence of thorns rises ahead, holds, and sinks" },
]

static func init(b: Dictionary) -> void:
	b.press_v = 0.0
	b.parts = []
	match b.id:
		"vine_snare":
			# the old vines rose on a sine envelope and writhed on the clock. here each
			# vine is a Grass blade — a chain of angles from upright, every joint a
			# damped spring chasing the one below — that starts LYING FLAT. the press
			# kicks the root; the spring toward upright does the rest, and because the
			# joints are lighter and less damped than the root, the tips arrive late
			# and overshoot past vertical before settling: the writhe is the settle.
			# when life runs out the rest angle goes back to flat, and they lie down.
			b.D = { "joints": 3,             # segments per vine
				"len": 0.6,                  # each segment's length, in cube-sides (three reach 1.8 sides)
				"k": 60.0,                   # the root spring's stiffness — the vine rights itself with this
				"damp": 0.45,                # the root's damping as a fraction of critical — under 1: it swings past vertical
				"tip": 1.4,                  # each joint's k as a multiple of the one below (lighter up there)
				"tipdamp": 0.4,              # a joint's damping as a fraction of ITS OWN critical — the tip whips through
				"bend": 1.5,                 # the most a joint can fold past the one below, radians
				"flat": 1.5,                 # where a vine lies before the press, radians from upright
				"kick": 3.0,                 # the press's impulse on each root, rad/s — the eruption is a shove, not a tween
				"life": 1.6,                 # seconds before the vines lie back down
				"splay": 0.08 }              # the outer vines' resting lean away from the middle one, radians
		"leaf_whirl":
			b.leaves = []
			for i in 8:
				b.leaves.append({ "a": randf_range(0, TAU), "r": randf_range(0.9, 1.3),
					"v": randf_range(1.0, 1.8), "burst": 0.0 })
		"boulder_shield":
			b.armour = 0.0
		"bloom_trail":
			b.blooms = []
			b.last_x = b.cub.x
			b.travelled = 0.0

static func press(b: Dictionary, pos: Vector2) -> void:
	var c: Dictionary = b.cub
	var r: Rect2 = b.rect
	match b.id:
		"rock_throw":
			b.parts.append({ "kind": "rock", "pos": Vector2(c.x + c.face * c.s * 0.5, c.y - c.s),
				"vel": Vector2(c.face * randf_range(120, 160), -170.0), "rot": 0.0, "life": 9.0 })
		"vine_snare":
			var D: Dictionary = b.D
			var J: int = D.joints
			var th := PackedFloat32Array()   # vine-major: [v * J + j], angles from upright, and their rates
			var om := PackedFloat32Array()
			th.resize(3 * J)
			om.resize(3 * J)
			var flat: float = D.flat
			for v in 3:
				var dir: float = -1.0 if v == 1 else 1.0    # the middle one lies the other way
				for j in J:
					th[v * J + j] = dir * flat
				om[v * J] = -dir * float(D.kick)            # the shove, at the root only
			b.parts.append({ "kind": "snare", "x": clampf(pos.x, r.position.x + 10, r.position.x + r.size.x - 10),
				"life": float(D.life), "th": th, "om": om })
		"leaf_whirl":
			for l in b.leaves:
				l.burst = 1.0
		"boulder_shield":
			b.armour = 3.0
		"bloom_trail":
			for i in 6:
				b.blooms.append({ "x": clampf(c.x + randf_range(-c.s * 2.4, c.s * 2.4),
					r.position.x + 6, r.position.x + r.size.x - 6), "open": 0.0, "hue": randf_range(0.83, 1.0), "big": true })
		"sand_kick":
			c.lean = -c.face * 0.15
			for i in 20:
				b.parts.append({ "kind": "grain", "pos": Vector2(c.x + c.face * c.s * 0.4, b.G - 2.0),
					"vel": Vector2(c.face * randf_range(70, 180), randf_range(-110, -30)), "life": 1.0 })
		"quake_slam":
			b.parts.append({ "kind": "hump", "x": c.x, "dir": c.face, "life": 1.0 })
		"thorn_wall":
			b.parts.append({ "kind": "wall", "x": c.x + c.face * c.s * 1.8, "life": 2.2 })

static func tick(b: Dictionary, dt: float, t: float) -> void:
	var c: Dictionary = b.cub
	b.press_v = maxf(0.0, b.press_v - dt * 1.6)
	match b.id:
		"rock_throw":
			for p in b.parts:
				if p.kind == "rock":
					p.pos += p.vel * dt
					p.vel.y += 340.0 * dt
					p.rot += 4.0 * dt
					if p.pos.y >= b.G - 4.0:
						for i in 7:
							b.parts.append({ "kind": "shard", "pos": Vector2(p.pos.x, b.G),
								"vel": Vector2(randf_range(-80, 80), randf_range(-120, -30)), "life": 1.0 })
						p.life = 0.0
				else:
					p.pos += p.vel * dt
					p.vel.y += 300.0 * dt
					p.life -= dt * 1.5
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		"thorn_wall":
			for p in b.parts:
				p.life -= dt * 0.6
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		"vine_snare":
			var D: Dictionary = b.D
			var J: int = D.joints
			var kk: float = D.k
			var damp: float = D.damp
			var tip: float = D.tip
			var tipdamp: float = D.tipdamp
			var bend: float = D.bend
			var flat: float = D.flat
			var splay: float = D.splay
			var sub := maxi(1, ceili(dt * 50.0))   # the springs' substep guard: ≤ 0.02 s a step
			var h := dt / float(sub)
			for p in b.parts:
				p.life -= dt
				var th: PackedFloat32Array = p.th
				var om: PackedFloat32Array = p.om
				for v in 3:
					var dir: float = -1.0 if v == 1 else 1.0
					var rest: float = (v - 1) * splay if p.life > 0.5 else dir * flat   # upright while alive; back to flat to withdraw
					for _s in sub:
						var below := rest
						var kj := kk
						var dj := damp * 2.0 * sqrt(kk)
						for j in J:
							var i := v * J + j
							if j > 0:
								kj *= tip                        # quicker with every joint up (lighter segment, same bend)
								dj = tipdamp * 2.0 * sqrt(kj)    # a fraction of THIS joint's critical damping
							om[i] += (kj * (below - th[i]) - dj * om[i]) * h
							var a: float = th[i] + om[i] * h
							if j > 0:
								a = clampf(a, below - bend, below + bend)
							th[i] = clampf(a, -1.6, 1.6)         # never below the floor
							below = th[i]
			b.parts = b.parts.filter(func(p): return p.life > -0.4)
		"leaf_whirl":
			for l in b.leaves:
				l.burst = maxf(0.0, l.burst - dt * 0.7)
				l.a += l.v * (1.0 + l.burst * 3.0) * dt
		"boulder_shield":
			b.armour = maxf(0.0, b.armour - dt)
		"bloom_trail":
			b.travelled += absf(c.x - b.last_x)
			b.last_x = c.x
			while b.travelled > 26.0:
				b.travelled -= 26.0
				b.blooms.append({ "x": c.x, "open": 0.0, "hue": randf_range(0.83, 1.0), "big": false })
			for bl in b.blooms:
				bl.open = minf(1.0, bl.open + dt * (3.0 if bl.big else 1.2))
			while b.blooms.size() > 20:
				b.blooms.pop_front()
		"sand_kick":
			if randf() < 0.08:
				b.parts.append({ "kind": "grain", "pos": Vector2(c.x + randf_range(-c.s * 0.4, c.s * 0.4), c.y - c.s),
					"vel": Vector2(0, 20), "life": 0.8 })
			for p in b.parts:
				p.pos += p.vel * dt
				p.vel.y += 300.0 * dt
				p.pos.y = minf(p.pos.y, b.G)
				p.life -= dt * 1.4
			b.parts = b.parts.filter(func(p): return p.life > 0.0)
		"quake_slam":
			var r: Rect2 = b.rect
			for p in b.parts:
				p.x += p.dir * 120.0 * dt
				p.life -= dt * 0.8
			b.parts = b.parts.filter(func(p): return p.life > 0.0 and p.x > r.position.x - 20 and p.x < r.position.x + r.size.x + 20)
			# the hero rides its own quake
			var lift := 0.0
			for p in b.parts:
				lift = maxf(lift, maxf(0.0, 10.0 - absf(c.x - p.x) * 0.4) * p.life)
			c.y = b.G - lift

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	var c: Dictionary = b.cub
	CubeKit.stage(n, b)
	match b.id:
		"rock_throw":
			CubeKit.draw_cube(n, b)
			var pa: float = t * 2.4
			n.draw_circle(Vector2(c.x + cos(pa) * c.s * 0.9, c.y - c.s * 0.6 + sin(pa) * c.s * 0.5),
				2.5, Color(0.48, 0.43, 0.37))
			for p in b.parts:
				if p.kind == "rock":
					n.draw_set_transform(p.pos, p.rot, Vector2.ONE)
					n.draw_colored_polygon(PackedVector2Array([
						Vector2(-6, -4), Vector2(5, -6), Vector2(7, 3), Vector2(-2, 6), Vector2(-7, 2)]),
						Color(0.48, 0.43, 0.37))
					n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				else:
					n.draw_rect(Rect2(p.pos, Vector2(2.5, 2.5)), Color(0.48, 0.43, 0.37, p.life))
		"vine_snare":
			CubeKit.draw_cube(n, b)
			n.draw_set_transform(Vector2(c.x + c.s * 0.25, c.y - c.s - c.hop), 0.5 + sin(t * 2.0) * 0.15, Vector2(1.0, 0.45))
			n.draw_circle(Vector2(3, 0), 4.0, Color(0.43, 0.7, 0.43, 0.9))
			n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			var J: int = b.D.joints
			var L: float = c.s * float(b.D.len)
			for p in b.parts:
				var th: PackedFloat32Array = p.th
				for v in 3:
					var pts := PackedVector2Array()
					var pt := Vector2(p.x + (v - 1) * 5.0, b.G)
					pts.append(pt)
					for j in J:                          # walk the chain up from the ground
						var a: float = th[v * J + j]
						pt += Vector2(sin(a), -cos(a)) * L
						pts.append(pt)
					n.draw_polyline(pts, Color(0.35, 0.63, 0.35, clampf(p.life + 0.4, 0.0, 1.0)), 3.0)
		"leaf_whirl":
			CubeKit.draw_cube(n, b)
			for l in b.leaves:
				var rr: float = c.s * l.r * (1.0 + l.burst * 1.4)
				n.draw_set_transform(Vector2(c.x + cos(l.a) * rr, c.y - c.s * 0.5 + sin(l.a) * rr * 0.55),
					l.a + t, Vector2(1.0, 0.45))
				n.draw_circle(Vector2.ZERO, 4.0, Color(0.47, 0.73, 0.43, 0.85))
				n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"boulder_shield":
			n.draw_set_transform(Vector2(c.x, b.G + 2.0), 0.0, Vector2(1.0, 0.2))
			n.draw_circle(Vector2.ZERO, c.s * 0.9, Color(0.59, 0.53, 0.47, 0.15))
			n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			CubeKit.draw_cube(n, b)
			if b.armour > 0.0:
				var rise: float = minf(1.0, (3.0 - b.armour) * 3.0)
				for i in 4:
					var a: float = t * 2.2 + i / 4.0 * TAU
					n.draw_set_transform(Vector2(c.x + cos(a) * c.s * 1.15,
						c.y - c.s * 0.5 * rise + sin(a) * c.s * 0.5 + (1.0 - rise) * 10.0), a, Vector2.ONE)
					n.draw_colored_polygon(PackedVector2Array([
						Vector2(-5, -3), Vector2(4, -5), Vector2(6, 3), Vector2(-3, 5)]),
						Color(0.48, 0.43, 0.37, minf(1.0, b.armour)))
					n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"bloom_trail":
			for bl in b.blooms:
				var s: float = (5.0 if bl.big else 3.5) * bl.open
				for p in 5:
					var th: float = p / 5.0 * TAU - PI / 2.0
					n.draw_set_transform(Vector2(bl.x + cos(th) * s * 0.7, b.G - 2.0 + sin(th) * s * 0.4),
						th, Vector2(1.0, 0.55))
					n.draw_circle(Vector2.ZERO, s * 0.5, Color.from_hsv(bl.hue, 0.35, 0.95, 0.9))
					n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				n.draw_circle(Vector2(bl.x, b.G - 2.0), s * 0.3, Color(1, 0.92, 0.59, 0.95))
			CubeKit.draw_cube(n, b)
		"sand_kick":
			CubeKit.draw_cube(n, b)
			for p in b.parts:
				n.draw_rect(Rect2(p.pos, Vector2(1.6, 1.6)), Color(0.82, 0.73, 0.55, p.life * 0.8))
		"quake_slam":
			# repaint the floor with the wave in it
			var r: Rect2 = b.rect
			var pts := PackedVector2Array()
			var x: float = r.position.x
			while x <= r.position.x + r.size.x:
				var y: float = b.G
				for p in b.parts:
					y -= maxf(0.0, 10.0 - absf(x - p.x) * 0.4) * p.life
				pts.append(Vector2(x, y))
				x += 4.0
			n.draw_polyline(pts, Color(0.59, 0.57, 0.75, 0.35), 1.0)
			CubeKit.draw_cube(n, b)
		"thorn_wall":
			CubeKit.draw_cube(n, b)
			for i in range(-1, 2):
				n.draw_line(Vector2(c.x + i * 10.0, b.G),
					Vector2(c.x + i * 10.0 + 2.0, b.G - 4.0 - sin(t * 2.0 + i) * 1.0),
					Color(0.43, 0.59, 0.35, 0.5), 1.5)
			for p in b.parts:
				var up: float = minf(1.0, minf((2.2 - p.life) * 2.4, p.life * 2.0))
				for i in range(-2, 3):
					var hgt: float = (c.s * 1.5 - absf(i) * 6.0) * up
					n.draw_colored_polygon(PackedVector2Array([
						Vector2(p.x + i * 9.0 - 4.0, b.G), Vector2(p.x + i * 9.0, b.G - hgt),
						Vector2(p.x + i * 9.0 + 4.0, b.G)]),
						Color(0.37, 0.55, 0.31, minf(1.0, p.life)))
