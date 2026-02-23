extends RigidBody3D

@onready var drone_detector: DroneDetection = $"Camera_detection"
@onready var target_position = null
@onready var target_speed = null
@onready var target_bike = null
@onready var total_time_since_last_scan = 10
@onready var ai_controller = $AIController3D

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

@export var use_rl : bool = true

var steps_with_no_bike = 0
var max_steps_with_no_bike = 1000

var start_position = Vector3.ZERO

func _ready():
	if use_rl:
		ai_controller.init(self)
		start_position = global_position

func _physics_process(delta):
	if use_rl:
		rl_procces(delta)
	else:
		drone_process(delta)


func rl_procces(_delta):
	
	if shared.bikes.size() == 0:
		ai_controller.done = true
		ai_controller.needs_reset = true	
	
	if ai_controller.needs_reset:
		ai_controller.reset()
		get_parent().reset()
		reset()
		return
	
	var torque = ai_controller.torque
	var central_force = ai_controller.central_force
	var direction = ai_controller.direction
	
	# write data to file
	var file = FileAccess.open("res://drone_data_per_episode.csv", FileAccess.READ_WRITE)
	file.seek_end()
	file.store_line(str(ai_controller.episode) + ", " + str(ai_controller.n_steps) + ", " + str(ai_controller.reward) + ", " + str(direction.x) + ", " + str(direction.y) + ", " + str(direction.z) + ", " + str(central_force) + ", " + str(torque))
	file.close()

	apply_central_force(direction * central_force)
	apply_torque(global_transform.basis.y * torque)

func get_reward() -> float:
	target_bike = null
	get_nearest_position(drone_detector.bike_set)
	var reward = 0.0

	# reward for standing still
	if linear_velocity.length() < 0.1:
		reward += 1
	
	# reward for seeing bike, punish 0 bikes
	if not target_bike:
		reward -= 1
	else:
		if target_bike.global_position.y + self.global_position.y != 5:
			reward -= 1
		reward += 1

	# punsih for moving 
	if linear_velocity.length() > 0.1 and not target_bike:
		reward -= linear_velocity.length() * 0.5

	# punsih for spinning
	if angular_velocity.length() > 0.1:
		reward -= angular_velocity.length() * 1

	return reward

	# reward = -0.1

	# if shared.total_visible_bikes() == 0:
	# 	reward -= 2.0 # Smaller per-step penalty to encourage searching
	# 	steps_with_no_bike += 1
	# 	if steps_with_no_bike >= max_steps_with_no_bike:
	# 		ai_controller.needs_reset = true
	# 		reward -= 20.0 # Final "failure" penalty
	# else:
	# 	steps_with_no_bike = 0
	# 	var closest_bike = shared.get_closest_bike_to_drone($Camera3D)
	# 	var dist = global_position.distance_to(closest_bike.global_position)
		
	# 	# 1. Optimal Distance Reward (Gaussian-style)
	# 	# Target a "sweet spot" (e.g., 5 meters away)
	# 	var ideal_dist = 5.0
	# 	var dist_error = abs(dist - ideal_dist)
	# 	reward += exp(-dist_error * 0.5) * 5 # High reward when close to 5m, tapers off
		
	# 	# 2. Centering Reward (Keep the bike in the middle of the screen)
	# 	# This is better than just "counting" bikes
	# 	var screen_pos = $Camera3D.unproject_position(closest_bike.global_position)
	# 	var screen_center = get_viewport().size / 2
	# 	var center_error = screen_pos.distance_to(screen_center) / get_viewport().size.length()
	# 	reward += (1.0 - center_error) * 0.5

	# 	# 3. Movement/Smoothing Penalty
	# 	# Penalize the drone for being too "twitchy" (high angular velocity)
	# 	reward -= angular_velocity.length() * 0.1

	# 	# 4. punsih for going under the bike
	# 	if closest_bike.global_position.y > global_position.y:
	# 		reward -= to_local(closest_bike.global_position).y * 0.2

	# 	# 5. Bonus for bike in camera view
	# 	if shared.total_visible_bikes() > 0:
	# 		reward += 10.0
	
	# return reward
	

func drone_process(delta):
	total_time_since_last_scan += delta
		
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

func game_over():
	ai_controller.done = true
	ai_controller.needs_reset = true		

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

func reset():
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	global_transform.origin = start_position
	# set random rotation around y axis to avoid symmetry in the start position
	var random_rotation = randf() * PI * 2
	var random_basis = Basis(Vector3.UP, random_rotation)
	global_transform.basis = random_basis
