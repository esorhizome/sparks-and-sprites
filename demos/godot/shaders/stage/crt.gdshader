// CRT — the almanac's Crt card (scenes/stage/screen.gd) as a real fragment
// shader: the same pass the web card spells slowly over ImageData bytes.
// BARREL CURVATURE is a lookup — the output pixel at uv (−1..1) reads the
// SOURCE at uv + uv·|uv|²·curve, so the corners reach past the picture and
// go black: the bezel appears by itself. SCANLINES darken every other row of
// the small buffer; the PHOSPHOR MASK boosts one channel per column (r, g,
// b, r, g, b…); the VIGNETTE multiplies by 1 − vig·|uv|⁴; a hair of BLOOM
// adds the bright neighbours two texels left and right.
//
// The buffer: like the web's pix(scale), the pass works on a card_size·scale
// grid of texels. Reading each texel at its centre with a linear filter is
// the web's smoothing shrink (at scale 0.5 it is exactly the 2×2 average).
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform vec2 card_size = vec2(220.0, 150.0);   // the card in canvas pixels (b.uniforms.card_size)
uniform float scale = 0.5;                      // the pass runs at this fraction of the card
uniform float curve = 0.12;                     // how much the corners bend inward
uniform float scan = 0.35;                      // scanline darkness (every other row)
uniform float mask = 0.18;                      // the RGB phosphor stripe strength
uniform float vig = 0.4;                        // corner darkening
uniform float bloom = 0.3;                      // how much bright neighbours bleed sideways

// The source at buffer pixel q (clamped to the buffer), read at its centre.
vec3 read_px(vec2 q, vec2 bw, vec2 org, vec2 span) {
	q = clamp(q, vec2(0.0), bw - 1.0);
	return texture(screen_tex, org + (q + 0.5) / bw * span).rgb;
}

void fragment() {
	// the card's place on the screen: its size in screen uv (span) and its
	// top-left (org), from the derivatives — so the window's canvas_items
	// stretch cannot skew the mapping
	vec2 span = vec2(dFdx(SCREEN_UV.x) / dFdx(UV.x), dFdy(SCREEN_UV.y) / dFdy(UV.y));
	vec2 org = SCREEN_UV - UV * span;
	vec2 bw = max(vec2(1.0), round(card_size * scale));       // the buffer: w × h texels
	vec2 p = clamp(floor(UV * bw), vec2(0.0), bw - 1.0);      // this fragment's buffer pixel
	float uu = (p.x + 0.5) * 2.0 / bw.x - 1.0;
	float v = (p.y + 0.5) * 2.0 / bw.y - 1.0;
	float r2 = uu * uu + v * v;
	float f = 1.0 + curve * r2;
	float su = uu * f;                                        // uv' = uv + uv·|uv|²·curve
	float sv = v * f;
	if (su < -1.0 || su > 1.0 || sv < -1.0 || sv > 1.0) {
		COLOR = vec4(vec3(8.0 / 255.0), 1.0);                 // past the picture: the bezel
	} else {
		vec2 sp = vec2(min(bw.x - 1.0, floor((su + 1.0) * 0.5 * bw.x)), min(bw.y - 1.0, floor((sv + 1.0) * 0.5 * bw.y)));
		vec3 src = read_px(sp, bw, org, span);
		vec3 lo = read_px(sp - vec2(2.0, 0.0), bw, org, span);
		vec3 hi = read_px(sp + vec2(2.0, 0.0), bw, org, span);
		float bright = (lo.r + lo.g + lo.b + hi.r + hi.g + hi.b) / 6.0;
		float add = bloom * max(0.0, bright - 150.0 / 255.0);
		float row_k = (int(p.y) % 2 == 1) ? 1.0 - scan : 1.0;   // row % 2 → ×(1 − scan)
		float vg = (1.0 - vig * r2 * r2 * 0.25) * row_k;
		int m = int(p.x) % 3;                                  // col % 3 → rgb mask
		vec3 mk = vec3(m == 0 ? mask : -mask * 0.5, m == 1 ? mask : -mask * 0.5, m == 2 ? mask : -mask * 0.5);
		COLOR = vec4(clamp(src * vg * (1.0 + mk) + add, 0.0, 1.0), 1.0);
	}
}
