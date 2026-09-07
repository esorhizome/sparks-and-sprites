extends RefCounted

const Kit := preload("res://scenes/stage/kit.gd")
## UI & HUD FEEDBACK — thirteen effects, ported from the web almanac
## (docs/stagecraft.js, the hud family). The interface as an effect. A HUD
## is not a picture of the game's numbers — it is a set of small machines
## that LAG, CLAMP, PROJECT and QUEUE those numbers so a human can read
## them at speed: a health bar whose ghost drains after the hit, a cooldown
## wiped by an angle, digits that roll toward a score, an XP bar that
## carries its remainder, arrows clamped to the edge of the view, bubbles
## projected from world to screen every frame, a reticle that blooms,
## damage arcs that point, toasts that stack, a radar sweep, a placement
## ghost snapped to a grid, a rarity sheen, a boss bar that breaks. Every
## card here runs a tiny autopilot game that feeds its HUD element events,
## and draws the mechanism beside the element.
##
## THE PAINTER'S VERSION OF A CLIP. The web clips its cooldown slice to the
## icon, its radar wedge to the map, its rolling digits to the drum and its
## sheen to a diagonal band. Godot's _draw() has no clip, so every one of
## those is done by arithmetic instead: the slice and the wedge are fans
## whose rim is the distance to the clipping rectangle (a fan that traces
## the rectangle's edge), the sheen band is a polygon clipped against the
## card by Sutherland–Hodgman, and the drum's two digits are squashed into
## their visible fractions instead of being cut — a drum seen as a
## cylinder. Each card's draw() says which. The web's globalAlpha is a
## colour alpha here; its dashed strokes are short lines.

const TITLE := "UI & HUD feedback"
const BLURB := "the interface as an effect — ghost health, radial cooldowns, odometers, XP overflow, off-screen arrows, speech bubbles, hit markers, damage arcs, toasts, minimaps, placement ghosts, rarity, boss bars"
const DEFS := [
	{ "id": "healthbar", "letter": "H", "name": "Healthbar",
		"hint": "red snaps to the new health; a white ghost waits, then drains after it — the chunk you just lost, visible; heals run ahead in green — press to hit",
		"dials": { "max": 100,           # hit points
			"hitEvery": 1.7,             # autopilot: seconds between hits
			"hitMin": 8,                 # damage per hit, from...
			"hitMax": 26,                # ...to
			"healEvery": 5.5,            # autopilot: seconds between heals
			"heal": 34,                  # hit points per heal
			"delay": 0.25,               # the ghost waits this long before it moves
			"drain": 0.5,                # then crosses the chunk in this many seconds
			"segments": 0,               # 0 = a smooth bar; N = tick marks every max/N
			"label": "red = hp (snaps) · ghost waits delay s, then → hp over drain s" },
		"rhyme": { "name": "Hardcore", "hint": "no ghost delay and a near-instant drain on a bar cut into ten segments — the roguelike that refuses to soften the blow",
			"dials": { "delay": 0, "drain": 0.08, "segments": 10 } } },
	{ "id": "radial", "letter": "R", "name": "Radial",
		"hint": "a conic wipe counts each cooldown down from 12 o'clock — angle = 2π · remaining/cooldown — and pops when ready — press to use the one under your click",
		"dials": { "cooldowns": [2, 4.5, 8],  # seconds, one per ability icon
			"dir": 1,                    # 1 = the wipe uncovers clockwise, −1 = counter-clockwise
			"size": 0.16,                # icon half-size, of H
			"pop": 0.3,                  # the scale punch when an ability comes ready
			"glowReady": false,          # a pulsing glow behind ready icons
			"autoEvery": 1.2,            # autopilot: seconds between uses
			"label": "sweep = 2π · remaining / cooldown, from 12 o'clock · 0 → pop" },
		"rhyme": { "name": "Rune", "hint": "the wipe runs counter-clockwise and a ready rune breathes a glow behind its icon, with a bigger pop — the spellbook's version",
			"dials": { "dir": -1, "glowReady": true, "pop": 0.5 } } },
	{ "id": "odometer", "letter": "O", "name": "Odometer",
		"hint": "a score tweens to its value with an ease-out and comma grouping; each drum slides only on its carry — the folio's Odometer, live — press to add score",
		"dials": { "tween": 0.9,         # seconds from the old value to the new
			"gainMin": 80,               # a gain, from...
			"gainMax": 3600,             # ...to
			"autoEvery": 2.4,            # autopilot: seconds between gains
			"snap": false,               # true = no tween, the value jumps
			"punch": 0,                  # a scale punch on each gain (0 = none)
			"digits": 7,                 # drums on the counter
			"label": "shown = from + (to − from) · (1 − (1 − k)³) · drum i slides on its carry" },
		"rhyme": { "name": "Overdrive", "hint": "no tween: the value snaps and the whole counter takes a scale punch instead — the arcade cabinet's way of saying more",
			"dials": { "snap": true, "punch": 0.4, "autoEvery": 1.2 } } },
	{ "id": "xpbar", "letter": "X", "name": "Xpbar",
		"hint": "the bar fills, flashes, levels up and carries the remainder into a longer bar — need(L) grows by a ratio each level — press to gain xp",
		"dials": { "base": 100,          # xp needed for level 2
			"growth": 1.4,               # each level needs this many times more
			"gainMin": 15,               # a gain, from...
			"gainMax": 60,               # ...to
			"autoEvery": 1.1,            # autopilot: seconds between gains
			"fillTime": 0.45,            # a whole bar fills in this many seconds
			"flash": 0.3,                # the level-up flash, seconds
			"label": "need(L) = base · growth^(L−1) · shown ≥ need → L+1, xp −= need (the carry)" },
		"rhyme": { "name": "Xpsurge", "hint": "gains ten times bigger and a bar that fills in a quarter second — several level-ups lap through one bar, carry after carry",
			"dials": { "gainMin": 150, "gainMax": 420, "fillTime": 0.25 } } },
	{ "id": "offscreen", "letter": "O", "name": "Offscreen",
		"hint": "targets orbit outside the view; each is clamped to the view's edge and an arrow points from there, with the distance — press to add one that way",
		"dials": { "targets": 3,         # orbiting targets at the start
			"orbitX": 0.4,               # orbit radius, of W...
			"orbitY": 0.42,              # ...and of H
			"wobble": 0.3,               # the radius breathes by this fraction (so targets visit the view)
			"speed": 0.45,               # radians per second, roughly
			"margin": 12,                # arrows sit this far inside the view's edge
			"style": "arrow",            # "arrow" = edge arrows · "radar" = a ring of blips
			"radarR": 0.16,              # the radar ring radius, of H
			"label": "p' = clamp(p, view ± margin) · arrow angle = atan2(p − p') · d = |p − p'|" },
		"rhyme": { "name": "Overwatch", "hint": "the same targets on a radar ring in the view's corner — a scaled position clamped to the ring's edge instead of the screen's — five of them",
			"dials": { "style": "radar", "targets": 5 } } },
	{ "id": "anchor", "letter": "A", "name": "Anchor", "drag": true,
		"hint": "speech bubbles project a world point to the screen each frame — the tail stays on the speaker as the camera pans, the box clamps to the view — drag",
		"dials": { "world": 2.4,         # the world is this many screens wide
			"speakers": 3,               # talking NPCs
			"style": "bubble",           # "bubble" = a typed speech box · "tag" = a name tag with a leader line
			"boxW": 0.32,                # widest box, of W
			"margin": 6,                 # the box never comes closer than this to the view's edge
			"autoPan": 0.35,             # autopilot camera sweep, radians per second
			"cps": 16,                   # typed characters per second
			"hold": 2.2,                 # seconds a finished line stays up
			"label": "sx = wx − cam · box.x = clamp(sx − w/2, m, W − w − m) · tail → (sx, head)" },
		"rhyme": { "name": "Annotate", "hint": "name tags instead of speech: a small label with a thin leader line to each head, still projected and clamped every frame",
			"dials": { "style": "tag", "boxW": 0.16 } } },
	{ "id": "xhair", "letter": "X", "name": "Xhair", "drag": true,
		"hint": "a reticle whose spread blooms per shot and shrinks at rest; shots land inside it, a hit flashes an X marker — press to fire, hold to keep firing",
		"dials": { "spreadMin": 5,       # the tightest reticle, px
			"spreadMax": 42,             # the widest, px
			"bloom": 7,                  # px added per shot
			"recover": 28,               # px removed per second at rest
			"fireRate": 9,               # shots per second while held
			"marker": 0.22,              # the hit marker's life, seconds
			"autoEvery": 2.6,            # autopilot: seconds between bursts
			"burst": 6,                  # shots per autopilot burst
			"targetR": 0.075,            # the bullseye radius, of H
			"label": "spread += bloom per shot · spread −= recover · dt · shot = c + disc(spread)" },
		"rhyme": { "name": "Xactshot", "hint": "a tiny maximum spread, two pixels of bloom and a slow recovery, two shots a second — the sniper's reticle, patient and exact",
			"dials": { "spreadMax": 12, "bloom": 2, "recover": 9, "fireRate": 2 } } },
	{ "id": "damagearc", "letter": "D", "name": "Damagearc",
		"hint": "a red arc on the screen edge at the angle of whoever hit you, fading and turning with them — the atlas's Vignette aimed — press to attack from there",
		"dials": { "attackers": 3,       # circling enemies
			"orbit": 0.36,               # their orbit radius, of W
			"width": 0.7,                # arc width, radians
			"fade": 1.3,                 # seconds an arc takes to fade
			"hitEvery": 0.9,             # autopilot: seconds between lunges
			"dmg": 0.12,                 # health lost per hit, of 1
			"regen": 0.03,               # health regained per second
			"ringBelow": 0,              # below this health the whole ring pulses (0 = never)
			"inset": 9,                  # the arc ellipse sits this far inside the frame
			"label": "θ = atan2(attacker − player) · arc θ ± width/2 · α = 1 − age/fade" },
		"rhyme": { "name": "Deathring", "hint": "health barely regenerates, so it lives below the line where the whole ring pulses — the arcs still point, over a heartbeat of red",
			"dials": { "ringBelow": 0.5, "regen": 0.005, "hitEvery": 1.2 } } },
	{ "id": "toast", "letter": "T", "name": "Toast",
		"hint": "notifications slide in from the right, stack upward as new ones arrive below, and slide out on timers; the rest wait in a queue — press to post one",
		"dials": { "life": 2.8,          # seconds a toast stays
			"slide": 0.22,               # the slide in / out, seconds
			"gap": 4,                    # px between stacked toasts
			"shown": 4,                  # slots on screen; the rest wait in the queue
			"autoEvery": 1.3,            # autopilot: seconds between posts
			"mode": "stack",             # "stack" = a column of toasts · "ticker" = one scrolling line
			"width": 0.46,               # toast width, of W
			"label": "slot i: y = base − i · (h + gap) · x eases in over slide s · out after life s" },
		"rhyme": { "name": "Ticker", "hint": "the same queue on a single scrolling line — items append to the right and crawl left, each living one screen width",
			"dials": { "mode": "ticker", "life": 4.5 } } },
	{ "id": "minimap", "letter": "M", "name": "Minimap",
		"hint": "a scaled copy of the world in the corner with a radar sweep — a blip lights as the wedge passes and fades until the next pass — press to add a blip",
		"dials": { "size": 0.3,          # the map is the world scaled by this
			"period": 3,                 # seconds per sweep revolution
			"fade": 2.4,                 # a blip fades out over this long after the sweep
			"blips": 6,                  # enemies at the start
			"speed": 0.12,               # enemy walking speed, screens per second
			"mode": "sweep",             # "sweep" = the rotating wedge reveals · "motion" = only movers show
			"label": "map = origin + world · k · blip α = 1 − (t − seenAt) / fade" },
		"rhyme": { "name": "Motiontracker", "hint": "no sweep: a blip is stamped only while its enemy moves and fades fast when it stops — the Aliens tracker, eight contacts",
			"dials": { "mode": "motion", "fade": 1.1, "blips": 8 } } },
	{ "id": "ghostplacement", "letter": "G", "name": "Ghostplacement", "drag": true,
		"hint": "build mode: a ghost snapped to the grid, green where it fits, red where it overlaps; autopilot builds — drag to move the ghost, let go to place",
		"dials": { "cell": 0.09,         # grid cell, of H
			"pieceW": 3,                 # the piece, in cells...
			"pieceH": 1,                 # ...wide and tall (a press on a blocked spot rotates it)
			"autoEvery": 1.4,            # autopilot: seconds between placements
			"prefill": 6,                # pieces already on the plot
			"moveRate": 7,               # how fast the cursor glides to its target
			"label": "gx = round((x − ox) / cell − w/2) · valid = in bounds ∧ every cell free" },
		"rhyme": { "name": "Gardenplot", "hint": "a 2×1 bed on a much tighter grid — more cells, more collisions, the same green-or-red answer",
			"dials": { "pieceW": 2, "pieceH": 1, "cell": 0.065 } } },
	{ "id": "jewel", "letter": "J", "name": "Jewel",
		"hint": "four inventory cards, each with a colour by tier and a sheen that sweeps its border — the bestiary's Chrome sweep worn as rarity — press to reroll",
		"dials": { "tiers": ["common", "rare", "epic", "legendary"],
			"colours": ["#B9B4D0", "#4FA3D8", "#C9A0F5", "#F5C169"],
			"odds": [0.5, 0.28, 0.15, 0.07],   # reroll weights per tier
			"period": 2.4,               # seconds per sheen pass
			"band": 0.3,                 # sheen band width, of the card width
			"rerollEvery": 3.6,          # autopilot: seconds between rerolls
			"junk": false,               # true = everything common but one card
			"label": "sheen u = ((t − i·0.4) / period) mod 1 · the band is a clip · glow ∝ tier" },
		"rhyme": { "name": "Junkloot", "hint": "every drop common but one — the sweep runs on that card alone, a little faster, and the eye goes straight to it",
			"dials": { "junk": true, "period": 1.6 } } },
	{ "id": "bossbar", "letter": "B", "name": "Bossbar",
		"hint": "segments fill on the intro, shake on every hit and break off as each phase ends — the grimoire's Earthquake on a strip — press to hit the boss",
		"dials": { "phases": 3,          # segments on the bar
			"intro": 2,                  # seconds the intro fill takes
			"shake": 6,                  # px of shake on a hit
			"decay": 7,                  # the shake's decay rate, per second
			"hitEvery": 0.75,            # autopilot: seconds between hits
			"dmgMin": 5,                 # damage per hit, from...
			"dmgMax": 11,                # ...to (the bar holds 100)
			"name": "GLOOMWARDEN",
			"label": "intro: seg i fills at i/phases · hit: dx = shake · e^(−decay·age) · sin(50·age) · empty seg falls" },
		"rhyme": { "name": "Behemoth", "hint": "five phases, a four-second intro that fills them one by one, and twice the shake — the raid boss whose bar is a ceremony",
			"dials": { "phases": 5, "intro": 4, "shake": 12 } } },
]

const FAINT := Color(0.91, 0.898, 0.957, 0.55)   # the web label's default ink
const INK_DARK := Color("131020")                  # eyes, the darkest ink
const PANEL := Color("262040")                     # icon and badge faces
const CARD := Color("221D38")                      # the jewel card's face
const BOX := Color(20.0 / 255.0, 16.0 / 255.0, 38.0 / 255.0, 0.92)   # bubbles and toasts
const HIST_N := 120                                # samples in the small history graphs

# ---------------------------------------------------------------- small maths

## The web kit's ease(): a clamped smoothstep.
static func _ease(k: float) -> float:
	k = clampf(k, 0.0, 1.0)
	return k * k * (3.0 - 2.0 * k)

## c with its alpha replaced (the web's rgba(c, a)).
static func _al(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, a)

## Comma grouping: 12480 → "12,480" (the web's fmt()).
static func _fmt(v: float) -> String:
	var digits := str(roundi(absf(v)))
	var out := ""
	var cnt := 0
	var i := digits.length() - 1
	while i >= 0:
		out = digits[i] + out
		cnt += 1
		if cnt % 3 == 0 and i > 0:
			out = "," + out
		i -= 1
	return ("-" if v < 0.0 else "") + out

## The pixel width of txt at a font size (the web's ctx.measureText).
static func _measure(txt: String, size: float) -> float:
	return ThemeDB.fallback_font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(1, int(size))).x

# ---------------------------------------------------------------- drawing pocket

## The web's label(txt, x, y, col, align): 10 px, left / center / right.
static func _lab(n: CanvasItem, b: Dictionary, txt: String, p: Vector2, col: Color = FAINT, align: String = "left") -> void:
	match align:
		"center":
			Kit.label(n, b, txt, p, col, true)
		"right":
			Kit.label(n, b, txt, Vector2(p.x - _measure(txt, 10.0), p.y), col)
		_:
			Kit.label(n, b, txt, p, col)

## The web's text(txt, x, y, size, col, align): a float size, three alignments.
static func _txt(n: CanvasItem, txt: String, p: Vector2, size: float, col: Color = Kit.INK, align: String = "left") -> void:
	var sz := maxi(1, int(size))
	match align:
		"center":
			Kit.text(n, txt, p, sz, col, true)
		"right":
			Kit.text(n, txt, Vector2(p.x - _measure(txt, size), p.y), sz, col)
		_:
			Kit.text(n, txt, p, sz, col)

## An outlined rectangle (ctx.strokeRect).
static func _stroke_rect(n: CanvasItem, r: Rect2, col: Color, w: float = 1.0) -> void:
	if r.size.x <= 0.0 or r.size.y <= 0.0:
		return
	n.draw_rect(r, col, false, w)

## The web's setLineDash([on, off]) on one line: short strokes.
static func _dash(n: CanvasItem, a: Vector2, c: Vector2, col: Color, w: float = 1.0, on: float = 2.0, off: float = 3.0) -> void:
	var d := a.distance_to(c)
	if d < 0.5:
		return
	var u := (c - a) / d
	var pos := 0.0
	var guard := 0
	while pos < d and guard < 400:
		n.draw_line(a + u * pos, a + u * minf(d, pos + on), col, w)
		pos += on + off
		guard += 1

## A dashed rectangle outline.
static func _dash_rect(n: CanvasItem, r: Rect2, col: Color, w: float = 1.0) -> void:
	var p0 := r.position
	var p1 := Vector2(r.end.x, r.position.y)
	var p2 := r.end
	var p3 := Vector2(r.position.x, r.end.y)
	_dash(n, p0, p1, col, w)
	_dash(n, p1, p2, col, w)
	_dash(n, p2, p3, col, w)
	_dash(n, p3, p0, col, w)

## A dashed ring: 3 px on, 4 px off, as short arcs.
static func _dash_ring(n: CanvasItem, c: Vector2, r: float, col: Color, w: float = 1.0) -> void:
	r = maxf(1.0, r)
	var step := 7.0 / r
	var a := 0.0
	var guard := 0
	while a < TAU and guard < 200:
		n.draw_arc(c, r, a, minf(TAU, a + 3.0 / r), 3, col, w)
		a += step
		guard += 1

## A rounded rectangle as a polygon (the web's rr() path).
static func _rr_pts(r: Rect2, rad: float) -> PackedVector2Array:
	rad = clampf(rad, 0.0, minf(r.size.x, r.size.y) / 2.0)
	var pts := PackedVector2Array()
	var centres := [Vector2(r.end.x - rad, r.position.y + rad), Vector2(r.end.x - rad, r.end.y - rad),
		Vector2(r.position.x + rad, r.end.y - rad), Vector2(r.position.x + rad, r.position.y + rad)]
	for q in 4:
		var c: Vector2 = centres[q]
		for i in 5:
			var a := -TAU / 4.0 + q * TAU / 4.0 + i / 4.0 * TAU / 4.0
			pts.append(c + Vector2(cos(a), sin(a)) * rad)
	return pts

static func _rr_fill(n: CanvasItem, r: Rect2, rad: float, col: Color) -> void:
	if r.size.x <= 0.5 or r.size.y <= 0.5:
		return
	n.draw_colored_polygon(_rr_pts(r, rad), col)

static func _rr_stroke(n: CanvasItem, r: Rect2, rad: float, col: Color, w: float = 1.0) -> void:
	if r.size.x <= 0.5 or r.size.y <= 0.5:
		return
	var pts := _rr_pts(r, rad)
	pts.append(pts[0])
	n.draw_polyline(pts, col, w)

## A filled pie slice from a0 to a1 (either direction) — ctx.arc + closePath + fill.
static func _pie(n: CanvasItem, c: Vector2, r: float, a0: float, a1: float, col: Color) -> void:
	var span := a1 - a0
	if absf(span) < 1e-4 or r < 0.5:
		return
	var steps := maxi(2, int(ceilf(absf(span) / (TAU / 48.0))))
	var pts := PackedVector2Array([c])
	for i in steps + 1:
		var a := a0 + span * i / float(steps)
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	n.draw_colored_polygon(pts, col)

## The distance from p along angle a to the edge of rect r (p inside r) —
## the painter's clip: a fan whose rim is this distance traces the rectangle.
static func _rect_ray(p: Vector2, a: float, r: Rect2) -> float:
	var d := Vector2(cos(a), sin(a))
	var best := INF
	if d.x > 1e-6:
		best = minf(best, (r.end.x - p.x) / d.x)
	elif d.x < -1e-6:
		best = minf(best, (r.position.x - p.x) / d.x)
	if d.y > 1e-6:
		best = minf(best, (r.end.y - p.y) / d.y)
	elif d.y < -1e-6:
		best = minf(best, (r.position.y - p.y) / d.y)
	return maxf(0.0, best) if is_finite(best) else 0.0

## A pie slice from a0 to a1 clipped to rect r (the sector's rim follows the
## rectangle's edge; corner angles are inserted so the corners stay sharp).
static func _pie_in_rect(n: CanvasItem, c: Vector2, a0: float, a1: float, r: Rect2, col: Color, reach: float = INF) -> void:
	var span := a1 - a0
	if absf(span) < 1e-4:
		return
	var sgn := signf(span)
	var angles: Array = []
	var steps := maxi(2, int(ceilf(absf(span) / (TAU / 64.0))))
	for i in steps + 1:
		angles.append(a0 + span * i / float(steps))
	for corner in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
		var ca := atan2((corner as Vector2).y - c.y, (corner as Vector2).x - c.x)
		for k: float in [-1.0, 0.0, 1.0]:            # the corner's angle, wrapped into the sweep
			var cc := ca + k * TAU
			if (cc - a0) * sgn > 0.0 and (cc - a1) * sgn < 0.0:
				angles.append(cc)
	if sgn > 0.0:
		angles.sort()
	else:
		angles.sort()
		angles.reverse()
	var pts := PackedVector2Array([c])
	for a in angles:
		var aa: float = a
		pts.append(c + Vector2(cos(aa), sin(aa)) * minf(reach, _rect_ray(c, aa, r)))
	n.draw_colored_polygon(pts, col)

## A stroked elliptical arc (ctx.ellipse … stroke).
static func _ell_arc(n: CanvasItem, c: Vector2, rx: float, ry: float, a0: float, a1: float, col: Color, w: float) -> void:
	var span := a1 - a0
	var steps := maxi(3, int(ceilf(absf(span) / (TAU / 64.0))))
	var pts := PackedVector2Array()
	for i in steps + 1:
		var a := a0 + span * i / float(steps)
		pts.append(c + Vector2(cos(a) * maxf(1.0, rx), sin(a) * maxf(1.0, ry)))
	n.draw_polyline(pts, col, w)

## Sutherland–Hodgman: a convex polygon clipped to a rectangle (the sheen band ∩ the card).
static func _clip_poly_rect(pts: Array, r: Rect2) -> Array:
	var out: Array = pts.duplicate()
	for side in 4:
		var inp: Array = out
		out = []
		if inp.is_empty():
			break
		var prev: Vector2 = inp[inp.size() - 1]
		for cur_v in inp:
			var cur: Vector2 = cur_v
			var cin := _inside_side(cur, side, r)
			var pin := _inside_side(prev, side, r)
			if cin:
				if not pin:
					out.append(_isect_side(prev, cur, side, r))
				out.append(cur)
			elif pin:
				out.append(_isect_side(prev, cur, side, r))
			prev = cur
	return out

static func _inside_side(p: Vector2, side: int, r: Rect2) -> bool:
	match side:
		0: return p.x >= r.position.x
		1: return p.x <= r.end.x
		2: return p.y >= r.position.y
		_: return p.y <= r.end.y

static func _isect_side(a: Vector2, c: Vector2, side: int, r: Rect2) -> Vector2:
	var d := c - a
	match side:
		0, 1:
			var x := r.position.x if side == 0 else r.end.x
			var k := 0.0 if absf(d.x) < 1e-9 else (x - a.x) / d.x
			return Vector2(x, a.y + d.y * k)
		_:
			var y := r.position.y if side == 2 else r.end.y
			var k := 0.0 if absf(d.y) < 1e-9 else (y - a.y) / d.y
			return Vector2(a.x + d.x * k, y)

## Greedy word wrap into at most three lines at a font size (Anchor's wrap()).
static func _wrap_words(txt: String, max_w: float, size: float) -> Array:
	var out: Array = []
	var ws := txt.split(" ")
	var cur := ""
	for w in ws:
		var try_s := (cur + " " + w) if cur != "" else w
		if _measure(try_s, size) > max_w and cur != "":
			out.append(cur)
			cur = w
		else:
			cur = try_s
		if out.size() == 3:
			break
	if cur != "" and out.size() < 3:
		out.append(cur)
	return out

# ---------------------------------------------------------------- per-card machines

## Healthbar: change hp by d; the ghost starts its wait.
static func _hb_change(b: Dictionary, d: float) -> void:
	var D: Dictionary = b.D
	b.hp = clampf(b.hp + d, 0.0, float(D.max))
	b.since = 0.0
	b.chunk = absf(b.ghost - b.hp)

static func _hb_hit(b: Dictionary) -> void:
	var D: Dictionary = b.D
	_hb_change(b, -randf_range(float(D.hitMin), float(D.hitMax)))
	b.hurt = 0.35

## Radial: the x of icon i.
static func _rad_x(b: Dictionary, i: int) -> float:
	var nn: int = (b.rem as Array).size()
	return b.w * (0.5 + (i - (nn - 1) / 2.0) * 0.27)

## Radial: use ability i (a refusal jiggle when it is not ready).
static func _rad_use(b: Dictionary, i: int, by_hand: bool) -> void:
	var D: Dictionary = b.D
	var rem: Array = b.rem
	if float(rem[i]) > 0.0:
		b.jig[i] = 0.3
		return
	var cds: Array = D.cooldowns
	rem[i] = float(cds[i])
	b.bursts.append({ "i": i, "age": 0.0 })
	if (b.bursts as Array).size() > 8:
		b.bursts.pop_front()
	if by_hand:
		Kit.beep(520.0 + i * 140.0, 0.07, "triangle")

## Odometer: a gain — the tween restarts from the value SHOWN, not the old target.
static func _odo_add(b: Dictionary, v: float, hand: bool) -> void:
	var D: Dictionary = b.D
	b.from = b.shown
	b.target += v
	b.k = 0.0
	b.punchT = 0.0
	b.pops.append({ "n": v, "age": 0.0 })
	if (b.pops as Array).size() > 5:
		b.pops.pop_front()
	if D.snap:
		b.shown = b.target
	if hand:
		Kit.beep(880.0, 0.06, "square")

## Xpbar: need(L) = base · growth^(L−1).
static func _xp_need(b: Dictionary, L: int) -> float:
	var D: Dictionary = b.D
	return roundf(float(D.base) * pow(float(D.growth), L - 1))

static func _xp_gain(b: Dictionary, v: float) -> void:
	b.xp += v
	b.pops.append({ "n": v, "age": 0.0 })
	if (b.pops as Array).size() > 5:
		b.pops.pop_front()

## Offscreen: a target at bearing a, with its own speed, wobble phase and colour.
static func _off_add(b: Dictionary, a: float) -> void:
	var D: Dictionary = b.D
	var cols := [Kit.HOT, Kit.SUN, Kit.MAGIC, Kit.GOOD]
	var targets: Array = b.targets
	targets.append({ "a": a, "w": randf_range(0.6, 1.4) * float(D.speed) * (-1.0 if randf() < 0.5 else 1.0),
		"ph": randf_range(0.0, TAU), "wf": randf_range(0.3, 0.7), "c": cols[targets.size() % 4], "x": 0.0, "y": 0.0 })
	if targets.size() > 8:
		targets.pop_front()

## Xhair: one shot, landed uniformly inside the spread disc (√rand keeps it uniform).
static func _xh_fire(b: Dictionary) -> void:
	var D: Dictionary = b.D
	var r: float = b.spread * sqrt(randf())
	var a := randf() * TAU
	var sx: float = b.cx + cos(a) * r
	var sy: float = b.cy + sin(a) * r
	b.shots += 1
	if Vector2(sx - b.tx, sy - b.ty).length() < b.h * float(D.targetR):
		b.hits += 1
		b.marker = 0.0
	b.holes.append({ "x": sx, "y": sy, "age": 0.0 })
	if (b.holes as Array).size() > 40:
		b.holes.pop_front()
	b.spread = minf(float(D.spreadMax), b.spread + float(D.bloom))

## Damagearc: a hit from angle ang (src = the attacker's index, −1 for a projectile).
static func _da_hit_from(b: Dictionary, ang: float, src: int) -> void:
	var D: Dictionary = b.D
	b.arcs.append({ "ang": ang, "age": 0.0, "src": src })
	if (b.arcs as Array).size() > 10:
		b.arcs.pop_front()
		b.last = maxi(-1, b.last - 1)
	b.hp = maxf(0.0, b.hp - float(D.dmg))
	b.hurt = 0.3
	b.last = (b.arcs as Array).size() - 1

## Toast: queue a random message.
static func _toast_post(b: Dictionary) -> void:
	var msgs: Array = b.msgs
	b.queue.append(msgs[randi() % msgs.size()])
	if (b.queue as Array).size() > 6:
		b.queue.pop_front()

## Minimap: an enemy at (x, y) — some are sitters that rest longer.
static func _mm_add_enemy(b: Dictionary, x: float, y: float) -> void:
	b.en.append({ "x": x, "y": y, "tx": x, "ty": y, "rest": randf_range(0.0, 3.0), "moving": false,
		"seenAt": -99.0, "sitter": randf() < 0.35 })
	if (b.en as Array).size() > 12:
		b.en.pop_front()

## Ghostplacement: does a w × h footprint at (gx, gy) fit? Fills b.bad with the cells it overlaps.
static func _gp_fits(b: Dictionary, gx: int, gy: int, w: int, h: int) -> bool:
	var cols: int = b.cols
	var rows: int = b.rows
	var occ: Array = b.occ
	var bad: Array = []
	var ok := gx >= 0 and gy >= 0 and gx + w <= cols and gy + h <= rows
	for j in h:
		for i in w:
			var cx := gx + i
			var cy := gy + j
			if cx < 0 or cy < 0 or cx >= cols or cy >= rows:
				continue
			if int(occ[cy * cols + cx]) != 0:
				ok = false
				bad.append(Vector2i(cx, cy))
	b.bad = bad
	return ok

static func _gp_place(b: Dictionary, gx: int, gy: int, w: int, h: int) -> void:
	var cols: int = b.cols
	var palette: Array = b.palette
	for j in h:
		for i in w:
			b.occ[(gy + j) * cols + gx + i] = 1
	b.pieces.append({ "gx": gx, "gy": gy, "w": w, "h": h, "c": palette[b.nColor % palette.size()], "age": 0.0 })
	b.nColor += 1
	b.filled += w * h

static func _gp_rotate(b: Dictionary) -> void:
	var q: int = b.pw
	b.pw = b.ph
	b.ph = q

## Jewel: a weighted tier pick.
static func _jw_pick(b: Dictionary) -> int:
	var D: Dictionary = b.D
	var odds: Array = D.odds
	var r := randf()
	var acc := 0.0
	for i in odds.size():
		acc += float(odds[i])
		if r < acc:
			return i
	return 0

## Jewel: reroll every card — the tier swaps at the half-turn (see tick).
static func _jw_roll(b: Dictionary) -> void:
	var D: Dictionary = b.D
	var star := randi() % 4
	for i in 4:
		var c: Dictionary = b.cards[i]
		if D.junk:
			c.next = (1 + randi() % 3) if i == star else 0
		else:
			c.next = _jw_pick(b)
		c.flip = 0.0

## Bossbar: the bar's geometry.
static func _bb_geom(b: Dictionary) -> Dictionary:
	var D: Dictionary = b.D
	var phases: int = D.phases
	var bw: float = b.w * 0.8
	var gap := 3.0
	return { "bx": b.w * 0.1, "bw": bw, "by": b.h * 0.15, "bh": b.h * 0.06, "gap": gap, "sw": (bw - gap * (phases - 1)) / phases }

static func _bb_reset(b: Dictionary) -> void:
	var D: Dictionary = b.D
	var phases: int = D.phases
	b.state = "intro"
	b.st = 0.0
	b.seg = []
	for _i in phases:
		b.seg.append(1.0)
	b.cur = phases - 1
	b.falling = []

static func _bb_hit(b: Dictionary) -> void:
	var D: Dictionary = b.D
	if b.state != "fight":
		return
	b.shakeAge = 0.0
	b.flash = 0.0
	b.slash = 0.0
	var cur: int = b.cur
	var seg: Array = b.seg
	seg[cur] = float(seg[cur]) - randf_range(float(D.dmgMin), float(D.dmgMax)) / b.hpPer
	if float(seg[cur]) <= 0.0:                          # the segment breaks off
		seg[cur] = 0.0
		var g := _bb_geom(b)
		b.falling.append({ "i": cur, "x": g.bx + cur * (g.sw + g.gap), "y": g.by, "w": g.sw, "h": g.bh,
			"vx": randf_range(20.0, 60.0), "vy": -randf_range(40.0, 90.0), "rot": 0.0, "vr": randf_range(-4.0, 4.0), "age": 0.0 })
		if (b.falling as Array).size() > 6:
			b.falling.pop_front()
		b.cur = cur - 1
		if b.cur < 0:
			b.state = "dead"
			b.st = 0.0

# ---------------------------------------------------------------- init

static func init(b: Dictionary) -> void:
	var D: Dictionary = b.D
	var W: float = b.w
	var H: float = b.h
	var GY: float = b.gy
	b.armed_sound = false                                # sound only after the card's first press
	match b.id:
		"healthbar":
			# the lexicon's Lerp card taught the lag; here the lag IS the information.
			# the red bar snaps to hp the instant a hit lands (the truth, never late).
			# a second value, the GHOST, remembers where the bar WAS: it waits a beat
			# (delay) and then slides to hp over drain seconds, so the white gap
			# between them is the damage you just took, held on screen long enough to
			# read. a heal is the same machine mirrored: hp jumps up, the ghost lags
			# below it, and the gap is painted green — "this much is arriving".
			b.hp = float(D.max)
			b.ghost = float(D.max)
			b.since = 9.0
			b.chunk = 0.0
			b.hitT = 0.6
			b.healT = 2.0
			b.hurt = 0.0
			b.hist = []                                  # hp, ghost pairs — the last 3 s
			for _i in HIST_N:
				b.hist.append(float(D.max))
				b.hist.append(float(D.max))
			b.head = 0
			b.sampleT = 0.0
		"radial":
			# chapter 03's masks, on a clock. the locked part of the icon is a dark
			# PIE SLICE: one arc from the top (−90°) sweeping an angle proportional to
			# the time left — remaining / cooldown of a full turn — clipped to the
			# icon. as the number falls the slice thins, its leading edge is the hand
			# of a clock, and at zero the icon POPS (a scale punch and a ring, the
			# bestiary's Radiant decay) so the eye is told "ready" without reading.
			var cds: Array = D.cooldowns
			b.rem = []
			b.pop = []
			b.jig = []
			b.bursts = []
			for i in cds.size():
				b.rem.append(0.0 if i == 0 else float(cds[i]) * (0.3 + 0.3 * i))
				b.pop.append(9.0)
				b.jig.append(0.0)
			b.autoT = 0.0
		"odometer":
			# a COUNT-UP is a tween between two numbers: k runs 0 → 1 over tween
			# seconds, an ease-out (1 − (1 − k)³) makes the last digits settle
			# slowly, and the number you draw is shown, never the target. the
			# drums are the folio's Odometer: the ones drum slides by frac(shown);
			# a higher drum only slides during the last tenth of the drum beneath
			# it — the CARRY, drawn. commas are placed every third drum from the right.
			b.target = 12480.0
			b.from = b.target
			b.shown = b.target
			b.k = 1.0
			b.autoT = 0.0
			b.punchT = 9.0
			b.pops = []
		"xpbar":
			# two numbers: xp (the truth, it may run far past the bar) and shown (the
			# bar, which fills toward xp at a steady rate). when shown reaches the
			# threshold the bar FLASHES, the level ticks, and BOTH subtract need — the
			# remainder is carried into the next bar, which is longer, because
			# need(L) is a geometric series. a big gain can lap several bars in a row:
			# each lap is one flash, one carry. the column of light is the folio's Levelup.
			b.level = 1
			b.xp = 0.0
			b.shown = 0.0
			b.flashT = 9.0
			b.upT = 9.0
			b.autoT = 0.0
			b.carry = 0.0
			b.carryT = 9.0
			b.pops = []
		"offscreen":
			# the lexicon's Xhair aimed at a thing on screen; this is for the thing
			# that is not. the middle rectangle is the VIEW (the player's screen); the
			# targets live in the world around it. CLAMP each target's position into
			# the view (minus a margin) — that is where its arrow sits — and point
			# the arrow along the vector from the clamped point back to the true
			# position; that vector's length is the distance you print. a target that
			# wanders into the view needs no arrow, so it simply gets drawn.
			b.view = Rect2(W * 0.22, H * 0.17, W * 0.56, H * 0.63)
			b.cx = W * 0.5
			b.cy = (H * 0.17 + H * 0.8) / 2.0
			b.targets = []
			var nt: int = D.targets
			for i in nt:
				_off_add(b, i * TAU / maxi(1, nt) + 0.4)
		"anchor":
			# the grimoire's Dialogue box sat still; a game's bubbles are pinned to
			# moving things. every frame: PROJECT the speaker's world x to the screen
			# (sx = wx − cam), put the box above the head, then CLAMP the box inside
			# the view — the tail is drawn last, from the box's bottom edge (its base
			# clamped inside the box) to the head, so it stretches and leans instead
			# of leaving. an off-screen speaker keeps a box at the edge, tail pointing out.
			var WORLD: float = W * float(D.world)
			b.WORLD = WORLD
			var sr := Kit.rng(11)
			var names := ["Mira", "Otto", "Pip", "Sol", "Vex"]
			var shirts := [Kit.HERO, Kit.GOOD, Kit.MAGIC, Kit.SUN, Kit.HOT]
			var lines := [["hello there!", "the box clamps to the view", "my tail stays on me"],
				["pan the camera", "not the words", "world → screen, every frame"],
				["sx = wx − cam", "that is the projection", "bye!"], ["still anchored", "even off-screen"], ["look up"]]
			var ns: int = D.speakers
			b.sp = []
			for i in ns:
				b.sp.append({ "wx": WORLD * (0.12 + 0.76 * (i / float(ns - 1) if ns > 1 else 0.5)), "name": names[i % 5],
					"shirt": shirts[i % 5], "set": lines[i % 5], "li": 0, "prog": i * 3.0, "hold": 0.0, "face": -1 if i % 2 == 1 else 1 })
			b.props = []
			for _i in 14:
				var wx := sr.randf() * WORLD
				var kind := 0 if sr.randf() < 0.6 else (1 if sr.randf() < 0.5 else 2)
				b.props.append({ "wx": wx, "kind": kind, "s": 0.6 + sr.randf() * 0.6 })
			b.cam = 0.0
			b.camT = 0.0
			b.lastPress = -9.0
		"xhair":
			# the lexicon's Xhair followed a target; this one tells the truth about
			# aim. SPREAD is a radius: every shot adds bloom to it, every idle second
			# takes recover off it, clamped between min and max — so the reticle's
			# four ticks walk outward while you hold fire and creep back when you
			# stop. each shot lands at a random point INSIDE that disc (√rand keeps
			# it uniform). a shot inside the bullseye paints the HIT MARKER: four
			# short diagonals that flash for marker seconds. the graph is spread(t).
			b.cx = W / 2.0
			b.cy = H * 0.45
			b.spread = float(D.spreadMin)
			b.lastPress = -9.0
			b.acc = 0.0
			b.autoT = 1.5
			b.pending = 0
			b.shots = 0
			b.hits = 0
			b.marker = 9.0
			b.holding = false
			b.tx = b.cx
			b.ty = b.cy
			b.holes = []
			b.hist = []
			for _i in HIST_N:
				b.hist.append(0.0)
			b.head = 0
			b.sampleT = 0.0
		"damagearc":
			# the atlas's Vignette darkened every edge equally; this one darkens ONE
			# direction. when a hit lands, take the angle from the player to the
			# attacker (atan2), and stroke an arc of width radians around that angle
			# on an ellipse hugging the screen's edge. the arc's alpha is 1 − age/fade,
			# and while its attacker is alive the angle is re-read every frame, so the
			# arc TURNS with them — you learn where they are, not where they were.
			# below ringBelow health the whole ellipse pulses: the low-health ring.
			b.px = W / 2.0
			b.feet = GY - H * 0.04
			b.chest = b.feet - 9.0 * maxf(2.0, roundf(H / 60.0))
			b.att = []
			b.arcs = []
			b.shots = []
			var na: int = D.attackers
			for i in na:
				b.att.append({ "a": i * TAU / na, "w": randf_range(0.3, 0.6) * (1.0 if i % 2 == 1 else -1.0), "lunge": 9.0, "x": 0.0, "y": 0.0 })
			b.hp = 1.0
			b.hitT = 0.0
			b.hurt = 0.0
			b.last = -1
		"toast":
			# the grimoire's Rise up was one phrase arriving; a toast system is a
			# QUEUE feeding a small number of SLOTS. a new toast takes slot 0 (the
			# bottom) and the older ones are pushed up — each toast's y is a target
			# (base − i·(h + gap)) that it lerps toward, so the push is a motion, not
			# a jump. x eases in over slide seconds, holds for life, eases out; when a
			# slot frees, the queue's head moves in. the ticker is the same queue on
			# one line: items append to the right and scroll left until they are gone.
			b.msgs = [["+25 gold", Kit.SUN], ["quest updated", Kit.HERO], ["achievement: first blood", Kit.MAGIC],
				["Mira joined the party", Kit.GOOD], ["low battery", Kit.HOT], ["autosaving…", Kit.BONE],
				["new recipe: ember stew", Kit.SUN], ["3 unread letters", Kit.HERO], ["level 7 reached", Kit.MAGIC], ["storm incoming", Kit.HOT]]
			b.queue = []
			b.live = []
			b.tk = []                                    # the ticker's items on the line
			b.autoT = 0.0
		"minimap":
			# the lexicon's Camera drew a world strip; a MINIMAP is the same idea in
			# two axes: map = origin + world · k, one multiply per point. the radar
			# SWEEP is the bestiary's Lighthouse turned into a rule: a blip is only
			# stamped when the sweep angle crosses its bearing from the player, then
			# its alpha decays until the next pass — so what you see is a memory,
			# period seconds stale at worst. the motion tracker is a different rule
			# on the same map: a blip shows only while its enemy moves.
			var sr := Kit.rng(5)
			b.yTop = GY - H * 0.26
			b.yBot = H - 8.0
			b.en = []
			b.trees = []
			for _i in 5:
				b.trees.append({ "x": sr.randf() * W, "y": b.yTop - 10.0 + sr.randf() * 20.0, "s": 0.14 + sr.randf() * 0.06 })
			var nb: int = D.blips
			for _i in nb:
				_mm_add_enemy(b, randf_range(W * 0.05, W * 0.95), randf_range(b.yTop, b.yBot))
			b.hx = W * 0.3
			b.hdir = 1
			b.sweep = 0.0
			b.prevSweep = 0.0
			var k: float = D.size
			b.k = k
			b.map = Rect2(W - W * k - 6.0, 6.0, W * k, H * k)
		"ghostplacement":
			# the lexicon's Grid quantised a position; a PLACEMENT GHOST quantises a
			# whole footprint. the cursor is continuous; the ghost's cell is
			# round((x − ox)/cell − w/2), and its VALIDITY is one test — inside the
			# grid, and no footprint cell already occupied (a byte per cell). the
			# tint is chapter 03's: the same shape painted green or red tells the
			# rule before you press. letting go places; a blocked spot rotates instead.
			var cell := maxf(6.0, H * float(D.cell))
			var cols := maxi(4, floori(W * 0.92 / cell))
			var rows := maxi(3, floori(H * 0.64 / cell))
			b.cell = cell
			b.cols = cols
			b.rows = rows
			b.ox = (W - cols * cell) / 2.0
			b.oy = H * 0.14
			b.occ = []
			for _i in cols * rows:
				b.occ.append(0)
			b.pieces = []
			b.palette = [Kit.SUN, Kit.HERO, Kit.MAGIC, Color("8A6A3E"), Kit.GOOD]
			b.bad = []
			b.pw = int(D.pieceW)
			b.ph = int(D.pieceH)
			b.fx = W / 2.0
			b.fy = H / 2.0
			b.tx = b.fx
			b.ty = b.fy
			b.heldT = 0.0
			b.autoT = 0.0
			b.lastPress = -9.0
			b.filled = 0
			b.clearedT = 9.0
			b.nColor = 0
			b.gx = 0
			b.gy_ = 0                                    # the ghost's cell row (b.gy is the ground line)
			b.valid = false
			var sr := Kit.rng(3)
			var prefill: int = D.prefill
			var tries := 0
			while tries < prefill * 6 and (b.pieces as Array).size() < prefill:
				tries += 1
				var pw: int = b.pw
				var ph: int = b.ph
				var w: int = pw if sr.randf() < 0.5 else ph
				var h: int = ph if w == pw else pw
				var gx := floori(sr.randf() * cols)
				var gy := floori(sr.randf() * rows)
				if _gp_fits(b, gx, gy, w, h):
					_gp_place(b, gx, gy, w, h)
			b.bad = []
		"jewel":
			# rarity is a lookup: tier → colour, and tier → how much light the card
			# is allowed. the SHEEN is the bestiary's Chrome sweep: a diagonal band
			# whose position u runs 0 → 1 over period seconds, used as a CLIP — inside
			# it the border is re-stroked white and the face brightened; outside it
			# nothing. common cards never sweep; epic and legendary also get a
			# breathing glow behind them. a reroll flips each card on its x axis and
			# swaps the tier at the half-turn, when the card is edge-on.
			b.cards = []
			for i in 4:
				b.cards.append({ "tier": i, "next": i, "flip": 9.0 })
			b.autoT = 0.0
			_jw_roll(b)
			for i in 4:
				var c: Dictionary = b.cards[i]
				c.tier = c.next
				c.flip = 9.0
		"bossbar":
			# three moments, three mechanisms. the INTRO is a tween: an eased clock
			# from 0 to phases, and segment i is as full as clamp(clock − i, 0, 1) —
			# they fill one after another. a HIT is the grimoire's Earthquake on the
			# bar alone: dx = shake · e^(−decay·age) · sin(50·age), a ring that dies.
			# a PHASE ends when its segment empties: the segment becomes a falling
			# body (velocity, gravity, spin, fade — the bestiary's Ice cracks) and the
			# next one takes the hits. the boss is one big shape with a flash tint.
			b.shakeAge = 9.0
			b.flash = 9.0
			b.hitT = 0.0
			b.slash = 9.0
			b.hpPer = 100.0 / maxi(1, int(D.phases))
			_bb_reset(b)

# ---------------------------------------------------------------- press

static func press(b: Dictionary, pos: Vector2) -> void:
	var D: Dictionary = b.D
	var W: float = b.w
	b.armed_sound = true
	match b.id:
		"healthbar":
			_hb_hit(b)
		"radial":
			var best := 0
			var bd := 1e9
			for i in (b.rem as Array).size():
				var d := absf(_rad_x(b, i) - pos.x)
				if d < bd:
					bd = d
					best = i
			_rad_use(b, best, true)
		"odometer":
			_odo_add(b, roundf(randf_range(float(D.gainMin), float(D.gainMax))), true)
		"xpbar":
			_xp_gain(b, roundf(randf_range(float(D.gainMin), float(D.gainMax))))
		"offscreen":
			_off_add(b, atan2(pos.y - b.cy, pos.x - b.cx))
		"anchor":
			b.camT = clampf(pos.x / W, 0.0, 1.0) * (b.WORLD - W)
			b.lastPress = b.t
		"xhair":
			b.cx = pos.x
			b.cy = pos.y
			if b.t - b.lastPress > 0.3:                  # the first shot of a hold lands at once
				_xh_fire(b)
				b.acc = 0.0
			b.lastPress = b.t
		"damagearc":
			b.shots.append({ "x": pos.x, "y": pos.y, "age": 0.0, "ang": atan2(pos.y - b.chest, pos.x - b.px) })
			if (b.shots as Array).size() > 6:
				b.shots.pop_front()
		"toast":
			_toast_post(b)
		"minimap":
			var wx := pos.x
			var wy := pos.y
			var map: Rect2 = b.map
			if map.has_point(pos):                       # a press on the map lands in the world it scales
				wx = (pos.x - map.position.x) / b.k
				wy = (pos.y - map.position.y) / b.k
			_mm_add_enemy(b, clampf(wx, 4.0, W - 4.0), clampf(wy, b.yTop, b.yBot))
		"ghostplacement":
			b.tx = pos.x
			b.ty = pos.y
			if b.t - b.lastPress > 0.3:
				b.fx = pos.x
				b.fy = pos.y
			b.lastPress = b.t
			b.heldT = 0.15
		"jewel":
			_jw_roll(b)
		"bossbar":
			_bb_hit(b)

# ---------------------------------------------------------------- tick

static func tick(b: Dictionary, dt: float, t: float) -> void:
	var D: Dictionary = b.D
	var W: float = b.w
	var H: float = b.h
	match b.id:
		"healthbar":
			b.hitT += dt
			if b.hitT > float(D.hitEvery):
				b.hitT = 0.0
				_hb_hit(b)
			b.healT += dt
			if b.healT > float(D.healEvery) or (b.hp <= 0.0 and b.healT > 1.2):
				b.healT = 0.0
				_hb_change(b, float(D.heal))
			b.since += dt
			b.hurt = maxf(0.0, b.hurt - dt)
			if b.ghost != b.hp and b.since >= float(D.delay):   # the ghost: wait, then cross the chunk
				var v: float = (maxf(b.chunk, 1.0) / maxf(0.01, float(D.drain))) * dt
				b.ghost = maxf(b.hp, b.ghost - v) if b.ghost > b.hp else minf(b.hp, b.ghost + v)
			b.sampleT += dt
			var nn := 0
			while b.sampleT > 0.025 and nn < 8:
				b.sampleT -= 0.025
				b.hist[b.head * 2] = b.hp
				b.hist[b.head * 2 + 1] = b.ghost
				b.head = (b.head + 1) % HIST_N
				nn += 1
		"radial":
			var rem: Array = b.rem
			var nn := rem.size()
			b.autoT += dt
			if b.autoT > float(D.autoEvery):             # autopilot: use something that is ready
				b.autoT = 0.0
				var ready: Array = []
				for i in nn:
					if float(rem[i]) <= 0.0:
						ready.append(i)
				if not ready.is_empty():
					_rad_use(b, ready[randi() % ready.size()], false)
			for i in nn:
				if float(rem[i]) > 0.0:
					rem[i] = float(rem[i]) - dt
					if float(rem[i]) <= 0.0:
						rem[i] = 0.0
						b.pop[i] = 0.0
				b.pop[i] = float(b.pop[i]) + dt
				b.jig[i] = maxf(0.0, float(b.jig[i]) - dt)
			var bursts: Array = b.bursts
			var j := bursts.size() - 1
			while j >= 0:
				var k: Dictionary = bursts[j]
				k.age += dt
				if k.age > 0.5:
					bursts.remove_at(j)
				j -= 1
		"odometer":
			b.autoT += dt
			if b.autoT > float(D.autoEvery):
				b.autoT = 0.0
				_odo_add(b, roundf(randf_range(float(D.gainMin), float(D.gainMax))), false)
			var cap := pow(10.0, float(D.digits))
			if b.target >= cap:
				b.target = fmod(b.target, cap)
				b.from = 0.0
				b.shown = b.target
				b.k = 1.0
			if D.snap:
				b.shown = b.target
				b.k = 1.0
			else:
				b.k = minf(1.0, b.k + dt / maxf(0.01, float(D.tween)))
				b.shown = b.from + (b.target - b.from) * (1.0 - pow(1.0 - b.k, 3.0))
			b.punchT += dt
			var pops: Array = b.pops
			var j := pops.size() - 1
			while j >= 0:
				var p: Dictionary = pops[j]
				p.age += dt
				if p.age > 1.2:
					pops.remove_at(j)
				j -= 1
		"xpbar":
			b.autoT += dt
			if b.autoT > float(D.autoEvery):
				b.autoT = 0.0
				_xp_gain(b, roundf(randf_range(float(D.gainMin), float(D.gainMax))))
			var nd := _xp_need(b, b.level)
			var rate := nd / maxf(0.05, float(D.fillTime))
			if b.shown < b.xp:
				b.shown = minf(b.xp, b.shown + rate * dt)
			if b.shown >= nd - 1e-6 and b.xp >= nd:      # LEVEL UP: flash, tick, carry the rest
				b.xp -= nd
				b.shown = 0.0
				b.level += 1
				b.flashT = 0.0
				b.upT = 0.0
				b.carry = b.xp
				b.carryT = 0.0
				if b.armed_sound:
					Kit.tone({ "freq": 523.0, "slide_to": 1046.0, "dur": 0.22, "type": "triangle", "vol": 0.1 })
				if b.level > 40:
					b.level = 1
					b.xp = minf(b.xp, 40.0)
			b.flashT += dt
			b.upT += dt
			b.carryT += dt
			var pops: Array = b.pops
			var j := pops.size() - 1
			while j >= 0:
				var p: Dictionary = pops[j]
				p.age += dt
				if p.age > 1.0:
					pops.remove_at(j)
				j -= 1
		"offscreen":
			var wob: float = D.wobble
			for gv in b.targets:
				var g: Dictionary = gv
				g.a += g.w * dt
				var k: float = 1.0 + wob * sin(t * g.wf + g.ph)
				g.x = b.cx + cos(g.a) * W * float(D.orbitX) * k
				g.y = b.cy + sin(g.a) * H * float(D.orbitY) * k
		"anchor":
			if t - b.lastPress > 3.0:
				b.camT = (b.WORLD - W) * (0.5 + 0.5 * sin(t * float(D.autoPan)))
			b.cam += (b.camT - b.cam) * Kit.smooth(4.0, dt)
			for kv in b.sp:
				var k: Dictionary = kv
				var lset: Array = k.set
				var line0: String = lset[k.li % lset.size()]
				k.prog += dt * float(D.cps)
				if k.prog >= line0.length():
					k.hold += dt
					if k.hold > float(D.hold):
						k.hold = 0.0
						k.prog = 0.0
						k.li += 1
		"xhair":
			b.holding = (t - b.lastPress) < 0.12
			b.tx = W / 2.0 + sin(t * 0.6) * W * 0.28
			b.ty = H * 0.45 + sin(t * 0.9 + 1.0) * H * 0.16
			if not b.holding:
				b.autoT += dt
				if b.autoT > float(D.autoEvery) and b.pending == 0:
					b.autoT = 0.0
					b.pending = int(D.burst)
				if t - b.lastPress > 1.5:
					b.cx += (b.tx - b.cx) * Kit.smooth(3.0, dt)
					b.cy += (b.ty - b.cy) * Kit.smooth(3.0, dt)
			if b.holding or b.pending > 0:
				b.acc += dt * float(D.fireRate)
				var nn := 0
				while b.acc >= 1.0 and nn < 8:
					b.acc -= 1.0
					_xh_fire(b)
					if b.pending > 0:
						b.pending -= 1
					if b.pending == 0 and not b.holding:
						b.acc = 0.0
						break
					nn += 1
			else:
				b.acc = 0.0
			b.spread = maxf(float(D.spreadMin), b.spread - float(D.recover) * dt)
			b.marker += dt
			b.sampleT += dt
			var ns := 0
			while b.sampleT > 0.033 and ns < 6:
				b.sampleT -= 0.033
				b.hist[b.head] = b.spread
				b.head = (b.head + 1) % HIST_N
				ns += 1
			var holes: Array = b.holes
			var j := holes.size() - 1
			while j >= 0:
				var h: Dictionary = holes[j]
				h.age += dt
				if h.age > 2.5:
					holes.remove_at(j)
				j -= 1
		"damagearc":
			var att: Array = b.att
			var feet: float = b.feet
			var px: float = b.px
			b.hitT += dt
			if b.hitT > float(D.hitEvery) and not att.is_empty():
				b.hitT = 0.0
				var a: Dictionary = att[randi() % att.size()]
				if a.lunge > 1.0:
					a.lunge = 0.0
			b.hp = minf(1.0, b.hp + float(D.regen) * dt)
			b.hurt = maxf(0.0, b.hurt - dt)
			for i in att.size():                         # the orbit, on the ground plane
				var a: Dictionary = att[i]
				a.a += a.w * dt
				var prev: float = a.lunge
				a.lunge += dt
				var k: float = sin(a.lunge / 0.5 * PI) * 0.72 if a.lunge < 0.5 else 0.0
				a.x = px + cos(a.a) * W * float(D.orbit) * (1.0 - k)
				a.y = feet + sin(a.a) * H * 0.12 * (1.0 - k)
				if prev < 0.25 and a.lunge >= 0.25:      # the strike lands mid-lunge
					_da_hit_from(b, a.a, i)
			var shots: Array = b.shots
			var j := shots.size() - 1
			while j >= 0:                                # a press: a projectile flies in
				var sh: Dictionary = shots[j]
				sh.age += dt
				if sh.age >= 0.35:
					_da_hit_from(b, sh.ang, -1)
					shots.remove_at(j)
				j -= 1
			var arcs: Array = b.arcs
			var fade: float = D.fade
			j = arcs.size() - 1
			while j >= 0:
				var c: Dictionary = arcs[j]
				c.age += dt
				if c.age > fade:
					arcs.remove_at(j)
					if b.last >= j:
						b.last -= 1
				elif c.src >= 0 and c.src < att.size():  # the angle is re-read while the attacker lives
					var a: Dictionary = att[c.src]
					c.ang = atan2(a.y - feet, a.x - px)
				j -= 1
		"toast":
			b.autoT += dt
			if b.autoT > float(D.autoEvery):
				b.autoT = 0.0
				_toast_post(b)
			var sz := maxf(9.0, H * 0.062)
			var h := sz * 2.0
			var bw: float = W * float(D.width)
			var base := H * 0.86 - h
			var queue: Array = b.queue
			if D.mode == "ticker":
				var speed := W / maxf(0.5, float(D.life))
				var tk: Array = b.tk
				var last_end := 0.0
				for kv in tk:
					var k: Dictionary = kv
					last_end = maxf(last_end, k.x + k.w)
				if not queue.is_empty() and last_end < W - 20.0:
					var m: Array = queue.pop_front()
					tk.append({ "m": m, "x": maxf(W, last_end + sz * 3.0), "w": _measure(m[0], sz) + sz })
				var j := tk.size() - 1
				while j >= 0:
					var k: Dictionary = tk[j]
					k.x -= speed * dt
					if k.x + k.w < 0.0:
						tk.remove_at(j)
					j -= 1
			else:
				var live: Array = b.live
				var shown: int = D.shown
				var gap: float = D.gap
				if live.size() < shown and not queue.is_empty():
					var m: Array = queue.pop_front()
					live.push_front({ "m": m, "age": 0.0, "y": base + h + gap })
				var j := live.size() - 1
				while j >= 0:
					var k: Dictionary = live[j]
					k.age += dt
					var ty := base - j * (h + gap)
					k.y += (ty - k.y) * Kit.smooth(14.0, dt)
					if k.age > float(D.life) and (k.age - float(D.life)) / maxf(0.01, float(D.slide)) >= 1.0:
						live.remove_at(j)
					j -= 1
		"minimap":
			var hy: float = b.gy + H * 0.02
			b.hx += b.hdir * W * 0.18 * dt
			if b.hx > W * 0.9:
				b.hdir = -1
			if b.hx < W * 0.1:
				b.hdir = 1
			var prev: float = b.sweep
			b.sweep = prev + TAU / maxf(0.2, float(D.period)) * dt
			b.prevSweep = prev
			var adv: float = b.sweep - prev
			var motion: bool = D.mode == "motion"
			for ev in b.en:                              # wander: walk to a spot, rest, repeat
				var e: Dictionary = ev
				if e.moving:
					var dx: float = e.tx - e.x
					var dy: float = e.ty - e.y
					var d := Vector2(dx, dy).length()
					var v: float = W * float(D.speed) * dt
					if d <= v or d < 0.01:
						e.x = e.tx
						e.y = e.ty
						e.moving = false
						e.rest = randf_range(1.0, 7.0 if e.sitter else 3.0)
					else:
						e.x += dx / d * v
						e.y += dy / d * v
				else:
					e.rest -= dt
					if e.rest <= 0.0:
						e.moving = true
						e.tx = clampf(e.x + randf_range(-W * 0.3, W * 0.3), 4.0, W - 4.0)
						e.ty = clampf(e.y + randf_range(-H * 0.15, H * 0.15), b.yTop, b.yBot)
				if motion:
					if e.moving:
						e.seenAt = t
				else:                                    # did the sweep cross this bearing this frame?
					var bearing := atan2(e.y - hy, e.x - b.hx)
					var da := fmod(bearing - prev, TAU)
					if da < 0.0:
						da += TAU
					if da <= adv:
						e.seenAt = t
		"ghostplacement":
			var cell: float = b.cell
			var cols: int = b.cols
			var rows: int = b.rows
			b.fx += (b.tx - b.fx) * Kit.smooth(float(D.moveRate), dt)
			b.fy += (b.ty - b.fy) * Kit.smooth(float(D.moveRate), dt)
			var pw: int = b.pw
			var ph: int = b.ph
			var gx := roundi((b.fx - b.ox) / cell - pw / 2.0)
			var gy := roundi((b.fy - b.oy) / cell - ph / 2.0)
			var valid := _gp_fits(b, gx, gy, pw, ph)
			if t - b.lastPress > 2.5:                    # autopilot: glide, place or rotate, pick anew
				b.autoT += dt
				if b.autoT > float(D.autoEvery):
					b.autoT = 0.0
					if valid:
						_gp_place(b, gx, gy, pw, ph)
					else:
						_gp_rotate(b)
					b.tx = b.ox + ((randi() % cols) + 0.5) * cell
					b.ty = b.oy + ((randi() % rows) + 0.5) * cell
			if b.heldT > 0.0:
				b.heldT -= dt
				if b.heldT <= 0.0:
					if valid:
						_gp_place(b, gx, gy, pw, ph)
					else:
						_gp_rotate(b)
			if b.filled > cols * rows * 0.62:
				for i in cols * rows:
					b.occ[i] = 0
				b.pieces = []
				b.filled = 0
				b.clearedT = 0.0
			b.clearedT += dt
			for pv in b.pieces:
				var p: Dictionary = pv
				p.age += dt
			b.gx = gx                                    # what draw() paints: the cell and its verdict
			b.gy_ = gy
			b.valid = valid and (b.pw == pw and b.ph == ph)
			if b.pw != pw or b.ph != ph:                 # rotated this tick: re-test the new footprint
				b.valid = _gp_fits(b, gx, gy, b.pw, b.ph)
		"jewel":
			b.autoT += dt
			if b.autoT > float(D.rerollEvery):
				b.autoT = 0.0
				_jw_roll(b)
			for cv in b.cards:
				var c: Dictionary = cv
				var prev: float = c.flip
				c.flip += dt
				if prev < 0.25 and c.flip >= 0.25:       # edge-on: swap
					c.tier = c.next
		"bossbar":
			b.st += dt
			b.shakeAge += dt
			b.flash += dt
			b.slash += dt
			if b.state == "intro" and b.st > float(D.intro) + 0.4:
				b.state = "fight"
				b.st = 0.0
				b.hitT = 0.0
			if b.state == "fight":
				b.hitT += dt
				if b.hitT > float(D.hitEvery):
					b.hitT = 0.0
					_bb_hit(b)
			if b.state == "dead" and b.st > 2.5:
				_bb_reset(b)
			var falling: Array = b.falling
			var j := falling.size() - 1
			while j >= 0:                                # the broken segments fall away
				var f: Dictionary = falling[j]
				f.age += dt
				f.vy += H * 2.4 * dt
				f.x += f.vx * dt
				f.y += f.vy * dt
				f.rot += f.vr * dt
				if f.age > 1.4 or f.y > H + 20.0:
					falling.remove_at(j)
				j -= 1

# ---------------------------------------------------------------- draw helpers

## A dial printed the way the web prints it: 2 → "2", 4.5 → "4.5".
static func _num(v: float) -> String:
	return str(roundi(v)) if absf(v - roundf(v)) < 1e-6 else str(v)

## Radial: the three ability glyphs (a sword, a shield, a bolt), in icon-local space.
static func _rad_glyph(n: CanvasItem, i: int, r: float, c: Color) -> void:
	if i % 3 == 0:
		Kit.line(n, Vector2(-r * 0.45, r * 0.45), Vector2(r * 0.45, -r * 0.45), c, 3.0)
		Kit.line(n, Vector2(-r * 0.05, -r * 0.05), Vector2(-r * 0.35, -r * 0.35), c, 1.0)
		Kit.line(n, Vector2(-r * 0.3, r * 0.05), Vector2(-r * 0.05, r * 0.3), c, 3.0)
	elif i % 3 == 1:
		Kit.poly(n, [Vector2(-r * 0.45, -r * 0.45), Vector2(r * 0.45, -r * 0.45), Vector2(r * 0.45, r * 0.05), Vector2(0, r * 0.5), Vector2(-r * 0.45, r * 0.05)], c)
	else:
		Kit.poly(n, [Vector2(-r * 0.1, -r * 0.55), Vector2(r * 0.35, -r * 0.1), Vector2(r * 0.05, -r * 0.1), Vector2(r * 0.15, r * 0.55), Vector2(-r * 0.35, 0), Vector2(-r * 0.05, 0)], c)

## Damagearc: one attacker — a diamond with two eyes, brighter mid-lunge.
static func _da_att(n: CanvasItem, a: Dictionary) -> void:
	var x: float = a.x
	var y: float = a.y
	Kit.poly(n, [Vector2(x, y - 12), Vector2(x + 8, y - 4), Vector2(x, y + 2), Vector2(x - 8, y - 4)], Kit.FIRE if a.lunge < 0.5 else Kit.HOT)
	Kit.dot(n, Vector2(x - 2, y - 6), 1.2, INK_DARK)
	Kit.dot(n, Vector2(x + 2, y - 6), 1.2, INK_DARK)

## Minimap: an enemy in the world — a diamond, dim until seen.
static func _mm_enemy(n: CanvasItem, e: Dictionary, vis: float) -> void:
	var x: float = e.x
	var y: float = e.y
	Kit.poly(n, [Vector2(x, y - 11), Vector2(x + 7, y - 4), Vector2(x, y), Vector2(x - 7, y - 4)], _al(Kit.HOT, 0.3 + 0.7 * vis))
	Kit.dot(n, Vector2(x - 2, y - 6), 1.2, INK_DARK)
	Kit.dot(n, Vector2(x + 2, y - 6), 1.2, INK_DARK)

# ---------------------------------------------------------------- draw

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	var D: Dictionary = b.D
	var W: float = b.w
	var H: float = b.h
	var GY: float = b.gy
	var origin: Vector2 = (b.rect as Rect2).position
	match b.id:
		"healthbar":
			Kit.stage(n, b, 0.0, true)
			var hp: float = b.hp
			var ghost: float = b.ghost
			var mx: float = D.max
			var hurt: float = b.hurt
			var since: float = b.since
			var delay: float = D.delay
			# the hero takes it
			var blink := hurt > 0.0 and floori(hurt * 24.0) % 2 == 0
			var opts := { "pose": "crouch" if hp <= 0.0 else ("hurt" if hurt > 0.0 else "stand"), "frame": t }
			if blink:
				opts.tint = Color(245.0 / 255.0, 138.0 / 255.0, 138.0 / 255.0, 0.75)
			Kit.hero(n, b, Vector2(W * 0.5, GY), opts)
			# the bar
			var bx := W * 0.1
			var by := H * 0.12
			var bw := W * 0.8
			var bh := H * 0.08
			var k := bw / mx
			Kit.rect(n, Rect2(bx, by, bw, bh), Color(0, 0, 0, 0.55))
			Kit.rect(n, Rect2(bx, by, minf(hp, ghost) * k, bh), Kit.HOT)
			var sz := maxf(9.0, H * 0.06)
			if ghost > hp:                               # damage: the white ghost chunk
				Kit.rect(n, Rect2(bx + hp * k, by, (ghost - hp) * k, bh), Color(1, 1, 1, 0.88))
				_lab(n, b, "ghost −%d" % roundi(ghost - hp), Vector2(bx + (hp + ghost) * 0.5 * k, by + bh + 11), Kit.INK, "center")
			elif hp > ghost:                             # heal: the bar lags, the gap is green
				Kit.rect(n, Rect2(bx + ghost * k, by, (hp - ghost) * k, bh), Kit.GOOD)
				_lab(n, b, "heal +%d" % roundi(hp - ghost), Vector2(bx + (hp + ghost) * 0.5 * k, by + bh + 11), Kit.GOOD, "center")
			var segs: int = D.segments
			for i in range(1, segs):
				Kit.line(n, Vector2(bx + i * bw / segs, by), Vector2(bx + i * bw / segs, by + bh), Color(19.0 / 255.0, 16.0 / 255.0, 32.0 / 255.0, 0.8), 1.5)
			_stroke_rect(n, Rect2(bx, by, bw, bh), Kit.BONE)
			_txt(n, "%d / %d" % [roundi(hp), int(mx)], Vector2(bx + bw, by - 3), sz, Kit.BONE, "right")
			_txt(n, "hp", Vector2(bx, by - 3), sz, Kit.HOT)
			if ghost != hp and since < delay:            # the wait, drawn as a tiny countdown
				var wx := bx + maxf(hp, ghost) * k + 10.0
				var wy := by + bh / 2.0
				Kit.ring(n, Vector2(wx, wy), 4.0, Kit.DIM, 1.0)
				n.draw_arc(Vector2(wx, wy), 4.0, -TAU / 4.0, -TAU / 4.0 + TAU * (since / maxf(0.001, delay)), 16, Kit.INK, 2.0)
				_lab(n, b, "wait", Vector2(wx + 7, wy + 3), Kit.DIM)
			# the history: hp (red) and ghost (white) over the last 3 s — the step and the lag
			var gx := W * 0.62
			var gy2 := H * 0.5
			var gw := W * 0.3
			var gh := H * 0.22
			Kit.rect(n, Rect2(gx, gy2, gw, gh), Color(0, 0, 0, 0.3))
			var hist: Array = b.hist
			var head: int = b.head
			for ch in 2:
				var pts := PackedVector2Array()
				for i in HIST_N:
					var j := ((head + i) % HIST_N) * 2 + ch
					pts.append(Vector2(gx + gw * i / (HIST_N - 1.0), gy2 + gh - gh * float(hist[j]) / mx))
				n.draw_polyline(pts, Color(1, 1, 1, 0.8) if ch == 1 else Kit.HOT, 1.5)
			_lab(n, b, "last 3 s", Vector2(gx, gy2 - 3), Kit.DIM)
			Kit.arrow(n, Vector2(W * 0.28, H * 0.5), Vector2(W * 0.28, by + bh + 2), Kit.DIM)
			_lab(n, b, "snaps", Vector2(W * 0.28, H * 0.5 + 11), Kit.HOT, "center")
			_lab(n, b, "lags", Vector2(W * 0.4, H * 0.5 + 11), Kit.INK, "center")
			Kit.arrow(n, Vector2(W * 0.4, H * 0.5), Vector2(W * 0.4, by + bh + 2), Kit.DIM)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"radial":
			Kit.stage(n, b, 0.0, true)
			var rem: Array = b.rem
			var cds: Array = D.cooldowns
			var cols := [Kit.SUN, Kit.HERO, Kit.MAGIC, Kit.GOOD]
			var r: float = H * float(D.size)
			var y := H * 0.44
			var dir: float = D.dir
			var popk: float = D.pop
			var shown_angle := 0.0
			for i in rem.size():
				var x := _rad_x(b, i)
				var c: Color = cols[i % 4]
				var cd: float = cds[i]
				var remi: float = rem[i]
				var popi: float = b.pop[i]
				var jig: float = b.jig[i]
				var s := 1.0 + popk * sin(minf(1.0, popi / 0.35) * PI)
				var dx := sin(jig * 60.0) * 3.0 if jig > 0.0 else 0.0
				n.draw_set_transform(origin + Vector2(x + dx, y), 0.0, Vector2(s, s))
				if D.glowReady and remi <= 0.0:
					Kit.glow(n, Vector2.ZERO, r * 1.7, c, 0.35 + 0.15 * sin(t * 4.0 + i))
				var icon := Rect2(-r, -r, 2.0 * r, 2.0 * r)
				_rr_fill(n, icon, r * 0.25, PANEL)
				_rr_stroke(n, icon, r * 0.25, Color(201.0 / 255.0, 196.0 / 255.0, 228.0 / 255.0, 0.4) if remi > 0.0 else c, 1.0 if remi > 0.0 else 2.0)
				_rad_glyph(n, i, r, Color(201.0 / 255.0, 196.0 / 255.0, 228.0 / 255.0, 0.5) if remi > 0.0 else c)
				if remi > 0.0:                           # the locked slice: one arc from the top
					var frac := remi / maxf(0.01, cd)
					var a1 := -TAU / 4.0 + dir * TAU * frac
					# the web clips the slice to the icon; here the fan's rim follows the icon's square
					_pie_in_rect(n, Vector2.ZERO, -TAU / 4.0, a1, icon, Color(0, 0, 0, 0.62), r * 1.6)
					var hl := minf(r * 1.5, _rect_ray(Vector2.ZERO, a1, icon))
					Kit.line(n, Vector2.ZERO, Vector2(cos(a1), sin(a1)) * hl, Color(1, 1, 1, 0.7), 1.5)
					_txt(n, "%.1f" % remi, Vector2(0, r * 0.32), r * 0.85, Kit.INK, "center")
					if i == 0 or shown_angle == 0.0:
						shown_angle = TAU * frac
				n.draw_set_transform(origin, 0.0, Vector2.ONE)
				_lab(n, b, "%s s" % _num(cd), Vector2(x, y + r + 12), Kit.DIM, "center")
				if remi <= 0.0:
					_lab(n, b, "ready", Vector2(x, y - r - 5), c, "center")
			for kv in b.bursts:                          # the ready ring, expanding
				var k: Dictionary = kv
				var ki: int = k.i
				Kit.ring(n, Vector2(_rad_x(b, ki), y), r * (1.0 + k.age * 2.0), _al(cols[ki % 4], 1.0 - k.age / 0.5), 2.0)
			# the angle, named
			var ax := W * 0.12
			var ay := H * 0.82
			Kit.ring(n, Vector2(ax, ay), 9.0, Kit.DIM, 1.0)
			if shown_angle > 1e-3:
				n.draw_arc(Vector2(ax, ay), 9.0, -TAU / 4.0, -TAU / 4.0 + dir * shown_angle, 24, Kit.SUN, 2.0)
			_lab(n, b, "θ = %d°" % roundi(shown_angle / TAU * 360.0), Vector2(ax + 14, ay + 4), Kit.SUN)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"odometer":
			Kit.stage(n, b, 0.0, true)
			var shown: float = b.shown
			var k: float = b.k
			var target: float = b.target
			var punchT: float = b.punchT
			var snap: bool = D.snap
			var digits: int = D.digits
			# the drums
			var dw := minf(W * 0.08, H * 0.13)
			var dh := dw * 1.4
			var commas := floori((digits - 1) / 3.0)
			var total := digits * dw + commas * dw * 0.4
			var x0 := W / 2.0 - total / 2.0
			var cy := H * 0.36
			var s := 1.0 + float(D.punch) * exp(-punchT * 9.0)
			var cpt := Vector2(W / 2.0, cy)
			var outer := Transform2D(0.0, Vector2(s, s), 0.0, origin + cpt * (1.0 - s))   # the punch, about the counter's centre
			n.draw_set_transform_matrix(outer)
			var fsz := dw * 1.05
			var top := cy - dh / 2.0
			var cur := x0
			var i := digits - 1
			while i >= 0:
				var p := pow(10.0, i)
				var q := shown / p
				var d := floori(q) % 10
				var slide := (q - floorf(q)) if i == 0 else clampf((q - floorf(q)) * p - (p - 1.0), 0.0, 1.0)
				var lead := i > 0 and floorf(q) == 0.0
				Kit.rect(n, Rect2(cur, top, dw, dh), Color(28.0 / 255.0, 24.0 / 255.0, 44.0 / 255.0, 0.95))
				var dcol := _al(Kit.SUN, 0.25) if lead else Kit.SUN
				# the web clips two sliding digits to the drum; with no clip, the leaving digit is
				# squashed into its (1 − slide) of the drum and the arriving one into its slide —
				# the drum read as a cylinder
				if 1.0 - slide > 0.02:
					n.draw_set_transform_matrix(outer * Transform2D(0.0, Vector2(1.0, 1.0 - slide), 0.0, Vector2(cur + dw / 2.0, top + dh)))
					_txt(n, str(d), Vector2(0, -dh / 2.0 + fsz * 0.35), fsz, dcol, "center")
				if slide > 0.02:
					n.draw_set_transform_matrix(outer * Transform2D(0.0, Vector2(1.0, slide), 0.0, Vector2(cur + dw / 2.0, top)))
					_txt(n, str((d + 1) % 10), Vector2(0, dh / 2.0 + fsz * 0.35), fsz, dcol, "center")
				n.draw_set_transform_matrix(outer)
				_stroke_rect(n, Rect2(cur, top, dw, dh), Color(201.0 / 255.0, 196.0 / 255.0, 228.0 / 255.0, 0.5))
				if slide > 0.001 and slide < 0.999 and i > 0:
					_lab(n, b, "carry", Vector2(cur + dw / 2.0, top - 4), Kit.GOOD, "center")
				cur += dw
				if i > 0 and i % 3 == 0:
					_txt(n, ",", Vector2(cur + dw * 0.2, cy + dh * 0.3 + fsz * 0.35), fsz, Kit.BONE, "center")
					cur += dw * 0.4
				i -= 1
			n.draw_set_transform(origin, 0.0, Vector2.ONE)
			var sz := maxf(9.0, H * 0.06)
			_txt(n, "target " + _fmt(target), Vector2(W / 2.0, cy + dh / 2.0 + sz * 1.4), sz, Kit.BONE, "center")
			# the easing, graphed, with k on it
			var gx := W * 0.1
			var gy2 := H * 0.6
			var gw := W * 0.3
			var gh := H * 0.2
			Kit.rect(n, Rect2(gx, gy2, gw, gh), Color(0, 0, 0, 0.3))
			var pts := PackedVector2Array()
			for j in 21:
				var kk := j / 20.0
				var e := ((1.0 if kk > 0.0 else 0.0) if snap else 1.0 - pow(1.0 - kk, 3.0))
				pts.append(Vector2(gx + gw * kk, gy2 + gh - gh * e))
			n.draw_polyline(pts, Kit.DIM, 1.0)
			var ek := 1.0 if snap else 1.0 - pow(1.0 - k, 3.0)
			Kit.dot(n, Vector2(gx + gw * k, gy2 + gh - gh * ek), 3.0, Kit.SUN)
			_lab(n, b, "k = %.2f" % k + (" (snap)" if snap else " · tween %s s" % _num(float(D.tween))), Vector2(gx, gy2 + gh + 11), Kit.DIM)
			# the gains, rising like the grimoire's Rise up
			for pv in b.pops:
				var pp: Dictionary = pv
				var e := 1.0 - pow(1.0 - minf(1.0, pp.age / 1.2), 2.0)
				_txt(n, "+" + _fmt(pp.n), Vector2(W * 0.75, cy + dh / 2.0 + sz * 3.0 - e * H * 0.22), sz * 1.2, _al(Kit.GOOD, 1.0 - pp.age / 1.2), "center")
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"xpbar":
			Kit.stage(n, b, 0.0, true)
			var level: int = b.level
			var xp: float = b.xp
			var shown: float = b.shown
			var flashT: float = b.flashT
			var upT: float = b.upT
			var carryT: float = b.carryT
			var flash: float = D.flash
			var nd := _xp_need(b, level)
			var sz := maxf(9.0, H * 0.06)
			var bx := W * 0.22
			var by := H * 0.2
			var bw := W * 0.68
			var bh := H * 0.075
			Kit.rect(n, Rect2(bx, by, bw, bh), Color(0, 0, 0, 0.55))
			Kit.rect(n, Rect2(bx, by, bw * clampf(shown / nd, 0.0, 1.0), bh), Kit.HERO)
			if flashT < flash:
				Kit.rect(n, Rect2(bx, by, bw, bh), Color(1, 1, 1, 0.9 * (1.0 - flashT / flash)))
			_stroke_rect(n, Rect2(bx, by, bw, bh), Kit.BONE)
			_txt(n, "%d / %d" % [floori(minf(shown, xp)), int(nd)], Vector2(bx + bw, by - 3), sz, Kit.BONE, "right")
			if xp > nd:
				_txt(n, "overflow +%d → carries" % roundi(xp - nd), Vector2(bx + bw, by + bh + sz * 1.2), sz, Kit.SUN, "right")
			if carryT < 1.6:
				_txt(n, "carried %d" % roundi(b.carry), Vector2(bx + 4, by + bh + sz * 1.2 + carryT * 4.0), sz, _al(Kit.GOOD, 1.0 - carryT / 1.6))
			# the level badge, punching on the tick
			var ps := 1.0 + 0.4 * sin(minf(1.0, upT / 0.35) * PI)
			n.draw_set_transform(origin + Vector2(bx - bh * 1.2, by + bh / 2.0), 0.0, Vector2(ps, ps))
			n.draw_circle(Vector2.ZERO, bh * 0.95, PANEL)
			Kit.ring(n, Vector2.ZERO, bh * 0.95, Kit.SPARK if upT < 0.35 else Kit.SUN, 1.5)
			_txt(n, "Lv %d" % level, Vector2(0, bh * 0.35), bh * 0.9, Kit.INK, "center")
			n.draw_set_transform(origin, 0.0, Vector2.ONE)
			# the ladder: the next thresholds, each longer than the last
			var lx := W * 0.5
			var ly := H * 0.42
			var lw := W * 0.4
			var lh := H * 0.045
			var top := _xp_need(b, level + 4)
			for j in 5:
				var L := level + j
				var need := _xp_need(b, L)
				var w := lw * need / top
				var y := ly + j * (lh + 3.0)
				Kit.rect(n, Rect2(lx, y, w, lh), Color(138.0 / 255.0, 217.0 / 255.0, 245.0 / 255.0, 0.6) if j == 0 else Color(201.0 / 255.0, 196.0 / 255.0, 228.0 / 255.0, 0.25))
				_lab(n, b, "L%d needs %d" % [L, int(need)], Vector2(lx + w + 4, y + lh - 1), Kit.HERO if j == 0 else Kit.DIM)
			_lab(n, b, "need(L) grows ×%s" % _num(float(D.growth)), Vector2(lx, ly - 4), Kit.DIM)
			# the hero and the folio's column of light
			var hx := W * 0.22
			if upT < 1.0:
				var a := upT / 0.15 if upT < 0.15 else (1.0 - upT) / 0.85
				Kit.vgrad(n, Rect2(hx - H * 0.07, GY - H * 0.45, H * 0.14, H * 0.45), _al(Kit.SUN, 0.0), _al(Kit.SUN, a * 0.4))
				for j in 3:
					var p := fmod(upT * 1.4 + j / 3.0, 1.0)
					var y := GY - 8.0 - p * H * 0.35
					var glint := Color(245.0 / 255.0, 220.0 / 255.0, 150.0 / 255.0, sin(p * PI) * a)
					Kit.line(n, Vector2(hx - 6, y + 4), Vector2(hx, y - 2), glint, 2.0)
					Kit.line(n, Vector2(hx, y - 2), Vector2(hx + 6, y + 4), glint, 2.0)
			Kit.hero(n, b, Vector2(hx, GY), { "pose": "jump" if upT < 0.5 else "stand", "frame": t })
			for pv in b.pops:
				var pp: Dictionary = pv
				_txt(n, "+%d xp" % roundi(pp.n), Vector2(hx + H * 0.12, GY - H * 0.3 - pp.age * H * 0.1), sz, _al(Kit.GOOD, 1.0 - pp.age))
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"offscreen":
			Kit.stage(n, b, 0.0, true)
			var v: Rect2 = b.view
			var cx: float = b.cx
			var cy: float = b.cy
			Kit.rect(n, v, Color(1, 1, 1, 0.05))
			_stroke_rect(n, v, Kit.BONE, 1.5)
			_lab(n, b, "the view", Vector2(v.position.x + 4, v.position.y + 11), Kit.DIM)
			Kit.hero(n, b, Vector2(cx, cy + H * 0.12), { "frame": t })
			var m: float = D.margin
			var rr: float = H * float(D.radarR)
			var rc := Vector2(v.end.x - rr - 5.0, v.position.y + rr + 5.0)
			var reach := maxf(W * float(D.orbitX), H * float(D.orbitY)) * (1.0 + float(D.wobble))
			var radar: bool = D.style == "radar"
			if radar:
				n.draw_circle(rc, rr, Color(0, 0, 0, 0.5))
				Kit.ring(n, rc, rr, Kit.BONE, 1.0)
				Kit.ring(n, rc, rr * 0.5, Kit.DIM, 1.0)
				Kit.line(n, rc, rc + Vector2(cos(t * 1.6), sin(t * 1.6)) * rr, Kit.GOOD, 1.0)
				Kit.dot(n, rc, 2.0, Kit.HERO)
			var targets: Array = b.targets
			for i in targets.size():
				var g: Dictionary = targets[i]
				var gp := Vector2(g.x, g.y)
				var gc: Color = g.c
				var inside := gp.x > v.position.x + m and gp.x < v.end.x - m and gp.y > v.position.y + m and gp.y < v.end.y - m
				# the world: the target itself, dim when outside the view
				Kit.poly(n, [gp + Vector2(0, -6), gp + Vector2(5, 0), gp + Vector2(0, 6), gp + Vector2(-5, 0)], gc if inside else _al(gc, 0.3))
				if inside:
					Kit.dot(n, gp + Vector2(-1.5, -1), 1.0, INK_DARK)
					continue
				# the clamp, the arrow, the distance
				var q := Vector2(clampf(gp.x, v.position.x + m, v.end.x - m), clampf(gp.y, v.position.y + m, v.end.y - m))
				var ang := atan2(gp.y - q.y, gp.x - q.x)
				var d := gp.distance_to(q)
				if radar:
					var kk := rr / reach
					var bp := rc + (gp - Vector2(cx, cy)) * kk
					var bd := bp.distance_to(rc)
					var sc := (rr - 2.0) / bd if bd > rr - 2.0 else 1.0
					Kit.dot(n, rc + (bp - rc) * sc, 2.5, gc)
					if i == 0:
						_dash(n, rc, gp, _al(gc, 0.35), 1.0)
					continue
				n.draw_set_transform(origin + q, ang, Vector2.ONE)
				Kit.poly(n, [Vector2(7, 0), Vector2(-4, -5), Vector2(-2, 0), Vector2(-4, 5)], gc)
				n.draw_set_transform(origin, 0.0, Vector2.ONE)
				var left := q.x < cx
				_lab(n, b, "%d m" % roundi(d / 4.0), Vector2(q.x + (10.0 if left else -10.0), q.y + (14.0 if q.y < cy else -6.0)), gc, "left" if left else "right")
				if i == 0:                               # one target annotated in full
					_dash(n, q, gp, _al(gc, 0.45), 1.0)
					Kit.ring(n, q, 4.0, Kit.INK, 1.0)
					_lab(n, b, "p'", Vector2(q.x + (10.0 if left else -10.0), q.y + (26.0 if q.y < cy else -18.0)), Kit.INK, "left" if left else "right")
					_lab(n, b, "p", gp + Vector2(8, -8), Kit.DIM)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"anchor":
			var cam: float = b.cam
			var WORLD: float = b.WORLD
			Kit.stage(n, b)
			for pv in b.props:
				var p: Dictionary = pv
				var x: float = p.wx - cam
				if x < -60.0 or x > W + 60.0:
					continue
				var ps: float = p.s
				if p.kind == 0:
					Kit.tree(n, Vector2(x, GY), H * 0.16 * ps)
				elif p.kind == 1:
					Kit.crate(n, Vector2(x, GY), H * 0.09 * ps)
				else:
					Kit.house(n, Vector2(x, GY), H * 0.18, H * 0.16, true)
			var su := maxf(2.0, roundf(H / 60.0))
			var headY := GY - 17.0 * su
			var sz := maxf(9.0, H * 0.058)
			var m: float = D.margin
			var tag: bool = D.style == "tag"
			var sp: Array = b.sp
			var boxes: Array = []                        # each speaker's box, for the stacking test
			for i in sp.size():
				var k: Dictionary = sp[i]
				var sx: float = k.wx - cam
				var shirt: Color = k.shirt
				if sx > -30.0 and sx < W + 30.0:
					Kit.hero(n, b, Vector2(sx, GY), { "shirt": shirt, "face": k.face, "frame": t })
				var lset: Array = k.set
				var line0: String = lset[k.li % lset.size()]
				var prog: float = k.prog
				# the projection and the clamp
				var bw := 0.0
				var bh := 0.0
				var ls: Array = []
				if tag:
					bw = _measure(k.name, sz) + sz
					bh = sz * 1.5
				else:
					ls = _wrap_words(line0, W * float(D.boxW) - sz, sz)
					var tw := 0.0
					for l in ls:
						tw = maxf(tw, _measure(l, sz))
					bw = minf(W - 2.0 * m, tw + sz * 1.1)
					bh = ls.size() * sz * 1.25 + sz * 0.7
				var bx := clampf(sx - bw / 2.0, m, maxf(m, W - bw - m))
				var by := headY - sz * 1.1 - bh - (sz * 0.6 if tag else 0.0)
				for j in i:                              # stacked when two boxes collide
					var o: Rect2 = boxes[j]
					if bx < o.end.x and bx + bw > o.position.x and absf(by - o.position.y) < bh:
						by = o.position.y - bh - 3.0
				boxes.append(Rect2(bx, by, bw, bh))
				var tipX := clampf(sx, 3.0, W - 3.0)
				if tag:
					Kit.line(n, Vector2(clampf(sx, bx + 4.0, bx + bw - 4.0), by + bh), Vector2(tipX, headY - 2.0), Kit.BONE, 1.0)
					Kit.dot(n, Vector2(tipX, headY - 2.0), 2.0, shirt)
					Kit.rect(n, Rect2(bx, by, bw, bh), Color(20.0 / 255.0, 16.0 / 255.0, 38.0 / 255.0, 0.9))
					_stroke_rect(n, Rect2(bx, by, bw, bh), shirt)
					_txt(n, k.name, Vector2(bx + bw / 2.0, by + bh - sz * 0.4), sz, Kit.INK, "center")
				else:
					var tb := clampf(sx, bx + sz, bx + bw - sz)
					Kit.poly(n, [Vector2(tb - sz * 0.45, by + bh - 1.0), Vector2(tb + sz * 0.45, by + bh - 1.0), Vector2(tipX, headY - 2.0)], BOX)
					Kit.line(n, Vector2(tb - sz * 0.45, by + bh - 1.0), Vector2(tipX, headY - 2.0), Kit.BONE, 1.0)
					Kit.line(n, Vector2(tb + sz * 0.45, by + bh - 1.0), Vector2(tipX, headY - 2.0), Kit.BONE, 1.0)
					Kit.rect(n, Rect2(bx, by, bw, bh), BOX)
					_stroke_rect(n, Rect2(bx, by, bw, bh), Kit.BONE)
					var shown_chars := floori(prog)
					for j in ls.size():
						var lj: String = ls[j]
						_txt(n, lj.substr(0, maxi(0, shown_chars)), Vector2(bx + sz * 0.55, by + sz * 1.2 + j * sz * 1.25), sz, Kit.INK)
						shown_chars -= lj.length() + 1
					if prog >= line0.length() and sin(t * 4.0) > 0.0:
						Kit.poly(n, [Vector2(bx + bw - sz, by + bh - sz * 0.5), Vector2(bx + bw - sz * 0.4, by + bh - sz * 0.5), Vector2(bx + bw - sz * 0.7, by + bh - sz * 0.15)], Kit.BONE)
				if i == 0:
					_lab(n, b, "sx = %d − %d = %d" % [roundi(k.wx), roundi(cam), roundi(sx)], Vector2(W / 2.0, H - 20.0), Kit.DIM, "center")
			# the world strip: the whole world, the window, the speakers
			var sw := W * 0.8
			var bx0 := W * 0.1
			var by0 := 8.0
			Kit.line(n, Vector2(bx0, by0), Vector2(bx0 + sw, by0), Kit.DIM, 1.0)
			Kit.poly(n, [Vector2(bx0 + cam / WORLD * sw, by0 - 4.0), Vector2(bx0 + (cam + W) / WORLD * sw, by0 - 4.0),
				Vector2(bx0 + (cam + W) / WORLD * sw, by0 + 4.0), Vector2(bx0 + cam / WORLD * sw, by0 + 4.0)], Color(0.91, 0.898, 0.957, 0.5), 1.0)
			for kv in sp:
				var k: Dictionary = kv
				Kit.dot(n, Vector2(bx0 + k.wx / WORLD * sw, by0), 2.5, k.shirt)
			_lab(n, b, "cam = %d" % roundi(cam), Vector2(bx0, by0 + 14.0), Kit.DIM)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"xhair":
			Kit.stage(n, b, 0.0, true)
			var c := Vector2(b.cx, b.cy)
			var spread: float = b.spread
			var tp := Vector2(b.tx, b.ty)
			var marker: float = b.marker
			var mlife: float = D.marker
			var smax: float = D.spreadMax
			var smin: float = D.spreadMin
			# the bullseye, the holes
			var tr := H * float(D.targetR)
			Kit.dot(n, tp, tr, Kit.BONE)
			Kit.dot(n, tp, tr * 0.66, Kit.HOT)
			Kit.dot(n, tp, tr * 0.33, Kit.BONE)
			for hv in b.holes:
				var h: Dictionary = hv
				Kit.dot(n, Vector2(h.x, h.y), 2.0, Color(0, 0, 0, 0.75 * (1.0 - h.age / 2.5)))
			# the reticle: four ticks at the spread radius, a faint disc
			_dash_ring(n, c, spread, Kit.DIM, 1.0)
			Kit.line(n, c + Vector2(-spread - 9.0, 0), c + Vector2(-spread - 2.0, 0), Kit.INK, 2.0)
			Kit.line(n, c + Vector2(spread + 2.0, 0), c + Vector2(spread + 9.0, 0), Kit.INK, 2.0)
			Kit.line(n, c + Vector2(0, -spread - 9.0), c + Vector2(0, -spread - 2.0), Kit.INK, 2.0)
			Kit.line(n, c + Vector2(0, spread + 2.0), c + Vector2(0, spread + 9.0), Kit.INK, 2.0)
			Kit.dot(n, c, 1.5, Kit.INK)
			if marker < mlife:                           # the hit marker
				var k := marker / mlife
				var r0 := 4.0 + k * 5.0
				var r1 := r0 + 7.0
				var mc := Color(1, 1, 1, 1.0 - k)
				for q in 4:
					var a := TAU / 8.0 + q * TAU / 4.0
					Kit.line(n, c + Vector2(cos(a), sin(a)) * r0, c + Vector2(cos(a), sin(a)) * r1, mc, 2.5)
			_lab(n, b, "spread %d px" % roundi(spread), c + Vector2(spread + 12.0, -6.0), Kit.SUN)
			# spread(t)
			var gx := W * 0.05
			var gy2 := H * 0.62
			var gw := W * 0.3
			var gh := H * 0.2
			Kit.rect(n, Rect2(gx, gy2, gw, gh), Color(0, 0, 0, 0.3))
			var hist: Array = b.hist
			var head: int = b.head
			var pts := PackedVector2Array()
			for i in HIST_N:
				pts.append(Vector2(gx + gw * i / (HIST_N - 1.0), gy2 + gh - gh * clampf(float(hist[(head + i) % HIST_N]) / smax, 0.0, 1.0)))
			n.draw_polyline(pts, Kit.SUN, 1.5)
			Kit.line(n, Vector2(gx, gy2 + gh - gh * smin / smax), Vector2(gx + gw, gy2 + gh - gh * smin / smax), Kit.DIM, 1.0)
			_lab(n, b, "spread, last 4 s · min %s · max %s" % [_num(smin), _num(smax)], Vector2(gx, gy2 - 3.0), Kit.DIM)
			_txt(n, "hits %d / %d" % [b.hits, b.shots], Vector2(W - 8.0, 14.0), maxf(9.0, H * 0.06), Kit.BONE, "right")
			if b.holding or b.pending > 0:
				_lab(n, b, "firing", Vector2(W - 8.0, 26.0), Kit.HOT, "right")
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"damagearc":
			Kit.stage(n, b, 0.45)
			var px: float = b.px
			var feet: float = b.feet
			var chest: float = b.chest
			var att: Array = b.att
			var arcs: Array = b.arcs
			var hp: float = b.hp
			var hurt: float = b.hurt
			var last: int = b.last
			var fade: float = D.fade
			var width: float = D.width
			for sv in b.shots:                           # a press: a projectile flies in
				var sh: Dictionary = sv
				var k: float = sh.age / 0.35
				var x: float = sh.x + (px - sh.x) * k
				var y: float = sh.y + (chest - sh.y) * k
				Kit.line(n, Vector2(x - (px - sh.x) * 0.08, y - (chest - sh.y) * 0.08), Vector2(x, y), Kit.FIRE, 2.0)
				Kit.dot(n, Vector2(x, y), 3.0, Kit.SPARK)
			Kit.ellipse(n, Vector2(px, feet + 2.0), W * float(D.orbit) + 12.0, H * 0.13, Color(0, 0, 0, 0.25))
			for av in att:
				if (av as Dictionary).y < feet:
					_da_att(n, av)
			var opts := { "pose": "hurt" if hurt > 0.0 else "stand", "frame": t }
			if hurt > 0.2:
				opts.tint = Color(245.0 / 255.0, 138.0 / 255.0, 138.0 / 255.0, 0.7)
			Kit.hero(n, b, Vector2(px, feet), opts)
			for av in att:
				if (av as Dictionary).y >= feet:
					_da_att(n, av)
			# the arcs on the screen's edge
			var cen := Vector2(W / 2.0, H / 2.0)
			var rx := W / 2.0 - float(D.inset)
			var ry := H / 2.0 - float(D.inset)
			var lw := H * 0.045
			for cv in arcs:
				var c: Dictionary = cv
				var al: float = 1.0 - c.age / fade
				var ang: float = c.ang
				_ell_arc(n, cen, maxf(1.0, rx - lw * 0.6), maxf(1.0, ry - lw * 0.6), ang - width / 2.0, ang + width / 2.0, _al(Kit.HOT, al * 0.3), lw * 2.2)
				_ell_arc(n, cen, rx, ry, ang - width / 2.0, ang + width / 2.0, _al(Kit.HOT, al), lw)
			if last >= 0 and last < arcs.size():         # the newest arc, annotated
				var c: Dictionary = arcs[last]
				var ang: float = c.ang
				var ep := cen + Vector2(cos(ang) * rx * 0.75, sin(ang) * ry * 0.75)
				Kit.arrow(n, Vector2(px, chest), ep, _al(Kit.INK, 0.6))
				_lab(n, b, "θ = %d°" % roundi(fposmod(ang / TAU * 360.0, 360.0)), ep + Vector2(0, -6), Kit.INK, "center")
			if hp < float(D.ringBelow):                  # the low-health ring
				var pulse := 0.5 + 0.5 * sin(t * 7.0)
				_ell_arc(n, cen, rx, ry, 0.0, TAU, _al(Kit.HOT, 0.2 + 0.45 * pulse), lw * 0.8)
				_txt(n, "LOW", Vector2(W / 2.0, H * 0.22), maxf(10.0, H * 0.08), _al(Kit.HOT, 0.5 + 0.5 * pulse), "center")
			Kit.rect(n, Rect2(W * 0.3, H * 0.9, W * 0.4, 5.0), Color(0, 0, 0, 0.5))
			Kit.rect(n, Rect2(W * 0.3, H * 0.9, W * 0.4 * hp, 5.0), Kit.HOT if hp < 0.3 else Kit.GOOD)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"toast":
			Kit.stage(n, b, 0.0, true)
			var sz := maxf(9.0, H * 0.062)
			var h := sz * 2.0
			var bw: float = W * float(D.width)
			var bx := W - bw - 8.0
			var base := H * 0.86 - h
			var life: float = D.life
			var slide: float = D.slide
			var gap: float = D.gap
			var shown: int = D.shown
			var queue: Array = b.queue
			var live: Array = b.live
			var tk: Array = b.tk
			var ticker: bool = D.mode == "ticker"
			if ticker:
				var y := H * 0.86
				var speed := W / maxf(0.5, life)
				Kit.rect(n, Rect2(0, y - h * 0.6, W, h * 0.9), Color(0, 0, 0, 0.5))
				Kit.line(n, Vector2(0, y - h * 0.6), Vector2(W, y - h * 0.6), Kit.BONE, 1.0)
				Kit.line(n, Vector2(0, y + h * 0.3), Vector2(W, y + h * 0.3), Kit.BONE, 1.0)
				for kv in tk:
					var k: Dictionary = kv
					var m: Array = k.m
					Kit.rect(n, Rect2(k.x, y - sz * 0.5, 3.0, sz * 0.9), m[1])
					_txt(n, m[0], Vector2(k.x + 8.0, y + sz * 0.3), sz, Kit.INK)
				_lab(n, b, "← %d px/s · a message lives one screen width" % roundi(speed), Vector2(8.0, y - h * 0.75), Kit.DIM)
			else:
				for i in shown:                          # the slots, outlined
					var y := base - i * (h + gap)
					_dash_rect(n, Rect2(bx, y, bw, h), Color(201.0 / 255.0, 196.0 / 255.0, 228.0 / 255.0, 0.25), 1.0)
					_lab(n, b, "slot %d" % i, Vector2(bx - 6.0, y + h * 0.65), Kit.DIM, "right")
				for kv in live:
					var k: Dictionary = kv
					var m: Array = k.m
					var age: float = k.age
					var off := 0.0
					if age < slide:
						off = (1.0 - _ease(age / slide)) * (bw + 12.0)
					elif age > life:
						off = _ease((age - life) / maxf(0.01, slide)) * (bw + 12.0)
					var x := bx + off
					var r := Rect2(x, k.y, bw, h)
					_rr_fill(n, r, 4.0, Color(20.0 / 255.0, 16.0 / 255.0, 38.0 / 255.0, 0.94))
					_rr_stroke(n, r, 4.0, Kit.BONE, 1.0)
					Kit.rect(n, Rect2(x, k.y, 3.0, h), m[1])
					_txt(n, m[0], Vector2(x + 9.0, k.y + h * 0.62), sz, Kit.INK)
					Kit.rect(n, Rect2(x + 3.0, k.y + h - 2.0, (bw - 6.0) * (1.0 - minf(1.0, age / life)), 2.0), m[1])
			# the queue, drawn
			var qx := 8.0
			var qy := H * 0.12
			var tail := (" · on the line %d" % tk.size()) if ticker else (" · shown %d / %d" % [live.size(), shown])
			_txt(n, "queue %d" % queue.size() + tail, Vector2(qx, qy), sz, Kit.BONE)
			for i in queue.size():
				var m: Array = queue[i]
				var y := qy + 8.0 + i * (sz * 1.4)
				Kit.rect(n, Rect2(qx, y, 3.0, sz), m[1])
				_lab(n, b, m[0], Vector2(qx + 8.0, y + sz * 0.85), Color(0.91, 0.898, 0.957, 0.4))
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"minimap":
			Kit.stage(n, b)
			var hx: float = b.hx
			var hdir: int = b.hdir
			var sweep: float = b.sweep
			var en: Array = b.en
			var k: float = b.k
			var map: Rect2 = b.map
			var hy := GY + H * 0.02
			var fade: float = D.fade
			var sweeping: bool = D.mode == "sweep"
			for tv in b.trees:
				var tr: Dictionary = tv
				Kit.tree(n, Vector2(tr.x, tr.y), H * tr.s)
			# the world: enemies dim until seen, the hero patrolling
			var hero_drawn := false
			var order: Array = en.duplicate()
			order.sort_custom(func(a: Dictionary, c: Dictionary) -> bool: return a.y < c.y)
			for ev in order:
				var e: Dictionary = ev
				if not hero_drawn and e.y > hy:
					Kit.hero(n, b, Vector2(hx, hy), { "pose": "run", "frame": t, "face": hdir })
					hero_drawn = true
				_mm_enemy(n, e, clampf(1.0 - (t - e.seenAt) / fade, 0.0, 1.0))
			if not hero_drawn:
				Kit.hero(n, b, Vector2(hx, hy), { "pose": "run", "frame": t, "face": hdir })
			# the map
			var mx0 := map.position.x
			var my0 := map.position.y
			var mw := map.size.x
			var mh := map.size.y
			Kit.rect(n, map, Color(10.0 / 255.0, 8.0 / 255.0, 22.0 / 255.0, 0.88))
			Kit.line(n, Vector2(mx0, my0 + GY * k), Vector2(mx0 + mw, my0 + GY * k), Kit.DIM, 1.0)
			for tv in b.trees:
				var tr: Dictionary = tv
				Kit.dot(n, Vector2(mx0 + tr.x * k, my0 + tr.y * k), 1.5, Kit.GOOD)
			var ph := Vector2(mx0 + hx * k, my0 + hy * k)
			if sweeping:
				# the wedge: ten slices, brighter toward the edge. the web clips them to the
				# map; here each slice is a fan whose rim follows the map's rectangle
				for j in 10:
					var a0 := sweep - 0.9 + j * 0.09
					_pie_in_rect(n, ph, a0, a0 + 0.1, map, _al(Kit.GOOD, 0.03 + j * 0.03))
				Kit.line(n, ph, ph + Vector2(cos(sweep), sin(sweep)) * _rect_ray(ph, sweep, map), Kit.GOOD, 1.0)
			for ev in en:
				var e: Dictionary = ev
				var vis := clampf(1.0 - (t - e.seenAt) / fade, 0.0, 1.0)
				if vis <= 0.0:
					continue
				var bp := Vector2(mx0 + e.x * k, my0 + e.y * k)
				Kit.dot(n, bp, 2.2, _al(Kit.HOT, vis))
				if not sweeping and e.moving:
					var ph2 := fmod(t * 2.0, 1.0)
					Kit.ring(n, bp, 3.0 + ph2 * 5.0, _al(Kit.HOT, 0.6 * (1.0 - ph2)), 1.0)
			Kit.dot(n, ph, 2.5, Kit.HERO)
			Kit.line(n, ph, ph + Vector2(hdir * 5.0, 0), Kit.HERO, 1.5)
			_stroke_rect(n, map, Kit.BONE)
			_lab(n, b, "k = %s" % _num(k), Vector2(mx0, my0 + mh + 11.0), Kit.DIM)
			_lab(n, b, ("sweep every %s s" % _num(float(D.period))) if sweeping else "motion only", Vector2(mx0 + mw, my0 + mh + 11.0), Kit.GOOD, "right")
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"ghostplacement":
			Kit.stage(n, b, 0.0, true)
			var cell: float = b.cell
			var cols: int = b.cols
			var rows: int = b.rows
			var ox: float = b.ox
			var oy: float = b.oy
			var pw: int = b.pw
			var ph: int = b.ph
			var fp := Vector2(b.fx, b.fy)
			var gx: int = b.gx
			var gy: int = b.gy_
			var valid: bool = b.valid
			var pieces: Array = b.pieces
			var clearedT: float = b.clearedT
			# the grid
			var grid := Color(201.0 / 255.0, 196.0 / 255.0, 228.0 / 255.0, 0.14)
			for i in cols + 1:
				Kit.line(n, Vector2(ox + i * cell, oy), Vector2(ox + i * cell, oy + rows * cell), grid, 1.0)
			for j in rows + 1:
				Kit.line(n, Vector2(ox, oy + j * cell), Vector2(ox + cols * cell, oy + j * cell), grid, 1.0)
			_stroke_rect(n, Rect2(ox, oy, cols * cell, rows * cell), Kit.BONE)
			for pv in pieces:                            # placed pieces, popping in
				var p: Dictionary = pv
				var s := 1.0 + 0.25 * sin(minf(1.0, p.age / 0.25) * PI)
				var w: float = p.w * cell
				var h: float = p.h * cell
				n.draw_set_transform(origin + Vector2(ox + p.gx * cell + w / 2.0, oy + p.gy * cell + h / 2.0), 0.0, Vector2(s, s))
				Kit.rect(n, Rect2(-w / 2.0 + 1.0, -h / 2.0 + 1.0, w - 2.0, h - 2.0), p.c)
				_stroke_rect(n, Rect2(-w / 2.0 + 1.0, -h / 2.0 + 1.0, w - 2.0, h - 2.0), Color(19.0 / 255.0, 16.0 / 255.0, 32.0 / 255.0, 0.6))
				n.draw_set_transform(origin, 0.0, Vector2.ONE)
			# the ghost
			var gc := Kit.GOOD if valid else Kit.HOT
			var x := ox + gx * cell
			var y := oy + gy * cell
			var w := pw * cell
			var h := ph * cell
			Kit.rect(n, Rect2(x, y, w, h), _al(gc, 0.3))
			_stroke_rect(n, Rect2(x + 0.5, y + 0.5, w - 1.0, h - 1.0), gc, 1.5)
			for cv in b.bad:                             # the overlapping cells, crossed
				var c: Vector2i = cv
				var bxp := ox + c.x * cell
				var byp := oy + c.y * cell
				Kit.line(n, Vector2(bxp + 3.0, byp + 3.0), Vector2(bxp + cell - 3.0, byp + cell - 3.0), Kit.HOT, 1.5)
				Kit.line(n, Vector2(bxp + cell - 3.0, byp + 3.0), Vector2(bxp + 3.0, byp + cell - 3.0), Kit.HOT, 1.5)
			_dash(n, fp, Vector2(x + w / 2.0, y + h / 2.0), Kit.DIM, 1.0)
			Kit.dot(n, fp, 2.5, Kit.INK)
			Kit.ring(n, fp, 5.0, Kit.INK, 1.0)
			var sz := maxf(9.0, H * 0.058)
			_txt(n, "gx %d · gy %d · %d×%d%s" % [gx, gy, pw, ph, " · valid" if valid else " · blocked"], Vector2(ox, oy - 4.0), sz, gc)
			_txt(n, "%d placed · %d%% full" % [pieces.size(), roundi(float(b.filled) / float(cols * rows) * 100.0)], Vector2(ox + cols * cell, oy - 4.0), sz, Kit.DIM, "right")
			if clearedT < 1.2:
				_txt(n, "plot cleared", Vector2(W / 2.0, H / 2.0), sz * 1.4, _al(Kit.INK, 1.0 - clearedT / 1.2), "center")
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"jewel":
			Kit.stage(n, b, 0.0, true)
			var tiers: Array = D.tiers
			var colours: Array = D.colours
			var period: float = maxf(0.2, float(D.period))
			var band: float = D.band
			var cw := minf(W * 0.18, H * 0.3)
			var ch := cw * 1.3
			var cy := H * 0.45
			var sz := maxf(9.0, H * 0.058)
			for i in 4:
				var c: Dictionary = b.cards[i]
				var cx := W * (0.5 + (i - 1.5) * 0.22)
				var flip: float = c.flip
				var sx := absf(cos(flip / 0.5 * PI)) if flip < 0.5 else 1.0
				var tier: int = c.tier
				var col := Color(colours[tier % colours.size()] as String)
				var tname: String = tiers[tier % tiers.size()]
				n.draw_set_transform(origin + Vector2(cx, cy), 0.0, Vector2(maxf(0.02, sx), 1.0))
				if tier >= 2:
					Kit.glow(n, Vector2.ZERO, cw * 0.95, col, (0.4 if tier == 3 else 0.22) + 0.12 * sin(t * 3.0 + i))
				var card := Rect2(-cw / 2.0, -ch / 2.0, cw, ch)
				_rr_fill(n, card, 5.0, CARD)
				_rr_stroke(n, card, 5.0, col, 2.5 if tier == 3 else (1.0 if tier == 0 else 2.0))
				var gs := cw * (0.22 + 0.05 * tier)      # the gem, bigger by tier
				Kit.poly(n, [Vector2(0, -gs), Vector2(gs * 0.8, -gs * 0.3), Vector2(gs * 0.5, gs * 0.7), Vector2(-gs * 0.5, gs * 0.7), Vector2(-gs * 0.8, -gs * 0.3)], col)
				Kit.poly(n, [Vector2(0, -gs), Vector2(gs * 0.8, -gs * 0.3), Vector2(0, -gs * 0.3)], col.lerp(Color.WHITE, 0.45))
				Kit.poly(n, [Vector2(-gs * 0.8, -gs * 0.3), Vector2(0, -gs * 0.3), Vector2(-gs * 0.5, gs * 0.7)], col.lerp(Color.BLACK, 0.25))
				if tier == 3:
					for q in 3:
						var a := t * 1.5 + q * TAU / 3.0
						Kit.dot(n, Vector2(cos(a) * cw * 0.36, sin(a) * ch * 0.36), 1.5 + sin(t * 6.0 + q) * 0.8, Kit.SPARK)
				if tier > 0:                             # the sheen: a clipped re-stroke
					var uu := fposmod((t - i * 0.4) / period, 1.0)
					var span := cw + ch
					var s0 := -span / 2.0 + uu * span
					var bw := cw * band / 2.0
					# the web clips to the diagonal band; here the band ∩ the card is a polygon
					# (Sutherland–Hodgman) for the face, and the border is re-stroked only along
					# the pieces of its outline whose midpoints lie inside the band
					var bandp := [Vector2(s0 - bw + ch * 0.35, -ch), Vector2(s0 + bw + ch * 0.35, -ch), Vector2(s0 + bw - ch * 0.35, ch), Vector2(s0 - bw - ch * 0.35, ch)]
					var facep := _clip_poly_rect(bandp, card)
					if facep.size() >= 3:
						n.draw_colored_polygon(PackedVector2Array(facep), Color(1, 1, 1, 0.05 * tier))
					var rim := _rr_pts(card, 5.0)
					rim.append(rim[0])
					var scol := Color(1, 1, 1, 0.5 + 0.17 * tier)
					var sw := 2.0 + tier
					for j in rim.size() - 1:
						var p0 := rim[j]
						var p1 := rim[j + 1]
						var pieces := maxi(1, int(ceilf(p0.distance_to(p1) / 4.0)))
						for u in pieces:
							var q0 := p0.lerp(p1, u / float(pieces))
							var q1 := p0.lerp(p1, (u + 1) / float(pieces))
							var mid := (q0 + q1) / 2.0
							if absf(mid.x - (s0 - 0.35 * mid.y)) <= bw:
								n.draw_line(q0, q1, scol, sw)
				n.draw_set_transform(origin, 0.0, Vector2.ONE)
				_txt(n, tname, Vector2(cx, cy + ch / 2.0 + sz * 1.3), sz, col, "center")
				_lab(n, b, "tier %d" % tier, Vector2(cx, cy + ch / 2.0 + sz * 2.4), Kit.DIM, "center")
				# u for this card, as a tiny bar
				var uu2 := fposmod((t - i * 0.4) / period, 1.0)
				Kit.rect(n, Rect2(cx - cw / 2.0, cy - ch / 2.0 - 8.0, cw, 2.0), Color(201.0 / 255.0, 196.0 / 255.0, 228.0 / 255.0, 0.2))
				if tier > 0:
					Kit.rect(n, Rect2(cx - cw / 2.0 + cw * uu2 - 1.0, cy - ch / 2.0 - 9.0, 2.0, 4.0), col)
			_lab(n, b, "u", Vector2(W * (0.5 - 1.5 * 0.22) - cw / 2.0 - 4.0, cy - ch / 2.0 - 5.0), Kit.DIM, "right")
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"bossbar":
			Kit.stage(n, b, 0.6)
			var state: String = b.state
			var st: float = b.st
			var cur: int = b.cur
			var shakeAge: float = b.shakeAge
			var flash: float = b.flash
			var slash: float = b.slash
			var seg: Array = b.seg
			var phases: int = D.phases
			var cols := [Kit.HOT, Kit.FIRE, Kit.SUN, Kit.MAGIC, Kit.GOOD]
			var g := _bb_geom(b)
			var gbx: float = g.bx
			var gbw: float = g.bw
			var gby: float = g.by
			var gbh: float = g.bh
			var gsw: float = g.sw
			var ggap: float = g.gap
			var sz := maxf(9.0, H * 0.062)
			var dx: float = float(D.shake) * exp(-float(D.decay) * shakeAge) * sin(50.0 * shakeAge)
			var dy := dx * 0.4
			# the boss and the hero
			var bob := sin(t * 2.0) * 3.0
			var bx0 := W * 0.64
			var dead := state == "dead"
			var intro := state == "intro"
			var al := maxf(0.0, 1.0 - st / 2.0) if dead else 1.0
			var sink := st * H * 0.1 if dead else 0.0
			Kit.ellipse(n, Vector2(bx0, GY + 2.0), W * 0.14, H * 0.03, Color(0, 0, 0, 0.35 * al))
			var bodyC := Color("F4F0FF") if flash < 0.1 else (Color("3A2246") if state == "fight" and cur < phases - 1 else Color("2A2246"))
			bodyC.a = al
			var yb := GY + bob + sink
			Kit.ellipse(n, Vector2(bx0, yb - H * 0.2), W * 0.13, H * 0.2, bodyC)
			Kit.poly(n, [Vector2(bx0 - W * 0.1, yb - H * 0.34), Vector2(bx0 - W * 0.04, yb - H * 0.3), Vector2(bx0 - W * 0.1, yb - H * 0.25)], bodyC)
			Kit.poly(n, [Vector2(bx0 + W * 0.1, yb - H * 0.34), Vector2(bx0 + W * 0.04, yb - H * 0.3), Vector2(bx0 + W * 0.1, yb - H * 0.25)], bodyC)
			var eye := 2.0 + (phases - 1 - cur) * 1.2
			var eyeC := _al(INK_DARK if flash < 0.1 else Kit.HOT, al)
			Kit.dot(n, Vector2(bx0 - W * 0.04, yb - H * 0.26), eye, eyeC)
			Kit.dot(n, Vector2(bx0 + W * 0.04, yb - H * 0.26), eye, eyeC)
			Kit.hero(n, b, Vector2(W * 0.24, GY), { "pose": "jump" if slash < 0.2 else "stand", "frame": t })
			if slash < 0.2:
				n.draw_arc(Vector2(bx0 - W * 0.08, GY - H * 0.22), H * 0.12, -TAU * 0.3, TAU * 0.05, 24, _al(Kit.SPARK, 1.0 - slash / 0.2), 3.0)
			# the bar
			var fill_clock := _ease(st / maxf(0.1, float(D.intro))) * phases if intro else float(phases)
			_stroke_rect(n, Rect2(gbx + dx - 2.0, gby + dy - 2.0, gbw + 4.0, gbh + 4.0), Kit.BONE)
			for i in phases:
				var x := gbx + i * (gsw + ggap) + dx
				var y := gby + dy
				Kit.rect(n, Rect2(x, y, gsw, gbh), Color(0, 0, 0, 0.5))
				var si: float = seg[i]
				if si <= 0.0:
					continue
				var f := clampf(fill_clock - i, 0.0, 1.0) * si
				Kit.rect(n, Rect2(x, y, gsw * f, gbh), cols[i % 5])
				Kit.rect(n, Rect2(x, y, gsw * f, gbh * 0.3), Color(1, 1, 1, 0.18))
				if i == cur and flash < 0.12 and state == "fight":
					Kit.rect(n, Rect2(x, y, gsw * f, gbh), Color(1, 1, 1, 0.7 * (1.0 - flash / 0.12)))
			var nameA := _ease(st / 0.6) if intro else 1.0
			var nameY := gby - 6.0 - (1.0 - nameA) * 14.0
			_txt(n, "DEFEATED" if dead else str(D.name), Vector2(gbx + dx, nameY + dy), sz * 1.15, _al(Kit.INK, nameA))
			var phase_txt := ("intro %d%%" % roundi(fill_clock / phases * 100.0)) if intro else ("" if dead else "phase %d / %d" % [phases - cur, phases])
			_txt(n, phase_txt, Vector2(gbx + gbw, gby - 6.0), sz, cols[maxi(0, cur) % 5], "right")
			if shakeAge < 0.6:
				_lab(n, b, "dx = %.1f px" % dx, Vector2(gbx + gbw / 2.0, gby + gbh + 12.0), Kit.SUN, "center")
			for fv in b.falling:                         # the broken segments fall away
				var f: Dictionary = fv
				var fw: float = f.w
				var fh: float = f.h
				n.draw_set_transform(origin + Vector2(f.x + fw / 2.0, f.y + fh / 2.0), f.rot, Vector2.ONE)
				Kit.rect(n, Rect2(-fw / 2.0, -fh / 2.0, fw, fh), _al(cols[int(f.i) % 5], maxf(0.0, 1.0 - f.age / 1.4)))
				n.draw_set_transform(origin, 0.0, Vector2.ONE)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
