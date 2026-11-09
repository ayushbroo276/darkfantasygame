# Dark Fantasy

**A six-zone dreamcore parkour game through surreal, liminal worlds.**

The repository includes the original Python/Ursina desktop game and a separate
Godot/GDScript port for Windows and Android. The original Ursina project is kept
alongside the port.

> **Get the latest game:** [Download the newest release](https://github.com/ayushbroo276/darkfantasygame/releases/latest)
> — the release page is the recommended place to get the current Android APK
> and any available desktop build.

## Explore

- Six atmospheric zones, checkpoints, moving platforms, and timed challenges.
- First-person movement, jumping, sprinting, and wall-running.
- Chapter progression, saved progress, completion screens, and pause/settings menus.
- Six bundled soundtrack selections, with support for importing your own audio.
- Windows keyboard/mouse controls and Android touch controls.

## Play the Godot version

Open [`godot_project`](./godot_project/) in **Godot 4.7.2** and run the main
scene. On Windows, use **WASD** to move, the mouse to look, **Space** to jump,
**Left Shift** to sprint, **E** to wall-run, and **Esc** to pause. Android uses a
landscape joystick, touch camera, and on-screen action buttons.

For a packaged game, use the [latest release](https://github.com/ayushbroo276/darkfantasygame/releases/latest).
The Android preview APK supports ARM64 and ARMv7 devices and requires Android 7.0
(API 24) or later. It is debug-signed, not signed with a Play Store production
key. See the [Godot guide](./godot_project/README.md) for build instructions,
music details, and current testing limitations.

## Play the original Ursina version

Use Python 3.10 or later:

```powershell
python -m pip install -r requirements.txt
python main.py
```

Gameplay starts fullscreen; press **F11** to toggle fullscreen.

## Project map

- `main.py`, `game_zones.py`, `zone*/` — original Python/Ursina game.
- `godot_project/` — Godot scenes, scripts, assets, tests, and export settings.
- `godot_project/assets/android_icons/` — launcher and adaptive icon artwork.

The Godot port stores saves in its own per-user `user://` directory. Its
licensed soundtrack files are bundled under `godot_project/assets/audio/music/`;
only redistribute audio or other assets when you have permission to do so.

## Verify

Run the Godot smoke test from the repository root with Godot 4.7.2:

```powershell
& 'C:\path\to\Godot_v4.7.2-stable_win64_console.exe' --headless --path .\godot_project --script res://tests/smoke_test.gd --audio-driver Dummy
```

Check the original Python sources:

```powershell
python -m py_compile main.py game_zones.py
```

## Limitations

The Android APK is a debug-signed preview. Device-specific performance,
touchscreen behavior, and imported-song support may vary; the latest release
notes describe the tested hardware and known issues. Windows builds are portable
and require the executable and its adjacent `.pck` file together.
