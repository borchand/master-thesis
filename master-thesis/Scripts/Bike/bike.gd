extends PathFollow3D

class_name Bike
signal freeing_bike

@onready var raycast = $RayCast3D
@onready var bikebody = $BikeBody
var rng = RandomNumberGenerator.new()
var max_progress: float

var pr_sec_checks = 4
var timer_threashold = 1.0 / pr_sec_checks
var timer = 0
var total_time = 0

var Maxspeed = 22
var Minspeed = 4.5
var staminaSpeedupThreashold = 85
var staminaSlowdownThreashold = 40
var staminaRegen: float
var speedUpProbability = 2
var accelerationRate = 0.0001
var deaccelerationRate = 0.0002
var stamina = 100.0

var is_rl: bool = false
var is_training: bool = false

var speed = 9.0
var acceleration = 0.0

var sustainable_force = 25 # not used
var sustainable_watt = null
var initial_breakout_watt = null
var a_fatigue_resistence = 0.00003
var fatigue_threashold = 52800.0
var b_stamina_degresse = 0.0000002
var fatigue = 0
var in_peloton = false
var behavior = "cruise"  #cruise, attack

var cohesion_c =  0.05     #Set by trial and error
var separation_c = 0.55   #Set by trial and error

func _ready():
	max_progress = self.get_parent().curve.get_baked_length()
	if staminaRegen == null:
		staminaRegen = rng.randf_range(3.0, 4.0)

func _process(delta):
	timer += delta
	total_time += delta
	if timer >= timer_threashold:
		timer = timer-timer_threashold
		coltroler(delta)

	# move bike forward
	self.progress += speed * delta
	if self.progress >= max_progress:
		if not is_rl:
			print("Bike: ", self.name, " Finish time: ", total_time)
		safe_queue_free()

func coltroler(delta):
	#control1(delta)
	control2(delta)

#Controller1
func control1(_delta): #No longer used
	#Slow down if stamina low
	if stamina<staminaSlowdownThreashold:
		acceleration -= deaccelerationRate * (staminaSlowdownThreashold - stamina)
	elif stamina>staminaSpeedupThreashold and (rng.randi_range(0,100) + (staminaSpeedupThreashold - stamina) * 0.3) < speedUpProbability :
		acceleration += accelerationRate
	#Change in speed and stamina
	speed = max(Minspeed, min(Maxspeed, speed + acceleration))
	stamina = min(100.0, stamina + staminaRegen * 0.25 - speed * 0.5)
	if speed == Minspeed: #on min speed stamina regenerate is double
		acceleration = max(0, acceleration)
		stamina += staminaRegen * 0.5

func setRegen(regen: float) -> void:
	staminaRegen = regen

#Controller2
func control2(delta):
	var elevation = -1 * bikebody.global_rotation.x #positive = going up
	var wanted_power  = sustainable_watt

	var raycast_result = raycast.run_raycast()
	if len(raycast_result) != 4:
		print("Ray_cast length is not 3")
		return
	if raycast_result[0] == 0 or raycast_result[2] > 6 or progress_ratio >= 0.985: #you left the peleton or are in front
		in_peloton = false
	else:
		in_peloton = true

	behaviorChange(delta, elevation)
	if behavior == "cruise":
		wanted_power = cruise(elevation, raycast_result)
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
	if self.progress_ratio > 0.985 and behavior != "attack":
		behavior = "attack"
		if not is_rl:
			print("EndAttack ", name, "  ", total_time, "  ", fatigue)
		return

	if behavior == "attack" and self.progress_ratio <= 0.985:
		if elevation_ < 0 or rng.randi_range(0, 1000) < 7 * delta:
			behavior = "cruise"
			if not is_rl:
				print("chill ", name, "  ", total_time, "  ", fatigue)
			return

	if behavior == "cruise" and elevation_ > 0.017: # 0.09 rad is 5%
		if rng.randi_range(0,10000) < (12 * (elevation_ / 0.034) * delta) / max(1-progress_ratio, 0.15):
			behavior = "attack"
			if not is_rl:
				print("ATTACK ",  name, "  ", total_time, "  ", fatigue, "  ", elevation_)

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
	return 82.9897 * speed_ms * (acceleration_mss + 0.0024 * drag_modifier * speed_ms**2 + 0.0390 + 9.81 * sin(elevation))

func acceleration_based_on_speed(speed_ms, elevation, power, in_peloton_ = false):
	# Power: 1,200 W (300-1500)   -   DriveTrain efficientcy: 0.97, aka 3% loss
	# Air density: $1.225 \, kg/m^3 at Sea level, 15C$   -  Drag Area: 0.32 m^2
	# Mass: 80 kg -  Rotating mass: 0.5 kg   -   Gravity: 9.81 m/s^2
	# Rolling Resistance: 0.004   -    Speed in meter pr sec
	# (((1200*0.97)/speed)-(0.5*1.225*0.32*speed^2)-(80*9.81*0.004)-9.81*sin(elevation)*80.5/(80+0.5)
	var drag_modifier = 1
	if in_peloton_:
		drag_modifier = 0.7
		
	return ((power * 0.97 / 80.5) / speed_ms) - 0.0024 * drag_modifier * speed_ms**2 - 0.0390 - 9.81 * sin(elevation)

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

func set_watts(sustainable_watt_ = 355, initial_breakout_watt_ = 531):
	sustainable_watt = sustainable_watt_
	initial_breakout_watt = initial_breakout_watt_

static func get_randomize_for_rl():
	var _rng = RandomNumberGenerator.new()
	
	var _speed = _rng.randf_range(6.0, 18.0)
	var _maxspeed = _rng.randf_range(16.0, 26.0)
	var _minspeed = _rng.randf_range(3.0, 7.0)
	var _speedUpProbability = _rng.randi_range(1, 6)
	var _cohesion_c = _rng.randf_range(0.1, 0.8)
	var _separation_c = _rng.randf_range(0.01, 1)

	return {
		"speed": _speed,
		"maxspeed": _maxspeed,
		"minspeed": _minspeed,
		"speedUpProbability": _speedUpProbability,
		"cohesion_c": _cohesion_c,
		"separation_c": _separation_c,
	}

func set_randomize_for_rl(dict) -> void:
	speed = dict["speed"]
	Maxspeed = dict["maxspeed"]
	Minspeed = dict["minspeed"]
	speedUpProbability = dict["speedUpProbability"]
	cohesion_c = dict["cohesion_c"]
	separation_c = dict["separation_c"]


func get_camera_node() -> Camera3D:
	return $Camera3D

func safe_queue_free() -> void:
	freeing_bike.emit(self)
	bikebody.collision_layer = 0
	queue_free()
