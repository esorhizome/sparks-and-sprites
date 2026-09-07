extends RefCounted

const Kit := preload("res://scenes/motion/kit.gd")
## GAME VERBS — thirteen movement styles, ported from the web lexicon
## (docs/locomotion.js). The verbs a game is made of, each one a tiny
## playable system whose rule can be read straight off the canvas: a bobber
## and a tension bar, tiles that grow one stage per day, a patty with a
## sweet spot, a push that needs a free cell beyond, needs that decay into a
## mood, emotes on a schedule, a xylophone with a music box, a pixel canvas
## that becomes a texture, a photo mode with two clocks, a match-3 cascade,
## tetromino gravity, a note highway judged by distance to the beat, and the
## cartoon wind-up run. Every card plays itself — an autopilot, sometimes a
## clumsy one — until you take the controls; the numbers that make the game
## fair or cruel all sit in D.

const TITLE := "Game verbs"
const BLURB := "fishing, farming, cooking, sokoban, a pet, emotes, an instrument, painting, photo mode, match-3, tetrominoes, rhythm, the cartoon wind-up"
const DEFS := [
	{ "id": "angler", "letter": "A", "name": "Angler",
		"hint": "fishing: a bobber rides Undulate's wave, a random bite, a tug, then a tension minigame — keep the bar inside the moving zone — drag to reel",
		"drag": true,
		"dials": { "biteMin": 1.5, "biteMax": 4.5,   # seconds before a fish bites
			"tug": 0.9,                              # seconds the bite lasts before the fish leaves
			"reel": 3.4, "g": 1.8, "damp": 2.5,      # the reel marker: accel up while reeling, gravity down, Damp's drag per s (in bar heights)
			"zoneH": 0.24, "zoneSpeed": 0.55,        # the fish's zone: height ×bar, how fast it wanders
			"fill": 0.4, "drain": 0.32,              # catch progress per second inside / outside the zone
			"amp": 0.03, "waves": 3, "w": 2.2,       # the wave: amplitude ×H, wavelengths across W, angular speed
			"lag": 0.4,                              # the autopilot's reaction lag, seconds — it plays badly on purpose
			"label": "in zone: catch += fill·dt · outside: catch −= drain·dt" },
		"rhyme": { "name": "Abyss", "hint": "deep water: twice the wait, a fish that darts fast inside a narrow zone — the late-game catch that takes a steady hand",
			"dials": { "biteMax": 9, "zoneSpeed": 1.3, "zoneH": 0.14 } } },
	{ "id": "farm", "letter": "F", "name": "Farm",
		"hint": "farming: till → plant → water → grow one stage per day → harvest; a state per tile and a day counter ticking — press a tile to work it",
		"dials": { "tiles": 6,        # plots in the row
			"dayLen": 3.5,            # seconds per day
			"growDays": 3,            # watered days from seed to harvest
			"actEvery": 0.8,          # the farmer's pause between jobs
			"speed": 0.7,             # the farmer's walk, ×W per second
			"label": "tile.state → next · stage = days it was watered" },
		"rhyme": { "name": "Fastforward", "hint": "days fly by and the row is longer — a farmer who never stops running, the time-lapse of a season",
			"dials": { "dayLen": 1.1, "tiles": 9, "actEvery": 0.3 } } },
	{ "id": "kitchen", "letter": "K", "name": "Kitchen",
		"hint": "cooking: doneness fills while a side is down, a sweet spot band, then the burn — timing is the game — press the pan to flip, the plate to serve",
		"dials": { "rate": 0.24,                  # doneness per second for the side that is down
			"sweetLo": 0.7, "sweetHi": 0.92,      # the sweet spot
			"burn": 1.1,                          # past this a side is burnt
			"slop": 0.9,                          # the autopilot's lateness, up to this many seconds
			"sizzle": 30,                         # sizzle particles per second
			"label": "side += rate·dt · sweet ∈ [lo, hi] · burnt ≥ burn" },
		"rhyme": { "name": "Kebab", "hint": "slow heat and a wide sweet spot — the skewer that forgives a daydream, though it still burns in the end",
			"dials": { "rate": 0.1, "sweetLo": 0.55, "sweetHi": 0.95 } } },
	{ "id": "sokoban", "letter": "S", "name": "Sokoban",
		"hint": "sokoban: a push succeeds only if the cell beyond is free, an undo stack of snapshots, a solver that plays and rewinds — press beside the mote to push, on it to undo",
		"dials": { "level": ["########",   # # wall  @ player  $ crate  O goal
				"#......#",
				"#.@$...#",
				"#..#..O#",
				"#..$..O#",
				"########"],
			"mode": "push",                # "push": a crate moves one cell · "ice": it slides to the next wall
			"stepEvery": 0.45,             # the solver's pace, seconds per move
			"label": "push ok ⇔ cell beyond is free · undo = pop the snapshot" },
		"rhyme": { "name": "Sledge", "hint": "on ice a pushed crate slides until it meets a wall or another crate — the same level, a different solution the solver finds by itself",
			"dials": { "mode": "ice", "stepEvery": 0.6 } } },
	{ "id": "needs", "letter": "N", "name": "Needs",
		"hint": "a pet: hunger, energy and affection decay every second; the lowest need is the mood, and the mood picks the idle and the emote — press an icon to feed, rest or play",
		"dials": { "decay": [0.05, 0.035, 0.07],   # hunger, energy, affection lost per second
			"careEvery": 3.2,                      # how often the owner's hand comes to help
			"happy": 0.6, "low": 0.3,              # mood thresholds on the lowest need
			"feed": 0.55, "rest": 0.6, "play": 0.5,   # what each action restores
			"label": "need −= decay·dt · mood = min(needs) → idle + emote" },
		"rhyme": { "name": "Neurotic", "hint": "needs that crash three times as fast and a mood that is only happy near full — the pet that is never satisfied for long",
			"dials": { "decay": [0.16, 0.12, 0.2], "happy": 0.8, "careEvery": 2.4 } } },
	{ "id": "emote", "letter": "E", "name": "Emote",
		"hint": "emotes on a schedule: sweat, blush, tears, an anger vein, an idea bulb, sparkle eyes — each a tiny drawing with a pop-in above the head — press to play the next one",
		"dials": { "sequence": ["sweat", "blush", "tears", "anger", "idea", "sparkle"],   # names drawn from code; unknown = "?"
			"each": 1.8,          # seconds per emote
			"pop": 0.22,          # pop-in time
			"overshoot": 1.35,    # the pop-in's peak scale
			"label": "emote = sequence[i], i += 1 every `each` s · scale pops to overshoot, settles to 1" },
		"rhyme": { "name": "Elated", "hint": "only the happy ones, twice as fast — a bulb, sparkles, a blush and a heart, the victory-screen loop",
			"dials": { "sequence": ["idea", "sparkle", "blush", "heart"], "each": 0.9 } } },
	{ "id": "xylophone", "letter": "X", "name": "Xylophone",
		"hint": "an instrument: keys map to a pentatonic scale, a music box plays a tune array with two bouncing hammers, bars light per note — press a key to play it (sound after the first press)",
		"dials": { "scale": [261.63, 293.66, 329.63, 392, 440, 523.25, 587.33, 659.26],   # C pentatonic, an octave and a bit
			"tune": [0, 2, 4, 5, 4, 2, 0, -1, 2, 4, 7, 5, 4, 2, 0, -1],                   # the music box: key indices, −1 rests
			"bpm": 168,           # one tune step per beat
			"decay": 5,           # how fast a struck bar's light fades, per second
			"label": "f = scale[key] · light *= e^(−decay·dt) · one step per 60/bpm s" },
		"rhyme": { "name": "Xylobox", "hint": "a minor pentatonic, a new tune and a brisker box — the same keys in a sadder key, the music box in the attic",
			"dials": { "scale": [220, 246.94, 261.63, 329.63, 349.23, 440, 493.88, 523.25], "tune": [5, 3, 2, 0, 2, 3, 5, -1, 6, 5, 3, 2, 3, 2, 0, -1], "bpm": 220 } } },
	{ "id": "paint", "letter": "P", "name": "Paint",
		"hint": "a pixel canvas: a brush, a flood fill and a palette on a small grid; the picture tiles into a texture on the right — drag to paint, press the palette to pick",
		"drag": true,
		"dials": { "cols": 24, "rows": 16,   # the canvas grid
			"brush": 2,                      # brush size, in cells
			"palette": ["#F58A8A", "#F5C169", "#9BE28A", "#8AD9F5", "#C9A0F5", "#E8E5F4", "#2A2340"],
			"doodle": 6,                     # the ghost brush's speed, cells per second
			"fillEvery": 6,                  # seconds between the ghost's flood fills
			"label": "px[r][c] = colour · brush = a b×b square · fill = flood from the seed's colour" },
		"rhyme": { "name": "Plotter", "hint": "a one-cell brush on a grid four times as big — pixel art proper, where the flood fill earns its keep",
			"dials": { "cols": 48, "rows": 32, "brush": 1 } } },
	{ "id": "snapshot", "letter": "S", "name": "Snapshot",
		"hint": "photo mode: freeze the world's clock while the UI clock runs, free the camera to pan and zoom about the focus, a filter and a frame, a shutter flash — press to freeze, drag to pan",
		"drag": true,
		"dials": { "every": 4.5,         # seconds of play between the autopilot's photos
			"hold": 2.2,                 # seconds a photo mode lasts after the last touch
			"zoom": 1.5,                 # the photo zoom
			"filter": "none",            # "none" · "sepia" · "night"
			"frame": "corners",          # "corners" (a viewfinder) · "polaroid"
			"balls": 4, "g": 1.8, "e": 0.85,   # the little scene: bouncing balls, gravity ×H, restitution
			"label": "world dt = frozen ? 0 : dt · ui dt = dt · view = zoom·(p − focus) + centre" },
		"rhyme": { "name": "Sepiabooth", "hint": "a sepia grade inside a polaroid border and a gentler zoom — the photo booth at the end of the pier",
			"dials": { "filter": "sepia", "frame": "polaroid", "zoom": 1.25 } } },
	{ "id": "gems", "letter": "G", "name": "Gems",
		"hint": "match-3: swap two neighbours, runs of 3+ in a row or column clear with a flash, gravity fills from above, and the cascade repeats — press two adjacent gems to swap",
		"dials": { "cols": 7, "rows": 6,   # the board
			"kinds": 4,                    # gem types
			"thinkEvery": 1.1,             # the autopilot's pause between moves
			"fall": 9,                     # gravity, in cells per second²
			"swapTime": 0.18,              # the swap animation
			"clearTime": 0.3,              # the clear flash
			"label": "match = run ≥ 3 in a row/col · clear → gravity → match again (cascade)" },
		"rhyme": { "name": "Glitter", "hint": "five kinds on a bigger board — matches are rarer, cascades longer, and the autopilot has to look harder",
			"dials": { "cols": 8, "rows": 7, "kinds": 5 } } },
	{ "id": "tetromino", "letter": "T", "name": "Tetromino",
		"hint": "tetromino gravity: the piece steps down one row per tick, locks when blocked, full rows flash and everything above shifts down — press beside the piece to move it, on it to rotate",
		"dials": { "cols": 10, "rows": 14,   # the well
			"dropEvery": 0.35,               # seconds per gravity tick
			"moveEvery": 0.12,               # the autopilot's pace
			"flash": 0.35,                   # the line-clear flash
			"label": "each tick y += 1 · blocked → lock · full row → flash, clear, shift down" },
		"rhyme": { "name": "Tinygrid", "hint": "a six-wide well and gravity two and a half times faster — pieces pile up before the autopilot has finished thinking",
			"dials": { "cols": 6, "rows": 12, "dropEvery": 0.14 } } },
	{ "id": "rhythm", "letter": "R", "name": "Rhythm",
		"hint": "rhythm judgement: notes ride a highway toward the hit line; a press is Perfect, Good or Miss by its distance to the note's beat; combo and feedback text — press on the beat (sound after the first press)",
		"dials": { "bpm": 110,                    # the song's tempo
			"perfect": 0.05, "good": 0.12,        # judgement windows, seconds
			"speed": 0.35,                        # highway speed, ×W per second
			"pattern": [1, 1, 0.5, 0.5, 1, 2],    # beats between notes, looped
			"err": 0.09,                          # the autopilot's timing error, ± seconds
			"label": "Δ = |tPress − tNote| · perfect ≤ " },
		"rhyme": { "name": "Relentless", "hint": "a fast chart with windows squeezed to 30 and 70 ms — the expert difficulty where the autopilot starts to miss",
			"dials": { "bpm": 170, "perfect": 0.03, "good": 0.07 } } },
	{ "id": "windup", "letter": "W", "name": "Windup",
		"hint": "the cartoon wind-up: legs blur in place while a timer fills, then a delayed launch with a dust cloud and speed lines — goofy locomotion and VFX in one — press to wind it up",
		"dials": { "windup": 0.8,     # seconds of legs spinning in place
			"delay": 0.15,            # the pause between "ready" and actually leaving
			"speed": 2.2,             # the run, ×W per second
			"spin": 40,               # the leg blur, radians per second
			"dustR": 0.12,            # the dust cloud's puff radius, ×H
			"every": 3.2,             # the autopilot's rest between runs
			"label": "legs spin for `windup` s · wait `delay` · then x += speed·dt, dust at the start" },
		"rhyme": { "name": "Whoosh", "hint": "a wind-up twice as long with no pause at all and a cloud three times the size — the gag where only the dust is left",
			"dials": { "windup": 1.8, "delay": 0, "dustR": 0.32 } } },
]

const FAINT := Color(0.91, 0.898, 0.957, 0.55)   # the web label's default ink
const INK_BG := Color(0.91, 0.898, 0.957, 0.08)  # the web's "rgba(232,229,244,0.08)" bar background
const SOK_DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const TET_BASE := [                                # [box size, the four cells] per tetromino
	[4, [Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1)]],
	[2, [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]],
	[3, [Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 0)]],
	[3, [Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, 0), Vector2i(2, 0)]],
	[3, [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1)]],
	[3, [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)]],
	[3, [Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)]]]
const GEM_COL := [Kit.HOT, Kit.TARGET, Kit.GOOD, Kit.MOVER, Kit.MAGIC, Kit.BONE]
const TET_COL := [Kit.MOVER, Kit.TARGET, Kit.MAGIC, Kit.GOOD, Kit.HOT, Kit.BONE, Color(0.961, 0.627, 0.816)]
const JUDGE_COL := [Kit.GOOD, Kit.TARGET, Kit.HOT]
const JUDGE_TXT := ["PERFECT", "GOOD", "MISS"]
const FARM_NAMES := ["soil", "tilled", "planted", "ready"]
const FARM_VERBS := ["till", "plant", "water", "harvest"]
const NEED_NAMES := ["hunger", "energy", "love"]

## A number for a label: "1" for whole values, "0.25" otherwise (JS's "" + k).
static func _num(v: float) -> String:
	return ("%d" % roundi(v)) if v == roundf(v) else ("%s" % v)

## The web label's "right" alignment: measure, then draw ending at p.x.
static func _label_right(n: CanvasItem, b: Dictionary, txt: String, p: Vector2, col: Color) -> void:
	var f := ThemeDB.fallback_font
	var w: float = f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	Kit.label(n, b, txt, Vector2(p.x - w, p.y), col)

## The web kit's ease: a clamped smoothstep.
static func _ease(k: float) -> float:
	var kk := clampf(k, 0.0, 1.0)
	return kk * kk * (3.0 - 2.0 * kk)

## ctx.globalAlpha: the same colour, its alpha multiplied.
static func _a(c: Color, alpha: float) -> Color:
	return Color(c.r, c.g, c.b, c.a * alpha)

## A CSS hsl(h, s%, l%) colour, through HSV.
static func _hsl(h: float, sat: float, lum: float) -> Color:
	var v := lum + sat * minf(lum, 1.0 - lum)
	var sv := 0.0 if v == 0.0 else 2.0 * (1.0 - lum / v)
	return Color.from_hsv(h, sv, v)

## ctx.ellipse: a 32-gon, optionally rotated about its centre.
static func _ellipse(n: CanvasItem, c: Vector2, rx: float, ry: float, col: Color, ang: float = 0.0) -> void:
	var pts := PackedVector2Array()
	for i in 32:
		var a := i / 32.0 * TAU
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry).rotated(ang))
	n.draw_colored_polygon(pts, col)

## The kit's mote under a non-uniform scale (the web's ctx.scale(sx, sy)
## before mote()): translate → scale → rotate, so squash and stretch stay
## in the body's own frame. Restores the card offset like Kit.mote does.
static func _mote_xf(n: CanvasItem, b: Dictionary, p: Vector2, ang: float, col: Color, s: float, sc: Vector2) -> void:
	var origin: Vector2 = (b.rect as Rect2).position
	var xf := Transform2D(ang, Vector2.ZERO).scaled(sc)
	xf.origin = origin + p
	n.draw_set_transform_matrix(xf)
	n.draw_circle(Vector2.ZERO, s, col)
	n.draw_colored_polygon(PackedVector2Array([
		Vector2(s * 0.45, -s * 0.6), Vector2(s * 1.5, 0), Vector2(s * 0.45, s * 0.6)]), col)
	n.draw_circle(Vector2(s * 0.38, -s * 0.3), s * 0.22, Kit.NIGHT)
	n.draw_set_transform(origin, 0.0, Vector2.ONE)

## An outlined axis-aligned box (the web's poly(..., true) rectangles).
static func _box(n: CanvasItem, r: Rect2, col: Color, w: float = 1.0) -> void:
	Kit.poly(n, [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)], col, w)

# ---------------------------------------------------------------- Angler

static func _angler_surface(b: Dictionary, x: float, tt: float) -> float:
	var D: Dictionary = b.D
	var waves: float = D.waves
	var w: float = D.w
	var amp: float = D.amp
	return b.h * 0.5 + sin(x / b.w * TAU * waves - tt * w) * b.h * amp

static func _angler_hook(b: Dictionary) -> void:
	if b.phase != "bite":
		return
	b.phase = "fight"
	b.fightT = 0.0
	b.prog = 0.35
	b.ind = 0.5
	b.iv = 0.0
	b.zc = 0.5
	b.zcSeen = 0.5

static func _angler_finish(b: Dictionary, ok: bool) -> void:
	b.phase = "done"
	b.pt = 1.4
	b.msg = "caught!" if ok else "it got away"
	b.msgT = 1.4
	if ok:
		b.caught += 1
	else:
		b.lost += 1

# ---------------------------------------------------------------- Farm

static func _farm_tile_x(b: Dictionary, i: int) -> float:
	return b.x0 + (i + 0.5) * b.tw

## The job a tile wants: 3 harvest, 2 water, 1 plant, 0 till, −1 wait.
static func _farm_job(tl: Dictionary) -> int:
	var st: int = tl.s
	if st == 3:
		return 3
	if st == 2:
		return -1 if tl.wet else 2
	return st

static func _farm_act(b: Dictionary, i: int) -> void:
	var tl: Dictionary = b.tiles[i]
	var j := _farm_job(tl)
	var pops: Array = b.pops
	var py: float = b.gy - b.th - 6.0
	if j < 0:
		pops.append({ "x": _farm_tile_x(b, i), "y": py, "t": 0.8, "txt": "wait for the day", "c": Kit.DIM })
	else:
		if j == 0:
			tl.s = 1
		elif j == 1:
			tl.s = 2
			tl.age = 0
			tl.wet = false
		elif j == 2:
			tl.wet = true
		else:
			tl.s = 0
			b.harvested += 1
		pops.append({ "x": _farm_tile_x(b, i), "y": py, "t": 0.8, "txt": FARM_VERBS[j], "c": Kit.TARGET if j == 3 else Kit.GOOD })
	if pops.size() > 8:
		pops.pop_front()

# ---------------------------------------------------------------- Kitchen

static func _kitchen_flip(b: Dictionary) -> void:
	if not b.patty or b.flipT > 0.0:
		return
	b.down = 1 - b.down
	b.flipT = 0.35

static func _kitchen_serve(b: Dictionary) -> void:
	if not b.patty or b.flipT > 0.0:
		return
	var D: Dictionary = b.D
	var side: Array = b.side
	var lo: float = minf(side[0], side[1])
	var hi: float = maxf(side[0], side[1])
	var score: Dictionary = b.score
	if hi >= D.burn:
		b.verdict = "burnt"
		b.verdictC = Kit.HOT
		score.burnt += 1
	elif lo < D.sweetLo:
		b.verdict = "raw inside"
		b.verdictC = Kit.BONE
		score.raw += 1
	elif hi > D.sweetHi:
		b.verdict = "overdone"
		b.verdictC = Kit.TARGET
		score.burnt += 1
	else:
		b.verdict = "perfect!"
		b.verdictC = Kit.GOOD
		score.perfect += 1
	b.verdictT = 1.2
	b.patty = false
	b.nextT = 1.0
	b.serveT = 0.0

## Doneness → colour: pink → brown → black.
static func _kitchen_colour(d: float) -> Color:
	var k := clampf(d, 0.0, 1.3)
	var r: float = lerpf(235.0, 120.0, k) if k < 1.0 else lerpf(120.0, 30.0, (k - 1.0) / 0.3)
	var g: float = lerpf(150.0, 70.0, k) if k < 1.0 else lerpf(70.0, 25.0, (k - 1.0) / 0.3)
	var bl: float = lerpf(160.0, 40.0, k) if k < 1.0 else lerpf(40.0, 25.0, (k - 1.0) / 0.3)
	return Color(roundf(r) / 255.0, roundf(g) / 255.0, roundf(bl) / 255.0)

# ---------------------------------------------------------------- Sokoban

## The index of the crate at (x, y) in a state [px, py, c1x, c1y, …], or −1.
static func _sok_crate_at(st: Array, x: int, y: int) -> int:
	var i := 2
	while i < st.size():
		if st[i] == x and st[i + 1] == y:
			@warning_ignore("integer_division")   # crate slots are pairs: an index, not a fraction
			return (i - 2) / 2
		i += 2
	return -1

## One step of the rules; an empty Array is the web's null (an illegal move).
static func _sok_step(b: Dictionary, st: Array, d: int, test: bool) -> Array:
	var cols: int = b.cols
	var wall: Array = b.wall
	var dir: Vector2i = SOK_DIRS[d]
	var nx: int = st[0] + dir.x
	var ny: int = st[1] + dir.y
	if wall[ny * cols + nx]:
		return []
	var k := _sok_crate_at(st, nx, ny)
	var out := st.duplicate()
	if k >= 0:
		var bx := nx + dir.x
		var by := ny + dir.y
		var free: bool = not wall[by * cols + bx] and _sok_crate_at(st, bx, by) < 0
		if test:
			b.testX = bx
			b.testY = by
			b.testOk = free
			b.testT = 0.5
		if not free:
			return []
		if b.D.mode == "ice":
			while not wall[(by + dir.y) * cols + bx + dir.x] and _sok_crate_at(st, bx + dir.x, by + dir.y) < 0:
				bx += dir.x
				by += dir.y
		out[2 + k * 2] = bx
		out[3 + k * 2] = by
	out[0] = nx
	out[1] = ny
	return out

## A state's key: the player's cell, then the crates' cells sorted (so the
## crates are interchangeable), folded into one integer.
static func _sok_key(b: Dictionary, st: Array) -> int:
	var cols: int = b.cols
	var ncell: int = b.ncell
	var ids := PackedInt32Array()
	var i := 2
	while i < st.size():
		ids.append(st[i + 1] * cols + st[i])
		i += 2
	ids.sort()
	var key: int = st[1] * cols + st[0]
	for id in ids:
		key = key * ncell + id
	return key

static func _sok_solved(b: Dictionary, st: Array) -> bool:
	for g in b.goals:
		if _sok_crate_at(st, (g as Vector2i).x, (g as Vector2i).y) < 0:
			return false
	return true

## BFS: the first solution is the shortest. Empty = no solution found.
static func _sok_solve(b: Dictionary, from: Array) -> Array:
	var seen := { _sok_key(b, from): true }
	var states: Array = [from]
	var parent: Array = [-1]
	var move: Array = [-1]
	var i := 0
	while i < states.size() and states.size() < 20000:
		var st: Array = states[i]
		if _sok_solved(b, st):
			var path: Array = []
			var j := i
			while parent[j] >= 0:
				path.append(move[j])
				j = parent[j]
			path.reverse()
			return path
		for d in 4:
			var nxt := _sok_step(b, st, d, false)
			if nxt.is_empty():
				continue
			var k := _sok_key(b, nxt)
			if seen.has(k):
				continue
			seen[k] = true
			states.append(nxt)
			parent.append(i)
			move.append(d)
		i += 1
	return []

static func _sok_try(b: Dictionary, d: int) -> bool:
	b.heading = d
	var st: Array = b.s
	var nxt := _sok_step(b, st, d, true)
	if nxt.is_empty():
		return false
	if _sok_crate_at(st, nxt[0], nxt[1]) >= 0:
		b.pushes += 1
	var undo: Array = b.undo
	undo.append(st)
	if undo.size() > 64:
		undo.pop_front()
	b.s = nxt
	return true

static func _sok_pop(b: Dictionary) -> void:
	var undo: Array = b.undo
	if undo.size() > 0:
		b.s = undo.pop_back()
		b.plan = []
		b.plan_ok = false

# ---------------------------------------------------------------- Needs

static func _needs_mood(b: Dictionary) -> String:
	var D: Dictionary = b.D
	var needs: Array = b.needs
	var m: float = minf(needs[0], minf(needs[1], needs[2]))
	return "happy" if m >= D.happy else ("okay" if m >= D.low else "grumpy")

static func _needs_lowest(b: Dictionary) -> int:
	var needs: Array = b.needs
	var k := 0
	for i in range(1, 3):
		if needs[i] < needs[k]:
			k = i
	return k

## A bowl, a moon, a heart.
static func _needs_icon(n: CanvasItem, i: int, x: float, y: float, c: Color) -> void:
	if i == 0:
		Kit.poly(n, [Vector2(x - 7, y - 2), Vector2(x + 7, y - 2), Vector2(x + 4, y + 4), Vector2(x - 4, y + 4)], c)
		Kit.dot(n, Vector2(x, y - 4), 3.0, c)
	elif i == 1:
		Kit.dot(n, Vector2(x, y), 6.0, c)
		Kit.dot(n, Vector2(x + 3, y - 2), 5.0, Color(0.102, 0.083, 0.196))
	else:
		Kit.dot(n, Vector2(x - 3, y - 2), 3.5, c)
		Kit.dot(n, Vector2(x + 3, y - 2), 3.5, c)
		Kit.poly(n, [Vector2(x - 6.3, y - 0.5), Vector2(x + 6.3, y - 0.5), Vector2(x, y + 6)], c)

static func _needs_act(b: Dictionary, i: int) -> void:
	var D: Dictionary = b.D
	var needs: Array = b.needs
	if i == 0:
		needs[0] = minf(1.0, needs[0] + D.feed)
		b.crumbT = 0.6
	elif i == 1:
		b.sleepT = 1.6
	else:
		needs[2] = minf(1.0, needs[2] + D.play)
		needs[1] = maxf(0.0, needs[1] - 0.08)
		b.spinT = 0.5
		b.heartT = 0.8

# ---------------------------------------------------------------- Emote

static func _star(n: CanvasItem, x: float, y: float, r: float, c: Color) -> void:
	Kit.poly(n, [Vector2(x, y - r), Vector2(x + r * 0.3, y - r * 0.3), Vector2(x + r, y), Vector2(x + r * 0.3, y + r * 0.3),
		Vector2(x, y + r), Vector2(x - r * 0.3, y + r * 0.3), Vector2(x - r, y), Vector2(x - r * 0.3, y - r * 0.3)], c)

static func _heart(n: CanvasItem, x: float, y: float, r: float, c: Color) -> void:
	Kit.dot(n, Vector2(x - r * 0.5, y - r * 0.3), r * 0.55, c)
	Kit.dot(n, Vector2(x + r * 0.5, y - r * 0.3), r * 0.55, c)
	Kit.poly(n, [Vector2(x - r * 1.03, y - r * 0.05), Vector2(x + r * 1.03, y - r * 0.05), Vector2(x, y + r)], c)

## One emote, drawn in head space (0,0 = above the head), k = 0..1 through
## its life, alpha = the fade-out (the web's globalAlpha).
static func _emote(n: CanvasItem, b: Dictionary, nm: String, k: float, alpha: float) -> void:
	match nm:
		"sweat":
			var y := 4.0 + k * 18.0
			Kit.dot(n, Vector2(16, y), 4.0, _a(Kit.MOVER, alpha))
			Kit.poly(n, [Vector2(12.2, y - 1), Vector2(19.8, y - 1), Vector2(16, y - 9)], _a(Kit.MOVER, alpha))
		"blush":
			var pink := Color(0.961, 0.541, 0.541, 0.55 * alpha)
			_ellipse(n, Vector2(-6, 22), 5.0, 3.0, pink)
			_ellipse(n, Vector2(8, 22), 5.0, 3.0, pink)
			for j in range(-1, 2):
				Kit.line(n, Vector2(6 + j * 4, 20), Vector2(8 + j * 4, 25), _a(Kit.HOT, alpha))
		"tears":
			for sgn in [-1.0, 1.0]:
				var x: float = 4.0 + sgn * 4.0
				Kit.line(n, Vector2(x, 18), Vector2(x + sgn * 2.0, 34), _a(Kit.MOVER, alpha), 2.0)
				Kit.dot(n, Vector2(x + sgn * 3.0, 36.0 + fmod(k * 60.0, 14.0)), 2.5, _a(Kit.MOVER, alpha))
		"anger":
			var x := 14.0
			var y := -2.0
			var s := 6.0
			var c := _a(Kit.HOT, alpha)
			Kit.line(n, Vector2(x - s, y - 2), Vector2(x - 2, y - 2), c, 3.0)
			Kit.line(n, Vector2(x + 2, y - 2), Vector2(x + s, y - 2), c, 3.0)
			Kit.line(n, Vector2(x - s, y + 2), Vector2(x - 2, y + 2), c, 3.0)
			Kit.line(n, Vector2(x + 2, y + 2), Vector2(x + s, y + 2), c, 3.0)
			Kit.line(n, Vector2(x - 2, y - s), Vector2(x - 2, y - 2), c, 3.0)
			Kit.line(n, Vector2(x + 2, y - s), Vector2(x + 2, y - 2), c, 3.0)
			Kit.line(n, Vector2(x - 2, y + 2), Vector2(x - 2, y + s), c, 3.0)
			Kit.line(n, Vector2(x + 2, y + 2), Vector2(x + 2, y + s), c, 3.0)
		"idea":
			Kit.dot(n, Vector2(0, -8), 8.0, _a(Kit.TARGET, alpha))
			Kit.rect(n, Rect2(-4, 0, 8, 5), _a(Kit.BONE, alpha))
			if k < 0.4:
				for j in 6:
					var a := j / 6.0 * TAU
					Kit.line(n, Vector2(cos(a) * 12, -8 + sin(a) * 12), Vector2(cos(a) * 17, -8 + sin(a) * 17), _a(Kit.TARGET, alpha))
		"sparkle":
			for j in 3:
				var a := j * 2.1 + k * 3.0
				var r := 4.0 + sin(k * 20.0 + j) * 1.5
				_star(n, cos(a) * 20.0, -6.0 + sin(a) * 12.0, r, _a(Kit.TARGET, alpha))
			_star(n, 4.0, 18.0, 4.0, _a(Kit.INK, alpha))
		"heart":
			_heart(n, 0.0, -6.0 - k * 10.0, 7.0, _a(Kit.HOT, alpha))
		_:
			Kit.ring(n, Vector2(0, -6), 10.0, _a(Kit.BONE, alpha), 1.5)
			Kit.label(n, b, "?", Vector2(0, -2), _a(Kit.INK, alpha), true)

# ---------------------------------------------------------------- Xylophone

static func _xkey_top(b: Dictionary, i: int) -> float:
	var nn: int = b.nn
	var h: float = lerpf(b.h * 0.5, b.h * 0.26, i / float(nn - 1))
	return b.cy - h / 2.0

static func _xylo_strike(b: Dictionary, i: int, h: int) -> void:
	var D: Dictionary = b.D
	var light: Array = b.light
	var shake: Array = b.shake
	light[i] = 1.0
	shake[i] = 0.0
	var hm: Dictionary = b.ham[h]
	hm.x = b.x0 + (i + 0.5) * b.kw
	hm.y = _xkey_top(b, i) - 3.0
	hm.vy = -b.h * 1.3
	hm.rest = _xkey_top(b, i) - 22.0
	if b.armed and b.sinceBeep >= 0.16:
		Kit.beep(float(D.scale[i]), 0.35, "sine")
		b.sinceBeep = 0.0

# ---------------------------------------------------------------- Paint

static func _paint_brush(b: Dictionary, c: int, r: int) -> void:
	var D: Dictionary = b.D
	var cols: int = b.cols
	var rows: int = b.rows
	var px: Array = b.px
	var bs: int = D.brush
	var o := int(floorf((bs - 1) / 2.0))
	var colour: int = b.colour
	for dy in bs:
		for dx in bs:
			var cc := c - o + dx
			var rr := r - o + dy
			if cc >= 0 and cc < cols and rr >= 0 and rr < rows:
				px[rr * cols + cc] = colour

## The flood fill: a stack of cells that spreads to four neighbours while
## they share the seed's colour.
static func _paint_fill(b: Dictionary, c: int, r: int) -> void:
	var cols: int = b.cols
	var rows: int = b.rows
	var px: Array = b.px
	var colour: int = b.colour
	var seed: int = px[r * cols + c]
	if seed == colour:
		return
	var stack: Array = [r * cols + c]
	px[r * cols + c] = colour
	while stack.size() > 0:
		var i: int = stack.pop_back()
		var ic := i % cols
		@warning_ignore("integer_division")   # (i − ic) is a whole number of rows
		var ir := (i - ic) / cols
		if ic > 0 and px[i - 1] == seed:
			px[i - 1] = colour
			stack.append(i - 1)
		if ic < cols - 1 and px[i + 1] == seed:
			px[i + 1] = colour
			stack.append(i + 1)
		if ir > 0 and px[i - cols] == seed:
			px[i - cols] = colour
			stack.append(i - cols)
		if ir < rows - 1 and px[i + cols] == seed:
			px[i + cols] = colour
			stack.append(i + cols)

## Runs of equal cells become one rect (st = the sampling stride for the tiles).
static func _paint_grid(n: CanvasItem, b: Dictionary, x0: float, y0: float, s: float, st: int) -> void:
	var cols: int = b.cols
	var rows: int = b.rows
	var px: Array = b.px
	var palc: Array = b.palc
	var r := 0
	while r < rows:
		var c := 0
		while c < cols:
			var v: int = px[r * cols + c]
			var e := c + st
			while e < cols and px[r * cols + e] == v:
				e += st
			n.draw_rect(Rect2(x0 + c / float(st) * s, y0 + r / float(st) * s, (e - c) / float(st) * s + 0.3, s + 0.3), palc[v])
			c = e
		r += st

# ---------------------------------------------------------------- Snapshot

static func _snap_clamp_focus(b: Dictionary) -> void:
	var z: float = b.z
	var hw: float = b.w / (2.0 * z)
	var hh: float = b.h / (2.0 * z)
	b.tfx = clampf(b.tfx, hw, b.w - hw)
	b.tfy = clampf(b.tfy, hh, b.h - hh)

static func _snap_enter(b: Dictionary, x: float, y: float) -> void:
	b.frozen = true
	b.holdT = b.D.hold
	b.frozenFor = 0.0
	b.flash = 1.0
	b.tfx = x
	b.tfy = y

# ---------------------------------------------------------------- Gems

static func _gem_at(b: Dictionary, c: int, r: int) -> int:
	var cols: int = b.cols
	return b.type[r * cols + c]

## A fresh board with no ready-made runs.
static func _gem_seed(b: Dictionary) -> void:
	var D: Dictionary = b.D
	var cols: int = b.cols
	var rows: int = b.rows
	var kinds: int = D.kinds
	var type: Array = b.type
	var yoff: Array = b.yoff
	var vy: Array = b.vy
	var clr: Array = b.clr
	for r in rows:
		for c in cols:
			var k := 0
			var tries := 0
			while true:
				k = randi_range(0, kinds - 1)
				tries += 1
				var runH: bool = c >= 2 and _gem_at(b, c - 1, r) == k and _gem_at(b, c - 2, r) == k
				var runV: bool = r >= 2 and _gem_at(b, c, r - 1) == k and _gem_at(b, c, r - 2) == k
				if not (runH or runV) or tries > 50:
					break
			type[r * cols + c] = k
			yoff[r * cols + c] = 0.0
			vy[r * cols + c] = 0.0
			clr[r * cols + c] = 0.0

## Is (c, r) inside a run of 3+?
static func _gem_run_at(b: Dictionary, c: int, r: int) -> bool:
	var cols: int = b.cols
	var rows: int = b.rows
	var k := _gem_at(b, c, r)
	if k < 0:
		return false
	var cnt := 1
	var i := c - 1
	while i >= 0 and _gem_at(b, i, r) == k:
		cnt += 1
		i -= 1
	i = c + 1
	while i < cols and _gem_at(b, i, r) == k:
		cnt += 1
		i += 1
	if cnt >= 3:
		return true
	cnt = 1
	i = r - 1
	while i >= 0 and _gem_at(b, c, i) == k:
		cnt += 1
		i -= 1
	i = r + 1
	while i < rows and _gem_at(b, c, i) == k:
		cnt += 1
		i += 1
	return cnt >= 3

## Mark every horizontal or vertical run of three or more; start their flash.
static func _gem_find_matches(b: Dictionary) -> int:
	var D: Dictionary = b.D
	var cols: int = b.cols
	var rows: int = b.rows
	var N: int = cols * rows
	var mark: Array = b.mark
	var clr: Array = b.clr
	for i in N:
		mark[i] = 0
	for r in rows:
		for c in cols:
			var k := _gem_at(b, c, r)
			if k < 0:
				continue
			if c + 2 < cols and _gem_at(b, c + 1, r) == k and _gem_at(b, c + 2, r) == k:
				var e := c
				while e < cols and _gem_at(b, e, r) == k:
					mark[r * cols + e] = 1
					e += 1
			if r + 2 < rows and _gem_at(b, c, r + 1) == k and _gem_at(b, c, r + 2) == k:
				var e := r
				while e < rows and _gem_at(b, c, e) == k:
					mark[e * cols + c] = 1
					e += 1
	var count := 0
	for i in N:
		if mark[i] == 1:
			count += 1
			clr[i] = D.clearTime
	return count

static func _gem_settled(b: Dictionary) -> bool:
	if b.swapT > 0.0:
		return false
	var N: int = b.cols * b.rows
	var type: Array = b.type
	var yoff: Array = b.yoff
	var clr: Array = b.clr
	for i in N:
		if yoff[i] > 0.0 or clr[i] > 0.0 or type[i] < 0:
			return false
	return true

static func _gem_swap_types(b: Dictionary, a: int, c: int) -> void:
	var type: Array = b.type
	var k: int = type[a]
	type[a] = type[c]
	type[c] = k

static func _gem_start_swap(b: Dictionary, a: int, c: int) -> void:
	b.sa = a
	b.sb = c
	b.swapT = b.D.swapTime
	b.back = false
	b.sel = -1

# ---------------------------------------------------------------- Tetromino

static func _tet_fits(b: Dictionary, tp: int, r: int, x: int, y: int) -> bool:
	var cols: int = b.cols
	var rows: int = b.rows
	var grid: Array = b.grid
	var cells: Array = b.rot[tp][r]
	for c in cells:
		var cx: int = x + (c as Vector2i).x
		var cy: int = y + (c as Vector2i).y
		if cx < 0 or cx >= cols or cy >= rows:
			return false
		if cy >= 0 and grid[cy * cols + cx] != 0:
			return false
	return true

static func _tet_spawn(b: Dictionary) -> void:
	var cols: int = b.cols
	b.type = randi_range(0, 6)
	b.rot_i = 0
	b.px = int(floorf(cols / 2.0)) - 2
	b.py = -1
	b.wantRot = randi_range(0, 3)
	b.wantCol = randi_range(0, cols - 2)
	if not _tet_fits(b, b.type, b.rot_i, b.px, b.py):
		b.over = 0.8

## Rotate with a small wall kick: try in place, then one and two cells aside.
static func _tet_rotate(b: Dictionary) -> bool:
	var r: int = (b.rot_i + 1) % 4
	for k in [0, -1, 1, -2, 2]:
		if _tet_fits(b, b.type, r, b.px + k, b.py):
			b.rot_i = r
			b.px += k
			return true
	return false

static func _tet_lock(b: Dictionary) -> void:
	var cols: int = b.cols
	var rows: int = b.rows
	var grid: Array = b.grid
	var full: Array = b.full
	var cells: Array = b.rot[b.type][b.rot_i]
	for c in cells:
		var cy: int = b.py + (c as Vector2i).y
		if cy >= 0:
			grid[cy * cols + b.px + (c as Vector2i).x] = b.type + 1
	var any := false
	for r in rows:
		var f := 1
		for c in cols:
			if grid[r * cols + c] == 0:
				f = 0
				break
		full[r] = f
		if f == 1:
			any = true
	if any:
		b.flashT = b.D.flash
	else:
		_tet_spawn(b)

## Every row above a full one copies down one.
static func _tet_clear(b: Dictionary) -> void:
	var cols: int = b.cols
	var rows: int = b.rows
	var grid: Array = b.grid
	var full: Array = b.full
	var w := rows - 1
	var r := rows - 1
	while r >= 0:
		if full[r] == 1:
			b.lines += 1
			r -= 1
			continue
		if w != r:
			for c in cols:
				grid[w * cols + c] = grid[r * cols + c]
		w -= 1
		r -= 1
	while w >= 0:
		for c in cols:
			grid[w * cols + c] = 0
		w -= 1
	for i in rows:
		full[i] = 0
	_tet_spawn(b)

# ---------------------------------------------------------------- Rhythm

static func _rhythm_judge(b: Dictionary, nt: Dictionary, delta: float) -> void:
	var D: Dictionary = b.D
	var a := absf(delta)
	nt.j = 0 if a <= D.perfect else (1 if a <= D.good else 2)
	nt.jt = 0.0
	if nt.j == 2:
		b.combo = 0
	else:
		b.combo += 1
		b.best = maxi(b.best, b.combo)
	b.fb = JUDGE_TXT[nt.j]
	b.fbC = JUDGE_COL[nt.j]
	b.fbT = 0.6
	b.fbD = delta
	if nt.j < 2 and b.armed and b.sinceBeep >= 0.16:
		Kit.beep(880.0 if nt.j == 0 else 660.0, 0.1, "square")
		b.sinceBeep = 0.0

static func _rhythm_hit(b: Dictionary) -> void:
	var D: Dictionary = b.D
	var song: float = b.song
	var bestN: Dictionary = {}
	var bestA := 1.0e9
	for nt in b.notes:
		if nt.j < 0:
			var a: float = absf(nt.t - song)
			if a < bestA:
				bestA = a
				bestN = nt
	var good: float = D.good
	if not bestN.is_empty() and bestA <= good * 2.5:
		_rhythm_judge(b, bestN, song - bestN.t)

# ---------------------------------------------------------------- Windup

static func _windup_puff(b: Dictionary, px: float, py: float, r: float, vx: float, vy: float, life: float) -> void:
	for d in b.dust:
		if d.life <= 0.0:
			d.x = px
			d.y = py
			d.r = r
			d.vx = vx
			d.vy = vy
			d.life = life
			return

static func _windup_wind(b: Dictionary) -> void:
	if b.phase == "idle" or b.phase == "back":
		b.phase = "wind"
		b.pt = 0.0

static func init(b: Dictionary) -> void:
	var D: Dictionary = b.D
	var W: float = b.w
	var H: float = b.h
	var GY: float = b.gy
	match b.id:
		"angler":
			# FISHING is three timers in a trench coat. WAIT: a random delay while the
			# bobber rides Undulate's wave y = sin(kx − ωt). BITE: a short window where
			# the bobber is tugged under — press inside it or the fish leaves. FIGHT:
			# the tension bar — the fish's zone wanders by noise, your reel pushes the
			# marker up against gravity (Damp's drag keeps it tame), and the catch
			# fills inside the zone and drains outside. the autopilot sees the zone a
			# lag late and overshoots, which is exactly what a first-timer does.
			b.phase = "wait"
			b.pt = randf_range(D.biteMin, D.biteMax)
			b.react = 0.0
			b.bobX = W * 0.6
			b.tugOff = 0.0
			b.hold = 0.0
			b.manualT = 0.0
			b.sincePress = 9.0
			b.splashT = 0.0
			b.splashX = 0.0
			b.ind = 0.5
			b.iv = 0.0
			b.zc = 0.5
			b.zcSeen = 0.5
			b.lagT = 0.0
			b.prog = 0.35
			b.fightT = 0.0
			b.msgT = 0.0
			b.msg = ""
			b.caught = 0
			b.lost = 0
		"farm":
			# a FARM is a state machine per tile — soil → tilled → planted → ready —
			# plus one number, the stage, that only the DAY may advance: at each day
			# tick a watered plant grows one stage and dries out again, so watering
			# is a promise you renew every morning. that is the save-file shape from
			# §16: a tiny struct per tile, one clock, nothing else. the farmer is an
			# autopilot walking to the best job (harvest before water before plant
			# before till); your press does the same job on the tile you point at.
			var nn: int = D.tiles
			b.nn = nn
			b.tw = minf(W * 0.88 / nn, H * 0.22)
			b.th = b.tw * 0.5
			b.x0 = (W - nn * b.tw) / 2.0
			b.tiles = []
			for _i in nn:
				b.tiles.append({ "s": 0, "age": 0, "wet": false })
			b.pops = []
			b.day = 1
			b.dayT = 0.0
			b.harvested = 0
			b.actT = 0.0
			b.target = -1
			b.fx = W / 2.0
			b.dir = 1
			b.walking = false
		"kitchen":
			# COOKING is a timer you cannot see directly. each side has a DONENESS
			# that only grows while it faces the pan; a FLIP swaps which side grows;
			# serving is judged against the sweet spot — under is raw, over is
			# burnt, both is perfect. the sizzle is ch06's ambient particle rule
			# (emit += rate·dt) and the two bars are §14's meters. the autopilot
			# flips and serves a random bit late, so you get to watch the mistakes.
			b.parts = []
			for _i in 48:
				b.parts.append({ "x": 0.0, "y": 0.0, "vx": 0.0, "vy": 0.0, "life": 0.0, "smoke": false })
			b.side = [0.0, 0.0]
			b.down = 0
			b.flipT = 0.0
			b.serveT = 0.0
			b.verdict = ""
			b.verdictC = Kit.DIM
			b.verdictT = 0.0
			b.emit = 0.0
			b.lateFlip = randf_range(0.0, D.slop)
			b.lateServe = randf_range(0.0, D.slop)
			b.manualT = 0.0
			b.patty = true
			b.nextT = 0.0
			b.score = { "perfect": 0, "raw": 0, "burnt": 0 }
		"sokoban":
			# SOKOBAN is Grid's cell logic with one rule added: a step into a crate is
			# a PUSH, legal only if the cell beyond the crate is neither wall nor
			# crate (the tested cell lights green or red). every move first pushes
			# a snapshot onto an UNDO stack, so undo is a pop. the autopilot is a
			# breadth-first search over (player, crates) — the same step function
			# the player uses — so it copes with the ice rule too; after solving it
			# rewinds through the stack and starts again.
			var level: Array = D.level
			var rows: int = level.size()
			var cols: int = (level[0] as String).length()
			b.rows = rows
			b.cols = cols
			b.ncell = rows * cols
			b.cs = minf(W * 0.72 / cols, (H - 44.0) / rows)
			b.ox = (W - cols * b.cs) / 2.0
			b.oy = (H - rows * b.cs) / 2.0 + 6.0
			var wall: Array = []
			wall.resize(rows * cols)
			var goals: Array = []
			var start: Array = [0, 0]
			var crates0: Array = []
			for r in rows:
				var row: String = level[r]
				for c in cols:
					var ch := row[c]
					wall[r * cols + c] = ch == "#"
					if ch == "@" or ch == "+":
						start[0] = c
						start[1] = r
					if ch == "$" or ch == "*":
						crates0.append(c)
						crates0.append(r)
					if ch == "O" or ch == "*" or ch == "+":
						goals.append(Vector2i(c, r))
			start.append_array(crates0)
			b.wall = wall
			b.goals = goals
			b.start = start
			b.s = start.duplicate()                      # the logical state, and the eased picture of it
			var vis: Array = []
			for v in start:
				vis.append(float(v))
			b.vis = vis
			b.undo = []
			b.plan = []
			b.plan_ok = false                            # the web's plan === null
			b.stepT = 0.0
			b.phase = "solve"
			b.holdT = 0.0
			b.heading = 0
			b.pushes = 0
			b.testX = -1
			b.testY = -1
			b.testOk = false
			b.testT = 0.0
		"needs":
			# a PET is three numbers that fall and a MOOD read off the lowest one.
			# every second each NEED loses its decay; the mood (happy / okay /
			# grumpy) chooses which of Idle's animations plays — a hop, a breath, a
			# droop — and the lowest need is drawn as the emote in the thought
			# bubble. feeding, resting and playing are just additions; resting is a
			# little state of its own (the pet lies down and the bar fills slowly).
			# the owner's hand is an autopilot that helps the neediest bar.
			b.needs = [0.9, 0.8, 0.85]
			b.rowY = [H * 0.24, H * 0.42, H * 0.6]
			b.iconX = W * 0.6
			b.barX = W * 0.66
			b.barW = W * 0.3
			b.px = W * 0.3
			b.py = GY - 18.0
			b.careT = 0.0
			b.hand = -1
			b.handT = 0.0
			b.sleepT = 0.0
			b.spinT = 0.0
			b.crumbT = 0.0
			b.heartT = 0.0
		"emote":
			# an EMOTE is a small sprite parented to the head with a lifetime: it
			# POPS IN (scale overshoots, then settles — the folio's Hearts and
			# Question do the same), lives for `each` seconds, fades out. a
			# SCHEDULE is just an index into a list of names; the body reacts to
			# each name too (a shiver, a droop, a hop), because an emote is a
			# moment, not a decoration. every sprite here is a few dots and lines.
			b.SZ = maxf(1.0, minf(1.8, H / 220.0))        # the sprites grow with the editor, not the card
			b.cx = W / 2.0
			b.cy = GY - 16.0 * b.SZ
			b.i = 0
			b.et = 0.0
		"xylophone":
			# an INSTRUMENT is a lookup table: key index → frequency, and a scale
			# chosen so that any two keys sound fine together (a PENTATONIC has no
			# wrong notes — the folio's Xylophone used the same trick). the MUSIC
			# BOX is ch07's beat clock reading a tune array one step per beat; two
			# hammers alternate, each a spring that is kicked on the strike so it
			# bounces. the light on a bar decays like every fading thing here:
			# multiply by e^(−decay·dt). beep() is only ever called after a press.
			var nn: int = (D.scale as Array).size()
			b.nn = nn
			b.kw = W * 0.8 / nn
			b.x0 = W * 0.1
			b.cy = H * 0.5
			b.light = []
			b.shake = []
			for _i in nn:
				b.light.append(0.0)
				b.shake.append(0.0)
			b.ham = [{ "x": b.x0 + b.kw * 1.5, "y": 0.0, "vy": 0.0, "rest": 0.0 },
				{ "x": b.x0 + b.kw * (nn - 1.5), "y": 0.0, "vy": 0.0, "rest": 0.0 }]
			for hm in b.ham:                             # each hammer rests above the key it starts on
				hm.rest = _xkey_top(b, roundi((hm.x - b.x0) / b.kw - 0.5)) - 22.0
				hm.y = hm.rest
			b.stepT = 0.0
			b.pos = -1
			b.armed = false
			b.sinceBeep = 9.0
			b.next = 0
		"paint":
			# a PAINTING is a grid of palette indices, and a texture is the same
			# grid repeated — ch02 made its tiles procedurally, this one hands you the
			# brush. the BRUSH writes a b×b square; the FLOOD FILL is a stack of
			# cells that spreads to four neighbours while they share the seed's
			# colour; the pointer's cell is ⌊(x − x0)/cs⌋. drawing merges runs of
			# equal cells into one rect so even a big grid stays cheap. the ghost
			# brush doodles by noise and fills something every few seconds.
			var cols: int = D.cols
			var rows: int = D.rows
			var pal: Array = D.palette
			b.cols = cols
			b.rows = rows
			b.palc = []
			for hex in pal:
				b.palc.append(Color(hex as String))
			b.px = []
			b.px.resize(cols * rows)
			b.px.fill(pal.size() - 1)
			b.sw = minf(18.0, H * 0.085)
			b.palX = 6.0
			b.palY = 10.0
			b.cx0 = W * 0.16
			b.cs = minf((W * 0.5) / cols, (H - 34.0) / rows)
			b.cy0 = (H - 20.0 - rows * b.cs) / 2.0 + 4.0
			b.tx0 = b.cx0 + cols * b.cs + W * 0.04
			b.tileW = (W - b.tx0 - 6.0) / 2.0
			b.ps = b.tileW / cols
			b.stride = maxi(1, ceili(cols / 16.0))
			b.colour = 0
			b.tool = "brush"
			b.gx = cols / 2.0
			b.gy2 = rows / 2.0
			b.ga = 0.0
			b.fillT = 0.0
			b.colourT = 0.0
			b.lastC = -1
			b.lastR = -1
			b.sinceP = 9.0
		"snapshot":
			# PHOTO MODE is §7's pause with the camera let off its leash: TWO CLOCKS
			# in one frame — the world's dt is zeroed while the interface's dt keeps
			# running (the corners breathe, the timer counts). the camera is a
			# scale about a FOCUS point: translate to the centre, scale by zoom,
			# translate by −focus; a drag moves the focus against the pointer. the
			# filter is §8's grading done with one multiply rect; the frame is
			# drawn last, unzoomed, because it belongs to the UI clock.
			var seed := Kit.rng(11)
			var balls: Array = []
			var nb: int = D.balls
			var palette := [Kit.TARGET, Kit.GOOD, Kit.HOT, Kit.MAGIC]
			for i in nb:
				balls.append({ "x": W * (0.15 + seed.randf() * 0.7), "y": H * (0.2 + seed.randf() * 0.3),
					"vx": W * (seed.randf() - 0.5) * 0.5, "vy": 0.0, "r": 5.0 + seed.randf() * 5.0, "c": palette[i % 4] })
			b.balls = balls
			b.mx = W * 0.3
			b.mvx = W * 0.18
			b.my = GY - 9.0
			b.mvy = 0.0
			b.hopT = 0.0
			b.frozen = false
			b.everyT = 0.0
			b.holdT = 0.0
			b.frozenFor = 0.0
			b.flash = 0.0
			b.z = 1.0
			b.fx = W / 2.0
			b.fy = H / 2.0
			b.tfx = W / 2.0
			b.tfy = H / 2.0
			b.sinceP = 9.0
			b.ax = 0.0
			b.ay = 0.0
			b.afx = 0.0
			b.afy = 0.0
			b.manual = false
			b.orbit = 0.0
			b.wdt = 0.0
			b.uidt = 0.0
		"gems":
			# MATCH-3 is Grid with three verbs. SWAP two neighbours (undo it if
			# nothing matched); MATCH: mark every horizontal or vertical run of three
			# or more; GRAVITY: each column compacts downward and new gems fall in
			# from above — and then match again, because falling makes new runs: the
			# CASCADE. the pictures per cell are one number (yoff, how far above its
			# home a gem still is) and one timer (the clear flash). the autopilot
			# tests every neighbour swap in place and takes one that matches.
			var cols: int = D.cols
			var rows: int = D.rows
			var N := cols * rows
			b.cols = cols
			b.rows = rows
			b.cs = minf(W * 0.62 / cols, (H - 40.0) / rows)
			b.ox = (W - cols * b.cs) / 2.0
			b.oy = (H - rows * b.cs) / 2.0 + 4.0
			b.type = []
			b.type.resize(N)
			b.type.fill(-1)
			b.yoff = []
			b.yoff.resize(N)
			b.yoff.fill(0.0)
			b.vy = []
			b.vy.resize(N)
			b.vy.fill(0.0)
			b.clr = []
			b.clr.resize(N)
			b.clr.fill(0.0)
			b.mark = []
			b.mark.resize(N)
			b.mark.fill(0)
			b.sel = -1
			b.sa = -1
			b.sb = -1
			b.swapT = 0.0
			b.back = false
			b.score = 0
			b.cascade = 0
			b.thinkT = 0.0
			b.hintT = 0.0
			b.shuffleT = 0.0
			_gem_seed(b)
		"tetromino":
			# TETRIS GRAVITY is Grid's tick: every dropEvery seconds the piece moves
			# one row down if all four cells below are free; if not, it LOCKS — its
			# cells are written into the well and a new piece spawns. a LINE CLEAR
			# is a row with no gaps: it flashes, then every row above it copies
			# down one. rotation turns each cell (x, y) into (n−1−y, x) inside the
			# piece's box, with a small wall kick. the ghost outline is where the
			# piece would land; the autopilot picks a random column and rotation.
			var cols: int = D.cols
			var rows: int = D.rows
			b.cols = cols
			b.rows = rows
			b.cs = minf(W * 0.5 / cols, (H - 30.0) / rows)
			b.ox = (W - cols * b.cs) / 2.0
			b.oy = (H - rows * b.cs) / 2.0 + 2.0
			var rot: Array = []                          # four rotations per piece
			for base in TET_BASE:
				var box: int = base[0]
				var cells: Array = base[1]
				var out: Array = []
				for _r in 4:
					out.append(cells)
					var turned: Array = []
					for p in cells:
						turned.append(Vector2i(box - 1 - (p as Vector2i).y, (p as Vector2i).x))
					cells = turned
				rot.append(out)
			b.rot = rot
			b.grid = []
			b.grid.resize(cols * rows)
			b.grid.fill(0)
			b.full = []
			b.full.resize(rows)
			b.full.fill(0)
			b.type = 0
			b.rot_i = 0
			b.px = 0
			b.py = 0
			b.dropT = 0.0
			b.moveT = 0.0
			b.flashT = 0.0
			b.lines = 0
			b.wantCol = 0
			b.wantRot = 0
			b.over = 0.0
			_tet_spawn(b)
		"rhythm":
			# RHYTHM is Kickdrum's beat clock with a ruler: every note owns a time,
			# and a press is scored by |tPress − tNote| against two WINDOWS — inside
			# the small one is Perfect, inside the big one Good, a note that drifts
			# past the big one unpressed is a Miss. the highway is that same
			# arithmetic drawn: x = hitLine + (tNote − now)·speed, so distance on
			# screen IS distance in time. the feedback text pops in like the
			# grimoire's Pop-in, and a Miss resets the COMBO. beeps follow a press.
			b.hitX = W * 0.22
			b.laneY = H * 0.5
			b.pxPerS = W * D.speed
			b.notes = []
			b.song = 0.0
			b.lastNote = 1.0
			b.pi = 0
			b.combo = 0
			b.best = 0
			b.fb = ""
			b.fbC = Kit.DIM
			b.fbT = 0.0
			b.fbD = 0.0
			b.armed = false
			b.sinceBeep = 9.0
			b.manualT = 0.0
		"windup":
			# the WIND-UP is anticipation made silly: the body leans back and
			# shakes while a fan of leg lines spins in place (a BLUR is many faint
			# copies at different phases), the timer fills, and then — after a
			# deliberate DELAY, the joke's beat — the body is gone in one frame,
			# leaving a dust cloud (the codex's Landing dust, borrowed for a
			# take-off) and speed lines. Cat's squash and stretch does the rest:
			# long on the run, flat on the wall.
			b.x0 = W * 0.16
			b.y = GY - 9.0
			b.dust = []
			for _i in 30:
				b.dust.append({ "x": 0.0, "y": 0.0, "vx": 0.0, "vy": 0.0, "r": 0.0, "life": 0.0 })
			b.x = b.x0
			b.phase = "idle"
			b.pt = D.every * 0.4
			b.puffT = 0.0

static func press(b: Dictionary, pos: Vector2) -> void:
	var D: Dictionary = b.D
	var W: float = b.w
	match b.id:
		"angler":
			b.manualT = 3.0
			if b.phase == "bite":
				_angler_hook(b)
			elif b.phase == "wait" and b.sincePress > 0.25:
				b.bobX = clampf(pos.x, W * 0.36, W * 0.8)
				b.splashT = 0.5
				b.splashX = b.bobX
			b.hold = 0.12
			b.sincePress = 0.0
		"farm":
			var i := int(floorf((pos.x - b.x0) / b.tw))
			if i >= 0 and i < b.nn:
				_farm_act(b, i)
		"kitchen":
			b.manualT = 3.0
			if pos.x > W * 0.7:
				_kitchen_serve(b)
			else:
				_kitchen_flip(b)
		"sokoban":
			var st: Array = b.s
			var cs: float = b.cs
			var cx: float = b.ox + (st[0] + 0.5) * cs
			var cy: float = b.oy + (st[1] + 0.5) * cs
			var dx := pos.x - cx
			var dy := pos.y - cy
			if absf(dx) < cs / 2.0 and absf(dy) < cs / 2.0:
				_sok_pop(b)
				b.phase = "solve"
				return
			var d: int
			if absf(dx) > absf(dy):
				d = 0 if dx > 0.0 else 1
			else:
				d = 2 if dy > 0.0 else 3
			_sok_try(b, d)
			b.plan = []
			b.plan_ok = false
			b.phase = "solve"
		"needs":
			var rowY: Array = b.rowY
			for i in 3:
				if absf(pos.y - rowY[i]) < 12.0 and pos.x > b.iconX - 14.0:
					_needs_act(b, i)
					return
			if absf(pos.x - b.px) < 24.0 and absf(pos.y - b.py) < 24.0:
				_needs_act(b, 2)
		"emote":
			var nn: int = (D.sequence as Array).size()
			b.i = (b.i + 1) % nn
			b.et = 0.0
		"xylophone":
			b.armed = true
			var nn: int = b.nn
			var i: int = clampi(int(floorf((pos.x - b.x0) / b.kw)), 0, nn - 1)
			_xylo_strike(b, i, 0 if pos.x < W / 2.0 else 1)
		"paint":
			var pal: Array = D.palette
			var sw: float = b.sw
			if pos.x < b.palX + sw + 4.0:                # the palette and the two tools
				var k := int(floorf((pos.y - b.palY) / (sw + 4.0)))
				if k >= 0 and k < pal.size():
					b.colour = k
					b.tool = "brush"
				elif k == pal.size():
					b.tool = "brush"
				elif k == pal.size() + 1:
					b.tool = "fill"
				b.sinceP = 0.0
				return
			var cols: int = b.cols
			var rows: int = b.rows
			var c := int(floorf((pos.x - b.cx0) / b.cs))
			var r := int(floorf((pos.y - b.cy0) / b.cs))
			if c < 0 or c >= cols or r < 0 or r >= rows:
				return
			if b.tool == "fill":
				_paint_fill(b, c, r)
			elif b.sinceP < 0.1 and b.lastC >= 0:        # a drag: join the dots since the last press
				var lastC: int = b.lastC
				var lastR: int = b.lastR
				var steps: int = maxi(maxi(absi(c - lastC), absi(r - lastR)), 1)
				for i in range(1, steps + 1):
					_paint_brush(b, roundi(lastC + (c - lastC) * i / float(steps)), roundi(lastR + (r - lastR) * i / float(steps)))
			else:
				_paint_brush(b, c, r)
			b.lastC = c
			b.lastR = r
			b.sinceP = 0.0
		"snapshot":
			if b.sinceP > 0.25:                          # a fresh click
				if not b.frozen:
					_snap_enter(b, pos.x, pos.y)
					b.manual = true
				b.ax = pos.x
				b.ay = pos.y
				b.afx = b.tfx
				b.afy = b.tfy
			elif b.frozen:                               # a drag: pan against the pointer
				var z: float = b.z
				b.tfx = b.afx - (pos.x - b.ax) / z
				b.tfy = b.afy - (pos.y - b.ay) / z
			b.holdT = D.hold
			b.sinceP = 0.0
			_snap_clamp_focus(b)
		"gems":
			var cols: int = b.cols
			var rows: int = b.rows
			var c := int(floorf((pos.x - b.ox) / b.cs))
			var r := int(floorf((pos.y - b.oy) / b.cs))
			if c < 0 or c >= cols or r < 0 or r >= rows or not _gem_settled(b):
				return
			var i := r * cols + c
			var sel: int = b.sel
			if sel < 0:
				b.sel = i
			else:
				var sc := sel % cols
				@warning_ignore("integer_division")   # (sel − sc) is a whole number of rows
				var sr := (sel - sc) / cols
				if absi(sc - c) + absi(sr - r) == 1:
					_gem_start_swap(b, sel, i)
					b.thinkT = -3.0
				else:
					b.sel = i
		"tetromino":
			if b.flashT > 0.0 or b.over > 0.0:
				return
			var minC := 9
			var maxC := -1
			var cells: Array = b.rot[b.type][b.rot_i]
			for c in cells:
				minC = mini(minC, b.px + (c as Vector2i).x)
				maxC = maxi(maxC, b.px + (c as Vector2i).x)
			var col: float = (pos.x - b.ox) / b.cs
			if col < minC:
				if _tet_fits(b, b.type, b.rot_i, b.px - 1, b.py):
					b.px -= 1
			elif col > maxC + 1:
				if _tet_fits(b, b.type, b.rot_i, b.px + 1, b.py):
					b.px += 1
			else:
				_tet_rotate(b)
			b.moveT = -1.5                               # your hands, not the autopilot's, for a moment
		"rhythm":
			b.armed = true
			b.manualT = 2.5
			_rhythm_hit(b)
		"windup":
			_windup_wind(b)

static func tick(b: Dictionary, dt: float, t: float) -> void:
	var D: Dictionary = b.D
	var W: float = b.w
	var H: float = b.h
	var GY: float = b.gy
	match b.id:
		"angler":
			b.sincePress += dt
			b.hold -= dt
			b.manualT -= dt
			b.splashT -= dt
			b.msgT -= dt
			var manual: bool = b.manualT > 0.0
			var phase: String = b.phase
			if phase == "wait":
				b.pt -= dt
				b.tugOff += (0.0 - b.tugOff) * minf(1.0, 8.0 * dt)
				if b.pt <= 0.0:
					b.phase = "bite"
					b.pt = 0.0
					b.react = randf_range(0.15, D.tug * 1.4)   # sometimes slower than the fish
			elif phase == "bite":
				b.pt += dt
				b.tugOff = 7.0 + sin(b.pt * 34.0) * 3.0
				if not manual and b.pt >= b.react:
					_angler_hook(b)
				elif b.pt >= D.tug:
					b.phase = "wait"
					b.pt = randf_range(D.biteMin, D.biteMax)
					b.msg = "too slow"
					b.msgT = 0.9
			elif phase == "fight":
				b.fightT += dt
				var zoneH: float = D.zoneH
				b.zc = 0.5 + Kit.noise(b.fightT * D.zoneSpeed + 3.7) * (0.5 - zoneH / 2.0)   # the fish wanders
				b.lagT += dt
				if b.lagT >= D.lag:                      # the autopilot's stale picture
					b.lagT = 0.0
					b.zcSeen = b.zc
				var reeling: bool = (b.hold > 0.0) if manual else (b.ind < b.zcSeen)
				var reel: float = D.reel
				var g: float = D.g
				var damp: float = D.damp
				b.iv += ((reel if reeling else -g) - damp * b.iv) * dt
				b.ind += b.iv * dt
				if b.ind < 0.0:
					b.ind = 0.0
					b.iv = 0.0
				if b.ind > 1.0:
					b.ind = 1.0
					b.iv = 0.0
				var inZone: bool = absf(b.ind - b.zc) < zoneH / 2.0
				b.prog += (D.fill if inZone else -D.drain) * dt
				b.tugOff = 9.0 + (b.zc - 0.5) * 10.0
				if b.prog >= 1.0:
					_angler_finish(b, true)
				elif b.prog <= 0.0:
					_angler_finish(b, false)
			else:
				b.pt -= dt
				b.tugOff += (0.0 - b.tugOff) * minf(1.0, 4.0 * dt)
				if b.pt <= 0.0:
					b.phase = "wait"
					b.pt = randf_range(D.biteMin, D.biteMax)
		"farm":
			var nn: int = b.nn
			var tiles: Array = b.tiles
			var growDays: int = D.growDays
			b.dayT += dt
			if b.dayT >= D.dayLen:                       # the day tick: the only thing that grows a plant
				b.dayT -= D.dayLen
				b.day += 1
				for tl in tiles:
					if tl.s == 2 and tl.wet:
						tl.age += 1
						tl.wet = false
						if tl.age >= growDays:
							tl.s = 3
			b.actT += dt
			if b.target < 0 and b.actT >= D.actEvery:    # pick the best job, nearest breaks ties
				var best := -1
				var bestJ := -1
				var bestD := 1.0e9
				for i in nn:
					var j := _farm_job(tiles[i])
					var d: float = absf(_farm_tile_x(b, i) - b.fx)
					if j > bestJ or (j == bestJ and d < bestD):
						best = i
						bestJ = j
						bestD = d
				if bestJ >= 0:
					b.target = best
			b.walking = false
			if b.target >= 0:
				var tx := _farm_tile_x(b, b.target)
				var step: float = W * D.speed * dt
				if absf(tx - b.fx) <= step:
					b.fx = tx
					_farm_act(b, b.target)
					b.target = -1
					b.actT = 0.0
				else:
					b.dir = 1 if tx > b.fx else -1
					b.fx += b.dir * step
					b.walking = true
			var pops: Array = b.pops
			for i in range(pops.size() - 1, -1, -1):
				var p: Dictionary = pops[i]
				p.t -= dt
				p.y -= 18.0 * dt
				if p.t <= 0.0:
					pops.remove_at(i)
		"kitchen":
			var panX := W * 0.42
			var panW := W * 0.3
			var panY := GY - 8.0
			b.manualT -= dt
			b.verdictT -= dt
			b.flipT = maxf(0.0, b.flipT - dt)
			b.serveT += dt
			var side: Array = b.side
			var rate: float = D.rate
			var burn: float = D.burn
			if not b.patty:
				b.nextT -= dt
				if b.nextT <= 0.0:
					b.patty = true
					side[0] = 0.0
					side[1] = 0.0
					b.down = 0
					b.lateFlip = randf_range(0.0, D.slop)
					b.lateServe = randf_range(0.0, D.slop)
			else:
				var down: int = b.down
				if b.flipT <= 0.0:
					side[down] += rate * dt
				var mid: float = (D.sweetLo + D.sweetHi) / 2.0
				if b.manualT <= 0.0:                     # the autopilot: right idea, late hands
					if side[1 - down] == 0.0 and side[down] >= mid + b.lateFlip * rate:
						_kitchen_flip(b)
					elif side[1 - down] > 0.0 and side[down] >= mid + b.lateServe * rate:
						_kitchen_serve(b)
					elif side[down] >= burn + 0.05:
						_kitchen_serve(b)
				var sizzle: float = D.sizzle
				b.emit += dt * sizzle * clampf(side[down] * 2.0, 0.2, 1.0)
				while b.emit >= 1.0:                     # ch06's emitter: a fractional budget
					b.emit -= 1.0
					for p in b.parts:
						if p.life <= 0.0:
							var smoke: bool = side[down] > burn * 0.9
							p.x = panX + randf_range(-panW * 0.2, panW * 0.2)
							p.y = panY - 6.0
							p.vx = randf_range(-10.0, 10.0)
							p.vy = -randf_range(14.0, 28.0) if smoke else -randf_range(30.0, 60.0)
							p.life = 1.4 if smoke else 0.5
							p.smoke = smoke
							break
			for p in b.parts:
				if p.life > 0.0:
					p.life -= dt
					p.x += p.vx * dt
					p.y += p.vy * dt
					p.vy *= (1.0 - 1.5 * dt)
		"sokoban":
			b.stepT += dt
			b.testT -= dt
			var phase: String = b.phase
			if phase == "solve":
				if _sok_solved(b, b.s):
					b.phase = "won"
					b.holdT = 1.4
				elif b.stepT >= D.stepEvery:
					b.stepT = 0.0
					var plan: Array = b.plan
					if not b.plan_ok or plan.is_empty():
						plan = _sok_solve(b, b.s)
						b.plan = plan
						b.plan_ok = not plan.is_empty()
					if not b.plan_ok:
						_sok_pop(b)                      # stuck: back one move, think again
					else:
						var d: int = plan.pop_front()
						if not _sok_try(b, d):
							b.plan = []
							b.plan_ok = false
			elif phase == "won":
				b.holdT -= dt
				if b.holdT <= 0.0:
					b.phase = "rewind"
					b.stepT = 0.0
			elif phase == "rewind":
				if b.stepT >= 0.1:
					b.stepT = 0.0
					if (b.undo as Array).size() > 0:
						_sok_pop(b)
					else:
						b.phase = "solve"
						b.pushes = 0
						b.stepT = -0.8
			var k := Kit.smooth(14.0, dt)
			var st: Array = b.s
			var vis: Array = b.vis
			for i in vis.size():
				vis[i] += (st[i] - vis[i]) * k
		"needs":
			var needs: Array = b.needs
			var decay: Array = D.decay
			for i in 3:
				needs[i] = maxf(0.0, needs[i] - float(decay[i]) * dt)
			if b.sleepT > 0.0:
				b.sleepT -= dt
				var rest: float = D.rest
				needs[1] = minf(1.0, needs[1] + rest / 1.6 * dt)
			b.spinT = maxf(0.0, b.spinT - dt)
			b.crumbT -= dt
			b.heartT -= dt
			b.careT += dt                                # the owner's hand: an autopilot for the neediest bar
			if b.hand < 0 and b.careT >= D.careEvery:
				b.hand = _needs_lowest(b)
				b.handT = 0.0
				b.careT = 0.0
			if b.hand >= 0:
				b.handT += dt
				if b.handT >= 0.55:
					_needs_act(b, b.hand)
					b.hand = -1
		"emote":
			var nn: int = (D.sequence as Array).size()
			b.et += dt
			if b.et >= D.each:
				b.et -= D.each
				b.i = (b.i + 1) % nn
		"xylophone":
			var nn: int = b.nn
			var tune: Array = D.tune
			b.sinceBeep += dt
			b.stepT += dt
			var bpm: float = D.bpm
			var step := 60.0 / bpm
			if b.stepT >= step:                          # the music box turns one notch
				b.stepT -= step
				b.pos = (b.pos + 1) % tune.size()
				var k: int = tune[b.pos]
				if k >= 0 and k < nn:
					_xylo_strike(b, k, b.next)
					b.next = 1 - b.next
			var decay: float = D.decay
			var fade := exp(-decay * dt)
			var light: Array = b.light
			var shake: Array = b.shake
			for i in nn:
				light[i] *= fade
				shake[i] += dt
			for hm in b.ham:                             # two hammers on springs
				hm.vy += ((hm.rest - hm.y) * 300.0 - hm.vy * 12.0) * dt
				hm.y += hm.vy * dt
		"paint":
			var cols: int = b.cols
			var rows: int = b.rows
			var pal: Array = D.palette
			var doodle: float = D.doodle
			b.sinceP += dt
			b.fillT += dt
			b.colourT += dt
			b.ga += Kit.noise(t * 0.7) * 4.0 * dt        # the ghost brush wanders
			b.gx += cos(b.ga) * doodle * dt
			b.gy2 += sin(b.ga) * doodle * dt
			if b.gx < 0.0 or b.gx >= cols:
				b.gx = clampf(b.gx, 0.0, cols - 0.01)
				b.ga = PI - b.ga
			if b.gy2 < 0.0 or b.gy2 >= rows:
				b.gy2 = clampf(b.gy2, 0.0, rows - 0.01)
				b.ga = -b.ga
			if b.sinceP > 1.5:                           # it paints only while you are not
				_paint_brush(b, int(floorf(b.gx)), int(floorf(b.gy2)))
				if b.colourT >= 2.5:
					b.colourT = 0.0
					b.colour = randi_range(0, pal.size() - 2)
				if b.fillT >= D.fillEvery:
					b.fillT = 0.0
					_paint_fill(b, randi_range(0, cols - 1), randi_range(0, rows - 1))
		"snapshot":
			b.sinceP += dt
			b.flash = maxf(0.0, b.flash - 4.0 * dt)
			var wdt: float = 0.0 if b.frozen else dt     # the world's clock
			b.wdt = wdt
			b.uidt = dt                                  # the interface's clock, never zeroed
			var balls: Array = b.balls
			if b.frozen:
				b.frozenFor += dt
				if b.sinceP > 0.3:
					b.holdT -= dt
				if not b.manual:
					b.orbit += dt
					b.tfx = b.afx + sin(b.orbit) * W * 0.08
					b.tfy = b.afy + cos(b.orbit * 0.7) * H * 0.05
					_snap_clamp_focus(b)
				if b.holdT <= 0.0:
					b.frozen = false
					b.manual = false
					b.everyT = 0.0
			else:
				b.everyT += dt
				if b.everyT >= D.every:
					var ball: Dictionary = balls[randi_range(0, balls.size() - 1)]
					_snap_enter(b, ball.x, ball.y)
					b.afx = b.tfx
					b.afy = b.tfy
					b.orbit = 0.0
			var zoom: float = D.zoom
			b.z += ((zoom if b.frozen else 1.0) - b.z) * Kit.smooth(6.0, dt)
			if not b.frozen:
				b.tfx = W / 2.0
				b.tfy = H / 2.0
			b.fx += (b.tfx - b.fx) * Kit.smooth(8.0, dt)
			b.fy += (b.tfy - b.fy) * Kit.smooth(8.0, dt)
			var G: float = H * D.g
			var e: float = D.e
			for ball in balls:                           # the little scene, stepped by wdt
				ball.vy += G * wdt
				ball.x += ball.vx * wdt
				ball.y += ball.vy * wdt
				if ball.y > GY - ball.r:
					ball.y = GY - ball.r
					ball.vy = -absf(ball.vy) * e
					if absf(ball.vy) < 20.0:
						ball.vy = -H * 0.9
				if ball.x < W * 0.06 + ball.r:
					ball.x = W * 0.06 + ball.r
					ball.vx = absf(ball.vx)
				if ball.x > W * 0.94 - ball.r:
					ball.x = W * 0.94 - ball.r
					ball.vx = -absf(ball.vx)
			b.hopT += wdt
			b.mvy += G * wdt
			b.mx += b.mvx * wdt
			b.my += b.mvy * wdt
			if b.my > GY - 9.0:
				b.my = GY - 9.0
				b.mvy = 0.0
				if b.hopT > 1.1:
					b.hopT = 0.0
					b.mvy = -H * 0.7
			if b.mx < W * 0.1:
				b.mvx = absf(b.mvx)
			if b.mx > W * 0.9:
				b.mvx = -absf(b.mvx)
		"gems":
			var cols: int = b.cols
			var rows: int = b.rows
			var N := cols * rows
			var cs: float = b.cs
			var kinds: int = D.kinds
			var type: Array = b.type
			var yoff: Array = b.yoff
			var vy: Array = b.vy
			var clr: Array = b.clr
			b.hintT -= dt
			b.shuffleT -= dt
			if b.swapT > 0.0:                            # the swap animation, forward or back
				b.swapT -= dt
				if b.swapT <= 0.0:
					var sa: int = b.sa
					var sb: int = b.sb
					_gem_swap_types(b, sa, sb)
					if not b.back:
						var ac := sa % cols
						@warning_ignore("integer_division")   # whole rows
						var ar := (sa - ac) / cols
						var bc := sb % cols
						@warning_ignore("integer_division")   # whole rows
						var br := (sb - bc) / cols
						if not (_gem_run_at(b, ac, ar) or _gem_run_at(b, bc, br)):
							b.back = true
							b.swapT = D.swapTime
					else:
						b.back = false
			var clearing := false
			var empties := false
			for i in N:
				if clr[i] > 0.0:
					clr[i] -= dt
					clearing = true
					if clr[i] <= 0.0:
						clr[i] = 0.0
						type[i] = -1
				if type[i] < 0:
					empties = true
			if not clearing and empties:                 # gravity: compact each column, refill from above
				for c in cols:
					var w := rows - 1
					var r := rows - 1
					while r >= 0:
						var i := r * cols + c
						if type[i] >= 0:
							if w != r:
								var j := w * cols + c
								type[j] = type[i]
								yoff[j] = yoff[i] + (w - r) * cs
								vy[j] = vy[i]
								type[i] = -1
							w -= 1
						r -= 1
					r = w
					while r >= 0:
						var i := r * cols + c
						type[i] = randi_range(0, kinds - 1)
						yoff[i] = (w + 1) * cs
						vy[i] = 0.0
						r -= 1
			var falling := false
			var fall: float = D.fall
			for i in N:
				if yoff[i] > 0.0:
					vy[i] += fall * cs * dt
					yoff[i] -= vy[i] * dt
					falling = true
					if yoff[i] <= 0.0:
						yoff[i] = 0.0
						vy[i] = 0.0
			if not falling and not clearing and not empties and b.swapT <= 0.0:
				var nm := _gem_find_matches(b)
				if nm > 0:
					b.cascade += 1
					b.score += nm * 10 * b.cascade
				else:
					b.cascade = 0
					b.thinkT += dt
					if b.thinkT >= D.thinkEvery:         # the autopilot: any neighbour swap that matches
						b.thinkT = 0.0
						var cand: Array = []
						for r in rows:
							if cand.size() >= 254:
								break
							for c in cols:
								if cand.size() >= 254:
									break
								for d in 2:
									var c2 := c + (1 if d == 0 else 0)
									var r2 := r + (1 if d == 1 else 0)
									if c2 >= cols or r2 >= rows:
										continue
									var a := r * cols + c
									var bb := r2 * cols + c2
									_gem_swap_types(b, a, bb)
									var ok := _gem_run_at(b, c, r) or _gem_run_at(b, c2, r2)
									_gem_swap_types(b, a, bb)
									if ok:
										cand.append(a)
										cand.append(bb)
						if cand.is_empty():
							_gem_seed(b)
							b.shuffleT = 1.0
						else:
							@warning_ignore("integer_division")   # pairs
							var k: int = randi_range(0, cand.size() / 2 - 1) * 2
							_gem_start_swap(b, cand[k], cand[k + 1])
							b.hintT = 0.3
		"tetromino":
			var cols: int = b.cols
			var rows: int = b.rows
			if b.over > 0.0:
				b.over -= dt
				if b.over <= 0.0:
					var grid: Array = b.grid
					for i in cols * rows:
						grid[i] = 0
					b.lines = 0
					_tet_spawn(b)
			elif b.flashT > 0.0:
				b.flashT -= dt
				if b.flashT <= 0.0:
					_tet_clear(b)
			else:
				b.moveT += dt
				if b.moveT >= D.moveEvery:               # the autopilot nudges toward its wish
					b.moveT = 0.0
					if b.rot_i != b.wantRot:
						_tet_rotate(b)
					elif b.px < b.wantCol and _tet_fits(b, b.type, b.rot_i, b.px + 1, b.py):
						b.px += 1
					elif b.px > b.wantCol and _tet_fits(b, b.type, b.rot_i, b.px - 1, b.py):
						b.px -= 1
				b.dropT += dt
				if b.dropT >= D.dropEvery:
					b.dropT -= D.dropEvery
					if _tet_fits(b, b.type, b.rot_i, b.px, b.py + 1):
						b.py += 1
					else:
						_tet_lock(b)
		"rhythm":
			var pattern: Array = D.pattern
			var bpm: float = D.bpm
			var good: float = D.good
			var err: float = D.err
			b.song += dt
			b.sinceBeep += dt
			b.manualT -= dt
			b.fbT -= dt
			var song: float = b.song
			var horizon: float = (W - b.hitX) / b.pxPerS + 0.5
			var notes: Array = b.notes
			while b.lastNote < song + horizon:           # write the chart ahead of the eye
				b.lastNote += float(pattern[b.pi % pattern.size()]) * 60.0 / bpm
				b.pi += 1
				notes.append({ "t": b.lastNote, "j": -1, "jt": 0.0,
					"err": randf_range(-err, err) * (3.0 if randf() < 0.12 else 1.0) })
			for i in range(notes.size() - 1, -1, -1):
				var nt: Dictionary = notes[i]
				if nt.j < 0 and song - nt.t > good:      # drifted past: a miss
					_rhythm_judge(b, nt, song - nt.t)
				elif nt.j < 0 and b.manualT <= 0.0 and song >= nt.t + nt.err:   # the autopilot's press
					_rhythm_judge(b, nt, song - nt.t)
				if nt.j >= 0:
					nt.jt += dt
					if nt.jt > 0.7:
						notes.remove_at(i)
		"windup":
			var x0: float = b.x0
			b.pt += dt
			var phase: String = b.phase
			if phase == "idle" and b.pt >= D.every:
				_windup_wind(b)
			elif phase == "wind":
				b.puffT += dt
				if b.puffT > 0.08:
					b.puffT = 0.0
					_windup_puff(b, b.x - 12.0, GY - 3.0, 3.0, -randf_range(20.0, 50.0), -randf_range(5.0, 15.0), 0.5)
				if b.pt >= D.windup:
					b.phase = "launch"
					b.pt = 0.0
			elif phase == "launch" and b.pt >= D.delay:
				b.phase = "run"
				b.pt = 0.0
				var dustR: float = D.dustR
				for _i in 16:
					_windup_puff(b, b.x + randf_range(-16.0, 6.0), GY - randf_range(0.0, 14.0), H * dustR * randf_range(0.2, 0.7),
						-randf_range(10.0, 70.0), -randf_range(5.0, 35.0), randf_range(0.5, 1.1))
			elif phase == "run":
				b.x += W * D.speed * dt
				if b.x >= W * 0.9:
					b.x = W * 0.9
					b.phase = "hit"
					b.pt = 0.0
					for _i in 6:
						_windup_puff(b, b.x + 8.0, GY - randf_range(0.0, 24.0), 5.0, -randf_range(10.0, 30.0), -randf_range(10.0, 40.0), 0.5)
			elif phase == "hit" and b.pt >= 0.35:
				b.phase = "back"
				b.pt = 0.0
			elif phase == "back":
				b.x -= W * 0.4 * dt
				if b.x <= x0:
					b.x = x0
					b.phase = "idle"
					b.pt = 0.0
			for d in b.dust:                             # the dust: puffs that grow and fade
				if d.life > 0.0:
					d.life -= dt
					d.x += d.vx * dt
					d.y += d.vy * dt
					d.r += 8.0 * dt

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	Kit.stage(n, b)
	var D: Dictionary = b.D
	var W: float = b.w
	var H: float = b.h
	var GY: float = b.gy
	var origin: Vector2 = (b.rect as Rect2).position
	match b.id:
		"angler":
			var Y0 := H * 0.5
			var by0 := H * 0.16
			var bh := H * 0.62
			var bx := W * 0.9
			var DOCK := H * 0.4
			var phase: String = b.phase
			var bobX: float = b.bobX
			var pt: float = b.pt
			var zc: float = b.zc
			var zoneH: float = D.zoneH
			var wave := PackedVector2Array()             # the water
			for i in 41:
				var wx := i / 40.0 * W
				wave.append(Vector2(wx, _angler_surface(b, wx, t)))
			var fillp := PackedVector2Array(wave)
			fillp.append(Vector2(W, H))
			fillp.append(Vector2(0, H))
			n.draw_colored_polygon(fillp, Color(0.541, 0.851, 0.961, 0.13))
			n.draw_polyline(wave, Color(0.541, 0.851, 0.961, 0.6), 1.5)
			Kit.rect(n, Rect2(0, DOCK, W * 0.2, 5), Kit.BONE)   # the dock, the angler, the rod
			Kit.line(n, Vector2(W * 0.05, DOCK + 5), Vector2(W * 0.05, Y0 + 8), Kit.BONE, 2.0)
			Kit.line(n, Vector2(W * 0.16, DOCK + 5), Vector2(W * 0.16, Y0 + 8), Kit.BONE, 2.0)
			var tipX := W * 0.3
			var tipY := H * 0.16
			Kit.mote(n, b, Vector2(W * 0.1, DOCK - 9), -0.3 if phase == "fight" else 0.0)
			Kit.line(n, Vector2(W * 0.12, DOCK - 6), Vector2(tipX, tipY), Kit.BONE, 2.0)
			var by: float = _angler_surface(b, bobX, t) + b.tugOff
			var ctrl := Vector2((tipX + bobX) / 2.0, maxf(tipY, by) + (0.0 if phase == "fight" else 24.0))   # the line: a quadratic, sampled
			var line := PackedVector2Array()
			for i in 13:
				var k := i / 12.0
				line.append(Vector2(tipX, tipY) * (1.0 - k) * (1.0 - k) + ctrl * 2.0 * (1.0 - k) * k + Vector2(bobX, by) * k * k)
			n.draw_polyline(line, Color(0.91, 0.898, 0.957, 0.4), 1.0)
			var splashT: float = b.splashT
			if splashT > 0.0:
				var sx: float = b.splashX
				Kit.ring(n, Vector2(sx, _angler_surface(b, sx, t)), 4.0 + (0.5 - splashT) * 40.0, Color(0.541, 0.851, 0.961, splashT), 1.5)
			if phase == "fight":                         # the fish, on the line
				var fightT: float = b.fightT
				var fx := bobX + sin(fightT * 4.0) * W * 0.03
				var fy := Y0 + 16.0 + (1.0 - zc) * H * 0.28
				Kit.line(n, Vector2(bobX, by), Vector2(fx, fy), Color(0.961, 0.757, 0.412, 0.5))
				Kit.dot(n, Vector2(fx, fy), 5.0, Kit.TARGET)
				Kit.poly(n, [Vector2(fx - 4, fy), Vector2(fx - 11, fy - 5), Vector2(fx - 11, fy + 5)], Kit.TARGET)
				Kit.dot(n, Vector2(fx + 2, fy - 1.5), 1.2, Kit.NIGHT)
			elif phase == "bite":
				for i in 3:
					Kit.ring(n, Vector2(bobX, _angler_surface(b, bobX, t)), 6.0 + i * 6.0 + fmod(pt * 20.0, 6.0), Color(0.961, 0.541, 0.541, 0.35))
			Kit.dot(n, Vector2(bobX, by), 5.0, Kit.HOT)
			Kit.dot(n, Vector2(bobX, by + 2.5), 2.5, Kit.INK)
			# the tension bar: the zone (amber), the marker (blue), the catch (green)
			var dim: bool = phase != "fight"
			_box(n, Rect2(bx - 8, by0, 16, bh), Kit.DIM if dim else Kit.BONE)
			if not dim:
				var ind: float = b.ind
				var prog: float = b.prog
				Kit.rect(n, Rect2(bx - 7, by0 + (1.0 - zc - zoneH / 2.0) * bh, 14, zoneH * bh), Color(0.961, 0.757, 0.412, 0.4))
				Kit.rect(n, Rect2(bx - 10, by0 + (1.0 - ind) * bh - 3.0, 20, 6), Kit.MOVER)
				_box(n, Rect2(bx - 24, by0, 6, bh), Kit.DIM)
				Kit.rect(n, Rect2(bx - 24, by0 + (1.0 - prog) * bh, 6, prog * bh), Kit.GOOD)
				Kit.label(n, b, "zone", Vector2(bx, by0 - 6), Kit.TARGET, true)
				Kit.label(n, b, "catch", Vector2(bx - 21, by0 + bh + 12), Kit.GOOD, true)
			else:
				Kit.label(n, b, "tension", Vector2(bx, by0 - 6), Kit.DIM, true)
			var top: String
			var topc: Color = Kit.DIM
			if phase == "wait":
				top = "waiting… bite in %.1f s" % maxf(0.0, pt)
			elif phase == "bite":
				top = "BITE! press now (%.2f s)" % maxf(0.0, D.tug - pt)
				topc = Kit.HOT
			elif phase == "fight":
				top = "hold to reel" if b.manualT > 0.0 else "autopilot reels (lag %s s)" % _num(D.lag)
				topc = Kit.MOVER
			else:
				top = b.msg
			Kit.label(n, b, top, Vector2(W * 0.42, H - 22), topc, true)
			if b.msgT > 0.0 and phase != "done":
				Kit.label(n, b, b.msg, Vector2(bobX, by - 14), Kit.HOT, true)
			Kit.label(n, b, "caught %d · lost %d" % [b.caught, b.lost], Vector2(6, 14), Kit.DIM)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"farm":
			var nn: int = b.nn
			var tw: float = b.tw
			var th: float = b.th
			var x0: float = b.x0
			var tiles: Array = b.tiles
			var growDays: int = D.growDays
			var dayLen: float = D.dayLen
			var frac: float = b.dayT / dayLen
			var sun := sin(frac * PI)
			Kit.dot(n, Vector2(lerpf(W * 0.08, W * 0.92, frac), H * 0.34 - sun * H * 0.24), 7.0, Kit.TARGET)
			Kit.ground(n, b)
			for i in nn:                                 # the plots, one icon per state
				var tl: Dictionary = tiles[i]
				var x := x0 + i * tw + 2.0
				var cx := _farm_tile_x(b, i)
				var w := tw - 4.0
				var st: int = tl.s
				var age: int = tl.age
				var wet: bool = tl.wet
				Kit.rect(n, Rect2(x, GY - th, w, th), Color(0.353, 0.314, 0.51, 0.75) if wet else Color(0.549, 0.392, 0.235, 0.55))
				if st >= 1:
					for k in range(1, 4):
						Kit.line(n, Vector2(x + 3, GY - th + th * k / 4.0), Vector2(x + w - 3, GY - th + th * k / 4.0), Color(0, 0, 0, 0.35))
				if wet:
					Kit.dot(n, Vector2(x + w * 0.25, GY - th * 0.4), 1.8, Kit.MOVER)
					Kit.dot(n, Vector2(x + w * 0.7, GY - th * 0.7), 1.8, Kit.MOVER)
				if st == 2 or st == 3:
					var k: float = 1.0 if st == 3 else age / float(growDays)
					var top := GY - th * 0.5 - (6.0 + k * th * 1.7)
					if age == 0 and st == 2:
						Kit.dot(n, Vector2(cx, GY - th * 0.5), 2.5, Kit.BONE)
					else:
						Kit.line(n, Vector2(cx, GY - th * 0.5), Vector2(cx, top), Kit.GOOD, 2.0)
						Kit.dot(n, Vector2(cx - 4, top + (GY - th * 0.5 - top) * 0.45), 3.0, Kit.GOOD)
						Kit.dot(n, Vector2(cx + 4, top + (GY - th * 0.5 - top) * 0.25), 3.0, Kit.GOOD)
						if st == 3:
							Kit.dot(n, Vector2(cx, top), 4.5, Kit.TARGET)
						else:
							Kit.dot(n, Vector2(cx, top), 2.5, Kit.GOOD)
				Kit.label(n, b, ("%d/%d" % [age, growDays]) if st == 2 else FARM_NAMES[st], Vector2(cx, GY + 14), Kit.DIM, true)
			var fx: float = b.fx
			var bob: float = absf(sin(t * 12.0)) * 3.0 if b.walking else 0.0
			Kit.mote(n, b, Vector2(fx, GY - th - 12.0 - bob), 0.0 if b.dir > 0 else PI)
			if b.target >= 0:
				Kit.label(n, b, "%s →" % FARM_VERBS[_farm_job(tiles[b.target])], Vector2(fx, GY - th - 26.0), Kit.TARGET, true)
			for p in b.pops:
				Kit.label(n, b, p.txt, Vector2(p.x, p.y), p.c, true)
			var night := (1.0 - sun) * (1.0 - sun) * 0.35   # dusk creeps in as the sun sets
			if night > 0.01:
				Kit.rect(n, Rect2(0, 0, W, H), Color(0.078, 0.059, 0.196, night))
			Kit.label(n, b, "day %d · %d:00" % [b.day, int(floorf(frac * 24.0))], Vector2(6, 14), Kit.DIM)
			_label_right(n, b, "harvested %d" % b.harvested, Vector2(W - 6, 14), Kit.TARGET)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"kitchen":
			var panX := W * 0.42
			var panW := W * 0.3
			var panY := GY - 8.0
			var plateX := W * 0.85
			var TH := maxf(6.0, H * 0.038)               # the pan's thickness, so the scene keeps its height in the editor
			var side: Array = b.side
			var down: int = b.down
			var flipT: float = b.flipT
			var patty: bool = b.patty
			var verdictT: float = b.verdictT
			var sweetLo: float = D.sweetLo
			var sweetHi: float = D.sweetHi
			var burn: float = D.burn
			Kit.ground(n, b)
			Kit.rect(n, Rect2(panX - panW * 0.7, GY - 4, panW * 1.4, 4), Kit.BONE)   # the hob
			for i in 4:
				Kit.dot(n, Vector2(panX - panW * 0.45 + i * panW * 0.3, GY - 2), 1.5, Kit.HOT)
			_ellipse(n, Vector2(panX, panY), panW * 0.5, TH, Color(0.227, 0.208, 0.314))   # the pan
			Kit.line(n, Vector2(panX + panW * 0.5, panY), Vector2(panX + panW * 0.5 + W * 0.09, panY - TH), Kit.BONE, 3.0)
			_ellipse(n, Vector2(plateX, GY - 3), W * 0.09, TH * 0.6, Color(0.91, 0.898, 0.957, 0.85))   # the plate
			Kit.label(n, b, "plate", Vector2(plateX, GY - TH - 10), Kit.DIM, true)
			Kit.label(n, b, "flip", Vector2(panX, panY - TH * 2 - 24), Kit.DIM, true)
			if patty:                                    # the patty: colour = the side you can see
				var py := panY - TH
				var ang := 0.0
				if flipT > 0.0:
					var k := 1.0 - flipT / 0.35
					py -= sin(k * PI) * H * 0.18
					ang = k * PI
				_ellipse(n, Vector2(panX, py), panW * 0.22, TH * 0.9, _kitchen_colour(side[1 - down]), ang)
			elif verdictT > 0.0:
				_ellipse(n, Vector2(plateX, GY - 4 - TH * 0.7), panW * 0.22, TH * 0.8, _kitchen_colour(maxf(side[0], side[1])))
			for p in b.parts:
				if p.life > 0.0:
					var life: float = p.life
					if p.smoke:
						Kit.dot(n, Vector2(p.x, p.y), 3.0 + (1.4 - life) * 4.0, Color(0.627, 0.608, 0.706, maxf(0.0, life * 0.25)))
					else:
						Kit.dot(n, Vector2(p.x, p.y), 1.3, Color(0.961, 0.902, 0.784, maxf(0.0, life * 1.6)))
			var bw := W * 0.56                           # the two doneness bars
			var bx0 := W * 0.26
			for s in 2:
				var y := H * 0.14 + s * 16.0
				var sc := bw / 1.3
				var sv: float = side[s]
				Kit.rect(n, Rect2(bx0, y, bw, 8), INK_BG)
				Kit.rect(n, Rect2(bx0 + sweetLo * sc, y, (sweetHi - sweetLo) * sc, 8), Color(0.608, 0.886, 0.541, 0.35))
				Kit.rect(n, Rect2(bx0 + burn * sc, y, bw - burn * sc, 8), Color(0.961, 0.541, 0.541, 0.3))
				Kit.rect(n, Rect2(bx0, y, clampf(sv, 0.0, 1.3) * sc, 8), _kitchen_colour(sv))
				_label_right(n, b, ("▼ " if s == down and patty else "") + ("B " if s == 1 else "A ") + ("%.2f" % sv),
					Vector2(bx0 - 5, y + 8), Kit.INK if s == down else Kit.DIM)
			Kit.label(n, b, "sweet", Vector2(bx0 + (sweetLo + sweetHi) / 2.0 * bw / 1.3, H * 0.14 - 4), Kit.GOOD, true)
			Kit.label(n, b, "burnt", Vector2(bx0 + (burn + 0.1) * bw / 1.3, H * 0.14 - 4), Kit.HOT, true)
			if verdictT > 0.0:
				Kit.label(n, b, b.verdict, Vector2(plateX, GY - 30.0 - (1.2 - verdictT) * 14.0), b.verdictC, true)
			var score: Dictionary = b.score
			_label_right(n, b, "★ %d · raw %d · burnt %d" % [score.perfect, score.raw, score.burnt], Vector2(W - 6, 14), Kit.DIM)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"sokoban":
			var rows: int = b.rows
			var cols: int = b.cols
			var cs: float = b.cs
			var ox: float = b.ox
			var oy: float = b.oy
			var wall: Array = b.wall
			var goals: Array = b.goals
			var st: Array = b.s
			var vis: Array = b.vis
			var ice: bool = D.mode == "ice"
			var testT: float = b.testT
			for r in rows:
				for c in cols:
					var x := ox + c * cs
					var y := oy + r * cs
					if wall[r * cols + c]:
						Kit.rect(n, Rect2(x + 1, y + 1, cs - 2, cs - 2), Color(0.788, 0.769, 0.894, 0.22))
						_box(n, Rect2(x + 1, y + 1, cs - 2, cs - 2), Color(0.788, 0.769, 0.894, 0.5))
					elif ice:
						Kit.rect(n, Rect2(x + 1, y + 1, cs - 2, cs - 2), Color(0.541, 0.851, 0.961, 0.06))
			if testT > 0.0:
				var tc: Color = Color(0.608, 0.886, 0.541, testT * 0.8) if b.testOk else Color(0.961, 0.541, 0.541, testT * 0.8)
				Kit.rect(n, Rect2(ox + b.testX * cs + 2.0, oy + b.testY * cs + 2.0, cs - 4, cs - 4), tc)
			for g in goals:
				Kit.ring(n, Vector2(ox + ((g as Vector2i).x + 0.5) * cs, oy + ((g as Vector2i).y + 0.5) * cs), cs * 0.28, Kit.TARGET, 1.5)
			var i := 2
			while i < vis.size():
				var x: float = ox + vis[i] * cs
				var y: float = oy + vis[i + 1] * cs
				var onGoal := false
				for g in goals:
					if (g as Vector2i).x == st[i] and (g as Vector2i).y == st[i + 1]:
						onGoal = true
				Kit.rect(n, Rect2(x + cs * 0.15, y + cs * 0.15, cs * 0.7, cs * 0.7), Color(0.608, 0.886, 0.541, 0.8) if onGoal else Color(0.788, 0.769, 0.894, 0.8))
				Kit.line(n, Vector2(x + cs * 0.15, y + cs * 0.15), Vector2(x + cs * 0.85, y + cs * 0.85), Kit.NIGHT)
				Kit.line(n, Vector2(x + cs * 0.85, y + cs * 0.15), Vector2(x + cs * 0.15, y + cs * 0.85), Kit.NIGHT)
				i += 2
			var hd: Vector2i = SOK_DIRS[b.heading]
			Kit.mote(n, b, Vector2(ox + (vis[0] + 0.5) * cs, oy + (vis[1] + 0.5) * cs), atan2(float(hd.y), float(hd.x)), Kit.MOVER, cs * 0.28)
			var undo: Array = b.undo
			for k in mini(undo.size(), 24):              # the stack (its first 24 snapshots)
				Kit.rect(n, Rect2(6 + k * 4, 8, 3, 6), Kit.INK if k == undo.size() - 1 else Kit.DIM)
			Kit.label(n, b, "undo stack: %d · pushes %d" % [undo.size(), b.pushes], Vector2(6, 24), Kit.DIM)
			var phase: String = b.phase
			var status: String
			if phase == "won":
				status = "solved!"
			elif phase == "rewind":
				status = "rewind: pop, pop, pop…"
			else:
				status = ("solver: %d moves left" % (b.plan as Array).size()) if b.plan_ok else "solver thinking…"
				if ice:
					status += " · ice"
			_label_right(n, b, status, Vector2(W - 6, 14), Kit.GOOD if phase == "won" else Kit.DIM)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"needs":
			var needs: Array = b.needs
			var rowY: Array = b.rowY
			var iconX: float = b.iconX
			var barX: float = b.barX
			var barW: float = b.barW
			var px: float = b.px
			var py: float = b.py
			var decay: Array = D.decay
			var happy: float = D.happy
			var low_t: float = D.low
			var sleepT: float = b.sleepT
			var spinT: float = b.spinT
			var heartT: float = b.heartT
			var crumbT: float = b.crumbT
			Kit.ground(n, b)
			if b.hand >= 0:                              # the owner's hand, on its way to a bar
				var hand: int = b.hand
				var k := _ease(b.handT / 0.5)
				var hx := lerpf(W * 0.5, iconX, k)
				var hy := lerpf(-10.0, rowY[hand], k)
				Kit.ring(n, Vector2(hx, hy), 7.0, Color(0.91, 0.898, 0.957, 0.7), 1.5)
				Kit.dot(n, Vector2(hx, hy), 2.0, Kit.INK)
			var m := _needs_mood(b)
			var low := _needs_lowest(b)
			var yoff := 0.0                              # the idle, chosen by mood
			var ang := 0.0
			var sx := 1.0
			var sy := 1.0
			if sleepT > 0.0:
				ang = -1.2
				yoff = 6.0
			elif spinT > 0.0:
				ang = (0.5 - spinT) / 0.5 * TAU
			elif m == "happy":
				yoff = -absf(sin(t * 6.0)) * 10.0
				ang = sin(t * 6.0) * 0.2
			elif m == "okay":
				sy = 1.0 + sin(t * 3.0) * 0.04
				sx = 1.0 - sin(t * 3.0) * 0.03
			else:
				sy = 0.85
				sx = 1.12
				yoff = 3.0
				ang = sin(t * 1.5) * 0.15 + 0.25
			_ellipse(n, Vector2(px, GY - 2), 16.0, 4.0, Color(0, 0, 0, 0.35))
			_mote_xf(n, b, Vector2(px, py + yoff), ang, Color(0.498, 0.69, 0.784) if m == "grumpy" else Kit.MOVER, 12.0, Vector2(sx, sy))
			if sleepT > 0.0:
				for i in 3:
					Kit.label(n, b, "z", Vector2(px + 16 + i * 7, py - 16 - i * 8 - fmod(t * 20.0, 8.0)), Kit.MAGIC)
			elif m != "happy" or heartT > 0.0:           # the thought bubble: the lowest need, or a heart
				var bx := px + 22.0
				var by := py - 34.0
				Kit.dot(n, Vector2(px + 12, py - 16), 2.0, Kit.BONE)
				Kit.dot(n, Vector2(px + 17, py - 24), 3.0, Kit.BONE)
				Kit.ring(n, Vector2(bx, by), 12.0, Kit.BONE, 1.0)
				if heartT > 0.0:
					_needs_icon(n, 2, bx, by, Kit.HOT)
				else:
					_needs_icon(n, low, bx, by, Kit.HOT if m == "grumpy" else Kit.TARGET)
			if crumbT > 0.0:
				Kit.dot(n, Vector2(lerpf(iconX, px, 1.0 - crumbT / 0.6), lerpf(rowY[0], py, 1.0 - crumbT / 0.6)), 3.0, Kit.TARGET)
			for i in 3:                                  # the bars
				var y: float = rowY[i]
				var v: float = needs[i]
				var c: Color = Kit.GOOD if v >= happy else (Kit.TARGET if v >= low_t else Kit.HOT)
				_needs_icon(n, i, iconX, y, Kit.INK if i == low else Kit.BONE)
				Kit.rect(n, Rect2(barX, y - 5, barW, 10), INK_BG)
				Kit.rect(n, Rect2(barX, y - 5, barW * v, 10), c)
				Kit.line(n, Vector2(barX + barW * happy, y - 7), Vector2(barX + barW * happy, y + 7), Kit.DIM)
				Kit.line(n, Vector2(barX + barW * low_t, y - 7), Vector2(barX + barW * low_t, y + 7), Kit.DIM)
				Kit.label(n, b, "%s  −%s/s" % [NEED_NAMES[i], _num(float(decay[i]))], Vector2(barX, y + 16), Kit.DIM)
			var moodc: Color = Kit.HOT if m == "grumpy" else (Kit.GOOD if m == "happy" else Kit.DIM)
			Kit.label(n, b, "mood: %s  (lowest: %s %.2f)" % ["asleep" if sleepT > 0.0 else m, NEED_NAMES[low], float(needs[low])], Vector2(6, 14), moodc)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"emote":
			var seq: Array = D.sequence
			var nn: int = seq.size()
			var SZ: float = b.SZ
			var cx: float = b.cx
			var cy: float = b.cy
			var i: int = b.i
			var et: float = b.et
			var each: float = D.each
			var pop: float = D.pop
			var overshoot: float = D.overshoot
			var nm: String = seq[i]
			var k := et / each
			var s: float = overshoot * _ease(et / pop) if et < pop else lerpf(overshoot, 1.0, _ease((et - pop) / pop))   # the pop-in
			var alpha := clampf((each - et) / 0.25, 0.0, 1.0)
			Kit.ground(n, b)
			var jx := 0.0                                # the body's reaction
			var yoff := 0.0
			var ang := 0.0
			var sx := 1.0
			var sy := 1.0
			if nm == "sweat":
				jx = sin(t * 40.0) * 1.2
			elif nm == "blush":
				ang = -0.5
				jx = -3.0
			elif nm == "tears":
				yoff = 4.0
				sy = 0.9
				sx = 1.08
			elif nm == "anger":
				jx = sin(t * 60.0) * 2.0
				ang = 0.15
			elif nm == "idea":
				yoff = -absf(sin(clampf(et / 0.5, 0.0, 1.0) * PI)) * 14.0
			elif nm == "sparkle" or nm == "heart":
				yoff = -absf(sin(t * 8.0)) * 6.0
				ang = sin(t * 8.0) * 0.15
			_mote_xf(n, b, Vector2(cx + jx, cy + yoff), ang, Kit.MOVER, 12.0, Vector2(sx * SZ, sy * SZ))
			n.draw_set_transform(origin + Vector2(cx + jx, cy + yoff - 28.0 * SZ), 0.0, Vector2(s * SZ, s * SZ))
			_emote(n, b, nm, k, alpha)
			n.draw_set_transform(origin, 0.0, Vector2.ONE)
			var stripW := minf(W * 0.9, nn * 52.0)      # the schedule strip
			var sx0 := (W - stripW) / 2.0
			for j in nn:
				var x := sx0 + (j + 0.5) * stripW / nn
				Kit.label(n, b, seq[j], Vector2(x, H * 0.16), Kit.INK if j == i else Kit.DIM, true)
				if j == i:
					Kit.rect(n, Rect2(x - stripW / nn * 0.4, H * 0.16 + 4, stripW / nn * 0.8 * k, 2), Kit.TARGET)
			Kit.label(n, b, "i = %d · scale %.2f · alpha %.2f" % [i, s, alpha], Vector2(W / 2.0, H * 0.09), Kit.DIM, true)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"xylophone":
			var nn: int = b.nn
			var kw: float = b.kw
			var x0: float = b.x0
			var cy: float = b.cy
			var scale: Array = D.scale
			var tune: Array = D.tune
			var light: Array = b.light
			var shake: Array = b.shake
			var pos: int = b.pos
			var armed: bool = b.armed
			var bpm: float = D.bpm
			Kit.line(n, Vector2(x0 - 6, cy - H * 0.13), Vector2(x0 + nn * kw + 6, cy - H * 0.13), Kit.BONE, 2.0)   # the rails
			Kit.line(n, Vector2(x0 - 6, cy + H * 0.13), Vector2(x0 + nn * kw + 6, cy + H * 0.13), Kit.BONE, 2.0)
			for i in nn:
				var top := _xkey_top(b, i)
				var h := (cy - top) * 2.0
				var x := x0 + i * kw + 2.0
				var w := kw - 4.0
				var li: float = light[i]
				var wob: float = sin(shake[i] * 40.0) * 3.0 * li
				Kit.rect(n, Rect2(x, top + wob, w, h), _hsl(roundf(i / float(nn) * 300.0) / 360.0, 0.65, 0.58))
				if li > 0.02:
					Kit.rect(n, Rect2(x, top + wob, w, h), Color(1, 1, 1, li * 0.6))
				Kit.dot(n, Vector2(x + w / 2.0, cy - H * 0.13 + wob), 1.8, Kit.NIGHT)
				Kit.dot(n, Vector2(x + w / 2.0, cy + H * 0.13 + wob), 1.8, Kit.NIGHT)
				Kit.label(n, b, "%d" % roundi(float(scale[i])), Vector2(x + w / 2.0, cy + h / 2.0 + 12.0), Kit.DIM, true)
			for hm in b.ham:                             # two hammers on springs
				Kit.line(n, Vector2(hm.x, hm.y), Vector2(hm.x, hm.y - 26.0), Kit.BONE, 2.0)
				Kit.dot(n, Vector2(hm.x, hm.y), 5.0, Kit.BONE)
			var tw := minf(W * 0.8, tune.size() * 12.0)   # the tune, as a piano roll
			var tx0 := (W - tw) / 2.0
			for j in tune.size():
				var k: int = tune[j]
				var x := tx0 + (j + 0.5) * tw / tune.size()
				if k < 0:
					Kit.dot(n, Vector2(x, H * 0.14), 1.0, Kit.DIM)
				else:
					Kit.rect(n, Rect2(x - 3, H * 0.14 - k * 2.0, 6, 3), Kit.INK if j == pos else Color(0.91, 0.898, 0.957, 0.35))
			Kit.label(n, b, ("♪ %s bpm" % _num(bpm)) if armed else ("press a key to unmute · %s bpm" % _num(bpm)), Vector2(W / 2.0, H * 0.09 - 6), Kit.TARGET if armed else Kit.DIM, true)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"paint":
			var cols: int = b.cols
			var rows: int = b.rows
			var palc: Array = b.palc
			var sw: float = b.sw
			var palX: float = b.palX
			var palY: float = b.palY
			var cx0: float = b.cx0
			var cy0: float = b.cy0
			var cs: float = b.cs
			var tx0: float = b.tx0
			var tileW: float = b.tileW
			var ps: float = b.ps
			var stride: int = b.stride
			var colour: int = b.colour
			var tool: String = b.tool
			var brush: int = D.brush
			for k in palc.size():                        # the palette column
				var py := palY + k * (sw + 4.0)
				Kit.rect(n, Rect2(palX, py, sw, sw), palc[k])
				if k == colour:
					_box(n, Rect2(palX - 2, py - 2, sw + 4, sw + 4), Kit.INK, 1.5)
			var ty := palY + palc.size() * (sw + 4.0)
			Kit.dot(n, Vector2(palX + sw / 2.0, ty + sw / 2.0), sw * 0.28, Kit.INK if tool == "brush" else Kit.DIM)
			Kit.poly(n, [Vector2(palX + sw * 0.2, ty + sw + 4 + sw * 0.35), Vector2(palX + sw * 0.8, ty + sw + 4 + sw * 0.35),
				Vector2(palX + sw * 0.7, ty + sw + 4 + sw * 0.85), Vector2(palX + sw * 0.3, ty + sw + 4 + sw * 0.85)], Kit.INK if tool == "fill" else Kit.DIM)
			Kit.label(n, b, "fill", Vector2(palX + sw / 2.0, ty + sw * 2 + 18), Kit.INK if tool == "fill" else Kit.DIM, true)
			_paint_grid(n, b, cx0, cy0, cs, 1)           # the canvas
			_box(n, Rect2(cx0, cy0, cols * cs, rows * cs), Kit.BONE)
			if b.sinceP > 1.5:
				Kit.ring(n, Vector2(cx0 + (floorf(b.gx) + 0.5) * cs, cy0 + (floorf(b.gy2) + 0.5) * cs), cs * brush * 0.7 + 2.0, palc[colour], 1.5)
			for ty2 in 2:                                # the texture: the grid, tiled
				for tx2 in 2:
					_paint_grid(n, b, tx0 + tx2 * tileW, cy0 + ty2 * rows * ps, ps * stride, stride)
			_box(n, Rect2(tx0, cy0, tileW * 2.0, rows * ps * 2.0), Kit.DIM)
			Kit.label(n, b, "tiled ×4", Vector2(tx0 + tileW, cy0 + rows * ps * 2.0 + 12.0), Kit.DIM, true)
			Kit.label(n, b, "%d×%d · brush %d · tool %s" % [cols, rows, brush, tool], Vector2(cx0 + cols * cs / 2.0, cy0 - 5.0), Kit.DIM, true)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"snapshot":
			var frozen: bool = b.frozen
			var z: float = b.z
			var fx: float = b.fx
			var fy: float = b.fy
			var filter: String = D.filter
			var frame: String = D.frame
			var frozenFor: float = b.frozenFor
			var flash: float = b.flash
			var mx: float = b.mx
			var my: float = b.my
			# the camera: scale about the focus — translate(W/2, H/2) · scale(z) · translate(−focus)
			var cam := Vector2(W / 2.0, H / 2.0) - Vector2(fx, fy) * z
			n.draw_set_transform(origin + cam, 0.0, Vector2(z, z))
			Kit.ground(n, b)
			Kit.line(n, Vector2(W * 0.06, 0), Vector2(W * 0.06, GY), Kit.BONE)
			Kit.line(n, Vector2(W * 0.94, 0), Vector2(W * 0.94, GY), Kit.BONE)
			for i in 3:
				var x := W * (0.25 + i * 0.25)
				Kit.line(n, Vector2(x, GY), Vector2(x, GY - H * 0.2), Kit.BONE, 2.0)
				Kit.poly(n, [Vector2(x - 8, GY - H * 0.18), Vector2(x + 8, GY - H * 0.18), Vector2(x, GY - H * 0.32)], Kit.GOOD)
			for ball in b.balls:
				Kit.dot(n, Vector2(ball.x, ball.y), ball.r, ball.c)
			n.draw_set_transform(origin, 0.0, Vector2.ONE)
			# the mote and the focus ring go through the same camera by arithmetic
			# (Kit.mote sets its own transform, so it cannot sit inside ours)
			Kit.mote(n, b, cam + Vector2(mx, my) * z, PI if b.mvx < 0.0 else 0.0, Kit.MOVER, 8.0 * z)
			if frozen:
				Kit.ring(n, cam + Vector2(fx, fy) * z, 6.0 * z, Color(0.961, 0.757, 0.412, 0.7), 1.0)
			# the grade: the web multiplies a colour rect over the frame. Godot 2D
			# has no per-draw multiply blend without a material, so the tint is a
			# translucent overlay at a lower alpha — the same hue, a softer darkening.
			if frozen and filter == "sepia":
				Kit.rect(n, Rect2(0, 0, W, H), Color(1.0, 0.804, 0.549, 0.3))
				Kit.rect(n, Rect2(0, 0, W, H), Color(0.471, 0.314, 0.118, 0.12))
			elif frozen and filter == "night":
				Kit.rect(n, Rect2(0, 0, W, H), Color(0.275, 0.353, 0.824, 0.4))
			if frozen:                                   # the frame belongs to the ui clock
				if frame == "polaroid":
					var m := W * 0.05
					var c := Color(0.941, 0.925, 0.902, 0.92)
					Kit.rect(n, Rect2(0, 0, W, m), c)
					Kit.rect(n, Rect2(0, 0, m, H), c)
					Kit.rect(n, Rect2(W - m, 0, m, H), c)
					Kit.rect(n, Rect2(0, H - m * 3, W, m * 3), c)
					Kit.label(n, b, "frozen %.1f s · %s" % [frozenFor, filter], Vector2(W / 2.0, H - m * 1.3), Color(0.235, 0.196, 0.157, 0.7), true)
				else:
					var m := 10.0 + sin(t * 3.0) * 2.0
					var L := 14.0
					for corner in [[m, m, 1.0, 1.0], [W - m, m, -1.0, 1.0], [m, H - m, 1.0, -1.0], [W - m, H - m, -1.0, -1.0]]:
						var cx: float = corner[0]
						var cy: float = corner[1]
						Kit.line(n, Vector2(cx, cy), Vector2(cx + L * corner[2], cy), Kit.INK, 2.0)
						Kit.line(n, Vector2(cx, cy), Vector2(cx, cy + L * corner[3]), Kit.INK, 2.0)
					for i in range(1, 3):
						Kit.line(n, Vector2(W * i / 3.0, 0), Vector2(W * i / 3.0, H), Kit.DIM)
						Kit.line(n, Vector2(0, H * i / 3.0), Vector2(W, H * i / 3.0), Kit.DIM)
					Kit.label(n, b, "● photo · zoom %.2f · %s" % [z, filter], Vector2(W / 2.0, 24), Kit.TARGET, true)
			if flash > 0.0:
				Kit.rect(n, Rect2(0, 0, W, H), Color(1, 1, 1, flash * 0.8))
			var onCard: bool = frozen and frame == "polaroid"   # captions over the cream border need dark ink
			var status := "world dt %d ms · ui dt %d ms" % [roundi(b.wdt * 1000.0), roundi(b.uidt * 1000.0)]
			if frozen:
				status += " · frozen %.1f s (unscaled)" % frozenFor
			Kit.label(n, b, status, Vector2(6, H - 22), Color(0.549, 0.235, 0.196, 0.9) if onCard else (Kit.HOT if frozen else Kit.DIM))
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), Color(0.235, 0.196, 0.157, 0.75) if onCard else FAINT, true)
		"gems":
			var cols: int = b.cols
			var rows: int = b.rows
			var cs: float = b.cs
			var ox: float = b.ox
			var oy: float = b.oy
			var type: Array = b.type
			var yoff: Array = b.yoff
			var clr: Array = b.clr
			var sel: int = b.sel
			var sa: int = b.sa
			var sb: int = b.sb
			var swapT: float = b.swapT
			var swapTime: float = D.swapTime
			var clearTime: float = D.clearTime
			var hintT: float = b.hintT
			# the web clips to the board; here a gem is skipped while its centre is
			# still above the top edge (the falling-in is otherwise identical)
			for r in rows:
				for c in cols:
					var i := r * cols + c
					var k: int = type[i]
					if k < 0:
						continue
					var x: float = ox + (c + 0.5) * cs
					var y: float = oy + (r + 0.5) * cs - yoff[i]
					if swapT > 0.0 and (i == sa or i == sb):   # the two swapping gems slide past each other
						var o := sb if i == sa else sa
						var kk := 1.0 - swapT / swapTime
						@warning_ignore("integer_division")   # the other gem's row
						var orow := o / cols
						x = lerpf(x, ox + (o % cols + 0.5) * cs, _ease(kk))
						y = lerpf(y, oy + (orow + 0.5) * cs, _ease(kk))
					if y < oy:
						continue
					var ci: float = clr[i]
					var s: float = cs * 0.36 * (ci / clearTime if ci > 0.0 else 1.0)
					var col: Color = GEM_COL[k % GEM_COL.size()]
					if k == 0:
						Kit.dot(n, Vector2(x, y), s, col)
					elif k == 1:
						Kit.poly(n, [Vector2(x, y - s), Vector2(x + s, y), Vector2(x, y + s), Vector2(x - s, y)], col)
					elif k == 2:
						Kit.rect(n, Rect2(x - s * 0.85, y - s * 0.85, s * 1.7, s * 1.7), col)
					elif k == 3:
						Kit.poly(n, [Vector2(x, y - s), Vector2(x + s, y + s * 0.8), Vector2(x - s, y + s * 0.8)], col)
					else:
						Kit.poly(n, [Vector2(x + s, y), Vector2(x + s * 0.5, y + s * 0.87), Vector2(x - s * 0.5, y + s * 0.87),
							Vector2(x - s, y), Vector2(x - s * 0.5, y - s * 0.87), Vector2(x + s * 0.5, y - s * 0.87)], col)
					if ci > 0.0:
						Kit.ring(n, Vector2(x, y), cs * 0.5 * (1.0 - ci / clearTime) + 2.0, Color(1, 1, 1, ci / clearTime), 1.5)
					if i == sel or (hintT > 0.0 and (i == sa or i == sb)):
						Kit.ring(n, Vector2(x, y), cs * 0.45, Kit.INK, 1.5)
			_box(n, Rect2(ox, oy, cols * cs, rows * cs), Kit.BONE)
			Kit.label(n, b, "score %d" % b.score, Vector2(6, 14), Kit.TARGET)
			if b.cascade > 1:
				_label_right(n, b, "cascade ×%d" % b.cascade, Vector2(W - 6, 14), Kit.GOOD)
			if b.shuffleT > 0.0:
				_label_right(n, b, "no moves — shuffle", Vector2(W - 6, 14), Kit.HOT)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"tetromino":
			var cols: int = b.cols
			var rows: int = b.rows
			var cs: float = b.cs
			var ox: float = b.ox
			var oy: float = b.oy
			var grid: Array = b.grid
			var full: Array = b.full
			var flashT: float = b.flashT
			var over: float = b.over
			var dropT: float = b.dropT
			var dropEvery: float = D.dropEvery
			var type: int = b.type
			var px: int = b.px
			var py: int = b.py
			_box(n, Rect2(ox, oy, cols * cs, rows * cs), Kit.BONE)
			for r in rows:
				for c in cols:
					var v: int = grid[r * cols + c]
					if v == 0:
						continue
					var col: Color = Color(1, 1, 1, 0.5 + sin(flashT * 40.0) * 0.5) if (full[r] == 1 and flashT > 0.0) else TET_COL[v - 1]
					Kit.rect(n, Rect2(ox + c * cs + 1, oy + r * cs + 1, cs - 2, cs - 2), col)
			if over <= 0.0 and flashT <= 0.0:
				var gy := py
				while _tet_fits(b, type, b.rot_i, px, gy + 1):   # the ghost: where it lands
					gy += 1
				var cells: Array = b.rot[type][b.rot_i]
				for c in cells:
					var cv: Vector2i = c
					var gx := ox + (px + cv.x) * cs
					var gyy := oy + (gy + cv.y) * cs
					if gy + cv.y >= 0:
						_box(n, Rect2(gx + 1, gyy + 1, cs - 2, cs - 2), Kit.DIM)
					var y := oy + (py + cv.y) * cs
					if py + cv.y >= 0:
						Kit.rect(n, Rect2(gx + 1, y + 1, cs - 2, cs - 2), TET_COL[type])
			var bx := ox + cols * cs + 8.0               # the tick timer, drawn
			Kit.rect(n, Rect2(bx, oy, 4, rows * cs), INK_BG)
			Kit.rect(n, Rect2(bx, oy + rows * cs * (1.0 - dropT / dropEvery), 4, rows * cs * dropT / dropEvery), Kit.TARGET)
			Kit.label(n, b, "tick", Vector2(bx + 8, oy + 10), Kit.DIM)
			Kit.label(n, b, "%s s" % _num(dropEvery), Vector2(bx + 8, oy + 22), Kit.DIM)
			_label_right(n, b, "lines %d" % b.lines, Vector2(ox - 8, oy + 10), Kit.GOOD)
			if over > 0.0:
				Kit.label(n, b, "top out — reset", Vector2(W / 2.0, oy - 6), Kit.HOT, true)
			elif flashT > 0.0:
				Kit.label(n, b, "line clear!", Vector2(W / 2.0, oy - 6), Kit.INK, true)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"rhythm":
			var hitX: float = b.hitX
			var laneY: float = b.laneY
			var pxPerS: float = b.pxPerS
			var song: float = b.song
			var bpm: float = D.bpm
			var good: float = D.good
			var perfect: float = D.perfect
			var err: float = D.err
			var fbT: float = b.fbT
			var fbD: float = b.fbD
			var combo: int = b.combo
			var manualT: float = b.manualT
			var horizon: float = (W - hitX) / pxPerS + 0.5
			var beat := 60.0 / bpm
			var phase := fmod(song / beat, 1.0)
			Kit.rect(n, Rect2(0, laneY - 16, W, 32), Color(0.91, 0.898, 0.957, 0.05))   # the highway and the windows
			Kit.rect(n, Rect2(hitX - good * pxPerS, laneY - 16, good * pxPerS * 2.0, 32), Color(0.961, 0.757, 0.412, 0.18))
			Kit.rect(n, Rect2(hitX - perfect * pxPerS, laneY - 16, perfect * pxPerS * 2.0, 32), Color(0.608, 0.886, 0.541, 0.3))
			Kit.line(n, Vector2(hitX, laneY - 22), Vector2(hitX, laneY + 22), Kit.INK, 2.0)
			var bi := ceili((song - 1.0) / beat)
			while bi * beat < song + horizon:
				var x := hitX + (bi * beat - song) * pxPerS
				if x > -5.0 and x < W + 5.0:
					Kit.line(n, Vector2(x, laneY + 18), Vector2(x, laneY + 24), Kit.DIM)
				bi += 1
			for nt in b.notes:
				var x: float = hitX + (nt.t - song) * pxPerS
				if x < -20.0 or x > W + 20.0:
					continue
				var j: int = nt.j
				if j < 0:
					Kit.dot(n, Vector2(x, laneY), 8.0, Kit.MOVER)
				else:
					var k: float = 1.0 - nt.jt / 0.7
					Kit.dot(n, Vector2(x, laneY - (0.0 if j == 2 else (1.0 - k) * 30.0)), 8.0 * (k if j == 2 else 1.0), _a(JUDGE_COL[j], k))
			Kit.dot(n, Vector2(W * 0.9, H * 0.2), 8.0 + (1.0 - phase) * 8.0, Color(0.961, 0.757, 0.412, 0.25 + (1.0 - phase) * 0.5))   # the beat lamp
			Kit.label(n, b, "%s bpm" % _num(bpm), Vector2(W * 0.9, H * 0.2 + 26), Kit.DIM, true)
			if fbT > 0.0:
				var s: float = (1.4 - _ease((0.6 - fbT) / 0.15) * 0.4) if fbT > 0.45 else 1.0
				n.draw_set_transform(origin + Vector2(hitX, laneY - 36.0), 0.0, Vector2(s, s))
				Kit.label(n, b, b.fb, Vector2.ZERO, b.fbC, true)
				n.draw_set_transform(origin, 0.0, Vector2.ONE)
				if b.fb != "MISS" or absf(fbD) < 1.0:
					Kit.label(n, b, "%s%d ms %s" % ["+" if fbD > 0.0 else "", roundi(fbD * 1000.0), "late" if fbD > 0.0 else "early"], Vector2(hitX, laneY - 50), Kit.DIM, true)
			Kit.label(n, b, "combo %d" % combo, Vector2(6, 16), Kit.GOOD if combo >= 10 else Kit.INK)
			Kit.label(n, b, "best %d" % b.best, Vector2(6, 28), Kit.DIM)
			_label_right(n, b, "your hands" if manualT > 0.0 else "autopilot ± %d ms" % roundi(err * 1000.0), Vector2(W - 6, 16), Kit.TARGET if manualT > 0.0 else Kit.DIM)
			Kit.label(n, b, "%s%d ms · good ≤ %d ms" % [D.label, roundi(perfect * 1000.0), roundi(good * 1000.0)], Vector2(W / 2.0, H - 8.0), FAINT, true)
		"windup":
			var x: float = b.x
			var y: float = b.y
			var phase: String = b.phase
			var pt: float = b.pt
			var windup: float = D.windup
			var spin: float = D.spin
			Kit.ground(n, b)
			for d in b.dust:                             # the dust: puffs that grow and fade
				if d.life > 0.0:
					Kit.dot(n, Vector2(d.x, d.y), d.r, Color(0.788, 0.769, 0.894, maxf(0.0, d.life * 0.28)))
			var sx := 1.0
			var sy := 1.0
			var ang := 0.0
			var jx := 0.0
			var blur := false
			if phase == "wind" or phase == "launch":
				ang = -0.4
				jx = sin(t * 50.0) * 2.0
				sx = 0.92
				sy = 1.08
				blur = true
			elif phase == "run":
				sx = 1.45
				sy = 0.7
				blur = true
				for i in 4:
					Kit.line(n, Vector2(x - 20 - i * 9, y - 6 + i * 4), Vector2(x - 44 - i * 9, y - 6 + i * 4), Color(0.91, 0.898, 0.957, 0.4 - i * 0.08), 1.5)
			elif phase == "hit":
				sx = 0.55
				sy = 1.45
				for i in 3:
					Kit.dot(n, Vector2(x + cos(t * 9.0 + i * 2.1) * 16.0, y - 18.0 + sin(t * 9.0 + i * 2.1) * 6.0), 2.0, Kit.TARGET)
			elif phase == "back":
				ang = PI
				sy = 1.0 + absf(sin(t * 14.0)) * 0.08
			if blur:                                     # the leg blur: a fan of faint lines
				_ellipse(n, Vector2(x + jx, GY - 6), 14.0, 7.0, Color(0.541, 0.851, 0.961, 0.12))
				for i in 8:
					var a := t * spin + i / 8.0 * TAU
					Kit.line(n, Vector2(x + jx, y + 6), Vector2(x + jx + cos(a) * 11.0, GY - 1.0 + sin(a) * 3.0), Color(0.541, 0.851, 0.961, 0.35), 2.0)
			else:
				Kit.line(n, Vector2(x - 4, y + 7), Vector2(x - 5, GY), Kit.MOVER, 2.0)
				Kit.line(n, Vector2(x + 4, y + 7), Vector2(x + 5, GY), Kit.MOVER, 2.0)
			_mote_xf(n, b, Vector2(x + jx, y - (sy - 1.0) * 9.0), ang, Kit.MOVER, 8.0, Vector2(sx, sy))
			if phase == "wind":                          # the wind-up timer over the head
				Kit.rect(n, Rect2(x - 16, y - 26, 32, 5), Color(0.91, 0.898, 0.957, 0.1))
				Kit.rect(n, Rect2(x - 16, y - 26, 32.0 * clampf(pt / windup, 0.0, 1.0), 5), Kit.TARGET)
				Kit.label(n, b, "wind %.2f / %s s" % [pt, _num(windup)], Vector2(x, y - 30), Kit.TARGET, true)
			elif phase == "launch":
				Kit.label(n, b, "delay %s s…" % _num(D.delay), Vector2(x, y - 30), Kit.HOT, true)
			elif phase == "run":
				Kit.label(n, b, "x += %s·W·dt" % _num(D.speed), Vector2(x, y - 30), Kit.MOVER, true)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
