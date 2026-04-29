extends AIController3D

enum Version { V1, V2, V3, V4 }

@export var rl_version: Version = Version.V1
@export var no_bike_reset_steps: int = 500
# V2 filming reward parameters
@export var optimal_film_dist: float = 10.0   # ideal horizontal distance to bike centroid (metres)
@export var film_dist_tolerance: float = 5.0  # half-width of the reward tent (metres)

@onready var drone: RigidBody3D = $".."

var _steps_without_bike: int = 0
var _debug_lines: Array[MeshInstance3D] = []
var _debug_force_line: MeshInstance3D = null
var _debug_torque_line: MeshInstance3D = null
var _last_force: Vector3 = Vector3.ZERO
var _last_torque: float = 0.0

# V3/V4 cluster state (refreshed each physics step)
var _v3_clusters: Array = []
var _v3_assigned: Dictionary = {}

# V4 state: cluster selected by RL agent this step
var _v4_selected_cluster: Dictionary = {}
var _v4_cluster_dots: Array[MeshInstance3D] = []
var _v4_selected_line: MeshInstance3D = null

# ─── Lifecycle ────────────────────────────────────────────────────────────────

func _ready():
	if not get_parent().is_rl:
		control_mode = ControlModes.HUMAN
		return
	super._ready()
	print("RL drone ready with version ", rl_version)

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

	if rl_version == Version.V3:
		_physics_process_v3()
		return

	if rl_version == Version.V4:
		_physics_process_v4()
		return

	drone.target_bike = _get_target_bike()
	_draw_debug_lines()

	if drone.target_bike == null:
		_steps_without_bike += 1
		reward -= 0.5
		if _steps_without_bike >= no_bike_reset_steps:
			done = true
			needs_reset = true
		return

	_steps_without_bike = 0

	match rl_version:
		Version.V1: _compute_reward_v1()
		Version.V2: _compute_reward_v2()

# ─── Reward ───────────────────────────────────────────────────────────────────

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

func _compute_reward_v2() -> void:
	var world = drone.get_parent()
	var total_bikes = shared.bike_lists[world.instance_id].size()
	if total_bikes == 0:
		return

	var bikes_in_camera = drone.drone_detector.bike_set
	var visible_count = bikes_in_camera.size()

	# Primary: what fraction of all bikes are currently in frame.
	# Ranges 0–1 and provides a gradient even when no bikes are visible.
	var coverage = float(visible_count) / float(total_bikes)
	reward += coverage

	if visible_count > 0:
		# Centroid centering: compute where the center-of-mass of visible bikes
		# falls in camera space and reward keeping it near the cross-hair.
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
		# centroid_cam.length() is 0 when perfectly centered, up to ~1.4 at corners.
		# Scale to max 0.3 so centering is a secondary signal, not dominant.
		reward += (1.0 - clamp(centroid_cam.length(), 0.0, 1.0)) * 0.3

	# Flat bonus when every bike is in frame — encourages full-group coverage
	# rather than settling for a high-but-not-perfect fraction.
	if visible_count == total_bikes:
		reward += 0.5

	# ── Filming quality rewards (camera facing + distance) ───────────────────
	# Compute the horizontal centroid of all bikes.
	var bike_centroid = Vector3.ZERO
	for bike in shared.bike_lists[world.instance_id]:
		bike_centroid += bike.global_position
	bike_centroid /= float(total_bikes)

	var to_centroid = bike_centroid - drone.global_position
	to_centroid.y = 0.0

	# Camera facing: reward the drone's forward vector pointing at the centroid.
	# dot product ranges -1..1; scale to max ±0.3 so it is a secondary signal.
	if to_centroid.length() > 0.1:
		var drone_forward = -drone.global_transform.basis.z
		drone_forward.y = 0.0
		reward += drone_forward.normalized().dot(to_centroid.normalized()) * 0.3

	# Filming distance: tent reward centred on optimal_film_dist (default 10 m).
	# Gives +0.3 at the sweet spot, dropping linearly to 0 at ±film_dist_tolerance.
	var horiz_dist = to_centroid.length()
	var dist_reward = 1.0 - clamp(abs(horiz_dist - optimal_film_dist) / film_dist_tolerance, 0.0, 1.0)
	reward += dist_reward * 0.3

	# Collision penalty: penalise proximity to other drones.
	# Uses the same sensor data as the avoidance controller (avoid_radius = 3 m).
	# Penalty scales linearly from 0 at avoid_radius down to -2.0 at distance 0.
	for reading in drone.sensor_readings_drones:
		if reading.distance < drone.avoid_radius:
			var proximity = 1.0 - (reading.distance / drone.avoid_radius)
			reward -= proximity * 2.0

# ─── V3 (BoidsPriorityGroups) ─────────────────────────────────────────────────

func _physics_process_v3() -> void:
	drone.read_sensor(drone.drone_sensor.drone_set, drone.drone_sensor.bike_set)
	_v3_clusters = drone._cluster_bikes(drone.sensor_readings_bikes)
	_v3_assigned = drone._assigned_cluster(_v3_clusters)

	if _v3_assigned.get("size", 0) == 0:
		_steps_without_bike += 1
		reward -= 0.5
		if _steps_without_bike >= no_bike_reset_steps:
			done = true
			needs_reset = true
		return

	_steps_without_bike = 0
	_compute_reward_v3()

func _compute_reward_v3() -> void:
	var centroid: Vector3 = _v3_assigned.centroid

	# 1. Proximity to assigned cluster centroid (XZ plane)
	var xz_dist = Vector2(
		drone.global_position.x - centroid.x,
		drone.global_position.z - centroid.z
	).length()
	reward += 1.0 / (1.0 + xz_dist)

	# 2. Velocity matching with cluster
	var flat_vel = Vector3(drone.linear_velocity.x, 0.0, drone.linear_velocity.z)
	var speed_diff = (flat_vel - _v3_assigned.velocity).length()
	reward -= speed_diff * 0.03

	# 3. Overcrowding penalty: penalise if competing drones exceed coverage score
	var self_dist = drone.global_position.distance_to(centroid)
	var competing = 0
	for reading in drone.sensor_readings_drones:
		var d = reading.position.distance_to(centroid)
		if d < self_dist or d < drone.coverage_radius:
			competing += 1
	var surplus = competing - drone._coverage_score(_v3_assigned.size)
	reward -= maxf(0.0, float(surplus)) * 0.5

	# 4. Drone proximity penalty (same as V2)
	for reading in drone.sensor_readings_drones:
		if reading.distance < drone.avoid_radius:
			var proximity = 1.0 - (reading.distance / drone.avoid_radius)
			reward -= proximity * 2.0

	# 5. Height penalty: stay height_offset above cluster centroid
	var desired_y = centroid.y + drone.height_offset
	var y_error = abs(drone.global_position.y - desired_y)
	reward -= y_error * 0.1

# ─── V4 (RL cluster selection + boids navigation) ────────────────────────────
func _physics_process_v4() -> void:
	drone.read_sensor(drone.drone_sensor.drone_set, drone.drone_sensor.bike_set)
	_v3_clusters = drone._cluster_bikes(drone.sensor_readings_bikes)

	if _v3_clusters.is_empty():
		_steps_without_bike += 1
		reward -= 0.5
		if _steps_without_bike >= no_bike_reset_steps:
			done = true
			needs_reset = true
		return

	_steps_without_bike = 0

	_draw_debug_v4()
	if not _v4_selected_cluster.is_empty():
		_compute_reward_v4()

func _compute_reward_v4() -> void:
	# Global coverage reward: how well the visible fleet collectively covers all
	# clusters. Each cluster contributes min(drones_on_cluster, coverage_score)
	# so the agent learns to spread the fleet — not stack on one cluster.
	var total_covered := 0.0
	var max_coverable := 0.0

	for cluster in _v3_clusters:
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
		if not _v4_selected_cluster.is_empty() and \
				_v4_selected_cluster.centroid == cluster.centroid:
			drones_on += 1

		# Reward coverage up to the score; excess drones add nothing.
		total_covered += minf(float(drones_on), float(score))

	if max_coverable > 0.0:
		reward += total_covered / max_coverable

# ─── Observations ─────────────────────────────────────────────────────────────

func get_obs() -> Dictionary:
	match rl_version:
		Version.V1: return _get_obs_v1()
		Version.V2: return _get_obs_v2()
		Version.V3: return _get_obs_v3()
		Version.V4: return _get_obs_v4()
	return {}

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

# 11 observations for V2 (camera-coverage / boids parameter tuning):
#   coverage (1), centroid_cam xy (2), full_coverage flag (1),
#   dist_error (1), camera_facing (1),
#   nearest_drone (1), drones_in_sep_zone (1), own velocity xyz (3)
func _get_obs_v2() -> Dictionary:
	var world = drone.get_parent()
	var total_bikes = shared.bike_lists[world.instance_id].size()
	var obs: Array = []

	if total_bikes == 0:
		for _i in 11:
			obs.append(0.0)
		return {"obs": obs}

	# --- Camera coverage ---
	var bikes_in_camera = drone.drone_detector.bike_set
	var visible_count = bikes_in_camera.size()
	obs.append(float(visible_count) / float(total_bikes))

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
	obs.append(1.0 if visible_count == total_bikes else 0.0)

	# --- Spatial relationship to bike centroid ---
	var bike_centroid = Vector3.ZERO
	for bike in shared.bike_lists[world.instance_id]:
		bike_centroid += bike.global_position
	bike_centroid /= float(total_bikes)

	var to_centroid = bike_centroid - drone.global_position
	to_centroid.y = 0.0
	var horiz_dist = to_centroid.length()

	# Distance error: 0 at sweet spot, ±1 at tolerance boundary
	obs.append(clamp((horiz_dist - optimal_film_dist) / film_dist_tolerance, -1.0, 1.0))

	# Camera facing: +1 when pointing directly at centroid
	var drone_forward = -drone.global_transform.basis.z
	drone_forward.y = 0.0
	obs.append(drone_forward.normalized().dot(to_centroid.normalized()) if horiz_dist > 0.1 else 0.0)

	# --- Drone separation (populated by previous step's boids() call) ---
	var nearest_dist_norm = 1.0  # 1.0 = at 2× avoid_radius or no drones nearby
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

	return {"obs": obs}

# 34 observations: 4 clusters × 7 features + own velocity (3) + nearest drone (3)
func _get_obs_v3() -> Dictionary:
	var obs: Array = []

	# --- Cluster features (4 slots, padded with zeros if fewer clusters exist) ---
	for i in 4:
		if i < _v3_clusters.size():
			var c = _v3_clusters[i]
			var basis_inv = drone.global_transform.basis.inverse()

			# Centroid offset in drone-local XZ frame (normalised by 30 m)
			var local_offset = basis_inv * (c.centroid - drone.global_position)
			obs.append(clamp(local_offset.x / 30.0, -1.0, 1.0))
			obs.append(clamp(local_offset.z / 30.0, -1.0, 1.0))

			# Coverage score normalised to ~0–1 (score tops out around 6 for large clusters)
			obs.append(clamp(float(drone._coverage_score(c.size)) / 6.0, 0.0, 1.0))

			# Competing drone count on this cluster (normalised by 5)
			var self_dist = drone.global_position.distance_to(c.centroid)
			var competing = 0
			for reading in drone.sensor_readings_drones:
				var d = reading.position.distance_to(c.centroid)
				if d < self_dist or d < drone.coverage_radius:
					competing += 1
			obs.append(clamp(float(competing) / 5.0, 0.0, 1.0))

			# Cluster velocity relative to drone in local XZ frame (normalised by 10 m/s)
			var drone_flat_vel = Vector3(drone.linear_velocity.x, 0.0, drone.linear_velocity.z)
			var rel_vel = c.velocity - drone_flat_vel
			var local_rel_vel = basis_inv * rel_vel
			obs.append(clamp(local_rel_vel.x / 10.0, -1.0, 1.0))
			obs.append(clamp(local_rel_vel.z / 10.0, -1.0, 1.0))

			# In-front flag: 1.0 if cluster is within ±90° of drone forward axis
			var to_cluster = c.centroid - drone.global_position
			to_cluster.y = 0.0
			var forward = -drone.global_transform.basis.z
			var in_front = 1.0 if to_cluster.length() < 0.01 or forward.angle_to(to_cluster) <= PI * 0.5 else 0.0
			obs.append(in_front)
		else:
			for _j in 7:
				obs.append(0.0)

	# --- Own velocity in drone-local frame (normalised by 15 m/s) ---
	var local_vel = drone.global_transform.basis.inverse() * drone.linear_velocity
	obs.append(clamp(local_vel.x / 15.0, -1.0, 1.0))
	obs.append(clamp(local_vel.y / 15.0, -1.0, 1.0))
	obs.append(clamp(local_vel.z / 15.0, -1.0, 1.0))

	# --- Nearest other drone: local-frame XZ offset + distance (normalised by 30 m) ---
	var nearest_dx := 0.0
	var nearest_dz := 0.0
	var nearest_dist := 1.0  # sentinel: 1.0 = no drone in range
	if not drone.sensor_readings_drones.is_empty():
		var min_d := INF
		for reading in drone.sensor_readings_drones:
			if reading.distance < min_d:
				min_d = reading.distance
				var local_p = drone.global_transform.basis.inverse() * (
					reading.position - drone.global_position
				)
				nearest_dx = clamp(local_p.x / 30.0, -1.0, 1.0)
				nearest_dz = clamp(local_p.z / 30.0, -1.0, 1.0)
				nearest_dist = clamp(min_d / 30.0, 0.0, 1.0)
	obs.append(nearest_dx)
	obs.append(nearest_dz)
	obs.append(nearest_dist)

	return {"obs": obs}

# 20 observations for V4 (local allocation state):
#   4 clusters × 5 features (exists, coverage_score, drones_on, deficit, distance)
#
# All features are derived from this drone's own sensor sphere (30 m radius) —
# no fleet-wide aggregation. The policy must infer allocation quality from
# what it can locally observe, as in a real swarm.
func _get_obs_v4() -> Dictionary:
	var obs: Array = []

	# Max score possible = score if all visible bikes were in one cluster.
	var max_score := float(max(1, drone._coverage_score(
		max(1, drone.sensor_readings_bikes.size())
	)))
	# Max drones_on = all visible drones + self.
	var max_drones := float(max(1, drone.sensor_readings_drones.size() + 1))

	for i in 4:
		if i < _v3_clusters.size():
			var c = _v3_clusters[i]
			var score := float(drone._coverage_score(c.size))
			var self_dist := drone.global_position.distance_to(c.centroid)

			# Count nearby drones already covering this cluster.
			var drones_on := 0
			for reading in drone.sensor_readings_drones:
				var d = reading.position.distance_to(c.centroid)
				if d < self_dist or d < drone.coverage_radius:
					drones_on += 1
			# Count self if currently assigned here.
			if not _v4_selected_cluster.is_empty() and \
					_v4_selected_cluster.centroid == c.centroid:
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

# ─── Action space ─────────────────────────────────────────────────────────────

func get_action_space() -> Dictionary:
	match rl_version:
		Version.V1: return _get_action_space_v1()
		Version.V2: return _get_action_space_v2()
		Version.V3: return _get_action_space_v3()
		Version.V4: return _get_action_space_v4()
	return {}

func _get_action_space_v1() -> Dictionary:
	return {
		"thrust": {"size": 3, "action_type": "continuous"},
		"torque":  {"size": 1, "action_type": "continuous"},
	}

func _get_action_space_v2() -> Dictionary:

	return {
		"avoid_radius": {"size": 1, "action_type": "continuous"},
		"avoid_factor": {"size": 1, "action_type": "continuous"},
		"centering_factor": {"size": 1, "action_type": "continuous"},
		"matching_factor": {"size": 1, "action_type": "continuous"},
	}

func _get_action_space_v3() -> Dictionary:
	return {
		"thrust": {"size": 3, "action_type": "continuous"},
		"torque":  {"size": 1, "action_type": "continuous"},
	}

func _get_action_space_v4() -> Dictionary:
	# 4 scores, one per cluster slot. Argmax picks which cluster to follow.
	return {
		"cluster_scores": {"size": 4, "action_type": "continuous"},
	}

# ─── Actions ──────────────────────────────────────────────────────────────────

func set_action(action) -> void:
	match rl_version:
		Version.V1: _set_action_v1(action)
		Version.V2: _set_action_v2(action)
		Version.V3: _set_action_v3(action)
		Version.V4: _set_action_v4(action)

func _set_action_v1(action) -> void:
	var thrust = action["thrust"]
	var torque = action["torque"][0]
	_last_force = drone.global_transform.basis * Vector3(thrust[0], thrust[1], thrust[2]) * drone.max_force
	_last_torque = clamp(torque, -1.0, 1.0)
	drone.apply_central_force(_last_force)
	drone.apply_torque(drone.global_transform.basis.y * _last_torque * drone.max_torque)

func _set_action_v2(action) -> void:
	drone.set_tunable_parameters({
		"avoid_radius":     _remap_action(action["avoid_radius"][0],     0.5, 10.0),
		"avoid_factor":     _remap_action(action["avoid_factor"][0],     0.1, 10.0),
		"centering_factor": _remap_action(action["centering_factor"][0], 0.1,  5.0),
		"matching_factor":  _remap_action(action["matching_factor"][0],  0.01, 1.0),
	})

	drone.boids()

func _set_action_v3(action) -> void:
	var thrust = action["thrust"]
	var torque = action["torque"][0]
	_last_force = drone.global_transform.basis * Vector3(thrust[0], thrust[1], thrust[2]) * drone.max_force
	_last_torque = clamp(torque, -1.0, 1.0)
	drone.apply_central_force(_last_force)
	drone.apply_torque(drone.global_transform.basis.y * _last_torque * drone.max_torque)

func _set_action_v4(action) -> void:
	if _v3_clusters.is_empty():
		return

	# Argmax over the 4 score outputs, restricted to valid cluster indices.
	var scores = action["cluster_scores"]
	var best_idx = 0
	var best_score = -INF
	for i in min(scores.size(), _v3_clusters.size()):
		if scores[i] > best_score:
			best_score = scores[i]
			best_idx = i

	_v4_selected_cluster = _v3_clusters[best_idx]

	# Navigate to the selected cluster using boids forces.
	var alignment_vector = drone.alignment(_v4_selected_cluster.bikes)
	var cohesion_vector = drone.cohesion(_v4_selected_cluster.bikes)
	var separation_vector = drone.separation()

	var direction_vector = alignment_vector + cohesion_vector + separation_vector

	# Height towards selected cluster centroid + offset.
	var desired_y = _v4_selected_cluster.centroid.y + drone.height_offset
	var y_error = desired_y - drone.global_position.y
	if abs(y_error) < 10.0:
		direction_vector.y = clamp(
			y_error * drone.y_gain - drone.linear_velocity.y * drone.y_damp,
			-drone.max_up_force, drone.max_up_force
		)
	else:
		direction_vector.y = 0.0

	drone.apply_central_force(drone.clamp_vector(direction_vector, drone.max_force))
	drone.rotate_towards_direction(-alignment_vector)

# Remap a value from the RL output range [-1, 1] to [low, high].
func _remap_action(value: float, low: float, high: float) -> float:
	return low + (value + 1.0) * 0.5 * (high - low)
	

func get_reward() -> float:
	return reward

# ─── Reset ────────────────────────────────────────────────────────────────────

func reset():
	super.reset()
	drone.linear_velocity = Vector3.ZERO
	drone.angular_velocity = Vector3.ZERO
	_steps_without_bike = 0
	drone.target_bike = null
	drone.target_position = null
	_v4_selected_cluster = {}

	var world = drone.get_parent()
	if world.is_rl:
		if shared.bike_lists[world.instance_id].is_empty() or not world.is_training:
			# All bikes finished the course — full world reset.
			world.reset_track_and_bike_and_drone()
		else:
			# This drone lost sight of bikes — respawn it near a random bike
			# without disturbing the track, bikes, or other drones.
			world.respawn_drone(drone)
	else:
		drone.set_position(Vector3(0, drone.height_offset + 2.0, 0))

# ─── Helpers ──────────────────────────────────────────────────────────────────

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

func _draw_debug_v4() -> void:
	if not drone.debug_draw:
		return

	while _v4_cluster_dots.size() < _v3_clusters.size():
		var dot = drone._make_cluster_dot()
		drone.get_parent().add_child.call_deferred(dot)
		_v4_cluster_dots.append(dot)

	for i in _v3_clusters.size():
		var dot: MeshInstance3D = _v4_cluster_dots[i]
		var is_selected = not _v4_selected_cluster.is_empty() and \
			_v4_selected_cluster.centroid == _v3_clusters[i].centroid
		(dot.material_override as StandardMaterial3D).albedo_color = \
			Color.GREEN if is_selected else Color.ORANGE
		if dot.is_inside_tree():
			dot.global_position = _v3_clusters[i].centroid
		dot.visible = true

	for i in range(_v3_clusters.size(), _v4_cluster_dots.size()):
		_v4_cluster_dots[i].visible = false

	if _v4_selected_line == null:
		_v4_selected_line = drone.make_debug_line()
		drone.get_parent().add_child.call_deferred(_v4_selected_line)
	if not _v4_selected_cluster.is_empty():
		drone.place_debug_line(
			_v4_selected_line,
			drone.global_position,
			_v4_selected_cluster.centroid,
			Color.GREEN
		)
	else:
		_v4_selected_line.visible = false

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
