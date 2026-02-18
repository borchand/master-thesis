extends RigidBody3D

class_name Drone
static var RAB_RANGE := 40
static var _next_id: int = 1
var id: int


@onready var drone_detector: DroneDetection = $"Camera_detection"
@onready var target_bike = null


@export var yaw_p = 1
@export var yaw_d = 1
@export var max_torque = 3
@export var max_steer_force = 150
@export var offset = 15
@export var slow_radius = 15.0
@export var stop_radius = 3.0
@export var brake_strength = 2 
var rab_signals := []

#These values should already be set on the body inspector itself, however I set it here
#For clarity and to make sure accidental changes don't change values
func _ready() -> void: 
	id = _next_id
	_next_id += 1
	mass = 30.0
	linear_damp = 0.2 
	angular_damp = 1.5
	add_to_group("drones")
	
func _physics_process(_delta):
	if self.id % 2 == 0:
		get_target(drone_detector.bike_set, true)
	else:
		get_target(drone_detector.bike_set, false)
	read_sensors()
	
	if not target_bike:
		search_spin()
		return
	
	var steer = flocking()
	steer = steer.normalized()

	var forward = -global_transform.basis.z
	var up = global_transform.basis.y

	var steer_flat = (steer - up * steer.dot(up)).normalized()
	
	var height_error = target_bike.global_position.y - global_position.y + 5
	var steer_height = Vector3.ZERO
	steer_height.y = height_error
	
	var yaw_error = atan2(up.dot(forward.cross(steer_flat)), forward.dot(steer_flat))
	var yaw_rate = angular_velocity.dot(up)
	var torque = yaw_p * yaw_error - yaw_d * yaw_rate
	apply_torque(up * clamp(torque, -max_torque, max_torque))
	
	var to_target = target_bike.global_position - global_position
	var dist = to_target.length()
	var dir = to_target / max(dist, 0.001)

	var catchup = 0.0
	if dist > stop_radius:
		catchup = clamp((dist - stop_radius) / (slow_radius - stop_radius), 0.0, 1.0)
	apply_central_force(steer_flat * max_steer_force * catchup)

	var v = linear_velocity
	var closing_speed = v.dot(dir)
	if dist < slow_radius and closing_speed > 0.0:
		var brake_force = -dir * closing_speed * brake_strength * mass
		brake_force.y = 0
		apply_central_force(brake_force)

	apply_central_force(steer_height)

func kmh():
	var speed_kmh = linear_velocity.length() * 3.6
	print("Speed:", speed_kmh, "km/h")
	
func flocking():
	var align_vector = Vector3.ZERO
	var cohesion_vector = Vector3.ZERO
	var separation_vector = Vector3.ZERO
	var target_vector = Vector3.ZERO
	
	var w_target = 10.6
	var w_align = 0.01
	var w_cohesion = 0.1
	var w_separation = 1.5
	var w_RAB_RANGE = 0.35
	
	for sig in self.rab_signals:
		align_vector += sig["heading"]
	align_vector.y = 0
	
	for sig in self.rab_signals:
		var dir_vec: Vector3 = sig["bearing"].normalized()
		dir_vec.y = 0

		if sig["distance"] >= RAB_RANGE * w_RAB_RANGE:
			cohesion_vector += dir_vec
		else:
			separation_vector -= dir_vec
	
	var to_target = (target_bike.global_position - global_position) if target_bike else Vector3.ZERO
	target_vector = to_target.normalized()
			
	var steer = (w_align * align_vector) \
		+ (w_cohesion * cohesion_vector) \
		+ (w_separation * separation_vector) \
		+ (w_target * target_vector)

	return steer

func search_spin():
	var up = global_transform.basis.y
	apply_torque(up * max_torque)

func decide_to_split():
	pass

func read_sensors():
	self.rab_signals = []
	
	for drone in get_tree().get_nodes_in_group("drones"):
		if drone == self:
			continue
			
		if drone is Drone:
			var dist = global_position.distance_to(drone.global_position)
			if dist <= RAB_RANGE:
				self.rab_signals.append(
					{
						"id": drone.id,
						"distance": dist,
						"linear_velocity": drone.linear_velocity,
						"heading": -1 * drone.global_transform.basis.z,
						"bearing": drone.global_position - global_position,
						"message": []
					}
				)

func get_target(bikes: Dictionary, furthest: bool):
	var distance = -INF if furthest else INF
	
	if not bikes:
		target_bike = null
	
	for bike_id in bikes:
		var pos = bikes[bike_id].global_position
		var dist = global_position.distance_to(pos)
		var should_pick = dist > distance if furthest else dist < distance
		if should_pick:
			distance = dist
			target_bike = bikes[bike_id].get_parent()

func get_camera_node() -> Camera3D:
	return $Camera3D
