extends HSlider

@export var slider_multipliers: Array[float] = [.5, 1, 2, 4, 8, 16, 32, 64]

@export var label_prefix = "Time scale: " 

func _ready():
	var current_speed = Engine.time_scale
	_on_value_changed(current_speed)
	min_value = 0
	max_value = slider_multipliers.size() - 1
	tick_count = slider_multipliers.size()
	value_changed.connect(_on_value_changed)

	set_label(current_speed)

func _on_value_changed(new_value: int):
	var new_multiplier = slider_multipliers[new_value]
	
	Engine.time_scale = new_multiplier
	Engine.physics_ticks_per_second = int(new_multiplier * 30)
	
	set_label(new_multiplier)
	
func set_label(multiplier : float):
	$Label.text = label_prefix + str(multiplier)
