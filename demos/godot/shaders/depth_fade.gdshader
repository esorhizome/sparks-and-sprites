// DEPTH FADE — lines (or anything) that fade with distance from the camera.
// The 3D cousin of the depth atlas's "fog" call: the farther a vertex sits
// from the eye, the more it is mixed toward far_color. On a wireframe this
// alone turns a flat tangle into a solid you can read the front of.
//
// Use: put a ShaderMaterial with this shader on a MeshInstance3D — as its
// material_override if the mesh already carries a material (this is the
// least invasive way to dress an existing wireframe gallery: the mesh data
// never changes, only the material on top).
//
// near_dist / far_dist are in world units, measured along the camera's view
// axis. Set near_dist to about where the nearest lines are and far_dist to
// where the farthest are; everything in between gets the gradient.
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_opaque;

uniform vec4 near_color : source_color = vec4(0.92, 0.93, 0.98, 1.0);
uniform vec4 far_color  : source_color = vec4(0.30, 0.32, 0.60, 0.10);
uniform float near_dist = 2.0;
uniform float far_dist = 5.0;
uniform float curve : hint_range(0.25, 4.0) = 1.0;   // >1 keeps more lines bright, <1 fades sooner

varying float depth_k;

void vertex() {
	// MODELVIEW_MATRIX takes the vertex into view space, where -z is "away
	// from the camera". That single number is the depth.
	vec4 view_pos = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	float d = -view_pos.z;
	depth_k = pow(clamp((d - near_dist) / max(far_dist - near_dist, 0.001), 0.0, 1.0), curve);
}

void fragment() {
	vec4 c = mix(near_color, far_color, depth_k);
	ALBEDO = c.rgb;
	ALPHA = c.a;
}
