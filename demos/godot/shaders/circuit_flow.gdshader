// CIRCUIT FLOW — scroll_uv's sibling, with the phase accumulated in script.
// scroll_uv.gdshader advances by TIME * speed, so changing `speed` mid-run
// makes the pattern SKIP (TIME is global and already huge). Here the script
// integrates phase += speed * delta every frame and hands us the result —
// now speed can be tweened (surges! reversals!) and the dashes never jump.
// Companion: cheatsheets/godot-flipbook-vfx.md §4.5. Chapters 04, 06, 12.
shader_type canvas_item;

uniform float flow_phase = 0.0;   // set from flipbook_vfx.gd, every frame

void fragment() {
	vec2 uv = UV - vec2(flow_phase, 0.0);
	COLOR = texture(TEXTURE, fract(uv)) * COLOR;   // keep Line2D's colour & modulate
}
