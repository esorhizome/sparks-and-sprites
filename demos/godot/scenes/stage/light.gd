extends RefCounted

const Kit := preload("res://scenes/stage/kit.gd")
## LIGHTING & VISIBILITY — thirteen effects, ported from the web almanac
## (docs/stagecraft.js, the light family). Light, and what it cannot reach.
## A 2D game has no photons: "lit" is a dark layer with holes punched in it,
## "shadow" is the part of the room a ray from the light never arrived at,
## "night" is a blue multiply with additive windows, and "bloom" is the
## bright parts drawn again, blurred, on top. This family spells each of
## those — the visibility polygon (a ray to every corner, sorted by angle),
## fog of war (a grid that remembers), a torch that shakes in the hand,
## torchlight whose shadows breathe, a day → night slider, lightning that
## decays exponentially, a stealth meter that fills inside a view cone,
## light shafts with dust, dusk windows on staggered timers, blob shadows
## that tilt to the slope, selective bloom, rooms that wake when entered,
## and colour-coded zones.
##
## THE PAINTER'S VERSION OF A DARKNESS LAYER. The web draws its darkness
## into an offscreen layer and ERASES light out of it (cutLight =
## destination-out, a radial gradient), clipped to a visibility polygon or
## a wedge, then lays the layer over the scene. Godot's _draw() has no
## erase and no clip, but it has per-vertex colour: every darkness layer
## here is ONE triangle array whose vertex alpha is the layer's alpha
## formula evaluated at that vertex — a fan through the visibility polygon
## (Visibility, Umbra: hard shadow edges, soft falloff), a polar mesh
## (Torch), one quad per tile (Fogofwar), a grid (Night). Each card's
## draw() says which. The web's "lighter" (additive) and "multiply" passes
## have no per-draw equivalent either: they are plain alpha here, brighter
## colours where the addition mattered. (The "true" Godot spelling —
## PointLight2D + LightOccluder2D + CanvasModulate — is the chapter's;
## the painter keeps the gallery one file per family.)

const TITLE := "Lighting & visibility"
const BLURB := "light and what it cannot reach — visibility polygons, fog of war, torches, night overlays, lightning, stealth meters, shafts, dusk windows, blob shadows, bloom, room lights, zones"
const DEFS := [
	{ "id": "visibility", "letter": "V", "name": "Visibility",
		"hint": "a ray to every wall corner (±ε), the hits sorted by angle and filled as a fan — the lexicon's Xmarks, fired a hundred times — press to set the light",
		"dials": { "cone": 360,          # degrees the light can see: 360 = all round, less = a clipped wedge
			"speed": 0.35,               # the wander rate (a Lissajous of t)
			"reach": 0.85,               # light radius inside the polygon, of W
			"rays": true,                # draw every ray and the corner it reaches
			"hold": 4,                   # seconds a pressed light stays put before wandering again
			"label": "ray → every corner ±ε · sort by θ · fill the fan" },
		"rhyme": { "name": "Viewcone", "hint": "the same polygon clipped to a 70° wedge that faces the way it walks — a guard's sight, shadows and all",
			"dials": { "cone": 70, "speed": 0.2 } } },
	{ "id": "fogofwar", "letter": "F", "name": "Fogofwar",
		"hint": "a grid that remembers: UNSEEN black, SEEN dim, VISIBLE a soft hole round the hero — the map fills in as it explores — press to send the hero",
		"dials": { "cols": 20,           # fog tiles across (rows follow the aspect)
			"sight": 0.17,               # sight radius, of W
			"memory": 0,                 # seconds a seen tile stays remembered (0 = forever)
			"speed": 0.16,               # hero speed, of W per second
			"dim": 0.55,                 # darkness of a remembered tile (unseen is 0.97)
			"label": "tile ∈ {unseen, seen, visible} · visible if |eye − tile| < r" },
		"rhyme": { "name": "Foglift", "hint": "a sight radius half again as wide, and remembered tiles that fade back to black over six seconds — a map you have to keep walking",
			"dials": { "sight": 0.27, "memory": 6 } } },
	{ "id": "torch", "letter": "T", "name": "Torch", "drag": true,
		"hint": "a feathered wedge with falloff, erased from a darkness layer; the aim shakes like a hand, a battery dims it — atlas Spotlight, held — drag to aim",
		"dials": { "half": 22,           # half-angle of the beam, degrees
			"reach": 0.8,                # beam length, of W
			"jitter": 1,                 # hand shake: how much noise rides on the aim
			"soft": 0.5,                 # how much of the beam's width is feathered edge (0..1)
			"battery": 25,               # seconds from full to flat, then a fresh cell goes in
			"dark": 0.94,                # the darkness layer's alpha
			"label": "wedge θ ± half · α(d) falloff · θ += noise(t)·jitter · × battery" },
		"rhyme": { "name": "Tunnelvision", "hint": "an 8° beam, a hand that shakes three times as hard, cells that last twelve seconds — the horror flashlight",
			"dials": { "half": 8, "jitter": 3, "battery": 12 } } },
	{ "id": "umbra", "letter": "U", "name": "Umbra",
		"hint": "a flickering point light PLUS its visibility polygon — the pillars' shadows breathe with the flame (atlas Candle, in a room) — press to move the torch",
		"dials": { "colour": "#F5C169",  # the light's colour
			"reach": 0.7,                # falloff radius, of W
			"flicker": 1,                # how much the flame breathes and the light point jitters
			"soft": 0.6,                 # the falloff's softness (cutLight's soft)
			"drift": 1,                  # how far the torch wanders around its base
			"label": "lit = visPoly(torch) ∩ falloff(d) · torch += noise(t)·flicker" },
		"rhyme": { "name": "Ultraviolet", "hint": "a cold purple light with a hard falloff and almost no flicker — the shadows stand still and cut like paper",
			"dials": { "colour": "#B070FF", "soft": 0.05, "flicker": 0.15 } } },
	{ "id": "night", "letter": "N", "name": "Night", "drag": true,
		"hint": "a blue MULTIPLY layer over the day, holes cut for lamps and windows, additive glows through them (ch03 additive, atlas Lantern) — drag: time of day",
		"dials": { "tint": "#1B2A7A",    # the night's colour
			"depth": 0.82,               # how dark full night gets (the layer's alpha at midnight)
			"lamps": ["#F5C169", "#F5C169"],   # the two street lamps' colours
			"day": 18,                   # seconds for a full day
			"hold": 4,                   # seconds a dragged time of day holds before the clock resumes
			"label": "scene × tint·n − holes(lamps) + lighter glows" },
		"rhyme": { "name": "Neonnight", "hint": "a deeper violet dark with one magenta and one cyan lamp — the same holes, a different city",
			"dials": { "tint": "#2A0A3A", "lamps": ["#FF3AC8", "#3AF0FF"], "depth": 0.92 } } },
	{ "id": "zap", "letter": "Z", "name": "Zap", "warn": "contains flashing light",
		"hint": "a white layer whose alpha decays exponentially, a jagged bolt, thunder that arrives late (distance ÷ sound speed, as a bar) — press to strike now",
		"dials": { "peak": 0.85,         # the flash's brightness at the strike
			"decay": 9,                  # per second: a ← a·e^(−decay·dt)
			"every": 5.5,                # seconds between autopilot strikes (± a third)
			"delay": 2.4,                # seconds of thunder delay per stage-width of distance
			"distant": false,            # true: bolts stay behind the hills, dim and short
			"rumble": 1.6,               # seconds the thunder lasts
			"label": "flash: a ← a·e^(−k·dt) · thunder after 0.3 + |x − hero|/W · delay" },
		"rhyme": { "name": "Zephyrstorm", "hint": "the storm on the far side of the hills: short dim bolts behind the ridge, a third of the flash, thunder that takes nine seconds",
			"dials": { "peak": 0.3, "distant": true, "delay": 6 } } },
	{ "id": "stealth", "letter": "S", "name": "Stealth", "drag": true,
		"hint": "a meter that fills while the hero stands in a guard's VIEW CONE, faster up close, drains outside: the ? then the ! (lexicon Ghost) — drag the hero",
		"dials": { "guards": 1,          # how many guards (up to two)
			"cone": 64,                  # view cone width, degrees
			"range": 0.42,               # how far a guard sees, of W
			"fill": 0.8,                 # meter per second at the edge of the range (doubles up close)
			"drain": 0.7,                # meter per second lost when unseen
			"sweep": 0.9,                # how fast the gaze sweeps (rad/s of a sine)
			"hold": 4,                   # seconds a dragged hero holds before it paces again
			"label": "m += dt·fill·(2 − d/range) in the cone · m −= dt·drain outside" },
		"rhyme": { "name": "Sentinel", "hint": "two guards sweeping out of phase and a meter that fills two and a half times as fast — the level where you wait for both to look away",
			"dials": { "guards": 2, "fill": 2 } } },
	{ "id": "volumetric", "letter": "V", "name": "Volumetric",
		"hint": "translucent QUADS from each window along the sun's direction, fading with length, dust that stays inside (atlas Motes, angled) — press: sun by x",
		"dials": { "windows": 3,         # how many windows in the back wall
			"width": 0.09,               # a window's width, of W
			"tilt": 0.4,                 # the idle sun's swing, radians from vertical
			"drift": 0.2,                # how fast the idle sun swings
			"haze": 0.4,                 # the shaft's alpha at the window
			"dust": 70,                  # motes, shared across the shafts
			"hold": 5,                   # seconds a pressed angle holds
			"label": "quad = window ⊕ sunDir·L · α fades along L · motes ∈ quad" },
		"rhyme": { "name": "Vault", "hint": "one narrow slit high in the wall and twice the dust, thick as smoke — a tomb, opened",
			"dials": { "windows": 1, "width": 0.05, "dust": 160, "haze": 0.55 } } },
	{ "id": "dusk", "letter": "D", "name": "Dusk",
		"hint": "windows switching on at STAGGERED thresholds as the sky darkens on a clock, headlights on a far road (atlas Skyline, timed) — press to jump to dusk",
		"dials": { "day": 26,            # seconds from noon to full night
			"houses": 6,                 # houses in the row
			"stagger": 0.35,             # the spread of the window thresholds (each in 0.35 .. 0.35 + stagger)
			"cars": 3,                   # cars on the road
			"reverse": false,            # true: the clock runs night → day (windows go off)
			"hold": 3,                   # seconds the end of the cycle holds before it wraps
			"label": "window_i lights when n > thr_i · thr_i ∈ [0.35, 0.35 + stagger] · headlights at n > 0.3" },
		"rhyme": { "name": "Dawnbreak", "hint": "the same thresholds with the clock run backward: a black sky lightening, windows going out one by one, headlights switching off",
			"dials": { "reverse": true, "day": 20 } } },
	{ "id": "blobshadow", "letter": "B", "name": "Blobshadow",
		"hint": "the blob sits where a GROUND RAYCAST under the hero lands, tilts to the surface NORMAL, shrinks with height (atlas Contact, on a hill) — press to jump",
		"dials": { "size": 1,            # the blob's radius at rest, × 10 px (scaled)
			"shrink": 0.6,               # how much of the radius is lost at the top of the jump
			"soft": 0.5,                 # the blob's edge: 0 hard, 1 all gradient
			"jumpH": 0.26,               # jump apex, of H
			"speed": 0.22,               # run speed, of W per second
			"g": 2.2,                    # gravity, × H per s²
			"hill": 0.2,                 # the hill's height, of H
			"label": "ray ↓ hits g(x) · tilt = atan g′(x) · r = r₀·(1 − shrink·h/hmax)" },
		"rhyme": { "name": "Brightnoon", "hint": "half the blob, nearly gone at the apex, with a hard edge — the sun straight overhead",
			"dials": { "size": 0.55, "shrink": 0.85, "soft": 0.1 } } },
	{ "id": "bloom", "letter": "B", "name": "Bloom",
		"hint": "a GLOW MASK: only bulbs and the laser go to a layer, blurred by offset copies and added back; the scene stays crisp (ch06 glow) — press to hang a bulb: it swings in on its wire and rings down, halo and all",
		"dials": { "radius": 5,          # blur radius, px (scaled to the card)
			"strength": 1,               # how much of the blur is added back
			"mask": "emitters",          # "emitters": only the light sources bloom · "all": the whole frame does
			"laser": true,               # a sweeping laser among the emitters
			"max": 8,                    # hung bulbs kept (the oldest falls when a new one comes)
			"g": 2.0,                    # gravity, in H per second² — a hung bulb is a pendulum on its wire: θ'' = −(g/L)·sin θ − damp·θ'
			"damp": 1.0,                 # the wire's drag, per second: the swing's envelope is e^(−damp·t/2), so it rings down in a few seconds
			"swing": 1.6,                # the angular speed a bulb is let go with, rad/s — the hand that hung it
			"label": "mask → Σ offset copies (r, then 2r) → lighter × strength · bulb: θ'' = −(g/L)·sin θ − damp·θ'" },
		"rhyme": { "name": "Blaze", "hint": "no mask at all: the whole frame goes to the blur and comes back added — the overexposed look, every edge haloed",
			"dials": { "mask": "all", "strength": 0.75, "radius": 7 } } },
	{ "id": "interior", "letter": "I", "name": "Interior",
		"hint": "four rooms, each dark until ENTERED: a hard-edged rect light per room that wakes on a tween (lexicon Zones, indoors) — press to send the hero there",
		"dials": { "wake": 0.7,          # seconds for a room's light to come up
			"linger": 0,                 # seconds after leaving before a room fades (0 = it stays lit)
			"fade": 1.2,                 # seconds for a room to fade back to dark
			"speed": 0.2,                # walk speed, of W per second
			"dark": 0.9,                 # an unlit room's overlay alpha
			"label": "lit_i → 1 over wake s while hero ∈ room_i · α_i = dark·(1 − lit_i)" },
		"rhyme": { "name": "Infrared", "hint": "rooms that forget you: two seconds after you leave, a room fades back to black — only where you are is ever lit",
			"dials": { "linger": 2, "fade": 1.5 } } },
	{ "id": "zonelight", "letter": "Z", "name": "Zonelight",
		"hint": "colour-coded light: the tint says safe or danger before the enemy does; zones pulse, an enemy patrols the red, the hero wears the tint — press to move",
		"dials": { "zones": [{ "x": 0, "w": 0.34, "kind": "safe" }, { "x": 0.34, "w": 0.36, "kind": "danger" }, { "x": 0.7, "w": 0.3, "kind": "safe" }],   # x, w of W
			"colours": { "safe": "#9BE28A", "danger": "#F58A8A" },
			"pulse": 1.2,                # danger's pulse rate, Hz (safe pulses at half)
			"soft": 0,                   # how much of a zone's width is feathered edge (0 = hard)
			"entryFlash": 0,             # seconds a danger zone flares when the hero steps in (0 = never)
			"speed": 0.18,               # hero speed, of W per second
			"hold": 4,                   # seconds a pressed target holds before the pacing resumes
			"label": "tint = colours[zone(x)] · α = base + pulse·sin(t·rate)" },
		"rhyme": { "name": "Zonewarn", "hint": "the danger zone flares for half a second when the hero steps in, and every edge is feathered — the level that warns you",
			"dials": { "entryFlash": 0.6, "soft": 0.5 } } },
]

const FAINT := Color(0.91, 0.898, 0.957, 0.55)   # the web label's default ink
const INK_DARK := Color("2B2440")                  # the sprite's outline colour, doors and unlit windows
const POST := Color("3A3355")                      # lamp posts, turrets, car bodies
const WOOD := Color("5A3E2B")

# ---------------------------------------------------------------- small maths

## The shortest signed angle (JS: atan2(sin d, cos d)).
static func _wrap(a: float) -> float:
	return atan2(sin(a), cos(a))

## The web kit's ease(): a clamped smoothstep.
static func _ease(k: float) -> float:
	k = clampf(k, 0.0, 1.0)
	return k * k * (3.0 - 2.0 * k)

## c with its alpha replaced (the web's rgba(c, a)).
static func _al(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, a)

## The web label's "right" alignment: measure, then draw ending at p.x.
static func _label_r(n: CanvasItem, b: Dictionary, txt: String, p: Vector2, col: Color = FAINT) -> void:
	var f := ThemeDB.fallback_font
	var w: float = f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	Kit.label(n, b, txt, Vector2(p.x - w, p.y), col)

## cutLight's erase profile at normalised distance u = d / r: a at the
## centre, 0.6·a at (1 − soft), nothing at the rim. What a darkness layer
## LOSES there.
static func _cut(u: float, soft: float, a: float) -> float:
	if u >= 1.0:
		return 0.0
	var k1 := maxf(0.01, 1.0 - clampf(soft, 0.0, 1.0))
	if u <= k1:
		return a + (0.6 * a - a) * (u / k1)
	return 0.6 * a * (1.0 - (u - k1) / (1.0 - k1))

## glow()'s profile at u = d / r: a, 0.35·a at the half, 0 at the rim.
static func _glow_at(u: float, a: float) -> float:
	if u >= 1.0:
		return 0.0
	if u <= 0.5:
		return a + (0.35 * a - a) * (u / 0.5)
	return 0.35 * a * (1.0 - (u - 0.5) / 0.5)

## A ray from p along d against wall segments plus the stage border: the
## nearest hit distance (the kit's vis_poly casting, for ONE ray — the two
## edges of a view cone need it).
static func _ray_hit(b: Dictionary, p: Vector2, d: Vector2, segs: Array) -> float:
	var all: Array = segs.duplicate()
	all.append([0.0, 0.0, b.w, 0.0])
	all.append([b.w, 0.0, b.w, b.h])
	all.append([b.w, b.h, 0.0, b.h])
	all.append([0.0, b.h, 0.0, 0.0])
	var best := INF
	for sg in all:
		var x3: float = sg[0]
		var y3: float = sg[1]
		var x4: float = sg[2]
		var y4: float = sg[3]
		var den := d.x * (y4 - y3) - d.y * (x4 - x3)
		if absf(den) < 1e-9:
			continue
		var tt := ((x3 - p.x) * (y4 - y3) - (y3 - p.y) * (x4 - x3)) / den
		var u := ((x3 - p.x) * d.y - (y3 - p.y) * d.x) / den
		if tt > 0.0 and u >= 0.0 and u <= 1.0 and tt < best:
			best = tt
	return best if is_finite(best) else b.w + b.h

# ---------------------------------------------------------------- the darkness meshes

## The workhorse: one triangle array from a fan of rays out of c. dirs[j]
## is a unit direction, rad[j] its ring radii (all rays the same count),
## alp[j] the alpha at each ring; the colour is col. Consecutive rays are
## stitched into quads (and the last back to the first when closed). Per-
## vertex alpha, linearly interpolated by the GPU, is the painter's radial
## gradient — and rings placed at the gradient's stops make it exact there.
static func _fan_mesh(n: CanvasItem, c: Vector2, dirs: Array, rad: Array, alp: Array, col: Color, closed: bool) -> void:
	var m := dirs.size()
	if m < 2:
		return
	var rings: int = (rad[0] as PackedFloat32Array).size()
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	for j in m:
		var d: Vector2 = dirs[j]
		var rr: PackedFloat32Array = rad[j]
		var aa: PackedFloat32Array = alp[j]
		for k in rings:
			pts.append(c + d * rr[k])
			cols.append(Color(col.r, col.g, col.b, aa[k]))
	var spans := m if closed else m - 1
	for j in spans:
		var j1 := (j + 1) % m
		for k in rings - 1:
			var a0 := j * rings + k
			var c0 := j1 * rings + k
			idx.append(a0)
			idx.append(c0)
			idx.append(c0 + 1)
			idx.append(a0)
			idx.append(c0 + 1)
			idx.append(a0 + 1)
	RenderingServer.canvas_item_add_triangle_array(n.get_canvas_item(), idx, pts, cols)

## Darkness (col at alpha dark) with (polygon ∩ cutLight(r, soft, a)) cut
## out of it — the web's layer("dark") + clip(poly) + cutLight, as one
## mesh. pts are the polygon's vertices sorted by angle about the light L
## (a visibility polygon is star-shaped from its light, so a fan through
## them tiles it exactly). Rings per ray: the centre, the two gradient
## stops, the polygon edge TWICE (once lit, once dark — that doubled ring
## is the hard shadow edge) and a far ring past the card at full darkness.
static func _poly_dark(n: CanvasItem, b: Dictionary, L: Vector2, pts: Array, r: float, soft: float, a: float, col: Color, dark: float, closed: bool) -> void:
	var r1: float = r * maxf(0.01, 1.0 - clampf(soft, 0.0, 1.0))
	var big: float = b.w + b.h
	var dirs: Array = []
	var rad: Array = []
	var alp: Array = []
	for p in pts:
		var v: Vector2 = p - L
		var d := v.length()
		dirs.append(v / d if d > 1e-6 else Vector2.RIGHT)
		var rr := PackedFloat32Array([0.0, minf(d, r1), minf(d, r), d, d, big])
		var aa := PackedFloat32Array()
		for k in 4:
			aa.append(dark * (1.0 - _cut(rr[k] / r, soft, a)))
		aa.append(dark)
		aa.append(dark)
		rad.append(rr)
		alp.append(aa)
	_fan_mesh(n, L, dirs, rad, alp, col, closed)

## glow(L, r, col, a) clipped to the polygon — the warm colour a torch
## throws only where its light reaches. Same fan, the glow's stops.
static func _poly_glow(n: CanvasItem, L: Vector2, pts: Array, r: float, a: float, col: Color) -> void:
	var dirs: Array = []
	var rad: Array = []
	var alp: Array = []
	for p in pts:
		var v: Vector2 = p - L
		var d := v.length()
		dirs.append(v / d if d > 1e-6 else Vector2.RIGHT)
		var rr := PackedFloat32Array([0.0, minf(d, r * 0.5), minf(d, r), d])
		var aa := PackedFloat32Array()
		for k in 4:
			aa.append(_glow_at(rr[k] / r, a))
		rad.append(rr)
		alp.append(aa)
	_fan_mesh(n, L, dirs, rad, alp, col, true)

## Full darkness over an angular range (the back of a view cone): a fan of
## radius past the card, every vertex at alpha dark.
static func _sector_dark(n: CanvasItem, b: Dictionary, L: Vector2, a0: float, a1: float, col: Color, dark: float) -> void:
	var big: float = b.w + b.h
	var dirs: Array = []
	var rad: Array = []
	var alp: Array = []
	var rr := PackedFloat32Array([0.0, big])
	var aa := PackedFloat32Array([dark, dark])
	for i in 17:
		var ang := a0 + (a1 - a0) * i / 16.0
		dirs.append(Vector2(cos(ang), sin(ang)))
		rad.append(rr)
		alp.append(aa)
	_fan_mesh(n, L, dirs, rad, alp, col, false)

## The visibility polygon as an Array of Vector2 (the kit returns a packed
## array; the fans and the ray loops want plain points).
static func _pts_of(packed: PackedVector2Array) -> Array:
	var out: Array = []
	for p in packed:
		out.append(p)
	return out

## A closed outline through pts.
static func _outline(n: CanvasItem, pts: Array, col: Color, w: float = 1.0) -> void:
	if pts.size() < 2:
		return
	var packed := PackedVector2Array(pts)
	packed.append(pts[0])
	n.draw_polyline(packed, col, w)

## Which of the polygon's points lie inside the wedge |θ − head| ≤ half,
## plus the wedge's two edge rays cast for real — sorted by angle from the
## wedge's left edge to its right, ready for a fan.
static func _wedge_pts(b: Dictionary, L: Vector2, pts: Array, segs: Array, head: float, half: float) -> Array:
	var keep: Array = []
	for p in pts:
		var q: Vector2 = p
		var off := _wrap(atan2(q.y - L.y, q.x - L.x) - head)
		if absf(off) <= half:
			keep.append([off, q])
	for sgn in [-1.0, 1.0]:
		var edge_a: float = head + sgn * half
		var d := Vector2(cos(edge_a), sin(edge_a))
		keep.append([sgn * half, L + d * _ray_hit(b, L, d, segs)])
	keep.sort_custom(func(p: Array, q: Array) -> bool: return p[0] < q[0])
	var out: Array = []
	for e in keep:
		out.append(e[1])
	return out

# ---------------------------------------------------------------- per-card helpers

## Blobshadow's ground: two Gaussian hills on the flat line, and its slope.
static func _hill_y(b: Dictionary, x: float) -> float:
	var D: Dictionary = b.D
	var a: float = (x - b.c1) / b.w1
	var c: float = (x - b.c2) / b.w2
	return b.gy - b.h * D.hill * (exp(-a * a) + 0.4 * exp(-c * c))

static func _hill_slope(b: Dictionary, x: float) -> float:
	var D: Dictionary = b.D
	var a: float = (x - b.c1) / b.w1
	var c: float = (x - b.c2) / b.w2
	return -b.h * D.hill * (exp(-a * a) * (-2.0 * a / b.w1) + 0.4 * exp(-c * c) * (-2.0 * c / b.w2))

static func _blob_jump(b: Dictionary) -> void:
	if not b.air:
		b.air = true
		b.vy = -sqrt(2.0 * b.G * b.hmax)

## Stealth: does the cover crate stand between the eye and the point?
static func _blocked(b: Dictionary, ex: float, ey: float, px: float, py: float) -> bool:
	var cx: float = b.cx
	var cw: float = b.cw
	if (cx - ex) * (cx - px) > 0.0:
		return false
	var run: float = px - ex
	if absf(run) < 1e-9:
		run = 1e-6
	var k := (cx - ex) / run
	var y := ey + (py - ey) * k
	return y > b.gy - cw and y < b.gy

## Interior: which room is x on this floor?
static func _room_of(b: Dictionary, x: float, fl: int) -> int:
	var xm: float = b.xm
	if fl == 0:
		return 0 if x < xm else 1
	return 3 if x < xm else 2

## Zonelight: which zone is x in (−1 = none)?
static func _zone_at(b: Dictionary, x: float) -> int:
	var zones: Array = b.D.zones
	for i in zones.size():
		var z: Dictionary = zones[i]
		var zx: float = z.x * b.w
		var zw: float = z.w * b.w
		if x >= zx and x < zx + zw:
			return i
	return -1

## Zap's strike: a random walk downward from the cloud to x, two branches,
## and a thunderclap queued at 0.3 s + distance × delay.
static func _strike(b: Dictionary, x: float) -> void:
	var D: Dictionary = b.D
	var W: float = b.w
	var H: float = b.h
	x = clampf(x, 6.0, W - 6.0)
	var distant: bool = D.distant
	var bottom: float = b.gy - H * 0.14 if distant else b.gy
	var nseg := 11
	var spread: float = W * (0.012 if distant else 0.035)
	var main: Array = []
	var px := x + randf_range(-W * 0.05, W * 0.05)
	for i in nseg + 1:
		if i > 0 and i < nseg:
			px += randf_range(-spread, spread)
		main.append(Vector2(x if i == nseg else px, bottom * i / float(nseg)))
	var branches: Array = []
	for k in 2:
		var p: Vector2 = main[3 + k * 3]
		var dir: float = -1.0 if k == 0 else 1.0
		var br: Array = [p]
		var qx := p.x
		var qy := p.y
		for _i in 3:
			qx += dir * randf_range(spread * 0.6, spread * 1.6)
			qy += bottom / nseg * randf_range(0.5, 1.0)
			br.append(Vector2(qx, qy))
		branches.append(br)
	b.bolt = { "main": main, "branches": branches }
	b.ba = 1.0
	b.fa = 1.0
	var dist: float = 1.5 if distant else absf(x - b.hx) / W
	var at: float = 0.3 + dist * D.delay
	if (b.pending as Array).size() < 4:
		b.pending.append({ "at": at, "total": at })

## Bloom: ONLY the light sources — the lamp bulbs, the hung bulbs, the
## laser and its hit. Drawn crisp into the scene, and again as the mask.
## Where a hung bulb is now: its wire's anchor, swung by its pendulum angle.
static func _bulb_at(bl: Dictionary) -> Vector2:
	return Vector2(float(bl.ax) + sin(float(bl.th)) * float(bl.L), cos(float(bl.th)) * float(bl.L))

static func _emitters(n: CanvasItem, b: Dictionary, hit_x: float) -> void:
	var D: Dictionary = b.D
	var S: float = b.h / 170.0
	for px in b.posts:
		Kit.dot(n, Vector2(px, b.postY), 5.0, Kit.SUN)
	for bl in b.bulbs:
		Kit.dot(n, _bulb_at(bl), 3.5 * S, Kit.SUN)
	if D.laser:
		Kit.line(n, Vector2(b.lx0, b.ly0), Vector2(hit_x, b.gy), Kit.HOT, 1.5 * S)
		Kit.dot(n, Vector2(hit_x, b.gy), 3.0 * S, Kit.SPARK)

## Bloom's blur, approximated: the web blurs the mask with eight offset
## copies at radius r and again at 2r, then adds both back ("lighter").
## Without offscreen layers or addition, every disc gets two soft glows
## (radii ≈ disc + 3r and disc + 1.5r) and the laser three wide translucent
## strokes — the same halo shape, plain alpha.
static func _halo(n: CanvasItem, b: Dictionary, hit_x: float) -> void:
	var D: Dictionary = b.D
	var S: float = b.h / 170.0
	var r: float = b.r
	var k: float = minf(1.0, D.strength)
	for px in b.posts:
		var p := Vector2(px, b.postY)
		Kit.glow(n, p, 5.0 + 3.0 * r, Kit.SUN, 0.55 * k)
		Kit.glow(n, p, 5.0 + 1.5 * r, Kit.SUN, 0.45 * k)
	for bl in b.bulbs:
		var p := _bulb_at(bl)
		Kit.glow(n, p, 3.5 * S + 3.0 * r, Kit.SUN, 0.55 * k)
		Kit.glow(n, p, 3.5 * S + 1.5 * r, Kit.SUN, 0.45 * k)
	if D.laser:
		var a := Vector2(b.lx0, b.ly0)
		var c := Vector2(hit_x, b.gy)
		Kit.line(n, a, c, _al(Kit.HOT, 0.08 * k), 1.5 * S + 6.0 * r)
		Kit.line(n, a, c, _al(Kit.HOT, 0.14 * k), 1.5 * S + 3.0 * r)
		Kit.line(n, a, c, _al(Kit.HOT, 0.22 * k), 1.5 * S + 1.5 * r)
		Kit.glow(n, c, 3.0 * S + 3.0 * r, Kit.SPARK, 0.6 * k)

# ================================================================ init

static func init(b: Dictionary) -> void:
	var D: Dictionary = b.D
	var W: float = b.w
	var H: float = b.h
	var GY: float = b.gy
	match b.id:
		"visibility":
			# a VISIBILITY POLYGON is what one point can see. the lexicon's Xmarks asked
			# "where does this ray first hit?" once; here it is asked for every wall
			# corner, plus a hair to either side of each (so a ray slides past the
			# corner and finds the wall behind it), and the hits, sorted by angle, are
			# the polygon's vertices. fill the fan and you have light with shadows;
			# test a point against it and you have line of sight. the kit's vis_poly
			# does the casting — this card draws what it did.
			b.blocks = [[0.22, 0.30, 0.06, 0.28], [0.52, 0.60, 0.17, 0.08], [0.72, 0.16, 0.05, 0.26]]   # x, y, w, h of W and H
			b.segs = []
			b.corners = []
			for bl in b.blocks:
				var x: float = bl[0] * W
				var y: float = bl[1] * H
				var w: float = bl[2] * W
				var h: float = bl[3] * H
				b.segs.append_array([[x, y, x + w, y], [x + w, y, x + w, y + h], [x + w, y + h, x, y + h], [x, y + h, x, y]])
				b.corners.append_array([Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h)])
			b.half = minf(180.0, D.cone) * PI / 360.0
			b.coned = D.cone < 360
			b.hs = maxf(1.0, roundf(H / 110.0))
			b.lx = W * 0.5
			b.ly = H * 0.5
			b.px = 0.0
			b.py = 0.0
			b.hold = 0.0
			b.head = 0.0
			b.lastx = b.lx
			b.lasty = b.ly
		"fogofwar":
			# FOG OF WAR is three states per tile. VISIBLE: inside the sight radius
			# right now. SEEN: it was visible once, so the map is remembered but the
			# tile is dimmed (and nothing that moves is drawn there). UNSEEN: black.
			# the overlay is one layer: every tile painted at its darkness, then one
			# soft hole erased around the eye so the visible disc has no stair-steps.
			# a memory dial lets remembered tiles fade back toward unseen.
			var cols: int = D.cols
			b.tw = W / cols
			b.rows = int(ceil(H / b.tw))
			b.nn = cols * b.rows
			b.last = []                                  # when each tile was last visible (−1 = never)
			for _i in b.nn:
				b.last.append(-1.0)
			var R := Kit.rng(3)
			b.R = R
			b.props = []
			for i in 10:
				b.props.append({ "k": i % 3, "x": W * (0.05 + R.randf() * 0.9), "y": H * (0.2 + R.randf() * 0.75) })
			b.hs = maxf(1.0, roundf(H / 100.0))
			b.hx = W * 0.15
			b.hy = H * 0.5
			b.tx = W * 0.6
			b.ty = H * 0.4
			b.face = 1
			b.clock = 0.0
			b.idle = 0.0
		"torch":
			# a FLASHLIGHT is a darkness layer (one near-black rect) with a cone erased
			# out of it. the cone is four nested wedges, each a little narrower and
			# each erased again, so the edge feathers; a radial gradient along the beam
			# is the falloff. the hand adds two noises to the aim — a slow drift and a
			# fast tremor — and a battery scales the whole erase: dying cells flicker.
			var hs: float = maxf(2.0, roundf(H / 60.0))
			b.hs = hs
			b.hx = W * 0.17
			b.ox = b.hx + 5.0 * hs
			b.oy = GY - 8.0 * hs
			b.aim = -0.15
			b.goal = -0.15
			b.hold = 0.0
			b.bat = 1.0
			b.swap = 0.0
		"umbra":
			# TORCHLIGHT WITH SHADOWS is Visibility with a colour and a pulse: the
			# polygon says where the light can reach, a radial falloff says how much,
			# and the darkness layer is erased by their intersection. the flame
			# breathes (a noise on the radius) and the light POINT jitters by a couple
			# of pixels, so every shadow edge moves — that is what makes fire read as
			# fire. a warm glow clipped to the same polygon tints what it lights.
			b.pillars = [[0.30, 0.42, 0.05], [0.56, 0.26, 0.06], [0.80, 0.50, 0.07]]   # x, top y, w — standing on the floor
			b.segs = []
			for pl in b.pillars:
				var x: float = pl[0] * W
				var y: float = pl[1] * H
				var w: float = pl[2] * W
				b.segs.append_array([[x, y, x + w, y], [x + w, y, x + w, GY], [x + w, GY, x, GY], [x, GY, x, y]])
			b.bx = W * 0.45
			b.by = H * 0.5
			b.lx = b.bx
			b.ly = b.by
		"night":
			# a NIGHT OVERLAY is the cheapest lighting there is: one blue rect drawn
			# with MULTIPLY (it darkens toward blue, never lightens), and a HOLE cut
			# out of it (destination-out) around every light source so the scene keeps
			# its day colours there. an ADDITIVE glow (chapter 03's "lighter") over the
			# hole gives the lamp its colour. n runs 0 at noon to 1 at midnight and
			# scales all three, so one number is the whole time of day.
			b.lampsX = [W * 0.32, W * 0.72]
			b.lampY = GY - H * 0.3 - 8.0                 # the kit lamp's bulb sits 0.3 H + 8 above its foot
			b.houses = [[W * 0.06, W * 0.16], [W * 0.5, W * 0.15], [W * 0.84, W * 0.13]]
			b.hh = H * 0.22
			b.tod = 0.1                                  # 0 = noon, 0.5 = midnight
			b.hold = 0.0
		"zap":
			# LIGHTNING is an exponential decay you can see: the strike sets a = 1 and
			# every frame multiplies it by e^(−k·dt), so the flash is framerate-proof
			# and never quite reaches zero. the bolt is a random walk downward with two
			# branches. thunder is the same event arriving late: light is instant,
			# sound crosses the stage at "delay" seconds per width, so a bar counts
			# the distance down and the rumble lands when it fills (the atlas's
			# Stormfront had the flash; this has the timing). sound only after a press.
			b.hx = W * 0.3
			b.pending = []
			b.fa = 0.0
			b.ba = 0.0
			b.bolt = {}
			b.nextAt = 3.0
			b.armed_sound = false
			b.rumble = 0.0
		"stealth":
			# a DETECTION METER turns the lexicon's Ghost test (in the cone if
			# gaze · dir > cos(half)) from a yes/no into a number that accumulates:
			# inside the cone it fills at a rate that grows as the distance shrinks,
			# outside it drains. half full shows the "?" (the guard is suspicious),
			# full shows the "!" (found) and the level resets. a crate between eye
			# and hero blocks the line (one segment-vs-rect test), so cover counts.
			b.hs = maxf(2.0, roundf(H / 60.0))
			b.gx = [W * 0.7, W * 0.22]
			b.gph = [0.0, 2.1]
			b.gface = [-1, 1]
			b.cx = W * 0.47                              # the cover crate
			b.cw = H * 0.1
			b.half = D.cone * PI / 360.0
			b.range = W * D.range
			b.meters = [0.0, 0.0]
			b.gh = [0.0, 0.0]                            # this frame's gaze headings, for draw
			b.gseen = [false, false]
			b.hx = W * 0.35
			b.tx = b.hx
			b.hold = 0.0
			b.clock = 0.0
			b.alert = 0.0
			b.caught = 0
			b.face = 1
		"volumetric":
			# LIGHT SHAFTS are geometry, not blur: each window's two top corners are
			# pushed along the sun's direction until they meet the floor, and the four
			# points make a quad filled with one linear gradient (bright at the window,
			# gone at the floor) drawn with "lighter". the dust is parametric — a mote
			# is (which shaft, how far along, how far across), so it can never leave
			# the light; the atlas's Motes did this for one vertical shaft.
			b.wy0 = H * 0.1
			b.wy1 = H * 0.24
			b.ww = W * D.width
			b.Lf = GY - b.wy0
			var nw: int = maxi(1, D.windows)
			b.nw = nw
			b.wins = []
			for i in nw:
				b.wins.append(W * (0.5 + (i - (nw - 1) / 2.0) * 0.28) - b.ww / 2.0)
			var R := Kit.rng(5)
			b.motes = []
			for i in D.dust:
				b.motes.append({ "w": i % nw, "s": R.randf(), "v": R.randf(), "sp": 0.03 + R.randf() * 0.05, "ph": R.randf() * 100.0 })
			b.ang = 0.0
			b.held = 0.0
			b.hold = 0.0
		"dusk":
			# DISTANT LIGHTS are the cheapest "a town lives here": every window owns a
			# THRESHOLD on the night value n, drawn once from a seeded random, and
			# switches on (with a short ease, so it does not pop) the moment n passes
			# it. one clock drives the sky, the windows, the stars, and the headlights
			# — the atlas's Skyline had the lit windows; this has the evening they
			# switch on in. reverse the clock and the same thresholds give you dawn.
			var R := Kit.rng(11)
			var houses: int = D.houses
			b.hw = W * 0.8 / houses * 0.68
			b.hh = H * 0.2
			b.road = H * 0.9
			b.hxs = []
			b.thr = []
			for i in houses:
				b.hxs.append(W * (0.08 + i * 0.84 / houses))
				b.thr.append([0.35 + D.stagger * R.randf(), 0.35 + D.stagger * R.randf()])
			b.stars = []
			for _i in 30:
				b.stars.append([R.randf() * W, R.randf() * H * 0.5, R.randf() * 10.0])
			b.cars = []
			for _i in D.cars:
				b.cars.append({ "x": R.randf() * W, "v": W * (0.06 + R.randf() * 0.08), "dir": -1.0 if R.randf() < 0.5 else 1.0 })
			b.clock = 0.0
		"blobshadow":
			# a BLOB SHADOW does not need a light: it needs to know where the ground
			# is UNDER the sprite. cast a ray straight down from the feet (here the
			# ground is a function, so the hit is g(x) directly), read the slope there
			# (g′(x), the lexicon's Normals) and rotate the ellipse to lie on it; the
			# height above the hit shrinks and fades it, as the atlas's Contact did on
			# flat ground. the shadow is what tells the eye where the jump will land.
			b.G = H * D.g
			b.hmax = H * D.jumpH
			b.c1 = W * 0.58
			b.w1 = W * 0.16
			b.c2 = W * 0.2
			b.w2 = W * 0.1
			b.x = W * 0.05
			b.y = _hill_y(b, b.x)
			b.vy = 0.0
			b.air = false
			b.clock = 0.0
			b.autoOK = true
		"bloom":
			# SELECTIVE BLOOM is a question of WHAT gets blurred. chapter 06 glowed a
			# whole sprite; a real bloom pass would blur everything above a brightness
			# threshold, and the cheap 2D answer is to skip the threshold: draw only
			# the things that should glow (the EMITTERS) into their own layer, blur
			# that — eight offset copies at 1/8 alpha, twice — and add it back with
			# "lighter". the scene underneath never blurs. mask: "all" shows the
			# difference: the whole frame goes to the blur, and everything overexposes.
			# a hung bulb is a PENDULUM: its wire is the length L, the press lets it go
			# with a push, and θ'' = −(g/L)·sin θ − damp·θ' swings it in and rings it
			# down. the emitter moves, so its bloom moves with it — the mask is drawn
			# from the same swung positions as the scene.
			b.r = D.radius * H / 170.0
			b.posts = [W * 0.25, W * 0.75]
			b.postY = GY - H * 0.3 - 8.0
			b.bulbs = []                                 # a bulb: { ax: the wire's anchor x, L: its length, th: the angle from hanging straight, w: its angular speed }
			b.lx0 = W * 0.06
			b.ly0 = H * 0.12
		"interior":
			# ROOM-BASED LIGHTING skips the physics: the level is a list of RECTS, each
			# with one number, lit, that tweens toward 1 while the hero is inside it.
			# the overlay is a hard-edged dark rect per room at alpha dark·(1 − lit),
			# so a doorway is a sharp line between a lit room and a black one — the
			# lexicon's Zones, with a light instead of a state. a linger dial lets
			# rooms forget you: they fade back to dark a few seconds after you leave.
			b.hs = maxf(2.0, roundf(H / 60.0))
			b.x0 = W * 0.08
			b.x1 = W * 0.92
			b.top = H * 0.12
			b.mid = (b.top + GY) / 2.0
			b.xm = (b.x0 + b.x1) / 2.0
			b.rooms = [Rect2(b.x0, b.mid, b.xm - b.x0, GY - b.mid), Rect2(b.xm, b.mid, b.x1 - b.xm, GY - b.mid),
				Rect2(b.xm, b.top, b.x1 - b.xm, b.mid - b.top), Rect2(b.x0, b.top, b.xm - b.x0, b.mid - b.top)]
			b.ladder = [b.x1 - W * 0.05, b.x0 + W * 0.05]   # up on the right, down on the left
			b.lit = [0.0, 0.0, 0.0, 0.0]
			b.away = [0.0, 0.0, 0.0, 0.0]
			b.hx = b.x0 + W * 0.1
			b.hy = GY
			b.fl = 0
			b.target = 1
			b.tour = 1
			b.phase = "walk"
			b.wait = 0.0
			b.clock = 0.0
			b.face = 1
		"zonelight":
			# COLOUR-CODED LIGHT is a rule made visible: every zone is a column of
			# tinted light ("lighter", so it brightens what it covers) and the tint IS
			# the message — green for safe, red for danger — read from across the
			# room before the enemy is. the hero picks up the tint of the zone it
			# stands in (chapter 03's tint, driven by position), and danger pulses
			# twice as fast as safe, so the rhythm says it too.
			var hs: float = maxf(2.0, roundf(H / 60.0))
			b.hs = hs
			var zones: Array = D.zones
			var dz := -1
			for i in zones.size():
				if (zones[i] as Dictionary).kind == "danger" and dz < 0:
					dz = i
			b.dz = dz
			if dz >= 0:
				var z: Dictionary = zones[dz]
				b.eb0 = z.x * W + 6.0 * hs
				b.eb1 = (z.x + z.w) * W - 6.0 * hs
			else:
				b.eb0 = 6.0 * hs
				b.eb1 = W - 6.0 * hs
			b.hx = W * 0.12
			b.tx = b.hx
			b.hold = 0.0
			b.clock = 0.0
			b.face = 1
			b.zone = -1
			b.flash = 0.0
			b.hits = 0
			b.hitT = 0.0
			b.ex = (b.eb0 + b.eb1) / 2.0
			b.edir = 1

# ================================================================ press

static func press(b: Dictionary, pos: Vector2) -> void:
	var D: Dictionary = b.D
	var W: float = b.w
	var H: float = b.h
	var GY: float = b.gy
	var S: float = H / 170.0
	match b.id:
		"visibility":
			b.px = pos.x
			b.py = pos.y
			b.hold = D.hold
		"fogofwar":
			b.tx = clampf(pos.x, 8.0, W - 8.0)
			b.ty = clampf(pos.y, H * 0.15, H - 6.0)
			b.idle = 0.0
		"torch":
			b.goal = atan2(pos.y - b.oy, pos.x - b.ox)
			b.hold = 3.0
		"umbra":
			b.bx = pos.x
			b.by = minf(pos.y, GY - 4.0 * S)
		"night":
			b.tod = clampf(pos.x / W, 0.0, 1.0) * 0.5
			b.hold = D.hold
		"zap":
			b.armed_sound = true                         # sound only after a press
			_strike(b, pos.x)
			b.nextAt = D.every * randf_range(0.8, 1.3)
		"stealth":
			b.tx = clampf(pos.x, 8.0, W - 8.0)
			b.hold = D.hold
		"volumetric":
			b.held = (clampf(pos.x / W, 0.0, 1.0) - 0.5) * 1.2
			b.hold = D.hold
		"dusk":
			b.clock = (0.25 if D.reverse else 0.3) * D.day
		"blobshadow":
			_blob_jump(b)
		"bloom":
			var bulbs: Array = b.bulbs
			if bulbs.size() >= int(D.max):
				bulbs.pop_front()
			bulbs.append({ "ax": pos.x, "L": maxf(H * 0.08, minf(pos.y, GY - 6.0 * S)), "th": 0.0, "w": (1.0 if pos.x < W / 2.0 else -1.0) * float(D.swing) })   # let go with a push toward the middle of the stage
		"interior":
			b.target = _room_of(b, clampf(pos.x, b.x0, b.x1), 1 if pos.y < b.mid else 0)
			b.tour = b.target
			b.phase = "walk"
			b.wait = 0.0
		"zonelight":
			b.tx = clampf(pos.x, 8.0, W - 8.0)
			b.hold = D.hold

# ================================================================ tick

static func tick(b: Dictionary, dt: float, t: float) -> void:
	var D: Dictionary = b.D
	var W: float = b.w
	var H: float = b.h
	var GY: float = b.gy
	var S: float = H / 170.0
	match b.id:
		"visibility":
			b.hold = maxf(0.0, b.hold - dt)
			var gx: float = b.px if b.hold > 0.0 else W * (0.5 + 0.34 * sin(t * D.speed))
			var gy: float = b.py if b.hold > 0.0 else H * (0.45 + 0.22 * sin(t * D.speed * 0.73 + 1.3))
			var k := Kit.smooth(6.0, dt)
			b.lx += (gx - b.lx) * k
			b.ly += (gy - b.ly) * k
			var vx: float = b.lx - b.lastx
			var vy: float = b.ly - b.lasty
			b.lastx = b.lx
			b.lasty = b.ly
			if Vector2(vx, vy).length() > 0.05 * S:      # the wedge faces the way the light moves
				var d: float = atan2(vy, vx) - b.head
				b.head += _wrap(d) * Kit.smooth(4.0, dt)
		"fogofwar":
			var dx: float = b.tx - b.hx
			var dy: float = b.ty - b.hy
			var d := Vector2(dx, dy).length()
			if d > 1.5:
				var sp: float = minf(d, W * D.speed * dt)
				b.hx += dx / d * sp
				b.hy += dy / d * sp
				if absf(dx) > 1.0:
					b.face = -1 if dx < 0.0 else 1
				b.clock += dt
			else:
				b.idle += dt
				if b.idle > 0.7:
					b.idle = 0.0
					var R: RandomNumberGenerator = b.R
					b.tx = W * (0.06 + R.randf() * 0.88)
					b.ty = H * (0.18 + R.randf() * 0.76)
			var r: float = W * D.sight
			var ex: float = b.hx                         # the eye
			var ey: float = b.hy - 5.0 * b.hs
			var cols: int = D.cols
			var rows: int = b.rows
			var tw: float = b.tw
			var last: Array = b.last
			for j in rows:
				for i in cols:
					if Vector2((i + 0.5) * tw - ex, (j + 0.5) * tw - ey).length() < r:
						last[j * cols + i] = t
		"torch":
			b.hold = maxf(0.0, b.hold - dt)
			if b.hold <= 0.0:
				b.goal = -0.12 + sin(t * 0.5) * 0.4 + sin(t * 0.21 + 2.0) * 0.25   # the idle sweep
			var da: float = b.goal - b.aim
			b.aim += _wrap(da) * Kit.smooth(5.0, dt)
			if b.swap > 0.0:
				b.swap -= dt
				if b.swap <= 0.0:
					b.bat = 1.0
			else:
				b.bat -= dt / maxf(1.0, D.battery)
				if b.bat <= 0.0:
					b.bat = 0.0
					b.swap = 1.0
		"umbra":
			var f: float = D.flicker
			var gx: float = b.bx + cos(t * 0.5) * W * 0.05 * D.drift + Kit.noise(t * 9.0 + 7.0) * 2.5 * S * f
			var gy: float = b.by + sin(t * 0.37) * H * 0.04 * D.drift + Kit.noise(t * 9.0 + 20.0) * 2.5 * S * f
			b.lx += (gx - b.lx) * Kit.smooth(8.0, dt)
			b.ly += (gy - b.ly) * Kit.smooth(8.0, dt)
		"night":
			b.hold = maxf(0.0, b.hold - dt)
			if b.hold <= 0.0:
				b.tod = fmod(b.tod + dt / maxf(1.0, D.day), 1.0)
		"zap":
			b.nextAt -= dt
			if b.nextAt <= 0.0:
				_strike(b, randf_range(W * 0.1, W * 0.9))
				b.nextAt = D.every * randf_range(0.7, 1.3)
			b.fa *= exp(-D.decay * dt)                   # ← the decay
			b.ba = maxf(0.0, b.ba - dt * 5.0)
			var pending: Array = b.pending
			var i := pending.size() - 1
			while i >= 0:                                # thunder in flight
				var p: Dictionary = pending[i]
				p.at -= dt
				if p.at <= 0.0:
					pending.remove_at(i)
					b.rumble = D.rumble
					if b.armed_sound:
						Kit.noise_burst({ "dur": D.rumble, "vol": 0.22, "lowpass": 260.0, "sweep_to": 70.0 })
				i -= 1
			b.rumble = maxf(0.0, b.rumble - dt)
		"stealth":
			b.hold = maxf(0.0, b.hold - dt)
			if b.hold <= 0.0:
				b.tx = W * (0.5 + 0.42 * sin(t * 0.22))
			var dx: float = b.tx - b.hx
			if absf(dx) > 1.0:
				var sp: float = minf(absf(dx), W * 0.16 * dt)
				b.hx += signf(dx) * sp
				b.face = -1 if dx < 0.0 else 1
				b.clock += dt
			var hs: float = b.hs
			var chestX: float = b.hx
			var chestY: float = GY - 9.0 * hs
			var half: float = b.half
			var range_: float = b.range
			var meters: Array = b.meters
			var worst := 0.0
			var alert: float = b.alert
			for g in mini(2, D.guards):
				var ex: float = b.gx[g]
				var ey: float = GY - 14.0 * hs
				var base: float = 0.0 if b.gface[g] > 0 else PI
				var h: float = atan2(chestY - ey, chestX - ex) if alert > 0.0 else base + sin(t * D.sweep + b.gph[g]) * 0.75
				var dxh := chestX - ex
				var dyh := chestY - ey
				var d := maxf(1e-6, Vector2(dxh, dyh).length())
				var dotp := (dxh * cos(h) + dyh * sin(h)) / d   # ← the Ghost test
				var seen := alert <= 0.0 and d < range_ and dotp > cos(half) and not _blocked(b, ex, ey, chestX, chestY)
				if seen:
					meters[g] = minf(1.0, meters[g] + dt * D.fill * (2.0 - d / range_))
				elif alert <= 0.0:
					meters[g] = maxf(0.0, meters[g] - dt * D.drain)
				worst = maxf(worst, meters[g])
				b.gh[g] = h
				b.gseen[g] = seen
			if worst >= 1.0 and alert <= 0.0:
				b.alert = 2.5
				b.caught += 1
			if b.alert > 0.0:
				b.alert -= dt
				if b.alert <= 0.0:
					meters[0] = 0.0
					meters[1] = 0.0
		"volumetric":
			b.hold = maxf(0.0, b.hold - dt)
			var goal: float = b.held if b.hold > 0.0 else D.tilt * sin(t * D.drift)
			b.ang += (goal - b.ang) * minf(1.0, dt * 3.0)
			for m in b.motes:
				m.s += m.sp * dt
				if m.s > 1.0:
					m.s -= 1.0
		"dusk":
			var cycle: float = D.day + D.hold
			b.clock += dt
			if b.clock > cycle:
				b.clock -= cycle
			for c in b.cars:
				c.x += c.v * c.dir * dt
				if c.x > W + 30.0 * S:
					c.x = -30.0 * S
				elif c.x < -30.0 * S:
					c.x = W + 30.0 * S
		"blobshadow":
			b.x += W * D.speed * dt
			b.clock += dt
			if b.x > W + 20.0:
				b.x = -20.0
				b.autoOK = true
			var gy := _hill_y(b, b.x)
			if b.air:
				b.y += b.vy * dt
				b.vy += b.G * dt
				if b.y >= gy and b.vy > 0.0:
					b.y = gy
					b.air = false
			else:
				b.y = gy
				if b.autoOK and b.x > W * 0.33:
					b.autoOK = false
					_blob_jump(b)
		"bloom":                                      # the laser's sweep is a function of t; the bulbs swing on their wires
			var gH: float = H * float(D.g)
			var damp: float = D.damp
			var sub := maxi(1, ceili(dt * 50.0))
			var h := dt / float(sub)
			for bl in b.bulbs:                           # every bulb's pendulum: θ'' = −(g/L)·sin θ − damp·θ', symplectic euler in ≤ 20 ms steps
				var bq: Dictionary = bl
				var gL: float = gH / float(bq.L)
				var th: float = bq.th
				var w: float = bq.w
				for _s in sub:
					w += (-gL * sin(th) - damp * w) * h
					th += w * h
				if absf(th) > 2.5:
					th = clampf(th, -2.5, 2.5)
					w = 0.0
				bq.th = th
				bq.w = w
		"interior":
			var tfloor: int = 1 if b.target >= 2 else 0
			var rooms: Array = b.rooms
			if b.phase == "walk":
				var tr: Rect2 = rooms[b.target]
				var wx: float = b.ladder[0 if tfloor == 1 else 1] if tfloor != b.fl else tr.position.x + tr.size.x / 2.0
				var dx: float = wx - b.hx
				if absf(dx) > 1.5:
					var sp: float = minf(absf(dx), W * D.speed * dt)
					b.hx += signf(dx) * sp
					b.face = -1 if dx < 0.0 else 1
					b.clock += dt
				elif tfloor != b.fl:
					b.phase = "climb"
				else:
					b.phase = "idle"
					b.wait = 1.6
			elif b.phase == "climb":
				var ty: float = b.mid if tfloor == 1 else GY
				b.hy += (ty - b.hy) * Kit.smooth(4.0, dt)
				if absf(ty - b.hy) < 1.0:
					b.hy = ty
					b.fl = tfloor
					b.phase = "walk"
			else:
				b.wait -= dt
				if b.wait <= 0.0:
					b.tour = (b.tour + 1) % 4
					b.target = b.tour
					b.phase = "walk"
			var here := _room_of(b, b.hx, 1 if b.hy < (b.mid + GY) / 2.0 else 0)
			var lit: Array = b.lit
			var away: Array = b.away
			for i in 4:                                  # ← the whole lighting model
				if i == here:
					lit[i] = minf(1.0, lit[i] + dt / maxf(0.05, D.wake))
					away[i] = 0.0
				else:
					away[i] += dt
					if D.linger > 0 and away[i] > D.linger:
						lit[i] = maxf(0.0, lit[i] - dt / maxf(0.05, D.fade))
		"zonelight":
			var hs: float = b.hs
			b.hold = maxf(0.0, b.hold - dt)
			if b.hold <= 0.0:
				b.tx = W * (0.5 + 0.44 * sin(t * 0.2))
			var dx: float = b.tx - b.hx
			if absf(dx) > 1.0:
				var sp: float = minf(absf(dx), W * D.speed * dt)
				b.hx += signf(dx) * sp
				b.face = -1 if dx < 0.0 else 1
				b.clock += dt
			var zi := _zone_at(b, b.hx)
			if zi != b.zone:
				b.zone = zi
				if zi >= 0 and (D.zones[zi] as Dictionary).kind == "danger":
					b.flash = D.entryFlash
			b.flash = maxf(0.0, b.flash - dt)
			b.ex += b.edir * W * 0.12 * dt               # the enemy's patrol
			if b.ex > b.eb1:
				b.ex = b.eb1
				b.edir = -1
			elif b.ex < b.eb0:
				b.ex = b.eb0
				b.edir = 1
			b.hitT = maxf(0.0, b.hitT - dt)
			var dz: int = b.dz
			if zi == dz and dz >= 0 and absf(b.hx - b.ex) < 6.0 * hs and b.hitT <= 0.0:
				b.hits += 1
				b.hitT = 0.8
				b.tx = clampf(b.hx - b.face * W * 0.25, 8.0, W - 8.0)
				b.hold = 1.5

# ================================================================ draw

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	var D: Dictionary = b.D
	var W: float = b.w
	var H: float = b.h
	var GY: float = b.gy
	var S: float = H / 170.0
	var origin: Vector2 = (b.rect as Rect2).position
	match b.id:
		"visibility":
			Kit.stage(n, b, 0.85)
			var L := Vector2(b.lx, b.ly)
			var segs: Array = b.segs
			var half: float = b.half
			var head: float = b.head
			var coned: bool = b.coned
			var packed := Kit.vis_poly(b, L, segs)       # ← the whole trick, once per frame
			var pts := _pts_of(packed)
			for bl in b.blocks:
				Kit.wall(n, Rect2(bl[0] * W, bl[1] * H, bl[2] * W, bl[3] * H))
			# the darkness layer, with the polygon cut out of it: a fan mesh through
			# the polygon's vertices (see _poly_dark) — or, coned, through the wedge's
			# slice of them, with the rest of the circle darkened as a plain sector.
			var dark_col := Color(8.0 / 255.0, 6.0 / 255.0, 20.0 / 255.0)
			if coned:
				var wedge := _wedge_pts(b, L, pts, segs, head, half)
				_poly_dark(n, b, L, wedge, W * D.reach, 0.7, 1.0, dark_col, 0.9, false)
				_sector_dark(n, b, L, head + half, head - half + TAU, dark_col, 0.9)
			else:
				_poly_dark(n, b, L, pts, W * D.reach, 0.7, 1.0, dark_col, 0.9, true)
			if D.rays:                                   # the rays
				var ray_col := _al(Kit.SUN, 0.14)
				for p in pts:
					var q: Vector2 = p
					if coned:
						var d := _wrap(atan2(q.y - L.y, q.x - L.x) - head)
						if absf(d) > half:
							continue
					n.draw_line(L, q, ray_col, 1.0)
				var hit := 0
				for c in b.corners:                      # a corner counts as hit when a ray ends on it
					var cq: Vector2 = c
					var on := false
					for p in pts:
						if (p as Vector2).distance_to(cq) < 1.5:
							on = true
							break
					if on:
						hit += 1
						Kit.dot(n, cq, 2.0 * S, Kit.SPARK)
				Kit.label(n, b, "%d rays · %d corners hit" % [pts.size(), hit], Vector2(W / 2.0, 12.0 * S), Kit.DIM, true)
			_outline(n, pts, _al(Kit.SUN, 0.35))         # the polygon's edge: where the shadows start
			if coned:                                    # a guard: the eyes are the light
				var hs: float = b.hs
				Kit.hero(n, b, Vector2(L.x, L.y + 14.0 * hs), { "s": hs, "face": -1 if cos(head) < 0.0 else 1 })
			else:
				Kit.dot(n, L, 3.0 * S, Kit.INK)
				Kit.ring(n, L, 6.0 * S, _al(Kit.SUN, 0.6), 1.5)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"fogofwar":
			var hs: float = b.hs
			var cols: int = D.cols
			var rows: int = b.rows
			var tw: float = b.tw
			var r: float = W * D.sight
			var ex: float = b.hx
			var ey: float = b.hy - 5.0 * hs
			var moving: bool = Vector2(b.tx - b.hx, b.ty - b.hy).length() > 1.5
			Kit.stage(n, b, 0.0, true)
			Kit.rect(n, Rect2(0, 0, W, H), Color(52.0 / 255.0, 92.0 / 255.0, 54.0 / 255.0, 0.85))   # the map: grass ...
			Kit.rect(n, Rect2(0, H * 0.62, W, H * 0.08), Color(58.0 / 255.0, 120.0 / 255.0, 190.0 / 255.0, 0.9))   # ... a river ...
			Kit.rect(n, Rect2(W * 0.42, H * 0.6, W * 0.05, H * 0.12), Color("7A5A3A"))   # ... and a bridge
			for o in b.props:
				if o.k == 0:
					Kit.tree(n, Vector2(o.x, o.y), H * 0.14)
				elif o.k == 1:
					Kit.crate(n, Vector2(o.x, o.y), H * 0.06)
				else:
					Kit.rect(n, Rect2(o.x - 6.0 * S, o.y - 4.0 * S, 12.0 * S, 8.0 * S), Color("6E6890"))
			Kit.hero(n, b, Vector2(b.hx, b.hy), { "face": b.face, "pose": "run" if moving else "stand", "frame": b.clock, "s": hs })
			# the fog layer: one quad per tile at its darkness, each corner's alpha
			# multiplied by (1 − the soft hole round the eye) — cutLight's
			# destination-out, evaluated at the tile corners. one triangle array.
			var last: Array = b.last
			var memory: float = D.memory
			var dim: float = D.dim
			var fog := Color(10.0 / 255.0, 8.0 / 255.0, 22.0 / 255.0)
			var hole_r := r * 1.05
			var pts := PackedVector2Array()
			var cs := PackedColorArray()
			var idx := PackedInt32Array()
			var seen := 0
			for j in rows:
				for i in cols:
					var l: float = last[j * cols + i]
					var a := 0.97
					if l >= 0.0:
						a = dim
						if memory > 0.0:
							a = lerpf(dim, 0.97, clampf((t - l) / memory, 0.0, 1.0))
						if a < 0.96:
							seen += 1
					var base := pts.size()
					var x0 := i * tw
					var y0 := j * tw
					for corner in [Vector2(x0, y0), Vector2(x0 + tw + 0.5, y0), Vector2(x0 + tw + 0.5, y0 + tw + 0.5), Vector2(x0, y0 + tw + 0.5)]:
						var cq: Vector2 = corner
						pts.append(cq)
						cs.append(Color(fog.r, fog.g, fog.b, a * (1.0 - _cut(cq.distance_to(Vector2(ex, ey)) / hole_r, 0.45, 1.0))))
					idx.append_array([base, base + 1, base + 2, base, base + 2, base + 3])
			RenderingServer.canvas_item_add_triangle_array(n.get_canvas_item(), idx, pts, cs)
			Kit.ring(n, Vector2(ex, ey), r, _al(Kit.INK, 0.2))
			var sw := 7.0 * S                            # the legend
			var ly0 := 6.0 * S
			Kit.rect(n, Rect2(6.0 * S, ly0, sw, sw), Color(fog.r, fog.g, fog.b, 0.97))
			Kit.label(n, b, "unseen", Vector2(6.0 * S + sw + 3.0, ly0 + sw - 1.0), Kit.DIM)
			Kit.rect(n, Rect2(6.0 * S, ly0 + sw + 3.0, sw, sw), Color(fog.r, fog.g, fog.b, dim))
			Kit.label(n, b, "seen", Vector2(6.0 * S + sw + 3.0, ly0 + 2.0 * sw + 2.0), Kit.DIM)
			Kit.rect(n, Rect2(6.0 * S, ly0 + 2.0 * sw + 6.0, sw, sw), Color(0.91, 0.898, 0.957, 0.15))
			Kit.label(n, b, "visible", Vector2(6.0 * S + sw + 3.0, ly0 + 3.0 * sw + 5.0), Kit.DIM)
			_label_r(n, b, "explored %d%%" % roundi(seen / float(b.nn) * 100.0), Vector2(W - 6.0, 12.0), Kit.DIM)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"torch":
			Kit.stage(n, b, 0.92)
			var bat: float = b.bat
			var swap: float = b.swap
			var ox: float = b.ox
			var oy: float = b.oy
			var dying: float = (0.55 + 0.45 * (Kit.noise(t * 17.0) * 0.5 + 0.5)) if (bat < 0.25 and bat > 0.0) else 1.0
			var bright: float = 0.0 if bat <= 0.0 else (0.3 + 0.7 * bat) * dying
			var jit: float = (Kit.noise(t * 7.3) * 0.02 + Kit.noise(t * 1.7 + 40.0) * 0.05) * D.jitter
			var th: float = b.aim + jit
			var half: float = D.half * PI / 180.0
			var R: float = W * D.reach
			Kit.tree(n, Vector2(W * 0.55, GY), H * 0.3)
			Kit.tree(n, Vector2(W * 0.88, GY), H * 0.24)
			Kit.crate(n, Vector2(W * 0.72, GY), H * 0.1)
			Kit.hero(n, b, Vector2(b.hx, GY), { "face": -1 if cos(th) < 0.0 else 1 })
			# the darkness layer as a POLAR MESH about the hand: angle samples just
			# inside and outside each nested wedge's edge (so the feather's steps stay
			# crisp), radii at the falloff's stops; each vertex's alpha is the layer's
			# alpha after the four erasures compound — (1 − 0.45·bright·g(d))^k for k
			# wedges containing the angle — times the spill hole round the hand.
			var soft: float = D.soft
			var dark: float = D.dark
			var offs: Array = [0.0]
			for i in 4:
				var hi: float = half * (1.0 - soft * i / 4.0)
				offs.append_array([-hi - 1e-4, -hi + 1e-4, hi - 1e-4, hi + 1e-4])
			var h0 := half
			for m in 13:                                 # the unlit back of the circle, coarsely
				offs.append(_wrap(h0 + (TAU - 2.0 * h0) * (m + 0.5) / 13.0))
			offs.sort()
			var radii := PackedFloat32Array([0.0, 7.0 * S, 14.0 * S, 0.4 * R, 0.7 * R, R, W + H])
			radii.sort()
			var dirs: Array = []
			var rad: Array = []
			var alp: Array = []
			for off in offs:
				var phi: float = off
				dirs.append(Vector2(cos(th + phi), sin(th + phi)))
				rad.append(radii)
				var aa := PackedFloat32Array()
				for rho in radii:
					var g := 0.0                         # the beam's radial gradient: 1 → 0.75 at 0.4 R → 0
					if rho <= 0.4 * R:
						g = 1.0 - 0.25 * rho / (0.4 * R)
					elif rho <= R:
						g = 0.75 * (1.0 - (rho - 0.4 * R) / (0.6 * R))
					var k := 0                           # nested wedges: the edge is erased once, the core four times
					for i in 4:
						if absf(phi) < half * (1.0 - soft * i / 4.0):
							k += 1
					var remain := pow(1.0 - 0.45 * bright * g, k) if bright > 0.0 else 1.0
					remain *= 1.0 - _cut(rho / (14.0 * S), 0.5, 0.7 * bright)   # spill around the hand
					aa.append(dark * remain)
				alp.append(aa)
			_fan_mesh(n, Vector2(ox, oy), dirs, rad, alp, Color(6.0 / 255.0, 5.0 / 255.0, 16.0 / 255.0), true)
			var edge := _al(Kit.SUN, 0.18)               # the wedge's edges, thin
			Kit.line(n, Vector2(ox, oy), Vector2(ox + cos(th - half) * R, oy + sin(th - half) * R), edge)
			Kit.line(n, Vector2(ox, oy), Vector2(ox + cos(th + half) * R, oy + sin(th + half) * R), edge)
			n.draw_set_transform(origin + Vector2(ox, oy), th, Vector2.ONE)
			Kit.rect(n, Rect2(-4.0 * S, -2.0 * S, 9.0 * S, 4.0 * S), POST)
			if bright > 0.0:
				Kit.dot(n, Vector2(5.0 * S, 0.0), 2.2 * S, _al(Kit.SPARK, bright))
			n.draw_set_transform(origin, 0.0, Vector2.ONE)
			var bw := 34.0 * S                           # the battery
			var bx := W - bw - 8.0 * S
			var by := 8.0 * S
			n.draw_rect(Rect2(bx, by, bw, 8.0 * S), _al(Kit.INK, 0.5), false, 1.0)
			Kit.rect(n, Rect2(bx + bw, by + 2.0 * S, 2.0 * S, 4.0 * S), _al(Kit.INK, 0.5))
			Kit.rect(n, Rect2(bx + 1.0, by + 1.0, (bw - 2.0) * bat, 8.0 * S - 2.0), Kit.HOT if bat < 0.25 else Kit.GOOD)
			_label_r(n, b, "swapping cells…" if swap > 0.0 else "battery %d%%" % roundi(bat * 100.0), Vector2(bx - 4.0, by + 8.0 * S - 1.0), Kit.DIM)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"umbra":
			Kit.stage(n, b, 0.95)
			var f: float = D.flicker
			var flick: float = 1.0 - 0.18 * f * (0.5 - 0.5 * Kit.noise(t * 11.0 + 3.0))   # the flame's breath
			var L := Vector2(b.lx, b.ly)
			var colour := Color(D.colour)
			var pts := _pts_of(Kit.vis_poly(b, L, b.segs))
			for pl in b.pillars:
				Kit.wall(n, Rect2(pl[0] * W, pl[1] * H, pl[2] * W, GY - pl[1] * H))
			Kit.hero(n, b, Vector2(W * 0.14, GY), { "face": 1 })
			var R: float = W * D.reach * flick
			# the light's colour, only where it reaches: the glow as a fan clipped to
			# the polygon; then darkness minus (polygon ∩ falloff), the same fan with
			# cutLight's stops (see _poly_dark). two triangle arrays, no layers.
			_poly_glow(n, L, pts, R * 0.9, 0.3, colour)
			_poly_dark(n, b, L, pts, R, D.soft, 1.0, Color(6.0 / 255.0, 5.0 / 255.0, 16.0 / 255.0), 0.93, true)
			_outline(n, pts, _al(colour, 0.25))          # the shadow edges
			Kit.line(n, Vector2(L.x, L.y + 2.0 * S), Vector2(L.x, L.y + 12.0 * S), WOOD, 2.0 * S)   # the torch
			Kit.glow(n, L, 7.0 * S * flick, colour, 0.9)   # "lighter" on the web — plain glows here
			Kit.glow(n, Vector2(L.x, L.y - 2.0 * S), 3.0 * S, Color("FFF6D8"), 0.9)
			Kit.label(n, b, "flame %.2f" % flick, Vector2(L.x, L.y - 12.0 * S), Kit.DIM, true)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"night":
			var tod: float = b.tod
			var nn: float = 0.5 - 0.5 * cos(tod * TAU)
			Kit.stage(n, b, nn * 0.8)
			var a: float = tod * TAU                     # the sun and the moon on one wheel
			var sx := W * 0.5 - sin(a) * W * 0.4
			var sy := H * 0.55 - cos(a) * H * 0.45
			Kit.glow(n, Vector2(sx, sy), 16.0 * S, Kit.SUN, 0.8)
			Kit.dot(n, Vector2(sx, sy), 6.0 * S, Color("FFF4D0"))
			Kit.dot(n, Vector2(W * 0.5 + sin(a) * W * 0.4, H * 0.55 + cos(a) * H * 0.45), 5.0 * S, Color("E0E4F5"))
			Kit.tree(n, Vector2(W * 0.4, GY), H * 0.28)
			var hh: float = b.hh
			var lit: Array = []                          # this frame's light sources: [pos, r, colour, is_lamp]
			var houses: Array = b.houses
			for i in houses.size():
				var on: bool = nn > 0.5 + i * 0.06
				var hx: float = houses[i][0]
				var hw: float = houses[i][1]
				Kit.house(n, Vector2(hx, GY), hw, hh, on)
				if on:
					lit.append([Vector2(hx + hw * 0.31, GY - hh * 0.56), W * 0.07, Kit.SUN, false])
					lit.append([Vector2(hx + hw * 0.69, GY - hh * 0.56), W * 0.07, Kit.SUN, false])
			var lamps: Array = D.lamps
			var lampsX: Array = b.lampsX
			for i in lampsX.size():
				var on: bool = nn > 0.38 + i * 0.05
				Kit.lamp(n, b, Vector2(lampsX[i], GY), on)
				if on:
					lit.append([Vector2(lampsX[i], b.lampY), W * 0.16, Color(lamps[i % lamps.size()]), true])
			Kit.hero(n, b, Vector2(W * 0.62, GY), { "face": -1 })
			# the tint, then the holes — as ONE triangle grid over the card whose
			# vertex alpha is the layer's: n·depth × Π(1 − cutLight_k). MULTIPLY has
			# no per-draw equivalent here: the tint is blended normally, which also
			# darkens toward it (a touch flatter in the shadows than a true multiply).
			var base: float = nn * D.depth
			if base > 0.002:
				var tint := Color(D.tint)
				var nx := 24
				var ny := 16
				var gpts := PackedVector2Array()
				var gcols := PackedColorArray()
				var gidx := PackedInt32Array()
				for j in ny + 1:
					for i in nx + 1:
						var p := Vector2(W * i / float(nx), H * j / float(ny))
						var al := base
						for src in lit:
							al *= 1.0 - _cut(p.distance_to(src[0]) / float(src[1]), 0.6, 0.9)
						gpts.append(p)
						gcols.append(Color(tint.r, tint.g, tint.b, al))
				for j in ny:
					for i in nx:
						var v0 := j * (nx + 1) + i
						var v1 := v0 + nx + 1
						gidx.append_array([v0, v0 + 1, v1 + 1, v0, v1 + 1, v1])
				RenderingServer.canvas_item_add_triangle_array(n.get_canvas_item(), gidx, gpts, gcols)
			for src in lit:                              # the additive half ("lighter" on the web — plain glows)
				var p: Vector2 = src[0]
				var rr: float = src[1]
				var col: Color = src[2]
				Kit.glow(n, p, rr * 1.1, col, 0.35 * nn)
				if src[3]:
					Kit.dot(n, p, 4.0 * S, col)
			var bx := 10.0 * S                           # the slider
			var bw := W - 20.0 * S
			var by := H - 20.0 * S
			Kit.line(n, Vector2(bx, by), Vector2(bx + bw, by), _al(Kit.INK, 0.35))
			var k: float = tod * 2.0 if tod <= 0.5 else (1.0 - tod) * 2.0
			Kit.dot(n, Vector2(bx + bw * k, by), 3.0 * S, Kit.INK)
			Kit.label(n, b, "noon", Vector2(bx, by - 4.0), Kit.DIM)
			_label_r(n, b, "midnight", Vector2(bx + bw, by - 4.0), Kit.DIM)
			Kit.label(n, b, "n = %.2f · %d holes" % [nn, lit.size()], Vector2(W / 2.0, by - 4.0), Kit.DIM, true)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"zap":
			var fa: float = b.fa
			var ba: float = b.ba
			var rumble: float = b.rumble
			var hx: float = b.hx
			var pending: Array = b.pending
			var distant: bool = D.distant
			Kit.stage(n, b, 0.85)
			Kit.house(n, Vector2(W * 0.62, GY), W * 0.16, H * 0.22, false)
			Kit.tree(n, Vector2(W * 0.85, GY), H * 0.3)
			Kit.hero(n, b, Vector2(hx + (Kit.noise(t * 30.0) * 1.5 * S if rumble > 0.0 else 0.0), GY), { "face": 1, "pose": "hurt" if fa > 0.3 else "stand" })
			var bolt: Dictionary = b.bolt
			if not bolt.is_empty() and ba > 0.02:
				var a: float = 0.5 if distant else 1.0
				var main := PackedVector2Array(bolt.main)
				n.draw_polyline(main, _al(Kit.SPARK, ba * a * 0.3), 6.0 * S)
				n.draw_polyline(main, Color(1.0, 1.0, 1.0, ba * a), 1.6 * S)
				for br in bolt.branches:
					n.draw_polyline(PackedVector2Array(br), _al(Kit.SPARK, ba * a * 0.8), 1.0 * S)
			if fa > 0.003:                               # the flash
				Kit.rect(n, Rect2(0, 0, W, H), Color(1.0, 1.0, 1.0, fa * D.peak))
			var bw := W * 0.34                           # the thunder bar
			var bx := 8.0 * S
			var by := H - 22.0 * S
			n.draw_rect(Rect2(bx, by, bw, 6.0 * S), _al(Kit.INK, 0.4), false, 1.0)
			for p in pending:
				Kit.rect(n, Rect2(bx + 1.0, by + 1.0, (bw - 2.0) * (1.0 - p.at / p.total), 6.0 * S - 2.0), _al(Kit.INK, 0.35))
			if rumble > 0.0:
				for k in 12:
					Kit.rect(n, Rect2(bx + 1.0 + k * (bw - 2.0) / 12.0, by + 3.0 * S - Kit.noise(t * 40.0 + k * 3.0) * 4.0 * S * rumble / D.rumble, (bw - 2.0) / 12.0 - 1.0, 1.5 * S), Kit.HOT)
			Kit.label(n, b, "thunder!" if rumble > 0.0 else ("sound travelling…" if pending.size() > 0 else "quiet"), Vector2(bx + bw + 4.0, by + 6.0 * S - 1.0), Kit.DIM)
			var gw := 40.0 * S                           # the decay curve, with the flash's value on it
			var gx := W - gw - 8.0 * S
			var gy := 8.0 * S
			var gh := 16.0 * S
			var curve := PackedVector2Array()
			for i in 21:
				curve.append(Vector2(gx + gw * i / 20.0, gy + gh * (1.0 - exp(-D.decay * i / 20.0 * 0.6))))
			n.draw_polyline(curve, _al(Kit.INK, 0.3), 1.0)
			Kit.line(n, Vector2(gx, gy + gh * (1.0 - fa)), Vector2(gx + gw, gy + gh * (1.0 - fa)), _al(Kit.SPARK, 0.7))
			_label_r(n, b, "a = %.2f" % fa, Vector2(gx + gw, gy + gh + 10.0), Kit.DIM)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"stealth":
			Kit.stage(n, b, 0.55)
			var hs: float = b.hs
			var half: float = b.half
			var range_: float = b.range
			var meters: Array = b.meters
			var alert: float = b.alert
			var moving: bool = absf(b.tx - b.hx) > 1.0
			Kit.crate(n, Vector2(b.cx, GY), b.cw)
			var worst := 0.0
			for g in mini(2, D.guards):
				var ex: float = b.gx[g]
				var ey: float = GY - 14.0 * hs
				var h: float = b.gh[g]
				var seen: bool = b.gseen[g]
				var m: float = meters[g]
				worst = maxf(worst, m)
				var col: Color = Kit.HOT if alert > 0.0 else (Kit.SUN if seen else Kit.INK)
				var cone := PackedVector2Array([Vector2(ex, ey)])
				for i in 25:
					var an := h - half + 2.0 * half * i / 24.0
					cone.append(Vector2(ex + cos(an) * range_, ey + sin(an) * range_))
				n.draw_colored_polygon(cone, _al(col, 0.22 if alert > 0.0 else 0.06 + 0.16 * m))
				Kit.line(n, Vector2(ex, ey), Vector2(ex + cos(h - half) * range_, ey + sin(h - half) * range_), _al(col, 0.35))
				Kit.line(n, Vector2(ex, ey), Vector2(ex + cos(h + half) * range_, ey + sin(h + half) * range_), _al(col, 0.35))
				var gopts := { "face": -1 if cos(h) < 0.0 else 1, "shirt": Color("4A4470") }
				if alert > 0.0:
					gopts.tint = _al(Kit.HOT, 0.4)
				Kit.hero(n, b, Vector2(ex, GY), gopts)
				if alert > 0.0:
					Kit.text(n, "!", Vector2(ex, GY - 19.0 * hs), int(14.0 * S), Kit.HOT, true)
				elif m > 0.5:
					Kit.text(n, "?", Vector2(ex, GY - 19.0 * hs), int(14.0 * S), Kit.SUN, true)
			Kit.hero(n, b, Vector2(b.hx, GY), { "face": b.face, "pose": "run" if moving else "stand", "frame": b.clock })
			var mw := 26.0 * S                           # the meter above the hero
			var mx: float = b.hx - mw / 2.0
			var my := GY - 20.0 * hs
			n.draw_rect(Rect2(mx, my, mw, 4.0 * S), _al(Kit.INK, 0.5), false, 1.0)
			Kit.rect(n, Rect2(mx + 1.0, my + 1.0, (mw - 2.0) * worst, 4.0 * S - 2.0), Kit.GOOD if worst < 0.5 else (Kit.SUN if worst < 1.0 else Kit.HOT))
			Kit.line(n, Vector2(mx + mw / 2.0, my - 1.0), Vector2(mx + mw / 2.0, my + 4.0 * S + 1.0), _al(Kit.INK, 0.6))
			Kit.label(n, b, "?", Vector2(mx + mw / 2.0, my - 3.0), Kit.DIM, true)
			Kit.label(n, b, "!", Vector2(mx + mw, my - 3.0), Kit.DIM, true)
			_label_r(n, b, "caught ×%d" % int(b.caught), Vector2(W - 6.0, 12.0), Kit.DIM)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"volumetric":
			var ang: float = b.ang
			var tanA := tan(clampf(ang, -1.1, 1.1))
			var sinA := sin(ang)
			var cosA := cos(ang)
			var wy0: float = b.wy0
			var wy1: float = b.wy1
			var ww: float = b.ww
			var Lf: float = b.Lf
			var wins: Array = b.wins
			var haze: float = D.haze
			Kit.stage(n, b, 0.93)
			Kit.rect(n, Rect2(0, 0, W, GY), Color(40.0 / 255.0, 34.0 / 255.0, 62.0 / 255.0, 0.7))   # the back wall
			Kit.crate(n, Vector2(W * 0.28, GY), H * 0.11)
			Kit.hero(n, b, Vector2(W * 0.6, GY), { "face": -1 })
			# "lighter" on the web: the shafts and the dust are plain alpha here (a
			# quad with a colour per vertex is the linear gradient)
			for xl in wins:                              # one quad per window
				var xr: float = xl + ww
				n.draw_polygon(PackedVector2Array([Vector2(xl, wy0), Vector2(xr, wy0), Vector2(xr + Lf * tanA, GY), Vector2(xl + Lf * tanA, GY)]),
					PackedColorArray([_al(Kit.SUN, haze), _al(Kit.SUN, haze), _al(Kit.SUN, 0.0), _al(Kit.SUN, 0.0)]))
				Kit.ellipse(n, Vector2(xl + ww / 2.0 + Lf * tanA, GY), ww * 0.9, 3.0 * S, _al(Kit.SUN, haze * 0.5))   # the pool where it lands
			for m in b.motes:                            # dust: parametric, so it stays inside
				var v: float = clampf(m.v + 0.08 * Kit.noise(t * 0.3 + m.ph), 0.0, 1.0)
				var xl: float = wins[m.w] if m.w < wins.size() else wins[0]
				var ms: float = m.s
				var x: float = xl + v * ww + ms * Lf * tanA
				var y: float = wy0 + ms * Lf
				var tw: float = 0.5 + 0.5 * Kit.noise(t * 2.0 + m.ph)
				Kit.dot(n, Vector2(x, y), (0.8 + tw) * S, Color(1.0, 0.957, 0.816, haze * 1.4 * (1.0 - ms * 0.8) * tw))
			for xl in wins:                              # the windows themselves
				var wx: float = xl
				Kit.rect(n, Rect2(wx, wy0, ww, wy1 - wy0), Color("FFF0C8"))
				Kit.line(n, Vector2(wx + ww / 2.0, wy0), Vector2(wx + ww / 2.0, wy1), INK_DARK, 1.5 * S)
				Kit.line(n, Vector2(wx, (wy0 + wy1) / 2.0), Vector2(wx + ww, (wy0 + wy1) / 2.0), INK_DARK, 1.5 * S)
			var ax := W - 22.0 * S                       # the sun's direction
			var ay := 8.0 * S
			Kit.arrow(n, Vector2(ax, ay), Vector2(ax + sinA * 16.0 * S, ay + cosA * 16.0 * S), Kit.SUN)
			_label_r(n, b, "sun %d°" % roundi(ang * 180.0 / PI), Vector2(ax - 4.0, ay + 10.0), Kit.DIM)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"dusk":
			var cycle: float = D.day + D.hold
			var clock: float = b.clock
			var nn: float = clampf(clock / D.day, 0.0, 1.0)
			var reverse: bool = D.reverse
			if reverse:
				nn = 1.0 - nn
			Kit.stage(n, b, nn)
			for st in b.stars:
				Kit.dot(n, Vector2(st[0], st[1]), 0.8 * S, _al(Kit.INK, clampf((nn - 0.55) / 0.4, 0.0, 1.0) * (0.5 + 0.4 * sin(t * 2.0 + st[2]))))
			var hw: float = b.hw
			var hh: float = b.hh
			var hxs: Array = b.hxs
			var thr: Array = b.thr
			for i in hxs.size():                         # the houses, then their windows by threshold
				var hx: float = hxs[i]
				Kit.house(n, Vector2(hx, GY), hw, hh, false)
				for w in 2:
					var bb := _ease((nn - thr[i][w]) / 0.03)   # 0 → 1 across a sliver of n: on, without a pop
					var wx := hx + hw * (0.58 if w == 1 else 0.2)
					var wy := GY - hh * 0.7
					Kit.rect(n, Rect2(wx, wy, hw * 0.22, hh * 0.28), INK_DARK.lerp(Kit.SUN, bb))
					if bb > 0.0:                         # "lighter" on the web — a plain glow
						Kit.glow(n, Vector2(wx + hw * 0.11, wy + hh * 0.14), hw * 0.45, Kit.SUN, 0.3 * bb)
			var road: float = b.road
			Kit.rect(n, Rect2(0, road - 4.0 * S, W, 8.0 * S), Color(20.0 / 255.0, 18.0 / 255.0, 34.0 / 255.0, 0.85))   # the far road
			var beams := nn > 0.3
			for c in b.cars:
				var cx: float = c.x
				var dir: float = c.dir
				Kit.rect(n, Rect2(cx - 7.0 * S, road - 4.0 * S, 14.0 * S, 4.0 * S), POST)
				Kit.dot(n, Vector2(cx - 4.0 * S, road), 1.2 * S, Color("1A1830"))
				Kit.dot(n, Vector2(cx + 4.0 * S, road), 1.2 * S, Color("1A1830"))
				if beams:
					var fx := cx + dir * 7.0 * S
					var k := clampf((nn - 0.3) / 0.2, 0.0, 1.0)
					n.draw_colored_polygon(PackedVector2Array([Vector2(fx, road - 2.0 * S), Vector2(fx + dir * 26.0 * S, road - 6.0 * S), Vector2(fx + dir * 26.0 * S, road + 3.0 * S)]),
						_al(Kit.SPARK, 0.12 * k))          # the beam: a triangle ahead of the car
					Kit.dot(n, Vector2(fx, road - 2.0 * S), 1.3 * S, _al(Kit.SPARK, k))
					Kit.dot(n, Vector2(cx - dir * 7.0 * S, road - 2.0 * S), 1.0 * S, _al(Kit.HOT, k))
			var bx := 10.0 * S                           # the threshold strip
			var bw := W - 20.0 * S
			var by := H - 20.0 * S
			Kit.line(n, Vector2(bx, by), Vector2(bx + bw, by), _al(Kit.INK, 0.35))
			for i in thr.size():
				for w in 2:
					var tv: float = thr[i][w]
					Kit.line(n, Vector2(bx + bw * tv, by - 3.0 * S), Vector2(bx + bw * tv, by + 3.0 * S), Kit.SUN if nn > tv else Kit.DIM)
			Kit.dot(n, Vector2(bx + bw * nn, by), 3.0 * S, Kit.INK)
			Kit.label(n, b, "n = %.2f" % nn, Vector2(bx + bw * nn, by - 6.0), Kit.DIM, true)
			_label_r(n, b, "night → day" if reverse else "noon → night", Vector2(bx + bw, by - 6.0), Kit.DIM)
			Kit.ring(n, Vector2(W - 16.0 * S, 14.0 * S), 8.0 * S, _al(Kit.INK, 0.4))   # the clock
			Kit.line(n, Vector2(W - 16.0 * S, 14.0 * S), Vector2(W - 16.0 * S + sin(clock / cycle * TAU) * 7.0 * S, 14.0 * S - cos(clock / cycle * TAU) * 7.0 * S), Kit.INK, 1.5)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"blobshadow":
			Kit.stage(n, b, 0.1)
			var x: float = b.x
			var y: float = b.y
			var air: bool = b.air
			var hmax: float = b.hmax
			var gy := _hill_y(b, x)
			var hill := PackedVector2Array([Vector2(0, GY + 1.0)])   # the hill
			var ridge := PackedVector2Array()
			var xx := 0.0
			while xx <= W:
				hill.append(Vector2(xx, _hill_y(b, xx)))
				ridge.append(Vector2(xx, _hill_y(b, xx)))
				xx += 4.0
			hill.append(Vector2(W, GY + 1.0))
			n.draw_colored_polygon(hill, Color("4E7A44"))
			n.draw_polyline(ridge, Color(20.0 / 255.0, 40.0 / 255.0, 20.0 / 255.0, 0.5), 1.5)
			var h := maxf(0.0, gy - y)
			var k := clampf(h / hmax, 0.0, 1.0)
			var slope := _hill_slope(b, x)
			var tilt := atan(slope)
			var nl := sqrt(slope * slope + 1.0)
			var rx: float = 10.0 * S * D.size * (1.0 - D.shrink * k)
			var ry: float = rx * 0.35
			var alpha: float = 0.6 * (1.0 - 0.65 * k)
			var soft: float = D.soft
			# the blob, on the slope: an ellipse rotated by tilt, its radial gradient
			# as a fan with rings at the gradient's stops (per-vertex alpha)
			var bdirs: Array = []
			var brad: Array = []
			var balp: Array = []
			var rr := PackedFloat32Array([0.0, maxf(0.01, 1.0 - soft), 1.0]) if soft > 0.0 else PackedFloat32Array([0.0, 1.0, 1.0])
			var aa := PackedFloat32Array([alpha, alpha * 0.9, 0.0]) if soft > 0.0 else PackedFloat32Array([alpha, alpha, alpha])
			var ct := cos(tilt)
			var stt := sin(tilt)
			for i in 32:
				var an := i / 32.0 * TAU
				var e := Vector2(cos(an) * rx, sin(an) * ry)   # a point on the unit-scaled ellipse, then rotated
				bdirs.append(Vector2(e.x * ct - e.y * stt, e.x * stt + e.y * ct))   # a "direction" carrying the radius: rings scale it
				brad.append(rr)
				balp.append(aa)
			_fan_mesh(n, Vector2(x, gy), bdirs, brad, balp, Color.BLACK, true)
			if air:                                      # the ray, the hit, the normal
				var yy := y
				var dash := 3.0 * S
				var on := true
				while yy < gy:
					var y2 := minf(gy, yy + dash)
					if on:
						Kit.line(n, Vector2(x, yy), Vector2(x, y2), _al(Kit.INK, 0.6))
					on = not on
					yy = y2
				Kit.label(n, b, "h = %d" % roundi(h), Vector2(x + 6.0 * S, y + (gy - y) / 2.0 + 3.0), Kit.DIM)
			Kit.dot(n, Vector2(x, gy), 1.8 * S, Kit.INK)
			Kit.arrow(n, Vector2(x, gy), Vector2(x + slope / nl * 14.0 * S, gy - 1.0 / nl * 14.0 * S), Kit.GOOD)
			Kit.hero(n, b, Vector2(x, y), { "face": 1, "pose": "jump" if air else "run", "frame": b.clock })
			Kit.label(n, b, "tilt %d° · r %.1f" % [roundi(tilt * 180.0 / PI), rx], Vector2(W / 2.0, 12.0 * S), Kit.DIM, true)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"bloom":
			Kit.stage(n, b, 0.75)
			var lx0: float = b.lx0
			var ly0: float = b.ly0
			var hs := Kit.hero_unit(b)
			var all_mask: bool = D.mask == "all"
			var strength: float = minf(1.0, D.strength)
			Kit.tree(n, Vector2(W * 0.55, GY), H * 0.3)
			for px in b.posts:
				Kit.lamp(n, b, Vector2(px, GY), true)
			Kit.hero(n, b, Vector2(W * 0.42, GY), { "face": 1 })
			var ang := 0.9 + sin(t * 0.7) * 0.45         # the laser turret's floor hit
			var hit_x := lx0 + cos(ang) * (GY - ly0) / sin(ang)
			Kit.rect(n, Rect2(lx0 - 5.0 * S, ly0 - 4.0 * S, 10.0 * S, 8.0 * S), POST)
			for bl in b.bulbs:                           # the wire, swung with the bulb
				var bq: Dictionary = bl
				Kit.line(n, Vector2(bq.ax, 0.0), _bulb_at(bq), _al(Kit.INK, 0.35))
			_emitters(n, b, hit_x)                       # crisp, in the scene
			# the bloom pass, approximated (see _halo): glows and wide strokes for the
			# offset-copy blur. mask "all" has no layer to blur either — the hero is
			# redrawn four times, offset and translucent, and a warm veil overexposes
			# the frame, which is what adding a blurred copy of everything looks like.
			_halo(n, b, hit_x)
			if all_mask:
				var r: float = b.r
				for i in 4:
					var an := i * TAU / 4.0 + 0.4
					Kit.hero(n, b, Vector2(W * 0.42 + cos(an) * 1.5 * r, GY + sin(an) * 1.5 * r), { "face": 1, "alpha": 0.18 * strength })
				Kit.rect(n, Rect2(0, 0, W, H), _al(Kit.SPARK, 0.1 * strength))
			var iw := W * 0.24                           # the inset: the mask itself
			var ih := iw * H / W
			var ix := W - iw - 6.0 * S
			var iy := 6.0 * S
			var sc := iw / W
			Kit.rect(n, Rect2(ix, iy, iw, ih), Color(0, 0, 0, 0.6))
			n.draw_set_transform(origin + Vector2(ix, iy), 0.0, Vector2(sc, sc))
			if all_mask:                                 # the whole frame, small
				Kit.stage(n, b, 0.75)
				Kit.tree(n, Vector2(W * 0.55, GY), H * 0.3)
				for px in b.posts:
					Kit.lamp(n, b, Vector2(px, GY), true)
				Kit.rect(n, Rect2(lx0 - 5.0 * S, ly0 - 4.0 * S, 10.0 * S, 8.0 * S), POST)
			_emitters(n, b, hit_x)
			n.draw_set_transform(origin, 0.0, Vector2.ONE)
			if all_mask:                                 # (the hero resets the transform itself, so it is placed by hand)
				Kit.hero(n, b, Vector2(ix, iy) + Vector2(W * 0.42, GY) * sc, { "face": 1, "s": hs * sc })
			n.draw_rect(Rect2(ix, iy, iw, ih), _al(Kit.INK, 0.4), false, 1.0)
			Kit.label(n, b, "mask: %s" % str(D.mask), Vector2(ix + iw / 2.0, iy + ih + 10.0), Kit.DIM, true)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"interior":
			Kit.stage(n, b, 0.6)
			var hs: float = b.hs
			var x0: float = b.x0
			var x1: float = b.x1
			var top: float = b.top
			var mid: float = b.mid
			var xm: float = b.xm
			var rooms: Array = b.rooms
			var lit: Array = b.lit
			var here := _room_of(b, b.hx, 1 if b.hy < (mid + GY) / 2.0 else 0)
			Kit.rect(n, Rect2(x0 - 3.0 * S, top - 3.0 * S, x1 - x0 + 6.0 * S, GY - top + 3.0 * S), Color("4A4470"))   # the house
			n.draw_colored_polygon(PackedVector2Array([Vector2(x0 - 6.0 * S, top - 3.0 * S), Vector2(xm, top - H * 0.1), Vector2(x1 + 6.0 * S, top - 3.0 * S)]), Color("6E3A3A"))
			for i in 4:
				Kit.rect(n, rooms[i], Color("8A82B0") if i % 2 == 1 else Color("7E7AA8"))
			Kit.line(n, Vector2(x0, mid), Vector2(x1, mid), INK_DARK, 2.0 * S)
			Kit.line(n, Vector2(xm, top), Vector2(xm, GY), INK_DARK, 2.0 * S)
			for l in 2:
				var lx: float = b.ladder[l]
				for k in 6:
					var ry := mid + k * (GY - mid) / 6.0
					Kit.line(n, Vector2(lx - 4.0 * S, ry), Vector2(lx + 4.0 * S, ry), _al(Kit.INK, 0.3))
			Kit.crate(n, Vector2(x0 + W * 0.12, GY), H * 0.1)   # furniture, one per room
			Kit.rect(n, Rect2(xm + W * 0.06, GY - 9.0 * S, 22.0 * S, 3.0 * S), WOOD)
			Kit.rect(n, Rect2(xm + W * 0.06, GY - 9.0 * S, 2.0 * S, 9.0 * S), WOOD)
			Kit.rect(n, Rect2(xm + W * 0.06 + 20.0 * S, GY - 9.0 * S, 2.0 * S, 9.0 * S), WOOD)
			Kit.rect(n, Rect2(xm + W * 0.06, mid - 7.0 * S, 26.0 * S, 7.0 * S), Color("6E3A3A"))
			Kit.rect(n, Rect2(xm + W * 0.06, mid - 10.0 * S, 8.0 * S, 3.0 * S), Color("E8E5F4"))
			Kit.tree(n, Vector2(x0 + W * 0.1, mid), H * 0.1)
			for i in 4:                                  # a bulb per room, brightening with lit
				var rm: Rect2 = rooms[i]
				var li: float = lit[i]
				var bp := Vector2(rm.position.x + rm.size.x / 2.0, rm.position.y + 4.0 * S)
				Kit.glow(n, bp, rm.size.x * 0.5, Kit.SUN, 0.35 * li)
				Kit.dot(n, bp, 2.0 * S, Kit.SUN if li > 0.05 else INK_DARK)
			Kit.hero(n, b, Vector2(b.hx, b.hy), { "face": b.face, "pose": "run" if b.phase == "walk" else "stand", "frame": b.clock, "s": maxf(1.0, roundf(hs * 0.7)) })
			for i in 4:                                  # the overlay: hard-edged, one alpha per room
				var rm: Rect2 = rooms[i]
				var li: float = lit[i]
				Kit.rect(n, rm, Color(10.0 / 255.0, 8.0 / 255.0, 22.0 / 255.0, D.dark * (1.0 - _ease(li))))
				Kit.label(n, b, "lit %.2f" % li, rm.position + Vector2(4.0, 11.0), Kit.SUN if i == here else Kit.DIM)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"zonelight":
			Kit.stage(n, b, 0.75)
			var hs: float = b.hs
			var zones: Array = D.zones
			var colours: Dictionary = D.colours
			var zi: int = b.zone
			var flash: float = b.flash
			var hitT: float = b.hitT
			var moving: bool = absf(b.tx - b.hx) > 1.0
			var soft: float = D.soft
			var entry: float = D.entryFlash
			# "lighter" on the web: the columns are plain alpha here (a colour per
			# vertex feathers the soft edges)
			for i in zones.size():                       # the columns of light
				var z: Dictionary = zones[i]
				var kind: String = z.kind
				var col := Color(colours[kind]) if colours.has(kind) else Kit.INK
				var danger := kind == "danger"
				var zx: float = z.x * W
				var zw: float = z.w * W
				var a: float = 0.12 + 0.05 * sin(t * TAU * D.pulse * (1.0 if danger else 0.5))
				if danger and i == zi and entry > 0.0:
					a += 0.35 * flash / entry
				var y0 := H * 0.22
				if soft > 0.0:
					var f0 := zx + zw * soft / 2.0
					var f1 := zx + zw * (1.0 - soft / 2.0)
					n.draw_polygon(PackedVector2Array([Vector2(zx, y0), Vector2(f0, y0), Vector2(f0, H), Vector2(zx, H)]),
						PackedColorArray([_al(col, 0.0), _al(col, a), _al(col, a), _al(col, 0.0)]))
					Kit.rect(n, Rect2(f0, y0, f1 - f0, H - y0), _al(col, a))
					n.draw_polygon(PackedVector2Array([Vector2(f1, y0), Vector2(zx + zw, y0), Vector2(zx + zw, H), Vector2(f1, H)]),
						PackedColorArray([_al(col, a), _al(col, 0.0), _al(col, 0.0), _al(col, a)]))
				else:
					Kit.rect(n, Rect2(zx, y0, zw, H - y0), _al(col, a))
				Kit.glow(n, Vector2(zx + zw / 2.0, H * 0.2), zw * 0.5, col, 0.4)   # the lamp that makes it
				Kit.dot(n, Vector2(zx + zw / 2.0, H * 0.2), 2.0 * S, col)
				Kit.text(n, kind, Vector2(zx + zw / 2.0, H * 0.34), int(10.0 * S), _al(col, 0.9), true)
			Kit.hero(n, b, Vector2(b.ex, GY), { "face": b.edir, "shirt": Color("5A2A3A"), "tint": _al(Kit.HOT, 0.45), "pose": "run", "frame": b.clock })
			var has_zone := zi >= 0
			var zc: Color = Color(colours[(zones[zi] as Dictionary).kind]) if has_zone else Kit.DIM
			var hopts := { "face": b.face, "pose": "hurt" if hitT > 0.5 else ("run" if moving else "stand"), "frame": b.clock }
			if hitT > 0.5:
				hopts.tint = _al(Kit.HOT, 0.8)
			elif has_zone:
				hopts.tint = _al(zc, 0.4)
			Kit.hero(n, b, Vector2(b.hx, GY), hopts)
			Kit.label(n, b, ("zone: %s" % str((zones[zi] as Dictionary).kind)) if has_zone else "zone: none", Vector2(b.hx, GY - 20.0 * hs), zc, true)
			_label_r(n, b, "hits ×%d" % int(b.hits), Vector2(W - 6.0, 12.0), Kit.DIM)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
