extends RefCounted

const ElemKit := preload("res://scenes/elements/kit.gd")
## CRYSTAL — four buttons, ported from the web bestiary.

const TITLE := "Crystal"
const BLURB := "facets, resonance, and iridescence"
const DEFS := [
	{ "id": "facet", "name": "Facet glint", "hint": "cut faces catch the light in turn; press for the full cascade" },
	{ "id": "resonance", "name": "Resonance", "hint": "shards hum under a travelling wave, each an oscillator pitched by its length; press and the strike kicks each in turn — they ring and decay" },
	{ "id": "stalactite", "name": "Stalactites", "hint": "crystals lengthen from above; press to snap them loose" },
	{ "id": "opal", "name": "Opal", "hint": "iridescent bands roll across the face; press for a colour shockwave" },
]

static func init(b: Dictionary) -> void:
	b.press_v = 0.0
	b.parts = []
	var r: Rect2 = b.rect
	match b.id:
		"facet":
			b.facets = []
			for cx in 6:
				for h in 2:
					b.facets.append({ "x": cx / 6.0, "ph": randf_range(0, 9), "top": h == 0 })
			b.cascade = -1.0
		"resonance":
			# each shard is an OSCILLATOR: x'' = −ω²x − 2ζω·x' + drive, with ω from its
			# length (a short crystal rings high). the idle hum is a small travelling
			# force the shards answer at their own pitch; the strike is velocity
			# handed to each as the wave passes, and the ringing dies at the rate ζ sets
			b.pitch = 220.0                # a shard's natural frequency is pitch / len, radians/s
			b.zeta = 0.03                  # damping ratio: tiny, so a struck shard rings for a few seconds
			b.hum = 20.0                   # the idle drive: a small travelling force, s⁻²
			b.hum_rate = 4.0               # the hum's tempo, radians/s
			b.strike = 12.0                # the press: velocity handed to each shard as the strike passes it (its swing is strike / ω)
			b.run = 8.0                    # how fast the strike runs round the circle, shards per second
			var sx := PackedFloat32Array()   # each shard's swing, velocity, and length
			var sv := PackedFloat32Array()
			var slen := PackedFloat32Array()
			for i in 12:
				sx.append(0.0)
				sv.append(0.0)
				slen.append(randf_range(7, 12))
			b.sx = sx
			b.sv = sv
			b.slen = slen
			b.ring_wave = -1.0
		"stalactite":
			b.spikes = []
			var x := 8.0
			while x < r.size.x - 4.0:
				b.spikes.append({ "x": x, "max": randf_range(8, 16), "len": randf_range(2, 6),
					"rate": randf_range(0.5, 1.2) })
				x += 13.0
		"opal":
			b.shock = -1.0
			b.sp = Vector2.ZERO

static func press(b: Dictionary, pos: Vector2) -> void:
	match b.id:
		"facet":
			b.cascade = 0.0
		"resonance":
			b.ring_wave = 0.0
		"stalactite":
			for s in b.spikes:
				if s.len > 4.0:
					b.parts.append({ "kind": "fall", "pos": Vector2(s.x, s.len), "vy": 0.0, "len": s.len })
				s.len = 2.0
		"opal":
			b.shock = 0.0
			b.sp = pos

static func tick(b: Dictionary, dt: float, t: float) -> void:
	var r: Rect2 = b.rect
	match b.id:
		"facet":
			if b.cascade >= 0.0:
				b.cascade += dt * 2.2
				if b.cascade > 1.4:
					b.cascade = -1.0
		"resonance":
			var prev: float = b.ring_wave
			if b.ring_wave >= 0.0:
				b.ring_wave += dt * float(b.run)   # the strike runs round the circle
			var sx: PackedFloat32Array = b.sx
			var sv: PackedFloat32Array = b.sv
			var slen: PackedFloat32Array = b.slen
			var pitch: float = b.pitch
			var zeta: float = b.zeta
			var hum: float = b.hum
			var hum_rate: float = b.hum_rate
			var strike: float = b.strike
			var sub := maxi(1, ceili(dt * 50.0))   # substep: ω·h must stay under 2
			var h := dt / float(sub)
			for i in sx.size():
				if prev >= 0.0 and prev <= float(i) and float(i) < b.ring_wave:
					sv[i] += strike                 # the strike passed this shard this frame
				var w := pitch / slen[i]
				var drive := hum * sin(t * hum_rate - i * 0.8)   # the idle travelling wave, as a force
				for _s in sub:
					sv[i] += (-w * w * sx[i] - 2.0 * zeta * w * sv[i] + drive) * h
					sx[i] += sv[i] * h
				sx[i] = clampf(sx[i], -0.9, 0.9)
			if b.ring_wave > float(sx.size()):
				b.ring_wave = -1.0             # one lap, then the shards are on their own
		"stalactite":
			for s in b.spikes:
				s.len = minf(s.max, s.len + s.rate * dt)
				if s.len > s.max * 0.95 and randf() < 0.008:
					b.parts.append({ "kind": "glit", "pos": Vector2(s.x, s.len + 2.0), "life": 1.0 })
			for p in b.parts:
				if p.kind == "fall":
					p.vy += 300.0 * dt
					p.pos.y += p.vy * dt
					if p.pos.y > r.size.y + 18.0:
						for i in 4:
							b.parts.append({ "kind": "glit", "pos": Vector2(p.pos.x + randf_range(-6, 6), r.size.y + 16.0), "life": 1.0 })
						p.vy = -9999.0
				else:
					p.life -= dt * 2.0
			b.parts = b.parts.filter(func(p): return (p.kind == "fall" and p.vy > -9000.0) or (p.kind == "glit" and p.life > 0.0))
		"opal":
			if b.shock >= 0.0:
				b.shock += dt * 130.0
				if b.shock > r.size.x * 1.3:
					b.shock = -1.0

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	var r: Rect2 = b.rect
	var o := r.position
	var c := r.get_center()
	match b.id:
		"facet":
			ElemKit.face(n, r, Color(0.1, 0.078, 0.19), Color(0.78, 0.71, 1.0, 0.5))
			for f in b.facets:
				var glint: float = pow(maxf(0.0, sin(t * 0.8 + f.ph)), 8.0) * 0.6
				if b.cascade >= 0.0:
					glint += maxf(0.0, 0.8 - absf(f.x - b.cascade) * 5.0)
				var fx: float = o.x + f.x * r.size.x
				var fy: float = o.y + (3.0 if f.top else r.size.y / 2.0)
				var fh := r.size.y / 2.0 - 3.0
				n.draw_colored_polygon(PackedVector2Array([
					Vector2(fx, fy), Vector2(fx + r.size.x / 6.0, fy), Vector2(fx, fy + fh)]),
					Color(0.82, 0.75, 1.0, minf(1.0, 0.1 + glint)))
			ElemKit.label(n, r, "BRILLIANT", Color(0.16, 0.12, 0.27))
		"resonance":
			ElemKit.face(n, r, Color(0.063, 0.078, 0.125, 0.92), Color(0.59, 0.86, 0.94, 0.5))
			ElemKit.label(n, r, "CHIME", Color(0.85, 0.95, 0.98))
			var sx: PackedFloat32Array = b.sx
			var slen: PackedFloat32Array = b.slen
			var count := sx.size()
			for i in count:
				var a := i / float(count) * TAU
				var excite := minf(1.0, absf(sx[i]) * 1.5)
				var scale := 1.0 + sx[i]           # the oscillator's swing IS the scale
				var len: float = slen[i]
				var pos := c + Vector2(cos(a) * r.size.x * 0.56, sin(a) * r.size.y * 0.78)
				n.draw_set_transform(pos, a + PI / 2.0, Vector2(1.0, scale))
				n.draw_colored_polygon(PackedVector2Array([
					Vector2(0, -len), Vector2(2.4, 0), Vector2(0, len * 0.4), Vector2(-2.4, 0)]),
					Color(0.67, 0.9, 0.98, 0.5 + excite * 0.5))
				n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"stalactite":
			ElemKit.face(n, r, Color(0.07, 0.07, 0.133, 0.92), Color(0.75, 0.78, 1.0, 0.5))
			ElemKit.label(n, r, "CAVERN", Color(0.89, 0.91, 1.0))
			for s in b.spikes:
				n.draw_colored_polygon(PackedVector2Array([
					o + Vector2(s.x - 2.6, 0), o + Vector2(s.x + 2.6, 0), o + Vector2(s.x, s.len)]),
					Color(0.78, 0.82, 1.0, 0.75))
			for p in b.parts:
				if p.kind == "fall":
					n.draw_colored_polygon(PackedVector2Array([
						o + p.pos + Vector2(-2, -p.len * 0.5), o + p.pos + Vector2(2, -p.len * 0.5), o + p.pos]),
						Color(0.78, 0.82, 1.0, 0.85))
				else:
					n.draw_rect(Rect2(o + p.pos, Vector2(2, 2)), Color(0.9, 0.93, 1.0, p.life))
		"opal":
			var x := 0.0
			while x < r.size.x:              # interference: two hue waves beating
				var hue := 0.5 + sin(x * 0.05 + t * 0.8) * 0.17 + sin(x * 0.11 - t * 0.5) * 0.11
				var light := 0.55
				if b.shock >= 0.0:
					var d: float = absf(Vector2(x, r.size.y / 2.0).distance_to(b.sp) - b.shock)
					if d < 16.0:
						hue += (16.0 - d) * 0.022
						light += (16.0 - d) * 0.015
				n.draw_rect(Rect2(o.x + x, o.y, 4.5, r.size.y),
					Color.from_hsv(fmod(hue + 1.0, 1.0), 0.65, minf(1.0, light + 0.35)))
				x += 4.0
			ElemKit.ring_face(n, r, Color(1, 1, 1, 0.6))
			ElemKit.label(n, r, "OPALESCE", Color(0.118, 0.078, 0.157, 0.85))
