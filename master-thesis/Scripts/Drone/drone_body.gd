extends RigidBody3D
class_name Drone
signal freeing_drone

static var _next_id: int = 1
var id: int

enum Version { Boids, BoidsPriorityAttractionFields, BoidsPriorityGroups }

var is_rl: bool = false
var is_training: bool = false

var collision_at_time_step = 0
var timestep = 1

@onready var camera: Camera3D = $"Camera3D"
@onready var drone_sensor: DroneCommunication = $"Drone_communication"

@onready var camera_readings = []
@onready var sensor_readings_drones = []
@onready var sensor_readings_bikes = []

@onready var target_speed = null
@onready var target_bike = null
@export var behind_distance := 4.0
@export var max_torque := 2.0
@export var yaw_gain := 2.2
@export var torque_zone := 0.05
@export var max_force := 18.0

#Boids tuneable parameters
@export var max_up_force := 120.0
@export var y_gain := 35.0
@export var y_damp := 18.0
@export var height_offset := 5.0
@export var avoid_radius := 10.0
@export var avoidfactor = 5
@export var centeringfactor = 2
@export var matchingfactor = 0.4

@export var version: Version = Version.BoidsPriorityGroups
@export var random_selection_rate := 0.2
var keep_selection_for_n_frames = 100

# BoidsPriorityAttractionFields parameters
# Bikes closer than this (metres) are merged into the same cluster
@export var cluster_distance_threshold := 10.0

@export var coverage_radius := 10.0

@export var debug_draw: bool = false
@export var debug_line_width: float = 0.1

var _debug_bike_lines: Array[MeshInstance3D] = []
var _debug_cluster_dots: Array[MeshInstance3D] = []
var _debug_cluster_target_line: MeshInstance3D = null

#Idle status
@export var idle_until_needed := false
@export var has_activated := true

var should_check_camera = false

var _cached_force: Vector3 = Vector3.ZERO
var _cached_rotation_dir: Vector3 = Vector3.ZERO
var _boids_throttle: int = 0

var last_point = null

func _ready():
	id = _next_id
	_next_id += 1
	contact_monitor = true
	max_contacts_reported = 100
	if not is_training:
		start_logging()
	body_entered.connect(_on_body_entered)
	var path = get_parent().get_node("BikePath3d") as Path3D
	var curve = path.curve
	last_point = path.to_global(curve.get_point_position(curve.point_count - 1))

func _physics_process(_delta):
	if self.position.distance_to(last_point) < 60 and sensor_readings_bikes.is_empty():
		queue_free()
		return

	if is_training:
		if is_rl:
			apply_central_force(_cached_force)
			rotate_towards_direction(_cached_rotation_dir)
		return

	should_check_camera = timestep % 30 == 0

	if not is_rl:
		if _boids_throttle % 3 == id % 3:
			_compute_boids()
		_boids_throttle += 1

	apply_central_force(_cached_force)
	rotate_towards_direction(_cached_rotation_dir)

	if should_check_camera:
		update_camera_readings_for_log()
		log_information(timestep)

	timestep += 1
	collision_at_time_step = 0

func _compute_boids():
	var sim = get_parent()
	var self_pos = global_position
	var sensor_radius_sq: float = shared.drone_communication_size * shared.drone_communication_size

	var bike_data: Array = []
	for bike_instance in shared.bike_lists[sim.instance_id]:
		var b = bike_instance.bikebody
		if self_pos.distance_squared_to(b.global_position) > sensor_radius_sq:
			continue
		var fwd = -b.global_transform.basis.z
		fwd.y = 0.0
		bike_data.append({
			"position": b.global_position,
			"velocity": fwd.normalized() * bike_instance.speed,
			"id": b.bike_id
		})

	var drone_data: Array = []
	for d in sim.drone_list:
		if d == self:
			continue
		if self_pos.distance_squared_to(d.global_position) <= sensor_radius_sq:
			drone_data.append({"id": d.id, "position": d.global_position})

	sensor_readings_bikes = bike_data
	sensor_readings_drones = drone_data

	var clusters := _cluster_bikes(bike_data)
	var assigned := _assigned_cluster_local(clusters, drone_data)
	var bikes: Array = assigned["bikes"]

	_draw_cluster_debug_lines([assigned])

	var alignment_vector = alignment(bikes)
	var cohesion_vector = cohesion(bikes)
	var separation_vector = separation_fast()

	var direction_vector = alignment_vector + cohesion_vector + separation_vector
	direction_vector.y = height_force(bikes)

	_cached_force = clamp_vector(direction_vector, max_force)
	_cached_rotation_dir = -alignment_vector

func _assigned_cluster_local(clusters: Array, local_drones: Array) -> Dictionary:
	if clusters.is_empty():
		return {
			"centroid": Vector3.ZERO,
			"velocity": Vector3.ZERO,
			"size": 0,
			"bikes": []
		}

	var best: Dictionary = {}
	var best_val = -INF

	var self_pos = global_position
	var coverage_radius_sq = coverage_radius * coverage_radius
	var forward = flat_dir(-global_transform.basis.z)

	for cluster in clusters:
		var centroid: Vector3 = cluster["centroid"]
		var v = _coverage_score(cluster["size"])
		var self_dist_sq = self_pos.distance_squared_to(centroid)

		var count := 0
		for d in local_drones:
			var d_dist_sq = d["position"].distance_squared_to(centroid)
			if d_dist_sq < self_dist_sq or d_dist_sq < coverage_radius_sq:
				count += 1
		v -= count

		var to_cluster = centroid - self_pos
		to_cluster.y = 0.0
		if to_cluster.length_squared() > 0.0001 and forward.dot(to_cluster.normalized()) < 0.0:
			v *= 0.8

		if v > best_val:
			best_val = v
			best = cluster

	return best

func separation_fast():
	var separation_vector = Vector3.ZERO
	var avoid_radius_sq = avoid_radius * avoid_radius
	var self_pos = global_position

	for drone in sensor_readings_drones:
		if drone["id"] == id:
			continue

		var diff = self_pos - drone["position"]
		diff.y = 0.0

		var dist_sq = diff.length_squared()

		if dist_sq > avoid_radius_sq:
			continue

		dist_sq = max(dist_sq, 0.0001)
		separation_vector += diff / dist_sq

	return separation_vector * avoidfactor

func update_camera_readings_for_log():
	camera_readings.clear()

	var bikes = get_parent().cached_bikes

	for bike in bikes:
		if camera.is_position_in_frustum(bike["position"]):
			camera_readings.append(bike)

func set_tunable_parameters(params: Dictionary):
	avoid_radius = params["avoid_radius"]
	avoidfactor = params["avoid_factor"]
	centeringfactor = params["centering_factor"]
	matchingfactor = params["matching_factor"]

func boids():
	read_sensor(drone_sensor.drone_set, drone_sensor.bike_set)

	var alignment_vector: Vector3
	var cohesion_vector: Vector3

	var bikes_for_boids: Array

	if version == Version.BoidsPriorityAttractionFields:
		var clusters = _cluster_bikes(sensor_readings_bikes)

		alignment_vector = _priority_alignment(clusters)
		cohesion_vector = _priority_cohesion(clusters)
		_draw_cluster_debug_lines(clusters)

		_boids_apply(clusters.bikes, alignment_vector, cohesion_vector)
		return

	elif version == Version.BoidsPriorityGroups:

		var clusters = _cluster_bikes(sensor_readings_bikes)
		var assigned_cluster = _assigned_cluster(clusters)

		_draw_cluster_debug_lines(clusters)
		_draw_bike_debug_lines(assigned_cluster.bikes)

		bikes_for_boids = assigned_cluster.bikes

	else:
		_draw_bike_debug_lines(sensor_readings_bikes)
		bikes_for_boids = sensor_readings_bikes

	boids_bikes(bikes_for_boids)

func boids_bikes(bikes):
	var alignment_vector = alignment(bikes)
	var cohesion_vector = cohesion(bikes)

	_boids_apply(bikes, alignment_vector, cohesion_vector)

func _boids_apply(bikes, alignment_vector, cohesion_vector):

	var separation_vector = separation()

	var direction_vector = alignment_vector + cohesion_vector + separation_vector
	direction_vector.y = height_force(bikes)

	apply_central_force(clamp_vector(direction_vector, max_force))
	rotate_towards_direction(-alignment_vector)

# Boids algorithm implementation
func alignment(bikes):
	var alignment_vector = Vector3.ZERO
	var neighboring_bikes = 0

	for bike in bikes:
		neighboring_bikes += 1
		alignment_vector.x += bike["velocity"].x
		alignment_vector.z += bike["velocity"].z

	if neighboring_bikes > 0:
		alignment_vector.x /= neighboring_bikes
		alignment_vector.z /= neighboring_bikes

	alignment_vector.x = (alignment_vector.x - linear_velocity.x) * matchingfactor
	alignment_vector.z = (alignment_vector.z - linear_velocity.z) * matchingfactor

	return alignment_vector

func cohesion(bikes):
	var cohesion_vector = Vector3.ZERO
	var neighboring_bikes = 0

	for bike in bikes:
		neighboring_bikes += 1
		cohesion_vector.x += bike["position"].x
		cohesion_vector.z += bike["position"].z

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
		if reading["distance"] > avoid_radius:
			continue

		var diff = Vector3(
			global_position.x - reading.position.x,
			0,
			global_position.z - reading.position.z
		)
		var dist = max(diff.length(), 0.01)
		separation_vector += diff / (dist * dist)

	return separation_vector * avoidfactor

var _smooth_target_y: float = 0.0

func height_force(bikes) -> float:
	if bikes.is_empty():
		return 0.0
	var highest_y := -INF
	for bike in bikes:
		highest_y = max(highest_y, bike["position"].y)
	var desired_y := highest_y + height_offset
	# Smooth the target so one bike dipping/rising doesn't yank the drone
	_smooth_target_y = lerpf(_smooth_target_y, desired_y, 0.05)
	var y_error := _smooth_target_y - global_position.y
	return clamp(y_error * y_gain - linear_velocity.y * y_damp, -max_up_force, max_up_force)
	
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

# Cluster methods for BoidsPriorityAttractionFields and BoidsPriorityGroups
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
				cluster.bikes.append(bike)
				assigned = true
				break
		if not assigned:
			clusters.append({
				"centroid": bike.position,
				"velocity": bike.velocity,
				"size": 1,
				"bikes": [bike]
			})

	return clusters

# BoidsPriorityGroups methods
func _assigned_cluster(clusters: Array) -> Dictionary:
	if clusters.is_empty():
		return {
		"centroid": Vector3.ZERO,
		"velocity": Vector3.ZERO,
		"size": 0,
		"bikes": []
		}

	var best: Dictionary = {}
	var best_val = -INF

	for i in range(clusters.size()):
		var v = _coverage_score(clusters[i].size)

		var self_dist = global_position.distance_to(clusters[i].centroid)
		# check how many drones are already on this cluster
		var count = 0
		for drone in sensor_readings_drones:
			var drone_dist = drone.position.distance_to(clusters[i].centroid)

			# if drone is closer to the cluster than self, count it as a competitor for this cluster
			# or if the drone is within the coverage radius, count it as well since it can be considered "covering" the cluster even if it's not closer than self
			if drone_dist < self_dist or drone_dist < coverage_radius:
				count += 1

		# add small penalty for clusters behind the drone
		var to_cluster = clusters[i].centroid - global_position
		to_cluster.y = 0
		var forward = -global_transform.basis.z
		var angle = forward.angle_to(to_cluster)
		if abs(angle) > PI / 2:
			v *= 0.8

		v -= count

		if v > best_val:
			best_val = v
			best = clusters[i]

	return best

# BoidsPriorityAttractionFields methods
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

#Drones along road functions
func _should_activate_from_coverage():
	var visible_bikes = camera_readings

	if visible_bikes.is_empty():
		return false

	var clusters = _cluster_bikes(visible_bikes)

	for cluster in clusters:
		var required_coverage = _coverage_score(cluster.size)
		var covering_drones = _count_drones_covering_cluster(cluster)
		
		if covering_drones < required_coverage:
			return true

	return false

func _count_drones_covering_cluster(cluster):
	var count = 0
	var centroid: Vector3 = cluster["centroid"]

	for drone in sensor_readings_drones:
		var drone_pos: Vector3 = drone["position"]
		
		if drone_pos.distance_to(centroid) <= coverage_radius:
			count += 1
	return count

# ─── Debug ────────────────────────────────────────────────────────────────────
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
		if mi.is_inside_tree():
			mi.global_position = clusters[i].centroid
		mi.visible = true
	for i in range(clusters.size(), _debug_cluster_dots.size()):
		_debug_cluster_dots[i].visible = false

	# Line from this drone to its assigned cluster centroid
	if _debug_cluster_target_line == null:
		_debug_cluster_target_line = make_debug_line()
		get_parent().add_child.call_deferred(_debug_cluster_target_line)
	place_debug_line(_debug_cluster_target_line, global_position, assigned.centroid, Color.GREEN)

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

func _draw_bike_debug_lines(bikes) -> void:
	if not debug_draw:
		return
	while _debug_bike_lines.size() < bikes.size():
		var mi := make_debug_line()
		get_parent().add_child.call_deferred(mi)
		_debug_bike_lines.append(mi)
	for i in range(bikes.size()):
		place_debug_line(_debug_bike_lines[i], global_position, bikes[i]["position"], Color.YELLOW)
	for i in range(bikes.size(), _debug_bike_lines.size()):
		_debug_bike_lines[i].visible = false

# ─── Helper functions ────────────────────────────────────────────────────────────────────
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
	camera_readings = []
	sensor_readings_drones = []
	sensor_readings_bikes = []

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

	for bike in bikes:
		var data = get_bike_data(bike)
		if should_check_camera:
			if camera.is_position_in_frustum(bike.global_position):
				camera_readings.append(data)
		sensor_readings_bikes.append(data)

func read_sensor_by_distance() -> void:
	var sim = get_parent()
	var self_pos := global_position
	var sensor_radius_sq: float = shared.drone_communication_size * shared.drone_communication_size

	camera_readings = []
	sensor_readings_drones = []
	sensor_readings_bikes = []

	for d in sim.drone_list:
		if d == self:
			continue
		if self_pos.distance_squared_to(d.global_position) <= sensor_radius_sq:
			sensor_readings_drones.append({
				"id": d.id,
				"position": d.global_position,
				"distance": self_pos.distance_to(d.global_position),
				"direction": self_pos.direction_to(d.global_position)
			})

	for bike_instance in shared.bike_lists[sim.instance_id]:
		var b: Bike_body = bike_instance.bikebody
		if self_pos.distance_squared_to(b.global_position) > sensor_radius_sq:
			continue
		var data = get_bike_data(b)
		if should_check_camera:
			if camera.is_position_in_frustum(b.global_position):
				camera_readings.append(data)
		sensor_readings_bikes.append(data)

func get_bike_data(bike: Bike_body) -> Dictionary:
	return {
		"position": bike.global_position,
		"distance": global_position.distance_to(bike.global_position),
		"direction": global_position.direction_to(bike.global_position),
		"velocity":  flat_dir(-bike.global_transform.basis.z) * bike.get_parent().speed,
		"id": bike.bike_id
	}

# log base 1.9 of n + 1, rounded to nearest int.
# n = 1 -> 1
# n = 2 -> 2
# n = 3 -> 3
# n = 4 -> 3
# n = 5 -> 4
# n = 10 -> 5
# n = 20 -> 6
func _coverage_score(n: int) -> int:
	return round(pow(log(float(n)) / log(float(2.4)), 2.3)) + 1 
	#return round(log(float(n)) / log(1.9)) + 1

func safe_queue_free() -> void:
	get_parent().erase_drone(self)
	freeing_drone.emit(self)
	queue_free()

# ─── Logging ────────────────────────────────────────────────────────────────────

func _on_body_entered(_body):
	collision_at_time_step += 1

func create_logging_message(delta):
	var data = []

	data.append(str(delta))
	data.append(str(global_position.x))
	data.append(str(global_position.y))
	data.append(str(global_position.z))
	data.append(str(collision_at_time_step))

	var bikes_id = '['
	for bike in camera_readings:
		bikes_id += ' '+str(bike['id'])

	data.append(bikes_id+' ]')

	return data

func start_logging():
	logging.start_run_file(str(self.id), "drone")

func log_information(delta):
	var message = create_logging_message(delta)
	logging.append_line(str(self.id), "drone", message)
