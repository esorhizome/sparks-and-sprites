extends RefCounted

const Kit := preload("res://scenes/stage/kit.gd")
## SPRITE & MATERIAL SHADERS — thirteen skins, ported from the web almanac
## (docs/stagecraft.js, family "skin"). Nothing in this family moves the hero
## differently — it changes what the pixels ARE: brightness remapped through a
## palette (frozen, stone, gold, ghost), a tint whose alpha rides a wave
## (poisoned, burning, stunned), rows of the sprite slid sideways by a sine or
## by height (jelly, wind, grass), a mask borrowed from another shape (the
## X-ray silhouette, the wet-floor reflection, the sheared shadow), nearest
## versus bilinear and rotation snapped to steps, a panel cut into nine,
## lighting quantised into bands, water bending what lies behind it, and a
## hologram of scanlines and a dilated rim.
##
## The web spelled every one of these in canvas — strips, clips, composite
## operations and ImageData. Here the sprite IS a list of unit squares
## (Kit.hero_cells), so the painter does the pixel work directly: recolour a
## cell (gradient map, tints), slice a cell into strips (jelly, wet floor),
## draw the cells through a shear matrix (skew shadow), keep the cells that
## land inside a wall (X-ray), ring the cells that have no neighbour (rim,
## outline). One card reads the screen — Undersea's refraction — and that one
## is a canvas_item shader confined to the water (see shaders/stage/undersea.gdshader).

const TITLE := "Sprite & material shaders"
const BLURB := "the sprite's own skin — frozen and petrified, poisoned, jelly, swaying, X-rayed, reflected, sheared into a shadow, pixel-perfect, nine-sliced, toon-lined, under water, holographic"
const DEFS := [
	{ "id": "frozen", "letter": "F", "name": "Frozen",
		"hint": "GRADIENT MAP: each pixel's brightness picks a colour on a 4-stop palette, swept up from the feet — ch03's palette swap, per pixel — press to freeze / thaw",
		"dials": { "state": "frozen",     # frozen / petrified / gilded / ghost — a palette + an overlay each
			"states": { "frozen":    { "map": ["#16224E", "#3B7FC8", "#A8E4F8", "#FFFFFF"], "overlay": "frost",  "alpha": 1 },
				"petrified": { "map": ["#1A181C", "#4E4A52", "#8E8A90", "#DCD8D4"], "overlay": "cracks", "alpha": 1 },
				"gilded":    { "map": ["#4A2A08", "#B8781E", "#F2C25A", "#FFF4C0"], "overlay": "sheen",  "alpha": 1 },
				"ghost":     { "map": ["#2A3A5A", "#6A9AC8", "#C8E8F8", "#FFFFFF"], "overlay": "none",   "alpha": 0.45 } },
			"sweep": 1.2,               # seconds for the freeze line to climb from the feet to the hair
			"hold": 2.6,                # seconds held in the state before it thaws
			"free": 3.2,                # seconds of free running between applications
			"speed": 0.28,              # run speed, screens per second
			"label": "lum = .299r + .587g + .114b → map[lum·3] · clip: y > feet − k·h" },
		"rhyme": { "name": "Fossil", "hint": "the petrified palette with its cracks, a slow sweep and a long hold — turned to stone, and staying that way",
			"dials": { "state": "petrified", "sweep": 3.2, "hold": 4.5 } } },
	{ "id": "flicker", "letter": "F", "name": "Flicker",
		"hint": "STATUS TINTS: one colour per status, its alpha on a wave — poison a slow sine, burning a fast one, stun a hard blink — stacked source-atop — press to cycle",
		"dials": { "statuses": { "poison":  { "colour": "#7FE07A", "wave": "sine",   "rate": 0.7, "min": 0.12, "max": 0.5,  "glyph": "☠" },
				"burning": { "colour": "#FF8A3A", "wave": "sine",   "rate": 3.2, "min": 0.2,  "max": 0.6,  "glyph": "▲", "embers": true },
				"stunned": { "colour": "#FFFFFF", "wave": "square", "rate": 4,   "min": 0,    "max": 0.75, "glyph": "★", "halt": true } },
			"cycleEvery": 2.6,          # seconds between autopilot status changes
			"pace": 0.12,               # the hero's walking speed, screens per second
			"night": 0.25,              # how dark the stage is
			"label": "α = min + (max − min)·wave(t·rate) · tint: source-atop, one fill per status" },
		"rhyme": { "name": "Frostbite", "hint": "the cold stack — chilled (a slow pale pulse), soaked (deep blue, dripping), slowed (a purple sawtooth that halves the walk)",
			"dials": { "statuses": { "chilled": { "colour": "#BFEFFF", "wave": "sine", "rate": 0.35, "min": 0.2, "max": 0.55, "glyph": "❄" },
					"soaked":  { "colour": "#3A78D8", "wave": "sine", "rate": 1.1, "min": 0.25, "max": 0.5, "glyph": "●", "drops": true },
					"slowed":  { "colour": "#9A7AE0", "wave": "saw", "rate": 0.5, "min": 0.1, "max": 0.6, "glyph": "◔", "slow": 0.45 } },
				"night": 0.55 } } },
	{ "id": "jelly", "letter": "J", "name": "Jelly",
		"hint": "a WOBBLE shader: the sprite in strips, each slid by a chain of lateral springs up the body — the feet driven, every link chasing the one below, so the head lags and overshoots — jelly, heat, underwater — press to poke, and the wobble climbs from where you poked",
		"dials": { "mode": "jelly",       # jelly (a poke rings up the body) / heat / underwater
			"modes": { "jelly":      { "amp": 0.02, "w": 1.2, "k": 600,  "zeta": 0.35 },   # amp: the drive at the feet, sprite widths · w: its noise rate · k: a link's stiffness · zeta: its damping, of critical
				"heat":       { "amp": 0.05, "w": 30,  "k": 3000, "zeta": 0.5 },
				"underwater": { "amp": 0.12, "w": 4,   "k": 300,  "zeta": 0.45 } },
			"ampScale": 1,              # multiplies every mode's amp (the sway the feet are driven with)
			"speedScale": 1,            # multiplies every mode's w (how fast that drive's noise runs)
			"links": 6,                 # springs up the body: the feet's link and the ones that chase it, hair last
			"poke": 8,                  # a poke's kick, sprite widths per second, into ONE link's velocity
			"strip": 0.5,               # strip height in sprite units (0.5 = two strips per pixel row)
			"pokeEvery": 2.6,           # seconds between autopilot pokes
			"label": "link j: xⱼ'' = k·(xⱼ₋₁ − xⱼ) − ζ·2√k·xⱼ' · x₋₁ = amp·noise(t·w) · poke: vⱼ += poke · strip: x' = x + lerp(links, y)" },
		"rhyme": { "name": "Jiggly", "hint": "underwater, twice the amplitude and half the speed — the whole body swaying like weed in a slow current",
			"dials": { "mode": "underwater", "ampScale": 2.2, "speedScale": 0.6 } } },
	{ "id": "sway", "letter": "S", "name": "Sway",
		"hint": "WIND SWAY: a tree, a banner and a hanging sign, each a chain of angle springs the wind leans on — the root chases the wind, every joint chases the one below and lags, so a gust bends them late and they ring back past upright after it; the sign a real pendulum under its bracket — press to gust from that side",
		"dials": { "amp": 0.06,           # the lean a unit wind asks for: the tip's rest displacement, as a fraction of H
			"freq": 0.5,                # how fast the noise wind changes
			"k": 40,                    # the root spring's stiffness (a trunk rooted in the ground)
			"damp": 5,                  # its damping (2√k = 12.6 would be critical) — under, so it rings back
			"joints": 4,                # segments per tree or banner: the root + the joints that chase it
			"tip": 1.4,                 # each joint's k as a multiple of the one below: above 1 because the segment above is lighter
			"tipdamp": 0.4,             # a joint's damping, as a fraction of ITS OWN critical — well under 1, so the top whips past
			"bend": 0.5,                # the wind's extra lean at each joint, as a fraction of the root's: a bending trunk, not a hinge (0 = hinge)
			"gravity": 12,              # the sign's pendulum: g over its hanging length, per second² — the ω² of its swing
			"swing": 1.2,               # the sign's damping (2√gravity = 6.9 would be critical): it swings for a long while
			"strips": 14,               # strips per object
			"gust": 2.2,                # a gust's peak strength, in wind units — a spike on the rest, never on the object
			"gustDecay": 1.1,           # how fast a gust dies, per second
			"autoGust": 3.6,            # seconds between autopilot gusts
			"broken": false,            # a torn banner instead of a whole one
			"label": "root: θ'' = k·(wind·lean − θ) − damp·θ' · joint: θⱼ'' = kⱼ·(θⱼ₋₁ + wind·lean·bend − θⱼ) − dⱼ·θⱼ' · sign: θ'' = g·(wind·lean − sin θ) − swing·θ'" },
		"rhyme": { "name": "Storm", "hint": "more than twice the amplitude, a wind that changes three times as fast, and the banner torn — the night the sign came down",
			"dials": { "amp": 0.14, "freq": 1.5, "broken": true } } },
	{ "id": "grass", "letter": "G", "name": "Grass", "drag": true,
		"hint": "INTERACTIVE GRASS: every blade is a chain of angles on the lexicon's Damp spring — the root pushed away from the nearest body, each joint above chasing the one below on its own quicker, under-damped spring, so the tip lags and whips through after the body has passed — drag to walk the hero through",
		"dials": { "blades": 70,          # blades per 250 px of width
			"k": 60,                    # the root spring's stiffness
			"damp": 12,                 # its damping (2√k would be critical)
			"joints": 3,                # segments per blade: the root + the joints that follow it (1 = the old rigid needle)
			"tip": 1.4,                 # each joint's k as a multiple of the one below: above 1 because the segment above is lighter — the same bend rights it faster
			"tipdamp": 0.4,             # a joint's damping, as a fraction of ITS OWN critical — well under 1, so the tip overshoots the root and whips through
			"lean": 1.1,                # the most a body can push a blade, radians
			"reach": 0.09,              # a body's push radius, as a fraction of W
			"wind": 0.15,               # the resting lean the wind asks for, radians
			"speed": 0.3,               # the hero's run, screens per second
			"palette": ["#3E8A38", "#8ED45E"],
			"label": "root: θ'' = k·(rest + push − θ) − damp·θ' · joint j: θⱼ'' = kⱼ·(θⱼ₋₁ − θⱼ) − dⱼ·θⱼ' · kⱼ = tip·kⱼ₋₁ · dⱼ = tipdamp·2√kⱼ" },
		"rhyme": { "name": "Gale", "hint": "stiff dry stalks under a strong wind — a hard spring that barely gives to the body, joints almost as stiff as the root, and a resting lean the whole field agrees on",
			"dials": { "k": 150, "wind": 0.55, "tip": 0.8, "tipdamp": 0.9, "palette": ["#A89048", "#E2CB6C"] } } },
	{ "id": "xray", "letter": "X", "name": "Xray",
		"hint": "SILHOUETTE THROUGH WALLS: the hero, then the wall, then hero ∩ wall (source-in on the wall's mask) as a flat fill or a dilated outline — press to toggle",
		"dials": { "mode": "outline",     # outline / flat
			"colour": "#8AD9F5",        # the silhouette's colour
			"alpha": 0.8,               # its opacity
			"thick": 1.5,               # outline thickness, px
			"pulse": 0,                 # Hz of an alpha pulse (0 = steady); > 0 also adds a glow
			"speed": 0.24,              # the hero's walk, screens per second
			"label": "1 hero · 2 wall · 3 wall-mask ∘ source-in hero → flat | dilate − self = outline" },
		"rhyme": { "name": "Xspectral", "hint": "a magic-purple flat silhouette that pulses and glows — the hero's soul seen through stone",
			"dials": { "mode": "flat", "colour": "#C9A0F5", "pulse": 1.4 } } },
	{ "id": "wetfloor", "letter": "W", "name": "Wetfloor",
		"hint": "2D REFLECTION: the scene above the line copied, drawn flipped in strips below it, faded by depth and wobbled by a row of springs along the line — the atlas's Mirror, wet — the runner's steps stir it — press to splash, and the ripple travels out from there",
		"dials": { "wobble": 2,           # a footstep's kick to the springs under it, px of crest (0 = the runner leaves the water still)
			"springs": 28,              # springs along the line: the surface the reflection reads
			"tension": 10,              # k: the pull back to the rest level, per second²
			"spread": 100,              # s: the pull toward each neighbour, per second² — a ripple's front travels at (W/springs)·√s
			"damping": 1.6,             # c: velocity bleed, per second
			"alpha": 0.55,              # the reflection's strength at the line
			"depth": 1,                 # where the fade reaches zero, as a fraction of the floor's height
			"strip": 2,                 # strip height, px
			"splashEvery": 3.2,         # seconds between autopilot splashes
			"splash": 5,                # a splash's kick to the springs under it, px of first crest (0 = a splash leaves the mirror still)
			"label": "y' = 2·GY − y · α = alpha·(1 − depth) · x' = x + row(x)·(0.3 + depth) · row: a = −k·y − c·v + s·(yL + yR − 2y)" },
		"rhyme": { "name": "Waxfloor", "hint": "no wobble at all and a fade that ends a third of the way down — the sharp, short mirror of a polished hall",
			"dials": { "wobble": 0, "depth": 0.4, "splash": 0 } } },
	{ "id": "skewshadow", "letter": "S", "name": "Skewshadow",
		"hint": "SKEWED DROP SHADOW: the sprite redrawn dark through a shear + squash matrix — c = (Sx − x)/(GY − Sy) follows the sun across the sky — press to place the sun",
		"dials": { "squash": 0.28,        # the shadow's height as a fraction of the sprite's (the ground plane, foreshortened)
			"maxShear": 4,              # the longest shadow, in heights per height
			"alpha": 0.5,               # the shadow's darkness
			"day": 14,                  # seconds for the sun to cross the sky
			"source": "sun",            # sun (far, arcing) / lamp (near, fixed — shadows point away from it)
			"night": 0,                 # how dark the stage is
			"speed": 0.22,              # the hero's run, screens per second
			"label": "ctx.transform(face, 0, c, −squash, x, GY) · c = (Sx − x) / (GY − Sy)" },
		"rhyme": { "name": "Streetlamp", "hint": "the light is a lamp, near and fixed: every shadow points away from it and grows as the hero walks off — press moves the lamp",
			"dials": { "source": "lamp", "squash": 0.34, "night": 0.85 } } },
	{ "id": "pixelperfect", "letter": "P", "name": "Pixelperfect",
		"hint": "PIXEL-PERFECT: ×2.5 bilinear at a half pixel vs ×3 nearest at whole pixels; a rotating copy melts unless snapped to steps or turned as texels — press to cycle",
		"dials": { "zoom": 3,             # the integer zoom (crisp)
			"blurZoom": 2.5,            # the fractional zoom (soft)
			"steps": 16,                # rotation steps for the snapped copy
			"mode": "steps",            # the fourth copy: steps / chunky / smooth
			"modes": ["steps", "chunky", "smooth"],
			"spin": 0.7,                # radians per second
			"bob": 3,                   # the soft copy's fractional bob, px
			"label": "nearest + integer zoom + ⌊pivot⌋ = crisp · rotate the texels, not the pixels" },
		"rhyme": { "name": "Purist", "hint": "eight rotation steps and a ×4 zoom — the strict pixel-art rule, where every turn is a 45° and every pixel is four",
			"dials": { "steps": 8, "zoom": 4 } } },
	{ "id": "nineslice", "letter": "N", "name": "Nineslice", "drag": true,
		"hint": "9-SLICE: one panel texture cut into corners, edges and centre — corners copied as-is, edges stretched one way, the centre both — drag to resize the panel",
		"dials": { "tile": 0.28,          # the source texture's size, as a fraction of H
			"border": 0.25,             # the cut, as a fraction of the tile (corner size)
			"style": "metal",           # metal / parchment
			"breathe": 1,               # how much the panel breathes on autopilot (0 = still)
			"period": 3.4,              # seconds per breath
			"label": "9 draws: corners 1:1 · edges stretched along · centre stretched both ways" },
		"rhyme": { "name": "Ninescroll", "hint": "a parchment panel with a border a third of the tile — the same nine cuts, a thicker frame and curled corners that never stretch",
			"dials": { "style": "parchment", "border": 0.34 } } },
	{ "id": "outline", "letter": "O", "name": "Outline",
		"hint": "TOON SHADING: n·l quantised into bands, a specular cap, an edge where nz is small, and an inverted hull drawn larger behind — press to move the light",
		"dials": { "bands": 3,            # how many lighting steps
			"edge": 0.3,                # pixels whose normal's z is below this are the outline
			"hull": 3,                  # the inverted hull: a darker copy this many px larger, behind
			"colour": "#E8705A",        # the ball's colour
			"spec": 0.93,               # n·h above this is the highlight
			"lz": 0.6,                  # how much the light faces the viewer
			"orbit": 0.6,               # radians per second of the light's orbit
			"label": "band = ⌊(n·l)·bands⌋ / bands · edge: n.z < e · hull: r + h behind" },
		"rhyme": { "name": "Origami", "hint": "two bands and a thick line on cream — the paper look, where light is either on or off",
			"dials": { "bands": 2, "hull": 5, "colour": "#F0D8A0" } } },
	{ "id": "undersea", "letter": "U", "name": "Undersea", "shader": "res://shaders/stage/undersea.gdshader",
		"hint": "WATER REFRACTION: what lies below the surface, redrawn in strips pushed by scrolling noise, then in columns sheared by the slope of the surface above them — a row of springs the wader stirs; CAUSTICS = two noise fields multiplied, thresholded — press to drop a pebble, and the wobble spreads from where it lands",
		"dials": { "level": 0.5,          # the water's surface, as a fraction of H
			"amp": 0.02,                # the current's push at full noise, as a fraction of H
			"k": 0.06,                  # noise waves per px of depth
			"speed": 0.7,               # how fast the noise field scrolls
			"springs": 32,              # springs along the surface: the row the refraction reads (the shader holds 64 at most)
			"tension": 10,              # the row's pull back to rest, per second²
			"spread": 100,              # its pull toward each neighbour, per second² — a ring's front travels at (W/springs)·√spread
			"damping": 1.6,             # its velocity bleed, per second
			"refract": 0.6,             # px of sideways shift per px of depth per unit of surface slope
			"pebble": 6,                # a pebble's kick to the springs under it, px of first crest
			"stir": 1.5,                # a wader's footfall, the same, px
			"tint": "#4FA3D8",          # the water's colour
			"tintA": 0.32,              # how much of it
			"thr": 0.5,                 # caustic threshold: n₁·n₂ above this is bright
			"cScale": 0.09,             # caustic cell size (bigger = smaller cells)
			"cSpeed": 0.4,              # caustic drift speed
			"strip": 2,                 # refraction strip height, px
			"pebbleEvery": 3,           # seconds between autopilot pebbles
			"label": "x' = x + noise(y·k, t)·amp + slope(x)·(y − surface)·refract · surface: a = −k·y − c·v + s·(yL + yR − 2y) · caustic = (n₁·n₂ > thr)" },
		"rhyme": { "name": "Ultramarine", "hint": "the water up to the hero's chin, a deep blue tint and caustics that drift at a third of the speed — the bottom of the lake",
			"dials": { "level": 0.32, "tint": "#1C3BA8", "cSpeed": 0.14 } } },
	{ "id": "hologram", "letter": "H", "name": "Hologram",
		"hint": "HOLOGRAM: the sprite tinted source-atop, scanlines scrolled over it, a rim from dilate − self, alpha flickering on noise, added over a projector — press to glitch",
		"dials": { "hue": 192,            # the hologram's colour, degrees
			"alpha": 0.7,               # its base opacity
			"scan": 3,                  # scanline spacing, px
			"scanA": 0.45,              # scanline darkness
			"rim": 1.5,                 # the rim's thickness, px
			"flicker": 0.25,            # how deep the flicker cuts (0..1)
			"flickerRate": 14,          # how fast the flicker noise runs
			"glitchEvery": 3.6,         # seconds between autopilot glitches
			"glitchLen": 0.35,          # seconds a glitch lasts
			"split": 4,                 # slice offset during a glitch, px
			"label": "α·flick(noise) · tint source-atop · scanlines every 3 px · rim = dilate − self · lighter" },
		"rhyme": { "name": "Haunt", "hint": "a green, slow-breathing ghost of a hologram — faint scanlines and a flicker that drifts instead of buzzing",
			"dials": { "hue": 125, "flickerRate": 2.5, "scanA": 0.2 } } },
]

const FAINT := Color(0.91, 0.898, 0.957, 0.55)   # the web label's default ink
const SHADOW_INK := Color("0A0812")                # the skew shadow's black
const LINE_INK := Color(22.0 / 255.0, 14.0 / 255.0, 30.0 / 255.0)   # the toon line
const FLOOR_WET := Color(19.0 / 255.0, 16.0 / 255.0, 32.0 / 255.0, 0.55)
const FOUR := [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]
const ROW_MAX := 64                                   # the undersea shader's row: uniform float row[64]

# ---------------------------------------------------------------- small helpers

## A number for a label: "1" for whole values, "0.25" otherwise (JS's "" + k).
static func _num(v: float) -> String:
	return ("%d" % roundi(v)) if v == roundf(v) else ("%s" % v)

## The web label's "right" alignment: measure, then draw ending at p.x.
static func _label_right(n: CanvasItem, b: Dictionary, txt: String, p: Vector2, col: Color) -> void:
	var f := ThemeDB.fallback_font
	var w: float = f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	Kit.label(n, b, txt, Vector2(p.x - w, p.y), col)

## The run cycle's frame for a clock: 12 fps over seven frames (the web's frameOf).
static func _frame_of(clock: float) -> float:
	return (floori(clock * 12.0) % 7) / 10.0

## hsl(h°, s, l, a) → Color (the web's hsl()).
static func _hsl(h: float, sat: float, l: float, a: float = 1.0) -> Color:
	var c := (1.0 - absf(2.0 * l - 1.0)) * sat
	var hh := fposmod(h, 360.0) / 60.0
	var x := c * (1.0 - absf(fmod(hh, 2.0) - 1.0))
	var rgb := Vector3(c, 0.0, x)
	if hh < 1.0:
		rgb = Vector3(c, x, 0.0)
	elif hh < 2.0:
		rgb = Vector3(x, c, 0.0)
	elif hh < 3.0:
		rgb = Vector3(0.0, c, x)
	elif hh < 4.0:
		rgb = Vector3(0.0, x, c)
	elif hh < 5.0:
		rgb = Vector3(x, 0.0, c)
	var m := l - c / 2.0
	return Color(rgb.x + m, rgb.y + m, rgb.z + m, a)

## The hero's pixels as a set: Vector2i(ux, uy) → Color, in the 14 × 19 frame
## (feet at (7, 18)). Later parts overwrite earlier ones at the same cell, as
## the painter's overdraw would.
static func _cell_map(opts: Dictionary) -> Dictionary:
	var out := {}
	for cell in Kit.hero_cells(opts):
		var c: Vector2i = cell[0]
		var col: Color = cell[1]
		out[c] = col
	return out

## A cell's left edge in px for a sprite whose feet are at x, facing face
## (the web's scale(face, 1) about the feet: cell ux lands at (ux − 7)·s or
## mirrored at (6 − ux)·s).
static func _cell_x(ux: int, x: float, s: float, face: int) -> float:
	return x + (ux - 7) * s if face > 0 else x + (6 - ux) * s

## The same, relative to the sprite box's left edge (x − 7s): 0..13 units.
static func _cell_rx(ux: int, s: float, face: int) -> float:
	return (ux if face > 0 else 13 - ux) * s

## Liang–Barsky: the part of segment a→c inside r, or an empty array.
static func _clip_seg(a: Vector2, c: Vector2, r: Rect2) -> PackedVector2Array:
	var d := c - a
	var t0 := 0.0
	var t1 := 1.0
	var p := PackedFloat64Array([-d.x, d.x, -d.y, d.y])
	var q := PackedFloat64Array([a.x - r.position.x, r.end.x - a.x, a.y - r.position.y, r.end.y - a.y])
	for i in 4:
		var pi_: float = p[i]
		var qi: float = q[i]
		if absf(pi_) < 1e-9:
			if qi < 0.0:
				return PackedVector2Array()
		else:
			var tt := qi / pi_
			if pi_ < 0.0:
				t0 = maxf(t0, tt)
			else:
				t1 = minf(t1, tt)
	if t0 > t1:
		return PackedVector2Array()
	return PackedVector2Array([a + d * t0, a + d * t1])

## The pieces of a polygon inside the horizontal band y0..y1 (Clipper does
## the cutting, so torn banners and other concave shapes survive it).
static func _band_polys(pts: PackedVector2Array, y0: float, y1: float, x0: float, x1: float) -> Array[PackedVector2Array]:
	var band := PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)])
	return Geometry2D.intersect_polygons(pts, band)

## An ellipse outline (the web's ctx.ellipse + stroke).
static func _ellipse_ring(n: CanvasItem, c: Vector2, rx: float, ry: float, col: Color, w: float = 1.0) -> void:
	var pts := PackedVector2Array()
	for i in 33:
		var a := i / 32.0 * TAU
		pts.append(c + Vector2(cos(a) * maxf(0.1, rx), sin(a) * maxf(0.1, ry)))
	n.draw_polyline(pts, col, w)

## A horizontal gradient bar with any number of stops (the map legends).
static func _hgrad(n: CanvasItem, x: float, y: float, w: float, h: float, stops: Array[Color]) -> void:
	var segs := stops.size() - 1
	for i in segs:
		var xa := x + i / float(segs) * w
		var xb := x + (i + 1) / float(segs) * w
		n.draw_polygon(PackedVector2Array([Vector2(xa, y), Vector2(xb, y), Vector2(xb, y + h), Vector2(xa, y + h)]),
			PackedColorArray([stops[i], stops[i + 1], stops[i + 1], stops[i]]))

# ---------------------------------------------------------------- frozen

## The gradient-mapped sprite, cached by (state, unit, run frame, face) like
## the web's layer: every cell's position relative to the sprite box, its own
## colour, its mapped colour and its sheen alpha; the overlay as segments and
## 1-px sparkles, already clipped to the sprite's pixels (source-atop).
static func _frozen_build(b: Dictionary) -> void:
	var D: Dictionary = b.D
	var s: float = Kit.hero_unit(b)
	var dir: int = b.dir
	var key := "%s|%s|%s|%d" % [D.state, s, b.fz, dir]
	if b.built == key:
		return
	b.built = key
	var states: Dictionary = D.states
	var S: Dictionary = states.get(D.state, states.frozen)
	var stops: Array[Color] = []
	for hx in S.map:
		stops.append(Color(hx))
	var w := 14.0 * s
	var h := 19.0 * s
	var map := _cell_map({ "pose": "run", "frame": b.fz, "face": dir })
	var cells: Array = []
	var occ := {}                                     # occupied unit squares, box-relative
	for c: Vector2i in map:
		var col: Color = map[c]
		var lum := 0.299 * col.r + 0.587 * col.g + 0.114 * col.b   # brightness → position on the map
		var p := clampf(lum, 0.0, 0.999) * (stops.size() - 1)
		var j := int(p)
		var f := p - j
		var mapped := stops[j].lerp(stops[j + 1], f)
		var rx := _cell_rx(c.x, s, dir)
		var ry := c.y * s
		var sheen := 0.0
		if S.overlay == "sheen":                      # a diagonal white band, 0.42..0.58 along (0,0)→(w,h)
			var u := ((rx + s / 2.0) * w + (ry + s / 2.0) * h) / (w * w + h * h)
			sheen = clampf(1.0 - absf(u - 0.5) / 0.08, 0.0, 1.0) * 0.6
		cells.append([Vector2(rx, ry), col, mapped, sheen])
		occ[Vector2i(int(rx / s), c.y)] = true
	b.fz_cells = cells
	var segs: Array = []
	var dots: Array = []
	var R := Kit.rng(11)
	if S.overlay == "frost":                          # diagonal hatching, clipped to each cell, and sparkles
		var sp := maxf(3.0, s * 1.5)
		for cell in cells:
			var pos: Vector2 = cell[0]
			var k0 := ceili((pos.x - pos.y - s) / sp)
			var k1 := floori((pos.x + s - pos.y) / sp)
			for kk in range(k0, k1 + 1):
				var q := kk * sp                      # the line x − y = q
				var xa := maxf(pos.x, pos.y + q)
				var xb := minf(pos.x + s, pos.y + s + q)
				if xb > xa:
					segs.append([Vector2(xa, xa - q), Vector2(xb, xb - q), Color(1, 1, 1, 0.35)])
		for _i in 14:
			var px := floorf(R.randf() * w)
			var py := floorf(R.randf() * h)
			if occ.has(Vector2i(int(px / s), int(py / s))):
				dots.append(Vector2(px, py))
	elif S.overlay == "cracks":                       # four random polylines, each segment cut to the cells it crosses
		for _i in 4:
			var cx := R.randf() * w
			var cy := R.randf() * h
			for _m in 5:
				var nx := cx + (R.randf() - 0.5) * w * 0.4
				var ny := cy + (R.randf() - 0.3) * h * 0.25
				var bb := Rect2(Vector2(minf(cx, nx), minf(cy, ny)), Vector2(absf(nx - cx), absf(ny - cy))).grow(0.5)
				for cell in cells:
					var pos: Vector2 = cell[0]
					var cr := Rect2(pos, Vector2(s, s))
					if not cr.intersects(bb):
						continue
					var seg := _clip_seg(Vector2(cx, cy), Vector2(nx, ny), cr)
					if seg.size() == 2:
						segs.append([seg[0], seg[1], Color(0, 0, 0, 0.65)])
				cx = nx
				cy = ny
	b.fz_segs = segs
	b.fz_dots = dots

# ---------------------------------------------------------------- flicker

## The statuses in the current combo, as [name, status] pairs.
static func _flicker_active(b: Dictionary) -> Array:
	var D: Dictionary = b.D
	var statuses: Dictionary = D.statuses
	var out: Array = []
	for nm in b.combos[b.combo]:
		if statuses.has(nm):
			out.append([nm, statuses[nm]])
	return out

## The wave of a status at a clock: square, saw or sine, in 0..1.
static func _wave(st: Dictionary, clock: float) -> float:
	var rate: float = st.rate
	var ph := clock * rate
	if st.wave == "square":
		return 1.0 if fmod(ph, 1.0) < 0.5 else 0.0
	if st.wave == "saw":
		return 1.0 - fmod(ph, 1.0)
	return 0.5 + 0.5 * sin(ph * TAU)

# ---------------------------------------------------------------- jelly

## A poke: velocity into ONE link of the chain — yf 0 at the feet, 1 at the
## hair — so the wobble starts there and climbs.
static func _jelly_poke(b: Dictionary, yf: float, dir: int) -> void:
	var D: Dictionary = b.D
	var L: int = b.L
	var vs: PackedFloat32Array = b.vs
	var j := clampi(roundi(yf * (L - 1)), 0, L - 1)
	vs[j] += dir * float(D.poke) * 14.0 * float(b.S)   # the sprite is 14 units wide
	b.pokeJ = j
	b.age = 0.0

# ---------------------------------------------------------------- sway

## One object of the wind scene — its primitives, cut to the band y0..y1 and
## slid by dx (the web's strip copy out of the upright layer).
static func _sway_piece(n: CanvasItem, o: Dictionary, y0: float, y1: float, dx: float, W: float, H: float, GY: float, broken: bool) -> void:
	var ox: float = o.x
	var top: float = o.top
	var x0: float = o.x0
	var x1: float = x0 + float(o.w)
	var off := Vector2(dx, 0.0)
	var kind: String = o.kind
	if kind == "tree":
		var trunk := Rect2(ox - W * 0.012, top + H * 0.2, W * 0.024, GY - top - H * 0.2)
		var ti := trunk.intersection(Rect2(x0, y0, x1 - x0, y1 - y0))
		if ti.size.y > 0.0:
			n.draw_rect(Rect2(ti.position + off, ti.size), Color("5A3E2B"))
		for tri in [PackedVector2Array([Vector2(ox, top), Vector2(ox + W * 0.11, top + H * 0.3), Vector2(ox - W * 0.11, top + H * 0.3)]),
				PackedVector2Array([Vector2(ox, top + H * 0.12), Vector2(ox + W * 0.125, top + H * 0.42), Vector2(ox - W * 0.125, top + H * 0.42)])]:
			for piece in _band_polys(tri, y0, y1, x0, x1):
				if piece.size() >= 3:
					n.draw_colored_polygon(Transform2D(0.0, off) * piece, Color("3E7A48"))
	elif kind == "banner":
		var pole := Rect2(ox - 1.5, top, 3.0, GY - top).intersection(Rect2(x0, y0, x1 - x0, y1 - y0))
		if pole.size.y > 0.0:
			n.draw_rect(Rect2(pole.position + off, pole.size), Kit.BONE)
		var cw := W * 0.14
		var ch := H * 0.11 if broken else H * 0.24
		var cloth := PackedVector2Array([Vector2(ox + 1, top + 3), Vector2(ox + cw, top + 3)])
		if broken:
			for i in 6:
				cloth.append(Vector2(ox + cw - (i + 1) * cw / 6.0, top + 3 + ch - (i % 2) * H * 0.045))
		else:
			cloth.append(Vector2(ox + cw, top + 3 + ch))
			cloth.append(Vector2(ox + cw * 0.7, top + 3 + ch * 0.8))
			cloth.append(Vector2(ox + 1, top + 3 + ch))
		for piece in _band_polys(cloth, y0, y1, x0, x1):
			if piece.size() >= 3:
				n.draw_colored_polygon(Transform2D(0.0, off) * piece, Kit.HOT)
	else:                                             # the sign: two chains, a board, its word
		for cx in [ox - W * 0.04, ox + W * 0.04]:
			var ca := maxf(top, y0)
			var cb := minf(top + H * 0.06, y1)
			if cb > ca:
				n.draw_line(Vector2(cx + dx, ca), Vector2(cx + dx, cb), Kit.BONE, 1.0)
		var board := Rect2(ox - W * 0.045, top + H * 0.06, W * 0.09, H * 0.16).intersection(Rect2(x0, y0, x1 - x0, y1 - y0))
		if board.size.y > 0.0:
			n.draw_rect(Rect2(board.position + off, board.size), Color("8A6A3E"))
		var size := maxi(6, roundi(H * 0.06))
		var mid := top + H * 0.16 - size * 0.35        # the word travels with the strip its middle sits in
		if mid >= y0 and mid < y1:
			Kit.text(n, "INN", Vector2(ox + dx, top + H * 0.16), size, Kit.SUN, true)

# ---------------------------------------------------------------- the wave row

## A ROW of springs along a water line — Wavesprings' surface, shared by the
## wet floor and the undersea: heights b.ys and velocities b.vs (px), each
## spring pulled back to rest (tension), toward its two neighbours (spread)
## and bled (damping), so one kick becomes a ripple that travels outward.
static func _row_init(b: Dictionary) -> void:
	var D: Dictionary = b.D
	var nn := maxi(4, int(D.springs))
	var ys := PackedFloat32Array()                    # sized here: a packed array read back from b is the same array
	var vs := PackedFloat32Array()
	ys.resize(nn)
	vs.resize(nn)
	b.n = nn
	b.ys = ys
	b.vs = vs
	b.col_w = b.w / float(nn - 1)
	b.front = float(b.col_w) * sqrt(maxf(0.0, float(D.spread)))   # how fast a ripple's front travels, px per second

## A crest of about `crest` px at x — given as velocity, so the row decides the shape.
static func _row_kick(b: Dictionary, px: float, crest: float) -> void:
	var D: Dictionary = b.D
	var nn: int = b.n
	var vs: PackedFloat32Array = b.vs
	var i := clampi(roundi(px / b.w * float(nn - 1)), 0, nn - 1)
	var v := crest * sqrt(float(D.tension) + float(D.spread))
	vs[i] += v
	if i > 0:
		vs[i - 1] += v * 0.5
	if i < nn - 1:
		vs[i + 1] += v * 0.5

## One frame of the row: one acceleration per spring, substepped so a coarse
## frame stays stable (√(k + 4s)·h < 2 — the lexicon's Substep).
static func _row_step(b: Dictionary, dt: float, lim: float) -> void:
	var D: Dictionary = b.D
	var nn: int = b.n
	var ys: PackedFloat32Array = b.ys
	var vs: PackedFloat32Array = b.vs
	var tension: float = D.tension
	var damping: float = D.damping
	var spread: float = D.spread
	var sub := maxi(1, ceili(dt * 50.0))
	var h := dt / float(sub)
	for _s in sub:
		for i in nn:
			var yl := ys[i - 1 if i > 0 else i]
			var yr := ys[i + 1 if i < nn - 1 else i]
			vs[i] += (-tension * ys[i] - damping * vs[i] + spread * (yl + yr - 2.0 * ys[i])) * h
		for i in nn:
			ys[i] = clampf(ys[i] + vs[i] * h, -lim, lim)

## The row's height at any x, between its springs.
static func _row_at(b: Dictionary, x: float) -> float:
	var nn: int = b.n
	var ys: PackedFloat32Array = b.ys
	var p := clampf(x / float(b.col_w), 0.0, float(nn - 1))
	var i0 := mini(nn - 2, int(p))
	return ys[i0] + (ys[i0 + 1] - ys[i0]) * (p - i0)

## The tallest crest on the row, px — for the readouts.
static func _row_peak(b: Dictionary) -> float:
	var ys: PackedFloat32Array = b.ys
	var peak := 0.0
	for y in ys:
		peak = maxf(peak, absf(y))
	return peak

# ---------------------------------------------------------------- wet floor

## The reflection's alpha at a depth below the line, and its sideways slide
## at (x, depth): the row's height under that x, growing with depth.
static func _wet_a(dy: float, alpha: float, fade: float) -> float:
	return alpha * maxf(0.0, 1.0 - dy / fade)

static func _wet_dx(b: Dictionary, x: float, dy: float, floor_h: float) -> float:
	return _row_at(b, x) * (0.3 + dy / floor_h)

## A splash: a kick to the row where it lands, and a ring that spreads from there.
static func _wet_splash(b: Dictionary, px: float) -> void:
	_row_kick(b, px, float(b.D.splash))
	b.splashed = 0.0
	var pick: Dictionary = b.rings[0]
	for r in b.rings:
		if not r.on:
			pick = r
			break
	pick.on = true
	pick.x = px
	pick.age = 0.0

## The rows GY−(i+1)·strip .. GY−i·strip of some upright rectangles, drawn
## mirrored (y' = 2·GY + 1 − y) strip by strip, faded by depth and slid by
## the row under the rectangle's middle (the lamp and the crate are a few
## springs wide, so one slide per strip is close enough).
static func _wet_rects(n: CanvasItem, rects: Array, cols: Array, b: Dictionary, fade: float) -> void:
	var D: Dictionary = b.D
	var GY: float = b.gy
	var floor_h: float = b.h - GY
	var strip: float = maxf(1.0, D.strip)
	var alpha: float = D.alpha
	var i := 0
	while i * strip < floor_h:
		var dy := i * strip
		var a := _wet_a(dy, alpha, fade)
		if a <= 0.005:
			break
		var sy0 := GY - dy - strip
		var sy1 := GY - dy
		for ri in rects.size():
			var r: Rect2 = rects[ri]
			var ia := maxf(r.position.y, sy0)
			var ib := minf(r.end.y, sy1)
			if ib > ia:
				var col: Color = cols[ri]
				col.a *= a
				var dx := _wet_dx(b, r.get_center().x, dy, floor_h)
				n.draw_rect(Rect2(r.position.x + dx, 2.0 * GY + 1.0 - ib, r.size.x, ib - ia), col)
		i += 1

## The same for upright line segments (the crate's X): the part of each
## segment inside the strip, mirrored.
static func _wet_lines(n: CanvasItem, segs: Array, col: Color, w: float, b: Dictionary, fade: float) -> void:
	var D: Dictionary = b.D
	var GY: float = b.gy
	var floor_h: float = b.h - GY
	var strip: float = maxf(1.0, D.strip)
	var alpha: float = D.alpha
	var i := 0
	while i * strip < floor_h:
		var dy := i * strip
		var a := _wet_a(dy, alpha, fade)
		if a <= 0.005:
			break
		var band := Rect2(-1.0e5, GY - dy - strip, 2.0e5, strip)
		for sg in segs:
			var cut := _clip_seg(sg[0], sg[1], band)
			if cut.size() == 2:
				var c2 := col
				c2.a *= a
				var dx := _wet_dx(b, (cut[0].x + cut[1].x) * 0.5, dy, floor_h)
				n.draw_line(Vector2(cut[0].x + dx, 2.0 * GY + 1.0 - cut[0].y), Vector2(cut[1].x + dx, 2.0 * GY + 1.0 - cut[1].y), c2, w)
		i += 1

## The hills of Kit.stage, recomputed (the same noise, the same seeds) so the
## reflection can mirror them: points along the top edge, left to right.
static func _hill_tops(b: Dictionary, base: float, amp: float, freq: float, seed_off: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var x := 0.0
	while x <= b.w + 6.0:
		out.append(Vector2(minf(x, b.w), b.gy - b.h * (base + amp * (Kit.noise(x / b.w * freq + seed_off) * 0.5 + 0.5))))
		x += 6.0
	return out

# ---------------------------------------------------------------- nine-slice

## The piecewise-linear map of one axis: source stops [0, B, T−B, T] onto the
## destination stops. Corners keep their size, edges and the centre stretch.
static func _pl(v: float, src: PackedFloat32Array, dst: PackedFloat32Array) -> float:
	for i in 3:
		if v <= src[i + 1] or i == 2:
			var span: float = maxf(src[i + 1] - src[i], 1e-6)
			return dst[i] + (v - src[i]) / span * (dst[i + 1] - dst[i])
	return dst[3]

## The panel texture's primitives, drawn through the nine-slice map (an
## axis-aligned rect maps to an axis-aligned rect; a rivet inside a corner
## keeps its size; a rivet under the naive stretch becomes an ellipse).
static func _nine_rect(n: CanvasItem, r: Rect2, col: Color, m: Dictionary) -> void:
	var xa := _pl(r.position.x, m.sx, m.dx)
	var xb := _pl(r.end.x, m.sx, m.dx)
	var ya := _pl(r.position.y, m.sy, m.dy)
	var yb := _pl(r.end.y, m.sy, m.dy)
	n.draw_rect(Rect2(xa, ya, xb - xa, yb - ya), col)

static func _nine_stroke(n: CanvasItem, r: Rect2, lw: float, col: Color, m: Dictionary) -> void:
	var hw := lw / 2.0
	_nine_rect(n, Rect2(r.position.x - hw, r.position.y - hw, r.size.x + lw, lw), col, m)
	_nine_rect(n, Rect2(r.position.x - hw, r.end.y - hw, r.size.x + lw, lw), col, m)
	_nine_rect(n, Rect2(r.position.x - hw, r.position.y + hw, lw, r.size.y - lw), col, m)
	_nine_rect(n, Rect2(r.end.x - hw, r.position.y + hw, lw, r.size.y - lw), col, m)

static func _nine_dot(n: CanvasItem, c: Vector2, rr: float, col: Color, m: Dictionary) -> void:
	var cx := _pl(c.x, m.sx, m.dx)
	var cy := _pl(c.y, m.sy, m.dy)
	var rx := (_pl(c.x + rr, m.sx, m.dx) - _pl(c.x - rr, m.sx, m.dx)) / 2.0
	var ry := (_pl(c.y + rr, m.sy, m.dy) - _pl(c.y - rr, m.sy, m.dy)) / 2.0
	Kit.ellipse(n, Vector2(cx, cy), rx, ry, col)

static func _nine_panel(n: CanvasItem, style: String, T: float, B: float, m: Dictionary) -> void:
	if style == "parchment":
		_nine_rect(n, Rect2(0, 0, T, T), Color("E8D8A8"), m)
		var speck := Color(120.0 / 255.0, 80.0 / 255.0, 30.0 / 255.0, 0.12)
		for i in 40:
			_nine_rect(n, Rect2(fmod(i * 37.0, T), fmod(i * 53.0, T), 2, 1), speck, m)
		_nine_stroke(n, Rect2(B * 0.3, B * 0.3, T - B * 0.6, T - B * 0.6), maxf(1.0, B * 0.12), Color("7A4A22"), m)
		_nine_stroke(n, Rect2(B * 0.55, B * 0.55, T - B * 1.1, T - B * 1.1), 1.0, Color("7A4A22"), m)
		for q in [Vector2(B * 0.3, B * 0.3), Vector2(T - B * 0.3, B * 0.3), Vector2(B * 0.3, T - B * 0.3), Vector2(T - B * 0.3, T - B * 0.3)]:
			_nine_dot(n, q, B * 0.22, Color("7A4A22"), m)
	else:
		var top := Color("3A3560")                    # the vertical gradient, in the three source bands
		var bot := Color("221E3C")
		var ys := PackedFloat32Array([0.0, B, T - B, T])
		for i in 3:
			var ya := _pl(ys[i], m.sy, m.dy)
			var yb := _pl(ys[i + 1], m.sy, m.dy)
			var xa := _pl(0.0, m.sx, m.dx)
			var xb := _pl(T, m.sx, m.dx)
			Kit.vgrad(n, Rect2(xa, ya, xb - xa, yb - ya), top.lerp(bot, ys[i] / T), top.lerp(bot, ys[i + 1] / T))
		_nine_stroke(n, Rect2(B * 0.25, B * 0.25, T - B * 0.5, T - B * 0.5), maxf(1.0, B * 0.18), Color("8C86B0"), m)
		_nine_stroke(n, Rect2(B * 0.62, B * 0.62, T - B * 1.24, T - B * 1.24), 1.0, Color("5A5480"), m)
		for q in [Vector2(B * 0.5, B * 0.5), Vector2(T - B * 0.5, B * 0.5), Vector2(B * 0.5, T - B * 0.5), Vector2(T - B * 0.5, T - B * 0.5)]:
			_nine_dot(n, q, B * 0.16, Color("C9C4E4"), m)

## A nine-slice map: source stops [0, B, T−B, T] onto x, x+B, x+w−B, x+w.
static func _nine_map(T: float, B: float, x: float, y: float, w: float, h: float) -> Dictionary:
	return { "sx": PackedFloat32Array([0.0, B, T - B, T]), "dx": PackedFloat32Array([x, x + B, x + w - B, x + w]),
		"sy": PackedFloat32Array([0.0, B, T - B, T]), "dy": PackedFloat32Array([y, y + B, y + h - B, y + h]) }

# ---------------------------------------------------------------- toon

## The region of the sphere's front where n·L ≥ c, projected: a spherical cap
## is a circle on the sphere — its front arc projects to part of an ellipse,
## and where it wraps behind the silhouette the region is closed by the disc's
## rim. This IS the band boundary the web computed per pixel; here it is one
## polygon per band (L.z > 0 always, so the cap's centre faces us).
static func _cap_poly(c: float, L: Vector3, r: float, centre: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	var s := sqrt(maxf(0.0, 1.0 - c * c))
	var uz := sqrt(maxf(0.0, 1.0 - L.z * L.z))     # |L_xy|
	var lxy := Vector2(L.x, L.y)
	if uz < 1e-4:                                   # the light straight on: concentric circles
		for i in 48:
			var a := i / 48.0 * TAU
			out.append(centre + Vector2(cos(a), sin(a)) * r * s)
		return out
	var u_xy := -L.z * lxy / uz                     # u ⊥ L, in the plane of L and z (front-most direction)
	var v_xy := Vector2(L.y, -L.x) / uz             # v ⊥ L, flat in the screen
	var kappa := -c * L.z / maxf(1e-6, s * uz)      # n.z(φ) ≥ 0 ⇔ cos φ ≥ κ
	if kappa <= -1.0:                               # the whole circle faces us: a full ellipse
		for i in 48:
			var a := i / 48.0 * TAU
			out.append(centre + (c * lxy + s * (u_xy * cos(a) + v_xy * sin(a))) * r)
		return out
	if kappa >= 1.0:                                # the cap covers the whole front: the disc
		for i in 48:
			var a := i / 48.0 * TAU
			out.append(centre + Vector2(cos(a), sin(a)) * r)
		return out
	var phi0 := acos(kappa)
	for i in 33:                                    # the front arc, −φ0 .. φ0
		var a := -phi0 + i / 32.0 * 2.0 * phi0
		out.append(centre + (c * lxy + s * (u_xy * cos(a) + v_xy * sin(a))) * r)
	var qp := out[out.size() - 1] - centre          # the silhouette crossings, on the rim
	var qm := out[0] - centre
	var ap := qp.angle()
	var am := qm.angle()
	var al := lxy.angle()
	var d1 := wrapf(am - ap, -PI, PI)               # the rim arc from q+ to q−, the way that passes the light
	var d2 := d1 - signf(d1) * TAU
	var m1 := ap + d1 / 2.0
	var m2 := ap + d2 / 2.0
	var delta := d1 if cos(m1 - al) >= cos(m2 - al) else d2
	for i in range(1, 24):
		var a := ap + delta * i / 24.0
		out.append(centre + Vector2(cos(a), sin(a)) * r)
	return out

# ---------------------------------------------------------------- hologram

## The rows a glitch shoves: the web's slice walk, resolved to [y0, y1, dx].
static func _holo_slices(b: Dictionary, h: float) -> Array:
	var sl: Array = (b.slices as Array).duplicate()
	sl.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return p.y < q.y)
	var out: Array = []
	var yy := 0.0
	for sd in sl:
		var sy := maxf(yy, minf(h, floorf(sd.y)))
		var sh := maxf(0.0, minf(h - sy, ceilf(sd.h)))
		if sh > 0.0:
			out.append([sy, sy + sh, float(sd.dx)])
		yy = sy + sh
	return out

## The rim (dilate − self): a strip `rim` px wide outside every cell side that
## has no neighbour, plus the corner squares of the 8-way dilate.
static func _rim(n: CanvasItem, map: Dictionary, x_of: Callable, y0: float, s: float, rim: float, col: Color, dx_of: Callable) -> void:
	for c: Vector2i in map:
		var cx: float = x_of.call(c.x) + float(dx_of.call(c))
		var cy: float = y0 + c.y * s
		var open_l := not map.has(c + Vector2i(-1, 0))
		var open_r := not map.has(c + Vector2i(1, 0))
		var open_u := not map.has(c + Vector2i(0, -1))
		var open_d := not map.has(c + Vector2i(0, 1))
		if open_l:
			n.draw_rect(Rect2(cx - rim, cy, rim, s), col)
		if open_r:
			n.draw_rect(Rect2(cx + s, cy, rim, s), col)
		if open_u:
			n.draw_rect(Rect2(cx, cy - rim, s, rim), col)
		if open_d:
			n.draw_rect(Rect2(cx, cy + s, s, rim), col)
		if open_l and open_u:
			n.draw_rect(Rect2(cx - rim, cy - rim, rim, rim), col)
		if open_r and open_u:
			n.draw_rect(Rect2(cx + s, cy - rim, rim, rim), col)
		if open_l and open_d:
			n.draw_rect(Rect2(cx - rim, cy + s, rim, rim), col)
		if open_r and open_d:
			n.draw_rect(Rect2(cx + s, cy + s, rim, rim), col)

# ---------------------------------------------------------------- undersea

## A pebble: a kick to the row where it lands, and a ring that spreads from there.
static func _sea_pebble(b: Dictionary, px: float) -> void:
	_row_kick(b, px, float(b.D.pebble))
	b.dropped = 0.0
	var pick: Dictionary = b.rings[0]
	for r in b.rings:
		if not r.on:
			pick = r
			break
	pick.on = true
	pick.x = px
	pick.age = 0.0

static func _sea_uniforms(b: Dictionary) -> void:
	var D: Dictionary = b.D
	var wy := roundf(b.h * float(D.level))
	var nn: int = b.n
	var ys: PackedFloat32Array = b.ys
	var row := PackedFloat32Array()                   # the row, padded to the shader's array
	row.resize(ROW_MAX)
	for i in mini(nn, ROW_MAX):
		row[i] = ys[i]
	b.shader_rect = Rect2(0.0, wy, b.w, b.h - wy)
	b.uniforms = { "rect_size": Vector2(b.w, b.h - wy), "card_size": Vector2(b.w, b.h), "y0": wy, "gy": b.gy,
		"t": b.t, "amp": float(D.amp) * b.h, "k": float(D.k), "speed": float(D.speed),
		"strip": float(D.strip), "thr": float(D.thr), "c_scale": float(D.cScale), "c_speed": float(D.cSpeed),
		"row": row, "n_row": mini(nn, ROW_MAX), "refract": float(D.refract) }

# ---------------------------------------------------------------- the quartet

static func init(b: Dictionary) -> void:
	var D: Dictionary = b.D
	var W: float = b.w
	var H: float = b.h
	var GY: float = b.gy
	match b.id:
		"frozen":
			# a STATE SHADER does not change the drawing — it changes what the pixels
			# ARE. read the sprite's own pixels, take each one's brightness (the
			# luminance formula) and use it as a position along a four-stop palette: a
			# GRADIENT MAP. dark hair becomes deep ice-blue, the pale face near white,
			# and every state — frozen, stone, gold, ghost — is only a different palette
			# plus an overlay pattern stamped source-atop. the FREEZE-IN SWEEP is a clip
			# rectangle whose top climbs from the feet. chapter 03's palette swap, done
			# per pixel instead of per colour; the mapped sprite is built once and cached.
			b.phase = "free"
			b.timer = 0.0
			b.k = 0.0
			b.fz = 0.0
			b.x = W * 0.3
			b.dir = 1
			b.built = ""
			b.fz_cells = []
			b.fz_segs = []
			b.fz_dots = []
			_frozen_build(b)
		"flicker":
			# chapter 03 tinted a sprite by filling over it SOURCE-ATOP — the fill lands
			# only where the sprite already has pixels. a STATUS is that fill with a
			# colour of its own and an alpha that rides a WAVE: poison a slow sine,
			# burning a fast one with embers, stunned a hard square-wave blink. statuses
			# STACK because each fill sits atop the last; the icons above the head list
			# the stack, and the little scopes on the right draw each wave as it plays.
			var names: Array = (D.statuses as Dictionary).keys()
			var combos: Array = []
			for idxs in [[0], [1], [2], [0, 1], [1, 2], [0, 1, 2], []]:
				var combo: Array = []
				for i in idxs:
					if i < names.size():
						combo.append(names[i])
				combos.append(combo)
			b.combos = combos
			b.combo = 0
			b.autoT = 0.0
			b.x = W * 0.4
			b.dir = 1
			b.emit = 0.0
			b.halt = false
			b.parts = []
			for _i in 28:
				b.parts.append({ "on": false, "x": 0.0, "y": 0.0, "vx": 0.0, "vy": 0.0, "life": 0.0, "drop": false, "c": Color.WHITE })
		"jelly":
			# a VERTEX SHADER moves where pixels land, not what they are. in 2D the
			# cheapest version is horizontal STRIPS: draw the sprite one thin row at a
			# time, each row shifted sideways. the shift is not a sine of the clock —
			# it is read off a CHAIN of lateral springs up the body (the lexicon's
			# Damp, stacked the way Grass stacks it): the feet's link chases a DRIVE —
			# a gentle slow noise for jelly's breathing, a tiny fast one for heat, a
			# big slow one under water — and every link above chases the one below on
			# its own under-damped spring, so the head lags the belly and overshoots.
			# a POKE adds velocity to one link only, so the wobble starts there and
			# climbs; nothing below the poke feels it. a strip's offset is the chain
			# interpolated at its height; the curve beside the sprite is that offset,
			# row by row, with the links marked on it.
			var L := maxi(2, int(D.links))
			var xs := PackedFloat32Array()                # link offsets (px) and velocities, feet first
			var vs := PackedFloat32Array()
			xs.resize(L)
			vs.resize(L)
			b.L = L
			b.xs = xs
			b.vs = vs
			b.S = maxf(2.0, roundf(H / 60.0)) * 2.0        # the sprite's unit here (its own, not the kit's)
			b.age = 9.0
			b.pokeJ = 0
			b.drive = 0.0
			b.autoT = 0.0
			b.bubbles = []
			for _i in 10:
				b.bubbles.append({ "x": randf_range(0.0, W), "y": randf_range(0.0, GY), "r": randf_range(1.0, 3.0), "v": randf_range(8.0, 20.0) })
		"sway":
			# everything that stands in the wind is drawn ONCE, upright, into a layer;
			# every frame it is copied back in horizontal STRIPS, each slid sideways by
			# how far the object has BENT at that height. the bend is never the wind's
			# value: it is a CHAIN of angle springs (Grass, stood up to tree height).
			# the root chases the lean the wind asks for on an under-damped spring, and
			# every joint above chases the one below — quicker, since the segment above
			# is lighter, and much less damped — plus a little extra lean of its own
			# from the wind, so the trunk curves instead of hinging. the top lags the
			# gust, and when the gust dies it whips back past upright. the sign hangs
			# from its bracket, so it is a PENDULUM: gravity pulls it back to hanging,
			# the wind pushes it aside, and it keeps swinging long after — the tree has
			# stopped before the sign has. the wind is one noise value at the clock
			# plus each object's x, and a GUST is a spike on that rest which decays; a
			# strip's dx is the chain walked up (or down) to the strip's height.
			# (here the upright drawing is cut to each strip with Clipper, then slid.)
			var J := maxi(1, int(D.joints))
			var amp: float = D.amp
			var bend: float = D.bend
			b.J = J
			b.objs = [
				{ "kind": "tree", "pivot": "base", "x": W * 0.2, "x0": W * 0.07, "w": W * 0.26, "top": GY - H * 0.56, "bot": GY },
				{ "kind": "banner", "pivot": "base", "x": W * 0.5, "x0": W * 0.47, "w": W * 0.19, "top": GY - H * 0.58, "bot": GY },
				{ "kind": "sign", "pivot": "hang", "x": W * 0.83, "x0": W * 0.78, "w": W * 0.2, "top": GY - H * 0.5, "bot": GY - H * 0.5 + H * 0.24 } ]
			for o in b.objs:
				var span: float = float(o.bot) - float(o.top)
				o.span = span
				o.th = 0.0                                # the root angle (the sign: its whole angle) and its velocity
				o.om = 0.0
				var tj := PackedFloat32Array()            # the joints above the root: angles and velocities
				var oj := PackedFloat32Array()
				tj.resize(maxi(0, J - 1))
				oj.resize(maxi(0, J - 1))
				o.tj = tj
				o.oj = oj
				# the lean per unit wind, so that at rest the tip sits amp·H aside: a chain of J
				# segments with the extra bend adds up to span·(1 + bend·(J − 1)/2) per radian
				o.lean = amp * H / (span * (1.0 + bend * (J - 1) / 2.0)) if o.pivot == "base" else 0.6 * amp * H / span
				var cum := PackedFloat32Array()           # the chain walked: sideways displacement at each segment's end
				cum.resize(J + 1)
				o.cum = cum
			b.gustA = 0.0
			b.gustDir = 1
			b.windC = 0.0
			b.autoT = 0.0
		"grass":
			# each blade of grass is a short CHAIN of angles from vertical. the root is
			# one rule: a damped spring toward a resting angle (the lexicon's Damp).
			# the wind moves the rest a little; a BODY nearby pushes the rest away from
			# itself, harder the closer it is, and when the body has passed the spring
			# brings the root back, overshooting a touch because the damping is a
			# little under critical. every JOINT above the root is the same spring
			# again, its rest the angle of the segment below it, quicker (k · tip: the
			# segment above is lighter, so k here is stiffness PER inertia) and much
			# less damped (tipdamp of its own critical) — so the tip lags the root on
			# the way out and whips through it on the way back: real grass is a
			# cantilever, clamped at the ground, that rings from the top.
			# a blade is drawn as a tapered polygon along its segments; the marked
			# blade shows its root θ and its tip θ.
			var nn := maxi(8, roundi(float(D.blades) * W / 250.0))
			var R := Kit.rng(5)
			var pal: Array = D.palette
			var c0 := Color(pal[0])
			var c1 := Color(pal[1])
			var bx := PackedFloat32Array()
			var bh := PackedFloat32Array()
			var cols: Array[Color] = []
			for _i in nn:
				bx.append(W * 0.02 + R.randf() * W * 0.96)
				bh.append(H * (0.07 + R.randf() * 0.1))
				cols.append(c0.lerp(c1, R.randf()))
			b.n = nn
			b.bx = bx
			b.bh = bh
			var th := PackedFloat32Array()                # sized here: a packed array read back from b is a copy
			var om := PackedFloat32Array()
			th.resize(nn)
			om.resize(nn)
			b.th = th
			b.om = om
			var J := maxi(1, int(D.joints))               # segments per blade; joints above the root: J − 1
			var tj := PackedFloat32Array()                # joint angles, blade-major: tj[i * (J − 1) + j]
			var oj := PackedFloat32Array()                # and their angular velocities
			tj.resize(nn * (J - 1))
			oj.resize(nn * (J - 1))
			b.J = J
			b.tj = tj
			b.oj = oj
			b.cols = cols
			b.hx = W * 0.2
			b.tx = W * 0.8
			b.dir = 1
			b.autoT = 0.0
			b.manual = 0.0
			b.moving = false
			b.near = 0
		"xray":
			# the X-RAY is three draws and two masks. draw the hero, then the wall over
			# it — the hidden part is gone. now, in a layer: paint the wall's SHAPE, then
			# draw the hero SOURCE-IN, which keeps only the hero pixels that land where
			# the wall is: the occluded part, as a cut-out. fill that cut-out flat with
			# one colour and draw it back (chapter 03's tint), or DILATE it — the same
			# cut-out drawn eight times, one pixel each way — and cut the original out of
			# that (destination-out) to leave the ring: an outline (the atlas's Xray).
			# (here: the cells that intersect a wall ARE the cut-out; a cell side with
			# no cut neighbour is where the ring goes.)
			b.pillars = [Rect2(W * 0.55, GY - H * 0.62, W * 0.13, H * 0.62), Rect2(W * 0.2, GY - H * 0.42, W * 0.045, H * 0.42)]
			b.x = W * 0.05
			b.dir = 1
		"wetfloor":
			# a reflection in 2D is the scene drawn TWICE: once upright, once mirrored
			# about the ground line — the atlas's Mirror. here the upright pass is
			# copied out of the canvas into a layer, then copied back one thin STRIP at
			# a time from the mirrored row, so each strip can (1) fade with depth — the
			# gradient mask — and (2) slide sideways, more the deeper it is: a wet
			# floor. the slide is not a sine of the clock: it is read off a ROW of
			# springs along the line (Wavesprings' water, laid on the floor) — each
			# pulled back to rest and toward its two neighbours, so a kick at one
			# spring becomes a ripple that travels outward, spreads and dies. the
			# runner's feet kick the row where they land; a splash kicks it harder
			# where you pressed, and the rings spread at the same speed the ripple
			# does. no kicks and a short fade = polish.
			# (the painter has no canvas to copy: the hero's cells, the lamp's and the
			# crate's rectangles are mirrored strip by strip with the α of their depth
			# and the slide of the row under them; the sky and hills are mirrored as
			# polygons whose vertices carry the fade and the slide of their own place
			# — smooth where the web's columns are stepped.)
			_row_init(b)
			b.x = W * 0.35
			b.dir = 1
			b.autoT = 0.0
			b.lastF = -1
			b.splashed = 9.0
			b.rings = []
			for _i in 5:
				b.rings.append({ "on": false, "x": 0.0, "age": 0.0 })
		"skewshadow":
			# any sprite can cast a shadow of itself: draw it again through a MATRIX
			# that keeps x, squashes y toward the ground (the floor is seen edge-on, so
			# height becomes a little depth) and SHEARS it sideways by the light. the
			# shear c is the sun's geometry: a point h above the feet lands h·c to the
			# side, away from the sun, so a low sun throws a long shadow — the
			# grimoire's Long shadow, the atlas's Longshadow, now driven by a clock. the
			# thin line runs from the light through the head to the shadow's tip.
			b.th = 0.2
			b.Sx = W * 0.3
			b.Sy = H * 0.2
			b.manual = 0.0
			b.x = W * 0.5
			b.dir = 1
			b.lampX = W * 0.72
		"pixelperfect":
			# pixel art stays pixel art under three rules. scale by an INTEGER, with
			# NEAREST sampling (bilinear at ×2.5 smears every edge across two pixels);
			# put the pivot on a WHOLE pixel (a half-pixel bob shimmers); and never
			# rotate the enlarged image — the big pixels tear into sub-pixel stairs, the
			# "melt". either snap the angle to a few STEPS, or rotate the tiny source
			# texture first and enlarge THAT: every pixel of the result is still a
			# texel. chapter 09's №4, the lexicon's Quantize, applied to a sprite.
			# (the painter has no bilinear filter: the soft copy is the same cells at a
			# fractional zoom and pivot, which shimmer rather than smear; the "chunky"
			# copy samples the rotated cell grid per texel, exactly as the web did.)
			b.ang = 0.0
		"nineslice":
			# a panel texture stretched whole gets fat, blurry corners. cut it into
			# NINE regions by two horizontal and two vertical lines at the border: the
			# four CORNERS are drawn at their own size, the four EDGES are stretched
			# only along their length, and the CENTRE is stretched both ways. nine
			# drawImage calls, one source texture drawn once and cached, any size of
			# panel with crisp corners. the small copy at the top right is the naive
			# stretch of the same texture, for comparison; the thin lines are the cuts.
			# (the texture is procedural, so the nine draws become one piecewise-linear
			# map per axis that every rectangle and rivet of it is drawn through.)
			b.cx = W * 0.5
			b.cy = H * 0.46
			b.pw = W * 0.5
			b.ph = H * 0.5
			b.manual = 0.0
		"outline":
			# chapter 11 shaded a ball with a smooth gradient of n·l; TOON shading
			# keeps the same n·l and QUANTISES it — floor it into a few bands — so the
			# light falls in steps like ink washes. the outline comes twice: an
			# INVERTED HULL, the same shape drawn larger and darker behind (the classic
			# 3D trick), and a NORMAL-EDGE test, where any pixel whose normal points
			# mostly sideways (n.z small) is painted the line colour. the ball is a
			# small pixel buffer, computed every frame and stretched up — the atlas's
			# Orb, with its gradient snapped to a staircase.
			# (no buffer here: each band n·l ≥ c is a spherical cap, and a cap projects
			# to an ellipse arc closed by the rim — one polygon per band, the same set
			# of pixels the loop would have painted.)
			b.cx = W * 0.5
			b.cy = H * 0.47
			b.r = minf(W, H) * 0.24
			b.lx = 0.6
			b.ly = -0.5
			b.manual = 0.0
		"undersea":
			# water bends what is behind it. copy the part of the scene below the
			# surface out of the canvas, then draw it back in horizontal STRIPS, each
			# slid sideways by a noise field that scrolls with the clock — the current
			# (the atlas's Undertow, live). then once more in vertical COLUMNS, each
			# SHEARED by the slope of the surface above it: a tilted surface bends the
			# light through it, so what lies under a wave's flank is pushed aside, more
			# the deeper it is, and nothing under a crest or a trough moves at all.
			# the surface is a ROW of springs (Wavesprings' water): each pulled back to
			# rest and toward its neighbours, so a pebble's kick becomes a ring that
			# travels out from where it fell, and the wader's steps stir it. the line
			# is the row itself; the rings spread at the row's own speed. CAUSTICS are
			# the light the surface focuses on the floor: two noise fields at different
			# scales, multiplied, and everything above a threshold painted bright.
			# (this is the family's one screen read: shaders/stage/undersea.gdshader,
			# confined to the water via b.shader_rect, does the strips, the shear from
			# the row it is handed as a uniform, and the caustics over what the painter
			# drew; the painter draws a straight line at x = 8 and the pass bends it
			# into the push curve.)
			_row_init(b)
			b.x = W * 0.3
			b.dir = 1
			b.autoT = 0.0
			b.lastF = -1
			b.dropped = 9.0
			b.rings = []
			for _i in 6:
				b.rings.append({ "on": false, "x": 0.0, "age": 0.0 })
			b.bubbles = []
			for _i in 8:
				b.bubbles.append({ "x": 0.0, "y": 0.0, "r": 1.0, "v": 10.0, "on": false })
			_sea_uniforms(b)
		"hologram":
			# the folio's Hologram was a baked sheet; this one is built live from five
			# cheap passes on the sprite's pixels. TINT: a source-atop fill in the
			# hologram's hue. SCANLINES: dark one-pixel rows, also source-atop, scrolling
			# upward. RIM: the sprite drawn four times one pixel out (a dilate), with
			# the sprite itself cut back out — the bright edge of rim_glow.gdshader.
			# FLICKER: the whole thing's alpha rides a fast noise, with rare dropouts.
			# and it is drawn LIGHTER, so it adds to the dark room instead of covering
			# it: light, not paint. a GLITCH slices it into rows and shoves them.
			# (Godot 2D has no per-draw additive blend without a material: the tinted
			# cells are drawn normally, with their alpha — over a night this dark the
			# difference is small.)
			b.glitch = 0.0
			b.autoT = 0.0
			b.face = 1
			b.slices = []
			for _i in 6:
				b.slices.append({ "y": 0.0, "h": 0.0, "dx": 0.0 })

static func press(b: Dictionary, pos: Vector2) -> void:
	var D: Dictionary = b.D
	var W: float = b.w
	var H: float = b.h
	var GY: float = b.gy
	match b.id:
		"frozen":
			var sweep: float = D.sweep
			var k: float = b.k
			if b.phase == "free" or b.phase == "thaw":
				b.phase = "freeze"
				b.timer = k * sweep
			else:
				b.phase = "thaw"
				b.timer = (1.0 - k) * sweep
		"flicker":
			b.combo = (b.combo + 1) % (b.combos as Array).size()
			b.autoT = -3.0
		"jelly":
			var S: float = b.S                            # the sprite, as the painter places it: feet on GY, 19 units tall
			var y0 := GY - 18.0 * S
			var yf := clampf((y0 + 19.0 * S - pos.y) / (19.0 * S), 0.05, 0.95)   # 0 at the feet, 1 at the hair
			_jelly_poke(b, yf, 1 if pos.x < W * 0.42 else -1)   # pushed away from the finger
			b.autoT = 0.0
		"sway":
			b.gustDir = 1 if pos.x < W / 2.0 else -1
			b.gustA = 1.0
			b.autoT = 0.0
		"grass":
			b.tx = clampf(pos.x, W * 0.04, W * 0.96)
			b.manual = 4.0
		"xray":
			D.mode = "flat" if D.mode == "outline" else "outline"
		"wetfloor":
			_wet_splash(b, clampf(pos.x, 10.0, W - 10.0))
			b.autoT = 0.0
		"skewshadow":
			if D.source == "lamp":
				b.lampX = clampf(pos.x, W * 0.1, W * 0.9)
				return
			b.Sx = clampf(pos.x, 0.0, W)
			b.Sy = clampf(pos.y, H * 0.03, GY - H * 0.1)
			b.manual = 5.0
			b.th = clampf(acos(clampf(-(b.Sx - W / 2.0) / (W * 0.55), -1.0, 1.0)), 0.06 * PI, 0.94 * PI)
		"pixelperfect":
			var modes: Array = D.modes
			D.mode = modes[(modes.find(D.mode) + 1) % modes.size()]
		"nineslice":
			b.pw = clampf(absf(pos.x - b.cx) * 2.0, H * 0.2, W * 0.9)
			b.ph = clampf(absf(pos.y - b.cy) * 2.0, H * 0.2, H * 0.78)
			b.manual = 4.0
		"outline":
			var r: float = b.r
			var dx: float = (pos.x - float(b.cx)) / r
			var dy: float = (pos.y - float(b.cy)) / r
			var d := sqrt(dx * dx + dy * dy)
			if d == 0.0:
				d = 1.0
			var m := minf(d, 0.95)
			b.lx = dx / d * m
			b.ly = dy / d * m
			b.manual = 5.0
		"undersea":
			_sea_pebble(b, clampf(pos.x, 8.0, W - 8.0))
			b.autoT = 0.0
		"hologram":
			b.glitch = float(D.glitchLen)
			b.autoT = 0.0
			b.face = -int(b.face)

static func tick(b: Dictionary, dt: float, t: float) -> void:
	var D: Dictionary = b.D
	var W: float = b.w
	var H: float = b.h
	var GY: float = b.gy
	match b.id:
		"frozen":
			b.timer += dt
			var timer: float = b.timer
			var sweep: float = D.sweep
			match b.phase:
				"free":
					var dir: int = b.dir
					b.x += dir * W * float(D.speed) * dt
					if b.x > W * 0.85:
						b.x = W * 0.85
						b.dir = -1
					if b.x < W * 0.15:
						b.x = W * 0.15
						b.dir = 1
					b.fz = _frame_of(t)
					b.k = 0.0
					if timer > float(D.free):
						b.phase = "freeze"
						b.timer = 0.0
				"freeze":
					b.k = clampf(timer / sweep, 0.0, 1.0)
					if b.k >= 1.0:
						b.phase = "hold"
						b.timer = 0.0
				"hold":
					b.k = 1.0
					if timer > float(D.hold):
						b.phase = "thaw"
						b.timer = 0.0
				_:
					b.k = 1.0 - clampf(timer / sweep, 0.0, 1.0)
					if b.k <= 0.0:
						b.k = 0.0
						b.phase = "free"
						b.timer = 0.0
			_frozen_build(b)
		"flicker":
			b.autoT += dt
			if b.autoT > float(D.cycleEvery):
				b.autoT = 0.0
				b.combo = (b.combo + 1) % (b.combos as Array).size()
			var active := _flicker_active(b)
			var halt := false
			var slow := 1.0
			var sparks := false
			var drops := false
			for pair in active:
				var st: Dictionary = pair[1]
				if st.get("halt", false):
					halt = true
				if st.has("slow"):
					slow *= float(st.slow)
				if st.get("embers", false):
					sparks = true
				if st.get("drops", false):
					drops = true
			b.halt = halt
			if not halt:
				var dir: int = b.dir
				b.x += dir * W * float(D.pace) * slow * dt
				if b.x > W * 0.62:
					b.x = W * 0.62
					b.dir = -1
				if b.x < W * 0.22:
					b.x = W * 0.22
					b.dir = 1
			var s: float = Kit.hero_unit(b)
			var x0: float = b.x - 7.0 * s
			var y0: float = GY - 18.0 * s
			var sw := 14.0 * s
			var sh := 19.0 * s
			b.emit += dt * ((12.0 if sparks else 0.0) + (10.0 if drops else 0.0))   # embers rise off a burning body, drops fall off a soaked one
			while b.emit > 1.0:
				b.emit -= 1.0
				var p: Dictionary = {}
				for q in b.parts:
					if not q.on:
						p = q
						break
				if p.is_empty():
					break
				var is_drop := drops and (not sparks or randf() < 0.5)
				var st: Dictionary = {}
				for pair in active:
					var cand: Dictionary = pair[1]
					if cand.get("drops" if is_drop else "embers", false):
						st = cand
						break
				if st.is_empty() and active.size() > 0:
					st = active[0][1]
				p.on = true
				p.drop = is_drop
				p.x = x0 + randf_range(2.0, sw - 2.0)
				p.y = y0 + randf_range(2.0, sh - 4.0)
				p.life = randf_range(0.4, 0.9)
				p.vx = randf_range(-8.0, 8.0)
				p.vy = randf_range(10.0, 30.0) if is_drop else randf_range(-40.0, -18.0)
				p.c = Color(st.colour) if not st.is_empty() else Color.WHITE
			for p in b.parts:
				if not p.on:
					continue
				p.life -= dt
				if p.life <= 0.0:
					p.on = false
					continue
				if p.drop:
					p.vy += 140.0 * dt
				else:
					p.vy -= 20.0 * dt
				p.x += p.vx * dt
				p.y += p.vy * dt
				if p.y > GY:
					p.on = false
		"jelly":
			b.autoT += dt
			b.age += dt
			if b.autoT > float(D.pokeEvery):
				b.autoT = 0.0
				_jelly_poke(b, 0.55, 1 if randf() < 0.5 else -1)
			if D.mode == "underwater":
				for bu in b.bubbles:
					bu.y -= bu.v * dt
					if bu.y < 0.0:
						bu.y = GY
						bu.x = randf_range(0.0, W)
			# the chain: the feet's link chases the drive, each link above chases the one
			# below. a symplectic step is only stable while √k·h < 2, so a coarse frame
			# is cut into substeps of at most 0.02 s (the lexicon's Substep)
			var modes: Dictionary = D.modes
			var m: Dictionary = modes.get(D.mode, modes.jelly)
			var L: int = b.L
			var xs: PackedFloat32Array = b.xs
			var vs: PackedFloat32Array = b.vs
			var S: float = b.S
			var sw := 14.0 * S
			var k: float = m.k
			var d := float(m.zeta) * 2.0 * sqrt(k)
			var lim := sw * 2.0
			var drive := float(m.amp) * float(D.ampScale) * sw * Kit.noise(t * float(m.w) * float(D.speedScale) + 3.7)
			b.drive = drive
			var sub := maxi(1, ceili(dt * 50.0))
			var h := dt / float(sub)
			for _s in sub:
				var below := drive
				for j in L:
					vs[j] += (k * (below - xs[j]) - d * vs[j]) * h
					xs[j] = clampf(xs[j] + vs[j] * h, -lim, lim)
					below = xs[j]
		"sway":
			b.autoT += dt
			if b.autoT > float(D.autoGust):
				b.autoT = 0.0
				b.gustA = 1.0
				b.gustDir = 1 if randf() < 0.5 else -1
			b.gustA = maxf(0.0, b.gustA - dt * float(D.gustDecay))
			var gust_a: float = b.gustA
			var gust_dir: int = b.gustDir
			var gust := gust_dir * float(D.gust) * gust_a * gust_a   # the spike: peaks at once, dies as a square
			var freq: float = D.freq
			var kk: float = D.k
			var damp: float = D.damp
			var tip: float = D.tip
			var tipdamp: float = D.tipdamp
			var bend: float = D.bend
			var gravity: float = D.gravity
			var swing: float = D.swing
			var J: int = b.J
			# the joints up a trunk are stiffer than the root (k · tip per joint), and a
			# symplectic step is only stable while √k·h < 2 — so a coarse frame is cut
			# into substeps of at most 0.02 s (the lexicon's Substep)
			var sub := maxi(1, ceili(dt * 50.0))
			var h := dt / float(sub)
			var objs: Array = b.objs
			for oi in objs.size():
				var o: Dictionary = objs[oi]
				var wind := clampf(Kit.noise(t * freq + float(o.x) / W * 1.7) + gust, -2.5, 2.5)
				if oi == 1:
					b.windC = wind
				var rest := wind * float(o.lean)          # what the wind asks for — the spring decides what it gets
				var th: float = o.th
				var om: float = o.om
				var tj: PackedFloat32Array = o.tj
				var oj: PackedFloat32Array = o.oj
				var base: bool = o.pivot == "base"
				for _s in sub:
					if not base:                          # the sign: a pendulum, gravity's pull toward hanging, the wind's push aside
						om += (gravity * (rest - sin(th)) - swing * om) * h
						th = clampf(th + om * h, -1.5, 1.5)
						continue
					om += (kk * (rest - th) - damp * om) * h
					th = clampf(th + om * h, -1.3, 1.3)
					var below := th                       # the joints: each chases the segment below, leaning a little more of its own
					var kj := kk
					for j in J - 1:
						kj *= tip
						var dj := tipdamp * 2.0 * sqrt(kj)   # a fraction of THIS joint's critical damping
						oj[j] += (kj * (below + rest * bend - tj[j]) - dj * oj[j]) * h
						tj[j] = clampf(tj[j] + oj[j] * h, -1.4, 1.4)
						below = tj[j]
				o.th = th
				o.om = om
				# walk the chain: the sideways displacement at the end of each segment, from the pivot
				var segs := J if base else 1
				var seg := float(o.span) / segs
				var cum: PackedFloat32Array = o.cum
				cum[0] = 0.0
				for j in segs:
					cum[j + 1] = cum[j] + sin(th if j == 0 else tj[j - 1]) * seg
		"grass":
			var nn: int = b.n
			var bx: PackedFloat32Array = b.bx
			var th: PackedFloat32Array = b.th
			var om: PackedFloat32Array = b.om
			b.manual -= dt
			b.autoT += dt
			var hx: float = b.hx
			var tx: float = b.tx
			if b.manual <= 0.0 and absf(tx - hx) < 4.0:   # autopilot: the far side
				tx = W * 0.9 if hx < W / 2.0 else W * 0.1
			var d := tx - hx
			var step := W * float(D.speed) * dt
			if absf(d) > step:
				hx += signf(d) * step
				b.dir = 1 if d > 0.0 else -1
			else:
				hx = tx
			b.hx = hx
			b.tx = tx
			b.moving = absf(d) > 1.0
			var reach := W * float(D.reach)
			var kk: float = D.k
			var damp: float = D.damp
			var lean: float = D.lean
			var wind: float = D.wind
			var near := 0
			var near_d := 1.0e9
			var J: int = b.J
			var tj: PackedFloat32Array = b.tj
			var oj: PackedFloat32Array = b.oj
			var tip: float = D.tip
			var tipdamp: float = D.tipdamp
			# the joints up a blade are stiffer than the root (k · tip per joint), and a
			# symplectic step is only stable while √k·h < 2 and damp·h < 2 — so a coarse
			# frame is cut into substeps of at most 0.02 s (the lexicon's Substep):
			# at 60 fps that is one step, exactly what it was
			var sub := maxi(1, ceili(dt * 50.0))
			var h := dt / float(sub)
			for i in nn:
				var rest := Kit.noise(t * 1.3 + bx[i] / W * 4.0) * wind
				var dx := bx[i] - hx
				var ad := absf(dx)
				if ad < reach:                            # the push: away from the body
					rest += (-1.0 if dx < 0.0 else 1.0) * lean * (1.0 - ad / reach)
				if ad < near_d:
					near_d = ad
					near = i
				for _s in sub:
					om[i] += (kk * (rest - th[i]) - damp * om[i]) * h
					th[i] = clampf(th[i] + om[i] * h, -1.5, 1.5)
					var below: float = th[i]              # the joints: each chases the segment below
					var kj: float = kk
					for j in J - 1:
						kj *= tip                         # quicker with every joint up the blade (lighter segment, same bend)
						var dj := tipdamp * 2.0 * sqrt(kj)   # a fraction of THIS joint's critical damping
						var idx := i * (J - 1) + j
						oj[idx] += (kj * (below - tj[idx]) - dj * oj[idx]) * h
						tj[idx] = clampf(tj[idx] + oj[idx] * h, -1.6, 1.6)
						below = tj[idx]
			b.near = near
		"xray":
			var dir: int = b.dir
			b.x += dir * W * float(D.speed) * dt
			if b.x > W * 0.94:
				b.x = W * 0.94
				b.dir = -1
			if b.x < W * 0.06:
				b.x = W * 0.06
				b.dir = 1
		"wetfloor":
			b.autoT += dt
			b.splashed += dt
			if b.autoT > float(D.splashEvery):
				b.autoT = 0.0
				_wet_splash(b, b.x)
			var dir: int = b.dir
			b.x += dir * W * 0.2 * dt
			if b.x > W * 0.8:
				b.x = W * 0.8
				b.dir = -1
			if b.x < W * 0.15:
				b.x = W * 0.15
				b.dir = 1
			var fi := roundi(_frame_of(t) * 10.0)        # a footfall: the run cycle's two plants stir the row
			if fi != int(b.lastF) and (fi == 0 or fi == 3):
				_row_kick(b, b.x, float(D.wobble))
			b.lastF = fi
			_row_step(b, dt, H * 0.2)
			for r in b.rings:
				if r.on:
					r.age += dt
					if r.age > 1.2:
						r.on = false
		"skewshadow":
			var lamp_mode: bool = D.source == "lamp"
			b.manual -= dt
			if not lamp_mode and b.manual <= 0.0:
				b.th += dt * PI / float(D.day)
				if b.th > 0.94 * PI:
					b.th = 0.06 * PI
				b.Sx = W / 2.0 - cos(b.th) * W * 0.55
				b.Sy = GY - sin(b.th) * H * 0.75 - H * 0.05
			var dir: int = b.dir
			b.x += dir * W * float(D.speed) * dt
			if b.x > W * 0.9:
				b.x = W * 0.9
				b.dir = -1
			if b.x < W * 0.1:
				b.x = W * 0.1
				b.dir = 1
		"pixelperfect":
			b.ang += dt * float(D.spin)
		"nineslice":
			b.manual -= dt
			if b.manual <= 0.0:
				var period: float = D.period
				var breathe: float = D.breathe
				var k := sin(t * TAU / period) * breathe
				b.pw = W * 0.48 + k * W * 0.16
				b.ph = H * 0.42 + cos(t * TAU / period * 0.7) * breathe * H * 0.14
		"outline":
			b.manual -= dt
			if b.manual <= 0.0:
				var a := t * float(D.orbit)
				b.lx = cos(a) * 0.75
				b.ly = sin(a) * 0.75 - 0.15
		"undersea":
			b.autoT += dt
			b.dropped += dt
			if b.autoT > float(D.pebbleEvery):
				b.autoT = 0.0
				_sea_pebble(b, randf_range(W * 0.1, W * 0.9))
			var dir: int = b.dir
			b.x += dir * W * 0.14 * dt
			if b.x > W * 0.8:
				b.x = W * 0.8
				b.dir = -1
			if b.x < W * 0.2:
				b.x = W * 0.2
				b.dir = 1
			var fi := roundi(_frame_of(t) * 10.0)        # the wader's two plants per cycle stir the surface
			if fi != int(b.lastF) and (fi == 0 or fi == 3):
				_row_kick(b, b.x, float(D.stir))
			b.lastF = fi
			_row_step(b, dt, H * 0.15)
			var wy := roundf(H * float(D.level))
			for r in b.rings:
				if r.on:
					r.age += dt
					if r.age > 1.4:
						r.on = false
			for bu in b.bubbles:                          # a few bubbles off the wader
				if not bu.on:
					if randf() < dt * 0.6:
						bu.on = true
						bu.x = b.x + randf_range(-6.0, 6.0)
						bu.y = GY - randf_range(4.0, 14.0)
						bu.r = randf_range(1.0, 2.2)
						bu.v = randf_range(14.0, 26.0)
					continue
				bu.y -= bu.v * dt
				bu.x += sin(t * 5.0 + bu.r) * 8.0 * dt
				if bu.y < wy:
					bu.on = false
			_sea_uniforms(b)
		"hologram":
			b.autoT += dt
			if b.autoT > float(D.glitchEvery):
				b.autoT = 0.0
				b.glitch = float(D.glitchLen)
			b.glitch = maxf(0.0, b.glitch - dt)
			if b.glitch > 0.0 and randf() < 0.5:
				var h := 19.0 * Kit.hero_unit(b)
				var split: float = D.split
				for sd in b.slices:
					sd.y = randf_range(0.0, h)
					sd.h = randf_range(2.0, h * 0.15)
					sd.dx = randf_range(-1.0, 1.0) * split

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	var D: Dictionary = b.D
	var W: float = b.w
	var H: float = b.h
	var GY: float = b.gy
	var origin: Vector2 = (b.rect as Rect2).position
	match b.id:
		"frozen":
			Kit.stage(n, b, 0.15)
			var states: Dictionary = D.states
			var S: Dictionary = states.get(D.state, states.frozen)
			var s_alpha: float = S.alpha
			var k: float = b.k
			var x: float = b.x
			var s: float = Kit.hero_unit(b)
			var x0 := x - 7.0 * s
			var y0 := GY - 18.0 * s
			var sw := 14.0 * s
			var sh := 19.0 * s
			var line_y := y0 + (1.0 - k) * sh
			for cell in b.fz_cells:
				var pos: Vector2 = cell[0]
				var cy0 := y0 + pos.y
				var cy1 := cy0 + s
				if k < 1.0 and cy0 < line_y:              # the unfrozen part: the ordinary hero, above the line
					n.draw_rect(Rect2(x0 + pos.x, cy0, s, minf(cy1, line_y) - cy0), cell[1])
				if k > 0.0 and cy1 > line_y:              # the frozen part: the gradient-mapped copy, below it
					var top := maxf(cy0, line_y)
					var mc: Color = cell[2]
					mc.a *= s_alpha
					n.draw_rect(Rect2(x0 + pos.x, top, s, cy1 - top), mc)
					var sheen: float = cell[3]
					if sheen > 0.0:
						n.draw_rect(Rect2(x0 + pos.x, top, s, cy1 - top), Color(1, 1, 1, sheen * s_alpha))
			if k > 0.0:
				var below := Rect2(-2.0, line_y - y0, sw + 4.0, y0 + sh - line_y + 2.0)   # box-relative
				for sg in b.fz_segs:
					var cut := _clip_seg(sg[0], sg[1], below)
					if cut.size() == 2:
						var sc: Color = sg[2]
						sc.a *= s_alpha
						n.draw_line(Vector2(x0, y0) + cut[0], Vector2(x0, y0) + cut[1], sc, 1.0)
				for dpos in b.fz_dots:
					var dp: Vector2 = dpos
					if dp.y >= line_y - y0:
						n.draw_rect(Rect2(x0 + dp.x, y0 + dp.y, 1, 1), Color(1, 1, 1, 0.9 * s_alpha))
				if k < 1.0:
					Kit.line(n, Vector2(x0 - 6, line_y), Vector2(x0 + sw + 6, line_y), Color(1, 1, 1, 0.85), 1.0)
					Kit.label(n, b, "k = %.2f" % k, Vector2(x0 + sw + 9, line_y + 3), Kit.DIM)
			var stops: Array[Color] = []                  # the map itself: luminance 0 → 1 along the bottom axis
			for hx in S.map:
				stops.append(Color(hx))
			var bw := W * 0.3
			var bx := 10.0
			var by := 12.0
			_hgrad(n, bx, by, bw, 6.0, stops)
			for i in stops.size():
				Kit.rect(n, Rect2(bx + i / float(stops.size() - 1) * bw - 1, by - 2, 2, 10), Kit.INK)
			Kit.label(n, b, "lum 0", Vector2(bx, by + 18), Kit.DIM)
			_label_right(n, b, "1", Vector2(bx + bw, by + 18), Kit.DIM)
			Kit.text(n, "%s · %s" % [D.state, S.overlay], Vector2(bx, by + 30), 10, Kit.INK)
			Kit.label(n, b, b.phase, Vector2(x, y0 - 8), Kit.DIM, true)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"flicker":
			Kit.stage(n, b, float(D.night))
			var active := _flicker_active(b)
			var halt: bool = b.halt
			var dir: int = b.dir
			var x: float = b.x
			var s: float = Kit.hero_unit(b)
			var y0 := GY - 18.0 * s
			var map := _cell_map({ "pose": "hurt" if halt else "run", "frame": 0.0 if halt else _frame_of(t), "face": dir })
			for c: Vector2i in map:                                 # the tint stack: one source-atop fill per status
				var col: Color = map[c]
				for pair in active:
					var st: Dictionary = pair[1]
					var a: float = float(st.min) + (float(st.max) - float(st.min)) * _wave(st, t)
					col = col.lerp(Color(st.colour), a)
				n.draw_rect(Rect2(_cell_x(c.x, x, s, dir), y0 + c.y * s, s, s), col)
			for p in b.parts:
				if p.on:
					var pc: Color = p.c
					pc.a = minf(1.0, float(p.life) * 1.6)
					Kit.dot(n, Vector2(p.x, p.y), 1.4 if p.drop else 1.2 + float(p.life), pc)
			for i in active.size():                       # the icons above the head: the stack, in order
				var st: Dictionary = active[i][1]
				var ix := x + (i - (active.size() - 1) / 2.0) * s * 4.2
				var iy := y0 - s * 3.0
				Kit.dot(n, Vector2(ix, iy), s * 1.7, Color(st.colour))
				Kit.text(n, st.glyph, Vector2(ix, iy + s * 0.8), maxi(6, roundi(s * 2.2)), Kit.NIGHT, true)
			var bw := W * 0.26                            # the scopes: each active wave over the last 1.5 s
			var bh := H * 0.07
			var bx := W - bw - 8.0
			for i in active.size():
				var nm: String = active[i][0]
				var st: Dictionary = active[i][1]
				var by := 10.0 + i * (bh + 14.0)
				n.draw_rect(Rect2(bx, by, bw, bh), Color(0.91, 0.898, 0.957, 0.15), false, 1.0)
				var pts := PackedVector2Array()
				for j in 31:
					var a: float = float(st.min) + (float(st.max) - float(st.min)) * _wave(st, t - 1.5 + j / 30.0 * 1.5)
					pts.append(Vector2(bx + j / 30.0 * bw, by + bh - a * bh))
				n.draw_polyline(pts, Color(st.colour), 1.2)
				Kit.label(n, b, "%s · %s %s Hz" % [nm, st.wave, _num(float(st.rate))], Vector2(bx, by + bh + 10), Kit.DIM)
			if active.is_empty():
				_label_right(n, b, "no status — press to add one", Vector2(W - 8, 18), Kit.DIM)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"jelly":
			var modes: Dictionary = D.modes
			var m: Dictionary = modes.get(D.mode, modes.jelly)
			var under: bool = D.mode == "underwater"
			Kit.stage(n, b, 0.4 if under else 0.1)
			if under:
				Kit.rect(n, Rect2(0, 0, W, H), Color(Kit.WATER, 0.28))
				for bu in b.bubbles:
					Kit.ring(n, Vector2(bu.x, bu.y), bu.r, Color(1, 1, 1, 0.35), 1.0)
			var unit := maxf(2.0, roundf(H / 60.0))
			var S := unit * 2.0
			var map := _cell_map({ "pose": "stand", "frame": 0.0 })
			var x := W * 0.42
			var x0 := x - 7.0 * S
			var y0 := GY - 18.0 * S
			var sw := 14.0 * S
			var sh := 19.0 * S
			if D.mode == "heat":
				Kit.glow(n, Vector2(x, GY + 2), sw * 0.9, Kit.FIRE, 0.7)
				for _i in 5:
					Kit.dot(n, Vector2(x + randf_range(-sw * 0.4, sw * 0.4), GY - randf_range(0.0, sh * 0.5)), 1.2, Color(Kit.FIRE, 0.5))
			var age: float = b.age
			var L: int = b.L
			var xs: PackedFloat32Array = b.xs
			var poke_j: int = b.pokeJ
			var drive: float = b.drive
			var strip_h := maxf(1.0, S * float(D.strip))
			var nn := ceili(sh / strip_h)
			var offs := PackedFloat32Array()
			for j in nn:
				var sy := j * strip_h
				var yf := (sy + strip_h / 2.0) / sh          # 0 at the hair, 1 at the feet
				var p := (1.0 - yf) * (L - 1)                 # the strip's place along the chain, feet first
				var i0 := mini(L - 2, int(p))
				offs.append(xs[i0] + (xs[i0 + 1] - xs[i0]) * (p - i0))
			for c: Vector2i in map:                                     # each cell, in strips, each strip slid by its offset
				var col: Color = map[c]
				var ry0 := c.y * S
				var ry1 := ry0 + S
				var j0 := int(ry0 / strip_h)
				var j1 := mini(nn - 1, int((ry1 - 0.001) / strip_h))
				for j in range(j0, j1 + 1):
					var sa := maxf(ry0, j * strip_h)
					var sb := minf(ry1, (j + 1) * strip_h)
					n.draw_rect(Rect2(x0 + c.x * S + offs[j], y0 + sa, S, sb - sa), col)
			var gx := x0 + sw + W * 0.12                      # the curve beside the sprite: the offset, row by row
			Kit.line(n, Vector2(gx, y0), Vector2(gx, y0 + sh), Color(0.91, 0.898, 0.957, 0.2), 1.0)
			var pts := PackedVector2Array()
			for j in nn:
				pts.append(Vector2(gx + offs[j], y0 + j * strip_h + strip_h / 2.0))
			n.draw_polyline(pts, Kit.INK, 1.2)
			for j in L:                                   # the links themselves
				var hot := j == poke_j and age < 0.4
				Kit.dot(n, Vector2(gx + xs[j], y0 + sh - float(j) / (L - 1) * sh), 1.7, Color(0.961, 0.541, 0.541) if hot else Kit.SUN)
			Kit.label(n, b, "offset(y)", Vector2(gx, y0 - 6), Kit.DIM, true)
			Kit.text(n, D.mode, Vector2(10, 18), 11, Kit.INK)
			Kit.label(n, b, "k %s · ζ %s · %d links · drive %.2f·w · head %.2f·w" % [_num(float(m.k)), _num(float(m.zeta)), L, drive / sw, xs[L - 1] / sw], Vector2(10, 32), Kit.DIM)
			if age < 0.4:
				Kit.label(n, b, "poke", Vector2(x, y0 + sh - float(poke_j) / (L - 1) * sh - 8.0), Color(0.961, 0.541, 0.541, 1.0 - age / 0.4), true)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"sway":
			Kit.stage(n, b, 0.1)
			var gust_a: float = b.gustA
			var objs: Array = b.objs
			var sgn: Dictionary = objs[2]                 # the bracket: post + arm, rigid
			var stop: float = sgn.top
			Kit.rect(n, Rect2(sgn.x - W * 0.09, stop - 2, W * 0.012, GY - stop + 2), Color("4A4470"))
			Kit.rect(n, Rect2(sgn.x - W * 0.09, stop - 3, W * 0.14, 3), Color("4A4470"))
			var wind_c: float = b.windC
			var broken: bool = D.broken
			var J: int = b.J
			var nn := maxi(2, roundi(float(D.strips)))
			for oi in objs.size():
				var o: Dictionary = objs[oi]
				var base: bool = o.pivot == "base"
				var top: float = o.top
				var bot: float = o.bot
				var cum: PackedFloat32Array = o.cum
				var segs := J if base else 1
				var sh := (bot - top) / nn
				for j in nn:
					var sy := top + j * sh
					var f := 1.0 - (j + 0.5) / nn if base else (j + 0.5) / nn   # distance from the pivot, 0..1
					var p := f * segs                     # the segment this strip sits on, and how far along it
					var i0 := mini(segs - 1, int(p))
					var dx := cum[i0] + (cum[i0 + 1] - cum[i0]) * (p - i0)
					_sway_piece(n, o, sy, sy + sh + 0.6, dx, W, H, GY, broken)
				Kit.line(n, Vector2(o.x, bot if base else top), Vector2(o.x, top if base else bot), Color(0.91, 0.898, 0.957, 0.12), 1.0)   # the rest line
			var ax := W * 0.5                             # the wind, as an arrow
			var ay := H * 0.1
			Kit.arrow(n, Vector2(ax - wind_c * W * 0.08, ay), Vector2(ax + wind_c * W * 0.08, ay), Kit.HOT if gust_a > 0.05 else Kit.INK)
			Kit.label(n, b, "wind %.2f%s" % [wind_c, " (gust)" if gust_a > 0.05 else ""], Vector2(ax, ay - 6), Kit.DIM, true)
			var tree: Dictionary = objs[0]
			var tree_tj: PackedFloat32Array = tree.tj
			var tip_a: float = float(tree.th) if J == 1 else tree_tj[J - 2]
			Kit.label(n, b, "pivot: base — θ₀ %.2f · θtip %.2f" % [float(tree.th), tip_a], Vector2(tree.x, GY + 14), Kit.DIM, true)
			Kit.label(n, b, "pivot: top — a pendulum, θ %.2f" % float(sgn.th), Vector2(sgn.x, float(sgn.bot) + 12), Kit.DIM, true)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"grass":
			Kit.stage(n, b, 0.1)
			var nn: int = b.n
			var bx: PackedFloat32Array = b.bx
			var bh: PackedFloat32Array = b.bh
			var th: PackedFloat32Array = b.th
			var tj: PackedFloat32Array = b.tj
			var J: int = b.J
			var cols: Array[Color] = b.cols
			var hx: float = b.hx
			var moving: bool = b.moving
			var dir: int = b.dir
			var reach := W * float(D.reach)
			var hw := maxf(1.0, H * 0.006)
			var pts: Array = []                           # the marked blade's joints, base → tip, kept for the readout
			for pass_i in 2:                              # odd blades behind the hero, even ones in front
				if pass_i == 1:
					Kit.hero(n, b, Vector2(hx, GY), { "pose": "run" if moving else "stand", "frame": _frame_of(t) if moving else 0.0, "face": dir })
				var i := pass_i
				while i < nn:
					# walk the chain: each segment is bh / J long at its own angle. the
					# polygon goes up the left side, round the tip and down the right, the
					# half-width shrinking to nothing at the tip.
					var seg := bh[i] / float(J)
					var p := Vector2(bx[i], GY)
					var left: Array = [Vector2(bx[i] - hw, GY + 1)]
					var right: Array = [Vector2(bx[i] + hw, GY + 1)]
					var chain: Array = [p]
					for j in J:
						var a: float = th[i] if j == 0 else tj[i * (J - 1) + j - 1]
						p += Vector2(sin(a), -cos(a)) * seg
						chain.append(p)
						if j < J - 1:
							var w := hw * (1.0 - float(j + 1) / float(J))
							var side := Vector2(cos(a), sin(a)) * w
							left.append(p - side)
							right.append(p + side)
					left.append(p)                        # the tip, shared by both sides
					right.reverse()
					Kit.poly(n, left + right, cols[i])
					if i == b.near:
						pts = chain
					i += 2
			var ni: int = b.near                          # the marked blade: its root θ and its tip θ
			var tip_a: float = th[ni] if J == 1 else tj[ni * (J - 1) + J - 2]
			Kit.line(n, Vector2(bx[ni], GY), Vector2(bx[ni], GY - bh[ni]), Color(0.91, 0.898, 0.957, 0.3), 1.0)
			for j in pts.size() - 1:
				Kit.line(n, pts[j], pts[j + 1], Kit.SUN, 1.0)
			n.draw_arc(Vector2(bx[ni], GY), bh[ni] * 0.35, -PI / 2.0, -PI / 2.0 + th[ni], 16, Kit.SUN, 1.0)
			var tip_txt := "θ = %.2f" % th[ni] if J == 1 else "θ₀ %.2f · θtip %.2f" % [th[ni], tip_a]
			Kit.label(n, b, tip_txt, Vector2(bx[ni], GY - bh[ni] - 6), Kit.SUN, true)
			Kit.ring(n, Vector2(hx, GY), reach, Color(0.961, 0.757, 0.412, 0.25))
			Kit.label(n, b, "reach", Vector2(hx + reach + 3, GY - 3), Kit.DIM)
			var kk: float = D.k
			Kit.text(n, "%d blades · %d segs · k %s · damp %s (crit %.1f)" % [nn, J, _num(kk), _num(float(D.damp)), 2.0 * sqrt(kk)], Vector2(10, 18), 10, Kit.INK)
			if J > 1:
				Kit.label(n, b, "joints: k ×%s each · damp %s of their own critical" % [_num(float(D.tip)), _num(float(D.tipdamp))], Vector2(10, 32), Kit.DIM)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"xray":
			Kit.stage(n, b, 0.3)
			var x: float = b.x
			var dir: int = b.dir
			var fr := _frame_of(t)
			Kit.hero(n, b, Vector2(x, GY), { "pose": "run", "frame": fr, "face": dir })   # 1: the hero
			var pillars: Array = b.pillars
			for p in pillars:                             # 2: the walls, over it
				Kit.wall(n, p)
			var s: float = Kit.hero_unit(b)
			var x0 := roundf(x - 7.0 * s)
			var y0 := roundf(GY - 18.0 * s)
			var sw := 14.0 * s
			var sh := 19.0 * s
			var map := _cell_map({ "pose": "run", "frame": fr, "face": dir })
			var pieces: Array = []                        # 3: the cut-out — every cell's part inside a wall
			for c: Vector2i in map:
				var cell := Rect2(x0 + _cell_rx(c.x, s, dir), y0 + c.y * s, s, s)
				for p in pillars:
					var isect: Rect2 = cell.intersection(p)
					if isect.size.x > 0.0 and isect.size.y > 0.0:
						pieces.append([isect, c, cell])
			var pulse_hz: float = D.pulse
			var pulse := 0.65 + 0.35 * sin(t * pulse_hz * TAU) if pulse_hz > 0.0 else 1.0
			var col := Color(D.colour)
			if pulse_hz > 0.0:                            # the glow: the cut-out, faint, spread (the web drew it lighter)
				var gc := Color(col, 0.18 * pulse)
				for i in 4:
					var a := i / 4.0 * TAU
					for pc in pieces:
						var r: Rect2 = pc[0]
						n.draw_rect(Rect2(r.position + Vector2(cos(a) * 3.0, sin(a) * 3.0), r.size), gc)
			var alpha: float = float(D.alpha) * pulse
			var fc := Color(col, alpha)
			if D.mode == "flat":
				for pc in pieces:
					n.draw_rect(pc[0], fc)
			else:                                         # dilate, then subtract the original: the ring
				var th: float = D.thick
				var eps := 0.01
				for pc in pieces:
					var r: Rect2 = pc[0]
					var c: Vector2i = pc[1]
					var cell: Rect2 = pc[2]
					var open_l := r.position.x > cell.position.x + eps or not map.has(c + Vector2i(-1, 0))
					var open_r := r.end.x < cell.end.x - eps or not map.has(c + Vector2i(1, 0))
					var open_u := r.position.y > cell.position.y + eps or not map.has(c + Vector2i(0, -1))
					var open_d := r.end.y < cell.end.y - eps or not map.has(c + Vector2i(0, 1))
					if open_l:
						n.draw_rect(Rect2(r.position.x - th, r.position.y, th, r.size.y), fc)
					if open_r:
						n.draw_rect(Rect2(r.end.x, r.position.y, th, r.size.y), fc)
					if open_u:
						n.draw_rect(Rect2(r.position.x, r.position.y - th, r.size.x, th), fc)
					if open_d:
						n.draw_rect(Rect2(r.position.x, r.end.y, r.size.x, th), fc)
					if open_l and open_u:
						n.draw_rect(Rect2(r.position.x - th, r.position.y - th, th, th), fc)
					if open_r and open_u:
						n.draw_rect(Rect2(r.end.x, r.position.y - th, th, th), fc)
					if open_l and open_d:
						n.draw_rect(Rect2(r.position.x - th, r.end.y, th, th), fc)
					if open_r and open_d:
						n.draw_rect(Rect2(r.end.x, r.end.y, th, th), fc)
			n.draw_rect(Rect2(x0 - 0.5, y0 - 0.5, sw + 1, sh + 1), Color(0.91, 0.898, 0.957, 0.18), false, 1.0)
			for p in pillars:
				var pr: Rect2 = p
				Kit.label(n, b, "wall", Vector2(pr.position.x + pr.size.x / 2.0, pr.position.y - 4), Kit.DIM, true)
			Kit.text(n, "mode: %s%s" % [D.mode, (" · %s px" % _num(float(D.thick))) if D.mode == "outline" else ""], Vector2(10, 18), 11, Kit.INK)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"wetfloor":
			Kit.stage(n, b, 0.45)
			var x: float = b.x
			var dir: int = b.dir
			var splashed: float = b.splashed
			var nr: int = b.n
			var ys: PackedFloat32Array = b.ys
			var col_w: float = b.col_w
			var front: float = b.front
			var lx := W * 0.22
			var cxp := W * 0.72
			var cs := H * 0.14
			Kit.lamp(n, b, Vector2(lx, GY), true)
			Kit.crate(n, Vector2(cxp, GY), cs)
			var fr := _frame_of(t)
			Kit.hero(n, b, Vector2(x, GY), { "pose": "run", "frame": fr, "face": dir })
			Kit.rect(n, Rect2(0, GY + 1, W, H - GY), FLOOR_WET)   # the floor itself, dark and wet
			var floor_h := H - GY
			var fade := maxf(0.05, float(D.depth)) * floor_h
			var alpha: float = D.alpha
			var night := 0.45                             # the sky, mirrored: bands whose vertices carry α of their depth and the slide of the row under them
			var sky_top := Kit.SKY_TOP_DAY.lerp(Kit.SKY_TOP_NIGHT, night)
			var sky_bot := Kit.SKY_BOT_DAY.lerp(Kit.SKY_BOT_NIGHT, night)
			var nb := 6
			for i in nb:
				var d0 := i * floor_h / nb
				var d1 := (i + 1) * floor_h / nb
				var a0 := _wet_a(d0, alpha, fade)
				var a1 := _wet_a(d1, alpha, fade)
				if a0 <= 0.005:
					break
				var c0 := Color(sky_top.lerp(sky_bot, (GY - d0) / GY), a0)
				var c1 := Color(sky_top.lerp(sky_bot, (GY - d1) / GY), a1)
				var band := PackedVector2Array()          # the band's top edge left to right, its bottom edge back — one vertex per spring
				var bcol := PackedColorArray()
				for c in nr:
					band.append(Vector2(c * col_w + _wet_dx(b, c * col_w, d0, floor_h), GY + 1 + d0))
					bcol.append(c0)
				for c in range(nr - 1, -1, -1):
					band.append(Vector2(c * col_w + _wet_dx(b, c * col_w, d1, floor_h), GY + 1 + d1))
					bcol.append(c1)
				n.draw_polygon(band, bcol)
			for hill in [[0.08, 0.07, 3.0, 7.0, Color("6E8FB8").lerp(Color("15132A"), night)], [0.02, 0.05, 5.0, 21.0, Color("4B7A5A").lerp(Color("12111F"), night)]]:
				var tops := _hill_tops(b, hill[0], hill[1], hill[2], hill[3])
				var hc: Color = hill[4]
				var pts := PackedVector2Array([Vector2(_wet_dx(b, 0.0, 0.0, floor_h), GY + 1)])
				var pcs := PackedColorArray([Color(hc, alpha)])
				for tp in tops:
					var dep := GY - tp.y
					pts.append(Vector2(tp.x + _wet_dx(b, tp.x, dep, floor_h), GY + 1 + dep))
					pcs.append(Color(hc, _wet_a(dep, alpha, fade)))
				pts.append(Vector2(W + _wet_dx(b, W, 0.0, floor_h), GY + 1))
				pcs.append(Color(hc, alpha))
				n.draw_polygon(pts, pcs)
			var lh := H * 0.3                             # the lamp and the crate, mirrored strip by strip
			_wet_rects(n, [Rect2(lx - 2, GY - lh, 4, lh), Rect2(lx - 8, GY - lh - 3, 16, 4)], [Color("3A3355"), Color("3A3355")], b, fade)
			var lw := maxf(1.0, cs * 0.08)
			_wet_rects(n, [Rect2(cxp - cs / 2.0, GY - cs, cs, cs),
				Rect2(cxp - cs / 2.0 + 1 - lw / 2.0, GY - cs + 1 - lw / 2.0, cs - 2 + lw, lw), Rect2(cxp - cs / 2.0 + 1 - lw / 2.0, GY - 1 - lw / 2.0, cs - 2 + lw, lw),
				Rect2(cxp - cs / 2.0 + 1 - lw / 2.0, GY - cs + 1, lw, cs - 2), Rect2(cxp + cs / 2.0 - 1 - lw / 2.0, GY - cs + 1, lw, cs - 2)],
				[Color("8A6A3E"), Color("5A3E2B"), Color("5A3E2B"), Color("5A3E2B"), Color("5A3E2B")], b, fade)
			_wet_lines(n, [[Vector2(cxp - cs / 2.0, GY - cs), Vector2(cxp + cs / 2.0, GY)], [Vector2(cxp + cs / 2.0, GY - cs), Vector2(cxp - cs / 2.0, GY)]], Color("5A3E2B"), lw, b, fade)
			var s: float = Kit.hero_unit(b)                # the hero's cells, each row cut into the floor's strips
			var strip: float = maxf(1.0, D.strip)
			var map := _cell_map({ "pose": "run", "frame": fr, "face": dir })
			var y0 := GY - 18.0 * s
			for c: Vector2i in map:
				var col: Color = map[c]
				var cy0 := y0 + c.y * s
				var cy1 := cy0 + s
				var i0 := maxi(0, floori((GY - cy1) / strip))
				var i1 := ceili((GY - cy0) / strip) - 1
				for i in range(i0, i1 + 1):
					var dy := i * strip
					if dy >= floor_h:
						break
					var a := _wet_a(dy, alpha, fade)
					if a <= 0.005:
						break
					var ia := maxf(cy0, GY - dy - strip)
					var ib := minf(cy1, GY - dy)
					if ib > ia:
						var cc := Color(col, col.a * a)
						var cx := _cell_x(c.x, x, s, dir)
						n.draw_rect(Rect2(cx + _wet_dx(b, cx + s * 0.5, dy, floor_h), 2.0 * GY + 1.0 - ib, s, ib - ia), cc)
			var skin := PackedVector2Array()              # the row itself: the puddle's skin, riding its springs
			for i in nr:
				skin.append(Vector2(i * col_w, GY + 1 + ys[i] * 0.35))
			n.draw_polyline(skin, Color(0.91, 0.898, 0.957, 0.28), 1.0)
			for r in b.rings:                             # splash rings on the line, at the ripple's own speed
				if not r.on:
					continue
				var age: float = r.age
				var rr := 4.0 + age * front
				_ellipse_ring(n, Vector2(r.x, GY + 1), rr, rr * 0.22, Color(0.91, 0.898, 0.957, 0.7 * (1.0 - age / 1.2)), 1.0)
			var mbx := W - 14.0                           # the mask: α against depth, at the right edge
			var mbh := floor_h - 6.0
			for i in 12:
				Kit.rect(n, Rect2(mbx, GY + 3 + i / 12.0 * mbh, 6, mbh / 12.0 - 1), Color(0.91, 0.898, 0.957, alpha * maxf(0.0, 1.0 - (i + 0.5) / 12.0 * floor_h / fade)))
			_label_right(n, b, "α", Vector2(mbx - 3, GY + 12), Kit.DIM)
			Kit.label(n, b, "row %d springs · crest %.1f px%s" % [nr, _row_peak(b), " · splash" if splashed < 1.0 else ""], Vector2(10, GY + 14), Kit.DIM)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"skewshadow":
			var lamp_mode: bool = D.source == "lamp"
			var night: float = D.night
			Kit.stage(n, b, maxf(night, 0.8) if lamp_mode else night)
			var x: float = b.x
			var dir: int = b.dir
			var th: float = b.th
			var lamp_x: float = b.lampX
			var lamp_y := GY - H * 0.3 - 8.0
			var Lx: float = lamp_x if lamp_mode else b.Sx
			var Ly: float = lamp_y if lamp_mode else b.Sy
			var squash: float = D.squash
			var max_shear: float = D.maxShear
			var alpha: float = D.alpha
			var fr := _frame_of(t)
			var s: float = Kit.hero_unit(b)
			var shear_den := maxf(H * 0.05, GY - Ly)
			if lamp_mode:
				Kit.glow(n, Vector2(Lx, Ly), H * 0.4, Kit.SUN, 0.35)
			var cs := H * 0.14                            # the crate's shadow: its square through the same matrix
			var cxp := W * 0.3
			var cc := clampf((Lx - cxp) / shear_den, -max_shear, max_shear)
			var a_crate := alpha * clampf(1.2 - absf(cxp - Lx) / (W * 0.45), 0.0, 1.0) if lamp_mode else alpha * (0.55 + 0.45 * sin(th))
			n.draw_set_transform_matrix(Transform2D(Vector2(1, 0), Vector2(cc, -squash), origin + Vector2(cxp, GY)))
			n.draw_rect(Rect2(-cs / 2.0, -cs, cs, cs), Color(SHADOW_INK, a_crate))
			if not lamp_mode:                             # the lamp post's shadow (in sun mode the lamp is just another object)
				var lc := clampf((Lx - lamp_x) / shear_den, -max_shear, max_shear)
				var lh := H * 0.3
				var a_lamp := alpha * (0.55 + 0.45 * sin(th))
				n.draw_set_transform_matrix(Transform2D(Vector2(1, 0), Vector2(lc, -squash), origin + Vector2(lamp_x, GY)))
				n.draw_rect(Rect2(-2, -lh, 4, lh), Color(SHADOW_INK, a_lamp))
				n.draw_rect(Rect2(-8, -lh - 3, 16, 4), Color(SHADOW_INK, a_lamp))
			var c := clampf((Lx - x) / shear_den, -max_shear, max_shear)   # the hero's shadow: the cells, dark, through the matrix, mirrored by face
			var a_hero := alpha * clampf(1.2 - absf(x - Lx) / (W * 0.45), 0.0, 1.0) if lamp_mode else alpha * (0.55 + 0.45 * sin(th))
			n.draw_set_transform_matrix(Transform2D(Vector2(dir, 0), Vector2(c, -squash), origin + Vector2(x, GY)))
			var dark := Color(SHADOW_INK, a_hero)
			for cell in Kit.hero_cells({ "pose": "run", "frame": fr }):
				var cv: Vector2i = cell[0]
				n.draw_rect(Rect2((cv.x - 7) * s, (cv.y - 18) * s, s, s), dark)
			n.draw_set_transform(origin, 0.0, Vector2.ONE)
			Kit.crate(n, Vector2(cxp, GY), cs)
			Kit.lamp(n, b, Vector2(lamp_x, GY), lamp_mode)
			Kit.hero(n, b, Vector2(x, GY), { "pose": "run", "frame": fr, "face": dir })
			var hh := 17.0 * s                            # the geometry: light → head → shadow tip
			var tipx := x - c * hh
			var tipy := GY + squash * hh
			Kit.line(n, Vector2(Lx, Ly), Vector2(x, GY - hh), Color(0.961, 0.757, 0.412, 0.35), 1.0)
			Kit.line(n, Vector2(x, GY - hh), Vector2(tipx, tipy), Color(0.961, 0.757, 0.412, 0.35), 1.0)
			Kit.dot(n, Vector2(tipx, tipy), 2.0, Kit.SUN)
			if not lamp_mode:
				Kit.glow(n, Vector2(Lx, Ly), H * 0.12, Kit.SUN, 0.6)
				Kit.dot(n, Vector2(Lx, Ly), H * 0.03, Color("FFF3D0"))
			Kit.label(n, b, "c = %.2f" % c, Vector2(x, GY + squash * hh + 12), Kit.DIM, true)
			Kit.text(n, "%s%s" % [D.source, (" at x %d" % roundi(lamp_x)) if lamp_mode else (" θ %.0f°" % (th / PI * 180.0))], Vector2(10, 18), 10, Kit.INK)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"pixelperfect":
			Kit.stage(n, b, 0.0, true)
			var ang: float = b.ang
			var s0 := maxf(1.0, roundf(H / 170.0))      # the texel: the sprite is drawn at this unit and enlarged
			var map := _cell_map({ "pose": "run", "frame": _frame_of(t) })
			var w0 := 14.0 * s0
			var h0 := 19.0 * s0
			var z: float = D.zoom
			var bz: float = D.blurZoom
			var cy := H * 0.5
			var cols := [W * 0.125, W * 0.375, W * 0.625, W * 0.875]
			var by := sin(t * 2.0) * float(D.bob)       # 1: ×2.5 "bilinear", pivot at a half pixel, bobbing by fractions
			for c: Vector2i in map:
				n.draw_rect(Rect2(cols[0] - w0 * bz / 2.0 + 0.5 + c.x * s0 * bz, cy - h0 * bz / 2.0 + by + c.y * s0 * bz, s0 * bz, s0 * bz), map[c])
			Kit.dot(n, Vector2(cols[0] + 0.5, cy + by), 1.5, Kit.HOT)
			var px := roundf(cols[1] - w0 * z / 2.0)      # 2: ×3 nearest, pivot rounded to a whole pixel
			var py := roundf(cy - h0 * z / 2.0 + by)
			for c: Vector2i in map:
				n.draw_rect(Rect2(px + c.x * s0 * z, py + c.y * s0 * z, s0 * z, s0 * z), map[c])
			Kit.dot(n, Vector2(px + w0 * z / 2.0, py + h0 * z / 2.0), 1.5, Kit.SUN)
			n.draw_set_transform(origin + Vector2(cols[2], cy), ang, Vector2.ONE)   # 3: the melt — the enlarged image rotated freely
			for c: Vector2i in map:
				n.draw_rect(Rect2(-w0 * z / 2.0 + c.x * s0 * z, -h0 * z / 2.0 + c.y * s0 * z, s0 * z, s0 * z), map[c])
			n.draw_set_transform(origin, 0.0, Vector2.ONE)
			var sub := ""                                 # 4: the fix, by mode
			if D.mode == "steps":
				var steps: float = D.steps
				var a := roundf(ang / (TAU / steps)) * (TAU / steps)
				n.draw_set_transform(origin + Vector2(cols[3], cy), a, Vector2.ONE)
				for c: Vector2i in map:
					n.draw_rect(Rect2(-w0 * z / 2.0 + c.x * s0 * z, -h0 * z / 2.0 + c.y * s0 * z, s0 * z, s0 * z), map[c])
				n.draw_set_transform(origin, 0.0, Vector2.ONE)
				sub = "snapped to %s steps" % _num(steps)
			elif D.mode == "chunky":                      # rotate the 1× texture (nearest), then enlarge with nearest: every pixel a texel
				var r0 := ceili(sqrt(w0 * w0 + h0 * h0)) + 2
				var ox := roundf(cols[3] - r0 * z / 2.0)
				var oy := roundf(cy - r0 * z / 2.0)
				for j in r0:
					for i in r0:
						var p := Vector2(i + 0.5 - r0 / 2.0, j + 0.5 - r0 / 2.0).rotated(-ang)
						var u := p.x + w0 / 2.0
						var v := p.y + h0 / 2.0
						if u < 0.0 or v < 0.0 or u >= w0 or v >= h0:
							continue
						var key := Vector2i(int(u / s0), int(v / s0))
						if map.has(key):
							n.draw_rect(Rect2(ox + i * z, oy + j * z, z, z), map[key])
				sub = "texels rotated, then ×%s" % _num(z)
			else:                                         # the painter has no bilinear filter: the free rotation, as is
				n.draw_set_transform(origin + Vector2(cols[3], cy), ang, Vector2.ONE)
				for c: Vector2i in map:
					n.draw_rect(Rect2(-w0 * z / 2.0 + c.x * s0 * z, -h0 * z / 2.0 + c.y * s0 * z, s0 * z, s0 * z), map[c])
				n.draw_set_transform(origin, 0.0, Vector2.ONE)
				sub = "bilinear, free angle"
			var ly := cy + h0 * z / 2.0 + 16.0
			Kit.label(n, b, "×%s bilinear" % _num(bz), Vector2(cols[0], ly), Kit.DIM, true)
			Kit.label(n, b, "pivot x + .5", Vector2(cols[0], ly + 12), Kit.HOT, true)
			Kit.label(n, b, "×%s nearest" % _num(z), Vector2(cols[1], ly), Kit.DIM, true)
			Kit.label(n, b, "pivot ⌊x⌋", Vector2(cols[1], ly + 12), Kit.SUN, true)
			Kit.label(n, b, "rotate ×%s" % _num(z), Vector2(cols[2], ly), Kit.DIM, true)
			Kit.label(n, b, "the melt", Vector2(cols[2], ly + 12), Kit.HOT, true)
			Kit.label(n, b, D.mode, Vector2(cols[3], ly), Kit.INK, true)
			Kit.label(n, b, sub, Vector2(cols[3], ly + 12), Kit.DIM, true)
			Kit.text(n, "texel = %d px · sprite %d×%d" % [roundi(s0), roundi(w0), roundi(h0)], Vector2(10, 18), 10, Kit.INK)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"nineslice":
			Kit.stage(n, b, 0.0, true)
			var T := maxf(12.0, roundf(H * float(D.tile)))
			var B := maxf(3.0, roundf(T * float(D.border)))
			var style: String = D.style
			var pw: float = b.pw
			var ph: float = b.ph
			var cx: float = b.cx
			var cy: float = b.cy
			var w := maxf(2.0 * B + 2.0, roundf(pw))
			var h := maxf(2.0 * B + 2.0, roundf(ph))
			var x := roundf(cx - w / 2.0)
			var y := roundf(cy - h / 2.0)
			_nine_panel(n, style, T, B, _nine_map(T, B, x, y, w, h))   # the nine draws, as one map per axis
			var cut := Color(0.961, 0.757, 0.412, 0.5)  # the cuts on the panel
			for q in [x + B + 0.5, x + w - B - 0.5]:
				n.draw_line(Vector2(q, y), Vector2(q, y + h), cut, 1.0)
			for q in [y + B + 0.5, y + h - B - 0.5]:
				n.draw_line(Vector2(x, q), Vector2(x + w, q), cut, 1.0)
			Kit.text(n, "%d × %d" % [roundi(w), roundi(h)], Vector2(cx, cy + 4), 11, Color("5A3A18") if style == "parchment" else Kit.INK, true)
			var tx := 8.0                                 # the source, with its cuts, at the top left
			var ty := 8.0
			_nine_panel(n, style, T, B, _nine_map(T, B, tx, ty, T, T))
			for q in [tx + B + 0.5, tx + T - B - 0.5]:
				n.draw_line(Vector2(q, ty), Vector2(q, ty + T), Kit.SUN, 1.0)
			for q in [ty + B + 0.5, ty + T - B - 0.5]:
				n.draw_line(Vector2(tx, q), Vector2(tx + T, q), Kit.SUN, 1.0)
			Kit.label(n, b, "source %d px · cut %d" % [roundi(T), roundi(B)], Vector2(tx, ty + T + 11), Kit.DIM)
			var nw := roundf(w * 0.32)                    # the naive stretch at the top right: the same texture, scaled whole
			var nh := roundf(h * 0.32)
			var nx := W - nw - 8.0
			var ny := 8.0
			_nine_panel(n, style, T, B, { "sx": PackedFloat32Array([0.0, B, T - B, T]), "dx": PackedFloat32Array([nx, nx + B * nw / T, nx + (T - B) * nw / T, nx + nw]),
				"sy": PackedFloat32Array([0.0, B, T - B, T]), "dy": PackedFloat32Array([ny, ny + B * nh / T, ny + (T - B) * nh / T, ny + nh]) })
			_label_right(n, b, "stretched whole", Vector2(W - 8, ny + nh + 11), Color(0.961, 0.541, 0.541, 0.8))
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"outline":
			Kit.stage(n, b, 0.0, true)
			var cx: float = b.cx
			var cy: float = b.cy
			var r: float = b.r
			var centre := Vector2(cx, cy)
			var lz := maxf(0.05, float(D.lz))
			var L := Vector3(b.lx, b.ly, lz).normalized()                    # the light, normalised
			var Hv := Vector3(L.x, L.y, L.z + 1.0).normalized()             # the half vector, toward the viewer
			var bands := mini(16, maxi(1, roundi(float(D.bands))))
			var base := Color(D.colour)
			var edge: float = D.edge
			var spec: float = D.spec
			var hull: float = D.hull
			Kit.ellipse(n, Vector2(cx - L.x * r * 0.4, cy + r * 1.08), r * 0.9, r * 0.16, Color(0, 0, 0, 0.35))
			Kit.dot(n, centre, r + hull, LINE_INK)         # the inverted hull, behind
			var band_cols: Array[Color] = []
			for bb in bands:                              # the staircase: one colour per band
				var k := 0.3 + 0.7 * (bb / float(bands - 1) if bands > 1 else 1.0)
				band_cols.append(Color(base.r * k, base.g * k, base.b * k))
			Kit.dot(n, centre, r, band_cols[0])
			for bb in range(1, bands):                    # band bb = the cap n·l ≥ bb / bands
				var poly := _cap_poly(bb / float(bands), L, r, centre)
				if poly.size() >= 3:
					n.draw_colored_polygon(poly, band_cols[bb])
			var sp := _cap_poly(spec, Hv, r, centre)      # the specular cap: n·h above spec
			if sp.size() >= 3:
				n.draw_colored_polygon(sp, Color(1.0, 250.0 / 255.0, 235.0 / 255.0))
			var rin := r * sqrt(maxf(0.0, 1.0 - edge * edge))   # the normal-edge outline: n.z < edge is the rim
			if r - rin > 0.2:
				n.draw_arc(centre, (rin + r) / 2.0, 0.0, TAU, 72, LINE_INK, r - rin)
			var lpx := cx + L.x * r * 1.6                 # the light itself
			var lpy := cy + L.y * r * 1.6
			Kit.dot(n, Vector2(lpx, lpy), 3.0, Color("FFF3D0"))
			Kit.line(n, Vector2(lpx, lpy), Vector2(cx + L.x * r, cy + L.y * r), Color(0.961, 0.757, 0.412, 0.35), 1.0)
			var bw := W * 0.34                            # the legend: n·l from 0 to 1, cut into bands
			var bx := 10.0
			var by := 14.0
			for bb in bands:
				Kit.rect(n, Rect2(bx + bb / float(bands) * bw, by, bw / bands - 1, 7), band_cols[bb])
			Kit.label(n, b, "n·l 0", Vector2(bx, by + 18), Kit.DIM)
			_label_right(n, b, "1", Vector2(bx + bw, by + 18), Kit.DIM)
			Kit.text(n, "%d bands · edge n.z < %s · hull %s px" % [bands, _num(edge), _num(hull)], Vector2(bx, by + 32), 10, Kit.INK)
			_label_right(n, b, "%d caps as polygons, every frame" % bands, Vector2(W - 8, 18), Kit.DIM)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"undersea":
			Kit.stage(n, b, 0.1)
			var x: float = b.x
			var dir: int = b.dir
			var dropped: float = b.dropped
			var nr: int = b.n
			var ys: PackedFloat32Array = b.ys
			var col_w: float = b.col_w
			var front: float = b.front
			var wy := roundf(H * float(D.level))
			Kit.crate(n, Vector2(W * 0.75, GY), H * 0.15)
			Kit.hero(n, b, Vector2(x, GY), { "pose": "run", "frame": _frame_of(t), "face": dir })
			# the push, drawn: a straight line at x = 8 that the refraction pass bends
			# into the curve (the strips and the shear slide it exactly as they slide the scene)
			Kit.line(n, Vector2(8, wy), Vector2(8, H), Color(0.91, 0.898, 0.957, 0.5), 1.0)
			Kit.rect(n, Rect2(0, wy, W, H - wy), Color(Color(D.tint), float(D.tintA)))
			var pts := PackedVector2Array()               # the surface line — the row itself
			var steep := 0.0
			for i in nr:
				pts.append(Vector2(i * col_w, wy + ys[i]))
				if i > 0:
					steep = maxf(steep, absf(ys[i] - ys[i - 1]) / col_w)
			n.draw_polyline(pts, Color(0.91, 0.898, 0.957, 0.75), 1.5)
			for r in b.rings:                             # the rings, at the row's own speed
				if not r.on:
					continue
				var age: float = r.age
				var rr := 3.0 + age * front
				_ellipse_ring(n, Vector2(r.x, wy), rr, rr * 0.25, Color(0.91, 0.898, 0.957, 0.8 * (1.0 - age / 1.4)), 1.0)
			for bu in b.bubbles:
				if bu.on:
					Kit.ring(n, Vector2(bu.x, bu.y), bu.r, Color(1, 1, 1, 0.5), 1.0)
			var amp := float(D.amp) * H
			Kit.label(n, b, "push(y)", Vector2(8, wy - 5), Kit.DIM)
			Kit.label(n, b, "caustics: n₁·n₂ > %s" % _num(float(D.thr)), Vector2(W / 2.0, GY + 12), Kit.DIM, true)
			Kit.text(n, "current %.1f px · slope %.2f · %d springs%s" % [amp, steep, nr, " · pebble" if dropped < 1.0 else ""], Vector2(10, 18), 10, Kit.INK)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"hologram":
			Kit.stage(n, b, 0.75)
			var face: int = b.face
			var glitch: float = b.glitch
			var s: float = Kit.hero_unit(b)
			var map := _cell_map({ "pose": "stand", "frame": 0.0, "face": face })
			var w := 14.0 * s
			var h := 19.0 * s
			var px := W * 0.5
			var py := GY - H * 0.16 + sin(t * 1.3) * H * 0.012   # floating above the lens
			var x0 := roundf(px - 7.0 * s)
			var y0 := roundf(py - 18.0 * s)
			var hue := float(D.hue) + sin(t * 0.7) * 8.0
			var tint := _hsl(hue, 0.9, 0.62)
			var rim_c := _hsl(hue, 1.0, 0.85)
			Kit.ellipse(n, Vector2(px, GY), W * 0.11, H * 0.022, Color("2B2640"))   # the projector: a base, a lens, the cone up to the sprite
			Kit.ellipse(n, Vector2(px, GY - 2), W * 0.09, H * 0.016, Color("3A3355"))
			n.draw_polygon(PackedVector2Array([Vector2(px - 3, GY - 3), Vector2(x0 - 2, y0), Vector2(x0 + w + 2, y0), Vector2(px + 3, GY - 3)]),
				PackedColorArray([_hsl(hue, 0.9, 0.7, 0.35), _hsl(hue, 0.9, 0.7, 0.0), _hsl(hue, 0.9, 0.7, 0.0), _hsl(hue, 0.9, 0.7, 0.35)]))
			Kit.glow(n, Vector2(px, GY - 3), W * 0.06, tint, 0.8)
			var flick_rate: float = D.flickerRate          # pass 4: flicker — the whole thing's alpha rides a fast noise, with rare dropouts
			var flick := 1.0 - float(D.flicker) * (0.5 + 0.5 * Kit.noise(t * flick_rate))
			if Kit.noise(t * flick_rate * 0.7 + 40.0) > 0.82:
				flick *= 0.35
			var A := float(D.alpha) * flick
			var split: float = D.split
			var slices: Array = _holo_slices(b, h) if glitch > 0.0 else []
			var dx_of := func(c: Vector2i) -> float:      # a glitch: rows shoved sideways
				var ry := c.y * s
				for sl in slices:
					if ry >= float(sl[0]) and ry < float(sl[1]):
						return float(sl[2])
				return 0.0
			var x_of := func(ux: int) -> float: return x0 + _cell_rx(ux, s, face)
			var scan := maxf(1.5, float(D.scan))
			var scan_a: float = D.scanA
			var off := fmod(t * 12.0, scan)
			var base_row := y0 + h - off                  # scanlines march up from here, every `scan` px
			for ghost in ([-split, split] if glitch > 0.0 else []):   # a ghost copy either side during a glitch
				for c: Vector2i in map:
					var col: Color = map[c]
					n.draw_rect(Rect2(x_of.call(c.x) + ghost, y0 + c.y * s, s, s), Color(col.lerp(tint, 0.8), A * 0.35))
			for c: Vector2i in map:                                 # pass 1: tint, source-atop; pass 2: scanlines, also source-atop
				var col: Color = map[c]
				var cx: float = x_of.call(c.x) + float(dx_of.call(c))
				var cy := y0 + c.y * s
				n.draw_rect(Rect2(cx, cy, s, s), Color(col.lerp(tint, 0.8), A))
				var m0 := ceili((base_row - cy - s) / scan + 1e-4)
				var m1 := floori((base_row - cy) / scan)
				for mm in range(m0, m1 + 1):
					var yy := base_row - mm * scan
					if yy >= cy and yy < cy + s:
						n.draw_rect(Rect2(cx, yy, s, 1.0), Color(0, 0, 0, scan_a * A))
			_rim(n, map, x_of, y0, s, float(D.rim), Color(rim_c, A * 0.9), dx_of)   # pass 3: the rim — dilate, minus itself
			var bw := W * 0.28                            # the flicker, drawn: a bar of α
			var bx := 10.0
			var by := 14.0
			n.draw_rect(Rect2(bx, by, bw, 6), Color(0.91, 0.898, 0.957, 0.2), false, 1.0)
			n.draw_rect(Rect2(bx, by, bw * A, 6), tint)
			Kit.label(n, b, "α %.2f%s" % [A, " · glitch" if glitch > 0.0 else ""], Vector2(bx, by + 18), Kit.DIM)
			Kit.text(n, "hue %d° · scan %s px · rim %s" % [roundi(hue), _num(float(D.scan)), _num(float(D.rim))], Vector2(bx, by + 32), 10, Kit.INK)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
