# Fish eating / reproduction sprites — design

Date: 2026-11-22
Topic: fish-eating-reproduction-sprites

## Intent and why

Three readability gaps in the fish lifecycle feedback, all visual:

1. A fish the player sends to eat (or to a nest) gave no clear sign of what it
   had understood.
2. While a fish ate, it still wore the full sprite, so the "head in the algae"
   read wrong.
3. While a fish reproduced, the nest just showed the empty shell, with the fish
   nowhere.

The user asked for concrete sprite swaps; the highlights question was parked.

## Goals

- While a fish is `EATING`, draw the headless body (`assets/sprites/fish_body.png`)
  instead of the full fish, shaken by pivoting on the neck so the tail moves up
  and down while the head is inside the algae.
- While a fish is `FERTILIZING`, hide its own sprite and show the nest art with
  the fish in it (`assets/sprites/nest_fish.png`).
- Both new textures live in `assets/sprites/` (the proper folder; `video/` is
  gitignored).

## Non-goals

- Order / hover highlights: parked, out of scope for this change.
- Gameplay, balance, audio or feature-flag changes.

## Constraints

- `FishVisual` draws in screen space through `SpriteFacing.transform()`, which
  maps body-local → screen. The body textures share the 254x240 canvas of the
  full fish, so the same facing math (and the same neck offset, the tail→head
  axis at half the body length) applies unchanged.
- Godot 4.7 GDScript quirks found while prototyping the neck-pivot rotation:
  `Transform2D(float, Vector2)` and `Transform2D * Transform2D` (matrix product)
  are the composition tools that parse; `Basis.from_axis_angle()`,
  `Transform2D.get_basis()` and quaternion constructors are not available. The
  neck-pivot rotation is therefore built as
  `T * (Translate(neck) * Rotate(angle) * Translate(-neck))`.
- Nest fitting: the new nest art is the same design as `nest_empty.png` (used
  rects 991x614 @ (6,315) vs 256x160 @ (0,0), same proportions, ~3.87x scale), so
  it is cropped to its used rect (991x614) and fitted with a scaled foot row.

## Approaches

1. **Body swap + neck-pivot shake in `FishVisual._draw`** (chosen).
2. **A dedicated "neck stub" sprite layer** (rejected: over-engineering, the
   body texture already stops at the neck).

## Design

### Eating (`FishVisual`)

- `EATING` → draw `BODY_TEXTURE` (`res://assets/sprites/fish_body.png`).
- Shake: rotation about the neck, `angle = sin(_time * SHAKE_SPEED) * SHAKE_AMPLITUDE`,
  composed as `facing * (Translate(neck) * Rotate(angle) * Translate(-neck))`.
  The head stays in the algae, the tail bobs up and down.
- Redraw every frame while eating (the shake is time-based).

### Reproduction (`Fish` + `Nest`)

- `Fish` records the nest it is fertilizing (`_fertilizing_nest`) and publishes
  it as that nest's `breeder`; `FishBrain` clears `nest` on every state change, so
  the fish clears the breeder when leaving `FERTILIZING`.
- `Nest.is_breeding()` is true while its breeder is still valid and still in
  `FERTILIZING` there (same pattern as `Algae.eater` / `Fish.holds(algae)`).
- While breeding, the nest swaps to the fish-in-nest texture; the fish hides its
  own sprite (body, outline, hunger bar) but keeps the action badge.

## What's left to the builder

- Re-run `tools/lint.sh` and `tools/test.sh` and fix everything reported.
- Keep the new behaviour free of warnings/errors before committing.

## Approval

Design accepted as-is (2026-11-22, user decisions: Q1 = A body-over-weed; shake =
neck pivot; highlights parked; focus on sprites).
