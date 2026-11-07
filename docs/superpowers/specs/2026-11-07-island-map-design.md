# Island map instead of threat warnings — design

## Goal

Remove the blinking edge warnings for threats. Instead, zoom the camera out so
the playable grid reads as an underwater island surrounded by open seabed; the
player sees threats crossing the seabed before they reach the island.

## Decisions

- **Island shape:** unchanged 20×20 grid (parallelogram on screen). Placement,
  algae, pathfinding and the fish walls stay around the island only.
- **Framing:** fixed camera zoom (`ViewSettings.zoom`, default 0.7). No camera
  controls.
- **Seabed:** `Ground` fills the whole screen with a deep seabed colour and draws
  the island lighter, with an outline. The placement grid is drawn on the
  island only (as today).
- **Threat entry:** threats spawn immediately (no warning delay) on the border
  of the *visible* world area (viewport corners projected back to world space)
  and head straight to a random point inside the island. Drift noise still
  bends CO2 and bags.
- **Threat exit:** a threat is removed once it leaves the visible world area,
  grown by `2 × radius + EXIT_MARGIN`.

## Changes

| File | Change |
|---|---|
| `ui/b_threat_warning.gd` | Delete |
| `data/balance_actors.gd/.tres` | Remove `threat_warning_seconds` |
| `systems/b_threat_spawner.gd` | Spawn on schedule tick, no pending list |
| `core/edge_entry.gd` | `random(rng, visible: PackedVector2Array, island: Rect2)`: point on the visible polygon perimeter (length-weighted), heading to a random island point |
| `autoload/game.gd` | `visible_world_polygon()`: viewport corners → canvas → world |
| `entities/threats/threat.gd` | Alive area = offset visible polygon |
| `data/view_settings.gd/.tres` | Add `zoom` |
| `main/main.gd` | Apply zoom to Camera2D |
| `main/ground.gd` | Full-screen seabed + lighter island with outline |
| `docs/GDD.md` | §7 and roadmap: no warnings, threats visible on the seabed |

## Testing

- Unit tests for `EdgeEntry`: point lies on the visible polygon border, heading
  ray hits the island, same seed → same entry.
- Run the game and check framing, seabed, threats entering from the screen
  edges and reaching the island.
