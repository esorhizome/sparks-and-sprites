extends RefCounted

const Kit := preload("res://scenes/motion/kit.gd")
## SQUADS & MAPS — thirteen movement styles, ported from the web lexicon
## (docs/locomotion.js). Many bodies and ONE PLAN. The steering family gave
## a body an intention and the crowds family gave every body one rule; here
## a group shares a picture — formation slots hung off a leader, a wingman's
## offset, the midpoint a bodyguard guards, the far side of a rock. And then
## the map itself starts thinking: a grid where every cell holds a NUMBER (a
## distance, a threat), so a route is "step to the smaller neighbour" and a
## retreat is "step to the larger one". The brains on top — a behaviour
## tree, a utility scorer, a daily schedule — only ever read those numbers.

const TITLE := "Squads & maps"
const BLURB := "formations, escorts, bodyguards, hiding, context steering, flow fields, Dijkstra and influence maps, behaviour trees, utility, schedules"
const DEFS := [
	{ "id": "formation", "letter": "F", "name": "Formation",
		"hint": "slots hung off the leader's heading — a V, a line, a ring (Queue's leader, Herd's flock) — press the leader to change shape, elsewhere to send it",
		"dials": { "n": 6,               # followers
			"shape": "v",                # "v", "line" or "ring" — the slot pattern
			"spacing": 0.1,              # slot pitch, × min(W, H)
			"maxsp": 150, "maxf": 420, "slow": 30,   # Arrive: top speed, steering clamp (px/s²), brake ring (px)
			"leadSpeed": 55,             # the leader's cruise, px/s
			"retarget": 4,               # seconds before the leader picks a new spot
			"reassign": 0.6,             # seconds between slot re-assignments (nearest free slot wins)
			"label": "slot = leader + R(heading) · offset · Arrive" },
		"rhyme": { "name": "Fleet", "hint": "a ring of ten around a slower flagship, re-dealt twice as often — an escort screen instead of geese",
			"dials": { "shape": "ring", "n": 10, "leadSpeed": 40 } } },
	{ "id": "escort", "letter": "E", "name": "Escort",
		"hint": "offset pursuit: wingmen hold a slot off a leader who will not wait, aiming at Chase's predicted point (leader + v · lead) — press to send the leader",
		"dials": { "n": 3,               # escorts
			"gap": 0.09,                 # slot distance behind and beside the leader, × min(W, H)
			"lead": 0.6,                 # how far ahead each escort predicts, as a fraction of its time-to-slot
			"maxsp": 170, "maxf": 520, "slow": 26,   # Arrive
			"ax": 0.32, "ay": 0.3, "fx": 0.31, "fy": 0.47,   # the leader's Lissajous: amplitudes (× W, × H) and frequencies (Hz)
			"label": "goal = predict(leader, eta · lead) + R(h) · offset" },
		"rhyme": { "name": "Entourage", "hint": "six wingmen in three tight rows predicting further ahead — a motorcade that corners as one body",
			"dials": { "n": 6, "lead": 1.0, "gap": 0.07 } } },
	{ "id": "interpose", "letter": "I", "name": "Interpose",
		"hint": "the bodyguard Arrives at the midpoint between a VIP and a threat, both predicted ahead — press to move the threat",
		"dials": { "aim": "midpoint",    # "midpoint" guards the gap; "threat" goes for the attacker's future position
			"lead": 0.7,                 # seconds of prediction on both bodies
			"maxsp": 190, "maxf": 600, "slow": 30,   # Arrive
			"vipSpeed": 45, "threatSpeed": 70,       # px/s
			"label": "goal = (vip′ + threat′) ÷ 2 · x′ = x + v · lead" },
		"rhyme": { "name": "Interceptor", "hint": "no midpoint: it Arrives at the threat's own predicted position, faster and further ahead — a guard that goes out to meet trouble",
			"dials": { "aim": "threat", "lead": 1.1, "maxsp": 240 } } },
	{ "id": "hide", "letter": "H", "name": "Hide",
		"hint": "for each rock, the spot on its FAR SIDE from the hunter; Arrive at the nearest one and the line of sight (Ghost's) breaks — press to move the hunter",
		"dials": { "count": 3,           # rocks
			"radius": 0.09,              # rock size, × H
			"dist": 14,                  # how far behind the rock's rim the hiding spot sits, px
			"seed": 5,                   # the rock layout
			"maxsp": 160, "maxf": 520, "slow": 30,   # Arrive
			"hunterSpeed": 40,           # px/s, on noise
			"label": "spot = rock + norm(rock − hunter) · (r + dist)" },
		"rhyme": { "name": "Hermit", "hint": "six smaller rocks, a spot set well back from each rim, a slower hunter — a garden of hiding places, never in the open for long",
			"dials": { "count": 6, "radius": 0.06, "dist": 26 } } },
	{ "id": "hug", "letter": "H", "name": "Hug",
		"hint": "wall-following: a side feeler keeps a set gap from the wall while a nose feeler REFLECTS the velocity to stay inside (Obstacle's feelers) — press to shove it",
		"dials": { "mode": "hug",        # "hug" follows the wall at a gap; "contain" only bounces off it
			"room": "box",               # "box" or "bowl" — the shape of the boundary
			"gap": 0.09,                 # wanted distance from the wall, × min(W, H)
			"speed": 95,                 # cruise, px/s
			"feel": 0.12,                # nose feeler length, × min(W, H)
			"gain": 3,                   # how hard the side feeler corrects the gap
			"shove": 260,                # a press's impulse, px/s
			"label": "v′ = v − 2(v·n)n · side: err = gap − dist" },
		"rhyme": { "name": "Halfpipe", "hint": "containment only, in a round bowl, half again as fast — a puck that wanders until the nose feeler mirrors it off the rim",
			"dials": { "mode": "contain", "room": "bowl", "speed": 140 } } },
	{ "id": "judge", "letter": "J", "name": "Judge",
		"hint": "context steering: an INTEREST map and a DANGER map, one score per direction (drawn as spokes), pick the best and blend — press to move the goal",
		"dials": { "dirs": 16,           # directions considered
			"range": 0.28,               # how far an obstacle is felt, × min(W, H)
			"weight": 1.4,               # danger's pull against interest
			"smoothRate": 5,             # how fast the chosen heading is blended (1/s) — huge = raw
			"speed": 90,                 # px/s
			"count": 4, "radius": 0.08, "seed": 3,   # rocks: how many, size (× H), layout
			"label": "score[i] = interest[i] − danger[i] · w → argmax" },
		"rhyme": { "name": "Jumpy", "hint": "eight directions and no blending at all — the same two maps, but every decision snaps: the twitchy raw version",
			"dials": { "dirs": 8, "smoothRate": 200, "speed": 110 } } },
	{ "id": "flowfield", "letter": "F", "name": "Flowfield",
		"hint": "one breadth-first flood from the goal writes a distance into every cell; every unit just steps to its smallest neighbour (Astar's grid, Vectorfield's crowd) — press to move the goal",
		"dials": { "cols": 18, "rows": 12,   # the grid
			"units": 16,                 # walkers sharing the one field
			"speed": 2.6,                # cells per second
			"wallChance": 0.18, "seed": 21,   # the walls
			"retarget": 7,               # seconds before the goal moves on its own
			"label": "BFS from the goal: dist[n] = dist[c] + 1 · walk to min(dist)" },
		"rhyme": { "name": "Floodgate", "hint": "twice the walls and forty units pouring through the gaps — the field does not care how many read it",
			"dials": { "wallChance": 0.3, "units": 40, "speed": 3.2 } } },
	{ "id": "dijkstra", "letter": "D", "name": "Dijkstra",
		"hint": "a Dijkstra map: flood from several goals at once; monsters step DOWNHILL to hunt, and fleeing is the same map walked UPHILL (Astar, Flee) — press to place a goal",
		"dials": { "cols": 16, "rows": 11,   # the dungeon grid
			"goals": 1,                  # how many goal cells the flood starts from (all at distance 0)
			"mode": "seek",              # "seek" walks downhill, "flee" walks uphill
			"monsters": 4,
			"speed": 2.2,                # cells per second
			"wallChance": 0.2, "seed": 33,
			"wander": 5,                 # seconds before a goal moves on its own
			"label": "seek: step to min(dist) · flee: step to max(dist)" },
		"rhyme": { "name": "Dread", "hint": "two players on one map and the monsters flee it uphill — they pile into the far corridors, and the numbers show why",
			"dials": { "mode": "flee", "goals": 2, "monsters": 5 } } },
	{ "id": "influence", "letter": "I", "name": "Influence",
		"hint": "an influence map: every threat paints a falloff onto the grid, and the AI reads the sum to pick safe ground — or, bold, the hottest (Magnet's fields, on a grid) — press to drop a threat",
		"dials": { "cols": 20, "rows": 13,   # the grid
			"threats": 3,                # red wanderers painting the map
			"radius": 0.22,              # a threat's reach, × min(W, H)
			"bold": 0,                   # 0 = seek the safest cell around, 1 = seek the most threatened
			"think": 0.35,               # seconds between decisions
			"speed": 3,                  # cells per second
			"threatSpeed": 30,           # px/s
			"maxThreats": 7,
			"label": "threat[c] = Σ (1 − d/R)² · step to argmin (bold: argmax)" },
		"rhyme": { "name": "Incursion", "hint": "bold turned all the way up and a wider falloff — it reads the same map and marches into the hottest cell it can find",
			"dials": { "bold": 1, "radius": 0.32, "threats": 4 } } },
	{ "id": "nodes", "letter": "N", "name": "Nodes",
		"hint": "a behaviour tree: a SELECTOR tries branches in order, a SEQUENCE runs steps until one fails — Zones' brain, redrawn as a tree lit each tick — press to move the player",
		"dials": { "order": ["chase", "flee", "patrol"],   # the selector's children, first wins
			"sense": 0.3,                # the "near?" radius, × W
			"panic": 0.12,               # the "too close?" radius, × W
			"alert": 0.6,                # seconds the notice step runs before it succeeds
			"patrol": 50, "chase": 105, "flee": 130,   # px/s per branch
			"drift": 0.3,                # how briskly the player wanders
			"label": "? = first child not failing · → = every child succeeding" },
		"rhyme": { "name": "Nervous", "hint": "the flee branch is asked first and its ring is wide — the same tree, now a coward that closes in and bolts, closes in and bolts",
			"dials": { "order": ["flee", "chase", "patrol"], "panic": 0.24, "flee": 150 } } },
	{ "id": "utility", "letter": "U", "name": "Utility",
		"hint": "utility AI: every action scores need^k through its own response curve (the little graphs), the highest wins; the curves are the personality — press to drop food",
		"dials": { "w": [1, 1, 1, 0],    # weights per action: eat, sleep, play, hunt (0 switches an action off)
			"k": [2.2, 3, 1.4, 1],       # curve exponents: score = need^k — steep = ignores the need until it is urgent
			"rise": [0.07, 0.045, 0.09], # how fast hunger, tiredness and boredom grow, per second
			"think": 0.4,                # seconds between decisions
			"stick": 0.08,               # a bonus for the current action, so it does not dither
			"speed": 85,                 # px/s
			"label": "score = w · need^k · context → argmax" },
		"rhyme": { "name": "Undead", "hint": "only hunt is weighted; nothing else scores, no need ever rises — a zombie's flat curves, shuffling toward whoever is closest",
			"dials": { "w": [0, 0, 0, 1], "rise": [0, 0, 0], "speed": 45 } } },
	{ "id": "edge", "letter": "E", "name": "Edge",
		"hint": "the Goomba rule: a ray ahead of the feet points DOWN; no ground under it → turn around (Xmarks' ray, Zigzag's patrol) — press to cut a gap",
		"dials": { "rows": [0.3, 0.55, 0.78],   # platform heights, × H
			"speed": 55,                 # px/s
			"ahead": 12,                 # the probe's lead ahead of the feet, px
			"probe": 14,                 # the ray's length, px
			"gapW": 0.12,                # a cut gap's width, × W
			"autoGap": 4.5,              # seconds between the idle finger's cuts
			"walls": 0,                  # posts on the platforms; 0 = none — the ray only looks down
			"gapMax": 0,                 # gaps up to this width (× W) are JUMPED; 0 = never
			"g": 2.2,                    # gravity for the jump, × H
			"seed": 4,
			"label": "hit = ray(feet + dir · ahead, down, probe) · none → dir = −dir" },
		"rhyme": { "name": "Explorer", "hint": "the same ray also reads walls, and a gap it can clear is jumped instead of refused — a patroller that gets around",
			"dials": { "walls": 2, "gapMax": 0.18, "speed": 70 } } },
	{ "id": "villager", "letter": "V", "name": "Villager",
		"hint": "a daily schedule: the CLOCK picks the destination (home → field → market → tavern) and Astar's search on a tiny grid walks there — press to advance the clock",
		"dials": { "cols": 14, "rows": 9,   # the village grid
			"npcs": 3,
			"dayLen": 24,                # real seconds per 24-hour day
			"sched": [[6, "field"], [12, "market"], [18, "tavern"], [22, "home"]],   # hour → where to be
			"stagger": 0.9,              # hours between one villager's day and the next
			"speed": 2.6,                # cells per second
			"invert": false,             # swap the day and night tint
			"wallChance": 0.12, "seed": 9,
			"label": "place = sched[latest hour ≤ clock] · A* → path" },
		"rhyme": { "name": "Vampire", "hint": "the schedule runs at night and the tint is inverted — the field at dusk, the market at midnight, home before dawn",
			"dials": { "sched": [[20, "field"], [0, "market"], [3, "tavern"], [6, "home"]], "invert": true, "dayLen": 18 } } },
]

const LBL := Color(0.91, 0.898, 0.957, 0.55)   # the web label()'s default ink
const SHAPES := ["v", "line", "ring"]          # Formation's slot patterns, in press order
const NS := 1                                  # Nodes: success
const NF := 2                                  #        failure
const NR := 3                                  #        running
const BRANCHES := {                            # Nodes: branch name → the sequence's leaves
	"chase": ["near?", "notice", "chase"],
	"flee": ["close?", "flee"],
	"patrol": ["patrol"] }
const UNAMES := ["eat", "sleep", "play", "hunt"]   # Utility's actions
const UCOLS := [Kit.TARGET, Kit.MAGIC, Kit.GOOD, Kit.HOT]
const PLACE_COL := { "home": Kit.MOVER, "field": Kit.GOOD, "market": Kit.TARGET, "tavern": Kit.MAGIC }
const NPC_COLS := [Kit.MOVER, Kit.GOOD, Kit.BONE, Kit.TARGET, Kit.MAGIC]
const PAINT_EVERY := 0.1                       # Influence repaints its grid on this slow timer, not every tick

# ---------------------------------------------------------------- helpers

## The web's `len(...) || 1`: a length, or 1 when it is exactly zero.
static func _or1(x: float) -> float:
	return x if x != 0.0 else 1.0

## A kit colour at another alpha — the web's "rgba(245,193,105,0.45)".
static func _a(base: Color, alpha: float) -> Color:
	return Color(base, alpha)

## A number for a label: "1" for whole values, "0.25" otherwise (JS's "" + k).
static func _num(v: float) -> String:
	return ("%d" % roundi(v)) if v == roundf(v) else ("%s" % v)

## The web kit's ease(k): smoothstep, clamped.
static func _ease(k: float) -> float:
	var kk := clampf(k, 0.0, 1.0)
	return kk * kk * (3.0 - 2.0 * kk)

## Text at any size and alignment (0 left, 1 centre, 2 right) — the grid
## cards print a number in every cell at a size that fits the cell.
static func _text(n: CanvasItem, txt: String, p: Vector2, col: Color, fs: int = 10, align: int = 0) -> void:
	var f := ThemeDB.fallback_font
	var x := p.x
	if align > 0:
		var w: float = f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		x -= w if align == 2 else w / 2.0
	n.draw_string(f, Vector2(x, p.y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)

## Card A's Arrive on an agent dictionary {p, v}: full speed far away,
## braking inside the slow ring, the steering clamped to maxf.
static func _arrive(a: Dictionary, goal: Vector2, maxsp: float, maxf: float, slow: float, dt: float) -> void:
	var to: Vector2 = goal - (a.p as Vector2)
	var d := _or1(to.length())
	var sp: float = maxsp * minf(1.0, d / slow)
	var st: Vector2 = to / d * sp - (a.v as Vector2)
	var sl := st.length()
	if sl > maxf:
		st = st / sl * maxf
	a.v = (a.v as Vector2) + st * dt
	a.p = (a.p as Vector2) + (a.v as Vector2) * dt

## A cell index's row: an int is intended (the grid cards index cells as
## row · cols + col, the web's Math.floor(c / cols)).
@warning_ignore("integer_division")
static func _row(c: int, cols: int) -> int:
	return c / cols

## A cell's centre in card pixels (the grid cards keep cw / ch on b).
static func _cell_px(b: Dictionary, c: int) -> Vector2:
	var cols: int = b.cols
	return Vector2((c % cols + 0.5) * float(b.cw), (_row(c, cols) + 0.5) * float(b.ch))

# ---- Formation ----
## Offsets in the leader's frame: +x forward. (back, side) pairs for a V, a
## row for a line, angles for a ring.
static func _layout(b: Dictionary) -> void:
	var D: Dictionary = b.D
	var nn: int = D.n
	var S: float = b.S
	var shape: int = b.shape
	for i in nn:
		var sl: Dictionary = b.slots[i]
		var k: float = float(floori(i / 2.0) + 1)
		var side: float = 1.0 if i % 2 == 1 else -1.0
		if shape == 0:
			sl.o = Vector2(-k * S * 0.9, side * k * S * 0.8)              # a V, trailing
		elif shape == 1:
			sl.o = Vector2(-S * 0.3, side * k * S)                        # a line abreast
		else:
			var an: float = (i + 0.5) / nn * TAU
			sl.o = Vector2(cos(an), sin(an)) * S * 1.4                    # a ring

## Nearest free slot wins, one follower at a time.
static func _deal(b: Dictionary) -> void:
	var nn: int = (b.D as Dictionary).n
	var slots: Array = b.slots
	var fol: Array = b.fol
	for sl in slots:
		sl.taken = -1
	for f in fol:
		f.slot = -1
	for _round in nn:
		var best := -1
		var bd := INF
		var bs := -1
		for fi in nn:
			var f: Dictionary = fol[fi]
			if int(f.slot) >= 0:
				continue
			for si in nn:
				var sl: Dictionary = slots[si]
				if int(sl.taken) >= 0:
					continue
				var d: float = (sl.p as Vector2).distance_to(f.p)
				if d < bd:
					bd = d
					best = fi
					bs = si
		if best < 0:
			break
		fol[best].slot = bs
		slots[bs].taken = best

# ---- Hug ----
## Signed distance to the wall (positive inside) and its inward normal,
## packed as Vector3(d, nx, ny). One function serves a box and a bowl alike.
static func _sdf(b: Dictionary, p: Vector2) -> Vector3:
	var D: Dictionary = b.D
	if D.room == "bowl":
		var dv: Vector2 = p - (b.bc as Vector2)
		var d: float = dv.length()
		if d == 0.0:
			d = 0.001
		return Vector3(float(b.BR) - d, -dv.x / d, -dv.y / d)
	var dl: float = p.x - b.bx0
	var dr: float = b.bx1 - p.x
	var dtp: float = p.y - b.by0
	var db: float = b.by1 - p.y
	var m := dl
	var nx := 1.0
	var ny := 0.0
	if dr < m:
		m = dr
		nx = -1.0
		ny = 0.0
	if dtp < m:
		m = dtp
		nx = 0.0
		ny = 1.0
	if db < m:
		m = db
		nx = 0.0
		ny = -1.0
	return Vector3(m, nx, ny)

# ---- Judge ----
static func _judge_clear(b: Dictionary, p: Vector2) -> bool:
	for r in b.rocks:
		if p.distance_to(r.p) < float(r.r) + 14.0:
			return false
	return true

static func _judge_pick(b: Dictionary) -> Vector2:
	for _i in 16:
		var p := Vector2(randf_range(b.w * 0.08, b.w * 0.92), randf_range(b.h * 0.1, b.h * 0.88))
		if _judge_clear(b, p):
			return p
	return Vector2(b.w * 0.5, b.h * 0.9)

# ---- Flowfield / Dijkstra ----
## Breadth-first from every goal at once: a queue, one ring at a time.
## Writes b.dist (−1 = unreachable) and b.maxd. Only called when a goal
## moves — the walk between floods is pure lookup.
static func _flood(b: Dictionary) -> void:
	var cols: int = b.cols
	var N: int = b.N
	var walls: Array = b.walls
	var dist: Array = b.dist
	var queue: Array = []
	for i in N:
		dist[i] = -1
	for g in b.goals:
		walls[g] = false
		if int(dist[g]) < 0:
			dist[g] = 0
			queue.append(g)
	var head := 0
	var maxd := 1
	while head < queue.size():
		var c: int = queue[head]
		head += 1
		var cx: int = c % cols
		var nb := [c - 1, c + 1, c - cols, c + cols]
		for k in 4:
			var nc: int = nb[k]
			if nc < 0 or nc >= N:
				continue
			if k == 0 and cx == 0:
				continue
			if k == 1 and cx == cols - 1:
				continue
			if walls[nc] or int(dist[nc]) >= 0:
				continue
			dist[nc] = int(dist[c]) + 1
			if int(dist[nc]) > maxd:
				maxd = dist[nc]
			queue.append(nc)
	b.maxd = maxd

## A random reachable cell at least minD steps from a goal.
static func _open_cell(b: Dictionary, minD: int) -> int:
	var N: int = b.N
	for _i in 40:
		var c := randi_range(0, N - 1)
		if not b.walls[c] and int(b.dist[c]) >= minD:
			return c
	return b.goals[0]

## The smallest (or, uphill, the largest) neighbour; diagonals only when
## both sides are open, and a diagonal counts a little longer.
static func _next_of(b: Dictionary, cxi: int, cyi: int, uphill: bool) -> int:
	var cols: int = b.cols
	var rows: int = b.rows
	var walls: Array = b.walls
	var dist: Array = b.dist
	var best: int = cyi * cols + cxi
	var bd: float = float(dist[best])
	if bd < 0.0 and not uphill:
		bd = 1.0e9
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var nx: int = cxi + dx
			var ny: int = cyi + dy
			if nx < 0 or ny < 0 or nx >= cols or ny >= rows:
				continue
			var nc: int = ny * cols + nx
			if walls[nc] or int(dist[nc]) < 0:
				continue
			if dx != 0 and dy != 0 and (walls[cyi * cols + nx] or walls[ny * cols + cxi]):
				continue
			var diag: float = 0.0
			if dx != 0 and dy != 0:
				diag = -0.4 if uphill else 0.4
			var dd: float = float(dist[nc]) + diag
			if (dd > bd) if uphill else (dd < bd):
				bd = dd
				best = nc
	return best

## The heat of a distance grid: walls, unreachable cells, then a fade with
## the distance — and the number in every reachable cell.
static func _draw_dist_grid(n: CanvasItem, b: Dictionary, near: Color, uphill: bool) -> void:
	var cols: int = b.cols
	var N: int = b.N
	var cw: float = b.cw
	var ch: float = b.ch
	var maxd: float = float(b.maxd)
	var fs: int = int(maxf(7.0, minf(10.0, ch * 0.55)))
	for i in N:
		var x: float = (i % cols) * cw
		var y: float = _row(i, cols) * ch
		var cell := Rect2(x + 1.0, y + 1.0, cw - 2.0, ch - 2.0)
		if b.walls[i]:
			n.draw_rect(cell, _a(Kit.BONE, 0.32))
			continue
		var di: int = b.dist[i]
		if di < 0:
			n.draw_rect(cell, Color(0.0, 0.0, 0.0, 0.25))
			continue
		var k: float = di / maxd
		n.draw_rect(cell, _a(near, 0.3 * k if uphill else 0.28 * (1.0 - k)))
		_text(n, str(di), Vector2(x + cw * 0.5, y + ch * 0.5 + 3.0), Color(0.91, 0.898, 0.957, 0.4), fs, 1)

# ---- Influence ----
## Every threat PAINTS (1 − d/R)² onto the cells within its radius; the
## paints add. Runs on a slow timer (PAINT_EVERY), not every tick.
static func _paint(b: Dictionary) -> void:
	var cols: int = b.cols
	var rows: int = b.rows
	var N: int = b.N
	var cw: float = b.cw
	var ch: float = b.ch
	var R: float = b.R
	var grid: Array = b.map
	for i in N:
		grid[i] = 0.0
	for th in b.thr:
		var tp: Vector2 = th.p
		var c0 := clampi(floori((tp.x - R) / cw), 0, cols - 1)
		var c1 := clampi(floori((tp.x + R) / cw), 0, cols - 1)
		var r0 := clampi(floori((tp.y - R) / ch), 0, rows - 1)
		var r1 := clampi(floori((tp.y + R) / ch), 0, rows - 1)
		for cy in range(r0, r1 + 1):
			for cx in range(c0, c1 + 1):
				var d: float = Vector2((cx + 0.5) * cw - tp.x, (cy + 0.5) * ch - tp.y).length()
				if d < R:
					var k: float = 1.0 - d / R
					grid[cy * cols + cx] = float(grid[cy * cols + cx]) + k * k
	var peak := 0.001
	for i in N:
		if float(grid[i]) > peak:
			peak = grid[i]
	b.peak = peak

# ---- Nodes ----
## Walk toward a point at a speed, turning smoothly; true on arrival.
static func _nodes_walk(b: Dictionary, tgt: Vector2, speed: float) -> bool:
	var p: Vector2 = b.p
	var to: Vector2 = tgt - p
	var dd := _or1(to.length())
	if dd < 4.0:
		return true
	var dt0: float = b.dt0
	b.hd = float(b.hd) + wrapf(atan2(to.y, to.x) - float(b.hd), -PI, PI) * minf(1.0, 8.0 * dt0)
	var step: float = minf(dd, speed * dt0)
	b.p = p + to / dd * step
	return false

## A leaf: a condition ("near?") or an action ("chase"); answers S / F / R.
static func _nodes_leaf(b: Dictionary, leaf: String) -> int:
	var D: Dictionary = b.D
	var W: float = b.w
	var H: float = b.h
	var d: float = b.d
	var pp: Vector2 = b.pp
	match leaf:
		"near?":
			return NS if d < W * D.sense else NF
		"notice":
			b.noticeT = float(b.noticeT) + float(b.dt0)
			return NS if float(b.noticeT) >= float(D.alert) else NR
		"chase":
			_nodes_walk(b, pp, D.chase)
			return NR
		"close?":
			return NS if d < W * D.panic else NF
		"flee":
			var p: Vector2 = b.p
			var away: Vector2 = p - pp
			var dd := _or1(away.length())
			_nodes_walk(b, Vector2(clampf(p.x + away.x / dd * 60.0, 10.0, W * 0.55), clampf(p.y + away.y / dd * 60.0, 10.0, H - 10.0)), D.flee)
			return NR
		"patrol":
			var posts: Array = b.posts
			if _nodes_walk(b, posts[b.post], D.patrol):
				b.post = 1 - int(b.post)
			return NR
	return NF

## A SEQUENCE: run the leaves in order, stop at the first that is not a success.
static func _nodes_seq(b: Dictionary, bname: String) -> int:
	var kids: Array = BRANCHES.get(bname, BRANCHES.patrol)
	var status: Dictionary = b.status
	for k in kids:
		var st := _nodes_leaf(b, k)
		status[bname + "/" + k] = st
		if st != NS:
			status[bname] = st
			return st
	status[bname] = NS
	return NS

static func _nodes_col(st: int) -> Color:
	if st == NS:
		return Kit.GOOD
	if st == NF:
		return Kit.HOT
	if st == NR:
		return Kit.TARGET
	return _a(Kit.BONE, 0.35)

## A tree node: an outlined box, filled faintly when it was ticked.
static func _nodes_box(n: CanvasItem, p: Vector2, txt: String, st: int, wide: float) -> void:
	var bw := wide
	var bh := 12.0
	var r := Rect2(p.x - bw / 2.0, p.y - bh / 2.0, bw, bh)
	if st != 0:
		n.draw_rect(r, Color(0.91, 0.898, 0.957, 0.06))
	n.draw_rect(r, _nodes_col(st), false, 1.5 if st != 0 else 1.0)
	_text(n, txt, Vector2(p.x, p.y + 3.5), _nodes_col(st) if st != 0 else Kit.DIM, 10, 1)

# ---- Edge ----
## Is there platform under this x on this row?
static func _ground_at(b: Dictionary, row: int, x: float) -> bool:
	if x < b.w * 0.04 or x > b.w * 0.96:
		return false
	var r: Dictionary = b.prows[row]
	for g in r.gaps:
		if x > float(g[0]) and x < float(g[1]):
			return false
	return true

## From x, how far to the next ground in dir (1e9 = none).
static func _gap_width(b: Dictionary, row: int, x: float, dir: float) -> float:
	var s0 := 0.0
	while s0 < 400.0:
		var xx: float = x + dir * s0
		if xx < 0.0 or xx > b.w:
			return 1.0e9
		if _ground_at(b, row, xx):
			return s0
		s0 += 2.0
	return 1.0e9

static func _cut(b: Dictionary, row: int, cx: float) -> void:
	var r: Dictionary = b.prows[row]
	var w: float = b.w * float((b.D as Dictionary).gapW)
	r.gaps.append([cx - w / 2.0, cx + w / 2.0])
	if (r.gaps as Array).size() > 2:
		r.gaps.pop_front()

# ---- Villager ----
## Astar's search, compact: f = g + h with a Manhattan h. Returns the cell
## path from → to, or an empty array when there is none.
static func _astar(b: Dictionary, from: int, to: int) -> Array:
	var cols: int = b.cols
	var N: int = b.N
	var walls: Array = b.walls
	var g: Array = []
	var came: Array = []
	var closed: Array = []
	g.resize(N)
	came.resize(N)
	closed.resize(N)
	for i in N:
		g[i] = INF
		came[i] = -1
		closed[i] = false
	var open: Array = [from]
	g[from] = 0.0
	var tox: int = to % cols
	var toy: int = _row(to, cols)
	while open.size() > 0:
		var bi := 0
		for i in range(1, open.size()):
			var ci: int = open[i]
			var cb: int = open[bi]
			var fi: float = float(g[ci]) + absi(ci % cols - tox) + absi(_row(ci, cols) - toy)
			var fb: float = float(g[cb]) + absi(cb % cols - tox) + absi(_row(cb, cols) - toy)
			if fi < fb:
				bi = i
		var cur: int = open[bi]
		open[bi] = open[open.size() - 1]
		open.pop_back()
		if cur == to:
			break
		closed[cur] = true
		var cx: int = cur % cols
		var nb := [cur - 1, cur + 1, cur - cols, cur + cols]
		for k in 4:
			var nc: int = nb[k]
			if nc < 0 or nc >= N or (k == 0 and cx == 0) or (k == 1 and cx == cols - 1):
				continue
			if walls[nc] or closed[nc]:
				continue
			if float(g[cur]) + 1.0 < float(g[nc]):
				g[nc] = float(g[cur]) + 1.0
				came[nc] = cur
				if open.find(nc) < 0:
					open.append(nc)
	if int(came[to]) < 0 and to != from:
		return []
	var path: Array = []
	var i := to
	while i >= 0:
		path.append(i)
		if path.size() > N:
			break
		i = came[i]
	path.reverse()
	return path

## The latest schedule entry whose hour has passed names the place to be
## (before the first entry, yesterday's last still holds).
static func _place_at(D: Dictionary, hour: float) -> String:
	var sched: Array = D.sched
	var best: String = sched[sched.size() - 1][1]
	for e in sched:
		if hour >= float(e[0]):
			best = e[1]
	return best

## A grid card's shared geometry: cols, rows, N, cw, ch (the web's
## cw = W / cols, ch = (H − 18) / rows — the strip below is for the label).
static func _grid_setup(b: Dictionary) -> void:
	var D: Dictionary = b.D
	b.cols = int(D.cols)
	b.rows = int(D.rows)
	b.N = int(b.cols) * int(b.rows)
	b.cw = b.w / float(b.cols)
	b.ch = (b.h - 18.0) / float(b.rows)

static func init(b: Dictionary) -> void:
	var D: Dictionary = b.D
	var W: float = b.w
	var H: float = b.h
	match b.id:
		"formation":
			# a FORMATION is a list of OFFSETS in the leader's own frame: (back, side)
			# pairs for a V, a row for a line, angles for a ring. every frame each
			# offset is rotated by the leader's heading and added to its position —
			# that is the SLOT (an amber ring) — and each follower simply ARRIVES at
			# its slot with card A's brake ring. slots are re-dealt now and then by
			# nearest-first, so a follower never crosses the whole squad to reach
			# the one it was born with. the leader knows nothing about any of this.
			var nn: int = D.n
			b.S = minf(W, H) * float(D.spacing)
			b.lead = { "p": Vector2(W * 0.5, H * 0.5), "h": 0.0 }
			b.tgt = Vector2(W * 0.75, H * 0.4)
			b.timer = 0.0
			b.dealT = 0.0
			b.fol = []
			b.slots = []
			for i in nn:
				b.fol.append({ "p": Vector2(randf_range(W * 0.1, W * 0.9), randf_range(H * 0.1, H * 0.9)), "v": Vector2.ZERO, "slot": i })
				b.slots.append({ "o": Vector2.ZERO, "p": Vector2.ZERO, "taken": -1 })
			b.shape = maxi(0, SHAPES.find(D.shape))
			_layout(b)
		"escort":
			# OFFSET PURSUIT. an escort's slot is an offset in the leader's frame,
			# like Formation's — but this leader never slows down, so aiming at the
			# slot where it IS means always trailing. Chase's trick fixes it: guess
			# the time to get there (eta = distance ÷ speed), move the leader forward
			# by its velocity × eta × lead, and hang the slot off THAT point (the
			# faint amber ring). the leader flies a Lissajous, so its velocity is
			# known exactly — a real game would difference two frames.
			var nn: int = D.n
			b.S = minf(W, H) * float(D.gap)
			b.esc = []
			b.g = []                                     # each escort's predicted slot
			b.s0 = []                                    # each escort's slot right now
			for _i in nn:
				b.esc.append({ "p": Vector2(W * 0.5, H * 0.5), "v": Vector2.ZERO })
				b.g.append(Vector2(W * 0.5, H * 0.5))
				b.s0.append(Vector2(W * 0.5, H * 0.5))
			b.c = Vector2(W * 0.5, H * 0.5)              # the Lissajous centre and where it is drifting to
			b.want = b.c
			b.lp = b.c
			b.lv = Vector2.ZERO
			b.lh = 0.0
			b.pred = b.c                                 # the leader, predicted for wingman 0
		"interpose":
			# INTERPOSE: stand between. the goal is the MIDPOINT of two moving things
			# — but the midpoint of where they ARE is already stale, so both are
			# pushed forward by their velocity × lead first (Chase's prediction, used
			# twice), and card A's Arrive does the rest. the VIP grazes on noise; the
			# threat homes on the VIP; the mote is the bodyguard. the dashed line is
			# the gap being guarded, the amber ring the point it wants.
			b.vip = { "p": Vector2(W * 0.3, H * 0.5), "v": Vector2.ZERO }
			b.thr = { "p": Vector2(W * 0.85, H * 0.2), "v": Vector2.ZERO }
			b.me = { "p": Vector2(W * 0.5, H * 0.8), "v": Vector2.ZERO }
			b.blocks = 0
			b.flash = 0.0
			b.hold = 0.0
			b.vp = b.vip.p                               # both, predicted (kept for draw)
			b.tp = b.thr.p
			b.goal = b.me.p
		"hide":
			# HIDE. every obstacle offers one hiding place: continue the line from
			# the hunter through the rock's centre and step just past its far rim.
			# pick the nearest such spot and Arrive at it — no map, no search, one
			# subtraction per rock. the line from hunter to mote is the LINE OF
			# SIGHT; it is tested against each rock (Obstacle's projection: the
			# closest point on the segment to the centre) and turns green when a
			# rock breaks it. the hunter drifts, and every spot drifts with it.
			var rnd := Kit.rng(int(D.seed))
			var count: int = D.count
			b.rocks = []
			b.spots = []
			for _i in count:
				var rx: float = W * (0.18 + rnd.randf() * 0.64)
				var ry: float = H * (0.18 + rnd.randf() * 0.6)
				b.rocks.append({ "p": Vector2(rx, ry), "r": H * float(D.radius) * (0.75 + rnd.randf() * 0.5) })
				b.spots.append(Vector2.ZERO)
			b.me = { "p": Vector2(W * 0.5, H * 0.85), "v": Vector2.ZERO }
			b.hp = Vector2(W * 0.1, H * 0.15)
			b.hold = 0.0
			b.hidden = 0.0
			b.best = 0
			b.seen = true
			b.q = Vector2.ZERO                           # where the line of sight is broken
		"hug":
			# two habits, both from feelers. CONTAINMENT: a NOSE feeler pokes ahead;
			# if its tip would be outside the boundary, the velocity is REFLECTED
			# about the wall's normal (v − 2(v·n)n, the mirror formula) — that is
			# the whole of "stay in the room". WALL-FOLLOWING: a SIDE feeler measures
			# the distance to the wall on the mote's right; the error against the
			# wanted gap steers it in or out, and the cruise runs along the wall's
			# tangent. one signed-distance function serves a box and a bowl alike.
			var M := minf(W, H)
			b.GAP = M * float(D.gap)
			b.FEEL = M * float(D.feel)
			b.bx0 = W * 0.08
			b.by0 = H * 0.08
			b.bx1 = W * 0.92
			b.by1 = H * 0.9
			b.bc = Vector2(W / 2.0, H * 0.49)
			b.BR = minf(W * 0.42, H * 0.41)
			b.me = { "p": Vector2(W * 0.5, H * 0.5), "v": Vector2(60.0, 20.0) }
			b.reflectT = 0.0
			b.rp = Vector2.ZERO                          # where the last reflection happened, and its normal
			b.rn = Vector2.ZERO
			b.wanderA = 0.0
			b.side = Vector2.ZERO                        # the side feeler's tip (kept for draw)
			b.sideHit = false
			b.nose = Vector2.ZERO
		"judge":
			# CONTEXT STEERING never adds forces. it keeps two arrays, one slot per
			# compass direction: INTEREST (how much each direction points at the
			# goal — a dot product, clamped at zero) and DANGER (how much it points
			# at a nearby rock, stronger when closer). subtract, take the best slot,
			# and BLEND the heading toward it so the choice never flickers. the green
			# spokes are interest, the red ones danger, the amber spoke the winner.
			# it borrows Obstacle's rocks and Wander's patience.
			var M := minf(W, H)
			b.RANGE = M * float(D.range)
			var nn: int = D.dirs
			var rnd := Kit.rng(int(D.seed))
			b.rocks = []
			for _i in int(D.count):
				var rx: float = W * (0.15 + rnd.randf() * 0.7)
				var ry: float = H * (0.15 + rnd.randf() * 0.65)
				b.rocks.append({ "p": Vector2(rx, ry), "r": H * float(D.radius) * (0.7 + rnd.randf() * 0.6) })
			b.interest = []
			b.danger = []
			b.dirv = []
			for i in nn:
				b.interest.append(0.0)
				b.danger.append(0.0)
				b.dirv.append(Vector2(cos(i / float(nn) * TAU), sin(i / float(nn) * TAU)))
			b.p = Vector2(W * 0.1, H * 0.8)
			b.hd = 0.0                                   # the heading (b.h is the card height)
			b.goal = _judge_pick(b)
			b.timer = 0.0
			b.best = 0
		"flowfield":
			# A* answers one question — how does THIS unit reach the goal — and must
			# be asked again for every unit. a FLOW FIELD answers it for every cell
			# at once: flood outward from the goal breadth-first, writing into each
			# cell how many steps it is from the goal (the numbers). after that no
			# unit searches anything: it reads its neighbours and steps to the
			# smallest number. forty units cost the same as one. the field is only
			# rebuilt when the goal moves — the walk between is pure lookup.
			_grid_setup(b)
			var N: int = b.N
			var cols: int = b.cols
			var rows: int = b.rows
			var rnd := Kit.rng(int(D.seed))
			b.walls = []
			b.dist = []
			for _i in N:
				b.walls.append(rnd.randf() < float(D.wallChance))
				b.dist.append(-1)
			b.goals = [floori(rows / 2.0) * cols + floori(cols * 0.75)]
			b.maxd = 1
			b.timer = 0.0
			_flood(b)
			b.units = []
			for _i in int(D.units):
				var c := _open_cell(b, 3)
				b.units.append({ "p": Vector2(c % cols + 0.5, _row(c, cols) + 0.5), "dir": Vector2.ZERO })
		"dijkstra":
			# the roguelike's favourite trick. a DIJKSTRA MAP is Flowfield's flood
			# with a twist: seed the queue with SEVERAL goals at distance 0 and the
			# map reads "steps to the NEAREST goal" for free — one flood, any number
			# of players, doors, or smells. a monster hunts by stepping to its
			# smallest neighbour. to FLEE, walk the same map the other way: step to
			# the largest neighbour, and it retreats into the corridors furthest
			# from every goal — no second search, no flee vector, just a sign flip.
			_grid_setup(b)
			var N: int = b.N
			var cols: int = b.cols
			var rows: int = b.rows
			var rnd := Kit.rng(int(D.seed))
			b.walls = []
			b.dist = []
			for _i in N:
				b.walls.append(rnd.randf() < float(D.wallChance))
				b.dist.append(-1)
			b.goals = []
			for i in int(D.goals):
				b.goals.append(floori(rows * (0.3 + 0.4 * i)) * cols + floori(cols * (0.7 - 0.4 * i)))
			b.maxd = 1
			b.timer = 0.0
			_flood(b)
			b.mons = []
			for _i in int(D.monsters):
				var c := _open_cell(b, 3)
				b.mons.append({ "p": Vector2(c % cols + 0.5, _row(c, cols) + 0.5), "dir": Vector2.ZERO, "d": 1.0 })
		"influence":
			# an INFLUENCE MAP is Magnet's field frozen onto a grid. each threat
			# PAINTS: every cell within its radius gets (1 − d/R)², and the paints
			# ADD, so two weak enemies make one hot patch. the mote never looks at
			# the enemies — it reads the nine cells around it and steps to the
			# coolest (or, with bold turned up, the hottest: it goes where the fight
			# is). the same map, read differently, is a coward or a berserker; that
			# is why strategy games keep several maps and blend them.
			_grid_setup(b)
			var N: int = b.N
			b.R = minf(W, H) * float(D.radius)
			b.map = []
			for _i in N:
				b.map.append(0.0)
			b.thr = []
			for _i in int(D.threats):
				b.thr.append({ "p": Vector2(randf_range(W * 0.1, W * 0.9), randf_range(H * 0.1, H * 0.75)),
					"a": randf_range(0.0, TAU), "s": randf_range(0.0, 100.0) })
			b.me = { "p": Vector2(float(b.cols) * 0.5, float(b.rows) * 0.5), "tp": Vector2(float(b.cols) * 0.5, float(b.rows) * 0.5) }
			b.thinkT = 0.0
			b.paintT = 0.0
			b.peak = 0.001
			b.choice = -1
			b.cxi = int(float(b.cols) * 0.5)             # the cell being read, its heat, the mote's heading (kept for draw)
			b.cyi = int(float(b.rows) * 0.5)
			b.here = 0.0
			b.mang = 0.0
			_paint(b)
		"nodes":
			# a BEHAVIOUR TREE is Zones' state machine with the transitions deleted.
			# every frame the root is TICKED and each node answers success, failure
			# or running. a SELECTOR (?) asks its children in order and stops at the
			# first that is not a failure; a SEQUENCE (→) runs its children in order
			# and stops at the first that is not a success. leaves are conditions
			# ("near?") or actions ("chase"). the mood is never stored — it is
			# re-derived from scratch each tick, which is why reordering the branches
			# (the rhyme) changes the personality without touching a line of the brain.
			b.posts = [Vector2(W * 0.1, H * 0.25), Vector2(W * 0.42, H * 0.82)]
			b.p = b.posts[0]
			b.hd = 0.0                                   # the heading (b.h is the card height)
			b.post = 1
			b.pp = Vector2(W * 0.4, H * 0.5)             # the player
			b.hold = 0.0
			b.noticeT = 0.0
			b.caught = 0
			b.flash = 0.0
			b.status = {}                                # node id → status this tick
			b.d = 0.0
			b.dt0 = 1.0 / 60.0
			b.active = ""
		"utility":
			# UTILITY AI has no tree and no states: every action is given a SCORE
			# each think, and the best one runs. the score is a need pushed through
			# a RESPONSE CURVE — need^k — so k is a personality: a low k acts early
			# and often, a high k ignores the need until it is desperate. hunting
			# reads the player's closeness instead of a need. needs rise on their
			# own and fall while the action runs, so the loop feeds itself: eat,
			# then play, then sleep, in whatever order the curves decide today.
			b.need = [0.3, 0.1, 0.5]
			b.spots = [Vector2(W * 0.8, H * 0.7), Vector2(W * 0.15, H * 0.72), Vector2(W * 0.5, H * 0.85)]
			b.me = { "p": Vector2(W * 0.5, H * 0.6), "h": 0.0 }
			b.pp = Vector2(W * 0.3, H * 0.45)
			b.thinkT = 0.0
			b.act = 0
			b.score = [0.0, 0.0, 0.0, 0.0]
			b.close = 0.0
		"edge":
			# the CLIFF SENSOR. a patroller does not know its platform's length; it
			# casts one short RAY, a little ahead of its feet, straight DOWN. ground
			# found → keep walking; nothing found → turn around. that single test is
			# every Goomba, every Koopa, every sentry on a ledge. the explorer rhyme
			# adds two more reads of the same ray: a forward probe for walls, and,
			# when the drop ahead is a gap it could clear, a jump instead of a turn.
			var rnd := Kit.rng(int(D.seed))
			b.prows = []
			b.bots = []
			var fr: Array = D.rows
			for i in fr.size():
				var r := { "y": H * float(fr[i]), "gaps": [], "walls": [] }
				for _k in int(D.walls):
					r.walls.append(0.15 + rnd.randf() * 0.7)
				b.prows.append(r)
				b.bots.append({ "row": i, "x": W * (0.2 + i * 0.25), "dir": -1.0 if i % 2 == 1 else 1.0, "vy": 0.0,
					"y": r.y, "air": false, "flash": 0.0, "fx": 0.0, "hit": true, "wall": false, "word": "turn" })
			b.gapT = 2.0
		"villager":
			# a DAILY SCHEDULE is a lookup table keyed by the clock: the latest
			# entry whose hour has passed names the place to be. when the place
			# changes, Astar's search (f = g + h, Manhattan h) plans a route across
			# the village, and the villager walks it cell by cell. that is the whole
			# of a Stardew townsperson: no goals, no needs, a table and a
			# pathfinder. each villager's clock is staggered a little, so the
			# street never empties all at once. the tint is the hour, made visible.
			_grid_setup(b)
			var N: int = b.N
			var cols: int = b.cols
			var rows: int = b.rows
			var rnd := Kit.rng(int(D.seed))
			b.walls = []
			for _i in N:
				b.walls.append(rnd.randf() < float(D.wallChance))
			b.places = { "home": Vector2i(1, 1), "field": Vector2i(cols - 2, 1),
				"market": Vector2i(floori(cols / 2.0), rows - 2), "tavern": Vector2i(1, rows - 2) }
			for k in b.places:                           # every place sits in a cleared 3×3
				var pc: Vector2i = b.places[k]
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						var cx: int = pc.x + dx
						var cy: int = pc.y + dy
						if cx >= 0 and cy >= 0 and cx < cols and cy < rows:
							b.walls[cy * cols + cx] = false
			b.npcs = []
			var home: Vector2i = b.places.home
			for i in int(D.npcs):
				b.npcs.append({ "cell": home.y * cols + home.x, "path": [], "pi": 0, "k": 0.0, "place": "",
					"col": NPC_COLS[i % 5], "dp": Vector2.ZERO, "ang": 0.0 })
			b.advance = 0.0
			b.clock = 0.0

static func press(b: Dictionary, pos: Vector2) -> void:
	var D: Dictionary = b.D
	var W: float = b.w
	var H: float = b.h
	match b.id:
		"formation":
			var lead: Dictionary = b.lead
			if pos.distance_to(lead.p) < 18.0:
				b.shape = (int(b.shape) + 1) % 3
				_layout(b)
				b.dealT = 0.0
			else:
				b.tgt = Vector2(clampf(pos.x, 12.0, W - 12.0), clampf(pos.y, 12.0, H - 12.0))
				b.timer = -5.0
		"escort":
			b.want = Vector2(clampf(pos.x, W * 0.35, W * 0.65), clampf(pos.y, H * 0.35, H * 0.65))
		"interpose":
			var thr: Dictionary = b.thr
			thr.p = Vector2(clampf(pos.x, 10.0, W - 10.0), clampf(pos.y, 10.0, H - 10.0))
			thr.v = Vector2.ZERO
			b.hold = 1.5
		"hide":
			b.hp = Vector2(clampf(pos.x, 8.0, W - 8.0), clampf(pos.y, 8.0, H - 8.0))
			b.hold = 4.0
		"hug":
			var me: Dictionary = b.me
			var dv: Vector2 = pos - (me.p as Vector2)
			var d := _or1(dv.length())
			me.v = dv / d * float(D.shove)
		"judge":
			b.goal = Vector2(clampf(pos.x, 8.0, W - 8.0), clampf(pos.y, 8.0, H - 8.0))
			b.timer = -6.0
		"flowfield":
			var cols: int = b.cols
			var c: int = clampi(floori(pos.y / float(b.ch)), 0, int(b.rows) - 1) * cols + clampi(floori(pos.x / float(b.cw)), 0, cols - 1)
			if b.walls[c]:
				b.walls[c] = false
			b.goals = [c]
			b.timer = -4.0
			_flood(b)
		"dijkstra":
			var cols: int = b.cols
			var c: int = clampi(floori(pos.y / float(b.ch)), 0, int(b.rows) - 1) * cols + clampi(floori(pos.x / float(b.cw)), 0, cols - 1)
			b.goals.pop_front()                          # the oldest goal is replaced
			b.goals.append(c)
			b.timer = -3.0
			_flood(b)
		"influence":
			var thr: Array = b.thr
			if thr.size() >= int(D.maxThreats):
				thr.pop_front()
			thr.append({ "p": Vector2(clampf(pos.x, 4.0, W - 4.0), clampf(pos.y, 4.0, H - 22.0)),
				"a": randf_range(0.0, TAU), "s": randf_range(0.0, 100.0) })
			b.paintT = 0.0                               # a new threat repaints at once
		"nodes":
			b.pp = Vector2(clampf(pos.x, 10.0, W * 0.55), clampf(pos.y, 10.0, H - 10.0))
			b.hold = 4.0
		"utility":
			b.spots[0] = Vector2(clampf(pos.x, 12.0, W - 12.0), clampf(pos.y, H * 0.3, H - 22.0))
		"edge":
			var best := 0
			var bd := INF
			var prows: Array = b.prows
			for i in prows.size():
				var dd: float = absf(float(prows[i].y) - pos.y)
				if dd < bd:
					bd = dd
					best = i
			_cut(b, best, clampf(pos.x, W * 0.12, W * 0.88))
			b.gapT = -1.0
		"villager":
			b.advance = float(b.advance) + 3.0

static func tick(b: Dictionary, dt: float, t: float) -> void:
	var D: Dictionary = b.D
	var W: float = b.w
	var H: float = b.h
	match b.id:
		"formation":
			var lead: Dictionary = b.lead
			b.timer = float(b.timer) + dt
			if float(b.timer) > float(D.retarget):
				b.timer = 0.0
				b.tgt = Vector2(randf_range(W * 0.15, W * 0.85), randf_range(H * 0.15, H * 0.85))
			var lp: Vector2 = lead.p
			var to: Vector2 = (b.tgt as Vector2) - lp     # the leader: a slow turn toward its spot
			var d := _or1(to.length())
			var lh: float = lead.h
			lh += wrapf(atan2(to.y, to.x) - lh, -PI, PI) * minf(1.0, 2.5 * dt)
			var sp: float = float(D.leadSpeed) * minf(1.0, d / 40.0)
			lp += Vector2(cos(lh), sin(lh)) * sp * dt
			lead.h = lh
			lead.p = lp
			var c := cos(lh)
			var sn := sin(lh)
			for sl in b.slots:                           # offset → world: rotate by the heading, add the leader
				var o: Vector2 = sl.o
				sl.p = lp + Vector2(o.x * c - o.y * sn, o.x * sn + o.y * c)
			b.dealT = float(b.dealT) - dt
			if float(b.dealT) <= 0.0:
				b.dealT = float(D.reassign)
				_deal(b)
			for f in b.fol:
				var si: int = maxi(0, int(f.slot))
				var sl: Dictionary = b.slots[si]
				_arrive(f, sl.p, D.maxsp, D.maxf, D.slow, dt)
				var fp: Vector2 = f.p
				f.p = Vector2(clampf(fp.x, -20.0, W + 20.0), clampf(fp.y, -20.0, H + 20.0))
		"escort":
			var nn: int = D.n
			var S: float = b.S
			var k := Kit.smooth(1.5, dt)
			b.c = (b.c as Vector2) + ((b.want as Vector2) - (b.c as Vector2)) * k
			var c0: Vector2 = b.c
			var aa: float = t * float(D.fx) * TAU
			var bb: float = t * float(D.fy) * TAU
			var lp := Vector2(c0.x + sin(aa) * W * float(D.ax), c0.y + sin(bb) * H * float(D.ay))
			var lv := Vector2(cos(aa) * float(D.fx) * TAU * W * float(D.ax), cos(bb) * float(D.fy) * TAU * H * float(D.ay))   # the derivative
			b.lp = lp
			b.lv = lv
			if lv.length() > 1.0:
				b.lh = atan2(lv.y, lv.x)
			var lh: float = b.lh
			var ch := cos(lh)
			var sh := sin(lh)
			for i in nn:
				var e: Dictionary = b.esc[i]
				var row: float = float(floori(i / 2.0) + 1)
				var side: float = (1.0 if i % 2 == 1 else -1.0) * (0.0 if nn == 1 else 1.0)
				var ox: float = -row * S
				var oy: float = side * row * S * 0.8
				var rot := Vector2(ox * ch - oy * sh, ox * sh + oy * ch)
				var s0: Vector2 = lp + rot                   # the slot right now
				b.s0[i] = s0
				var eta: float = clampf(s0.distance_to(e.p) / float(D.maxsp), 0.0, 1.2)   # time to get there, at full speed
				var pred: Vector2 = lp + lv * eta * float(D.lead)                        # the leader, predicted
				if i == 0:
					b.pred = pred
				var g: Vector2 = pred + rot                  # the slot, predicted
				b.g[i] = g
				_arrive(e, g, D.maxsp, D.maxf, D.slow, dt)
				var ep: Vector2 = e.p
				e.p = Vector2(clampf(ep.x, -30.0, W + 30.0), clampf(ep.y, -30.0, H + 30.0))
		"interpose":
			var vip: Dictionary = b.vip
			var thr: Dictionary = b.thr
			var me: Dictionary = b.me
			var lead: float = D.lead
			var a: float = Kit.noise(t * 0.3 + 9.0) * PI * 1.6   # the vip grazes
			var nv := Vector2(cos(a), sin(a)) * float(D.vipSpeed)
			var vp: Vector2 = vip.p
			var vv: Vector2 = vip.v
			if vp.x < W * 0.12:
				nv.x = absf(nv.x)
			if vp.x > W * 0.88:
				nv.x = -absf(nv.x)
			if vp.y < H * 0.15:
				nv.y = absf(nv.y)
			if vp.y > H * 0.85:
				nv.y = -absf(nv.y)
			vv += (nv - vv) * minf(1.0, 3.0 * dt)
			vp += vv * dt
			vip.p = vp
			vip.v = vv
			b.hold = float(b.hold) - dt
			var tp: Vector2 = thr.p
			var tv: Vector2 = thr.v
			var tdv: Vector2 = vp - tp
			var td := _or1(tdv.length())
			if float(b.hold) <= 0.0:                     # the threat homes on the vip
				tv += (tdv / td * float(D.threatSpeed) - tv) * minf(1.0, 2.0 * dt)
			tp += tv * dt
			var vpred: Vector2 = vp + vv * lead          # both, predicted
			var tpred: Vector2 = tp + tv * lead
			var goal: Vector2 = (vpred + tpred) / 2.0
			if D.aim == "threat":
				goal = tpred
			_arrive(me, goal, D.maxsp, D.maxf, D.slow, dt)
			var mp: Vector2 = me.p
			mp = Vector2(clampf(mp.x, 8.0, W - 8.0), clampf(mp.y, 8.0, H - 8.0))
			me.p = mp
			var md: float = tp.distance_to(mp)
			if md < 16.0:                                # blocked: the threat is bounced far away
				b.blocks = int(b.blocks) + 1
				b.flash = 1.0
				var ang := randf_range(0.0, TAU)
				tp = Vector2(clampf(vp.x + cos(ang) * W * 0.45, 10.0, W - 10.0), clampf(vp.y + sin(ang) * H * 0.45, 10.0, H - 10.0))
				tv = Vector2.ZERO
			elif td < 14.0:                              # the vip was reached: reset the threat, no flash
				var ang := randf_range(0.0, TAU)
				tp = Vector2(clampf(vp.x + cos(ang) * W * 0.45, 10.0, W - 10.0), clampf(vp.y + sin(ang) * H * 0.45, 10.0, H - 10.0))
			thr.p = tp
			thr.v = tv
			b.flash = maxf(0.0, float(b.flash) - dt * 2.0)
			b.vp = vpred
			b.tp = tpred
			b.goal = goal
		"hide":
			var me: Dictionary = b.me
			var count: int = D.count
			var hp: Vector2 = b.hp
			b.hold = float(b.hold) - dt
			if float(b.hold) <= 0.0:                     # the hunter drifts, on noise, staying off the rocks
				var a: float = Kit.noise(t * 0.22 + 17.0) * PI * 1.7
				hp = Vector2(clampf(hp.x + cos(a) * float(D.hunterSpeed) * dt, 10.0, W - 10.0),
					clampf(hp.y + sin(a) * float(D.hunterSpeed) * dt, 10.0, H - 10.0))
			for r in b.rocks:
				var rp: Vector2 = r.p
				var rr: float = r.r
				var dv: Vector2 = hp - rp
				var d := _or1(dv.length())
				if d < rr + 10.0:
					hp = rp + dv / d * (rr + 10.0)
			b.hp = hp
			var best := 0
			var bd := INF
			var mp: Vector2 = me.p
			for i in count:                              # one spot per rock, on the far side
				var r: Dictionary = b.rocks[i]
				var rp: Vector2 = r.p
				var dv: Vector2 = rp - hp
				var d := _or1(dv.length())
				var spot: Vector2 = rp + dv / d * (float(r.r) + float(D.dist))
				b.spots[i] = spot
				var md := spot.distance_to(mp)
				if md < bd:
					bd = md
					best = i
			b.best = best
			_arrive(me, b.spots[best], D.maxsp, D.maxf, D.slow, dt)
			mp = me.p
			for r in b.rocks:                            # never inside a rock
				var rp: Vector2 = r.p
				var rr: float = r.r
				var dv: Vector2 = mp - rp
				var rd := _or1(dv.length())
				if rd < rr + 7.0:
					mp = rp + dv / rd * (rr + 7.0)
			mp = Vector2(clampf(mp.x, 8.0, W - 8.0), clampf(mp.y, 8.0, H - 8.0))
			me.p = mp
			var seen := true                             # the line of sight vs every rock
			var q := Vector2.ZERO
			var lv: Vector2 = mp - hp
			var L := _or1(lv.length())
			var u: Vector2 = lv / L
			for r in b.rocks:
				var rp: Vector2 = r.p
				var along: float = clampf((rp - hp).dot(u), 0.0, L)
				var pt: Vector2 = hp + u * along
				if pt.distance_to(rp) < float(r.r):
					seen = false
					q = pt
					break
			if not seen:
				b.hidden = float(b.hidden) + dt
			b.seen = seen
			b.q = q
		"hug":
			var me: Dictionary = b.me
			var GAP: float = b.GAP
			var FEEL: float = b.FEEL
			var speed: float = D.speed
			var hug: bool = D.mode == "hug"
			var mp: Vector2 = me.p
			var mv: Vector2 = me.v
			var v := _or1(mv.length())
			var hd: Vector2 = mv / v
			var des := Vector2.ZERO
			var side := Vector2.ZERO
			var sideHit := false
			if hug:
				var perp := Vector2(-hd.y, hd.x)          # the mote's right-hand side
				side = mp + perp * GAP * 2.0
				var sd := _sdf(b, side)
				sideHit = sd.x < GAP * 1.5               # a wall is near on the right
				sd = _sdf(b, mp)
				if sd.x < GAP * 2.5:                     # near a wall: cruise along it, correct the gap
					var tang := Vector2(-sd.z, sd.y)      # the tangent that keeps the wall on the right
					var err: float = GAP - sd.x
					des = tang * speed + Vector2(sd.y, sd.z) * err * float(D.gain) * 6.0
				else:                                    # far from any wall: seek the nearest one
					des = -Vector2(sd.y, sd.z) * speed
			else:                                        # contain: a wander, bounced
				var wa: float = float(b.wanderA) + Kit.noise(t * 0.7 + 3.0) * 2.2 * dt
				b.wanderA = wa
				des = Vector2(cos(wa), sin(wa)) * speed
			mv += (des - mv) * minf(1.0, 4.0 * dt)
			var v2 := _or1(mv.length())
			if v2 > speed * 1.6 or (not hug and v2 < speed * 0.8):
				mv *= speed / v2
			var v3 := _or1(mv.length())
			hd = mv / v3
			var nose: Vector2 = mp + hd * FEEL           # the nose feeler
			var nd := _sdf(b, nose)
			if nd.x < 0.0:                               # the tip is outside: reflect
				var nrm := Vector2(nd.y, nd.z)
				var dotp: float = mv.dot(nrm)
				if dotp < 0.0:
					mv -= 2.0 * dotp * nrm
					b.reflectT = 0.5
					b.rp = nose - nrm * nd.x
					b.rn = nrm
					if not hug:
						b.wanderA = atan2(mv.y, mv.x)
			mp += mv * dt
			var pd := _sdf(b, mp)
			if pd.x < 6.0:                               # never through the wall
				mp += Vector2(pd.y, pd.z) * (6.0 - pd.x)
			me.p = mp
			me.v = mv
			b.reflectT = maxf(0.0, float(b.reflectT) - dt)
			b.side = side
			b.sideHit = sideHit
			b.nose = nose
		"judge":
			var nn: int = D.dirs
			var RANGE: float = b.RANGE
			var p: Vector2 = b.p
			var goal: Vector2 = b.goal
			var interest: Array = b.interest
			var danger: Array = b.danger
			var dirv: Array = b.dirv
			b.timer = float(b.timer) + dt
			var gdv: Vector2 = goal - p
			var gd := _or1(gdv.length())
			if gd < 10.0 or float(b.timer) > 8.0:
				b.goal = _judge_pick(b)
				b.timer = 0.0
			for i in nn:                                 # the two maps
				var dv: Vector2 = dirv[i]
				interest[i] = maxf(0.0, dv.dot(gdv) / gd)
				danger[i] = 0.0
			for r in b.rocks:
				var rdv: Vector2 = (r.p as Vector2) - p
				var d := _or1(rdv.length())
				var near: float = clampf(1.0 - (d - float(r.r)) / RANGE, 0.0, 1.0)
				if near <= 0.0:
					continue
				for i in nn:
					var dv: Vector2 = dirv[i]
					var dp: float = dv.dot(rdv) / d
					if dp > 0.0:
						danger[i] = maxf(float(danger[i]), dp * dp * near)
			var bs := -INF
			var best: int = b.best
			for i in nn:
				var sc: float = float(interest[i]) - float(danger[i]) * float(D.weight)
				if sc > bs:
					bs = sc
					best = i
			b.best = best
			var want: float = best / float(nn) * TAU
			var h: float = b.hd
			h += wrapf(want - h, -PI, PI) * Kit.smooth(float(D.smoothRate), dt)   # blend the heading, the short way round
			b.hd = h
			var sp: float = float(D.speed) * minf(1.0, gd / 30.0)
			p += Vector2(cos(h), sin(h)) * sp * dt
			for r in b.rocks:
				var rv: Vector2 = p - (r.p as Vector2)
				var rd := _or1(rv.length())
				if rd < float(r.r) + 8.0:
					p = (r.p as Vector2) + rv / rd * (float(r.r) + 8.0)
			b.p = Vector2(clampf(p.x, 8.0, W - 8.0), clampf(p.y, 8.0, H - 8.0))
		"flowfield":
			var cols: int = b.cols
			var rows: int = b.rows
			var speed: float = D.speed
			b.timer = float(b.timer) + dt
			if float(b.timer) > float(D.retarget):
				b.timer = 0.0
				b.goals = [_open_cell(b, 3)]
				_flood(b)
			var goal: int = b.goals[0]
			for un in b.units:                           # read, then step
				var up: Vector2 = un.p
				var cxi := clampi(floori(up.x), 0, cols - 1)
				var cyi := clampi(floori(up.y), 0, rows - 1)
				var here: int = cyi * cols + cxi
				if here == goal or int(b.dist[here]) < 0:
					var c := _open_cell(b, 3)
					un.p = Vector2(c % cols + 0.5, _row(c, cols) + 0.5)
					un.dir = Vector2.ZERO
					continue
				var nc := _next_of(b, cxi, cyi, false)
				var tgt := Vector2(nc % cols + 0.5, _row(nc, cols) + 0.5)
				var dv: Vector2 = tgt - up
				var d := _or1(dv.length())
				var step: float = minf(d, speed * dt)
				un.p = up + dv / d * step
				un.dir = dv / d
		"dijkstra":
			var cols: int = b.cols
			var rows: int = b.rows
			var speed: float = D.speed
			var flee: bool = D.mode == "flee"
			b.timer = float(b.timer) + dt
			if float(b.timer) > float(D.wander):
				b.timer = 0.0
				var ng := _open_cell(b, 2)                # picked before the oldest goal goes (the fallback reads goals[0])
				b.goals.pop_front()
				b.goals.append(ng)
				_flood(b)
			for m in b.mons:
				var mp: Vector2 = m.p
				var cxi := clampi(floori(mp.x), 0, cols - 1)
				var cyi := clampi(floori(mp.y), 0, rows - 1)
				var here: int = cyi * cols + cxi
				var dh: int = b.dist[here]
				if dh < 0:
					var c := _open_cell(b, 1)
					m.p = Vector2(c % cols + 0.5, _row(c, cols) + 0.5)
					continue
				if not flee and dh == 0:                 # caught: it respawns far off
					var c := _open_cell(b, 4)
					m.p = Vector2(c % cols + 0.5, _row(c, cols) + 0.5)
					continue
				var nc := _next_of(b, cxi, cyi, flee)
				var tgt := Vector2(nc % cols + 0.5, _row(nc, cols) + 0.5)
				var dv: Vector2 = tgt - mp
				var d := _or1(dv.length())
				var step: float = minf(d, speed * dt)
				m.p = mp + dv / d * step
				m.dir = dv / d
				m.d = d
		"influence":
			var cols: int = b.cols
			var rows: int = b.rows
			var me: Dictionary = b.me
			var grid: Array = b.map
			for th in b.thr:                             # the threats wander on noise
				var ta: float = float(th.a) + Kit.noise(t * 0.5 + float(th.s)) * 1.8 * dt
				var tp: Vector2 = (th.p as Vector2) + Vector2(cos(ta), sin(ta)) * float(D.threatSpeed) * dt
				if tp.x < 6.0 or tp.x > W - 6.0 or tp.y < 6.0 or tp.y > H - 24.0:
					ta += PI
					tp = Vector2(clampf(tp.x, 6.0, W - 6.0), clampf(tp.y, 6.0, H - 24.0))
				th.a = ta
				th.p = tp
			b.paintT = float(b.paintT) - dt              # the web paints every frame; here on a slow timer
			if float(b.paintT) <= 0.0:
				b.paintT = PAINT_EVERY
				_paint(b)
			b.thinkT = float(b.thinkT) - dt
			var mp: Vector2 = me.p
			var cxi := clampi(floori(mp.x), 0, cols - 1)
			var cyi := clampi(floori(mp.y), 0, rows - 1)
			if float(b.thinkT) <= 0.0:                   # read the nine cells, pick one
				b.thinkT = float(D.think)
				var best: int = cyi * cols + cxi
				var bs := -INF
				var sgn: float = float(D.bold) * 2.0 - 1.0
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						var nx: int = cxi + dx
						var ny: int = cyi + dy
						if nx < 0 or ny < 0 or nx >= cols or ny >= rows:
							continue
						var nc: int = ny * cols + nx
						var sc: float = sgn * float(grid[nc]) - 0.002 * Vector2(nx + 0.5 - cols / 2.0, ny + 0.5 - rows / 2.0).length() + randf_range(0.0, 0.0005)   # a whisper toward the centre breaks ties
						if sc > bs:
							bs = sc
							best = nc
				b.choice = best
				me.tp = Vector2(best % cols + 0.5, _row(best, cols) + 0.5)
			var dv: Vector2 = (me.tp as Vector2) - mp
			var d := _or1(dv.length())
			var step: float = minf(d, float(D.speed) * dt)
			me.p = mp + dv / d * step
			b.mang = atan2(dv.y, dv.x)
			b.here = float(grid[cyi * cols + cxi])
			b.cxi = cxi
			b.cyi = cyi
		"nodes":
			b.dt0 = dt
			b.hold = float(b.hold) - dt
			var pp: Vector2 = b.pp
			if float(b.hold) <= 0.0:                     # the player drifts on noise inside the scene half
				var a: float = Kit.noise(t * float(D.drift) + 5.0) * PI * 1.5
				pp = Vector2(clampf(pp.x + cos(a) * 34.0 * dt, 12.0, W * 0.55), clampf(pp.y + sin(a) * 34.0 * dt, 12.0, H - 12.0))
			b.pp = pp
			b.d = pp.distance_to(b.p)
			var status: Dictionary = b.status
			for k in status.keys():
				status[k] = 0
			var root := NF
			var active := ""
			for bname in D.order:                        # the selector
				var st := _nodes_seq(b, bname)
				if st != NF:
					root = st
					active = bname
					break
			status.root = root
			b.active = active
			if active != "chase":                        # the notice timer cools when not ticked
				b.noticeT = maxf(0.0, float(b.noticeT) - dt * 2.0)
			var p: Vector2 = b.p
			if float(b.d) < 12.0:
				b.caught = int(b.caught) + 1
				b.flash = 1.0
				b.pp = Vector2(W * 0.5 if p.x < W * 0.28 else W * 0.08, randf_range(H * 0.15, H * 0.85))
				b.hold = 1.0
				b.noticeT = 0.0
			b.flash = maxf(0.0, float(b.flash) - dt * 2.0)
			b.p = Vector2(clampf(p.x, 8.0, W * 0.58), clampf(p.y, 8.0, H - 8.0))
		"utility":
			var need: Array = b.need
			var rise: Array = D.rise
			var wts: Array = D.w
			var ks: Array = D.k
			var me: Dictionary = b.me
			var score: Array = b.score
			for i in 3:
				need[i] = clampf(float(need[i]) + float(rise[i]) * dt, 0.0, 1.0)
			var a: float = Kit.noise(t * 0.25 + 11.0) * PI * 1.6   # the player drifts
			var pp: Vector2 = b.pp
			pp = Vector2(clampf(pp.x + cos(a) * 30.0 * dt, 12.0, W - 12.0), clampf(pp.y + sin(a) * 30.0 * dt, H * 0.3, H - 22.0))
			var mp: Vector2 = me.p
			var close: float = clampf(1.0 - pp.distance_to(mp) / (W * 0.6), 0.0, 1.0)
			b.close = close
			b.thinkT = float(b.thinkT) - dt
			var act: int = b.act
			if float(b.thinkT) <= 0.0:
				b.thinkT = float(D.think)
				for i in 3:
					score[i] = float(wts[i]) * pow(float(need[i]), float(ks[i]))
				score[3] = float(wts[3]) * pow(0.4 + 0.6 * close, float(ks[3]))
				var best := act
				var bs := -1.0
				for i in 4:
					var sc: float = float(score[i]) + (float(D.stick) if i == act else 0.0)
					if sc > bs:
						bs = sc
						best = i
				act = best
				b.act = act
			var goal: Vector2 = b.spots[act] if act < 3 else pp
			var dv: Vector2 = goal - mp
			var d := _or1(dv.length())
			if d > 10.0:
				me.h = atan2(dv.y, dv.x)
				var step: float = minf(d, float(D.speed) * dt)
				me.p = mp + dv / d * step
			elif act < 3:                                # doing it: the need drains
				need[act] = clampf(float(need[act]) - dt * 0.35, 0.0, 1.0)
			elif float(wts[3]) > 0.0:                    # caught: the player reappears
				pp = Vector2(randf_range(W * 0.1, W * 0.9), randf_range(H * 0.35, H * 0.8))
			b.pp = pp
		"edge":
			var prows: Array = b.prows
			var speed: float = D.speed
			var ahead: float = D.ahead
			var gapMax: float = D.gapMax
			var nwalls: int = D.walls
			b.gapT = float(b.gapT) + dt
			if float(b.gapT) > float(D.autoGap):
				b.gapT = 0.0
				_cut(b, randi_range(0, prows.size() - 1), randf_range(W * 0.15, W * 0.85))
			for bt in b.bots:
				var row: int = bt.row
				var r: Dictionary = prows[row]
				var ry: float = r.y
				var dir: float = bt.dir
				var bx: float = bt.x
				bt.flash = maxf(0.0, float(bt.flash) - dt)
				if bt.air:                               # mid-jump
					var vy: float = float(bt.vy) + H * float(D.g) * dt
					bx += dir * speed * 1.3 * dt
					var by: float = float(bt.y) + vy * dt
					if vy > 0.0 and by >= ry - 8.0:
						if _ground_at(b, row, bx):
							by = ry - 8.0
							bt.air = false
							vy = 0.0
						elif by > H + 20.0:              # missed: respawn
							bx = W * 0.5
							by = ry - 8.0
							bt.air = false
							vy = 0.0
							var guard := 0
							while not _ground_at(b, row, bx) and guard < 200:
								bx += 6.0
								guard += 1
					bt.vy = vy
					bt.x = bx
					bt.y = by
					continue
				var fx: float = bx + dir * ahead         # the probe: ahead of the feet, pointing down
				var hit := _ground_at(b, row, fx)
				var wall := false
				if nwalls > 0:
					for wf in r.walls:
						if absf(W * float(wf) - (bx + dir * 10.0)) < 4.0:
							wall = true
				if wall:
					dir = -dir
					bt.flash = 0.4
					bt.word = "turn"
				elif not hit:
					var gw: float = _gap_width(b, row, fx, dir) if gapMax > 0.0 else 1.0e9
					if gw + ahead <= W * gapMax:         # a jump it can clear: v₀ from the time to cross
						var T: float = (gw + ahead + 8.0) / (speed * 1.3)
						bt.vy = -H * float(D.g) * T / 2.0
						bt.air = true
						bt.flash = 0.4
						bt.word = "jump"
					else:
						dir = -dir
						bt.flash = 0.4
						bt.word = "turn"
				else:
					bx += dir * speed * dt
				bt.dir = dir
				bt.x = bx
				bt.y = ry - 8.0
				bt.fx = fx
				bt.hit = hit
				bt.wall = wall
		"villager":
			var cols: int = b.cols
			var ch: float = b.ch
			var places: Dictionary = b.places
			var stagger: float = D.stagger
			var clock: float = fposmod(t * 24.0 / float(D.dayLen) + float(b.advance), 24.0)
			b.clock = clock
			var npcs: Array = b.npcs
			for i in npcs.size():
				var v: Dictionary = npcs[i]
				var want := _place_at(D, fposmod(clock - i * stagger, 24.0))
				if want != v.place:                      # the clock changed the destination: plan once
					v.place = want
					var pc: Vector2i = places[want]
					var dest: int = pc.y * cols + pc.x
					var opath: Array = v.path
					var pj: int = v.pi
					var from: int = v.cell
					if pj + 1 < opath.size():
						from = opath[pj + 1]
					var npath := _astar(b, from, dest)
					if npath.size() > 0 and int(npath[0]) != int(v.cell):
						npath.push_front(v.cell)
					v.path = npath
					v.pi = 0
					v.k = 0.0
				var pos := _cell_px(b, v.cell)
				var ang := 0.0
				var path: Array = v.path
				var pi0: int = v.pi
				if pi0 + 1 < path.size():
					var kk: float = float(v.k) + dt * float(D.speed)
					var pa := _cell_px(b, path[pi0])
					var pb := _cell_px(b, path[pi0 + 1])
					var e := _ease(minf(1.0, kk))
					pos = pa + (pb - pa) * e - Vector2(0.0, sin(minf(1.0, kk) * PI) * ch * 0.25)
					ang = atan2(pb.y - pa.y, pb.x - pa.x)
					if kk >= 1.0:
						v.cell = path[pi0 + 1]
						v.pi = pi0 + 1
						kk = 0.0
					v.k = kk
				v.dp = pos
				v.ang = ang

## The web's setLineDash: a segment drawn as short dashes (on, off in px).
static func _dash(n: CanvasItem, a: Vector2, c: Vector2, col: Color, on: float, off: float, w: float = 1.0) -> void:
	var d := a.distance_to(c)
	if d < 0.5:
		return
	var u := (c - a) / d
	var s0 := 0.0
	while s0 < d:
		var e := minf(d, s0 + on)
		n.draw_line(a + u * s0, a + u * e, col, w)
		s0 += on + off

## A dashed ring: the same, along the circumference.
static func _dash_ring(n: CanvasItem, c: Vector2, r: float, col: Color, on: float, off: float) -> void:
	if r < 1.0:
		return
	var circ := TAU * r
	var s0 := 0.0
	while s0 < circ:
		var e := minf(circ, s0 + on)
		n.draw_arc(c, r, s0 / r, e / r, 4, col, 1.0)
		s0 += on + off

## A dashed rectangle outline.
static func _dash_rect(n: CanvasItem, r: Rect2, col: Color, on: float, off: float) -> void:
	var p0 := r.position
	var p1 := r.position + Vector2(r.size.x, 0.0)
	var p2 := r.end
	var p3 := r.position + Vector2(0.0, r.size.y)
	_dash(n, p0, p1, col, on, off)
	_dash(n, p1, p2, col, on, off)
	_dash(n, p2, p3, col, on, off)
	_dash(n, p3, p0, col, on, off)

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	Kit.stage(n, b)
	var D: Dictionary = b.D
	var W: float = b.w
	var H: float = b.h
	match b.id:
		"formation":
			var lead: Dictionary = b.lead
			var lp: Vector2 = lead.p
			for sl in b.slots:
				Kit.ring(n, sl.p, 5.0, _a(Kit.TARGET, 0.45))
				Kit.line(n, lp, sl.p, _a(Kit.TARGET, 0.12))
			for f in b.fol:
				var fp: Vector2 = f.p
				var fv: Vector2 = f.v
				Kit.arrow(n, fp, fp + fv * 0.25, _a(Kit.GOOD, 0.5))
				Kit.mote(n, b, fp, atan2(fv.y, fv.x), Kit.GOOD, 6.0)
			Kit.ring(n, b.tgt, 6.0, Kit.TARGET, 1.5)
			Kit.mote(n, b, lp, lead.h, Kit.MOVER, 8.0)
			Kit.label(n, b, "%s · %d slots · redeal every %s s" % [SHAPES[b.shape], int(D.n), _num(D.reassign)], Vector2(W / 2.0, 14.0), Kit.DIM, true)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), LBL, true)
		"escort":
			var nn: int = D.n
			var lp: Vector2 = b.lp
			var lv: Vector2 = b.lv
			var c0: Vector2 = b.c
			var pred: Vector2 = b.pred
			Kit.ring(n, pred, 5.0, _a(Kit.TARGET, 0.6))   # the prediction, made visible for one wingman
			_dash(n, lp, pred, _a(Kit.TARGET, 0.45), 3.0, 4.0)
			for i in nn:
				Kit.ring(n, b.g[i], 4.0, _a(Kit.TARGET, 0.35))
				Kit.ring(n, b.s0[i], 2.5, _a(Kit.INK, 0.2))
			var fig := PackedVector2Array()              # the leader's figure, faint
			for i in 61:
				var tt: float = t - i * 0.05
				fig.append(Vector2(c0.x + sin(tt * float(D.fx) * TAU) * W * float(D.ax), c0.y + sin(tt * float(D.fy) * TAU) * H * float(D.ay)))
			n.draw_polyline(fig, _a(Kit.MOVER, 0.12), 1.0)
			for e in b.esc:
				var ev: Vector2 = e.v
				Kit.mote(n, b, e.p, atan2(ev.y, ev.x), Kit.GOOD, 6.0)
			Kit.arrow(n, lp, lp + lv * 0.3, _a(Kit.MOVER, 0.6))
			Kit.mote(n, b, lp, b.lh, Kit.MOVER, 8.0)
			Kit.label(n, b, "eta = |slot − me| ÷ maxsp · lead %s" % _num(D.lead), Vector2(W / 2.0, 14.0), Kit.DIM, true)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), LBL, true)
		"interpose":
			var vip: Dictionary = b.vip
			var thr: Dictionary = b.thr
			var me: Dictionary = b.me
			var vp: Vector2 = b.vp
			var tp: Vector2 = b.tp
			var vpos: Vector2 = vip.p
			var vv: Vector2 = vip.v
			var tpos: Vector2 = thr.p
			var tv: Vector2 = thr.v
			var mp: Vector2 = me.p
			var mv: Vector2 = me.v
			_dash(n, vp, tp, _a(Kit.TARGET, 0.4), 3.0, 4.0)   # the gap being guarded
			Kit.arrow(n, vpos, vp, _a(Kit.GOOD, 0.5))
			Kit.arrow(n, tpos, tp, _a(Kit.HOT, 0.5))
			Kit.ring(n, b.goal, 7.0, Kit.TARGET, 1.5)
			var flash: float = b.flash
			if flash > 0.0:
				Kit.ring(n, mp, 12.0 + (1.0 - flash) * 26.0, _a(Kit.TARGET, flash * 0.8), 2.0)
			Kit.mote(n, b, vpos, atan2(vv.y, vv.x), Kit.GOOD, 7.0)
			Kit.mote(n, b, tpos, atan2(tv.y, tv.x), Kit.HOT, 7.0)
			Kit.mote(n, b, mp, atan2(mv.y, mv.x), Kit.MOVER, 8.0)
			Kit.label(n, b, "aim: %s · lead %s s · blocked ×%d" % [D.aim, _num(D.lead), int(b.blocks)], Vector2(W / 2.0, 14.0), Kit.DIM, true)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), LBL, true)
		"hide":
			var me: Dictionary = b.me
			var mp: Vector2 = me.p
			var mv: Vector2 = me.v
			var hp: Vector2 = b.hp
			var best: int = b.best
			var seen: bool = b.seen
			var q: Vector2 = b.q
			for r in b.rocks:
				Kit.dot(n, r.p, r.r, _a(Kit.BONE, 0.12))
				Kit.ring(n, r.p, r.r, _a(Kit.BONE, 0.5))
			var count: int = (b.spots as Array).size()
			for i in count:
				var spot: Vector2 = b.spots[i]
				_dash(n, hp, spot, _a(Kit.INK, 0.1), 2.0, 3.0)
				if i == best:
					Kit.ring(n, spot, 7.0, Kit.TARGET, 1.5)
				else:
					Kit.ring(n, spot, 4.0, _a(Kit.TARGET, 0.35), 1.0)
			if seen:
				Kit.line(n, hp, mp, _a(Kit.HOT, 0.7), 1.5)
			else:
				Kit.line(n, hp, q, _a(Kit.GOOD, 0.7), 1.5)
				_dash(n, q, mp, _a(Kit.GOOD, 0.3), 2.0, 4.0)
				Kit.dot(n, q, 3.0, Kit.GOOD)
			Kit.mote(n, b, hp, atan2(mp.y - hp.y, mp.x - hp.x), Kit.HOT, 7.0)
			Kit.mote(n, b, mp, atan2(mv.y, mv.x), Kit.MOVER, 8.0)
			Kit.label(n, b, "seen" if seen else "hidden", Vector2(mp.x, mp.y - 14.0), Kit.HOT if seen else Kit.GOOD, true)
			Kit.label(n, b, "hidden %.1f s" % float(b.hidden), Vector2(W / 2.0, 14.0), Kit.DIM, true)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), LBL, true)
		"hug":
			var me: Dictionary = b.me
			var mp: Vector2 = me.p
			var mv: Vector2 = me.v
			var GAP: float = b.GAP
			var bowl: bool = D.room == "bowl"
			var hug: bool = D.mode == "hug"
			var bc: Vector2 = b.bc
			var BR: float = b.BR
			var bx0: float = b.bx0
			var by0: float = b.by0
			var bx1: float = b.bx1
			var by1: float = b.by1
			if bowl:
				Kit.ring(n, bc, BR, Kit.BONE, 1.5)
			else:
				n.draw_rect(Rect2(bx0, by0, bx1 - bx0, by1 - by0), Kit.BONE, false, 1.5)
			if hug:                                      # the gap band, faint
				if bowl:
					_dash_ring(n, bc, BR - GAP, _a(Kit.TARGET, 0.3), 2.0, 4.0)
				else:
					_dash_rect(n, Rect2(bx0 + GAP, by0 + GAP, bx1 - bx0 - 2.0 * GAP, by1 - by0 - 2.0 * GAP), _a(Kit.TARGET, 0.3), 2.0, 4.0)
				var side: Vector2 = b.side
				var sideHit: bool = b.sideHit
				Kit.line(n, mp, side, Kit.TARGET if sideHit else Kit.DIM, 1.5 if sideHit else 1.0)
				Kit.dot(n, side, 2.5, Kit.TARGET if sideHit else Kit.DIM)
			var reflectT: float = b.reflectT
			Kit.line(n, mp, b.nose, Kit.HOT if reflectT > 0.0 else Kit.DIM, 1.5 if reflectT > 0.0 else 1.0)
			if reflectT > 0.0:
				var rp: Vector2 = b.rp
				var rn: Vector2 = b.rn
				Kit.arrow(n, rp, rp + rn * 22.0, Kit.HOT)
				Kit.label(n, b, "reflect", rp + rn * 26.0 + Vector2(0.0, 4.0), Kit.HOT, true)
			Kit.mote(n, b, mp, atan2(mv.y, mv.x))
			Kit.label(n, b, "%s · %s · gap %d px" % [D.mode, D.room, roundi(GAP)], Vector2(W / 2.0, 14.0), Kit.DIM, true)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), LBL, true)
		"judge":
			var nn: int = D.dirs
			var RANGE: float = b.RANGE
			var p: Vector2 = b.p
			var goal: Vector2 = b.goal
			var best: int = b.best
			var M := minf(W, H)
			for r in b.rocks:
				Kit.dot(n, r.p, r.r, _a(Kit.BONE, 0.12))
				Kit.ring(n, r.p, r.r, _a(Kit.BONE, 0.5))
				Kit.ring(n, r.p, float(r.r) + RANGE, _a(Kit.HOT, 0.08))
			var R0 := 12.0
			var RS: float = M * 0.11                     # the spokes: interest out, danger over it
			for i in nn:
				var dv: Vector2 = b.dirv[i]
				var it: float = b.interest[i]
				var dg: float = b.danger[i]
				Kit.line(n, p + dv * R0, p + dv * (R0 + it * RS), _a(Kit.GOOD, 0.6), 2.0)
				if dg > 0.01:
					Kit.line(n, p + dv * R0, p + dv * (R0 + dg * RS), _a(Kit.HOT, 0.75), 3.0)
			Kit.ring(n, p, R0, Kit.DIM)
			var bv: Vector2 = b.dirv[best]
			Kit.line(n, p, p + bv * (R0 + RS * 1.05), Kit.TARGET, 1.5)   # the winner
			Kit.ring(n, goal, 7.0, Kit.TARGET, 1.5)
			Kit.dot(n, goal, 2.5, Kit.TARGET)
			Kit.mote(n, b, p, b.hd)
			Kit.label(n, b, "%d directions · blend %s/s" % [nn, _num(D.smoothRate)], Vector2(W / 2.0, 14.0), Kit.DIM, true)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), LBL, true)
		"flowfield":
			var cw: float = b.cw
			var ch: float = b.ch
			_draw_dist_grid(n, b, Kit.TARGET, false)     # the field: a heat of distance, and the number
			var goal: int = b.goals[0]
			Kit.ring(n, _cell_px(b, goal), minf(cw, ch) * 0.4, Kit.TARGET, 1.5)
			for un in b.units:
				var up: Vector2 = un.p
				var ud: Vector2 = un.dir
				var sp := Vector2(up.x * cw, up.y * ch)
				if ud != Vector2.ZERO:
					Kit.line(n, sp, sp + Vector2(ud.x * cw * 0.4, ud.y * ch * 0.4), _a(Kit.MOVER, 0.45))
				Kit.dot(n, sp, maxf(2.0, minf(cw, ch) * 0.2), Kit.MOVER)
			_text(n, "%d units · one field · max %d" % [int(D.units), int(b.maxd)], Vector2(W - 4.0, 11.0), Kit.DIM, 10, 2)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 6.0), LBL, true)
		"dijkstra":
			var cw: float = b.cw
			var ch: float = b.ch
			var flee: bool = D.mode == "flee"
			_draw_dist_grid(n, b, Kit.GOOD if flee else Kit.TARGET, flee)   # uphill glows green, downhill amber
			var goals: Array = b.goals
			for g in goals:
				var gp := _cell_px(b, g)
				Kit.ring(n, gp, minf(cw, ch) * 0.4, Kit.TARGET, 1.5)
				Kit.dot(n, gp, 3.0, Kit.TARGET)
			for m in b.mons:
				var mp: Vector2 = m.p
				var md: Vector2 = m.dir
				var dd: float = m.d
				var sp := Vector2(mp.x * cw, mp.y * ch)
				if dd > 0.05:
					Kit.line(n, sp, sp + Vector2(md.x * cw * 0.45, md.y * ch * 0.45), _a(Kit.HOT, 0.5))
				else:
					Kit.label(n, b, "stuck", Vector2(sp.x, sp.y - 8.0), _a(Kit.HOT, 0.6), true)   # a local peak: nowhere higher to go
				Kit.mote(n, b, sp, atan2(md.y, md.x), Kit.HOT, maxf(3.0, minf(cw, ch) * 0.24))
			_text(n, "%s · %d goal%s · one flood" % [D.mode, goals.size(), "s" if goals.size() > 1 else ""], Vector2(W - 4.0, 11.0), Kit.DIM, 10, 2)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 6.0), LBL, true)
		"influence":
			var cols: int = b.cols
			var rows: int = b.rows
			var N: int = b.N
			var cw: float = b.cw
			var ch: float = b.ch
			var grid: Array = b.map
			var peak: float = maxf(1.0, float(b.peak))
			for i in N:                                  # the heat map
				var v: float = grid[i]
				if v <= 0.001:
					continue
				n.draw_rect(Rect2((i % cols) * cw + 0.5, _row(i, cols) * ch + 0.5, cw - 1.0, ch - 1.0), _a(Kit.HOT, 0.55 * minf(1.0, v / peak)))
			var cxi: int = b.cxi
			var cyi: int = b.cyi
			var choice: int = b.choice
			for dy in range(-1, 2):                      # the cells being read
				for dx in range(-1, 2):
					var nx: int = cxi + dx
					var ny: int = cyi + dy
					if nx < 0 or ny < 0 or nx >= cols or ny >= rows:
						continue
					var sel: bool = ny * cols + nx == choice
					n.draw_rect(Rect2(nx * cw + 1.0, ny * ch + 1.0, cw - 2.0, ch - 2.0), Kit.TARGET if sel else _a(Kit.INK, 0.25), false, 1.5 if sel else 1.0)
			var R: float = b.R
			for th in b.thr:
				Kit.ring(n, th.p, R, _a(Kit.HOT, 0.12))
				Kit.mote(n, b, th.p, th.a, Kit.HOT, 5.0)
			var me: Dictionary = b.me
			var mp: Vector2 = me.p
			var here: float = b.here
			var bold: float = D.bold
			var spx := Vector2(mp.x * cw, mp.y * ch)
			Kit.mote(n, b, spx, b.mang, Kit.TARGET if bold > 0.5 else Kit.MOVER, 7.0)
			Kit.label(n, b, "here %.2f" % here, Vector2(spx.x, spx.y - 12.0), Kit.HOT if here > 0.05 else Kit.GOOD, true)
			_text(n, "bold %s · %d threats · R %d px" % [_num(bold), (b.thr as Array).size(), roundi(R)], Vector2(W - 4.0, 11.0), Kit.DIM, 10, 2)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 6.0), LBL, true)
		"nodes":
			var posts: Array = b.posts
			var p0: Vector2 = posts[0]
			var p1: Vector2 = posts[1]
			var p: Vector2 = b.p
			var pp: Vector2 = b.pp
			var active: String = b.active
			var status: Dictionary = b.status
			var flash: float = b.flash
			# the scene, left
			_dash(n, p0, p1, _a(Kit.BONE, 0.3), 3.0, 5.0)
			for ps in posts:
				Kit.ring(n, ps, 4.0, _a(Kit.BONE, 0.5))
			Kit.line(n, Vector2(W * 0.6, 8.0), Vector2(W * 0.6, H - 20.0), _a(Kit.BONE, 0.15))
			Kit.ring(n, p, W * float(D.sense), _a(Kit.TARGET, 0.35 if active == "chase" else 0.12))
			Kit.ring(n, p, W * float(D.panic), _a(Kit.HOT, 0.45 if active == "flee" else 0.12))
			if flash > 0.0:
				Kit.ring(n, p, 14.0 + (1.0 - flash) * 26.0, _a(Kit.HOT, flash * 0.8), 2.0)
			Kit.ring(n, pp, 8.0, _a(Kit.TARGET, 0.5))
			Kit.dot(n, pp, 4.0, Kit.TARGET)
			Kit.mote(n, b, p, b.hd)
			var acol := Kit.GOOD
			if active == "chase":
				acol = Kit.HOT
			elif active == "flee":
				acol = Kit.MAGIC
			Kit.label(n, b, active, Vector2(p.x, p.y - 15.0), acol, true)
			# the tree, right
			var tx0: float = W * 0.62
			var tw: float = W * 0.36
			var ty0: float = H * 0.12
			var rowH: float = (H - 40.0) * 0.3
			var rx: float = tx0 + tw / 2.0
			var ry: float = ty0
			var order: Array = D.order
			var cnt: int = order.size()
			for i in cnt:
				var bname: String = order[i]
				var bx: float = tx0 + tw * (i + 0.5) / cnt
				var by: float = ry + rowH
				var st: int = status.get(bname, 0)
				Kit.line(n, Vector2(rx, ry + 6.0), Vector2(bx, by - 6.0), _nodes_col(st) if st != 0 else _a(Kit.BONE, 0.25), 1.5 if st != 0 else 1.0)
				var kids: Array = BRANCHES.get(bname, BRANCHES.patrol)
				for k in kids.size():
					var ly: float = by + rowH * 0.62 * (k + 1)
					var ls: int = status.get(bname + "/" + str(kids[k]), 0)
					Kit.line(n, Vector2(bx, by + 6.0), Vector2(bx, ly - 6.0), _nodes_col(ls) if ls != 0 else _a(Kit.BONE, 0.25), 1.5 if ls != 0 else 1.0)
					_nodes_box(n, Vector2(bx, ly), kids[k], ls, minf(tw / cnt - 2.0, 40.0))
				_nodes_box(n, Vector2(bx, by), "→", st, 22.0)
			_nodes_box(n, Vector2(rx, ry), "?", status.get("root", 0), 22.0)
			Kit.label(n, b, "S", Vector2(tx0, H - 26.0), Kit.GOOD)
			Kit.label(n, b, "F", Vector2(tx0 + 14.0, H - 26.0), Kit.HOT)
			Kit.label(n, b, "R", Vector2(tx0 + 28.0, H - 26.0), Kit.TARGET)
			_text(n, "tagged ×%d" % int(b.caught), Vector2(tx0 + tw, H - 26.0), Kit.DIM, 10, 2)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), LBL, true)
		"utility":
			var need: Array = b.need
			var wts: Array = D.w
			var ks: Array = D.k
			var score: Array = b.score
			var act: int = b.act
			var close: float = b.close
			var me: Dictionary = b.me
			var mp: Vector2 = me.p
			var pp: Vector2 = b.pp
			# the graphs: one per action, curve y = x^k and the current need on it, the score bar under
			var gw: float = minf(46.0, W / 4.0 - 8.0)
			var gh: float = gw * 0.55
			var gy0 := 16.0
			for i in 4:
				var gx0: float = W / 4.0 * (i + 0.5) - gw / 2.0
				var on: bool = float(wts[i]) > 0.0
				var kk: float = ks[i]
				var ccol: Color = UCOLS[i]
				n.draw_rect(Rect2(gx0, gy0, gw, gh), ccol if act == i else _a(Kit.BONE, 0.3), false, 1.5 if act == i else 1.0)
				var curve := PackedVector2Array()
				for sidx in 13:
					var xx: float = sidx / 12.0
					var yy: float = pow(xx, kk)
					curve.append(Vector2(gx0 + xx * gw, gy0 + gh - yy * gh))
				n.draw_polyline(curve, ccol if on else _a(Kit.BONE, 0.2), 1.0)
				var nx: float = float(need[i]) if i < 3 else 0.4 + 0.6 * close
				var ny: float = pow(nx, kk)
				Kit.dot(n, Vector2(gx0 + nx * gw, gy0 + gh - ny * gh), 2.5, ccol if on else Kit.DIM)
				Kit.rect(n, Rect2(gx0, gy0 + gh + 3.0, gw * clampf(float(score[i]), 0.0, 1.0), 3.0), ccol if on else _a(Kit.BONE, 0.2))
				Kit.label(n, b, "%s k%s" % [UNAMES[i], _num(kk)], Vector2(gx0 + gw / 2.0, gy0 + gh + 16.0), ccol if act == i else Kit.DIM, true)
			for i in 3:
				var spt: Vector2 = b.spots[i]
				var ccol: Color = UCOLS[i]
				Kit.ring(n, spt, 9.0, ccol, 2.0 if act == i else 1.0)
				Kit.label(n, b, (UNAMES[i] as String).substr(0, 1), Vector2(spt.x, spt.y + 3.5), ccol, true)
			var hunt: bool = float(wts[3]) > 0.0
			Kit.ring(n, pp, 7.0, Kit.HOT if hunt else _a(Kit.HOT, 0.35))
			Kit.dot(n, pp, 3.0, Kit.HOT if hunt else Kit.DIM)
			Kit.mote(n, b, mp, me.h, Kit.GOOD if hunt and float(wts[0]) == 0.0 else Kit.MOVER)   # a hunter with no appetite: zombie green
			Kit.label(n, b, UNAMES[act], Vector2(mp.x, mp.y - 14.0), UCOLS[act], true)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), LBL, true)
		"edge":
			var prows: Array = b.prows
			var nwalls: int = D.walls
			var probe: float = D.probe
			for r in prows:                              # the platforms, as what is left after the gaps
				var ry: float = r.y
				var segs: Array = [[W * 0.04, W * 0.96]]
				for g in r.gaps:
					var out: Array = []
					for sg in segs:
						if float(g[1]) <= float(sg[0]) or float(g[0]) >= float(sg[1]):
							out.append(sg)
						else:
							if float(g[0]) > float(sg[0]):
								out.append([sg[0], g[0]])
							if float(g[1]) < float(sg[1]):
								out.append([g[1], sg[1]])
					segs = out
				for sg in segs:
					var x0: float = sg[0]
					var x1: float = sg[1]
					Kit.line(n, Vector2(x0, ry), Vector2(x1, ry), _a(Kit.BONE, 0.6), 2.0)
					var xx: float = x0 + 4.0
					while xx < x1:
						Kit.line(n, Vector2(xx, ry + 2.0), Vector2(xx - 4.0, ry + 7.0), _a(Kit.BONE, 0.16))
						xx += 10.0
				for wf in r.walls:
					Kit.rect(n, Rect2(W * float(wf) - 2.0, ry - 14.0, 4.0, 14.0), Kit.BONE)
			for bt in b.bots:
				var bx: float = bt.x
				var by: float = bt.y
				var dir: float = bt.dir
				if bt.air:                               # mid-jump
					Kit.mote(n, b, Vector2(bx, by), -0.5 if dir > 0.0 else PI + 0.5, Kit.MOVER, 7.0)
					continue
				var r: Dictionary = prows[bt.row]
				var ry: float = r.y
				var fx: float = bt.fx
				var hit: bool = bt.hit
				var wall: bool = bt.wall
				Kit.line(n, Vector2(fx, ry - 8.0), Vector2(fx, ry - 8.0 + probe), Kit.GOOD if hit else Kit.HOT, 1.5)   # the ray
				Kit.dot(n, Vector2(fx, ry if hit else ry - 8.0 + probe), 2.5, Kit.GOOD if hit else Kit.HOT)
				if nwalls > 0:
					Kit.line(n, Vector2(bx, ry - 10.0), Vector2(bx + dir * 10.0, ry - 10.0), Kit.HOT if wall else Kit.DIM)
				if float(bt.flash) > 0.0:
					var jump: bool = bt.word == "jump"
					Kit.label(n, b, bt.word, Vector2(bx, by - 14.0), Kit.TARGET if jump else Kit.HOT, true)
				Kit.mote(n, b, Vector2(bx, by), 0.0 if dir > 0.0 else PI, Kit.MOVER, 7.0)
			var gapMax: float = D.gapMax
			var head := ""
			if gapMax > 0.0:
				head += "jumps gaps ≤ %d px · " % roundi(W * gapMax)
			if nwalls > 0:
				head += "walls read · "
			Kit.label(n, b, head + "probe %s px" % _num(probe), Vector2(W / 2.0, 14.0), Kit.DIM, true)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), LBL, true)
		"villager":
			var cols: int = b.cols
			var N: int = b.N
			var cw: float = b.cw
			var ch: float = b.ch
			var places: Dictionary = b.places
			var clock: float = b.clock
			var npcs: Array = b.npcs
			for i in N:
				if b.walls[i]:
					Kit.rect(n, Rect2((i % cols) * cw + 1.0, _row(i, cols) * ch + 1.0, cw - 2.0, ch - 2.0), _a(Kit.BONE, 0.3))
			for k in places:
				var pc: Vector2i = places[k]
				var pos := Vector2((pc.x + 0.5) * cw, (pc.y + 0.5) * ch)
				var pcol: Color = PLACE_COL[k]
				Kit.ring(n, pos, minf(cw, ch) * 0.42, pcol, 1.5)
				Kit.label(n, b, (k as String).substr(0, 1).to_upper(), Vector2(pos.x, pos.y + 3.5), pcol, true)
			for v in npcs:
				var path: Array = v.path
				var pi0: int = v.pi
				for j in range(pi0, path.size() - 1):    # the rest of the route, faint
					Kit.line(n, _cell_px(b, path[j]), _cell_px(b, path[j + 1]), _a(Kit.TARGET, 0.3))
				Kit.mote(n, b, v.dp, v.ang, v.col, maxf(3.5, minf(cw, ch) * 0.26))
			var night: float = clampf((absf(clock - 12.0) - 5.0) / 3.0, 0.0, 1.0)   # 0 by day, 1 by night
			if D.invert:
				night = 1.0 - night
			Kit.rect(n, Rect2(0.0, 0.0, W, H - 18.0), Color(0.047, 0.039, 0.188, 0.5 * night))   # the tint is the hour
			var ck := Vector2(W - 20.0, 20.0)            # the clock dial: one turn = 24 h
			var rk := 12.0
			Kit.ring(n, ck, rk, Kit.BONE, 1.5)
			var ha: float = clock / 24.0 * TAU - PI / 2.0
			Kit.line(n, ck, ck + Vector2(cos(ha), sin(ha)) * rk * 0.8, Kit.TARGET, 2.0)
			var hh: int = floori(clock)
			var mm: int = floori((clock - hh) * 60.0)
			var first: Dictionary = npcs[0]
			_text(n, "%02d:%02d → %s" % [hh, mm, first.place], Vector2(ck.x - rk - 4.0, ck.y + 4.0), LBL, 10, 2)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 6.0), LBL, true)
