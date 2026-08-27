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
