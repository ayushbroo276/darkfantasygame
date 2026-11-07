# Dark Fantasy

The six-zone 3D parkour game has an original Python/Ursina desktop version and a
Godot port for Windows and Android. Both include chapter progression,
checkpoints, moving and timed obstacles, secrets, music selection, settings,
and saved progress.

## Status

- **Ursina:** the original Python project remains at the repository root and is
  unchanged. It continues to target desktop Python.
- **Godot:** a separate GDScript port named **Dark Fantasy** is in [`godot_project`](./godot_project/).
  Its Godot 4.7.2 headless startup and gameplay smoke tests cover all six zones,
  movement, jumping, sprinting, wall-running, checkpoints, moving/timed platforms,
  and the principal menus. A portable Windows export has been built and launched
  on this machine; keyboard/mouse interaction has not been physically tested.
  The package is available at
  `godot_project/build/windows/Dark Fantasy.exe` with its adjacent `.pck` file.
- **Android:** the preview APK named `Dark-Fantasy.apk` includes the corrected zone texture
  mapping and all six licensed soundtrack tracks. It also lets players import
  additional MP3, OGG, or WAV files from the phone. Version 0.3.0 has been
  exported and passed the Godot smoke test, APK signature/manifest checks, and
  bundled-track packaging checks. The app and title screen are named **Dark
  Fantasy**. The new APK still needs phone testing.
  The earlier preview was installed and launched on a realme RMX3762 (Android
  15); the landscape screen and gameplay controls were visually confirmed. The
  new soundtrack build has not yet been tested on a phone and is not signed with
  a production release key.
  The current downloadable build is the
  [Dark Fantasy 0.3.0 release](https://github.com/ayushbroo276/darkfantasygame/releases/tag/v0.3.0-android).
- **GitHub release:** [Dark Fantasy 0.3.0](https://github.com/ayushbroo276/darkfantasygame/releases/tag/v0.3.0-android).

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

Keep the six zone folders and WAV files beside `main.py`. The Ursina game uses
locally supplied soundtrack MP3s beside `main.py`; those root copies remain
ignored by Git. Licensed soundtrack copies used by the Godot game are stored in
`godot_project/assets/audio/music/` and are bundled with that version. On Android,
players can also import other MP3, OGG, or WAV files from the phone's system picker.

Saved progress and settings are local (`save.json` and `settings.json`) and are
ignored by Git.

## Checks

Run the same syntax check used by the GitHub Actions workflow:

```powershell
python -m py_compile main.py game_zones.py
```

## Android preview limitations

The Android APK is a debug-signed preview (`arm64-v8a` and `armeabi-v7a`, minimum
Android 7.0/API 24). Version 0.3.0 passed the Godot smoke test and APK
signature/manifest/package checks, including all six bundled songs. The earlier preview was installed and
launched on a realme RMX3762 running Android 15, with landscape gameplay and
touch controls visually confirmed; the updated soundtrack build and Android
document picker still need device testing. The APK is not signed with a
production release key and should not be submitted to an app store. Six
licensed soundtrack MP3s are bundled; any additional tracks imported from the
phone stay in the app's private music library and are removed on uninstall.
