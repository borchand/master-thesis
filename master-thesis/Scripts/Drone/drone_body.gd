extends RigidBody3D

@onready var drone_detector: DroneDetection = $"Camera_detection"
@onready var target_position = global_position

var speed: float = 1

func _ready():
	pass

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
