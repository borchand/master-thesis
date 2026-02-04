extends Path3D

@export var file_path : String = "res://stages/stage-1-route.json"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	self.curve.clear_points()
	load_coords()
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass

func load_coords():
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		print("Some error fix later")
		return

	var json_text = file.get_as_text()
	var data = JSON.parse_string(json_text)

	for point in data:
		var lat = point["lat"]
		var lon = point["lon"]
		var elevation = point["elevation"]
		self.curve.add_point(Vector3(lat, elevation, lon))
