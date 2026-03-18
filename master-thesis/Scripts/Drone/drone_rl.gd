extends AIController3D

@export var no_bike_reset_steps: int = 500

@onready var drone: RigidBody3D = $".."

var _steps_without_bike: int = 0

func _physics_process(_delta):
	if needs_reset:
		reset()
		return

	var world = drone.get_parent()
	if shared.bike_lists[world.instance_id].is_empty():
		done = true
		needs_reset = true
		return

	drone.target_bike = _get_target_bike()

	if drone.target_bike == null:
		_steps_without_bike += 1

		reward -= 0.5

		if _steps_without_bike >= no_bike_reset_steps:
			done = true
			needs_reset = true
			return
		return

	_steps_without_bike = 0

	if drone.target_bike != null:
		# Ideal follow position: behind the bike at height_offset above it
		var bike_forward = -drone.target_bike.global_transform.basis.z
		bike_forward.y = 0.0
		bike_forward = bike_forward.normalized()
		var desired_pos = drone.target_bike.global_position - bike_forward * drone.behind_distance
		desired_pos.y = drone.target_bike.global_position.y + drone.height_offset

		# Dense position reward: 1/(1+error) gives useful gradient at all distances.
		# exp(-error/sigma) collapses to ~0 when far away, giving no signal to move.
		var pos_error = global_position.distance_to(desired_pos)
		reward += 1.0 / (1.0 + pos_error)

		# Speed-matching penalty: penalise forward speed mismatch to prevent overtaking.
		# Uses the bike's forward axis so only the along-track component is compared.
		var drone_fwd_speed = drone.linear_velocity.dot(bike_forward)
		var speed_diff = abs(drone_fwd_speed - drone.target_bike.speed)
		reward -= speed_diff * 0.03

		# Camera centering bonus: smaller secondary signal so it does not dominate.
		# Clamped to 0 so negative values (bike behind) do not subtract.
		var cam_forward = -drone.target_bike.get_camera_node().global_transform.basis.z
		var to_bike = (drone.target_bike.global_position - global_position).normalized()
		reward += maxf(0.0, cam_forward.dot(to_bike)) * 0.2

func _get_desired_pos() -> Vector3:
	var bike_forward = -drone.target_bike.global_transform.basis.z
	bike_forward.y = 0
	bike_forward = bike_forward.normalized()
	var pos = drone.target_bike.global_position - bike_forward * drone.behind_distance
	pos.y = drone.target_bike.global_position.y + drone.height_offset
	return pos

func _get_target_bike() -> Bike:
	var world = drone.get_parent()
	var closest_bike: Bike = null
	var min_dist := INF
	for bike_body: Bike_body in drone.drone_detector.bike_set.values():
		var bike: Bike = bike_body.get_parent()
		if bike.get_parent().get_parent() != world:
			continue
		var dist = drone.global_position.distance_to(bike.global_position)
		if dist < min_dist:
			min_dist = dist
			closest_bike = bike
	return closest_bike

func get_obs() -> Dictionary:
	var bikes_in_camera = drone.get_node("Camera_detection").bike_set
	var camera = drone.get_camera_node()

	var closest_bike_pos = Vector3.ZERO
	var closest_distance = INF
	var bike_speed = 0.0
	var bike_direction_local = Vector2.ZERO  # bike movement direction in drone-local x/z
	var cam_offset = Vector2.ZERO            # bike position in camera space, normalized

	for bike in bikes_in_camera:
		var pos = drone.to_local(bikes_in_camera[bike].global_position)
		var distance = pos.length()
		if distance < closest_distance:
			closest_distance = distance
			closest_bike_pos = pos
			bike_speed = bikes_in_camera[bike].get_parent().speed

			# Bike movement direction in drone-local space (x/z only — y is always ~0 on flat ground)
			var world_dir = -bikes_in_camera[bike].get_parent().global_transform.basis.z
			var local_dir = drone.global_transform.basis.inverse() * world_dir
			bike_direction_local = Vector2(local_dir.x, local_dir.z).normalized()

			# Camera-space offset: where in the camera image does the bike appear
			var to_bike_cam = camera.global_transform.basis.inverse() * (
				bikes_in_camera[bike].global_position - camera.global_position
			)
			# Divide by forward distance to get angular offset (tan of angle from center)
			var forward = -to_bike_cam.z
			if forward > 0.01:
				cam_offset.x = clamp(to_bike_cam.x / forward, -1.0, 1.0)
				cam_offset.y = clamp(to_bike_cam.y / forward, -1.0, 1.0)

	# Drone velocity in drone-local space
	var local_velocity = drone.global_transform.basis.inverse() * drone.linear_velocity

	# Normalize
	closest_bike_pos = closest_bike_pos / sqrt(pow(26.0, 2) + pow(5.0, 2))   # max expected distance. Max distance is sqrt(26^2 + 5^2) ~ 26.5 m (diagonal of drone detection box)
	bike_speed = bike_speed / 22.0               # max bike speed ~22 m/s
	local_velocity = local_velocity / 15.0       # max expected drone speed

	var obs = [
		1.0 if bikes_in_camera.size() > 0 else 0.0,  # bike visible flag
		closest_bike_pos.x,                            # bike position in drone-local space
		closest_bike_pos.y,
		closest_bike_pos.z,
		bike_speed,                                    # bike speed (normalized)
		bike_direction_local.x,                        # bike movement direction (drone-local x/z)
		bike_direction_local.y,
		local_velocity.x,                              # drone velocity in drone-local space
		local_velocity.y,
		local_velocity.z,
		cam_offset.x,                                  # bike offset in camera view
		cam_offset.y,
	]

	return {"obs": obs}

func get_reward() -> float:
	return reward

func get_action_space() -> Dictionary:
	return {
		"central_force" : {
			"size": 1,
			"action_type": "continuous",
		},
		"torque" : {
			"size": 1,
			"action_type": "continuous",
		},
		"direction" : {
			"size": 3,
			"action_type": "continuous",
		},
	}

func reset():
	super.reset()
	# Reset drone physics state
	drone.linear_velocity = Vector3.ZERO
	drone.angular_velocity = Vector3.ZERO
	_steps_without_bike = 0
	drone.target_bike = null
	drone.target_position = null
	drone.total_time_since_last_scan = 10.0
	# Load a new random track and reset the bike
	var world = drone.get_parent()
	if world.is_rl:
		world.reset_track_and_bike()
		# Position drone behind the new bike
		var bikes = shared.bike_lists[world.instance_id]
		if not bikes.is_empty():
			drone.target_bike = bikes[0]
			drone.set_position(_get_desired_pos())
			var bike_forward = -drone.target_bike.global_transform.basis.z
			bike_forward.y = 0
			drone.look_at(drone.global_position + bike_forward.normalized(), Vector3.UP)
		else:
			drone.set_position(Vector3(0, drone.height_offset + 2.0, 0))
	else:
		drone.set_position(Vector3(0, drone.height_offset + 2.0, 0))

func set_action(action) -> void:
	# central_force: map [-1,1] -> [0,1]
	var normalized_central_force = (action["central_force"][0] + 1) / 2
	var central_force = normalized_central_force * drone.max_force
	# torque: full [-1,1] range so drone can rotate both ways
	var torque = action["torque"][0] * drone.max_torque
	# direction: interpreted as drone-local space, converted to global in drone_body
	var direction = Vector3(
		action["direction"][0],
		action["direction"][1],
		action["direction"][2]
	)

	drone.apply_central_force(global_transform.basis * direction * central_force)
	drone.apply_torque(global_transform.basis.y * torque)
