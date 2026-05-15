extends StaticBody3D

class_name Bike_body

static var _next_id: int = 1
var bike_id: int
var timestep = 1

func _ready():
	bike_id = _next_id
	_next_id += 1
	add_to_group("bikes")
	if not get_parent().is_training:
		start_logging()

func _physics_process(_delta):
	if not get_parent().is_training and timestep % 30 == 0:
		log_information(timestep)
	timestep += 1

func create_logging_message(delta):
	var data = []
	
	data.append(str(delta))
	data.append(str(global_position.x))
	data.append(str(global_position.y))
	data.append(str(global_position.z))

	return data

func start_logging():
	logging.start_run_file(str(self.bike_id), "bike")

func log_information(delta):
	var message = create_logging_message(delta)
	logging.append_line(str(self.bike_id), "bike", message)
