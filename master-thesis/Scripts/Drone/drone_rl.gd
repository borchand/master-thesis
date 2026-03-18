extends AIController3D

@onready var drone: RigidBody3D = $".."

func _physics_process(_delta):
	if needs_reset:
		reset()
		return

	var world = drone.get_parent()
	if shared.bike_lists[world.instance_id].is_empty():
		done = true
		needs_reset = true
		return

	if drone.target_bike == null:
		reward -= 0.01
		return

	var desired_pos = _get_desired_pos()
	var dist = drone.global_position.distance_to(desired_pos)
	reward += clamp(1.0 - dist / drone.max_distance, -1.0, 1.0) * 0.1

func _get_desired_pos() -> Vector3:
	var bike_forward = -drone.target_bike.global_transform.basis.z
	bike_forward.y = 0
	bike_forward = bike_forward.normalized()
	var pos = drone.target_bike.global_position - bike_forward * drone.behind_distance
	pos.y = drone.target_bike.global_position.y + drone.height_offset
	return pos

func get_obs() -> Dictionary:
	var obs: Array[float] = []

	if drone.target_bike == null:
		obs.resize(14)
		obs.fill(0.0)
		return {"obs": obs}

	var desired_pos = _get_desired_pos()
	var to_desired = desired_pos - drone.global_position

	var drone_forward = -drone.global_transform.basis.z
	drone_forward.y = 0
	drone_forward = drone_forward.normalized()

	var bike_forward = -drone.target_bike.global_transform.basis.z
	bike_forward.y = 0
	bike_forward = bike_forward.normalized()

	var horiz_dist = Vector2(to_desired.x, to_desired.z).length()
	var y_error = to_desired.y

	# Relative vector to desired position (normalised)
	obs.append(to_desired.x / 20.0)
	obs.append(to_desired.y / 20.0)
	obs.append(to_desired.z / 20.0)
	# Drone linear velocity (normalised)
	obs.append(drone.linear_velocity.x / 10.0)
	obs.append(drone.linear_velocity.y / 10.0)
	obs.append(drone.linear_velocity.z / 10.0)
	# Drone forward direction
	obs.append(drone_forward.x)
	obs.append(drone_forward.y)
	obs.append(drone_forward.z)
	# Target bike forward direction
	obs.append(bike_forward.x)
	obs.append(bike_forward.y)
	obs.append(bike_forward.z)
	# Horizontal distance to desired (clamped 0–1)
	obs.append(clamp(horiz_dist / 20.0, 0.0, 1.0))
	# Y error (clamped -1–1)
	obs.append(clamp(y_error / 10.0, -1.0, 1.0))

	return {"obs": obs}

func get_reward() -> float:
	return reward

func get_action_space() -> Dictionary:
	return {
		"thrust": {
			"size": 3,
			"action_type": "continuous",
		},
		"torque": {
			"size": 1,
			"action_type": "continuous",
		},
	}

func reset():
	print("Resetting drone RL environment for instance ", drone.get_parent().instance_id)
	super.reset()
	# Reset drone physics state
	drone.linear_velocity = Vector3.ZERO
	drone.angular_velocity = Vector3.ZERO
	drone.target_bike = null
	drone.target_position = null
	drone.total_time_since_last_scan = 10.0
	# Load a new random track and reset the bike
	var world = drone.get_parent()
	if world.is_rl:
		# Only reset the track/bike if no bike exists yet (prevents double-reset
		# when sync.gd re-sets needs_reset after an internal reset already ran)
		var bikes = shared.bike_lists[world.instance_id]
		if bikes.is_empty():
			world.reset_track_and_bike()
			bikes = shared.bike_lists[world.instance_id]
		# Position drone behind the bike
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
	var thrust = action["thrust"]
	var torque_val = action["torque"][0]

	drone.apply_central_force(
		Vector3(thrust[0], thrust[1], thrust[2]) * drone.max_force
	)
	drone.apply_torque(
		drone.global_transform.basis.y * clamp(torque_val, -1.0, 1.0) * drone.max_torque
	)
