# UI font: Archivo (Britannic Bold lookalike) everywhere

## Intent

BalanSea should render all of its text in one display typeface. Britannic
Bold is a commercial Monotype face that is neither in the repository nor on
the machine that builds it, so we ship **Archivo** (SIL OFL) as the closest
free lookalike: the same heavy, wide grotesque proportions, available from
Google Fonts.

## Goals

- Every rendered string uses the same face: `Label`s, `Button`s, tooltips,
  the F3 debug overlay, the trailer captions, and custom-drawn text
  (inventory cards, thermometer, fish hunger warning).
- One source of truth: a single project theme provides `default_font`, with
  no per-node font overrides.
- Full glyph coverage for the UI's Italian copy and symbols:
  `è é Ì ° ₂ · − — →`.
- The web export embeds the font; no reliance on system fonts.

## Non-goals

- Changing type sizes, colours, layout or wording.
- Shipping Britannic Bold itself.
- A font picker or a settings option.

## Constraints

- Godot 4.7.2, Compatibility renderer; CD exports the `"Web"` preset,
  single-threaded.
- `project.godot` has local editor-only changes right now (`[editor]
  movie_writer`, an audio latency line). Only the new `[gui]` line may be
  staged; the rest stays uncommitted.
- `tools/lint.sh` and `tools/test.sh` must pass with zero warnings/errors.

## Approaches

1. **Project-wide Theme resource via `gui/theme/custom` (chosen).** The
   canonical Godot route: one resource, applied to every `Control`, visible
   in scene previews, inherited by controls created later.
2. **An autoload assigns `get_tree().root.theme` at startup.** Avoids the
   project setting, but it is implicit, invisible in the editor, and code
   paths that run without the autoload (tests, isolated scenes) silently
   miss the font. Rejected.
3. **A theme on each scene root.** Duplicates the reference across every
   scene and misses future ones. Rejected.

## Decisions

- **Font:** Google Fonts `Archivo[wdth,wght].ttf` (variable, OFL), wrapped
  in a `FontVariation` with `wght = 900` — the Archivo Black cut. The axis
  is set under its numeric OpenType tag (`2003265652`), not the string key
  `"wght"`: Godot 4.7 resolves variants by `TextServer.tag_to_name()`
  (`"weight"`), so `"wght"` is silently ignored and leaves the font at its
  default SemiBold 600. The static
  `ArchivoBlack-Regular.ttf` was rejected because it lacks U+2082 `₂`
  (used by the tutorial's `CO₂`); the variable family has every glyph the
  UI needs, so no separate fallback font is shipped.
- **One theme:** `res://ui/ui_theme.tres` (`Theme`) whose `default_font` is
  that `FontVariation`. `project.godot` gains
  `[gui] theme/custom="res://ui/ui_theme.tres"`.
- **Custom-drawn text:** `get_theme_default_font()` resolves through the
  project theme; `entities/fish/fish_visual.gd`, which currently reaches for
  `ThemeDB.fallback_font`, resolves the project font with the engine
  fallback only if the theme is unset.
- **Licence:** ship the Archivo `OFL.txt` beside the font in
  `assets/fonts/`.

## What is left to the builder

- Verify headless that `get_theme_default_font()` returns the project font;
  add a small helper only if it does not.
- Add a unit test: the project theme's default font is the Archivo variable
  font, a `Label` inherits it, and the font has `₂`.
- Run `tools/lint.sh` + `tools/test.sh`, and `tools/smoke.sh` because
  `project.godot` changes.
