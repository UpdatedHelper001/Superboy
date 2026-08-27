# Workflow fixes

The previous workflow referenced `firebelley/godot-android-build`, which GitHub
could not resolve as an action repository. That caused the job to fail during
"Set up job", before Godot even started.

The workflow has now been changed to use the `barichello/godot-ci:4.3`
container and Godot's native headless Android export command.

The workflow:
- runs on pushes to `main`/`master`, pull requests, or manually;
- checks that the Godot project and Android export preset exist;
- exports the existing `Android` preset as a debug APK;
- uploads the APK as a GitHub Actions artifact.

No release signing key is required for this debug build.

## Round 2

- **Fixed the actual cause of build failures.** `WorldGenerator.gd` uses two
  `class_name` scripts (`InteriorBuilder`, and now `TouchControls`). Godot 4
  does not resolve `class_name` references until it has scanned the project
  once and built `.godot/global_script_class_cache.cfg` — and a fresh
  `actions/checkout` has no such cache. Exporting directly on a clean
  checkout reliably failed with `Parse Error: Identifier "InteriorBuilder"
  not declared in the current scope.` This was verified by downloading the
  real Godot 4.3 binary and reproducing the failure from a fully clean
  cache, then confirming a `godot --headless --path . --import` step before
  the export fixes it. That step has been added to the workflow.
- Removed the "Prepare Godot export environment" step. Since `HOME` is
  pinned to `/root` (matching the container's own user), its copy commands
  were always copying `/root/...` onto itself — dead code that never did
  anything, just noise in the log.
- Reformatted the export command, which had collapsed onto one line with
  large gaps of spaces instead of proper `\`-continued lines (harmless to
  bash, but confusing to read/edit).
- Added a `.gitignore` (there wasn't one) excluding `.godot/` and `build/`.
  Godot regenerates `.godot/` locally the moment you open or run the
  project, and a machine-specific copy of it accidentally committed to the
  repo would shadow the fresh one the workflow builds in CI.
