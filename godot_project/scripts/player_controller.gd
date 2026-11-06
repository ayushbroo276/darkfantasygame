extends CharacterBody3D

const WALK_SPEED := 7.0
const JUMP_SPEED := 8.4
const GRAVITY := 22.0
const SPRINT_MULTIPLIER := 1.7
const LOOK_SENSITIVITY := 0.0025
const MAX_WALL_RUN_TIME := 1.5

var camera: Camera3D
var can_control := false
var mobile_controls := false
var mobile_jump := false
var mobile_sprint := false
var mobile_wall_run := false
var mobile_movement := Vector2.ZERO
var wall_run_time := 0.0
var pitch := 0.0
var smoothed_speed := WALK_SPEED
var look_sensitivity := LOOK_SENSITIVITY


func _ready() -> void:
	floor_snap_length = 0.28
	floor_max_angle = deg_to_rad(48.0)
	floor_stop_on_slope = true
	floor_constant_speed = true
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = 1.8
	var collision := CollisionShape3D.new()
	collision.shape = capsule
	collision.position.y = 0.9
	add_child(collision)
	camera = Camera3D.new()
	camera.position.y = 1.58
	camera.fov = 84.0
	camera.near = 0.07
	camera.far = 220.0
	add_child(camera)


func _input(event: InputEvent) -> void:
	if not can_control or mobile_controls:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * look_sensitivity)
		pitch = clampf(pitch - event.relative.y * look_sensitivity, -1.48, 1.48)
		camera.rotation.x = pitch


func _physics_process(delta: float) -> void:
	if not can_control:
		velocity = Vector3.ZERO
		return

	var keys := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var movement := keys
	if mobile_controls and mobile_movement.length() > movement.length():
		movement = mobile_movement
	var local_direction := Vector3(movement.x, 0.0, movement.y)
	var direction := local_direction.rotated(Vector3.UP, rotation.y)
	if direction.length_squared() > 1.0:
		direction = direction.normalized()

	var sprinting := Input.is_action_pressed("sprint") or mobile_sprint
	var target_speed := WALK_SPEED * (SPRINT_MULTIPLIER if sprinting else 1.0)
	smoothed_speed = move_toward(smoothed_speed, target_speed, delta * WALK_SPEED * 5.0)
	velocity.x = direction.x * smoothed_speed
	velocity.z = direction.z * smoothed_speed

	if is_on_floor():
		wall_run_time = 0.0
		if Input.is_action_just_pressed("jump") or mobile_jump:
			velocity.y = JUMP_SPEED
	else:
		var wall_nearby := _wall_is_nearby()
		var wants_wall_run := Input.is_action_pressed("wall_run") or mobile_wall_run
		if wall_nearby and (wants_wall_run or movement.y < -0.35) and wall_run_time < MAX_WALL_RUN_TIME:
			wall_run_time += delta
			velocity.y = maxf(velocity.y - GRAVITY * delta * 0.12, -1.25)
		else:
			velocity.y = maxf(velocity.y - GRAVITY * delta, -38.0)

	move_and_slide()


func _wall_is_nearby() -> bool:
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3.UP * 1.15
	var exclusion: Array[RID] = [get_rid()]
	for side: float in [-1.0, 1.0]:
		var direction: Vector3 = global_basis.x * side
		var query := PhysicsRayQueryParameters3D.create(from, from + direction * 1.1)
		query.exclude = exclusion
		var hit := space.intersect_ray(query)
		if not hit.is_empty():
			return true
	return false


func set_gameplay_active(active: bool, use_touch: bool) -> void:
	can_control = active
	mobile_controls = use_touch
	if active and not use_touch:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if not active:
		mobile_jump = false
		mobile_sprint = false
		mobile_wall_run = false
		mobile_movement = Vector2.ZERO
