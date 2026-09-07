// QUANTISE — the almanac's Quantise card (scenes/stage/screen.gd): the frame
// may only use N colours. Two ways to choose. By LUMA: the palette, sorted
// by brightness, indexed with the pixel's brightness — cheap, and it keeps
// gradients ordered, which is why the Game Boy greens read as shading. By
// NEAREST: the palette colour with the smallest squared RGB distance — right
// for coloured palettes. (The web fills a 5-bit lookup table as pixels
// arrive; a GPU just does the N compares.) No dither: the bands are the point.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform vec2 card_size = vec2(220.0, 150.0);
uniform float scale = 0.5;
uniform vec4 pal[16];                           // the palette — sorted dark → light when luma is on
uniform int n = 4;                              // how many of pal are in use
uniform bool luma = true;                       // true: by brightness rank · false: by RGB distance

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
	int ci = 0;
	if (luma) {
		float lum = dot(src, vec3(0.299, 0.587, 0.114)) * 255.0;
		ci = min(nn - 1, int(lum / 256.0 * float(nn)));       // p[⌊L · N⌋]
	} else {
		float best = 1e9;
		for (int i = 0; i < 16; i++) {                         // argminᵢ |rgb − pᵢ|²
			if (i >= nn) { break; }
			vec3 d = pal[i].rgb - src;
			float dd = dot(d, d);
			if (dd < best) { best = dd; ci = i; }
		}
	}
	COLOR = vec4(pal[ci].rgb, 1.0);
}
