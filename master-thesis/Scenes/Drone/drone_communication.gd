extends Area3D
class_name DroneCommunication

var drone_set := {}
var bike_set := {}

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
	if body is Drone:
		drone_set[body] = body
	elif body is Bike_body:
		bike_set[body] = body

func _on_body_exited(body: Node) -> void:
	if body is Drone:
		drone_set.erase(body)
	elif body is Bike_body:
		bike_set.erase(body)
