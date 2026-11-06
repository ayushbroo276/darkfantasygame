extends RefCounted

const PLATFORM_COUNT := 700
const PLATFORM_SPACING := 6.0
const SECTION_SIZE := 100
const CHECKPOINT_SPACING := 50

const ZONES: Array[Dictionary] = [
	{
		"name": "The Beginning",
		"description": "An abandoned yellow-stone facility beneath a dark sky.",
		"folder": "zone1_the_beginning",
		"wall": "concrete_wall",
		"floor": "dirty_concrete",
		"platform": "rusted_metal",
		"ceiling": "dark_brick",
		"wall_color": Color(0.59, 0.51, 0.24),
		"floor_color": Color(0.18, 0.16, 0.12),
		"platform_color": Color(0.43, 0.29, 0.15),
		"fog": Color(0.15, 0.075, 0.09),
		"slope": 0.30,
		"messages": ["WE LEFT THE LIGHTS ON", "NO ONE ANSWERED", "THE LIFT IS STILL RUNNING", "DO NOT LOOK BACK", "THE WALLS REMEMBER", "A DOOR WAS HERE", "KEEP GOING"],
	},
	{
		"name": "The Long Climb",
		"description": "Rusted platforms rise through an empty industrial shaft.",
		"folder": "zone2_the_long_climb",
		"wall": "oxidized_metal",
		"floor": "industrial_floor",
		"platform": "metal_grate",
		"ceiling": "rusted_steel",
		"wall_color": Color(0.37, 0.30, 0.24),
		"floor_color": Color(0.15, 0.16, 0.17),
		"platform_color": Color(0.48, 0.36, 0.22),
		"fog": Color(0.11, 0.10, 0.09),
		"slope": 0.42,
		"messages": ["LEVEL 01", "STAIRWELL CLOSED", "LIFT OUT OF SERVICE", "YOU ARE STILL CLIMBING", "NO TOP FLOOR", "KEEP CLIMBING", "ROOF ACCESS"],
	},
	{
		"name": "Poolrooms",
		"description": "Quiet tiled chambers hover above still blue water.",
		"folder": "zone3_poolrooms",
		"wall": "aged_pool_tile",
		"floor": "wet_tile_floor",
		"platform": "blue_pool_tile",
		"ceiling": "aged_pool_tile",
		"wall_color": Color(0.67, 0.60, 0.40),
		"floor_color": Color(0.15, 0.31, 0.33),
		"platform_color": Color(0.24, 0.60, 0.65),
		"fog": Color(0.13, 0.29, 0.31),
		"slope": 0.0,
		"messages": ["PLEASE WALK, DO NOT RUN", "THE WATER IS TOO STILL", "POOL CLOSED", "THE DEEP END IS NOT MARKED", "SOMEONE IS SWIMMING", "NO LIFEGUARD ON DUTY", "THE WATER HAS NO BOTTOM"],
	},
	{
		"name": "Dark Hall",
		"description": "Red emergency lights mark a cracked, endless corridor.",
		"folder": "zone4_dark_hall",
		"wall": "dark_red_wall",
		"floor": "dirty_checker_floor",
		"platform": "stained_concrete",
		"ceiling": "cracked_wall",
		"wall_color": Color(0.41, 0.19, 0.19),
		"floor_color": Color(0.14, 0.11, 0.13),
		"platform_color": Color(0.52, 0.18, 0.20),
		"fog": Color(0.18, 0.05, 0.08),
		"slope": 0.28,
		"messages": ["EMERGENCY EXIT", "KEEP THIS DOOR CLEAR", "POWER FAILURE", "WE HEARD FOOTSTEPS", "THE LIGHT IS NOT HELPING", "DO NOT STOP", "EVACUATE"],
	},
	{
		"name": "Vine Tunnel",
		"description": "Moss, stone, and hanging vines reclaim the passage.",
		"folder": "zone5_vine_tunnel",
		"wall": "vine_covered_wall",
		"floor": "damp_rock",
		"platform": "mossy_stone",
		"ceiling": "overgrown_stone",
		"wall_color": Color(0.22, 0.37, 0.24),
		"floor_color": Color(0.12, 0.18, 0.15),
		"platform_color": Color(0.24, 0.47, 0.30),
		"fog": Color(0.07, 0.15, 0.11),
		"slope": 0.34,
		"messages": ["ROOTS BELOW", "THE STONE IS WARM", "SOMETHING GREW THROUGH HERE", "BRIDGE UNSAFE", "FOLLOW THE VINES", "THE TUNNEL IS BREATHING", "DAYLIGHT AHEAD"],
	},
	{
		"name": "The Tower",
		"description": "A dark stone staircase climbs toward the final tower.",
		"folder": "zone6_the_tower",
		"wall": "dark_stone",
		"floor": "tower_floor",
		"platform": "aged_stone",
		"ceiling": "iron_bars",
		"wall_color": Color(0.25, 0.23, 0.32),
		"floor_color": Color(0.11, 0.10, 0.14),
		"platform_color": Color(0.41, 0.34, 0.49),
		"fog": Color(0.09, 0.07, 0.14),
		"slope": 0.52,
		"messages": ["TOWER ENTRY", "STAIRCASE 02", "THE WIND IS ABOVE YOU", "NO WINDOWS ON THIS SIDE", "THE TOP IS NOT THE END", "FINAL ASCENT", "THANK YOU FOR CLIMBING"],
	},
]

const LATERAL_PATTERNS: Array[Array] = [
	[],
	[0.0, 0.8, 1.6, 1.6, 0.8, 0.0, -0.8, -1.6, -1.6, -0.8, 0.0, 0.0],
	[0.0, 1.2, 2.4, 3.0, 2.4, 1.2, 0.0, -1.2, -2.4, -3.0, -2.4, -1.2],
	[0.0, 1.6, 3.2, 4.0, 4.8, 4.0, 2.4, 0.0, -2.4, -4.0, -4.8, -2.4],
	[0.0, 1.2, -0.4, 1.6, -0.8, 0.0, -1.2, 0.4, -1.6, 0.8, 0.0, 0.0],
	[0.0, 1.2, 2.4, 1.8, 0.6, -0.6, -1.8, -2.4, -1.2, 0.0, 1.2, 0.0],
	[0.0, 1.2, 2.4, 3.6, 2.4, 1.2, 0.0, -1.2, -2.4, -3.6, -2.4, -1.2],
]

const CHALLENGES := {
	1: {"moving": [30, 70], "timed": [], "rotating": [47], "collapsing": []},
	2: {"moving": [16, 58, 87], "timed": [], "rotating": [35, 75], "collapsing": []},
	3: {"moving": [20, 52, 82], "timed": [], "rotating": [], "collapsing": []},
	4: {"moving": [16, 58], "timed": [30, 75], "rotating": [], "collapsing": [45, 88]},
	5: {"moving": [16, 66], "timed": [], "rotating": [], "collapsing": [35, 58, 85]},
	6: {"moving": [16, 63], "timed": [34, 82], "rotating": [46, 76], "collapsing": [56]},
}

const SECTION_LABELS := [
	"INTRODUCTION",
	"FLOATING STAIRS",
	"MOVING CROSSING",
	"WALL-RUN GALLERY",
	"TIMED HALL",
	"HIDDEN PASSAGE",
	"FINAL ASCENT",
]


static func zone(zone_number: int) -> Dictionary:
	return ZONES[clampi(zone_number - 1, 0, ZONES.size() - 1)]


static func platform_position(zone_number: int, index: int) -> Vector3:
	var pattern: Array = LATERAL_PATTERNS[zone_number]
	var section: int = index / SECTION_SIZE
	var step: int = index % pattern.size()
	var height := 0.5 + section * float(zone(zone_number)["slope"]) + (step % 5) * 0.035
	return Vector3(float(pattern[step]), height, -index * PLATFORM_SPACING)


static func platform_kind(zone_number: int, index: int) -> String:
	var challenge: Dictionary = CHALLENGES[zone_number]
	var section_offset: int = index % SECTION_SIZE
	for kind in ["moving", "timed", "rotating", "collapsing"]:
		if section_offset in challenge[kind]:
			return kind
	return "normal"


static func moving_offset(zone_number: int) -> Vector3:
	var offsets := [
		Vector3.ZERO,
		Vector3(2.1, 0.1, 0.0),
		Vector3(0.5, 1.2, 0.0),
		Vector3(2.7, 0.0, 0.0),
		Vector3(1.7, 0.7, 0.0),
		Vector3(2.2, 0.6, 0.0),
		Vector3(1.0, 1.4, 0.0),
	]
	return offsets[zone_number]
