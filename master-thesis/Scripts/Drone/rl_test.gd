extends AIController3D


# Stores the action sampled for the agent's policy, running in python
var central_force : float = 0.0
var torque : float = 0.0
var direction : Vector3 = Vector3.ZERO

@onready var max_central_force = get_parent().max_force
@onready var max_torque = get_parent().max_torque

func get_obs() -> Dictionary:
	var bikes_in_camera = _player.get_node("Camera_detection").bike_set
	var camera = _player.get_camera_node()

	var closest_bike_pos = Vector3.ZERO
	var closest_distance = INF
	var bike_speed = 0.0
	var bike_direction_local = Vector2.ZERO  # bike movement direction in drone-local x/z
	var cam_offset = Vector2.ZERO            # bike position in camera space, normalized

	for bike in bikes_in_camera:
		var pos = _player.to_local(bikes_in_camera[bike].global_position)
		var distance = pos.length()
		if distance < closest_distance:
			closest_distance = distance
			closest_bike_pos = pos
			bike_speed = bikes_in_camera[bike].get_parent().speed

			# Bike movement direction in drone-local space (x/z only — y is always ~0 on flat ground)
			var world_dir = bikes_in_camera[bike].get_parent().direction
			var local_dir = _player.global_transform.basis.inverse() * world_dir
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
	var local_velocity = _player.global_transform.basis.inverse() * _player.linear_velocity

	# Normalize
	closest_bike_pos = closest_bike_pos / 50.0   # max expected distance
	bike_speed = bike_speed / 30.0               # max bike speed ~30 m/s
	local_velocity = local_velocity / 10.0       # max expected drone speed

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

func set_action(action) -> void:
	# central_force: map [-1,1] -> [0,1]
	var normalized_central_force = (action["central_force"][0] + 1) / 2
	central_force = normalized_central_force * max_central_force
	# torque: full [-1,1] range so drone can rotate both ways
	torque = action["torque"][0] * max_torque
	# direction: interpreted as drone-local space, converted to global in drone_body
	direction = Vector3(
		action["direction"][0],
		action["direction"][1],
		action["direction"][2]
	).normalized()
