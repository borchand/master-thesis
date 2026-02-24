extends PathFollow3D

class_name Bike
signal freeing_bike

@onready var raycast = $RayCast3D
@onready var bikebody = $BikeBody
var rng = RandomNumberGenerator.new()
var max_progress: float

var pr_sec_checks = 4
var timer_threashold = 1.0/pr_sec_checks
var timer = 0
var t = 0 

var Maxspeed = 22
var Minspeed = 4.5
var staminaSpeedupThreashold = 85
var staminaSlowdownThreashold = 40
var staminaRegen: float
var speedUpProbability = 2
var accelerationRate = 0.0001
var deaccelerationRate = 0.0002
var stamina = 100.0

var speed = 8.0
var acceleration = 0.0

var sustainable_force = 25     
var sustained_watt = 355 
var initial_breakout_watt = 531
var a_fatigue_resistence = 0.00003
var fatigue_threashold = 52800.0
var b_stamina_degresse = 0.0000002
var fatigue = 0
var behavior = "cruise"  #cruise, attack

var cohesion_c = 0.05   #Set by trial and error
var separation_c = 5    #Set by trial and error 

func _ready():
	max_progress = self.get_parent().curve.get_baked_length()
	if staminaRegen == null:
		staminaRegen = rng.randf_range(3.0, 4.0)
	
func _process(delta):
	timer += delta
	t += delta
	if timer >= timer_threashold:
		timer = timer-timer_threashold
		adjust_speed(delta)
	
	speed = max(0,speed+acceleration*delta)
	# move bike forward
	self.progress += speed * delta
	if self.progress >= max_progress:
		# remove bike when it reaches the end of the path
		safe_queue_free()
	
func adjust_speed(delta):
	#control1(delta)
	control2(delta)

#Controller1 
func control1(delta):
	#Slow down if stamina low
	if stamina<staminaSlowdownThreashold:
		acceleration -= deaccelerationRate*(staminaSlowdownThreashold-stamina)
	elif stamina>staminaSpeedupThreashold and (rng.randi_range(0,100)+(staminaSpeedupThreashold-stamina)*0.3) < speedUpProbability :
		acceleration += accelerationRate
	#Change in speed and stamina
	speed = max(Minspeed, min(Maxspeed, speed+acceleration))
	stamina = min(100.0, stamina+staminaRegen*0.25-speed*0.5)
	if speed==Minspeed: #on min speed stamina regenerate is double
		acceleration = max(0,acceleration)
		stamina += staminaRegen*0.5 
		
func setRegen(regen: float) -> void:
	staminaRegen = regen

#Controller2
func control2(delta):
	
	if behavior == "cruise":
		cruise(delta)
	elif  behavior == "attack":
		attack(delta)
	#control1(delta)
	solo(delta)
	#peloton(delta)
		
func cruise(delta):
	var result = raycast.run_raycast()
	if len(result) != 4: 
		print("Ray_cast length is not 3")
		return
	if result[0]==0: #you left the peleton
		solo(delta)
		return
	var dist_to_center = result[1]
	var dist_to_1 = result[2]
	var dist_to_2 = result[3]
	if dist_to_center != null:
		var sep_mod = 0
		if dist_to_2 != null and dist_to_2 != 0:
			sep_mod = (1/dist_to_2) #something high
		elif dist_to_1 != null and dist_to_1 != 0: 
			sep_mod = (1/dist_to_1) #something high
		print(dist_to_center, " ", cohesion_c, " ",sep_mod, " ",separation_c)
		acceleration = dist_to_center * cohesion_c - sep_mod * separation_c
	else: 
		#something normal
		print("shouldn't happen")	
	return 
func attack(delta):
	return

func solo(delta):
	var tilt_angle_rad = -1*bikebody.global_rotation.x #negative facing down
	acceleration = acceleration_based_on_speed(speed, tilt_angle_rad, sustained_watt)
	return
	
func behaviorChange(delta, behavior_string:String):
	return

func calc_watt(speed_ms, elevation, acceleration_mss, in_peloton=false):
	#see acceleration_based_on_speed for constant explain
	var drag_modifier = 1
	if in_peloton:
		drag_modifier = 0.7
	return 82.9897 * speed_ms * (acceleration_mss + 0.0024 * drag_modifier * speed_ms**2 + 0.0390 + 9.81 * sin(elevation))
	
func acceleration_based_on_speed(speed_ms, elevation, power, in_peloton = false):
	#Power: 1,200 W (300-1500)   -   DriveTrain efficientcy: 0.97, aka 3% loss
	#Air density: $1.225 \, kg/m^3 at Sea level, 15C$   -  Drag Area: 0.32 m^2
	#Mass: 80 kg -  Rotating mass: 0.5 kg   -   Gravity: 9.81 m/s^2
	#Rolling Resistance: 0.004   -    Speed in meter pr sec
	#(((1200*0.97)/speed)-(0.5*1.225*0.32*speed^2)-(80*9.81*0.004)-9.81*sin(elevation)*80.5/(80+0.5)
	var drag_modifier = 1
	if in_peloton:
		drag_modifier = 0.7
	return ((power*0.97/80.5)/speed_ms)-0.0024*drag_modifier*speed_ms**2-0.0390-9.81*sin(elevation)
	
func max_possible_power(p):
	return

func set_watts(sustained_watt_ = 355, initial_breakout_watt_ = 531):
	sustained_watt = sustained_watt_
	initial_breakout_watt = initial_breakout_watt_

#Helper Functions
func get_camera_node() -> Camera3D:
	return $Camera3D
	
func safe_queue_free() -> void:
	freeing_bike.emit(self)
	queue_free()
	
func _on_bike_proximity_area_body_exited(body: Node3D) -> void:
	return
	if body.name == "BikeHitBox" and stamina >= staminaSlowdownThreashold:
		var pObject = body
		while pObject.get_parent() == null:
			pObject = pObject.get_parent()
		var bike = pObject
		if bike.name == "Bike": 
			acceleration = max(acceleration, bike.acceleration)
