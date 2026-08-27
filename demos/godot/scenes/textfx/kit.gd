extends RefCounted
## Shared kit for the glyph grimoire (scenes/textfx/*.gd) — each family file
## preloads this as TextKit. It owns the phrase: "just this", laid out one
## character at a time so every effect is just a loop over letters deciding
## WHERE each one is, HOW BIG, WHAT COLOUR, and WHETHER IT EXISTS YET.
##
## Card state lives in the card dictionary b:
##   b.rect      — the card's stage area (absolute scene coords)
##   b.mid       — the phrase's baseline y
##   b.base_size — the resting font size for this card
##
## Translation notes (web canvas → Godot _draw), same spirit as the
## bestiary and codex kits:
##   · canvas font weights 300–700  → ThemeDB's fallback font has ONE
##     weight, so "bolder" is spelled draw_string_outline with a growing
##     outline (fake bold — the same trick bitmap-font games use);
##   · ctx.shadowBlur / radial glows → layered translucent circles (glow);
##   · globalCompositeOperation "lighter" → the same layering, brighter;
##   · canvas clip() on letters      → a scale-y reveal anchored top or
##     bottom (ink that rises, snow that presses down), noted in place.

const PHRASE := "just this"
const GLYPHS := "abcdefghjkmnpqrstuvwxyz023456789#%&@+=?"
const INK := Color(0.91, 0.898, 0.957)
const DIM := Color(0.91, 0.898, 0.957, 0.22)
const FONT_RATIO := 0.62                  ## width/size guess only for pre-layout sizing

static func setup(b: Dictionary) -> void:
	var r: Rect2 = b.rect
	b.mid = r.position.y + r.size.y * 0.54
	b.base_size = minf(r.size.y * 0.30, r.size.x * 0.135)

## The heart of the kit: measure PHRASE at font size `size` (default
## b.base_size) with `spacing` extra px between letters, centred in the
## card. Returns one Dictionary per character:
##   { ch, i, n, x, cx, w, y }  — x = left edge, cx = centre, w = width,
##   y = the shared baseline. Draw a plain letter with
##   TextKit.letter(n, l.ch, Vector2(l.x, l.y), size, col); draw a
##   transformed one via draw_set_transform around (l.cx, l.y).
static func layout(b: Dictionary, size: float = -1.0, spacing: float = 0.0) -> Array:
	var font := ThemeDB.fallback_font
	var s: float = b.base_size if size < 0.0 else size
	var fs := int(round(s))
	var ws: Array = []
	var total := 0.0
	for i in PHRASE.length():
		var w: float = font.get_string_size(PHRASE[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		ws.append(w)
		total += w + (spacing if i > 0 else 0.0)
	var r: Rect2 = b.rect
	var x: float = r.get_center().x - total / 2.0
	var out: Array = []
	for i in PHRASE.length():
		out.append({ "ch": PHRASE[i], "i": i, "n": PHRASE.length(),
			"x": x, "cx": x + (ws[i] as float) / 2.0, "w": ws[i], "y": b.mid })
		x += ws[i] + spacing
	return out

static func stage(n: CanvasItem, b: Dictionary) -> void:
	var r: Rect2 = b.rect
	n.draw_rect(r, Color(0.075, 0.063, 0.125))              # the night backdrop
	var y: float = b.mid + b.base_size * 0.28               # the faint dotted baseline rule
	var x := r.position.x + r.size.x * 0.08
	var x1 := r.position.x + r.size.x * 0.92
	while x < x1:
		n.draw_line(Vector2(x, y), Vector2(x + 2.0, y), Color(0.59, 0.57, 0.75, 0.14), 1.0)
		x += 7.0

## One letter at the baseline. `pos` is the letter's LEFT edge on the baseline.
static func letter(n: CanvasItem, ch: String, pos: Vector2, size: float, col: Color) -> void:
	n.draw_string(ThemeDB.fallback_font, pos, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, int(round(size)), col)

## The fake-bold dial: weight 300–700 → outline 0..~2.4 px of the same colour.
static func letter_weight(n: CanvasItem, ch: String, pos: Vector2, size: float, col: Color, weight: float) -> void:
	var fs := int(round(size))
	n.draw_string(ThemeDB.fallback_font, pos, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	var extra := (weight - 400.0) / 100.0
	if extra > 0.0:
		n.draw_string_outline(ThemeDB.fallback_font, pos, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
			int(ceil(extra * 0.8)), col)
	elif extra < 0.0:                       # thinner than the font: fade instead — the honest translation
		n.draw_string(ThemeDB.fallback_font, pos, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
			Color(col.r, col.g, col.b, col.a * 0.55))

static func letter_outline(n: CanvasItem, ch: String, pos: Vector2, size: float, width: int, col: Color) -> void:
	n.draw_string_outline(ThemeDB.fallback_font, pos, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, int(round(size)), width, col)

## Layered fading circles ≈ a soft additive glow.
static func glow(n: CanvasItem, pos: Vector2, radius: float, col: Color, layers: int = 3) -> void:
	for i in range(layers, 0, -1):
		var k := float(i) / layers
		n.draw_circle(pos, maxf(1.0, radius * k), Color(col.r, col.g, col.b, col.a * (1.1 - k) * 0.5))

static func twinkle(n: CanvasItem, pos: Vector2, size: float, col: Color) -> void:
	n.draw_line(pos - Vector2(size, 0), pos + Vector2(size, 0), col, 1.0)
	n.draw_line(pos - Vector2(0, size), pos + Vector2(0, size), col, 1.0)

static func scramble() -> String:
	return GLYPHS[randi() % GLYPHS.length()]
