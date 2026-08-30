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

## Round 3

- **Root-caused why every character had no body and spammed errors every
  frame.** `CharacterRig.gd` failed to compile under this Godot 4.3 build:
  `var swing := sin(...) * leg_swing_max * clamp(...)` — `clamp()`'s return
  type can't be statically inferred here, so the `:=` declaration is a hard
  parse error, not a warning. Since the class failed to load, `class_name
  CharacterRig` resolved to nothing, so `var _rig := CharacterRig.new()` in
  both `Player.gd` and `NPC.gd` was silently `null`. The practical effect:
  every character (Joseph and every NPC) had no visible legs/arms/torso/head
  at all, and `_rig.update_walk(...)` threw a `SCRIPT ERROR` on every single
  physics frame for every character (tens of thousands of error lines in a
  short play session). Fixed by giving `swing`/`arm_swing` in
  `CharacterRig.gd` and `ratio` in `HUD.gd` explicit `: float` types instead
  of relying on `:=` inference across a `clamp()` call. Confirmed fixed by
  downloading the real Godot 4.3 editor, running a full headless import
  (zero errors, versus a hard parse failure before), and running the actual
  game headless for 60 simulated seconds (zero script errors, versus
  thousands before).
- **Root-caused NPCs walking into walls and getting stuck.** Workplace/home
  target points were computed as fixed offsets like `pos + Vector3(0, 0, 3)`
  or `home + Vector3(2, 0, 2)` — both always along world +Z/+X regardless of
  the structure's actual rotation (structures are randomly rotated to one of
  0/90/180/270 degrees in `_place_structure`), and even at rotation 0 the
  offset was small enough to land *inside* the building's own solid
  collision rather than outside its door. NPCs (and the player's own spawn
  point) would walk toward that point, hit the building's real wall before
  reaching it, and stall. `_add_door_and_interior` now reads the structure's
  actual world-space forward axis (`structure.transform.basis.z`) and
  computes a `door_front` point genuinely outside the door, regardless of
  rotation. `_workplaces`, `_house_positions`, NPC home/work targets, and
  the player's spawn point all use this corrected point now. Verified with
  an instrumented headless run: 0/90 workplace door-fronts landed inside a
  building's footprint (checked across multiple random-seeded runs).
- **Added a stuck/detour fallback to `NPC.gd`** as a safety net for the
  cases the fix above doesn't cover (an ambient wanderer's random point
  clipping a nearby building, two NPCs converging on the same spot): if an
  NPC makes little progress toward a real destination for ~1.2s, it steers
  sideways around the obstruction for ~2s before resuming. Verified with an
  instrumented headless run (137-144 NPCs, 15-60 simulated seconds): 0 NPCs
  ever completely frozen, detours triggered only occasionally (~1 per NPC
  per 15s) and never looped (max 4 detours for any single NPC, 0 NPCs stuck
  in a repeated-detour loop).
- **Chunked world generation.** Spawning all ~180 buildings (each with its
  own interior room) and then ~150 NPCs (each with a multi-part articulated
  body) in one unbroken burst inside `_ready()` used to block the whole game
  for a very noticeable moment on startup -- worst of all on the low-end
  Android hardware this project targets. Both passes are now spread across
  multiple frames (`STRUCTURES_PER_CHUNK` / `NPCS_PER_CHUNK` per frame, via
  `await get_tree().process_frame`), with a "Generating Nova Terra..."
  loading screen tracking phase and percentage. The player now spawns only
  after the world is fully built.
- All of the above was verified against the real Godot 4.3 editor binary,
  not just read from source: a from-scratch `--headless --import` (clean),
  and full headless play sessions up to 60 simulated seconds with zero
  script errors.

## Round 4

- **Right-corner HUD clock.** Added a day/time panel in the top-right,
  visually matching the minimap panel's style. Runs on its own timer over
  the same day-length every NPC's schedule uses, and the phase mapping is
  set so "night" roughly lines up with NPCs' AT_HOME hours and "day" with
  AT_WORK -- e.g. showing "Day 2 / 08:48 AM" as commuters start their shift.
  Confirmed on-screen placement via the real editor: panel rect lands at
  (814,16)-(944,62) in the 960-wide viewport, a clean 16px margin from the
  top-right corner mirroring the minimap's own margin.
- **Re-verified the door/rotation fix from Round 3 still holds**, plus a
  check Round 3 didn't cover: whether a door's "front" point could land
  inside a *different*, neighboring building rather than its own (a real
  risk in the tighter districts, e.g. Old Town's 15-unit spacing with
  buildings up to 14 units wide). Tested every door_front point against
  every OTHER structure's own oriented bounding box across multiple
  random-seeded runs: 0 overlaps out of 156-166 points each time. No
  further door bug found in this pass -- if something's still off, the
  most useful thing to say is what it looks like in play (an NPC/Joseph
  stuck at a specific building, a door that doesn't teleport, teleporting
  to the wrong spot, etc.) so it can be reproduced directly.
- **Fixed the invisible instant-death bug making Joseph look invincible.**
  `_die()` used to reset health back to full in the exact same physics
  frame the lethal damage happened, before that frame ever got rendered --
  so a fatal fall looked visually identical to no damage at all; the health
  bar never actually showed empty. `_die()` now holds at 0 HP for a beat
  (0.6s) before teleporting home and healing, so the hit is genuinely seen.
  Verified with an instrumented run: health hits 0, stays there for ~35
  physics frames (~0.6s), *then* respawns at full health -- confirmed via
  the HUD's own health_changed listener firing as two distinct events, not
  one. The underlying fall-damage math itself was already correct (a
  scripted 40m drop test reliably dealt lethal damage and triggered
  respawn); note that on the current flat map there's no reachable ledge
  high enough to trigger it in ordinary play (jump apex is ~1m, and fall
  damage needs ~2.8m+) -- worth knowing if it still looks like nothing
  happens after an ordinary jump, since that's expected until the world has
  real elevation somewhere.
- Verified against the real Godot 4.3 editor as before: clean
  `--headless --import`, and 30 simulated seconds of headless play with
  zero script errors.
