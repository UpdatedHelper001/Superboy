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

## Round 5

- **Integrated the real art pack** (`NovaTerra_Building_Art_Pack_720p_PNG`,
  64 facade variants across 8 districts + 8 entrance-sign decals) in place
  of the flat-color procedural buildings.
  - Each 1280x720 source PNG is really a 720x720 square facade card,
    horizontally centered with transparent padding on both sides; cropped
    via `AtlasTexture` region `(280, 0, 720, 720)` rather than stretching
    the padding into the building. Loaded with `load()` (not
    `Image.load_from_file()`/raw file reads) specifically because raw
    source PNGs generally aren't bundled in an exported Android
    APK -- only their imported form is -- so anything reading the file
    directly at runtime would work fine from the editor and then silently
    fail on-device. `load()` resolves correctly in both cases.
  - `_make_structure` now picks the facade folder from the zone's district
    (residential/downtown/old_town/industrial/port/beach) for huts and
    "building"-kind structures, and always uses the `commercial` set
    (which bakes in an awning + shop name like MARKET/CAFÉ/STUDIO) for
    shops regardless of district. The school uses the `civic` set. This
    replaces the old procedural window-grid mesh instances (up to ~24 extra
    nodes per building) with a single textured quad per building -- a net
    node-count reduction as well as a visual upgrade. Old procedural
    window-grid/awning code is kept as a fallback for any zone kind that
    doesn't have matching art.
  - Added `[importer_defaults]` to `project.godot` (`compress/mode: 2`,
    `mipmaps/generate: true`) so every texture gets VRAM compression +
    mipmaps by default without needing 72 hand-authored `.import` files --
    verified by wiping `.godot` and checking the regenerated `.import`
    output directly. Matches the art pack's own README guidance.
  - District entrance signs: the 8 decal PNGs (a different crop,
    `(0, 200, 1280, 320)` -- a wide horizontal pill, not a square) are
    mounted on posts near each district's edge, facing whichever
    neighboring zone `ZONE_LINKS` (hoisted out of `_build_connecting_roads`
    so both roads and signs share one adjacency list) says it connects to
    first. Sign material is double-sided so it still reads fine even if
    that "which way is traffic coming from" guess is off. The 9th decal
    (`nova_terra_neutral_sign`, no specific district) is placed near the
    school as a neutral civic landmark instead of favoring one district.
  - Couldn't get real rendered screenshots to visually confirm placement --
    this environment's Xvfb instance wasn't reachable from the Godot
    process (socket connection refused across tool-call process
    boundaries), consistent with earlier notes that Xvfb-based rendering
    is unreliable here. Compensated with what could be verified directly:
    confirmed `PlaneMesh.orientation = FACE_Z` lays the quad flat in the
    local XY plane via `get_aabb()` on a minimal isolated test scene;
    used `cull_mode = CULL_DISABLED` on every facade/sign material so
    they render regardless of which way the generated winding faces,
    removing that as a failure mode entirely; and built a 2D crop+stretch
    mockup with Pillow outside Godot to sanity-check the visual result
    for a hut, a shop, a tall building, and a square industrial building --
    all read clearly, with only very tall buildings showing a
    noticeably elongated door, an acceptable trade-off in this flat
    vector-art style.
  - Verified via instrumented headless runs (3 different random seeds):
    every generated structure (157/157 each run, huts + shops + buildings
    + the school) got a real facade quad with zero fallback-to-procedural
    and zero texture load failures; all 9 signs loaded and placed with
    sane, non-degenerate positions/facing directions.
  - Final build verified against the real Godot 4.3 editor: clean
    `--headless --import`, and 30 simulated seconds of headless play with
    zero script errors.

## Round 6

- **Character models** from `Nova_Terra_3D_Source_Pack` (Joseph + 7 NPC
  types: Civilian, Worker, Elder, Child, Police, Doctor, Gang), replacing
  the plain capsule/sphere "gingerbread man" rig for every character in the
  game.
  - Important finding, stated plainly because it changes what "using" this
    pack actually meant: the pack's own README says the included meshes are
    "procedural blockout/source meshes, not the exact AAA/4K models shown in
    the artwork" -- and inspecting the actual `.glb` files confirmed why.
    Each one is a single merged mesh with **zero materials, zero UVs, zero
    skeleton, and zero animation** -- generated by `trimesh` from what reads
    as a simple Blender primitive blockout (boxes/cylinders/spheres per
    limb), then flattened into one static blob before export. Two of the
    five "outfit variants" (`Default`/`Stealth`) are byte-identical files,
    as are two NPC "types" (`Civilian`/`Elder`). Dropped in as-is, this
    would have meant either a frozen T-pose statue replacing the walk
    animation, or keeping the animation and losing the model. Said this
    directly rather than quietly shipping a downgrade or overselling what's
    really a rough placeholder blockout.
  - Instead, reconstructed real articulation out of the single merged mesh:
    each character's mesh is actually several disjoint (non-touching)
    primitive clusters -- one per original Blender object -- so a
    union-find over shared triangle vertices cleanly separates it back into
    parts. Verified this against `generate_nova_terra.py`'s literal
    coordinates for the Default character: every segmented part's center
    and size matched the script's `cube()`/`sphere()`/`cyl()` calls
    exactly. A general rule (height-band + left/right position, no
    per-file tuning) then groups those parts into exactly 6 rig-relevant
    clusters -- LeftLeg, RightLeg, LeftArm, RightArm, Torso, Head -- and
    this held with zero empty/misclassified groups across all 12 source
    files (5 main-character outfits + 7 NPC types).
  - A Python pipeline (kept out of the shipped project; the source pack
    isn't included either) re-centers each of the 6 groups on the right
    pivot (hip for legs, shoulder for arms, base for torso/head -- matching
    exactly what `CharacterRig._make_limb` already pivots primitives on),
    remaps the source data's Z-up axes to glTF/Godot's Y-up (verified
    against the generator script's own front/back placement -- the chest
    detail sits toward what becomes -Z, matching Godot's `look_at()`
    forward convention, confirmed empirically rather than assumed), computes
    real vertex normals (source had none), and rescales each character to a
    game-appropriate height (~2.15m Joseph / ~1.95m NPCs, close to the
    rig's existing proportions) before writing out a hand-built multi-node
    glTF -- one named node per rig group. Loaded with `load()` (not raw
    file reads), consistent with the export-safety fix from the building
    art round.
  - `CharacterRig.build()` now accepts an optional `model_path`: if given,
    it loads the reconstructed rig, finds the 6 named nodes, and tints each
    with the exact same `leg_color`/`arm_color`/`torso_color`/`head_color`
    the primitive path already used (the source meshes have no material at
    all, so per-instance tinting via `set_surface_override_material` was
    already necessary either way -- this preserves every NPC's existing
    per-role/skin-tone color variety without change). Every existing
    caller falls back to the original capsule primitives automatically if
    a model fails to load, so there's no new single point of failure.
    Player.gd uses `MainCharacter_Default`; NPC.gd picks from the 7 NPC
    models per spawn, weighted toward civilians/workers with police,
    doctor, and gang rarer -- a believable city crowd instead of one
    generic silhouette. Also fixed a latent, previously-invisible bug this
    surfaced: the backpack marking Joseph among NPCs was positioned on his
    *front* (confirmed via an isolated `look_at()` axis test that -Z is
    forward) -- harmless against the old symmetric capsule body, but would
    have visibly clashed with the new model's real chest detail.
  - Couldn't get real rendered screenshots here either (same Xvfb
    limitation as the building art round). Verified everything else
    directly: parsed the hand-built glTF myself and independently via
    actual Godot import + a runtime node-tree dump (confirmed node names,
    hierarchy, and world-space part positions form a contiguous standing
    silhouette with no gaps); ran an instrumented headless session
    confirming 100% success (147/147 NPCs + Joseph) building from the real
    model with zero fallback to primitives; and sampled left-leg rotation
    on 5 NPCs every 2 seconds across a run, confirming the walk cycle is
    genuinely oscillating (not stuck, not NaN) through the same
    `update_walk()` code the primitive rig already used, unchanged.
  - Known trade-off, stated rather than hidden: since the source meshes
    have no material boundaries, each of the 6 groups gets one solid
    color -- so a chest logo/accent color distinct from the jacket isn't
    preserved (the concept sheet's red trim, for instance, doesn't survive
    as its own color). Splitting Torso into two tintable surfaces is a
    reasonable follow-up if that detail matters. Also worth watching on
    real Android hardware: total scene vertex count is meaningfully higher
    than the old capsule rig (~2,500 vertices per character vs. a handful
    for primitives; ~150 NPCs is a lot of characters even if most are
    off-screen or distant at any moment) -- nothing observed here suggests
    a problem, but this wasn't load-tested on real mobile GPU hardware.
  - Verified against the real Godot 4.3 editor as every round before:
    clean `--headless --import`, and 30 simulated seconds of headless play
    with zero script errors.
