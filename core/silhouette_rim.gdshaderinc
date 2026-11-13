// Rim settings shared by core/sprite_rim.gdshader and the algae sway shader
// (entities/algae/algae_sway.gdshader). Declarations only: a user-defined
// shader function cannot read the built-in TEXTURE sampler, so each shader
// inlines the tap loop over its own UV (the algae warps it with the sway).
//
// The rim is the band just outside the texture's alpha, so a sprite gets a
// coloured border that hugs its art instead of a circle around it.

uniform vec4 rim_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
// Band thickness in texture pixels (scripts scale it to an on-screen width).
// 0 disables the rim, so the same material can sit on a sprite all the time.
uniform float rim_width = 0.0;

// Taps around the silhouette: three rings x sixteen directions fill the band
// with no gaps, whatever the sprite scale or rotation.
const int RING_TAPS = 16;
const int RINGS = 3;
