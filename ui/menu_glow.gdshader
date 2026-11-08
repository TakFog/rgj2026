shader_type canvas_item;
render_mode blend_add;

// One painted menu pill, redrawn additively to brighten it on hover/focus.
// The glow is a rect covering the hotspot; the shader samples the matching
// part of the painting and clips it to the pill so no rectangle shows.
uniform vec2 region_position = vec2(0.0); // top-left of the hotspot in the painting (0..1)
uniform vec2 region_size = vec2(1.0); // size of the hotspot in the painting (0..1)
// The pill's corners in the glow's rect: top-left, top-right, bottom-right,
// bottom-left.
uniform vec2 top_left = vec2(0.0, 0.0);
uniform vec2 top_right = vec2(1.0, 0.0);
uniform vec2 bottom_right = vec2(1.0, 1.0);
uniform vec2 bottom_left = vec2(0.0, 1.0);
// How much the pill brightens; the menu raises it while the button is held.
uniform float intensity : hint_range(0.0, 1.0) = 0.22;

void fragment() {
	float left = mix(top_left.x, bottom_left.x, UV.y);
	float right = mix(top_right.x, bottom_right.x, UV.y);
	// Soften the slanted edges by roughly one pixel.
	vec2 aa = fwidth(UV) * 1.5;
	float fill = smoothstep(left - aa.x, left + aa.x, UV.x)
			* (1.0 - smoothstep(right - aa.x, right + aa.x, UV.x))
			* smoothstep(-aa.y, aa.y, UV.y)
			* (1.0 - smoothstep(1.0 - aa.y, 1.0 + aa.y, UV.y));
	vec4 tex = texture(TEXTURE, region_position + UV * region_size);
	COLOR = vec4(tex.rgb, tex.a * fill * intensity);
}
