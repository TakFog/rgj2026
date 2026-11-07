// Underwater seabed look (Ground and its painted map): teal water tint,
// a network of bright caustic lines on the sand only, uneven depth and a
// darker vignette.
// Web-safe: Compatibility renderer / WebGL2, no screen texture, fixed-size loop.
// Caustics live in the logical (top-down) world, so they lie on the seabed
// slanted like the island and its grid; the vignette is in screen space.
shader_type canvas_item;

// Water colour grade: the art's brightness in this colour, blended by `tint_amount`.
uniform vec3 water_tint : source_color = vec3(0.2, 0.75, 0.85);
uniform float tint_amount : hint_range(0.0, 1.0) = 0.3;
// Canvas → logical world (inverse view projection, columns), set by Ground.
uniform vec2 to_world_x = vec2(1.0, 0.0);
uniform vec2 to_world_y = vec2(0.0, 1.0);
// Caustic light network: tile size (world units), speed, line brightness.
uniform vec3 caustic_color : source_color = vec3(0.85, 1.0, 1.0);
uniform float caustic_scale = 260.0;
uniform float caustic_speed = 0.3;
uniform float caustic_strength : hint_range(0.0, 2.0) = 0.45;
// Sand detection in the map art (red minus blue): caustics fade in across this range.
uniform vec2 sand_threshold = vec2(0.1, 0.35);
// Large dark/light patches, like uneven depth (canvas px).
uniform float depth_scale = 600.0;
uniform float depth_strength : hint_range(0.0, 1.0) = 0.15;
// Darkening towards the screen edges, strongest at the bottom corners.
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.55;
// Refraction wobble of the texture (texture px).
uniform float wobble_pixels = 2.5;
uniform float wobble_speed = 0.8;
// Fraction of the texture width/height (per side) faded to transparent.
// Zero disables the fade (used by the untextured seabed fill).
uniform vec2 edge_fade = vec2(0.0);

varying vec2 world_pos;
varying vec4 tint;


void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	tint = COLOR;
}


float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}


float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}


// Tileable water caustics (iterated sin/cos distortion): thin bright lines, in [0, 1].
float caustics(vec2 pos, float t) {
	vec2 p = mod(pos / caustic_scale * TAU, TAU) - 250.0;
	vec2 i = p;
	float c = 1.0;
	const float intensity = 0.005;
	for (int n = 0; n < 4; n++) {
		float tn = t * (1.0 - 3.5 / float(n + 1));
		i = p + vec2(cos(tn - i.x) + sin(tn + i.y), sin(tn - i.y) + cos(tn + i.x));
		c += 1.0 / length(vec2(p.x / (sin(i.x + tn) / intensity), p.y / (cos(i.y + tn) / intensity)));
	}
	c /= 4.0;
	c = 1.17 - pow(c, 1.4);
	return clamp(pow(abs(c), 10.0), 0.0, 1.0);
}


void fragment() {
	vec2 wobble = vec2(sin(world_pos.y * 0.035 + TIME * wobble_speed),
		cos(world_pos.x * 0.03 + TIME * wobble_speed * 1.3)) * wobble_pixels * TEXTURE_PIXEL_SIZE;
	vec2 uv = clamp(UV + wobble, vec2(0.0), vec2(1.0));
	vec4 color = texture(TEXTURE, uv) * tint;
	float sand = smoothstep(sand_threshold.x, sand_threshold.y, color.r - color.b);

	// Tint by brightness (not hue), so warm sand stays sandy instead of turning green.
	float luma = dot(color.rgb, vec3(0.299, 0.587, 0.114));
	color.rgb = mix(color.rgb, luma * water_tint * 1.3, tint_amount);

	float depth = value_noise(world_pos / depth_scale + vec2(TIME * 0.02, 0.0));
	color.rgb *= 1.0 - depth_strength * depth;

	vec2 seabed_pos = mat2(to_world_x, to_world_y) * world_pos;
	float light = caustics(seabed_pos, TIME * caustic_speed + 23.0);
	color.rgb += caustic_color * light * caustic_strength * sand;

	vec2 from_top = (SCREEN_UV - vec2(0.5, 0.0)) * vec2(1.0, 0.8);
	color.rgb *= 1.0 - vignette_strength * smoothstep(0.35, 1.0, length(from_top));

	if (edge_fade.x > 0.0 && edge_fade.y > 0.0) {
		vec2 edge = min(UV, 1.0 - UV) / edge_fade;
		color.a *= smoothstep(0.0, 1.0, clamp(min(edge.x, edge.y), 0.0, 1.0));
	}
	COLOR = color;
}
