extends AIController3D

enum Version { BoidsRl, GroupingRl, GroupingBoidsRl }

@export var rl_version: Version = Version.BoidsRl
@export var no_bike_reset_steps: int = 500
# Boids RL filming reward parameters
@export var optimal_film_dist: float = 10.0   # ideal horizontal distance to bike centroid (metres)
@export var film_dist_tolerance: float = 5.0  # half-width of the reward tent (metres)
# GroupingBoidsRl: path to a trained BoidsRl ONNX model used for low-level movement
@export var boids_rl_model_path: String = ""

@onready var drone: Drone = $".."

var _boids_rl_model: ONNXModel = null
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

# ─── RL setup ────────────────────────────────────────────────────────────────────

func _ready():
	if not get_parent().IsRl:
		control_mode = ControlModes.HUMAN
		return
	super._ready()
	print("RL drone ready with version ", rl_version)

	if rl_version == Version.GroupingBoidsRl and boids_rl_model_path != "":
		_boids_rl_model = ONNXModel.new(boids_rl_model_path, 1)

func _physics_process(_delta):
	if not get_parent().IsRl:
		return
	if needs_reset:
		reset()
		return

	var world = drone.get_parent()
	if shared.BikeLists[world.InstanceId].is_empty():
		done = true
		needs_reset = true
		return

	if rl_version == Version.GroupingRl or rl_version == Version.GroupingBoidsRl:
		_physics_process_grouping_rl()
		return

	if rl_version == Version.BoidsRl:
		_physics_process_boids_rl(world)
		return

func get_obs() -> Dictionary:
	match rl_version:
		Version.BoidsRl: return _get_obs_boids_rl()
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
		world.ResetTrackAndBikeAndDrone()

		# Randomize bikes to create different grouping scenarios for the agent to learn from.
		var random_bike_values = Bike.GetRandomizeForRl()
		for bike in shared.BikeLists[world.InstanceId]:
			bike.SetRandomizeForRl(random_bike_values)
	else:
		# close the program
		get_tree().quit()

# ─── Boids RL ────────────────────────────────────────────────────────────────────

func _physics_process_boids_rl(world) -> void:
	drone.ReadSensor(drone.DroneSensor.DroneSet, drone.DroneSensor.BikeSet)

	if drone.SensorReadingsBikes.is_empty():
		reward -= 0.5
		# Only the first drone checks the collective condition to avoid multiple resets.
		if world.is_training and drone == world.DroneList[0]:
			var any_has_bikes := false
			for d in world.DroneList:
				if not d.SensorReadingsBikes.is_empty():
					any_has_bikes = true
					break
			if not any_has_bikes:
				done = true
				needs_reset = true

	_draw_debug_lines()
	_compute_reward_boids_rl()


func _compute_reward_boids_rl() -> void:

	for reading in drone.SensorReadingsDrones:
		if reading.distance < drone.avoid_radius:
			var proximity = 1.0 - (reading.distance / drone.avoid_radius)
			reward -= proximity * 2.0

	var nearby_count = drone.SensorReadingsBikes.size()
	if nearby_count == 0:
		return

	var bikes_in_camera = drone.CameraReadings
	var visible_count = bikes_in_camera.size()

	# Primary: fraction of locally sensed bikes that are in frame.
	var coverage = float(visible_count) / float(nearby_count)
	reward += coverage

	if visible_count > 0:
		var camera = drone.GetCameraNode()
		var cam_inv = camera.global_transform.basis.inverse()
		var centroid_cam = Vector2.ZERO

		for bike_data in drone.CameraReadings:
			var to_bike = cam_inv * (bike_data["position"] - camera.global_position)
			var fwd = -to_bike.z
			if fwd > 0.01:
				centroid_cam.x += clamp(to_bike.x / fwd, -1.0, 1.0)
				centroid_cam.y += clamp(to_bike.y / fwd, -1.0, 1.0)

		centroid_cam /= float(visible_count)
		reward += (1.0 - clamp(centroid_cam.length(), 0.0, 1.0)) * 0.3

	# Bonus when all locally sensed bikes are in frame.
	if visible_count == nearby_count:
		reward += 0.5

	# Centroid of locally sensed bikes (sensor sphere, not global list).
	var bike_centroid = Vector3.ZERO
	for reading in drone.SensorReadingsBikes:
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

# 16 observations for boids rl (camera-coverage / boids parameter tuning):
#   coverage (1), centroid_cam xy (2), full_coverage flag (1),
#   dist_error (1), camera_facing (1),
#   avg_bike_vel xz in drone-local frame (2), bike_spread (1), bike_count_norm (1),
#   nearest_drone (1), drones_in_sep_zone (1), own velocity xyz (3), drone_count_norm (1)
func _get_obs_boids_rl() -> Dictionary:
	var nearby_count = drone.SensorReadingsBikes.size()
	var obs: Array = []

	if nearby_count == 0:
		for _i in 16:
			obs.append(0.0)
		return {"obs": obs}

	# --- Camera coverage ---
	var bikes_in_camera = drone.CameraReadings
	var visible_count = bikes_in_camera.size()
	obs.append(float(visible_count) / float(nearby_count))

	var camera = drone.GetCameraNode()
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
	for reading in drone.SensorReadingsBikes:
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
	var avg_vel := Vector3.ZERO
	for reading in drone.SensorReadingsBikes:
		avg_vel += reading.velocity
	avg_vel /= float(nearby_count)
	var local_avg_vel = drone.global_transform.basis.inverse() * avg_vel
	obs.append(clamp(local_avg_vel.x / 22.0, -1.0, 1.0))
	obs.append(clamp(local_avg_vel.z / 22.0, -1.0, 1.0))

	var spread := 0.0
	for reading in drone.SensorReadingsBikes:
		var flat := Vector2(reading.position.x - bike_centroid.x, reading.position.z - bike_centroid.z)
		spread += flat.length()
	spread /= float(nearby_count)
	obs.append(clamp(spread / 30.0, 0.0, 1.0))

	obs.append(clamp(float(nearby_count) / 8.0, 0.0, 1.0))

	# --- Drone separation ---
	var nearest_dist_norm = 1.0
	var in_zone = 0
	for reading in drone.SensorReadingsDrones:
		var d_norm = reading.distance / (drone.avoid_radius * 2.0)
		if d_norm < nearest_dist_norm:
			nearest_dist_norm = d_norm
		if reading.distance < drone.avoid_radius:
			in_zone += 1
	obs.append(clamp(nearest_dist_norm, 0.0, 1.0))
	obs.append(clamp(float(in_zone) / 5.0, 0.0, 1.0))

	# --- Own velocity in drone-local frame ---
	var local_vel = drone.global_transform.basis.inverse() * drone.linear_velocity
	obs.append(clamp(local_vel.x / 15.0, -1.0, 1.0))
	obs.append(clamp(local_vel.y / 15.0, -1.0, 1.0))
	obs.append(clamp(local_vel.z / 15.0, -1.0, 1.0))

	obs.append(clamp(float(drone.SensorReadingsDrones.size()) / 10.0, 0.0, 1.0))

	return {"obs": obs}

func _get_action_space_boids_rl() -> Dictionary:

	return {
		"avoid_radius": {"size": 1, "action_type": "continuous"},
		"avoid_factor": {"size": 1, "action_type": "continuous"},
		"centering_factor": {"size": 1, "action_type": "continuous"},
		"matching_factor": {"size": 1, "action_type": "continuous"},
	}

func _set_action_boids_rl(action) -> void:
	drone.SetTunableParameters({
		"avoid_radius":     _remap_action(action["avoid_radius"][0],     1.0, 8.0),
		"avoid_factor":     _remap_action(action["avoid_factor"][0],     1.0, 20.0),
		"centering_factor": _remap_action(action["centering_factor"][0], 0.1,  5.0),
		"matching_factor":  _remap_action(action["matching_factor"][0],  0.01, 1.0),
	})

	drone.BoidsBikes(drone.SensorReadingsBikes)

# ─── Grouping RL ────────────────────────────────────────────────────────────────────

func _physics_process_grouping_rl() -> void:
	drone.ReadSensor(drone.DroneSensor.DroneSet, drone.DroneSensor.BikeSet)
	_grouping_rl_clusters = drone.ClusterBikes(drone.SensorReadingsBikes)

	if _grouping_rl_clusters.is_empty():
		reward -= 0.5
		return

	_draw_debug_grouping_rl()
	if not _grouping_rl_selected_cluster.is_empty():
		_compute_reward_grouping_rl()

func _compute_reward_grouping_rl() -> void:
	var total_covered := 0.0
	var max_coverable := 0.0

	for cluster in _grouping_rl_clusters:
		var score = drone.CoverageScore(cluster.size)
		max_coverable += float(score)

		var self_dist := drone.global_position.distance_to(cluster.centroid)
		var drones_on := 0
		for reading in drone.SensorReadingsDrones:
			var d = reading.position.distance_to(cluster.centroid)
			if d < self_dist or d < drone.coverage_radius:
				drones_on += 1

		if not _grouping_rl_selected_cluster.is_empty() and \
				_grouping_rl_selected_cluster.centroid == cluster.centroid:
			drones_on += 1

		total_covered += minf(float(drones_on), float(score))

	if max_coverable > 0.0:
		reward += total_covered / max_coverable

func _get_obs_grouping_rl() -> Dictionary:
	var obs: Array = []

	var max_score := float(max(1, drone.CoverageScore(
		max(1, drone.SensorReadingsBikes.size())
	)))
	var max_drones := float(max(1, drone.SensorReadingsDrones.size() + 1))

	for i in 4:
		if i < _grouping_rl_clusters.size():
			var c = _grouping_rl_clusters[i]
			var score := float(drone.CoverageScore(c.size))
			var self_dist := drone.global_position.distance_to(c.centroid)

			var drones_on := 0
			for reading in drone.SensorReadingsDrones:
				var d = reading.position.distance_to(c.centroid)
				if d < self_dist or d < drone.coverage_radius:
					drones_on += 1
			if not _grouping_rl_selected_cluster.is_empty() and \
					_grouping_rl_selected_cluster.centroid == c.centroid:
				drones_on += 1

			obs.append(1.0)
			obs.append(clamp(score / max_score, 0.0, 1.0))
			obs.append(clamp(float(drones_on) / max_drones, 0.0, 1.0))
			obs.append(clamp((score - float(drones_on)) / max_score, -1.0, 1.0))
			obs.append(clamp(self_dist / 30.0, 0.0, 1.0))
		else:
			for _j in 5:
				obs.append(0.0)

	return {"obs": obs}

func _get_action_space_grouping_rl() -> Dictionary:
	return {
		"cluster_scores": {"size": 4, "action_type": "continuous"},
	}


func _set_action_grouping_rl(action) -> void:
	if _grouping_rl_clusters.is_empty():
		return

	var scores = action["cluster_scores"]
	var best_idx = 0
	var best_score = -INF
	for i in min(scores.size(), _grouping_rl_clusters.size()):
		if scores[i] > best_score:
			best_score = scores[i]
			best_idx = i

	_grouping_rl_selected_cluster = _grouping_rl_clusters[best_idx]

	drone.BoidsBikes(_grouping_rl_selected_cluster.bikes)

# ─── Grouping + BoidsRl ──────────────────────────────────────────────────────────────────

func _set_action_grouping_boids_rl(action) -> void:
	if _grouping_rl_clusters.is_empty():
		return

	var scores = action["cluster_scores"]
	var best_idx = 0
	var best_score = -INF
	for i in min(scores.size(), _grouping_rl_clusters.size()):
		if scores[i] > best_score:
			best_score = scores[i]
			best_idx = i
	_grouping_rl_selected_cluster = _grouping_rl_clusters[best_idx]

	assert(_boids_rl_model != null, "GroupingBoidsRl requires a BoidsRl ONNX model — set boids_rl_model_path")

	var boids_obs = _get_obs_boids_rl()
	var result = _boids_rl_model.run_inference(boids_obs["obs"], 1)
	var output = result["output"]
	drone.SetTunableParameters({
		"avoid_radius":     _remap_action(output[0], 1.0, 8.0),
		"avoid_factor":     _remap_action(output[1], 1.0, 20.0),
		"centering_factor": _remap_action(output[2], 0.1,  5.0),
		"matching_factor":  _remap_action(output[3], 0.01, 1.0),
	})

	drone.BoidsBikes(_grouping_rl_selected_cluster.bikes)

# ─── Helpers ──────────────────────────────────────────────────────────────────

func _remap_action(value: float, low: float, high: float) -> float:
	return low + (value + 1.0) * 0.5 * (high - low)

func closest_bike() -> Dictionary:
	var closest_bike_data = null
	var closest_distance = INF

	for bike_data in drone.CameraReadings:
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
		var dot = drone.MakeClusterDot()
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
		_grouping_rl_selected_line = drone.MakeDebugLine()
		drone.get_parent().add_child.call_deferred(_grouping_rl_selected_line)
	if not _grouping_rl_selected_cluster.is_empty():
		drone.PlaceDebugLine(
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
	var bikes = drone.CameraReadings
	while _debug_lines.size() < bikes.size():
		var mi = drone.MakeDebugLine()
		drone.get_parent().add_child.call_deferred(mi)
		_debug_lines.append(mi)
	for i in bikes.size():
		var color := Color.YELLOW
		drone.PlaceDebugLine(_debug_lines[i], drone.global_position, bikes[i]["position"], color)
	for i in range(bikes.size(), _debug_lines.size()):
		_debug_lines[i].visible = false
	if _debug_force_line == null:
		_debug_force_line = drone.MakeDebugLine()
		drone.get_parent().add_child.call_deferred(_debug_force_line)
	drone.PlaceDebugLine(_debug_force_line, drone.global_position,
		drone.global_position + _last_force / drone.max_force * 5.0, Color.RED)
	if _debug_torque_line == null:
		_debug_torque_line = drone.MakeDebugLine()
		drone.get_parent().add_child.call_deferred(_debug_torque_line)
	drone.PlaceDebugLine(_debug_torque_line, drone.global_position,
		drone.global_position + Vector3.UP * _last_torque * 5.0, Color.BLUE, Vector3.FORWARD)
