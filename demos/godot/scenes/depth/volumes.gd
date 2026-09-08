extends RefCounted
## VOLUMES NEAR & FAR — 13 pictures, ported from the web atlas (docs/depth.js).
## Smoke, flame, sparkle, fog: things without edges. What makes a puff of
## smoke look NEAR is not one cue but five moving together — bigger, darker
## (or brighter, if it glows), faster, firmer-edged, and less mixed with the
## colour of the air. So every particle here carries one number, z (0 = far,
## 1 = near), and everything else is read off it. Sort far → near before
## drawing so the near ones cover the far ones (the painter's order).
##
## The web page draws volumes made of LIGHT (flame, sparkle, steam) with the
## "lighter" blend so they add up hot where they overlap. Godot's _draw() has
## no per-call blend mode, so those cards approximate light with translucent
## K.soft glows layered over each other — overlaps still brighten, they just
## stop short of burning to white. Volumes made of matter (smoke, ash, dust,
## fog) cover, exactly as on the web.
##
## Each def: letter, name, hint, dials (D), rhyme { name, hint, dials } and
## the callables init(b) / tick(b, dt) / press(b, pos) / draw(n, b). The
## rhyme's dials are merged over D on right-click — nothing else changes.

const K := preload("res://scenes/depth/kit.gd")

const TITLE := "Volumes near & far"
const BLURB := "smoke, flame, sparkle sorted by depth — the near ones bigger, brighter, faster; the far ones fading into the air"

const ARMS := 5                                       # Jellyfish: tentacles per bell …
const SEGS := 8                                       # … and chain points per tentacle

## A point on a quadratic curve p0 → p2 bent by p1.
static func _quad(p0: Vector2, p1: Vector2, p2: Vector2, k: float) -> Vector2:
	var j := 1.0 - k
	return p0 * (j * j) + p1 * (2.0 * j * k) + p2 * (k * k)

## A teardrop of flame: two quadratic curves meeting at the tip, filled with
## the web's vertical gradient (solid at the base, gone at the tip) by giving
## every outline vertex the colour the gradient has at its height.
static func _tongue(n: CanvasItem, x: float, y: float, w: float, h: float, lean: float, c: Color, a: float) -> void:
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var p0 := Vector2(x - w / 2.0, y)
	var p1 := Vector2(x - w / 2.0 + lean * 0.3, y - h * 0.55)
	var tip := Vector2(x + lean, y - h)
	var q1 := Vector2(x + w / 2.0 + lean * 0.3, y - h * 0.55)
	var q2 := Vector2(x + w / 2.0, y)
	var steps := 8
	for s in steps + 1: pts.append(_quad(p0, p1, tip, float(s) / steps))
	for s in range(1, steps + 1): pts.append(_quad(tip, q1, q2, float(s) / steps))
	for p in pts:
		var k := clampf((y - p.y) / maxf(h, 0.001), 0.0, 1.0)
		var al := lerpf(a, a * 0.8, k / 0.6) if k < 0.6 else lerpf(a * 0.8, 0.0, (k - 0.6) / 0.4)
		cols.append(K.alpha(c, al))
	K.lin_poly(n, pts, cols)

## A four-point twinkle: 8 vertices, long, short, long, short…
static func _star4(n: CanvasItem, p: Vector2, r: float, c: Color) -> void:
	var pts := PackedVector2Array()
	for k in 8:
		var ang := k * TAU / 8.0
		var rr := r * 0.3 if k % 2 == 1 else r
		pts.append(p + Vector2(cos(ang), sin(ang)) * rr)
	K.poly(n, pts, c)

## The colour of a stop list [[k, Color], …] at k — piecewise linear.
static func _stop_col(st: Array, k: float) -> Color:
	for i in st.size() - 1:
		var k0: float = st[i][0]
		var k1: float = st[i + 1][0]
		if k <= k1:
			var f := 0.0 if k1 - k0 < 1e-6 else (k - k0) / (k1 - k0)
			return (st[i][1] as Color).lerp(st[i + 1][1], clampf(f, 0.0, 1.0))
	return st[st.size() - 1][1]

## Where point p sits in a canvas radial gradient (0 = the inner point at
## c + off, 1 = the rim circle (c, r)): the circle through p has centre
## c + off·(1 − k) and radius k·r, which is one quadratic in k.
static func _rad_k(p: Vector2, c: Vector2, r: float, off: Vector2) -> float:
	var d := p - c - off
	var qa := off.length_squared() - r * r          # negative while the inner point is inside the rim
	var qb := 2.0 * d.dot(off)
	var qc := d.length_squared()
	if absf(qa) < 1e-6:
		return clampf(-qc / qb, 0.0, 1.0) if absf(qb) > 1e-9 else 1.0
	var disc := qb * qb - 4.0 * qa * qc
	if disc < 0.0: return 1.0
	return clampf((-qb - sqrt(disc)) / (2.0 * qa), 0.0, 1.0)

## A radial gradient CLIPPED to a shape (the web's rad fill inside a path):
## a fan from the inner point out to the outline, each spoke cut into steps,
## every vertex coloured exactly. The outline must wrap around c + off.
static func _radial_in(n: CanvasItem, outline: PackedVector2Array, c: Vector2, r: float, stops: Array, off := Vector2.ZERO, steps := 4) -> void:
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var m := outline.size()
	var o := c + off
	pts.append(o); cols.append(_stop_col(stops, 0.0))
	for i in m:
		for s in range(1, steps + 1):
			var p := o.lerp(outline[i], float(s) / steps)
			pts.append(p); cols.append(_stop_col(stops, _rad_k(p, c, r, off)))
	for i in m:
		var a := 1 + i * steps
		var bb := 1 + ((i + 1) % m) * steps
		idx.append(0); idx.append(a); idx.append(bb)
		for s in steps - 1:
			idx.append(a + s); idx.append(bb + s); idx.append(bb + s + 1)
			idx.append(a + s); idx.append(bb + s + 1); idx.append(a + s + 1)
	RenderingServer.canvas_item_add_triangle_array(n.get_canvas_item(), idx, pts, cols)

static func defs() -> Array:
	var d: Array = []

	# ---- A · Ash -----------------------------------------------------------
	d.append({ "letter": "A", "name": "Ash", "drag": true,
		"hint": "flakes falling over a burnt-out night: one z per flake sets size, greyness, speed and a touch of blur — near ones big and fast, far ones tiny and slow; press sets a wind, and the light far flakes take it first, the heavy near ones a second or two later",
		"dials": { "sky": [Color("0A0608"), Color("2A1410")], "glow": Color("F58A4A"), "near": Color("E8E4E0"), "far": Color("5A5458"),
			"flakes": 80, "fall": 0.35, "wind": 0.0, "seed": 31,
			"gust": 0.25,               # the sideways speed a full wind asks of a flake, screens per second
			"response": 1.0,            # how quickly the lightest (farthest) flake's drift takes up the wind, per second — a near, heavy flake takes it slower
			"flutter": 1.0,             # how wide a flake swings on its own as it tumbles (1 = 3 px far … 15 px near)
			"label": "matter covers: near flakes big, pale, fast, slightly blurred — far ones tiny, dim, slow, fogged, and first to take the wind" },
		"rhyme": { "name": "Snowfall", "hint": "the same falling flakes in white over a blue night, half the speed — the ash code IS the snow code",
			"dials": { "sky": [Color("060A1E"), Color("1A2A50")], "glow": Color("8AA0D8"), "near": Color.WHITE, "far": Color("8A98B8"), "fall": 0.18,
				"label": "change four colours and one speed: the ruin becomes a village and the ash becomes snow" } },
		"init": func(b: Dictionary) -> void:
			var D: Dictionary = b.D
			var R := K.rng(int(D.seed))
			var nn := int(D.flakes)
			b.flakes = []
			for j in nn: b.flakes.append({ "x": R.randf(), "ph": R.randf(), "z": R.randf() })
			b.flakes.sort_custom(func(p, q): return p.z < q.z)           # far first, near last — painter's order
			# the motion, one slot per flake in that order (sized here: a packed array read back from b is a copy):
			# fx / vx the drift and its speed in screens, sw / sv the swing and its speed in px, nx the seconds to the next tumble
			var fx := PackedFloat32Array(); fx.resize(nn)
			var vx := PackedFloat32Array(); vx.resize(nn)
			var sw := PackedFloat32Array(); sw.resize(nn)
			var sv := PackedFloat32Array(); sv.resize(nn)
			var nx := PackedFloat32Array(); nx.resize(nn)
			for j in nn:
				fx[j] = b.flakes[j].x
				nx[j] = R.randf() * 2.0
			b.fx = fx; b.vx = vx; b.sw = sw; b.sv = sv; b.nx = nx,
		"tick": func(b: Dictionary, dt: float) -> void:
			# the fall is a steady rate (a flake at terminal velocity), but the DRIFT is
			# simulated: each flake carries a sideways velocity that the wind drags toward
			# its own speed — a light far flake takes it up in a quarter of a second, a
			# heavy near one over a second or two — so a press does not turn the whole
			# field on one frame: the gust sweeps through it, back to front. the flutter
			# is a pendulum swing about the flake's path, kicked at random moments as it
			# tumbles and catches the air, under-damped so it swings past and back.
			var D: Dictionary = b.D
			var R: RandomNumberGenerator = b.rng
			var flakes: Array = b.flakes
			var fx: PackedFloat32Array = b.fx
			var vx: PackedFloat32Array = b.vx
			var sw: PackedFloat32Array = b.sw
			var sv: PackedFloat32Array = b.sv
			var nx: PackedFloat32Array = b.nx
			var want: float = float(D.wind) * float(D.gust)
			var response: float = D.response
			var flutter: float = D.flutter
			var sub := maxi(1, ceili(dt * 50.0))                           # substeps of ≤ 0.02 s keep the springs stable at any frame rate
			var h := dt / float(sub)
			for j in flakes.size():
				var z: float = flakes[j].z
				var rate := response / (0.25 + z * 1.5)                    # heavier = slower to take the wind
				var ks := 9.0 / (0.5 + z)                                  # the swing: near flakes are wider, slower pendulums
				var w := sqrt(ks)
				var ds := 0.25 * 2.0 * w                                   # a quarter of critical
				var amp := flutter * (3.0 + z * 12.0)
				nx[j] -= dt
				if nx[j] <= 0.0:                                           # a tumble catches the air: a kick of amp·ω swings it about amp
					nx[j] = 0.6 + R.randf() * 1.6
					sv[j] += (-1.0 if R.randf() < 0.5 else 1.0) * (0.5 + R.randf()) * amp * w
				for _s in sub:
					vx[j] += (want - vx[j]) * rate * h                     # the wind drags the drift toward its own speed
					fx[j] += vx[j] * h
					sv[j] += (ks * (0.0 - sw[j]) - ds * sv[j]) * h
					sw[j] = clampf(sw[j] + sv[j] * h, -amp * 3.0, amp * 3.0)
				fx[j] -= floorf(fx[j]),                                    # wrap: out one side, in the other
		"press": func(b: Dictionary, pos: Vector2) -> void: b.D.wind = (pos.x / b.W - 0.5) * 2.0,   # click left/right = the wind the drifts will chase
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var t: float = b.t
			var W: float = b.W; var H: float = b.H
			var sky: Array = D.sky
			K.sky(n, b, sky)
			K.soft(n, Vector2(W * 0.5, H * 0.82), W * 0.6, D.glow, 0.35)   # something still burning below the rise
			K.ground(n, b, H * 0.8, Color("050305"))
			for k in 5: n.draw_rect(Rect2(W * (0.08 + k * 0.2), H * (0.62 + (k % 2) * 0.08), W * 0.07, H * 0.2), Color("050305"))   # ruined walls
			var fall: float = D.fall
			var flakes: Array = b.flakes
			var fx: PackedFloat32Array = b.fx
			var sw: PackedFloat32Array = b.sw
			for j in flakes.size():
				var f: Dictionary = flakes[j]
				var z: float = f.z                                       # z: 0 far … 1 near
				var p := fposmod(t * fall * (0.3 + z) + f.ph, 1.0)      # near flakes fall faster
				var y := p * (H + 20.0) - 10.0
				var x := fx[j] * W + sw[j]
				var c := K.fog(K.mix(D.far, D.near, z), (1.0 - z) * 0.6, sky[1])   # far flakes take on the glow-lit air
				var r := 0.6 + z * 3.2; var a := 0.15 + z * 0.8
				if z > 0.6: K.soft(n, Vector2(x, y), r * 2.4, c, a * 0.35)   # the nearest are a touch out of focus
				K.dot(n, Vector2(x, y), r, K.alpha(c, a))
			K.label(n, b, D.label) })

	# ---- B · Blaze ---------------------------------------------------------
	d.append({ "letter": "B", "name": "Blaze", "drag": true,
		"hint": "flame in three depth planes: back tongues dark red, soft, slow; middle orange; front ones yellow-white, sharp, fast — additive, so overlaps burn hot",
		"dials": { "sky": [Color("0A0508"), Color("1E0A08")], "planes": [Color("8A1E10"), Color("F07A20"), Color("FFF0A0")],   # far → near
			"per": 6, "speed": 1.0, "gust": 0.0, "seed": 7,
			"label": "z picks the plane: back = dark, soft, slow; front = bright, sharp, fast. Light adds, so overlaps burn white" },
		"rhyme": { "name": "Spirit fire", "hint": "the same three planes of flame in blue-green, burning at half speed — a ghost's hearth",
			"dials": { "sky": [Color("040A10"), Color("081A20")], "planes": [Color("0A3A5A"), Color("20B0A0"), Color("C8FFF0")], "speed": 0.5,
				"label": "cold colours and half the flicker: the same depth planes read as something that is not quite fire" } },
		"init": func(b: Dictionary) -> void:
			var D: Dictionary = b.D
			var R := K.rng(int(D.seed))
			var planes: Array = D.planes
			var per: int = D.per
			b.tongues = []
			for i in planes.size():                                       # plane by plane = already far → near
				for j in per:
					b.tongues.append({ "z": (i + 0.5) / planes.size(), "c": planes[i], "x": 0.2 + (j + R.randf() * 0.6) / per * 0.6,
						"ph": R.randf() * 9.0, "s": 0.7 + R.randf() * 0.6 }),
		"press": func(b: Dictionary, pos: Vector2) -> void: b.D.gust = (pos.x / b.W - 0.5) * 2.0,   # click left/right = a gust leans the flames
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var t: float = b.t
			var W: float = b.W; var H: float = b.H
			K.sky(n, b, D.sky)
			var GY := H * 0.82
			K.ground(n, b, GY, Color("050305"))
			# the web switches to "lighter" here — light adds; we layer translucent glows instead
			var planes: Array = D.planes
			K.soft(n, Vector2(W / 2.0, GY), W * 0.45, planes[1], 0.25)     # the light the fire throws on the ground
			var speed: float = D.speed; var gust: float = D.gust
			for g in b.tongues:
				var z: float = g.z
				var sp := speed * (1.5 + z * 3.0)                            # near planes flicker faster
				var h: float = H * (0.18 + z * 0.3) * g.s * (0.8 + 0.2 * sin(t * sp + g.ph))
				var w := W * (0.05 + z * 0.06)
				var lean := sin(t * sp * 1.3 + g.ph) * w * 0.6 + gust * w * 1.5
				var x: float = W * g.x
				var y := GY - (1.0 - z) * H * 0.03                          # far tongues stand a little farther back
				K.soft(n, Vector2(x + lean * 0.4, y - h * 0.4), h * 0.5, g.c, 0.12 + (1.0 - z) * 0.3)   # far = mostly halo
				_tongue(n, x, y, w, h, lean, g.c, 0.3 + z * 0.65)           # near = mostly crisp shape
			K.label(n, b, D.label) })

	# ---- D · Dustcloud -----------------------------------------------------
	d.append({ "letter": "D", "name": "Dustcloud", "drag": true,
		"hint": "a dust cloud rolling along the ground: each puff is a ball lit from one side (inner point pushed toward the light); near puffs darker, bigger, faster",
		"dials": { "sky": [Color("C8B89A"), Color("E8D8B8")], "dust": Color("B08A5A"), "puffs": 36, "roll": 1.0, "lightX": -1.0, "seed": 17,   # lightX: -1 sun on the left, +1 on the right
			"label": "one radial gradient per puff, inner point toward the sun; z sets size, darkness, speed and where it sits" },
		"rhyme": { "name": "Sandstorm", "hint": "the same lit puffs in ochre, sixty of them rolling nearly three times as fast — the sky itself goes the colour of sand",
			"dials": { "sky": [Color("B07A3A"), Color("E0B070")], "dust": Color("C89050"), "puffs": 60, "roll": 2.6,
				"label": "more puffs, more speed, and the air the same colour as the dust: the far ones vanish into it entirely" } },
		"init": func(b: Dictionary) -> void:
			var D: Dictionary = b.D
			var R := K.rng(int(D.seed))
			b.puffs = []
			for j in int(D.puffs): b.puffs.append({ "x": R.randf(), "z": R.randf(), "ph": R.randf() * 9.0 })
			b.puffs.sort_custom(func(p, q): return p.z < q.z),           # far first
		"press": func(b: Dictionary, pos: Vector2) -> void: b.D.lightX = (pos.x / b.W - 0.5) * 2.0,   # click = move the sun left/right
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var t: float = b.t
			var W: float = b.W; var H: float = b.H
			var sky: Array = D.sky
			K.sky(n, b, sky)
			var GY := H * 0.72
			K.lin_rect(n, Rect2(0, GY, W, H - GY), [K.shade(D.dust, -0.1), K.shade(D.dust, -0.45)])
			var roll: float = D.roll; var lightX: float = D.lightX
			for q in b.puffs:
				var z: float = q.z
				var r := W * (0.05 + z * 0.09); var span := W + r * 2.0
				var x := fposmod(q.x * span + t * roll * (15.0 + z * 55.0), span) - r   # near puffs roll past faster
				var y := GY + z * H * 0.12 - r * 0.4 + sin(t * (0.8 + z) + q.ph) * 3.0   # near puffs sit lower on the ground plane
				var c := K.fog(K.shade(D.dust, -0.45 * z), (1.0 - z) * 0.7, sky[1])   # near = darker; far = paler, into the sky
				var a := 0.35 + z * 0.5
				# a lit edge and a dark edge = a round puff
				K.radial(n, Vector2(x, y), r, [[0.0, K.alpha(K.shade(c, 0.4), a)], [0.55, K.alpha(c, a)], [1.0, K.alpha(K.shade(c, -0.3), 0.0)]],
					Vector2(lightX * r * 0.45, -r * 0.25))
			K.label(n, b, D.label) })

	# ---- F · Fireflies -----------------------------------------------------
	d.append({ "letter": "F", "name": "Fireflies",
		"hint": "points of light over a dusk meadow: z sets each one's size, brightness, blink speed and wander — near ones wear a wide halo, far ones are pinpricks",
		"dials": { "sky": [Color("1A1E4A"), Color("5A3A5A"), Color("2A3A2A")], "glow": Color("D8F07A"), "flies": 40, "halo": 1.0, "seed": 23,
			"label": "a point of light has a depth too: size, brightness, blink rate and halo width all read off z" },
		"rhyme": { "name": "Will-o'-wisps", "hint": "the same wandering lights in teal over a swamp, with halos twice as wide — the near ones become lanterns",
			"dials": { "sky": [Color("0A1A1E"), Color("1A3A3A"), Color("0E2A1E")], "glow": Color("60F0D0"), "halo": 2.2,
				"label": "the halo dial is the whole difference between an insect and a haunting" } },
		"init": func(b: Dictionary) -> void:
			var D: Dictionary = b.D
			var R := K.rng(int(D.seed))
			b.flies = []
			for j in int(D.flies):
				b.flies.append({ "x": R.randf(), "y": 0.3 + R.randf() * 0.5, "z": R.randf(), "a": 0.3 + R.randf() * 0.5, "b": 0.2 + R.randf() * 0.4, "ph": R.randf() * 9.0 })
			b.flies.sort_custom(func(p, q): return p.z < q.z)            # far first
			b.grass = []
			for k in 30: b.grass.append([R.randf(), 0.06 + R.randf() * 0.1, R.randf() * 9.0]),
		"press": func(b: Dictionary, pos: Vector2) -> void:
			for f in b.flies:                                               # near ones gather most
				f.x += (pos.x / b.W - f.x) * 0.4 * f.z
				f.y += (pos.y / b.H - f.y) * 0.4 * f.z,
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var t: float = b.t
			var W: float = b.W; var H: float = b.H
			var sky: Array = D.sky
			K.sky(n, b, [[0.0, sky[0]], [0.6, sky[1]], [1.0, sky[2]]])
			var GY := H * 0.8
			K.ground(n, b, GY, Color("0A140A"))
			for g in b.grass:
				K.line(n, Vector2(g[0] * W, GY + 1.0), Vector2(g[0] * W + sin(t * 0.8 + g[2]) * 3.0, GY - g[1] * H), Color("0A140A"), 1.5)
			# the web adds these with "lighter"; translucent glows stand in for the addition
			var halo: float = D.halo
			for f in b.flies:
				var z: float = f.z
				var wander := 0.3 + z                                        # near ones wander wider
				var x: float = f.x * W + sin(t * f.a + f.ph) * W * 0.08 * wander
				var y: float = f.y * H + sin(t * f.b * 1.3 + f.ph * 2.0) * H * 0.05 * wander
				var blink := pow(0.5 + 0.5 * sin(t * (0.8 + z * 3.0) + f.ph), 3.0)   # near ones blink faster
				var c := K.fog(D.glow, (1.0 - z) * 0.7, sky[1])
				var r := 0.6 + z * 2.2
				K.soft(n, Vector2(x, y), r * (3.0 + z * 8.0) * halo, c, (0.05 + 0.5 * z) * blink)   # the halo is the near one's badge
				K.dot(n, Vector2(x, y), r, K.alpha(c, (0.25 + z * 0.75) * blink))
			K.label(n, b, D.label) })

	# ---- G · Glitter -------------------------------------------------------
	d.append({ "letter": "G", "name": "Glitter",
		"hint": "four-point twinkles at many depths drifting up: far ones tiny, dim, slow; near ones big, bright, fast, wrapped in a soft halo — additive, in violet",
		"dials": { "sky": [Color("0A0616"), Color("1E1030")], "star": Color("E8C8FF"), "deep": Color("C9A0F5"), "count": 70, "drift": 1.0, "seed": 41,
			"label": "size, brightness, twinkle speed and halo all from one z — sorted far to near, added like light" },
		"rhyme": { "name": "Pixie dust", "hint": "the same twinkles in gold, twice as many, drifting up twice as fast — a trail that never settles",
			"dials": { "sky": [Color("0E0A06"), Color("2A1E10")], "star": Color("FFF4C0"), "deep": Color("F5C169"), "count": 140, "drift": 2.0,
				"label": "double the count and the depth sort matters more: near gold covers far gold, never the other way" } },
		"init": func(b: Dictionary) -> void:
			var D: Dictionary = b.D
			var R := K.rng(int(D.seed))
			b.stars = []
			for j in int(D.count): b.stars.append({ "x": R.randf(), "y": R.randf(), "z": R.randf(), "ph": R.randf() * 9.0 })
			b.stars.sort_custom(func(p, q): return p.z < q.z)            # far first
			b.burst = null,
		"press": func(b: Dictionary, pos: Vector2) -> void: b.burst = { "x": pos.x, "y": pos.y, "t": b.t },   # click = a burst of sparkle there
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var t: float = b.t
			var W: float = b.W; var H: float = b.H
			var sky: Array = D.sky
			K.sky(n, b, sky)
			# "lighter" on the web; here the halos are translucent and simply stack
			var drift: float = D.drift
			for s in b.stars:
				var z: float = s.z
				var tw := 0.5 + 0.5 * sin(t * (1.0 + z * 4.0) + s.ph)       # near ones twinkle faster
				var y := fposmod(s.y - t * drift * (0.01 + z * 0.05), 1.0) * H   # and drift up faster
				var x: float = s.x * W + sin(t * 0.5 + s.ph) * (2.0 + z * 8.0)
				var c := K.fog(K.mix(D.deep, D.star, z), (1.0 - z) * 0.7, sky[1])
				var r := (1.0 + z * 5.0) * (0.6 + 0.4 * tw); var a := (0.15 + z * 0.85) * (0.4 + 0.6 * tw)
				if z > 0.5: K.soft(n, Vector2(x, y), r * 3.0, c, 0.35 * z * tw)   # only the near half get a halo
				_star4(n, Vector2(x, y), r, K.alpha(c, a))
			if b.burst != null:
				var bu: Dictionary = b.burst
				var age: float = (t - bu.t) / 1.2                            # a ring of twelve, 1.2 s long
				if age < 1.0:
					for k in 12:
						var ang := k * TAU / 12.0; var dist := K.ease(age) * W * 0.18
						_star4(n, Vector2(bu.x + cos(ang) * dist, bu.y + sin(ang) * dist), 4.0 * (1.0 - age) + 0.5, K.alpha(D.star, 1.0 - age))
				else: b.burst = null
			K.label(n, b, D.label) })

	# ---- I · Incense -------------------------------------------------------
	d.append({ "letter": "I", "name": "Incense", "drag": true,
		"hint": "one thin ribbon of smoke: small soft dots along a sine path that widens, pales and thins with height — dark at the stick, air-coloured at the top",
		"dials": { "room": [Color("1A1418"), Color("0A080C")], "smoke": Color("3A3A48"), "pale": Color("C8C8D8"), "tip": Color("FF8A3A"), "dots": 60, "curl": 1.0,
			"label": "height is distance here: darker, thinner and sharper at the stick; paler, wider and fainter as it climbs" },
		"rhyme": { "name": "Cigarette", "hint": "the same ribbon in plain grey, curling twice as fast, thinner and shorter — a bar at closing time",
			"dials": { "room": [Color("141416"), Color("08080A")], "smoke": Color("4A4A4C"), "pale": Color("A8A8AC"), "tip": Color("FF6A2A"), "dots": 40, "curl": 2.4,
				"label": "fewer dots and a quicker curl: the same ribbon, restless instead of ceremonial" } },
		"init": func(b: Dictionary) -> void: b.current = 0.0,
		"press": func(b: Dictionary, pos: Vector2) -> void: b.current = (pos.x / b.W - 0.5) * 2.0,   # click left/right = an air current
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var t: float = b.t
			var W: float = b.W; var H: float = b.H
			var room: Array = D.room
			var cx := W * 0.5; var sy := H * 0.78
			K.sky(n, b, room)
			K.line(n, Vector2(cx, H * 0.96), Vector2(cx, sy), Color("2A1E14"), 3.0)   # the stick
			n.draw_rect(Rect2(cx - W * 0.08, H * 0.94, W * 0.16, H * 0.03), Color("050305"))   # its holder
			var dots: int = D.dots; var curl: float = D.curl; var current: float = b.current
			for i in range(dots - 1, -1, -1):                                # top (far, pale) first; the stick end covers it
				var k := float(i) / dots                                     # 0 at the tip … 1 high up
				var y := sy - k * H * 0.72
				var x := cx + sin(k * 5.0 - t * 0.8 * curl) * W * (0.01 + k * 0.1) \
					+ sin(k * 13.0 - t * 1.7 * curl) * W * 0.02 * k + current * k * k * W * 0.3
				var r := 1.2 + k * 4.0 + k * k * 14.0                        # the ribbon widens as it climbs
				var c := K.fog(K.mix(D.smoke, D.pale, k), k * 0.6, room[0])  # pales with height, then into the room's air
				K.soft(n, Vector2(x, y), r, c, 0.75 * (1.0 - k * 0.8))       # and thins
			K.soft(n, Vector2(cx, sy), 9.0, D.tip, 0.6 * (0.7 + 0.3 * sin(t * 5.0)))   # the glowing tip
			K.dot(n, Vector2(cx, sy), 1.6, Color("FFE0A0"))
			K.label(n, b, D.label) })

	# ---- J · Jellyfish -----------------------------------------------------
	d.append({ "letter": "J", "name": "Jellyfish",
		"hint": "three of the same jelly at three depths: a dome is a radial gradient with alpha; the far one is smaller, paler, slower, and its glow dimmer — every bell snaps shut on a kicked spring and glides, its tentacles trailing and whipping after it; press to call them over",
		"dials": { "sea": [Color("0A2A50"), Color("041428")], "bell": Color("A8C8F0"), "core": Color("7AF0E0"), "bells": 3, "pulse": 1.0, "seed": 5,
			"snap": 60.0,               # the bell's spring: how hard it springs back open after a contraction
			"relax": 0.5,               # its damping as a fraction of critical — under 1, so it flares a touch past open before it settles
			"contract": 0.1,            # how much of the radius a full contraction takes in
			"thrust": 0.12,             # the swim each contraction buys, screens per second, toward where the jelly is headed
			"drag": 1.6,                # the water's drag on the glide, per second
			"sink": 0.02,               # how fast a jelly sinks between pulses, screens per second per second
			"arms": 90.0,               # a tentacle segment's spring toward hanging straight under the one above
			"armdamp": 0.3,             # its damping as a fraction of critical — low, so the tentacles overshoot and whip
			"label": "one jelly, three z: size, alpha, water-colour, pulse rate and glow all follow — a kicked spring for the bell, chains for the arms" },
		"rhyme": { "name": "Alien jellies", "hint": "the same bells in magenta, six of them at six depths, pulsing faster — a deeper, stranger sea",
			"dials": { "sea": [Color("1A0A30"), Color("08041A")], "bell": Color("F080D0"), "core": Color("FFB0F0"), "bells": 6, "pulse": 1.6,
				"label": "six depths instead of three and the ladder of size, alpha and speed becomes a staircase you can count" } },
		"init": func(b: Dictionary) -> void:
			var D: Dictionary = b.D
			var R := K.rng(int(D.seed))
			var bells: int = D.bells
			var W: float = b.W; var H: float = b.H
			b.jellies = []
			# tentacle segments in px, jelly-major then arm-major: [(j * ARMS + k) * SEGS + s] (sized here: a packed array read back from b is a copy)
			var px := PackedFloat32Array(); px.resize(bells * ARMS * SEGS)
			var py := PackedFloat32Array(); py.resize(bells * ARMS * SEGS)
			var tvx := PackedFloat32Array(); tvx.resize(bells * ARMS * SEGS)
			var tvy := PackedFloat32Array(); tvy.resize(bells * ARMS * SEGS)
			for j in bells:                                                 # built far → near
				var z := (j + 0.5) / bells
				var J := { "x": 0.15 + R.randf() * 0.7, "y": 0.25 + R.randf() * 0.35, "z": z, "vx": 0.0, "vy": 0.0, "c": 0.0, "cv": 0.0, "clk": R.randf() * 4.0 }   # position and glide in screens; c the contraction (0 open … 1 shut); clk the pulse clock
				J.hx = J.x; J.hy = J.y                                      # home: where it keeps swimming back to
				J.r0 = W * (0.05 + z * 0.09)                                # the open radius; a contraction takes it in from here
				for k in ARMS:                                              # hanging straight down to begin with
					for s in SEGS:
						var i := (j * ARMS + k) * SEGS + s
						px[i] = J.x * W - J.r0 * 0.7 + k * J.r0 * 0.35
						py[i] = J.y * H + (s + 1) * J.r0 * 0.35
				b.jellies.append(J)
			b.px = px; b.py = py; b.tvx = tvx; b.tvy = tvy,
		"tick": func(b: Dictionary, dt: float) -> void:
			# a jellyfish moves by pulsing. the bell is a spring around OPEN: every
			# period (2π/sp seconds, the old sine's beat) it takes a kick that snaps it
			# shut, and the spring relaxes it open again, flaring a touch past open
			# because the damping is under critical. the same kick is the swim: a shove
			# toward home (give or take a random heading, so they wander) and a little
			# lift, dying in the water's drag, while between pulses the jelly sinks.
			# each tentacle is a chain of eight points, every one a spring toward the
			# spot straight under the point above it, lightly damped — so when the rim
			# pulls in and the bell jerks up, the arms lag, trail, and whip through
			# after it. nothing here is a sine: the rhythm is a clock and everything
			# that moves is integrated.
			var D: Dictionary = b.D
			var R: RandomNumberGenerator = b.rng
			var W: float = b.W; var H: float = b.H
			var px: PackedFloat32Array = b.px
			var py: PackedFloat32Array = b.py
			var tvx: PackedFloat32Array = b.tvx
			var tvy: PackedFloat32Array = b.tvy
			var snap: float = D.snap
			var contract: float = D.contract
			var thrust: float = D.thrust
			var drag: float = D.drag
			var sink: float = D.sink
			var arms: float = D.arms
			var pulse_d: float = D.pulse
			var bd := float(D.relax) * 2.0 * sqrt(snap)                     # dampings from their fractions of critical
			var ad := float(D.armdamp) * 2.0 * sqrt(arms)
			var sub := maxi(1, ceili(dt * 50.0))                           # substeps of ≤ 0.02 s: the arm springs need √k·h small
			var h := dt / float(sub)
			var jellies: Array = b.jellies
			for j in jellies.size():
				var J: Dictionary = jellies[j]
				var z: float = J.z
				var sp := pulse_d * (0.6 + z * 1.2)                        # near ones pulse faster
				var per := TAU / sp
				var r0: float = J.r0
				var seg := r0 * 0.35
				for _s in sub:
					J.clk += h
					if J.clk >= per:                                       # the bell fires
						J.clk -= per
						J.cv += 2.0 * sqrt(snap)                           # a kick of 2ω shuts it about all the way
						var dx: float = J.hx - J.x
						var dy: float = J.hy - J.y
						var dist := sqrt(dx * dx + dy * dy)
						var ang := R.randf() * TAU if dist < 0.03 else atan2(dy, dx) + (R.randf() - 0.5) * 1.2   # headed home, roughly; at home, any way
						var go := thrust * (0.6 + z * 0.8)                 # the near one swims further per pulse
						J.vx += cos(ang) * go
						J.vy += sin(ang) * go - thrust * 0.6               # and every pulse lifts it a little
					J.cv += (snap * (0.0 - J.c) - bd * J.cv) * h           # the bell: a spring around open
					J.c = clampf(J.c + J.cv * h, -0.5, 1.5)
					J.vy += sink * h                                       # between pulses it sinks
					J.vx -= J.vx * drag * h                                # the glide dies in the water
					J.vy -= J.vy * drag * h
					J.x += J.vx * h
					J.y += J.vy * h
					if J.x < 0.04:                                         # the tank has walls
						J.x = 0.04; J.vx = 0.0
					elif J.x > 0.96:
						J.x = 0.96; J.vx = 0.0
					if J.y < 0.08:
						J.y = 0.08; J.vy = 0.0
					elif J.y > 0.85:
						J.y = 0.85; J.vy = 0.0
					var r: float = r0 * (1.0 - contract * float(J.c))
					var bx: float = J.x * W
					var by: float = J.y * H
					for k in ARMS:                                         # the tentacles: each point chases the spot under the one above
						var ax := bx - r * 0.7 + k * r * 0.35              # the anchor on the rim — it moves in as the bell shuts
						var ay := by
						for q in SEGS:
							var i := (j * ARMS + k) * SEGS + q
							tvx[i] += (arms * (ax - px[i]) - ad * tvx[i]) * h
							tvy[i] += (arms * (ay + seg - py[i]) - ad * tvy[i]) * h
							px[i] += tvx[i] * h
							py[i] += tvy[i] * h
							ax = px[i]
							ay = py[i],
		"press": func(b: Dictionary, pos: Vector2) -> void:
			for J in b.jellies:                                             # moves their homes — the near one's most — and they swim over in a few pulses
				J.hx += (pos.x / b.W - J.hx) * 0.5 * J.z
				J.hy += (pos.y / b.H - J.hy) * 0.5 * J.z,
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var W: float = b.W; var H: float = b.H
			var sea: Array = D.sea
			K.sky(n, b, sea)
			var contract: float = D.contract
			var px: PackedFloat32Array = b.px
			var py: PackedFloat32Array = b.py
			var jellies: Array = b.jellies
			for j in jellies.size():
				var J: Dictionary = jellies[j]
				var z: float = J.z
				var pulse: float = clampf(J.c, 0.0, 1.0)
				var r: float = J.r0 * (1.0 - contract * J.c)
				var x: float = J.x * W
				var y: float = J.y * H
				var c := K.fog(D.bell, (1.0 - z) * 0.75, sea[0]); var a := 0.25 + z * 0.45   # far = mostly water-coloured
				var tcol := K.alpha(c, a * 0.6); var tw := 0.6 + z * 1.2
				for k in ARMS:                                               # tentacles: the chains, drawn from the rim down
					var pts := PackedVector2Array([Vector2(x - r * 0.7 + k * r * 0.35, y)])
					for s in SEGS:
						var i := (j * ARMS + k) * SEGS + s
						pts.append(Vector2(px[i], py[i]))
					n.draw_polyline(pts, tcol, tw, true)
				# the dome: the top half-circle closed by a shallow curve, filled with a lit radial
				var outline := PackedVector2Array()
				for s in 17:
					var ang := PI + PI * s / 16.0
					outline.append(Vector2(x + cos(ang) * r, y + sin(ang) * r))
				for s in range(1, 8):
					outline.append(_quad(Vector2(x + r, y), Vector2(x, y + r * 0.35), Vector2(x - r, y), s / 8.0))
				_radial_in(n, outline, Vector2(x, y), r, [[0.0, K.alpha(K.shade(c, 0.5), a)], [0.7, K.alpha(c, a * 0.8)], [1.0, K.alpha(c, a * 0.2)]],
					Vector2(-r * 0.3, -r * 0.4))
				# the bioluminescent core adds on the web ("lighter"); a translucent glow stands in — brightest shut
				K.soft(n, Vector2(x, y - r * 0.2), r * 0.7, D.core, (0.15 + z * 0.5) * (0.6 + 0.4 * pulse))
			K.label(n, b, D.label) })

	# ---- M · Motes ---------------------------------------------------------
	d.append({ "letter": "M", "name": "Motes", "drag": true,
		"hint": "dust in a light shaft: the shaft is one gradient with alpha, a mote is bright only inside it — near motes large and lazy, far ones tiny; with the bounce dial up they hop under real gravity, land with a bounce, and lie still a moment before the next kick",
		"dials": { "room": [Color("141018"), Color("0A080C")], "light": Color("FFE8B0"), "motes": 60, "shaftX": 0.35, "bounce": 0.0, "seed": 29,   # bounce: 0 float, 1 snow-globe hop (the height of a fresh hop, in units of 8% of H, scaled by depth)
			"gravity": 2.5,             # the pull on a hopping mote, screen heights per second per second
			"rebound": 0.5,             # how much of its speed a mote keeps when it lands — each bounce a quarter the height of the last
			"rest": 0.5,                # the longest a landed mote lies still before its next kick, seconds
			"label": "the light is a gradient with alpha; a mote is bright where the light is and big only when it is near" },
		"rhyme": { "name": "Snow globe motes", "hint": "the same shaft of light in cold white, and the motes now hop instead of float — the bounce dial turned to one",
			"dials": { "room": [Color("0E1420"), Color("060A14")], "light": Color("E8F4FF"), "bounce": 1.0,
				"label": "near motes hop higher (the kick scales with z) and every landing bounces — even a toy obeys the depth rule" } },
		"init": func(b: Dictionary) -> void:
			var D: Dictionary = b.D
			var R := K.rng(int(D.seed))
			var nn := int(D.motes)
			b.motes = []
			for j in nn: b.motes.append({ "x": R.randf(), "y": R.randf(), "z": R.randf(), "ph": R.randf() * 9.0 })
			b.motes.sort_custom(func(p, q): return p.z < q.z)            # far first
			# the hop, one slot per mote in that order (sized here: a packed array read back from b is a copy):
			# ha the altitude above the mote's drift line in px, hv its speed, wait the pause before a kick
			var ha := PackedFloat32Array(); ha.resize(nn)
			var hv := PackedFloat32Array(); hv.resize(nn)
			var wait := PackedFloat32Array(); wait.resize(nn)
			for j in nn: wait[j] = R.randf()
			b.ha = ha; b.hv = hv; b.wait = wait,
		"tick": func(b: Dictionary, dt: float) -> void:
			# the drift is the old slow wander; the HOP is simulated. each mote has an
			# altitude above its own drift line and a vertical speed: gravity pulls the
			# speed down, the speed moves the altitude, and the drift line is a floor —
			# land, keep `rebound` of the speed, go up again a quarter as high, and when
			# the next bounce would be under half a pixel, lie still. a resting mote gets
			# a random kick after a random pause (the globe being shaken), sized so a
			# near mote's hop is taller than a far one's. at bounce 0 there are no kicks
			# and the motes float exactly as before.
			var D: Dictionary = b.D
			var R: RandomNumberGenerator = b.rng
			var H: float = b.H
			var motes: Array = b.motes
			var ha: PackedFloat32Array = b.ha
			var hv: PackedFloat32Array = b.hv
			var wait: PackedFloat32Array = b.wait
			var g: float = float(D.gravity) * H
			var bounce: float = D.bounce
			var rebound: float = D.rebound
			var rest: float = D.rest
			var sub := maxi(1, ceili(dt * 50.0))                           # substeps of ≤ 0.02 s so a coarse frame cannot tunnel through the floor
			var h := dt / float(sub)
			for j in motes.size():
				var z: float = motes[j].z
				var top := bounce * (0.3 + z) * H * 0.08                   # how high a fresh hop reaches: near motes higher
				for _s in sub:
					if ha[j] > 0.0 or hv[j] > 0.0:                         # in the air: gravity, then the floor
						hv[j] -= g * h
						ha[j] += hv[j] * h
						if ha[j] <= 0.0:
							ha[j] = 0.0
							hv[j] = -hv[j] * rebound                       # land: a bounce with part of the speed
							if hv[j] * hv[j] < 2.0 * g * 0.5:              # too small to see — lie still
								hv[j] = 0.0
								wait[j] = R.randf() * rest
					elif top > 0.0:                                        # at rest: the pause, then a kick
						wait[j] -= h
						if wait[j] <= 0.0:
							hv[j] = sqrt(2.0 * g * top) * (0.7 + 0.6 * R.randf()),   # √(2·g·top) reaches top; a little random so they scatter
		"press": func(b: Dictionary, pos: Vector2) -> void: b.D.shaftX = pos.x / b.W - 0.3 * (pos.y / b.H),   # click = the shaft passes through here
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var t: float = b.t
			var W: float = b.W; var H: float = b.H
			var room: Array = D.room
			K.sky(n, b, room)
			var shaftX: float = D.shaftX
			var x0 := W * shaftX; var slope := W * 0.3; var hw := W * 0.13   # the shaft leans right as it falls
			# the web skews a rect (x slides right as y goes down) — here the skew is drawn
			# directly as two parallelogram halves, transparent at the edges, 0.22 down the middle
			var light: Color = D.light
			var l0 := K.alpha(light, 0.0); var l1 := K.alpha(light, 0.22)   # "lighter" on the web: translucent here
			K.lin_poly(n, PackedVector2Array([Vector2(x0 - hw, 0), Vector2(x0, 0), Vector2(x0 + slope, H), Vector2(x0 - hw + slope, H)]),
				PackedColorArray([l0, l1, l1, l0]))
			K.lin_poly(n, PackedVector2Array([Vector2(x0, 0), Vector2(x0 + hw, 0), Vector2(x0 + hw + slope, H), Vector2(x0 + slope, H)]),
				PackedColorArray([l1, l0, l0, l1]))
			var motes: Array = b.motes
			var ha: PackedFloat32Array = b.ha
			for j in motes.size():
				var m: Dictionary = motes[j]
				var z: float = m.z
				var slow := 1.4 - z                                          # near motes drift slower (they are heavier, lazier)
				var x := fposmod(m.x + t * 0.012 * slow, 1.0) * W + sin(t * 0.4 + m.ph) * (3.0 + z * 6.0)
				var y := fposmod(m.y + t * 0.008 * slow, 1.0) * H - ha[j]    # the hop lifts the mote off its drift line
				var tumble := 0.6 + 0.4 * sin(t * (1.0 + z * 2.0) + m.ph)     # a turning speck catches light on and off
				var inside := absf(x - (x0 + slope * y / H)) < hw
				var bright := 1.0 if inside else 0.15                         # outside the shaft a mote is barely there
				var r := 0.5 + z * 2.2; var a := (0.2 + z * 0.8) * bright * tumble
				var c := K.mix(room[0], light, 0.3 + z * 0.7)
				if inside and z > 0.6: K.soft(n, Vector2(x, y), r * 3.0, light, 0.25 * z * tumble)
				K.dot(n, Vector2(x, y), r, K.alpha(c, a))
			K.label(n, b, D.label) })

	# ---- P · Plume ---------------------------------------------------------
	d.append({ "letter": "P", "name": "Plume", "drag": true,
		"hint": "a smoke column of soft puffs: one z per puff sets size, darkness, speed and edge — near puffs big, dark, firm, fast; far ones small, pale, slow, soft",
		"dials": { "sky": [Color("2A2F4A"), Color("6A7498"), Color("9AA0B8")], "smoke": Color("3A3A44"), "lit": Color("9AA0B8"), "litY": -1.0,   # lit: the light on each puff; litY -1 from above, +1 from below
			"puffs": 40, "rise": 0.35, "wind": 0.0, "seed": 3,
			"label": "one z per puff drives size × darkness × speed × edge together; sort far to near so near covers far" },
		"rhyme": { "name": "Chimney at dusk", "hint": "the same smoke column with the light on each puff moved to its UNDERSIDE, warm orange, against a sunset — the low sun lights it from below",
			"dials": { "sky": [Color("2A1E4A"), Color("8A4A6A"), Color("F5A15A")], "lit": Color("F5A15A"), "litY": 1.0,
				"label": "flip the inner point of each puff's gradient from top to bottom and the light comes from a setting sun" } },
		"init": func(b: Dictionary) -> void:
			var D: Dictionary = b.D
			var R := K.rng(int(D.seed))
			b.puffs = []
			for j in int(D.puffs): b.puffs.append({ "z": R.randf(), "ph": R.randf(), "sw": R.randf() * 9.0, "side": R.randf() * 2.0 - 1.0 })
			b.puffs.sort_custom(func(p, q): return p.z < q.z),           # far first, near last — painter's order
		"press": func(b: Dictionary, pos: Vector2) -> void: b.D.wind = (pos.x / b.W - 0.5) * 2.0,   # click left/right = wind direction
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var t: float = b.t
			var W: float = b.W; var H: float = b.H
			var sky: Array = D.sky
			K.sky(n, b, [[0.0, sky[0]], [0.6, sky[1]], [1.0, sky[2]]])
			var GY := H * 0.86; var cx := W * 0.42; var top := GY - H * 0.2
			K.ground(n, b, GY, Color("0E0B1A"))
			n.draw_rect(Rect2(cx - W * 0.04, top, W * 0.08, H * 0.2), Color("0E0B1A"))   # the stack
			var rise: float = D.rise; var wind: float = D.wind; var litY: float = D.litY
			var lit: Color = D.lit
			for q in b.puffs:
				var z: float = q.z                                           # z: 0 far … 1 near
				var p := fposmod(t * rise * (0.5 + z) + q.ph, 1.0)          # near puffs rise faster
				var y := top - p * H * 0.8
				var x: float = cx + wind * p * p * W * 0.35 + q.side * p * W * 0.08 * (0.5 + z) + sin(q.sw + p * 5.0 + t * 0.3) * (3.0 + z * 8.0)
				var r := W * (0.02 + z * 0.06) * (0.4 + p * 1.4)             # puffs swell as they rise
				var a := (0.15 + z * 0.55) * (1.0 - p) * minf(1.0, p * 5.0 + 0.2)   # and fade away
				var c := K.fog(D.smoke, (1.0 - z) * 0.7 + p * 0.25, sky[1])  # far smoke is the colour of the sky it is in front of
				var hard := 0.05 + z * 0.45                                  # where the falloff starts — near = a firmer core
				K.radial(n, Vector2(x, y), r, [[0.0, K.alpha(K.mix(c, lit, 0.35), a)], [hard, K.alpha(c, a * 0.9)], [1.0, K.alpha(c, 0.0)]],
					Vector2(0.0, litY * r * 0.35))
			K.label(n, b, D.label) })

	# ---- S · Steam ---------------------------------------------------------
	d.append({ "letter": "S", "name": "Steam", "drag": true,
		"hint": "pale soft volumes rising off a cup, added onto a dark room: near wisps bigger, brighter, faster, firmer; far ones fade into the room; all curl upward",
		"dials": { "room": [Color("0E0C14"), Color("1E1A22")], "steam": Color("DCE8F5"), "cup": Color("2A2430"), "wisps": 34, "rise": 0.4, "gain": 1.0, "curl": 1.0, "wind": 0.0, "seed": 13,   # gain: how hard the steam adds
			"label": "light adds: near wisps bigger, brighter, faster, firmer-edged — far ones melt into the room's dark" },
		"rhyme": { "name": "Sci-fi coolant", "hint": "the same wisps in cyan off a steel vent, adding nearly twice as hard — leaking reactor, not breakfast",
			"dials": { "room": [Color("06080E"), Color("0E1620")], "steam": Color("60E8FF"), "cup": Color("3A4450"), "gain": 1.8,
				"label": "turn the gain up and additive light saturates where near wisps overlap — the glow is the genre" } },
		"init": func(b: Dictionary) -> void:
			var D: Dictionary = b.D
			var R := K.rng(int(D.seed))
			b.wisps = []
			for j in int(D.wisps): b.wisps.append({ "z": R.randf(), "ph": R.randf(), "sw": R.randf() * 9.0, "side": R.randf() * 2.0 - 1.0 })
			b.wisps.sort_custom(func(p, q): return p.z < q.z),           # far first
		"press": func(b: Dictionary, pos: Vector2) -> void: b.D.wind = (pos.x / b.W - 0.5) * 2.0,   # click left/right = a draught
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var t: float = b.t
			var W: float = b.W; var H: float = b.H
			var room: Array = D.room
			K.sky(n, b, room)
			var cx := W * 0.5; var top := H * 0.62
			K.cyl(n, cx, H * 0.9, W * 0.22, H * 0.28, D.cup, -0.4)          # the cup is a cylinder
			K.ellipse(n, Vector2(cx, top), W * 0.11, H * 0.025, K.shade(D.cup, 0.25))   # its rim
			# steam is light on dark: it adds on the web ("lighter"); translucent puffs stack here instead
			var rise: float = D.rise; var gain: float = D.gain; var curl: float = D.curl; var wind: float = D.wind
			for w in b.wisps:
				var z: float = w.z
				var p := fposmod(t * rise * (0.5 + z) + w.ph, 1.0)          # near wisps rise faster
				var y := top - p * H * 0.55
				var x: float = cx + w.side * W * 0.06 * (0.4 + z * 0.6) + sin(p * 4.0 * curl + w.sw + t * 0.4) * W * (0.02 + p * 0.08) + wind * p * p * W * 0.3   # x sways more the higher it gets
				var r := W * (0.02 + z * 0.05) * (0.5 + p * 1.2)
				var a := (0.08 + z * 0.35) * gain * (1.0 - p) * minf(1.0, p * 6.0 + 0.15)
				var c := K.mix(room[1], D.steam, 0.3 + z * 0.7)              # far wisps are already halfway to the room's colour
				var hard := 0.05 + z * 0.35
				K.radial(n, Vector2(x, y), r, [[0.0, K.alpha(c, a)], [hard, K.alpha(c, a * 0.85)], [1.0, K.alpha(c, 0.0)]])
			K.label(n, b, D.label) })

	# ---- V · Vapour --------------------------------------------------------
	d.append({ "letter": "V", "name": "Vapour", "drag": true,
		"hint": "ground fog in four depth bands — far band pale, thin, slow; near band darker, thick, fast — and tree silhouettes paler the more fog stands before them",
		"dials": { "sky": [Color("3A4A6A"), Color("8A98B0"), Color("B8C0CC")], "fog": Color("C8CCD8"), "tree": Color("0A1210"), "bands": 4, "per": 12, "drift": 1.0, "seed": 19,
			"label": "fog is layers: each band paler, thinner and slower the farther back — and it pales whatever stands behind it" },
		"rhyme": { "name": "Swamp gas", "hint": "the same four fog bands tinted sickly green under a low sky, drifting two and a half times as fast",
			"dials": { "sky": [Color("1A2A20"), Color("4A6A48"), Color("7A9A70")], "fog": Color("9AC89A"), "drift": 2.5,
				"label": "the air's colour is a dial: tint the fog and every tree behind it takes the tint — that is what 'air' means" } },
		"init": func(b: Dictionary) -> void:
			var D: Dictionary = b.D
			var R := K.rng(int(D.seed))
			b.blobs = []
			for i in int(D.bands):
				for j in int(D.per): b.blobs.append({ "band": i, "x": R.randf(), "ph": R.randf() * 9.0 })
			b.trees = []
			for k in 9: b.trees.append({ "x": R.randf(), "d": R.randf() })   # d: 0 far … 1 near
			b.trees.sort_custom(func(p, q): return p.d < q.d),
		"press": func(b: Dictionary, pos: Vector2) -> void: b.D.drift = (pos.x / b.W - 0.5) * 4.0,   # click left/right = which way the fog drifts
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var t: float = b.t
			var W: float = b.W; var H: float = b.H
			var sky: Array = D.sky
			K.sky(n, b, [[0.0, sky[0]], [0.5, sky[1]], [1.0, sky[2]]])
			var hor := H * 0.45; var ti := 0
			K.ground(n, b, hor, K.mix(D.tree, sky[2], 0.5))
			var bands: int = D.bands; var drift: float = D.drift
			for i in bands:
				var dd := float(i) / (bands - 1)
				var by := hor + pow(dd, 1.5) * H * 0.45 + H * 0.03          # band 0 hugs the horizon
				while ti < b.trees.size() and b.trees[ti].d <= float(i + 1) / bands:   # trees standing in this slice go in BEFORE its fog
					var tr: Dictionary = b.trees[ti]; ti += 1
					var td: float = tr.d
					var ty := hor + pow(td, 1.5) * H * 0.45 + H * 0.03
					var h := H * (0.08 + td * 0.3); var tx: float = tr.x * W
					var tc := K.fog(D.tree, (1.0 - td) * 0.85, sky[1])     # the fog between you and the tree pales it
					K.poly(n, PackedVector2Array([Vector2(tx - h * 0.18, ty), Vector2(tx, ty - h), Vector2(tx + h * 0.18, ty)]), tc)
					n.draw_rect(Rect2(tx - h * 0.03, ty - 1.0, h * 0.06, h * 0.12), tc)
				var r := W * (0.08 + dd * 0.1); var span := W + r * 2.0
				var c := K.shade(K.mix(D.fog, sky[1], (1.0 - dd) * 0.6), -0.25 * dd)   # far band pale toward the sky, near band darker
				for bl in b.blobs:
					if bl.band != i: continue
					var x := fposmod(bl.x * span + t * drift * (4.0 + dd * 28.0), span) - r   # near bands drift faster
					n.draw_set_transform(Vector2(x, by + sin(t * 0.3 + bl.ph) * 3.0), 0.0, Vector2(1.0, 0.4))   # flattened blobs
					K.soft(n, Vector2.ZERO, r, c, 0.2 + dd * 0.4)            # far thin, near thick
					n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			K.label(n, b, D.label) })

	# ---- W · Wildfire ------------------------------------------------------
	d.append({ "letter": "W", "name": "Wildfire", "drag": true,
		"hint": "a field of small flames in perspective rows: rows shrink and bunch toward the horizon (horizon + p²); size, brightness and flicker come from the row",
		"dials": { "sky": [Color("0A0406"), Color("3A0E0A")], "far": Color("8A1E10"), "near": Color("FFE08A"), "rows": 7, "dense": 12, "flicker": 1.0, "smoke": 10, "wind": 0.0, "seed": 37,   # dense: flames in the farthest row
			"label": "rows at horizon + p² shrink and bunch; z here is the row — size, colour, alpha and flicker all follow it" },
		"rhyme": { "name": "Candle field", "hint": "the same perspective rows with five flames a row instead of twelve, flickering gently, no smoke — a vigil, not a disaster",
			"dials": { "sky": [Color("0A0608"), Color("1E1010")], "far": Color("A05A20"), "near": Color("FFF0C0"), "dense": 5, "flicker": 0.4, "smoke": 0,
				"label": "fewer flames, slower flicker, no smoke: the same rows read as candles because calm is a dial too" } },
		"init": func(b: Dictionary) -> void:
			var D: Dictionary = b.D
			var R := K.rng(int(D.seed))
			var rows: int = D.rows; var dense: int = D.dense
			b.flames = []
			for i in rows:                                                  # row by row = far → near
				var p := float(i) / (rows - 1)
				var cnt := maxi(1, roundi(dense - p * dense * 0.5))        # far rows hold more, smaller flames
				for j in cnt:
					b.flames.append({ "p": p, "x": (j + 0.2 + R.randf() * 0.6) / cnt, "ph": R.randf() * 9.0, "s": 0.7 + R.randf() * 0.6 })
			b.smokes = []
			for k in int(D.smoke): b.smokes.append({ "x": R.randf(), "ph": R.randf(), "z": R.randf() }),
		"press": func(b: Dictionary, pos: Vector2) -> void: b.D.wind = (pos.x / b.W - 0.5) * 2.0,   # click left/right = wind leans every flame
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var t: float = b.t
			var W: float = b.W; var H: float = b.H
			var sky: Array = D.sky
			K.sky(n, b, sky)
			var hor := H * 0.42
			K.lin_rect(n, Rect2(0, hor, W, H - hor), [Color("2A0C08"), Color("0A0406")])
			var wind: float = D.wind; var flicker: float = D.flicker
			for s in b.smokes:                                              # smoke is matter: it covers, so it goes first
				var q := fposmod(t * 0.08 * (0.5 + s.z) + s.ph, 1.0)
				K.soft(n, Vector2(fposmod(s.x + wind * q * 0.3 + 10.0, 1.0) * W, hor - q * hor * 0.9), W * (0.05 + s.z * 0.08) * (0.5 + q),
					K.mix(Color("3A2A28"), sky[1], 0.5), (0.1 + s.z * 0.25) * (1.0 - q))
			# "lighter" from here on the web — the flames add; translucent glows stand in
			K.soft(n, Vector2(W / 2.0, hor), W * 0.6, D.far, 0.3)           # the glow on the horizon
			for f in b.flames:
				var p: float = f.p
				var scale := 0.12 + p * 0.88
				var sp := (3.0 + p * 4.0) * flicker                          # near rows flicker faster
				var y := hor + p * p * H * 0.55 + 2.0; var x: float = f.x * W
				var h: float = H * 0.17 * scale * f.s * (0.8 + 0.2 * sin(t * sp + f.ph)); var w := W * 0.045 * scale + 1.0
				var lean := sin(t * sp * 1.3 + f.ph) * w * 0.5 + wind * w * 1.2
				var c := K.mix(D.far, D.near, p)                             # far rows dark red, near rows yellow-white
				if p > 0.5: K.soft(n, Vector2(x, y - h * 0.3), h * 0.6, c, 0.15 * p)
				_tongue(n, x, y, w, h, lean, c, 0.3 + p * 0.7)
			K.label(n, b, D.label) })

	# ---- Y · Yule ----------------------------------------------------------
	d.append({ "letter": "Y", "name": "Yule",
		"hint": "a log fire: dark tongues far back, bright tongues just behind the logs, embers on the near wood — logs are turned cylinders; overlap does the depth",
		"dials": { "room": [Color("1A0E0A"), Color("3A1A10")], "hearth": Color("141010"), "planes": [Color("8A1E10"), Color("F0A030")], "log": Color("4A2E1A"), "ember": Color("FF9A3A"),
			"per": 5, "flame": 1.0, "embers": 10, "seed": 43,             # flame: height of the tongues; embers: how many coals glow
			"label": "overlap is depth order: dark flame far back, bright flame nearer, then the logs, then the embers on them" },
		"rhyme": { "name": "Campfire embers", "hint": "the same logs under an open night sky, the flame burnt down to a third and forty coals glowing — the fire an hour later",
			"dials": { "room": [Color("04060E"), Color("0E1424")], "hearth": Color("0A0C14"), "log": Color("3A2416"), "flame": 0.35, "embers": 40,
				"label": "low flame, many coals: the depth order is untouched — the fire is just older" } },
		"init": func(b: Dictionary) -> void:
			var D: Dictionary = b.D
			var R := K.rng(int(D.seed))
			var planes: Array = D.planes
			var per: int = D.per
			b.tongues = []
			for i in planes.size():                                         # far plane first
				for j in per:
					b.tongues.append({ "z": (i + 0.5) / planes.size(), "c": planes[i], "x": 0.32 + (j + R.randf() * 0.6) / per * 0.36,
						"ph": R.randf() * 9.0, "s": 0.7 + R.randf() * 0.6 })
			b.embers = []
			for k in int(D.embers): b.embers.append({ "x": R.randf(), "ph": R.randf() * 9.0, "front": k % 2 == 1 })
			b.flare = 0.0,
		"press": func(b: Dictionary, pos: Vector2) -> void: b.flare = 1.0,   # click = poke the fire
		"draw": func(n: CanvasItem, b: Dictionary) -> void:
			var D: Dictionary = b.D
			var t: float = b.t
			var W: float = b.W; var H: float = b.H
			var room: Array = D.room
			var flare: float = b.flare
			var fl := 0.85 + 0.15 * sin(t * 7.3) * sin(t * 3.1) + flare * 0.4   # the fire's breathing lights the room
			b.flare = flare * 0.96
			K.sky(n, b, [K.mix(room[0], room[1], fl * 0.5), K.mix(room[1], Color("8A4A20"), fl * 0.4)])
			var GY := H * 0.84
			n.draw_rect(Rect2(W * 0.2, H * 0.3, W * 0.6, GY - H * 0.3), D.hearth)   # the hearth's dark back
			K.ground(n, b, GY, Color("1E1410"))
			K.lin_rect(n, Rect2(0, GY, W, H - GY), [[0.0, K.alpha(D.ember, 0.35 * fl)], [1.0, K.alpha(D.ember, 0.0)]])   # firelight on the floor
			# flame BEHIND the logs, dark plane first — "lighter" on the web, translucent glows here
			var flame: float = D.flame
			for g in b.tongues:
				var z: float = g.z
				var sp := 1.5 + z * 3.0
				var h: float = H * (0.14 + z * 0.14) * g.s * flame * (0.8 + 0.2 * sin(t * sp + g.ph)) * (1.0 + flare * 0.5)
				var w := W * (0.04 + z * 0.04)
				var lean := sin(t * sp * 1.3 + g.ph) * w * 0.5
				var x: float = W * g.x
				var y := GY - H * 0.06 - (1.0 - z) * H * 0.04
				K.soft(n, Vector2(x, y - h * 0.4), h * 0.5, g.c, 0.1 + (1.0 - z) * 0.3)
				_tongue(n, x, y, w, h, lean, g.c, 0.3 + z * 0.65)
			# a log is a cylinder turned on its side: rotate the frame, draw K.cyl standing, put the frame back
			var logc: Color = D.log
			for lg in [[GY - H * 0.075, W * 0.4, H * 0.06, 0.15], [GY - H * 0.045, W * 0.44, H * 0.07, -0.1]]:   # the back log tilted up-right; the front log covers it
				var len: float = lg[1]
				n.draw_set_transform(Vector2(W * 0.5, lg[0]), PI / 2.0 + lg[3], Vector2.ONE)
				K.cyl(n, 0.0, len / 2.0, lg[2], len, logc, -0.3)
				n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			for e in b.embers:                                              # embers ride the top of the logs
				var ex: float = W * (0.3 + e.x * 0.4)
				var ey: float = (GY - H * 0.045 - (ex - W / 2.0) * 0.1 - H * 0.02) if e.front else (GY - H * 0.075 + (ex - W / 2.0) * 0.15 - H * 0.02)
				var glow := 0.5 + 0.5 * sin(t * (2.0 + e.ph * 0.3) + e.ph)
				K.soft(n, Vector2(ex, ey), 3.0 + glow * 3.0 + flare * 4.0, D.ember, 0.25 + 0.5 * glow)
				K.dot(n, Vector2(ex, ey), 1.0, Color("FFE0A0"))
			K.label(n, b, D.label) })

	return d
