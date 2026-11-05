import os
import json
import math
from time import perf_counter
from pathlib import Path  # Lets Ursina load the sky from this script's folder.
from ursina import *
from ursina.prefabs.first_person_controller import FirstPersonController
from panda3d.core import TransparencyAttrib
from game_zones import (
    CollapsingPlatform,
    FlickeringLight,
    MovingPlatform,
    RotatingPlatform,
    TimedDoor,
    TimedPlatform,
    ZONE_CONFIGS,
    build_zone,
)
from ursina.audio import audio_groups
import random

app = Ursina()
window.color = color.black
window.fullscreen = True

BASE = os.path.dirname(os.path.abspath(__file__))
SAVE_FILE = os.path.join(BASE, 'save.json')
SETTINGS_FILE = os.path.join(BASE, 'settings.json')
texture_cache = {}

# Load saved game progress and settings, or start with safe defaults.
def read_json_file(path, defaults):
    if not os.path.isfile(path):
        return defaults.copy()
    try:
        with open(path, 'r', encoding='utf-8') as file:
            data = json.load(file)
        if isinstance(data, dict):
            return data
        print('Save file has an invalid format: ' + path)
    except (OSError, json.JSONDecodeError) as error:
        print('Could not read save file ' + path + ': ' + str(error))
    return defaults.copy()


progress_data = read_json_file(SAVE_FILE, {
    'unlocked_zones': [1],
    'current_zone': 1,
    'checkpoint': None,
    'secrets': [],
    'best_times': {},
})
if not isinstance(progress_data.get('best_times'), dict):
    progress_data['best_times'] = {}
settings_data = read_json_file(SETTINGS_FILE, {
    'graphics': 'high',
    'music_volume': 1.0,
    'ambient_volume': 0.25,
    'sfx_volume': 0.8,
    'master_volume': 1.0,
    'mouse_sensitivity': 40,
    'show_fps': False,
    'sprint_multiplier': 1.7,
})
graphics_level = settings_data.get('graphics', 'high')
if graphics_level not in ('low', 'medium', 'high'):
    graphics_level = 'high'
try:
    music_volume = max(0.0, min(1.0, float(settings_data.get('music_volume', 1.0))))
except (TypeError, ValueError):
    print('Invalid saved music volume; using full volume.')
    music_volume = 1.0
try:
    ambient_volume = max(0.0, min(1.0, float(settings_data.get('ambient_volume', 0.25))))
    sfx_volume = max(0.0, min(1.0, float(settings_data.get('sfx_volume', 0.8))))
    master_volume = max(0.0, min(1.0, float(settings_data.get('master_volume', 1.0))))
except (TypeError, ValueError):
    print('Invalid saved audio volume; using safe defaults.')
    ambient_volume, sfx_volume, master_volume = 0.25, 0.8, 1.0
try:
    mouse_sensitivity = max(10, min(100, int(settings_data.get('mouse_sensitivity', 40))))
except (TypeError, ValueError):
    print('Invalid saved mouse sensitivity; using the default.')
    mouse_sensitivity = 40
show_fps = bool(settings_data.get('show_fps', False))
try:
    sprint_multiplier = max(1.3, min(2.2, float(settings_data.get('sprint_multiplier', 1.7))))
except (TypeError, ValueError):
    print('Invalid saved sprint speed; using the default.')
    sprint_multiplier = 1.7


# Save progress and basic settings as readable JSON files.
def write_json_file(path, data):
    temporary_path = path + '.tmp'
    try:
        with open(temporary_path, 'w', encoding='utf-8') as file:
            json.dump(data, file, indent=2)
        os.replace(temporary_path, path)
    except OSError as error:
        print('Could not save file ' + path + ': ' + str(error))


# Load a texture from the main folder or a zone subfolder, with a safe fallback.
def load_zone_texture(name, folder=''):
    cache_key = (folder, name)
    if cache_key in texture_cache:
        return texture_cache[cache_key]
    texture_folder = Path(BASE) / folder
    texture_file = None
    for extension in ('.png', '.jpg', '.jpeg'):
        possible_file = texture_folder / (name + extension)
        if os.path.isfile(possible_file):
            texture_file = str(possible_file)
            break
    if texture_file:
        texture_name = os.path.splitext(os.path.basename(texture_file))[0]
        texture = load_texture(texture_name, folder=texture_folder)
        if texture:
            texture_cache[cache_key] = texture
            return texture
    print('Missing texture: ' + name)
    texture_cache[cache_key] = None
    return None

# Use the night-sky image when it exists, and a dark color when it does not.
sky_texture = load_zone_texture('sky')
if sky_texture:
    Sky(texture=sky_texture)  # Show the custom sky image.
else:
    Sky(color=color.rgb32(40, 10, 50))  # Use a dark night-color sky as a fallback.

# Keep the root wall texture available as a fallback for older map helpers.
wall_texture = load_zone_texture('wall')
HAS_WALL = wall_texture is not None

# Load the existing menu background and logo images.
menu_bg_texture = load_zone_texture('menu_bg')
logo_texture = load_zone_texture('logo')

# ---- COLORS (change these to restyle the map) ----
wall_color = color.rgb32(150, 130, 50)  # Yellowish stone fallback.
floor_color = color.rgb32(70, 60, 30)   # Dark brown floor fallback.
vine_color = color.rgb32(30, 110, 30)   # Green vine-card fallback.

def make_wall(pos, scale, texture_scale=(4, 4)):
    # Uses wall.png if you added one, otherwise uses the color
    if HAS_WALL:
        return Entity(model='cube', texture=wall_texture, texture_scale=texture_scale,
                      color=color.white, position=pos, scale=scale, collider='box')
    return Entity(model='cube', color=wall_color,
                  position=pos, scale=scale, collider='box')

# ---- SONGS ----
songs = {
    "1. Resonance": 'resonance',
    "2. Weeks": 'weeks',
    "3. Comfort": 'comfort',
    "4. School": 'school',
    "5. Numbers": 'numbers',
    "6. Undertale": 'undertale',
}

song_players = {}
for name, file in songs.items():
    song_players[name] = Audio(file, loop=True, autoplay=False, group='music')

# Reuse one low-volume ambience player and one short sound-effect player.
ambient_player = Audio('zone1_ambient', loop=True, autoplay=False, group='ambient')
sfx_player = Audio('game_sfx.wav', autoplay=False, group='sfx')


# Apply the saved master and per-category audio levels.
def apply_audio_mix():
    Audio.volume_multiplier = master_volume
    audio_groups['music'].volume_multiplier = 1
    audio_groups['ambient'].volume_multiplier = ambient_volume
    audio_groups['sfx'].volume_multiplier = sfx_volume
    for player_audio in song_players.values():
        player_audio.volume = music_volume
    ambient_player.volume = 0.22
    sfx_player.volume = 1


apply_audio_mix()


# Play one short shared cue for checkpoints, collectibles, and collapsing stones.
def play_game_sfx():
    sfx_player.stop(destroy=False)
    sfx_player.play()


# Switch the single looping ambience player to the selected chapter.
def set_zone_ambience(zone_number):
    ambient_player.stop(destroy=False)
    ambient_player.clip = Path(BASE) / ('zone' + str(zone_number) + '_ambient.wav')
    ambient_player.loop = True
    ambient_player.volume = 0.22
    ambient_player.play()

selected_song = progress_data.get('selected_song', None)
if selected_song not in songs:
    selected_song = None
current_song = None

def play_song(name):
    global current_song, selected_song
    if current_song:
        current_song.stop()
    current_song = song_players[name]
    current_song.volume = music_volume
    current_song.play()
    selected_song = name
    progress_data['selected_song'] = name
    write_json_file(SAVE_FILE, progress_data)
    now_playing.text = 'Now playing: ' + name

# ---- GRAPHICS ----
vines = []
zone_data = None

def set_graphics(level):
    global graphics_level
    graphics_level = level
    if level == 'low':
        scene.fog_color = color.clear  # Use a transparent fog color to turn shader fog off.
        scene.fog_density = (0, 70)  # Keep the fog distance ready for the other settings.
        for i, v in enumerate(vines):
            v.enabled = (i % 2 == 0)
    elif level == 'medium':
        scene.fog_color = color.clear  # Keep the middle setting free of fog.
        scene.fog_density = (0, 70)  # Keep the fog distance ready for the other settings.
        for v in vines:
            v.enabled = True
    elif level == 'high':
        fog = zone_data['fog_color'] if zone_data else color.rgb32(40, 20, 25)
        scene.fog_color = color.rgba(fog.x, fog.y, fog.z, 1)
        scene.fog_density = (30, 120)  # Fade distant scenery without hiding nearby walls.
        for v in vines:
            v.enabled = True
    graphics_text.text = 'Graphics: ' + level.upper()
    settings_data['graphics'] = level
    write_json_file(SETTINGS_FILE, settings_data)
    if zone_data:
        update_zone_streaming(force=True)

# ---- MENU ----
menu = Entity(parent=camera.ui, enabled=False)
# Use the menu image as a background, or keep the original dark panel.
Entity(parent=menu, model='quad',
       texture=menu_bg_texture,
       color=color.white if menu_bg_texture else color.rgba(0, 0, 0, 0.85),
       scale=(2, 1.6))
Text("MENU  (Esc to close)", parent=menu, y=0.65, origin=(0, 0), scale=1.5)

# Show the logo in the top-right corner of the menu when available.
if logo_texture:
    Entity(parent=menu, model='quad', texture=logo_texture, color=color.white,
           position=(0.78, 0.69), scale=(0.22, 0.12))

Text("SONGS", parent=menu, x=-0.45, y=0.5, origin=(0, 0), scale=1.2)
for i, name in enumerate(songs):
    Button(text=name, parent=menu, scale=(0.5, 0.07), x=-0.45, y=0.38 - i * 0.12,
           color=color.dark_gray, highlight_color=color.gray,
           on_click=lambda n=name: play_song(n))

Text("GRAPHICS", parent=menu, x=0.45, y=0.5, origin=(0, 0), scale=1.2)
graphics_text = Text("Graphics: HIGH", parent=menu, x=0.45, y=0.42, origin=(0, 0), scale=1)
for i, level in enumerate(['low', 'medium', 'high']):
    Button(text=level.capitalize(), parent=menu, scale=(0.4, 0.07), x=0.45,
           y=0.3 - i * 0.12, color=color.dark_gray, highlight_color=color.gray,
           on_click=lambda l=level: set_graphics(l))

Button(text='QUIT', parent=menu, scale=(0.4, 0.08), x=0, y=-0.74,
       color=color.red, highlight_color=color.orange,
       on_click=application.quit)

now_playing = Text("Now playing: nothing", origin=(-0.5, 0), x=-0.85, y=0.45, scale=1)

def toggle_menu():
    global game_paused
    if not gameplay_active:
        return
    menu.enabled = not menu.enabled
    game_paused = menu.enabled
    player.enabled = not menu.enabled
    mouse.locked = not menu.enabled
    if menu.enabled:
        ambient_player.stop(destroy=False)
    else:
        set_zone_ambience(current_zone)

def input(key):
    if key == 'space' and gameplay_active and player.grounded:
        show_tutorial('jump', 'JUMP — PRESS SPACE')
    if key == 'escape':
        if gameplay_active:
            if settings_screen.enabled or controls_screen.enabled or audio_screen.enabled:
                close_settings()
            else:
                toggle_menu()
        elif soundtrack_screen.enabled:
            show_menu_screen('title')
        elif settings_screen.enabled or controls_screen.enabled or audio_screen.enabled:
            close_settings()
        elif new_game_screen.enabled:
            close_new_game_confirmation()
        elif menu.enabled:
            menu.enabled = False
            title_screen.enabled = True
            soundtrack_screen.enabled = False
    if key == 'f10':
        application.quit()
    if key == 'f11':
        window.fullscreen = not window.fullscreen

# ---- PLAYER ----
# Catch a missed landing when a fast fall crosses a platform between frames.
class CollisionSafeFirstPersonController(FirstPersonController):
    def __init__(self, **kwargs):
        self.walkable_surfaces = []
        self.walkable_bins = {}
        self.catch_floor = None
        super().__init__(**kwargs)
        self.normal_walk_speed = self.speed
        self.sprint_multiplier = sprint_multiplier

    def update(self):
        # Advance only the nearby parkour objects to keep long chapters light.
        first_active_bin = int(self.world_z // 16) - 2
        last_active_bin = int(self.world_z // 16) + 2
        active_surfaces = []
        for bin_number in range(first_active_bin, last_active_bin + 1):
            active_surfaces.extend(self.walkable_bins.get(bin_number, ()))
        for surface in active_surfaces:
            if isinstance(surface, MovingPlatform):
                surface.advance(time.dt)
            elif isinstance(surface, TimedPlatform):
                surface.advance(time.dt)
            elif isinstance(surface, RotatingPlatform):
                surface.advance(time.dt)
            elif isinstance(surface, CollapsingPlatform):
                was_enabled = surface.enabled
                surface.advance(self, time.dt)
                if was_enabled and not surface.enabled:
                    play_game_sfx()
        for door in zone_data['timed_doors'] if zone_data else ():
            door.advance(time.dt)
        for lamp in zone_data['flickering_lights'] if zone_data else ():
            lamp.advance(time.dt)

        # Carry a grounded player along with the moving platform they stand on.
        carried_platform = None
        if self.grounded:
            for surface in active_surfaces:
                if not isinstance(surface, MovingPlatform):
                    continue
                old_position = surface.previous_position
                old_top = old_position.y + surface.world_scale.y / 2
                if (abs(self.y - old_top) <= 0.15
                        and abs(self.x - old_position.x) <= surface.world_scale.x / 2 + 0.25
                        and abs(self.z - old_position.z) <= surface.world_scale.z / 2 + 0.25):
                    self.position += surface.movement_delta
                    carried_platform = surface
                    break

        # Smoothly blend between normal walking and sprinting.
        target_speed = self.normal_walk_speed
        if held_keys['left shift']:
            target_speed *= self.sprint_multiplier
        speed_blend = min(1, time.dt * 8)
        self.speed += (target_speed - self.speed) * speed_blend

        previous = Vec3(self.world_x, self.world_y, self.world_z)
        super().update()
        current = Vec3(self.world_x, self.world_y, self.world_z)

        # Check only nearby platforms, plus the single deep safety floor.
        first_bin = int(min(previous.z, current.z) // 16) - 1
        last_bin = int(max(previous.z, current.z) // 16) + 1
        nearby_surfaces = []
        for bin_number in range(first_bin, last_bin + 1):
            nearby_surfaces.extend(self.walkable_bins.get(bin_number, ()))
        if self.catch_floor:
            floor_top = self.catch_floor.world_y + self.catch_floor.world_scale_y / 2
            if min(previous.y, current.y) <= floor_top + 1:
                nearby_surfaces.append(self.catch_floor)

        for surface in nearby_surfaces:
            if not surface.enabled:
                continue

            surface_position = surface.world_position
            surface_scale = surface.world_scale
            if isinstance(surface, MovingPlatform) and surface is not carried_platform:
                old_surface_position = surface.previous_position
            else:
                old_surface_position = surface_position
            old_top = old_surface_position.y + surface_scale.y / 2
            new_top = surface_position.y + surface_scale.y / 2
            if min(previous.y, current.y) > max(old_top, new_top) + self.height:
                continue
            if max(previous.y, current.y) < min(old_top, new_top):
                continue
            previous_gap = previous.y - old_top
            current_gap = current.y - new_top
            relative_fall = previous_gap - current_gap
            if previous_gap < 0 or current_gap > 0 or relative_fall <= 0:
                continue

            crossing = previous_gap / relative_fall
            crossing_x = previous.x + (current.x - previous.x) * crossing
            crossing_z = previous.z + (current.z - previous.z) * crossing
            crossing_surface_x = old_surface_position.x + (
                surface_position.x - old_surface_position.x
            ) * crossing
            crossing_surface_z = old_surface_position.z + (
                surface_position.z - old_surface_position.z
            ) * crossing
            previous_rotation = getattr(surface, 'previous_rotation_y', surface.rotation_y)
            rotation_change = (surface.rotation_y - previous_rotation + 180) % 360 - 180
            rotation = previous_rotation + rotation_change * crossing
            angle = math.radians(rotation)
            offset_x = crossing_x - crossing_surface_x
            offset_z = crossing_z - crossing_surface_z
            local_x = math.cos(angle) * offset_x + math.sin(angle) * offset_z
            local_z = -math.sin(angle) * offset_x + math.cos(angle) * offset_z
            if (abs(local_x) <= surface_scale.x / 2 + 0.25
                    and abs(local_z) <= surface_scale.z / 2 + 0.25):
                self.position = Vec3(crossing_x, new_top, crossing_z)
                self.land()
                return


start_pos = Vec3(0, 2, 0)
player = CollisionSafeFirstPersonController(position=start_pos)
player.mouse_sensitivity = Vec2(mouse_sensitivity, mouse_sensitivity)
player.sprint_multiplier = sprint_multiplier

# Teleport cleanly without a leftover jump animation changing the new position.
def reset_player_position(position):
    if hasattr(player, 'y_animator') and player.y_animator is not None:
        player.y_animator.pause()
    player.position = Vec3(position.x, position.y, position.z)
    player.air_time = 0
    player.grounded = False
    player.gravity = 1


# Restore the unlocked chapters, keeping Zone 1 available in every save.
current_zone = progress_data.get('current_zone', 1)
if not isinstance(current_zone, int) or not 1 <= current_zone <= len(ZONE_CONFIGS):
    current_zone = 1
unlocked_zones = progress_data.get('unlocked_zones', [1])
if not isinstance(unlocked_zones, list):
    unlocked_zones = [1]
unlocked_zones = sorted(set(zone for zone in unlocked_zones
                            if isinstance(zone, int) and 1 <= zone <= len(ZONE_CONFIGS)))
if 1 not in unlocked_zones:
    unlocked_zones.insert(0, 1)
collected_secrets = progress_data.get('secrets', [])
if not isinstance(collected_secrets, list):
    collected_secrets = []
tutorials_seen = progress_data.get('tutorials_seen', [])
if not isinstance(tutorials_seen, list):
    tutorials_seen = []
zone_started_at = 0

# Save the player's current chapter and checkpoint.
def save_progress():
    progress_data['unlocked_zones'] = unlocked_zones
    progress_data['current_zone'] = current_zone
    progress_data['checkpoint'] = [checkpoint_pos.x, checkpoint_pos.y, checkpoint_pos.z]
    progress_data['secrets'] = collected_secrets
    progress_data['tutorials_seen'] = tutorials_seen
    write_json_file(SAVE_FILE, progress_data)


# Keep only nearby course sections active while retaining shared floor and walls.
def update_zone_streaming(force=False):
    if not zone_data:
        return
    center = math.floor(player.world_z / 64)
    if not force and zone_data['active_stream_center'] == center:
        return
    zone_data['active_stream_center'] = center
    active_bins = range(center - 2, center + 3)
    for entity in zone_data['stream_global_entities']:
        entity.enabled = True
    vine_indexes = {id(vine): index for index, vine in enumerate(zone_data['vines'])}
    for bin_number, entities in zone_data['stream_bins'].items():
        enabled = bin_number in active_bins
        for entity in entities:
            vine_index = vine_indexes.get(id(entity))
            if vine_index is not None and graphics_level == 'low':
                entity.enabled = enabled and vine_index % 2 == 0
            else:
                entity.enabled = enabled


# Replace the current map with the selected chapter's assets and course.
def load_zone(zone_number, use_saved_checkpoint=False):
    global current_zone, zone_data, walls, parkour, zone_entities
    global walkable_surfaces, vines
    global checkpoint_pos, checkpoint_reached, goal, zone_started_at

    for entity in zone_entities:
        destroy(entity)
    current_zone = zone_number
    zone_data = build_zone(zone_number, load_zone_texture)
    zone_entities = zone_data['entities']
    for secret in list(zone_data['secrets']):
        if secret.secret_id in collected_secrets:
            secret_bin = math.floor(secret.world_z / 64)
            zone_data['stream_bins'][secret_bin].remove(secret)
            destroy(secret)
            zone_entities.remove(secret)
            zone_data['secrets'].remove(secret)
    walls = zone_data['walls']
    parkour = zone_data['positions']
    vines = zone_data['vines']
    player.walkable_surfaces = zone_data['walkable_surfaces']
    player.walkable_bins = zone_data['walkable_bins']
    player.catch_floor = zone_data['catch_floor']
    checkpoint_pos = zone_data['start_pos']
    checkpoint_reached = False
    if use_saved_checkpoint and progress_data.get('current_zone') == zone_number:
        saved = progress_data.get('checkpoint')
        if isinstance(saved, list) and len(saved) == 3:
            try:
                saved_position = Vec3(*(float(value) for value in saved))
                if (-15 <= saved_position.x <= 15 and
                        0 <= saved_position.y <= 20 and
                        0 <= saved_position.z <= zone_data['positions'][-1][2]):
                    checkpoint_pos = saved_position
                    checkpoint_reached = True
            except (TypeError, ValueError):
                print('Saved checkpoint is invalid; starting at the chapter entrance.')
    reset_player_position(checkpoint_pos)
    goal = zone_data['goal']
    zone_started_at = perf_counter()
    set_graphics(graphics_level)
    save_progress()


# Start or resume a chapter and lock the mouse for first-person play.
def start_game(zone_number, use_saved_checkpoint=False):
    global gameplay_active, game_paused
    if zone_number not in unlocked_zones:
        return
    load_zone(zone_number, use_saved_checkpoint)
    win_text.enabled = False
    status_text.text = ''
    title_screen.enabled = False
    chapters_screen.enabled = False
    settings_screen.enabled = False
    completion_screen.enabled = False
    menu.enabled = False
    gameplay_active = True
    game_paused = False
    player.enabled = True
    mouse.locked = True
    set_zone_ambience(zone_number)
    if current_song is None:
        play_song(selected_song or next(iter(songs)))
    show_tutorial('sprint', 'SPRINT — HOLD LEFT SHIFT')


# Return to the title screen without unloading the current chapter.
def return_to_title():
    global gameplay_active, game_paused
    gameplay_active = False
    game_paused = False
    player.enabled = False
    mouse.locked = False
    ambient_player.stop(destroy=False)
    new_game_screen.enabled = False
    menu.enabled = False
    completion_screen.enabled = False
    title_screen.enabled = True


# Start with a map that will be replaced when a chapter is selected.
walls = []
parkour = []
walkable_surfaces = []
zone_entities = []
zone_data = None
checkpoint_pos = Vec3(start_pos.x, start_pos.y, start_pos.z)
checkpoint_reached = False
gameplay_active = False
game_paused = False
goal = None
win_text = Text("YOU MADE IT", origin=(0, 0), scale=2, enabled=False)

# Create the initial chapter and restore its saved checkpoint, if any.
load_zone(current_zone, use_saved_checkpoint=True)
player.enabled = False

# ---- WALL RUN ----
wall_time = 0

def can_wall_run():
    origin = player.world_position + Vec3(0, 1, 0)
    for direction in (player.right, -player.right):
        hit = raycast(origin, direction, distance=1.5, ignore=(player,))
        if hit.hit and hit.entity in walls:
            return True
    return False

def update():
    global wall_time, checkpoint_pos, checkpoint_reached, gameplay_active
    global tutorial_timer

    if fps_text.enabled and time.dt > 0:
        fps_text.text = 'FPS: ' + str(int(1 / time.dt))
    if tutorial_timer > 0:
        tutorial_timer = max(0, tutorial_timer - time.dt)
        tutorial_text.color = color.rgba(1, 0.9, 0.55, min(1, tutorial_timer))
        if tutorial_timer == 0:
            tutorial_text.enabled = False
    if not gameplay_active or game_paused:
        return

    update_zone_streaming()
    goal.rotation_y += 90 * time.dt

    # Teach each special obstacle the first time the player reaches it.
    if tutorial_timer == 0:
        nearby = lambda objects, radius: any(
            distance(player, obstacle) < radius for obstacle in objects
        )
        if nearby(zone_data['moving_platforms'], 12):
            show_tutorial('moving_platform', 'MOVING PLATFORM — WATCH THE PATH AND TIME YOUR JUMP.')
        elif nearby(zone_data['timed_platforms'], 10):
            show_tutorial('timed_platform', 'TIMED STEP — CROSS WHILE THE PLATFORM IS VISIBLE.')
        elif nearby(zone_data['collapsing_platforms'], 10):
            show_tutorial('collapsing_platform', 'COLLAPSING STEP — KEEP MOVING AFTER YOU LAND.')
        elif nearby(zone_data['rotating_platforms'], 10):
            show_tutorial('rotating_platform', 'ROTATING STEP — FACE THE NEXT PLATFORM BEFORE JUMPING.')
        elif nearby(zone_data['timed_doors'], 12):
            show_tutorial('timed_door', 'TIMED GATE — WAIT FOR THE GREEN LIGHT, THEN RUN THROUGH.')
        elif nearby(zone_data['wall_run_walls'], 10):
            show_tutorial('wall_run', 'WALL RUN — HOLD W BESIDE THE WALL WHILE AIRBORNE.')

    if player.grounded:
        wall_time = 0
        player.gravity = 1
    elif held_keys['w'] and can_wall_run() and wall_time < 1.5:
        wall_time += time.dt
        player.gravity = 0
    else:
        player.gravity = 1

    # Save each checkpoint when the player lands on its platform.
    for checkpoint in zone_data['checkpoints']:
        if (player.grounded and abs(player.x - checkpoint.x) <= 2
                and abs(player.z - checkpoint.z) <= 2
                and player.y > checkpoint.y
                and checkpoint.z > checkpoint_pos.z):
            checkpoint_pos = Vec3(checkpoint.x, checkpoint.y + 1.5, checkpoint.z)
            checkpoint_reached = True
            save_progress()
            status_text.text = 'Checkpoint saved'
            play_game_sfx()

    # Collect optional secret items and remember them between sessions.
    for secret in list(zone_data['secrets']):
        if distance(player, secret) < 1.5:
            secret_bin = math.floor(secret.world_z / 64)
            zone_data['stream_bins'][secret_bin].remove(secret)
            if secret.secret_id not in collected_secrets:
                collected_secrets.append(secret.secret_id)
            destroy(secret)
            zone_entities.remove(secret)
            zone_data['secrets'].remove(secret)
            save_progress()
            status_text.text = 'Secret found'
            play_game_sfx()

    # Return to the saved checkpoint if the player falls.
    if player.y < -12:
        reset_player_position(checkpoint_pos)

    if distance(player, goal) < 3:
        ambient_player.stop(destroy=False)
        elapsed = perf_counter() - zone_started_at
        win_text.enabled = True
        gameplay_active = False
        player.enabled = False
        mouse.locked = False
        if current_zone < len(ZONE_CONFIGS):
            next_zone = current_zone + 1
            if next_zone not in unlocked_zones:
                unlocked_zones.append(next_zone)
        progress_data['completed_zone_' + str(current_zone)] = True
        best_times = progress_data.setdefault('best_times', {})
        best_time = best_times.get(str(current_zone))
        if not isinstance(best_time, (int, float)) or elapsed < best_time:
            best_times[str(current_zone)] = round(elapsed, 1)
        save_progress()
        minutes = int(elapsed // 60)
        seconds = int(elapsed % 60)
        completion_title.text = 'YOU MADE IT\n' + zone_data['name']
        completion_time.text = 'Time: {:02d}:{:02d}'.format(minutes, seconds)
        completion_next_button.text = (
            'NEXT CHAPTER' if current_zone < len(ZONE_CONFIGS) else 'FINISH GAME'
        )
        completion_screen.enabled = True


# Continue to the next chapter, or return to the title after the last one.
def next_chapter():
    if current_zone < len(ZONE_CONFIGS):
        start_game(current_zone + 1)
    else:
        return_to_title()


# Show the title menu, chapter picker, settings, and chapter-complete screen.
title_screen = Entity(parent=camera.ui, enabled=True)
Entity(parent=title_screen, model='quad', texture=menu_bg_texture,
       color=color.white if menu_bg_texture else color.black, scale=(2, 1.6))
if logo_texture:
    Entity(parent=title_screen, model='quad', texture=logo_texture, color=color.white,
           position=(0, 0.55), scale=(0.45, 0.22))
Text('DREAMCORE PARKOUR', parent=title_screen, y=0.32, origin=(0, 0), scale=1.6)
Button(text='PLAY', parent=title_screen, y=0.12, scale=(0.38, 0.075),
       on_click=lambda: start_game(1))
Button(text='CONTINUE', parent=title_screen, y=0.02, scale=(0.38, 0.075),
       on_click=lambda: start_game(current_zone, True))
Button(text='CHAPTERS', parent=title_screen, y=-0.08, scale=(0.38, 0.075),
       on_click=lambda: show_menu_screen('chapters'))
Button(text='SETTINGS', parent=title_screen, y=-0.18, scale=(0.38, 0.075),
       on_click=lambda: show_menu_screen('settings'))
Button(text='SOUNDTRACK', parent=title_screen, y=-0.28, scale=(0.38, 0.075),
       on_click=lambda: show_menu_screen('soundtrack'))
Button(text='CONTROLS', parent=title_screen, y=-0.38, scale=(0.38, 0.075),
       on_click=lambda: show_menu_screen('controls'))
Button(text='AUDIO', parent=title_screen, y=-0.48, scale=(0.38, 0.075),
       on_click=lambda: show_menu_screen('audio'))
Button(text='NEW GAME', parent=title_screen, y=-0.58, scale=(0.38, 0.075),
       on_click=lambda: show_new_game_confirmation())
Button(text='QUIT GAME', parent=title_screen, y=-0.68, scale=(0.38, 0.075),
       color=color.red, on_click=application.quit)

# Confirm before clearing saved chapters, secrets, and tutorial progress.
new_game_screen = Entity(parent=camera.ui, enabled=False)
Entity(parent=new_game_screen, model='quad', color=color.rgba(0, 0, 0, 0.94),
       scale=(2, 1.6))
Text('START A NEW GAME?', parent=new_game_screen, y=0.16,
     origin=(0, 0), scale=1.3)
Text('This will reset saved chapter progress.', parent=new_game_screen,
     y=0.03, origin=(0, 0), scale=0.8)
Button(text='RESET PROGRESS', parent=new_game_screen, x=-0.23, y=-0.12,
       scale=(0.38, 0.08), color=color.orange,
       on_click=lambda: start_new_game())
Button(text='CANCEL', parent=new_game_screen, x=0.23, y=-0.12,
       scale=(0.32, 0.08), on_click=lambda: close_new_game_confirmation())

# Create the chapter selection screen and only enable unlocked chapters.
chapters_screen = Entity(parent=camera.ui, enabled=False)
Entity(parent=chapters_screen, model='quad', texture=menu_bg_texture,
       color=color.white if menu_bg_texture else color.black, scale=(2, 1.6))
Text('CHOOSE A CHAPTER', parent=chapters_screen, y=0.65, origin=(0, 0), scale=1.4)
chapter_info = Text('Select a chapter to see its description and best time.',
                    parent=chapters_screen, y=-0.44, origin=(0, 0), scale=0.55)
chapter_buttons = []

# Show a short chapter description and its saved best completion time.
def set_chapter_info(number):
    chapter = ZONE_CONFIGS[number - 1]
    best = progress_data.get('best_times', {}).get(str(number))
    if isinstance(best, (int, float)):
        best_text = 'Best time: {:.0f} seconds'.format(best)
    else:
        best_text = 'Not completed yet'
    secret_count = sum(
        1 for secret in collected_secrets if secret.startswith(str(number) + ':')
    )
    chapter_info.text = (
        chapter['description'] + '\nLong-course target: 10-15 min (varies by play style)'
        + '\n' + best_text
        + '\nSecrets: {}/7'.format(secret_count)
    )


for i, chapter in enumerate(ZONE_CONFIGS):
    number = i + 1
    locked = number not in unlocked_zones
    chapter_button = Button(
        text=f'{number}. {chapter["name"]}' + ('  [LOCKED]' if locked else ''),
        parent=chapters_screen, y=0.42 - i * 0.12, scale=(0.65, 0.08),
        enabled=not locked,
        on_click=lambda n=number: start_game(n),
        on_mouse_enter=lambda n=number: set_chapter_info(n),
    )
    chapter_buttons.append(chapter_button)
    if locked:
        chapter_button.color = color.dark_gray
Button(text='BACK', parent=chapters_screen, y=-0.75, scale=(0.3, 0.07),
       on_click=lambda: show_menu_screen('title'))

# Show the existing songs in a dedicated soundtrack screen from the title menu.
soundtrack_screen = Entity(parent=camera.ui, enabled=False)
Entity(parent=soundtrack_screen, model='quad', texture=menu_bg_texture,
       color=color.white if menu_bg_texture else color.black, scale=(2, 1.6))
Text('SOUNDTRACK', parent=soundtrack_screen, y=0.62, origin=(0, 0), scale=1.5)
for i, name in enumerate(songs):
    Button(text=name, parent=soundtrack_screen, y=0.38 - i * 0.12,
           scale=(0.48, 0.075), on_click=lambda n=name: play_song(n))
Text('Choose a song to play', parent=soundtrack_screen, y=-0.4,
     origin=(0, 0), scale=0.8)
Button(text='BACK', parent=soundtrack_screen, y=-0.55, scale=(0.3, 0.07),
       on_click=lambda: show_menu_screen('title'))

# Show the actual movement and parkour controls from both menus.
controls_screen = Entity(parent=camera.ui, enabled=False)
Entity(parent=controls_screen, model='quad', texture=menu_bg_texture,
       color=color.white if menu_bg_texture else color.black, scale=(2, 1.6))
Text('CONTROLS', parent=controls_screen, y=0.55, origin=(0, 0), scale=1.5)
Text(
    'WASD — Move\nMouse — Look around\nSPACE — Jump\nLEFT SHIFT — Sprint\n'
    'Wall run — Hold W beside a wall while airborne\n'
    'F11 — Toggle fullscreen\nESC — Pause / return\nF10 — Quit game',
    parent=controls_screen, y=0.05, origin=(0, 0), scale=0.9, line_height=1.5,
)
Button(text='BACK', parent=controls_screen, y=-0.55, scale=(0.3, 0.07),
       on_click=lambda: close_settings())

# Give music, atmosphere, sound effects, and master volume separate controls.
audio_screen = Entity(parent=camera.ui, enabled=False)
Entity(parent=audio_screen, model='quad', texture=menu_bg_texture,
       color=color.white if menu_bg_texture else color.black, scale=(2, 1.6))
Text('AUDIO MIXER', parent=audio_screen, y=0.55, origin=(0, 0), scale=1.5)
audio_volume_buttons = {}
for row, (label, setting_name) in enumerate((
    ('Music volume', 'music_volume'),
    ('Ambient sound volume', 'ambient_volume'),
    ('Sound effects volume', 'sfx_volume'),
    ('Master volume', 'master_volume'),
)):
    row_y = 0.25 - row * 0.2
    Text(label, parent=audio_screen, y=row_y + 0.065,
         origin=(0, 0), scale=0.75)
    audio_volume_buttons[setting_name] = []
    for column, amount in enumerate((0.0, 0.5, 1.0)):
        button = Button(
            text=str(int(amount * 100)) + '%',
            parent=audio_screen, x=-0.25 + column * 0.25, y=row_y - 0.015,
            scale=(0.2, 0.07),
            on_click=lambda key=setting_name, value=amount: set_audio_volume(key, value),
        )
        audio_volume_buttons[setting_name].append(button)
Button(text='BACK', parent=audio_screen, y=-0.62, scale=(0.3, 0.07),
       on_click=lambda: close_settings())

# Provide simple graphics and music controls from the settings screen.
settings_screen = Entity(parent=camera.ui, enabled=False)
Entity(parent=settings_screen, model='quad', texture=menu_bg_texture,
       color=color.white if menu_bg_texture else color.black, scale=(2, 1.6))
Text('SETTINGS', parent=settings_screen, y=0.62, origin=(0, 0), scale=1.5)
Text('Graphics quality — choose below', parent=settings_screen, y=0.4, origin=(0, 0))
for i, level in enumerate(('low', 'medium', 'high')):
    Button(text=level.capitalize(), parent=settings_screen, x=-0.35 + i * 0.35,
           y=0.25, scale=(0.28, 0.07), on_click=lambda l=level: set_graphics(l))
Text('Mouse sensitivity — look speed', parent=settings_screen, y=0.08, origin=(0, 0))
for i, sensitivity in enumerate((20, 40, 60, 80)):
    Button(text=str(sensitivity), parent=settings_screen,
           x=-0.36 + i * 0.24, y=-0.02, scale=(0.19, 0.07),
           on_click=lambda value=sensitivity: set_mouse_sensitivity(value))
Text('Sprint speed — multiplier', parent=settings_screen, y=-0.16, origin=(0, 0))
for i, multiplier in enumerate((1.5, 1.7, 2.0)):
    Button(text=str(multiplier) + 'x', parent=settings_screen,
           x=-0.3 + i * 0.3, y=-0.25, scale=(0.24, 0.07),
           on_click=lambda value=multiplier: set_sprint_multiplier(value))
fps_toggle_button = Button(
    text='FPS counter: ON' if show_fps else 'FPS counter: OFF',
    parent=settings_screen, y=-0.38, scale=(0.42, 0.07),
    on_click=lambda: toggle_fps_counter(),
)
Button(text='AUDIO MIXER', parent=settings_screen, y=-0.51, scale=(0.42, 0.07),
       on_click=lambda: show_menu_screen('audio'))
Button(text='BACK', parent=settings_screen, y=-0.63, scale=(0.3, 0.07),
       on_click=lambda: close_settings())

# Show the chapter result and offer a next-chapter button.
completion_screen = Entity(parent=camera.ui, enabled=False)
Entity(parent=completion_screen, model='quad', color=color.rgba(0, 0, 0, 0.88),
       scale=(2, 1.6))
completion_title = Text('YOU MADE IT', parent=completion_screen,
                        y=0.25, origin=(0, 0), scale=1.8)
completion_time = Text('', parent=completion_screen,
                      y=0.12, origin=(0, 0), scale=1)
completion_next_button = Button(text='NEXT CHAPTER', parent=completion_screen,
                                y=-0.05, scale=(0.42, 0.08), on_click=next_chapter)
Button(text='CHAPTERS', parent=completion_screen, y=-0.17, scale=(0.42, 0.08),
       on_click=lambda: show_menu_screen('chapters'))
Button(text='MAIN MENU', parent=completion_screen, y=-0.29, scale=(0.42, 0.08),
       on_click=return_to_title)

# Keep the pause menu usable without letting the player move behind it.
Button(text='RESUME', parent=menu, x=0, y=-0.12, scale=(0.32, 0.07),
       on_click=toggle_menu)
Button(text='RESTART CHAPTER', parent=menu, x=0, y=-0.22, scale=(0.32, 0.07),
       on_click=lambda: start_game(current_zone))
Button(text='MAIN MENU', parent=menu, x=0, y=-0.32, scale=(0.32, 0.07),
       on_click=return_to_title)
Button(text='SETTINGS', parent=menu, x=0, y=-0.42, scale=(0.32, 0.07),
       on_click=lambda: show_menu_screen('settings'))
Button(text='CONTROLS', parent=menu, x=0, y=-0.52, scale=(0.32, 0.07),
       on_click=lambda: show_menu_screen('controls'))
Button(text='AUDIO', parent=menu, x=0, y=-0.62, scale=(0.32, 0.07),
       on_click=lambda: show_menu_screen('audio'))

# Open the requested menu panel without replacing the existing song controls.
def show_menu_screen(screen_name):
    global settings_from_pause, game_paused
    settings_from_pause = screen_name in ('settings', 'controls', 'audio') and gameplay_active
    if settings_from_pause:
        menu.enabled = False
        game_paused = True
        player.enabled = False
        mouse.locked = False
        ambient_player.stop(destroy=False)
    title_screen.enabled = screen_name == 'title'
    chapters_screen.enabled = screen_name == 'chapters'
    soundtrack_screen.enabled = screen_name == 'soundtrack'
    controls_screen.enabled = screen_name == 'controls'
    audio_screen.enabled = screen_name == 'audio'
    settings_screen.enabled = screen_name == 'settings'
    new_game_screen.enabled = False
    completion_screen.enabled = False
    for i, chapter_button in enumerate(chapter_buttons):
        locked = i + 1 not in unlocked_zones
        chapter_button.enabled = not locked
        chapter_button.text = f'{i + 1}. {ZONE_CONFIGS[i]["name"]}' + ('  [LOCKED]' if locked else '')


# Return from settings to the paused game or the title screen.
def close_settings():
    global settings_from_pause, game_paused
    settings_screen.enabled = False
    controls_screen.enabled = False
    audio_screen.enabled = False
    if settings_from_pause and gameplay_active:
        menu.enabled = True
        game_paused = True
        player.enabled = False
    else:
        title_screen.enabled = True
    settings_from_pause = False


# Change the shared song player's volume and remember the setting.
def set_music_volume(amount):
    set_audio_volume('music_volume', amount)


# Update and save an audio category without changing the others.
def set_audio_volume(setting_name, amount):
    global music_volume, ambient_volume, sfx_volume, master_volume
    settings_data[setting_name] = amount
    if setting_name == 'music_volume':
        music_volume = amount
    elif setting_name == 'ambient_volume':
        ambient_volume = amount
    elif setting_name == 'sfx_volume':
        sfx_volume = amount
    elif setting_name == 'master_volume':
        master_volume = amount
    apply_audio_mix()
    for button, value in zip(audio_volume_buttons[setting_name], (0.0, 0.5, 1.0)):
        button.color = color.azure if value == amount else color.dark_gray
    write_json_file(SETTINGS_FILE, settings_data)


# Let the player open and cancel a clean new-game reset.
def show_new_game_confirmation():
    title_screen.enabled = False
    new_game_screen.enabled = True


def close_new_game_confirmation():
    new_game_screen.enabled = False
    title_screen.enabled = True


# Reset saved progress only after the player confirms the new game.
def start_new_game():
    global current_zone, unlocked_zones, collected_secrets, tutorials_seen
    new_game_screen.enabled = False
    current_zone = 1
    unlocked_zones = [1]
    collected_secrets = []
    tutorials_seen = []
    selected_song_name = progress_data.get('selected_song')
    progress_data.clear()
    if selected_song_name in songs:
        progress_data['selected_song'] = selected_song_name
    checkpoint_pos.x = start_pos.x
    checkpoint_pos.y = start_pos.y
    checkpoint_pos.z = start_pos.z
    save_progress()
    start_game(1)


# Adjust mouse look sensitivity and save the selected value.
def set_mouse_sensitivity(amount):
    global mouse_sensitivity
    mouse_sensitivity = amount
    player.mouse_sensitivity = Vec2(amount, amount)
    settings_data['mouse_sensitivity'] = amount
    write_json_file(SETTINGS_FILE, settings_data)


# Set the sprint multiplier and update the live player controller.
def set_sprint_multiplier(amount):
    global sprint_multiplier
    sprint_multiplier = amount
    player.sprint_multiplier = amount
    settings_data['sprint_multiplier'] = amount
    write_json_file(SETTINGS_FILE, settings_data)


# Show or hide the simple live FPS readout.
def toggle_fps_counter():
    global show_fps
    show_fps = not show_fps
    fps_text.enabled = show_fps
    fps_toggle_button.text = 'FPS counter: ON' if show_fps else 'FPS counter: OFF'
    settings_data['show_fps'] = show_fps
    write_json_file(SETTINGS_FILE, settings_data)


# Show a short, one-time tutorial and save that it has been seen.
def show_tutorial(tutorial_name, message):
    global tutorial_timer
    if tutorial_name in tutorials_seen:
        return
    tutorials_seen.append(tutorial_name)
    tutorial_text.text = message
    tutorial_text.enabled = True
    tutorial_text.color = color.rgba(1, 0.9, 0.55, 1)
    tutorial_timer = 5
    save_progress()


# Add a status message without changing the existing HUD or game controls.
status_text = Text('', origin=(-0.5, 0), x=-0.85, y=0.4, scale=1)
fps_text = Text('', origin=(0.5, 0), x=0.83, y=0.46, scale=0.8, enabled=show_fps)
tutorial_text = Text('', origin=(0, 0), y=-0.38, scale=0.9, enabled=False)
tutorial_timer = 0

app.run()