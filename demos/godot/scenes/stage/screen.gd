extends RefCounted

const Kit := preload("res://scenes/stage/kit.gd")
## SCREEN & POST-PROCESS — thirteen things done to the FRAME after the scene
## is finished, ported from the web almanac (docs/stagecraft.js). The picture
## is drawn, then read back and bent: a mask wipes it, a vignette rims it, a
## CRT curves and stripes it, a threshold matrix dithers it, a palette snaps
## it or cycles under it, the colour channels slide apart, a distortion field
## pushes its texels, samples are averaged toward a centre (zoom blur, god
## rays), a curve regrades it, grain and scratches age it, a tape corrupts it.
##
## THE ONE HONEST DIFFERENCE from the web: where the browser runs fn(data, w,
## h) over the frame's bytes at scale ≤ 0.5, Godot runs the same arithmetic
## in a canvas_item shader (shaders/stage/<id>.gdshader) — the runner lays a
## ColorRect with it over the card and pushes b.uniforms in each frame. The
## painter here still draws the scene (that is what the shader reads) and
## tick() keeps b.uniforms current. A few things the web draws AFTER its
## pass (labels, swatches, arrows) therefore go through the pass too: the
## runner has no post-pass layer, so the CRT curves its own caption.

const TITLE := "Screen & post-process"
const BLURB := "the whole frame bent after the fact — wipes, CRT curves, dither, palettes that cycle, RGB splits, distortion, radial blur, god rays, grades, grain, tape damage"
const DEFS := [
	{ "id": "iris", "letter": "I", "name": "Iris",
		"hint": "the old frame is captured, then a MASK eats it away over the new scene — iris, dissolve, checker, curtain, slide, swirl — press to cut now",
		"dials": { "kind": "cycle",      # "iris" | "dissolve" | "checker" | "curtain" | "slide" | "swirl" — or "cycle" through all six
			"kinds": ["iris", "dissolve", "checker", "curtain", "slide", "swirl"],
			"hold": 2.4,                 # seconds each scene sits before the next cut
			"dur": 1.1,                  # seconds one transition takes
			"cells": 14,                 # dissolve / checker cells across the width
			"turns": 3,                  # laps of the swirl's spiral
			"label": "frame = new scene + old frame · mask(k) — the shape of the hole IS the transition" },
		"rhyme": { "name": "Irisout", "hint": "one slow spiral wipe, three laps out from the centre, a long hold either side — the RPG battle entry",
			"dials": { "kind": "swirl", "dur": 2.6, "hold": 3.2 } },
		"shader": "res://shaders/stage/iris.gdshader" },
	{ "id": "hurt", "letter": "H", "name": "Hurt",
		"hint": "red edges whose alpha follows health, pulsing on a heartbeat that quickens as health falls — the atlas's Vignette, wounded — press to take a hit",
		"dials": { "hitEvery": 2.6,      # seconds between the slime's lunges
			"dmg": 0.24,                 # health lost per hit (of 1)
			"regen": 0.05,               # health regrown per second, once left alone
			"inner": 0.45,               # where the red starts, as a fraction of the corner radius
			"maxA": 0.9,                 # the vignette's alpha at zero health
			"bpmLow": 45, "bpmHigh": 170,   # the heartbeat at full health, and at none
			"colour": "#D8262E",         # the edge colour
			"frost": 0,                  # 0..1: ice creeping in at the corners as health falls
			"label": "α = maxA · (1 − hp)^1.2 · beat(φ)  ·  bpm = lerp(45, 170, 1 − hp)" },
		"rhyme": { "name": "Hypothermia", "hint": "blue edges, a slow heavy pulse and frost creeping in at the corners — cold, not blood",
			"dials": { "colour": "#4FA3D8", "bpmHigh": 75, "frost": 1 } } },
	{ "id": "crt", "letter": "C", "name": "Crt",
		"hint": "CRT: sample from uv + uv·|uv|²·curve (the barrel), darken every other row, stripe RGB phosphors, rim with a vignette — press to change the curve",
		"dials": { "curve": 0.12,        # how much the corners bend inward
			"curves": [0.04, 0.12, 0.22, 0.34],   # what a press cycles through
			"scan": 0.35,                # scanline darkness (every other row)
			"mask": 0.18,                # the RGB phosphor stripe strength
			"vig": 0.4,                  # corner darkening
			"bloom": 0.3,                # how much bright neighbours bleed sideways
			"scale": 0.5,                # the pixel pass runs at this fraction of the canvas
			"label": "uv' = uv + uv·|uv|²·curve · row % 2 → ×(1 − scan) · col % 3 → rgb mask" },
		"rhyme": { "name": "Cathode", "hint": "a strong curve and heavy scanlines, no phosphor mask — the arcade cabinet from across the room",
			"dials": { "curve": 0.3, "scan": 0.6, "mask": 0 } },
		"shader": "res://shaders/stage/crt.gdshader" },
	{ "id": "ordered", "letter": "O", "name": "Ordered",
		"hint": "ordered dither: a Bayer matrix of thresholds tiled over the frame quantises brightness to on/off — the Game Boy look — press to cycle 2×2 / 4×4 / 8×8",
		"dials": { "size": 4,            # the Bayer matrix: 2, 4 or 8
			"sizes": [2, 4, 8],          # what a press cycles through
			"levels": 4,                 # output shades (2 = 1-bit)
			"dark": "#0F380F", "light": "#9BBC0F",   # the two ends of the shade ramp
			"scale": 0.5,                # the pixel pass runs at this fraction of the canvas
			"label": "q = ⌊v⌋ + (frac(v) > (M[y%n][x%n] + ½) / n²) · v = lum · (levels − 1)" },
		"rhyme": { "name": "Obsidian", "hint": "1-bit, near-black on the same pale green, at a fifth of the resolution — a pocket LCD, two colours and a coarse grid",
			"dials": { "levels": 2, "scale": 0.22, "dark": "#15161A" } },
		"shader": "res://shaders/stage/ordered.gdshader" },
	{ "id": "quantise", "letter": "Q", "name": "Quantise",
		"hint": "palette quantise: every pixel snaps to the nearest of N colours — by luma or by RGB distance — the swatches drawn — press to cycle palettes",
		"dials": { "palette": ["#0F380F", "#306230", "#8BAC0F", "#9BBC0F"],   # the starting palette: four Game Boy greens
			"more": [["#000000", "#1D2B53", "#7E2553", "#008751", "#AB5236", "#5F574F", "#C2C3C7", "#FFF1E8", "#FF004D", "#FFA300", "#FFEC27", "#00E436", "#29ADFF", "#83769C", "#FF77A8", "#FFCCAA"],   # a 16-colour fantasy console
				["#000000", "#0000AA", "#00AA00", "#00AAAA", "#AA0000", "#AA00AA", "#AA5500", "#AAAAAA", "#555555", "#5555FF", "#55FF55", "#55FFFF", "#FF5555", "#FF55FF", "#FFFF55", "#FFFFFF"],   # the 16 EGA colours
				["#2B0F54", "#AB1F65", "#FF4F69", "#FFF7F8", "#FF8142", "#FFDA45", "#3368DC", "#49E7EC"]],   # eight, hot
			"mode": "luma",              # "luma": by brightness rank · "nearest": by RGB distance
			"scale": 0.5,                # the pixel pass runs at this fraction of the canvas
			"label": "luma: p[⌊L · N⌋] (sorted by brightness)  ·  nearest: argminᵢ |rgb − pᵢ|²" },
		"rhyme": { "name": "Quartz", "hint": "eight pastel colours chosen by RGB distance — a candy palette in nearest mode",
			"dials": { "palette": ["#F6E7EE", "#F2C4D8", "#C9B6E4", "#A8D8EA", "#B5EAD7", "#FFF3B0", "#FFC6A5", "#7C6C8C"], "mode": "nearest" } },
		"shader": "res://shaders/stage/quantise.gdshader" },
	{ "id": "cycle", "letter": "C", "name": "Cycle",
		"hint": "palette cycling: the picture is indices, not colours; shift the palette each frame and the still waterfall flows (Mark Ferrari) — press to reverse",
		"dials": { "palette": "water",   # which palette the indices look up: "water" | "fire"
			"palettes": { "water": ["#0B2A5C", "#123C7A", "#1A4E98", "#2261B4", "#2F78CC", "#4A93DD", "#6FB0EA", "#9CCDF4", "#D7ECFB", "#FFFFFF", "#7FB6E8", "#3D7EC9"],
				"fire": ["#1A0700", "#3A0E00", "#6A1A00", "#9A2E00", "#C64A08", "#E8701A", "#F79A2A", "#FFC24A", "#FFE58A", "#FFF7C8", "#F5A030", "#C04010"] },
			"speed": 7,                  # palette entries shifted per second (negative flows the other way)
			"scale": 0.5,                # the pixel pass runs at this fraction of the canvas
			"label": "colour = pal[(index + shift) mod n] — the pixels never move, the palette does" },
		"rhyme": { "name": "Campfire", "hint": "the same index map through a fire palette, shifting the other way and faster — the waterfall becomes a column of flame",
			"dials": { "palette": "fire", "speed": -12 } },
		"shader": "res://shaders/stage/cycle.gdshader" },
	{ "id": "xsplit", "letter": "X", "name": "Xsplit",
		"hint": "chromatic aberration: R and B read from offsets that grow toward the edges, G in place — the grimoire's RGB split, frame-wide — press: split by distance",
		"dials": { "split": 0.05,        # the offset at the corners, as a fraction of the buffer width
			"power": 2,                  # how the offset grows with distance from the centre (|uv|^power)
			"pulse": 0,                  # 0..1: a glitch pulse that tears rows sideways every pulseEvery seconds
			"pulseEvery": 1.6,
			"scale": 0.5,                # the pixel pass runs at this fraction of the canvas
			"label": "o = split · |uv|^p · û   ·   R(p − o)  G(p)  B(p + o)" },
		"rhyme": { "name": "Xtreme", "hint": "a huge split and a glitch pulse that tears rows sideways — the broken-lens boss intro",
			"dials": { "split": 0.18, "pulse": 1 } },
		"shader": "res://shaders/stage/xsplit.gdshader" },
	{ "id": "refract", "letter": "R", "name": "Refract",
		"hint": "distortion: each texel is read from p − field(p) — heat noise over a fire, an expanding shockwave ring, water rows (ch06's shockwave) — press to fire one",
		"dials": { "kind": "heat",       # the standing field: "heat" (noise above a fire) | "water" (sine rows below a line) | "none"
			"amp": 0.03,                 # the standing field's push, as a fraction of the buffer width
			"ringAmp": 0.05,             # a shockwave's push at birth
			"ringW": 0.07,               # a ring's thickness, of the width
			"ringSpeed": 0.7,            # how fast a ring grows, in widths per second
			"ringEvery": 2.2,            # autopilot: one shockwave every so often
			"waterY": 0.5,               # the water line, as a fraction of H (kind "water")
			"scale": 0.5,                # the pixel pass runs at this fraction of the canvas
			"label": "p' = p − field(p) · shock: amp·sin(π(d − r)/w)·r̂ · heat: noise(p, t) · water: sin rows" },
		"rhyme": { "name": "Ripplewave", "hint": "kind water: the lower half refracts on sine rows, and slow rings spread from every drop",
			"dials": { "kind": "water", "ringSpeed": 0.22, "ringEvery": 1.6 } },
		"shader": "res://shaders/stage/refract.gdshader" },
	{ "id": "zoomblur", "letter": "Z", "name": "Zoomblur",
		"hint": "radial blur: average N samples along the line to a centre — speed lines when the hero dashes, the folio's Zoom as a pass — press to set the centre",
		"dials": { "samples": 8,         # reads per pixel along the line to the centre
			"strength": 0.35,            # how far toward the centre the last sample sits (fraction of the distance)
			"dashEvery": 2.6,            # seconds between dashes
			"dashDur": 0.45,             # how long a dash (and full blur) lasts
			"dashSpeed": 1.6,            # the dash, in widths per second
			"decay": 4,                  # how fast the blur fades after (per second)
			"scale": 0.5,                # the pixel pass runs at this fraction of the canvas
			"label": "out = mean₀..N of src(p + (c − p) · i/N · reach)  ·  reach = strength · amount" },
		"rhyme": { "name": "Zoomimpact", "hint": "a hard hit instead of a dash: strong blur that slams in for a frame and decays away — the impact frame",
			"dials": { "strength": 0.75, "dashDur": 0.06, "decay": 2.2 } },
		"shader": "res://shaders/stage/zoomblur.gdshader" },
	{ "id": "godrays", "letter": "G", "name": "Godrays",
		"hint": "god rays: threshold the bright pixels, smear them toward the sun, add them back — the trees cut the shafts (the atlas's Motes) — press to move the sun",
		"dials": { "threshold": 205,     # luminance above this counts as light
			"samples": 12,               # steps toward the sun per pixel
			"density": 0.7,              # how far toward the sun the last step reaches (fraction of the distance)
			"weight": 0.6,               # how much of the smear is added back
			"decay": 0.9,                # each step counts this much less than the last
			"sunY": 0.32,                # the sun's height, as a fraction of H
			"sunCol": "#FFF0B8",         # the colour the rays add
			"drift": 0.05,               # the sun's wander, in cycles per second
			"scale": 0.5,                # the pixel pass runs at this fraction of the canvas
			"label": "bright = lum > T · rays = Σᵢ bright(p + (sun − p)·i/N·density)·decayⁱ · out = src + w·rays" },
		"rhyme": { "name": "Gloaming", "hint": "a low red sun and long dim rays through the trees — the last light of the day",
			"dials": { "sunCol": "#FF6A45", "sunY": 0.64, "density": 0.95 } },
		"shader": "res://shaders/stage/godrays.gdshader" },
	{ "id": "kelvin", "letter": "K", "name": "Kelvin",
		"hint": "colour grading: saturation, then a per-channel curve — contrast, warmth, posterise — the three curves drawn (the atlas's Old photo, live) — press to cycle",
		"dials": { "grade": "none",      # the preset in use: "none" | "sepia" | "night" | "danger" | "posterise" | "custom"
			"presets": { "none": { "contrast": 1, "sat": 1, "warm": 0, "levels": 0 },
				"sepia": { "contrast": 1.05, "sat": 0.12, "warm": 0.55, "levels": 0 },
				"night": { "contrast": 0.9, "sat": 0.5, "warm": -0.8, "levels": 0 },
				"danger": { "contrast": 1.25, "sat": 0.55, "warm": 0.9, "levels": 0 },
				"posterise": { "contrast": 1.1, "sat": 1.3, "warm": 0, "levels": 4 } },
			"custom": { "contrast": 1, "sat": 1, "warm": 0, "levels": 0 },   # the "custom" grade: yours to turn
			"order": ["none", "sepia", "night", "danger", "posterise"],   # what a press cycles through
			"scale": 0.5,                # the pixel pass runs at this fraction of the canvas
			"label": "c' = lum + (c − lum)·sat → LUTc: (c' − 128)·contrast + 128 ± warm → ⌊·L⌋/L" },
		"rhyme": { "name": "Kodachrome", "hint": "the custom grade: high saturation, warm, six posterise levels — slide film",
			"dials": { "grade": "custom", "custom": { "contrast": 1.15, "sat": 1.7, "warm": 0.35, "levels": 6 } } },
		"shader": "res://shaders/stage/kelvin.gdshader" },
	{ "id": "yesteryear", "letter": "Y", "name": "Yesteryear",
		"hint": "film grain, live: per-pixel noise, an exposure flicker, gate weave (the frame jitters a pixel), wandering scratches — the folio's Oldfilm — press: grain / static",
		"dials": { "mode": "grain",      # "grain" (film) | "static" (TV snow)
			"grain": 0.2,                # noise amplitude, of full brightness
			"snow": 0.7,                 # static mode: how much of the picture the snow replaces
			"scratches": 3,              # vertical scratches wandering at once
			"weave": 1.5,                # GATE WEAVE: the frame jitters by up to this many canvas pixels
			"weaveHz": 14,               # how often the weave picks a new offset
			"flicker": 0.1,              # exposure flicker, ± this fraction
			"sepia": 0,                  # 0..1: pull colours toward an old print
			"scale": 0.5,                # the pixel pass runs at this fraction of the canvas
			"label": "v' = v(p + weave) · flicker + (n − ½)·grain → sepia   ·   scratches wander on noise" },
		"rhyme": { "name": "Yellowed", "hint": "a sepia tint, seven scratches and a slow weave — the reel left in the attic",
			"dials": { "sepia": 0.85, "scratches": 7, "weaveHz": 3 } },
		"shader": "res://shaders/stage/yesteryear.gdshader" },
	{ "id": "mosh", "letter": "M", "name": "Mosh",
		"hint": "VHS / datamosh: row blocks of the held frame shifted, a rolling tracking bar, chroma bleed, a frame-hold — the grimoire's Sync loss, live — press to corrupt",
		"dials": { "every": 2.4,         # autopilot: seconds between corruptions
			"hold": 0.45,                # FRAME-HOLD: how long the last good frame is shown instead of the live one
			"block": 8,                  # row block height, canvas pixels
			"shift": 0.1,                # a displaced block's slide, as a fraction of the width
			"bleed": 2,                  # chroma offset in buffer pixels (R left, B right)
			"track": 0.35,               # the tracking bar's strength
			"trackSpeed": 0.2,           # how fast the bar rolls, screens per second
			"scale": 0.5,                # the pixel pass runs at this fraction of the canvas
			"label": "rows[b] ← x − shift·hash(b) · R(x − bleed) G(x) B(x + bleed) · hold: show frame t−1" },
		"rhyme": { "name": "Magnetic", "hint": "tracking only: no block shifts, no hold, a hair of bleed — a worn tape playing fine",
			"dials": { "shift": 0, "hold": 0, "bleed": 1 } },
		"shader": "res://shaders/stage/mosh.gdshader" },
]

const FAINT := Color(0.91, 0.898, 0.957, 0.55)   # the web label's default ink
const MARKER := Color(0.0, 0.0, 1.0)             # Cycle's index marker: g = 0, b = 255, as on the web
const ROCK := Color("3A3550")
const IRIS_KINDS := { "iris": 1, "dissolve": 2, "checker": 3, "curtain": 4, "slide": 5, "swirl": 6 }   # the shader's codes
const HURT_TRACE := 72                            # samples in the pulse trace

## A number for a label: "1" for whole values, "0.35" otherwise (JS's "" + k).
static func _num(v: float) -> String:
	return ("%d" % roundi(v)) if v == roundf(v) else ("%s" % v)

## The web label's "right" alignment: measure, then draw ending at p.x.
static func _label_right(n: CanvasItem, b: Dictionary, txt: String, p: Vector2, col: Color) -> void:
	var f := ThemeDB.fallback_font
	var w: float = f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	Kit.label(n, b, txt, Vector2(p.x - w, p.y), col)

## The web kit's ease(k): smoothstep, clamped.
static func _ease(k: float) -> float:
	k = clampf(k, 0.0, 1.0)
	return k * k * (3.0 - 2.0 * k)

## The web's hsl(h, s, l) → a Color (h in degrees).
static func _hsl(h: float, s: float, l: float) -> Color:
	var c := (1.0 - absf(2.0 * l - 1.0)) * s
	var hp := fposmod(h, 360.0) / 60.0
	var x := c * (1.0 - absf(fmod(hp, 2.0) - 1.0))
	var m := l - c / 2.0
	var rgb := Vector3(c, x, 0.0)
	if hp >= 1.0 and hp < 2.0:
		rgb = Vector3(x, c, 0.0)
	elif hp >= 2.0 and hp < 3.0:
		rgb = Vector3(0.0, c, x)
	elif hp >= 3.0 and hp < 4.0:
		rgb = Vector3(0.0, x, c)
	elif hp >= 4.0 and hp < 5.0:
		rgb = Vector3(x, 0.0, c)
	elif hp >= 5.0:
		rgb = Vector3(c, 0.0, x)
	return Color(rgb.x + m, rgb.y + m, rgb.z + m)

static func _lum(c: Color) -> float:
	return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b

## The hero's patrol: back and forth between lo·W and hi·W at speed·W per second.
static func _walk(b: Dictionary, dt: float, speed: float, lo: float, hi: float) -> void:
	var W: float = b.w
	b.hx += b.hdir * W * speed * dt
	if b.hx > W * hi:
		b.hdir = -1
	elif b.hx < W * lo:
		b.hdir = 1

## A ring between two radii with a colour per rim — the web's radial
## gradient stops, one pair at a time (Hurt's vignette and frost).
static func _annulus(n: CanvasItem, c: Vector2, r0: float, c0: Color, r1: float, c1: Color, segs: int = 48) -> void:
	if r1 <= r0 + 0.01:
		return
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	for i in segs + 1:
		var ang := i / float(segs) * TAU
		var d := Vector2(cos(ang), sin(ang))
		pts.append(c + d * maxf(0.0, r0))
		cols.append(c0)
		pts.append(c + d * r1)
		cols.append(c1)
	for i in segs:
		var a := i * 2
		idx.append(a)
		idx.append(a + 1)
		idx.append(a + 2)
		idx.append(a + 1)
		idx.append(a + 3)
		idx.append(a + 2)
	RenderingServer.canvas_item_add_triangle_array(n.get_canvas_item(), idx, pts, cols)

## A palette as the shader's vec4[16], padded.
static func _pal16(pal: Array) -> PackedColorArray:
	var out := PackedColorArray()
	for i in 16:
		out.append(pal[i] if i < pal.size() else Color.BLACK)
	return out

## Ordered's Bayer matrix, built as the web builds it: [[0,2],[3,1]], then
## each cell ×4 + that same pattern, until it is nn × nn.
static func _bayer(nn: int) -> Array:
	var m: Array = [[0]]
	var s := 1
	while s < nn:
		var nm: Array = []
		for y in s * 2:
			var row: Array = []
			for x in s * 2:
				var base: int = m[y % s][x % s]
				var pat: int = [0, 2, 3, 1][(0 if y < s else 2) + (0 if x < s else 1)]
				row.append(base * 4 + pat)
			nm.append(row)
		m = nm
		s *= 2
	return m

## Quantise: adopt a palette — as colours, and sorted by brightness.
static func _quantise_use(b: Dictionary, hexes: Array) -> void:
	var pal: Array = []
	for hx in hexes:
		pal.append(Color(hx))
	b.pal = pal
	var by_lum: Array = pal.duplicate()
	by_lum.sort_custom(func(p: Color, q: Color) -> bool: return _lum(p) < _lum(q))
	b.by_lum = by_lum

## Kelvin: the grade in use (a preset, or the custom one).
static func _kelvin_params(b: Dictionary) -> Dictionary:
	var D: Dictionary = b.D
	if b.cur == "custom":
		return D.custom
	var presets: Dictionary = D.presets
	return presets.get(b.cur, presets.none)

## Kelvin: one channel's curve at v (0..255) — the web's LUT entry.
static func _kelvin_curve(v: float, ch: int, p: Dictionary) -> float:
	var L: int = maxi(0, int(p.levels) - 1)
	var tilt := 45.0 if ch == 0 else (-45.0 if ch == 2 else -6.0)
	var x: float = (v - 128.0) * float(p.contrast) + 128.0 + float(p.warm) * tilt
	if L > 0:
		x = roundf(x / 255.0 * L) / L * 255.0
	return clampf(x, 0.0, 255.0)

static func _hurt_hit(b: Dictionary) -> void:
	var D: Dictionary = b.D
	b.hp = maxf(0.04, b.hp - D.dmg)
	b.flash = 1.0
	b.lunge = 1.0
	b.since = 0.0

static func _refract_shock(b: Dictionary, p: Vector2) -> void:
	var D: Dictionary = b.D
	b.rings.append({ "x": p.x, "y": p.y, "r": 2.0, "a": float(D.ringAmp) })
	if b.rings.size() > 6:
		b.rings.pop_front()

static func _mosh_corrupt(b: Dictionary) -> void:
	var D: Dictionary = b.D
	b.corrupt = 1.0
	b.holdT = float(D.hold)
	var R := Kit.rng(randi())
	for i in 64:                                     # which blocks slide, and how far
		b.blk[i] = (R.randf() - 0.5) * 2.0 if R.randf() < 0.55 else 0.0

## The scene most of the pass cards share: a night-ish stage, a tree, a
## crate, a lit lamp with its glow, the hero running. (The web draws the
## glow with "lighter"; Godot 2D has no per-draw additive blend without a
## material, so it is the same glow alpha-blended — a little less hot.)
static func _lamp_scene(n: CanvasItem, b: Dictionary, t: float, night: float, lamp_x: float, glow_on: bool, hx: float, hdir: int) -> void:
	var W: float = b.w
	var H: float = b.h
	var GY: float = b.gy
	Kit.stage(n, b, night)
	Kit.tree(n, Vector2(W * 0.15, GY), H * 0.28)
	Kit.crate(n, Vector2(W * 0.84, GY), H * 0.12)
	if glow_on:
		Kit.glow(n, Vector2(lamp_x, GY - H * 0.3 - 8.0), H * 0.32, Kit.SUN, 0.5)
	Kit.lamp(n, b, Vector2(lamp_x, GY), true)
	Kit.hero(n, b, Vector2(hx, GY), { "pose": "run", "frame": t, "face": hdir })

static func init(b: Dictionary) -> void:
	var D: Dictionary = b.D
	var W: float = b.w
	var H: float = b.h
	var GY: float = b.gy
	match b.id:
		"iris":
			# a SCREEN TRANSITION never touches either scene. the frame about to leave
			# is COPIED into a layer, the new scene is drawn underneath it, and a hole
			# is cut out of the copy (destination-out) that grows with k = 0 → 1. the
			# whole family is one question — what shape is the hole: a circle (iris),
			# cells in a hashed order (pixel dissolve), squares growing in two waves
			# (checkerboard), a rect opening from the centre (curtain), the copy just
			# translated (slide), ring-sectors sweeping lap by lap (swirl). chapter
			# 03's masks and the folio's Pixelate, grown into a cut between scenes.
			# HERE the hole is decided per pixel in iris.gdshader; the painter draws
			# the day scene and the shader dresses it as night on whichever side of
			# the mask is the night scene (see the shader's header).
			b.scene = 0                              # 0 = day, 1 = night
			b.k = -1.0                               # the transition's progress; < 0 = holding
			b.wait = float(D.hold) * 0.5
			b.ki = 0
			b.kind_cur = str((D.kinds as Array)[0])
			b.cx = W / 2.0
			b.cy = H * 0.45
			b.rmax = 1.0
			b.hx = W * 0.3
			b.hdir = 1
		"hurt":
			# the DAMAGE VIGNETTE is the atlas's Vignette with its alpha wired to a
			# number: a radial gradient, clear inside, colour at the corners, its
			# strength (1 − hp)^1.2 so it barely shows above half health and floods
			# below a quarter. the LOW-HEALTH PULSE is a heartbeat — two bumps per
			# beat, exp(−p²·90) and a smaller echo — whose rate rises as health falls,
			# so the screen's breathing tells you the number before the bar does. a
			# hit adds a flash and a shake; regen drains the whole thing back.
			var R := Kit.rng(5)
			b.ice = []
			for i in 28:
				b.ice.append({ "c": i & 3, "a": R.randf() * TAU / 4.0, "l": 0.08 + R.randf() * 0.12, "w": 0.5 + R.randf() })
			b.trace = []
			for _i in HURT_TRACE:
				b.trace.append(0.0)
			b.ti = 0
			b.hp = 1.0
			b.phase = 0.0
			b.flash = 0.0
			b.since = 9.0
			b.lunge = 0.0
			b.timer = 1.2
			b.beat = 0.0
			b.bpm = float(D.bpmLow)
			b.a = 0.0
		"crt":
			# a CRT in one pass over the bytes. BARREL CURVATURE is a lookup: the
			# output pixel at uv (−1..1) reads the SOURCE at uv + uv·|uv|²·curve, so
			# the corners reach past the picture and go black — the bezel appears by
			# itself. SCANLINES darken every other row of the small buffer; the
			# PHOSPHOR MASK boosts one channel per column (r, g, b, r, g, b…); the
			# VIGNETTE multiplies by 1 − vig·|uv|⁴; a hair of BLOOM adds the bright
			# left and right neighbours. the folio's Hologram, grown to a whole frame.
			b.curve = float(D.curve)
			b.hx = W * 0.3
			b.hdir = 1
		"ordered":
			# ORDERED DITHER trades shades for pattern. a BAYER MATRIX is an n×n grid
			# of thresholds arranged so every 2×2 block already holds a spread of
			# values (built recursively: [[0,2],[3,1]], then each cell ×4 + that same
			# pattern). tile it over the frame; a pixel turns on where its brightness
			# beats the threshold under it. with more than two levels the same test
			# decides between the two nearest shades. no memory, no neighbours — one
			# lookup per pixel — which is why a 1989 hand-held could afford it.
			b.n = int(D.size)
			b.M = _bayer(b.n)
			b.hx = W * 0.3
			b.hdir = 1
		"quantise":
			# PALETTE QUANTISE: the frame may only use N colours. two ways to choose.
			# by LUMA: sort the palette by brightness and index it with the pixel's
			# brightness — cheap, and it keeps gradients ordered, which is why the
			# Game Boy greens read as shading. by NEAREST: the palette colour with the
			# smallest squared RGB distance — right for coloured palettes, and worth
			# a lookup table (here 5 bits per channel, filled as pixels arrive) so the
			# per-pixel cost stays one read. no dither: the bands are the point.
			b.list = [D.palette] + (D.more as Array)
			b.pi = 0
			_quantise_use(b, b.list[0])
			b.hx = W * 0.3
			b.hdir = 1
		"cycle":
			# PALETTE CYCLING is the oldest animation that draws nothing. the picture
			# is an INDEX MAP — every pixel stores a number, not a colour — and the
			# colour lives in a PALETTE the screen reads through. rotate the palette
			# by one entry per tick and every band moves one step, forever, for free.
			# here the map is drawn ONCE into a layer with the index hidden in the red
			# channel (r = i·16, g = 0, b = 255 as the marker); the pass finds those
			# pixels and looks them up through the shifted palette. the folio's Vapor
			# did the same with rows; Mark Ferrari did whole skies. (the Godot painter
			# lays the marker down; cycle.gdshader computes the index from the same
			# formula — streaks, noise, rings — where it sees it.)
			var palettes: Dictionary = D.palettes
			var hexes: Array = palettes.get(D.palette, palettes.water)
			b.pal = []
			for hx in hexes:
				b.pal.append(Color(hx))
			b.shift = 0.0
			b.off = 0                                # draw reads it before the first tick (and after a rhyme swap)
			b.dir = 1
			b.hx = W * 0.72
			b.hdir = -1
			b.x0 = W * 0.38                          # the waterfall column
			b.x1 = W * 0.56
			b.yt = H * 0.12
			b.pcx = W * 0.47                         # the pool
			b.pcy = GY + (H - GY) * 0.45
			b.prx = W * 0.22
			b.pry = (H - GY) * 0.5
		"xsplit":
			# CHROMATIC ABERRATION is a lens failing to focus every wavelength at the
			# same spot: red lands a little outside, blue a little inside. as a pass
			# it is three reads instead of one — red from p − o, green from p, blue
			# from p + o — where o points away from the centre and GROWS with
			# |uv|^power, so the middle stays sharp and the corners fringe. the
			# grimoire split one glyph; here the whole frame is the glyph. the pulse
			# tears rows sideways for a few frames — the "glitch" everyone means.
			b.split = float(D.split)
			b.g = 0.0
			b.timer = float(D.pulseEvery)
			b.seed = 1.0
			b.hx = W * 0.3
			b.hdir = 1
		"refract":
			# SCREEN-SPACE DISTORTION: every output pixel reads the scene from
			# somewhere slightly else, p − field(p). the picture is untouched; only
			# the READ ADDRESSES bend. HEAT is a noise field inside a cone above the
			# fire, scrolling upward and fading with height (the bestiary's Heat haze,
			# as a pass). a SHOCKWAVE is a ring: inside its band the push is radial,
			# amp·sin(π·(d − r)/w), so the ring magnifies on one side and shrinks on
			# the other as it grows — chapter 06's ring made of displacement. WATER
			# is the cheapest: one sine per row, one per column, below a line.
			b.rings = []
			b.timer = 0.8
			b.hx = W * 0.65
			b.hdir = 1
			b.fx = W * 0.3
			b.fy = GY - 4.0
		"zoomblur":
			# RADIAL (zoom) BLUR: for every pixel, walk N steps along the line from
			# it to a CENTRE and average what you find. near the centre the steps
			# are tiny, so it stays sharp; at the edges they stretch into streaks —
			# the camera rushing forward, or the folio's Zoom happening to the whole
			# frame. the amount is an envelope: it slams to 1 while the hero dashes
			# and decays exponentially after, so the blur reads as speed, not as a
			# filter left on. N is the cost — 8 reads per pixel here.
			b.hx = W * 0.25
			b.hdir = 1
			b.amount = 0.0
			b.dashing = 0.0
			b.timer = 1.0
			b.cx = W * 0.6
			b.cy = H * 0.5
			b.userT = 0.0
		"godrays":
			# GOD RAYS (crepuscular rays) are a radial blur that only the light is
			# allowed into. THRESHOLD: a mask of the pixels brighter than T — the sun
			# and little else. SMEAR: from every pixel, step toward the sun's screen
			# position N times, summing the mask with a decay per step. ADD: pour the
			# sum back onto the frame in the sun's colour. anything dark between a
			# pixel and the sun (the trees, the hero) leaves a hole in its sum, and
			# those holes are the shafts. the atlas's Motes, made of light itself.
			b.ux = W * 0.5
			b.uy = H * float(D.sunY)
			b.sx = b.ux
			b.sy = b.uy
			b.hx = W * 0.4
			b.hdir = 1
		"kelvin":
			# COLOUR GRADING is a function of colour applied to every pixel, and most
			# of it is PER-CHANNEL: contrast (stretch about the middle), warmth (a
			# Kelvin-ish tilt: red up and blue down, or the reverse), and POSTERISE
			# (round to L steps). anything per-channel can be baked into three
			# 256-entry LOOKUP TABLES — the three curves drawn at the top right — so
			# the pass is three reads. SATURATION mixes channels (toward or away from
			# the pixel's luminance), so it runs first, before the tables. the atlas
			# faked an old photo with a tint; this is the tint as arithmetic.
			b.cur = str(D.grade)
			b.hx = W * 0.3
			b.hdir = 1
		"yesteryear":
			# FILM GRAIN is noise added per pixel PER FRAME — never the same twice,
			# which is the whole difference from a grain texture pasted on top. the
			# pass also does GATE WEAVE (read the source a pixel or so off, the
			# offset re-rolled a few times a second: the film not sitting still in
			# the gate), an exposure FLICKER (one multiplier per frame from slow
			# noise), and a SEPIA pull toward an old print. STATIC swaps the grain
			# for TV snow that replaces the picture. the scratches are lines drawn
			# after the pass, wandering on noise — the folio's Oldfilm, live.
			b.mode = str(D.mode)
			b.jx = 0.0
			b.jy = 0.0
			b.wt = 0.0
			b.frame = 0
			b.flick = 1.0
			b.hx = W * 0.3
			b.hdir = 1
		"mosh":
			# tape damage, as three separate lies. a FRAME-HOLD: the decoder lost a
			# frame, so it shows the previous one again (a layer kept from last
			# frame) while the world moves on — release it and the picture jumps.
			# BLOCK DISPLACEMENT: rows in blocks of `block` pixels slide sideways by
			# a hashed amount that decays — the datamosh smear. And always on: a
			# TRACKING BAR rolling up the frame (rows jittered, brightened, noisy),
			# CHROMA BLEED (red read a little left, blue a little right — the tape
			# stored colour at lower resolution), and head-switching noise on the
			# bottom rows. the grimoire's Sync loss and the folio's Glitch, live.
			# (the held frame here is the scene's own state, kept from the last
			# good tick and redrawn — the scene is procedural, so that IS the frame.)
			b.blk = []
			for _i in 64:
				b.blk.append(0.0)
			b.corrupt = 0.0
			b.holdT = 0.0
			b.timer = float(D.every) * 0.6
			b.have_prev = false
			b.prev = { "hx": W * 0.3, "hdir": 1, "t": 0.0 }
			b.holding = false
			b.hx = W * 0.3
			b.hdir = 1

static func press(b: Dictionary, pos: Vector2) -> void:
	var D: Dictionary = b.D
	var W: float = b.w
	var H: float = b.h
	match b.id:
		"iris":
			b.cx = pos.x
			b.cy = pos.y
			if b.k >= 0.0:
				b.k = -1.0
			b.wait = 0.0
		"hurt":
			_hurt_hit(b)
		"crt":
			var curves: Array = D.curves
			b.curve = float(curves[(curves.find(b.curve) + 1) % curves.size()])
		"ordered":
			var sizes: Array = D.sizes
			b.n = int(sizes[(sizes.find(b.n) + 1) % sizes.size()])
			b.M = _bayer(b.n)
		"quantise":
			b.pi = (b.pi + 1) % (b.list as Array).size()
			_quantise_use(b, b.list[b.pi])
		"cycle":
			b.dir = -b.dir
		"xsplit":
			b.split = clampf((pos - Vector2(W / 2.0, H / 2.0)).length() / (0.5 * minf(W, H)), 0.0, 1.0) * 0.2
		"refract":
			_refract_shock(b, pos)
		"zoomblur":
			b.cx = pos.x
			b.cy = pos.y
			b.userT = 8.0
		"godrays":
			b.ux = pos.x
			b.uy = clampf(pos.y, H * 0.05, b.gy - H * 0.05)
		"kelvin":
			var order: Array = D.order
			var cyc: Array = order if order.has(D.grade) else order + [D.grade]
			b.cur = str(cyc[(cyc.find(b.cur) + 1) % cyc.size()])
		"yesteryear":
			b.mode = "static" if b.mode == "grain" else "grain"
		"mosh":
			_mosh_corrupt(b)

static func tick(b: Dictionary, dt: float, t: float) -> void:
	var D: Dictionary = b.D
	var W: float = b.w
	var H: float = b.h
	var GY: float = b.gy
	match b.id:
		"iris":
			_walk(b, dt, 0.16, 0.22, 0.78)
			var kinds: Array = D.kinds
			if b.k < 0.0:
				b.wait -= dt
				if b.wait <= 0.0:                    # the cut starts: "capture" this frame, flip the scene
					if D.kind == "cycle":
						b.kind_cur = str(kinds[b.ki % kinds.size()])
						b.ki = (b.ki + 1) % kinds.size()
					else:
						b.kind_cur = str(D.kind)
					var mx: float = maxf(b.cx, W - b.cx)
					var my: float = maxf(b.cy, H - b.cy)
					b.rmax = sqrt(mx * mx + my * my) + 2.0   # the far corner, so the hole can reach it
					b.scene = 1 - b.scene
					b.k = 0.0
			if b.k >= 0.0:
				b.k = minf(1.0, b.k + dt / maxf(0.05, float(D.dur)))
				if b.k >= 1.0:
					b.k = -1.0
					b.wait = float(D.hold)
			var cutting: bool = b.k >= 0.0
			b.uniforms = { "card_size": Vector2(W, H),
				"kind": int(IRIS_KINDS.get(b.kind_cur, 0)) if cutting else 0,
				"e": _ease(b.k) if cutting else 1.0,
				"centre": Vector2(b.cx, b.cy), "rmax": float(b.rmax),
				"cells": int(D.cells), "turns": int(D.turns),
				"in_night": b.scene == 1, "out_night": b.scene == 0,   # inside the hole: the new scene; outside: the old
				"bulb": Kit.lamp_bulb(b, Vector2(W * 0.62, GY)), "glow_r": H * 0.35 }
		"hurt":
			b.timer -= dt
			if b.timer <= 0.0:
				_hurt_hit(b)
				b.timer = float(D.hitEvery)
			b.since += dt
			if b.since > 1.5:                        # regen, once left alone
				b.hp = minf(1.0, b.hp + float(D.regen) * dt)
			b.flash = maxf(0.0, b.flash - dt * 3.0)
			b.lunge = maxf(0.0, b.lunge - dt * 2.5)
			var hp: float = b.hp
			var bpm: float = lerpf(float(D.bpmLow), float(D.bpmHigh), 1.0 - hp)   # the rate follows the wound
			b.phase = fposmod(b.phase + bpm / 60.0 * dt, 1.0)
			var p: float = b.phase
			var beat: float = exp(-p * p * 90.0) + 0.55 * exp(-(p - 0.2) * (p - 0.2) * 90.0)   # lub, dub
			b.beat = beat
			b.bpm = bpm
			b.a = clampf(float(D.maxA) * pow(1.0 - hp, 1.2) * (0.45 + 0.55 * beat) + b.flash * 0.5, 0.0, 1.0)
			b.trace[b.ti] = beat                     # the pulse, as a trace
			b.ti = (b.ti + 1) % HURT_TRACE
		"crt":
			_walk(b, dt, 0.15, 0.2, 0.8)
			b.uniforms = { "card_size": Vector2(W, H), "scale": float(D.scale), "curve": float(b.curve),
				"scan": float(D.scan), "mask": float(D.mask), "vig": float(D.vig), "bloom": float(D.bloom) }
		"ordered":
			_walk(b, dt, 0.15, 0.2, 0.8)
			b.uniforms = { "card_size": Vector2(W, H), "scale": float(D.scale), "size": int(b.n),
				"levels": int(D.levels), "dark_col": Color(D.dark), "light_col": Color(D.light) }
		"quantise":
			_walk(b, dt, 0.15, 0.2, 0.8)
			var luma: bool = D.mode == "luma"
			var show: Array = b.by_lum if luma else b.pal   # the palette in the order the pass uses it
			b.uniforms = { "card_size": Vector2(W, H), "scale": float(D.scale), "pal": _pal16(show),
				"n": show.size(), "luma": luma }
		"cycle":
			var nn: int = (b.pal as Array).size()
			_walk(b, dt, 0.12, 0.62, 0.92)
			b.shift = fposmod(b.shift - float(D.speed) * b.dir * dt, float(nn))   # ← the whole animation
			var off: int = floori(b.shift) % nn
			b.off = off
			b.uniforms = { "card_size": Vector2(W, H), "scale": float(D.scale), "pal": _pal16(b.pal), "n": nn, "off": off,
				"fall": Vector4(b.x0, b.x1, b.yt, GY), "pool": Vector4(b.pcx, b.pcy, b.prx, b.pry) }
		"xsplit":
			_walk(b, dt, 0.15, 0.2, 0.8)
			b.timer -= dt
			if b.timer <= 0.0:
				b.timer = float(D.pulseEvery)
				if float(D.pulse) > 0.0:
					b.g = float(D.pulse)
					b.seed = randf_range(1.0, 99999.0)
			b.g = maxf(0.0, b.g - dt * 4.0)
			b.uniforms = { "card_size": Vector2(W, H), "scale": float(D.scale), "split": float(b.split),
				"power": float(D.power), "glitch": float(b.g), "seed": float(b.seed) }
		"refract":
			_walk(b, dt, 0.12, 0.5, 0.9)
			b.timer -= dt
			if b.timer <= 0.0:
				b.timer = float(D.ringEvery)
				var ry: float = randf_range(H * float(D.waterY), H * 0.95) if D.kind == "water" else randf_range(H * 0.2, H * 0.8)
				_refract_shock(b, Vector2(randf_range(W * 0.1, W * 0.9), ry))
			var rmax: float = W * 0.6
			var rings: Array = b.rings
			var i := rings.size() - 1
			while i >= 0:
				var q: Dictionary = rings[i]
				q.r += float(D.ringSpeed) * W * dt
				if q.r > rmax:
					rings.remove_at(i)
				i -= 1
			var packed := PackedVector4Array()
			for k in 6:
				if k < rings.size():
					var q2: Dictionary = rings[k]
					packed.append(Vector4(q2.x, q2.y, q2.r, q2.a))
				else:
					packed.append(Vector4.ZERO)
			var kind: int = 1 if D.kind == "heat" else (2 if D.kind == "water" else 0)
			b.uniforms = { "card_size": Vector2(W, H), "scale": float(D.scale), "kind": kind, "amp": float(D.amp),
				"ring_w": float(D.ringW), "rings": packed, "nrings": rings.size(), "rmax": rmax,
				"fire": Vector2(b.fx, b.fy), "water_y": H * float(D.waterY), "time": t }
		"zoomblur":
			b.timer -= dt
			b.userT -= dt
			if b.timer <= 0.0:                       # a dash: the centre goes where the hero is heading
				b.timer = float(D.dashEvery)
				b.dashing = float(D.dashDur)
				if b.userT <= 0.0:
					b.cx = b.hx + b.hdir * W * 0.3
					b.cy = GY - H * 0.12
			if b.dashing > 0.0:
				b.dashing -= dt
				b.hx += b.hdir * W * float(D.dashSpeed) * dt
				b.amount = minf(1.0, b.amount + dt * 14.0)
			else:
				b.hx += b.hdir * W * 0.1 * dt
				b.amount *= exp(-float(D.decay) * dt)
			if b.hx > W * 0.85:
				b.hx = W * 0.85
				b.hdir = -1
			elif b.hx < W * 0.15:
				b.hx = W * 0.15
				b.hdir = 1
			var reach: float = float(D.strength) * b.amount
			b.shader_on = b.amount > 0.02             # the pass is skipped when there is nothing to blur
			b.uniforms = { "card_size": Vector2(W, H), "scale": float(D.scale), "samples": maxi(1, int(D.samples)),
				"reach": reach, "centre": Vector2(b.cx, b.cy) }
		"godrays":
			_walk(b, dt, 0.12, 0.2, 0.8)
			var drift: float = D.drift
			b.sx = b.ux + sin(t * drift * TAU) * W * 0.22
			b.sy = b.uy + cos(t * drift * TAU * 0.7) * H * 0.04
			b.uniforms = { "card_size": Vector2(W, H), "scale": float(D.scale), "threshold": float(D.threshold),
				"samples": maxi(1, int(D.samples)), "density": float(D.density), "weight": float(D.weight),
				"decay": float(D.decay), "sun_col": Color(D.sunCol), "sun": Vector2(b.sx, b.sy) }
		"kelvin":
			_walk(b, dt, 0.15, 0.2, 0.8)
			var P := _kelvin_params(b)
			b.uniforms = { "card_size": Vector2(W, H), "scale": float(D.scale), "contrast": float(P.contrast),
				"sat": float(P.sat), "warm": float(P.warm), "levels": int(P.levels) }
		"yesteryear":
			b.frame = (b.frame + 1) % 1024
			_walk(b, dt, 0.15, 0.2, 0.8)
			b.wt -= dt
			if b.wt <= 0.0:                          # the gate weave re-rolls a few times a second
				b.wt = 1.0 / maxf(0.1, float(D.weaveHz))
				b.jx = randf_range(-1.0, 1.0) * float(D.weave)
				b.jy = randf_range(-1.0, 1.0) * float(D.weave)
			b.flick = 1.0 + float(D.flicker) * Kit.noise(t * 13.0)
			b.uniforms = { "card_size": Vector2(W, H), "scale": float(D.scale), "grain": float(D.grain),
				"snow": float(D.snow) if b.mode == "static" else 0.0, "flick": float(b.flick),
				"weave": Vector2(b.jx, b.jy), "sepia": float(D.sepia), "frame_no": int(b.frame) }
		"mosh":
			b.timer -= dt
			if b.timer <= 0.0:
				_mosh_corrupt(b)
				b.timer = float(D.every)
			b.holdT = maxf(0.0, b.holdT - dt)
			b.corrupt = maxf(0.0, b.corrupt - dt * 1.6)
			_walk(b, dt, 0.15, 0.2, 0.8)
			b.holding = b.holdT > 0.0 and b.have_prev
			if not b.holding:                        # keep this frame for the next hold
				b.prev = { "hx": float(b.hx), "hdir": int(b.hdir), "t": t }
				b.have_prev = true
			b.uniforms = { "card_size": Vector2(W, H), "scale": float(D.scale), "block": float(D.block),
				"shift": float(D.shift), "bleed": float(D.bleed), "track": float(D.track),
				"track_y": fposmod(t * float(D.trackSpeed), 1.0), "cor": float(b.corrupt),
				"seed": fmod(floorf(t * 1000.0), 65536.0), "blk": PackedFloat32Array(b.blk) }

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	var D: Dictionary = b.D
	var W: float = b.w
	var H: float = b.h
	var GY: float = b.gy
	match b.id:
		"iris":
			# the DAY scene; iris.gdshader dresses it as night where the mask says so
			Kit.stage(n, b, 0.0)
			Kit.tree(n, Vector2(W * 0.16, GY), H * 0.28, Color("3E7A48"))
			Kit.crate(n, Vector2(W * 0.82, GY), H * 0.12)
			Kit.lamp(n, b, Vector2(W * 0.62, GY), false)
			Kit.hero(n, b, Vector2(b.hx, GY), { "pose": "run", "frame": t, "face": b.hdir })
			var k: float = b.k
			var kinds: Array = D.kinds
			if k >= 0.0:
				var e := _ease(k)
				var kind_cur: String = b.kind_cur
				if kind_cur == "iris" or kind_cur == "swirl":
					Kit.ring(n, Vector2(b.cx, b.cy), e * b.rmax, Color(0.961, 0.757, 0.412, 0.6), 1.0)
					Kit.dot(n, Vector2(b.cx, b.cy), 2.0, Kit.SUN)
				Kit.rect(n, Rect2(W * 0.3, 8.0, W * 0.4, 3.0), Color(0.91, 0.898, 0.957, 0.15))
				Kit.rect(n, Rect2(W * 0.3, 8.0, W * 0.4 * k, 3.0), Kit.SUN)
				Kit.label(n, b, "%s  k = %.2f" % [kind_cur, k], Vector2(W / 2.0, 22.0), FAINT, true)
			else:
				var nxt: String = str(kinds[b.ki % kinds.size()]) if D.kind == "cycle" else str(D.kind)
				Kit.label(n, b, "hold %.1f s · next: %s" % [maxf(0.0, b.wait), nxt], Vector2(W / 2.0, 22.0), Kit.DIM, true)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"hurt":
			var hp: float = b.hp
			var flash: float = b.flash
			var lunge: float = b.lunge
			var beat: float = b.beat
			var a: float = b.a
			var colour := Color(D.colour)
			var origin: Vector2 = (b.rect as Rect2).position
			var shake := flash * 4.0 * sin(t * 70.0)      # the hit shake
			n.draw_set_transform(origin + Vector2(shake, 0.0), 0.0, Vector2.ONE)
			Kit.stage(n, b, 0.2)
			Kit.tree(n, Vector2(W * 0.14, GY), H * 0.26)
			Kit.lamp(n, b, Vector2(W * 0.88, GY), true)
			Kit.crate(n, Vector2(W * 0.7, GY), H * 0.11)
			var hx: float = W * 0.4
			var ex: float = lerpf(W * 0.76, hx + H * 0.1, sin(lunge * PI))   # the slime, lunging
			Kit.ellipse(n, Vector2(ex, GY - H * 0.045), H * 0.06, H * 0.045, Kit.HOT)
			Kit.dot(n, Vector2(ex - H * 0.025, GY - H * 0.06), 1.5, Color("2B2440"))
			Kit.dot(n, Vector2(ex - H * 0.005, GY - H * 0.06), 1.5, Color("2B2440"))
			n.draw_set_transform(origin, 0.0, Vector2.ONE)
			Kit.hero(n, b, Vector2(hx + shake, GY), { "pose": "hurt" if flash > 0.55 else "stand", "frame": t, "face": 1 })
			var Rc: float = Vector2(W / 2.0, H / 2.0).length() * 1.02   # the vignette: clear inside, colour at the corners
			var r0: float = Rc * float(D.inner)
			var rm: float = r0 + 0.6 * (Rc - r0)
			var c := Vector2(W / 2.0, H / 2.0)
			_annulus(n, c, r0, Color(colour, 0.0), rm, Color(colour, a * 0.45))
			_annulus(n, c, rm, Color(colour, a * 0.45), Rc, Color(colour, a))
			var frost: float = D.frost
			if frost > 0.0:                          # frost: a pale rim plus crystals growing in from the corners
				var fa: float = clampf(frost * (1.0 - hp) * 0.95, 0.0, 1.0)
				_annulus(n, c, Rc * 0.55, Color(0.863, 0.941, 1.0, 0.0), Rc, Color(0.882, 0.949, 1.0, fa))
				var icol := Color(0.922, 0.973, 1.0, fa * 0.8)
				for ice in b.ice:
					var cc: int = ice.c
					var x0: float = W if (cc & 1) == 1 else 0.0
					var y0: float = H if (cc & 2) == 2 else 0.0
					var ang: float = ice.a + (PI / 2.0 if (cc & 1) == 1 else 0.0) + (-PI / 2.0 if (cc & 2) == 2 else 0.0) + (PI if cc == 3 else 0.0)
					var L: float = ice.l * W * (0.4 + 0.6 * (1.0 - hp))
					n.draw_line(Vector2(x0, y0), Vector2(x0 + cos(ang) * L, y0 + sin(ang) * L), icol, ice.w)
			var bw: float = W * 0.34                 # the health bar, and the heart that beats with the screen
			Kit.rect(n, Rect2(10.0, 10.0, bw, 7.0), Color(0.075, 0.063, 0.125, 0.7))
			Kit.rect(n, Rect2(10.0, 10.0, bw * hp, 7.0), Kit.HOT.lerp(Kit.GOOD, hp))
			n.draw_rect(Rect2(10.5, 10.5, bw, 7.0), Kit.BONE, false, 1.0)
			var hcx: float = 10.0 + bw + 14.0
			var hcy := 13.0
			var hr: float = 4.5 * (1.0 + beat * 0.35 * (0.4 + 0.6 * (1.0 - hp)))
			Kit.dot(n, Vector2(hcx - hr * 0.5, hcy - hr * 0.25), hr * 0.55, colour)
			Kit.dot(n, Vector2(hcx + hr * 0.5, hcy - hr * 0.25), hr * 0.55, colour)
			Kit.poly(n, [Vector2(hcx - hr * 1.02, hcy - hr * 0.05), Vector2(hcx + hr * 1.02, hcy - hr * 0.05), Vector2(hcx, hcy + hr)], colour)
			Kit.label(n, b, "%d bpm" % roundi(b.bpm), Vector2(hcx + 12.0, 17.0), Kit.DIM)
			var x0t: float = W * 0.58                # the pulse, as a trace
			var x1t: float = W * 0.96
			var pts := PackedVector2Array()
			var trace: Array = b.trace
			var ti: int = b.ti
			for i in HURT_TRACE:
				var v: float = trace[(ti + i) % HURT_TRACE]
				pts.append(Vector2(x0t + (x1t - x0t) * i / float(HURT_TRACE - 1), 24.0 - v * 12.0))
			n.draw_polyline(pts, Color(colour, 0.9), 1.0)
			Kit.label(n, b, "hp %.2f  α %.2f" % [hp, a], Vector2(10.0, 30.0), Kit.DIM)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"crt":
			_lamp_scene(n, b, t, 0.35, W * 0.6, true, b.hx, b.hdir)
			n.draw_rect(Rect2(1.0, 1.0, W - 2.0, H - 2.0), Color(0.788, 0.769, 0.894, 0.35), false, 2.0)   # the set's frame
			Kit.rect(n, Rect2(W - 34.0, 8.0, 4.0, 12.0), Color("F55"))   # the mask, enlarged
			Kit.rect(n, Rect2(W - 30.0, 8.0, 4.0, 12.0), Color("5F5"))
			Kit.rect(n, Rect2(W - 26.0, 8.0, 4.0, 12.0), Color("55F"))
			Kit.label(n, b, "mask", Vector2(W - 22.0, 18.0), Kit.DIM)
			Kit.label(n, b, "curve %.2f · scan %s · %d×%d" % [b.curve, _num(float(D.scan)), roundi(W * float(D.scale)), roundi(H * float(D.scale))], Vector2(8.0, 18.0), Kit.DIM)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"ordered":
			Kit.stage(n, b, 0.1)
			Kit.tree(n, Vector2(W * 0.15, GY), H * 0.28)
			Kit.crate(n, Vector2(W * 0.84, GY), H * 0.12)
			Kit.lamp(n, b, Vector2(W * 0.62, GY), true)
			Kit.hero(n, b, Vector2(b.hx, GY), { "pose": "run", "frame": t, "face": b.hdir })
			var nn: int = b.n
			var M: Array = b.M
			var cell: float = H * 0.07 if nn == 2 else (H * 0.05 if nn == 4 else H * 0.03)   # the matrix, drawn as a tile
			var x0 := 8.0
			var y0 := 8.0
			for y in nn:
				for x in nn:
					var mv: int = M[y][x]
					var k: float = mv / float(nn * nn)
					var g: float = (40.0 + 200.0 * k) / 255.0
					Kit.rect(n, Rect2(x0 + x * cell, y0 + y * cell, cell, cell), Color(g, g, g, 0.95))
					if nn <= 4:
						Kit.text(n, str(mv), Vector2(x0 + x * cell + cell / 2.0, y0 + y * cell + cell * 0.72), maxi(4, int(cell * 0.55)),
							Color("222") if k > 0.5 else Color("EEE"), true)
			n.draw_rect(Rect2(x0 + 0.5, y0 + 0.5, nn * cell, nn * cell), Kit.BONE, false, 1.0)
			Kit.label(n, b, "M %d×%d · %d levels" % [nn, nn, int(D.levels)], Vector2(x0 + nn * cell + 6.0, y0 + 10.0), Kit.DIM)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"quantise":
			Kit.stage(n, b, 0.0)
			for i in 6:                              # test colours
				Kit.dot(n, Vector2(W * (0.12 + i * 0.15), H * 0.22 + sin(t * 1.3 + i) * H * 0.05), H * 0.05, _hsl(i * 60.0, 0.8, 0.6))
			Kit.tree(n, Vector2(W * 0.15, GY), H * 0.28)
			Kit.crate(n, Vector2(W * 0.84, GY), H * 0.12)
			Kit.lamp(n, b, Vector2(W * 0.62, GY), true)
			Kit.hero(n, b, Vector2(b.hx, GY), { "pose": "run", "frame": t, "face": b.hdir })
			var luma: bool = D.mode == "luma"
			var show: Array = b.by_lum if luma else b.pal   # the swatches, in the order the pass uses them
			var N: int = show.size()
			var sw: float = minf(10.0, (W - 20.0) / N)
			for i in N:
				Kit.rect(n, Rect2(8.0 + i * sw, H - 30.0, sw - 1.0, 9.0), show[i])
			n.draw_rect(Rect2(7.5, H - 30.5, N * sw, 10.0), Kit.BONE, false, 1.0)
			Kit.label(n, b, "%s · N = %d%s" % [D.mode, N, " · dark → light" if luma else " · 5-bit LUT"], Vector2(10.0 + N * sw, H - 22.0), Kit.DIM)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"cycle":
			var pal: Array = b.pal
			var nn: int = pal.size()
			var off: int = b.off
			var x0: float = b.x0
			var x1: float = b.x1
			var yt: float = b.yt
			var pcx: float = b.pcx
			var pcy: float = b.pcy
			var prx: float = b.prx
			var pry: float = b.pry
			Kit.stage(n, b, 0.15)
			# the still picture: the index MARKER over the waterfall column and the
			# pool (below the ground line only, as the web's map is); the shader
			# turns marker pixels into palette colours
			Kit.rect(n, Rect2(x0, yt, x1 - x0, GY + 2.0 - yt), MARKER)
			var pool := PackedVector2Array()
			for i in 32:
				var ang := i / 32.0 * TAU
				pool.append(Vector2(pcx + cos(ang) * prx, maxf(GY, pcy + sin(ang) * pry)))
			n.draw_colored_polygon(pool, MARKER)
			Kit.hero(n, b, Vector2(b.hx, GY), { "pose": "run", "frame": t, "face": b.hdir })
			Kit.rect(n, Rect2(x0 - 9.0, yt - H * 0.1, 9.0, GY - yt + H * 0.1), ROCK)   # the cliff, drawn over the map's seams
			Kit.rect(n, Rect2(x1, yt - H * 0.1, 9.0, GY - yt + H * 0.1), ROCK)
			Kit.rect(n, Rect2(x0 - 9.0, yt - H * 0.1, x1 - x0 + 18.0, H * 0.1 - 2.0), ROCK)
			for i in 9:
				var ang := PI * i / 8.0
				Kit.ellipse(n, Vector2(pcx + cos(ang) * prx * 1.02, pcy + sin(ang) * pry * 1.02), W * 0.022, H * 0.014, ROCK)
			var sw: float = minf(9.0, (W * 0.6) / nn)   # the palette strip, rotating
			for i in nn:
				Kit.rect(n, Rect2(8.0 + i * sw, H - 30.0, sw - 1.0, 9.0), pal[(i + off) % nn])
			n.draw_rect(Rect2(7.5, H - 30.5, nn * sw, 10.0), Kit.BONE, false, 1.0)
			Kit.poly(n, [Vector2(8.0 + sw / 2.0 - 3.0, H - 33.0), Vector2(8.0 + sw / 2.0 + 3.0, H - 33.0), Vector2(8.0 + sw / 2.0, H - 30.0)], Kit.SUN)
			Kit.label(n, b, "index 0 → pal[%d] · %s %s/s" % [off, "→" if b.dir > 0 else "←", _num(absf(float(D.speed)))], Vector2(12.0 + nn * sw, H - 22.0), Kit.DIM)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"xsplit":
			Kit.stage(n, b, 0.6)
			Kit.dot(n, Vector2(W * 0.8, H * 0.18), H * 0.05, Color("F4F1E0"))   # the moon and stars
			for i in 12:
				Kit.dot(n, Vector2((i * 0.083 + 0.03) * W, H * (0.06 + ((i * 7) % 5) * 0.06)), 1.0, Color.WHITE)
			Kit.tree(n, Vector2(W * 0.15, GY), H * 0.28)
			Kit.crate(n, Vector2(W * 0.84, GY), H * 0.12)
			Kit.glow(n, Vector2(W * 0.6, GY - H * 0.3 - 8.0), H * 0.32, Kit.SUN, 0.5)   # ("lighter" on the web: alpha here)
			Kit.lamp(n, b, Vector2(W * 0.6, GY), true)
			Kit.hero(n, b, Vector2(b.hx, GY), { "pose": "run", "frame": t, "face": b.hdir })
			var split: float = b.split
			var g: float = b.g
			var power: float = D.power
			var spots := [Vector2(0.12, 0.14), Vector2(0.88, 0.14), Vector2(0.12, 0.86), Vector2(0.88, 0.86), Vector2(0.5, 0.5)]   # the offset vector, at five places
			for sp in spots:
				var px: float = sp.x * W
				var py: float = sp.y * H
				var uu: float = (px - W / 2.0) / (W / 2.0)
				var vv: float = (py - H / 2.0) / (H / 2.0)
				var r: float = Vector2(uu, vv).length()
				if r < 1e-3:
					Kit.dot(n, Vector2(px, py), 2.0, Kit.DIM)
					continue
				var f: float = split * W * pow(r * r, power * 0.5) / r   # in canvas pixels
				Kit.arrow(n, Vector2(px, py), Vector2(px - uu * f, py - vv * f), Color(1.0, 0.314, 0.314, 0.9))
				Kit.arrow(n, Vector2(px, py), Vector2(px + uu * f, py + vv * f), Color(0.353, 0.549, 1.0, 0.9))
			Kit.label(n, b, "split %.3f · |uv|^%s%s" % [split, _num(power), (" · glitch %.2f" % g) if g > 0.0 else ""], Vector2(8.0, 18.0), Kit.DIM)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"refract":
			var kind: String = D.kind
			var fx: float = b.fx
			var fy: float = b.fy
			var wy: float = H * float(D.waterY)
			var rmax: float = W * 0.6
			Kit.stage(n, b, 0.55 if kind == "heat" else 0.1)
			Kit.tree(n, Vector2(W * 0.12, GY), H * 0.26)
			Kit.crate(n, Vector2(W * 0.86, GY), H * 0.11)
			if kind == "heat":                       # the campfire: logs and three flickering glows ("lighter" on the web)
				Kit.rect(n, Rect2(fx - H * 0.06, GY - H * 0.02, H * 0.12, H * 0.02), Color("5A3E2B"))
				Kit.rect(n, Rect2(fx - H * 0.05, GY - H * 0.035, H * 0.1, H * 0.015), Color("4A2E1B"))
				var fl: float = 0.8 + 0.2 * sin(t * 17.0) * sin(t * 5.3)
				Kit.glow(n, Vector2(fx, fy - H * 0.05), H * 0.16 * fl, Kit.FIRE, 0.9)
				Kit.glow(n, Vector2(fx + sin(t * 9.0) * 3.0, fy - H * 0.09), H * 0.09 * fl, Kit.SUN, 0.9)
				Kit.glow(n, Vector2(fx, fy - H * 0.11), H * 0.04, Kit.SPARK, 1.0)
			Kit.hero(n, b, Vector2(b.hx, GY), { "pose": "run", "frame": t, "face": b.hdir })
			if kind == "water":
				Kit.rect(n, Rect2(0.0, wy, W, H - wy), Color(0.31, 0.64, 0.85, 0.35))
				Kit.line(n, Vector2(0.0, wy), Vector2(W, wy), Color(0.843, 0.925, 0.984, 0.8), 1.5)
			var rings: Array = b.rings
			for q in rings:
				Kit.ring(n, Vector2(q.x, q.y), q.r, Color(0.961, 0.757, 0.412, 0.7 * (1.0 - q.r / rmax)), 1.0)
			if kind == "heat":                       # the cone, dashed
				var ccol := Color(0.961, 0.541, 0.353, 0.5)
				n.draw_dashed_line(Vector2(fx - W * 0.06, fy), Vector2(fx - W * 0.06 - (fy - H * 0.05) * 0.5, H * 0.05), ccol, 1.0, 3.5)
				n.draw_dashed_line(Vector2(fx + W * 0.06, fy), Vector2(fx + W * 0.06 + (fy - H * 0.05) * 0.5, H * 0.05), ccol, 1.0, 3.5)
				Kit.label(n, b, "noise cone", Vector2(fx, H * 0.09), Color(0.961, 0.541, 0.353, 0.7), true)
			if kind == "water":
				Kit.label(n, b, "sin rows below y = %sH" % _num(float(D.waterY)), Vector2(W * 0.02, wy - 4.0), Color(0.843, 0.925, 0.984, 0.7))
			Kit.label(n, b, "rings %d · w = %sW" % [rings.size(), _num(float(D.ringW))], Vector2(8.0, 18.0), Kit.DIM)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"zoomblur":
			var dashing: float = b.dashing
			var amount: float = b.amount
			var cx: float = b.cx
			var cy: float = b.cy
			Kit.stage(n, b, 0.25)
			Kit.tree(n, Vector2(W * 0.15, GY), H * 0.28)
			Kit.crate(n, Vector2(W * 0.84, GY), H * 0.12)
			Kit.lamp(n, b, Vector2(W * 0.5, GY), true)
			for i in 5:
				Kit.dot(n, Vector2(W * (0.1 + i * 0.2), H * 0.2 + (i % 2) * H * 0.1), 2.0, Color.WHITE)
			Kit.hero(n, b, Vector2(b.hx, GY), { "pose": "jump" if dashing > 0.0 else "run", "frame": t, "face": b.hdir })
			var N: int = maxi(1, int(D.samples))
			var reach: float = float(D.strength) * amount
			Kit.ring(n, Vector2(cx, cy), 6.0, Kit.SUN, 1.5)   # the centre
			Kit.line(n, Vector2(cx - 10.0, cy), Vector2(cx + 10.0, cy), Kit.SUN)
			Kit.line(n, Vector2(cx, cy - 10.0), Vector2(cx, cy + 10.0), Kit.SUN)
			var spots := [Vector2(0.1, 0.12), Vector2(0.9, 0.12), Vector2(0.1, 0.7)]   # three sample lines, N dots each
			for sp in spots:
				var px: float = sp.x * W
				var py: float = sp.y * H
				Kit.line(n, Vector2(px, py), Vector2(px + (cx - px) * reach, py + (cy - py) * reach), Color(0.541, 0.851, 0.961, 0.5), 1.0)
				for k in N:
					Kit.dot(n, Vector2(px + (cx - px) * reach * k / N, py + (cy - py) * reach * k / N), 1.3, Kit.HERO)
			Kit.rect(n, Rect2(8.0, 10.0, W * 0.25, 4.0), Color(0.91, 0.898, 0.957, 0.15))
			Kit.rect(n, Rect2(8.0, 10.0, W * 0.25 * amount, 4.0), Kit.SUN)
			Kit.label(n, b, "amount %.2f · N = %d" % [amount, N], Vector2(8.0, 24.0), Kit.DIM)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"godrays":
			var sx: float = b.sx
			var sy: float = b.sy
			var sun_col := Color(D.sunCol)
			Kit.stage(n, b, 0.4)
			Kit.glow(n, Vector2(sx, sy), H * 0.3, sun_col, 0.55)   # the sun: the only thing past the threshold
			Kit.dot(n, Vector2(sx, sy), H * 0.06, Color("FFFDF0"))
			var dark := Color("141C18")
			Kit.tree(n, Vector2(W * 0.18, GY), H * 0.42, dark)
			Kit.tree(n, Vector2(W * 0.36, GY - 2.0), H * 0.32, dark)
			Kit.tree(n, Vector2(W * 0.66, GY), H * 0.46, dark)
			Kit.tree(n, Vector2(W * 0.86, GY - 2.0), H * 0.3, dark)
			Kit.crate(n, Vector2(W * 0.52, GY), H * 0.1)
			Kit.hero(n, b, Vector2(b.hx, GY), { "pose": "run", "frame": t, "face": b.hdir })
			var N: int = maxi(1, int(D.samples))
			var density: float = D.density
			var decay: float = D.decay
			Kit.ring(n, Vector2(sx, sy), H * 0.075, Color(0.961, 0.757, 0.412, 0.7), 1.0)
			Kit.label(n, b, "lum > %d" % int(D.threshold), Vector2(sx, sy - H * 0.09), Color(0.961, 0.757, 0.412, 0.8), true)
			var spots := [Vector2(0.06, 0.94), Vector2(0.94, 0.92)]   # two sample rays, N dots each
			for sp in spots:
				var px: float = sp.x * W
				var py: float = sp.y * H
				Kit.line(n, Vector2(px, py), Vector2(px + (sx - px) * density, py + (sy - py) * density), Color(1.0, 0.941, 0.722, 0.35), 1.0)
				for k in range(1, N + 1):
					Kit.dot(n, Vector2(px + (sx - px) * density * k / N, py + (sy - py) * density * k / N), 1.2, Color(1.0, 0.941, 0.722, pow(decay, k)))
			Kit.label(n, b, "N = %d · density %s · decay %s" % [N, _num(density), _num(decay)], Vector2(8.0, 18.0), Kit.DIM)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"kelvin":
			Kit.stage(n, b, 0.0)
			for i in 6:
				Kit.dot(n, Vector2(W * (0.12 + i * 0.15), H * 0.22 + sin(t * 1.3 + i) * H * 0.05), H * 0.05, _hsl(i * 60.0, 0.8, 0.6))
			Kit.tree(n, Vector2(W * 0.15, GY), H * 0.28)
			Kit.crate(n, Vector2(W * 0.84, GY), H * 0.12)
			Kit.lamp(n, b, Vector2(W * 0.62, GY), true)
			Kit.hero(n, b, Vector2(b.hx, GY), { "pose": "run", "frame": t, "face": b.hdir })
			var P := _kelvin_params(b)
			var gs: float = maxf(20.0, H * 0.15)    # the three curves
			var gx0: float = W - 8.0 - gs * 3.0 - 8.0
			var gy0 := 8.0
			var ccols := [Color("F55"), Color("5F5"), Color("58F")]
			for c in 3:
				var gx: float = gx0 + c * (gs + 4.0)
				Kit.rect(n, Rect2(gx, gy0, gs, gs), Color(0.075, 0.063, 0.125, 0.6))
				n.draw_line(Vector2(gx, gy0 + gs), Vector2(gx + gs, gy0), Color(0.788, 0.769, 0.894, 0.3), 1.0)   # identity
				var pts := PackedVector2Array()
				for i in 17:
					var v: float = i * 255.0 / 16.0
					pts.append(Vector2(gx + i / 16.0 * gs, gy0 + gs - _kelvin_curve(v, c, P) / 255.0 * gs))
				n.draw_polyline(pts, ccols[c], 1.5)
			Kit.text(n, b.cur, Vector2(8.0, 20.0), 13, Kit.BONE)
			var lv: int = int(P.levels)
			Kit.label(n, b, "contrast %s · sat %s · warm %s%s" % [_num(float(P.contrast)), _num(float(P.sat)), _num(float(P.warm)), (" · L %d" % lv) if lv > 1 else ""], Vector2(8.0, 32.0), Kit.DIM)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"yesteryear":
			var jx: float = b.jx
			var jy: float = b.jy
			var flick: float = b.flick
			Kit.stage(n, b, 0.15)
			Kit.tree(n, Vector2(W * 0.15, GY), H * 0.28)
			Kit.crate(n, Vector2(W * 0.84, GY), H * 0.12)
			Kit.lamp(n, b, Vector2(W * 0.62, GY), true)
			Kit.hero(n, b, Vector2(b.hx, GY), { "pose": "run", "frame": t, "face": b.hdir })
			var scratches: int = int(D.scratches)
			for i in scratches:                      # scratches: thin lines that wander and blink
				var x: float = W * (0.08 + fmod(i * 0.37, 0.84)) + Kit.noise(t * 2.5 + i * 7.0) * W * 0.03
				var on: float = Kit.noise(t * 9.0 + i * 3.1)
				if on > 0.05:
					Kit.line(n, Vector2(x, 0.0), Vector2(x, H), Color(1.0, 0.957, 0.882, 0.25 + on * 0.3), 1.0)
				elif on < -0.5:
					Kit.line(n, Vector2(x + 2.0, 0.0), Vector2(x + 2.0, H), Color(0.078, 0.047, 0.039, 0.5), 1.0)
			if Kit.noise(t * 21.0) > 0.6:            # a dust speck
				Kit.dot(n, Vector2(W * (0.5 + Kit.noise(t * 3.0) * 0.4), H * (0.5 + Kit.noise(t * 4.0 + 5.0) * 0.4)), 2.0, Color("1A1410"))
			Kit.rect(n, Rect2(8.0, 8.0, 18.0, 18.0), Color(0.075, 0.063, 0.125, 0.6))   # the weave, magnified ×3
			Kit.ring(n, Vector2(17.0, 17.0), 6.0, Color(0.788, 0.769, 0.894, 0.35), 1.0)
			Kit.dot(n, Vector2(17.0 + jx * 3.0, 17.0 + jy * 3.0), 2.0, Kit.SUN)
			Kit.label(n, b, "weave (%.1f, %.1f) px" % [jx, jy], Vector2(30.0, 14.0), Kit.DIM)
			Kit.rect(n, Rect2(30.0, 19.0, W * 0.2, 3.0), Color(0.91, 0.898, 0.957, 0.15))
			Kit.rect(n, Rect2(30.0, 19.0, W * 0.2 * (flick - 0.8) / 0.4, 3.0), Kit.SUN)
			Kit.label(n, b, "flicker %.2f" % flick, Vector2(30.0 + W * 0.2 + 4.0, 23.0), Kit.DIM)
			var mode_txt: String = ("static: v = lerp(v, n, %s)" % _num(float(D.snow))) if b.mode == "static" else ("grain σ %s" % _num(float(D.grain)))
			Kit.label(n, b, mode_txt, Vector2(8.0, 40.0), Kit.DIM)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"mosh":
			var holding: bool = b.holding
			var cor: float = b.corrupt
			var track_y: float = fposmod(t * float(D.trackSpeed), 1.0)
			if holding:                              # the FRAME-HOLD: the last good frame again
				var prev: Dictionary = b.prev
				_lamp_scene(n, b, prev.t, 0.5, W * 0.6, true, prev.hx, prev.hdir)
			else:
				_lamp_scene(n, b, t, 0.5, W * 0.6, true, b.hx, b.hdir)
			Kit.text(n, "PLAY ▶", Vector2(10.0, 20.0), 11, Color.WHITE)
			var bb: float = maxf(1.0, float(D.block)) # the displaced blocks, marked at the left edge
			if cor > 0.0:
				var blk: Array = b.blk
				for bi in 64:
					if bi * bb >= H:
						break
					var bv: float = blk[bi]
					if bv != 0.0:
						var y: float = bi * bb + bb / 2.0
						var dx: float = bv * float(D.shift) * W * cor
						Kit.arrow(n, Vector2(6.0, y), Vector2(6.0 + dx, y), Color(0.961, 0.541, 0.541, 0.8))
			Kit.line(n, Vector2(W - 6.0, track_y * H - H * 0.09), Vector2(W - 6.0, track_y * H + H * 0.09), Kit.SUN, 2.0)
			_label_right(n, b, "tracking", Vector2(W - 10.0, track_y * H + 3.0), Color(0.961, 0.757, 0.412, 0.8))
			if holding:
				Kit.text(n, "HOLD  frame t−1", Vector2(W / 2.0, H * 0.14), 12, Kit.HOT, true)
			Kit.label(n, b, "bleed %spx · block %s · %s" % [_num(float(D.bleed)), _num(float(D.block)), ("corrupt %.2f" % cor) if cor > 0.0 else "clean"], Vector2(8.0, 34.0), Kit.DIM)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
