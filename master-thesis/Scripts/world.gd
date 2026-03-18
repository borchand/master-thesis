extends Node3D

const bike = preload("res://Scenes/Bike/Bike.tscn")
const drone = preload("res://Scenes/Drone/Drone.tscn")

@export var is_training: bool = false
@export var is_rl: bool = false

const RL_TRACKS: Array[String] = [
	"res://stages/rl-test-track.json",
	"res://stages/rl-track-circle.json",
	"res://stages/rl-track-circuit.json",
	"res://stages/rl-track-hilly.json",
]

@onready var path_instance : Path3D
var rng = RandomNumberGenerator.new()
var instance_id: int = -1

const bike_count = 1

func _ready():
	path_instance = $BikePath3d
	instance_id = shared.register_instance()

	if is_rl:
		randomize_track()

	if is_training:
		$Menu/ToggleContainer.visible = false
		$Menu/OtherContainer.visible = false
		$Menu.offset_bottom = 60.0
		
	for i in range(bike_count):
		add_bike()
		add_drone(Vector3(-i, 5, 2))

	$Menu/OtherContainer/FollowDroneInPos.max_value = bike_count - 1
	$Menu/OtherContainer/FollowBikeInPos.max_value = bike_count - 1

func add_drone(start_position: Vector3):
	var drone_instance = drone.instantiate()
	drone_instance.set_position(start_position)
	drone_instance.is_rl = is_rl
	var drone_camera = drone_instance.get_node("Camera3D")
	shared.drone_camera_lists[instance_id].append(drone_camera)
	add_child(drone_instance)

func add_bike():
	# create bike instance
	var bike_instance = bike.instantiate()
	bike_instance.connect("freeing_bike", bike_freed)
	bike_instance.is_rl = is_rl

	# Add variation in bike preformance
	var rn = rng.randfn(23, 1.15)
	var rnW = rng.randfn(2, 0.2)

	#if we want more grouped bikes.
	#if (rn>value1 and rn<valu2) or (rn>value3 and rn<value4):
		#rn = rng.randfn(23, 1.15)

	bike_instance.setRegen(rn)
	bike_instance.set_watts(353+rnW,533+rnW)

	# add bike to scene
	path_instance.add_child(bike_instance)

	shared.bike_lists[instance_id].append(bike_instance)

func bike_freed(freed_bike: Node3D):
	# remove bike camera from list when bike is freed
	shared.bike_lists[instance_id].erase(freed_bike)

func reset_track_and_bike() -> void:
	randomize_track()

	for i in bike_count:
		add_bike()

func randomize_track() -> void:
	var track = RL_TRACKS[randi() % RL_TRACKS.size()]
	path_instance.rl_route_file_path = track
	path_instance.reload_for_rl()
