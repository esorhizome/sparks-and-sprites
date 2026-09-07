extends RefCounted
## Shared kit for the stagecraft almanac (scenes/stage/*.gd) — the web kit
## (docs/stagecraft.js) spelled in GDScript: one small SCENE (a sky
## gradient, two hill lines, a ground band), a code-drawn HERO sprite with a
## run cycle, props (tree, lamp, crate, wall, house), a soft glow, the
## drawing pocket tools, 1-D and 2-D value noise, seeded random, and a
## small SYNTHESIZER (tone / noise_burst / beep) that the audio family
## plays through — silent until a card is pressed, exactly like the web.
##
## Where the web page reads and rewrites pixels (its pix() screen pass),
## Godot uses a canvas_item shader: the runner (scenes/stagecraft.gd) lays a
## ColorRect with the card's named .gdshader over the card and pushes
## b.uniforms into it each frame. For sprite-level pixel work (emit from
## pixels, gradient maps, shatter) use hero_cells(): the hero as a list of
## unit squares [Vector2i(ux, uy), Color], which is literally its pixels.
##
## Coordinates are CARD-LOCAL (the Painter node draws in (0,0)..(w,h)).
## Card state: b.rect (Rect2 at ZERO), b.w, b.h, b.gy (h · 0.8), b.D (the
## dials, rhyme merged), b.t (seconds since the card woke), b.uniforms
## (shader parameters), b.armed (false until an opt-in card is clicked).

const INK := Color(0.91, 0.898, 0.957)
const DIM := Color(0.91, 0.898, 0.957, 0.25)
const NIGHT := Color(0.075, 0.063, 0.125)
const HERO := Color(0.541, 0.851, 0.961)    ## the sprite's shirt blue
const SUN := Color(0.961, 0.757, 0.412)     ## amber: light, warmth, targets
const FIRE := Color(0.961, 0.541, 0.353)
const SPARK := Color(1.0, 0.914, 0.659)
const HOT := Color(0.961, 0.541, 0.541)     ## damage, danger
const GOOD := Color(0.608, 0.886, 0.541)    ## safe, healthy
const MAGIC := Color(0.788, 0.627, 0.961)   ## spells, ghosts
const WATER := Color(0.31, 0.64, 0.85)      ## water, ice, cold
const BONE := Color(0.788, 0.769, 0.894)    ## structure, HUD frames

const SKY_TOP_DAY := Color("3B6FC4")
const SKY_BOT_DAY := Color("CFE0F5")
const SKY_TOP_NIGHT := Color("0B0A1E")
const SKY_BOT_NIGHT := Color("1E1A3A")

static func setup(b: Dictionary) -> void:
	var r: Rect2 = b.rect
	b.w = r.size.x
	b.h = r.size.y
	b.gy = r.size.y * 0.8

# ---------------------------------------------------------------- numbers

static func rng(seed_v: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_v
	return r

static func _hash(i: float) -> float:
	var s := sin(i * 127.1 + 311.7) * 43758.5453
	return s - floor(s)

static func _hash2(i: float, j: float) -> float:
	var s := sin(i * 127.1 + j * 269.5 + 311.7) * 43758.5453
	return s - floor(s)

## Smooth 1-D value noise in -1..1 (the web kit's noise(x)).
static func noise(x: float) -> float:
	var i := floorf(x)
	var f := x - i
	var k := f * f * (3.0 - 2.0 * f)
	return (_hash(i) + (_hash(i + 1.0) - _hash(i)) * k) * 2.0 - 1.0

## Smooth 2-D value noise in -1..1 (the web kit's noise2(x, y)).
static func noise2(x: float, y: float) -> float:
	var i := floorf(x)
	var j := floorf(y)
	var fx := x - i
	var fy := y - j
	var kx := fx * fx * (3.0 - 2.0 * fx)
	var ky := fy * fy * (3.0 - 2.0 * fy)
	var a := _hash2(i, j)
	var bb := _hash2(i + 1.0, j)
	var c := _hash2(i, j + 1.0)
	var d := _hash2(i + 1.0, j + 1.0)
	var top := a + (bb - a) * kx
	var bot := c + (d - c) * kx
	return (top + (bot - top) * ky) * 2.0 - 1.0

## The framerate-proof lerp factor.
static func smooth(rate: float, dt: float) -> float:
	return 1.0 - exp(-rate * dt)

## k > 0 lightens toward white, k < 0 darkens toward black (the web's shade()).
static func shade(c: Color, k: float) -> Color:
	return c.lerp(Color.WHITE, k) if k >= 0.0 else c.lerp(Color.BLACK, -k)

# ---------------------------------------------------------------- the scene

## A vertical gradient rectangle: one draw_polygon with a colour per vertex
## (the GPU interpolates — the depth atlas's trick).
static func vgrad(n: CanvasItem, r: Rect2, top: Color, bot: Color) -> void:
	var pts := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	var cols := PackedColorArray([top, top, bot, bot])
	n.draw_polygon(pts, cols)

## The scene: sky (night 0..1 darkens it), far hills, near hills, a ground
## band. plain = true paints only the night paper + graph paper (for HUD and
## audio cards).
static func stage(n: CanvasItem, b: Dictionary, night: float = 0.0, plain: bool = false) -> void:
	if plain:
		vgrad(n, Rect2(Vector2.ZERO, Vector2(b.w, b.h)), Color("1A1532"), NIGHT)
		var grid := Color(0.59, 0.57, 0.75, 0.07)
		var x := 26.0
		while x < b.w:
			n.draw_line(Vector2(x, 0), Vector2(x, b.h), grid, 1.0)
			x += 26.0
		var y := 26.0
		while y < b.h:
			n.draw_line(Vector2(0, y), Vector2(b.w, y), grid, 1.0)
			y += 26.0
		return
	var k := clampf(night, 0.0, 1.0)
	var gy: float = b.gy
	vgrad(n, Rect2(Vector2.ZERO, Vector2(b.w, gy + 1.0)), SKY_TOP_DAY.lerp(SKY_TOP_NIGHT, k), SKY_BOT_DAY.lerp(SKY_BOT_NIGHT, k))
	var far := PackedVector2Array([Vector2(0, gy)])   # far hills: one noise line
	var x2 := 0.0
	while x2 <= b.w + 6.0:
		far.append(Vector2(minf(x2, b.w), gy - b.h * (0.08 + 0.07 * (noise(x2 / b.w * 3.0 + 7.0) * 0.5 + 0.5))))
		x2 += 6.0
	far.append(Vector2(b.w, gy))
	n.draw_colored_polygon(far, Color("6E8FB8").lerp(Color("15132A"), k))
	var near := PackedVector2Array([Vector2(0, gy)])
	var x3 := 0.0
	while x3 <= b.w + 6.0:
		near.append(Vector2(minf(x3, b.w), gy - b.h * (0.02 + 0.05 * (noise(x3 / b.w * 5.0 + 21.0) * 0.5 + 0.5))))
		x3 += 6.0
	near.append(Vector2(b.w, gy))
	n.draw_colored_polygon(near, Color("4B7A5A").lerp(Color("12111F"), k))
	vgrad(n, Rect2(Vector2(0, gy), Vector2(b.w, b.h - gy)), Color("5D8A4A").lerp(Color("1A1830"), k), Color("3E5F33").lerp(NIGHT, k))
	n.draw_line(Vector2(0, gy), Vector2(b.w, gy), Color(0.08, 0.16, 0.08, 0.5).lerp(Color(0.788, 0.769, 0.894, 0.35), k), 1.5)

static func ground(n: CanvasItem, b: Dictionary, gy: float = -1.0) -> void:
	var g: float = b.gy if gy < 0.0 else gy
	n.draw_line(Vector2(0, g), Vector2(b.w, g), Color(0.788, 0.769, 0.894, 0.5), 1.5)
	var x := 4.0
	while x < b.w:
		n.draw_line(Vector2(x, g + 2), Vector2(x - 5, g + 8), Color(0.788, 0.769, 0.894, 0.16), 1.0)
		x += 12.0

# ---------------------------------------------------------------- the hero

## The hero's unit size for a stage of height h (the web's heroUnit()).
static func hero_unit(b: Dictionary) -> float:
	return maxf(2.0, roundf(b.h / 60.0))

## The hero as a list of unit squares — [Vector2i(ux, uy), Color] — in a
## 14 × 19 unit frame whose feet anchor is (7, 18). opts: face (±1), pose
## ("stand" | "run" | "jump" | "hurt" | "crouch"), frame (a clock for the
## run cycle), shirt (Color). These ARE the sprite's pixels: recolour them
## for a gradient map, fling them for a disintegrate, group them for a
## shatter.
static func hero_cells(opts: Dictionary = {}) -> Array:
	var pose: String = opts.get("pose", "stand")
	var f: float = opts.get("frame", 0.0)
	var shirt: Color = opts.get("shirt", HERO)
	var skin := Color("F2C9A0")
	var hair := SUN
	var pants := Color("4A4470")
	var shoe := Color("2B2440")
	var eye := HOT if pose == "hurt" else Color("2B2440")
	var bob := 0.0
	var leg_a := 0
	var leg_b := 0
	var arm_a := 0
	var arm_b := 0
	var squat := 0
	if pose == "run":
		var ph := f * 9.0
		bob = absf(sin(ph)) * 0.6
		leg_a = roundi(sin(ph) * 2.0)
		leg_b = -leg_a
		arm_a = -leg_a
		arm_b = leg_a
	elif pose == "jump":
		leg_a = -1
		leg_b = 1
		arm_a = -3
		arm_b = -3
	elif pose == "hurt":
		arm_a = -2
		arm_b = -2
	elif pose == "crouch":
		squat = 4
	else:
		bob = sin(f * 2.0) * 0.25
	var out: Array = []
	var by := roundi(-bob) + squat                     # the frame's y shift
	var add := func(ux: int, uy: int, uw: int, uh: int, col: Color) -> void:
		for yy in uh:
			for xx in uw:
				out.append([Vector2i(7 + ux + xx, 18 + uy + by + yy), col])
	add.call(-3 + leg_a, -5, 3, 5 - squat, pants)
	add.call(0 + leg_b, -5, 3, 5 - squat, pants)
	add.call(-3 + leg_a, -1, 3, 1, shoe)
	add.call(0 + leg_b, -1, 3, 1, shoe)
	add.call(-4, -11, 8, 6, shirt)
	add.call(-6, -11 + int(arm_a / 2), 2, 4, shirt)
	add.call(4, -11 + int(arm_b / 2), 2, 4, shirt)
	add.call(-6, -7 + int(arm_a / 2), 2, 1, skin)
	add.call(4, -7 + int(arm_b / 2), 2, 1, skin)
	add.call(-4, -16, 8, 5, skin)
	add.call(-4, -17, 8, 2, hair)
	add.call(-5, -16, 1, 3, hair)
	add.call(4, -16, 1, 2, hair)
	add.call(0, -14, 1, 1, eye)
	add.call(2, -14, 1, 1, eye)
	if pose == "hurt":
		add.call(-1, -13, 5, 1, HOT)
	return out

## Draw the hero with its feet at p. opts as hero_cells, plus s (unit size),
## tint (a Color painted over every cell, alpha = strength), alpha, rot
## (radians about the feet), flat (draw every cell in this one colour —
## silhouettes and shadows).
static func hero(n: CanvasItem, b: Dictionary, p: Vector2, opts: Dictionary = {}) -> void:
	var s: float = opts.get("s", hero_unit(b))
	var face: int = opts.get("face", 1)
	var alpha: float = opts.get("alpha", 1.0)
	var origin: Vector2 = (b.rect as Rect2).position
	var xf := Transform2D(float(opts.get("rot", 0.0)), origin + p).scaled_local(Vector2(face, 1))
	n.draw_set_transform_matrix(xf)
	var cellsv := hero_cells(opts)
	var flat: Variant = opts.get("flat", null)
	var tint: Variant = opts.get("tint", null)
	for cell in cellsv:
		var c: Vector2i = cell[0]
		var col: Color = cell[1]
		if flat != null:
			col = flat
		elif tint != null:
			var tc: Color = tint
			col = col.lerp(Color(tc.r, tc.g, tc.b, 1.0), tc.a)
		col.a *= alpha
		n.draw_rect(Rect2(Vector2((c.x - 7) * s, (c.y - 18) * s), Vector2(s, s)), col)
	n.draw_set_transform(origin, 0.0, Vector2.ONE)

# ---------------------------------------------------------------- props

static func tree(n: CanvasItem, p: Vector2, s: float, col: Color = Color("3E7A48")) -> void:
	n.draw_rect(Rect2(p.x - s * 0.08, p.y - s * 0.55, s * 0.16, s * 0.55), Color("5A3E2B"))
	n.draw_colored_polygon(PackedVector2Array([Vector2(p.x, p.y - s * 1.3), Vector2(p.x + s * 0.45, p.y - s * 0.55), Vector2(p.x - s * 0.45, p.y - s * 0.55)]), col)
	n.draw_colored_polygon(PackedVector2Array([Vector2(p.x, p.y - s * 1.05), Vector2(p.x + s * 0.36, p.y - s * 0.4), Vector2(p.x - s * 0.36, p.y - s * 0.4)]), col)

static func lamp(n: CanvasItem, b: Dictionary, p: Vector2, lit: bool = true) -> void:
	var h: float = b.h * 0.3
	n.draw_rect(Rect2(p.x - 2, p.y - h, 4, h), Color("3A3355"))
	n.draw_rect(Rect2(p.x - 8, p.y - h - 3, 16, 4), Color("3A3355"))
	n.draw_circle(Vector2(p.x, p.y - h - 8), 5.0, SUN if lit else Color("3A3355"))

## The lamp's bulb position, for glows and light cones.
static func lamp_bulb(b: Dictionary, p: Vector2) -> Vector2:
	return Vector2(p.x, p.y - b.h * 0.3 - 8.0)

static func crate(n: CanvasItem, p: Vector2, s: float) -> void:
	n.draw_rect(Rect2(p.x - s / 2.0, p.y - s, s, s), Color("8A6A3E"))
	var w := maxf(1.0, s * 0.08)
	n.draw_rect(Rect2(p.x - s / 2.0 + 1, p.y - s + 1, s - 2, s - 2), Color("5A3E2B"), false, w)
	n.draw_line(Vector2(p.x - s / 2.0, p.y - s), Vector2(p.x + s / 2.0, p.y), Color("5A3E2B"), w)
	n.draw_line(Vector2(p.x + s / 2.0, p.y - s), Vector2(p.x - s / 2.0, p.y), Color("5A3E2B"), w)

static func wall(n: CanvasItem, r: Rect2) -> void:
	n.draw_rect(r, Color("6E6890"))
	var y := r.position.y
	while y < r.end.y:
		n.draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Color(0.075, 0.063, 0.125, 0.5), 1.0)
		y += 8.0

static func house(n: CanvasItem, p: Vector2, w: float, h: float, lit: bool = false) -> void:
	n.draw_rect(Rect2(p.x, p.y - h, w, h), Color("4A4470"))
	n.draw_colored_polygon(PackedVector2Array([Vector2(p.x - 4, p.y - h), Vector2(p.x + w / 2.0, p.y - h - h * 0.5), Vector2(p.x + w + 4, p.y - h)]), Color("6E3A3A"))
	var wc := SUN if lit else Color("2B2440")
	n.draw_rect(Rect2(p.x + w * 0.2, p.y - h * 0.7, w * 0.22, h * 0.28), wc)
	n.draw_rect(Rect2(p.x + w * 0.58, p.y - h * 0.7, w * 0.22, h * 0.28), wc)

# ---------------------------------------------------------------- drawing

static func dot(n: CanvasItem, p: Vector2, radius: float, col: Color = INK) -> void:
	n.draw_circle(p, maxf(0.1, radius), col)

static func ring(n: CanvasItem, p: Vector2, radius: float, col: Color = DIM, w: float = 1.0) -> void:
	n.draw_arc(p, maxf(0.5, radius), 0.0, TAU, 48, col, w)

static func line(n: CanvasItem, a: Vector2, c: Vector2, col: Color = INK, w: float = 1.0) -> void:
	n.draw_line(a, c, col, w)

static func rect(n: CanvasItem, r: Rect2, col: Color = INK) -> void:
	n.draw_rect(r, col)

static func ellipse(n: CanvasItem, c: Vector2, rx: float, ry: float, col: Color = INK) -> void:
	var pts := PackedVector2Array()
	for i in 32:
		var a := i / 32.0 * TAU
		pts.append(c + Vector2(cos(a) * maxf(0.1, rx), sin(a) * maxf(0.1, ry)))
	n.draw_colored_polygon(pts, col)

static func poly(n: CanvasItem, pts: Array, col: Color = INK, stroke: float = 0.0) -> void:
	if pts.size() < 2:
		return
	var packed := PackedVector2Array(pts)
	if stroke > 0.0:
		packed.append(pts[0])
		n.draw_polyline(packed, col, stroke)
	elif pts.size() >= 3:
		n.draw_colored_polygon(packed, col)

static func arrow(n: CanvasItem, a: Vector2, c: Vector2, col: Color = INK) -> void:
	var d := a.distance_to(c)
	n.draw_line(a, c, col, 1.5)
	if d < 3.0:
		return
	var h := (c - a) / d
	var s := minf(6.0, d * 0.4)
	var perp := Vector2(-h.y, h.x)
	n.draw_colored_polygon(PackedVector2Array([c, c - h * s + perp * s * 0.55, c - h * s - perp * s * 0.55]), col)

## A soft radial glow: a triangle fan with a bright centre vertex fading to
## transparent at the rim (the depth atlas's radial() in one call).
static func glow(n: CanvasItem, c: Vector2, r: float, col: Color, a: float = 0.8, segs: int = 40) -> void:
	r = maxf(1.0, r)
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var inner := Color(col.r, col.g, col.b, a)
	var mid := Color(col.r, col.g, col.b, a * 0.35)
	var outer := Color(col.r, col.g, col.b, 0.0)
	pts.append(c)
	cols.append(inner)
	for i in segs + 1:
		var ang := i / float(segs) * TAU
		pts.append(c + Vector2(cos(ang), sin(ang)) * r * 0.5)
		cols.append(mid)
	for i in segs + 1:
		var ang := i / float(segs) * TAU
		pts.append(c + Vector2(cos(ang), sin(ang)) * r)
		cols.append(outer)
	for i in segs:
		idx.append(0)
		idx.append(1 + i)
		idx.append(2 + i)
		var o := 1 + segs + 1
		idx.append(1 + i)
		idx.append(o + i)
		idx.append(o + i + 1)
		idx.append(1 + i)
		idx.append(o + i + 1)
		idx.append(2 + i)
	RenderingServer.canvas_item_add_triangle_array(n.get_canvas_item(), idx, pts, cols)

static func label(n: CanvasItem, b: Dictionary, txt: String, p: Vector2,
		col: Color = Color(0.91, 0.898, 0.957, 0.55), center: bool = false) -> void:
	var f := ThemeDB.fallback_font
	var x := p.x
	if center:
		x -= f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x / 2.0
	n.draw_string(f, Vector2(x, p.y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, col)

static func text(n: CanvasItem, txt: String, p: Vector2, size: int = 12, col: Color = INK, center: bool = false) -> void:
	var f := ThemeDB.fallback_font
	var x := p.x
	if center:
		x -= f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x / 2.0
	n.draw_string(f, Vector2(x, p.y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

# ---------------------------------------------------------------- visibility

static func _ray_seg(p: Vector2, d: Vector2, s: Array) -> float:
	var x3: float = s[0]
	var y3: float = s[1]
	var x4: float = s[2]
	var y4: float = s[3]
	var den := d.x * (y4 - y3) - d.y * (x4 - x3)
	if absf(den) < 1e-9:
		return INF
	var t := ((x3 - p.x) * (y4 - y3) - (y3 - p.y) * (x4 - x3)) / den
	var u := ((x3 - p.x) * d.y - (y3 - p.y) * d.x) / den
	return t if (t > 0.0 and u >= 0.0 and u <= 1.0) else INF

## The VISIBILITY POLYGON from p against wall segments [[x1, y1, x2, y2], …]
## plus the stage border: rays toward every corner (± a hair), nearest hit
## per ray, sorted by angle. Returns PackedVector2Array ready to fill.
static func vis_poly(b: Dictionary, p: Vector2, segs: Array) -> PackedVector2Array:
	var all: Array = segs.duplicate()
	all.append([0.0, 0.0, b.w, 0.0])
	all.append([b.w, 0.0, b.w, b.h])
	all.append([b.w, b.h, 0.0, b.h])
	all.append([0.0, b.h, 0.0, 0.0])
	var angles: Array = []
	for s in all:
		for e in 2:
			var a := atan2(float(s[1 + e * 2]) - p.y, float(s[e * 2]) - p.x)
			angles.append(a - 1e-4)
			angles.append(a)
			angles.append(a + 1e-4)
	angles.sort()
	var out := PackedVector2Array()
	for a in angles:
		var d := Vector2(cos(a), sin(a))
		var best := INF
		for s in all:
			var t := _ray_seg(p, d, s)
			if t < best:
				best = t
		if not is_finite(best):
			best = b.w + b.h
		out.append(p + d * best)
	return out

# ---------------------------------------------------------------- sound

## One AudioStreamGenerator shared by every card: voices are summed in
## _process (the sound_blips.gd recipe with a voice list). Created on the
## first tone and parented to the scene root, so it survives page turns.
class Synth extends Node:
	const MIX_RATE := 22050.0
	var player: AudioStreamPlayer
	var playback: AudioStreamGeneratorPlayback
	var voices: Array = []                            # dictionaries, see tone()
	var noise_state := 0.0
	func _ready() -> void:
		player = AudioStreamPlayer.new()
		var gen := AudioStreamGenerator.new()
		gen.mix_rate = MIX_RATE
		gen.buffer_length = 0.12
		player.stream = gen
		player.volume_db = -9.0
		add_child(player)
		player.play()
		playback = player.get_stream_playback()
	func _exit_tree() -> void:
		playback = null                               # drop the generator's playback so nothing leaks at quit
		if player != null:
			player.stop()
	func _process(_dt: float) -> void:
		if playback == null:
			return
		var frames: int = playback.get_frames_available()
		for i in frames:
			var l := 0.0
			var r := 0.0
			var j := voices.size() - 1
			while j >= 0:
				var v: Dictionary = voices[j]
				if v.delay > 0.0:
					v.delay -= 1.0 / MIX_RATE
					j -= 1
					continue
				var u: float = v.t / v.dur
				if u >= 1.0:
					voices.remove_at(j)
					j -= 1
					continue
				var env: float = v.vol * (1.0 - u) * minf(1.0, v.t / v.attack)
				var sample := 0.0
				if v.noise:
					var white := randf_range(-1.0, 1.0)
					var cutoff: float = lerpf(v.f0, v.f1, u)
					var k := clampf(cutoff / (MIX_RATE * 0.5), 0.01, 1.0)
					v.lp = v.lp + (white - v.lp) * k      # a one-pole low-pass, swept
					sample = v.lp
				else:
					var freq: float = v.f0 * pow(v.f1 / v.f0, u) if v.f1 > 0.0 else v.f0
					v.phase = fmod(v.phase + freq / MIX_RATE, 1.0)
					match v.type:
						"sine":
							sample = sin(v.phase * TAU)
						"triangle":
							sample = 4.0 * absf(v.phase - 0.5) - 1.0
						"sawtooth":
							sample = 2.0 * v.phase - 1.0
						_:
							sample = 1.0 if v.phase < 0.5 else -1.0
				sample *= env
				var pan: float = clampf(v.pan, -1.0, 1.0)
				l += sample * (1.0 - maxf(0.0, pan))
				r += sample * (1.0 + minf(0.0, pan))
				v.t += 1.0 / MIX_RATE
				j -= 1
			playback.push_frame(Vector2(clampf(l, -1.0, 1.0), clampf(r, -1.0, 1.0)))

static var _synth: Synth = null

static func _get_synth() -> Synth:
	if _synth != null and is_instance_valid(_synth):
		return _synth
	var loop := Engine.get_main_loop()
	if loop == null or not (loop is SceneTree):
		return null
	_synth = Synth.new()
	_synth.name = "StageSynth"
	var root := (loop as SceneTree).root
	if root.is_node_ready() and not root.is_ancestor_of(_synth):
		root.add_child(_synth)                        # straight in: a deferred add can miss a headless quit and leak
	return _synth

## One synthesized voice — the web's tone(o). o: freq, slide_to (0 = none),
## type ("square" | "triangle" | "sine" | "sawtooth"), dur, vol (≤ 0.25),
## pan (-1..1), attack, at (seconds from now, for scheduling ahead).
static func tone(o: Dictionary) -> void:
	var s := _get_synth()
	if s == null:
		return
	if s.voices.size() > 24:                          # a voice quota, so a burst can't hurt
		s.voices.pop_front()
	s.voices.append({ "noise": false, "f0": float(o.get("freq", 440.0)), "f1": float(o.get("slide_to", 0.0)),
		"type": str(o.get("type", "square")), "dur": maxf(0.02, float(o.get("dur", 0.15))),
		"vol": clampf(float(o.get("vol", 0.2)), 0.0, 0.3), "pan": float(o.get("pan", 0.0)),
		"attack": maxf(0.002, float(o.get("attack", 0.006))), "delay": float(o.get("at", 0.0)),
		"t": 0.0, "phase": 0.0, "lp": 0.0 })

## Filtered noise — the web's noiseBurst(o): dur, vol, lowpass (Hz),
## sweep_to (Hz), pan, attack, at.
static func noise_burst(o: Dictionary) -> void:
	var s := _get_synth()
	if s == null:
		return
	if s.voices.size() > 24:
		s.voices.pop_front()
	var lp := float(o.get("lowpass", 4000.0))
	s.voices.append({ "noise": true, "f0": lp, "f1": float(o.get("sweep_to", lp)), "type": "noise",
		"dur": maxf(0.02, float(o.get("dur", 0.3))), "vol": clampf(float(o.get("vol", 0.2)), 0.0, 0.3),
		"pan": float(o.get("pan", 0.0)), "attack": maxf(0.002, float(o.get("attack", 0.005))),
		"delay": float(o.get("at", 0.0)), "t": 0.0, "phase": 0.0, "lp": 0.0 })

static func beep(freq: float, dur: float = 0.12, type: String = "triangle") -> void:
	tone({ "freq": freq, "dur": dur, "type": type, "vol": 0.12 })

## How many voices are sounding right now (the web's voices()).
static func voices() -> int:
	if _synth == null or not is_instance_valid(_synth):
		return 0
	return _synth.voices.size()
