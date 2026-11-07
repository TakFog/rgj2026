# Android build

BalanSea ships an `Android` export preset next to the `Web` one. Both run the same game; the
Android build only adds touch controls, and nothing about the web build changes.

## What differs on Android

Everything is gated on `Platform.is_touch()` (`core/platform.gd`), which is true only in the
Android build (or on desktop with `-- --touch-ui`, to try the touch controls without a phone):

| Desktop / web | Android |
| --- | --- |
| Left click | Tap (Godot emulates the mouse from touch) |
| Placement preview follows the mouse, click places | Tap or drag moves the preview, tapping the preview again places (`PlacementController.touch_mode`) |
| Right click / Esc | **Annulla** button (`ui/b_touch_controls.gd`) or Back |
| Space / Esc | **Pausa** button or Back |
| 1-4 keys (badges on the cards) | Tap the card; badges hidden |
| `fish_click_radius` | `fish_touch_radius` (fingertip-sized), both in `data/balance_actors.tres` |
| F3 | Three-finger tap |

The Android Back button is turned into an Esc key press (`Game._notification`), so every screen
reacts to it exactly as it does to Esc. `application/config/quit_on_go_back=false` stops Back from
closing the app; the painted **ESCI** button on the title screen quits, as on desktop.

Project settings added for Android (no effect on the web build): `quit_on_go_back=false`,
sensor-landscape orientation, and `import_etc2_astc=true` (required by the Android exporter;
every texture is lossless, so nothing is actually re-compressed).

## CI

`.github/workflows/ci.yml` (job **Android APK**, after the tests pass) exports the preset on every
push and uploads `balansea.apk` as the `android-apk` artifact.

Every push to `main` also publishes a **GitHub release** tagged `v<N>` (`v1`, `v2`, …), with
`balansea-v<N>.apk` attached: N is the highest existing `v<N>` tag plus one, and is used as both
the Android version code and the version name, so each release installs over the previous one.
Branch builds take the number the next release will get, named `<N>-dev.<commit>`.

The APK is release-signed with the keystore stored in the repository secrets:

| Secret | Contents |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | the keystore file, base64-encoded |
| `ANDROID_KEYSTORE_ALIAS` | the key alias |
| `ANDROID_KEYSTORE_PASSWORD` | the keystore and key password |

Without the secrets (pull requests from forks) the job signs a debug APK with a throwaway key.
Keep a backup of the keystore: an APK signed with a different key cannot update an installed one,
and the Play Store requires the same key for every release.

## Building locally

1. Install the Android SDK (Android Studio) and a JDK 17+, then in Godot set
   *Editor Settings → Export → Android* `Android SDK Path` and `Java SDK Path`.
2. *Editor → Manage Export Templates* → download the 4.7.2 templates.
3. Export:

   ```sh
   godot --headless --export-debug "Android" build/android/balansea.apk
   adb install -r build/android/balansea.apk
   ```

   A release build needs the keystore, passed through the environment so it never lands in
   `export_presets.cfg`:

   ```sh
   GODOT_ANDROID_KEYSTORE_RELEASE_PATH=/path/to/release.keystore \
   GODOT_ANDROID_KEYSTORE_RELEASE_USER=<alias> \
   GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=<password> \
   godot --headless --export-release "Android" build/android/balansea.apk
   ```

Never put keystore paths or passwords in `export_presets.cfg` (it is committed); Godot keeps
editor-entered credentials in the git-ignored `.godot/export_credentials.cfg`.
