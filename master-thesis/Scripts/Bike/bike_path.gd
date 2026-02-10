extends Path3D

@export var route_file_path : String = "res://stages/stage-1-route.json"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	self.curve.clear_points()
	load_coords()

func load_coords():
	var file = FileAccess.open(route_file_path, FileAccess.READ)
	if file == null:
		print("Some error fix later")
		return

	var json_text = file.get_as_text()
	var data = JSON.parse_string(json_text)
	
	var i = 0
	for point in data:
		var lat = point["lat"]
		var lon = point["lon"]
		var elevation = point["elevation"]

		var vectorPoint = Vector3(lat, elevation, lon)

		# check if point is to close to previous point, if so skip it
		if i > 0:
			var prev_point = self.curve.get_point_position(i - 1)
			if vectorPoint.distance_to(prev_point) < 0.1:
				continue

		self.curve.add_point(vectorPoint)
		i += 1	
