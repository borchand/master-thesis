extends PathFollow3D

class_name Bike
signal freeing_bike

@onready var bikebody = $BikeBody
var world
var race_index: int
var rng = RandomNumberGenerator.new()
var max_progress: float

var pr_sec_checks = 4
var timer_threashold = 1.0 / pr_sec_checks
var timer = 0
var total_time = 0

var is_rl: bool = false
var is_training: bool = false

var speed = 9.0
var speedUpProbability := 5.0
var speedDownProbability := 4.5
var acceleration = 0.0

var sustainable_watt = null
var initial_breakout_watt = null
var a_fatigue_resistence = 0.00003
var fatigue_threashold = 52800.0
var b_stamina_degresse = 0.0000002
var fatigue = 0
var in_peloton = false
var pelotonleader = false
var behavior = "cruise"  #cruise, attack

var cohesion_c :=  0.8    #Set by trial and error
var separation_c := 0.01  #0.05   #Set by trial and error 
var n_breakouts = 0
var max_speed = 0

func _ready():
	max_progress = self.get_parent().curve.get_baked_length()
	world = get_parent().get_parent()

var printCheck = true

func _physics_process(delta):
	if printCheck:
		printCheck = false
		print(sustainable_watt, " ", initial_breakout_watt, " ", cohesion_c, " ", separation_c, " ", speedUpProbability, " ", speedDownProbability)
	timer += delta
	total_time += delta
	if timer >= timer_threashold:
		timer = timer-timer_threashold
		coltroler(timer_threashold)
		
	if speed>max_speed:
		max_speed=speed
	self.progress += speed * delta
	if self.progress >= max_progress:
		if not is_rl:
			print("Bike: ", self.name, " Finish time: ", total_time, " nBreakout: ", n_breakouts, "  Max_speed: ", max_speed)
		safe_queue_free()

func coltroler(delta):
	#control1(delta)
	control1(delta)

#Controller1
func control1(delta):
	var elevation = -1 * bikebody.global_rotation.x #positive = going up
	var wanted_power  = sustainable_watt

	var neighborhood_result = find_neighborhood()
	
	if len(neighborhood_result) != 5:
		print("Ray_cast length is not 5")
		return
	if neighborhood_result[0] == 0 or neighborhood_result[2] > 6 or progress_ratio >= 0.985: #you left the peleton or are in front
		in_peloton = false
		if neighborhood_result[4] != null and neighborhood_result[4]<3:
			pelotonleader = true
		else:
			pelotonleader = false
	else:
		in_peloton = true

	behaviorChange(delta, elevation)
	if behavior == "cruise":
		wanted_power = cruise(elevation, neighborhood_result)
	elif  behavior == "attack":
		wanted_power = attack()

	var atcual_power = wanted_power
	if wanted_power > sustainable_watt:
		atcual_power = min(max_possible_power(), wanted_power)

	acceleration = acceleration_based_on_speed(speed, elevation, atcual_power, in_peloton)
	fatigue_changes(atcual_power)

	speed = max(0.5, speed + acceleration * delta)

func cruise(_elevation_, ray_hits):
	if not in_peloton:
		return solo()
	var dist_to_center = ray_hits[1]
	var dist_to_1 = ray_hits[2]
	var dist_to_3 = ray_hits[3]
	if dist_to_center != null:
		var sep_mod = 0
		if dist_to_3 != null:
			sep_mod = 1 / max(0.5, dist_to_3)   #something high
		elif dist_to_1 != null:
			sep_mod = 1/ max(0.5, dist_to_1)  #something high

		var additional_force_amplification = dist_to_center * cohesion_c -  sep_mod * separation_c
		return sustainable_watt*0.7*additional_force_amplification
	else:
		print("shouldn't happen")
		return

func attack():
	return initial_breakout_watt

func solo():
	return sustainable_watt

func behaviorChange(delta, elevation_):
	if self.sustainable_watt>390 and self.progress_ratio > 0.985 and behavior != "attack":
		behavior = "attack"
		return

	if behavior == "attack" and self.progress_ratio <= 0.985:
		if elevation_ < 0 or rng.randi_range(0, 1000) < speedDownProbability * delta:
			behavior = "cruise"
			return

	if behavior == "cruise" and elevation_ > 0.017: # 0.09 rad is 5%
		if rng.randi_range(0,10000) < (speedUpProbability * (elevation_ / 0.034) * delta) / max(1-progress_ratio, 0.15): # max(1-progress_ratio, 0.15):
			behavior = "attack"
			n_breakouts += 1
	
func fatigue_changes(current_watt):
	if current_watt == sustainable_watt:
		return
	fatigue = max(0, fatigue + current_watt - sustainable_watt)


#Helper Functions
func calc_watt_current_state(speed_ms, elevation, acceleration_mss, in_peloton_=false):
	#see acceleration_based_on_speed for constant explain
	var drag_modifier = 1
	if in_peloton_:
		drag_modifier = 0.7
	elif pelotonleader:
		drag_modifier = 0.85
	return 72.68 * (acceleration_mss + 0.00278 * drag_modifier * speed_ms**2 + 0.03896 + 9.81 * sin(elevation)) * speed_ms

func acceleration_based_on_speed(speed_ms, elevation, power, in_peloton_ = false):
	# Power: 1,200 W (300-1500)   -   DriveTrain efficientcy: 0.97, aka 3% loss
	# Air density: $1.225 \, kg/m^3 at Sea level, 15C$   -  Drag Area: 0.32 m^2
	# Mass: 70 kg -  Rotating mass: 0.5 kg   -   Gravity: 9.81 m/s^2
	# Rolling Resistance: 0.004   -    Speed in meter pr sec
	# (((1200*0.97)/speed)-(0.5*1.225*0.32*speed^2)-(70*9.81*0.004)-9.81*sin(elevation)*70.5/(70+0.5)
	var drag_modifier = 1
	if in_peloton_:
		drag_modifier = 0.7
	elif pelotonleader:
		drag_modifier = 0.85
		
	return ((power * 0.97 / 70.5) / speed_ms) - 0.00278 * drag_modifier * speed_ms**2 - 0.03896 - 9.81 * sin(elevation)

func max_possible_power():
	if fatigue < fatigue_threashold:
		return sustainable_watt + watt_limited_by_stamina()
	else:
		return watt_limited_by_fatigue()

func watt_limited_by_fatigue():
	return (sustainable_watt+watt_limited_by_stamina())*exp(-a_fatigue_resistence * (fatigue - fatigue_threashold))

func watt_limited_by_stamina():
	var break_away_bonus = initial_breakout_watt-sustainable_watt
	return break_away_bonus*exp(-1*b_stamina_degresse*break_away_bonus*total_time)

func set_variables(sustainable_watt_ = 400, initial_breakout_watt_ = 600, cohesion_ = 0.8, seperation_ = 0.05, speedup_ = 5.0, speeddown_ = 4.5):
	sustainable_watt = sustainable_watt_
	initial_breakout_watt = initial_breakout_watt_
	cohesion_c =  cohesion_    #Set by trial and error
	separation_c = seperation_
	speedUpProbability = speedup_
	speedDownProbability = speeddown_

func find_neighborhood():
	return world.bike_neighborhoods[race_index]

static func get_randomize_for_rl():
	var _rng = RandomNumberGenerator.new()
	
	var _speed = _rng.randf_range(6.0, 18.0)
	var _speedUpProbability = _rng.randi_range(4, 16)
	var _cohesion_c = _rng.randf_range(0.1, 1.0)
	var _separation_c = _rng.randf_range(0.01, 1)

	return {
		"speed": _speed,
		"speedUpProbability": _speedUpProbability,
		"cohesion_c": _cohesion_c,
		"separation_c": _separation_c,
	}

func set_randomize_for_rl(dict) -> void:
	speed = dict["speed"]
	speedUpProbability = dict["speedUpProbability"]
	cohesion_c = dict["cohesion_c"]
	separation_c = dict["separation_c"]


func get_camera_node() -> Camera3D:
	return $Camera3D

func safe_queue_free() -> void:
	world.erase_bike(self)
	freeing_bike.emit(self)
	bikebody.collision_layer = 0
	queue_free()
