# Ideologia Marina

Godot **4.7.2** stable (GDScript, Compatibility renderer) top-down 2D reef-management game for a game jam (theme: "SUBIRE").
The same version is pinned in CI (`GODOT_VERSION` in `.github/workflows/ci.yml`); keep the two in sync when upgrading.
The game design document is `docs/GDD.md`.

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
  expects, then run `tools/test.sh` and `tools/smoke.sh`.

### Git flow

1. **Never implement features directly on `main`.** Start every new feature from an up-to-date `main` on a personal feature branch prefixed with the GitHub username:
   ```sh
   git switch main && git pull origin main
   git switch -c <gh-username>/<feature-name>   # e.g. lorenzopatane/coral-placement
   ```
   (Get the username with `gh api user -q .login`.)
2. Commit the work on the feature branch.
3. **Before merging, bring `main` into the feature branch** to integrate the latest changes and verify everything is stable and safe there:
   ```sh
   git fetch origin
   git merge origin/main          # resolve any conflicts on the feature branch
   ```
   Then check that the project still opens/runs correctly in Godot with no errors before proceeding.
4. Only once the feature branch is verified, merge it into `main` and push:
   ```sh
   git switch main && git pull origin main
   git merge <gh-username>/<feature-name>
   git push origin main
   ```
5. **Never delete feature branches**, even after they have been merged. Keep them for reference.

## Feature flags

Every feature flag must be exposed in the debug overlay (F3, `res://core/debug_overlay.gd`)
so it can be inspected and toggled at runtime. When adding a new feature flag:
1. Add the `@export` flag to the relevant balance resource (`data/balance_*.gd`/`*.tres`).
2. Add a read-only (or toggleable) entry to the "Feature flags" section of `DebugOverlay`.
3. Gate the feature on `Game.actors.<flag>` (or `Game.eco.<flag>`) in the system that uses it.

Current flags: `co2_dies_on_coral`, `predator_enabled`, `turtle_enabled`.
