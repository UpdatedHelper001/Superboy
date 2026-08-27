# Workflow fixes

- Replaced the Android GitHub Actions workflow.
- Added/ensured an Android export preset.
- Supports pushes to main/master.
- Added manual workflow_dispatch.
- Added checkout permissions.
- Removed the malformed duplicate display section.

If the Actions log still shows a project-specific error, the first red error line will identify whether it is a Godot script, Android SDK/JDK, export preset, or signing configuration issue.
