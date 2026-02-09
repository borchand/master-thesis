extends RigidBody3D

@onready var drone_detector: DroneDetection = $"Camera_detection"
@onready var target_position = null
@onready var target_speed = null

@export var max_force= 80
@export var max_torque = 0.2
@export var yaw_p := 10.0
@export var yaw_d := 10.0
@export var speed_gain := 3.0

func follow_target():
	var to_target = target_position - global_position
	to_target.y = 0

	var dir = to_target.normalized()
	var forward = -global_transform.basis.z
	var up = global_transform.basis.y

	var yaw_error = forward.cross(dir).dot(up)
	var yaw_rate = angular_velocity.dot(up)

	var torque = yaw_error * yaw_p - yaw_rate * yaw_d
	torque = clamp(torque, -max_torque, max_torque)
	
	var current_speed = linear_velocity.dot(dir)
	var speed_error = target_speed - current_speed

	var force = speed_error * speed_gain
	force = clamp(force, -max_force, max_force)

	apply_central_force(dir * force)
	apply_torque(up * torque)
	
func _integrate_forces(_state):
	pass
		
func _physics_process(_delta):
	if target_position:
		if shared.drone_controlled:
			move_by_keyboard()
		else:
			follow_target()
	else:
		search_spin()
			
func _process(_delta):
	if drone_detector.bike_set.size() > 0:
		get_nearest_position(drone_detector.bike_set)
		
func search_spin():
	var up = global_transform.basis.y
	apply_torque(up * max_torque)

func move_by_keyboard():
	var dir = Vector3.ZERO

	var forward = -global_transform.basis.z
	var up = global_transform.basis.y

	if Input.is_action_pressed("ui_up"):
		dir += forward
	if Input.is_action_pressed("ui_down"):
		dir -= forward

	if dir != Vector3.ZERO:
		apply_central_force(dir.normalized())

	if Input.is_action_pressed("ui_left"):
		apply_torque(up * max_torque)
	if Input.is_action_pressed("ui_right"):
		apply_torque(-up * max_torque)

func get_nearest_position(bikes: Dictionary):
	var closest = Vector3.ZERO
	var min_distance = INF
	var speed = 0

	for bike_id in bikes:
		var pos = bikes[bike_id].global_position
		var dist = global_position.distance_to(pos)
		if dist < min_distance:
			min_distance = dist
			closest = pos
			speed = bikes[bike_id].get_parent().speed
	
	target_position = closest
	target_speed = speed

func get_camera_node() -> Camera3D:
	return $Camera3D
