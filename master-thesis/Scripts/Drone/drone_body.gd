extends RigidBody3D

@onready var drone_detector: DroneDetection = $"Camera_detection"
@onready var target_position = null
@onready var target_speed = null
@onready var target_bike = null

func _physics_process(_delta):
	get_nearest_position(drone_detector.bike_set)

	if is_instance_valid(target_bike):
		follow_target()
	else:
		search_spin()

#Controller for following a picked target
func follow_target():
	var follow_data = get_follow_data()
	if follow_data == null:
		#Do something here, maybe find new target
		return
	
	rotate_towards_bike(follow_data.bike_forward, follow_data.drone_forward)

	var desired_velocity = compute_desired_velocity(follow_data)
	apply_horizontal_follow_force(desired_velocity, follow_data)

	control_height(follow_data.desired_pos)

func search_spin():
	var up = global_transform.basis.y
	apply_torque(up * max_torque)
	
@export var behind_distance := 4.0
@export var height_offset := 5.0
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

@export var max_torque := 2.0
@export var yaw_gain := 2.2
@export var torque_zone := 0.05
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

@export var min_distance := 3.5
@export var max_distance := 4.5
@export var catchup_gain := 3.5
@export var max_catchup_speed := 14.0
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

@export var max_force := 18.0
@export var brake_force := 40.0
func apply_horizontal_follow_force(desired_velocity: Vector3, data):
	apply_central_force(clamp_vector(desired_velocity - data.drone_velocity, max_force))

	if data.forward_offset > 0.5:
		apply_central_force(-data.bike_forward * brake_force)

@export var y_gain := 8.0
@export var y_damp := 4.0
@export var max_up_force := 8.0
func control_height(desired_pos: Vector3):
	#How far from the target height
	var y_error = desired_pos.y - global_position.y
	#How fast the drone is already moving up/down
	var y_vel = linear_velocity.y
	#Drone far below the target = push up strongly. If drone far above = push down strongly
	var y_force = (y_error * y_gain) - (y_vel * y_damp)
	y_force = clamp(y_force, -max_up_force, max_up_force)
	apply_central_force(Vector3.UP * y_force)

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
