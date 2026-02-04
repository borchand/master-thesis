extends Node

var paused = false
var free_roam = false
		
func toggle_free_roam():
	free_roam = !free_roam
	if free_roam:
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)	
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func pause():
	paused = !paused
	get_tree().paused = paused
