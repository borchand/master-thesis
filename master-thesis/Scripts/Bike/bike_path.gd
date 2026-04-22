extends Path3D

@export var route_file_path : String = "res://stages/stage-12-route.json"
@export var rl_route_file_path : String = "res://stages/rl-test-track.json"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	self.curve.clear_points()
	load_coords()

func reload_for_rl() -> void:
	route_file_path = rl_route_file_path                                                                                
	self.curve = self.curve.duplicate()  # break the shared resource link                                             
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
			
			# check if points are collinear, if so skip it
			if i > 1:
				var prev_prev_point = self.curve.get_point_position(i - 2)
				var dir1 = (prev_point - prev_prev_point).normalized()
				var dir2 = (vectorPoint - prev_point).normalized()
				if dir1.dot(dir2) > 0.99:
					continue

		self.curve.add_point(vectorPoint)
		i += 1	
