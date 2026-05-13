extends AIController3D

enum Version { V1, BoidsRl, GroupingRl, GroupingBoidsRl }

@export var rl_version: Version = Version.V1
@export var no_bike_reset_steps: int = 500
# Boids RL filming reward parameters
@export var optimal_film_dist: float = 10.0   # ideal horizontal distance to bike centroid (metres)
@export var film_dist_tolerance: float = 5.0  # half-width of the reward tent (metres)
# GroupingBoidsRl: path to a trained BoidsRl ONNX model used for low-level movement
@export var boids_rl_model_path: String = ""

@onready var drone: RigidBody3D = $".."

var _steps_without_bike: int = 0
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
	if needs_reset:
		reset()
		return

	var world = drone.get_parent()
	if shared.bike_lists[world.instance_id].is_empty():
		done = true
		needs_reset = true
		return

	if rl_version == Version.GroupingRl or rl_version == Version.GroupingBoidsRl:
		_physics_process_grouping_rl(world)
		return

	if rl_version == Version.BoidsRl:
		_physics_process_boids_rl(world)
		return

	drone.target_bike = _get_target_bike()
	_draw_debug_lines()

	if drone.target_bike == null:
		_steps_without_bike += 1
		reward -= 0.5
		if _steps_without_bike >= no_bike_reset_steps and world.is_training:
			done = true
			needs_reset = true
		return

	_steps_without_bike = 0

	_compute_reward_v1()

func get_obs() -> Dictionary:
	match rl_version:
		Version.V1: return _get_obs_v1()
		Version.BoidsRl: return _get_obs_boids_rl()
		Version.GroupingRl: return _get_obs_grouping_rl()
		Version.GroupingBoidsRl: return _get_obs_grouping_rl()
	return {}

func get_action_space() -> Dictionary:
	match rl_version:
		Version.V1: return _get_action_space_v1()
		Version.BoidsRl: return _get_action_space_boids_rl()
		Version.GroupingRl: return _get_action_space_grouping_rl()
		Version.GroupingBoidsRl: return _get_action_space_grouping_rl()
	return {}

func set_action(action) -> void:
	match rl_version:
		Version.V1: _set_action_v1(action)
		Version.BoidsRl: _set_action_boids_rl(action)
		Version.GroupingRl: _set_action_grouping_rl(action)
		Version.GroupingBoidsRl: _set_action_grouping_boids_rl(action)


func get_reward() -> float:
	return reward


func reset():
	super.reset()
	drone.linear_velocity = Vector3.ZERO
	drone.angular_velocity = Vector3.ZERO
	drone.target_bike = null
	drone.target_position = null
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

# ─── V1 ────────────────────────────────────────────────────────────────────

func _compute_reward_v1() -> void:
	var bike_forward = -drone.target_bike.global_transform.basis.z
	bike_forward.y = 0.0
	bike_forward = bike_forward.normalized()
	var desired_pos = drone.target_bike.global_position - bike_forward * drone.behind_distance
	desired_pos.y = drone.target_bike.global_position.y + drone.height_offset

	var pos_error = drone.global_position.distance_to(desired_pos)
	reward += 1.0 / (1.0 + pos_error)

	var drone_fwd_speed = drone.linear_velocity.dot(bike_forward)
	var speed_diff = abs(drone_fwd_speed - drone.target_bike.speed)
	reward -= speed_diff * 0.03

	var cam_forward = -drone.target_bike.get_camera_node().global_transform.basis.z
	var to_bike = (drone.target_bike.global_position - drone.global_position).normalized()
	reward += maxf(0.0, cam_forward.dot(to_bike)) * 0.2

func _get_obs_v1() -> Dictionary:
	var bikes_in_camera = drone.get_node("Camera_detection").bike_set
	var camera = drone.get_camera_node()

	var closest_bike_pos = Vector3.ZERO
	var closest_distance = INF
	var bike_speed = 0.0
	var bike_direction_local = Vector2.ZERO
	var cam_offset = Vector2.ZERO

	for bike in bikes_in_camera:
		var pos = drone.to_local(bikes_in_camera[bike].global_position)
		var distance = pos.length()
		if distance < closest_distance:
			closest_distance = distance
			closest_bike_pos = pos
			bike_speed = bikes_in_camera[bike].get_parent().speed

			var world_dir = -bikes_in_camera[bike].get_parent().global_transform.basis.z
			var local_dir = drone.global_transform.basis.inverse() * world_dir
			bike_direction_local = Vector2(local_dir.x, local_dir.z).normalized()

			var to_bike_cam = camera.global_transform.basis.inverse() * (
				bikes_in_camera[bike].global_position - camera.global_position
			)
			var forward = -to_bike_cam.z
			if forward > 0.01:
				cam_offset.x = clamp(to_bike_cam.x / forward, -1.0, 1.0)
				cam_offset.y = clamp(to_bike_cam.y / forward, -1.0, 1.0)

	var local_velocity = drone.global_transform.basis.inverse() * drone.linear_velocity

	closest_bike_pos = closest_bike_pos / sqrt(pow(26.0, 2) + pow(5.0, 2))
	bike_speed = bike_speed / 22.0
	local_velocity = local_velocity / 15.0

	return {"obs": [
		1.0 if bikes_in_camera.size() > 0 else 0.0,
		closest_bike_pos.x,
		closest_bike_pos.y,
		closest_bike_pos.z,
		bike_speed,
		bike_direction_local.x,
		bike_direction_local.y,
		local_velocity.x,
		local_velocity.y,
		local_velocity.z,
		cam_offset.x,
		cam_offset.y,
	]}

func _get_action_space_v1() -> Dictionary:
	return {
		"thrust": {"size": 3, "action_type": "continuous"},
		"torque":  {"size": 1, "action_type": "continuous"},
	}


func _set_action_v1(action) -> void:
	var thrust = action["thrust"]
	var torque = action["torque"][0]
	_last_force = drone.global_transform.basis * Vector3(thrust[0], thrust[1], thrust[2]) * drone.max_force
	_last_torque = clamp(torque, -1.0, 1.0)
	drone.apply_central_force(_last_force)
	drone.apply_torque(drone.global_transform.basis.y * _last_torque * drone.max_torque)

# ─── Boids RL ────────────────────────────────────────────────────────────────────

func _physics_process_boids_rl(world) -> void:
	drone.read_sensor(drone.drone_sensor.drone_set, drone.drone_sensor.bike_set)

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

	drone.target_bike = _get_target_bike()
	_draw_debug_lines()

	if drone.target_bike == null:
		reward -= 0.5

	_compute_reward_boids_rl()

func _compute_reward_boids_rl() -> void:

	for reading in drone.sensor_readings_drones:
		if reading.distance < drone.avoid_radius:
			var proximity = 1.0 - (reading.distance / drone.avoid_radius)
			reward -= proximity * 2.0

	var nearby_count = drone.sensor_readings_bikes.size()
	if nearby_count == 0:
		return

	var bikes_in_camera = drone.drone_detector.bike_set
	var visible_count = bikes_in_camera.size()

	# Primary: fraction of locally sensed bikes that are in frame.
	var coverage = float(visible_count) / float(nearby_count)
	reward += coverage

	if visible_count > 0:
		var camera = drone.get_camera_node()
		var cam_inv = camera.global_transform.basis.inverse()
		var centroid_cam = Vector2.ZERO

		for bike_body in bikes_in_camera.values():
			var to_bike = cam_inv * (bike_body.global_position - camera.global_position)
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
	for reading in drone.sensor_readings_bikes:
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
	var nearby_count = drone.sensor_readings_bikes.size()
	var obs: Array = []

	if nearby_count == 0:
		for _i in 16:
			obs.append(0.0)
		return {"obs": obs}

	# --- Camera coverage ---
	var bikes_in_camera = drone.drone_detector.bike_set
	var visible_count = bikes_in_camera.size()
	obs.append(float(visible_count) / float(nearby_count))

	var camera = drone.get_camera_node()
	var cam_inv = camera.global_transform.basis.inverse()
	var centroid_cam = Vector2.ZERO
	if visible_count > 0:
		for bike_body in bikes_in_camera.values():
			var to_bike = cam_inv * (bike_body.global_position - camera.global_position)
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
	for reading in drone.sensor_readings_bikes:
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
	for reading in drone.sensor_readings_bikes:
		avg_vel += reading.velocity
	avg_vel /= float(nearby_count)
	var local_avg_vel = drone.global_transform.basis.inverse() * avg_vel
	obs.append(clamp(local_avg_vel.x / 22.0, -1.0, 1.0))
	obs.append(clamp(local_avg_vel.z / 22.0, -1.0, 1.0))

	# Bike spread: average distance from group centroid, normalised by sensor radius.
	# High spread → centering_factor should increase to pull drones toward the group.
	var spread := 0.0
	for reading in drone.sensor_readings_bikes:
		var flat := Vector2(reading.position.x - bike_centroid.x, reading.position.z - bike_centroid.z)
		spread += flat.length()
	spread /= float(nearby_count)
	obs.append(clamp(spread / 30.0, 0.0, 1.0))

	# How many bikes are nearby, normalised by sensor capacity (max_bike_count = 8).
	obs.append(clamp(float(nearby_count) / 8.0, 0.0, 1.0))

	# --- Drone separation ---
	var nearest_dist_norm = 1.0
	var in_zone = 0
	for reading in drone.sensor_readings_drones:
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

	# How many other drones are nearby, normalised by drone_count export.
	obs.append(clamp(float(drone.sensor_readings_drones.size()) / 10.0, 0.0, 1.0))

	return {"obs": obs}

func _get_action_space_boids_rl() -> Dictionary:

	return {
		"avoid_radius": {"size": 1, "action_type": "continuous"},
		"avoid_factor": {"size": 1, "action_type": "continuous"},
		"centering_factor": {"size": 1, "action_type": "continuous"},
		"matching_factor": {"size": 1, "action_type": "continuous"},
	}

func _set_action_boids_rl(action) -> void:
	drone.set_tunable_parameters({
		"avoid_radius":     _remap_action(action["avoid_radius"][0],     1.0, 8.0),
		"avoid_factor":     _remap_action(action["avoid_factor"][0],     1.0, 20.0),
		"centering_factor": _remap_action(action["centering_factor"][0], 0.1,  5.0),
		"matching_factor":  _remap_action(action["matching_factor"][0],  0.01, 1.0),
	})

	drone.boids_bikes(drone.sensor_readings_bikes)

# ─── Grouping RL ────────────────────────────────────────────────────────────────────

func _physics_process_grouping_rl(world) -> void:
	drone.read_sensor(drone.drone_sensor.drone_set, drone.drone_sensor.bike_set)
	_grouping_rl_clusters = drone._cluster_bikes(drone.sensor_readings_bikes)

	if _grouping_rl_clusters.is_empty():
		reward -= 0.5
		return

	_draw_debug_grouping_rl()
	if not _grouping_rl_selected_cluster.is_empty():
		_compute_reward_grouping_rl()

func _compute_reward_grouping_rl() -> void:
	# Global coverage reward: how well the visible fleet collectively covers all
	# clusters. Each cluster contributes min(drones_on_cluster, coverage_score)
	# so the agent learns to spread the fleet — not stack on one cluster.
	var total_covered := 0.0
	var max_coverable := 0.0

	for cluster in _grouping_rl_clusters:
		var score = drone._coverage_score(cluster.size)
		max_coverable += float(score)

		# Count drones covering this cluster (closer than self or within coverage_radius).
		var self_dist := drone.global_position.distance_to(cluster.centroid)
		var drones_on := 0
		for reading in drone.sensor_readings_drones:
			var d = reading.position.distance_to(cluster.centroid)
			if d < self_dist or d < drone.coverage_radius:
				drones_on += 1

		# Count self if this drone selected this cluster.
		if not _grouping_rl_selected_cluster.is_empty() and \
				_grouping_rl_selected_cluster.centroid == cluster.centroid:
			drones_on += 1

		# Reward coverage up to the score; excess drones add nothing.
		total_covered += minf(float(drones_on), float(score))

	if max_coverable > 0.0:
		reward += total_covered / max_coverable

# 20 observations for grouping rl (local allocation state):
#   4 clusters × 5 features (exists, coverage_score, drones_on, deficit, distance)
#
# All features are derived from this drone's own sensor sphere (30 m radius) —
# no fleet-wide aggregation. The policy must infer allocation quality from
# what it can locally observe, as in a real swarm.
func _get_obs_grouping_rl() -> Dictionary:
	var obs: Array = []

	# Max score possible = score if all visible bikes were in one cluster.
	var max_score := float(max(1, drone._coverage_score(
		max(1, drone.sensor_readings_bikes.size())
	)))
	# Max drones_on = all visible drones + self.
	var max_drones := float(max(1, drone.sensor_readings_drones.size() + 1))

	for i in 4:
		if i < _grouping_rl_clusters.size():
			var c = _grouping_rl_clusters[i]
			var score := float(drone._coverage_score(c.size))
			var self_dist := drone.global_position.distance_to(c.centroid)

			# Count nearby drones already covering this cluster.
			var drones_on := 0
			for reading in drone.sensor_readings_drones:
				var d = reading.position.distance_to(c.centroid)
				if d < self_dist or d < drone.coverage_radius:
					drones_on += 1
			# Count self if currently assigned here.
			if not _grouping_rl_selected_cluster.is_empty() and \
					_grouping_rl_selected_cluster.centroid == c.centroid:
				drones_on += 1

			obs.append(1.0)                                                          # exists
			obs.append(clamp(score / max_score, 0.0, 1.0))                          # need (relative to max visible)
			obs.append(clamp(float(drones_on) / max_drones, 0.0, 1.0))              # staffing (relative to visible fleet)
			obs.append(clamp((score - float(drones_on)) / max_score, -1.0, 1.0))    # deficit (+) or surplus (-)
			obs.append(clamp(self_dist / 30.0, 0.0, 1.0))                           # distance to cluster
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

	# Argmax over the 4 score outputs, restricted to valid cluster indices.
	var scores = action["cluster_scores"]
	var best_idx = 0
	var best_score = -INF
	for i in min(scores.size(), _grouping_rl_clusters.size()):
		if scores[i] > best_score:
			best_score = scores[i]
			best_idx = i

	_grouping_rl_selected_cluster = _grouping_rl_clusters[best_idx]

	drone.boids_bikes(_grouping_rl_selected_cluster.bikes)

# ─── Grouping + BoidsRl ──────────────────────────────────────────────────────────────────

func _set_action_grouping_boids_rl(action) -> void:
	if _grouping_rl_clusters.is_empty():
		return

	# Same cluster selection as GroupingRl.
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
	var result = _boids_rl_model.run_inference(boids_obs["obs"], 1.0)
	var output = result["output"]
	drone.set_tunable_parameters({
		"avoid_radius":     _remap_action(output[0], 1.0, 8.0),
		"avoid_factor":     _remap_action(output[1], 1.0, 20.0),
		"centering_factor": _remap_action(output[2], 0.1,  5.0),
		"matching_factor":  _remap_action(output[3], 0.01, 1.0),
	})

	drone.boids_bikes(_grouping_rl_selected_cluster.bikes)

# ─── Helpers ──────────────────────────────────────────────────────────────────

# Remap a value from the RL output range [-1, 1] to [low, high].
func _remap_action(value: float, low: float, high: float) -> float:
	return low + (value + 1.0) * 0.5 * (high - low)
	
func _get_desired_pos() -> Vector3:
	var bike_forward = -drone.target_bike.global_transform.basis.z
	bike_forward.y = 0
	bike_forward = bike_forward.normalized()
	var pos = drone.target_bike.global_position - bike_forward * drone.behind_distance
	pos.y = drone.target_bike.global_position.y + drone.height_offset
	return pos

func _get_target_bike() -> Bike:
	var world = drone.get_parent()
	var closest_bike: Bike = null
	var min_dist := INF
	for bike_body: Bike_body in drone.drone_detector.bike_set.values():
		var bike: Bike = bike_body.get_parent()
		if bike.get_parent().get_parent() != world:
			continue
		var dist = drone.global_position.distance_to(bike.global_position)
		if dist < min_dist:
			min_dist = dist
			closest_bike = bike
	return closest_bike

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
	var bikes = drone.drone_detector.bike_set.values()
	while _debug_lines.size() < bikes.size():
		var mi = drone.make_debug_line()
		drone.get_parent().add_child.call_deferred(mi)
		_debug_lines.append(mi)
	for i in bikes.size():
		var bike_body: Bike_body = bikes[i]
		var color := Color.GREEN if bike_body.get_parent() == drone.target_bike else Color.YELLOW
		drone.place_debug_line(_debug_lines[i], drone.global_position, bike_body.global_position, color)
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
