extends RigidBody3D
class_name Drone

static var _next_id: int = 1
var id: int

var is_rl: bool = false

@onready var drone_detector: DroneDetection = $"Camera_detection"
@onready var drone_sensor: DroneCommunication = $"Drone_communication"

@onready var sensor_readings_drones = []
@onready var sensor_readings_bikes =[]

@onready var target_position = null
@onready var target_speed = null
@onready var target_bike = null

@export var behind_distance := 4.0
@export var max_torque := 2.0
@export var yaw_gain := 2.2
@export var torque_zone := 0.05
@export var min_distance := 3.5
@export var max_distance := 4.5
@export var catchup_gain := 3.5
@export var max_catchup_speed := 14.0
@export var max_force := 18.0
@export var brake_force := 40.0

#For collission avoidance
@export var avoid_strength := 8.0
@export var max_avoid_speed := 10.0

#Boids tuneable parameters
@export var y_gain := 20.0
@export var y_damp := 30.0
@export var max_up_force := 40.0
@export var height_offset := 5.0
@export var avoid_radius := 3.0
@export var avoidfactor = 0
@export var centeringfactor = 2
@export var matchingfactor = 0.25

var timestep = 1

func _ready():
	id = _next_id
	_next_id += 1
	contact_monitor = true
	start_logging()
	
func _physics_process(_delta):
	if is_rl:
		return
	
	boids()
	log_information(timestep)
	timestep += 1
	print(get_contact_count())

func boids():
	read_sensor(drone_sensor.drone_set, drone_sensor.bike_set)
	var alignment_vector = alignment() 
	var cohesion_vector = cohesion()
	var separation_vector = separation()
	
	var direction_vector = alignment_vector + cohesion_vector + separation_vector
	direction_vector.y = height_force()
	
	apply_central_force(clamp_vector(direction_vector, max_force))
	rotate_towards_direction(-alignment_vector)

func alignment():
	var alignment_vector = Vector3.ZERO
	var neighboring_bikes = 0
	
	for bike in sensor_readings_bikes:
		neighboring_bikes += 1
		alignment_vector.x += bike["velocity"].x
		alignment_vector.z += bike["velocity"].z
	
	if neighboring_bikes > 0:
		alignment_vector.x /= neighboring_bikes
		alignment_vector.z /= neighboring_bikes
	
	alignment_vector.x = (alignment_vector.x - linear_velocity.x) * matchingfactor
	alignment_vector.z = (alignment_vector.z - linear_velocity.z) * matchingfactor
	
	return alignment_vector
	
func cohesion():
	var cohesion_vector = Vector3.ZERO
	var neighboring_bikes = 0
	
	for bike in sensor_readings_bikes:
		neighboring_bikes += 1
		cohesion_vector.x += bike["position"].x
		cohesion_vector.z += bike["position"].z
	
	if neighboring_bikes > 0:
		cohesion_vector.x /= neighboring_bikes
		cohesion_vector.z /= neighboring_bikes
		
		cohesion_vector.x -= global_position.x
		cohesion_vector.z -= global_position.z
		
		cohesion_vector.x *= centeringfactor
		cohesion_vector.z *= centeringfactor
	
	return cohesion_vector
	
func separation():
	var separation_vector = Vector3.ZERO
	
	for reading in sensor_readings_drones:
		if reading["distance"] > avoid_radius:
			continue
		
		separation_vector.x += global_position.x - reading.position.x
		separation_vector.z += global_position.z - reading.position.z
	
	separation_vector.x *= avoidfactor
	separation_vector.z *= avoidfactor
	
	return separation_vector

func height_force():
	if len(sensor_readings_bikes) == 0:
		return 0
		
	var neighboring_bikes = 0
	var avg_y = 0
	
	for bike in sensor_readings_bikes:
		neighboring_bikes += 1
		avg_y += bike.position.y
	
	avg_y /= neighboring_bikes
	var desired_y = avg_y + height_offset
	var y_error = desired_y - global_position.y
	
	if abs(y_error) < 10:
		return clamp(y_error * y_gain - linear_velocity.y * y_damp, -max_up_force, max_up_force)
	else:
		return 0

func rotate_towards_direction(direction_vector: Vector3):
	var desired_forward = flat_dir(direction_vector)
	
	if desired_forward.length() < 0.01:
		return
	
	var drone_forward = flat_dir(-global_transform.basis.z)
	var up = global_transform.basis.y
	
	var yaw_error = atan2(drone_forward.cross(desired_forward).y, drone_forward.dot(desired_forward))
	
	if abs(yaw_error) > torque_zone:
		var torque_strength = clamp(yaw_error * yaw_gain, -1.0, 1.0) * max_torque
		apply_torque(up * torque_strength)

#Controller for following a picked target
func follow_target():
	var follow_data = get_follow_data()
	
	rotate_towards_bike(follow_data.bike_forward, follow_data.drone_forward)

	var desired_velocity = compute_desired_velocity(follow_data)
	apply_horizontal_follow_force(desired_velocity, follow_data)
	apply_collision_avoidance()

	control_height(follow_data.desired_pos)

func search_spin():
	var up = global_transform.basis.y
	apply_torque(up * max_torque)
	apply_collision_avoidance()
	
func apply_collision_avoidance():
	var avoidance_force = Vector3.ZERO

	for reading in sensor_readings_drones:
		if reading.distance > avoid_radius:
			continue

		var away = global_position - reading.position
		away.y = 0.0
		away = away.normalized()

		var weight = (avoid_radius - reading.distance) / avoid_radius

		avoidance_force += away * weight * avoid_strength

	apply_central_force(clamp_vector(avoidance_force, max_force))
	
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

func apply_horizontal_follow_force(desired_velocity: Vector3, data):
	apply_central_force(clamp_vector(desired_velocity - data.drone_velocity, max_force))

	if data.forward_offset > 0.5:
		apply_central_force(-data.bike_forward * brake_force)

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

func read_sensor(drones: Dictionary, bikes: Dictionary):
	sensor_readings_drones = []
	sensor_readings_bikes = []
	
	for drone in drones:
		if drone.id != id:
			sensor_readings_drones.append(
				{
					"id": drone.id,
					"position": drone.global_position,
					"distance": global_position.distance_to(drone.global_position),
					"direction": global_position.direction_to(drone.global_position)
				}
			)
	
	for bike in bikes:
		sensor_readings_bikes.append(
			{
				"position": bike.global_position,
				"distance": global_position.distance_to(bike.global_position),
				"direction": global_position.direction_to(bike.global_position),
				"velocity":  flat_dir(-bike.global_transform.basis.z) * bike.get_parent().speed
			}
		)

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

func create_logging_message(delta):
	var data = []
	
	data.append(str(delta))
	data.append(str(global_position.x))
	data.append(str(global_position.y))
	data.append(str(global_position.z))

	return data

func start_logging():
	logging.start_run_file(str(self.id), "drone")

func log_information(delta):
	var message = create_logging_message(delta)
	logging.append_line(str(self.id), "drone", message)
