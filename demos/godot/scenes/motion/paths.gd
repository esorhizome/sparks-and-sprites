extends RefCounted

const Kit := preload("res://scenes/motion/kit.gd")
## PATHS, GRIDS & SCHEDULES — ten movement styles, ported from the web
## lexicon (docs/locomotion.js). A route REMEMBERED. The clocks stored
## nothing and the springs stored a velocity; these bodies store a LIST —
## waypoints, control points, grid cells, floors, keyframes, throws — plus
## one number saying how far along it they are. "Where am I" becomes a
## bookmark instead of a coordinate: a distance along a spline, a cell in a
## maze, a beat in a timetable. A*, a Bézier, Frogger, Pac-Man, a lift, and
## a juggler are all the same bookmark being moved.

const TITLE := "Paths, grids & schedules"
const BLURB := "a route remembered — waypoints, splines, grids, floors, keyframes, throws, plus one number saying how far along"
const DEFS := [
	{ "id": "astar", "letter": "A", "name": "Astar",
		"hint": "a* on a walled grid — f = g + h, with the open and closed sets on show — press to set the goal, or to open a wall you click",
		"dials": { "cols": 12, "rows": 8, "seed": 7, "wallChance": 0.26,   # the maze: seeded, so it is the same on every visit
			"greed": 1.0,                                                    # weight on h — 1 is honest A*, more is greedy
			"hopTime": 0.22, "hopLift": 0.35, "pause": 1.1,                  # the walk: seconds per cell, lift in cells, rest at the goal
			"label": "f = g + h · h = |dx| + |dy| (Manhattan)" },
		"rhyme": { "name": "Anthill", "hint": "a denser maze and a greedier h (×2.5) at scurrying speed — fewer cells inspected, and not always the shortest way",
			"dials": { "wallChance": 0.36, "greed": 2.5, "hopTime": 0.1 } } },
	{ "id": "bezier", "letter": "B", "name": "Bezier", "drag": true,
		"hint": "a cubic bézier is three lerps deep — de casteljau's scaffold drawn live at k — drag to move the nearest handle",
		"dials": { "p0": [0.08, 0.76], "p1": [0.2, 0.08], "p2": [0.8, 0.08], "p3": [0.92, 0.76],   # control points, fractions of W and H
			"period": 3.2,                                                   # seconds per flight, end to end
			"label": "B(k): three lerps deep — de Casteljau" },
		"rhyme": { "name": "Barrelroll", "hint": "the handles swapped to the far corners so the curve crosses itself — a loop-the-loop, flown at a faster clip",
			"dials": { "p1": [0.98, 0.15], "p2": [0.02, 0.15], "period": 2.2 } } },
	{ "id": "path", "letter": "P", "name": "Path",
		"hint": "a catmull-rom spline walked by arc length; the ghost walks by parameter and bunches — press to add or move a waypoint",
		"dials": { "pts": [[0.15, 0.5], [0.32, 0.2], [0.62, 0.24], [0.86, 0.5], [0.66, 0.8], [0.36, 0.76]],   # waypoints, a closed loop
			"tension": 0.5,                                                  # 0.5 is Catmull-Rom; more overshoots, less cuts corners
			"speed": 0.35,                                                   # fraction of W per second
			"samples": 16, "grab": 0.06, "maxPts": 10,
			"label": "arc length: s → (segment, k) via a table" },
		"rhyme": { "name": "Pretzel", "hint": "tension doubled and the walk faster — the spline overshoots every waypoint into loops; arc length keeps the pace honest",
			"dials": { "tension": 1.1, "speed": 0.5 } } },
	{ "id": "kart", "letter": "K", "name": "Kart",
		"hint": "rubber-band ai: speed = base + gain · gap behind the leader, nobody escapes (Path + Arrive) — press to shove the nearest kart",
		"dials": { "n": 4, "base": 0.3, "gain": 0.4, "leaderDrag": 0.9, "spread": 0.12,   # speeds in W per second; the gap is a fraction of a lap
			"shove": 0.5, "wobble": 0.05, "rx": 0.36, "ry": 0.28, "lanes": 7, "seed": 11,   # lanes: each kart's own sideways offset, px
			"label": "v = base + gain · (gap behind the leader)" },
		"rhyme": { "name": "Kingpin", "hint": "the band cut (gain 0, no leader throttle) and personal speeds spread wider — the quick kart laps the field, the pack strings out",
			"dials": { "gain": 0.0, "leaderDrag": 1.0, "spread": 0.25 } } },
	{ "id": "frog", "letter": "F", "name": "Frog",
		"hint": "hops are fixed-clock grid steps; a log is a moving frame the frog inherits (Jump + Platform + Nest) — press to hop toward your click",
		"dials": { "cols": 9, "rows": 5, "hopTime": 0.2, "hopLift": 0.6,           # rows: a far bank, water lanes, a home bank
			"logLen": 2.2, "logGap": 2.4, "speeds": [0.9, -1.3, 1.6],            # logs in cells; lane speeds in cells per second, top lane first
			"autoWait": 0.8, "seed": 5,
			"label": "on a log: x += log.v · dt (a moving frame)" },
		"rhyme": { "name": "Frenzy", "hint": "logs twice as fast and shorter, hops quicker — frogger on its hardest wave",
			"dials": { "speeds": [1.8, -2.4, 3.0], "logLen": 1.4, "hopTime": 0.14 } } },
	{ "id": "grid", "letter": "G", "name": "Grid",
		"hint": "pac-man lanes: move_toward the next centre, turn only there, buffer the wish early (Lerp) — press to set the desired direction",
		"dials": { "map": ["###########",
				"#.........#",
				"#.###.###.#",
				"#.#.....#.#",
				"#.#.###.#.#",
				"#.........#",
				"###########"],
			"speed": 3.4,                                                    # cells per second
			"bufferTime": 1.2,                                               # a buffered turn is forgotten after this long
			"autoWait": 2.5, "pelletR": 0.09,
			"label": "move_toward the next centre · turn at centres" },
		"rhyme": { "name": "Gauntlet", "hint": "a different maze with long open corridors and a faster mote — more intersections, more buffered turns",
			"dials": { "map": ["###########",
					"#....#....#",
					"#.##.#.##.#",
					"#.........#",
					"#.##.#.##.#",
					"#....#....#",
					"###########"],
				"speed": 5.5 } } },
	{ "id": "platform", "letter": "P", "name": "Platform",
		"hint": "a sine platform, a waypoint platform, a rider that inherits whichever it stands on (Hover + Zigzag + Jump) — press to make it jump",
		"dials": { "g": 2.2, "jumpH": 0.3,                                                    # gravity in H per s², the apex as a fraction of H
			"platW": 0.22, "sineX": 0.28, "sineY": 0.66, "sineAmp": 0.14, "sinePeriod": 3.4,   # platform A: a sine sway
			"wp": [[0.62, 0.66], [0.88, 0.52], [0.66, 0.44]], "legSpeed": 0.3, "legPause": 0.5,   # platform B: waypoints, eased legs
			"maxKick": 0.9, "autoWait": 1.4,                                             # the kick's limit (W per s), seconds before it jumps by itself
			"label": "inherit v · solve T: v₀T + ½gT² = Δy" },
		"rhyme": { "name": "Parkour", "hint": "narrow platforms, a fast sway, a higher apex — the rider has to time its kicks, and every miss costs a respawn",
			"dials": { "platW": 0.14, "sinePeriod": 1.6, "jumpH": 0.38 } } },
	{ "id": "keyframe", "letter": "K", "name": "Keyframe",
		"hint": "keyframes replay a pose list; the spring twin adapts when the target moves and the replay cannot — press to move the target",
		"dials": { "keys": [[0.0, 0.2, 0.55], [0.8, 0.5, 0.25], [1.6, 0.8, 0.55], [2.4, 0.5, 0.82], [3.2, 0.2, 0.55]],   # time, x, y — the last key loops to the first
			"easing": "smooth", "tempo": 1.0,                                # smooth or linear between keys; playback speed
			"omega": 8.0, "zeta": 1.0, "hold": 3.0,                          # the procedural twin's spring, and how long a press holds the target
			"label": "lerp(keyᵢ, keyᵢ₊₁, ease(k))  vs  a spring" },
		"rhyme": { "name": "Kinetoscope", "hint": "linear easing at double tempo, and a bouncy twin — the replay snaps between poses like an old film loop",
			"dials": { "easing": "linear", "tempo": 2.0, "zeta": 0.35 } } },
	{ "id": "elevator", "letter": "E", "name": "Elevator",
		"hint": "a trapezoidal velocity profile: accelerate, cruise, brake to land exactly on the floor — press to call it to the nearest floor",
		"dials": { "floors": 4, "accel": 1.2, "vmax": 0.5,                   # fractions of H per second² and per second
			"dwell": 1.2, "schedule": [2, 0, 3, 1],                          # the floors it visits on its own, in order
			"label": "accel a · cruise vmax · brake a · exact stop" },
		"rhyme": { "name": "Express", "hint": "vmax and a both far higher — the trapezoid sharpens into a spike and the car whooshes between floors",
			"dials": { "vmax": 1.3, "accel": 3.2 } } },
	{ "id": "juggle", "letter": "J", "name": "Juggle",
		"hint": "a cascade: v₀ = √(2gh) and a beat that interleaves the throws, every ball a formula of t (Jump + Orbit) — press to set the height",
		"dials": { "balls": 3, "height": 0.42, "g": 2.4, "dwell": 1.0,       # apex as a fraction of H, gravity in H per s², dwell in beats
			"hy": 0.7, "handGap": 0.22, "scoop": 0.06,                       # the hands: height, half the distance between them, the scoop ellipse
			"label": "v₀ = √(2gh) · beat = flight ÷ (n − dwell)" },
		"rhyme": { "name": "Jester", "hint": "five balls thrown higher — the same beat arithmetic with n = 5, a court jester's showpiece",
			"dials": { "balls": 5, "height": 0.6 } } },
]

## The web kit's `len(...) || 1`: a zero length becomes 1 so divisions stay safe.
static func _or1(x: float) -> float:
	return x if x != 0.0 else 1.0

## The web label's "right" alignment — Kit.label only knows left and centre.
static func _label_right(n: CanvasItem, txt: String, p: Vector2, col: Color) -> void:
	var f := ThemeDB.fallback_font
	var x := p.x - f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	n.draw_string(f, Vector2(x, p.y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, col)

# ---- Astar: pathfinding on a grid, the open and closed sets on show ----
static func _astar_id(b: Dictionary, c: Vector2i) -> int:
	return c.y * int(b.D.cols) + c.x

static func _astar_c(b: Dictionary, c: Vector2i) -> Vector2:          # the cell's centre
	return Vector2((c.x + 0.5) * b.cw, (c.y + 0.5) * b.ch)

static func _astar_h(b: Dictionary, i: int, to: Vector2i) -> float:   # Manhattan, weighted by greed
	var cols: int = b.D.cols
	return (absi(i % cols - to.x) + absi(floori(i / float(cols)) - to.y)) * float(b.D.greed)

## Returns the path as a list of cells, or an empty list when there is none (the JS null).
static func _astar_search(b: Dictionary, from: Vector2i, to: Vector2i) -> Array:
	var cols: int = b.D.cols
	var rows: int = b.D.rows
	var N: int = b.N
	var walls: Array = b.walls
	var g: Array = []
	var came: Array = []
	var open: Array = []
	b.state = []
	for i in N:
		g.append(INF)
		came.append(-1)
		b.state.append(0)
	var state: Array = b.state
	g[_astar_id(b, from)] = 0.0
	open.append(_astar_id(b, from))
	state[_astar_id(b, from)] = 1
	var found := false
	while not open.is_empty():
		var bi := 0                                          # the cheapest f in the open set
		for i in range(1, open.size()):
			if g[open[i]] + _astar_h(b, open[i], to) < g[open[bi]] + _astar_h(b, open[bi], to):
				bi = i
		var cur: int = open[bi]
		open[bi] = open[open.size() - 1]
		open.pop_back()
		state[cur] = 2                                       # inspected: closed
		if cur == _astar_id(b, to):
			found = true
			break
		var cc := cur % cols
		var cr := floori(cur / float(cols))
		var nb := [Vector2i(cc + 1, cr), Vector2i(cc - 1, cr), Vector2i(cc, cr + 1), Vector2i(cc, cr - 1)]
		for nn in nb:
			if nn.x < 0 or nn.y < 0 or nn.x >= cols or nn.y >= rows:
				continue
			var ni := _astar_id(b, nn)
			if walls[ni] or state[ni] == 2:
				continue
			if g[cur] + 1.0 < g[ni]:                         # a better way to reach it
				g[ni] = g[cur] + 1.0
				came[ni] = cur
				if state[ni] != 1:
					state[ni] = 1
					open.append(ni)
	if not found:
		return []
	var p: Array = []                                        # walk the breadcrumbs back
	var j: int = _astar_id(b, to)
	while j >= 0:
		p.append(Vector2i(j % cols, floori(j / float(cols))))
		j = came[j]
	p.reverse()
	return p

static func _astar_replan(b: Dictionary) -> void:
	var hop: Dictionary = b.hop
	var from: Vector2i = hop.to if not hop.is_empty() else b.cell   # mid-hop, plan from where the hop lands
	b.path = _astar_search(b, from, b.goal)
	b.pi = 0
	if (b.path as Array).is_empty():
		b.wait = b.D.pause

static func _astar_new_goal(b: Dictionary) -> void:           # a random open cell it can actually reach
	for tries in 20:
		var c := Vector2i(randi() % int(b.D.cols), randi() % int(b.D.rows))
		if b.walls[_astar_id(b, c)] or c == b.cell or _astar_search(b, b.cell, c).is_empty():
			continue
		b.goal = c
		return

# ---- Bezier: a curve that is nothing but lerps ----
static func _bez_ladder(P: Array, k: float) -> Dictionary:
	var q0: Vector2 = (P[0] as Vector2).lerp(P[1], k)         # one lerp deep
	var q1: Vector2 = (P[1] as Vector2).lerp(P[2], k)
	var q2: Vector2 = (P[2] as Vector2).lerp(P[3], k)
	var r0 := q0.lerp(q1, k)                                  # two deep
	var r1 := q1.lerp(q2, k)
	return { "q": [q0, q1, q2], "r": [r0, r1], "b": r0.lerp(r1, k) }   # three deep: the curve

# ---- Path: a cardinal spline, measured into an arc-length table ----
static func _path_pts(b: Dictionary) -> Array:
	var out: Array = []
	for p in b.D.pts:
		out.append(Vector2(p[0] * b.w, p[1] * b.h))
	return out

static func _path_at(b: Dictionary, i: int, k: float) -> Vector2:   # the Hermite cubic on piece i
	var pts: Array = b.pts
	var cnt := pts.size()
	var tension: float = b.D.tension
	var p0: Vector2 = pts[(i - 1 + cnt) % cnt]
	var p1: Vector2 = pts[i % cnt]
	var p2: Vector2 = pts[(i + 1) % cnt]
	var p3: Vector2 = pts[(i + 2) % cnt]
	var m1 := tension * (p2 - p0)
	var m2 := tension * (p3 - p1)
	var k2 := k * k
	var k3 := k2 * k
	var h00 := 2.0 * k3 - 3.0 * k2 + 1.0
	var h10 := k3 - 2.0 * k2 + k
	var h01 := -2.0 * k3 + 3.0 * k2
	var h11 := k3 - k2
	return h00 * p1 + h10 * m1 + h01 * p2 + h11 * m2

static func _path_measure(b: Dictionary) -> void:            # the arc-length table
	var samples: int = b.D.samples
	b.table = []
	b.total = 0.0
	var prev := _path_at(b, 0, 0.0)
	for i in (b.pts as Array).size():
		for j in range(1, samples + 1):
			var p := _path_at(b, i, j / float(samples))
			b.total += p.distance_to(prev)
			b.table.append({ "s": b.total, "i": i, "k": j / float(samples), "p": p })
			prev = p
	if b.total < 1.0:
		b.total = 1.0

static func _path_lookup(b: Dictionary, d: float) -> Vector2:   # distance → (piece, k) → point
	var table: Array = b.table
	var total: float = b.total
	var dd := fposmod(d, total)
	var lo := 0
	while lo < table.size() - 1 and table[lo].s < dd:
		lo += 1
	var a: Dictionary = table[lo - 1] if lo > 0 else { "s": 0.0, "i": 0, "k": 0.0 }
	var e: Dictionary = table[lo]
	var f: float = (dd - a.s) / maxf(1e-6, e.s - a.s)
	var ak: float = a.k if a.i == e.i else 0.0
	return _path_at(b, e.i, lerpf(ak, e.k, f))

# ---- Kart: the track is a bookmark — one distance along the lap ----
static func _kart_place(b: Dictionary, s: float) -> Vector3:   # distance along the lap → (x, y, heading)
	var cx: float = b.cx
	var cy: float = b.cy
	var hs: float = b.hs
	var r: float = b.r
	var L: float = b.L
	var ss := fposmod(s, L)
	if ss < 2.0 * hs:
		return Vector3(cx - hs + ss, cy - r, 0.0)
	ss -= 2.0 * hs
	if ss < PI * r:
		var an := -PI / 2.0 + ss / r
		return Vector3(cx + hs + cos(an) * r, cy + sin(an) * r, an + PI / 2.0)
	ss -= PI * r
	if ss < 2.0 * hs:
		return Vector3(cx + hs - ss, cy + r, PI)
	ss -= 2.0 * hs
	var an2 := PI / 2.0 + ss / r
	return Vector3(cx - hs + cos(an2) * r, cy + sin(an2) * r, an2 + PI / 2.0)

static func _kart_spot(b: Dictionary, k: Dictionary) -> Vector3:   # a kart's place, nudged into its own lane
	var p := _kart_place(b, k.s)
	var lane: float = k.lane
	return Vector3(p.x + cos(p.z + PI / 2.0) * lane, p.y + sin(p.z + PI / 2.0) * lane, p.z)

# ---- Frog: logs are a schedule, a pure formula of t ----
static func _frog_log_left(b: Dictionary, ln: Dictionary, j: int, t: float) -> float:   # log j of a lane at time t
	var wrapL: float = ln.n * ln.period
	var lx := fmod(ln.phase + ln.v * t + j * ln.period, wrapL)
	if lx < 0.0:
		lx += wrapL
	return lx - b.D.logLen * b.cw

## Is x over a log at time t? (the JS returns the lane's velocity or null; here a bool — the velocity is ln.v)
static func _frog_log_under(b: Dictionary, ln: Dictionary, x: float, t: float, margin: float) -> bool:
	var L: float = b.D.logLen * b.cw
	for j in int(ln.n):
		var lx := _frog_log_left(b, ln, j, t)
		if x >= lx + margin and x <= lx + L - margin:
			return true
	return false

static func _frog_cy(b: Dictionary, r: int) -> float:
	return (r + 0.5) * b.ch

static func _frog_start_hop(b: Dictionary, tx: float, tr: int) -> void:
	var rows: int = b.D.rows
	var cw: float = b.cw
	b.hop = { "x0": b.fx, "r0": b.row, "x1": clampf(tx, cw * 0.5, b.w - cw * 0.5), "r1": clampi(tr, 0, rows - 1), "k": 0.0 }
	b.idle = 0.0

static func _frog_respawn(b: Dictionary) -> void:
	b.fx = b.w / 2.0
	b.row = int(b.D.rows) - 1
	b.hop = {}
	b.idle = 0.0

# ---- Grid: Pac-Man never leaves the lane centres ----
static func _grid_open(b: Dictionary, c: int, r: int) -> bool:
	var map: Array = b.D.map
	return r >= 0 and r < int(b.rows) and c >= 0 and c < int(b.cols) and (map[r] as String)[c] != "#"

static func _grid_refill(b: Dictionary) -> void:
	b.left = 0
	b.pellets = []
	for r in int(b.rows):
		for c in int(b.cols):
			var o := _grid_open(b, c, r)
			b.pellets.append(o)
			if o:
				b.left += 1

static func _grid_eat(b: Dictionary, c: Vector2i) -> void:
	var i := c.y * int(b.cols) + c.x
	if b.pellets[i]:
		b.pellets[i] = false
		b.left -= 1
		if b.left == 0:
			_grid_refill(b)

## At a centre: the wish first, then straight on, then (if bored) a whim.
static func _grid_decide(b: Dictionary, c: Vector2i) -> void:
	var dir: Vector2i = b.dir
	if b.want != null and _grid_open(b, c.x + b.want.x, c.y + b.want.y):
		b.dir = b.want
		b.want = null
	elif b.idle > b.D.autoWait:
		var o: Array = []
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if _grid_open(b, c.x + d.x, c.y + d.y) and d != -dir:
				o.append(d)
		if o.is_empty():
			b.dir = -dir
		else:
			b.dir = o[randi() % o.size()]
	var nd: Vector2i = b.dir
	if _grid_open(b, c.x + nd.x, c.y + nd.y):
		b.to = c + nd
	else:
		b.to = null                                          # a wall ahead: stop
	b.k = 0.0

static func _grid_c(b: Dictionary, c: Vector2i) -> Vector2:
	return Vector2((c.x + 0.5) * b.cw, (c.y + 0.5) * b.ch)

static func _grid_pos(b: Dictionary) -> Vector2:              # the mote, between two centres
	var f := _grid_c(b, b.from)
	if b.to == null:
		return f
	var k: float = b.k
	return f + (_grid_c(b, b.to) - f) * k

# ---- Platform: the jump maths, from the rider's feet ----
static func _plat_predict_x(b: Dictionary, i: int, T: float, t: float) -> float:   # where platform i will be, T seconds from now
	var D: Dictionary = b.D
	if i == 0:
		return D.sineX * b.w + sin((t + T) * TAU / D.sinePeriod) * D.sineAmp * b.w
	return b.B.x + b.B.vx * T                                # B: assume it keeps its velocity

static func _plat_plan(b: Dictionary, t: float) -> Dictionary:
	var D: Dictionary = b.D
	var rd: Dictionary = b.rd
	var plats: Array = b.plats
	var G: float = b.G
	var V0: float = b.V0
	var tgt: int = 1 - int(rd.on)
	var dy: float = plats[tgt].y - rd.y
	var disc: float = V0 * V0 + 2.0 * G * dy                 # v₀T + ½gT² = Δy, solved for T
	var T: float = (-V0 + sqrt(disc)) / G if disc >= 0.0 else -2.0 * V0 / G   # no root: it cannot reach that height — jump anyway
	var pv: float = plats[rd.on].vx
	var kick: float = clampf((_plat_predict_x(b, tgt, T, t) - rd.x) / T - pv, -D.maxKick * b.w, D.maxKick * b.w)
	return { "T": T, "vx": pv + kick, "pv": pv, "kick": kick }

static func _plat_jump(b: Dictionary, t: float) -> void:
	var p := _plat_plan(b, t)
	var rd: Dictionary = b.rd
	rd.vx = p.vx
	rd.vy = b.V0
	rd.on = -1
	rd.stand = 0.0

# ---- Keyframe: the playhead → a pose ----
static func _key_pose(b: Dictionary, ph: float) -> Dictionary:
	var keys: Array = b.D["keys"]
	var i := 0
	while i < keys.size() - 2 and ph >= keys[i + 1][0]:
		i += 1
	var a: Array = keys[i]
	var c: Array = keys[i + 1]
	var k: float = clampf((ph - a[0]) / maxf(1e-6, c[0] - a[0]), 0.0, 1.0)
	var e: float = k if b.D.easing == "linear" else smoothstep(0.0, 1.0, k)
	return { "x": lerpf(a[1], c[1], e) * b.w, "y": lerpf(a[2], c[2], e) * b.h, "i": i, "k": k }

# ---- Elevator: a motion profile ----
static func _elev_fy(b: Dictionary, i: int) -> float:
	var top: float = b.top
	var bot: float = b.bot
	var nf: int = b.n
	return bot - i * (bot - top) / (nf - 1)

static func _elev_profile(b: Dictionary, d: float) -> Dictionary:   # the plan for a trip of distance d
	var a: float = b.a
	var vmax: float = b.vmax
	var t1 := vmax / a
	var vp := vmax
	if a * t1 * t1 > d:                                      # too short for vmax: a triangle
		vp = sqrt(a * d)
		t1 = vp / a
	var tc: float = (d - a * t1 * t1) / vp if vp > 0.0 else 0.0   # the cruise
	return { "d": d, "t1": t1, "tc": tc, "vp": vp, "total": 2.0 * t1 + tc }

static func _elev_s_at(b: Dictionary, p: Dictionary, tau: float) -> float:   # distance covered after tau seconds
	var a: float = b.a
	var tt := clampf(tau, 0.0, p.total)
	if tt < p.t1:
		return 0.5 * a * tt * tt
	if tt < p.t1 + p.tc:
		return 0.5 * a * p.t1 * p.t1 + p.vp * (tt - p.t1)
	var r: float = p.total - tt
	return p.d - 0.5 * a * r * r

static func _elev_v_at(b: Dictionary, p: Dictionary, tau: float) -> float:
	var a: float = b.a
	var tt := clampf(tau, 0.0, p.total)
	if tt < p.t1:
		return a * tt
	if tt < p.t1 + p.tc:
		return p.vp
	return a * (p.total - tt)

static func _elev_v_at_s(b: Dictionary, p: Dictionary, s: float) -> float:   # the same profile, against distance
	var a: float = b.a
	return minf(minf(sqrt(2.0 * a * maxf(0.0, s)), p.vp), sqrt(2.0 * a * maxf(0.0, p.d - s)))

static func _elev_go(b: Dictionary, f0: int) -> void:         # (the JS rounds f; every caller here passes an int)
	var nf: int = b.n
	var f := clampi(f0, 0, nf - 1)
	if f == b.floor:
		return
	var sgn: float = -1.0 if _elev_fy(b, f) < _elev_fy(b, b.floor) else 1.0
	b.trip = { "to": f, "y0": _elev_fy(b, b.floor), "sign": sgn,
		"p": _elev_profile(b, absf(_elev_fy(b, f) - _elev_fy(b, b.floor))), "tau": 0.0 }
	b.floor = f

# ---- Juggle: the hands ----
static func _jug_hand_x(b: Dictionary, k: int) -> float:
	var hg: float = b.hg
	return b.cx + (hg if k != 0 else -hg)

static func _jug_side(k: int) -> float:
	return 1.0 if k != 0 else -1.0

static func _jug_hand(b: Dictionary, k: int, psi: float) -> Vector2:   # the hand's scoop: out while empty, in while holding
	var dw: float = b.dw
	var ex: float = b.ex
	var ey: float = b.ey
	var hyP: float = b.hyP
	var pc := 1.0 - dw / 2.0                                 # the phase at which it catches
	var th: float = PI * psi / pc if psi < pc else PI + PI * (psi - pc) / (1.0 - pc)
	return Vector2(_jug_hand_x(b, k) - _jug_side(k) * ex * cos(th), hyP + ey * sin(th))


static func init(b: Dictionary) -> void:
	var D: Dictionary = b.D
	match b.id:
		"astar":
			# PATHFINDING on a grid. every cell scores f = g + h: g is the distance
			# walked to reach it, h a HEURISTIC guess of the distance still to go —
			# Manhattan, |dx| + |dy|, which never overestimates, so the first route
			# to reach the goal is the shortest. the OPEN set (green) is the frontier
			# still to inspect; the CLOSED set (red) has been inspected. pop the
			# cheapest open cell, offer its four neighbours a better g, repeat until
			# the goal pops. weight h by more than 1 and A* turns GREEDY: fewer cells
			# inspected, no promise of shortest.
			var cols: int = D.cols
			var rows: int = D.rows
			b.cw = b.w / cols
			b.ch = (b.h - 18.0) / rows
			b.N = cols * rows
			b.walls = []
			b.state = []
			b.path = []
			b.pi = 0
			b.cell = Vector2i(0, rows - 1)
			b.goal = Vector2i(cols - 1, 0)
			b.hop = {}
			b.wait = 0.0
			var s := 0
			while s < 40 and (b.path as Array).is_empty():   # the first seed whose maze can be solved
				var r := Kit.rng(int(D.seed) + s)
				b.walls = []
				for i in int(b.N):
					b.walls.append(r.randf() < D.wallChance)
				b.walls[_astar_id(b, b.cell)] = false
				b.walls[_astar_id(b, b.goal)] = false
				b.path = _astar_search(b, b.cell, b.goal)
				s += 1
		"bezier":
			# a BÉZIER curve is nothing but lerps. lerp along P0→P1, P1→P2, P2→P3 to
			# get three points; lerp between those to get two; lerp between those to
			# get one — that is the curve at k. this ladder is DE CASTELJAU's
			# construction, drawn here every frame (green rungs, an amber rung, the
			# mote). the handles P1 and P2 are never visited; they only pull. k runs
			# at a constant rate, so the mote hurries wherever the handles are far apart.
			b.P = []
			for p in [D.p0, D.p1, D.p2, D.p3]:
				b.P.append(Vector2(p[0] * b.w, p[1] * b.h))
			b.grab = -1
			b.grabT = 9.0
		"path":
			# a SPLINE is a curve that visits its waypoints. this one is a cardinal
			# spline: each waypoint gets a tangent  m = tension · (next − previous)
			# and the piece between two waypoints is a HERMITE cubic built from the
			# two points and two tangents (tension 0.5 is Catmull-Rom). the catch:
			# the cubic's parameter k is not distance — equal steps of k bunch up on
			# short pieces (the faint ticks, the ghost). so measure the curve once
			# into a table of distance → (piece, k), and walk by ARC LENGTH.
			b.pts = _path_pts(b)
			b.table = []
			b.total = 1.0
			b.s = 0.0
			b.up = 0.0
			_path_measure(b)
		"kart":
			# the racing-game secret nobody admits to: RUBBER-BANDING. every kart's
			# wanted speed is base + gain · (how far behind the leader it is), and
			# the leader alone is throttled — so a straggler is quietly faster and a
			# runaway quietly slower, and the pack stays a pack. each kart also has a
			# personal speed (some are just faster), which the band overrules. the
			# track is a bookmark: one distance s along the lap, turned into (x, y).
			b.cx = b.w / 2.0
			b.cy = (b.h - 18.0) / 2.0 + 2.0
			var a: float = D.rx * b.w
			var bb: float = D.ry * (b.h - 18.0)
			b.r = minf(a, bb)
			b.hs = maxf(0.0, a - bb)
			b.L = 4.0 * b.hs + TAU * b.r                     # lap length: two straights, two half-circles
			var R := Kit.rng(int(D.seed))
			var COLS := [Kit.MOVER, Kit.GOOD, Kit.TARGET, Kit.MAGIC]
			b.karts = []
			for i in int(D.n):
				b.karts.append({ "s": -i * b.L * 0.06, "v": D.base * b.w, "pers": (R.randf() * 2.0 - 1.0) * D.spread,
					"lane": (R.randf() * 2.0 - 1.0) * D.lanes, "c": COLS[i % COLS.size()] })
			b.lead = 0
			b.last = 0
		"frog":
			# Frogger is two lessons in a trench coat. a HOP is a discrete step: pick
			# the cell, fly a fixed-duration arc (sin(k·π) lift, Jump's shape), land
			# exactly — no physics in between. a LOG is a moving COORDINATE FRAME:
			# while the frog sits on it, x += log.v · dt every frame, the same
			# inheritance as a moving platform (and Nest's parent + local). mid-hop
			# it belongs to no frame at all — which is why the landing has to be timed.
			var cols: int = D.cols
			var rows: int = D.rows
			b.cw = b.w / cols
			b.ch = (b.h - 18.0) / rows
			var R := Kit.rng(int(D.seed))
			var speeds: Array = D.speeds
			b.lanes = []                                     # each water lane: a schedule of logs
			for i in rows - 2:
				var period: float = (D.logLen + D.logGap) * b.cw
				var nl: int = ceili((b.w + D.logLen * b.cw) / period) + 1
				b.lanes.append({ "row": i + 1, "v": speeds[i % speeds.size()] * b.cw, "period": period, "n": nl, "phase": R.randf() * period * nl })
			b.fx = b.w / 2.0
			b.row = rows - 1
			b.hop = {}
			b.dead = 0.0
			b.idle = 0.0
			b.home = 0.0
			b.crossed = 0
		"grid":
			# Pac-Man never leaves the LANE centres. the body is a bookmark — the
			# cell it left, the cell it is heading to, and k between them — and every
			# frame it move_towards the next centre (Lerp's constant-speed cousin).
			# turning is only allowed AT a centre, so the input is BUFFERED: press
			# early and the wish waits (for a while) until a lane opens that way. the
			# amber arrow is the wish, the faint one the way it is going. reversing
			# is the one exception: allowed anywhere, at once.
			var map: Array = D.map
			b.rows = map.size()
			b.cols = (map[0] as String).length()
			b.cw = b.w / b.cols
			b.ch = (b.h - 18.0) / b.rows
			b.from = Vector2i(1, 1)
			b.to = null
			b.k = 0.0
			b.dir = Vector2i(1, 0)
			b.want = null
			b.wantAge = 0.0
			b.idle = D.autoWait + 1.0
			b.pellets = []
			b.left = 0
			_grid_refill(b)
		"platform":
			# two platforms, two schedules: A rides a sine (Hover, turned sideways),
			# B walks waypoints with eased legs and corner rests (Zigzag). the rider's
			# rule is INHERITANCE: standing on a platform it moves WITH it — its
			# velocity is the platform's, measured the honest way (this frame's
			# position minus last frame's). a jump keeps that velocity and adds a
			# KICK, sized by solving the flight time T from  v₀T + ½gT² = Δy  (Jump's
			# maths run backward) and asking where the other platform will be by then.
			b.G = D.g * b.h
			b.V0 = -sqrt(2.0 * b.G * D.jumpH * b.h)
			b.PW = D.platW * b.w
			b.A = { "x": D.sineX * b.w, "y": D.sineY * b.h, "vx": 0.0, "px": 0.0, "py": 0.0 }
			b.wp = []
			for p in D.wp:
				b.wp.append(Vector2(p[0] * b.w, p[1] * b.h))
			b.B = { "x": b.wp[0].x, "y": b.wp[0].y, "vx": 0.0, "px": 0.0, "py": 0.0, "seg": 0, "dir": 1, "k": 0.0, "pause": 0.0 }
			b.plats = [b.A, b.B]
			b.rd = { "x": b.A.x, "y": b.A.y, "vx": 0.0, "vy": 0.0, "on": 0, "off": 0.0, "stand": 0.0, "tNow": 0.0 }
			b.flash = 0.0
		"keyframe":
			# KEYFRAME animation: an artist stores poses at fixed times, and the
			# player lerps between the two keys either side of the playhead — k is
			# how far between them, eased or linear. it replays perfectly and can do
			# nothing else. its twin is PROCEDURAL: a critically damped spring (Damp)
			# chasing the same target. move the target and the puppet keeps
			# performing its recording at empty air while the spring simply goes —
			# which is the whole reason this lexicon exists.
			var keys: Array = D["keys"]
			b.period = maxf(0.1, keys[keys.size() - 1][0])
			b.tx = keys[0][1] * b.w
			b.ty = keys[0][2] * b.h
			b.holdT = 0.0
			b.tw = { "x": b.tx, "y": b.ty, "vx": 0.0, "vy": 0.0 }
		"elevator":
			# a lift is a MOTION PROFILE: accelerate at a, cruise at vmax, brake at a
			# — a trapezoid on the velocity graph — and the whole trip is a formula
			# of the time since departure, so it stops on the floor to the pixel. a
			# short trip never reaches vmax: the trapezoid becomes a triangle, peak
			# v = √(a·d). the graph beside the shaft is the profile drawn against
			# height: v rises as √(2·a·s) out of rest and falls the same way into the
			# stop. cameras, doors, and CNC tables all move exactly like this.
			b.top = b.h * 0.12
			b.bot = b.gy
			b.n = maxi(2, int(floorf(D.floors)))
			b.a = D.accel * b.h
			b.vmax = D.vmax * b.h
			b.sx = b.w * 0.28                                # the shaft
			b.sw = b.w * 0.16
			b.carH = b.h * 0.1
			b.gx = b.w * 0.6                                 # the graph
			b.gw = b.w * 0.3
			b.floor = 0
			b.y = _elev_fy(b, 0)
			b.trip = {}
			b.last = {}
			b.dwell = D.dwell
			b.si = 0
			b.call = -1
		"juggle":
			# a CASCADE is a timetable. every throw is Jump's parabola — v₀ = √(2gh),
			# in the air for T = 2v₀/g — and the hands alternate on a BEAT: with n
			# balls each ball flies for (n − dwell) beats, rests in the catching hand
			# for dwell beats, and is thrown again exactly n beats after its last
			# throw. that arithmetic fixes the beat at T ÷ (n − dwell), and from
			# there every ball and both hands are pure functions of the beat count —
			# no state but a clock (Orbit's lesson, worn by a juggler).
			b.n = maxi(1, int(floorf(D.balls))) | 1           # odd counts cross between hands — force odd
			b.dw = clampf(D.dwell, 0.2, minf(1.8, b.n - 0.5))
			b.cx = b.w / 2.0
			b.hyP = D.hy * b.h
			b.hg = D.handGap * b.w
			b.ex = D.scoop * b.w
			b.ey = D.scoop * b.h * 0.7
			b.COLS = [Kit.MOVER, Kit.GOOD, Kit.TARGET, Kit.MAGIC, Kit.HOT]
			b.hgt = D.height                                 # (the JS h — b.h is the stage height here)
			b.hT = D.height
			b.beat = 0.0


static func press(b: Dictionary, pos: Vector2) -> void:
	var D: Dictionary = b.D
	match b.id:
		"astar":
			var cols: int = D.cols
			var rows: int = D.rows
			var c := Vector2i(clampi(int(floorf(pos.x / b.cw)), 0, cols - 1), clampi(int(floorf(pos.y / b.ch)), 0, rows - 1))
			if b.walls[_astar_id(b, c)]:
				b.walls[_astar_id(b, c)] = false             # knock a wall down...
			else:
				b.goal = c                                   # ...or move the goal
			b.wait = 0.0
			_astar_replan(b)
		"bezier":
			var P: Array = b.P
			if b.grabT > 0.3:                                # a fresh grab takes the nearest handle...
				b.grab = 0
				for i in range(1, 4):
					if (P[i] as Vector2).distance_to(pos) < (P[b.grab] as Vector2).distance_to(pos):
						b.grab = i
			P[b.grab] = Vector2(clampf(pos.x, 6.0, b.w - 6.0), clampf(pos.y, 6.0, b.h - 22.0))   # ...a continuing drag keeps the same one
			b.grabT = 0.0
		"path":
			var pts: Array = b.pts
			var near := -1
			for i in pts.size():
				if (pts[i] as Vector2).distance_to(pos) < D.grab * b.w:
					near = i
			if near >= 0:
				pts[near] = pos                              # move a waypoint...
			elif pts.size() >= int(D.maxPts):
				b.pts = _path_pts(b)
			else:                                            # ...or add one on the nearest piece
				var bi := 0
				var bc := INF
				for i in pts.size():
					var a: Vector2 = pts[i]
					var c: Vector2 = pts[(i + 1) % pts.size()]
					var cost := a.distance_to(pos) + c.distance_to(pos) - c.distance_to(a)
					if cost < bc:
						bc = cost
						bi = i
				pts.insert(bi + 1, pos)
			_path_measure(b)
		"kart":
			var best := 0
			var bd := INF
			for i in b.karts.size():
				var p := _kart_spot(b, b.karts[i])
				var d := Vector2(p.x, p.y).distance_to(pos)
				if d < bd:
					bd = d
					best = i
			b.karts[best].v += D.shove * b.w                 # an impulse — Knock's idea, on a rail
		"frog":
			if not (b.hop as Dictionary).is_empty() or b.dead > 0.0:
				return                                       # no steering mid-air
			var cw: float = b.cw
			var dx: float = pos.x - b.fx
			var dy: float = pos.y - _frog_cy(b, b.row)
			if absf(dx) > absf(dy):
				_frog_start_hop(b, b.fx + (cw if dx > 0.0 else -cw), b.row)
			else:
				_frog_start_hop(b, b.fx, b.row + (1 if dy > 0.0 else -1))
		"grid":
			var m := _grid_pos(b)
			var dx := pos.x - m.x
			var dy := pos.y - m.y
			if absf(dx) > absf(dy):                          # the wish, relative to the mote
				b.want = Vector2i(1 if dx > 0.0 else -1, 0)
			else:
				b.want = Vector2i(0, 1 if dy > 0.0 else -1)
			b.wantAge = 0.0
			b.idle = 0.0
		"platform":
			if b.rd.on >= 0:
				_plat_jump(b, b.rd.tNow)
		"keyframe":
			b.tx = pos.x
			b.ty = pos.y
			b.holdT = D.hold
		"elevator":
			var nf: int = b.n
			var f := clampi(roundi((b.bot - pos.y) / (b.bot - b.top) * (nf - 1)), 0, nf - 1)
			if not (b.trip as Dictionary).is_empty():
				b.call = f                                   # moving: remember the call
			else:
				_elev_go(b, f)                               # idle: leave now
		"juggle":
			b.hT = clampf((b.hyP - pos.y) / b.h, 0.12, 0.62)


static func tick(b: Dictionary, dt: float, t: float) -> void:
	var D: Dictionary = b.D
	match b.id:
		"astar":
			var hop: Dictionary = b.hop
			if not hop.is_empty():
				hop.k += dt / D.hopTime
				if hop.k >= 1.0:
					b.cell = hop.to
					b.hop = {}
					b.pi += 1
					if (b.path as Array).is_empty() or b.pi >= (b.path as Array).size() - 1:
						b.wait = D.pause                     # arrived: a rest
			if (b.hop as Dictionary).is_empty():
				if b.wait > 0.0:
					b.wait -= dt
				elif not (b.path as Array).is_empty() and b.pi < (b.path as Array).size() - 1:
					b.hop = { "from": b.path[b.pi], "to": b.path[b.pi + 1], "k": 0.0 }
				else:                                        # a fresh errand
					_astar_new_goal(b)
					_astar_replan(b)
		"bezier":
			b.grabT += dt
		"path":
			var cnt: int = (b.pts as Array).size()
			b.s = fmod(b.s + D.speed * b.w * dt, b.total)                    # the bookmark: a distance
			b.up = fmod(b.up + dt * D.speed * b.w / (b.total / cnt), float(cnt))   # the ghost's bookmark: a parameter
		"kart":
			var karts: Array = b.karts
			var L: float = b.L
			var lead := 0
			var last := 0
			for i in range(1, karts.size()):
				if karts[i].s > karts[lead].s:
					lead = i
				if karts[i].s < karts[last].s:
					last = i
			for i in karts.size():
				var k: Dictionary = karts[i]
				var gap: float = (karts[lead].s - k.s) / L   # laps behind the leader (0 for the leader)
				var want: float = D.base * b.w * (1.0 + k.pers) + D.gain * b.w * gap   # ← the band
				if i == lead:
					want *= D.leaderDrag                     # the leader is throttled
				want += Kit.noise(t * 0.8 + i * 7.3) * D.wobble * b.w   # a little human wobble
				k.v += (want - k.v) * Kit.smooth(2.5, dt)    # Arrive's manners: ease to the wanted speed
				k.v = clampf(k.v, 0.0, 2.0 * b.w)
				k.s += k.v * dt
			if karts[last].s > L:                            # keep the bookmarks small
				for k in karts:
					k.s -= L
			b.lead = lead
			b.last = last
		"frog":
			var rows: int = D.rows
			var cw: float = b.cw
			var lanes: Array = b.lanes
			var water: bool = b.row > 0 and b.row < rows - 1
			if b.dead > 0.0:
				b.dead -= dt
				if b.dead <= 0.0:
					_frog_respawn(b)
			elif not (b.hop as Dictionary).is_empty():
				var hop: Dictionary = b.hop
				hop.k += dt / D.hopTime
				if hop.k >= 1.0:                             # land exactly, then ask the water
					b.fx = hop.x1
					b.row = hop.r1
					b.hop = {}
					if b.row > 0 and b.row < rows - 1 and not _frog_log_under(b, lanes[b.row - 1], b.fx, t, -cw * 0.15):
						b.dead = 0.7
					elif b.row == 0:
						b.crossed += 1
						b.home = 0.9
			else:
				if water:
					var ln: Dictionary = lanes[b.row - 1]
					if not _frog_log_under(b, ln, b.fx, t, -cw * 0.15):
						b.dead = 0.7
					else:
						b.fx += ln.v * dt                    # ← the moving frame
					if b.fx < cw * 0.3 or b.fx > b.w - cw * 0.3:
						b.dead = 0.7                         # swept off the edge
				if b.home > 0.0:
					b.home -= dt
					if b.home <= 0.0:
						_frog_respawn(b)
				else:
					b.idle += dt
					if b.idle > D.autoWait and b.row > 0:    # the little brain: hop up when a log will be there
						var up: int = b.row - 1
						if up == 0 or _frog_log_under(b, lanes[up - 1], b.fx, t + D.hopTime, cw * 0.25):
							_frog_start_hop(b, b.fx, up)
						else:
							b.idle = D.autoWait - 0.2        # not yet — look again soon
		"grid":
			b.wantAge += dt
			b.idle += dt
			if b.want != null and b.wantAge > D.bufferTime:
				b.want = null                                # a stale wish is dropped
			if b.to == null:
				if b.want != null or b.idle > D.autoWait:
					_grid_decide(b, b.from)
			else:
				var dir: Vector2i = b.dir
				if b.want != null and b.want == -dir:        # reverse: anywhere, at once
					var tmp: Vector2i = b.from
					b.from = b.to
					b.to = tmp
					b.k = 1.0 - b.k
					b.dir = b.want
					b.want = null
				var step: float = D.speed * dt               # move_toward, in cells
				while b.to != null and step > 0.0:
					if step < 1.0 - b.k:
						b.k += step
						step = 0.0
					else:
						step -= 1.0 - b.k
						b.from = b.to
						_grid_eat(b, b.from)
						_grid_decide(b, b.from)
		"platform":
			dt = maxf(dt, 1e-4)
			var A: Dictionary = b.A
			var B: Dictionary = b.B
			var rd: Dictionary = b.rd
			var wp: Array = b.wp
			var plats: Array = b.plats
			var G: float = b.G
			var PW: float = b.PW
			rd.tNow = t
			A.px = A.x                                       # platform A: a sine, its velocity by difference
			A.py = A.y
			A.x = D.sineX * b.w + sin(t * TAU / D.sinePeriod) * D.sineAmp * b.w
			A.vx = (A.x - A.px) / dt
			B.px = B.x                                       # platform B: eased legs between waypoints
			B.py = B.y
			var a: Vector2 = wp[B.seg]
			var c: Vector2 = wp[B.seg + 1]
			if B.pause > 0.0:
				B.pause -= dt
			else:
				B.k += dt * D.legSpeed * b.w / maxf(1.0, c.distance_to(a))
				if B.k >= 1.0:
					B.k = 0.0
					B.pause = D.legPause
					B.seg += B.dir
					if B.seg > wp.size() - 2:
						B.seg = wp.size() - 2
						B.dir = -1
					if B.seg < 0:
						B.seg = 0
						B.dir = 1
			var a2: Vector2 = wp[B.seg]
			var b2: Vector2 = wp[B.seg + 1]
			var bk: float = B.k
			var e: float = smoothstep(0.0, 1.0, bk) if B.dir > 0 else 1.0 - smoothstep(0.0, 1.0, bk)
			B.x = a2.x + (b2.x - a2.x) * e
			B.y = a2.y + (b2.y - a2.y) * e
			B.vx = (B.x - B.px) / dt
			var prevY: float = rd.y
			if rd.on >= 0:                                   # standing: carried by the platform
				var p: Dictionary = plats[rd.on]
				rd.x = p.x + rd.off
				rd.y = p.y
				rd.vx = p.vx
				rd.stand += dt
				if rd.stand > D.autoWait:
					_plat_jump(b, t)
			else:                                            # airborne: plain ballistics
				rd.vy += G * dt
				rd.x += rd.vx * dt
				rd.y += rd.vy * dt
				if rd.vy > 0.0:
					for i in 2:
						var p: Dictionary = plats[i]
						if prevY <= p.py + 1.0 and rd.y >= p.y - 1.0 and absf(rd.x - p.x) <= PW / 2.0:
							rd.on = i                        # caught
							rd.off = rd.x - p.x
							rd.y = p.y
							rd.vy = 0.0
							break
				if rd.y > b.h + 30.0 or rd.x < -40.0 or rd.x > b.w + 40.0:   # missed: back to A
					rd.on = 0
					rd.off = 0.0
					rd.x = A.x
					rd.y = A.y
					rd.vy = 0.0
					b.flash = 1.0
			b.flash = maxf(0.0, b.flash - dt * 2.0)
		"keyframe":
			var ph := fmod(t * D.tempo, b.period)
			var p := _key_pose(b, ph)
			if b.holdT > 0.0:
				b.holdT -= dt
			else:                                            # normally the target IS the recording
				b.tx = p.x
				b.ty = p.y
			var tw: Dictionary = b.tw
			var w: float = D.omega                           # the twin: Damp's equation
			var z: float = D.zeta
			tw.vx += ((b.tx - tw.x) * w * w - 2.0 * z * w * tw.vx) * dt
			tw.vy += ((b.ty - tw.y) * w * w - 2.0 * z * w * tw.vy) * dt
			tw.x += tw.vx * dt
			tw.y += tw.vy * dt
		"elevator":
			var trip: Dictionary = b.trip
			if not trip.is_empty():
				trip.tau += dt
				b.y = trip.y0 + trip.sign * _elev_s_at(b, trip.p, trip.tau)
				if trip.tau >= trip.p.total:                 # exact
					b.y = _elev_fy(b, trip.to)
					b.last = trip
					b.trip = {}
					b.dwell = D.dwell
			else:
				b.dwell -= dt
				if b.dwell <= 0.0:
					var sched: Array = D.schedule
					var f: int
					if b.call >= 0:
						f = b.call
					else:
						f = sched[b.si % sched.size()]
						b.si += 1
					b.call = -1
					var nf: int = b.n
					if clampi(f, 0, nf - 1) == b.floor:
						b.dwell = 0.3
					else:
						_elev_go(b, f)
		"juggle":
			b.hgt += (b.hT - b.hgt) * Kit.smooth(3.0, dt)
			var T: float = 2.0 * sqrt(2.0 * b.hgt / D.g)     # flight time — the H's cancel
			var bt: float = T / (b.n - b.dw)                 # the beat
			b.beat += dt / bt


static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	Kit.stage(n, b)
	var D: Dictionary = b.D
	var origin: Vector2 = (b.rect as Rect2).position
	match b.id:
		"astar":
			var cols: int = D.cols
			var cw: float = b.cw
			var ch: float = b.ch
			var nc := 0
			var no := 0
			for i in int(b.N):
				var x: float = (i % cols) * cw
				var y: float = floori(i / float(cols)) * ch
				if b.walls[i]:
					Kit.rect(n, Rect2(x + 1.0, y + 1.0, cw - 2.0, ch - 2.0), Color(0.788, 0.769, 0.894, 0.32))
				elif b.state[i] == 2:
					nc += 1
					Kit.rect(n, Rect2(x + 1.0, y + 1.0, cw - 2.0, ch - 2.0), Color(0.961, 0.541, 0.541, 0.13))
				elif b.state[i] == 1:
					no += 1
					Kit.rect(n, Rect2(x + 1.0, y + 1.0, cw - 2.0, ch - 2.0), Color(0.608, 0.886, 0.541, 0.16))
			var path: Array = b.path
			for i in path.size() - 1:
				Kit.line(n, _astar_c(b, path[i]), _astar_c(b, path[i + 1]), Color(0.961, 0.757, 0.412, 0.55), 1.5)
			Kit.ring(n, _astar_c(b, b.goal), minf(cw, ch) * 0.3, Kit.TARGET, 1.5)
			var m := _astar_c(b, b.cell)
			var ang := 0.0
			var hop: Dictionary = b.hop
			if not hop.is_empty():
				var k := smoothstep(0.0, 1.0, hop.k)
				var f := _astar_c(b, hop.from)
				var to := _astar_c(b, hop.to)
				m = f + (to - f) * k
				m.y -= sin(clampf(hop.k, 0.0, 1.0) * PI) * D.hopLift * ch   # the hop's little arc
				ang = atan2(float(hop.to.y - hop.from.y), float(hop.to.x - hop.from.x))
			Kit.mote(n, b, m, ang, Kit.MOVER, minf(cw, ch) * 0.26)
			var tail: String = (" · path %d" % (path.size() - 1)) if not path.is_empty() else " · no path"
			_label_right(n, "closed %d · open %d%s" % [nc, no, tail], Vector2(b.w - 4.0, 11.0), Kit.INK * Color(1, 1, 1, 0.55))
			Kit.label(n, b, D.label, Vector2(b.w / 2.0, b.h - 6.0), Kit.INK * Color(1, 1, 1, 0.55), true)
		"bezier":
			var P: Array = b.P
			var ph := fmod(t / D.period, 2.0)
			var k: float = ph if ph < 1.0 else 2.0 - ph     # there and back again
			var curve := PackedVector2Array()                # the whole curve, previewed
			for i in 49:
				curve.append(_bez_ladder(P, i / 48.0).b)
			n.draw_polyline(curve, Color(0.91, 0.898, 0.957, 0.16), 1.0)
			Kit.line(n, P[0], P[1], Color(0.788, 0.769, 0.894, 0.5))   # the handles
			Kit.line(n, P[2], P[3], Color(0.788, 0.769, 0.894, 0.5))
			Kit.line(n, P[1], P[2], Color(0.788, 0.769, 0.894, 0.18))
			var s := _bez_ladder(P, k)
			var q: Array = s.q
			var r: Array = s.r
			Kit.line(n, q[0], q[1], Color(0.608, 0.886, 0.541, 0.6))    # rung one
			Kit.line(n, q[1], q[2], Color(0.608, 0.886, 0.541, 0.6))
			Kit.line(n, r[0], r[1], Color(0.961, 0.757, 0.412, 0.75))   # rung two
			for qq in q:
				Kit.dot(n, qq, 2.2, Kit.GOOD)
			for rr in r:
				Kit.dot(n, rr, 2.6, Kit.TARGET)
			for i in 4:
				var hot: bool = b.grab == i and b.grabT < 0.5
				if i == 0 or i == 3:
					Kit.dot(n, P[i], 3.5, Kit.TARGET if hot else Kit.BONE)
				else:
					Kit.ring(n, P[i], 4.5, Kit.TARGET if hot else Kit.BONE, 1.5)
				Kit.label(n, b, "P%d" % i, (P[i] as Vector2) + Vector2(7.0, 4.0), Color(0.788, 0.769, 0.894, 0.7))
			var dir: float = 1.0 if ph < 1.0 else -1.0       # heading = the last rung's direction
			var r0: Vector2 = r[0]
			var r1: Vector2 = r[1]
			Kit.mote(n, b, s.b, atan2((r1.y - r0.y) * dir, (r1.x - r0.x) * dir))
			Kit.label(n, b, "k = %.2f" % k, Vector2(b.w / 2.0, 14.0), Kit.INK * Color(1, 1, 1, 0.55), true)
			Kit.label(n, b, D.label, Vector2(b.w / 2.0, b.h - 6.0), Kit.INK * Color(1, 1, 1, 0.55), true)
		"path":
			var pts: Array = b.pts
			var table: Array = b.table
			var cnt := pts.size()
			var poly := PackedVector2Array()
			poly.append(table[table.size() - 1].p)
			for e in table:
				poly.append(e.p)
			n.draw_polyline(poly, Color(0.91, 0.898, 0.957, 0.2), 1.5)
			for i in cnt:                                    # equal-parameter ticks: they bunch
				for j in range(1, 4):
					Kit.dot(n, _path_at(b, i, j / 4.0), 1.5, Kit.DIM)
				var p0: Vector2 = pts[(i - 1 + cnt) % cnt]     # the tangent, made visible
				var p2: Vector2 = pts[(i + 1) % cnt]
				var wp: Vector2 = pts[i]
				var tension: float = D.tension
				Kit.arrow(n, wp, wp + tension * (p2 - p0) * 0.3, Color(0.788, 0.769, 0.894, 0.35))
				Kit.ring(n, wp, 4.0, Kit.BONE, 1.5)
			var up: float = b.up
			var gp := _path_at(b, int(floorf(up)) % cnt, up - floorf(up))
			Kit.dot(n, gp, 6.0, Color(0.91, 0.898, 0.957, 0.2))
			var p := _path_lookup(b, b.s)
			var q := _path_lookup(b, b.s + 3.0)
			Kit.mote(n, b, p, (q - p).angle())
			Kit.label(n, b, D.label, Vector2(b.w / 2.0, b.h - 6.0), Kit.INK * Color(1, 1, 1, 0.55), true)
		"kart":
			var karts: Array = b.karts
			var L: float = b.L
			for off in [-11.0, 11.0]:                        # the track, two kerbs
				var kerb := PackedVector2Array()
				for j in 73:
					var p := _kart_place(b, j / 72.0 * L)
					kerb.append(Vector2(p.x + cos(p.z + PI / 2.0) * off, p.y + sin(p.z + PI / 2.0) * off))
				n.draw_polyline(kerb, Color(0.788, 0.769, 0.894, 0.35), 1.0)
			var sl := _kart_place(b, 0.0)
			Kit.line(n, Vector2(sl.x, sl.y - 11.0), Vector2(sl.x, sl.y + 11.0), Color(0.91, 0.898, 0.957, 0.5), 2.0)   # the start line
			var pl := _kart_spot(b, karts[b.lead])
			var pt := _kart_spot(b, karts[b.last])
			Kit.line(n, Vector2(pl.x, pl.y), Vector2(pt.x, pt.y), Color(0.961, 0.541, 0.541, 0.3))   # the band itself, leader to straggler
			for k in karts:
				var p := _kart_spot(b, k)
				n.draw_set_transform(origin + Vector2(p.x, p.y), p.z, Vector2.ONE)
				n.draw_rect(Rect2(-7.0, -4.0, 14.0, 8.0), k.c)
				n.draw_rect(Rect2(2.0, -2.5, 3.0, 5.0), Color("131020"))   # a windscreen: which way is forward
				n.draw_set_transform(origin, 0.0, Vector2.ONE)
			Kit.dot(n, Vector2(pl.x, pl.y - 11.0), 2.5, Kit.TARGET)   # the leader's crown
			Kit.label(n, b, D.label, Vector2(b.w / 2.0, b.h - 6.0), Kit.INK * Color(1, 1, 1, 0.55), true)
		"frog":
			var rows: int = D.rows
			var cw: float = b.cw
			var ch: float = b.ch
			for r in rows:
				Kit.rect(n, Rect2(0.0, r * ch, b.w, ch), Color(0.541, 0.851, 0.961, 0.06) if (r > 0 and r < rows - 1) else Color(0.608, 0.886, 0.541, 0.1))
			for ln in b.lanes:
				for j in int(ln.n):
					Kit.rect(n, Rect2(_frog_log_left(b, ln, j, t), _frog_cy(b, ln.row) - ch * 0.28, D.logLen * cw, ch * 0.56), Color(0.788, 0.769, 0.894, 0.5))
			var dead: float = b.dead
			if dead > 0.0:                                   # the splash
				Kit.ring(n, Vector2(b.fx, _frog_cy(b, b.row)), (0.7 - dead) * cw * 1.5, Color(0.961, 0.541, 0.541, clampf(dead, 0.0, 0.7)), 2.0)
			if dead <= 0.0:
				var x: float = b.fx
				var y := _frog_cy(b, b.row)
				var ang := -PI / 2.0
				var hop: Dictionary = b.hop
				if not hop.is_empty():
					var k := smoothstep(0.0, 1.0, hop.k)
					x = lerpf(hop.x0, hop.x1, k)
					y = lerpf(_frog_cy(b, hop.r0), _frog_cy(b, hop.r1), k) - sin(clampf(hop.k, 0.0, 1.0) * PI) * D.hopLift * ch
					ang = atan2(float(hop.r1 - hop.r0), hop.x1 - hop.x0)
				Kit.mote(n, b, Vector2(x, y), ang, Kit.MOVER, minf(cw, ch) * 0.24)
			_label_right(n, "crossed ×%d" % b.crossed, Vector2(b.w - 4.0, 11.0), Kit.INK * Color(1, 1, 1, 0.55))
			Kit.label(n, b, D.label, Vector2(b.w / 2.0, b.h - 6.0), Kit.INK * Color(1, 1, 1, 0.55), true)
		"grid":
			var rows: int = b.rows
			var cols: int = b.cols
			var cw: float = b.cw
			var ch: float = b.ch
			for r in rows:
				for c in cols:
					if not _grid_open(b, c, r):
						Kit.rect(n, Rect2(c * cw + 1.0, r * ch + 1.0, cw - 2.0, ch - 2.0), Color(0.788, 0.769, 0.894, 0.28))
					elif b.pellets[r * cols + c]:
						Kit.dot(n, Vector2((c + 0.5) * cw, (r + 0.5) * ch), D.pelletR * cw, Color(0.961, 0.757, 0.412, 0.7))
			var m := _grid_pos(b)
			var dir: Vector2i = b.dir
			Kit.arrow(n, m, m + Vector2(dir.x * cw * 0.8, dir.y * ch * 0.8), Kit.DIM)
			if b.want != null:                               # the buffered wish
				var want: Vector2i = b.want
				Kit.arrow(n, m, m + Vector2(want.x * cw * 0.8, want.y * ch * 0.8), Kit.TARGET)
			Kit.mote(n, b, m, atan2(float(dir.y), float(dir.x)), Kit.MOVER, minf(cw, ch) * 0.3)
			var tail: String = " · wish buffered" if b.want != null else ""
			_label_right(n, "pellets %d%s" % [b.left, tail], Vector2(b.w - 4.0, 11.0), Kit.INK * Color(1, 1, 1, 0.55))
			Kit.label(n, b, D.label, Vector2(b.w / 2.0, b.h - 6.0), Kit.INK * Color(1, 1, 1, 0.55), true)
		"platform":
			Kit.ground(n, b)
			var A: Dictionary = b.A
			var rd: Dictionary = b.rd
			var wp: Array = b.wp
			var plats: Array = b.plats
			var G: float = b.G
			var V0: float = b.V0
			var PW: float = b.PW
			Kit.line(n, Vector2(D.sineX * b.w - D.sineAmp * b.w, A.y + 3.0), Vector2(D.sineX * b.w + D.sineAmp * b.w, A.y + 3.0), Color(0.91, 0.898, 0.957, 0.12))   # A's rail
			for i in wp.size() - 1:
				Kit.line(n, (wp[i] as Vector2) + Vector2(0.0, 3.0), (wp[i + 1] as Vector2) + Vector2(0.0, 3.0), Color(0.91, 0.898, 0.957, 0.12))
			for p in wp:
				Kit.ring(n, (p as Vector2) + Vector2(0.0, 3.0), 3.0, Color(0.788, 0.769, 0.894, 0.4))
			for p in plats:
				Kit.rect(n, Rect2(p.x - PW / 2.0, p.y, PW, 5.0), Color(0.788, 0.769, 0.894, 0.7))
			if rd.on >= 0:                                   # the plan, previewed while it stands
				var plan := _plat_plan(b, t)
				for i in 17:
					var tau: float = plan.T * i / 16.0
					Kit.dot(n, Vector2(rd.x + plan.vx * tau, rd.y + V0 * tau + 0.5 * G * tau * tau), 1.2, Color(0.91, 0.898, 0.957, 0.28))
				Kit.arrow(n, Vector2(rd.x, rd.y - 9.0), Vector2(rd.x + plan.pv * 0.35, rd.y - 9.0), Kit.GOOD)   # inherited
				Kit.arrow(n, Vector2(rd.x + plan.pv * 0.35, rd.y - 9.0), Vector2(rd.x + (plan.pv + plan.kick) * 0.35, rd.y - 9.0), Kit.HOT)   # the kick
			var flash: float = b.flash
			if flash > 0.0:
				Kit.ring(n, Vector2(rd.x, rd.y - 8.0), 12.0 + (1.0 - flash) * 20.0, Color(0.961, 0.541, 0.541, flash * 0.7), 2.0)
			Kit.mote(n, b, Vector2(rd.x, rd.y - 8.0), clampf(rd.vx * 0.002, -0.4, 0.4))
			var other: Dictionary = plats[1 - maxi(0, int(rd.on))]
			Kit.ring(n, Vector2(other.x, other.y + 2.5), 5.0, Kit.TARGET)
			Kit.label(n, b, D.label, Vector2(b.w / 2.0, b.h - 6.0), Kit.INK * Color(1, 1, 1, 0.55), true)
		"keyframe":
			var keys: Array = D["keys"]
			var period: float = b.period
			var tw: Dictionary = b.tw
			var ph := fmod(t * D.tempo, period)
			var p := _key_pose(b, ph)
			for i in keys.size() - 1:                        # the recording, drawn
				Kit.line(n, Vector2(keys[i][1] * b.w, keys[i][2] * b.h), Vector2(keys[i + 1][1] * b.w, keys[i + 1][2] * b.h), Color(0.788, 0.769, 0.894, 0.15))
			for i in keys.size() - 1:
				Kit.ring(n, Vector2(keys[i][1] * b.w, keys[i][2] * b.h), 5.0, Color(0.788, 0.769, 0.894, 0.35))
				Kit.label(n, b, str(i), Vector2(keys[i][1] * b.w + 7.0, keys[i][2] * b.h - 5.0), Color(0.788, 0.769, 0.894, 0.5))
			var x0: float = b.w * 0.1                        # the timeline
			var x1: float = b.w * 0.9
			var ty2: float = b.h - 22.0
			Kit.line(n, Vector2(x0, ty2), Vector2(x1, ty2), Color(0.788, 0.769, 0.894, 0.4))
			for i in keys.size():
				var kx: float = x0 + (x1 - x0) * keys[i][0] / period
				Kit.line(n, Vector2(kx, ty2 - 4.0), Vector2(kx, ty2 + 4.0), Kit.BONE)
			var hx: float = x0 + (x1 - x0) * ph / period
			Kit.line(n, Vector2(hx, ty2 - 6.0), Vector2(hx, ty2 + 6.0), Kit.TARGET, 2.0)
			Kit.label(n, b, "key %d→%d  k = %.2f" % [p.i, p.i + 1, p.k], Vector2(b.w / 2.0, 14.0), Kit.INK * Color(1, 1, 1, 0.55), true)
			var pp := Vector2(p.x, p.y)
			var tp := Vector2(b.tx, b.ty)
			if pp.distance_to(tp) > 8.0:                     # the replay, missing its cue
				n.draw_dashed_line(pp, tp, Color(0.961, 0.541, 0.541, 0.6), 1.0, 8.0)
			Kit.ring(n, tp, 9.0, Kit.TARGET, 1.5)
			var nk: Array = keys[mini(p.i + 1, keys.size() - 1)]
			Kit.mote(n, b, pp, atan2(nk[2] * b.h - p.y, nk[1] * b.w - p.x), Kit.BONE, 7.0)   # the puppet
			Kit.mote(n, b, Vector2(tw.x, tw.y), atan2(tw.vy, tw.vx), Kit.MOVER, 7.0)         # the twin
			Kit.label(n, b, D.label, Vector2(b.w / 2.0, b.h - 6.0), Kit.INK * Color(1, 1, 1, 0.55), true)
		"elevator":
			Kit.ground(n, b)
			var sx: float = b.sx
			var sw: float = b.sw
			var top: float = b.top
			var bot: float = b.bot
			var carH: float = b.carH
			var gx: float = b.gx
			var gw: float = b.gw
			var nf: int = b.n
			var y: float = b.y
			var vmax: float = b.vmax
			var trip: Dictionary = b.trip
			var last: Dictionary = b.last
			Kit.rect(n, Rect2(sx, top - 12.0, sw, bot - top + 12.0), Color(0.588, 0.569, 0.745, 0.08))
			for i in nf:
				Kit.line(n, Vector2(sx - 8.0, _elev_fy(b, i)), Vector2(sx + sw + 8.0, _elev_fy(b, i)), Kit.DIM)
				Kit.label(n, b, str(i), Vector2(sx - 16.0, _elev_fy(b, i) + 4.0), Color(0.788, 0.769, 0.894, 0.6))
			Kit.line(n, Vector2(sx + sw / 2.0, top - 12.0), Vector2(sx + sw / 2.0, y - carH), Kit.DIM)   # the cable
			Kit.rect(n, Rect2(sx + 3.0, y - carH, sw - 6.0, carH), Color(0.788, 0.769, 0.894, 0.7))
			Kit.mote(n, b, Vector2(sx + sw / 2.0, y - carH / 2.0), 0.0, Kit.MOVER, 5.0)
			if trip.is_empty():
				Kit.ring(n, Vector2(sx + sw / 2.0, y - carH / 2.0), carH * 0.6, Kit.GOOD)   # doors open
			if b.call >= 0:
				Kit.ring(n, Vector2(sx + sw + 8.0, _elev_fy(b, b.call)), 4.0, Kit.TARGET, 1.5)   # a call waiting
			Kit.line(n, Vector2(gx, top), Vector2(gx, bot), Kit.DIM)   # the graph: v against height
			Kit.label(n, b, "v", Vector2(gx + 3.0, top - 4.0), Kit.INK * Color(1, 1, 1, 0.55))
			_label_right(n, "vmax", Vector2(gx + gw, top - 4.0), Kit.INK * Color(1, 1, 1, 0.55))
			var pr: Dictionary = trip if not trip.is_empty() else last
			if not pr.is_empty():
				var graph := PackedVector2Array()
				for j in 41:
					var s: float = pr.p.d * j / 40.0
					graph.append(Vector2(gx + _elev_v_at_s(b, pr.p, s) / vmax * gw, pr.y0 + pr.sign * s))
				n.draw_polyline(graph, Color(0.961, 0.757, 0.412, 0.7 if not trip.is_empty() else 0.25), 1.5)
			if not trip.is_empty():
				Kit.dot(n, Vector2(gx + _elev_v_at(b, trip.p, trip.tau) / vmax * gw, y), 3.5, Kit.TARGET)
			Kit.label(n, b, D.label, Vector2(b.w / 2.0, b.h - 6.0), Kit.INK * Color(1, 1, 1, 0.55), true)
		"juggle":
			var nb: int = b.n
			var dw: float = b.dw
			var cx: float = b.cx
			var hyP: float = b.hyP
			var ex: float = b.ex
			var ey: float = b.ey
			var hgt: float = b.hgt
			var beat: float = b.beat
			var COLS: Array = b.COLS
			var T: float = 2.0 * sqrt(2.0 * hgt / D.g)
			var bt: float = T / (nb - dw)
			var G: float = D.g * b.h
			var v0: float = G * T / 2.0
			for k in 2:                                      # the hands' ellipses, and the hands
				var ell := PackedVector2Array()
				for j in 25:
					var th := j / 24.0 * PI * 2.0
					ell.append(Vector2(_jug_hand_x(b, k) - _jug_side(k) * ex * cos(th), hyP + ey * sin(th)))
				n.draw_polyline(ell, Color(0.91, 0.898, 0.957, 0.12), 1.0)
				var psi := fmod((beat - k) / 2.0, 1.0)
				if psi < 0.0:
					psi += 1.0
				Kit.ring(n, _jug_hand(b, k, psi), 7.0, Kit.BONE, 2.0)
			for k in 2:                                      # the two flight paths, faint
				for j in 15:
					var tau: float = T * j / 14.0
					Kit.dot(n, Vector2(lerpf(_jug_hand_x(b, k) - _jug_side(k) * ex, _jug_hand_x(b, 1 - k) + _jug_side(1 - k) * ex, j / 14.0),
						hyP - v0 * tau + 0.5 * G * tau * tau), 1.1, Kit.DIM)
			Kit.ring(n, Vector2(cx, hyP - hgt * b.h), 4.0, Color(0.961, 0.757, 0.412, 0.5))
			Kit.label(n, b, "h", Vector2(cx + 8.0, hyP - hgt * b.h + 4.0), Color(0.961, 0.757, 0.412, 0.7))
			for i in nb:
				var q := floori((beat - i) / nb)               # beats since this ball's last throw
				var phi: float = beat - i - q * nb
				var from: int = ((q * nb + i) % 2 + 2) % 2      # throw m comes from hand m mod 2
				var to: int = 1 - from
				var x: float
				var y: float
				if phi < nb - dw:                            # in flight: Jump's parabola, hand to hand
					var tau: float = phi * bt
					x = lerpf(_jug_hand_x(b, from) - _jug_side(from) * ex, _jug_hand_x(b, to) + _jug_side(to) * ex, phi / (nb - dw))
					y = hyP - v0 * tau + 0.5 * G * tau * tau
				else:                                        # held: ride the catching hand's scoop
					var psi := fmod((beat - to) / 2.0, 1.0)
					if psi < 0.0:
						psi += 1.0
					var hp := _jug_hand(b, to, psi)
					x = hp.x
					y = hp.y
				Kit.dot(n, Vector2(x, y), 6.0, COLS[i % COLS.size()])
			Kit.label(n, b, "n = %d · beat = %.2f s · T = %.2f s" % [nb, bt, T], Vector2(b.w / 2.0, 14.0), Kit.INK * Color(1, 1, 1, 0.55), true)
			Kit.label(n, b, D.label, Vector2(b.w / 2.0, b.h - 6.0), Kit.INK * Color(1, 1, 1, 0.55), true)
