# Superboy - fixes applied

- Added collision to generated interior floors.
- Moved NPC random day-cycle initialization into `_ready()`.
- Explicitly enabled `Area3D.monitoring` for generated doors.
- Switched the renderer to GL Compatibility for better Android/low-end compatibility.
- Added a predictable 960x540 base viewport.

## Round 2

- **Added on-screen touch controls** (`scripts/TouchControls.gd`): a virtual
  joystick (bottom-left) for movement, drag-to-look on the right side of the
  screen, and a jump button (bottom-right). Previously the player script only
  read keyboard/mouse input, so the built APK had no way to move, look
  around, or jump on an actual touchscreen. Touch controls are only added
  when `OS.has_feature("mobile")` is true, so desktop keyboard/mouse play is
  untouched. A gentle joystick tilt now walks instead of always running at
  full speed (keyboard movement is unaffected — it's still always full
  speed).
- Disabled `input_devices/pointing/emulate_mouse_from_touch` in
  `project.godot` so touch drags aren't double-counted (once as a real touch
  by the joystick/look code, once as an emulated mouse-look event).
- The touch layer re-measures its layout whenever the viewport's reported
  size changes (`Viewport.size_changed`), instead of trusting a single read
  at startup, since that isn't guaranteed to be final on the very first
  frame.

The original game structure and procedural world generation were preserved.
