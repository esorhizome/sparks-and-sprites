extends RefCounted

const Kit := preload("res://scenes/motion/kit.gd")
## COLLISION & CONTACT — thirteen movement styles, ported from the web
## lexicon (docs/locomotion.js). What touches what. A game world is a pile
## of shapes that must not pass through each other, and every rule here is
## a TEST followed by a PUSH: boxes overlap only when four edge tests all
## pass; circles touch when the centres are closer than the radii add up
## to; a fast bullet is swept, not stepped, so a thin wall still catches
## it; a tilemap is walked one axis at a time; a one-way ledge asks where
## the feet were LAST frame; a slope hands the velocity its tangent;
## whiskers of short rays light the onFloor lamp; a spatial hash decides
## who is even worth testing; triggers only watch; a hitbox exists for six
## frames; billiard balls trade momentum along the normal; and rotated
## crates confess a gap on a separating axis.

const TITLE := "Collision & contact"
const BLURB := "what touches what — boxes and circles, sweeps, tiles one axis at a time, one-way ledges, slopes, sensors, triggers, hitboxes"
const DEFS := [
	{ "id": "aabb", "letter": "A", "name": "Aabb",
		"hint": "two axis-aligned boxes overlap only if all four edge tests pass; the push is along the axis of least penetration — press to place the crate",
		"dials": { "crates": 1,          # how many crates stand in the way
			"speed": 0.45,               # the Lissajous clock, radians per second
			"bw": 0.15, "bh": 0.11,      # the mote's box, ×W and ×H
			"cw": 0.17, "ch": 0.15,      # a crate, ×W and ×H
			"label": "aL<bR ∧ aR>bL ∧ aT<bB ∧ aB>bT · push = min(px, py)" },
		"rhyme": { "name": "Arcade", "hint": "three crates and a box twice as quick — the same four tests, run against every crate in turn",
			"dials": { "crates": 3, "speed": 0.9 } } },
	{ "id": "overlap", "letter": "O", "name": "Overlap",
		"hint": "circle vs circle is d < r₁ + r₂; circle vs rectangle clamps the centre to the nearest point on the box — press to move the rectangle",
		"dials": { "r1": 0.075, "r2": 0.05,   # the two circles, ×H
			"rw": 0.3, "rh": 0.18,            # the rectangle, ×W and ×H
			"orbit": 0.3,                     # the circles' orbit radius, ×W
			"speed": 0.8,                     # their orbit rate, radians per second
			"label": "d < r₁ + r₂ · p = clamp(c, min, max) · |c − p| < r" },
		"rhyme": { "name": "Oversize", "hint": "one huge circle and a tiny box — the nearest-point clamp still finds the one spot that matters",
			"dials": { "r1": 0.19, "rw": 0.1, "rh": 0.08 } } },
	{ "id": "tunnel", "letter": "T", "name": "Tunnel",
		"hint": "a fast box stepped naively skips a thin wall; a swept AABB finds the time of impact t in 0..1 and stops there (Xmarks' ray, with a box) — press to fire toward your click",
		"dials": { "speed": 3.0,         # the bullet, screens per second
			"stepDt": 0.06,              # the game's frame length, seconds — one step per frame
			"slow": 0.7,                 # seconds we take to show each step
			"hold": 1.6,                 # seconds to hold the frozen hit before firing again
			"wall": 0.02,                # wall thickness, ×W
			"bullet": 0.06,              # the bullet box, ×W
			"label": "hit ⇔ max(tx₁, ty₁) ≤ min(tx₂, ty₂), inside 0..1" },
		"rhyme": { "name": "Turbo", "hint": "a bullet nearly twice as fast against a wall a third as thick — the naive step never lands, the sweep still does",
			"dials": { "speed": 5.5, "wall": 0.008 } } },
	{ "id": "xaxis", "letter": "X", "name": "Xaxis",
		"hint": "tilemap collision: move on x, sample the body's corner tiles, push out; THEN do y (Grid's cells) — press to send the mote",
		"dials": { "body": 0.75,         # the body's side, in tiles
			"speed": 0.55,               # its speed, ×W per second
			"map": ["##########",
				"#........#",
				"#..##....#",
				"#.....#..#",
				"#.#...#..#",
				"#.#......#",
				"##########"],
			"label": "x += vx·dt → sample corners → push · then y" },
		"rhyme": { "name": "Xtratight", "hint": "a body almost a full tile wide threading one-tile corridors — the corner reads have no slack at all",
			"dials": { "body": 0.95, "map": ["##########", "#....#...#", "#.##.#.#.#", "#.#....#.#", "#.#.##.#.#", "#...#....#", "##########"] } } },
	{ "id": "oneway", "letter": "O", "name": "Oneway",
		"hint": "one-way platforms catch you only falling, and only if your feet were above the top last frame; down+jump ignores them for N frames (Platform) — press above to jump, below to drop",
		"dials": { "g": 2.4,             # gravity, ×H per second²
			"jumpH": 0.3,                # jump apex, ×H (Jump's √(2gh))
			"plats": 3,                  # how many ledges are stacked
			"gap": 0.2,                  # the vertical spacing, ×H
			"dropFrames": 8,             # frames the platforms are ignored after a drop
			"label": "land ⇔ vy > 0 ∧ feetLast ≤ top ∧ feet ≥ top ∧ drop = 0" },
		"rhyme": { "name": "Openair", "hint": "six thin ledges in a tall shaft under low gravity — the same last-frame test, hopped up and dropped down",
			"dials": { "plats": 6, "gap": 0.12, "g": 1.4 } } },
	{ "id": "oblique", "letter": "O", "name": "Oblique",
		"hint": "slopes: velocity is projected onto the ground's tangent; steeper than the limit and you slide (Normals, Avalanche) — press to set where it walks",
		"dials": { "maxAngle": 45,       # degrees: walkable up to here, sliding past it
			"speed": 0.3,                # walking speed along the tangent, ×W per second
			"slideG": 1.8,               # gravity along a too-steep slope, ×H per second²
			"friction": 2.5,             # how fast a slide dies on walkable ground, per second
			"hills": [[0, 0], [0.1, 0.02], [0.24, 0.2], [0.36, 0.22], [0.46, 0.06], [0.55, 0.08], [0.62, 0.4], [0.7, 0.42], [0.82, 0.16], [0.92, 0.17], [1, 0.02]],
			"label": "v = (v·t̂)·t̂ · θ = acos(n·up) · slide ⇔ θ > max" },
		"rhyme": { "name": "Overhang", "hint": "a 25° limit on ice — nearly every hill is too steep, and a slide takes forever to die",
			"dials": { "maxAngle": 25, "friction": 0.4, "slideG": 1.2 } } },
	{ "id": "kerb", "letter": "K", "name": "Kerb", "drag": true,
		"hint": "step-up: a foot ray blocked while the knee ray is clear means lift the body over the step; too tall and it is refused — drag to scale the risers",
		"dials": { "riser": 1,           # the stair scale a drag scrubs (0.5 .. 1.6)
			"base": 0.016,               # the first riser's height, ×H; the i-th is i times that
			"knee": 0.075,               # knee height, ×H: the tallest step that can be climbed
			"steps": 5,                  # how many risers
			"tread": 0.1,                # each tread's depth, ×W
			"speed": 0.28,               # walking speed, ×W per second
			"probe": 6,                  # how far ahead the two rays look, px past the body
			"label": "foot ray hits ∧ knee ray clear ⇒ y = top · else blocked" },
		"rhyme": { "name": "Kneehigh", "hint": "a taller knee climbs taller steps — the same two rays, only the second one is cast higher",
			"dials": { "knee": 0.11, "base": 0.02 } } },
	{ "id": "whiskers", "letter": "W", "name": "Whiskers",
		"hint": "a bundle of short rays — two down, left, right, up — with a tolerance lights the onFloor / onWall / onCeiling lamps (Xmarks, Ninja) — press to send it",
		"dials": { "len": 0.05,          # whisker length past the body, ×H
			"tol": 0.012,                # the extra grace added to every whisker, ×H
			"g": 2.2,                    # gravity, ×H per second²
			"jumpH": 0.24,               # jump apex, ×H
			"run": 0.35,                 # run speed, ×W per second
			"slideCap": 0.14,            # wall-slide fall cap, ×H per second
			"cling": 0.35,               # seconds on a wall before it kicks off
			"label": "onFloor ⇔ ray↓ hit ≤ len + tol · lamps = verbs" },
		"rhyme": { "name": "Wide", "hint": "whiskers three times as long with a floaty tolerance — the floor lamp lights well before the feet arrive",
			"dials": { "len": 0.14, "tol": 0.04, "jumpH": 0.3 } } },
	{ "id": "quadtree", "letter": "Q", "name": "Quadtree",
		"hint": "broad phase: a spatial hash puts every body in a grid cell, and only neighbours in the same or adjacent cells are tested (Swarm's crowd) — press to add a body",
		"dials": { "n": 40,              # bodies at the start
			"cell": 0.1,                 # cell size, ×W
			"r": 4,                      # body radius, px
			"speed": 0.22,               # their speed, ×W per second
			"label": "cell = ⌊x/s⌋ + ⌊y/s⌋·cols · test the 3×3 only" },
		"rhyme": { "name": "Quorum", "hint": "three times the bodies, smaller and in bigger cells — more pairs per cell, still a fraction of all-pairs",
			"dials": { "n": 120, "cell": 0.14, "r": 3 } } },
	{ "id": "volume", "letter": "V", "name": "Volume",
		"hint": "trigger volumes overlap without pushing back; a wasInside flag turns that into ENTER / STAY / EXIT events (Zones) — press to send the mote",
		"dials": { "speed": 0.22,        # the mote's speed, ×W per second
			"log": 6,                    # lines of the event ticker
			"show": "rcs",               # which zones exist: r rect, c circle, s sector
			"rect": [0.06, 0.12, 0.26, 0.3],            # x, y, w, h — ×W, ×H
			"circle": [0.7, 0.66, 0.13],                # cx, cy — ×W, ×H; r ×W
			"sector": [0.42, 0.9, 0.3, -2.6, -1.1],     # cx, cy, r, a0, a1 (radians)
			"label": "enter = in∧¬was · stay = in∧was · exit = ¬in∧was" },
		"rhyme": { "name": "Vast", "hint": "one enormous circle and a slow mote — enter and exit are rare; the stay timer is the whole story",
			"dials": { "show": "c", "circle": [0.5, 0.5, 0.36], "speed": 0.07 } } },
	{ "id": "iframes", "letter": "I", "name": "Iframes",
		"hint": "hitbox vs hurtbox: the swing's hitbox exists only on its active frames, and the hurtbox switches off during i-frames after a hit (Hitstop) — press to swing",
		"dials": { "swing": 24,          # frames in a whole swing, at 60 per second
			"active": [8, 13],           # the frames the hitbox exists (inclusive)
			"iframes": 40,               # invincibility frames after a hit
			"every": 2.0,                # the autopilot swings this often, seconds
			"reach": 0.2,                # the hitbox's reach, ×W
			"label": "hit ⇔ frame ∈ active ∧ hitbox ∩ hurtbox ∧ ¬invincible" },
		"rhyme": { "name": "Invincible", "hint": "a two-frame active window against a long invulnerability — swings come often and hits almost never land",
			"dials": { "active": [10, 11], "iframes": 150, "every": 1.2 } } },
	{ "id": "elastic", "letter": "E", "name": "Elastic",
		"hint": "elastic collision: two balls trade velocity along the line between centres, scaled by mass and restitution e (Newton's cradle, in 2D) — press to cue the mote",
		"dials": { "balls": 2,           # balls on the table (the mote is the first)
			"e": 0.85,                   # restitution: 1 is a perfect bounce, 0 is clay
			"m": [1, 2.5, 1, 1, 1],      # masses; radius grows with √m
			"cue": 0.75,                 # cue speed, ×W per second
			"friction": 0.5,             # rolling friction, per second
			"r": 8,                      # the unit ball's radius, px
			"label": "j = −(1+e)(vᵣ·n)/(1/m₁+1/m₂) · v ± j·n/m" },
		"rhyme": { "name": "Eightball", "hint": "five equal balls at e 0.98 — the rack splits and the impulse passes down the line almost undiminished",
			"dials": { "balls": 5, "e": 0.98, "m": [1, 1, 1, 1, 1] } } },
	{ "id": "obb", "letter": "O", "name": "Obb",
		"hint": "SAT for rotated rectangles: project both onto every edge normal — a gap on any axis means no collision (Ragdoll's crate, spun) — press to spin the crate",
		"dials": { "spin": 0.5,          # the crate's idle turn, radians per second
			"w": 0.2, "h": 0.12,         # the crates' sides, ×W
			"drift": 0.11,               # how fast the blue crate drifts in and out, cycles per second
			"kick": 4,                   # radians per second a press adds
			"label": "SAT: project onto each edge normal · a gap ⇒ apart" },
		"rhyme": { "name": "Obtuse", "hint": "two long thin planks turning slowly — the shadows are long on one axis and slivers on the other, and the gap flickers open and shut",
			"dials": { "w": 0.34, "h": 0.04, "spin": 0.2 } } },
]

const FAINT := Color(0.91, 0.898, 0.957, 0.55)   # the web label's default ink
const BODY_R := 8.0                                # the mote's radius on the platformer cards
const QT_NB := [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)]   # half the 3×3: every pair once
const OBB_NAMES := ["A₁", "A₂", "B₁", "B₂"]

## A number for a label: "1" for whole values, "0.25" otherwise (JS's "" + k).
static func _num(v: float) -> String:
	return ("%d" % roundi(v)) if v == roundf(v) else ("%s" % v)

## The web label's "right" alignment: measure, then draw ending at p.x.
static func _label_right(n: CanvasItem, b: Dictionary, txt: String, p: Vector2, col: Color) -> void:
	var f := ThemeDB.fallback_font
	var w: float = f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	Kit.label(n, b, txt, Vector2(p.x - w, p.y), col)

## The web label with a runtime alignment ("left" / "right" / "center").
static func _lab(n: CanvasItem, b: Dictionary, txt: String, p: Vector2, col: Color, align: String) -> void:
	match align:
		"right":
			_label_right(n, b, txt, p, col)
		"center":
			Kit.label(n, b, txt, p, col, true)
		_:
			Kit.label(n, b, txt, p, col)

## ctx.strokeRect: an outlined rectangle.
static func _srect(n: CanvasItem, r: Rect2, col: Color, w: float) -> void:
	n.draw_rect(r, col, false, w)

## ctx.setLineDash + strokeRect: four dashed edges.
static func _dash_rect(n: CanvasItem, r: Rect2, col: Color, w: float, dash: float) -> void:
	var p0 := r.position
	var p1 := r.position + Vector2(r.size.x, 0.0)
	var p2 := r.end
	var p3 := r.position + Vector2(0.0, r.size.y)
	n.draw_dashed_line(p0, p1, col, w, dash)
	n.draw_dashed_line(p1, p2, col, w, dash)
	n.draw_dashed_line(p2, p3, col, w, dash)
	n.draw_dashed_line(p3, p0, col, w, dash)

## wrapAngle: into −π..π.
static func _wrap(a: float) -> float:
	return fposmod(a + PI, TAU) - PI

## Tunnel's number format: infinities for the parallel axis.
static func _fmt(v: float) -> String:
	if v > 99.0:
		return "+∞"
	if v < -99.0:
		return "−∞"
	return "%.2f" % v

static func _cross(o: Vector2, a: Vector2, c: Vector2) -> float:
	return (a.x - o.x) * (c.y - o.y) - (a.y - o.y) * (c.x - o.x)

## Tunnel's convex hull of eight points at most: a tiny monotone chain.
static func _hull(src: Array) -> PackedVector2Array:
	src.sort_custom(func(p: Vector2, q: Vector2) -> bool: return p.x < q.x or (p.x == q.x and p.y < q.y))
	var out: Array = []
	for p in src:
		while out.size() >= 2 and _cross(out[out.size() - 2], out[out.size() - 1], p) <= 0.0:
			out.pop_back()
		out.append(p)
	var lo := out.size() + 1
	for i in range(src.size() - 2, -1, -1):
		var p: Vector2 = src[i]
		while out.size() >= lo and _cross(out[out.size() - 2], out[out.size() - 1], p) <= 0.0:
			out.pop_back()
		out.append(p)
	out.pop_back()
	return PackedVector2Array(out)

## Tunnel's swept test: the wall grown by the box's half size = a ray test.
static func _tunnel_sweep(b: Dictionary, cx: float, cy: float, hw: float, hh: float, X0: float, X1: float, Y0: float, Y1: float) -> void:
	var S: Dictionary = b.S
	var dx: float = b.dx
	var dy: float = b.dy
	X0 -= hw
	X1 += hw
	Y0 -= hh
	Y1 += hh
	if absf(dx) < 1e-6:
		if cx < X0 or cx > X1:
			S.tx1 = 1e9
			S.tx2 = -1e9
		else:
			S.tx1 = -1e9
			S.tx2 = 1e9
	else:
		S.tx1 = (X0 - cx) / dx
		S.tx2 = (X1 - cx) / dx
		if S.tx1 > S.tx2:
			var sw: float = S.tx1
			S.tx1 = S.tx2
			S.tx2 = sw
	if absf(dy) < 1e-6:
		if cy < Y0 or cy > Y1:
			S.ty1 = 1e9
			S.ty2 = -1e9
		else:
			S.ty1 = -1e9
			S.ty2 = 1e9
	else:
		S.ty1 = (Y0 - cy) / dy
		S.ty2 = (Y1 - cy) / dy
		if S.ty1 > S.ty2:
			var sw: float = S.ty1
			S.ty1 = S.ty2
			S.ty2 = sw
	S.entry = maxf(S.tx1, S.ty1)
	S.exit = minf(S.tx2, S.ty2)
	S.hit = S.entry <= S.exit and S.entry >= 0.0 and S.entry <= 1.0
	# (the ±1e9 sentinels never leave S: entry/exit are clamped by the
	# min/max, and the family check only sees the values stored here — so
	# keep S's infinities at ±1e5, safely "infinite" for a 0..1 window)
	for key in ["tx1", "tx2", "ty1", "ty2", "entry", "exit"]:
		S[key] = clampf(S[key], -1e5, 1e5)

## Tunnel's fire: from the launcher toward (tx, ty), one step per frame.
static func _tunnel_fire(b: Dictionary, tx: float, ty: float) -> void:
	var D: Dictionary = b.D
	b.bx = b.w * 0.1
	b.nx = b.bx
	b.by = b.h * 0.5
	b.ny = b.by
	var ex: float = tx - b.bx
	var ey: float = ty - b.by
	var d := sqrt(ex * ex + ey * ey)
	if d == 0.0:
		d = 1.0
	var step: float = b.w * D.speed * D.stepDt
	b.dx = ex / d * step
	b.dy = ey / d * step
	b.k = 0.0
	b.stopped = false
	b.holdT = 0.0
	b.ghostOn = true
	b.tunnelled = false
	b.aim = atan2(ey, ex)

## Xaxis: is this tile a wall? (outside the map counts as one)
static func _solid(map: Array, cx: int, cy: int) -> bool:
	if cx < 0 or cy < 0 or cy >= map.size():
		return true
	var row: String = map[cy]
	if cx >= row.length():
		return true
	return row[cx] == "#"

## Xaxis: the four tiles under the body's corners, from its current px, py.
static func _xa_corners(b: Dictionary, into: Array) -> void:
	var ts: float = b.ts
	var bw: float = b.bw
	var cx0 := int(floorf((b.px + 0.5 - b.gx0) / ts))
	var cx1 := int(floorf((b.px + bw - 0.5 - b.gx0) / ts))
	var cy0 := int(floorf((b.py + 0.5 - b.gy0) / ts))
	var cy1 := int(floorf((b.py + bw - 0.5 - b.gy0) / ts))
	into[0] = Vector2i(cx0, cy0)
	into[1] = Vector2i(cx1, cy0)
	into[2] = Vector2i(cx0, cy1)
	into[3] = Vector2i(cx1, cy1)

## Xaxis: a random empty tile to walk to.
static func _xa_new_target(b: Dictionary) -> void:
	var map: Array = b.D.map
	var cols: int = b.cols
	var rows: int = b.rows
	var ts: float = b.ts
	var bw: float = b.bw
	for _tries in 20:
		var cx := int(floorf(randf_range(1.0, cols - 1.0)))
		var cy := int(floorf(randf_range(1.0, rows - 1.0)))
		if not _solid(map, cx, cy):
			b.tx = b.gx0 + cx * ts + (ts - bw) / 2.0
			b.ty = b.gy0 + cy * ts + (ts - bw) / 2.0
			return

## Oneway: the i-th ledge's top. standing: −2 airborne, −1 the floor, i a ledge.
static func _ow_top(b: Dictionary, i: int) -> float:
	return b.gy - (i + 1) * float(b.D.gap) * b.h

static func _ow_jump(b: Dictionary) -> void:
	if b.standing == -2:
		return
	var D: Dictionary = b.D
	var G: float = b.h * D.g
	b.vy = -sqrt(2.0 * G * b.h * D.jumpH)
	b.standing = -2

static func _ow_drop(b: Dictionary) -> void:
	if b.standing == -2 or b.standing < 0:
		return
	b.dropN = int(b.D.dropFrames)
	b.standing = -2
	b.y += 1.0
	b.vy = 0.0

## Oblique: the ground under x — height, tangent, normal (pointing up), slope angle.
static func _terrain(pts: Array, x: float) -> Dictionary:
	var i := 0
	while i < pts.size() - 2 and (pts[i + 1] as Vector2).x < x:
		i += 1
	var a: Vector2 = pts[i]
	var c: Vector2 = pts[i + 1]
	var dx := c.x - a.x
	var dy := c.y - a.y
	var d := sqrt(dx * dx + dy * dy)
	if d == 0.0:
		d = 1.0
	var k := clampf((x - a.x) / (dx if dx != 0.0 else 1.0), 0.0, 1.0)
	var tx := dx / d
	var ty := dy / d
	var nx := ty                                     # the tangent turned to point up
	var ny := -tx
	if ny > 0.0:
		nx = -nx
		ny = -ny
	return { "y": a.y + dy * k, "tx": tx, "ty": ty, "nx": nx, "ny": ny,
		"th": acos(clampf(-ny, -1.0, 1.0)) * 180.0 / PI }

## Kerb: the stairs — the i-th riser's x, its height, and the surface under px.
static func _kb_stepx(b: Dictionary, i: int) -> float:
	return b.w * 0.3 + i * float(b.D.tread) * b.w

static func _kb_steph(b: Dictionary, i: int) -> float:
	return float(b.D.base) * b.h * b.riser * (i + 1)

static func _kb_surf(b: Dictionary, px: float) -> float:
	var sfc: float = b.gy
	for i in int(b.D.steps):
		if px >= _kb_stepx(b, i):
			sfc -= _kb_steph(b, i)
	return sfc

## Kerb: the two rays, cast from the body as it stands now (kept for draw).
static func _kb_probe(b: Dictionary) -> void:
	var D: Dictionary = b.D
	b.kneeY = b.y - D.knee * b.h
	b.footY = b.y - 2.0
	b.ahead = b.x + b.dir * (BODY_R + D.probe)
	b.sAhead = _kb_surf(b, b.ahead)
	b.footHit = b.dir > 0 and b.sAhead < b.footY
	b.kneeHit = b.dir > 0 and b.sAhead < b.kneeY

## Whiskers: an axis ray against axis-aligned solids.
static func _wk_cast(b: Dictionary, r: Dictionary) -> void:
	var D: Dictionary = b.D
	var best := 1e9
	for sq in b.solids:
		var sr: Rect2 = sq
		if r.dx == 0.0:
			if r.ox < sr.position.x or r.ox > sr.end.x:
				continue
			var d: float = (sr.position.y - r.oy) if r.dy > 0.0 else (r.oy - sr.end.y)
			if d >= -0.5 and d < best:
				best = d
		else:
			if r.oy < sr.position.y or r.oy > sr.end.y:
				continue
			var d: float = (sr.position.x - r.ox) if r.dx > 0.0 else (r.ox - sr.end.x)
			if d >= -0.5 and d < best:
				best = d
	r.d = minf(maxf(0.0, best), b.h * 4.0)          # capped: a miss is "far", not infinite
	r.hit = best <= (D.len + D.tol) * b.h

static func _wk_jump(b: Dictionary) -> void:
	var D: Dictionary = b.D
	b.vy = -sqrt(2.0 * b.h * D.g * b.h * D.jumpH)

## Quadtree: one more body, heading a random way (200 at most).
static func _qt_add(b: Dictionary, x: float, y: float) -> void:
	var bodies: Array = b.bodies
	if bodies.size() >= 200:
		return
	var a := randf_range(0.0, 6.283)
	var sp: float = b.w * b.D.speed
	bodies.append({ "x": x, "y": y, "vx": cos(a) * sp, "vy": sin(a) * sp, "hot": 0.0, "cx": 0, "cy": 0 })

## Volume: the inside test for one zone — a rect, a circle, or a sector.
static func _vol_inside(b: Dictionary, z: Dictionary) -> bool:
	var D: Dictionary = b.D
	var W: float = b.w
	var H: float = b.h
	var x: float = b.x
	var y: float = b.y
	if z.kind == "rect":
		var r: Array = D.rect
		return x > float(r[0]) * W and x < (float(r[0]) + float(r[2])) * W and y > float(r[1]) * H and y < (float(r[1]) + float(r[3])) * H
	if z.kind == "circle":
		var c: Array = D.circle
		return Vector2(x - float(c[0]) * W, y - float(c[1]) * H).length() < float(c[2]) * W
	var sc: Array = D.sector
	var dx := x - float(sc[0]) * W
	var dy := y - float(sc[1]) * H
	if sqrt(dx * dx + dy * dy) > float(sc[2]) * W:
		return false
	var mid := (float(sc[3]) + float(sc[4])) / 2.0
	var half := absf(float(sc[4]) - float(sc[3])) / 2.0
	return absf(_wrap(atan2(dy, dx) - mid)) < half

## Volume: one line on the event ticker.
static func _vol_post(b: Dictionary, txt: String, col: Color) -> void:
	var logs: Array = b.logs
	logs.append({ "txt": txt, "c": col, "t": b.now })
	if logs.size() > int(b.D.log):
		logs.pop_front()

## Iframes: start a swing, unless one is already in the air.
static func _if_swing(b: Dictionary) -> void:
	if b.swingF < float(b.D.swing):
		return
	b.swingF = 0.0
	b.hitThis = false

## Elastic: send the mote toward (px, py) at cue speed.
static func _el_cue(b: Dictionary, px: float, py: float) -> void:
	var ball: Dictionary = b.balls[0]
	var dx: float = px - ball.x
	var dy: float = py - ball.y
	var d := sqrt(dx * dx + dy * dy)
	if d == 0.0:
		d = 1.0
	var v: float = b.w * b.D.cue
	ball.vx = dx / d * v
	ball.vy = dy / d * v

## Obb: a rotated rectangle's four corners.
static func _obb_corners(bx: Dictionary, out: Array) -> void:
	var c: float = cos(bx.a)
	var sn: float = sin(bx.a)
	var ex := Vector2(c * bx.hw, sn * bx.hw)
	var ey := Vector2(-sn * bx.hh, c * bx.hh)
	var p := Vector2(bx.x, bx.y)
	out[0] = p - ex - ey
	out[1] = p + ex - ey
	out[2] = p + ex + ey
	out[3] = p - ex + ey

## Obb: the shadow of four corners on an axis — (lo, hi).
static func _obb_project(pts: Array, ax: Vector2) -> Vector2:
	var lo := 1e9
	var hi := -1e9
	for p in pts:
		var v: float = (p as Vector2).dot(ax)
		if v < lo:
			lo = v
		if v > hi:
			hi = v
	return Vector2(lo, hi)

## Whiskers: place the five rays on the body as it stands now, cast them,
## and light the lamps (used by init so the first draw has whiskers too).
static func _wk_sense(b: Dictionary) -> void:
	var rays: Array = b.rays
	var x: float = b.x
	var y: float = b.y
	var r0: Dictionary = rays[0]
	var r1: Dictionary = rays[1]
	var r2: Dictionary = rays[2]
	var r3: Dictionary = rays[3]
	var r4: Dictionary = rays[4]
	r0.ox = x - BODY_R * 0.7
	r0.oy = y + BODY_R
	r1.ox = x + BODY_R * 0.7
	r1.oy = y + BODY_R
	r2.ox = x - BODY_R
	r2.oy = y
	r3.ox = x + BODY_R
	r3.oy = y
	r4.ox = x
	r4.oy = y - BODY_R
	for r in rays:
		_wk_cast(b, r)
	b.onFloor = r0.hit or r1.hit
	b.onWall = -1 if r2.hit else (1 if r3.hit else 0)
	b.onCeil = r4.hit

static func init(b: Dictionary) -> void:
	var D: Dictionary = b.D
	var W: float = b.w
	var H: float = b.h
	var GY: float = b.gy
	match b.id:
		"aabb":
			# an AABB (axis-aligned bounding box) is four numbers: left, right, top,
			# bottom. two of them OVERLAP only when all four edge tests pass — A's
			# left is before B's right, A's right is past B's left, and the same up
			# and down. one failing test is a gap, and a gap anywhere means no touch.
			# to RESOLVE, measure how deep the boxes sit on each axis and push out
			# along the shallower one — LEAST PENETRATION — so a box clipping the
			# corner of a floor slides up onto it instead of sideways off it.
			var sr := Kit.rng(11)
			b.crates = []
			for _i in int(D.crates):
				b.crates.append(Vector2(W * (0.28 + sr.randf() * 0.44), H * (0.22 + sr.randf() * 0.5)))
			b.placeI = 0
			b.tests = [false, false, false, false]
			b.focus = -1
			b.hit = false
			b.px = 0.0
			b.py = 0.0
			b.ax = W / 2.0
			b.ay = H / 2.0
			b.rawX = b.ax
			b.rawY = b.ay
		"overlap":
			# the two cheapest tests in the book. CIRCLE vs CIRCLE: measure the gap
			# between centres, and if it is less than the radii added together they
			# overlap — push each away by half the difference. CIRCLE vs RECTANGLE:
			# clamp the circle's centre into the box; that clamped point is the
			# NEAREST POINT of the box, and the circle touches if it is closer than
			# the radius. the push is along the line from that point to the centre.
			b.rx = W * 0.5
			b.ry = H * 0.5
			b.c = []
			for _i in 2:
				b.c.append({ "x": 0.0, "y": 0.0, "ox": 0.0, "oy": 0.0, "mx": 0.0, "my": 0.0, "r": 1.0,
					"px": 0.0, "py": 0.0, "d": 0.0, "touch": false, "inRect": false })
			b.cc = false
			b.dcc = 0.0
			b.sum = 0.0
			b.hits = 0
		"tunnel":
			# TUNNELLING: a body that moves further in one frame than a wall is thick
			# can be on one side this frame and the other side next frame, and a
			# simple overlap test never sees the wall. the SWEPT test asks instead:
			# along this frame's displacement d, WHEN does the box enter the wall?
			# per axis, (wallEdge − boxEdge)/d gives an entry and an exit time; the
			# box is inside the wall only while BOTH axes agree — from the later
			# entry to the earlier exit. if that window sits inside 0..1, the box
			# stops at the entry time, however fast it was going.
			b.S = { "tx1": 0.0, "tx2": 0.0, "ty1": 0.0, "ty2": 0.0, "entry": 0.0, "exit": 0.0, "hit": false }
			_tunnel_fire(b, W * 0.9, H * randf_range(0.3, 0.7))
		"xaxis":
			# the tilemap trick every 2D platformer shares: never move diagonally in
			# one go. move on X alone, read the tiles under the body's four CORNERS,
			# and if any is a wall push the body flush with that wall's face; then do
			# exactly the same on Y. because each axis is resolved by itself the body
			# SLIDES along walls for free, and a corner never wedges. the amber
			# squares are the corners read during the x pass, the green ones during
			# the y pass; a tile flashes red when it pushed.
			var map: Array = D.map
			var rows: int = map.size()
			var cols: int = (map[0] as String).length()
			var ts: float = minf(W / cols, (H - 22.0) / rows)
			b.rows = rows
			b.cols = cols
			b.ts = ts
			b.gx0 = (W - cols * ts) / 2.0
			b.gy0 = (H - 22.0 - rows * ts) / 2.0 + 2.0
			var bw: float = ts * D.body
			b.bw = bw
			b.px = b.gx0 + ts + (ts - bw) / 2.0
			b.py = b.gy0 + ts + (ts - bw) / 2.0
			b.tx = b.px
			b.ty = b.py
			b.autoT = 0.0
			b.stuckT = 0.0
			b.hitX = 0.0
			b.hitY = 0.0
			b.xs = [Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO]
			b.ys = [Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO, Vector2i.ZERO]
			b.hx = Vector2i.ZERO
			b.hy = Vector2i.ZERO
			b.vx = 0.0
			b.vy = 0.0
			_xa_new_target(b)
		"oneway":
			# a ONE-WAY platform is a floor with a memory. it is solid only when the
			# body is moving DOWN, and only if the feet were AT OR ABOVE its top on
			# the previous frame — so a jump from below passes straight through and
			# is caught on the way back. dropping through is the same rule with an
			# exception: for a handful of frames after down+jump the platforms are
			# not consulted at all. the dashed line is where the feet were last frame;
			# the lamps are the four tests against the ledge just below them.
			b.x = W / 2.0
			b.y = GY - BODY_R
			b.vy = 0.0
			b.feetLast = GY
			b.feetShown = GY
			b.standing = -1                              # −2 airborne, −1 the floor, i a ledge
			b.dropN = 0
			b.autoT = 0.5
			b.climbing = true
			b.lampV = false
			b.lampLast = false
			b.lampFeet = false
			b.lampDrop = true
			b.tested = -1
		"oblique":
			# a SLOPE is a floor whose normal is not straight up. the body's speed is
			# kept along the surface's TANGENT (the normal turned 90°), so walking up
			# a hill is the same code as walking on the flat, only tilted; the angle
			# between the normal and up is the slope angle θ. past a MAX ANGLE the
			# ground refuses to be a floor: input is ignored and gravity's component
			# along the tangent, g·sin θ, drags the body downhill — the slide. the
			# dashed cone at the foot is the allowed range of normals.
			var pts: Array = []
			for hill in D.hills:
				var hh: Array = hill
				pts.append(Vector2(float(hh[0]) * W, GY - float(hh[1]) * H))
			b.pts = pts
			var fill: Array = pts.duplicate()
			fill.append(Vector2(W, H))
			fill.append(Vector2(0.0, H))
			b.fill = fill
			b.x = W * 0.05
			b.sp = 0.0
			b.tx = W * 0.4
			b.autoT = 0.0
			b.seg = _terrain(pts, b.x)
			b.walkable = true
		"kerb":
			# stairs would stop a box dead: the riser is a wall. STEP-UP is two short
			# rays cast forward — one at the feet, one at KNEE HEIGHT. if the foot
			# ray hits something and the knee ray sails over it, the obstacle is a
			# step, not a wall: lift the body to the top and walk on. if both rays
			# hit, it is a wall — refused. the knee height is the whole design dial:
			# it is why a hero climbs kerbs but not crates.
			b.riser = float(D.riser)
			b.x = W * 0.08
			b.dir = 1.0
			b.y = GY
			b.blockT = 0.0
			b.lift = 0.0
			b.liftY = 0.0
			b.refused = -1
			_kb_probe(b)
		"whiskers":
			# a character controller rarely asks "am I overlapping?" — it asks "is
			# there floor just under my feet?" WHISKERS are short rays cast from the
			# body's edges: two down (so one foot on a ledge still counts), one each
			# way, one up. a hit within the whisker's length plus a TOLERANCE sets a
			# flag, and the flags are the grammar: onFloor lets you jump, onWall lets
			# you slide and kick off, onCeiling ends a jump early. longer whiskers
			# mean earlier detection — the lamps light before the body touches.
			var roomL: float = W * 0.08
			var roomR: float = W * 0.92
			var ceilY: float = H * 0.12
			b.roomL = roomL
			b.roomR = roomR
			b.ceilY = ceilY
			b.solids = [Rect2(0.0, 0.0, W, ceilY), Rect2(0.0, 0.0, roomL, H), Rect2(roomR, 0.0, W - roomR, H),
				Rect2(0.0, GY, W, H - GY), Rect2(W * 0.4, GY - H * 0.22, W * 0.2, H * 0.06)]
			b.x = W * 0.3
			b.y = GY - BODY_R
			b.vx = 0.0
			b.vy = 0.0
			b.tx = W * 0.7
			b.ty = GY - BODY_R
			b.autoT = 0.0
			b.wallT = 0.0
			b.rays = []
			for dirv in [Vector2(0.0, 1.0), Vector2(0.0, 1.0), Vector2(-1.0, 0.0), Vector2(1.0, 0.0), Vector2(0.0, -1.0)]:
				var dv: Vector2 = dirv
				b.rays.append({ "ox": 0.0, "oy": 0.0, "dx": dv.x, "dy": dv.y, "d": 0.0, "hit": false })
			_wk_sense(b)
		"quadtree":
			# testing every pair is n(n−1)/2 tests — 40 bodies is 780, 400 bodies is
			# 79,800. the BROAD PHASE cuts that by asking "who could possibly touch?"
			# first. a SPATIAL HASH drops each body into a grid cell by integer
			# division of its position; a body can only touch bodies in its own cell
			# or the eight around it, so those are the only pairs the exact test ever
			# sees. the grey lines are the pairs actually tested this frame; the
			# count at the top is the saving. a quadtree is the same idea with cells
			# that split where it is crowded.
			var sr := Kit.rng(5)
			var cs: float = W * D.cell
			var cols: int = maxi(1, ceili(W / cs))
			var rows: int = maxi(1, ceili(H / cs))
			b.cs = cs
			b.cols = cols
			b.rows = rows
			b.buckets = []
			for _i in cols * rows:
				b.buckets.append([])
			b.bodies = []
			var r: float = D.r
			for _i in int(D.n):
				_qt_add(b, r + sr.randf() * (W - 2.0 * r), r + sr.randf() * (H - 24.0 - 2.0 * r))
			b.tests = 0
			b.lines = PackedVector2Array()
		"volume":
			# a TRIGGER is a collider that never pushes: it only knows whether you are
			# inside. the whole event system is one remembered bit per zone,
			# wasInside — compare it with this frame's answer and you get ENTER (in,
			# wasn't), STAY (in, was) and EXIT (not in, was). the inside test itself
			# is the cheapest shape test you have: a rect, a circle, a sector (a
			# circle plus an angle check). doors, checkpoints, ambushes and music
			# changes are all this card.
			var show: String = D.show
			b.zones = []
			for kind in ["rect", "circle", "sector"]:
				var kd: String = kind
				if show.contains(kd.substr(0, 1)):
					b.zones.append({ "kind": kd, "name": kd, "was": false, "stay": 0.0, "inn": false })
			b.logs = []
			b.x = W * 0.5
			b.y = H * 0.7
			b.tx = W * 0.2
			b.ty = H * 0.35
			b.autoT = 0.0
			b.now = 0.0
			b.ex = 0.0
			b.ey = 0.0
		"iframes":
			# fighting games count in FRAMES. a swing is a little timeline: startup,
			# a few ACTIVE frames when the HITBOX (red) actually exists, then
			# recovery. the defender carries a HURTBOX (blue); a hit is a box overlap
			# on an active frame — nothing else counts. after a hit the hurtbox is
			# switched off for a run of I-FRAMES (the flicker), so one swing cannot
			# land twice and a fallen fighter gets up unmolested. the strip at the
			# top is the swing's timeline; the bar under the defender is the i-frame
			# countdown.
			b.ax = W * 0.3
			b.swingF = 1.0e4                             # "no swing yet" (the web's 1e9, kept small for the runaway guard)
			b.invF = 0.0
			b.autoT = 1.0
			b.hits = 0
			b.whiffs = 0
			b.hitThis = false
			b.flash = 0.0
			b.fx = 0.0
			b.fy = 0.0
			b.note = ""
			b.noteT = 0.0
			b.f = 0
			b.swinging = false
			b.activeNow = false
			b.dx = W * 0.58
			b.dy = GY - BODY_R
			b.hb = Rect2(b.ax + BODY_R, GY - BODY_R * 2.6, W * D.reach, BODY_R * 2.6)
			b.ub = Rect2(b.dx - BODY_R * 1.2, b.dy - BODY_R * 1.3, BODY_R * 2.4, BODY_R * 2.6)
		"elastic":
			# when two round things collide, only the velocity ALONG THE NORMAL (the
			# line between centres) changes; the sideways part is untouched, which is
			# why a glancing shot barely deflects. the IMPULSE j is one number: the
			# approach speed along the normal, times (1 + e), divided by the sum of
			# inverse masses. each ball gets j over its own mass — the heavy one
			# barely moves, the light one flies. the frozen overlay shows the last
			# hit: faint arrows before, solid arrows after, the normal in bone.
			var tx0: float = W * 0.06
			var ty0: float = H * 0.1
			var tw: float = W * 0.88
			var th: float = H * 0.7
			b.tx0 = tx0
			b.ty0 = ty0
			b.tw = tw
			b.th = th
			var ms: Array = D.m
			var unit: float = D.r
			b.balls = []
			for i in mini(int(D.balls), ms.size()):
				var m: float = ms[i]
				var r: float = unit * sqrt(m)
				var x: float = tx0 + tw * 0.68
				var y: float = ty0 + th / 2.0
				if i == 0:
					x = tx0 + tw * 0.25
				else:
					var row: int = 0 if i == 1 else (1 if i <= 3 else 2)
					var col: int = 0 if i == 1 else (i - 2) % 2
					x += row * r * 2.2
					y += (col - 0.5) * r * 2.4 * (1.0 if row > 0 else 0.0)
				b.balls.append({ "x": x, "y": y, "vx": 0.0, "vy": 0.0, "m": m, "r": r })
			b.last = { "on": 0.0, "x": 0.0, "y": 0.0, "nx": 0.0, "ny": 0.0, "a": -1, "b": -1,
				"a1x": 0.0, "a1y": 0.0, "b1x": 0.0, "b1y": 0.0, "a2x": 0.0, "a2y": 0.0, "b2x": 0.0, "b2y": 0.0, "j": 0.0 }
			b.restT = 0.0
		"obb":
			# the SEPARATING AXIS THEOREM: two convex shapes are apart if and only if
			# there is some direction along which their shadows do not overlap. for
			# two rectangles you only have to try four directions — the edge normals
			# of both — so the test is four projections. cast every corner onto an
			# axis (a dot product), keep the min and max, and compare the two
			# intervals: the rulers at the bottom are those shadows. one gap (green)
			# and you are done; no gap on any axis and the smallest overlap is the
			# push that separates them — the MTV.
			b.A = { "x": W * 0.36, "y": H * 0.4, "a": 0.0, "hw": 1.0, "hh": 1.0 }
			b.B = { "x": W * 0.66, "y": H * 0.4, "a": 0.4, "hw": 1.0, "hh": 1.0 }
			b.cA = [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
			b.cB = [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
			b.cR = [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
			b.axes = [Vector2.RIGHT, Vector2.DOWN, Vector2.RIGHT, Vector2.DOWN]
			b.iv = [[0.0, 0.0, 0.0, 0.0], [0.0, 0.0, 0.0, 0.0], [0.0, 0.0, 0.0, 0.0], [0.0, 0.0, 0.0, 0.0]]
			b.angA = 0.0
			b.kick = 0.0
			b.rawX = b.A.x
			b.rawY = b.A.y
			b.sep = -1
			b.mtv = -1
			b.mtvOv = 0.0
			b.colliding = false

static func press(b: Dictionary, pos: Vector2) -> void:
	var D: Dictionary = b.D
	var W: float = b.w
	var GY: float = b.gy
	match b.id:
		"aabb":
			var crates: Array = b.crates
			crates[b.placeI % crates.size()] = pos
			b.placeI += 1
		"overlap":
			b.rx = pos.x
			b.ry = pos.y
		"tunnel":
			_tunnel_fire(b, pos.x, pos.y)
		"xaxis":
			var bw: float = b.bw
			var ts: float = b.ts
			b.tx = clampf(pos.x - bw / 2.0, b.gx0, b.gx0 + b.cols * ts - bw)
			b.ty = clampf(pos.y - bw / 2.0, b.gy0, b.gy0 + b.rows * ts - bw)
			b.autoT = -4.0
		"oneway":
			if pos.y < b.y:
				_ow_jump(b)
			else:
				_ow_drop(b)
			b.autoT = -3.0
		"oblique":
			b.tx = clampf(pos.x, W * 0.03, W * 0.97)
			b.autoT = -5.0
		"kerb":
			var r := lerpf(0.5, 1.6, clampf(pos.x / W, 0.0, 1.0))
			if absf(r - b.riser) > 0.01:
				b.riser = r
				b.x = W * 0.08
				b.dir = 1.0
				b.y = GY
				b.blockT = 0.0
				b.refused = -1
		"whiskers":
			b.tx = clampf(pos.x, b.roomL + BODY_R, b.roomR - BODY_R)
			b.ty = clampf(pos.y, b.ceilY + BODY_R, GY - BODY_R)
			b.autoT = -4.0
		"quadtree":
			_qt_add(b, pos.x, pos.y)
		"volume":
			b.tx = pos.x
			b.ty = pos.y
			b.autoT = -4.0
		"iframes":
			_if_swing(b)
			b.autoT = -1.0
		"elastic":
			_el_cue(b, pos.x, pos.y)
			b.restT = -2.0
		"obb":
			b.kick += D.kick

static func tick(b: Dictionary, dt: float, t: float) -> void:
	var D: Dictionary = b.D
	var W: float = b.w
	var H: float = b.h
	var GY: float = b.gy
	match b.id:
		"aabb":
			var speed: float = D.speed
			var aw: float = W * D.bw
			var ah: float = H * D.bh
			var cw: float = W * D.cw
			var ch: float = H * D.ch
			var rawX: float = W / 2.0 + sin(t * speed) * W * 0.34
			var rawY: float = H * 0.5 + sin(t * speed * 1.31 + 1.2) * H * 0.3
			var ax := rawX
			var ay := rawY
			var focus := -1
			var best := -1.0e9
			var hit := false
			var px := 0.0
			var py := 0.0
			var crates: Array = b.crates
			for i in crates.size():                      # the crate we are closest to touching
				var c: Vector2 = crates[i]
				var d := minf(minf(ax + aw / 2.0 - (c.x - cw / 2.0), c.x + cw / 2.0 - (ax - aw / 2.0)),
					minf(ay + ah / 2.0 - (c.y - ch / 2.0), c.y + ch / 2.0 - (ay - ah / 2.0)))
				if d > best:
					best = d
					focus = i
			var tests: Array = b.tests
			for i in crates.size():                      # the four tests, then the push
				var c: Vector2 = crates[i]
				var aL := ax - aw / 2.0
				var aR := ax + aw / 2.0
				var aT := ay - ah / 2.0
				var aB := ay + ah / 2.0
				var bL := c.x - cw / 2.0
				var bR := c.x + cw / 2.0
				var bT := c.y - ch / 2.0
				var bB := c.y + ch / 2.0
				var t0 := aL < bR
				var t1 := aR > bL
				var t2 := aT < bB
				var t3 := aB > bT
				if i == focus:
					tests[0] = t0
					tests[1] = t1
					tests[2] = t2
					tests[3] = t3
				if not (t0 and t1 and t2 and t3):
					continue
				var pxx := minf(aR - bL, bR - aL)          # depth on each axis
				var pyy := minf(aB - bT, bB - aT)
				if i == focus:
					px = pxx
					py = pyy
					hit = true
				if pxx < pyy:                            # least penetration wins
					ax += -pxx if aR - bL < bR - aL else pxx
				else:
					ay += -pyy if aB - bT < bB - aT else pyy
			b.rawX = rawX
			b.rawY = rawY
			b.ax = ax
			b.ay = ay
			b.focus = focus
			b.hit = hit
			b.px = px
			b.py = py
		"overlap":
			var speed: float = D.speed
			var orbit: float = D.orbit
			var c: Array = b.c
			var c0: Dictionary = c[0]
			var c1: Dictionary = c[1]
			c0.r = H * D.r1
			c1.r = H * D.r2
			c0.x = W / 2.0 + cos(t * speed) * W * orbit
			c0.y = H * 0.5 + sin(t * speed) * H * orbit * 0.9
			c1.x = W / 2.0 + cos(-t * speed * 1.37 + 2.0) * W * orbit * 0.75
			c1.y = H * 0.5 + sin(-t * speed * 1.37 + 2.0) * H * orbit * 1.1
			for k in c:
				var kk: Dictionary = k
				kk.ox = kk.x
				kk.oy = kk.y
			var rw: float = W * D.rw
			var rh: float = H * D.rh
			var L: float = b.rx - rw / 2.0
			var R: float = b.rx + rw / 2.0
			var T: float = b.ry - rh / 2.0
			var B: float = b.ry + rh / 2.0
			var hits := 0
			for k in c:                                  # circle vs rectangle, each circle
				var kk: Dictionary = k
				var kx: float = kk.x
				var ky: float = kk.y
				var kr: float = kk.r
				var px := clampf(kx, L, R)
				var py := clampf(ky, T, B)
				var dx := kx - px
				var dy := ky - py
				var d := sqrt(dx * dx + dy * dy)
				var inRect := false
				if d < 0.001:                            # centre inside the box: leave by the nearest face
					inRect = true
					var dl := kx - L
					var dr := R - kx
					var dtp := ky - T
					var db := B - ky
					var m := minf(minf(dl, dr), minf(dtp, db))
					if m == dl:
						dx = -1.0
						dy = 0.0
						px = L
					elif m == dr:
						dx = 1.0
						dy = 0.0
						px = R
					elif m == dtp:
						dx = 0.0
						dy = -1.0
						py = T
					else:
						dx = 0.0
						dy = 1.0
						py = B
					d = 0.0
				else:
					dx /= d
					dy /= d
				var touch := d < kr
				kk.px = px
				kk.py = py
				kk.d = d
				kk.touch = touch
				kk.inRect = inRect
				if touch:
					hits += 1
					kk.x = kx + dx * (kr - d)
					kk.y = ky + dy * (kr - d)
				kk.mx = kk.x                             # where it stands before the circle test
				kk.my = kk.y
			var ddx: float = c1.x - c0.x                 # circle vs circle
			var ddy: float = c1.y - c0.y
			var dd := sqrt(ddx * ddx + ddy * ddy)
			var sum: float = c0.r + c1.r
			var cc := dd < sum
			if dd < 0.001:
				ddx = 1.0
				ddy = 0.0
				dd = 0.001
			if cc:
				hits += 1
				var push := (sum - dd) / 2.0
				var nx := ddx / dd
				var ny := ddy / dd
				c0.x -= nx * push
				c0.y -= ny * push
				c1.x += nx * push
				c1.y += ny * push
			b.cc = cc
			b.dcc = dd
			b.sum = sum
			b.hits = hits
		"tunnel":
			var slow: float = D.slow
			var hold: float = D.hold
			var hw: float = W * D.bullet / 2.0
			var hh: float = hw * 0.6
			var wx0: float = W * 0.62
			var wx1: float = wx0 + W * D.wall
			var wy0: float = H * 0.12
			var wy1: float = GY
			var S: Dictionary = b.S
			_tunnel_sweep(b, b.bx, b.by, hw, hh, wx0, wx1, wy0, wy1)   # this step's test, from the box's start
			if not b.stopped:
				b.k += dt / slow
				if b.k >= 1.0:                           # commit the step
					b.k = 0.0
					if S.hit:
						b.bx += b.dx * S.entry
						b.by += b.dy * S.entry
						b.stopped = true
					else:
						b.bx += b.dx
						b.by += b.dy
					if b.ghostOn:
						b.nx += b.dx
						b.ny += b.dy
						if b.nx > wx1 + hw and not b.tunnelled:
							b.tunnelled = true
					_tunnel_sweep(b, b.bx, b.by, hw, hh, wx0, wx1, wy0, wy1)
					if b.bx < -hw * 2.0 or b.bx > W + hw * 2.0 or b.by < -hh * 2.0 or b.by > H + hh * 2.0:
						_tunnel_fire(b, W * randf_range(0.75, 0.95), H * randf_range(0.2, 0.75))
			else:
				b.holdT += dt
				b.k = minf(1.0, b.k + dt / slow)
				if b.ghostOn and b.k >= 1.0:
					b.k = 0.0
					b.nx += b.dx
					b.ny += b.dy
					if b.nx > wx1 + hw:
						b.tunnelled = true
					if b.nx > W + hw * 3.0 or b.ny < -hh * 3.0 or b.ny > H + hh * 3.0:
						b.ghostOn = false
				if b.holdT > hold + 1.0:
					_tunnel_fire(b, W * randf_range(0.75, 0.95), H * randf_range(0.2, 0.75))
		"xaxis":
			var map: Array = D.map
			var ts: float = b.ts
			var gx0: float = b.gx0
			var gy0: float = b.gy0
			var bw: float = b.bw
			b.autoT += dt
			if b.autoT > 3.5 or b.stuckT > 0.8:
				b.autoT = 0.0
				b.stuckT = 0.0
				_xa_new_target(b)
			var ex: float = b.tx - b.px
			var ey: float = b.ty - b.py
			var d := sqrt(ex * ex + ey * ey)
			var sp: float = W * D.speed
			var vx := 0.0
			var vy := 0.0
			if d > 1.5:
				var sc := minf(sp, d / maxf(dt, 1.0e-6)) / d
				vx = ex * sc
				vy = ey * sc
			var ox: float = b.px
			var oy: float = b.py
			b.px += vx * dt                              # ---- the x pass
			var xs: Array = b.xs
			_xa_corners(b, xs)
			b.hitX = maxf(0.0, b.hitX - dt * 3.0)
			for i in 4:
				var c: Vector2i = xs[i]
				if not _solid(map, c.x, c.y):
					continue
				if vx > 0.0:
					b.px = minf(b.px, gx0 + c.x * ts - bw - 0.01)
				elif vx < 0.0:
					b.px = maxf(b.px, gx0 + (c.x + 1) * ts + 0.01)
				b.hitX = 1.0
				b.hx = c
			b.py += vy * dt                              # ---- then the y pass
			var ys: Array = b.ys
			_xa_corners(b, ys)
			b.hitY = maxf(0.0, b.hitY - dt * 3.0)
			for i in 4:
				var c: Vector2i = ys[i]
				if not _solid(map, c.x, c.y):
					continue
				if vy > 0.0:
					b.py = minf(b.py, gy0 + c.y * ts - bw - 0.01)
				elif vy < 0.0:
					b.py = maxf(b.py, gy0 + (c.y + 1) * ts + 0.01)
				b.hitY = 1.0
				b.hy = c
			if d > 1.5 and Vector2(b.px - ox, b.py - oy).length() < sp * dt * 0.3:
				b.stuckT += dt
			else:
				b.stuckT = 0.0
			b.vx = vx
			b.vy = vy
		"oneway":
			var plats: int = D.plats
			var G: float = H * D.g
			var L: float = W * 0.28
			var Rr: float = W * 0.72
			var x: float = W / 2.0 + sin(t * 0.7) * W * 0.1
			b.x = x
			b.autoT += dt
			if b.standing != -2 and b.autoT > 1.0:       # the autopilot: up the stack, then down
				b.autoT = 0.0
				if b.climbing:
					if b.standing == plats - 1:
						b.climbing = false
					else:
						_ow_jump(b)
				else:
					if b.standing >= 0:
						_ow_drop(b)
					else:
						b.climbing = true
						_ow_jump(b)
			if b.dropN > 0:
				b.dropN -= 1
			if b.standing == -2:
				b.vy += G * dt
				var feet0: float = b.y + BODY_R
				b.y += b.vy * dt
				var feet1: float = b.y + BODY_R
				if feet1 >= GY:
					b.y = GY - BODY_R
					b.vy = 0.0
					b.standing = -1
				else:
					for i in plats:
						var top1 := _ow_top(b, i)
						if b.vy > 0.0 and feet0 <= top1 and feet1 >= top1 and b.dropN == 0 and x > L and x < Rr:
							b.y = top1 - BODY_R
							b.vy = 0.0
							b.standing = i
							break
			var feet: float = b.y + BODY_R
			var feetLast: float = b.feetLast
			var tested := -1                             # the ledge just below last frame's feet
			for i in range(plats - 1, -1, -1):
				if _ow_top(b, i) >= feetLast - 0.5:
					tested = i
					break
			var top: float = _ow_top(b, tested) if tested >= 0 else GY
			b.lampV = b.vy > 0.0
			b.lampLast = feetLast <= top + 0.5
			b.lampFeet = feet >= top - 0.5
			b.lampDrop = b.dropN == 0
			b.tested = tested
			b.feetShown = feetLast
			b.feetLast = feet
		"oblique":
			var maxAngle: float = D.maxAngle
			var speed: float = D.speed
			var slideG: float = D.slideG
			var friction: float = D.friction
			var pts: Array = b.pts
			b.autoT += dt
			if b.autoT > 4.0:
				b.autoT = 0.0
				b.tx = randf_range(W * 0.05, W * 0.95)
			var x: float = b.x
			var sg := _terrain(pts, x)
			var th: float = sg.th
			var stx: float = sg.tx
			var sty: float = sg.ty
			var walkable := th <= maxAngle
			var sp: float = b.sp
			if walkable:
				var want := clampf((b.tx - x) * 3.0, -W * speed, W * speed)
				sp *= exp(-friction * dt)
				sp += (want - sp) * Kit.smooth(6.0, dt)
			else:
				var downhill: float = 1.0 if sty > 0.0 else -1.0   # screen y grows downward
				sp += downhill * slideG * H * sin(th * PI / 180.0) * dt
			sp = clampf(sp, -W * 1.5, W * 1.5)
			x += sp * stx * dt                           # velocity lives on the tangent
			if x < W * 0.03:
				x = W * 0.03
				sp = 0.0
			if x > W * 0.97:
				x = W * 0.97
				sp = 0.0
			b.x = x
			b.sp = sp
			b.seg = _terrain(pts, x)
			b.walkable = walkable
		"kerb":
			var steps: int = D.steps
			var probe: float = D.probe
			var speed: float = D.speed
			_kb_probe(b)
			b.lift = maxf(0.0, b.lift - dt * 4.0)
			if b.blockT > 0.0:
				b.blockT -= dt
				if b.blockT <= 0.0:
					b.dir = -1.0
					b.refused = -1
			elif b.footHit and b.kneeHit:                # a wall: refused
				b.blockT = 1.2
				for i in steps:
					if absf(_kb_stepx(b, i) - b.ahead) < BODY_R + probe + 1.0:
						b.refused = i
			elif b.footHit:                              # a step: lift
				b.liftY = b.y
				b.y = b.sAhead
				b.x += probe + 1.0
				b.lift = 1.0
			else:
				b.x += b.dir * W * speed * dt
				var x: float = b.x
				var support := minf(minf(_kb_surf(b, x - BODY_R), _kb_surf(b, x)), _kb_surf(b, x + BODY_R))
				if support > b.y:                        # fall to the ground, settle
					b.y = minf(support, b.y + H * 1.5 * dt)
				else:
					b.y = support
				if b.dir > 0.0 and x > W * 0.94:
					b.dir = -1.0
				if b.dir < 0.0 and x < W * 0.08:
					b.dir = 1.0
		"whiskers":
			var g: float = D.g
			var run: float = D.run
			var slideCap: float = D.slideCap
			var cling: float = D.cling
			var roomL: float = b.roomL
			var roomR: float = b.roomR
			var ceilY: float = b.ceilY
			b.autoT += dt
			if b.autoT > 3.0:
				b.autoT = 0.0
				b.tx = randf_range(roomL + BODY_R * 2.0, roomR - BODY_R * 2.0)
				b.ty = randf_range(ceilY + BODY_R * 2.0, GY - BODY_R)
			var G: float = H * g
			var tx: float = b.tx
			var ty: float = b.ty
			var want := clampf((tx - b.x) * 3.0, -W * run, W * run)
			var dir: int = 1 if want > 0.0 else -1
			var onWall: int = b.onWall
			var onFloor: bool = b.onFloor
			var pushingWall := onWall != 0 and onWall == dir and absf(tx - b.x) > 6.0
			b.vx += (want - b.vx) * Kit.smooth(10.0 if onFloor else 4.0, dt)
			if onFloor and ((ty < b.y - 24.0 and absf(tx - b.x) < W * 0.35) or pushingWall):
				_wk_jump(b)
			b.vy += G * dt
			if onWall != 0 and not onFloor and b.vy > 0.0:   # the wall lamp is lit: slide, then kick
				b.vy = minf(b.vy, H * slideCap)
				b.wallT += dt
				if b.wallT > cling:
					_wk_jump(b)
					b.vx = -onWall * W * run
					b.wallT = 0.0
			else:
				b.wallT = 0.0
			b.x += b.vx * dt
			for sq in b.solids:                          # resolve x against the room
				var sr: Rect2 = sq
				if b.x + BODY_R > sr.position.x and b.x - BODY_R < sr.end.x and b.y + BODY_R > sr.position.y and b.y - BODY_R < sr.end.y:
					if b.vx > 0.0:
						b.x = sr.position.x - BODY_R
					else:
						b.x = sr.end.x + BODY_R
					b.vx = 0.0
			b.y += b.vy * dt
			for sq in b.solids:                          # then y
				var sr: Rect2 = sq
				if b.x + BODY_R > sr.position.x and b.x - BODY_R < sr.end.x and b.y + BODY_R > sr.position.y and b.y - BODY_R < sr.end.y:
					if b.vy > 0.0:
						b.y = sr.position.y - BODY_R
					else:
						b.y = sr.end.y + BODY_R
					b.vy = 0.0
			_wk_sense(b)
		"quadtree":
			var r: float = D.r
			var cols: int = b.cols
			var rows: int = b.rows
			var cs: float = b.cs
			var bodies: Array = b.bodies
			for bd in bodies:
				var o: Dictionary = bd
				o.x += o.vx * dt
				o.y += o.vy * dt
				if o.x < r:
					o.x = r
					o.vx = absf(o.vx)
				elif o.x > W - r:
					o.x = W - r
					o.vx = -absf(o.vx)
				if o.y < r:
					o.y = r
					o.vy = absf(o.vy)
				elif o.y > H - r:
					o.y = H - r
					o.vy = -absf(o.vy)
				o.hot = maxf(0.0, o.hot - dt * 4.0)
				o.cx = mini(cols - 1, maxi(0, int(floorf(o.x / cs))))
				o.cy = mini(rows - 1, maxi(0, int(floorf(o.y / cs))))
			var buckets: Array = b.buckets
			for bk in buckets:
				(bk as Array).clear()
			for bd in bodies:
				var o: Dictionary = bd
				(buckets[o.cx + o.cy * cols] as Array).append(o)
			var tests := 0
			var lines := PackedVector2Array()
			for cy in rows:
				for cx in cols:
					var bkA: Array = buckets[cx + cy * cols]
					if bkA.is_empty():
						continue
					for off in QT_NB:
						var o2: Vector2i = off
						var nx: int = cx + o2.x
						var ny: int = cy + o2.y
						if nx < 0 or ny < 0 or nx >= cols or ny >= rows:
							continue
						var bkB: Array = buckets[nx + ny * cols]
						var same := o2 == Vector2i.ZERO
						for i in bkA.size():
							var j0: int = i + 1 if same else 0
							for j in range(j0, bkB.size()):
								var pa: Dictionary = bkA[i]
								var pb: Dictionary = bkB[j]
								tests += 1
								lines.append(Vector2(pa.x, pa.y))
								lines.append(Vector2(pb.x, pb.y))
								var dx: float = pb.x - pa.x
								var dy: float = pb.y - pa.y
								var d := sqrt(dx * dx + dy * dy)
								if d < 2.0 * r and d > 0.001:   # the narrow phase: the exact circle test
									var nx2 := dx / d
									var ny2 := dy / d
									var push := (2.0 * r - d) / 2.0
									pa.x -= nx2 * push
									pa.y -= ny2 * push
									pb.x += nx2 * push
									pb.y += ny2 * push
									var va: float = pa.vx * nx2 + pa.vy * ny2
									var vb: float = pb.vx * nx2 + pb.vy * ny2
									if va - vb > 0.0:
										pa.vx += (vb - va) * nx2
										pa.vy += (vb - va) * ny2
										pb.vx += (va - vb) * nx2
										pb.vy += (va - vb) * ny2
									pa.hot = 1.0
									pb.hot = 1.0
			b.tests = tests
			b.lines = lines
		"volume":
			var speed: float = D.speed
			b.now += dt
			b.autoT += dt
			if b.autoT > 3.0:
				b.autoT = 0.0
				b.tx = randf_range(W * 0.06, W * 0.94)
				b.ty = randf_range(H * 0.1, H * 0.86)
			var ex: float = b.tx - b.x
			var ey: float = b.ty - b.y
			var d := sqrt(ex * ex + ey * ey)
			if d > 2.0:
				var sc := minf(W * speed, d / maxf(dt, 1.0e-6)) / d
				b.x += ex * sc * dt
				b.y += ey * sc * dt
			b.ex = ex
			b.ey = ey
			for z in b.zones:
				var zz: Dictionary = z
				var inn := _vol_inside(b, zz)
				if inn and not zz.was:
					_vol_post(b, "enter %s" % zz.name, Kit.GOOD)
					zz.stay = 0.0
				elif not inn and zz.was:
					_vol_post(b, "exit %s · stayed %.1f s" % [zz.name, zz.stay], Kit.HOT)
				if inn:
					zz.stay += dt
				zz.was = inn
				zz.inn = inn
		"iframes":
			var swing: float = D.swing
			var active: Array = D.active
			var a0: int = active[0]
			var a1: int = active[1]
			var iframes: float = D.iframes
			var every: float = D.every
			var reach: float = D.reach
			var ax: float = b.ax
			b.autoT += dt
			if b.autoT > every:
				b.autoT = 0.0
				_if_swing(b)
			b.swingF = minf(b.swingF + dt * 60.0, 1.0e4)
			b.invF = maxf(0.0, b.invF - dt * 60.0)
			b.flash = maxf(0.0, b.flash - dt * 3.0)
			b.noteT = maxf(0.0, b.noteT - dt)
			var f: int = int(floorf(b.swingF))
			var swinging: bool = b.swingF < swing
			var activeNow := swinging and f >= a0 and f <= a1
			var dx: float = W * 0.58 + sin(t * 0.9) * W * 0.09   # the defender drifts in and out of reach
			var dy: float = GY - BODY_R
			var hb := Rect2(ax + BODY_R, GY - BODY_R * 2.6, W * reach, BODY_R * 2.6)   # hitbox: in front of the attacker
			var ub := Rect2(dx - BODY_R * 1.2, dy - BODY_R * 1.3, BODY_R * 2.4, BODY_R * 2.6)   # hurtbox
			var overlap := hb.position.x < ub.end.x and hb.end.x > ub.position.x and hb.position.y < ub.end.y and hb.end.y > ub.position.y
			if activeNow and not b.hitThis:
				if overlap and b.invF <= 0.0:
					b.hits += 1
					b.invF = iframes
					b.hitThis = true
					b.flash = 1.0
					b.fx = (maxf(hb.position.x, ub.position.x) + minf(hb.end.x, ub.end.x)) / 2.0
					b.fy = dy - BODY_R
					b.note = "hit"
					b.noteT = 0.8
				elif overlap and b.invF > 0.0:
					b.note = "blocked by i-frames"
					b.noteT = 0.5
				elif f == a1:
					b.whiffs += 1
					b.note = "whiff"
					b.noteT = 0.6
					b.hitThis = true
			b.f = f
			b.swinging = swinging
			b.activeNow = activeNow
			b.dx = dx
			b.dy = dy
			b.hb = hb
			b.ub = ub
		"elastic":
			var e: float = D.e
			var friction: float = D.friction
			var tx0: float = b.tx0
			var ty0: float = b.ty0
			var tw: float = b.tw
			var th: float = b.th
			var balls: Array = b.balls
			var moving := false
			var damp := exp(-friction * dt)
			for bd in balls:
				var o: Dictionary = bd
				o.vx *= damp
				o.vy *= damp
				o.x += o.vx * dt
				o.y += o.vy * dt
				var rr: float = o.r
				if o.x < tx0 + rr:
					o.x = tx0 + rr
					o.vx = absf(o.vx) * e
				if o.x > tx0 + tw - rr:
					o.x = tx0 + tw - rr
					o.vx = -absf(o.vx) * e
				if o.y < ty0 + rr:
					o.y = ty0 + rr
					o.vy = absf(o.vy) * e
				if o.y > ty0 + th - rr:
					o.y = ty0 + th - rr
					o.vy = -absf(o.vy) * e
				if Vector2(o.vx, o.vy).length() > 3.0:
					moving = true
			var last: Dictionary = b.last
			for i in balls.size():
				for j in range(i + 1, balls.size()):
					var pa: Dictionary = balls[i]
					var pb: Dictionary = balls[j]
					var ra: float = pa.r
					var rb: float = pb.r
					var dx: float = pb.x - pa.x
					var dy: float = pb.y - pa.y
					var d := sqrt(dx * dx + dy * dy)
					if d >= ra + rb:
						continue
					if d < 0.001:
						dx = 1.0
						dy = 0.0
						d = 1.0
					var nx := dx / d
					var ny := dy / d
					var ia: float = 1.0 / pa.m
					var ib: float = 1.0 / pb.m
					var push := (ra + rb - d) / (ia + ib)    # separate by inverse mass
					pa.x -= nx * push * ia
					pa.y -= ny * push * ia
					pb.x += nx * push * ib
					pb.y += ny * push * ib
					var vrel: float = (pa.vx - pb.vx) * nx + (pa.vy - pb.vy) * ny   # approach speed along the normal
					if vrel <= 0.0:
						continue
					var jj := (1.0 + e) * vrel / (ia + ib)
					last.a1x = pa.vx
					last.a1y = pa.vy
					last.b1x = pb.vx
					last.b1y = pb.vy
					pa.vx -= jj * nx * ia
					pa.vy -= jj * ny * ia
					pb.vx += jj * nx * ib
					pb.vy += jj * ny * ib
					last.on = 1.0
					last.x = pa.x + nx * ra
					last.y = pa.y + ny * ra
					last.nx = nx
					last.ny = ny
					last.a = i
					last.b = j
					last.a2x = pa.vx
					last.a2y = pa.vy
					last.b2x = pb.vx
					last.b2y = pb.vy
					last.j = jj
			if not moving:
				b.restT += dt
				if b.restT > 1.2:
					b.restT = 0.0
					var o: Dictionary = balls[1] if balls.size() > 1 else balls[0]
					var orr: float = o.r
					_el_cue(b, o.x + randf_range(-orr, orr) * 0.8, o.y + randf_range(-orr, orr) * 0.8)
			else:
				b.restT = minf(b.restT, 0.0)
			last.on = maxf(0.0, last.on - dt * 0.6)
		"obb":
			var spin: float = D.spin
			var drift: float = D.drift
			var hwd: float = W * D.w / 2.0
			var hhd: float = W * D.h / 2.0
			var A: Dictionary = b.A
			var B: Dictionary = b.B
			var cA: Array = b.cA
			var cB: Array = b.cB
			var axes: Array = b.axes
			var iv: Array = b.iv
			b.kick *= exp(-1.2 * dt)
			b.angA = fposmod(b.angA + (spin + b.kick) * dt, TAU)
			A.hw = hwd
			A.hh = hhd
			B.hw = hwd
			B.hh = hhd
			A.a = b.angA
			B.a = 0.4 - t * spin * 0.6
			A.x = W * 0.36 + sin(t * drift * 6.283) * W * 0.13
			A.y = H * 0.4 + cos(t * drift * 6.283 * 0.7) * H * 0.06
			b.rawX = A.x
			b.rawY = A.y
			_obb_corners(A, cA)
			_obb_corners(B, cB)
			var aa: float = A.a
			var ba: float = B.a
			axes[0] = Vector2(cos(aa), sin(aa))
			axes[1] = Vector2(-sin(aa), cos(aa))
			axes[2] = Vector2(cos(ba), sin(ba))
			axes[3] = Vector2(-sin(ba), cos(ba))
			var sep := -1
			var sepGap := -1.0
			var mtv := -1
			var mtvOv := 1.0e9
			for i in 4:
				var axis: Vector2 = axes[i]
				var pa := _obb_project(cA, axis)
				var pb := _obb_project(cB, axis)
				var v: Array = iv[i]
				v[0] = pa.x
				v[1] = pa.y
				v[2] = pb.x
				v[3] = pb.y
				var ov := minf(pa.y, pb.y) - maxf(pa.x, pb.x)
				if ov < 0.0:
					if -ov > sepGap:
						sepGap = -ov
						sep = i
				elif ov < mtvOv:
					mtvOv = ov
					mtv = i
			var colliding := sep < 0
			if colliding:                                # push A out along the axis of least overlap
				var axis: Vector2 = axes[mtv]
				var sgn: float = 1.0 if (A.x - B.x) * axis.x + (A.y - B.y) * axis.y >= 0.0 else -1.0
				A.x += axis.x * mtvOv * sgn
				A.y += axis.y * mtvOv * sgn
				_obb_corners(A, b.cR)
			b.sep = sep
			b.mtv = mtv
			b.mtvOv = mtvOv if colliding else 0.0
			b.colliding = colliding

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	Kit.stage(n, b)
	var D: Dictionary = b.D
	var W: float = b.w
	var H: float = b.h
	var GY: float = b.gy
	match b.id:
		"aabb":
			var aw: float = W * D.bw
			var ah: float = H * D.bh
			var cw: float = W * D.cw
			var ch: float = H * D.ch
			var rawX: float = b.rawX
			var rawY: float = b.rawY
			var ax: float = b.ax
			var ay: float = b.ay
			var focus: int = b.focus
			var hit: bool = b.hit
			var px: float = b.px
			var py: float = b.py
			var tests: Array = b.tests
			var crates: Array = b.crates
			var names := ["aL < bR", "aR > bL", "aT < bB", "aB > bT"]
			for i in crates.size():
				var c: Vector2 = crates[i]
				var cr := Rect2(c.x - cw / 2.0, c.y - ch / 2.0, cw, ch)
				Kit.rect(n, cr, Color(Kit.TARGET, 0.35 if i == focus else 0.18))
				_srect(n, cr, Kit.TARGET, 1.5)
				Kit.line(n, cr.position, cr.end, Color(Kit.TARGET, 0.4))
				Kit.line(n, Vector2(cr.end.x, cr.position.y), Vector2(cr.position.x, cr.end.y), Color(Kit.TARGET, 0.4))
			if hit:                                      # the raw box, and the push that fixed it
				_dash_rect(n, Rect2(rawX - aw / 2.0, rawY - ah / 2.0, aw, ah), Kit.DIM, 1.0, 3.0)
				Kit.rect(n, Rect2(ax - aw / 2.0, ay - ah / 2.0, aw, ah), Color(Kit.HOT, 0.22))
				Kit.arrow(n, Vector2(rawX, rawY), Vector2(ax, ay), Kit.HOT)
				var ptxt: String = ("x %d" % roundi(px)) if px < py else ("y %d" % roundi(py))
				Kit.label(n, b, "push " + ptxt + " px", Vector2((rawX + ax) / 2.0, minf(rawY, ay) - ah / 2.0 - 6.0), Kit.HOT, true)
			else:
				Kit.rect(n, Rect2(ax - aw / 2.0, ay - ah / 2.0, aw, ah), Color(Kit.MOVER, 0.12))
			var L := ax - aw / 2.0
			var R := ax + aw / 2.0
			var T := ay - ah / 2.0
			var B := ay + ah / 2.0
			Kit.line(n, Vector2(L, T), Vector2(L, B), Kit.GOOD if tests[0] else Kit.HOT, 2.0)   # each side wears its own test
			Kit.line(n, Vector2(R, T), Vector2(R, B), Kit.GOOD if tests[1] else Kit.HOT, 2.0)
			Kit.line(n, Vector2(L, T), Vector2(R, T), Kit.GOOD if tests[2] else Kit.HOT, 2.0)
			Kit.line(n, Vector2(L, B), Vector2(R, B), Kit.GOOD if tests[3] else Kit.HOT, 2.0)
			Kit.mote(n, b, Vector2(ax, ay), 0.0)
			for i in 4:
				Kit.label(n, b, names[i] + ("  ✓" if tests[i] else "  ✗"), Vector2(8.0, 14.0 + i * 12.0), Kit.GOOD if tests[i] else Kit.HOT)
			var otxt: String = ("overlap: px %d · py %d" % [roundi(px), roundi(py)]) if hit else "no overlap"
			_label_right(n, b, otxt, Vector2(W - 8.0, 14.0), Kit.HOT if hit else Kit.DIM)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"overlap":
			var rw: float = W * D.rw
			var rh: float = H * D.rh
			var rx: float = b.rx
			var ry: float = b.ry
			var c: Array = b.c
			var c0: Dictionary = c[0]
			var c1: Dictionary = c[1]
			var hits: int = b.hits
			var cc: bool = b.cc
			var dcc: float = b.dcc
			var sum: float = b.sum
			_srect(n, Rect2(rx - rw / 2.0, ry - rh / 2.0, rw, rh), Kit.TARGET, 1.5)
			for k in c:                                  # the nearest point, and its distance
				var kk: Dictionary = k
				var touch: bool = kk.touch
				var p := Vector2(kk.px, kk.py)
				var o := Vector2(kk.ox, kk.oy)
				Kit.line(n, p, o, Kit.HOT if touch else Kit.DIM, 1.0)
				Kit.dot(n, p, 3.0, Kit.HOT if touch else Kit.TARGET)
				Kit.label(n, b, ("d %d" % roundi(kk.d)) + (" < r" if touch else " ≥ r"), (p + o) / 2.0 + Vector2(6.0, -4.0), Kit.HOT if touch else Kit.DIM)
				if kk.inRect:
					Kit.label(n, b, "inside", p + Vector2(0.0, -6.0), Kit.HOT, true)
			var ma := Vector2(c0.mx, c0.my)              # circle vs circle: the line between centres
			var mb := Vector2(c1.mx, c1.my)
			Kit.line(n, ma, mb, Kit.HOT if cc else Kit.DIM, 1.0)
			Kit.label(n, b, ("d %d" % roundi(dcc)) + (" < " if cc else " ≥ ") + ("r₁+r₂ %d" % roundi(sum)), (ma + mb) / 2.0 + Vector2(0.0, -6.0), Kit.HOT if cc else Kit.DIM, true)
			for i in 2:                                  # raw ring, pushed body, push arrow
				var kk: Dictionary = c[i]
				var kr: float = kk.r
				var p := Vector2(kk.x, kk.y)
				var o := Vector2(kk.ox, kk.oy)
				var moved := p.distance_to(o) > 0.5
				if moved:
					Kit.ring(n, o, kr, Kit.DIM, 1.0)
					Kit.arrow(n, o, p, Kit.HOT)
				var fillc := Color(Kit.HOT, 0.35) if moved else (Color(Kit.TARGET, 0.25) if i == 1 else Color(Kit.MOVER, 0.25))
				Kit.dot(n, p, kr, fillc)
				Kit.ring(n, p, kr, Kit.TARGET if i == 1 else Kit.MOVER, 1.5)
			Kit.mote(n, b, Vector2(c0.x, c0.y), atan2(c0.oy - H / 2.0, c0.ox - W / 2.0) + PI / 2.0)
			var htxt: String = ("%d overlap%s pushed out" % [hits, "s" if hits > 1 else ""]) if hits > 0 else "no overlap"
			_label_right(n, b, htxt, Vector2(W - 8.0, 14.0), Kit.HOT if hits > 0 else Kit.DIM)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"tunnel":
			Kit.ground(n, b)
			var hw: float = W * D.bullet / 2.0
			var hh: float = hw * 0.6
			var wx0: float = W * 0.62
			var wx1: float = wx0 + W * D.wall
			var wy0: float = H * 0.12
			var S: Dictionary = b.S
			var bx: float = b.bx
			var by: float = b.by
			var dx: float = b.dx
			var dy: float = b.dy
			var k: float = b.k
			var stopped: bool = b.stopped
			var hit: bool = S.hit
			var entry: float = S.entry
			Kit.rect(n, Rect2(wx0, wy0, wx1 - wx0, GY - wy0), Color(Kit.BONE, 0.55))   # the wall
			Kit.label(n, b, "wall %d px" % roundi(wx1 - wx0), Vector2((wx0 + wx1) / 2.0, wy0 - 5.0), Kit.DIM, true)
			var ex: float = bx + dx                      # the swept slab from the start of this step to its end
			var ey: float = by + dy
			var pts: Array = [Vector2(bx - hw, by - hh), Vector2(bx + hw, by - hh), Vector2(bx + hw, by + hh), Vector2(bx - hw, by + hh),
				Vector2(ex - hw, ey - hh), Vector2(ex + hw, ey - hh), Vector2(ex + hw, ey + hh), Vector2(ex - hw, ey + hh)]
			var hull := _hull(pts)
			if hull.size() >= 3:
				n.draw_colored_polygon(hull, Color(Kit.MOVER, 0.1))
				var closed := PackedVector2Array(hull)
				closed.append(hull[0])
				n.draw_polyline(closed, Color(Kit.MOVER, 0.35), 1.0)
			_srect(n, Rect2(bx - hw, by - hh, hw * 2.0, hh * 2.0), Kit.DIM, 1.0)
			_dash_rect(n, Rect2(ex - hw, ey - hh, hw * 2.0, hh * 2.0), Kit.DIM, 1.0, 2.0)
			Kit.line(n, Vector2(bx, by), Vector2(ex, ey), Kit.DIM, 1.0)
			for tk in [[S.tx1, Kit.TARGET, 4.0], [S.tx2, Kit.TARGET, 4.0], [S.ty1, Kit.GOOD, -4.0], [S.ty2, Kit.GOOD, -4.0]]:
				var tv: float = tk[0]                    # entry / exit ticks along the step, per axis
				if tv < 0.0 or tv > 1.0:
					continue
				var off: float = tk[2]
				Kit.dot(n, Vector2(bx + dx * tv + off, by + dy * tv - off), 2.2, tk[1])
			if hit:                                      # the box at the time of impact
				var hx: float = bx + dx * entry
				var hy: float = by + dy * entry
				_srect(n, Rect2(hx - hw, hy - hh, hw * 2.0, hh * 2.0), Kit.GOOD, 1.5)
				Kit.label(n, b, "t = %.2f" % entry, Vector2(hx, hy - hh - 6.0), Kit.GOOD, true)
			var ghx: float = b.nx + dx * k               # the naive ghost, and the swept box, both moving along the step
			var ghy: float = b.ny + dy * k
			if b.ghostOn:
				_dash_rect(n, Rect2(ghx - hw, ghy - hh, hw * 2.0, hh * 2.0), Kit.MAGIC, 1.2, 3.0)
				if b.tunnelled:
					Kit.label(n, b, "naive: tunnelled through", Vector2(clampf(ghx, 70.0, W - 70.0), ghy - hh - 6.0), Kit.HOT, true)
			var sk: float = 0.0 if stopped else (minf(k, entry) if hit else k)
			var sx: float = bx + dx * sk
			var sy: float = by + dy * sk
			Kit.rect(n, Rect2(sx - hw, sy - hh, hw * 2.0, hh * 2.0), Color(Kit.GOOD, 0.5) if stopped else Color(Kit.MOVER, 0.6))
			_srect(n, Rect2(sx - hw, sy - hh, hw * 2.0, hh * 2.0), Kit.GOOD if stopped else Kit.MOVER, 1.5)
			var aim: float = b.aim
			Kit.arrow(n, Vector2(sx, sy), Vector2(sx + cos(aim) * hw * 1.6, sy + sin(aim) * hw * 1.6), Kit.GOOD if stopped else Kit.MOVER)
			Kit.dot(n, Vector2(W * 0.1, H * 0.5), 3.0, Kit.DIM)   # the launcher
			if stopped:
				Kit.label(n, b, "swept: stopped at entry", Vector2(clampf(sx, 70.0, W - 70.0), sy + hh + 12.0), Kit.GOOD, true)
			Kit.label(n, b, "step %d px / frame" % roundi(sqrt(dx * dx + dy * dy)), Vector2(8.0, 14.0), Kit.MOVER)
			Kit.label(n, b, "tx " + _fmt(S.tx1) + " → " + _fmt(S.tx2), Vector2(8.0, 26.0), Kit.TARGET)
			Kit.label(n, b, "ty " + _fmt(S.ty1) + " → " + _fmt(S.ty2), Vector2(8.0, 38.0), Kit.GOOD)
			Kit.label(n, b, "entry " + _fmt(entry) + " · exit " + _fmt(S.exit) + (" · hit" if hit else " · miss"), Vector2(8.0, 50.0), Kit.HOT if hit else Kit.DIM)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"xaxis":
			var map: Array = D.map
			var rows: int = b.rows
			var cols: int = b.cols
			var ts: float = b.ts
			var gx0: float = b.gx0
			var gy0: float = b.gy0
			var bw: float = b.bw
			var px: float = b.px
			var py: float = b.py
			var vx: float = b.vx
			var vy: float = b.vy
			var hitX: float = b.hitX
			var hitY: float = b.hitY
			var xs: Array = b.xs
			var ys: Array = b.ys
			for cy in rows:                              # the map
				for cx in cols:
					if not _solid(map, cx, cy):
						continue
					var x: float = gx0 + cx * ts
					var y: float = gy0 + cy * ts
					Kit.rect(n, Rect2(x, y, ts, ts), Color(Kit.BONE, 0.22))
					_srect(n, Rect2(x + 0.5, y + 0.5, ts - 1.0, ts - 1.0), Color(Kit.BONE, 0.35), 1.0)
			if hitX > 0.0:
				var hx: Vector2i = b.hx
				Kit.rect(n, Rect2(gx0 + hx.x * ts, gy0 + hx.y * ts, ts, ts), Color(Kit.HOT, hitX * 0.6))
			if hitY > 0.0:
				var hy: Vector2i = b.hy
				Kit.rect(n, Rect2(gx0 + hy.x * ts, gy0 + hy.y * ts, ts, ts), Color(Kit.HOT, hitY * 0.6))
			for i in 4:                                  # the sampled corners: amber x, green y
				var cxs: Vector2i = xs[i]
				var cys: Vector2i = ys[i]
				_srect(n, Rect2(gx0 + cxs.x * ts + 2.0, gy0 + cxs.y * ts + 2.0, ts - 4.0, ts - 4.0), Color(Kit.TARGET, 0.8), 1.5)
				_srect(n, Rect2(gx0 + cys.x * ts + 4.0, gy0 + cys.y * ts + 4.0, ts - 8.0, ts - 8.0), Color(Kit.GOOD, 0.8), 1.5)
			_srect(n, Rect2(b.tx, b.ty, bw, bw), Kit.TARGET, 1.0)   # where it is going
			Kit.rect(n, Rect2(px, py, bw, bw), Color(Kit.MOVER, 0.25))
			_srect(n, Rect2(px, py, bw, bw), Kit.MOVER, 1.5)
			Kit.dot(n, Vector2(px + 0.5, py + 0.5), 2.0, Kit.TARGET)
			Kit.dot(n, Vector2(px + bw - 0.5, py + 0.5), 2.0, Kit.TARGET)
			Kit.dot(n, Vector2(px + 0.5, py + bw - 0.5), 2.0, Kit.GOOD)
			Kit.dot(n, Vector2(px + bw - 0.5, py + bw - 0.5), 2.0, Kit.GOOD)
			var mid := Vector2(px + bw / 2.0, py + bw / 2.0)
			Kit.mote(n, b, mid, atan2(vy, vx if vx != 0.0 else 0.001), Kit.MOVER, minf(8.0, bw * 0.3))
			if absf(vx) > 1.0 or absf(vy) > 1.0:
				Kit.arrow(n, mid, mid + Vector2(vx, vy) * 0.25, Kit.DIM)
			Kit.label(n, b, "x pass", Vector2(gx0 + 4.0, gy0 + ts * 0.7), Kit.HOT if hitX > 0.5 else Kit.TARGET)
			_label_right(n, b, "y pass", Vector2(gx0 + cols * ts - 4.0, gy0 + ts * 0.7), Kit.HOT if hitY > 0.5 else Kit.GOOD)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"oneway":
			Kit.ground(n, b)
			var plats: int = D.plats
			var dropFrames: int = D.dropFrames
			var L: float = W * 0.28
			var Rr: float = W * 0.72
			var x: float = b.x
			var y: float = b.y
			var vy: float = b.vy
			var standing: int = b.standing
			var dropN: int = b.dropN
			var tested: int = b.tested
			var feetShown: float = b.feetShown
			var feet: float = y + BODY_R
			for i in plats:
				var py := _ow_top(b, i)
				var on := i == tested
				Kit.rect(n, Rect2(L, py, Rr - L, 4.0), Color(Kit.TARGET, 0.35) if on else Color(Kit.BONE, 0.2))
				Kit.line(n, Vector2(L, py), Vector2(Rr, py), Kit.TARGET if on else Color(Kit.BONE, 0.7), 2.0 if on else 1.2)
				var k := L + 6.0
				while k < Rr:                            # hatched below only: solid from above
					Kit.line(n, Vector2(k, py + 4.0), Vector2(k - 3.0, py + 8.0), Kit.DIM)
					k += 12.0
			n.draw_dashed_line(Vector2(L - 10.0, feetShown), Vector2(Rr + 10.0, feetShown), Color(Kit.MOVER, 0.6), 1.0, 3.0)
			_label_right(n, b, "feet last", Vector2(Rr - 4.0, feetShown - 4.0), Color(Kit.MOVER, 0.7))
			Kit.line(n, Vector2(x - BODY_R, feet), Vector2(x + BODY_R, feet), Kit.MOVER, 1.5)
			Kit.mote(n, b, Vector2(x, y), -PI / 2.0 if vy < -1.0 else (PI / 2.0 if vy > 1.0 else 0.0))
			if dropN > 0:
				Kit.label(n, b, "ignoring for %d f" % dropN, Vector2(x, y + BODY_R + 14.0), Kit.HOT, true)
				Kit.rect(n, Rect2(x - 16.0, y + BODY_R + 17.0, 32.0 * dropN / maxf(1.0, dropFrames), 3.0), Kit.HOT)
			var lamps: Array = [[b.lampV, "vy > 0"], [b.lampLast, "feetLast ≤ top"], [b.lampFeet, "feet ≥ top"], [b.lampDrop, "drop = 0"]]
			for i in 4:
				var lp: Array = lamps[i]
				var on: bool = lp[0]
				Kit.dot(n, Vector2(10.0, 14.0 + i * 13.0), 4.0, Kit.GOOD if on else Kit.HOT)
				Kit.label(n, b, lp[1], Vector2(18.0, 17.0 + i * 13.0), Kit.GOOD if on else Kit.DIM)
			var stxt: String = "airborne" if standing == -2 else ("on the floor" if standing < 0 else "on ledge %d" % (standing + 1))
			_label_right(n, b, stxt, Vector2(W - 8.0, 14.0), Kit.DIM if standing == -2 else Kit.GOOD)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"oblique":
			var maxAngle: float = D.maxAngle
			var slideG: float = D.slideG
			var pts: Array = b.pts
			var sg: Dictionary = b.seg
			var walkable: bool = b.walkable
			var x: float = b.x
			var sp: float = b.sp
			var tx: float = b.tx
			var fy: float = sg.y
			var snx: float = sg.nx
			var sny: float = sg.ny
			var stx: float = sg.tx
			var sty: float = sg.ty
			var th: float = sg.th
			Kit.poly(n, b.fill, Color(Kit.BONE, 0.14))
			var edge: Array = pts.duplicate()
			edge.append(Vector2(W, H + 2.0))
			edge.append(Vector2(0.0, H + 2.0))
			Kit.poly(n, edge, Color(Kit.BONE, 0.7), 1.5)
			var bx: float = x + snx * BODY_R
			var by: float = fy + sny * BODY_R
			var tsg := _terrain(pts, tx)
			Kit.ring(n, Vector2(tx, float(tsg.y) - 3.0), 4.0, Kit.TARGET, 1.5)
			var lim: float = maxAngle * PI / 180.0       # the allowed cone
			var cl := 30.0
			n.draw_dashed_line(Vector2(x, fy), Vector2(x + sin(lim) * cl, fy - cos(lim) * cl), Kit.DIM, 1.0, 2.0)
			n.draw_dashed_line(Vector2(x, fy), Vector2(x - sin(lim) * cl, fy - cos(lim) * cl), Kit.DIM, 1.0, 2.0)
			Kit.arrow(n, Vector2(x, fy), Vector2(x + snx * 26.0, fy + sny * 26.0), Kit.GOOD if walkable else Kit.HOT)
			if absf(sp) > 4.0:
				Kit.arrow(n, Vector2(bx, by), Vector2(bx + stx * sp * 0.25, by + sty * sp * 0.25), Kit.MOVER if walkable else Kit.HOT)
			var facing: float = atan2(sty, stx) if sp >= 0.0 else atan2(-sty, -stx)
			Kit.mote(n, b, Vector2(bx, by), facing)
			var atxt: String = "θ %d° %s %s°%s" % [roundi(th), "≤" if walkable else ">", _num(maxAngle), "" if walkable else "  slide"]
			Kit.label(n, b, atxt, Vector2(clampf(x, 50.0, W - 50.0), fy - cl - 8.0), Kit.GOOD if walkable else Kit.HOT, true)
			_label_right(n, b, "g·sin θ = %.2f H/s²" % (slideG * sin(th * PI / 180.0)), Vector2(W - 8.0, 14.0), Kit.DIM if walkable else Kit.HOT)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"kerb":
			Kit.ground(n, b)
			var steps: int = D.steps
			var knee: float = D.knee
			var x: float = b.x
			var y: float = b.y
			var dir: float = b.dir
			var refused: int = b.refused
			var blockT: float = b.blockT
			var lift: float = b.lift
			var liftY: float = b.liftY
			var riser: float = b.riser
			var kneeY: float = b.kneeY
			var footY: float = b.footY
			var ahead: float = b.ahead
			var footHit: bool = b.footHit
			var kneeHit: bool = b.kneeHit
			for i in steps:                              # the stairs
				var sx := _kb_stepx(b, i)
				var sh := _kb_steph(b, i)
				var top := _kb_surf(b, sx + 1.0)
				Kit.rect(n, Rect2(sx, top, W - sx, GY - top), Color(Kit.BONE, 0.12))
				Kit.line(n, Vector2(sx, top), Vector2(sx, top + sh), Kit.HOT if i == refused else Kit.BONE, 2.5 if i == refused else 1.5)
				Kit.line(n, Vector2(sx, top), Vector2(_kb_stepx(b, i + 1) if i + 1 < steps else W, top), Kit.BONE, 1.5)
				Kit.label(n, b, "%.3f" % (sh / H), Vector2(sx + 3.0, top + sh - 2.0), Kit.HOT if i == refused else Kit.DIM)
			Kit.line(n, Vector2(0.0, GY - knee * H), Vector2(W * 0.3, GY - knee * H), Color(Kit.GOOD, 0.35), 1.0)
			Kit.label(n, b, "knee %.3f H" % knee, Vector2(4.0, GY - knee * H - 3.0), Kit.GOOD)
			var fx0: float = x + dir * BODY_R            # the two probes
			var align: String = "left" if dir > 0.0 else "right"
			Kit.line(n, Vector2(fx0, footY), Vector2(ahead, footY), Kit.HOT if footHit else Kit.GOOD, 2.0)
			Kit.dot(n, Vector2(ahead, footY), 2.5, Kit.HOT if footHit else Kit.GOOD)
			_lab(n, b, "foot", Vector2(fx0 + dir * 2.0, footY + 11.0), Kit.HOT if footHit else Kit.GOOD, align)
			Kit.line(n, Vector2(fx0, kneeY), Vector2(ahead, kneeY), Kit.HOT if kneeHit else Kit.GOOD, 2.0)
			Kit.dot(n, Vector2(ahead, kneeY), 2.5, Kit.HOT if kneeHit else Kit.GOOD)
			_lab(n, b, "knee", Vector2(fx0 + dir * 2.0, kneeY - 4.0), Kit.HOT if kneeHit else Kit.GOOD, align)
			if lift > 0.0:
				Kit.arrow(n, Vector2(x - 14.0, liftY), Vector2(x - 14.0, y), Color(Kit.GOOD, lift))
				_label_right(n, b, "lift", Vector2(x - 18.0, (liftY + y) / 2.0 + 3.0), Kit.GOOD)
			if blockT > 0.0:
				var rtxt: String = ("%.3f" % (_kb_steph(b, refused) / H)) if refused >= 0 else ""
				Kit.label(n, b, "too tall: " + rtxt + " > knee", Vector2(ahead, kneeY - 16.0), Kit.HOT, true)
			var bob: float = absf(sin(t * 12.0)) * 1.5 * (0.0 if blockT > 0.0 else 1.0)
			Kit.mote(n, b, Vector2(x, y - BODY_R - bob), 0.0 if dir > 0.0 else PI)
			_label_right(n, b, "riser × %.2f  (drag)" % riser, Vector2(W - 8.0, 14.0), Kit.TARGET)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"whiskers":
			var lenD: float = D.len
			var tolD: float = D.tol
			var roomL: float = b.roomL
			var roomR: float = b.roomR
			var ceilY: float = b.ceilY
			var x: float = b.x
			var y: float = b.y
			var vx: float = b.vx
			var vy: float = b.vy
			var onFloor: bool = b.onFloor
			var onWall: int = b.onWall
			var onCeil: bool = b.onCeil
			var solids: Array = b.solids
			for sq in solids:
				Kit.rect(n, sq, Color(Kit.BONE, 0.14))
			Kit.line(n, Vector2(roomL, ceilY), Vector2(roomR, ceilY), Kit.BONE, 1.5)
			Kit.line(n, Vector2(roomL, ceilY), Vector2(roomL, GY), Kit.BONE, 1.5)
			Kit.line(n, Vector2(roomR, ceilY), Vector2(roomR, GY), Kit.BONE, 1.5)
			Kit.line(n, Vector2(roomL, GY), Vector2(roomR, GY), Kit.BONE, 1.5)
			_srect(n, solids[4], Kit.BONE, 1.5)
			Kit.ring(n, Vector2(b.tx, b.ty), 4.0, Kit.TARGET, 1.5)
			var Lw: float = lenD * H
			var Tw: float = tolD * H
			for r in b.rays:                             # the whiskers: solid to len, faint to len + tol
				var rr: Dictionary = r
				var hitr: bool = rr.hit
				var o := Vector2(rr.ox, rr.oy)
				var dv := Vector2(rr.dx, rr.dy)
				Kit.line(n, o, o + dv * Lw, Kit.HOT if hitr else Kit.GOOD, 1.5)
				Kit.line(n, o + dv * Lw, o + dv * (Lw + Tw), Color(Kit.HOT, 0.4) if hitr else Color(Kit.GOOD, 0.35), 1.0)
				if hitr:
					Kit.dot(n, o + dv * minf(rr.d, Lw + Tw), 2.5, Kit.HOT)
			if onWall != 0 and not onFloor and vy > 0.0:
				_lab(n, b, "slide", Vector2(x - onWall * 14.0, y + 3.0), Kit.HOT, "right" if onWall > 0 else "left")
			Kit.mote(n, b, Vector2(x, y), PI if vx < 0.0 else 0.0)
			var lamps: Array = [[onFloor, "onFloor"], [onWall != 0, "onWall"], [onCeil, "onCeiling"]]
			for i in 3:
				var lp: Array = lamps[i]
				var on: bool = lp[0]
				var lx: float = W * (0.2 + i * 0.27)
				Kit.dot(n, Vector2(lx, ceilY / 2.0), 4.0, Kit.GOOD if on else Color(Kit.INK, 0.15))
				Kit.label(n, b, lp[1], Vector2(lx + 8.0, ceilY / 2.0 + 3.0), Kit.GOOD if on else Kit.DIM)
			Kit.label(n, b, "len %d + tol %d px" % [roundi(Lw), roundi(Tw)], Vector2(8.0, H - 22.0), Kit.DIM)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"quadtree":
			var r: float = D.r
			var cols: int = b.cols
			var rows: int = b.rows
			var cs: float = b.cs
			var bodies: Array = b.bodies
			var tests: int = b.tests
			var lines: PackedVector2Array = b.lines
			var gridc := Color(Kit.BONE, 0.18)           # the grid, and the focus body's neighbourhood
			for i in range(1, cols):
				n.draw_line(Vector2(i * cs, 0.0), Vector2(i * cs, H), gridc, 1.0)
			for j in range(1, rows):
				n.draw_line(Vector2(0.0, j * cs), Vector2(W, j * cs), gridc, 1.0)
			if not bodies.is_empty():
				var f: Dictionary = bodies[0]
				var fcx: int = f.cx
				var fcy: int = f.cy
				for j in range(-1, 2):
					for i in range(-1, 2):
						var cx := fcx + i
						var cy := fcy + j
						if cx < 0 or cy < 0 or cx >= cols or cy >= rows:
							continue
						Kit.rect(n, Rect2(cx * cs, cy * cs, cs, cs), Color(Kit.TARGET, 0.22 if i == 0 and j == 0 else 0.09))
			var nn: int = bodies.size()
			if lines.size() >= 2:                        # the pairs actually tested this frame
				n.draw_multiline(lines, Color(Kit.INK, minf(0.25, 9.0 / maxf(1.0, nn))), 1.0)
			for i in nn:
				var o: Dictionary = bodies[i]
				Kit.dot(n, Vector2(o.x, o.y), r, Kit.HOT if o.hot > 0.0 else (Kit.TARGET if i == 0 else Kit.MOVER))
			var all: float = nn * (nn - 1) / 2.0
			Kit.rect(n, Rect2(0.0, H - 22.0, W, 22.0), Color(Kit.NIGHT, 0.7))
			Kit.rect(n, Rect2(0.0, 0.0, W, 20.0), Color(Kit.NIGHT, 0.7))
			var pct: int = roundi(100.0 * tests / all) if all > 0.0 else 0
			Kit.label(n, b, "tests: %d of %d  (%d%%)" % [tests, int(all), pct], Vector2(8.0, 14.0), Kit.GOOD)
			_label_right(n, b, "%d bodies · %d×%d cells" % [nn, cols, rows], Vector2(W - 8.0, 14.0), Kit.DIM)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"volume":
			var x: float = b.x
			var y: float = b.y
			var ex: float = b.ex
			var ey: float = b.ey
			var now: float = b.now
			for z in b.zones:                            # draw each zone, lit while inside
				var zz: Dictionary = z
				var inn: bool = zz.inn
				var fillC := Color(Kit.GOOD, 0.22) if inn else Color(Kit.MAGIC, 0.08)
				var edge := Kit.GOOD if inn else Kit.MAGIC
				var lp := Vector2.ZERO
				if zz.kind == "rect":
					var rr: Array = D.rect
					var zr := Rect2(float(rr[0]) * W, float(rr[1]) * H, float(rr[2]) * W, float(rr[3]) * H)
					Kit.rect(n, zr, fillC)
					_srect(n, zr, edge, 1.5)
					lp = zr.position + Vector2(4.0, 12.0)
				elif zz.kind == "circle":
					var cc: Array = D.circle
					var cp := Vector2(float(cc[0]) * W, float(cc[1]) * H)
					var cr: float = float(cc[2]) * W
					Kit.dot(n, cp, cr, fillC)
					Kit.ring(n, cp, cr, edge, 1.5)
					lp = cp + Vector2(-cr + 4.0, -cr + 12.0)
				else:
					var sc: Array = D.sector
					var cp := Vector2(float(sc[0]) * W, float(sc[1]) * H)
					var sr: float = float(sc[2]) * W
					var a0: float = sc[3]
					var a1: float = sc[4]
					var wedge: Array = [cp]
					for k in 25:
						var ang: float = a0 + (a1 - a0) * k / 24.0
						wedge.append(cp + Vector2(cos(ang), sin(ang)) * sr)
					Kit.poly(n, wedge, fillC)
					Kit.poly(n, wedge, edge, 1.5)
					lp = cp + Vector2(4.0, -6.0)
				var ztxt: String = str(zz.name) + ((" · stay %.1f s" % float(zz.stay)) if inn else "")
				Kit.label(n, b, ztxt, lp, Kit.GOOD if inn else Color(Kit.MAGIC, 0.7))
			Kit.ring(n, Vector2(b.tx, b.ty), 4.0, Kit.TARGET, 1.5)
			Kit.mote(n, b, Vector2(x, y), atan2(ey, ex if ex != 0.0 else 0.001))
			var logs: Array = b.logs                     # the ticker, newest at the bottom
			for i in logs.size():
				var e: Dictionary = logs[i]
				var age: float = now - e.t
				var a := clampf(1.2 - age * 0.12, 0.25, 1.0)
				var ec: Color = e.c
				_label_right(n, b, e.txt, Vector2(W - 8.0, 14.0 + i * 12.0), Color(ec, ec.a * a))
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"iframes":
			Kit.ground(n, b)
			var swing: int = D.swing
			var active: Array = D.active
			var a0: int = active[0]
			var a1: int = active[1]
			var iframes: float = D.iframes
			var reach: float = D.reach
			var ax: float = b.ax
			var f: int = b.f
			var swinging: bool = b.swinging
			var activeNow: bool = b.activeNow
			var swingF: float = b.swingF
			var invF: float = b.invF
			var dx: float = b.dx
			var dy: float = b.dy
			var hb: Rect2 = b.hb
			var ub: Rect2 = b.ub
			var flash: float = b.flash
			var noteT: float = b.noteT
			var note: String = b.note
			var sx0: float = W * 0.1                     # the frame strip
			var sw: float = W * 0.8 / swing
			var sy0 := 10.0
			for i in swing:
				var act := i >= a0 and i <= a1
				Kit.rect(n, Rect2(sx0 + i * sw + 0.5, sy0, sw - 1.0, 7.0), Color(Kit.HOT, 0.7) if act else Color(Kit.BONE, 0.2))
			if swinging:
				Kit.rect(n, Rect2(sx0 + f * sw, sy0 - 2.0, sw, 11.0), Color(Kit.INK, 0.9))
				Kit.label(n, b, "frame %d / %d" % [f, swing], Vector2(sx0 + f * sw + sw / 2.0, sy0 + 21.0), Kit.HOT if activeNow else Kit.DIM, true)
			else:
				Kit.label(n, b, "active frames %d–%d" % [a0, a1], Vector2(W / 2.0, sy0 + 21.0), Kit.DIM, true)
			var k: float = swingF / swing if swinging else 0.0   # the attacker and the sword
			var ang: float = -1.9 + k * 2.4
			Kit.line(n, Vector2(ax, GY - BODY_R), Vector2(ax + cos(ang) * W * reach * 0.9, GY - BODY_R + sin(ang) * W * reach * 0.9),
				Kit.HOT if activeNow else Kit.BONE, 3.0 if activeNow else 2.0)
			Kit.mote(n, b, Vector2(ax, GY - BODY_R), 0.0, Kit.HOT)
			if activeNow:
				Kit.rect(n, hb, Color(Kit.HOT, 0.25))
				_srect(n, hb, Kit.HOT, 1.5)
				Kit.label(n, b, "hitbox", hb.position + Vector2(3.0, -4.0), Kit.HOT)
			else:
				_dash_rect(n, hb, Color(Kit.HOT, 0.3), 1.0, 2.0)
			var visible := invF <= 0.0 or int(floorf(invF / 3.0)) % 2 == 0   # the defender: flickers while invincible, hurtbox off
			if invF <= 0.0:
				Kit.rect(n, ub, Color(Kit.MOVER, 0.18))
				_srect(n, ub, Kit.MOVER, 1.5)
				Kit.label(n, b, "hurtbox", Vector2(ub.end.x + 3.0, ub.position.y + 8.0), Kit.MOVER)
			else:
				_dash_rect(n, ub, Color(Kit.MAGIC, 0.5), 1.0, 2.0)
				Kit.label(n, b, "hurtbox off", Vector2(ub.end.x + 3.0, ub.position.y + 8.0), Kit.MAGIC)
			if visible:
				Kit.mote(n, b, Vector2(dx, dy), PI)
			if invF > 0.0:
				Kit.rect(n, Rect2(dx - 18.0, GY + 12.0, 36.0, 4.0), Color(Kit.MAGIC, 0.25))
				Kit.rect(n, Rect2(dx - 18.0, GY + 12.0, 36.0 * invF / maxf(1.0, iframes), 4.0), Kit.MAGIC)
				Kit.label(n, b, "i-frames %d" % ceili(invF), Vector2(dx, GY + 26.0), Kit.MAGIC, true)
			if flash > 0.0:
				Kit.ring(n, Vector2(b.fx, b.fy), 6.0 + (1.0 - flash) * 18.0, Color(Kit.HOT, flash), 2.0)
			if noteT > 0.0:
				Kit.label(n, b, note, Vector2((ax + dx) / 2.0, GY - BODY_R * 4.5), Kit.HOT if note == "hit" else (Kit.DIM if note == "whiff" else Kit.MAGIC), true)
			_label_right(n, b, "hits %d · whiffs %d" % [int(b.hits), int(b.whiffs)], Vector2(W - 8.0, H - 22.0), Kit.DIM)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"elastic":
			var e: float = D.e
			var tx0: float = b.tx0
			var ty0: float = b.ty0
			var tw: float = b.tw
			var th: float = b.th
			var balls: Array = b.balls
			var last: Dictionary = b.last
			var on: float = last.on
			Kit.rect(n, Rect2(tx0, ty0, tw, th), Color(Kit.GOOD, 0.07))
			_srect(n, Rect2(tx0, ty0, tw, th), Kit.BONE, 3.0)
			var ia: int = last.a
			var ib: int = last.b
			if on > 0.0 and ia >= 0 and ib < balls.size():   # the frozen overlay of the last hit
				var ga := minf(1.0, on * 2.0)            # the web's globalAlpha: folded into every colour
				var Lm := maxf(W, H)
				var lp := Vector2(last.x, last.y)
				var nv := Vector2(last.nx, last.ny)
				var pv := Vector2(-nv.y, nv.x)
				Kit.line(n, lp - nv * Lm, lp + nv * Lm, Color(Kit.BONE, 0.35 * ga), 1.0)
				n.draw_dashed_line(lp - pv * 30.0, lp + pv * 30.0, Color(Kit.DIM, Kit.DIM.a * ga), 1.0, 3.0)
				Kit.dot(n, lp, 3.0, Color(Kit.BONE, ga))
				var sc := 0.22
				var pa: Dictionary = balls[ia]
				var pb: Dictionary = balls[ib]
				var av := Vector2(pa.x, pa.y)
				var bv := Vector2(pb.x, pb.y)
				Kit.arrow(n, av, av + Vector2(last.a1x, last.a1y) * sc, Color(Kit.MOVER, 0.3 * ga))
				Kit.arrow(n, bv, bv + Vector2(last.b1x, last.b1y) * sc, Color(Kit.TARGET, 0.3 * ga))
				Kit.arrow(n, av, av + Vector2(last.a2x, last.a2y) * sc, Color(Kit.MOVER, ga))
				Kit.arrow(n, bv, bv + Vector2(last.b2x, last.b2y) * sc, Color(Kit.TARGET, ga))
				Kit.label(n, b, "n", lp + nv * 22.0 + Vector2(4.0, 0.0), Color(Kit.BONE, ga))
				Kit.label(n, b, "j = %.2f W·m/s" % (float(last.j) / W), lp + Vector2(0.0, -14.0), Color(Kit.HOT, ga), true)
			for i in balls.size():
				var o: Dictionary = balls[i]
				var op := Vector2(o.x, o.y)
				var orr: float = o.r
				if i == 0:
					var ovx: float = o.vx
					Kit.mote(n, b, op, atan2(o.vy, ovx if ovx != 0.0 else 0.001), Kit.MOVER, orr)
				else:
					Kit.dot(n, op, orr, Color(Kit.TARGET, 0.35))
					Kit.ring(n, op, orr, Kit.TARGET, 1.5)
					Kit.label(n, b, "m " + _num(o.m), op + Vector2(0.0, 3.5), Kit.TARGET, true)
			var m0: Dictionary = balls[0]
			var etxt: String = "e = " + _num(e) + " · m₁ " + _num(m0.m)
			if balls.size() > 1:
				var m1: Dictionary = balls[1]
				etxt += " · m₂ " + _num(m1.m)
			_label_right(n, b, etxt, Vector2(W - 8.0, H - 22.0), Kit.DIM)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"obb":
			var A: Dictionary = b.A
			var B: Dictionary = b.B
			var cA: Array = b.cA
			var cB: Array = b.cB
			var cR: Array = b.cR
			var axes: Array = b.axes
			var iv: Array = b.iv
			var sep: int = b.sep
			var mtv: int = b.mtv
			var mtvOv: float = b.mtvOv
			var colliding: bool = b.colliding
			var rawX: float = b.rawX
			var rawY: float = b.rawY
			var Ax: float = A.x
			var Ay: float = A.y
			var Ahw: float = A.hw
			Kit.poly(n, cB, Color(Kit.TARGET, 0.2))     # the scene
			Kit.poly(n, cB, Kit.TARGET, 1.5)
			if colliding:
				Kit.poly(n, cA, Kit.DIM, 1.0)
				Kit.poly(n, cR, Color(Kit.HOT, 0.25))
				Kit.poly(n, cR, Kit.HOT, 1.5)
				Kit.arrow(n, Vector2(rawX, rawY), Vector2(Ax, Ay), Kit.HOT)
				Kit.label(n, b, "push %d px" % roundi(mtvOv), Vector2((rawX + Ax) / 2.0, minf(rawY, Ay) - Ahw - 4.0), Kit.HOT, true)
			elif sep >= 0:
				Kit.poly(n, cA, Color(Kit.MOVER, 0.2))
				Kit.poly(n, cA, Kit.MOVER, 1.5)
				var axis: Vector2 = axes[sep]
				var v: Array = iv[sep]
				var g: float = (maxf(v[0], v[2]) + minf(v[1], v[3])) / 2.0
				var pp := axis * g                       # the separating line: perpendicular to the axis
				var Lm := maxf(W, H)
				var perp := Vector2(-axis.y, axis.x)
				Kit.line(n, pp - perp * Lm, pp + perp * Lm, Kit.GOOD, 1.5)
				Kit.arrow(n, pp, pp + axis * 18.0, Kit.GOOD)
			var rx0: float = W * 0.16                    # the four rulers
			var rx1: float = W * 0.92
			var ry0: float = H * 0.66
			var rh: float = (H - 24.0 - ry0) / 4.0
			for i in 4:
				var y: float = ry0 + rh * (i + 0.5)
				var v: Array = iv[i]
				var v0: float = v[0]
				var v1: float = v[1]
				var v2: float = v[2]
				var v3: float = v[3]
				var lo := minf(v0, v2) - 8.0
				var hi := maxf(v1, v3) + 8.0
				var sc: float = (rx1 - rx0) / maxf(1.0, hi - lo)
				var gap := i == sep
				var ov := minf(v1, v3) - maxf(v0, v2)
				var axis: Vector2 = axes[i]
				_label_right(n, b, OBB_NAMES[i], Vector2(rx0 - 6.0, y + 3.0), Kit.GOOD if gap else (Kit.MOVER if i < 2 else Kit.TARGET))
				Kit.line(n, Vector2(rx0, y), Vector2(rx1, y), Color(Kit.GOOD, 0.5) if gap else Kit.DIM, 1.0)
				Kit.arrow(n, Vector2(rx0 - 26.0, y), Vector2(rx0 - 26.0 + axis.x * 8.0, y + axis.y * 8.0), Kit.DIM)
				Kit.line(n, Vector2(rx0 + (v0 - lo) * sc, y - 2.5), Vector2(rx0 + (v1 - lo) * sc, y - 2.5), Kit.MOVER, 3.0)
				Kit.line(n, Vector2(rx0 + (v2 - lo) * sc, y + 2.5), Vector2(rx0 + (v3 - lo) * sc, y + 2.5), Kit.TARGET, 3.0)
				if gap:
					Kit.line(n, Vector2(rx0 + (minf(v1, v3) - lo) * sc, y), Vector2(rx0 + (maxf(v0, v2) - lo) * sc, y), Kit.GOOD, 3.0)
					Kit.label(n, b, "gap %d" % roundi(-ov), Vector2(rx1 + 2.0, y + 3.0), Kit.GOOD)
				elif colliding and i == mtv:
					Kit.label(n, b, "min %d" % roundi(ov), Vector2(rx1 + 2.0, y + 3.0), Kit.HOT)
			var ttxt: String = "no gap on any axis: collision" if colliding else ("separating axis " + (OBB_NAMES[sep] if sep >= 0 else "?"))
			Kit.label(n, b, ttxt, Vector2(W / 2.0, 14.0), Kit.HOT if colliding else Kit.GOOD, true)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
