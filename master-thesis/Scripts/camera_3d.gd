extends Camera3D

var drone_cameras = []
var bike_cameras = []

var follow_bike = false
var followed_bike_index = 0

const camera_speed = 10.0

var mouse_sens = 0.2
var pitch_limit = 85.0 # degrees
@onready var yaw = rotation_degrees.y
@onready var pitch = rotation_degrees.x

var default_offset = Vector3(0, 20, 10)
	
func _process(delta):
	# CAMERA CONTROLS

	if follow_bike and not bike_cameras.is_empty():
		
		if followed_bike_index >= bike_cameras.size():
			followed_bike_index = bike_cameras.size() - 1
			
		# get bike camera 
		var bike_camera = bike_cameras[followed_bike_index]
		bike_camera.set_current(true)
	else:
		set_current(true)
		if shared.free_roam:
			var speed_multiplier = 1.0
			if Input.is_key_pressed(KEY_SHIFT):
				speed_multiplier = 10.0
			elif Input.is_key_pressed(KEY_CTRL):
				speed_multiplier = 0.3

			# move camera on key press
			if Input.is_key_pressed(KEY_W):
				translate(Vector3(0, 0, -1) * delta * camera_speed * speed_multiplier)
			if Input.is_key_pressed(KEY_S):
				translate(Vector3(0, 0, 1) * delta * camera_speed * speed_multiplier)
			if Input.is_key_pressed(KEY_A):
				translate(Vector3(-1, 0, 0) * delta * camera_speed * speed_multiplier)
			if Input.is_key_pressed(KEY_D):
				translate(Vector3(1, 0, 0) * delta * camera_speed * speed_multiplier)
		else:
			if not bike_cameras.is_empty():
				var first_bike_camera = bike_cameras[0]

				if Input.is_key_pressed(KEY_W):
					default_offset *= 0.95
				if Input.is_key_pressed(KEY_S):
					default_offset *= 1.05



				global_transform.origin = first_bike_camera.global_transform.origin + default_offset
				# rotate to look at bike
				look_at(first_bike_camera.global_transform.origin, Vector3.UP)

func _input(event):
	if event is InputEventMouseMotion and shared.free_roam:
		yaw -= event.relative.x * mouse_sens
		pitch -= event.relative.y * mouse_sens
		pitch = clamp(pitch, -pitch_limit, pitch_limit)
		rotation_degrees = Vector3(pitch, yaw, 0)

	if event.is_action_released("toggle_follow_bike"):
		follow_bike = !follow_bike

	if follow_bike:
		if event.is_action_released("follow_next_bike"):
			followed_bike_index = (followed_bike_index + 1) % bike_cameras.size()
		
		if event.is_action_released("follow_prev_bike"):
			followed_bike_index = (followed_bike_index - 1 + bike_cameras.size()) % bike_cameras.size()
