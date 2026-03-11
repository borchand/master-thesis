extends RigidBody3D

@onready var drone_detector: DroneDetection = $"Camera_detection"
@onready var target_position = null
@onready var target_speed = null
@onready var target_bike = null
@onready var total_time_since_last_scan = 10
@onready var ai_controller = $AIController3D

@export var max_torque := .1
@export var max_force := 15
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
var steps_with_bike = 0
var max_steps_with_no_bike = 500

var start_position = Vector3.ZERO
var start_rotation = Vector3.ZERO

func _ready():
	if use_rl:
		ai_controller.init(self)
		start_position = global_position
		start_rotation = rotation

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
	# direction is in drone-local space — convert to global before applying force
	apply_central_force(global_transform.basis * direction * central_force)
	apply_torque(global_transform.basis.y * torque)
	

func get_reward() -> float:
	target_bike = null
	get_nearest_position(drone_detector.bike_set)
	var reward = 0.0

	if shared.total_visible_bikes() == 0:
		steps_with_no_bike += 1
		steps_with_bike = 0

		# Flat penalty per step — encourages actively re-acquiring the bike
		reward -= 0.5

		if steps_with_no_bike >= max_steps_with_no_bike:
			ai_controller.done = true
			ai_controller.needs_reset = true
			steps_with_no_bike = 0

	else:
		steps_with_no_bike = 0
		steps_with_bike += 1

		if target_bike != null:
			# Ideal follow position: behind the bike at height_offset above it
			var bike_forward = -target_bike.global_transform.basis.z
			bike_forward.y = 0.0
			bike_forward = bike_forward.normalized()
			var desired_pos = target_bike.global_position - bike_forward * behind_distance
			desired_pos.y = target_bike.global_position.y + height_offset

			# Dense position reward: 1/(1+error) gives useful gradient at all distances.
			# exp(-error/sigma) collapses to ~0 when far away, giving no signal to move.
			var pos_error = global_position.distance_to(desired_pos)
			reward += 1.0 / (1.0 + pos_error)

			# Speed-matching penalty: penalise forward speed mismatch to prevent overtaking.
			# Uses the bike's forward axis so only the along-track component is compared.
			var drone_fwd_speed = linear_velocity.dot(bike_forward)
			var speed_diff = abs(drone_fwd_speed - target_bike.speed)
			reward -= speed_diff * 0.03

			# Camera centering bonus: smaller secondary signal so it does not dominate.
			# Clamped to 0 so negative values (bike behind) do not subtract.
			var cam_forward = -get_camera_node().global_transform.basis.z
			var to_bike = (target_bike.global_position - global_position).normalized()
			reward += maxf(0.0, cam_forward.dot(to_bike)) * 0.2

	return reward
	

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
	global_transform.basis = Basis().rotated(Vector3(1, 0, 0), start_rotation.x).rotated(Vector3(0, 1, 0), start_rotation.y).rotated(Vector3(0, 0, 1), start_rotation.z)
	steps_with_no_bike = 0
	steps_with_bike = 0
