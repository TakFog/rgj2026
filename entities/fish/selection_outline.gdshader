shader_type canvas_item;
// Selection rim for a fish: draws only the band just outside the sprite's
// silhouette, so the highlight hugs the art instead of disappearing behind it
// (the old circle on the seabed was entirely covered by the body).
// FishVisual puts this on a copy of the fish sprite drawn behind the body and
// scales `rim_width` with the sprite, so the rim keeps one on-screen width.

uniform vec4 rim_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
// Rim thickness in texture pixels (the script scales it, not the shader).
uniform float rim_width = 10.0;
// 0..1 breathing raised by the script: it brightens the rim, never moves it.
uniform float pulse = 0.0;

// Taps around the silhouette: three rings x sixteen directions fill the band
// with no gaps, whatever the heading the sprite is mirrored or tilted to.
const int RING_TAPS = 16;
const int RINGS = 3;

void fragment() {
	float own = texture(TEXTURE, UV).a;
	vec2 pixel = TEXTURE_PIXEL_SIZE;
	float neighbour = 0.0;
	for (int ring = 1; ring <= RINGS; ring++) {
		float radius = rim_width * float(ring) / float(RINGS);
		for (int tap = 0; tap < RING_TAPS; tap++) {
			float angle = TAU * float(tap) / float(RING_TAPS);
			vec2 offset = vec2(cos(angle), sin(angle)) * pixel * radius;
			neighbour = max(neighbour, texture(TEXTURE, UV + offset).a);
		}
	}
	// Outward only: the body itself keeps the sprite's own colours.
	float rim = clamp(neighbour - own, 0.0, 1.0);
	COLOR = vec4(rim_color.rgb, rim * rim_color.a * mix(0.72, 1.0, pulse));
}
