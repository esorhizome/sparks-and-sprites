// MOSH — the almanac's Mosh card (scenes/stage/screen.gd): tape damage as
// three separate lies. BLOCK DISPLACEMENT: rows in blocks of `block` pixels
// slide sideways by a hashed amount (blk[], rolled by the card on each
// corruption) that decays — the datamosh smear. Always on: a TRACKING BAR
// rolling up the frame (rows jittered, brightened, noisy), CHROMA BLEED
// (red read a little left, blue a little right — the tape stored colour at
// lower resolution), and head-switching noise on the bottom rows. The
// FRAME-HOLD is the painter's half: it redraws the last good frame.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform vec2 card_size = vec2(220.0, 150.0);
uniform float scale = 0.5;
uniform float block = 8.0;                      // row block height, card px
uniform float shift = 0.1;                      // a displaced block's slide, as a fraction of the width
uniform float bleed = 2.0;                      // chroma offset in buffer pixels (R left, B right)
uniform float track = 0.35;                     // the tracking bar's strength
uniform float track_y = 0.0;                    // where the bar is, 0..1 of the height
uniform float cor = 0.0;                        // the current corruption, 1 → 0
uniform float seed = 0.0;                       // this frame's row noise seed
uniform float blk[64];                          // which blocks slide, and how far (−1..1, 0 = still)

float hash2(float i, float j) { return fract(sin(i * 127.1 + j * 269.5 + 311.7) * 43758.5453); }

vec3 read_px(vec2 q, vec2 bw, vec2 org, vec2 span) {
	q = clamp(q, vec2(0.0), bw - 1.0);
	return texture(screen_tex, org + (q + 0.5) / bw * span).rgb;
}

void fragment() {
	vec2 span = vec2(dFdx(SCREEN_UV.x) / dFdx(UV.x), dFdy(SCREEN_UV.y) / dFdy(UV.y));
	vec2 org = SCREEN_UV - UV * span;
	vec2 bw = max(vec2(1.0), round(card_size * scale));
	vec2 p = clamp(floor(UV * bw), vec2(0.0), bw - 1.0);
	float w = bw.x;
	float h = bw.y;
	float s = w / card_size.x;
	float bb = max(1.0, block * s);
	float ty = track_y * h;
	float band_h = max(2.0, h * 0.09);
	float x = p.x;
	float y = p.y;
	int bi = int(y / bb);
	float dband = abs(y - ty);
	bool in_band = dband < band_h;
	float k = in_band ? 1.0 - dband / band_h : 0.0;
	float rs = 0.0;
	if (cor > 0.0) { rs += blk[bi & 63] * shift * w * cor; }                          // block displacement
	if (in_band) { rs += (hash2(y, seed) - 0.5) * w * 0.08 * k * track; }             // the tracking bar jitters its rows
	if (y >= h - 3.0) { rs += (hash2(y + 0.5, seed + 11.0) - 0.5) * w * 0.12; }      // head-switching noise
	float bl = round(bleed * (in_band ? 3.0 : 1.0));
	float gain = 1.0 + 0.6 * k * track;
	vec3 c = vec3(read_px(vec2(floor(x - rs - bl + 0.5), y), bw, org, span).r,     // R(x − bleed)
		read_px(vec2(floor(x - rs + 0.5), y), bw, org, span).g,                     // G(x)
		read_px(vec2(floor(x - rs + bl + 0.5), y), bw, org, span).b) * gain;        // B(x + bleed)
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
