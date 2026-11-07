# Ideologia Marina

Godot 4 (GDScript, Compatibility renderer) top-down 2D reef-management game for a game jam (theme: "SUBIRE").
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
