extends RefCounted

const Kit := preload("res://scenes/stage/kit.gd")
## PARTICLE MECHANICS — thirteen effects, ported from the web almanac
## (docs/stagecraft.js, the particles family). The machinery under every
## effect. Chapter 06's Sparks taught the four lines of particle physics
## and Waterdrops made a particle's death an event; this family is
## everything that grows around those lines once a game has a hundred
## effects at once: pools and free lists (never allocate in the loop),
## emitters that read a sprite's own pixels, particles that collide and
## pile up, particles that emit particles, force lists, shape emitters,
## depth sorting and soft edges, Voronoi shatter, branching cracks, sword
## ribbons, timelines as data, world-versus-screen layers, and the budget
## that decides who gets to exist. Every card draws the mechanism beside
## the pretty part: the slot grid, the emitter tree, the force chips, the
## playhead, the priority table.
##
## THE PAINTER'S VERSION. Every pool here is an Array of Dictionaries made
## ONCE in init and reused — tick flips `on`, never appends. tick() does
## the maths and draw() reads it (the web interleaves both in frame()), so
## the counts a card labels (alive, resting, per-kind) are tallied in tick
## and stored on b. Where the web reads the hero's pixels off a tiny canvas
## (Disintegrate, Voronoi) this file reads Kit.hero_cells(): the same
## 14 × 19 grid as a list of unit squares. Where the web caches strokes
## into an offscreen layer (Cracks) this file keeps the segment list and
## redraws it. Canvas gradients become per-vertex colours; a clip becomes
## a polygon clipped by arithmetic; globalAlpha becomes colour alpha.

const TITLE := "Particle mechanics"
const BLURB := "the machinery under every effect — pools, pixel emitters, colliding particles, sub-emitters, forces, shape emitters, depth sorting, shatter, cracks, sword arcs, timelines, layers, budgets"
const DEFS := [
	{ "id": "pool", "letter": "P", "name": "Pool",
		"hint": "OBJECT POOLING: N particles made once, lent out by a free list — the slot grid lights while they live, allocations stay 0 — press to burst there",
		"dials": { "size": 64,          # particles made once, at the start
			"burst": 20,                # particles asked for per burst
			"every": 1.5,               # seconds between autopilot bursts
			"gravity": 1.3,             # ×H per second²
			"life": 1.1,                # seconds a particle lives
			"speed": 0.55,              # burst speed, ×H per second
			"steal": false,             # when the free list is empty: false = refuse, true = evict the oldest
			"label": "spawn: i = free.pop() · die: free.push(i) · allocations: 0" },
		"rhyme": { "name": "Puddlepool", "hint": "a pool of twelve that starves in one burst — every newcomer steals the oldest slot, so the tail of each burst eats its head",
			"dials": { "size": 12, "burst": 10, "steal": true } } },
	{ "id": "disintegrate", "letter": "D", "name": "Disintegrate",
		"hint": "EMIT FROM A SPRITE'S PIXELS: pixelsOf reads the hero's opaque pixels; each becomes a particle on a spring chasing its flight path — lagging on the way out, overshooting and snapping home as it reassembles — press to send it there",
		"dials": { "mode": "disintegrate",   # "disintegrate" (feet first, blown away) / "teleport" (a vertical streak) / "assemble" (rain in, top first)
			"hold": 1.6,                # seconds whole between trips
			"fly": 1.2,                 # seconds for the pixels to leave, and again to arrive
			"scatter": 0.45,            # how far the pixels roam, ×H
			"wind": 0.5,                # the disintegrate drift, ×W
			"spring": 80,                # each pixel's position spring: stiffness (ω = √spring ≈ 9 /s)
			"damp": 0.3,                 # its damping as a fraction of critical — under 1, so pixels overshoot and snap home
			"label": "pixelsOf(sprite): one particle per opaque pixel · target: k = ease(p·1.8 − delay) · x'' = spring·(target − x) − c·x'" },
		"rhyme": { "name": "Dustup", "hint": "the assemble mode, slowly: the pixels rain in from a wide cloud above and lock in top row first — a summoning",
			"dials": { "mode": "assemble", "fly": 2, "scatter": 0.6 } } },
	{ "id": "hail", "letter": "H", "name": "Hail",
		"hint": "PARTICLES THAT COLLIDE: each stone tests the ground, two blocks and a slope, bounces by e, rubs by μ, piles up, then rain — press to drop hail there",
		"dials": { "n": 200,            # the pool
			"rate": 45,                 # stones per second from the sky
			"gravity": 1.7,             # ×H per second²
			"bounce": 0.5,              # restitution e: the share of normal speed kept
			"friction": 0.75,           # μ: the share of tangential speed kept per hit
			"bounces": 8,               # hits before a stone gives up
			"melt": 2.5,                # seconds a resting stone lasts
			"rainAfter": 6,             # seconds of hail, then as many of rain, forever
			"size": 2.2,                # stone radius, px at card size
			"label": "v' = v − (1+e)(v·n)n · vₜ ·= μ · rest when |v| < ε" },
		"rhyme": { "name": "Hailstorm", "hint": "three times the stones, heavier, and each one dies on its first bounce — a hard rattle instead of a pile",
			"dials": { "rate": 140, "gravity": 2.6, "bounces": 1 } } },
	{ "id": "subemitter", "letter": "S", "name": "Subemitter",
		"hint": "SUB-EMITTERS: a rocket that emits smoke, dies into sparks that emit embers and pop — the emitter tree drawn — press to launch a rocket there",
		"dials": { "depth": 2,          # levels of the tree allowed to emit (the rocket is level 0)
			"every": 2.4,               # seconds between autopilot launches
			"speed": 0.9,               # rocket speed, ×H per second
			"gravity": 1.2,             # on sparks and embers, ×H per second²
			"chain": false,             # sparks die into more sparks instead of a pop
			"tree": { "rocket": { "trail": "smoke", "rate": 45, "death": "spark", "burst": 18 },
				"spark": { "trail": "ember", "rate": 16, "death": "pop", "burst": 1 },
				"smoke": {}, "ember": {}, "pop": {} },
			"label": "p.acc += rate·dt → emit(trail) · on death → burst(kind, n) · level < depth" },
		"rhyme": { "name": "Sparklers", "hint": "sparks that die into sparks, three levels deep — the same tree with chain on and one more level of depth; the pool fills and refuses",
			"dials": { "depth": 3, "chain": true } } },
	{ "id": "vortex", "letter": "V", "name": "Vortex",
		"hint": "FORCE LISTS: wind, vortex, attractor, turbulence — one list per emitter, summed into one acceleration; drawn as chips — press to move the vortex there",
		"dials": { "n": 220,            # the pool
			"rate": 70,                 # particles per second from the left edge
			"life": 3,                  # seconds each lives
			"drag": 0.6,                # velocity bleed per second
			"radius": 0.36,             # a positional force's reach, ×H
			"forces": [ { "kind": "wind", "strength": 0.35 },                          # a constant push to the right, ×H/s²
				{ "kind": "vortex", "strength": 1.6, "x": 0.55, "y": 0.42 },         # a swirl about a point (x, y are fractions of W, H)
				{ "kind": "attract", "strength": 0.5, "x": 0.84, "y": 0.62 },        # a pull toward a point; it swallows what arrives
				{ "kind": "turbulence", "strength": 0.9 } ],                          # a noise field, no centre
			"label": "a = Σ force(kind, strength, p) · v += a·dt · v ·= 1 − drag·dt" },
		"rhyme": { "name": "Vacuum", "hint": "attractors only, and strong: two drains and no wind — everything that spawns curves in and is swallowed; the drained counter is the whole picture",
			"dials": { "forces": [ { "kind": "attract", "strength": 2.4, "x": 0.5, "y": 0.42 }, { "kind": "attract", "strength": 1.4, "x": 0.82, "y": 0.68 } ], "rate": 110 } } },
	{ "id": "emitters", "letter": "E", "name": "Emitters",
		"hint": "SHAPE EMITTERS: spawn points sample an outlined shape — point, line, ring, rect, arc, path — and launch along its normal — press to cycle the shape",
		"dials": { "shape": "point",    # the starting shape
			"shapes": ["point", "line", "ring", "rect", "arc", "path"],   # the cycle
			"every": 2.4,               # seconds per shape on autopilot
			"rate": 90,                 # particles per second
			"life": 1.3,                # seconds each lives
			"rise": 0.22,               # launch speed along the normal, ×H per second
			"size": 0.2,                # the shape's radius, ×H
			"colour": "#FFE9A8",
			"formula": { "point": "p = c", "line": "p = c + (2u − 1)·R·x̂", "ring": "p = c + R·(cos θ, sin θ)", "rect": "p = c + (2u − 1, 2v − 1)·½size",
				"arc": "θ = θ₀ + u·(θ₁ − θ₀) · p = c + R·(cos θ, sin θ)", "path": "p = B(u) = Σ Bᵢ(u)·Pᵢ · n̂ = ⟂B′(u)" },
			"label": "spawn: (p, n̂) = shape(u) · v = n̂·rise" },
		"rhyme": { "name": "Edgeglow", "hint": "ring and arc only, slow and violet, the motes barely leaving the line — a portal breathing rather than a fountain",
			"dials": { "shapes": ["ring", "arc"], "rise": 0.05, "colour": "#C9A0F5" } } },
	{ "id": "zsort", "letter": "Z", "name": "Zsort",
		"hint": "Z-SORT & SOFT PARTICLES: the same puffs twice — left in pool order with a hard floor cut, right sorted by z and faded at the ground — press to scatter",
		"dials": { "n": 70,             # puffs (drawn twice)
			"size": 1,                  # ×
			"alpha": 0.6,               # a near puff's strength
			"soft": 0.1,                # the fade band above the floor, ×H
			"sink": 0.035,              # downward drift, ×H per second
			"life": 7,                  # seconds before a puff is respawned
			"label": "order = sort(z) far → near · α(y) → 0 as y → floor" },
		"rhyme": { "name": "Zfog", "hint": "many faint puffs, large and slow — a fog bank, where the left half's popping order and hard floor line are the whole tell",
			"dials": { "n": 160, "alpha": 0.16, "size": 1.9 } } },
	{ "id": "voronoi", "letter": "V", "name": "Voronoi",
		"hint": "VORONOI SHATTER: seeds claim the sprite's pixel blocks by nearest seed; each cell flies as one rigid piece from the impact — press to shatter there",
		"dials": { "target": "hero",    # "hero" (the sprite's own pixels) / "pane" (a sheet of glass)
			"cells": 9,                 # seeds, so pieces
			"fling": 0.7,               # ×H per second, away from the impact
			"spin": 6,                  # radians per second, at most
			"gravity": 1.6,             # ×H per second²
			"hold": 2.2,                # seconds whole before the autopilot breaks it
			"fade": 1.8,                # seconds the pieces last
			"tinkle": false,            # glass tones on the break (after the first press)
			"label": "cell(b) = argminᵢ |b − seedᵢ| · piece = rigid body of its blocks" },
		"rhyme": { "name": "Vitrine", "hint": "a sheet of glass in thirty-six small cells, with a tinkle after your first press — the same seeds and pieces, a museum case instead of a hero",
			"dials": { "target": "pane", "cells": 36, "tinkle": true } } },
	{ "id": "cracks", "letter": "C", "name": "Cracks",
		"hint": "CRACK GENERATION: a branching random walk from the impact — each tip steps, jitters, thins by decay and sometimes forks — press to crack there",
		"dials": { "surface": "stone",  # "stone" / "glass" / "ice": the slab and the crack's colour
			"branches": 10,             # live tips allowed at once
			"start": 4,                 # tips a fresh impact begins with
			"decay": 0.94,              # width kept per step
			"fork": 0.12,               # chance per step that a tip forks
			"jitter": 0.5,              # radians of wander per step
			"speed": 150,               # px per second a tip advances, at card size
			"width": 2.6,               # starting width, px
			"every": 2.4,               # seconds between the autopilot's impacts
			"hits": 3,                  # impacts before the slab is replaced
			"label": "tip: p += step·(cos θ, sin θ) · θ += U(−j, j) · w ·= decay · fork with P" },
		"rhyme": { "name": "Crazing", "hint": "thin ice: many fine tips that fork often and thin fast — a web of hairlines instead of a few fat fractures",
			"dials": { "surface": "ice", "branches": 22, "fork": 0.3, "width": 1.4 } } },
	{ "id": "arc", "letter": "A", "name": "Arc",
		"hint": "SWORD ARC RIBBON: the blade's hilt and tip sampled into a ring of N pairs as it swings; quads between neighbours fade by age — press to swing at it",
		"dials": { "n": 24,             # sample pairs kept
			"step": 0.12,               # radians the blade must turn before a new sample
			"fade": 0.32,               # seconds a sample lasts
			"rise": 0,                  # samples drift upward, ×H per second
			"colour": "#8AD9F5",
			"swing": 0.26,              # seconds per swing
			"every": 1.3,               # seconds between autopilot swings
			"blade": 0.4,               # blade length, ×H
			"hilt": 0.09,               # the hilt's distance from the pivot, ×H
			"label": "quad(hilt[i], tip[i], tip[i+1], hilt[i+1]) · α = 1 − age ÷ fade" },
		"rhyme": { "name": "Afterburn", "hint": "a fiery ribbon that lingers four times longer and rises as it fades — the same quads, wearing smoke",
			"dials": { "fade": 1.3, "rise": 0.12, "colour": "#F58A5A" } } },
	{ "id": "keyframes", "letter": "K", "name": "Keyframes",
		"hint": "EFFECT SEQUENCING: the effect is data — [{at, do}, …] — and one runner fires each cue as the playhead passes it; timeline drawn — press to play there",
		"dials": { "seq": [ { "at": 0, "do": "flash" }, { "at": 0.05, "do": "burst" }, { "at": 0.1, "do": "smoke" }, { "at": 0.2, "do": "ring" } ],
			"every": 2.4,               # seconds between autopilot plays
			"speed": 1,                 # playback rate
			"tail": 0.5,                # seconds of timeline shown after the last cue
			"label": "while (seq[i].at ≤ t) fire(seq[i++].do) · t += dt·speed" },
		"rhyme": { "name": "Kickoff", "hint": "the same runner on a slower, spaced-out list with a double ring at the end — the cues are readable one at a time",
			"dials": { "seq": [ { "at": 0, "do": "flash" }, { "at": 0.3, "do": "burst" }, { "at": 0.6, "do": "smoke" }, { "at": 0.9, "do": "ring" }, { "at": 1.15, "do": "ring" } ], "every": 3.4 } } },
	{ "id": "layers", "letter": "L", "name": "Layers", "drag": true,
		"hint": "SCREEN vs WORLD SPACE: a world-parented spark scrolls with the camera, the HUD flash does not, a misparented twin slides off — drag to pan the camera",
		"dials": { "space": "world",    # where hit sparks live: "world" (draw at x − cam) / "screen" (draw at x) / "double" (x − 2·Δcam, the classic bug)
			"ghost": "double",          # a faint twin spawned in a mistaken space, or "none"
			"pan": 0.28,                # the autopilot's camera sway, ×W
			"every": 1.5,               # seconds between hits
			"run": 0.22,                # the hero's speed, ×W per second
			"label": "world: draw(x − cam) · screen: draw(x) · double: draw(x − 2·Δcam)" },
		"rhyme": { "name": "Lockstep", "hint": "the wrong version: sparks kept in screen space, no twin — they stay where they were born while the hero and the world slide out from under them",
			"dials": { "space": "screen", "ghost": "none" } } },
	{ "id": "budget", "letter": "B", "name": "Budget",
		"hint": "EFFECT BUDGETS: every emitter has a priority; the meter counts the living, past the budget the worst priority is culled first — press to spawn a burst",
		"dials": { "budget": 150,       # particles allowed alive at once (the pool holds 300)
			"burst": 110,               # an explosion's size
			"ambient": 45,              # dust per second, the lowest priority
			"every": 5,                 # seconds between autopilot explosions
			"table": [ { "name": "hero hits", "pri": 1 }, { "name": "enemy hits", "pri": 2 }, { "name": "explosion", "pri": 3 }, { "name": "ambient dust", "pri": 4 } ],
			"label": "spawn(p): alive < budget ? slot : cull(worst > p) ? slot : refuse" },
		"rhyme": { "name": "Bargain", "hint": "a budget of thirty: the dust never gets a slot, the enemy's hits are culled by every explosion, and only the hero's own sparks always land",
			"dials": { "budget": 30, "burst": 60 } } },
]

const FAINT := Color(0.91, 0.898, 0.957, 0.55)   # the web label's default ink
const SLOT_DIM := Color(201.0 / 255.0, 196.0 / 255.0, 228.0 / 255.0, 0.16)   # an idle pool slot, the ground's hatching
const AMBER := Color(245.0 / 255.0, 193.0 / 255.0, 105.0 / 255.0)             # the web's #F5C169 warnings and normals
const SMOKE := Color(160.0 / 255.0, 160.0 / 255.0, 190.0 / 255.0)
const ICE_DOT := Color(220.0 / 255.0, 240.0 / 255.0, 1.0)
const ICE_REST := Color(200.0 / 255.0, 230.0 / 255.0, 1.0)
const RAIN := Color(170.0 / 255.0, 210.0 / 255.0, 1.0)
const WOOD := Color("8A6A3E")
const SLAB_INK := Color("5E5880")
const SUB_N := 300           # Subemitter's pool
const EMIT_N := 200          # Emitters' pool
const KEY_N := 180           # Keyframes' pool
const LAYER_N := 120         # Layers' pool
const BUDGET_N := 300        # Budget's pool
const CRACK_MAX := 2500      # segments Cracks keeps (the web's layer had no cap; the painter redraws them all)

# ---------------------------------------------------------------- small maths

## The web kit's ease(): a clamped smoothstep.
static func _ease(k: float) -> float:
	k = clampf(k, 0.0, 1.0)
	return k * k * (3.0 - 2.0 * k)

## c with its alpha replaced (the web's rgba(c, a)).
static func _al(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, a)

## The web's hsl(h°, s, l, a) as a Color.
static func _hsl(hdeg: float, sat: float, lig: float, a: float = 1.0) -> Color:
	var q := lig + sat * minf(lig, 1.0 - lig)          # HSL → HSV: v = l + s·min(l, 1 − l), s_v = 2(1 − l / v)
	var sv := 0.0 if q <= 0.0 else 2.0 * (1.0 - lig / q)
	return Color.from_hsv(fmod(hdeg, 360.0) / 360.0, sv, q, a)

## The web label's "right" alignment: measure, then draw ending at p.x.
static func _label_r(n: CanvasItem, b: Dictionary, txt: String, p: Vector2, col: Color = FAINT) -> void:
	var f := ThemeDB.fallback_font
	var w: float = f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	Kit.label(n, b, txt, Vector2(p.x - w, p.y), col)

## setLineDash([3, 3]) for one straight line: 3 px on, 3 px off.
static func _dash_line(n: CanvasItem, a: Vector2, c: Vector2, col: Color) -> void:
	var d := a.distance_to(c)
	if d < 0.5:
		return
	var dir := (c - a) / d
	var x := 0.0
	while x < d:
		n.draw_line(a + dir * x, a + dir * minf(d, x + 3.0), col, 1.0)
		x += 6.0

## setLineDash([3, 3]) along an arc: dashes of ~3 px.
static func _dash_arc(n: CanvasItem, c: Vector2, r: float, a0: float, a1: float, col: Color) -> void:
	var L := absf(a1 - a0) * maxf(1.0, r)
	var nn := maxi(2, int(L / 6.0))
	for i in nn:
		var u0 := a0 + (a1 - a0) * (i / float(nn))
		var u1 := a0 + (a1 - a0) * ((i + 0.5) / float(nn))
		n.draw_line(c + Vector2(cos(u0), sin(u0)) * r, c + Vector2(cos(u1), sin(u1)) * r, col, 1.0)

## A circle as a polygon of nn vertices.
static func _circle_pts(c: Vector2, r: float, nn: int = 24) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in nn:
		var a := i / float(nn) * TAU
		out.append(c + Vector2(cos(a), sin(a)) * maxf(0.1, r))
	return out

## Sutherland–Hodgman against one axis-aligned edge: keep the part of the
## polygon where (x if axis 0 else y) <= v (keep_less) or >= v. The web's
## ctx.clip(rect) for a puff, done by arithmetic.
static func _clip_poly(pts: PackedVector2Array, axis: int, v: float, keep_less: bool) -> PackedVector2Array:
	var out := PackedVector2Array()
	var m := pts.size()
	if m == 0:
		return out
	for i in m:
		var p := pts[i]
		var q := pts[(i + 1) % m]
		var pv := p.x if axis == 0 else p.y
		var qv := q.x if axis == 0 else q.y
		var pin := pv <= v if keep_less else pv >= v
		var qin := qv <= v if keep_less else qv >= v
		if pin:
			out.append(p)
		if pin != qin:
			var k := (v - pv) / (qv - pv)
			out.append(p + (q - p) * k)
	return _clean_poly(out)

## A polygon the triangulator will accept: no near-duplicate consecutive
## vertices (a vertex exactly on a clip edge produces one), and a real
## area (a circle grazing the floor leaves a hairline sliver). Returns an
## empty array for a degenerate one, so callers skip the draw.
static func _clean_poly(pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		if out.is_empty() or out[out.size() - 1].distance_squared_to(p) > 1e-4:
			out.append(p)
	if out.size() >= 2 and out[0].distance_squared_to(out[out.size() - 1]) <= 1e-4:
		out.remove_at(out.size() - 1)
	if out.size() < 3:
		return PackedVector2Array()
	var area := 0.0                                    # the shoelace, twice
	for i in out.size():
		var a := out[i]
		var c := out[(i + 1) % out.size()]
		area += a.x * c.y - c.x * a.y
	if absf(area) < 0.2:
		return PackedVector2Array()
	return out

## One blank particle for every pool in the family: the superset of the
## fields the cards use, so a pool is one shape and never grows.
static func _blank() -> Dictionary:
	return { "x": 0.0, "y": 0.0, "vx": 0.0, "vy": 0.0, "age": 0.0, "life": 1.0, "born": 0.0, "on": false,
		"kind": "", "level": 0, "acc": 0.0, "hits": 0, "rest": 0.0, "rain": false, "pri": 4,
		"space": "world", "cam0": 0.0, "ghost": false, "z": 0.0, "r": 1.0 }

static func _make_pool(nn: int) -> Array:
	var out: Array = []
	for _i in nn:
		out.append(_blank())
	return out

## The first idle slot of a pool, or -1.
static func _free_slot(pool: Array) -> int:
	for i in pool.size():
		var p: Dictionary = pool[i]
		if not p.on:
			return i
	return -1

# ---------------------------------------------------------------- pool

## The whole trick: a slot from the free list; refuse or steal when it is dry.
static func _pool_spawn(b: Dictionary, x: float, y: float) -> void:
	var D: Dictionary = b.D
	var H: float = b.h
	var pool: Array = b.pool
	var free: Array = b.free
	b.naive += 1                                       # what new Particle() would have cost
	var i := -1
	if free.size() > 0:
		i = free.pop_back()                            # the whole trick
	elif D.steal:
		var best := -1
		var bt := INF
		for k in pool.size():
			var pk: Dictionary = pool[k]
			if pk.on and pk.born < bt:
				bt = pk.born
				best = k
		if best < 0:
			return
		i = best
		b.stolen += 1
	else:
		b.refused += 1
		return
	var p: Dictionary = pool[i]
	var a := randf_range(0.0, TAU)
	var sp: float = randf_range(0.2, 1.0) * H * D.speed
	p.x = x
	p.y = y
	p.vx = cos(a) * sp
	p.vy = sin(a) * sp - H * 0.2
	p.age = 0.0
	p.life = D.life * randf_range(0.6, 1.0)
	p.born = b.clock
	p.on = true

static func _pool_burst(b: Dictionary, x: float, y: float) -> void:
	var D: Dictionary = b.D
	for _k in int(D.burst):
		_pool_spawn(b, x, y)
	b.lastX = x
	b.lastY = y
	b.flash = 1.0

# ---------------------------------------------------------------- disintegrate

## Every pixel's scattered spot and delay for this trip.
static func _dis_plan(b: Dictionary) -> void:
	var D: Dictionary = b.D
	var W: float = b.w
	var H: float = b.h
	var un: float = Kit.hero_unit(b)
	var mode: String = D.mode
	for q in b.px:
		var qd: Dictionary = q
		var ox: float = qd.ox
		var oy: float = qd.oy
		var j: float = qd.j
		var row: float = qd.row
		if mode == "teleport":
			qd.sx = ox * un * 0.4
			qd.sy = -H * D.scatter - j * H * 0.3
			qd.d = j * 0.2
		elif mode == "assemble":
			qd.sx = randf_range(-1.0, 1.0) * W * 0.3
			qd.sy = -H * D.scatter * randf_range(0.5, 1.4)
			qd.d = (1.0 - row) * 0.6 + j * 0.2
		else:
			qd.sx = ox * un + W * D.wind * randf_range(0.4, 1.0) + Kit.noise(j * 9.0) * W * 0.1
			qd.sy = -H * D.scatter * randf_range(0.3, 1.0) + oy * un * 0.5
			qd.d = (1.0 - row) * 0.6 + j * 0.2

static func _dis_go(b: Dictionary) -> void:
	if b.phase == 0:
		b.phase = 1
		b.p = 0.0
		_dis_plan(b)

# ---------------------------------------------------------------- hail

static func _hail_spawn(b: Dictionary, x: float, y: float, rain: bool) -> void:
	var W: float = b.w
	var H: float = b.h
	var i := _free_slot(b.pool)
	if i < 0:
		return
	var p: Dictionary = b.pool[i]
	p.x = x
	p.y = y
	p.vx = randf_range(-0.05, 0.05) * W
	p.vy = H * 1.2 if rain else randf_range(0.0, 0.2) * H
	p.hits = 0
	p.rest = 0.0
	p.rain = rain
	p.on = true

## Push out along n, reflect the normal part by e, rub the tangent by μ.
static func _hail_collide(b: Dictionary, p: Dictionary, nx: float, ny: float, push: float) -> bool:
	var D: Dictionary = b.D
	var H: float = b.h
	p.x += nx * push
	p.y += ny * push
	var vn: float = p.vx * nx + p.vy * ny
	if vn < 0.0:
		var tx := -ny
		var ty := nx
		var vt: float = (p.vx * tx + p.vy * ty) * D.friction
		var vn2: float = 0.0 if absf(vn) < H * 0.06 else -vn * D.bounce   # too slow to bounce: settle
		p.vx = vn2 * nx + vt * tx
		p.vy = vn2 * ny + vt * ty
		p.hits += 1
		var hit: Dictionary = b.hit
		hit.x = p.x
		hit.y = p.y
		hit.nx = nx
		hit.ny = ny
		hit.age = 0.0
	return true

# ---------------------------------------------------------------- subemitter

static func _sub_spawn(b: Dictionary, kind: String, level: int, x: float, y: float, vx: float, vy: float) -> Dictionary:
	var i := _free_slot(b.pool)
	if i < 0:
		b.refused += 1
		return {}
	var p: Dictionary = b.pool[i]
	p.kind = kind
	p.level = level
	p.x = x
	p.y = y
	p.vx = vx
	p.vy = vy
	p.age = 0.0
	p.acc = 0.0
	p.on = true
	match kind:
		"rocket":
			p.life = 9.0
		"smoke":
			p.life = randf_range(0.7, 1.2)
		"spark":
			p.life = randf_range(0.5, 0.9)
		"ember":
			p.life = randf_range(0.25, 0.45)
		_:
			p.life = 0.25
	return p

static func _sub_launch(b: Dictionary, x: float, y: float) -> void:
	var D: Dictionary = b.D
	var W: float = b.w
	var H: float = b.h
	var GY: float = b.gy
	var x0 := W * 0.2
	var y0 := GY
	var dx := x - x0
	var dy := y - y0
	var d := maxf(1.0, sqrt(dx * dx + dy * dy))
	var v: float = H * D.speed
	var p := _sub_spawn(b, "rocket", 0, x0, y0, dx / d * v, dy / d * v)
	if not p.is_empty():
		p.life = d / v                                 # it dies exactly at the target
	b.tx = x
	b.ty = y

## Death is an event: the tree says what a kind bursts into.
static func _sub_die(b: Dictionary, p: Dictionary) -> void:
	var D: Dictionary = b.D
	var H: float = b.h
	var tree: Dictionary = D.tree
	var node: Dictionary = tree.get(p.kind, {})
	var chain: bool = p.kind == "spark" and D.chain
	var kind: String = "spark" if chain else str(node.get("death", ""))
	var nn: int = 3 if chain else int(node.get("burst", 0))
	if kind == "" or p.level >= int(D.depth):
		return
	for _k in nn:
		var a := randf_range(0.0, TAU)
		var sp: float = (randf_range(0.2, 0.7) if kind == "spark" else 0.05) * H
		_sub_spawn(b, kind, p.level + 1, p.x, p.y, cos(a) * sp, sin(a) * sp - (H * 0.1 if kind == "spark" else 0.0))

# ---------------------------------------------------------------- vortex

## One force's push on p, written into out.ax / out.ay; false = swallowed.
static func _vx_apply(b: Dictionary, f: Dictionary, p: Dictionary, tt: float, out: Dictionary) -> bool:
	var D: Dictionary = b.D
	var H: float = b.h
	var R: float = H * D.radius
	out.ax = 0.0
	out.ay = 0.0
	var kind: String = f.kind
	var strength: float = f.strength
	if kind == "wind":
		out.ax = strength * H
		return true
	if kind == "turbulence":
		var k := 3.4 / H
		out.ax = Kit.noise2(p.x * k + tt * 0.5, p.y * k) * strength * H * 2.0
		out.ay = Kit.noise2(p.x * k + 40.0, p.y * k - tt * 0.5) * strength * H * 2.0
		return true
	var dx: float = f.x - p.x
	var dy: float = f.y - p.y
	var d := maxf(1.0, sqrt(dx * dx + dy * dy))
	var fall := clampf(1.4 - d / R, 0.0, 1.0)
	if kind == "attract":
		if d < 3.0 + strength * 2.0:
			return false                               # it arrived: drained
		out.ax = dx / d * strength * H * 2.5 * fall
		out.ay = dy / d * strength * H * 2.5 * fall
		return true
	out.ax = (-dy / d * strength * 2.5 + dx / d * strength * 0.5) * H * fall   # vortex: mostly sideways, a little in
	out.ay = (dx / d * strength * 2.5 + dy / d * strength * 0.5) * H * fall
	return true

static func _vx_col(kind: String) -> Color:
	match kind:
		"wind":
			return Kit.BONE
		"vortex":
			return Kit.WATER
		"attract":
			return Kit.MAGIC
		"turbulence":
			return Kit.GOOD
	return Kit.INK

# ---------------------------------------------------------------- emitters

## A point on the shape (about the centre) and its normal, into b.out.
static func _em_sample(b: Dictionary, shape: String) -> void:
	var R: float = b.R
	var out: Dictionary = b.out
	var Bp: Array = b.B
	var u0 := randf()
	out.nx = 0.0
	out.ny = -1.0
	if shape == "line":
		out.x = (u0 * 2.0 - 1.0) * R * 1.3
		out.y = 0.0
	elif shape == "ring":
		var a := u0 * TAU
		out.x = cos(a) * R
		out.y = sin(a) * R
		out.nx = cos(a)
		out.ny = sin(a)
	elif shape == "rect":
		out.x = (u0 * 2.0 - 1.0) * R * 1.3
		out.y = (randf() * 2.0 - 1.0) * R * 0.6
	elif shape == "arc":
		var a := PI + u0 * PI
		out.x = cos(a) * R
		out.y = sin(a) * R
		out.nx = cos(a)
		out.ny = sin(a)
	elif shape == "path":
		var v := 1.0 - u0
		var b0 := v * v * v
		var b1 := 3.0 * u0 * v * v
		var b2 := 3.0 * u0 * u0 * v
		var b3 := u0 * u0 * u0
		var P0: Vector2 = Bp[0]
		var P1: Vector2 = Bp[1]
		var P2: Vector2 = Bp[2]
		var P3: Vector2 = Bp[3]
		var pt := (P0 * b0 + P1 * b1 + P2 * b2 + P3 * b3) * R
		out.x = pt.x
		out.y = pt.y
		var dv := (P1 - P0) * (3.0 * v * v) + (P2 - P1) * (6.0 * v * u0) + (P3 - P2) * (3.0 * u0 * u0)
		var L := maxf(1e-6, dv.length())
		out.nx = -dv.y / L
		out.ny = dv.x / L
		if out.ny > 0.0:                               # the upward-facing normal
			out.nx = -out.nx
			out.ny = -out.ny
	else:
		out.x = 0.0
		out.y = 0.0

static func _em_next(b: Dictionary) -> void:
	var D: Dictionary = b.D
	var shapes: Array = D.shapes
	b.si = (b.si + 1) % maxi(1, shapes.size())
	b.timer = 0.0

# ---------------------------------------------------------------- zsort

static func _z_spawn(b: Dictionary, p: Dictionary, fresh: bool) -> void:
	var D: Dictionary = b.D
	var W: float = b.w
	var H: float = b.h
	var GY: float = b.gy
	p.x = randf_range(0.0, W / 2.0)
	p.y = randf_range(H * 0.25, GY + H * 0.03) if fresh else randf_range(H * 0.2, H * 0.45)
	p.z = randf()
	p.vx = randf_range(-0.02, 0.02) * W
	p.vy = 0.0
	p.age = randf_range(0.0, D.life if fresh else 0.5)
	p.r = H * 0.05 * D["size"] * (0.4 + p.z * 1.1)

# ---------------------------------------------------------------- voronoi

## New seeds, and every block re-assigned to its nearest; each piece keeps
## the list of its blocks (rebuilt here, once per shatter, not per frame).
static func _vor_reseed(b: Dictionary) -> void:
	var D: Dictionary = b.D
	var cells: int = D.cells
	var seeds: Array = b.seeds
	var pieces: Array = b.pieces
	var blocks: Array = b.blocks
	for i in cells:
		var sd: Dictionary = seeds[i]
		sd.x = randf_range(-7.0, 7.0)
		sd.y = randf_range(-18.0, 0.0)
	for k in cells:
		var pc: Dictionary = pieces[k]
		pc.cx = 0.0
		pc.cy = 0.0
		pc.n = 0
		(pc.idx as Array).clear()
	for bi in blocks.size():
		var q: Dictionary = blocks[bi]
		var best := 0
		var bd := INF
		for i in cells:
			var sd: Dictionary = seeds[i]
			var dx: float = q.ox + 0.5 - sd.x
			var dy: float = q.oy + 0.5 - sd.y
			var d := dx * dx + dy * dy
			if d < bd:
				bd = d
				best = i
		q.cell = best
		var pb: Dictionary = pieces[best]
		pb.cx += q.ox + 0.5
		pb.cy += q.oy + 0.5
		pb.n += 1
		(pb.idx as Array).append(bi)
	for k in cells:
		var pc: Dictionary = pieces[k]
		var nn := maxi(1, pc.n)
		pc.cx /= nn
		pc.cy /= nn

static func _vor_shatter(b: Dictionary, x: float, y: float) -> void:
	var D: Dictionary = b.D
	var H: float = b.h
	var GY: float = b.gy
	var un: float = Kit.hero_unit(b)
	var hx: float = b.hx
	b.ix = x
	b.iy = y
	b.phase = 1
	b.age = 0.0
	for k in int(D.cells):
		var p: Dictionary = b.pieces[k]
		p.x = hx + p.cx * un
		p.y = GY + p.cy * un
		p.rot = 0.0
		p.bounced = false
		var dx: float = p.x - x
		var dy: float = p.y - y
		var d := maxf(4.0, sqrt(dx * dx + dy * dy))
		var sp: float = H * D.fling * randf_range(0.5, 1.0) / (1.0 + d / (H * 0.25))
		p.vx = dx / d * sp
		p.vy = dy / d * sp - H * 0.25
		p.vr = randf_range(-1.0, 1.0) * D.spin
	if b.armed_sound and D.tinkle:                     # glass tones, only after the first press
		for k in 3:
			Kit.tone({ "freq": randf_range(1800.0, 3400.0), "dur": 0.14, "type": "sine", "vol": 0.07, "at": k * 0.05 })

# ---------------------------------------------------------------- cracks

static func _crack_look(surface: String) -> Dictionary:
	match surface:
		"glass":
			return { "fill": Color(140.0 / 255.0, 190.0 / 255.0, 240.0 / 255.0, 0.3), "crack": Color(1.0, 1.0, 1.0, 0.9), "edge": Color(1.0, 1.0, 1.0, 0.12) }
		"ice":
			return { "fill": Color(200.0 / 255.0, 232.0 / 255.0, 1.0, 0.55), "crack": Color(1.0, 1.0, 1.0, 0.95), "edge": Color(120.0 / 255.0, 180.0 / 255.0, 240.0 / 255.0, 0.35) }
	return { "fill": Color("6E6890"), "crack": Color(20.0 / 255.0, 16.0 / 255.0, 32.0 / 255.0, 0.95), "edge": Color(0.91, 0.898, 0.957, 0.35) }

static func _crack_in_slab(b: Dictionary, x: float, y: float) -> bool:
	var slab: Rect2 = b.slab
	return x > slab.position.x and x < slab.end.x and y > slab.position.y and y < slab.end.y

static func _crack_impact(b: Dictionary, x: float, y: float) -> void:
	var D: Dictionary = b.D
	if b.fadeK < 1.0:
		return
	var slab: Rect2 = b.slab
	var k: float = b.k
	x = clampf(x, slab.position.x + 4.0, slab.end.x - 4.0)
	y = clampf(y, slab.position.y + 4.0, slab.end.y - 4.0)
	var placed := 0
	var tips: Array = b.tips
	for i in tips.size():
		if placed >= int(D.start):
			break
		var tp: Dictionary = tips[i]
		if not tp.on:
			tp.x = x
			tp.y = y
			tp.a = randf_range(0.0, TAU)
			tp.w = D.width * k
			tp.on = true
			placed += 1
	b.hits += 1
	b.timer = 0.0
	(b.dots as Array).append(Vector2(x, y))            # the impact's dot on the layer

## One step of a tip: a segment onto the layer, then the walk, the thinning, the fork.
static func _crack_step(b: Dictionary, tp: Dictionary) -> void:
	var D: Dictionary = b.D
	var k: float = b.k
	var st := 4.0 * k
	var nx: float = tp.x + cos(tp.a) * st
	var ny: float = tp.y + sin(tp.a) * st
	var segs: Array = b.segs
	if segs.size() < CRACK_MAX:
		segs.append([tp.x, tp.y, nx, ny, tp.w])
	tp.x = nx
	tp.y = ny
	tp.a += randf_range(-D.jitter, D.jitter)
	tp.w *= D.decay
	b.nseg += 1
	if tp.w < 0.35 or not _crack_in_slab(b, nx, ny) or segs.size() >= CRACK_MAX:
		tp.on = false
		return
	if randf() < D.fork:                               # a fork: a thinner child at an angle
		var tips: Array = b.tips
		for i in tips.size():
			var c: Dictionary = tips[i]
			if not c.on:
				c.x = nx
				c.y = ny
				c.a = tp.a + (-1.0 if randf() < 0.5 else 1.0) * randf_range(0.4, 1.1)
				c.w = tp.w * 0.7
				c.on = true
				tp.w *= 0.85
				break

# ---------------------------------------------------------------- arc

static func _arc_angle(b: Dictionary) -> float:
	return b.a0 + (b.a1 - b.a0) * _ease(b.k)

static func _arc_begin(b: Dictionary, from: float, to: float) -> void:
	b.a0 = from
	b.a1 = to
	b.k = 0.0
	b.timer = 0.0

# ---------------------------------------------------------------- keyframes

static func _key_spawn(b: Dictionary, kind: String, x: float, y: float, nn: int, sp: float) -> void:
	var H: float = b.h
	var pool: Array = b.pool
	var k := 0
	for i in pool.size():
		if k >= nn:
			break
		var p: Dictionary = pool[i]
		if p.on:
			continue
		var a := randf_range(0.0, TAU)
		var v := randf_range(0.3, 1.0) * sp
		p.kind = kind
		p.x = x
		p.y = y
		p.vx = cos(a) * v
		p.vy = sin(a) * v - (H * 0.1 if kind == "smoke" else 0.0)
		p.age = 0.0
		p.life = randf_range(0.8, 1.4) if kind == "smoke" else randf_range(0.4, 0.8)
		p.on = true
		k += 1

static func _key_oldest(list: Array) -> Dictionary:
	var o := 0
	for i in range(1, list.size()):
		var li: Dictionary = list[i]
		var lo: Dictionary = list[o]
		if li.age > lo.age:
			o = i
	return list[o]

## The cue names are the whole vocabulary.
static func _key_fire(b: Dictionary, cue: String, x: float, y: float) -> void:
	var H: float = b.h
	if cue == "flash":
		var f := _key_oldest(b.flashes)
		f.x = x
		f.y = y
		f.age = 0.0
	elif cue == "burst":
		_key_spawn(b, "spark", x, y, 16, H * 0.7)
	elif cue == "smoke":
		_key_spawn(b, "smoke", x, y, 8, H * 0.12)
	elif cue == "ring":
		var r := _key_oldest(b.rings)
		r.x = x
		r.y = y
		r.age = 0.0

static func _key_play(b: Dictionary, x: float, y: float) -> void:
	var runs: Array = b.runs
	var idx := 0
	for i in runs.size():
		var ri: Dictionary = runs[i]
		if not ri.on:
			idx = i
			break
	var r: Dictionary = runs[idx]
	r.x = x
	r.y = y
	r.t = 0.0
	r.i = 0
	r.on = true
	b.last = idx

# ---------------------------------------------------------------- layers

static func _lay_sparks(b: Dictionary, space: String, ghost: bool) -> void:
	var H: float = b.h
	var GY: float = b.gy
	var wx: float = b.wx
	var cam: float = b.cam
	var sx := wx - cam
	var sy := GY - H * 0.12
	var pool: Array = b.pool
	var k := 0
	for i in pool.size():
		if k >= 12:
			break
		var p: Dictionary = pool[i]
		if p.on:
			continue
		var a := randf_range(-PI, 0.0)
		var v := randf_range(0.2, 0.6) * H
		p.x = wx if space == "world" else sx
		p.y = sy
		p.vx = cos(a) * v
		p.vy = sin(a) * v
		p.age = 0.0
		p.life = randf_range(0.5, 0.9)
		p.on = true
		p.space = space
		p.cam0 = cam
		p.ghost = ghost
		k += 1

static func _lay_hit(b: Dictionary) -> void:
	var D: Dictionary = b.D
	_lay_sparks(b, D.space, false)
	if D.ghost != "none" and D.ghost != D.space:
		_lay_sparks(b, D.ghost, true)
	b.hud = 1.0
	b.hits += 1
	b.timer = 0.0

# ---------------------------------------------------------------- budget

static func _bud_flag(b: Dictionary, pri: int, what: String) -> void:
	for e in b.em:
		var ed: Dictionary = e
		if ed.pri == pri:
			ed[what] += 1
			ed.flag = 0.6

## A slot while under budget; over it, cull the worst priority's oldest if
## it is worse than us; otherwise refuse.
static func _bud_spawn(b: Dictionary, pri: int, x: float, y: float, vx: float, vy: float, life: float) -> void:
	var D: Dictionary = b.D
	var pool: Array = b.pool
	var counts: Array = b.counts
	var slot := -1
	if b.alive < int(D.budget):
		slot = _free_slot(pool)
	if slot < 0:
		var worst := -1
		var q := 4
		while q > pri:
			if counts[q] > 0:
				worst = q
				break
			q -= 1
		if worst < 0:
			_bud_flag(b, pri, "refused")
			return
		var bt := INF
		for i in pool.size():
			var pi: Dictionary = pool[i]
			if pi.on and pi.pri == worst and pi.born < bt:
				bt = pi.born
				slot = i
		if slot < 0:
			_bud_flag(b, pri, "refused")
			return
		counts[worst] -= 1
		b.alive -= 1
		_bud_flag(b, worst, "culled")
	var p: Dictionary = pool[slot]
	p.pri = pri
	p.x = x
	p.y = y
	p.vx = vx
	p.vy = vy
	p.age = 0.0
	p.life = life
	p.born = b.clock
	p.on = true
	counts[pri] += 1
	b.alive += 1

static func _bud_burst(b: Dictionary, pri: int, x: float, y: float, nn: int, sp: float) -> void:
	var H: float = b.h
	for _k in nn:
		var a := randf_range(0.0, TAU)
		var v := randf_range(0.3, 1.0) * sp
		_bud_spawn(b, pri, x, y, cos(a) * v, sin(a) * v - H * 0.15, randf_range(0.5, 1.0))

static func _bud_col(pri: int) -> Color:
	match pri:
		1:
			return Kit.SPARK
		2:
			return Kit.HOT
		3:
			return Kit.FIRE
	return Color(201.0 / 255.0, 196.0 / 255.0, 228.0 / 255.0, 0.5)

# ---------------------------------------------------------------- the four entry points (parts 2-4 follow)

static func init(b: Dictionary) -> void:
	var D: Dictionary = b.D
	var W: float = b.w
	var H: float = b.h
	var GY: float = b.gy
	match b.id:
		"pool":
			# a POOL is a box of N particles made ONCE. a FREE LIST — a stack of the idle
			# slots' indices — hands out a slot on spawn (free.pop()) and takes it back
			# when the particle dies (free.push(i)). nothing is created after the first
			# frame, so the garbage collector never has a reason to stall the game. the
			# naive version — new Particle() per spawn — counts up forever in red; the
			# pool's counter stays at zero. when the free list runs dry the honest move
			# is to REFUSE the spawn, or, with steal on, to evict the oldest and reuse it.
			var size: int = D["size"]
			b.pool = _make_pool(size)
			b.free = []
			for i in size:
				(b.free as Array).append(i)
			b.naive = 0
			b.refused = 0
			b.stolen = 0
			b.clock = 0.0
			b.spawnT = 0.0
			b.lastX = W * 0.4
			b.lastY = H * 0.5
			b.flash = 0.0
		"disintegrate":
			# the sprite is drawn once to a tiny offscreen canvas at UNIT size 1 (14 × 19
			# px) and pixelsOf() reads it back: every opaque pixel becomes a particle
			# carrying its colour and its home offset — the source grid sits in the
			# corner, magnified. a trip is one clock p: 0 → 1 the pixels LEAVE for a
			# scattered spot, the hero's home moves, 1 → 0 they ARRIVE. each pixel waits
			# its own DELAY, ordered by row (feet first to disintegrate, top first to
			# assemble), and the mode decides where "scattered" is. the codex's Teleport
			# blink and the grimoire's Dust burst are this trick with one mode each.
			# the eased clock is only the TARGET: every pixel is a particle with a
			# position and a velocity, on an under-damped spring toward that target —
			# so it lags behind on the way out, and on the way home it overshoots and
			# snaps into place, and the whole sprite rings for a moment after it lands.
			# (here the "canvas" is Kit.hero_cells(): the same 14 × 19 grid, anchor (7, 18).)
			b.px = []
			for cell in Kit.hero_cells({}):
				var c: Vector2i = cell[0]
				(b.px as Array).append({ "ox": float(c.x - 7), "oy": float(c.y - 18), "row": c.y / 19.0, "j": randf(),
					"sx": 0.0, "sy": 0.0, "d": 0.0, "c": cell[1] })
			b.hx = W * 0.3
			b.phase = 0                                  # 0 whole · 1 leaving · 2 arriving
			b.p = 0.0
			b.timer = 0.0
			b.nextX = W * 0.7
			_dis_plan(b)
			var un0 := Kit.hero_unit(b)
			var nn: int = (b.px as Array).size()
			var X := PackedFloat32Array()                # each pixel's sprung position and velocity (sized here: a packed array read back from b is a copy)
			var Y := PackedFloat32Array()
			var VX := PackedFloat32Array()
			var VY := PackedFloat32Array()
			X.resize(nn)
			Y.resize(nn)
			VX.resize(nn)
			VY.resize(nn)
			for i in nn:
				var qd: Dictionary = b.px[i]
				X[i] = float(b.hx) + float(qd.ox) * un0
				Y[i] = GY + float(qd.oy) * un0
			b.X = X
			b.Y = Y
			b.VX = VX
			b.VY = VY
			b.ring = 0.0                                 # the fastest pixel, px/s: while any still moves at home, the hero is drawn from its pixels
		"hail":
			# chapter 06's sparks fell through the floor; these stop. each particle
			# carries a radius and asks three questions a frame: am I below the GROUND,
			# inside a BLOCK, under the SLOPE? a hit pushes it out along the surface
			# NORMAL n, reflects the normal part of its velocity scaled by RESTITUTION e,
			# and scales the tangential part by FRICTION μ (the lexicon's Bounce, with a
			# second axis). when a stone's speed falls under ε it RESTS — that is how
			# piles form in corners. every few seconds the sky switches to rain: thin,
			# no restitution, dead on the first touch (the codex's Stage rain).
			b.r = D["size"] * H / 170.0
			b.blocks = [Rect2(W * 0.1, GY - H * 0.2, W * 0.2, H * 0.2), Rect2(W * 0.7, GY - H * 0.11, W * 0.13, H * 0.11)]
			b.slope = [W * 0.3, GY - H * 0.2, W * 0.56, GY]   # x1, y1, x2, y2 — down to the right
			var sdx: float = b.slope[2] - b.slope[0]
			var sdy: float = b.slope[3] - b.slope[1]
			var sl := maxf(1e-6, sqrt(sdx * sdx + sdy * sdy))
			var sn := Vector2(-sdy / sl, sdx / sl)
			if sn.y > 0.0:                               # the normal points up
				sn = -sn
			b.sn = sn
			b.pool = _make_pool(int(D.n))
			b.acc = 0.0
			b.clock = 0.0
			b.hit = { "x": 0.0, "y": 0.0, "nx": 0.0, "ny": -1.0, "age": 9.0 }
			b.dropX = -1.0
			b.dropT = 0.0
			b.splash = []                                # the rain's death rings, a small ring buffer
			for _i in 24:
				(b.splash as Array).append({ "x": 0.0, "y": 0.0, "age": 9.0 })
			b.splash_i = 0
			b.alive = 0
			b.resting = 0
			b.raining = false
		"subemitter":
			# Waterdrops made a particle's death an EVENT; here the event spawns more
			# particles, and so can its life. every particle carries a kind and a LEVEL;
			# the tree (a plain object in D) says what each kind trails while alive
			# (rate per second, banked in an accumulator) and what it bursts into when
			# it dies. one pool serves all five kinds; a particle only emits while its
			# level is under depth, so the tree cannot recurse into a pool-emptying
			# storm — when the pool is full, spawns are refused and counted.
			b.pool = _make_pool(SUB_N)
			b.counts = { "rocket": 0, "smoke": 0, "spark": 0, "ember": 0, "pop": 0 }
			b.refused = 0
			b.timer = 1.5
			b.tx = W * 0.6
			b.ty = H * 0.3
		"vortex":
			# chapter 06 gave every particle one force: gravity. a FORCE LIST gives an
			# emitter any number, each a plain record { kind, strength } — WIND is a
			# constant vector, a VORTEX pushes sideways around a point (the lexicon's
			# Whirlpool) and a little inward, an ATTRACTOR pulls straight in (Magnet)
			# and swallows what reaches it, TURBULENCE reads a noise field at the
			# particle's position. each frame the list is summed into one acceleration,
			# the velocity bleeds by drag so nothing runs away, and one sample particle
			# shows its terms as arrows in the colour of the chip that made them.
			b.pool = _make_pool(int(D.n))
			b.F = []
			var forces: Array = D.forces
			for i in forces.size():
				var f: Dictionary = forces[i]
				var pos: bool = f.has("x")
				(b.F as Array).append({ "kind": f.kind, "strength": float(f.strength), "pos": pos,
					"bx": (float(f.x) if pos else 0.5) * W, "by": (float(f.y) if pos else 0.5) * H,
					"x": 0.0, "y": 0.0, "seed": float(i * 7) })
			b.out = { "ax": 0.0, "ay": 0.0 }             # the scratch a force writes into
			b.acc = 0.0
			b.pick = 0
			b.drained = 0
			b.alive = 0
			b.sample = -1
		"emitters":
			# chapter 06 emitted from a point. a SHAPE EMITTER asks the shape for a
			# random point (one number u, or two) and for the NORMAL there, and launches
			# along the normal — so a ring breathes outward, an arc fans, a line curtains
			# up and a path (a cubic Bézier, sampled by u) sheds sideways. the shape is
			# half the effect: the same particle on a ring is a portal, on a line a
			# waterfall, on a rect a snowfield. the codex's Fire spin was a ring emitter
			# with a spin; here the outline is drawn so the sample points can be read.
			b.pool = _make_pool(EMIT_N)
			b.cx = W * 0.5
			b.cy = H * 0.48
			b.R = H * D["size"]
			b.B = [Vector2(-1.3, 0.5), Vector2(-0.7, -1.4), Vector2(0.7, 1.4), Vector2(1.3, -0.5)]   # the path's control points, ×R
			var shapes: Array = D.shapes
			b.si = maxi(0, shapes.find(D.shape))
			b.timer = 0.0
			b.acc = 0.0
			b.out = { "x": 0.0, "y": 0.0, "nx": 0.0, "ny": -1.0 }
			b.last = { "x": b.cx, "y": b.cy, "nx": 0.0, "ny": -1.0 }   # the last sample: its point and normal
			b.alive = 0
		"zsort":
			# two mistakes a puff can make, and their fixes, side by side. every puff
			# carries a Z (0 far, 1 near): near ones are bigger and brighter (the atlas's
			# Volumes). drawn in POOL ORDER (left) a far puff can paint over a near one
			# and the cloud flickers as slots are reused; SORTED BY Z each frame (right)
			# near always covers far. and where a puff crosses the floor the left half
			# shows the HARD CUT of an intersection; the right fades its alpha to zero
			# over a soft band above the floor — SOFT PARTICLES, the depth-buffer trick
			# done with a distance. the strips at the top are the draw order's z values.
			var nn: int = D.n
			b.pool = _make_pool(nn)
			b.order = []
			for i in nn:
				(b.order as Array).append(i)
				_z_spawn(b, b.pool[i], true)
		"voronoi":
			# the bestiary's Crumble broke a button into a grid; a VORONOI shatter
			# breaks along cells instead, and cells look like glass. scatter a few SEEDS
			# over the sprite's box; every pixel block belongs to its NEAREST seed
			# (Disintegrate's pixelsOf gives the blocks — here Kit.hero_cells). each cell
			# is then one rigid PIECE — a position, a velocity, a spin — carrying its
			# blocks with it, flung away from the impact point, falling, bouncing once,
			# fading. while whole, the map is shown: each block tinted by its cell, the
			# seeds as dots, so the pieces that fly are the ones you were already looking at.
			b.blocks = []
			if D.target == "pane":
				for y in 19:
					for x in 14:
						(b.blocks as Array).append({ "ox": float(x - 7), "oy": float(y - 18), "cell": 0,
							"c": Color((150 + x * 5) / 255.0, (200 + y * 2) / 255.0, 1.0, 0.35 + ((x + y) % 3) * 0.1) })
			else:
				for cell in Kit.hero_cells({}):
					var c: Vector2i = cell[0]
					(b.blocks as Array).append({ "ox": float(c.x - 7), "oy": float(c.y - 18), "cell": 0, "c": cell[1] })
			b.hx = W * 0.5
			b.seeds = []
			b.pieces = []
			for _i in int(D.cells):
				(b.seeds as Array).append({ "x": 0.0, "y": 0.0 })
				(b.pieces as Array).append({ "x": 0.0, "y": 0.0, "vx": 0.0, "vy": 0.0, "rot": 0.0, "vr": 0.0,
					"cx": 0.0, "cy": 0.0, "n": 0, "bounced": false, "idx": [] })
			b.phase = 0
			b.timer = 0.0
			b.age = 0.0
			b.ix = b.hx
			b.iy = GY - 9.0 * Kit.hero_unit(b)
			b.armed_sound = false
			_vor_reseed(b)
		"cracks":
			# the codex's Ground crack was a drawing; this one is GROWN. an impact starts
			# a few TIPS, each a position, a heading θ and a width w. every step a tip
			# moves a few pixels along θ, nudges θ by a random amount (the RANDOM WALK),
			# multiplies w by decay (the THINNING) and, with a small chance, FORKS: a
			# child tip leaves at an angle with a fraction of the width. a tip dies when
			# it is too thin or leaves the slab. the web strokes segments once into a
			# cached layer; the painter keeps the SEGMENT LIST (capped at CRACK_MAX) and
			# redraws it every frame — the picture is the same, the price is per segment.
			b.k = H / 170.0
			b.slab = Rect2(W * 0.12, H * 0.1, W * 0.76, GY - H * 0.1)
			b.tips = []
			for _i in int(D.branches):
				(b.tips as Array).append({ "x": 0.0, "y": 0.0, "a": 0.0, "w": 0.0, "on": false })
			b.segs = []                                  # [x1, y1, x2, y2, w] — the layer
			b.dots = []                                  # the impacts' dots on the layer
			b.acc = 0.0
			b.timer = 0.0
			b.hits = 0
			b.nseg = 0
			b.live = 0
			b.fadeK = 1.0
			b.done = 0.0
			b.sample = 0
			b.look = _crack_look(D.surface)
		"arc":
			# chapter 06 trailed a point; a blade is a LINE, so the trail is a RIBBON.
			# every time the blade has turned by step, two points are pushed into a ring
			# buffer: where the HILT is and where the TIP is. between each neighbouring
			# pair a QUAD is filled — hilt[i], tip[i], tip[i+1], hilt[i+1] — with a
			# gradient from faint at the hilt to bright at the tip, and an alpha that
			# falls with the sample's age. the folio's Trailslash was this baked into
			# frames; here the buffer is drawn as the dots it is, so the quads can be
			# counted. a fast swing spreads samples wide; a slow one packs them.
			b.S = []
			for _i in int(D.n):
				(b.S as Array).append({ "hx": 0.0, "hy": 0.0, "tx": 0.0, "ty": 0.0, "t0": -99.0 })
			b.swings = [[-2.5, 0.5], [0.7, -2.6], [-1.3, 1.1], [1.6, -2.0]]
			var un: float = Kit.hero_unit(b)
			b.hx = W * 0.42
			b.px = b.hx + 5.0 * un
			b.py = GY - 10.0 * un
			b.a0 = -2.5
			b.a1 = 0.5
			b.k = 1.0
			b.timer = 0.0
			b.head = 0
			b.lastA = 99.0
			b.sw = 0
			b.clock = 0.0
		"keyframes":
			# an explosion is not one effect but a SEQUENCE: a flash, then sparks, then
			# smoke, then a ring, each a few frames apart. write that down as data — a
			# list of { at, do } — and one RUNNER plays any list: it keeps a clock and an
			# index, and every frame fires every cue whose time has come. the folio's
			# Beam was a sequence baked into a sprite sheet; this one is edited by
			# changing numbers. four runners can play at once (each with its own
			# playhead), and the same particle pool serves all their cues.
			b.pool = _make_pool(KEY_N)
			b.runs = []
			b.flashes = []
			b.rings = []
			for _i in 4:
				(b.runs as Array).append({ "x": 0.0, "y": 0.0, "t": 0.0, "i": 0, "on": false })
				(b.flashes as Array).append({ "x": 0.0, "y": 0.0, "age": 9.0 })
				(b.rings as Array).append({ "x": 0.0, "y": 0.0, "age": 9.0 })
			b.timer = 1.5
			b.last = -1
			var T := 1.0
			for cue in D.seq:
				var cd: Dictionary = cue
				T = maxf(T, float(cd["at"]) + D.tail)
			b.T_end = T
		"layers":
			# every effect lives in a LAYER, and the layer decides what the camera does
			# to it (chapter 03's layering). a hit spark belongs to the WORLD: it is
			# stored in world x and drawn at x − camera, so it stays on the hero as the
			# view pans. a damage flash belongs to the SCREEN: stored and drawn in screen
			# x, it ignores the camera. the classic mistake is a world effect parented
			# to a node that already follows the camera — it scrolls TWICE, sliding off
			# its owner at the camera's speed; the faint red twin here is that bug,
			# spawned beside every correct spark so the two can be watched part.
			b.pool = _make_pool(LAYER_N)
			b.wx = W * 0.4
			b.cam = 0.0
			b.hold = 0.0
			b.holdT = 0.0
			b.timer = 0.0
			b.hud = 0.0
			b.hits = 0
		"budget":
			# chapter 16 kept a budget table for the whole game; this is the particle
			# row of it. every emitter carries a PRIORITY (1 matters most). a spawn takes
			# a free slot while the alive count is under the BUDGET; past it, the spawn
			# may CULL a living particle of worse priority and take its slot, and if
			# none exists it is REFUSED — so when an explosion lands, the ambient dust
			# is what vanishes, and the hero's own hits always get through. the meter
			# is the count stacked by priority against the budget line; the table shows
			# who was culled or refused in the last moment.
			b.pool = _make_pool(BUDGET_N)
			b.counts = [0, 0, 0, 0, 0]
			b.em = []
			for row in D.table:
				var rd: Dictionary = row
				(b.em as Array).append({ "name": rd.name, "pri": int(rd.pri), "culled": 0, "refused": 0, "flag": 0.0 })
			b.clock = 0.0
			b.acc = 0.0
			b.heroT = 0.0
			b.enemyT = 0.9
			b.boomT = 2.0
			b.alive = 0
			b.hx = W * 0.3
			b.ex = W * 0.72

static func press(b: Dictionary, pos: Vector2) -> void:
	var D: Dictionary = b.D
	var W: float = b.w
	var H: float = b.h
	var GY: float = b.gy
	match b.id:
		"pool":
			_pool_burst(b, pos.x, pos.y)
			b.spawnT = 0.0
		"disintegrate":
			b.nextX = clampf(pos.x, W * 0.1, W * 0.9)
			_dis_go(b)
		"hail":
			b.dropX = pos.x
			b.dropT = 0.7
			for _k in 12:
				_hail_spawn(b, pos.x + randf_range(-8.0, 8.0), minf(pos.y, GY - 4.0), false)
		"subemitter":
			_sub_launch(b, pos.x, clampf(pos.y, 10.0, GY - 10.0))
			b.timer = 0.0
		"vortex":
			var posF: Array = []
			for f in b.F:
				var fd: Dictionary = f
				if fd.pos:
					posF.append(fd)
			if posF.is_empty():
				return
			var f: Dictionary = posF[b.pick % posF.size()]
			b.pick += 1
			f.bx = clampf(pos.x, 4.0, W - 4.0)
			f.by = clampf(pos.y, 4.0, GY - 4.0)
		"emitters":
			_em_next(b)
		"zsort":
			var half := W / 2.0
			var lx := fmod(pos.x, half)
			for p in b.pool:
				var pd: Dictionary = p
				var dx: float = pd.x - lx
				var dy: float = pd.y - pos.y
				var d := maxf(4.0, sqrt(dx * dx + dy * dy))
				var k := clampf(1.0 - d / (H * 0.5), 0.0, 1.0) * H * 0.9
				pd.vx += dx / d * k
				pd.vy += dy / d * k
		"voronoi":
			b.armed_sound = true
			var un: float = Kit.hero_unit(b)
			var hx: float = b.hx
			if b.phase == 0:
				_vor_shatter(b, clampf(pos.x, hx - 8.0 * un, hx + 8.0 * un), clampf(pos.y, GY - 19.0 * un, GY))
			else:
				for k in int(D.cells):
					var p: Dictionary = b.pieces[k]
					var dx: float = p.x - pos.x
					var dy: float = p.y - pos.y
					var d := maxf(4.0, sqrt(dx * dx + dy * dy))
					p.vx += dx / d * H * 0.3
					p.vy += dy / d * H * 0.3 - H * 0.15
					p.bounced = false
		"cracks":
			_crack_impact(b, pos.x, pos.y)
		"arc":
			var px: float = b.px
			var py: float = b.py
			var target := atan2(pos.y - py, pos.x - px)
			var cur := _arc_angle(b)
			var from := cur
			if absf(target - cur) < 1.0:
				from = target + (-2.2 if target > -PI / 2.0 else 2.2)
			_arc_begin(b, from, target)
		"keyframes":
			_key_play(b, pos.x, clampf(pos.y, H * 0.25, GY))
			b.timer = 0.0
		"layers":
			b.hold = (pos.x / W - 0.5) * W * 0.9
			b.holdT = 1.5
		"budget":
			_bud_burst(b, 3, pos.x, clampf(pos.y, H * 0.4, GY), int(D.burst), H * 0.8)
			b.boomT = 0.0

static func tick(b: Dictionary, dt: float, t: float) -> void:
	var D: Dictionary = b.D
	var W: float = b.w
	var H: float = b.h
	var GY: float = b.gy
	match b.id:
		"pool":
			b.clock += dt
			b.spawnT += dt
			if b.spawnT > D.every:
				b.spawnT = 0.0
				_pool_burst(b, randf_range(W * 0.1, W * 0.6), randf_range(H * 0.25, H * 0.6))
			b.flash = maxf(0.0, b.flash - dt * 3.0)
			var g: float = H * D.gravity
			var pool: Array = b.pool
			var free: Array = b.free
			for i in pool.size():
				var p: Dictionary = pool[i]
				if not p.on:
					continue
				p.age += dt
				if p.age >= p.life:                      # die = give the slot back
					p.on = false
					free.append(i)
					continue
				p.vy += g * dt
				p.x += p.vx * dt
				p.y += p.vy * dt
				if p.y > GY:
					p.y = GY
					p.vy *= -0.4
					p.vx *= 0.7
		"disintegrate":
			b.timer += dt
			var X: PackedFloat32Array = b.X
			var Y: PackedFloat32Array = b.Y
			var VX: PackedFloat32Array = b.VX
			var VY: PackedFloat32Array = b.VY
			var nn: int = X.size()
			if b.phase == 0 and b.timer > D.hold:
				_dis_go(b)
			if b.phase == 1:
				b.p = minf(1.0, b.p + dt / D.fly)
				if b.p >= 1.0:                           # the home moves while the cloud is invisible (alpha = 1 − k = 0 up here): the cloud moves with it, offsets and velocities kept, so the springs never see the jump
					b.phase = 2
					var jump: float = b.nextX - b.hx
					for i in nn:
						X[i] += jump
					b.hx = b.nextX
					b.nextX = randf_range(W * 0.15, W * 0.85)
			elif b.phase == 2:
				b.p = maxf(0.0, b.p - dt / D.fly)
				if b.p <= 0.0:
					b.phase = 0
					b.timer = 0.0
			# every pixel's spring chases its target — home → scattered by the eased clock — in substeps of ≤ 20 ms
			var un: float = Kit.hero_unit(b)
			var hx: float = b.hx
			var phase: int = b.phase
			var pp: float = b.p
			var px: Array = b.px
			var kS: float = maxf(1.0, float(D.spring))
			var cS: float = 2.0 * clampf(float(D.damp), 0.0, 0.99) * sqrt(kS)
			var sub := maxi(1, ceili(dt * 50.0))
			var h := dt / float(sub)
			var ring := 0.0
			for i in nn:
				var qd: Dictionary = px[i]
				var ox: float = qd.ox
				var oy: float = qd.oy
				var k: float = 0.0 if phase == 0 else _ease(pp * 1.8 - float(qd.d))
				var tx: float = hx + ox * un + (float(qd.sx) - ox * un) * k
				var ty: float = GY + oy * un + (float(qd.sy) - oy * un) * k
				for _s in sub:
					VX[i] += (kS * (tx - X[i]) - cS * VX[i]) * h
					VY[i] += (kS * (ty - Y[i]) - cS * VY[i]) * h
					X[i] += VX[i] * h
					Y[i] += VY[i] * h
				X[i] = clampf(X[i], -W, 2.0 * W)
				Y[i] = clampf(Y[i], -H, 2.0 * H)
				ring = maxf(ring, maxf(absf(VX[i]), absf(VY[i])))
			b.ring = ring
		"hail":
			var r: float = b.r
			b.clock += dt
			var hit: Dictionary = b.hit
			hit.age += dt
			b.dropT -= dt
			var raining: bool = fmod(b.clock, D.rainAfter * 2.0) > D.rainAfter
			b.raining = raining
			b.acc += D.rate * (2.0 if raining else 1.0) * dt
			while b.acc >= 1.0:
				b.acc -= 1.0
				_hail_spawn(b, randf_range(0.0, W), -4.0, raining)
			if b.dropT > 0.0:
				for _k in 2:
					_hail_spawn(b, b.dropX + randf_range(-10.0, 10.0), 0.0, false)
			var g: float = H * D.gravity
			var alive := 0
			var resting := 0
			var blocks: Array = b.blocks
			var slope: Array = b.slope
			var sn: Vector2 = b.sn
			var splash: Array = b.splash
			for sp in splash:
				(sp as Dictionary).age += dt
			for i in (b.pool as Array).size():
				var p: Dictionary = b.pool[i]
				if not p.on:
					continue
				if p.rest > 0.0:                         # a resting stone: no physics, just melting
					p.rest += dt
					if p.rest > D.melt:
						p.on = false
						continue
					resting += 1
					alive += 1
					continue
				p.vy += g * dt
				p.x += p.vx * dt
				p.y += p.vy * dt
				var touched := false
				if p.y + r > GY:
					touched = _hail_collide(b, p, 0.0, -1.0, GY - (p.y + r))
				for bk in blocks:
					var br: Rect2 = bk
					if p.x + r <= br.position.x or p.x - r >= br.end.x or p.y + r <= br.position.y or p.y - r >= br.end.y:
						continue
					var top: float = p.y + r - br.position.y
					var left: float = p.x + r - br.position.x
					var right: float = br.end.x - (p.x - r)
					var bot: float = br.end.y - (p.y - r)
					var m := minf(minf(top, left), minf(right, bot))
					if m == top:
						touched = _hail_collide(b, p, 0.0, -1.0, -top)
					elif m == left:
						touched = _hail_collide(b, p, -1.0, 0.0, -left)
					elif m == right:
						touched = _hail_collide(b, p, 1.0, 0.0, -right)
					else:
						touched = _hail_collide(b, p, 0.0, 1.0, -bot)
				var sx0: float = slope[0]
				var sx1: float = slope[2]
				if p.x >= sx0 and p.x <= sx1:
					var sy0: float = slope[1]
					var sy1: float = slope[3]
					var ly: float = sy0 + (p.x - sx0) / (sx1 - sx0) * (sy1 - sy0)
					if p.y + r > ly and p.y - r < ly + 10.0:
						touched = _hail_collide(b, p, sn.x, sn.y, -(p.y + r - ly) * -sn.y)   # the web's push, sign and all
				if touched and p.rain:                   # rain dies on its first touch, with a ring
					p.on = false
					var si: int = b.splash_i
					var sd: Dictionary = splash[si]
					sd.x = p.x
					sd.y = p.y
					sd.age = 0.0
					b.splash_i = (si + 1) % splash.size()
					continue
				if p.hits > int(D.bounces) or p.x < -10.0 or p.x > W + 10.0 or p.y > H + 10.0:
					p.on = false
					continue
				if touched and absf(p.vy) < H * 0.02 and absf(p.vx) < H * 0.02 and p.y + r > GY - 1.0:
					p.rest = 0.001
				alive += 1
			b.alive = alive
			b.resting = resting
		"subemitter":
			b.timer += dt
			if b.timer > D.every:
				b.timer = 0.0
				_sub_launch(b, randf_range(W * 0.35, W * 0.9), randf_range(H * 0.12, H * 0.5))
			var counts: Dictionary = b.counts
			for key in counts.keys():
				counts[key] = 0
			var g: float = H * D.gravity
			var tree: Dictionary = D.tree
			var depth: int = D.depth
			var pool: Array = b.pool
			for i in pool.size():
				var p: Dictionary = pool[i]
				if not p.on:
					continue
				p.age += dt
				if p.age >= p.life:
					p.on = false
					_sub_die(b, p)
					continue
				var node: Dictionary = tree.get(p.kind, {})
				if node.has("trail") and p.level < depth:   # the trail: banked spawns
					p.acc += float(node.rate) * dt
					while p.acc >= 1.0:
						p.acc -= 1.0
						_sub_spawn(b, node.trail, p.level + 1, p.x, p.y, randf_range(-0.03, 0.03) * H, randf_range(-0.06, 0.0) * H)
				if p.kind == "spark" or p.kind == "ember":
					p.vy += g * dt
				if p.kind == "smoke":
					p.vy -= H * 0.05 * dt
				p.x += p.vx * dt
				p.y += p.vy * dt
				counts[p.kind] = int(counts.get(p.kind, 0)) + 1
		"vortex":
			var F: Array = b.F
			for i in F.size():                           # positional forces drift a little about their base
				var f: Dictionary = F[i]
				f.x = f.bx + Kit.noise(t * 0.12 + f.seed) * W * 0.06
				f.y = f.by + Kit.noise(t * 0.1 + f.seed + 3.0) * H * 0.05
			b.acc += D.rate * dt
			var pool: Array = b.pool
			while b.acc >= 1.0:
				b.acc -= 1.0
				var i := _free_slot(pool)
				if i >= 0:
					var p: Dictionary = pool[i]
					p.x = randf_range(0.0, W * 0.04)
					p.y = randf_range(H * 0.1, GY - 4.0)
					p.vx = H * 0.1
					p.vy = 0.0
					p.age = 0.0
					p.life = D.life * randf_range(0.7, 1.1)
					p.on = true
			var keep := clampf(1.0 - D.drag * dt, 0.0, 1.0)
			var VMAX := H * 1.6
			var alive := 0
			var sample := -1
			var out: Dictionary = b.out
			for i in pool.size():
				var p: Dictionary = pool[i]
				if not p.on:
					continue
				p.age += dt
				if p.age >= p.life or p.x > W + 6.0 or p.x < -6.0 or p.y > GY or p.y < -6.0:
					p.on = false
					continue
				var ax := 0.0
				var ay := 0.0
				var gone := false
				for k in F.size():
					if not _vx_apply(b, F[k], p, t, out):
						gone = true
						break
					ax += out.ax
					ay += out.ay
				if gone:
					p.on = false
					b.drained += 1
					continue
				p.vx = (p.vx + ax * dt) * keep
				p.vy = (p.vy + ay * dt) * keep
				var v: float = sqrt(p.vx * p.vx + p.vy * p.vy)
				if v > VMAX:
					p.vx *= VMAX / v
					p.vy *= VMAX / v
				p.x += p.vx * dt
				p.y += p.vy * dt
				alive += 1
				if sample < 0 and p.age > 0.4 and p.x > W * 0.2:
					sample = i
			b.alive = alive
			b.sample = sample
		"emitters":
			b.timer += dt
			if b.timer > D.every:
				_em_next(b)
			var shapes: Array = D.shapes
			var shape: String = shapes[b.si] if b.si < shapes.size() else "point"
			b.acc += D.rate * dt
			var pool: Array = b.pool
			var out: Dictionary = b.out
			var last: Dictionary = b.last
			var cx: float = b.cx
			var cy: float = b.cy
			while b.acc >= 1.0:
				b.acc -= 1.0
				var i := _free_slot(pool)
				if i >= 0:
					var p: Dictionary = pool[i]
					_em_sample(b, shape)
					p.x = cx + out.x
					p.y = cy + out.y
					p.vx = out.nx * H * D.rise + randf_range(-0.02, 0.02) * H
					p.vy = out.ny * H * D.rise + randf_range(-0.02, 0.02) * H
					p.age = 0.0
					p.life = D.life * randf_range(0.7, 1.2)
					p.on = true
					last.x = p.x
					last.y = p.y
					last.nx = out.nx
					last.ny = out.ny
			var alive := 0
			for i in pool.size():
				var p: Dictionary = pool[i]
				if not p.on:
					continue
				p.age += dt
				if p.age >= p.life:
					p.on = false
					continue
				p.x += p.vx * dt
				p.y += p.vy * dt
				alive += 1
			b.alive = alive
		"zsort":
			var half := W / 2.0
			var keep := clampf(1.0 - 2.5 * dt, 0.0, 1.0)
			var pool: Array = b.pool
			for i in pool.size():
				var p: Dictionary = pool[i]
				p.age += dt
				if p.age > D.life:
					_z_spawn(b, p, false)
				p.vx *= keep
				p.vy *= keep
				p.x += p.vx * dt
				p.y += (p.vy + H * D.sink + sin(t * 0.7 + i) * H * 0.01) * dt
				if p.x < 0.0:
					p.x = 0.0
					p.vx = absf(p.vx)
				elif p.x > half:
					p.x = half
					p.vx = -absf(p.vx)
				if p.y - p.r > GY + H * 0.02:
					_z_spawn(b, p, false)
			var order: Array = b.order
			order.sort_custom(func(ia: int, ib: int) -> bool:   # far first, so near paints last
				return (pool[ia] as Dictionary).z < (pool[ib] as Dictionary).z)
		"voronoi":
			var un: float = Kit.hero_unit(b)
			var hx: float = b.hx
			if b.phase == 0:
				b.timer += dt
				if b.timer > D.hold:
					_vor_shatter(b, hx + randf_range(-4.0, 4.0) * un, GY - randf_range(4.0, 14.0) * un)
			else:
				b.age += dt
				var g: float = H * D.gravity
				for k in int(D.cells):
					var p: Dictionary = b.pieces[k]
					if p.n == 0:
						continue
					p.vy += g * dt
					p.x += p.vx * dt
					p.y += p.vy * dt
					p.rot += p.vr * dt
					if p.y > GY:
						p.y = GY
						if not p.bounced:
							p.vy *= -0.35
							p.vx *= 0.6
							p.vr *= 0.5
							p.bounced = true
						else:
							p.vy = 0.0
							p.vx *= 0.9
							p.vr *= 0.9
				if b.age > D.fade:
					b.phase = 0
					b.timer = 0.0
					_vor_reseed(b)
		"cracks":
			var k: float = b.k
			var slab: Rect2 = b.slab
			b.timer += dt
			if b.fadeK >= 1.0 and b.timer > D.every and b.hits < int(D.hits):
				_crack_impact(b, randf_range(slab.position.x + 10.0, slab.end.x - 10.0), randf_range(slab.position.y + 10.0, slab.end.y - 10.0))
			b.acc = minf(b.acc + D.speed * k * dt, 24.0 * k)
			var tips: Array = b.tips
			while b.acc >= 4.0 * k:
				b.acc -= 4.0 * k
				for i in tips.size():
					var tp: Dictionary = tips[i]
					if tp.on:
						_crack_step(b, tp)
			var live := 0
			for i in tips.size():
				var tp: Dictionary = tips[i]
				if tp.on:
					live += 1
					b.sample = i
			b.live = live
			if b.hits >= int(D.hits) and live == 0:      # the slab is spent: fade the layer, then a fresh one
				b.done += dt
				if b.done > 1.0:
					b.fadeK = maxf(0.0, b.fadeK - dt * 2.0)
				if b.fadeK <= 0.0:
					(b.segs as Array).clear()
					(b.dots as Array).clear()
					b.hits = 0
					b.nseg = 0
					b.done = 0.0
					b.timer = 0.0
					b.fadeK = 1.0
		"arc":
			b.clock += dt
			b.timer += dt
			var swings: Array = b.swings
			if b.k < 1.0:
				b.k = minf(1.0, b.k + dt / D.swing)
			elif b.timer > D.every:
				b.sw = (b.sw + 1) % swings.size()
				var swp: Array = swings[b.sw]
				_arc_begin(b, swp[0], swp[1])
			var a := _arc_angle(b)
			if absf(a - b.lastA) >= D.step:              # a new pair for the ring buffer
				var S: Array = b.S
				var smp: Dictionary = S[b.head]
				b.head = (b.head + 1) % int(D.n)
				b.lastA = a
				var px: float = b.px
				var py: float = b.py
				smp.hx = px + cos(a) * H * D.hilt
				smp.hy = py + sin(a) * H * D.hilt
				smp.tx = px + cos(a) * H * D.blade
				smp.ty = py + sin(a) * H * D.blade
				smp.t0 = b.clock
		"keyframes":
			b.timer += dt
			if b.timer > D.every:
				b.timer = 0.0
				_key_play(b, randf_range(W * 0.15, W * 0.85), randf_range(H * 0.3, GY - 4.0))
			var seq: Array = D.seq
			var T: float = b.T_end
			for r in b.runs:                             # the runner: one loop, any sequence
				var rd: Dictionary = r
				if not rd.on:
					continue
				rd.t += dt * D.speed
				while rd.i < seq.size() and float((seq[rd.i] as Dictionary)["at"]) <= rd.t:
					_key_fire(b, (seq[rd.i] as Dictionary)["do"], rd.x, rd.y)
					rd.i += 1
				if rd.t > T:
					rd.on = false
			for f in b.flashes:
				(f as Dictionary).age += dt
			for rg in b.rings:
				(rg as Dictionary).age += dt
			var g := H * 1.4
			for p in b.pool:
				var pd: Dictionary = p
				if not pd.on:
					continue
				pd.age += dt
				if pd.age >= pd.life:
					pd.on = false
					continue
				if pd.kind == "spark":
					pd.vy += g * dt
				else:
					pd.vx *= clampf(1.0 - dt, 0.0, 1.0)
				pd.x += pd.vx * dt
				pd.y += pd.vy * dt
		"layers":
			b.wx += W * D.run * dt
			b.timer += dt
			b.holdT -= dt
			var want: float = b.wx - W * 0.45 + (b.hold if b.holdT > 0.0 else sin(t * 0.6) * W * D.pan)
			b.cam += (want - b.cam) * clampf(dt * 6.0, 0.0, 1.0)
			if b.timer > D.every:
				_lay_hit(b)
			for p in b.pool:
				var pd: Dictionary = p
				if not pd.on:
					continue
				pd.age += dt
				if pd.age >= pd.life:
					pd.on = false
					continue
				pd.vy += H * 1.2 * dt
				pd.x += pd.vx * dt
				pd.y += pd.vy * dt
			b.hud = maxf(0.0, b.hud - dt * 3.0)
		"budget":
			b.clock += dt
			b.heroT += dt
			b.enemyT += dt
			b.boomT += dt
			var hx: float = b.hx
			var ex: float = b.ex
			if b.heroT > 1.2:
				b.heroT = 0.0
				_bud_burst(b, 1, hx, GY - H * 0.12, 12, H * 0.5)
			if b.enemyT > 1.8:
				b.enemyT = 0.0
				_bud_burst(b, 2, ex, GY - H * 0.1, 10, H * 0.45)
			if b.boomT > D.every:
				b.boomT = 0.0
				_bud_burst(b, 3, randf_range(W * 0.2, W * 0.8), randf_range(H * 0.45, GY - 4.0), int(D.burst), H * 0.8)
			b.acc += D.ambient * dt
			while b.acc >= 1.0:
				b.acc -= 1.0
				_bud_spawn(b, 4, randf_range(0.0, W), randf_range(H * 0.4, GY), 0.0, -H * 0.04, randf_range(1.5, 2.5))
			var g := H * 1.3
			var counts: Array = b.counts
			for p in b.pool:
				var pd: Dictionary = p
				if not pd.on:
					continue
				pd.age += dt
				if pd.age >= pd.life:
					pd.on = false
					counts[pd.pri] -= 1
					b.alive -= 1
					continue
				if pd.pri < 4:
					pd.vy += g * dt
					if pd.y > GY:
						pd.y = GY
						pd.vy *= -0.3
				else:
					pd.vx = Kit.noise(pd.y * 0.05 + t) * H * 0.05
				pd.x += pd.vx * dt
				pd.y += pd.vy * dt
			for e in b.em:
				var ed: Dictionary = e
				ed.flag = maxf(0.0, ed.flag - dt)

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	var D: Dictionary = b.D
	var W: float = b.w
	var H: float = b.h
	var GY: float = b.gy
	var origin: Vector2 = (b.rect as Rect2).position
	match b.id:
		"pool":
			Kit.stage(n, b, 0.35)
			var pool: Array = b.pool
			var size: int = D["size"]
			var alive := 0
			for i in pool.size():
				var p: Dictionary = pool[i]
				if not p.on:
					continue
				alive += 1
				var k: float = 1.0 - p.age / p.life
				Kit.dot(n, Vector2(p.x, p.y), 1.5 + k * 1.5, _al(Kit.SPARK, 0.3 + k * 0.7))
			var flash: float = b.flash
			if flash > 0.0:
				Kit.ring(n, Vector2(b.lastX, b.lastY), (1.0 - flash) * 18.0, _al(Kit.SPARK, flash * 0.6), 1.0)
			# the pool itself: one slot per particle, lit while it lives
			var cols := int(ceil(sqrt(float(size))))
			var rows := int(ceil(size / float(cols)))
			var cell := minf(W * 0.32 / cols, H * 0.4 / rows)
			var gx := W - 8.0 - cols * cell
			var gy := 14.0
			for i in size:
				var cx := gx + (i % cols) * cell
				@warning_ignore("integer_division")   # the slot's row is an int index
				var cy := gy + (i / cols) * cell
				var pi: Dictionary = pool[i]
				Kit.rect(n, Rect2(cx + 0.5, cy + 0.5, maxf(0.5, cell - 1.5), maxf(0.5, cell - 1.5)), Kit.SPARK if pi.on else SLOT_DIM)
			_label_r(n, b, "alive %d / %d · free %d" % [alive, size, (b.free as Array).size()], Vector2(gx + cols * cell, gy + rows * cell + 11.0), Kit.BONE)
			# the two counters: the pool versus new Particle() every time
			Kit.label(n, b, "pool: allocations 0 since start", Vector2(8, 14), Kit.GOOD)
			Kit.label(n, b, "naive: new Particle() × %d" % b.naive, Vector2(8, 26), Kit.HOT)
			if D.steal:
				Kit.label(n, b, "stolen %d (oldest evicted)" % b.stolen, Vector2(8, 38), _al(AMBER, 0.8))
			elif b.refused > 0:
				Kit.label(n, b, "refused %d (free list empty)" % b.refused, Vector2(8, 38), _al(AMBER, 0.8))
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"disintegrate":
			Kit.stage(n, b, 0.4)
			var un: float = Kit.hero_unit(b)
			var hx: float = b.hx
			var phase: int = b.phase
			var pp: float = b.p
			var mode: String = D.mode
			var px: Array = b.px
			var X: PackedFloat32Array = b.X
			var Y: PackedFloat32Array = b.Y
			if phase == 0 and float(b.ring) < 2.0:
				Kit.hero(n, b, Vector2(hx, GY), { "pose": "stand", "frame": t })
			else:
				for i in px.size():                      # each pixel where its spring has carried it (stepped in tick), fading by its target's clock
					var qd: Dictionary = px[i]
					var col: Color = qd.c
					var k: float = 0.0 if phase == 0 else _ease(pp * 1.8 - float(qd.d))
					var x: float = X[i]
					var y: float = Y[i]
					col.a = clampf(1.0 - k, 0.0, 1.0)
					if mode == "teleport":
						Kit.rect(n, Rect2(x, y - un * 5.0 * k * (1.0 - k), un, un * (1.0 + 10.0 * k * (1.0 - k))), col)
					else:
						Kit.rect(n, Rect2(x, y, un, un), col)
			# the source: the 14 × 19 sprite the particles were read from, at ×2
			for q in px:
				var qd: Dictionary = q
				Kit.rect(n, Rect2(8.0 + (qd.ox + 7.0) * 2.0, 14.0 + (qd.oy + 18.0) * 2.0, 2.0, 2.0), qd.c)
			n.draw_rect(Rect2(7.5, 13.5, 29.0, 39.0), Kit.DIM, false, 1.0)
			Kit.label(n, b, "14×19 px → %d particles" % px.size(), Vector2(8, 19 * 2 + 26), Kit.BONE)
			var st := "whole" if phase == 0 else ("leaving p=%.2f" % pp if phase == 1 else "arriving p=%.2f" % pp)
			_label_r(n, b, mode + " · " + st, Vector2(W - 8.0, 14.0), Kit.BONE)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"hail":
			Kit.stage(n, b, 0.5)
			var r: float = b.r
			for p in b.pool:
				var pd: Dictionary = p
				if not pd.on:
					continue
				if pd.rest > 0.0:
					Kit.dot(n, Vector2(pd.x, pd.y), r, _al(ICE_REST, 0.85))
				elif pd.rain:
					Kit.line(n, Vector2(pd.x, pd.y), Vector2(pd.x - pd.vx * 0.02, pd.y - pd.vy * 0.02), _al(RAIN, 0.6), 1.0)
				else:
					Kit.dot(n, Vector2(pd.x, pd.y), r, _al(ICE_DOT, 0.95))
			for sp in b.splash:                          # the rain's death rings (the web draws one the frame it dies)
				var sd: Dictionary = sp
				if sd.age < 0.08:
					Kit.ring(n, Vector2(sd.x, sd.y), 3.0, _al(ICE_REST, 0.5), 1.0)
			# the colliders, and the last hit's normal
			for bk in b.blocks:
				Kit.wall(n, bk)
			var slope: Array = b.slope
			Kit.poly(n, [Vector2(slope[0], slope[1]), Vector2(slope[2], slope[3]), Vector2(slope[0], slope[3])], SLAB_INK)
			Kit.line(n, Vector2(slope[0], slope[1]), Vector2(slope[2], slope[3]), Kit.BONE, 1.5)
			var hit: Dictionary = b.hit
			if hit.age < 0.5:
				Kit.arrow(n, Vector2(hit.x, hit.y), Vector2(hit.x + hit.nx * 16.0, hit.y + hit.ny * 16.0), _al(AMBER, 1.0 - hit.age * 2.0))
			Kit.label(n, b, "%s · alive %d · resting %d · e %s μ %s" % ["rain" if b.raining else "hail", b.alive, b.resting, str(D.bounce), str(D.friction)], Vector2(8, 14), Kit.BONE)
			Kit.label(n, b, "n", Vector2(hit.x + hit.nx * 20.0, hit.y + hit.ny * 20.0 + 3.0), _al(AMBER, clampf(1.0 - hit.age * 2.0, 0.0, 1.0)), true)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"subemitter":
			Kit.stage(n, b, 0.85)
			for p in b.pool:
				var pd: Dictionary = p
				if not pd.on:
					continue
				var k: float = 1.0 - pd.age / pd.life
				var pos := Vector2(pd.x, pd.y)
				match pd.kind:
					"rocket":
						Kit.glow(n, pos, 8.0, Kit.SPARK, 0.6)
						Kit.dot(n, pos, 2.2, Kit.INK)
					"smoke":
						Kit.dot(n, pos, 2.0 + (1.0 - k) * 6.0, _al(SMOKE, k * 0.25))
					"spark":
						Kit.dot(n, pos, 1.8, _al(Kit.SPARK, 0.4 + k * 0.6))
					"ember":
						Kit.dot(n, pos, 1.1, _al(Kit.FIRE, k))
					_:
						Kit.ring(n, pos, (1.0 - k) * 7.0, _al(Kit.SPARK, k * 0.7), 1.0)
			Kit.ring(n, Vector2(b.tx, b.ty), 4.0, Kit.DIM, 1.0)
			# the emitter tree, as it runs
			var tr: Dictionary = D.tree
			var rocket: Dictionary = tr.rocket
			var spark: Dictionary = tr.spark
			var counts: Dictionary = b.counts
			var depth: int = D.depth
			var x0 := 8.0
			var lh := 11.0
			var y := 14.0
			var rows: Array = [
				["rocket  L0", counts.rocket, 0, Kit.INK],
				["├ trail %s %s/s" % [rocket.trail, str(rocket.rate)], counts.smoke, 1, Kit.BONE],
				["└ death %s ×%s" % [rocket.death, str(rocket.burst)], counts.spark, 1, Kit.SPARK],
				["├ trail %s %s/s" % [spark.trail, str(spark.rate)], counts.ember, 2, Kit.FIRE],
				["└ death %s" % ("spark ×3" if D.chain else str(spark.death)), -1 if D.chain else int(counts.pop), 2, Kit.BONE]]
			for row in rows:
				var rw: Array = row
				var lvl: int = rw[2]
				var colr: Color = rw[3]
				Kit.label(n, b, rw[0], Vector2(x0 + lvl * 10.0, y), colr if lvl < depth else Kit.DIM)
				if int(rw[1]) >= 0:
					Kit.label(n, b, "×%d" % int(rw[1]), Vector2(x0 + 118.0, y), colr)
				y += lh
			var total: int = counts.rocket + counts.smoke + counts.spark + counts.ember + counts.pop
			Kit.label(n, b, "depth %d · pool %d/%d%s" % [depth, total, SUB_N, (" · refused %d" % b.refused) if b.refused > 0 else ""], Vector2(x0, y + 2.0), Kit.DIM)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"vortex":
			Kit.stage(n, b, 0.6)
			var F: Array = b.F
			var R: float = H * D.radius
			var pool: Array = b.pool
			for p in pool:
				var pd: Dictionary = p
				if not pd.on:
					continue
				var k: float = 1.0 - pd.age / pd.life
				Kit.dot(n, Vector2(pd.x, pd.y), 1.4 + k * 0.8, _al(Kit.SPARK, 0.25 + k * 0.6))
			# the positional forces on the stage: a swirl ring, a drain
			for f in F:
				var fd: Dictionary = f
				if not fd.pos:
					continue
				var c := _vx_col(fd.kind)
				var fp := Vector2(fd.x, fd.y)
				Kit.ring(n, fp, R, _al(c, 0.18), 1.0)
				if fd.kind == "vortex":
					for k in 3:
						var a := t * 1.5 + k * TAU / 3.0
						var r0 := R * 0.45
						Kit.arrow(n, fp + Vector2(cos(a), sin(a)) * r0, fp + Vector2(cos(a + 0.5), sin(a + 0.5)) * r0, _al(c, 0.7))
				else:
					Kit.dot(n, fp, 3.0, c)
					for k in 4:
						var a := k * TAU / 4.0 + t
						Kit.arrow(n, fp + Vector2(cos(a), sin(a)) * R * 0.5, fp + Vector2(cos(a), sin(a)) * R * 0.25, _al(c, 0.6))
			# the sample particle: each force's term as an arrow (a local scratch; draw mutates nothing on b)
			var sample: int = b.sample
			if sample >= 0:
				var p: Dictionary = pool[sample]
				if p.on:
					var scratch := { "ax": 0.0, "ay": 0.0 }
					Kit.ring(n, Vector2(p.x, p.y), 4.0, Kit.INK, 1.0)
					for f in F:
						var fd: Dictionary = f
						_vx_apply(b, fd, p, t, scratch)
						Kit.arrow(n, Vector2(p.x, p.y), Vector2(p.x + scratch.ax * 0.07, p.y + scratch.ay * 0.07), _vx_col(fd.kind))
			# the chips: the force list as the emitter holds it
			var cx := 8.0
			for f in F:
				var fd: Dictionary = f
				var txt := "%s %s" % [fd.kind, str(fd.strength)]
				var w := 10.0 + txt.length() * 5.4
				var c := _vx_col(fd.kind)
				Kit.rect(n, Rect2(cx, 6.0, w, 13.0), _al(c, 0.18))
				n.draw_rect(Rect2(cx + 0.5, 6.5, w - 1.0, 12.0), _al(c, 0.7), false, 1.0)
				Kit.label(n, b, txt, Vector2(cx + 5.0, 16.0), c)
				cx += w + 4.0
			_label_r(n, b, "alive %d/%d%s" % [b.alive, pool.size(), (" · drained %d" % b.drained) if b.drained > 0 else ""], Vector2(W - 8.0, H - 20.0), Kit.DIM)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"emitters":
			Kit.stage(n, b, 0.7)
			var shapes: Array = D.shapes
			var si: int = b.si
			var shape: String = shapes[si] if si < shapes.size() else "point"
			var cx: float = b.cx
			var cy: float = b.cy
			var R: float = b.R
			var Bp: Array = b.B
			var c := Vector2(cx, cy)
			# the outline, dashed
			if shape == "point":
				_dash_line(n, Vector2(cx - 5.0, cy), Vector2(cx + 5.0, cy), Kit.DIM)
				_dash_line(n, Vector2(cx, cy - 5.0), Vector2(cx, cy + 5.0), Kit.DIM)
			elif shape == "line":
				_dash_line(n, Vector2(cx - R * 1.3, cy), Vector2(cx + R * 1.3, cy), Kit.DIM)
			elif shape == "ring":
				_dash_arc(n, c, R, 0.0, TAU, Kit.DIM)
			elif shape == "rect":
				var r0 := Rect2(cx - R * 1.3, cy - R * 0.6, R * 2.6, R * 1.2)
				_dash_line(n, r0.position, Vector2(r0.end.x, r0.position.y), Kit.DIM)
				_dash_line(n, Vector2(r0.end.x, r0.position.y), r0.end, Kit.DIM)
				_dash_line(n, r0.end, Vector2(r0.position.x, r0.end.y), Kit.DIM)
				_dash_line(n, Vector2(r0.position.x, r0.end.y), r0.position, Kit.DIM)
			elif shape == "arc":
				_dash_arc(n, c, R, PI, TAU, Kit.DIM)
			else:
				var P0: Vector2 = Bp[0]
				var P1: Vector2 = Bp[1]
				var P2: Vector2 = Bp[2]
				var P3: Vector2 = Bp[3]
				for i in 24:                             # the Bézier as 24 pieces, every other one drawn
					var u0 := i / 24.0
					var u1 := (i + 0.5) / 24.0
					var q0 := c + P0.bezier_interpolate(P1, P2, P3, u0) * R
					var q1 := c + P0.bezier_interpolate(P1, P2, P3, u1) * R
					n.draw_line(q0, q1, Kit.DIM, 1.0)
				for k in 4:
					Kit.dot(n, c + (Bp[k] as Vector2) * R, 1.6, Kit.DIM)
			var colour := Color(D.colour as String)
			for p in b.pool:
				var pd: Dictionary = p
				if not pd.on:
					continue
				var k: float = 1.0 - pd.age / pd.life
				Kit.dot(n, Vector2(pd.x, pd.y), 1.0 + k * 1.6, _al(colour, 0.15 + k * 0.7))
			# the last sample: its point and normal
			var last: Dictionary = b.last
			Kit.ring(n, Vector2(last.x, last.y), 3.0, Kit.INK, 1.0)
			Kit.line(n, Vector2(last.x, last.y), Vector2(last.x + last.nx * 12.0, last.y + last.ny * 12.0), Kit.INK, 1.0)
			# the cycle, the current shape lit
			var x0 := 8.0
			for k in shapes.size():
				var nm: String = shapes[k]
				Kit.label(n, b, nm, Vector2(x0, 14.0), Kit.INK if k == si else Kit.DIM)
				x0 += nm.length() * 5.6 + 8.0
			var formula: Dictionary = D.formula
			Kit.label(n, b, str(formula.get(shape, "")), Vector2(W / 2.0, cy + R * 1.5 + 12.0), Kit.BONE, true)
			_label_r(n, b, "rate %s/s · alive %d · rise %s" % [str(D.rate), b.alive, str(D.rise)], Vector2(W - 8.0, H - 20.0), Kit.DIM)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"zsort":
			Kit.stage(n, b, 0.55)
			var half := W / 2.0
			var pool: Array = b.pool
			var order: Array = b.order
			var nn := pool.size()
			var band: float = H * D.soft
			var far := Color("4A4A6E")
			var near := Color("E6E2F2")
			# left: pool order, clipped hard at the floor. right: sorted, soft at the floor.
			# the web's ctx.clip(rect) is a polygon clip by arithmetic; its vertical
			# gradient is a colour per vertex whose alpha falls to zero at the ground.
			for pass_i in 2:
				var soft := pass_i == 1
				var ox := half if soft else 0.0
				for k in nn:
					var p: Dictionary = pool[order[k]] if soft else pool[k]
					var a: float = D.alpha * (0.35 + p.z * 0.65) * clampf(minf(p.age * 2.0, (D.life - p.age) * 1.5), 0.0, 1.0)
					if a <= 0.005:
						continue
					var c: Color = far.lerp(near, p.z)
					var pr: float = p.r
					var pts := _circle_pts(Vector2(ox + p.x, p.y), pr, 20)
					if soft:                             # clip only the puffs that cross an edge
						if p.x - pr < 0.0:
							pts = _clip_poly(pts, 0, half, false)
						if p.y + pr > H:
							pts = _clip_poly(pts, 1, H, true)
					else:
						if p.x + pr > half:
							pts = _clip_poly(pts, 0, half, true)
						if p.y + pr > GY:
							pts = _clip_poly(pts, 1, GY, true)
					if pts.size() < 3:
						continue
					if soft and p.y + p.r > GY - band:   # near the floor: a vertical fade to zero at the ground
						var cols := PackedColorArray()
						for pt in pts:
							cols.append(_al(c, a * clampf((GY - pt.y) / band, 0.0, 1.0)))
						n.draw_polygon(pts, cols)
					else:
						n.draw_colored_polygon(pts, _al(c, a))
			Kit.line(n, Vector2(half, 0.0), Vector2(half, H), Kit.DIM, 1.0)
			# the draw order's z, as strips: jagged on the left, a ramp on the right
			var sw := maxf(1.0, (half - 16.0) / nn)
			var sh := H * 0.07
			for k in nn:
				var pk: Dictionary = pool[k]
				var po: Dictionary = pool[order[k]]
				Kit.rect(n, Rect2(8.0 + k * sw, 22.0 + sh * (1.0 - pk.z), maxf(0.5, sw - 0.5), sh * pk.z), _al(Kit.HOT, 0.6))
				Kit.rect(n, Rect2(half + 8.0 + k * sw, 22.0 + sh * (1.0 - po.z), maxf(0.5, sw - 0.5), sh * po.z), _al(Kit.GOOD, 0.6))
			Kit.label(n, b, "pool order · hard cut", Vector2(8, 14), Kit.HOT)
			Kit.label(n, b, "sorted by z · soft floor", Vector2(half + 8.0, 14.0), Kit.GOOD)
			_label_r(n, b, "soft band", Vector2(W - 8.0, GY - band - 3.0), Kit.DIM)
			Kit.line(n, Vector2(half, GY - band), Vector2(W, GY - band), _al(Kit.GOOD, 0.3), 1.0)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"voronoi":
			Kit.stage(n, b, 0.45)
			var un: float = Kit.hero_unit(b)
			var hx: float = b.hx
			var blocks: Array = b.blocks
			var seeds: Array = b.seeds
			var cells: int = D.cells
			var phase: int = b.phase
			var age: float = b.age
			if phase == 0:
				var fadeIn := clampf(b.timer * 3.0, 0.0, 1.0)
				for q in blocks:
					var qd: Dictionary = q
					var col: Color = qd.c
					col.a *= fadeIn
					Kit.rect(n, Rect2(hx + qd.ox * un, GY + qd.oy * un, un, un), col)
				for q in blocks:
					var qd: Dictionary = q
					Kit.rect(n, Rect2(hx + qd.ox * un, GY + qd.oy * un, un, un), _hsl(fmod(qd.cell * 47.0, 360.0), 0.7, 0.6, 0.28 * fadeIn))
				for i in cells:
					var sd: Dictionary = seeds[i]
					Kit.dot(n, Vector2(hx + sd.x * un, GY + sd.y * un), 1.8, _al(Kit.SPARK, fadeIn))
			else:
				var a := clampf(1.0 - (age - D.fade * 0.5) / (D.fade * 0.5), 0.0, 1.0)
				for k in cells:
					var p: Dictionary = b.pieces[k]
					if p.n == 0:
						continue
					n.draw_set_transform(origin + Vector2(p.x, p.y), p.rot, Vector2.ONE)
					for bi in p.idx:
						var qd: Dictionary = blocks[bi]
						var col: Color = qd.c
						col.a *= a
						n.draw_rect(Rect2((qd.ox - p.cx) * un, (qd.oy - p.cy) * un, un + 0.3, un + 0.3), col)
					n.draw_set_transform(origin, 0.0, Vector2.ONE)
				if age < 0.4:
					var k := 1.0 - age / 0.4
					var ip := Vector2(b.ix, b.iy)
					Kit.ring(n, ip, (1.0 - k) * 22.0, _al(Kit.SPARK, k), 1.5)
					for r in 6:
						Kit.line(n, ip, ip + Vector2(cos(r * TAU / 6.0), sin(r * TAU / 6.0)) * 6.0 * k, _al(Kit.INK, k), 1.0)
			# the seeds' map, magnified in the corner
			var ms := maxf(1.5, un * 0.6)
			var mx := 10.0
			var my := 14.0
			n.draw_rect(Rect2(mx - 0.5, my - 0.5, 14.0 * ms + 1.0, 19.0 * ms + 1.0), Kit.DIM, false, 1.0)
			for q in blocks:
				var qd: Dictionary = q
				Kit.rect(n, Rect2(mx + (qd.ox + 7.0) * ms, my + (qd.oy + 18.0) * ms, ms, ms), _hsl(fmod(qd.cell * 47.0, 360.0), 0.7, 0.55, 0.9))
			for i in cells:
				var sd: Dictionary = seeds[i]
				Kit.dot(n, Vector2(mx + (sd.x + 7.0) * ms, my + (sd.y + 18.0) * ms), 1.2, Kit.INK)
			Kit.label(n, b, "%d seeds · %d blocks · %s" % [cells, blocks.size(), "whole" if phase == 0 else "pieces %.1fs" % age], Vector2(mx, my + 19.0 * ms + 12.0), Kit.BONE)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"cracks":
			Kit.stage(n, b, 0.35)
			var slab: Rect2 = b.slab
			var look: Dictionary = b.look
			var fill: Color = look.fill
			var crack: Color = look.crack
			var edge: Color = look.edge
			var k: float = b.k
			var fadeK: float = b.fadeK
			Kit.rect(n, slab, fill)
			n.draw_rect(Rect2(slab.position.x + 0.5, slab.position.y + 0.5, slab.size.x - 1.0, slab.size.y - 1.0), _al(Kit.BONE, 0.4), false, 1.0)
			# the layer: every segment twice (a lighter edge offset by a pixel, then the crack), at the layer's alpha
			var edge_f := _al(edge, edge.a * fadeK)
			var crack_f := _al(crack, crack.a * fadeK)
			for sg in b.segs:
				var sa: Array = sg
				var a0 := Vector2(sa[0], sa[1])
				var a1 := Vector2(sa[2], sa[3])
				var w: float = sa[4]
				n.draw_line(a0 + Vector2.ONE, a1 + Vector2.ONE, edge_f, w + 2.0)
				n.draw_line(a0, a1, crack_f, w)
			for dp in b.dots:
				Kit.dot(n, dp, 2.0 * k, crack_f)
			var tips: Array = b.tips
			for i in tips.size():
				var tp: Dictionary = tips[i]
				if tp.on:
					Kit.dot(n, Vector2(tp.x, tp.y), 1.6, Kit.SPARK)
			var live: int = b.live
			if live > 0:
				var tp: Dictionary = tips[b.sample]
				Kit.label(n, b, "w %.2f θ %.2f" % [tp.w, fposmod(tp.a, TAU)], Vector2(tp.x + 6.0, tp.y - 4.0), Kit.SPARK)
			Kit.label(n, b, "%s · tips %d/%d · segments %d · hits %d/%d" % [D.surface, live, int(D.branches), b.nseg, b.hits, int(D.hits)], Vector2(8, 14), Kit.BONE)
			_label_r(n, b, "decay %s · fork %s · jitter %s" % [str(D.decay), str(D.fork), str(D.jitter)], Vector2(W - 8.0, 14.0), Kit.DIM)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"arc":
			Kit.stage(n, b, 0.5)
			var S: Array = b.S
			var nn: int = D.n
			var head: int = b.head
			var clock: float = b.clock
			var fade: float = D.fade
			var rise: float = D.rise
			var colour := Color(D.colour as String)
			var a := _arc_angle(b)
			var ca := cos(a)
			var sa := sin(a)
			var px: float = b.px
			var py: float = b.py
			# the ribbon: quads between neighbouring samples, oldest first; the web's
			# hilt → tip gradient is a colour per vertex
			var quads := 0
			for i in nn - 1:
				var p: Dictionary = S[(head + i) % nn]
				var q: Dictionary = S[(head + i + 1) % nn]
				var ap: float = 1.0 - (clock - p.t0) / fade
				var aq: float = 1.0 - (clock - q.t0) / fade
				if ap <= 0.0 or aq <= 0.0 or q.t0 < p.t0:
					continue
				var al := clampf(minf(ap, aq), 0.0, 1.0)
				var lift: float = rise * H * (clock - q.t0)
				var pts := PackedVector2Array([Vector2(p.hx, p.hy - lift), Vector2(p.tx, p.ty - lift), Vector2(q.tx, q.ty - lift), Vector2(q.hx, q.hy - lift)])
				var cols := PackedColorArray([_al(colour, al * 0.08), _al(colour, al * 0.85), _al(colour, al * 0.85), _al(colour, al * 0.08)])
				n.draw_polygon(pts, cols)
				Kit.line(n, Vector2(p.tx, p.ty - lift), Vector2(q.tx, q.ty - lift), Color(1.0, 1.0, 1.0, al * 0.6), 1.0)
				quads += 1
			for i in nn:
				var smp: Dictionary = S[i]
				var al: float = 1.0 - (clock - smp.t0) / fade
				if al > 0.0:
					var lift: float = rise * H * (clock - smp.t0)
					Kit.dot(n, Vector2(smp.tx, smp.ty - lift), 1.2, _al(Kit.INK, al * 0.7))
					Kit.dot(n, Vector2(smp.hx, smp.hy - lift), 1.0, _al(Kit.INK, al * 0.4))
			Kit.hero(n, b, Vector2(b.hx, GY), { "pose": "stand", "frame": t })
			var hilt := Vector2(px + ca * H * D.hilt, py + sa * H * D.hilt)
			Kit.line(n, hilt, Vector2(px + ca * H * D.blade, py + sa * H * D.blade), Kit.INK, 2.5)
			Kit.line(n, hilt + Vector2(-sa, ca) * 5.0, hilt - Vector2(-sa, ca) * 5.0, WOOD, 2.0)
			Kit.label(n, b, "θ %.2f · %d quads · step %s · fade %ss" % [a, quads, str(D.step), str(fade)], Vector2(8, 14), Kit.DIM)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"keyframes":
			Kit.stage(n, b, 0.6)
			for f in b.flashes:
				var fd: Dictionary = f
				if fd.age < 0.15:
					Kit.glow(n, Vector2(fd.x, fd.y), H * 0.22 * (1.0 - fd.age / 0.15 * 0.5), Kit.SPARK, 0.9 * (1.0 - fd.age / 0.15))
			for p in b.pool:
				var pd: Dictionary = p
				if not pd.on:
					continue
				var k: float = 1.0 - pd.age / pd.life
				if pd.kind == "spark":
					Kit.dot(n, Vector2(pd.x, pd.y), 1.2 + k, _al(Kit.SPARK, 0.3 + k * 0.7))
				else:
					Kit.dot(n, Vector2(pd.x, pd.y), 2.0 + (1.0 - k) * 7.0, _al(SMOKE, k * 0.3))
			for rg in b.rings:
				var rd: Dictionary = rg
				if rd.age < 0.5:
					Kit.ring(n, Vector2(rd.x, rd.y), rd.age / 0.5 * H * 0.18, _al(Kit.INK, 1.0 - rd.age / 0.5), 2.0)
			# the timeline: cues as ticks, a playhead per runner, the sequence as text
			var seq: Array = D.seq
			var T: float = b.T_end
			var x0 := 14.0
			var x1 := W - 14.0
			var y0 := 22.0
			Kit.line(n, Vector2(x0, y0), Vector2(x1, y0), Kit.BONE, 1.0)
			var runs: Array = b.runs
			var last: int = b.last
			var lr: Dictionary = runs[last] if last >= 0 else {}
			for i in seq.size():
				var c: Dictionary = seq[i]
				var at: float = c["at"]
				var x := x0 + (x1 - x0) * at / T
				var lit: bool = not lr.is_empty() and lr.on and lr.i > i
				Kit.line(n, Vector2(x, y0 - 4.0), Vector2(x, y0 + 4.0), Kit.SPARK if lit else Kit.BONE, 2.0 if lit else 1.0)
				Kit.label(n, b, str(c["do"]), Vector2(x, y0 + (24.0 if i % 2 == 1 else 14.0)), Kit.SPARK if lit else Kit.DIM, true)
				Kit.label(n, b, str(c["at"]) + "s", Vector2(x, y0 - 7.0), Kit.DIM, true)
			for k in runs.size():
				var r: Dictionary = runs[k]
				if r.on:
					var x := x0 + (x1 - x0) * clampf(r.t / T, 0.0, 1.0)
					Kit.line(n, Vector2(x, y0 - 6.0), Vector2(x, y0 + 6.0), Kit.INK if k == last else _al(Kit.INK, 0.35), 1.5)
			var txt := "seq = ["
			for i in seq.size():
				var c: Dictionary = seq[i]
				txt += (", " if i > 0 else "") + "{at %s, do %s}" % [str(c["at"]), str(c["do"])]
			Kit.label(n, b, txt + "]", Vector2(W / 2.0, H - 20.0), Kit.DIM, true)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"layers":
			Kit.stage(n, b, 0.3)
			var cam: float = b.cam
			var wx: float = b.wx
			# the world layer: props at world x, the ground's hatching, the hero
			var sp := W * 0.5
			var k0 := int(floor(cam / sp)) - 1
			for k in range(k0, k0 + 5):
				var x := k * sp - cam
				if k % 2 != 0:
					Kit.tree(n, Vector2(x, GY), H * 0.3)
				else:
					Kit.crate(n, Vector2(x + sp * 0.3, GY), H * 0.09)
			var hx0 := -fposmod(cam, 12.0)
			var x := hx0
			while x < W:
				n.draw_line(Vector2(x, GY + 2.0), Vector2(x - 5.0, GY + 8.0), SLOT_DIM, 1.0)
				x += 12.0
			var hx := wx - cam
			Kit.hero(n, b, Vector2(hx, GY), { "pose": "run", "frame": t })
			for p in b.pool:
				var pd: Dictionary = p
				if not pd.on:
					continue
				var space: String = pd.space
				var dx: float = pd.x - cam if space == "world" else (pd.x if space == "screen" else pd.x - 2.0 * (cam - pd.cam0))
				var k: float = 1.0 - pd.age / pd.life
				Kit.dot(n, Vector2(dx, pd.y), 1.2 + k, _al(Kit.HOT, 0.25 + k * 0.4) if pd.ghost else _al(Kit.SPARK, 0.3 + k * 0.7))
			# the screen layer: a damage vignette and a hit marker that ignore the camera
			var hud: float = b.hud
			if hud > 0.0:
				n.draw_rect(Rect2(0.0, 0.0, W, H), _al(Kit.HOT, hud * 0.5), false, 10.0)
			Kit.rect(n, Rect2(8.0, 6.0, 40.0, 12.0), Color(19.0 / 255.0, 16.0 / 255.0, 32.0 / 255.0, 0.6))
			Kit.label(n, b, "HIT %d" % b.hits, Vector2(12, 15), Kit.HOT if hud > 0.0 else Kit.BONE)
			# the two layers, as a legend
			var lx := W - 8.0
			var ly := 14.0
			_label_r(n, b, "screen layer: vignette, HIT counter", Vector2(lx, ly), Kit.GOOD)
			_label_r(n, b, "world layer: ground, hero, sparks (%s)" % D.space, Vector2(lx, ly + 12.0), Kit.SPARK)
			if D.ghost != "none" and D.ghost != D.space:
				_label_r(n, b, "the bug: sparks in %s space" % D.ghost, Vector2(lx, ly + 24.0), Kit.HOT)
			_label_r(n, b, "camera x %d%s" % [roundi(cam), " (held)" if b.holdT > 0.0 else ""], Vector2(lx, ly + 36.0), Kit.DIM)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"budget":
			Kit.stage(n, b, 0.5)
			var hx: float = b.hx
			var ex: float = b.ex
			var counts: Array = b.counts
			Kit.hero(n, b, Vector2(hx, GY), { "pose": "stand", "frame": t })
			Kit.rect(n, Rect2(ex - 6.0, GY - 16.0, 12.0, 16.0), Color("6E3A3A"))
			Kit.dot(n, Vector2(ex - 2.0, GY - 11.0), 1.2, Kit.INK)
			Kit.dot(n, Vector2(ex + 2.0, GY - 11.0), 1.2, Kit.INK)
			for p in b.pool:
				var pd: Dictionary = p
				if not pd.on:
					continue
				var k: float = 1.0 - pd.age / pd.life
				var pri: int = pd.pri
				if pri < 4:
					Kit.dot(n, Vector2(pd.x, pd.y), 1.2 + k, _al(_bud_col(pri), 0.3 + k * 0.7))
				else:
					Kit.dot(n, Vector2(pd.x, pd.y), 1.0, _al(Kit.BONE, k * 0.45))
			# the meter: alive by priority against the budget line, on the pool's full width
			var mx := 8.0
			var mw := W - 16.0
			var my := 8.0
			var mh := 7.0
			Kit.rect(n, Rect2(mx, my, mw, mh), Color(201.0 / 255.0, 196.0 / 255.0, 228.0 / 255.0, 0.12))
			var x := mx
			for q in range(1, 5):
				var w: float = mw * int(counts[q]) / float(BUDGET_N)
				Kit.rect(n, Rect2(x, my, w, mh), _bud_col(q))
				x += w
			var bx: float = mx + mw * D.budget / float(BUDGET_N)
			Kit.line(n, Vector2(bx, my - 3.0), Vector2(bx, my + mh + 3.0), Kit.HOT, 1.5)
			if bx > W * 0.8:
				_label_r(n, b, "budget %d" % int(D.budget), Vector2(bx, my + mh + 12.0), Kit.HOT)
			else:
				Kit.label(n, b, "budget %d" % int(D.budget), Vector2(bx, my + mh + 12.0), Kit.HOT, true)
			_label_r(n, b, "alive %d / pool %d" % [b.alive, BUDGET_N], Vector2(W - 8.0, my + mh + 12.0), Kit.DIM)
			# the priority table
			var em: Array = b.em
			for i in em.size():
				var e: Dictionary = em[i]
				var y := my + mh + 24.0 + i * 11.0
				var pri: int = e.pri
				Kit.rect(n, Rect2(mx, y - 7.0, 6.0, 6.0), _bud_col(pri))
				Kit.label(n, b, "%d %s" % [pri, e.name], Vector2(mx + 10.0, y), Kit.HOT if e.flag > 0.0 else Kit.BONE)
				Kit.label(n, b, "×%d" % int(counts[pri]), Vector2(mx + 88.0, y), Kit.BONE)
				if e.flag > 0.0:
					Kit.label(n, b, "CULLED" if e.culled > e.refused else "REFUSED", Vector2(mx + 118.0, y), Kit.HOT)
				elif e.culled > 0 or e.refused > 0:
					Kit.label(n, b, "culled %d · refused %d" % [e.culled, e.refused], Vector2(mx + 118.0, y), Kit.DIM)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
