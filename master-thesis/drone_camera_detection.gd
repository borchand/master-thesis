extends Area3D

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(bike: Node) -> void:
	if bike is Bike_body:
		print("Bike entered: ", bike.bike_id)

func _on_body_exited(bike: Node) -> void:
	if bike is Bike_body:
		print("Bike exited: ", bike.bike_id)
