extends RigidBody3D
class_name Drone

static var _next_id: int = 1
var id: int

enum Version { Boids, BoidsRandomTargets, BoidsDynamicTargets, BoidsPriorityAttractionFields }

var is_rl: bool = false

@onready var drone_detector: DroneDetection = $"Camera_detection"
@onready var drone_sensor: DroneCommunication = $"Drone_communication"

@onready var sensor_readings_drones = []
@onready var sensor_readings_bikes =[]

@onready var target_position = null
@onready var target_speed = null
@onready var target_bike = null

@export var behind_distance := 4.0
@export var max_torque := 2.0
@export var yaw_gain := 2.2
@export var torque_zone := 0.05
@export var min_distance := 3.5
@export var max_distance := 4.5
@export var catchup_gain := 3.5
@export var max_catchup_speed := 14.0
@export var max_force := 18.0
@export var brake_force := 40.0

#For collission avoidance
@export var avoid_strength := 8.0
@export var max_avoid_speed := 10.0

#Boids tuneable parameters
@export var y_gain := 20.0
@export var y_damp := 30.0
@export var max_up_force := 40.0
@export var height_offset := 5.0
@export var avoid_radius := 3.0
@export var avoidfactor = 3
@export var centeringfactor = 1.5
@export var matchingfactor = 0.4

@export var version: Version = Version.Boids
@export var random_selection_rate := 0.2
var keep_selection_for_n_frames = 100

var sensor_selection_timer = 0.0
var _random_target_bikes: Array = []

# BoidsPriorityAttractionFields parameters
# Bikes closer than this (metres) are merged into the same cluster
@export var cluster_distance_threshold := 5.0
# Distance falloff exponent for attraction: higher = drone commits to nearest cluster sooner
@export var attraction_falloff := 2.0
# How many frames to keep a cluster assignment before re-evaluating
@export var cluster_reassign_interval := 120

var _cluster_assign_timer: int = 0
var _last_cluster_count: int = 0
var _cached_cluster_centroid: Vector3 = Vector3.INF


@export var debug_draw: bool = true
@export var debug_line_width: float = 0.1

var _debug_bike_lines: Array[MeshInstance3D] = []
var _debug_cluster_dots: Array[MeshInstance3D] = []
var _debug_cluster_target_line: MeshInstance3D = null

func _ready():
	id = _next_id
	_next_id += 1

func _physics_process(_delta):
	if is_rl:
		return
	
	boids()

func set_tunable_parameters(params: Dictionary):
	avoid_radius = params["avoid_radius"]
	avoid_strength = params["avoid_strength"]
	max_avoid_speed = params["max_avoid_speed"]
	avoidfactor = params["avoid_factor"]
	centeringfactor = params["centering_factor"]
	matchingfactor = params["matching_factor"]

func boids():
	read_sensor(drone_sensor.drone_set, drone_sensor.bike_set)

	var alignment_vector: Vector3
	var cohesion_vector: Vector3

	if version == Version.BoidsPriorityAttractionFields:
		var clusters = _cluster_bikes(sensor_readings_bikes)
		alignment_vector = _priority_alignment(clusters)
		cohesion_vector = _priority_cohesion(clusters)
		_draw_cluster_debug_lines(clusters)
	else:
		_draw_bike_debug_lines()
		alignment_vector = alignment()
		cohesion_vector = cohesion()

	var separation_vector = separation()

	var direction_vector = alignment_vector + cohesion_vector + separation_vector
	direction_vector.y = height_force()

	apply_central_force(clamp_vector(direction_vector, max_force))
	rotate_towards_direction(-alignment_vector)

func alignment():
	var alignment_vector = Vector3.ZERO
	var neighboring_bikes = 0
	
	for bike in sensor_readings_bikes:
		neighboring_bikes += 1
		alignment_vector.x += bike.velocity.x
		alignment_vector.z += bike.velocity.z
	
	if neighboring_bikes > 0:
		alignment_vector.x /= neighboring_bikes
		alignment_vector.z /= neighboring_bikes
	
	alignment_vector.x = (alignment_vector.x - linear_velocity.x) * matchingfactor
	alignment_vector.z = (alignment_vector.z - linear_velocity.z) * matchingfactor
	
	return alignment_vector
	
func cohesion():
	var cohesion_vector = Vector3.ZERO
	var neighboring_bikes = 0
	
	for bike in sensor_readings_bikes:
		neighboring_bikes += 1
		cohesion_vector.x += bike.position.x
		cohesion_vector.z += bike.position.z
	
	if neighboring_bikes > 0:
		cohesion_vector.x /= neighboring_bikes
		cohesion_vector.z /= neighboring_bikes
		
		cohesion_vector.x -= global_position.x
		cohesion_vector.z -= global_position.z
		
		cohesion_vector.x *= centeringfactor
		cohesion_vector.z *= centeringfactor
	
	return cohesion_vector
	
func separation():
	var separation_vector = Vector3.ZERO
	
	for reading in sensor_readings_drones:
		if reading.distance > avoid_radius:
			continue
		
		separation_vector.x += global_position.x - reading.position.x
		separation_vector.z += global_position.z - reading.position.z
	
	separation_vector.x *= avoidfactor
	separation_vector.z *= avoidfactor
	
	return separation_vector

# ─── Priority-Weighted Attraction Fields ──────────────────────────────────────

# Greedy single-pass clustering: bikes within cluster_distance_threshold of an
# existing cluster centroid are merged into it. Returns an Array of Dictionaries:
#   { centroid: Vector3, velocity: Vector3, size: int, weight: float }
func _cluster_bikes(readings: Array) -> Array:
	var clusters: Array = []

	for bike in readings:
		var assigned = false
		for cluster in clusters:
			var flat_dist = Vector2(
				bike.position.x - cluster.centroid.x,
				bike.position.z - cluster.centroid.z
			).length()
			if flat_dist < cluster_distance_threshold:
				var n = float(cluster.size)
				cluster.centroid = (cluster.centroid * n + bike.position) / (n + 1.0)
				cluster.velocity = (cluster.velocity * n + bike.velocity) / (n + 1.0)
				cluster.size += 1
				assigned = true
				break
		if not assigned:
			clusters.append({
				"centroid": bike.position,
				"velocity": bike.velocity,
				"size": 1,
				"weight": 0.0   # filled in below
			})

	# Inverse-size weighting: smaller clusters (breakaways) get higher attraction.
	# A lone rider scores 1/1 = 1.0; a 10-rider group scores 1/10 = 0.1.
	# Weights are normalised so they sum to 1.0 across all clusters.
	var inv_sum = 0.0
	for cluster in clusters:
		inv_sum += 1.0 / float(cluster.size)
	for cluster in clusters:
		cluster["weight"] = (1.0 / float(cluster.size)) / inv_sum

	return clusters

# Return the cluster whose centroid is nearest to a given position.
# Used to re-acquire the cached cluster as bikes (and thus the centroid) move.
func _nearest_cluster(clusters: Array, pos: Vector3) -> Dictionary:
	var best = clusters[0]
	var best_dist = pos.distance_to(clusters[0].centroid)
	for i in range(1, clusters.size()):
		var d = pos.distance_to(clusters[i].centroid)
		if d < best_dist:
			best_dist = d
			best = clusters[i]
	return best

# Compute a fresh rank-based assignment.
func _compute_assigned_cluster(clusters: Array) -> Dictionary:
	var all_ids: Array[int] = [id]
	for drone in sensor_readings_drones:
		all_ids.append(drone.id)
	all_ids.sort()
	var rank: int = all_ids.find(id)

	# Sort largest-first so extra drones (from modulo wrap) go to the main peloton
	var sorted_clusters = clusters.duplicate()
	sorted_clusters.sort_custom(func(a, b): return a.size > b.size)
	return sorted_clusters[rank % sorted_clusters.size()]

# Return a stable cluster assignment.
# Re-evaluates only when the cluster count changes (split/merge) or the timer expires.
# Between re-evaluations, tracks the cached cluster by proximity as centroids drift.
func _assigned_cluster(clusters: Array) -> Dictionary:
	var cluster_count_changed = clusters.size() != _last_cluster_count

	if _cached_cluster_centroid == Vector3.INF or cluster_count_changed or _cluster_assign_timer >= cluster_reassign_interval:
		_cluster_assign_timer = 0
		_last_cluster_count = clusters.size()
		var assigned = _compute_assigned_cluster(clusters)
		_cached_cluster_centroid = assigned.centroid
		return assigned

	_cluster_assign_timer += 1
	# Track the same cluster as its centroid drifts with the bikes
	var tracked = _nearest_cluster(clusters, _cached_cluster_centroid)
	_cached_cluster_centroid = tracked.centroid
	return tracked

func _priority_cohesion(clusters: Array) -> Vector3:
	if clusters.is_empty():
		return Vector3.ZERO
	var target = _assigned_cluster(clusters)
	var to_centroid = target.centroid - global_position
	to_centroid.y = 0.0
	return to_centroid * centeringfactor

func _priority_alignment(clusters: Array) -> Vector3:
	if clusters.is_empty():
		return Vector3.ZERO
	var target = _assigned_cluster(clusters)
	var vel_diff = target.velocity - flat_velocity(linear_velocity)
	return vel_diff * matchingfactor

func _make_cluster_dot() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	mi.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true
	mi.material_override = mat
	return mi

func _draw_cluster_debug_lines(clusters: Array) -> void:
	if not debug_draw or clusters.is_empty():
		return

	# Dots at each cluster centroid
	while _debug_cluster_dots.size() < clusters.size():
		var mi := _make_cluster_dot()
		get_parent().add_child.call_deferred(mi)
		_debug_cluster_dots.append(mi)
	var assigned = _assigned_cluster(clusters)
	for i in clusters.size():
		var mi = _debug_cluster_dots[i]
		var color = Color.GREEN if clusters[i].centroid == assigned.centroid else Color.ORANGE
		(mi.material_override as StandardMaterial3D).albedo_color = color
		mi.global_position = clusters[i].centroid
		mi.visible = true
	for i in range(clusters.size(), _debug_cluster_dots.size()):
		_debug_cluster_dots[i].visible = false

	# Line from this drone to its assigned cluster centroid
	if _debug_cluster_target_line == null:
		_debug_cluster_target_line = make_debug_line()
		get_parent().add_child.call_deferred(_debug_cluster_target_line)
	place_debug_line(_debug_cluster_target_line, global_position, assigned.centroid, Color.GREEN)

func height_force():
	if len(sensor_readings_bikes) == 0:
		return 0
		
	var neighboring_bikes = 0
	var avg_y = 0
	
	for bike in sensor_readings_bikes:
		neighboring_bikes += 1
		avg_y += bike.position.y
	
	avg_y /= neighboring_bikes
	var desired_y = avg_y + height_offset
	var y_error = desired_y - global_position.y
	
	if abs(y_error) < 10:
		return clamp(y_error * y_gain - linear_velocity.y * y_damp, -max_up_force, max_up_force)
	else:
		return 0

func rotate_towards_direction(direction_vector: Vector3):
	var desired_forward = flat_dir(direction_vector)
	
	if desired_forward.length() < 0.01:
		return
	
	var drone_forward = flat_dir(-global_transform.basis.z)
	var up = global_transform.basis.y
	
	var yaw_error = atan2(drone_forward.cross(desired_forward).y, drone_forward.dot(desired_forward))
	
	if abs(yaw_error) > torque_zone:
		var torque_strength = clamp(yaw_error * yaw_gain, -1.0, 1.0) * max_torque
		apply_torque(up * torque_strength)

#Controller for following a picked target
func follow_target():
	var follow_data = get_follow_data()
	
	rotate_towards_bike(follow_data.bike_forward, follow_data.drone_forward)

	var desired_velocity = compute_desired_velocity(follow_data)
	apply_horizontal_follow_force(desired_velocity, follow_data)
	apply_collision_avoidance()

	control_height(follow_data.desired_pos)

func search_spin():
	var up = global_transform.basis.y
	apply_torque(up * max_torque)
	apply_collision_avoidance()
	
func apply_collision_avoidance():
	var avoidance_force = Vector3.ZERO

	for reading in sensor_readings_drones:
		if reading.distance > avoid_radius:
			continue

		var away = global_position - reading.position
		away.y = 0.0
		away = away.normalized()

		var weight = (avoid_radius - reading.distance) / avoid_radius

		avoidance_force += away * weight * avoid_strength

	apply_central_force(clamp_vector(avoidance_force, max_force))
	
func get_follow_data():
	# Info from bike that is being followed. Flattened to reduce interference from height offset
	# Direction forward is -z
	var bike_forward = flat_dir(-target_bike.global_transform.basis.z)
	#Offset to the right (or left if negative)
	var bike_right = flat_dir(target_bike.global_transform.basis.x)
	#Speed taken from bike directly
	var bike_speed = target_bike.speed
	#Calculate velocity from direction and speed
	var bike_velocity = bike_forward * bike_speed

	#Forward direction and velocity of drone itself. Flattened to reduce interference from height offset
	var drone_forward = flat_dir(-global_transform.basis.z)
	var drone_velocity = flat_velocity(linear_velocity)

	#Calculate desired position from position of bike, its direction and a distance which we wish to stay behind it
	#Behind distance can be adjusted above
	#Again, flatten(Remove y)
	var desired_pos = target_bike.global_position - bike_forward * behind_distance
	desired_pos.y = target_bike.global_position.y + height_offset

	#Vector from bike to drone, flatten again
	var bike_to_drone = global_position - target_bike.global_position
	bike_to_drone.y = 0.0

	#How far the drone is in front of (or behind) the bike
	#Positive = drone is in front, Negative = drone is behind
	var forward_offset = bike_to_drone.dot(bike_forward)

	#How far the drone is to the right (or left) of the bike
	#Positive = drone is to the right, Negative = drone is to the left
	var side_offset = bike_to_drone.dot(bike_right)

	#Return values for use in following logic
	return {
		"bike_forward": bike_forward,
		"bike_right": bike_right,
		"drone_forward": drone_forward,
		"drone_velocity": drone_velocity,
		"bike_speed": bike_speed,
		"bike_velocity": bike_velocity,
		"desired_pos": desired_pos,
		"forward_offset": forward_offset,
		"side_offset": side_offset
	}

func rotate_towards_bike(bike_forward: Vector3, drone_forward: Vector3):
	#The axis to rotate about.
	var up = global_transform.basis.y

	#The angle the drone needs to rotate to face the bike
	#Positive = rotate one way, negative = rotate the other way
	var yaw_error = atan2(drone_forward.cross(bike_forward).y, drone_forward.dot(bike_forward))

	#Don't rotate if angle is too small, will cause a lot of oscillation
	#Adjust torque zone to adjust how much
	if abs(yaw_error) > torque_zone:
		#bigger error = stronger turning, smaller error = weeaker tuning. Adjust yaw gain
		#Values clamped to -1 and 1 to limit strength
		var torque_strength = clamp(yaw_error * yaw_gain, -1.0, 1.0) * max_torque
		apply_torque(up * torque_strength)

func compute_desired_velocity(data) -> Vector3:
	var desired_velocity = data.bike_velocity
	#How far is the drone off in terms of direction, too far behind/in front. Ideally behind
	var direction_error = -behind_distance - data.forward_offset

	#checks if the drone is too far behind bike.
	if data.forward_offset < -max_distance:
		#“How much behind is the drone, compared to the ideal behind distance”
		var catchup_amount = abs(data.forward_offset + behind_distance)
		#Set velocity accordingly
		desired_velocity += data.bike_forward * min(catchup_amount * catchup_gain, max_catchup_speed)
	else:
		desired_velocity += data.bike_forward * (direction_error)

	#Adjust sideways also
	desired_velocity += data.bike_right * (-data.side_offset)

	return desired_velocity

func apply_horizontal_follow_force(desired_velocity: Vector3, data):
	apply_central_force(clamp_vector(desired_velocity - data.drone_velocity, max_force))

	if data.forward_offset > 0.5:
		apply_central_force(-data.bike_forward * brake_force)

func control_height(desired_pos: Vector3):
	#How far from the target height
	var y_error = desired_pos.y - global_position.y
	#How fast the drone is already moving up/down
	var y_vel = linear_velocity.y
	#Drone far below the target = push up strongly. If drone far above = push down strongly
	var y_force = (y_error * y_gain) - (y_vel * y_damp)
	y_force = clamp(y_force, -max_up_force, max_up_force)
	apply_central_force(Vector3.UP * y_force)

# ─── Debug ────────────────────────────────────────────────────────────────────

func make_debug_line() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(debug_line_width, debug_line_width, 1.0)
	mi.mesh = box
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true
	mi.material_override = mat
	return mi

func place_debug_line(mi: MeshInstance3D, a: Vector3, b: Vector3, color: Color, up: Vector3 = Vector3.UP) -> void:
	if not mi.is_inside_tree():
		return
	var dir := b - a
	var length := dir.length()
	if length < 0.001:
		mi.visible = false
		return
	mi.global_position = (a + b) * 0.5
	mi.global_transform.basis = Basis.looking_at(dir / length, up)
	mi.scale = Vector3(1.0, 1.0, length)
	(mi.material_override as StandardMaterial3D).albedo_color = color
	mi.visible = true

func _draw_bike_debug_lines() -> void:
	if not debug_draw:
		return
	while _debug_bike_lines.size() < sensor_readings_bikes.size():
		var mi := make_debug_line()
		get_parent().add_child.call_deferred(mi)
		_debug_bike_lines.append(mi)
	for i in sensor_readings_bikes.size():
		place_debug_line(_debug_bike_lines[i], global_position, sensor_readings_bikes[i]["position"], Color.YELLOW)
	for i in range(sensor_readings_bikes.size(), _debug_bike_lines.size()):
		_debug_bike_lines[i].visible = false

#Helper functions
func flat_dir(v: Vector3) -> Vector3:
	v.y = 0.0
	return v.normalized()

func flat_velocity(v: Vector3) -> Vector3:
	v.y = 0.0
	return v

func clamp_vector(v: Vector3, max_len: float) -> Vector3:
	if v.length() > max_len:
		return v.normalized() * max_len
	return v

func get_camera_node() -> Camera3D:
	return $Camera3D

func read_sensor(drones: Dictionary, bikes: Dictionary):
	sensor_readings_drones = []
	sensor_readings_bikes = []

	if version == Version.BoidsRandomTargets:
		# For BoidsRandomTargets we want to keep the same bike readings for a few frames to give the drone a chance to react to them, instead of changing them every frame which would make it hard for the drone to learn anything.
		if sensor_selection_timer < keep_selection_for_n_frames:
			sensor_selection_timer += 1
		else:
			_random_target_bikes.clear()
			sensor_selection_timer = 0

	for drone in drones:
		if drone.id != id:
			sensor_readings_drones.append(
				{
					"id": drone.id,
					"position": drone.global_position,
					"distance": global_position.distance_to(drone.global_position),
					"direction": global_position.direction_to(drone.global_position)
				}
			)
	
	if version == Version.Boids or version == Version.BoidsPriorityAttractionFields:

		# All bike data is used; BoidsPriorityAttractionFields clusters internally
		for bike in bikes:
			sensor_readings_bikes.append(get_bike_data(bike))

	elif version == Version.BoidsRandomTargets:

		if _random_target_bikes.is_empty():
			# Randomly select a subset of bikes to consider for the boids calculations.
			# The idea is that the drones will spread out more and not all cluster around the same target bike,
			# which could help with splitting up the drones when the peloton splits.
			for bike in bikes:
				if randf() < random_selection_rate:
					_random_target_bikes.append(bike)
		else:
			# Remove any bikes that have left the simulation (iterate backwards to avoid index shift)
			for i in range(_random_target_bikes.size() - 1, -1, -1):
				if not bikes.has(_random_target_bikes[i]):
					_random_target_bikes.remove_at(i)

		# Rebuild sensor readings from the current selection
		for bike in _random_target_bikes:
			sensor_readings_bikes.append(get_bike_data(bike))

	elif version == Version.BoidsDynamicTargets:

		# Like BoidsRandomTargets but the selection rate is derived from the drone/bike ratio.
		# Each drone covers roughly (bike_count / drone_count) bikes on average, so that
		# collectively all drones spread evenly across the peloton.
		var drone_count = max(1, drones.size())
		# Each drone picks 1/drone_count of all bikes on average, so across all
		# drones each bike gets covered roughly once regardless of fleet size.
		var dynamic_rate = clamp(1.0 / float(drone_count), 0.05, 1.0)

		for bike in bikes:
			if randf() < dynamic_rate:
				sensor_readings_bikes.append(get_bike_data(bike))

func get_bike_data(bike: Bike_body) -> Dictionary:
	return {
		"position": bike.global_position,
		"distance": global_position.distance_to(bike.global_position),
		"direction": global_position.direction_to(bike.global_position),
		"velocity":  flat_dir(-bike.global_transform.basis.z) * bike.get_parent().speed
	}

func get_nearest_position(bikes: Dictionary):
	var closest = Vector3.ZERO
	var minimum_distance = INF
	var speed = 0.0

	for bike_id in bikes:
		var pos = bikes[bike_id].global_position
		var dist = global_position.distance_to(pos)
		if dist < minimum_distance:
			minimum_distance = dist
			closest = pos
			speed = bikes[bike_id].get_parent().speed
			target_bike = bikes[bike_id].get_parent()

	target_position = closest
	target_speed = speed

func get_random_position(bikes: Dictionary):
	if bikes.is_empty():
		return

	var keys = bikes.keys()
	var random_key = keys[randi() % keys.size()]
	var bike = bikes[random_key]

	target_position = bike.global_position
	target_speed = bike.get_parent().speed
	target_bike = bike.get_parent()
