extends RefCounted

const Kit := preload("res://scenes/world/kit.gd")
## DICE, WAVES & SAVES — four generators, ported from the web workshop
## (docs/worlds.js, family dice). The arithmetic around the world. Not the
## map but the things that decide what falls out of a chest, when the next
## wave comes, how a world folds into a file and back, and the one number
## that makes all of it repeatable: the seed. Four cards: Dice, Horde,
## Save, Seed. Every "random" here is rng(seed), so every visitor sees the
## same luck.
##
## Randomness: every card seeds Kit.rng(D.seed), exactly like the web's
## rng(seed). Godot's RandomNumberGenerator is not mulberry32, so the
## NUMBERS differ from the web page (the Seed card's decimals included) —
## but the RULE is the same: one seed, one world, on every machine that
## runs this file.

const TITLE := "Dice, waves & saves"
const BLURB := "the arithmetic around the world — weighted loot and fair bags, a director's spawn curve, the world folded into a save, and one seed for everything"
const DEFS := [
	{ "id": "dice", "letter": "D", "name": "Dice",
		"hint": "loot by weight (a bar per rarity), a shuffle bag that empties before it repeats, and a pity timer that fattens the rare weight — press to roll ten",
		"dials": { "names": ["common", "uncommon", "rare", "legendary"],
			"weights": [60, 28, 10, 2],        # the loot table
			"bag": [0, 0, 0, 0, 0, 1, 1, 2],   # the shuffle bag's contents, by rarity index
			"pityMax": 60,                     # a legendary is forced when the drought reaches this
			"pityRamp": 0.1,                   # extra legendary weight per dry roll
			"every": 0.28,                     # seconds between rolls
			"rolls": 80,                       # rolls per seed before the counts reset
			"rest": 2.4,
			"seed": 12,
			"label": "roll × Σw · walk the cumulative · the bag is fair · pity is kind" },
		"rhyme": { "name": "Drops", "hint": "a short, steep pity timer — the legendary weight climbs fast and is forced within twenty rolls",
			"dials": { "pityMax": 20, "pityRamp": 0.6 } } },
	{ "id": "horde", "letter": "H", "name": "Horde",
		"hint": "a director's curve — intensity over time, peaks and rests — sets the spawn rate; enemies enter off-screen and steer for the base — a velocity chasing a heading, so they arc in and spread — press to spike it",
		"dials": { "period": 12,               # seconds per wave cycle
			"peaks": 4,                        # bursts per cycle
			"peakH": 1,                        # the tallest burst
			"peakW": 0.55,                     # a burst's width, in seconds
			"floor": 0.06,                     # intensity between bursts — the trickle
			"rate": 5,                         # spawns per second at intensity 1
			"speed": 0.13,                     # enemy speed, in widths per second
			"turn": 3,                         # how fast a velocity chases its desired heading, per second — low turns wide
			"drag": 0.4,                       # velocity lost per second — the turn is a turn, not a slide
			"sepR": 0.05,                      # separation radius, in widths — closer than this, two enemies push apart
			"sepF": 0.5,                       # the push at zero distance, as a multiple of the steering pull
			"spikeH": 1.2, "spikeDecay": 1.6,  # what a press adds, and how fast it fades per second
			"maxE": 70,
			"seed": 9,
			"label": "spawns/s = rate × intensity(t) · v' = (desired − v)·turn − drag·v + push from neighbours" },
		"rhyme": { "name": "Hush", "hint": "two small peaks in a long cycle — most of the time is rest, and the trickle is the tension: a stealth game's pacing",
			"dials": { "peaks": 2, "peakH": 0.4, "period": 20 } } },
	{ "id": "save", "letter": "S", "name": "Save",
		"hint": "the state as JSON text (right there in the panel), three slots, a version field and a migration when an old save loads — press to save / load a slot",
		"dials": { "slots": 3,
			"version": 2,                      # what this build writes
			"legacy": { "version": 1, "x": 8, "y": 2, "hp": 4, "day": 2 },   # an old save already in slot 1: no coins, no pos array
			"cols": 12, "rows": 7,             # the tiny world
			"coins": 7,                        # coins a day
			"step": 0.45,                      # seconds per world step on autopilot
			"autoSave": 3.4,                   # seconds between the autopilot's saves
			"autoLoad": 8.5,                   # seconds between the autopilot's loads
			"deleteOnLoad": false,             # the roguelike rule: a loaded save is gone
			"scroll": 10,                      # json panel scroll, px per second
			"run": 30,                         # seconds per run before a new game (next seed)
			"seed": 21,
			"label": "state → JSON.stringify → slot · load → JSON.parse → migrate(v)" },
		"rhyme": { "name": "Suspend", "hint": "one slot, and it is deleted the moment it is loaded — the roguelike's suspend rule: no scumming",
			"dials": { "slots": 1, "deleteOnLoad": true } } },
	{ "id": "seed", "letter": "S", "name": "Seed",
		"hint": "one seed reproduces the whole map — same seed, identical panels; seed + 1, another world; the rng's first numbers shown — press for the next seed",
		"dials": { "seed": 4477,
			"offsets": [0, 0, 1],              # each panel's seed, relative to the typed one: same, same, next
			"cols": 14, "rows": 9,
			"scale": 0.38,                     # noise zoom
			"sea": -0.15, "grass": 0.25, "wood": 0.55,   # height bands
			"houses": 3,
			"perBeat": 6, "beat": 0.03,        # cells revealed per beat, in reading order
			"typeBeat": 0.08,                  # seconds per typed character
			"rest": 3,
			"label": "rng(seed) → the same numbers → the same world, on every machine" },
		"rhyme": { "name": "Sibling", "hint": "three consecutive seeds side by side — neighbours in number, strangers on the map",
			"dials": { "offsets": [0, 1, 2] } } },
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

## ctx.setLineDash([4, 3]) + strokeRect: the dashes drawn as short lines.
static func _dashed_rect(n: CanvasItem, rc: Rect2, col: Color) -> void:
	var corners := [rc.position, rc.position + Vector2(rc.size.x, 0.0), rc.end, rc.position + Vector2(0.0, rc.size.y)]
	for k in 4:
		var a: Vector2 = corners[k]
		var c: Vector2 = corners[(k + 1) % 4]
		var seg := c - a
		var length := seg.length()
		if length < 0.5:
			continue
		var dir := seg / length
		var at := 0.0
		while at < length:
			n.draw_line(a + dir * at, a + dir * minf(length, at + 4.0), col, 1.0)
			at += 7.0


# ── Dice ─────────────────────────────────────────────────────────────────

static func _dice_reset(b: Dictionary) -> void:
	var K: int = b.K
	b.r = Kit.rng(b.seed)
	b.done = 0
	b.pity = 0
	b.forced = 0
	b.refills = 0
	b.bagIdx = 0
	b.bagOrder = []
	b.lastW = -1
	b.lastB = -1
	b.acc = 0.0
	b.restT = 0.0
	b.pulse = 0.0
	b.roll = { "v": 0.0, "total": 1.0, "at": 0.0, "forced": false }
	var counts: PackedInt32Array = b.counts
	var bagCounts: PackedInt32Array = b.bagCounts
	for i in K:
		counts[i] = 0
		bagCounts[i] = 0

static func _dice_legendary_w(b: Dictionary) -> float:
	var D: Dictionary = b.D
	var weights: Array = D.weights
	return float(weights[int(b.K) - 1]) + float(b.pity) * float(D.pityRamp)

static func _dice_weight(b: Dictionary, i: int) -> float:
	var weights: Array = (b.D as Dictionary).weights
	return _dice_legendary_w(b) if i == int(b.K) - 1 else float(weights[i])

static func _dice_once(b: Dictionary) -> void:
	var D: Dictionary = b.D
	var K: int = b.K
	var r: RandomNumberGenerator = b.r
	var total := 0.0                                            # the weighted pick, with pity on the last weight
	for i in K:
		total += _dice_weight(b, i)
	var v := r.randf() * total
	var pick := K - 1
	var acc2 := 0.0
	for i in K:
		var wgt := _dice_weight(b, i)
		if v < acc2 + wgt:
			pick = i
			break
		acc2 += wgt
	var wasForced := false
	if int(b.pity) >= int(D.pityMax) and pick != K - 1:
		pick = K - 1
		wasForced = true
		b.forced += 1
	b.roll = { "v": v, "total": total, "at": v / maxf(1e-6, total), "forced": wasForced }
	if pick == K - 1:
		b.pity = 0
	else:
		b.pity += 1
	var counts: PackedInt32Array = b.counts
	counts[pick] += 1
	b.lastW = pick
	var bagOrder: Array = b.bagOrder
	if int(b.bagIdx) >= bagOrder.size():                        # the bag: refill only when empty
		bagOrder = Kit.shuffle((D.bag as Array).duplicate(), r)
		b.bagOrder = bagOrder
		b.bagIdx = 0
		b.refills += 1
	var lastB: int = bagOrder[b.bagIdx]
	b.bagIdx += 1
	b.lastB = lastB
	var bagCounts: PackedInt32Array = b.bagCounts
	bagCounts[lastB] += 1
	b.done += 1
	b.pulse = 1.0


# ── Horde ────────────────────────────────────────────────────────────────

static func _horde_curve(b: Dictionary) -> void:
	var D: Dictionary = b.D
	var r := Kit.rng(b.seed)
	var peaks: Array = []
	var spawners: Array = []
	var nPeaks: int = D.peaks
	var period: float = D.period
	for i in nPeaks:
		peaks.append({ "c": (i + 0.2 + r.randf() * 0.6) / nPeaks * period, "h": float(D.peakH) * (0.55 + 0.45 * r.randf()) })
	var m: float = b.w * 0.06
	var sx0: float = b.sx0
	var sx1: float = b.sx1
	var sy0: float = b.sy0
	var sy1: float = b.sy1
	spawners.append({ "x": sx0 - m, "y": sy0 + (0.2 + r.randf() * 0.5) * (sy1 - sy0) })
	spawners.append({ "x": sx1 + m, "y": sy0 + (0.2 + r.randf() * 0.5) * (sy1 - sy0) })
	spawners.append({ "x": sx0 + (0.2 + r.randf() * 0.6) * (sx1 - sx0), "y": sy0 - m })
	b.peaks = peaks
	b.spawners = spawners

## The seeded curve, wrapped so the cycle joins up.
static func _horde_base(b: Dictionary, x: float) -> float:
	var D: Dictionary = b.D
	var period: float = D.period
	var peakW: float = D.peakW
	var v: float = D.floor
	for p: Dictionary in (b.peaks as Array):
		var d: float = x - float(p.c)
		d -= period * roundf(d / period)
		v += float(p.h) * exp(-(d * d) / (peakW * peakW))
	return v


# ── Save ─────────────────────────────────────────────────────────────────

## The day's coins come from the seed, so a save need not list them.
static func _save_coins(D: Dictionary, st: Dictionary) -> PackedInt32Array:
	var rr := Kit.rng(int(st.seed) * 31 + int(st.day))
	var out := PackedInt32Array()
	var cols: int = D.cols
	for _i in int(D.coins):
		out.append(_pick(rr, cols) + _pick(rr, int(D.rows)) * cols)
	return out

static func _save_new_game(b: Dictionary) -> void:
	var D: Dictionary = b.D
	var r := Kit.rng(b.seed)
	b.r = r
	b.st = { "version": int(D.version), "seed": int(b.seed), "day": 1, "hp": 5, "coins": 0,
		"pos": [_pick(r, int(D.cols)), _pick(r, int(D.rows))], "taken": [] }
	b.stepT = 0.0
	b.saveT = 0.0
	b.loadT = 0.0
	b.runT = 0.0
	b.nextSlot = 1 % int(D.slots)
	b.scrollY = 0.0
	b.lastAct = "new game · seed %d" % int(b.seed)

## An older save, brought up to date one version at a time.
static func _save_migrate(b: Dictionary, s: Dictionary) -> String:
	var D: Dictionary = b.D
	var version: int = D.version
	var from := int(s.version) if s.has("version") else 0
	var fixes := PackedStringArray()
	if from < 1:
		s.version = 1
	if int(s.version) < 2:
		if not s.has("pos"):
			s.pos = [int(s.x) if s.has("x") else 0, int(s.y) if s.has("y") else 0]
			s.erase("x")
			s.erase("y")
			fixes.append("pos = [x, y]")
		if not s.has("coins"):
			s.coins = 0
			fixes.append("coins = 0")
		if not s.has("taken"):
			s.taken = []
			fixes.append("taken = []")
		if not s.has("seed"):
			s.seed = int(b.seed)
			fixes.append("seed = %d" % int(b.seed))
		s.version = 2
	if not (s.get("hp") is float or s.get("hp") is int) or not is_finite(float(s.hp)):
		s.hp = 5
	if not (s.get("pos") is Array) or (s.pos as Array).size() != 2:
		s.pos = [0, 0]
	var pos: Array = s.pos                                      # JSON numbers come back as floats: int them
	pos[0] = clampi(int(pos[0]), 0, int(D.cols) - 1)
	pos[1] = clampi(int(pos[1]), 0, int(D.rows) - 1)
	s.hp = int(s.hp)
	s.day = maxi(1, int(s.get("day", 1)))
	s.coins = maxi(0, int(s.coins))
	s.seed = int(s.get("seed", b.seed))
	s.version = int(s.version)
	var taken: Array = []
	if s.get("taken") is Array:
		for v in (s.taken as Array):
			taken.append(int(v))
	s.taken = taken
	return "migrated v%d → v%d: %s" % [from, version, ", ".join(fixes)] if from < version else ""

static func _save_save(b: Dictionary, i: int) -> void:
	var D: Dictionary = b.D
	var slots: Array = b.slots
	var st: Dictionary = b.st
	var text := JSON.stringify(st)                              # the whole game as text: that IS the save
	slots[i] = { "text": text, "v": int(st.version), "glow": 1.0 }
	b.lastAct = "saved slot %d · %d chars" % [i + 1, text.length()]
	b.nextSlot = (i + 1) % int(D.slots)

static func _save_load(b: Dictionary, i: int) -> void:
	var D: Dictionary = b.D
	var slots: Array = b.slots
	if slots[i] == null:
		return
	var sl: Dictionary = slots[i]
	var parsed: Variant = JSON.parse_string(sl.text)
	var obj: Dictionary = parsed if parsed is Dictionary else {}
	var note := _save_migrate(b, obj)
	b.st = obj
	sl.glow = -1.0
	b.lastAct = "loaded slot %d%s" % [i + 1, " · " + note if note != "" else " · v%d, nothing to migrate" % int(D.version)]
	if note != "":
		(b.notes as Array).append({ "txt": note, "t": 3.0 })
	if D.deleteOnLoad:
		slots[i] = null
		b.lastAct += " · slot deleted"

## Autopilot: walk to the nearest coin left today.
static func _save_world_step(b: Dictionary) -> void:
	var D: Dictionary = b.D
	var st: Dictionary = b.st
	var r: RandomNumberGenerator = b.r
	var cols: int = D.cols
	var coins := _save_coins(D, st)
	var taken: Array = st.taken
	var pos: Array = st.pos
	var bi := -1
	var bd := 1000000000
	for i in coins.size():
		if taken.has(i):
			continue
		var cx := coins[i] % cols
		var cy := (coins[i] - cx) / cols
		var d := absi(cx - int(pos[0])) + absi(cy - int(pos[1]))
		if d < bd:
			bd = d
			bi = i
	if bi < 0:                                                  # all taken: a new day, new coins
		st.day += 1
		st.taken = []
		st.hp = mini(5, int(st.hp) + 1)
		return
	var cx := coins[bi] % cols
	var cy := (coins[bi] - cx) / cols
	if cx != int(pos[0]):
		pos[0] = int(pos[0]) + (1 if cx > int(pos[0]) else -1)
	elif cy != int(pos[1]):
		pos[1] = int(pos[1]) + (1 if cy > int(pos[1]) else -1)
	if int(pos[0]) == cx and int(pos[1]) == cy:
		taken.append(bi)
		st.coins += 1
		if r.randf() < 0.25:
			st.hp = maxi(1, int(st.hp) - 1)


# ── Seed ─────────────────────────────────────────────────────────────────

## Everything about a panel comes from rng(s).
static func _seed_world(b: Dictionary, s: int) -> Dictionary:
	var D: Dictionary = b.D
	var r := Kit.rng(s)
	var first := [r.randf(), r.randf(), r.randf(), r.randf()]
	var ox: float = first[0] * 100.0
	var oy: float = first[1] * 100.0
	var cols: int = D.cols
	var rows: int = D.rows
	var N: int = b.N
	var scale: float = D.scale
	var sea: float = D.sea
	var grass: float = D.grass
	var wood: float = D.wood
	var cells := PackedByteArray()
	cells.resize(N)
	for y in rows:
		for x in cols:
			var v := Kit.noise2(x * scale + ox, y * scale + oy)
			cells[y * cols + x] = 0 if v < sea else (1 if v < grass else (2 if v < wood else 3))
	var houses: Array = []
	for _i in int(D.houses):
		var c := _pick(r, N)
		if cells[c] == 1:
			houses.append(c)
	return { "seed": s, "first": first, "cells": cells, "houses": houses }

static func _seed_grow(b: Dictionary) -> void:
	var D: Dictionary = b.D
	var worlds: Array = []
	for o in (D.offsets as Array):
		worlds.append(_seed_world(b, int(b.seed) + int(o)))
	b.worlds = worlds
	b.text = "try seed %d" % int(b.seed)
	b.typed = 0
	b.shown = 0
	b.acc = 0.0
	b.restT = 0.0


# ── the four entry points ────────────────────────────────────────────────

static func init(b: Dictionary) -> void:
	var D: Dictionary = b.D
	match b.id:
		"dice":
			# WEIGHTED RANDOM. lay the weights end to end — 60, 28, 10, 2 — roll a
			# number from 0 to their sum, and walk along until the roll is spent:
			# the segment you stop in is the drop. that is every loot table. it is
			# fair on average and cruel in the moment, so games add two kindnesses.
			# a SHUFFLE BAG holds the drops as tokens, shuffled, and hands them out
			# until empty — every rarity arrives exactly its share per bag. a PITY
			# TIMER counts dry rolls and adds to the rare weight each time, forcing
			# it at a cap. the seed (ch01) makes even the luck reproducible.
			var K: int = (D.names as Array).size()
			b.K = K
			b.cols = [Kit.BONE, Kit.GOOD, Kit.MOVER, Kit.MAGIC]
			var counts := PackedInt32Array()
			counts.resize(K)
			b.counts = counts
			var bagCounts := PackedInt32Array()
			bagCounts.resize(K)
			b.bagCounts = bagCounts
			b.seed = int(D.seed)
			_dice_reset(b)
		"horde":
			# a SPAWN DIRECTOR. the horde is not a list of enemies, it is a CURVE:
			# intensity against time, a few seeded bumps on a low floor, and the
			# director reads it — spawns per second = rate × intensity — so the
			# pressure has PACING: a rush, a breath, a bigger rush. spawn points
			# sit just outside the screen rectangle, so enemies enter rather than
			# appear, and every one of them marches toward the base like the
			# lexicon's Zombies and Invaders. each cycle draws a fresh curve from
			# the next seed; a press adds a spike where the playhead is.
			b.gy0 = 14.0
			b.gh = b.h * 0.26
			b.sy0 = float(b.gy0) + float(b.gh) + 8.0
			b.sx0 = b.w * 0.13
			b.sx1 = b.w * 0.87
			b.sy1 = b.h - 20.0
			b.bx = b.w / 2.0
			b.by = float(b.sy1) - 12.0
			b.seed = int(D.seed)
			b.tau = 0.0
			b.spike = 0.0
			b.acc = 0.0
			b.reached = 0
			b.hit = 0.0
			b.r2 = Kit.rng(int(D.seed) + 1)                     # the spawn jitter: its own stream, never reseeded
			b.E = []
			_horde_curve(b)
		"save":
			# SAVE & LOAD. the whole game is a plain object — position, hp, coins,
			# the day, which coins are taken — and JSON.stringify turns it into
			# text; that text is the save. loading is JSON.parse and then the
			# careful part: MIGRATION. the save carries a VERSION, and when an old
			# one arrives (slot 1 holds a v1 save with x, y and no coins) the loader
			# fills in what the new build expects — pos = [x, y], coins = 0 — and
			# stamps the new version. ch09 wrote the rules; this card shows the
			# text moving. the world walks on autopilot so the state keeps changing.
			b.ww = b.w * 0.52
			b.wh = b.h * 0.5
			b.cw = float(b.ww) / float(D.cols)
			b.ch = float(b.wh) / float(D.rows)
			b.px0 = float(b.ww) + 8.0
			b.pw = b.w - float(b.px0) - 4.0
			b.fs = clampf(b.w * 0.034, 8.0, 12.0)
			b.lh = float(b.fs) + 2.0
			var slots: Array = []
			for _i in int(D.slots):
				slots.append(null)
			slots[0] = { "text": JSON.stringify(D.legacy), "v": 1, "glow": 0.0 }
			b.slots = slots
			b.notes = []
			b.jsonLines = PackedStringArray()
			b.seed = int(D.seed)
			_save_new_game(b)
		"seed":
			# a SEEDED WORLD. rng(seed) is mulberry32 on the web page (here Godot's
			# generator — different numbers, same idea): a few shifts and multiplies
			# on one 32-bit number, and the sequence it spits out is the same on
			# every machine that starts from the same seed (ch01). feed every
			# choice the generator makes — where the noise is read from, where the
			# houses go — from that one stream and the whole world is one number
			# long: "try seed 4477" is the entire map. the first panels share a
			# seed, so they match to the cell; the last one is off by one, and
			# nothing matches. the four decimals under each are the stream itself.
			var P: int = (D.offsets as Array).size()
			b.P = P
			b.gap = 6.0
			b.pw = (b.w - float(b.gap) * (P + 1)) / P
			b.ph = minf(float(b.pw) * float(D.rows) / float(D.cols), b.h * 0.5)
			b.cw = float(b.pw) / float(D.cols)
			b.ch = float(b.ph) / float(D.rows)
			b.py0 = 30.0
			b.N = int(D.cols) * int(D.rows)
			b.cols = [Color("#3A6FB5"), Color("#6FAF5E"), Color("#3E7A3A"), Color("#8C8698")]
			b.seed = int(D.seed)
			_seed_grow(b)

static func press(b: Dictionary, pos: Vector2) -> void:
	var D: Dictionary = b.D
	match b.id:
		"dice":
			for _i in 10:
				if int(b.done) < int(D.rolls):
					_dice_once(b)
		"horde":
			b.spike += float(D.spikeH)
		"save":
			var slotsN: int = D.slots
			var sw: float = float(b.ww) / slotsN
			var sy: float = float(b.wh) + 14.0
			var slots: Array = b.slots
			if pos.y > sy and pos.y < sy + 26.0 and pos.x < float(b.ww):
				var i := clampi(int(floorf(pos.x / sw)), 0, slotsN - 1)
				if slots[i] != null:
					_save_load(b, i)
				else:
					_save_save(b, i)
			else:
				_save_save(b, b.nextSlot)
		"seed":
			b.seed += 1
			_seed_grow(b)

static func tick(b: Dictionary, dt: float, _t: float) -> void:
	var D: Dictionary = b.D
	match b.id:
		"dice":
			b.pulse = maxf(0.0, float(b.pulse) - dt * 5.0)
			if int(b.done) < int(D.rolls):
				b.acc += dt
				if float(b.acc) >= float(D.every):
					b.acc = 0.0
					_dice_once(b)
			else:
				b.restT += dt
				if float(b.restT) > float(D.rest):
					b.seed += 1
					_dice_reset(b)
		"horde":
			var period: float = D.period
			b.tau += dt
			if float(b.tau) >= period:                          # a new wave from the next seed
				b.tau -= period
				b.seed += 1
				_horde_curve(b)
			b.spike = maxf(0.0, float(b.spike) - float(b.spike) * float(D.spikeDecay) * dt)
			b.hit = maxf(0.0, float(b.hit) - dt * 3.0)
			var inten := _horde_base(b, b.tau) + float(b.spike)
			b.acc += inten * float(D.rate) * dt
			var E: Array = b.E
			var spawners: Array = b.spawners
			var r2: RandomNumberGenerator = b.r2
			var maxE: int = D.maxE
			var guard := 0
			while float(b.acc) >= 1.0 and guard < 20:           # spawn: a seeded point, a nudge, a heading for the base
				guard += 1
				b.acc -= 1.0
				var sp: Dictionary = spawners[_pick(r2, spawners.size())]
				if E.size() >= maxE:
					E.pop_front()
				var ex: float = float(sp.x) + (r2.randf() - 0.5) * b.w * 0.04
				var ey: float = float(sp.y) + (r2.randf() - 0.5) * b.h * 0.06
				var ew: float = r2.randf() * 6.28
				var ek: float = 0.8 + r2.randf() * 0.4
				var v0: float = float(D.speed) * b.w * ek * 0.5     # born moving, in a random direction — the steering has to swing it round
				E.append({ "x": ex, "y": ey, "w": ew, "k": ek, "vx": cos(ew) * v0, "vy": sin(ew) * v0 })
			var bx: float = b.bx
			var by: float = b.by
			var speed: float = D.speed
			var turn: float = D.turn
			var drag: float = D.drag
			var sepF: float = D.sepF
			var R: float = float(D.sepR) * b.w
			var R2 := R * R
			# every enemy is a VELOCITY now, not a position stamped along a line: each
			# step it steers — v += (desired − v)·turn·dt, desired being full speed
			# straight at the base — so a spawn facing the wrong way swings round in
			# an arc instead of snapping; drag bleeds speed so the turn is a turn and
			# not a slide; and a cheap SEPARATION (every pair closer than sepR pushes
			# apart, harder the closer) spreads the mob so it arrives as a crowd, not
			# a stack. symplectic: velocity first, then position; substepped so the
			# coarsest frame is still stable (turn·h and drag·h well under 1)
			var sub := maxi(1, ceili(dt * 50.0))
			var hs := dt / sub
			for _s in sub:
				for i in E.size():
					var e: Dictionary = E[i]
					var dx: float = bx - float(e.x)
					var dy: float = by - float(e.y)
					var d := maxf(1e-6, Vector2(dx, dy).length())
					var spd: float = speed * b.w * float(e.k)
					var ax: float = (dx / d * spd - float(e.vx)) * turn   # chase the heading
					var ay: float = (dy / d * spd - float(e.vy)) * turn
					e.w += hs * 6.0                                 # the old wobble, now a small sideways push
					var wob: float = cos(float(e.w)) * spd * turn * 0.3
					ax += -dy / d * wob
					ay += dx / d * wob
					for j in E.size():                              # separation: O(n²), but n ≤ maxE and the test is one subtraction
						if j == i:
							continue
						var o: Dictionary = E[j]
						var ox: float = float(e.x) - float(o.x)
						var oy: float = float(e.y) - float(o.y)
						var q2 := ox * ox + oy * oy
						if q2 < R2 and q2 > 1e-6:
							var q := sqrt(q2)
							var f := (1.0 - q / R) * spd * sepF * turn
							ax += ox / q * f
							ay += oy / q * f
					e.vx += (ax - float(e.vx) * drag) * hs
					e.vy += (ay - float(e.vy) * drag) * hs
					e.x += float(e.vx) * hs
					e.y += float(e.vy) * hs
			for i in range(E.size() - 1, -1, -1):
				var e: Dictionary = E[i]
				if Vector2(bx - float(e.x), by - float(e.y)).length() < 10.0:
					E.remove_at(i)
					b.reached += 1
					b.hit = 1.0
		"save":
			var slots: Array = b.slots
			var slotsN: int = D.slots
			b.stepT += dt
			if float(b.stepT) >= float(D.step):
				b.stepT = 0.0
				_save_world_step(b)
			b.saveT += dt
			if float(b.saveT) >= float(D.autoSave):
				b.saveT = 0.0
				_save_save(b, b.nextSlot)
			b.loadT += dt
			if float(b.loadT) >= float(D.autoLoad):             # the autopilot loads a filled slot now and then
				b.loadT = 0.0
				for k in slotsN:
					var i := (int(b.nextSlot) + k) % slotsN
					if slots[i] != null:
						_save_load(b, i)
						break
			b.runT += dt
			if float(b.runT) >= float(D.run):
				b.seed += 1
				_save_new_game(b)
			var notes: Array = b.notes
			for note: Dictionary in notes:
				note.t -= dt
			while not notes.is_empty() and float((notes[0] as Dictionary).t) <= 0.0:
				notes.pop_front()
			for sl in slots:                                    # the slot glow fades (the web did this while drawing)
				if sl != null:
					var sd: Dictionary = sl
					var glow: float = sd.glow
					sd.glow = maxf(0.0, glow - dt * 1.5) if glow > 0.0 else minf(0.0, glow + dt * 1.5)
			# the panel's text, the real JSON of the real state, and its scroll
			var lines := JSON.stringify(b.st, "  ").split("\n")
			b.jsonLines = lines
			var lh: float = b.lh
			var span := lines.size() * lh + lh * 2.0
			b.scrollY = fmod(float(b.scrollY) + float(D.scroll) * dt, span)
		"seed":
			var text: String = b.text
			var N: int = b.N
			if int(b.typed) < text.length():
				b.acc += dt
				if float(b.acc) >= float(D.typeBeat):
					b.acc = 0.0
					b.typed += 1
			elif int(b.shown) < N:
				b.acc += dt
				var beat: float = D.beat
				var guard := 0
				while float(b.acc) >= beat and int(b.shown) < N and guard < 30:
					guard += 1
					b.acc -= beat
					b.shown = mini(N, int(b.shown) + int(D.perBeat))
			else:
				b.restT += dt
				if float(b.restT) > float(D.rest):
					b.seed += 1
					_seed_grow(b)

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	var D: Dictionary = b.D
	var w: float = b.w
	var h: float = b.h
	Kit.stage(n, b)
	match b.id:
		"dice":
			var K: int = b.K
			var cols: Array = b.cols
			var names: Array = D.names
			var weights: Array = D.weights
			var counts: PackedInt32Array = b.counts
			var bagCounts: PackedInt32Array = b.bagCounts
			var roll: Dictionary = b.roll
			var lastW: int = b.lastW
			var done: int = b.done
			var pity: int = b.pity
			var pityMax: int = D.pityMax
			var forced: bool = roll.forced
			var x0 := 8.0
			var bw := w - 16.0
			var y1 := 24.0
			var bh := maxf(6.0, h * 0.055)
			var total := 0.0
			for i in K:
				total += _dice_weight(b, i)
			var x := x0                                         # the cumulative bar: the weights laid end to end
			for i in K:
				var wgt := _dice_weight(b, i) / total * bw
				var cc: Color = cols[i]
				Kit.rect(n, Rect2(x, y1, wgt, bh), Color(cc, 0.95 if i == lastW else 0.45))
				x += wgt
			var px := x0 + clampf(roll.at, 0.0, 1.0) * bw
			var mark := Kit.HOT if forced else Kit.TARGET
			Kit.poly(n, [Vector2(px, y1 - 5.0), Vector2(px - 4.0, y1 - 11.0), Vector2(px + 4.0, y1 - 11.0)], mark)
			Kit.line(n, Vector2(px, y1 - 5.0), Vector2(px, y1 + bh), mark, 1.5)
			_txt(n, "roll %.1f of %.1f → %s%s" % [float(roll.v), total, String(names[lastW]) if lastW >= 0 else "…", " (forced)" if forced else ""],
				x0, 11.0, Kit.HOT if forced else DEFAULT_TXT)
			_txt(n, "%d / %d" % [done, int(D.rolls)], w - 8.0, 11.0, DEFAULT_TXT, "right")
			var hy := y1 + bh + 10.0                            # histograms: weighted vs bag, expected as a tick
			var hh := maxf(10.0, h * 0.17)
			var colW := bw / (K * 2 + 1)
			var nn := maxi(1, done)
			for i in K:
				var cx := x0 + colW * (i * 2 + 1)
				var cc: Color = cols[i]
				var wh := minf(hh, counts[i] / float(nn) * hh * 1.6)
				var bhh := minf(hh, bagCounts[i] / float(nn) * hh * 1.6)
				Kit.rect(n, Rect2(cx, hy + hh - wh, colW * 0.45, wh), Color(cc, 0.85))
				Kit.rect(n, Rect2(cx + colW * 0.5, hy + hh - bhh, colW * 0.45, bhh), Color(cc, 0.4))
				var ex := hy + hh - minf(hh, float(weights[i]) / total * hh * 1.6)
				Kit.line(n, Vector2(cx - 2.0, ex), Vector2(cx + colW, ex), Kit.DIM, 1.0)   # where the weight says the column should be
				var nm := String(names[i])
				_txt(n, "%s %d·%d" % [nm if w > 400.0 else nm.substr(0, 1), counts[i], bagCounts[i]], cx, hy + hh + 10.0, cc)
			_txt(n, "weighted · bag", w - 8.0, hy + hh + 10.0, Kit.DIM, "right")
			var bag: Array = D.bag
			var bagOrder: Array = b.bagOrder
			var bagIdx: int = b.bagIdx
			var pulse: float = b.pulse
			var by := hy + hh + 22.0                            # the bag, emptying token by token
			var chip := minf(bw / (bag.size() + 2), h * 0.06)
			_txt(n, "bag %d / %d left · refills %d" % [bagOrder.size() - bagIdx, bag.size(), int(b.refills)], x0, by - 2.0)
			for i in bagOrder.size():
				var cx := x0 + chip * 0.5 + i * chip * 1.15
				var cy := by + chip * 0.6
				var cc: Color = cols[int(bagOrder[i])]
				if i < bagIdx:
					Kit.ring(n, Vector2(cx, cy), chip * 0.42, Color(cc, 0.35), 1.0)
				else:
					Kit.dot(n, Vector2(cx, cy), chip * 0.42 * (1.0 + pulse * 0.3 if i == bagIdx else 1.0), cc)
			var py := by + chip * 1.4 + 12.0                    # the pity meter
			Kit.rect(n, Rect2(x0, py, bw, 5.0), Color(0.91, 0.898, 0.957, 0.1))
			Kit.rect(n, Rect2(x0, py, bw * clampf(pity / maxf(1.0, float(pityMax)), 0.0, 1.0), 5.0), Kit.HOT if pity >= pityMax * 0.75 else Kit.MAGIC)
			var nForced: int = b.forced
			_txt(n, "pity %d / %d · legendary weight %s + %d×%s = %.1f%s" % [pity, pityMax, str(weights[K - 1]), pity, str(D.pityRamp),
				_dice_legendary_w(b), " · forced ×%d" % nForced if nForced > 0 else ""], x0, py - 3.0, Kit.MAGIC)
			_txt(n, D.label, w / 2.0, h - 6.0, DEFAULT_TXT, "center")
		"horde":
			var gy0: float = b.gy0
			var gh: float = b.gh
			var sx0: float = b.sx0
			var sx1: float = b.sx1
			var sy0: float = b.sy0
			var sy1: float = b.sy1
			var bx: float = b.bx
			var by: float = b.by
			var period: float = D.period
			var tau: float = b.tau
			var spike: float = b.spike
			var inten := _horde_base(b, tau) + spike
			var top: float = float(D.peakH) * 1.15 + float(D.floor) + 0.6   # the graph
			var gx := func(x: float) -> float: return 8.0 + x / period * (w - 16.0)
			var gyv := func(v: float) -> float: return gy0 + gh - clampf(v / top, 0.0, 1.4) * gh
			Kit.line(n, Vector2(8.0, gy0 + gh), Vector2(w - 8.0, gy0 + gh), Kit.DIM)
			var nn := maxi(40, int(floorf(w / 3.0)))
			var pts := PackedVector2Array()
			pts.resize(nn + 1)
			for i in nn + 1:
				var x := i / float(nn) * period
				pts[i] = Vector2(gx.call(x), gyv.call(_horde_base(b, x)))
			n.draw_polyline(pts, Kit.BONE, 1.5)
			var hx: float = gx.call(tau)
			Kit.line(n, Vector2(hx, gy0), Vector2(hx, gy0 + gh), Kit.TARGET, 1.0)   # the playhead …
			if spike > 0.01:                                    # … and the spike on top of the curve
				Kit.line(n, Vector2(hx, gyv.call(_horde_base(b, tau))), Vector2(hx, gyv.call(inten)), Kit.HOT, 3.0)
			Kit.dot(n, Vector2(hx, gyv.call(inten)), 3.0, Kit.HOT if spike > 0.01 else Kit.TARGET)
			_txt(n, "intensity %.2f → %.1f / s" % [inten, inten * float(D.rate)], clampf(hx + 6.0, 4.0, w - 110.0), gy0 + 8.0, Kit.TARGET)
			_txt(n, "t = %.1f / %s s · wave %d" % [tau, str(D.period), int(b.seed)], w - 8.0, gy0 + gh + 10.0, DEFAULT_TXT, "right")
			_dashed_rect(n, Rect2(sx0, sy0, sx1 - sx0, sy1 - sy0), Color(0.788, 0.769, 0.894, 0.35))   # the screen: what the player sees
			_txt(n, "screen", sx0 + 4.0, sy1 - 4.0, Kit.DIM)
			for sp: Dictionary in (b.spawners as Array):
				var p := Vector2(sp.x, sp.y)
				Kit.ring(n, p, 5.0, Kit.HOT, 1.2)
				Kit.arrow(n, p, p + (Vector2(bx, by) - p) * 0.12, Color(Kit.HOT, 0.6))
			var E: Array = b.E
			for e: Dictionary in E:
				var ep := Vector2(e.x, e.y)
				var a := atan2(float(e.vy), float(e.vx))           # the nose follows the velocity
				Kit.dot(n, ep, 3.0, Kit.HOT)
				Kit.dot(n, ep + Vector2(cos(a), sin(a)) * 3.5, 1.5, Kit.HOT)
			var hit: float = b.hit
			if hit > 0.0:
				Kit.ring(n, Vector2(bx, by), 10.0 + (1.0 - hit) * 14.0, Color(Kit.HOT, hit), 2.0)
			Kit.mote(n, b, Vector2(bx, by), -PI / 2.0, Kit.MOVER, 7.0)
			_txt(n, "%d alive · reached %d" % [E.size(), int(b.reached)], sx0 + 4.0, sy0 + 10.0)
			_txt(n, D.label, w / 2.0, h - 6.0, DEFAULT_TXT, "center")
		"save":
			var cols: int = D.cols
			var ww: float = b.ww
			var wh: float = b.wh
			var cw: float = b.cw
			var ch: float = b.ch
			var px0: float = b.px0
			var pw: float = b.pw
			var st: Dictionary = b.st
			var slots: Array = b.slots
			var slotsN: int = D.slots
			var version: int = D.version
			var coins := _save_coins(D, st)                     # the tiny world
			var taken: Array = st.taken
			var pos: Array = st.pos
			n.draw_rect(Rect2(0.5, 0.5, ww - 1.0, wh - 1.0), Color(0.588, 0.569, 0.745, 0.18), false, 1.0)
			for i in coins.size():
				if not taken.has(i):
					var cx := coins[i] % cols
					Kit.dot(n, Vector2((cx + 0.5) * cw, ((coins[i] - cx) / cols + 0.5) * ch), minf(cw, ch) * 0.22, Kit.TARGET)
			Kit.mote(n, b, Vector2((int(pos[0]) + 0.5) * cw, (int(pos[1]) + 0.5) * ch), 0.0, Kit.MOVER, minf(cw, ch) * 0.36)
			var hp: int = st.hp
			for i in 5:
				Kit.dot(n, Vector2(6.0 + i * 8.0, wh - 7.0), 2.5, Kit.HOT if i < hp else Color(0.961, 0.541, 0.541, 0.2))
			_txt(n, "day %d · coins %d" % [int(st.day), int(st.coins)], ww - 4.0, wh - 4.0, DEFAULT_TXT, "right")
			var sw := ww / slotsN                               # the slots
			var sy := wh + 14.0
			for i in slotsN:
				var x := i * sw + 2.0
				var fillC := Color(0.0, 0.0, 0.0, 0.25)
				var nameC := Kit.DIM
				var sub := "empty"
				if slots[i] != null:
					var sl: Dictionary = slots[i]
					var glow: float = sl.glow
					var sv: int = sl.v
					if glow > 0.0:
						fillC = Color(Kit.GOOD, 0.15 + glow * 0.4)
					elif glow < 0.0:
						fillC = Color(Kit.MOVER, 0.15 - glow * 0.4)
					else:
						fillC = Color(0.91, 0.898, 0.957, 0.08)
					nameC = Kit.TARGET if sv < version else Kit.BONE
					sub = "old format" if sv < version else "%d chars" % (sl.text as String).length()
				Kit.rect(n, Rect2(x, sy, sw - 4.0, 26.0), fillC)
				var slotName := "slot %d" % (i + 1)
				if slots[i] != null:
					slotName += " · v%d" % int((slots[i] as Dictionary).v)
				_txt(n, slotName, x + 4.0, sy + 11.0, nameC)
				_txt(n, sub, x + 4.0, sy + 22.0, Kit.DIM)
			_txt(n, b.lastAct, 4.0, sy + 38.0)
			# the json panel: the actual text, scrolling. the web clips to the panel
			# and uses a monospace font; here the lines are culled by arithmetic and
			# drawn in the fallback font.
			var panelH := h - 18.0
			Kit.rect(n, Rect2(px0, 0.0, pw, panelH), Color(0.0, 0.0, 0.0, 0.3))
			var fs: float = b.fs
			var lh: float = b.lh
			var lines: PackedStringArray = b.jsonLines
			var span := lines.size() * lh + lh * 2.0
			var scrollY: float = b.scrollY
			var maxChars := int(floorf(pw / (fs * 0.6)))
			var f := ThemeDB.fallback_font
			for k in range(-1, 2):
				for i in lines.size():
					var y := 12.0 + i * lh - scrollY + k * span
					if y < fs or y > panelH - 2.0:
						continue
					var ln := lines[i]
					var lc := Color(0.91, 0.898, 0.957, 0.75)
					if ln.find("\"version\"") >= 0:
						lc = Kit.TARGET
					elif ln.find("\"coins\"") >= 0 or ln.find("\"pos\"") >= 0:
						lc = Kit.GOOD
					n.draw_string(f, Vector2(px0 + 4.0, y), ln.substr(0, maxChars), HORIZONTAL_ALIGNMENT_LEFT, -1, int(fs), lc)
			var notes: Array = b.notes
			for i in notes.size():
				var note: Dictionary = notes[i]
				_txt(n, note.txt, w / 2.0, h / 2.0 + i * 12.0, Color(Kit.MAGIC, minf(1.0, float(note.t))), "center")
			_txt(n, D.label, w / 2.0, h - 6.0, DEFAULT_TXT, "center")
		"seed":
			var cols: int = D.cols
			var P: int = b.P
			var N: int = b.N
			var gap: float = b.gap
			var pw: float = b.pw
			var ph: float = b.ph
			var cw: float = b.cw
			var ch: float = b.ch
			var py0: float = b.py0
			var worlds: Array = b.worlds
			var typed: int = b.typed
			var shown: int = b.shown
			var text: String = b.text
			var offsets: Array = D.offsets
			var palette: Array = b.cols
			var f := ThemeDB.fallback_font
			var typing := typed < text.length()
			var cursor := "▍" if typing and int(floorf(t * 4.0)) % 2 == 1 else ""
			n.draw_string(f, Vector2(gap, 16.0), text.substr(0, typed) + cursor, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Kit.TARGET)   # the seed, typed
			var fs := clampf(pw * 0.06, 7.0, 10.0)
			var nums := 4 if pw > 150.0 else 2
			for p in P:
				var wd: Dictionary = worlds[p]
				var cells: PackedByteArray = wd.cells
				var x0 := gap + p * (pw + gap)
				Kit.rect(n, Rect2(x0, py0, pw, ph), Color(0.0, 0.0, 0.0, 0.25))
				for c in shown:
					var x := c % cols
					var cc: Color = palette[cells[c]]
					n.draw_rect(Rect2(x0 + x * cw, py0 + ((c - x) / cols) * ch, cw + 0.5, ch + 0.5), cc)
				for hc in (wd.houses as Array):
					if int(hc) < shown:
						var x := int(hc) % cols
						Kit.dot(n, Vector2(x0 + (x + 0.5) * cw, py0 + ((int(hc) - x) / cols + 0.5) * ch), minf(cw, ch) * 0.3, Kit.BONE)
				var same := p > 0 and int(offsets[p]) == int(offsets[p - 1])
				_txt(n, "seed %d%s" % [int(wd.seed), " again" if same else ""], x0 + pw / 2.0, py0 + ph + 11.0, Kit.DIM if typing else Kit.BONE, "center")
				var first: Array = wd.first
				var digits := PackedStringArray()
				for k in nums:
					digits.append("%.4f" % float(first[k]))
				_txt(n, " ".join(digits) + " …", x0 + pw / 2.0, py0 + ph + 22.0, Color(0.91, 0.898, 0.957, 0.5), "center", int(fs))
				if p > 0:                                       # between the panels: the verdict
					var prev: Dictionary = worlds[p - 1]
					var cellsSame: bool = cells == (prev.cells as PackedByteArray)
					_txt(n, "=" if cellsSame else "≠", x0 - gap / 2.0, py0 + ph / 2.0 + 5.0, Kit.GOOD if cellsSame else Kit.HOT, "center")
			var status := ""
			if shown < N and not typing:
				status = "building %d / %d" % [shown, N]
			elif shown >= N:
				status = "same seed, same map — off by one, another world"
			_txt(n, status, w - gap, 16.0, DEFAULT_TXT, "right")
			_txt(n, D.label, w / 2.0, h - 6.0, DEFAULT_TXT, "center")
