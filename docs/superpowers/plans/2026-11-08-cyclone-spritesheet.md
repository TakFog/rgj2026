# Cyclone Spritesheet Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the cyclone's temporary still art and fake swirl shader with the supplied 9-frame spritesheet, animated in the reef and in the tutorial.

**Architecture:** Downscale the supplied sheet to 256 px per frame and ship it as `assets/sprites/cyclone.png`. `CycloneVisual` keeps its `Sprite2D`, sets `hframes = 9` and advances `frame` from `_process`; the swirl shader is deleted. `TutorialIcons` crops one frame with an `AtlasTexture` so the chip shows a still icon.

**Tech Stack:** Godot 4.7.2, GDScript, Compatibility renderer (WebGL2), ffmpeg for the one-time asset conversion.

**Spec:** `docs/superpowers/specs/2026-11-08-cyclone-spritesheet-design.md`

## Global Constraints

- Godot 4.7.2, Compatibility renderer.
- Never stage `project.godot` or `export_presets.cfg`; stage files by explicit path.
- Every commit must pass `tools/lint.sh` and `tools/test.sh` with zero errors and zero GDScript warnings.
- WebGL2 guarantees only a 4096 px maximum texture width.
- Final art goes in `assets/sprites/`; `assets/sprites/temp/` holds placeholders only.
- Do not merge the branch into `main`.

## Review Focus

- A frame with the funnel's tip high in the transparent padding (frames 7–8) must not make the cyclone jump vertically: the sprite is anchored on the union of all frames, not per-frame bounds.
- Two cyclones on screen at once must not animate in lockstep: the start frame is randomised per instance.
- The cyclone tutorial chip must show one frame, not the whole 9-frame sheet.
- The downscaled sheet must stay under 4096 px wide so the web build can upload it.
- Removing the shader must not leave a dangling reference in tests or `TutorialStage`.

---

### Task 1: Ship the final cyclone sheet

**Files:**
- Create: `assets/sprites/cyclone.png`
- Modify: `assets/sprites/temp/README.md`
- Delete: `assets/sprites/temp/cyclone.png`, `assets/sprites/temp/cyclone.png.import`
- Modify: `entities/threats/cyclone.gd`
- Test: `tests/unit/test_threat_visuals.gd`

**Interfaces:**
- Produces: `Cyclone.TEXTURE` (2304×256 sheet, 9 square frames of 256 px).

- [ ] **Step 1: Convert the supplied sheet to final art**

```sh
ffmpeg -y -i video/Vortice_Spritesheet.png \
  -vf "scale=2304:256:flags=lanczos" -pix_fmt rgba \
  assets/sprites/cyclone.png
```

Verify: `sips -g pixelWidth -g pixelHeight assets/sprites/cyclone.png` reports 2304×256.

- [ ] **Step 2: Remove the placeholder and document the swap**

```sh
rm assets/sprites/temp/cyclone.png assets/sprites/temp/cyclone.png.import
```

In `assets/sprites/temp/README.md`, add `cyclone.png` to the "already done" list and delete the `cyclone.png` table row.

- [ ] **Step 3: Point `Cyclone` at the final sheet**

In `entities/threats/cyclone.gd`, replace the temporary-art comment and texture:

```gdscript
## The 9-frame funnel spritesheet (frames are laid out horizontally).
const TEXTURE := preload("res://assets/sprites/cyclone.png")
```

- [ ] **Step 4: Write the failing test**

Add to `tests/unit/test_threat_visuals.gd`:

```gdscript
func test_cyclone_sheet_is_nine_web_safe_square_frames() -> void:
	assert_eq(Cyclone.TEXTURE.get_width(), Cyclone.TEXTURE.get_height() * CycloneVisual.FRAMES,
		"the sheet must be 9 square frames")
	assert_true(Cyclone.TEXTURE.get_width() <= 4096, "the sheet must fit WebGL2's texture width")
```

- [ ] **Step 5: Run the tests to verify they fail**

Run: `tools/test.sh`
Expected: FAIL — `CycloneVisual.FRAMES` is not defined yet (or the texture is not the sheet).

- [ ] **Step 6: Commit**

```sh
git add assets/sprites/cyclone.png assets/sprites/cyclone.png.import \
  assets/sprites/temp/README.md entities/threats/cyclone.gd \
  tests/unit/test_threat_visuals.gd
git rm assets/sprites/temp/cyclone.png assets/sprites/temp/cyclone.png.import
git commit -m "Add the final cyclone spritesheet"
```

---

### Task 2: Animate the funnel frames

**Files:**
- Modify: `entities/threats/cyclone_visual.gd`
- Delete: `entities/threats/cyclone_swirl.gdshader`, `entities/threats/cyclone_swirl.gdshader.uid`
- Test: `tests/unit/test_threat_visuals.gd`, `tests/unit/test_tutorial_stage.gd`

**Interfaces:**
- Consumes: `Cyclone.TEXTURE` (the 2304×256 sheet).
- Produces: `CycloneVisual.FRAMES = 9`, `CycloneVisual.FRAME_FPS = 9.0`; `CycloneVisual.body` is a `Sprite2D` with `hframes = FRAMES`, `texture = Cyclone.TEXTURE`, and a `frame` that advances over time.

- [ ] **Step 1: Rewrite the shader test as an animation test**

Replace `test_cyclone_visual_uses_the_swirl_shader` in `tests/unit/test_threat_visuals.gd` with:

```gdscript
func test_cyclone_visual_uses_the_animated_sheet() -> void:
	# The shadow is drawn by CycloneVisual itself; the children are the funnel
	# and the orbiting spray.
	var previous := Game.projection
	Game.projection = ViewProjection.from_settings(Game.VIEW_SETTINGS)
	var cyclone := Cyclone.new()
	autofree(cyclone)
	var visual := cyclone._make_visual()
	autofree(visual)
	Game.projection = previous
	assert_true(visual is CycloneVisual, "cyclone must use its own visual")
	assert_eq(visual.get_child_count(), 2, "funnel plus spray")
	assert_true(cyclone._body is Sprite2D)
	var sprite := cyclone._body as Sprite2D
	assert_eq(sprite.texture, Cyclone.TEXTURE, "the funnel must use the cyclone spritesheet")
	assert_eq(sprite.hframes, CycloneVisual.FRAMES, "the funnel must cycle the whole sheet")


func test_cyclone_funnel_advances_through_the_frames() -> void:
	var previous := Game.projection
	Game.projection = ViewProjection.from_settings(Game.VIEW_SETTINGS)
	var cyclone := Cyclone.new()
	autofree(cyclone)
	var visual := cyclone._make_visual()
	autofree(visual)
	Game.projection = previous
	var sprite := cyclone._body as Sprite2D
	var start := sprite.frame
	visual._process(0.2)
	assert_true(sprite.frame != start, "the funnel must advance through the sheet")
```

In `tests/unit/test_tutorial_stage.gd`, replace the shader assertions in
`test_cyclone_agent_uses_the_animated_visual` with:

```gdscript
	if body != null:
		assert_eq(body.hframes, CycloneVisual.FRAMES,
			"the tutorial funnel must play the full sheet")
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `tools/test.sh`
Expected: FAIL — `CycloneVisual.FRAMES` is not defined, and the body still uses the shader.

- [ ] **Step 3: Implement the frame animation**

In `entities/threats/cyclone_visual.gd`:
- Delete the `SHADER` preload and the `_material` field.
- Add:

```gdscript
## Frames in the funnel spritesheet, laid out horizontally.
const FRAMES := 9
## Loop speed of the funnel frames.
const FRAME_FPS := 9.0
```

- Add `var _frames := FRAMES` and `var _frame_offset := 0`.
- In `setup`, derive the frame count from the square frames
  (`_frames = maxi(1, roundi(texture_size.x / texture_size.y))`), use
  `frame_size := Vector2(texture_size.x / float(_frames), texture_size.y)` for
  the scale and half-width, and set `_frame_offset = _rng.randi_range(0, _frames - 1)`.
- In `_make_body`, set `body.hframes = _frames` and anchor the sprite with
  `body.offset = Vector2(0.0, -(content.end.y - frame_size.y * 0.5))`; remove
  the shader material.
- In `_process`, before the bob, set
  `body.frame = (_frame_offset + int(_time * FRAME_FPS)) % _frames`.
- Update the class comment: the funnel is now a frame animation, not a shader.

- [ ] **Step 4: Delete the shader**

```sh
rm entities/threats/cyclone_swirl.gdshader entities/threats/cyclone_swirl.gdshader.uid
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `tools/test.sh`
Expected: PASS.

- [ ] **Step 6: Run lint**

Run: `tools/lint.sh`
Expected: `LINT OK`.

- [ ] **Step 7: Commit**

```sh
git add entities/threats/cyclone_visual.gd tests/unit/test_threat_visuals.gd tests/unit/test_tutorial_stage.gd
git rm entities/threats/cyclone_swirl.gdshader entities/threats/cyclone_swirl.gdshader.uid
git commit -m "Animate the cyclone from its spritesheet"
```

---

### Task 3: Crop the tutorial icon to one frame

**Files:**
- Modify: `core/tutorial_icons.gd`
- Test: `tests/unit/test_tutorial_icons.gd`

**Interfaces:**
- Consumes: `Cyclone.TEXTURE`, `CycloneVisual.FRAMES`.
- Produces: `TutorialIcons.texture(&"cyclone")` returns an `AtlasTexture` covering exactly one frame.

- [ ] **Step 1: Write the failing test**

Add to `tests/unit/test_tutorial_icons.gd`:

```gdscript
func test_cyclone_icon_crops_a_single_frame() -> void:
	var icon := TutorialIcons.texture(&"cyclone") as AtlasTexture
	assert_true(icon != null, "the cyclone icon must crop one frame")
	if icon != null:
		assert_eq(icon.atlas, Cyclone.TEXTURE)
		assert_almost(icon.region.size.x * CycloneVisual.FRAMES,
			float(Cyclone.TEXTURE.get_width()))
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `tools/test.sh`
Expected: FAIL — the cyclone icon is the whole sheet, not an `AtlasTexture`.

- [ ] **Step 3: Implement the crop**

In `core/tutorial_icons.gd`:
- Add `const CYCLONE_ICON_FRAME := 3` (the most readable frame) and
  `static var _cyclone_icon: AtlasTexture`.
- Change the match arm to `&"cyclone": return _cyclone_icon_texture()`.
- Add:

```gdscript
static func _cyclone_icon_texture() -> AtlasTexture:
	if _cyclone_icon == null:
		var frame_width := float(Cyclone.TEXTURE.get_width()) / CycloneVisual.FRAMES
		_cyclone_icon = AtlasTexture.new()
		_cyclone_icon.atlas = Cyclone.TEXTURE
		_cyclone_icon.region = Rect2(
			CYCLONE_ICON_FRAME * frame_width, 0.0,
			frame_width, float(Cyclone.TEXTURE.get_height()))
	return _cyclone_icon
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `tools/test.sh`
Expected: PASS.

- [ ] **Step 5: Commit**

```sh
git add core/tutorial_icons.gd tests/unit/test_tutorial_icons.gd
git commit -m "Show a single cyclone frame in the tutorial icon"
```

---

### Task 4: Final verification

- [ ] **Step 1: Run the full gate**

```sh
tools/lint.sh
tools/test.sh
tools/smoke.sh
```

Expected: `LINT OK`, all tests PASS, smoke check succeeds.

- [ ] **Step 2: Check the branch state**

```sh
git status --short --branch
git log --oneline origin/main..HEAD
```

Expected: only the intended files changed; the user's modified
`project.godot`, `data/audio_settings.tres`, `data/balance_actors.tres` and
`data/view_settings.tres` are still untouched and unstaged; no merge into
`main`.
