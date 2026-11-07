# BalanSea

A real-time, top-down 2D reef-management game made for a game jam (theme: **SUBIRE**, "to endure").

You look after a coral reef. The coral does nothing: it just endures. Your job is to protect it
indirectly by keeping the whole ecosystem in balance:

- too much algae suffocates the coral;
- too many fish eat all the algae;
- too much coral blocks the fish from reaching their food, so they starve;
- meanwhile the water keeps warming up and threats (CO2, plastic bags, cyclones) keep arriving.

Coral, algae, fish and nests are all tracked. If any of them drops to zero, a 10-second countdown
starts; if it runs out, the reef collapses and the game is over. There is no victory: your score is
how long you survive.

The full game design document (in Italian) is in [`docs/GDD.md`](docs/GDD.md).

## Controls

| Input | Action |
| --- | --- |
| Left click | Select a fish, give it an order, confirm a placement |
| Right click / Esc | Cancel placement / deselect |
| Space / Esc | Pause (Esc pauses only when there is nothing to cancel) |
| F3 | Debug overlay (SHOW PATHS draws planned fish/predator/turtle routes) |

## Requirements

- [Godot **4.7.2** stable](https://godotengine.org/download/archive/) (standard build, no .NET needed).
  Other versions may work but are not tested; CI uses exactly 4.7.2.

## Running the game

1. Clone the repository.
2. Open Godot, click **Import**, and select `project.godot` in the repository root.
3. Press **F5** (or the Play button) to run the main scene (`main/main.tscn`).

## Tests

Unit tests use a small custom runner (`tests/run_tests.gd`) and run headless. On macOS, with Godot
installed in `/Applications`:

```sh
tools/test.sh    # run all unit tests in tests/unit/
tools/smoke.sh   # boot the main scene for ~5 s and fail on any script error
tools/audio.sh   # print the resolved audio settings (track, gains, filters, takes)
```

Elsewhere, point the scripts at your Godot binary:

```sh
GODOT=/path/to/godot tools/test.sh
```

To add a test, create `tests/unit/test_<something>.gd` extending `TestCase`; every method whose name
starts with `test_` is run automatically.

CI (GitHub Actions, `.github/workflows/ci.yml`) runs both scripts on every push and pull request.

## Audio

Music and sound effects are tuned from `data/audio_settings.tres` (level in dB, pitch,
low/high-pass filters, per event). To add a new sound, follow [`docs/audio.md`](docs/audio.md).

## Project layout

| Folder | Contents |
| --- | --- |
| `autoload/` | Global singletons (`Game`) |
| `core/` | Pure game logic (grid, algae spread, coral oxygen, fish brain, projection...), unit-tested |
| `data/` | Balance values and settings as `.tres` resources, editable in the Godot inspector |
| `entities/` | Coral, algae, fish and nest scenes/scripts |
| `systems/` | Systems that drive entities (e.g. fish commands) |
| `levels/` | Hand-built levels |
| `main/` | Main scene and bootstrap |
| `tests/` | Test runner and unit tests |
| `tools/` | Shell scripts for tests and smoke test |
| `docs/` | Game design document and implementation plans |

## Contributing

- Work on your own feature branch named `<your-github-username>/<feature-name>` (the prefix is your account, not the
  repository owner's or a teammate's), never directly on `main`.
- Before merging, merge the latest `origin/main` into your branch and check that tests pass and the
  game runs without errors.
- Commit messages and PRs are written in English.

See [`CLAUDE.md`](CLAUDE.md) for the full workflow.
