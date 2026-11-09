# Dark Fantasy (Godot)

This is a Godot/GDScript port of the six-zone Ursina game. The original Python
project remains in the repository root and is not modified by the port.

## Current validation status

The project has passed Godot 4.7.2 headless startup and the automated gameplay
smoke test in `tests/smoke_test.gd`. The test exercises movement, jumping,
sprinting, wall-running, checkpoint landing/saving, moving and timed platforms,
pause/resume, completion/unlocks, loading all six zones, texture mapping, and
custom-audio import/playback. The app label and title screen both display
**Dark Fantasy**. A portable Windows export was built and launched
in both headless and desktop modes on Intel integrated graphics. Input was
simulated by the smoke test, not verified with a physical keyboard, mouse,
touchscreen, or phone.

The portable Windows package is generated under `build/windows/`. An earlier
debug-signed Android APK was installed and launched on a realme RMX3762 running
Android 15; landscape display, gameplay textures, and touch controls were
visually confirmed. Testing 0.3.0 exposed that Android rejected bundled song
paths. Version 0.4.1 fixes resource lookup, selects Numbers for new installs,
and passes the Godot smoke test, including selection of every bundled track;
the new APK still needs phone verification. This is a preview build, not a Play
Store/release-key-signed APK. Publishing the fixed APK is complete:
[Dark Fantasy 0.4.1](https://github.com/ayushbroo276/darkfantasygame/releases/tag/v0.4.1-android).

The six licensed MP3 tracks are bundled at `assets/audio/music/` and listed on
the **Soundtrack** screen. Choose **Comfort**, **Numbers**, **Resonance**,
**School**, **Weeks**, or **Undertale** to play that track during gameplay.
You can also choose **ADD SONG FROM PHONE** on Android (or **ADD SONG** on
desktop) to import another MP3, OGG, or WAV you have permission to use. Android
opens the system document picker; the selected file is copied into the app's
private music library and appears under **YOUR SONGS**. Additional imported
songs are removed when the app is uninstalled.

## Run in Godot

Open this directory in Godot 4.7 or later and run the main scene. The Windows
controls are WASD, mouse look, Space, Left Shift, E (wall-run), and Escape.
Android uses a landscape virtual joystick, touch camera, jump, sprint, wall-run,
and settings controls.

To play the included music, open **Settings** → **CHOOSE MUSIC** (or **SOUNDTRACK**
from the title menu), then select a track under **INCLUDED SOUNDTRACKS**. To add
another song from your phone, tap **ADD SONG FROM PHONE**, select an MP3, OGG,
or WAV in Android's document picker, then choose the imported title under
**YOUR SONGS**. The system picker still needs further physical-device testing.

Run the headless smoke test from the repository root:

```powershell
& 'C:\path\to\Godot_v4.7.2-stable_win64_console.exe' --headless --path .\godot_project --script res://tests/smoke_test.gd --audio-driver Dummy
```

After installing the matching Godot export templates, build the portable Windows
version from the repository root:

```powershell
& 'C:\path\to\Godot_v4.7.2-stable_win64_console.exe' --headless --path .\godot_project --export-release 'Windows Desktop' '.\godot_project\build\windows\Dark Fantasy.exe'
```

Distribute the generated executable and its adjacent `.pck` file together.

To create the Android preview APK named `Dark-Fantasy.apk`, install the matching
Android export templates and Gradle build template. Configure JDK 17 and Android SDK 36 (including
Build-Tools 36.1.0) in Godot Editor Settings, then run from the repository root:

```powershell
& 'C:\path\to\Godot_v4.7.2-stable_win64_console.exe' --headless --path .\godot_project --export-debug Android '.\godot_project\build\android\Dark-Fantasy.apk'
```

Install the APK on an ARM Android device by opening it from the device's file
manager and allowing installation from that source if Android asks. Version
0.4.1 contains `arm64-v8a` and `armeabi-v7a` builds and requests Android 7.0
(API 24) or later. Installation and launch of the earlier preview were
confirmed on an RMX3762 running Android 15. The fixed soundtrack build, document
picker, and other devices/resolutions still need testing. Do not
redistribute it as a production-signed release.

The six zone courses are streamed around the player to reduce live object and
collision counts on low-memory hardware. Rendering targets 30 FPS and disables
real-time shadows. For Android, portrait-safe content scaling is not used:
landscape canvas scaling expands to fill wider screens without stretching the
3D view.

Progress and settings are stored under Godot's per-user `user://` directory,
not in the Ursina save file.
