extends Area3D
class_name DroneCommunication

var drone_set := {}

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(drone: Node) -> void:
	if drone is Drone:
		drone_set[drone] = drone


func _on_body_exited(drone: Node) -> void:
	if drone is Drone:
		drone_set.erase(drone)
