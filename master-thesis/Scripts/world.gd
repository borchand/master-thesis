extends Node3D

const bike = preload("res://Scenes/Bike/Bike.tscn")
const drone = preload("res://Scenes/Drone/Drone.tscn")

@export var is_training: bool = false
@export var is_rl: bool = false

@export var min_bike_count: int = 1
@export var max_bike_count: int = 20
@export var drone_counts_per_instance: Array[int] = [1, 2, 8, 15]

const RL_TRACKS: Array[String] = [
	"res://stages/rl-5k-straight-flat.json",
	"res://stages/rl-5k-straight-uphill.json",
	"res://stages/rl-5k-straight-downhill.json",
	"res://stages/rl-5k-rolling-hills.json",
	"res://stages/rl-5k-valley.json",
	"res://stages/rl-5k-mountain.json",
	"res://stages/rl-5k-left-arc.json",
	"res://stages/rl-5k-right-arc.json",
	"res://stages/rl-5k-s-curve.json",
	"res://stages/rl-5k-zigzag.json",
	"res://stages/rl-5k-left-arc-uphill.json",
	"res://stages/rl-5k-right-arc-downhill.json",
	"res://stages/rl-5k-s-curve-uphill.json",
	"res://stages/rl-5k-rolling-left-arc.json",
	"res://stages/rl-5k-hairpin.json",
	"res://stages/rl-5k-hairpin-uphill.json",
]

@onready var path_instance: Path3D

var rng = RandomNumberGenerator.new()
var instance_id: int = -1
var drone_list: Array = []

var bike_count: int = 180
var drone_count: int = 0

@export var drone_spawn_spacing: float = 1.5
@export var place_drone_along_road: bool = false

var cached_bikes: Array = []
var cached_drones: Array = []

var pr_sec_checks = 4
var timer_threashold = 1.0 / pr_sec_checks
var timer = 0
var bike_process_list: Array = []
var bike_index_dic: Dictionary = {}
var bike_neighborhoods: Array = []

var start_time := 0
var wall_start := 0
var sim_time := 0.0
var next_ratio_print_time := 30.0

var bike_restWatt := 400
var bike_sprintWatt := 600
var watt_spread := 9
var bike_cohesion := 0.8
var bike_seperation := 0.05
var bike_speedupchance := 5.0
var bike_speedDownChance := 4.5


func _ready():
	start_time = Time.get_ticks_msec()
	wall_start = Time.get_ticks_msec()

	path_instance = $BikePath3d
	instance_id = shared.register_instance()

	if is_rl and is_training:
		path_instance.call("preload_tracks", RL_TRACKS)
		randomize_track()
		bike_count = randi_range(min_bike_count, max_bike_count)

		if instance_id < drone_counts_per_instance.size():
			drone_count = drone_counts_per_instance[instance_id]

	if not is_training:
		logging.add_info(
			bike_count,
			drone_count,
			path_instance.route_file_path,
			shared.drone_communication_size
		)

	if is_training:
		$Menu/ToggleContainer.visible = false
		$Menu/OtherContainer.visible = false
		$Menu.offset_bottom = 60.0
	
	set_stage_variables()
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

	update_cached_world_data()
	update_bike_order()


func _physics_process(delta: float) -> void:
	sim_time += delta

	if sim_time >= next_ratio_print_time:
		next_ratio_print_time += 30.0
		var wall = (Time.get_ticks_msec() - wall_start) / 1000.0

		print(
			"sim_time=", sim_time,
			" wall_time=", wall,
			" ratio=", sim_time / max(wall, 0.001),
			" drones=", drone_list.size()
		)
		
	update_cached_world_data()
	
	timer += delta
	if timer >= timer_threashold:
		timer = timer-timer_threashold
		update_bike_order()
		

func update_cached_world_data():
	cached_bikes.clear()
	cached_drones.clear()

	for bike_instance in shared.bike_lists[instance_id]:
		var bike_body = bike_instance.bikebody
		var pos: Vector3 = bike_body.global_position

		var forward: Vector3 = -bike_body.global_transform.basis.z
		forward.y = 0.0
		forward = forward.normalized()

		cached_bikes.append({
			"position": pos,
			"velocity": forward * bike_instance.speed,
			"id": bike_body.bike_id
		})

	for d in drone_list:
		cached_drones.append({
			"id": d.id,
			"position": d.global_position
		})

func set_stage_variables():
	match path_instance.route_file_path:
		"res://stages/stage-1-route.json":
			bike_restWatt=423; bike_sprintWatt = 623; watt_spread = 9
			bike_cohesion = 1.2; bike_seperation = 0.01; bike_speedupchance = 4.0; bike_speedDownChance = 4.5
		"res://stages/stage-8-route.json":
			bike_restWatt=358; bike_sprintWatt = 558; watt_spread = 9
			bike_cohesion = 0.7; bike_seperation = 0.1; bike_speedupchance = 40.0; bike_speedDownChance = 4.5
		"res://stages/stage-10-route.json":
			bike_restWatt=360; bike_sprintWatt = 460; watt_spread = 9
			bike_cohesion = 1.4; bike_seperation = 0.01; bike_speedupchance = 1.0; bike_speedDownChance = 4.5
		"res://stages/stage-19-route.json":
			bike_restWatt=400; bike_sprintWatt = 600; watt_spread = 9
			bike_cohesion = 0.8; bike_seperation = 0.05; bike_speedupchance = 5.0; bike_speedDownChance = 4.5

func erase_bike(node):
	bike_process_list.erase(node)
	bike_neighborhoods.resize(bike_process_list.size())
	
	for i in bike_process_list.size():
		bike_process_list[i].race_index = i

func update_bike_order():
	bike_process_list.sort_custom(func(a, b): return a.progress > b.progress)
	var n = bike_process_list.size()
	
	# Cache all progress values and rebuild index dict in one pass
	var prog := PackedFloat32Array()
	prog.resize(n)
	for i in n:
		var bike = bike_process_list[i]
		prog[i] = bike.get_progress()
		bike.race_index = i
	
	# Prefix sums for O(1) range-sum queries
	var prefix:= PackedFloat64Array()
	prefix.resize(n + 1)
	prefix[0] = 0.0
	for i in n:
		prefix[i + 1] = prefix[i] + prog[i]
	# Sliding window: left is the furthest-ahead bike still within 30m
	# List is descending, so prog[0] is highest. For bike at index i,
	# "ahead" bikes are at lower indices.
	bike_neighborhoods.resize(n)
	var left = 0
	for i in n:
		# Advance left past any bike now more than 30m ahead
		while left < i and prog[left] - prog[i] >= 30.0:
			left += 1
		
		# Window [left, i-1] contains all bikes ahead within 30m
		var n_bikes = i - left
		var avg_dist = 0.0
		if n_bikes > 0:
			var range_sum = (prefix[i] - prefix[left]) - n_bikes * prog[i]
			avg_dist = range_sum / n_bikes
			
		var dist_1st = null
		var dist_3rd = null
		var dist_behind = null
		
		if i >= 1 and (i - 1) >= left:
			dist_1st = prog[i - 1] - prog[i]
		if i >= 3 and (i - 3) >= left:
			dist_3rd = prog[i - 3] - prog[i]
		if i + 1 < n and prog[i] - prog[i + 1] < 4.1:
			dist_behind = prog[i] - prog[i + 1]

		bike_neighborhoods[i] = [n_bikes, avg_dist, dist_1st, dist_3rd, dist_behind]

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

	var bike_forward: Vector3 = -_bike.global_transform.basis.z
	bike_forward.y = 0.0
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
	road_direction.y = 0.0
	road_direction = road_direction.normalized()

	var side_direction := Vector3(-road_direction.z, 0, road_direction.x).normalized()

	var drone_world_pos := road_world_pos + side_direction * 25.0
	drone_world_pos.y += drone_instance.height_offset

	drone_instance.global_position = drone_world_pos

	var look_target := road_world_pos
	look_target.y = drone_world_pos.y

	drone_instance.look_at(look_target, Vector3.UP)

	drone_instance.idle_until_needed = true
	drone_instance.has_activated = false


func add_bike():
	var bike_instance = bike.instantiate()

	bike_instance.connect("freeing_bike", bike_freed)
	bike_instance.is_rl = is_rl
	bike_instance.is_training = is_training

	var random_watt_variant = watt_spread * rng.randi_range(-1, 2)

	bike_instance.set_variables(
		bike_restWatt + random_watt_variant,
		bike_sprintWatt + random_watt_variant,
		bike_cohesion,
		bike_seperation,
		bike_speedupchance,
		bike_speedDownChance
	)
	
	path_instance.add_child(bike_instance)
	bike_instance.progress = (random_watt_variant / 2.0) + rng.randf_range(0.0, 2.0)
	bike_process_list.append(bike_instance)
	shared.bike_lists[instance_id].append(bike_instance)


func bike_freed(freed_bike: Node3D):
	shared.bike_lists[instance_id].erase(freed_bike)

	if shared.bike_lists[instance_id].is_empty() and not is_training:
		var end_time = Time.get_ticks_msec()
		var runtime_sec = (end_time - start_time) / 1000.0
		print("Run time: ", runtime_sec, " seconds")
		get_tree().quit()


func reset_track_and_bike_and_drone() -> void:
	for _bike in shared.bike_lists[instance_id].duplicate():
		_bike.safe_queue_free()

	var time = Time.get_ticks_msec()

	randomize_track()
	print("Track randomization took ", Time.get_ticks_msec() - time, " ms")

	bike_count = randi_range(min_bike_count, max_bike_count)

	for i in bike_count:
		add_bike()

	place_all_drones()
	update_cached_world_data()
	update_bike_order()


func respawn_drone(drone_instance: Node3D) -> void:
	if shared.bike_lists[instance_id].is_empty():
		return

	var bike_index = randi() % shared.bike_lists[instance_id].size()
	place_drone(drone_instance, bike_index)


func randomize_track() -> void:
	var track = RL_TRACKS[randi() % RL_TRACKS.size()]
	path_instance.rl_route_file_path = track
	path_instance.reload_for_rl()
