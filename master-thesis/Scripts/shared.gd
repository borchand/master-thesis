extends Node

var paused = false
var free_roam = false
var follow_drone = false
var drone_controlled = false
var follow_bike = false

var bikes : Array[Bike]
var follow_bike_in_pos : int = 0

var drone_cameras : Array[Camera3D]
var followed_drone_index = 0

func get_progress_ratio_of_bike_in_pos(pos: int) -> float:
	
	if bikes.is_empty():
		return 1.0

	var bike_progress = []
	
	for bike : Bike in bikes:
		bike_progress.append(bike.progress_ratio)
		
	# sort by progress
	bike_progress.sort_custom(func(a, b):
		return a > b
	)
	
	return bike_progress[pos]

func get_camera_of_bike_in_pos(pos: int) -> Camera3D:
	var bike_progress = []

	for bike : Bike in bikes:
		var dict = {
			bike.progress: bike.get_camera_node()
		}
		bike_progress.append(dict)

	# sort by progress
	bike_progress.sort_custom(func(a, b):
		return a.keys()[0] > b.keys()[0]
	)

	return bike_progress[pos].values()[0]

func total_visible_bikes() -> int:
	
	var count = 0
	for drone_camera in drone_cameras:
		count += drone_camera.get_parent().get_node("Camera_detection").bike_set.size()
	return count

func get_closest_bike_to_drone(drone_camera: Camera3D) -> Bike:
	var closest_bike : Bike = null
	var closest_distance = INF

	for bike : Bike in bikes:
		var distance = drone_camera.global_transform.origin.distance_to(bike.global_transform.origin)
		if distance < closest_distance:
			closest_distance = distance
			closest_bike = bike

	return closest_bike

func toggle_free_roam():
	free_roam = !free_roam
	if free_roam:
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func pause():
	paused = !paused
	get_tree().paused = paused

func toggle_drone():
	follow_bike = false
	follow_drone = !follow_drone

func toggle_bike():
	follow_drone = false
	drone_controlled = false
	follow_bike = !follow_bike
