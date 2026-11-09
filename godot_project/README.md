# Dark Fantasy — Godot

The six-zone GDScript port of the original Ursina game. This project targets
Windows and Android and does not share or overwrite the Ursina save data.

## Download

Use the [latest GitHub release](https://github.com/ayushbroo276/darkfantasygame/releases/latest)
for the current APK and desktop package. The Android preview APK supports
`arm64-v8a` and `armeabi-v7a` and Android 7.0 (API 24) or later. It is
debug-signed, not signed with a Play Store production key.

## Features

- Six themed zones with chapter progression, checkpoints, secrets, and completion.
- First-person movement, jumping, sprinting, wall-running, and moving platforms.
- Menus for pause, settings, and soundtrack selection; progress is saved locally.
- Six included soundtrack tracks plus MP3, OGG, and WAV import.
- Windows keyboard/mouse input and landscape Android touch controls.
- Custom Dark Fantasy project and Android launcher icons.

## Run and build

Open this directory in Godot 4.7.2 or later and run `scenes/main.tscn`.

Windows controls: **WASD** move, mouse look, **Space** jump, **Left Shift**
sprint, **E** wall-run, **Esc** pause. On Android, use the left joystick to move,
the right side to look, and the on-screen buttons for actions and settings.

Install the matching Godot export templates. To run the automated smoke test
from the repository root:

```powershell
& 'C:\path\to\Godot_v4.7.2-stable_win64_console.exe' --headless --path .\godot_project --script res://tests/smoke_test.gd --audio-driver Dummy
```

Build a portable Windows version:

```powershell
& 'C:\path\to\Godot_v4.7.2-stable_win64_console.exe' --headless --path .\godot_project --export-release 'Windows Desktop' '.\godot_project\build\windows\Dark Fantasy.exe'
```

Distribute the executable with its adjacent `.pck` file.

Export the Android preview APK:

```powershell
& 'C:\path\to\Godot_v4.7.2-stable_win64_console.exe' --headless --path .\godot_project --export-debug Android '.\godot_project\build\android\Dark-Fantasy.apk'
```

Configure JDK 17 and Android SDK 36 (including Build-Tools 36.1.0) in Godot
Editor Settings before exporting. The Android preset enables immersive
landscape mode and includes ARM64 and ARMv7 builds.

## Soundtrack

Choose **Comfort**, **Numbers**, **Resonance**, **School**, **Weeks**, or
**Undertale** from the Soundtrack menu. A fresh install starts with **Numbers**.
Choose **ADD SONG FROM PHONE** on Android or **ADD SONG** on Windows to import
an MP3, OGG, or WAV you have permission to use. Phone imports are stored in the
app's private library and are removed when the app is uninstalled.

## Performance and testing

The project uses the GL Compatibility renderer, 30 FPS target, streamed course
platforms, and low-cost lighting for integrated graphics and mobile hardware.
The smoke test checks the six zones, movement, jumping, sprinting, wall-running,
platforms, checkpoints, soundtrack selection, pause/settings input, and icon
resources. Device-specific performance, touch behavior, and Android document
picker behavior still require testing on the target device.

## Assets and permissions

Generated launcher images live in `assets/android_icons/`; the supplied artwork
is preserved there as `source_dark_fantasy.jpg`. Only distribute music or other
assets when you have permission to do so.
