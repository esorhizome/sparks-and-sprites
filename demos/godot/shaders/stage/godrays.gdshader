// GODRAYS — the almanac's Godrays card (scenes/stage/screen.gd): crepuscular
// rays are a radial blur that only the light is allowed into. THRESHOLD: a
// mask of the pixels brighter than T — the sun and little else. SMEAR: from
// every pixel, step toward the sun's screen position N times, summing the
// mask with a decay per step. ADD: pour the sum back onto the frame in the
// sun's colour. Anything dark between a pixel and the sun (the trees, the
// hero) leaves a hole in its sum, and those holes are the shafts.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform vec2 card_size = vec2(220.0, 150.0);
uniform float scale = 0.5;
uniform float threshold = 205.0;                // luminance above this counts as light (0..255, as the web counts)
uniform int samples = 12;                       // steps toward the sun per pixel
uniform float density = 0.7;                    // how far toward the sun the last step reaches
uniform float weight = 0.6;                     // how much of the smear is added back
uniform float decay = 0.9;                      // each step counts this much less than the last
uniform vec4 sun_col : source_color = vec4(1.0, 0.941, 0.722, 1.0);   // the colour the rays add
uniform vec2 sun = vec2(110.0, 48.0);           // the sun on screen, card px

vec3 read_px(vec2 q, vec2 bw, vec2 org, vec2 span) {
	q = clamp(q, vec2(0.0), bw - 1.0);
	return texture(screen_tex, org + (q + 0.5) / bw * span).rgb;
}

// the threshold mask at buffer pixel q: 1 where lum > T
float bright_at(vec2 q, vec2 bw, vec2 org, vec2 span) {
	vec3 c = read_px(q, bw, org, span);
	return (dot(c, vec3(0.299, 0.587, 0.114)) * 255.0 > threshold) ? 1.0 : 0.0;
}

void fragment() {
	vec2 span = vec2(dFdx(SCREEN_UV.x) / dFdx(UV.x), dFdy(SCREEN_UV.y) / dFdy(UV.y));
	vec2 org = SCREEN_UV - UV * span;
	vec2 bw = max(vec2(1.0), round(card_size * scale));
	vec2 p = clamp(floor(UV * bw), vec2(0.0), bw - 1.0);
	vec3 src = read_px(p, bw, org, span);
	float s = bw.x / card_size.x;
	float sxb = sun.x * s;
	float syb = sun.y * s;
	int N = clamp(samples, 1, 64);
	float dx = (sxb - p.x) * density / float(N);
	float dy = (syb - p.y) * density / float(N);
	float acc = 0.0;
	float wgt = 1.0;
	for (int i = 1; i <= 64; i++) {                            // step toward the sun, summing the mask
		if (i > N) { break; }
		vec2 q = vec2(floor(p.x + dx * float(i) + 0.5), floor(p.y + dy * float(i) + 0.5));
		if (q.x >= 0.0 && q.x < bw.x && q.y >= 0.0 && q.y < bw.y) { acc += bright_at(q, bw, org, span) * wgt; }
		wgt *= decay;
	}
	float k = acc / float(N) * weight;
	COLOR = vec4(clamp(src + sun_col.rgb * k, 0.0, 1.0), 1.0);   // added back, in the sun's colour
}
