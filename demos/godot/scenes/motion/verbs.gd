extends RefCounted

const Kit := preload("res://scenes/motion/kit.gd")
## PLATFORMER VERBS — thirteen movement styles, ported from the web lexicon
## (docs/locomotion.js, family `verbs`). The ledge, the ladder, the wall.
## A platformer is a small vocabulary of VERBS, and each verb is a state
## with its own gravity and its own exits: a ledge grab is two rays (chest
## blocked, head clear) and a scripted arc; a ladder switches gravity off
## and snaps x to the rail; a wall run is a timer that borrows the wall for
## gravity; a slide shrinks the hitbox and is not allowed to stand up under
## a beam; a dodge roll turns the hurtbox off for its middle third; a glide
## trades speed for lift until it stalls; a jetpack is thrust minus gravity
## while the tank lasts; water pushes up by the fraction under the surface;
## gravity is just a vector you may flip; a zipline, a minecart, a crumbling
## ledge and a bounce pad are all the same lesson — the designer chose the
## number, the physics obeyed.

const TITLE := "Platformer verbs"
const BLURB := "the ledge, the ladder, the wall — mantle, climb, wall-run, slide, roll, glide, jetpack, swim, flip gravity, zipline, minecart"
const DEFS := [
	{ "id": "mantle", "letter": "M", "name": "Mantle",
		"hint": "ledge grab: chest ray blocked, head ray clear → hands snap to the edge (Xmarks' rays), a scripted arc lifts the body — press to jump / mantle",
		"dials": { "g": 2.2,            # gravity, ×H per second²
			"jumpH": 0.2,               # a jump's apex, ×H
			"run": 0.3,                 # run speed, ×W per second
			"probe": 0.07,              # the rays' reach, ×W
			"hang": 0.5,                # seconds hung before the mantle starts
			"mantleT": 0.45,            # seconds the scripted arc takes
			"fromBelow": false,         # may the hands catch an edge while still rising?
			"steps": [0.14, 0.3, 0.5],  # ledge tops above the floor, ×H
			"label": "grab ⇔ chest ray hit ∧ head ray clear · then hang, then arc" },
		"rhyme": { "name": "Monkeybars", "hint": "the hands catch an edge even while rising, and the arc takes a third of the time — a climber, not a clamberer",
			"dials": { "fromBelow": true, "mantleT": 0.15, "hang": 0.2 } } },
	{ "id": "ladder", "letter": "L", "name": "Ladder",
		"hint": "ladder: up inside the rect snaps x to the rail and turns gravity off; a hop off the top (Grid's snap, one axis); a rope is the same rail on an angular spring the climber's weight and pulls swing — press above to climb, below to drop",
		"dials": { "g": 2.2,            # gravity, ×H per second²
			"climb": 0.22,              # climb speed, ×H per second
			"walk": 0.25,               # walk speed, ×W per second
			"hopV": 0.55,               # the little hop off the top, ×H per second
			"sway": 0,                  # 0 = a ladder (rigid: nothing the climber does moves it); 1 = a rope that swings
			"swayRate": 1.6,            # the rope's natural swing rate, radians per second (its k = swayRate²)
			"swayDamp": 0.35,           # its damping as a fraction of critical — under 1, so a let-go rope rings for a few swings before it hangs still
			"load": 0.25,               # the climber's weight, hung to one side: rad/s² of lean at the top of the rope, scaled by their height
			"pull": 0.15,               # each hand-over-hand pull shoves the rope sideways, rad/s, alternating sides
			"reach": 0.05,              # height climbed per pull, ×H
			"top": 0.22,                # the ladder's top, ×H
			"label": "in rect ∧ up ⇒ x = rail, g = 0, y −= climb·dt · top ⇒ hop · rope: θ'' = −k·θ − c·θ' + sway·(load·h + pulls)" },
		"rhyme": { "name": "Lianas", "hint": "the rail sways like a jungle rope and the climb is slow — the same mode, a different plant",
			"dials": { "sway": 1, "climb": 0.12, "swayRate": 1.2 } } },
	{ "id": "wallrun", "letter": "W", "name": "Wallrun",
		"hint": "wall run: airborne on a wall above a minimum speed, gravity ×wallG while a timer runs (Ninja's cling with a clock) — press to jump off along n̂",
		"dials": { "g": 2.2,            # gravity, ×H per second²
			"run": 0.42,                # run speed, ×W per second
			"minSpeed": 0.3,            # the speed the wall demands, ×W per second
			"wallG": 0.15,              # gravity's share during the run
			"runTime": 0.7,             # seconds the wall lends itself
			"kick": 0.5,                # the jump-off along the normal, ×W per second
			"jumpV": 0.7,               # the jump-off upward part, ×H per second
			"wall": 0.72,               # the wall's x, ×W
			"label": "on wall ∧ |v| > min ⇒ g·wallG while t < runTime · off: v = n̂·kick" },
		"rhyme": { "name": "Wuxia", "hint": "the wall holds for two full seconds with almost no gravity — a martial-arts film, running straight up",
			"dials": { "runTime": 2.0, "wallG": 0.03, "kick": 0.7 } } },
	{ "id": "kneel", "letter": "K", "name": "Kneel",
		"hint": "crouch & slide: the hitbox shrinks, speed decays under friction (Inertia's), standing is refused while a ceiling ray hits the beam — press to slide",
		"dials": { "run": 0.34,         # run speed, ×W per second
			"slideFriction": 0.28,      # speed lost per second, ×W per second²
			"crawl": 0.06,              # crawl speed under a beam, ×W per second
			"standH": 0.16,             # standing hitbox height, ×H
			"crouchH": 0.08,            # crouching hitbox height, ×H
			"tunnel": 0.28,             # the beam's length, ×W
			"beamY": 0.1,               # the gap under the beam, ×H (fits a crouch, not a stand)
			"label": "slide: v −= μ·dt · stand ⇔ ceiling ray clear" },
		"rhyme": { "name": "Kickslide", "hint": "a quarter of the friction and a tunnel twice as long — the slide crosses the whole room on its knees",
			"dials": { "slideFriction": 0.07, "tunnel": 0.5 } } },
	{ "id": "dodge", "letter": "D", "name": "Dodge",
		"hint": "dodge roll: a fixed-distance dash (Dash's), hurtbox OFF for the middle third (Iframes); recovery can't be cancelled — press to roll toward your click",
		"dials": { "dist": 0.26,        # the roll's length, ×W — fixed, not a velocity
			"dur": 0.5,                 # seconds the whole roll takes
			"startup": 0.15,            # the first phase, as a share of dur: hurtbox still on
			"invuln": 0.5,              # the middle share: hurtbox off — the rest is recovery
			"bulletSpeed": 0.5,         # bullets, ×W per second
			"bulletEvery": 1.1,         # seconds between bullets
			"label": "x += dist/dur · hurtbox off for k ∈ [startup, startup + invuln]" },
		"rhyme": { "name": "Dancer", "hint": "a short quick roll that is invulnerable for three quarters of it and recovers in a blink — the i-frames are the whole move",
			"dials": { "dist": 0.14, "dur": 0.3, "invuln": 0.8 } } },
	{ "id": "glide", "letter": "G", "name": "Glide", "drag": true,
		"hint": "a controllable glide: pitch sets the lift/drag mix on v² (Umbrella's drag, Kite's lift); too slow or too steep = STALL, nose drops — drag: y = pitch",
		"dials": { "g": 2.2,            # gravity, ×H per second²
			"lift": 20,                 # lift per radian of angle of attack, ×H/s² at 1 H/s
			"drag": 0.08,               # drag at zero pitch, ×H/s² at 1 H/s
			"dragK": 1.0,               # induced drag: how much pitching costs
			"maxAoA": 0.4,              # full pitch = this angle of attack, radians
			"stallAoA": 0.3,            # past this the wing stops working
			"stallV": 0.5,              # below this speed the wing stops working, ×H per second
			"stallDrop": 0.25,          # the lift that survives a stall
			"launchV": 0.8,             # the speed a fresh glider starts with, ×H per second
			"label": "L = lift·α·v² ⊥ v · Dr = (drag + dragK·α²)·v² ∥ −v · stall ⇒ L × stallDrop" },
		"rhyme": { "name": "Gull", "hint": "a wing with far more lift, less drag and a gentle stall that keeps most of it — long lazy soaring, forgiving of a heavy hand",
			"dials": { "lift": 30, "drag": 0.05, "stallDrop": 0.7 } } },
	{ "id": "jetpack", "letter": "J", "name": "Jetpack", "drag": true,
		"hint": "jetpack: thrust minus gravity while fuel > 0 (Rocket's exhaust), the tank refills on the ground; two arrows and a fuel bar — drag: hold to thrust",
		"dials": { "g": 2.2,            # gravity, ×H per second²
			"thrust": 3.6,              # upward acceleration while burning, ×H per second²
			"tank": 2.2,                # seconds of fuel in a full tank
			"refill": 1.6,              # seconds to refill from empty, on the ground
			"lean": 0.28,               # sideways push toward the pointer, ×W per second²
			"hoverY": 0.42,             # the autopilot's wanted height, ×H
			"label": "a = thrust − g while fuel > 0 · fuel −= dt · grounded: fuel += dt·tank/refill" },
		"rhyme": { "name": "Jumpjets", "hint": "three times the thrust from a tank a third the size that fills in a moment — bursts and drops, never a hover",
			"dials": { "thrust": 9, "tank": 0.6, "refill": 0.5 } } },
	{ "id": "underwater", "letter": "U", "name": "Underwater",
		"hint": "swimming: buoyancy pushes up by the SUBMERGED FRACTION (Yacht's), water drag, a bobbing surface — press below the surface to dive, above to leap",
		"dials": { "g": 2.2,            # gravity, ×H per second²
			"buoy": 3.2,                # buoyancy at full submersion, ×H per second² (float ⇔ buoy > g)
			"dragW": 2.6,               # water drag, per second
			"dragA": 0.15,              # air drag, per second
			"dive": 0.9,                # a dive's downward kick, ×H per second
			"leap": 0.85,               # a leap's upward kick, ×H per second
			"swim": 0.5,                # sideways swim, ×W per second²
			"surface": 0.42,            # the water's rest surface, ×H
			"wave": 0.012,              # the surface wave, ×H
			"bodyH": 0.1,               # the body's height, ×H — the fraction is measured on it
			"every": 2.4,               # seconds between the autopilot's dives and leaps
			"label": "f = submerged/bodyH · a = g − buoy·f · v ×= e^(−drag(f)·dt)" },
		"rhyme": { "name": "Uplift", "hint": "twice the buoyancy through thin water — a cork: it will not stay down, and pops clear of the surface every time",
			"dials": { "buoy": 6.5, "dragW": 1.2, "leap": 0.4 } } },
	{ "id": "gravity", "letter": "G", "name": "Gravity",
		"hint": "gravity as a VECTOR: feet face −g, floor and ceiling both catch (Normals); 'flip' (VVVVVV) or 'planet' (Magnet) — press to flip / place the planet",
		"dials": { "mode": "flip",      # "flip": g points up or down · "planet": g points at a centre
			"g": 2.0,                   # gravity's size, ×H per second²
			"run": 0.28,                # run speed along whatever is the floor, ×W per second
			"every": 1.7,               # seconds between the autopilot's flips (or hops)
			"hop": 0.55,                # a planet hop, ×H per second, straight up from the surface
			"planetR": 0.14,            # the planet's radius, ×H
			"ceiling": 0.12,            # the room's ceiling, ×H
			"label": "a = g⃗ · up = −g⃗/|g⃗| · body rotated so its feet face g⃗" },
		"rhyme": { "name": "Gravitywell", "hint": "the same body on a little planet with a third of the gravity — every hop becomes a low orbit skimming the surface",
			"dials": { "mode": "planet", "g": 0.7, "hop": 0.62 } } },
	{ "id": "zipline", "letter": "Z", "name": "Zipline",
		"hint": "zipline / rail grind: lock to a path (Path's), speed integrates the slope (g along the tangent), let go with that velocity — press to let go / grab",
		"dials": { "g": 2.2,            # gravity, ×H per second²
			"friction": 0.18,           # speed lost per second, as a share
			"y0": 0.16, "y1": 0.5,      # the rail's two ends, ×H
			"sag": 0.1,                 # how far the middle droops, ×H
			"waves": 0,                 # ripples along the rail (0 = a plain sag)
			"waveAmp": 0.05,            # the ripples' height, ×H
			"attachV": 0.05,            # the speed a fresh grab starts with, ×W per second
			"rideT": 2.2,               # seconds the autopilot hangs on before dropping
			"reach": 0.09,              # how near the rail a hand can grab it, ×H
			"label": "on rail: v̇ = g·t̂ᵧ − μv · p += v·t̂·dt · let go: v⃗ = v·t̂" },
		"rhyme": { "name": "Zigrail", "hint": "a rippled rail with almost no friction and a running start — a grind that rocks back through every valley, both ways",
			"dials": { "waves": 3, "friction": 0.03, "attachV": 0.45 } } },
	{ "id": "minecart", "letter": "M", "name": "Minecart",
		"hint": "minecart: a track of humps, v += g·sin θ·dt (Path's arc, a real force) — hills slow it, dips speed it, a push station keeps it looping — press to push",
		"dials": { "g": 2.2,            # gravity, ×H per second²
			"humps": 2,                 # humps across the loop
			"amp": 0.09,                # a hump's half-height, ×H
			"base": 0.5,                # the track's mean height, ×H
			"friction": 0.12,           # speed lost per second, as a share
			"push": 0.42,               # the station's shove, ×W per second
			"label": "v̇ = g·sin θ − μv · θ = slope of the track · x += v·cos θ·dt" },
		"rhyme": { "name": "Mineshaft", "hint": "humps nearly twice as steep and rails four times as rough — the cart rocks in the dip for two or three shoves before it crests",
			"dials": { "amp": 0.16, "friction": 0.45, "push": 0.5 } } },
	{ "id": "brittle", "letter": "B", "name": "Brittle",
		"hint": "a crumbling platform: stand → SHAKE (Jitter's) → fall → fade → RESPAWN after N s; three timers, Platform's rider hops across — press to shake one",
		"dials": { "g": 2.2,            # gravity, ×H per second²
			"stand": 0.9,               # seconds a platform holds before it falls
			"mult": [0.6, 1, 1.6],      # each platform's share of that time: quick, normal, patient
			"respawn": 2.5,             # seconds gone before it comes back
			"fade": 0.9,                # seconds the fall takes to fade out
			"hopClear": 0.08,           # how far above its target a hop's apex sits, ×H
			"platW": 0.16,              # a platform's width, ×W
			"platY": 0.5,               # the platforms' height, ×H
			"label": "stand → shake t < stand·k → fall: vy += g → α → 0 → respawn after N s" },
		"rhyme": { "name": "Bulwark", "hint": "platforms that hold for two and a half seconds and take six to come back — the Mario kind, stern about second chances",
			"dials": { "stand": 2.5, "respawn": 6, "fade": 0.5 } } },
	{ "id": "bouncepad", "letter": "B", "name": "Bouncepad", "drag": true,
		"hint": "a bounce pad assigns a FIXED velocity √(2gh) for a DESIGNED apex (Jump's) with Slime's squash; beside it restitution decays — drag: y sets the apex",
		"dials": { "g": 2.2,            # gravity, ×H per second²
			"apex": 0.55,               # the designed apex, as a share of the room above the pad
			"e": 0.72,                  # the honest floor's restitution, for comparison
			"drop": 0.85,               # both balls start this high, share of the room
			"squash": 1,                # how theatrical the squash is
			"squashT": 0.16,            # seconds the squash lasts
			"padW": 0.16,               # the pad's width, ×W
			"label": "pad: vy = −√(2·g·h), h chosen · floor: vy = −e·vy, apex ×e² per bounce" },
		"rhyme": { "name": "Boing", "hint": "the apex almost at the ceiling and a squash three times as theatrical — the cartoon spring, the same one line of maths",
			"dials": { "apex": 0.9, "squash": 3 } } },
]

const R := 8.0                                       # the mote's radius, every card's body

# ---- shared helpers ----
static func _a(c: Color, alpha: float) -> Color:     # the web's "rgba(…, a)": a kit colour with its own alpha
	return Color(c, alpha)

static func _or1(x: float) -> float:                 # the web's `x || 1`
	return x if x != 0.0 else 1.0

static func _num(v: float) -> String:                # a dial in a label, the way JS prints it: 2 not 2.0, 0.15 as is
	return str(int(v)) if v == floorf(v) else str(v)

## The web kit's ease(k): clamp, then smoothstep.
static func _ease(k: float) -> float:
	var kk := clampf(k, 0.0, 1.0)
	return kk * kk * (3.0 - 2.0 * kk)

## The web label's "right" alignment — Kit.label only knows left and centre.
static func _label_right(n: CanvasItem, b: Dictionary, txt: String, p: Vector2, col: Color) -> void:
	var f := ThemeDB.fallback_font
	var w: float = f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	Kit.label(n, b, txt, Vector2(p.x - w, p.y), col)

## A dashed line (the web's setLineDash), drawn as short segments.
static func _dashed(n: CanvasItem, a: Vector2, c: Vector2, dash: float, gap: float, col: Color, w: float = 1.0) -> void:
	var d := a.distance_to(c)
	if d < 0.5:
		return
	var u := (c - a) / d
	var s0 := 0.0
	while s0 < d:
		var s1 := minf(d, s0 + dash)
		n.draw_line(a + u * s0, a + u * s1, col, w)
		s0 += dash + gap

## A dashed rectangle outline (the web's setLineDash + strokeRect).
static func _dash_rect(n: CanvasItem, r: Rect2, dash: float, gap: float, col: Color, w: float = 1.0) -> void:
	var p0 := r.position
	var p1 := r.position + Vector2(r.size.x, 0)
	var p2 := r.end
	var p3 := r.position + Vector2(0, r.size.y)
	_dashed(n, p0, p1, dash, gap, col, w)
	_dashed(n, p1, p2, dash, gap, col, w)
	_dashed(n, p2, p3, dash, gap, col, w)
	_dashed(n, p3, p0, dash, gap, col, w)

## The mote drawn through an arbitrary transform (the web's
## ctx.translate/rotate/scale round mote(0, 0, ang)): a mirror or a squash
## that Kit.mote's (position, angle) cannot express. Restores the card offset.
static func _mote_xf(n: CanvasItem, b: Dictionary, xf: Transform2D, ang: float, col: Color = Kit.MOVER, s: float = R) -> void:
	var origin: Vector2 = (b.rect as Rect2).position
	n.draw_set_transform_matrix(Transform2D(0.0, origin) * xf * Transform2D(ang, Vector2.ZERO))
	n.draw_circle(Vector2.ZERO, s, col)
	n.draw_colored_polygon(PackedVector2Array([
		Vector2(s * 0.45, -s * 0.6), Vector2(s * 1.5, 0), Vector2(s * 0.45, s * 0.6)]), col)
	n.draw_circle(Vector2(s * 0.38, -s * 0.3), s * 0.22, Kit.NIGHT)
	n.draw_set_transform(origin, 0.0, Vector2.ONE)

# ---- Mantle: the ledges, the rays, the jump ----
static func _m_floor_at(b: Dictionary, px: float) -> float:
	var f: float = b.gy
	for l: Dictionary in b.L:
		if px >= l.x:
			f = l.top
	return f

static func _m_wall_ahead(b: Dictionary, px: float, py: float, reach: float) -> Dictionary:   # the first ledge face this ray crosses, or none
	for l: Dictionary in b.L:
		if px < l.x and px + reach >= l.x and py > l.top:
			return l
	return {}

static func _m_jump(b: Dictionary) -> void:
	var D: Dictionary = b.D
	b.vy = -sqrt(2.0 * b.h * D.g * b.h * D.jumpH)
	b.state = "air"

# ---- Ladder: the rail's x at a height (a rope bends it) ----
static func _l_rail_x(b: Dictionary, py: float) -> float:   # the rail at height py: the hinge is at the ground
	var lx: float = b.w * 0.5
	return lx + sin(float(b.th)) * (b.gy - py)

# ---- Dodge: begin a roll, unless recovering ----
static func _d_roll(b: Dictionary, d: int) -> void:
	var D: Dictionary = b.D
	if b.rolling:
		if b.k > D.startup + D.invuln:               # recovery: no cancel
			b.refused = 0.4
		return
	b.rolling = true
	b.k = 0.0
	b.dir = d
	b.x0 = b.x
	var x0: float = b.x0
	if x0 + d * b.w * D.dist < R * 2.0 or x0 + d * b.w * D.dist > b.w - R * 2.0:
		b.dir = -d

# ---- Glide: throw it again ----
static func _g_launch(b: Dictionary) -> void:
	var D: Dictionary = b.D
	b.y = b.h * 0.25
	b.vx = b.h * D.launchV
	b.vy = 0.0
	b.launched = 0.8

# ---- Underwater: the wavy waterline, the splash rings ----
static func _u_surface(b: Dictionary, px: float, t: float) -> float:
	var D: Dictionary = b.D
	return b.h * D.surface + sin(t * 2.1 + px / b.w * 7.0) * b.h * D.wave + sin(t * 1.3 - px / b.w * 4.0) * b.h * D.wave * 0.6

static func _u_splash(b: Dictionary, sx: float, sy: float) -> void:
	for r: Dictionary in b.rings:
		if r.life <= 0.0:
			r.x = sx
			r.y = sy
			r.r = 3.0
			r.life = 0.7
			return

# ---- Gravity: negate the vector ----
static func _gv_flip(b: Dictionary) -> void:
	b.gdy = -b.gdy
	b.flash = 0.5
	b.grounded = false

# ---- Zipline: the rail, its tangent, the two hand-offs ----
static func _z_rail_y(b: Dictionary, px: float) -> float:
	var D: Dictionary = b.D
	var s0: float = clampf(px / b.w, 0.0, 1.0)
	var wv: float = D.waves
	return b.h * (D.y0 + (D.y1 - D.y0) * s0 + D.sag * 4.0 * s0 * (1.0 - s0) + D.waveAmp * sin(s0 * wv * TAU) * (1.0 if wv != 0.0 else 0.0))

static func _z_tangent(b: Dictionary, px: float) -> void:
	var dy := (_z_rail_y(b, px + 2.0) - _z_rail_y(b, px - 2.0)) / 4.0
	var L := sqrt(1.0 + dy * dy)
	b.tx = 1.0 / L
	b.ty = dy / L

static func _z_let_go(b: Dictionary) -> void:
	b.vx = b.v * b.tx
	b.vy = b.v * b.ty
	b.state = "free"
	b.timer = 0.0
	b.flash = 0.5

static func _z_grab(b: Dictionary) -> void:
	_z_tangent(b, b.x)
	b.v = b.vx * b.tx + b.vy * b.ty
	b.y = _z_rail_y(b, b.x) + R
	b.state = "ride"
	b.timer = 0.0
	b.flash = 0.5

# ---- Minecart: the track's height at x ----
static func _mc_track_y(b: Dictionary, px: float) -> float:
	var D: Dictionary = b.D
	return b.h * D.base + sin(px / b.w * D.humps * TAU) * b.h * D.amp

# ---- Brittle: rise hopClear above the target, then solve the flight time T ----
static func _b_hop_to(b: Dictionary, tx: float, ty: float) -> void:
	var D: Dictionary = b.D
	var G: float = b.h * D.g
	var up: float = maxf(0.0, b.y - ty) + b.h * D.hopClear
	var v0 := -sqrt(2.0 * G * up)
	var disc: float = maxf(0.0, v0 * v0 + 2.0 * G * (ty - b.y))
	var T: float = maxf(0.05, (-v0 + sqrt(disc)) / G)   # v₀T + ½gT² = Δy
	b.vx = (tx - b.x) / T
	b.vy = v0
	b.state = "air"
	b.on = -1

static func init(b: Dictionary) -> void:
	var D: Dictionary = b.D
	match b.id:
		"mantle":
			# a LEDGE GRAB is two raycasts and a promise. every frame the body casts a
			# short ray forward at chest height and another at head height; when the
			# chest ray hits a wall but the head ray sails over it, there is an edge
			# right there, and the hands snap to it. the body then HANGS (gravity off,
			# a timer), and the MANTLE is not physics at all: a scripted arc that
			# lifts the body up and over in a fixed time. Grapple's hook was the same
			# idea — find the point, then own it — and a tall ledge is simply one
			# the head ray also hits: refused, so the mote must jump for it.
			var steps: Array = D.steps
			b.L = []                                     # the ledges: x where each starts, its top
			for i in steps.size():
				b.L.append({ "x": b.w * (0.28 + i * 0.22), "top": b.gy - b.h * float(steps[i]) })
			b.x = b.w * 0.08
			b.y = b.gy - R
			b.vy = 0.0
			b.flr = b.gy
			b.state = "run"
			b.tm = 0.0
			b.hx = 0.0
			b.hy = 0.0
			b.sx = 0.0
			b.sy = 0.0
			b.refused = 0.0
			b.chestHit = false
			b.headHit = false
		"ladder":
			# a LADDER is a rectangle and a mode. inside the rectangle, pressing up
			# ENTERS the mode: x snaps to the rail (the way Grid snaps to a cell, but
			# on one axis only), gravity is switched off, and up/down move y at a
			# fixed climb speed. leaving happens three ways: walk off the side, drop
			# (gravity back on), or reach the top, where a small scripted hop puts
			# the feet on the platform so the body never pops through it. a ROPE is
			# the same mode with the rail on a hinge: one angle θ from vertical,
			# rooted at the ground, on Upright's spring (α = −k·θ − c·ω, k from
			# swayRate) — and what swings it is the CLIMBER: their weight hangs to
			# one side, a torque that grows with their height, and every pull up
			# shoves it the other way. let go and the load vanishes: the rope
			# springs back and rings, under-damped, long after the climber has gone.
			# the climber's x follows the rail, so a rope you climb swings because
			# you are on it.
			b.x = b.w * 0.1
			b.y = b.gy - R
			b.vy = 0.0
			b.dir = 1
			b.state = "walk"
			b.want = 0                                   # want: +1 up, −1 down
			b.th = 0.0                                   # the rope's angle and rate
			b.om = 0.0
			b.climbed = 0.0                              # height climbed since the last pull, and which hand pulls next
			b.side = 1.0
		"wallrun":
			# the WALL RUN is a timer that borrows the wall for gravity. Ninja clung
			# and slid; here the body must arrive FAST — a speed below minSpeed just
			# slides — and when it does, gravity is multiplied by wallG for runTime
			# seconds and the forward speed is turned up the wall. the timer is the
			# whole design: while it runs the body climbs, when it ends gravity is
			# handed back and the fall begins. the jump off leaves ALONG THE NORMAL
			# — the wall's outward direction — plus a fixed upward part, so the
			# player cannot steer it, only time it.
			b.x = b.w * 0.15
			b.y = b.gy - R
			b.vx = 0.0
			b.vy = 0.0
			b.state = "run"
			b.tm = 0.0
			b.flash = 0.0
			b.back = false
			b.ldt = 1.0 / 60.0                           # the last dt, for the air trail (draw has no dt)
		"kneel":
			# CROUCH shrinks the hitbox; SLIDE is a crouch that keeps the run's
			# speed and lets friction eat it (Inertia's decay, with a knee on the
			# floor). the rule beginners forget: standing up is a collision test —
			# a ray from the body to full height must be CLEAR, or the head would
			# pop into the beam. while the ray hits, standing is refused and the
			# body crawls; the moment it clears, the body pops up and runs on.
			b.x = b.w * 0.05
			b.v = 0.0
			b.state = "run"
			b.refused = 0.0
			b.rayHit = false
		"dodge":
			# a DODGE ROLL is Dash with a calendar. the distance is fixed and so is the
			# time, which splits into three PHASES: STARTUP (the body is still there to
			# be hit), INVULNERABLE (the hurtbox is switched off — bullets pass through
			# the picture of the body), and RECOVERY (the hurtbox is back and no new
			# roll may begin: that is the price of the dodge). the bar over the mote
			# is the roll's clock; the box round the body is the hurtbox, dashed while
			# it is off. bullets fly in from the sides; the autopilot rolls through
			# the ones it sees coming, and sometimes mistimes on purpose.
			b.bullets = []
			for _i in 6:
				b.bullets.append({ "x": 0.0, "y": 0.0, "vx": 0.0, "on": false, "through": false })
			b.x = b.w * 0.5
			b.dir = 1
			b.rolling = false
			b.k = 0.0
			b.x0 = 0.0
			b.spawnT = 0.4
			b.side = 1
			b.flash = 0.0
			b.refused = 0.0
			b.hits = 0
			b.dodged = 0
			b.late = 0
			b.hurt = true
		"glide":
			# a GLIDE is a fall with a wing on it. two forces grow with the SQUARE of
			# the speed: LIFT, perpendicular to the velocity and proportional to the
			# ANGLE OF ATTACK (the pitch you hold), and DRAG, straight back along it.
			# pitch up and lift grows — but so does induced drag, and the speed bleeds
			# away; pitch past the stall angle, or let the speed fall under stallV,
			# and the wing STALLS: most of the lift vanishes and gravity turns the
			# velocity downward, which is the nose dropping. the world scrolls under
			# a glider that stays at one x; the pointer's height is the pitch.
			b.y = b.h * 0.3
			b.vx = b.h * D.launchV
			b.vy = 0.0
			b.pitch = 0.0
			b.want = 0.0
			b.idle = 9.0
			b.scroll = 0.0
			b.stalled = false
			b.speed = 0.0
			b.aoa = 0.0
			b.liftA = 0.0
			b.dragA = 0.0
			b.launched = 0.0
			b.ux = 1.0                                   # along the velocity, kept for draw
			b.uy = 0.0
		"jetpack":
			# a JETPACK is Rocket's thrust with a budget. every second of burn spends
			# a second of FUEL; the acceleration is thrust upward minus gravity down,
			# and the two arrows show which one is winning. an empty tank hands the
			# body to gravity, and the tank only REFILLS on the ground, at its own
			# rate — so the verb has a rhythm: burn, fall, land, wait. the autopilot
			# hovers bang-bang around the dashed line, pulsing the burn on and off;
			# your pointer takes over the throttle and leans the body toward its x.
			b.puffs = []
			for _i in 40:
				b.puffs.append({ "x": 0.0, "y": 0.0, "vx": 0.0, "vy": 0.0, "life": 0.0 })
			b.x = b.w * 0.5
			b.y = b.gy - R
			b.vx = 0.0
			b.vy = 0.0
			b.fuel = float(D.tank)
			b.held = 0.0
			b.idle = 9.0
			b.leanX = 0.0
			b.burning = false
			b.grounded = true
			b.empty = 0.0
			b.rest = false
		"underwater":
			# BUOYANCY is gravity's mirror: an upward push proportional to how much
			# of the body is under the surface — the SUBMERGED FRACTION f, read off
			# the body's height against the wavy waterline. with buoy > g the body
			# sinks until g = buoy·f and floats there, bobbing as the wave changes f
			# under it (Yacht's trick). drag is blended by f too, thick in water and
			# thin in air, so a leap is fast and a dive is smothered. rings mark each
			# crossing of the surface; the autopilot dives and leaps on a timer.
			b.rings = []
			for _i in 6:
				b.rings.append({ "x": 0.0, "y": 0.0, "r": 0.0, "life": 0.0 })
			b.x = b.w * 0.5
			b.y = b.h * D.surface
			b.vx = 0.0
			b.vy = 0.0
			b.wantX = b.w * 0.5
			b.timer = 1.2
			b.f = 0.0
			b.wasUnder = false
			b.phase = 0
		"gravity":
			# most games hide gravity inside "vy += g·dt". write it as a VECTOR and
			# two verbs fall out for free. FLIP: negate it, and the ceiling becomes
			# the floor — the body must be drawn with its feet toward g, so it walks
			# upside down (Normals' up-vector, chosen by the designer). PLANET: aim it
			# at a centre, |g| along the unit vector to it, and the body walks round a
			# little world, hops straight "up" (radially), and with a weak enough g
			# a hop turns into an orbit (Magnet's pull, felt from the inside).
			b.x = b.w * 0.3
			b.y = b.gy - R
			b.vx = 0.0
			b.vy = 0.0
			b.gdx = 0.0                                  # the gravity direction (b.gy is the ground line)
			b.gdy = 1.0
			b.dir = 1
			b.timer = 1.0
			b.grounded = true
			b.cx = b.w * 0.5
			b.cyp = b.h * 0.48
			b.flash = 0.0
			b.trail = []
			for _i in 60:
				b.trail.append(Vector2.ZERO)
			b.ti = 0
			b.tn = 0
		"zipline":
			# a ZIPLINE is a one-dimensional world. while attached the body has one
			# number, its speed along the rail, and the only physics is gravity's
			# shadow on the local TANGENT: a downhill tangent has a positive y part
			# and speeds you up, an uphill one slows you, a valley rocks you back and
			# forth (Path's arc-length, with a real force on it). LETTING GO is the
			# honest part: the velocity you leave with is that speed times the
			# tangent, so a fast drop from a steep bit flies far. a rail grind is
			# the same card with the body on top instead of hanging under.
			b.x = b.w * 0.02
			b.y = _z_rail_y(b, b.w * 0.02) + R
			b.v = b.w * D.attachV
			b.vx = 0.0
			b.vy = 0.0
			b.state = "ride"
			b.timer = 0.0
			b.tx = 1.0
			b.ty = 0.0
			b.gAlong = 0.0
			b.flash = 0.0
			b.trail = []
			for _i in 40:
				b.trail.append(Vector2.ZERO)
			b.ti = 0
			b.tn = 0
		"minecart":
			# a MINECART is one number on a curve. the track gives every x a height
			# and therefore a SLOPE θ; gravity's share along the rails is g·sin θ —
			# positive going downhill, negative climbing — and that is the whole
			# engine (Path's arc-length parameter, pushed by physics instead of a
			# clock). a hump the cart cannot crest sends it rolling back to rock in
			# the dip until the PUSH STATION at the bottom shoves it again; Elevator
			# moved a rider on a schedule, this one is moved by the shape of the ground.
			var humps: float = maxf(1.0, float(D.humps))
			var station := 0.0
			var best := -1.0
			for i in 64:                                 # the lowest point of the first dip
				var px: float = b.w * i / 64.0 / humps
				if _mc_track_y(b, px) > best:
					best = _mc_track_y(b, px)
					station = px
			b.station = station
			b.period = b.w / humps                       # one station per dip: the same spot, every period
			b.x = station - b.w * 0.05
			b.v = 0.0
			b.tx = 1.0
			b.ty = 0.0
			b.gAlong = 0.0
			b.flash = 0.0
			b.pushed = 0
			b.lastSeg = 0
		"brittle":
			# a CRUMBLING platform is a small state machine with a body inside it.
			# IDLE until a foot lands; then SHAKE — Jitter's random offset, growing
			# as the timer runs out, the warning the player reads; then FALL, a real
			# body now, vy += g, fading as it goes; then GONE, an outline and a
			# countdown, and after the respawn time it POPS back. three platforms
			# share one recipe with three timers, so the hop across is a rhythm to
			# learn: the quick one gives you no time at all, the patient one lets
			# you wait. the rider is Platform's, landing from above only.
			var py: float = b.h * D.platY
			var mult: Array = D.mult
			b.P = []
			for i in 3:
				b.P.append({ "x": b.w * (0.2 + i * 0.3), "y": py, "vy": 0.0, "state": "idle", "tm": 0.0,
					"jx": 0.0, "jy": 0.0, "hold": D.stand * float(mult[i]) })
			b.x = b.w * 0.06
			b.y = b.gy - R
			b.vx = 0.0
			b.vy = 0.0
			b.on = -1
			b.state = "walk"
			b.tm = 0.0
		"bouncepad":
			# two ways to bounce. RESTITUTION is honest physics: the floor hands back
			# a share e of the speed it was hit with, so every apex is e² of the last
			# and the ball dies down. a BOUNCE PAD is a designer's lie: it ignores the
			# incoming speed and ASSIGNS the launch velocity — Jump's v₀ = √(2gh) run
			# backward from the apex the level needs — so the ball reaches the same
			# dashed line every time, however it arrived. the squash is Slime's:
			# width up, height down, springing back over a few frames.
			var room: float = b.gy - 12.0
			b.apex = float(D.apex)
			b.ly = b.gy - room * D.drop
			b.lvy = 0.0
			b.ry = b.gy - room * D.drop
			b.rvy = 0.0
			b.lsq = 0.0
			b.rsq = 0.0
			b.rTop = b.gy - room * D.drop
			b.rTopNext = b.gy - room * D.drop
			b.lv0 = 0.0

static func press(b: Dictionary, pos: Vector2) -> void:
	var D: Dictionary = b.D
	match b.id:
		"mantle":
			if b.state == "hang":
				b.state = "mantle"
				b.tm = 0.0
				b.sx = b.x
				b.sy = b.y
			elif b.state == "run":
				_m_jump(b)
		"ladder":
			var lx: float = b.w * 0.5
			var half: float = b.w * 0.05
			if b.state == "climb":
				if pos.y > b.y:
					b.state = "fall"
					b.vy = 0.0
			elif pos.y < b.y and absf(b.x - lx) < half + R:
				b.state = "climb"
				b.want = 1
		"wallrun":
			if b.state == "wallrun" or b.state == "slide":
				b.vx = -b.w * D.kick                     # along the normal (−x), plus up
				b.vy = -b.h * D.jumpV
				b.state = "air"
				b.flash = 0.5
			elif b.state == "run":
				b.vy = -b.h * 0.5
				b.state = "air"
		"kneel":
			if b.state == "run":
				b.state = "slide"
				b.v = b.w * D.run
		"dodge":
			_d_roll(b, -1 if pos.x < b.x else 1)
		"glide":
			b.want = clampf(1.0 - 2.0 * pos.y / b.h, -1.0, 1.0)
			b.idle = 0.0
		"jetpack":
			b.held = 0.07
			b.idle = 0.0
			b.leanX = pos.x
		"underwater":
			b.wantX = pos.x
			if pos.y > _u_surface(b, pos.x, 0.0):        # below the line: dive
				b.vy += b.h * D.dive
				b.phase = 1
			elif b.f > 0.25:                             # above it, and afloat: leap
				b.vy = -b.h * D.leap
				b.phase = 0
		"gravity":
			if D.mode == "planet":
				b.cx = pos.x
				b.cyp = pos.y
				b.flash = 0.5
			else:
				_gv_flip(b)
		"zipline":
			if b.state == "ride":
				_z_let_go(b)
			elif b.state == "free" and absf(b.y - R - _z_rail_y(b, b.x)) < b.h * D.reach:
				_z_grab(b)
			elif b.state == "walk" or b.state == "climb":
				b.vy = -b.h * 0.75
				b.vx = 0.0
				b.state = "free"
				b.timer = 0.0
		"minecart":
			b.v += (1.0 if b.v >= 0.0 else -1.0) * b.w * D.push
			b.flash = 0.5
			b.pushed += 1
		"brittle":
			var P: Array = b.P
			var bi := 0
			for i in range(1, 3):
				if absf(P[i].x - pos.x) < absf(P[bi].x - pos.x):
					bi = i
			var p: Dictionary = P[bi]
			if p.state == "idle" or p.state == "shake":
				p.state = "shake"
				p.tm = maxf(p.tm, p.hold * 0.65)
		"bouncepad":
			var room: float = b.gy - 12.0
			b.apex = clampf((b.gy - pos.y) / room, 0.08, 0.95)

static func tick(b: Dictionary, dt: float, t: float) -> void:
	var D: Dictionary = b.D
	match b.id:
		"mantle":
			var reach: float = b.w * D.probe
			var st: String = b.state
			if st == "run" or st == "air":
				b.x += b.w * D.run * dt
				b.vy += b.h * D.g * dt
				b.y += b.vy * dt
				b.flr = _m_floor_at(b, b.x + R)
				var face := _m_wall_ahead(b, b.x + R, b.y, 0.0)   # pressed against a face: stop
				if not face.is_empty() and b.y + R > face.top:
					b.x = face.x - R
				if b.y >= b.flr - R:
					b.y = b.flr - R
					b.vy = 0.0
					b.state = "run"
				else:
					b.state = "air"
				var chest := _m_wall_ahead(b, b.x + R, b.y - R * 0.3, reach)
				var head := _m_wall_ahead(b, b.x + R, b.y - R * 2.2, reach)
				b.chestHit = not chest.is_empty()
				b.headHit = not head.is_empty()
				if not chest.is_empty() and head.is_empty() and (b.vy >= 0.0 or D.fromBelow):   # the grab
					b.state = "hang"
					b.tm = 0.0
					b.hx = chest.x
					b.hy = chest.top
					b.vy = 0.0
					b.x = b.hx - R
					b.y = b.hy + R * 0.9
				elif not chest.is_empty() and not head.is_empty():   # too tall for the hands: refused, jump instead
					b.refused = 0.4
					if b.state == "run":
						_m_jump(b)
			elif st == "hang":
				b.tm += dt
				if b.tm >= D.hang:
					b.state = "mantle"
					b.tm = 0.0
					b.sx = b.x
					b.sy = b.y
			elif st == "mantle":
				b.tm += dt
				var k: float = clampf(b.tm / D.mantleT, 0.0, 1.0)   # the scripted arc: up first, then over
				b.y = lerpf(b.sy, b.hy - R, _ease(minf(1.0, k * 1.6)))
				b.x = lerpf(b.sx, b.hx + R * 1.2, _ease(maxf(0.0, (k - 0.35) / 0.65)))
				if k >= 1.0:
					b.state = "run"
					b.vy = 0.0
			if b.x > b.w + R:
				b.x = -R
				b.y = b.gy - R
				b.vy = 0.0
				b.state = "run"
			b.refused = maxf(0.0, b.refused - dt)
		"ladder":
			var lx: float = b.w * 0.5
			var topY: float = b.h * D.top
			var platX: float = lx + b.w * 0.05              # the platform the top exits onto
			var st: String = b.state
			if st == "walk":
				b.x += b.dir * b.w * D.walk * dt
				if b.dir > 0 and absf(b.x - lx) < b.w * D.walk * dt + 1.0 and b.y > b.gy - R - 1.0:   # the autopilot presses up
					b.x = lx
					b.state = "climb"
					b.want = 1
				if b.x > b.w - R and b.y < b.gy - R - 1.0:   # walks off the platform's end
					b.state = "fall"
					b.vy = 0.0
				if b.x > b.w + R:
					b.x = -R
					b.y = b.gy - R
					b.dir = 1
				if b.x < R:
					b.dir = 1
			elif st == "climb":
				var dy: float = b.want * b.h * D.climb * dt
				b.y -= dy
				b.climbed += absf(dy)
				if b.climbed > b.h * float(D.reach):         # a pull: the weight shifts to the other hand
					b.climbed = 0.0
					b.side = -b.side
					b.om += float(D.sway) * float(D.pull) * b.side
				b.x = _l_rail_x(b, b.y)                      # the snap, every frame — to wherever the rope is now
				if b.y - R < topY:
					b.state = "hop"
					b.vy = -b.h * D.hopV
			elif st == "hop":
				b.vy += b.h * D.g * dt
				b.y += b.vy * dt
				b.x += b.w * D.walk * dt
				if b.vy > 0.0 and b.x > platX and b.y >= topY - R:
					b.y = topY - R
					b.state = "walk"
					b.dir = 1
				if b.y > b.gy - R:
					b.y = b.gy - R
					b.state = "walk"
			elif st == "fall":
				b.vy += b.h * D.g * dt
				b.y += b.vy * dt
				if b.y >= b.gy - R:
					b.y = b.gy - R
					b.vy = 0.0
					b.state = "walk"
					b.dir = 1
			# the rope's hinge: Upright's spring on θ, loaded by the climber while
			# they hang on it (their weight to one side, a torque that grows with
			# their height up the rope). sway = 0 leaves k·θ = 0 and no load: a
			# ladder. a coarse frame is cut into substeps of at most 0.02 s
			var rate: float = D.swayRate
			var k: float = rate * rate
			var c: float = 2.0 * float(D.swayDamp) * sqrt(k)
			var hf: float = clampf((b.gy - b.y) / (b.gy - topY), 0.0, 1.0) if b.state == "climb" else 0.0   # how far up the rope the load hangs
			var drive: float = float(D.sway) * float(D.load) * hf
			var th: float = b.th
			var om: float = b.om
			var sub := maxi(1, ceili(dt * 50.0))
			var h := dt / float(sub)
			for _s in sub:
				om += (-k * th - c * om + drive) * h
				th += om * h
				if th > 0.6:                                 # a rope can only lean so far before it is a slide
					th = 0.6
					om = minf(0.0, om)
				if th < -0.6:
					th = -0.6
					om = maxf(0.0, om)
			b.th = th
			b.om = om
		"wallrun":
			var wx: float = b.w * D.wall
			var st: String = b.state
			b.ldt = dt
			if st == "run":
				if b.back:
					b.x -= b.w * D.run * dt
					if b.x < b.w * 0.15:
						b.back = false
				else:
					b.vx = b.w * D.run
					b.x += b.vx * dt
					if b.x > wx - b.w * 0.28:                # the autopilot leaps at the wall
						b.vy = -b.h * 0.55
						b.state = "air"
			elif st == "air":
				b.vy += b.h * D.g * dt
				b.x += b.vx * dt
				b.y += b.vy * dt
				if b.x >= wx - R:                            # arrival: fast enough?
					b.x = wx - R
					var sp: float = Vector2(b.vx, b.vy).length()
					if sp / b.w > D.minSpeed:
						b.state = "wallrun"
						b.tm = 0.0
						b.vy = -minf(sp * 0.8, b.h * 0.9)
						b.vx = 0.0
					else:
						b.state = "slide"
						b.vx = 0.0
				if b.y >= b.gy - R:
					b.y = b.gy - R
					b.vy = 0.0
					b.state = "run"
					b.back = true
			elif st == "wallrun":
				b.tm += dt
				b.vy += b.h * D.g * D.wallG * dt
				b.y += b.vy * dt
				if b.tm >= D.runTime:
					b.state = "slide"
				elif b.tm > D.runTime * 0.75:                # the autopilot's jump-off
					b.vx = -b.w * D.kick
					b.vy = -b.h * D.jumpV
					b.state = "air"
					b.flash = 0.5
			elif st == "slide":
				b.vy = minf(b.vy + b.h * D.g * dt, b.h * 0.25)
				b.y += b.vy * dt
				if b.y >= b.gy - R:
					b.y = b.gy - R
					b.vy = 0.0
					b.state = "run"
					b.back = true
			if b.y < R:
				b.y = R
				b.vy = maxf(0.0, b.vy)
			b.flash = maxf(0.0, b.flash - dt)
		"kneel":
			var bx0: float = b.w * 0.4
			var beamW: float = b.w * D.tunnel
			var gap: float = b.h * D.beamY
			var standH: float = b.h * D.standH
			var under: bool = b.x + R > bx0 and b.x - R < bx0 + beamW
			var rayHit: bool = under and standH > gap    # the ceiling ray: from the floor up to standing height
			b.rayHit = rayHit
			var st: String = b.state
			if st == "run":
				b.v = b.w * D.run
				b.x += b.v * dt
				if b.x > bx0 - b.w * 0.16 and b.x < bx0:     # the autopilot slides for the beam
					b.state = "slide"
				if under and rayHit:
					b.state = "crouch"
			elif st == "slide":
				b.v = maxf(0.0, b.v - b.w * D.slideFriction * dt)
				b.x += b.v * dt
				if b.v <= b.w * D.crawl:
					b.state = "crouch" if rayHit else "run"
					if rayHit:
						b.refused = 0.5
			elif st == "crouch":
				b.v = b.w * D.crawl
				b.x += b.v * dt
				if not rayHit:
					b.state = "run"
					b.refused = 0.0
			if b.x > b.w + R:
				b.x = -R
			b.refused = maxf(0.0, b.refused - dt)
		"dodge":
			var bw := R * 2.2
			var k0: float = D.startup
			var k1: float = D.startup + D.invuln
			var hurt := true
			if b.rolling:
				b.k += dt / D.dur
				var k: float = b.k
				b.x = b.x0 + b.dir * b.w * D.dist * _ease(clampf(k, 0.0, 1.0))
				hurt = not (k >= k0 and k <= k1)
				if k >= 1.0:
					b.rolling = false
					b.k = 0.0
			# bullets: spawn from alternating sides, fly at the mote's height
			b.spawnT -= dt
			if b.spawnT <= 0.0:
				b.spawnT = float(D.bulletEvery)
				for bl: Dictionary in b.bullets:
					if not bl.on:
						bl.on = true
						bl.through = false
						bl.x = -6.0 if b.side > 0 else b.w + 6.0
						bl.vx = b.side * b.w * D.bulletSpeed
						bl.y = b.gy - R
						b.side = -b.side
						b.late = 1 if randf_range(0.0, 1.0) < 0.25 else 0
						break
			for bl: Dictionary in b.bullets:
				if not bl.on:
					continue
				bl.x += bl.vx * dt
				var arrive: float = (b.x - bl.x) / bl.vx       # seconds until it reaches the body
				var window: float = D.dur * D.startup * 0.5 if b.late == 1 else D.dur * (D.startup + D.invuln * 0.5)
				if not b.rolling and arrive > 0.0 and arrive < window:   # the autopilot's dodge
					_d_roll(b, 1 if bl.vx > 0.0 else -1)
				var inBox: bool = absf(bl.x - b.x) < bw / 2.0 + 3.0
				if inBox and hurt and not bl.through:
					bl.on = false
					b.flash = 0.5
					b.hits += 1
				elif inBox and not hurt:
					bl.through = true
				if bl.through and not inBox and signf(bl.x - b.x) == signf(bl.vx):
					b.dodged += 1
					bl.through = false
					bl.on = false
				if bl.x < -10.0 or bl.x > b.w + 10.0:
					bl.on = false
			b.hurt = hurt
			b.flash = maxf(0.0, b.flash - dt)
			b.refused = maxf(0.0, b.refused - dt)
		"glide":
			b.idle += dt
			if b.idle > 1.5:                                 # the autopilot: trim, then pull up into a stall, then recover
				var k := fmod(t, 11.0)
				b.want = 0.5 + sin(t * 0.7) * 0.12 if k < 7.0 else (1.0 if k < 8.6 else (0.2 if k < 10.0 else 0.5))
			b.pitch += (b.want - b.pitch) * Kit.smooth(6.0, dt)
			# the forces, in H units per second
			var speed: float = Vector2(b.vx, b.vy).length() / b.h
			b.speed = speed
			var ux: float = b.vx / (speed * b.h) if speed > 1e-4 else 1.0   # along the velocity
			var uy: float = b.vy / (speed * b.h) if speed > 1e-4 else 0.0
			b.ux = ux
			b.uy = uy
			var aoa: float = b.pitch * D.maxAoA
			b.aoa = aoa
			var stalled: bool = speed < D.stallV or aoa > D.stallAoA
			b.stalled = stalled
			var v2 := speed * speed
			var liftA: float = D.lift * aoa * v2 * (D.stallDrop if stalled else 1.0)
			var dragA: float = (D.drag + D.dragK * aoa * aoa) * v2
			b.liftA = liftA
			b.dragA = dragA
			var nx := uy                                     # the wing's up: left of the velocity
			var ny := -ux
			var ax: float = (nx * liftA - ux * dragA) * b.h
			var ay: float = (ny * liftA - uy * dragA + D.g) * b.h
			b.vx += ax * dt
			b.vy += ay * dt
			b.vx = clampf(b.vx, b.h * 0.05, b.h * 3.0)
			b.vy = clampf(b.vy, -b.h * 3.0, b.h * 3.0)
			b.y += b.vy * dt
			b.scroll += b.vx * dt
			if b.y < R + 2.0:
				b.y = R + 2.0
				b.vy = maxf(b.vy, 0.0)
			if b.y > b.gy - R:                               # touched down: throw it again
				_g_launch(b)
			b.launched = maxf(0.0, b.launched - dt)
		"jetpack":
			b.idle += dt
			b.held -= dt
			var want: bool = b.held > 0.0
			if b.idle > 2.0:                                 # the autopilot: bang-bang hover
				var hy: float = b.h * D.hoverY
				want = b.y > hy + b.h * 0.02 or (b.y > hy - b.h * 0.04 and b.vy > 0.0)
				if b.grounded and b.fuel < D.tank * 0.05:    # ran dry: rest until the tank is nearly full
					b.rest = true
				if b.fuel > D.tank * 0.9:
					b.rest = false
				if b.rest:
					want = false
				b.leanX = b.w * 0.5 + sin(t * 0.4) * b.w * 0.3
			var burning: bool = want and b.fuel > 0.0
			b.burning = burning
			if burning:
				b.fuel = maxf(0.0, b.fuel - dt)
				b.vy -= b.h * D.thrust * dt
				if b.fuel == 0.0:
					b.empty = 0.8
			b.vy += b.h * D.g * dt
			b.vx += signf(b.leanX - b.x) * b.w * D.lean * dt * (1.0 if burning else 0.3)
			b.vx *= exp(-1.2 * dt)
			b.x += b.vx * dt
			b.y += b.vy * dt
			b.grounded = false
			if b.y >= b.gy - R:
				b.y = b.gy - R
				b.vy = 0.0
				b.vx *= 0.5
				b.grounded = true
				b.fuel = minf(D.tank, b.fuel + dt * D.tank / D.refill)
			if b.y < R:
				b.y = R
				b.vy = maxf(0.0, b.vy)
			if b.x < R:
				b.x = R
				b.vx = absf(b.vx)
			if b.x > b.w - R:
				b.x = b.w - R
				b.vx = -absf(b.vx)
			b.empty = maxf(0.0, b.empty - dt)
			# exhaust
			if burning:
				for _k in 3:
					for p: Dictionary in b.puffs:
						if p.life <= 0.0:
							p.x = b.x + randf_range(-3.0, 3.0)
							p.y = b.y + R
							p.vx = b.vx * 0.3 + randf_range(-20.0, 20.0)
							p.vy = b.h * 0.9 + randf_range(0.0, b.h * 0.3)
							p.life = 0.45
							break
			for p: Dictionary in b.puffs:
				if p.life > 0.0:
					p.life -= dt
					p.x += p.vx * dt
					p.y += p.vy * dt
					if p.y > b.gy:
						p.vy = -absf(p.vy) * 0.3
		"underwater":
			var bh: float = b.h * D.bodyH
			b.timer -= dt
			if b.timer <= 0.0:                               # the autopilot alternates
				b.timer = float(D.every)
				b.wantX = b.w * randf_range(0.2, 0.8)
				if b.phase == 0:
					b.vy += b.h * D.dive
					b.phase = 1
				else:
					if b.f > 0.25:
						b.vy = -b.h * D.leap
					b.phase = 0
			var sy := _u_surface(b, b.x, t)
			var f: float = clampf((b.y + bh / 2.0 - sy) / bh, 0.0, 1.0)
			b.f = f
			b.vy += b.h * (D.g - D.buoy * f) * dt
			b.vx += signf(b.wantX - b.x) * (1.0 if absf(b.wantX - b.x) > 4.0 else 0.0) * b.w * D.swim * dt * (0.3 + 0.7 * f)
			var drag: float = lerpf(D.dragA, D.dragW, f)
			var k := exp(-drag * dt)
			b.vx *= k
			b.vy *= k
			b.x += b.vx * dt
			b.y += b.vy * dt
			if b.y + bh / 2.0 > b.gy:
				b.y = b.gy - bh / 2.0
				b.vy = minf(0.0, b.vy)
			if b.y - bh / 2.0 < 0.0:
				b.y = bh / 2.0
				b.vy = maxf(0.0, b.vy)
			if b.x < R:
				b.x = R
				b.vx = absf(b.vx)
			if b.x > b.w - R:
				b.x = b.w - R
				b.vx = -absf(b.vx)
			var under: bool = b.y > sy
			if under != b.wasUnder and absf(b.vy) > b.h * 0.2:
				_u_splash(b, b.x, sy)
			b.wasUnder = under
			for r: Dictionary in b.rings:
				if r.life > 0.0:
					r.life -= dt
					r.r += dt * 60.0
		"gravity":
			b.timer -= dt
			var planet: bool = D.mode == "planet"
			var pr: float = b.h * D.planetR
			var G: float = b.h * D.g
			var cy0: float = b.h * D.ceiling
			if planet:                                       # g aims at the centre
				var rx: float = b.x - b.cx
				var ry: float = b.y - b.cyp
				var d := sqrt(rx * rx + ry * ry)
				if d < 1e-3:
					rx = 0.0
					ry = -1.0
					d = 1.0
				var ux := rx / d
				var uy := ry / d
				b.gdx = -ux
				b.gdy = -uy
				b.vx += b.gdx * G * dt
				b.vy += b.gdy * G * dt
				b.x += b.vx * dt
				b.y += b.vy * dt
				rx = b.x - b.cx
				ry = b.y - b.cyp
				d = sqrt(rx * rx + ry * ry)
				var ux2: float = rx / d if d > 1e-3 else 0.0
				var uy2: float = ry / d if d > 1e-3 else -1.0
				b.grounded = false
				if d < pr + R:                               # on the surface: stand, then run along the tangent
					b.x = b.cx + ux2 * (pr + R)
					b.y = b.cyp + uy2 * (pr + R)
					var vr: float = b.vx * ux2 + b.vy * uy2
					if vr < 0.0:
						b.vx -= vr * ux2
						b.vy -= vr * uy2
					var tx := -uy2
					var ty := ux2
					var vt: float = b.vx * tx + b.vy * ty
					var want: float = b.dir * b.w * D.run
					b.vx += (want - vt) * tx
					b.vy += (want - vt) * ty
					b.grounded = true
					if b.timer <= 0.0:                       # the hop, straight up
						b.timer = float(D.every)
						b.vx += ux2 * b.h * D.hop
						b.vy += uy2 * b.h * D.hop
				if b.x < -b.w * 0.3 or b.x > b.w * 1.3 or b.y < -b.h * 0.3 or b.y > b.h * 1.3:   # lost to space: back home
					b.x = b.cx
					b.y = b.cyp - pr - R
					b.vx = b.w * D.run
					b.vy = 0.0
			else:                                            # the room: floor and ceiling
				if b.timer <= 0.0:
					b.timer = float(D.every)
					_gv_flip(b)
				b.gdx = 0.0
				b.vy += b.gdy * G * dt
				b.vx = b.dir * b.w * D.run
				b.x += b.vx * dt
				b.y += b.vy * dt
				b.grounded = false
				if b.gdy > 0.0 and b.y > b.gy - R:
					b.y = b.gy - R
					b.vy = 0.0
					b.grounded = true
				if b.gdy < 0.0 and b.y < cy0 + R:
					b.y = cy0 + R
					b.vy = 0.0
					b.grounded = true
				if b.x > b.w - R:
					b.x = b.w - R
					b.dir = -1
				if b.x < R:
					b.x = R
					b.dir = 1
			b.flash = maxf(0.0, b.flash - dt)
			var trail: Array = b.trail
			trail[b.ti] = Vector2(b.x, b.y)
			b.ti = (b.ti + 1) % trail.size()
			b.tn = mini(b.tn + 1, trail.size())
		"zipline":
			b.timer += dt
			var st: String = b.state
			if st == "ride":
				_z_tangent(b, b.x)
				b.gAlong = b.h * D.g * b.ty                  # gravity's share along the rail
				b.v += b.gAlong * dt
				b.v *= exp(-D.friction * dt)
				b.v = clampf(b.v, -b.w * 2.0, b.w * 2.0)
				b.x += b.v * b.tx * dt
				b.y = _z_rail_y(b, b.x) + R
				if b.x > b.w - R or b.x < 0.0:               # ran off the end
					_z_let_go(b)
				elif b.timer > D.rideT and b.x > b.w * 0.3:  # the autopilot's drop
					_z_let_go(b)
			elif st == "free":
				b.vy += b.h * D.g * dt
				b.x += b.vx * dt
				b.y += b.vy * dt
				if b.timer > 0.25 and b.vy > 0.0 and absf(b.y - R - _z_rail_y(b, b.x)) < b.h * 0.03 and b.x > R and b.x < b.w - R:   # fell back onto the rail
					_z_grab(b)
				if b.y >= b.gy - R:
					b.y = b.gy - R
					b.vy = 0.0
					b.state = "walk"
				if b.x < R:
					b.x = R
					b.vx = absf(b.vx)
				if b.x > b.w - R:
					b.x = b.w - R
					b.vx = -absf(b.vx)
			elif st == "walk":                               # back to the start, then up the pole
				b.x -= b.w * 0.5 * dt
				if b.x <= b.w * 0.02:
					b.x = b.w * 0.02
					b.state = "climb"
			elif st == "climb":
				b.y -= b.h * 0.6 * dt
				if b.y <= _z_rail_y(b, b.x) + R:
					b.y = _z_rail_y(b, b.x) + R
					b.v = b.w * D.attachV
					b.state = "ride"
					b.timer = 0.0
			b.flash = maxf(0.0, b.flash - dt)
			var trail: Array = b.trail
			trail[b.ti] = Vector2(b.x, b.y)
			b.ti = (b.ti + 1) % trail.size()
			b.tn = mini(b.tn + 1, trail.size())
		"minecart":
			var dy := (_mc_track_y(b, b.x + 2.0) - _mc_track_y(b, b.x - 2.0)) / 4.0
			var L := sqrt(1.0 + dy * dy)
			b.tx = 1.0 / L
			b.ty = dy / L
			b.gAlong = b.h * D.g * b.ty                      # g·sin θ, signed along +x
			b.v += b.gAlong * dt
			b.v *= exp(-D.friction * dt)
			b.v = clampf(b.v, -b.w * 2.0, b.w * 2.0)
			b.x += b.v * b.tx * dt
			if b.x > b.w:
				b.x -= b.w
			if b.x < 0.0:
				b.x += b.w
			var seg := int(floorf(fposmod(b.x - b.station, b.w) / b.period))   # which dip we are in, counted from a station
			if seg != b.lastSeg and b.v > 0.0 and b.v < b.w * D.push * 1.5:   # crossed a station rightward, slowly: a shove
				b.v += b.w * D.push
				b.flash = 0.5
			b.lastSeg = seg
			b.flash = maxf(0.0, b.flash - dt)
		"brittle":
			var P: Array = b.P
			var py: float = b.h * D.platY
			var pw: float = b.w * D.platW
			# the platforms
			for i in 3:
				var p: Dictionary = P[i]
				p.jx = 0.0
				p.jy = 0.0
				if p.state == "shake":
					p.tm += dt
					var k: float = clampf(p.tm / p.hold, 0.0, 1.0)
					p.jx = randf_range(-1.0, 1.0) * 3.0 * k
					p.jy = randf_range(-1.0, 1.0) * 2.0 * k
					if p.tm >= p.hold:
						p.state = "fall"
						p.tm = 0.0
						p.vy = 0.0
						if b.on == i:
							b.on = -1
							b.state = "air"
							b.vx = 0.0
							b.vy = 0.0
				elif p.state == "fall":
					p.tm += dt
					p.vy += b.h * D.g * dt
					p.y += p.vy * dt
					if p.tm >= D.fade or p.y > b.h + 10.0:
						p.state = "gone"
						p.tm = 0.0
				elif p.state == "gone":
					p.tm += dt
					if p.tm >= D.respawn:
						p.state = "idle"
						p.tm = 0.0
						p.y = py
			# the rider
			var st: String = b.state
			if st == "walk":
				b.x += signf(b.w * 0.06 - b.x) * b.w * 0.3 * dt
				if absf(b.x - b.w * 0.06) < 2.0:
					b.x = b.w * 0.06
					var p0: Dictionary = P[0]
					if p0.state == "idle" or p0.state == "shake":
						_b_hop_to(b, p0.x, p0.y - R)
			elif st == "stand":
				var on: int = b.on
				var p: Dictionary = P[on]
				b.x = p.x + p.jx
				b.y = p.y + p.jy - R
				b.tm += dt
				if p.state == "idle":
					p.state = "shake"
					p.tm = 0.0
				if b.tm > minf(p.hold * 0.8, 0.6 + (0.35 if on == 1 else 0.0)):   # hop on, before it goes
					if on < 2:
						var q: Dictionary = P[on + 1]
						_b_hop_to(b, q.x, q.y - R)
					else:
						_b_hop_to(b, b.w * 0.96, b.gy - R)
			elif st == "air":
				var py0: float = b.y
				b.vy += b.h * D.g * dt
				b.x += b.vx * dt
				b.y += b.vy * dt
				if b.vy > 0.0:
					for i in 3:
						var p: Dictionary = P[i]
						if (p.state == "idle" or p.state == "shake") and absf(b.x - p.x) < pw / 2.0 and py0 + R <= p.y + 1.0 and b.y + R >= p.y:
							b.on = i
							b.state = "stand"
							b.tm = 0.0
							b.y = p.y - R
							b.vy = 0.0
							break
				if b.y >= b.gy - R:
					b.y = b.gy - R
					b.vy = 0.0
					b.vx = 0.0
					b.state = "walk"
				if b.x > b.w - R:
					b.x = b.w - R
		"bouncepad":
			var room: float = b.gy - 12.0
			var G: float = b.h * D.g
			var h: float = room * b.apex
			var padH := 6.0
			# the pad lane: assigned velocity
			b.lvy += G * dt
			b.ly += b.lvy * dt
			if b.ly >= b.gy - padH - R and b.lvy > 0.0:
				b.ly = b.gy - padH - R
				b.lvy = -sqrt(2.0 * G * h)
				b.lv0 = -b.lvy
				b.lsq = 1.0
			# the floor lane: restitution
			b.rvy += G * dt
			b.ry += b.rvy * dt
			if b.ry < b.rTopNext:                            # the highest point since the last bounce
				b.rTopNext = b.ry
			if b.ry >= b.gy - R and b.rvy > 0.0:
				b.ry = b.gy - R
				b.rvy = -b.rvy * D.e
				b.rsq = 1.0
				b.rTop = b.rTopNext
				b.rTopNext = b.gy
				if -b.rvy < b.h * 0.15:                      # dead: drop it again
					b.ry = b.gy - room * D.drop
					b.rvy = 0.0
					b.rTop = b.ry
					b.rTopNext = b.ry
			b.lsq = maxf(0.0, b.lsq - dt / D.squashT)
			b.rsq = maxf(0.0, b.rsq - dt / D.squashT)

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	var D: Dictionary = b.D
	var origin: Vector2 = (b.rect as Rect2).position
	Kit.stage(n, b)
	match b.id:
		"mantle":
			var reach: float = b.w * D.probe
			var x: float = b.x
			var y: float = b.y
			var st: String = b.state
			# the world
			for l: Dictionary in b.L:
				Kit.rect(n, Rect2(l.x, l.top, b.w - l.x, b.gy - l.top), _a(Kit.BONE, 0.08))
				Kit.line(n, Vector2(l.x, l.top), Vector2(l.x, b.gy), Kit.BONE, 1.5)
				Kit.line(n, Vector2(l.x, l.top), Vector2(b.w, l.top), Kit.BONE, 1.5)
			Kit.ground(n, b)
			# the two rays, coloured by what they found
			if st == "run" or st == "air":
				var cc: Color = Kit.HOT if b.chestHit else Kit.GOOD
				var hc: Color = Kit.HOT if b.headHit else Kit.GOOD
				Kit.line(n, Vector2(x + R, y - R * 0.3), Vector2(x + R + reach, y - R * 0.3), cc, 1.5)
				Kit.line(n, Vector2(x + R, y - R * 2.2), Vector2(x + R + reach, y - R * 2.2), hc, 1.5)
				Kit.label(n, b, "chest", Vector2(x + R + reach + 3.0, y - R * 0.3 + 3.0), Kit.HOT if b.chestHit else Kit.DIM)
				Kit.label(n, b, "head", Vector2(x + R + reach + 3.0, y - R * 2.2 + 3.0), Kit.HOT if b.headHit else Kit.DIM)
			if st == "hang":                                 # hands on the edge, the hang timer
				Kit.dot(n, Vector2(b.hx, b.hy), 3.0, Kit.TARGET)
				Kit.dot(n, Vector2(b.hx - 5.0, b.hy + 1.0), 2.5, Kit.TARGET)
				Kit.rect(n, Rect2(x - 14.0, y - R * 3.0, 28.0, 3.0), _a(Kit.INK, 0.15))
				Kit.rect(n, Rect2(x - 14.0, y - R * 3.0, 28.0 * clampf(b.tm / D.hang, 0.0, 1.0), 3.0), Kit.TARGET)
				Kit.label(n, b, "hang", Vector2(x, y - R * 3.6), Kit.TARGET, true)
			if st == "mantle":                               # the arc, drawn as the promise it is (dashed: every other segment)
				var p0 := Vector2(b.sx, b.sy)
				var pc := Vector2(b.sx, b.hy - R)
				var p2 := Vector2(b.hx + R * 1.2, b.hy - R)
				for i in range(0, 24, 2):
					var k0 := i / 24.0
					var k1 := (i + 1) / 24.0
					var q0 := p0.lerp(pc, k0).lerp(pc.lerp(p2, k0), k0)
					var q1 := p0.lerp(pc, k1).lerp(pc.lerp(p2, k1), k1)
					n.draw_line(q0, q1, Kit.MAGIC, 1.0)
				Kit.label(n, b, "mantle %.0f%%" % (b.tm / D.mantleT * 100.0), Vector2(x, y - R * 2.4), Kit.MAGIC, true)
			if b.refused > 0.0:
				Kit.label(n, b, "too tall — jump", Vector2(x, y - R * 3.4), _a(Kit.HOT, b.refused * 2.0), true)
			Kit.mote(n, b, Vector2(x, y), -PI / 2.0 if st == "hang" else 0.0)
			_label_right(n, b, st, Vector2(b.w - 8.0, 14.0), Kit.DIM)
			Kit.label(n, b, D.label, Vector2(b.w / 2.0, b.h - 8.0), Color(0.91, 0.898, 0.957, 0.55), true)
		"ladder":
			var lx: float = b.w * 0.5
			var half: float = b.w * 0.05
			var topY: float = b.h * D.top
			var platX: float = lx + half
			var x: float = b.x
			var y: float = b.y
			var st: String = b.state
			# the world: the ladder rect, the rails and rungs, the top platform
			Kit.rect(n, Rect2(lx - half, topY, half * 2.0, b.gy - topY), _a(Kit.GOOD, 0.06))
			_dash_rect(n, Rect2(lx - half, topY, half * 2.0, b.gy - topY), 3.0, 3.0, _a(Kit.GOOD, 0.35), 1.0)
			var nn := 10
			var rail := PackedVector2Array()
			for i in nn + 1:
				var yy: float = topY + (b.gy - topY) * i / float(nn)
				rail.append(Vector2(_l_rail_x(b, yy) - half * 0.6, yy))
			for i in range(nn, -1, -1):
				var yy: float = topY + (b.gy - topY) * i / float(nn)
				rail.append(Vector2(_l_rail_x(b, yy) + half * 0.6, yy))
			n.draw_polyline(rail, Kit.BONE, 1.5)
			for i in range(1, nn):
				var yy: float = topY + (b.gy - topY) * i / float(nn)
				var rx := _l_rail_x(b, yy)
				Kit.line(n, Vector2(rx - half * 0.6, yy), Vector2(rx + half * 0.6, yy), Kit.BONE, 1.0)
			Kit.rect(n, Rect2(platX, topY, b.w - platX, 4.0), Kit.BONE)
			Kit.ground(n, b)
			if float(D.sway) != 0.0:                     # the hinge and its angle, read off the state
				Kit.dot(n, Vector2(lx, b.gy), 2.5, Kit.TARGET)
				Kit.label(n, b, "θ = %.1f°" % rad_to_deg(float(b.th)), Vector2(lx + half + 4.0, b.gy - 4.0), Kit.DIM)
			if st == "climb":
				Kit.line(n, Vector2(x, y), Vector2(lx, y), Kit.TARGET, 1.0)   # x is owned by the rail
				Kit.label(n, b, "g = 0 · x = rail", Vector2(x + R + 6.0, y + 3.0), Kit.GOOD)
				Kit.rect(n, Rect2(b.w - 30.0, b.h * 0.3, 6.0, b.gy - b.h * 0.3), _a(Kit.INK, 0.1))
				Kit.rect(n, Rect2(b.w - 30.0, y, 6.0, b.gy - y), Kit.GOOD)
			if st == "hop":
				Kit.label(n, b, "hop", Vector2(x, y - R * 2.0), Kit.TARGET, true)
			if st == "fall":
				Kit.label(n, b, "dropped", Vector2(x + R + 4.0, y), Kit.HOT)
			Kit.mote(n, b, Vector2(x, y), -PI / 2.0 if st == "climb" else 0.0)
			_label_right(n, b, st, Vector2(b.w - 8.0, 14.0), Kit.DIM)
			Kit.label(n, b, D.label, Vector2(b.w / 2.0, b.h - 8.0), Color(0.91, 0.898, 0.957, 0.55), true)
		"wallrun":
			var wx: float = b.w * D.wall
			var x: float = b.x
			var y: float = b.y
			var vx: float = b.vx
			var vy: float = b.vy
			var st: String = b.state
			var flash: float = b.flash
			# the wall and its normal
			Kit.rect(n, Rect2(wx, 0.0, b.w - wx, b.gy), Color(0.588, 0.569, 0.745, 0.13))
			Kit.line(n, Vector2(wx, 0.0), Vector2(wx, b.gy), Kit.BONE, 1.5)
			Kit.ground(n, b)
			var ny: float = minf(y, b.gy - R * 4.0)
			Kit.arrow(n, Vector2(wx, ny), Vector2(wx - b.w * 0.09, ny), Kit.BONE)
			Kit.label(n, b, "n̂", Vector2(wx - b.w * 0.09 - 12.0, ny + 3.0), Kit.BONE)
			if st == "wallrun":                              # the timer, on the wall beside the runner
				var k: float = clampf(b.tm / D.runTime, 0.0, 1.0)
				Kit.rect(n, Rect2(wx + 5.0, y - 20.0, 5.0, 40.0), _a(Kit.INK, 0.12))
				Kit.rect(n, Rect2(wx + 5.0, y - 20.0 + 40.0 * k, 5.0, 40.0 * (1.0 - k)), Kit.GOOD)
				Kit.label(n, b, "t %.2f / %s" % [b.tm, _num(D.runTime)], Vector2(wx + 14.0, y + 3.0), Kit.GOOD)
				_label_right(n, b, "g × %s" % _num(D.wallG), Vector2(x - R - 4.0, y + 3.0), Kit.GOOD)
			if st == "slide":
				_label_right(n, b, "slide: timer spent", Vector2(x - R - 4.0, y + 3.0), Kit.HOT)
			if st == "air" and vx > 0.0:
				var sp: float = Vector2(vx, vy).length() / b.w
				var fast: bool = sp > D.minSpeed
				Kit.label(n, b, "|v| %.2f%s%s" % [sp, " > " if fast else " < ", _num(D.minSpeed)], Vector2(x, y - R * 2.2), Kit.GOOD if fast else Kit.HOT, true)
			if flash > 0.0:
				Kit.arrow(n, Vector2(x, y), Vector2(x - b.w * 0.1, y - b.h * 0.1), _a(Kit.HOT, flash * 2.0))
			if st == "air":
				var ldt: float = b.ldt
				for i in range(1, 4):
					Kit.dot(n, Vector2(x - vx * ldt * i * 4.0, y - vy * ldt * i * 4.0), 1.5, _a(Kit.MOVER, 0.3 - i * 0.08))
			var ang: float = -PI / 2.0 if st == "wallrun" else (PI if (st == "run" and b.back) else atan2(vy, _or1(vx)))
			Kit.mote(n, b, Vector2(x, y), ang)
			_label_right(n, b, st, Vector2(b.w - 8.0, 14.0), Kit.DIM)
			Kit.label(n, b, D.label, Vector2(b.w / 2.0, b.h - 8.0), Color(0.91, 0.898, 0.957, 0.55), true)
		"kneel":
			var bx0: float = b.w * 0.4
			var beamW: float = b.w * D.tunnel
			var gap: float = b.h * D.beamY
			var beamY: float = b.gy - gap
			var standH: float = b.h * D.standH
			var crouchH: float = b.h * D.crouchH
			var x: float = b.x
			var st: String = b.state
			var rayHit: bool = b.rayHit
			# the beam and the tunnel
			Kit.rect(n, Rect2(bx0, 0.0, beamW, beamY), Color(0.588, 0.569, 0.745, 0.13))
			Kit.line(n, Vector2(bx0, beamY), Vector2(bx0 + beamW, beamY), Kit.BONE, 1.5)
			Kit.line(n, Vector2(bx0, 0.0), Vector2(bx0, beamY), Kit.BONE, 1.5)
			Kit.line(n, Vector2(bx0 + beamW, 0.0), Vector2(bx0 + beamW, beamY), Kit.BONE, 1.5)
			Kit.ground(n, b)
			# the hitbox, and the ceiling ray from the feet to standing height
			var hh: float = standH if st == "run" else crouchH
			var box := Rect2(x - R, b.gy - hh, R * 2.0, hh)
			Kit.rect(n, box, _a(Kit.MOVER, 0.15) if st == "run" else _a(Kit.TARGET, 0.15))
			n.draw_rect(box, Kit.MOVER if st == "run" else Kit.TARGET, false, 1.0)
			if st != "run":
				var rc: Color = Kit.HOT if rayHit else Kit.GOOD
				Kit.line(n, Vector2(x, b.gy), Vector2(x, b.gy - standH), rc, 1.5)
				Kit.line(n, Vector2(x - 4.0, b.gy - standH), Vector2(x + 4.0, b.gy - standH), rc, 1.5)
				Kit.label(n, b, "stand refused" if rayHit else "clear", Vector2(x + R + 4.0, b.gy - standH + 3.0), rc)
			if st == "slide":
				Kit.label(n, b, "v %.2f" % (b.v / b.w), Vector2(x, b.gy - crouchH - 6.0), Kit.TARGET, true)
			if st == "crouch":
				Kit.label(n, b, "crawl", Vector2(x, b.gy - crouchH - 6.0), Kit.HOT, true)
			Kit.mote(n, b, Vector2(x, b.gy - hh / 2.0), 0.0, Kit.MOVER, 8.0 if st == "run" else 6.0)
			_label_right(n, b, st, Vector2(b.w - 8.0, 14.0), Kit.DIM)
			Kit.label(n, b, D.label, Vector2(b.w / 2.0, b.h - 8.0), Color(0.91, 0.898, 0.957, 0.55), true)
		"dodge":
			var bw := R * 2.2
			var bh := R * 2.4
			var k0: float = D.startup
			var k1: float = D.startup + D.invuln
			var x: float = b.x
			var k: float = b.k
			var rolling: bool = b.rolling
			var hurt: bool = b.hurt
			var flash: float = b.flash
			var dir: int = b.dir
			Kit.ground(n, b)
			# the bullets
			for bl: Dictionary in b.bullets:
				if bl.on:
					var bc: Color = _a(Kit.HOT, 0.35) if bl.through else Kit.HOT
					Kit.line(n, Vector2(bl.x - signf(bl.vx) * 10.0, bl.y), Vector2(bl.x, bl.y), bc, 2.0)
					Kit.dot(n, Vector2(bl.x, bl.y), 2.5, bc)
			# the hurtbox: solid while it counts, dashed while it does not
			var box := Rect2(x - bw / 2.0, b.gy - bh, bw, bh)
			if hurt:
				n.draw_rect(box, Kit.HOT if flash > 0.0 else Kit.MOVER, false, 1.5)
			else:
				_dash_rect(n, box, 3.0, 3.0, Kit.GOOD, 1.5)
			if flash > 0.0:
				Kit.rect(n, box, _a(Kit.HOT, flash * 0.5))
			# the phase bar: three bands and a cursor
			var bx: float = x - 24.0
			var by: float = b.gy - bh - 14.0
			var bwid := 48.0
			Kit.rect(n, Rect2(bx, by, bwid * k0, 4.0), Kit.BONE if rolling else _a(Kit.BONE, 0.25))
			Kit.rect(n, Rect2(bx + bwid * k0, by, bwid * D.invuln, 4.0), Kit.GOOD if rolling else _a(Kit.GOOD, 0.25))
			Kit.rect(n, Rect2(bx + bwid * k1, by, bwid * (1.0 - k1), 4.0), Kit.HOT if rolling else _a(Kit.HOT, 0.25))
			if rolling:
				Kit.line(n, Vector2(bx + bwid * k, by - 3.0), Vector2(bx + bwid * k, by + 7.0), Kit.INK, 1.5)
			var phase: String = ("startup" if k < k0 else ("invulnerable" if k <= k1 else "recovery")) if rolling else "ready"
			var pc: Color = (Kit.BONE if k < k0 else (Kit.GOOD if k <= k1 else Kit.HOT)) if rolling else Kit.DIM
			Kit.label(n, b, phase, Vector2(x, by - 5.0), pc, true)
			if b.refused > 0.0:
				Kit.label(n, b, "can't cancel recovery", Vector2(x, by - 16.0), _a(Kit.HOT, b.refused * 2.5), true)
			var kc := clampf(k, 0.0, 1.0)
			var my: float = b.gy - R - (sin(kc * PI) * R * 0.4 if rolling else 0.0)
			var ang: float = kc * PI * 2.0 * dir if rolling else (0.0 if dir > 0 else PI)
			Kit.mote(n, b, Vector2(x, my), ang, Kit.MOVER if hurt else _a(Kit.MOVER, 0.45))
			Kit.label(n, b, "hit %d · dodged %d" % [b.hits, b.dodged], Vector2(8.0, 14.0), Kit.DIM)
			_label_right(n, b, "startup %.2f s · i-frames %.2f s · recovery %.2f s" % [D.dur * k0, D.dur * D.invuln, D.dur * (1.0 - k1)], Vector2(b.w - 8.0, 14.0), Kit.DIM)
			Kit.label(n, b, D.label, Vector2(b.w / 2.0, b.h - 8.0), Color(0.91, 0.898, 0.957, 0.55), true)
		"glide":
			var mx: float = b.w * 0.4
			var y: float = b.y
			var ux: float = b.ux
			var uy: float = b.uy
			var nx := uy
			var ny := -ux
			var liftA: float = b.liftA
			var dragA: float = b.dragA
			var speed: float = b.speed
			var aoa: float = b.aoa
			var stalled: bool = b.stalled
			var scroll: float = b.scroll
			var pitch: float = b.pitch
			# the scrolling world: posts and low hills
			for i in range(-1, 12):
				var px: float = fposmod(i * b.w * 0.13 - scroll, b.w * 1.3) - b.w * 0.15
				var hh: float = (Kit.noise(px / b.w * 3.0 + scroll / b.w * 0.01) * 0.5 + 0.5) * b.h * 0.08 + 4.0
				Kit.line(n, Vector2(px, b.gy), Vector2(px, b.gy - hh), _a(Kit.BONE, 0.25), 1.5)
			Kit.ground(n, b)
			# the forces drawn where they act
			var S: float = b.h * 0.09
			Kit.arrow(n, Vector2(mx, y), Vector2(mx + nx * liftA * S, y + ny * liftA * S), _a(Kit.GOOD, 0.4) if stalled else Kit.GOOD)
			Kit.arrow(n, Vector2(mx, y), Vector2(mx - ux * dragA * S, y - uy * dragA * S), Kit.HOT)
			Kit.arrow(n, Vector2(mx, y), Vector2(mx, y + D.g * S), Kit.DIM)
			Kit.line(n, Vector2(mx, y), Vector2(mx + ux * 22.0, y + uy * 22.0), _a(Kit.MOVER, 0.5), 1.0)
			Kit.label(n, b, "L", Vector2(mx + nx * liftA * S + nx * 8.0, y + ny * liftA * S + ny * 8.0 + 3.0), Kit.GOOD, true)
			Kit.label(n, b, "Dr", Vector2(mx - ux * dragA * S - 10.0, y - uy * dragA * S - 4.0), Kit.HOT, true)
			Kit.label(n, b, "g", Vector2(mx + 8.0, y + D.g * S + 2.0), Kit.DIM)
			Kit.mote(n, b, Vector2(mx, y), atan2(uy, ux) - aoa)
			if stalled:
				Kit.label(n, b, "STALL" + (" — too slow" if speed < D.stallV else " — too steep"), Vector2(mx, y - R * 2.6), Kit.HOT, true)
			elif b.launched > 0.0:
				Kit.label(n, b, "launched at v = %s" % _num(D.launchV), Vector2(mx, y - R * 2.6), _a(Kit.TARGET, b.launched), true)
			# the speed gauge, with the stall speed marked
			var gx: float = b.w - 18.0
			var g0: float = b.h * 0.2
			var gh: float = b.h * 0.5
			Kit.rect(n, Rect2(gx, g0, 6.0, gh), _a(Kit.INK, 0.1))
			var kv := clampf(speed / 2.0, 0.0, 1.0)
			var ks: float = clampf(D.stallV / 2.0, 0.0, 1.0)
			Kit.rect(n, Rect2(gx, g0 + gh * (1.0 - kv), 6.0, gh * kv), Kit.HOT if speed < D.stallV else Kit.MOVER)
			Kit.line(n, Vector2(gx - 3.0, g0 + gh * (1.0 - ks)), Vector2(gx + 9.0, g0 + gh * (1.0 - ks)), Kit.HOT, 1.0)
			Kit.label(n, b, "v %.2f" % speed, Vector2(gx + 3.0, g0 - 6.0), Kit.MOVER, true)
			_label_right(n, b, "stall", Vector2(gx - 5.0, g0 + gh * (1.0 - ks) + 3.0), Kit.HOT)
			# the pitch control: the pointer's height
			var px0 := 14.0
			Kit.rect(n, Rect2(px0, g0, 6.0, gh), _a(Kit.INK, 0.1))
			var kp: float = (1.0 - pitch) / 2.0
			var kst: float = (1.0 - D.stallAoA / D.maxAoA) / 2.0
			Kit.rect(n, Rect2(px0, g0 + gh * minf(kp, 0.5), 6.0, gh * absf(0.5 - kp)), Kit.HOT if aoa > D.stallAoA else Kit.TARGET)
			Kit.line(n, Vector2(px0 - 3.0, g0 + gh * kst), Vector2(px0 + 9.0, g0 + gh * kst), Kit.HOT, 1.0)
			Kit.label(n, b, "α %.0f°" % (aoa * 57.3), Vector2(px0 + 3.0, g0 - 6.0), Kit.TARGET, true)
			Kit.label(n, b, "autopilot" if b.idle > 1.5 else "pitch", Vector2(px0 + 3.0, g0 + gh + 12.0), Kit.DIM, true)
			Kit.label(n, b, D.label, Vector2(b.w / 2.0, b.h - 8.0), Color(0.91, 0.898, 0.957, 0.55), true)
		"jetpack":
			var x: float = b.x
			var y: float = b.y
			var fuel: float = b.fuel
			var burning: bool = b.burning
			var grounded: bool = b.grounded
			var idle: float = b.idle
			var tank: float = D.tank
			# exhaust
			for p: Dictionary in b.puffs:
				if p.life > 0.0:
					var life: float = p.life
					Kit.dot(n, Vector2(p.x, p.y), 1.0 + life * 4.0, _a(Kit.TARGET, life) if life > 0.3 else _a(Kit.HOT, life))
			# the hover line
			_dashed(n, Vector2(0.0, b.h * D.hoverY), Vector2(b.w, b.h * D.hoverY), 4.0, 4.0, _a(Kit.TARGET, 0.35) if idle > 2.0 else Kit.DIM, 1.0)
			Kit.ground(n, b)
			# the two arrows
			var S: float = b.h * 0.05
			Kit.arrow(n, Vector2(x, y), Vector2(x, y + D.g * S), Kit.BONE)
			Kit.label(n, b, "g %s" % _num(D.g), Vector2(x + 12.0, y + D.g * S), Kit.BONE)
			if burning:
				Kit.arrow(n, Vector2(x, y), Vector2(x, y - D.thrust * S), Kit.HOT)
				Kit.label(n, b, "thrust %s" % _num(D.thrust), Vector2(x + 12.0, y - D.thrust * S + 3.0), Kit.HOT)
			elif b.empty > 0.0:
				Kit.label(n, b, "empty", Vector2(x, y - R * 2.4), _a(Kit.HOT, b.empty), true)
			# the fuel bar
			var low: bool = fuel < tank * 0.2
			var refilling: bool = grounded and fuel < tank
			Kit.rect(n, Rect2(8.0, 8.0, b.w * 0.3, 6.0), _a(Kit.INK, 0.1))
			Kit.rect(n, Rect2(8.0, 8.0, b.w * 0.3 * fuel / tank, 6.0), Kit.HOT if low else (Kit.GOOD if refilling else Kit.TARGET))
			Kit.label(n, b, "fuel %.2f s%s" % [fuel, " · refilling" if refilling else ""], Vector2(8.0, 24.0), Kit.HOT if low else Kit.DIM)
			var acc: String = "a = %.1f H/s²" % (D.thrust - D.g) if burning else "a = −%s H/s²" % _num(D.g)
			_label_right(n, b, acc, Vector2(b.w - 8.0, 14.0), Kit.HOT if burning else Kit.DIM)
			_label_right(n, b, "autopilot" if idle > 2.0 else "held", Vector2(b.w - 8.0, 26.0), Kit.DIM)
			Kit.mote(n, b, Vector2(x, y), -PI / 2.0 + clampf(b.vx / b.w, -0.5, 0.5))
			Kit.label(n, b, D.label, Vector2(b.w / 2.0, b.h - 8.0), Color(0.91, 0.898, 0.957, 0.55), true)
		"underwater":
			var bh: float = b.h * D.bodyH
			var x: float = b.x
			var y: float = b.y
			var vx: float = b.vx
			var vy: float = b.vy
			var f: float = b.f
			var sy := _u_surface(b, x, t)
			# the water: a wavy surface, a translucent body of it
			var water := PackedVector2Array()
			var surf := PackedVector2Array()
			water.append(Vector2(0.0, b.gy))
			for i in 33:
				var px: float = b.w * i / 32.0
				var pt := Vector2(px, _u_surface(b, px, t))
				water.append(pt)
				surf.append(pt)
			water.append(Vector2(b.w, b.gy))
			n.draw_colored_polygon(water, _a(Kit.MOVER, 0.12))
			n.draw_polyline(surf, _a(Kit.MOVER, 0.6), 1.5)
			Kit.ground(n, b)
			for r: Dictionary in b.rings:
				if r.life > 0.0:
					var life: float = r.life
					Kit.ring(n, Vector2(r.x, r.y), r.r, _a(Kit.INK, life * 0.8), 1.5)
					Kit.ring(n, Vector2(r.x, r.y), r.r * 0.6, _a(Kit.INK, life * 0.5), 1.0)
			# the body, its submerged share painted, the forces beside it
			var top: float = maxf(y - bh / 2.0, sy)
			Kit.rect(n, Rect2(x - R, y - bh / 2.0, R * 2.0, bh), _a(Kit.MOVER, 0.12))
			Kit.rect(n, Rect2(x - R, top, R * 2.0, maxf(0.0, y + bh / 2.0 - top)), _a(Kit.MOVER, 0.35))
			n.draw_rect(Rect2(x - R, y - bh / 2.0, R * 2.0, bh), Kit.MOVER, false, 1.0)
			var S: float = b.h * 0.05
			Kit.arrow(n, Vector2(x + R + 8.0, y), Vector2(x + R + 8.0, y - D.buoy * f * S), Kit.GOOD)
			Kit.arrow(n, Vector2(x - R - 8.0, y), Vector2(x - R - 8.0, y + D.g * S), Kit.BONE)
			Kit.label(n, b, "buoy·f %.2f" % (D.buoy * f), Vector2(x + R + 12.0, y - D.buoy * f * S - 3.0), Kit.GOOD)
			_label_right(n, b, "g %s" % _num(D.g), Vector2(x - R - 12.0, y + D.g * S + 9.0), Kit.BONE)
			Kit.label(n, b, "f = %.2f" % f, Vector2(x, y + bh / 2.0 + 11.0), Kit.MOVER if f > 0.0 else Kit.DIM, true)
			var ang: float = PI / 2.0 if vy > b.h * 0.15 else (-PI / 2.0 if vy < -b.h * 0.15 else (PI if vx < 0.0 else 0.0))
			Kit.mote(n, b, Vector2(x, y - bh / 2.0 + R), ang)
			Kit.label(n, b, "drag %.2f /s" % lerpf(D.dragA, D.dragW, f), Vector2(8.0, 14.0), Kit.DIM)
			var under: bool = y > sy
			_label_right(n, b, ("diving" if vy > b.h * 0.1 else "afloat") if under else "in the air", Vector2(b.w - 8.0, 14.0), Kit.DIM)
			Kit.dot(n, Vector2(b.wantX, sy - 4.0), 2.0, Kit.TARGET)
			Kit.label(n, b, D.label, Vector2(b.w / 2.0, b.h - 8.0), Color(0.91, 0.898, 0.957, 0.55), true)
		"gravity":
			var planet: bool = D.mode == "planet"
			var pr: float = b.h * D.planetR
			var cy0: float = b.h * D.ceiling
			var x: float = b.x
			var y: float = b.y
			var gdx: float = b.gdx
			var gdy: float = b.gdy
			var cx: float = b.cx
			var cyp: float = b.cyp
			var flash: float = b.flash
			var dir: int = b.dir
			var gs: float = D.g
			# the world
			if planet:
				Kit.dot(n, Vector2(cx, cyp), pr, _a(Kit.BONE, 0.12))
				Kit.ring(n, Vector2(cx, cyp), pr, Kit.BONE, 1.5)
				var a := 0.0
				while a < TAU:
					Kit.line(n, Vector2(cx + cos(a) * pr, cyp + sin(a) * pr), Vector2(cx + cos(a) * pr * 0.9, cyp + sin(a) * pr * 0.9), _a(Kit.BONE, 0.35))
					a += TAU / 14.0
				Kit.dot(n, Vector2(cx, cyp), 2.5, Kit.TARGET)
				_dashed(n, Vector2(x, y), Vector2(cx, cyp), 2.0, 4.0, _a(Kit.TARGET, 0.35))
			else:
				Kit.ground(n, b)
				Kit.line(n, Vector2(0.0, cy0), Vector2(b.w, cy0), _a(Kit.BONE, 0.5), 1.5)
				var px := 4.0
				while px < b.w:                              # the ceiling's hatching, mirrored
					Kit.line(n, Vector2(px, cy0 - 2.0), Vector2(px - 5.0, cy0 - 8.0), _a(Kit.BONE, 0.16))
					px += 12.0
			var trail: Array = b.trail
			var tn: int = b.tn
			var ti: int = b.ti
			var tl := trail.size()
			for i in tn:
				var p: Vector2 = trail[(ti - 1 - i + tl * 2) % tl]
				Kit.dot(n, p, 1.2, _a(Kit.MOVER, 0.3 - i / float(tl) * 0.3))
			# the g vector, and the body rotated so its feet face it
			var S: float = b.h * 0.06
			var gc: Color = Kit.HOT if flash > 0.0 else Kit.TARGET
			Kit.arrow(n, Vector2(x, y), Vector2(x + gdx * gs * S, y + gdy * gs * S), gc)
			Kit.label(n, b, "g⃗ (%.1f, %.1f)" % [gdx * gs, gdy * gs], Vector2(x + gdx * gs * S + 10.0, y + gdy * gs * S + 3.0), gc)
			var rot := atan2(gdy, gdx) - PI / 2.0              # local +y is "down" = along g
			var xf := Transform2D(rot, Vector2(x, y)) * Transform2D(0.0, Vector2(dir, 1.0), 0.0, Vector2.ZERO)   # the mirror faces the run
			_mote_xf(n, b, xf, 0.0)
			n.draw_set_transform_matrix(Transform2D(0.0, origin) * xf)
			n.draw_line(Vector2(-4.0, R), Vector2(-4.0, R + 4.0), Kit.MOVER, 2.0)   # feet, toward g
			n.draw_line(Vector2(4.0, R), Vector2(4.0, R + 4.0), Kit.MOVER, 2.0)
			n.draw_set_transform(origin, 0.0, Vector2.ONE)
			var mode: String = D.mode
			_label_right(n, b, mode + (" · standing" if b.grounded else (" · in orbit" if planet else " · falling")), Vector2(b.w - 8.0, 14.0), Kit.DIM)
			Kit.label(n, b, "up = (%.1f, %.1f)" % [-gdx, -gdy], Vector2(8.0, 14.0), Kit.GOOD)
			Kit.label(n, b, D.label, Vector2(b.w / 2.0, b.h - 8.0), Color(0.91, 0.898, 0.957, 0.55), true)
		"zipline":
			var x: float = b.x
			var y: float = b.y
			var v: float = b.v
			var vx: float = b.vx
			var vy: float = b.vy
			var tx: float = b.tx
			var ty: float = b.ty
			var gAlong: float = b.gAlong
			var st: String = b.state
			var flash: float = b.flash
			# the rail and its posts
			var rail := PackedVector2Array()
			for i in 49:
				var px: float = b.w * i / 48.0
				rail.append(Vector2(px, _z_rail_y(b, px)))
			n.draw_polyline(rail, Kit.BONE, 2.0)
			Kit.line(n, Vector2(b.w * 0.02, _z_rail_y(b, b.w * 0.02)), Vector2(b.w * 0.02, b.gy), _a(Kit.BONE, 0.45), 3.0)
			Kit.line(n, Vector2(b.w * 0.98, _z_rail_y(b, b.w * 0.98)), Vector2(b.w * 0.98, b.gy), _a(Kit.BONE, 0.45), 3.0)
			Kit.ground(n, b)
			var trail: Array = b.trail
			var tn: int = b.tn
			var ti: int = b.ti
			var tl := trail.size()
			for i in tn:
				var p: Vector2 = trail[(ti - 1 - i + tl * 2) % tl]
				Kit.dot(n, p, 1.2, _a(Kit.MOVER, 0.3 - i / float(tl) * 0.3))
			if st == "ride":                                 # the tangent, gravity's share of it, the speed
				var S: float = b.h * 0.07
				Kit.arrow(n, Vector2(x, y - R), Vector2(x + tx * 26.0, y - R + ty * 26.0), Kit.TARGET)
				Kit.arrow(n, Vector2(x, y), Vector2(x + tx * gAlong / b.h * S * 2.0, y + ty * gAlong / b.h * S * 2.0), Kit.HOT)
				Kit.line(n, Vector2(x, y - R), Vector2(x, y - R - 6.0), Kit.BONE, 2.0)   # the hand on the rail
				Kit.label(n, b, "t̂", Vector2(x + tx * 26.0 + 6.0, y - R + ty * 26.0 + 3.0), Kit.TARGET)
				Kit.label(n, b, "g·t̂ᵧ %.2f%s" % [gAlong / b.h, " ↓" if gAlong > 0.0 else " ↑"], Vector2(x + 12.0, y + 14.0), Kit.HOT)
				Kit.label(n, b, "v %.2f W/s" % (v / b.w), Vector2(x, y - R - 12.0), Kit.MOVER, true)
			if st == "free":
				Kit.arrow(n, Vector2(x, y), Vector2(x + vx * 0.25, y + vy * 0.25), Kit.HOT if flash > 0.0 else _a(Kit.MOVER, 0.6))
				if absf(y - R - _z_rail_y(b, x)) < b.h * D.reach:
					Kit.label(n, b, "in reach — grab", Vector2(x, y - R * 2.2), Kit.GOOD, true)
			var ang: float
			if st == "ride":
				var sg := signf(_or1(v))
				ang = atan2(ty * sg, tx * sg)
			elif st == "free":
				ang = atan2(vy, _or1(vx))
			elif st == "walk":
				ang = PI
			else:
				ang = -PI / 2.0
			Kit.mote(n, b, Vector2(x, y), ang)
			_label_right(n, b, st, Vector2(b.w - 8.0, 14.0), Kit.DIM)
			Kit.label(n, b, D.label, Vector2(b.w / 2.0, b.h - 8.0), Color(0.91, 0.898, 0.957, 0.55), true)
		"minecart":
			var x: float = b.x
			var v: float = b.v
			var tx: float = b.tx
			var ty: float = b.ty
			var gAlong: float = b.gAlong
			var flash: float = b.flash
			var station: float = b.station
			var period: float = b.period
			var y := _mc_track_y(b, x)
			# the track: two rails and sleepers, periodic in W
			for r in [-1.0, 1.0]:
				var rail := PackedVector2Array()
				for i in 65:
					var px: float = b.w * i / 64.0
					rail.append(Vector2(px, _mc_track_y(b, px) + r * 2.0))
				n.draw_polyline(rail, Kit.BONE, 1.5)
			for i in range(0, 64, 2):
				var px: float = b.w * i / 64.0
				var py := _mc_track_y(b, px)
				Kit.line(n, Vector2(px, py - 4.0), Vector2(px, py + 4.0), _a(Kit.BONE, 0.35), 1.0)
			Kit.ground(n, b)
			# the station
			for i in int(D.humps):
				var sx: float = station + i * period
				var near: bool = flash > 0.0 and absf(x - sx) < period * 0.5
				Kit.rect(n, Rect2(sx - 5.0, _mc_track_y(b, sx) + 6.0, 10.0, 10.0), Kit.HOT if near else _a(Kit.TARGET, 0.5))
				Kit.label(n, b, "push", Vector2(sx, _mc_track_y(b, sx) + 26.0), Kit.HOT if near else Kit.TARGET, true)
			# the cart, rotated onto the tangent
			var ang := atan2(ty, tx)
			n.draw_set_transform(origin + Vector2(x, y), ang, Vector2.ONE)
			Kit.rect(n, Rect2(-11.0, -10.0, 22.0, 8.0), _a(Kit.BONE, 0.7))
			Kit.dot(n, Vector2(-6.0, 0.0), 3.0, Kit.BONE)
			Kit.dot(n, Vector2(6.0, 0.0), 3.0, Kit.BONE)
			n.draw_set_transform(origin, 0.0, Vector2.ONE)
			Kit.mote(n, b, Vector2(x + sin(ang) * 14.0, y - cos(ang) * 14.0), ang + PI if v < 0.0 else ang, Kit.MOVER, 6.0)
			# the tangent, gravity's share of it, the numbers
			var S: float = b.h * 0.075
			Kit.arrow(n, Vector2(x, y), Vector2(x + tx * 28.0, y + ty * 28.0), Kit.TARGET)
			Kit.arrow(n, Vector2(x, y), Vector2(x + tx * gAlong / b.h * S, y + ty * gAlong / b.h * S), Kit.HOT)
			Kit.label(n, b, "θ %.0f°" % (ang * 57.3), Vector2(x + tx * 28.0 + 8.0, y + ty * 28.0 + 3.0), Kit.TARGET)
			Kit.label(n, b, "g·sin θ %.2f" % (gAlong / b.h), Vector2(x, y + 22.0), Kit.HOT, true)
			if flash > 0.0:
				Kit.label(n, b, "+%s W/s" % _num(D.push), Vector2(x, y - 24.0), _a(Kit.HOT, flash * 2.0), true)
			Kit.label(n, b, "v %.2f W/s" % (v / b.w), Vector2(8.0, 14.0), Kit.MOVER)
			_label_right(n, b, "rolling back" if v < 0.0 else ("downhill" if gAlong > 0.0 else "climbing"), Vector2(b.w - 8.0, 14.0), Kit.DIM)
			Kit.label(n, b, D.label, Vector2(b.w / 2.0, b.h - 8.0), Color(0.91, 0.898, 0.957, 0.55), true)
		"brittle":
			var P: Array = b.P
			var py: float = b.h * D.platY
			var pw: float = b.w * D.platW
			var x: float = b.x
			var y: float = b.y
			var st: String = b.state
			var on: int = b.on
			Kit.ground(n, b)
			# draw the platforms
			for i in 3:
				var p: Dictionary = P[i]
				var k: float = clampf(p.tm / p.hold, 0.0, 1.0)
				if p.state == "gone":
					_dash_rect(n, Rect2(p.x - pw / 2.0, py, pw, 6.0), 3.0, 3.0, Kit.DIM, 1.0)
					Kit.label(n, b, "back in %.1f s" % maxf(0.0, D.respawn - p.tm), Vector2(p.x, py - 6.0), Kit.DIM, true)
					continue
				var a: float = 1.0 - clampf(p.tm / D.fade, 0.0, 1.0) if p.state == "fall" else 1.0
				Kit.rect(n, Rect2(p.x - pw / 2.0 + p.jx, p.y + p.jy, pw, 6.0), _a(Kit.BONE, 0.75 * a))
				var cracks: int = int(floorf(k * 5.0)) if p.state == "shake" else (5 if p.state == "fall" else 0)
				for c in cracks:
					var cx: float = p.x - pw / 2.0 + pw * (c + 0.5) / 5.0 + p.jx
					Kit.line(n, Vector2(cx, p.y + p.jy), Vector2(cx + 3.0, p.y + p.jy + 6.0), _a(Kit.NIGHT, 0.9 * a), 1.0)
				if p.state == "shake":
					Kit.rect(n, Rect2(p.x - pw / 2.0, py - 12.0, pw, 3.0), _a(Kit.INK, 0.12))
					Kit.rect(n, Rect2(p.x - pw / 2.0, py - 12.0, pw * (1.0 - k), 3.0), Kit.HOT if k > 0.7 else Kit.TARGET)
					Kit.label(n, b, "%.1f s" % (p.hold - p.tm), Vector2(p.x, py - 16.0), Kit.HOT if k > 0.7 else Kit.TARGET, true)
				elif p.state == "idle":
					Kit.label(n, b, "holds %.1f s" % p.hold, Vector2(p.x, py - 6.0), Kit.DIM, true)
				elif p.state == "fall":
					Kit.label(n, b, "α %.2f" % a, Vector2(p.x + pw / 2.0 + 6.0, p.y + 6.0), _a(Kit.INK, a))
			Kit.mote(n, b, Vector2(x, y), atan2(b.vy, _or1(b.vx)) if st == "air" else 0.0)
			_label_right(n, b, st + (" on #%d" % (on + 1) if on >= 0 else ""), Vector2(b.w - 8.0, 14.0), Kit.DIM)
			Kit.label(n, b, D.label, Vector2(b.w / 2.0, b.h - 8.0), Color(0.91, 0.898, 0.957, 0.55), true)
		"bouncepad":
			var lx: float = b.w * 0.28
			var rx: float = b.w * 0.72
			var room: float = b.gy - 12.0
			var apex: float = b.apex
			var h: float = room * apex
			var padH := 6.0
			var lsq: float = b.lsq
			var rsq: float = b.rsq
			var rTop: float = b.rTop
			var sq: float = D.squash
			Kit.ground(n, b)
			# the designed apex line, and the decaying one
			_dashed(n, Vector2(lx - b.w * 0.2, b.gy - padH - h), Vector2(lx + b.w * 0.2, b.gy - padH - h), 4.0, 4.0, Kit.TARGET, 1.5)
			_dashed(n, Vector2(rx - b.w * 0.2, rTop), Vector2(rx + b.w * 0.2, rTop), 4.0, 4.0, Kit.DIM, 1.0)
			Kit.label(n, b, "h = %.2f · designed" % apex, Vector2(lx, b.gy - padH - h - 5.0), Kit.TARGET, true)
			Kit.label(n, b, "last apex ×e²", Vector2(rx, rTop - 5.0), Kit.DIM, true)
			# the pad, squashed
			var pw: float = b.w * D.padW * (1.0 + 0.4 * lsq * sq)
			var ph: float = padH * maxf(0.2, 1.0 - 0.7 * lsq * sq)
			Kit.rect(n, Rect2(lx - pw / 2.0, b.gy - ph, pw, ph), Kit.GOOD if lsq > 0.0 else _a(Kit.GOOD, 0.6))
			for i in range(-1, 2):
				Kit.line(n, Vector2(lx + i * pw * 0.25, b.gy - ph), Vector2(lx + i * pw * 0.25 + 4.0, b.gy - ph - 3.0 * (1.0 - lsq)), _a(Kit.GOOD, 0.5), 1.0)
			# the two balls, squashed on contact (the web's translate + scale round the mote)
			for ball in [[lx, b.ly, lsq, Kit.MOVER, b.lvy], [rx, b.ry, rsq, Kit.BONE, b.rvy]]:
				var bx: float = ball[0]
				var by: float = ball[1]
				var bs: float = ball[2]
				var bc: Color = ball[3]
				var bvy: float = ball[4]
				var xf := Transform2D(0.0, Vector2(bx, by + R * 0.5 * bs * sq)) * Transform2D(0.0, Vector2(1.0 + 0.5 * bs * sq, maxf(0.2, 1.0 - 0.5 * bs * sq)), 0.0, Vector2.ZERO)
				_mote_xf(n, b, xf, -PI / 2.0 * (1.0 if bvy < 0.0 else -1.0), bc)
			if lsq > 0.3:
				Kit.label(n, b, "vy = −√(2gh) = %.2f H/s" % (b.lv0 / b.h), Vector2(lx, b.gy - padH - R * 3.0), Kit.GOOD, true)
			if rsq > 0.3:
				Kit.label(n, b, "vy = −e·vy · e = %s" % _num(D.e), Vector2(rx, b.gy - R * 3.0), Kit.HOT, true)
			Kit.label(n, b, "pad", Vector2(lx, 14.0), Kit.GOOD, true)
			Kit.label(n, b, "restitution", Vector2(rx, 14.0), Kit.BONE, true)
			Kit.label(n, b, "vy %.2f" % (-b.lvy / b.h), Vector2(lx + R + 6.0, b.ly + 3.0), Kit.MOVER)
			Kit.label(n, b, "vy %.2f" % (-b.rvy / b.h), Vector2(rx + R + 6.0, b.ry + 3.0), Kit.DIM)
			Kit.label(n, b, D.label, Vector2(b.w / 2.0, b.h - 8.0), Color(0.91, 0.898, 0.957, 0.55), true)
