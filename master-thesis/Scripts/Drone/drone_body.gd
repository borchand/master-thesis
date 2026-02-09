extends RigidBody3D

@onready var drone_detector: DroneDetection = $"Camera_detection"
@onready var target_position = global_position

var force := 3.0
var yaw_torque := 0.01

func _ready():
	pass

func move():
	var dir := Vector3.ZERO

	if Input.is_action_pressed("ui_up"):
		dir += transform.basis.z
	if Input.is_action_pressed("ui_down"):
		dir += -transform.basis.z
	if Input.is_action_pressed("ui_left"):
		apply_torque(Vector3.UP * yaw_torque)
	if Input.is_action_pressed("ui_right"):
		apply_torque(Vector3.DOWN * yaw_torque)

	if dir != Vector3.ZERO:
		apply_central_force(dir.normalized() * force)

func _physics_process(delta):
	if shared.drone_controlled:
		move()

func _process(_delta):
	if drone_detector.bike_set.size() > 0:
		target_position = get_nearest_position(drone_detector.bike_set)

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
