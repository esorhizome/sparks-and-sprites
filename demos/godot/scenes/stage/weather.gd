extends RefCounted

const Kit := preload("res://scenes/stage/kit.gd")
## WATER, WEATHER & NATURE — thirteen scene effects, ported from the web
## almanac (docs/stagecraft.js). The outdoors as SYSTEMS rather than
## paintings. Water is a row of springs that pass their motion sideways; a
## float reads that surface and pushes it back; the shoreline is a slow sine
## the sand remembers; puddles and a wet lens are the flip-and-clip mirror
## trick worn by a hundred small mirrors. Snow is a height field that
## deepens where feet fall, reeds are springs on an angle, wind is a region
## with an envelope, a year is one clock driving every leaf, a fern is a
## rule string, wildfire and lava are cellular grids, and the cheapest
## "outdoors" of all is a scrolling noise mask on the ground.

const TITLE := "Water, weather & nature"
const BLURB := "the outdoors as systems — spring water, floating, foam lines, puddles, rain on the lens, snow prints, reeds, wind, seasons, growth, wildfire, lava, cloud shadows"
const DEFS := [
	{ "id": "wavesprings", "letter": "W", "name": "Wavesprings",
		"hint": "a row of springs, each pulled to rest and toward its neighbours — one kick becomes a wave that travels, spreads and settles (lexicon Damp) — press to splash at x",
		"dials": { "n": 40,              # springs across the width
			"tension": 60,               # k: the pull back to the rest level, per second²
			"damping": 2.5,              # c: velocity bleed, per second
			"spread": 18,                # s: the pull toward each neighbour, per second²
			"level": 0.68,               # the rest surface, of H
			"splash": 0.9,               # a drop's kick, in H per second
			"every": 2.6,                # seconds between the autopilot's drops
			"label": "a = −k·y − c·v + s·(yL + yR − 2y)" },
		"rhyme": { "name": "Wobblepool", "hint": "low tension, heavy spread, little damping — a kick barely dents it but the whole pool rolls together like syrup",
			"dials": { "tension": 10, "spread": 70, "damping": 1.4 } } },
	{ "id": "jetsam", "letter": "J", "name": "Jetsam",
		"hint": "floating on that water: each body rises by how deep it sits and drives the springs under it with its own motion — buoyancy both ways (lexicon Yacht) — press to drop a crate",
		"dials": { "n": 36, "tension": 50, "damping": 2.2, "spread": 16,   # the Wavesprings surface
			"level": 0.66,               # the rest surface, of H
			"density": 0.45,             # 0..1: how much of a float sits under the line at rest
			"push": 4,                   # how hard a moving float drives the springs beneath it
			"drag": 3,                   # water drag on a float, per second
			"count": 2,                  # floats at the start: a crate, then a barrel, alternating
			"size": 1,                   # float size, ×
			"chop": 0,                   # a constant wind ripple laid on the surface, px
			"dive": 4,                   # seconds between the hero's leaps
			"label": "a = g·(1 − depth ÷ (h·density))   spring.v += vy·push" },
		"rhyme": { "name": "Junkraft", "hint": "eight small floats on a choppy surface — every bob drives the springs, so the raft of junk makes its own weather",
			"dials": { "count": 8, "size": 0.5, "chop": 2 } } },
	{ "id": "waterline", "letter": "W", "name": "Waterline",
		"hint": "where water meets shore: the run-up is a body on a spring toward a slow tidal rest, so a pressed wave overshoots up the slope and the backwash undershoots, a foam line that chases the edge on its own lag, and a wet band behind it that dries as it is left (atlas Tide) — press to throw a big wave",
		"dials": { "shore": 0.62,        # the slope runs from the left edge up to this fraction of W
			"tide": 0.55,                # radians per second of the slow in-out sine the REST level follows
			"reach": 0.3,                # how far the tide carries the rest level, of the slope
			"wk": 6,                     # the run-up's stiffness toward the tidal rest: √wk rad/s, a wave every ~2.6 s
			"wdamp": 0.35,               # its damping as a fraction of critical — under 1, so a wave overshoots up the slope and the backwash undershoots
			"surge": 1.2,                # the velocity a press adds to the run-up, slopes per second (about 0.3 of the slope at the crest)
			"foamk": 12,                 # the foam line's own spring toward the water's edge
			"foamdamp": 0.5,             # its damping, of critical — the froth lags the water going up and is left behind coming down
			"dry": 6,                    # seconds for wet sand to fade back
			"cols": 48,                  # wet-memory columns along the slope
			"sea": "#2E7FB8", "sand": "#D8C08A", "wet": "#6A4A28",
			"label": "r'' = wk·(tide(t) − r) − wdamp·2√wk·r' · press: r' += surge · foam'' = foamk·(r − foam) − foamdamp·2√foamk·foam' · wet α = 1 − age ÷ dry" },
		"rhyme": { "name": "Wintersurf", "hint": "a slow grey sea that takes a long time to dry — the same slope and spring, the tide at a colder pace",
			"dials": { "tide": 0.25, "dry": 14, "sea": "#5A6E80" } } },
	{ "id": "puddle", "letter": "P", "name": "Puddle",
		"hint": "flat ellipses that reflect: the flipped sprite (Wetfloor's trick, the atlas's Mirror) clipped to each puddle, sky in the rest, rain rings on top — press to toggle the rain",
		"dials": { "puddles": [[0.2, 0.1, 0.11, 0.028], [0.54, 0.16, 0.16, 0.036], [0.83, 0.07, 0.08, 0.02]],   # x (of W), depth into the ground band (of H), rx (of W), ry (of H)
			"rain": true,                # rings and streaks
			"rate": 12,                  # rain rings per second
			"ringLife": 1.1,             # seconds a ring lives
			"wobble": 2,                 # px the reflection sways
			"sheen": 0,                  # 0..1: an oily rainbow over the water
			"refA": 0.6,                 # reflection strength
			"night": 0.45,
			"label": "clip(ellipse) → draw scene flipped about GY · ring r = age/life" },
		"rhyme": { "name": "Petrol", "hint": "no rain, a still mirror, and an oily rainbow screened over it — hue bands from a slow noise field",
			"dials": { "rain": false, "sheen": 0.7, "wobble": 0.6 } } },
	{ "id": "lens", "letter": "L", "name": "Lens",
		"hint": "rain on the camera glass: drops bead, merge, and run once heavy enough, each a tiny upside-down lens on the scene behind, leaving a trail (bestiary Rain on glass) — press to wipe",
		"dials": { "kind": "rain",       # "rain" | "snow": what lands on the glass
			"rate": 6,                   # new drops per second
			"slideR": 3.2,               # a drop heavier than this runs
			"slideSpeed": 14,            # run speed per unit of extra radius, px/s
			"mag": 0.5,                  # the lens shrink: the drop shows a wider patch of scene, flipped
			"evap": 0.35,                # px of radius lost per second (the trail dries)
			"melt": 2.5,                 # snow: seconds a flake keeps before it becomes water
			"wipeTime": 0.7,             # seconds for one wiper sweep
			"label": "drop = clip(circle) · drawImage(scene, flipped, ÷mag)" },
		"rhyme": { "name": "Lenssnow", "hint": "flakes that land white, sit for a moment, then melt into clear beads that run — the same lens with a countdown in front of it",
			"dials": { "kind": "snow", "melt": 2.2, "rate": 5 } } },
	{ "id": "yeti", "letter": "Y", "name": "Yeti",
		"hint": "footprints in snow: each plant stamps a print and deepens a height field under it, so a path walked twice is darker than one walked once (Marks) — press to send the hero",
		"dials": { "cols": 48, "rows": 10,   # the height field over the ground band
			"step": 0.28,                # how much one plant deepens a cell
			"stride": 0.06,              # distance between plants, of W
			"fade": 30,                  # seconds a print's own outline lasts
			"refill": 0,                 # depth lost per second (wind filling the prints)
			"surface": "snow",           # "snow" | "sand": the palette
			"path": [[0.12, 0.3], [0.85, 0.3], [0.85, 0.75], [0.12, 0.75]],   # waypoints: x of W, y within the ground band
			"speed": 0.22,               # of W per second
			"label": "depth[c][r] += step per plant · colour = mix(surface, shade, depth)" },
		"rhyme": { "name": "Yellowsand", "hint": "dune sand: the same height field, but the wind pays back a little depth every second, so old trails heal and only the walked one stays",
			"dials": { "surface": "sand", "refill": 0.12, "fade": 10 } } },
	{ "id": "quiver", "letter": "Q", "name": "Quiver",
		"hint": "reeds: every blade is a chain of angles on springs (Grass) — the root leans on wind noise and parts from whoever walks through, the joints above chase it under-damped so the tips lag and whip through after the body has passed, with a rustle meter that hears every joint — press to walk through at x",
		"dials": { "blades": 60,         # reeds across the stage
			"height": 1,                 # blade height, × (of 0.28 H)
			"k": 40,                     # the root spring's stiffness
			"c": 3.5,                    # the root's damping (2√k would be critical)
			"joints": 3,                 # segments per reed: the root + the joints that follow it (1 = the old rigid needle)
			"tip": 1.4,                  # each joint's k as a multiple of the one below: above 1 because the segment above is lighter — the same bend rights it faster
			"tipdamp": 0.4,              # a joint's damping, as a fraction of ITS OWN critical — well under 1, so the tip overshoots the root and whips through
			"wind": 0.18,                # radians the wind leans them by
			"windSpeed": 0.7,            # how fast the noise scrolls
			"part": 0.9,                 # radians the hero pushes a blade aside
			"reach": 0.09,               # the hero's push radius, of W
			"walk": 0.16,                # hero speed, of W per second
			"label": "root: θ'' = k·(target − θ) − c·θ' · joint j: θⱼ'' = kⱼ·(θⱼ₋₁ − θⱼ) − tipdamp·2√kⱼ·θⱼ' · kⱼ = tip·kⱼ₋₁ · target = wind·noise + part·(away)" },
		"rhyme": { "name": "Quillfield", "hint": "tall stiff reeds under a slow wind — a high spring constant snaps them back, so the parting is a clean V that closes behind, the tips a beat late",
			"dials": { "height": 1.7, "k": 110, "windSpeed": 0.25 } } },
	{ "id": "updraft", "letter": "U", "name": "Updraft",
		"hint": "wind zones: regions that carry leaves, dust and the hero, each gust an attack / sustain / release envelope drawn as a graph (lexicon Vectorfield, Conveyor) — press to gust now",
		"dials": { "zones": [{ "x": 0.08, "y": 0.35, "w": 0.5, "h": 0.45, "dx": 1, "dy": 0 }, { "x": 0.68, "y": 0.05, "w": 0.18, "h": 0.75, "dx": 0, "dy": -1 }],   # fractions of W, H; a unit direction
			"force": 2.2,                # peak push, in H per second²
			"idle": 0.12,                # the breeze between gusts, as a fraction of force
			"attack": 0.4, "sustain": 1.2, "release": 1.6,   # the envelope, seconds
			"every": 5,                  # seconds between autopilot gusts
			"drag": 1.6,                 # air drag on debris, per second
			"leaves": 60, "dust": 70,
			"label": "a = zone.dir · force · env(t) − drag·v   env: A / S / R" },
		"rhyme": { "name": "Upwell", "hint": "one tall column blowing straight up — leaves rise, hang while the envelope holds, and rain back down on the release",
			"dials": { "zones": [{ "x": 0.36, "y": 0.02, "w": 0.28, "h": 0.78, "dx": 0, "dy": -1 }], "force": 3, "sustain": 2 } } },
	{ "id": "year", "letter": "Y", "name": "Year",
		"hint": "seasons on one clock: buds, green, a turn to red and a fall that flutters and settles by formula, snow that settles and melts — every leaf reads the same phase and nothing is stored (atlas Nightfall) — press to advance the season",
		"dials": { "year": 20,           # seconds per year
			"leaves": 56,                # leaves in the canopy
			"snow": 1,                   # snowfall density, ×
			"fallDur": 0.08,             # of the year a leaf spends falling
			"swings": 2,                 # full flutters a leaf makes on the way down (ω = 2π·swings per fall)
			"settle": 3,                 # the flutter's decay, e^(−settle·q): at 3 a leaf lands with 5% of its sway left
			"label": "p = (t ÷ year) mod 1 → colour(p), fall(p): y ∝ q², x = e^(−λq)·sin(ωq + φ), snow(p): one clock, no memory" },
		"rhyme": { "name": "Yearfast", "hint": "a six-second year, thick snow — the same clock spun fast enough to watch the whole cycle in one breath",
			"dials": { "year": 6, "snow": 2.5, "fallDur": 0.12 } } },
	{ "id": "unfurl", "letter": "U", "name": "Unfurl",
		"hint": "plant growth: a seed → sprout → bloom timeline, and beside it an L-system fern that grows branch by branch from a rule string (lexicon Vine, folio Mushroom) — press to replant",
		"dials": { "rule": "F[+F]F[-F]F",   # the rewrite for every F
			"depth": 4,                  # rewrites (capped at 5)
			"angle": 25,                 # degrees per + or −
			"speed": 1,                  # growth speed, ×
			"grow": 9,                   # seconds for the fern to finish
			"stages": [1.5, 3.5, 6],     # seconds: sprout, leaves, bloom
			"plants": 1,                 # ferns
			"label": "F → rule, depth times · turtle: F draws, ± turns, [ ] branches · revealed = progress · total" },
		"rhyme": { "name": "Undergrowth", "hint": "three ferns from the same rule at a wider angle and twice the speed — the string is identical, the turtle turns harder",
			"dials": { "plants": 3, "speed": 2, "angle": 38 } } },
	{ "id": "kindle", "letter": "K", "name": "Kindle",
		"hint": "wildfire on a grid: burning cells ignite neighbours with a probability the wind tilts, burn for a while, leave ash that regrows (atlas Wildfire) — press to ignite at your click",
		"dials": { "cols": 40, "rows": 14,   # the meadow grid
			"spread": 0.32,              # chance per tick that a burning cell lights a neighbour
			"tick": 0.14,                # seconds per simulation step
			"burn": 1.6,                 # seconds a cell burns
			"ash": true,                 # leave ash (else the ground shows straight through)
			"regrow": 9,                 # seconds until ash is grass again
			"wind": 0.55,                # 0..1: how much the wind tilts the odds
			"windDir": 0,                # degrees, 0 = blowing to the right
			"every": 4,                  # seconds of quiet before the autopilot strikes a match
			"label": "p(n) = spread · (1 + wind · dir·n̂)   burn → ash → grass" },
		"rhyme": { "name": "Kilnwind", "hint": "a gale: the odds downwind nearly double and upwind nearly vanish, cells burn out in half a second and leave no ash — a fire that runs, not one that smoulders",
			"dials": { "wind": 0.9, "burn": 0.5, "ash": false } } },
	{ "id": "lava", "letter": "L", "name": "Lava",
		"hint": "lava on a grid: a slow flow down the slope, a crust that darkens wherever it stops moving (age → colour), heat haze in strips above, embers (the atlas's Lava sea) — press to pour at your click",
		"dials": { "cols": 40, "rows": 12,   # the rock field
			"flow": 0.35,                # fraction of a height difference that moves per tick
			"tick": 0.1,                 # seconds per flow step
			"crust": 4,                  # seconds still before a cell crusts over
			"cool": 10,                  # seconds after crusting until it is dark rock and gone
			"slope": 1.4,                # terrain drop across the width, in lava units
			"channel": 0,                # 0..1: how deep a trench runs across the middle
			"pour": 1.2,                 # lava units per pour
			"every": 1.5,                # seconds between the vent's pours
			"label": "Δ = flow · (h+a − hₙ−aₙ)   colour = f(still age) → crust" },
		"rhyme": { "name": "Lavatube", "hint": "a deep trench across the field: fast flow, quick crust — the lava runs down the channel and roofs itself over into a tube",
			"dials": { "channel": 1, "flow": 0.8, "crust": 1.2 } } },
	{ "id": "cloudshadow", "letter": "C", "name": "Cloudshadow",
		"hint": "cloud shadows: a scrolling noise mask multiplied over the ground, with clouds drawn overhead from the same field (ch04 noise) — press to aim the wind at your click: the wind vector swings round on a spring, so the shadows sweep rather than cut",
		"dials": { "scale": 0.9,         # noise feature size, of W
			"speed": 0.06,               # scroll speed, of W per second
			"threshold": 0.15,           # noise above this is cloud
			"soft": 0.35,                # the width of the mask's edge (0 = hard)
			"dark": 0.45,                # shadow strength
			"windk": 4,                  # the wind vector's spring toward the aimed heading: √windk = 2 rad/s
			"winddamp": 0.45,            # its damping, of critical — under 1, so a turn swings past the new heading and settles over a few seconds
			"cols": 36, "rows": 7,       # the ground mask grid
			"label": "shadow α = smoothstep(thr, thr+soft, noise2(x + ∫wind, y)) · dark · wind'' = windk·(aim − wind) − winddamp·2√windk·wind'" },
		"rhyme": { "name": "Cumulus", "hint": "big slow clouds with hard-edged shadows — the same field at twice the scale, thresholded with no soft edge",
			"dials": { "scale": 2.2, "speed": 0.035, "soft": 0 } } },
]

const FAINT := Color(0.91, 0.898, 0.957, 0.55)   # the web label's default ink
const SNOW_PAL := [Color("F0F2FA"), Color("8A94B8"), Color("4A4470")]   # Yeti: surface, trodden, print
const SAND_PAL := [Color("E2C98A"), Color("9A7A40"), Color("5A4020")]
const SEASONS := ["spring", "summer", "autumn", "winter"]
const YEAR_RING := [Color("9BE28A"), Color("F5C169"), Color("F58A5A"), Color("C9C4E4")]
const KINDLE_DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

# ---------------------------------------------------------------- helpers

## A number for a label: "1" for whole values, "0.25" otherwise (JS's "" + k).
static func _num(v: float) -> String:
	return ("%d" % roundi(v)) if v == roundf(v) else ("%s" % v)

## The web label's "right" alignment: measure, then draw ending at p.x.
static func _label_right(n: CanvasItem, b: Dictionary, txt: String, p: Vector2, col: Color = FAINT) -> void:
	var f := ThemeDB.fallback_font
	var w: float = f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	Kit.label(n, b, txt, Vector2(p.x - w, p.y), col)

## The web kit's mix(a, b, k): a lerp with k clamped.
static func _mix(a: Color, c: Color, k: float) -> Color:
	return a.lerp(c, clampf(k, 0.0, 1.0))

## The web kit's ease(k): a clamped smoothstep.
static func _ease(k: float) -> float:
	k = clampf(k, 0.0, 1.0)
	return k * k * (3.0 - 2.0 * k)

static func _with_a(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, a)

## An ellipse outline (ctx.ellipse + stroke): a closed polyline.
static func _ellipse_stroke(n: CanvasItem, c: Vector2, rx: float, ry: float, col: Color, w: float = 1.0) -> void:
	var pts := PackedVector2Array()
	for i in 33:
		var a := i / 32.0 * TAU
		pts.append(c + Vector2(cos(a) * maxf(0.3, rx), sin(a) * maxf(0.3, ry)))
	n.draw_polyline(pts, col, w)

## The dashed rest line (setLineDash([3, 5])): short segments.
static func _dashed_h(n: CanvasItem, x0: float, x1: float, y: float, col: Color) -> void:
	var x := x0
	while x < x1:
		n.draw_line(Vector2(x, y), Vector2(minf(x + 3.0, x1), y), col, 1.0)
		x += 8.0

## The spring surface both water cards share: one acceleration per spring
## (Damp's a = ω²(target − y) − 2ζω·v) plus the SPREAD toward its neighbours.
static func _springs(b: Dictionary, dt: float) -> void:
	var D: Dictionary = b.D
	var nn: int = D.n
	var ys: Array = b.ys
	var vs: Array = b.vs
	var tension: float = D.tension
	var damping: float = D.damping
	var spread: float = D.spread
	var H: float = b.h
	for i in nn:
		var yl: float = ys[i - 1 if i > 0 else i]
		var yr: float = ys[i + 1 if i < nn - 1 else i]
		var yi: float = ys[i]
		var vi: float = vs[i]
		vs[i] = vi + (-tension * yi - damping * vi + spread * (yl + yr - 2.0 * yi)) * dt
	for i in nn:
		ys[i] = clampf(float(ys[i]) + float(vs[i]) * dt, -H * 0.3, H * 0.3)

## Wavesprings' kick: the spring under x and half to each neighbour.
static func _kick(b: Dictionary, x: float, v: float) -> void:
	var nn: int = b.D.n
	var vs: Array = b.vs
	var i: int = clampi(roundi(x / b.w * (nn - 1)), 0, nn - 1)
	vs[i] = float(vs[i]) + v
	if i > 0:
		vs[i - 1] = float(vs[i - 1]) + v * 0.5
	if i < nn - 1:
		vs[i + 1] = float(vs[i + 1]) + v * 0.5

## Jetsam's surface height under x, interpolated between two springs.
static func _surf(b: Dictionary, x: float, t: float) -> float:
	var D: Dictionary = b.D
	var nn: int = D.n
	var dx: float = b.w / (nn - 1)
	var q: float = clampf(x / dx, 0.0, nn - 1.001)
	var i: int = int(floorf(q))
	var f: float = q - i
	var ys: Array = b.ys
	var y0: float = ys[i]
	var y1: float = ys[i + 1]
	return b.h * D.level + y0 + (y1 - y0) * f + float(D.chop) * sin(x * 0.06 - t * 4.0)

## Jetsam's add(kind, x, y): the ninth float evicts the oldest non-hero.
static func _add_float(b: Dictionary, kind: String, x: float, y: float) -> void:
	var D: Dictionary = b.D
	var H: float = b.h
	var s: float = H * 0.11 * float(D.size)
	var floats: Array = b.floats
	var f := { "kind": kind, "x": x, "y": y, "vy": 0.0, "vx": 0.0,
		"w": s * 0.8 if kind == "barrel" else s, "h": H * 0.16 if kind == "hero" else s, "face": 1 }
	if floats.size() >= 8:
		var k := 0
		while k < floats.size() and floats[k].kind == "hero":
			k += 1
		floats.remove_at(k)
	floats.append(f)

## Waterline's beach profile: a slope up to shore · W, then the flat.
static func _sand_y(b: Dictionary, x: float) -> float:
	var sx: float = b.w * float(b.D.shore)
	var low_y: float = b.h * 0.97
	return b.gy if x >= sx else low_y + (b.gy - low_y) * (x / sx)

## Puddle's reflection: the hero's cells flipped about the ground line
## (the web's translate(sway, 2·GY) · scale(1, −1)) and CLIPPED to the
## ellipse by arithmetic — a cell is drawn only if its centre lies inside.
static func _hero_reflect(n: CanvasItem, b: Dictionary, hx: float, sway: float, face: int, f: float,
		c: Vector2, rx: float, ry: float, alpha: float) -> void:
	var s: float = Kit.hero_unit(b)
	var GY: float = b.gy
	for cell in Kit.hero_cells({ "pose": "run", "frame": f }):
		var uv: Vector2i = cell[0]
		var col: Color = cell[1]
		var x0: float = hx + sway + ((uv.x - 7) * s if face > 0 else -(uv.x - 6) * s)
		var y0: float = GY + (17 - uv.y) * s
		var ex := (x0 + s * 0.5 - c.x) / rx
		var ey := (y0 + s * 0.5 - c.y) / ry
		if ex * ex + ey * ey > 1.0:
			continue
		col.a *= alpha
		n.draw_rect(Rect2(x0, y0, s, s), col)

## Lens's spawn: the 45th drop evicts the oldest.
static func _spawn_drop(b: Dictionary, x: float, y: float, r: float, flake: bool) -> void:
	var drops: Array = b.drops
	if drops.size() >= 44:
		drops.pop_front()
	drops.append({ "x": x, "y": y, "r": r, "flake": float(b.D.melt) if flake else 0.0, "id": b.nid, "tr": 0.0 })
	b.nid += 1

## Lens's wiper geometry: the pivot below the card, the arm as tall as it.
static func _piv(b: Dictionary) -> Vector2:
	return Vector2(b.w / 2.0, b.h * 1.06)

## Quiver's blade: a tapered leaf bent by θ. The web strokes two quadratic
## curves that cross when the reed bends hard (a self-intersecting polygon
## the triangulator rejects), so here it is ONE centre curve widened by a
## taper — 2 px at the root, a hair at the tip — as a strip.
static func _blade(n: CanvasItem, bl: Dictionary, tj: PackedFloat32Array, i: int, J: int, GY: float, hgt: float) -> void:
	# Quiver's reed: a tapered shape walked up the chain, root to tip — the root
	# angle from the blade, the joints above it from the packed array. one
	# outline round the whole chain crosses itself when a joint whips hard and
	# the triangulator refuses it, so each segment is its own convex quad (a
	# trapezoid narrowing up the reed) and the last one a triangle to the tip.
	# the tip's lean picks the shade.
	var bx: float = bl.x
	var seg := hgt / float(J)
	var hw := 2.0
	var p := Vector2(bx, GY)
	var tip_s := 0.0
	if J > 0:
		tip_s = sin(float(bl.th) if J == 1 else tj[i * (J - 1) + J - 2])
	var col := Kit.shade(Kit.GOOD, -0.45 + float(bl.hue) * 0.3 + tip_s * 0.2)
	for j in J:
		var a: float = float(bl.th) if j == 0 else tj[i * (J - 1) + j - 1]
		var q := p + Vector2(sin(a), -cos(a)) * seg
		var off := Vector2(cos(a), sin(a))
		var w0 := hw * (1.0 - float(j) / float(J))
		if j == J - 1:
			n.draw_colored_polygon(PackedVector2Array([p - off * w0, q, p + off * w0]), col)
		else:
			var w1 := hw * (1.0 - float(j + 1) / float(J))
			n.draw_colored_polygon(PackedVector2Array([p - off * w0, q - off * w1, q + off * w1, p + off * w0]), col)
		p = q

## Updraft's envelope: attack / sustain / release of a gust aged `age`.
static func _env(D: Dictionary, age: float) -> float:
	var at: float = D.attack
	var su: float = D.sustain
	var re: float = D.release
	if age < 0.0:
		return 0.0
	if age < at:
		return age / at
	if age < at + su:
		return 1.0
	return clampf(1.0 - (age - at - su) / re, 0.0, 1.0)

static func _in_zone(z: Dictionary, x: float, y: float, W: float, H: float) -> bool:
	return x >= float(z.x) * W and x <= (float(z.x) + float(z.w)) * W and y >= float(z.y) * H and y <= (float(z.y) + float(z.h)) * H

## Unfurl's build(): rewrite the string, then walk it with a turtle into
## unit segments [x, y, nx, ny, level] — stored in order, revealed by time.
static func _build_fern(b: Dictionary) -> void:
	var D: Dictionary = b.D
	var depth: int = clampi(roundi(float(D.depth)), 1, 5)
	var rule: String = D.rule
	var s := "F"
	for _d in depth:
		var out := ""
		for ch in s:
			out += rule if ch == "F" else ch
		s = out
	var segs: Array = []
	var R := Kit.rng(b.seed)
	var stack: Array = []
	var x := 0.0
	var y := 0.0
	var a := -PI / 2.0
	var lv := 0
	var angle: float = D.angle
	for ch in s:
		if ch == "F":
			var nx := x + cos(a)
			var ny := y + sin(a)
			segs.append([x, y, nx, ny, lv])
			x = nx
			y = ny
		elif ch == "+":
			a += (angle + (R.randf() - 0.5) * 6.0) * PI / 180.0
		elif ch == "-":
			a -= (angle + (R.randf() - 0.5) * 6.0) * PI / 180.0
		elif ch == "[":
			stack.append([x, y, a, lv])
			lv += 1
			if stack.size() > 64:
				break
		elif ch == "]" and stack.size() > 0:
			var st: Array = stack.pop_back()
			x = st[0]
			y = st[1]
			a = st[2]
			lv = st[3]
	b.segs = segs
	b.total = segs.size()
	var max_y := 0.0
	for sg in segs:
		max_y = maxf(max_y, -float(sg[3]))
	b.born = maxf(1.0, max_y)

## Kindle's ignite(c, r): grass only, with the burn timer set.
static func _ignite(b: Dictionary, c: int, r: int) -> void:
	var D: Dictionary = b.D
	var cols: int = D.cols
	var rows: int = D.rows
	if c < 0 or r < 0 or c >= cols or r >= rows:
		return
	var i := r * cols + c
	if int(b.st[i]) == 0:
		b.st[i] = 1
		b.tm[i] = float(D.burn)

## Kindle's step(): every burning cell rolls a die per neighbour, the odds
## tilted by the dot product of the wind and the direction to it.
static func _fire_step(b: Dictionary) -> void:
	var D: Dictionary = b.D
	var cols: int = D.cols
	var wd: float = float(D.windDir) * PI / 180.0
	var wx := cos(wd)
	var wy := sin(wd)
	var spread: float = D.spread
	var wind: float = D.wind
	var st: Array = b.st
	var lit: Array = []
	for i in st.size():
		if int(st[i]) == 1:
			lit.append(i)
	for i in lit:
		var c: int = i % cols
		var r: int = int(floor(i / float(cols)))
		for d in KINDLE_DIRS:
			var dv: Vector2i = d
			var p: float = spread * clampf(1.0 + wind * (dv.x * wx + dv.y * wy), 0.0, 2.0)
			if randf() < p:
				_ignite(b, c + dv.x, r + dv.y)

## Lava's addAt(c, r, amt): pour onto a cell that has not crusted.
static func _lava_add(b: Dictionary, c: int, r: int, amt: float) -> void:
	var D: Dictionary = b.D
	var cols: int = D.cols
	var rows: int = D.rows
	if c < 0 or r < 0 or c >= cols or r >= rows:
		return
	var i := r * cols + c
	if float(b.age[i]) < float(D.crust):
		b.am[i] = float(b.am[i]) + amt
		b.age[i] = 0.0

## Lava's step(): each cell sends a fraction of the surface difference
## (h + a) to every lower, uncrusted neighbour; a cell that moved resets its age.
static func _lava_step(b: Dictionary) -> void:
	var D: Dictionary = b.D
	var cols: int = D.cols
	var rows: int = D.rows
	var crust: float = D.crust
	var flow: float = D.flow
	var hs: Array = b.hf
	var am: Array = b.am
	var age: Array = b.age
	var da: Array = b.da
	var N := cols * rows
	for i in N:
		da[i] = 0.0
	for i in N:
		var ai: float = am[i]
		if ai < 0.02 or float(age[i]) >= crust:
			continue
		var c: int = i % cols
		var r: int = int(floor(i / float(cols)))
		var surf_h: float = float(hs[i]) + ai
		var out := 0.0
		var nb := [i - 1 if c > 0 else -1, i + 1 if c < cols - 1 else -1, i - cols if r > 0 else -1, i + cols if r < rows - 1 else -1]
		for j in nb:
			var jj: int = j
			if jj < 0 or float(age[jj]) >= crust:
				continue
			var diff: float = surf_h - (float(hs[jj]) + float(am[jj]))
			if diff <= 0.0:
				continue
			var m: float = minf(flow * diff * 0.25, ai * 0.24)
			da[jj] = float(da[jj]) + m
			out += m
		da[i] = float(da[i]) - out
	for i in N:
		if absf(float(da[i])) > 0.004:
			age[i] = 0.0
		am[i] = maxf(0.0, float(am[i]) + float(da[i]))

## Cloudshadow's mask: one octave of value noise, thresholded — the whole trick.
static func _mask(D: Dictionary, nx: float, ny: float) -> float:
	var v := Kit.noise2(nx, ny)
	var thr: float = D.threshold
	var soft: float = D.soft
	if soft <= 0.0:
		return 1.0 if v > thr else 0.0
	return clampf((v - thr) / soft, 0.0, 1.0)

## An ellipse rotated by `rot` (ctx.ellipse's rotation argument), filled.
static func _ellipse_rot(n: CanvasItem, c: Vector2, rx: float, ry: float, rot: float, col: Color) -> void:
	var pts := PackedVector2Array()
	var cr := cos(rot)
	var sr := sin(rot)
	for i in 24:
		var a := i / 24.0 * TAU
		var px := cos(a) * maxf(0.1, rx)
		var py := sin(a) * maxf(0.1, ry)
		pts.append(c + Vector2(px * cr - py * sr, px * sr + py * cr))
	n.draw_colored_polygon(pts, col)

## Lens's wiper angle to a point (the web's angOf).
static func _ang_of(b: Dictionary, x: float, y: float) -> float:
	var pv := _piv(b)
	return atan2(y - pv.y, x - pv.x)

# ---------------------------------------------------------------- init

static func init(b: Dictionary) -> void:
	var D: Dictionary = b.D
	var W: float = b.w
	var H: float = b.h
	var GY: float = b.gy
	match b.id:
		"wavesprings":
			# the surface is n SPRINGS (Damp's a = ω²(target − y) − 2ζω·v), one per
			# column, each resting on the water line. alone they would only bob in
			# place; the SPREAD term pulls every spring toward its two neighbours, and
			# that coupling is what turns one kick into a wave that travels outward,
			# bounces off the banks and dies down — Terraria's water in forty numbers.
			# drawn as the dots it really is, with the rest line dashed behind them.
			var nn: int = D.n
			b.ys = []
			b.vs = []
			for _i in nn:
				b.ys.append(0.0)
				b.vs.append(0.0)
			b.drops = []
			b.clock = 0.0
		"jetsam":
			# Wavesprings' surface again, with bodies on it. a float reads the surface
			# HEIGHT under it (between two springs); the part of it below that line is
			# its submerged depth, and BUOYANCY pushes up in proportion — the body
			# settles where the upthrust equals its weight (that ratio is density).
			# the other way round, a float moving down drives its springs down, so a
			# drop makes a wave and every bob leaves ripples. Yacht rode a wave that
			# was a formula; here the wave is ridden AND made.
			var nn: int = D.n
			b.ys = []
			b.vs = []
			for _i in nn:
				b.ys.append(0.0)
				b.vs.append(0.0)
			b.floats = []
			b.diveClock = 0.0
			b.nextKind = 0
			var count: int = D.count
			for c in count:
				_add_float(b, "barrel" if c % 2 == 1 else "crate", W * (0.2 + 0.6 * (c + 0.5) / count), H * 0.2)
			_add_float(b, "hero", W * 0.5, H * 0.3)
		"waterline":
			# seen from the side: a beach is a SLOPE and the sea is a flat LEVEL. the
			# WATERLINE is simply where the level meets the slope, so it runs up the
			# beach and back. the level is not a clock: the run-up r is a BODY on a
			# spring (the lexicon's Damp) whose rest is the slow tide, so it carries
			# momentum — a press does not lift the water, it throws it: a velocity
			# kick that the spring turns into a wave that overshoots up the slope, a
			# backwash that undershoots below the rest, and a ring-down of a few
			# seconds. the FOAM is a second body chasing the first on its own slacker
			# spring, so it trails the edge on the way up and is left on the sand on
			# the way down. the WET BAND — every column of sand remembers when it was
			# last covered and darkens by that age, drying over D.dry seconds — is
			# Tide's trick, turned on its side.
			b.lastT = []
			for _c in int(D.cols):
				b.lastT.append(-99.0)
			b.r = 0.5                                    # the run-up, of the slope, and its velocity
			b.v = 0.0
			b.fr = 0.5                                   # the foam line, chasing r on its own spring
			b.fv = 0.0
			b.rest = 0.5
			b.foam = 0.0
			b.level = GY
			b.edge = W * float(D.shore) * 0.5
		"puddle":
			# a puddle is a MIRROR you can only see through a hole: clip to the
			# ellipse, then draw the sprite FLIPPED about the ground line (translate
			# to 2·GY, scale y by −1 — the same flip-and-clip as the atlas's Mirror),
			# faded, with a sine sway. the sky's reflection is a lighter gradient in
			# the same clip. RAIN RINGS are ellipses that grow and fade, squashed by
			# the puddle's own aspect so they lie on the ground. (the web draws one
			# cached sprite image flipped; here the hero's cells are flipped one by
			# one and clipped to the ellipse by arithmetic — see _hero_reflect.)
			b.rings = []
			for _i in 40:
				b.rings.append({ "p": 0, "ox": 0.0, "oy": 0.0, "age": 9.0 })
			b.rain = bool(D.rain)
			b.acc = 0.0
		"lens":
			# a raindrop on a lens is a small LENS: clip to its circle and draw the
			# scene layer through it flipped and shrunk, so each drop carries an
			# upside-down world. drops have a radius that stands in for mass: they
			# sit until they are heavier than slideR, then RUN downward, wandering on
			# noise, swallowing what they touch and shedding a trail of small beads
			# that dry (evaporate) behind them. the WIPER is a pivoting arm: anything
			# between last frame's angle and this one's is gone. (no offscreen scene
			# copy here: each drop is a small shaded bead — sky-light at the bottom,
			# ground-dark at the top, the way the flipped scene would read.)
			b.drops = []
			b.wipe = -1.0
			b.wipePrev = 0.0
			b.nid = 0
		"yeti":
			# a footprint is a DECAL stamped by distance moved (Marks); the trail is a
			# HEIGHT FIELD — a coarse grid over the ground where every plant adds
			# depth, clamped at 1. the grid is painted by depth, so the first pass
			# leaves faint prints and the tenth a trodden groove; on sand the wind
			# pays it back a little every second (refill), and the trail heals. the
			# prints themselves are small ellipses that age out; the field remembers.
			var cols: int = D.cols
			var rows: int = D.rows
			b.field = []
			for _i in cols * rows:
				b.field.append(0.0)
			b.prints = []
			for _i in 90:
				b.prints.append({ "x": 0.0, "y": 0.0, "a": 0.0, "age": 99.0 })
			var path: Array = D.path
			var p0: Array = path[0]
			b.wp = 0
			b.acc = 0.0
			b.foot = 0
			b.hx = W * float(p0[0])
			b.hy = GY + (H - GY) * float(p0[1])
			b.target = null
			b.face = 1
		"quiver":
			# Grass bends every blade as a CHAIN of angles: the root is a damped spring
			# toward a target, and each joint above is the same spring again, chasing
			# the segment below on a quicker, much less damped spring, so the tip lags
			# on the way out and whips through on the way back. reeds add the WIND:
			# the root's target is noise(t·speed + x) scaled by D.wind, so neighbours
			# lean together in slow waves, plus a push AWAY from the hero that fades
			# with distance — and the joints pass all of it up to the tips a beat late.
			# the RUSTLE is the mean angular speed over every segment of every reed —
			# a meter you can watch, and after the first press a short filtered noise
			# burst whenever it spikes (rate-limited).
			var R := Kit.rng(11)
			var nb: int = D.blades
			b.blades = []
			for i in nb:
				b.blades.append({ "x": (i + 0.5) / nb * W + (R.randf() - 0.5) * 6.0, "h": 0.7 + R.randf() * 0.6,
					"th": 0.0, "w": 0.0, "hue": R.randf() })
			var J := maxi(1, int(D.joints))               # segments per reed; joints above the root: J − 1
			var tj := PackedFloat32Array()                # joint angles, reed-major: tj[i * (J − 1) + j] — sized here: a packed array read back from b is a copy
			var oj := PackedFloat32Array()                # and their angular velocities
			tj.resize(nb * (J - 1))
			oj.resize(nb * (J - 1))
			b.J = J
			b.tj = tj
			b.oj = oj
			b.hx = W * 0.2
			b.dir = 1
			b.goal = -1.0                                # < 0: no goal, patrol
			b.armed_sound = false
			b.cool = 0.0
			b.rustle = 0.0
			b.face = 1
		"updraft":
			# a wind zone is a RECTANGLE with a direction (Vectorfield, drawn with
			# arrows). its strength is not a number but an ENVELOPE: a gust attacks
			# over A seconds, holds for S, and releases over R — the same shape a
			# synth uses for loudness. debris inside a zone accelerates along its
			# direction times the envelope, minus drag; leaves also feel gravity so
			# they settle when the gust ends, and the up-zone lifts the hero off the
			# ground while it blows. between gusts a small idle breeze keeps it alive.
			var R := Kit.rng(3)
			var nl: int = D.leaves
			var nd: int = D.dust
			b.parts = []
			for i in nl + nd:
				b.parts.append({ "x": R.randf() * W, "y": GY - R.randf() * H * 0.5, "vx": 0.0, "vy": 0.0, "leaf": i < nl, "s": R.randf() })
			b.gustAt = -99.0
			b.gust_pending = false
			b.clock = float(D.every) - 1.0
			b.hx = W * 0.3
			b.hy = GY
			b.hvy = 0.0
			b.face = 1
		"year":
			# Nightfall turned one clock into five palettes; a YEAR is the same idea
			# with more states. the phase p runs 0..1 and every leaf is a pure
			# function of it: size grows in spring, colour turns from green toward
			# red as autumn passes the leaf's own turn time, then from its fallAt it
			# falls on q² (it accelerates) with a sway that is a damped oscillation
			# WRITTEN OUT — A·e^(−settle·q)·(sin(2π·swings·q + φ) − sin φ), φ the
			# leaf's own phase — so it flutters hardest just after letting go and
			# settles before it lands, instead of swinging like a metronome. no
			# velocity is stored: that formula IS the solution of the spring, read
			# off at q. then it lies there as litter. snow is a second function of p —
			# settling through winter, melting in the first weeks of spring. nothing
			# is remembered, so a skip costs nothing.
			var R := Kit.rng(21)
			var cr: float = H * 0.2
			var nl: int = D.leaves
			b.leaves = []
			for _i in nl:
				var a := R.randf() * TAU
				var r := sqrt(R.randf()) * cr
				b.leaves.append({ "ox": cos(a) * r * 1.15, "oy": sin(a) * r * 0.8 - cr * 0.1, "turn": 0.5 + R.randf() * 0.12,
					"fallAt": 0.58 + R.randf() * 0.16, "hue": R.randf(), "landX": (R.randf() - 0.5) * cr * 3.0, "ph": R.randf() * TAU })
			b.shift = 0.0
			b.lastT = 0.0
		"unfurl":
			# an L-SYSTEM is a string that rewrites itself: every F becomes the rule,
			# depth times, and a turtle reads the result — F draws, + and − turn by
			# the angle, [ saves the turtle and ] restores it (that is a branch). the
			# string is expanded once; the turtle's segments are stored in order and
			# REVEALED as the clock advances, so the fern grows the way it was written,
			# one branch at a time. the pot plant beside it is the plain version:
			# three stages on a timer, each a tween. press replants both.
			b.seed = 1
			b.t0 = 0.0
			b.lastT = 0.0
			_build_fern(b)
		"kindle":
			# a CELLULAR grid: every cell is grass, burning (with a timer) or ash.
			# each tick, a burning cell rolls a die for each of its four neighbours
			# — the chance is D.spread, multiplied up for the neighbour downwind and
			# down for the one upwind (the dot product of the wind and the direction
			# to it). fire burns out after D.burn seconds and leaves ash that regrows,
			# so the field never runs out. the odds table is drawn beside the wind.
			var N: int = int(D.cols) * int(D.rows)
			var R := Kit.rng(5)
			b.st = []
			b.tm = []
			b.hue = []
			for _i in N:
				b.st.append(0)
				b.tm.append(0.0)
				b.hue.append(R.randf())
			b.acc = 0.0
			b.quiet = 0.0
			b.burning = 0
		"lava":
			# a HEIGHT-FIELD FLOW: every cell has terrain height h and lava amount a;
			# each tick, lava moves from a cell to lower neighbours by a fraction of
			# the surface difference (h + a). a cell's STILL AGE counts up while
			# nothing moves through it, and the colour is a function of that age —
			# yellow when moving, red as it slows, black CRUST once it passes D.crust,
			# and after D.cool it is rock and leaves the simulation. crusted cells no
			# longer flow, so new lava runs around them — the tube. the HEAT HAZE is
			# the band above the field copied out in strips and pushed by noise (no
			# layer copy here: it is faint warm strips, shifted by the same noise).
			var cols: int = D.cols
			var rows: int = D.rows
			var slope: float = D.slope
			var channel: float = D.channel
			b.hf = []
			b.am = []
			b.age = []
			b.da = []
			b.rock = []                                  # the rock shade never changes: build it once (as alphas)
			for i in cols * rows:
				var c: int = i % cols
				var r: int = int(i / float(cols))
				var trench: float = channel * 3.0 * exp(-pow((r - rows * 0.5) / 1.6, 2.0))
				var hv: float = -slope * c / cols + Kit.noise2(c * 0.35, r * 0.35 + 7.0) * 0.25 - trench
				b.hf.append(hv)
				b.am.append(0.0)
				b.age.append(0.0)
				b.da.append(0.0)
				b.rock.append(0.25 * clampf(-hv / (slope + 3.0), 0.0, 1.0) + 0.1 * (Kit.noise2(c * 0.7, r * 0.7) * 0.5 + 0.5))
			b.embers = []
			for _i in 40:
				b.embers.append({ "x": 0.0, "y": 0.0, "vy": 0.0, "life": 0.0 })
			b.acc = 0.0
			b.vent = 0.0
			b.hot = 0
		"cloudshadow":
			# the cheapest outdoors cue there is: a NOISE FIELD scrolled by the wind,
			# thresholded into blobs, MULTIPLIED over the ground as darkness. the
			# clouds above are the same field sampled along a band of the sky, so
			# their shapes and the shadows drifting under them agree. the mask is a
			# coarse grid of rectangles — a few hundred alpha fills — and it darkens
			# the hero and props too, because it is drawn after them. the wind is a
			# BODY, not a setting: a press moves the AIM, and the wind vector chases
			# it on an under-damped spring (one per axis), so it swings past the new
			# heading, gusts while it turns, and settles over a few seconds; the
			# offsets integrate the wind as it swings, so both layers sweep round
			# together instead of cutting to the new direction in a frame.
			b.ox = 0.0
			b.oy = 0.0
			b.wx = 1.0                                   # the wind vector, its velocity, and the aim it springs toward
			b.wy = 0.25
			b.vx = 0.0
			b.vy = 0.0
			b.ax = 1.0
			b.ay = 0.25
			b.shades = []                                # the mask quantised to 16 alphas, built once
			var dark: float = D.dark
			for i in 17:
				b.shades.append(Color(0.039, 0.039, 0.118, i / 16.0 * dark))


# ---------------------------------------------------------------- press

static func press(b: Dictionary, pos: Vector2) -> void:
	var D: Dictionary = b.D
	var W: float = b.w
	var H: float = b.h
	var GY: float = b.gy
	match b.id:
		"wavesprings":
			if (b.drops as Array).size() < 8:
				b.drops.append({ "x": clampf(pos.x, 2.0, W - 2.0), "y": minf(pos.y, H * float(D.level) - 6.0), "vy": 0.0 })
		"jetsam":
			var k: int = b.nextKind
			b.nextKind = k + 1
			_add_float(b, "barrel" if k % 2 == 1 else "crate", clampf(pos.x, 10.0, W - 10.0), minf(pos.y, H * float(D.level) - 10.0))
		"waterline":
			b.v = float(b.v) + float(D.surge)            # a velocity kick: the spring does the rest
		"puddle":
			b.rain = not bool(b.rain)
		"lens":
			if float(b.wipe) < 0.0:
				b.wipe = 0.0
				b.wipePrev = -PI * 0.92
		"yeti":
			b.target = Vector2(clampf(pos.x, 8.0, W - 8.0), clampf(pos.y, GY + 4.0, H - 6.0))
		"quiver":
			b.armed_sound = true
			b.goal = clampf(pos.x, 8.0, W - 8.0)
		"updraft":
			b.gust_pending = true
		"year":
			var year: float = D.year
			var p := fposmod(float(b.lastT) / year + float(b.shift), 1.0)
			b.shift = float(b.shift) + 0.25 - fmod(p, 0.25) + 0.002   # snap to the next quarter
		"unfurl":
			b.seed = (int(b.seed) * 7 + 3) % 1000
			b.t0 = float(b.lastT)
			_build_fern(b)
		"kindle":
			var cols: int = D.cols
			var rows: int = D.rows
			var y0: float = GY - H * 0.22
			var cw: float = W / cols
			var ch: float = (H - y0) / rows
			_ignite(b, int(floorf(pos.x / cw)), int(floorf((pos.y - y0) / ch)))
		"lava":
			var cols: int = D.cols
			var rows: int = D.rows
			var y0: float = GY - H * 0.2
			var cw: float = W / cols
			var ch: float = (H - y0) / rows
			_lava_add(b, int(floorf(pos.x / cw)), int(floorf((pos.y - y0) / ch)), float(D.pour))
		"cloudshadow":
			var dx := pos.x - W / 2.0
			var dy := pos.y - H / 2.0
			var d := maxf(1e-6, sqrt(dx * dx + dy * dy))
			b.ax = dx / d                                # move the aim; the spring does the turning
			b.ay = dy / d * 0.4

# ---------------------------------------------------------------- tick

static func tick(b: Dictionary, dt: float, t: float) -> void:
	var D: Dictionary = b.D
	var W: float = b.w
	var H: float = b.h
	var GY: float = b.gy
	var S: float = H / 170.0
	match b.id:
		"wavesprings":
			var nn: int = D.n
			var rest: float = H * float(D.level)
			var splash: float = D.splash
			b.clock = float(b.clock) + dt
			if float(b.clock) > float(D.every):
				b.clock = 0.0
				if (b.drops as Array).size() < 8:
					b.drops.append({ "x": randf_range(W * 0.1, W * 0.9), "y": H * 0.08, "vy": 0.0 })
			var drops: Array = b.drops
			var ys: Array = b.ys
			var d := drops.size() - 1
			while d >= 0:                                # a pebble falls, then kicks the spring it lands on
				var p: Dictionary = drops[d]
				p.vy = float(p.vy) + H * 2.4 * dt
				p.y = float(p.y) + float(p.vy) * dt
				var i: int = clampi(roundi(float(p.x) / W * (nn - 1)), 0, nn - 1)
				if float(p.y) >= rest + float(ys[i]):
					_kick(b, float(p.x), H * splash * clampf(float(p.vy) / (H * 1.5), 0.3, 1.4))
					drops.remove_at(d)
				d -= 1
			_springs(b, dt)                              # the whole physics: one acceleration per spring
		"jetsam":
			var nn: int = D.n
			var G: float = H * 2.4
			var dx: float = W / (nn - 1)
			var density: float = D.density
			var push: float = D.push
			var drag: float = D.drag
			var dive: float = D.dive
			var vs: Array = b.vs
			b.diveClock = float(b.diveClock) + dt
			for f: Dictionary in b.floats:
				var fx: float = f.x
				var fy: float = f.y
				var fh: float = f.h
				var fw: float = f.w
				var hs := _surf(b, fx, t)
				var depth := clampf(fy - hs, 0.0, fh)
				var a := G
				if depth > 0.0:
					a -= G * depth / (fh * density)      # upthrust grows with depth: the whole buoyancy law
					f.vy = float(f.vy) - float(f.vy) * clampf(drag * dt, 0.0, 1.0)
					f.vx = float(f.vx) - float(f.vx) * clampf(drag * dt, 0.0, 1.0)
					var i0: int = clampi(int(floorf((fx - fw / 2.0) / dx)), 0, nn - 1)
					var i1: int = clampi(int(ceilf((fx + fw / 2.0) / dx)), 0, nn - 1)
					for i in range(i0, i1 + 1):          # and the float drives the springs beneath it
						vs[i] = float(vs[i]) + float(f.vy) * push * dt
				f.vy = float(f.vy) + a * dt
				f.y = fy + float(f.vy) * dt
				f.x = fx + float(f.vx) * dt
				if float(f.y) > H + fh:
					f.y = H
					f.vy = 0.0
				if float(f.x) < fw / 2.0:
					f.x = fw / 2.0
					f.vx = absf(float(f.vx))
				if float(f.x) > W - fw / 2.0:
					f.x = W - fw / 2.0
					f.vx = -absf(float(f.vx))
				if f.kind == "hero" and depth > 0.0 and float(b.diveClock) > dive and absf(float(f.vy)) < H * 0.2:   # the hero leaps out and lands again
					b.diveClock = 0.0
					f.vy = -H * 1.4
					f.vx = randf_range(-1.0, 1.0) * H * 0.5
					f.face = -1 if float(f.vx) < 0.0 else 1
			_springs(b, dt)
		"waterline":
			var sx: float = W * float(D.shore)
			var low_y: float = H * 0.97
			var rest := 0.5 + float(D.reach) * sin(t * float(D.tide))   # the tide: where the run-up would sit if it stood still
			var wk: float = D.wk
			var fk: float = D.foamk
			var wc: float = float(D.wdamp) * 2.0 * sqrt(wk)
			var fc: float = float(D.foamdamp) * 2.0 * sqrt(fk)
			var r: float = b.r
			var v: float = b.v
			var fr: float = b.fr
			var fv: float = b.fv
			# two springs, stepped symplectically; a coarse frame is cut into substeps
			# of at most 0.02 s (the lexicon's Substep) so foamk stays well inside √k·h < 2
			var sub := maxi(1, ceili(dt * 50.0))
			var h := dt / float(sub)
			for _s in sub:
				v += (wk * (rest - r) - wc * v) * h
				r += v * h
				if r > 0.95:                             # the top of the beach and the sea floor stop it dead
					r = 0.95
					v = minf(v, 0.0)
				if r < 0.05:
					r = 0.05
					v = maxf(v, 0.0)
				fv += (fk * (r - fr) - fc * fv) * h      # the foam chases the water, late
				fr = clampf(fr + fv * h, 0.02, 0.98)
			var edge := sx * r
			b.r = r
			b.v = v
			b.fr = fr
			b.fv = fv
			b.rest = rest
			b.foam = clampf(maxf(v, 0.0) * 5.0 + absf(r - fr) * 6.0, 0.0, 1.0)   # froth: the advance, and the gap the foam has yet to close
			b.level = low_y + (GY - low_y) * r
			b.edge = edge
			var cols: int = D.cols
			var cw := sx / cols
			var last: Array = b.lastT
			for c in cols:                               # the wet memory, column by column
				if c * cw + cw * 0.5 <= edge:
					last[c] = t
		"puddle":
			var rate: float = D.rate
			var puddles: Array = D.puddles
			var rings: Array = b.rings
			if bool(b.rain):
				b.acc = float(b.acc) + dt * rate
			while float(b.acc) >= 1.0:                   # a new ring in a random puddle
				b.acc = float(b.acc) - 1.0
				var oldest := 0
				for i in range(1, rings.size()):
					if float(rings[i].age) > float(rings[oldest].age):
						oldest = i
				var rg: Dictionary = rings[oldest]
				rg.p = randi_range(0, puddles.size() - 1)
				rg.ox = randf_range(-0.7, 0.7)
				rg.oy = randf_range(-0.7, 0.7)
				rg.age = 0.0
			for rg: Dictionary in rings:
				rg.age = float(rg.age) + dt
		"lens":
			var rate: float = D.rate
			var slide_r: float = float(D.slideR) * S
			var slide_speed: float = D.slideSpeed
			var evap: float = D.evap
			var snowing: bool = str(D.kind) == "snow"
			var k := 0.0
			while k < rate * dt:
				if randf() < minf(1.0, rate * dt - k):
					_spawn_drop(b, randf_range(0.0, W), randf_range(0.0, H), randf_range(1.4, 3.4) * S, snowing)
				k += 1.0
			var drops: Array = b.drops
			var i := drops.size() - 1
			while i >= 0:                                # physics: melt, run, wander, shed, dry
				var d: Dictionary = drops[i]
				if float(d.flake) > 0.0:
					d.flake = float(d.flake) - dt
					i -= 1
					continue
				var extra: float = float(d.r) - slide_r
				if extra > 0.0:
					var v := slide_speed * extra * S
					d.y = float(d.y) + v * dt
					d.x = float(d.x) + Kit.noise(float(d.y) * 0.04 + float(d.id) * 3.1) * v * 0.5 * dt
					d.tr = float(d.tr) + v * dt
					if float(d.tr) > float(d.r) * 2.2:
						d.tr = 0.0
						_spawn_drop(b, float(d.x) + randf_range(-1.0, 1.0), float(d.y) - float(d.r), float(d.r) * 0.32, false)
						d.r = float(d.r) - float(d.r) * 0.04
				else:
					d.r = float(d.r) - evap * S * dt
				if float(d.r) < 0.6 or float(d.y) > H + float(d.r):
					drops.remove_at(i)
					i -= 1
					continue
				var j := drops.size() - 1
				while j >= 0:                            # merge: the bigger swallows the smaller
					if j != i:
						var e: Dictionary = drops[j]
						var dd := Vector2(float(d.x) - float(e.x), float(d.y) - float(e.y)).length()
						if dd < (float(d.r) + float(e.r)) * 0.8 and float(e.r) <= float(d.r) and float(e.flake) <= 0.0:
							d.r = minf(9.0 * S, sqrt(float(d.r) * float(d.r) + float(e.r) * float(e.r)))
							drops.remove_at(j)
							if j < i:
								i -= 1
					j -= 1
				i -= 1
			if float(b.wipe) >= 0.0:                     # the wiper sweeps; drops in its sector are gone
				b.wipe = float(b.wipe) + dt / float(D.wipeTime)
				var a := -PI * 0.92 + PI * 0.84 * clampf(float(b.wipe), 0.0, 1.0)
				var pv := _piv(b)
				var prev: float = b.wipePrev
				var m := drops.size() - 1
				while m >= 0:
					var d: Dictionary = drops[m]
					var q := _ang_of(b, float(d.x), float(d.y))
					if q >= prev and q <= a and Vector2(float(d.x) - pv.x, float(d.y) - pv.y).length() < H:
						drops.remove_at(m)
					m -= 1
				b.wipePrev = a
				if float(b.wipe) >= 1.0:
					b.wipe = -1.0
		"yeti":
			var cols: int = D.cols
			var rows: int = D.rows
			var band := H - GY
			var cw := W / cols
			var ch := band / rows
			var path: Array = D.path
			var refill: float = D.refill
			var step: float = D.step
			var target: Variant = b.target
			var goal: Vector2
			if target != null:
				goal = target
			else:
				var wpt: Array = path[int(b.wp)]
				goal = Vector2(W * float(wpt[0]), GY + band * float(wpt[1]))
			var hx: float = b.hx
			var hy: float = b.hy
			var dx := goal.x - hx
			var dy := goal.y - hy
			var d := sqrt(dx * dx + dy * dy)
			var step_len := minf(d, W * float(D.speed) * dt)
			if d < 3.0:
				if target != null:
					b.target = null
				else:
					b.wp = (int(b.wp) + 1) % path.size()
			else:
				hx += dx / d * step_len
				hy += dy / d * step_len
				b.face = -1 if dx < 0.0 else 1
				b.acc = float(b.acc) + step_len
			b.hx = hx
			b.hy = hy
			var field: Array = b.field
			if float(b.acc) >= W * float(D.stride):      # a plant: stamp a print, deepen the field
				b.acc = 0.0
				b.foot = 1 - int(b.foot)
				var foot: int = b.foot
				var nx := -dy / d if d > 0.0 else 0.0
				var ny := dx / d if d > 0.0 else 1.0
				var off := (1.0 if foot == 1 else -1.0) * 4.0
				var px := hx + nx * off
				var py := hy + ny * off
				var prints: Array = b.prints
				var old := 0
				for i in range(1, prints.size()):
					if float(prints[i].age) > float(prints[old].age):
						old = i
				var pr: Dictionary = prints[old]
				pr.x = px
				pr.y = py
				pr.a = atan2(dy, dx)
				pr.age = 0.0
				var c: int = clampi(int(floorf(px / cw)), 0, cols - 1)
				var r: int = clampi(int(floorf((py - GY) / ch)), 0, rows - 1)
				field[r * cols + c] = minf(1.0, float(field[r * cols + c]) + step)
				var r2: int = clampi(r + (1 if foot == 1 else -1), 0, rows - 1)   # the print's edge bleeds into the next row
				field[r2 * cols + c] = minf(1.0, float(field[r2 * cols + c]) + step * 0.4)
			if refill > 0.0:
				for i in field.size():
					field[i] = maxf(0.0, float(field[i]) - refill * dt)
			for pr: Dictionary in b.prints:
				pr.age = float(pr.age) + dt
		"quiver":
			var goal: float = b.goal
			var hx: float = b.hx
			var g: float = goal if goal >= 0.0 else (W - 10.0 if int(b.dir) > 0 else 10.0)
			var dx := g - hx
			var sp := W * float(D.walk) * dt
			if absf(dx) <= sp:
				hx = g
				if goal >= 0.0:
					b.goal = -1.0
				else:
					b.dir = -int(b.dir)
			else:
				hx += signf(dx) * sp
			b.hx = hx
			b.face = -1 if dx < 0.0 else 1
			var reach := W * float(D.reach)
			var wind: float = D.wind
			var wind_speed: float = D.windSpeed
			var part: float = D.part
			var kk: float = D.k
			var cc: float = D.c
			var J: int = b.J
			var tj: PackedFloat32Array = b.tj
			var oj: PackedFloat32Array = b.oj
			var tip: float = D.tip
			var tipdamp: float = D.tipdamp
			# the joints up a reed are stiffer than the root (k · tip per joint), and a
			# symplectic step is only stable while √k·h < 2 — so a coarse frame is cut
			# into substeps of at most 0.02 s (the lexicon's Substep): one step at 60 fps
			var sub := maxi(1, ceili(dt * 50.0))
			var h := dt / float(sub)
			var sum := 0.0
			var blades: Array = b.blades
			for i in blades.size():
				var bl: Dictionary = blades[i]
				var bx: float = bl.x
				var target := Kit.noise(t * wind_speed + bx / W * 3.0) * wind
				var d := bx - hx
				var ad := absf(d)
				if ad < reach:
					target += (-1.0 if d < 0.0 else 1.0) * part * (1.0 - ad / reach)   # parting: away from the body
				var w: float = bl.w
				var th: float = bl.th
				for _s in sub:
					w += (kk * (target - th) - cc * w) * h    # the root spring, on an angle
					th = clampf(th + w * h, -1.4, 1.4)
					var below: float = th                     # the joints: each chases the segment below
					var kj: float = kk
					for j in J - 1:
						kj *= tip                             # quicker with every joint up the reed
						var dj := tipdamp * 2.0 * sqrt(kj)    # a fraction of THIS joint's critical damping
						var idx := i * (J - 1) + j
						oj[idx] += (kj * (below - tj[idx]) - dj * oj[idx]) * h
						tj[idx] = clampf(tj[idx] + oj[idx] * h, -1.6, 1.6)
						below = tj[idx]
				bl.w = w
				bl.th = th
				sum += absf(w)
				for j in J - 1:                               # the joints rustle too
					sum += absf(oj[i * (J - 1) + j])
			b.rustle = float(b.rustle) + (sum / float(blades.size() * J) - float(b.rustle)) * clampf(dt * 8.0, 0.0, 1.0)   # the meter's own smoothing, a readout not a motion
			b.cool = float(b.cool) - dt
			if bool(b.armed_sound) and float(b.rustle) > 0.9 and float(b.cool) <= 0.0:
				b.cool = 0.45
				Kit.noise_burst({ "dur": 0.22, "vol": 0.07, "lowpass": 3200.0, "sweep_to": 1200.0 })
		"updraft":
			if bool(b.gust_pending):
				b.gust_pending = false
				b.gustAt = t
			b.clock = float(b.clock) + dt
			if float(b.clock) > float(D.every):
				b.clock = 0.0
				b.gustAt = t
			var zones: Array = D.zones
			var e := _env(D, t - float(b.gustAt))
			var idle: float = D.idle
			var g := idle + (1.0 - idle) * e
			var F := H * float(D.force)
			var drag: float = D.drag
			for p: Dictionary in b.parts:                # debris under the field
				var px: float = p.x
				var py: float = p.y
				var ps: float = p.s
				var ax := 0.0
				var ay := H * 0.5 if bool(p.leaf) else 0.0
				for z: Dictionary in zones:
					if _in_zone(z, px, py, W, H):
						ax += float(z.dx) * F * g
						ay += float(z.dy) * F * g
				ax += Kit.noise(t * 2.0 + ps * 40.0) * H * 0.3 * g
				ay += Kit.noise(t * 2.0 + ps * 40.0 + 9.0) * H * 0.3 * g
				p.vx = float(p.vx) + (ax - drag * float(p.vx)) * dt
				p.vy = float(p.vy) + (ay - drag * float(p.vy)) * dt
				px += float(p.vx) * dt
				py += float(p.vy) * dt
				if py > GY:
					py = GY
					p.vy = 0.0
					p.vx = float(p.vx) * 0.8
				if px > W + 6.0:
					px -= W + 12.0
				elif px < -6.0:
					px += W + 12.0
				if py < -10.0:
					py = GY - 1.0
					px = randf_range(0.0, W)
					p.vy = 0.0
				p.x = px
				p.y = py
			var hx: float = b.hx
			var hy: float = b.hy
			var face: int = b.face
			var hax := 0.0                               # the hero: pushed sideways, lifted in an up-zone
			var lift := false
			for z: Dictionary in zones:
				if _in_zone(z, hx, hy - H * 0.08, W, H):
					hax += float(z.dx) * F * g
					if float(z.dy) < 0.0 and e > 0.2:
						lift = true
			hx += (W * 0.08 * face + hax * 0.25) * dt
			if hx > W * 0.92:
				hx = W * 0.92
				face = -1
			if hx < W * 0.05:
				hx = W * 0.05
				face = 1
			var hvy: float = b.hvy
			hvy += (-H * 1.6 * e if lift else H * 2.2) * dt
			hvy *= 0.96
			hy = clampf(hy + hvy * dt, H * 0.15, GY)
			if hy >= GY:
				hvy = minf(hvy, 0.0)
			b.hx = hx
			b.hy = hy
			b.hvy = hvy
			b.face = face
		"year":
			b.lastT = t                                  # everything else is a pure function of t
		"unfurl":
			b.lastT = t
		"kindle":
			var N: int = (b.st as Array).size()
			var regrow: float = D.regrow
			var ash: bool = bool(D.ash)
			var cols: int = D.cols
			var rows: int = D.rows
			b.acc = float(b.acc) + dt
			var loops := 0
			while float(b.acc) >= float(D.tick) and loops < 4:
				b.acc = float(b.acc) - float(D.tick)
				loops += 1
				_fire_step(b)
			var st: Array = b.st
			var tm: Array = b.tm
			var burning := 0
			for i in N:                                  # timers: burning → ash → grass
				if int(st[i]) == 1:
					burning += 1
					tm[i] = float(tm[i]) - dt
					if float(tm[i]) <= 0.0:
						st[i] = 2 if ash else 0
						tm[i] = regrow
				elif int(st[i]) == 2:
					tm[i] = float(tm[i]) - dt
					if float(tm[i]) <= 0.0:
						st[i] = 0
			b.burning = burning
			b.quiet = 0.0 if burning > 0 else float(b.quiet) + dt
			if float(b.quiet) > float(D.every):
				b.quiet = 0.0
				_ignite(b, randi_range(0, cols - 1), randi_range(0, rows - 1))
		"lava":
			var cols: int = D.cols
			var rows: int = D.rows
			var N := cols * rows
			var crust: float = D.crust
			var cool: float = D.cool
			var top := GY - H * 0.2
			var cw := W / cols
			var ch := (H - top) / rows
			b.vent = float(b.vent) + dt
			if float(b.vent) > float(D.every):
				b.vent = 0.0
				_lava_add(b, 1, int(floorf(rows * 0.5)), float(D.pour))
			b.acc = float(b.acc) + dt
			var loops := 0
			while float(b.acc) >= float(D.tick) and loops < 4:
				b.acc = float(b.acc) - float(D.tick)
				loops += 1
				_lava_step(b)
			var am: Array = b.am
			var age: Array = b.age
			var embers: Array = b.embers
			var hot := 0
			for i in N:                                  # still ages: moving → crust → cold rock, out of the simulation
				if float(am[i]) < 0.02:
					continue
				age[i] = float(age[i]) + dt
				if float(age[i]) > crust + cool:
					am[i] = 0.0
					age[i] = 0.0
					continue
				var q := clampf(float(age[i]) / crust, 0.0, 1.0)
				if q < 0.5:
					hot += 1
				if q < 0.4 and randf() < 0.02:
					var e: Dictionary = embers[randi_range(0, embers.size() - 1)]
					if float(e.life) <= 0.0:
						e.x = (i % cols) * cw + cw / 2.0
						e.y = top + int(i / float(cols)) * ch
						e.vy = -H * randf_range(0.15, 0.35)
						e.life = 1.0
			b.hot = hot
			for k in embers.size():
				var e: Dictionary = embers[k]
				if float(e.life) <= 0.0:
					continue
				e.life = float(e.life) - dt * 0.8
				e.y = float(e.y) + float(e.vy) * dt
				e.x = float(e.x) + Kit.noise(float(e.y) * 0.05 + k) * 20.0 * dt
		"cloudshadow":
			var sc: float = D.scale
			var speed: float = D.speed
			var wk: float = D.windk
			var wc: float = float(D.winddamp) * 2.0 * sqrt(wk)
			var ax: float = b.ax
			var ay: float = b.ay
			var wx: float = b.wx
			var wy: float = b.wy
			var vx: float = b.vx
			var vy: float = b.vy
			var ox: float = b.ox
			var oy: float = b.oy
			# two springs toward the aim, symplectic, substepped to ≤ 0.02 s (the
			# lexicon's Substep); the offsets integrate the wind inside the same loop
			var sub := maxi(1, ceili(dt * 50.0))
			var h := dt / float(sub)
			for _s in sub:
				vx += (wk * (ax - wx) - wc * vx) * h
				vy += (wk * (ay - wy) - wc * vy) * h
				wx = clampf(wx + vx * h, -3.0, 3.0)
				wy = clampf(wy + vy * h, -3.0, 3.0)
				ox += wx * speed * h / sc
				oy += wy * speed * h / sc
			b.wx = wx
			b.wy = wy
			b.vx = vx
			b.vy = vy
			b.ox = ox
			b.oy = oy

# ---------------------------------------------------------------- draw

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	var D: Dictionary = b.D
	var W: float = b.w
	var H: float = b.h
	var GY: float = b.gy
	var S: float = H / 170.0
	var origin: Vector2 = (b.rect as Rect2).position
	var INK := Kit.INK
	match b.id:
		"wavesprings":
			Kit.stage(n, b, 0.15)
			var nn: int = D.n
			var rest: float = H * float(D.level)
			var dx: float = W / (nn - 1)
			var ys: Array = b.ys
			var vs: Array = b.vs
			for p: Dictionary in b.drops:
				Kit.dot(n, Vector2(float(p.x), float(p.y)), 2.5, INK)
			var surf := PackedVector2Array()
			for i in nn:
				surf.append(Vector2(i * dx, rest + float(ys[i])))
			var body := PackedVector2Array(surf)          # the water body under the surface
			body.append(Vector2(W, H))
			body.append(Vector2(0.0, H))
			n.draw_colored_polygon(body, Color(0.31, 0.64, 0.85, 0.55))
			n.draw_polyline(surf, Color(0.91, 0.898, 0.957, 0.7), 1.5)
			_dashed_h(n, 0.0, W, rest, _with_a(INK, 0.25))
			for i in nn:                                 # the springs: brighter where they move faster
				Kit.dot(n, Vector2(i * dx, rest + float(ys[i])), 1.7, _with_a(Kit.SUN, 0.45 + clampf(absf(float(vs[i])) / (H * 0.6), 0.0, 0.55)))
			Kit.label(n, b, "k %s · c %s · spread %s · %s springs" % [str(D.tension), str(D.damping), str(D.spread), str(nn)], Vector2(W / 2.0, 14.0), FAINT, true)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"jetsam":
			Kit.stage(n, b, 0.1)
			var floats: Array = b.floats
			for f: Dictionary in floats:                 # the bodies, tilted to the local slope
				var fx: float = f.x
				var fy: float = f.y
				var fw: float = f.w
				var fh: float = f.h
				var sl := atan2(_surf(b, fx + 6.0, t) - _surf(b, fx - 6.0, t), 12.0)
				if f.kind == "hero":
					Kit.hero(n, b, Vector2(fx, fy), { "face": int(f.face), "pose": "jump" if float(f.vy) < -H * 0.1 else "stand", "frame": t, "rot": sl * 0.4 })
					continue
				n.draw_set_transform(origin + Vector2(fx, fy), sl * 0.7, Vector2.ONE)
				if f.kind == "crate":
					Kit.crate(n, Vector2.ZERO, fw)
				else:
					n.draw_rect(Rect2(-fw / 2.0, -fh, fw, fh), Color("7A5230"))
					n.draw_rect(Rect2(-fw / 2.0, -fh * 0.78, fw, 2.0), Kit.BONE)
					n.draw_rect(Rect2(-fw / 2.0, -fh * 0.28, fw, 2.0), Kit.BONE)
				n.draw_set_transform(origin, 0.0, Vector2.ONE)
			var surf := PackedVector2Array()             # the water over them: what is below the line reads as submerged
			var x := 0.0
			while x <= W:
				surf.append(Vector2(x, _surf(b, x, t)))
				x += 4.0
			var body := PackedVector2Array(surf)
			body.append(Vector2(W, H))
			body.append(Vector2(0.0, H))
			n.draw_colored_polygon(body, Color(0.31, 0.64, 0.85, 0.5))
			n.draw_polyline(surf, Color(0.91, 0.898, 0.957, 0.65), 1.5)
			for f: Dictionary in floats:                 # the depth each float reads, as a tick
				var fx: float = f.x
				var hs := _surf(b, fx, t)
				var depth := clampf(float(f.y) - hs, 0.0, float(f.h))
				if depth > 0.5:
					n.draw_line(Vector2(fx + float(f.w) / 2.0 + 3.0, hs), Vector2(fx + float(f.w) / 2.0 + 3.0, hs + depth), _with_a(INK, 0.6), 1.0)
			Kit.label(n, b, "density %s · push %s · %d floats" % [str(D.density), str(D.push), floats.size()], Vector2(W / 2.0, 14.0), FAINT, true)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"waterline":
			Kit.stage(n, b, 0.05)
			var sx: float = W * float(D.shore)
			var low_y: float = H * 0.97
			var r: float = b.r
			var level: float = b.level
			var edge: float = b.edge
			var foam: float = b.foam
			var v: float = b.v
			var fr: float = b.fr
			var rest: float = b.rest
			var fx := sx * fr                            # the foam line sits on the sand, wherever it has got to
			var fy := low_y + (GY - low_y) * fr
			var dry: float = D.dry
			n.draw_colored_polygon(PackedVector2Array([Vector2(0.0, low_y), Vector2(sx, GY), Vector2(W, GY), Vector2(W, H), Vector2(0.0, H)]), Color(D.sand))   # the beach: the slope, then the flat
			var cols: int = D.cols
			var cw := sx / cols
			var last: Array = b.lastT
			var wet := Color(D.wet)
			for c in cols:                               # the wet memory, column by column
				var a := clampf(1.0 - (t - float(last[c])) / dry, 0.0, 1.0) * 0.6
				if a <= 0.0:
					continue
				var x0 := c * cw
				var x1 := x0 + cw
				n.draw_colored_polygon(PackedVector2Array([Vector2(x0, _sand_y(b, x0)), Vector2(x1 + 0.5, _sand_y(b, x1)),
					Vector2(x1 + 0.5, _sand_y(b, x1) + 7.0), Vector2(x0, _sand_y(b, x0) + 7.0)]), _with_a(wet, a))
			var sea := PackedVector2Array([Vector2(0.0, level)])   # the sea: a level cut off by the slope
			var x := 0.0
			while x <= edge:
				sea.append(Vector2(x, level + sin(x * 0.08 - t * 3.0) * 1.2 * (1.0 - x / maxf(edge, 1.0))))
				x += 4.0
			sea.append(Vector2(edge, level))
			sea.append(Vector2(0.0, low_y))
			n.draw_colored_polygon(sea, _with_a(Color(D.sea), 0.78))
			n.draw_line(Vector2(fx, fy), Vector2(edge, level), _with_a(INK, 0.25 + foam * 0.7), 1.0 + foam * 3.0)   # the foam line: from where the froth is to the water's edge
			for k in 5:
				Kit.dot(n, Vector2(fx - k * 5.0 - 2.0, fy - 1.0 + sin(t * 5.0 + k) * 1.2), 1.2 + foam * 1.5, _with_a(INK, 0.5 + foam * 0.5))
			Kit.hero(n, b, Vector2(W * 0.82, GY), { "face": -1, "pose": "stand", "frame": t })
			n.draw_line(Vector2(edge, level), Vector2(edge, H * 0.3), _with_a(INK, 0.18), 1.0)   # the edge's x, read off the slope
			n.draw_line(Vector2(sx * rest, low_y + (GY - low_y) * rest), Vector2(sx * rest, H * 0.34), _with_a(INK, 0.1), 1.0)   # and the rest it is springing toward
			Kit.label(n, b, "level %d%% · r' %s%.2f · foam %d%%" % [roundi(r * 100.0), "+" if v >= 0.0 else "", v, roundi(foam * 100.0)], Vector2(edge, H * 0.28), FAINT, true)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"puddle":
			Kit.stage(n, b, float(D.night))
			var lx := W * 0.68
			var hx := W * 0.5 + sin(t * 0.5) * W * 0.3
			var face := -1 if cos(t * 0.5) < 0.0 else 1
			var f := floorf(fmod(t * 10.0, 7.0)) * 0.1     # the run frame, quantised as the web's sprite cache is
			Kit.tree(n, Vector2(W * 0.12, GY), H * 0.32)
			Kit.lamp(n, b, Vector2(lx, GY), true)
			var puddles: Array = D.puddles
			var rings: Array = b.rings
			var wobble: float = D.wobble
			var sheen: float = D.sheen
			var ref_a: float = D.refA
			var ring_life: float = D.ringLife
			var rain: bool = bool(b.rain)
			var lamp_h := H * 0.3
			for k in puddles.size():
				var P: Array = puddles[k]
				var px := W * float(P[0])
				var py := GY + H * float(P[1])
				var rx := W * float(P[2])
				var ry := H * float(P[3])
				var pts := PackedVector2Array()          # the sky, upside down: the ellipse itself carries the gradient
				var cols := PackedColorArray()
				for i in 32:
					var a := i / 32.0 * TAU
					var pt := Vector2(px + cos(a) * rx, py + sin(a) * ry)
					pts.append(pt)
					cols.append(Color(0.47, 0.59, 0.78, 0.55).lerp(Color(0.157, 0.196, 0.353, 0.8), (pt.y - (py - ry)) / (2.0 * ry)))
				n.draw_polygon(pts, cols)
				var sway := sin(t * 3.0 + k) * wobble
				if absf(lx - px) < rx:                   # the lamp post's reflection: the flipped post, clipped to the ellipse's height at x
					var dyv := ry * sqrt(1.0 - pow((lx - px) / rx, 2.0))
					var y0 := maxf(py - dyv, GY)
					var y1 := minf(py + dyv, GY + lamp_h)
					if y1 > y0:
						n.draw_rect(Rect2(lx - 2.0 + sway, y0, 4.0, y1 - y0), _with_a(Color("3A3355"), ref_a))
				_hero_reflect(n, b, hx, sway, face, f, Vector2(px, py), rx, ry, ref_a)   # the flip about the ground line
				if sheen > 0.0:                          # petrol: hue bands from a noise field ("screen" ≈ light colours at alpha)
					var bw := maxf(3.0, rx / 8.0)
					var x := px - rx
					while x < px + rx:
						var nz := Kit.noise2(x / (rx * 0.6) + k * 3.0, t * 0.15)
						var hue := fmod((nz * 0.5 + 0.5) * 300.0 + t * 20.0, 360.0)
						var xc := x + bw * 0.5
						if absf(xc - px) < rx:
							var dyv := ry * sqrt(1.0 - pow((xc - px) / rx, 2.0))
							n.draw_rect(Rect2(x, py - dyv, bw + 0.5, dyv * 2.0), Color.from_hsv(hue / 360.0, 0.75, 1.0, sheen * 0.45))
						x += bw
				for rg: Dictionary in rings:             # rings squashed by the puddle's aspect
					if int(rg.p) != k or float(rg.age) >= ring_life:
						continue
					var q := float(rg.age) / ring_life
					var rr := q * rx * 0.45
					_ellipse_stroke(n, Vector2(px + float(rg.ox) * rx, py + float(rg.oy) * ry), maxf(0.5, rr), maxf(0.3, rr * ry / rx), _with_a(INK, (1.0 - q) * 0.7))
				_ellipse_stroke(n, Vector2(px, py), rx, ry, Color(0.91, 0.898, 0.957, 0.18))
			Kit.hero(n, b, Vector2(hx, GY), { "face": face, "pose": "run", "frame": f })
			if rain:                                     # streaks: clock-driven, so a skip costs nothing
				for i in 28:
					var x := fmod(fmod(i * 137.5, W) + t * 30.0, W)
					var y := fmod(i * 71.3 + t * H * 2.2, H + 20.0) - 10.0
					n.draw_line(Vector2(x, y), Vector2(x - 2.0, y + H * 0.05), Color(0.78, 0.86, 1.0, 0.35), 1.0)
			var top := "rain on · %s rings/s" % str(D.rate) if rain else ("no rain · oil sheen %s" % str(sheen) if sheen > 0.0 else "rain off")
			Kit.label(n, b, top, Vector2(W / 2.0, 14.0), FAINT, true)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"lens":
			Kit.stage(n, b, 0.25)
			Kit.tree(n, Vector2(W * 0.15, GY), H * 0.3)
			Kit.lamp(n, b, Vector2(W * 0.8, GY), true)
			Kit.hero(n, b, Vector2(W * 0.5 + sin(t * 0.7) * W * 0.2, GY), { "face": -1 if cos(t * 0.7) < 0.0 else 1, "pose": "run", "frame": t })
			var snowing: bool = str(D.kind) == "snow"
			if snowing:                                  # falling flakes / rain streaks in the scene, clock-driven
				for i in 30:
					Kit.dot(n, Vector2(fmod(fmod(i * 97.3, W) + sin(t + i) * 8.0 + W, W), fmod(i * 53.7 + t * H * 0.25, H + 10.0) - 5.0), 1.3 * S, Color(0.94, 0.94, 1.0, 0.7))
			else:
				for i in 30:
					var x := fmod(i * 137.5, W)
					var y := fmod(i * 71.3 + t * H * 2.5, H + 20.0) - 10.0
					n.draw_line(Vector2(x, y), Vector2(x - 2.0, y + H * 0.06), Color(0.78, 0.86, 1.0, 0.3), 1.0)
			var wipe: float = b.wipe
			if wipe >= 0.0:                              # the wiper's sector and arm
				var a := -PI * 0.92 + PI * 0.84 * clampf(wipe, 0.0, 1.0)
				var pv := _piv(b)
				var a0 := maxf(a - 0.35, -PI * 0.92)
				var fan := PackedVector2Array([pv])
				for i in 9:
					var q := a0 + (a - a0) * i / 8.0
					fan.append(pv + Vector2(cos(q), sin(q)) * H)
				if a > a0:
					n.draw_colored_polygon(fan, Color(1.0, 1.0, 1.0, 0.05))
				n.draw_line(pv, pv + Vector2(cos(a), sin(a)) * H, Color("2B2440"), 4.0 * S)
			var melt: float = D.melt
			var drops: Array = b.drops
			for d: Dictionary in drops:                  # draw: each drop is a small bead of the flipped scene
				var r := maxf(0.6, float(d.r))
				var c := Vector2(float(d.x), float(d.y))
				if float(d.flake) > 0.0:
					n.draw_circle(c, r, _with_a(Color("F4F6FF"), clampf(float(d.flake) / melt, 0.3, 1.0)))
					continue
				var pts := PackedVector2Array()          # ground-dark at the top, sky-light at the bottom: the lens flips the view
				var cols := PackedColorArray()
				for i in 16:
					var a := i / 16.0 * TAU
					pts.append(c + Vector2(cos(a), sin(a)) * r)
					cols.append(Color(0.16, 0.2, 0.18, 0.6).lerp(Color(0.72, 0.82, 0.98, 0.55), (sin(a) + 1.0) * 0.5))
				n.draw_polygon(pts, cols)
				n.draw_arc(c, r, -2.4, -1.0, 8, Color(1.0, 1.0, 1.0, 0.35), 0.8)   # a highlight arc
			Kit.label(n, b, "%s · %d drops · run above r %s" % [str(D.kind), drops.size(), str(D.slideR)], Vector2(W / 2.0, 14.0), FAINT, true)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"yeti":
			Kit.stage(n, b, 0.1)
			var P: Array = SAND_PAL if str(D.surface) == "sand" else SNOW_PAL
			var cols: int = D.cols
			var rows: int = D.rows
			var band := H - GY
			var cw := W / cols
			var ch := band / rows
			var fade: float = D.fade
			var refill: float = D.refill
			var field: Array = b.field
			n.draw_rect(Rect2(0.0, GY, W, band), P[0])   # the surface, then the field painted by depth
			for r in rows:
				for c in cols:
					var v: float = field[r * cols + c]
					if v <= 0.01:
						continue
					n.draw_rect(Rect2(c * cw, GY + r * ch, cw + 0.5, ch + 0.5), _with_a(P[1], v * 0.75))
			for pr: Dictionary in b.prints:              # the prints: ovals along the heading
				var a := clampf(1.0 - float(pr.age) / fade, 0.0, 1.0) * 0.55
				if a <= 0.0:
					continue
				_ellipse_rot(n, Vector2(float(pr.x), float(pr.y)), 3.2, 1.8, float(pr.a), _with_a(P[2], a))
			if refill > 0.0:                             # blown sand, clock-driven
				for i in 14:
					var x := fmod(i * 91.7 + t * W * 0.6, W + 30.0) - 15.0
					var y := GY + fmod(i * 37.1, band)
					n.draw_line(Vector2(x, y), Vector2(x + 12.0, y - 1.0), _with_a(P[0], 0.5), 1.0)
			n.draw_line(Vector2(0.0, GY), Vector2(W, GY), Color(0.075, 0.063, 0.125, 0.25), 1.0)
			Kit.hero(n, b, Vector2(float(b.hx), float(b.hy)), { "face": int(b.face), "pose": "run", "frame": t })
			var trod := 0
			for v in field:
				if float(v) > 0.05:
					trod += 1
			n.draw_polygon(PackedVector2Array([Vector2(W - 70.0, 8.0), Vector2(W - 10.0, 8.0), Vector2(W - 10.0, 14.0), Vector2(W - 70.0, 14.0)]),
				PackedColorArray([P[0], P[1], P[1], P[0]]))   # the depth scale
			_label_right(n, b, "0", Vector2(W - 72.0, 22.0))
			_label_right(n, b, "1 trodden", Vector2(W - 8.0, 22.0))
			var info := "%s · %d cells marked" % [str(D.surface), trod]
			if refill > 0.0:
				info += " · refill %s/s" % str(refill)
			Kit.label(n, b, info, Vector2(8.0, 14.0))
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"quiver":
			Kit.stage(n, b, 0.12)
			var hx: float = b.hx
			var height: float = D.height
			var wind_speed: float = D.windSpeed
			var blades: Array = b.blades
			var J: int = b.J
			var tj: PackedFloat32Array = b.tj
			for i in blades.size():                      # reeds behind the hero first
				var bl: Dictionary = blades[i]
				if float(bl.x) < hx - 4.0:
					_blade(n, bl, tj, i, J, GY, H * 0.28 * height * float(bl.h))
			Kit.hero(n, b, Vector2(hx, GY), { "face": int(b.face), "pose": "run", "frame": t })
			for i in blades.size():                      # then the rest, in front
				var bl: Dictionary = blades[i]
				if float(bl.x) >= hx - 4.0:
					_blade(n, bl, tj, i, J, GY, H * 0.28 * height * float(bl.h))
			var graph := PackedVector2Array()            # the wind noise, as a graph
			var x := 0.0
			while x <= W:
				graph.append(Vector2(x, H * 0.12 - Kit.noise(t * wind_speed + x / W * 3.0) * H * 0.04))
				x += 6.0
			n.draw_polyline(graph, _with_a(INK, 0.3), 1.0)
			Kit.label(n, b, "wind", Vector2(4.0, H * 0.12 - 4.0))
			var m := clampf(float(b.rustle) / 2.5, 0.0, 1.0)   # the rustle meter
			n.draw_rect(Rect2(W - 66.0, 8.0, 58.0, 6.0), _with_a(INK, 0.15))
			n.draw_rect(Rect2(W - 66.0, 8.0, 58.0 * m, 6.0), _with_a(Kit.GOOD if m > 0.36 else INK, 0.8))
			_label_right(n, b, "rustle", Vector2(W - 8.0, 22.0))
			if J > 1:
				Kit.label(n, b, "%d segs · joints k ×%s · damp %s of their own critical" % [J, str(D.tip), str(D.tipdamp)], Vector2(8.0, H - 20.0), Kit.DIM)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"updraft":
			Kit.stage(n, b, 0.1)
			Kit.tree(n, Vector2(W * 0.9, GY), H * 0.3)
			var zones: Array = D.zones
			var e := _env(D, t - float(b.gustAt))
			var idle: float = D.idle
			var g := idle + (1.0 - idle) * e
			for z: Dictionary in zones:                  # the zones and their arrow fields
				var zr := Rect2(float(z.x) * W, float(z.y) * H, float(z.w) * W, float(z.h) * H)
				n.draw_rect(zr, _with_a(Kit.GOOD if float(z.dy) < 0.0 else Kit.SUN, 0.06 + g * 0.08))
				n.draw_rect(zr, _with_a(INK, 0.15), false, 1.0)
				var nx := maxi(1, roundi(zr.size.x / 34.0))
				var ny := maxi(1, roundi(zr.size.y / 30.0))
				var al := 6.0 + g * 12.0
				var dir := Vector2(float(z.dx), float(z.dy))
				for i in nx:
					for j in ny:
						var ac := zr.position + Vector2((i + 0.5) / nx * zr.size.x, (j + 0.5) / ny * zr.size.y)
						Kit.arrow(n, ac - dir * al / 2.0, ac + dir * al / 2.0, _with_a(INK, 0.25 + g * 0.4))
			for p: Dictionary in b.parts:                # debris under the field
				var c := Vector2(float(p.x), float(p.y))
				if bool(p.leaf):
					var ang := float(p.vx) * 0.02 + float(p.s) * 6.0
					var ux := Vector2(cos(ang), sin(ang)) * 3.0
					var uy := Vector2(-sin(ang), cos(ang)) * 1.5
					n.draw_colored_polygon(PackedVector2Array([c - ux - uy, c + ux - uy, c + ux + uy, c - ux + uy]), Color("D89A4A") if float(p.s) < 0.5 else Color("B8643A"))
				else:
					Kit.dot(n, c, 1.0, _with_a(Kit.BONE, 0.5))
			var hy: float = b.hy
			Kit.hero(n, b, Vector2(float(b.hx), hy), { "face": int(b.face), "pose": "jump" if hy < GY - 2.0 else "run", "frame": t })
			var gx := W - 78.0                           # the envelope, with a playhead
			var gy0 := 8.0
			var gw := 70.0
			var gh := 26.0
			var at: float = D.attack
			var su: float = D.sustain
			var re: float = D.release
			var total := at + su + re
			n.draw_rect(Rect2(gx, gy0, gw, gh), Color(0.075, 0.063, 0.125, 0.55))
			n.draw_polyline(PackedVector2Array([Vector2(gx, gy0 + gh), Vector2(gx + gw * at / total, gy0 + 2.0),
				Vector2(gx + gw * (at + su) / total, gy0 + 2.0), Vector2(gx + gw, gy0 + gh)]), _with_a(Kit.SUN, 0.9), 1.2)
			var age := t - float(b.gustAt)
			if age >= 0.0 and age <= total:
				var px := gx + gw * age / total
				n.draw_line(Vector2(px, gy0), Vector2(px, gy0 + gh), INK, 1.0)
			_label_right(n, b, "A %s S %s R %s" % [str(at), str(su), str(re)], Vector2(gx + gw, gy0 + gh + 11.0))
			Kit.label(n, b, "gust %d%%" % roundi(e * 100.0), Vector2(8.0, 14.0))
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"year":
			var year: float = D.year
			var fall_dur: float = D.fallDur
			var swings: float = D.swings
			var settle: float = D.settle
			var p := fposmod(t / year + float(b.shift), 1.0)
			var snow := _ease((p - 0.75) / 0.14) if p > 0.75 else (_ease(1.0 - p / 0.09) if p < 0.09 else 0.0)   # settles late, melts early
			var cold := _ease((p - 0.7) / 0.1) if p > 0.7 else (_ease(1.0 - p / 0.1) if p < 0.1 else 0.0)
			Kit.stage(n, b, 0.08 + cold * 0.22)
			var white := Color("F0F2FA")
			var bark := Color("5A3E2B")
			var tx := W * 0.32
			var cr := H * 0.2
			n.draw_rect(Rect2(0.0, GY, W, H - GY), _with_a(white, snow * 0.92))   # snow on the ground
			n.draw_rect(Rect2(tx - cr * 0.09, GY - cr * 1.3, cr * 0.18, cr * 1.3), bark)   # trunk and three branches
			n.draw_line(Vector2(tx, GY - cr * 1.1), Vector2(tx - cr * 0.7, GY - cr * 1.7), bark, 3.0)
			n.draw_line(Vector2(tx, GY - cr * 1.2), Vector2(tx + cr * 0.75, GY - cr * 1.75), bark, 3.0)
			n.draw_line(Vector2(tx, GY - cr * 1.3), Vector2(tx, GY - cr * 2.1), bark, 3.0)
			var cy := GY - cr * 1.7
			var sway_a := 9.0 * S
			var bud := _mix(Color("9BE28A"), Color("E2F5A0"), 0.4)
			for L: Dictionary in b.leaves:
				var size := _ease(p / 0.2) if p < 0.2 else 1.0                          # buds grow through spring
				var turn := clampf((p - float(L.turn)) / 0.14, 0.0, 1.0)                 # green → orange → red
				var colr := _mix(Kit.GOOD, Kit.SUN, turn * 2.0) if turn < 0.5 else _mix(Kit.SUN, Kit.HOT, (turn - 0.5) * 2.0)
				var q := clampf((p - float(L.fallAt)) / fall_dur, 0.0, 1.0)              # falling: canopy → ground
				if p < 0.02 and q > 0.0:
					continue
				var ph: float = L.ph
				var sway := exp(-settle * q) * (sin(TAU * swings * q + ph) - sin(ph))   # the damped oscillation, written out: zero at release, dying by the ground
				var sx := tx + float(L.ox) + sway * sway_a + float(L.landX) * q
				var sy := cy + float(L.oy) + (GY - 2.0 - (cy + float(L.oy))) * q * q     # q²: it accelerates
				var litter := q >= 1.0
				if litter and p < 0.4:                                                   # last year's litter is gone by mid-spring
					continue
				var a := clampf(1.0 - snow * 1.2, 0.0, 1.0) * 0.8 if litter else 1.0
				if a <= 0.0:
					continue
				var rr := (2.2 + float(L.hue) * 1.6) * size * S
				Kit.ellipse(n, Vector2(sx, sy), rr, rr * (0.5 if litter else 0.8), _with_a(bud if p < 0.2 else colr, a))
			if snow > 0.05:                              # snow caps on the branches
				n.draw_line(Vector2(tx - cr * 0.7, GY - cr * 1.72), Vector2(tx, GY - cr * 1.14), _with_a(white, snow), 3.0 * snow)
				n.draw_line(Vector2(tx, GY - cr * 1.24), Vector2(tx + cr * 0.75, GY - cr * 1.79), _with_a(white, snow), 3.0 * snow)
			if p > 0.76 or p < 0.03:                     # falling flakes, clock-driven
				var nf := roundi(30.0 * float(D.snow))
				for i in nf:
					Kit.dot(n, Vector2(fmod(fmod(i * 97.3, W) + sin(t + i) * 10.0 + W, W), fmod(i * 53.7 + t * H * 0.2, H + 10.0) - 5.0), 1.3, Color(0.94, 0.95, 0.98, 0.8))
			Kit.hero(n, b, Vector2(W * 0.7, GY), { "face": -1, "pose": "stand", "frame": t })
			var rc := Vector2(W - 26.0, 26.0)            # the year ring
			var rr := 16.0
			for k in 4:
				n.draw_arc(rc, rr, -PI / 2.0 + k * PI / 2.0, -PI / 2.0 + (k + 1) * PI / 2.0 - 0.05, 16, _with_a(YEAR_RING[k], 0.7), 4.0)
			n.draw_line(rc, rc + Vector2(cos(p * TAU - PI / 2.0), sin(p * TAU - PI / 2.0)) * rr, INK, 1.5)
			Kit.label(n, b, "%s · %d%%" % [SEASONS[int(p * 4.0) % 4], roundi(p * 100.0)], Vector2(rc.x, rc.y + rr + 12.0), FAINT, true)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"unfurl":
			Kit.stage(n, b, 0.05)
			var age := (t - float(b.t0)) * float(D.speed)
			var sc: float = H * 0.72 / float(b.born)
			var segs: Array = b.segs
			var total: int = b.total
			var grow: float = D.grow
			var plants: int = D.plants
			var prog := clampf(age / grow, 0.0, 1.0)
			var nseg := int(floorf(prog * total))
			var frac := prog * total - nseg
			for k in plants:                             # the fern(s): segments revealed in order
				var bx := W * (0.66 if plants == 1 else 0.4 + 0.5 * k / (plants - 1))
				for i in mini(nseg + 1, total):
					var sg: Array = segs[i]
					var f := 1.0 if i < nseg else frac
					var lv: int = sg[4]
					n.draw_line(Vector2(bx + float(sg[0]) * sc, GY + float(sg[1]) * sc),
						Vector2(bx + (float(sg[0]) + (float(sg[2]) - float(sg[0])) * f) * sc, GY + (float(sg[1]) + (float(sg[3]) - float(sg[1])) * f) * sc),
						_mix(Color("3E7A48"), Kit.GOOD, lv / 4.0), maxf(0.8, 3.0 - lv * 0.6))
				if nseg < total:                         # the growing tip
					var sg: Array = segs[nseg]
					Kit.dot(n, Vector2(bx + float(sg[0]) * sc, GY + float(sg[1]) * sc), 2.0, Kit.SUN)
			var px := W * 0.22                           # the pot plant: three tweens
			var ST: Array = D.stages
			var s0: float = ST[0]
			var s1t: float = ST[1]
			var s2t: float = ST[2]
			n.draw_rect(Rect2(px - 14.0, GY - 16.0, 28.0, 16.0), Color("7A5230"))
			n.draw_rect(Rect2(px - 12.0, GY - 16.0, 24.0, 4.0), Color("3A2A20"))
			var e1 := _ease(age / s0)
			var e2 := _ease((age - s0) / (s1t - s0))
			var e3 := _ease((age - s1t) / (s2t - s1t))
			var stem_h := H * 0.2 * e1 + H * 0.12 * e2
			Kit.dot(n, Vector2(px, GY - 14.0), 3.0 * (1.0 - e1) + 1.0, Color("9A7A40"))
			n.draw_line(Vector2(px, GY - 14.0), Vector2(px, GY - 14.0 - stem_h), Color("3E7A48"), 2.5)
			for k in 2:                                  # two leaves unfold in stage two
				var ly := GY - 14.0 - stem_h * 0.55
				var dir := 1.0 if k == 1 else -1.0
				var ll := 14.0 * e2
				_ellipse_rot(n, Vector2(px + dir * ll * 0.6, ly), maxf(0.1, ll * 0.6), maxf(0.1, 4.0 * e2), dir * 0.5, Kit.GOOD)
			for k in 6:                                  # the bloom: petals scale in stage three
				var a := k / 6.0 * TAU + t * 0.2
				var prr := 7.0 * e3
				Kit.dot(n, Vector2(px + cos(a) * prr, GY - 14.0 - stem_h + sin(a) * prr), maxf(0.1, 4.0 * e3), Kit.HOT)
			Kit.dot(n, Vector2(px, GY - 14.0 - stem_h), 3.0 * e3 + 0.1, Kit.SUN)
			var stage_name := "seed" if age < s0 else ("sprout" if age < s1t else ("leaves" if age < s2t else "bloom"))
			var bw := W * 0.3                            # the stage bar
			var bx0 := px - bw / 2.0
			var by0 := H * 0.1
			n.draw_rect(Rect2(bx0, by0, bw, 5.0), _with_a(INK, 0.12))
			n.draw_rect(Rect2(bx0, by0, bw * clampf(age / s2t, 0.0, 1.0), 5.0), _with_a(Kit.SUN, 0.8))
			for sv in ST:
				var mx := bx0 + bw * float(sv) / s2t
				n.draw_line(Vector2(mx, by0 - 2.0), Vector2(mx, by0 + 7.0), _with_a(INK, 0.5), 1.0)
			Kit.label(n, b, "%s · %.1f s" % [stage_name, age], Vector2(px, by0 + 18.0), FAINT, true)
			Kit.label(n, b, "F → %s · θ %s° · depth %d · %d/%d" % [str(D.rule), str(D.angle), clampi(roundi(float(D.depth)), 1, 5), mini(total, nseg), total], Vector2(W * 0.66, H * 0.1 + 4.0), FAINT, true)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"kindle":
			Kit.stage(n, b, 0.2)
			var cols: int = D.cols
			var rows: int = D.rows
			var top := GY - H * 0.22
			var cw := W / cols
			var ch := (H - top) / rows
			var burn: float = D.burn
			var regrow: float = D.regrow
			var st: Array = b.st
			var tm: Array = b.tm
			var hue: Array = b.hue
			var grass := Color("4E8A3E")
			for r in rows:                               # paint the grid by state
				for c in cols:
					var i := r * cols + c
					var x := c * cw
					var y := top + r * ch
					var hv: float = hue[i]
					var cell := Rect2(x, y, cw + 0.5, ch + 0.5)
					var state: int = st[i]
					if state == 0:
						n.draw_rect(cell, _mix(grass, Kit.GOOD, hv * 0.35))
					elif state == 1:
						var f: float = float(tm[i]) / burn
						n.draw_rect(cell, _mix(Kit.FIRE, Kit.SPARK, 0.5 + 0.5 * sin(t * 17.0 + hv * 30.0)))
						n.draw_rect(cell, _with_a(Color("2A1A10"), 1.0 - f))
						var fh := ch * (0.6 + 0.4 * sin(t * 23.0 + hv * 50.0))
						n.draw_colored_polygon(PackedVector2Array([Vector2(x + cw * 0.2, y + ch), Vector2(x + cw * 0.5, y + ch - fh), Vector2(x + cw * 0.8, y + ch)]), _with_a(Kit.SPARK, 0.8))
					else:
						var f: float = float(tm[i]) / regrow
						n.draw_rect(cell, _mix(grass, Color("3A3A3E"), clampf(f * 1.4, 0.0, 1.0)))
			var wd := float(D.windDir) * PI / 180.0       # the wind and its odds
			var wv := Vector2(cos(wd), sin(wd))
			var ac := Vector2(W - 30.0, 22.0)
			Kit.arrow(n, ac - wv * 14.0, ac + wv * 14.0, INK)
			var spread: float = D.spread
			var wind: float = D.wind
			Kit.label(n, b, "wind %s" % str(wind), Vector2(ac.x, ac.y + 20.0), FAINT, true)
			Kit.label(n, b, "p→ %.2f · p← %.2f · p↕ %.2f" % [spread * (1.0 + wind), spread * (1.0 - wind), spread], Vector2(8.0, 14.0))
			Kit.label(n, b, "%d burning · burn %s s%s" % [int(b.burning), str(burn), (" · ash %s s" % str(regrow)) if bool(D.ash) else " · no ash"], Vector2(8.0, 27.0))
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"lava":
			Kit.stage(n, b, 0.6)
			var cols: int = D.cols
			var rows: int = D.rows
			var N := cols * rows
			var top := GY - H * 0.2
			var cw := W / cols
			var ch := (H - top) / rows
			var crust: float = D.crust
			var cool: float = D.cool
			var am: Array = b.am
			var age: Array = b.age
			var rock: Array = b.rock
			n.draw_rect(Rect2(0.0, top, W, H - top), Color("1E1A2A"))
			for i in N:
				var c := i % cols
				var r := int(i / float(cols))
				var cell := Rect2(c * cw, top + r * ch, cw + 0.5, ch + 0.5)
				n.draw_rect(cell, Color(0.0, 0.0, 0.0, float(rock[i])))   # the rock, darker downhill
				var ai: float = am[i]
				if ai < 0.02:
					continue
				var q := clampf(float(age[i]) / crust, 0.0, 1.0)
				var cl := clampf((float(age[i]) - crust) / cool, 0.0, 1.0)
				var colr := _mix(Kit.SPARK, Kit.FIRE, q / 0.4) if q < 0.4 else (_mix(Kit.FIRE, Color("7A1A10"), (q - 0.4) / 0.6) if q < 1.0 else _mix(Color("7A1A10"), Color("2A1E22"), cl))
				n.draw_rect(cell, _with_a(colr, clampf(0.5 + ai * 0.6, 0.0, 1.0)))
			for e: Dictionary in b.embers:
				if float(e.life) <= 0.0:
					continue
				Kit.dot(n, Vector2(float(e.x), float(e.y)), 1.2, _with_a(Kit.SPARK, clampf(float(e.life), 0.0, 1.0)))
			var heat := clampf(float(b.hot) / (N * 0.06), 0.0, 1.0)   # the haze: the web copies the band above out in strips pushed by
			if heat > 0.02:                                            # noise; without a layer, faint warm strips carry the same offsets
				var hy := top - H * 0.16
				var hh := H * 0.2
				var y := hy
				while y < hy + hh:
					var k := (y - hy) / hh
					var off := Kit.noise(y * 0.08 + t * 3.5) * 4.0 * heat * k
					n.draw_rect(Rect2(off, y, W, 3.0), _with_a(Kit.SPARK, 0.05 * heat * k))
					y += 3.0
			Kit.label(n, b, "%d cells moving · crust after %s s · flow %s" % [int(b.hot), str(crust), str(D.flow)], Vector2(8.0, 14.0))
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"cloudshadow":
			Kit.stage(n, b, 0.05)
			var sc: float = float(D.scale) * W
			var ox: float = b.ox
			var oy: float = b.oy
			for i in 26:                                 # clouds: the field sampled along the sky band
				var cx := (i + 0.5) / 26.0 * W
				for j in 3:
					var m := _mask(D, cx / sc + ox, 0.5 + j * 0.15 + oy)
					if m <= 0.05:
						continue
					n.draw_circle(Vector2(cx, H * (0.12 + j * 0.05)), (6.0 + m * 9.0) * S, Color(0.957, 0.957, 1.0, 0.35 + m * 0.5))
			Kit.tree(n, Vector2(W * 0.15, GY), H * 0.3)
			Kit.crate(n, Vector2(W * 0.78, GY), H * 0.11)
			Kit.hero(n, b, Vector2(W * 0.5 + sin(t * 0.5) * W * 0.2, GY), { "face": -1 if cos(t * 0.5) < 0.0 else 1, "pose": "run", "frame": t })
			var cols: int = D.cols
			var rows: int = D.rows
			var cw := W / cols
			var top := GY - H * 0.16
			var ch := (H - top) / rows
			var shades: Array = b.shades
			for r in rows:                               # the mask over the ground band (and the hero's feet)
				for c in cols:
					var x := c * cw
					var m := _mask(D, x / sc + ox, 0.5 + (r / float(rows)) * 0.45 + oy)
					if m <= 0.02:
						continue
					n.draw_rect(Rect2(x, top + r * ch, cw + 0.5, ch + 0.5), shades[roundi(m * 16.0)])
			var wx: float = b.wx
			var wy: float = b.wy
			var ax: float = b.ax
			var ay: float = b.ay
			Kit.arrow(n, Vector2(W - 40.0, 22.0), Vector2(W - 40.0 + ax * 22.0, 22.0 + ay * 22.0 / 0.4 * 0.6), _with_a(INK, 0.3))   # the aim, faint, and the wind where it has swung to
			Kit.arrow(n, Vector2(W - 40.0, 22.0), Vector2(W - 40.0 + wx * 22.0, 22.0 + wy * 22.0 / 0.4 * 0.6), INK)
			Kit.label(n, b, "wind %.2f" % sqrt(wx * wx + (wy / 0.4) * (wy / 0.4)), Vector2(W - 40.0, 40.0), FAINT, true)
			Kit.label(n, b, "thr %s · soft %s · dark %s" % [str(D.threshold), str(D.soft), str(D.dark)], Vector2(8.0, 14.0))
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
