extends Node
class_name CustomLogger

var logging = false
var current_run_folders := {}

var bikes = ""
var drones = ""
var track = ""
var size = ""

func add_info(bikes_, drones_, track_, size_):
	if logging:
		bikes = str(bikes_)
		drones = str(drones_)
		track = track_.replace("res://stages/", "").replace("-route.json", "")
		size = size_
	
func _get_logs_base_path():
	var base_path := ProjectSettings.globalize_path("res://").get_base_dir().get_base_dir()
	return base_path.path_join("logs")

func _get_next_run_folder(vehicle_type: String):
	if logging:
		var logs_base = _get_logs_base_path()
		var type_folder = logs_base.path_join(vehicle_type)

		DirAccess.make_dir_recursive_absolute(type_folder)

		var index = 1
		while true:
			var candidate = type_folder.path_join("run_%d" % [index])
			if not DirAccess.dir_exists_absolute(candidate):
				DirAccess.make_dir_recursive_absolute(candidate)
				return candidate
			index += 1

		return ""

func start_new_run(vehicle_type: String):
	var run_folder = _get_next_run_folder(vehicle_type)
	current_run_folders[vehicle_type] = run_folder

func start_run_file(vehicle_id: String, vehicle_type: String):
	if logging:
		if not current_run_folders.has(vehicle_type):
			start_new_run(vehicle_type)

		var run_folder = current_run_folders[vehicle_type]
		var file_path = run_folder.path_join("%s_%s.csv" % [vehicle_type, vehicle_id])
		var file = FileAccess.open(file_path, FileAccess.WRITE)
		
		file.store_line("Bikes: %s, Drones: %s, Stage: %s, Size: %s" % [bikes, drones, track, size])
		if vehicle_type == "drone":
			file.store_line("Timestep, Pos x, Pos y, Pos z, Collisions, Bikes-ID")
		else:
			file.store_line("Timestep, Pos x, Pos y, Pos z")

		file.close()

func append_line(vehicle_id: String, vehicle_type: String, data):
	if logging:
		var run_folder = current_run_folders[vehicle_type]
		var file_path = run_folder.path_join("%s_%s.csv" % [vehicle_type, vehicle_id])
		var file = FileAccess.open(file_path, FileAccess.READ_WRITE)

		file.seek_end()
		file.store_line(",".join(data))
		file.close()

func _get_run_name(run_folder: String) -> String:
	return run_folder.get_file()

func log_bike_finish_time(
	finish_time: float,
):
	if not logging:
		return

	var vehicle_type = "bike_finish_time"

	if not current_run_folders.has(vehicle_type):
		start_new_run(vehicle_type)

	var run_folder = current_run_folders[vehicle_type]

	var file_path = run_folder.path_join(
		"%s_results.csv" % vehicle_type
	)

	var file_exists = FileAccess.file_exists(file_path)

	var file = FileAccess.open(
		file_path,
		FileAccess.READ_WRITE if file_exists else FileAccess.WRITE
	)

	if not file_exists:
		file.store_line(
			"Bikes: %s, Drones: %s, Stage: %s, Size: %s"
			% [bikes, drones, track, size]
		)

		file.store_line("Run, Finish Time")

	file.seek_end()

	file.store_line(
		"%.4f"
		% [finish_time]
	)

	file.close()
