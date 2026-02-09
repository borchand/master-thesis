extends MenuBar

func _process(delta):
	if !shared.drone_controlled and $Panel/DroneControl.button_pressed:
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
		
	if event.is_action_released("close_game", true):
		get_tree().quit()

func toggle_mouse_movement():
	toggle_check_btn($Panel/MouseMovement)

func toggle_pause():
	toggle_check_btn($Panel/Pause)

func toggle_drone():
	toggle_check_btn($Panel/DroneControl)

func toggle_free_roam():
	toggle_check_btn($Panel/FreeRoam)

func toggle_check_btn(btn: CheckButton):
	btn.button_pressed = !btn.button_pressed

func _on_pause_toggled(_toggled_on):
	shared.pause()

func _on_free_roam_toggled(toggled_on):
	shared.toggle_free_roam()

func _on_drone_control_toggled(toggled_on):
	if !toggled_on == shared.follow_drone:
		shared.toggle_drone()
	shared.drone_controlled = toggled_on
