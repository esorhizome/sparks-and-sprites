// IRIS — the almanac's Iris card (scenes/stage/screen.gd): a screen
// transition is a MASK. The web copies the frame about to leave into a
// layer, draws the new scene underneath, and cuts a hole in the copy that
// grows with e = 0 → 1; the whole family is one question — what shape is
// the hole: a circle (iris), cells in a hashed order (dissolve), squares
// growing in two waves (checker), a rect opening from the centre (curtain),
// the copy just translated (slide), ring-sectors sweeping lap by lap (swirl).
// Here the mask is decided per fragment, which is how a transition shader
// really works. The one approximation: a shader has no yesterday's frame,
// so the two scenes are both made from the frame the painter drew (the DAY
// scene) — the NIGHT scene is that frame graded toward the stage's night
// colours, with the lamp lit and its glow added. The mask shapes are exact;
// the "old frame" is not frozen, it is the live scene in its other dress.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform vec2 card_size = vec2(220.0, 150.0);
uniform int kind = 0;                           // 0 none (the whole frame is the inside scene) · 1 iris · 2 dissolve · 3 checker · 4 curtain · 5 slide · 6 swirl
uniform float e = 1.0;                          // eased progress, 0..1
uniform vec2 centre = vec2(110.0, 67.5);        // the iris / swirl centre, card px
uniform float rmax = 1.0;                       // the far corner, so the hole can reach it
uniform int cells = 14;                         // dissolve / checker cells across the width
uniform int turns = 3;                          // laps of the swirl's spiral
uniform bool in_night = false;                  // the scene inside the hole (the new one) is the night scene
uniform bool out_night = false;                 // the scene outside (the old frame) is the night scene
uniform vec2 bulb = vec2(136.4, 67.0);          // the lamp's bulb, card px
uniform float glow_r = 52.5;                    // the lamp glow's radius, card px

const vec3 SUN = vec3(0.961, 0.757, 0.412);

float cell_hash(float i, float j) { return fract(sin(i * 127.1 + j * 269.5 + 311.7) * 43758.5453); }   // each cell's dissolve threshold, fixed

// the day frame in its night dress: the stage kit's night lerp as a grade,
// the bulb lit, the glow added ("lighter" = additive)
vec3 night_of(vec3 c, vec2 px) {
	vec3 o = c * vec3(0.30, 0.26, 0.42) + vec3(0.02, 0.015, 0.05);
	float d = distance(px, bulb);
	if (d < 5.0) { o = SUN; }
	float half_r = glow_r * 0.5;
	float a = d < half_r ? mix(0.5, 0.175, d / half_r) : (d < glow_r ? mix(0.175, 0.0, (d - half_r) / half_r) : 0.0);
	return o + SUN * a;
}

// is this card pixel inside the hole (the revealed new scene)?
bool inside_hole(vec2 px) {
	float W = card_size.x;
	if (kind == 1) { return distance(px, centre) < max(0.1, e * rmax); }
	if (kind == 2 || kind == 3) {
		float cw = W / float(max(1, cells));
		float i = floor(px.x / cw);
		float j = floor(px.y / cw);
		if (kind == 2) { return cell_hash(i, j) < e; }
		float odd = mod(i + j, 2.0);                              // odd cells start half a transition later
		float s = clamp(e * 2.0 - odd, 0.0, 1.0) * cw;
		vec2 cc = vec2(i, j) * cw + cw * 0.5;
		return abs(px.x - cc.x) < s * 0.5 && abs(px.y - cc.y) < s * 0.5;
	}
	if (kind == 4) { return abs(px.x - W * 0.5) < e * W * 0.5; }
	if (kind == 5) { return px.x < e * W; }
	if (kind == 6) {
		int n = max(1, turns);
		vec2 d = px - centre;
		float dist = length(d);
		if (dist >= rmax) { return false; }
		int j = int(floor(dist / rmax * float(n)));                // band j opens only after j full laps
		float sweep = clamp(e * float(n) * TAU - float(j) * TAU, 0.0, TAU);
		float ang = atan(d.y, d.x);
		if (ang < 0.0) { ang += TAU; }
		return sweep > 0.001 && ang < sweep;
	}
	return true;
}

void fragment() {
	vec2 span = vec2(dFdx(SCREEN_UV.x) / dFdx(UV.x), dFdy(SCREEN_UV.y) / dFdy(UV.y));
	vec2 org = SCREEN_UV - UV * span;
	vec2 px = UV * card_size;
	vec3 here = texture(screen_tex, SCREEN_UV).rgb;
	vec3 o;
	if (inside_hole(px)) {
		o = in_night ? night_of(here, px) : here;
	} else {
		vec2 opx = px;
		vec3 old = here;
		if (kind == 5) {                                           // slide: the old copy simply moves
			opx = px - vec2(e * card_size.x, 0.0);
			old = texture(screen_tex, org + (UV - vec2(e, 0.0)) * span).rgb;
		}
		o = out_night ? night_of(old, opx) : old;
	}
	COLOR = vec4(o, 1.0);
}
