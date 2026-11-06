# Dreamcore Parkour (Godot)

This is a Godot/GDScript port of the six-zone Ursina game. The original Python
project remains in the repository root and is not modified by the port.

## Current validation status

The project has passed Godot 4.7.2 headless startup and the automated gameplay
smoke test in `tests/smoke_test.gd`. The test exercises movement, jumping,
sprinting, wall-running, checkpoint landing/saving, moving and timed platforms,
pause/resume, completion/unlocks, and loading all six zones. A portable Windows
export was built and launched in both headless and desktop modes on Intel
integrated graphics. Input was simulated by the smoke test, not verified with a
physical keyboard, mouse, touchscreen, or phone.

The portable Windows package is generated under `build/windows/`. A debug-signed
Android APK is generated under `build/android/`. Its signature and package
metadata have been verified, but it has not been installed or tested on a phone.
It is a preview build, not a Play Store/release-key-signed APK.

Only the existing zone textures, generated ambience WAVs, and game SFX are
packaged. The MP3 soundtrack is intentionally not copied: its redistribution
rights have not been established. The in-game soundtrack picker uses the
included zone ambience.

## Run in Godot

Open this directory in Godot 4.7 or later and run the main scene. The Windows
controls are WASD, mouse look, Space, Left Shift, E (wall-run), and Escape.
Android uses a landscape virtual joystick, touch camera, jump, sprint, wall-run,
and settings controls.

Run the headless smoke test from the repository root:

```powershell
& 'C:\path\to\Godot_v4.7.2-stable_win64_console.exe' --headless --path .\godot_project --script res://tests/smoke_test.gd --audio-driver Dummy
```

After installing the matching Godot export templates, build the portable Windows
version from the repository root:

```powershell
& 'C:\path\to\Godot_v4.7.2-stable_win64_console.exe' --headless --path .\godot_project --export-release 'Windows Desktop' '.\godot_project\build\windows\Dreamcore Parkour.exe'
```

Distribute the generated executable and its adjacent `.pck` file together.

To create the Android preview APK, configure a compatible Android SDK and Java
installation in Godot Editor Settings, install Android export templates, and run
from the repository root:

```powershell
& 'C:\path\to\Godot_v4.7.2-stable_win64_console.exe' --headless --path .\godot_project --export-debug Android '.\godot_project\build\android\dreamcore-parkour-debug.apk'
```

Install the APK on an ARM Android device by opening it from the device's file
manager and allowing installation from that source if Android asks. The package
contains `arm64-v8a` and `armeabi-v7a` builds and requests Android 7.0 (API 24)
or later. Device compatibility, controls, and safe-area behavior have not been
confirmed. Do not redistribute it as a production-signed release.

The six zone courses are streamed around the player to reduce live object and
collision counts on low-memory hardware. Rendering targets 30 FPS and disables
real-time shadows. For Android, portrait-safe content scaling is not used:
landscape canvas scaling expands to fill wider screens without stretching the
3D view.

Progress and settings are stored under Godot's per-user `user://` directory,
not in the Ursina save file.
