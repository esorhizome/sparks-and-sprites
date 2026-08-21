// DISSOLVE — the noise-threshold trick, as a real shader.
// Per pixel: read smooth noise; if it's below the sliding threshold, the
// pixel is gone; just above it, paint a hot rim. Three lines of real logic —
// the "hello world" of shader confidence. Chapter 03 in the book.
shader_type canvas_item;

uniform sampler2D noise_tex;             // a NoiseTexture2D, supplied from code
uniform float threshold : hint_range(0.0, 1.0) = 0.0;
uniform vec4 edge_colour : source_color = vec4(0.84, 0.66, 0.47, 1.0);

void fragment() {
	float n = texture(noise_tex, UV).r;
	COLOR = texture(TEXTURE, UV);
	// ---- the whole dissolve ----
	if (n < threshold) { discard; }                       // dissolved: gone
	if (n < threshold + 0.06) { COLOR.rgb = edge_colour.rgb; }  // hot rim
	// ----------------------------
}
