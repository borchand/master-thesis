extends AIController3D


# Stores the action sampled for the agent's policy, running in python
var central_force : float = 0.0
var torque : float = 0.0
var direction : Vector3 = Vector3.ZERO

@onready var max_central_force = get_parent().max_force
@onready var max_torque = get_parent().max_torque

func get_obs() -> Dictionary:
	var bikes_in_camera = _player.get_node("Camera_detection").bike_set

	var closest_bike_pos = Vector3.ZERO
	var closest_distance = INF
	for bike in bikes_in_camera:
		var pos = to_local(bikes_in_camera[bike].global_position)
		var distance = pos.length()
		if distance < closest_distance:
			closest_distance = distance
			closest_bike_pos = pos

	# get drone data
	var local_velocity = get_parent().global_transform.basis.inverse() * get_parent().linear_velocity

	var obs = [
		1.0 if bikes_in_camera.size() > 0 else 0.0,
		closest_bike_pos.x,
		closest_bike_pos.y,
		closest_bike_pos.z,
		local_velocity.x,
		local_velocity.y,
		local_velocity.z,
		sin(get_parent().rotation.y), # Yaw
		cos(get_parent().rotation.y), # yaw
		get_parent().rotation.x, # Pitch
		get_parent().rotation.z  # Roll
	]
	return {"obs":obs}

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
	var normalized_central_force = (action["central_force"][0] + 1) / 2
	var normalized_torque = (action["torque"][0] + 1) / 2
	central_force = normalized_central_force * max_central_force
	torque = normalized_torque * max_torque
	
	direction = Vector3(
		action["direction"][0],
		action["direction"][1],
		action["direction"][2]
	)
