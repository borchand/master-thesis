extends Node3D

const bike = preload("res://Scenes/Bike/Bike.tscn")
const drone = preload("res://Scenes/Drone/Drone.tscn")

@onready var path_instance : Path3D
var rng = RandomNumberGenerator.new()

const bike_count = 1

func _ready():
	path_instance = $BikePath3d

	# load bike scene
	for i in range(bike_count):
		add_bike()
		add_drone(Vector3(0, 5, -2))
	
	$Menu/OtherContainer/FollowBikeInPos.max_value = bike_count - 1

func add_drone(start_position: Vector3):
	var drone_instance = drone.instantiate()
	drone_instance.set_position(start_position)
	var drone_camera = drone_instance.get_node("Camera3D")
	shared.drone_cameras.append(drone_camera)
	add_child(drone_instance)

func add_bike():
	# create bike instance
	var bike_instance = bike.instantiate()
	bike_instance.connect("freeing_bike", bike_freed)

	#Add variation in bike preformance
	var rn = rng.randfn(23, 1.15)

	#if we want more grouped bikes.
	#if (rn>value1 and rn<valu2) or (rn>value3 and rn<value4):
		#rn = rng.randfn(23, 1.15)

	bike_instance.setRegen(rn)

	# add bike to scene
	path_instance.add_child(bike_instance)

	shared.bikes.append(bike_instance)

func bike_freed(freed_bike: Node3D):
	# remove bike camera from list when bike is freed
	shared.bikes.erase(freed_bike)

func reset():
	for bike in shared.bikes:
		bike.queue_free()
	shared.bikes.clear()

	for i in range(bike_count):
		add_bike()
	
	$Menu/OtherContainer/FollowBikeInPos.max_value = bike_count - 1
