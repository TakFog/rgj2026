# Ideologia Marina

Godot **4.7.2** stable (GDScript, Compatibility renderer) top-down 2D reef-management game for a game jam (theme: "SUBIRE").
The same version is pinned in CI (`GODOT_VERSION` in `.github/workflows/ci.yml`); keep the two in sync when upgrading.
The game design document is `docs/GDD.md`.

## Git

- Always write commit messages (and PR titles/descriptions) in **English**.

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

Current flags: `co2_dies_on_coral`, `predator_enabled`.
