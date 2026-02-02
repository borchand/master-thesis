extends Node3D


func _ready():
	pass # Replace with function body.

func _process(delta):
	# move bike forward
	translate(Vector3(0, 0, 1) * delta)
