# Inventory drag-and-drop — design

## Intent

Place inventory items by pressing a card, dragging it onto the reef and
releasing it there, with the same gesture on desktop/web (mouse) and Android
(touch). Today both platforms are click/tap-to-place: pick a card, move the
preview, then click/tap again. Dragging is the natural gesture on a phone and
removes a confirmation step on both platforms.

This is an additional way to place items. Click/tap placement, the **Annulla**
button, right click and Esc keep working exactly as they do today.

## Goals

- Press an inventory card and drag: the existing placement ghost follows the
  pointer, multi-cell corals show their full footprint, and release on a valid
  cell places the item.
- One gesture path for mouse and touch (Android emulates mouse events from
  touches, as the current placement code already relies on).
- A plain click/tap on a card still only selects it and starts placement.
- A release over an invalid cell keeps placement active, so the item is not
  lost.
- A release outside the reef cancels placement and returns the item.
- On touch, the ghost sits above the fingertip during a drag so the finger does
  not hide it; the item drops on the ghost's cell.

## Non-goals

- Moving items that are already on the reef.
- Changing the fish order, pause, cancel or inventory-refill flows.
- Changing the web build's mouse/keyboard behaviour beyond adding the drag
  gesture.
- Changing `project.godot` or `export_presets.cfg`.

## Anti-goals

- Losing the item because a click on the card is mistaken for a zero-length
  drag.
- A dropped item landing on an occupied cell or outside the map.
- A stale drag that places an item on the next unrelated click after focus
  loss, pause or game over.
- Blocking the normal click/tap-to-place path.

## Approaches considered

1. **Manual drag state in `PlacementController` (chosen).** The card's
   `button_down` starts placement and arms drag tracking; the controller
   watches mouse motion and the left-button release, then places or cancels.
   The reef is a `Node2D` world, so the placement logic already lives here and
   stays unit-testable. Works with Android's emulated mouse events.
2. **Godot's `Control` drag-and-drop (`_get_drag_data`/`_drop_data`).** Requires
   a full-screen `Control` drop target over the reef, which risks swallowing
   fish clicks and complicates the placement ghost. Rejected: more moving parts
   for the same gesture.
3. **Separate touch drag implementation with `InputEventScreenDrag`.** Rejected:
   the project already depends on touch-to-mouse emulation, and a second path
   would double the behaviour to maintain.

## Behaviour

- `InventoryCard` stays a `BaseButton`. `InventoryBar` connects its
  `button_down` signal to `PlacementController.begin_drag(slot)`, which calls
  the existing `begin(slot)`. Disabled (empty/refilling) cards never emit it,
  and `begin_drag` still checks the slot.
- While armed, the controller updates the touch preview origin on motion.
  Desktop needs no update: the ghost already follows the mouse.
- On left-button release the controller computes the cell under the pointer
  (lifted above the finger on touch), and decides with a pure helper:
  - moved less than a 10 px dead zone: not a drag; placement stays active;
  - moved enough and outside the grid: cancel and return the item;
  - moved enough and inside: place if valid, otherwise keep placement active
    and play the existing failure feedback.
- Focus loss (which opens the pause menu) or cancellation disarms the drag
  without changing the current placement.

## Constraints

- Godot 4.7.2, GDScript, Compatibility renderer.
- No new input actions, no project settings changes.
- Touch behaviour must stay gated on `Platform.is_touch()`; web must keep its
  current controls.
- All GDScript warnings are errors (`tools/lint.sh`), and unit tests run
  headless (`tools/test.sh`).
- Commit in English, never on `main`, no merge for this task.
