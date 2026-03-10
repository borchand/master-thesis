extends Panel

@onready var label = $Label


func _process(_delta):
	visible = shared.follow_drone
	if not visible or shared.drone_cameras.is_empty():
		return

	var drone = shared.drone_cameras[shared.followed_drone_index].get_parent()
	var ai = drone.get_node("AIController3D")
	var cam_det = drone.get_node("Camera_detection")

	var pos = drone.global_position
	var closest_dist = INF
	for bike in shared.bikes:
		var d = drone.global_position.distance_to(bike.global_position)
		if d < closest_dist:
			closest_dist = d
	var dist_str = "%.2f m" % closest_dist if closest_dist < INF else "N/A"

	label.text = (
		"Speed:         %.2f m/s\n"
		+ "Torque:        %.3f\n"
		+ "Direction:     (%.2f, %.2f, %.2f)\n"
		+ "Position:      (%.1f, %.1f, %.1f)\n"
		+ "Dist to bike:  %s\n"
		+ "Bikes visible: %d\n"
		+ "No-bike steps: %d / %d\n"
		+ "Episode:       %d\n"
		+ "Reward:        %.3f\n"
		+ "Acc. reward:   %.2f"
	) % [
		drone.linear_velocity.length(),
		ai.torque,
		ai.direction.x, ai.direction.y, ai.direction.z,
		pos.x, pos.y, pos.z,
		dist_str,
		cam_det.bike_set.size(),
		drone.steps_with_no_bike,
		drone.max_steps_with_no_bike,
		ai.episode,
		ai.reward,
		ai.accumulated_reward,
	]
