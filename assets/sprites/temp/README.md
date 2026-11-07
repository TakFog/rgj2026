# Temporary sprites (placeholders for testing only)

Everything in this folder is **temporary** and MUST be replaced with the
designer's sprites as soon as they are ready. Final art lives in
`assets/sprites/` (already done: `fish.png`, `map.png`, `predator.png`, `coral.png`, `coral_base.png`, `nest_empty.png`, `nest_eggs.png`).

| File | Used by | Source |
|------|---------|--------|
| `algae.png` | `entities/algae/algae.gd` | Supplied by the team (stock image) |
| `turtle.png` | `entities/turtle/turtle_visual.gd` | Supplied by the team (stock image) |
| `co2_cloud.svg` | `entities/threats/co2_cloud.gd` | Twemoji ☁️ (U+2601) |
| `cyclone.png` | `entities/threats/cyclone.gd` | Supplied by the team (stock image; baked checkerboard keyed out) |
| `plastic_bag.png` | `entities/threats/plastic_bag.gd` | Supplied by the team (stock image) |

The Twemoji SVG is imported at `svg/scale=4.0` (144 px) so it stays sharp when scaled; PNGs are downscaled to at most 256 px.

## Attribution

Twemoji graphics © Twitter, Inc. and other contributors
(<https://github.com/jdecked/twemoji>), licensed under
[CC-BY 4.0](https://creativecommons.org/licenses/by/4.0/).
