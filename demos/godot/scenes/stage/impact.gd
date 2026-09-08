extends RefCounted

const Kit := preload("res://scenes/stage/kit.gd")
## WEAPONS, IMPACTS & DECALS — thirteen effects, ported from the web almanac
## (docs/stagecraft.js, the impact family). Everything here begins with one
## EVENT — fire(), break(), light() — and the rest is what the event leaves
## behind. A muzzle flash is a two-frame sprite, a one-frame light and a
## recoil, all spawned by one call; a tracer is a line that lives three
## frames; an impact is a LOOKUP — the material the ray hit picks sparks,
## dust, chips or a ring; a decal is a stamp in a RING BUFFER that forgets
## the oldest; footprints are stamped by distance, not time; splats obey the
## hit normal, then gravity; debris bounces exactly once; barrels chain by
## radius and delay; fuses, grenades, telegraphs and tells are TIMERS YOU
## CAN SEE — the danger drawn before the hit, so the hit reads as fair.
##
## THE PAINTER'S VERSION OF A PERSISTENT LAYER. The web keeps its decals and
## its ink on an offscreen canvas that is never cleared (the ink layer dries
## by washing itself out a little a frame). Godot's _draw() starts blank
## every frame, so each stamp is a small record on b — the slot list of
## Decals, the splat list and drip pool of Ink — redrawn every frame with a
## ring-buffer cap, and "drying" is exp(−age / dry), which is what the
## per-frame wash converges to. Frame-counted things (a tracer's three
## frames, the two-frame trace line) count TICKS here, so tempo shortens
## them, as it does the web's. The web's "lighter" (additive) passes have
## no per-draw equivalent in 2D without a material: they are plain alpha
## here, with brighter colours where the addition mattered. Particle pools
## are preallocated in init and reused oldest-first, exactly as the web's.

const TITLE := "Weapons, impacts & decals"
const BLURB := "the fire() event and the marks it leaves — muzzle flash, casings, tracers, impacts by material, decal buffers, footprints, splats, debris, chain reactions, fuses, grenades, telegraphs, tells"
const DEFS := [
	{ "id": "muzzle", "letter": "M", "name": "Muzzle", "warn": "contains flashing light",
		"hint": "one fire() spawns a 2-frame flash, a 1-frame light, smoke and recoil — the shot as a timeline (ch06 sparks) — press to fire toward your click",
		"dials": { "every": 1.2,         # autopilot: seconds between shots
			"frameLen": 0.033,           # one "frame" of the flash sprite, in seconds
			"flashFrames": 2,            # the flash sprite lives this many frames
			"size": 1,                   # flash size multiplier
			"light": 0.28,               # the one-frame light: alpha of the whole-screen wash
			"recoil": 0.4,               # the kick's first peak, as a fraction of the barrel's length
			"spring": 600,               # the recoil spring's stiffness (ω = √spring ≈ 24 /s: a 4 Hz barrel)
			"damp": 0.35,                # its damping as a fraction of critical (2√spring) — under 1, so the barrel overshoots forward before it settles
			"smoke": 14,                 # puffs per shot
			"smokeLife": 1.0,            # seconds a puff lives
			"label": "fire() → flash sprite · 1-frame light · recoil: kv += v₀, kick'' = −spring·kick − c·kick' · smoke" },
		"rhyme": { "name": "Musket", "hint": "one big slow flash — four frames at twice the length — and a cloud of smoke that hangs: black powder",
			"dials": { "size": 1.9, "frameLen": 0.06, "smoke": 40 } } },
	{ "id": "eject", "letter": "E", "name": "Eject",
		"hint": "casings are tiny bodies: thrown sideways, they bounce with restitution and spin, then rest — lexicon Bounce with a tink — press to fire",
		"dials": { "every": 0.45,        # autopilot: seconds between shots
			"rest": 0.45,                # restitution: how much of the fall speed survives a bounce
			"friction": 0.6,             # what a bounce keeps of the sideways speed and the spin
			"g": 2.0,                    # gravity, in H per second²
			"eject": 0.22,               # ejection speed sideways, in W per second
			"spin": 30,                  # max spin, radians per second
			"settle": 2.5,               # seconds a resting casing stays before it fades
			"spring": 600,               # the recoil spring's stiffness (Muzzle's idiom: ω = √spring ≈ 24 /s)
			"damp": 0.35,                # its damping as a fraction of critical — under 1, so the barrel overshoots forward before it settles
			"label": "on ground: vy ← −e·vy · vx ← μ·vx · ω ← μ·ω" },
		"rhyme": { "name": "Empties", "hint": "a belt-fed stream — a shot every tenth of a second — and casings that never fade, so the pool of forty piles up and steals its oldest",
			"dials": { "every": 0.09, "settle": 40, "rest": 0.3 } } },
	{ "id": "tracer", "letter": "T", "name": "Tracer",
		"hint": "instant hits made visible: a line from the muzzle to the ray's hit point that lives 3 frames (lexicon Xmarks) — press to fire at your click",
		"dials": { "every": 0.6,         # autopilot: seconds between shots
			"frames": 3,                 # a plain tracer lives this many FRAMES, not seconds
			"glowEvery": 0,              # every n-th shot glows and lingers (0 = never)
			"linger": 0.8,               # seconds a glowing tracer takes to fade
			"spread": 0.04,              # aim error, radians
			"spring": 600,               # the recoil spring's stiffness (Muzzle's idiom: ω = √spring ≈ 24 /s)
			"damp": 0.35,                # its damping as a fraction of critical — under 1, so the barrel overshoots forward before it settles
			"label": "hit = nearest t over segments · plain tracer: alpha = frames left / 3" },
		"rhyme": { "name": "Tracerfire", "hint": "every third round is a real tracer — it glows orange and lingers a second while the plain rounds still vanish in three frames",
			"dials": { "glowEvery": 3, "linger": 1.0, "every": 0.35 } } },
	{ "id": "impact", "letter": "I", "name": "Impact",
		"hint": "the hit normal and a material lookup pick the effect — sparks, dust, chips or a ring (codex Hit spark) — press to shoot the panel under your click",
		"dials": { "materials": [ { "name": "metal", "fx": "sparks", "c": "#9AA3B5" },   # the LOOKUP TABLE: material → effect
				{ "name": "stone", "fx": "dust", "c": "#7B7686" },
				{ "name": "wood", "fx": "chips", "c": "#8A6A3E" },
				{ "name": "water", "fx": "ring", "c": "#3E7FB0" } ],
			"every": 1.1,                # autopilot: seconds between shots
			"count": 14,                 # particles per hit (scaled per effect)
			"g": 1.8,                    # gravity, in H per second²
			"night": 0.2,
			"spring": 600,               # the recoil spring's stiffness (Muzzle's idiom: ω = √spring ≈ 24 /s)
			"damp": 0.35,                # its damping as a fraction of critical — under 1, so the barrel overshoots forward before it settles
			"label": "ray → hit point + normal n · table[material] → effect" },
		"rhyme": { "name": "Icefield", "hint": "the same ray and the same table with cold rows: ice throws shards, frost and snow puff white, slush rings — a winter level's lookup",
			"dials": { "materials": [ { "name": "ice", "fx": "chips", "c": "#BFE6F7" }, { "name": "frost", "fx": "dust", "c": "#DDE9F2" }, { "name": "snow", "fx": "dust", "c": "#F1F5F9" }, { "name": "slush", "fx": "ring", "c": "#8FB9D4" } ], "night": 0.5 } } },
	{ "id": "decals", "letter": "D", "name": "Decals",
		"hint": "holes and scorch marks in a ring buffer of N — newest overwrites oldest, which fades first (codex Ground crack) — press to stamp at your click",
		"dials": { "n": 12,              # the RING BUFFER holds this many decals
			"fade": 3,                   # once full, the oldest few slots dim in steps toward the exit
			"every": 0.9,                # autopilot: seconds between stamps
			"kind": "bullet",            # "bullet": holes and scorch marks · "chalk": chalk scribbles
			"scorchEvery": 4,            # every n-th bullet stamp is a scorch mark
			"size": 1,
			"spring": 600,               # the recoil spring's stiffness (Muzzle's idiom: ω = √spring ≈ 24 /s)
			"damp": 0.35,                # its damping as a fraction of critical — under 1, so the barrel overshoots forward before it settles
			"label": "slot = head mod N · head++ · alpha by age rank" },
		"rhyme": { "name": "Doodles", "hint": "chalk circles and crosses in a buffer of only five — the limit shows: the sixth scribble wipes the first",
			"dials": { "kind": "chalk", "n": 5, "every": 0.6 } } },
	{ "id": "marks", "letter": "M", "name": "Marks",
		"hint": "footprints and tyre tracks stamped per stride of distance, not time, fading with age (codex Skid smoke) — press to send the hero",
		"dials": { "stride": 0.055,      # W between footprints — a stamp per stride, never per frame
			"tyre": 0.018,               # W between tyre-track dashes
			"life": 6,                   # seconds a mark takes to fade to nothing
			"size": 1,                   # print width multiplier
			"palette": ["#E9EEF5", "#93A6BE"],   # the ground, and the mark pressed into it
			"speed": 0.28,               # hero speed, W per second
			"carSpeed": 0.2,             # car speed, W per second
			"label": "stamp when Σ|dx| ≥ stride · alpha = 1 − age / life" },
		"rhyme": { "name": "Mudtrack", "hint": "dark mud instead of snow — wide prints that take sixteen seconds to dry out, so the whole route stays written",
			"dials": { "palette": ["#6E5137", "#2A1B0F"], "life": 16, "size": 1.6 } } },
	{ "id": "ink", "letter": "I", "name": "Ink",
		"hint": "a blob on the far side of the hit normal, drips that grow down — blood, ink or paint by one dial (grimoire Wet paint) — press to splat at your click",
		"dials": { "colour": "#D8323C",  # the liquid
			"paper": "#5E5880",          # the wall it lands on
			"push": 0.03,                # W: how far past the hit point the blob's centre lands (along the shot)
			"blobs": 8,                  # circles per splat
			"size": 1,
			"drips": 3,                  # drips per splat
			"drip": 1.0,                 # drip growth, in H per second
			"dry": 14,                   # seconds for the layer to wash back to clean
			"every": 1.3,                # autopilot: seconds between splats
			"spring": 600,               # the recoil spring's stiffness (Muzzle's idiom: ω = √spring ≈ 24 /s)
			"damp": 0.35,                # its damping as a fraction of critical — under 1, so the barrel overshoots forward before it settles
			"label": "centre = hit − n · push · drip: y += rate·dt, width ↓" },
		"rhyme": { "name": "Inkwell", "hint": "black ink on cream paper with drips twice as eager — a calligrapher's accident",
			"dials": { "colour": "#14121A", "paper": "#EFE6D0", "drip": 2.2 } } },
	{ "id": "rubble", "letter": "R", "name": "Rubble",
		"hint": "a block breaks into 4–8 chunks with random spin and gravity that bounce once, then fade (folio Explosion) — press to break a block at your click",
		"dials": { "pieces": [4, 8],     # how many chunks a block breaks into (min, max)
			"g": 2.0,                    # gravity, in H per second²
			"spin": 9,                   # max spin, radians per second
			"rest": 0.4,                 # restitution of the one bounce
			"size": 1,                   # block and chunk size multiplier
			"colour": "#8A6A3E",         # the block's material
			"hold": 0.8,                 # seconds a settled chunk lies still before fading
			"fade": 1.0,                 # seconds the fade takes
			"respawn": 3,                # seconds before a broken block is back
			"every": 2.2,                # autopilot: seconds between breaks
			"label": "v += g·dt · θ += ω·dt · bounce ×1 (e) → hold → fade" },
		"rhyme": { "name": "Rockfall", "hint": "grey stone blocks nearly twice the size, chunks that do not spin, and more dust — a quarry, not a crate",
			"dials": { "spin": 0, "size": 1.7, "colour": "#7E7A86" } } },
	{ "id": "kaboom", "letter": "K", "name": "Kaboom",
		"hint": "a blast radius lights every barrel inside it after a delay — a queue of timed detonations, dominoes too (lexicon Knock) — press to light a barrel",
		"dials": { "barrels": 7,         # barrels in the field
			"radius": 0.15,              # blast radius, in W
			"delay": 0.35,               # seconds a barrel inside a blast waits before it goes
			"fuse": 0.7,                 # seconds a hand-lit barrel takes
			"respawn": 4,                # seconds after the last blast before the field resets
			"dominoes": 8,
			"tip": 0.12,                 # seconds from a falling domino touching the next to the next one going — the shove's latency
			"g": 2.0,                    # gravity, in H per second² — a domino is a rod on its base corner: θ'' = (3g / 2L)·sin θ
			"shove": 2.5,                # the angular speed a blast gives the first domino, rad/s; each hands 0.6 of its own to the next
			"every": 3.5,                # autopilot: seconds between lightings
			"night": 0.4,
			"label": "d(b, blast) < R → queue(now + delay) · domino: θ'' = (3g/2L)·sin θ · touches i+1 → queue(now + tip)" },
		"rhyme": { "name": "Krakatoa", "hint": "a radius half the stage and a second's delay before each barrel answers — the slow doom you can count down",
			"dials": { "radius": 0.5, "delay": 1.1, "respawn": 6 } } },
	{ "id": "wick", "letter": "W", "name": "Wick",
		"hint": "a spark walks a Bézier rope at a fixed rate, trailing smoke — a timer you can see (lexicon Path); it pops and resets — press to light or hurry it",
		"dials": { "kind": "fuse",       # "fuse": a rope to a bomb · "candle": a wick burning down a candle, wax creeping down the sides
			"burn": 4,                   # seconds the whole length takes at the plain rate
			"hurry": 3,                  # a press while lit multiplies the rate by this
			"path": [[0.08, 0.6], [0.24, 0.05], [0.5, 0.98], [0.8, 0.7]],   # the rope's cubic Bézier: start, two controls, end — fractions of W and H
			"sparks": 40,                # sparks thrown per second while lit
			"smoke": 8,                  # puffs per second
			"pause": 1.4,                # seconds between the pop and the next lighting
			"label": "p(u) = Σ Bᵢ(u)·Pᵢ · u from the arc-length table · s += (L / burn)·dt" },
		"rhyme": { "name": "Waxwick", "hint": "the same clock stood upright: a wick twelve seconds down a candle, wax creeping down the sides, and a gutter of smoke instead of a bang",
			"dials": { "kind": "candle", "burn": 12, "path": [[0.5, 0.32], [0.5, 0.45], [0.5, 0.6], [0.5, 0.74]] } } },
	{ "id": "grenade", "letter": "G", "name": "Grenade", "drag": true,
		"hint": "fuse runs from the pin: arc preview while held, bounces, blast — cook too long, it goes off in hand (lexicon Bounce) — drag to aim, let go to throw",
		"dials": { "kind": "frag",       # "frag": a flash and shrapnel · "gas": a cloud that lingers
			"fuse": 3,                   # seconds from the pin to the blast
			"throwV": 1.1,               # throw speed at a full-length aim, in H per second
			"g": 2.2,                    # gravity, in H per second²
			"rest": 0.45,                # restitution: what a bounce keeps of the vertical speed
			"friction": 0.7,             # what a bounce keeps of the sideways speed
			"release": 0.15,             # seconds without a press = you let go
			"cloud": 4,                  # gas only: seconds the cloud lingers
			"cook": [0.3, 3.4],          # autopilot: how long it holds a live grenade (min, max) — past the fuse it cooks off
			"every": 2.4,                # autopilot: seconds between throws
			"label": "fuse −= dt from the pull · preview = the same integrator run ahead · vy ← −e·vy" },
		"rhyme": { "name": "Gasbomb", "hint": "the same pin, arc and bounces, but the payload is a cloud: puffs that spread for six seconds instead of a flash — cook it and it lands ready",
			"dials": { "kind": "gas", "cloud": 6, "fuse": 2.5 } } },
	{ "id": "aoe", "letter": "A", "name": "Aoe",
		"hint": "circle, cone or line fills over the windup, then hits — danger you can read (ch14 telegraph); the hero steps out once it reacts — press to place one",
		"dials": { "windup": 1.2,        # seconds a telegraph fills before it hits
			"shape": "cycle",            # "circle" | "cone" | "line" | "cycle" through all three
			"count": 1,                  # telegraphs per cast, staggered
			"gap": 1.0,                  # seconds between casts
			"radius": 0.13,              # circle radius, in W
			"cone": 0.45,                # cone half-angle, radians
			"range": 0.5,                # cone and line reach, in W
			"width": 0.06,               # line width, in W
			"react": 0.35,               # hero's reaction time before it starts to step out
			"speed": 0.3,                # hero's escape speed, in W per second
			"label": "fill = age / windup → hit at 1 · inside(shape, hero) ? hit : dodged" },
		"rhyme": { "name": "Ambush", "hint": "half-second windups, three shapes at once with overlaps — the way out of one is into the next, and the hero's reaction time is suddenly the whole game",
			"dials": { "windup": 0.5, "count": 3, "gap": 0.7 } } },
	{ "id": "tell", "letter": "T", "name": "Tell",
		"hint": "before each swing the enemy flashes white and leans back 0.2 s — the tell: a dodge inside it is safe, a late one is hit (lexicon Cat) — press to dodge",
		"dials": { "tell": 0.2,          # seconds of the wind-up: the flash and the lean
			"lean": 0.35,                # radians the body leans back at the tell's peak
			"tint": "white",             # "white" flash or "red" tint during the tell
			"strike": 0.1,               # seconds the swing takes to land
			"recover": 0.7,              # seconds the enemy hangs after a swing
			"every": 1.6,                # seconds between attacks
			"dodgeLen": 0.35,            # seconds a dodge's safe window lasts
			"react": 0.25,               # the hero's reaction time (± a little noise)
			"k": 350,                    # the body's lean spring: stiffness (ω = √k ≈ 19 /s — quick enough to track a 0.2 s tell)
			"damp": 0.45,                # its damping as a fraction of critical — under 1, so the recovery overshoots upright: the follow-through
			"armK": 0.5,                 # the arm's stiffness as a multiple of the body's — under 1, so the arm lags the body and whips through after it
			"armDamp": 0.5,              # the arm's damping, as a fraction of ITS OWN critical — under 1, so it whips past the strike pose and comes back
			"label": "tell → strike → recover set the targets · lean, arm: θ'' = k·(target − θ) − c·θ' · safe if dodge ≤ land ≤ dodge + dodgeLen" },
		"rhyme": { "name": "Telegraphed", "hint": "a tutorial boss: a tell three times as long with a deep lean — the hero has time to wait and hop just before the swing, and nearly always does",
			"dials": { "tell": 0.6, "lean": 0.7, "every": 2.4 } } },
]

const FAINT := Color(0.91, 0.898, 0.957, 0.55)   # the web label's default ink
const INK_DARK := Color("2B2440")                  # barrels, wheels, the sprite's outline colour
const WOOD := Color("5A3E2B")
const PALE := Color(1.0, 0.941, 0.745)             # "rgba(255,240,190,·)": tracer lines
const SMOKE := Color(0.745, 0.729, 0.824)          # "rgba(190,186,210,·)": gun smoke

# ================================================================ helpers

## c with its alpha replaced (the web's rgba(c, a)).
static func _al(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, a)

## The web kit's ease(): a clamped smoothstep.
static func _ease(k: float) -> float:
	var x := clampf(k, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)

## A font size in px scaled with the card (S = H / 170), never below 6.
static func _fs(S: float, px: float) -> int:
	return maxi(6, roundi(px * S))

## The web text's "right" alignment: measure, then draw ending at p.x.
static func _text_r(n: CanvasItem, txt: String, p: Vector2, size: int, col: Color) -> void:
	var f := ThemeDB.fallback_font
	n.draw_string(f, Vector2(p.x - f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x, p.y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

## The web's setLineDash on one segment: short lines with gaps.
static func _dash_line(n: CanvasItem, a: Vector2, c: Vector2, col: Color, w: float, on: float, off: float) -> void:
	var d := a.distance_to(c)
	if d < 0.01:
		return
	var dir := (c - a) / d
	var pos := 0.0
	while pos < d:
		n.draw_line(a + dir * pos, a + dir * minf(d, pos + on), col, w)
		pos += on + off

## A dashed ring: arcs with gaps.
static func _dash_ring(n: CanvasItem, c: Vector2, r: float, col: Color, w: float, on: float, off: float) -> void:
	r = maxf(1.0, r)
	var step := (on + off) / r
	var a := 0.0
	while a < TAU:
		n.draw_arc(c, r, a, minf(TAU, a + on / r), 4, col, w)
		a += step

## An ellipse outline (the web's ctx.ellipse + stroke).
static func _ellipse_ring(n: CanvasItem, c: Vector2, rx: float, ry: float, col: Color, w: float) -> void:
	var pts := PackedVector2Array()
	for i in 33:
		var a := i / 32.0 * TAU
		pts.append(c + Vector2(cos(a) * maxf(0.3, rx), sin(a) * maxf(0.3, ry)))
	n.draw_polyline(pts, col, w)

## A pool of count particles, each a copy of the template (the web's
## "for i < N pool.push({...})") — allocated once, reused oldest-first.
static func _pool(count: int, template: Dictionary) -> Array:
	var out: Array = []
	for _i in count:
		out.append(template.duplicate())
	return out

## A gun's muzzle tip: base + (cos aim, sin aim) · (L − kick).
static func _tip(base: Vector2, aim: float, kick: float, L: float) -> Vector2:
	return base + Vector2(cos(aim), sin(aim)) * (L - kick)

## The barrel, kicked back by RECOIL: two dark rects drawn in the gun's frame.
static func _barrel(n: CanvasItem, b: Dictionary, base: Vector2, aim: float, kick: float, L: float, u: float) -> void:
	var origin: Vector2 = (b.rect as Rect2).position
	n.draw_set_transform(origin + base, aim, Vector2.ONE)
	n.draw_rect(Rect2(-kick, -1.1 * u, L, 2.1 * u), INK_DARK)
	n.draw_rect(Rect2(1.5 * u - kick, 0.0, 2.0 * u, 3.0 * u), INK_DARK)
	n.draw_set_transform(origin, 0.0, Vector2.ONE)

## The recoil spring's impulse: a shot adds VELOCITY to the barrel, never
## position. From rest, kick'' = −k·kick − c·kick' with kick' = v₀ peaks at
## v₀/√k · e^(−ζφ/√(1−ζ²)), φ = atan(√(1−ζ²)/ζ) — so this v₀ puts the first
## peak at exactly peak px (ζ = damp, the fraction of critical).
static func _recoil_kick(b: Dictionary, peak: float) -> void:
	var D: Dictionary = b.D
	var w := sqrt(maxf(1.0, float(D.spring)))
	var z := clampf(float(D.damp), 0.0, 0.99)
	var q := sqrt(1.0 - z * z)
	b.kv += peak * w * exp(z * atan2(q, z) / q)

## The recoil spring, stepped: kick'' = −spring·kick − c·kick', c = damp·2√spring,
## symplectic euler at ≤ 5 ms (it is stiff, and one number costs nothing).
## Under-damped, so the barrel overshoots forward past rest before it settles.
static func _recoil_step(b: Dictionary, dt: float) -> void:
	var D: Dictionary = b.D
	var k: float = maxf(1.0, float(D.spring))
	var c: float = 2.0 * clampf(float(D.damp), 0.0, 0.99) * sqrt(k)
	var sub := maxi(1, ceili(dt * 200.0))
	var h := dt / float(sub)
	var kick: float = b.kick
	var kv: float = b.kv
	for _s in sub:
		kv += (-k * kick - c * kv) * h
		kick += kv * h
	b.kick = clampf(kick, -float(b.L), float(b.L))
	b.kv = kv

## A ray from p along d against one segment [x1, y1, x2, y2]: the distance
## t of the hit, or -1 when it misses (the web's hitSeg, Infinity → -1 so
## nothing non-finite is ever stored on b).
static func _seg_hit(p: Vector2, d: Vector2, g: Array) -> float:
	var x3: float = g[0]
	var y3: float = g[1]
	var x4: float = g[2]
	var y4: float = g[3]
	var den := d.x * (y4 - y3) - d.y * (x4 - x3)
	if absf(den) < 1e-9:
		return -1.0
	var tt := ((x3 - p.x) * (y4 - y3) - (y3 - p.y) * (x4 - x3)) / den
	var w := ((x3 - p.x) * d.y - (y3 - p.y) * d.x) / den
	return tt if (tt > 0.0 and w >= 0.0 and w <= 1.0) else -1.0

## A short-lived tracer / spark: a line from p back along its velocity.
static func _streak(n: CanvasItem, p: Vector2, v: Vector2, back: float, col: Color, w: float) -> void:
	n.draw_line(p, p - v * back, col, w)

## The wick's point a distance along the rope, from its arc-length table.
static func _wick_at(b: Dictionary, dist: float) -> Vector2:
	var pts: Array = b.pts
	var cum: Array = b.cum
	var N: int = pts.size() - 1
	dist = clampf(dist, 0.0, b.L)
	var i := 1
	while i < N and float(cum[i]) < dist:
		i += 1
	var c0: float = cum[i - 1]
	var c1: float = cum[i]
	var k := (dist - c0) / maxf(1e-6, c1 - c0)
	var p0: Vector2 = pts[i - 1]
	var p1: Vector2 = pts[i]
	return p0 + (p1 - p0) * k

## One grenade integrator step, shared by the flight and the preview:
## gravity, the ground (restitution e, friction μ), the walls, the crate.
static func _gren_step(b: Dictionary, o: Dictionary, dt: float) -> void:
	var D: Dictionary = b.D
	var W: float = b.w
	var H: float = b.h
	var GY: float = b.gy
	var R: float = b.R
	var G: float = b.G
	var cx: float = b.cx
	var cs: float = b.cs
	o.vy += G * dt
	o.x += o.vx * dt
	o.y += o.vy * dt
	if o.y > GY - R:
		o.y = GY - R
		if o.vy > H * 0.08:
			o.vy = -o.vy * D.rest
			o.vx *= D.friction
			o.b += 1
		else:
			o.vy = 0.0
			o.vx *= maxf(0.0, 1.0 - 3.0 * dt)
	if o.x < R:
		o.x = R
		o.vx = absf(o.vx) * D.rest
	elif o.x > W - R:
		o.x = W - R
		o.vx = -absf(o.vx) * D.rest
	var l := cx - cs / 2.0 - R                           # the crate: a box to bounce off
	var r := cx + cs / 2.0 + R
	var top := GY - cs - R
	if o.x > l and o.x < r and o.y > top:
		var px := minf(o.x - l, r - o.x)
		var py: float = o.y - top
		if py < px:
			o.y = top
			if o.vy > 0.0:
				o.vy = -o.vy * D.rest
				o.vx *= D.friction
				o.b += 1
		elif o.x < cx:
			o.x = l
			o.vx = -absf(o.vx) * D.rest
		else:
			o.x = r
			o.vx = absf(o.vx) * D.rest

## The grenade: a ball, a cap, a pin ring, drawn at p turned by rot.
static func _grenade(n: CanvasItem, b: Dictionary, p: Vector2, rot: float, a: float) -> void:
	var origin: Vector2 = (b.rect as Rect2).position
	var R: float = b.R
	var gas: bool = b.gas
	n.draw_set_transform(origin + p, rot, Vector2.ONE)
	n.draw_circle(Vector2.ZERO, R, _al(Color("5A7A5A") if gas else Color("3F4A3A"), a))
	n.draw_rect(Rect2(-R * 0.4, -R * 1.4, R * 0.8, R * 0.6), _al(Color("9A9AA8"), a))
	n.draw_line(Vector2(R * 0.4, -R * 1.2), Vector2(R * 1.3, -R * 0.4), _al(Kit.BONE, a), 1.0)
	n.draw_set_transform(origin, 0.0, Vector2.ONE)

## An AoE telegraph's outline at a fraction of its full size, as points
## on the squashed floor (the web's shape()).
static func _aoe_shape(b: Dictionary, g: Dictionary, frac: float) -> PackedVector2Array:
	var D: Dictionary = b.D
	var W: float = b.w
	var GY: float = b.gy
	var SQ: float = b.SQ
	var r: float = W * D.radius
	var rg: float = W * D.range
	var hw: float = W * D.width / 2.0
	var gx: float = g.x
	var gz: float = g.z
	var ax: float = g.ax
	var az: float = g.az
	var pts := PackedVector2Array()
	if g.kind == "circle":
		for i in 32:
			var a := i / 32.0 * TAU
			pts.append(Vector2(gx + cos(a) * maxf(0.5, r * frac), GY + (gz + sin(a) * maxf(0.5, r * frac)) * SQ))
		return pts
	if g.kind == "line":
		var px := -az * hw
		var pz := ax * hw
		var lx := ax * rg * frac
		var lz := az * rg * frac
		pts.append(Vector2(gx + px, GY + (gz + pz) * SQ))
		pts.append(Vector2(gx + lx + px, GY + (gz + lz + pz) * SQ))
		pts.append(Vector2(gx + lx - px, GY + (gz + lz - pz) * SQ))
		pts.append(Vector2(gx - px, GY + (gz - pz) * SQ))
		return pts
	var a0 := atan2(az, ax)
	pts.append(Vector2(gx, GY + gz * SQ))
	for i in 13:
		var a: float = a0 - D.cone + D.cone * 2.0 * i / 12.0
		pts.append(Vector2(gx + cos(a) * rg * frac, GY + (gz + sin(a) * rg * frac) * SQ))
	return pts

## Is the floor point (px, pz) inside telegraph g? (the web's inside())
static func _aoe_inside(b: Dictionary, g: Dictionary, px: float, pz: float) -> bool:
	var D: Dictionary = b.D
	var W: float = b.w
	var dx: float = px - g.x
	var dz: float = pz - g.z
	if g.kind == "circle":
		return Vector2(dx, dz).length() < W * D.radius
	var ax: float = g.ax
	var az: float = g.az
	var along := dx * ax + dz * az
	var perp := -dx * az + dz * ax
	if g.kind == "line":
		return along > 0.0 and along < W * D.range and absf(perp) < W * D.width / 2.0
	return along > 0.0 and Vector2(dx, dz).length() < W * D.range and absf(atan2(perp, along)) < D.cone

## The shortest way out of g: away from a circle's centre, across a cone's
## or a line's aim (the web's out()).
static func _aoe_out(g: Dictionary, px: float, pz: float) -> Vector2:
	var dx: float = px - g.x
	var dz: float = pz - g.z
	if g.kind == "circle":
		var d := Vector2(dx, dz).length()
		return Vector2(0.0, 1.0) if d < 1e-6 else Vector2(dx / d, dz / d)
	var ax: float = g.ax
	var az: float = g.az
	var perp := -dx * az + dz * ax
	var sg := 1.0 if perp >= 0.0 else -1.0
	return Vector2(-az * sg, ax * sg)

# ================================================================ init

static func init(b: Dictionary) -> void:
	var D: Dictionary = b.D
	var W: float = b.w
	var H: float = b.h
	var GY: float = b.gy
	var u := Kit.hero_unit(b)                            # the web's s: the hero's unit
	b.u = u
	match b.id:
		"muzzle":
			# a MUZZLE FLASH is not one thing: fire() is an EVENT that spawns four
			# short-lived things at once — a flash SPRITE that lives two frames (big,
			# then small), a LIGHT that lives one frame and paints the ground, a smoke
			# puff that lives a second, and a RECOIL — a real spring on the barrel: the
			# shot adds VELOCITY (never position), the spring pulls the barrel back
			# toward rest and, being under-damped, carries it forward PAST rest before
			# it settles — that overshoot is what reads as weight. chapter 06's sparks
			# were the smoke; the strip at the top is the timeline of one shot, so you
			# can see how short "short" is — the recoil row is the spring's real settle.
			b.hx = W * 0.26
			b.L = 8.0 * u
			b.timer = D.every * 0.6
			b.shotT = 9.0
			b.kick = 0.0
			b.kv = 0.0
			b.aim = -0.2
			b.rot = 0.0
			b.armed_sound = false
			b.tx = W * 0.8
			b.ty = GY - H * 0.15
			b.pool = _pool(60, { "on": false, "x": 0.0, "y": 0.0, "vx": 0.0, "vy": 0.0, "life": 0.0, "r": 1.0 })
			b.pi = 0
		"eject":
			# every SHELL CASING is a small rigid body with three numbers: a velocity,
			# a spin, and a RESTITUTION e. the ground flips the vertical speed and
			# multiplies it by e (lexicon Bounce), friction μ eats the sideways speed
			# and the spin, and once the bounce is smaller than a pixel the casing
			# lies flat and waits to fade. the first bounce is the tink. the pool is
			# 40 casings, reused oldest-first — a belt of them costs nothing.
			b.hx = W * 0.3
			b.L = 8.0 * u
			b.G = H * D.g
			b.pool = _pool(40, { "on": false, "x": 0.0, "y": 0.0, "vx": 0.0, "vy": 0.0, "rot": 0.0, "vr": 0.0, "bounces": 0, "restT": 0.0, "age": 0.0 })
			b.pi = 0
			b.timer = 0.0
			b.kick = 0.0
			b.kv = 0.0
			b.flash = 0.0
			b.armed_sound = false
			b.tinkGap = 0.0
			b.fired = 0
			b.last = -1                                  # the pool index of the newest casing
		"tracer":
			# a hitscan shot arrives the same frame it leaves, so there is nothing to
			# see. the TRACER is the fix: cast one RAY against every terrain segment
			# (lexicon Xmarks), keep the nearest hit, and draw a line from muzzle to
			# hit point for three frames — counted in frames, because that is what the
			# eye reads. the dim rings are the other candidates the ray crossed; the
			# bright one is the minimum t. every n-th shot can glow and linger instead.
			b.hx = W * 0.14
			b.L = 8.0 * u
			var cx := W * 0.6
			var cs := u * 6.0
			var wx := W * 0.86
			var ww := u * 4.0
			var wh := H * 0.42
			b.cx = cx
			b.cs = cs
			b.wx = wx
			b.ww = ww
			b.wh = wh
			b.segs = [[0.0, GY, W, GY], [cx - cs / 2.0, GY - cs, cx + cs / 2.0, GY - cs], [cx - cs / 2.0, GY - cs, cx - cs / 2.0, GY],
				[wx, GY - wh, wx + ww, GY - wh], [wx, GY - wh, wx, GY], [0.0, 0.0, W, 0.0], [W, 0.0, W, H], [0.0, 0.0, 0.0, H]]
			b.tracers = []
			b.sparks = _pool(24, { "on": false, "x": 0.0, "y": 0.0, "vx": 0.0, "vy": 0.0, "life": 0.0 })
			b.si = 0
			b.timer = 0.0
			b.aim = -0.1
			b.kick = 0.0
			b.kv = 0.0
			b.shots = 0
			b.cand = []
			b.candT = 9.0
			b.tx = W * 0.7
			b.ty = GY - H * 0.2
		"impact":
			# an IMPACT is two facts and a table. the ray gives a HIT POINT and the
			# surface's NORMAL n (perpendicular to the segment it struck); the surface
			# names a MATERIAL; a LOOKUP TABLE turns the material into an effect —
			# sparks that fly off n and fall (codex Hit spark), dust that drifts, chips
			# that tumble, a ring that spreads on water. same bullet, four answers.
			# the table is drawn top-right; the row that fired lights up.
			b.ly = GY - H * 0.3
			b.hx = W * 0.11
			b.L = 8.0 * u
			b.G = H * D.g
			var x0 := W * 0.26
			var pw := (W - x0) / 4.0
			b.x0 = x0
			b.pw = pw
			var panels: Array = []
			for i in 4:
				var a := x0 + i * pw
				var bb := a + pw
				var ya := GY + u * 0.8 if i == 3 else GY   # stone is a ramp, water sits lower
				var yb := GY - H * 0.07 if i == 1 else ya
				var nv := Vector2(yb - ya, -(bb - a))
				nv = nv / (nv.length() if nv.length() > 0.0 else 1.0)
				if nv.y > 0.0:
					nv = -nv
				panels.append({ "a": a, "b": bb, "ya": ya, "yb": yb, "nx": nv.x, "ny": nv.y })
			b.panels = panels
			b.pool = _pool(120, { "on": false, "kind": "", "x": 0.0, "y": 0.0, "vx": 0.0, "vy": 0.0, "life": 0.0, "rot": 0.0, "vr": 0.0, "c": Color.WHITE, "r": 1.0 })
			b.pi = 0
			b.rings = []
			b.timer = 0.4
			b.aim = 0.5
			b.kick = 0.0
			b.kv = 0.0
			b.lastHit = {}
			b.hitT = 9.0
			b.lastRow = -1
			b.trace = 0
			b.tr0 = Vector2.ZERO
			b.tr1 = Vector2.ZERO
		"decals":
			# decals are cheap to draw and expensive to keep, so a game keeps N of
			# them in a RING BUFFER: stamp number k lives in slot k mod N, and when the
			# buffer is full the newest simply overwrites the oldest. here the doomed
			# slots dim by AGE RANK so you can watch the queue advance. the buffer is
			# one offscreen layer drawn UNDER the hero and the props — a decal is part
			# of the wall, not of the world (codex Ground crack was one such stamp).
			# (here the layer is the slot list itself, redrawn under the props each frame.)
			b.hx = W * 0.14
			b.L = 8.0 * u
			b.wx = W * 0.36
			b.wy = H * 0.14
			var N := maxi(1, roundi(D.n))
			b.N = N
			b.slots = _pool(N, { "on": false, "x": 0.0, "y": 0.0, "kind": "hole", "seed": 0, "a": 0.0, "seq": 0, "shape": [] })
			b.head = 0
			b.stamped = 0
			b.timer = 0.3
			b.aim = -0.1
			b.kick = 0.0
			b.kv = 0.0
			b.trace = 0
			b.tr0 = Vector2.ZERO
			b.tr1 = Vector2.ZERO
		"marks":
			# footprints stamped every frame become a smear; stamped every N seconds
			# they drift apart when the hero speeds up. the honest rule is DISTANCE: add
			# up |dx| and stamp a print each time the sum passes one stride (a tyre
			# track is the same rule with a shorter stride, twice — once per wheel).
			# every mark remembers its birth; alpha = 1 − age/life, and the graph at
			# the top-right plots each living mark on that line as it slides off.
			b.roadY = GY + (H - GY) * 0.62
			b.prints = _pool(80, { "on": false, "x": 0.0, "y": 0.0, "age": 0.0, "side": 0 })
			b.tyres = _pool(140, { "on": false, "x": 0.0, "y": 0.0, "age": 0.0 })
			b.pi = 0
			b.ti = 0
			b.hx = W * 0.3
			b.tx = W * 0.75
			b.acc = 0.0
			b.steps = 0
			b.face = 1
			b.dist = 0.0
			b.carX = -W * 0.1
			b.carAcc = 0.0
		"ink":
			# a SPLAT has two halves. the stamp: a cluster of circles whose centre
			# sits on the FAR SIDE of the hit normal — the liquid keeps the shot's
			# momentum past the point of contact, so the blob smears away from the
			# shooter. the drips: gravity takes over; a few threads grow downward
			# each frame, thinning as they go. both live on one persistent layer
			# (grimoire Wet paint), which dries by washing itself out a little a frame.
			# (here: a ring buffer of 24 splats and a drip pool, each fading by
			# exp(−age / dry) — what the per-frame wash converges to.)
			b.hx = W * 0.12
			b.L = 8.0 * u
			b.wy = H * 0.1
			b.stamps = []                                # splats: { circles: [Vector3(x, y, r)…], age }
			b.drips = _pool(40, { "on": false, "alive": false, "x": 0.0, "y0": 0.0, "y": 0.0, "w0": 0.0, "w": 0.0, "rate": 0.0, "remain": 0.0, "age": 0.0 })
			b.di = 0
			b.timer = 0.5
			b.aim = -0.1
			b.kick = 0.0
			b.kv = 0.0
			b.last = {}
			b.hitT = 9.0
			b.splats = 0
		"rubble":
			# DEBRIS is the cheapest physics there is: a handful of quads with a
			# velocity, a spin, and gravity. the rule that sells it is ONE BOUNCE —
			# the first ground contact flips vy by e and halves the spin, the second
			# stops the chunk dead — then a short hold and a fade, so the ground never
			# fills up. the chunks are cut from the block's own rectangle, so their
			# colours and sizes agree with what broke (lexicon Knock did the push).
			b.G = H * D.g
			b.B = u * 5.0 * D.size
			var blocks: Array = []
			for i in 4:
				blocks.append({ "x": W * (0.24 + i * 0.2), "gone": 0.0 })
			b.blocks = blocks
			b.pool = _pool(48, { "on": false, "x": 0.0, "y": 0.0, "vx": 0.0, "vy": 0.0, "rot": 0.0, "vr": 0.0, "r": 1.0, "c": Color.WHITE, "life": 1.0, "bounced": 0, "still": 0.0, "pts": PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]) })
			b.dust = _pool(36, { "on": false, "x": 0.0, "y": 0.0, "vx": 0.0, "vy": 0.0, "life": 0.0, "r": 1.0 })
			b.marks = []
			b.pi = 0
			b.du = 0
			b.timer = 1.0
			b.broken = 0
			b.lastN = 0
		"kaboom":
			# a CHAIN REACTION is a queue. a blast at (x, y) with radius R asks every
			# barrel "are you inside?" and the ones that are get an entry — barrel,
			# time = now + delay — in a list sorted by time. dominoes join the same
			# list by CONTACT instead of a radius test: each is a rod pivoting on its
			# base corner, θ'' = (3g/2L)·sin θ — slow to start, fast to arrive — and the
			# moment its top reaches the next one's face the next is queued (now + tip)
			# with a share of its angular speed: the shove (lexicon Knock and Newton).
			# it lands on its neighbour at 1.25 rad, bounces a little, and rests. the
			# queue is drawn at the top, so you can read the doom before it lands.
			b.bw = u * 3.0
			b.bh = u * 4.5
			b.R = W * D.radius
			var seed := Kit.rng(3)
			var NB := maxi(1, roundi(D.barrels))
			var ND := maxi(1, roundi(D.dominoes))
			b.NB = NB
			b.ND = ND
			var barrels: Array = []
			for i in NB:
				barrels.append({ "x": W * (0.05 + 0.58 * (i + 0.5) / NB) + (seed.randf() - 0.5) * W * 0.03, "alive": true, "fuse": -1.0 })
			b.barrels = barrels
			var dx0 := W * 0.7
			var dw := (W * 0.95 - dx0) / ND
			b.dw = dw
			b.dh = u * 5.0
			var dominoes: Array = []
			for i in ND:
				dominoes.append({ "x": dx0 + i * dw, "th": 0.0, "w": 0.0, "w0": 0.0, "going": false, "touched": false, "rested": false })   # th, w: the pivot's angle and angular speed · w0: the shove it was handed
			b.dominoes = dominoes
			b.fallA = 3.0 * (H * float(D.g)) / (2.0 * float(b.dh))   # θ'' = fallA·sin θ: a uniform rod about its end (I = mL²/3, torque = mg·L/2·sin θ)
			b.thC = asin(clampf((dw - u * 0.5) / float(b.dh), 0.05, 1.0))   # the angle at which a domino's top reaches the next one's face
			b.queue = []
			b.blasts = []
			b.smoke = _pool(40, { "on": false, "x": 0.0, "y": 0.0, "vy": 0.0, "life": 0.0, "r": 1.0 })
			b.si = 0
			b.timer = 1.5
			b.quiet = 0.0
			b.fadeIn = 1.0
		"wick":
			# a FUSE is a timer drawn as a distance: the spark moves along the rope at
			# a constant rate, so the rope left over IS the time left. the rope is one
			# cubic Bézier (lexicon Path), but a Bézier's parameter u is not distance —
			# the curve bunches near its controls — so the curve is sampled into 48
			# straight pieces and the spark walks the ARC-LENGTH table instead. the
			# spark is chapter 06's sparks with a smoke trail; the pop at the end is
			# small and local. a candle is the same clock stood upright.
			var N := 48
			b.candle = D.kind == "candle"
			var P: Array = D.path
			var p0: Array = P[0]
			var p1: Array = P[1]
			var p2: Array = P[2]
			var p3: Array = P[3]
			var pts: Array = []
			var cum: Array = [0.0]
			for i in N + 1:                              # sample the curve, then the running length
				var k := i / float(N)
				var a := (1.0 - k) * (1.0 - k) * (1.0 - k)
				var bb := 3.0 * (1.0 - k) * (1.0 - k) * k
				var c := 3.0 * (1.0 - k) * k * k
				var d := k * k * k
				pts.append(Vector2(W * (a * float(p0[0]) + bb * float(p1[0]) + c * float(p2[0]) + d * float(p3[0])),
					H * (a * float(p0[1]) + bb * float(p1[1]) + c * float(p2[1]) + d * float(p3[1]))))
				if i > 0:
					cum.append(float(cum[i - 1]) + (pts[i] as Vector2).distance_to(pts[i - 1]))
			b.pts = pts
			b.cum = cum
			b.L = maxf(1.0, cum[N])
			b.endp = pts[N]
			b.sparks = _pool(40, { "on": false, "x": 0.0, "y": 0.0, "vx": 0.0, "vy": 0.0, "life": 0.0 })
			b.puffs = _pool(40, { "on": false, "x": 0.0, "y": 0.0, "vy": 0.0, "life": 0.0, "r": 1.0 })
			b.wdrips = _pool(14, { "on": false, "x": 0.0, "y": 0.0, "stop": 0.0, "r": 1.0 })
			b.si = 0
			b.pu = 0
			b.dr = 0
			b.lit = false
			b.popped = false
			b.hurried = false
			b.pos = 0.0
			b.idleT = 0.4
			b.popT = 0.0
			b.sinceReset = 9.0
			b.pops = 0
			b.sparkAcc = 0.0
			b.smokeAcc = 0.0
			b.dripAcc = 0.0
		"grenade":
			# the grenade's clock starts when the PIN comes out and nothing after that
			# stops it — so COOKING (holding a live one) trades your safety for a
			# blast that lands with less time for anyone to run. while it is held, the
			# ARC PREVIEW runs the very same integrator the throw will use (lexicon
			# Jump's parabola, Bounce's restitution) two seconds ahead and marks the
			# point on that arc where the fuse would run out. hold past the fuse and
			# it goes off in your hand; the meter by the hero is the only warning.
			b.G = H * D.g
			b.R = u * 1.2
			b.hx = W * 0.16
			b.cx = W * 0.62
			b.cs = u * 6.0
			b.gas = D.kind == "gas"
			b.phase = "idle"
			b.fuseLeft = 0.0
			b.since = 0.0
			b.held = 0.0
			b.cookFor = 1.0
			b.manual = false
			b.timer = D.every * 0.6
			b.ax = 0.0
			b.ay = 0.0
			b.rot = 0.0
			b.vr = 0.0
			b.fxT = 9.0
			b.fxX = 0.0
			b.fxY = 0.0
			b.hurtT = 0.0
			b.throws = 0
			b.cooked = 0
			b.lastCook = 0.0
			b.body = { "x": 0.0, "y": 0.0, "vx": 0.0, "vy": 0.0, "b": 0 }
			b.sparks = _pool(24, { "on": false, "x": 0.0, "y": 0.0, "vx": 0.0, "vy": 0.0, "life": 0.0 })
			b.puffs = _pool(40, { "on": false, "x": 0.0, "y": 0.0, "vx": 0.0, "vy": 0.0, "age": 0.0, "r": 1.0 })
			b.si = 0
			b.pu = 0
		"aoe":
			# an AoE TELEGRAPH draws the hit before it lands: the shape's outline is
			# the promise, the FILL is the clock — it grows from the centre (or from
			# the caster) as age/windup, and the hit comes exactly at full. the hero
			# reads it too: after a REACTION TIME it steps out along the shortest way
			# (away from a circle's centre, across a cone's or a line's aim), so a
			# long windup is a dodge and a short one is a hit — the same shape, and
			# the fairness lives entirely in the number. the ground is a plane seen
			# at a squash of 0.35, so circles are the ellipses a floor would show.
			var ZM := (H - GY) / 0.35 * 0.92
			b.SQ = 0.35
			b.ZM = ZM
			b.ex = W * 0.82
			b.ez = ZM * 0.5
			b.hx = W * 0.4
			b.hz = ZM * 0.5
			b.face = 1
			b.hurtT = 0.0
			b.moving = false
			b.mdir = Vector2.ZERO
			b.castT = D.gap * 0.5
			b.next = 0
			b.hits = 0
			b.dodged = 0
			b.casts = 0
			b.active = false
			b.newest = -1
			b.tgs = _pool(8, { "on": false, "kind": "circle", "x": 0.0, "z": 0.0, "ax": 1.0, "az": 0.0, "age": 0.0, "res": "" })
			b.ti = 0
		"tell":
			# a TELL is the attack's promise: for D.tell seconds before the swing the
			# enemy's body goes white (chapter 03's hit-flash, worn early) and LEANS
			# BACK about its feet — two cues, so it reads in the corner of the eye.
			# the dodge is a window: a hop with dodgeLen seconds of safety. the swing
			# lands at tell + strike; the hero is safe if that instant falls inside its
			# window — start too late and you are hit, too early and the window has
			# closed again (lexicon Cat's i-frames). the hero here has a REACTION
			# TIME, so with a short tell it is often late, and with a long one it can
			# wait and time the hop; the bar at the top shows where each dodge fell.
			# the lean and the arm are not tweened: the phase machine only moves their
			# TARGETS, and each chases its target on an under-damped spring — so the
			# body swings past upright as it recovers (the follow-through), and the
			# arm's softer, slower spring lags the body's and whips through after it.
			b.hx = W * 0.36
			b.ex = W * 0.62
			b.phase = "idle"
			b.pt = D.every * 0.4
			b.clock = 0.0
			b.tellStart = -99.0
			b.plan = 0.0
			b.planned = false
			b.dodgeT = 0.0
			b.dodgeStart = -99.0
			b.hurtT = 0.0
			b.shake = 0.0
			b.sx = 0.0
			b.hits = 0
			b.dodged = 0
			b.lastRes = ""
			b.lastAt = 0.0
			b.lastWhy = ""
			b.lastManual = false
			b.leanA = 0.0                                # the two springs: the body's lean and the arm's angle, radians, with their velocities
			b.leanV = 0.0
			b.armA = 0.3
			b.armV = 0.0

# ---------------------------------------------------------------- events

## Muzzle's fire(): the EVENT that spawns the flash, the light, the recoil
## and the smoke at once.
static func _muzzle_fire(b: Dictionary) -> void:
	var D: Dictionary = b.D
	var W: float = b.w
	var H: float = b.h
	var GY: float = b.gy
	var u: float = b.u
	b.shotT = 0.0
	b.rot = randf_range(0.0, TAU)
	_recoil_kick(b, b.L * D.recoil)
	var m := _tip(Vector2(b.hx + 4.0 * u, GY - 9.0 * u), b.aim, b.kick, b.L)
	var pool: Array = b.pool
	for _i in int(D.smoke):
		var p: Dictionary = pool[b.pi]
		b.pi = (b.pi + 1) % pool.size()
		var a: float = b.aim + randf_range(-0.5, 0.5)
		var v := randf_range(0.04, 0.22) * W
		p.on = true
		p.x = m.x
		p.y = m.y
		p.vx = cos(a) * v
		p.vy = sin(a) * v - H * 0.04
		p.life = 1.0
		p.r = randf_range(0.6, 1.4) * u
	if b.armed_sound:
		Kit.noise_burst({ "dur": 0.12, "vol": 0.14, "lowpass": 2200.0, "sweep_to": 300.0 })

## Eject's fire(): one casing out of the pool, a kick, a flash.
static func _eject_fire(b: Dictionary) -> void:
	var D: Dictionary = b.D
	var W: float = b.w
	var H: float = b.h
	var GY: float = b.gy
	var u: float = b.u
	var pool: Array = b.pool
	var idx: int = b.pi
	var p: Dictionary = pool[idx]
	b.pi = (idx + 1) % pool.size()
	p.on = true
	p.x = b.hx + 5.0 * u
	p.y = GY - 10.0 * u
	p.vx = -W * D.eject * randf_range(0.6, 1.1)
	p.vy = -H * randf_range(0.6, 0.95)
	p.rot = 0.0
	p.vr = randf_range(-D.spin, D.spin)
	p.bounces = 0
	p.restT = 0.0
	p.age = 0.0
	_recoil_kick(b, b.L * 0.3)
	b.flash = 0.04
	b.fired += 1
	b.last = idx

## Tracer's fire(): one ray against every segment, the nearest hit wins.
static func _tracer_fire(b: Dictionary) -> void:
	var D: Dictionary = b.D
	var W: float = b.w
	var GY: float = b.gy
	var u: float = b.u
	var m := _tip(Vector2(b.hx + 4.0 * u, GY - 9.0 * u), b.aim, b.kick, b.L)
	var a: float = b.aim + randf_range(-D.spread, D.spread)
	var d := Vector2(cos(a), sin(a))
	var segs: Array = b.segs
	var best := -1.0
	var bi := -1
	var cand: Array = []
	for i in segs.size():
		var tt := _seg_hit(m, d, segs[i])
		if tt >= 0.0:
			cand.append(m + d * tt)
			if best < 0.0 or tt < best:
				best = tt
				bi = i
	b.cand = cand
	if best < 0.0:
		best = W
	var g: Array = segs[0 if bi < 0 else bi]
	var nv := Vector2(float(g[3]) - float(g[1]), -(float(g[2]) - float(g[0])))
	nv = nv / (nv.length() if nv.length() > 0.0 else 1.0)
	if nv.dot(d) > 0.0:
		nv = -nv
	b.shots += 1
	var glowing: bool = int(D.glowEvery) > 0 and b.shots % int(D.glowEvery) == 0
	var tracers: Array = b.tracers
	# left = frames + 1: the tick that follows takes one before the first draw
	tracers.append({ "p1": m, "p2": m + d * best, "left": int(D.frames) + 1, "age": 0.0, "glow": glowing, "nx": nv.x, "ny": nv.y })
	if tracers.size() > 8:
		tracers.pop_front()
	var sparks: Array = b.sparks
	for _i in 6:
		var p: Dictionary = sparks[b.si]
		b.si = (b.si + 1) % sparks.size()
		var v := randf_range(0.1, 0.3) * W
		var ang := atan2(nv.y, nv.x) + randf_range(-0.9, 0.9)
		p.on = true
		p.x = m.x + d.x * best
		p.y = m.y + d.y * best
		p.vx = cos(ang) * v
		p.vy = sin(ang) * v
		p.life = 1.0
	_recoil_kick(b, b.L * 0.25)
	b.candT = 0.0

## Impact's spawn(): the table's effect as particles off the normal.
static func _impact_spawn(b: Dictionary, kind: String, x: float, y: float, nx: float, ny: float, matc: Color) -> void:
	var D: Dictionary = b.D
	var W: float = b.w
	var u: float = b.u
	var na := atan2(ny, nx)
	var cnt: int = int(D.count) if kind == "sparks" else (roundi(D.count * 0.7) if kind == "dust" else roundi(D.count * 0.5))
	var pool: Array = b.pool
	for _i in cnt:
		var p: Dictionary = pool[b.pi]
		b.pi = (b.pi + 1) % pool.size()
		p.on = true
		p.kind = kind
		p.x = x
		p.y = y
		p.life = 1.0
		p.rot = randf_range(0.0, TAU)
		p.vr = 0.0
		if kind == "sparks":
			var a := na + randf_range(-1.1, 1.1)
			var v := randf_range(0.25, 0.6) * W
			p.vx = cos(a) * v
			p.vy = sin(a) * v
			p.c = Kit.SPARK
			p.r = 1.0
		elif kind == "dust":
			var a := na + randf_range(-1.4, 1.4)
			var v := randf_range(0.03, 0.09) * W
			p.vx = cos(a) * v
			p.vy = sin(a) * v
			p.c = Kit.shade(matc, 0.35)
			p.r = randf_range(0.8, 1.6) * u
		else:
			var a := na + randf_range(-0.9, 0.9)
			var v := randf_range(0.12, 0.35) * W
			p.vx = cos(a) * v
			p.vy = sin(a) * v
			p.vr = randf_range(-14.0, 14.0)
			p.c = Kit.shade(matc, randf_range(-0.3, 0.3))
			p.r = randf_range(0.5, 1.1) * u

## Impact's shoot(): which panel is under px, its material, its normal.
static func _impact_shoot(b: Dictionary, px: float) -> void:
	var D: Dictionary = b.D
	var W: float = b.w
	var u: float = b.u
	var x0: float = b.x0
	var pw: float = b.pw
	px = clampf(px, x0 + 2.0, W - 2.0)
	var idx := mini(3, int(floorf((px - x0) / pw)))
	var P: Dictionary = b.panels[idx]
	var mats: Array = D.materials
	var mat: Dictionary = mats[idx] if idx < mats.size() else mats[0]
	var k: float = (px - P.a) / (P.b - P.a)
	var hy: float = P.ya + (P.yb - P.ya) * k
	var base := Vector2(b.hx + 4.0 * u, b.ly - 9.0 * u)
	b.aim = atan2(hy - base.y, px - base.x)
	_recoil_kick(b, b.L * 0.25)
	b.tr0 = _tip(base, b.aim, b.kick, b.L)
	b.tr1 = Vector2(px, hy)
	b.trace = 3
	b.lastHit = { "x": px, "y": hy, "nx": P.nx, "ny": P.ny, "fx": mat.fx }
	b.hitT = 0.0
	b.lastRow = idx
	var mc := Color(mat.c)
	if mat.fx == "ring":
		var rings: Array = b.rings
		rings.append({ "x": px, "y": hy, "age": 0.0, "c": mc })
		if rings.size() > 6:
			rings.pop_front()
		_impact_spawn(b, "dust", px, hy, P.nx, P.ny, mc)
	else:
		_impact_spawn(b, mat.fx, px, hy, P.nx, P.ny, mc)

## Decals' stamp(): slot = head mod N, head++, the shape drawn from a
## seeded rng ONCE and kept (the web draws it from the seed on rebuild).
static func _decal_stamp(b: Dictionary, x: float, y: float) -> void:
	var D: Dictionary = b.D
	var GY: float = b.gy
	var u: float = b.u
	var N: int = b.N
	var slots: Array = b.slots
	var sl: Dictionary = slots[b.head % N]
	b.stamped += 1
	b.head += 1
	var stamped: int = b.stamped
	sl.on = true
	sl.x = x
	sl.y = y
	sl.seq = stamped
	sl.seed = stamped * 31 + 7
	sl.a = 0.0
	if D.kind == "chalk":
		sl.kind = "circle" if stamped % 2 == 1 else "cross"
	else:
		sl.kind = "scorch" if stamped % int(D.scorchEvery) == 0 else "hole"
	var R := Kit.rng(sl.seed)
	var r: float = u * 0.9 * D.size
	var shape: Array = []
	if sl.kind == "hole":
		for _i in 3:
			var a := R.randf() * TAU
			var l := r * (1.5 + R.randf() * 2.0)
			shape.append(Vector2(cos(a) * r, sin(a) * r))
			shape.append(Vector2(cos(a) * l, sin(a) * l))
	elif sl.kind == "circle":
		for i in 15:
			var a := i / 14.0 * TAU * 1.08
			var rr := r * 2.2 * (0.85 + R.randf() * 0.3)
			shape.append(Vector2(cos(a) * rr, sin(a) * rr))
	elif sl.kind == "cross":
		var k := r * 2.0
		shape.append(Vector2(-k + R.randf() * 2.0, -k))
		shape.append(Vector2(k, k + R.randf() * 2.0))
		shape.append(Vector2(k, -k + R.randf() * 2.0))
		shape.append(Vector2(-k + R.randf() * 2.0, k))
	sl.shape = shape
	var base := Vector2(b.hx + 4.0 * u, GY - 9.0 * u)
	b.aim = atan2(y - base.y, x - base.x)
	_recoil_kick(b, b.L * 0.25)
	b.tr0 = _tip(base, b.aim, b.kick, b.L)
	b.tr1 = Vector2(x, y)
	b.trace = 3

## Ink's splat(): circles clustered past the hit, then drips from the
## lowest one — a new record in the splat ring buffer.
static func _ink_splat(b: Dictionary, x: float, y: float) -> void:
	var D: Dictionary = b.D
	var W: float = b.w
	var H: float = b.h
	var GY: float = b.gy
	var u: float = b.u
	x = clampf(x, u * 2.0, W - u * 2.0)
	y = clampf(y, b.wy + u, GY - u)
	var base := Vector2(b.hx + 4.0 * u, GY - 9.0 * u)
	b.aim = atan2(y - base.y, x - base.x)
	_recoil_kick(b, b.L * 0.25)
	var d := Vector2(x, y) - base
	d = d / (d.length() if d.length() > 0.0 else 1.0)
	var nv := -d                                         # the wall's normal faces the shooter
	var cx: float = x - nv.x * W * D.push
	var cy: float = y - nv.y * W * D.push
	var r: float = u * 1.6 * D.size
	var circles: Array = [Vector3(x, y, r * 0.8)]
	var lowX := cx
	var lowY := cy
	for _i in int(D.blobs):                              # circles clustered past the hit, stretched along the shot
		var k := randf_range(-0.4, 1.2)
		var off := randf_range(-1.0, 1.0) * r * 0.9
		var bx := cx + d.x * k * r * 1.6 - d.y * off
		var by := cy + d.y * k * r * 1.6 + d.x * off
		var br := r * randf_range(0.3, 1.0) * (1.0 - absf(k) * 0.35)
		circles.append(Vector3(bx, by, maxf(0.5, br)))
		if by + br > lowY:
			lowY = by + br
			lowX = bx
	var stamps: Array = b.stamps
	stamps.append({ "circles": circles, "age": 0.0 })
	if stamps.size() > 24:
		stamps.pop_front()
	var drips: Array = b.drips
	for i in int(D.drips):
		var dr: Dictionary = drips[b.di]
		b.di = (b.di + 1) % drips.size()
		dr.on = true
		dr.alive = true
		dr.x = lowX if i == 0 else cx + randf_range(-1.0, 1.0) * r * 1.4
		dr.y0 = lowY - r * 0.3
		dr.y = dr.y0
		dr.w0 = r * randf_range(0.35, 0.6)
		dr.w = dr.w0
		dr.rate = H * D.drip * randf_range(0.06, 0.14)
		dr.remain = H * randf_range(0.05, 0.16) * D.drip
		dr.age = 0.0
	b.last = { "x": x, "y": y, "nx": nv.x, "ny": nv.y, "cx": cx, "cy": cy }
	b.hitT = 0.0
	b.splats += 1

## Rubble's shatter(): 4–8 chunks cut from the block, and a little dust.
static func _rubble_shatter(b: Dictionary, x: float, y: float) -> void:
	var D: Dictionary = b.D
	var W: float = b.w
	var H: float = b.h
	var u: float = b.u
	var B: float = b.B
	var pieces: Array = D.pieces
	var cnt := roundi(randf_range(float(pieces[0]), float(pieces[1])))
	b.lastN = cnt
	b.broken += 1
	var col := Color(D.colour)
	var pool: Array = b.pool
	for _i in cnt:
		var p: Dictionary = pool[b.pi]
		b.pi = (b.pi + 1) % pool.size()
		p.on = true
		p.x = x + randf_range(-B * 0.4, B * 0.4)
		p.y = y - randf_range(B * 0.1, B * 0.9)
		p.vx = randf_range(-0.25, 0.25) * W
		p.vy = -randf_range(0.3, 0.9) * H
		p.rot = randf_range(0.0, TAU)
		p.vr = randf_range(-D.spin, D.spin)
		p.r = B * randf_range(0.16, 0.32)
		p.c = Kit.shade(col, randf_range(-0.3, 0.25))
		p.life = 1.0
		p.bounced = 0
		p.still = 0.0
		var pts: PackedVector2Array = p.pts
		for k in 4:
			var a := k / 4.0 * TAU + randf_range(-0.4, 0.4)
			var rr: float = p.r * randf_range(0.6, 1.1)
			pts[k] = Vector2(cos(a) * rr, sin(a) * rr)
		p.pts = pts
	var dust: Array = b.dust
	for _i in roundi(6.0 * D.size):
		var d: Dictionary = dust[b.du]
		b.du = (b.du + 1) % dust.size()
		d.on = true
		d.x = x + randf_range(-B * 0.5, B * 0.5)
		d.y = y - randf_range(0.0, B * 0.6)
		d.vx = randf_range(-0.06, 0.06) * W
		d.vy = -randf_range(0.02, 0.08) * H
		d.life = 1.0
		d.r = u * randf_range(0.8, 1.6)

## Kaboom's enqueue(): one entry per (kind, i), the list kept sorted by time.
static func _kaboom_enqueue(b: Dictionary, kind: String, i: int, wait: float) -> void:
	var queue: Array = b.queue
	for qv in queue:
		var q: Dictionary = qv
		if q.kind == kind and q.i == i:
			return
	queue.append({ "kind": kind, "i": i, "left": wait })
	queue.sort_custom(func(qa: Dictionary, qb: Dictionary) -> bool: return qa.left < qb.left)

## Kaboom's blast(): a fireball, smoke, and the RADIUS TEST over the field.
static func _kaboom_blast(b: Dictionary, x: float, y: float) -> void:
	var D: Dictionary = b.D
	var H: float = b.h
	var GY: float = b.gy
	var u: float = b.u
	var bw: float = b.bw
	var bh: float = b.bh
	var R: float = b.R
	var blasts: Array = b.blasts
	blasts.append({ "x": x, "y": y, "age": 0.0 })
	var smoke: Array = b.smoke
	for _i in 6:
		var p: Dictionary = smoke[b.si]
		b.si = (b.si + 1) % smoke.size()
		p.on = true
		p.x = x + randf_range(-bw, bw)
		p.y = y - randf_range(0.0, bh)
		p.vy = -randf_range(0.03, 0.09) * H
		p.life = 1.0
		p.r = u * randf_range(1.0, 2.0)
	var barrels: Array = b.barrels
	for i in barrels.size():
		var br: Dictionary = barrels[i]
		if br.alive and Vector2(br.x - x, GY - bh / 2.0 - y).length() < R:   # the radius test
			_kaboom_enqueue(b, "barrel", i, D.delay)
	var d0: Dictionary = b.dominoes[0]
	if not d0.going and Vector2(d0.x - x, GY - b.dh / 2.0 - y).length() < R:
		d0.w0 = float(D.shove)                       # the blast shoves the first domino
		_kaboom_enqueue(b, "domino", 0, D.delay)
	b.quiet = 0.0

## Kaboom's light(): a hand-lit barrel takes D.fuse seconds.
static func _kaboom_light(b: Dictionary, i: int) -> void:
	var D: Dictionary = b.D
	var br: Dictionary = b.barrels[i]
	if br.alive and br.fuse < 0.0:
		_kaboom_enqueue(b, "barrel", i, D.fuse)
		br.fuse = D.fuse
		b.quiet = 0.0

## Wick's puff(): one smoke puff from the pool.
static func _wick_puff(b: Dictionary, x: float, y: float, big: bool) -> void:
	var H: float = b.h
	var u: float = b.u
	var puffs: Array = b.puffs
	var p: Dictionary = puffs[b.pu]
	b.pu = (b.pu + 1) % puffs.size()
	p.on = true
	p.x = x + randf_range(-1.0, 1.0) * u * (2.0 if big else 0.5)
	p.y = y
	p.vy = -randf_range(0.03, 0.08) * H
	p.life = 1.0
	p.r = u * (randf_range(1.5, 2.5) if big else randf_range(0.5, 0.9))

## Wick's pop(): the end of the rope — a puff of smoke, and sparks unless
## it is a candle guttering out.
static func _wick_pop(b: Dictionary) -> void:
	var W: float = b.w
	var endp: Vector2 = b.endp
	var candle: bool = b.candle
	b.lit = false
	b.popped = true
	b.popT = 0.0
	b.pops += 1
	for _i in (4 if candle else 14):
		_wick_puff(b, endp.x, endp.y, true)
	if not candle:
		var sparks: Array = b.sparks
		for _i in 24:
			var p: Dictionary = sparks[b.si]
			b.si = (b.si + 1) % sparks.size()
			var a := randf_range(0.0, TAU)
			var v := randf_range(0.2, 0.6) * W
			p.on = true
			p.x = endp.x
			p.y = endp.y
			p.vx = cos(a) * v
			p.vy = sin(a) * v
			p.life = 1.0

## Grenade's aimAt(): the throw velocity from the hand toward (x, y).
static func _gren_aim(b: Dictionary, x: float, y: float) -> void:
	var D: Dictionary = b.D
	var W: float = b.w
	var H: float = b.h
	var GY: float = b.gy
	var u: float = b.u
	var hand := Vector2(b.hx + 5.0 * u, GY - 11.0 * u)
	var d := Vector2(x, y) - hand
	var dl := d.length() if d.length() > 0.0 else 1.0
	var k := clampf(dl / (W * 0.45), 0.15, 1.0)
	b.ax = d.x / dl * k * H * D.throwV
	b.ay = d.y / dl * k * H * D.throwV

## Grenade's detonate(): the flash and shrapnel, or the gas cloud.
static func _gren_detonate(b: Dictionary, x: float, y: float, in_hand: bool) -> void:
	var W: float = b.w
	var H: float = b.h
	var u: float = b.u
	b.phase = "done"
	b.fxT = 0.0
	b.fxX = x
	b.fxY = y
	if in_hand:
		b.cooked += 1
		b.hurtT = 0.8
	if b.gas:
		var puffs: Array = b.puffs
		for _i in 24:
			var p: Dictionary = puffs[b.pu]
			b.pu = (b.pu + 1) % puffs.size()
			var a := randf_range(0.0, TAU)
			var v := randf_range(0.02, 0.12) * W
			p.on = true
			p.x = x
			p.y = y
			p.vx = cos(a) * v
			p.vy = sin(a) * v * 0.5 - H * 0.02
			p.age = 0.0
			p.r = u * randf_range(1.5, 3.0)
	else:
		var sparks: Array = b.sparks
		for _i in 20:
			var p: Dictionary = sparks[b.si]
			b.si = (b.si + 1) % sparks.size()
			var a := randf_range(0.0, TAU)
			var v := randf_range(0.25, 0.7) * W
			p.on = true
			p.x = x
			p.y = y
			p.vx = cos(a) * v
			p.vy = sin(a) * v
			p.life = 1.0

## Aoe's cast(): one telegraph from the pool, aimed at (tx, tz) on the floor.
static func _aoe_cast(b: Dictionary, kind: String, tx: float, tz: float, delay: float) -> void:
	var tgs: Array = b.tgs
	var g: Dictionary = tgs[b.ti]
	b.ti = (b.ti + 1) % tgs.size()
	g.on = true
	g.kind = kind
	g.age = -delay
	g.res = ""
	b.casts += 1
	if kind == "circle":
		g.x = tx
		g.z = tz
		g.ax = 1.0
		g.az = 0.0
	else:
		var ex: float = b.ex
		var ez: float = b.ez
		g.x = ex
		g.z = ez
		var d := Vector2(tx - ex, tz - ez)
		var dl := d.length() if d.length() > 0.0 else 1.0
		g.ax = d.x / dl
		g.az = d.y / dl

## Aoe's volley(): count telegraphs, staggered, the shape cycling.
static func _aoe_volley(b: Dictionary, tx: float, tz: float) -> void:
	var D: Dictionary = b.D
	var W: float = b.w
	var u: float = b.u
	var ZM: float = b.ZM
	var cnt := maxi(1, roundi(D.count))
	var KINDS := ["circle", "cone", "line"]
	for i in cnt:
		var k: String = KINDS[b.next % 3] if D.shape == "cycle" else str(D.shape)
		b.next += 1
		if not KINDS.has(k):
			k = "circle"
		_aoe_cast(b, k, clampf(tx + (randf_range(-1.0, 1.0) * W * 0.12 if i > 0 else 0.0), u * 2.0, W - u * 2.0),
			clampf(tz + (randf_range(-1.0, 1.0) * ZM * 0.3 if i > 0 else 0.0), 0.0, ZM), i * 0.15)

## Tell's startDodge(): a hop with dodgeLen seconds of safety.
static func _tell_dodge(b: Dictionary, manual: bool) -> void:
	var D: Dictionary = b.D
	if b.dodgeT > 0.0:
		return
	b.dodgeT = D.dodgeLen
	b.dodgeStart = b.clock
	b.lastManual = manual
	if manual:
		b.planned = false

# ================================================================ press

static func press(b: Dictionary, pos: Vector2) -> void:
	var D: Dictionary = b.D
	var W: float = b.w
	var H: float = b.h
	var GY: float = b.gy
	var u: float = b.u
	match b.id:
		"muzzle":
			var base := Vector2(b.hx + 4.0 * u, GY - 9.0 * u)
			b.aim = atan2(pos.y - base.y, pos.x - base.x)
			b.tx = pos.x
			b.ty = pos.y
			b.armed_sound = true                         # sound only after a press
			_muzzle_fire(b)
			b.timer = 0.0
		"eject":
			b.armed_sound = true
			_eject_fire(b)
			b.timer = 0.0
		"tracer":
			var base := Vector2(b.hx + 4.0 * u, GY - 9.0 * u)
			b.aim = atan2(pos.y - base.y, pos.x - base.x)
			b.tx = pos.x
			b.ty = pos.y
			_tracer_fire(b)
			b.timer = 0.0
		"impact":
			_impact_shoot(b, pos.x)
			b.timer = 0.0
		"decals":
			_decal_stamp(b, clampf(pos.x, b.wx, W - 2.0), clampf(pos.y, b.wy, H - 2.0))
			b.timer = 0.0
		"marks":
			b.tx = clampf(pos.x, u * 3.0, W - u * 3.0)
		"ink":
			_ink_splat(b, pos.x, pos.y)
			b.timer = 0.0
		"rubble":
			var best := -1
			var bd := INF
			var blocks: Array = b.blocks
			for i in blocks.size():
				var bl: Dictionary = blocks[i]
				var d: float = absf(bl.x - pos.x)
				if bl.gone <= 0.0 and d < bd:
					bd = d
					best = i
			if best >= 0:
				var bl: Dictionary = blocks[best]
				bl.gone = D.respawn
				_rubble_shatter(b, bl.x, GY)
			else:
				_rubble_shatter(b, clampf(pos.x, b.B, W - b.B), GY)
			b.timer = 0.0
		"kaboom":
			var best := -1
			var bd := INF
			var barrels: Array = b.barrels
			for i in barrels.size():
				var br: Dictionary = barrels[i]
				var d: float = absf(br.x - pos.x)
				if br.alive and d < bd:
					bd = d
					best = i
			if best >= 0:
				_kaboom_light(b, best)
			b.timer = 0.0
		"wick":
			if b.popped:
				b.popT = D.pause
			elif not b.lit:
				b.lit = true
				b.popped = false
				b.pos = 0.0
				b.hurried = false
			else:
				b.hurried = true
		"grenade":
			if b.phase == "idle" or b.phase == "done":   # pull the pin
				b.phase = "held"
				b.fuseLeft = D.fuse
				b.since = 0.0
				b.held = 0.0
				b.manual = true
			if b.phase == "held":
				_gren_aim(b, pos.x, pos.y)
				b.since = 0.0
				b.manual = true
		"aoe":
			_aoe_volley(b, clampf(pos.x, u * 2.0, W - u * 2.0), clampf((pos.y - GY) / b.SQ, 0.0, b.ZM))
			b.castT = 0.0
		"tell":
			_tell_dodge(b, true)

# ================================================================ tick

static func tick(b: Dictionary, dt: float, _t: float) -> void:
	var D: Dictionary = b.D
	var W: float = b.w
	var H: float = b.h
	var GY: float = b.gy
	var u: float = b.u
	match b.id:
		"muzzle":
			b.timer += dt
			b.shotT += dt
			if b.timer > D.every:                        # autopilot: a new target, a shot
				b.timer = 0.0
				b.tx = randf_range(W * 0.55, W * 0.95)
				b.ty = randf_range(H * 0.2, GY)
				var base := Vector2(b.hx + 4.0 * u, GY - 9.0 * u)
				b.aim = atan2(b.ty - base.y, b.tx - base.x)
				_muzzle_fire(b)
			_recoil_step(b, dt)
			for pv in b.pool:                            # the SMOKE: the longest-lived part of the shot
				var p: Dictionary = pv
				if not p.on:
					continue
				p.life -= dt / D.smokeLife
				if p.life <= 0.0:
					p.on = false
					continue
				p.x += p.vx * dt
				p.y += p.vy * dt
				p.vx *= maxf(0.0, 1.0 - 2.0 * dt)
				p.vy -= H * 0.03 * dt
				p.r += u * 1.2 * dt
		"eject":
			b.timer += dt
			b.tinkGap += dt
			if b.timer > D.every:
				b.timer = 0.0
				_eject_fire(b)
			_recoil_step(b, dt)
			b.flash -= dt
			var G: float = b.G
			var pool: Array = b.pool
			for pv in pool:
				var p: Dictionary = pv
				if not p.on:
					continue
				p.age += dt
				if p.restT > 0.0:                        # at rest: wait, then fade
					p.restT += dt
					if p.restT > D.settle + 0.6:
						p.on = false
					continue
				p.vy += G * dt
				p.x += p.vx * dt
				p.y += p.vy * dt
				p.rot += p.vr * dt
				if p.y >= GY:
					p.y = GY
					if p.vy > H * 0.12:                  # a real bounce: flip, scale by e, eat some μ
						p.vy = -p.vy * D.rest
						p.vx *= D.friction
						p.vr *= D.friction
						p.bounces += 1
						if p.bounces == 1 and b.armed_sound and b.tinkGap > 0.12:
							b.tinkGap = 0.0
							Kit.tone({ "freq": randf_range(2300.0, 3100.0), "slide_to": 1900.0, "type": "triangle", "dur": 0.07, "vol": 0.08, "pan": (p.x / W - 0.5) * 1.6 })
					else:
						p.vy = 0.0
						p.vx = 0.0
						p.vr = 0.0
						p.restT = 0.001
						p.rot = roundf(p.rot / PI) * PI
				if p.x < u or p.x > W - u:
					p.vx = -p.vx * D.rest
					p.x = clampf(p.x, u, W - u)
		"tracer":
			b.timer += dt
			b.candT += dt
			_recoil_step(b, dt)
			if b.timer > D.every:
				b.timer = 0.0
				b.tx = randf_range(W * 0.4, W * 0.98)
				b.ty = randf_range(H * 0.15, GY)
				var base := Vector2(b.hx + 4.0 * u, GY - 9.0 * u)
				b.aim = atan2(b.ty - base.y, b.tx - base.x)
				_tracer_fire(b)
			var tracers: Array = b.tracers
			var i := tracers.size() - 1
			while i >= 0:                                # plain ones count ticks down, glowing ones age
				var tr: Dictionary = tracers[i]
				var a: float
				if tr.glow:
					tr.age += dt
					a = 1.0 - tr.age / D.linger
				else:
					tr.left -= 1
					a = float(tr.left) / D.frames
				if a <= 0.0:
					tracers.remove_at(i)
				i -= 1
			for pv in b.sparks:
				var p: Dictionary = pv
				if not p.on:
					continue
				p.life -= dt * 4.0
				if p.life <= 0.0:
					p.on = false
					continue
				p.x += p.vx * dt
				p.y += p.vy * dt
				p.vy += H * 1.5 * dt
		"impact":
			b.timer += dt
			b.hitT += dt
			_recoil_step(b, dt)
			if b.timer > D.every:
				b.timer = 0.0
				_impact_shoot(b, randf_range(b.x0, W))
			if b.trace > 0:
				b.trace -= 1
			var rings: Array = b.rings
			var i := rings.size() - 1
			while i >= 0:                                # water: a ring that spreads on the surface plane
				var r: Dictionary = rings[i]
				r.age += dt
				if r.age / 1.1 >= 1.0:
					rings.remove_at(i)
				i -= 1
			var G: float = b.G
			for pv in b.pool:
				var p: Dictionary = pv
				if not p.on:
					continue
				var rate := 2.4 if p.kind == "sparks" else (1.1 if p.kind == "dust" else 1.3)
				p.life -= dt * rate
				if p.life <= 0.0:
					p.on = false
					continue
				if p.kind == "dust":
					p.vx *= maxf(0.0, 1.0 - 1.5 * dt)
					p.vy -= H * 0.02 * dt
					p.r += u * 0.8 * dt
				else:
					p.vy += G * dt
				p.x += p.vx * dt
				p.y += p.vy * dt
				p.rot += p.vr * dt
				if p.kind != "dust" and p.y > GY + u:
					p.y = GY + u
					p.vy = 0.0
					p.vx *= 0.5
					p.vr = 0.0
		"decals":
			b.timer += dt
			_recoil_step(b, dt)
			if b.timer > D.every:
				b.timer = 0.0
				_decal_stamp(b, randf_range(b.wx + u, W - u), randf_range(b.wy + u, GY + (H - GY) * 0.7))
			if b.trace > 0:
				b.trace -= 1
			var N: int = b.N
			var stamped: int = b.stamped
			var count := mini(stamped, N)
			var oldest := stamped - count + 1              # ranks: 0 = the oldest kept
			for sv in b.slots:
				var sl: Dictionary = sv
				if not sl.on:
					continue
				var rank: int = sl.seq - oldest
				var target := 1.0 if count < N else clampf((rank + 1) / D.fade, 0.0, 1.0)
				sl.a += (target - sl.a) * Kit.smooth(6.0, dt)
		"marks":
			var far: bool = absf(b.tx - b.hx) > u
			var dx: float = clampf(b.tx - b.hx, -1.0, 1.0) * W * D.speed * dt * (1.0 if far else 0.0)
			b.hx += dx
			b.acc += absf(dx)
			b.dist += absf(dx)
			if absf(dx) > 1e-6:
				b.face = 1 if dx > 0.0 else -1
			if absf(b.tx - b.hx) <= u and randf() < dt * 0.8:   # autopilot: a new destination
				b.tx = randf_range(u * 4.0, W - u * 4.0)
			var prints: Array = b.prints
			while b.acc >= W * D.stride:                 # the rule: one print per stride of DISTANCE
				b.acc -= W * D.stride
				b.steps += 1
				var steps: int = b.steps
				var p: Dictionary = prints[b.pi]
				b.pi = (b.pi + 1) % prints.size()
				p.on = true
				p.x = b.hx - b.face * u * 1.5
				p.y = GY + (1.0 if steps % 2 == 1 else -1.0) * u * 0.7 + u * 0.5
				p.age = 0.0
				p.side = steps % 2
			var cdx: float = W * D.carSpeed * dt
			b.carX += cdx
			b.carAcc += cdx
			if b.carX > W * 1.15:
				b.carX = -W * 0.15
			var tyres: Array = b.tyres
			while b.carAcc >= W * D.tyre:
				b.carAcc -= W * D.tyre
				for w in 2:
					var q: Dictionary = tyres[b.ti]
					b.ti = (b.ti + 1) % tyres.size()
					q.on = true
					q.x = b.carX + (-3.5 if w == 1 else 3.5) * u
					q.y = b.roadY
					q.age = 0.0
			for pv in prints:
				var p: Dictionary = pv
				if p.on:
					p.age += dt
					if 1.0 - p.age / D.life <= 0.0:
						p.on = false
			for qv in tyres:
				var q: Dictionary = qv
				if q.on:
					q.age += dt
					if 1.0 - q.age / D.life <= 0.0:
						q.on = false
		"ink":
			b.timer += dt
			b.hitT += dt
			_recoil_step(b, dt)
			if b.timer > D.every:
				b.timer = 0.0
				_ink_splat(b, randf_range(W * 0.35, W * 0.95), randf_range(b.wy + H * 0.08, GY - H * 0.08))
			var dry: float = maxf(0.1, D.dry)
			var stamps: Array = b.stamps                 # drying: the layer washes itself out
			var i := stamps.size() - 1
			while i >= 0:
				var st: Dictionary = stamps[i]
				st.age += dt
				if st.age > dry * 4.0:                   # exp(−4) ≈ 2 %: gone
					stamps.remove_at(i)
				i -= 1
			for dv in b.drips:                           # the drips grow INTO the layer, a segment a frame
				var d: Dictionary = dv
				if not d.alive:
					continue
				d.age += dt
				if d.age > dry * 4.0:
					d.alive = false
					d.on = false
					continue
				if not d.on:
					continue
				var dy: float = d.rate * dt
				d.y += dy
				d.remain -= dy
				d.w *= maxf(0.0, 1.0 - 0.6 * dt)
				d.rate *= maxf(0.0, 1.0 - 0.25 * dt)
				if d.remain <= 0.0 or d.w < 0.4 or d.y > GY - 1.0:
					d.on = false
		"rubble":
			b.timer += dt
			var blocks: Array = b.blocks
			if b.timer > D.every:
				b.timer = 0.0
				var alive: Array = []
				for bl in blocks:
					if bl.gone <= 0.0:
						alive.append(bl)
				if alive.size() > 0:
					var bl: Dictionary = alive[randi_range(0, alive.size() - 1)]
					bl.gone = D.respawn
					_rubble_shatter(b, bl.x, GY)
			for bv in blocks:
				var bl: Dictionary = bv
				if bl.gone > 0.0:
					bl.gone = maxf(0.0, bl.gone - dt)
			for dv in b.dust:
				var d: Dictionary = dv
				if not d.on:
					continue
				d.life -= dt * 0.9
				if d.life <= 0.0:
					d.on = false
					continue
				d.x += d.vx * dt
				d.y += d.vy * dt
				d.r += u * 0.9 * dt
			var G: float = b.G
			var marks: Array = b.marks
			for pv in b.pool:
				var p: Dictionary = pv
				if not p.on:
					continue
				if p.bounced < 2:
					p.vy += G * dt
					p.x += p.vx * dt
					p.y += p.vy * dt
					p.rot += p.vr * dt
					if p.y >= GY - p.r * 0.5:
						p.y = GY - p.r * 0.5
						if p.bounced == 0 and p.vy > H * 0.1:   # the ONE bounce
							p.vy = -p.vy * D.rest
							p.vx *= 0.6
							p.vr *= 0.5
							p.bounced = 1
							marks.append({ "x": p.x, "age": 0.0 })
							if marks.size() > 12:
								marks.pop_front()
						else:
							p.bounced = 2
							p.vy = 0.0
							p.vx = 0.0
							p.vr = 0.0
					if p.x < p.r or p.x > W - p.r:
						p.vx = -p.vx * D.rest
						p.x = clampf(p.x, p.r, W - p.r)
				else:
					p.still += dt
					if p.still > D.hold:
						p.life -= dt / D.fade
						if p.life <= 0.0:
							p.on = false
			var i := marks.size() - 1
			while i >= 0:
				var mk: Dictionary = marks[i]
				mk.age += dt
				if mk.age > 0.4:
					marks.remove_at(i)
				i -= 1
		"kaboom":
			b.timer += dt
			b.quiet += dt
			b.fadeIn = minf(1.0, b.fadeIn + dt * 2.0)
			var barrels: Array = b.barrels
			var dominoes: Array = b.dominoes
			var queue: Array = b.queue
			var ND: int = b.ND
			var anyAlive := false
			for br in barrels:
				if br.alive:
					anyAlive = true
			if b.timer > D.every and queue.is_empty() and anyAlive:
				b.timer = 0.0
				var alive: Array = []
				for i in barrels.size():
					if (barrels[i] as Dictionary).alive:
						alive.append(i)
				_kaboom_light(b, alive[randi_range(0, alive.size() - 1)])
			var lastD: Dictionary = dominoes[ND - 1]
			if queue.is_empty() and b.quiet > D.respawn and (not anyAlive or lastD.rested):
				for br in barrels:                       # reset: the field comes back
					br.alive = true
					br.fuse = -1.0
				for dm in dominoes:
					dm.th = 0.0
					dm.w = 0.0
					dm.w0 = 0.0
					dm.going = false
					dm.touched = false
					dm.rested = false
				queue.clear()
				b.fadeIn = 0.0
			var i := queue.size() - 1
			while i >= 0:                                # the queue: fire whatever is due
				var q: Dictionary = queue[i]
				q.left -= dt
				if q.left <= 0.0:
					queue.remove_at(i)
					if q.kind == "barrel":
						var br: Dictionary = barrels[q.i]
						if br.alive:
							br.alive = false
							br.fuse = -1.0
							_kaboom_blast(b, br.x, GY - b.bh / 2.0)
					else:
						var dm: Dictionary = dominoes[q.i]
						if not dm.going:                  # a domino goes: it starts with the shove it was handed
							dm.going = true
							dm.w = maxf(0.3, float(dm.w0))
							b.quiet = 0.0
				i -= 1
			for br in barrels:
				if br.fuse > 0.0:
					br.fuse -= dt
			var fallA: float = b.fallA
			var thC: float = b.thC
			var dsub := maxi(1, ceili(dt * 50.0))
			var hh := dt / float(dsub)
			for di in ND:                                # dominoes: rods pivoting on their base corner, integrated (symplectic euler, ≤ 20 ms steps)
				var dm: Dictionary = dominoes[di]
				if not dm.going or dm.rested:
					continue
				var th: float = dm.th
				var w: float = dm.w
				var rested := false
				for _s in dsub:
					w += fallA * sin(th) * hh
					th += w * hh
					if th >= 1.25:                       # the stop: it lands on its neighbour, bounces a little, and rests once the bounce is small
						th = 1.25
						w = -w * 0.25
						if -w < 0.6:
							w = 0.0
							rested = true
				dm.th = clampf(th, 0.0, 1.25)
				dm.w = clampf(w, -50.0, 50.0)
				if rested:
					dm.rested = true
				if not dm.touched and dm.th >= thC:      # its top reaches the next: the shove is queued
					dm.touched = true
					if di + 1 < ND:
						var nx: Dictionary = dominoes[di + 1]
						nx.w0 = dm.w * 0.6
						_kaboom_enqueue(b, "domino", di + 1, D.tip)
			for pv in b.smoke:
				var p: Dictionary = pv
				if not p.on:
					continue
				p.life -= dt * 0.6
				if p.life <= 0.0:
					p.on = false
					continue
				p.y += p.vy * dt
				p.r += u * 0.8 * dt
			var blasts: Array = b.blasts
			i = blasts.size() - 1
			while i >= 0:
				var bl: Dictionary = blasts[i]
				bl.age += dt
				if bl.age / 0.7 >= 1.0:
					blasts.remove_at(i)
				i -= 1
		"wick":
			var candle: bool = b.candle
			var L: float = b.L
			b.sinceReset += dt
			if not b.lit and not b.popped:               # autopilot: it lights itself
				b.idleT += dt
				if b.idleT > 1.0:
					b.lit = true
					b.popped = false
					b.pos = 0.0
					b.hurried = false
			var rate: float = L / maxf(0.1, D.burn) * (D.hurry if b.hurried else 1.0)
			if b.lit:
				b.pos += rate * dt
				var p := _wick_at(b, b.pos)
				if not candle:
					b.sparkAcc = minf(8.0, b.sparkAcc + dt * D.sparks)
					var sparks: Array = b.sparks
					while b.sparkAcc >= 1.0:
						b.sparkAcc -= 1.0
						var q: Dictionary = sparks[b.si]
						b.si = (b.si + 1) % sparks.size()
						var a := randf_range(0.0, TAU)
						var v := randf_range(0.05, 0.25) * W
						q.on = true
						q.x = p.x
						q.y = p.y
						q.vx = cos(a) * v
						q.vy = sin(a) * v - H * 0.1
						q.life = 1.0
				b.smokeAcc = minf(4.0, b.smokeAcc + dt * D.smoke * (0.3 if candle else 1.0))
				while b.smokeAcc >= 1.0:
					b.smokeAcc -= 1.0
					_wick_puff(b, p.x, p.y - u, false)
				if candle:
					b.dripAcc = minf(2.0, b.dripAcc + dt * 0.9)
					var wdrips: Array = b.wdrips
					while b.dripAcc >= 1.0:
						b.dripAcc -= 1.0
						var d: Dictionary = wdrips[b.dr]
						b.dr = (b.dr + 1) % wdrips.size()
						d.on = true
						d.x = p.x + (-1.0 if randf() < 0.5 else 1.0) * u * 1.6
						d.y = p.y + u
						d.stop = randf_range(d.y + u, GY - u * 0.5)
						d.r = u * 0.35
				if b.pos >= L:
					_wick_pop(b)
			if b.popped:
				b.popT += dt
				if b.popT >= D.pause:                    # reset
					b.popped = false
					b.pos = 0.0
					b.idleT = 0.0
					b.sinceReset = 0.0
					for dv in b.wdrips:
						dv.on = false
			for dv in b.wdrips:                          # wax creeps down the candle's sides
				var d: Dictionary = dv
				if d.on and d.y < d.stop:
					d.y = minf(d.stop, d.y + H * 0.03 * dt)
					d.r = minf(u * 0.7, d.r + u * 0.15 * dt)
			for pv in b.puffs:
				var p: Dictionary = pv
				if not p.on:
					continue
				p.life -= dt * 0.7
				if p.life <= 0.0:
					p.on = false
					continue
				p.y += p.vy * dt
				p.r += u * 0.7 * dt
			for qv in b.sparks:
				var q: Dictionary = qv
				if not q.on:
					continue
				q.life -= dt * 3.0
				if q.life <= 0.0:
					q.on = false
					continue
				q.x += q.vx * dt
				q.y += q.vy * dt
				q.vy += H * 1.6 * dt
		"grenade":
			b.timer += dt
			b.hurtT -= dt
			b.fxT += dt
			var gas: bool = b.gas
			if b.phase == "idle" and b.timer > D.every:  # autopilot: pull, cook a while, throw
				b.timer = 0.0
				b.manual = false
				b.phase = "held"
				b.fuseLeft = D.fuse
				b.since = 0.0
				b.held = 0.0
				var cook: Array = D.cook
				b.cookFor = randf_range(float(cook[0]), float(cook[1]))
				_gren_aim(b, randf_range(W * 0.45, W * 0.95), randf_range(H * 0.1, GY - H * 0.25))
			var hand := Vector2(b.hx + 5.0 * u, GY - 11.0 * u)
			if b.phase == "held":
				b.fuseLeft -= dt
				b.held += dt
				b.since += dt
				if b.fuseLeft <= 0.0:
					_gren_detonate(b, hand.x, hand.y, true)
				elif (b.since > D.release) if b.manual else (b.held > b.cookFor):   # let go: throw
					var body: Dictionary = b.body
					b.phase = "flying"
					body.x = hand.x
					body.y = hand.y
					body.vx = b.ax
					body.vy = b.ay
					body.b = 0
					b.vr = randf_range(-12.0, 12.0)
					b.throws += 1
					b.lastCook = b.held
			if b.phase == "flying":
				b.fuseLeft -= dt
				var body: Dictionary = b.body
				_gren_step(b, body, dt)
				b.rot += b.vr * dt
				if body.b > 0:
					b.vr *= maxf(0.0, 1.0 - 2.0 * dt)
				if b.fuseLeft <= 0.0:
					_gren_detonate(b, body.x, body.y, false)
			if b.phase == "done" and b.fxT > (D.cloud if gas else 0.9):
				b.phase = "idle"
				b.timer = minf(b.timer, D.every * 0.6)
			if gas:                                      # the cloud: puffs that spread, then thin out over D.cloud
				for pv in b.puffs:
					var p: Dictionary = pv
					if not p.on:
						continue
					p.age += dt
					if p.age / D.cloud >= 1.0:
						p.on = false
						continue
					p.x += p.vx * dt
					p.y += p.vy * dt
					p.vx *= maxf(0.0, 1.0 - 0.8 * dt)
					if p.y > GY - p.r * 0.4:
						p.vy = -absf(p.vy) * 0.3
					p.r += u * 1.2 * dt
			else:
				for pv in b.sparks:
					var p: Dictionary = pv
					if not p.on:
						continue
					p.life -= dt * 2.2
					if p.life <= 0.0:
						p.on = false
						continue
					p.x += p.vx * dt
					p.y += p.vy * dt
					p.vy += H * 1.4 * dt
					if p.y > GY:
						p.y = GY
						p.vy = -p.vy * 0.4
		"aoe":
			b.castT += dt
			b.hurtT -= dt
			var tgs: Array = b.tgs
			var ZM: float = b.ZM
			var active := false
			for gv in tgs:
				if gv.on and gv.age < D.windup:
					active = true
			b.active = active
			if not active and b.castT > D.gap:           # autopilot: the caster aims at the hero
				b.castT = 0.0
				_aoe_volley(b, b.hx + randf_range(-1.0, 1.0) * W * 0.05, b.hz)
			var mv := Vector2.ZERO                       # the hero: step out of every shape it has had time to read
			b.moving = false
			for gv in tgs:
				var g: Dictionary = gv
				if not g.on or g.age < D.react or g.age >= D.windup or not _aoe_inside(b, g, b.hx, b.hz):
					continue
				mv += _aoe_out(g, b.hx, b.hz)
			var ml := mv.length()
			if ml > 1e-6:
				b.moving = true
				b.mdir = mv / ml
				b.hx = clampf(b.hx + mv.x / ml * W * D.speed * dt, u * 3.0, W * 0.72)
				b.hz = clampf(b.hz + mv.y / ml * W * D.speed * dt, 0.0, ZM)
				if absf(mv.x) > 0.2:
					b.face = 1 if mv.x > 0.0 else -1
			var newest := -1
			var newestAge := 0.0
			for i in tgs.size():
				var g: Dictionary = tgs[i]
				if not g.on:
					continue
				var was: float = g.age
				g.age += dt
				if was < D.windup and g.age >= D.windup:   # the hit lands: inside, or out?
					if _aoe_inside(b, g, b.hx, b.hz):
						b.hits += 1
						b.hurtT = 0.5
						g.res = "hit"
					else:
						b.dodged += 1
						g.res = "dodged"
				if g.age > D.windup + 0.35:
					g.on = false
				elif g.age >= 0.0 and g.age < D.windup and (newest < 0 or g.age < newestAge):
					newest = i
					newestAge = g.age
			b.newest = newest
		"tell":
			b.pt += dt
			b.clock += dt
			b.dodgeT -= dt
			b.hurtT -= dt
			b.shake *= maxf(0.0, 1.0 - 8.0 * dt)
			b.sx = randf_range(-1.0, 1.0) * b.shake * 2.0
			var phase: String = b.phase
			if phase == "idle" and b.pt > D.every:       # the tell begins; the hero plans its hop: no faster than its reaction, else just before the swing
				b.phase = "tell"
				b.pt = 0.0
				b.tellStart = b.clock
				b.planned = true
				b.plan = maxf(D.react + randf_range(-0.12, 0.12), D.tell - 0.1 + randf_range(-0.08, 0.08))
			elif phase == "tell":
				if b.planned and b.pt >= b.plan:
					b.planned = false
					_tell_dodge(b, false)
				if b.pt > D.tell:
					b.phase = "strike"
					b.pt = 0.0
			elif phase == "strike" and b.pt > D.strike:  # the swing lands: is the hero inside its window?
				var land: float = b.clock
				var ds: float = b.dodgeStart
				var safe: bool = ds <= land and land <= ds + D.dodgeLen
				b.lastAt = ds - b.tellStart
				b.lastRes = "dodged" if safe else "hit"
				b.lastWhy = "" if safe else ("no dodge" if ds < b.tellStart - 0.5 else ("too late" if ds > land else "too early"))
				if safe:
					b.dodged += 1
				else:
					b.hits += 1
					b.hurtT = 0.5
					b.shake = 1.0
				b.phase = "recover"
				b.pt = 0.0
				b.planned = false
			elif phase == "recover" and b.pt > D.recover:
				b.phase = "idle"
				b.pt = 0.0
			var ph: String = b.phase                     # the TARGETS: what the phase machine asks for (read after it ran)
			var pt: float = b.pt
			var kT: float = _ease(pt / D.tell) if ph == "tell" else (1.0 - pt / D.strike * 1.4 if ph == "strike" else (lerpf(-0.4, 0.0, _ease(pt / D.recover)) if ph == "recover" else 0.0))
			var armT: float = lerpf(0.3, -2.4, _ease(pt / D.tell)) if ph == "tell" else (lerpf(-2.4, 1.3, clampf(pt / D.strike, 0.0, 1.0)) if ph == "strike" else (lerpf(1.3, 0.3, _ease(pt / D.recover)) if ph == "recover" else 0.3))
			# two springs chase them (symplectic euler, substepped to ≤ 10 ms): the body's,
			# and the arm's — softer (k · armK) and less damped, so it lags and whips
			var kb: float = maxf(1.0, float(D.k))
			var cb: float = 2.0 * clampf(float(D.damp), 0.0, 0.99) * sqrt(kb)
			var ka: float = kb * maxf(0.05, float(D.armK))
			var ca: float = 2.0 * clampf(float(D.armDamp), 0.0, 0.99) * sqrt(ka)
			var sub := maxi(1, ceili(dt * 100.0))
			var h := dt / float(sub)
			var leanA: float = b.leanA
			var leanV: float = b.leanV
			var armA: float = b.armA
			var armV: float = b.armV
			var lean: float = D.lean
			for _s in sub:
				leanV += (kb * (lean * kT - leanA) - cb * leanV) * h
				leanA = clampf(leanA + leanV * h, -3.0, 3.0)
				armV += (ka * (armT - armA) - ca * armV) * h
				armA = clampf(armA + armV * h, -6.0, 6.0)
			b.leanA = leanA
			b.leanV = leanV
			b.armA = armA
			b.armV = armV

# ================================================================ draw

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	var D: Dictionary = b.D
	var W: float = b.w
	var H: float = b.h
	var GY: float = b.gy
	var u: float = b.u
	var S: float = H / 170.0                             # the web's px, scaled with the card
	var origin: Vector2 = (b.rect as Rect2).position
	match b.id:
		"muzzle":
			var kick: float = b.kick
			var aim: float = b.aim
			var shotT: float = b.shotT
			var L: float = b.L
			Kit.stage(n, b, 0.6)
			Kit.tree(n, Vector2(W * 0.9, GY), H * 0.28)
			Kit.crate(n, Vector2(W * 0.7, GY), u * 5.0)
			var base := Vector2(b.hx + 4.0 * u, GY - 9.0 * u)
			var m := _tip(base, aim, kick, L)
			var fi := int(floorf(shotT / D.frameLen))     # which frame of the shot we are on
			if fi < 1:                                   # the ONE-FRAME light: it paints the ground and the air ("lighter" → bright alpha)
				n.draw_set_transform(origin + Vector2(m.x, GY), 0.0, Vector2(1.0, 0.35))
				Kit.glow(n, Vector2.ZERO, W * 0.3 * D.size, Kit.SUN, 0.7)
				n.draw_set_transform(origin, 0.0, Vector2.ONE)
				Kit.glow(n, m, W * 0.35 * D.size, Kit.SUN, 0.5)
				Kit.rect(n, Rect2(0, 0, W, H), Color(1.0, 0.902, 0.667, D.light))
			Kit.hero(n, b, Vector2(b.hx - kick * 0.2, GY), { "face": 1, "pose": "stand", "frame": t })
			_barrel(n, b, base, aim, kick, L, u)         # the barrel, kicked back by RECOIL
			if fi < int(D.flashFrames):                  # the flash SPRITE: frame 0 big, later frames smaller
				var r: float = u * 4.5 * D.size * (1.0 if fi == 0 else 0.55)
				var a := 1.0 if fi == 0 else 0.8
				var star := PackedVector2Array()
				for i in 10:
					var rr: float = r * 0.35 if i % 2 == 1 else (r * 1.6 if i == 0 else r)
					var th := i / 10.0 * TAU
					star.append(Vector2(cos(th) * rr, sin(th) * rr))
				n.draw_set_transform(origin + m, aim + b.rot * 0.1, Vector2.ONE)
				n.draw_colored_polygon(star, Color(1.0, 0.933, 0.706, a))
				n.draw_set_transform(origin, 0.0, Vector2.ONE)
				Kit.dot(n, m, r * 0.3, Color.WHITE)
			for pv in b.pool:                            # the SMOKE
				var p: Dictionary = pv
				if p.on:
					Kit.dot(n, Vector2(p.x, p.y), p.r, _al(SMOKE, p.life * 0.3))
			var tp := Vector2(b.tx, b.ty)
			Kit.ring(n, tp, u * 1.2, Kit.SPARK if shotT < 0.12 else Kit.DIM, 1.0)
			if shotT < 0.12:
				Kit.dot(n, tp, u * 0.8 * (1.0 - shotT * 6.0), Kit.SPARK)
			var x0 := W * 0.09                           # the TIMELINE of one shot
			var x1 := W * 0.92
			var span: float = maxf(D.smokeLife, maxf(D.frameLen * D.flashFrames * 4.0, 0.5))
			var y0 := 10.0 * S
			var recoilT := 3.0 / (maxf(0.02, float(D.damp)) * sqrt(maxf(1.0, float(D.spring))))   # the spring's envelope e^(−ζ·ω·t) is under 5% after 3 / (ζ·ω): its real settle
			var rows: Array = [["flash", D.frameLen * D.flashFrames, Kit.SPARK], ["light", D.frameLen, Kit.SUN], ["recoil", recoilT, Kit.BONE], ["smoke", D.smokeLife, Color("9A96B0")]]
			for i in rows.size():
				var row: Array = rows[i]
				var y := y0 + i * 8.0 * S
				_text_r(n, row[0], Vector2(x0 - 3.0, y + 4.0 * S), _fs(S, 7.0), Kit.DIM)
				Kit.rect(n, Rect2(x0, y, x1 - x0, 4.0 * S), _al(Kit.INK, 0.08))
				Kit.rect(n, Rect2(x0, y, maxf(1.5, (x1 - x0) * clampf(float(row[1]) / span, 0.0, 1.0)), 4.0 * S), row[2])
			var ph := x0 + (x1 - x0) * clampf(shotT / span, 0.0, 1.0)
			Kit.line(n, Vector2(ph, y0 - 3.0 * S), Vector2(ph, y0 + rows.size() * 8.0 * S), _al(Kit.HOT, 0.9), 1.0)
			Kit.text(n, ("%d ms" % int(shotT * 1000.0)) if shotT < span else "…", Vector2(ph + 3.0, y0 + rows.size() * 8.0 * S + 1.0 + 6.0 * S), _fs(S, 7.0), _al(Kit.HOT, 0.9))
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"eject":
			var kick: float = b.kick
			var hx: float = b.hx
			var L: float = b.L
			var pool: Array = b.pool
			Kit.stage(n, b, 0.35)
			Kit.ground(n, b)
			Kit.hero(n, b, Vector2(hx - kick * 0.2, GY), { "face": 1, "pose": "stand", "frame": t })
			n.draw_rect(Rect2(hx + 4.0 * u - kick, GY - 10.0 * u, L, 2.0 * u), INK_DARK)
			n.draw_rect(Rect2(hx + 5.5 * u - kick, GY - 8.0 * u, 2.0 * u, 3.0 * u), INK_DARK)
			if b.flash > 0.0:
				Kit.dot(n, Vector2(hx + 4.0 * u + L, GY - 9.0 * u), u * 2.2, Kit.SPARK)
			var alive := 0
			var last: int = b.last
			for i in pool.size():
				var p: Dictionary = pool[i]
				if not p.on:
					continue
				alive += 1
				var a: float = maxf(0.0, 1.0 - (p.restT - D.settle) / 0.6) if p.restT > D.settle else 1.0
				n.draw_set_transform(origin + Vector2(p.x, p.y - u * 0.35), p.rot, Vector2.ONE)
				n.draw_rect(Rect2(-u * 0.9, -u * 0.35, u * 1.8, u * 0.7), Color(0.847, 0.659, 0.29, a))
				n.draw_rect(Rect2(-u * 0.9, -u * 0.35, u * 0.4, u * 0.7), Color(0.541, 0.392, 0.125, a))
				n.draw_set_transform(origin, 0.0, Vector2.ONE)
				if p.bounces == 0 and i == last and p.age < 0.3:
					Kit.arrow(n, Vector2(p.x, p.y - u), Vector2(p.x + p.vx * 0.12, p.y - u + p.vy * 0.12), Kit.SUN)
			if last >= 0:
				var lp: Dictionary = pool[last]
				if lp.on and lp.bounces > 0 and lp.age < 1.2:
					Kit.text(n, "bounce %d  ×e" % int(lp.bounces), Vector2(lp.x, lp.y - u * 2.5), _fs(S, 8.0), _al(Kit.SUN, 0.9), true)
			Kit.text(n, "e = %s   μ = %s   pool %d/%d   fired %d" % [str(D.rest), str(D.friction), alive, pool.size(), int(b.fired)], Vector2(W * 0.5, 14.0 * S), _fs(S, 8.0), Kit.DIM, true)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"tracer":
			var kick: float = b.kick
			var aim: float = b.aim
			var L: float = b.L
			var candT: float = b.candT
			Kit.stage(n, b, 0.5)
			Kit.ground(n, b)
			Kit.crate(n, Vector2(b.cx, GY), b.cs)
			Kit.wall(n, Rect2(b.wx, GY - b.wh, b.ww, b.wh))
			var base := Vector2(b.hx + 4.0 * u, GY - 9.0 * u)
			Kit.hero(n, b, Vector2(b.hx - kick * 0.2, GY), { "face": 1, "pose": "stand", "frame": t })
			_barrel(n, b, base, aim, kick, L, u)
			Kit.ring(n, Vector2(b.tx, b.ty), u, Kit.DIM, 1.0)
			if candT < 0.5:                              # every segment the ray crossed
				for cv in b.cand:
					Kit.ring(n, cv, u * 1.1, _al(Kit.INK, 0.5 - candT), 1.0)
			var tracers: Array = b.tracers
			var i := tracers.size() - 1
			while i >= 0:                                # "lighter" in the web: bright alpha here
				var tr: Dictionary = tracers[i]
				var a: float = (1.0 - tr.age / D.linger) if tr.glow else (float(tr.left) / D.frames)
				if a > 0.0:
					var p1: Vector2 = tr.p1
					var p2: Vector2 = tr.p2
					if tr.glow:
						n.draw_line(p1, p2, Color(0.961, 0.541, 0.353, a * 0.5), u * 1.4)
						Kit.glow(n, p2, u * 4.0, Kit.SUN, a * 0.8)
					n.draw_line(p1, p2, _al(PALE, a), 1.5)
					n.draw_line(p1, p2, Color(1.0, 1.0, 1.0, a * 0.8), 0.6)
					if i == tracers.size() - 1:
						Kit.ring(n, p2, u * 1.4, Kit.SPARK, 1.5)
						Kit.arrow(n, p2, p2 + Vector2(tr.nx, tr.ny) * u * 4.0, Kit.SUN)
						var txt: String = ("lingers %.2f s" % maxf(0.0, D.linger - tr.age)) if tr.glow else ("%d f left" % int(tr.left))
						Kit.text(n, txt, (p1 + p2) / 2.0 - Vector2(0.0, 6.0), _fs(S, 8.0), _al(PALE, 0.95), true)
				i -= 1
			for pv in b.sparks:
				var p: Dictionary = pv
				if p.on:
					Kit.dot(n, Vector2(p.x, p.y), 1.0, _al(Kit.SPARK, p.life))
			var ge := int(D.glowEvery)
			Kit.text(n, "shots %d%s · segments %d" % [int(b.shots), (" · every %drd glows" % ge) if ge > 0 else "", (b.segs as Array).size()], Vector2(W / 2.0, 14.0 * S), _fs(S, 8.0), Kit.DIM, true)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"impact":
			var kick: float = b.kick
			var aim: float = b.aim
			var L: float = b.L
			var ly: float = b.ly
			var hitT: float = b.hitT
			var pw: float = b.pw
			var mats: Array = D.materials
			var panels: Array = b.panels
			Kit.stage(n, b, D.night)
			for i in 4:                                  # the four panels, each its own material
				var P: Dictionary = panels[i]
				var mat: Dictionary = mats[i] if i < mats.size() else mats[0]
				var mc := Color(mat.c)
				var pa: float = P.a
				var pb: float = P.b
				var ya: float = P.ya
				var yb: float = P.yb
				Kit.poly(n, [Vector2(pa, ya), Vector2(pb, yb), Vector2(pb, H), Vector2(pa, H)], mc)
				if mat.fx == "chips":
					var x := pa + u
					while x < pb:
						Kit.line(n, Vector2(x, ya + 1.0), Vector2(x, H), Color(0.0, 0.0, 0.0, 0.18), 1.0)
						x += u * 2.2
				if mat.fx == "sparks":
					Kit.line(n, Vector2(pa + 2.0, ya + u * 0.6), Vector2(pb - 2.0, yb + u * 0.6), Color(1.0, 1.0, 1.0, 0.25), 1.0)
				if mat.fx == "ring":
					Kit.rect(n, Rect2(pa, ya - u, u * 0.6, H - ya + u), Color("4A4470"))
					Kit.rect(n, Rect2(pb - u * 0.6, ya - u, u * 0.6, H - ya + u), Color("4A4470"))
				Kit.line(n, Vector2(pa, ya), Vector2(pb, yb), Color(1.0, 1.0, 1.0, 0.35), 1.5)
				Kit.text(n, mat.name, Vector2((pa + pb) / 2.0, maxf(ya, yb) + 11.0 * S), _fs(S, 8.0), Color(1.0, 1.0, 1.0, 0.75), true)
			Kit.rect(n, Rect2(0, ly, W * 0.22, GY - ly), Color("4A4470"))   # the ledge the shooter stands on
			Kit.line(n, Vector2(0, ly), Vector2(W * 0.22, ly), Kit.BONE, 1.0)
			var base := Vector2(b.hx + 4.0 * u, ly - 9.0 * u)
			Kit.hero(n, b, Vector2(b.hx - kick * 0.2, ly), { "face": 1, "pose": "stand", "frame": t })
			_barrel(n, b, base, aim, kick, L, u)
			var trace: int = b.trace
			if trace > 0:
				Kit.line(n, b.tr0, b.tr1, _al(PALE, 0.4 + (trace - 1) * 0.3), 1.2)
			for rv in b.rings:                           # water: a ring that spreads on the surface plane
				var r: Dictionary = rv
				var k: float = r.age / 1.1
				_ellipse_ring(n, Vector2(r.x, r.y), maxf(0.5, pw * 0.45 * k), maxf(0.3, u * 0.9 * k), Color(1.0, 1.0, 1.0, (1.0 - k) * 0.8), 1.5)
			for pv in b.pool:
				var p: Dictionary = pv
				if not p.on:
					continue
				var pp := Vector2(p.x, p.y)
				if p.kind == "sparks":
					_streak(n, pp, Vector2(p.vx, p.vy), 0.02, _al(Kit.SPARK, p.life), 1.2)
				elif p.kind == "dust":
					Kit.dot(n, pp, p.r, _al(p.c, p.life * 0.35))
				else:
					n.draw_set_transform(origin + pp, p.rot, Vector2.ONE)
					n.draw_rect(Rect2(-p.r, -p.r * 0.5, p.r * 2.0, p.r), _al(p.c, minf(1.0, p.life * 2.0)))
					n.draw_set_transform(origin, 0.0, Vector2.ONE)
			var lastHit: Dictionary = b.lastHit
			if not lastHit.is_empty() and hitT < 0.6:    # the normal, where it acts
				var hp := Vector2(lastHit.x, lastHit.y)
				var nv := Vector2(lastHit.nx, lastHit.ny)
				Kit.arrow(n, hp, hp + nv * u * 5.0, Kit.SUN)
				Kit.text(n, "n", hp + nv * u * 6.0 + Vector2(0.0, 3.0), _fs(S, 9.0), Kit.SUN, true)
			var tx := W * 0.62                           # the lookup table, drawn
			var ty := 8.0 * S
			var rw := W * 0.34
			var rh := 9.0 * S
			Kit.rect(n, Rect2(tx - 3.0, ty - 2.0, rw + 6.0, rh * 4.0 + 4.0), _al(Kit.NIGHT, 0.55))
			for i in 4:
				var mat: Dictionary = mats[i] if i < mats.size() else mats[0]
				var y := ty + i * rh
				var hot: bool = i == b.lastRow and hitT < 0.5
				if hot:
					Kit.rect(n, Rect2(tx - 3.0, y - 1.0, rw + 6.0, rh), _al(Kit.SUN, 0.35))
				Kit.rect(n, Rect2(tx, y + 1.0, 6.0 * S, 6.0 * S), Color(mat.c))
				Kit.text(n, "%s → %s" % [mat.name, mat.fx], Vector2(tx + 10.0 * S, y + 7.0 * S), _fs(S, 8.0), Kit.INK if hot else Kit.BONE)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"decals":
			var kick: float = b.kick
			var aim: float = b.aim
			var L: float = b.L
			var N: int = b.N
			var stamped: int = b.stamped
			var count := mini(stamped, N)
			var oldest := stamped - count + 1
			var slots: Array = b.slots
			Kit.stage(n, b, 0.35)
			Kit.wall(n, Rect2(b.wx, b.wy, W - b.wx, GY - b.wy))
			var r: float = u * 0.9 * D.size
			for sv in slots:                             # the decals: under everything that moves
				var sl: Dictionary = sv
				if not sl.on:
					continue
				var a: float = sl.a
				var sp := Vector2(sl.x, sl.y)
				var shape: Array = sl.shape
				if sl.kind == "hole":
					n.draw_circle(sp, r * 1.7, Color(1.0, 1.0, 1.0, 0.18 * a))
					n.draw_circle(sp, r, _al(Color("16121E"), a))
					var i := 0
					while i + 1 < shape.size():
						n.draw_line(sp + shape[i], sp + shape[i + 1], Color(0.078, 0.063, 0.118, 0.7 * a), 1.0)
						i += 2
				elif sl.kind == "scorch":                # the web's radial gradient: a dark glow
					Kit.glow(n, sp, r * 4.0, Color(0.04, 0.03, 0.055), 0.9 * a)
				elif sl.kind == "circle":
					var pts := PackedVector2Array()
					for q in shape:
						pts.append(sp + q)
					n.draw_polyline(pts, Color(0.961, 0.953, 0.98, 0.9 * a), 1.6)
				elif shape.size() >= 4:
					n.draw_line(sp + shape[0], sp + shape[1], Color(0.961, 0.953, 0.98, 0.9 * a), 1.6)
					n.draw_line(sp + shape[2], sp + shape[3], Color(0.961, 0.953, 0.98, 0.9 * a), 1.6)
			Kit.crate(n, Vector2(W * 0.62, GY), u * 5.0)
			var base := Vector2(b.hx + 4.0 * u, GY - 9.0 * u)
			Kit.hero(n, b, Vector2(b.hx - kick * 0.2, GY), { "face": 1, "pose": "stand", "frame": t })
			_barrel(n, b, base, aim, kick, L, u)
			var trace: int = b.trace
			if trace > 0:
				Kit.line(n, b.tr0, b.tr1, _al(PALE, 0.4 + (trace - 1) * 0.3), 1.2)
			var bx := W * 0.06                           # the ring buffer, drawn slot by slot
			var bw := W * 0.88 / N
			var by := 6.0 * S
			var bh := 9.0 * S
			for i in N:
				var sl: Dictionary = slots[i]
				var x := bx + i * bw
				Kit.rect(n, Rect2(x + 1.0, by, bw - 2.0, bh), _al(Kit.SUN, 0.15 + sl.a * 0.75) if sl.on else _al(Kit.INK, 0.08))
				if sl.on and sl.seq == oldest and count >= N:
					Kit.text(n, "old", Vector2(x + bw / 2.0, by + bh + 8.0 * S), _fs(S, 7.0), Kit.HOT, true)
			var hxx: float = bx + (int(b.head) % N) * bw + bw / 2.0
			Kit.arrow(n, Vector2(hxx, by + bh + 9.0 * S), Vector2(hxx, by + bh + 1.0), Kit.SUN)
			Kit.text(n, "head", Vector2(hxx + 3.0, by + bh + 12.0 * S), _fs(S, 7.0), Kit.SUN)
			_text_r(n, "stamped %d · kept %d/%d" % [stamped, count, N], Vector2(W - 6.0, by + bh + 12.0 * S), _fs(S, 8.0), Kit.DIM)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"marks":
			var pal: Array = D.palette
			var ground := Color(pal[0])
			var mark := Color(pal[1])
			var hx: float = b.hx
			var tx: float = b.tx
			var carX: float = b.carX
			var roadY: float = b.roadY
			var prints: Array = b.prints
			Kit.stage(n, b, 0.15)
			Kit.vgrad(n, Rect2(0, GY, W, H - GY), ground, Kit.shade(ground, -0.25))
			Kit.tree(n, Vector2(W * 0.08, GY), H * 0.22, Color("5E8A6A"))
			Kit.tree(n, Vector2(W * 0.92, GY), H * 0.26, Color("5E8A6A"))
			var live := 0
			for pv in prints:
				var p: Dictionary = pv
				if not p.on:
					continue
				live += 1
				Kit.ellipse(n, Vector2(p.x, p.y), u * 1.3 * D.size, u * 0.6 * D.size, _al(mark, 1.0 - p.age / D.life))
			for qv in b.tyres:
				var q: Dictionary = qv
				if q.on:
					Kit.rect(n, Rect2(q.x - u * 0.9, q.y - u * 0.35 * D.size, u * 1.8, u * 0.7 * D.size), _al(mark, (1.0 - q.age / D.life) * 0.9))
			Kit.hero(n, b, Vector2(hx, GY), { "face": b.face, "pose": "run" if absf(tx - hx) > u else "stand", "frame": b.dist / (u * 3.0) })
			n.draw_rect(Rect2(carX - 5.0 * u, roadY - 4.5 * u, 10.0 * u, 3.0 * u), Kit.HOT)   # the car
			n.draw_rect(Rect2(carX - 3.0 * u, roadY - 6.5 * u, 5.0 * u, 2.2 * u), Kit.HOT)
			Kit.dot(n, Vector2(carX - 3.5 * u, roadY - u), u * 1.1, INK_DARK)
			Kit.dot(n, Vector2(carX + 3.5 * u, roadY - u), u * 1.1, INK_DARK)
			var gx := W - 72.0 * S                       # the age fade, drawn: alpha against age
			var gy := 8.0 * S
			var gw := 62.0 * S
			var gh := 24.0 * S
			Kit.rect(n, Rect2(gx - 4.0, gy - 3.0, gw + 8.0, gh + 16.0 * S), _al(Kit.NIGHT, 0.55))
			Kit.line(n, Vector2(gx, gy), Vector2(gx, gy + gh), Kit.DIM, 1.0)
			Kit.line(n, Vector2(gx, gy + gh), Vector2(gx + gw, gy + gh), Kit.DIM, 1.0)
			Kit.line(n, Vector2(gx, gy), Vector2(gx + gw, gy + gh), Kit.SUN, 1.2)
			for pv in prints:
				var p: Dictionary = pv
				if p.on:
					var k: float = clampf(p.age / D.life, 0.0, 1.0)
					Kit.dot(n, Vector2(gx + gw * k, gy + gh * k), 1.5, Kit.BONE)
			Kit.text(n, "a = 1 − age/%s s" % str(D.life), Vector2(gx + gw / 2.0, gy + gh + 10.0 * S), _fs(S, 7.0), Kit.DIM, true)
			Kit.text(n, "prints %d · steps %d · stride %d px" % [live, int(b.steps), roundi(W * D.stride)], Vector2(6.0, 14.0 * S), _fs(S, 8.0), Kit.DIM)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"ink":
			var kick: float = b.kick
			var aim: float = b.aim
			var L: float = b.L
			var wy: float = b.wy
			var hitT: float = b.hitT
			var col := Color(D.colour)
			var dry: float = maxf(0.1, D.dry)
			Kit.stage(n, b, 0.3)
			Kit.rect(n, Rect2(0, wy, W, GY - wy), Color(D.paper))   # the wall
			var y := wy + 14.0 * S
			while y < GY:
				Kit.line(n, Vector2(0, y), Vector2(W, y), Color(0.0, 0.0, 0.0, 0.12), 1.0)
				y += 14.0 * S
			for sv in b.stamps:                          # the layer: every splat, washed out by its age
				var st: Dictionary = sv
				var a: float = exp(-st.age / dry)
				for cv in st.circles:
					var c: Vector3 = cv
					n.draw_circle(Vector2(c.x, c.y), c.z, _al(col, a))
			for dv in b.drips:                           # the drips: a tapered thread from where they started
				var d: Dictionary = dv
				if not d.alive:
					continue
				var a: float = exp(-d.age / dry)
				var w0: float = d.w0
				var w: float = maxf(0.25, d.w)
				var dx: float = d.x
				var y0: float = d.y0
				var y1: float = d.y
				if y1 - y0 > 0.5 and w0 > 0.3:
					n.draw_colored_polygon(PackedVector2Array([Vector2(dx - w0 / 2.0, y0), Vector2(dx + w0 / 2.0, y0), Vector2(dx + w / 2.0, y1), Vector2(dx - w / 2.0, y1)]), _al(col, a))
					n.draw_circle(Vector2(dx, y1), w / 2.0, _al(col, a))
				if d.on:                                 # the bead at each growing drip's tip
					Kit.dot(n, Vector2(dx, y1), d.w * 0.75, col)
			var base := Vector2(b.hx + 4.0 * u, GY - 9.0 * u)
			Kit.hero(n, b, Vector2(b.hx - kick * 0.2, GY), { "face": 1, "pose": "stand", "frame": t })
			_barrel(n, b, base, aim, kick, L, u)
			var last: Dictionary = b.last
			if not last.is_empty() and hitT < 0.7:       # the normal, and the far side of it
				var a := 1.0 - hitT / 0.7
				var hp := Vector2(last.x, last.y)
				var nv := Vector2(last.nx, last.ny)
				var cp := Vector2(last.cx, last.cy)
				Kit.arrow(n, hp, hp + nv * u * 5.0, _al(Kit.SUN, a))
				Kit.text(n, "n", hp + nv * u * 6.5 + Vector2(0.0, 3.0), _fs(S, 9.0), _al(Kit.SUN, a), true)
				_dash_line(n, hp, cp, _al(Kit.BONE, a), 1.0, 2.0, 3.0)
				Kit.text(n, "far side", cp - Vector2(0.0, u * 2.2 * D.size), _fs(S, 8.0), _al(Kit.BONE, a), true)
			Kit.text(n, "splats %d · colour %s · dries in %s s" % [int(b.splats), str(D.colour), str(D.dry)], Vector2(W / 2.0, 14.0 * S), _fs(S, 8.0), Kit.DIM, true)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"rubble":
			var B: float = b.B
			var col := Color(D.colour)
			Kit.stage(n, b, 0.3)
			Kit.ground(n, b)
			Kit.hero(n, b, Vector2(W * 0.08, GY), { "face": 1, "pose": "stand", "frame": t })
			for bv in b.blocks:                          # the blocks: a crate look in the material's colour
				var bl: Dictionary = bv
				if bl.gone > 0.0:
					continue
				var bx: float = bl.x
				n.draw_rect(Rect2(bx - B / 2.0, GY - B, B, B), col)
				var lw := maxf(1.0, B * 0.08)
				var edge := Kit.shade(col, -0.4)
				n.draw_rect(Rect2(bx - B / 2.0 + 1.0, GY - B + 1.0, B - 2.0, B - 2.0), edge, false, lw)
				n.draw_line(Vector2(bx - B / 2.0, GY - B), Vector2(bx + B / 2.0, GY), edge, lw)
				n.draw_line(Vector2(bx + B / 2.0, GY - B), Vector2(bx - B / 2.0, GY), edge, lw)
			for dv in b.dust:
				var d: Dictionary = dv
				if d.on:
					Kit.dot(n, Vector2(d.x, d.y), d.r, Color(0.784, 0.745, 0.706, d.life * 0.3))
			var flying := 0
			var bounced := 0
			var fading := 0
			for pv in b.pool:
				var p: Dictionary = pv
				if not p.on:
					continue
				if p.bounced == 1:
					bounced += 1
				elif p.bounced == 0:
					flying += 1
				elif p.still > D.hold:
					fading += 1
				n.draw_set_transform(origin + Vector2(p.x, p.y), p.rot, Vector2.ONE)
				n.draw_colored_polygon(p.pts, _al(p.c, maxf(0.0, p.life)))
				n.draw_set_transform(origin, 0.0, Vector2.ONE)
			for mv in b.marks:
				var mk: Dictionary = mv
				Kit.ring(n, Vector2(mk.x, GY), u * 2.0 * mk.age / 0.4 + 1.0, _al(Kit.SUN, 1.0 - mk.age / 0.4), 1.0)
			Kit.text(n, "last break: %d chunks · flying %d · bounced %d · fading %d" % [int(b.lastN), flying, bounced, fading], Vector2(W / 2.0, 14.0 * S), _fs(S, 8.0), Kit.DIM, true)
			Kit.text(n, "e = %s · ω ≤ %s rad/s · g = %s H/s²" % [str(D.rest), str(D.spin), str(D.g)], Vector2(W / 2.0, 25.0 * S), _fs(S, 8.0), Kit.DIM, true)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"kaboom":
			var bw: float = b.bw
			var bh: float = b.bh
			var dh: float = b.dh
			var R: float = b.R
			var fadeIn: float = b.fadeIn
			var barrels: Array = b.barrels
			var queue: Array = b.queue
			Kit.stage(n, b, D.night)
			Kit.ground(n, b)
			for i in barrels.size():
				var br: Dictionary = barrels[i]
				if not br.alive:
					continue
				var bx: float = br.x
				n.draw_rect(Rect2(bx - bw / 2.0, GY - bh, bw, bh), _al(Color("8A3A3A"), fadeIn))
				n.draw_rect(Rect2(bx - bw / 2.0, GY - bh * 0.7, bw, u * 0.5), _al(Color("4A2A2A"), fadeIn))
				n.draw_rect(Rect2(bx - bw / 2.0, GY - bh * 0.3, bw, u * 0.5), _al(Color("4A2A2A"), fadeIn))
				var due := -1.0
				for qv in queue:
					var q: Dictionary = qv
					if q.kind == "barrel" and q.i == i:
						due = q.left
				if due >= 0.0:                           # the fuse bar: time left before it goes
					var w := bw * 1.4
					Kit.rect(n, Rect2(bx - w / 2.0, GY - bh - u * 1.6, w, u * 0.6), _al(Kit.INK, 0.2))
					Kit.rect(n, Rect2(bx - w / 2.0, GY - bh - u * 1.6, w * clampf(due / maxf(D.delay, D.fuse), 0.0, 1.0), u * 0.6), Kit.HOT)
					if fmod(t * 12.0, 2.0) < 1.0:
						Kit.dot(n, Vector2(bx, GY - bh - u * 0.4), u * 0.5, Kit.SPARK)
			for dv in b.dominoes:                        # dominoes fall about their base corner
				var dm: Dictionary = dv
				n.draw_set_transform(origin + Vector2(dm.x + u * 0.5, GY), float(dm.th), Vector2.ONE)
				n.draw_rect(Rect2(-u * 0.5, -dh, u, dh), _al(Kit.BONE, fadeIn))
				n.draw_rect(Rect2(-u * 0.15, -dh * 0.55, u * 0.3, u * 0.3), _al(INK_DARK, fadeIn))
				n.draw_set_transform(origin, 0.0, Vector2.ONE)
			for pv in b.smoke:
				var p: Dictionary = pv
				if p.on:
					Kit.dot(n, Vector2(p.x, p.y), p.r, Color(0.353, 0.314, 0.353, p.life * 0.45))
			for bv in b.blasts:                          # the blast: a fireball, and the honest radius ring ("lighter" → bright alpha)
				var bl: Dictionary = bv
				var k: float = bl.age / 0.7
				var bp := Vector2(bl.x, bl.y)
				if k < 0.3:
					Kit.glow(n, bp, minf(R * 0.6, W * 0.16) * (0.5 + k), Kit.FIRE, 0.9 * (1.0 - k / 0.3))
				Kit.ring(n, bp, R * minf(1.0, k * 3.0), _al(Kit.SUN, (1.0 - k) * 0.9), 1.5)
				_dash_ring(n, bp, R, _al(Kit.SUN, 0.5 * (1.0 - k)), 1.0, 3.0, 4.0)
				Kit.text(n, "R", bp + Vector2(R + 3.0, 3.0), _fs(S, 8.0), _al(Kit.SUN, 1.0 - k))
			var f := ThemeDB.fallback_font                # the queue, drawn in order
			var fs := _fs(S, 8.0)
			var qx := 6.0
			Kit.text(n, "queue:", Vector2(qx, 14.0 * S), fs, Kit.DIM)
			qx += 36.0 * S
			if queue.is_empty():
				Kit.text(n, "empty", Vector2(qx, 14.0 * S), fs, Kit.DIM)
			for qv in queue:
				if qx >= W - 30.0:
					break
				var q: Dictionary = qv
				var tag := "%s%d %.2f" % ["B" if q.kind == "barrel" else "D", int(q.i) + 1, float(q.left)]
				var tw := f.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				Kit.rect(n, Rect2(qx - 2.0, 5.0 * S, tw + 4.0, 11.0 * S), _al(Kit.HOT, 0.35) if q.kind == "barrel" else Color(0.788, 0.769, 0.894, 0.3))
				Kit.text(n, tag, Vector2(qx, 14.0 * S), fs, Kit.BONE)
				qx += tw + 8.0
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"wick":
			var candle: bool = b.candle
			var L: float = b.L
			var pos: float = b.pos
			var lit: bool = b.lit
			var popped: bool = b.popped
			var hurried: bool = b.hurried
			var popT: float = b.popT
			var pts: Array = b.pts
			var cum: Array = b.cum
			var endp: Vector2 = b.endp
			var rate: float = L / maxf(0.1, D.burn) * (D.hurry if hurried else 1.0)
			var left: float = (L - pos) / rate if lit else (0.0 if popped else D.burn)
			Kit.stage(n, b, 0.55)
			Kit.ground(n, b)
			Kit.hero(n, b, Vector2(W * 0.92, GY), { "face": -1, "pose": "crouch" if (lit and left < 0.6 and not candle) else "stand", "frame": t })
			var fade := clampf(b.sinceReset / 0.4, 0.0, 1.0)   # the fuse fades back in after a pop
			var p := _wick_at(b, pos)
			if candle:                                   # the candle: a body from the flame down, on a saucer
				var cx: float = (pts[0] as Vector2).x
				var topY: float = p.y if lit else (endp.y if popped else (pts[0] as Vector2).y)
				Kit.rect(n, Rect2(cx - u * 3.0, GY - u * 0.9, u * 6.0, u * 0.9), _al(Kit.BONE, fade))
				Kit.rect(n, Rect2(cx - u * 1.7, topY, u * 3.4, maxf(0.0, GY - u * 0.9 - topY)), _al(Color("EFE6D0"), fade))
				Kit.rect(n, Rect2(cx - u * 1.7, topY, u * 0.6, maxf(0.0, GY - u * 0.9 - topY)), Color(0.0, 0.0, 0.0, 0.12 * fade))
				for dv in b.wdrips:
					var d: Dictionary = dv
					if not d.on:
						continue
					Kit.dot(n, Vector2(d.x, d.y), d.r, _al(Color("F6EEDC"), fade))
					Kit.rect(n, Rect2(d.x - d.r * 0.5, topY + u, d.r, maxf(0.0, d.y - topY - u)), _al(Color("F6EEDC"), fade))
				Kit.line(n, Vector2(cx, topY - u * 1.6), Vector2(cx, topY), _al(INK_DARK, fade), maxf(1.0, u * 0.4))
			else:                                        # the rope: ash behind the spark, hemp ahead of it
				var N := pts.size() - 1
				for i in range(1, N + 1):
					if float(cum[i]) <= pos:
						_dash_line(n, pts[i - 1], pts[i], Color(0.353, 0.329, 0.392, 0.8 * fade), maxf(1.0, u * 0.45), 2.0, 3.0)
				if not popped:
					var hemp := PackedVector2Array([p])
					for i in range(1, N + 1):
						if float(cum[i]) > pos:
							hemp.append(pts[i])
					if hemp.size() >= 2:
						n.draw_polyline(hemp, _al(Color("8A6A3E"), fade), maxf(1.5, u * 0.9))
					Kit.dot(n, endp, u * 2.6, _al(Color("1E1A2A"), fade))
					Kit.dot(n, endp + Vector2(-u * 0.8, -u * 0.9), u * 0.6, Color(1.0, 1.0, 1.0, 0.35 * fade))
			for pv in b.puffs:
				var q: Dictionary = pv
				if q.on:
					Kit.dot(n, Vector2(q.x + Kit.noise(q.y * 0.05) * u, q.y), q.r, Color(0.667, 0.647, 0.745, q.life * 0.35))
			if lit:                                      # the spark, or the flame
				if candle:
					var fl := 1.0 + Kit.noise(t * 9.0) * 0.25
					Kit.glow(n, p - Vector2(0.0, u), u * 6.0 * fl, Kit.SUN, 0.45)
					Kit.dot(n, Vector2(p.x + Kit.noise(t * 13.0) * u * 0.3, p.y - u * 1.6), u * 1.1 * fl, Kit.FIRE)
					Kit.dot(n, Vector2(p.x, p.y - u * 1.1), u * 0.5, Kit.SPARK)
				else:
					Kit.glow(n, p, u * 4.5 + Kit.noise(t * 30.0) * u, Kit.SUN, 0.7)
					Kit.dot(n, p, u * 0.9, Color.WHITE)
				Kit.text(n, "%.1f s" % left, Vector2(p.x, p.y - u * 3.5), _fs(S, 9.0), Kit.SPARK, true)
			for qv in b.sparks:
				var q: Dictionary = qv
				if q.on:
					_streak(n, Vector2(q.x, q.y), Vector2(q.vx, q.vy), 0.015, _al(Kit.SPARK, q.life), 1.2)
			if popped and not candle and popT < 0.35:
				var k := popT / 0.35
				Kit.glow(n, endp, W * 0.16 * (0.6 + k), Kit.FIRE, (1.0 - k) * 0.9)
				Kit.ring(n, endp, W * 0.2 * k + 1.0, _al(Kit.SUN, 1.0 - k), 1.5)
			var x0 := W * 0.1                            # the burn-down bar: the rope's length as a bar, one tick per plain second
			var x1 := W * 0.9
			var y0 := 8.0 * S
			var bw := x1 - x0
			Kit.rect(n, Rect2(x0, y0, bw, 5.0 * S), _al(Kit.INK, 0.1))
			Kit.rect(n, Rect2(x0, y0, bw * clampf((L - pos) / L, 0.0, 1.0) * (0.0 if popped else 1.0), 5.0 * S), Kit.FIRE if hurried else Kit.SUN)
			var burn: float = D.burn
			if burn <= 30.0:
				for i in range(1, int(burn)):
					Kit.line(n, Vector2(x0 + bw * i / burn, y0), Vector2(x0 + bw * i / burn, y0 + 5.0 * S), _al(Kit.NIGHT, 0.6), 1.0)
			var state := ("guttered" if candle else "pop!") if popped else ("lit" if lit else "unlit")
			Kit.text(n, "burn %s s · L = %d px%s · %s · %d so far" % [str(D.burn), roundi(L), (" · hurried ×%s" % str(D.hurry)) if hurried else "", state, int(b.pops)], Vector2(W / 2.0, y0 + 15.0 * S), _fs(S, 8.0), Kit.DIM, true)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"grenade":
			var gas: bool = b.gas
			var phase: String = b.phase
			var fuseLeft: float = b.fuseLeft
			var hurtT: float = b.hurtT
			var fxT: float = b.fxT
			var hx: float = b.hx
			Kit.stage(n, b, 0.4)
			Kit.ground(n, b)
			Kit.crate(n, Vector2(b.cx, GY), b.cs)
			var hand := Vector2(hx + 5.0 * u, GY - 11.0 * u)
			Kit.hero(n, b, Vector2(hx, GY), { "face": 1, "pose": "hurt" if hurtT > 0.0 else "stand", "frame": t })
			if phase == "held":                          # the preview: run the integrator ahead and mark where the fuse ends
				var pv := { "x": hand.x, "y": hand.y, "vx": b.ax, "vy": b.ay, "b": 0 }
				var steps := 100
				var boomStep := int(floorf(fuseLeft * 50.0))
				var boom := Vector2(-1.0, -1.0)
				for i in range(1, steps + 1):
					_gren_step(b, pv, 0.02)
					if i % 4 == 0:
						Kit.dot(n, Vector2(pv.x, pv.y), 1.2, _al(Kit.INK, 0.8 - i / float(steps) * 0.6))
					if i == boomStep:
						boom = Vector2(pv.x, pv.y)
				if boom.x >= 0.0:
					Kit.ring(n, boom, u * 2.5, Kit.HOT, 1.5)
					Kit.text(n, "boom", boom - Vector2(0.0, u * 3.2), _fs(S, 8.0), Kit.HOT, true)
				else:
					Kit.text(n, "boom later →", Vector2(pv.x, pv.y - u * 2.5), _fs(S, 8.0), _al(Kit.HOT, 0.7), true)
				Kit.arrow(n, hand, hand + Vector2(b.ax, b.ay) * 0.1, Kit.SUN)
				_grenade(n, b, hand, 0.0, 1.0)
				var mw := u * 8.0                        # the cook meter: how much fuse is left while it is still in the hand
				Kit.rect(n, Rect2(hand.x - mw / 2.0, hand.y - u * 4.2, mw, u * 0.8), _al(Kit.INK, 0.15))
				Kit.rect(n, Rect2(hand.x - mw / 2.0, hand.y - u * 4.2, mw * clampf(fuseLeft / D.fuse, 0.0, 1.0), u * 0.8), Kit.HOT if fuseLeft < 1.0 else Kit.SUN)
				Kit.text(n, "cooking %.2f s · %.2f left" % [float(b.held), fuseLeft], Vector2(hand.x, hand.y - u * 5.2), _fs(S, 8.0), Kit.HOT if fuseLeft < 1.0 else Kit.BONE, true)
			if phase == "flying":
				var body: Dictionary = b.body
				var bp := Vector2(body.x, body.y)
				_grenade(n, b, bp, b.rot, 1.0)
				Kit.rect(n, Rect2(bp.x - u * 3.0, bp.y - u * 3.2, u * 6.0, u * 0.7), _al(Kit.INK, 0.15))
				Kit.rect(n, Rect2(bp.x - u * 3.0, bp.y - u * 3.2, u * 6.0 * clampf(fuseLeft / D.fuse, 0.0, 1.0), u * 0.7), Kit.HOT if fuseLeft < 1.0 else Kit.SUN)
				Kit.text(n, "%.2f s" % fuseLeft, Vector2(bp.x, bp.y - u * 4.0), _fs(S, 8.0), Kit.BONE, true)
			if gas:                                      # the cloud: puffs that spread, then thin out over D.cloud
				for pv in b.puffs:
					var p: Dictionary = pv
					if p.on:
						Kit.dot(n, Vector2(p.x, p.y), p.r, _al(Kit.GOOD, (1.0 - p.age / D.cloud) * 0.35))
			else:                                        # the flash and the shrapnel ("lighter" → bright alpha)
				if fxT < 0.35:
					var k := fxT / 0.35
					var fp := Vector2(b.fxX, b.fxY)
					Kit.glow(n, fp, W * 0.15 * (0.6 + k), Kit.FIRE, (1.0 - k) * 0.9)
					Kit.ring(n, fp, W * 0.18 * k + 1.0, _al(Kit.SUN, 1.0 - k), 1.5)
				for pv in b.sparks:
					var p: Dictionary = pv
					if p.on:
						_streak(n, Vector2(p.x, p.y), Vector2(p.vx, p.vy), 0.02, _al(Kit.SPARK, p.life), 1.2)
			if hurtT > 0.0:
				Kit.text(n, "cooked off in hand", Vector2(hx, GY - u * 20.0), _fs(S, 9.0), Kit.HOT, true)
			var throws: int = b.throws
			Kit.text(n, "fuse %s s · throws %d · cooked off %d%s" % [str(D.fuse), throws, int(b.cooked), (" · last cooked %.2f s" % float(b.lastCook)) if throws > 0 else ""], Vector2(W / 2.0, 14.0 * S), _fs(S, 8.0), Kit.DIM, true)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"aoe":
			var SQ: float = b.SQ
			var ZM: float = b.ZM
			var ex: float = b.ex
			var ez: float = b.ez
			var hx: float = b.hx
			var hz: float = b.hz
			var hurtT: float = b.hurtT
			var moving: bool = b.moving
			var active: bool = b.active
			var newest: int = b.newest
			var tgs: Array = b.tgs
			Kit.stage(n, b, 0.45)
			for i in 5:                                  # the floor's depth lines
				Kit.line(n, Vector2(0, GY + ZM * i / 4.0 * SQ), Vector2(W, GY + ZM * i / 4.0 * SQ), _al(Kit.INK, 0.07), 1.0)
			for i in tgs.size():
				var g: Dictionary = tgs[i]
				if not g.on or g.age < 0.0:
					continue
				var k: float = clampf(g.age / D.windup, 0.0, 1.0)
				var hitK: float = (g.age - D.windup) / 0.35 if g.age > D.windup else -1.0
				var full := _aoe_shape(b, g, 1.0)
				n.draw_colored_polygon(full, _al(Kit.HOT, 0.12))
				var outline := full.duplicate()
				outline.append(full[0])
				n.draw_polyline(outline, _al(Kit.HOT, 0.9 if hitK < 0.0 else 0.9 * (1.0 - hitK)), 1.2)
				if hitK < 0.0:                           # the fill is the clock
					if k > 0.01:
						n.draw_colored_polygon(_aoe_shape(b, g, k), _al(Kit.HOT, 0.38))
				else:
					n.draw_colored_polygon(full, Color(1.0, 1.0, 1.0, (1.0 - hitK) * 0.7))
				var lx: float = g.x if g.kind == "circle" else g.x + g.ax * W * D.range * 0.5
				var lz: float = g.z if g.kind == "circle" else g.z + g.az * W * D.range * 0.5
				var lp := Vector2(lx, GY + lz * SQ - 4.0)
				if i == newest and hitK < 0.0:
					Kit.text(n, "%d%%" % roundi(k * 100.0), lp, _fs(S, 8.0), Kit.HOT, true)
				if hitK >= 0.0 and g.res != "":
					Kit.text(n, g.res, lp, _fs(S, 9.0), Kit.HOT if g.res == "hit" else Kit.GOOD, true)
			var ey := GY + ez * SQ
			var hero_opts := { "face": b.face, "pose": "hurt" if hurtT > 0.0 else ("run" if moving else "stand"), "frame": t }
			var hero_p := Vector2(hx, GY + hz * SQ)
			if hz < ez:
				Kit.hero(n, b, hero_p, hero_opts)
			if active:                                   # the caster: a hooded shape, lit while a telegraph fills
				Kit.dot(n, Vector2(ex, ey), u * 4.0, _al(Kit.MAGIC, 0.25))
			Kit.ellipse(n, Vector2(ex, ey - u * 6.0), u * 3.6, u * 6.2, INK_DARK)
			Kit.dot(n, Vector2(ex - u * 1.2, ey - u * 9.0), u * 0.7, Kit.HOT if active else Kit.MAGIC)
			Kit.dot(n, Vector2(ex + u * 1.2, ey - u * 9.0), u * 0.7, Kit.HOT if active else Kit.MAGIC)
			Kit.line(n, Vector2(ex + u * 3.5, ey), Vector2(ex + u * 3.5, ey - u * 13.0), WOOD, maxf(1.0, u * 0.5))
			Kit.dot(n, Vector2(ex + u * 3.5, ey - u * 13.0), u * 1.1, Kit.HOT if active else Kit.MAGIC)
			if hz >= ez:
				Kit.hero(n, b, hero_p, hero_opts)
			if moving:
				var o: Vector2 = b.mdir
				Kit.line(n, hero_p, Vector2(hx + o.x * u * 5.0, GY + (hz + o.y * u * 5.0) * SQ), Kit.GOOD, 1.2)
			Kit.text(n, "hits %d · dodged %d" % [int(b.hits), int(b.dodged)], Vector2(6.0, 14.0 * S), _fs(S, 8.0), Kit.DIM)
			var cnt := int(D.count)
			_text_r(n, "windup %s s · react %s s · %s" % [str(D.windup), str(D.react), ("%d at once" % cnt) if cnt > 1 else str(D.shape)], Vector2(W - 6.0, 14.0 * S), _fs(S, 8.0), Kit.DIM)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"tell":
			var phase: String = b.phase
			var pt: float = b.pt
			var hx: float = b.hx
			var ex: float = b.ex
			var dodgeT: float = b.dodgeT
			var hurtT: float = b.hurtT
			var lastRes: String = b.lastRes
			var body := Color("6E4A8A")
			var leanA: float = b.leanA                   # the lean and the arm: where their springs have carried them (stepped in tick)
			var armA: float = b.armA
			var tintK: float = (1.0 if pt < 0.034 else 0.85) if phase == "tell" else 0.0
			var fill := body.lerp(Kit.HOT if D.tint == "red" else Color.WHITE, tintK) if tintK > 0.0 else body
			Kit.stage(n, b, 0.4)
			Kit.ground(n, b)
			var dk: float = 1.0 - dodgeT / D.dodgeLen if dodgeT > 0.0 else 1.0
			var hop := sin(PI * clampf(dk, 0.0, 1.0))
			var sx: float = b.sx
			if dodgeT > 0.0:
				Kit.ring(n, Vector2(hx, GY), u * 3.0, _al(Kit.GOOD, 0.5), 1.0)
			Kit.hero(n, b, Vector2(hx - hop * u * 7.0 + sx, GY - hop * u * 3.0), { "face": 1, "pose": "hurt" if hurtT > 0.0 else ("crouch" if dodgeT > 0.0 else "stand"), "frame": t })
			var xf := Transform2D(leanA, origin + Vector2(ex, GY))   # the enemy leans about its feet — where its spring has carried it
			n.draw_set_transform_matrix(xf)
			var legs := Kit.shade(body, -0.3)
			n.draw_rect(Rect2(-3.0 * u, -3.0 * u, 2.0 * u, 3.0 * u), legs)
			n.draw_rect(Rect2(u, -3.0 * u, 2.0 * u, 3.0 * u), legs)
			Kit.ellipse(n, Vector2(0.0, -8.0 * u), 4.5 * u, 6.0 * u, fill)
			n.draw_circle(Vector2(-1.6 * u, -9.5 * u), u * 0.9, Kit.HOT if tintK > 0.0 else Color.WHITE)
			n.draw_circle(Vector2(-1.9 * u, -9.5 * u), u * 0.45, Color("1A1020"))
			n.draw_set_transform_matrix(xf * Transform2D(armA, Vector2(-3.0 * u, -9.0 * u)))
			n.draw_rect(Rect2(-u * 0.7, 0.0, u * 1.4, 6.0 * u), fill)
			n.draw_rect(Rect2(-u * 1.3, 5.0 * u, u * 2.6, 3.0 * u), WOOD)
			n.draw_set_transform(origin, 0.0, Vector2.ONE)
			if phase == "tell":
				Kit.text(n, "tell %.2f / %s s" % [pt, str(D.tell)], Vector2(ex, GY - u * 17.0), _fs(S, 8.0), Kit.INK, true)
				Kit.text(n, "lean %.2f rad" % leanA, Vector2(ex, GY - u * 15.4), _fs(S, 7.0), Kit.DIM, true)
			if phase == "recover" and pt < 0.5:
				Kit.text(n, "hit!" if lastRes == "hit" else "miss", Vector2(hx + u * 2.0, GY - u * 19.0), _fs(S, 10.0), Kit.HOT if lastRes == "hit" else Kit.GOOD, true)
			var x0 := W * 0.08                           # the attack as a bar, and the dodge window under it
			var x1 := W * 0.92
			var y0 := 8.0 * S
			var total: float = D.tell + D.strike + D.recover
			var px := (x1 - x0) / total
			Kit.rect(n, Rect2(x0, y0, D.tell * px, 5.0 * S), _al(Kit.INK, 0.85))
			Kit.rect(n, Rect2(x0 + D.tell * px, y0, D.strike * px, 5.0 * S), Kit.HOT)
			Kit.rect(n, Rect2(x0 + (D.tell + D.strike) * px, y0, D.recover * px, 5.0 * S), _al(Kit.INK, 0.15))
			Kit.text(n, "tell", Vector2(x0, y0 + 14.0 * S), _fs(S, 7.0), Kit.DIM)
			Kit.text(n, "land", Vector2(x0 + (D.tell + D.strike) * px, y0 + 14.0 * S), _fs(S, 7.0), Kit.HOT, true)
			_text_r(n, "recover", Vector2(x1, y0 + 14.0 * S), _fs(S, 7.0), Kit.DIM)
			var ds: float = b.dodgeStart
			var ts: float = b.tellStart
			if ds > ts - 0.5 and ts > -1.0:
				var a := clampf(ds - ts, 0.0, total)
				var bb := clampf(ds - ts + D.dodgeLen, 0.0, total)
				if bb > a:
					Kit.rect(n, Rect2(x0 + a * px, y0 + 6.0 * S, (bb - a) * px, 3.0 * S), Kit.SUN if b.lastManual else Kit.GOOD)
			if phase != "idle":
				var rel: float = pt if phase == "tell" else (D.tell + pt if phase == "strike" else D.tell + D.strike + pt)
				var hxp := x0 + clampf(rel, 0.0, total) * px
				Kit.line(n, Vector2(hxp, y0 - 2.0), Vector2(hxp, y0 + 10.0 * S), Kit.INK, 1.0)
			var lastWhy: String = b.lastWhy
			var tail := (" · last: %s%s at +%.2f s" % [lastRes, (" (%s)" % lastWhy) if lastWhy != "" else "", float(b.lastAt)]) if lastRes != "" else ""
			Kit.text(n, "hits %d · dodged %d%s" % [int(b.hits), int(b.dodged), tail], Vector2(W / 2.0, y0 + 25.0 * S), _fs(S, 8.0), Kit.DIM, true)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
