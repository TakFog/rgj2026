shader_type canvas_item;
// Gentle underwater sway for the algae sprite.
//
// Two layers, both driven by TIME:
//  * `vertex()` leans the whole plant from its rooted base (the quad's top
//    corners move while the bottom edge stays put);
//  * `fragment()` warps the UVs so single fronds ripple against each other.
// The phase comes from the sprite's canvas position, so neighbouring plants
// do not move in lockstep while all algae share one material (batching).
// Web-safe: Compatibility renderer / WebGL2, no screen texture.

// Whole-plant lean at the tip, as a fraction of the texture width.
uniform float lean_strength : hint_range(0.0, 0.2) = 0.1;
// Per-frond ripple at the tip, as a fraction of the texture width.
uniform float sway_strength : hint_range(0.0, 0.12) = 0.04;
uniform float sway_speed : hint_range(0.0, 4.0) = 1.5;
// Vertical frequency: how many waves run from the roots to the tips.
uniform float sway_frequency : hint_range(0.0, 20.0) = 4.5;
// Horizontal frequency: ripples across the clump, so single fronds differ.
uniform float ripple_frequency : hint_range(0.0, 40.0) = 9.0;
// Bottom fraction of the sprite that is rooted and never moves.
uniform float base_height : hint_range(0.0, 1.0) = 0.4;
// Phase (radians) per screen pixel of the sprite's position: about 0.73 rad
// per cell along x and 1.21 rad per cell along y with the default view.
uniform vec2 phase_per_pixel = vec2(0.018, 0.079);
// Extra offset (radians) for a material that is not shared (e.g. the tutorial).
uniform float phase = 0.0;

varying float position_phase;


// 0 at the rooted base, 1 at the tips.
float tip_weight(vec2 uv) {
	float anchor = 1.0 - base_height;
	float height = clamp((anchor - uv.y) / max(anchor, 0.001), 0.0, 1.0);
	return height * height;
}


void vertex() {
	position_phase = phase + dot(MODEL_MATRIX[3].xy, phase_per_pixel);
	float lean = sin(TIME * sway_speed + position_phase);
	VERTEX.x += lean * lean_strength * tip_weight(UV) / TEXTURE_PIXEL_SIZE.x;
}


void fragment() {
	float height = tip_weight(UV);
	float wave = sin(TIME * sway_speed + position_phase + UV.y * sway_frequency + UV.x * ripple_frequency);
	float ripple = sin(TIME * sway_speed * 0.63 + position_phase * 1.7 + UV.y * sway_frequency * 0.6);
	float offset = (wave * 0.7 + ripple * 0.3) * sway_strength * height;

	vec2 uv = UV;
	uv.x = clamp(uv.x + offset, 0.0, 1.0);
	COLOR = texture(TEXTURE, uv) * COLOR;
}