// UNDERSEA — the almanac's water refraction + caustics (scenes/stage/skin.gd,
// card U), the web card's strip loop spelled as a fragment. The runner lays
// this over b.shader_rect = the water (the card from the surface y0 down),
// reading what the painter drew through the screen texture:
//   x' = x + noise2(y·k, t·speed + y·0.003) · amp      (per strip of `strip` px)
//   caustic = (n₁·n₂ > thr) · gain, added on the floor band (y ≥ gy)
// noise2 is the kit's 2-D value noise, hash and all, so the painter's copy
// of the push curve and this pass agree. The strip's push is a copy of the
// source row shifted by dx, so the pixel at x shows the source at x − dx.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform vec2 rect_size = vec2(220.0, 75.0);   // this pass's rect, card px (W × (H − y0))
uniform vec2 card_size = vec2(220.0, 150.0);  // the whole card, card px
uniform float y0 = 75.0;       // the surface: the rect's top, card-local px
uniform float gy = 120.0;      // the ground line, card-local px (caustics below it)
uniform float t = 0.0;         // the card's clock (tempo-aware, not TIME)
uniform float amp = 3.0;       // refraction push at full noise, px (× (1 + 2.5·boost) already)
uniform float k = 0.06;        // noise waves per px of depth
uniform float speed = 0.7;     // how fast the noise field scrolls
uniform float strip = 2.0;     // strip height, px
uniform float thr = 0.5;       // caustic threshold
uniform float c_scale = 0.09;  // caustic cell size (bigger = smaller cells)
uniform float c_speed = 0.4;   // caustic drift speed

const float CW = 64.0;         // the web's caustic buffer: 64 × 24, stretched over the floor band
const float CH = 24.0;

float hash2(float i, float j) {
	float s = sin(i * 127.1 + j * 269.5 + 311.7) * 43758.5453;
	return s - floor(s);
}

// the kit's noise2(x, y): smooth 2-D value noise in -1..1
float noise2(float x, float y) {
	float i = floor(x);
	float j = floor(y);
	float fx = x - i;
	float fy = y - j;
	float kx = fx * fx * (3.0 - 2.0 * fx);
	float ky = fy * fy * (3.0 - 2.0 * fy);
	float a = hash2(i, j);
	float b = hash2(i + 1.0, j);
	float c = hash2(i, j + 1.0);
	float d = hash2(i + 1.0, j + 1.0);
	float top = a + (b - a) * kx;
	float bot = c + (d - c) * kx;
	return (top + (bot - top) * ky) * 2.0 - 1.0;
}

void fragment() {
	// this fragment in card px, and the strip its row belongs to
	vec2 px = vec2(UV.x * rect_size.x, y0 + UV.y * rect_size.y);
	float ys = y0 + floor((px.y - y0) / max(strip, 1.0)) * max(strip, 1.0);
	float dx = noise2(ys * k, t * speed + ys * 0.003) * amp;
	// card px → screen uv: the rect's extent in screen uv, from the derivatives
	// (the window may scale the canvas, so SCREEN_PIXEL_SIZE alone is not a card px)
	float dux = dFdx(UV.x);
	float s_per_uv_x = abs(dux) > 1e-7 ? dFdx(SCREEN_UV.x) / dux : SCREEN_PIXEL_SIZE.x * rect_size.x;
	float s_per_px_x = s_per_uv_x / rect_size.x;
	// the web layer is transparent past the canvas edge; here the edge pixel repeats
	float sx = clamp(px.x - dx, 0.5, card_size.x - 0.5);
	vec2 suv = vec2(SCREEN_UV.x + (sx - px.x) * s_per_px_x, SCREEN_UV.y);
	vec4 col = texture(screen_tex, suv);
	// caustics: two noise fields drifting against each other, multiplied,
	// thresholded, added ("lighter") on the floor band at 0.7
	if (px.y >= gy) {
		float u = px.x / card_size.x * CW;
		float v = (px.y - gy) / max(1.0, card_size.y - gy) * CH;
		float ph = t * c_speed;
		float o1 = (CW - 1.0) * (0.5 + 0.5 * sin(ph));
		float o2 = (CW - 1.0) * (0.5 - 0.5 * sin(ph * 0.71 + 1.0));
		float o3 = floor(CH * (0.5 + 0.5 * sin(ph * 0.53 + 2.0)));
		float o4 = floor(CH * (0.5 - 0.5 * cos(ph * 0.37)));
		float n1 = 0.5 + 0.5 * noise2((u + o1) * c_scale, (v + o3) * c_scale * 2.2);
		float n2 = 0.5 + 0.5 * noise2((u + o2) * c_scale * 1.37 + 7.0, (v + o4) * c_scale * 2.9 + 3.0);
		float val = n1 * n2 - thr;
		float gain = 420.0 / max(0.05, 1.0 - thr);
		float a = val > 0.0 ? min(1.0, val * gain / 255.0) : 0.0;
		col.rgb += vec3(220.0, 245.0, 255.0) / 255.0 * a * 0.7;
	}
	COLOR = vec4(col.rgb, 1.0);
}
