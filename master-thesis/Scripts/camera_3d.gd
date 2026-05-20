extends Camera3D

const camera_speed = 10.0

var mouse_sens = 0.2
var pitch_limit = 85.0 # degrees
@onready var yaw = rotation_degrees.y
@onready var pitch = rotation_degrees.x

var default_offset = Vector3(0, 20, 10)
var default_follow_camera_position = Vector3(0, 2.5, 3)
var target_bike_camera_position = default_follow_camera_position

func _process(delta):
	var instance_id = get_parent().instance_id
	var bikes = shared.bike_lists[instance_id]
	var drone_cameras = shared.drone_camera_lists[instance_id]

	# CAMERA CONTROLS
	if shared.follow_bike and not bikes.is_empty():

		if shared.follow_bike_in_pos >= bikes.size():
			shared.follow_bike_in_pos = bikes.size() - 1

		var bike_camera = shared.get_camera_of_bike_in_pos(shared.follow_bike_in_pos, instance_id)

		# if free roam is disabled reset camera rotation
		if not shared.free_roam:
			bike_camera.set_current(true)
			bike_camera.position = default_follow_camera_position
		else:
			set_current(true)

			if Input.is_key_pressed(KEY_W):
				target_bike_camera_position *= 0.95
			if Input.is_key_pressed(KEY_S):
				target_bike_camera_position *= 1.05

			bike_camera.position = target_bike_camera_position
			var offset = Vector3(0, 0, target_bike_camera_position.z).rotated(Vector3.UP, deg_to_rad(yaw))
			offset.y = target_bike_camera_position.y

			global_transform.origin = bike_camera.global_transform.origin + offset
			look_at(bike_camera.global_transform.origin, Vector3.UP)


	elif shared.follow_drone and not drone_cameras.is_empty():
		shared.followed_drone_index = int(shared.followed_drone_index)

		if shared.followed_drone_index >= drone_cameras.size():
			shared.followed_drone_index = drone_cameras.size() - 1

		if shared.followed_drone_index < 0:
			shared.followed_drone_index = 0

		var drone_camera = drone_cameras[shared.followed_drone_index]
		drone_camera.set_current(true)
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
				var bike_camera = shared.get_camera_of_bike_in_pos(shared.follow_bike_in_pos, instance_id)

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

	if event.is_action_released("toggle_follow_drone"):
		shared.toggle_drone()

	var instance_id = get_parent().instance_id
	var bikes = shared.bike_lists[instance_id]
	var drone_cameras = shared.drone_camera_lists[instance_id]

	if shared.follow_drone:
		if event.is_action_released("follow_next_bike"):
			shared.followed_drone_index = (shared.followed_drone_index + 1) % drone_cameras.size()

		if event.is_action_released("follow_prev_bike"):
			shared.followed_drone_index = (shared.followed_drone_index - 1 + drone_cameras.size()) % drone_cameras.size()


	if not bikes.is_empty():
		if event.is_action_released("follow_next_bike"):
			shared.follow_bike_in_pos = (shared.follow_bike_in_pos - 1 + bikes.size()) % bikes.size()

		if event.is_action_released("follow_prev_bike"):
			shared.follow_bike_in_pos = (shared.follow_bike_in_pos + 1) % bikes.size()
