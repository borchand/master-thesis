extends Node
class_name ReplayManager

# bike_id -> Array of { ts: int, pos: Vector3 }
var bike_data: Dictionary = {}
# drone_id -> Array of { ts: int, pos: Vector3, collisions: int, visible_bikes: Array[int] }
var drone_data: Dictionary = {}

# timestep -> Array[bike_id] sorted descending by cumulative distance (index 0 = leader)
var _bike_ranking: Dictionary = {}
var _sorted_timesteps: Array = []   # sorted list of all logged timesteps

var max_time: float = 0.0   # seconds of sim time
var bike_count: int = 0
var drone_count: int = 0
var stage: String = ""

var current_time: float = 0.0
var is_playing: bool = false
var playback_speed: float = 1.0

signal time_changed(new_time: float)
signal playback_state_changed(playing: bool)
signal load_complete()

# Physics tick rate at which logs were recorded (30 ticks/s → timestep 30 = 1 s)
const LOG_TICK_RATE: int = 30
const LOG_INTERVAL: int = 30  # drones log every 30 physics frames


func _get_logs_base_path() -> String:
	var base_path := ProjectSettings.globalize_path("res://").get_base_dir().get_base_dir()
	return base_path.path_join("logs")


# --- Streaming load API (used by replay_world for progress bar) ---

# Validates the run path, clears previous data, and returns an Array of
# { type: String, id: int, path: String } — one entry per CSV file.
# Returns an empty array on error.
func prepare_run(run_name: String) -> Array:
	bike_data.clear()
	drone_data.clear()
	_bike_ranking.clear()
	_sorted_timesteps.clear()
	stage = ""
	bike_count = 0
	drone_count = 0

	var logs_base = _get_logs_base_path()
	var bike_run_path = logs_base.path_join("bike").path_join(run_name)
	var drone_run_path = logs_base.path_join("drone").path_join(run_name)

	if not DirAccess.dir_exists_absolute(bike_run_path):
		push_error("Replay: bike run path not found: " + bike_run_path)
		return []

	var files: Array = []
	for vehicle_type in ["bike", "drone"]:
		var dir_path = logs_base.path_join(vehicle_type).path_join(run_name)
		var dir = DirAccess.open(dir_path)
		if not dir:
			continue
		dir.list_dir_begin()
		var fname = dir.get_next()
		while fname != "":
			if fname.ends_with(".csv") and fname.begins_with(vehicle_type + "_"):
				var vid = fname.trim_prefix(vehicle_type + "_").trim_suffix(".csv").to_int()
				files.append({"type": vehicle_type, "id": vid, "path": dir_path.path_join(fname)})
			fname = dir.get_next()
		dir.list_dir_end()

	return files


# Loads a single file returned by prepare_run().
func load_file(file_info: Dictionary):
	if file_info["type"] == "bike":
		_load_bike_file(file_info["path"], file_info["id"])
	else:
		_load_drone_file(file_info["path"], file_info["id"])


# Call after all load_file() calls to compute max_time and race rankings.
func finalize_run(run_name: String):
	var global_max_ts: int = 0
	for frames in bike_data.values():
		if frames.size() > 0:
			global_max_ts = max(global_max_ts, frames[-1]["ts"])
	for frames in drone_data.values():
		if frames.size() > 0:
			global_max_ts = max(global_max_ts, frames[-1]["ts"])

	max_time = float(global_max_ts) / float(LOG_TICK_RATE)
	current_time = 0.0
	is_playing = false

	_precompute_rankings()

	print(
		"ReplayManager: loaded %s — bikes=%d drones=%d stage=%s max_time=%.1fs"
		% [run_name, bike_data.size(), drone_data.size(), stage, max_time]
	)

func _precompute_rankings():
	# Collect all logged timesteps
	var ts_set: Dictionary = {}
	for frames in bike_data.values():
		for f in frames:
			ts_set[f["ts"]] = true
	_sorted_timesteps = ts_set.keys()
	_sorted_timesteps.sort()

	if _sorted_timesteps.is_empty():
		return

	# For each bike, track cumulative distance and its value at each logged ts
	var cum_dist: Dictionary = {}      # bike_id -> float
	var cum_at_ts: Dictionary = {}     # bike_id -> { ts -> float }
	var prev_pos: Dictionary = {}      # bike_id -> Vector3
	var frame_idx: Dictionary = {}     # bike_id -> current frame index

	for bike_id in bike_data:
		cum_dist[bike_id] = 0.0
		cum_at_ts[bike_id] = {}
		frame_idx[bike_id] = 0
		var frames = bike_data[bike_id]
		if frames.size() > 0:
			prev_pos[bike_id] = frames[0]["pos"]

	for ts in _sorted_timesteps:
		# Advance each bike's frame pointer to this timestep and accumulate distance
		for bike_id in bike_data:
			var frames = bike_data[bike_id]
			var fi: int = frame_idx[bike_id]
			while fi < frames.size() and frames[fi]["ts"] <= ts:
				var p = frames[fi]["pos"]
				if prev_pos.has(bike_id):
					cum_dist[bike_id] += prev_pos[bike_id].distance_to(p)
				prev_pos[bike_id] = p
				fi += 1
			frame_idx[bike_id] = fi
			cum_at_ts[bike_id][ts] = cum_dist[bike_id]

		# Sort bike IDs by descending cumulative distance → index 0 = leader
		var sorted_ids: Array = bike_data.keys().duplicate()
		sorted_ids.sort_custom(func(a, b):
			return cum_at_ts[a].get(ts, 0.0) > cum_at_ts[b].get(ts, 0.0)
		)
		_bike_ranking[ts] = sorted_ids


# Returns the bike_id of the bike currently in `race_pos` (1-based, 1 = leader).
func get_bike_id_at_position(race_pos: int, time_sec: float) -> int:
	if _sorted_timesteps.is_empty():
		return 1

	# Snap to the nearest logged timestep
	var ts = int(round(time_sec * LOG_TICK_RATE / float(LOG_INTERVAL))) * LOG_INTERVAL
	ts = clamp(ts, _sorted_timesteps[0], _sorted_timesteps[-1])

	var ranking: Array = _bike_ranking.get(ts, [])
	if ranking.is_empty():
		return 1
	var idx = clamp(race_pos - 1, 0, ranking.size() - 1)
	return ranking[idx]


func _load_vehicle_dir(dir_path: String, vehicle_type: String):
	var dir = DirAccess.open(dir_path)
	if not dir:
		push_error("Replay: could not open dir: " + dir_path)
		return
	dir.list_dir_begin()
	var fname = dir.get_next()
	while fname != "":
		if fname.ends_with(".csv") and fname.begins_with(vehicle_type + "_"):
			var id_str = fname.trim_prefix(vehicle_type + "_").trim_suffix(".csv")
			var vid = id_str.to_int()
			var full_path = dir_path.path_join(fname)
			if vehicle_type == "bike":
				_load_bike_file(full_path, vid)
			else:
				_load_drone_file(full_path, vid)
		fname = dir.get_next()
	dir.list_dir_end()


func _parse_metadata(line: String):
	# "Bikes: 180, Drones: 100, Stage: stage-1, Size: 60"
	for part in line.split(","):
		var kv = part.strip_edges().split(":")
		if kv.size() < 2:
			continue
		var key = kv[0].strip_edges()
		var val = kv[1].strip_edges()
		match key:
			"Bikes":   bike_count = val.to_int()
			"Drones":  drone_count = val.to_int()
			"Stage":   if stage == "": stage = val


func _load_bike_file(path: String, bike_id: int):
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return
	_parse_metadata(file.get_line())
	file.get_line()  # column header

	var frames: Array = []
	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		if line == "":
			continue
		var cols = line.split(",")
		if cols.size() < 4:
			continue
		frames.append({
			"ts":  cols[0].to_int(),
			"pos": Vector3(cols[1].to_float(), cols[2].to_float(), cols[3].to_float())
		})
	file.close()
	bike_data[bike_id] = frames


func _load_drone_file(path: String, drone_id: int):
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return
	_parse_metadata(file.get_line())
	file.get_line()  # column header

	var frames: Array = []
	while not file.eof_reached():
		var raw = file.get_line().strip_edges()
		if raw == "":
			continue

		# Split at the "[" to isolate the Bikes-ID list
		var bracket_pos = raw.find("[")
		var main_part = raw if bracket_pos < 0 else raw.substr(0, bracket_pos)
		var bikes_id_str = "" if bracket_pos < 0 else raw.substr(bracket_pos)

		var cols = main_part.split(",")
		if cols.size() < 5:
			continue

		var visible: Array[int] = []
		if bikes_id_str != "":
			var inner = bikes_id_str.strip_edges().trim_prefix("[").trim_suffix("]").strip_edges()
			for token in inner.split(" "):
				var t = token.strip_edges()
				if t != "":
					visible.append(t.to_int())

		frames.append({
			"ts":           cols[0].to_int(),
			"pos":          Vector3(cols[1].to_float(), cols[2].to_float(), cols[3].to_float()),
			"collisions":   cols[4].to_int(),
			"visible_bikes": visible
		})
	file.close()
	drone_data[drone_id] = frames


# --- Interpolation helpers ---

func get_bike_position(bike_id: int, time_sec: float) -> Vector3:
	if not bike_data.has(bike_id):
		return Vector3.ZERO
	return _lerp_position(bike_data[bike_id], time_sec)


func get_drone_state(drone_id: int, time_sec: float) -> Dictionary:
	if not drone_data.has(drone_id):
		return {"pos": Vector3.ZERO, "collisions": 0, "visible_bikes": []}
	var frames = drone_data[drone_id]
	if frames.is_empty():
		return {"pos": Vector3.ZERO, "collisions": 0, "visible_bikes": []}
	var idx = _find_frame_index(frames, time_sec)
	if idx < 0 or idx >= frames.size() - 1:
		var f = frames[clamp(idx, 0, frames.size() - 1)]
		return {"pos": f["pos"], "collisions": f["collisions"], "visible_bikes": f["visible_bikes"]}
	var f0 = frames[idx]
	var f1 = frames[idx + 1]
	var t = _lerp_t(f0["ts"], f1["ts"], time_sec)
	return {
		"pos":          f0["pos"].lerp(f1["pos"], t),
		"collisions":   f0["collisions"],
		"visible_bikes": f0["visible_bikes"]
	}


func _lerp_position(frames: Array, time_sec: float) -> Vector3:
	if frames.is_empty():
		return Vector3.ZERO
	var idx = _find_frame_index(frames, time_sec)
	if idx < 0:
		return frames[0]["pos"]
	if idx >= frames.size() - 1:
		return frames[-1]["pos"]
	var f0 = frames[idx]
	var f1 = frames[idx + 1]
	return f0["pos"].lerp(f1["pos"], _lerp_t(f0["ts"], f1["ts"], time_sec))


func _find_frame_index(frames: Array, time_sec: float) -> int:
	var ts = time_sec * LOG_TICK_RATE
	if ts <= frames[0]["ts"]:
		return 0
	if ts >= frames[-1]["ts"]:
		return frames.size() - 1

	# Direct index assuming even spacing of LOG_INTERVAL
	var first_ts: int = frames[0]["ts"]
	var est = int((ts - first_ts) / LOG_INTERVAL)
	est = clamp(est, 0, frames.size() - 2)

	# Verify and correct for any uneven spacing
	while est > 0 and frames[est]["ts"] > ts:
		est -= 1
	while est < frames.size() - 2 and frames[est + 1]["ts"] <= ts:
		est += 1
	return est


func _lerp_t(ts0: int, ts1: int, time_sec: float) -> float:
	if ts1 == ts0:
		return 0.0
	return clampf((time_sec * LOG_TICK_RATE - ts0) / float(ts1 - ts0), 0.0, 1.0)


# --- Playback controls ---

func _process(delta: float):
	if not is_playing:
		return
	current_time = minf(current_time + delta * playback_speed, max_time)
	time_changed.emit(current_time)
	if current_time >= max_time:
		is_playing = false
		playback_state_changed.emit(false)


func play():
	if current_time >= max_time:
		current_time = 0.0
	is_playing = true
	playback_state_changed.emit(true)


func pause():
	is_playing = false
	playback_state_changed.emit(false)


func toggle_play_pause():
	if is_playing:
		pause()
	else:
		play()


func step_forward():
	pause()
	current_time = minf(current_time + 1.0, max_time)
	time_changed.emit(current_time)


func step_backward():
	pause()
	current_time = maxf(current_time - 1.0, 0.0)
	time_changed.emit(current_time)


func jump_to_start():
	pause()
	current_time = 0.0
	time_changed.emit(current_time)


func jump_to_end():
	pause()
	current_time = max_time
	time_changed.emit(current_time)


func seek(time_sec: float):
	current_time = clampf(time_sec, 0.0, max_time)
	time_changed.emit(current_time)
