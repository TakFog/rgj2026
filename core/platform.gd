class_name Platform
extends RefCounted
## Platform checks shared by the input code.
##
## Touch controls (on-screen pause/cancel buttons, tap-to-preview placement,
## bigger fish hit area, back button) exist only in the Android build. Every
## other build, the web one included, keeps the mouse + keyboard controls
## exactly as they are.

## User command-line argument (after `--`) that turns the touch controls on in
## a desktop build, to try them without a phone.
const TOUCH_ARG := "--touch-ui"


## True when the game must be driven by touch instead of mouse and keyboard.
static func is_touch() -> bool:
	return uses_touch(OS.has_feature("android"), OS.get_cmdline_user_args())


static func uses_touch(android: bool, user_args: PackedStringArray) -> bool:
	return android or user_args.has(TOUCH_ARG)


## True for a third finger landing on the screen in a touch build: the touch
## stand-in for F3 (debug overlay).
static func is_debug_touch(event: InputEvent, touch: bool) -> bool:
	var touch_event := event as InputEventScreenTouch
	return touch and touch_event != null and touch_event.pressed and touch_event.index == 2
