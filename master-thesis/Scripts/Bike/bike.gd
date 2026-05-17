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

var speed = 10.0
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

var cohesion_c =  0.8    #Set by trial and error
var separation_c = 0.05  #0.05   #Set by trial and error 

var max_speed = 0

func _ready():
	max_progress = self.get_parent().curve.get_baked_length()
	if staminaRegen == null:
		staminaRegen = rng.randf_range(3.0, 4.0)

var processCounter = 0 
var controllerCounter = 0
var TotalSpeed = 0
var total_threashold = 0

func _physics_process(delta: float):
	timer += delta
	total_time += delta
	processCounter += 1
	if timer >= timer_threashold:
		controllerCounter += 1 
		timer = timer-timer_threashold
		coltroler(timer_threashold)
		total_threashold += timer_threashold
		#move bike forward
		if speed>max_speed:
			max_speed = speed
			
	TotalSpeed += speed
	self.progress += speed * delta
	if self.progress >= max_progress:
		print("Bike: ", self.name, " Finish time: ", total_time, " Remaining_Timer: ", timer,  "  Watts: ", sustainable_watt, " MaxSpeed: ", max_speed, "  Progress: ", self.progress, " MaxProgress: ", max_progress)
		print("total_time: ", total_time, " total threashold: ", total_threashold, " Total_Speed: ", TotalSpeed, " Total_processcounter: ", processCounter, " Threahold_Counter: ", controllerCounter)
		safe_queue_free()


func coltroler(delta):
	#control1(delta)
	control2(delta)

#Controller1 
func control1(delta): #No longer used
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

func cruise(elevation_, ray_hits):
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
		#print("EndAttack ", name, "  ", total_time, "  ", fatigue)
		return
	
	if behavior == "attack" and self.progress_ratio <= 0.985:
		if elevation_ < 0 or rng.randi_range(0, 1000) < 7 * delta:
			behavior = "cruise"
			#print("chill ", name, "  ", total_time, "  ", fatigue)
			return
	
	if behavior == "cruise" and elevation_ > 0.017: # 0.09 rad is 5%
		if rng.randi_range(0,10000) < (12 * (elevation_ / 0.034) * delta) / max(1-progress_ratio, 0.15): # max(1-progress_ratio, 0.15):
			behavior = "attack"
			#print("ATTACK ",  name, "  ", total_time, "  ", fatigue, "  ", elevation_)
		#if self.fatigue>self.fatigue_threashold*1.05:
			#print(self.fatigue)
	
func fatigue_changes(current_watt):
	if current_watt == sustainable_watt:
		return
	fatigue = max(0, fatigue + current_watt - sustainable_watt)

func max_possible_power():
	if fatigue < fatigue_threashold:
		return sustainable_watt + watt_limited_by_stamina()
	else:
		return watt_limited_by_fatigue()

func watt_limited_by_fatigue():
	return (sustainable_watt + watt_limited_by_stamina()) * exp(-a_fatigue_resistence * (fatigue - fatigue_threashold))
	
func watt_limited_by_stamina():
	var break_away_bonus = initial_breakout_watt - sustainable_watt
	return break_away_bonus*exp(-1 * b_stamina_degresse * break_away_bonus * total_time)

#Controlter3 


#Helper Functions
func calc_watt_current_state(speed_ms, elevation, acceleration_mss, in_peloton_=false):
	#see acceleration_based_on_speed for constant explain
	var drag_modifier = 1
	if in_peloton_:
		drag_modifier = 0.7
	return 82.9897 * speed_ms * (acceleration_mss + 0.0024 * drag_modifier * speed_ms**2 + 0.0390 + 9.81 * sin(elevation))
	
func acceleration_based_on_speed(speed_ms, elevation, power, in_peloton_ = false):
	#Power: 1,200 W (300-1500)   -   DriveTrain efficientcy: 0.97, aka 3% loss
	#Air density: $1.225 \, kg/m^3 at Sea level, 15C$   -  Drag Area: 0.32 m^2
	#Mass: 80 kg -  Rotating mass: 0.5 kg   -   Gravity: 9.81 m/s^2
	#Rolling Resistance: 0.004   -    Speed in meter pr sec
	#(((1200*0.97)/speed)-(0.5*1.225*0.32*speed^2)-(80*9.81*0.004)-9.81*sin(elevation)*80.5/(80+0.5)
	var drag_modifier = 1
	if in_peloton_:
		drag_modifier = 0.7
	return ((power * 0.97 / 80.5) / speed_ms) - 0.0024 * drag_modifier * speed_ms**2 - 0.0390 - 9.81 * sin(elevation)
	
func set_watts(sustainable_watt_ = 355, initial_breakout_watt_ = 531):
	sustainable_watt = sustainable_watt_
	initial_breakout_watt = initial_breakout_watt_
	
func get_camera_node() -> Camera3D:
	return $Camera3D
	
func safe_queue_free() -> void:
	freeing_bike.emit(self)
	queue_free()
	
