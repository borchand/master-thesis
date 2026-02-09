extends Camera3D

var drone_cameras = []
var bikes = []

var follow_bike = false

const camera_speed = 10.0

var mouse_sens = 0.2
var pitch_limit = 85.0 # degrees
@onready var yaw = rotation_degrees.y
@onready var pitch = rotation_degrees.x

var default_offset = Vector3(0, 20, 10)
	
func _process(delta):
	# CAMERA CONTROLS

	if follow_bike and not bikes.is_empty():
		
		if shared.follow_bike_in_pos >= bikes.size():
			shared.follow_bike_in_pos = bikes.size() - 1

		var bike_camera = get_camera_of_bike_in_pos(shared.follow_bike_in_pos)
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
			if not bikes.is_empty():
				var bike_camera = get_camera_of_bike_in_pos(shared.follow_bike_in_pos)

				if Input.is_key_pressed(KEY_W):
					default_offset *= 0.95
				if Input.is_key_pressed(KEY_S):
					default_offset *= 1.05

				global_transform.origin = bike_camera.global_transform.origin + default_offset
				# rotate to look at bike
				look_at(bike_camera.global_transform.origin, Vector3.UP)

func _input(event):
	if event is InputEventMouseMotion and shared.free_roam:
		yaw -= event.relative.x * mouse_sens
		pitch -= event.relative.y * mouse_sens
		pitch = clamp(pitch, -pitch_limit, pitch_limit)
		rotation_degrees = Vector3(pitch, yaw, 0)

	if event.is_action_released("toggle_follow_bike"):
		follow_bike = !follow_bike


	if event.is_action_released("follow_next_bike"):
		shared.follow_bike_in_pos = (shared.follow_bike_in_pos - 1 + bikes.size()) % bikes.size()

	if event.is_action_released("follow_prev_bike"):
		shared.follow_bike_in_pos = (shared.follow_bike_in_pos + 1) % bikes.size()


func get_camera_of_bike_in_pos(pos: int) -> Camera3D:
	var bike_progress = []
	
	for bike : Bike in bikes:
		var dict = {
			bike.progress: bike.get_camera_node()
		}
		bike_progress.append(dict)
		
	# sort by progress
	bike_progress.sort_custom(func(a, b):
		return a.keys()[0] > b.keys()[0]
	)
	
	return bike_progress[pos].values()[0]
