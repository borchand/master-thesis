extends RigidBody3D

@onready var drone_detector: DroneDetection = $"Camera_detection"
var target_position = global_position
var speed: float = 1

func _ready():
	pass

func _process(delta):
	if drone_detector.bike_set.size() > 0:
		target_position = get_nearest_position(drone_detector.bike_set)

func look_follow(state: PhysicsDirectBodyState3D, current_transform: Transform3D, target_pos: Vector3) -> void:
	var forward_dir = current_transform.basis.z
	forward_dir.y = 0
	forward_dir = forward_dir.normalized()

	var to_target = target_pos - current_transform.origin
	to_target.y = 0

	if to_target.length() < 0.001:
		return

	var target_dir = to_target.normalized()

	var dot = clampf(forward_dir.dot(target_dir), -1.0, 1.0)
	var angle = acos(dot)

	if angle < 0.01:
		state.angular_velocity = Vector3.ZERO
		return

	var cross_y = forward_dir.cross(target_dir).y
	state.angular_velocity = Vector3(0, cross_y * 6.0, 0)

func _integrate_forces(state):
	look_follow(state, global_transform, target_position)
	var forward = state.transform.basis.z
	forward.y = 0
	forward = forward.normalized()
	state.apply_central_force(forward * speed)

func get_nearest_position(bikes: Dictionary) -> Vector3:
	var closest = Vector3.ZERO
	var min_distance = INF

	for bike_id in bikes:
		var pos = bikes[bike_id].global_position
		var dist = global_position.distance_to(pos)
		if dist < min_distance:
			min_distance = dist
			closest = pos
	
	closest.y += 1
	return closest

func get_camera_node() -> Camera3D:
	return $Camera3D
