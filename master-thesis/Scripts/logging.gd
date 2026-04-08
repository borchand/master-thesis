extends Node
class_name CustomLogger

func start_run_file(vehicle_id: String, vehicle_type: String):
	var base_path := ProjectSettings.globalize_path("res://").get_base_dir().get_base_dir()
	var folder_path := base_path.path_join("logs").path_join(vehicle_type)
	var file_path := folder_path.path_join("%s_%s.csv" % [vehicle_type, vehicle_id])
	var dir := DirAccess.open(base_path)
	var err := dir.make_dir_recursive("logs/" + vehicle_type)
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	
	if vehicle_type == "drone":
		file.store_line("Timestep, Pos x, Pos y, Pos z, Collisions")
	else:
		file.store_line("Timestep, Pos x, Pos y, Pos z")
	file.close()

func append_line(vehicle_id: String, vehicle_type: String, data):
	var base_path := ProjectSettings.globalize_path("res://").get_base_dir().get_base_dir()
	var folder_path := base_path.path_join("logs").path_join(vehicle_type)
	var file_path := folder_path.path_join("%s_%s.csv" % [vehicle_type, vehicle_id])
	var file := FileAccess.open(file_path, FileAccess.READ_WRITE)
	
	file.seek_end()
	file.store_line(", ".join(data))
	file.close()
