extends Node3D

const bike = preload("res://Scenes/Bike/Bike.tscn")
const drone = preload("res://Scenes/Drone/Drone.tscn")

@onready var path_instance : Path3D
var rng = RandomNumberGenerator.new()

var min_rng= 24
var max_rng= 0

const bike_count = 180

func _ready():
	path_instance = $BikePath3d

	# load bike scene
	for i in range(bike_count):
		add_bike()
		#add_drone(Vector3(-i, 5, 2))
		
	print("Min: ", min_rng, " Max: ", max_rng)
	
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
	var rnW = rng.randi_range(0,3)#rng.randi_range(-8,18)#rng.randfn(12, 14)
	rnW = -9+9*rnW 
	
	if rnW < min_rng:
		min_rng = rnW
	if rnW > max_rng:
		max_rng = rnW
	#rnW = min(1000, max(-1000, rnW))

	bike_instance.setRegen(rn)
	bike_instance.set_watts(373+rnW,573+rnW)

	# add bike to scene
	path_instance.add_child(bike_instance)
	bike_instance.progress = 20+rnW+rng.randf_range(0.0,1.0)

	shared.bikes.append(bike_instance)

func bike_freed(freed_bike: Node3D):
	# remove bike camera from list when bike is freed
	shared.bikes.erase(freed_bike)
