# Superboy - fixes applied

- Added collision to generated interior floors.
- Moved NPC random day-cycle initialization into `_ready()`.
- Explicitly enabled `Area3D.monitoring` for generated doors.
- Switched the renderer to GL Compatibility for better Android/low-end compatibility.
- Added a predictable 960x540 base viewport.

The original game structure and procedural world generation were preserved.
