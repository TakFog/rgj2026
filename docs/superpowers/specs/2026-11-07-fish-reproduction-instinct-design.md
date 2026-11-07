# Fish reproduction instinct — design

## Intent and why

Today an adult fish reproduces only when the player orders it onto an empty nest.
It should also show a reproduction instinct on its own: when it is well fed, an
empty nest is nearby, and it has not reproduced for a while, it swims there and
lays eggs.

This makes the reef feel alive and lets the player focus on feeding and
protecting fish instead of micromanaging nests. Feeding stays meaningful because
a hungry fish always prioritizes food.

## Goals

- Adult, not-hungry, wandering fish autonomously seek and fertilize a nearby
  empty nest.
- The reproduction cooldown is at least **twice the nest hatching time**.
- Player orders still override the instinct.
- All numbers are tunable in `data/balance_actors.gd` / `.tres`.

## Non-goals

- No change to nest hatching, egg mortality, or the number of juveniles.
- No change to player-ordered reproduction (`ORDERED` onto a nest).
- No new feature flag: this is normal fish behaviour, not a toggleable threat.

## Constraints

- `FishBrain` stays a pure, unit-testable rules class. The `Fish` node keeps
  owning movement, sensing and pathfinding.
- Routes go around corals/algae with `ReefPathfinder`; nests are not obstacles.
- The debug overlay (F3) already prints the fish state, so the new state is
  visible there without extra work.
- GDD §5.4 must stop saying that a wandering fish never fertilizes.

## Approaches

1. **Dedicated `SEEKING_NEST` state in `FishBrain` (chosen).** It mirrors
   `SEEKING_FOOD`: explicit trigger, explicit abort/lost handling, and a state
   name the debug overlay can show.
2. **Reuse `ORDERED` internally.** Rejected: orders override autonomous drives by
   design, so a hungry fish would stop eating, and the behaviour would be
   indistinguishable from a player order in F3.
3. **Nests recruit nearby fish through a signal.** Rejected: it couples nests to
   fish behaviour, has no per-fish cooldown or priority, and is harder to unit
   test.

## Design

### FishBrain

- New state `SEEKING_NEST`; the target nest is stored in the existing `nest`
  field (as `FERTILIZING` does). The fish has `wants_to_move()` while seeking.
- `wants_to_seek_nest()` is true when the fish:
  - is not dead, is an adult, and is in `WANDER`;
  - has hunger ratio below `seek_food_threshold` (the existing 50 % "not
    hungry" line);
  - has finished both the reproduction cooldown and the nest-seek retry delay.
- `seek_nest(nest)` enters `SEEKING_NEST` and sets the target.
- `nest_reached(empty_nest)`: if the target nest is still valid and empty,
  enter `FERTILIZING`; otherwise behave like `nest_lost()`.
- `nest_lost()` now also handles `SEEKING_NEST`: back to `WANDER` and wait
  `seek_retry_seconds` before looking again, so an unreachable nest is not
  re-pathfound every frame.
- When `FERTILIZING` finishes, the reproduction cooldown restarts. A cancelled
  fertilization (player order, nest lost) does **not** restart it.
- The cooldown starts at its full value when the brain is created, so fish wait
  before their first autonomous reproduction.
- The brain receives the already-clamped cooldown from the `Fish` node. The
  effective value is
  `max(reproduce_cooldown_seconds, 2 × nest_hatch_seconds)`; with the defaults
  that is `max(40, 2 × 20) = 40 s`.
- Hunger wins: while `SEEKING_NEST`, reaching `seek_food_threshold` abandons
  the nest (`nest_lost()`), and the normal `WANDER → SEEKING_FOOD` flow takes
  over on the next frame.

### Fish node

- In `WANDER`, after the food check, call `wants_to_seek_nest()` and search for
  the nearest reachable empty nest within `reproduce_nest_radius`.
- Search uses `ReefPathfinder.nearest_occupant()` extended with an optional
  maximum straight-line distance, so the fish only notices nearby nests while
  still choosing the nearest one by path length.
- If no nest is found, record the retry delay and keep wandering.
- `SEEKING_NEST` follows its route like `SEEKING_FOOD`; on an unexpected
  obstacle it re-plans toward the nest, and after the last re-plan it gives up
  and wanders.
- At the end of the route, query the nest under the fish and call
  `nest_reached()`. If the target disappeared or another fish fertilized it en
  route, `_check_targets_still_exist()` calls `nest_lost()`.
- A player order still cancels everything through the existing `order()` path.

### Balance

New exports in `BalanceActors`:

- `reproduce_cooldown_seconds := 40.0` — minimum 2 × `nest_hatch_seconds`;
  clamped at runtime so a designer can never set it below that.
- `reproduce_nest_radius := 128.0` — 4 cells: how close an empty nest must be
  for the fish to notice it on its own.

Retry delay reuses the existing `seek_retry_seconds` (1 s).

## What is left to the builder

- Exact test cases and wording in the GDD.
- Whether to add a dedicated pathfinder test for the distance limit (recommended,
  since it is a shared core API change).
