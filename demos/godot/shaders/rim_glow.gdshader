// RIM GLOW — paint light just OUTSIDE the sprite's own pixels.
// Sample the alpha in a small ring around each point; where a neighbour is
// solid but we are not, we're standing on the rim — add glow there.
// Works on every frame of a flipbook automatically: TEXTURE is always the
// frame currently showing. Needs transparent padding around the art —
// a cropped-tight PNG clips the halo flat at the texture's edge.
// Companion: cheatsheets/godot-flipbook-vfx.md §3.1. Chapters 03, 06.
shader_type canvas_item;

uniform vec4 glow_color : source_color = vec4(0.45, 0.9, 1.0, 1.0);
uniform float glow_size : hint_range(0.0, 12.0) = 3.0;     // in texture pixels
uniform float glow_strength : hint_range(0.0, 4.0) = 1.1;  // scripts tween this

void fragment() {
	vec4 tint = COLOR;                        // modulate arrives here — honour it
	float raw_a = texture(TEXTURE, UV).a;     // the frame's own silhouette
	vec4 base = texture(TEXTURE, UV) * tint;
	vec2 px = TEXTURE_PIXEL_SIZE * glow_size;
	float dilated = 0.0;
	for (int i = 0; i < 8; i++) {
		float ang = TAU * float(i) / 8.0;
		dilated = max(dilated, texture(TEXTURE, UV + vec2(cos(ang), sin(ang)) * px).a);
	}
	float halo = clamp(dilated - raw_a, 0.0, 1.0);
	COLOR = base + glow_color * halo * glow_strength;   // glow ignores the tint on purpose
}
