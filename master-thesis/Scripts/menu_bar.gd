extends Panel

func _process(_delta):
	set_target_bike(shared.follow_bike_in_pos)

	if !shared.drone_controlled and $ToggleContainer/DroneControl.button_pressed:
		toggle_drone()

func _input(event):
	if event.is_action_released("mouse_movement_enabled", true):
		toggle_mouse_movement()

	if event.is_action_released("pause", true):
		toggle_pause()

	if event.is_action_released("drone_control", true):
		toggle_drone()

	if event.is_action_released("free_roam", true):
		if shared.follow_drone:
			toggle_drone()
		toggle_free_roam()

	if event.is_action_released("toggle_follow_"):
		toggle_follow_bike()
		
	if event.is_action_released("close_game", true):
		get_tree().quit()
		

func set_target_bike(value:int):
	
	var follow_bike_in_pos = $OtherContainer/FollowBikeInPos
	follow_bike_in_pos.value = value

func toggle_follow_bike():
	toggle_check_btn($ToggleContainer/FollowBike)

func toggle_mouse_movement():
	toggle_check_btn($ToggleContainer/MouseMovement)

func toggle_pause():
	toggle_check_btn($ToggleContainer/Pause)

func toggle_drone():
	toggle_check_btn($ToggleContainer/DroneControl)

func toggle_free_roam():
	toggle_check_btn($ToggleContainer/FreeRoam)

func toggle_check_btn(btn: CheckButton):
	btn.button_pressed = !btn.button_pressed

func _on_pause_toggled(_toggled_on):
	shared.pause()

func _on_free_roam_toggled(_toggled_on):
	shared.toggle_free_roam()

func _on_follow_bike_in_pos_value_changed(value):
	shared.follow_bike_in_pos = value

func _on_drone_control_toggled(toggled_on):
	if !toggled_on == shared.follow_drone:
		shared.toggle_drone()
	shared.drone_controlled = toggled_on

func _on_follow_bike_toggled(_toggled_on):
	shared.toggle_bike()
	
