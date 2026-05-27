extends AIController3D
class_name DroneRL

enum Version { BoidsRl, GroupingRl, GroupingBoidsRl }

@export var rl_version: Version = Version.BoidsRl
@export var no_bike_reset_steps: int = 500
# Boids RL filming reward parameters
@export var optimal_film_dist: float = 6.0   # ideal horizontal distance to bike centroid (metres)
@export var film_dist_tolerance: float = 3.0  # half-width of the reward tent (metres)
# GroupingBoidsRl: path to a trained BoidsRl ONNX model used for low-level movement
@export var boids_rl_model_path: String = ""

@onready var drone: Drone = $".."

var _boids_rl_model: ONNXModel = null
var _boids_rl_assigned_bikes: Array = []
var _debug_lines: Array[MeshInstance3D] = []
var _debug_force_line: MeshInstance3D = null
var _debug_torque_line: MeshInstance3D = null
var _last_force: Vector3 = Vector3.ZERO
var _last_torque: float = 0.0

# Grouping rl cluster state (refreshed each physics step)
var _grouping_rl_clusters: Array = []

var _grouping_rl_selected_cluster: Dictionary = {}
var _grouping_rl_cluster_dots: Array[MeshInstance3D] = []
var _grouping_rl_selected_line: MeshInstance3D = null

var _prev_avg_bike_vel: Vector3 = Vector3.ZERO

# ─── RL setup ────────────────────────────────────────────────────────────────────

func _ready():
	if not get_parent().is_rl:
		control_mode = ControlModes.HUMAN
		return
	super._ready()
	print("RL drone ready with version ", rl_version)

	if rl_version == Version.GroupingBoidsRl and boids_rl_model_path != "":
		_boids_rl_model = ONNXModel.new(boids_rl_model_path, 1)

func _physics_process(_delta):
	if not get_parent().is_rl:
		return
	if drone.is_queued_for_deletion():
		done = true
		needs_reset = true
		return
	if needs_reset:
		reset()
		return

	var world = drone.get_parent()
	if shared.bike_lists[world.instance_id].is_empty():
		done = true
		needs_reset = true
		return

	if rl_version == Version.GroupingRl or rl_version == Version.GroupingBoidsRl:
		_physics_process_grouping_rl()
		return

	if rl_version == Version.BoidsRl:
		if world.is_training:
			_physics_process_boids_rl(world)
		return

func get_obs() -> Dictionary:
	match rl_version:
		Version.BoidsRl:
			if not drone.is_training:
				drone.read_sensor_by_distance()
				_boids_rl_assigned_bikes = _compute_assigned_bikes()
			return _get_obs_boids_rl(_boids_rl_assigned_bikes, drone._filter_camera(_boids_rl_assigned_bikes), drone.sensor_readings_drones)

		Version.GroupingRl: return _get_obs_grouping_rl()
		Version.GroupingBoidsRl: return _get_obs_grouping_rl()
	return {}

func get_action_space() -> Dictionary:
	match rl_version:
		Version.BoidsRl: return _get_action_space_boids_rl()
		Version.GroupingRl: return _get_action_space_grouping_rl()
		Version.GroupingBoidsRl: return _get_action_space_grouping_rl()
	return {}

func set_action(action) -> void:
	match rl_version:
		Version.BoidsRl: _set_action_boids_rl(action)
		Version.GroupingRl: _set_action_grouping_rl(action)
		Version.GroupingBoidsRl: _set_action_grouping_boids_rl(action)


func get_reward() -> float:
	return reward


func reset():
	super.reset()
	drone.linear_velocity = Vector3.ZERO
	drone.angular_velocity = Vector3.ZERO

	_grouping_rl_selected_cluster = {}

	var world = drone.get_parent()
	if world.is_training:
		# All bikes finished the course — full world reset.
		world.reset_track_and_bike_and_drone()

		# Randomize bikes to create different grouping scenarios for the agent to learn from.
		var random_bike_values = Bike.get_randomize_for_rl()
		for bike in shared.bike_lists[world.instance_id]:
			bike.set_randomize_for_rl(random_bike_values)
	else:
		# close the program
		get_tree().quit()

# ─── Boids RL ────────────────────────────────────────────────────────────────────

func _compute_assigned_bikes() -> Array:
	var clusters := drone._cluster_bikes(drone.sensor_readings_bikes)
	var assigned = drone._assigned_cluster_local_v2(clusters, drone.sensor_readings_drones) \
		if drone.cluster_version == drone.Cluster_version.V2 \
		else drone._assigned_cluster_local(clusters, drone.sensor_readings_drones)
	return assigned["bikes"]

func _physics_process_boids_rl(world) -> void:
	drone.read_sensor_by_distance()
	_boids_rl_assigned_bikes = _compute_assigned_bikes()

	if drone.sensor_readings_bikes.is_empty():
		reward -= 0.5
		# Only the first drone checks the collective condition to avoid multiple resets.
		if world.is_training and drone == world.drone_list[0]:
			var any_has_bikes := false
			for d in world.drone_list:
				if not d.sensor_readings_bikes.is_empty():
					any_has_bikes = true
					break
			if not any_has_bikes:
				done = true
				needs_reset = true

	_draw_debug_lines()
	_compute_reward_boids_rl_v2()

func _compute_reward_boids_rl_v2() -> void:
	var nearby_count = _boids_rl_assigned_bikes.size()
	if nearby_count == 0:
		return

	var bikes_in_camera = drone._filter_camera(_boids_rl_assigned_bikes)
	var visible_count = bikes_in_camera.size()

	# +1 when all cluster bikes visible, -1 when none, linear in between
	var coverage = float(visible_count) / float(nearby_count)
	reward += 2.0 * coverage - 1.0

	# Small proximity bonus — decays linearly to 0 at 3× optimal_film_dist
	var bike_centroid := Vector3.ZERO
	for reading in _boids_rl_assigned_bikes:
		bike_centroid += reading.position
	bike_centroid /= float(nearby_count)
	var horiz_dist := Vector3(bike_centroid.x - drone.global_position.x, 0.0, bike_centroid.z - drone.global_position.z).length()
	reward += clamp(1.0 - horiz_dist / (optimal_film_dist * 3.0), 0.0, 1.0) * 0.2

func _compute_reward_boids_rl() -> void:
	var nearby_count = _boids_rl_assigned_bikes.size()
	if nearby_count == 0:
		return

	var bikes_in_camera = drone._filter_camera(_boids_rl_assigned_bikes)
	var visible_count = bikes_in_camera.size()

	# Primary: fraction of assigned cluster bikes that are in frame (squared for
	# stronger gradient near zero — losing coverage costs much more than gaining it).
	var coverage = float(visible_count) / float(nearby_count)
	reward += coverage * coverage

	if visible_count > 0:
		var camera = drone.get_camera_node()
		var cam_inv = camera.global_transform.basis.inverse()
		var centroid_cam = Vector2.ZERO

		for bike_data in bikes_in_camera:
			var to_bike = cam_inv * (bike_data["position"] - camera.global_position)
			var fwd = -to_bike.z
			if fwd > 0.01:
				centroid_cam.x += clamp(to_bike.x / fwd, -1.0, 1.0)
				centroid_cam.y += clamp(to_bike.y / fwd, -1.0, 1.0)

		centroid_cam /= float(visible_count)
		reward += (1.0 - clamp(centroid_cam.length(), 0.0, 1.0)) * 0.3

	# Bonus when all assigned cluster bikes are in frame.
	if visible_count == nearby_count:
		reward += 0.5

	var bike_centroid = Vector3.ZERO
	for reading in _boids_rl_assigned_bikes:
		bike_centroid += reading.position
	bike_centroid /= float(nearby_count)

	var to_centroid = bike_centroid - drone.global_position
	to_centroid.y = 0.0

	if to_centroid.length() > 0.1:
		var drone_forward = -drone.global_transform.basis.z
		drone_forward.y = 0.0
		reward += drone_forward.normalized().dot(to_centroid.normalized()) * 0.3

	var horiz_dist = to_centroid.length()
	var dist_reward = 1.0 - clamp(abs(horiz_dist - optimal_film_dist) / film_dist_tolerance, 0.0, 1.0)
	reward += dist_reward * 0.3

# 13 observations for boids rl (camera-coverage / following):
#   coverage (1), centroid_cam xy (2), full_coverage flag (1),
#   dist_error (1), camera_facing (1),
#   avg_bike_vel xz in drone-local frame (2), own velocity xyz (3),
#   avg_bike_vel delta xz in drone-local frame (2) — encodes turn rate / heading change
func _get_obs_boids_rl(bikes : Array, camera_readings : Array, drone_sensor_readings : Array) -> Dictionary:
	var nearby_count = bikes.size()
	var obs: Array = []

	if nearby_count == 0:
		_prev_avg_bike_vel = Vector3.ZERO
		for _i in 13:
			obs.append(0.0)
		return {"obs": obs}

	# --- Camera coverage ---
	var bikes_in_camera = camera_readings
	var visible_count = bikes_in_camera.size()
	obs.append(float(visible_count) / float(nearby_count))

	var camera = drone.get_camera_node()
	var cam_inv = camera.global_transform.basis.inverse()
	var centroid_cam = Vector2.ZERO
	if visible_count > 0:
		for bike_data in bikes_in_camera:
			var to_bike = cam_inv * (bike_data["position"] - camera.global_position)
			var fwd = -to_bike.z
			if fwd > 0.01:
				centroid_cam.x += clamp(to_bike.x / fwd, -1.0, 1.0)
				centroid_cam.y += clamp(to_bike.y / fwd, -1.0, 1.0)
		centroid_cam /= float(visible_count)
	obs.append(centroid_cam.x)
	obs.append(centroid_cam.y)
	obs.append(1.0 if visible_count == nearby_count else 0.0)

	# --- Spatial relationship to centroid of locally sensed bikes ---
	var bike_centroid = Vector3.ZERO
	for reading in bikes:
		bike_centroid += reading.position
	bike_centroid /= float(nearby_count)

	var to_centroid = bike_centroid - drone.global_position
	to_centroid.y = 0.0
	var horiz_dist = to_centroid.length()

	obs.append(clamp((horiz_dist - optimal_film_dist) / film_dist_tolerance, -1.0, 1.0))

	var drone_forward = -drone.global_transform.basis.z
	drone_forward.y = 0.0
	obs.append(drone_forward.normalized().dot(to_centroid.normalized()) if horiz_dist > 0.1 else 0.0)

	# --- Bike group dynamics ---
	# Average bike velocity in drone-local XZ frame: tells the agent how fast
	# and in which direction the group is moving (key for matching_factor tuning).
	var avg_vel := Vector3.ZERO
	for reading in bikes:
		avg_vel += reading.velocity
	avg_vel /= float(nearby_count)
	var local_avg_vel = drone.global_transform.basis.inverse() * avg_vel
	obs.append(clamp(local_avg_vel.x / 22.0, -1.0, 1.0))
	obs.append(clamp(local_avg_vel.z / 22.0, -1.0, 1.0))

	# --- Own velocity in drone-local frame ---
	var local_vel = drone.global_transform.basis.inverse() * drone.linear_velocity
	obs.append(clamp(local_vel.x / 15.0, -1.0, 1.0))
	obs.append(clamp(local_vel.y / 15.0, -1.0, 1.0))
	obs.append(clamp(local_vel.z / 15.0, -1.0, 1.0))

	# --- Bike group velocity delta (turn rate): change since last obs query ---
	# Non-zero when the peloton is cornering; lets the agent anticipate tight turns.
	var vel_delta = avg_vel - _prev_avg_bike_vel
	_prev_avg_bike_vel = avg_vel
	var local_vel_delta = drone.global_transform.basis.inverse() * vel_delta
	obs.append(clamp(local_vel_delta.x / 2.0, -1.0, 1.0))
	obs.append(clamp(local_vel_delta.z / 2.0, -1.0, 1.0))

	return {"obs": obs}

func _get_action_space_boids_rl() -> Dictionary:
	return {
		"centering_factor": {"size": 1, "action_type": "continuous"},
		"matching_factor": {"size": 1, "action_type": "continuous"},
	}

func _set_action_boids_rl(action) -> void:
	drone.set_tunable_parameters({
		"avoid_radius":     drone.avoid_radius,
		"avoid_factor":     drone.avoidfactor,
		"centering_factor": centering_factor_remap_action(action["centering_factor"][0]),
		"matching_factor":  matching_factor_remap_action(action["matching_factor"][0]),
	})

	var bikes = _boids_rl_assigned_bikes if not _boids_rl_assigned_bikes.is_empty() else drone.sensor_readings_bikes
	_update_cached_force(bikes)

# ─── Grouping RL ────────────────────────────────────────────────────────────────────

func _physics_process_grouping_rl() -> void:
	drone.read_sensor_by_distance()
	var all_clusters := drone._cluster_bikes(drone.sensor_readings_bikes)
	all_clusters.sort_custom(func(a, b): return drone.global_position.distance_squared_to(a.centroid) < drone.global_position.distance_squared_to(b.centroid))
	_grouping_rl_clusters = all_clusters.slice(0, 4)

	# #5: Re-snap selected cluster to the closest match in the freshly rebuilt list so
	# centroid comparisons in the obs and reward functions always reference a live cluster.
	if not _grouping_rl_selected_cluster.is_empty() and not _grouping_rl_clusters.is_empty():
		var prev = _grouping_rl_selected_cluster.centroid
		var best = _grouping_rl_clusters[0]
		var best_d = prev.distance_squared_to(best.centroid)
		for c in _grouping_rl_clusters.slice(1):
			var d = prev.distance_squared_to(c.centroid)
			if d < best_d:
				best_d = d
				best = c
		_grouping_rl_selected_cluster = best

	var world = drone.get_parent()

	if drone.sensor_readings_bikes.is_empty():
		reward -= 0.5
		# Only the first drone checks the collective condition to avoid multiple resets.
		if world.is_training and drone == world.drone_list[0]:
			var any_has_bikes := false
			for d in world.drone_list:
				if not d.sensor_readings_bikes.is_empty():
					any_has_bikes = true
					break
			if not any_has_bikes:
				done = true
				needs_reset = true
		return

	_draw_debug_grouping_rl()
	if not _grouping_rl_selected_cluster.is_empty():
		_compute_reward_grouping_rl()

func _compute_reward_grouping_rl() -> void:
	if _grouping_rl_selected_cluster.is_empty() or _grouping_rl_clusters.is_empty():
		reward -= 0.1
		return

	var self_dist := drone.global_position.distance_to(_grouping_rl_selected_cluster.centroid)

	# #1: Shaped approach reward — penalty scales with distance outside coverage_radius,
	# providing a gradient that guides the drone toward the cluster.
	if self_dist >= drone.coverage_radius:
		var dist_ratio := self_dist / drone.coverage_radius
		reward -= clamp(dist_ratio, 1.0, 3.0) * 0.05
		return

	var drones_on := 0
	for reading in drone.sensor_readings_drones:
		if reading.position.distance_to(_grouping_rl_selected_cluster.centroid) < drone.coverage_radius:
			drones_on += 1

	# #2: Cluster-size-weighted reward that goes negative when over-staffed.
	# Sign flips at drones_on == 1: first drone is wanted (+size_weight), second is
	# neutral (0), third+ is actively repelled (-size_weight per extra drone).
	# The over-staffing penalty exceeds the transit penalty (max -0.15/step), so
	# excess drones always have a net incentive to leave and find an uncovered cluster.
	var total_bikes := float(max(1, drone.sensor_readings_bikes.size()))
	var size_weight := float(_grouping_rl_selected_cluster.size) / total_bikes
	reward += size_weight * (1.0 - float(drones_on))

# 20 observations for grouping rl (local allocation state):
#   4 clusters × 5 features (exists, bike_count, drones_on, under_coverage, distance)
#
# Raw bike counts and drone counts are exposed — no _coverage_score heuristic baked in —
# so the agent learns the optimal staffing ratio from experience.
func _get_obs_grouping_rl() -> Dictionary:
	var obs: Array = []

	var max_bikes := float(max(1, drone.sensor_readings_bikes.size()))
	var max_drones := float(max(1, drone.sensor_readings_drones.size() + 1))

	for i in 4:
		if i < _grouping_rl_clusters.size():
			var c = _grouping_rl_clusters[i]
			var self_dist := drone.global_position.distance_to(c.centroid)

			var drones_on := 0
			for reading in drone.sensor_readings_drones:
				if reading.position.distance_to(c.centroid) < drone.coverage_radius:
					drones_on += 1
			if not _grouping_rl_selected_cluster.is_empty() and \
					_grouping_rl_selected_cluster.centroid == c.centroid:
				drones_on += 1

			obs.append(1.0)                                                             # exists
			obs.append(clamp(float(c.size) / max_bikes, 0.0, 1.0))                     # bike count (relative to visible bikes)
			obs.append(clamp(float(drones_on) / max_drones, 0.0, 1.0))                 # drone staffing
			obs.append(clamp((float(c.size) - float(drones_on)) / max_bikes, 0.0, 1.0)) # under-coverage (bikes not yet matched by a drone)
			obs.append(clamp(self_dist / 30.0, 0.0, 1.0))                              # distance to cluster
		else:
			for _j in 5:
				obs.append(0.0)

	return {"obs": obs}

func _get_action_space_grouping_rl() -> Dictionary:
	# 4 scores, one per cluster slot. Argmax picks which cluster to follow.
	return {
		"cluster_scores": {"size": 4, "action_type": "continuous"},
	}


func _set_action_grouping_rl(action) -> void:
	if _grouping_rl_clusters.is_empty():
		return

	# Argmax over the 4 score outputs
	var scores = action["cluster_scores"]
	var best_idx = 0
	var best_score = -INF
	for i in scores.size():
		if scores[i] > best_score:
			best_score = scores[i]
			best_idx = i

	if best_idx >= _grouping_rl_clusters.size():
		_grouping_rl_selected_cluster = {}
		return

	_grouping_rl_selected_cluster = _grouping_rl_clusters[best_idx]
	_update_cached_force(_grouping_rl_selected_cluster.bikes)

# ─── Grouping + BoidsRl ──────────────────────────────────────────────────────────────────

func _set_action_grouping_boids_rl(action) -> void:
	if _grouping_rl_clusters.is_empty():
		print("No clusters available — cannot set action")
		return

	var scores = action["cluster_scores"]
	var best_idx = 0
	var best_score = -INF
	for i in scores.size():
		if scores[i] > best_score:
			best_score = scores[i]
			best_idx = i

	if best_idx >= _grouping_rl_clusters.size():
		_grouping_rl_selected_cluster = {}
		return

	_grouping_rl_selected_cluster = _grouping_rl_clusters[best_idx]

	assert(_boids_rl_model != null, "GroupingBoidsRl requires a BoidsRl ONNX model — set boids_rl_model_path")

	var boids_obs = _get_obs_boids_rl(drone.sensor_readings_bikes, drone._filter_camera(drone.sensor_readings_bikes), drone.sensor_readings_drones)
	var result = _boids_rl_model.run_inference(boids_obs["obs"], 1)
	var output = result["output"]
	drone.set_tunable_parameters({
		"avoid_radius":     avoid_radius_remap_action(output[0]),
		"avoid_factor":     avoid_factor_remap_action(output[1]),
		"centering_factor": centering_factor_remap_action(output[2]),
		"matching_factor":  matching_factor_remap_action(output[3]),
	})

	_update_cached_force(_grouping_rl_selected_cluster.bikes)

# ─── Helpers ──────────────────────────────────────────────────────────────────

func _update_cached_force(bikes: Array) -> void:
	var alignment_vector = drone.alignment(bikes)
	var cohesion_vector = drone.cohesion(bikes)
	var separation_vector = drone.separation_fast()

	var direction = alignment_vector + cohesion_vector + separation_vector
	direction.y = drone.height_force(bikes)

	drone._cached_force = drone.clamp_vector(direction, drone.max_force)
	drone._cached_rotation_dir = -alignment_vector

func avoid_radius_remap_action(action):
	return _remap_action(action,     5.0, 12.0)

func avoid_factor_remap_action(action):
	return _remap_action(action,     1.0, 6.0)

func centering_factor_remap_action(action):
	return _remap_action(action, 1, 10.0)

func matching_factor_remap_action(action):
	return _remap_action(action, 0.0, 1.0)

# Remap a value from the RL output range [-1, 1] to [low, high].
func _remap_action(value: float, low: float, high: float) -> float:
	return low + (value + 1.0) * 0.5 * (high - low)
	
func closest_bike() -> Dictionary:
	var closest_bike_data = null
	var closest_distance = INF

	for bike_data in drone.camera_readings:
		var distance = bike_data["distance"]
		if distance < closest_distance:
			closest_distance = distance
			closest_bike_data = bike_data

	return closest_bike_data


# ─── Debug ────────────────────────────────────────────────────────────────────

func _draw_debug_grouping_rl() -> void:
	if not drone.debug_draw:
		return

	while _grouping_rl_cluster_dots.size() < _grouping_rl_clusters.size():
		var dot = drone._make_cluster_dot()
		drone.get_parent().add_child.call_deferred(dot)
		_grouping_rl_cluster_dots.append(dot)

	for i in _grouping_rl_clusters.size():
		var dot: MeshInstance3D = _grouping_rl_cluster_dots[i]
		var is_selected = not _grouping_rl_selected_cluster.is_empty() and \
			_grouping_rl_selected_cluster.centroid == _grouping_rl_clusters[i].centroid
		(dot.material_override as StandardMaterial3D).albedo_color = \
			Color.GREEN if is_selected else Color.ORANGE
		if dot.is_inside_tree():
			dot.global_position = _grouping_rl_clusters[i].centroid
		dot.visible = true

	for i in range(_grouping_rl_clusters.size(), _grouping_rl_cluster_dots.size()):
		_grouping_rl_cluster_dots[i].visible = false

	if _grouping_rl_selected_line == null:
		_grouping_rl_selected_line = drone.make_debug_line()
		drone.get_parent().add_child.call_deferred(_grouping_rl_selected_line)
	if not _grouping_rl_selected_cluster.is_empty():
		drone.place_debug_line(
			_grouping_rl_selected_line,
			drone.global_position,
			_grouping_rl_selected_cluster.centroid,
			Color.GREEN
		)
	else:
		_grouping_rl_selected_line.visible = false

func _draw_debug_lines() -> void:
	if not drone.debug_draw:
		return
	var bikes = drone.camera_readings
	while _debug_lines.size() < bikes.size():
		var mi = drone.make_debug_line()
		drone.get_parent().add_child.call_deferred(mi)
		_debug_lines.append(mi)
	for i in bikes.size():
		var color := Color.YELLOW
		drone.place_debug_line(_debug_lines[i], drone.global_position, bikes[i]["position"], color)
	for i in range(bikes.size(), _debug_lines.size()):
		_debug_lines[i].visible = false
	if _debug_force_line == null:
		_debug_force_line = drone.make_debug_line()
		drone.get_parent().add_child.call_deferred(_debug_force_line)
	drone.place_debug_line(_debug_force_line, drone.global_position,
		drone.global_position + _last_force / drone.max_force * 5.0, Color.RED)
	if _debug_torque_line == null:
		_debug_torque_line = drone.make_debug_line()
		drone.get_parent().add_child.call_deferred(_debug_torque_line)
	drone.place_debug_line(_debug_torque_line, drone.global_position,
		drone.global_position + Vector3.UP * _last_torque * 5.0, Color.BLUE, Vector3.FORWARD)
