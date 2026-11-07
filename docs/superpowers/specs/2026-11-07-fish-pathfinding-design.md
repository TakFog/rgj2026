# Fish pathfinding and autonomous feeding — design

## Goal
1. Ordered fish plan a route around corals/algae instead of swimming straight and stopping at the first obstacle.
2. Hungry wandering fish automatically go eat the nearest reachable algae.

## Pathfinding — `core/reef_pathfinder.gd` (pure, unit tested)
- Wraps `AStarGrid2D` over `GridModel`. Rebuilt on every query (20×20 grid, cheap; never out of sync).
- Solidity comes from an injected predicate on the grid occupant. In game: everything except `Nest` is solid (nests are Area2D, fish swim over them).
- Diagonal steps only when both side cells are free (`DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES`), so fish never clip corners.
- `find_path(from, to)`: waypoints at cell centres, ending at the exact `to`. If the goal cell is solid or sealed off, the route goes to the closest reachable cell, then the last segment aims at `to` — the fish touches the obstacle and the existing collision rules apply (algae → eat, anything else → idle).
- `nearest_occupant(from, predicate)`: BFS over free cells (4-neighbours); the first free cell touching a matching occupant is the nearest by path length. Returns `{occupant, path}` (path ends at the occupant's centre) or `{}` if none is reachable.

## Fish rules — `FishBrain`
- New state `SEEKING_FOOD` (target algae in `food`).
- `wants_to_seek_food()`: WANDER, hunger ratio ≥ `seek_food_threshold` (0.5, same as the hunger bar), retry cooldown elapsed.
- `seek_food(algae)` / `seek_failed()` (no reachable algae → retry after `seek_retry_seconds` = 1 s).
- `blocked_by_algae` works while ORDERED or SEEKING_FOOD → EATING.
- `blocked_by_other` while SEEKING_FOOD → WANDER with retry cooldown (ORDERED → IDLE, unchanged).
- `food_lost` while SEEKING_FOOD → WANDER (target eaten by another fish / cyclone).
- Player orders always override seeking.

## Fish node
- ORDERED and SEEKING_FOOD follow the waypoint list.
- Blocked by coral/wall mid-route: re-plan once; blocked again → `blocked_by_other`.
- Path exhausted: ORDERED → `arrived(nest)`; SEEKING_FOOD → `food_lost`.
- WANDER is unchanged (random).

## GDD
§5.4 updated: orders follow a route; hungry fish seek food on their own.
