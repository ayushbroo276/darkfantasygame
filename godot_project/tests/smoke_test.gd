extends SceneTree

const ZoneData = preload("res://scripts/zone_data.gd")

var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := load("res://scenes/main.tscn") as PackedScene
	_expect(scene != null, "main scene can be loaded")
	if scene == null:
		quit(1)
		return
	var game: Node = scene.instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	game.set("progress_path", "user://smoke_test_progress.json")
	game.set("settings_path", "user://smoke_test_settings.cfg")
	game.set("unlocked_zones", [1])
	game.set("saved_current_zone", 1)
	(game.get("checkpoint_by_zone") as Dictionary).clear()
	(game.get("best_times") as Dictionary).clear()
	(game.get("collected_secrets") as Array).clear()

	var screens: Dictionary = game.get("screens")
	for screen_name in ["title", "chapters", "new_game", "settings", "soundtrack", "controls", "pause", "complete"]:
		_expect(screens.has(screen_name), "%s screen is present" % screen_name)

	game.call("_set_screen", "chapters")
	_expect(game.get("active_screen") == "chapters" and screens["chapters"].visible, "chapter menu opens")
	var unlocked_before_cancel: Array = game.get("unlocked_zones").duplicate()
	game.call("_set_screen", "new_game")
	_expect(screens["new_game"].visible, "new-game confirmation opens")
	game.call("_set_screen", "title")
	_expect(game.get("unlocked_zones") == unlocked_before_cancel, "canceling new game preserves progress")
	game.call("_set_screen", "settings")
	_expect(screens["settings"].visible, "settings menu opens")
	game.call("_set_screen", "soundtrack")
	_expect(screens["soundtrack"].visible, "soundtrack menu opens")
	game.call("_set_screen", "controls")
	_expect(screens["controls"].visible, "controls menu opens")

	game.call("_start_game", 1, false)
	await physics_frame
	await physics_frame
	var player := game.get("player") as CharacterBody3D
	_expect(game.get("gameplay_active") and game.get("current_zone") == 1, "zone 1 starts")
	_expect(game.get("platforms").size() >= 20, "nearby course platforms stream in")

	var starting_z := player.global_position.z
	Input.action_press("move_forward")
	for _frame in range(12):
		await physics_frame
	Input.action_release("move_forward")
	var walked_distance := starting_z - player.global_position.z
	_expect(walked_distance > 0.4, "forward movement advances the player")

	player.global_position = Vector3(0.0, 0.8, 1.4)
	player.velocity = Vector3.ZERO
	for _frame in range(3):
		await physics_frame
	Input.action_press("sprint")
	Input.action_press("move_forward")
	for _frame in range(12):
		await physics_frame
	Input.action_release("move_forward")
	Input.action_release("sprint")
	var sprint_distance := 1.4 - player.global_position.z
	_expect(sprint_distance > walked_distance * 1.1, "sprint increases movement speed")

	player.global_position = Vector3(0.0, 0.8, 1.4)
	player.velocity = Vector3.ZERO
	for _frame in range(3):
		await physics_frame
	Input.action_press("jump")
	for _frame in range(2):
		await physics_frame
	Input.action_release("jump")
	_expect(player.velocity.y > 3.0, "jump applies upward velocity")

	var checkpoint_position := ZoneData.platform_position(1, 49)
	player.global_position = checkpoint_position + Vector3(0.0, 1.3, 0.0)
	player.velocity = Vector3(0.0, -8.0, 0.0)
	game.call("_update_streaming", true)
	for _frame in range(14):
		await physics_frame
	var saved_checkpoints: Dictionary = game.get("checkpoint_by_zone")
	_expect(player.is_on_floor() and saved_checkpoints.has("1"), "landing on a checkpoint saves progress")

	var moving_position := ZoneData.platform_position(1, 30)
	player.global_position = moving_position + Vector3(0.0, 1.0, 0.0)
	game.call("_update_streaming", true)
	var platform_data: Dictionary = game.get("platforms")[30]
	var platform_body := platform_data["body"] as Node3D
	var old_platform_position := platform_body.position
	game.set("course_time", 1.0)
	await physics_frame
	_expect(platform_body.position.distance_to(old_platform_position) > 0.05, "moving platform advances")
	player.global_position = platform_body.global_position + Vector3(0.0, 0.31, 0.0)
	player.velocity = Vector3.ZERO
	for _frame in range(3):
		await physics_frame
	_expect(player.is_on_floor(), "player lands on a moving platform")
	var carried_start := player.global_position
	for _frame in range(10):
		await physics_frame
	_expect(player.global_position.distance_to(carried_start) > 0.03, "moving platform carries the player")

	game.call("_set_paused", true)
	_expect(game.get("game_paused") and screens["pause"].visible, "pause menu opens")
	game.call("_set_paused", false)
	_expect(not game.get("game_paused"), "pause menu resumes gameplay")

	game.set("is_mobile", true)
	game.call("_apply_safe_area")
	game.call("_start_game", 1, false)
	_expect(player.mobile_controls and game.get("joystick_base").visible, "touch controls appear on mobile")
	var safe_rect: Rect2 = game.get("safe_rect")
	_expect(safe_rect.size.x > 0.0 and safe_rect.size.y > 0.0, "mobile HUD safe area remains nonempty")
	var joystick_center := safe_rect.position + Vector2(safe_rect.size.x * 0.17, safe_rect.size.y * 0.80)
	game.call("_update_joystick", joystick_center)
	_expect(player.mobile_movement.length() < 0.2, "touch joystick is centered in the safe area")
	var old_yaw: float = player.rotation.y
	game.set("look_pointer", 7)
	var drag := InputEventScreenDrag.new()
	drag.index = 7
	drag.relative = Vector2(30.0, 0.0)
	game.call("_handle_screen_drag", drag)
	_expect(not is_equal_approx(player.rotation.y, old_yaw), "touch drag rotates the camera")
	game.call("_open_settings")
	_expect(game.get("game_paused") and game.get("active_screen") == "settings", "mobile settings pause gameplay")
	game.call("_set_screen", game.get("previous_screen"))
	_expect(game.get("active_screen") == "pause", "mobile settings return to pause menu")
	game.call("_set_paused", false)
	game.set("is_mobile", false)

	var wall_anchor := ZoneData.platform_position(1, 205)
	var wall_x := wall_anchor.x + 2.7
	player.global_position = Vector3(wall_x - 0.8, wall_anchor.y + 1.5, wall_anchor.z - 20.0)
	player.velocity = Vector3(0.0, -0.5, 0.0)
	await physics_frame
	_expect(bool(player.call("_wall_is_nearby")), "wall-run surface is detectable")
	Input.action_press("move_forward")
	Input.action_press("wall_run")
	for _frame in range(3):
		await physics_frame
	Input.action_release("move_forward")
	Input.action_release("wall_run")
	_expect(float(player.get("wall_run_time")) > 0.0, "wall-run input slows airborne descent")

	var unlocked: Array = game.get("unlocked_zones")
	for zone_number in range(2, 7):
		unlocked.append(zone_number)
	game.call("_start_game", 4, false)
	_expect(game.get("current_zone") == 4, "unlocked chapter can be started")
	_expect(ZoneData.platform_kind(4, 130) == "timed", "zone challenge data identifies timed steps")
	var timed_position := ZoneData.platform_position(4, 130)
	player.global_position = timed_position + Vector3(0.0, 1.0, 0.0)
	game.call("_update_streaming", true)
	var timed_data: Dictionary = game.get("platforms")[130]
	game.set("course_time", 5.0)
	await physics_frame
	_expect(not bool(timed_data["active"]), "timed platform cycles off")
	game.set("course_time", 0.0)
	await physics_frame
	_expect(bool(timed_data["active"]), "timed platform cycles on")

	game.call("_set_screen", "title")
	game.call("_start_game", 1, false)
	var goal_position: Vector3 = ZoneData.platform_position(1, ZoneData.PLATFORM_COUNT - 1) + Vector3(0.0, 2.0, 0.0)
	player.global_position = goal_position
	game.call("_physics_process", 1.0 / 30.0)
	_expect(not game.get("gameplay_active") and screens["complete"].visible, "finishing a course opens completion")
	_expect(2 in game.get("unlocked_zones"), "finishing a course unlocks the next chapter")

	var next_button := game.get("completion_next_button") as Button
	next_button.pressed.emit()
	await process_frame
	_expect(game.get("gameplay_active") and game.get("current_zone") == 2, "completion menu advances to the next chapter")

	game.call("_select_ambience", 3)
	_expect(game.get("selected_ambience") == 3, "soundtrack selection persists")
	var all_unlocked: Array = game.get("unlocked_zones")
	for zone_number in range(3, 7):
		all_unlocked.append(zone_number)
	for zone_number in range(1, 7):
		game.call("_start_game", zone_number, false)
		_expect(game.get("current_zone") == zone_number and game.get("gameplay_active"), "zone %d loads" % zone_number)
		_expect(game.get("platforms").size() >= 20, "zone %d streams its course" % zone_number)

	game.call("_return_to_title")
	game.queue_free()
	await process_frame
	for path in ["user://smoke_test_progress.json", "user://smoke_test_settings.cfg"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if failures == 0:
		print("Godot smoke test passed.")
		quit(0)
	else:
		push_error("%d Godot smoke test(s) failed." % failures)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		failures += 1
		push_error("FAIL: %s" % message)
