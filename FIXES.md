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

## Round 7 -- NovaTerra AAA character + building source packs

Two new uploaded packs (`NovaTerra_Realistic_AAA_Character_Source_Pack`,
`NovaTerra_Realistic_AAA_Building_Pack`) replaced the placeholder art from
the previous rounds. Both ship as *source pipelines* (raw OBJ geometry +
Blender Python generators), same as the pack integrated in Round 6, not
ready-to-import Godot assets -- so this was another reconstruction job, not
a drag-and-drop.

**Buildings**
- The building pack's own Blender script had a real bug: `window()` tried
  to unpack `for px,pz,s in [(x,z+h/2), ...]` against a list of 2-tuples --
  `s` was never used in the loop body (dead scaffolding), so the fix was
  dropping it from the unpacking target, not adding a missing list element.
  Confirmed by reading the loop body before touching it.
- Ran the (now-fixed) script in real Blender 4.0 (installed via apt; not
  bundled, so this environment needed it) to generate the 6 building GLBs
  the pack only ships as source for. Measured each output's actual bounds
  rather than trusting the script's stated constants -- confirmed the
  front-facing detail (doors/windows, built at `-D/2` in Blender's Y) lands
  on +Z after Blender's Y-up glTF export, i.e. exactly this project's
  existing "door faces local +Z" convention, so no manual axis correction
  was needed.
- The pack's default 3-segment bevel produced 60-95k triangles per building
  (measured) across 300-500 separate mesh parts each -- fine for a hero
  asset, not for instancing repeatedly across an open world on Android.
  Dropped to a 1-segment bevel (still reads as softened, non-razor edges)
  and merged every part sharing a material into one mesh per material
  (~6-7 parts per building instead of 300-500), cutting Downtown_Office
  from 95k tris / 506 parts to 22k tris / 6 parts with the same silhouette
  and material palette -- collapsing draw-call count is the bigger mobile
  win of the two.
- New `BUILDING_MODELS` in `WorldGenerator.gd` maps each district to one of
  the 6 models + that model's real (width, height, depth), replacing the
  flat facade card **for "building"-kind structures only** -- huts and
  shops keep the existing flat-card system (`_apply_facade`/commercial
  awning), since none of the 6 models are hut/shop-scaled and shops need
  to keep their baked-in name signage. `old_town` and `beach` previously
  never rolled "building" at all (`_pick_structure_kind`), so `Old_Town.glb`
  and `Coastal_Villa.glb` would've gone unused -- added a small "building"
  chance to both (10% / 15%) so every model in the pack is actually reachable.
  `Abandoned.glb` is a rare (8%) substitute wherever "building" is picked,
  in any district, for a bit of worn/derelict variety.
- The procedural door shell (collision + doorway pillars/lintel/roof cap)
  still runs underneath every model-backed building -- it's the only source
  of actual collision and the door/interior-link metadata everything else
  depends on -- but now builds **invisible** (`_add_box_part` gained a
  `visible` flag) when a real model is present, since the pack's buildings
  are fully enclosed volumes, not flat cards, and would otherwise z-fight
  against the shell's own coincident wall/roof faces.
- New building footprints (up to 28m wide for Industrial_Warehouse) are
  much larger than the old random 8-14m box the district `spacing` values
  were tuned around -- bumped spacing per affected zone (e.g. downtown
  18->26, industrial/port 26/28->34) to keep neighboring structures from
  overlapping. **Caught by verification, not inspection**: an instrumented
  headless run (see below) flagged the school overlapping two
  `residential_north` structures -- its position was a hand-picked offset
  that used to sit just past that zone's (smaller, pre-this-round) grid
  edge, and the new spacing pushed the grid past it. Replaced the magic
  offset with one computed from the zone's actual `count`/`spacing`, so it
  stays correct if either changes again later.

**Characters**
- Same reconstruction approach as Round 6 (the source OBJs are disjoint
  8-vertex box primitives, no UVs/normals/rig), reapplied to this pack's 9
  archetypes (1 main character + 8 NPCs: Civilian Male/Female, Scout,
  Guard, Medic, Merchant, Engineer, Boss Heavy). Classification rule this
  time keyed off box-center **X magnitude** first (legs stay within ~0.2-0.35
  of center, arms sit out at ~0.5-0.8, a clean gap across every archetype),
  then height for the centered leftover (torso vs. head) -- verified zero
  empty/misclassified groups across all 9 files, same bar as Round 6.
- Preserved each archetype's relative scale instead of flattening every NPC
  to one height: all 8 NPCs share one scale factor (Civilian Male's raw
  height -> 1.95m, matching the existing convention), so Boss Heavy comes
  out ~2.15m and Civilian Female ~1.87m rather than every NPC being
  identical height. Main character scaled independently to 2.15m as before.
  Output structure (root node, 6 children named LeftLeg/RightLeg/LeftArm/
  RightArm/Torso/Head, each pivoted exactly like `CharacterRig._make_limb`
  already expects) matches the existing reconstructed-rig convention
  byte-for-byte -- confirmed against the already-shipped
  `MainCharacter_Default.glb` as a structural reference before building
  the new ones, not assumed from the docstring alone.
- `NPC.gd`'s `NPC_MODELS` now points at the 8 new archetypes (civilians
  most common, Engineer/Merchant as workers, Medic/Guard/Scout occasional,
  Boss Heavy rarest). Removed the old pack's now-unreferenced
  `NPC_Civilian/Worker/Elder/Child/Police/Doctor/Gang.glb` and the unused
  `MainCharacter_Hoodie/Armored/Stealth/Nightwing.glb` outfit variants
  (nothing loaded them even before this round).
- **Known trade-off, stated rather than hidden**: this pack has no
  Elder/Child archetype, so that age variety from Round 6's crowd is gone.
  Scaling an adult rig down reads as a shrunken adult, not a child, so
  faking it wasn't worth doing -- flagged here instead.
- The 6 building-part modular OBJs (Balcony/Door/Roof_Slab/Wall_Brick/
  Wall_Concrete/Window) weren't used -- the 6 pre-built buildings already
  cover every district, and these have the same no-UV/no-material/no-rig
  limitations as everything else in both packs.

**Verification**
- Real Godot 4.3 (downloaded fresh, same as every round) headless
  `--import`: zero errors across both new packs, all 9 character GLBs and
  6 building GLBs, confirmed via `--verbose` that every character import
  produced the expected `Creating mesh for: LeftLeg/RightLeg/.../Head` set.
- Wrote an instrumented headless pass (not shipped -- removed after use,
  same as this project's usual practice) that actually runs
  `WorldGenerator._ready()` inside the real engine and checks, over the
  real generated world: zero structure-footprint overlaps (rotation-aware,
  not axis-aligned-only), zero `door_front` points landing inside a
  neighboring structure, all 65 model-backed "building" structures
  actually got their model instanced (0 silent no-ops), and all 147 spawned
  NPCs have real `LeftLeg`/etc. nodes from a loaded model (0 fallback to
  the primitive capsule body). First run caught the school/residential
  overlap above; second run came back clean on all four checks. Re-ran the
  identical check against an unmodified copy of the original upload to
  confirm a leftover renderer warning on quit (`Parameter "m" is null`)
  is a pre-existing headless/dummy-renderer artifact at this scene size,
  not something this round introduced.
- Couldn't get real rendered screenshots here either (same Xvfb/GL
  limitation as the last two art rounds) -- relied on the structural
  verification above plus directly measuring each GLB's bounds/axis
  orientation with the same tooling used to build them, rather than
  trusting the source pack's stated dimensions.

**Addendum: modular parts, and a real triangle budget**
- Checked whether the 6 unused modular OBJs (`Balcony_3x1_5`, `Door_1x2_2`,
  `Roof_Slab_4x4`, `Wall_Brick_4x3`, `Wall_Concrete_4x3`, `Window_2x2`)
  could close the hut/shop gap noted above. They're bare, unbeveled,
  material-less slabs -- `Wall_Brick_4x3` and `Wall_Concrete_4x3` are in
  fact geometrically identical, differing only in filename, with no brick
  pattern or texture baked into either. Assembling huts/shops from these
  would be a visual downgrade from the existing illustrated flat-card art,
  not an upgrade, so that trade-off stands as designed rather than as an
  oversight.
- Confirmed no other docs/scripts reference the removed old-pack filenames
  (`NPC_Civilian.glb`, `MainCharacter_Hoodie.glb`, etc.) outside this file's
  own history, and that `WORKFLOW_FIXES.md`/`ANDROID_BUILD.md` don't
  reference specific art filenames at all.
- Estimated the real triangle load from the new buildings across a full
  generated city (all districts, actual per-zone structure counts and
  "building" roll rates, including the 8% Abandoned substitution):
  ~59 model-backed buildings total, ~720k triangles summed across all of
  them city-wide. Downtown alone accounts for ~540k of that (26 buildings
  x up to 22.3k tris each, since every downtown structure is "building"
  kind) -- by far the densest district, worth keeping an eye on if this
  project profiles slow specifically in downtown on real Android hardware,
  since that's the one place where camera view distance could put a dozen-
  plus of these on screen simultaneously.

## Round 8 -- real knee/elbow bend (walk cycle was rigid-leg scissoring)

The 6-node rig (whole leg/arm as one rigid pivoting piece) only ever swung
at the hip/shoulder, so it walked like a stiff scissor doll -- no knee or
elbow to bend. Re-ran the character reconstruction with legs split into
Thigh (hip pivot) -> nested Shin (knee pivot) and arms into UpperArm
(shoulder pivot) -> nested Forearm (elbow pivot), 10 rig nodes total.
Classified the split by rank, not a threshold: sorted each limb region's
boxes by height and always took the bottom two as shin/forearm -- this is
what actually holds across every archetype (some arms carry a 4th
shoulder-armor box, legs never do), where an absolute or mean-based z cut
doesn't.
`CharacterRig.update_walk` now drives knee/elbow bend off the same
walk_phase as the hip/shoulder swing (cos-timed so each joint bends
through its own limb's airborne half of the stride and straightens
through its planted half). Verified in real Godot: all 9 regenerated
models load with zero rig-fallback, and a simulated walk cycle produces
nonzero, bounded, NaN-free knee/hip angles. All 152 world-spawned NPCs
pick up the new rig cleanly.

## Round 9 -- Quaternius pack added to the NPC pool

5 fully-rigged, pre-animated character GLBs (Man, Man in Long Sleeves, Man
in Suit, Business Man, Punk -- Quaternius packs, real Skeleton3D + baked
Idle/Walk/Run clips) dropped into `art/models/quaternius/` and mixed into
`NPC_MODELS`.

These needed a different path through `CharacterRig` than the NovaTerra
box-reconstructed rigs -- there's a real skeleton and baked animation here,
not 10 pivots to rotate by hand. `_build_from_model` now checks for an
`AnimationPlayer` with recognizable Idle/Walk (and optionally Run) clips
first (name-matched case-insensitively, since one sub-pack uses
`HumanArmature|Man_Walk` and the other `CharacterArmature|Walk`); if
found, `update_walk` just crossfades Idle<->Walk/Run and nudges
`speed_scale` with actual movement speed, instead of touching any pivot.
Falls through to the existing NovaTerra node-lookup, then the primitive
capsule, exactly as before, for anything without a skeleton.
No cfg color tinting applies to these -- they ship their own per-part
materials (Shirt/Pants/Skin/etc.), which is the point of naming a specific
archetype instead of recoloring a generic mesh.
Checked the Walk/Run clips' animated channels directly against the raw
glTF before wiring this up: nothing targets the root/armature node, only
bones from Hips down, so there's no baked root motion to fight with this
game's own CharacterBody3D movement (would otherwise double the character's
forward travel per step).
Verified in real Godot: all 5 models resolve to animation mode with the
right clips found, and a full world-generation run picked them up cleanly
across NPCs (0 falling back to the primitive body).

## Round 10 -- uniform NPC height

Boss Heavy (NovaTerra, deliberately 2.15m from Round 7's "preserve relative
archetype scale" choice) ended up exactly as tall as the main character,
and the Quaternius pack (Round 9) was never height-corrected at all --
its native units render around 4.7m, several times human height. Both are
symptoms of the same underlying gap: nothing normalized a model's actual
rendered size against any common reference once it left its own source
pipeline's hands.

Fixed at the root instead of hand-tuning either pack: `CharacterRig` now
measures how tall a just-instanced model *actually renders* (skeleton bone
world-positions for a skinned model, aggregated MeshInstance3D bounds
otherwise -- a skinned mesh's own `get_aabb()` only reflects its unposed
bind pose, not real size) and rescales it to a `target_height` cfg key.
`NPC.gd` now passes `"target_height": 1.95` for every archetype in both
packs; `Player.gd` doesn't (its own model is already correctly authored at
2.15m), so the main character stays visually distinct from the crowd. This
self-corrects for any future pack regardless of its native units, rather
than adding another per-asset scale constant to maintain.
Verified in real Godot: all 13 current NPC archetypes measure to within
3cm of 1.95m post-scale, main character unaffected at 2.15m, and the walk
cycle/skeletal-animation playback both still work normally on a scaled
instance (scaling `inst` doesn't touch any child node's local animated
transform, so nothing about Round 8/9's animation logic needed to change).

## Round 11 -- Lamborghini/Sports Car/Dominus added, dead code swept, road collision fixed

Added the 3 uploaded models: two parked-car archetypes (Sports Car,
Lamborghini Aventador -- the latter authored in centimeters, not meters;
cross-checked its 0.01 scale correction against the real car's known
~1.14m/4.78m dimensions rather than eyeballing it) scattered along both
sides of every connecting road, and Dominus as a one-off landmark prop in
Greenwood Park. Both go through the same `_add_box_part(..., visible:
false)` pattern as building models -- a plain invisible collision box sized
to the asset, with the real model as a non-colliding visual on top.

Dead-code sweep: removed `FlyCam.gd` (an editor-only debug camera script,
never referenced by any scene or attached anywhere -- confirmed via a
whole-project grep, not just a guess) and `CharacterRig._using_model` (set
in two places, read nowhere -- same grep-for-zero-other-references check
run across every var/const/func in scripts/, one hit).

**Real bug found while verifying the above, unrelated to either change:**
connecting roads (`_build_connecting_roads`) have only ever been a bare
visual `Node3D` -- mesh, curbs, dashed line -- with no `CollisionShape3D`
of any kind. Zone ground (`_build_ground`) only covers each zone's own
footprint and zones don't touch, so every road was an invisible hole the
player fell through the moment they walked past their starting zone's
edge. Added a `StaticBody3D` + `BoxShape3D` matching the road's own
(length x ROAD_WIDTH) footprint as an actual collision surface. Verified
with a real physics drop test (not just an import check) at all 10 road
midpoints: a capsule body dropped from 5m above each one now settles at
~0.85m (its own half-height) instead of falling through.

## Round 12 -- dropped the NovaTerra NPC archetypes, compacted shared collision code

`NPC_MODELS` now only draws from the 5 Quaternius archetypes (real
skeleton + baked animation) -- removed the 8 box-reconstructed NovaTerra
NPC archetypes (Civilian Male/Female, Scout, Guard, Medic, Merchant,
Engineer, Boss Heavy) from the pool and deleted their now-unreferenced
`.glb` files (confirmed zero remaining references first, same as every
prior deletion this project). `MainCharacter_Default.glb` and
`CharacterRig._build_from_rig_model`/the hand-rotated knee-elbow walk are
untouched -- Joseph still uses that rig, only the NPC pool changed.

Re-ran the whole-project dead-symbol sweep (every `var`/`const`/`func`
grepped for a second reference anywhere in scripts/) -- only hits were
`_process`/`_input`/`_unhandled_input`, which are real Godot engine
callbacks the sweep can't see are invoked, not actual dead code (checked
each one has real logic, not a stub, before ruling them out).

Compaction: `_build_ground`'s zone-floor collision and last round's new
road collision were near-identical 6-line "StaticBody3D + BoxShape3D"
blocks -- pulled into one `_flat_collision(size, pos)` helper, used by
both. Left the older, already-hardened collision code in
`_add_box_part`/`_build_door_shell`/`InteriorBuilder.gd` alone: those are
tested across many rounds and touching them for cosmetic consolidation
alone isn't worth the regression risk.

Verified in real Godot: main character still resolves through the rig-
model path (unaffected), all 141 world-spawned NPCs now hit the animation
path with zero primitive-fallback, zero structure overlaps, and the
road-collision physics drop test from last round still passes at all 10
midpoints after the `_flat_collision` refactor.

## Round 13 -- NPC walk direction, road connectivity, and performance

**NPC walking backward:** confirmed first that the actual `move_and_slide()`
position never reverses (a real physics-driven walk test showed 0 backward
frames across a full commute) -- the bug was purely visual. Measured the
Quaternius Walk clip's own forward-swing direction in real Godot (average
`dz` of `Foot.L` while airborne, not a single noisy sample near the swing
peak, which is what an earlier single-frame check had gotten wrong) against
this project's -Z-is-forward convention: all 5 archetypes swing toward
local +Z -- backward relative to `look_at()`-driven movement, for both
rig families in this pack (`HumanArmature|Man_Walk` and
`CharacterArmature|Walk`). Added `facing_offset_y` to `NPC_MODELS`
(180 for all 5, following the same empirically-measured-correction pattern
already used for `BUILDING_MODELS`/`CAR_MODELS`), applied in
`CharacterRig._build_from_model` before the model is added to the tree.
Reverified the swing direction through the real `CharacterRig.build()`
path afterward, not just the raw fix in isolation.

**Roads not reaching anywhere:** roads spanned zone CENTER to zone CENTER,
so most of a road's length actually ran through the zone's own interior
(already covered by that zone's ground collision) -- and since structures
scatter right up to a zone's edge, 7 structures measurably overlapped a
road's collision box outright. Trimmed each road to start/end where it
actually leaves the zone's footprint (standard ray-to-box-edge distance,
since zone ground is never rotated) instead of at the zone's center.
Total road length across all 10 links dropped ~77% (e.g. downtown<->
old_town: 204 -> 31 units) with zero remaining road/structure overlap,
confirmed geometrically, and zero regression on the Round 11 road-collision
fix (physics drop test still passes at all 10 new midpoints).

**FPS:** the road trim alone cut parked-car count from 137 to ~35-45 (fewer,
shorter roads need far fewer 9-unit-spaced slots) -- a real, if incidental,
geometry win. Separately, `NPC.gd` now throttles any NPC more than 90m
from the player to a full update just twice a second instead of every
physics frame (schedule/wander logic, `move_and_slide()`, and -- the
expensive part for the Quaternius archetypes -- skeletal animation
playback all skip entirely on the throttled frames). Verified an NPC
placed 500m from the player still makes real forward progress under
throttling (not frozen), while one within range is untouched.
