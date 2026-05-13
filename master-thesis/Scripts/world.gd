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

var bike_count:int = 50
var drone_count:int = 30

# Spacing used only at spawn time. Smaller than avoid_radius so large fleets
# fit within the camera frustum; boids separation takes over once running.
@export var drone_spawn_spacing: float = 1.5
@export var place_drone_along_road = false

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
		add_drone(false)
	
	if place_drone_along_road:
		place_all_drones()
	else:
		for i in range(drone_list.size()):
			var bike_index = i % shared.bike_lists[instance_id].size()
			place_drone(drone_list[i], bike_index)

	$Menu/OtherContainer/FollowDroneInPos.max_value = drone_count - 1
	$Menu/OtherContainer/FollowBikeInPos.max_value = bike_count - 1

func add_drone(auto_place: bool = true):
	var drone_instance = drone.instantiate()
	drone_instance.is_rl = is_rl
	drone_instance.is_training = is_training
	var drone_camera = drone_instance.get_node("Camera3D")
	shared.drone_camera_lists[instance_id].append(drone_camera)
	add_child(drone_instance)
	drone_list.append(drone_instance)

	if auto_place:
		var bike_index = (drone_list.size() - 1) % shared.bike_lists[instance_id].size()
		place_drone(drone_instance, bike_index)

func place_all_drones():
	var total = drone_list.size()
	var route_drone_count = int(floor(float(total) / 3.0))
	var normal_drone_count = total - route_drone_count

	for i in range(total):
		if i >= normal_drone_count:
			var route_index = i - normal_drone_count
			place_drone_along_middle_section(drone_list[i], route_index, route_drone_count)
		else:
			var bike_index = i % shared.bike_lists[instance_id].size()
			place_drone(drone_list[i], bike_index)

func place_drone(drone_instance: Node3D, bike_index: int):
	var _bike = shared.bike_lists[instance_id][bike_index]
	var bike_forward = -_bike.global_transform.basis.z
	bike_forward.y = 0
	bike_forward = bike_forward.normalized()
	var desired_pos = _bike.global_position - bike_forward * drone_instance.behind_distance
	desired_pos.y = _bike.global_position.y + drone_instance.height_offset

	var drone_index = drone_list.find(drone_instance)
	var total = drone_list.size()
	var spacing = drone_spawn_spacing
	var cols = max(1, ceili(sqrt(float(total))))
	var row = drone_index / cols
	var col = drone_index % cols
	var cols_in_row = min(cols, total - row * cols)
	var bike_right = bike_forward.cross(Vector3.UP).normalized()
	desired_pos += bike_right * (col - (cols_in_row - 1) * 0.5) * spacing
	desired_pos -= bike_forward * row * spacing

	drone_instance.set_position(desired_pos)

func place_drone_along_middle_section(drone_instance, route_index, route_drone_count):
	var curve := path_instance.curve
	var length := curve.get_baked_length()

	var start_offset := length / 4.0
	var end_offset := length * 3.0 / 4.0

	var t := 0.5
	if route_drone_count > 1:
		t = float(route_index) / float(route_drone_count - 1)

	var offset = lerp(start_offset, end_offset, t)

	var local_road_pos := curve.sample_baked(offset)
	var road_world_pos := path_instance.to_global(local_road_pos)

	var ahead_offset = min(offset + 5.0, length)
	var ahead_local_pos := curve.sample_baked(ahead_offset)
	var ahead_world_pos := path_instance.to_global(ahead_local_pos)

	var road_direction := ahead_world_pos - road_world_pos
	road_direction.y = 0
	road_direction = road_direction.normalized()

	var side_direction := Vector3(-road_direction.z, 0, road_direction.x).normalized()

	var drone_world_pos := road_world_pos + side_direction * 25
	drone_world_pos.y += drone_instance.height_offset

	drone_instance.global_position = drone_world_pos

	var look_target := road_world_pos
	look_target.y = drone_world_pos.y

	drone_instance.look_at(look_target, Vector3.UP)

	drone_instance.idle_until_needed = true
	drone_instance.has_activated = false
	
func add_bike():
	# create bike instance
	var watt_spread = 9
	var bike_instance = bike.instantiate()
	bike_instance.connect("freeing_bike", bike_freed)
	bike_instance.is_rl = is_rl
	bike_instance.is_training = is_training

	# Add variation in bike preformance
	var randowm_watt_variant =  watt_spread*rng.randi_range(-1,2)

	bike_instance.set_watts(373+randowm_watt_variant,573+randowm_watt_variant)

	# add bike to scene
	path_instance.add_child(bike_instance)
	bike_instance.progress = (randowm_watt_variant/2)+rng.randf_range(0.0,2.0)

	shared.bike_lists[instance_id].append(bike_instance)

func bike_freed(freed_bike: Node3D):
	# remove bike camera from list when bike is freed
	shared.bike_lists[instance_id].erase(freed_bike)
	if shared.bike_lists[instance_id].is_empty():
		get_tree().quit()

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

	#for i in range(drone_list.size()):
		#var bike_index = i % shared.bike_lists[instance_id].size()
		#place_drone(drone_list[i], bike_index)
	place_all_drones()

func respawn_drone(drone_instance: Node3D) -> void:
	if shared.bike_lists[instance_id].is_empty():
		return
	var bike_index = randi() % shared.bike_lists[instance_id].size()
	place_drone(drone_instance, bike_index)

func randomize_track() -> void:
	var track = RL_TRACKS[randi() % RL_TRACKS.size()]
	path_instance.rl_route_file_path = track
	path_instance.reload_for_rl()
