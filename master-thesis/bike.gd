extends Node3D

var pathFollow: PathFollow3D
var rng = RandomNumberGenerator.new()
var speed = rng.randf_range(2.0, 6.0)
var max_progress: float
func _ready():
	pathFollow = $Path3D/PathFollow3D
	max_progress = pathFollow.get_parent().curve.get_baked_length()
	print(max_progress)
	print(pathFollow.progress)
	

func _process(delta):
	# move bike forward
	pathFollow.progress += speed * delta
	if pathFollow.progress >= max_progress:
		# remove bike when it reaches the end of the path
		print(pathFollow.progress)
		queue_free()
		
	
func get_camera_node() -> Camera3D:
	return $Path3D/PathFollow3D/Camera3D
