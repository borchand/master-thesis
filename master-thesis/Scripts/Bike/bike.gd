extends PathFollow3D

class_name Bike
signal freeing_bike

var rng = RandomNumberGenerator.new()
var speed = rng.randf_range(2.0, 6.0)
var max_progress: float

func _ready():
	max_progress = self.get_parent().curve.get_baked_length()
	
func _process(delta):
	# move bike forward
	self.progress += speed * delta

	if self.progress >= max_progress:
		# remove bike when it reaches the end of the path
		safe_queue_free()
	
func get_camera_node() -> Camera3D:
	return $Camera3D
	
func safe_queue_free() -> void:
	freeing_bike.emit(self)
	queue_free()
