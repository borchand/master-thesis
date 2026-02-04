extends Area3D
class_name DroneDetection

var bike_set := {}

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(bike: Node) -> void:
	if bike is Bike_body:
		bike_set[bike.bike_id] = bike

func _on_body_exited(bike: Node) -> void:
	if bike is Bike_body:
		bike_set.erase(bike.bike_id)
