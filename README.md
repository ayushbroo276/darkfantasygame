# Dreamcore Horror Parkour

A six-zone 3D parkour game made with Python and Ursina. The existing desktop game
includes chapter progression, checkpoints, moving and timed obstacles, secrets,
music selection, settings, and saved progress.

## Status

- **Ursina:** the original Python project remains at the repository root and is
  unchanged. It continues to target desktop Python.
- **Godot:** a separate GDScript port is in [`godot_project`](./godot_project/).
  Its Godot 4.7.2 headless startup and gameplay smoke tests cover all six zones,
  movement, jumping, sprinting, wall-running, checkpoints, moving/timed platforms,
  and the principal menus. A portable Windows export has been built and launched
  on this machine; keyboard/mouse interaction has not been physically tested.
  The package is available at
  `godot_project/build/windows/DreamcoreParkour-Windows.zip`.
- **Android:** a debug-signed preview APK is available from the release below.
  The Godot project has landscape/touch support; the APK has been signature-
  checked but not installed or tested on a phone and is not signed with a
  production release key. Download it from the
  [Android Preview release](https://github.com/ayushbroo276/darkfantasygame/releases/tag/v0.1.0-android-preview).
- **GitHub release:** [Android Preview 0.1.0](https://github.com/ayushbroo276/darkfantasygame/releases/tag/v0.1.0-android-preview)
  (pre-release; device testing pending).

## Run on desktop

Use Python 3.10 or newer, then install the game dependency and start the game:

```powershell
python -m pip install -r requirements.txt
python main.py
```

Gameplay starts in fullscreen. Press **F11** to toggle fullscreen.

## Run the Godot port

Install Godot 4.7 or later, open the `godot_project` directory, and run the main
scene. It targets 30 FPS with low-cost rendering defaults. Windows controls are
WASD, mouse look, **Space** to jump, **Left Shift** to sprint, **E** to wall-run,
and **Escape** to pause. Android uses a virtual joystick, touch camera, and
on-screen action buttons.

The Godot port keeps its saves in Godot's per-user `user://` folder; it does not
modify or reuse the Ursina `save.json`.

## Controls

| Action | Control |
| --- | --- |
| Move | WASD |
| Look | Mouse |
| Jump | Space |
| Sprint | Hold Left Shift |
| Wall run | Hold W beside a wall while airborne |
| Pause | Esc |
| Toggle fullscreen | F11 |
| Quit | F10 |

## Project layout

- `main.py` — game startup, player/controller, menus, saves, audio, and progression.
- `game_zones.py` — six chapter themes, routes, obstacles, checkpoints, and scenery.
- `zone1_the_beginning/` through `zone6_the_tower/` — chapter texture assets.
- `zone*_ambient.wav` and `game_sfx.wav` — generated ambience and gameplay cue.

Keep the six zone folders and WAV files beside `main.py`. The six soundtrack MP3s
are intentionally not tracked: only add and distribute music you have permission
to use. Place locally licensed tracks beside `main.py` using the expected filenames
(`resonance.mp3`, `weeks.mp3`, `comfort.mp3`, `school.mp3`, `numbers.mp3`, and
`undertale.mp3`).

Saved progress and settings are local (`save.json` and `settings.json`) and are
ignored by Git.

## Checks

Run the same syntax check used by the GitHub Actions workflow:

```powershell
python -m py_compile main.py game_zones.py
```

## Android preview limitations

The Android APK is a debug-signed preview (`arm64-v8a` and `armeabi-v7a`, minimum
Android 7.0/API 24). It has passed signature and manifest checks but has not been
installed or tested on a phone; joystick, camera, fullscreen, and safe-area
behavior remain unverified on physical hardware. It is not signed with a
production release key and should not be submitted to an app store.
