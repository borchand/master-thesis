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
	"res://stages/rl-track-straight.json",
	"res://stages/rl-track-left-turn.json",
	"res://stages/stage-1-route.json",
	"res://stages/stage-6-route.json",
	"res://stages/stage-10-route.json",
	"res://stages/stage-12-route.json",
	"res://stages/stage-18-route.json",

]

@onready var path_instance : Path3D
var rng = RandomNumberGenerator.new()
var instance_id: int = -1
var drone_list: Array = []

const bike_count = 20
const drone_count = 5

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
	for i in range(drone_count):
		add_drone()

	$Menu/OtherContainer/FollowDroneInPos.max_value = drone_count - 1
	$Menu/OtherContainer/FollowBikeInPos.max_value = bike_count - 1

func add_drone():
	var drone_instance = drone.instantiate()
	drone_instance.is_rl = is_rl
	var drone_camera = drone_instance.get_node("Camera3D")
	shared.drone_camera_lists[instance_id].append(drone_camera)
	add_child(drone_instance)
	drone_list.append(drone_instance)

	var bike_index = (drone_list.size() - 1) % shared.bike_lists[instance_id].size()
	place_drone(drone_instance, bike_index)

func place_drone(drone_instance: Node3D, bike_index: int):
	var bike = shared.bike_lists[instance_id][bike_index]
	var bike_forward = -bike.global_transform.basis.z
	bike_forward.y = 0
	bike_forward = bike_forward.normalized()
	var desired_pos = bike.global_position - bike_forward * drone_instance.behind_distance
	desired_pos.y = bike.global_position.y + drone_instance.height_offset

	# Spread drones laterally so they don't start on top of each other.
	var drone_index = drone_list.find(drone_instance)
	var bike_right = bike_forward.cross(Vector3.UP).normalized()
	var spacing = drone_instance.avoid_radius + 1.0
	var offset = (drone_index - (drone_count - 1) * 0.5) * spacing
	desired_pos += bike_right * offset

	drone_instance.set_position(desired_pos)
	drone_instance.look_at(desired_pos + bike_forward, Vector3.UP)

func add_bike():
	# create bike instance
	var bike_instance = bike.instantiate()
	bike_instance.connect("freeing_bike", bike_freed)
	bike_instance.is_rl = is_rl

	# Add variation in bike preformance
	var rn = rng.randfn(23, 1.15)
	var rnW = rng.randfn(6, 3)

	#if we want more grouped bikes.
	#if (rn>value1 and rn<valu2) or (rn>value3 and rn<value4):
		#rn = rng.randfn(23, 1.15)

	bike_instance.setRegen(rn)
	bike_instance.set_watts(393+rnW,592+rnW)

	# add bike to scene
	path_instance.add_child(bike_instance)

	shared.bike_lists[instance_id].append(bike_instance)

func bike_freed(freed_bike: Node3D):
	# remove bike camera from list when bike is freed
	shared.bike_lists[instance_id].erase(freed_bike)

func reset_track_and_bike() -> void:
	for bike in shared.bike_lists[instance_id].duplicate():
		bike.safe_queue_free()
	randomize_track()

	for i in bike_count:
		add_bike()

	for i in range(drone_list.size()):
		var bike_index = i % shared.bike_lists[instance_id].size()
		place_drone(drone_list[i], bike_index)

func randomize_track() -> void:
	var track = RL_TRACKS[randi() % RL_TRACKS.size()]
	path_instance.rl_route_file_path = track
	path_instance.reload_for_rl()
