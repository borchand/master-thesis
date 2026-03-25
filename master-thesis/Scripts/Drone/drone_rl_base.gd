extends AIController3D

enum Version { V1, V2 }

@export var rl_version: Version = Version.V1
@export var no_bike_reset_steps: int = 500
@export var debug_draw: bool = true
@export var debug_line_width: float = 0.1

@onready var drone: RigidBody3D = $".."

var _steps_without_bike: int = 0
var _debug_lines: Array[MeshInstance3D] = []
var _debug_force_line: MeshInstance3D = null
var _debug_torque_line: MeshInstance3D = null
var _last_force: Vector3 = Vector3.ZERO
var _last_torque: float = 0.0

# ─── Lifecycle ────────────────────────────────────────────────────────────────

func _ready():
	if not get_parent().is_rl:
		control_mode = ControlModes.HUMAN
		return
	super._ready()

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

# ─── Observations ─────────────────────────────────────────────────────────────

func get_obs() -> Dictionary:
	match rl_version:
		Version.V1: return _get_obs_v1()
		Version.V2: return _get_obs_v2()
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

func _get_obs_v2() -> Dictionary:
	return {"obs": []}  # TODO: implement V2 observations

# ─── Action space ─────────────────────────────────────────────────────────────

func get_action_space() -> Dictionary:
	match rl_version:
		Version.V1: return _get_action_space_v1()
		Version.V2: return _get_action_space_v2()
	return {}

func _get_action_space_v1() -> Dictionary:
	return {
		"thrust": {"size": 3, "action_type": "continuous"},
		"torque":  {"size": 1, "action_type": "continuous"},
	}

func _get_action_space_v2() -> Dictionary:

	return {
		"avoid_radius": {"size": 1, "action_type": "continuous"},
		"avoid_strength": {"size": 1, "action_type": "continuous"},
		"max_avoid_speed": {"size": 1, "action_type": "continuous"},
		"avoid_factor": {"size": 1, "action_type": "continuous"},
		"centering_factor": {"size": 1, "action_type": "continuous"},
		"matching_factor": {"size": 1, "action_type": "continuous"},
	}

# ─── Actions ──────────────────────────────────────────────────────────────────

func set_action(action) -> void:
	match rl_version:
		Version.V1: _set_action_v1(action)
		Version.V2: _set_action_v2(action)

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
		"avoid_strength":   _remap_action(action["avoid_strength"][0],   1.0, 20.0),
		"max_avoid_speed":  _remap_action(action["max_avoid_speed"][0],  1.0, 20.0),
		"avoid_factor":     _remap_action(action["avoid_factor"][0],     0.1, 10.0),
		"centering_factor": _remap_action(action["centering_factor"][0], 0.1,  5.0),
		"matching_factor":  _remap_action(action["matching_factor"][0],  0.01, 1.0),
	})

	drone.boids()

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

	var world = drone.get_parent()
	if world.is_rl:
		world.reset_track_and_bike()
		var bikes = shared.bike_lists[world.instance_id]
		if not bikes.is_empty():
			drone.target_bike = bikes[0]
			drone.set_position(_get_desired_pos())
			var bike_forward = -drone.target_bike.global_transform.basis.z
			bike_forward.y = 0
			drone.look_at(drone.global_position + bike_forward.normalized(), Vector3.UP)
		else:
			drone.set_position(Vector3(0, drone.height_offset + 2.0, 0))
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

func _make_debug_line() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(debug_line_width, debug_line_width, 1.0)
	mi.mesh = box
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true
	mi.material_override = mat
	return mi

func _place_debug_line(mi: MeshInstance3D, a: Vector3, b: Vector3, color: Color, up: Vector3 = Vector3.UP) -> void:
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

func _draw_debug_lines() -> void:
	if not debug_draw:
		return
	var bikes = drone.drone_detector.bike_set.values()
	while _debug_lines.size() < bikes.size():
		var mi := _make_debug_line()
		drone.get_parent().add_child.call_deferred(mi)
		_debug_lines.append(mi)
	for i in bikes.size():
		var bike_body: Bike_body = bikes[i]
		var color := Color.GREEN if bike_body.get_parent() == drone.target_bike else Color.YELLOW
		_place_debug_line(_debug_lines[i], drone.global_position, bike_body.global_position, color)
	for i in range(bikes.size(), _debug_lines.size()):
		_debug_lines[i].visible = false
	if _debug_force_line == null:
		_debug_force_line = _make_debug_line()
		drone.get_parent().add_child.call_deferred(_debug_force_line)
	_place_debug_line(_debug_force_line, drone.global_position,
		drone.global_position + _last_force / drone.max_force * 5.0, Color.RED)
	if _debug_torque_line == null:
		_debug_torque_line = _make_debug_line()
		drone.get_parent().add_child.call_deferred(_debug_torque_line)
	_place_debug_line(_debug_torque_line, drone.global_position,
		drone.global_position + Vector3.UP * _last_torque * 5.0, Color.BLUE, Vector3.FORWARD)
