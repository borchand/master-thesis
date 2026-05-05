extends Node3D

const bike = preload("res://Scenes/Bike/Bike.tscn")
const drone = preload("res://Scenes/Drone/Drone.tscn")

@export var is_training: bool = false
@export var is_rl: bool = false

# Bike count range used when is_rl = true. Fixed count is used otherwise.
@export var min_bike_count: int = 2
@export var max_bike_count: int = 8

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

var bike_count:int = 10
var drone_count:int = 10

func _ready():
	path_instance = $BikePath3d

	if not is_training:
		logging.add_info(bike_count, drone_count, path_instance.route_file_path, shared.drone_communication_size)
	instance_id = shared.register_instance()

	if is_rl and is_training:
		# Pre-build and cache all RL track curves before training begins,
		# so that each reset is a fast duplicate() rather than a slow add_point() loop.
		path_instance.call("preload_tracks", RL_TRACKS)
		randomize_track()
		bike_count = randi_range(min_bike_count, max_bike_count)

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
	drone_instance.is_training = is_training
	var drone_camera = drone_instance.get_node("Camera3D")
	shared.drone_camera_lists[instance_id].append(drone_camera)
	add_child(drone_instance)
	drone_list.append(drone_instance)

	var bike_index = (drone_list.size() - 1) % shared.bike_lists[instance_id].size()
	place_drone(drone_instance, bike_index)

func place_drone(drone_instance: Node3D, bike_index: int):
	var _bike = shared.bike_lists[instance_id][bike_index]
	var bike_forward = -_bike.global_transform.basis.z
	bike_forward.y = 0
	bike_forward = bike_forward.normalized()
	var desired_pos = _bike.global_position - bike_forward * drone_instance.behind_distance
	desired_pos.y = _bike.global_position.y + drone_instance.height_offset

	# Spread only drones that share the same assigned bike so the lateral
	# offset stays small enough for the bike to remain in the camera frame.
	var drone_index = drone_list.find(drone_instance)
	var bike_count_cur = shared.bike_lists[instance_id].size()
	@warning_ignore("integer_division")   
	var same_bike_rank: int = drone_index / bike_count_cur
	@warning_ignore("integer_division")   
	var same_bike_total: int = int(drone_count + bike_count_cur - 1 - bike_index) / bike_count_cur
	var bike_right = bike_forward.cross(Vector3.UP).normalized()
	var spacing = drone_instance.avoid_radius + 1.0
	var offset = (same_bike_rank - (same_bike_total - 1) * 0.5) * spacing
	desired_pos += bike_right * offset

	drone_instance.set_position(desired_pos)

func add_bike():
	# create bike instance
	var bike_instance = bike.instantiate()
	bike_instance.connect("freeing_bike", bike_freed)
	bike_instance.is_rl = is_rl
	bike_instance.is_training = is_training

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

func reset_track_and_bike_and_drone() -> void:
	for _bike in shared.bike_lists[instance_id].duplicate():
		_bike.safe_queue_free()

	# time randomize_track 
	var time = Time.get_ticks_msec()
	
	randomize_track()
	print("Track randomization took ", Time.get_ticks_msec() - time, " ms")
	bike_count = randi_range(min_bike_count, max_bike_count)

	for i in bike_count:
		add_bike()

	for i in range(drone_list.size()):
		var bike_index = i % shared.bike_lists[instance_id].size()
		place_drone(drone_list[i], bike_index)

func respawn_drone(drone_instance: Node3D) -> void:
	if shared.bike_lists[instance_id].is_empty():
		return
	var bike_index = randi() % shared.bike_lists[instance_id].size()
	place_drone(drone_instance, bike_index)

func randomize_track() -> void:
	var track = RL_TRACKS[randi() % RL_TRACKS.size()]
	path_instance.rl_route_file_path = track
	path_instance.reload_for_rl()
