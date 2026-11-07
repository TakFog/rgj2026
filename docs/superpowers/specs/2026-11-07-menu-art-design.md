# Painted title screen (`video/MENU.png`) — design

## Intent

The title screen currently draws the `assets/ui/logo.png` wordmark plus five
`SeaStyle` text buttons built in code. The artist delivered a finished menu
painting (`video/MENU.png`, 5699×3341): the reef illustration on the left and
five **painted** buttons on the right — INIZIA, COME SI GIOCA, IMPOSTAZIONI,
ESCI, CREDITI. The title screen should become that painting, with the painted
buttons acting as the real buttons, so the shipped menu matches the art.

Why: the jam build is judged on its first screen; two competing button styles
(painted shapes plus code-drawn cards) look unfinished.

## Goals

- The title screen is the painting, dead centre, and clicking any painted
  button does what the matching code button does today.
- Keyboard/gamepad players can still start and navigate the menu.
- Nothing about the front-end flow changes: `play_requested`,
  `tutorial_requested`, `play_pressed`, `exit_pressed`, `button_pressed`,
  settings panel, credits panel, `--smoke-play`, `restart_run`.
- The menu keeps working at any window size, including CI's headless smoke run
  and the CD web export.

## Non-goals

- No change to the settings panel, credits panel, tutorial screen or HUD.
- No change to audio (button clicks keep firing `button_pressed`).
- No new menu entries: the art has exactly the five actions the code has.

## Anti-goals

- Labels appearing twice (painted name plus a text button on top).
- Hotspots drifting off the painted shapes when the window is resized.
- Shipping the 15 MB / 5699 px master to the web build.

## Approaches considered

1. **Transparent hotspots over the painted buttons (chosen).** The painting is the
   whole screen; five invisible `Button`s are placed at fraction coordinates of
   the art rectangle. Cheap, exact, no art editing. Hover/focus feedback is
   drawn by code (wash + outline).
2. Keep the code-drawn text buttons on top of the painting. No alignment work,
   but every label is duplicated — rejected.
3. Slice the PNG into five textures and use `TextureButton` hover/pressed art.
   Best-looking feedback, but needs image editing and an atlas, too slow for
   the jam — rejected for now; hotspots keep the door open for it later.

## Design

- **Asset.** A copy of the art lives at `assets/ui/menu.png`, scaled to 2048 px
  wide (2048×1201, same 1.705:1 ratio) with mipmaps enabled, so the web build
  and VRAM stay reasonable. `video/MENU.png` stays as the master.
- **Layout.** `MainMenuScreen` (still a full-rect `ColorRect`, opaque deep-sea
  colour for the letterbox bars) owns an "Art" `Control` that fits the painting
  *contain*: same aspect ratio, centred, recomputed on every `resized`. The
  painting is a `TextureRect` filling that box; the five hotspots are its
  children positioned as fractions, so they scale with it.
- **Hotspots.** Invisible `Button`s (no theme, no text) with a pointer cursor.
  Hover brightens the painted shape with a translucent white wash (invisible on
  the white background, so only the shape lights up); pressed deepens it;
  keyboard focus draws an aqua outline. Focus order: INIZIA → COME SI GIOCA →
  IMPOSTAZIONI → CREDITI → ESCI, INIZIA focused when the menu opens.
- **Web build.** `OS.has_feature("web")`: the ESCI hotspot is replaced by an
  opaque white cover over its rect, so the dead button disappears instead of
  looking clickable (same intent as today's hidden `Esci` button).
- **Panels.** Settings and credits keep their sea cards, shown over the art;
  the art box is hidden while a panel is up, restored on back/close.
- **`logo.png`** is no longer used by the menu (the painting has its own
  illustration); the file stays in the repo.

## What is decided, and by whom

- Chosen approach, contain (letterbox) scaling, hotspot feedback style, the
  downscaled asset and the web ESCI cover: agreed with the user.
- Exact hotspot fractions: measured from the painting during the plan; the
  builder only needs them to line up (verify with a screenshot).
