extends StaticBody3D

class_name Bike_body

static var _next_id: int = 1
var bike_id: int

func _ready():
	bike_id = _next_id
	_next_id += 1
	add_to_group("bikes")
