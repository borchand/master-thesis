extends Node

var paused = false
var free_roam = false
var follow_drone = false
var drone_controlled = false
var follow_bike = false

		
func toggle_free_roam():
	free_roam = !free_roam
	if free_roam:
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)	
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func pause():
	paused = !paused
	get_tree().paused = paused

func toggle_drone():
	follow_bike = false
	follow_drone = !follow_drone

func toggle_bike():
	follow_drone = false
	follow_bike = !follow_bike
