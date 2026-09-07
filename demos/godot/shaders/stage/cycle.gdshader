// CYCLE — the almanac's Cycle card (scenes/stage/screen.gd): palette cycling.
// The picture is an INDEX MAP — every pixel stores a number, not a colour —
// and the colour lives in a PALETTE the screen reads through. Rotate the
// palette by one entry per tick and every band moves one step, forever, for
// free. The web draws the map once into a layer with the index hidden in
// the red channel (g = 0, b = 255 as the marker) and the pass looks those
// pixels up. Here the painter lays down the same MARKER (pure blue) over the
// waterfall column and the pool, and this pass computes the index for each
// marker pixel from the same formula — the streaks, the noise, the rings —
// then reads pal[(index + shift) mod n]. The hero and the rocks the painter
// draws over the marker are not markers, so they stay, exactly as on the web.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform vec2 card_size = vec2(220.0, 150.0);
uniform float scale = 0.5;
uniform vec4 pal[16];                           // the palette
uniform int n = 12;                             // entries in use
uniform int off = 0;                            // the shift, in entries
uniform vec4 fall = vec4(83.6, 123.2, 18.0, 120.0);   // the waterfall column: x0, x1, yt, gy (card px)
uniform vec4 pool = vec4(103.4, 133.5, 48.4, 15.0);   // the pool ellipse: cx, cy, rx, ry (card px)

// the stage kit's value noise (kit.gd noise / noise2), in −1..1
float hash1(float i) { return fract(sin(i * 127.1 + 311.7) * 43758.5453); }
float hash2(float i, float j) { return fract(sin(i * 127.1 + j * 269.5 + 311.7) * 43758.5453); }
float noise1(float x) {
	float i = floor(x);
	float f = x - i;
	float k = f * f * (3.0 - 2.0 * f);
	return (hash1(i) + (hash1(i + 1.0) - hash1(i)) * k) * 2.0 - 1.0;
}
float noise2(float x, float y) {
	float i = floor(x);
	float j = floor(y);
	float fx = x - i;
	float fy = y - j;
	float kx = fx * fx * (3.0 - 2.0 * fx);
	float ky = fy * fy * (3.0 - 2.0 * fy);
	float a = hash2(i, j);
	float bb = hash2(i + 1.0, j);
	float c = hash2(i, j + 1.0);
	float d = hash2(i + 1.0, j + 1.0);
	float top = a + (bb - a) * kx;
	float bot = c + (d - c) * kx;
	return (top + (bot - top) * ky) * 2.0 - 1.0;
}

vec3 read_px(vec2 q, vec2 bw, vec2 org, vec2 span) {
	q = clamp(q, vec2(0.0), bw - 1.0);
	return texture(screen_tex, org + (q + 0.5) / bw * span).rgb;
}

void fragment() {
	vec2 span = vec2(dFdx(SCREEN_UV.x) / dFdx(UV.x), dFdy(SCREEN_UV.y) / dFdy(UV.y));
	vec2 org = SCREEN_UV - UV * span;
	vec2 bw = max(vec2(1.0), round(card_size * scale));
	vec2 p = clamp(floor(UV * bw), vec2(0.0), bw - 1.0);
	vec3 src = read_px(p, bw, org, span);
	int nn = clamp(n, 1, 16);
	if (src.b > 225.0 / 255.0 && src.g < 30.0 / 255.0) {       // an indexed pixel
		vec2 c = (p + 0.5) / bw * card_size;                    // the map's own pixel, in card px
		float x = c.x;
		float y = c.y;
		int idx;
		if (x >= fall.x && x <= fall.y && y >= fall.z && y <= fall.w + 2.0) {   // the waterfall
			float edge = min(x - fall.x, fall.y - x) / max(1.0, fall.y - fall.x);
			float streak = (noise1(x * 0.09 + 3.0) * 0.5 + 0.5) * 6.0;         // each column its own offset
			idx = int(floor(y / card_size.y * 26.0 + streak + noise2(x * 0.12, y * 0.06) * 1.5 + (edge < 0.08 ? 3.0 : 0.0)));
		} else {                                                                // the pool: rings
			float dx = (x - pool.x) / pool.z;
			float dy = (y - pool.y) / pool.w;
			float dd = min(0.99, sqrt(dx * dx + dy * dy));
			idx = int(floor(dd * 10.0 + noise2(x * 0.05, y * 0.1) * 0.8));
		}
		idx = ((idx % nn) + nn) % nn;
		src = pal[(idx + off) % nn].rgb;                        // colour = pal[(index + shift) mod n]
	}
	COLOR = vec4(src, 1.0);
}
