extends Node3D

# Change this constant to replay a different run.
@export var REPLAY_RUN: String = "run_1"

# Registered with `shared` so camera_3d.gd can access instance_id safely.
var instance_id: int = -1

var replay_manager: ReplayManager

# Visual nodes
var bike_nodes: Dictionary = {}   # bike_id  -> MeshInstance3D
var drone_nodes: Dictionary = {}  # drone_id -> MeshInstance3D

# Shared materials (per-drone material_override swap — no material mutation)
var _bike_mat: StandardMaterial3D
var _drone_mat_ok: StandardMaterial3D
var _drone_mat_collision: StandardMaterial3D

# Camera follow state
var _follow_enabled: bool = false
var _follow_type: String = "bike"   # "bike" or "drone"
var _follow_id: int = 1
var _camera_offset: Vector3 = Vector3(0, 20, 15)

# UI references built in _ready()
var _play_pause_btn: Button
var _timeline: HSlider
var _time_label: Label
var _speed_label: Label
var _speed_slider: HSlider
var _follow_check: CheckButton
var _follow_type_btn: Button
var _follow_id_spin: SpinBox
var _follow_spin_label: Label
var _updating_slider: bool = false   # guard against signal feedback loop
var _loading_overlay: CanvasLayer
var _loading_label: Label
var _loading_bar: ProgressBar


func _ready():
	instance_id = shared.register_instance()
	shared.free_roam = true

	replay_manager = ReplayManager.new()
	add_child(replay_manager)

	_create_materials()
	_show_loading_screen()

	# Wait two render frames so the loading screen actually appears before blocking.
	await get_tree().process_frame
	await get_tree().process_frame
	_load_and_init()


func _show_loading_screen():
	_loading_overlay = CanvasLayer.new()
	_loading_overlay.layer = 100
	add_child(_loading_overlay)

	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.08, 0.08, 0.08, 0.95)
	_loading_overlay.add_child(bg)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_loading_overlay.add_child(center)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	vbox.custom_minimum_size = Vector2(500, 0)
	center.add_child(vbox)

	var title = Label.new()
	title.text = "Loading replay…"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	vbox.add_child(title)

	_loading_bar = ProgressBar.new()
	_loading_bar.min_value = 0
	_loading_bar.max_value = 1
	_loading_bar.value = 0
	_loading_bar.show_percentage = true
	_loading_bar.custom_minimum_size = Vector2(0, 24)
	vbox.add_child(_loading_bar)

	_loading_label = Label.new()
	_loading_label.text = "Run: %s" % REPLAY_RUN
	_loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading_label.add_theme_font_size_override("font_size", 18)
	_loading_label.modulate = Color(0.7, 0.7, 0.7)
	vbox.add_child(_loading_label)


func _load_and_init():
	_loading_label.text = "Scanning run folder…"
	await get_tree().process_frame

	var files = replay_manager.prepare_run(REPLAY_RUN)
	if files.is_empty():
		_loading_label.text = "ERROR: could not find run '%s'" % REPLAY_RUN
		push_error("ReplayWorld: failed to load run '%s'" % REPLAY_RUN)
		return

	var total: int = files.size()
	_loading_bar.max_value = total
	_loading_bar.value = 0

	# Load files in small batches, yielding a frame between each batch
	# so the progress bar actually updates on screen.
	const BATCH_SIZE = 8
	for i in total:
		replay_manager.load_file(files[i])
		_loading_bar.value = i + 1
		_loading_label.text = "Loading files… %d / %d" % [i + 1, total]
		if (i + 1) % BATCH_SIZE == 0:
			await get_tree().process_frame

	_loading_label.text = "Computing race rankings…"
	_loading_bar.value = total
	await get_tree().process_frame

	replay_manager.finalize_run(REPLAY_RUN)

	_loading_label.text = "Building scene…"
	await get_tree().process_frame

	# Always load the track from the log metadata, not from scene defaults.
	var stage_path = "res://stages/%s-route.json" % replay_manager.stage
	var path_node = $BikePath3d
	path_node.curve.clear_points()
	path_node.route_file_path = stage_path
	path_node.load_coords()

	_spawn_bikes()
	_spawn_drones()
	_build_ui()

	replay_manager.time_changed.connect(_on_time_changed)
	replay_manager.playback_state_changed.connect(_on_playback_state_changed)

	_loading_overlay.queue_free()
	_loading_overlay = null


func _create_materials():
	_bike_mat = StandardMaterial3D.new()
	_bike_mat.albedo_color = Color(0.9, 0.2, 0.2)

	_drone_mat_ok = StandardMaterial3D.new()
	_drone_mat_ok.albedo_color = Color(0.2, 0.5, 0.95)

	_drone_mat_collision = StandardMaterial3D.new()
	_drone_mat_collision.albedo_color = Color(1.0, 0.5, 0.0)


func _spawn_bikes():
	var mesh = CapsuleMesh.new()
	mesh.radius = 0.3
	mesh.height = 1.2

	for bike_id in replay_manager.bike_data.keys():
		var node = MeshInstance3D.new()
		node.mesh = mesh
		node.material_override = _bike_mat
		node.name = "ReplayBike_%d" % bike_id
		add_child(node)
		node.global_position = replay_manager.get_bike_position(bike_id, 0.0)
		bike_nodes[bike_id] = node


func _spawn_drones():
	var mesh = BoxMesh.new()
	mesh.size = Vector3(0.7, 0.35, 0.7)

	for drone_id in replay_manager.drone_data.keys():
		var node = MeshInstance3D.new()
		node.mesh = mesh
		node.name = "ReplayDrone_%d" % drone_id
		add_child(node)
		var state = replay_manager.get_drone_state(drone_id, 0.0)
		node.global_position = state["pos"]
		node.material_override = _drone_mat_ok
		drone_nodes[drone_id] = node


func _process(_delta: float):
	var t = replay_manager.current_time

	for bike_id in bike_nodes:
		var frames: Array = replay_manager.bike_data[bike_id]
		var active = frames.size() > 0 and t <= frames[-1]["ts"] / float(ReplayManager.LOG_TICK_RATE)
		bike_nodes[bike_id].visible = active
		if active:
			bike_nodes[bike_id].global_position = replay_manager.get_bike_position(bike_id, t)

	for drone_id in drone_nodes:
		var frames: Array = replay_manager.drone_data[drone_id]
		var active = frames.size() > 0 and t <= frames[-1]["ts"] / float(ReplayManager.LOG_TICK_RATE)
		drone_nodes[drone_id].visible = active
		if active:
			var state = replay_manager.get_drone_state(drone_id, t)
			drone_nodes[drone_id].global_position = state["pos"]
			drone_nodes[drone_id].material_override = (
				_drone_mat_collision if state["collisions"] > 0 else _drone_mat_ok
			)

	_update_follow_camera()


func _update_follow_camera():
	if not _follow_enabled:
		return

	var target_pos: Vector3
	if _follow_type == "bike":
		# _follow_id is race position (1 = leader); resolve to bike_id each frame
		var bike_id = replay_manager.get_bike_id_at_position(_follow_id, replay_manager.current_time)
		if not bike_nodes.has(bike_id):
			return
		target_pos = bike_nodes[bike_id].global_position
	elif _follow_type == "drone":
		# _follow_id is drone ID directly
		if not drone_nodes.has(_follow_id):
			return
		target_pos = drone_nodes[_follow_id].global_position
	else:
		return

	var cam: Camera3D = $Camera3D
	cam.global_position = target_pos + _camera_offset
	cam.look_at(target_pos, Vector3.UP)


# --- UI signals ---

func _on_time_changed(new_time: float):
	if _time_label:
		_time_label.text = "Time: %.1fs / %.1fs   (ts %d)" % [
			new_time, replay_manager.max_time, int(new_time * 30)
		]
	if _timeline and not _updating_slider:
		_updating_slider = true
		_timeline.value = new_time
		_updating_slider = false


func _on_playback_state_changed(playing: bool):
	if _play_pause_btn:
		_play_pause_btn.text = "⏸" if playing else "▶"


# --- UI builder ---

func _build_ui():
	var canvas = CanvasLayer.new()
	canvas.layer = 10
	add_child(canvas)

	var panel = _make_panel()
	canvas.add_child(panel)


func _make_panel() -> Control:
	var panel = Panel.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_top = -160.0
	panel.process_mode = Node.PROCESS_MODE_ALWAYS

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	# --- Info row ---
	var info_row = HBoxContainer.new()
	vbox.add_child(info_row)

	var run_lbl = Label.new()
	run_lbl.text = "  Run: %s   |   Bikes: %d   Drones: %d   Stage: %s" % [
		REPLAY_RUN, replay_manager.bike_count,
		replay_manager.drone_count, replay_manager.stage
	]
	run_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_row.add_child(run_lbl)

	# --- Controls row ---
	var ctrl_row = HBoxContainer.new()
	ctrl_row.add_theme_constant_override("separation", 6)
	vbox.add_child(ctrl_row)

	var jump_start = _make_btn("|◀", func(): replay_manager.jump_to_start())
	var step_back  = _make_btn("◀",  func(): replay_manager.step_backward())
	_play_pause_btn = _make_btn("▶", func(): replay_manager.toggle_play_pause())
	var step_fwd   = _make_btn("▶",  func(): replay_manager.step_forward())
	var jump_end   = _make_btn("▶|", func(): replay_manager.jump_to_end())

	for btn in [jump_start, step_back, _play_pause_btn, step_fwd, jump_end]:
		ctrl_row.add_child(btn)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ctrl_row.add_child(spacer)

	_time_label = Label.new()
	_time_label.text = "Time: 0.0s / %.1fs   (ts 0)" % replay_manager.max_time
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ctrl_row.add_child(_time_label)

	# --- Timeline ---
	_timeline = HSlider.new()
	_timeline.min_value = 0.0
	_timeline.max_value = replay_manager.max_time
	_timeline.step = 0.033
	_timeline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_timeline.value_changed.connect(_on_timeline_changed)
	vbox.add_child(_timeline)

	# --- Speed row ---
	var speed_row = HBoxContainer.new()
	speed_row.add_theme_constant_override("separation", 6)
	vbox.add_child(speed_row)

	var speed_lbl = Label.new()
	speed_lbl.text = "  Speed:"
	speed_row.add_child(speed_lbl)

	_speed_slider = HSlider.new()
	_speed_slider.min_value = 0.1
	_speed_slider.max_value = 8.0
	_speed_slider.step = 0.1
	_speed_slider.value = 1.0
	_speed_slider.custom_minimum_size = Vector2(200, 0)
	_speed_slider.value_changed.connect(_on_speed_changed)
	speed_row.add_child(_speed_slider)

	_speed_label = Label.new()
	_speed_label.text = "1.0x"
	_speed_label.custom_minimum_size = Vector2(50, 0)
	speed_row.add_child(_speed_label)

	var hint = Label.new()
	hint.text = "  [Space] play/pause   [←/→] step   [F] free-roam"
	hint.modulate = Color(0.7, 0.7, 0.7)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	speed_row.add_child(hint)

	# --- Follow row ---
	var follow_row = HBoxContainer.new()
	follow_row.add_theme_constant_override("separation", 6)
	vbox.add_child(follow_row)

	_follow_check = CheckButton.new()
	_follow_check.text = "Follow:"
	_follow_check.toggled.connect(_on_follow_toggled)
	follow_row.add_child(_follow_check)

	_follow_type_btn = Button.new()
	_follow_type_btn.text = "Bike"
	_follow_type_btn.custom_minimum_size = Vector2(70, 0)
	_follow_type_btn.pressed.connect(_on_follow_type_pressed)
	follow_row.add_child(_follow_type_btn)

	_follow_id_spin = SpinBox.new()
	_follow_id_spin.min_value = 1
	_follow_id_spin.max_value = replay_manager.bike_count  # bikes follow by position
	_follow_id_spin.value = 1
	_follow_id_spin.custom_minimum_size = Vector2(80, 0)
	_follow_id_spin.value_changed.connect(_on_follow_id_changed)
	follow_row.add_child(_follow_id_spin)

	_follow_spin_label = Label.new()
	_follow_spin_label.text = "(1 = leader)"
	follow_row.add_child(_follow_spin_label)

	var sep = Label.new()
	sep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	follow_row.add_child(sep)

	return panel


func _make_btn(label: String, callback: Callable) -> Button:
	var btn = Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(48, 0)
	btn.pressed.connect(callback)
	return btn


func _on_timeline_changed(value: float):
	if _updating_slider:
		return
	replay_manager.seek(value)


func _on_speed_changed(value: float):
	replay_manager.playback_speed = value
	if _speed_label:
		_speed_label.text = "%.1fx" % value


func _on_follow_toggled(on: bool):
	_follow_enabled = on
	# When following, disable free-roam so camera_3d.gd's WASD doesn't fight us.
	# When released, restore free-roam so the user can navigate manually.
	shared.free_roam = not on


func _on_follow_type_pressed():
	_follow_type = "drone" if _follow_type == "bike" else "bike"
	_follow_type_btn.text = "Drone" if _follow_type == "drone" else "Bike"
	if _follow_type == "drone":
		_follow_id_spin.max_value = replay_manager.drone_count
		_follow_spin_label.text = "(ID)"
	else:
		_follow_id_spin.max_value = replay_manager.bike_count
		_follow_spin_label.text = "(1 = leader)"
	_follow_id_spin.value = clamp(_follow_id_spin.value, 1, _follow_id_spin.max_value)


func _on_follow_id_changed(value: float):
	_follow_id = int(value)


# Keyboard shortcuts
func _unhandled_input(event: InputEvent):
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE:
				replay_manager.toggle_play_pause()
			KEY_LEFT:
				replay_manager.step_backward()
			KEY_RIGHT:
				replay_manager.step_forward()
