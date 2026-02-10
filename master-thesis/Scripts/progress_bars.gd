extends Control

func _process(delta):
	$ProgressBarLeader.value = shared.get_progress_ratio_of_bike_in_pos(0) * 100
	$ProgressBarBackMarker.value = shared.get_progress_ratio_of_bike_in_pos(shared.bikes.size() - 1) * 100
