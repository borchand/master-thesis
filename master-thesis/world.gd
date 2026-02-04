extends Node3D

const bike = preload("res://Scenes/Bike/Bike.tscn")
const drone = preload("res://Drone.tscn")

var path_instance : Path3D
var camera_instance : Camera3D
const bike_count = 100

func _ready():	
	path_instance = $BikePath3d
	camera_instance = $Camera3D
	# load bike scene
	for i in range(bike_count):
		add_bike()
	add_drone(Vector3(0, 1, -1))
  	
func add_drone(start_position: Vector3):
	var drone_instance = drone.instantiate()
	drone_instance.set_position(start_position)
	var drone_camera = drone_instance.get_node("Camera3D")
	camera_instance.drone_cameras.append(drone_camera)
	add_child(drone_instance)
	
func add_bike():
	# create bike instance
	var bike_instance = bike.instantiate()
	bike_instance.connect("freeing_bike", bike_freed)

	# get bike camera and add to list
	var bike_camera = bike_instance.get_camera_node()
	camera_instance.bike_cameras.append(bike_camera)
	
	# add bike to scene
	path_instance.add_child(bike_instance)

func bike_freed(freed_bike: Node3D):
	# remove bike camera from list when bike is freed
	var bike_camera = freed_bike.get_camera_node()
	camera_instance.bike_cameras.erase(bike_camera)
