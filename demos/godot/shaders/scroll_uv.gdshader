// INFINITE SCROLL — the one-line UV shader.
// UV = "which part of the texture am I reading?" (0,0 top-left → 1,1 bottom-right).
// Add time to it and the texture slides forever. That's the whole trick.
// Chapter 04 in the book.
shader_type canvas_item;

uniform float speed = 0.05;   // tiles per second — try 0.5, then 0.01

void fragment() {
	vec2 uv = UV + vec2(TIME * speed, 0.0);   // ← the line
	COLOR = texture(TEXTURE, fract(uv));      // fract() wraps 1.2 → 0.2
}
