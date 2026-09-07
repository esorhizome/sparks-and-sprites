extends RefCounted

const Kit := preload("res://scenes/stage/kit.gd")
## SFX & AUDIO — thirteen cards, ported from the web almanac (docs/stagecraft.js,
## the audio family). The sound half, drawn. Every card here is a picture of a
## mechanism that is usually invisible: a panner and a distance curve, the
## contact frame that fires a footstep, a blip per letter, six envelopes, an
## engine's rpm-to-pitch line, LFOs on a noise filter, a lowpass cutoff
## sliding on a spectrum, a feedback delay, three music layers gated by
## intensity, the lookahead window on the audio clock, voice slots being
## stolen, an analyser's bins, and two rumble motors. Sound is a courtesy:
## nothing here makes a noise until you press it (browsers insist, and so do
## we — b.armed_sound), the volumes stay low (≤ 0.25), the voices stay under
## about six a second, and every card is worth watching with the speakers
## off. It grows from chapter 07 — the blip, the pitch randomisation, the bus.
##
## THE KIT'S SYNTH VS THE WEB'S. The stage kit's Synth is one generator with
## a voice list: tone() (square / triangle / sine / sawtooth, a pitch slide,
## pan, attack, "at" to book ahead) and noise_burst() (white noise through a
## ONE-POLE LOWPASS, swept). It has no highpass, no playbackRate and no
## decayTo — where the web passes those, the port folds rate into the
## cutoff (cutoff × rate) and drops the rest, and says so in the arm. There
## is NO ANALYSER in the kit either: Analyser and Quiet draw their spectra
## from the card's own note pattern (the web does the same when the tab is
## silent), so the picture never depends on the speakers.

const TITLE := "SFX & audio"
const BLURB := "the sound half, drawn — panning, footsteps, beep-speak, synth recipes, engines, noise beds, muffles, reverb, adaptive music, lookahead scheduling, voice quotas, analysers, rumble"
const DEFS := [
	{ "id": "positional", "letter": "P", "name": "Positional",
		"hint": "pan follows x, gain falls with distance, pitch bends with closing speed — a siren crosses; three meters draw it — press to place the listener",
		"dials": { "speed": 0.28,        # the car's speed, screens per second
			"refDist": 0.25,             # the distance (of W) where the gain has fallen to half
			"soundSpeed": 1.4,           # the speed of sound, screens per second — tiny on purpose so the doppler shows
			"baseHz": 520,               # the siren's low note...
			"wobbleHz": 150,             # ...and how far the high note sits above it
			"every": 0.28,               # seconds between siren voices after the first press
			"vol": 0.2,
			"label": "pan = dx/(W/2) · gain = 1/(1+(d/ref)²) · f′ = f·c/(c − v_closing)" },
		"rhyme": { "name": "Prowler", "hint": "a slow pass with a low engine note and sound that travels slowly — the doppler bends the pitch hard as it passes",
			"dials": { "speed": 0.14, "soundSpeed": 0.45, "baseHz": 110 } } },
	{ "id": "footsteps", "letter": "F", "name": "Footsteps",
		"hint": "the band under the foot picks the recipe — grass, stone, wood, water — and the run cycle's contact frame fires it — press to send the hero across",
		"dials": { "bands": ["grass", "stone", "wood", "water"],
			"recipes": { "grass": { "lowpass": 1600, "highpass": 300, "dur": 0.08, "vol": 0.12, "rate": 1.0 },
				"stone": { "lowpass": 5000, "highpass": 900, "dur": 0.05, "vol": 0.16, "rate": 1.2 },
				"wood": { "lowpass": 700, "highpass": 80, "dur": 0.11, "vol": 0.18, "rate": 0.6 },
				"water": { "lowpass": 2600, "highpass": 400, "dur": 0.2, "vol": 0.14, "rate": 0.9, "sweepTo": 500 } },
			"colours": ["#5D8A4A", "#8A8AA0", "#8A6A3E", "#4FA3D8"],
			"speed": 0.22,               # the hero's pace, screens per second
			"cadence": 1.0,              # the run cycle's clock rate (the kit's frame clock)
			"legs": 2,                   # plants per stride: two for a runner, four for a trot
			"humanise": 0.1,             # ± pitch randomisation on every plant
			"label": "plant event → recipe[band(x)] · rate × (1 ± humanise)" },
		"rhyme": { "name": "Fourlegs", "hint": "a trotting animal — four plants per stride at a quicker clock, so the surface changes voice twice as often",
			"dials": { "legs": 4, "cadence": 0.8, "speed": 0.3 } } },
	{ "id": "natter", "letter": "N", "name": "Natter",
		"hint": "a blip per typed letter, pitched by the character — vowels sing (sine), consonants click (square) — press for the next line",
		"dials": { "lines": ["Hello, traveller.", "The bridge is out again!", "Take the long way round...", "Mind the frogs."],
			"base": 300,                 # the character's voice: its lowest blip, Hz
			"range": 0.6,                # how far above base a letter can sit (× base)
			"cps": 6,                    # characters per second
			"blipEvery": 1,              # sound every nth letter — keeps the voice count polite
			"vowelDur": 0.09,            # a vowel rings...
			"consDur": 0.04,             # ...a consonant clicks
			"hold": 1.6,                 # seconds a finished line stays before the next
			"vol": 0.12,
			"label": "f = base · (1 + hash(letter) · range) · vowel ? sine : square" },
		"rhyme": { "name": "Nasal", "hint": "a high squeaky voice typing fast — twice the base pitch, eleven letters a second, a blip on every other one",
			"dials": { "base": 640, "cps": 11, "blipEvery": 2 } } },
	{ "id": "envelopes", "letter": "E", "name": "Envelopes",
		"hint": "six recipes beyond the blip — explosion, jump, hurt, pickup, whistle, boing — each a pitch and gain envelope, drawn — press to play the one you click",
		"dials": { "recipes": [ { "name": "explosion", "kind": "noise", "lowpass": 2600, "sweepTo": 120, "dur": 0.55, "vol": 0.22 },
				{ "name": "jump", "kind": "tone", "wave": "square", "f0": 200, "f1": 620, "dur": 0.16, "vol": 0.14 },
				{ "name": "hurt", "kind": "tone", "wave": "square", "f0": 340, "f1": 90, "dur": 0.22, "vol": 0.14 },
				{ "name": "pickup", "kind": "arp", "wave": "triangle", "notes": [523, 659, 784, 1047], "step": 0.055, "dur": 0.09, "vol": 0.14 },
				{ "name": "whistle", "kind": "tone", "wave": "sine", "f0": 320, "f1": 1400, "dur": 0.5, "vol": 0.16, "attack": 0.05 },
				{ "name": "boing", "kind": "tone", "wave": "sawtooth", "f0": 260, "f1": 60, "dur": 0.38, "vol": 0.12, "attack": 0.01 } ],
			"wave": "auto",              # "auto" keeps each recipe's own wave; "square" forces the NES kit
			"stretch": 1,                # × every duration
			"every": 1.5,                # seconds between the autopilot's plays
			"fLo": 50, "fHi": 2000,      # the pitch axis, Hz, drawn on a log scale
			"label": "gain: 0 → vol in attack, → 0 by dur · pitch: f0 → f1 (exponential)" },
		"rhyme": { "name": "Eightbit", "hint": "square waves only and every envelope shortened — the same six recipes played by a NES",
			"dials": { "wave": "square", "stretch": 0.6, "every": 1.1 } } },
	{ "id": "engine", "letter": "E", "name": "Engine", "drag": true,
		"hint": "an oscillator whose pitch and volume follow speed — rpm for every vehicle; a car accelerates and brakes on autopilot — drag to throttle",
		"dials": { "wave": "sawtooth",   # the engine's oscillator
			"idleHz": 55,                # the note at idle...
			"pitchRange": 3.2,           # ...and how many times higher it climbs at top speed
			"vol": 0.16,                 # the gain at top speed (idleVol at rest)
			"idleVol": 0.05,
			"seg": 0.25,                 # seconds per overlapping tone segment after the first press
			"accel": 0.45,               # how fast speed chases the throttle upward, per second
			"brake": 0.9,                # ...and downward
			"idleRpm": 900, "maxRpm": 7000,
			"manual": 4,                 # seconds a drag's throttle holds before the autopilot takes back the wheel
			"label": "f = idle · (1 + speed · range) · gain = lerp(idleVol, vol, speed)" },
		"rhyme": { "name": "Electric", "hint": "a sine whine that starts high and climbs higher, quieter than the petrol note — the same two lines, a different motor",
			"dials": { "wave": "sine", "idleHz": 240, "vol": 0.09 } } },
	{ "id": "noisebed", "letter": "N", "name": "Noisebed",
		"hint": "wind, rain, surf and fire are one noise source under a filter, with slow LFOs on the cutoff and the gain — the curves drawn — press for the next bed",
		"dials": { "beds": { "wind": { "lowpass": 900, "highpass": 120, "lfo": 0.13, "depth": 0.8, "glfo": 0.21, "gdepth": 0.6, "vol": 0.14, "rate": 0.7 },
				"rain": { "lowpass": 6000, "highpass": 1500, "lfo": 0.5, "depth": 0.25, "glfo": 1.3, "gdepth": 0.25, "vol": 0.12, "rate": 1.4 },
				"surf": { "lowpass": 1400, "highpass": 200, "lfo": 0.09, "depth": 0.9, "glfo": 0.09, "gdepth": 0.8, "vol": 0.16, "rate": 0.8 },
				"fire": { "lowpass": 2400, "highpass": 300, "lfo": 0.9, "depth": 0.5, "glfo": 2.2, "gdepth": 0.45, "vol": 0.12, "rate": 1.0 } },
			"order": ["wind", "rain", "surf", "fire"],
			"bed": "wind",               # the bed to start on
			"second": "",                # a second bed layered underneath, always on ("" for none)
			"lfoScale": 1,               # × every LFO rate
			"grain": 0.4,                # seconds between overlapping noise grains after the first press
			"every": 7,                  # seconds before the autopilot moves to the next bed
			"label": "cutoff = lp · 2^(depth · sin 2π·lfo·t) · gain = vol · (1 − gdepth · (1 − sin 2π·glfo·t)/2)" },
		"rhyme": { "name": "Nightrain", "hint": "rain on top and distant surf underneath, both LFOs slowed — the same two filters, at night",
			"dials": { "bed": "rain", "second": "surf", "lfoScale": 0.4 } } },
	{ "id": "quiet", "letter": "Q", "name": "Quiet",
		"hint": "a lowpass slides shut when the hero is under water — the 'you are somewhere else' filter; its cutoff drawn on a spectrum — press to dive or surface",
		"dials": { "mode": "water",      # "water": the hero dives; "door": the cutoff follows distance behind a door
			"openHz": 12000,             # the cutoff with nothing in the way...
			"closedHz": 380,             # ...and fully muffled
			"slide": 5,                  # how fast the cutoff slides, per second
			"every": 3.5,                # seconds between the autopilot's dives and surfacings
			"tick": 0.45,                # seconds between the world's noise ticks after the first press
			"range": 0.5,                # door mode: the distance (of W) over which the muffle closes fully
			"bars": 24,
			"label": "cutoff = open · (closed/open)^m · |H(f)| = 1/√(1 + (f/cutoff)⁴)" },
		"rhyme": { "name": "Quietroom", "hint": "the hero behind a door — the cutoff follows how far past it he walks, and the listener stays put",
			"dials": { "mode": "door", "closedHz": 250, "range": 0.4 } } },
	{ "id": "yodel", "letter": "Y", "name": "Yodel",
		"hint": "a feedback delay whose mix rises inside the cave — a shout returns at delay·k, each fb times quieter, drawn as fading copies — press to shout",
		"dials": { "delay": 0.32,        # seconds between echoes
			"feedback": 0.55,            # each echo × this
			"caveMix": 0.75,             # the echo level deep in the cave...
			"openMix": 0.05,             # ...and in the open
			"maxEchoes": 5,
			"every": 2.6,                # seconds between the autopilot's shouts
			"caveX": 0.55,               # the cave mouth, of W
			"f0": 520, "f1": 380, "dur": 0.24, "vol": 0.18,
			"label": "y(t) = x(t) + Σ mix · fb^(k−1) · x(t − k·delay)" },
		"rhyme": { "name": "Yawningcave", "hint": "a long delay and high feedback — the shout comes back five times over three seconds, a canyon rather than a cave",
			"dials": { "delay": 0.6, "feedback": 0.82, "caveMix": 0.92 } } },
	{ "id": "jukebox", "letter": "J", "name": "Jukebox",
		"hint": "three music layers fade in with intensity, sections switch on the bar, stingers land on the beat — meters draw it — press to raise the intensity",
		"dials": { "tempo": 100,         # beats per minute; a step is an eighth
			"steps": 8,                  # steps per bar
			"patterns": { "drums": [1, 0, 2, 0, 1, 0, 2, 2], "bass": [1, 0, 0, 1, 0, 1, 0, 0], "lead": [0, 0, 1, 0, 1, 0, 0, 1] },
			"bassNotes": [110, 131, 98, 147], "leadNotes": [440, 523, 587, 659, 784],
			"thresholds": [0, 0.35, 0.7],   # the intensity at which each layer starts to fade in
			"fade": 1.5,                 # the fade rate, per second
			"floor": 0,                  # the lowest intensity the autopilot drifts to
			"drift": 0.06,               # intensity per second, the autopilot's triangle wave
			"sectionEvery": 4,           # bars between A ↔ B requests
			"stingerEvery": 4,           # bars between stingers (on the downbeat)
			"vol": 0.12,
			"label": "gain_i → clamp((I − thr_i)/0.25) · switch on step 0 · stinger on the beat" },
		"rhyme": { "name": "Jamsession", "hint": "every layer on from the start, a fast tempo and a stinger on every bar — the boss fight's music",
			"dials": { "tempo": 130, "floor": 1, "stingerEvery": 1 } } },
	{ "id": "lookahead", "letter": "L", "name": "Lookahead",
		"hint": "notes booked ahead on the audio clock, never fired from a frame — a frame-timed metronome vs a scheduled one, errors measured — press to start/stop",
		"dials": { "bpm": 120,
			"lookahead": 0.1,            # seconds ahead the scheduler books notes
			"window": 4,                 # seconds of history drawn
			"msSpan": 60,                # the error axis, ± ms
			"fLow": 330, "fHigh": 660, "vol": 0.12,
			"label": "while (due < now + lookahead) book(due)  vs  if (t ≥ due) play()" },
		"rhyme": { "name": "Latency", "hint": "a slow beat and a huge window — robust against any hitch, but stop and the booked notes keep coming for half a second",
			"dials": { "lookahead": 0.6, "bpm": 90 } } },
	{ "id": "quota", "letter": "Q", "name": "Quota",
		"hint": "a cap per sound and a pool of players — over the cap the oldest (or quietest) is stolen; the slots draw it — press for a burst of 20 requests",
		"dials": { "slots": 6,           # the pool of players
			"cap": 3,                    # instances per sound
			"steal": "oldest",           # "oldest" | "quietest" | "newest" (newest = the request is refused)
			"burst": 20,                 # requests a press queues...
			"burstSpan": 0.5,            # ...spread over this many seconds
			"rate": 2.5,                 # the autopilot's requests per second
			"sounds": { "coin": { "f0": 880, "f1": 1320, "wave": "triangle", "dur": 0.6, "vol": 0.12 }, "hit": { "f0": 220, "f1": 70, "wave": "square", "dur": 0.7, "vol": 0.14 } },
			"maxPerSec": 6,              # the audio side's courtesy cap on real tones
			"label": "count(name) ≥ cap ? steal(policy) : free slot ?: steal(all) · steals shown red" },
		"rhyme": { "name": "Quietquota", "hint": "a cap of two in a pool of four, and the newest request is the one refused — the strict mixer that never cuts a playing sound",
			"dials": { "cap": 2, "steal": "newest", "slots": 4 } } },
	{ "id": "analyser", "letter": "A", "name": "Analyser",
		"hint": "spectrum() feeds bar heights, a glow and a camera pulse — the music drives the picture; without audio a fake beat drives it — press to play/stop",
		"dials": { "bpm": 112,
			"bars": 16,                  # bars drawn (32 bins, two per bar)
			"shape": "bars",             # "bars" | "ring" — a waveform ring around the hero
			"attack": 30,                # how fast a bar rises, per second
			"release": 6,                # ...and falls
			"pulse": 0.05,               # camera scale per unit of bass
			"glowR": 0.45,               # the glow radius, of H, at full bass
			"label": "h_i ← max(bin_i, h_i · e^(−release·dt)) · scale = 1 + bass · pulse" },
		"rhyme": { "name": "Ambientwaves", "hint": "a smooth waveform ring around the hero instead of bars — slow release, a gentle pulse",
			"dials": { "shape": "ring", "release": 2.5, "pulse": 0.02 } } },
	{ "id": "rumble", "letter": "R", "name": "Rumble",
		"hint": "gamepad rumble and phone vibration as two motors, low and high, with intensity envelopes over time, fired by landings and hits — press for a pattern",
		"dials": { "patterns": { "land": [[0, 0, 0.12, 1.0], [1, 0, 0.05, 0.4]],
				"hit": [[1, 0, 0.06, 1.0], [0, 0.03, 0.2, 0.7], [1, 0.16, 0.05, 0.5]],
				"heartbeat": [[0, 0, 0.1, 0.8], [0, 0.25, 0.1, 0.5]],
				"pickup": [[1, 0, 0.04, 0.6], [1, 0.08, 0.04, 0.9]] },   # pulse = [motor 0 low / 1 high, at, dur, strength]
			"order": ["heartbeat", "pickup", "land", "hit"],   # what a press cycles through
			"motorFilter": "both",       # "both" | "low" | "high": which motors a pattern may use
			"stretch": 1,                # × every pulse's time
			"shake": 2.5,                # camera shake, px per unit of intensity
			"jumpEvery": 2.1, "hitEvery": 3.3,
			"lowHz": 55, "highHz": 170, "vol": 0.14,
			"label": "motor_m(t) = max over pulses of a · [at ≤ t < at + dur] · navigator.vibrate([on, off, …])" },
		"rhyme": { "name": "Rattle", "hint": "the high motor only and every pulse cut short — sharp little rattles instead of thuds, with a harder shake",
			"dials": { "motorFilter": "high", "stretch": 0.45, "shake": 4 } } },
]

const FAINT := Color(0.91, 0.898, 0.957, 0.55)     # the web label's default colour
const PANEL := Color(0.075, 0.063, 0.125, 0.6)      # "rgba(19,16,32,0.6)": the meter boxes' fill
const PANEL55 := Color(0.075, 0.063, 0.125, 0.55)
const PANEL7 := Color(0.075, 0.063, 0.125, 0.7)
const FRAME := Color(0.788, 0.769, 0.894, 0.3)      # "rgba(201,196,228,0.3)": the boxes' stroke
const FRAME35 := Color(0.788, 0.769, 0.894, 0.35)
const TRACK := Color(0.788, 0.769, 0.894, 0.15)     # "rgba(201,196,228,0.15)": an empty bar
const INK_DARK := Color("2B2440")                   # the sprite's outline colour: windows, wheels, bubble text
const WOOD := Color("5A3E2B")
const ROAD := Color(0.176, 0.157, 0.275, 0.9)       # "rgba(45,40,70,0.9)"
const CAVE := Color("2A2440")

# ---------------------------------------------------------------- small maths

## c with its alpha replaced (the web's rgba(c, a)).
static func _al(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, a)

## The web kit's ease(): a clamped smoothstep.
static func _ease(k: float) -> float:
	k = clampf(k, 0.0, 1.0)
	return k * k * (3.0 - 2.0 * k)

## The web label's "right" alignment: measure, then draw ending at p.x.
static func _label_r(n: CanvasItem, b: Dictionary, txt: String, p: Vector2, col: Color = FAINT) -> void:
	var f := ThemeDB.fallback_font
	var w: float = f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	Kit.label(n, b, txt, Vector2(p.x - w, p.y), col)

## The web text's "right" alignment (bold is drawn as plain — one font here).
static func _text_r(n: CanvasItem, txt: String, p: Vector2, size: int, col: Color) -> void:
	var f := ThemeDB.fallback_font
	var w: float = f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	Kit.text(n, txt, Vector2(p.x - w, p.y), size, col)

## A filled box with a one-pixel frame (rect + strokeRect on the web).
static func _panel(n: CanvasItem, r: Rect2, fill: Color = PANEL, stroke: Color = FRAME, w: float = 1.0) -> void:
	n.draw_rect(r, fill)
	n.draw_rect(r, stroke, false, w)

## setLineDash([on, off]) as short lines, with lineDashOffset.
static func _dash(n: CanvasItem, a: Vector2, c: Vector2, on: float, off: float, col: Color, w: float = 1.0, offset: float = 0.0) -> void:
	var len := a.distance_to(c)
	if len < 0.5:
		return
	var dir := (c - a) / len
	var period := on + off
	var s0 := -fposmod(offset, period)
	while s0 < len:
		var s1 := minf(s0 + on, len)
		if s1 > 0.0:
			n.draw_line(a + dir * maxf(s0, 0.0), a + dir * s1, col, w)
		s0 += period

## A quadratic bezier sampled into k points (ctx.quadraticCurveTo).
static func _quad(p0: Vector2, p1: Vector2, p2: Vector2, k: int = 8) -> Array:
	var out: Array = []
	for i in k:
		var u := (i + 1) / float(k)
		out.append(p0.lerp(p1, u).lerp(p1.lerp(p2, u), u))
	return out

## A filled pie slice (ctx.arc + lineTo(centre) + fill).
static func _sector(n: CanvasItem, c: Vector2, r: float, a0: float, a1: float, col: Color, segs: int = 24) -> void:
	var pts := PackedVector2Array([c])
	for i in segs + 1:
		var a := a0 + (a1 - a0) * i / float(segs)
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	n.draw_colored_polygon(pts, col)

## A rounded box: the body rect plus a frame (ctx.roundRect, squared off).
static func _round_box(n: CanvasItem, r: Rect2, fill: Color, stroke: Color) -> void:
	n.draw_rect(r, fill)
	n.draw_rect(r, stroke, false, 1.0)

# ---------------------------------------------------------------- per-card helpers

## Positional / Footsteps / Engine: a titled meter box.
static func _meter_box(n: CanvasItem, b: Dictionary, r: Rect2, title: String) -> void:
	_panel(n, r, PANEL55, FRAME35)
	Kit.label(n, b, title, r.position + Vector2(4.0, 11.0), Kit.DIM)

## Footsteps: which surface band is under x.
static func _band_at(b: Dictionary, x: float) -> int:
	var bands: Array = (b.D as Dictionary).bands
	return clampi(floori(x / b.w * bands.size()), 0, bands.size() - 1)

## Natter: the letter's pitch inside the voice's range — a hash of its code,
## so the same word always sings the same tune.
static func _pitch_of(ch: String) -> float:
	var c := ch.to_lower().unicode_at(0)
	return float((c * 37 + 11) % 17) / 16.0

static func _is_vowel(ch: String) -> bool:
	return "aeiou".find(ch.to_lower()) >= 0

static func _is_letter(ch: String) -> bool:
	if ch.is_empty():
		return false
	var c := ch.to_lower().unicode_at(0)
	return c >= 97 and c <= 122

## Natter: word wrap to a column count.
static func _wrap_words(text_in: String, max_chars: int) -> Array:
	var out: Array = []
	var row := ""
	for w in text_in.split(" "):
		var joined := (row + " " + w).strip_edges()
		if joined.length() > max_chars and row != "":
			out.append(row)
			row = w
		else:
			row = joined
	if row != "":
		out.append(row)
	return out

## Envelopes: a recipe's total length (an arp is its notes plus the last tail).
static func _env_len(r: Dictionary, stretch: float) -> float:
	if r.kind == "arp":
		return ((r.notes as Array).size() * float(r.step) + float(r.dur)) * stretch
	return float(r.dur) * stretch

## Envelopes: the kit's gain envelope — linear up in attack, exponential down to dur.
static func _gain_at(r: Dictionary, tau: float, total: float, stretch: float) -> float:
	var a: float = float(r.get("attack", 0.006)) * stretch
	if tau < a:
		return tau / a
	return pow(0.0005, (tau - a) / maxf(0.001, total - a))

## Envelopes: a frequency on the log pitch axis.
static func _fy(D: Dictionary, f: float, y0: float, h: float) -> float:
	var lo := log(float(D.fLo))
	var hi := log(float(D.fHi))
	return y0 + h - h * clampf((log(maxf(1.0, f)) - lo) / (hi - lo), 0.0, 1.0)

## Envelopes: play one recipe through the kit (the web's sound(r)).
static func _env_sound(D: Dictionary, r: Dictionary) -> void:
	var s: float = D.stretch
	var wave: String = r.get("wave", "square") if D.wave == "auto" else D.wave
	if r.kind == "noise":
		Kit.noise_burst({ "dur": float(r.dur) * s, "vol": r.vol, "lowpass": r.lowpass, "sweep_to": r.sweepTo })
	elif r.kind == "arp":
		var notes: Array = r.notes
		for k in notes.size():
			Kit.tone({ "freq": notes[k], "type": wave, "dur": float(r.dur) * s, "vol": r.vol, "at": k * float(r.step) * s })
	else:
		Kit.tone({ "freq": r.f0, "slide_to": r.f1, "type": wave, "dur": float(r.dur) * s, "vol": r.vol, "attack": float(r.get("attack", 0.006)) * s })

## Engine: the rpm line — pitch against speed.
static func _freq_of(D: Dictionary, sp: float) -> float:
	return float(D.idleHz) * (1.0 + sp * float(D.pitchRange))

## Noisebed: the cutoff LFO (octaves around lowpass) and the gain LFO (a sine
## with a little noise on it).
static func _bed_cutoff(D: Dictionary, bed: Dictionary, tt: float) -> float:
	return float(bed.lowpass) * pow(2.0, float(bed.depth) * sin(TAU * float(bed.lfo) * float(D.lfoScale) * tt))

static func _bed_gain(D: Dictionary, bed: Dictionary, tt: float) -> float:
	var sc: float = D.lfoScale
	var s := sin(TAU * float(bed.glfo) * sc * tt) * 0.75 + Kit.noise(tt * float(bed.glfo) * sc * 3.0 + 7.0) * 0.25
	return float(bed.vol) * (1.0 - float(bed.gdepth) * (1.0 - s) / 2.0)

## Noisebed: a frequency on the 40 Hz .. 12 kHz log axis.
static func _fx(f: float, x0: float, w: float) -> float:
	return x0 + w * clampf((log(maxf(20.0, f)) - log(40.0)) / (log(12000.0) - log(40.0)), 0.0, 1.0)

static func _bed_colour(nm: String) -> Color:
	match nm:
		"wind":
			return Kit.BONE
		"rain":
			return Kit.WATER
		"surf":
			return Kit.GOOD
		"fire":
			return Kit.FIRE
	return Kit.SUN

## Noisebed: one overlapping grain, sweeping its cutoff from this tick's value
## to the next one's. The kit's noise has no highpass and no playbackRate:
## rate is folded into the cutoff (a faster buffer is a brighter one).
static func _bed_grains(D: Dictionary, bed: Dictionary, tt: float) -> void:
	var g: float = D.grain
	Kit.noise_burst({ "dur": g * 2.4, "vol": clampf(_bed_gain(D, bed, tt), 0.0, 0.25),
		"lowpass": _bed_cutoff(D, bed, tt) * float(bed.rate), "sweep_to": _bed_cutoff(D, bed, tt + g) * float(bed.rate),
		"attack": g * 0.8 })

## Quiet: the centre frequency of spectrum bar i.
static func _f_of(D: Dictionary, i: int) -> float:
	return 40.0 * pow(400.0, (i + 0.5) / float(D.bars))

## Yodel: one shout and its booked echoes — the same schedule a delay line
## would produce, drawn as ghost heroes. tone()'s "at" books echo k at
## k · delay (the web's comment says so; its call left the at off).
static func _shout(b: Dictionary, t: float) -> void:
	var D: Dictionary = b.D
	var pending: Array = b.pending
	var pan := clampf(b.hx / b.w * 2.0 - 1.0, -1.0, 1.0)
	var mix: float = b.mix
	for k in int(D.maxEchoes) + 1:
		var g := 1.0 if k == 0 else mix * pow(float(D.feedback), k - 1)
		if g < 0.03:
			break
		pending.append({ "at": t + k * float(D.delay), "g": g, "k": k, "x": b.hx, "t0": 0.0 })
		if b.armed_sound:
			Kit.tone({ "freq": float(D.f0) * pow(0.985, k), "slide_to": D.f1, "type": "triangle", "dur": D.dur,
				"vol": clampf(float(D.vol) * g, 0.0, 0.25), "pan": (pan * 0.3 + 0.5) if k > 0 else pan, "attack": 0.02,
				"at": k * float(D.delay) })

## Jukebox: an eighth note in seconds.
static func _step_dur(D: Dictionary) -> float:
	return 60.0 / float(D.tempo) / 2.0

## Jukebox: fire step s on every layer whose gain is up. Drums are two
## noise recipes (the kit has no highpass: the hat is a short bright burst),
## bass a square, lead a triangle. decayTo is not in the kit — dropped.
static func _play_step(b: Dictionary, s: int) -> void:
	var D: Dictionary = b.D
	var pats: Dictionary = D.patterns
	var gains: Array = b.gains
	var flashes: Array = b.flashes
	var layers: Array = b.layers
	var section: int = b.section
	var bar: int = b.bar
	for i in layers.size():
		var pat: Array = pats[layers[i]]
		var hit: int = pat[s % pat.size()]
		if hit == 0 or float(gains[i]) < 0.05:
			continue
		flashes[i] = 1.0
		if not b.armed_sound:
			continue
		var v: float = float(D.vol) * float(gains[i])
		if i == 0:
			if hit == 1:
				Kit.noise_burst({ "dur": 0.12, "vol": v * 1.4, "lowpass": 220.0, "sweep_to": 60.0 })
			else:
				Kit.noise_burst({ "dur": 0.04, "vol": v * 0.6, "lowpass": 9000.0 })
		elif i == 1:
			var bn: Array = D.bassNotes
			Kit.tone({ "freq": bn[(floori(s / 2.0) + section * 2) % bn.size()], "type": "square", "dur": 0.22, "vol": v })
		else:
			var ln: Array = D.leadNotes
			Kit.tone({ "freq": ln[(s * 2 + bar + section * 2) % ln.size()], "type": "triangle", "dur": 0.2, "vol": v })

## Jukebox: a one-shot hit booked for the beat — two sawtooth notes, a hair apart.
static func _play_stinger(b: Dictionary) -> void:
	b.stinger = 1.0
	if not b.armed_sound:
		return
	var sec: int = b.section
	Kit.tone({ "freq": 659.0 if sec == 1 else 523.0, "type": "sawtooth", "dur": 0.35, "vol": 0.1, "attack": 0.01 })
	Kit.tone({ "freq": 988.0 if sec == 1 else 784.0, "type": "sawtooth", "dur": 0.35, "vol": 0.08, "attack": 0.01, "at": 0.02 })

## Quota: a slot's current level — its envelope, squared.
static func _q_level(D: Dictionary, v: Dictionary, t: float) -> float:
	var snd: Dictionary = (D.sounds as Dictionary)[v.name]
	var k := clampf(1.0 - (t - float(v.born)) / float(snd.dur), 0.0, 1.0)
	return float(v.vol) * k * k

## Quota: the slot to steal — the oldest, or the quietest by current level —
## among one sound's voices (list != "") or all of them.
static func _q_victim(b: Dictionary, list: String, t: float) -> int:
	var D: Dictionary = b.D
	var slots: Array = b.slots
	var best := -1
	for i in int(D.slots):
		var v: Variant = slots[i]
		if v == null or (list != "" and (v as Dictionary).name != list):
			continue
		if best < 0:
			best = i
			continue
		var vd: Dictionary = v
		var bd: Dictionary = slots[best]
		var better: bool = (_q_level(D, vd, t) < _q_level(D, bd, t)) if D.steal == "quietest" else (float(vd.born) < float(bd.born))
		if better:
			best = i
	return best

## Quota: one request — under the cap and a free slot → play; at the cap →
## steal one of its own or refuse; pool full → steal across all sounds. The
## kit cannot cut a voice short, so the audio side plays only accepted
## requests, and at most maxPerSec a second (the token bucket).
static func _q_request(b: Dictionary, nm: String, t: float) -> void:
	var D: Dictionary = b.D
	var slots: Array = b.slots
	var reqlog: Array = b.reqlog
	b.requests += 1
	var count := 0
	var fr := -1
	for i in int(D.slots):
		var v: Variant = slots[i]
		if v == null:
			if fr < 0:
				fr = i
		elif (v as Dictionary).name == nm:
			count += 1
	var slot := fr
	var stolen := false
	if count >= int(D.cap):
		if D.steal == "newest":
			b.refused += 1
			reqlog.append({ "t": t, "name": nm, "kind": "refused" })
			if reqlog.size() > 40:
				reqlog.pop_front()
			return
		slot = _q_victim(b, nm, t)
		stolen = true
	elif fr < 0:
		slot = _q_victim(b, "", t)
		stolen = true
	if slot < 0:
		return
	if stolen:
		b.steals += 1
	slots[slot] = { "name": nm, "born": t, "vol": randf_range(0.45, 1.0), "flash": 1.0 if stolen else 0.0 }
	reqlog.append({ "t": t, "name": nm, "kind": "stole" if stolen else "ok" })
	if reqlog.size() > 40:
		reqlog.pop_front()
	if b.armed_sound and float(b.tokens) >= 1.0:
		b.tokens -= 1.0
		var snd: Dictionary = (D.sounds as Dictionary)[nm]
		Kit.tone({ "freq": snd.f0, "slide_to": snd.f1, "type": snd.wave, "dur": minf(0.3, float(snd.dur)),
			"vol": float(snd.vol) * (0.6 + 0.4 * float((slots[slot] as Dictionary).vol)) })

## Rumble: may this motor run under the current filter?
static func _allowed(D: Dictionary, m: int) -> bool:
	if D.motorFilter == "both":
		return true
	return m == 0 if D.motorFilter == "low" else m == 1

## Rumble: fire a haptic pattern — a list of (motor, at, dur, strength)
## pulses booked as events; the phone's flat vibrate([on, off, …]) list is
## the same pulses in milliseconds; the tones are the motors hummed at
## their two pitches, booked with "at".
static func _trigger(b: Dictionary, nm: String, t: float) -> void:
	var D: Dictionary = b.D
	var pats: Dictionary = D.patterns
	if not pats.has(nm):
		return
	var p: Array = pats[nm]
	var events: Array = b.events
	b.lastName = nm
	var stretch: float = D.stretch
	var ons: Array = []
	for i in p.size():
		var pulse: Array = p[i]
		var m: int = pulse[0]
		if not _allowed(D, m):
			continue
		var at: float = float(pulse[1]) * stretch
		var dur: float = maxf(0.02, float(pulse[2]) * stretch)
		var a: float = pulse[3]
		events.append({ "m": m, "at": t + at, "dur": dur, "a": a })
		ons.append([at, dur])
		if b.armed_sound:
			Kit.tone({ "freq": D.highHz if m == 1 else D.lowHz, "type": "triangle" if m == 1 else "sine", "dur": maxf(0.06, dur),
				"vol": clampf(float(D.vol) * a, 0.0, 0.25), "attack": 0.01, "at": at })
	ons.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) < float(y[0]))
	var vib: Array = []
	for i in ons.size():
		var o: Array = ons[i]
		vib.append(str(roundi(float(o[1]) * 1000.0)))
		if i + 1 < ons.size():
			var nx: Array = ons[i + 1]
			vib.append(str(maxi(0, roundi((float(nx[0]) - float(o[0]) - float(o[1])) * 1000.0))))
	b.lastVib = "vibrate([" + ", ".join(vib) + "])"
	if events.size() > 40:
		b.events = events.slice(events.size() - 40)

## Rumble: motor m's intensity at tt — the strongest pulse covering it.
static func _motor(b: Dictionary, m: int, tt: float) -> float:
	var a := 0.0
	for e in b.events:
		var ev: Dictionary = e
		if int(ev.m) == m and tt >= float(ev.at) and tt < float(ev.at) + float(ev.dur):
			a = maxf(a, float(ev.a))
	return a

# ================================================================ init

static func init(b: Dictionary) -> void:
	var D: Dictionary = b.D
	var W: float = b.w
	var H: float = b.h
	var GY: float = b.gy
	b.armed_sound = false                                # sound only after the card's first press
	match b.id:
		"positional":
			# POSITIONAL AUDIO is three numbers read off the geometry every frame.
			# PAN is the source's x relative to the listener, squashed to −1..1.
			# ATTENUATION is a distance curve: 1/(1+(d/ref)²) is one; engines call
			# theirs "inverse", "linear", "logarithmic". DOPPLER is the pitch shift
			# from closing speed: f′ = f·c/(c − v), where v is the source's speed
			# TOWARD the listener (positive = approaching = higher). chapter 07's
			# AudioStreamPlayer2D / spatialBlend do exactly this behind the curtain.
			b.cx = -40.0
			b.dir = 1.0
			b.lx = W * 0.5
			b.sirenT = 0.0
			b.hi = false
			b.pan = 0.0
			b.gain = 0.0
			b.dop = 1.0
			b.flash = 0.0
			b.closing = 0.0
			b.d = 1.0
			b.ry = GY - H * 0.1                              # the road, a little behind the hero
		"footsteps":
			# a footstep is an EVENT, not a loop: the run cycle has a CONTACT FRAME
			# where a foot lands (the kit's leg swing is sin(frame·9), so a plant is
			# every crossing of ±1), and that instant fires ONE sound. which sound is
			# a SURFACE LOOKUP under the foot — four noise recipes here, four sample
			# sets in a shipped game — and chapter 07's one-line trick, a random pitch
			# on every play, keeps forty steps from sounding like a machine gun. the
			# lexicon's Gait knows the cycle; this card listens to it.
			b.hx = -20.0
			b.dir = 1.0
			b.fc = 0.0
			b.lastK = 0
			b.led = 0.0
			b.plants = []                                    # recent plants: { t, band }
		"natter":
			# BEEP-SPEAK (Animal Crossing, Undertale, Celeste) is a typewriter with a
			# sound per letter. the letter's code picks a PITCH inside the character's
			# range — a hash, so the same word always sings the same tune — and its
			# class picks the WAVE: vowels get a longer sine, consonants a short square
			# click, spaces are silence. a whole cast of voices is one dial pair
			# (base, range) per character. the grimoire's Typewriter owns the cursor.
			b.li = 0
			b.shown = 0
			b.charT = 0.0
			b.holdT = 0.0
			b.mouth = 0.0
			b.strip = []                                     # recent blips: { k, vowel }
			b.cur = ""                                       # the letter being typed, for the caption
			b.typed = 0                                      # letters typed so far, for blipEvery
		"envelopes":
			# chapter 07's blip is one oscillator with a GAIN ENVELOPE (up fast, down
			# slowly) and a PITCH ENVELOPE (f0 sliding to f1). every classic effect
			# is those two curves with different numbers: a jump slides up, a hurt is
			# a square falling, a whistle is a long sine sweep, a boing is a sawtooth
			# dropping, a pickup is the same blip four times up an ARPEGGIO, and an
			# explosion swaps the oscillator for noise and sweeps a LOWPASS instead of
			# a pitch. each panel draws the two curves; a play sweeps a playhead over them.
			b.clock = 0.0
			b.next = 0
			b.play_i = -1                                    # the recipe playing (−1 = none)
			b.play_t0 = 0.0                                  # ...and when it started (−1 = at the next tick)
		"engine":
			# an ENGINE HUM is a continuous oscillator with two lines through it:
			# pitch rises with speed (an rpm curve), gain rises with speed (a throttle
			# curve). a shipped game loops a sample and moves playbackRate along the
			# same line. the kit's voices are one-shot, so after the first press the
			# hum is re-triggered in short OVERLAPPING segments — each one slides from
			# this frame's pitch to the next one's guess, so the joins vanish. the
			# lexicon's Vehicle and Motor knew the speed; this card lets you hear it.
			b.speed = 0.0
			b.throttle = 0.0
			b.manualT = 0.0
			b.auto = 0.0
			b.segT = 0.0
			b.road = 0.0
			b.lastSeg = 0.0
			b.wheel = 0.0
			b.exhaust = 0.0
			b.f = _freq_of(D, 0.0)
			b.g = float(D.idleVol)
			b.rpm = float(D.idleRpm)
		"noisebed":
			# every ambience bed is the same trick: WHITE NOISE through a highpass and
			# a LOWPASS, with two slow LFOs — one wandering the cutoff (the "whoosh"
			# of wind, the roll of surf), one wandering the gain (gusts, the wave's
			# rise). the recipe is six numbers, so wind, rain, surf and fire are four
			# rows of a table. the kit's noise is one-shot, so after the first press
			# the bed is a train of overlapping GRAINS, each sweeping its cutoff from
			# this tick's value to the next one's. chapter 07 called this "synthesize".
			var order: Array = D.order
			b.idx = maxi(0, order.find(D.bed))
			b.clock = 0.0
			b.grainT = 0.0
		"quiet":
			# MUFFLE is one LOWPASS on the whole SFX bus (chapter 07's buses): its
			# cutoff slides from wide open to a few hundred hertz and the world goes
			# distant — under water, behind a door, on the pause screen. the drawn
			# spectrum is what the filter does: the response |H(f)| falls off above
			# the cutoff, so the high bars die first. m is the muffle amount, and the
			# cutoff moves along a LOG scale (the ear hears octaves), which is why the
			# formula is a power and not a lerp. (the "world's" spectrum is the card's
			# own shape array, wobbled by noise — there is no analyser in the kit.)
			b.m = 0.0
			b.under = false
			b.clock = 0.0
			b.tickT = 0.0
			b.hx = W * 0.3
			b.hy = GY
			b.tx = W * 0.75
			b.target = 0.0
			b.cut = float(D.openHz)
			b.behind = 0.0
			var shape: Array = []
			for i in 32:
				shape.append(0.35 + 0.65 * pow(1.0 - i / 32.0, 1.6) * (0.7 + 0.3 * sin(i * 1.7)))
			b.shape = shape
		"yodel":
			# an ECHO is a DELAY LINE with FEEDBACK: the shout goes into a buffer,
			# comes out delay seconds later at mix, and a share (fb) of that goes back
			# in — so echo k arrives at k·delay, fb times quieter than the last. a
			# REVERB ZONE is just the mix dial tied to where the hero stands: near
			# zero in the open, high inside the cave, sliding across the mouth. the
			# kit has no tape loop, so the echoes are booked ahead with tone()'s at:
			# the same schedule the delay line would produce, drawn as ghost heroes.
			b.hx = W * 0.2
			b.dir = 1.0
			b.clock = 0.0
			b.mix = 0.0
			b.depth = 0.0
			b.want = false
			b.pending = []
			b.fired = []
		"jukebox":
			# ADAPTIVE MUSIC has two axes. VERTICAL: the track is several layers
			# playing in sync, and an INTENSITY number decides how many you hear —
			# each layer's gain chases clamp((I − threshold)/0.25), so drums come
			# first, then bass, then the lead (chapter 07's fade). HORIZONTAL: a
			# request to change section waits for the BAR LINE, so A becomes B on
			# step 0 and never mid-phrase. a STINGER is a one-shot hit booked for the
			# next beat. the sequencer runs silently until the first press.
			b.step = -1
			b.stepT = 0.0
			b.bar = 0
			b.section = 0
			b.pendingSection = false
			b.stinger = 0.0
			b.stingerReq = false
			b.intensity = 0.2
			b.target = 0.2
			b.idle = 99.0
			b.dirI = 1.0
			b.layers = ["drums", "bass", "lead"]
			b.gains = [0.0, 0.0, 0.0]
			b.flashes = [0.0, 0.0, 0.0]
		"lookahead":
			# a frame runs when the engine gets round to it — 16 ms apart, 50 under
			# load — so a metronome that plays "when t passes the beat" is late by a
			# random slice of a frame, and the ear hears the slop. the LOOKAHEAD
			# SCHEDULER (Chris Wilson's "a tale of two clocks") asks a different
			# question each frame: is any beat due inside the next lookahead seconds?
			# if so, book it on the AUDIO CLOCK at its exact time and move on. the
			# frame's jitter never reaches the note; the price is that a booked note
			# cannot be unbooked — press stop and the window still plays out.
			b.running = true
			b.dueF = 0.5
			b.dueS = 0.5
			b.beatsF = []
			b.beatsS = []
			b.queue = []
			b.sumF = 0.0
			b.nF = 0
			b.maxF = 0.0
		"quota":
			# every mixer has a POOL of players and a QUOTA per sound. a request finds
			# its sound's live count: under the cap and a free slot → play; at the cap
			# → STEAL one of its own (the oldest, or the quietest by current level) or
			# refuse the newcomer; pool full → steal across all sounds. twenty coins
			# in a frame cost three voices, not twenty. this page's Pool did the same
			# for particles. the kit cannot cut a voice short, so the audio side plays
			# only the accepted requests, at most six a second.
			b.acc = 0.0
			b.burstLeft = 0
			b.burstAcc = 0.0
			b.tokens = 0.0
			b.requests = 0
			b.steals = 0
			b.refused = 0
			var slots: Array = []
			for _i in 24:
				slots.append(null)
			b.slots = slots
			b.reqlog = []
		"analyser":
			# an ANALYSER node sits at the end of the graph and hands back the output's
			# SPECTRUM as bins; anything can read them — bar heights, a glow's radius,
			# a camera zoom on the bass. the visual half needs ENVELOPE FOLLOWING: a
			# bar jumps up to a loud bin and falls slowly, or it flickers. here the
			# low bins become "bass" and scale the whole scene (chapter 11's music
			# visualiser, made a camera). the kit has no analyser, so the bins are
			# ALWAYS the pattern faked from the beat clock (the web does the same
			# when its tab is silent): the picture never depends on the speakers.
			b.playing = true
			b.beatT = 0.0
			b.beat = 0
			b.kick = 0.0
			b.hat = 0.0
			b.bass = 0.0
			var hb: Array = []
			var fk: Array = []
			for _i in 32:
				hb.append(0.0)
				fk.append(0.0)
			b.hbins = hb                                     # the followed bar heights, 0..1
			b.fake = fk                                      # this tick's "bins", 0..255
		"rumble":
			# a gamepad has two MOTORS — a heavy low-frequency one for weight and a
			# light high-frequency one for texture — and a haptic PATTERN is a list
			# of pulses: (motor, start, duration, strength). a phone has one motor and
			# takes the same list flattened into vibrate([on, off, on, …]) ms. the
			# envelope is the picture: at any instant each motor runs at the strongest
			# pulse covering it. chapter 06's screen shake is the third motor here,
			# scaled by the same envelope. the tones after the first press are the
			# motors hummed at their two pitches.
			b.hx = W * 0.3
			b.vy = 0.0
			b.hy = GY
			b.jumpT = 0.0
			b.hitT = 1.5
			b.hurt = 0.0
			b.next = 0
			b.lastName = ""
			b.lastVib = ""
			b.want = ""
			b.events = []
			b.G = H * 2.4
			b.lo = 0.0
			b.hi = 0.0
			b.inten = 0.0
			b.shake = Vector2.ZERO

# ================================================================ press

static func press(b: Dictionary, pos: Vector2) -> void:
	var D: Dictionary = b.D
	var W: float = b.w
	var H: float = b.h
	b.armed_sound = true                                 # sound only after a press
	match b.id:
		"positional":
			b.lx = clampf(pos.x, 20.0, W - 20.0)
		"footsteps":
			b.dir = 1.0 if pos.x > float(b.hx) else -1.0
		"natter":
			var lines: Array = D.lines
			b.li = (int(b.li) + 1) % lines.size()
			b.shown = 0
			b.holdT = 0.0
			b.charT = 0.0
		"envelopes":
			var cols := 3
			var gw := (W - 12.0) / cols
			var gh := (H - 40.0) / 2.0
			var c := clampi(floori((pos.x - 6.0) / gw), 0, cols - 1)
			var r := clampi(floori((pos.y - 20.0) / gh), 0, 1)
			var i := r * cols + c
			var recipes: Array = D.recipes
			if i < recipes.size():
				b.play_i = i
				b.play_t0 = -1.0
				_env_sound(D, recipes[i])
				b.clock = 0.0
		"engine":
			b.throttle = clampf(pos.x / W, 0.0, 1.0)
			b.manualT = float(D.manual)
		"noisebed":
			var order: Array = D.order
			b.idx = (int(b.idx) + 1) % order.size()
			b.clock = 0.0
		"quiet":
			if D.mode == "door":
				b.tx = clampf(pos.x, 16.0, W - 16.0)
			else:
				b.under = not b.under
				b.clock = 0.0
		"yodel":
			b.want = true
			b.clock = 0.0
		"jukebox":
			b.idle = 0.0
			var tg: float = b.target
			b.target = 0.0 if tg + 0.34 > 1.01 else clampf(tg + 0.34, 0.0, 1.0)
			b.stingerReq = true
		"lookahead":
			b.running = not b.running
			if b.running:
				b.dueF = -1.0
				b.dueS = -1.0
		"quota":
			b.burstLeft = int(b.burstLeft) + int(D.burst)
		"analyser":
			b.playing = not b.playing
		"rumble":
			var order: Array = D.order
			b.want = order[int(b.next) % order.size()]
			b.next = int(b.next) + 1

# ================================================================ tick

static func tick(b: Dictionary, dt: float, t: float) -> void:
	var D: Dictionary = b.D
	var W: float = b.w
	var H: float = b.h
	var GY: float = b.gy
	match b.id:
		"positional":
			var dir: float = b.dir
			var cx: float = b.cx + dir * W * float(D.speed) * dt
			if cx > W + 50.0:
				dir = -1.0
			elif cx < -50.0:
				dir = 1.0
			b.cx = cx
			b.dir = dir
			var lx: float = b.lx
			var ly := GY - H * 0.12                          # the listener's ears
			var dx := cx - lx
			var dy := float(b.ry) - 6.0 - ly
			var d := maxf(1.0, sqrt(dx * dx + dy * dy))
			var pan := clampf(dx / (W * 0.5), -1.0, 1.0)
			var refd := maxf(1.0, W * float(D.refDist))
			var gain := 1.0 / (1.0 + (d / refd) * (d / refd))
			var vx := dir * W * float(D.speed)               # the source's velocity
			var closing := vx * (-dx / d)                    # ...projected on the line to the ear
			var c := maxf(1.0, W * float(D.soundSpeed))
			var dop := c / maxf(c * 0.25, c - closing)       # f′/f, guarded so it can never blow up
			b.pan = pan
			b.gain = gain
			b.dop = dop
			b.closing = closing
			b.d = d
			b.ly = ly
			b.sirenT += dt
			b.flash = maxf(0.0, float(b.flash) - dt * 4.0)
			if b.armed_sound and float(b.sirenT) >= float(D.every):   # one siren voice per tick, panned and attenuated
				b.sirenT = 0.0
				b.hi = not b.hi
				b.flash = 1.0
				var f := (float(D.baseHz) + (float(D.wobbleHz) if b.hi else 0.0)) * dop
				Kit.tone({ "freq": f, "slide_to": f * (0.97 if b.hi else 1.03), "type": "triangle", "dur": float(D.every) * 1.4,
					"vol": float(D.vol) * gain, "pan": pan, "attack": 0.02 })
		"footsteps":
			var bands: Array = D.bands
			var recipes: Dictionary = D.recipes
			var dir: float = b.dir
			var hx: float = b.hx + dir * W * float(D.speed) * dt
			if hx > W + 24.0:
				dir = -1.0
			elif hx < -24.0:
				dir = 1.0
			b.hx = hx
			b.dir = dir
			var legs: int = D.legs
			b.fc += dt * float(D.cadence)
			var ph: float = b.fc * 9.0                       # the kit's swing phase
			var k := floori((ph - PI / 2.0) / (TAU / legs))  # which plant we are on
			if k != int(b.lastK):                            # the contact frame: fire the event
				b.lastK = k
				b.led = 1.0
				var band := _band_at(b, hx)
				var nm: String = bands[band]
				var r: Dictionary = recipes[nm]
				var plants: Array = b.plants
				plants.append({ "t": t, "band": band })
				if plants.size() > 24:
					plants.pop_front()
				if b.armed_sound:
					# the kit's noise has no highpass and no playbackRate: the random
					# rate rides the cutoff instead (a faster buffer is a brighter one)
					var rate := float(r.rate) * (1.0 + randf_range(-float(D.humanise), float(D.humanise)))
					Kit.noise_burst({ "dur": r.dur, "vol": r.vol, "lowpass": float(r.lowpass) * rate,
						"sweep_to": float(r.get("sweepTo", r.lowpass)) * rate, "pan": clampf(hx / W * 2.0 - 1.0, -1.0, 1.0) })
			b.led = maxf(0.0, float(b.led) - dt * 6.0)
		"natter":
			var lines: Array = D.lines
			var line_s: String = lines[int(b.li)]
			var shown: int = b.shown
			if shown < line_s.length():
				b.charT += dt
				var ch := line_s[shown]
				var pause := 3.0 if (ch == "." or ch == "!" or ch == "?") else (2.0 if ch == "," else 1.0)
				if float(b.charT) >= pause / maxf(0.1, float(D.cps)):
					b.charT = 0.0
					b.shown = shown + 1
					b.cur = ch
					if _is_letter(ch):
						b.typed = int(b.typed) + 1
						var k := _pitch_of(ch)
						var v := _is_vowel(ch)
						var f := float(D.base) * (1.0 + k * float(D.range))
						var strip: Array = b.strip
						strip.append({ "k": k, "vowel": v })
						if strip.size() > 28:
							strip.pop_front()
						b.mouth = 0.25 if v else 0.1
						if b.armed_sound and int(b.typed) % maxi(1, int(D.blipEvery)) == 0:
							Kit.tone({ "freq": f, "type": "sine" if v else "square", "dur": D.vowelDur if v else D.consDur,
								"vol": float(D.vol) * (1.0 if v else 0.7), "attack": 0.004 })
			else:
				b.holdT += dt
				if float(b.holdT) > float(D.hold):
					b.li = (int(b.li) + 1) % lines.size()
					b.shown = 0
					b.holdT = 0.0
			b.mouth = maxf(0.0, float(b.mouth) - dt)
		"envelopes":
			var recipes: Array = D.recipes
			if int(b.play_i) >= 0 and float(b.play_t0) == -1.0:
				b.play_t0 = t
			b.clock += dt
			if float(b.clock) >= float(D.every):
				b.clock = 0.0
				b.play_i = int(b.next)
				b.play_t0 = t
				if b.armed_sound:
					_env_sound(D, recipes[int(b.next)])
				b.next = (int(b.next) + 1) % recipes.size()
			if int(b.play_i) >= 0 and t - float(b.play_t0) > _env_len(recipes[int(b.play_i)], float(D.stretch)) + 0.15:
				b.play_i = -1
		"engine":
			var throttle: float = b.throttle
			if float(b.manualT) > 0.0:
				b.manualT -= dt
			else:                                            # the autopilot's throttle: a slow cycle of pull, cruise, brake
				b.auto += dt
				var ph := fmod(float(b.auto), 9.0)
				throttle = 1.0 if ph < 3.0 else (0.55 if ph < 5.5 else (0.0 if ph < 7.0 else 0.25))
				b.throttle = throttle
			var speed: float = b.speed
			var rate: float = float(D.accel) if throttle > speed else float(D.brake)
			speed += (throttle - speed) * Kit.smooth(rate * 2.2, dt)
			speed = clampf(speed, 0.0, 1.0)
			b.speed = speed
			var f := _freq_of(D, speed)
			var g := lerpf(float(D.idleVol), float(D.vol), speed)
			b.f = f
			b.g = g
			b.rpm = lerpf(float(D.idleRpm), float(D.maxRpm), speed)
			b.segT += dt
			var seg: float = D.seg
			if b.armed_sound and float(b.segT) >= seg:      # one overlapping segment per tick, sliding toward the guess
				b.segT = 0.0
				var guess := clampf(speed + (speed - float(b.lastSeg)), 0.0, 1.0)
				b.lastSeg = speed
				# (the web's decayTo is not in the kit: the segment simply fades)
				Kit.tone({ "freq": f, "slide_to": _freq_of(D, guess), "type": D.wave, "dur": seg * 1.8, "vol": g, "attack": seg * 0.6 })
			b.road = fmod(float(b.road) + speed * W * 0.9 * dt, 40.0)   # the road scrolls under a fixed car
			b.wheel += speed * 14.0 * dt
			b.exhaust += dt * (2.0 + speed * 10.0)
		"noisebed":
			var order: Array = D.order
			var beds: Dictionary = D.beds
			b.clock += dt
			if float(b.clock) >= float(D.every):
				b.clock = 0.0
				b.idx = (int(b.idx) + 1) % order.size()
			b.grainT += dt
			if b.armed_sound and float(b.grainT) >= float(D.grain):
				b.grainT = 0.0
				_bed_grains(D, beds[order[int(b.idx)]], t)
				if D.second != "":
					_bed_grains(D, beds[D.second], t)
		"quiet":
			var target := 0.0
			var hx: float = b.hx
			if D.mode == "door":
				var tx: float = b.tx
				hx += clampf(tx - hx, -1.0, 1.0) * minf(absf(tx - hx), W * 0.22 * dt)
				if absf(tx - hx) < 2.0:
					b.clock += dt
					if float(b.clock) > float(D.every) * 0.6:
						b.clock = 0.0
						b.tx = randf_range(W * 0.08, W * 0.92)
				var door_x := W * 0.5
				var behind := clampf((hx - door_x) / (W * float(D.range)), 0.0, 1.0)
				b.behind = behind
				target = (0.45 + 0.55 * behind) if hx > door_x else 0.0
				b.hx = hx
			else:
				b.clock += dt
				if float(b.clock) >= float(D.every):
					b.clock = 0.0
					b.under = not b.under
				var px := W * 0.4
				var under: bool = b.under
				var goal_x := W * 0.68 if under else px - 12.0
				var goal_y := GY + H * 0.11 if under else GY - 4.0
				b.hx = hx + (goal_x - hx) * Kit.smooth(4.0, dt)
				b.hy = float(b.hy) + (goal_y - float(b.hy)) * Kit.smooth(3.0, dt)
				target = 1.0 if under else 0.0
			b.target = target
			var m: float = b.m
			m += (target - m) * Kit.smooth(float(D.slide), dt)
			m = clampf(m, 0.0, 1.0)
			b.m = m
			var cut := float(D.openHz) * pow(float(D.closedHz) / float(D.openHz), m)
			b.cut = cut
			b.tickT += dt
			if b.armed_sound and float(b.tickT) >= float(D.tick):   # the world's ticks: noise through the muffle
				b.tickT = 0.0
				# (no highpass / playbackRate in the kit: the random rate rides the cutoff)
				Kit.noise_burst({ "dur": 0.22, "vol": 0.12, "lowpass": cut * randf_range(0.8, 1.25), "pan": randf_range(-0.6, 0.6) })
		"yodel":
			if b.want:
				b.want = false
				_shout(b, t)
			var cx := W * float(D.caveX)
			var dir: float = b.dir
			var hx: float = b.hx + dir * W * 0.12 * dt
			if hx > W * 0.9:
				dir = -1.0
			elif hx < W * 0.14:
				dir = 1.0
			b.hx = hx
			b.dir = dir
			var depth := clampf((hx - cx) / (W * 0.12), 0.0, 1.0)
			b.depth = depth
			b.mix = lerpf(float(D.openMix), float(D.caveMix), _ease(depth))
			b.clock += dt
			if float(b.clock) >= float(D.every):
				b.clock = 0.0
				_shout(b, t)
			var pending: Array = b.pending
			var fired: Array = b.fired
			var i := pending.size() - 1
			while i >= 0:
				var e: Dictionary = pending[i]
				if float(e.at) <= t:
					e.t0 = t
					fired.append(e)
					pending.remove_at(i)
				i -= 1
			while fired.size() > 12:
				fired.pop_front()
			if pending.size() > 24:
				b.pending = pending.slice(pending.size() - 24)
			i = fired.size() - 1
			while i >= 0:                                    # a fired echo lives 0.7 s as a ghost
				var e: Dictionary = fired[i]
				if t - float(e.t0) > 0.7:
					fired.remove_at(i)
				i -= 1
		"jukebox":
			var thr: Array = D.thresholds
			var gains: Array = b.gains
			var flashes: Array = b.flashes
			var flo: float = D.floor
			var target: float = b.target
			b.idle += dt
			if float(b.idle) > 6.0:                          # the autopilot: a slow triangle between floor and 1
				target += float(b.dirI) * float(D.drift) * dt
				if target > 1.0:
					target = 1.0
					b.dirI = -1.0
				elif target < flo:
					target = flo
					b.dirI = 1.0
			target = clampf(maxf(target, flo), 0.0, 1.0)
			b.target = target
			b.intensity += (target - float(b.intensity)) * Kit.smooth(3.0, dt)
			var fade: float = D.fade
			for i in 3:
				var want := clampf((float(b.intensity) - float(thr[i])) / 0.25, 0.0, 1.0)
				gains[i] = float(gains[i]) + clampf(want - float(gains[i]), -fade * dt, fade * dt)
				flashes[i] = maxf(0.0, float(flashes[i]) - dt * 8.0)
			b.stinger = maxf(0.0, float(b.stinger) - dt * 3.0)
			var sd := _step_dur(D)
			b.stepT += dt
			if float(b.stepT) > sd * 4.0:                    # a long skip: resync rather than replay every step
				b.stepT = sd
			var guard := 0
			var steps: int = D.steps
			while float(b.stepT) >= sd and guard < 4:
				guard += 1
				b.stepT -= sd
				var stp: int = (int(b.step) + 1) % steps
				b.step = stp
				if stp == 0:
					b.bar = int(b.bar) + 1
					if b.pendingSection:
						b.section = 1 - int(b.section)
						b.pendingSection = false
					if int(b.bar) % int(D.sectionEvery) == 0:
						b.pendingSection = true
					if int(b.bar) % int(D.stingerEvery) == 0:
						b.stingerReq = true
				if b.stingerReq and stp % 2 == 0:
					b.stingerReq = false
					_play_stinger(b)
				_play_step(b, stp)
		"lookahead":
			var p := 60.0 / float(D.bpm)
			if float(b.dueF) == -1.0:
				b.dueF = t + p
				b.dueS = t + p
			var beats_f: Array = b.beatsF
			var beats_s: Array = b.beatsS
			var queue: Array = b.queue
			if b.running:
				if t - float(b.dueF) > 2.0:                  # a long skip: resync, do not replay the gap
					b.dueF = t
				if t >= float(b.dueF):                       # the frame-timed one: fires late by the frame's slice
					var err := t - float(b.dueF)
					beats_f.append({ "t": t, "err": err })
					b.sumF += err
					b.nF = int(b.nF) + 1
					b.maxF = maxf(float(b.maxF), err)
					if b.armed_sound:
						Kit.tone({ "freq": D.fLow, "type": "square", "dur": 0.05, "vol": D.vol, "pan": -0.5 })
					b.dueF += p
					if t >= float(b.dueF):
						b.dueF = t + p
				if t - float(b.dueS) > 2.0:
					b.dueS = t
				var guard := 0
				while float(b.dueS) < t + float(D.lookahead) and guard < 8:   # the scheduled one: book everything inside the window
					guard += 1
					queue.append({ "due": b.dueS, "booked": t })
					if b.armed_sound:
						Kit.tone({ "freq": D.fHigh, "type": "square", "dur": 0.05, "vol": D.vol, "pan": 0.5, "at": maxf(0.0, float(b.dueS) - t) })
					b.dueS += p
			var i := queue.size() - 1
			while i >= 0:
				var q: Dictionary = queue[i]
				if float(q.due) <= t:
					beats_s.append({ "t": q.due, "err": 0.0, "late": float(q.due) - float(q.booked) })
					queue.remove_at(i)
				i -= 1
			var window: float = D.window
			while beats_f.size() > 0 and t - float((beats_f[0] as Dictionary).t) > window:
				beats_f.pop_front()
			while beats_s.size() > 0 and t - float((beats_s[0] as Dictionary).t) > window:
				beats_s.pop_front()
		"quota":
			var slots: Array = b.slots
			var sounds: Dictionary = D.sounds
			var mps: float = D.maxPerSec
			b.tokens = minf(mps, float(b.tokens) + dt * mps)
			b.acc += dt * float(D.rate)
			var guard := 0
			while float(b.acc) >= 1.0 and guard < 8:
				guard += 1
				b.acc -= 1.0
				_q_request(b, "coin" if randf() < 0.6 else "hit", t)
			if int(b.burstLeft) > 0:
				b.burstAcc += dt * float(D.burst) / maxf(0.05, float(D.burstSpan))
				var g2 := 0
				while float(b.burstAcc) >= 1.0 and int(b.burstLeft) > 0 and g2 < 40:
					g2 += 1
					b.burstAcc -= 1.0
					b.burstLeft = int(b.burstLeft) - 1
					_q_request(b, "coin" if randf() < 0.7 else "hit", t)
			for i in int(D.slots):
				var v: Variant = slots[i]
				if v != null:
					var vd: Dictionary = v
					vd.flash = maxf(0.0, float(vd.flash) - dt * 3.0)
					if t - float(vd.born) > float((sounds[vd.name] as Dictionary).dur):
						slots[i] = null
		"analyser":
			var p := 60.0 / float(D.bpm)
			b.beatT += dt
			if float(b.beatT) > p * 4.0:
				b.beatT = p
			var guard := 0
			var playing: bool = b.playing
			while float(b.beatT) >= p / 2.0 and guard < 4:   # an eighth-note clock: kicks on the beat, hats off it
				guard += 1
				b.beatT -= p / 2.0
				var beat: int = (int(b.beat) + 1) % 8
				b.beat = beat
				if not playing:
					continue
				if beat % 2 == 0:
					b.kick = 1.0
					if b.armed_sound:
						Kit.tone({ "freq": 150.0, "slide_to": 45.0, "type": "sine", "dur": 0.18, "vol": 0.22 })
					if b.armed_sound and beat % 4 == 0:
						Kit.tone({ "freq": 82.0 if beat == 0 else 98.0, "type": "square", "dur": 0.3, "vol": 0.1 })
				else:
					b.hat = 1.0
					if b.armed_sound:                        # (no highpass in the kit: a short bright burst)
						Kit.noise_burst({ "dur": 0.04, "vol": 0.06, "lowpass": 9000.0 })
			var kick := maxf(0.0, float(b.kick) - dt * 6.0)
			var hat := maxf(0.0, float(b.hat) - dt * 14.0)
			b.kick = kick
			b.hat = hat
			# the fake beat: a kick low, a bass hump, hats high — the only bins here
			var fake: Array = b.fake
			var hb: Array = b.hbins
			var attack: float = D.attack
			var release: float = D.release
			var bass := 0.0
			for i in 32:
				var fi := float(i)
				var v: float
				if playing:
					v = 255.0 * clampf(kick * exp(-fi / 2.2) + kick * 0.7 * exp(-(fi - 3.0) * (fi - 3.0) / 3.0)
						+ hat * 0.6 * exp(-(fi - 22.0) * (fi - 22.0) / 24.0) + 0.04 + 0.03 * Kit.noise(fi * 0.8 + t * 5.0), 0.0, 1.0)
				else:
					v = 255.0 * (0.03 + 0.02 * Kit.noise(fi * 0.8 + t * 2.0))
				fake[i] = v
				var target := v / 255.0
				var hcur: float = hb[i]
				hcur = hcur + (target - hcur) * clampf(attack * dt, 0.0, 1.0) if target > hcur else hcur * exp(-release * dt)
				hb[i] = hcur
				if i < 4:
					bass += hcur / 4.0
			b.bass = bass
		"rumble":
			if b.want != "":
				_trigger(b, b.want, t)
				b.want = ""
			# the hero: runs on the spot, jumps on a timer and lands, takes a hit on another
			var G: float = b.G
			b.jumpT += dt
			b.hitT += dt
			if float(b.jumpT) >= float(D.jumpEvery) and float(b.hy) >= GY:
				b.jumpT = 0.0
				b.vy = -sqrt(2.0 * G * H * 0.22)
			b.vy += G * dt
			b.hy += float(b.vy) * dt
			var landed := false
			if float(b.hy) >= GY:
				if float(b.vy) > H * 0.5:
					landed = true
				b.hy = GY
				b.vy = 0.0
			if landed:
				_trigger(b, "land", t)
			if float(b.hitT) >= float(D.hitEvery):
				b.hitT = 0.0
				_trigger(b, "hit", t)
				b.hurt = 0.35
			b.hurt = maxf(0.0, float(b.hurt) - dt)
			var lo := _motor(b, 0, t)
			var hi := _motor(b, 1, t)
			var inten := maxf(lo, hi)
			b.lo = lo
			b.hi = hi
			b.inten = inten
			b.shake = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * inten * float(D.shake)

# ================================================================ draw

## Noisebed: one bed's panel — left, the filter's response on a log axis with
## the cutoff moving; right, the two LFO curves over an 8-second window.
static func _bed_panel(n: CanvasItem, b: Dictionary, D: Dictionary, nm: String, bed: Dictionary, r: Rect2, tt: float, main: bool) -> void:
	var col := _bed_colour(nm)
	var cut := _bed_cutoff(D, bed, tt)
	var g := _bed_gain(D, bed, tt)
	var x0 := r.position.x
	var y0 := r.position.y
	var w := r.size.x
	var h := r.size.y
	_panel(n, r, PANEL, FRAME)
	Kit.text(n, nm + ("" if main else " (under)"), Vector2(x0 + 4.0, y0 + 11.0), 10, col)
	var fw := w * 0.42
	var fy0 := y0 + 16.0
	var fh := h - 22.0
	var hp: float = bed.highpass
	Kit.label(n, b, "hp %d" % roundi(hp), Vector2(x0 + 4.0, y0 + h - 3.0), Kit.DIM)
	_label_r(n, b, "lp %d" % roundi(cut), Vector2(x0 + fw, y0 + h - 3.0), col)
	var pts := PackedVector2Array([Vector2(x0 + 4.0, fy0 + fh)])
	for k in 31:
		var f := 40.0 * pow(300.0, k / 30.0)
		var hpk := 1.0 / sqrt(1.0 + pow(hp / f, 4.0))
		var lpk := 1.0 / sqrt(1.0 + pow(f / cut, 4.0))
		pts.append(Vector2(_fx(f, x0 + 4.0, fw - 8.0), fy0 + fh - fh * maxf(0.002, hpk * lpk * g / 0.25)))
	pts.append(Vector2(x0 + fw - 4.0, fy0 + fh))
	n.draw_colored_polygon(pts, Color(0.788, 0.769, 0.894, 0.14))
	var cxl := _fx(cut, x0 + 4.0, fw - 8.0)
	n.draw_line(Vector2(cxl, fy0), Vector2(cxl, fy0 + fh), col, 1.5)
	var lx := x0 + fw + 6.0
	var lw := w - fw - 10.0
	var span := 8.0
	var ln2 := log(2.0)
	var depth := maxf(0.05, float(bed.depth))
	var vol: float = bed.vol
	var sc: float = D.lfoScale
	for row in 2:
		var ry0 := fy0 + row * (fh / 2.0)
		var rh := fh / 2.0 - 3.0
		var title := ("gain lfo %.2f Hz" % (float(bed.glfo) * sc)) if row == 1 else ("cutoff lfo %.2f Hz" % (float(bed.lfo) * sc))
		Kit.label(n, b, title, Vector2(lx, ry0 + 8.0), Kit.DIM)
		var curve := PackedVector2Array()
		for k in 33:
			var tk := tt - span * 0.7 + span * k / 32.0
			var v := (_bed_gain(D, bed, tk) / vol) if row == 1 else ((log(_bed_cutoff(D, bed, tk) / float(bed.lowpass)) / ln2 / depth + 1.0) / 2.0)
			curve.append(Vector2(lx + lw * k / 32.0, ry0 + rh - (rh - 9.0) * clampf(v, 0.0, 1.0)))
		n.draw_polyline(curve, col if row == 1 else _al(Kit.INK, 0.6), 1.0)
		var pxh := lx + lw * 0.7
		n.draw_line(Vector2(pxh, ry0 + 8.0), Vector2(pxh, ry0 + rh), _al(Kit.INK, 0.35), 1.0)
		var vnow := (g / vol) if row == 1 else ((log(cut / float(bed.lowpass)) / ln2 / depth + 1.0) / 2.0)
		Kit.dot(n, Vector2(pxh, ry0 + rh - (rh - 9.0) * clampf(vnow, 0.0, 1.0)), 2.5, col)

static func draw(n: CanvasItem, b: Dictionary, t: float) -> void:
	var D: Dictionary = b.D
	var W: float = b.w
	var H: float = b.h
	var GY: float = b.gy
	var origin: Vector2 = (b.rect as Rect2).position
	match b.id:
		"positional":
			Kit.stage(n, b, 0.35)
			var cx: float = b.cx
			var dir: float = b.dir
			var lx: float = b.lx
			var ly := GY - H * 0.12
			var ry: float = b.ry
			var hi: bool = b.hi
			var flash: float = b.flash
			var pan: float = b.pan
			var gain: float = b.gain
			var dop: float = b.dop
			# the road, the car, the listener
			n.draw_rect(Rect2(0.0, ry - 5.0, W, 10.0), ROAD)
			_dash(n, Vector2(0.0, ry), Vector2(W, ry), 6.0, 8.0, _al(Kit.INK, 0.25))
			var cw := W * 0.12
			var ch := H * 0.06
			n.draw_rect(Rect2(cx - cw / 2.0, ry - 4.0 - ch, cw, ch), Kit.WATER)
			n.draw_rect(Rect2(cx - cw * 0.3, ry - 4.0 - ch * 1.7, cw * 0.55, ch * 0.7), INK_DARK)
			Kit.dot(n, Vector2(cx - cw * 0.3, ry - 2.0), ch * 0.3, INK_DARK)
			Kit.dot(n, Vector2(cx + cw * 0.3, ry - 2.0), ch * 0.3, INK_DARK)
			Kit.dot(n, Vector2(cx, ry - 4.0 - ch * 1.8), 3.0, Kit.HOT if hi else Kit.WATER)   # the light bar, hee-haw
			if flash > 0.0:
				Kit.ring(n, Vector2(cx, ry - 4.0 - ch * 1.8), 3.0 + (1.0 - flash) * 14.0, _al(Kit.HOT if hi else Kit.WATER, flash * 0.6), 1.5)
			_dash(n, Vector2(cx, ry - 4.0 - ch / 2.0), Vector2(lx, ly), 3.0, 4.0, Kit.DIM)
			Kit.label(n, b, "d = %d" % roundi(float(b.d)), Vector2((cx + lx) / 2.0, (ry + ly) / 2.0 - 6.0), Kit.DIM, true)
			Kit.hero(n, b, Vector2(lx, GY), { "face": 1 if cx > lx else -1, "frame": t })
			Kit.ring(n, Vector2(lx, ly), 6.0 + sin(t * 6.0) * 2.0, _al(Kit.INK, 0.35), 1.0)
			Kit.label(n, b, "listener", Vector2(lx, GY + 12.0), Kit.DIM, true)
			# three meters: pan, gain, pitch
			var mw := W * 0.28
			var mh := H * 0.2
			var my := 6.0
			var gap := (W - mw * 3.0) / 4.0
			var mx := gap
			_meter_box(n, b, Rect2(mx, my, mw, mh), "pan %.2f" % pan)
			n.draw_line(Vector2(mx + 8.0, my + mh * 0.62), Vector2(mx + mw - 8.0, my + mh * 0.62), Kit.BONE, 1.0)
			Kit.label(n, b, "L", Vector2(mx + 6.0, my + mh - 4.0), Kit.DIM)
			_label_r(n, b, "R", Vector2(mx + mw - 6.0, my + mh - 4.0), Kit.DIM)
			Kit.dot(n, Vector2(mx + mw / 2.0 + pan * (mw / 2.0 - 10.0), my + mh * 0.62), 4.0, Kit.SUN)
			mx += mw + gap
			_meter_box(n, b, Rect2(mx, my, mw, mh), "gain %.2f" % gain)
			n.draw_rect(Rect2(mx + 8.0, my + mh * 0.5, mw - 16.0, mh * 0.3), TRACK)
			n.draw_rect(Rect2(mx + 8.0, my + mh * 0.5, (mw - 16.0) * gain, mh * 0.3), Kit.SUN)
			mx += mw + gap
			_meter_box(n, b, Rect2(mx, my, mw, mh), "pitch ×%.2f" % dop)
			var nx := mx + mw / 2.0
			var ny := my + mh - 4.0
			var nr := mh * 0.6
			n.draw_arc(Vector2(nx, ny), nr, PI, TAU, 24, Kit.BONE, 1.0)
			var na := PI + clampf((dop - 0.5) / 1.0, 0.0, 1.0) * PI   # 0.5× .. 1.5× across the dial
			n.draw_line(Vector2(nx, ny), Vector2(nx + cos(na) * nr, ny + sin(na) * nr), Kit.HOT if float(b.closing) > 0.0 else Kit.WATER, 2.0)
			Kit.label(n, b, "1×", Vector2(nx, ny - nr - 3.0), Kit.DIM, true)
			Kit.arrow(n, Vector2(cx, ry + 14.0), Vector2(cx + dir * 22.0, ry + 14.0), Kit.INK)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"footsteps":
			Kit.stage(n, b)
			var bands: Array = D.bands
			var colours: Array = D.colours
			var recipes: Dictionary = D.recipes
			var bw := W / bands.size()
			for i in bands.size():                           # the surface bands, drawn on the ground
				n.draw_rect(Rect2(i * bw, GY, bw, H - GY), Color(colours[i] as String))
				n.draw_rect(Rect2(i * bw, GY - 2.0, bw, 3.0), Color(0.075, 0.063, 0.125, 0.35))
				Kit.label(n, b, bands[i], Vector2(i * bw + bw / 2.0, GY + 16.0), Color(0.075, 0.063, 0.125, 0.75), true)
			var hx: float = b.hx
			var dir: float = b.dir
			var led: float = b.led
			var band := _band_at(b, clampf(hx, 0.0, W - 1.0))
			var nm: String = bands[band]
			var r: Dictionary = recipes[nm]
			var col := Color(colours[band] as String)
			if led > 0.0:
				Kit.ring(n, Vector2(hx, GY), 3.0 + (1.0 - led) * 12.0, _al(Kit.INK, led * 0.8), 1.5)
			Kit.hero(n, b, Vector2(hx, GY - (3.0 if nm == "water" else 0.0)), { "pose": "run", "frame": b.fc, "face": int(dir) })
			# the recipe card for the band underfoot, and the plant LED
			var px := 8.0
			var py := 8.0
			var pw := W * 0.46
			var phh := H * 0.3
			_panel(n, Rect2(px, py, pw, phh), PANEL, FRAME35)
			Kit.text(n, nm, Vector2(px + 6.0, py + 13.0), 11, col)
			Kit.dot(n, Vector2(px + pw - 10.0, py + 9.0), 4.0, Kit.SUN if led > 0.0 else _al(Kit.SUN, 0.2))
			_label_r(n, b, "plant", Vector2(px + pw - 18.0, py + 12.0), Kit.DIM)
			var rows: Array = [["lowpass", float(r.lowpass) / 6000.0], ["highpass", float(r.highpass) / 6000.0], ["dur", float(r.dur) / 0.25], ["vol", float(r.vol) / 0.25]]
			for i in rows.size():
				var row: Array = rows[i]
				var yy := py + 20.0 + i * ((phh - 24.0) / rows.size())
				Kit.label(n, b, row[0], Vector2(px + 6.0, yy + 8.0), Kit.DIM)
				n.draw_rect(Rect2(px + pw * 0.42, yy + 1.0, pw * 0.52, 7.0), Color(0.788, 0.769, 0.894, 0.12))
				n.draw_rect(Rect2(px + pw * 0.42, yy + 1.0, pw * 0.52 * clampf(row[1], 0.0, 1.0), 7.0), col)
			# the last few plants on a timeline, coloured by band
			var tx0 := W * 0.56
			var tw := W * 0.4
			var ty := H * 0.16
			n.draw_line(Vector2(tx0, ty), Vector2(tx0 + tw, ty), Kit.DIM, 1.0)
			Kit.label(n, b, "plants, last 4 s", Vector2(tx0, ty - 6.0), Kit.DIM)
			for p in b.plants:
				var pl: Dictionary = p
				var age := t - float(pl.t)
				if age > 4.0:
					continue
				Kit.dot(n, Vector2(tx0 + tw * (1.0 - age / 4.0), ty), 3.0, Color(colours[int(pl.band)] as String))
			var legs: int = D.legs
			Kit.label(n, b, "legs %d · %.1f plants/s" % [legs, 9.0 * float(D.cadence) / (TAU / legs)], Vector2(tx0, ty + 16.0), Kit.DIM)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"natter":
			Kit.stage(n, b, 0.0, true)
			var lines: Array = D.lines
			var line_s: String = lines[int(b.li)]
			var shown: int = b.shown
			var mouth: float = b.mouth
			var cur: String = b.cur
			# the speaker and the bubble
			var hxp := W * 0.16
			Kit.hero(n, b, Vector2(hxp, GY), { "frame": t, "face": 1 })
			if mouth > 0.0:
				n.draw_rect(Rect2(hxp - 2.0, GY - H * 0.2, 4.0, 2.0 + mouth * 12.0), INK_DARK)
			var bx := W * 0.3
			var by := H * 0.12
			var bw := W * 0.62
			var bh := H * 0.36
			var bub: Array = [Vector2(bx + 6.0, by), Vector2(bx + bw - 6.0, by)]
			bub.append_array(_quad(Vector2(bx + bw - 6.0, by), Vector2(bx + bw, by), Vector2(bx + bw, by + 6.0), 3))
			bub.append(Vector2(bx + bw, by + bh - 6.0))
			bub.append_array(_quad(Vector2(bx + bw, by + bh - 6.0), Vector2(bx + bw, by + bh), Vector2(bx + bw - 6.0, by + bh), 3))
			bub.append(Vector2(bx + 18.0, by + bh))
			bub.append(Vector2(bx + 4.0, by + bh + 12.0))               # the tail
			bub.append(Vector2(bx + 10.0, by + bh))
			bub.append(Vector2(bx + 6.0, by + bh))
			bub.append_array(_quad(Vector2(bx + 6.0, by + bh), Vector2(bx, by + bh), Vector2(bx, by + bh - 6.0), 3))
			bub.append(Vector2(bx, by + 6.0))
			bub.append_array(_quad(Vector2(bx, by + 6.0), Vector2(bx, by), Vector2(bx + 6.0, by), 3))
			n.draw_colored_polygon(PackedVector2Array(bub), _al(Kit.INK, 0.95))
			var fs := maxi(10, roundi(H / 15.0))
			var rows := _wrap_words(line_s.substr(0, shown), maxi(6, floori((bw - 16.0) / (fs * 0.55))))
			for i in rows.size():
				Kit.text(n, rows[i], Vector2(bx + 8.0, by + fs + 4.0 + i * (fs + 3.0)), fs, INK_DARK)
			if shown < line_s.length() and floori(t * 4.0) % 2 == 0:  # the caret
				var last_len: int = (rows[rows.size() - 1] as String).length() if rows.size() > 0 else 0
				var last_row: int = rows.size() - 1 if rows.size() > 0 else 0
				n.draw_rect(Rect2(bx + 8.0 + last_len * fs * 0.55, by + 6.0 + last_row * (fs + 3.0), 2.0, fs), INK_DARK)
			# the pitch strip: one bar per blip, vowels violet, consonants bone
			var sx := W * 0.3
			var sy := H * 0.86
			var sw := W * 0.62
			var sh := H * 0.2
			n.draw_line(Vector2(sx, sy), Vector2(sx + sw, sy), Kit.DIM, 1.0)
			Kit.label(n, b, "base %d Hz" % int(D.base), Vector2(sx, sy + 12.0), Kit.DIM)
			_label_r(n, b, "+%d%%" % roundi(float(D.range) * 100.0), Vector2(sx + sw, sy - sh - 2.0), Kit.DIM)
			var bwid := sw / 28.0
			var strip: Array = b.strip
			for i in strip.size():
				var sb: Dictionary = strip[i]
				var hgt := 4.0 + float(sb.k) * (sh - 4.0)
				n.draw_rect(Rect2(sx + i * bwid + 1.0, sy - hgt, maxf(1.0, bwid - 2.0), hgt), Kit.MAGIC if sb.vowel else Kit.BONE)
			if _is_letter(cur):
				var f := roundi(float(D.base) * (1.0 + _pitch_of(cur) * float(D.range)))
				var vow := _is_vowel(cur)
				Kit.text(n, "%s → %d Hz %s" % [cur, f, "sine" if vow else "square"], Vector2(W * 0.16, H * 0.12), 11, Kit.MAGIC if vow else Kit.BONE, true)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"envelopes":
			Kit.stage(n, b, 0.0, true)
			var recipes: Array = D.recipes
			var play_i: int = b.play_i
			var play_t0: float = b.play_t0
			var stretch: float = D.stretch
			var colours: Array = [Kit.FIRE, Kit.GOOD, Kit.HOT, Kit.SUN, Kit.WATER, Kit.MAGIC]
			var gw := (W - 12.0) / 3.0
			var gh := (H - 40.0) / 2.0
			for i in recipes.size():
				var r: Dictionary = recipes[i]
				var px := 6.0 + (i % 3) * gw + 3.0
				var py := 20.0 + floori(i / 3.0) * gh + 3.0
				var pw := gw - 6.0
				var ph := gh - 6.0
				var on := play_i == i
				var col: Color = colours[i % colours.size()]
				_panel(n, Rect2(px, py, pw, ph), _al(Kit.INK, 0.1) if on else PANEL55, col if on else FRAME, 1.5 if on else 1.0)
				Kit.text(n, r.name, Vector2(px + 4.0, py + 11.0), 10, col)
				var wave: String = "noise" if r.kind == "noise" else (str(r.get("wave", "square")) if D.wave == "auto" else str(D.wave))
				var total := _env_len(r, stretch)
				var ay := py + 16.0
				var ah := ph - 22.0
				var nn := 24
				# the gain envelope, filled (lifted a hair off the base so the polygon stays simple)
				var gp := PackedVector2Array([Vector2(px + 4.0, ay + ah)])
				for k in nn + 1:
					var tau := total * k / float(nn)
					var g: float
					if r.kind == "arp":
						var stp := float(r.step) * stretch
						var inn := fmod(tau, stp)
						var idx := floori(tau / stp)
						g = _gain_at(r, inn, float(r.dur) * stretch, stretch) if idx < (r.notes as Array).size() else 0.0
					else:
						g = _gain_at(r, tau, total, stretch)
					gp.append(Vector2(px + 4.0 + (pw - 8.0) * k / float(nn), ay + ah - ah * maxf(0.002, clampf(g, 0.0, 1.0))))
				gp.append(Vector2(px + pw - 4.0, ay + ah))
				n.draw_colored_polygon(gp, Color(0.788, 0.769, 0.894, 0.18))
				# the pitch (or cutoff) curve, exponential between f0 and f1
				if r.kind == "arp":
					var notes: Array = r.notes
					for k in notes.size():
						var x0 := px + 4.0 + (pw - 8.0) * (k * float(r.step) * stretch) / total
						var x1 := px + 4.0 + (pw - 8.0) * ((k * float(r.step) + float(r.dur)) * stretch) / total
						var yk := _fy(D, float(notes[k]), ay, ah)
						n.draw_line(Vector2(x0, yk), Vector2(minf(x1, px + pw - 4.0), yk), col, 1.5)
				else:
					var f0: float = float(r.lowpass) if r.kind == "noise" else float(r.f0)
					var f1: float = float(r.sweepTo) if r.kind == "noise" else float(r.f1)
					var pc := PackedVector2Array()
					for k in nn + 1:
						var f := f0 * pow(f1 / f0, k / float(nn))
						pc.append(Vector2(px + 4.0 + (pw - 8.0) * k / float(nn), _fy(D, f, ay, ah)))
					n.draw_polyline(pc, col, 1.5)
				Kit.label(n, b, wave, Vector2(px + 4.0, py + ph - 3.0), Kit.DIM)
				_label_r(n, b, "%d ms" % roundi(total * 1000.0), Vector2(px + pw - 4.0, py + ph - 3.0), Kit.DIM)
				if on:                                       # the playhead
					var k := clampf((t - play_t0) / total, 0.0, 1.0)
					var xx := px + 4.0 + (pw - 8.0) * k
					n.draw_line(Vector2(xx, ay), Vector2(xx, ay + ah), _al(Kit.INK, 0.8), 1.0)
					var gk := 1.0 if r.kind == "arp" else clampf(_gain_at(r, k * total, total, stretch), 0.0, 1.0)
					Kit.dot(n, Vector2(xx, ay + ah - ah * gk), 2.5, col)
			Kit.label(n, b, "wave %s · stretch ×%s" % [D.wave, str(stretch)], Vector2(W / 2.0, 13.0), FAINT, true)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"engine":
			Kit.stage(n, b, 0.2)
			var speed: float = b.speed
			var throttle: float = b.throttle
			var manual_t: float = b.manualT
			var g: float = b.g
			var rpm: float = b.rpm
			# the road scrolls under a fixed car
			var ry := GY - H * 0.04
			n.draw_rect(Rect2(0.0, ry - 6.0, W, 12.0), Color(0.176, 0.157, 0.275, 0.95))
			_dash(n, Vector2(0.0, ry), Vector2(W, ry), 16.0, 24.0, _al(Kit.INK, 0.3), 1.0, b.road)
			var cx := W * 0.42
			var cw := W * 0.16
			var ch := H * 0.07
			var tilt := (throttle - speed) * 0.08           # the nose lifts under throttle, dips under brake
			var wheel: float = b.wheel
			n.draw_set_transform(origin + Vector2(cx, ry - 3.0), -tilt, Vector2.ONE)
			n.draw_rect(Rect2(-cw / 2.0, -ch, cw, ch), Kit.HOT)
			n.draw_rect(Rect2(-cw * 0.28, -ch * 1.75, cw * 0.5, ch * 0.75), INK_DARK)
			for wside in [-1.0, 1.0]:
				var wx: float = wside * cw * 0.32
				Kit.dot(n, Vector2(wx, 2.0), ch * 0.34, INK_DARK)
				Kit.dot(n, Vector2(wx, 2.0), ch * 0.16, Kit.BONE)
				n.draw_line(Vector2(wx, 2.0), Vector2(wx + cos(wheel) * ch * 0.3, 2.0 + sin(wheel) * ch * 0.3), INK_DARK, 1.5)
			n.draw_set_transform(origin, 0.0, Vector2.ONE)
			if throttle > speed + 0.05:
				for k in 3:
					var a := fposmod(float(b.exhaust) + k * 0.33, 1.0)
					Kit.dot(n, Vector2(cx - cw / 2.0 - 4.0 - a * 18.0, ry - 4.0 - a * 6.0 + sin(a * 9.0) * 2.0), 1.5 + a * 3.0, _al(Kit.BONE, 0.4 * (1.0 - a)))
			# the rpm gauge: an arc, a redline, a needle
			var gx := W - H * 0.22 - 6.0
			var gy := H * 0.3
			var gr := H * 0.19
			_sector(n, Vector2(gx, gy), gr + 6.0, PI * 0.75, PI * 2.25, PANEL)
			n.draw_arc(Vector2(gx, gy), gr, PI * 0.75, PI * 2.05, 32, Kit.BONE, 2.0)
			n.draw_arc(Vector2(gx, gy), gr, PI * 2.05, PI * 2.25, 8, Kit.HOT, 2.0)
			for k in 8:
				var a := PI * 0.75 + PI * 1.5 * k / 7.0
				n.draw_line(Vector2(gx + cos(a) * (gr - 4.0), gy + sin(a) * (gr - 4.0)), Vector2(gx + cos(a) * gr, gy + sin(a) * gr), Kit.BONE, 1.0)
			var na := PI * 0.75 + PI * 1.5 * clampf(rpm / 8000.0, 0.0, 1.0)
			n.draw_line(Vector2(gx, gy), Vector2(gx + cos(na) * (gr - 2.0), gy + sin(na) * (gr - 2.0)), Kit.SUN, 2.0)
			Kit.dot(n, Vector2(gx, gy), 3.0, Kit.SUN)
			Kit.label(n, b, "%d rpm" % roundi(rpm), Vector2(gx, gy + gr + 4.0), Kit.BONE, true)
			# the two lines through the engine: pitch and gain against speed
			var px := 8.0
			var py := 8.0
			var pw := W * 0.36
			var ph := H * 0.3
			_panel(n, Rect2(px, py, pw, ph), PANEL, FRAME)
			_label_r(n, b, "speed →", Vector2(px + pw - 4.0, py + ph - 3.0), Kit.DIM)
			n.draw_line(Vector2(px + 4.0, py + ph - 4.0), Vector2(px + pw - 4.0, py + 6.0), Kit.SUN, 1.5)   # pitch: a straight line
			n.draw_line(Vector2(px + 4.0, py + ph - 4.0 - (ph - 10.0) * float(D.idleVol) / 0.25),
				Vector2(px + pw - 4.0, py + ph - 4.0 - (ph - 10.0) * float(D.vol) / 0.25), Kit.WATER, 1.5)  # gain: another
			var sx := px + 4.0 + (pw - 8.0) * speed
			n.draw_line(Vector2(sx, py + 4.0), Vector2(sx, py + ph - 4.0), _al(Kit.INK, 0.4), 1.0)
			Kit.dot(n, Vector2(sx, py + ph - 4.0 - (ph - 10.0) * speed), 3.0, Kit.SUN)
			Kit.dot(n, Vector2(sx, py + ph - 4.0 - (ph - 10.0) * g / 0.25), 3.0, Kit.WATER)
			Kit.label(n, b, "%d Hz" % roundi(float(b.f)), Vector2(px + 4.0, py + 11.0), Kit.SUN)
			Kit.label(n, b, "gain %.2f" % g, Vector2(px + 4.0, py + 21.0), Kit.WATER)
			# the throttle bar
			var tx := 8.0
			var ty := H * 0.46
			var tw := W * 0.36
			n.draw_rect(Rect2(tx, ty, tw, 8.0), TRACK)
			n.draw_rect(Rect2(tx, ty, tw * throttle, 8.0), Kit.HOT if manual_t > 0.0 else Kit.BONE)
			n.draw_rect(Rect2(tx + tw * speed - 1.0, ty - 2.0, 2.0, 12.0), Kit.INK)
			Kit.label(n, b, "throttle %.2f%s · speed %.2f" % [throttle, " (yours)" if manual_t > 0.0 else " (auto)", speed], Vector2(tx, ty + 20.0), Kit.DIM)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"noisebed":
			Kit.stage(n, b, 0.0, true)
			var order: Array = D.order
			var beds: Dictionary = D.beds
			var idx: int = b.idx
			var nm: String = order[idx]
			var has2: bool = D.second != ""
			var ph := (H - 34.0) / 2.0 if has2 else H - 34.0
			_bed_panel(n, b, D, nm, beds[nm], Rect2(6.0, 18.0, W - 12.0, ph - 4.0), t, true)
			if has2:
				_bed_panel(n, b, D, D.second, beds[D.second], Rect2(6.0, 18.0 + ph, W - 12.0, ph - 4.0), t, false)
			# a strip of names: which bed is on, and the countdown to the next
			for i in order.size():
				var x := W * 0.5 + (i - (order.size() - 1) / 2.0) * 44.0
				var bc := _bed_colour(order[i])
				Kit.label(n, b, order[i], Vector2(x, 12.0), bc if i == idx else Kit.DIM, true)
				if i == idx:
					n.draw_rect(Rect2(x - 18.0, 14.0, 36.0 * clampf(1.0 - float(b.clock) / float(D.every), 0.0, 1.0), 1.5), bc)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"quiet":
			var hx: float = b.hx
			var hy: float = b.hy
			var m: float = b.m
			var cut: float = b.cut
			if D.mode == "door":
				Kit.stage(n, b, 0.35)
				var tx: float = b.tx
				var door_x := W * 0.5
				Kit.wall(n, Rect2(door_x - 3.0, GY - H * 0.42, 6.0, H * 0.42))
				n.draw_rect(Rect2(door_x - 3.0, GY - H * 0.2, 6.0, H * 0.2), WOOD)
				Kit.dot(n, Vector2(door_x + 1.5, GY - H * 0.1), 1.2, Kit.SUN)
				Kit.hero(n, b, Vector2(hx, GY), { "face": 1 if tx > hx else -1, "pose": "run" if absf(tx - hx) > 2.0 else "stand", "frame": t })
				Kit.dot(n, Vector2(W * 0.12, GY - H * 0.14), 4.0, Kit.BONE)
				Kit.label(n, b, "listener", Vector2(W * 0.12, GY + 12.0), Kit.DIM, true)
				_dash(n, Vector2(W * 0.12, GY - H * 0.14), Vector2(hx, GY - H * 0.14), 3.0, 4.0, Kit.DIM)
				var where := ("behind the door · %d%% of range" % roundi(float(b.behind) * 100.0)) if hx > door_x else "same room"
				Kit.label(n, b, where, Vector2((W * 0.12 + hx) / 2.0, GY - H * 0.16), Kit.DIM, true)
			else:
				Kit.stage(n, b, 0.15)
				var under: bool = b.under
				var px := W * 0.4
				n.draw_rect(Rect2(px, GY, W - px, H - GY), Kit.WATER)
				n.draw_rect(Rect2(px - 4.0, GY - 4.0, 4.0, H - GY + 4.0), WOOD)
				Kit.hero(n, b, Vector2(hx, hy), { "face": 1, "pose": "jump" if under else "stand", "frame": t })
				n.draw_rect(Rect2(px, GY, W - px, H - GY), _al(Kit.WATER, 0.45))   # the water over the hero
				if hy > GY:
					for k in 6:
						var a := fposmod(t * 0.4 + k * 0.17, 1.0)
						Kit.dot(n, Vector2(hx + sin(k * 5.0 + t) * 6.0, hy - H * 0.16 - a * (hy - GY + H * 0.16)), 1.0 + (k % 2), _al(Kit.INK, 0.5 * (1.0 - a)))
				n.draw_line(Vector2(px, GY), Vector2(W, GY), _al(Kit.INK, 0.6), 1.5)
				Kit.label(n, b, "under water" if under else "on the pier", Vector2(hx, H - 20.0), Kit.DIM, true)
			if m > 0.02:                                     # the screen goes distant too
				n.draw_rect(Rect2(0.0, 0.0, W, H), Color(0.118, 0.235, 0.431, 0.35 * m))
			# the spectrum: the world's bars (the card's own shape, wobbled), filtered by |H(f)|, and the cutoff line
			var bars: int = D.bars
			var shape: Array = b.shape
			var sx := 8.0
			var sy := 8.0
			var sw := W * 0.55
			var sh := H * 0.32
			var bw := sw / bars
			_panel(n, Rect2(sx, sy, sw, sh), PANEL, FRAME)
			for i in bars:
				var f := _f_of(D, i)
				var h0 := float(shape[i % 32]) * (0.75 + 0.25 * Kit.noise(i * 0.7 + t * 4.0))
				var hf := 1.0 / sqrt(1.0 + pow(f / cut, 4.0))
				var x := sx + i * bw + 1.0
				n.draw_rect(Rect2(x, sy + sh - 2.0 - (sh - 14.0) * h0, bw - 2.0, (sh - 14.0) * h0), Color(0.788, 0.769, 0.894, 0.12))
				n.draw_rect(Rect2(x, sy + sh - 2.0 - (sh - 14.0) * h0 * hf, bw - 2.0, (sh - 14.0) * h0 * hf), _al(Kit.WATER, 0.7) if f > cut else Kit.SUN)
			var cxl := sx + sw * clampf(log(cut / 40.0) / log(400.0), 0.0, 1.0)
			n.draw_line(Vector2(cxl, sy + 2.0), Vector2(cxl, sy + sh - 2.0), Kit.HOT, 1.5)
			if cxl > sx + sw * 0.6:
				_label_r(n, b, "%d Hz" % roundi(cut), Vector2(cxl - 3.0, sy + 11.0), Kit.HOT)
			else:
				Kit.label(n, b, "%d Hz" % roundi(cut), Vector2(cxl + 3.0, sy + 11.0), Kit.HOT)
			Kit.label(n, b, "m %.2f" % m, Vector2(sx + 4.0, sy + sh - 4.0), Kit.DIM)
			Kit.label(n, b, "40", Vector2(sx + 2.0, sy + sh + 10.0), Kit.DIM)
			_label_r(n, b, "16k", Vector2(sx + sw, sy + sh + 10.0), Kit.DIM)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"yodel":
			Kit.stage(n, b, 0.3)
			var cx := W * float(D.caveX)
			# the cave: a dark arch over the right of the stage
			var arch: Array = [Vector2(cx, GY)]
			arch.append_array(_quad(Vector2(cx, GY), Vector2(cx + W * 0.02, H * 0.2), Vector2(cx + W * 0.2, H * 0.18), 8))
			arch.append(Vector2(W, H * 0.16))
			arch.append(Vector2(W, GY))
			n.draw_colored_polygon(PackedVector2Array(arch), CAVE)
			var inner: Array = [Vector2(cx + 8.0, GY)]
			inner.append_array(_quad(Vector2(cx + 8.0, GY), Vector2(cx + W * 0.06, H * 0.3), Vector2(cx + W * 0.22, H * 0.28), 8))
			inner.append(Vector2(W, H * 0.27))
			inner.append(Vector2(W, GY))
			n.draw_colored_polygon(PackedVector2Array(inner), Kit.NIGHT)
			Kit.tree(n, Vector2(W * 0.08, GY), H * 0.3)
			var hx: float = b.hx
			var dir: float = b.dir
			var mix: float = b.mix
			var depth: float = b.depth
			Kit.hero(n, b, Vector2(hx, GY), { "face": int(dir), "pose": "run", "frame": t })
			for e in b.fired:                                # each echo: a ghost of the shouter, deeper in, fading
				var ev: Dictionary = e
				var age := t - float(ev.t0)
				var life := 0.7
				if age > life:
					continue
				var a := float(ev.g) * (1.0 - age / life)
				var k: int = ev.k
				if k == 0:
					Kit.ring(n, Vector2(ev.x, GY - H * 0.22), 4.0 + age * 40.0, _al(Kit.SUN, a * 0.8), 1.5)
					Kit.text(n, "hey!", Vector2(ev.x, GY - H * 0.3 - age * 10.0), 11, Kit.SUN, true)
					continue
				var gx := clampf(cx + W * 0.085 * k, 0.0, W - 10.0)
				Kit.hero(n, b, Vector2(gx, GY), { "face": -1, "pose": "stand", "alpha": a * 0.8, "tint": _al(Kit.MAGIC, 0.6), "frame": 0.0 })
				Kit.label(n, b, "×%.2f" % float(ev.g), Vector2(gx, GY - H * 0.3 - (k % 2) * 11.0), _al(Kit.MAGIC, a), true)
				Kit.ring(n, Vector2(gx, GY - H * 0.22), 4.0 + age * 30.0, _al(Kit.MAGIC, a * 0.6), 1.0)
			# the delay line: a loop with a write head, the feedback path, and the mix
			var bx := 8.0
			var by := 8.0
			var bw := W * 0.5
			var bh := 12.0
			var delay: float = D.delay
			_panel(n, Rect2(bx, by, bw, bh), PANEL, Kit.BONE)
			var head := fposmod(t / delay, 1.0)
			n.draw_rect(Rect2(bx + bw * head - 1.0, by - 2.0, 2.0, bh + 4.0), Kit.SUN)
			for e in b.pending:
				var ev: Dictionary = e
				var frac := clampf(1.0 - (float(ev.at) - t) / delay, 0.0, 1.0)
				if float(ev.at) - t <= delay:
					Kit.dot(n, Vector2(bx + bw * fposmod(head + 1.0 - frac + 1.0, 1.0), by + bh / 2.0), 2.5, Kit.MAGIC)
			Kit.label(n, b, "delay %s s" % str(delay), Vector2(bx, by + bh + 11.0), Kit.DIM)
			n.draw_polyline(PackedVector2Array([Vector2(bx + bw, by + bh / 2.0), Vector2(bx + bw + 8.0, by + bh / 2.0), Vector2(bx + bw + 8.0, by + bh + 18.0),
				Vector2(bx - 6.0, by + bh + 18.0), Vector2(bx - 6.0, by + bh / 2.0), Vector2(bx, by + bh / 2.0)]), Kit.MAGIC, 1.0)
			Kit.label(n, b, "fb %s" % str(D.feedback), Vector2(bx + bw + 12.0, by + bh + 21.0), Kit.MAGIC)
			var mxp := W * 0.62
			var mw := W * 0.3
			n.draw_rect(Rect2(mxp, by + 2.0, mw, 8.0), TRACK)
			n.draw_rect(Rect2(mxp, by + 2.0, mw * mix, 8.0), Kit.MAGIC)
			Kit.label(n, b, "mix %.2f%s" % [mix, " · cave" if depth > 0.5 else " · open"], Vector2(mxp, by + 21.0), Kit.DIM)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"jukebox":
			Kit.stage(n, b, 0.0, true)
			var layers: Array = b.layers
			var gains: Array = b.gains
			var flashes: Array = b.flashes
			var pats: Dictionary = D.patterns
			var thr: Array = D.thresholds
			var stp: int = b.step
			var steps: int = D.steps
			var intensity: float = b.intensity
			var stinger: float = b.stinger
			var colours: Array = [Kit.HOT, Kit.WATER, Kit.MAGIC]
			# the lanes: one row per layer, a cell per step, lit by the pattern and dimmed by the gain
			var lx := W * 0.24
			var lw := W * 0.5
			var ly0 := 24.0
			var lh := (H * 0.52) / 3.0
			var cw := lw / steps
			for i in 3:
				var y := ly0 + i * lh
				var pat: Array = pats[layers[i]]
				var col: Color = colours[i]
				var gi: float = gains[i]
				_text_r(n, layers[i], Vector2(lx - 6.0, y + lh * 0.55), 10, col)
				for s_i in steps:
					var hit: int = pat[s_i % pat.size()]
					var x := lx + s_i * cw
					var cell := Rect2(x + 1.0, y + 3.0, cw - 2.0, lh - 6.0)
					n.draw_rect(cell, PANEL)
					if hit != 0:
						n.draw_rect(cell, _al(col, 0.15 + 0.75 * gi * (0.6 if hit == 2 else 1.0)))
					if s_i == stp:
						var lit: bool = float(flashes[i]) > 0.0 and hit != 0
						n.draw_rect(cell, Kit.INK if lit else _al(Kit.INK, 0.5), false, 2.0 if lit else 1.0)
				var mx := lx + lw + 10.0                     # the gain meter
				var mw := W * 0.16
				n.draw_rect(Rect2(mx, y + lh * 0.35, mw, lh * 0.3), TRACK)
				n.draw_rect(Rect2(mx, y + lh * 0.35, mw * gi, lh * 0.3), col)
				Kit.label(n, b, "%.2f" % gi, Vector2(mx + mw + 3.0, y + lh * 0.62), Kit.DIM)
			var px := lx + (stp + clampf(float(b.stepT) / _step_dur(D), 0.0, 1.0)) * cw   # the playhead
			n.draw_line(Vector2(px, ly0), Vector2(px, ly0 + lh * 3.0), _al(Kit.INK, 0.7), 1.0)
			# the intensity slider with the three thresholds
			var sx := 14.0
			var sy := ly0
			var sh := lh * 3.0
			n.draw_rect(Rect2(sx, sy, 8.0, sh), TRACK)
			n.draw_rect(Rect2(sx, sy + sh * (1.0 - intensity), 8.0, sh * intensity), Kit.SUN)
			for i in 3:
				var ty := sy + sh * (1.0 - float(thr[i]))
				n.draw_line(Vector2(sx - 3.0, ty), Vector2(sx + 11.0, ty), colours[i], 1.0)
			n.draw_rect(Rect2(sx - 2.0, sy + sh * (1.0 - float(b.target)) - 1.0, 12.0, 2.0), Kit.INK)
			Kit.label(n, b, "I %.2f" % intensity, Vector2(sx + 14.0, sy + sh * (1.0 - intensity) + 4.0), Kit.DIM)
			# the bar counter, the section and the pending switch, the stinger
			var sec: int = b.section
			var pend: bool = b.pendingSection
			Kit.text(n, "bar %d · step %d/%d" % [int(b.bar), stp + 1, steps], Vector2(W * 0.24, 14.0), 11, Kit.BONE)
			var sec_txt := "section %s" % ("B" if sec == 1 else "A")
			if pend:
				sec_txt += " → %s on the bar" % ("A" if sec == 1 else "B")
			_text_r(n, sec_txt, Vector2(W - 8.0, 14.0), 10, Kit.SUN if pend else Kit.DIM)
			if stinger > 0.0:
				n.draw_rect(Rect2(0.0, 0.0, W, H), _al(Kit.SUN, stinger * 0.12))
				Kit.text(n, "stinger", Vector2(W / 2.0, H * 0.86), int(12.0 + stinger * 4.0), Kit.SUN, true)
			Kit.label(n, b, "%d bpm · fade %s/s · %s" % [int(D.tempo), str(D.fade), "autopilot" if float(b.idle) > 6.0 else "yours"], Vector2(W * 0.24, H - 22.0), Kit.DIM)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"lookahead":
			Kit.stage(n, b, 0.0, true)
			var running: bool = b.running
			var queue: Array = b.queue
			var p := 60.0 / float(D.bpm)
			var window: float = D.window
			var look: float = D.lookahead
			var ms_span: float = D.msSpan
			# two rows: a time ruler with ideal beats, the fired beats, and each one's error as a bar
			var x0 := 10.0
			var x1 := W - 10.0
			var tw := x1 - x0
			var now_x := x0 + tw * 0.78
			var titles: Array = ["frame-timed", "scheduled · lookahead %d ms" % roundi(look * 1000.0)]
			var lists: Array = [b.beatsF, b.beatsS]
			var cols: Array = [Kit.HOT, Kit.GOOD]
			for r in 2:
				var y := 22.0 + r * (H * 0.42)
				var col: Color = cols[r]
				var beats: Array = lists[r]
				Kit.text(n, titles[r], Vector2(x0, y), 10, col)
				var ry := y + 6.0
				var rh := H * 0.085
				n.draw_rect(Rect2(x0, ry, tw, rh), PANEL)
				for k in range(-20, 5):                      # the ideal grid
					var tb := floorf(t / p) * p + k * p
					var xx := now_x - (t - tb) / window * tw * 0.78
					if xx >= x0 and xx <= x1:
						n.draw_line(Vector2(xx, ry), Vector2(xx, ry + rh), Color(0.788, 0.769, 0.894, 0.18), 1.0)
				n.draw_line(Vector2(now_x, ry - 3.0), Vector2(now_x, ry + rh + 3.0), Kit.INK, 1.0)
				Kit.label(n, b, "now", Vector2(now_x + 3.0, ry - 2.0), Kit.DIM)
				if r == 1:                                   # the lookahead window and the booked notes inside it
					var wx := now_x + look / window * tw * 0.78
					n.draw_rect(Rect2(now_x, ry, minf(wx, x1) - now_x, rh), _al(Kit.GOOD, 0.15))
					for q in queue:
						var xx := now_x - (t - float((q as Dictionary).due)) / window * tw * 0.78
						if xx <= x1:
							Kit.ring(n, Vector2(xx, ry + rh / 2.0), 3.0, col, 1.5)
				for bt in beats:
					Kit.dot(n, Vector2(now_x - (t - float((bt as Dictionary).t)) / window * tw * 0.78, ry + rh / 2.0), 3.0, col)
				# the error bars below: last 16 beats, ms
				var ey := ry + rh + 5.0
				var eh := H * 0.1
				var nn := mini(16, beats.size())
				var ew := (tw - 34.0) / 16.0
				var ex0 := x0 + 34.0
				n.draw_line(Vector2(ex0, ey + eh), Vector2(x1, ey + eh), FRAME, 1.0)
				var mean := 0.0
				for k in nn:
					var bt: Dictionary = beats[beats.size() - nn + k]
					var hgt := clampf(float(bt.err) * 1000.0 / ms_span, 0.0, 1.0) * eh
					n.draw_rect(Rect2(ex0 + k * ew + 1.0, ey + eh - hgt, ew - 2.0, hgt), col)
				for bt in beats:
					mean += float((bt as Dictionary).err)
				mean = mean / beats.size() if beats.size() > 0 else 0.0
				var err_txt := ("error: mean %.1f ms · max %.0f ms" % [mean * 1000.0, float(b.maxF) * 1000.0]) if r == 0 else ("error: 0 ms (booked %d ms early) · %d in the window" % [roundi(look * 1000.0), queue.size()])
				Kit.label(n, b, err_txt, Vector2(x0, ey + eh + 11.0), Kit.DIM)
				_label_r(n, b, "0", Vector2(ex0 - 3.0, ey + eh + 3.0), Kit.DIM)
				_label_r(n, b, "%d ms" % roundi(ms_span), Vector2(ex0 - 3.0, ey + 7.0), Kit.DIM)
			var status := ("running · %d bpm" % int(D.bpm)) if running else "stopped"
			if not running and queue.size() > 0:
				status += " — %d booked note%s still due" % [queue.size(), "s" if queue.size() > 1 else ""]
			_text_r(n, status, Vector2(W - 8.0, 14.0), 10, Kit.SUN if running else Kit.HOT)
			# the kit's synth has no clock of its own: the card's t stands in once sound is armed
			Kit.label(n, b, ("audio clock %.2f s" % t) if b.armed_sound else "audio clock: none here (silent)", Vector2(x0, 14.0), Kit.DIM)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"quota":
			Kit.stage(n, b, 0.0, true)
			var slots: Array = b.slots
			var nslots := maxi(1, int(D.slots))
			var cap: int = D.cap
			# the slots: one box per player, its level bar decaying, red when it was just stolen
			var sw := minf(W * 0.14, (W - 24.0) / nslots)
			var sx0 := (W - sw * nslots) / 2.0
			var sy := H * 0.24
			var sh := H * 0.3
			var cc := 0
			var hc := 0
			for i in nslots:
				var x := sx0 + i * sw
				var v: Variant = slots[i]
				var box := Rect2(x + 2.0, sy, sw - 4.0, sh)
				n.draw_rect(box, PANEL)
				var vd: Dictionary = v if v != null else {}
				var fl: float = float(vd.flash) if v != null else 0.0
				n.draw_rect(box, _al(Kit.HOT, fl) if fl > 0.0 else FRAME, false, 2.0 if fl > 0.0 else 1.0)
				Kit.label(n, b, str(i + 1), Vector2(x + sw / 2.0, sy + sh + 11.0), Kit.DIM, true)
				if v == null:
					continue
				var vcol := Kit.SUN if vd.name == "coin" else Kit.WATER
				if vd.name == "coin":
					cc += 1
				else:
					hc += 1
				var lv := _q_level(D, vd, t)
				n.draw_rect(Rect2(x + 5.0, sy + sh - 3.0 - (sh - 16.0) * lv, sw - 10.0, (sh - 16.0) * lv), vcol)
				Kit.label(n, b, vd.name, Vector2(x + sw / 2.0, sy + 11.0), vcol, true)
				if fl > 0.0:
					Kit.text(n, "stolen", Vector2(x + sw / 2.0, sy - 4.0), 9, Kit.HOT, true)
			# the counts per sound against the cap
			Kit.text(n, "coin %d/%d" % [cc, cap], Vector2(W * 0.3, 16.0), 11, Kit.SUN, true)
			Kit.text(n, "hit %d/%d" % [hc, cap], Vector2(W * 0.7, 16.0), 11, Kit.WATER, true)
			Kit.label(n, b, "pool %d/%d · steal %s" % [cc + hc, int(D.slots), D.steal], Vector2(W / 2.0, 30.0), Kit.DIM, true)
			# the request stream: a tick per request over the last 3 s, red for steals, hollow for refusals
			var ly := H * 0.72
			var lx0 := 12.0
			var lw := W - 24.0
			n.draw_line(Vector2(lx0, ly), Vector2(lx0 + lw, ly), FRAME, 1.0)
			for e in b.reqlog:
				var ev: Dictionary = e
				var age := t - float(ev.t)
				if age > 3.0:
					continue
				var x := lx0 + lw * (1.0 - age / 3.0)
				if ev.kind == "refused":
					Kit.ring(n, Vector2(x, ly), 3.0, Kit.HOT, 1.0)
				else:
					var stole: bool = ev.kind == "stole"
					Kit.dot(n, Vector2(x, ly), 3.0 if stole else 2.0, Kit.HOT if stole else (Kit.SUN if ev.name == "coin" else Kit.WATER))
			var burst_left: int = b.burstLeft
			var counts := "requests %d · steals %d · refused %d" % [int(b.requests), int(b.steals), int(b.refused)]
			if burst_left > 0:
				counts += " · burst: %d to go" % burst_left
			Kit.label(n, b, counts, Vector2(lx0, ly + 14.0), Kit.DIM)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"analyser":
			var bass: float = b.bass
			var hb: Array = b.hbins
			var playing: bool = b.playing
			var bars: int = D.bars
			var sc := 1.0 + bass * float(D.pulse)
			var centre := Vector2(W / 2.0, H / 2.0)
			# the scene, scaled about its centre by the bass: the camera pulse
			n.draw_set_transform(origin + centre - centre * sc, 0.0, Vector2(sc, sc))
			Kit.stage(n, b, 0.0, true)
			var hx := W / 2.0
			var hy := GY
			# the web draws this glow "lighter" (additive); Godot 2D has no per-draw
			# additive blend without a material, so it is a plain alpha glow here
			Kit.glow(n, Vector2(hx, hy - H * 0.14), H * (0.1 + float(D.glowR) * bass), Kit.MAGIC, 0.5)
			if D.shape == "ring":                            # a smooth waveform ring: the bins mirrored round a circle
				var r0 := H * 0.2
				var amp := H * 0.16
				var pts := PackedVector2Array()
				for k in bars * 2 + 1:
					var i := k if k < bars else bars * 2 - k
					var a := -PI / 2.0 + TAU * k / float(bars * 2)
					var idx := mini(31, i * 2)
					var v := (float(hb[idx]) + float(hb[mini(31, idx + 1)])) / 2.0
					var rr := r0 + amp * v
					pts.append(Vector2(hx + cos(a) * rr, hy - H * 0.14 + sin(a) * rr))
				n.draw_polyline(pts, Kit.SUN, 2.0)
				n.draw_arc(Vector2(hx, hy - H * 0.14), r0, 0.0, TAU, 48, _al(Kit.SUN, 0.25), 1.0)
			else:
				var bw := (W - 20.0) / bars
				var base := H * 0.86
				var max_h := H * 0.5
				for i in bars:
					var idx := mini(31, floori(i * 32.0 / bars))
					var v := (float(hb[idx]) + float(hb[mini(31, idx + 1)])) / 2.0
					var x := 10.0 + i * bw
					var hh := maxf(1.0, max_h * v)
					n.draw_rect(Rect2(x + 1.0, base - hh, bw - 2.0, hh), Kit.HOT if i < 4 else (Kit.SUN if i < 10 else Kit.WATER))
					n.draw_rect(Rect2(x + 1.0, base - hh - 2.0, bw - 2.0, 1.5), Kit.INK)   # the peak cap
				n.draw_line(Vector2(10.0, base), Vector2(W - 10.0, base), Color(0.788, 0.769, 0.894, 0.4), 1.0)
			# the hero sets its own transform, so it takes the pulse as a scaled position and unit
			Kit.hero(n, b, centre + (Vector2(hx, hy) - centre) * sc, { "s": Kit.hero_unit(b) * sc, "pose": "run", "frame": t * (1.0 if playing else 0.2), "face": 1 })
			n.draw_set_transform(origin, 0.0, Vector2.ONE)
			# the readouts
			Kit.text(n, ("playing · %d bpm" % int(D.bpm)) if playing else "stopped", Vector2(8.0, 14.0), 10, Kit.SUN if playing else Kit.HOT)
			_label_r(n, b, "beat clock (no analyser in the kit)", Vector2(W - 8.0, 14.0), Kit.DIM)
			var mx := 8.0
			var my := 22.0
			var mw := W * 0.3
			n.draw_rect(Rect2(mx, my, mw, 6.0), TRACK)
			n.draw_rect(Rect2(mx, my, mw * clampf(bass, 0.0, 1.0), 6.0), Kit.HOT)
			Kit.label(n, b, "bass %.2f → scale ×%.3f" % [bass, sc], Vector2(mx, my + 16.0), Kit.DIM)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
		"rumble":
			var shake: Vector2 = b.shake
			var hx: float = b.hx
			var hy: float = b.hy
			var hit_t: float = b.hitT
			var lo: float = b.lo
			var hi: float = b.hi
			var inten: float = b.inten
			# chapter 06's screen shake is the third motor: the scene shifts by the envelope
			n.draw_set_transform(origin + shake, 0.0, Vector2.ONE)
			Kit.stage(n, b, 0.25)
			if hit_t < 0.3:
				var prx := W * 0.9 - (hit_t / 0.3) * (W * 0.6 - 10.0)
				if prx > hx + 8.0:
					Kit.dot(n, Vector2(prx, GY - H * 0.16), 3.0, Kit.HOT)
			var pose := "hurt" if float(b.hurt) > 0.0 else ("jump" if hy < GY else "run")
			Kit.hero(n, b, Vector2(hx, hy) + shake, { "pose": pose, "frame": t, "face": 1 })   # (the hero sets its own transform)
			n.draw_set_transform(origin, 0.0, Vector2.ONE)
			# the two motors on a pad, sized and jittered by their intensity
			var px := W * 0.7
			var py := H * 0.2
			var pw := W * 0.24
			var ph := H * 0.16
			_round_box(n, Rect2(px, py, pw, ph), PANEL7, Kit.BONE)
			var m_a: Array = [lo, hi]
			for m in 2:
				var ma: float = m_a[m]
				var mcol := Kit.WATER if m == 1 else Kit.HOT
				var cx := px + pw * (0.25 + 0.5 * m) + randf_range(-1.0, 1.0) * ma * 2.0
				var cy := py + ph * 0.55 + randf_range(-1.0, 1.0) * ma * 2.0
				Kit.dot(n, Vector2(cx, cy), ph * 0.18 + ma * ph * 0.14, _al(mcol, 0.25 + 0.75 * ma))
				Kit.ring(n, Vector2(cx, cy), ph * 0.22, mcol, 1.0)
				Kit.label(n, b, "high" if m == 1 else "low", Vector2(cx, py + ph + 10.0), mcol, true)
			# the envelopes over time: history left of now, booked pulses to the right
			var ex := 8.0
			var ey := 8.0
			var ew := W * 0.56
			var eh := H * 0.34
			var span := 2.0
			var now_x := ex + ew * 0.7
			_panel(n, Rect2(ex, ey, ew, eh), PANEL, FRAME)
			for m in 2:
				var ry := ey + 4.0 + m * (eh / 2.0)
				var rh := eh / 2.0 - 8.0
				var mcol := Kit.WATER if m == 1 else Kit.HOT
				Kit.label(n, b, "high motor" if m == 1 else "low motor", Vector2(ex + 4.0, ry + 8.0), mcol)
				var fill := _al(mcol, 0.6)
				for e in b.events:
					var ev: Dictionary = e
					if int(ev.m) != m:
						continue
					var x0 := now_x - (t - float(ev.at)) / span * ew * 0.7
					var x1 := now_x - (t - float(ev.at) - float(ev.dur)) / span * ew * 0.7
					var cx0 := clampf(x0, ex, ex + ew)
					var cx1 := clampf(x1, ex, ex + ew)
					if cx1 > cx0:
						n.draw_rect(Rect2(cx0, ry + rh - rh * float(ev.a), cx1 - cx0, rh * float(ev.a)), fill)
				n.draw_line(Vector2(ex, ry + rh), Vector2(ex + ew, ry + rh), Color(0.788, 0.769, 0.894, 0.25), 1.0)
			n.draw_line(Vector2(now_x, ey), Vector2(now_x, ey + eh), Kit.INK, 1.0)
			Kit.label(n, b, "now", Vector2(now_x + 3.0, ey + eh - 3.0), Kit.DIM)
			# the phone: the same pattern as a flat ms list
			var fx := W * 0.7
			var fy := H * 0.5
			var fw := W * 0.24
			var fh := H * 0.2
			_round_box(n, Rect2(fx, fy, fw, fh), PANEL7, Kit.SUN if inten > 0.0 else Kit.BONE)
			var last_name: String = b.lastName
			var last_vib: String = b.lastVib
			Kit.label(n, b, last_name if last_name != "" else "—", Vector2(fx + fw / 2.0 + randf_range(-1.0, 1.0) * inten * 2.0, fy + fh * 0.4), Kit.SUN, true)
			Kit.label(n, b, last_vib.substr(0, floori(fw / 5.0)) if last_vib != "" else "vibrate([])", Vector2(fx + fw / 2.0, fy + fh * 0.75), Kit.DIM, true)
			Kit.label(n, b, "motors: %s · stretch ×%s · shake %.2f" % [D.motorFilter, str(D.stretch), inten], Vector2(8.0, H - 22.0), Kit.DIM)
			Kit.label(n, b, D.label, Vector2(W / 2.0, H - 8.0), FAINT, true)
