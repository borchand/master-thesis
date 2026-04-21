extends Area3D
class_name DroneDetection

var bike_set := {}

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
	if body is Bike_body:
		bike_set[body.bike_id] = body
	


func _on_body_exited(bike: Node) -> void:
	if not is_instance_valid(bike):
		return
	if bike is Bike_body:
		bike_set.erase(bike.bike_id)
