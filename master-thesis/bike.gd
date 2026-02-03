extends Node3D

signal freeing_bike

var pathFollow: PathFollow3D
var rng = RandomNumberGenerator.new()
var speed = rng.randf_range(2.0, 6.0)
var max_progress: float

func _ready():
	pathFollow = $Path3D/PathFollow3D
	max_progress = pathFollow.get_parent().curve.get_baked_length()
	
func _process(delta):
	# move bike forward
	pathFollow.progress += speed * delta

	if pathFollow.progress >= max_progress:
		# remove bike when it reaches the end of the path
		safe_queue_free()
		
	
func get_camera_node() -> Camera3D:
	return $Path3D/PathFollow3D/Camera3D
	
func safe_queue_free() -> void:
	freeing_bike.emit(self)
	queue_free()
