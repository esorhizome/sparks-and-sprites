// REFRACT — the almanac's Refract card (scenes/stage/screen.gd): screen-space
// distortion. Every output pixel reads the scene from somewhere slightly
// else, p − field(p). The picture is untouched; only the READ ADDRESSES bend.
// HEAT is a noise field inside a cone above the fire, scrolling upward and
// fading with height. A SHOCKWAVE is a ring: inside its band the push is
// radial, amp·sin(π·(d − r)/w), so the ring magnifies on one side and
// shrinks on the other as it grows. WATER is the cheapest: one sine per row,
// one per column, below a line.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform vec2 card_size = vec2(220.0, 150.0);
uniform float scale = 0.5;
uniform int kind = 1;                           // the standing field: 1 heat · 2 water · 0 none
uniform float amp = 0.03;                       // the standing field's push, as a fraction of the buffer width
uniform float ring_w = 0.07;                    // a ring's thickness, of the width
uniform vec4 rings[6];                          // live shockwaves: x, y, r (card px), push at birth
uniform int nrings = 0;
uniform float rmax = 132.0;                     // a ring dies past this radius (card px)
uniform vec2 fire = vec2(66.0, 116.0);          // the fire, card px
uniform float water_y = 75.0;                   // the water line, card px
uniform float time = 0.0;                       // the card's clock (tempo included)

float hash2(float i, float j) { return fract(sin(i * 127.1 + j * 269.5 + 311.7) * 43758.5453); }
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
	float w = bw.x;
	float h = bw.y;
	float s = w / card_size.x;                                 // card px → buffer px
	float fxb = fire.x * s;
	float fyb = fire.y * s;
	float wyb = water_y * s;
	float a = amp * w;
	float rw = max(1.0, ring_w * w);
	float x = p.x;
	float y = p.y;
	float dx = 0.0;
	float dy = 0.0;
	if (kind == 1 && y < fyb) {                                // inside the cone above the fire: scrolling noise
		float spread = w * 0.06 + (fyb - y) * 0.5;
		float nx = (x - fxb) / spread;
		if (nx > -1.0 && nx < 1.0) {
			float wgt = (1.0 - nx * nx) * clamp(1.0 - (fyb - y) / (h * 0.8), 0.0, 1.0) * clamp((fyb - y) / (h * 0.06), 0.0, 1.0);
			dx = noise2(x * 0.3, y * 0.3 - time * 7.0) * a * wgt;
			dy = noise2(x * 0.3 + 9.0, y * 0.3 - time * 7.0) * a * 0.5 * wgt;
		}
	} else if (kind == 2 && y > wyb) {                         // water: sin rows and columns
		float rs = sin(y * 0.5 + time * 3.0);
		float cs = sin(x * 0.3 - time * 2.0);
		dx = (rs + cs) * a * 0.5;
		dy = rs * a * 0.25;
	}
	for (int i = 0; i < 6; i++) {                              // every live ring: a radial push inside its band
		if (i >= nrings) { break; }
		vec4 q = rings[i];
		float ddx = x - q.x * s;
		float ddy = y - q.y * s;
		float dd = sqrt(ddx * ddx + ddy * ddy);
		float band = dd - q.z * s;
		if (band > -rw && band < rw && dd > 1e-3) {
			float k = sin(PI * band / rw) * q.w * w * (1.0 - q.z / rmax);
			dx += k * ddx / dd;
			dy += k * ddy / dd;
		}
	}
	vec2 sp = vec2(floor(x - dx + 0.5), floor(y - dy + 0.5));  // p' = p − field(p)
	COLOR = vec4(read_px(sp, bw, org, span), 1.0);
}
