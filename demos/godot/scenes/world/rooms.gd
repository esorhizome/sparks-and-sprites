extends RefCounted

const Kit := preload("res://scenes/world/kit.gd")
## ROOMS, CAVES & MAZES — five generators, ported from the web workshop
## (docs/worlds.js, family rooms). Places from grids. A grid is the cheapest
## world there is — a row of numbers per row of tiles — and every generator
## here is one rule run over it: ask the neighbours, halve the rectangle,
## carve to the next cell, keep only the tiles the rules still allow, sum
## the neighbours into an index. Five cards: Caves, Bsp, Maze, Wfc,
## Autotile. All seeded.
##
## Randomness: every card seeds Kit.rng(D.seed), exactly like the web's
## rng(seed). Godot's RandomNumberGenerator is not mulberry32, so the
## NUMBERS differ from the web page — but the RULE is the same: one seed,
## one world, on every machine that runs this file.

const TITLE := "Rooms, caves & mazes"
const BLURB := "places from grids — caves grown by a neighbour rule, rooms carved by halving, mazes with two personalities, tiles chosen by constraint, tiles picked by a bitmask"
const DEFS := [
	{ "id": "caves", "letter": "C", "name": "Caves",
		"hint": "random fill, then \"a cell is rock if 5+ of its 8 neighbours are rock\", four times — press to regrow",
		"dials": { "cols": 48, "rows": 30,   # the grid
			"fill": 0.45,                    # the chance a cell starts as rock
			"rule": 5,                       # rock if this many neighbours (of 8) are rock
			"passes": 4,                     # smoothing passes, animated one per beat
			"beat": 0.55,                    # seconds per pass
			"rest": 2.4,                     # seconds to rest in the finished cave
			"seed": 7,
			"label": "rock if neighbours ≥ rule · open if ≤ rule − 2 · then keep the largest region" },
		"rhyme": { "name": "Catacombs", "hint": "a denser fill and fewer passes, so the rock never rounds off — narrow winding tunnels instead of caverns",
			"dials": { "fill": 0.52, "passes": 2 } } },
	{ "id": "bsp", "letter": "B", "name": "Bsp",
		"hint": "halve the map, halve the halves; a room in every leaf; siblings joined by a corridor, bottom up — press to resplit",
		"dials": { "cols": 48, "rows": 30,   # the map
			"depth": 4,                      # how many times a half is halved again
			"minLeaf": 7,                    # a leaf is never narrower than this
			"roomMin": 3, "roomMax": 12,     # room sides, in cells (also capped by the leaf)
			"corridor": "bent",              # "bent": an L between any two rooms · "straight": the pair that lines up
			"beat": 0.3,                     # seconds per split
			"rest": 2.6,
			"seed": 3,
			"label": "split 35–65 % · room per leaf · join siblings" },
		"rhyme": { "name": "Bunker", "hint": "one more level of cuts, tiny rooms and straight corridors — a bunker's cell block",
			"dials": { "depth": 5, "minLeaf": 5, "roomMax": 4, "corridor": "straight" } } },
	{ "id": "maze", "letter": "M", "name": "Maze",
		"hint": "one grid, two carvers — the backtracker digs long winding halls, prim's picks any frontier cell and branches — press to carve again",
		"dials": { "cols": 24, "rows": 15,   # cells (each keeps four wall bits)
			"algo": "backtracker",           # "backtracker" or "prim"
			"perBeat": 2, "beat": 0.03,      # cells carved per beat
			"rest": 2.6,
			"seed": 5,
			"label": "backtracker: go deep, back up · prim: any frontier cell" },
		"rhyme": { "name": "Meander", "hint": "prim's carver on a bigger grid — short branchy halls and a swarm of dead ends",
			"dials": { "algo": "prim", "cols": 32, "rows": 20 } } },
	{ "id": "wfc", "letter": "W", "name": "Wfc",
		"hint": "each cell holds every tile it could still be; collapse the least undecided one, propagate the rules, repeat — press to collapse from your click",
		"dials": { "cols": 32, "rows": 20,
			"tiles": ["water", "sand", "grass"],
			"colours": ["#3A6FB5", "#E2C98A", "#6FAF5E"],
			"weights": [2, 2, 3],                                    # how much each tile wants to be picked
			"rules": [[0, 0], [0, 1], [1, 1], [1, 2], [2, 2]],       # the pairs that may touch
			"perBeat": 4, "beat": 0.03,                              # cells collapsed per beat
			"rest": 2.6,
			"seed": 4,
			"label": "lowest entropy first · propagate · contradiction → restart" },
		"rhyme": { "name": "Wetlands", "hint": "a rule set that lets grass meet water and keeps sand rare — lakes with reeds instead of beaches",
			"dials": { "weights": [5, 1, 2], "rules": [[0, 0], [0, 1], [1, 1], [0, 2], [2, 2]] } } },
	{ "id": "autotile", "letter": "A", "name": "Autotile", "drag": true,
		"hint": "sum the wall neighbours into a bitmask (n1 e2 s4 w8); that index picks the tile, so edges and corners resolve themselves — drag to paint walls",
		"dials": { "cols": 24, "rows": 15,
			"bits": 4,                       # 4: edges only (16 tiles) · 8: corners too (47 tiles)
			"fill": 0.46,                    # the seeded layout: chance a cell starts as wall
			"smooth": 1,                     # neighbour-rule passes that round the layout off
			"perBeat": 5, "beat": 0.03,      # tiles laid per beat while the layout grows
			"rest": 3,
			"hold": 5,                       # seconds a painted map is kept before the next seed
			"palette": "wall",               # "wall" or "island"
			"palettes": { "wall": ["#1A1532", "#8E88AC", "#E8E5F4", "#3E3960"], "island": ["#2E5F9E", "#D9C48C", "#F7F1E0", "#A8925C"] },   # floor, tile, rim, inner corner
			"seed": 6,
			"label": "index = n·1 + e·2 + s·4 + w·8 → tile" },
		"rhyme": { "name": "Archipelago", "hint": "eight bits, so the corners join in, and an island palette — sand meets sea and the beaches draw their own bends",
			"dials": { "bits": 8, "palette": "island", "smooth": 2 } } },
]

const DEFAULT_TXT := Color(0.91, 0.898, 0.957, 0.55)


# ── shared helpers ────────────────────────────────────────────────────────

## The web kit's label(txt, x, y, col, align): 10 px text, left / right / center.
static func _txt(n: CanvasItem, txt: String, x: float, y: float,
		col: Color = DEFAULT_TXT, align: String = "left", size: int = 10) -> void:
	var f := ThemeDB.fallback_font
	var xx := x
	if align != "left":
		var w := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		xx -= w if align == "right" else w / 2.0
	n.draw_string(f, Vector2(xx, y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

## The web's floor(r() * count): an index in 0..count-1 from the seeded stream.
static func _pick(r: RandomNumberGenerator, count: int) -> int:
	return r.randi_range(0, count - 1) if count > 0 else 0

static func _bytes(count: int) -> PackedByteArray:
	var a := PackedByteArray()
	a.resize(count)
	return a

static func _ints(count: int) -> PackedInt32Array:
	var a := PackedInt32Array()
	a.resize(count)
	return a


# ── Caves ────────────────────────────────────────────────────────────────

static func _caves_count(b: Dictionary, x: int, y: int) -> int:
	var g: Dictionary = b.g
	var cnt := 0
	for j in range(-1, 2):
		for i in range(-1, 2):
			if (i != 0 or j != 0) and Kit.cell_get(g, x + i, y + j) == 1.0:
				cnt += 1
	return cnt

## A cell to watch: one sitting right on the rule's edge.
static func _caves_watch(b: Dictionary) -> void:
	var D: Dictionary = b.D
	var r: RandomNumberGenerator = b.r
	var cols: int = D.cols
	var rows: int = D.rows
	var rule: int = D.rule
	b.hx = 1 + _pick(r, cols - 2)
	b.hy = 1 + _pick(r, rows - 2)
	for _tries in 40:
		var x := 1 + _pick(r, cols - 2)
		var y := 1 + _pick(r, rows - 2)
		var cnt := _caves_count(b, x, y)
		if cnt >= rule - 2 and cnt <= rule:
			b.hx = x
			b.hy = y
			break
	b.hn = _caves_count(b, b.hx, b.hy)

static func _caves_regrow(b: Dictionary) -> void:
	var D: Dictionary = b.D
	var r := Kit.rng(b.seed)
	b.r = r
	b.pass_n = 0
	b.acc = 0.0
	b.restT = 0.0
	b.kept = 0
	b.dropped = 0
	b.homeX = -1
	b.homeY = -1
	var a: PackedFloat32Array = (b.g as Dictionary).a
	var fill: float = D.fill
	for i in int(b.N):
		a[i] = 1.0 if r.randf() < fill else 0.0
	_caves_watch(b)

## rock · open · unchanged
static func _caves_verdict(b: Dictionary, x: int, y: int, cnt: int) -> float:
	var rule: int = (b.D as Dictionary).rule
	if cnt >= rule:
		return 1.0
	if cnt <= rule - 2:
		return 0.0
	return Kit.cell_get(b.g, x, y)

## Every cell asks its eight neighbours at once.
static func _caves_smooth(b: Dictionary) -> void:
	var D: Dictionary = b.D
	var cols: int = D.cols
	var rows: int = D.rows
	var a2: PackedFloat32Array = (b.g2 as Dictionary).a
	for y in rows:
		for x in cols:
			a2[y * cols + x] = _caves_verdict(b, x, y, _caves_count(b, x, y))
	var tmp: Dictionary = b.g
	b.g = b.g2
	b.g2 = tmp
	_caves_watch(b)

static func _caves_visit(a: PackedFloat32Array, lab: PackedInt32Array, stack: PackedInt32Array, sp: int, c: int, id: int) -> int:
	if a[c] == 0.0 and lab[c] == 0:
		lab[c] = id
		stack[sp] = c
		return sp + 1
	return sp

static func _caves_keep_largest(b: Dictionary) -> void:
	var D: Dictionary = b.D
	var cols: int = D.cols
	var rows: int = D.rows
	var N: int = b.N
	var a: PackedFloat32Array = (b.g as Dictionary).a
	var lab: PackedInt32Array = b.lab
	var stack: PackedInt32Array = b.stack
	var r: RandomNumberGenerator = b.r
	lab.fill(0)
	var best := 0
	var bestSize := 0
	var id := 0
	for s0 in N:
		if a[s0] != 0.0 or lab[s0] != 0:
			continue
		id += 1
		var sp := 0
		stack[sp] = s0
		sp += 1
		lab[s0] = id
		var size := 0
		while sp > 0:
			sp -= 1
			var c := stack[sp]
			var x := c % cols
			var y := (c - x) / cols
			size += 1
			if x > 0:
				sp = _caves_visit(a, lab, stack, sp, c - 1, id)
			if x < cols - 1:
				sp = _caves_visit(a, lab, stack, sp, c + 1, id)
			if y > 0:
				sp = _caves_visit(a, lab, stack, sp, c - cols, id)
			if y < rows - 1:
				sp = _caves_visit(a, lab, stack, sp, c + cols, id)
		if size > bestSize:
			bestSize = size
			best = id
	b.kept = bestSize
	var dropped := 0
	for i in N:
		if a[i] == 0.0 and lab[i] != best:                       # doomed: the small pockets
			a[i] = 2.0
			dropped += 1
	b.dropped = dropped
	for _tries in 60:                                           # somewhere in the kept region to stand
		if int(b.homeX) >= 0:
			break
		var c := _pick(r, N)
		if a[c] == 0.0:
			b.homeX = c % cols
			b.homeY = (c - int(b.homeX)) / cols
	if int(b.homeX) < 0:
		for c in N:
			if a[c] == 0.0:
				b.homeX = c % cols
				b.homeY = (c - int(b.homeX)) / cols
				break

static func _caves_seal(b: Dictionary) -> void:
	var a: PackedFloat32Array = (b.g as Dictionary).a
	for i in int(b.N):
		if a[i] == 2.0:
			a[i] = 1.0


# ── Bsp ──────────────────────────────────────────────────────────────────

static func _bsp_node(x: int, y: int, w: int, h: int, d: int) -> Dictionary:
	return { "x": x, "y": y, "w": w, "h": h, "d": d, "a": -1, "b": -1, "room": {}, "split": {}, "rooms": [], "tx": 0.0, "fired": false }

static func _bsp_build(b: Dictionary) -> void:
	var D: Dictionary = b.D
	var r := Kit.rng(b.seed)
	b.r = r
	var ga: PackedFloat32Array = (b.g as Dictionary).a
	ga.fill(0.0)
	var events: Array = []
	b.events = events
	b.ev = 0
	b.acc = 0.0
	b.restT = 0.0
	b.curSplit = -1
	var depth: int = D.depth
	var minLeaf: int = D.minLeaf
	var nodes: Array = [_bsp_node(0, 0, int(D.cols), int(D.rows), 0)]
	b.nodes = nodes
	var queue: Array = [0]
	while not queue.is_empty():                                 # breadth first, so the splits animate coarse to fine
		var ni: int = queue.pop_front()
		var nd: Dictionary = nodes[ni]
		if int(nd.d) >= depth:
			continue
		var nw: int = nd.w
		var nh: int = nd.h
		var canV := nw >= 2 * minLeaf
		var canH := nh >= 2 * minLeaf
		if not canV and not canH:
			continue
		var vert: bool
		if canV and canH:
			if nw / float(nh) > 1.25:
				vert = true
			elif nh / float(nw) > 1.25:
				vert = false
			else:
				vert = r.randf() < 0.5
		else:
			vert = canV
		var span := nw if vert else nh
		var lo := maxi(minLeaf, int(floorf(span * 0.35)))
		var hi := mini(span - minLeaf, ceili(span * 0.65))
		var at := lo + _pick(r, maxi(1, hi - lo + 1))
		nd.split = { "vert": vert, "at": at }
		var na := _bsp_node(nd.x, nd.y, at, nh, int(nd.d) + 1) if vert else _bsp_node(nd.x, nd.y, nw, at, int(nd.d) + 1)
		var nb := _bsp_node(int(nd.x) + at, nd.y, nw - at, nh, int(nd.d) + 1) if vert else _bsp_node(nd.x, int(nd.y) + at, nw, nh - at, int(nd.d) + 1)
		nd.a = nodes.size()
		nodes.append(na)
		nd.b = nodes.size()
		nodes.append(nb)
		queue.append(nd.a)
		queue.append(nd.b)
		events.append({ "kind": "split", "node": ni })
	b.leaves = 0
	b.slot = 0
	_bsp_place(b, 0)
	events.append({ "kind": "rooms" })
	for d in range(depth - 1, -1, -1):                          # corridors: deepest siblings first
		var level: Array = []
		for ni in nodes.size():
			var nd: Dictionary = nodes[ni]
			if int(nd.a) >= 0 and int(nd.d) == d:
				level.append(ni)
		if not level.is_empty():
			events.append({ "kind": "join", "nodes": level })

## Rooms in the leaves, and a column for the tree drawing.
static func _bsp_place(b: Dictionary, ni: int) -> void:
	var D: Dictionary = b.D
	var r: RandomNumberGenerator = b.r
	var nodes: Array = b.nodes
	var nd: Dictionary = nodes[ni]
	if int(nd.a) < 0:
		var roomMin: int = D.roomMin
		var roomMax: int = D.roomMax
		var hi := maxi(1, mini(roomMax, int(nd.w) - 2))
		var hj := maxi(1, mini(roomMax, int(nd.h) - 2))
		var rw := mini(hi, roomMin + _pick(r, maxi(1, hi - roomMin + 1)))
		var rh := mini(hj, roomMin + _pick(r, maxi(1, hj - roomMin + 1)))
		var rx := int(nd.x) + 1 + _pick(r, maxi(1, int(nd.w) - 1 - rw))
		var ry := int(nd.y) + 1 + _pick(r, maxi(1, int(nd.h) - 1 - rh))
		nd.room = { "x": rx, "y": ry, "w": rw, "h": rh }
		nd.rooms = [nd.room]
		nd.tx = float(b.slot)
		b.slot += 1
		b.leaves += 1
		return
	_bsp_place(b, nd.a)
	_bsp_place(b, nd.b)
	var na: Dictionary = nodes[nd.a]
	var nb: Dictionary = nodes[nd.b]
	nd.rooms = (na.rooms as Array) + (nb.rooms as Array)
	nd.tx = (float(na.tx) + float(nb.tx)) / 2.0

static func _bsp_carve_room(g: Dictionary, m: Dictionary) -> void:
	for y in range(int(m.y), int(m.y) + int(m.h)):
		for x in range(int(m.x), int(m.x) + int(m.w)):
			Kit.cell_set(g, x, y, 1.0)

static func _bsp_carve_h(g: Dictionary, x1: int, x2: int, y: int) -> void:
	for x in range(mini(x1, x2), maxi(x1, x2) + 1):
		if Kit.cell_get(g, x, y) == 0.0:
			Kit.cell_set(g, x, y, 2.0)

static func _bsp_carve_v(g: Dictionary, y1: int, y2: int, x: int) -> void:
	for y in range(mini(y1, y2), maxi(y1, y2) + 1):
		if Kit.cell_get(g, x, y) == 0.0:
			Kit.cell_set(g, x, y, 2.0)

static func _bsp_join(b: Dictionary, ni: int) -> void:
	var D: Dictionary = b.D
	var r: RandomNumberGenerator = b.r
	var g: Dictionary = b.g
	var nodes: Array = b.nodes
	var nd: Dictionary = nodes[ni]
	var vert: bool = (nd.split as Dictionary).vert
	var roomsA: Array = (nodes[nd.a] as Dictionary).rooms
	var roomsB: Array = (nodes[nd.b] as Dictionary).rooms
	var ra: Dictionary = {}
	var rb: Dictionary = {}
	var best := 0
	if D.corridor == "straight":                                # the pair of rooms that overlap most across the cut
		for p: Dictionary in roomsA:
			for q: Dictionary in roomsB:
				var ov: int
				if vert:
					ov = mini(int(p.y) + int(p.h), int(q.y) + int(q.h)) - maxi(int(p.y), int(q.y))
				else:
					ov = mini(int(p.x) + int(p.w), int(q.x) + int(q.w)) - maxi(int(p.x), int(q.x))
				if ov > best:
					best = ov
					ra = p
					rb = q
	if ra.is_empty():
		ra = roomsA[_pick(r, roomsA.size())]
		rb = roomsB[_pick(r, roomsB.size())]
	var ax := int(ra.x) + (int(ra.w) >> 1)
	var ay := int(ra.y) + (int(ra.h) >> 1)
	var bx := int(rb.x) + (int(rb.w) >> 1)
	var by := int(rb.y) + (int(rb.h) >> 1)
	if best > 0:                                                # a straight run through the shared band
		if vert:
			_bsp_carve_h(g, ax, bx, maxi(int(ra.y), int(rb.y)) + _pick(r, best))
		else:
			_bsp_carve_v(g, ay, by, maxi(int(ra.x), int(rb.x)) + _pick(r, best))
	elif r.randf() < 0.5:                                       # an L, elbow on one side …
		_bsp_carve_h(g, ax, bx, ay)
		_bsp_carve_v(g, ay, by, bx)
	else:                                                       # … or the other
		_bsp_carve_v(g, ay, by, ax)
		_bsp_carve_h(g, ax, bx, by)

static func _bsp_fire(b: Dictionary, e: Dictionary) -> void:
	var nodes: Array = b.nodes
	if e.kind == "split":
		b.curSplit = e.node
		(nodes[e.node] as Dictionary).fired = true
	elif e.kind == "rooms":
		for nd: Dictionary in nodes:
			if not (nd.room as Dictionary).is_empty():
				_bsp_carve_room(b.g, nd.room)
		b.curSplit = -1
	else:
		for ni in (e.nodes as Array):
			_bsp_join(b, ni)


# ── Maze ─────────────────────────────────────────────────────────────────

const MAZE_DX := [0, 1, 0, -1]      # n e s w
const MAZE_DY := [-1, 0, 1, 0]
const MAZE_BIT := [1, 2, 4, 8]
const MAZE_OPP := [4, 8, 1, 2]

static func _maze_carve(b: Dictionary) -> void:
	var D: Dictionary = b.D
	var r := Kit.rng(b.seed)
	b.r = r
	var cols: int = D.cols
	var N: int = b.N
	b.open = _bytes(N)
	b.seen = _bytes(N)
	b.inFront = _bytes(N)
	b.sp = 0
	b.nf = 0
	b.carved = 1
	b.done = false
	b.acc = 0.0
	b.restT = 0.0
	b.headDir = 1
	var s0 := _pick(r, int(D.rows)) * cols + _pick(r, cols)
	var seen: PackedByteArray = b.seen                          # typed locals share the array; a cast-write would hit a copy
	seen[s0] = 1
	b.head = s0
	if D.algo == "prim":
		_maze_add_frontier(b, s0)
	else:
		var stack: PackedInt32Array = b.stack
		stack[0] = s0
		b.sp = 1

static func _maze_add_frontier(b: Dictionary, c: int) -> void:
	var D: Dictionary = b.D
	var cols: int = D.cols
	var rows: int = D.rows
	var seen: PackedByteArray = b.seen
	var inFront: PackedByteArray = b.inFront
	var front: PackedInt32Array = b.front
	var x := c % cols
	var y := (c - x) / cols
	for d in 4:
		var nx: int = x + MAZE_DX[d]
		var ny: int = y + MAZE_DY[d]
		if nx < 0 or ny < 0 or nx >= cols or ny >= rows:
			continue
		var nn := ny * cols + nx
		if seen[nn] == 0 and inFront[nn] == 0:
			inFront[nn] = 1
			front[b.nf] = nn
			b.nf += 1

## Knock the wall between c and its neighbour in direction d.
static func _maze_link(b: Dictionary, c: int, d: int) -> int:
	var cols: int = (b.D as Dictionary).cols
	var open: PackedByteArray = b.open
	var nn: int = c + MAZE_DX[d] + MAZE_DY[d] * cols
	open[c] = open[c] | MAZE_BIT[d]
	open[nn] = open[nn] | MAZE_OPP[d]
	return nn

static func _maze_step(b: Dictionary) -> void:
	var D: Dictionary = b.D
	var r: RandomNumberGenerator = b.r
	var cols: int = D.cols
	var rows: int = D.rows
	var seen: PackedByteArray = b.seen
	var nbrs: Array = []
	if D.algo == "prim":
		var nf: int = b.nf
		if nf == 0:
			b.done = true
			return
		var front: PackedInt32Array = b.front
		var inFront: PackedByteArray = b.inFront
		var i := _pick(r, nf)
		var c := front[i]
		nf -= 1
		front[i] = front[nf]
		b.nf = nf
		inFront[c] = 0
		var x := c % cols
		var y := (c - x) / cols
		for d in 4:                                             # the carved cells it touches: pick one to join
			var nx: int = x + MAZE_DX[d]
			var ny: int = y + MAZE_DY[d]
			if nx >= 0 and ny >= 0 and nx < cols and ny < rows and seen[ny * cols + nx] == 1:
				nbrs.append(d)
		var d: int = nbrs[_pick(r, nbrs.size())]
		_maze_link(b, c, d)
		seen[c] = 1
		b.carved += 1
		b.head = c
		b.headDir = (d + 2) % 4
		_maze_add_frontier(b, c)
	else:
		var sp: int = b.sp
		if sp == 0:
			b.done = true
			return
		var stack: PackedInt32Array = b.stack
		var c := stack[sp - 1]
		var x := c % cols
		var y := (c - x) / cols
		for d in 4:
			var nx: int = x + MAZE_DX[d]
			var ny: int = y + MAZE_DY[d]
			if nx >= 0 and ny >= 0 and nx < cols and ny < rows and seen[ny * cols + nx] == 0:
				nbrs.append(d)
		if nbrs.is_empty():                                     # a dead end: back up
			sp -= 1
			b.sp = sp
			b.head = stack[sp - 1] if sp > 0 else c
			return
		var d: int = nbrs[_pick(r, nbrs.size())]
		var nn := _maze_link(b, c, d)
		seen[nn] = 1
		stack[sp] = nn
		b.sp = sp + 1
		b.carved += 1
		b.head = nn
		b.headDir = d


# ── Wfc ──────────────────────────────────────────────────────────────────

static func _wfc_reset(b: Dictionary, fresh: bool) -> void:
	if fresh:
		b.r = Kit.rng(b.seed)
		b.restarts = 0
	var opt: PackedByteArray = b.opt
	opt.fill(b.FULL)
	b.left = b.N
	b.last = -1
	b.lastE = 0
	b.acc = 0.0
	b.restT = 0.0

static func _wfc_propagate(b: Dictionary, c0: int) -> bool:
	var D: Dictionary = b.D
	var cols: int = D.cols
	var rows: int = D.rows
	var N: int = b.N
	var T: int = b.T
	var opt: PackedByteArray = b.opt
	var queue: PackedInt32Array = b.queue
	var queued: PackedByteArray = b.queued
	var allow: PackedInt32Array = b.allow
	var bits: PackedByteArray = b.bits
	var qn := 0
	queue[qn] = c0
	qn += 1
	queued[c0] = 1
	var ok := true
	var qi := 0
	while qi < qn:
		var c := queue[qi]
		qi += 1
		var x := c % cols
		var y := (c - x) / cols
		var m := 0
		for tt in T:                                            # what may sit beside what remains
			if opt[c] & (1 << tt):
				m |= allow[tt]
		var nb := [c - 1 if x > 0 else -1, c + 1 if x < cols - 1 else -1, c - cols if y > 0 else -1, c + cols if y < rows - 1 else -1]
		for k in 4:
			var nn: int = nb[k]
			if nn < 0:
				continue
			var nm := opt[nn] & m
			if nm != opt[nn]:
				if bits[opt[nn]] > 1 and bits[nm] == 1:
					b.left -= 1
				opt[nn] = nm
				if nm == 0:
					ok = false
				if queued[nn] == 0 and qn < N:
					queued[nn] = 1
					queue[qn] = nn
					qn += 1
	for i in qn:
		queued[queue[i]] = 0
	return ok

## One tile, by weight, from what is left.
static func _wfc_collapse(b: Dictionary, c: int) -> void:
	var D: Dictionary = b.D
	var r: RandomNumberGenerator = b.r
	var T: int = b.T
	var opt: PackedByteArray = b.opt
	var bits: PackedByteArray = b.bits
	var weights: Array = D.weights
	var total := 0.0
	for tt in T:
		if opt[c] & (1 << tt):
			total += float(weights[tt])
	var v := r.randf() * total
	var pick := 0
	for tt in T:
		if opt[c] & (1 << tt):
			pick = tt
			v -= float(weights[tt])
			if v <= 0.0:
				break
	b.lastE = bits[opt[c]]
	b.last = c
	opt[c] = 1 << pick
	b.left -= 1
	if not _wfc_propagate(b, c):
		b.restarts += 1
		b.flash = 1.0
		_wfc_reset(b, false)

static func _wfc_step(b: Dictionary) -> void:
	if int(b.left) <= 0:
		return
	var r: RandomNumberGenerator = b.r
	var N: int = b.N
	var opt: PackedByteArray = b.opt
	var bits: PackedByteArray = b.bits
	var best := 99
	var ties := 0
	var pick := -1
	for c in N:                                                 # the lowest entropy, ties broken by the seed
		var e := int(bits[opt[c]])
		if e < 2:
			continue
		if e < best:
			best = e
			ties = 1
			pick = c
		elif e == best:
			ties += 1
			if r.randf() * ties < 1.0:
				pick = c
	if pick < 0:
		b.left = 0
		return
	_wfc_collapse(b, pick)


# ── Autotile ─────────────────────────────────────────────────────────────

static func _auto_wall_at(b: Dictionary, x: int, y: int) -> int:
	var D: Dictionary = b.D
	var cols: int = D.cols
	if x < 0 or y < 0 or x >= cols or y >= int(D.rows):
		return b.edge
	return (b.g as PackedByteArray)[y * cols + x]

static func _auto_layout(b: Dictionary) -> void:
	var D: Dictionary = b.D
	var r := Kit.rng(b.seed)
	var cols: int = D.cols
	var rows: int = D.rows
	var N: int = b.N
	var edge: int = b.edge
	var target: PackedByteArray = b.target
	var tmp: PackedByteArray = b.tmp
	var fill: float = D.fill
	for i in N:
		target[i] = 1 if r.randf() < fill else 0
	for _p in int(D.smooth):                                    # the Caves rule, once or twice, so the walls come in blobs
		for y in rows:
			for x in cols:
				var cnt := 0
				for j in range(-1, 2):
					for i in range(-1, 2):
						if i != 0 or j != 0:
							var xx := x + i
							var yy := y + j
							cnt += edge if (xx < 0 or yy < 0 or xx >= cols or yy >= rows) else target[yy * cols + xx]
				tmp[y * cols + x] = 1 if cnt >= 5 else 0
		for i in N:
			target[i] = tmp[i]
	var order: Array = []
	for i in N:
		if target[i] == 1:
			order.append(i)
	Kit.shuffle(order, r)
	b.order = order
	var g: PackedByteArray = b.g
	g.fill(0)
	b.laid = 0
	b.acc = 0.0
	b.restT = 0.0
	b.holdT = 0.0
	b.last = -1
	b.sincePress = 9.0
	_auto_remask(b)

static func _auto_mask_of(b: Dictionary, x: int, y: int) -> int:
	var nn := _auto_wall_at(b, x, y - 1)
	var ee := _auto_wall_at(b, x + 1, y)
	var ss := _auto_wall_at(b, x, y + 1)
	var ww := _auto_wall_at(b, x - 1, y)
	if int((b.D as Dictionary).bits) != 8:
		return nn + ee * 2 + ss * 4 + ww * 8
	return nn + ee * 4 + ss * 16 + ww * 64 + \
		(2 if nn == 1 and ee == 1 and _auto_wall_at(b, x + 1, y - 1) == 1 else 0) + \
		(8 if ee == 1 and ss == 1 and _auto_wall_at(b, x + 1, y + 1) == 1 else 0) + \
		(32 if ss == 1 and ww == 1 and _auto_wall_at(b, x - 1, y + 1) == 1 else 0) + \
		(128 if ww == 1 and nn == 1 and _auto_wall_at(b, x - 1, y - 1) == 1 else 0)   # corners count only between two present edges

static func _auto_remask(b: Dictionary) -> void:
	var D: Dictionary = b.D
	var cols: int = D.cols
	var g: PackedByteArray = b.g
	var mask: PackedByteArray = b.mask
	var flash: PackedFloat32Array = b.flash
	for y in int(D.rows):
		for x in cols:
			var i := y * cols + x
			var m := _auto_mask_of(b, x, y) if g[i] == 1 else 0
			if g[i] == 1 and m != mask[i]:                      # its index changed: a neighbour arrived or left
				flash[i] = 1.0
			mask[i] = m


# ── the four entry points ────────────────────────────────────────────────

static func init(b: Dictionary) -> void:
	var D: Dictionary = b.D
	match b.id:
		"caves":
			# CELLULAR AUTOMATA. start from noise — every cell is rock with chance
			# fill — then run one rule over the whole grid a few times: "count the
			# 8 neighbours; rock if rule or more of them are rock, open if two
			# fewer, otherwise stay as you are" (a majority vote, counting yourself).
			# lonely rocks vanish, lonely gaps fill, and the noise rounds itself
			# into caverns — the falling-sand idea (lexicon Sand) with a vote in
			# place of gravity. beyond the edge counts as rock, so the cave is
			# closed. the last step is a FLOOD FILL: label every open region, keep
			# the biggest, and turn the rest back to rock so nothing is unreachable.
			b.cw = b.w / float(D.cols)
			b.ch = (b.h - 18.0) / float(D.rows)
			b.N = int(D.cols) * int(D.rows)
			b.g = Kit.cells(int(D.cols), int(D.rows), 1.0)      # off the map is rock
			b.g2 = Kit.cells(int(D.cols), int(D.rows), 1.0)
			b.lab = _ints(b.N)
			b.stack = _ints(b.N)
			b.seed = int(D.seed)
			_caves_regrow(b)
		"bsp":
			# BINARY SPACE PARTITION. cut the map in two somewhere between 35 and
			# 65 %; cut each half again; stop after depth cuts or when a piece is
			# too thin. every leaf gets one room that fits inside it, so rooms never
			# overlap by construction. then walk the tree back up: every internal
			# node joins a room from its left child to a room from its right child,
			# so the whole dungeon is connected without a search. the tree on the
			# right is the same map as a family — the map is the tree, flattened.
			b.mw = b.w * 0.74
			b.mh = b.h - 18.0
			b.cw = float(b.mw) / float(D.cols)
			b.ch = float(b.mh) / float(D.rows)
			b.tx0 = float(b.mw) + 10.0
			b.tw = b.w - float(b.tx0) - 4.0
			b.g = Kit.cells(int(D.cols), int(D.rows))
			b.seed = int(D.seed)
			_bsp_build(b)
		"maze":
			# MAZE CARVING. every cell starts walled on four sides; a carver visits
			# cells and knocks down the wall between each new cell and the one it
			# came from, so the maze is a tree — one route between any two cells.
			# the RECURSIVE BACKTRACKER keeps a stack: go to a random unvisited
			# neighbour, and when there is none, back up. it commits, so halls are
			# long. PRIM'S keeps a FRONTIER — every unvisited cell touching the
			# carved part — and picks any of them, so it branches everywhere and
			# halls are short. the dead-end count is the fingerprint: the Astar
			# card would find these mazes very different to search.
			b.N = int(D.cols) * int(D.rows)
			b.cw = b.w / float(D.cols)
			b.ch = (b.h - 18.0) / float(D.rows)
			b.stack = _ints(b.N)
			b.front = _ints(b.N)
			b.seed = int(D.seed)
			_maze_carve(b)
		"wfc":
			# WAVE FUNCTION COLLAPSE, the simple tiled kind. every cell begins as a
			# SUPERPOSITION — a bitmask of every tile it could still be. each step
			# picks the cell with the LOWEST ENTROPY (fewest options left, ties at
			# random), COLLAPSES it to one tile by weight, and PROPAGATES: each
			# neighbour drops any option no longer allowed next to what remains,
			# and if it changed, its neighbours check again. a cell left with zero
			# options is a CONTRADICTION; the honest fix is to start over. the
			# rule table in the corner is the whole world's grammar: five pairs.
			var T: int = (D.tiles as Array).size()
			b.N = int(D.cols) * int(D.rows)
			b.T = T
			b.cw = b.w / float(D.cols)
			b.ch = (b.h - 18.0) / float(D.rows)
			b.opt = _bytes(b.N)
			b.queue = _ints(b.N)
			b.queued = _bytes(b.N)
			b.FULL = (1 << T) - 1
			var allow := _ints(T)
			for a in T:
				for p: Array in (D.rules as Array):
					if int(p[0]) == a:
						allow[a] |= 1 << int(p[1])
					if int(p[1]) == a:
						allow[a] |= 1 << int(p[0])
			b.allow = allow
			var bits := _bytes(1 << T)                          # popcount and highest-bit tables for every mask
			var hi := _bytes(1 << T)
			for m in (1 << T):
				var cnt := 0
				var top := 0
				for tt in T:
					if m & (1 << tt):
						cnt += 1
						top = tt
				bits[m] = cnt
				hi[m] = top
			b.bits = bits
			b.hi = hi
			var cols: Array = []
			for hx in (D.colours as Array):
				cols.append(Color(String(hx)))
			b.cols = cols
			b.seed = int(D.seed)
			b.flash = 0.0
			_wfc_reset(b, true)
		"autotile":
			# AUTOTILING. a wall tile does not know what it looks like; its
			# neighbours decide. ask the four sides "are you a wall too?" and sum
			# the yeses with place values — north 1, east 2, south 4, west 8 — and
			# the BITMASK is a number from 0 to 15 that names exactly which edges
			# need a rim. paint one wall and the tiles around it change their own
			# index, so corners and ends resolve themselves. with 8 bits the
			# diagonals join in (only where both of their edges are walls), and
			# inner corners get their notch — the 47-tile "blob" set.
			b.N = int(D.cols) * int(D.rows)
			b.cw = b.w / float(D.cols)
			b.ch = (b.h - 18.0) / float(D.rows)
			var pals: Dictionary = D.palettes
			var hexes: Array = pals[D.palette] if pals.has(D.palette) else pals.wall
			var pal: Array = []
			for hx in hexes:
				pal.append(Color(String(hx)))
			b.pal = pal
			b.edge = 0 if D.palette == "island" else 1           # off the map: more wall, or open sea
			b.target = _bytes(b.N)
			b.g = _bytes(b.N)
			b.tmp = _bytes(b.N)
			b.mask = _bytes(b.N)
			var flash := PackedFloat32Array()
			flash.resize(b.N)
			b.flash = flash
			b.mode = 1
			b.seed = int(D.seed)
			_auto_layout(b)

static func press(b: Dictionary, pos: Vector2) -> void:
	var D: Dictionary = b.D
	match b.id:
		"caves":
			b.seed += 1
			_caves_regrow(b)
		"bsp":
			b.seed += 1
			_bsp_build(b)
		"maze":
			b.seed += 1
			_maze_carve(b)
		"wfc":
			_wfc_reset(b, true)                                 # the same seed, but your cell goes first
			var cx := clampi(int(floorf(pos.x / float(b.cw))), 0, int(D.cols) - 1)
			var cy := clampi(int(floorf(pos.y / float(b.ch))), 0, int(D.rows) - 1)
			_wfc_collapse(b, cy * int(D.cols) + cx)
		"autotile":
			var cols: int = D.cols
			var cx := clampi(int(floorf(pos.x / float(b.cw))), 0, cols - 1)
			var cy := clampi(int(floorf(pos.y / float(b.ch))), 0, int(D.rows) - 1)
			var i := cy * cols + cx
			var g: PackedByteArray = b.g
			if float(b.sincePress) > 0.3:                       # a fresh press toggles what it lands on; a drag keeps painting the same
				b.mode = 0 if g[i] == 1 else 1
			b.sincePress = 0.0
			var order: Array = b.order
			if int(b.laid) < order.size():                      # finish the growth, then paint on it
				for c in order:
					g[c] = 1
				b.laid = order.size()
			g[i] = b.mode
			b.last = i
			b.holdT = float(D.hold)
			b.restT = 0.0
			_auto_remask(b)

static func tick(b: Dictionary, dt: float, _t: float) -> void:
	var D: Dictionary = b.D
	match b.id:
		"caves":
			var passes: int = D.passes
			var last := passes + 2                              # passes, then the flood, then the sealing
			if int(b.pass_n) < last:
				b.acc += dt
				if float(b.acc) >= float(D.beat):
					b.acc = 0.0
					b.pass_n += 1
					if int(b.pass_n) <= passes:
						_caves_smooth(b)
					elif int(b.pass_n) == passes + 1:
						_caves_keep_largest(b)
					else:
						_caves_seal(b)
			else:
				b.restT += dt
				if float(b.restT) > float(D.rest):
					b.seed += 1
					_caves_regrow(b)
		"bsp":
			var events: Array = b.events
			if int(b.ev) < events.size():
				b.acc += dt
				if float(b.acc) >= float(D.beat):
					b.acc = 0.0
					_bsp_fire(b, events[b.ev])
					b.ev += 1
			else:
				b.restT += dt
				if float(b.restT) > float(D.rest):
					b.seed += 1
					_bsp_build(b)
		"maze":
			if not b.done:
				b.acc += dt
				var beat: float = D.beat
				var guard := 0
				while float(b.acc) >= beat and not b.done and guard < 30:
					guard += 1
					b.acc -= beat
					for _i in int(D.perBeat):
						if b.done:
							break
						_maze_step(b)
			else:
				b.restT += dt
				if float(b.restT) > float(D.rest):
					b.seed += 1
					_maze_carve(b)
		"wfc":
			b.flash = maxf(0.0, float(b.flash) - dt * 1.5)
			if int(b.left) > 0:
				b.acc += dt
				var beat: float = D.beat
				var guard := 0
				while float(b.acc) >= beat and int(b.left) > 0 and guard < 30:
					guard += 1
					b.acc -= beat
					for _i in int(D.perBeat):
						if int(b.left) <= 0:
							break
						_wfc_step(b)
			else:
				b.restT += dt
				if float(b.restT) > float(D.rest):
					b.seed += 1
					_wfc_reset(b, true)
		"autotile":
			b.sincePress += dt
			var flash: PackedFloat32Array = b.flash
			for i in int(b.N):
				if flash[i] > 0.0:
					flash[i] = maxf(0.0, flash[i] - dt * 2.5)
			var order: Array = b.order
			if int(b.laid) < order.size():
				b.acc += dt
				var beat: float = D.beat
				var guard := 0
				var g: PackedByteArray = b.g
				while float(b.acc) >= beat and int(b.laid) < order.size() and guard < 30:
					guard += 1
					b.acc -= beat
					for _k in int(D.perBeat):
						if int(b.laid) >= order.size():
							break
						b.last = order[b.laid]
						b.laid += 1
						g[b.last] = 1
				_auto_remask(b)
			elif float(b.holdT) > 0.0:
				b.holdT -= dt
			else:
				b.restT += dt
				if float(b.restT) > float(D.rest):
					b.seed += 1
					_auto_layout(b)

static func draw(n: CanvasItem, b: Dictionary, _t: float) -> void:
	var D: Dictionary = b.D
	var w: float = b.w
	var h: float = b.h
	Kit.stage(n, b)
	match b.id:
		"caves":
			var cw: float = b.cw
			var ch: float = b.ch
			var passes: int = D.passes
			var rule: int = D.rule
			var pass_n: int = b.pass_n
			var rock := Color(0.788, 0.769, 0.894, 0.5)
			var doomed := Color(0.961, 0.541, 0.541, 0.45)
			Kit.draw_cells(n, b.g, Vector2.ZERO, cw, ch, func(v: float, _x: int, _y: int) -> Variant:
				return rock if v == 1.0 else (doomed if v == 2.0 else null))
			if pass_n < passes:                                 # the rule, on one cell
				var hx: int = b.hx
				var hy: int = b.hy
				var hn: int = b.hn
				n.draw_rect(Rect2((hx - 1) * cw, (hy - 1) * ch, cw * 3.0, ch * 3.0), Kit.TARGET, false, 1.5)
				var v := _caves_verdict(b, hx, hy, hn)
				var cc := Kit.HOT if hn >= rule else (Kit.GOOD if hn <= rule - 2 else Kit.TARGET)
				n.draw_rect(Rect2(hx * cw, hy * ch, cw, ch), cc)
				var fs := roundi(clampf(ch * 0.95, 7.0, 13.0))
				_txt(n, str(hn), (hx + 0.5) * cw, (hy + 0.5) * ch + ch * 0.35, Color(0.075, 0.063, 0.125), "center", fs)
				var verdictTxt: String
				if hn >= rule:
					verdictTxt = "≥ %d → rock" % rule
				elif hn <= rule - 2:
					verdictTxt = "≤ %d → open" % (rule - 2)
				else:
					verdictTxt = "= %d → stays %s" % [hn, "rock" if v == 1.0 else "open"]
				var right := hx < float(D.cols) * 0.6
				_txt(n, "%d of 8 %s" % [hn, verdictTxt], (hx + 2.2) * cw if right else (hx - 1.2) * cw, (hy + 0.5) * ch + 3.0,
					Kit.TARGET, "left" if right else "right")
			elif int(b.homeX) >= 0 and pass_n > passes:
				Kit.mote(n, b, Vector2((int(b.homeX) + 0.5) * cw, (int(b.homeY) + 0.5) * ch), 0.0, Kit.MOVER, minf(cw, ch) * 0.9)
			var stageTxt: String
			if pass_n == 0:
				stageTxt = "random fill %d%%" % roundi(float(D.fill) * 100.0)
			elif pass_n <= passes:
				stageTxt = "pass %d / %d" % [pass_n, passes]
			elif pass_n == passes + 1:
				stageTxt = "flood fill: keep %d, drop %d cells" % [int(b.kept), int(b.dropped)]
			else:
				stageTxt = "sealed · %d open cells" % int(b.kept)
			_txt(n, stageTxt, 4.0, 11.0, Kit.HOT if pass_n == passes + 1 else DEFAULT_TXT)
			_txt(n, String(D.label) + " · rule %d · ×%d" % [rule, passes], w / 2.0, h - 6.0, DEFAULT_TXT, "center")
		"bsp":
			var cw: float = b.cw
			var ch: float = b.ch
			var mw: float = b.mw
			var mh: float = b.mh
			var tx0: float = b.tx0
			var tw: float = b.tw
			var nodes: Array = b.nodes
			var events: Array = b.events
			var ev: int = b.ev
			var curSplit: int = b.curSplit
			var leaves: int = b.leaves
			var floorC := Color(0.788, 0.769, 0.894, 0.55)
			var hallC := Color(0.541, 0.851, 0.961, 0.45)
			Kit.draw_cells(n, b.g, Vector2.ZERO, cw, ch, func(v: float, _x: int, _y: int) -> Variant:
				return floorC if v == 1.0 else (hallC if v == 2.0 else null))
			var splits := 0
			var faint := Color(0.961, 0.757, 0.412, 0.22)
			for i in ev:                                        # every cut so far, the newest in amber
				var e: Dictionary = events[i]
				if e.kind != "split":
					continue
				splits += 1
				var ni: int = e.node
				var nd: Dictionary = nodes[ni]
				var sp: Dictionary = nd.split
				var hot := ni == curSplit
				var at: int = sp.at
				var nx: int = nd.x
				var ny: int = nd.y
				var nw: int = nd.w
				var nh: int = nd.h
				var lc := Kit.TARGET if hot else faint
				var lw := 1.5 if hot else 1.0
				if sp.vert:
					Kit.line(n, Vector2((nx + at) * cw, ny * ch), Vector2((nx + at) * cw, (ny + nh) * ch), lc, lw)
				else:
					Kit.line(n, Vector2(nx * cw, (ny + at) * ch), Vector2((nx + nw) * cw, (ny + at) * ch), lc, lw)
				if hot:
					var vert: bool = sp.vert
					var pct := roundi(at / float(nw if vert else nh) * 100.0)
					_txt(n, "%s%d (%d %%)" % ["x = " if vert else "y = ", (nx + at) if vert else (ny + at), pct],
						clampf((nx + (at if vert else nw / 2.0)) * cw + 3.0, 0.0, mw - 60.0),
						clampf((ny + (1.5 if vert else at)) * ch - 3.0, 10.0, mh), Kit.TARGET)
			var dy := (mh - 20.0) / maxf(1.0, float(D.depth))    # the tree, small, beside the map
			var dx := tw / maxf(1.0, float(leaves))
			for nd: Dictionary in nodes:
				if int(nd.a) < 0 or not nd.fired:               # a branch appears with its cut
					continue
				var p := Vector2(tx0 + (float(nd.tx) + 0.5) * dx, 10.0 + int(nd.d) * dy)
				var na: Dictionary = nodes[nd.a]
				var nb: Dictionary = nodes[nd.b]
				Kit.line(n, p, Vector2(tx0 + (float(na.tx) + 0.5) * dx, 10.0 + int(na.d) * dy), Kit.DIM)
				Kit.line(n, p, Vector2(tx0 + (float(nb.tx) + 0.5) * dx, 10.0 + int(nb.d) * dy), Kit.DIM)
			for ni in nodes.size():
				var nd: Dictionary = nodes[ni]
				var p := Vector2(tx0 + (float(nd.tx) + 0.5) * dx, 10.0 + int(nd.d) * dy)
				if int(nd.a) >= 0:
					Kit.dot(n, p, 3.0 if ni == curSplit else 1.8, Kit.TARGET if ni == curSplit else Kit.BONE)
				else:
					var room: Dictionary = nd.room
					if not room.is_empty() and Kit.cell_get(b.g, room.x, room.y) == 1.0:   # a leaf with its room
						Kit.rect(n, Rect2(p.x - 1.5, p.y - 1.5, 3.0, 3.0), Kit.BONE)
					else:
						Kit.dot(n, p, 1.2, Kit.DIM)
			Kit.line(n, Vector2(mw + 4.0, 0.0), Vector2(mw + 4.0, mh), Color(0.788, 0.769, 0.894, 0.2))
			_txt(n, "splits %d · leaves %d · %s" % [splits, leaves, String(D.corridor)], 4.0, 11.0)
			_txt(n, D.label, w / 2.0, h - 6.0, DEFAULT_TXT, "center")
		"maze":
			var cols: int = D.cols
			var rows: int = D.rows
			var N: int = b.N
			var cw: float = b.cw
			var ch: float = b.ch
			var open: PackedByteArray = b.open
			var seen: PackedByteArray = b.seen
			var solid := Color(0.0, 0.0, 0.0, 0.28)                # unvisited: still solid
			for c in N:
				if seen[c] == 0:
					var x := c % cols
					n.draw_rect(Rect2(x * cw, ((c - x) / cols) * ch, cw + 0.5, ch + 0.5), solid)
			var wallC := Color(0.788, 0.769, 0.894, 0.7)
			n.draw_rect(Rect2(0.5, 0.5, cols * cw - 1.0, rows * ch - 1.0), wallC, false, 1.2)
			var walls := PackedVector2Array()
			var dead := 0
			for c in N:                                         # each cell owns its east and south wall
				var x := c % cols
				var y := (c - x) / cols
				var o := open[c]
				if (o & 2) == 0 and x < cols - 1:
					walls.append(Vector2((x + 1) * cw, y * ch))
					walls.append(Vector2((x + 1) * cw, (y + 1) * ch))
				if (o & 4) == 0 and y < rows - 1:
					walls.append(Vector2(x * cw, (y + 1) * ch))
					walls.append(Vector2((x + 1) * cw, (y + 1) * ch))
				if o == 1 or o == 2 or o == 4 or o == 8:
					dead += 1
			if walls.size() >= 2:
				n.draw_multiline(walls, wallC, 1.2)
			var prim: bool = D.algo == "prim"
			var sp: int = b.sp
			if not b.done:
				if prim:
					var front: PackedInt32Array = b.front
					for i in int(b.nf):
						var c := front[i]
						var x := c % cols
						Kit.dot(n, Vector2((x + 0.5) * cw, ((c - x) / cols + 0.5) * ch), minf(cw, ch) * 0.18, Kit.TARGET)
				elif sp > 1:                                    # the stack: the way back
					var stack: PackedInt32Array = b.stack
					var pts := PackedVector2Array()
					pts.resize(sp)
					for i in sp:
						var c := stack[i]
						var x := c % cols
						pts[i] = Vector2((x + 0.5) * cw, ((c - x) / cols + 0.5) * ch)
					n.draw_polyline(pts, Color(0.541, 0.851, 0.961, 0.5), maxf(1.0, cw * 0.18))
			var head: int = b.head
			var hx := head % cols
			var hy := (head - hx) / cols
			var headings := [-PI / 2.0, 0.0, PI / 2.0, PI]
			Kit.mote(n, b, Vector2((hx + 0.5) * cw, (hy + 0.5) * ch), headings[b.headDir], Kit.MOVER, minf(cw, ch) * 0.28)
			var tail := " · frontier %d" % int(b.nf) if prim else " · stack %d" % sp
			_txt(n, "%s · %d / %d%s" % [String(D.algo), int(b.carved), N, tail], 4.0, 11.0)
			_txt(n, "dead ends: %d" % dead, w - 4.0, 11.0, Kit.HOT if b.done else DEFAULT_TXT, "right")
			_txt(n, D.label, w / 2.0, h - 6.0, DEFAULT_TXT, "center")
		"wfc":
			var cols: int = D.cols
			var N: int = b.N
			var T: int = b.T
			var cw: float = b.cw
			var ch: float = b.ch
			var opt: PackedByteArray = b.opt
			var bits: PackedByteArray = b.bits
			var hi: PackedByteArray = b.hi
			var tileCols: Array = b.cols
			var allow: PackedInt32Array = b.allow
			var last: int = b.last
			var fs := clampf(cw * 0.75, 6.0, 11.0)
			var allDigits := fs >= 7.0
			var lx := last % cols if last >= 0 else -9
			var ly := (last - lx) / cols if last >= 0 else -9
			var digitC := Color(0.91, 0.898, 0.957, 0.6)
			var f := ThemeDB.fallback_font
			for c in N:
				var x := c % cols
				var y := (c - x) / cols
				var m := opt[c]
				var e := int(bits[m])
				if e == 1:
					var tc: Color = tileCols[hi[m]]
					n.draw_rect(Rect2(x * cw, y * ch, cw + 0.5, ch + 0.5), tc)
				else:
					n.draw_rect(Rect2(x * cw, y * ch, cw + 0.5, ch + 0.5), Color(0.91, 0.898, 0.957, 0.04 + (T - e) * 0.07))   # fewer options: brighter
					if allDigits or (absi(x - lx) <= 1 and absi(y - ly) <= 1):
						var txt := str(e)
						var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, int(fs)).x
						n.draw_string(f, Vector2((x + 0.5) * cw - tw / 2.0, (y + 0.5) * ch + fs * 0.35), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, int(fs), digitC)
			if last >= 0:
				n.draw_rect(Rect2(lx * cw, ly * ch, cw, ch), Kit.TARGET, false, 1.5)
				var om := opt[last] if opt[last] != 0 else 1
				_txt(n, "e = %d → %s" % [int(b.lastE), String((D.tiles as Array)[hi[om]])],
					clampf((lx + 1.3) * cw, 0.0, w - 70.0), clampf((ly + 0.5) * ch + 3.0, 10.0, h - 20.0), Kit.TARGET)
			var s0 := clampf(w * 0.028, 6.0, 12.0)              # the rule table
			var tx := w - (T + 1) * s0 - 6.0
			var ty := 4.0
			Kit.rect(n, Rect2(tx - 2.0, ty - 2.0, (T + 1) * s0 + 4.0, (T + 1) * s0 + 4.0), Color(0.075, 0.063, 0.125, 0.75))
			for a in T:
				var tc: Color = tileCols[a]
				Kit.rect(n, Rect2(tx + (a + 1) * s0, ty, s0 - 1.0, s0 - 1.0), tc)
				Kit.rect(n, Rect2(tx, ty + (a + 1) * s0, s0 - 1.0, s0 - 1.0), tc)
			for a in T:
				for bb in T:
					if (allow[a] >> bb) & 1:
						Kit.rect(n, Rect2(tx + (bb + 1) * s0 + 1.0, ty + (a + 1) * s0 + 1.0, s0 - 3.0, s0 - 3.0), Kit.GOOD)
					else:
						Kit.line(n, Vector2(tx + (bb + 1) * s0 + 2.0, ty + (a + 1) * s0 + s0 / 2.0), Vector2(tx + (bb + 2) * s0 - 3.0, ty + (a + 1) * s0 + s0 / 2.0), Kit.HOT, 1.0)
			var flash: float = b.flash
			if flash > 0.0:
				_txt(n, "contradiction — restart", w / 2.0, h / 2.0, Color(Kit.HOT, minf(1.0, flash)), "center")
			var left: int = b.left
			_txt(n, "undecided %d / %d" % [left, N] if left > 0 else "done · %d cells" % N, 4.0, 11.0)
			var restarts: int = b.restarts
			_txt(n, "restarts %d" % restarts, 4.0, 22.0, Kit.HOT if restarts > 0 else Kit.DIM)
			_txt(n, D.label, w / 2.0, h - 6.0, DEFAULT_TXT, "center")
		"autotile":
			var cols: int = D.cols
			var rows: int = D.rows
			var cw: float = b.cw
			var ch: float = b.ch
			var eight: bool = int(D.bits) == 8
			var g: PackedByteArray = b.g
			var mask: PackedByteArray = b.mask
			var flash: PackedFloat32Array = b.flash
			var pal: Array = b.pal
			var pal0: Color = pal[0]
			var pal1: Color = pal[1]
			var pal2: Color = pal[2]
			var pal3: Color = pal[3]
			var fs := clampf(cw * 0.5, 6.0, 10.0)
			var digits := fs >= 7.0
			var rim := maxf(1.5, minf(cw, ch) * 0.16)
			n.draw_rect(Rect2(0.0, 0.0, cols * cw, rows * ch), pal0)
			var f := ThemeDB.fallback_font
			var inkC := Color(0.075, 0.063, 0.125, 0.7)
			for y in rows:
				for x in cols:
					var i := y * cols + x
					if g[i] == 0:
						continue
					var px := x * cw
					var py := y * ch
					var m := int(mask[i])
					var nn := m & 1
					var ee := (m & 4) if eight else (m & 2)
					var ss := (m & 16) if eight else (m & 4)
					var ww := (m & 64) if eight else (m & 8)
					n.draw_rect(Rect2(px, py, cw + 0.5, ch + 0.5), Color(Kit.GOOD, 0.35 + flash[i] * 0.5) if flash[i] > 0.0 else pal1)
					if nn == 0:                                 # a rim on every side that faces the floor
						n.draw_rect(Rect2(px, py, cw + 0.5, rim), pal2)
					if ss == 0:
						n.draw_rect(Rect2(px, py + ch - rim, cw + 0.5, rim + 0.5), pal2)
					if ww == 0:
						n.draw_rect(Rect2(px, py, rim, ch + 0.5), pal2)
					if ee == 0:
						n.draw_rect(Rect2(px + cw - rim, py, rim + 0.5, ch + 0.5), pal2)
					if eight:                                   # inner corners: two edges present, the diagonal missing
						if nn != 0 and ee != 0 and (m & 2) == 0:
							n.draw_rect(Rect2(px + cw - rim, py, rim + 0.5, rim), pal3)
						if ee != 0 and ss != 0 and (m & 8) == 0:
							n.draw_rect(Rect2(px + cw - rim, py + ch - rim, rim + 0.5, rim + 0.5), pal3)
						if ss != 0 and ww != 0 and (m & 32) == 0:
							n.draw_rect(Rect2(px, py + ch - rim, rim, rim + 0.5), pal3)
						if ww != 0 and nn != 0 and (m & 128) == 0:
							n.draw_rect(Rect2(px, py, rim, rim), pal3)
					if digits:
						var txt := str(m)
						var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, int(fs)).x
						n.draw_string(f, Vector2(px + cw / 2.0 - tw / 2.0, py + ch / 2.0 + fs * 0.35), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, int(fs), inkC)
			var last: int = b.last
			if last >= 0 and g[last] == 1:                      # the sum, spelt out on the newest tile
				var lx := last % cols
				var ly := (last - lx) / cols
				var m := int(mask[last])
				var names := ["n", "ne", "e", "se", "s", "sw", "w", "nw"] if eight else ["n", "e", "s", "w"]
				var parts := PackedStringArray()
				for bb in names.size():
					if m & (1 << bb):
						parts.append("%s·%d" % [names[bb], 1 << bb])
				n.draw_rect(Rect2((lx - 1) * cw, (ly - 1) * ch, cw * 3.0, ch * 3.0), Kit.TARGET, false, 1.5)
				var right := lx < float(cols) * 0.55
				_txt(n, "%s = %d" % [" + ".join(parts) if parts.size() > 0 else "none", m],
					(lx + 2.3) * cw if right else (lx - 1.3) * cw, clampf((ly + 0.5) * ch + 3.0, 10.0, h - 22.0),
					Kit.TARGET, "left" if right else "right")
			var order: Array = b.order
			var laid: int = b.laid
			var state: String
			if laid < order.size():
				state = "laying %d / %d" % [laid, order.size()]
			elif float(b.holdT) > 0.0:
				state = "yours"
			else:
				state = "seed %d" % int(b.seed)
			_txt(n, "%d-bit · %d tiles · %s" % [int(D.bits), 47 if eight else 16, state], 4.0, 11.0)
			_txt(n, String(D.label) + (" · + corners 2 · 8 · 32 · 128" if eight else ""), w / 2.0, h - 6.0, DEFAULT_TXT, "center")
