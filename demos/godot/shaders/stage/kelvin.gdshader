// KELVIN — the almanac's Kelvin card (scenes/stage/screen.gd): colour
// grading is a function of colour applied to every pixel, and most of it is
// PER-CHANNEL: contrast (stretch about the middle), warmth (a Kelvin-ish
// tilt: red up and blue down, or the reverse), and POSTERISE (round to L
// steps). The web bakes those into three 256-entry lookup tables; here the
// same curve is simply evaluated per channel. SATURATION mixes channels
// (toward or away from the pixel's luminance), so it runs first.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform vec2 card_size = vec2(220.0, 150.0);
uniform float scale = 0.5;
uniform float contrast = 1.0;
uniform float sat = 1.0;
uniform float warm = 0.0;
uniform int levels = 0;                         // posterise steps (0 or 1 = off)

vec3 read_px(vec2 q, vec2 bw, vec2 org, vec2 span) {
	q = clamp(q, vec2(0.0), bw - 1.0);
	return texture(screen_tex, org + (q + 0.5) / bw * span).rgb;
}

// one channel's curve, in 0..255 like the web's table: (v − 128)·contrast + 128 ± warm → ⌊·L⌋/L
float curve_c(float v, float tilt, float L) {
	float x = (v - 128.0) * contrast + 128.0 + warm * tilt;
	if (L > 0.0) { x = round(x / 255.0 * L) / L * 255.0; }
	return clamp(x, 0.0, 255.0);
}

void fragment() {
	vec2 span = vec2(dFdx(SCREEN_UV.x) / dFdx(UV.x), dFdy(SCREEN_UV.y) / dFdy(UV.y));
	vec2 org = SCREEN_UV - UV * span;
	vec2 bw = max(vec2(1.0), round(card_size * scale));
	vec2 p = clamp(floor(UV * bw), vec2(0.0), bw - 1.0);
	vec3 c = read_px(p, bw, org, span) * 255.0;
	float lum = dot(c, vec3(0.299, 0.587, 0.114));
	vec3 c2 = clamp(lum + (c - lum) * sat, 0.0, 255.0);      // saturation first
	float L = float(max(0, levels - 1));
	vec3 o = vec3(curve_c(c2.r, 45.0, L), curve_c(c2.g, -6.0, L), curve_c(c2.b, -45.0, L));   // then the three curves
	COLOR = vec4(o / 255.0, 1.0);
}
