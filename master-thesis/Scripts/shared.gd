extends Node

var paused = false
var free_roam = false
var follow_drone = false
var drone_controlled = false
var follow_bike = false

var follow_bike_in_pos : int = 0

var bike_lists: Array[Array] = []
var drone_camera_lists: Array[Array] = []

func register_instance() -> int:
	bike_lists.append([])
	drone_camera_lists.append([])
	return bike_lists.size() - 1

var followed_drone_index = 0

func get_progress_ratio_of_bike_in_pos(pos: int, instance_id: int) -> float:
	var bikes = bike_lists[instance_id]
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

func get_camera_of_bike_in_pos(pos: int, instance_id: int) -> Camera3D:
	var bikes = bike_lists[instance_id]
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
