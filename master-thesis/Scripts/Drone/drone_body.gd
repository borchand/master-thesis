extends RigidBody3D

@onready var drone_detector: DroneDetection = $"Camera_detection"
@onready var target_position = null
@onready var target_speed = null
@onready var target_bike = null
@onready var total_time_since_last_scan = 10

@export var max_torque := 2
@export var max_force := 10
@export var behind_distance := 3
@export var yaw_gain := 1.6
@export var min_distance := 3
@export var max_distance := 6
@export var brake_force := 30
@export var height_offset := 5.0     
@export var y_gain := 8.0
@export var y_damp := 4.0
@export var max_up_force := 8.0
@export var torque_zone := 0.8


func follow_target():
	if target_bike == null:
		return
	
	var up = global_transform.basis.y
	
	#position of bike tracked, y set to 0 to avoid moving down
	var bike_forward = -target_bike.global_transform.basis.z
	bike_forward.y = 0
	bike_forward = bike_forward.normalized()
	
	#offset, to stay slightly behind the bike we aim to follow. Set behind distance above to change this 
	#Change y position back 
	var desired_pos = target_bike.global_position - bike_forward * behind_distance
	desired_pos.y = target_bike.global_position.y + height_offset
	
	# vector and distance to desired position ONLY horizontal
	var to_desired = desired_pos - global_position
	to_desired.y = 0
	var dist = to_desired.length()
	if dist > 0.001:
		#Direction from vector and distance
		var dir = to_desired / dist
		
		#Drones forward direction
		var drone_forward = -global_transform.basis.z
		drone_forward.y = 0
		drone_forward = drone_forward.normalized()
		
		var yaw_error = atan2(drone_forward.cross(dir).y, drone_forward.dot(dir))
		var abs_err = abs(yaw_error)
		
		#Ignore turning all the time 
		if abs_err > torque_zone:
			apply_torque(up * clamp(yaw_error * yaw_gain, -2.0, 2.0) * max_torque)
		
		if dist > max_distance:
			var t = clamp((dist - max_distance) / max_distance, 0.0, 1.0)
			apply_central_force(dir * (max_force * (0.6 + 0.4 * t)))
		elif dist < min_distance:
			var v = linear_velocity
			v.y = 0
			if v.length() > 0.1:
				apply_central_force(-v.normalized() * brake_force)
		else:
			apply_central_force(dir * (max_force * 0.25))
	
	#Height controlling
	var y_error = desired_pos.y - global_position.y
	var y_vel = linear_velocity.y
	var y_force = (y_error * y_gain) - (y_vel * y_damp)
	y_force = clamp(y_force, -max_up_force, max_up_force)

	apply_central_force(Vector3(0, y_force, 0))
	
func _physics_process(_delta):
	total_time_since_last_scan += _delta
	
	if drone_detector.bike_set.size() > 0 and total_time_since_last_scan >= 10:
		total_time_since_last_scan = 0
		#get_nearest_position(drone_detector.bike_set)
		get_random_position(drone_detector.bike_set)
	
	if target_position:
		if shared.drone_controlled:
			move_by_keyboard()
		else:
			follow_target()
	else:
		search_spin()

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
		apply_central_force(dir.normalized() * max_force)

	if Input.is_action_pressed("ui_left"):
		apply_torque(up * max_torque)
	if Input.is_action_pressed("ui_right"):
		apply_torque(-up * max_torque)

func get_nearest_position(bikes: Dictionary):
	var closest = Vector3.ZERO
	var minimum_distance = INF
	var speed = 0

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

func get_camera_node() -> Camera3D:
	return $Camera3D
