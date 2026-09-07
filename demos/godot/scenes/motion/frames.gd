extends RefCounted

const Kit := preload("res://scenes/motion/kit.gd")
## REWINDS, ROOMS & BEATS — thirteen movement styles, ported from the web
## lexicon (fams/frames.js). The time family, second lap: what a game
## remembers about TIME, and the shape of the WINDOW it looks through. A
## ring buffer of states is a rewind and a replay; a fixed step plus an
## alpha is motion smooth at any frame rate; an energy pool is a turn order;
## a bpm is a beat every input is measured against; two clocks in one frame
## are a pause; named countdowns are cooldowns. Then the camera proper —
## framing a group, clamping to rooms, kicking on a shot, punching in on a
## hit, riding a rail, orbiting a pivot — and the world that has no edge at
## all. Frame counters, buffers, clocks and camera frames are all drawn
## where they act.

const TITLE := "Rewinds, rooms & beats"
const BLURB := "ring buffers, fixed steps, energy turns, the beat, pause, cooldowns, group framing, room cameras, kicks, zooms, rails, orbits, wrap"
const DEFS := [
	{ "id": "rewind", "letter": "R", "name": "Rewind",
		"hint": "a ring buffer keeps the last 4 s of state at 30 Hz; hold to play it backward, let go to resume from there (Braid) — drag to rewind",
		"drag": true,
		"dials": { "seconds": 4,        # how much past the buffer holds
			"hz": 30,                   # snapshots per second
			"g": 1.6,                   # gravity, ×H per second²
			"e": 0.92,                  # restitution on the walls and pegs
			"autoEvery": 5,             # the idle rewind: after this many seconds of play…
			"autoLen": 1.3,             # …rewind for this long
			"label": "buf[(head − k) mod N] · hold: k += hz·dt" },
		"rhyme": { "name": "Rerun", "hint": "ten seconds of past at fifteen snapshots a second — a long, chunky buffer where the rewind visibly steps from slot to slot",
			"dials": { "seconds": 10, "hz": 15 } } },
	{ "id": "xtrapolate", "letter": "X", "name": "Xtrapolate",
		"hint": "a fixed-step sim at hz; between ticks draw the last state, a blend of the last two by α = acc/step, or the last run ahead by acc — press to change hz",
		"dials": { "hzList": [20, 10, 40],   # the fixed simulation rates the press cycles through
			"speed": 0.9,               # horizontal speed, columns per second
			"g": 2.0,                   # gravity, ×H per second²
			"apex": 0.34,               # bounce apex, ×H
			"trail": 24,                # draws remembered per column
			"label": "α = acc/step · a + (b − a)·α · b + v·acc" },
		"rhyme": { "name": "Xtralow", "hint": "ten, five and three ticks a second with longer trails — the raw column crawls in lumps, the others stay smooth",
			"dials": { "hzList": [10, 5, 3], "trail": 40 } } },
	{ "id": "initiative", "letter": "I", "name": "Initiative",
		"hint": "each tick every actor adds its speed to an energy pool and acts at 100 — the fast rat acts twice per turn of yours — press to take your turn",
		"dials": { "tickEvery": 0.28,   # seconds per scheduler tick (a roguelike ticks instantly)
			"cost": 100,                # energy one action costs
			"player": 100,              # your speed
			"speeds": [200, 50, 100],   # the rat, the ogre, the bat
			"autoWait": 1.4,            # the idle player acts after this long
			"cols": 8, "rows": 5,       # the grid
			"label": "e += speed per tick · act while e ≥ cost" },
		"rhyme": { "name": "Impatient", "hint": "you at speed 200 among sluggish monsters — two moves of yours to their one, and the rat is the slow one now",
			"dials": { "player": 200, "speeds": [60, 40, 50] } } },
	{ "id": "kickdrum", "letter": "K", "name": "Kickdrum",
		"hint": "beat = t·bpm/60: hops land only on the beat, and a press is judged by its distance to the nearest one — early, late, miss — press to hop on the beat",
		"dials": { "bpm": 120,          # beats per minute
			"window": 0.1,              # seconds either side of the beat that still count
			"tiles": 8,                 # the dance floor
			"hopT": 0.16,               # seconds a hop takes
			"kickHz": 110,              # the kick's pitch
			"label": "beat = t·bpm/60 · Δ = t − beat·60/bpm · |Δ| ≤ w" },
		"rhyme": { "name": "Klezmer", "hint": "180 beats a minute and half the window — the hops come thick and fast and the autopilot's human error misses more than it lands",
			"dials": { "bpm": 180, "window": 0.05 } } },
	{ "id": "pause", "letter": "P", "name": "Pause",
		"hint": "two clocks in one frame: the world's dt is scaled to 0 while the menu spinner keeps the real dt — pause is a time scale of zero — press to toggle it",
		"dials": { "scale": 0,          # the world's dt multiplier while paused (0 = frozen solid)
			"every": 3.2,               # the idle toggle: seconds of play…
			"pauseFor": 2,              # …then seconds of pause
			"g": 1.8,                   # gravity, ×H per second²
			"spin": 5,                  # the spinner, radians per second of UNSCALED time
			"label": "world += dt × scale · menu += dt" },
		"rhyme": { "name": "Pausebullet", "hint": "the paused world runs at a twentieth speed instead of freezing — the bullet-time menu, the ball still creeping while the spinner spins",
			"dials": { "scale": 0.05, "pauseFor": 3.5 } } },
	{ "id": "cooldown", "letter": "C", "name": "Cooldown",
		"hint": "named countdowns — dash 0.4 s, shot 0.15 s, heal 5 s — a use starts its timer, and it is refused until that hits zero — press to fire everything",
		"dials": { "dash": 0.4, "shot": 0.15, "heal": 5,   # the cooldowns, seconds
			"tryEvery": 0.3,            # the autopilot tries a random ability this often
			"dashLen": 0.22,            # dash distance, ×W
			"label": "use: t[k] ≤ 0 ? t[k] = cd[k] : refused" },
		"rhyme": { "name": "Cheatmode", "hint": "every cooldown near zero — the bars barely fill before they empty, nothing is ever refused, and the room fills with bullets",
			"dials": { "dash": 0.03, "shot": 0.03, "heal": 0.15 } } },
	{ "id": "xtents", "letter": "X", "name": "Xtents",
		"hint": "the camera centres on the group's bounding box and zooms so everyone fits — padded, clamped to min..max (Smash) — press to scatter or gather",
		"dials": { "pad": 0.12,         # padding around the box, ×W each side
			"minZoom": 0.55,            # the zoom floor: never further out than this
			"maxZoom": 1.7,             # the zoom ceiling: never closer than this
			"omega": 4,                 # the framing spring (ζ = 1) for centre and zoom
			"phase": 4.5,               # seconds between the idle scatter and gather
			"world": 2.6,               # the arena, ×W
			"label": "z = clamp(min(W/(bw+2p), H/(bh+2p)), min, max)" },
		"rhyme": { "name": "Xtrawide", "hint": "two and a half times the padding and a lazy spring — the fighters float in a wide frame that drifts after them like a broadcast crane",
			"dials": { "pad": 0.3, "omega": 1.5 } } },
	{ "id": "pan", "letter": "P", "name": "Pan",
		"hint": "the view is clamped to the level; cross a room's edge and the camera slides one whole screen over (Zelda) — press to send the mote",
		"dials": { "mode": "rooms",     # "rooms": flip screen by screen · "scroll": a bounded smooth follow
			"rooms": 2,                 # rooms per side (a 2 × 2 level)
			"slide": 0.55,              # seconds the room flip takes
			"speed": 0.55,              # walking speed, ×W per second
			"lag": 5,                   # the scroll mode's follow rate
			"label": "cam = clamp(focus, 0, level − W) · flip: tween" },
		"rhyme": { "name": "Pushscroll", "hint": "no rooms at all — the camera follows the mote smoothly and the clamp alone stops it at the level's edges",
			"dials": { "mode": "scroll", "lag": 4 } } },
	{ "id": "nudge", "letter": "N", "name": "Nudge",
		"hint": "a shot kicks the camera back along the recoil line; a spring returns it — a punch, not noise (the shake beside it is) — press to fire at your click",
		"dials": { "kick": 0.06,        # the camera kick, ×W per shot
			"omega": 18,                # the return spring's ω, rad/s
			"zeta": 0.5,                # its damping ratio (under 1 = a little overshoot)
			"trauma": 0.55,             # trauma a shot adds to the shake panel
			"shakeAmp": 0.05,           # the shake's reach at trauma 1, ×W
			"shakeFreq": 22,            # the noise's speed
			"every": 1.3,               # the autopilot fires this often
			"label": "kick: x −= k·dir → spring · shake: noise·trauma²" },
		"rhyme": { "name": "Nailgun", "hint": "four shots a second, a small kick and a very stiff spring — a rattle of tiny directional punches instead of one big one",
			"dials": { "kick": 0.025, "omega": 40, "every": 0.25 } } },
	{ "id": "zoompunch", "letter": "Z", "name": "Zoompunch",
		"hint": "a hit zooms in about the impact point and springs back — scale about a focus: p' = f + (p − f)·z — press to hit; click a corner for the death dolly",
		"dials": { "punch": 0.35,       # zoom added by a hit (1 → 1.35)
			"omega": 14,                # the punch spring's ω
			"zeta": 0.4,                # its damping (a little wobble)
			"dollyZoom": 2.3,           # the death zoom
			"dolly": 2.6,               # seconds the death dolly takes
			"every": 1.5,               # the autopilot's hits
			"label": "p' = f + (p − f)·z · punch: spring · dolly: ease" },
		"rhyme": { "name": "Zoomslow", "hint": "a gentle punch on a soft spring and a five-second dolly — the art-film cut, every zoom a slow breath",
			"dials": { "punch": 0.12, "omega": 6, "dolly": 5 } } },
	{ "id": "tracking", "letter": "T", "name": "Tracking",
		"hint": "the camera rides a Bézier with its look-at pinned to the target and its fov keyframed along the rail — map + what it sees — press to move the target",
		"dials": { "rail": [[0.08, 0.88], [0.08, 0.1], [0.92, 0.1], [0.92, 0.88]],   # the cubic's four control points, ×W and ×H
			"fovKeys": [[0, 75], [0.5, 32], [1, 85]],   # keyframes: [u along the rail, fov in degrees]
			"period": 9,                # seconds for one ride there and back
			"range": 0.5,               # how far the frustum is drawn, ×W
			"wander": 3,                # seconds between the target's wanders
			"label": "cam = B(u) · look-at target · fov = keys(u)" },
		"rhyme": { "name": "Trucking", "hint": "a straight rail along the bottom and one constant fov — the sideways truck of a stage camera, only the look-at turning",
			"dials": { "rail": [[0.08, 0.9], [0.36, 0.9], [0.64, 0.9], [0.92, 0.9]], "fovKeys": [[0, 50], [1, 50]] } } },
	{ "id": "zenith", "letter": "Z", "name": "Zenith",
		"hint": "yaw and pitch swing the camera about the mote on a spring arm — pitch stops short of straight up, the arm shortens at a wall — drag to orbit",
		"drag": true,
		"dials": { "arm": 0.34,         # the spring arm's full length, ×room width
			"pitchMin": 0.12,           # radians above the floor
			"pitchMax": 1.25,           # radians — short of π/2, the ZENITH
			"margin": 0.03,             # the arm stops this far short of a wall, ×room width
			"fov": 75,                  # the inset's field of view, degrees
			"yawSpeed": 0.4,            # the idle orbit, radians per second
			"label": "pitch ∈ [min, max] · arm = min(L, wall − m)" },
		"rhyme": { "name": "Zoomedin", "hint": "a short arm, a wider pitch range and a wide lens — the over-the-shoulder camera that almost never meets a wall",
			"dials": { "arm": 0.14, "pitchMax": 1.5, "fov": 95 } } },
	{ "id": "wrap", "letter": "W", "name": "Wrap",
		"hint": "a torus: past the right edge is the left (x mod W); near a seam the sprite is drawn twice so it never blinks — press to thrust at your click",
		"dials": { "asteroids": 5,      # drifting rocks
			"thrust": 0.6,              # ship acceleration, ×W per second²
			"drag": 0.5,                # velocity damping per second
			"wrapX": true,              # wrap horizontally…
			"wrapY": true,              # …and vertically (false = bounce off the top and bottom)
			"every": 1.4,               # the autopilot's thrust bursts
			"label": "x = ((x mod W) + W) mod W · draw at x and x ± W" },
		"rhyme": { "name": "Worldsedge", "hint": "wrap left-right only and bounce off the top and bottom, in a thicker rock field — a cylinder world, the Defender strip",
			"dials": { "wrapY": false, "asteroids": 8 } } },
]

const FAINT := Color(0.91, 0.898, 0.957, 0.55)   # the web label's default ink
const INSET_BG := Color(0.055, 0.043, 0.102)      # "#0E0B1A" — the insets' black
const DASH_INK := Color(0.875, 0.957, 1.0)        # "#DFF4FF" — the mote mid-dash
const NUDGE_HIST := 48                            # camera-offset samples kept per panel
const ZOOM_HIST := 60                             # z samples kept (one second)

## A number for a label: "1" for whole values, "0.25" otherwise (JS's "" + k).
static func _num(v: float) -> String:
	return ("%d" % roundi(v)) if v == roundf(v) else ("%s" % v)

## The web label's "right" alignment: measure, then draw ending at p.x.
static func _label_right(n: CanvasItem, b: Dictionary, txt: String, p: Vector2, col: Color) -> void:
	var f := ThemeDB.fallback_font
	var w: float = f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	Kit.label(n, b, txt, Vector2(p.x - w, p.y), col)

## The web kit's ease(k): clamp, then smoothstep.
static func _ease(k: float) -> float:
	var kk := clampf(k, 0.0, 1.0)
	return kk * kk * (3.0 - 2.0 * kk)

## The web kit's wrapAngle: back into −π..π.
static func _wrap_angle(a: float) -> float:
	return wrapf(a, -PI, PI)

## A dashed outline (the web's setLineDash + stroked poly), edge by edge.
static func _dashed_poly(n: CanvasItem, pts: Array, col: Color, w: float, dash: float) -> void:
	for i in pts.size():
		n.draw_dashed_line(pts[i], pts[(i + 1) % pts.size()], col, w, dash)

## An Array of count floats, all v (the web's Float32Array; a plain Array so
## the card dictionary holds it by reference).
static func _floats(count: int, v: float) -> Array:
	var out: Array = []
	out.resize(count)
	out.fill(v)
	return out

# ---- Rewind -------------------------------------------------------------

## The slot k snapshots behind the head.
static func _rw_slot(b: Dictionary, k: int) -> int:
	var N: int = b.N
	var head: int = b.head
	return posmod(head - k, N)

## The scrubber x of slot k (oldest left, newest right).
static func _rw_px(b: Dictionary, k: float) -> float:
	var W: float = b.w
	var N: int = b.N
	var count: int = b.count
	return W * 0.08 + W * 0.84 * (count - 1 - k) / N

# ---- Xtrapolate ---------------------------------------------------------

## One fixed step of h seconds: b becomes a, then b advances.
static func _xt_tick(b: Dictionary, h: float) -> void:
	var D: Dictionary = b.D
	var H: float = b.h
	var GY: float = b.gy
	var cw: float = b.cw
	b.ax = b.bx                                      # b becomes a — the previous state is kept for α
	b.ay = b.by
	b.avx = b.bvx
	b.avy = b.bvy
	b.bvy += D.g * H * h
	b.bx += b.bvx * h
	b.by += b.bvy * h
	if b.bx < 9.0:
		b.bx = 9.0
		b.bvx = absf(b.bvx)
	if b.bx > cw - 9.0:
		b.bx = cw - 9.0
		b.bvx = -absf(b.bvx)
	if b.by > GY - 9.0:
		b.by = GY - 9.0
		b.bvy = -b.v0

## Where column i draws the ball between ticks.
static func _xt_pos(b: Dictionary, i: int, al: float, acc: float) -> Vector2:
	var ax: float = b.ax
	var ay: float = b.ay
	var bx: float = b.bx
	var by: float = b.by
	if i == 0:
		return Vector2(bx, by)                       # raw: the newest tick
	if i == 1:
		return Vector2(ax + (bx - ax) * al, ay + (by - ay) * al)   # interp: between a and b
	var bvx: float = b.bvx
	var bvy: float = b.bvy
	return Vector2(bx + bvx * acc, by + bvy * acc)   # extrap: b run ahead

# ---- Initiative ---------------------------------------------------------

static func _in_cx(b: Dictionary, a: Dictionary) -> float:
	var gx0: float = b.gx0
	var cell: float = b.cell
	var ax: int = a.x
	return gx0 + (ax + 0.5) * cell

static func _in_cy(b: Dictionary, a: Dictionary) -> float:
	var gy0: float = b.gy0
	var cell: float = b.cell
	var ay: int = a.y
	return gy0 + (ay + 0.5) * cell

## The index of the actor standing on a cell, or −1.
static func _in_at(b: Dictionary, x: int, y: int) -> int:
	var actors: Array = b.actors
	for i in actors.size():
		var a: Dictionary = actors[i]
		if a.x == x and a.y == y:
			return i
	return -1

static func _in_step(b: Dictionary, a: Dictionary, dx: int, dy: int) -> bool:
	var cols: int = b.cols
	var rows: int = b.rows
	var nx: int = clampi(a.x + dx, 0, cols - 1)
	var ny: int = clampi(a.y + dy, 0, rows - 1)
	if (nx == a.x and ny == a.y) or _in_at(b, nx, ny) >= 0:
		return false
	a.x = nx
	a.y = ny
	return true

static func _in_say(b: Dictionary, s: String) -> void:
	var entries: Array = b.log
	entries.push_front(s)
	if entries.size() > 5:
		entries.pop_back()

## The player's action: the ordered step, or a step away from the nearest.
static func _in_player_act(b: Dictionary, a: Dictionary) -> void:
	var actors: Array = b.actors
	if b.wantX != 0 or b.wantY != 0:
		_in_say(b, "you move" if _in_step(b, a, b.wantX, b.wantY) else "you bump")
		b.wantX = 0
		b.wantY = 0
		return
	if actors.size() < 2:
		_in_say(b, "you wait")
		return
	var m: Dictionary = actors[1]                    # no order given: step away from the nearest
	var best: int = 1000000000
	for i in range(1, actors.size()):
		var o: Dictionary = actors[i]
		var d: int = absi(o.x - a.x) + absi(o.y - a.y)
		if d < best:
			best = d
			m = o
	var dx: int = a.x - m.x
	var dy: int = a.y - m.y
	var sx: int = -1 if dx < 0 else 1
	var sy: int = -1 if dy < 0 else 1
	var ok: bool
	if absi(dx) >= absi(dy):
		ok = _in_step(b, a, sx, 0) or _in_step(b, a, 0, sy)
	else:
		ok = _in_step(b, a, 0, sy) or _in_step(b, a, sx, 0)
	_in_say(b, "you step away" if ok else "you wait")

## A monster's action: toward you, or a bite.
static func _in_monster_act(b: Dictionary, a: Dictionary) -> void:
	var actors: Array = b.actors
	var p: Dictionary = actors[0]
	var dx: int = p.x - a.x
	var dy: int = p.y - a.y
	if absi(dx) + absi(dy) == 1:
		_in_say(b, "%s bites you" % a.name)
		p.flash = 1.0
		b.bites += 1
		return
	var ok: bool
	if absi(dx) >= absi(dy):
		ok = _in_step(b, a, signi(dx), 0) or _in_step(b, a, 0, signi(dy))
	else:
		ok = _in_step(b, a, 0, signi(dy)) or _in_step(b, a, signi(dx), 0)
	_in_say(b, "%s %s" % [a.name, "moves" if ok else "waits"])

static func _in_act(b: Dictionary, idx: int) -> void:
	var D: Dictionary = b.D
	var a: Dictionary = b.actors[idx]
	a.e -= D.cost
	a.flash = 1.0
	b.turns += 1
	if idx == 0:
		_in_player_act(b, a)
	else:
		_in_monster_act(b, a)

## The scheduler tick: energy by speed, then whoever can pay, acts.
static func _in_tick(b: Dictionary) -> void:
	var D: Dictionary = b.D
	var actors: Array = b.actors
	b.ticks += 1
	for a in actors:
		a.e += a.speed                               # ← the scheduler: energy by speed
	for i in range(1, actors.size()):
		var g := 0
		while actors[i].e >= D.cost and g < 4:
			g += 1
			_in_act(b, i)
	if actors[0].e >= D.cost:                        # your pool is full: the world waits
		b.waiting = true
		b.waitT = 0.0

static func _in_player_go(b: Dictionary) -> void:
	var D: Dictionary = b.D
	_in_act(b, 0)
	b.waiting = b.actors[0].e >= D.cost
	b.waitT = 0.0

# ---- Kickdrum -----------------------------------------------------------

static func _kd_tile_x(b: Dictionary, i: int) -> float:
	var tx0: float = b.tx0
	var tw: float = b.tw
	return tx0 + (i + 0.5) * tw

## An input, measured by Δ — its distance in seconds to the nearest beat.
static func _kd_judge(b: Dictionary, now: float) -> void:
	var D: Dictionary = b.D
	var bpm: float = D.bpm
	var window: float = D.window
	var tiles: int = D.tiles
	var period: float = 60.0 / bpm
	var bb: float = now * bpm / 60.0
	var d: float = (bb - roundf(bb)) * period        # Δ: seconds early (−) or late (+)
	var marks: Array = b.marks
	marks.append({ "d": d, "age": 0.0 })
	if marks.size() > 8:
		marks.pop_front()
	if absf(d) <= window:
		b.hits += 1
		var perfect: bool = absf(d) < window * 0.3
		b.judgeTxt = "perfect" if perfect else ("%s%d ms" % ["early −" if d < 0.0 else "late +", roundi(absf(d) * 1000.0)])
		b.judgeC = Kit.GOOD if perfect else Kit.TARGET
		if b.hop < 0.0:                              # the hop: one tile, on the beat
			var tile: int = b.tile
			var dir: int = b.dir
			if tile + dir < 0 or tile + dir >= tiles:
				dir = -dir
			b.fromX = _kd_tile_x(b, tile)
			tile += dir
			b.toX = _kd_tile_x(b, tile)
			b.tile = tile
			b.dir = dir
			b.hop = 0.0
	else:
		b.misses += 1
		b.judgeTxt = "miss · %d ms off" % roundi(absf(d) * 1000.0)
		b.judgeC = Kit.HOT
		b.stumble = 0.4
	b.judgeT = 0.9

# ---- Pause --------------------------------------------------------------

## A little clock face: one turn per 10 s.
static func _pz_clock(n: CanvasItem, b: Dictionary, c: Vector2, tt: float, col: Color, cname: String) -> void:
	Kit.ring(n, c, 11.0, Kit.DIM, 1.0)
	var a: float = tt / 10.0 * TAU - TAU / 4.0
	Kit.line(n, c, c + Vector2(cos(a) * 9.0, sin(a) * 9.0), col, 1.5)
	Kit.label(n, b, "%s %.1f s" % [cname, tt], c + Vector2(16.0, 4.0), col)

# ---- Cooldown -----------------------------------------------------------

## Use ability k: refused while its timer runs, else act and restart it.
static func _cd_use(b: Dictionary, k: int) -> void:
	var W: float = b.w
	var GY: float = b.gy
	var a: Dictionary = b.T[k]
	if a.t > 0.0:                                    # ← refused: still cooling
		a.refused += 1
		a.flash = 0.3
		return
	a.t = a.cd                                       # ← used: the timer restarts
	a.uses += 1
	a.glow = 0.4
	var dir: int = b.dir
	if k == 0:
		b.dashT = 0.15
		b.streakX = b.x
		b.streakK = 1.0
	if k == 1:
		var bl: Dictionary = b.bullets[b.bi]
		b.bi = (b.bi + 1) % 10
		bl.x = b.x + dir * 12.0
		bl.y = GY - 11.0
		bl.vx = dir * W * 1.3
		bl.on = true
	if k == 2:
		b.hp = minf(1.0, b.hp + 0.3)
		b.healR = 1.0

# ---- Xtents -------------------------------------------------------------

static func _xe_pick(b: Dictionary) -> void:
	var W: float = b.w
	var AW: float = b.AW
	var gather: bool = b.gather
	for f in b.F:
		f.tx = (AW / 2.0 + randf_range(-W * 0.22, W * 0.22)) if gather else randf_range(W * 0.12, AW - W * 0.12)

## World → screen: (v − c)·z + the anchor — the web's one transform, done by
## hand so the kit's mote (which resets the draw transform) still works.
static func _xe_scr(b: Dictionary, v: Vector2) -> Vector2:
	var z: float = b.z
	return (v - Vector2(b.cx, b.cy)) * z + Vector2(b.w / 2.0, b.h * 0.55)

# ---- Pan ----------------------------------------------------------------

static func _pan_room_of(b: Dictionary, x: float, y: float) -> Vector2i:
	var N: int = b.N
	return Vector2i(clampi(floori(x / b.w), 0, N - 1), clampi(floori(y / b.h), 0, N - 1))

## Waypoints through the doorways to (x, y).
static func _pan_route(b: Dictionary, x: float, y: float) -> void:
	var W: float = b.w
	var H: float = b.h
	var a := _pan_room_of(b, b.mx, b.my)
	var bb := _pan_room_of(b, x, y)
	var ax: int = a.x
	var ay: int = a.y
	var path: Array = b.path
	path.clear()
	while ax != bb.x:
		var nx: int = ax + (1 if bb.x > ax else -1)
		path.append(Vector2(W * maxi(ax, nx), (ay + 0.5) * H))
		ax = nx
	while ay != bb.y:
		var ny: int = ay + (1 if bb.y > ay else -1)
		path.append(Vector2((ax + 0.5) * W, H * maxi(ay, ny)))
		ay = ny
	path.append(Vector2(x, y))
	b.goal = Vector2(x, y)

# ---- Nudge --------------------------------------------------------------

static func _nd_fire(b: Dictionary) -> void:
	var D: Dictionary = b.D
	var W: float = b.w
	var gun: Vector2 = b.gun
	var aim: Vector2 = b.aim
	var d := aim - gun
	var dl: float = maxf(1.0, d.length())
	var u := d / dl
	b.shots += 1
	var k: Dictionary = b.P[0]
	k.x -= u.x * W * D.kick                          # ← the kick: straight back from the shot
	k.y -= u.y * W * D.kick
	var s: Dictionary = b.P[1]
	s.trauma = minf(1.0, s.trauma + D.trauma)        # ← the shake: more trauma
	for bl in b.B:
		bl.x = gun.x + u.x * 14.0
		bl.y = gun.y + u.y * 14.0
		bl.vx = u.x * W * 1.4
		bl.vy = u.y * W * 1.4
		bl.life = dl / (W * 1.4)

# ---- Zoompunch ----------------------------------------------------------

static func _zp_hit(b: Dictionary, i: int) -> void:
	var a: Dictionary = b.F[i]
	if a.lunge >= 0.0 or b.dolly >= 0.0:
		return
	a.lunge = 0.0
	b.att = i

# ---- Tracking -----------------------------------------------------------

## The rail: Bezier's cubic at u.
static func _tr_B(b: Dictionary, u: float) -> Vector2:
	var rail: Array = b.D.rail
	var a := 1.0 - u
	var p0: Array = rail[0]
	var p1: Array = rail[1]
	var p2: Array = rail[2]
	var p3: Array = rail[3]
	var x: float = a * a * a * float(p0[0]) + 3.0 * a * a * u * float(p1[0]) + 3.0 * a * u * u * float(p2[0]) + u * u * u * float(p3[0])
	var y: float = a * a * a * float(p0[1]) + 3.0 * a * a * u * float(p1[1]) + 3.0 * a * u * u * float(p2[1]) + u * u * u * float(p3[1])
	return Vector2(b.w * x, b.h * y)

## The fov keyframes, lerped, in radians.
static func _tr_fov_at(b: Dictionary, u: float) -> float:
	var keys: Array = b.D.fovKeys
	var deg := TAU / 360.0
	if keys.size() < 2:
		return (float(keys[0][1]) if keys.size() > 0 else 60.0) * deg
	var k0: Array = keys[0]
	if u <= float(k0[0]):
		return float(k0[1]) * deg
	for i in range(1, keys.size()):
		var ki: Array = keys[i]
		var kp: Array = keys[i - 1]
		if u <= float(ki[0]):
			var span: float = float(ki[0]) - float(kp[0])
			if span == 0.0:
				span = 1.0
			var s: float = (u - float(kp[0])) / span
			return lerpf(float(kp[1]), float(ki[1]), clampf(s, 0.0, 1.0)) * deg
	var kl: Array = keys[keys.size() - 1]
	return float(kl[1]) * deg

# ---- Zenith -------------------------------------------------------------

## The pivot, the arm and the camera for this instant, kept on b.zn.
static func _zn_update(b: Dictionary, t: float) -> void:
	var D: Dictionary = b.D
	var rx0: float = b.rx0
	var ry0: float = b.ry0
	var rw: float = b.rw
	var rh: float = b.rh
	var px: float = rx0 + rw / 2.0 + cos(t * 0.31) * rw * 0.36   # the pivot walks
	var py: float = ry0 + rh / 2.0 + sin(t * 0.43) * rh * 0.36
	var ph: float = atan2(cos(t * 0.43) * 0.43 * rh, -sin(t * 0.31) * 0.31 * rw)
	var L: float = rw * D.arm
	var yaw: float = b.yaw
	var pitch: float = b.pitch
	var lx := cos(yaw)                               # the look direction; the arm goes the other way
	var ly := sin(yaw)
	var dx := -lx
	var dy := -ly
	var hit: float = rw + rh                         # the ray from the pivot along the arm to the room's walls
	if dx > 1.0e-6:
		hit = minf(hit, (rx0 + rw - px) / dx)
	elif dx < -1.0e-6:
		hit = minf(hit, (rx0 - px) / dx)
	if dy > 1.0e-6:
		hit = minf(hit, (ry0 + rh - py) / dy)
	elif dy < -1.0e-6:
		hit = minf(hit, (ry0 - py) / dy)
	var wantH: float = L * cos(pitch)
	var armH: float = maxf(0.0, minf(wantH, hit - rw * D.margin))
	var short: bool = armH < wantH - 0.01
	var arm3: float = armH / cos(pitch) if cos(pitch) > 0.05 else L
	var camH: float = arm3 * sin(pitch)
	b.zn = { "px": px, "py": py, "ph": ph, "L": L, "lx": lx, "ly": ly, "dx": dx, "dy": dy, "hit": hit,
		"wantH": wantH, "armH": armH, "short": short, "arm3": arm3, "camH": camH,
		"cx": px + dx * armH, "cy": py + dy * armH }

# ---- Wrap ---------------------------------------------------------------

## The torus, one modulo per axis (or a bounce on an axis that does not wrap).
static func _wr_wrap(b: Dictionary, body: Dictionary, r: float) -> void:
	var D: Dictionary = b.D
	var W: float = b.w
	var H: float = b.h
	if D.wrapX:
		var nx: float = fposmod(body.x, W)
		if nx != body.x:
			b.wraps += 1
			b.seamX = 1.0
		body.x = nx
	else:
		if body.x < r:
			body.x = r
			body.vx = absf(body.vx)
		if body.x > W - r:
			body.x = W - r
			body.vx = -absf(body.vx)
	if D.wrapY:
		var ny: float = fposmod(body.y, H)
		if ny != body.y:
			b.wraps += 1
			b.seamY = 1.0
		body.y = ny
	else:
		if body.y < r:
			body.y = r
			body.vy = absf(body.vy)
		if body.y > H - r:
			body.y = H - r
			body.vy = -absf(body.vy)

## The offsets a body is drawn at: (0, 0), and ±W / ±H near a seam.
static func _wr_offsets(b: Dictionary, x: float, y: float, r: float) -> Array:
	var D: Dictionary = b.D
	var W: float = b.w
	var H: float = b.h
	var oxs: Array = [0.0]
	var oys: Array = [0.0]
	if D.wrapX:
		if x < r:
			oxs.append(W)
		if x > W - r:
			oxs.append(-W)
	if D.wrapY:
		if y < r:
			oys.append(H)
		if y > H - r:
			oys.append(-H)
	var out: Array = []
	for ox in oxs:
		for oy in oys:
			out.append(Vector2(ox, oy))
	return out

# ==== the four entry points ==============================================

static func init(b: Dictionary) -> void:
	var D: Dictionary = b.D
	var W: float = b.w
	var H: float = b.h
	var GY: float = b.gy
	match b.id:
		"rewind":
			# Echo queued poses for its clones; a REWIND queues the whole state — x,
			# y, vx, vy — in a RING BUFFER: N slots, a head that wraps around, the
			# oldest slot silently overwritten. hold, and every frame the read cursor
			# walks back hz·dt slots and the mote is simply placed where that slot
			# says. let go, and the head moves back to the cursor: the future is
			# thrown away and the bounce resumes from the past. the purple ghost is
			# the same buffer read forward from its oldest slot — a REPLAY for free.
			var N: int = maxi(8, roundi(float(D.seconds) * float(D.hz)))
			b.N = N
			b.bx = _floats(N, 0.0)
			b.by = _floats(N, 0.0)
			b.bvx = _floats(N, 0.0)
			b.bvy = _floats(N, 0.0)
			b.x0 = W * 0.06
			b.x1 = W * 0.94
			b.y0 = H * 0.22
			b.y1 = H * 0.9
			b.pegs = [Vector2(W * 0.34, H * 0.52), Vector2(W * 0.66, H * 0.64), Vector2(W * 0.5, H * 0.38)]
			b.head = 0
			b.count = 0
			b.acc = 0.0
			b.cursor = 0.0
			b.holdT = 0.0
			b.autoT = 0.0
			b.ghost = 0.0
			b.rewinds = 0
			b.rewinding = false
			b.x = W * 0.3
			b.y = H * 0.32
			b.vx = W * 0.4
			b.vy = 0.0
		"xtrapolate":
			# Substep replayed the missed ticks; this is the other half of a FIXED
			# TIMESTEP: the screen draws whenever it likes, so what does it draw
			# between ticks? RAW draws the newest state, and stutters. INTERPOLATION
			# keeps the previous state too and blends them by α = acc/step — smooth,
			# but always one step behind. EXTRAPOLATION runs the newest state ahead
			# by acc with its velocity — smooth and on time, and it pokes through the
			# wall at every bounce. the trails are the last 24 draws: clumps, even
			# beads, and spikes. the counters: many frames, fewer steps.
			var cw: float = W / 3.0
			var trail: int = D.trail
			b.cw = cw
			b.C = []
			var names := ["raw", "interp", "extrap"]
			var cols := [Kit.MOVER, Kit.GOOD, Kit.MAGIC]
			for i in 3:
				b.C.append({ "name": names[i], "c": cols[i], "x0": i * cw,
					"tx": _floats(trail, 0.0), "ty": _floats(trail, 0.0), "ti": 0, "tn": 0 })
			b.v0 = sqrt(2.0 * D.g * H * H * D.apex)
			b.hi = 0
			b.acc = 0.0
			b.steps = 0
			b.frames = 0
			b.al = 0.0
			b.ax = cw * 0.2                              # state a: the previous tick
			b.ay = GY - 9.0
			b.avx = cw * D.speed
			b.avy = -b.v0
			b.bx = b.ax                                  # state b: the newest tick
			b.by = b.ay
			b.bvx = b.avx
			b.bvy = b.avy
		"initiative":
			# Quantize snapped the clock; this snaps TURNS. an ENERGY SCHEDULER, the
			# roguelike's initiative: every tick each actor's pool grows by its speed,
			# and whoever holds 100 acts and pays 100. speed 200 acts every tick,
			# speed 50 every fourth — "the fast monster acts twice" is arithmetic,
			# not a special case. when your pool is full the tick loop blocks until
			# you press: turn-based is just a scheduler that waits for one actor.
			var cols: int = D.cols
			var rows: int = D.rows
			b.cols = cols
			b.rows = rows
			b.cell = minf(W * 0.56 / cols, H * 0.7 / rows)
			b.gx0 = W * 0.04
			b.gy0 = H * 0.14
			var names := ["rat", "ogre", "bat"]
			var acol := [Kit.HOT, Kit.MAGIC, Kit.GOOD]
			b.actors = [{ "name": "you", "speed": float(D.player), "x": 1, "y": 2, "e": 0.0, "flash": 0.0, "c": Kit.MOVER }]
			var speeds: Array = D.speeds
			for i in speeds.size():
				b.actors.append({ "name": names[i % 3], "speed": float(speeds[i]), "x": cols - 2 - (i % 2), "y": (i * 2) % rows,
					"e": 0.0, "flash": 0.0, "c": acol[i % 3] })
			b.log = []
			b.tickT = 0.0
			b.ticks = 0
			b.waiting = false
			b.waitT = 0.0
			b.wantX = 0
			b.wantY = 0
			b.turns = 0
			b.bites = 0
		"kickdrum":
			# Invaders marched to a metronome; a BEAT CLOCK makes the metronome the
			# rule. one number, bpm, and the running clock give the current beat,
			# beat = t·bpm/60; its fractional part is the phase, and the kick lamp is
			# that phase made visible. an input is measured by Δ, its distance in
			# seconds to the nearest whole beat: inside the window it is a hop —
			# early or late, but a hop — outside it is a miss and the mote stumbles.
			# NecroDancer's whole rule. the kick sounds only once you have pressed.
			b.tw = W * 0.82 / D.tiles
			b.tx0 = W * 0.09
			b.lampX = W * 0.12
			b.lampY = H * 0.5
			b.marks = []
			b.tile = 0
			b.dir = 1
			b.hop = -1.0
			b.fromX = 0.0
			b.toX = 0.0
			b.lastBeat = -1
			b.kick = 0.0
			b.armed_sound = false                        # the kick sounds only after the first press
			b.userLast = -9.0
			b.now = 0.0
			b.nextAuto = 1.0
			b.judgeTxt = ""
			b.judgeT = 0.0
			b.judgeC = Kit.DIM
			b.hits = 0
			b.misses = 0
			b.stumble = 0.0
		"pause":
			# Timescale fed each column dt × scale; a PAUSE is scale = 0 — and the menu
			# that appears is the giveaway that one frame carries TWO CLOCKS. the
			# world clock advances by dt × scale: the ball hangs, the orbit stops,
			# the dust freezes mid-air. the UNSCALED clock advances by dt regardless:
			# the spinner turns, the "paused for" counter counts, the menu fades in.
			# every engine has both — Unity's unscaledDeltaTime, Godot's
			# process_always — and a frame counter that never notices the difference.
			b.puffs = []
			for _i in 12:
				b.puffs.append({ "x": 0.0, "y": 0.0, "vx": 0.0, "vy": 0.0, "life": 0.0 })
			b.paused = false
			b.phaseT = 0.0
			b.worldT = 0.0
			b.realT = 0.0
			b.pausedFor = 0.0
			b.menuK = 0.0
			b.spinA = 0.0
			b.frames = 0
			b.x = W * 0.3
			b.y = H * 0.3
			b.vx = W * 0.32
			b.vy = 0.0
		"cooldown":
			# Dash had one timer; a COOLDOWN MANAGER has a list of them — a name, a
			# length, a remaining time — all counted down by the same dt in one loop.
			# an ability asks "is mine at zero?": yes, act and reset the timer to its
			# length; no, refuse (the grey flash and a refused count, so the player
			# learns the rhythm). the bars ARE the timers: full at the moment of use,
			# draining to empty, a lamp when ready. a heal that takes five seconds
			# and a shot that takes a sixth share the same three lines of code.
			b.T = [{ "name": "dash", "cd": float(D.dash), "c": Kit.MOVER },
				{ "name": "shot", "cd": float(D.shot), "c": Kit.HOT },
				{ "name": "heal", "cd": float(D.heal), "c": Kit.GOOD }]
			for a in b.T:
				a.t = 0.0
				a.uses = 0
				a.refused = 0
				a.flash = 0.0
				a.glow = 0.0
			b.bullets = []
			for _i in 10:
				b.bullets.append({ "x": 0.0, "y": 0.0, "vx": 0.0, "on": false })
			b.x = W * 0.4
			b.dir = 1
			b.dashT = 0.0
			b.tryT = 0.0
			b.hp = 0.6
			b.healR = 0.0
			b.bi = 0
			b.streakX = 0.0
			b.streakK = 0.0
		"xtents":
			# Camera followed one mote; MULTI-TARGET FRAMING follows a GROUP. every
			# frame: the bounding box of all the fighters, grown by a padding; the
			# camera centre is the box's centre, and the zoom is whatever makes the
			# box fit the screen — the smaller of W / box width and H / box height —
			# clamped so it never zooms in past max nor out past min (the blast zones
			# live out there). centre and zoom both chase their targets with Camera's
			# ζ = 1 spring. drawing is one transform: translate, scale, translate.
			var AW: float = W * D.world
			b.AW = AW
			var sr := Kit.rng(3)
			b.posts = []
			for _i in 9:
				b.posts.append({ "x": sr.randf() * AW, "h": 10.0 + sr.randf() * H * 0.12 })
			var fcol := [Kit.MOVER, Kit.HOT, Kit.GOOD, Kit.MAGIC]
			b.F = []
			for i in 4:
				b.F.append({ "c": fcol[i], "x": AW / 2.0 + (i - 1.5) * W * 0.18, "tx": 0.0, "hop": i * 0.7, "moving": false, "y": GY - 9.0 })
			b.gather = true
			b.phaseT = 0.0
			b.cx = AW / 2.0
			b.cvx = 0.0
			b.cy = GY - H * 0.05
			b.cvy = 0.0
			b.z = 1.0
			b.zv = 0.0
			b.zt = 1.0
			b.box = { "x0": 0.0, "x1": W, "y0": 0.0, "y1": H }
			_xe_pick(b)
		"pan":
			# Camera's world was one long strip; here the level is a grid of ROOMS,
			# each exactly one screen, and the camera has BOUNDS: it may never show
			# past the level's edge, so its position is a clamp. in rooms mode the
			# camera sits on a room corner and, when the mote crosses a doorway, TWEENS
			# one whole screen to the next corner (the mote frozen, Zelda-style) — the
			# count of flips is the count of rooms visited. in scroll mode it follows
			# the mote with a lag and the clamp alone stops it at the walls.
			var N: int = D.rooms
			b.N = N
			b.LW = W * N
			b.LH = H * N
			var sr := Kit.rng(5)
			b.stuff = []
			for r in N * N:
				for _i in 4:
					b.stuff.append({ "x": (r % N) * W + W * (0.12 + sr.randf() * 0.76), "y": floori(r / float(N)) * H + H * (0.14 + sr.randf() * 0.7),
						"w": 8.0 + sr.randf() * W * 0.06, "h": 8.0 + sr.randf() * H * 0.06 })
			b.path = []
			b.mx = W * 0.5
			b.my = H * 0.5
			b.goal = Vector2(b.mx, b.my)
			b.camx = 0.0
			b.camy = 0.0
			b.fx = 0.0
			b.fy = 0.0
			b.tox = 0.0
			b.toy = 0.0
			b.tween = -1.0
			b.idleT = 0.0
			b.flips = 0
			b.rx = 0
			b.ry = 0
		"nudge":
			# chapter 6's screen shake is NOISE scaled by trauma²: random, directionless,
			# and it says "rumble". a CAMERA KICK is the opposite: one DIRECTIONAL
			# displacement — straight back along the recoil line, the exact opposite
			# of the shot — and Damp's spring returns it, with a little overshoot if ζ
			# is under 1. it says "punch". the two panels get the same shots; the
			# traces underneath are the camera offsets: one clean spike per shot on
			# the left, a decaying scribble on the right.
			var pw: float = W / 2.0
			b.pw = pw
			b.hist = [_floats(NUDGE_HIST, 0.0), _floats(NUDGE_HIST, 0.0)]
			b.P = [{ "name": "kick", "x": 0.0, "y": 0.0, "vx": 0.0, "vy": 0.0 }, { "name": "shake", "x": 0.0, "y": 0.0, "trauma": 0.0 }]
			b.B = [{ "x": 0.0, "y": 0.0, "vx": 0.0, "vy": 0.0, "life": 0.0 }, { "x": 0.0, "y": 0.0, "vx": 0.0, "vy": 0.0, "life": 0.0 }]
			b.gun = Vector2(pw * 0.3, GY - 9.0)
			b.aim = Vector2(pw * 0.75, H * 0.35)
			b.fireT = 0.0
			b.hi = 0
			b.shots = 0
		"zoompunch":
			# Camera moved the window; a ZOOM scales it, and the only question is
			# ABOUT WHAT POINT. scaling about the focus f — translate to f, scale by
			# z, translate back — leaves f exactly where it was and pulls everything
			# else toward it: p' = f + (p − f)·z. a ZOOM PUNCH sets f at the impact,
			# bumps z by a little and lets a wobbly spring bring it home in a quarter
			# of a second. the DEATH DOLLY is the same transform with an ease instead
			# of a spring: seconds long, about the loser. the strip is z over time.
			b.F = [{ "x": W * 0.36, "c": Kit.MOVER, "dir": 1.0, "lunge": -1.0, "recoil": 0.0, "down": 0.0 },
				{ "x": W * 0.64, "c": Kit.HOT, "dir": -1.0, "lunge": -1.0, "recoil": 0.0, "down": 0.0 }]
			b.zh = _floats(ZOOM_HIST, 1.0)
			b.z = 1.0
			b.zv = 0.0
			b.fx = W / 2.0
			b.fy = GY - 12.0
			b.att = 0
			b.hitT = 0.0
			b.spark = 0.0
			b.sx = 0.0
			b.sy = 0.0
			b.hits = 0
			b.zi = 0
			b.dolly = -1.0
			b.loser = 1
			b.dollyFrom = 1.0
		"tracking":
			# a CUTSCENE CAMERA is three curves evaluated at one parameter u. its
			# position rides Bezier's cubic, B(u); its heading is Lookat's atan2 to
			# the target, whatever the rail does; its FIELD OF VIEW is a list of
			# KEYFRAMES lerped by u — wide at the ends, tight in the middle. the
			# wedge on the map is the frustum, and the inset renders what falls
			# inside it: anything within ±fov/2 of the look direction, placed by
			# tan(angle)/tan(fov/2) and sized by 1/distance.
			var sr := Kit.rng(9)
			b.posts = []
			for _i in 7:
				b.posts.append({ "x": W * (0.25 + sr.randf() * 0.5), "y": H * (0.28 + sr.randf() * 0.5), "h": 0.5 + sr.randf() })
			b.ix = W * 0.6
			b.iy = H * 0.05
			b.iw = W * 0.36
			b.ih = H * 0.3
			b.tp = Vector2(W * 0.5, H * 0.55)
			b.goal = b.tp
			b.wanderT = 0.0
		"zenith":
			# Camera in 2D followed; the THIRD-PERSON ORBIT CAMERA hangs behind the
			# mote on a SPRING ARM: two angles, yaw around it and pitch above the
			# floor, and a length. pitch is clamped short of the zenith — straight up
			# the yaw would become meaningless, the classic gimbal problem. the arm is
			# Xmarks' ray, cast backward from the mote: if it hits a wall before its
			# full length, the camera moves in to the hit (minus a margin), so the
			# wall never comes between them. the inset is what that camera sees.
			b.rx0 = W * 0.04                             # the room, top-down
			b.ry0 = H * 0.12
			b.rw = W * 0.54
			b.rh = H * 0.76
			b.ix = W * 0.62                              # the inset
			b.iy = H * 0.06
			b.iw = W * 0.34
			b.ih = H * 0.4
			var sr := Kit.rng(13)
			b.posts = []
			for _i in 4:
				b.posts.append({ "x": b.rx0 + b.rw * (0.15 + sr.randf() * 0.7), "y": b.ry0 + b.rh * (0.15 + sr.randf() * 0.7) })
			b.yaw = 0.6
			b.pitch = 0.6
			b.userT = -9.0
			_zn_update(b, 0.0)
		"wrap":
			# Asteroids' world is a TORUS: leave the right edge and you enter the
			# left, one modulo per axis — ((x mod W) + W) mod W keeps a negative x
			# honest. the catch is the SEAM: a sprite half over the edge would blink
			# out and back in, so anything within its radius of an edge is drawn
			# TWICE, once at x and once at x ± W (four times in a corner). the purple
			# rings mark the copies. the rhyme keeps only the horizontal wrap and
			# bounces the vertical one: a cylinder instead of a doughnut.
			var sr := Kit.rng(21)
			var na: int = D.asteroids
			b.rocks = []
			for _i in na:
				var r: float = 9.0 + sr.randf() * 10.0
				var pts: Array = []
				for _k in 8:
					pts.append(0.7 + sr.randf() * 0.5)
				b.rocks.append({ "x": sr.randf() * W, "y": sr.randf() * H, "vx": (sr.randf() - 0.5) * W * 0.16, "vy": (sr.randf() - 0.5) * H * 0.16,
					"r": r, "a": 0.0, "w": (sr.randf() - 0.5) * 1.6, "pts": pts })
			b.ship = { "x": W * 0.5, "y": H * 0.5, "vx": W * 0.15, "vy": 0.0 }
			b.ang = 0.0
			b.burst = 0.0
			b.aim = Vector2(W * 0.8, H * 0.3)
			b.autoT = 0.0
			b.wraps = 0
			b.copies = 0
			b.seamX = 0.0
			b.seamY = 0.0
			b.ad = 0.0

static func press(b: Dictionary, pos: Vector2) -> void:
	var D: Dictionary = b.D
	var W: float = b.w
	var H: float = b.h
	match b.id:
		"rewind":
			b.holdT = 0.12
		"xtrapolate":
			b.hi = (b.hi + 1) % (D.hzList as Array).size()
		"initiative":
			var p: Dictionary = b.actors[0]
			var dx: float = pos.x - _in_cx(b, p)
			var dy: float = pos.y - _in_cy(b, p)
			if absf(dx) >= absf(dy):
				b.wantX = -1 if dx < 0.0 else 1
				b.wantY = 0
			else:
				b.wantX = 0
				b.wantY = -1 if dy < 0.0 else 1
			if b.waiting:
				_in_player_go(b)
		"kickdrum":
			b.armed_sound = true
			b.userLast = b.now
			_kd_judge(b, b.now)
		"pause":
			b.paused = not b.paused
			b.phaseT = 0.0
			if b.paused:
				b.pausedFor = 0.0
		"cooldown":
			for k in 3:
				_cd_use(b, k)
		"xtents":
			b.gather = not b.gather
			_xe_pick(b)
			b.phaseT = 0.0
		"pan":
			_pan_route(b, clampf(b.camx + pos.x, 14.0, b.LW - 14.0), clampf(b.camy + pos.y, 14.0, b.LH - 14.0))
			b.idleT = 0.0
		"nudge":
			var pw: float = b.pw
			b.aim = Vector2(clampf(fmod(pos.x, pw), 10.0, pw - 10.0), clampf(pos.y, 10.0, b.gy - 4.0))
			_nd_fire(b)
			b.fireT = 0.0
		"zoompunch":
			var corner: bool = (pos.x < W * 0.2 or pos.x > W * 0.8) and (pos.y < H * 0.2 or pos.y > H * 0.8)
			if corner and b.dolly < 0.0:
				b.loser = 0 if pos.x < W / 2.0 else 1
				b.dolly = 0.0
				b.dollyFrom = b.z
			else:
				var att: int = b.att
				_zp_hit(b, att ^ 1)
		"tracking":
			b.goal = Vector2(clampf(pos.x, W * 0.1, W * 0.9), clampf(pos.y, H * 0.15, H * 0.85))
			b.wanderT = 0.0
		"zenith":
			b.yaw = pos.x / W * TAU - PI
			b.pitch = lerpf(D.pitchMin, D.pitchMax, clampf(pos.y / H, 0.0, 1.0))
			b.userT = 0.0
		"wrap":
			b.aim = pos
			b.burst = 0.5

static func tick(b: Dictionary, dt: float, t: float) -> void:
	var D: Dictionary = b.D
	var W: float = b.w
	var H: float = b.h
	var GY: float = b.gy
	match b.id:
		"rewind":
			var hz: float = D.hz
			var e: float = D.e
			var R := 8.0
			b.holdT -= dt
			b.autoT += dt
			if b.autoT > float(D.autoEvery) + float(D.autoLen):
				b.autoT = 0.0
			var count: int = b.count
			var rewinding: bool = (b.holdT > 0.0 or b.autoT > float(D.autoEvery)) and count > 1
			b.rewinding = rewinding
			var bx: Array = b.bx
			var by: Array = b.by
			var bvx: Array = b.bvx
			var bvy: Array = b.bvy
			if rewinding:
				b.cursor = minf(b.cursor + hz * dt, float(count - 1))   # the cursor walks back through the past
				var sl := _rw_slot(b, floori(b.cursor))
				b.x = bx[sl]
				b.y = by[sl]
				b.vx = bvx[sl]
				b.vy = bvy[sl]
			else:
				if b.cursor > 0.0:                           # let go: the future is discarded
					var k: int = floori(b.cursor)
					b.head = _rw_slot(b, k)
					b.count -= k
					count = b.count
					b.cursor = 0.0
					b.rewinds += 1
				var x: float = b.x
				var y: float = b.y
				var vx: float = b.vx
				var vy: float = b.vy
				vy += H * D.g * dt                           # the chaotic bounce, three pegs
				x += vx * dt
				y += vy * dt
				var x0: float = b.x0
				var x1: float = b.x1
				var y0: float = b.y0
				var y1: float = b.y1
				if x < x0 + R:
					x = x0 + R
					vx = absf(vx) * e
				if x > x1 - R:
					x = x1 - R
					vx = -absf(vx) * e
				if y < y0 + R:
					y = y0 + R
					vy = absf(vy) * e
				if y > y1 - R:
					y = y1 - R
					vy = -maxf(absf(vy) * e, H * 0.95)       # the floor is a trampoline
				if absf(vx) < W * 0.15:                      # never let it settle
					vx = (-1.0 if vx < 0.0 else 1.0) * W * 0.4
				for p in b.pegs:
					var pv: Vector2 = p
					var dx := x - pv.x
					var dy := y - pv.y
					var d := sqrt(dx * dx + dy * dy)
					if d < R + 6.0 and d > 0.001:
						var nx := dx / d
						var ny := dy / d
						var vn := vx * nx + vy * ny
						if vn < 0.0:
							vx -= (1.0 + e) * vn * nx
							vy -= (1.0 + e) * vn * ny
						x = pv.x + nx * (R + 6.0)
						y = pv.y + ny * (R + 6.0)
				b.x = x
				b.y = y
				b.vx = vx
				b.vy = vy
				var N: int = b.N
				b.acc = minf(b.acc + dt, 0.5)
				while b.acc >= 1.0 / hz:                     # a snapshot every 1/hz seconds
					b.acc -= 1.0 / hz
					b.head = (b.head + 1) % N
					b.count = mini(N, b.count + 1)
					var hd: int = b.head
					bx[hd] = x
					by[hd] = y
					bvx[hd] = vx
					bvy[hd] = vy
				count = b.count
			var kept: int = count - floori(b.cursor)         # the slots the ghost may replay
			b.ghost += hz * dt
			if kept < 2 or b.ghost >= float(kept):
				b.ghost = 0.0
		"xtrapolate":
			var hzList: Array = D.hzList
			var trail: int = D.trail
			var hz: float = float(hzList[b.hi])
			var step := 1.0 / hz
			b.acc += dt
			var nn := 0
			while b.acc >= step and nn < 16:
				_xt_tick(b, step)
				b.acc -= step
				b.steps += 1
				nn += 1
			if nn >= 16:
				b.acc = 0.0                                  # the spiral-of-death guard
			var acc: float = b.acc
			var al: float = acc / step                       # α: how far into the next step we are
			b.al = al
			b.frames += 1
			for i in 3:
				var c: Dictionary = b.C[i]
				var p := _xt_pos(b, i, al, acc)
				var tx: Array = c.tx
				var ty: Array = c.ty
				var ti: int = c.ti
				tx[ti] = p.x
				ty[ti] = p.y
				c.ti = (ti + 1) % trail
				c.tn = mini(trail, c.tn + 1)
		"initiative":
			for a in b.actors:
				a.flash = maxf(0.0, a.flash - dt * 3.0)
			if b.waiting:
				b.waitT += dt
				if b.waitT > float(D.autoWait):
					_in_player_go(b)
			else:
				b.tickT += dt
				if b.tickT >= float(D.tickEvery):
					b.tickT = 0.0
					_in_tick(b)
		"kickdrum":
			var bpm: float = D.bpm
			var window: float = D.window
			b.now = t
			var period := 60.0 / bpm
			var beat := t * bpm / 60.0
			var bi := floori(beat)
			if bi != b.lastBeat:                             # a new beat: the kick
				if b.armed_sound:
					Kit.beep(float(D.kickHz), 0.1, "sine")   # once per beat, and only after a press
				b.lastBeat = bi
				b.kick = 1.0
			b.kick = maxf(0.0, b.kick - dt * 5.0)
			if t - b.userLast > 2.0 * period:                # the autopilot presses near the beat, with human error
				if t > b.nextAuto + period:
					b.nextAuto = (bi + 1) * period + randf_range(-1.0, 1.0) * window * 1.4
				if t >= b.nextAuto:
					_kd_judge(b, t)
					b.nextAuto = (bi + 1) * period + randf_range(-1.0, 1.0) * window * 1.4
			b.judgeT = maxf(0.0, b.judgeT - dt)
			b.stumble = maxf(0.0, b.stumble - dt)
			var marks: Array = b.marks
			for m in marks:
				m.age += dt
			while marks.size() > 0 and marks[0].age > 2.5:
				marks.pop_front()
			if b.hop >= 0.0:
				b.hop += dt / float(D.hopT)
				if b.hop >= 1.0:
					b.hop = -1.0
		"pause":
			var scale: float = D.scale
			var g: float = D.g
			b.frames += 1
			b.phaseT += dt
			if not b.paused and b.phaseT > float(D.every):
				b.paused = true
				b.phaseT = 0.0
				b.pausedFor = 0.0
			if b.paused and b.phaseT > float(D.pauseFor):
				b.paused = false
				b.phaseT = 0.0
			var paused: bool = b.paused
			var wdt: float = dt * scale if paused else dt    # ← the world's clock
			b.realT += dt                                    # ← the menu's clock
			b.worldT += wdt
			if paused:
				b.pausedFor += dt
			var x: float = b.x
			var y: float = b.y
			var vx: float = b.vx
			var vy: float = b.vy
			vy += H * g * wdt                                # the world, fed wdt only
			x += vx * wdt
			y += vy * wdt
			if x < 9.0:
				x = 9.0
				vx = absf(vx)
			if x > W - 9.0:
				x = W - 9.0
				vx = -absf(vx)
			var puffs: Array = b.puffs
			if y > GY - 9.0:
				y = GY - 9.0
				vy = -sqrt(2.0 * g * H * H * 0.4)
				var frames: int = b.frames
				for i in 4:
					var p: Dictionary = puffs[(frames + i) % puffs.size()]
					p.x = x
					p.y = GY - 2.0
					p.vx = (i - 1.5) * W * 0.12
					p.vy = -H * 0.15
					p.life = 1.0
			b.x = x
			b.y = y
			b.vx = vx
			b.vy = vy
			for p in puffs:
				if p.life > 0.0:
					p.life -= wdt * 1.4
					p.x += p.vx * wdt
					p.y += p.vy * wdt
			b.menuK += ((1.0 if paused else 0.0) - b.menuK) * Kit.smooth(10.0, dt)   # the menu animates on the real clock
			b.spinA += float(D.spin) * dt
		"cooldown":
			for a in b.T:                                    # one loop counts them all
				a.t = maxf(0.0, a.t - dt)
				a.flash = maxf(0.0, a.flash - dt)
				a.glow = maxf(0.0, a.glow - dt)
			b.tryT += dt
			if b.tryT > float(D.tryEvery):
				b.tryT = 0.0
				_cd_use(b, randi_range(0, 2))
			var dir: int = b.dir
			if b.dashT > 0.0:
				b.dashT -= dt
				b.x += dir * W * float(D.dashLen) / 0.15 * dt
			if b.x > W * 0.8:
				b.x = W * 0.8
				b.dir = -1
			if b.x < W * 0.2:
				b.x = W * 0.2
				b.dir = 1
			b.hp = maxf(0.05, b.hp - dt * 0.04)
			b.healR = maxf(0.0, b.healR - dt * 1.5)
			b.streakK = maxf(0.0, b.streakK - dt * 3.0)
			for bl in b.bullets:
				if bl.on:
					bl.x += bl.vx * dt
					if bl.x < -10.0 or bl.x > W + 10.0:
						bl.on = false
		"xtents":
			b.phaseT += dt
			if b.phaseT > float(D.phase):
				b.phaseT = 0.0
				b.gather = not b.gather
				_xe_pick(b)
			var x0 := 1.0e9
			var x1 := -1.0e9
			var y0 := 1.0e9
			var y1 := -1.0e9
			var v := W * 0.35
			for f in b.F:
				var d: float = f.tx - f.x
				var moving: bool = absf(d) > 3.0
				f.moving = moving
				if moving:
					f.x += clampf(d, -v * dt, v * dt)
					f.hop += dt * 9.0
				f.y = GY - 9.0 - (absf(sin(f.hop)) * H * 0.07 if moving else 0.0)
				x0 = minf(x0, f.x - 9.0)
				x1 = maxf(x1, f.x + 9.0)
				y0 = minf(y0, f.y - 9.0)
				y1 = maxf(y1, f.y + 9.0)
			var p: float = W * D.pad                         # the group box, then the framing rule
			var bw := x1 - x0
			var bh := y1 - y0
			var minZoom: float = D.minZoom
			var maxZoom: float = D.maxZoom
			var zt: float = clampf(minf(W / (bw + 2.0 * p), H / (bh + 2.0 * p)), minZoom, maxZoom)
			var gx := (x0 + x1) / 2.0
			var gy := (y0 + y1) / 2.0
			var w: float = D.omega
			b.cvx += (w * w * (gx - b.cx) - 2.0 * w * b.cvx) * dt   # ζ = 1: never overshoots
			b.cx += b.cvx * dt
			b.cvy += (w * w * (gy - b.cy) - 2.0 * w * b.cvy) * dt
			b.cy += b.cvy * dt
			b.zv += (w * w * (zt - b.z) - 2.0 * w * b.zv) * dt
			b.z += b.zv * dt
			b.z = clampf(b.z, minZoom * 0.5, maxZoom * 2.0)
			b.zt = zt
			b.box = { "x0": x0, "x1": x1, "y0": y0, "y1": y1 }
		"pan":
			var N: int = b.N
			var LW: float = b.LW
			var LH: float = b.LH
			var rooms: bool = D.mode == "rooms"
			var frozen: bool = rooms and b.tween >= 0.0
			var path: Array = b.path
			if not frozen and path.size() > 0:               # walk the route
				var p: Vector2 = path[0]
				var dx: float = p.x - b.mx
				var dy: float = p.y - b.my
				var d := sqrt(dx * dx + dy * dy)
				var step: float = W * D.speed * dt
				if d <= step or d < 0.5:
					b.mx = p.x
					b.my = p.y
					path.pop_front()
				else:
					b.mx += dx / d * step
					b.my += dy / d * step
			if path.is_empty():                              # idle: pick a random room and a point in it
				b.idleT += dt
				if b.idleT > 1.2:
					b.idleT = 0.0
					var r := randi_range(0, N * N - 1)
					_pan_route(b, (r % N) * W + randf_range(W * 0.15, W * 0.85), floori(r / float(N)) * H + randf_range(H * 0.15, H * 0.85))
			var room := _pan_room_of(b, b.mx, b.my)
			if rooms:
				if room.x != b.rx or room.y != b.ry:         # a doorway crossed: tween one screen
					b.rx = room.x
					b.ry = room.y
					b.fx = b.camx
					b.fy = b.camy
					b.tox = room.x * W
					b.toy = room.y * H
					b.tween = 0.0
					b.flips += 1
				if b.tween >= 0.0:
					b.tween += dt / float(D.slide)
					var k := _ease(minf(1.0, b.tween))
					b.camx = lerpf(b.fx, b.tox, k)
					b.camy = lerpf(b.fy, b.toy, k)
					if b.tween >= 1.0:
						b.tween = -1.0
			else:
				var k := Kit.smooth(float(D.lag), dt)        # a bounded smooth follow
				b.camx += (clampf(b.mx - W / 2.0, 0.0, LW - W) - b.camx) * k
				b.camy += (clampf(b.my - H / 2.0, 0.0, LH - H) - b.camy) * k
		"nudge":
			var pw: float = b.pw
			var omega: float = D.omega
			var zeta: float = D.zeta
			b.fireT += dt
			if b.fireT > float(D.every):
				b.fireT = 0.0
				b.aim = Vector2(randf_range(pw * 0.5, pw * 0.95), randf_range(H * 0.15, GY - 20.0))
				_nd_fire(b)
			var k: Dictionary = b.P[0]
			var nn := maxi(1, ceili(omega * dt / 0.35))      # the spring, in safe steps
			var h := dt / nn
			for _i in nn:
				k.vx += (-omega * omega * k.x - 2.0 * zeta * omega * k.vx) * h
				k.x += k.vx * h
				k.vy += (-omega * omega * k.y - 2.0 * zeta * omega * k.vy) * h
				k.y += k.vy * h
			var sh: Dictionary = b.P[1]
			sh.trauma = maxf(0.0, sh.trauma - dt * 0.9)
			var trauma: float = sh.trauma
			var amp: float = W * D.shakeAmp * trauma * trauma
			var freq: float = D.shakeFreq
			sh.x = Kit.noise(t * freq) * amp
			sh.y = Kit.noise(t * freq + 57.3) * amp
			for bl in b.B:
				if bl.life > 0.0:
					bl.life -= dt
					bl.x += bl.vx * dt
					bl.y += bl.vy * dt
			var hist: Array = b.hist
			var h0: Array = hist[0]
			var h1: Array = hist[1]
			var hi: int = b.hi
			h0[hi] = Vector2(k.x, k.y).length()
			h1[hi] = Vector2(sh.x, sh.y).length()
			b.hi = (hi + 1) % NUDGE_HIST
		"zoompunch":
			var omega: float = D.omega
			var zeta: float = D.zeta
			var punch: float = D.punch
			var dollyLen: float = D.dolly
			var F: Array = b.F
			b.hitT += dt
			if b.hitT > float(D.every) and b.dolly < 0.0:
				b.hitT = 0.0
				var att: int = b.att
				_zp_hit(b, att ^ 1)
			for i in 2:
				var a: Dictionary = F[i]
				var o: Dictionary = F[i ^ 1]
				if a.lunge >= 0.0:
					var was: float = a.lunge
					a.lunge += dt / 0.28
					if was < 0.5 and a.lunge >= 0.5:         # the moment of impact
						b.fx = (a.x + o.x) / 2.0
						b.fy = GY - 12.0
						b.sx = b.fx
						b.sy = b.fy
						b.spark = 1.0
						b.hits += 1
						b.z += punch                         # ← the punch: z bumped, the spring will bring it home
						o.recoil = 1.0
					if a.lunge >= 1.0:
						a.lunge = -1.0
				a.recoil = maxf(0.0, a.recoil - dt * 3.0)
			b.spark = maxf(0.0, b.spark - dt * 4.0)
			if b.dolly >= 0.0:                               # the death dolly: an ease, not a spring
				b.dolly += dt
				var k := _ease(minf(1.0, b.dolly / dollyLen))
				var L: Dictionary = F[b.loser]
				L.down = minf(1.0, L.down + dt * 3.0)
				b.fx = L.x
				b.fy = GY - 6.0
				b.z = lerpf(b.dollyFrom, float(D.dollyZoom), k)
				b.zv = 0.0
				if b.dolly > dollyLen + 0.8:
					b.dolly = -1.0
					L.down = 0.0
			else:
				var nn := maxi(1, ceili(omega * dt / 0.35))
				var h := dt / nn
				for _i in nn:
					b.zv += (omega * omega * (1.0 - b.z) - 2.0 * zeta * omega * b.zv) * h
					b.z += b.zv * h
				for f in F:
					f.down = maxf(0.0, f.down - dt * 2.0)
			b.z = maxf(0.3, b.z)
			var zh: Array = b.zh
			var zi: int = b.zi
			zh[zi] = b.z
			b.zi = (zi + 1) % ZOOM_HIST
		"tracking":
			b.wanderT += dt
			if b.wanderT > float(D.wander):
				b.wanderT = 0.0
				b.goal = Vector2(randf_range(W * 0.2, W * 0.8), randf_range(H * 0.3, H * 0.8))
			var tp: Vector2 = b.tp
			var goal: Vector2 = b.goal
			var dg := tp.distance_to(goal)
			var sp := W * 0.12 * dt
			if dg > sp:
				tp += (goal - tp) / dg * sp
			else:
				tp = goal
			b.tp = tp
		"zenith":
			var pitchMin: float = D.pitchMin
			var pitchMax: float = D.pitchMax
			b.userT += dt
			if b.userT > 2.5:
				b.yaw += float(D.yawSpeed) * dt
				b.pitch = lerpf(pitchMin, pitchMax, 0.5 + 0.4 * sin(t * 0.5))
			b.pitch = clampf(b.pitch, pitchMin, minf(pitchMax, 1.55))   # ← never the zenith
			_zn_update(b, t)
		"wrap":
			var thrust: float = D.thrust
			var dragK: float = D.drag
			var wrapX: bool = D.wrapX
			var wrapY: bool = D.wrapY
			b.autoT += dt
			if b.autoT > float(D.every):
				b.autoT = 0.0
				b.aim = Vector2(randf_range(0.0, W), randf_range(0.0, H))
				b.burst = 0.4
			b.seamX = maxf(0.0, b.seamX - dt * 2.0)
			b.seamY = maxf(0.0, b.seamY - dt * 2.0)
			var ship: Dictionary = b.ship
			var aim: Vector2 = b.aim
			var ax: float = aim.x - ship.x                   # the shortest way to the aim may cross a seam
			var ay: float = aim.y - ship.y
			if wrapX and absf(ax) > W / 2.0:
				ax -= signf(ax) * W
			if wrapY and absf(ay) > H / 2.0:
				ay -= signf(ay) * H
			var ad := sqrt(ax * ax + ay * ay)
			b.ad = ad
			if ad > 1.0:
				b.ang = atan2(ay, ax)
			var ang: float = b.ang
			if b.burst > 0.0 and ad > 8.0:
				b.burst -= dt
				ship.vx += cos(ang) * W * thrust * dt
				ship.vy += sin(ang) * W * thrust * dt
			var k := maxf(0.0, 1.0 - dragK * dt)
			ship.vx *= k
			ship.vy *= k
			var sp: float = Vector2(ship.vx, ship.vy).length()
			var cap := W * 0.6
			if sp > cap:
				ship.vx *= cap / sp
				ship.vy *= cap / sp
			ship.x += ship.vx * dt
			ship.y += ship.vy * dt
			_wr_wrap(b, ship, 9.0)
			var copies := 0
			for r in b.rocks:
				r.x += r.vx * dt
				r.y += r.vy * dt
				r.a += r.w * dt
				_wr_wrap(b, r, r.r)
				copies += _wr_offsets(b, r.x, r.y, r.r).size() - 1
			copies += _wr_offsets(b, ship.x, ship.y, 12.0).size() - 1
			b.copies = copies                                # the seam copies this frame will draw

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	Kit.stage(n, b)
	var D: Dictionary = b.D
	var W: float = b.w
	var H: float = b.h
	var GY: float = b.gy
	match b.id:
		"rewind":
			var N: int = b.N
			var count: int = b.count
			var cursor: float = b.cursor
			var rewinding: bool = b.rewinding
			var ghost: float = b.ghost
			var bx: Array = b.bx
			var by: Array = b.by
			var bvx: Array = b.bvx
			var bvy: Array = b.bvy
			var x0: float = b.x0
			var x1: float = b.x1
			var y0: float = b.y0
			var y1: float = b.y1
			var kept: int = count - floori(cursor)           # the slots the ghost may replay
			Kit.poly(n, [Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)], Color(Kit.BONE, 0.35), 1.0)
			for p in b.pegs:
				Kit.dot(n, p, 6.0, Kit.BONE)
			var stride: int = maxi(1, floori(count / 80.0))  # the buffer drawn as a trail —
			var k := 0                                       # the discarded future in red
			while k < count:
				var sl := _rw_slot(b, k)
				var a: float = 0.08 + 0.35 * (1.0 - float(k) / count)
				Kit.dot(n, Vector2(bx[sl], by[sl]), 1.5, Color(Kit.HOT, a) if k < cursor else Color(Kit.MOVER, a))
				k += stride
			var gk: int = kept - 1 - floori(ghost)
			if kept > 1:                                     # the replay ghost reads the buffer forward
				var sg := _rw_slot(b, gk)
				Kit.mote(n, b, Vector2(bx[sg], by[sg]), atan2(bvy[sg], bvx[sg]), Color(Kit.MAGIC, 0.45), 7.0)
			var vx: float = b.vx
			var vy: float = b.vy
			Kit.mote(n, b, Vector2(b.x, b.y), atan2(vy, vx), Kit.TARGET if rewinding else Kit.MOVER)
			var sx0 := W * 0.08                              # the scrubber: N slots, oldest left
			var sw := W * 0.84
			var sy := H * 0.08
			Kit.rect(n, Rect2(sx0, sy - 4.0, sw, 8.0), Color(Kit.INK, 0.08))
			Kit.rect(n, Rect2(sx0, sy - 4.0, sw * count / N, 8.0), Color(Kit.MOVER, 0.35))
			if cursor > 0.0:
				Kit.rect(n, Rect2(_rw_px(b, cursor), sy - 4.0, sw * (cursor + 1.0) / N, 8.0), Color(Kit.HOT, 0.5))
			if kept > 1:
				Kit.dot(n, Vector2(_rw_px(b, gk), sy), 3.0, Kit.MAGIC)
			var cxp := _rw_px(b, cursor)
			Kit.line(n, Vector2(cxp, sy - 7.0), Vector2(cxp, sy + 7.0), Kit.TARGET if rewinding else Kit.MOVER, 2.0)
			Kit.label(n, b, "N = %d · held %d%s · rewinds %d" % [N, count, " · ◀◀ rewinding" if rewinding else " · ● recording", b.rewinds], Vector2(W / 2.0, sy + 18.0), FAINT, true)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"xtrapolate":
			var cw: float = b.cw
			var hzList: Array = D.hzList
			var hz: float = float(hzList[b.hi])
			var trail: int = D.trail
			var al: float = b.al
			var acc: float = b.acc
			var bx: float = b.bx
			var by: float = b.by
			var bvx: float = b.bvx
			var bvy: float = b.bvy
			Kit.ground(n, b)
			for i in 3:
				var c: Dictionary = b.C[i]
				var x0: float = c.x0
				var col: Color = c.c
				var p := _xt_pos(b, i, al, acc)
				if i > 0:
					Kit.line(n, Vector2(x0, H * 0.06), Vector2(x0, GY), Kit.DIM, 1.0)
				Kit.line(n, Vector2(x0 + 9.0, H * 0.3), Vector2(x0 + 9.0, GY), Color(Kit.BONE, 0.25), 1.0)   # the walls it bounces off
				Kit.line(n, Vector2(x0 + cw - 9.0, H * 0.3), Vector2(x0 + cw - 9.0, GY), Color(Kit.BONE, 0.25), 1.0)
				var tx: Array = c.tx
				var ty: Array = c.ty
				var ti: int = c.ti
				var tn: int = c.tn
				for k in tn:                                 # the last draws, oldest faintest
					var j: int = (ti - 1 - k + 2 * trail) % trail
					Kit.dot(n, Vector2(x0 + tx[j], ty[j]), 2.0, Color(col, 0.55 * (1.0 - float(k) / tn)))
				if i > 0:
					Kit.ring(n, Vector2(x0 + bx, by), 7.0, Kit.DIM, 1.0)   # where the raw state is, for reference
				Kit.mote(n, b, Vector2(x0 + p.x, p.y), atan2(bvy, bvx), col, 7.0)
				Kit.label(n, b, c.name, Vector2(x0 + cw / 2.0, 14.0), FAINT, true)
				Kit.rect(n, Rect2(x0 + cw * 0.2, 19.0, cw * 0.6, 4.0), Color(Kit.INK, 0.1))   # α, as a bar
				Kit.rect(n, Rect2(x0 + cw * 0.2, 19.0, cw * 0.6 * al, 4.0), Kit.TARGET)
			Kit.label(n, b, "α %.2f" % al, Vector2(W / 2.0, 33.0), Color(Kit.TARGET, 0.8), true)
			Kit.label(n, b, "%s Hz · frames %d · steps %d" % [_num(hz), b.frames, b.steps], Vector2(W / 2.0, GY + 16.0), FAINT, true)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"initiative":
			var cols: int = b.cols
			var rows: int = b.rows
			var cell: float = b.cell
			var gx0: float = b.gx0
			var gy0: float = b.gy0
			var actors: Array = b.actors
			var cost: float = D.cost
			var grid := Color(Kit.BONE, 0.18)                # the grid
			for i in cols + 1:
				Kit.line(n, Vector2(gx0 + i * cell, gy0), Vector2(gx0 + i * cell, gy0 + rows * cell), grid, 1.0)
			for j in rows + 1:
				Kit.line(n, Vector2(gx0, gy0 + j * cell), Vector2(gx0 + cols * cell, gy0 + j * cell), grid, 1.0)
			var p: Dictionary = actors[0]
			for i in range(actors.size() - 1, -1, -1):
				var a: Dictionary = actors[i]
				var x := _in_cx(b, a)
				var y := _in_cy(b, a)
				var flash: float = a.flash
				var col: Color = a.c
				if flash > 0.0:
					Kit.ring(n, Vector2(x, y), cell * 0.45, Color(Kit.INK, flash * 0.8), 1.5)
				var ang: float = atan2(float(p.y - a.y), float(p.x - a.x)) if i > 0 else 0.0
				Kit.mote(n, b, Vector2(x, y), ang, col, cell * 0.28)
				Kit.rect(n, Rect2(x - cell * 0.4, y + cell * 0.36, cell * 0.8, 2.5), Color(Kit.INK, 0.12))   # the pool, in the grid too
				Kit.rect(n, Rect2(x - cell * 0.4, y + cell * 0.36, cell * 0.8 * clampf(a.e / cost, 0.0, 1.0), 2.5), col)
			var wantX: int = b.wantX
			var wantY: int = b.wantY
			if wantX != 0 or wantY != 0:
				var pc := Vector2(_in_cx(b, p), _in_cy(b, p))
				Kit.arrow(n, pc, pc + Vector2(wantX * cell * 0.8, wantY * cell * 0.8), Kit.TARGET)
			var px0 := W * 0.63                              # the panel: pools and the log
			var bx0 := W * 0.77
			var bw := W * 0.19
			var rowH := H * 0.075
			var waiting: bool = b.waiting
			for i in actors.size():
				var a: Dictionary = actors[i]
				var y := gy0 + i * rowH
				var col: Color = a.c
				Kit.label(n, b, "%s %s" % [a.name, _num(a.speed)], Vector2(px0, y + 4.0), col)
				Kit.rect(n, Rect2(bx0, y - 1.0, bw, 6.0), Color(Kit.INK, 0.1))
				Kit.rect(n, Rect2(bx0, y - 1.0, bw * clampf(a.e / cost, 0.0, 1.0), 6.0), col)
				if i == 0 and waiting:
					var k := 0.5 + 0.5 * sin(t * 8.0)
					Kit.rect(n, Rect2(bx0, y - 1.0, bw, 6.0), Color(Kit.TARGET, k * 0.7))
					_label_right(n, b, "your turn — press", Vector2(bx0 + bw, y + 14.0), Kit.TARGET)
			Kit.line(n, Vector2(bx0 + bw, gy0 - 4.0), Vector2(bx0 + bw, gy0 + actors.size() * rowH - 4.0), Kit.DIM, 1.0)
			_label_right(n, b, "cost %s" % _num(cost), Vector2(bx0 + bw, gy0 + actors.size() * rowH + 6.0), Kit.DIM)
			var ly := gy0 + actors.size() * rowH + 20.0
			var logs: Array = b.log
			for i in logs.size():
				Kit.label(n, b, logs[i], Vector2(px0, ly + i * 11.0), Color(Kit.INK, 0.85 - i * 0.15))
			Kit.label(n, b, "tick %d · turns %d · bites %d" % [b.ticks, b.turns, b.bites], Vector2(W / 2.0, 12.0), FAINT, true)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"kickdrum":
			var bpm: float = D.bpm
			var window: float = D.window
			var tiles: int = D.tiles
			var period := 60.0 / bpm
			var beat := t * bpm / 60.0
			var phase := beat - floorf(beat)
			var kick: float = b.kick
			var tile: int = b.tile
			var dir: int = b.dir
			var hop: float = b.hop
			var stumble: float = b.stumble
			var lamp := Vector2(b.lampX, b.lampY)
			var tw: float = b.tw
			Kit.ground(n, b)
			var hx := W * 0.5                                # the beat strip: beats slide toward the hit line
			var sy := H * 0.17
			var sp := W * 0.18
			Kit.line(n, Vector2(W * 0.1, sy), Vector2(W * 0.9, sy), Kit.DIM, 1.0)
			Kit.rect(n, Rect2(hx - window / period * sp, sy - 9.0, 2.0 * window / period * sp, 18.0), Color(Kit.GOOD, 0.18))
			Kit.line(n, Vector2(hx, sy - 11.0), Vector2(hx, sy + 11.0), Kit.TARGET, 2.0)
			for k in range(-2, 4):
				var x := hx + (k - phase) * sp
				if x > W * 0.1 and x < W * 0.9:
					Kit.line(n, Vector2(x, sy - 6.0), Vector2(x, sy + 6.0), Kit.BONE, 1.5)
			for m in b.marks:
				var md: float = m.d
				var age: float = m.age
				Kit.dot(n, Vector2(hx + md / period * sp, sy + 14.0), 2.5, Color(Kit.GOOD if absf(md) <= window else Kit.HOT, 1.0 - age / 2.5))
			Kit.label(n, b, "← early · late →", Vector2(hx, sy + 27.0), Kit.DIM, true)
			Kit.ring(n, lamp, 15.0, Kit.DIM, 1.0)            # the kick lamp and the phase hand
			Kit.dot(n, lamp, 5.0 + kick * 8.0, Kit.HOT)
			if phase > 0.001:
				n.draw_arc(lamp, 15.0, -TAU / 4.0, -TAU / 4.0 + phase * TAU, 32, Kit.TARGET, 2.0)
			Kit.label(n, b, "kick", lamp + Vector2(0.0, 28.0), Kit.DIM, true)
			for i in tiles:                                  # the floor
				var x := _kd_tile_x(b, i)
				Kit.rect(n, Rect2(x - tw * 0.46, GY - 3.0, tw * 0.92, 3.0), Color(Kit.MOVER, 0.6) if i == tile else Color(Kit.BONE, 0.18))
			var mx := _kd_tile_x(b, tile)
			var my := GY - 9.0 - kick * 2.0
			var ang: float = 0.0 if dir > 0 else PI
			if hop >= 0.0:
				var k := minf(1.0, hop)
				mx = lerpf(b.fromX, b.toX, k)
				my = GY - 9.0 - sin(k * PI) * H * 0.12
				ang = atan2(-cos(k * PI) * 2.0, float(dir))
			if stumble > 0.0:
				mx += sin(t * 60.0) * 3.0 * stumble
			Kit.mote(n, b, Vector2(mx, my), ang, Kit.HOT if stumble > 0.0 else Kit.MOVER)
			if b.judgeT > 0.0:
				Kit.label(n, b, b.judgeTxt, Vector2(W * 0.6, H * 0.5), b.judgeC, true)
			Kit.label(n, b, "bpm %s · beat %.2f · hits %d · misses %d" % [_num(bpm), beat, b.hits, b.misses], Vector2(W / 2.0, 12.0), FAINT, true)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"pause":
			var paused: bool = b.paused
			var worldT: float = b.worldT
			var realT: float = b.realT
			var menuK: float = b.menuK
			var spinA: float = b.spinA
			var scale: float = D.scale
			var vx: float = b.vx
			var vy: float = b.vy
			Kit.ground(n, b)
			var ox := W * 0.72                               # an orbit on the world clock
			var oy := H * 0.36
			Kit.ring(n, Vector2(ox, oy), H * 0.13, Kit.DIM, 1.0)
			Kit.dot(n, Vector2(ox, oy), 4.0, Kit.TARGET)
			var ocol := [Kit.GOOD, Kit.MAGIC, Kit.BONE]
			for i in 3:
				var a := worldT * 1.6 + i * TAU / 3.0
				Kit.dot(n, Vector2(ox + cos(a) * H * 0.13, oy + sin(a) * H * 0.13), 4.0, ocol[i])
			for p in b.puffs:
				var life: float = p.life
				if life > 0.0:
					Kit.dot(n, Vector2(p.x, p.y), 2.5, Color(Kit.INK, life * 0.5))
			Kit.mote(n, b, Vector2(b.x, b.y), atan2(vy, vx))
			_pz_clock(n, b, Vector2(W * 0.07, H * 0.1), worldT, Kit.HOT if paused else Kit.MOVER, "world")
			_pz_clock(n, b, Vector2(W * 0.55, H * 0.1), realT, Kit.BONE, "real")
			_label_right(n, b, "frame %d" % b.frames, Vector2(W - 6.0, H * 0.1 + 4.0), Kit.DIM)
			if menuK > 0.01:                                 # the menu, on the real clock
				Kit.rect(n, Rect2(0.0, H * 0.2, W, H * 0.5), Color(Kit.NIGHT, menuK * 0.55))
				var mx := W * 0.5
				var my := H * 0.45
				n.draw_arc(Vector2(mx, my), 14.0, spinA, spinA + TAU * 0.72, 32, Color(Kit.TARGET, menuK), 3.0)
				Kit.label(n, b, "PAUSED", Vector2(mx, my + 32.0), Color(Kit.INK, menuK), true)
				Kit.label(n, b, "for %.1f s (unscaled) · world dt × %s" % [b.pausedFor, _num(scale)], Vector2(mx, my + 45.0), Color(Kit.TARGET, menuK), true)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"cooldown":
			var x: float = b.x
			var dir: int = b.dir
			var dashT: float = b.dashT
			var hp: float = b.hp
			var healR: float = b.healR
			var streakK: float = b.streakK
			var streakX: float = b.streakX
			Kit.ground(n, b)
			var bx0 := W * 0.2                               # the timers, one bar each
			var bw := W * 0.46
			var T: Array = b.T
			for i in T.size():
				var a: Dictionary = T[i]
				var y := H * 0.1 + i * H * 0.12
				var col: Color = a.c
				var at: float = a.t
				var cd: float = a.cd
				var flash: float = a.flash
				var glow: float = a.glow
				Kit.label(n, b, a.name, Vector2(W * 0.05, y + 4.0), col)
				Kit.rect(n, Rect2(bx0, y - 1.0, bw, 7.0), Color(Kit.INK, 0.1))
				Kit.rect(n, Rect2(bx0, y - 1.0, bw * clampf(at / cd, 0.0, 1.0), 7.0), col)
				if flash > 0.0:
					Kit.rect(n, Rect2(bx0, y - 1.0, bw, 7.0), Color(0.627, 0.627, 0.667, flash * 1.5))
					Kit.label(n, b, "✗ refused", Vector2(bx0 + bw / 2.0, y + 4.0), Kit.HOT, true)
				if at <= 0.0:
					Kit.dot(n, Vector2(bx0 + bw + 8.0, y + 2.5), 3.5, Kit.GOOD)
					Kit.label(n, b, "ready", Vector2(bx0 + bw + 15.0, y + 6.0), Kit.GOOD)
				else:
					Kit.label(n, b, "%.2f s" % at, Vector2(bx0 + bw + 6.0, y + 6.0), col)
				_label_right(n, b, "%d · %d" % [a.uses, a.refused], Vector2(W * 0.97, y + 6.0), Kit.DIM)
				if glow > 0.0:
					Kit.ring(n, Vector2(bx0 + bw * 0.5, y + 2.5), bw * 0.5 + 4.0, Color(Kit.INK, glow), 1.0)
			_label_right(n, b, "used · refused", Vector2(W * 0.97, H * 0.1 - 10.0), Kit.DIM)
			if streakK > 0.0:
				Kit.line(n, Vector2(streakX, GY - 9.0), Vector2(x, GY - 9.0), Color(Kit.MOVER, streakK * 0.7), 5.0)
			for bl in b.bullets:
				if bl.on:
					Kit.dot(n, Vector2(bl.x, bl.y), 2.5, Kit.HOT)
			if healR > 0.0:
				Kit.ring(n, Vector2(x, GY - 9.0), (1.0 - healR) * 26.0 + 8.0, Color(Kit.GOOD, healR), 2.0)
			Kit.rect(n, Rect2(x - 12.0, GY - 26.0, 24.0, 3.0), Color(Kit.INK, 0.12))
			Kit.rect(n, Rect2(x - 12.0, GY - 26.0, 24.0 * hp, 3.0), Kit.GOOD)
			Kit.mote(n, b, Vector2(x, GY - 9.0), 0.0 if dir > 0 else PI, DASH_INK if dashT > 0.0 else Kit.MOVER)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"xtents":
			var AW: float = b.AW
			var z: float = b.z
			var zt: float = b.zt
			var cx: float = b.cx
			var box: Dictionary = b.box
			var x0: float = box.x0
			var x1: float = box.x1
			var y0: float = box.y0
			var y1: float = box.y1
			var p: float = W * D.pad
			var gather: bool = b.gather
			# ← the camera: the web's translate · scale · translate is _xe_scr, applied
			# point by point (the kit's mote resets the draw transform, so no draw_set_transform).
			var g0 := _xe_scr(b, Vector2(0.0, GY))
			var g1 := _xe_scr(b, Vector2(AW, GY + H * 0.12))
			Kit.rect(n, Rect2(g0, g1 - g0), Color(Kit.BONE, 0.14))
			Kit.line(n, g0, _xe_scr(b, Vector2(AW, GY)), Color(Kit.BONE, 0.5), 1.5 * z)
			for q in b.posts:
				var qx: float = q.x
				var qh: float = q.h
				var a0 := _xe_scr(b, Vector2(qx - 3.0, GY - qh))
				var a1 := _xe_scr(b, Vector2(qx + 3.0, GY))
				Kit.rect(n, Rect2(a0, a1 - a0), Kit.BONE)
			for f in b.F:
				var fx: float = f.x
				var fy: float = f.y
				var ftx: float = f.tx
				Kit.dot(n, _xe_scr(b, Vector2(fx, GY - 2.0)), 6.0 * z, Color(0.0, 0.0, 0.0, 0.35))
				Kit.mote(n, b, _xe_scr(b, Vector2(fx, fy)), PI if ftx < fx else 0.0, f.c, 8.0 * z)
			Kit.poly(n, [_xe_scr(b, Vector2(x0, y0)), _xe_scr(b, Vector2(x1, y0)), _xe_scr(b, Vector2(x1, y1)), _xe_scr(b, Vector2(x0, y1))], Color(Kit.TARGET, 0.7), 1.0)
			_dashed_poly(n, [_xe_scr(b, Vector2(x0 - p, y0 - p)), _xe_scr(b, Vector2(x1 + p, y0 - p)), _xe_scr(b, Vector2(x1 + p, y1 + p)), _xe_scr(b, Vector2(x0 - p, y1 + p))], Color(Kit.TARGET, 0.35), 1.0, 3.0)
			var bw := x1 - x0
			var bh := y1 - y0
			var gx := (x0 + x1) / 2.0
			var lp := Vector2(clampf(_xe_scr(b, Vector2(gx, 0.0)).x, 40.0, W - 40.0), clampf(_xe_scr(b, Vector2(0.0, y0 - p)).y - 6.0, 30.0, H - 20.0))
			Kit.label(n, b, "box %d × %d + pad %d" % [roundi(bw), roundi(bh), roundi(p)], lp, Color(Kit.TARGET, 0.8), true)
			var mw := W * 0.8                                # the minimap: the arena and the window
			var mx0 := W * 0.1
			var my := 12.0
			Kit.line(n, Vector2(mx0, my), Vector2(mx0 + mw, my), Kit.DIM, 1.0)
			var wl := mx0 + (cx - W / 2.0 / z) / AW * mw
			var ww := W / z / AW * mw
			Kit.poly(n, [Vector2(wl, my - 5.0), Vector2(wl + ww, my - 5.0), Vector2(wl + ww, my + 5.0), Vector2(wl, my + 5.0)], Color(Kit.INK, 0.5), 1.0)
			for f in b.F:
				Kit.dot(n, Vector2(mx0 + f.x / AW * mw, my), 2.5, f.c)
			Kit.label(n, b, "zoom %.2f → %.2f · min %s · max %s · %s" % [z, zt, _num(D.minZoom), _num(D.maxZoom), "gather" if gather else "scatter"], Vector2(W / 2.0, 28.0), FAINT, true)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"pan":
			var N: int = b.N
			var LW: float = b.LW
			var LH: float = b.LH
			var camx: float = b.camx
			var camy: float = b.camy
			var mx: float = b.mx
			var my: float = b.my
			var tween: float = b.tween
			var rooms: bool = D.mode == "rooms"
			var frozen: bool = rooms and tween >= 0.0
			var cam := Vector2(camx, camy)                   # ← the camera: the level is drawn at p − cam (the card's Control clips it)
			for r in N * N:
				var rx: int = r % N
				var ryy: int = floori(r / float(N))
				Kit.rect(n, Rect2(Vector2(rx * W, ryy * H) - cam, Vector2(W, H)), Color(Kit.MOVER, 0.04) if r % 2 == ryy % 2 else Color(Kit.TARGET, 0.04))
			for st in b.stuff:
				Kit.rect(n, Rect2(Vector2(st.x, st.y) - cam, Vector2(st.w, st.h)), Color(Kit.BONE, 0.22))
			for k in range(1, N):                            # the seams, with doorways
				for j in N:
					Kit.line(n, Vector2(k * W, j * H) - cam, Vector2(k * W, (j + 0.5) * H - H * 0.1) - cam, Kit.BONE, 3.0)
					Kit.line(n, Vector2(k * W, (j + 0.5) * H + H * 0.1) - cam, Vector2(k * W, (j + 1) * H) - cam, Kit.BONE, 3.0)
					Kit.line(n, Vector2(j * W, k * H) - cam, Vector2((j + 0.5) * W - W * 0.1, k * H) - cam, Kit.BONE, 3.0)
					Kit.line(n, Vector2((j + 0.5) * W + W * 0.1, k * H) - cam, Vector2((j + 1) * W, k * H) - cam, Kit.BONE, 3.0)
			Kit.poly(n, [Vector2(1.5, 1.5) - cam, Vector2(LW - 1.5, 1.5) - cam, Vector2(LW - 1.5, LH - 1.5) - cam, Vector2(1.5, LH - 1.5) - cam], Kit.BONE, 3.0)
			var goal: Vector2 = b.goal
			Kit.ring(n, goal - cam, 5.0, Kit.TARGET, 1.5)
			var path: Array = b.path
			for i in range(0, path.size() - 1):
				var pa: Vector2 = path[i]
				var pb: Vector2 = path[i + 1]
				Kit.line(n, pa - cam, pb - cam, Color(Kit.TARGET, 0.3), 1.0)
			var hd := 0.0
			if path.size() > 0:
				var p0: Vector2 = path[0]
				hd = atan2(p0.y - my, p0.x - mx)
			Kit.mote(n, b, Vector2(mx, my) - cam, hd, Kit.BONE if frozen else Kit.MOVER)
			var ms := W * 0.09                               # the minimap: rooms, window, mote
			var mx0 := W - 8.0 - ms * N
			var my0 := 8.0
			for r in N * N:
				var rx := float(r % N)
				var ryy := float(floori(r / float(N)))
				Kit.poly(n, [Vector2(mx0 + rx * ms, my0 + ryy * ms), Vector2(mx0 + (rx + 1.0) * ms, my0 + ryy * ms),
					Vector2(mx0 + (rx + 1.0) * ms, my0 + (ryy + 1.0) * ms), Vector2(mx0 + rx * ms, my0 + (ryy + 1.0) * ms)], Kit.DIM, 1.0)
			var ks := ms * N
			Kit.poly(n, [Vector2(mx0 + camx / LW * ks, my0 + camy / LH * ks), Vector2(mx0 + (camx + W) / LW * ks, my0 + camy / LH * ks),
				Vector2(mx0 + (camx + W) / LW * ks, my0 + (camy + H) / LH * ks), Vector2(mx0 + camx / LW * ks, my0 + (camy + H) / LH * ks)], Kit.TARGET, 1.5)
			Kit.dot(n, Vector2(mx0 + mx / LW * ks, my0 + my / LH * ks), 2.0, Kit.MOVER)
			var txt: String
			if rooms:
				txt = "room (%d, %d) · flips %d%s" % [b.rx, b.ry, b.flips, (" · sliding %.2f s" % (tween * float(D.slide))) if tween >= 0.0 else ""]
			else:
				txt = "cam (%d, %d) in 0..%d × 0..%d" % [roundi(camx), roundi(camy), roundi(LW - W), roundi(LH - H)]
			Kit.label(n, b, txt, Vector2(8.0, 14.0))
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"nudge":
			var pw: float = b.pw
			var P: Array = b.P
			var B: Array = b.B
			var hist: Array = b.hist
			var hi: int = b.hi
			var gun: Vector2 = b.gun
			var aim: Vector2 = b.aim
			var kick: float = D.kick
			var ang := atan2(aim.y - gun.y, aim.x - gun.x)
			for i in 2:
				var p: Dictionary = P[i]
				var x0 := i * pw
				var off := Vector2(x0 + p.x, p.y)           # ← the camera offset moves the whole scene
				# the web clips each panel to its half: here the ground line is cut to the
				# panel and the posts are intersected with it (the mote and ring may bleed a pixel)
				var panel := Rect2(x0, 0.0, pw, H)
				Kit.line(n, Vector2(x0, GY + off.y), Vector2(x0 + pw, GY + off.y), Color(Kit.BONE, 0.5), 1.5)
				var r1 := Rect2(pw * 0.55 + off.x, GY - H * 0.18 + off.y, 5.0, H * 0.18).intersection(panel)
				if r1.has_area():
					Kit.rect(n, r1, Kit.BONE)
				var r2 := Rect2(pw * 0.85 + off.x, GY - H * 0.1 + off.y, 5.0, H * 0.1).intersection(panel)
				if r2.has_area():
					Kit.rect(n, r2, Kit.BONE)
				Kit.ring(n, aim + off, 5.0, Kit.TARGET, 1.5)
				Kit.line(n, gun + off, gun + off + Vector2(cos(ang), sin(ang)) * 15.0, Kit.BONE, 3.0)
				Kit.mote(n, b, gun + off, ang)
				var bl: Dictionary = B[i]
				if bl.life > 0.0:
					Kit.dot(n, Vector2(bl.x, bl.y) + off, 2.5, Kit.HOT)
				if i > 0:
					Kit.line(n, Vector2(pw, 0.0), Vector2(pw, H), Kit.DIM, 1.0)
				var col: Color = Kit.MAGIC if i > 0 else Kit.HOT
				var c := Vector2(x0 + pw / 2.0, H * 0.2)   # the camera's offset, drawn ×3
				Kit.ring(n, c, 3.0, Kit.DIM, 1.0)
				Kit.arrow(n, c, c + Vector2(p.x, p.y) * 3.0, col)
				var plen: float = Vector2(p.x, p.y).length()
				Kit.label(n, b, "%s · offset %d px (×3)" % [p.name, roundi(plen)], Vector2(c.x, 12.0), col, true)
				var tx0 := x0 + pw * 0.08                    # the trace: |offset| over the last 48 frames
				var tw := pw * 0.84
				var ty := H - 20.0
				var th := H * 0.08
				Kit.line(n, Vector2(tx0, ty), Vector2(tx0 + tw, ty), Kit.DIM, 1.0)
				var hrow: Array = hist[i]
				var pts := PackedVector2Array()
				for j in NUDGE_HIST:
					var v: float = hrow[(hi + j) % NUDGE_HIST]
					pts.append(Vector2(tx0 + j / float(NUDGE_HIST - 1) * tw, ty - minf(th, v / (W * kick) * th)))
				n.draw_polyline(pts, col, 1.0)
			var sh: Dictionary = P[1]
			Kit.label(n, b, "shots %d · trauma %.2f" % [b.shots, sh.trauma], Vector2(W / 2.0, H * 0.3), Kit.DIM, true)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"zoompunch":
			var z: float = b.z
			var spark: float = b.spark
			var dolly: float = b.dolly
			var dollyLen: float = D.dolly
			var dollyZoom: float = D.dollyZoom
			var F: Array = b.F
			var foc := Vector2(b.fx, b.fy)
			# ← scale about the focus, by hand: p' = f + (p − f)·z (the kit's mote resets
			# any draw transform, so every point goes through the same little formula)
			Kit.line(n, foc + (Vector2(0.0, GY) - foc) * z, foc + (Vector2(W, GY) - foc) * z, Color(Kit.BONE, 0.5), 1.5 * z)   # the ground, zoomed
			var hx := 4.0
			while hx < W:
				Kit.line(n, foc + (Vector2(hx, GY + 2.0) - foc) * z, foc + (Vector2(hx - 5.0, GY + 8.0) - foc) * z, Color(Kit.BONE, 0.16), 1.0 * z)
				hx += 12.0
			for i in 5:
				var ph := (i % 2) * H * 0.05
				var r0 := Vector2(W * (0.1 + i * 0.2) - 2.0, GY - H * 0.08 - ph)
				var r1 := r0 + Vector2(4.0, H * 0.08 + ph)
				var q0 := foc + (r0 - foc) * z
				var q1 := foc + (r1 - foc) * z
				Kit.rect(n, Rect2(q0, q1 - q0), Color(Kit.BONE, 0.35))
			for i in 2:
				var a: Dictionary = F[i]
				var o: Dictionary = F[i ^ 1]
				var ax: float = a.x
				var ox: float = o.x
				var adir: float = a.dir
				var lunge: float = a.lunge
				var recoil: float = a.recoil
				var down: float = a.down
				var x := ax
				var y := GY - 12.0 + sin(t * 6.0 + i) * 1.5
				if lunge >= 0.0:
					x += (ox - ax) * 0.55 * sin(minf(1.0, lunge) * PI)
				x -= adir * recoil * W * 0.05
				var ang: float = adir * down * TAU / 4.0 if down > 0.0 else (0.0 if adir > 0.0 else PI)
				Kit.mote(n, b, foc + (Vector2(x, y + down * 6.0) - foc) * z, ang, a.c, 8.0 * z)
			if spark > 0.0:
				var spk := Vector2(b.sx, b.sy)
				for i in 8:
					var an := i / 8.0 * TAU + 0.4
					var r0 := 5.0
					var r1 := 6.0 + (1.0 - spark) * 16.0
					var dv := Vector2(cos(an), sin(an))
					Kit.line(n, foc + (spk + dv * r0 - foc) * z, foc + (spk + dv * r1 - foc) * z, Color(Kit.TARGET, spark), 2.0 * z)
			Kit.ring(n, foc, 6.0, Kit.TARGET, 1.0)         # the focus: the one point that does not move
			Kit.line(n, foc - Vector2(10.0, 0.0), foc + Vector2(10.0, 0.0), Kit.TARGET, 1.0)
			Kit.line(n, foc - Vector2(0.0, 10.0), foc + Vector2(0.0, 10.0), Kit.TARGET, 1.0)
			Kit.label(n, b, "f · z = %.2f" % z, foc + Vector2(12.0, -8.0), Kit.TARGET)
			var gx0 := W * 0.1                               # z over the last second
			var gw := W * 0.8
			var gy0 := 30.0
			var gh := 22.0
			Kit.line(n, Vector2(gx0, gy0), Vector2(gx0 + gw, gy0), Kit.DIM, 1.0)
			var zh: Array = b.zh
			var zi: int = b.zi
			var den: float = dollyZoom - 1.0 if dollyZoom != 1.0 else 1.0
			var pts := PackedVector2Array()
			for j in ZOOM_HIST:
				var v: float = zh[(zi + j) % ZOOM_HIST]
				if v == 0.0:
					v = 1.0
				pts.append(Vector2(gx0 + j / float(ZOOM_HIST - 1) * gw, gy0 - (v - 1.0) / den * gh))
			n.draw_polyline(pts, Kit.TARGET, 1.5)
			_label_right(n, b, "z = 1", Vector2(gx0 - 2.0, gy0 + 3.0), Kit.DIM)
			var txt := "hits %d" % b.hits
			txt += (" · death dolly %.1f / %s s" % [minf(dollyLen, dolly), _num(dollyLen)]) if dolly >= 0.0 else " · corners: dolly"
			Kit.label(n, b, txt, Vector2(W / 2.0, 12.0), FAINT, true)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"tracking":
			var rail: Array = D.rail
			var keys: Array = D.fovKeys
			var period: float = D.period
			var rangeK: float = D.range
			var tp: Vector2 = b.tp
			var goal: Vector2 = b.goal
			var ix: float = b.ix
			var iy: float = b.iy
			var iw: float = b.iw
			var ih: float = b.ih
			var ph := fmod(t / period, 1.0)
			var u: float = ph * 2.0 if ph < 0.5 else 2.0 - ph * 2.0   # there and back along the rail
			var cam := _tr_B(b, u)
			var fov := clampf(_tr_fov_at(b, u), 0.15, 2.8)
			var look := atan2(tp.y - cam.y, tp.x - cam.x)
			var rp := PackedVector2Array()                   # the rail
			for i in 33:
				rp.append(_tr_B(b, i / 32.0))
			n.draw_polyline(rp, Color(Kit.BONE, 0.3), 1.5)
			for i in 3:
				var q0: Array = rail[i]
				var q1: Array = rail[i + 1]
				n.draw_dashed_line(Vector2(W * float(q0[0]), H * float(q0[1])), Vector2(W * float(q1[0]), H * float(q1[1])), Kit.DIM, 1.0, 3.0)
			for q in rail:
				var qa: Array = q
				Kit.ring(n, Vector2(W * float(qa[0]), H * float(qa[1])), 3.0, Kit.DIM, 1.0)
			var R := W * rangeK                              # the frustum
			var e0 := cam + Vector2(cos(look - fov / 2.0), sin(look - fov / 2.0)) * R
			var e1 := cam + Vector2(cos(look + fov / 2.0), sin(look + fov / 2.0)) * R
			Kit.poly(n, [cam, e0, e1], Color(Kit.TARGET, 0.08))
			Kit.line(n, cam, e0, Color(Kit.TARGET, 0.6), 1.0)
			Kit.line(n, cam, e1, Color(Kit.TARGET, 0.6), 1.0)
			Kit.line(n, cam, tp, Color(Kit.MOVER, 0.35), 1.0)
			var seen: Array = []                             # what falls inside the wedge
			for q in b.posts:
				var qp := Vector2(q.x, q.y)
				var rel := _wrap_angle(atan2(qp.y - cam.y, qp.x - cam.x) - look)
				var d := qp.distance_to(cam)
				var inside := absf(rel) < fov / 2.0
				Kit.dot(n, qp, 4.0, Kit.GOOD if inside else Kit.BONE)
				if inside:
					seen.append({ "rel": rel, "d": d, "h": q.h, "mote": false })
			seen.append({ "rel": _wrap_angle(atan2(tp.y - cam.y, tp.x - cam.x) - look), "d": tp.distance_to(cam), "h": 0.6, "mote": true })
			seen.sort_custom(func(p1: Dictionary, p2: Dictionary) -> bool: return p1.d > p2.d)
			var origin: Vector2 = (b.rect as Rect2).position   # the camera glyph
			n.draw_set_transform(origin + cam, look, Vector2.ONE)
			Kit.rect(n, Rect2(-7.0, -5.0, 10.0, 10.0), Kit.BONE)
			Kit.poly(n, [Vector2(3.0, -3.0), Vector2(9.0, -6.0), Vector2(9.0, 6.0), Vector2(3.0, 3.0)], Kit.BONE)
			n.draw_set_transform(origin, 0.0, Vector2.ONE)
			Kit.ring(n, goal, 4.0, Kit.TARGET, 1.0)
			var dg := goal - tp
			Kit.mote(n, b, tp, atan2(dg.y, dg.x))
			var inset := Rect2(ix, iy, iw, ih)              # the inset: the framed view (the web clips to it; here its rects are intersected with it)
			Kit.rect(n, inset, INSET_BG)
			Kit.rect(n, Rect2(ix, iy + ih * 0.55, iw, ih * 0.45), Color(Kit.BONE, 0.08))
			Kit.line(n, Vector2(ix, iy + ih * 0.55), Vector2(ix + iw, iy + ih * 0.55), Kit.DIM, 1.0)
			var half := tan(fov / 2.0)
			for sd in seen:
				var sdd: float = sd.d
				var srel: float = sd.rel
				var shh: float = sd.h
				var k := W * 0.08 / maxf(sdd, W * 0.04)
				var sxp := ix + iw / 2.0 + tan(clampf(srel, -1.4, 1.4)) / half * iw / 2.0
				var base := iy + ih * 0.55 + minf(ih * 0.45, ih * 0.45 * k)
				var hh := minf(ih, shh * ih * 0.5 * k)
				if sd.mote:
					Kit.mote(n, b, Vector2(sxp, base - 8.0 * k), 0.0, Kit.MOVER, minf(14.0, 8.0 * k))
				else:
					var rr := Rect2(sxp - 2.0 * k - 1.0, base - hh, 4.0 * k + 2.0, hh).intersection(inset)
					if rr.has_area():
						Kit.rect(n, rr, Kit.GOOD)
			Kit.poly(n, [Vector2(ix, iy), Vector2(ix + iw, iy), Vector2(ix + iw, iy + ih), Vector2(ix, iy + ih)], Kit.BONE, 1.0)
			Kit.label(n, b, "the view · fov %d°" % roundi(fov * 360.0 / TAU), Vector2(ix + iw / 2.0, iy + ih + 11.0), FAINT, true)
			var kx0 := W * 0.06                              # the fov keyframes, and u
			var kw := W * 0.3
			var ky := H * 0.93
			var kh := H * 0.1
			Kit.line(n, Vector2(kx0, ky), Vector2(kx0 + kw, ky), Kit.DIM, 1.0)
			var kp := PackedVector2Array()
			for i in 25:
				kp.append(Vector2(kx0 + i / 24.0 * kw, ky - _tr_fov_at(b, i / 24.0) / 2.0 * kh))
			n.draw_polyline(kp, Kit.TARGET, 1.0)
			for kk in keys:
				var ka: Array = kk
				Kit.dot(n, Vector2(kx0 + clampf(float(ka[0]), 0.0, 1.0) * kw, ky - float(ka[1]) * TAU / 360.0 / 2.0 * kh), 2.5, Kit.TARGET)
			Kit.dot(n, Vector2(kx0 + u * kw, ky - fov / 2.0 * kh), 3.0, Kit.MOVER)
			Kit.label(n, b, "u %.2f" % u, Vector2(kx0 + kw + 6.0, ky - 2.0), Kit.DIM)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"zenith":
			var zn: Dictionary = b.zn
			var rx0: float = b.rx0
			var ry0: float = b.ry0
			var rw: float = b.rw
			var rh: float = b.rh
			var ix: float = b.ix
			var iy: float = b.iy
			var iw: float = b.iw
			var ih: float = b.ih
			var yaw: float = b.yaw
			var pitch: float = b.pitch
			var fovDeg: float = D.fov
			var pitchMin: float = D.pitchMin
			var pitchMax: float = D.pitchMax
			var px: float = zn.px
			var py: float = zn.py
			var ph: float = zn.ph
			var L: float = zn.L
			var lx: float = zn.lx
			var ly: float = zn.ly
			var hit: float = zn.hit
			var wantH: float = zn.wantH
			var short: bool = zn.short
			var arm3: float = zn.arm3
			var camH: float = zn.camH
			var cx: float = zn.cx
			var cy: float = zn.cy
			var piv := Vector2(px, py)
			var camp := Vector2(cx, cy)
			var dirv := Vector2(zn.dx, zn.dy)
			Kit.poly(n, [Vector2(rx0, ry0), Vector2(rx0 + rw, ry0), Vector2(rx0 + rw, ry0 + rh), Vector2(rx0, ry0 + rh)], Kit.BONE, 1.5)   # the map
			for q in b.posts:
				Kit.dot(n, Vector2(q.x, q.y), 4.0, Kit.BONE)
			n.draw_dashed_line(piv, piv + dirv * wantH, Kit.DIM, 1.0, 3.0)   # the arm it wanted
			Kit.line(n, piv, camp, Kit.HOT if short else Kit.BONE, 2.0)     # the arm it got
			if short:
				var wp := piv + dirv * hit
				Kit.dot(n, wp, 3.0, Kit.HOT)
				Kit.label(n, b, "wall", wp + Vector2(0.0, -6.0), Kit.HOT, true)
			var fov := fovDeg * TAU / 360.0
			Kit.line(n, camp, camp + Vector2(cos(yaw - fov / 2.0), sin(yaw - fov / 2.0)) * rw * 0.3, Color(Kit.TARGET, 0.45), 1.0)
			Kit.line(n, camp, camp + Vector2(cos(yaw + fov / 2.0), sin(yaw + fov / 2.0)) * rw * 0.3, Color(Kit.TARGET, 0.45), 1.0)
			Kit.dot(n, camp, 4.0, Kit.TARGET)
			Kit.mote(n, b, piv, ph)
			var inset := Rect2(ix, iy, iw, ih)              # the inset: what the camera sees (the web clips to it; rects are intersected with it here)
			Kit.rect(n, inset, INSET_BG)
			var f := (iw / 2.0) / tan(fov / 2.0)
			var vcx := ix + iw / 2.0
			var vcy := iy + ih / 2.0
			var horizon := vcy - tan(minf(pitch, 1.3)) * f
			var fl := Rect2(ix, maxf(iy, horizon), iw, ih).intersection(inset)
			if fl.has_area():
				Kit.rect(n, fl, Color(Kit.BONE, 0.08))
			if horizon > iy and horizon < iy + ih:
				Kit.line(n, Vector2(ix, horizon), Vector2(ix + iw, horizon), Kit.DIM, 1.0)
			var items: Array = []
			for q in b.posts:
				items.append({ "x": q.x, "y": q.y, "h": rw * 0.12, "mote": false })
			items.append({ "x": px, "y": py, "h": 0.0, "mote": true })
			for it in items:
				it.d = (it.x - cx) * lx + (it.y - cy) * ly
				it.s = -(it.x - cx) * ly + (it.y - cy) * lx
			items.sort_custom(func(p1: Dictionary, p2: Dictionary) -> bool: return p1.d > p2.d)
			for it in items:
				var itd: float = it.d
				var its: float = it.s
				var ith: float = it.h
				if itd < rw * 0.02:
					continue
				var sxp := vcx + its / itd * f
				var base := vcy + tan(clampf(atan2(camH, itd) - pitch, -1.4, 1.4)) * f
				var top := vcy + tan(clampf(atan2(camH - ith, itd) - pitch, -1.4, 1.4)) * f
				var wpx := minf(iw, 6.0 * f / itd * 0.6 + 1.0)
				if it.mote:
					var ms := minf(20.0, 9.0 * f / itd * 0.4)
					if sxp > ix and sxp < ix + iw:
						Kit.mote(n, b, Vector2(sxp, base - ms), _wrap_angle(ph - yaw) + PI / 2.0, Kit.MOVER, ms)
				else:
					var rr := Rect2(sxp - wpx / 2.0, minf(top, base), wpx, absf(base - top)).intersection(inset)
					if rr.has_area():
						Kit.rect(n, rr, Kit.GOOD)
			Kit.poly(n, [Vector2(ix, iy), Vector2(ix + iw, iy), Vector2(ix + iw, iy + ih), Vector2(ix, iy + ih)], Kit.BONE, 1.0)
			Kit.label(n, b, "the view", Vector2(ix + iw / 2.0, iy + ih + 11.0), FAINT, true)
			var gx := ix + iw * 0.15                         # the pitch gauge, side on
			var gy := H * 0.88
			var gr := iw * 0.7
			Kit.line(n, Vector2(gx - 6.0, gy), Vector2(gx + gr + 4.0, gy), Color(Kit.BONE, 0.5), 1.5)
			n.draw_dashed_line(Vector2(gx, gy), Vector2(gx, gy - gr), Kit.DIM, 1.0, 2.5)
			Kit.label(n, b, "zenith", Vector2(gx + 3.0, gy - gr + 2.0), Kit.DIM)
			n.draw_arc(Vector2(gx, gy), gr * 0.5, -minf(pitchMax, 1.55), -pitchMin, 32, Color(Kit.TARGET, 0.35), 3.0)
			var ratio := arm3 / L
			var tipv := Vector2(gx + cos(pitch) * gr * ratio, gy - sin(pitch) * gr * ratio)
			Kit.line(n, Vector2(gx, gy), tipv, Kit.HOT if short else Kit.BONE, 2.0)
			Kit.dot(n, tipv, 3.0, Kit.TARGET)
			Kit.dot(n, Vector2(gx, gy), 3.0, Kit.MOVER)
			Kit.label(n, b, "pitch %.2f · yaw %.2f" % [pitch, _wrap_angle(yaw)], Vector2(ix + iw / 2.0, H * 0.6), FAINT, true)
			Kit.label(n, b, "arm %d / %d px%s" % [roundi(arm3), roundi(L), " · shortened" if short else ""], Vector2(ix + iw / 2.0, H * 0.68), Kit.HOT if short else Kit.DIM, true)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"wrap":
			var wrapX: bool = D.wrapX
			var wrapY: bool = D.wrapY
			var ship: Dictionary = b.ship
			var aim: Vector2 = b.aim
			var ang: float = b.ang
			var burst: float = b.burst
			var ad: float = b.ad
			var seamX: float = b.seamX
			var seamY: float = b.seamY
			Kit.line(n, Vector2(0.0, 0.5), Vector2(W, 0.5), Color(Kit.MAGIC, 0.15 + seamY * 0.6), 1.0)   # the seams
			Kit.line(n, Vector2(0.0, H - 0.5), Vector2(W, H - 0.5), Color(Kit.MAGIC, 0.15 + seamY * 0.6), 1.0)
			Kit.line(n, Vector2(0.5, 0.0), Vector2(0.5, H), Color(Kit.MAGIC, 0.15 + seamX * 0.6), 1.0)
			Kit.line(n, Vector2(W - 0.5, 0.0), Vector2(W - 0.5, H), Color(Kit.MAGIC, 0.15 + seamX * 0.6), 1.0)
			if not wrapX:
				Kit.line(n, Vector2(0.5, 0.0), Vector2(0.5, H), Kit.BONE, 2.0)
				Kit.line(n, Vector2(W - 0.5, 0.0), Vector2(W - 0.5, H), Kit.BONE, 2.0)
			if not wrapY:
				Kit.line(n, Vector2(0.0, 0.5), Vector2(W, 0.5), Kit.BONE, 2.0)
				Kit.line(n, Vector2(0.0, H - 0.5), Vector2(W, H - 0.5), Kit.BONE, 2.0)
			for r in b.rocks:                                # each rock at x, and at x ± W / y ± H near a seam
				var rr: float = r.r
				var ra: float = r.a
				var rpts: Array = r.pts
				var rx: float = r.x
				var ry: float = r.y
				for off in _wr_offsets(b, rx, ry, rr):
					var ov: Vector2 = off
					var c := Vector2(rx, ry) + ov
					var pts: Array = []
					for i in 8:
						var a := ra + i / 8.0 * TAU
						pts.append(c + Vector2(cos(a), sin(a)) * rr * float(rpts[i]))
					Kit.poly(n, pts, Kit.BONE, 1.5)
					if ov != Vector2.ZERO:
						Kit.ring(n, c, rr + 4.0, Kit.MAGIC, 1.0)
						Kit.label(n, b, "copy", c + Vector2(0.0, -rr - 7.0), Kit.MAGIC, true)
			Kit.ring(n, aim, 5.0, Color(Kit.TARGET, 0.7), 1.0)
			var sp := Vector2(ship.x, ship.y)
			for off in _wr_offsets(b, sp.x, sp.y, 12.0):
				var ov: Vector2 = off
				var c := sp + ov
				if burst > 0.0 and ad > 8.0:                 # the flame (the web's rand jitter; draw-only randomness)
					for i in 3:
						Kit.dot(n, c - Vector2(cos(ang), sin(ang)) * (12.0 + i * 5.0) + Vector2(randf_range(-2.0, 2.0), randf_range(-2.0, 2.0)), 2.5 - i * 0.6, Kit.HOT)
				Kit.mote(n, b, c, ang)
				if ov != Vector2.ZERO:
					Kit.ring(n, c, 16.0, Kit.MAGIC, 1.0)
					Kit.label(n, b, "copy", c + Vector2(0.0, -19.0), Kit.MAGIC, true)
			Kit.label(n, b, "wraps %d · copies drawn now %d · %s · %s" % [b.wraps, b.copies, "x wraps" if wrapX else "x bounces", "y wraps" if wrapY else "y bounces"], Vector2(W / 2.0, 14.0), FAINT, true)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
