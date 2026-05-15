extends Control

func _process(_delta):
	var instance_id = get_parent().InstanceId  
	
	$ProgressBarLeader.value = shared.GetProgressRatioOfBikeInPos(0, instance_id) * 100
	$ProgressBarBackMarker.value = shared.GetProgressRatioOfBikeInPos(shared.BikeLists[instance_id].size() - 1, instance_id) * 100
