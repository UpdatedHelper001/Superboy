# Building the APK via GitHub Actions

This project includes a workflow (`.github/workflows/android-build.yml`) that
automatically builds an Android **debug** APK every time you push to the
`main` branch, using a container that already has Godot 4.3 + Android export
tools installed — you don't need to install anything locally.

## One-time setup

1. Create a new GitHub repository and push this whole folder to it:
   ```bash
   git init
   git add .
   git commit -m "Initial commit: PSP open-world project"
   git branch -M main
   git remote add origin <your-repo-url>
   git push -u origin main
   ```
2. That's it — no secrets or extra config needed for the debug build.

## Getting the APK

1. Go to your repo on GitHub → **Actions** tab.
2. Open the latest **"Build Android APK"** run (it starts automatically on
   push, or click **"Run workflow"** to trigger it manually).
3. Once it finishes (green check), scroll to the **Artifacts** section at the
   bottom of the run page and download **psp-open-world-debug-apk**.
4. Unzip it — you'll get `psp-open-world-debug.apk`. Install it on an
   Android device (you'll need to allow "install from unknown sources" since
   it's unsigned for release/Play Store) or drag it into an Android
   emulator.

## Controls on the phone

The screen has three touch regions:
- **Bottom-left**: a virtual joystick — walk with a light tilt, run with a
  full tilt.
- **Right ~65% of the screen**: drag anywhere to look around.
- **Bottom-right**: tap-and-hold to jump.

Keyboard + mouse still work as before for anyone testing in the desktop
editor or a PC export.

## Notes / limits

- This builds a **debug** APK only — fine for testing on your own device,
  but not something you'd upload to the Play Store as-is.
- A real release build needs your own signing keystore (Play Store requires
  it) — I can add a release workflow + signing steps later if you want to
  publish it properly.
- If the build fails, the most common cause is the Godot project version not
  matching the `barichello/godot-ci` image tag (`4.3` here) — check
  `project.godot`'s `config_version`/`features` line if you upgrade Godot
  later.
