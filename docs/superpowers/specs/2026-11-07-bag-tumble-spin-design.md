# Plastic bag tumble spin — design

## Intent

The plastic bag should read as a bag caught in a drifting current: its sprite
turns around its own centre, in a randomly chosen direction, with a speed that
wanders — slowing to a near-stop and sometimes reversing. The bag also loses
its ground shadow: it floats in the water, it does not sit on the seabed. The
effect is **purely cosmetic**: it changes nothing about movement, collision,
damage or timing.

## Goals

- The bag is drawn as the sprite alone, with no ground shadow beneath it.
- The bag sprite rotates around the sprite's centre (not around the world).
- Direction and speed feel random and uneven ("tumbling"), not a mechanical
  constant spin.
- Zero gameplay impact: heading, speed, radius, contact rules and destruction
  are untouched.

## Non-goals

- No change to bag movement (`DriftMotion`) or to any other threat. Cyclones
  keep their ground shadow; CO2 clouds already drew their own shadowless nebula
  (`_make_visual()` override) before this work and are untouched.
- No new art; the temporary sprite stays.
- No squash / 3D "edge-on" faking for now — pure in-plane rotation. A mild
  horizontal squash can be added later if the spin reads too much like a wheel.

## Approaches considered

1. **`Tween` on the sprite rotation, restarted with a random direction.**
   Easy, but chained tweens give a sawtooth rhythm (always full turns at
   constant speed) and are awkward to unit test.
2. **Rotate in `Threat._physics_process` with a random constant rate per bag.**
   Cheapest, but constant speed reads as a wheel, not a bag in water, and it
   would touch the gameplay loop for an aesthetic concern.
3. **A small pure-logic "tumble" model, stepped from the visual only.**
   *Chosen.* Mirrors the existing `DriftMotion` pattern (seeded RNG, unit
   tested in `tests/unit/`), keeps the gameplay `_physics_process` untouched,
   and lets the rate wander, stall and reverse.

## Decided by the designer

- Tumbling behaviour (approaches 3): direction and speed wander, occasional
  near-stops and reversals, rather than one fixed direction for a bag's life.

## Calls made by the builder

- Rotation stays in the screen plane on the existing side-on sprite; no squash.
- Peak spin speed is designer-tunable as `bag_spin_speed` (rad/s) in
  `data/balance_actors.gd`, next to the other `bag_*` values. The randomness
  shape (how fast the rate wanders, how often it stalls) stays as readable
  constants inside the model.
- The shadow is removed through a `show_shadow` flag on `Threat` (default
  `true`, so CO2 and cyclone are unaffected), set to `false` by `PlasticBag`.
  No bag gets a shadow again by accident.
- The bag keeps its current `HOVER_PX` lift, so only the shadow disappears and
  the sprite does not jump. The sprite's centre is what spins.
- No debug-overlay entry: this is not a feature flag.

## How it works

- `core/tumble_spin.gd` — `TumbleSpin` (`RefCounted`), seeded:
  - starts at a uniformly random angle with a random sign and a random start
    rate up to `max_speed`;
  - every step the rate is eased toward a random target inside
    `[-max_speed, +max_speed]`, re-rolled every few tenths of a second, so the
    bag speeds up, slows down and sometimes reverses;
  - occasionally the target is near zero, giving the "hangs in the current"
    beat;
  - `step(delta) -> float` returns the new angle; `max_speed <= 0` freezes it.
- `entities/threats/threat.gd` — the floating body is kept as a member and a
  no-op `_animate_body(delta)` hook runs each frame next to the existing
  movement, so subclasses can animate their sprite without touching movement.
  A `show_shadow` flag (default `true`) guards the shadow, and `PlasticBag`
  turns it off.
- `entities/threats/plastic_bag.gd` — creates its `TumbleSpin` from its **own
  randomized RNG**, never from the RNG passed to `setup()`: drawing from that
  one would shift the bag's heading and every later spawn position, which is
  gameplay this effect must not touch. (`TumbleSpin` itself stays deterministic
  when handed a seeded RNG, so tests can pin it.) In `_animate_body` it sets the
  body's `rotation` to the model's angle. `rotation` on the body node pivots
  around the sprite's centre, which is exactly the bag centre.

## Verification

- `tests/unit/test_tumble_spin.gd`: rate stays within ±`max_speed`; both signs
  appear across seeds; the rate passes near zero (stall) and changes sign at
  least once over a long run; same seed reproduces the same angles; zero max
  speed means no rotation.
- `tools/test.sh`, plus a manual look in game: the bag spins slowly and unevenly
  with no shadow under it, while CO2 clouds and cyclones keep theirs.
