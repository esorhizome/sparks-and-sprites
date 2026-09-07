// YESTERYEAR — the almanac's Yesteryear card (scenes/stage/screen.gd): film
// grain is noise added per pixel PER FRAME — never the same twice, which is
// the whole difference from a grain texture pasted on top. The pass also
// does GATE WEAVE (read the source a pixel or so off, the offset re-rolled a
// few times a second), an exposure FLICKER (one multiplier per frame), and
// a SEPIA pull toward an old print. STATIC swaps the grain for TV snow that
// replaces the picture. One fresh random per pixel per frame: a hash of the
// pixel and the frame counter (the web rolls an LCG through the buffer).
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform vec2 card_size = vec2(220.0, 150.0);
uniform float scale = 0.5;
uniform float grain = 0.2;                      // noise amplitude, of full brightness
uniform float snow = 0.0;                       // static mode: how much of the picture the snow replaces (0 = grain mode)
uniform float flick = 1.0;                      // this frame's exposure multiplier
uniform vec2 weave = vec2(0.0);                 // gate weave: this frame's offset, card px
uniform float sepia = 0.0;                      // 0..1: pull colours toward an old print
uniform int frame_no = 0;                       // the frame counter (mod 1024)

float hash3(float x, float y, float z) { return fract(sin(x * 127.1 + y * 311.7 + z * 74.7 + 19.19) * 43758.5453); }

vec3 read_px(vec2 q, vec2 bw, vec2 org, vec2 span) {
	q = clamp(q, vec2(0.0), bw - 1.0);
	return texture(screen_tex, org + (q + 0.5) / bw * span).rgb;
}

void fragment() {
	vec2 span = vec2(dFdx(SCREEN_UV.x) / dFdx(UV.x), dFdy(SCREEN_UV.y) / dFdy(UV.y));
	vec2 org = SCREEN_UV - UV * span;
	vec2 bw = max(vec2(1.0), round(card_size * scale));
	vec2 p = clamp(floor(UV * bw), vec2(0.0), bw - 1.0);
	float s = bw.x / card_size.x;
	vec2 j = round(weave * s);
	vec3 src = read_px(p + j, bw, org, span);                 // v(p + weave)
	float nr = hash3(p.x, p.y, float(frame_no)) * 255.0;      // n: 0..255, fresh every frame
	vec3 c;
	if (snow > 0.0) {
		c = src * (1.0 - snow) + (nr / 255.0) * snow;          // static: v = lerp(v, n, snow)
	} else {
		float gr = (nr - 128.0) / 128.0 * grain;               // grain: v·flicker + (n − ½)·grain
		c = src * flick + gr;
	}
	if (sepia > 0.0) {
		float lum = dot(c, vec3(0.299, 0.587, 0.114));
		c += (lum * vec3(1.15, 0.95, 0.7) - c) * sepia;
	}
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
