extends MenuBar

func _process(_delta):
	set_target_bike(shared.follow_bike_in_pos)

func _input(event):
	if event.is_action_released("mouse_movement_enabled"):
		toggle_mouse_movement()

	if event.is_action_released("pause"):
		toggle_pause()
		
	if event.is_action_released("free_roam"):
		toggle_free_roam()
	if event.is_action_released("close_game"):
		get_tree().quit()

func set_target_bike(value:int):
	var follow_bike_in_pos = $Panel/FollowBikeInPos
	follow_bike_in_pos.value = value

func toggle_mouse_movement():
	toggle_check_btn($Panel/MouseMovement)

func toggle_pause():
	toggle_check_btn($Panel/Pause)

func toggle_free_roam():
	toggle_check_btn($Panel/FreeRoam)

func toggle_check_btn(btn: CheckButton):
	btn.button_pressed = !btn.button_pressed

func _on_pause_toggled(_toggled_on):
	shared.pause()

func _on_free_roam_toggled(toggled_on):
	shared.toggle_free_roam()


func _on_follow_bike_in_pos_value_changed(value):
	shared.follow_bike_in_pos = value
	
