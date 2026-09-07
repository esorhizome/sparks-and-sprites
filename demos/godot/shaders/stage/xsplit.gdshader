// XSPLIT — the almanac's Xsplit card (scenes/stage/screen.gd): chromatic
// aberration. A lens fails to focus every wavelength at the same spot: red
// lands a little outside, blue a little inside. As a pass it is three reads
// instead of one — red from p − o, green from p, blue from p + o — where o
// points away from the centre and GROWS with |uv|^power, so the middle stays
// sharp and the corners fringe. The glitch pulse tears 4-row bands sideways
// for a few frames (the web rolls an LCG per band; here a hash of the band
// and the seed the card re-rolls on every pulse — the same lottery).
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform vec2 card_size = vec2(220.0, 150.0);
uniform float scale = 0.5;
uniform float split = 0.05;                     // the offset at the corners, as a fraction of the buffer width
uniform float power = 2.0;                      // how the offset grows with distance from the centre (|uv|^power)
uniform float glitch = 0.0;                     // the pulse's current strength, 0..1
uniform float seed = 1.0;                       // re-rolled on every pulse

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
	float cx = w / 2.0;
	float cy = bw.y / 2.0;
	float sp = split * w;
	float hp = power * 0.5;
	float ro = 0.0;                                            // the glitch: some 4-row bands get a sideways tear
	if (glitch > 0.0) {
		float band = floor(p.y / 4.0);
		if (hash2(band, seed) < 90.0 / 256.0) {
			ro = (hash2(band + 0.37, seed * 1.7 + 3.0) - 0.5) * 2.0 * glitch * w * 0.15;
		}
	}
	float uu = (p.x - cx) / cx;
	float vv = (p.y - cy) / cy;
	float r2 = uu * uu + vv * vv;
	float r = sqrt(r2);
	float ox = 0.0;
	float oy = 0.0;
	if (r > 1e-4) {                                            // o = split·|uv|^p·û
		float f = sp * pow(r2, hp) / r;
		ox = uu * f;
		oy = vv * f;
	}
	vec2 pr = vec2(floor(p.x - ox + ro + 0.5), floor(p.y - oy + 0.5));   // red from p − o
	vec2 pb = vec2(floor(p.x + ox - ro + 0.5), floor(p.y + oy + 0.5));   // blue from p + o
	COLOR = vec4(read_px(pr, bw, org, span).r, read_px(p, bw, org, span).g, read_px(pb, bw, org, span).b, 1.0);
}
