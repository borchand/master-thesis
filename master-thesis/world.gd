extends Node3D

const bike = preload("res://Scenes/Bike/Bike.tscn")
const drone = preload("res://Drone.tscn")

var path_instance : Path3D
var drone_cameras = []

var bike_cameras = []
var follow_bike = false
var followed_bike_index = 0
const bike_count = 100

func _ready():	
	path_instance = $BikePath3d
	# load bike scene
	for i in range(bike_count):
		add_bike()
	add_drone(Vector3(0, 1, -1))
  
func _process(delta):
	# close game on escape
	if Input.is_key_pressed(KEY_ESCAPE):
		get_tree().quit()
		
	# CAMERA CONTROLS
	var camera = $Camera3D
	if follow_bike and not bike_cameras.is_empty():
		
		if followed_bike_index >= bike_cameras.size():
			followed_bike_index = bike_cameras.size() - 1
			
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
		if Input.is_key_pressed(KEY_C):
			camera.rotate_z(deg_to_rad(30) * delta)
		if Input.is_key_pressed(KEY_V):
			camera.rotate_z(deg_to_rad(-30) * delta)
		if Input.is_key_pressed(KEY_B):
			camera.rotate_x(deg_to_rad(30) * delta)
		if Input.is_key_pressed(KEY_N):
			camera.rotate_x(deg_to_rad(-30) * delta)
			
		# zoom camera on key press
		if Input.is_key_pressed(KEY_Z):
			camera.translate(Vector3(0, 0, -1) * delta * 5)
		if Input.is_key_pressed(KEY_X):
			camera.translate(Vector3(0, 0, 1) * delta * 5)

func _input(event):
	if event.is_action_released("toggle_follow_bike"):
		follow_bike = !follow_bike

	if follow_bike:
		if event.is_action_released("follow_next_bike"):
			followed_bike_index = (followed_bike_index + 1) % bike_cameras.size()
		
		if event.is_action_released("follow_prev_bike"):
			followed_bike_index = (followed_bike_index - 1 + bike_cameras.size()) % bike_cameras.size()

func add_drone(start_position: Vector3):
	var drone_instance = drone.instantiate()
	drone_instance.set_position(start_position)
	var drone_camera = drone_instance.get_node("Camera3D")
	drone_cameras.append(drone_camera)
	add_child(drone_instance)
	
func add_bike():
	# create bike instance
	var bike_instance = bike.instantiate()
	bike_instance.connect("freeing_bike", bike_freed)

	# get bike camera and add to list
	var bike_camera = bike_instance.get_camera_node()
	bike_cameras.append(bike_camera)
	
	# add bike to scene
	path_instance.add_child(bike_instance)

func bike_freed(freed_bike: Node3D):
	# remove bike camera from list when bike is freed
	var bike_camera = freed_bike.get_camera_node()
	bike_cameras.erase(bike_camera)
