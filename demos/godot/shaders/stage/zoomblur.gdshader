// ZOOMBLUR — the almanac's Zoomblur card (scenes/stage/screen.gd): radial
// blur. For every pixel, walk N steps along the line from it to a CENTRE
// and average what you find. Near the centre the steps are tiny, so it
// stays sharp; at the edges they stretch into streaks — the camera rushing
// forward. reach = strength · amount is the envelope the card drives: it
// slams to 1 while the hero dashes and decays after. N is the cost — 8
// reads per pixel here. (The card turns the pass off, b.shader_on = false,
// when there is nothing to blur — the web skips pix() the same way.)
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform vec2 card_size = vec2(220.0, 150.0);
uniform float scale = 0.5;
uniform int samples = 8;                        // reads per pixel along the line to the centre
uniform float reach = 0.0;                      // strength · amount: how far toward the centre the last sample sits
uniform vec2 centre = vec2(132.0, 75.0);        // the centre, card px

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
	float cxb = centre.x * s;
	float cyb = centre.y * s;
	int N = clamp(samples, 1, 64);
	float dx = (cxb - p.x) * reach / float(N);
	float dy = (cyb - p.y) * reach / float(N);
	vec3 acc = vec3(0.0);
	for (int i = 0; i < 64; i++) {                             // N reads along the line to the centre
		if (i >= N) { break; }
		acc += read_px(vec2(floor(p.x + dx * float(i) + 0.5), floor(p.y + dy * float(i) + 0.5)), bw, org, span);
	}
	COLOR = vec4(acc / float(N), 1.0);                         // out = mean of the N samples
}
