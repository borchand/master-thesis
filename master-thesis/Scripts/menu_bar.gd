extends MenuBar

func _input(event):
	if event.is_action_released("mouse_movement_enabled"):
		toggle_mouse_movement()

	if event.is_action_released("pause"):
		toggle_pause()
		
	if event.is_action_released("close_game"):
		get_tree().quit()

func toggle_mouse_movement():
	$Panel/MouseMovement.button_pressed = !$Panel/MouseMovement.button_pressed

func toggle_pause():
	$Panel/Pause.button_pressed = !$Panel/Pause.button_pressed

func _on_pause_toggled(toggled_on):
	shared.pause()


func _on_mouse_movement_toggled(toggled_on):
	shared.toggle_mouse_movement()
