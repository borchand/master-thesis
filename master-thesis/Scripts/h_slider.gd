extends HSlider

@export var slider_multipliers: Array[float] = [.5, 1, 2, 10, 20, 100]

@export var label_prefix = "Time scale: " 

func _ready():
	var current_speed = Engine.time_scale
	min_value = 0
	max_value = slider_multipliers.size() - 1
	tick_count = slider_multipliers.size()
	value_changed.connect(_on_value_changed)
	
	var _multiplier_idx = slider_multipliers.find(current_speed)
	
	set_label(current_speed)

func _on_value_changed(new_value: int):
	var new_multiplier = slider_multipliers[new_value]
	
	Engine.time_scale = new_multiplier
	
	set_label(new_multiplier)
	
	
	
	
func set_label(multiplier : float):
	$Label.text = label_prefix + str(multiplier)
	
	
