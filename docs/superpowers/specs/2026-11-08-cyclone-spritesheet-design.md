# Cyclone spritesheet — design

## Intent

Replace the cyclone's temporary still art and the shader that fakes its
rotation with the supplied 9-frame spritesheet, so the cyclone animates from
real frames. Gameplay, collision and balance stay untouched.

## Goals

- The cyclone in the reef and in the tutorial stage plays the 9-frame loop.
- The art is web-safe: a texture width every WebGL2 device can upload.
- The cyclone tutorial icon still shows a single, readable frame.

## Non-goals

- Changing the cyclone's radius, speed, spawn schedule, audio or interactions.
- Changing any other threat, entity or the view projection.
- Merging the work into `main` (the user asked to leave the branch unmerged).

## Constraints

- Source: `video/Vortice_Spritesheet.png`, 9216×1024, 9 square 1024×1024
  frames, transparent background. `/video` is gitignored, so the art must be
  copied into the project.
- Final art lives in `assets/sprites/`; `assets/sprites/temp/` is placeholders.
- WebGL2 only guarantees a 4096 px maximum texture width; the cyclone is
  ~100 px tall on a 1280×720 viewport (radius 40, ppu 1.25, zoom 0.8).
- The project's PNG convention downscales art to roughly 256 px where the
  on-screen size allows it.

## Approaches

- **A (chosen): 9-frame `Sprite2D`, 256 px per frame, no shader.** Downscale
  the sheet to 2304×256, set `hframes = 9` and advance `frame` from
  `_process`. Keeps the existing shadow, seabed spiral and spray, but drops
  `cyclone_swirl.gdshader` (a UV swirl would sample neighbouring frames).
  2304 px is inside the WebGL2 limit and 256 px per frame is ~2× the
  on-screen height.
- **B: keep the full 9216 px sheet.** Sharper but a ~37 MB texture, and the
  width exceeds what some WebGL2/mobile devices guarantee. Not worth it at
  this on-screen size.
- **C: use one frame with the current shader.** Ignores the supplied
  animation and keeps the artificial swirl the new art replaces.

## Design

- `assets/sprites/cyclone.png`: the sheet downscaled to 2304×256 with
  Lanczos, alpha preserved. `assets/sprites/temp/cyclone.png` and its
  `.import` are removed and the temp README loses its row.
- `Cyclone.TEXTURE` points at the final sheet.
- `CycloneVisual` owns the animation: it derives the frame count from the
  square frames (`width / height`), sets `hframes`, and advances the frame
  at 9 fps from a random per-instance offset so two cyclones do not spin in
  lockstep. The sprite is anchored by the union of all frames' visible
  content, not per-frame bounds, so the funnel does not jitter vertically.
  The bob, breathe, shadow, seabed spiral and spray stay.
- `cyclone_swirl.gdshader` is deleted.
- `TutorialIcons` returns an `AtlasTexture` cropping one frame (frame 3, the
  most readable) for the `cyclone` chip; the tutorial stage keeps building
  the live `CycloneVisual`.
- Tests that asserted the swirl shader now assert the animated sheet; a new
  test pins the icon to a single frame.

## Left to the builder

- Exact frame rate (9 fps is a starting choice; tune by eye).
- Whether the spray should stay after seeing it in motion.
