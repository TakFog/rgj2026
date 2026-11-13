shader_type canvas_item;
// Rim along a sprite's silhouette: keeps the art unchanged and paints a
// coloured band just outside the texture's alpha. Used by the selected fish
// (on a copy of its sprite placed behind the body) and by the algae and nest
// under the pointer of a selected fish (on the item's own sprite, with
// `rim_width` 0 while it is not highlighted).
//
// The fragment COLOR already holds the texture times the sprite modulate, so
// it must be left alone: sampling the texture into it again would darken the
// sprite (it would be multiplied by itself). Only the rim is written.
//
// Kept in sync with the same loop in entities/algae/algae_sway.gdshader, which
// samples it from the swayed UV.

#include "res://core/silhouette_rim.gdshaderinc"

void fragment() {
	if (rim_width > 0.0) {
		float own = texture(TEXTURE, UV).a;
		float neighbour = 0.0;
		for (int ring = 1; ring <= RINGS; ring++) {
			float radius = rim_width * float(ring) / float(RINGS);
			for (int tap = 0; tap < RING_TAPS; tap++) {
				float angle = TAU * float(tap) / float(RING_TAPS);
				vec2 offset = vec2(cos(angle), sin(angle)) * TEXTURE_PIXEL_SIZE * radius;
				neighbour = max(neighbour, texture(TEXTURE, UV + offset).a);
			}
		}
		// Outward only: the body itself keeps the sprite's own colours.
		COLOR = mix(COLOR, vec4(rim_color.rgb, rim_color.a), clamp(neighbour - own, 0.0, 1.0));
	}
}
