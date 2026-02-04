extends Node

var paused = false
var mouse_movement_enabled = false
		
func toggle_mouse_movement():
	mouse_movement_enabled = !mouse_movement_enabled
	if mouse_movement_enabled:
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)	
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func pause():
	paused = !paused
	get_tree().paused = paused
