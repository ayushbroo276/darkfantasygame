import math
from ursina import *
from panda3d.core import TransparencyAttrib


# Move a collidable platform smoothly between two ends of a short path.
class MovingPlatform(Entity):
    def __init__(self, position, movement, speed, texture, tint, size=(3.6, 0.5, 3.6)):
        self.origin = Vec3(*position)
        self.movement = Vec3(*movement)
        self.motion_speed = speed
        self.motion_phase = 0
        self.previous_position = Vec3(*position)
        self.movement_delta = Vec3(0, 0, 0)
        self.platform_kind = 'moving'
        super().__init__(
            model='cube', texture=texture, color=tint,
            texture_scale=(2, 2), position=position, scale=size,
            collider='box',
        )

    def advance(self, delta_time):
        self.previous_position = Vec3(self.world_position)
        self.motion_phase += self.motion_speed * delta_time
        self.position = self.origin + self.movement * math.sin(self.motion_phase)
        self.movement_delta = self.world_position - self.previous_position


# Rotate a long, flat platform around its center.
class RotatingPlatform(Entity):
    def __init__(self, position, texture, tint, size=(4, 0.5, 1.8)):
        self.previous_rotation_y = 0
        self.platform_kind = 'rotating'
        super().__init__(
            model='cube', texture=texture, color=tint,
            texture_scale=(2, 1), position=position, scale=size,
            collider='box',
        )

    def advance(self, delta_time):
        self.previous_rotation_y = self.rotation_y
        self.rotation_y = (self.rotation_y + 24 * delta_time) % 360


# Let timed stepping stones blink out briefly, then return.
class TimedPlatform(Entity):
    def __init__(self, position, texture, tint, phase_offset=0):
        self.phase = phase_offset
        self.period = 8.0
        self.active_time = 5.2
        self.platform_kind = 'timed'
        super().__init__(
            model='cube', texture=texture, color=tint,
            texture_scale=(2, 2), position=position, scale=(3.4, 0.5, 3.4),
            collider='box',
        )

    def advance(self, delta_time):
        self.phase = (self.phase + delta_time) % self.period
        should_show = self.phase < self.active_time
        if self.enabled != should_show:
            self.enabled = should_show


# Collapse a stone after it has carried the player for a moment, then restore it.
class CollapsingPlatform(Entity):
    def __init__(self, position, texture, tint):
        self.stand_time = 0
        self.reset_time = 0
        self.platform_kind = 'collapsing'
        super().__init__(
            model='cube', texture=texture, color=tint,
            texture_scale=(2, 2), position=position, scale=(3.4, 0.5, 3.4),
            collider='box',
        )

    def advance(self, player, delta_time):
        if self.reset_time > 0:
            self.reset_time = max(0, self.reset_time - delta_time)
            if self.reset_time == 0:
                self.enabled = True
                self.stand_time = 0
            return

        top = self.world_y + self.world_scale_y / 2
        standing = (
            self.enabled and player.grounded and abs(player.y - top) < 0.18
            and abs(player.x - self.world_x) <= self.world_scale_x / 2 + 0.2
            and abs(player.z - self.world_z) <= self.world_scale_z / 2 + 0.2
        )
        if standing:
            self.stand_time += delta_time
            if self.stand_time >= 1.1:
                self.enabled = False
                self.reset_time = 3.0
        else:
            self.stand_time = 0


# Open the route periodically by lifting a simple, low-cost gate.
class TimedDoor(Entity):
    def __init__(self, position, color_value):
        self.closed_position = Vec3(*position)
        self.phase = 0
        self.open_duration = 3.5
        self.closed_duration = 4.5
        self.total_cycle = self.open_duration + self.closed_duration
        self.is_open = False
        super().__init__(
            model='cube', color=color_value, position=position,
            scale=(8, 4.5, 0.6), collider='box', unlit=True,
        )

    def advance(self, delta_time):
        self.phase = (self.phase + delta_time) % self.total_cycle
        self.is_open = self.phase < self.open_duration
        self.y = self.closed_position.y + (5.5 if self.is_open else 0)
        self.color = color.rgb32(70, 180, 110) if self.is_open else color.rgb32(190, 50, 45)


# Flicker a small emissive fixture without creating a real-time light source.
class FlickeringLight(Entity):
    def __init__(self, position, bright_color):
        self.phase = position[2] * 0.13
        self.bright_color = bright_color
        self.dim_color = color.rgb32(55, 35, 40)
        super().__init__(
            model='cube', color=bright_color, position=position,
            scale=(0.3, 1.1, 1.5), unlit=True,
        )

    def advance(self, delta_time):
        self.phase += delta_time
        if math.sin(self.phase * 9) > -0.15:
            self.color = self.bright_color
        else:
            self.color = self.dim_color


# Each chapter points to its own textures and palette.
ZONE_CONFIGS = [
    {
        'name': 'The Beginning',
        'description': 'An abandoned yellow-stone facility beneath a dark sky.',
        'folder': 'zone1_the_beginning',
        'wall': 'concrete_wall',
        'floor': 'dirty_concrete',
        'platform': 'rusted_metal',
        'ceiling': 'dark_brick',
        'colors': ((150, 130, 60), (55, 48, 36), (110, 75, 38)),
        'fog': (40, 20, 25),
        'messages': ('WE LEFT THE LIGHTS ON', 'NO ONE ANSWERED',
                     'THE LIFT IS STILL RUNNING', 'DO NOT LOOK BACK',
                     'THE WALLS REMEMBER', 'A DOOR WAS HERE', 'KEEP GOING'),
    },
    {
        'name': 'The Long Climb',
        'description': 'Rusted platforms rise through an empty industrial shaft.',
        'folder': 'zone2_the_long_climb',
        'wall': 'oxidized_metal',
        'floor': 'industrial_floor',
        'platform': 'metal_grate',
        'ceiling': 'rusted_steel',
        'colors': ((95, 78, 60), (38, 40, 42), (125, 92, 56)),
        'fog': (27, 24, 22),
        'messages': ('LEVEL 01', 'STAIRWELL CLOSED', 'LIFT OUT OF SERVICE',
                     'YOU ARE STILL CLIMBING', 'NO TOP FLOOR', 'KEEP CLIMBING',
                     'ROOF ACCESS'),
    },
    {
        'name': 'Poolrooms',
        'description': 'Quiet tiled chambers hover above still blue water.',
        'folder': 'zone3_poolrooms',
        'wall': 'aged_pool_tile',
        'floor': 'wet_tile_floor',
        'platform': 'blue_pool_tile',
        'ceiling': 'aged_pool_tile',
        'colors': ((175, 158, 105), (40, 86, 91), (62, 153, 165)),
        'fog': (33, 75, 80),
        'messages': ('PLEASE WALK, DO NOT RUN', 'THE WATER IS TOO STILL',
                     'POOL CLOSED', 'THE DEEP END IS NOT MARKED',
                     'SOMEONE IS SWIMMING', 'NO LIFEGUARD ON DUTY',
                     'THE WATER HAS NO BOTTOM'),
    },
    {
        'name': 'Dark Hall',
        'description': 'Red emergency lights mark a cracked, endless corridor.',
        'folder': 'zone4_dark_hall',
        'wall': 'dark_red_wall',
        'floor': 'dirty_checker_floor',
        'platform': 'stained_concrete',
        'ceiling': 'cracked_wall',
        'colors': ((105, 48, 48), (35, 29, 34), (132, 45, 50)),
        'fog': (45, 12, 21),
        'messages': ('EMERGENCY EXIT', 'KEEP THIS DOOR CLEAR',
                     'POWER FAILURE', 'WE HEARD FOOTSTEPS',
                     'THE LIGHT IS NOT HELPING', 'DO NOT STOP',
                     'EVACUATE'),
    },
    {
        'name': 'Vine Tunnel',
        'description': 'Moss, stone, and hanging vines reclaim the passage.',
        'folder': 'zone5_vine_tunnel',
        'wall': 'vine_covered_wall',
        'floor': 'damp_rock',
        'platform': 'mossy_stone',
        'ceiling': 'overgrown_stone',
        'colors': ((56, 95, 61), (30, 45, 38), (62, 115, 77)),
        'fog': (18, 38, 28),
        'messages': ('ROOTS BELOW', 'THE STONE IS WARM',
                     'SOMETHING GREW THROUGH HERE', 'BRIDGE UNSAFE',
                     'FOLLOW THE VINES', 'THE TUNNEL IS BREATHING',
                     'DAYLIGHT AHEAD'),
    },
    {
        'name': 'The Tower',
        'description': 'A dark stone staircase climbs toward the final tower.',
        'folder': 'zone6_the_tower',
        'wall': 'dark_stone',
        'floor': 'tower_floor',
        'platform': 'aged_stone',
        'ceiling': 'iron_bars',
        'colors': ((65, 60, 82), (27, 25, 34), (105, 88, 125)),
        'fog': (23, 18, 35),
        'messages': ('TOWER ENTRY', 'STAIRCASE 02', 'THE WIND IS ABOVE YOU',
                     'NO WINDOWS ON THIS SIDE', 'THE TOP IS NOT THE END',
                     'FINAL ASCENT', 'THANK YOU FOR CLIMBING'),
    },
]


# Build seven long sections with a checkpoint at the end of each section.
PLATFORM_COUNT = 700
SECTION_SIZE = 100
CHECKPOINT_SPACING = 50
PLATFORM_SPACING = 6.0


def make_platform_positions(zone_number):
    lateral_patterns = {
        1: (0, 0.8, 1.6, 1.6, 0.8, 0, -0.8, -1.6, -1.6, -0.8, 0, 0),
        2: (0, 1.2, 2.4, 3.0, 2.4, 1.2, 0, -1.2, -2.4, -3.0, -2.4, -1.2),
        3: (0, 1.6, 3.2, 4.0, 4.8, 4, 2.4, 0, -2.4, -4, -4.8, -2.4),
        4: (0, 1.2, -0.4, 1.6, -0.8, 0, -1.2, 0.4, -1.6, 0.8, 0, 0),
        5: (0, 1.2, 2.4, 1.8, 0.6, -0.6, -1.8, -2.4, -1.2, 0, 1.2, 0),
        6: (0, 1.2, 2.4, 3.6, 2.4, 1.2, 0, -1.2, -2.4, -3.6, -2.4, -1.2),
    }
    positions = []
    for index in range(PLATFORM_COUNT):
        section = index // SECTION_SIZE
        step = index % len(lateral_patterns[zone_number])
        x = lateral_patterns[zone_number][step]
        z = index * PLATFORM_SPACING
        if zone_number == 1:
            height = 0.5 + section * 0.6 + (step % 4) * 0.06
        elif zone_number == 2:
            height = 0.5 + section * 1.4 + (step % 6) * 0.08
        elif zone_number == 3:
            height = 0.5 + (step % 5) * 0.12
        elif zone_number == 4:
            height = 0.5 + section * 0.55 + (step % 3) * 0.1
        elif zone_number == 5:
            height = 0.5 + section * 0.8 + (step % 4) * 0.08
        else:
            height = 0.5 + section * 1.8 + (step % 4) * 0.12
        positions.append((x, height, z))
    return positions


# Add one textured entity to the zone and keep the cleanup list complete.
def add_entity(entities, entity):
    entities.append(entity)
    return entity


# Build just one detailed chapter and return its gameplay objects for cleanup.
def build_zone(zone_number, load_texture):
    config = ZONE_CONFIGS[zone_number - 1]
    wall_color = color.rgb32(*config['colors'][0])
    floor_color = color.rgb32(*config['colors'][1])
    platform_color = color.rgb32(*config['colors'][2])
    fog_color = color.rgb32(*config['fog'])
    folder = config['folder']
    wall_texture = load_texture(config['wall'], folder)
    floor_texture = load_texture(config['floor'], folder)
    platform_texture = load_texture(config['platform'], folder)
    ceiling_texture = load_texture(config['ceiling'], folder)
    positions = make_platform_positions(zone_number)
    length = positions[-1][2] + 40
    entities = []
    walls = []
    wall_run_walls = []
    walkable_surfaces = []
    moving_platforms = []
    timed_platforms = []
    collapsing_platforms = []
    rotating_platforms = []
    timed_doors = []
    flickering_lights = []
    checkpoints = []
    secrets = []
    vines = []

    # Use one simple catch floor, broad walls, and a high visual ceiling per zone.
    floor = add_entity(entities, Entity(
        model='cube', texture=floor_texture,
        color=color.white if floor_texture else floor_color,
        texture_scale=(20, max(1, int(length / 8))), position=(0, -25, length / 2),
        scale=(52, 1, length + 35), collider='box',
    ))
    walkable_surfaces.append(floor)
    add_entity(entities, Entity(
        model='cube', texture=ceiling_texture,
        color=color.white if ceiling_texture else floor_color,
        texture_scale=(18, max(1, int(length / 8))), position=(0, 30, length / 2),
        scale=(52, 1, length + 35),
    ))
    for x in (-26, 26):
        wall = add_entity(entities, Entity(
            model='cube', texture=wall_texture,
            color=color.white if wall_texture else wall_color,
            texture_scale=(12, max(1, int(length / 10))),
            position=(x, 10, length / 2), scale=(1, 34, length + 35),
            collider='box',
        ))
        walls.append(wall)

    # Give each chapter its own mix of moving, timed, rotating, and collapsing steps.
    challenge_offsets = {
        1: ({30, 70}, set(), {47}, set()),
        2: ({16, 58, 87}, set(), {35, 75}, set()),
        3: ({20, 52, 82}, set(), set(), set()),
        4: ({16, 58}, {30, 75}, set(), {45, 88}),
        5: ({16, 66}, set(), set(), {35, 58, 85}),
        6: ({16, 63}, {34, 82}, {46, 76}, {56}),
    }
    moving_offsets, timed_offsets, rotating_offsets, collapsing_offsets = (
        challenge_offsets[zone_number]
    )
    moving_indices = {
        section * SECTION_SIZE + offset
        for section in range(7) for offset in moving_offsets
    }
    timed_indices = {
        section * SECTION_SIZE + offset
        for section in range(7) for offset in timed_offsets
    }
    rotating_indices = {
        section * SECTION_SIZE + offset
        for section in range(7) for offset in rotating_offsets
    }
    collapsing_indices = {
        section * SECTION_SIZE + offset
        for section in range(7) for offset in collapsing_offsets
    }
    for index, position in enumerate(positions):
        x, height, z = position
        tint = color.hsv(index * 19, 0.22, 0.95)
        if index in moving_indices:
            motion_by_zone = {
                1: (2.1, 0.1, 0),
                2: (0.5, 1.7, 0),
                3: (2.7, 0, 0),
                4: (1.7, 0.7, 0),
                5: (2.2, 0.6, 0),
                6: (1.0, 2.0, 0),
            }
            movement = motion_by_zone[zone_number]
            platform = MovingPlatform(
                position, movement, 0.56 + (index // SECTION_SIZE % 3) * 0.14,
                platform_texture, platform_color,
                size=(4.0, 0.5, 3.6) if index % 2 == 0 else (3.4, 0.5, 3.4),
            )
            moving_platforms.append(platform)
        elif index in timed_indices:
            platform = TimedPlatform(
                position, platform_texture, platform_color,
                phase_offset=(index // SECTION_SIZE) * 1.1,
            )
            timed_platforms.append(platform)
        elif index in rotating_indices:
            platform = RotatingPlatform(
                position, platform_texture, platform_color,
                size=(4.0, 0.5, 1.9),
            )
            rotating_platforms.append(platform)
        elif index in collapsing_indices:
            platform = CollapsingPlatform(position, platform_texture, platform_color)
            collapsing_platforms.append(platform)
        else:
            platform = Entity(
                model='cube', texture=platform_texture,
                color=tint if platform_texture else platform_color,
                texture_scale=(2, 2), position=position, scale=(3.2, 0.5, 3.2),
                collider='box',
            )
        add_entity(entities, platform)
        walkable_surfaces.append(platform)

    # Save a checkpoint every 50 course platforms.
    section_labels = (
        'INTRODUCTION',
        'FLOATING STAIRS',
        'MOVING CROSSING',
        'WALL-RUN GALLERY',
        'TIMED HALL',
        'HIDDEN PASSAGE',
        'FINAL ASCENT',
    )
    for checkpoint_index in range(CHECKPOINT_SPACING - 1, PLATFORM_COUNT, CHECKPOINT_SPACING):
        checkpoint_position = positions[checkpoint_index]
        checkpoints.append(Vec3(*checkpoint_position))
        checkpoint_marker = add_entity(entities, Entity(
            model='sphere', color=color.rgb32(255, 190, 75),
            position=(checkpoint_position[0], checkpoint_position[1] + 1.1,
                      checkpoint_position[2]),
            scale=0.65, unlit=True,
        ))
        checkpoint_marker.rotation_y = 30

    # Add light architectural framing and a readable marker for each section.
    for section in range(7):
        section_start = section * SECTION_SIZE
        center = positions[section_start + 6]
        sign = add_entity(entities, Entity(
            model='cube', texture=wall_texture,
            color=color.white if wall_texture else wall_color,
            position=(15 if section % 2 == 0 else -15, center[1] + 4, center[2]),
            scale=(0.45, 5, 7), collider='box',
        ))
        label = Text(
            config['messages'][section] + '\n' + section_labels[section], parent=scene,
            position=(sign.x - 0.2, sign.y, sign.z), scale=3,
            billboard=True, color=color.white, unlit=True,
        )
        add_entity(entities, label)

        # Frame each section as a large room instead of an unbroken tube.
        gateway_z = positions[section_start + 4][2]
        gateway_y = center[1] + 8
        for side in (-1, 1):
            add_entity(entities, Entity(
                model='cube', texture=wall_texture,
                color=color.white if wall_texture else wall_color,
                position=(side * 13, gateway_y / 2, gateway_z),
                scale=(1.2, gateway_y, 1.4), collider='box',
            ))
        add_entity(entities, Entity(
            model='cube', texture=ceiling_texture,
            color=color.white if ceiling_texture else floor_color,
            position=(0, gateway_y, gateway_z),
            scale=(27, 1.2, 1.4), collider='box',
        ))

    # Build seven small optional side routes, each ending at a saved collectible.
    for secret_number, index in enumerate(range(8, PLATFORM_COUNT - 8, SECTION_SIZE)):
        base = positions[index]
        side = -1 if secret_number % 2 else 1
        branch_positions = (
            (base[0] + side * 4.1, base[1] + 0.25, base[2] + 1.5),
            (base[0] + side * 6.8, base[1] + 0.45, base[2] + 4.3),
            (base[0] + side * 4.2, base[1] + 0.65, base[2] + 7.1),
        )
        for branch in branch_positions:
            branch_platform = add_entity(entities, Entity(
                model='cube', texture=platform_texture,
                color=platform_color, position=branch, scale=(3, 0.5, 3),
                collider='box',
            ))
            walkable_surfaces.append(branch_platform)
        # Frame the token platform as a small hidden room with an open entrance.
        room_center = branch_positions[-1]
        for side_offset in (-2.0, 2.0):
            add_entity(entities, Entity(
                model='cube', texture=wall_texture,
                color=color.white if wall_texture else wall_color,
                position=(room_center[0] + side_offset, room_center[1] + 2,
                          room_center[2] + 1),
                scale=(0.35, 4, 5), collider='box',
            ))
        add_entity(entities, Entity(
            model='cube', texture=wall_texture,
            color=color.white if wall_texture else wall_color,
            position=(room_center[0], room_center[1] + 2, room_center[2] + 3.4),
            scale=(4.3, 4, 0.35), collider='box',
        ))
        secret = add_entity(entities, Entity(
            model='sphere', color=color.rgb32(255, 235, 135),
            position=(branch_positions[-1][0], branch_positions[-1][1] + 1.1,
                      branch_positions[-1][2]),
            scale=0.55, collider='sphere', unlit=True,
            secret_id=str(zone_number) + ':' + str(secret_number + 1),
        ))
        secrets.append(secret)

    # Group walkable surfaces by nearby depth so landing checks stay inexpensive.
    walkable_bins = {}
    for surface in walkable_surfaces:
        if surface is floor:
            continue
        bin_number = math.floor(surface.world_z / 16)
        walkable_bins.setdefault(bin_number, []).append(surface)

    # Add long wall-running surfaces beside the route in several chapters.
    if zone_number in (1, 2, 5, 6):
        for section in (2, 3, 6):
            anchor = positions[section * SECTION_SIZE + 5]
            side = -1 if section % 2 else 1
            wall = add_entity(entities, Entity(
                model='cube', texture=wall_texture,
                color=color.white if wall_texture else wall_color,
                position=(anchor[0] + side * 2.7, anchor[1] + 4.5,
                          anchor[2] + 20),
                scale=(0.8, 9, 38), collider='box',
            ))
            walls.append(wall)
            wall_run_walls.append(wall)

    # Place timing gates after clear rest platforms, never directly over a jump.
    door_sections = (1, 3, 5) if zone_number in (1, 4) else ()
    for section in door_sections:
        position = positions[section * SECTION_SIZE + 3]
        door = TimedDoor(
            (position[0], position[1] + 2.5, position[2] + 2.1),
            color.rgb32(190, 50, 45),
        )
        add_entity(entities, door)
        timed_doors.append(door)

    # Build a low tunnel and a raised elevator section as visual landmarks.
    tunnel_sections = (1, 4) if zone_number in (1, 4, 5) else ()
    for section in tunnel_sections:
        start = positions[section * SECTION_SIZE + 2]
        roof = add_entity(entities, Entity(
            model='cube', texture=ceiling_texture,
            color=color.white if ceiling_texture else floor_color,
            position=(start[0], start[1] + 3.1, start[2] + 12),
            scale=(8, 0.6, 18), collider='box',
        ))
        for side in (-1, 1):
            support = add_entity(entities, Entity(
                model='cube', texture=wall_texture,
                color=color.white if wall_texture else wall_color,
                position=(start[0] + side * 3.7, start[1] + 1.8, start[2] + 12),
                scale=(0.6, 3.6, 18), collider='box',
            ))

    # Add sparse zone details for atmosphere without high-cost lights or particles.
    for section in range(7):
        point = positions[section * SECTION_SIZE + 1]
        lamp_color = color.rgb32(*config['colors'][2])
        add_entity(entities, Entity(
            model='sphere', color=lamp_color,
            position=(point[0] + (-1 if section % 2 else 1) * 7,
                      point[1] + 6, point[2] + 9),
            scale=1.4, unlit=True,
        ))

    # Hang low-cost vine cards in the overgrown chapter.
    if zone_number == 5:
        vine_texture = load_texture('vine')
        for i in range(42):
            side = -24.8 if i % 2 == 0 else 24.8
            z = 5 + i * (length / 42)
            vine = add_entity(entities, Entity(
                model='quad', texture=vine_texture,
                color=color.white if vine_texture else color.rgb32(40, 100, 50),
                position=(side, 10, z), rotation_y=90 if side < 0 else -90,
                scale=(2.2, 6),
            ))
            vine.set_transparency(TransparencyAttrib.M_alpha)
            vines.append(vine)

    # Use broad, inexpensive water and emergency lamps for their themed zones.
    if zone_number == 3:
        water_texture = load_texture('pool_water', folder)
        water = add_entity(entities, Entity(
            model='plane', texture=water_texture,
            color=color.rgba(0.35, 0.75, 0.8, 0.65) if water_texture else color.azure,
            position=(0, -20, length / 2), scale=(52, 1, length + 35),
        ))
        water.set_transparency(True)
    if zone_number == 4:
        for section in range(7):
            point = positions[section * SECTION_SIZE + 10]
            lamp = FlickeringLight(
                (point[0] - 7, point[1] + 5, point[2]),
                color.rgb32(185, 35, 45),
            )
            add_entity(entities, lamp)
            flickering_lights.append(lamp)

    # End the route with a bright, clearly visible goal.
    end = positions[-1]
    goal = add_entity(entities, Entity(
        model='sphere', color=color.rgb32(255, 220, 100),
        scale=1.5, position=(end[0], end[1] + 2, end[2]),
        collider='sphere', unlit=True,
    ))

    # Group scenery into short depth sections so distant areas can stay inactive.
    stream_bins = {}
    stream_global_entities = []
    for entity in entities:
        if entity is floor or entity.world_scale_z >= 500:
            stream_global_entities.append(entity)
            continue
        bin_number = math.floor(entity.world_z / 64)
        stream_bins.setdefault(bin_number, []).append(entity)

    return {
        'entities': entities,
        'walls': walls,
        'wall_run_walls': wall_run_walls,
        'positions': positions,
        'walkable_surfaces': walkable_surfaces,
        'walkable_bins': walkable_bins,
        'stream_bins': stream_bins,
        'stream_global_entities': stream_global_entities,
        'active_stream_center': None,
        'catch_floor': floor,
        'moving_platforms': moving_platforms,
        'timed_platforms': timed_platforms,
        'collapsing_platforms': collapsing_platforms,
        'rotating_platforms': rotating_platforms,
        'timed_doors': timed_doors,
        'flickering_lights': flickering_lights,
        'checkpoints': checkpoints,
        'secrets': secrets,
        'vines': vines,
        'goal': goal,
        'fog_color': fog_color,
        'name': config['name'],
        'start_pos': Vec3(0, 2, 0),
    }
