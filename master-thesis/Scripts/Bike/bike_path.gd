extends Path3D

@export var route_file_path : String = "res://stages/stage-10-route.json"
@export var rl_route_file_path : String = "res://stages/rl-5k-straight-flat.json"

# Fully-built Curve3D objects cached across all instances.
# Building from add_point() in GDScript is slow (~5 s for large tracks);
# duplicate() of a pre-built Curve3D is a fast C++ array copy.
static var _curve_cache: Dictionary = {}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	self.curve.clear_points()
	load_coords()

func reload_for_rl() -> void:
	route_file_path = rl_route_file_path
	self.curve = _get_cached_curve(rl_route_file_path).duplicate()

# Pre-build and cache curves for a list of track paths so the first reset
# for each track is not slow. Call this once at startup before training begins.
func preload_tracks(paths: Array) -> void:
	for path in paths:
		_get_cached_curve(path)

func _get_cached_curve(path: String) -> Curve3D:
	if not _curve_cache.has(path):
		var c := Curve3D.new()
		for p in _parse_track_points(path):
			c.add_point(p)
		# Force bake now (in case duplicate() copies the baked cache).
		c.get_baked_length()
		_curve_cache[path] = c
	return _curve_cache[path]

# Parse a track JSON into a filtered Array[Vector3] and return it.
# Uses the same proximity/collinearity filters as load_coords().
func _parse_track_points(path: String) -> Array:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Could not open track file: " + path)
		return []
	var data = JSON.parse_string(file.get_as_text())
	var points: Array = []
	for point_data in data:
		var v = Vector3(point_data["lat"], point_data["elevation"], point_data["lon"])
		var n = points.size()
		if n > 0:
			if v.distance_to(points[n - 1]) < 0.1:
				continue
			if n > 1:
				var dir1 = (points[n - 1] - points[n - 2]).normalized()
				var dir2 = (v - points[n - 1]).normalized()
				if dir1.dot(dir2) > 0.99:
					points[n - 1] = v
					continue
		points.append(v)
	return points

func load_coords():
	var file = FileAccess.open(route_file_path, FileAccess.READ)
	if file == null:
		push_error("Could not open track file: " + route_file_path)
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

			# check if points are collinear — replace last point to keep the endpoint correct
			if i > 1:
				var prev_prev_point = self.curve.get_point_position(i - 2)
				var dir1 = (prev_point - prev_prev_point).normalized()
				var dir2 = (vectorPoint - prev_point).normalized()
				if dir1.dot(dir2) > 0.99:
					self.curve.set_point_position(i - 1, vectorPoint)
					continue

		self.curve.add_point(vectorPoint)
		i += 1
