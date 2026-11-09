extends Node3D

const ZoneData = preload("res://scripts/zone_data.gd")
const PlayerScript = preload("res://scripts/player_controller.gd")

const SAVE_PATH := "user://progress.json"
const SETTINGS_PATH := "user://settings.cfg"
const MUSIC_LIBRARY_PATH := "user://music"
const DEFAULT_MUSIC_PATH := "res://assets/audio/music/numbers.mp3"
const BUILT_IN_SOUNDTRACKS := [
	{"path": "res://assets/audio/music/comfort.mp3", "name": "Comfort"},
	{"path": "res://assets/audio/music/numbers.mp3", "name": "Numbers"},
	{"path": "res://assets/audio/music/resonance.mp3", "name": "Resonance"},
	{"path": "res://assets/audio/music/school.mp3", "name": "School"},
	{"path": "res://assets/audio/music/weeks.mp3", "name": "Weeks"},
	{"path": "res://assets/audio/music/undertale.mp3", "name": "Undertale"},
]
const STREAM_BACK := 3
const STREAM_FORWARD := 22
const SECTION_NAMES := ["INTRODUCTION", "FLOATING STAIRS", "MOVING CROSSING", "WALL-RUN GALLERY", "TIMED HALL", "HIDDEN PASSAGE", "FINAL ASCENT"]

var player: CharacterBody3D
var zone_root: Node3D
var environment: Environment
var world_environment: WorldEnvironment
var directional_light: DirectionalLight3D
var platform_material: StandardMaterial3D
var wall_material: StandardMaterial3D
var floor_material: StandardMaterial3D
var platforms: Dictionary = {}
var current_zone := 1
var saved_current_zone := 1
var progress_path := SAVE_PATH
var settings_path := SETTINGS_PATH
var music_library_path := MUSIC_LIBRARY_PATH
var unlocked_zones: Array[int] = [1]
var checkpoint_by_zone: Dictionary = {}
var best_times: Dictionary = {}
var collected_secrets: Array[String] = []
var settings := {
	"music_volume": 0.28,
	"sfx_volume": 0.72,
	"mouse_sensitivity": 0.0025,
	"graphics": "low",
	"show_fps": false,
}
var active_screen := "title"
var previous_screen := "title"
var gameplay_active := false
var game_paused := false
var is_mobile := false
var current_checkpoint := Vector3.ZERO
var course_time := 0.0
var elapsed_time := 0.0
var checkpoint_notice_time := 0.0
var tutorial_notice_time := 0.0
var selected_ambience := 1
var selected_music_path := DEFAULT_MUSIC_PATH
var selected_music_name := "Numbers"
var music_selection_explicit := false
var custom_music_tracks: Array[Dictionary] = []
var ambience_player: AudioStreamPlayer
var sfx_player: AudioStreamPlayer
var audio_picker
var music_file_dialog: FileDialog
var screens: Dictionary = {}
var ui_root: Control
var hud: Control
var status_label: Label
var zone_label: Label
var fps_label: Label
var joystick_base: Panel
var joystick_knob: Panel
var joystick_vector := Vector2.ZERO
var joystick_pointer := -1
var look_pointer := -1
var touch_origins: Dictionary = {}
var safe_rect := Rect2(24.0, 24.0, 1232.0, 672.0)
var menu_description: Label
var chapter_details: Label
var current_zone_config: Dictionary
var completion_next_button: Button
var completion_description_label: Label
var soundtrack_tracks_container: VBoxContainer
var soundtrack_status_label: Label


func _ready() -> void:
	is_mobile = OS.has_feature("android")
	_configure_input()
	_load_progress()
	_load_settings()
	_create_world()
	_create_player()
	_create_audio()
	_create_interface()
	_connect_android_audio_picker()
	get_viewport().size_changed.connect(_apply_safe_area)
	_apply_safe_area()
	_set_screen("title")
	if is_mobile:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		call_deferred("_apply_safe_area")


func _configure_input() -> void:
	_add_key_action("move_forward", KEY_W)
	_add_key_action("move_forward", KEY_UP)
	_add_key_action("move_back", KEY_S)
	_add_key_action("move_back", KEY_DOWN)
	_add_key_action("move_left", KEY_A)
	_add_key_action("move_left", KEY_LEFT)
	_add_key_action("move_right", KEY_D)
	_add_key_action("move_right", KEY_RIGHT)
	_add_key_action("jump", KEY_SPACE)
	_add_key_action("sprint", KEY_SHIFT)
	_add_key_action("wall_run", KEY_E)
	_add_key_action("pause", KEY_ESCAPE)


func _add_key_action(action_name: String, key_code: Key) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	var event := InputEventKey.new()
	event.physical_keycode = key_code
	InputMap.action_add_event(action_name, event)


func _create_world() -> void:
	world_environment = WorldEnvironment.new()
	environment = Environment.new()
	var sky_material := PanoramaSkyMaterial.new()
	sky_material.panorama = load("res://assets/sky.png") as Texture2D
	var sky := Sky.new()
	sky.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.background_color = Color(0.035, 0.025, 0.055)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.55, 0.53, 0.65)
	environment.ambient_light_energy = 0.72
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.15, 0.075, 0.09)
	environment.fog_density = 0.008
	environment.fog_sky_affect = 0.12
	world_environment.environment = environment
	add_child(world_environment)
	directional_light = DirectionalLight3D.new()
	directional_light.rotation_degrees = Vector3(-42.0, -28.0, 0.0)
	directional_light.light_energy = 0.55
	directional_light.shadow_enabled = false
	add_child(directional_light)


func _create_player() -> void:
	player = CharacterBody3D.new()
	player.set_script(PlayerScript)
	player.name = "Player"
	add_child(player)
	player.position = Vector3(0.0, 0.85, 1.4)
	player.camera.fov = 84.0
	player.look_sensitivity = float(settings["mouse_sensitivity"])


func _create_audio() -> void:
	ambience_player = AudioStreamPlayer.new()
	ambience_player.name = "ZoneAmbience"
	ambience_player.finished.connect(_on_ambience_finished)
	add_child(ambience_player)
	sfx_player = AudioStreamPlayer.new()
	sfx_player.name = "GameSFX"
	var sfx := load("res://assets/audio/game_sfx.wav") as AudioStream
	if sfx != null:
		sfx_player.stream = sfx
	add_child(sfx_player)
	music_file_dialog = FileDialog.new()
	music_file_dialog.title = "Choose a song"
	music_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	music_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	music_file_dialog.add_filter("*.mp3", "MP3 audio")
	music_file_dialog.add_filter("*.ogg", "Ogg Vorbis audio")
	music_file_dialog.add_filter("*.wav", "WAV audio")
	music_file_dialog.file_selected.connect(_on_desktop_audio_selected)
	add_child(music_file_dialog)


func _connect_android_audio_picker() -> void:
	if not is_mobile or not Engine.has_singleton("AudioPicker"):
		return
	audio_picker = Engine.get_singleton("AudioPicker")
	audio_picker.audio_selected.connect(_on_android_audio_selected)
	audio_picker.audio_picker_cancelled.connect(_on_audio_picker_cancelled)
	audio_picker.audio_picker_error.connect(_on_audio_picker_error)


func _input(event: InputEvent) -> void:
	if (event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel")) and not event.is_echo():
		if gameplay_active:
			if active_screen == "settings" or active_screen == "soundtrack":
				_set_screen(previous_screen)
			elif game_paused:
				_set_paused(false)
			else:
				_set_paused(true)
			get_viewport().set_input_as_handled()
		elif active_screen == "chapters" or active_screen == "new_game" or active_screen == "settings" or active_screen == "soundtrack" or active_screen == "controls":
			_set_screen("title")
			get_viewport().set_input_as_handled()
		return
	if not gameplay_active or not is_mobile or game_paused:
		return
	if event is InputEventScreenTouch:
		_handle_screen_touch(event)
	elif event is InputEventScreenDrag:
		_handle_screen_drag(event)


func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	if game_paused:
		return
	var size := get_viewport().get_visible_rect().size
	if event.pressed:
		touch_origins[event.index] = event.position
		if event.position.x < size.x * 0.38 and event.position.y > size.y * 0.53:
			joystick_pointer = event.index
			_update_joystick(event.position)
		elif event.position.x > size.x * 0.39 and event.position.x < size.x * 0.94 and event.position.y > size.y * 0.12 and event.position.y < size.y * 0.62:
			look_pointer = event.index
	else:
		if event.index == joystick_pointer:
			joystick_pointer = -1
			joystick_vector = Vector2.ZERO
			player.mobile_movement = Vector2.ZERO
			joystick_knob.position = Vector2(40.0, 40.0)
		if event.index == look_pointer:
			look_pointer = -1
		touch_origins.erase(event.index)


func _handle_screen_drag(event: InputEventScreenDrag) -> void:
	if game_paused:
		return
	if event.index == joystick_pointer:
		_update_joystick(event.position)
	elif event.index == look_pointer:
		var sensitivity: float = float(settings["mouse_sensitivity"])
		player.rotate_y(-event.relative.x * sensitivity)
		player.pitch = clampf(player.pitch - event.relative.y * sensitivity, -1.48, 1.48)
		player.camera.rotation.x = player.pitch


func _update_joystick(screen_position: Vector2) -> void:
	var center := safe_rect.position + Vector2(safe_rect.size.x * 0.17, safe_rect.size.y * 0.80)
	var delta := (screen_position - center) / 78.0
	joystick_vector = delta.limit_length(1.0)
	player.mobile_movement = joystick_vector
	joystick_knob.position = Vector2(40.0, 40.0) + joystick_vector * 44.0


func _apply_safe_area() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var inset_left := 24.0
	var inset_top := 24.0
	var inset_right := 24.0
	var inset_bottom := 24.0
	if is_mobile:
		var screen := DisplayServer.window_get_current_screen()
		var display_size := DisplayServer.screen_get_size(screen)
		var display_safe_area := DisplayServer.get_display_safe_area()
		if display_size.x > 0 and display_size.y > 0 and display_safe_area.size.x > 0 and display_safe_area.size.y > 0:
			var scale_x := viewport_size.x / float(display_size.x)
			var scale_y := viewport_size.y / float(display_size.y)
			inset_left = maxf(inset_left, display_safe_area.position.x * scale_x + 12.0)
			inset_top = maxf(inset_top, display_safe_area.position.y * scale_y + 12.0)
			inset_right = maxf(inset_right, (display_size.x - display_safe_area.end.x) * scale_x + 12.0)
			inset_bottom = maxf(inset_bottom, (display_size.y - display_safe_area.end.y) * scale_y + 12.0)
	safe_rect = Rect2(
		inset_left,
		inset_top,
		maxf(1.0, viewport_size.x - inset_left - inset_right),
		maxf(1.0, viewport_size.y - inset_top - inset_bottom)
	)
	if is_instance_valid(hud):
		hud.offset_left = safe_rect.position.x
		hud.offset_top = safe_rect.position.y
		hud.offset_right = safe_rect.end.x - viewport_size.x
		hud.offset_bottom = safe_rect.end.y - viewport_size.y
	if is_instance_valid(joystick_base):
		joystick_base.position = Vector2(
			safe_rect.size.x * 0.17 - joystick_base.size.x * 0.5,
			safe_rect.size.y * 0.80 - joystick_base.size.y * 0.5
		)


func _process(delta: float) -> void:
	if gameplay_active and not game_paused:
		elapsed_time += delta
		course_time += delta
		checkpoint_notice_time = maxf(0.0, checkpoint_notice_time - delta)
		tutorial_notice_time = maxf(0.0, tutorial_notice_time - delta)
		if checkpoint_notice_time <= 0.0 and tutorial_notice_time <= 0.0:
			status_label.text = ""
		if player.global_position.y < current_checkpoint.y - 12.0:
			_respawn_at_checkpoint()
		_update_streaming()
		_update_progress_hud()
	if fps_label.visible:
		fps_label.text = "FPS  %d" % Engine.get_frames_per_second()


func _physics_process(delta: float) -> void:
	if not gameplay_active or game_paused:
		return
	_update_platforms(delta)
	_check_checkpoint()
	_check_secrets()
	var goal_position := ZoneData.platform_position(current_zone, ZoneData.PLATFORM_COUNT - 1) + Vector3(0.0, 2.0, 0.0)
	if player.global_position.distance_to(goal_position) < 2.7:
		_complete_zone()


func _update_progress_hud() -> void:
	if not gameplay_active:
		return
	var step: int = clampi(int(round(-player.global_position.z / ZoneData.PLATFORM_SPACING)), 0, ZoneData.PLATFORM_COUNT - 1)
	var section: int = mini(step / ZoneData.SECTION_SIZE, 6)
	zone_label.text = "%s  /  %s" % [current_zone_config["name"].to_upper(), SECTION_NAMES[section]]


func _create_zone(zone_number: int) -> void:
	if is_instance_valid(zone_root):
		zone_root.queue_free()
	platforms.clear()
	current_zone = zone_number
	current_zone_config = ZoneData.zone(current_zone)
	zone_root = Node3D.new()
	zone_root.name = "Zone%d" % current_zone
	add_child(zone_root)
	_apply_zone_atmosphere()
	_create_zone_shell()
	_create_section_landmarks()
	_create_secret_routes()
	_create_zone_details()
	_create_goal()
	_update_streaming(true)
	_start_ambience()


func _apply_zone_atmosphere() -> void:
	var config := current_zone_config
	environment.background_color = config["fog"].darkened(0.48)
	environment.fog_light_color = config["fog"]
	environment.fog_density = 0.0065 if str(settings["graphics"]) == "low" else 0.008
	environment.ambient_light_color = config["wall_color"].lightened(0.18)
	platform_material = _make_material(config["platform"], config["folder"], config["platform_color"])
	wall_material = _make_material(config["wall"], config["folder"], config["wall_color"], true)
	floor_material = _make_material(config["floor"], config["folder"], config["floor_color"], true)


func _make_material(texture_name: String, folder: String, fallback: Color, world_triplanar := false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = fallback
	material.texture_repeat = true
	if world_triplanar:
		material.uv1_triplanar = true
		material.uv1_world_triplanar = true
		material.uv1_scale = Vector3(0.28, 0.28, 0.28)
	var texture_path := "res://assets/%s/%s.png" % [folder, texture_name]
	var texture := load(texture_path) as Texture2D
	if texture != null:
		material.albedo_texture = texture
		material.albedo_color = Color.WHITE
	material.roughness = 0.92
	return material


func _box_material(source: Material) -> Material:
	if source is StandardMaterial3D and not source.uv1_triplanar:
		var tiled := source.duplicate() as StandardMaterial3D
		tiled.uv1_scale = Vector3(3.0, 2.0, 1.0)
		return tiled
	return source


func _create_zone_shell() -> void:
	var length := float(ZoneData.PLATFORM_COUNT) * ZoneData.PLATFORM_SPACING + 50.0
	var center_z := -length * 0.5
	_add_box_body(zone_root, Vector3(0.0, -20.0, center_z), Vector3(54.0, 1.0, length + 40.0), floor_material, "CatchFloor")
	for side in [-1.0, 1.0]:
		_add_box_body(zone_root, Vector3(side * 26.0, 9.0, center_z), Vector3(1.0, 34.0, length + 40.0), wall_material, "OuterWall")
	_add_box_mesh(zone_root, Vector3(0.0, 30.0, center_z), Vector3(54.0, 1.0, length + 40.0), wall_material)
	if current_zone == 3:
		var water_material := StandardMaterial3D.new()
		water_material.albedo_color = Color(0.15, 0.48, 0.55, 0.54)
		water_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		water_material.roughness = 0.28
		var water := MeshInstance3D.new()
		var water_mesh := PlaneMesh.new()
		water_mesh.size = Vector2(54.0, length + 30.0)
		water.mesh = water_mesh
		water.material_override = water_material
		water.position = Vector3(0.0, -18.9, center_z)
		zone_root.add_child(water)


func _create_section_landmarks() -> void:
	for section in range(7):
		var anchor := ZoneData.platform_position(current_zone, section * ZoneData.SECTION_SIZE + 6)
		var gateway_z := ZoneData.platform_position(current_zone, section * ZoneData.SECTION_SIZE + 4).z
		var gateway_height := anchor.y + 8.0
		for side in [-1.0, 1.0]:
			_add_box_mesh(zone_root, Vector3(side * 13.0, gateway_height * 0.5, gateway_z), Vector3(1.2, gateway_height, 1.4), wall_material)
		_add_box_mesh(zone_root, Vector3(0.0, gateway_height, gateway_z), Vector3(27.0, 1.2, 1.4), wall_material)
		var sign := Label3D.new()
		sign.text = "%s\n%s" % [current_zone_config["messages"][section], SECTION_NAMES[section]]
		sign.font_size = 34
		sign.outline_size = 7
		sign.modulate = Color(0.94, 0.89, 0.75)
		sign.position = Vector3(14.5 if section % 2 == 0 else -14.5, anchor.y + 4.0, anchor.z)
		sign.pixel_size = 0.012
		zone_root.add_child(sign)
		var lamp := _make_sphere(Color(0.88, 0.68, 0.43), 0.55, true)
		lamp.position = Vector3(anchor.x + (7.0 if section % 2 == 0 else -7.0), anchor.y + 6.0, anchor.z - 8.0)
		zone_root.add_child(lamp)
		if current_zone == 4:
			var red_lamp := _make_sphere(Color(0.78, 0.09, 0.14), 0.38, true)
			red_lamp.position = Vector3(anchor.x - 7.0, anchor.y + 5.0, anchor.z - 12.0)
			zone_root.add_child(red_lamp)
	if current_zone in [1, 2, 5, 6]:
		for section in [2, 3, 6]:
			var anchor := ZoneData.platform_position(current_zone, section * ZoneData.SECTION_SIZE + 5)
			var side := -1.0 if section % 2 == 1 else 1.0
			_add_box_body(zone_root, Vector3(anchor.x + side * 2.7, anchor.y + 4.5, anchor.z - 20.0), Vector3(0.8, 9.0, 38.0), wall_material, "WallRunSurface")
	if current_zone in [1, 4]:
		for section in [1, 3, 5]:
			var position := ZoneData.platform_position(current_zone, section * ZoneData.SECTION_SIZE + 3)
			var gate := _add_box_body(zone_root, position + Vector3(0.0, 2.5, -2.1), Vector3(8.0, 4.5, 0.6), wall_material, "TimedDoor")
			gate.set_meta("closed_position", gate.position)
			gate.set_meta("phase", float(section) * 0.7)


func _create_secret_routes() -> void:
	var vine_material: StandardMaterial3D
	if current_zone == 5:
		vine_material = StandardMaterial3D.new()
		vine_material.albedo_texture = load("res://assets/vine.png") as Texture2D
		vine_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		vine_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		vine_material.albedo_color = Color.WHITE
		var length := float(ZoneData.PLATFORM_COUNT) * ZoneData.PLATFORM_SPACING + 50.0
		for index in range(42):
			var vine_mesh := QuadMesh.new()
			vine_mesh.size = Vector2(2.2, 6.0)
			var vine := MeshInstance3D.new()
			vine.mesh = vine_mesh
			vine.material_override = vine_material
			vine.position = Vector3(-24.8 if index % 2 == 0 else 24.8, 10.0, -5.0 - index * length / 42.0)
			vine.rotation.y = PI * 0.5 if index % 2 == 0 else -PI * 0.5
			zone_root.add_child(vine)
	for secret_number in range(7):
		var index := 8 + secret_number * ZoneData.SECTION_SIZE
		var base := ZoneData.platform_position(current_zone, index)
		var side := -1.0 if secret_number % 2 == 1 else 1.0
		var branches: Array[Vector3] = [
			Vector3(base.x + side * 4.1, base.y + 0.25, base.z - 1.5),
			Vector3(base.x + side * 6.8, base.y + 0.45, base.z - 4.3),
			Vector3(base.x + side * 4.2, base.y + 0.65, base.z - 7.1),
		]
		for branch_index in range(branches.size()):
			_add_box_body(zone_root, branches[branch_index], Vector3(3.0, 0.5, 3.0), platform_material, "SecretStep")
		var secret_id := "%d:%d" % [current_zone, secret_number + 1]
		if secret_id in collected_secrets:
			continue
		var orb := _make_sphere(Color(1.0, 0.83, 0.28), 0.48, true)
		orb.position = branches[2] + Vector3(0.0, 1.2, 0.0)
		orb.name = "Secret_%s" % secret_id
		orb.set_meta("secret_id", secret_id)
		zone_root.add_child(orb)
		orb.add_to_group("secrets")


func _create_zone_details() -> void:
	if current_zone == 5:
		return
	for index in range(7):
		var point := ZoneData.platform_position(current_zone, index * ZoneData.SECTION_SIZE + 1)
		if index % 2 == 0:
			var detail := _make_sphere(current_zone_config["platform_color"].lightened(0.4), 0.7, true)
			detail.position = Vector3(point.x + 7.0, point.y + 6.0, point.z - 9.0)
			zone_root.add_child(detail)


func _create_goal() -> void:
	var goal := _make_sphere(Color(1.0, 0.78, 0.26), 1.5, true)
	goal.name = "Goal"
	goal.position = ZoneData.platform_position(current_zone, ZoneData.PLATFORM_COUNT - 1) + Vector3(0.0, 2.0, 0.0)
	zone_root.add_child(goal)


func _make_sphere(tint: Color, diameter: float, emissive: bool) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = diameter * 0.5
	sphere.height = diameter
	instance.mesh = sphere
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	if emissive:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.emission_enabled = true
		material.emission = tint
	instance.material_override = material
	return instance


func _add_box_body(parent: Node3D, position: Vector3, dimensions: Vector3, material: Material, node_name: String, moving := false) -> StaticBody3D:
	var body: StaticBody3D
	if moving:
		body = AnimatableBody3D.new()
		(body as AnimatableBody3D).sync_to_physics = true
	else:
		body = StaticBody3D.new()
	body.name = node_name
	body.position = position
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = dimensions
	collision.shape = shape
	body.add_child(collision)
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _box_material(material)
	body.add_child(mesh_instance)
	parent.add_child(body)
	return body


func _add_box_mesh(parent: Node3D, position: Vector3, dimensions: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	instance.mesh = mesh
	instance.material_override = _box_material(material)
	instance.position = position
	parent.add_child(instance)
	return instance


func _update_streaming(force := false) -> void:
	if not is_instance_valid(zone_root) or not is_instance_valid(player):
		return
	var center := clampi(int(round(-player.global_position.z / ZoneData.PLATFORM_SPACING)), 0, ZoneData.PLATFORM_COUNT - 1)
	if not force and platforms.has("_center") and int(platforms["_center"]) == center:
		return
	platforms["_center"] = center
	var first_index := maxi(0, center - STREAM_BACK)
	var last_index := mini(ZoneData.PLATFORM_COUNT - 1, center + STREAM_FORWARD)
	for index in range(first_index, last_index + 1):
		if not platforms.has(index):
			_spawn_platform(index)
	var stale_keys: Array = []
	for key in platforms:
		if key is int and (int(key) < first_index or int(key) > last_index):
			stale_keys.append(key)
	for key in stale_keys:
		var data: Dictionary = platforms[key]
		if is_instance_valid(data["body"]):
			data["body"].queue_free()
		platforms.erase(key)


func _spawn_platform(index: int) -> void:
	var position := ZoneData.platform_position(current_zone, index)
	var kind := ZoneData.platform_kind(current_zone, index)
	var dimensions := Vector3(3.2, 0.5, 3.2)
	if kind == "moving":
		dimensions = Vector3(4.0, 0.5, 3.6) if index % 2 == 0 else Vector3(3.4, 0.5, 3.4)
	elif kind == "rotating":
		dimensions = Vector3(4.0, 0.5, 1.9)
	var body := _add_box_body(zone_root, position, dimensions, platform_material, "Platform_%03d_%s" % [index, kind], kind in ["moving", "rotating"])
	var mesh_instance := body.get_child(1) as MeshInstance3D
	if kind == "normal":
		var tint := Color.from_hsv(fposmod(index * 0.052, 1.0), 0.14, 0.96)
		var tinted := (mesh_instance.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
		tinted.albedo_color = tint if tinted.albedo_texture == null else Color.WHITE
		mesh_instance.material_override = tinted
	if index % ZoneData.CHECKPOINT_SPACING == ZoneData.CHECKPOINT_SPACING - 1:
		var marker := _make_sphere(Color(1.0, 0.69, 0.2), 0.64, true)
		marker.position.y = 0.75
		body.add_child(marker)
	var collision := body.get_child(0) as CollisionShape3D
	var phase := float(index / ZoneData.SECTION_SIZE) * 1.1
	platforms[index] = {
		"body": body,
		"collision": collision,
		"kind": kind,
		"origin": position,
		"dimensions": dimensions,
		"phase": phase,
		"stand_time": 0.0,
		"reset_time": 0.0,
		"active": true,
	}


func _update_platforms(delta: float) -> void:
	for key in platforms:
		if not key is int:
			continue
		var data: Dictionary = platforms[key]
		var body := data["body"] as StaticBody3D
		if not is_instance_valid(body):
			continue
		var kind: String = data["kind"]
		if kind == "moving":
			body.position = data["origin"] + ZoneData.moving_offset(current_zone) * sin(course_time * (0.56 + float(int(key) / 100 % 3) * 0.14))
		elif kind == "rotating":
			body.rotation.y += delta * 0.42
		elif kind == "timed":
			var phase := fposmod(course_time + float(data["phase"]), 8.0)
			_set_platform_active(data, phase < 5.2)
		elif kind == "collapsing":
			_update_collapsing_platform(data, delta)
	for body in zone_root.get_children():
		if body is StaticBody3D and body.has_meta("closed_position"):
			var phase := fposmod(course_time + float(body.get_meta("phase")), 8.0)
			var open := phase < 3.5
			var closed_position: Vector3 = body.get_meta("closed_position")
			body.position = closed_position + Vector3(0.0, 5.5 if open else 0.0, 0.0)


func _set_platform_active(data: Dictionary, active: bool) -> void:
	if bool(data["active"]) == active:
		return
	data["active"] = active
	data["body"].visible = active
	data["collision"].set_deferred("disabled", not active)


func _update_collapsing_platform(data: Dictionary, delta: float) -> void:
	var reset_time: float = data["reset_time"]
	if reset_time > 0.0:
		reset_time = maxf(0.0, reset_time - delta)
		data["reset_time"] = reset_time
		if reset_time == 0.0:
			data["body"].visible = true
			data["collision"].set_deferred("disabled", false)
			data["stand_time"] = 0.0
		return
	var body := data["body"] as StaticBody3D
	var dimensions: Vector3 = data["dimensions"]
	var standing := player.is_on_floor() and absf(player.global_position.y - (body.global_position.y + 0.25)) < 0.22
	standing = standing and absf(player.global_position.x - body.global_position.x) < dimensions.x * 0.5 + 0.2
	standing = standing and absf(player.global_position.z - body.global_position.z) < dimensions.z * 0.5 + 0.2
	if standing:
		data["stand_time"] = float(data["stand_time"]) + delta
		if float(data["stand_time"]) >= 1.1:
			body.visible = false
			data["collision"].set_deferred("disabled", true)
			data["reset_time"] = 3.0
			_play_sfx()
	else:
		data["stand_time"] = 0.0


func _check_checkpoint() -> void:
	if not player.is_on_floor():
		return
	var step: int = clampi(int(round(-player.global_position.z / ZoneData.PLATFORM_SPACING)), 0, ZoneData.PLATFORM_COUNT - 1)
	var checkpoint_index := step - step % ZoneData.CHECKPOINT_SPACING + ZoneData.CHECKPOINT_SPACING - 1
	if checkpoint_index < 0 or checkpoint_index >= ZoneData.PLATFORM_COUNT:
		return
	var position := ZoneData.platform_position(current_zone, checkpoint_index)
	if player.global_position.distance_to(position) > 2.0 or position.z >= current_checkpoint.z:
		return
	current_checkpoint = position + Vector3(0.0, 0.29, 0.0)
	checkpoint_by_zone[str(current_zone)] = [current_checkpoint.x, current_checkpoint.y, current_checkpoint.z]
	_save_progress()
	checkpoint_notice_time = 3.0
	status_label.text = "CHECKPOINT SAVED"
	_play_sfx()


func _check_secrets() -> void:
	for orb in zone_root.get_tree().get_nodes_in_group("secrets"):
		if not is_instance_valid(orb) or not orb.is_inside_tree():
			continue
		orb.rotate_y(0.8 * get_process_delta_time())
		if player.global_position.distance_to(orb.global_position) < 1.5:
			var secret_id: String = str(orb.get_meta("secret_id"))
			if not secret_id in collected_secrets:
				collected_secrets.append(secret_id)
				_save_progress()
			orb.queue_free()
			status_label.text = "SECRET FOUND"
			checkpoint_notice_time = 2.5
			_play_sfx()


func _respawn_at_checkpoint() -> void:
	player.global_position = current_checkpoint + Vector3(0.0, 0.15, 0.0)
	player.velocity = Vector3.ZERO
	player.wall_run_time = 0.0


func _complete_zone() -> void:
	if not gameplay_active:
		return
	gameplay_active = false
	game_paused = false
	player.set_gameplay_active(false, is_mobile)
	ambience_player.stop()
	var elapsed := elapsed_time
	var key := str(current_zone)
	if not best_times.has(key) or elapsed < float(best_times[key]):
		best_times[key] = snappedf(elapsed, 0.1)
	if current_zone < ZoneData.ZONES.size() and not (current_zone + 1 in unlocked_zones):
		unlocked_zones.append(current_zone + 1)
	unlocked_zones.sort()
	_save_progress()
	completion_next_button.text = "NEXT CHAPTER" if current_zone < ZoneData.ZONES.size() else "FINISH GAME"
	completion_description_label.text = "%s\nTIME  %02d:%02d" % [current_zone_config["name"], int(elapsed / 60.0), int(elapsed) % 60]
	_set_screen("complete")


func _start_game(zone_number: int, resume: bool) -> void:
	if not zone_number in unlocked_zones:
		return
	_create_zone(zone_number)
	saved_current_zone = zone_number
	var spawn := Vector3(0.0, 0.85, 1.4)
	if resume and checkpoint_by_zone.has(str(zone_number)):
		var saved: Array = checkpoint_by_zone[str(zone_number)]
		if saved.size() == 3:
			var candidate := Vector3(float(saved[0]), float(saved[1]), float(saved[2]))
			if absf(candidate.x) <= 15.0 and candidate.y >= 0.0 and candidate.y <= 20.0 and candidate.z <= 0.0 and absf(candidate.z) < ZoneData.PLATFORM_COUNT * ZoneData.PLATFORM_SPACING:
				spawn = candidate
				current_checkpoint = candidate
			else:
				push_warning("Ignoring an out-of-range saved checkpoint.")
				current_checkpoint = spawn
	else:
		current_checkpoint = spawn
	player.global_position = spawn
	player.rotation = Vector3.ZERO
	player.pitch = 0.0
	player.camera.rotation = Vector3.ZERO
	player.velocity = Vector3.ZERO
	_update_streaming(true)
	elapsed_time = 0.0
	course_time = 0.0
	_save_progress()
	gameplay_active = true
	game_paused = false
	player.set_gameplay_active(true, is_mobile)
	hud.visible = true
	_set_screen("")
	if is_mobile:
		_touch_controls_visible(true)
	_start_ambience()
	status_label.text = "JOYSTICK MOVE   JUMP   SPRINT   WALL-RUN" if is_mobile else "WASD MOVE   SPACE JUMP   SHIFT SPRINT   E WALL-RUN"
	tutorial_notice_time = 4.5


func _start_new_game() -> void:
	unlocked_zones = [1]
	saved_current_zone = 1
	checkpoint_by_zone.clear()
	best_times.clear()
	collected_secrets.clear()
	_save_progress()
	_start_game(1, false)


func _return_to_title() -> void:
	gameplay_active = false
	game_paused = false
	player.set_gameplay_active(false, is_mobile)
	ambience_player.stop()
	hud.visible = false
	_touch_controls_visible(false)
	_set_screen("title")


func _set_paused(paused: bool) -> void:
	game_paused = paused
	if paused:
		_clear_mobile_input()
		player.set_gameplay_active(false, is_mobile)
		ambience_player.stop()
		_set_screen("pause")
	else:
		player.set_gameplay_active(true, is_mobile)
		_set_screen("")
		_start_ambience()


func _set_screen(screen_name: String) -> void:
	active_screen = screen_name
	for key in screens:
		screens[key].visible = key == screen_name
	if screen_name == "":
		hud.visible = gameplay_active
	elif screen_name != "pause" and screen_name != "settings":
		hud.visible = false


func _clear_mobile_input() -> void:
	joystick_pointer = -1
	look_pointer = -1
	touch_origins.clear()
	joystick_vector = Vector2.ZERO
	if is_instance_valid(player):
		player.mobile_movement = Vector2.ZERO
		player.mobile_jump = false
		player.mobile_sprint = false
		player.mobile_wall_run = false
	if is_instance_valid(joystick_knob):
		joystick_knob.position = Vector2(40.0, 40.0)


func _start_ambience() -> void:
	_start_music()


func _start_music(preview := false) -> void:
	if not gameplay_active and not preview:
		return
	var stream: AudioStream
	if not selected_music_path.is_empty():
		if _music_path_exists(selected_music_path):
			stream = _load_music_stream(selected_music_path)
		if stream == null:
			push_warning("The selected song could not be opened: %s" % selected_music_path)
			_set_default_music_selection()
			stream = _load_music_stream(selected_music_path)
			_save_settings()
	if stream == null:
		var track := selected_ambience
		if track < 1 or track > 6:
			track = current_zone
		var path := "res://assets/audio/zone%d_ambient.wav" % track
		stream = load(path) as AudioStream
	if stream == null:
		push_warning("The selected music and zone ambience could not be loaded.")
		return
	ambience_player.stop()
	ambience_player.stream = stream
	ambience_player.volume_db = linear_to_db(maxf(0.001, float(settings["music_volume"])))
	ambience_player.play()


func _load_music_stream(path: String) -> AudioStream:
	var stream: AudioStream
	if path.begins_with("res://"):
		stream = load(path) as AudioStream
	else:
		match path.get_extension().to_lower():
			"mp3":
				stream = AudioStreamMP3.load_from_file(path)
			"ogg":
				stream = AudioStreamOggVorbis.load_from_file(path)
			"wav":
				stream = AudioStreamWAV.load_from_file(path)
			_:
				return null
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	return stream


func _music_path_exists(path: String) -> bool:
	if path.begins_with("res://"):
		return ResourceLoader.exists(path)
	return FileAccess.file_exists(path)


func _on_ambience_finished() -> void:
	if gameplay_active and not game_paused:
		ambience_player.play()


func _play_sfx() -> void:
	if sfx_player.stream == null:
		return
	sfx_player.volume_db = linear_to_db(maxf(0.001, float(settings["sfx_volume"])))
	sfx_player.stop()
	sfx_player.play()


func _load_progress() -> void:
	if not FileAccess.file_exists(progress_path):
		return
	var file := FileAccess.open(progress_path, FileAccess.READ)
	if file == null:
		push_warning("Could not read progress save: %s" % error_string(FileAccess.get_open_error()))
		return
	var decoded: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not decoded is Dictionary:
		push_warning("Progress save has an invalid format; using new-game defaults.")
		return
	var data: Dictionary = decoded
	var saved_unlocked: Variant = data.get("unlocked_zones", [1])
	if saved_unlocked is Array:
		for zone_number in saved_unlocked:
			if zone_number is int and zone_number >= 1 and zone_number <= ZoneData.ZONES.size() and not zone_number in unlocked_zones:
				unlocked_zones.append(zone_number)
	if not 1 in unlocked_zones:
		unlocked_zones.append(1)
	unlocked_zones.sort()
	var saved_checkpoints: Variant = data.get("checkpoints", {})
	if saved_checkpoints is Dictionary:
		checkpoint_by_zone = saved_checkpoints
	var saved_times: Variant = data.get("best_times", {})
	if saved_times is Dictionary:
		best_times = saved_times
	var saved_secrets: Variant = data.get("secrets", [])
	if saved_secrets is Array:
		for secret_id in saved_secrets:
			if secret_id is String and not secret_id in collected_secrets:
				collected_secrets.append(secret_id)
	var saved_track := int(data.get("selected_ambience", 1))
	if saved_track >= 1 and saved_track <= 6:
		selected_ambience = saved_track
	var saved_zone := int(data.get("saved_current_zone", data.get("current_zone", 1)))
	if saved_zone >= 1 and saved_zone <= ZoneData.ZONES.size():
		saved_current_zone = saved_zone


func _save_progress() -> void:
	var data := {
		"current_zone": current_zone,
		"saved_current_zone": saved_current_zone,
		"unlocked_zones": unlocked_zones,
		"checkpoints": checkpoint_by_zone,
		"best_times": best_times,
		"secrets": collected_secrets,
		"selected_ambience": selected_ambience,
	}
	var file := FileAccess.open(progress_path, FileAccess.WRITE)
	if file == null:
		push_warning("Could not save progress: %s" % error_string(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()


func _load_settings() -> void:
	var config := ConfigFile.new()
	var result := config.load(settings_path)
	if result == ERR_FILE_NOT_FOUND:
		if not music_selection_explicit:
			_set_default_music_selection()
		return
	if result != OK:
		push_warning("Could not read settings: %s" % error_string(result))
		return
	settings["music_volume"] = clampf(float(config.get_value("audio", "music_volume", 0.28)), 0.0, 1.0)
	settings["sfx_volume"] = clampf(float(config.get_value("audio", "sfx_volume", 0.72)), 0.0, 1.0)
	settings["mouse_sensitivity"] = clampf(float(config.get_value("controls", "mouse_sensitivity", 0.0025)), 0.001, 0.006)
	settings["graphics"] = str(config.get_value("video", "graphics", "low"))
	settings["show_fps"] = bool(config.get_value("video", "show_fps", false))
	var has_saved_music_path := config.has_section_key("audio", "selected_music_path")
	selected_music_path = str(config.get_value("audio", "selected_music_path", DEFAULT_MUSIC_PATH))
	selected_music_name = str(config.get_value("audio", "selected_music_name", ""))
	music_selection_explicit = bool(config.get_value("audio", "music_selection_explicit", has_saved_music_path and not selected_music_path.is_empty()))
	var saved_tracks: Variant = config.get_value("audio", "custom_music_tracks", [])
	if saved_tracks is Array:
		for track in saved_tracks:
			if not track is Dictionary:
				continue
			var path := str(track.get("path", ""))
			var name := str(track.get("name", ""))
			if path.is_empty() or name.is_empty() or not FileAccess.file_exists(path):
				continue
			custom_music_tracks.append({"path": path, "name": name})
	if not selected_music_path.is_empty() and not _music_path_exists(selected_music_path):
		_set_default_music_selection()
	elif selected_music_path.is_empty() and not music_selection_explicit:
		_set_default_music_selection()


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "music_volume", settings["music_volume"])
	config.set_value("audio", "sfx_volume", settings["sfx_volume"])
	config.set_value("controls", "mouse_sensitivity", settings["mouse_sensitivity"])
	config.set_value("video", "graphics", settings["graphics"])
	config.set_value("video", "show_fps", settings["show_fps"])
	config.set_value("audio", "custom_music_tracks", custom_music_tracks)
	config.set_value("audio", "selected_music_path", selected_music_path)
	config.set_value("audio", "selected_music_name", selected_music_name)
	config.set_value("audio", "music_selection_explicit", music_selection_explicit)
	var result := config.save(settings_path)
	if result != OK:
		push_warning("Could not save settings: %s" % error_string(result))


func _create_interface() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 2
	add_child(canvas)
	ui_root = Control.new()
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_PASS
	canvas.add_child(ui_root)
	_create_hud()
	_create_title_screen()
	_create_chapters_screen()
	_create_new_game_screen()
	_create_settings_screen()
	_create_soundtrack_screen()
	_create_controls_screen()
	_create_pause_screen()
	_create_completion_screen()


func _create_hud() -> void:
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.offset_left = 28.0
	hud.offset_top = 30.0
	hud.offset_right = -28.0
	hud.offset_bottom = -28.0
	hud.visible = false
	ui_root.add_child(hud)
	zone_label = Label.new()
	zone_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	zone_label.offset_left = 24.0
	zone_label.offset_top = 18.0
	zone_label.offset_bottom = 58.0
	zone_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	zone_label.add_theme_font_size_override("font_size", 20)
	hud.add_child(zone_label)
	status_label = Label.new()
	status_label.set_anchors_preset(Control.PRESET_CENTER)
	status_label.offset_left = -290.0
	status_label.offset_top = 100.0
	status_label.offset_right = 290.0
	status_label.offset_bottom = 150.0
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 21)
	status_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.54))
	hud.add_child(status_label)
	fps_label = Label.new()
	fps_label.position = Vector2(20.0, 74.0)
	fps_label.add_theme_font_size_override("font_size", 16)
	fps_label.visible = bool(settings["show_fps"])
	hud.add_child(fps_label)
	var pause_button := _make_button(hud, "SETTINGS" if is_mobile else "MENU", Vector2(112.0, 52.0), 16)
	_place_control(pause_button, 0.96, 0.07, 112.0, 50.0)
	if is_mobile:
		pause_button.pressed.connect(func(): _open_settings())
	else:
		pause_button.pressed.connect(func(): _set_paused(true))
	_create_touch_controls()
	screens[""] = Control.new()
	screens[""].set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screens[""].mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(screens[""])


func _create_touch_controls() -> void:
	var base := Panel.new()
	base.custom_minimum_size = Vector2(132.0, 132.0)
	base.add_theme_stylebox_override("panel", _round_style(Color(0.08, 0.1, 0.15, 0.50), 70))
	base.position = Vector2(123.0, 480.0)
	base.size = Vector2(132.0, 132.0)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(base)
	joystick_base = base
	var knob := Panel.new()
	knob.size = Vector2(52.0, 52.0)
	knob.position = Vector2(40.0, 40.0)
	knob.add_theme_stylebox_override("panel", _round_style(Color(0.78, 0.82, 0.9, 0.72), 28))
	knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	base.add_child(knob)
	joystick_knob = knob
	var jump := _make_button(hud, "JUMP", Vector2(98.0, 86.0), 18)
	_place_control(jump, 0.88, 0.84, 98.0, 88.0)
	jump.button_down.connect(func(): player.mobile_jump = true)
	jump.button_up.connect(func(): player.mobile_jump = false)
	var sprint := _make_button(hud, "SPRINT", Vector2(82.0, 72.0), 15)
	_place_control(sprint, 0.74, 0.88, 82.0, 72.0)
	sprint.button_down.connect(func(): player.mobile_sprint = true)
	sprint.button_up.connect(func(): player.mobile_sprint = false)
	var wall_run := _make_button(hud, "WALL", Vector2(72.0, 64.0), 14)
	_place_control(wall_run, 0.79, 0.70, 72.0, 64.0)
	wall_run.button_down.connect(func(): player.mobile_wall_run = true)
	wall_run.button_up.connect(func(): player.mobile_wall_run = false)
	_touch_controls_visible(false)


func _touch_controls_visible(visible: bool) -> void:
	if not is_instance_valid(joystick_base):
		return
	joystick_base.visible = visible
	for control in hud.get_children():
		if control is Button and (control.text == "JUMP" or control.text == "SPRINT" or control.text == "WALL"):
			control.visible = visible


func _create_title_screen() -> void:
	var screen := _new_screen("title", "DARK FANTASY", "SIX LIMINAL ZONES  ·  ONE LONG WAY HOME")
	screens["title"] = screen["root"]
	var content: VBoxContainer = screen["content"]
	var play := _make_button(content, "PLAY", Vector2(360.0, 46.0))
	play.pressed.connect(func(): _start_game(1, false))
	var resume := _make_button(content, "CONTINUE", Vector2(360.0, 46.0))
	resume.pressed.connect(func(): _start_game(_saved_zone(), true))
	var chapters := _make_button(content, "CHAPTERS", Vector2(360.0, 46.0))
	chapters.pressed.connect(func(): _set_screen("chapters"))
	var settings_button := _make_button(content, "SETTINGS", Vector2(360.0, 46.0))
	settings_button.pressed.connect(func(): _open_settings())
	var soundtrack := _make_button(content, "SOUNDTRACK", Vector2(360.0, 46.0))
	soundtrack.pressed.connect(func(): _set_screen("soundtrack"))
	var controls := _make_button(content, "CONTROLS", Vector2(360.0, 46.0))
	controls.pressed.connect(func(): _set_screen("controls"))
	var new_game := _make_button(content, "NEW GAME", Vector2(360.0, 46.0))
	new_game.pressed.connect(func(): _set_screen("new_game"))
	var quit := _make_button(content, "QUIT GAME", Vector2(360.0, 46.0))
	quit.pressed.connect(func(): get_tree().quit())


func _saved_zone() -> int:
	return saved_current_zone if saved_current_zone in unlocked_zones else 1


func _create_chapters_screen() -> void:
	var screen := _new_screen("chapters", "CHOOSE A CHAPTER", "Select an unlocked chapter.")
	screens["chapters"] = screen["root"]
	chapter_details = screen["description"]
	var content: VBoxContainer = screen["content"]
	for index in range(ZoneData.ZONES.size()):
		var zone_number := index + 1
		var button := _make_button(content, "", Vector2(400.0, 42.0), 18)
		button.name = "Zone%d" % zone_number
		_update_chapter_button(button, zone_number)
		button.pressed.connect(_start_game.bind(zone_number, false))
		button.mouse_entered.connect(_show_chapter_summary.bind(zone_number))
		button.focus_entered.connect(_show_chapter_summary.bind(zone_number))
	var back := _make_button(content, "BACK", Vector2(360.0, 42.0))
	back.pressed.connect(func(): _set_screen("title"))
	chapter_details.text = _chapter_summary(1)


func _chapter_summary(zone_number: int) -> String:
	var summary := str(ZoneData.zone(zone_number)["description"])
	if best_times.has(str(zone_number)):
		summary += "\nBest time: %.1f seconds" % float(best_times[str(zone_number)])
	else:
		summary += "\nNot completed yet"
	var secret_count := 0
	for secret_id in collected_secrets:
		if secret_id.begins_with("%d:" % zone_number):
			secret_count += 1
	summary += "\nSecrets: %d / 7" % secret_count
	return summary


func _show_chapter_summary(zone_number: int) -> void:
	chapter_details.text = _chapter_summary(zone_number)


func _create_new_game_screen() -> void:
	var screen := _new_screen("new_game", "START A NEW GAME?", "This resets unlocked chapters, checkpoints, and collected secrets.")
	screens["new_game"] = screen["root"]
	var content: VBoxContainer = screen["content"]
	var reset := _make_button(content, "RESET PROGRESS", Vector2(360.0, 50.0))
	reset.pressed.connect(func(): _start_new_game())
	var cancel := _make_button(content, "CANCEL", Vector2(360.0, 46.0))
	cancel.pressed.connect(func(): _set_screen("title"))


func _update_chapter_button(button: Button, zone_number: int) -> void:
	var config := ZoneData.zone(zone_number)
	var unlocked := zone_number in unlocked_zones
	button.text = "%02d   %s%s" % [zone_number, str(config["name"]).to_upper(), "" if unlocked else "   ·   LOCKED"]
	button.disabled = not unlocked


func _create_settings_screen() -> void:
	var screen := _new_screen("settings", "SETTINGS", "Changes are saved on this device.")
	screens["settings"] = screen["root"]
	var content: VBoxContainer = screen["content"]
	_make_label(content, "MUSIC / AMBIENCE", 16)
	var music := HSlider.new()
	music.min_value = 0.0
	music.max_value = 1.0
	music.step = 0.05
	music.value = float(settings["music_volume"])
	content.add_child(music)
	music.value_changed.connect(_set_music_volume)
	var music_library := _make_button(content, "CHOOSE MUSIC", Vector2(360.0, 42.0))
	music_library.pressed.connect(func(): _set_screen("soundtrack"))
	_make_label(content, "SOUND EFFECTS", 16)
	var sfx := HSlider.new()
	sfx.min_value = 0.0
	sfx.max_value = 1.0
	sfx.step = 0.05
	sfx.value = float(settings["sfx_volume"])
	content.add_child(sfx)
	sfx.value_changed.connect(_set_sfx_volume)
	_make_label(content, "GRAPHICS QUALITY", 16)
	var quality := OptionButton.new()
	for item in ["Low", "Medium", "High"]:
		quality.add_item(item)
	quality.select(maxi(["low", "medium", "high"].find(str(settings["graphics"]).to_lower()), 0))
	content.add_child(quality)
	quality.item_selected.connect(func(index: int):
		settings["graphics"] = ["low", "medium", "high"][index]
		_apply_zone_atmosphere()
		_save_settings()
	)
	var fps := CheckButton.new()
	fps.text = "Show FPS counter"
	fps.button_pressed = bool(settings["show_fps"])
	content.add_child(fps)
	fps.toggled.connect(func(enabled: bool):
		settings["show_fps"] = enabled
		fps_label.visible = enabled
		_save_settings()
	)
	var sensitivity := HSlider.new()
	sensitivity.min_value = 0.001
	sensitivity.max_value = 0.006
	sensitivity.step = 0.00025
	sensitivity.value = float(settings["mouse_sensitivity"])
	_make_label(content, "MOUSE / TOUCH LOOK SENSITIVITY", 16)
	content.add_child(sensitivity)
	sensitivity.value_changed.connect(func(value: float):
		settings["mouse_sensitivity"] = value
		player.look_sensitivity = value
		_save_settings()
	)
	var fullscreen := _make_button(content, "TOGGLE FULLSCREEN", Vector2(360.0, 42.0))
	fullscreen.pressed.connect(_toggle_fullscreen)
	var back := _make_button(content, "BACK", Vector2(360.0, 42.0))
	back.pressed.connect(func(): _set_screen(previous_screen))


func _set_music_volume(value: float) -> void:
	settings["music_volume"] = value
	ambience_player.volume_db = linear_to_db(maxf(0.001, value))
	_save_settings()


func _set_sfx_volume(value: float) -> void:
	settings["sfx_volume"] = value
	_save_settings()


func _toggle_fullscreen() -> void:
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func _open_settings() -> void:
	previous_screen = active_screen if active_screen != "settings" else "title"
	if gameplay_active and not game_paused:
		previous_screen = "pause"
		game_paused = true
		_clear_mobile_input()
		player.set_gameplay_active(false, is_mobile)
		ambience_player.stop()
	elif game_paused:
		_clear_mobile_input()
	_set_screen("settings")


func _create_soundtrack_screen() -> void:
	var screen := _new_screen("soundtrack", "SOUNDTRACK", "Choose an included song, import audio, or choose zone ambience.")
	screens["soundtrack"] = screen["root"]
	var content: VBoxContainer = screen["content"]
	var add_song := _make_button(content, "ADD SONG FROM PHONE" if is_mobile else "ADD SONG", Vector2(380.0, 46.0))
	add_song.pressed.connect(_open_music_picker)
	soundtrack_status_label = _make_label(content, "", 14)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(380.0, 210.0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(scroll)
	soundtrack_tracks_container = VBoxContainer.new()
	soundtrack_tracks_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	soundtrack_tracks_container.add_theme_constant_override("separation", 5)
	scroll.add_child(soundtrack_tracks_container)
	var back := _make_button(content, "BACK", Vector2(360.0, 42.0))
	back.pressed.connect(func(): _set_screen(previous_screen))
	_refresh_soundtrack_options()


func _select_ambience(track: int) -> void:
	selected_music_path = ""
	selected_music_name = ""
	music_selection_explicit = true
	selected_ambience = track
	_save_progress()
	_save_settings()
	_start_music(true)
	_update_soundtrack_selection_labels()


func _open_music_picker() -> void:
	soundtrack_status_label.text = ""
	if is_mobile:
		if audio_picker == null:
			_set_music_picker_status("The Android song picker is unavailable in this build.")
			return
		audio_picker.openAudioPicker()
		_set_music_picker_status("Choose an MP3, OGG, or WAV from your phone.")
		return
	music_file_dialog.popup_centered_ratio(0.82)


func _on_audio_picker_cancelled() -> void:
	_set_music_picker_status("No song selected.")


func _on_audio_picker_error(message: String) -> void:
	_set_music_picker_status(message)
	push_warning("Audio picker: %s" % message)


func _on_android_audio_selected(path: String, display_name: String) -> void:
	_register_custom_music(path, display_name)


func _on_desktop_audio_selected(source_path: String) -> void:
	var extension := source_path.get_extension().to_lower()
	if extension not in ["mp3", "ogg", "wav"]:
		_set_music_picker_status("Choose an MP3, OGG, or WAV audio file.")
		return
	var directory_path := ProjectSettings.globalize_path(music_library_path)
	var make_directory_result := DirAccess.make_dir_recursive_absolute(directory_path)
	if make_directory_result != OK:
		_set_music_picker_status("Could not create the music library: %s" % error_string(make_directory_result))
		return
	var display_name := source_path.get_file()
	var destination_path := music_library_path.path_join("%d-%s" % [Time.get_ticks_usec(), display_name.validate_filename()])
	var source_absolute_path := ProjectSettings.globalize_path(source_path) if source_path.begins_with("res://") or source_path.begins_with("user://") else source_path
	var destination_absolute_path := ProjectSettings.globalize_path(destination_path)
	var copy_result := DirAccess.copy_absolute(source_absolute_path, destination_absolute_path)
	if copy_result != OK:
		_set_music_picker_status("Could not copy the song: %s" % error_string(copy_result))
		return
	_register_custom_music(destination_absolute_path, display_name)


func _register_custom_music(path: String, display_name: String) -> void:
	if not FileAccess.file_exists(path):
		_set_music_picker_status("The selected audio file could not be found.")
		return
	if path.get_extension().to_lower() not in ["mp3", "ogg", "wav"]:
		_set_music_picker_status("Choose an MP3, OGG, or WAV audio file.")
		return
	var stream := _load_music_stream(path)
	if stream == null:
		_set_music_picker_status("This audio file could not be decoded. Choose an MP3, OGG, or WAV file.")
		return
	var track_name := display_name.get_basename().strip_edges()
	if track_name.is_empty():
		track_name = "Imported song"
	var found := false
	for index in range(custom_music_tracks.size()):
		if str(custom_music_tracks[index]["path"]) == path:
			custom_music_tracks[index]["name"] = track_name
			found = true
			break
	if not found:
		custom_music_tracks.append({"path": path, "name": track_name})
	selected_music_path = path
	selected_music_name = track_name
	music_selection_explicit = true
	_save_settings()
	_start_music(true)
	_set_music_picker_status("Now playing: %s" % track_name)
	_refresh_soundtrack_options()


func _refresh_soundtrack_options() -> void:
	if not is_instance_valid(soundtrack_tracks_container):
		return
	for child in soundtrack_tracks_container.get_children():
		soundtrack_tracks_container.remove_child(child)
		child.free()
	var ambience_heading := _make_label(soundtrack_tracks_container, "ZONE AMBIENCE", 14)
	ambience_heading.custom_minimum_size.y = 28.0
	ambience_heading.set_meta("soundtrack_heading", "ambience")
	for index in range(ZoneData.ZONES.size()):
		var track := index + 1
		var label := "%02d   %s" % [track, str(ZoneData.zone(track)["name"]).to_upper()]
		var button := _make_button(soundtrack_tracks_container, label, Vector2(380.0, 40.0), 16)
		button.set_meta("ambience_track", track)
		button.set_meta("track_label", label)
		button.pressed.connect(_select_ambience.bind(track))
	var included_heading := _make_label(soundtrack_tracks_container, "INCLUDED SOUNDTRACKS", 14)
	included_heading.custom_minimum_size.y = 28.0
	for track in BUILT_IN_SOUNDTRACKS:
		var path := str(track["path"])
		var label := str(track["name"])
		var button := _make_button(soundtrack_tracks_container, label, Vector2(380.0, 40.0), 16)
		button.set_meta("music_path", path)
		button.set_meta("track_label", label)
		button.pressed.connect(_select_music_track.bind(path, str(track["name"])))
	if not custom_music_tracks.is_empty():
		var library_heading := _make_label(soundtrack_tracks_container, "YOUR SONGS", 14)
		library_heading.custom_minimum_size.y = 28.0
	for track in custom_music_tracks:
		var path := str(track["path"])
		var label := str(track["name"])
		var button := _make_button(soundtrack_tracks_container, label, Vector2(380.0, 40.0), 16)
		button.set_meta("music_path", path)
		button.set_meta("track_label", label)
		button.pressed.connect(_select_music_track.bind(path, str(track["name"])))
	_update_soundtrack_selection_labels()


func _update_soundtrack_selection_labels() -> void:
	for child in soundtrack_tracks_container.get_children():
		if child is Label and child.has_meta("soundtrack_heading"):
			var heading := child as Label
			heading.text = "ZONE AMBIENCE  (NOW PLAYING)" if selected_music_path.is_empty() else "ZONE AMBIENCE"
		elif child is Button:
			var button := child as Button
			var label := str(button.get_meta("track_label", button.text))
			if button.has_meta("music_path"):
				if selected_music_path == str(button.get_meta("music_path")):
					label += "   (NOW PLAYING)"
			elif button.has_meta("ambience_track"):
				if selected_music_path.is_empty() and selected_ambience == int(button.get_meta("ambience_track")):
					label += "   (NOW PLAYING)"
			button.text = label


func _select_music_track(path: String, track_name: String) -> void:
	if not _music_path_exists(path):
		_set_music_picker_status("This song is no longer available.")
		return
	var stream := _load_music_stream(path)
	if stream == null:
		_set_music_picker_status("This soundtrack could not be decoded.")
		return
	selected_music_path = path
	selected_music_name = track_name
	music_selection_explicit = true
	_save_settings()
	_start_music(true)
	_set_music_picker_status("Now playing: %s" % track_name)
	_update_soundtrack_selection_labels()


func _set_default_music_selection() -> void:
	selected_music_path = DEFAULT_MUSIC_PATH
	selected_music_name = "Numbers"
	music_selection_explicit = false


func _set_music_picker_status(message: String) -> void:
	if is_instance_valid(soundtrack_status_label):
		soundtrack_status_label.text = message


func _create_controls_screen() -> void:
	var screen := _new_screen("controls", "CONTROLS", "")
	screens["controls"] = screen["root"]
	var content: VBoxContainer = screen["content"]
	var controls_text := "WINDOWS\nWASD  Move          Mouse  Look\nSPACE  Jump         LEFT SHIFT  Sprint\nE  Wall-run         ESC  Pause\n\nANDROID\nLeft joystick  Move       Right side  Look\nJUMP  Jump       SPRINT  Sprint\nWALL  Wall-run      MENU  Pause"
	_make_label(content, controls_text, 19)
	var back := _make_button(content, "BACK", Vector2(360.0, 46.0))
	back.pressed.connect(func(): _set_screen("title"))


func _create_pause_screen() -> void:
	var screen := _new_screen("pause", "PAUSED", "Your checkpoint is saved automatically.")
	screens["pause"] = screen["root"]
	var content: VBoxContainer = screen["content"]
	var resume := _make_button(content, "RESUME", Vector2(360.0, 50.0))
	resume.pressed.connect(func(): _set_paused(false))
	var settings_button := _make_button(content, "SETTINGS", Vector2(360.0, 50.0))
	settings_button.pressed.connect(func(): _open_settings())
	var title := _make_button(content, "RETURN TO TITLE", Vector2(360.0, 50.0))
	title.pressed.connect(func(): _return_to_title())


func _create_completion_screen() -> void:
	var screen := _new_screen("complete", "YOU MADE IT", "")
	screens["complete"] = screen["root"]
	var content: VBoxContainer = screen["content"]
	completion_description_label = screen["description"]
	completion_description_label.name = "Description"
	completion_next_button = _make_button(content, "NEXT CHAPTER", Vector2(360.0, 50.0))
	completion_next_button.name = "Next"
	completion_next_button.pressed.connect(_continue_after_completion)
	var chapters := _make_button(content, "CHAPTERS", Vector2(360.0, 46.0))
	chapters.pressed.connect(func(): _return_to_title(); _set_screen("chapters"))
	var title := _make_button(content, "RETURN TO TITLE", Vector2(360.0, 46.0))
	title.pressed.connect(func(): _return_to_title())


func _continue_after_completion() -> void:
	if current_zone < ZoneData.ZONES.size():
		_start_game(current_zone + 1, false)
	else:
		_return_to_title()


func _new_screen(screen_name: String, title: String, description: String) -> Dictionary:
	var root := Control.new()
	root.name = screen_name.capitalize()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.015, 0.012, 0.028, 0.89)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(backdrop)
	if screen_name == "title":
		var background := TextureRect.new()
		background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		background.texture = load("res://assets/menu_bg.png") as Texture2D
		background.modulate = Color(0.68, 0.64, 0.75, 0.58)
		background.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(background)
		backdrop.color = Color(0.02, 0.015, 0.032, 0.55)
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -278.0
	panel.offset_top = -292.0
	panel.offset_right = 278.0
	panel.offset_bottom = 292.0
	panel.add_theme_stylebox_override("panel", _round_style(Color(0.035, 0.035, 0.055, 0.96), 18))
	root.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 17)
	margin.add_theme_constant_override("margin_bottom", 17)
	panel.add_child(margin)
	var content := VBoxContainer.new()
	content.name = "Content"
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 7)
	margin.add_child(content)
	var heading := _make_label(content, title, 30)
	heading.add_theme_color_override("font_color", Color(0.91, 0.82, 0.66))
	var detail := _make_label(content, description, 15)
	detail.name = "Description"
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.visible = false
	ui_root.add_child(root)
	return {"root": root, "content": content, "description": detail}


func _make_button(parent: Control, text: String, dimensions: Vector2, font_size := 20) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = dimensions
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", Color(0.91, 0.89, 0.86))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.87, 0.55))
	button.add_theme_stylebox_override("normal", _round_style(Color(0.13, 0.14, 0.19, 0.96), 11))
	button.add_theme_stylebox_override("hover", _round_style(Color(0.23, 0.21, 0.25, 0.98), 11))
	button.add_theme_stylebox_override("pressed", _round_style(Color(0.30, 0.25, 0.23, 1.0), 11))
	button.add_theme_stylebox_override("disabled", _round_style(Color(0.10, 0.10, 0.12, 0.9), 11))
	parent.add_child(button)
	return button


func _make_label(parent: Control, text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.82, 0.81, 0.80))
	parent.add_child(label)
	return label


func _round_style(fill: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.64, 0.57, 0.51, 0.42)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	return style


func _place_control(control: Control, anchor_x: float, anchor_y: float, width: float, height: float) -> void:
	control.anchor_left = anchor_x
	control.anchor_right = anchor_x
	control.anchor_top = anchor_y
	control.anchor_bottom = anchor_y
	control.offset_left = -width * 0.5
	control.offset_right = width * 0.5
	control.offset_top = -height * 0.5
	control.offset_bottom = height * 0.5
