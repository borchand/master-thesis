extends Node3D

const bike = preload("res://Bike.tscn")
var follow_bike = true
var bike_cameras = []
var followed_bike_index = 0


func _ready():
	# load bike scene
	for i in 5:
		var start_position = Vector3(i, 0, 0)
		add_bike(start_position)

	
func _process(delta):
	var camera = $Camera3D
	if follow_bike:
		# get bike camera 
		var bike_camera = bike_cameras[followed_bike_index]
		bike_camera.set_current(true)
	else:
		camera.set_current(true)
		# move camera on key press
		if Input.is_key_pressed(KEY_W):
			camera.translate(Vector3(0, 1, 0) * delta * 5)
		if Input.is_key_pressed(KEY_S):
			camera.translate(Vector3(0, -1, 0) * delta * 5)
		if Input.is_key_pressed(KEY_A):
			camera.translate(Vector3(-1, 0, 0) * delta * 5)
		if Input.is_key_pressed(KEY_D):
			camera.translate(Vector3(1, 0, 0) * delta * 5)

		# rotate camera on key press
		if Input.is_key_pressed(KEY_Q):
			camera.rotate_y(deg_to_rad(30) * delta)
		if Input.is_key_pressed(KEY_E):
			camera.rotate_y(deg_to_rad(-30) * delta)

		# zoom camera on key press
		if Input.is_key_pressed(KEY_Z):
			camera.translate(Vector3(0, 0, -1) * delta * 5)
		if Input.is_key_pressed(KEY_X):
			camera.translate(Vector3(0, 0, 1) * delta * 5)


func _input(event):
	if event.is_action_released("toggle_follow_bike"):
		follow_bike = !follow_bike

	if event.is_action_released("follow_next_bike"):
		followed_bike_index = (followed_bike_index + 1) % bike_cameras.size()
	
	if event.is_action_released("follow_prev_bike"):
		followed_bike_index = (followed_bike_index - 1 + bike_cameras.size()) % bike_cameras.size()

func add_bike(start_position: Vector3):
	var bike_instance = bike.instantiate()
	bike_instance.position = start_position
	var bike_camera = bike_instance.get_node("Camera3D")
	bike_cameras.append(bike_camera)
	add_child(bike_instance)
