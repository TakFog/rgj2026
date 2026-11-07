shader_type canvas_item;
// Gentle underwater sway for the algae sprite.
//
// The sprite is a single quad, so the movement is a fragment-space UV warp
// instead of a vertex deformation: the upper part of the plant drifts
// horizontally while the base (the sand patch it grows from) stays put.
// `phase` is set per algae so neighbouring plants do not move in lockstep.
// Web-safe: Compatibility renderer / WebGL2, no screen texture.

// Horizontal displacement at the tip, as a fraction of the texture width.
uniform float sway_strength : hint_range(0.0, 0.08) = 0.025;
uniform float sway_speed : hint_range(0.0, 4.0) = 1.1;
// Vertical frequency: how many waves run from the roots to the tips.
uniform float sway_frequency : hint_range(0.0, 20.0) = 4.5;
// Horizontal frequency: ripples across the clump, so single fronds differ.
uniform float ripple_frequency : hint_range(0.0, 40.0) = 9.0;
// Bottom fraction of the sprite that is rooted and never moves.
uniform float base_height : hint_range(0.0, 1.0) = 0.4;
// Per-instance offset (radians) so the algae sway independently.
uniform float phase = 0.0;


void fragment() {
	float anchor = 1.0 - base_height;
	float height = clamp((anchor - UV.y) / max(anchor, 0.001), 0.0, 1.0);
	// Quadratic falloff: the roots barely move, the tips swing the most.
	height *= height;

	float wave = sin(TIME * sway_speed + phase + UV.y * sway_frequency + UV.x * ripple_frequency);
	float ripple = sin(TIME * sway_speed * 0.63 + phase * 1.7 + UV.y * sway_frequency * 0.6);
	float offset = (wave * 0.7 + ripple * 0.3) * sway_strength * height;

	vec2 uv = UV;
	uv.x = clamp(uv.x + offset, 0.0, 1.0);
	COLOR = texture(TEXTURE, uv) * COLOR;
}