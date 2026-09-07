// ORDERED — the almanac's Ordered card (scenes/stage/screen.gd): ordered
// dither as a fragment shader. A BAYER MATRIX is an n×n grid of thresholds
// arranged so every 2×2 block already holds a spread of values (built
// recursively: [[0,2],[3,1]], then each cell ×4 + that same pattern). Tile
// it over the frame; a pixel turns on where its brightness beats the
// threshold under it. With more than two levels the same test decides
// between the two nearest shades. No memory, no neighbours — one lookup per
// pixel — which is why a 1989 hand-held could afford it.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform vec2 card_size = vec2(220.0, 150.0);
uniform float scale = 0.5;
uniform int size = 4;                           // the Bayer matrix: 2, 4 or 8
uniform int levels = 4;                         // output shades (2 = 1-bit)
uniform vec4 dark_col : source_color = vec4(0.059, 0.220, 0.059, 1.0);    // the two ends of the shade ramp
uniform vec4 light_col : source_color = vec4(0.608, 0.737, 0.059, 1.0);

// (M[y][x] + ½) / n², with M built exactly as the web's recursion does it:
// the web nests  m[y % s][x % s]·4 + [0,2,3,1][quadrant]  from the bottom
// up, which is the same as reading each bit pair of (y, x) as one base-4
// digit, lowest bit most significant.
float bayer_thr(ivec2 c, int n) {
	int m = 0;
	for (int b = 0; b < 3; b++) {
		if ((1 << (b + 1)) > n) { break; }
		int xb = (c.x >> b) & 1;
		int yb = (c.y >> b) & 1;
		m = m * 4 + (yb * 3 + xb * 2 - yb * xb * 4);   // (0,0)→0 (0,1)→2 (1,0)→3 (1,1)→1
	}
	return (float(m) + 0.5) / float(n * n);
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
	int n = max(2, size);
	vec3 src = read_px(p, bw, org, span);
	float L = float(max(1, levels - 1));
	float v = dot(src, vec3(0.299, 0.587, 0.114)) * L;      // v = lum · (levels − 1)
	float bq = floor(v);
	float thr = bayer_thr(ivec2(int(p.x) % n, int(p.y) % n), n);
	float q = min(L, bq + ((v - bq > thr) ? 1.0 : 0.0));    // the threshold under this pixel decides
	COLOR = vec4(mix(dark_col.rgb, light_col.rgb, q / L), 1.0);
}
