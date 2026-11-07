shader_type canvas_item;
// Swirling water funnel for the cyclone sprite.
//
// The stock funnel is a still image; this shader makes it move:
//  * `fragment()` shears the UVs around the centre into a spiral (inner rings
//    rotate faster than the rim), so the funnel appears to spin and flow;
//  * rising bands and fbm foam add churning water and whitecaps;
//  * the silhouette is eroded with the same noise, so the edge boils like
//    spray instead of reading as a cut-out PNG.
// Web-safe: Compatibility renderer / WebGL2, no screen texture.

// How strongly the art is sheared into a spiral (radians at the centre).
uniform float swirl : hint_range(0.0, 8.0) = 1.4;
// Rotations per second of the whole vortex.
uniform float spin_speed : hint_range(0.0, 6.0) = 1.4;
// Rising water rings.
uniform float band_count : hint_range(0.0, 40.0) = 14.0;
uniform float band_speed : hint_range(0.0, 8.0) = 2.0;
uniform float band_strength : hint_range(0.0, 1.0) = 0.14;
uniform vec3 band_color : source_color = vec3(0.35, 0.62, 0.75);
// Whitecap foam flecks.
uniform float foam_strength : hint_range(0.0, 1.0) = 0.65;
uniform vec3 foam_color : source_color = vec3(0.82, 0.95, 1.0);
// Boiling silhouette (0 = clean cut-out).
uniform float edge_noise : hint_range(0.0, 0.6) = 0.07;
// Rim light and deep core.
uniform vec3 rim_color : source_color = vec3(0.6, 0.9, 1.0);
uniform float rim_strength : hint_range(0.0, 1.0) = 0.3;
uniform float core_darkening : hint_range(0.0, 1.0) = 0.18;
// Swirl axis in UV space, set from the sprite's visible content (not always 0.5).
uniform vec2 pivot = vec2(0.5, 0.5);
// Per-instance offset so two cyclones do not spin in lockstep.
uniform float phase = 0.0;


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


float fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 3; i++) {
		value += amplitude * value_noise(p);
		p *= 2.0;
		amplitude *= 0.5;
	}
	return value;
}


void fragment() {
	// Keep the original silhouette: the funnel must stay upright and readable.
	// Only the water inside it is swirled, so the tip and crest never drift off.
	vec4 base = texture(TEXTURE, UV);
	vec2 c = UV - pivot;
	float r = clamp(length(c) * 2.0, 0.0, 1.0);

	// Inner rings rotate faster than the rim.
	float falloff = 1.0 - smoothstep(0.0, 0.9, r);
	float angle = TIME * spin_speed + falloff * swirl + phase;
	mat2 rot = mat2(vec2(cos(angle), -sin(angle)), vec2(sin(angle), cos(angle)));
	vec2 uv = clamp(rot * c + pivot, vec2(0.0), vec2(1.0));
	vec4 swirled = texture(TEXTURE, uv);

	// Fill the funnel with the swirling water, falling back to the base colour
	// wherever the rotated sample lands outside the art.
	vec3 color = mix(base.rgb, swirled.rgb, swirled.a * 0.9);

	// Rising water rings.
	float bands = sin(UV.y * band_count - TIME * band_speed + phase);
	color += band_color * max(bands, 0.0) * band_strength * base.a;

	// Turbulent whitecap flecks.
	float n = fbm(UV * 5.0 + vec2(0.0, -TIME * 0.8) + phase);
	color += foam_color * smoothstep(0.58, 0.88, n) * foam_strength * base.a;

	// Boundary band: a bright rim and a gentle boil, without eating thin tips.
	float edge = smoothstep(0.0, 0.3, base.a) * (1.0 - smoothstep(0.45, 1.0, base.a));
	float alpha = base.a * (1.0 - edge_noise * edge * (1.0 - n));
	color += rim_color * edge * rim_strength;

	// Deeper core (fake volume).
	color = mix(color, color * vec3(0.55, 0.8, 0.95), (1.0 - r) * core_darkening);

	COLOR = vec4(color, alpha) * COLOR;
}
