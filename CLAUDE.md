# BalanSea

Godot [**4.7.2** stable](https://godotengine.org/download/archive/4.7.2-stable/) (GDScript, Compatibility renderer) top-down 2D reef-management game for a game jam (theme: "SUBIRE").
The same version is pinned in CI (`GODOT_VERSION` in `.github/workflows/ci.yml`); keep the two in sync when upgrading.
The game design document is `docs/GDD.md`.

## Audio

- Every sound — music included — is configured through `data/audio_settings.tres` (which music track plays, level in dB, pitch, high/low-pass filters). Never hard-code a volume, pitch or filter in a script. How-to: `docs/audio.md`.
- A new sound needs **both** a take list in `core/audio_events.gd` `AudioEvents.TAKES` (files under `assets/audio/<event>/`) **and** an `AudioEvent` entry in the audio settings. `tests/unit/test_audio_settings.gd` fails if an event is missing from the settings.

## Git

- **Never work on `main`.** Never commit directly to `main`. All work happens on
  a personal feature branch and reaches `main` only through a merge of that
  verified branch.
- Always write commit messages (and PR titles/descriptions) in **English**.

### Project files shared with CI/CD

`project.godot` and `export_presets.cfg` are read by CI (`.github/workflows/ci.yml`)
and CD (`.github/workflows/cd.yml`, which exports the `"Web"` preset, single-threaded,
to `build/web/index.html`). The Godot editor rewrites both with machine-specific
settings, so **never commit local editor changes to them**:

- Never stage `project.godot` or `export_presets.cfg` unless the task is explicitly
  about changing project or export settings. Stage files by explicit path
  (`git add <paths>`), never with `git add -A` / `git add .` / `git commit -a`, and
  check `git diff --cached --stat` before every commit.
- Never commit local-only settings: `[editor]` entries such as `movie_writer/*`
  (absolute paths like `/Users/...`), extra presets (e.g. `macOS`), empty or local
  `export_path` values, or removals of sections other people added (e.g. `[audio]`).
- If one of those files shows up modified or staged without being part of the task,
  leave it alone (do not commit, revert or overwrite it) and tell the user.
- When a change to them *is* intended, keep the `"Web"` preset name, its
  `export_path="build/web/index.html"` and `variant/thread_support=false` as CD
  expects, keep the `"Android"` preset name that CI exports (`docs/android.md`),
  never put keystore paths or passwords in it (CI signs from the
  `ANDROID_KEYSTORE_*` secrets), then run `tools/test.sh` and `tools/smoke.sh`.

## Android

Touch-only behaviour (on-screen Pausa/Annulla, tap-to-preview placement, Back as
Esc) is gated on `Platform.is_touch()`, true only in the Android build. Never
change mouse/keyboard behaviour for it: the web build must stay identical.
Details: `docs/android.md`.

### Git flow

1. **Never implement features directly on `main`.** Start every new feature from an up-to-date `main` on **your own** feature branch, prefixed with **your** GitHub username:
   ```sh
   git switch main && git pull origin main
   git switch -c <your-gh-username>/<feature-name>   # e.g. mjkjkjk/audio
   ```
   The prefix identifies who did the work, so it must be the account you are working as:
   - `gh api user -q .login` when the GitHub CLI is available;
   - otherwise take it from `git config user.email` / `user.name` and **confirm with the user**.
   Never borrow a prefix from the remote URL (e.g. `TakFog/rgj2026` is the repository owner, which is usually not you), from `git branch -r`, or from a branch by someone else.
2. **Before every commit, check Godot for errors and warnings and fix all of them.**
   Run `tools/lint.sh` (loads every GDScript file headless with all warnings
   escalated to errors) and `tools/test.sh`; both must pass with **zero** errors
   and **zero** GDScript warnings. Fix every reported issue — including ones not
   introduced by your change — rather than suppressing it (no new `@warning_ignore`,
   no lowering warning levels in `project.godot`). Never commit while either reports
   a problem.
3. Commit the work on the feature branch.
4. **Before merging, bring `main` into the feature branch** to integrate the latest changes and verify everything is stable and safe there:
   ```sh
   git fetch origin
   git merge origin/main          # resolve any conflicts on the feature branch
   ```
   Then check that the project still opens/runs correctly in Godot with no errors before proceeding.
5. Only once the feature branch is verified, merge it into `main` and push:
   ```sh
   git switch main && git pull origin main
   git merge <your-gh-username>/<feature-name>
   git push origin main
   ```
6. **Never delete feature branches**, even after they have been merged. Keep them for reference.

## Levels

The campaign is three timed levels defined in `levels/level_catalog.gd` (see
`LevelDefinition`). Each level lists its enabled mechanics; `Main._ready` copies
them into the balance flags before the systems start, so systems keep gating on
`Game.actors.*` / `Game.eco.*`. The loaded level is the static
`LevelSession.current_index` (it survives the `reload_current_scene()` used to
switch or retry). `LevelDirector` owns the countdown, the clear screen and
progress saving; a collapse still ends the run and the player retries the same
level. Progress and per-level records live in `user://settings.cfg`
(`UserSettings`).

## Feature flags

Every feature flag must be exposed in the debug overlay (F3, `res://core/debug_overlay.gd`)
so it can be inspected and toggled at runtime. When adding a new feature flag:
1. Add the `@export` flag to the relevant balance resource (`data/balance_*.gd`/`*.tres`).
2. Add a read-only (or toggleable) entry to the "Feature flags" section of `DebugOverlay`.
3. Gate the feature on `Game.actors.<flag>` (or `Game.eco.<flag>`) in the system that uses it.

Current flags: `temperature_enabled`, `co2_enabled`, `bag_enabled`, `cyclone_enabled`,
`co2_dies_on_coral`, `predator_enabled`, `turtle_enabled`.
