extends Control

func _process(_delta):
	var instance_id = get_parent().instance_id  
	
	$ProgressBarLeader.value = shared.get_progress_ratio_of_bike_in_pos(0, instance_id) * 100
	$ProgressBarBackMarker.value = shared.get_progress_ratio_of_bike_in_pos(shared.bike_lists[instance_id].size() - 1, instance_id) * 100
