# Dreamcore Horror Parkour

A six-zone 3D parkour game made with Python and Ursina. The existing desktop game
includes chapter progression, checkpoints, moving and timed obstacles, secrets,
music selection, settings, and saved progress.

## Status

- **Desktop:** the Ursina project targets desktop Python and is the version currently
  in this repository.
- **Android:** no Android APK is included. Ursina 8.3.0/Panda3D 1.10.16 in this
  project uses the desktop runtime; adding touch controls alone would not make it an
  Android application. A real mobile release needs an Android-capable engine/runtime
  port and device testing.
- **GitHub release:** no APK release has been published.

## Run on desktop

Use Python 3.10 or newer, then install the game dependency and start the game:

```powershell
python -m pip install -r requirements.txt
python main.py
```

Gameplay starts in fullscreen. Press **F11** to toggle fullscreen.

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

## Android next steps

Do not treat this desktop project as an APK. A mobile port needs a supported
Android rendering/runtime path, touch input and responsive UI, Android audio and
asset integration, and tests on real devices. The current project has not passed
those checks, so there is no APK build or install instruction to provide yet.
